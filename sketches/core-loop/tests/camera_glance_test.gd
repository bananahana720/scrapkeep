extends SceneTree

const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const BallState := preload("res://src/movement/ball_state.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Intent := preload("res://src/movement/intent.gd")
const Rows := preload("res://src/presentation/flourish_rows.gd")
const Cues := preload("res://src/presentation/flourish_cues.gd")
const T := preload("res://tests/support/t.gd")
const Comfort := preload("res://src/core/comfort.gd")

# Ruling bv: Brindle's entrance is on screen. The bowl entry aims the camera down the track and
# the Requisition lands across the bowl, off to one side, so his card and HONK played with the
# ship out of frame. The camera now glances at it (chase_camera.glance_at) and the player's look
# always wins. G1-G10 on a stand-in rig, stepped with a fixed delta: the glance lands on its
# subject, eases there, gives way to a mouse move or a stick push, shrugs off a bumped mouse,
# and is refused under reduced motion, cut by a snap and ended by a freed subject; a subject
# already in the picture starts none and one out at its edge does. R1: the
# arrival and both phase rows carry the beat in both forms. B1-B2 through the real flow: a bot's
# run never glances (its stream is the one the bands were measured on), and a hand on the
# controls gets the ship inside the middle of the view by the time the glance ends.

const DT := 1.0 / 60.0
const LAND_RAD := 0.035
const MIDDLE_RAD := 0.2

var _t = T.new("camera_glance_test")
var _game
var _started := false


class Tuning:
	func f(_key: String) -> float:
		return 20.0


class Target:
	var state := BallState.new()

	func shown_position() -> Vector3:
		return Vector3.ZERO


class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_started = true
	Harness.install(_game)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_run_all()
	return false


func _run_all() -> void:
	await process_frame
	_rig_checks()
	_row_checks()
	_flow_checks()
	var code: int = _t.verdict()
	_game.free()
	quit(code)


func _rig() -> Array:
	var cam := ChaseCamera.new()
	root.add_child(cam)
	cam.setup(Target.new(), Tuning.new())
	cam.snap(Vector3.FORWARD)
	var subject := Node3D.new()
	root.add_child(subject)
	subject.global_position = Vector3(30.0, 4.0, 0.0)
	return [cam, subject]


func _step(cam, frames: int) -> void:
	for i in frames:
		cam._process(DT)


# The angle between where the camera's yaw looks and the bearing to a point, on the ground plane.
func _off(cam, at: Vector3) -> float:
	var to: Vector3 = at - cam.global_position
	var forward: Vector3 = -cam.yaw_basis().z
	return absf(Vector2(forward.x, forward.z).angle_to(Vector2(to.x, to.z)))


func _rig_checks() -> void:
	var rig := _rig()
	var cam = rig[0]
	var subject: Node3D = rig[1]
	var before: float = _off(cam, subject.global_position)
	cam.glance_at(subject, 0.9)
	_step(cam, 27)
	var halfway: float = _off(cam, subject.global_position)
	_step(cam, 30)
	_t.check("G1 the glance lands on its subject and ends", _off(cam, subject.global_position) < LAND_RAD and not cam.glancing()
			and is_equal_approx(cam.pitch, ChaseCamera.GLANCE_PITCH), "off %.3f rad from %.3f, pitch %.2f, glancing %s" % [_off(cam, subject.global_position), before, cam.pitch, cam.glancing()])
	_t.check("G2 it eases: halfway it is part of the way", halfway > before * 0.2 and halfway < before * 0.8, "%.3f of %.3f rad" % [halfway, before])

	cam.snap(Vector3.FORWARD)
	cam.glance_at(subject, 0.9)
	_step(cam, 10)
	cam.look(Vector2(1.0, 0.0))
	cam.look(Vector2(0.0, 1.0))
	_t.check("G4 a bumped mouse does not end it", cam.glancing(), "")
	cam.look(Vector2(12.0, 0.0))
	var yaw_then: float = cam.yaw
	_step(cam, 60)
	_t.check("G3 a mouse move ends it where it is", not cam.glancing() and is_equal_approx(cam.yaw, yaw_then), "yaw %.3f then %.3f" % [cam.yaw, yaw_then])

	cam.snap(Vector3.FORWARD)
	cam.glance_at(subject, 0.9)
	_step(cam, 10)
	cam.look_stick(Vector2(0.6, 0.0), DT)
	_t.check("G5 a stick push ends it", not cam.glancing(), "")

	cam.snap(Vector3.FORWARD)
	Comfort.reduced_motion = true
	yaw_then = cam.yaw
	cam.glance_at(subject, 0.9)
	_step(cam, 60)
	_t.check("G6 reduced motion refuses it", not cam.glancing() and is_equal_approx(cam.yaw, yaw_then), "")
	Comfort.reduced_motion = false

	cam.glance_at(subject, 0.9)
	cam.snap(Vector3.FORWARD)
	_t.check("G7 a snap cuts it", not cam.glancing(), "")

	# The subject bears along +x. 0.45 rad off it is in the picture; 0.75 rad off is out at the
	# edge of a 16:9 lens (half-width 0.85 rad) and still worth the turn.
	cam.snap(Vector3(cos(0.45), 0.0, sin(0.45)))
	var pitch_then: float = cam.pitch
	cam.glance_at(subject, 0.9)
	_t.check("G9 a subject already in the picture starts none", not cam.glancing() and is_equal_approx(cam.pitch, pitch_then), "off %.3f rad" % _off(cam, subject.global_position))
	cam.snap(Vector3(cos(0.75), 0.0, sin(0.75)))
	cam.glance_at(subject, 0.9)
	_t.check("G10 a subject out at the edge of the picture starts one", cam.glancing(), "off %.3f rad" % _off(cam, subject.global_position))

	cam.snap(Vector3.FORWARD)
	cam.glance_at(subject, 0.9)
	_step(cam, 5)
	subject.free()
	_step(cam, 5)
	_t.check("G8 a freed subject ends it", not cam.glancing(), "")
	cam.free()


func _row_checks() -> void:
	var missing := []
	for id in ["brindle_arrival", "brindle_phase_2", "brindle_phase_3"]:
		for short in [false, true]:
			if not Cues.world_beats(id, short).any(func(b): return b.get("kind") == "glance" and b.get("anchor") == "ship"):
				missing.append("%s %s" % [id, "short" if short else "full"])
	_t.check("R1 the arrival and both phase rows glance at the ship, in both forms", missing.is_empty(), str(missing))
	var arrival: Array = Cues.world_beats("brindle_arrival", false).filter(func(b): return b.get("kind") == "glance")
	_t.check("R1 the arrival's glance ends inside the arrival", arrival.size() == 1 and float(arrival[0]["seconds"]) < Rows.length("brindle_arrival", false), "")


func _to_arena() -> void:
	_game.flow.enter_stage(3, Vector3(0.0, 0.0, 16.0), false)
	_game.flow._finish_stage()


func _flow_checks() -> void:
	var camera = _game.camera
	Harness.start_run(_game)
	_game.presentation.flourish.stop_all()
	_to_arena()
	var out_of_view: bool = not camera.in_view(_game.boss.ship.global_position)
	_t.check("B1 a bot's arrival plays with the ship out of the picture and never glances", _game.presentation.flourish.id == "brindle_arrival" and out_of_view and not camera.glancing(),
		"playing %s, ship out of the picture %s" % [_game.presentation.flourish.id, out_of_view])

	_game.flow.show_title()
	_game.bot_driven = false
	Harness.start_run(_game)
	_game.presentation.flourish.stop_all()
	_to_arena()
	var ship: Node3D = _game.boss.ship
	var before: float = _off(camera, ship.global_position)
	var began: bool = camera.glancing()
	_step(camera, 60)
	_t.check("B2 a hand on the controls gets the glance, and the ship ends in the middle of the view", began and not camera.glancing()
			and before > MIDDLE_RAD and _off(camera, ship.global_position) < MIDDLE_RAD,
		"began %s; off %.2f rad at entry, %.2f after" % [began, before, _off(camera, ship.global_position)])
	_game.bot_driven = true
