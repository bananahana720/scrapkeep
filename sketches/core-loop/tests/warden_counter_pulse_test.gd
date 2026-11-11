# smoke: solo (the Warden counter-pulse dial: a second core ring inside a stagger, off by default)
extends SceneTree

const Game := preload("res://src/game.gd")
const Warden := preload("res://src/combat/warden.gd")
const Roster := preload("res://src/combat/roster.gd")
const T := preload("res://tests/support/t.gd")

# warden.counter_damage_by_stage / counter_telegraph_by_stage / counter_delay_by_stage: at the default
# (damage 0) a stagger builds nothing and hits nothing; with damage set, one core ring is committed
# counter_delay seconds in, charges for the floored telegraph and hits a ball inside it once; a
# stagger that ends first cancels it; the stagger, the posture and the chunks are unchanged.
#
# Evidence limit: the Warden is stepped by hand with a parked ball, as challenge_dials_warden_test does.

class FlowDouble extends RefCounted:
	var row := {"warden_variant": ""}

	func stage_def() -> Dictionary:
		return row


class CtxDouble extends RefCounted:
	var events
	var flow := FlowDouble.new()
	# The Warden reads the run's heft off its fleet's ctx; this fight has no run.
	var run = null


const DT := 1.0 / 90.0
const STAGE := 3
var _t := T.new("warden_counter_pulse_test")
var _game
var _hits: Array = []
var _vents: Array = []


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

	var off := await _stagger({}, true)
	_t.check("default: a full stagger passes with no counter and no hit", off["counters"] == 0 and off["hits"].is_empty() and not off["ring_after"], str(off))
	_t.eq("default: counter reads 0 at every stage and out of range", [Warden.counter_damage(0), Warden.counter_damage(STAGE), Warden.counter_damage(7)], [0.0, 0.0, 0.0])

	var dials := {"warden.counter_damage_by_stage": [0.0, 0.0, 20.0, 0.0, 0.0, 0.0]}
	var on := await _stagger(dials, true)
	_t.check("counter: one ring, one hit of 20", on["counters"] == 1 and on["hits"].size() == 1 and is_equal_approx(float(on["hits"][0]), 20.0), str(on))
	_t.check("counter: lands after delay + telegraph", absf(float(on["hit_at"]) - 1.8) < 0.05, str(on["hit_at"]))
	_t.check("counter: ring committed after the delay", absf(float(on["ring_at"]) - 1.0) < 0.05, str(on["ring_at"]))
	_t.check("counter: the ring is freed after landing", not on["ring_after"], str(on))
	_t.check("counter: reactor vent_charging fired once", on["vents"] == 1, str(on["vents"]))

	var away := await _stagger(dials, false)
	_t.check("a ball outside the core ring is not hit (ring still committed)", away["hits"].is_empty() and away["counters"] == 1 and not away["ring_after"], str(away))

	var fast := await _stagger({"warden.counter_damage_by_stage": [0.0, 0.0, 20.0, 0.0, 0.0, 0.0],
		"warden.counter_telegraph_by_stage": [0.1, 0.1, 0.1, 0.1, 0.1, 0.1], "warden.counter_delay_by_stage": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]}, true)
	_t.near("telegraph 0.1 floors at 0.6", float(fast["hit_at"]) - float(fast["ring_at"]), 0.6, 0.05)

	var short := await _stagger(dials, true, 1.5)
	_t.check("a stagger shorter than delay + telegraph cancels: no hit, no leaked ring", short["hits"].is_empty() and short["counters"] == 1 and not short["ring_after"], str(short))

	var twice := await _stagger(dials, true, 4.0)
	_t.check("at most one counter per stagger", twice["counters"] == 1 and twice["hits"].size() == 1, str(twice))
	var again := await _stagger_twice(dials)
	_t.check("a second stagger gets its own counter", again == 2, str(again))

	_t.check("the stagger length is unchanged by the counter", off["ticks"] == on["ticks"] and off["ticks"] == away["ticks"], "%s vs %s" % [off["ticks"], on["ticks"]])
	_t.check("posture and chunks are unchanged", off["sig"] == on["sig"] and off["hp"] == on["hp"] and off["pulses"] == on["pulses"], "%s %s" % [off["sig"], on["sig"]])

	ChallengeDials.quiet = true
	var bad := ChallengeDials.parse("warden.counter_damage_by_stage=-1")
	_t.check("a negative counter damage is refused", bad.is_empty() and not ChallengeDials.rejected.is_empty())
	ChallengeDials.quiet = false
	ChallengeDials.reset()
	_game.free()
	quit(_t.verdict())


func _make() -> Node:
	var fleet := preload("res://src/combat/fleet.gd").new()
	var ctx := CtxDouble.new()
	ctx.events = _game.events
	fleet.ctx = ctx
	fleet.combat = _game.ctx.spawner
	var warden := Warden.new()
	_game.add_child(warden)
	warden.position = Vector3(40.0, 0.0, 0.0)
	warden.setup(_game.player, _game.ctx.terrain, _game, func(): return false, 1.0,
		fleet.dress("warden", {"family": Roster.REACTOR, "stage": STAGE, "fleet": fleet, "plating": 30.0, "hp": 800.0}))
	warden.set_meta("fleet", fleet)
	return warden


func _place_ball(at: Vector3) -> void:
	_game.player._rigid.global_position = at
	_game.player.state.grounded = true


# One stagger on a fresh Warden, stepped like _physics_process does. Returns what happened.
func _stagger(dials: Dictionary, at_core: bool, seconds := 4.0) -> Dictionary:
	ChallengeDials.set_overrides(dials)
	var warden = _make()
	var fleet = warden.get_meta("fleet")
	warden._posture.stagger_seconds = seconds
	var out := {"hits": [], "vents": 0, "hit_at": -1.0, "ring_at": -1.0, "ticks": 0}
	warden.counter_hit.connect(func(amount: float, _push: Vector3):
		out["hits"].append(amount)
		out["hit_at"] = out["ticks"] * DT)
	var vents := [0]
	fleet.events().vent_charging.connect(func(_at, _len): vents[0] += 1)
	var spot: Vector3 = warden.global_position + (Vector3(0.0, 1.0, 0.5) if at_core else Vector3(0.0, 1.0, 12.0))
	_place_ball(spot)
	warden._apply_posture({"gain": 100.0})
	var guard := 0
	while warden.staggered() and guard < 2000:
		_place_ball(spot)
		warden._step_posture(DT)
		warden._step_pulse(DT, true)
		out["ticks"] += 1
		if out["ring_at"] < 0.0 and is_instance_valid(warden._counter_ring):
			out["ring_at"] = out["ticks"] * DT
		guard += 1
	warden._step_pulse(DT, true)
	await physics_frame
	await physics_frame
	out["counters"] = warden.counters
	out["ring_after"] = is_instance_valid(warden._counter_ring)
	out["sig"] = warden._posture_signature()
	out["hp"] = warden.hp
	out["pulses"] = warden.pulses
	out["vents"] = vents[0]
	warden.free()
	fleet.free()
	return out


func _stagger_twice(dials: Dictionary) -> int:
	ChallengeDials.set_overrides(dials)
	var warden = _make()
	var fleet = warden.get_meta("fleet")
	_place_ball(warden.global_position + Vector3(0.0, 1.0, 0.5))
	for round in 2:
		warden._apply_posture({"gain": 100.0})
		var guard := 0
		while warden.staggered() and guard < 2000:
			warden._step_posture(DT)
			warden._step_pulse(DT, true)
			guard += 1
		warden._step_pulse(DT, true)
	var n: int = warden.counters
	warden.free()
	fleet.free()
	return n
