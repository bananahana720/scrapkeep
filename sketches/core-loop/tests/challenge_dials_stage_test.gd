# per-stage dial lists; the mobs wire on the real combat, the pulse wire on a Warden
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Warden := preload("res://src/combat/warden.gd")
const Roster := preload("res://src/combat/roster.gd")
const T := preload("res://tests/support/t.gd")

# The per-stage lists (`*_by_stage`, six entries): parse and validation, the 1.0 read for any stage
# outside the list, stage_mult() as the global mult times the stage's entry, and two wire points
# driven for real: mobs.damage_by_stage through combat's enemy-hit door and
# warden.pulse_damage_by_stage through a Warden of that stage.
#
# Evidence limit: the Warden is stepped by hand with a parked ball, as challenge_dials_warden_test does.

class FlowDouble extends RefCounted:
	var row := {"warden_variant": "meltdown"}

	func stage_def() -> Dictionary:
		return row


class CtxDouble extends RefCounted:
	var events
	var flow := FlowDouble.new()


const KEYS := ["warden.pulse_damage_by_stage", "warden.pulse_cycle_by_stage", "warden.slag_damage_by_stage",
	"mobs.damage_by_stage", "mobs.pack_scale_by_stage", "mobs.interval_scale_by_stage", "mobs.elite_rate_by_stage"]
const DT := 1.0 / 90.0

var _t := T.new("challenge_dials_stage_test")
var _game
var _hits: Array = []
var _pulses: Array = []
# The shortest charge the last _pulse_at Warden pulsed after (warden.min_pulse_telegraph).
var _last_charge := 0.0


func _initialize() -> void:
	ChallengeDials.reset()
	_rules()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _rules() -> void:
	var parsed := ChallengeDials.parse("mobs.damage_by_stage=2/1/1.5/1/1/0.5,warden.pulse_cycle_by_stage=3")
	_t.eq("a six-entry list parses", parsed["mobs.damage_by_stage"], [2.0, 1.0, 1.5, 1.0, 1.0, 0.5])
	_t.eq("a short list parses as given", parsed["warden.pulse_cycle_by_stage"], [3.0])
	for key in KEYS:
		# World 1 mob hits ship at x2.6 on the dam and x2.5 on the flume (W46-S1), W2/3 at identity; its own checks are below.
		if key == "mobs.damage_by_stage":
			_t.eq("mobs.damage_by_stage ships x2.6 on the dam and x2.5 on the flume (W46-S1)", ChallengeDials.value(key), [2.6, 2.5, 1.0, 1.0, 1.0, 1.0])
			continue
		# World 1's Wardens pulse x4.0 / x4.5 (W46-S1), the flume's on a x0.85 cycle and x4.5 slag; their own checks are below.
		if key == "warden.pulse_damage_by_stage":
			_t.eq("warden.pulse_damage_by_stage ships x4.0/x4.5 on world 1 only (W46-S1)", ChallengeDials.value(key), [4.0, 4.5, 1.0, 1.0, 1.0, 1.0])
			continue
		if key == "warden.pulse_cycle_by_stage":
			_t.eq("warden.pulse_cycle_by_stage ships x0.85 on the flume only", ChallengeDials.value(key), [1.0, 0.85, 1.0, 1.0, 1.0, 1.0])
			continue
		if key == "warden.slag_damage_by_stage":
			_t.eq("warden.slag_damage_by_stage ships x4.5 on the flume only (W46-S1)", ChallengeDials.value(key), [1.0, 4.5, 1.0, 1.0, 1.0, 1.0])
			continue
		if key == "mobs.interval_scale_by_stage":
			_t.eq("mobs.interval_scale_by_stage ships x0.7 on the flume only (W1-31)", ChallengeDials.value(key), [1.0, 0.7, 1.0, 1.0, 1.0, 1.0])
			continue
		_t.eq("%s defaults to six 1.0" % key, ChallengeDials.value(key), [1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
		var all_one := true
		for stage in [-1, 0, 1, 2, 3, 4, 5, 6, 7, 99]:
			all_one = all_one and ChallengeDials.by_stage(key, stage) == 1.0
		_t.check("%s reads 1.0 for every stage and out of range" % key, all_one)
	_t.check("stage_mult is exactly 1.0 at defaults", ChallengeDials.stage_mult("mobs.damage", 3) == 1.0 and ChallengeDials.stage_mult("warden.slag_damage", 0) == 1.0)
	ChallengeDials.set_overrides({"mobs.damage_by_stage": [2, 1, 1, 1, 1, 1], "mobs.damage_mult": 1.5})
	_t.near("stage_mult multiplies the global mult and the stage entry", ChallengeDials.stage_mult("mobs.damage", 1), 3.0)
	_t.near("another stage reads the global mult alone", ChallengeDials.stage_mult("mobs.damage", 3), 1.5)
	_t.near("a stage past the list reads the global mult alone", ChallengeDials.stage_mult("mobs.damage", 7), 1.5)
	ChallengeDials.set_overrides({"mobs.pack_scale_by_stage": [1, 1, 1]})
	_t.near("a short list reads 1.0 past its end", ChallengeDials.by_stage("mobs.pack_scale_by_stage", 5), 1.0)
	ChallengeDials.reset()
	ChallengeDials.quiet = true
	ChallengeDials.set_overrides({"mobs.damage_by_stage": [2, -1, 1, 1, 1, 1]})
	_t.eq("a negative entry is refused", ChallengeDials.rejected.size(), 1)
	_t.eq("a refused list leaves the default", ChallengeDials.value("mobs.damage_by_stage"), ChallengeDials.DEFAULTS["mobs.damage_by_stage"])
	ChallengeDials.set_overrides({"warden.slag_damage_by_stage": ["x", 1]})
	_t.eq("a non-numeric entry is refused", ChallengeDials.rejected.size(), 2)
	ChallengeDials.set_overrides({"mobs.elite_rate_by_stage": []})
	_t.eq("an empty list is refused", ChallengeDials.rejected.size(), 3)
	ChallengeDials.parse("mobs.damage_by_stage=1/-2/1")
	_t.eq("a bad command-line list is refused", ChallengeDials.rejected.size(), 4)
	ChallengeDials.set_overrides({"mobs.damage_by_stage": 1.5, "brindle.damage_by_phase": 2.0})
	_t.eq("a scalar for a list dial is refused (by_stage and by_phase)", ChallengeDials.rejected.size(), 6)
	_t.eq("and leaves the (tuned) default", ChallengeDials.value("brindle.damage_by_phase"), [2.5, 3.2, 2.5, 1.0])
	ChallengeDials.reset()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_game.ctx.spawner = _game.combat
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	await physics_frame
	_game.run.max_hp = 100000.0
	_game.run.hp = 100000.0
	_game.ctx.events.player_hit.connect(func(amount: float, source: String): _hits.append([source, amount]))
	# Mobs at the defaults: the dam (stage 1) takes x2.6, the flume (stage 2) takes x2.5 (W46-S1).
	ChallengeDials.reset()
	for stage in [1, 2]:
		_game.run.stage = stage
		_hits.clear()
		_game.combat._on_player_hit(10.0, Vector3.ZERO, "chaser")
		var got := float(_hits[-1][1]) if not _hits.is_empty() else -1.0
		_t.near("default stage %d chaser hit" % stage, got, 26.0 if stage == 1 else 25.0)
	# Mobs: stage 1 triples, stage 3 does not.
	ChallengeDials.set_overrides({"mobs.damage_by_stage": [3, 1, 1, 1, 1, 1]})
	for stage in [1, 3]:
		_game.run.stage = stage
		_hits.clear()
		_game.combat._on_player_hit(10.0, Vector3.ZERO, "chaser")
		var got := float(_hits[-1][1]) if not _hits.is_empty() else -1.0
		_t.near("stage %d chaser hit with mobs.damage_by_stage [3,1,..]" % stage, got, 30.0 if stage == 1 else 10.0)
	# Warden at the defaults (W46-S1): the dam's pulse hits x4.0 and the flume's hits x4.5 on a 5.1 s
	# cycle (the dam keeps 6 s, wave 39), the Dig's is the base; the ring charges the same PULSE_TELEGRAPH seconds everywhere, so no tell is shorter.
	ChallengeDials.reset()
	for stage in [1, 2, 3]:
		var pulse_mult := 4.0 if stage == 1 else (4.5 if stage == 2 else 1.0)
		_t.near("default stage %d pulse hit" % stage, _pulse_at(stage), Warden.PULSE_DAMAGE * pulse_mult, 0.001)
		_t.near("default stage %d pulse cycle" % stage, Warden.pulse_cycle(stage), Warden.PULSE_CYCLE * (0.85 if stage == 2 else 1.0), 0.001)
		_t.near("default stage %d pulse telegraph is the whole PULSE_TELEGRAPH" % stage, Warden.pulse_telegraph(stage), Warden.PULSE_TELEGRAPH, 0.0)
		_t.near("default stage %d pulse charged that long on the Warden" % stage, _last_charge, Warden.PULSE_TELEGRAPH, DT + 0.0001)
	# The planted case: the lists at identity are the game before this unit; the same reads must give the
	# base hit and cycle, or the checks above say nothing about the dials.
	ChallengeDials.set_overrides({"warden.pulse_damage_by_stage": [1, 1, 1, 1, 1, 1], "warden.pulse_cycle_by_stage": [1, 1, 1, 1, 1, 1]})
	_t.near("planted: at identity the dam's pulse is the base hit", _pulse_at(1), Warden.PULSE_DAMAGE, 0.001)
	_t.near("planted: at identity the dam's cycle is the base cycle", Warden.pulse_cycle(1), Warden.PULSE_CYCLE, 0.001)
	# Warden: the pulse on a stage 1 and a stage 3 Warden.
	ChallengeDials.set_overrides({"warden.pulse_damage_by_stage": [2, 1, 1, 1, 1, 1], "warden.pulse_cycle_by_stage": [1, 1, 0.5, 1, 1, 1]})
	for stage in [1, 3]:
		var amount := _pulse_at(stage)
		_t.near("stage %d pulse with warden.pulse_damage_by_stage [2,1,..]" % stage, amount, Warden.PULSE_DAMAGE * (2.0 if stage == 1 else 1.0))
	_t.near("stage 1 pulse cycle is unmoved", Warden.pulse_cycle(1), Warden.PULSE_CYCLE)
	_t.near("stage 3 pulse cycle is halved", Warden.pulse_cycle(3), Warden.PULSE_CYCLE * 0.5)
	ChallengeDials.reset()
	_game.free()
	quit(_t.verdict())


# The damage of one pulse landing on a ball under a Warden's core ring (-1.0 if none landed).
func _pulse_at(stage: int) -> float:
	var fleet := preload("res://src/combat/fleet.gd").new()
	var ctx := CtxDouble.new()
	ctx.events = _game.ctx.events
	fleet.ctx = ctx
	fleet.combat = _game.ctx.spawner
	var warden := Warden.new()
	_game.add_child(warden)
	warden.position = Vector3(40.0, 0.0, 0.0)
	warden.setup(_game.player, _game.ctx.terrain, _game, func(): return false, 1.0,
		fleet.dress("warden", {"family": Roster.REACTOR, "stage": stage, "fleet": fleet, "plating": 30.0, "hp": 800.0}))
	_pulses.clear()
	warden.hit_player.connect(func(amount: float, _push: Vector3): _pulses.append(amount))
	var at := warden.global_position + Vector3(0.0, 1.0, 0.5)
	var guard := 0
	while warden.pulses == 0 and guard < 3000:
		_game.player._rigid.global_position = at
		_game.player.state.grounded = true
		warden._step_pulse(DT, true)
		guard += 1
	_last_charge = float(warden.min_pulse_telegraph)
	warden.free()
	fleet.free()
	return float(_pulses[0]) if not _pulses.is_empty() else -1.0
