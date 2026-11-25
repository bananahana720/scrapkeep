extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Consumables := preload("res://src/build/consumables.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const MetaOptions := preload("res://src/core/meta_options.gd")
const PilotStory := preload("res://src/core/pilot_story.gd")
const Progress := preload("res://src/core/progress.gd")
const Profile := preload("res://src/core/profile.gd")
const Relics := preload("res://src/build/relics.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const RunState := preload("res://src/core/run_state.gd")
const TradePockets := preload("res://src/world/trade_pockets.gd")
const WorkOrders := preload("res://src/core/work_orders.gd")
const Weapons := preload("res://src/combat/weapons.gd")

var _t := T.new("w50_systems_opt_regression_test")


func _check(cond: bool, msg: String) -> void:
	_t.check(msg, cond)


func _chapter(id: String) -> Dictionary:
	for row in PilotStory.CHAPTERS:
		if String(row.get("id", "")) == id:
			return row
	return {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_bindings_and_story_and_lore()
	_test_run_state_ingots_and_overrides()
	_test_work_orders_and_progress_habits()
	await _test_live_game_wiring()
	quit(_t.verdict())


func _test_bindings_and_story_and_lore() -> void:
	var actions := Bindings.actions()
	_check(int(actions["cl_consumable"].get("pad", -1)) == JOY_BUTTON_LEFT_STICK,
		"cl_consumable maps to JOY_BUTTON_LEFT_STICK")
	_check(int(actions["cl_bay_2"].get("pad", -1)) != int(actions["cl_consumable"].get("pad", -1)),
		"cl_consumable and cl_bay_2 do not collide on pad")

	var kest_ch3 := _chapter("demolitions_caster.ch3")
	_check("order:wo_kest_2" in kest_ch3.get("accepts", []), "kest ch3 accepts order:wo_kest_2")
	var cannon_ch4 := _chapter("remembered_cannon.ch4")
	_check("order:wo_cannon_3" in cannon_ch4.get("accepts", []), "cannon ch4 accepts order:wo_cannon_3")
	var patch_ch2 := _chapter("patch.ch2")
	_check("codex:patch.wire.w1" in patch_ch2.get("accepts", []) and not ("order:wo_patch_1" in patch_ch2.get("accepts", [])),
		"patch ch2 accepts codex:patch.wire.w1 not wo_patch_1")
	var sable_ch5 := _chapter("pylon_engineer.ch5")
	_check("crown_mark_sable" in sable_ch5.get("accepts", []) and not ("first_win" in sable_ch5.get("accepts", [])),
		"sable ch5 accepts crown_mark_sable")
	var moss_ch2 := _chapter("moss.ch2")
	var moss_ch5 := _chapter("moss.ch5")
	_check(not String(moss_ch2.get("note", "")).contains("he still") and not String(moss_ch5.get("note", "")).contains("his own"),
		"moss chapters stay gender-neutral")

	for key in LoreRows.WORLD_TWO_COLD_OPEN:
		var entry: Dictionary = LoreRows.WORLD_TWO_COLD_OPEN[key]
		var blob := "%s %s" % [String(entry.get("title", "")), String(entry.get("line", ""))]
		_check(not blob.contains("—"), "WORLD_TWO_COLD_OPEN[%s] has no em-dash" % String(key))
	for row in LoreRows.KEST_RESCUE_BANTER:
		var blob := String(row.get("line", row.get("text", ""))) if row is Dictionary else String(row)
		_check(not blob.contains("—"), "KEST_RESCUE_BANTER has no em-dash")

	_check(not String(Consumables.row_of(Consumables.CAP_CHARGE)["headline"]).contains("Tier 5"),
		"CAP_CHARGE headline clean of Tier 5 jargon")
	_check(not String(Consumables.row_of(Consumables.OVERCLOCK_CARD)["headline"]).contains("CD"),
		"OVERCLOCK_CARD headline clean of CD jargon")
	_check(not String(Consumables.row_of(Consumables.ANCHOR_FLARE)["headline"]).contains("sky-grapple"),
		"ANCHOR_FLARE headline clean of sky-grapple jargon")


func _test_run_state_ingots_and_overrides() -> void:
	var ev := preload("res://src/core/game_events.gd").new()
	var run := RunState.new(ev, 42)
	var def = preload("res://src/core/class_def.gd").by_id("pylon_engineer")
	run.begin(def)
	var normal_hp := run.base_max_hp()
	run.extra["overrides"] = ["code_glass_rail"]
	_check(run.override_on("hull_half") and run.override_on("impact_force_2x"),
		"RunState.override_on exposes code_glass_rail effects")
	_check(is_equal_approx(run.base_max_hp(), normal_hp * 0.5),
		"hull_half halves base_max_hp")

	Fabricators.ingots_from_doc(run, {"1": 2, "2": 1, "3": 0})
	run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	Fabricators.ingots_from_doc(run, {"1": 5, "2": 3, "3": 1})
	run.restore()
	var restored_ingots := Fabricators.scrap_ingots(run)
	_check(int(restored_ingots.get(1, 0)) == 2 and int(restored_ingots.get(2, 0)) == 1,
		"RunState.restore rewinds scrap_ingots to checkpoint")

	var doc := run.to_entrance_doc(null)
	_check(doc.has("scrap_ingots") and RunState.validate_entrance_doc(doc) == "",
		"Entrance doc with scrap_ingots validates cleanly")
	var bad_doc := doc.duplicate(true)
	bad_doc["scrap_ingots"] = {"1": -1}
	_check(RunState.validate_entrance_doc(bad_doc) != "",
		"Negative scrap_ingots in entrance doc rejected")

	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var drew_risk_only := true
	for _i in 30:
		var offer := TradePockets.draw(TradePockets.memory(), 1, rng, false, true)
		if not offer.is_empty() and String(offer.get("family", "")) != "risk":
			drew_risk_only = false
	_check(drew_risk_only, "kindness_sealed prevents safe/kindness trade counters")

	var p := Profile.new("user://test-override-check.json")
	_check(MetaOptions.active_overrides(p, true, false).is_empty(),
		"Bot runs never activate overrides")
	ev.free()


func _test_work_orders_and_progress_habits() -> void:
	var p := Profile.new("user://test-wo-check.json")
	p.unlock_pilot("runner_gunner")
	var pinned_rivet: Array = WorkOrders.ensure_default_pin(p, false, "runner_gunner")
	var pin_rivet := String(pinned_rivet[0]) if not pinned_rivet.is_empty() else ""
	_check(String(WorkOrders.order(pin_rivet).get("pilot", "")) == "runner_gunner",
		"ensure_default_pin prefers available Crew Order for current pilot")

	var ev := preload("res://src/core/game_events.gd").new()
	var run := RunState.new(ev, 99)
	run.bot_driven = false
	var def = preload("res://src/core/class_def.gd").by_id("pylon_engineer")
	run.begin(def)
	var codex := preload("res://src/core/codex.gd").new()
	var prog := Progress.new()
	prog.setup(ev, run, p, Callable(), codex)

	var rogue_facts: Array[String] = []
	ev.world_fact.connect(func(kind: String, _at: Vector3): rogue_facts.append(kind))
	ev.enemy_killed.emit("rogue_crane", Vector3.ZERO, 10)
	_check("rogue_downed" in rogue_facts, "Rogue kill emits rogue_downed world_fact")
	_check(codex.known("patch.rogue.w1"), "Rogue kill marks patch.rogue.w1 in codex")

	WorkOrders.begin_run(run, p, false, false)
	_check(run.extra.has(WorkOrders.RUN_KEY), "WorkOrders.begin_run attaches tracker to run.extra")
	prog._wo_tracker = {}
	prog.reconcile_settled()
	_check(not prog._wo_tracker.is_empty(), "Progress.reconcile_settled restores _wo_tracker on Continue")
	ev.free()
	codex.free()
	prog.free()


func _test_live_game_wiring() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.bot_driven = false
	_check(game.run.bot_driven == false, "game.bot_driven setter syncs to run.bot_driven")

	game.flow.press_start()
	game.flow.choose_class(0)
	var picks: Array = ["rivet_plating", "magnet_spool"]
	game.build.gates.open(picks, game.player.ball_position(), Vector3.FORWARD, game.run.parts)
	var before_ids: Array = game.build.gates.offers.map(func(o): return String(o["part_id"]))
	game.run.bonus_cores = 1
	var cogs_before: int = int(game.run.cogs)
	var dice_res: Dictionary = game.combat.use_consumable(Consumables.SCRAP_DICE)
	var after_ids: Array = game.build.gates.offers.map(func(o): return String(o["part_id"]))
	_check(int(dice_res.get("rerolled_gates", 0)) > 0, "Audit Die rerolls standing reward gates")
	_check(after_ids != before_ids, "Audit Die replaces gate part_ids")
	_check(game.build.gates._ids == after_ids, "RewardGates._ids matches rebuilt offers")
	_check(game.run.bonus_cores == 0 and String(dice_res.get("cost", "")) == "core",
		"Audit Die spends 1 bonus core as Foreman fee when held")
	_check(int(game.run.cogs) == cogs_before, "Audit Die spends 0 cogs")
	game.build.gates.close()

	var look := RewardGates.taken_look(Consumables.BELT_OFFER_ID)
	_check(String(look.get("name", "")) == "Pocket Belt", "RewardGates.taken_look handles consumable offers")
	var slots_before: int = int(game.run.consumable_slots)
	game.build._on_gate_chosen(Consumables.BELT_OFFER_ID)
	_check(int(game.run.consumable_slots) == mini(RunState.CONSUMABLE_SLOTS_MAX, slots_before + 1),
		"Choosing belt gate offer expands consumable slots")

	game.combat.use_consumable(Consumables.DUPLICATOR_SPOOL)
	var cores_before: int = int(game.run.bonus_cores)
	game.run.add_core("test_vault", Vector3.ZERO)
	_check(int(game.run.bonus_cores) == cores_before + 2, "Carbon Tape clones core_gained once")
	_check(not Consumables.duplicator_armed(game.run), "Carbon Tape disarms after 1 clone")

	game.combat.use_consumable(Consumables.DUPLICATOR_SPOOL)
	var parts_before: int = (game.run.parts as Array).size()
	game.run.add_part("rivet_plating", "test_cache")
	_check((game.run.parts as Array).size() == parts_before + 2, "Carbon Tape clones part_gained once")

	game.combat.use_consumable(Consumables.OVERLOAD_FUSE)
	_check(Consumables.overload_armed(game.run), "Breaker Fuse arms overload_fuse")
	var rec := {"landing_hits": 0, "damage": 0.0}
	game.combat.ultimate.report_landing(rec, "cable_run", game.player.ball_position(), [1, 40.0])
	_check(not Consumables.overload_armed(game.run), "Breaker Fuse fires and disarms on ultimate landing")

	var warden = game.combat.spawn_enemy("warden", game.player.ball_position() + Vector3(2.0, 0.0, 0.0))
	if warden != null:
		warden.global_position = game.player.ball_position() + Vector3(2.0, 0.0, 0.0)
	_check(warden != null and warden.has_method("apply_posture_hit"), "Warden exposes apply_posture_hit()")
	var cap_res: Dictionary = game.combat.use_consumable(Consumables.CAP_CHARGE)
	_check(int(cap_res.get("hits", 0)) >= 1, "Blasting Cap hits Warden cleanly without type error")

	var sign_res := TradePockets.sign_overtime_contract(game.run)
	_check(bool(sign_res.get("ok", false)), "Overtime Contract signs")
	var cogs_pre_settle: int = int(game.run.cogs)
	game.events.stage_cleared.emit(game.run.stage)
	_check(int(game.run.cogs) > cogs_pre_settle, "stage_cleared auto-settles signed Overtime Contract")

	game.combat.orbitals.storm_charges = 5
	game.events.player_died.emit()
	_check(int(game.combat.orbitals.storm_charges) == 0, "OrbitalSatellites resets on player_died")

	var rapid_p: Resource = game.combat._patterns.get(Weapons.RAPID_LASER)
	var hot: int = int(game.combat.weapon_driver.hot_reload_cylinder(Weapons.RAPID_LASER, rapid_p))
	_check(hot > 0, "WeaponDriver.hot_reload_cylinder loads hot rounds")

	game.run.extra["overrides"] = ["code_open_manifest"]
	game.build.shop.stocked_for = []
	game.build.shop.enter()
	_check(game.build.shop.shelf.is_empty(), "code_open_manifest keeps shop shelves shut")

	var alt_pool := Relics.eligible("pylon_engineer", {}, null, 1, true)
	_check(alt_pool.size() > Relics.eligible("pylon_engineer", {}, null, 1, false).size(),
		"Relics.eligible with include_alt=true exposes W50 alt relics")

	game.free()
