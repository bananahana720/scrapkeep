extends SceneTree
# smoke: timeout=240s

# Forced-contact probe for the dam's eye_fin_east foot (red team on cf07ff61, random seed 2867 runner_gunner on the park
# table: the bot sat at (98, 103, 137) on "roll to spillway sheet" from 76 s to the 240 s stall cap; #456 met the same
# point at (100, 103, 137)). A per-tick contact read there found only the ground heightfield: a floor at 102.1 m and the
# fin's south face rising from z 138, uniform along x. So the stall was the bot's wall steering (bot_driver.gd
# _around_walls, now holding its side), and this test proves a player's ball there is not wedged.
#
# The real Game on the park table (stage 1, park_dam, calm, no Warden), the real ball and its scripted stick, set in the
# camera's frame each tick as a person's keys are. Each shot resets the ball at REST, just off the face, and holds one
# stick heading for SHOT_S:
#   square   due north, square into the face: the control. The ball meets the face and stays at its foot, so the probe
#            really is at the wall.
#   goal     straight at the sheet foot (the bot's goal, (5, 566)), 12 degrees off square: a player holding toward the
#            dam slides west along the foot toward the Eye's mouth.
#   east     the goal turned 1.5 rad toward +x, the bot's held east side: rolls along the foot.
#   west     the goal turned 1.5 rad toward -x, toward the Eye's mouth.
#   back     straight away from the face.
# Gate: every shot but square leaves the foot by at least LEAVE_M (planar), and square touches the face (its centre
# reaches FACE_Z less one radius and CONTACT_SLACK_M) without passing it (z under FACE_Z).

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

const REST := Vector3(98.0, 103.2, 136.6)
const GOAL := Vector3(5.0, 103.0, 566.0)
const FACE_Z := 138.0
const SHOT_S := 4.0
const LEAVE_M := 20.0
const CONTACT_SLACK_M := 0.1

var t := T.new("park_dam_fin_foot_probe_test")
var game
var source := Intent.Scripted.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = source
	game.flow.press_start()
	game.flow.choose_class(1)
	game.flow.enter_stage(1, Vector3.ZERO, false)
	await physics_frame
	await physics_frame
	t.eq("real Game plays the dam on the park table", game.ctx.terrain.map().title, "park_dam")
	var to_goal := Vector3(GOAL.x - REST.x, 0.0, GOAL.z - REST.z).normalized()
	var shots := {
		"square": Vector3(0.0, 0.0, 1.0),
		"goal": to_goal,
		"east": to_goal.rotated(Vector3.UP, 1.5),
		"west": to_goal.rotated(Vector3.UP, -1.5),
		"back": -to_goal,
	}
	var out := {}
	for name: String in shots:
		out[name] = await _shot(shots[name])
		print("  %s: end=%s moved=%.1f m max_z=%.2f" % [name, out[name]["end"], out[name]["moved"], out[name]["max_z"]])
	t.check("square: the ball meets the fin face", out["square"]["max_z"] >= FACE_Z - Tuning.RADIUS - CONTACT_SLACK_M,
			"max z %.2f" % out["square"]["max_z"])
	t.check("square: the ball stays south of the face", out["square"]["max_z"] < FACE_Z, "max z %.2f" % out["square"]["max_z"])
	t.check("square: the face holds it (control)", out["square"]["moved"] < LEAVE_M, "moved %.1f m" % out["square"]["moved"])
	for name in ["goal", "east", "west", "back"]:
		t.check("%s: rolls out of the foot" % name, out[name]["moved"] >= LEAVE_M, "moved %.1f m in %.0f s" % [out[name]["moved"], SHOT_S])
	game.free()
	quit(t.verdict())


func _shot(want: Vector3) -> Dictionary:
	var player = game.player
	player.reset_to(REST)
	source.hold = {}
	await physics_frame
	var max_z := -INF
	for tick in int(SHOT_S * Engine.physics_ticks_per_second):
		var yaw: float = game.camera.yaw
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		source.hold = {"move": Vector2(want.dot(right), want.dot(forward)).normalized()}
		await physics_frame
		max_z = maxf(max_z, player.ball_position().z)
	source.hold = {}
	var end: Vector3 = player.ball_position()
	return {"end": end, "moved": Vector2(end.x - REST.x, end.z - REST.z).length(), "max_z": max_z}
