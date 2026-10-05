extends SceneTree

# Rule (world._on_slammed, breach.gd under): a slam that breaks a Dig breach plate sends
# one world_fact("breach_opened") and strikes, as a "slam" contact, every live enemy in
# the broken plate's rect on the tier below. An enemy on the upper tier, a ball resting
# on the cover and a second slam strike nothing. The row's cue is the breach_crack recipe.
# Evidence limit: live headless Game on a one-stage Dig table with both chasers parked
# (physics off, so they hold their tier); no camera, mix or feel claim.

const T := preload("res://tests/support/t.gd")
const DigTable := preload("res://tests/doubles/dig_table_defs.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Augments := preload("res://src/movement/augments.gd")
const Breach := preload("res://src/world/breach.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Rows := preload("res://src/presentation/rows.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")

const UPPER := 12.0
const STRENGTH := 1.0
const REST_FRAMES := 60
const HP := 500.0


class DigGame extends "res://src/game.gd":
	func _chosen_table():
		return DigTable


var _game
var _facts: Array[String] = []
var _struck := {}
# combat.resolve() read inside the strike, so the heft the slam itself changes (the
# discovery it marks) is the heft the hit used.
var _resolved := {}


func _initialize() -> void:
	_run()


func _run() -> void:
	var t := T.new("breach_attack_test")
	_game = DigGame.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	var waited := 0
	while not _game.flow.in_stage() and waited < 120:
		waited += 1
		await physics_frame
	t.check("in stage", _game.flow.in_stage(), "after %d frames" % waited)
	var combat = _game.ctx.spawner
	_game.events.world_fact.connect(func(kind: String, _at: Vector3): _facts.append(kind))
	_game.events.enemy_struck.connect(func(enemy, kind: String, struck_force: float):
		var id: int = enemy.get_instance_id()
		_struck[id] = _struck.get(id, []) + [kind]
		_resolved[id] = {"force": struck_force, "dealt": combat.resolve(enemy, kind, struck_force)["dealt"]})
	var world = _game.world
	var terrain = _game.ctx.terrain
	var plate: Dictionary = terrain.map().breach_plates[0]
	var id: String = plate["id"]
	var c: Vector2 = plate["rect"].get_center()

	# Scratch read of the pit floor under the cover: lift the overlay, read, restore.
	terrain.overlays.erase(id + "_before")
	var floor_y: float = terrain.height(c.x, c.y)
	terrain.overlays.append(id + "_before")
	t.near("pit floor is drop_to", floor_y, float(plate["drop_to"]), 0.01)
	t.near("cover reads upper", terrain.height(c.x, c.y), UPPER, 0.01)

	var below := _chaser(combat, Vector3(c.x, floor_y + 1.6, c.y))
	var above := _chaser(combat, Vector3(c.x + 4.0, UPPER + 1.6, c.y + 4.0))
	t.check("control inside the rect", plate["rect"].has_point(Vector2(above.global_position.x, above.global_position.z)),
		str(above.global_position))

	# A ball resting on the cover strikes nothing.
	var ball := _ball(Vector3(c.x - 3.0, UPPER + Tuning.RADIUS + 1.0, c.y - 3.0))
	for i in REST_FRAMES:
		await physics_frame
	var gap: float = ball.global_position.y - Tuning.RADIUS - UPPER
	t.check("ball rests on the cover", absf(gap) <= 0.3, "gap %.3f" % gap)
	t.eq("rest: below hp", below.hp, HP)
	t.eq("rest: no strikes", _struck.size(), 0)
	t.eq("rest: plate whole", world.breach.breached(id), false)

	# One slam at the centre: the plate breaks, one fact, one slam strike below.
	var force := Augments.SLAM_KNOCK * STRENGTH
	_facts.clear()
	world._on_slammed(Vector3(c.x, UPPER + 1.0, c.y), STRENGTH, 1.0)
	t.check("plate broken", world.breach.breached(id), str(world.breach.broken))
	t.eq("one breach_opened fact", _facts, [Breach.FACT])
	t.eq("below struck once by slam", _struck.get(below.get_instance_id(), []), ["slam"])
	var hit: Dictionary = _resolved.get(below.get_instance_id(), {"force": 0.0, "dealt": 0.0})
	t.near("strike force is SLAM_KNOCK * strength", hit["force"], force)
	t.check("below hp dropped by resolve dealt", hit["dealt"] > 0.0 and is_equal_approx(HP - below.hp, hit["dealt"]),
		"force %.1f, dealt %.3f, hp %.3f -> %.3f" % [hit["force"], hit["dealt"], HP, below.hp])
	t.eq("upper-tier control not struck", _struck.get(above.get_instance_id(), []), [])

	# A second slam adds nothing.
	var hp_after: float = below.hp
	world._on_slammed(Vector3(c.x, UPPER + 1.0, c.y), STRENGTH, 1.0)
	t.eq("second slam: no new fact", _facts, [Breach.FACT])
	t.eq("second slam: no new strike", _struck.get(below.get_instance_id(), []).size(), 1)
	t.eq("second slam: hp held", below.hp, hp_after)

	# The cue, measured as audio_row_coverage_test does.
	t.check("recipe breach_crack", SfxBank.has_recipe("breach_crack"))
	var wav := SfxBank.stream("breach_crack")
	var peak := Synth.wav_peak(wav)
	var seconds := wav.data.size() / 2.0 / wav.mix_rate
	t.check("peak breach_crack", peak >= 0.1, "peak %.4f" % peak)
	t.eq("16-bit breach_crack", wav.format, AudioStreamWAV.FORMAT_16_BITS)
	t.check("length breach_crack", seconds > 0.02 and seconds < 0.6, "%.6f s" % seconds)
	var samples := SfxBank.samples("breach_crack")
	t.check("not fallback blip breach_crack", samples.size() != int(0.12 * SfxBank.RATE), "%d samples" % samples.size())

	if EventKinds.WORLD_ROWS.has(Breach.FACT):
		var row: Dictionary = EventKinds.world_row(Breach.FACT)
		t.eq("row matches Breach.ROW", row, Breach.ROW)
		# 2026-10-04: plate_crack_rubble_fall has no recipe yet, so the row is heard as its
		# sound. Flips to plate_crack_rubble_fall when that recipe lands.
		if SfxBank.has_recipe("plate_crack_rubble_fall"):
			t.eq("row heard", Rows.heard(row), "plate_crack_rubble_fall")
		else:
			t.eq("row heard", Rows.heard(row), "breach_crack")
	else:
		print("[pending] breach_opened row: coordinator adds it at integrate")

	ball.free()
	_game.free()
	quit(t.verdict())


func _chaser(combat, at: Vector3) -> Node3D:
	var enemy: Node3D = combat.spawn_enemy("chaser", at)
	enemy.hp = HP
	enemy.max_hp = HP
	enemy.set_physics_process(false)
	enemy.set_process(false)
	enemy.global_position = at
	return enemy


# The player's body as rigid_ball.gd sets it up (breach_plate_test.gd).
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
