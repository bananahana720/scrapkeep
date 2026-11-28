extends Control

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const ClassDef := preload("res://src/core/class_def.gd")


const SIDE := 68.0
const TAG_H := 20.0
const TAG_FONT := UiTokens.CAPTION
const EDGE := 3.0
const KEYLINE := 1.5
const SYLLABLES := 6.5
const HOP := 4.0
const TILT := 0.07
const BARS := 3
const POP_IN := 0.16
const TAG_INKS := [UiTokens.TAG_INK, Palette.LEDGER_CREAM]
const TAG_TILT := -0.035

const CALLERS := {
	"moss": {"hands": "hatch", "icon": "", "color": Palette.SANDSTONE},
	"pump_crew": {"hands": "keeper", "icon": "obj_fabricator", "color": Palette.COPPER},
	"flume_crew": {"hands": "keeper", "icon": "obj_event", "color": Palette.STEEL},
	"signal_crew": {"hands": "keeper", "icon": "obj_beacon", "color": Palette.LEDGER_CREAM},
	"dig_crew": {"hands": "keeper", "icon": "obj_vault", "color": Palette.COPPER},
	"caisson_crew": {"hands": "keeper", "icon": "res_heft", "color": Palette.STEEL},
	"roost_crew": {"hands": "keeper", "icon": "obj_gate", "color": Palette.SANDSTONE},
	"crown_watch": {"hands": "keeper", "icon": "res_difficulty", "color": Palette.LEDGER_CREAM},
	"unsigned": {"hands": "keeper", "icon": "cls_patch", "color": Palette.STEEL},
	"patch": {"hands": "keeper", "icon": "cls_patch", "color": Palette.TURQUOISE},
	"brindle": {"hands": "fleet", "icon": "fac_fleet", "color": Palette.BRASS},
	"mind": {"hands": "works", "icon": "fac_mind", "color": Palette.ANCIENT},
}

static var reduced_motion := false

var pilots: Array = []
var speaker := ""
var caller_name := ""
var _look := {}
var _voice := 0.0
var _framed: Array = []
var _drawn: Array = []
var _age := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIDE, SIDE)
	size = custom_minimum_size
	visible = false


func look_of(id: String) -> Dictionary:
	if CALLERS.has(id):
		return CALLERS[id]
	for def in pilots:
		if def != null and (String(def.id) == id or String(def.display_name).to_lower() == id):
			return {"hands": "keeper", "icon": Icons.class_icon_id(String(def.id)), "color": ClassDef.screen_color(def.color)}
	return {}


func present(id: String, shown_name: String, voice_s := 0.0) -> bool:
	_look = look_of(id)
	speaker = id if not _look.is_empty() else ""
	caller_name = shown_name
	_voice = maxf(0.0, voice_s)
	_age = 0.0
	visible = not _look.is_empty()
	_framed = _hand_plates(_look["color"]) if _frame_hand() >= 0 else []
	set_process(visible)
	queue_redraw()
	return visible


func clear() -> void:
	speaker = ""
	_look = {}
	_framed = []
	visible = false
	set_process(false)


func quiet() -> void:
	_voice = 0.0
	set_process(false)
	queue_redraw()


func tint() -> Color:
	return _look.get("color", Palette.SAND)


func talking() -> bool:
	return visible and _age < _voice


func hands() -> String:
	return String(_look.get("hands", ""))


func drawn_frames() -> Array:
	return _drawn.duplicate()


func _process(delta: float) -> void:
	_age += delta
	if talking() or _age <= POP_IN + delta:
		queue_redraw()


func _draw() -> void:
	_drawn = []
	if _look.is_empty():
		return
	var color: Color = _look["color"]
	var beat := _age * SYLLABLES * TAU
	var live := talking() and not reduced_motion
	var hop := -absf(sin(beat * 0.5)) * HOP if live else 0.0
	var tilt := sin(beat * 0.5 + 0.6) * TILT if live else 0.0
	var pop := 1.0 if reduced_motion else minf(1.0, _age / POP_IN)
	pop = 1.0 + 0.18 * sin(pop * PI) if pop < 1.0 else 1.0
	var centre := Vector2(SIDE, SIDE) * 0.5
	draw_set_transform(centre + Vector2(0.0, hop), tilt, Vector2(pop, pop))
	var framed := not _framed.is_empty()
	var plate := PackedVector2Array() if framed else _plate(String(_look["hands"]))
	if framed:
		for box in _framed:
			_put_frame(box)
	else:
		draw_colored_polygon(plate, Color(Palette.CHARCOAL, 0.96))
	if _look["hands"] == "hatch":
		_draw_hatch(color, live, beat)
	else:
		var icon := String(_look["icon"])
		var mark := SIDE * 0.56
		draw_texture_rect(Icons.texture(icon), Rect2(Vector2(-mark, -mark) * 0.5, Vector2(mark, mark)), false, Icons.tint(icon, color))
		if _look["hands"] == "works":
			var half := SIDE * 0.5 - EDGE
			for i in 7:
				var y := -half + (i + 0.5) * (2.0 * half / 7.0)
				var reach := half - absf(y) * 0.55
				draw_line(Vector2(-reach, y), Vector2(reach, y), Color(color, 0.14), 2.0)
			if live:
				var sweep := fposmod(_age * 1.4, 1.0) * 2.0 * half - half
				draw_line(Vector2(-half + absf(sweep) * 0.55, sweep), Vector2(half - absf(sweep) * 0.55, sweep), Color(color, 0.6), 2.0)
	if not framed:
		var closed := plate.duplicate()
		closed.append(closed[0])
		draw_polyline(closed, Palette.CHARCOAL, EDGE + KEYLINE * 2.0)
		draw_polyline(closed, color, EDGE)
	draw_set_transform(Vector2.ZERO)
	_draw_tag(color, live, beat)


func _put_frame(box: StyleBox) -> void:
	draw_style_box(box, Rect2(-Vector2(SIDE, SIDE) * 0.5, Vector2(SIDE, SIDE)))
	_drawn.append(box)


func _frame_hand() -> int:
	match hands():
		"keeper":
			return UiTokens.Hand.KEEPER
		"fleet":
			return UiTokens.Hand.FLEET
	return -1


func _hand_plates(color: Color) -> Array:
	var which := _frame_hand()
	var serial := speaker.hash()
	var under = ScrapFrame.hand_plate(which, serial)
	under.border_color = Palette.CHARCOAL
	under.border_width = EDGE + KEYLINE * 2.0
	under.rivets = false
	under.halftone = false
	under.stamped = false
	var edge = ScrapFrame.hand_plate(which, serial)
	edge.border_color = color
	edge.border_width = EDGE
	edge.bg_color = Color(edge.bg_color, 0.0)
	return [under, edge]


func _plate(whose: String) -> PackedVector2Array:
	var h := SIDE * 0.5
	var out := PackedVector2Array()
	match whose:
		"works":
			var nose := h * 0.55
			out = PackedVector2Array([Vector2(-h + nose, -h), Vector2(h - nose, -h), Vector2(h, 0.0), Vector2(h - nose, h), Vector2(-h + nose, h), Vector2(-h, 0.0)])
		_:
			var r := 12.0
			for corner in [[Vector2(h - r, -h + r), -PI * 0.5], [Vector2(h - r, h - r), 0.0], [Vector2(-h + r, h - r), PI * 0.5], [Vector2(-h + r, -h + r), PI]]:
				for i in 5:
					var a: float = float(corner[1]) + PI * 0.5 * i / 4.0
					out.append(corner[0] + Vector2(cos(a), sin(a)) * r)
	return out


func _draw_hatch(color: Color, live: bool, beat: float) -> void:
	var w := SIDE * 0.74
	var open := 15.0 + (absf(sin(beat * 0.5)) * 6.0 if live else 0.0)
	var lip := 9.0
	draw_rect(Rect2(-w * 0.5, lip - open, w, open), Color.BLACK)
	draw_rect(Rect2(-w * 0.5, lip - open, w, open), Color(color, 0.5), false, 2.0)
	draw_line(Vector2(-w * 0.5 - 3.0, lip - open), Vector2(w * 0.5 + 3.0, lip - open), color, 4.0)
	draw_line(Vector2(-w * 0.5 - 5.0, lip), Vector2(w * 0.5 + 5.0, lip), color, 5.0)
	for side in [-1.0, 1.0]:
		var at := Vector2(side * w * 0.24, lip + 1.0 + (sin(beat * 0.5 + side) * 1.5 if live else 0.0))
		var palm := PackedVector2Array()
		for i in 12:
			var a := TAU * i / 12.0
			palm.append(at + Vector2(cos(a) * 9.0, sin(a) * 6.5))
		draw_colored_polygon(palm, Palette.SANDSTONE)
		palm.append(palm[0])
		draw_polyline(palm, Palette.CHARCOAL, 2.0)
		for finger in 3:
			var x := at.x + (finger - 1) * 5.0
			draw_line(Vector2(x, at.y + 2.0), Vector2(x, at.y + 10.0), Palette.CHARCOAL, 6.0)
			draw_line(Vector2(x, at.y + 2.0), Vector2(x, at.y + 9.0), Palette.SANDSTONE, 3.5)


func _draw_tag(color: Color, live: bool, beat: float) -> void:
	if caller_name == "":
		return
	var font := UiFonts.bold()
	var words := caller_name.to_upper()
	var text_w := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT).x
	var bars_w := BARS * 5.0 + 4.0
	var w := text_w + bars_w + 16.0
	var at := Vector2(-4.0, -TAG_H * 0.55)
	var ink := tag_ink(color)
	draw_set_transform(at, 0.0 if reduced_motion else TAG_TILT, Vector2.ONE)
	draw_rect(Rect2(Vector2(2.0, 2.0), Vector2(w, TAG_H)), Color(Palette.CHARCOAL, 0.9))
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, TAG_H)).grow(KEYLINE), Palette.CHARCOAL)
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, TAG_H)), color)
	draw_string(font, Vector2(7.0, TAG_H - 5.5), words, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT, ink)
	for i in BARS:
		var level := 0.35 + 0.65 * absf(sin(beat * 0.5 + i * 1.3)) if live else 0.35
		var bar_h := (TAG_H - 8.0) * level
		draw_rect(Rect2(Vector2(text_w + 12.0 + i * 5.0, TAG_H - 4.0 - bar_h), Vector2(3.0, bar_h)), ink)
	draw_set_transform(Vector2.ZERO)


static func tag_ink(color: Color) -> Color:
	var best: Color = TAG_INKS[0]
	for ink in TAG_INKS:
		if UiTokens.contrast(ink, color) > UiTokens.contrast(best, color):
			best = ink
	return best
