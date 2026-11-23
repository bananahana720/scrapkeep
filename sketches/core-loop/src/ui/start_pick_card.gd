extends Control

signal pick_requested(index: int)
signal reroll_requested
signal tier_requested(tier: int)

const RunTier := preload("res://src/core/run_tier.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const StartPicks := preload("res://src/core/start_picks.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const Palette := preload("res://src/core/palette.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")

# The card draws the offer and emits choices. Flow owns the input routes and RunState
# owns grants and the win check. The noninteractive default preserves SG9's draw-only use.

const ICON := 40.0
const KEY := 26.0
const FONT := UiTokens.LABEL
# The effect line under a tile's name (StartPicks row "effect"), and how far each line sits
# from the tile's middle.
const EFFECT_FONT := UiTokens.CAPTION
const NAME_RISE := 10.0
const EFFECT_DROP := 15.0
const GAP := 10.0
const TILE_GAP := 18.0
const PAD := 10.0
const PIP := 5.0
const KEYS := ["key_1", "key_2", "key_3"]
const REROLL_KEY := "key_v"
# In the run's briefing (workshop.gd) the card has the paused screen to itself, so its tiles draw
# this much larger than the in-play strip.
const BRIEFING_SCALE := 1.4
const UNLOCK_WORDS := "A win opens harder runs"
# The HARD ladder on the card (a profile with a rung opened): the word, one pip per rung and four
# gauges (RunTier.meters). At rest the gauges are the selected rung's and only its pip carries a
# numeral. The pip the focus or the mouse came to last is the rung looked at: it shows its numeral, the
# gauges read it, and its contract (RunTier.contract_lines) is written under them, so the numbers
# reach a pad, a keyboard and a mouse the same way before the press. Sizes are the card's own,
# unscaled in the briefing.
const TIER_WORD := "Tier"
const RUNG := 34.0
const RUNG_GAP := 10.0
const RUNG_FONT := UiTokens.BODY
const LADDER_ROW := 26.0
const METER_ROW := 80.0
const METER_FONT := UiTokens.BODY
const METER_BAR := Vector2(110.0, 12.0)
const METER_GAP := 24.0
const CONTRACT_ROW := 108.0
const CONTRACT_STEP := 21.0
const CONTRACT_FONT := UiTokens.CAPTION
# The interactive card's height under the tiles: the words and the reroll, or the ladder with room
# for a looked-at rung's contract.
const CONTROLS_H := 120.0
const LADDER_H := 146.0
# The interactive card's least width; the ladder's is wide enough for the top rung's threat line.
const CONTROLS_W := 780.0
const LADDER_W := 840.0
const REROLL_SIZE := Vector2(138.0, 38.0)

var _tiles: Array = []
var _tile_rects: Array[Rect2] = []
var _rerolls := 0
var _color := Palette.SAND
var _interactive := false
# True in the run's briefing (set_briefing): larger tiles, and the reroll centred when no tier is offered.
var _briefing := false
var _profile
var _run
# The opened rungs' pips, by tier.
var _tier_buttons := {}
# The rung looked at: the opened pip the focus or the mouse came to last, -1 with neither on a pip.
var _looked := -1
# Whether a screen over the card owns the input now (flow.gd _start_card_covered); unset, nothing does.
var covered := Callable()
var reroll_button: Button
# The tiles' buttons, in tile order (interactive only).
var _tile_buttons: Array[Button] = []
# One Keeper plate per tile, cut by its place in the row.
var _frames: Array = []
# What the last draw put down: the tiles' frames and each gauge's colour, for a check of the drawn colours.
var _drawn := {"frames": [], "gauges": []}



func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process_input(false)
	set_process_unhandled_input(false)
	# In-run flourishes keep clear of the card while it shows (flourish_player.gd AVOID_GROUP).
	add_to_group("flourish_avoid")


func _ready() -> void:
	set_process_input(_interactive)
	set_process_unhandled_input(false)


func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	set_process_input(enabled)


func set_briefing(on: bool) -> void:
	_briefing = on


# The tile metrics' scale: 1 for the in-play strip, BRIEFING_SCALE in the briefing.
func _k() -> float:
	return BRIEFING_SCALE if _briefing else 1.0


func show_picks(run, profile = null) -> void:
	_run = run
	_profile = profile
	_tiles = []
	var taken := String(run.start_pick.get("taken", ""))
	var pilot: String = run.class_id()
	if taken == "" and int(run.stage) == 1:
		var options: Array = run.start_pick_options()
		for i in mini(options.size(), KEYS.size()):
			var row := StartPicks.row(pilot, String(options[i]))
			if row.is_empty():
				continue
			_tiles.append({"key": KEYS[i], "icon": row["icon"], "name": row["name"], "id": row["id"], "effect": String(row.get("effect", ""))})
	_rerolls = int(run.start_pick.get("rerolls_left", 0))
	if run.class_def != null:
		_color = run.class_def.color
	visible = _tiles.size() == StartPicks.OFFERED
	custom_minimum_size = extent()
	size = extent()
	_layout_tiles()
	_frames = range(_tiles.size()).map(func(i): return ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, i + 1))
	_controls()
	queue_redraw()


func hide_card() -> void:
	visible = false


func showing() -> bool:
	return visible


# Whether the card needs the cursor: only while it offers a choice the mouse alone can make, the
# run tier before stage 1's Warden closes it on a profile with a rung unlocked. Picks and the
# reroll have keys, so a fresh profile's card, or one holding its tier, leaves the mouse to aim
# (w22 first-timer red team: a freed cursor had left mouse look dead until a pick).
func wants_pointer() -> bool:
	return _interactive and visible and _run != null and _run.run_tier_open() and offered_tiers().size() > 1


func tiles() -> Array:
	return _tiles.duplicate(true)


func tile_rects() -> Array[Rect2]:
	return _tile_rects.duplicate()


func _layout_tiles() -> void:
	var widths := []
	var total := TILE_GAP * _k() * maxf(0.0, _tiles.size() - 1)
	for tile in _tiles:
		var width := _tile_width(tile)
		widths.append(width)
		total += width
	_tile_rects.clear()
	var x := (size.x - total) * 0.5
	for width in widths:
		_tile_rects.append(Rect2(x, 0.0, width, (ICON + PAD * 2.0) * _k()))
		x += width + TILE_GAP * _k()


func rerolls_left() -> int:
	return _rerolls


func _tile_width(tile: Dictionary) -> float:
	var k := _k()
	var words := maxf(UiDraw.width(String(tile["name"]), int(FONT * k)), UiDraw.width(String(tile.get("effect", "")), int(EFFECT_FONT * k)))
	return (PAD + KEY + GAP + ICON + GAP + PAD) * k + words


func extent() -> Vector2:
	var w := 0.0
	for tile in _tiles:
		w += _tile_width(tile)
	w += TILE_GAP * _k() * maxf(0.0, _tiles.size() - 1)
	if not _interactive:
		return Vector2(w, _controls_top())
	if ladder_shown():
		return Vector2(maxf(w, LADDER_W), _controls_top() + LADDER_H)
	return Vector2(maxf(w, CONTROLS_W), _controls_top() + CONTROLS_H)


# Where the words and buttons under the tiles and their pips begin.
func _controls_top() -> float:
	return (ICON + PAD * 2.0 + PIP * 3.0) * _k()


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	if visible:
		for tile in _tiles:
			out.append(String(tile["name"]))
			if String(tile.get("effect", "")) != "":
				out.append(String(tile["effect"]))
		if _interactive and not ladder_open():
			out.append(UNLOCK_WORDS)
		elif _interactive and not _run.run_tier_open():
			out.append(_held_words())
		elif _interactive:
			out.append(TIER_WORD)
			out.append_array(_numerals())
			for meter in RunTier.meters(_shown_tier()):
				out.append(String(meter["name"]))
			if _looked_tier() >= 0:
				out.append_array(RunTier.contract_lines(_looked_tier()))
	return out


func _looked_tier() -> int:
	return _looked if _tier_buttons.has(_looked) else -1


# The focus or the mouse came to a pip: whichever came last is the look, so a mouse over one rung
# reads that rung while the focus still sits on the rung picked before, and the stick takes it back.
func _look(tier: int) -> void:
	_looked = tier
	queue_redraw()


# The focus or the mouse left a pip. The look stays while the other of the two is still on it, and
# otherwise falls back to the pip under the focus.
func _look_away(tier: int, by_mouse: bool) -> void:
	var pip: Button = _tier_buttons.get(tier)
	if _looked == tier and pip != null and is_instance_valid(pip) and not (pip.has_focus() if by_mouse else pip.is_hovered()):
		_looked = _focused_tier()
	queue_redraw()


# The pip under the focus, by tier; -1 with the focus elsewhere.
func _focused_tier() -> int:
	for tier in _tier_buttons:
		if is_instance_valid(_tier_buttons[tier]) and _tier_buttons[tier].has_focus():
			return tier
	return -1


# The rung the gauges read: the one looked at, else the one selected.
func _shown_tier() -> int:
	var looked := _looked_tier()
	return looked if looked >= 0 else _run.selected_run_tier()


# The numerals drawn on the pips, in rung order: the selected rung's and the looked-at rung's.
func _numerals() -> PackedStringArray:
	var tiers := [_run.selected_run_tier()]
	if _looked_tier() >= 0 and not _looked_tier() in tiers:
		tiers.append(_looked_tier())
	tiers.sort()
	return PackedStringArray(tiers.map(func(tier): return str(tier)))


# A fresh profile has no rung to pick, so the card names only how to open one: HARD's threat, pay
# and held tier wait for the first unlock (w22 first-timer red team watch 6).
func ladder_open() -> bool:
	return RunTier.top_unlocked(_profile) >= RunTier.HARD


func _held_words() -> String:
	return "Tier %d held for this run" % _run.selected_run_tier()


func offered_tiers() -> Array:
	return StartPicks.offered_tiers(_profile)


# An opened rung's pip; null for a rung the profile has not opened, or with no ladder on the card.
func tier_button(tier: int) -> Button:
	return _tier_buttons.get(tier)


# Whether the card shows the ladder: a rung opened and the choice not yet closed by stage 1's Warden.
func ladder_shown() -> bool:
	return _interactive and visible and _run != null and ladder_open() and _run.run_tier_open()


# The ladder row, left to right: the word, the pips, then the reroll with its key cap.
func _ladder_width() -> float:
	return UiDraw.width(TIER_WORD, UiTokens.BODY) + GAP + _pips_width() + 40.0 + KEY + GAP + REROLL_SIZE.x


func _pips_width() -> float:
	return (RunTier.TOP + 1) * RUNG + RunTier.TOP * RUNG_GAP


func _pip_centre(tier: int) -> Vector2:
	var left := (size.x - _ladder_width()) * 0.5 + UiDraw.width(TIER_WORD, UiTokens.BODY) + GAP
	return Vector2(left + RUNG * 0.5 + tier * (RUNG + RUNG_GAP), _controls_top() + LADDER_ROW)


func _button(at: Vector2, extent_value: Vector2, words: String, action: Callable) -> Button:
	var button := Button.new()
	button.position = at
	button.size = extent_value
	button.text = words
	button.pressed.connect(action)
	add_child(button)
	return button


func _label(words: String, y: float) -> void:
	var label := Label.new()
	label.text = words
	label.position = Vector2(0.0, y)
	label.size = Vector2(size.x, 28.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", UiTokens.BODY)
	add_child(label)


# centred is for a card that offers no tier beside it (the briefing on a profile with no rung, or a held tier).
func _reroll(y: float, centred := false) -> void:
	# The V key is a drawn cap left of the button (_draw), as the tiles' keys are.
	var alone := centred and _briefing
	var x := size.x * 0.5 - 80.0 if alone else size.x * 0.5 + 122.0
	_reroll_at(Vector2(x, y + 60.0), Vector2(160.0 if alone else REROLL_SIZE.x, REROLL_SIZE.y))


func _reroll_at(at: Vector2, extent_value: Vector2) -> void:
	reroll_button = _button(at, extent_value, "Reroll", func(): reroll_requested.emit())
	reroll_button.disabled = _rerolls <= 0


func _controls() -> void:
	# A pick redraws the card (flow.show_start_card): the focus stays on the rung it was on.
	var held := _focused_tier()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_tier_buttons.clear()
	_looked = -1
	_tile_buttons.clear()
	reroll_button = null
	if not _interactive or not visible:
		return
	for index in _tiles.size():
		var rect := _tile_rects[index]
		var button := _button(rect.position, rect.size, "", func(): pick_requested.emit(index))
		button.flat = true
		button.tooltip_text = "Take " + String(_tiles[index].name)
		_tile_buttons.append(button)
	var y := _controls_top()
	if not ladder_open():
		_label(UNLOCK_WORDS, y)
		_reroll(y, true)
		return
	if not _run.run_tier_open():
		# Closed when stage 1's Warden engages (run_state.gd _tier_closed): the card names the tier the run holds.
		_label(_held_words(), y)
		_reroll(y, true)
		return
	# The ladder: a pip for each rung the profile has opened takes the press; the pips, the locked rungs,
	# the gauges and a looked-at rung's contract are drawn (_draw_ladder).
	for tier_value in offered_tiers():
		var pip := _button(_pip_centre(tier_value) - Vector2(RUNG, RUNG) * 0.5, Vector2(RUNG, RUNG), "", func(): tier_requested.emit(tier_value))
		pip.flat = true
		# The looked-at ring is drawn (_draw_ladder), so the button's own focus box stays off.
		pip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		pip.focus_entered.connect(_look.bind(tier_value))
		pip.mouse_entered.connect(_look.bind(tier_value))
		pip.focus_exited.connect(_look_away.bind(tier_value, false))
		pip.mouse_exited.connect(_look_away.bind(tier_value, true))
		_tier_buttons[tier_value] = pip
	if held >= 0 and _tier_buttons.has(held) and is_inside_tree():
		_tier_buttons[held].grab_focus()
	var last := _pip_centre(RunTier.TOP)
	_reroll_at(Vector2(last.x + RUNG * 0.5 + 40.0 + KEY + GAP, last.y - REROLL_SIZE.y * 0.5), REROLL_SIZE)


# The buttons the focus walks, left to right as they read: the tiles, then the ladder's pips and
# Reroll, leaving out any that cannot be pressed.
func _focus_ring() -> Array:
	var ring: Array = _tile_buttons.duplicate()
	var tiers: Array = _tier_buttons.keys()
	tiers.sort()
	ring.append_array(tiers.map(func(tier): return _tier_buttons[tier]))
	ring.append(reroll_button)
	return ring.filter(func(button): return button != null and is_instance_valid(button) and not button.disabled)


# The briefing's focus moves: left and right step along the ring; with nothing focused the first
# step lands on the first tile (or the ring's last button, stepping left).
func step_focus(direction: int) -> void:
	var ring := _focus_ring()
	if ring.is_empty() or not visible:
		return
	var at := ring.find(get_viewport().gui_get_focus_owner())
	var next := clampi(at + direction, 0, ring.size() - 1)
	if at < 0:
		next = 0 if direction >= 0 else ring.size() - 1
	ring[next].grab_focus()


func focused_tile() -> int:
	for i in _tile_buttons.size():
		if _tile_buttons[i].has_focus():
			return i
	return -1


# Confirm presses whichever of the card's buttons holds the focus (a tile, the reroll, a tier).
# With none focused a key does nothing, and the pad's press only lands the focus on the first tile,
# so a confirm held from the page before takes nothing.
func confirm(pad := false) -> void:
	if not visible or not is_inside_tree():
		return
	var held := get_viewport().gui_get_focus_owner()
	if held is BaseButton and is_ancestor_of(held) and not (held as BaseButton).disabled:
		(held as BaseButton).pressed.emit()
	elif pad:
		step_focus(1)


# The briefing's focus keys, for the keyboard and the pad: A and D or left and right step the
# focus, confirm presses what it holds.
func _focus_key(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_A:
				step_focus(-1)
				return true
			KEY_D:
				step_focus(1)
				return true
	if event.is_action_pressed("ui_left"):
		step_focus(-1)
		return true
	if event.is_action_pressed("ui_right"):
		step_focus(1)
		return true
	if event.is_action_pressed("ui_accept"):
		confirm(event is InputEventJoypadButton)
		return true
	return false


func _input(event: InputEvent) -> void:
	if not _interactive or not visible:
		return
	if covered.is_valid() and covered.call():
		return
	if _briefing and _focus_key(event):
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if key >= KEY_1 and key <= KEY_3:
		pick_requested.emit(key - KEY_1)
	elif key == KEY_V:
		reroll_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()


# The frames and gauge colours the last draw put down: {"frames": [StyleBox], "gauges": [Color]}.
func drawn_marks() -> Dictionary:
	return _drawn.duplicate(true)


func _draw() -> void:
	_drawn = {"frames": [], "gauges": []}
	var k := _k()
	var h := (ICON + PAD * 2.0) * k
	for index in _tiles.size():
		var tile: Dictionary = _tiles[index]
		var rect := _tile_rects[index]
		_put_frame(_frames[index], rect)
		var mid := h * 0.5
		var cx := rect.position.x + PAD * k
		# A drawn cap, so the key's number shows (a key's own SVG imports as a blank cap, keycap.gd).
		Keycap.draw(self, Vector2(cx + KEY * k * 0.5, mid), tile["key"], Palette.SAND, KEY * k)
		cx += (KEY + GAP) * k
		draw_texture_rect(Icons.texture(tile["icon"]), Rect2(Vector2(cx, mid - ICON * k * 0.5), Vector2(ICON, ICON) * k), false,
			Icons.tint(tile["icon"], _color))
		cx += (ICON + GAP) * k
		var effect := String(tile.get("effect", ""))
		if effect == "":
			UiDraw.text(self, cx, mid, String(tile["name"]), int(FONT * k), _color)
		else:
			UiDraw.text(self, cx, mid - NAME_RISE * k, String(tile["name"]), int(FONT * k), _color)
			UiDraw.text(self, cx, mid + EFFECT_DROP * k, effect, int(EFFECT_FONT * k), Palette.SAND)
	if reroll_button != null and is_instance_valid(reroll_button):
		var cap := reroll_button.position + Vector2(-KEY * 0.5 - GAP, reroll_button.size.y * 0.5)
		Keycap.draw(self, cap, REROLL_KEY, Color(Palette.SAND, 0.4 if reroll_button.disabled else 1.0), KEY)
	if ladder_shown():
		_draw_ladder()
	# One pip per reroll left, centred under the tiles: a spent reroll leaves an outline.
	for i in StartPicks.REROLLS:
		var at := Vector2(size.x * 0.5 + (i - (StartPicks.REROLLS - 1) * 0.5) * PIP * k * 3.0, h + PIP * k * 1.5)
		if i < _rerolls:
			draw_circle(at, PIP * k, _color)
		else:
			draw_arc(at, PIP * k, 0.0, TAU, 16, Color(_color, 0.5), 1.5)


# A tile's frame, drawn and noted in one step so the record is what was drawn.
func _put_frame(box: StyleBox, rect: Rect2) -> void:
	draw_style_box(box, rect)
	_drawn.frames.append(box)


# The ladder as drawn: the selected rung is a filled disc in the pilot's colour, an opened rung a
# sand ring and a locked rung a faint one. Under it the gauges of the rung looked at, or of the
# selected rung: hazard for what the works gains, the Keeper's ink for what is the pilot's. A gauge is faint up to
# the base tier's mark and bright past it; a gauge short of the mark (the top rungs' regen) leaves the
# lost length as a hazard outline. Under the gauges, the looked-at rung's contract in words.
func _draw_ladder() -> void:
	var row_y := _controls_top() + LADDER_ROW
	var selected: int = _run.selected_run_tier()
	var looked := _looked_tier()
	var top := RunTier.top_unlocked(_profile)
	UiDraw.text(self, _pip_centre(0).x - RUNG * 0.5 - GAP - UiDraw.width(TIER_WORD, UiTokens.BODY), row_y, TIER_WORD, UiTokens.BODY, Palette.SAND)
	for tier in RunTier.TOP + 1:
		var at := _pip_centre(tier)
		var numeral := str(tier) if tier == selected or tier == looked else ""
		var ink := Palette.SAND
		if tier == selected:
			draw_circle(at, RUNG * 0.5, _color)
			draw_arc(at, RUNG * 0.5 + 4.0, 0.0, TAU, 32, _color, 2.0)
			ink = Palette.CHARCOAL
		elif tier <= top:
			draw_circle(at, RUNG * 0.5, Color(Palette.CHARCOAL, 0.88))
			draw_arc(at, RUNG * 0.5, 0.0, TAU, 32, Palette.SAND, 2.0)
			if tier == looked:
				draw_arc(at, RUNG * 0.5 + 4.0, 0.0, TAU, 32, Palette.SAND, 2.0)
		else:
			draw_arc(at, RUNG * 0.5, 0.0, TAU, 32, Color(Palette.SAND, 0.3), 1.5)
			ink = Color(Palette.SAND, 0.3)
		var font := UiFonts.bold()
		var base := Vector2(at.x - UiDraw.width(numeral, RUNG_FONT) * 0.5, at.y + (font.get_ascent(RUNG_FONT) - font.get_descent(RUNG_FONT)) * 0.5)
		draw_string(font, base, numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, RUNG_FONT, ink)
	var meters := RunTier.meters(_shown_tier())
	var total := METER_GAP * (meters.size() - 1)
	for meter in meters:
		total += UiDraw.width(String(meter["name"]), METER_FONT) + GAP + METER_BAR.x
	var x := (size.x - total) * 0.5
	var y := _controls_top() + METER_ROW
	for meter in meters:
		x += UiDraw.text(self, x, y, String(meter["name"]), METER_FONT, Palette.SAND) + GAP
		var bar := Rect2(Vector2(x, y - METER_BAR.y * 0.5), METER_BAR)
		var colour: Color = UiTokens.hand(UiTokens.Hand.KEEPER).ink if meter["yours"] else Palette.HAZARD
		_drawn.gauges.append(colour)
		var fill := clampf(float(meter["fill"]), 0.0, 1.0)
		var mark := clampf(float(meter["base"]), 0.0, 1.0)
		UiDraw.bar(self, bar, minf(fill, mark), Color(colour, 0.4))
		if fill > mark:
			draw_rect(Rect2(bar.position + Vector2(bar.size.x * mark, 0.0), Vector2(bar.size.x * (fill - mark), bar.size.y)), colour)
		elif fill < mark:
			draw_rect(Rect2(bar.position + Vector2(bar.size.x * fill, 0.0), Vector2(bar.size.x * (mark - fill), bar.size.y)), Palette.HAZARD, false, 1.5)
		draw_line(bar.position + Vector2(bar.size.x * mark, -3.0), bar.position + Vector2(bar.size.x * mark, bar.size.y + 3.0), Palette.SAND, 2.0)
		x += METER_BAR.x + METER_GAP
	if looked >= 0:
		var lines := RunTier.contract_lines(looked)
		for i in lines.size():
			var line_y := _controls_top() + CONTRACT_ROW + i * CONTRACT_STEP
			UiDraw.text(self, (size.x - UiDraw.width(lines[i], CONTRACT_FONT)) * 0.5, line_y, lines[i], CONTRACT_FONT, Palette.SAND)
