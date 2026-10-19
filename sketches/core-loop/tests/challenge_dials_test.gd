# smoke: solo (the dials as pure rules, then the Waking and the Mind on the real ball)
extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Waking := preload("res://src/boss/waking.gd")
const WakingAttacks := preload("res://src/boss/waking_attacks.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Warden := preload("res://src/combat/warden.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const T := preload("res://tests/support/t.gd")

# The difficulty dials (src/core/challenge_dials.gd): defaults, parsing, the 0.6 s tell floor, damage
# and combo on the real Waking and Mind. The byte-identity proof for default dials is
# tests/run_tier_test.gd (20 pinned whole-run hashes).
#
# Evidence limit: Brindle's wire points (boss.gd) are covered through the shared helper
# functions here, not a Brindle fight; combo is read from the module's own attack clock on
# a parked ball, not from dodging.

const RADIUS := 36.0
var _t := T.new("challenge_dials_test")
var _game
var _hits: Array = []


func _initialize() -> void:
	ChallengeDials.reset()
	_rules()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _rules() -> void:
	_t.eq("no override: describe is empty", ChallengeDials.describe(), {})
	for key in ChallengeDials.DEFAULTS:
		if not ChallengeDials.value(key) == ChallengeDials.DEFAULTS[key]:
			_t.check("default " + key, false)
	_t.eq("default damage_by_phase", ChallengeDials.value("waking.damage_by_phase"), [1.0, 1.0, 1.0, 1.0])
	_t.near("default damage is the base", ChallengeDials.damage("mind", 10.0, 2), 10.0, 0.0)
	_t.near("default period is the base", ChallengeDials.period("brindle", Rules.CRANE_PERIOD, 1), Rules.CRANE_PERIOD, 0.0)
	_t.near("default tell is the base", ChallengeDials.tell("brindle", Rules.CRANE_WARN), Rules.CRANE_WARN, 0.0)

	var parsed := ChallengeDials.parse("mind.damage_mult=1.5,waking.damage_by_phase=1/1.25/1.5/2,brindle.combo=2")
	_t.eq("parse floats", parsed["mind.damage_mult"], 1.5)
	_t.eq("parse _by_phase arrays", parsed["waking.damage_by_phase"], [1.0, 1.25, 1.5, 2.0])
	_t.eq("parse the combo", parsed["brindle.combo"], 2.0)
	_t.eq("parse drops an unknown key", ChallengeDials.parse("nope.nothing=3").size(), 0)
	ChallengeDials.set_overrides(parsed)
	_t.eq("override wins", ChallengeDials.value("mind.damage_mult"), 1.5)
	_t.eq("describe lists only the non-defaults", ChallengeDials.describe().keys().size(), 3)
	_t.near("by-phase multiplier reads the phase", ChallengeDials.damage("waking", 8.0, 3), 12.0)
	_t.near("phase past the array clamps", ChallengeDials.damage("waking", 8.0, 9), 16.0)
	_t.eq("combo reads as an integer", ChallengeDials.combo("brindle"), 2)
	_t.eq("combo chain: lead owes two", ChallengeDials.combo_step("brindle", -1), 2)
	_t.eq("combo chain: a follow-up owes one", ChallengeDials.combo_step("brindle", 2), 1)
	ChallengeDials.reset()
	_t.eq("reset restores defaults", ChallengeDials.describe(), {})

	# The 0.6 s floor on every boss family's warn computation.
	ChallengeDials.set_overrides({"brindle.tell_mult": 0.1, "waking.tell_mult": 0.1, "mind.tell_mult": 0.1,
		"warden.pulse_cycle_mult": 0.01})
	for w in [Rules.CRANE_WARN, Rules.SLAG_WARN, Rules.CHARGE_WARN]:
		_t.near("brindle tell %.1f floors at 0.6" % w, ChallengeDials.tell("brindle", w), 0.6, 0.0)
	var center := Vector3(5.0, 12.0, -3.0)
	var ball := center + Vector3(10.0, 0.0, 4.0)
	var least := INF
	for phase in range(1, 5):
		for family in WakingAttacks.exposed(phase):
			for d in WakingAttacks.commit(family, 7, ball, Vector3.ZERO, center, phase, RADIUS):
				least = minf(least, float(d["warn"]))
	_t.check("waking tells with tell_mult 0.1 stay >= 0.6", least >= 0.6 - 1e-6 and least < INF, str(least))
	least = INF
	for phase in range(1, MindAttacks.phase_cap() + 1):
		for family in MindAttacks.exposed(phase):
			for d in MindAttacks.commit(family, 7, ball, center, phase, RADIUS):
				least = minf(least, float(d["warn"]))
	_t.check("mind tells with tell_mult 0.1 stay >= 0.6", least >= 0.6 - 1e-6 and least < INF, str(least))
	_t.check("warden pulse cycle floors at 0.6", Warden.pulse_cycle() >= 0.6, str(Warden.pulse_cycle()))
	_t.check("warden telegraph is never longer than the cycle", Warden.pulse_telegraph() <= Warden.pulse_cycle()
			and Warden.pulse_telegraph() >= 0.6, str(Warden.pulse_telegraph()))
	ChallengeDials.reset()
	_t.near("default warden cycle", Warden.pulse_cycle(), Warden.PULSE_CYCLE, 0.0)
	_t.near("default warden telegraph", Warden.pulse_telegraph(), Warden.PULSE_TELEGRAPH, 0.0)
	ChallengeDials.set_overrides({"brindle.period_mult": 0.001})
	_t.near("a period never drops under the warning gap", ChallengeDials.period("brindle", Rules.CRANE_PERIOD, 1), ChallengeDials.WARN_GAP, 0.0)
	ChallengeDials.reset()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	Harness.boot(_game)
	_game.ctx.events.player_hit.connect(func(amount: float, source: String): _hits.append([source, amount]))
	await _hazard("The Waking", 2, "waking", "cave_in", "waking_cave_in", WakingAttacks.DAMAGE["cave_in"])
	await _combo("The Waking", 2, "waking")
	await _hazard("The Mind", 3, "mind", "rush", "mind_rush", 10.0)
	await _combo("The Mind", 3, "mind")
	_game.free()
	ChallengeDials.reset()
	quit(_t.verdict())


# A ring over the parked ball lands once; with damage_mult 2 it lands for double.
func _hazard(label: String, world: int, boss: String, family: String, source: String, base: float) -> void:
	Harness.enter_world(_game, world)
	var mod = Harness.module(_game, world)
	if not _t.check(label + " module is up", mod != null):
		return
	_game.run.max_hp = 100000.0
	_game.run.hp = 100000.0
	mod._attack_clock = 1.0e9
	var center: Vector3 = Vector3(mod._center.x, mod._top(), mod._center.z) if "_center" in mod else Vector3(mod.pad.global_position.x, mod._top(), mod.pad.global_position.z)
	var player = _game.ctx.player
	var parked := center + Vector3(0.0, 1.2, 18.0)
	player.reset_to(parked, Vector3.ZERO)
	player.body().global_position = parked
	for i in 20:
		await physics_frame
	for mult in [1.0, 2.0]:
		ChallengeDials.set_overrides({boss + ".damage_mult": mult})
		_hits.clear()
		var d := {"family": family, "family_index": 1, "id": "dials_test_ring", "shape": "annulus", "type": Threat.Type.INSTANT,
			"warn": 1.0, "live": 1.0, "height": WakingAttacks.HEIGHT, "at": center, "band": Vector2(0.0, 36.0), "delay": 0.0}
		var h = MindAttacks.build(d)
		h.ground = Callable(mod, "ground_height_at")
		mod.ctx.root.add_child(h)
		var attack := {"hazards": [h], "family": family, "landed": false, "descs": [d]}
		mod.attacks.append(attack)
		while not h.is_done():
			await physics_frame
		var mine: Array = _hits.filter(func(e): return e[0] == source)
		_t.check("%s hit lands once at x%.0f" % [label, mult], attack["landed"] and mine.size() == 1, str(_hits))
		_t.near("%s hit is %.0f x %.0f" % [label, base, mult], float(mine[0][1]) if not mine.is_empty() else -1.0, base * mult)
		mod._clear_attacks()
	ChallengeDials.reset()


# combo=1 queues one extra attack a warning gap after the lead, then the normal period resumes.
func _combo(label: String, world: int, boss: String) -> void:
	var mod = Harness.module(_game, world)
	ChallengeDials.set_overrides({boss + ".combo": 1.0})
	mod._clear_attacks()
	mod._combo_left = -1
	mod.clock = 100.0
	mod._attack_clock = 0.0
	var start: int = mod.attack_count
	var at: Array = []
	var frames := 0
	var last: int = start
	while frames < 90 * 12 and at.size() < 3:
		await physics_frame
		frames += 1
		if mod.attack_count != last:
			last = mod.attack_count
			at.append(frames)
	_t.check(label + " combo=1 commits three attacks (lead, follow-up, next period)", at.size() == 3, str(at))
	if at.size() == 3:
		var gap := float(at[1] - at[0]) / 90.0
		_t.check(label + " follow-up comes a warning gap after the lead", gap >= ChallengeDials.WARN_GAP - 0.001 and gap <= ChallengeDials.WARN_GAP + 0.05, "%.3f s" % gap)
		var rest := float(at[2] - at[1]) / 90.0
		_t.check(label + " normal period resumes after the follow-up", rest > 2.0, "%.3f s" % rest)
	if not "warnings" in mod:
		ChallengeDials.reset()
		return  # the Mind has no warning log: its follow-up is the 0.2 s attack clock above
	var gaps: Array = []
	for i in range(1, mod.warnings.size()):
		gaps.append(mod.warnings[i]["at"] - mod.warnings[i - 1]["at"])
	_t.check(label + " no two warnings within the gap", gaps.all(func(g): return g >= WakingAttacks.GAP - 0.001), str(gaps))
	ChallengeDials.reset()
