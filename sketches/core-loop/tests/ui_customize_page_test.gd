extends SceneTree

const Game := preload("res://src/game.gd")
const Customize := preload("res://src/ui/customize_page.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Push := preload("res://tests/support/push.gd")
const T := preload("res://tests/support/t.gd")
const Comfort := preload("res://src/core/comfort.gd")

var _t := T.new("ui_customize_page_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n := 2) -> void:
	for i in n:
		await process_frame


# The ball set down in the lockers' zone, the walk's Customize station (camp_hub.gd); its key is then C.
func _enter_lockers() -> void:
	var hub = _game.camp_hub
	var toward: Vector3 = hub.root.global_position - hub.zone_position("lockers")
	toward.y = 0.0
	var at: Vector3 = hub.zone_position("lockers") + toward.normalized() * 1.5
	at.y = 1.3
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	for i in 4:
		await physics_frame


func _action(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		root.push_input(event)


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_game.ctx.calm = true
	var screens = _game.screens
	var profile = _game.ctx.profile
	profile.unlock_pilot("runner_gunner")
	_game._screen_key(KEY_K)
	await _frames()
	await _enter_lockers()
	var camp = screens.camp_page()
	var entry = camp.get_node_or_null("CustomizeButton")
	var page = camp.get_node_or_null("CustomizePage")
	_t.check("CUS-4 Customize entry exists in camp", entry != null and page != null)
	if entry == null or page == null:
		_game.free()
		quit(_t.verdict())
		return
	_game._screen_key(KEY_C)
	await _frames()
	_t.check("CUS-4 C opens Customize", page.is_visible_in_tree() and screens.camp_open())
	_t.eq("focus starts on pilot", page.focused_id(), "pilot")
	_t.check("camp controls hide under page", not camp._lines.visible and not camp._buttons.visible and not entry.visible)
	Push.key(root, KEY_S)
	_t.eq("S moves down", page.focused_id(), "paint")
	Push.key(root, KEY_W)
	_t.eq("W moves up", page.focused_id(), "pilot")
	Push.key(root, KEY_DOWN)
	_t.eq("arrow down moves", page.focused_id(), "paint")
	Push.key(root, KEY_ENTER)
	_t.eq("Enter cycles owned ball paint", profile.equipped(page.pilot, "paint"), "paint_any_salt")
	profile.unlock_cosmetic("trail_salt_skip")
	profile.unlock_cosmetic("decal_fern")
	profile.unlock_cosmetic("companion_paint_night")
	# Re-pinned 2026-10-16: every pilot has a live shell variant now, so Shell sits between Paint and Trail.
	Push.pad(root, JOY_BUTTON_DPAD_DOWN)
	_t.eq("pad d-pad moves to shell", page.focused_id(), "shell")
	Push.pad(root, JOY_BUTTON_DPAD_DOWN)
	_t.eq("pad d-pad moves to trail", page.focused_id(), "trail")
	Push.pad(root, JOY_BUTTON_A)
	_t.eq("pad A equips trail", profile.equipped(page.pilot, "trail"), "trail_salt_skip")
	_action("ui_down")
	_t.eq("ui_down moves to decal", page.focused_id(), "decal")
	_action("ui_accept")
	_t.eq("ui_accept equips decal", profile.equipped(page.pilot, "decal"), "decal_fern")
	_action("ui_down")
	_action("ui_right")
	_t.eq("ui_right equips SPIL-9 paint", profile.equipped("spil9", "companion_paint"), "companion_paint_night")
	for slot in ["trail", "decal", "companion_paint"]:
		_t.check("page resolves delivered %s" % slot, not page.effective(slot).is_empty())
	var real_assets: Dictionary = page.assets
	page.assets = {}
	for slot in ["trail", "decal", "companion_paint"]:
		_t.eq("page resolves missing %s to default" % slot, page.effective(slot), {})
		page.effective(slot)
	_t.eq("page shares one warning per missing art id", page.resolver._warned.size(), 3)
	page.assets = real_assets
	page.focus("trail")
	Push.key(root, KEY_LEFT)
	_t.eq("left clears trail to none", profile.equipped(page.pilot, "trail"), "")
	Push.key(root, KEY_RIGHT)
	_t.eq("right selects trail", profile.equipped(page.pilot, "trail"), "trail_salt_skip")
	page.focus("pilot")
	var before: String = page.pilot
	Push.key(root, KEY_ENTER)
	_t.check("pilot selector changes pilot", page.pilot != before)
	_t.eq("ball slot choices stay scoped to pilot", page.selected("trail"), "")
	_t.eq("SPIL-9 paint shared across pilots", page.selected("companion_paint"), "companion_paint_night")
	Push.key(root, KEY_ESCAPE)
	await _frames()
	_t.check("CUS-4 Esc returns to camp without closing it", not page.visible and screens.camp_open() and screens.walk_live() and camp._strip.visible)
	_t.check("Back returns the walk, not the title", not screens._actions.visible and not entry.visible)
	_game._screen_key(KEY_C)
	await _frames()
	_t.check("C in the zone opens Customize again", page.is_visible_in_tree())
	# Re-pinned 2026-10-10 (w13 B5, CUSTOMIZE.md section 7): mouse first. A click on a slot row
	# shows its cards; a click on an owned card equips and saves. Every control fits at 1280 by
	# 720 and 1920 by 1080, not only today's row list.
	for i in 120:
		if is_zero_approx(page.position.x):
			break
		await process_frame
	page.focus("trail")
	Push.click(root, page.rows["paint"])
	await _frames()
	_t.eq("mouse click on a slot row shows its cards", page.slot, "paint")
	var paint_before: String = page.selected("paint")
	var target = null
	for card in page.cards:
		if card.state == "owned" and card.id != paint_before:
			target = card
			break
	_t.check("an owned paint card to click", target != null)
	if target != null:
		var target_id: String = target.id
		Push.click(root, target)
		await _frames()
		_t.eq("mouse click on an owned card equips it", page.selected("paint"), target_id)
		_t.check("the equip counts its slot", profile.stat("cos.equip.paint") >= 1.0)
	await _page_checks(page, profile, screens)
	Push.pad(root, JOY_BUTTON_B)
	await _frames()
	_t.check("pad B returns to camp", not page.visible and screens.camp_open())
	_game._screen_key(KEY_C)
	await _frames()
	_action("ui_cancel")
	await _frames()
	_t.check("ui_cancel returns to camp", not page.visible and screens.camp_open())
	_game.free()
	quit(_t.verdict())


func _fits(label: String, control: Control, screen: Vector2) -> void:
	var rect := control.get_global_rect()
	_t.check(label, rect.size.x > 0.0 and rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= screen.x + 0.5 and rect.end.y <= screen.y + 0.5, str(rect))


# CUSTOMIZE.md section 9 ACCEPTANCE, the page bullet.
func _page_checks(page, profile, screens) -> void:
	# Hover tries on without saving; leaving the grid returns to what is worn.
	page._select_slot("decal")
	page._select_slot("paint")
	var worn: String = page.selected("paint")
	var saved_before: float = profile.stat("cos.equip.paint")
	var other = null
	for card in page.cards:
		if card.state in ["owned", "new"] and card.id != worn and card.id != "":
			other = card
			break
	_t.check("an owned card to hover", other != null)
	if other != null:
		page._hover_card(other)
		_t.eq("hover tries the card on", page.look("paint"), other.id)
		_t.eq("hover saves nothing", page.selected("paint"), worn)
		_t.eq("hover counts no equip", profile.stat("cos.equip.paint"), saved_before)
		var tint = page._painter.paint_tint(page.pilot, other.id)
		_t.check("the preview wears the hovered paint", tint != null and page.preview_rec().get("tints", {}).get("paint") == tint)
		page._leave_grid()
		_t.eq("leaving the grid returns to what is worn", page.look("paint"), worn)
	# A locked card names its grant and progress; a hidden grant shows "?" and no progress.
	var locked = null
	var hidden = null
	for card in page.cards:
		if card.state == "locked" and locked == null:
			locked = card
		if card.state == "hidden" and hidden == null:
			hidden = card
	_t.check("a locked paint card shows", locked != null)
	if locked != null:
		var grant := Achievements.for_cosmetic(locked.id)
		var line: String = page.hover_text(locked)
		_t.check("a locked card names its grant", grant != "" and line.contains(String(Achievements.row(grant)["name"])), line)
		_t.check("a locked card shows its progress", line.contains(" / %d" % int(Achievements.row(grant).get("count", 1))), line)
		var equipped_before: String = page.selected("paint")
		_t.check("clicking a locked card equips nothing", not page.click_card(locked) and page.selected("paint") == equipped_before)
	_t.check("the hidden grant's card shows", hidden != null and hidden.id == "paint_any_ink")
	if hidden != null:
		_t.eq("a hidden grant shows only its hint", page.hover_text(hidden), "Hidden. Keep playing.")
	# Pending art is never shown; a slot with nothing that fits is hidden with its group heading.
	page._select_slot("paint")
	for id in Cosmetics.PENDING_ART:
		_t.check("pending %s has no card" % id, page.card_for(id) == null and not id in page.shown_ids(Cosmetics.row(id)["slot"]))
	# With PENDING_ART empty, the test seam plants a shown outfit so the hiding path still runs.
	var outfits: Array = page.shown_ids("outfit")
	_t.check("an outfit is shown before the plant", not outfits.is_empty(), str(outfits))
	if not outfits.is_empty():
		var planted: String = outfits[0]
		Cosmetics._test_pending = [planted]
		page._select_slot("outfit")
		_t.check("planted pending %s has no card" % planted, page.card_for(planted) == null and not planted in page.shown_ids("outfit"))
		Cosmetics._test_pending = []
		page._select_slot("paint")
		page._select_slot("outfit")
		_t.check("cleared %s shows its card again" % planted, page.card_for(planted) != null and planted in page.shown_ids("outfit"))
	page._select_slot("paint")
	_t.check("the shell slot shows its built variant", page.rows["shell"].visible and "shell" in page.order())
	_t.check("empty slot bay_decor is hidden", not page.rows["bay_decor"].visible and not "bay_decor" in page.order())
	_t.check("an empty owner group is hidden", not page._group_labels["BAY"].visible)
	# The delivered outfit and companion skin art is no longer pending: both slots and their groups show.
	var delivered := {"outfit": ["outfit_rivet_hood", "outfit_tally_eyeshade", "outfit_tarn_steady_cap"], "companion_skin": ["companion_skin_till_bell"]}
	for slot in delivered:
		var shown: Array = page.shown_ids(slot)
		_t.check("slot %s shows delivered ids" % slot, not shown.is_empty() and shown.all(func(id): return id in delivered[slot]), str(shown))
		_t.check("slot %s row is visible and ordered" % slot, page.rows[slot].visible and slot in page.order())
		page._select_slot(slot)
		_t.check("slot %s has a card for each shown id" % slot, shown.all(func(id): return page.card_for(id) != null))
	_t.check("the PILOT and SPIL-9 groups show", page._group_labels["PILOT"].visible and page._group_labels["SPIL-9"].visible)
	page._select_slot("paint")
	# New marks clear after 0.6 s on screen and seen saves once, on close.
	var fresh := "paint_any_night"
	profile.unlock_cosmetic(fresh)
	profile._doc["seen"].erase(fresh)
	page.refresh()
	await _frames()
	_t.eq("a new item's card is marked new", page.card_for(fresh).state if page.card_for(fresh) != null else "", "new")
	_t.check("its slot row holds a new mark", page.slot_has_new("paint"))
	page._scroll.ensure_control_visible(page.card_for(fresh))
	await _frames()
	page._age_new_marks(0.3)
	_t.check("the mark stays under 0.6 s", not profile.is_seen(fresh))
	page._age_new_marks(0.4)
	_t.check("the mark clears after 0.6 s on screen", profile.is_seen(fresh) and page.card_for(fresh).state == "owned" and not page.slot_has_new("paint"))
	# Layout at both target sizes: every visible control inside the screen.
	for screen in [Vector2(1280, 720), Vector2(1920, 1080)]:
		page.layout(screen)
		await _frames(3)
		var tag := "%dx%d" % [int(screen.x), int(screen.y)]
		_t.eq("%s card columns" % tag, page._grid.columns, 3 if screen.x < 1600.0 else 4)
		for id in page.order():
			_fits("%s row %s fits" % [tag, id], page.rows[id], screen)
		for id in page._portraits:
			_fits("%s portrait %s fits" % [tag, id], page._portraits[id], screen)
		for i in page._pips.size():
			_fits("%s heft pip %d fits" % [tag, i + 1], page._pips[i], screen)
		_fits("%s preview fits" % tag, page._container, screen)
		_fits("%s card grid fits" % tag, page._scroll, screen)
		_fits("%s hover line fits" % tag, page._hover, screen)
		_t.check("%s preview takes 55%% of the width" % tag, absf(page._container.position.x + page._container.size.x + Customize.MARGIN * 0.5 - screen.x * Customize.PREVIEW_SHARE) < 1.0, str(page._container.size))
	page.layout(screens._screen())
	await _frames(2)
	# The heft pips preview a class and pin it.
	page.pin_heft(4)
	var rec: Dictionary = page.preview_rec()
	_t.check("the preview is built by fit_shell_into", not rec.is_empty() and rec.has("layers") and rec.layers.size() == 4)
	if not rec.is_empty():
		_t.eq("a pinned pip sets the preview's heft class", int(rec.heft), 4)
	page.pin_heft(1)
	# Reduced motion drops the spin, the shake and the hop.
	Comfort.reduced_motion = true
	var turn: float = page._pivot.rotation.y
	page._spin_wait = 0.0
	page._process(0.5)
	_t.eq("reduced motion: no turntable spin", page._pivot.rotation.y, turn)
	if locked != null:
		page._select_slot("decal")
		page._select_slot("paint")
		var lock_card = page.card_for(locked.id)
		var tweens := get_processed_tweens().size()
		page.click_card(lock_card)
		_t.eq("reduced motion: a locked click does not shake", get_processed_tweens().size(), tweens)
		Comfort.reduced_motion = false
		lock_card = page.card_for(locked.id)
		tweens = get_processed_tweens().size()
		page.click_card(lock_card)
		_t.check("full motion: a locked click shakes", get_processed_tweens().size() > tweens)
	Comfort.reduced_motion = false
	page._process(0.5)
	_t.check("full motion: the turntable spins", not is_equal_approx(page._pivot.rotation.y, turn))
	if page._pilots.size() >= 2:
		var a: String = page._pilots[0]
		var b: String = page._pilots[1]
		Comfort.reduced_motion = true
		page.pick_pilot(a)
		page.pick_pilot(b)
		var seat_y: float = page.preview_rec().pilot.position.y if page.preview_rec().get("pilot") != null else 0.0
		Comfort.reduced_motion = false
		page.pick_pilot(a)
		page.pick_pilot(b)
		var hop_y: float = page.preview_rec().pilot.position.y if page.preview_rec().get("pilot") != null else 0.0
		_t.check("reduced motion drops the hop that full motion plays", page.preview_rec().get("pilot") != null and hop_y - seat_y > 0.4, "%f vs %f" % [hop_y, seat_y])
		page.pick_pilot(a)
	# The preview never adds a light per item, and nothing fitted carries a light or override.
	var lights: Array = page._viewport.find_children("*", "Light3D", true, false)
	_t.eq("the preview keeps its one light", lights.size(), 1)
	var overrides := 0
	rec = page.preview_rec()
	for key in ["core", "pod"]:
		if rec.get(key) == null:
			continue
		for node in rec[key].find_children("*", "GeometryInstance3D", true, false):
			if node.material_override != null:
				overrides += 1
	_t.eq("no material_override under the preview shell", overrides, 0)
	# Close saves the seen marks once; a second open and close with nothing new saves nothing.
	var saves: int = page.seen_saves
	page.close()
	_t.eq("seen saves once on close", page.seen_saves, saves + 1)
	page.open(profile)
	await _frames()
	page.close()
	_t.eq("a close with no new marks saves nothing", page.seen_saves, saves + 1)
	page.open(profile)
	await _frames()
