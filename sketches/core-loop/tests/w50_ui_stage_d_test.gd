extends SceneTree

# Wave 50 Stage D Four-Hand UI/UX verification suite:
# 1. Camp Dispatch / Work Orders & Repeatable Shift Orders, 7 Maker Licenses, and RoR2 Run Overrides
# 2. W1-W3 ShiftBoard Act progress + RunTier world gauges + active Overrides on StartPickCard
# 3. Per-Pilot Alt Loadouts on ClassCard + ClassKit live swap preview (zero words added on fresh profile)
# 4. Logbook / Codex 5 tabs: Entries, 40-chapter PilotStory arcs (Patch hidden on fresh profile),
#    15-pair Chemistry + synthesis margins, 6-node Patch Wire Trail, and Old-Works Foreman Habit Ledger
# 5. In-Run HUD 9-item wordless ConsumableSlot carousel + W50 armed state + Progress listeners
# 6. Moss's Shop Counter W47-W50 faces: Tri-Terminal, Pocket Consumables, Pocket Belt, Scrapper, and Part Press
# 7. Camp Hub new stations (dispatch on camp_shift_board, logbook on camp_tarp) + Settings active/cl_consumable
# 8. Four-Hand & zero-slop compliance checks across all Stage D UI surfaces.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WorkOrders := preload("res://src/core/work_orders.gd")
const MetaOptions := preload("res://src/core/meta_options.gd")
const PilotStory := preload("res://src/core/pilot_story.gd")
const ShiftBoard := preload("res://src/core/shift_board.gd")
const Consumables := preload("res://src/build/consumables.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const WorkOrdersPage := preload("res://src/ui/work_orders_page.gd")
const LogbookPage := preload("res://src/ui/logbook_page.gd")
const MetaPage := preload("res://src/ui/meta_page.gd")
const ClassKit := preload("res://src/ui/class_kit.gd")
const CallerTile := preload("res://src/ui/caller_tile.gd")
const SettingsPages := preload("res://src/ui/settings_pages.gd")
const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Push := preload("res://tests/workshop/push.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("w50_ui_stage_d_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _physics(n: int) -> void:
	for _i in n:
		await physics_frame


func _put_in(id: String) -> void:
	var hub = _game.camp_hub
	var centre: Vector3 = hub.zone_position(id)
	var toward: Vector3 = hub.root.global_position - centre
	toward.y = 0.0
	var at: Vector3 = centre + toward.normalized() * 1.5
	at.y = 1.3
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	await _physics(4)


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.screens.prologue_enabled = false

	await _check_work_orders_licenses_overrides()
	await _check_w2_w3_shift_board_and_camp_stations()
	await _check_pilot_alt_loadouts_and_briefing()
	await _check_logbook_story_surfaces()
	await _check_hud_consumable_carousel_and_shop_faces()
	_check_settings_and_callers_and_slop_guards()

	Consumables._reset()
	_game.queue_free()
	quit(_t.verdict())


func _check_work_orders_licenses_overrides() -> void:
	var screens = _game.screens
	var profile = _game.ctx.profile

	# Open Work Orders from title via toggle_work_orders / KEY_O.
	Push.key(root, KEY_O)
	await _frames(2)
	_t.check("O on title opens Work Orders page", screens.work_orders_open() and screens.overlay_open())
	var page = screens.work_orders_page()
	_t.eq("default tab is orders", page.active_tab, "orders")
	_t.check("fresh profile auto-pins wo_moss_1 in pinned strip", page.pinned_summary().size() == 1 and page.order_rows.has("wo_moss_1"))

	# Pin a repeatable Shift Order in slot 1 alongside Crew Order in slot 0.
	var shift_offers := WorkOrders.shift_offers(profile)
	_t.check("shift offers populated on page", not shift_offers.is_empty() and page.order_rows.has(shift_offers[0]))
	_t.check("pinning a shift order succeeds", page.press_order(shift_offers[0]) and WorkOrders.active_ids(profile).size() == 2)
	_t.check("unpinning a shift order succeeds", page.press_order(shift_offers[0]) and WorkOrders.active_ids(profile).size() == 1)

	# Patch issuer secrecy before wo_patch_2.
	_t.eq("Patch order issuer stays Unsigned before wo_patch_2", WorkOrders.issuer_label("wo_patch_1", profile), "Unsigned")
	if page.order_rows.has("wo_patch_1"):
		_t.check("wo_patch_1 row never leaks Patch name early", not String(page.order_rows["wo_patch_1"].text).contains("Patch"))

	# Switch tabs via keyboard E and pad RB.
	Push.key(root, KEY_E)
	await _frames(1)
	_t.eq("E switches Work Orders to licenses tab", page.active_tab, "licenses")
	_t.eq("all 7 Maker Licenses rendered", page.license_cards.size(), WorkOrders.LICENSES.size())

	Push.pad(root, JOY_BUTTON_RIGHT_SHOULDER)
	await _frames(1)
	_t.eq("pad RB switches Work Orders to overrides tab", page.active_tab, "overrides")
	_t.eq("all 6 Foreman Override Codes rendered", page.override_rows.size(), MetaOptions.OVERRIDE_CODES.size())
	_t.eq("all 4 Head Starts rendered", page.head_start_rows.size(), MetaOptions.ids().size())
	_t.check("locked override code refuses toggle", not page.press_override("code_glass_rail") and MetaOptions.active_overrides(profile).is_empty())

	# Unlock an override code and toggle ON/OFF.
	profile.settle("order:wo_sable_3")
	page.refresh(profile)
	page.show_tab("overrides")
	_t.check("unlocked override code toggles ON", page.press_override("code_glass_rail") and "code_glass_rail" in MetaOptions.active_overrides(profile))
	_t.check("unlocked override code toggles OFF", page.press_override("code_glass_rail") and MetaOptions.active_overrides(profile).is_empty())

	# Standalone MetaPage also exposes override rows cleanly while keeping legacy rows/level_text intact.
	var meta := MetaPage.new()
	meta.refresh(profile)
	_t.eq("MetaPage keeps legacy rows keys", meta.rows.keys(), MetaOptions.ids())
	_t.eq("MetaPage adds all 6 override_rows", meta.override_rows.size(), MetaOptions.OVERRIDE_CODES.size())
	meta.free()

	# Escape closes Work Orders cleanly back to title.
	Push.key(root, KEY_ESCAPE)
	await _frames(2)
	_t.check("Esc closes Work Orders back to title", not screens.work_orders_open() and _game.flow.state_name() == "title")


func _check_w2_w3_shift_board_and_camp_stations() -> void:
	var screens = _game.screens
	var profile = _game.ctx.profile

	# Fresh profile shows zero W2/W3 act cards; unlocking W2/W3 surfaces Act II & Act III strips.
	screens.toggle_achievements()
	await _frames(2)
	var ach = screens.achievements_page()
	_t.eq("fresh AchievementsPage hides W2/W3 acts", ach.world_act_cards.size(), 0)
	_t.check("AchievementsPage exposes Work Orders and Logbook buttons", ach.orders_button != null and ach.logbook_button != null)

	profile.earn("brindle_routed", 100.0)
	profile.earn("waking_stilled", 200.0)
	ach.refresh(profile, _game.progress)
	_t.check("AchievementsPage surfaces Act II and Act III strips once unlocked",
		ach.world_act_cards.has(2) and ach.world_act_cards.has(3))

	# O from Achievements jumps straight into Work Orders.
	Push.key(root, KEY_O)
	await _frames(2)
	_t.check("O from Achievements opens Work Orders", screens.work_orders_open() and not screens.achievements_open())
	Push.key(root, KEY_ESCAPE)
	await _frames(2)

	# Camp Hub walk: dispatch (camp_shift_board) and logbook (camp_tarp) stations reachable.
	_game._screen_key(KEY_K)
	await _frames(3)
	var hub = _game.camp_hub
	_t.check("camp hub registers dispatch and logbook zones", hub.zone_ids().has("dispatch") and hub.zone_ids().has("logbook"))
	await _put_in("dispatch")
	_t.check("dispatch station prompt shows Work orders", hub.card_for("dispatch") != null and hub.card_for("dispatch").text == "Work orders")
	_game._screen_key(KEY_O)
	await _frames(2)
	_t.check("O at dispatch station opens Work Orders over walk", screens.work_orders_open() and screens.walking() and not screens.walk_live())
	Push.key(root, KEY_ESCAPE)
	await _frames(2)
	_t.check("Esc returns from Work Orders to walk", not screens.work_orders_open() and screens.walk_live())

	await _put_in("logbook")
	_t.check("logbook station prompt shows Logbook", hub.card_for("logbook") != null and hub.card_for("logbook").text == "Logbook")
	_game._screen_key(KEY_L)
	await _frames(2)
	_t.check("L at logbook station opens Logbook over walk", screens.logbook_open() and screens.walking() and not screens.walk_live())
	Push.pad(root, JOY_BUTTON_B)
	await _frames(2)
	_t.check("pad B returns from Logbook to walk", not screens.logbook_open() and screens.walk_live())

	_game._screen_key(KEY_K)
	await _frames(2)


func _check_pilot_alt_loadouts_and_briefing() -> void:
	var screens = _game.screens
	var profile = _game.ctx.profile

	# Unlock Sable's alt loadout (brindle_mark_sable -> alt_sable_crater).
	profile.earn("brindle_mark_sable", 300.0)
	_game.flow.press_start()
	await _frames(3)
	var cards: Array = screens.class_cards()
	var sable = cards[0]
	_t.check("Sable card detects unlocked alt loadout", sable.owns_alt() and sable.alt_options().has("alt_sable_crater"))
	var equipped: String = sable.cycle_alt_loadout()
	_t.eq("cycling Sable alt loadout equips alt_sable_crater", equipped, "alt_sable_crater")
	_t.eq("profile persists equipped alt loadout", MetaOptions.equipped_alt_loadouts(profile, "pylon_engineer"), {"smash": "alt_sable_crater"})
	var kit_keys := ClassKit.card_keys_for(sable.def, profile)
	var smash_swapped := kit_keys.any(func(k): return String(k.get("ability", "")) == "crater_slam" and bool(k.get("swapped", false)))
	_t.check("ClassKit.card_keys_for reflects crater_slam swap", smash_swapped)
	# Cycle back to Stock kit cleanly.
	var back_stock: String = sable.cycle_alt_loadout()
	_t.eq("second cycle returns to Stock kit", back_stock, "")

	# Verify StartPickCard renders active override codes when armed.
	MetaOptions.toggle_override(profile, "code_glass_rail")
	_game.flow.choose_class(0)
	await _frames(4)
	var card = _game.flow.start_card
	if card != null:
		card.set_interactive(true)
		card.show_picks(_game.run, profile)
		var words: Array = card.drawn_words()
		_t.check("StartPickCard shows armed Foreman Override code", "Glass Rail" in words, str(words))
	MetaOptions.toggle_override(profile, "code_glass_rail")
	_game.flow.show_title()
	await _frames(2)


func _check_logbook_story_surfaces() -> void:
	var screens = _game.screens
	var profile = _game.ctx.profile
	var codex = _game.ctx.codex

	# Fresh-ish Patch secrecy check on Logbook.
	Push.key(root, KEY_L)
	await _frames(2)
	_t.check("L on title opens Logbook", screens.logbook_open())
	var lb = screens.logbook_page()
	_t.eq("Logbook opens on entries tab", lb.active_tab, "entries")
	_t.check("Entries tab populates rows", lb.rows.size() > 0)

	# Crew Arcs tab: Patch hidden before ch1 punches; stays "Unsigned" after ch1 until wo_patch_2.
	lb.show_tab("arcs")
	await _frames(1)
	_t.check("Crew Arcs hides Patch card before ch1 punches", not lb.arc_rows.has("patch") and lb.arc_rows.size() == 7)
	# Punch patch.ch1 -> Patch card appears, still labeled "Unsigned" before wo_patch_2!
	codex.mark_known("patch.rogue.w1")
	PilotStory.record_overtime("pylon_engineer", 2, profile)
	lb.show_tab("arcs")
	_t.check("Crew Arcs reveals Patch card once patch.rogue.w1 known", lb.arc_rows.has("patch") and lb.arc_rows.size() == 8)
	_t.check("Crew Arcs keeps Patch named Unsigned before wo_patch_2",
		(lb.arc_rows["patch"] as Button).text.begins_with("Unsigned") and not (lb.arc_rows["patch"] as Button).text.contains("Patch"))
	lb.open_arc("patch")
	_t.check("Patch arc detail stays Unsigned before wo_patch_2", lb.detail.text.begins_with("Unsigned") and not lb.detail.text.contains("Patch"))
	lb.open_arc("pylon_engineer")
	_t.check("Crew Arc detail reads real overtime rung and non-empty open chapter lead",
		lb.detail.text.contains("Overtime rung 2") and lb.detail.text.contains("Next lead"))

	# Chemistry tab: all 15 pairs rendered + synthesis margin updates live.
	lb.show_tab("pairs")
	await _frames(1)
	_t.eq("Chemistry tab renders all 15 pairs", lb.pair_rows.size(), 15)
	codex.mark_known("pair.rivet_sable.1")
	codex.mark_known("pair.rivet_sable.2")
	codex.mark_known("pair.rivet_sable.3")
	lb.open_pair("rivet_sable")
	_t.check("Chemistry detail renders synthesis margin note", lb.detail.text.contains("Margin note"))
	codex.mark_known("wrecking_ball")
	lb.open_pair("rivet_sable")
	_t.check("Chemistry synthesis margin flips confirmed on linked discovery", lb.detail.text.contains("confirmed in the field"))

	# Wire Trail tab: progressive spoiler gating + real "log" body text.
	lb.show_tab("trail")
	await _frames(1)
	_t.check("Wire Trail reveals w1 wire after rogue w1 and keeps w2 wire hidden",
		lb.trail_rows.has("patch.rogue.w1") and lb.trail_rows.has("patch.wire.w1") and not lb.trail_rows.has("patch.wire.w2"))
	lb.open_trail_node("patch.rogue.w1")
	_t.check("Logged Wire Trail node renders PilotStory PATCH_TRAIL log body",
		lb.detail.text.contains("insulated shears"), lb.detail.text)

	# Foreman Ledger tab: dormant < 3 runs (never leaks unearned memos), active axis >= 3 runs with real total_runs & axis names.
	lb.show_tab("foreman")
	await _frames(1)
	_t.check("Foreman Ledger reads dormant on < 3 runs", lb.detail.text.contains("DORMANT"))
	lb._show_foreman_axis("chronic_gambler", PilotStory.classify_habits(profile, []))
	_t.check("Dormant Foreman refuses to leak unearned axis memos", lb.detail.text.contains("DORMANT"), lb.detail.text)
	profile.set_stat("habit.runs_total", 4.0)
	profile.set_stat("habit.trade_risk", 6.0)
	lb.show_tab("foreman")
	_t.check("Foreman Ledger reads real total_runs and active axis name",
		lb._summary_label.text.contains("4 shifts recorded") and lb.detail.text.contains("Risk taker") and not lb.detail.text.contains("Score "),
		"%s | %s" % [lb._summary_label.text, lb.detail.text])
	var panel_box = lb._detail_panel.get_theme_stylebox("panel")
	_t.eq("Foreman Ledger detail plate uses OLD_WORKS hand", panel_box.hand, UiTokens.Hand.OLD_WORKS)

	Push.key(root, KEY_ESCAPE)
	await _frames(2)
	_t.check("Esc closes Logbook", not screens.logbook_open())


func _check_hud_consumable_carousel_and_shop_faces() -> void:
	_game.flow.press_start()
	_game.flow.choose_class(1) # Rivet
	await _physics(6)
	var run = _game.ctx.run
	var hud = _game.hud
	var ws = _game.get_node("Workshop")
	var shop = _game.build.shop

	# 1. Wordless 9-item ConsumableSlot carousel + W50 armed indicators.
	run.clear_consumables()
	run.expand_consumable_belt(2)
	run.add_consumable(Consumables.SCRAP_DICE)
	run.add_consumable(Consumables.DUPLICATOR_SPOOL)
	await _frames(3)
	hud.layout(Vector2(1600.0, 900.0))
	var slot: Control = hud.consumable_slot
	var labels: Array = slot.find_children("*", "Label", true, false)
	_t.check("2-slot ConsumableSlot carousel widens cleanly with zero Label nodes",
		slot.showing() and labels.is_empty() and slot.size.x > slot.SLOT_SIZE.x and slot.held_ids().size() == 2)
	# Armed state keeps slot showing after popping Carbon Tape even when belt empties.
	run.clear_consumables()
	Consumables.fire_w50(Consumables.DUPLICATOR_SPOOL, _game.ctx, _game.ctx.spawner, Vector3.ZERO)
	await _frames(2)
	_t.check("ConsumableSlot shows Carbon Tape armed window when belt empty",
		slot.showing() and float(slot.armed_state()["duplicator_left"]) > 0.0)
	Consumables.clear_w50(run)
	await _frames(2)
	_t.check("ConsumableSlot hides again once empty and disarmed", not slot.showing())

	# 2. Progress -> HUD work_order_changed & story_chapter_punched listeners.
	_game.progress.work_order_changed.emit("wo_moss_1", "completed", {"license_tier": 1, "new_license_tiers": [1]})
	_game.progress.story_chapter_punched.emit("moss", 1, "moss.ch1")
	await _frames(2)
	var waiting: Array = hud.ach_toasts() + hud.ach_waiting()
	_t.check("HUD listens to work_order_changed and story_chapter_punched", waiting.size() >= 1, str(waiting))
	hud.clear_achievement_toasts()

	# 3. Shop Counter W47-W50 faces: Stock (Tri-Terminal + Consumables + Belt) & Fab (Scrapper + Press).
	ws.armed = true
	shop.enter()
	run.cogs = 600
	run.parts.clear()
	run.add_part("hot_rivets", "test")
	run.add_part("light_frame", "test")
	ws.open_counter()
	await _frames(3)

	# Switch to "stock" face.
	ws.counter.set_face("stock")
	await _frames(2)
	var tri0 = ws.counter.tile_for("tri", 0)
	var cons0 = ws.counter.tile_for("consumable", 0)
	var belt_tile = ws.counter.tile_for("belt", 0)
	_t.check("Shop stock face shows Tri-Terminal, Consumables, and Pocket Belt (no un-wired contract tiles)",
		tri0 != null and cons0 != null and belt_tile != null and ws.counter.tile_for("contract_overtime", 0) == null)
	# Buy 1 Tri-Terminal choice -> locks remaining 2.
	ws.counter.press(tri0)
	await _frames(1)
	_t.check("buying Tri-Terminal tile closes terminal", shop.tri_terminal_closed and ws.counter.tile_for("tri", 1).state() == "sold")
	# Buy a Pocket Consumable.
	var cons_before: int = run.consumables.size()
	ws.counter.press(ws.counter.tile_for("consumable", 0))
	await _frames(1)
	_t.eq("buying consumable tile adds cartridge to belt", run.consumables.size(), cons_before + 1)

	# Switch to "fab" face: Scrapper + Part Press.
	ws.counter.set_face("fab")
	await _frames(2)
	var scrap0 = ws.counter.tile_for("scrap", 0)
	var press0 = ws.counter.tile_for("press", 0)
	_t.check("Shop fab face shows Scrapper and Part Press tiles", scrap0 != null and press0 != null)
	var scrapped_id := String(scrap0.rec["part_id"])
	ws.counter.press(scrap0)
	await _frames(1)
	var t_scrapped := Fabricators.tier_of(scrapped_id)
	_t.check("Scrapper tile converts part to rarity-matched Scrap Ingot", Fabricators.ingot_count(run, t_scrapped) >= 1)
	var press_target = ws.counter.tile_for("press", 0)
	if press_target != null:
		var target_id := String(press_target.rec["part_id"])
		var count_before: int = run.part_count(target_id)
		ws.counter.press(press_target)
		await _frames(1)
		_t.eq("Part Press tile duplicates target part spending ingot", run.part_count(target_id), count_before + 1)

	ws.close_counter()
	shop.leave()


func _check_settings_and_callers_and_slop_guards() -> void:
	_t.check("SettingsPages.VERBS includes active", "active" in SettingsPages.VERBS)
	_t.check("SettingsPages.EXTRA_WORDS includes cl_consumable and drops redundant cl_active",
		SettingsPages.EXTRA_WORDS.has("cl_consumable") and not SettingsPages.EXTRA_WORDS.has("cl_active"))
	var tile := CallerTile.new()
	_t.check("CallerTile supports unsigned and patch callers",
		not tile.look_of("unsigned").is_empty() and not tile.look_of("patch").is_empty()
		and not tile.look_of("dig_crew").is_empty() and not tile.look_of("crown_watch").is_empty())
	tile.free()

	# Ruling ek & §13 guards: WorkOrdersPage and LogbookPage never reference PAID or Palette.KINDNESS,
	# and WorkOrdersPage resolves option payouts (e.g. wo_patch_1).
	var wo_tmp := WorkOrdersPage.new()
	_t.check("WorkOrdersPage _pay_words handles option payouts",
		wo_tmp._pay_words({"option": "pocket_key"}).contains("Opens "))
	wo_tmp.free()
	for path in ["res://src/ui/work_orders_page.gd", "res://src/ui/logbook_page.gd"]:
		var src := FileAccess.get_file_as_string(path)
		_t.check("%s has zero Palette.KINDNESS and zero PAID" % path,
			not src.contains("Palette.KINDNESS") and not src.contains("\"PAID\""))
