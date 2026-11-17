extends SceneTree
# smoke: solo timeout=240s (builds the dam and the flume rows headless)

# Owner map point 5, code half (ruling ct, the ten-point map standard; map-audit section G, row "5 code"): landform
# mass is hard cover, dressing is soft cover. The audit's line is "rows tagged hard have a ball-layer collider >= 2 m
# tall; soft rows have none". No park row carries a hard or soft tag, so this reads the tag from what the game builds:
# a placed park row whose collider stands HARD_M or more is hard (it stops the ball), and the ground scatter is soft.
# Per world 1 park, built headless through terrain.gd as the game builds it:
#   - shell_cover: the stage's hazard.shell_cover_by_stage dial is on, so terrain and landforms stop a lobber shell
#     (projectile.gd _burst_on_cover) at all; 1 or 0, pass >= 1;
#   - hard_rows_cover_share: the share of hard rows whose collider is on the layer a shell's cover ray hits
#     (projectile.gd COVER_MASK), so what stops the ball also stops a shell; pass >= 1.00;
#   - soft_cover_bodies: bodies under the ground scatter on that layer; pass <= 0.
# The picture half of point 5 (hostile marks never share a look with walls or dressing, safe ground shown, dressing
# never hides a telegraph) is not read here: tools/danger_read_capture.gd and tools/mark_cover_capture.gd hold it,
# and the blind "where is safe" read is Andrew's eye.
#
# Output: `MAPCHECK <stage> <measure> <value> pass<op><line> PASS|FAIL`, plus `report INFO`.
#
# Planted: one hard row's collider taken off the cover layer drops the share under 1 and fails; one scatter body put
# on the cover layer counts 1 and fails.

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Projectile := preload("res://src/combat/projectile.gd")

const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_dam"}, {"stage": 2, "world": 1, "map": "park_flume"}]}
const HARD_M := 2.0
const READY_FRAMES := 1200

var t := T.new("park_cover_tags_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()
	var terrain = Terrain.new(TABLE)
	terrain.build(holder)
	for d in TABLE["DEFS"]:
		await _stage(terrain, int(d["stage"]), String(d["map"]))
	quit(t.verdict())


# The world-space height of a node's collision shapes, 0 with none.
static func collider_height(body: CollisionObject3D) -> float:
	var box := AABB()
	var any := false
	for shape_node in body.find_children("*", "CollisionShape3D", true, false):
		var cs := shape_node as CollisionShape3D
		if cs.shape == null or cs.disabled:
			continue
		var b: AABB = cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
		box = b if not any else box.merge(b)
		any = true
	return box.size.y if any else 0.0


# {"hard": [{"id", "height", "cover"}], "soft_cover": int, "soft": int}
static func read_rows(rows_node: Node, scatter: Node) -> Dictionary:
	var hard := []
	for node in rows_node.find_children("*", "Node3D", true, false):
		if not node.has_meta("park_recipe"):
			continue
		var tallest := 0.0
		var on_cover := true
		for body in node.find_children("*", "CollisionObject3D", true, false):
			var h := collider_height(body)
			if h >= HARD_M:
				tallest = maxf(tallest, h)
				on_cover = on_cover and (body.collision_layer & Projectile.COVER_MASK) != 0
		if tallest >= HARD_M:
			hard.append({"id": String(node.name), "height": tallest, "cover": on_cover})
	var soft_cover := 0
	var soft := 0
	if scatter != null:
		soft = scatter.find_children("*", "VisualInstance3D", true, false).size()
		for body in scatter.find_children("*", "CollisionObject3D", true, false):
			if (body.collision_layer & Projectile.COVER_MASK) != 0:
				soft_cover += 1
	return {"hard": hard, "soft_cover": soft_cover, "soft": soft}


static func cover_share(hard: Array) -> float:
	if hard.is_empty():
		return 0.0
	return float(hard.filter(func(r): return r["cover"]).size()) / hard.size()


func _stage(terrain, stage: int, map_id: String) -> void:
	terrain.use(stage)
	var frames := 0
	while not terrain.rows_ready(stage) and frames < READY_FRAMES:
		await process_frame
		frames += 1
	var rows_node: Node = terrain.park_rows(stage)
	if not t.check("%s rows placed" % map_id, rows_node != null and terrain.rows_ready(stage), "%d frames" % frames):
		return
	await physics_frame
	var scatter: Node = rows_node.get_parent().get_node_or_null("GroundScatter")
	if scatter != null and scatter.has_method("finish") and not scatter.is_ready():
		scatter.finish()
	var r := read_rows(rows_node, scatter)
	t.check("%s ground scatter built" % map_id, r["soft"] > 0, "%d scatter views" % r["soft"])
	var dial := ChallengeDials.by_stage_or("hazard.shell_cover_by_stage", stage, 0.0) > 0.5
	_report(map_id, "shell_cover", 1.0 if dial else 0.0, ">=", 1.0, "%d")
	var share := cover_share(r["hard"])
	t.check("%s has hard rows" % map_id, not r["hard"].is_empty(), "%d" % r["hard"].size())
	_report(map_id, "hard_rows_cover_share", share, ">=", 1.0, "%.2f")
	_report(map_id, "soft_cover_bodies", float(r["soft_cover"]), "<=", 0.0, "%d")
	var off: Array = r["hard"].filter(func(x): return not x["cover"]).map(func(x): return x["id"])
	print("MAPCHECK %s cover_rows hard=%d soft_views=%d off_cover=%s report INFO" % [map_id, r["hard"].size(), r["soft"], ",".join(off) if not off.is_empty() else "none"])
	if stage == 1:
		_planted(rows_node, scatter, r)


func _report(stage: String, measure: String, value: float, op: String, line: float, fmt: String) -> void:
	var meets := value >= line if op == ">=" else value <= line
	var shown: String = fmt % (int(value) if fmt == "%d" else value)
	var line_shown: String = fmt % (int(line) if fmt == "%d" else line)
	print("MAPCHECK %s %s %s pass%s%s %s" % [stage, measure, shown, op, line_shown, "PASS" if meets else "FAIL"])
	t.check("%s %s %s %s" % [stage, measure, op, line_shown], meets, shown)


func _planted(rows_node: Node, scatter: Node, before: Dictionary) -> void:
	# A hard row whose collider leaves the cover layer: the ball still meets it, a shell flies through.
	var victim: Node = null
	for node in rows_node.find_children("*", "Node3D", true, false):
		if node.has_meta("park_recipe") and String(node.name) == String(before["hard"][0]["id"]):
			victim = node
			break
	var bodies: Array = victim.find_children("*", "CollisionObject3D", true, false) if victim != null else []
	var kept := []
	for body in bodies:
		kept.append(body.collision_layer)
		body.collision_layer = body.collision_layer & ~Projectile.COVER_MASK
	var stripped := cover_share(read_rows(rows_node, scatter)["hard"])
	for i in bodies.size():
		bodies[i].collision_layer = kept[i]
	print("PLANTED hard_row_off_cover hard_rows_cover_share %.2f pass>=1.00 %s" % [stripped, "PASS" if stripped >= 1.0 else "FAIL"])
	t.check("planted: a hard row off the cover layer fails the share", not bodies.is_empty() and stripped < 1.0, "%.2f, %d bodies" % [stripped, bodies.size()])
	# A scatter body on the cover layer: dressing that stops a shell is no longer soft.
	var planted_soft := 0
	if scatter != null:
		var body := StaticBody3D.new()
		body.collision_layer = Projectile.COVER_MASK
		scatter.add_child(body)
		planted_soft = read_rows(rows_node, scatter)["soft_cover"]
		body.queue_free()
	print("PLANTED scatter_body_on_cover soft_cover_bodies %d pass<=0 %s" % [planted_soft, "PASS" if planted_soft <= 0 else "FAIL"])
	t.check("planted: a scatter body on the cover layer counts and fails", planted_soft == int(before["soft_cover"]) + 1 and planted_soft > 0, "%d" % planted_soft)
