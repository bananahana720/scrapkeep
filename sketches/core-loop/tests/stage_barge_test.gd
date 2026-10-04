extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Contraptions := preload("res://src/world/contraptions.gd")

# The hover barge carries the ball (DESIGN-V2 section 8; I3 test 3). A ball set at rest
# on the west barge while it dwells at the rim deck rides the whole lane down to the
# west shelf and back: it never leaves the deck, its world drift matches the barge's
# within tolerance, and it ends where it started on the deck. The barge's lean toward
# the ball's weight is a scripted function a test can hold to its number.
#
# Evidence limit: calm, no input; a ball the player steers is free to roll off, which
# is the point of a barge you can leave.

const SIM_SCALE := 3.0
const ON_DECK := 6.0
const DRIFT := 1.5

# 2026-10-04: the authored gorge route remains on a test double after the alpha repoint.
# 2026-10-04: retire with F6 the local plating cases; keep the flow regression.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _failures := 0
var _ticks := 0
var _phase := "boot"
var _start_local := Vector3.ZERO
var _start_ball := Vector3.ZERO
var _start_barge := Vector3.ZERO
var _worst_local := 0.0
var _min_up := INF
var _sim := 0.0
var _mid_checked := false


func _initialize() -> void:
	_check_pure()
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _check_pure() -> void:
	var size := Vector3(14.0, 1.2, 14.0)
	var t := Contraptions.barge_tilt(Vector3(3.5, 0.0, -7.0), size)
	var want := Vector2(-1.0, -0.5) * deg_to_rad(Contraptions.BARGE_TILT)
	_report("scripted lean", t.is_equal_approx(want),
		"a ball 3.5 m to +x and 7 m to -z leans the deck (%.4f, %.4f) rad, wanted (%.4f, %.4f)" % [t.x, t.y, want.x, want.y])
	var spec := {"travel": 9.0, "dwell": 3.0}
	var o := [Contraptions.barge_offset(spec, 1.0), Contraptions.barge_offset(spec, 7.5), Contraptions.barge_offset(spec, 13.0),
		Contraptions.barge_offset(spec, 19.5), Contraptions.barge_offset(spec, 24.5)]
	_report("lane schedule", o[0] == 0.0 and absf(o[1] - 0.5) < 0.001 and o[2] == 1.0 and absf(o[3] - 0.5) < 0.001 and o[4] == 0.0,
		"dwell, half way out, dwell, half way back, home: %s" % [o])


func _barge():
	return _game.world.contraptions[2].barges[0]


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_phase = "enter"
		"enter":
			_game.flow.enter_stage(2, Vector3.ZERO, false)
			_phase = "place"
		"place":
			var b = _barge()
			var body: AnimatableBody3D = b["body"]
			var at: Vector3 = body.global_position + Vector3.UP * 4.0
			_game.player.reset_to(at)
			_game.player.body().global_position = at
			_phase = "settle"
			_ticks = 0
		"settle":
			if _ticks > 90:
				var body: AnimatableBody3D = _barge()["body"]
				_start_ball = _game.player.ball_position()
				_start_barge = body.global_position
				_start_local = _start_ball - _start_barge
				Engine.time_scale = SIM_SCALE
				_phase = "ride"
				_sim = 0.0
		"ride":
			_sim += delta
			var body: AnimatableBody3D = _barge()["body"]
			var ball: Vector3 = _game.player.ball_position()
			var local := ball - body.global_position
			_worst_local = maxf(_worst_local, Vector2(local.x - _start_local.x, local.z - _start_local.z).length())
			_min_up = minf(_min_up, local.y)
			if not _mid_checked and Contraptions.barge_offset(_barge()["spec"], _barge()["time"]) >= 0.999:
				_mid_checked = true
				var moved := body.global_position - _start_barge
				var carried := ball - _start_ball
				_report("carried to the far dock", absf(local.x) < ON_DECK and absf(local.z) < ON_DECK and (carried - moved).length() <= DRIFT,
					"barge moved %.1f m to %s, ball moved %.1f m; ball on deck at local (%.2f, %.2f), drift %.2f m"
						% [moved.length(), body.global_position, carried.length(), local.x, local.z, (carried - moved).length()])
			if _sim > 24.5:
				Engine.time_scale = 1.0
				var back := Vector2(local.x - _start_local.x, local.z - _start_local.z).length()
				_report("stays on through a round trip", _worst_local <= DRIFT and _min_up > 0.0 and back <= DRIFT,
					"over %.1f s the ball strayed at most %.2f m from its deck spot and never below the deck top (min %.2f m above the barge centre); back home %.2f m off"
						% [_sim, _worst_local, _min_up, back])
				print("stage_barge_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				_game.free()
				quit(0 if _failures == 0 else 1)
				return true
	return false
