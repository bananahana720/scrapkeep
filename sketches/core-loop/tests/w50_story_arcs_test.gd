extends SceneTree

# W50-STORY-ARCS falsifiable test suite (spec §5.4 predicates 1-9 + planted negative controls).
# Pure-data / headless verification of PilotStory, LoreRows W2/W3 additive extensions,
# CampLines 3rd-arg backward compatibility, and PrologueRows W2/W3 act notes.

const PilotStory := preload("res://src/core/pilot_story.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const CampLines := preload("res://src/core/camp_lines.gd")
const PrologueRows := preload("res://src/core/prologue_rows.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Profile := preload("res://src/core/profile.gd")
const Codex := preload("res://src/core/codex.gd")
const ContentRegistry := preload("res://src/core/content_registry.gd")
const Synergies := preload("res://src/build/synergies.gd")
const CombatCodex := preload("res://src/combat/codex_entries.gd")
const BossCodex := preload("res://src/boss/codex_entries.gd")
const WorldCodex := preload("res://src/world/codex_world.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("w50_story_arcs_test")


class MockCodex extends RefCounted:
	var _known := {}

	func mark(id: String) -> void:
		_known[id] = true

	func known(id: String) -> bool:
		return _known.has(id)


func _fresh_profile() -> Profile:
	var p := Profile.new("user://w50-story-test-%d.json" % OS.get_process_id())
	p.can_save = false
	return p


func _class_ids() -> Array:
	var out: Array = []
	for def in ClassDef.all():
		out.append(String(def.id))
	return out


func _signal_names() -> Array:
	var out: Array = []
	for s in GameEvents.signal_names():
		out.append(String(s))
	return out


func _all_valid_codex_targets() -> Dictionary:
	var valid := {}
	for id in CombatCodex.ids():
		valid[String(id)] = true
	for row in BossCodex.all():
		valid[String(row["id"])] = true
	for row in WorldCodex.ENTRIES:
		valid[String(row["id"])] = true
	for id in Synergies.ROWS:
		valid[String(id)] = true
	for id in Synergies.CROSS_SYSTEM:
		valid[String(id)] = true
	for id in PilotStory.PATCH_TRAIL:
		valid[String(id)] = true
	return valid


func _initialize() -> void:
	_test_schema_and_rule8()
	_test_planted_negative_controls()
	_test_golden_hash_and_existing_safety()
	_test_punch_mask_and_zero_spoiler()
	_test_pair_chemistry_and_anti_spam()
	_test_patch_trail_determinism()
	_test_foreman_habits_dormancy_and_cooldown()
	_test_camp_lines_backward_compat()
	_test_codex_declarations_and_shuffle_hygiene()
	quit(_t.verdict())


# Predicate 1: Schema, Word-Cap & Rule 8 Gate + live links_to resolution.
func _test_schema_and_rule8() -> void:
	var cids := _class_ids()
	var sigs := _signal_names()
	var spks := LoreRows.SPEAKERS.keys()
	var issues := PilotStory.validate(cids, sigs, spks)
	_t.eq("P1 PilotStory.validate clean", issues, [])
	_t.eq("P1 8 casts", PilotStory.CAST_ORDER.size(), 8)
	_t.eq("P1 40 chapters", PilotStory.CHAPTERS.size(), 40)
	_t.eq("P1 15 pilot pairs", PilotStory.pair_ids().size(), 15)
	_t.eq("P1 6 Patch trail nodes", PilotStory.PATCH_TRAIL.size(), 6)
	_t.eq("P1 7 Foreman habit axes", PilotStory.FOREMAN_AXES.size(), 7)
	var targets := _all_valid_codex_targets()
	var unresolved: Array[String] = []
	for pid in PilotStory.pair_ids():
		var link := String(PilotStory.PAIRS[pid]["payoff"]["links_to"])
		if not targets.has(link):
			unresolved.append("%s->%s" % [pid, link])
	_t.eq("P1 all 15 pair links_to resolve to live Codex/Synergy/Patch IDs", unresolved, [])


# Predicate 2: Planted Negative Controls.
func _test_planted_negative_controls() -> void:
	var cids := _class_ids()
	var sigs := _signal_names()
	var spks := LoreRows.SPEAKERS.keys()

	# (a) 13-word call-in MUST be rejected.
	var bad_calls: Array = LoreRows.WORLD_CALLS.duplicate(true)
	bad_calls[0]["text"] = ["One two three four five six seven eight nine ten eleven twelve thirteen."]
	var res_a := PilotStory.validate_tables(
		PilotStory.CHAPTERS, PilotStory.PAIRS, PilotStory.PATCH_TRAIL, PilotStory.FOREMAN_AXES,
		bad_calls, LoreRows.CAMP_EXCHANGES, LoreRows.CAMP_QUIPS_BY_CHAPTER, cids, sigs, spks
	)
	_t.check("P2a 13-word call-in rejected", not res_a.is_empty(), str(res_a))

	# (b) 9-word Foreman stage memo MUST be rejected.
	var bad_axes: Dictionary = PilotStory.FOREMAN_AXES.duplicate(true)
	bad_axes["chronic_gambler"]["stage_memos"] = ["One two three four five six seven eight nine."]
	var res_b := PilotStory.validate_tables(
		PilotStory.CHAPTERS, PilotStory.PAIRS, PilotStory.PATCH_TRAIL, bad_axes,
		LoreRows.WORLD_CALLS, LoreRows.CAMP_EXCHANGES, LoreRows.CAMP_QUIPS_BY_CHAPTER, cids, sigs, spks
	)
	_t.check("P2b 9-word Foreman stage memo rejected", not res_b.is_empty(), str(res_b))

	# (c) Self-pair and missing pair MUST be rejected.
	var bad_pairs_missing: Dictionary = PilotStory.PAIRS.duplicate(true)
	bad_pairs_missing.erase("rivet_sable")
	var res_c1 := PilotStory.validate_tables(
		PilotStory.CHAPTERS, bad_pairs_missing, PilotStory.PATCH_TRAIL, PilotStory.FOREMAN_AXES,
		LoreRows.WORLD_CALLS, LoreRows.CAMP_EXCHANGES, LoreRows.CAMP_QUIPS_BY_CHAPTER, cids, sigs, spks
	)
	_t.check("P2c1 missing pair rejected", not res_c1.is_empty(), str(res_c1))

	var bad_pairs_self: Dictionary = PilotStory.PAIRS.duplicate(true)
	bad_pairs_self["rivet_sable"]["pilots"] = ["pylon_engineer", "pylon_engineer"]
	var res_c2 := PilotStory.validate_tables(
		PilotStory.CHAPTERS, bad_pairs_self, PilotStory.PATCH_TRAIL, PilotStory.FOREMAN_AXES,
		LoreRows.WORLD_CALLS, LoreRows.CAMP_EXCHANGES, LoreRows.CAMP_QUIPS_BY_CHAPTER, cids, sigs, spks
	)
	_t.check("P2c2 self-pair rejected", not res_c2.is_empty(), str(res_c2))

	# (d) "PAID" in a Tally chapter note MUST be rejected.
	var bad_chapters: Array = PilotStory.CHAPTERS.duplicate(true)
	for row in bad_chapters:
		if String(row["id"]) == "tally.ch2":
			row["note"] = "Tally stamped PAID across the whole dispatch form."
	var res_d := PilotStory.validate_tables(
		bad_chapters, PilotStory.PAIRS, PilotStory.PATCH_TRAIL, PilotStory.FOREMAN_AXES,
		LoreRows.WORLD_CALLS, LoreRows.CAMP_EXCHANGES, LoreRows.CAMP_QUIPS_BY_CHAPTER, cids, sigs, spks
	)
	_t.check("P2d PAID in Tally chapter note rejected", not res_d.is_empty(), str(res_d))


# Predicate 3: Golden-Hash & Existing-Test Safety.
func _test_golden_hash_and_existing_safety() -> void:
	_t.eq("P3 LoreRows.call_signals().size() == 7", LoreRows.call_signals().size(), 7)
	_t.eq("P3 PrologueRows.ROWS.size() == 3", PrologueRows.ROWS.size(), 3)
	_t.eq("P3 PrologueRows.for_world(1) == ROWS", PrologueRows.for_world(1), PrologueRows.ROWS)
	for w in [2, 3]:
		var act_rows := PrologueRows.for_world(w)
		_t.eq("P3 PrologueRows world %d has 3 rows" % w, act_rows.size(), 3)
		for r in act_rows:
			var words := PrologueRows.words(String(r["text"]))
			_t.check("P3 PrologueRows W%d cap" % w, words > 0 and words <= PrologueRows.LINE_WORD_CAP, "%d words" % words)
	var snap := ContentRegistry.snapshot()
	var lore_issues := ContentRegistry.validate_table("lore_rows.ROWS", LoreRows.ROWS, snap, true)
	_t.eq("P3 LoreRows.ROWS golden hash intact", lore_issues, [])

	# Default voice_of keeps W1 compatibility for lore_rows_test.gd:201.
	_t.eq("P3 default voice_of Deck crew silent", LoreRows.voice_of({"kind": "exchange", "speaker": "Deck crew", "text": "x"}), "")
	_t.eq("P3 default voice_of 2-1 warden silent", LoreRows.voice_of({"kind": "intro", "zone": "2-1", "subject": "warden", "text": "Pit Warden. x"}), "")

	# world_voice_of resolves Dig crew -> dig_crew, Deck crew -> roost_crew, and EVERY non-field_note row in LoreRows.ROWS.
	_t.eq("P3 world_voice_of Dig crew", LoreRows.world_voice_of({"kind": "exchange", "speaker": "Dig crew", "text": "x"}), "dig_crew")
	_t.eq("P3 world_voice_of Deck crew", LoreRows.world_voice_of({"kind": "exchange", "speaker": "Deck crew", "text": "x"}), "roost_crew")
	var missing_voices: Array[String] = []
	for row in LoreRows.ROWS:
		if String(row["kind"]) == "field_note":
			continue
		var v := LoreRows.world_voice_of(row)
		if v == "" or not LoreRows.SPEAKERS.has(v):
			missing_voices.append("%s->%s" % [row["id"], v])
	_t.eq("P3 every non-field_note LoreRows.ROWS resolves via world_voice_of", missing_voices, [])


# Predicate 4: Independent Punch Mask, Zero-Spoiler Gate, Progress Hook & Overtime Ribbon.
func _test_punch_mask_and_zero_spoiler() -> void:
	var profile := _fresh_profile()
	var codex := MockCodex.new()
	var known := Callable(codex, "known")

	_t.eq("P4 ClassDef.by_id('patch') == null", ClassDef.by_id("patch"), null)
	_t.eq("P4 fresh patch card hidden", PilotStory.card_visible("patch", profile, false, codex), false)
	_t.eq("P4 fresh pair.rivet_sable.3 hidden", PilotStory.entry_visible("pair.rivet_sable.3", known), false)
	_t.eq("P4 fresh patch.wire.w1 hidden", PilotStory.entry_visible("patch.wire.w1", known), false)

	# Punch Ch. 4 without Ch. 1..3 (zero order soft-lock!).
	profile.earn("ach_sable_cable_runs", 10.0)
	var mask := PilotStory.punch_mask("pylon_engineer", profile, codex)
	_t.eq("P4 independent Ch4 punch without Ch1..3", mask, [false, false, false, true, false])
	_t.eq("P4 punched_count == 1", PilotStory.punched_count("pylon_engineer", profile, codex), 1)
	_t.eq("P4 next_chase still points to Ch1", String(PilotStory.next_chase("pylon_engineer", profile, false, codex).get("id", "")), "pylon_engineer.ch1")

	# Progress trigger hook resolves matching chapter cleanly with 2 args.
	profile.earn("brindle_mark_sable", 20.0)
	var matched := PilotStory.chapters_matching_trigger("brindle_mark_sable", profile)
	_t.eq("P4 chapters_matching_trigger", matched, [{"cast": "pylon_engineer", "num": 2, "id": "pylon_engineer.ch2"}])

	# Overtime ribbon is orthogonal & monotonic.
	_t.eq("P4 overtime starts 0", PilotStory.overtime_rung("pylon_engineer", profile), 0)
	_t.eq("P4 record_overtime rung 3", PilotStory.record_overtime("pylon_engineer", 3, profile), true)
	_t.eq("P4 record_overtime lower rung ignored", PilotStory.record_overtime("pylon_engineer", 2, profile), false)
	_t.eq("P4 overtime stays 3", PilotStory.overtime_rung("pylon_engineer", profile), 3)

	# Patch card unlocks when Ch. 1 punches.
	codex.mark("patch.rogue.w1")
	_t.eq("P4 patch card visible after rogue_crane", PilotStory.card_visible("patch", profile, false, codex), true)


# Predicate 5: 15-Pair Chemistry 3-Beat Flow & Anti-Spam Budgets.
func _test_pair_chemistry_and_anti_spam() -> void:
	_t.eq("P5 pair_id symmetric", PilotStory.pair_id("pylon_engineer", "runner_gunner"), "rivet_sable")
	_t.eq("P5 pair_id reversed", PilotStory.pair_id("runner_gunner", "pylon_engineer"), "rivet_sable")
	_t.eq("P5 self pair empty", PilotStory.pair_id("pylon_engineer", "pylon_engineer"), "")

	var profile := _fresh_profile()
	profile.unlock_pilot("runner_gunner")
	profile.unlock_pilot("demolitions_caster")
	var codex := MockCodex.new()
	var known := Callable(codex, "known")

	# Walk 1: Sable approaches Rivet -> spark plays once.
	var b1 := PilotStory.pick_camp_beat(
		"pylon_engineer", "runner_gunner", ["runner_gunner", "demolitions_caster"],
		profile, codex, [], 1, false
	)
	_t.eq("P5 Beat 1 kind", String(b1.get("kind", "")), "pair_spark")
	_t.eq("P5 Beat 1 id", String(b1.get("id", "")), "pair.rivet_sable.1")
	_t.eq("P5 Beat 1 consumes budget", bool(b1.get("consumes_pair_budget", false)), true)
	codex.mark("pair.rivet_sable.1")

	# Second pilot same walk (pair_played_this_walk = true) -> solo quip only!
	var b_solo := PilotStory.pick_camp_beat(
		"pylon_engineer", "demolitions_caster", ["runner_gunner", "demolitions_caster"],
		profile, codex, [], 1, true
	)
	_t.eq("P5 second pilot same walk returns solo_quip", String(b_solo.get("kind", "")), "solo_quip")

	# In-run drop_landed(3) while flying Sable -> fires Rivet's Beat 2 (NEVER Sable!).
	var c1 := PilotStory.pick_run_call(
		"drop_landed", [3], 1, "pylon_engineer", 42,
		["pylon_engineer", "runner_gunner"], profile, codex, {}, false
	)
	_t.eq("P5 Beat 2 kind", String(c1.get("kind", "")), "pair_field")
	_t.eq("P5 Beat 2 id", String(c1.get("id", "")), "pair.rivet_sable.2")
	_t.eq("P5 Beat 2 speaker is Rivet (never self)", String(c1.get("speaker", "")), "rivet")

	# Second drop_landed(3) with pair_call_used = true -> returns {} (anti-spam!).
	var c2 := PilotStory.pick_run_call(
		"drop_landed", [3], 1, "pylon_engineer", 42,
		["pylon_engineer", "runner_gunner"], profile, codex, {}, true
	)
	_t.eq("P5 second pair call blocked by pair_call_used", c2, {})

	# Record Beat 2, clear boss -> camp Beat 3 payoff fires + synthesis_margin flips on discovery!
	codex.mark("pair.rivet_sable.2")
	profile.earn("brindle_routed", 30.0)
	var b3 := PilotStory.pick_camp_beat(
		"pylon_engineer", "runner_gunner", ["runner_gunner"],
		profile, codex, [], 2, false
	)
	_t.eq("P5 Beat 3 kind", String(b3.get("kind", "")), "pair_payoff")
	_t.eq("P5 Beat 3 id", String(b3.get("id", "")), "pair.rivet_sable.3")
	codex.mark("pair.rivet_sable.3")
	_t.eq("P5 pair_stage == 3", PilotStory.pair_stage("rivet_sable", known), 3)

	var margin_before := PilotStory.synthesis_margin("pair.rivet_sable.3", known)
	_t.check("P5 margin hint before discovery", margin_before.begins_with("\nMargin note: ") and margin_before != "\nMargin note: confirmed in the field.", margin_before)
	codex.mark("wrecking_ball")
	var margin_after := PilotStory.synthesis_margin("pair.rivet_sable.3", known)
	_t.eq("P5 margin confirmed after discovery", margin_after, "\nMargin note: confirmed in the field.")


# Predicate 6: Patch Trail Determinism & Visibility Flip.
func _test_patch_trail_determinism() -> void:
	_t.eq("P6 rogue_crane -> w1", PilotStory.patch_rogue_for_kind("rogue_crane"), "patch.rogue.w1")
	_t.eq("P6 rogue_skip -> w2", PilotStory.patch_rogue_for_kind("rogue_skip"), "patch.rogue.w2")
	_t.eq("P6 rogue_tender -> w3", PilotStory.patch_rogue_for_kind("rogue_tender"), "patch.rogue.w3")

	var s1 := PilotStory.patch_spot("patch.wire.w1", 42)
	var s2 := PilotStory.patch_spot("patch.wire.w1", 42)
	_t.eq("P6 patch_spot repeatable for same seed", s1, s2)
	var seen_sites := {}
	for seed_n in 64:
		var spot := PilotStory.patch_spot("patch.wire.w1", seed_n)
		seen_sites[String(spot.get("site", ""))] = true
	_t.check("P6 patch_spot shifts across seeds", seen_sites.size() >= 2, str(seen_sites.keys()))

	var codex := MockCodex.new()
	var known := Callable(codex, "known")
	_t.eq("P6 w1 wire hidden initially", PilotStory.entry_visible("patch.wire.w1", known), false)
	codex.mark("patch.rogue.w1")
	_t.eq("P6 w1 wire visible after rogue_crane", PilotStory.entry_visible("patch.wire.w1", known), true)
	_t.eq("P6 w2 wire still hidden", PilotStory.entry_visible("patch.wire.w2", known), false)
	_t.eq("P6 w3 wire still hidden", PilotStory.entry_visible("patch.wire.w3", known), false)

	var profile := _fresh_profile()
	var patch_call := PilotStory.pick_run_call(
		"enemy_killed", ["rogue_crane", Vector3.ZERO, 30], 1, "pylon_engineer", 7,
		["pylon_engineer"], profile, codex, {}, false
	)
	_t.eq("P6 rogue_crane fires unsigned Patch call", String(patch_call.get("speaker", "")), "unsigned")
	_t.eq("P6 rogue_crane call id", String(patch_call.get("id", "")), "patch.rogue.w1")


# Predicate 7: Foreman Habit Ledger Dormancy, Axis Separation & 2-Run Cooldown.
func _test_foreman_habits_dormancy_and_cooldown() -> void:
	# Dormant on runs < 3.
	var p_new := _fresh_profile()
	p_new.set_stat("habit.trade_risk", 8.0)
	p_new.set_stat("habit.runs_total", 2.0)
	_t.eq("P7 dormant on run 2", bool(PilotStory.classify_habits(p_new, [])["dormant"]), true)
	_t.eq("P7 dormant stage memo empty", PilotStory.foreman_stage_memo(4, 1, p_new, []), "")
	_t.eq("P7 dormant loss memo empty", PilotStory.foreman_loss_memo(4, "warden", p_new, []), "")
	_t.eq("P7 dormant crown line empty", PilotStory.foreman_crown_line(4, p_new, []), "")

	# Distinct profiles classify cleanly into distinct axes.
	var p_gambler := _fresh_profile()
	p_gambler.set_stat("habit.runs_total", 4.0)
	p_gambler.set_stat("habit.trade_risk", 6.0)
	var p_kind := _fresh_profile()
	p_kind.set_stat("habit.runs_total", 4.0)
	p_kind.set_stat("habit.trade_safe", 6.0)
	var p_speed := _fresh_profile()
	p_speed.set_stat("habit.runs_total", 4.0)
	p_speed.set_stat("habit.runs_blazing", 5.0)

	_t.eq("P7 gambler axis", String(PilotStory.classify_habits(p_gambler, [])["axis"]), "chronic_gambler")
	_t.eq("P7 kindness axis", String(PilotStory.classify_habits(p_kind, [])["axis"]), "kindness_regular")
	_t.eq("P7 speed axis", String(PilotStory.classify_habits(p_speed, [])["axis"]), "speed_demon")

	# Find a seed that passes the 50% cadence guard and one that skips it.
	var fired := 0
	var skipped := 0
	var gambler_stage := ""
	var kind_stage := ""
	var speed_stage := ""
	for seed_n in 32:
		var m := PilotStory.foreman_stage_memo(seed_n, 1, p_gambler, [])
		if m != "":
			fired += 1
			if gambler_stage == "":
				gambler_stage = m
				kind_stage = PilotStory.foreman_stage_memo(seed_n, 1, p_kind, [])
				speed_stage = PilotStory.foreman_stage_memo(seed_n, 1, p_speed, [])
		else:
			skipped += 1
	_t.check("P7 50% nominal audit cadence fires and skips", fired > 0 and skipped > 0, "fired=%d skipped=%d" % [fired, skipped])
	_t.check("P7 stage memos distinct and <= 8w",
		gambler_stage != kind_stage and kind_stage != speed_stage and gambler_stage != speed_stage
		and WordBudget.words_in(gambler_stage) <= 8 and WordBudget.words_in(kind_stage) <= 8 and WordBudget.words_in(speed_stage) <= 8,
		"%s | %s | %s" % [gambler_stage, kind_stage, speed_stage])

	var g_loss := PilotStory.foreman_loss_memo(11, "warden", p_gambler, [])
	var k_loss := PilotStory.foreman_loss_memo(11, "warden", p_kind, [])
	var s_loss := PilotStory.foreman_loss_memo(11, "warden", p_speed, [])
	_t.check("P7 loss memos distinct and <= 14w",
		g_loss != k_loss and k_loss != s_loss and g_loss != s_loss
		and WordBudget.words_in(g_loss) <= 14 and WordBudget.words_in(k_loss) <= 14 and WordBudget.words_in(s_loss) <= 14,
		"%s | %s | %s" % [g_loss, k_loss, s_loss])

	# Cooldown: firing chronic_gambler on run 4 suppresses it on run 5 and re-enables on run 6.
	PilotStory.record_foreman_axis("chronic_gambler", 4, p_gambler)
	p_gambler.set_stat("habit.runs_total", 5.0)
	var cd_run5 := PilotStory.classify_habits(p_gambler, [])
	_t.eq("P7 axis suppressed on run N+1", String(cd_run5["axis"]), "")
	_t.eq("P7 suppressed flag true on run N+1", bool(cd_run5["suppressed"]), true)
	p_gambler.set_stat("habit.runs_total", 6.0)
	var cd_run6 := PilotStory.classify_habits(p_gambler, [])
	_t.eq("P7 axis re-enabled on run N+2", String(cd_run6["axis"]), "chronic_gambler")


# Predicate 8: CampLines Backward Compatibility + 3rd-arg Story State.
func _test_camp_lines_backward_compat() -> void:
	var pages := [{"run_id": "run-101", "outcome": "won", "world": 1, "pilot": "pylon_engineer", "stage_reached": 2}]
	var base := CampLines.line_for(pages, {})
	_t.check("P8 2-arg baseline stays in WIN", base in CampLines.WIN, base)
	_t.eq("P8 3-arg empty dict matches 2-arg verbatim", CampLines.line_for(pages, {}, {}), base)

	var l_order := CampLines.line_for(pages, {}, {"order_done": ["wo_moss_1"]})
	var l_lic := CampLines.line_for(pages, {}, {"licenses_up": ["moss:1"]})
	var l_ch := CampLines.line_for(pages, {}, {"chapter_punched": {"id": "pylon_engineer.ch3", "num": 3}})
	var l_patch := CampLines.line_for(pages, {}, {"patch_wires_all": true})
	var l_hard := CampLines.line_for(pages, {}, {"hard_clear": 2})

	_t.check("P8 order_done pool", l_order in CampLines.ORDER_DONE and l_order == CampLines.line_for(pages, {}, {"order_done": ["wo_moss_1"]}), l_order)
	_t.check("P8 licenses_up pool", l_lic in CampLines.LICENSE_UP, l_lic)
	_t.check("P8 chapter_punched pool", l_ch in CampLines.CHAPTER_BEAT, l_ch)
	_t.check("P8 patch_wires_all pool", l_patch in CampLines.PATCH_WALL_NOTE, l_patch)
	_t.check("P8 hard_clear pool", l_hard in CampLines.HARD_CLEAR, l_hard)


# Predicate 9: Codex declarations validity & zero-state hygiene.
func _test_codex_declarations_and_shuffle_hygiene() -> void:
	var decls := PilotStory.codex_declarations()
	_t.eq("P9 21 codex declarations (15 pairs + 6 patch)", decls.size(), 21)
	var seen := {}
	for entry in decls:
		var id := String(entry.get("id", ""))
		var cat := String(entry.get("category", ""))
		_t.check("P9 decl %s valid" % id, id != "" and not seen.has(id) and cat in Codex.CATEGORIES and String(entry.get("text", "")) != "", "%s:%s" % [id, cat])
		seen[id] = true
