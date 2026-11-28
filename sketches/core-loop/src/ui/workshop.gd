extends CanvasLayer

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const TreePick := preload("res://src/ui/tree_pick.gd")
const PickQuiet := preload("res://src/ui/pick_quiet.gd")
const ShopCounter := preload("res://src/ui/shop_counter.gd")
const MossBubble := preload("res://src/ui/moss_bubble.gd")
const VoiceSynth := preload("res://src/presentation/voice_synth.gd")
const CompanionPanel := preload("res://src/ui/companion_panel.gd")


const LAYER := 4
const PULL_UP := 4.0
const BUBBLE_Y := 0.30
const COUNTER_X := 0.36
const COUNTER_Y := 0.33
const TALK_KEY := KEY_T
const BRIEF_LINE := "Spillway Works. Running perfectly. Go and fix that."
const BRIEF_WORDS := "Moss packed three. Take one."
const BRIEF_ROWS := [[BRIEF_LINE, 22, 118.0], [BRIEF_WORDS, 30, 66.0]]
const BRIEF_ROW_H := 44.0
const OUTSIDE_RUN := ["title", "class_select"]
const COUNTER_HOLD := ["input", "mouse"]
const PICK_HOLD := ["pause", "input", "mouse"]
const CARD_HOLD := ["mouse"]

var game
var armed := true
var _start_pointer_held := false
var pick
var brief: ColorRect
var counter
var bubble
var _bubble_hid := false
var companion_panel
var talk: Button
var _counter_ready := true
var _ball_parked := false
var _offer_pending := false
var _held := false
var _brief_hush: Array = []
var _paused := false


class TalkButton extends Button:
	const H := 30.0

	var _bubble: StyleBox = ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, 7)

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		accessibility_name = "Talk"
		custom_minimum_size = Vector2(maxf(Keycap.size_of("key_t", H).x + 34.0, UiTokens.TARGET), maxf(H + 8.0, UiTokens.TARGET))
		size = custom_minimum_size
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())

	func drawn_words() -> PackedStringArray:
		return Keycap.words("key_t")

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var tint := UiTokens.TEXT if is_hovered() else Palette.SAND
		var cap := Keycap.size_of("key_t", H)
		Keycap.draw(self, Vector2(cap.x * 0.5, size.y * 0.5), "key_t", tint, H)
		var at := Vector2(cap.x + 8.0, size.y * 0.5 - 9.0)
		var bubble_rect := Rect2(at, Vector2(24.0, 16.0))
		_bubble.border_color = tint
		draw_style_box(_bubble, bubble_rect)
		draw_colored_polygon(PackedVector2Array([at + Vector2(4.0, 15.0), at + Vector2(-2.0, 22.0), at + Vector2(11.0, 15.0)]), tint)


func _init() -> void:
	name = "Workshop"


func _ready() -> void:
	if game == null:
		setup(get_parent())


func setup(game_ref) -> void:
	game = game_ref
	armed = not game.test_mode
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	bubble = MossBubble.new()
	add_child(bubble)
	talk = TalkButton.new()
	talk.visible = false
	talk.pressed.connect(say_next)
	add_child(talk)
	counter = ShopCounter.new()
	add_child(counter)
	counter.setup(game)
	counter.acted.connect(_on_acted)
	counter.pick_wanted.connect(open_pick)
	counter.leave_wanted.connect(close_counter)
	if game.ctx.get("screen_busy") != null:
		game.ctx.screen_busy.add_source(func() -> bool: return pick.is_open() or briefing())
	brief = ColorRect.new()
	brief.color = Color(Palette.CHARCOAL, 0.72)
	brief.set_anchors_preset(Control.PRESET_FULL_RECT)
	brief.mouse_filter = Control.MOUSE_FILTER_STOP
	brief.visible = false
	add_child(brief)
	for row in BRIEF_ROWS:
		brief.add_child(UiDraw.label(row[1], Palette.AMBER if row[0] == BRIEF_LINE else Palette.SAND, row[0]))
	pick = TreePick.new()
	add_child(pick)
	pick.chosen.connect(choose)
	pick.later.connect(close_pick)
	companion_panel = CompanionPanel.new()
	add_child(companion_panel)
	companion_panel.setup(game)
	companion_panel.closed.connect(func():
		if not game.flow.in_play():
			game.flow._persist_companion()
		if counter.is_open():
			_apply_hold())
	game.events.tree_offered.connect(func(_c: String, _d: int, _choices: Array): _offer_later())
	game.events.tree_picked.connect(func(_c: String, _n: String, _d: int): _offer_later())
	game.events.bay_entered.connect(func(_banked: float): _speak_world_bark("shop_entered"))
	game.events.bay_left.connect(func(_v: Vector3): _on_bay_left())
	game.events.stage_entered.connect(func(_i: int, retry: bool):
		if retry:
			close_all()
		else:
			close_counter())
	game.events.flow_changed.connect(func(_s: String):
		if not game.flow.in_play():
			close_all()
		else:
			companion_panel.close()
		sync_start_card_pointer())


func _start_card_showing() -> bool:
	var card = game.flow.get("start_card") if game.flow != null else null
	return card != null and card.showing()


func _start_card_wants_pointer() -> bool:
	var card = game.flow.get("start_card") if game.flow != null else null
	return card != null and card.wants_pointer()


func sync_start_card_pointer() -> void:
	if _start_card_wants_pointer():
		_start_pointer_held = true
		game.hold_play("start_card", true, CARD_HOLD)
	elif _start_pointer_held:
		_start_pointer_held = false
		game.hold_play("start_card", false)


func shop():
	var b = game.build
	return b.shop if b != null and "shop" in b else null


func tree():
	return game.player.get("tree") if game.player != null else null


func screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1600.0, 900.0)


func _offer_later() -> void:
	if _offer_pending:
		return
	_offer_pending = true
	_sync_pick.call_deferred()


func _sync_pick() -> void:
	_offer_pending = false
	var t = tree()
	if not armed or t == null or not game.flow.in_play():
		return
	if not t.pending():
		if pick.is_open():
			close_pick()
		else:
			_resync_start_card()
		return
	if pick.is_open() and pick.depth == t.path().size() + 1:
		return
	open_pick()
	if not pick.is_open():
		_resync_start_card()


func _resync_start_card() -> void:
	if game.flow != null and game.flow.in_play():
		game.flow.show_start_card()


func open_pick() -> void:
	var t = tree()
	if t == null or not t.pending():
		return
	var depth: int = t.path().size() + 1
	var nodes: Array = t.offered(t.class_id, depth)
	if nodes.size() != 2:
		return
	var color: Color = game.run.class_def.color if game.run.class_def != null else Palette.SAND
	pick.open(t.class_id, depth, nodes, t.path(), color)
	counter.visible = false
	_resync_start_card()
	_apply_hold()


func close_pick(chosen_index := -1) -> void:
	pick.close(chosen_index)
	if game.flow != null and game.flow.in_play():
		game.flow.show_start_card()
	_apply_hold()
	if counter.is_open():
		counter.visible = true
		counter.refresh()
		counter.focus_first()


func choose(index: int) -> void:
	var t = tree()
	if t == null or not pick.is_open():
		return
	var nodes: Array = t.offered(t.class_id, pick.depth)
	if index < 0 or index >= nodes.size():
		return
	if not t.pick(String(nodes[index]["id"])):
		return
	if t.pending():
		open_pick()
	else:
		close_pick(index)


func open_counter() -> void:
	var s = shop()
	if s == null or not s.inside or counter.is_open():
		return
	_counter_ready = false
	var size := screen_size()
	counter.position.y = size.y * COUNTER_Y
	counter.open(s, size.x * COUNTER_X)
	if game.flow.in_play() and not game.player.frozen():
		game.player.set_frozen(true)
		_ball_parked = true
	bubble.sticky = true
	_update_talk(armed)
	_apply_hold()


func close_counter() -> void:
	if not counter.is_open():
		return
	counter.close()
	bubble.sticky = false
	_release_ball()
	_apply_hold()


func close_all() -> void:
	if pick.is_open():
		pick.close()
	if counter.is_open():
		counter.close()
	bubble.sticky = false
	_release_ball()
	_apply_hold()


func _release_ball() -> void:
	if _ball_parked:
		_ball_parked = false
		if game.flow.in_play():
			game.player.set_frozen(false)


func should_open_counter(inside: bool, near: bool, speed: float) -> bool:
	return inside and near and speed < PULL_UP and _counter_ready


func _near_moss() -> bool:
	var terrain = game.ctx.terrain if game.ctx != null else null
	return terrain != null and terrain.has_method("near_moss") and terrain.near_moss(game.player.ball_position())


func held() -> bool:
	return _held


func card_holds_only() -> bool:
	return _start_pointer_held and not _held and not get_tree().paused


func _apply_hold() -> void:
	var briefed := briefing()
	_hold_quiet(armed and _start_card_showing())
	var held_now: bool = pick.is_open() or counter.is_open() or briefed
	var pause: bool = pick.is_open() or briefed
	_show_briefing(briefed)
	if held_now == _held and pause == _paused:
		return
	_held = held_now
	_paused = pause
	if not held_now:
		sync_start_card_pointer()
	game.hold_play("workshop", held_now, PICK_HOLD if pause else COUNTER_HOLD)


func _hold_quiet(on: bool) -> void:
	if on and _brief_hush.is_empty():
		_brief_hush = PickQuiet.hush(self)
	elif not on and not _brief_hush.is_empty():
		PickQuiet.restore(_brief_hush)
		_brief_hush = []


func _exit_tree() -> void:
	_hold_quiet(false)


func quiet(on: bool) -> void:
	if on:
		if bubble.visible:
			bubble.visible = false
			_bubble_hid = true
	elif _bubble_hid:
		bubble.visible = true
		_bubble_hid = false


func briefing() -> bool:
	return armed and _start_card_showing() and not pick.is_open()


func kit_pick_due() -> bool:
	if not armed:
		return false
	var t = tree()
	return pick.is_open() or (_offer_pending and t != null and t.pending())


func sync_briefing() -> void:
	_apply_hold()


func _show_briefing(on: bool) -> void:
	brief.visible = on
	if not on:
		return
	var card = game.flow.start_card
	var mid_run: bool = game.flow.start_pick_at_yard()
	for i in BRIEF_ROWS.size():
		var words: Label = brief.get_child(i)
		words.visible = not (mid_run and BRIEF_ROWS[i][0] == BRIEF_LINE)
		words.position = Vector2(0.0, card.position.y - float(BRIEF_ROWS[i][2]))
		words.size = Vector2(screen_size().x, BRIEF_ROW_H)


func open_companion() -> bool:
	var screens = game.screens
	if screens != null and (screens.overlay_open() or screens.settings_open()):
		return false
	if game.summary_shut():
		return false
	if _outside_run() and game.ctx.profile != null:
		game.run.companion = game.flow.profile_companion()
	if game.flow.in_play():
		if not counter.is_open():
			return false
	if game.run.companion.is_empty():
		return false
	return companion_panel.open()


func _outside_run() -> bool:
	return game.flow.state_name() in OUTSIDE_RUN


func say_next() -> Dictionary:
	var s = shop()
	if s == null or not s.inside:
		return {}
	var record: Dictionary = s.talk()
	if record.is_empty():
		return record
	bubble.beat(record)
	_place_bubble()
	_babble("moss_relent" if record.get("relent", false) else "moss_beat", String(record.get("text", "")), babble_beat(record))
	if record.get("relent", false) and counter.is_open():
		counter.refresh()
	return record


func _on_acted(fact: String, record: Dictionary) -> void:
	if record.has("bark"):
		bubble.bark(record["bark"], fact)
		_place_bubble()
		_babble(fact, String(record["bark"].get("text", "")), VoiceSynth.BABBLE_LEVEL)
	_cue(fact)


func _speak_world_bark(fact: String) -> void:
	_counter_ready = true
	var line: Dictionary = game.world.bay_bark if game.world != null and "bay_bark" in game.world else {}
	if armed and not line.is_empty():
		bubble.bark(line, fact)
		_place_bubble()
		_babble(fact, String(line.get("text", "")), VoiceSynth.BABBLE_LEVEL)


func _on_bay_left() -> void:
	companion_panel.close()
	close_counter()
	_speak_world_bark("shop_left")


func _place_bubble() -> void:
	bubble.position = Vector2(0.0, screen_size().y * BUBBLE_Y)


func _cue(fact: String) -> void:
	var audio = _audio()
	if EventKinds.LOOT_ROWS.has(fact) and audio != null:
		audio.play(fact, 0.0, 1.0, "UI")


func _babble(fact: String, text: String, beat: int) -> void:
	var audio = _audio()
	if audio != null and audio.has_method("speak"):
		audio.speak(fact, text, beat)


func _audio():
	var presentation = game.presentation if game != null else null
	var audio = presentation.get("audio") if presentation != null else null
	return audio if audio != null and audio.has_method("play") else null


static func babble_beat(record: Dictionary) -> int:
	if record.get("relent", false):
		return VoiceSynth.BABBLE_RELENT
	if record.get("restart", false):
		return VoiceSynth.BABBLE_LEVEL
	return int(record.get("beat", 0)) + 1


func _process(_delta: float) -> void:
	sync_start_card_pointer()
	_apply_hold()
	var s = shop()
	var inside: bool = armed and s != null and s.inside and game.flow.in_play()
	var near := inside and _near_moss()
	if not near and not counter.is_open():
		_counter_ready = true
	if not pick.is_open() and should_open_counter(inside, near, game.player.state.velocity.length() if game.player != null else 99.0):
		open_counter()
	_update_talk(inside and (near or counter.is_open()))


func _update_talk(shown: bool) -> void:
	talk.visible = shown
	talk.position = Vector2(18.0, screen_size().y * BUBBLE_Y - talk.size.y - 10.0)
	talk.disabled = not counter.is_open()
	talk.mouse_filter = Control.MOUSE_FILTER_STOP if counter.is_open() and not pick.is_open() else Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if briefing():
		if _notes_key(event):
			get_viewport().set_input_as_handled()
		return
	if not armed:
		return
	if companion_panel.is_open():
		if companion_panel.handle(event):
			get_viewport().set_input_as_handled()
		return
	if _companion_wanted(event) and open_companion():
		get_viewport().set_input_as_handled()
		return
	if pick.is_open():
		if _pick_key(event):
			get_viewport().set_input_as_handled()
		return
	if counter.is_open():
		if _counter_key(event):
			get_viewport().set_input_as_handled()
		return
	if talk.visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == TALK_KEY:
		say_next()
		get_viewport().set_input_as_handled()


func _companion_wanted(event: InputEvent) -> bool:
	var state: String = game.flow.state_name()
	var outside := _outside_run()
	if not (state == "dead" or state == "summary" or outside or counter.is_open()):
		return false
	if not outside and game.run.companion.is_empty():
		return false
	if event is InputEventKey:
		return event.pressed and not event.echo and event.physical_keycode == KEY_M
	return event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_LEFT_SHOULDER


func _note_menu_nav() -> void:
	var audio = _audio()
	if audio != null and audio.has_method("note_menu_nav"):
		audio.note_menu_nav()


func _pick_key(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_KP_1:
				pick.chosen.emit(0)
				return true
			KEY_2, KEY_KP_2:
				pick.chosen.emit(1)
				return true
			KEY_A:
				_note_menu_nav()
				pick.step_focus(-1)
				return true
			KEY_D:
				_note_menu_nav()
				pick.step_focus(1)
				return true
			KEY_P:
				return true
	if _notes_key(event):
		return true
	if event.is_action_pressed("ui_cancel"):
		close_pick()
		return true
	if event.is_action_pressed("ui_left"):
		pick.step_focus(-1)
		return true
	if event.is_action_pressed("ui_right"):
		pick.step_focus(1)
		return true
	if event.is_action_pressed("ui_accept"):
		if event is InputEventJoypadButton:
			pick.confirm_pad()
		else:
			pick.confirm()
		return true
	return false


func _notes_key(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.physical_keycode == KEY_TAB
	return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_BACK


func _counter_key(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			TALK_KEY:
				say_next()
				return true
			KEY_W:
				_note_menu_nav()
				counter.step_focus(0, -1)
				return true
			KEY_S:
				_note_menu_nav()
				counter.step_focus(0, 1)
				return true
			KEY_A:
				_note_menu_nav()
				counter.step_focus(-1, 0)
				return true
			KEY_D:
				_note_menu_nav()
				counter.step_focus(1, 0)
				return true
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
		say_next()
		return true
	if event.is_action_pressed("ui_cancel"):
		close_counter()
		return true
	for dir in [["ui_left", -1, 0], ["ui_right", 1, 0], ["ui_up", 0, -1], ["ui_down", 0, 1]]:
		if event.is_action_pressed(dir[0]):
			counter.step_focus(dir[1], dir[2])
			return true
	if event.is_action_pressed("ui_accept"):
		counter.confirm()
		return true
	return false
