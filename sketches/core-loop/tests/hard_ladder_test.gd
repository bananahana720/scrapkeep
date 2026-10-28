extends SceneTree
# The HARD ladder's rungs (src/core/run_tier.gd LADDER, Cards.RUN_TIERS; Andrew 27 Oct option 3, ruling al):
# the data's shape, the rung dials reaching ChallengeDials through the run tier, enemy health untouched at
# every rung, pilot regen cut on the top rungs only, and rungs above HARD locked to players for now.

const T := preload("res://tests/support/t.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const Cards := preload("res://src/world/director_cards.gd")
const Director := preload("res://src/world/director.gd")
const Park := preload("res://src/core/park_defs.gd")
const Game := preload("res://src/game.gd")
const Profile := preload("res://src/core/profile.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# Each lever and the way a harder rung moves it: up (hits, waits before regen) or down (cadence, regen rate).
const HARDER_UP := ["mobs.damage_mult", "warden.pulse_damage_mult", "brindle.damage_mult", "mobs.elite_rate_mult",
	"pilot.regen_delay_mult"]
const HARDER_DOWN := ["brindle.period_mult", "warden.pulse_cycle_mult", "mobs.interval_scale_mult", "pilot.regen_rate_mult"]

var t := T.new("hard_ladder_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_data()
	_dials_follow_tier()
	await _production()
	quit(t.verdict())


func _data() -> void:
	t.eq("five rungs", RunTier.TOP, 5)
	t.eq("rung 1 is the old HARD", RunTier.HARD, 1)
	t.eq("rung 1 has no attack dials", RunTier.dials(1), {})
	t.eq("the base tier has none", RunTier.dials(0), {})
	var previous := {}
	for rung in range(1, RunTier.TOP + 1):
		var d: Dictionary = RunTier.dials(rung)
		t.check("rung %d has a row" % rung, Cards.RUN_TIERS.has(rung))
		for key in d:
			t.check("rung %d %s is a scalar dial" % [rung, key], ChallengeDials.DEFAULTS.has(key) and not ChallengeDials.DEFAULTS[key] is Array)
			t.check("rung %d %s is an allowed lever" % [rung, key], key in HARDER_UP or key in HARDER_DOWN)
			t.check("rung %d %s never eases" % [rung, key], float(d[key]) >= 1.0 if key in HARDER_UP else float(d[key]) <= 1.0)
		for key in previous:
			t.check("rung %d keeps %s from the rung below" % [rung, key], d.has(key))
			if d.has(key):
				t.check("rung %d %s at least as hard" % [rung, key],
					float(d[key]) >= float(previous[key]) if key in HARDER_UP else float(d[key]) <= float(previous[key]))
		var regen := d.has("pilot.regen_delay_mult") or d.has("pilot.regen_rate_mult")
		t.check("rung %d: regen cut on the top rungs only" % rung, not regen or rung >= RunTier.TOP - 1)
		var row := RunTier.row(rung)
		var below := RunTier.row(rung - 1)
		t.check("rung %d crowd at least the rung below" % rung, float(row.cap_weight) >= float(below.cap_weight))
		t.check("rung %d pace at least the rung below" % rung, float(row.interval_weight) <= float(below.interval_weight))
		t.check("rung %d pay at least the rung below" % rung, float(row.event_core_multiplier) >= float(below.event_core_multiplier))
		t.check("rung %d pay within the cap" % rung, float(row.event_core_multiplier) <= RunTier.PAY_GAIN_CAP and float(row.rare_weight) <= RunTier.PAY_GAIN_CAP)
		t.eq("rung %d keeps the hard elite plating" % rung, row.elite_stats, Cards.RUN_TIERS[1].elite_stats)
		previous = d
	t.eq("top rung pays the cap", float(RunTier.row(RunTier.TOP).event_core_multiplier), RunTier.PAY_GAIN_CAP)
	t.check("the top rung cuts regen", RunTier.dials(RunTier.TOP).has("pilot.regen_rate_mult"))
	t.eq("a tier past the top reads the top row", RunTier.row(RunTier.TOP + 3), RunTier.row(RunTier.TOP))
	# Ruling al: no tier raises enemy health.
	for row in Park.DEFS:
		for tier_value in range(RunTier.BASE, RunTier.TOP + 1):
			var d = Director.new(77)
			d.use_row(row, "", func(): return tier_value)
			d.threat = float(row.threat)
			t.eq("health is threat only, stage %d tier %d" % [row.stage, tier_value], d.hp_scale(), float(row.threat))


func _dials_follow_tier() -> void:
	ChallengeDials.reset()
	var base_damage := _dial("mobs.damage_mult")
	var run = load("res://src/core/run_state.gd").new()
	run.run_tier = RunTier.TOP
	var top: Dictionary = RunTier.dials(RunTier.TOP)
	for key in top:
		t.near("top rung sets " + key, _dial(key), float(ChallengeDials.DEFAULTS[key]) * float(top[key]))
	t.near("rung dial rides on the stage dial", ChallengeDials.stage_mult("mobs.damage", 1),
		float(top["mobs.damage_mult"]) * ChallengeDials.by_stage("mobs.damage_by_stage", 1))
	ChallengeDials.set_overrides({"mobs.damage_mult": 2.0})
	t.near("rung dial multiplies an override", _dial("mobs.damage_mult"), 2.0 * float(top["mobs.damage_mult"]))
	ChallengeDials.set_overrides({})
	t.eq("records name the rung dials", ChallengeDials.rung(), top)
	t.eq("describe stays overrides only", ChallengeDials.describe(), {})
	run.run_tier = RunTier.HARD
	t.eq("rung 1 clears them", _dial("mobs.damage_mult"), base_damage)
	run.run_tier = RunTier.TOP
	run.run_tier = RunTier.BASE
	t.eq("the base tier clears them", _dial("pilot.regen_rate_mult"), 1.0)
	# Regen at the top rung: later and slower than at the base tier, from the same hit.
	var healed := []
	for tier_value in [RunTier.BASE, RunTier.TOP]:
		run.run_tier = tier_value
		run.hp = run.max_hp * 0.5
		run.since_damage = 0.0
		for i in 600:
			run.advance(1.0 / 60.0)
		healed.append(run.hp - run.max_hp * 0.5)
	t.check("top rung regen heals less in 10 s", healed[1] < healed[0] * 0.5, "base %s top %s" % healed)
	t.check("base regen heals", healed[0] > 0.0)
	run.run_tier = RunTier.BASE
	ChallengeDials.reset()


func _production() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	await process_frame
	paused = true
	game.presentation.audio.process_mode = Node.PROCESS_MODE_DISABLED
	game.ctx.calm = true
	game.ctx.profile = Profile.new("user://hard_ladder_test/unused.json")
	game.ctx.profile.load_profile()
	game.ctx.profile.can_save = false
	game.ctx.profile.earn("first_win", 1.0)
	game.flow._begin_run(ClassDef.all()[0])
	t.check("a player cannot pick rung 2 yet", not game.flow.choose_run_tier(2) and game.run.selected_run_tier() == 0)
	t.check("nor past the top", not game.flow.choose_run_tier(RunTier.TOP + 1, false))
	t.check("the bots' --run-tier picks the top rung", game.flow.choose_run_tier(RunTier.TOP, false))
	t.near("and its dials apply", _dial("mobs.damage_mult"), float(RunTier.dials(RunTier.TOP)["mobs.damage_mult"]))
	t.check("rung 1 stays the player's HARD", game.flow.choose_run_tier(1))
	t.eq("rung 1 drops the top dials", _dial("mobs.damage_mult"), 1.0)
	game.flow.choose_run_tier(RunTier.TOP, false)
	game.flow._begin_run(ClassDef.all()[0])
	t.eq("a new run starts at the base tier", ChallengeDials.rung(), {})
	paused = false
	game.free()
	ChallengeDials.reset()


# ChallengeDials.f, by name: a literal `.f("key")` reads as a tuning.gd row key to sketch-lint L3.
func _dial(key: String) -> float:
	return ChallengeDials.f(key)
