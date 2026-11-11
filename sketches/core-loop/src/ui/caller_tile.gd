extends Control

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")

# Who is on the line (Andrew, 9 November 2026: callers pop up in the HUD and talk, cute). A
# small plate beside the speech bubble (moss_bubble.gd) with the caller's mark and a name tag
# across its head (the tag runs on over the bubble's top edge, a name plate on a dialogue box),
# so one glance says who is talking before a word is read. The plate's shape says whose hands
# the caller is, the colour says which of them:
#
#   keeper  a rounded scrap plate: the site crews in their site's colour, a freed pilot in the
#           pilot's own colour with the pilot's emblem
#   hatch   Moss, who is never seen (DESIGN-V2 sections 12 and 15): the slot of his hatch and
#           his two mitts on its lip
#   fleet   a requisition tag with clipped corners in the Fleet's hazard red
#   works   the old works: a hard-cornered lozenge in the ancients' green, scanned
#
# While the caller's voice lasts the plate babbles: it hops and tilts on the syllables and the
# three bars by the name move. Reduced motion keeps it still. One call, present(); the bubble
# owns where the plate sits and when it goes.

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
# A tag colour darker than this takes light words.
const INK_FLOOR := 0.4

# Callers who are not pilots: whose hands, the mark and the colour. A pilot is found by class id.
const CALLERS := {
	"moss": {"hands": "hatch", "icon": "", "color": Palette.SANDSTONE},
	"pump_crew": {"hands": "keeper", "icon": "obj_fabricator", "color": Palette.COPPER},
	"flume_crew": {"hands": "keeper", "icon": "obj_event", "color": Palette.ARC},
	"signal_crew": {"hands": "keeper", "icon": "obj_beacon", "color": Palette.BRASS},
	"brindle": {"hands": "fleet", "icon": "fac_fleet", "color": Palette.HAZARD},
	"mind": {"hands": "works", "icon": "fac_mind", "color": Palette.ANCIENT},
}

# Reduced motion (the bubble keeps it current with its own): the plate stands still.
static var reduced_motion := false

# The roster's class rows, so a pilot's plate wears the pilot's colour and emblem.
var pilots: Array = []
var speaker := ""
var caller_name := ""
var _look := {}
var _voice := 0.0
var _age := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIDE, SIDE)
	size = custom_minimum_size
	visible = false


# The look of a caller: {hands, icon, color}, empty for one this plate cannot draw (the bubble
# then says the name in its words, as before).
func look_of(id: String) -> Dictionary:
	if CALLERS.has(id):
		return CALLERS[id]
	for def in pilots:
		# A pilot is named by class id or by the name they answer to ("sable").
		if def != null and (String(def.id) == id or String(def.display_name).to_lower() == id):
			return {"hands": "keeper", "icon": Icons.class_icon_id(String(def.id)), "color": def.color}
	return {}


# The caller comes up: who, the name on the tag, and the seconds the voice lasts. False for a
# caller with no look; the plate then stays down.
func present(id: String, shown_name: String, voice_s := 0.0) -> bool:
	_look = look_of(id)
	speaker = id if not _look.is_empty() else ""
	caller_name = shown_name
	_voice = maxf(0.0, voice_s)
	_age = 0.0
	visible = not _look.is_empty()
	set_process(visible)
	queue_redraw()
	return visible


func clear() -> void:
	speaker = ""
	_look = {}
	visible = false
	set_process(false)


# The voice was cut short (a fight hushes a call): the plate stands still until it goes.
func quiet() -> void:
	_voice = 0.0
	set_process(false)
	queue_redraw()


# The caller's colour, for the bubble's edge.
func tint() -> Color:
	return _look.get("color", Palette.SAND)


func talking() -> bool:
	return visible and _age < _voice


func hands() -> String:
	return String(_look.get("hands", ""))


func _process(delta: float) -> void:
	_age += delta
	if talking() or _age <= POP_IN + delta:
		queue_redraw()


func _draw() -> void:
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
	var plate := _plate(String(_look["hands"]))
	draw_colored_polygon(plate, Color(Palette.CHARCOAL, 0.96))
	if _look["hands"] == "hatch":
		_draw_hatch(color, live, beat)
	else:
		var icon := String(_look["icon"])
		var mark := SIDE * 0.56
		draw_texture_rect(Icons.texture(icon), Rect2(Vector2(-mark, -mark) * 0.5, Vector2(mark, mark)), false, Icons.tint(icon, color))
		if _look["hands"] == "works":
			# The old works' picture is scanned: lines cross it and one of them travels.
			var half := SIDE * 0.5 - EDGE
			for i in 7:
				var y := -half + (i + 0.5) * (2.0 * half / 7.0)
				var reach := half - absf(y) * 0.55
				draw_line(Vector2(-reach, y), Vector2(reach, y), Color(color, 0.14), 2.0)
			if live:
				var sweep := fposmod(_age * 1.4, 1.0) * 2.0 * half - half
				draw_line(Vector2(-half + absf(sweep) * 0.55, sweep), Vector2(half - absf(sweep) * 0.55, sweep), Color(color, 0.6), 2.0)
	var closed := plate.duplicate()
	closed.append(closed[0])
	# A charcoal keyline under the coloured edge: copper on the Spillway's sand is no edge at all.
	draw_polyline(closed, Palette.CHARCOAL, EDGE + KEYLINE * 2.0)
	draw_polyline(closed, color, EDGE)
	if _look["hands"] == "fleet":
		# A requisition tag: its punch hole, low so the name tag does not cover it.
		draw_circle(Vector2(-SIDE * 0.5 + 11.0, SIDE * 0.5 - 11.0), 3.5, color)
	draw_set_transform(Vector2.ZERO)
	_draw_tag(color, live, beat)


# The plate's outline about its centre, by whose hands.
func _plate(whose: String) -> PackedVector2Array:
	var h := SIDE * 0.5
	var out := PackedVector2Array()
	match whose:
		"fleet":
			var cut := 14.0
			out = PackedVector2Array([Vector2(-h + cut, -h), Vector2(h, -h), Vector2(h, h - cut), Vector2(h - cut, h), Vector2(-h, h), Vector2(-h, -h + cut)])
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


# Moss: the dark slot of the hatch, its lid lifting as he talks, and two mitts on the lip.
func _draw_hatch(color: Color, live: bool, beat: float) -> void:
	var w := SIDE * 0.74
	var open := 15.0 + (absf(sin(beat * 0.5)) * 6.0 if live else 0.0)
	var lip := 9.0
	draw_rect(Rect2(-w * 0.5, lip - open, w, open), Color.BLACK)
	draw_rect(Rect2(-w * 0.5, lip - open, w, open), Color(color, 0.5), false, 2.0)
	# The lid above the slot and the sill under it.
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


# The name tag across the plate's head, in the caller's colour, and the voice bars after it.
# Its words are charcoal, or ledger white on a colour too dark to carry charcoal (Tarn's rust).
func _draw_tag(color: Color, live: bool, beat: float) -> void:
	if caller_name == "":
		return
	var font := UiFonts.bold()
	var words := caller_name.to_upper()
	var text_w := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT).x
	var bars_w := BARS * 5.0 + 4.0
	var w := text_w + bars_w + 16.0
	var at := Vector2(-4.0, -TAG_H * 0.55)
	var ink: Color = Palette.CHARCOAL if color.get_luminance() > INK_FLOOR else Palette.LEDGER
	draw_set_transform(at, -0.035, Vector2.ONE)
	draw_rect(Rect2(Vector2(2.0, 2.0), Vector2(w, TAG_H)), Color(Palette.CHARCOAL, 0.9))
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, TAG_H)).grow(KEYLINE), Palette.CHARCOAL)
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, TAG_H)), color)
	draw_string(font, Vector2(7.0, TAG_H - 5.5), words, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT, ink)
	for i in BARS:
		var level := 0.35 + 0.65 * absf(sin(beat * 0.5 + i * 1.3)) if live else 0.35
		var bar_h := (TAG_H - 8.0) * level
		draw_rect(Rect2(Vector2(text_w + 12.0 + i * 5.0, TAG_H - 4.0 - bar_h), Vector2(3.0, bar_h)), ink)
	draw_set_transform(Vector2.ZERO)
