# smoke: solo (the dials as pure rules, then the Waking and the Mind on the real ball)
extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Waking := preload("res://src/boss/waking.gd")
const WakingAttacks := preload("res://src/boss/waking_attacks.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Warden := preload("res://src/combat/warden.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Director := preload("res://src/world/director.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const PRESSURE_ZERO := ["pack.lead_by_stage", "pack.crew_extra_by_stage", "pack.flank_by_stage", "ground.churn_by_stage", "hazard.boil_by_stage"]
# Dials whose default is tuned for world 1 by wave 37 (ruling cu), one line a unit; each value is pinned in _init.
const W37_TUNED := [
	"mobs.chaser_speed_by_stage",  # D2
	"warden.pulse_damage_by_stage",  # D6
	"warden.pulse_cycle_by_stage",  # D6
	"mobs.clock_tiers_by_stage",  # D3
	"hazard.boil_stall_by_stage",  # D5
	"hazard.boil_crawl_by_stage",  # D5
]
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


func _raw_identity() -> float:
	ChallengeDials.set_overrides({"brindle.period_by_phase": [1.0, 1.0, 1.0, 1.0]})
	var v := ChallengeDials.period("brindle", 3.4, 1)
	ChallengeDials.reset()
	return v


func _rules() -> void:
	_t.eq("no override: describe is empty", ChallengeDials.describe(), {})
	for key in ChallengeDials.DEFAULTS:
		if not ChallengeDials.value(key) == ChallengeDials.DEFAULTS[key]:
			_t.check("default " + key, false)
	_t.eq("default damage_by_phase", ChallengeDials.value("waking.damage_by_phase"), [1.0, 1.0, 1.0, 1.0])
	_t.near("default damage is the base", ChallengeDials.damage("mind", 10.0, 2), 10.0, 0.0)
	# Brindle ships tuned (Spillway PR): the per-phase lists carry the band-swept values, every other key is identity.
	_t.eq("brindle tuned period_by_phase", ChallengeDials.value("brindle.period_by_phase"), [0.6, 0.5, 1.0, 1.0])
	_t.eq("brindle tuned damage_by_phase", ChallengeDials.value("brindle.damage_by_phase"), [1.0, 2.0, 1.3, 1.0])
	_t.near("tuned Requisition period", ChallengeDials.period("brindle", Rules.CRANE_PERIOD, 1), Rules.CRANE_PERIOD * 0.6, 1e-6)
	_t.near("tuned Furnace period", ChallengeDials.period("brindle", 2.0, 2), 1.0, 1e-6)
	_t.near("Scuttle and chase periods are the base", ChallengeDials.period("brindle", 2.0, 3), 2.0, 0.0)
	_t.near("tuned Furnace damage", ChallengeDials.damage("brindle", 10.0, 2), 20.0, 1e-6)
	_t.near("chase damage is the base", ChallengeDials.damage("brindle", 10.0, 4), 10.0, 0.0)
	_t.eq("a --tune/override REPLACES the tuned list: 1/1/1/1 is the raw identity", _raw_identity(), 3.4)
	_t.eq("and the tuned default returns after reset", ChallengeDials.value("brindle.period_by_phase"), [0.6, 0.5, 1.0, 1.0])
	for key in ChallengeDials.DEFAULTS:
		# The tuned lists, and the fight-phase follow-up counts (a count, not a multiplier; Andrew's
		# 23 Oct phase ruling sets them, fight_phases.gd).
		# The silt boils ship on world 1 (pack pressure E, 24 Oct); the dam's mob hits ship at x1.5 (w19 bands).
		# Crews lead the roll by half on world 1 (wave 37 unit D1).
		if key in ["brindle.period_by_phase", "brindle.damage_by_phase", "brindle.follow_ups_by_phase", "hazard.boil_by_stage", "mobs.damage_by_stage", "pack.lead_by_stage"]:
			continue
		# Wave 37's other world 1 defaults, each pinned below: chasers run at 9 m/s (unit D2).
		if key in W37_TUNED:
			continue
		var d: Variant = ChallengeDials.DEFAULTS[key]
		var ident: bool = true
		if d is Array:
			for x in d:
				# The counter-pulse and the pack pressure dials are absolute values whose identity is 0 (off).
				ident = ident and (float(x) == 1.0 or key.contains("counter") or (key in PRESSURE_ZERO and float(x) == 0.0))
		else:
			ident = float(d) == 1.0 or key == "brindle.combo" or key.ends_with(".combo") or key.ends_with(".weak_points")
		if not ident:
			_t.check("identity default " + key, false)
	_t.eq("the dam's mob hits ship at x1.5, every other stage at identity", ChallengeDials.value("mobs.damage_by_stage"), [1.5, 1.0, 1.0, 1.0, 1.0, 1.0])
	_t.eq("crews lead the roll by half on world 1, nowhere else", ChallengeDials.value("pack.lead_by_stage"), [0.5, 0.5, 0.0, 0.0, 0.0, 0.0])
	_t.eq("chasers run at 9 m/s on world 1, their own speed after it", ChallengeDials.value("mobs.chaser_speed_by_stage"), [9.0, 9.0, 0.0, 0.0, 0.0, 0.0])
	_t.eq("world 1 Wardens pulse x1.3, later ones at identity", ChallengeDials.value("warden.pulse_damage_by_stage"), [1.3, 1.3, 1.0, 1.0, 1.0, 1.0])
	_t.eq("world 1 Wardens pulse on a x0.85 cycle, later ones at identity", ChallengeDials.value("warden.pulse_cycle_by_stage"), [0.85, 0.85, 1.0, 1.0, 1.0, 1.0])
	_t.eq("the clock climbs three tiers on world 1, two after it", ChallengeDials.value("mobs.clock_tiers_by_stage"), [3.0, 3.0, 2.0, 2.0, 2.0, 2.0])
	_t.eq("the boils read the stall on world 1, the loop after it", ChallengeDials.value("hazard.boil_stall_by_stage"), [1.0, 1.0, 0.0, 0.0, 0.0, 0.0])
	_t.eq("the stall's crawl line on world 1, none after it", ChallengeDials.value("hazard.boil_crawl_by_stage"), [0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	_t.eq("weak points ship off on both bosses for wave 18", [ChallengeDials.value("waking.weak_points"), ChallengeDials.value("mind.weak_points")], [0.0, 0.0])
	_t.near("default tell is the base", ChallengeDials.tell("brindle", Rules.CRANE_WARN), Rules.CRANE_WARN, 0.0)

	var parsed := ChallengeDials.parse("mind.damage_mult=1.5,waking.damage_by_phase=1/1.25/1.5/2,brindle.combo=2")
	_t.eq("parse floats", parsed["mind.damage_mult"], 1.5)
	_t.eq("parse _by_phase arrays", parsed["waking.damage_by_phase"], [1.0, 1.25, 1.5, 2.0])
	_t.eq("parse the combo", parsed["brindle.combo"], 2.0)
	_t.eq("phase_min_by_phase parses as a list", ChallengeDials.parse("waking.phase_min_by_phase=0/0.5/1/2")["waking.phase_min_by_phase"], [0.0, 0.5, 1.0, 2.0])
	_t.eq("phase_min_by_phase defaults to the identity multiplier", ChallengeDials.value("mind.phase_min_by_phase"), [1.0, 1.0, 1.0, 1.0])
	ChallengeDials.quiet = true
	_t.eq("parse drops an unknown key", ChallengeDials.parse("nope.nothing=3").size(), 0)
	_t.eq("the unknown key is recorded as refused", ChallengeDials.rejected, ["challenge_dials: unknown dial 'nope.nothing' ignored"])
	ChallengeDials.quiet = false
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

	# The tell floor: what the committed hazard shows never drops under Hazard.MIN_WARN (the Mind's
	# WARN_FLOOR), and tell() is the identity at tell_mult 1.
	ChallengeDials.set_overrides({"brindle.tell_mult": 0.1, "waking.tell_mult": 0.1, "mind.tell_mult": 0.1,
		"warden.pulse_cycle_mult": 0.01})
	for w in [Rules.CRANE_WARN, Rules.SLAG_WARN, Rules.CHARGE_WARN]:
		_t.near("brindle tell %.1f floors at MIN_WARN" % w, ChallengeDials.tell("brindle", w, Hazard.MIN_WARN), Hazard.MIN_WARN, 0.0)
	var center := Vector3(5.0, 12.0, -3.0)
	var ball := center + Vector3(10.0, 0.0, 4.0)
	var least := INF
	for phase in range(1, 5):
		for family in WakingAttacks.exposed(phase):
			for d in WakingAttacks.commit(family, 7, ball, Vector3.ZERO, center, phase, RADIUS):
				var h = MindAttacks.build(d)
				least = minf(least, h.warn_seconds)
				h.free()
	_t.check("committed waking hazards at tell_mult 0.1 stay >= MIN_WARN", least >= Hazard.MIN_WARN - 1e-6 and least < INF, str(least))
	least = INF
	for phase in range(1, MindAttacks.phase_cap() + 1):
		for family in MindAttacks.exposed(phase):
			for d in MindAttacks.commit(family, 7, ball, center, phase, RADIUS):
				var h = MindAttacks.build(d)
				least = minf(least, h.warn_seconds)
				h.free()
	_t.check("committed mind hazards at tell_mult 0.1 stay >= WARN_FLOOR", least >= MindAttacks.WARN_FLOOR - 1e-6 and least < INF, str(least))
	_t.check("warden pulse cycle floors at 0.6", Warden.pulse_cycle() >= 0.6, str(Warden.pulse_cycle()))
	_t.check("warden telegraph is never longer than the cycle", Warden.pulse_telegraph() <= Warden.pulse_cycle()
			and Warden.pulse_telegraph() >= 0.6, str(Warden.pulse_telegraph()))
	ChallengeDials.reset()
	_t.near("tell is the identity at tell_mult 1", ChallengeDials.tell("mind", 1.7, MindAttacks.WARN_FLOOR), 1.7, 0.0)
	_t.near("default warden cycle", Warden.pulse_cycle(), Warden.PULSE_CYCLE, 0.0)
	_t.near("default warden telegraph", Warden.pulse_telegraph(), Warden.PULSE_TELEGRAPH, 0.0)
	ChallengeDials.set_overrides({"brindle.period_mult": 0.001})
	_t.near("a period never drops under the warning gap", ChallengeDials.period("brindle", Rules.CRANE_PERIOD, 1), ChallengeDials.WARN_GAP, 0.0)
	ChallengeDials.reset()

	# --tune parsing refuses what it cannot read: no silent zeros. Quiet, so the refusals this block
	# feeds on purpose are recorded and counted below instead of printed as ERROR lines.
	ChallengeDials.quiet = true
	_t.eq("a non-numeric value is ignored", ChallengeDials.parse("mind.damage_mult=abc").size(), 0)
	_t.eq("a negative multiplier is ignored", ChallengeDials.parse("mind.damage_mult=-1").size(), 0)
	_t.eq("a bad entry in a by-phase list is ignored", ChallengeDials.parse("mind.damage_by_phase=1/x/2/3").size(), 0)
	_t.eq("a negative by-phase entry is ignored", ChallengeDials.parse("mind.damage_by_phase=1/-1/2/3").size(), 0)
	_t.eq("pilot dials are refused without --tune-unruled", ChallengeDials.parse("pilot.regen_rate_mult=2").size(), 0)
	_t.eq("a good entry beside a bad one is kept", ChallengeDials.parse("mind.damage_mult=abc,mind.combo=1"), {"mind.combo": 1.0})
	ChallengeDials.set_overrides({"mind.damage_mult": -1.0, "mind.combo": "abc", "pilot.regen_rate_mult": 2.0, "mind.punish_mult": 3.0})
	_t.eq("set_overrides refuses negative, non-numeric and pilot values", ChallengeDials.describe(), {"mind.punish_mult": 3.0})
	ChallengeDials.set_overrides({"pilot.regen_rate_mult": 2.0}, true)
	_t.eq("set_overrides takes a pilot dial only with the opt-in", ChallengeDials.describe(), {"pilot.regen_rate_mult": 2.0})
	_t.eq("each refused entry is recorded once per refusal", ChallengeDials.rejected.size(), 9)
	_t.check("the refusals name their dials", ChallengeDials.rejected.all(func(m): return m.begins_with("challenge_dials: dial '")))
	ChallengeDials.reset()
	_t.eq("reset clears the refusals and quiet", [ChallengeDials.rejected.size(), ChallengeDials.quiet], [0, false])
	_director()


# The director's crowd cap, spawn interval, pack share and elite repeat read the mobs dials.
func _director() -> void:
	var d = Director.new(0)
	d.spike = true
	var cap0: int = d.cap()
	var interval0: float = d.interval()
	var share0: float = d.reinforcement_weight()
	ChallengeDials.set_overrides({"mobs.pack_scale_mult": 2.0, "mobs.interval_scale_mult": 3.0})
	_t.eq("pack_scale_mult doubles the crowd cap", d.cap(), cap0 * 2)
	_t.near("interval_scale_mult triples the spawn interval", d.interval(), interval0 * 3.0, 0.0001)
	_t.check("pack_scale_mult raises the pack share, under PACK_MAX", d.reinforcement_weight() > share0 + 1e-6 and d.reinforcement_weight() <= Director.PACK_MAX, "%.3f -> %.3f" % [share0, d.reinforcement_weight()])
	ChallengeDials.reset()
	d.spike = false
	for path in ["credit", "authored"]:
		var counts := []
		for mult in [0.0, 1.0e6]:
			ChallengeDials.set_overrides({"mobs.elite_rate_mult": mult})
			var e = Director.new(5)
			e.elite = {"id": "elite", "kinds": ["chaser"]}
			e.elite_arrival = 1
			e.authored = [{"id": "plain", "kinds": ["chaser"]}] if path == "authored" else []
			var n := 0
			for i in 100:
				e._arrivals_made = 1
				e._last_was_elite = false
				var credit: Dictionary = e._draw_authored() if path == "authored" else e._draw_credit()
				n += 1 if credit.get("id", "") == "elite" else 0
			counts.append(n)
		_t.eq("elite_rate_mult 0 never repeats the elite (%s draw)" % path, counts[0], 0)
		_t.eq("elite_rate_mult huge always repeats it (%s draw)" % path, counts[1], 100)
	ChallengeDials.reset()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	Harness.boot(_game)
	_game.ctx.events.player_hit.connect(func(amount: float, source: String): _hits.append([source, amount]))
	await _hazard("The Waking", 2, "waking", "cave_in", "waking_cave_in", WakingAttacks.DAMAGE["cave_in"])
	await _combo("The Waking", 2, "waking")
	await _period("The Waking", 2, "waking", Waking.ATTACK_PERIOD)
	await _waking_punish()
	await _waking_clock_after_jam()
	await _hazard("The Mind", 3, "mind", "rush", "mind_rush", 10.0)
	await _combo("The Mind", 3, "mind")
	await _period("The Mind", 3, "mind", 3.5)
	await _mind_punish()
	await _mind_clock_after_plate()
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


# period_mult 2 doubles the clock set when an attack commits.
func _period(label: String, world: int, boss: String, base: float) -> void:
	var mod = Harness.module(_game, world)
	mod._clear_attacks()
	mod._combo_left = -1
	for mult in [1.0, 2.0]:
		ChallengeDials.set_overrides({boss + ".period_mult": mult})
		mod.clock = 100.0
		mod._attack_clock = 0.0
		var seen: int = mod.attack_count
		var frames := 0
		while mod.attack_count == seen and frames < 90 * 3:
			await physics_frame
			frames += 1
		_t.check("%s period x%.0f" % [label, mult], mod.attack_count != seen and absf(mod._attack_clock - base * mult) < 0.05,
				"%.3f s, want %.1f" % [mod._attack_clock, base * mult])
		mod._clear_attacks()
	ChallengeDials.reset()


# The bore's jam lasts BORE_JAM x punish_mult and ends a combo; the breach window scales and ends one.
func _waking_punish() -> void:
	var mod = Harness.module(_game, 2)
	var center: Vector3 = Vector3(mod._center.x, mod._top(), mod._center.z)
	mod._attack_clock = 1.0e9
	mod._clear_attacks()
	ChallengeDials.set_overrides({"waking.punish_mult": 2.0, "waking.combo": 2.0})
	mod._combo_left = 2
	var d := {"family": "bore", "family_index": 3, "id": "waking_bore_0", "shape": "annulus", "type": Threat.Type.INSTANT,
		"warn": 1.0, "live": 1.0, "height": WakingAttacks.HEIGHT, "at": center, "band": Vector2(0.0, 6.0), "delay": 0.0}
	var h = MindAttacks.build(d)
	h.ground = Callable(mod, "ground_height_at")
	mod.ctx.root.add_child(h)
	mod.attacks.append({"hazards": [h], "family": "bore", "landed": false, "descs": [d]})
	var frames := 0
	while not h.is_live() and frames < 90 * 3:
		await physics_frame
		frames += 1
	await physics_frame
	var left: float = mod._jammed_until - mod.clock
	_t.check("the bore jam lasts BORE_JAM x2", mod.jammed() and left >= Waking.BORE_JAM * 2.0 and left <= Waking.BORE_JAM * 2.0 + 1.1, "%.2f s" % left)
	_t.eq("the jam drops the owed combo", mod._combo_left, -1)
	mod._clear_attacks()
	# The breach window: a slam 3 s after a floor drop is outside the 2 s default and inside x2.
	mod.warden.set("_staggered", false)
	for mult in [1.0, 2.0]:
		ChallengeDials.set_overrides({"waking.punish_mult": mult})
		mod._combo_left = 2
		mod._dropped_at = mod.clock - 3.0
		mod._on_enemy_struck(mod.warden, "slam", 1.0)
		_t.eq("breach window x%.0f %s the owed combo" % [mult, "keeps" if mult == 1.0 else "drops"], mod._combo_left, 2 if mult == 1.0 else -1)
	ChallengeDials.reset()


# The plate's weak window scales in the descriptor and in the Mind's own clock, and ends a combo; a
# hand carries the Mind's phase.
func _mind_punish() -> void:
	var mod = Harness.module(_game, 3)
	mod._attack_clock = 1.0e9
	mod._clear_attacks()
	ChallengeDials.set_overrides({"mind.punish_mult": 2.0, "mind.combo": 2.0})
	var ball: Vector3 = _game.ctx.player.ball_position()
	var center: Vector3 = mod.pad.global_position if is_instance_valid(mod.pad) else mod.warden.global_position
	var plate: Array = MindAttacks.plate(1, ball, center, 4)
	_t.near("plate descriptor weak_window is PLATE_WINDOW x2", float(plate[0]["weak_window"]), MindAttacks.PLATE_WINDOW * 2.0)
	mod._combo_left = 2
	mod.clock = 100.0
	mod._commit_attack("plate")
	var span: float = mod._plate_until - mod.clock
	_t.check("the Mind's plate window runs PLATE_WINDOW x2 past the plate", span >= MindAttacks.PLATE_WINDOW * 2.0 + 1.0 and span < MindAttacks.PLATE_WINDOW * 2.0 + 4.0, "%.2f s" % span)
	_t.eq("the plate drops the owed combo", mod._combo_left, -1)
	mod._clear_attacks()
	ChallengeDials.reset()
	mod.phase = 3
	mod._send_hand()
	var hands: Array = mod.hands.filter(func(x): return is_instance_valid(x))
	_t.check("a sent hand carries the Mind's phase", not hands.is_empty() and hands[0].boss_phase == 3, str(hands.size()))


# With follow-ups owed, a bore jam pushes the attack clock back to the normal period: no commit
# sooner than that inside the jam, not one 0.2 s later.
func _waking_clock_after_jam() -> void:
	var mod = Harness.module(_game, 2)
	var center: Vector3 = Vector3(mod._center.x, mod._top(), mod._center.z)
	mod._clear_attacks()
	ChallengeDials.set_overrides({"waking.combo": 2.0})
	mod.clock = 100.0
	mod._attack_clock = 1.0e9
	var d := {"family": "bore", "family_index": 3, "id": "waking_bore_0", "shape": "annulus", "type": Threat.Type.INSTANT,
		"warn": 1.0, "live": 1.0, "height": WakingAttacks.HEIGHT, "at": center, "band": Vector2(0.0, 6.0), "delay": 0.0}
	var h = MindAttacks.build(d)
	h.ground = Callable(mod, "ground_height_at")
	mod.ctx.root.add_child(h)
	mod.attacks.append({"hazards": [h], "family": "bore", "landed": false, "descs": [d]})
	var frames := 0
	while not h.is_live() and frames < 90 * 3:
		await physics_frame
		frames += 1
	mod._combo_left = 2
	mod._attack_clock = ChallengeDials.WARN_GAP
	var seen: int = mod.attack_count
	for i in int(2.5 * 90.0):
		await physics_frame
	_t.eq("no attack commits for 2.5 s after a jam with a combo owed", mod.attack_count, seen)
	_t.check("the clock was pushed back to the normal period", mod._attack_clock > 0.5, "%.2f s left" % mod._attack_clock)
	mod._clear_attacks()
	ChallengeDials.reset()


# With follow-ups owed, a plate's weak window pushes the attack clock to the normal period.
func _mind_clock_after_plate() -> void:
	var mod = Harness.module(_game, 3)
	mod._clear_attacks()
	ChallengeDials.set_overrides({"mind.combo": 2.0})
	mod._combo_left = -1
	mod._brace_due = true
	mod.clock = 100.0
	mod._attack_clock = 0.0
	var seen: int = mod.attack_count
	var frames := 0
	while mod.attack_count == seen and frames < 90:
		await physics_frame
		frames += 1
	_t.check("the plate led the chain", mod.attack_count == seen + 1 and mod._family == "plate", "%d, %s" % [mod.attack_count, mod._family])
	seen = mod.attack_count
	for i in int(2.5 * 90.0):
		await physics_frame
	_t.eq("no attack commits for 2.5 s after the plate with a combo owed", mod.attack_count, seen)
	mod._clear_attacks()
	ChallengeDials.reset()
