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
const StartPicks := preload("res://src/core/start_picks.gd")
const WordBudget := preload("res://src/core/word_budget.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Push := preload("res://tests/support/push.gd")

# Each lever and the way a harder rung moves it: up (hits, waits before regen) or down (cadence, regen rate).
const HARDER_UP := ["mobs.damage_mult", "warden.pulse_damage_mult", "brindle.damage_mult", "waking.damage_mult",
	"mind.damage_mult", "mobs.elite_rate_mult", "pilot.regen_delay_mult"]
const HARDER_DOWN := ["brindle.period_mult", "waking.period_mult", "mind.period_mult", "waking.punish_mult",
	"mind.punish_mult", "warden.pulse_cycle_mult", "mobs.interval_scale_mult", "pilot.regen_rate_mult"]

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
	_locked(game)
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
	await _unlock(game)
	_late_choice(game)
	paused = false
	game.free()
	ChallengeDials.reset()


# A fresh profile has no rung to pick: the card names how to open one and nothing of HARD's threat, pay or tiers
# (w22 first-timer red team watch 6), before and after stage 1's Warden closes the choice.
func _locked(game) -> void:
	var was: bool = game.bot_driven
	game.bot_driven = false
	game.flow._begin_run(ClassDef.all()[0])
	game.flow.show_start_card()
	var card = game.flow.start_card
	for closed in [false, true]:
		var label := "locked card%s" % (" after the Warden" if closed else "")
		var labels := _labels(card)
		t.check(label + " shows", card.showing() and card.is_processing_input())
		t.eq(label + " names only the unlock", labels, [card.UNLOCK_WORDS])
		t.check(label + " has no ladder", card.tier_button(0) == null and card.tier_button(1) == null and not card.ladder_shown())
		t.check(label + " keeps the reroll", card.reroll_button != null)
		t.check(label + " reports the same words", card.UNLOCK_WORDS in card.drawn_words()
			and not Array(card.drawn_words()).any(func(w): return String(w) in ["Tier", "Crowd", "Hits", "Regen", "Pay"]),
			"words %s" % [card.drawn_words()])
		if not closed:
			game.run.close_run_tier()
			game.flow.show_start_card()
	game.bot_driven = was


# Beating rung N opens N+1 (run_tier.gd BEST_STAT); the start card draws the ladder, with a pip to press
# for each rung the profile has opened and the selected rung's four gauges.
func _unlock(game) -> void:
	var profile = game.ctx.profile
	# The card draws its buttons only for a player (flow.show_start_card).
	game.bot_driven = false
	t.eq("first_win opens rung 1 only", RunTier.top_unlocked(profile), 1)
	t.eq("offered tiers", StartPicks.offered_tiers(profile), [0, 1])
	t.check("no locked profile tier", RunTier.top_unlocked(null) == 0 and not RunTier.unlocked(null, 1))
	game.flow.show_start_card()
	var card = game.flow.start_card
	t.check("the ladder shows", card.ladder_shown())
	t.check("one opened rung: pips for the base tier and rung 1 only", card.tier_button(0) != null and card.tier_button(1) != null and card.tier_button(2) == null)
	# At rest: the word, the selected rung's numeral and the four gauges, counted as the word budget counts.
	t.eq("the ladder's words at rest", Array(card.drawn_words()).slice(-6), ["Tier", "0", "Crowd", "Hits", "Regen", "Pay"])
	t.check("and no more than the held tier's line, so the ladder costs the page no more words than a held tier does",
		WordBudget.words_in(" ".join(Array(card.drawn_words()).slice(-6))) <= WordBudget.words_in("Tier 0 held for this run"))
	t.eq("the card writes no sentence under the tiles", _labels(card), [])
	t.check("at rest no rung's numbers are written", not RunTier.threat_text(1) in card.drawn_words() and not RunTier.pay_text(1) in card.drawn_words())
	# The rung looked at (the focus stands in for the mouse here): its numeral, and its contract in words.
	card.tier_button(1).grab_focus()
	t.eq("a looked-at rung adds its numeral and its two lines", Array(card.drawn_words()).slice(-9),
		["Tier", "0", "1", "Crowd", "Hits", "Regen", "Pay", RunTier.threat_text(1), RunTier.pay_text(1)])
	t.check("rung 1's lines say crowd, pace, plated elite brutes and pay, and no slower regen", "more crowd" in RunTier.threat_text(1)
		and "shorter intervals" in RunTier.threat_text(1) and "plated elite brutes" in RunTier.threat_text(1) and not "slower regen" in RunTier.threat_text(1))
	card.tier_button(0).grab_focus()
	t.eq("the base tier's line", Array(card.drawn_words()).slice(-1), ["The standard shift."])
	card.tier_button(0).release_focus()
	t.eq("looking away takes the lines off", Array(card.drawn_words()).slice(-6), ["Tier", "0", "Crowd", "Hits", "Regen", "Pay"])
	_gauges()
	# A won run on rung 1, through flow's own run end.
	game.flow.choose_run_tier(1)
	game.flow._end_run(true)
	t.eq("winning rung 1 records it", RunTier.best_rung(profile), 1)
	t.eq("and opens rung 2", RunTier.top_unlocked(profile), 2)
	t.check("a lower win never lowers the best", not RunTier.note_win(profile, 1) and RunTier.best_rung(profile) == 1)
	t.check("a base-tier win records nothing", not RunTier.note_win(profile, 0))
	game.flow._begin_run(ClassDef.all()[0])
	t.check("a player picks rung 2 once opened", game.flow.choose_run_tier(2))
	t.check("but not rung 3", not game.flow.choose_run_tier(3) and game.run.selected_run_tier() == 2)
	game.flow.choose_run_tier(0)
	RunTier.note_win(profile, 4)
	t.eq("rung 4 won opens the top", RunTier.top_unlocked(profile), RunTier.TOP)
	t.eq("all tiers offered", StartPicks.offered_tiers(profile), range(RunTier.TOP + 1))
	game.flow.show_start_card()
	t.check("every rung has a pip", range(RunTier.TOP + 1).all(func(tier): return card.tier_button(tier) != null))
	card.tier_button(RunTier.TOP).grab_focus()
	t.check("the top rung's lines disclose it", RunTier.threat_text(RunTier.TOP) in card.drawn_words()
		and RunTier.pay_text(RunTier.TOP) in card.drawn_words() and "slower regen" in RunTier.threat_text(RunTier.TOP))
	var picked := []
	for tier in [2, 5, 0, 3]:
		card.tier_button(tier).grab_focus()
		card.tier_button(tier).pressed.emit()
		picked.append(game.run.selected_run_tier())
		# flow redraws the card on a pick: the pips are new buttons, and the focus stays on the rung picked.
		t.check("the redrawn card keeps a pip for rung %d, still under the focus" % tier, card.tier_button(tier) != null
			and is_instance_valid(card.tier_button(tier)) and card.tier_button(tier).has_focus())
		t.eq("and writes the picked rung's numeral once", Array(card.drawn_words()).slice(Array(card.drawn_words()).find("Tier"), Array(card.drawn_words()).find("Crowd")),
			["Tier", str(tier)])
	t.eq("a pip picks its rung, up or down the ladder", picked, [2, 5, 0, 3])
	# The look is whichever of the focus and the mouse came to a pip last (the focus is on rung 3, just picked):
	# a mouse over another rung reads that rung before its click, and the stick takes the look back.
	Push.hover(root, card.tier_button(5))
	t.check("the mouse over rung 5 reads rung 5, the focus still on rung 3", card.tier_button(3).has_focus() and RunTier.threat_text(5) in card.drawn_words()
		and not RunTier.threat_text(3) in card.drawn_words() and "5" in card.drawn_words(), "words %s" % [card.drawn_words()])
	card.tier_button(1).grab_focus()
	t.check("the focus moved to rung 1 reads rung 1, the mouse still on rung 5", RunTier.threat_text(1) in card.drawn_words()
		and not RunTier.threat_text(5) in card.drawn_words(), "words %s" % [card.drawn_words()])
	Push.hover(root, card.tier_button(5))
	Push.hover(root, card.tier_button(4))
	t.check("the mouse moved on to rung 4 reads rung 4", RunTier.threat_text(4) in card.drawn_words() and not RunTier.threat_text(5) in card.drawn_words())
	var off := InputEventMouseMotion.new()
	off.position = Vector2(4.0, 4.0)
	off.global_position = off.position
	root.push_input(off, true)
	t.check("the mouse off the pips, the look falls back to the rung under the focus", RunTier.threat_text(1) in card.drawn_words()
		and not RunTier.threat_text(4) in card.drawn_words(), "words %s" % [card.drawn_words()])
	Push.click(root, card.tier_button(4))
	t.check("a click picks the rung it was reading, and keeps reading it", game.run.selected_run_tier() == 4 and RunTier.threat_text(4) in card.drawn_words(),
		"tier %d, words %s" % [game.run.selected_run_tier(), card.drawn_words()])
	card.tier_button(4).release_focus()
	off.position = Vector2(6.0, 6.0)
	off.global_position = off.position
	root.push_input(off, true)
	game.flow.choose_run_tier(3)
	t.eq("the pips sit left to right in rung order", range(RunTier.TOP + 1).map(func(tier): return card.tier_button(tier).position.x),
		_sorted(range(RunTier.TOP + 1).map(func(tier): return card.tier_button(tier).position.x)))
	t.check("the ladder and the reroll sit inside the card", Rect2(Vector2.ZERO, card.size).encloses(card.tier_button(0).get_rect())
		and Rect2(Vector2.ZERO, card.size).encloses(card.reroll_button.get_rect())
		and not card.reroll_button.get_rect().intersects(card.tier_button(RunTier.TOP).get_rect()),
		"card %s, pip 0 %s, reroll %s" % [card.size, card.tier_button(0).get_rect(), card.reroll_button.get_rect()])
	var widest := 0.0
	for tier in RunTier.TOP + 1:
		for line in RunTier.contract_lines(tier):
			widest = maxf(widest, UiFonts.width(line, card.CONTRACT_FONT))
	t.check("the longest contract line fits the narrowest ladder card", widest <= card.LADDER_W and card.size.x >= card.LADDER_W,
		"%.0f px in a card at least %.0f px wide (now %.0f)" % [widest, card.LADDER_W, card.size.x])
	# Every win records through flow._record_end, the victory lap's (_begin_ending) included.
	profile.set_stat(RunTier.BEST_STAT, 2.0)
	game.flow._record_end(true)
	t.eq("_record_end records the won rung", RunTier.best_rung(profile), 3)
	game.flow._begin_run(ClassDef.all()[0])
	game.flow.choose_run_tier(1)
	game.flow._record_end(false)
	t.eq("a loss records nothing", RunTier.best_rung(profile), 3)
	# The lab's tier on a resumed stage survives a retry (bot_run --run-tier with --from-stage).
	game.flow._begin_run(ClassDef.all()[0])
	game.run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	game.run.lab_run_tier(4)
	t.eq("lab tier set", game.run.run_tier, 4)
	game.run.restore()
	t.eq("a retry keeps the lab tier", game.run.run_tier, 4)
	game.run.lab_run_tier(0)
	t.eq("a top-rung win caps at the top", [RunTier.note_win(profile, RunTier.TOP + 2), RunTier.best_rung(profile)], [true, RunTier.TOP])
	game.flow._begin_run(ClassDef.all()[0])
	game.flow.show_start_card()
	t.check("a new run's card has the whole ladder", card.ladder_shown() and card.tier_button(RunTier.TOP) != null)


# The rung is chosen before stage 1's Warden fight (red team w21 speedrunner edge): engaging that Warden
# closes the choice, GATES and LAUNCH never take one, and a retry reopens it with the Warden replayed.
func _late_choice(game) -> void:
	var card = game.flow.start_card
	game.flow._begin_run(ClassDef.all()[0])
	game.flow.show_start_card()
	t.check("the choice is open before the Warden", game.run.run_tier_open() and game.flow.choose_run_tier(2))
	t.check("the open choice takes the cursor", card.wants_pointer())
	game.flow._engage()
	t.check("engaging stage 1's Warden closes it", not game.run.run_tier_open())
	t.check("no rung after the engage", not game.flow.choose_run_tier(3) and game.run.selected_run_tier() == 2)
	t.check("nor back to the base tier", not game.flow.choose_run_tier(0) and game.run.selected_run_tier() == 2)
	t.check("the card names the held tier", "Tier 2 held for this run" in _labels(card))
	t.check("and reports it to the word budget", "Tier 2 held for this run" in card.drawn_words()
		and not RunTier.threat_text(2) in card.drawn_words())
	t.check("and draws no ladder", card.tier_button(0) == null and card.tier_button(2) == null and not card.ladder_shown())
	t.check("and gives the mouse back to aim (w22 first-timer red team)", card.showing() and not card.wants_pointer())
	t.check("the start pick itself stays open", card.reroll_button != null and game.flow.take_start_pick(0))
	game.flow._unseal()
	t.eq("the Warden broken, the stage opens its gates", game.flow.NAMES[game.flow.state], game.flow.NAMES[game.flow.GATES])
	game.flow.retry_stage()
	t.check("a retry reopens it, the Warden replayed", game.run.run_tier_open() and not game.flow._engaged and game.flow.choose_run_tier(3))
	t.eq("the retry rewinds the pick", String(game.run.start_pick.get("taken", "")), "")
	game.flow._begin_run(ClassDef.all()[0])
	# A vanished Warden opens the gates with no engage (flow._warden_vanished).
	game.flow._unseal()
	t.check("no choice in gates", not game.flow.choose_run_tier(2) and game.run.selected_run_tier() == 0)
	game.flow._set_state(game.flow.LAUNCH)
	t.check("nor in launch", not game.flow.choose_run_tier(2) and game.run.selected_run_tier() == 0)
	game.flow.retry_stage()
	t.check("back in the stage it opens", game.flow.choose_run_tier(2))
	game.flow.choose_run_tier(0)


func _hits(d: Dictionary, prefix: String) -> float:
	var mobs := float(d.get("mobs.damage_mult", 1.0)) * float(d.get("mobs.elite_rate_mult", 1.0))
	var pulse := float(d.get("warden.pulse_damage_mult", 1.0)) / float(d.get("warden.pulse_cycle_mult", 1.0))
	var boss := float(d.get(prefix + "damage_mult", 1.0)) / float(d.get(prefix + "period_mult", 1.0))
	return (mobs + pulse + boss) / 3.0


func _sorted(values: Array) -> Array:
	var out := values.duplicate()
	out.sort()
	return out


# The gauges (RunTier.meters): the base tier reads at its mark on every gauge; up the ladder the works'
# gauges and the pay never shrink and regen never grows; the top rung fills crowd, hits and pay.
func _gauges() -> void:
	var names: Array = RunTier.meters(0).map(func(m): return m["name"])
	t.eq("four gauges, the works' two then the pilot's two", [names, RunTier.meters(0).map(func(m): return m["yours"])],
		[["Crowd", "Hits", "Regen", "Pay"], [false, false, true, true]])
	t.check("the base tier reads at its mark", RunTier.meters(0).all(func(m): return is_equal_approx(m["fill"], m["base"])))
	var ok := true
	for tier in range(1, RunTier.TOP + 1):
		var was: Array = RunTier.meters(tier - 1)
		var now: Array = RunTier.meters(tier)
		for i in now.size():
			if now[i]["name"] == "Regen":
				ok = ok and now[i]["fill"] <= was[i]["fill"] + 0.0001
			else:
				ok = ok and now[i]["fill"] >= was[i]["fill"] - 0.0001
			ok = ok and now[i]["fill"] <= 1.0001 and now[i]["fill"] > 0.0
	t.check("up the ladder crowd, hits and pay never shrink and regen never grows", ok)
	var top: Array = RunTier.meters(RunTier.TOP)
	t.check("the top rung fills crowd, hits and pay and cuts regen", [0, 1, 3].all(func(i): return is_equal_approx(top[i]["fill"], 1.0)) and top[2]["fill"] < top[2]["base"],
		"top %s" % [top])
	t.check("rung 1 adds crowd and pay but no harder hits", RunTier.meters(1)[0]["fill"] > RunTier.meters(1)[0]["base"]
		and is_equal_approx(RunTier.meters(1)[1]["fill"], RunTier.meters(1)[1]["base"]) and RunTier.meters(1)[3]["fill"] > RunTier.meters(1)[3]["base"])
	# Rung 1 changes both the crowd's size and its pace: the gauge reads past the size alone.
	t.check("the crowd gauge reads the pace with the size", RunTier.meters(1)[0]["fill"] / RunTier.meters(1)[0]["base"] > float(Cards.RUN_TIERS[1].cap_weight) + 0.0001)
	# Every dial a rung turns is read by a gauge (run_tier.gd _readings), so a new dial needs a gauge
	# or a line in the contract before this list takes it.
	var read := ["mobs.damage_mult", "mobs.elite_rate_mult", "mobs.interval_scale_mult", "warden.pulse_damage_mult", "warden.pulse_cycle_mult",
		"brindle.damage_mult", "brindle.period_mult", "waking.damage_mult", "waking.period_mult",
		"mind.damage_mult", "mind.period_mult", "pilot.regen_delay_mult", "pilot.regen_rate_mult"]
	var contracted := ["waking.punish_mult", "mind.punish_mult"]
	var turned := {}
	for rung in RunTier.LADDER:
		for key in RunTier.LADDER[rung]:
			turned[key] = true
	t.eq("every dial the ladder turns is read by a gauge", turned.keys().filter(func(key): return not key in read and not key in contracted), [])
	for world in RunTier.BOSS_PREFIX_BY_WORLD:
		var prefix: String = RunTier.BOSS_PREFIX_BY_WORLD[world]
		var top_dials: Dictionary = RunTier.dials(RunTier.TOP)
		var top_hits := _hits(top_dials, prefix)
		for rung in range(1, RunTier.TOP + 1):
			var d: Dictionary = RunTier.dials(rung)
			t.near("world %d rung %d: the hits gauge reads %sdamage_mult over %speriod_mult" % [world, rung, prefix, prefix],
				RunTier.meters(rung, world)[1]["fill"], _hits(d, prefix) / top_hits)
			t.eq("world %d rung %d: the contract names a tighter opening when %spunish_mult turns" % [world, rung, prefix],
				"tighter boss openings" in RunTier.threat_text(rung, world), world > 1 and d.has(prefix + "punish_mult"))
			for key in RunTier.dials_for_world(rung, world):
				t.check("world %d rung %d turns no other world's boss: %s" % [world, rung, key],
					not RunTier.ALL_BOSS_PREFIXES.any(func(other): return other != prefix and String(key).begins_with(other)))
	# Each of them moves its gauge: every rung that turns a works dial reads above the rung below.
	var strict := true
	for tier in range(2, RunTier.TOP + 1):
		strict = strict and RunTier.meters(tier)[1]["fill"] > RunTier.meters(tier - 1)[1]["fill"] and RunTier.meters(tier)[0]["fill"] > RunTier.meters(tier - 1)[0]["fill"]
	t.check("crowd and hits rise on every rung from 2 up", strict)
	t.check("regen falls on rungs 4 and 5", RunTier.meters(4)[2]["fill"] < RunTier.meters(3)[2]["fill"] and RunTier.meters(5)[2]["fill"] < RunTier.meters(4)[2]["fill"])


func _labels(card) -> Array:
	var out := []
	for node in card.get_children():
		if node is Label:
			out.append(node.text)
	return out


# ChallengeDials.f, by name: a literal `.f("key")` reads as a tuning.gd row key to sketch-lint L3.
func _dial(key: String) -> float:
	return ChallengeDials.f(key)
