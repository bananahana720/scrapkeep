extends SceneTree

# DOMES-STOP (2026-10-16). Rule: the dome_camp interior assigned to park_dam's domes_camp keeps
# its solid terrain blocks off every authored line through the camp. Each pilot line and the
# floor line in assets/park/park_dam/lines.json runs from the waypoint before domes_camp to the
# camp and on to the waypoint after it, and the bot cuts that corner from WAYPOINT_REACHED out; a ball of Tuning.RADIUS swept along those segments, with
# LINE_SPREAD metres more for the bot's spread about its line, touches no block once the
# interior's collision is live. Before this card the blocks stood at [-9, -3] and [9, -5], 0.1 m
# from the south-west approach and 1.1 m from the south-east one, and Tarn, Kest and the floor
# line struck them and then a camp chaser: a dead stop at about [-57, -403]. A planted block on
# Tarn's approach must turn the sweep red, so a zero here is a measured zero.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Library := preload("res://src/world/pockets/pocket_library.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PARK := "res://src/world/park/park_dam.json"
const LINES := "res://assets/park/park_dam/lines.json"
const ROW := "domes_camp"
# Metres beyond the ball's radius; the measured Kest stop rode 1.5 m off its authored line.
const LINE_SPREAD := 1.5
# How far from the camp centre each segment is swept: past the small footprint's corner.
const REACH := 20.0
const STEP := 0.25
# tools/bot_driver.gd WAYPOINT_REACHED: the traversal bot takes the next waypoint this close.
const WAYPOINT_REACHED := 9.0
var t := T.new("domes_camp_line_test")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var park = JSON.parse_string(FileAccess.get_file_as_string(PARK))
	var lines = JSON.parse_string(FileAccess.get_file_as_string(LINES))
	var entry: Dictionary = Library.for_site("park_dam", ROW)
	var camp := _place(park, ROW)
	if not t.check("domes_camp has its assigned interior and a park position", not entry.is_empty() and camp != Vector2.INF and park is Dictionary and lines is Dictionary):
		quit(t.verdict())
		return
	var segments := _segments(park, lines, camp)
	t.eq("seven lines give an approach, an exit and a cut corner through the camp", segments.size(), 21)
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
	game.player.active_body().freeze = true
	var acts = game.world.activities
	acts.set_physics_process(false)
	acts.clear()
	await physics_frame
	var site = _site(acts, entry, Vector2(200, 200))
	t.check("an assigned interior stands unrotated, so line offsets are camp-local", is_zero_approx(site.rotation.y))
	# The planted control: block 0 moved onto Tarn's approach, 8 m out from the camp centre.
	var tarn_in: Vector2 = segments.filter(func(s): return s.name == "tarn in")[0].to
	var planted_entry: Dictionary = entry.duplicate(true)
	var on_line := tarn_in.normalized() * 8.0
	planted_entry.terrain[0].at = [on_line.x, on_line.y]
	var planted = _site(acts, planted_entry, Vector2(320, 200))
	await physics_frame
	await physics_frame
	var planted_hits := _sweep(planted, segments)
	t.check("planted control: a block on Tarn's approach turns the sweep red", planted_hits.has("tarn in"), str(planted_hits))
	var hits := _sweep(site, segments)
	for segment in segments:
		t.check("%s keeps clear of dome_camp's blocks" % segment.name, not hits.has(segment.name), str(hits.get(segment.name, "")))
	acts.clear()
	await physics_frame
	game.free()
	quit(t.verdict())

func _site(acts, entry: Dictionary, at: Vector2):
	var site = acts._build(entry.activity, at, Library.site_spec(entry))
	acts.sites.append(site)
	acts._activate_interior_collision(site)
	return site

# Camp-local segments: from the camp centre out to the waypoint before and after domes_camp.
func _segments(park: Dictionary, lines: Dictionary, camp: Vector2) -> Array:
	var named: Dictionary = lines.get("pilots", {}).duplicate()
	named["floor"] = lines.get("floor", {})
	var out := []
	for key in named:
		var points: Array = named[key].get("waypoints", [])
		var i := points.find(ROW)
		if i <= 0 or i >= points.size() - 1:
			continue
		var ends := {}
		for pair in [[points[i - 1], "in"], [points[i + 1], "out"]]:
			var at: Vector2 = _place(park, pair[0]) if pair[0] is String else Vector2(float(pair[0][0]), float(pair[0][1]))
			ends[pair[1]] = at - camp
			out.append({"name": "%s %s" % [key, pair[1]], "from": Vector2.ZERO, "to": at - camp})
		# The bot turns for the next waypoint WAYPOINT_REACHED out from the camp, so it cuts the corner.
		out.append({"name": "%s cut" % key, "from": ends["in"].normalized() * WAYPOINT_REACHED, "to": ends["out"]})
	return out

func _place(park: Dictionary, id: String) -> Vector2:
	for table in ["park_rows", "activity_rows"]:
		for row in park.get(table, []):
			if row is Dictionary and row.get("id") == id:
				return Vector2(float(row.at[0]), float(row.at[1]))
	return Vector2.INF

# Segment name -> the first camp-local point where the swept ball overlaps an interior block.
func _sweep(site: Node3D, segments: Array) -> Dictionary:
	var interior: Node = site.get_node("Interior_" + String(site.interior.id))
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS + LINE_SPREAD
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	var space: PhysicsDirectSpaceState3D = site.get_world_3d().direct_space_state
	var hits := {}
	for segment in segments:
		var span: Vector2 = segment.to - segment.from
		var dir: Vector2 = span.normalized()
		var d := 0.0
		while d <= span.length() and not hits.has(segment.name):
			var p: Vector2 = segment.from + dir * d
			d += STEP
			if p.length() > REACH:
				continue
			query.transform = Transform3D(Basis(), site.to_global(Vector3(p.x, Tuning.RADIUS, p.y)))
			for result in space.intersect_shape(query, 32):
				if interior.is_ancestor_of(result.collider):
					hits[segment.name] = [snappedf(p.x, 0.01), snappedf(p.y, 0.01)]
					break
	return hits
