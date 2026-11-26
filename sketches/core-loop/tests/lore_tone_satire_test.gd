extends SceneTree

const LoreRows := preload("res://src/core/lore_rows.gd")
const PilotStory := preload("res://src/core/pilot_story.gd")
const StageModifier := preload("res://src/world/events/stage_modifier.gd")
const BossCodex := preload("res://src/boss/codex_entries.gd")
const CombatCodex := preload("res://src/combat/codex_entries.gd")
const PickupLines := preload("res://src/ui/pickup_lines.gd")
const Panels := preload("res://src/build/panels.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Profile := preload("res://src/core/profile.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const ContentRegistry := preload("res://src/core/content_registry.gd")
const T := preload("res://tests/support/t.gd")

const BANNED_TOKENS := ["!", "\u2014", "\u2013", "...", "\u2026", "\u00b7", "\u2018", "\u2019", "\u201c", "\u201d"]
const PILOTS := ["sable", "rivet", "kest", "tarn", "tally", "cannon"]

var _t := T.new("lore_tone_satire_test")


class MockCodex extends RefCounted:
	var _known := {}

	func mark(id: String) -> void:
		_known[id] = true

	func known(id: String) -> bool:
		return _known.has(id)


func _fresh_profile() -> Profile:
	var p := Profile.new("user://lore-tone-satire-test-%d.json" % OS.get_process_id())
	p.can_save = false
	return p


func _initialize() -> void:
	_check_word_caps_unweakened()
	_check_world_calls_coverage()
	_check_patch_and_pilot_call_selection()
	_check_foreman_satire_memos()
	_check_codex_flavour_and_hashes()
	_check_pickup_lines_quips()
	_check_planted_negative_controls()
	quit(_t.verdict())


func _tone_issues(text: String, max_words: int, forbid_colon := false) -> Array[String]:
	var issues: Array[String] = []
	var words := WordBudget.words_in(text)
	if words < 1 or words > max_words:
		issues.append("words %d > %d" % [words, max_words])
	for sub in BANNED_TOKENS:
		if text.contains(sub):
			issues.append("banned '%s'" % sub)
	if forbid_colon and text.contains(":"):
		issues.append("colon")
	var lower := text.to_lower()
	for phrase in PilotStory.BANNED_PHRASES:
		if lower.contains(phrase):
			issues.append("phrase '%s'" % phrase)
	for raw_tok in lower.split(" ", false):
		var tok := PilotStory._strip_punct(raw_tok)
		if tok in PilotStory.BANNED_WORDS:
			issues.append("word '%s'" % tok)
	return issues


func _check_word_caps_unweakened() -> void:
	_t.eq("CALL_LINE_WORD_CAP == 12", LoreRows.CALL_LINE_WORD_CAP, 12)
	_t.eq("INTRO_LINE_WORD_CAP == 12", LoreRows.INTRO_LINE_WORD_CAP, 12)
	_t.eq("EXCHANGE_LINE_WORD_CAP == 14", LoreRows.EXCHANGE_LINE_WORD_CAP, 14)
	_t.eq("FIELD_NOTE_WORD_CAP == 40", LoreRows.FIELD_NOTE_WORD_CAP, 40)
	_t.eq("STAGE_MEMO_WORD_CAP == 8", PilotStory.STAGE_MEMO_WORD_CAP, 8)
	_t.eq("LOSS_MEMO_WORD_CAP == 14", PilotStory.LOSS_MEMO_WORD_CAP, 14)


func _check_world_calls_coverage() -> void:
	var bus := GameEvents.new()
	var arity := {}
	for sig in bus.get_signal_list():
		arity[String(sig["name"])] = (sig["args"] as Array).size()
	bus.free()

	var w2_speakers := {}
	var w3_speakers := {}
	var w2_rows := 0
	var w3_rows := 0
	for row in LoreRows.WORLD_CALLS:
		var cid := String(row["id"])
		var world := int(row.get("world", 0))
		var speaker := String(row.get("speaker", ""))
		var sig := String(row.get("on", ""))
		_t.check("%s signal %s arity <= 4" % [cid, sig], arity.has(sig) and int(arity[sig]) <= 4, str(arity.get(sig, -1)))
		var lines: Array = row.get("text", [])
		_t.check("%s has 2..3 variants" % cid, lines.size() >= 2 and lines.size() <= 3, str(lines.size()))
		for line in lines:
			var iss := _tone_issues(String(line), LoreRows.CALL_LINE_WORD_CAP, false)
			_t.eq("%s tone clean" % cid, iss, [])
		if world == 2:
			w2_rows += 1
			w2_speakers[speaker] = true
		elif world == 3:
			w3_rows += 1
			w3_speakers[speaker] = true

	_t.check("W2 has rich reactive calls (>= 15)", w2_rows >= 15, str(w2_rows))
	_t.check("W3 has rich reactive calls (>= 15)", w3_rows >= 15, str(w3_rows))
	for sp in ["dig_crew", "caisson_crew", "waking", "moss", "mind", "patch"] + PILOTS:
		_t.check("W2 covers speaker %s" % sp, w2_speakers.has(sp), str(w2_speakers.keys()))
	for sp in ["roost_crew", "crown_watch", "moss", "mind", "patch"] + PILOTS:
		_t.check("W3 covers speaker %s" % sp, w3_speakers.has(sp), str(w3_speakers.keys()))

	for row in LoreRows.CALLS:
		var cid := String(row["id"])
		for line in row.get("text", []):
			_t.eq("W1 %s tone clean" % cid, _tone_issues(String(line), LoreRows.CALL_LINE_WORD_CAP, false), [])

	_t.check("PATCH_CAMP_QUIPS has >= 4 quips", LoreRows.PATCH_CAMP_QUIPS.size() >= 4, str(LoreRows.PATCH_CAMP_QUIPS.size()))
	for i in LoreRows.PATCH_CAMP_QUIPS.size():
		var q := LoreRows.patch_quip_text(i)
		_t.eq("patch camp quip %d clean" % i, _tone_issues(q, LoreRows.CALL_LINE_WORD_CAP, false), [])


func _check_patch_and_pilot_call_selection() -> void:
	var profile := _fresh_profile()
	var codex := MockCodex.new()
	var all_classes: Array = ClassDef.all().map(func(d): return String(d.id))

	var locked_patch := PilotStory.pick_run_call("maker_set_completed", ["fleet", "shock"], 2, "pylon_engineer", 11, all_classes, profile, codex, {}, false)
	_t.eq("Patch maker call hidden before patch.ch2", locked_patch, {})

	codex.mark("patch.wire.w1")
	var unlocked_patch := PilotStory.pick_run_call("maker_set_completed", ["fleet", "shock"], 2, "pylon_engineer", 11, all_classes, profile, codex, {}, false)
	_t.eq("Patch maker call fires in W2 once patch.ch2 punched", String(unlocked_patch.get("speaker", "")), "patch")

	var w3_patch := PilotStory.pick_run_call("ultimate_landed", ["cable_run", Vector3.ZERO, 4, 200.0], 3, "pylon_engineer", 17, all_classes, profile, codex, {}, false)
	_t.eq("Patch ultimate call fires in W3 once patch.ch2 punched", String(w3_patch.get("speaker", "")), "patch")

	var w2_callers := {}
	var w3_callers := {}
	for seed_n in 40:
		var w2 := PilotStory.pick_run_call("drop_landed", [3], 2, "pylon_engineer", seed_n, all_classes, profile, codex, {}, false)
		var w3 := PilotStory.pick_run_call("drop_landed", [3], 3, "pylon_engineer", seed_n, all_classes, profile, codex, {}, false)
		_t.check("W2 drop caller never flying pilot", String(w2.get("pilot", "")) != "pylon_engineer" and String(w2.get("speaker", "")) != "")
		_t.check("W3 drop caller never flying pilot", String(w3.get("pilot", "")) != "pylon_engineer" and String(w3.get("speaker", "")) != "")
		w2_callers[String(w2.get("speaker", ""))] = true
		w3_callers[String(w3.get("speaker", ""))] = true
	_t.check("W2 drop calls rotate across multiple pilots", w2_callers.size() >= 3, str(w2_callers.keys()))
	_t.check("W3 drop calls rotate across multiple pilots", w3_callers.size() >= 3, str(w3_callers.keys()))

	var waking_call := PilotStory.pick_run_call("swarm_scattered", [Vector3.ZERO, 3], 2, "pylon_engineer", 7, all_classes, profile, codex, {}, false)
	_t.eq("W2 swarm_scattered fires Waking call", String(waking_call.get("speaker", "")), "waking")

	var ring_call := PilotStory.pick_run_call("enemy_ringed_out", ["ballast_heavy", Vector3.ZERO], 3, "pylon_engineer", 7, all_classes, profile, codex, {}, false)
	_t.eq("W3 enemy_ringed_out fires roost_crew call", String(ring_call.get("speaker", "")), "roost_crew")

	var adapt_call := PilotStory.pick_run_call("mind_adapted", ["ram", "icon"], 3, "pylon_engineer", 7, all_classes, profile, codex, {}, false)
	_t.eq("W3 mind_adapted fires mind call", String(adapt_call.get("speaker", "")), "mind")


func _check_foreman_satire_memos() -> void:
	_t.eq("StageModifier.ROWS stays 8 rows", StageModifier.ROWS.size(), 8)
	for row in StageModifier.ROWS:
		_t.eq("StageModifier %s line clean" % row.id, _tone_issues(String(row.line), 8, true), [])
	_t.check("StageModifier.NOMINAL has >= 8 satire memos", StageModifier.NOMINAL.size() >= 8, str(StageModifier.NOMINAL.size()))
	for line in StageModifier.NOMINAL:
		_t.eq("StageModifier nominal '%s' clean" % line, _tone_issues(String(line), 8, true), [])

	for axis in PilotStory.FOREMAN_AXIS_ORDER:
		var arow: Dictionary = PilotStory.FOREMAN_AXES[axis]
		_t.check("%s has >= 3 stage_memos" % axis, (arow["stage_memos"] as Array).size() >= 3)
		_t.check("%s has >= 3 loss_memos" % axis, (arow["loss_memos"] as Array).size() >= 3)
		_t.check("%s has >= 2 crown_lines" % axis, (arow["crown_lines"] as Array).size() >= 2)
		for m in arow["stage_memos"]:
			_t.eq("%s stage_memo clean" % axis, _tone_issues(String(m), PilotStory.STAGE_MEMO_WORD_CAP, true), [])
		for m in arow["loss_memos"]:
			_t.eq("%s loss_memo clean" % axis, _tone_issues(String(m), PilotStory.LOSS_MEMO_WORD_CAP, true), [])
		for m in arow["crown_lines"]:
			_t.eq("%s crown_line clean" % axis, _tone_issues(String(m), PilotStory.CALL_WORD_CAP, true), [])

	var cids: Array = ClassDef.all().map(func(d): return String(d.id))
	var sigs: Array = []
	for s in GameEvents.signal_names():
		sigs.append(String(s))
	_t.eq("PilotStory.validate clean", PilotStory.validate(cids, sigs, LoreRows.SPEAKERS.keys()), [])


func _check_codex_flavour_and_hashes() -> void:
	var snap := ContentRegistry.snapshot()
	for table in ["lore_rows.ROWS", "boss.codex_entries.ENTRIES", "boss.codex_entries.WAKING", "boss.codex_entries.MIND", "combat.codex_entries.ENTRIES"]:
		_t.eq("golden hash intact for " + table, ContentRegistry.digest(snap[table]), ContentRegistry.GOLDEN_HASHES[table])

	for row in BossCodex.all():
		var id := String(row["id"])
		var f := BossCodex.flavour(id)
		_t.check("BossCodex flavour exists for " + id, not f.is_empty() and LoreRows.SPEAKERS.has(String(f.get("speaker", ""))))
		_t.eq("BossCodex flavour %s clean" % id, _tone_issues(BossCodex.flavour_text(id), 20, true), [])

	var combat_ids := CombatCodex.ids()
	_t.check("CombatCodex has >= 25 flavour notes", CombatCodex.flavour_ids().size() >= 25, str(CombatCodex.flavour_ids().size()))
	for id in CombatCodex.flavour_ids():
		_t.check("CombatCodex flavour %s maps to live id" % id, id in combat_ids)
		var f := CombatCodex.flavour(String(id))
		_t.check("CombatCodex flavour %s has valid speaker" % id, LoreRows.SPEAKERS.has(String(f.get("speaker", ""))))
		_t.eq("CombatCodex flavour %s clean" % id, _tone_issues(CombatCodex.flavour_text(String(id)), 20, true), [])


func _check_pickup_lines_quips() -> void:
	for pid in Panels.ids():
		var pop := Panels.pop_text(String(pid))
		var quip := PickupLines.quip_for(pop)
		_t.check("PickupLines quip resolves for " + String(pid), quip != "", pop)
		_t.eq("PickupLines quip %s clean" % pid, _tone_issues(quip, 10, true), [])
	for maker in ["fleet", "keeper", "works", "rogue", "patch"]:
		var slogan := PickupLines.maker_slogan(maker)
		_t.check("PickupLines slogan exists for " + maker, slogan != "")
		_t.eq("PickupLines slogan %s clean" % maker, _tone_issues(slogan, 8, true), [])


func _check_planted_negative_controls() -> void:
	_t.check("planted exclamation rejected", not _tone_issues("Synergistic win!", 12, false).is_empty())
	_t.check("planted em-dash rejected", not _tone_issues("Mean it \u2014 then wink.", 12, false).is_empty())
	_t.check("planted ellipsis rejected", not _tone_issues("Waiting for metrics...", 12, false).is_empty())
	_t.check("planted W1 puffery rejected", not _tone_issues("Epic powerful hit.", 12, false).is_empty())
	_t.check("planted W7 retired word rejected", not _tone_issues("Grab the salvage fast.", 12, false).is_empty())
	_t.check("planted 13-word call rejected", not _tone_issues("One two three four five six seven eight nine ten eleven twelve thirteen.", 12, false).is_empty())
	_t.check("planted colon in non-voice text rejected", not _tone_issues("Label: value here.", 12, true).is_empty())
