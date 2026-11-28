extends Node

signal finished(id: String, skipped: bool)
signal started(id: String)

const Rows := preload("res://src/presentation/flourish_rows.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const Inset := preload("res://src/presentation/flourish_inset.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const Comfort := preload("res://src/core/comfort.gd")

const LAYER := 39
const SKIP_GRACE := 1.5
const SEEN_SHARE := 0.6
const MAX_QUEUED := 3
const QUEUE_WAIT := 6.0
const PLAY_ACTIONS := ["cl_forward", "cl_back", "cl_left", "cl_right", "cl_jump", "cl_boost", "cl_haul", "cl_fire", "cl_harpoon"]
const AVOID_GROUP := "flourish_avoid"
const AVOID_GAP := 12.0
const FACT_KINDS := ["card", "caption", "panels", "stamp", "inset"]
const WRITTEN := ["card", "caption", "panels"]
const HOLDS_VOICES := ["card", "caption", "panels", "stamp"]
const INK := Color("17141a")
const PAPER := Color("f3ecdc")
const CAPTION_FILL := Color("fff6c9")
const SFX_FILL := Color("ffd23f")
const COLUMN_X := 0.03
const COLUMN_WIDTH := 0.30
const SLOT_Y := {"left_top": 0.30, "left_low": 0.50}
const STAMP_OVERLAP := 0.08
const STAMP_RIGHT := 0.5
const STAMP_MIN_SHARE := 0.4
const STAMP_CENTRE_Y := 0.40
const PLAY_VIEW := Rect2(0.34, 0.30, 0.60, 0.28)
const INSET_VIEW := Rect2(0.715, 0.295, 0.25, 0.32)
const INSET_TILT := 2.0
const BASE_HEIGHT := 1080.0


var ctx
var playing := false
var id := ""
var short := false
var clock := 0.0
var _wall := 0.0
var run_seed := 0
var played: Array = []

var _pieces: Array = []
var _started: Array[bool] = []
var _live: Array = []
var _anchors := {}
var _queue: Array = []
var _seen_key := ""
var _layer: CanvasLayer
var _overlay: Control
var _lines: Control
var _tweens: Array[Tween] = []


func setup(ctx_ref) -> void:
	name = "FlourishPlayer"
	add_to_group(PlayerFx.KEEP_GROUP)
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


func play(row_id: String, seed_value := -1, anchors := {}, form := "") -> bool:
	if not Rows.has(row_id):
		return false
	if playing:
		if Rows.priority(row_id) <= Rows.priority(id):
			_expire_queue()
			if _queue.size() >= MAX_QUEUED:
				return false
			_queue.append([row_id, seed_value, anchors, form, 0.0])
			return true
		_finish("preempted", false)
		if playing:
			_queue.push_front([row_id, seed_value, anchors, form, 0.0])
			return true
	_start(row_id, seed_value, anchors, form)
	return true


func length() -> float:
	return Rows.length(id, short) if id != "" else 0.0


func skip() -> void:
	if playing:
		_finish("skipped")


func stop_all() -> void:
	_queue.clear()
	if playing:
		_finish("stopped", false)


func queued() -> Array:
	return _queue.map(func(entry): return entry[0])


func reading(row_id := "") -> bool:
	if row_id != "" and row_id in queued():
		return true
	if not playing or (row_id != "" and id != row_id):
		return false
	return _pieces.any(func(piece): return String(piece.kind) in HOLDS_VOICES and clock < float(piece.at) + float(piece["for"]))


func has(row_id: String) -> bool:
	return (playing and id == row_id) or row_id in queued()


func in_window(row_id: String, from: float, to: float) -> bool:
	return playing and id == row_id and clock >= from and clock < to


func close_up() -> bool:
	if not playing:
		return false
	for piece in _pieces:
		if String(piece.kind) == "inset" and clock < float(piece.at) + float(piece["for"]) and _subject_of(piece) != null:
			return true
	return false


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
	_seen_key = key if profile != null and not short else ""
	for entry in _live.duplicate():
		_drop(entry)
	_clear_lines()
	_pieces = Rows.resolve(row_id, short, run_seed)
	_started.clear()
	_started.resize(_pieces.size())
	_started.fill(false)
	_anchors = anchors
	clock = 0.0
	_wall = 0.0
	playing = true
	set_process(true)
	started.emit(row_id)
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
	if skippable() and not get_tree().paused and skips(event) and not _play_verb(event):
		skip()


func skippable() -> bool:
	return playing and _wall >= SKIP_GRACE


func _play_verb(event: InputEvent) -> bool:
	for action in PLAY_ACTIONS:
		if InputMap.has_action(action) and InputMap.event_is_action(event, action):
			return true
	return false


const WHEEL := [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]


static func skips(event: InputEvent) -> bool:
	return (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed and not event.button_index in WHEEL) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)


func advance(delta: float) -> void:
	if not playing:
		return
	clock += delta
	_wall += delta / maxf(Engine.time_scale, 0.01)
	for entry in _queue:
		entry[4] = float(entry[4]) + delta
	if clock >= length():
		_finish("")
		return
	for words_pass in [false, true]:
		for i in _pieces.size():
			var piece: Dictionary = _pieces[i]
			if (String(piece.kind) == "sfx_word") != words_pass:
				continue
			if not _started[i] and clock >= float(piece.at):
				_started[i] = true
				var node := _build(piece)
				if node != null:
					node.set_meta("flourish_kind", String(piece.kind))
					_live.append({"piece": piece, "node": node, "end": float(piece.at) + float(piece["for"])})
					if String(piece.kind) in FACT_KINDS:
						_yield_words(node)
	for entry in _live.duplicate():
		if clock >= float(entry.end):
			_drop(entry)
		elif String(entry.piece.kind) == "sfx_word":
			_place_word(entry.node, entry.piece)
		elif String(entry.piece.kind) == "panels":
			_reveal_panels(entry)
	if _lines != null:
		_lines.queue_redraw()


func _finish(cut: String, next := true) -> void:
	var skipped := cut != ""
	var record := {"id": id, "s": snappedf(minf(clock, length()), 0.01), "full": not short, "skipped": skipped, "held": 0.0, "cut": cut}
	if _seen_key != "" and (not skipped or clock >= length() * SEEN_SHARE):
		_mark_seen(_seen_key)
	_seen_key = ""
	played.append(record)
	playing = false
	set_process(false)
	for entry in _live.duplicate():
		_drop(entry)
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	_clear_lines()
	var done := id
	id = ""
	_anchors = {}
	finished.emit(done, skipped)
	_log(record)
	if next:
		_expire_queue()
	if next and not _queue.is_empty() and not playing:
		var entry: Array = _queue.pop_front()
		_start(entry[0], entry[1], entry[2], entry[3])


func _expire_queue() -> void:
	for entry in _queue.duplicate():
		if float(entry[4]) > QUEUE_WAIT or not _anchors_alive(entry[2]):
			_queue.erase(entry)
			var record := {"id": entry[0], "s": 0.0, "full": false, "skipped": true, "held": 0.0, "cut": "expired"}
			played.append(record)
			finished.emit(entry[0], true)
			_log(record)


func _log(record: Dictionary) -> void:
	if ctx != null and ctx.get("run") != null:
		var log: Array = ctx.run.get_meta("flourishes", [])
		log.append(record)
		ctx.run.set_meta("flourishes", log)


func _anchors_alive(anchors: Dictionary) -> bool:
	for name in anchors:
		if not is_instance_valid(anchors[name]):
			return false
	return true


func _mark_seen(key: String) -> void:
	var profile = _profile()
	if profile == null or not profile.mark_seen(key):
		return
	if not profile.save_if_allowed():
		push_warning("flourish: profile not saved: %s" % profile.last_error)


func _drop(entry: Dictionary) -> void:
	_live.erase(entry)
	if String(entry.piece.kind) in FACT_KINDS:
		_room_changed()
	if String(entry.piece.kind) == "speed_lines":
		_clear_lines()
	var node = entry.node
	if is_instance_valid(node) and node is Node:
		node.queue_free()


func _clear_lines() -> void:
	if _lines == null:
		return
	_lines.set("mode", "")
	_lines.set("tint", Color.WHITE)
	_lines.queue_redraw()


func _yield_words(node: Control) -> void:
	_room_changed()
	var rect := node.get_global_rect()
	for entry in _live:
		if String(entry.piece.kind) == "sfx_word" and is_instance_valid(entry.node) and entry.node.visible \
				and entry.node.get_global_rect().intersects(rect):
			entry.node.visible = false


func _room_changed() -> void:
	var room = get_tree().get_first_node_in_group(PlayerFx.ROOM_GROUP) if is_inside_tree() else null
	if room != null:
		room.keep_clear_changed()


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920.0, 1080.0)


func _scale() -> float:
	return maxf(0.5, _screen().y / BASE_HEIGHT)


func _build(piece: Dictionary) -> Node:
	match String(piece.kind):
		"card":
			return _card(piece.card, String(piece.get("slot", "left_top")), String(piece.get("accent", "")))
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
			if not _place_word(label, piece):
				label.queue_free()
				return null
			_pop(label, 1.5)
			return label
		"inset":
			return _inset(piece)
		"speed_lines":
			if Comfort.reduced_motion:
				return null
			_lines.set("mode", "speed")
			var line_colour: Color = _colour(String(piece.get("colour", ""))) if piece.has("colour") else Color.WHITE
			_lines.set("tint", line_colour)
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
	label.custom_minimum_size.x = _column_right() - _screen().x * COLUMN_X - 40.0 * _scale()
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


func _card(card: Array, slot: String, accent := "") -> Control:
	var s := _scale()
	var panel := _panel(PAPER, 4)
	panel.name = "FlourishCard"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(3 * s))
	if accent != "":
		var frame := HBoxContainer.new()
		frame.add_theme_constant_override("separation", int(10 * s))
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bar := ColorRect.new()
		bar.color = _colour(accent)
		bar.custom_minimum_size = Vector2(maxf(4.0, 6.0 * s), 0.0)
		bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(bar)
		frame.add_child(column)
		panel.add_child(frame)
	else:
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
		if i > 0 and not Comfort.reduced_motion:
			panel.modulate.a = 0.0
	_seat(strip, _column_at("left_top"))
	return strip


func _anchor(name: String) -> Node3D:
	var node = _anchors.get(name)
	return node if is_instance_valid(node) and node is Node3D and node.is_inside_tree() else null


func _subject_of(piece: Dictionary) -> Node3D:
	return _anchor(String(piece.get("anchor", "")))


func _inset(piece: Dictionary) -> Control:
	var subject := _subject_of(piece)
	if subject == null:
		return null
	var home := _anchor(String(piece.get("home", "")))
	var toward := _anchor(String(piece.get("toward", "")))
	var rests: Vector3 = home.global_position if home != null else subject.global_position
	var screen := _screen()
	var inset := Inset.new()
	inset.name = "FlourishInset"
	inset.add_to_group(AVOID_GROUP)
	_overlay.add_child(inset)
	inset.frame(subject, rests, toward.global_position if toward != null else rests + Vector3.BACK,
		INSET_VIEW.size * screen, maxi(3, int(6 * _scale())))
	inset.position = INSET_VIEW.position * screen
	inset.rotation_degrees = INSET_TILT
	inset.still = Comfort.reduced_motion
	_pop(inset, 1.2)
	return inset


func _seat(node: Control, at: Vector2) -> void:
	node.reset_size()
	var screen := _screen()
	var tilt_y := node.size.x * absf(sin(deg_to_rad(node.rotation_degrees))) + 2.0
	var floor_y := ScreenRegions.rect("prompts", screen).position.y - 8.0 * _scale() - tilt_y
	var ceiling := ScreenRegions.rect("toasts", screen).end.y + tilt_y
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


func _reveal_panels(entry: Dictionary) -> void:
	var strip: Control = entry.node
	for i in strip.get_child_count():
		if clock >= float(entry.piece.at) + Rows.PANEL_STEP * i:
			strip.get_child(i).modulate.a = 1.0


func _avoid_rects() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	for node in get_tree().get_nodes_in_group(AVOID_GROUP):
		if node is Control and node.is_visible_in_tree():
			out.append(node.get_global_rect())
	return out


func _column_right() -> float:
	return minf(_screen().x * (COLUMN_X + COLUMN_WIDTH), _avoid_right())


func _avoid_right() -> float:
	var screen := _screen()
	var right := INF
	var top: float = screen.y * SLOT_Y.left_top
	var band := Rect2(0.0, top, screen.x, ScreenRegions.rect("prompts", screen).position.y - top)
	for rect in _avoid_rects():
		if rect.intersects(band) and rect.position.x > screen.x * COLUMN_X:
			right = minf(right, rect.position.x - AVOID_GAP * _scale())
	return right


func _stamp_at(label: Control) -> Vector2:
	var screen := _screen()
	var top: Control = null
	for entry in _live:
		if String(entry.piece.kind) in WRITTEN and is_instance_valid(entry.node):
			if top == null or entry.node.position.y < top.position.y:
				top = entry.node
	if top == null:
		return _column_at("left_top")
	var start := top.position.x + top.size.x
	var limit := minf(screen.x * STAMP_RIGHT, _avoid_right())
	var room := limit - start
	if label.size.x * (1.0 - STAMP_OVERLAP) > room:
		var share := clampf(room / (label.size.x * (1.0 - STAMP_OVERLAP)), STAMP_MIN_SHARE, 1.0)
		label.add_theme_font_size_override("font_size", int(label.get_theme_font_size("font_size") * share))
		label.reset_size()
	var x := maxf(screen.x * COLUMN_X, minf(start - label.size.x * STAMP_OVERLAP, limit - label.size.x))
	return Vector2(x, top.position.y + top.size.y * 0.5 - label.size.y * 0.5)


func keep_clear_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for entry in _live:
		if String(entry.piece.kind) == "sfx_word" or not is_instance_valid(entry.node) or not entry.node is Control:
			continue
		var node: Control = entry.node
		if node.is_visible_in_tree():
			out.append(node.get_global_rect())
	return out


func _place_word(label: Control, piece: Dictionary) -> bool:
	var screen := _screen()
	var share: Vector2 = piece.get("at_share", Vector2(0.62, 0.36))
	var anchor = _anchors.get(String(piece.get("anchor", "")))
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if is_instance_valid(anchor) and anchor is Node3D and anchor.is_inside_tree() and camera != null \
			and not camera.is_position_behind(anchor.global_position):
		share = camera.unproject_position(anchor.global_position + Vector3.UP * 2.0) / screen
	label.reset_size()
	var view := Rect2(PLAY_VIEW.position * screen, PLAY_VIEW.size * screen)
	var asked := share * screen - label.size * 0.5
	var gap := AVOID_GAP * _scale()
	var spots: Array[Vector2] = [asked, asked + Vector2(0.0, -label.size.y - gap), asked + Vector2(0.0, label.size.y + gap),
		asked + Vector2(label.size.x + gap, 0.0), asked - Vector2(label.size.x + gap, 0.0)]
	var room = get_tree().get_first_node_in_group(PlayerFx.ROOM_GROUP) if is_inside_tree() else null
	var avoid := _avoid_rects()
	for i in spots.size():
		var at := Vector2(clampf(spots[i].x, view.position.x, maxf(view.position.x, view.end.x - label.size.x)),
			clampf(spots[i].y, view.position.y, maxf(view.position.y, view.end.y - label.size.y)))
		var rect := Rect2(at, label.size)
		if avoid.any(func(r): return r.intersects(rect)):
			continue
		if room != null and not room.spot_free(rect):
			continue
		label.position = at
		return true
	return false


func _pop(node: Control, from: float) -> void:
	if Comfort.reduced_motion or not is_inside_tree():
		return
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * from
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens.append(tween)


class Lines extends Control:
	var player
	var mode := ""
	var tint := Color.WHITE

	func _draw() -> void:
		if mode == "" or player == null:
			return
		var centre := size * 0.5
		var reach := size.length()
		var clock: float = player.clock
		var primary := Color(tint.r, tint.g, tint.b, 0.28)
		var bright := Color(1.0, 1.0, 1.0, 0.34)
		for i in 48:
			var angle := TAU * i / 48.0 + clock * 0.4
			var inner := centre + Vector2.from_angle(angle) * size.y * (0.46 + 0.04 * sin(i * 7.0 + clock * 9.0))
			var width := 4.5 if i % 4 == 0 else 2.5
			draw_line(inner, centre + Vector2.from_angle(angle) * reach, bright if i % 4 == 0 else primary, width)
