extends SceneTree
# smoke: solo timeout=240s (builds the dam and the flume rows headless)

# Owner map point 5, code half (ruling ct, the ten-point map standard; map-audit section G, row "5 code"): landform
# mass is hard cover, dressing is soft cover. Every placed park row carries an explicit `cover_kind` tag stamped by
# park_recipes.gd (`tag_cover`):
#   - "hard": solid world-layer collider >= HARD_M (2.0 m) tall that blocks lobber shells;
#   - "soft": dressing, sensor-only, stamp-replaced, or empty row carrying zero colliders on Projectile.COVER_MASK;
#   - "surface": low rideable deck or apron strictly under HARD_M on the world layer (neither tall cover nor soft
#     dressing — e.g. flume's weir_deck 0.47 m and crew_ledges 1.00 m).
# Explicit row JSON `"cover"` overrides ("hard" / "soft" / "surface") are validated by park_schema.gd and honored by
# park_recipes.gd.
#
# Per world 1 park, built headless through terrain.gd as the game builds it:
#   - shell_cover: the stage's hazard.shell_cover_by_stage dial is on, so terrain and landforms stop a lobber shell
#     (projectile.gd _burst_on_cover) at all; 1 or 0, pass >= 1;
#   - hard_rows_cover_share: the share of tagged "hard" rows whose solid collider stands >= HARD_M tall and stays on
#     Projectile.COVER_MASK; pass >= 1.00;
#   - hard_rows_shell_cast_share: the share of tagged "hard" rows stopped by a real PhysicsRayQueryParameters3D cast
#     in World3D.direct_space_state on Projectile.COVER_MASK along a descending lobber shell path that hits the row's
#     own collider more than Projectile.BLAST_RADIUS short of the target and more than Projectile.COVER_SEAT_BAND
#     above the landing seat (matching projectile.gd _burst_on_cover); pass >= 1.00;
#   - soft_cover_bodies: bodies under tagged "soft" park rows or GroundScatter on Projectile.COVER_MASK; pass <= 0.
#
# The picture half of point 5 (hostile marks never share a look with walls or dressing, safe ground shown, dressing
# never hides a telegraph) is not read here: tools/danger_read_capture.gd and tools/mark_cover_capture.gd hold it,
# and the blind "where is safe" read is Andrew's eye.
#
# Output: `MAPCHECK <stage> <measure> <value> pass<op><line> PASS|FAIL`, plus `report INFO`.
#
# Planted (3 faults):
#   1. hard_row_off_cover: a tagged hard row's collider taken off COVER_MASK drops hard_rows_cover_share < 1.00;
#   2. hard_row_shell_miss: a tagged hard row's collider shapes disabled while keeping COVER_MASK drops the real
#      physics raycast hard_rows_shell_cast_share < 1.00;
#   3. scatter_body_on_cover: a body put on COVER_MASK under GroundScatter increments soft_cover_bodies > 0 (plus a
#      check that a body put on COVER_MASK under a tagged soft park row does the same).

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const Projectile := preload("res://src/combat/projectile.gd")

const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_dam"}, {"stage": 2, "world": 1, "map": "park_flume"}]}
const HARD_M := ParkRecipes.COVER_HARD_M
const READY_FRAMES := 1200
const RAY_LEAD_M := 5.0
const RAY_TRAIL_M := 6.0
const RAY_DROP_M := 1.2
const RAY_DROP_SHALLOW_M := 0.5

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
	_check_json_cover_override()
	for d in TABLE["DEFS"]:
		await _stage(terrain, int(d["stage"]), String(d["map"]))
	quit(t.verdict())


static func _owns_collider(row_node: Node, collider: Object) -> bool:
	return collider is Node and (collider == row_node or row_node.is_ancestor_of(collider as Node))


# Reads explicit ParkRecipes.cover_kind tags on every placed row under rows_node and GroundScatter:
# {"hard": [...], "soft_rows": [...], "surface": [...], "untagged": [...], "soft_cover": int, "soft_views": int}
static func read_rows(rows_node: Node, scatter: Node) -> Dictionary:
	var hard := []
	var soft_rows := []
	var surface := []
	var untagged := []
	var soft_cover := 0
	for node in rows_node.find_children("*", "Node3D", true, false):
		if not node.has_meta("park_recipe"):
			continue
		var kind := ParkRecipes.cover_kind(node)
		if not ParkRecipes.COVER_KINDS.has(kind):
			untagged.append(String(node.name))
			continue
		match kind:
			ParkRecipes.COVER_HARD:
				var h := ParkRecipes.cover_height(node as Node3D, Projectile.COVER_MASK)
				var shapes := ParkRecipes.collider_shapes(node).filter(func(s):
					return s["body"] is StaticBody3D and not s["disabled"] and s["shape"] != null)
				var on_cover := not shapes.is_empty() and h >= HARD_M
				for s in shapes:
					var b: CollisionObject3D = s["body"]
					if (b.collision_layer & Projectile.COVER_MASK) == 0:
						on_cover = false
						break
				hard.append({"id": String(node.name), "node": node, "height": h, "cover": on_cover})
			ParkRecipes.COVER_SOFT:
				soft_rows.append({"id": String(node.name), "node": node})
				for body in node.find_children("*", "CollisionObject3D", true, false):
					if (body.collision_layer & Projectile.COVER_MASK) != 0:
						soft_cover += 1
			ParkRecipes.COVER_SURFACE:
				var h := ParkRecipes.cover_height(node as Node3D, Projectile.COVER_MASK)
				surface.append({"id": String(node.name), "height": h, "valid": h > 0.0 and h < HARD_M})
	var soft_views := 0
	if scatter != null:
		soft_views = scatter.find_children("*", "VisualInstance3D", true, false).size()
		for body in scatter.find_children("*", "CollisionObject3D", true, false):
			if (body.collision_layer & Projectile.COVER_MASK) != 0:
				soft_cover += 1
	return {
		"hard": hard,
		"soft_rows": soft_rows,
		"surface": surface,
		"untagged": untagged,
		"soft_cover": soft_cover,
		"soft_views": soft_views,
	}


static func cover_share(hard: Array) -> float:
	if hard.is_empty():
		return 0.0
	return float(hard.filter(func(r): return r["cover"]).size()) / hard.size()


# Performs a real PhysicsRayQueryParameters3D shell-path cast on Projectile.COVER_MASK across a tagged hard row's
# collider geometry, matching projectile.gd _burst_on_cover (hit owned by this row, > BLAST_RADIUS planar short of
# target, and > COVER_SEAT_BAND above target seat).
static func cast_row_cover(space: PhysicsDirectSpaceState3D, row_node: Node3D) -> Dictionary:
	var solid := ParkRecipes.collider_shapes(row_node).filter(func(s):
		return s["body"] is StaticBody3D and not s["disabled"] and s["shape"] != null)
	if solid.is_empty():
		return {"hit": false, "reason": "no_shapes"}
	var candidates := []
	var pick_indices: Array[int] = [0]
	if solid.size() > 1:
		pick_indices.append(solid.size() / 2)
		pick_indices.append(solid.size() - 1)
		for step in range(1, mini(solid.size(), 12)):
			var idx := (step * solid.size()) / 12
			if not pick_indices.has(idx):
				pick_indices.append(idx)
	for idx in pick_indices:
		var s: Dictionary = solid[idx]
		var sh: Shape3D = s["shape"]
		var xf: Transform3D = s["global_transform"]
		if sh is ConcavePolygonShape3D:
			var faces := (sh as ConcavePolygonShape3D).get_faces()
			var tri_count := faces.size() / 3
			var wall_tris := []
			var other_tris := []
			var step_t := maxi(1, tri_count / 48)
			for tri in range(0, tri_count, step_t):
				var a := xf * faces[tri * 3]
				var b := xf * faces[tri * 3 + 1]
				var c := xf * faces[tri * 3 + 2]
				var cross := (b - a).cross(c - a)
				var area2 := cross.length()
				if area2 < 0.05:
					continue
				var n := cross / area2
				var m := (a + b + c) / 3.0
				var hdir := Vector3(n.x, 0.0, n.z)
				if hdir.length() > 0.3:
					wall_tris.append([area2, m, hdir.normalized()])
				else:
					other_tris.append([area2, m, Vector3.RIGHT])
			wall_tris.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
			other_tris.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
			for k in mini(8, wall_tris.size()):
				var entry: Array = wall_tris[k]
				candidates.append([entry[1], entry[2], RAY_LEAD_M, RAY_TRAIL_M, RAY_DROP_M])
				candidates.append([entry[1], -(entry[2] as Vector3), RAY_LEAD_M, RAY_TRAIL_M, RAY_DROP_M])
			for k in mini(4, other_tris.size()):
				var entry: Array = other_tris[k]
				candidates.append([entry[1], entry[2], RAY_LEAD_M, RAY_TRAIL_M, RAY_DROP_M])
				candidates.append([entry[1], -(entry[2] as Vector3), RAY_LEAD_M, RAY_TRAIL_M, RAY_DROP_M])
				candidates.append([entry[1], Vector3.BACK, RAY_LEAD_M, RAY_TRAIL_M, RAY_DROP_M])
		else:
			var box: AABB = xf * ParkRecipes.shape_aabb(sh)
			var c := box.get_center()
			var rx := maxf(box.size.x * 0.5, 0.5)
			var rz := maxf(box.size.z * 0.5, 0.5)
			var drop := minf(RAY_DROP_M, maxf(RAY_DROP_SHALLOW_M, box.size.y * 0.35))
			candidates.append([c, Vector3.RIGHT, rx + RAY_LEAD_M, rx + RAY_TRAIL_M, drop])
			candidates.append([c, Vector3.LEFT, rx + RAY_LEAD_M, rx + RAY_TRAIL_M, drop])
			candidates.append([c, Vector3.BACK, rz + RAY_LEAD_M, rz + RAY_TRAIL_M, drop])
			candidates.append([c, Vector3.FORWARD, rz + RAY_LEAD_M, rz + RAY_TRAIL_M, drop])
	for cand in candidates:
		var pt: Vector3 = cand[0]
		var hdir: Vector3 = cand[1]
		var lead := float(cand[2])
		var trail := float(cand[3])
		var drop := float(cand[4])
		var from := pt + hdir * lead + Vector3.UP * drop
		var to := pt - hdir * trail - Vector3.UP * drop
		var q := PhysicsRayQueryParameters3D.create(from, to, Projectile.COVER_MASK)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or not _owns_collider(row_node, hit["collider"]):
			continue
		var at: Vector3 = hit["position"]
		var planar_short := Vector2(at.x - to.x, at.z - to.z).length()
		var seat_clear := at.y - to.y
		if planar_short > Projectile.BLAST_RADIUS and seat_clear > Projectile.COVER_SEAT_BAND:
			return {"hit": true, "at": at, "short_m": planar_short, "seat_m": seat_clear}
	return {"hit": false, "reason": "no_own_hit"}


static func cast_hard_rows(space: PhysicsDirectSpaceState3D, hard: Array) -> Dictionary:
	var hits := 0
	var missed := []
	for entry in hard:
		var res := cast_row_cover(space, entry["node"] as Node3D)
		if res["hit"]:
			hits += 1
		else:
			missed.append(String(entry["id"]))
	var share := float(hits) / hard.size() if not hard.is_empty() else 0.0
	return {"hits": hits, "total": hard.size(), "share": share, "missed": missed}


func _check_json_cover_override() -> void:
	var scratch := Node3D.new()
	root.add_child(scratch)
	var flat := func(_x: float, _z: float) -> float: return 0.0
	var base_row := {
		"id": "override_probe", "element": "bank", "at": [0, 0], "y": 0.0, "size": [10, 4, 10],
		"yaw_deg": 0, "ride_fact": "", "recipe": "greybox:bank", "stamp": "", "budget": "landform",
	}
	var forced_soft := base_row.duplicate(true)
	forced_soft["cover"] = "soft"
	var soft_node := ParkRecipes.place_row(forced_soft, scratch, flat)
	t.check("row JSON cover='soft' override is honored", ParkRecipes.cover_kind(soft_node) == ParkRecipes.COVER_SOFT, ParkRecipes.cover_kind(soft_node))
	var forced_hard := base_row.duplicate(true)
	forced_hard["id"] = "override_hard"
	forced_hard["recipe"] = "scatter"
	forced_hard["cover"] = "hard"
	var hard_node := ParkRecipes.place_row(forced_hard, scratch, flat)
	t.check("row JSON cover='hard' override is honored", ParkRecipes.cover_kind(hard_node) == ParkRecipes.COVER_HARD, ParkRecipes.cover_kind(hard_node))
	scratch.free()
	var fixture := ParkSchema.read_file("res://src/world/park/park_test.json")["data"] as Dictionary
	if not fixture.is_empty():
		var valid_copy := fixture.duplicate(true)
		valid_copy["park_rows"][0]["cover"] = "hard"
		t.check("park_schema accepts valid cover='hard'", ParkSchema.validate(valid_copy).is_empty(), ParkSchema.describe(ParkSchema.validate(valid_copy)))
		var bad_copy := fixture.duplicate(true)
		bad_copy["park_rows"][0]["cover"] = "paper"
		var errs := ParkSchema.validate(bad_copy)
		t.check("park_schema rejects invalid cover enum", errs.any(func(e): return e["rule"] == "enum" and String(e["detail"]).contains("cover")), ParkSchema.describe(errs))


func _stage(terrain, stage: int, map_id: String) -> void:
	terrain.use(stage)
	var frames := 0
	while not terrain.rows_ready(stage) and frames < READY_FRAMES:
		await process_frame
		frames += 1
	var rows_node: Node3D = terrain.park_rows(stage)
	if not t.check("%s rows placed" % map_id, rows_node != null and terrain.rows_ready(stage), "%d frames" % frames):
		return
	await physics_frame
	var scatter: Node = rows_node.get_parent().get_node_or_null("GroundScatter")
	if scatter != null and scatter.has_method("finish") and not scatter.is_ready():
		scatter.finish()
	var r := read_rows(rows_node, scatter)
	t.check("%s every placed park row carries a valid cover_kind tag" % map_id, r["untagged"].is_empty(), str(r["untagged"]))
	t.check("%s ground scatter built" % map_id, r["soft_views"] > 0, "%d scatter views" % r["soft_views"])
	t.check("%s has tagged hard and soft rows" % map_id, not r["hard"].is_empty() and not r["soft_rows"].is_empty(),
		"hard=%d soft=%d surface=%d" % [r["hard"].size(), r["soft_rows"].size(), r["surface"].size()])
	var bad_surface: Array = r["surface"].filter(func(s): return not s["valid"]).map(func(s): return "%s(%.2f)" % [s["id"], s["height"]])
	t.check("%s surface rows are low solid decks under %.1f m" % [map_id, HARD_M], bad_surface.is_empty(), str(bad_surface))
	var dial := ChallengeDials.by_stage_or("hazard.shell_cover_by_stage", stage, 0.0) > 0.5
	_report(map_id, "shell_cover", 1.0 if dial else 0.0, ">=", 1.0, "%d")
	var share := cover_share(r["hard"])
	_report(map_id, "hard_rows_cover_share", share, ">=", 1.0, "%.2f")
	var space := rows_node.get_world_3d().direct_space_state
	var cast := cast_hard_rows(space, r["hard"])
	_report(map_id, "hard_rows_shell_cast_share", float(cast["share"]), ">=", 1.0, "%.2f")
	_report(map_id, "soft_cover_bodies", float(r["soft_cover"]), "<=", 0.0, "%d")
	var off: Array = r["hard"].filter(func(x): return not x["cover"]).map(func(x): return x["id"])
	var missed: Array = cast["missed"]
	print("MAPCHECK %s cover_rows hard=%d soft=%d surface=%d soft_views=%d off_cover=%s cast_miss=%s report INFO" % [
		map_id, r["hard"].size(), r["soft_rows"].size(), r["surface"].size(), r["soft_views"],
		",".join(off) if not off.is_empty() else "none",
		",".join(missed) if not missed.is_empty() else "none",
	])
	if stage == 1:
		await _planted(rows_node, scatter, space, r)


func _report(stage: String, measure: String, value: float, op: String, line: float, fmt: String) -> void:
	var meets := value >= line if op == ">=" else value <= line
	var shown: String = fmt % (int(value) if fmt == "%d" else value)
	var line_shown: String = fmt % (int(line) if fmt == "%d" else line)
	print("MAPCHECK %s %s %s pass%s%s %s" % [stage, measure, shown, op, line_shown, "PASS" if meets else "FAIL"])
	t.check("%s %s %s %s" % [stage, measure, op, line_shown], meets, shown)


func _planted(rows_node: Node3D, scatter: Node, space: PhysicsDirectSpaceState3D, before: Dictionary) -> void:
	# Plant 1: a tagged hard row whose collider leaves the cover layer fails hard_rows_cover_share.
	var victim: Node3D = before["hard"][0]["node"]
	var bodies: Array = victim.find_children("*", "CollisionObject3D", true, false)
	var kept := []
	for body in bodies:
		kept.append(body.collision_layer)
		body.collision_layer = body.collision_layer & ~Projectile.COVER_MASK
	var stripped := cover_share(read_rows(rows_node, scatter)["hard"])
	for i in bodies.size():
		bodies[i].collision_layer = kept[i]
	print("PLANTED hard_row_off_cover hard_rows_cover_share %.2f pass>=1.00 %s" % [stripped, "PASS" if stripped >= 1.0 else "FAIL"])
	t.check("planted: a hard row off the cover layer fails the share", not bodies.is_empty() and stripped < 1.0, "%.2f, %d bodies" % [stripped, bodies.size()])

	# Plant 2: a tagged hard row whose collider shapes are disabled (even while keeping COVER_MASK on its body) fails
	# the real physics raycast hard_rows_shell_cast_share.
	var disabled_owners := []
	for body in bodies:
		if not body is StaticBody3D:
			continue
		for oid in (body as StaticBody3D).get_shape_owners():
			if not (body as StaticBody3D).is_shape_owner_disabled(oid):
				(body as StaticBody3D).shape_owner_set_disabled(oid, true)
				disabled_owners.append([body, oid])
	await physics_frame
	var missed_cast := cast_hard_rows(space, before["hard"])
	for pair in disabled_owners:
		(pair[0] as StaticBody3D).shape_owner_set_disabled(int(pair[1]), false)
	await physics_frame
	var cast_share := float(missed_cast["share"])
	print("PLANTED hard_row_shell_miss hard_rows_shell_cast_share %.2f pass>=1.00 %s" % [cast_share, "PASS" if cast_share >= 1.0 else "FAIL"])
	t.check("planted: disabling a hard row's collider fails the physics shell cast", not disabled_owners.is_empty() and cast_share < 1.0 and missed_cast["missed"].has(String(victim.name)),
		"%.2f, missed=%s" % [cast_share, str(missed_cast["missed"])])

	# Plant 3: a scatter body on the cover layer counts and fails soft_cover_bodies.
	var planted_soft := 0
	if scatter != null:
		var body := StaticBody3D.new()
		body.collision_layer = Projectile.COVER_MASK
		scatter.add_child(body)
		planted_soft = read_rows(rows_node, scatter)["soft_cover"]
		scatter.remove_child(body)
		body.free()
	print("PLANTED scatter_body_on_cover soft_cover_bodies %d pass<=0 %s" % [planted_soft, "PASS" if planted_soft <= 0 else "FAIL"])
	t.check("planted: a scatter body on the cover layer counts and fails", planted_soft == int(before["soft_cover"]) + 1 and planted_soft > 0, "%d" % planted_soft)

	# Also verify a tagged soft park row carrying a COVER_MASK body increments soft_cover_bodies.
	var soft_row_planted := 0
	if not before["soft_rows"].is_empty():
		var soft_node: Node3D = before["soft_rows"][0]["node"]
		var body := StaticBody3D.new()
		body.collision_layer = Projectile.COVER_MASK
		soft_node.add_child(body)
		soft_row_planted = read_rows(rows_node, scatter)["soft_cover"]
		soft_node.remove_child(body)
		body.free()
	t.check("a soft park row body on the cover layer counts and fails", soft_row_planted == int(before["soft_cover"]) + 1 and soft_row_planted > 0, "%d" % soft_row_planted)
