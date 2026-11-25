extends SceneTree

const Game := preload("res://src/game.gd")
const Warden := preload("res://src/combat/warden.gd")
const Roster := preload("res://src/combat/roster.gd")
const T := preload("res://tests/support/t.gd")

# The Warden's dials (warden.gd) on a meltdown Warden: the pulse hit on a ball under the core ring and
# the slag burn on a ball in a filled lane scale with warden.pulse_damage_mult and slag_damage_mult;
# pulse_cycle_mult moves the pulse's start (cycle minus telegraph) and never under the 0.6 s floor.
#
# Evidence limit: the Warden is stepped by hand with a parked ball, as warden_meltdown_slag_test does.

class FlowDouble extends RefCounted:
	var row := {"warden_variant": "meltdown"}

	func stage_def() -> Dictionary:
		return row


class CtxDouble extends RefCounted:
	var events
	var flow := FlowDouble.new()


const DT := 1.0 / 90.0
var _t := T.new("challenge_dials_warden_test")
var _game
var _hits: Array = []


func _initialize() -> void:
	ChallengeDials.reset()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await physics_frame
	_game.run.set_max_hp(99999.0)
	for mult in [1.0, 2.0]:
		ChallengeDials.set_overrides({"warden.pulse_damage_mult": mult, "warden.slag_damage_mult": mult})
		_check(mult)
	ChallengeDials.set_overrides({"warden.pulse_cycle_mult": 0.5})
	_t.near("pulse_cycle_mult 0.5 halves the cycle", Warden.pulse_cycle(), Warden.PULSE_CYCLE * 0.5)
	ChallengeDials.set_overrides({"warden.pulse_cycle_mult": 0.01})
	_t.near("pulse cycle floors at 0.6", Warden.pulse_cycle(), 0.6)
	_t.check("telegraph never exceeds the cycle", Warden.pulse_telegraph() <= Warden.pulse_cycle())
	ChallengeDials.reset()
	_game.free()
	quit(_t.verdict())


func _place_ball(at: Vector3) -> void:
	_game.player._rigid.global_position = at
	_game.player.state.grounded = true


func _check(mult: float) -> void:
	var fleet := preload("res://src/combat/fleet.gd").new()
	var ctx := CtxDouble.new()
	ctx.events = _game.events
	fleet.ctx = ctx
	fleet.combat = _game.ctx.spawner
	var warden := Warden.new()
	_game.add_child(warden)
	warden.position = Vector3(40.0, 0.0, 0.0)
	warden.setup(_game.player, _game.ctx.terrain, _game, func(): return false, 1.0,
		fleet.dress("warden", {"family": Roster.REACTOR, "stage": 1, "fleet": fleet, "plating": 30.0, "hp": 800.0}))
	warden.hit_player.connect(func(amount: float, _push: Vector3): _hits.append(amount))
	# Pulse: the ball under the core ring when the pulse lands.
	_place_ball(warden.global_position + Vector3(0.0, 1.0, 0.5))
	_hits.clear()
	var guard := 0
	while warden.pulses == 0 and guard < 3000:
		_place_ball(warden.global_position + Vector3(0.0, 1.0, 0.5))
		warden._step_pulse(DT, true)
		guard += 1
	# This Warden stands on stage 1, where the pulse ships at x4.0 (W46-S1); the multiplier under test
	# multiplies on top of it.
	_t.check("x%.0f: the pulse landed on the core ring at the dam's x4.0" % mult, not _hits.is_empty() and is_equal_approx(float(_hits[0]), Warden.PULSE_DAMAGE * 4.0 * mult), str(_hits))
	# Slag: a filled lane burns a ball inside it for SLAG_DAMAGE per second.
	var lane: Dictionary = warden.slag_lanes[0] if warden.slag_lanes.size() == 1 else {}
	var node = lane.get("node")
	if node != null:
		var inside: Vector3 = lane["from"] + lane["dir"] * 5.0
		_place_ball(Vector3(inside.x, node.ground_under(node.terrain, inside) + 1.0, inside.z))
		_hits.clear()
		var t := 0.0
		while t < Warden.SLAG_WARN + 1.5 and _hits.is_empty() and not warden.slag_lanes.is_empty():
			warden._step_slag(DT)
			t += DT
		_t.check("x%.0f: the slag burn hits for SLAG_DAMAGE x mult" % mult, not _hits.is_empty() and is_equal_approx(float(_hits[0]), Warden.SLAG_DAMAGE * mult), str(_hits))
	else:
		_t.check("x%.0f: a slag lane was laid" % mult, false)
	warden.free()
	fleet.free()
