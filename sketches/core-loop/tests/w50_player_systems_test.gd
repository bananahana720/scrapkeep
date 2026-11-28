extends SceneTree

# W50-PLAYER-SYSTEMS (w50-player-story-spec.md §6.8):
# Verifies all 8 falsifiable predicates and planted negative controls for WorkOrders,
# Achievements.MASTERY_ROWS, ShiftBoard.WORLD_RUNGS/WORLD_CARDS/WORLD_SEEDS,
# MetaOptions.OVERRIDE_CODES/ALT_LOADOUTS, RunTier W1-W3 HARD rungs, Progress atomic
# settlement & EarnedSave.tla guards, and Codex story hooks.

const WorkOrders := preload("res://src/core/work_orders.gd")
const Achievements := preload("res://src/core/achievements.gd")
const ShiftBoard := preload("res://src/core/shift_board.gd")
const MetaOptions := preload("res://src/core/meta_options.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const Progress := preload("res://src/core/progress.gd")
const Codex := preload("res://src/core/codex.gd")
const Profile := preload("res://src/core/profile.gd")
const RunState := preload("res://src/core/run_state.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const TuneRows := preload("res://src/core/tune_rows.gd")
const Items := preload("res://src/build/items.gd")
const MakerSets := preload("res://src/build/maker_sets.gd")
const Parts := preload("res://src/build/parts.gd")
const Relics := preload("res://src/build/relics.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const ChallengeDials := preload("res://src/core/challenge_dials.gd")
const PilotBlocks := preload("res://tests/support/pilot_blocks.gd")
const T := preload("res://tests/support/t.gd")

const DIR := "user://w50_player_systems_test/"
const SABLE := "pylon_engineer"

var _t := T.new("w50_player_systems_test")
var _serial := 0


class FakeRun:
	extends RefCounted
	var pilot := "pylon_engineer"
	var kills := 0
	var world := 1
	var run_tier := 0
	var bot_driven := false
	var cursed := false
	var settled: Array = []
	var extra := {}

	func class_id() -> String:
		return pilot

	func selected_run_tier() -> int:
		return run_tier

	func summary() -> Dictionary:
		return {"parts": 0, "retries": 0, "stages": 1, "kills": kills}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean_dir()
	_p1_static_integrity()
	_p2_planted_negative_controls()
	_p3_work_order_and_license_lifecycle()
	_p4_alt_loadouts_and_override_codes()
	_p5_bot_invariance_and_fresh_purity()
	_p6_schema4_and_earned_save_concurrency()
	_p7_codex_story_hooks()
	_p8_mastery_habits_and_world_tier_reads()
	_clean_dir()
	DirAccess.remove_absolute(DIR)
	quit(_t.verdict())


func _clean_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for fname in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + fname)
	for dname in DirAccess.get_directories_at(DIR):
		DirAccess.remove_absolute(DIR + dname)


func _path(tag := "p") -> String:
	_serial += 1
	return "%s%s-%d-%d.json" % [DIR, tag, OS.get_process_id(), _serial]


func _fresh(path := "") -> Profile:
	var store := Profile.new(_path() if path == "" else path)
	store.load_profile()
	return store


func _pilots() -> Array:
	return ClassDef.all().map(func(d): return d.id)


# Predicate 1: Static Integrity & Zero-Dangling-IDs Gate.
func _p1_static_integrity() -> void:
	var pilots := _pilots()
	var bus := Achievements.bus_signals()
	var all_grant_ids := Achievements.all_rows().keys()
	var order_ids := WorkOrders.order_ids()

	_t.eq("P1 WorkOrders.validate passes clean",
		WorkOrders.validate(bus, Items.TABLE, MakerSets.SETS.keys(), TuneRows.ids(), MetaOptions.override_ids(), MetaOptions.alt_loadout_ids(), MetaOptions.ids()), [])
	_t.eq("P1 24 Crew Orders", WorkOrders.CREW_ORDERS.size(), 24)
	_t.eq("P1 12 Shift Orders", WorkOrders.SHIFT_ORDERS.size(), 12)
	_t.eq("P1 7 Maker Licenses", WorkOrders.LICENSES.size(), 7)

	_t.eq("P1 Achievements.ROWS validates clean",
		Achievements.validate(Achievements.ROWS, bus, pilots, Cosmetics.ids()), [])
	_t.eq("P1 Achievements.MASTERY_ROWS validates clean",
		Achievements.validate_mastery(bus, pilots, Cosmetics.ids()), [])
	_t.eq("P1 Achievements.ROWS shared count stays 67",
		PilotBlocks.shared(_t, Achievements.ids(), "res://src/core/achievements.gd").size(), 67)

	_t.eq("P1 ShiftBoard W1 validate clean",
		ShiftBoard.validate(ShiftBoard.RUNGS, Achievements.ROWS, TuneRows.ids(), Items.TABLE), [])
	_t.eq("P1 ShiftBoard W2/W3 validate_world_rungs clean",
		ShiftBoard.validate_world_rungs(Achievements.all_rows(), TuneRows.ids(), Items.TABLE), [])

	# Verify every item opened across WorkOrders, LICENSES, and WORLD_CARDS is live & outside ParkDefs.
	var w50_items: Array = []
	for id in WorkOrders.CREW_ORDERS:
		var item := String(WorkOrders.CREW_ORDERS[id]["pays"].get("item", ""))
		if item != "":
			w50_items.append(item)
	for maker in WorkOrders.LICENSES:
		for t in [1, 2, 3]:
			var item := String(WorkOrders.LICENSES[maker][t]["pays"].get("item", ""))
			if item != "":
				w50_items.append(item)
	for card in ShiftBoard.WORLD_CARDS:
		w50_items.append(String(card["pays"]["item"]))
	_t.eq("P1 all 12 verified free universal items accounted for", w50_items.size(), 12)
	for item in w50_items:
		_t.check("P1 item %s outside ParkDefs.part_in_play and valid in Parts" % item,
			not ParkDefs.part_in_play(item) and not Parts.row(item).is_empty(), item)

	_t.eq("P1 MetaOptions.ROWS validates clean", MetaOptions.validate(MetaOptions.ROWS, Achievements.ROWS), [])
	_t.eq("P1 MetaOptions.OVERRIDE_CODES validates clean", MetaOptions.validate_overrides(order_ids, all_grant_ids), [])
	_t.eq("P1 MetaOptions.ALT_LOADOUTS validates clean", MetaOptions.validate_alt_loadouts(Relics.ROWS, pilots, order_ids, all_grant_ids), [])
	_t.eq("P1 6 Foreman Override Codes", MetaOptions.OVERRIDE_CODES.size(), 6)
	_t.eq("P1 9 Survivor Alternate Loadouts", MetaOptions.ALT_LOADOUTS.size(), 9)

	_t.eq("P1 RunTier.validate passes clean", RunTier.validate(), [])
	for tier in range(RunTier.HARD, RunTier.TOP + 1):
		for key in RunTier.dials(tier):
			_t.check("P1 rung %d key %s exists in ChallengeDials.DEFAULTS" % [tier, key], ChallengeDials.DEFAULTS.has(key), key)


# Predicate 2: Planted Negative Controls.
func _p2_planted_negative_controls() -> void:
	var pilots := _pilots()
	var bus := Achievements.bus_signals()
	var all_grant_ids := Achievements.all_rows().keys()
	var order_ids := WorkOrders.order_ids()

	# (a) Inject hp_mult into RunTier.LADDER -> MUST fail.
	var bad_ladder := RunTier.LADDER.duplicate(true)
	bad_ladder[2]["mobs.hp_mult"] = 1.25
	var tier_errs := RunTier.validate(bad_ladder)
	_t.check("P2 RunTier.validate rejects hp_mult", not tier_errs.is_empty(), str(tier_errs))

	# (b) Inject "cost" key and empty "downside" into MetaOptions.OVERRIDE_CODES -> MUST fail.
	var bad_ov_cost := MetaOptions.OVERRIDE_CODES.duplicate(true)
	bad_ov_cost["code_glass_rail"]["cost"] = 50
	_t.check("P2 validate_overrides rejects cost key",
		not MetaOptions.validate_overrides(order_ids, all_grant_ids, bad_ov_cost).is_empty(), "")

	var bad_ov_down := MetaOptions.OVERRIDE_CODES.duplicate(true)
	bad_ov_down["code_glass_rail"]["downside"] = ""
	_t.check("P2 validate_overrides rejects empty downside",
		not MetaOptions.validate_overrides(order_ids, all_grant_ids, bad_ov_down).is_empty(), "")

	# (c) Point an ALT_LOADOUTS row at cooldown-only relic (quick_fuse) -> MUST fail.
	var bad_alts := MetaOptions.ALT_LOADOUTS.duplicate(true)
	bad_alts["alt_sable_crater"]["relic"] = "quick_fuse"
	bad_alts["alt_sable_crater"]["slot"] = "special"
	_t.check("P2 validate_alt_loadouts rejects cooldown-only relic",
		not MetaOptions.validate_alt_loadouts(Relics.ROWS, pilots, order_ids, all_grant_ids, bad_alts).is_empty(), "")

	# (d) Inject count: 15 Work Order and unknown signal -> WorkOrders.validate() MUST fail.
	var bad_crew_count := WorkOrders.CREW_ORDERS.duplicate(true)
	bad_crew_count["wo_moss_1"]["objective"] = {"on": "beacon_unsealed", "count": 15}
	_t.check("P2 WorkOrders.validate rejects count 15",
		not WorkOrders.validate(bus, Items.TABLE, MakerSets.SETS.keys(), TuneRows.ids(), MetaOptions.override_ids(), MetaOptions.alt_loadout_ids(), MetaOptions.ids(), bad_crew_count).is_empty(), "")

	var bad_crew_sig := WorkOrders.CREW_ORDERS.duplicate(true)
	bad_crew_sig["wo_moss_1"]["objective"] = {"on": "not_a_real_signal", "count": 1}
	_t.check("P2 WorkOrders.validate rejects unknown signal",
		not WorkOrders.validate(bus, Items.TABLE, MakerSets.SETS.keys(), TuneRows.ids(), MetaOptions.override_ids(), MetaOptions.alt_loadout_ids(), MetaOptions.ids(), bad_crew_sig).is_empty(), "")


# Predicate 3: End-to-End Work Order & Maker License Lifecycle.
func _p3_work_order_and_license_lifecycle() -> void:
	var path := _path("wo")
	var store := _fresh(path)
	var bus := GameEvents.new()
	var run := FakeRun.new()
	var listener := Progress.new()
	var wo_events: Array = []
	var story_events: Array = []
	listener.work_order_changed.connect(func(oid: String, phase: String, summary: Dictionary):
		wo_events.append([oid, phase, summary]))
	listener.story_chapter_punched.connect(func(cast_id: String, ch: int, ch_id: String):
		story_events.append([cast_id, ch, ch_id]))
	listener.set_story_chapter_hook(func(trigger_id: String, _p):
		if trigger_id == "order:wo_moss_1":
			return [{"cast": "moss", "num": 1, "id": "moss.ch1"}]
		return [])
	listener.setup(bus, run, store, func(): return 1700000000.0)

	# Auto-pin on fresh profile.
	var pinned := WorkOrders.ensure_default_pin(store)
	_t.eq("P3 fresh profile auto-pins wo_moss_1", pinned, ["wo_moss_1"])

	# Replay real GameEvents sequence.
	bus.run_started.emit(SABLE)
	bus.beacon_unsealed.emit(1)
	_t.check("P3 half-done order not yet settled", not store.is_settled("order:wo_moss_1"), "")
	bus.stage_cleared.emit(1)
	bus.run_ended.emit(true)

	_t.check("P3 order:wo_moss_1 settled", store.is_settled("order:wo_moss_1"), "")
	_t.check("P3 license:moss:1 settled", store.is_settled("license:moss:1"), "")
	_t.eq("P3 Moss Maker License at Tier 1", WorkOrders.license_tier("moss", store), 1)
	_t.eq("P3 Moss Maker License name is Temp Pass", WorkOrders.license_tier_name(WorkOrders.license_tier("moss", store)), "Temp Pass")
	_t.check("P3 momentum_thief opened in ShiftBoard.opened_items",
		ShiftBoard.opened_items(store).has("momentum_thief"), str(ShiftBoard.opened_items(store)))
	_t.eq("P3 work_order_changed emitted once for wo_moss_1", wo_events.size(), 1)
	_t.check("P3 work_order_changed payload matches",
		wo_events[0][0] == "wo_moss_1" and wo_events[0][1] == "completed" and int(wo_events[0][2]["license_tier"]) == 1,
		str(wo_events[0]))
	_t.eq("P3 story_chapter_punched emitted via hook", story_events, [["moss", 1, "moss.ch1"]])

	# Replay identical events: MUST NOT double-pay or re-emit wo_moss_1.
	bus.run_started.emit(SABLE)
	bus.beacon_unsealed.emit(1)
	bus.stage_cleared.emit(1)
	bus.run_ended.emit(true)
	var moss_completions := wo_events.filter(func(e): return e[0] == "wo_moss_1").size()
	_t.eq("P3 replay does not double-pay or re-emit wo_moss_1", moss_completions, 1)
	_t.eq("P3 Moss license stamps stay 1 on replay", WorkOrders.license_stamps("moss", store), 1)

	# Verify persistence on disk after reload.
	var reloaded := _fresh(path)
	_t.check("P3 order & license survive reload",
		reloaded.is_settled("order:wo_moss_1") and reloaded.is_settled("license:moss:1") and WorkOrders.license_tier("moss", reloaded) == 1, "")
	_t.check("P3 Patch issuer reads Unsigned before wo_patch_2",
		WorkOrders.issuer_label("wo_patch_1", reloaded) == "Unsigned", WorkOrders.issuer_label("wo_patch_1", reloaded))

	# Repeatable rotating Shift Order across two consecutive runs:
	# same-run duplicate pays once; second run pays again and advances Maker License to Tier 2 -> Tier 3.
	_t.check("P3 pin repeatable Shift Order so_w1_moss_gamble for run 1", WorkOrders.pin(store, "so_w1_moss_gamble"), "")
	bus.run_started.emit(SABLE)
	bus.trade_taken.emit("trade_risk", Vector3.ZERO)
	bus.trade_taken.emit("trade_risk", Vector3.ZERO) # same-run duplicate MUST NOT double-pay
	bus.run_ended.emit(true)
	var shift_completions_r1 := wo_events.filter(func(e): return e[0] == "so_w1_moss_gamble").size()
	_t.eq("P3 shift order pays once inside run 1", shift_completions_r1, 1)
	_t.eq("P3 shift stat is 1 after run 1", int(store.stat("license.shift.moss")), 1)
	_t.check("P3 shift order is NOT permanently settled in profile.settled", not store.is_settled("order:so_w1_moss_gamble"), "")
	_t.eq("P3 Moss Maker License advances to Tier 2 (Yard Ticket)", WorkOrders.license_tier("moss", store), 2)
	_t.check("P3 license:moss:2 settled", store.is_settled("license:moss:2"), "")

	_t.check("P3 re-pin so_w1_moss_gamble for run 2", WorkOrders.pin(store, "so_w1_moss_gamble"), "")
	bus.run_started.emit(SABLE)
	bus.trade_taken.emit("trade_risk", Vector3.ZERO)
	bus.run_ended.emit(true)
	var shift_completions_r2 := wo_events.filter(func(e): return e[0] == "so_w1_moss_gamble").size()
	_t.eq("P3 shift order repeats and emits again on run 2", shift_completions_r2, 2)
	_t.eq("P3 license.shift.moss reaches 2 across consecutive runs", int(store.stat("license.shift.moss")), 2)
	_t.eq("P3 Moss Maker License reaches Tier 3 (Full License)", WorkOrders.license_tier("moss", store), 3)
	_t.check("P3 license:moss:3 settled", store.is_settled("license:moss:3"), "")

	listener.free()
	bus.free()


# Predicate 4: RoR2 Alt Loadouts & Foreman Override Codes Toggle + Round-Trip.
func _p4_alt_loadouts_and_override_codes() -> void:
	var path := _path("meta_ror2")
	var store := _fresh(path)

	# Locked refusals.
	_t.check("P4 locked alt_sable_crater refused", not MetaOptions.equip_alt_loadout(store, "alt_sable_crater"), "")
	_t.check("P4 locked code_glass_rail refused", not MetaOptions.toggle_override(store, "code_glass_rail"), "")

	# Unlock alt_sable_crater via brindle_mark_sable.
	store.earn("brindle_mark_sable", 10.0)
	_t.check("P4 alt_sable_crater unlocks and equips", MetaOptions.equip_alt_loadout(store, "alt_sable_crater"), "")
	_t.check("P4 profile saves with alt loadout", store.save(), store.last_error)

	var reload_alt := _fresh(path)
	var eq_sable := MetaOptions.equipped_alt_loadouts(reload_alt, SABLE)
	_t.eq("P4 alt loadout persists across reload", eq_sable, {"smash": "alt_sable_crater"})
	var relic_id := String(MetaOptions.alt_loadout("alt_sable_crater")["relic"])
	_t.eq("P4 alt loadout resolves to live Relics.ROWS swap", Relics.row(relic_id)["swap"], "crater_slam")

	# Clear alt loadout.
	MetaOptions.clear_alt_loadout(reload_alt, SABLE, "smash")
	_t.eq("P4 clear_alt_loadout removes equipped slot", MetaOptions.equipped_alt_loadouts(reload_alt, SABLE), {})

	# Unlock code_glass_rail via wo_sable_3 and code_double_shift via wo_patch_3, multi-toggle & persist.
	reload_alt.settle("order:wo_sable_3")
	reload_alt.settle("order:wo_patch_3")
	_t.check("P4 toggle code_glass_rail ON", MetaOptions.toggle_override(reload_alt, "code_glass_rail"), "")
	_t.check("P4 toggle code_double_shift ON", MetaOptions.toggle_override(reload_alt, "code_double_shift"), "")
	_t.check("P4 profile saves with multi overrides", reload_alt.save(), reload_alt.last_error)

	var reload_ov := _fresh(path)
	_t.eq("P4 multi-toggled override codes persist",
		MetaOptions.active_overrides(reload_ov), ["code_glass_rail", "code_double_shift"])
	_t.eq("P4 override_effects carries upside and downside", MetaOptions.override_effects(reload_ov).size(), 2)
	_t.check("P4 toggling code_glass_rail again turns it OFF",
		MetaOptions.toggle_override(reload_ov, "code_glass_rail") and MetaOptions.active_overrides(reload_ov) == ["code_double_shift"],
		str(MetaOptions.active_overrides(reload_ov)))

	# Sitting-mode read parity: locked overrides/alt loadouts toggled with sitting=true read back with sitting=true.
	var sit_store := _fresh()
	_t.check("P4 sitting toggle_override allows locked code", MetaOptions.toggle_override(sit_store, "code_glass_rail", true), "")
	_t.eq("P4 sitting active_overrides reads back toggled code", MetaOptions.active_overrides(sit_store, false, true), ["code_glass_rail"])
	_t.eq("P4 sitting override_effects reads back toggled code", MetaOptions.override_effects(sit_store, false, true).size(), 1)
	_t.eq("P4 non-sitting active_overrides still filters locked code", MetaOptions.active_overrides(sit_store, false, false), [])
	_t.check("P4 sitting equip_alt_loadout allows locked alt", MetaOptions.equip_alt_loadout(sit_store, "alt_sable_crater", true), "")
	_t.eq("P4 sitting equipped_alt_loadouts reads back equipped alt",
		MetaOptions.equipped_alt_loadouts(sit_store, SABLE, false, true), {"smash": "alt_sable_crater"})
	_t.eq("P4 non-sitting equipped_alt_loadouts still filters locked alt",
		MetaOptions.equipped_alt_loadouts(sit_store, SABLE, false, false), {})


# Predicate 5: Bot Invariance & Fresh Profile Purity.
func _p5_bot_invariance_and_fresh_purity() -> void:
	var store := _fresh()
	store.earn("brindle_mark_sable", 10.0)
	store.settle("order:wo_moss_1")
	store.settle("order:wo_sable_3")
	MetaOptions.equip_alt_loadout(store, "alt_sable_crater")
	MetaOptions.toggle_override(store, "code_glass_rail")

	var bus := GameEvents.new()
	var run := RunState.new(bus, 77)
	run.begin(ClassDef.all()[0])
	var bot_tracker := WorkOrders.begin_run(run, store, true)
	_t.eq("P5 bot begin_run returns empty tracker", bot_tracker, {})
	_t.check("P5 bot begin_run leaves RunState.extra free of work_orders", not run.extra.has(WorkOrders.RUN_KEY), str(run.extra))
	_t.eq("P5 bot active_overrides returns empty", MetaOptions.active_overrides(store, true), [])
	_t.eq("P5 bot equipped_alt_loadouts returns empty", MetaOptions.equipped_alt_loadouts(store, SABLE, true), {})
	_t.eq("P5 bot WorkOrders.opened_items returns empty", WorkOrders.opened_items(store, true), [])
	bus.free()

	# Fresh profile purity.
	var fresh := _fresh()
	_t.eq("P5 fresh profile ShiftBoard.opened_items is empty", ShiftBoard.opened_items(fresh), [])
	_t.check("P5 fresh profile hides W2 WORLD_RUNGS", not ShiftBoard.world_rung_shown("dig_warden", fresh), "")
	_t.check("P5 fresh profile hides W3 WORLD_RUNGS", not ShiftBoard.world_rung_shown("highdraft_reached", fresh), "")
	_t.check("P5 fresh profile hides patch_backdoor", not ShiftBoard.world_rung_shown("patch_backdoor", fresh), "")
	_t.eq("P5 fresh profile Act 2 and Act 3 rung lists empty",
		[ShiftBoard.act_rungs(2, fresh).size(), ShiftBoard.act_rungs(3, fresh).size()], [0, 0])


# Predicate 6: Schema-4 Save Compatibility & EarnedSave.tla Concurrency.
func _p6_schema4_and_earned_save_concurrency() -> void:
	# Legacy v4 profile lacking camp keys.
	var legacy_path := _path("legacy_v4")
	var f := FileAccess.open(legacy_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": 4, "generation": 3, "pilots": ["tarn"], "achievements": {"first_win": 100}}))
	f.close()
	var legacy := _fresh(legacy_path)
	_t.eq("P6 Profile.SCHEMA remains 4", Profile.SCHEMA, 4)
	_t.check("P6 legacy v4 loads with zero error", legacy.last_error == "" and legacy.has_pilot("tarn"), legacy.last_error)
	_t.eq("P6 legacy v4 defaults cleanly",
		[WorkOrders.active_ids(legacy), MetaOptions.active_overrides(legacy), MetaOptions.equipped_alt_loadouts(legacy, SABLE)],
		[[], [], {}])

	# Concurrent merge of two Profile documents completing distinct Work Orders & license shift stats.
	var p_a := _path("merge_a")
	var p_b := _path("merge_b")
	var a := _fresh(p_a)
	var b := _fresh(p_b)
	a.settle("order:wo_moss_1")
	a.settle("license:moss:1")
	a.add_stat("license.shift.redjaw", 1.0)
	b.settle("order:wo_sable_1")
	b.settle("license:spillway_works:1")
	b.add_stat("license.shift.redjaw", 2.0)
	_t.check("P6 save a and b", a.save() and b.save(), "%s / %s" % [a.last_error, b.last_error])
	var doc_a: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(p_a))
	var doc_b: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(p_b))
	var merged := Profile.merge(doc_a, doc_b)
	_t.check("P6 merge keeps both settled orders and licenses",
		merged["settled"].has("order:wo_moss_1") and merged["settled"].has("order:wo_sable_1")
		and merged["settled"].has("license:moss:1") and merged["settled"].has("license:spillway_works:1"),
		str(merged["settled"]))
	_t.eq("P6 merge keeps monotonic max license.shift.redjaw", int(merged["stats"]["license.shift.redjaw"]), 2)
	_t.eq("P6 merge duplicates zero settled keys", merged["settled"].count("order:wo_moss_1"), 1)

	# reconcile_settled() skips order:* and license:* prefixes (EarnedSave.tla) while copying ledger.*.
	var r_store := _fresh()
	var r_run := FakeRun.new()
	r_run.settled = ["reward:warden_broken:cosmetic:paint_any_night", "order:wo_moss_1", "license:moss:1", "ledger.found.1"]
	var r_bus := GameEvents.new()
	var r_prog := Progress.new()
	r_prog.setup(r_bus, r_run, r_store, func(): return 1700000000.0)
	r_prog.reconcile_settled()
	_t.check("P6 reconcile_settled skips reward:*", not r_store.is_settled("reward:warden_broken:cosmetic:paint_any_night"), "")
	_t.check("P6 reconcile_settled skips order:*", not r_store.is_settled("order:wo_moss_1"), "")
	_t.check("P6 reconcile_settled skips license:*", not r_store.is_settled("license:moss:1"), "")
	_t.check("P6 reconcile_settled still copies ledger.found.1", r_store.is_settled("ledger.found.1"), "")
	r_prog.free()
	r_bus.free()


# Predicate 7: Codex Story Hooks & Spoiler Suppression.
func _p7_codex_story_hooks() -> void:
	var bus := GameEvents.new()
	var codex := Codex.new()
	root.add_child(codex)
	codex.setup(bus, null, null, DIR)

	codex.declare_story_entries([
		{"id": "patch.rogue.w1", "category": "enemy", "name": "Gate Crane Tape", "hint": "Cut line in the Spillway.", "clue": "Crane 14.", "text": "Governor stuck on loop."},
		{"id": "patch.wire.w1", "category": "world", "name": "Dam Wire Room", "hint": "Follow the red wire.", "clue": "Powerhouse.", "text": "Warm kettle beside the breaker."},
		{"id": "pair.rivet_sable.3", "category": "npc", "name": "Cable Wager", "hint": "Bring both pilots past Brindle.", "clue": "", "text": "Rivet kept the tape."},
	])

	# Unset hooks: all 3 visible, detail returns hint+clue when unknown, text when known.
	_t.eq("P7 unset hooks expose all declared story entries", codex.entries().size(), 3)
	_t.eq("P7 unknown entry_detail joins hint and clue", codex.entry_detail("patch.wire.w1"), "Follow the red wire. Powerhouse.")

	# Install visibility & margin hooks.
	codex.set_story_hooks(
		func(id: String, known_cb: Callable) -> bool:
			if id == "patch.wire.w1":
				return bool(known_cb.call("patch.rogue.w1")) or bool(known_cb.call("patch.wire.w1"))
			if id == "pair.rivet_sable.3":
				return bool(known_cb.call("pair.rivet_sable.3"))
			return true,
		func(id: String, known_cb: Callable) -> String:
			if id == "pair.rivet_sable.3":
				return "\nMargin note: confirmed in the field." if bool(known_cb.call("patch.wire.w1")) else "\nMargin note: check the dam powerhouse."
			return ""
	)

	var before_ids := codex.entries().map(func(e): return String(e["id"]))
	_t.eq("P7 spoiler filter hides gated entries before unlock", before_ids, ["patch.rogue.w1"])

	codex.mark_known("patch.rogue.w1")
	var after_rogue := codex.entries().map(func(e): return String(e["id"]))
	_t.eq("P7 discovering prerequisite exposes patch.wire.w1", after_rogue, ["patch.rogue.w1", "patch.wire.w1"])

	codex.mark_known("pair.rivet_sable.3")
	_t.eq("P7 entry_detail appends unconfirmed margin note",
		codex.entry_detail("pair.rivet_sable.3"), "Rivet kept the tape.\nMargin note: check the dam powerhouse.")
	codex.mark_known("patch.wire.w1")
	_t.eq("P7 entry_detail flips margin note once target known",
		codex.entry_detail("pair.rivet_sable.3"), "Rivet kept the tape.\nMargin note: confirmed in the field.")

	codex.free()
	bus.free()


# Predicate 8: Mastery rows, habit stats, ShiftBoard.reading enrichment, and W2/W3 RunTier reads.
func _p8_mastery_habits_and_world_tier_reads() -> void:
	var store := _fresh()
	var bus := GameEvents.new()
	var run := FakeRun.new()
	run.run_tier = 2
	var listener := Progress.new()
	listener.setup(bus, run, store, func(): return 1700000000.0)

	bus.run_started.emit(SABLE)
	bus.trade_taken.emit("trade_risk", Vector3.ZERO)
	bus.trade_taken.emit("trade_safe", Vector3.ZERO)
	bus.world_entered.emit(2)
	bus.beacon_unsealed.emit(3)
	bus.boss_defeated.emit()
	bus.run_ended.emit(true)

	_t.check("P8 dig_warden_broken earned in world 2", store.earned("dig_warden_broken"), "")
	_t.check("P8 dig_mark_sable earned in world 2 as Sable", store.earned("dig_mark_sable"), "")
	_t.check("P8 hard_rung_1 and hard_rung_2 earned on tier 2 win",
		store.earned("hard_rung_1") and store.earned("hard_rung_2") and not store.earned("hard_rung_3"), "")
	_t.eq("P8 habit stats recorded",
		[int(store.stat("habit.trade_risk")), int(store.stat("habit.trade_safe")), int(store.stat("habit.pilot_runs." + SABLE))],
		[1, 1, 1])

	# ShiftBoard.reading preserves W1 keys and adds active_orders, licenses, act_progress.
	var reading := ShiftBoard.reading(store)
	_t.check("P8 ShiftBoard.reading has additive keys",
		reading.has("active_orders") and reading.has("licenses") and reading.has("act_progress") and reading.has("next"),
		str(reading.keys()))

	# RunTier world-filtered dials keep world boss only and drop foreign bosses.
	var w2_dials := RunTier.dials_for_world(4, 2)
	_t.check("P8 dials_for_world(4, 2) includes waking.* and excludes brindle.*/mind.*",
		w2_dials.has("waking.punish_mult") and not w2_dials.has("brindle.damage_mult") and not w2_dials.has("mind.damage_mult"),
		str(w2_dials))
	var w3_dials := RunTier.dials_for_world(5, 3)
	_t.check("P8 dials_for_world(5, 3) includes mind.* and excludes brindle.*/waking.*",
		w3_dials.has("mind.punish_mult") and not w3_dials.has("brindle.damage_mult") and not w3_dials.has("waking.damage_mult"),
		str(w3_dials))
	_t.eq("P8 meters(4, 2) returns 4 gauges", RunTier.meters(4, 2).size(), 4)

	listener.free()
	bus.free()
