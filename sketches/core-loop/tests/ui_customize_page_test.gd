extends SceneTree

const Game := preload("res://src/game.gd")
const Customize := preload("res://src/ui/customize_page.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Push := preload("res://tests/workshop/push.gd")
const T := preload("res://tests/support/t.gd")

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
	var camp = screens.camp_page()
	var entry = camp.get_node_or_null("CustomizeButton")
	var page = camp.get_node_or_null("CustomizePage")
	_t.check("CUS-4 Customize entry exists in camp", entry != null and page != null)
	if entry == null or page == null:
		_game.free()
		quit(_t.verdict())
		return
	Push.key(root, KEY_C)
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
	_t.check("CUS-4 Esc returns to camp without closing it", not page.visible and screens.camp_open() and entry.visible)
	_t.check("Back restores entry focus", root.gui_get_focus_owner() == entry)
	Push.click(root, entry)
	await _frames()
	_t.check("mouse opens Customize", page.is_visible_in_tree())
	page.focus("paint")
	var paint_before: String = page.selected("paint")
	Push.click(root, page.rows["paint"])
	await _frames()
	_t.check("mouse cycles paint", page.selected("paint") != paint_before)
	for id in Customize.ORDER:
		var rect: Rect2 = page.rows[id].get_global_rect()
		var screen: Vector2 = screens._screen()
		_t.check("%s row fits viewport" % id, rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= screen.x and rect.end.y <= screen.y, str(rect))
	Push.pad(root, JOY_BUTTON_B)
	await _frames()
	_t.check("pad B returns to camp", not page.visible and screens.camp_open())
	Push.click(root, entry)
	await _frames()
	_action("ui_cancel")
	await _frames()
	_t.check("ui_cancel returns to camp", not page.visible and screens.camp_open())
	_game.free()
	quit(_t.verdict())
