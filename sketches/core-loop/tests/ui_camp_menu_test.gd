extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Secrets := preload("res://src/core/secrets.gd")
const Companion := preload("res://src/core/companion.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const CampMenu := preload("res://src/ui/camp_menu.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const WordBudget := preload("res://src/core/word_budget.gd")
const Push := preload("res://tests/support/push.gd")
const T := preload("res://tests/support/t.gd")
const RunStore := preload("res://src/core/run_store.gd")

# The camp page (C7), now the key-hint strip over the walkable camp (camp_hub.gd; camp_hub_test.gd walks it), on K
# and the summary's Camp action, on the real title:
#   - built synchronously; K, Escape and pad B leave the walk; A, S and Space act only in their station's zone,
#     where A and S open their page, whose Back returns to the walk, and Space leaves for class select;
#   - it reads ready and locked pilots, companion pieces found and seated, and achievements;
#   - its Companion button shows only with a piece and opens the companion panel;
#   - the summary's Camp (K, pad Y) lands on the title with the camp open;
#   - every camp label is 15 words or fewer;
#   - the title row never drops a button: the worst case (Continue, New run, Help, Achievements,
#     Settings, Companion, Camp) wraps onto two centred rows, every button inside
#     1280 - 2*SIDE, none overlapping, in their order; Camp still opens the camp by focus and K.

const LABEL_WORDS := 15
const EARNED_AT := 1790000000.0
const STORE_DIR := "user://ui_camp_menu_test/"

var _t := T.new("ui_camp_menu_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= _game.get_process_delta_time()


# The ball set down in a camp station's zone (2 m toward the plaza from its centre), as camp_hub_test.gd does.
func _put_in(id: String) -> void:
	var hub = _game.camp_hub
	var toward: Vector3 = hub.root.global_position - hub.zone_position(id)
	toward.y = 0.0
	var at: Vector3 = hub.zone_position(id) + toward.normalized() * 1.5
	at.y = 1.3
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	for i in 4:
		await physics_frame


func _reopen(screens) -> void:
	if screens.camp_open():
		_game._screen_key(KEY_K)
	_game._screen_key(KEY_K)


func _line_with(lines: PackedStringArray, prefix: String) -> String:
	for line in lines:
		if line.begins_with(prefix):
			return line
	return ""


func _row_dump(screens) -> String:
	var out := []
	for c in screens._actions.get_children():
		var r: Rect2 = c.get_global_rect()
		out.append("%s@%.0f,%.0f+%.0f" % [c.action, r.position.x, r.position.y, r.size.x])
	return str(out)


# Every title button inside the centred room, no two overlapping, read left to right and row
# by row in the order they were added. Returns "" or the first fault.
func _row_fault(screens, room: float) -> String:
	var mid: float = screens._screen().x / 2.0
	var buttons: Array = screens._actions.get_children()
	for i in buttons.size():
		var r: Rect2 = buttons[i].get_global_rect()
		if r.position.x < mid - room / 2.0 - 0.5 or r.end.x > mid + room / 2.0 + 0.5:
			return "%s outside the room" % buttons[i].action
		for j in range(i + 1, buttons.size()):
			var q: Rect2 = buttons[j].get_global_rect()
			if r.intersects(q):
				return "%s overlaps %s" % [buttons[i].action, buttons[j].action]
			# Rows by centre line: the primary button stands taller than its neighbours (ui_tokens).
			if q.get_center().y < r.get_center().y - 0.5 or (absf(q.get_center().y - r.get_center().y) <= 0.5 and q.position.x < r.position.x):
				return "%s reads before %s" % [buttons[j].action, buttons[i].action]
	return ""


func _rows(screens) -> int:
	var ys := {}
	for c in screens._actions.get_children():
		ys[roundi(c.get_global_rect().get_center().y)] = true
	return ys.size()


func _run() -> void:
	while _game.flow == null:
		await process_frame
	# Checked in the call that built the screens, before another frame: no deferred add_child.
	var page = _game.screens.camp_page() if _game.screens != null else null
	_t.check("the camp page is built synchronously", page != null and page.is_inside_tree(), "")
	await _frames(5)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	var screens = _game.screens
	var flow = _game.flow
	var profile = _game.ctx.profile
	var camp = screens.camp_page()
	var ws = _game.get_node("Workshop")
	await _settle(0.6)
	_t.eq("the game starts on the title", flow.state_name(), "title")
	var camp_button = screens.button_for("camp")
	_t.check("the title has a Camp button on K", camp_button != null and camp_button.key == "key_k", "")
	var room: float = 1280.0 - 2.0 * screens.SIDE
	var fault := _row_fault(screens, room)
	_t.check("the fresh title buttons with Camp sit inside the room, apart", fault == "", "%s %s" % [fault, _row_dump(screens)])
	var first = screens._actions.get_child(0)
	_t.check("Continue or Start stays first on the title", first.action == "continue" or first.action == "start", first.action)

	# K opens and closes.
	_game._screen_key(KEY_K)
	await _frames(1)
	_t.check("K opens the camp", screens.camp_open() and screens.overlay_open(), "")
	_t.eq("the camp's title reads CAMP", screens._title.text, "CAMP")
	_t.check("the title actions hide under the camp", not screens._actions.visible, "")
	_t.check("the walk holds no focus and shows the key strip", root.gui_get_focus_owner() == null and camp.walk
		and not camp.button_for("launch").is_visible_in_tree(), str(root.gui_get_focus_owner()))
	await _frames(2)
	var strip: Control = camp.get_node("WalkStrip")
	var keys: Control = strip.find_child("WalkKeys", true, false)
	_t.check("the key strip is a keycap row, on screen with room under it", strip.is_visible_in_tree() and keys != null
			and camp.walk_words() == "W A S D roll · Space jump · mouse to look · K leave camp"
			and keys.get_global_rect().end.y <= root.get_visible_rect().size.y - 8.0, "%s, ends %.0f of %.0f" % [camp.walk_words(),
				keys.get_global_rect().end.y if keys != null else -1.0, root.get_visible_rect().size.y])
	_game._screen_key(KEY_K)
	await _frames(1)
	_t.check("K again closes the camp", not screens.camp_open() and screens._actions.visible, "")
	_t.eq("the title body comes back", screens._body.text, FieldNotes.OBJECTIVE)
	_t.check("nothing keeps focus after closing", root.gui_get_focus_owner() == null, str(root.gui_get_focus_owner()))

	# Escape and pad Start close (pad B is the boost); pad A presses the focused button.
	_game._screen_key(KEY_K)
	Push.key(root, KEY_ESCAPE)
	await _frames(1)
	_t.check("Escape closes the camp", not screens.camp_open(), "")
	_game._screen_key(KEY_K)
	Push.pad(root, JOY_BUTTON_B)
	await _frames(1)
	_t.check("pad B boosts in the walk and does not close the camp", screens.camp_open(), "")
	Push.pad(root, JOY_BUTTON_START)
	await _frames(1)
	_t.check("pad Start closes the camp", not screens.camp_open(), "")
	_game._screen_key(KEY_K)
	var pad_a := InputEventJoypadButton.new()
	pad_a.button_index = JOY_BUTTON_A
	pad_a.pressed = true
	_t.eq("pad A in the walk outside a zone is the jump, not a title key", _game.pad_screen_key(pad_a), KEY_NONE)
	await _put_in("gate")
	_t.eq("pad A in the gate's zone is Launch", _game.pad_screen_key(pad_a), KEY_SPACE)
	_game._screen_key(_game.pad_screen_key(pad_a))
	await _frames(2)
	_t.check("pad A at the gate launches into stage 1", flow.in_stage() and _game.run.stage == 1, flow.state_name())
	flow.show_title()
	await _frames(1)

	# Pilots.
	var starters := 0
	var locked_def = null
	for def in flow.classes:
		if def.starter:
			starters += 1
		elif locked_def == null:
			locked_def = def
	var read: Dictionary = CampMenu.reading(_game)
	print("camp lines, fresh profile: %s" % " | ".join(read["lines"]))
	var ready := 0
	for p in read["pilots"]:
		if p["ready"]:
			ready += 1
	_t.eq("a fresh profile has the starters ready", ready, starters)
	_t.eq("the headline counts them", read["lines"][0], "%d / %d pilots ready" % [starters, flow.classes.size()])
	_t.check("a non-starter pilot exists", locked_def != null, "")
	var hint := ClassCard.unlock_hint(locked_def, _game.progress)
	var locked_line := _line_with(read["lines"], "%s is " % locked_def.display_name)
	_t.check("a locked pilot's line names how it unlocks", locked_line.contains(hint if hint != "" else "locked"), locked_line)
	profile.unlock_pilot(locked_def.id)
	_reopen(screens)
	read = CampMenu.reading(_game)
	var after := 0
	var now_ready := false
	for p in read["pilots"]:
		if p["ready"]:
			after += 1
		if p["id"] == locked_def.id:
			now_ready = p["ready"]
	_t.check("an unlocked pilot reads ready and the count rises", now_ready and after == starters + 1
		and camp.labels().has("%s is ready" % locked_def.display_name), "ready %s, %d of %d" % [now_ready, after, starters + 1])
	var still_locked = null
	for def in flow.classes:
		if not _game.pilot_unlocked(def):
			still_locked = def
			break
	if still_locked != null:
		var h := ClassCard.unlock_hint(still_locked, _game.progress)
		var line := _line_with(read["lines"], "%s is " % still_locked.display_name)
		_t.check("a still-locked pilot names its unlock", line.contains(h if h != "" else "locked"), line)

	# Companion.
	_t.check("a fresh profile reads no pieces", camp.labels().has(CampMenu.NO_PIECES), "")
	_t.check("no Companion button without pieces", camp.button_for("companion") == null, "")
	profile.set_companion(Companion.with_piece({}, "escape_vent"))
	_reopen(screens)
	_t.check("one piece reads 1 of the table", camp.labels().has("1 / %d companion pieces" % Companion.PIECES.size()), "\n".join(camp.labels()))
	_t.check("nothing seated reads none", camp.labels().has("Nothing seated"), "")
	var companion = camp.button_for("companion")
	_t.check("the Companion button shows with a piece", companion != null, "")
	_game._screen_key(KEY_M)
	_t.check("M outside Moss's zone opens nothing", not ws.companion_panel.is_open(), "")
	await _put_in("moss")
	_game._screen_key(KEY_M)
	await _frames(1)
	_t.check("M at Moss's stall opens the panel over the walk", screens.camp_open() and ws.companion_panel.is_open()
		and not screens.walk_live(), "camp %s" % screens.camp_open())
	ws.companion_panel.close()
	await _frames(1)
	_t.check("closing the panel returns to the walk", screens.walk_live(), "")

	# Achievements count.
	profile.earn(Achievements.ids()[0], EARNED_AT)
	_reopen(screens)
	_t.check("an earn shows in the count", camp.labels().has("1 / %d achievements earned" % Achievements.ids().filter(func(id): return not Secrets.shut_row(id, profile)).size()), "")

	# Pages from the camp: each opens from its station's zone and its Back returns to the walk.
	_game._screen_key(KEY_A)
	_t.check("A outside the trophy wall's zone opens nothing", not screens.achievements_open(), "")
	await _put_in("achieve")
	_game._screen_key(KEY_A)
	await _frames(1)
	_t.check("A at the trophy wall opens achievements", screens.achievements_open() and screens.camp_open(), "")
	_game._screen_key(KEY_A)
	_t.check("A on the open page does not stack or close it", screens.achievements_open(), "")
	screens.toggle_achievements()
	await _frames(1)
	_t.check("its Back returns to the walk", not screens.achievements_open() and screens.walk_live() and not screens._actions.visible, "")
	await _put_in("settings")
	_game._screen_key(KEY_S)
	await _frames(1)
	_t.check("S at the console opens settings", screens.settings_open() and screens.camp_open(), "")
	screens.toggle_settings()
	await _frames(1)
	_t.check("settings' back returns to the walk", not screens.settings_open() and screens.walk_live() and not screens._actions.visible, "")
	await _put_in("gate")
	_game._screen_key(KEY_SPACE)
	await _frames(1)
	_t.check("Space at the gate launches into stage 1", flow.in_stage() and _game.run.stage == 1, flow.state_name())
	flow.show_title()
	await _frames(1)

	# Labels.
	_game._screen_key(KEY_K)
	var longest := 0
	for line in camp.labels():
		longest = maxi(longest, WordBudget.words_in(line))
	_t.check("every camp label is %d words or fewer" % LABEL_WORDS, longest <= LABEL_WORDS, "%d words" % longest)
	_game._screen_key(KEY_K)

	# Summary.
	flow._set_state(flow.SUMMARY)
	await _frames(1)
	var summary_camp = screens.button_for("camp")
	_t.check("the summary has a Camp action on K", summary_camp != null and summary_camp.key == "key_k", "")
	_game.summary_latched = true
	_game._screen_key(KEY_K)
	_t.eq("K under the summary guard stays on the summary", flow.state_name(), "summary")
	_game.summary_latched = false
	var pad_y := InputEventJoypadButton.new()
	pad_y.button_index = JOY_BUTTON_Y
	pad_y.pressed = true
	_t.eq("pad Y on the summary is K", _game.pad_screen_key(pad_y), KEY_K)
	_game._screen_key(KEY_K)
	await _frames(1)
	_t.check("K on the summary lands on the title with the camp open", flow.state_name() == "title" and screens.camp_open(), flow.state_name())
	_t.check("no Continue after a finished run", screens.button_for("continue") == null, "")
	_game._screen_key(KEY_K)

	# Crowded title rows wrap; no button leaves.
	profile.set_companion(Companion.with_piece({}, "escape_vent"))
	flow.show_title()
	await _frames(2)
	fault = _row_fault(screens, room)
	_t.check("a title with Companion and Camp keeps every button inside the room, apart",
		screens.button_for("companion") != null and screens.button_for("camp") != null
		and screens.button_for("breath") == null and fault == "", "%s %s" % [fault, _row_dump(screens)])
	DirAccess.make_dir_recursive_absolute(STORE_DIR)
	flow.store = RunStore.new(STORE_DIR + "run.json")
	flow.store.clear()
	flow.press_start()
	flow.choose_class(0)
	await _frames(2)
	flow.show_title()
	await _frames(2)
	var present := []
	for action in ["continue", "start", "help", "achievements", "settings", "companion", "camp"]:
		if screens.button_for(action) != null:
			present.append(action)
	_t.eq("the worst-case title keeps all seven buttons", present.size(), 7)
	fault = _row_fault(screens, room)
	_t.check("the worst-case buttons sit inside the room, apart, in order", fault == "", "%s %s" % [fault, _row_dump(screens)])
	_t.eq("the worst-case row wraps onto two rows", _rows(screens), 2)
	print("worst-case title row: %s" % _row_dump(screens))
	var crowded_camp = screens.button_for("camp")
	_t.check("the worst-case Camp is on K", crowded_camp != null and crowded_camp.key == "key_k", "")
	_game._screen_key(KEY_K)
	_t.check("K opens the camp from the worst-case title", screens.camp_open(), "")
	_game._screen_key(KEY_K)
	await _frames(1)
	crowded_camp = screens.button_for("camp")
	crowded_camp.grab_focus()
	Push.pad(root, JOY_BUTTON_A)
	await _frames(2)
	_t.check("pad A on the focused worst-case Camp opens the camp", screens.camp_open(), str(root.gui_get_focus_owner()))
	_game._screen_key(KEY_K)
	flow.store.clear()
	quit(_t.verdict())
