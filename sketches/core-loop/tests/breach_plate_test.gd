extends SceneTree

# Rule (breach.gd, world._on_slammed): a slam landing inside an unbroken Dig breach plate
# breaks it once per stage entry. Its overlay is erased so the ground reads drop_to, its
# cover box parks, swap_log records it and the codex marks "breach_plate". A slam
# elsewhere, a second slam or no slam leaves the plates alone; a stage entry restores
# them. The break sends exactly one world_fact("breach_opened") (event_kinds.gd WORLD_ROWS).
# Evidence limit: live headless Game on a one-stage Dig table; no camera or feel claim.

const DigTable := preload("res://tests/doubles/dig_table_defs.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const UPPER := 12.0
const TOLERANCE := 0.3
const SETTLE_FRAMES := 120
const DROP_FRAMES := 120


class DigGame extends "res://src/game.gd":
	func _chosen_table():
		return DigTable


var _game
var _failures := 0
var _facts := 0
var _kinds: Array[String] = []


func _initialize() -> void:
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _run() -> void:
	_game = DigGame.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.flow.press_start()
	_game.flow.choose_class(0)
	var waited := 0
	while not _game.flow.in_stage() and waited < 120:
		waited += 1
		await physics_frame
	_report("in stage", _game.flow.in_stage(), "after %d frames" % waited)
	_game.events.world_fact.connect(func(kind: String, _at: Vector3):
		_facts += 1
		_kinds.append(kind))
	var world = _game.world
	var terrain = _game.ctx.terrain
	var m = terrain.map()
	_report("Dig map", m.title == "Dig: the upper bench" and world.breach != null, m.title)
	var plate: Dictionary = m.breach_plates[0]
	var id: String = plate["id"]
	var drop_to: float = plate["drop_to"]
	var c: Vector2 = plate["rect"].get_center()
	var cover: Node3D = _game.find_child("BreachPlate_%s" % id, true, false)

	# (a) covered at stage start.
	_report("(a) plate reads upper", is_equal_approx(terrain.height(c.x, c.y), UPPER), "height %.3f" % terrain.height(c.x, c.y))
	_report("(a) cover at home", cover != null and cover.position == cover.get_meta("home"), str(cover.position if cover != null else null))

	# (b) a slam on the plate breaks it.
	_facts = 0
	_kinds.clear()
	world._on_slammed(Vector3(c.x, 13.0, c.y), 20.0, 1.0)
	_report("(b) height drops to drop_to", is_equal_approx(terrain.height(c.x, c.y), drop_to), "height %.3f, drop_to %.1f" % [terrain.height(c.x, c.y), drop_to])
	_report("(b) overlay erased", not terrain.overlays.has(id + "_before"), str(terrain.overlays))
	_report("(b) cover parked", cover.position.y < -300.0, "cover y %.1f" % cover.position.y)
	_report("(b) one swap logged", world.swap_log.size() == 1 and world.swap_log[0]["id"] == id, str(world.swap_log))
	_report("(b) codex marked", world.discoveries.any(func(d): return d["id"] == "breach_plate"), "%d discoveries" % world.discoveries.size())
	_report("(b) one world_fact breach_opened", _facts == 1 and _kinds == ["breach_opened"], "%d facts %s" % [_facts, _kinds])

	# (c) the same slam again changes nothing.
	world._on_slammed(Vector3(c.x, 13.0, c.y), 20.0, 1.0)
	_report("(c) second slam is a no-op", world.swap_log.size() == 1, "%d swaps" % world.swap_log.size())

	# (d) a slam 30 m outside every rect changes nothing.
	var far := Vector2(c.x, c.y - 30.0)
	var outside := true
	for p in m.breach_plates:
		var r: Rect2 = p["rect"]
		if r.grow(1.0).has_point(far):
			outside = false
	var overlays_before: Array = terrain.overlays.duplicate()
	world._on_slammed(Vector3(far.x, UPPER + 1.0, far.y), 20.0, 1.0)
	_report("(d) far slam leaves the plates", outside and world.swap_log.size() == 1 and terrain.overlays == overlays_before,
		"outside %s, %d swaps, overlays %s" % [outside, world.swap_log.size(), terrain.overlays])

	# (e) no slam: plate 1 stays covered.
	var other: Dictionary = m.breach_plates[1]
	var oc: Vector2 = other["rect"].get_center()
	for i in 60:
		await physics_frame
	_report("(e) unslammed plate stays upper", is_equal_approx(terrain.height(oc.x, oc.y), UPPER), "height %.3f" % terrain.height(oc.x, oc.y))

	# (f) a stage entry restores every plate.
	world._on_stage_entered(1, true)
	_report("(f) height back to upper", is_equal_approx(terrain.height(c.x, c.y), UPPER), "height %.3f" % terrain.height(c.x, c.y))
	_report("(f) cover home", cover.position == cover.get_meta("home"), str(cover.position))
	_report("(f) breach reset", world.breach != null and world.breach.broken.is_empty(), str(world.breach.broken if world.breach != null else null))

	# (g) a ball resting on plate 1 drops to drop_to after the slam.
	var ball := _ball(Vector3(oc.x, UPPER + Tuning.RADIUS + 2.0, oc.y))
	for i in SETTLE_FRAMES:
		await physics_frame
	var at := ball.global_position
	var gap: float = at.y - Tuning.RADIUS - terrain.height(at.x, at.z)
	_report("(g) ball rests on the cover", absf(gap) <= TOLERANCE, "y %.3f, gap %.3f" % [at.y, gap])
	world._on_slammed(Vector3(oc.x, UPPER + 1.0, oc.y), 20.0, 1.0)
	var reached := -1
	for frame in range(1, DROP_FRAMES + 1):
		await physics_frame
		at = ball.global_position
		gap = at.y - Tuning.RADIUS - terrain.height(at.x, at.z)
		if reached < 0 and absf(gap) <= TOLERANCE and is_equal_approx(terrain.height(at.x, at.z), float(other["drop_to"])):
			reached = frame
	_report("(g) ball agrees with drop_to within %d frames" % DROP_FRAMES, reached > 0,
		"first agreeing frame %d, y %.3f, height %.3f, drop_to %.1f" % [reached, at.y, terrain.height(at.x, at.z), other["drop_to"]])

	ball.free()
	_game.free()
	print("breach_plate_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


# The player's body as rigid_ball.gd sets it up (probe_dig_floor_drop_test.gd).
func _ball(at: Vector3) -> RigidBody3D:
	var ball := RigidBody3D.new()
	ball.can_sleep = false
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	material.bounce = 0.25
	ball.physics_material_override = material
	ball.gravity_scale = Tuning.new().f("gravity") / 9.8
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS
	shape.shape = sphere
	ball.add_child(shape)
	ball.position = at
	_game.add_child(ball)
	return ball
