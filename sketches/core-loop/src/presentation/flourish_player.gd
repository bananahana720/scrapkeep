extends Node

# Plays one row of flourish_rows.gd over play: name cards, inked stamps, captions, comic panels
# and drawn sound words on a canvas layer, in the title openings' comic look
# (title_intro_player.gd). It never stops time, never moves the camera and never eats input:
# any fresh press after SKIP_GRACE ends the row and still reaches the ball. While the tree is
# paused (a reward ceremony, the pause menu) the row hides and waits.
#
# Layout keeps to ScreenRegions: cards, captions, panels and stamps in the left column of the
# play view (a stamp inks onto the right edge of the top piece), sound words at their anchor clamped inside
# the play view. Nothing sits over the top band (the boss plate), the toast band (the world and
# stage cards), the prompts or the bottom bar.
#
# A row plays in full the first time a profile sees it and in its short form after. Every
# finished row (shown out or skipped) emits finished and joins the run's "flourishes" meta,
# which run_log.gd writes into the run record.

signal finished(id: String, skipped: bool)

const Rows := preload("res://src/presentation/flourish_rows.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")

const LAYER := 39
const SKIP_GRACE := 0.8
const MAX_QUEUED := 3
const INK := Color("17141a")
const PAPER := Color("f3ecdc")
const CAPTION_FILL := Color("fff6c9")
const SFX_FILL := Color("ffd23f")
const COLUMN_X := 0.03
const COLUMN_WIDTH := 0.30
const SLOT_Y := {"left_top": 0.30, "left_low": 0.50}
# A stamp inks onto the right edge of the column's top piece (the punch card, the comic page);
# "centre" puts it over the upper play view, for a caller that knows no threat is committed.
const STAMP_OVERLAP := 0.25
const STAMP_RIGHT := 0.5
const STAMP_CENTRE_Y := 0.40
# Sound words stay inside the play view, between the toast band and the prompts.
const PLAY_VIEW := Rect2(0.34, 0.30, 0.60, 0.28)
const BASE_HEIGHT := 1080.0

static var reduced_motion := false

var ctx
var playing := false
var id := ""
var short := false
var clock := 0.0
var run_seed := 0
# Every row finished since setup: {id, s, full, skipped, held}. finished is emitted before the
# record joins the run meta, and it is the same dictionary, so a listener may set its held.
var played: Array = []

var _pieces: Array = []
var _started: Array[bool] = []
var _live: Array = []
var _anchors := {}
var _queue: Array = []
var _layer: CanvasLayer
var _overlay: Control
var _lines: Control
var _tweens: Array[Tween] = []


func setup(ctx_ref) -> void:
	name = "FlourishPlayer"
	ctx = ctx_ref
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.name = "Flourish"
	_layer.layer = LAYER
	add_child(_layer)
	_lines = Lines.new()
	_lines.name = "FlourishLines"
	_lines.player = self
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_lines)
	_overlay = Control.new()
	_overlay.name = "FlourishOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_overlay)
	set_process(false)


# Starts a row, or queues it behind a row of equal or higher priority. A higher row ends the
# one showing (as skipped). seed_value < 0 reads the run's seed. anchors: name -> Node3D for
# sound words. form "full" or "short" overrides the seen rule (stills, tests) and marks nothing.
# False for an unknown row or a full queue.
func play(row_id: String, seed_value := -1, anchors := {}, form := "") -> bool:
	if not Rows.has(row_id):
		return false
	if playing:
		if Rows.priority(row_id) <= Rows.priority(id):
			if _queue.size() >= MAX_QUEUED:
				return false
			_queue.append([row_id, seed_value, anchors, form])
			return true
		_finish(true, false)
	_start(row_id, seed_value, anchors, form)
	return true


func length() -> float:
	return Rows.length(id, short) if id != "" else 0.0


func skip() -> void:
	if playing:
		_finish(true)


# Ends the showing row and drops the queue: a screen change away from play.
func stop_all() -> void:
	_queue.clear()
	if playing:
		_finish(true, false)


func queued() -> Array:
	return _queue.map(func(entry): return entry[0])


# Pieces on screen now, by kind, for tests and stills.
func live_kinds() -> Array:
	return _live.map(func(entry): return String(entry.piece.kind))


func live_nodes() -> Array:
	return _live.map(func(entry): return entry.node)


func _start(row_id: String, seed_value: int, anchors: Dictionary, form: String) -> void:
	id = row_id
	run_seed = seed_value if seed_value >= 0 else _run_seed()
	var profile = _profile() if form == "" else null
	var key: String = Rows.SEEN_PREFIX + row_id
	short = form == "short" or (profile != null and profile.is_seen(key))
	if profile != null and not short:
		profile.mark_seen(key)
		if profile.get("can_save") and not profile.save():
			push_warning("flourish: profile not saved: %s" % profile.last_error)
	_pieces = Rows.resolve(row_id, short, run_seed)
	_started.clear()
	_started.resize(_pieces.size())
	_started.fill(false)
	_anchors = anchors
	clock = 0.0
	playing = true
	set_process(true)
	advance(0.0)


func _run_seed() -> int:
	if ctx != null and ctx.get("run") != null:
		return int(ctx.run.run_seed)
	return 0


func _profile():
	return ctx.get("profile") if ctx != null else null


func _process(delta: float) -> void:
	var paused := get_tree().paused
	_layer.visible = not paused
	if not paused:
		advance(delta)


func _input(event: InputEvent) -> void:
	if playing and clock >= SKIP_GRACE and not get_tree().paused and skips(event):
		skip()


static func skips(event: InputEvent) -> bool:
	return (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)


# Moves the row on by delta seconds; tests call it directly.
func advance(delta: float) -> void:
	if not playing:
		return
	clock += delta
	if clock >= length():
		_finish(false)
		return
	for i in _pieces.size():
		var piece: Dictionary = _pieces[i]
		if not _started[i] and clock >= float(piece.at):
			_started[i] = true
			var node := _build(piece)
			if node != null:
				node.set_meta("flourish_kind", String(piece.kind))
				_live.append({"piece": piece, "node": node, "end": float(piece.at) + float(piece["for"])})
	for entry in _live.duplicate():
		if clock >= float(entry.end):
			_drop(entry)
		elif String(entry.piece.kind) == "sfx_word":
			_place_word(entry.node, entry.piece)
	if _lines != null:
		_lines.queue_redraw()


func _finish(skipped: bool, next := true) -> void:
	var record := {"id": id, "s": snappedf(minf(clock, length()), 0.01), "full": not short, "skipped": skipped, "held": 0.0}
	played.append(record)
	playing = false
	set_process(false)
	for entry in _live.duplicate():
		_drop(entry)
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	_lines.set("mode", "")
	var done := id
	id = ""
	_anchors = {}
	finished.emit(done, skipped)
	if ctx != null and ctx.get("run") != null:
		var log: Array = ctx.run.get_meta("flourishes", [])
		log.append(record)
		ctx.run.set_meta("flourishes", log)
	if next and not _queue.is_empty() and not playing:
		var entry: Array = _queue.pop_front()
		_start(entry[0], entry[1], entry[2], entry[3])


func _drop(entry: Dictionary) -> void:
	_live.erase(entry)
	if String(entry.piece.kind) == "speed_lines":
		_lines.set("mode", "")
	var node = entry.node
	if is_instance_valid(node) and node is Node:
		node.queue_free()


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920.0, 1080.0)


func _scale() -> float:
	return maxf(0.5, _screen().y / BASE_HEIGHT)


func _build(piece: Dictionary) -> Node:
	match String(piece.kind):
		"card":
			return _card(piece.card, String(piece.get("slot", "left_top")))
		"stamp":
			return _stamp(String(piece.text), _colour(String(piece.get("colour", "HAZARD"))), String(piece.get("slot", "column")))
		"caption":
			return _caption(String(piece.text), String(piece.get("slot", "left_top")))
		"panels":
			return _panels(piece.texts)
		"sfx_word":
			var label := _label(String(piece.text), int(72 * _scale()), SFX_FILL, int(10 * _scale()))
			label.name = "FlourishWord"
			label.rotation_degrees = -6.0
			_overlay.add_child(label)
			_place_word(label, piece)
			_pop(label, 1.5)
			return label
		"speed_lines":
			if reduced_motion:
				return null
			_lines.set("mode", "speed")
			var marker := Control.new()
			_overlay.add_child(marker)
			return marker
	push_warning("flourish: unknown piece kind %s in %s" % [piece.kind, id])
	return null


func _colour(palette_name: String) -> Color:
	return (Palette as Script).get_script_constant_map().get(palette_name, Palette.HAZARD)


func _column_at(slot: String) -> Vector2:
	return Vector2(COLUMN_X, float(SLOT_Y.get(slot, SLOT_Y.left_top))) * _screen()


func _label(text: String, font_size: int, color: Color, outline := 0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_color_override("font_outline_color", INK)
		label.add_theme_constant_override("outline_size", outline)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _wrapped(text: String, font_size: int) -> Label:
	var label := _label(text, font_size, INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = _screen().x * COLUMN_WIDTH - 40.0 * _scale()
	return label


func _panel(fill: Color, border: int) -> PanelContainer:
	var s := _scale()
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = INK
	box.set_border_width_all(maxi(2, int(border * s)))
	box.shadow_color = INK
	box.shadow_offset = Vector2(5.0, 5.0) * s
	box.shadow_size = 1
	box.content_margin_left = 14.0 * s
	box.content_margin_right = 14.0 * s
	box.content_margin_top = 8.0 * s
	box.content_margin_bottom = 10.0 * s
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _card(card: Array, slot: String) -> Control:
	var s := _scale()
	var panel := _panel(PAPER, 4)
	panel.name = "FlourishCard"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(3 * s))
	panel.add_child(column)
	column.add_child(_label(String(card[0]), int(40 * s), INK))
	if card.size() > 1:
		column.add_child(_label(String(card[1]).to_upper(), int(16 * s), Color("4a4250")))
	for i in range(2, card.size() - 1, 2):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(10 * s))
		row.add_child(_label(String(card[i]), int(21 * s), INK))
		row.add_child(_label(String(card[i + 1]), int(21 * s), Color("4a4250")))
		column.add_child(row)
	panel.rotation_degrees = -2.0
	_overlay.add_child(panel)
	_seat(panel, _column_at(slot))
	_pop(panel, 1.25)
	return panel


func _caption(text: String, slot: String) -> Control:
	var panel := _panel(CAPTION_FILL, 3)
	panel.name = "FlourishCaption"
	panel.add_child(_wrapped(text, int(22 * _scale())))
	_overlay.add_child(panel)
	_seat(panel, _column_at(slot))
	_pop(panel, 1.06)
	return panel


func _panels(texts: Array) -> Control:
	var s := _scale()
	var strip := VBoxContainer.new()
	strip.name = "FlourishPanels"
	strip.add_theme_constant_override("separation", int(10 * s))
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(strip)
	for i in texts.size():
		var panel := _panel(PAPER if i < texts.size() - 1 else CAPTION_FILL, 4)
		panel.name = "Panel%d" % i
		panel.add_child(_wrapped(String(texts[i]), int(22 * s)))
		panel.rotation_degrees = [-1.5, 1.0, -0.5][i % 3]
		strip.add_child(panel)
		if i > 0 and not reduced_motion:
			panel.modulate.a = 0.0
			var tween := create_tween()
			tween.tween_interval(Rows.PANEL_STEP * i)
			tween.tween_property(panel, "modulate:a", 1.0, 0.08)
			_tweens.append(tween)
	_seat(strip, _column_at("left_top"))
	return strip


# A column piece at its slot, lifted if it would reach the prompts band, never above the toasts.
func _seat(node: Control, at: Vector2) -> void:
	node.reset_size()
	var screen := _screen()
	var floor_y := ScreenRegions.rect("prompts", screen).position.y - 8.0 * _scale()
	var ceiling := ScreenRegions.rect("toasts", screen).end.y
	node.position = Vector2(at.x, maxf(ceiling, minf(at.y, floor_y - node.size.y)))


func _stamp(text: String, colour: Color, slot: String) -> Control:
	var label := _label(text, int(56 * _scale()), colour, int(12 * _scale()))
	label.name = "FlourishStamp"
	label.rotation_degrees = -8.0
	_overlay.add_child(label)
	label.reset_size()
	if slot == "centre":
		var screen := _screen()
		label.position = Vector2(0.5, STAMP_CENTRE_Y) * screen - label.size * 0.5
	else:
		_seat(label, _stamp_at(label))
	_pop(label, 1.4)
	return label


# On the right edge of the column's top piece, overlapping it by STAMP_OVERLAP of the stamp's
# width so the piece's words stay readable, and never past STAMP_RIGHT of the screen; with no
# piece up, at the column's top slot.
func _stamp_at(label: Control) -> Vector2:
	var screen := _screen()
	var top: Control = null
	for entry in _live:
		if String(entry.piece.kind) in ["card", "caption", "panels"] and is_instance_valid(entry.node):
			if top == null or entry.node.position.y < top.position.y:
				top = entry.node
	if top == null:
		return _column_at("left_top")
	var x := top.position.x + top.size.x - label.size.x * STAMP_OVERLAP
	x = minf(x, screen.x * STAMP_RIGHT - label.size.x)
	return Vector2(x, top.position.y + top.size.y * 0.5 - label.size.y * 0.5)


# A sound word sits at its anchor's screen point, or at its at_share, clamped in the play view.
func _place_word(label: Control, piece: Dictionary) -> void:
	var screen := _screen()
	var share: Vector2 = piece.get("at_share", Vector2(0.62, 0.36))
	var anchor = _anchors.get(String(piece.get("anchor", "")))
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if anchor is Node3D and is_instance_valid(anchor) and anchor.is_inside_tree() and camera != null \
			and not camera.is_position_behind(anchor.global_position):
		share = camera.unproject_position(anchor.global_position + Vector3.UP * 2.0) / screen
	label.reset_size()
	var view := Rect2(PLAY_VIEW.position * screen, PLAY_VIEW.size * screen)
	var at := share * screen - label.size * 0.5
	label.position = Vector2(clampf(at.x, view.position.x, maxf(view.position.x, view.end.x - label.size.x)),
		clampf(at.y, view.position.y, maxf(view.position.y, view.end.y - label.size.y)))


# Three frames of overshoot; reduced motion just shows the piece.
func _pop(node: Control, from: float) -> void:
	if reduced_motion or not is_inside_tree():
		return
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * from
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens.append(tween)


# Speed lines from the screen's rim only, so the play view's middle stays clear.
class Lines extends Control:
	var player
	var mode := ""

	func _draw() -> void:
		if mode == "" or player == null:
			return
		var centre := size * 0.5
		var reach := size.length()
		var clock: float = player.clock
		for i in 48:
			var angle := TAU * i / 48.0 + clock * 0.4
			var inner := centre + Vector2.from_angle(angle) * size.y * (0.46 + 0.04 * sin(i * 7.0 + clock * 9.0))
			draw_line(inner, centre + Vector2.from_angle(angle) * reach, Color(1.0, 1.0, 1.0, 0.28), 3.0)
