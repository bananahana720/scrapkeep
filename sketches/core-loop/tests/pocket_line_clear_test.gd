extends SceneTree

# POCKET-LINES (2026-10-16), generalising DOMES-STOP's domes_camp_line_test. Rule: no interior the
# pocket library assigns to a park stage row puts a solid block on an authored rolling line.
# For every park stage, every row an interior is assigned to (PocketLibrary.for_site) is built unrotated
# (activities.gd rotates only drawn sites), its collision goes live, and a ball of Tuning.RADIUS
# plus LINE_SPREAD metres is swept along every authored line of the stage (six pilots and the floor
# line in assets/park/<map>/lines.json) wherever the line comes within the footprint's reach. The
# sweep covers each leg between consecutive waypoints and the corner the bot cuts from
# WAYPOINT_REACHED out (tools/bot_driver.gd). Each stage also runs a planted control: a block moved
# onto the stage's first line leg must turn the sweep red, so a zero is a measured zero. A stage with
# no assigned interior still runs its control and states the zero. DOMES-STOP's case stays: dome_camp's
# blocks stood 0.1 m and 1.1 m from Tarn's and Kest's approaches on park_dam.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Library := preload("res://src/world/pockets/pocket_library.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const STAGES := ["park_dam", "park_flume", "park_pit", "park_sinkhole", "park_islands", "park_crown"]
# Metres beyond the ball's radius; the measured Kest stop rode 1.5 m off its authored line.
const LINE_SPREAD := 1.5
const STEP := 0.25
# tools/bot_driver.gd WAYPOINT_REACHED: the traversal bot takes the next waypoint this close.
const WAYPOINT_REACHED := 9.0
var t := T.new("pocket_line_clear_test")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	game.world.set_physics_process(false)
	game.flow.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.body().freeze = true
	var acts = game.world.activities
	acts.set_physics_process(false)
	acts.clear()
	await physics_frame
	var slot := 0
	var assigned_total := 0
	for stage in STAGES:
		var park = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % stage))
		var lines = JSON.parse_string(FileAccess.get_file_as_string("res://assets/park/%s/lines.json" % stage))
		if not t.check("%s has its park file and seven lines" % stage, park is Dictionary and lines is Dictionary and lines.get("pilots", {}).size() == 6 and lines.has("floor")):
			continue
		var legs := _legs(park, lines)
		t.check("%s resolves its lines to legs" % stage, legs.size() > 40, str(legs.size()))
		# Every row of the stage that has an assigned interior.
		var rows := []
		for row in park.get("activity_rows", []):
			var entry: Dictionary = Library.for_site(stage, String(row.id))
			if not entry.is_empty():
				rows.append({"row": row, "entry": entry})
		assigned_total += rows.size()
		var template: Dictionary = rows[0].entry if not rows.is_empty() else Library.for_site("park_dam", "domes_camp")
		# The planted control: the template's first block on the stage's first leg, 30 m past the spawn.
		var leg: Dictionary = legs[0]
		var dir: Vector2 = (leg.to - leg.from).normalized()
		var spot: Vector2 = leg.from + dir * 30.0
		var planted_entry: Dictionary = template.duplicate(true)
		planted_entry.terrain[0].at = [0.0, 0.0]
		var planted_lab := Vector2(200 + 120 * slot, 200)
		var planted = _site(acts, planted_entry, planted_lab)
		slot += 1
		await physics_frame
		await physics_frame
		var planted_hits := _sweep(planted, legs, spot, planted_lab)
		t.check("%s planted control: a block on the first leg turns the sweep red" % stage, not planted_hits.is_empty(), str(planted_hits))
		for item in rows:
			var row: Dictionary = item.row
			var entry: Dictionary = item.entry
			var at := Vector2(float(row.at[0]), float(row.at[1]))
			var lab := Vector2(200 + 120 * slot, 200)
			var site = _site(acts, entry, lab)
			slot += 1
			await physics_frame
			await physics_frame
			if entry.activity == "enemy_camp":
				t.check("%s %s: an assigned camp interior stands unrotated" % [stage, row.id], is_zero_approx(site.rotation.y))
			var hits := _sweep(site, legs, at, lab)
			var closest := _clearance(site, legs, at, lab)
			print("[table] %s %s %s footprint=%s nearest_block_to_line=%.2f m site_yaw=%.2f" % [stage, row.id, entry.id, entry.footprint, closest, site.rotation.y])
			t.check("%s %s (%s) keeps clear of every line" % [stage, row.id, entry.id], hits.is_empty(), str(hits))
			if not hits.is_empty():
				print("[lines] %s %s site-local points: %s" % [stage, row.id, _trace(site, legs, at, lab)])
		if rows.is_empty():
			print("[table] %s no assigned interior" % stage)
	t.check("the park stages carry at least the four known assigned interiors", assigned_total >= 4, str(assigned_total))
	acts.clear()
	await physics_frame
	game.free()
	quit(t.verdict())

func _site(acts, entry: Dictionary, at: Vector2):
	var site = acts._build(entry.activity, at, Library.site_spec(entry))
	acts.sites.append(site)
	acts._activate_interior_collision(site)
	return site

# Global-coordinate legs of every line: {"name", "from", "to"}. The drop-in is the spawn, the landmark its
# beacon, other ids a park row's or activity's at; each leg joins consecutive points, and the
# bot's cut corner runs from WAYPOINT_REACHED short of a waypoint to the one after it.
func _legs(park: Dictionary, lines: Dictionary) -> Array:
	var named: Dictionary = lines.get("pilots", {}).duplicate()
	named["floor"] = lines.get("floor", {})
	var out := []
	for key in named:
		var pts: Array[Vector2] = []
		for point in named[key].get("waypoints", []):
			var at: Vector2 = _place(park, point) if point is String else Vector2(float(point[0]), float(point[1]))
			if at != Vector2.INF:
				pts.append(at)
		for i in range(1, pts.size()):
			out.append({"name": "%s leg %d" % [key, i], "from": pts[i - 1], "to": pts[i]})
		for i in range(1, pts.size() - 1):
			var back: Vector2 = pts[i] + (pts[i - 1] - pts[i]).normalized() * WAYPOINT_REACHED
			out.append({"name": "%s cut %d" % [key, i], "from": back, "to": pts[i + 1]})
	return out

func _place(park: Dictionary, id: String) -> Vector2:
	if id == "drop_in":
		var s = park.get("spawn", {}).get("at")
		return Vector2(float(s[0]), float(s[1])) if s is Array else Vector2.INF
	if id == "landmark":
		var b = park.get("landmark", {}).get("beacon")
		return Vector2(float(b[0]), float(b[1])) if b is Array else Vector2.INF
	for table in ["park_rows", "activity_rows"]:
		for row in park.get(table, []):
			if row is Dictionary and row.get("id") == id:
				return Vector2(float(row.at[0]), float(row.at[1]))
	return Vector2.INF

# A park point in the site's own frame (x, z): the lab site stands where the park site would stand with
# the same shift the build applied, so park offsets carry over, then the site's yaw is undone.
func _local(site: Node3D, p: Vector2, park_at: Vector2, lab_at: Vector2) -> Vector2:
	var world := lab_at + (p - park_at)
	var l := site.to_local(Vector3(world.x, site.global_position.y, world.y))
	return Vector2(l.x, l.z)

func _reach(entry: Dictionary) -> float:
	return Library.FOOTPRINTS[entry.footprint] * 0.5 * sqrt(2.0) + 3.0

# Leg name -> the first global point where the swept ball overlaps an interior block, among points
# within the footprint's reach of the site at `centre`.
func _sweep(site: Node3D, legs: Array, park_at: Vector2, lab_at: Vector2) -> Dictionary:
	var interior: Node = site.get_node("Interior_" + String(site.interior.id))
	var reach := _reach(site.interior)
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS + LINE_SPREAD
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	var space: PhysicsDirectSpaceState3D = site.get_world_3d().direct_space_state
	var hits := {}
	for leg in legs:
		var span: Vector2 = leg.to - leg.from
		var dir: Vector2 = span.normalized()
		var d := 0.0
		while d <= span.length() and not hits.has(leg.name):
			var p: Vector2 = leg.from + dir * d
			d += STEP
			var local := _local(site, p, park_at, lab_at)
			if local.length() > reach:
				# Skip ahead when far outside the disc.
				d += maxf(0.0, local.length() - reach - STEP)
				continue
			query.transform = Transform3D(Basis(), site.to_global(Vector3(local.x, Tuning.RADIUS, local.y)))
			for result in space.intersect_shape(query, 32):
				if interior.is_ancestor_of(result.collider):
					hits[leg.name] = [snappedf(local.x, 0.01), snappedf(local.y, 0.01)]
					break
	return hits

# Table figure: the shortest gap from any leg (within reach) to any block's footprint rectangle, in metres.
func _clearance(site: Node3D, legs: Array, park_at: Vector2, lab_at: Vector2) -> float:
	var entry: Dictionary = site.interior
	var reach := _reach(entry)
	var best := INF
	for leg in legs:
		var span: Vector2 = leg.to - leg.from
		var dir: Vector2 = span.normalized()
		var d := 0.0
		while d <= span.length():
			var p: Vector2 = leg.from + dir * d
			var local := _local(site, p, park_at, lab_at)
			if local.length() > reach:
				d += maxf(STEP, local.length() - reach)
				continue
			d += STEP
			for block in entry.terrain:
				var dx := maxf(absf(local.x - float(block.at[0])) - float(block.size[0]) * 0.5, 0.0)
				var dz := maxf(absf(local.y - float(block.at[1])) - float(block.size[2]) * 0.5, 0.0)
				best = minf(best, sqrt(dx * dx + dz * dz))
	return best

# Diagnostic for a red interior: each leg's site-local points inside the reach, every 3 m.
func _trace(site: Node3D, legs: Array, park_at: Vector2, lab_at: Vector2) -> String:
	var reach := _reach(site.interior)
	var out := []
	for leg in legs:
		var span: Vector2 = leg.to - leg.from
		var dir: Vector2 = span.normalized()
		var pts := []
		var d := 0.0
		while d <= span.length():
			var local := _local(site, leg.from + dir * d, park_at, lab_at)
			if local.length() <= reach:
				pts.append("%d,%d" % [roundi(local.x), roundi(local.y)])
			d += 3.0
		if not pts.is_empty():
			out.append("%s: %s" % [leg.name, " ".join(pts)])
	return "\n".join(out)
