extends Control

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Icons := preload("res://src/ui/icons.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const ClassKit := preload("res://src/ui/class_kit.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const AimReticle := preload("res://src/ui/aim_reticle.gd")
const Bindings := preload("res://src/core/bindings.gd")
const ClassDef := preload("res://src/core/class_def.gd")


const ROWS := [
	[["key_quoteleft", 1.0], ["key_1", 1.0], ["key_2", 1.0], ["key_3", 1.0], ["key_4", 1.0], ["key_5", 1.0], ["key_6", 1.0],
		["key_7", 1.0], ["key_8", 1.0], ["key_9", 1.0], ["key_0", 1.0]],
	[["key_tab", 1.5], ["key_q", 1.0], ["key_w", 1.0], ["key_e", 1.0], ["key_r", 1.0], ["key_t", 1.0], ["key_y", 1.0],
		["key_u", 1.0], ["key_i", 1.0], ["key_o", 1.0], ["key_p", 1.0]],
	[["key_caps", 1.75], ["key_a", 1.0], ["key_s", 1.0], ["key_d", 1.0], ["key_f", 1.0], ["key_g", 1.0], ["key_h", 1.0],
		["key_j", 1.0], ["key_k", 1.0], ["key_l", 1.0]],
	[["key_shift", 2.25], ["key_z", 1.0], ["key_x", 1.0], ["key_c", 1.0], ["key_v", 1.0], ["key_b", 1.0], ["key_n", 1.0], ["key_m", 1.0]],
	[["key_ctrl", 1.5], ["key_super", 1.25], ["key_alt", 1.25], ["key_space", 6.25]],
]
const MOUSE_KEYS := ["key_lmb", "key_rmb"]
const LOOK := "key_mouse"
const ARROWS := {"key_w": Vector2.UP, "key_a": Vector2.LEFT, "key_s": Vector2.DOWN, "key_d": Vector2.RIGHT}
const U := 98.0
const ROW_H := 98.0
const GAP := 6.0
const CAP := 22.0
const ICON := 30.0
const FONT := UiTokens.CAPTION
const EXTRA_FONT := UiTokens.CAPTION
const MOUSE_GAP := 24.0
const MOUSE_SIZE := Vector2(124.0, 200.0)
const MOUSE_LEFT_LABEL := 54.0
const MOUSE_RIGHT_LABEL := 108.0
const ARC_R := 17.0
const ARC_W := 4.0

var def: Resource
var _keys := {}


func _init(class_def: Resource = null) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_board_width() + MOUSE_GAP + MOUSE_LEFT_LABEL + MOUSE_RIGHT_LABEL + MOUSE_SIZE.x, ROWS.size() * ROW_H)
	set_class(class_def)


func set_class(class_def: Resource) -> void:
	def = class_def
	_keys = entries(def)
	queue_redraw()


static func entries(class_def) -> Dictionary:
	var out := {}
	for row in FieldNotes.CONTROLS:
		if not (row.has("caps") and row.has("short")):
			continue
		var caps: Array = row["caps"]
		var short: String = row["short"]
		short = short.replace("use / ride", "use/ride").replace("hold restart", "hold-restart")
		for i in caps.size():
			var label := short if i == 0 and not (short == "drive" and ARROWS.has(caps[i])) else ""
			out[caps[i]] = {"label": label, "icon": "", "tone": Color(Palette.SAND, 0.8),
				"lit": false, "extra": "", "extra_icon": ""}
	if class_def == null:
		return out
	for record in ClassKit.keys(class_def):
		var key: String = record["key"]
		if record["slot"] == "extra" and out.has(key):
			out[key]["extra"] = record["words"]
			out[key]["extra_icon"] = record["icon"]
			out[key]["tone"] = ClassDef.screen_color(class_def.color)
			out[key]["lit"] = true
			continue
		out[key] = {"label": record["words"], "icon": record["icon"], "tone": ClassDef.screen_color(class_def.color), "lit": true,
			"extra": "", "extra_icon": ""}
	return out


func lit_keys() -> Dictionary:
	var out := {}
	for key in _keys:
		if _keys[key]["lit"]:
			out[key] = _keys[key]["tone"]
	return out


func shown_keys() -> Array:
	return _keys.keys()


func label_of(key: String) -> String:
	return _keys[key]["label"] if _keys.has(key) else ""


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	for key in _keys:
		if key != LOOK:
			out.append_array(Keycap.words(key))
		for field in ["label", "extra"]:
			if _keys[key][field] != "":
				out.append(_keys[key][field])
	return out


func text_fit_issues() -> Array[String]:
	var issues: Array[String] = []
	var font := UiFonts.bold()
	for r in ROWS.size():
		var x := 0.0
		for spec in ROWS[r]:
			var key: String = spec[0]
			var rect := Rect2(Vector2(x, r * ROW_H), Vector2(spec[1] * U, ROW_H)).grow(-GAP * 0.5)
			x += spec[1] * U
			if not _keys.has(key):
				continue
			var entry: Dictionary = _keys[key]
			var below := _label_rect(rect, rect.size.x)
			if entry["extra"] == "":
				var ms := font.get_multiline_string_size(entry["label"], HORIZONTAL_ALIGNMENT_CENTER, below.size.x, FONT, 2)
				if ms.x > below.size.x + 0.5 or ms.y > below.size.y + 0.5:
					issues.append("%s label '%s' %s > %s" % [key, entry["label"], ms, below.size])
			elif rect.size.x < 2.0 * U:
				var band := Vector2(below.size.x, below.size.y * 0.5)
				var ms1 := font.get_multiline_string_size(entry["label"], HORIZONTAL_ALIGNMENT_CENTER, band.x, FONT, 2)
				var ms2 := font.get_multiline_string_size(entry["extra"], HORIZONTAL_ALIGNMENT_CENTER, band.x, EXTRA_FONT, 2)
				if ms1.x > band.x + 0.5 or ms1.y > band.y + 0.5:
					issues.append("%s label '%s' %s > %s" % [key, entry["label"], ms1, band])
				if ms2.x > band.x + 0.5 or ms2.y > band.y + 0.5:
					issues.append("%s extra '%s' %s > %s" % [key, entry["extra"], ms2, band])
			else:
				var half := rect.size.x * 0.5
				var left_box := _label_rect(rect, half)
				var ms1 := font.get_multiline_string_size(entry["label"], HORIZONTAL_ALIGNMENT_CENTER, left_box.size.x, FONT, 2)
				var ms2 := font.get_multiline_string_size(entry["extra"], HORIZONTAL_ALIGNMENT_CENTER, left_box.size.x, FONT, 2)
				if ms1.x > left_box.size.x + 0.5 or ms1.y > left_box.size.y + 0.5:
					issues.append("%s label '%s' %s > %s" % [key, entry["label"], ms1, left_box.size])
				if ms2.x > left_box.size.x + 0.5 or ms2.y > left_box.size.y + 0.5:
					issues.append("%s extra '%s' %s > %s" % [key, entry["extra"], ms2, left_box.size])
	return issues


static func _board_width() -> float:
	var widest := 0.0
	for row in ROWS:
		var w := 0.0
		for spec in row:
			w += spec[1]
		widest = maxf(widest, w)
	return widest * U


func _draw() -> void:
	for r in ROWS.size():
		var x := 0.0
		for spec in ROWS[r]:
			var rect := Rect2(Vector2(x, r * ROW_H), Vector2(spec[1] * U, ROW_H)).grow(-GAP * 0.5)
			x += spec[1] * U
			if _keys.has(spec[0]):
				_key(spec[0], rect)
			else:
				_blank(rect)
	_mouse()


func _blank(rect: Rect2) -> void:
	draw_style_box(_scrap(Color(Palette.VERDIGRIS, 0.35), Color(Palette.CHARCOAL, 0.35), 1, int(rect.position.x * 7.0 + rect.position.y)), rect)


func _key(key: String, rect: Rect2) -> void:
	var entry: Dictionary = _keys[key]
	var tone: Color = entry["tone"]
	var lit: bool = entry["lit"]
	draw_style_box(_scrap(tone, Color(tone, 0.2) if lit else Color(Palette.CHARCOAL, 0.9), 3 if lit else 2, key.hash()), rect)
	var cap := Keycap.size_of(key, CAP)
	Keycap.draw(self, rect.position + Vector2(6.0 + cap.x * 0.5, 6.0 + CAP * 0.5), key, ScrapFrame.wear(tone, key.hash()), CAP)
	var icon_rect := Rect2(Vector2(rect.end.x - 6.0 - ICON, rect.position.y + 4.0), Vector2(ICON, ICON))
	if key == arc_key():
		_meter_arc(icon_rect, tone, entry["icon"])
	elif entry["icon"] != "":
		draw_texture_rect(Icons.texture(entry["icon"]), icon_rect, false, Icons.tint(entry["icon"], tone))
	elif ARROWS.has(key):
		_arrow(icon_rect.get_center(), ARROWS[key], tone)
	if entry["extra"] == "":
		_words(entry["label"], _label_rect(rect, rect.size.x), tone)
		return
	if rect.size.x < 2.0 * U:
		draw_texture_rect(Icons.texture(entry["extra_icon"]), icon_rect, false, Icons.tint(entry["extra_icon"], tone))
		var below := _label_rect(rect, rect.size.x)
		var line := Vector2(below.size.x, below.size.y * 0.5)
		_words(entry["label"], Rect2(below.position, line), Color(Palette.SAND, 0.8))
		_words(entry["extra"], Rect2(below.position + Vector2(0.0, line.y), line), tone, HORIZONTAL_ALIGNMENT_CENTER, EXTRA_FONT)
		return
	var half := rect.size.x * 0.5
	_words(entry["label"], _label_rect(rect, half), Color(Palette.SAND, 0.8))
	var side := Rect2(rect.position + Vector2(half, 0.0), Vector2(half, rect.size.y))
	draw_texture_rect(Icons.texture(entry["extra_icon"]), Rect2(side.get_center() - Vector2(ICON * 0.5, 30.0), Vector2(ICON, ICON)), false,
		Icons.tint(entry["extra_icon"], tone))
	_words(entry["extra"], _label_rect(side, half), tone)


func _meter_arc(spot: Rect2, tone: Color, icon: String) -> void:
	var centre := spot.get_center() + Vector2(0.0, 2.0)
	var span := AimReticle.meter_span(1.0)
	draw_arc(centre, ARC_R, span.x, span.y, 32, AimReticle.meter_fill_color(tone), ARC_W)
	if icon != "":
		var inner := Rect2(centre - Vector2(ARC_R, ARC_R) * 0.6, Vector2(ARC_R, ARC_R) * 1.2)
		draw_texture_rect(Icons.texture(icon), inner, false, Icons.tint(icon, tone))
	else:
		draw_arc(centre, AimReticle.RING * ARC_R / AimReticle.meter_radius(), 0.0, TAU, 24, tone, 2.0)


static func arc_key() -> String:
	return Bindings.glyph("ultimate")


func _label_rect(tile: Rect2, width: float) -> Rect2:
	var top := CAP + 12.0
	return Rect2(tile.position + Vector2(2.0, top), Vector2(width - 4.0, tile.size.y - top - 4.0))


func _mouse() -> void:
	var left := _board_width() + MOUSE_GAP + MOUSE_LEFT_LABEL
	var body := Rect2(Vector2(left, (size.y - MOUSE_SIZE.y) * 0.5 - 10.0), MOUSE_SIZE)
	var split := body.position.y + MOUSE_SIZE.y * 0.42
	var body_box := _plate(Color(Palette.SAND, 0.8), Color(Palette.CHARCOAL, 0.9), 2)
	body_box.set_corner_radius_all(int(MOUSE_SIZE.x * 0.5))
	body_box.corner_detail = 12
	draw_style_box(body_box, body)
	for i in MOUSE_KEYS.size():
		var key: String = MOUSE_KEYS[i]
		if not _keys.has(key):
			continue
		var entry: Dictionary = _keys[key]
		var tone: Color = entry["tone"]
		var half := Rect2(Vector2(body.position.x + i * MOUSE_SIZE.x * 0.5, body.position.y), Vector2(MOUSE_SIZE.x * 0.5, split - body.position.y)).grow(-5.0)
		var box := _plate(tone, Color(tone, 0.22) if entry["lit"] else Color(Palette.CHARCOAL, 0.9), 3 if entry["lit"] else 2)
		box.set_corner_radius_all(UiTokens.RADIUS)
		box.corner_detail = 12
		if i == 0:
			box.corner_radius_top_left = int(MOUSE_SIZE.x * 0.45)
		else:
			box.corner_radius_top_right = int(MOUSE_SIZE.x * 0.45)
		draw_style_box(box, half)
		if entry["icon"] != "":
			draw_texture_rect(Icons.texture(entry["icon"]), Rect2(half.get_center() - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON)), false,
				Icons.tint(entry["icon"], tone))
		ScrapFrame.stamp(self, entry["label"], UiFonts.bold(), FONT, tone, Color(tone, 0.55), key.hash(),
			Vector2(body.position.x - 6.0 if i == 0 else body.end.x + 6.0, half.get_center().y + 4.0),
			HORIZONTAL_ALIGNMENT_RIGHT if i == 0 else HORIZONTAL_ALIGNMENT_LEFT)
	draw_line(Vector2(body.position.x + 6.0, split), Vector2(body.end.x - 6.0, split), Color(Palette.SAND, 0.5), 2.0)
	ScrapFrame.draw_tape(get_canvas_item(), Vector2(body.get_center().x, body.end.y - 46.0), -0.32, Vector2(MOUSE_SIZE.x * 0.7, 16.0))
	if _keys.has(LOOK):
		var mid := Vector2(body.get_center().x, body.end.y + 16.0)
		for dir in [Vector2.LEFT, Vector2.RIGHT]:
			_arrow(mid + dir * 42.0, dir, Color(Palette.SAND, 0.8))
		_words(_keys[LOOK]["label"], Rect2(mid - Vector2(40.0, 10.0), Vector2(80.0, 24.0)), Color(Palette.SAND, 0.8))


func _words(text: String, rect: Rect2, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER, font_size := FONT) -> void:
	if text == "":
		return
	var font := UiFonts.bold()
	var line := font.get_height(font_size)
	var lines := 1 if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= rect.size.x else 2
	var top := rect.position.y + (rect.size.y - line * lines) * 0.5 + font.get_ascent(font_size)
	draw_multiline_string(font, Vector2(rect.position.x, top), text, align, rect.size.x, font_size, 2, color)


func _arrow(at: Vector2, dir: Vector2, color: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([at + dir * 9.0, at - dir * 6.0 + side * 8.0, at - dir * 6.0 - side * 8.0]), color)


static func _scrap(edge: Color, fill: Color, width: int, serial: int) -> StyleBox:
	var box = ScrapFrame.plate(edge, serial, fill, width)
	box.rivets = false
	return box


static func _plate(edge: Color, fill: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.border_width_bottom = width + 2
	box.set_corner_radius_all(UiTokens.RADIUS)
	box.corner_detail = 3
	return box
