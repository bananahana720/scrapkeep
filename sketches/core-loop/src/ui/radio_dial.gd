extends Control

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const RadioTakes := preload("res://src/core/radio_takes.gd")
const Radio := preload("res://src/core/radio.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")
const Keycap := preload("res://src/ui/keycap.gd")

# The pilot radio on the HUD, in the top band's right corner (screen_regions.gd): a knob whose
# needle points at the station, the call sign in the station's colour, the track on air, and
# four meter bars that are the band's own layers (drums, bass, keys, lead) as the run drives
# them, so the dial shows the music following speed and combo. A change swells it for SWELL
# seconds with the station's name and blurb and stamps a drawn KSSHT on the turn (the tone
# bible's comic-book pillar); then it settles back to a chip. Off draws the knob dark and the
# bars flat. radio_deck.gd owns the state; this only reads deck.reading().
# While the radio's first-meet tip is up (field_tips.gd calls teach), the dial hangs its own keys
# under the plate for TEACH seconds: back, next and skip, each cap with a drawn arrow, read from
# the InputMap so a rebinding shows. A toast cannot draw a keycap; the dial can.
# The words are news, not furniture (PF-19: the panel stood up all run, its line past its edge).
# The chip shows its words for PEEK seconds when they change (a run's start, a new signal, a turn)
# and then folds to the knob and the meter bars, which still carry the station and the band. Every
# line it draws is cut to the plate's width with an ellipsis, so no word runs past its edge.

const CHIP := Vector2(320.0, 46.0)
# Folded: the knob and the meter bars, no words.
const FOLDED := Vector2(84.0, 46.0)
const PEEK := 4.0
const ELLIPSIS := "…"
# Swollen, the plate holds the station's name and its blurb on up to BLURB_LINES lines, wrapped
# at a word: a blurb stopped mid-word read as broken (w37 film 012, "played however th"). The
# plate still ends inside the top band (screen_regions.gd) at 900 px high.
const SWOLLEN := Vector2(380.0, 110.0)
const BLURB_LINES := 2
const NAME_Y := 60.0
const BLURB_Y := 80.0
const MARGIN := 18.0
const SWELL := 2.6
const STAMP := 0.5
const WORD := "KSSHT!"
# music_engine.gd's layer indices: kick, bass, keys, lead.
const METER := [3, 5, 0, 6]
const LAYERS := 4
const TEACH := 4.0
const TEACH_KEY_H := 24.0
# [action, fallback glyph, arrow]: the arrow is drawn, -1 back, 1 next, 2 skip (a double arrow).
const TEACH_KEYS := [["cl_radio_prev", "key_comma", -1], ["cl_radio_next", "key_period", 1], ["cl_radio_skip", "key_slash", 2]]

var deck
var _swell := 0.0
var _stamp := 0.0
var _teach := 0.0
var _peek := 0.0
var _said := ""
var _read := {}
var _bars := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = CHIP


func swell() -> void:
	_swell = SWELL
	_stamp = STAMP


func teach() -> void:
	_teach = TEACH


func teaching() -> bool:
	return _teach > 0.0


# How many lines `blurb` takes on the swollen plate, wrapped at a word.
static func blurb_lines(blurb: String) -> int:
	var font := UiFonts.bold()
	return roundi(font.get_multiline_string_size(blurb, HORIZONTAL_ALIGNMENT_LEFT, SWOLLEN.x - 24.0, UiTokens.CAPTION).y / font.get_height(UiTokens.CAPTION))


func swollen() -> bool:
	return _swell > 0.0


# Whether the chip shows its words: swollen, teaching its keys, or inside PEEK of a change.
func says() -> bool:
	return swollen() or teaching() or _peek > 0.0


# The size the chip is headed for: swollen, with its words, or folded to the knob and bars.
func target_size() -> Vector2:
	if swollen():
		return SWOLLEN
	return CHIP if says() else FOLDED


# `text` cut at the end with an ellipsis so it fits `width` at `font_size`; whole when it fits.
static func fit(text: String, width: float, font_size: int) -> String:
	if width <= 0.0:
		return ""
	if UiFonts.width(text, font_size) <= width:
		return text
	var cut := text
	while cut != "" and UiFonts.width(cut.strip_edges(false, true) + ELLIPSIS, font_size) > width:
		cut = cut.left(cut.length() - 1)
	return cut.strip_edges(false, true) + ELLIPSIS if cut != "" else ""


const TINTS := {"AMBER": Palette.AMBER, "COPPER": Palette.COPPER, "SANDSTONE": Palette.SANDSTONE, "LEDGER": Palette.LEDGER,
	"ARC": Palette.ARC, "MINT": Palette.ARC, "BRASS": Palette.BRASS, "SLATE": Palette.SLATE, "RUST": Palette.RUST,
	"VERDIGRIS": Palette.VERDIGRIS, "SAND": Palette.SAND}


static func tint(name: String) -> Color:
	return TINTS.get(name, Palette.ARC)


func _process(delta: float) -> void:
	visible = deck != null and deck._live()
	if not visible:
		return
	_swell = maxf(0.0, _swell - delta)
	_stamp = maxf(0.0, _stamp - delta)
	_teach = maxf(0.0, _teach - delta)
	_peek = maxf(0.0, _peek - delta)
	_read = deck.reading()
	var said := "%s|%s|%s" % [_read.get("call", ""), _read.get("dial", ""), _read.get("line", "")]
	if said != _said:
		_said = said
		_peek = PEEK
	var engine = deck._audio.engine if deck._audio != null else null
	for i in LAYERS:
		var want := 0.0
		if engine != null and not _read.get("off", false):
			want = clampf(float(engine.layer_gain(METER[i])), 0.0, 1.0)
			# A small kick on each beat so the bars breathe with the band.
			var beat: int = maxi(1, engine.beat_len())
			want *= 0.75 + 0.25 * (1.0 - float(engine.clock % beat) / beat)
		_bars[i] = move_toward(_bars[i], want, delta * 6.0)
	size = size.lerp(target_size(), clampf(delta * 12.0, 0.0, 1.0))
	var screen := get_viewport().get_visible_rect().size
	var top := ScreenRegions.rect("top", screen)
	position = Vector2(screen.x - size.x - MARGIN, top.position.y + 12.0)
	queue_redraw()


func _draw() -> void:
	if _read.is_empty():
		return
	var color := tint(String(_read.get("color", "")))
	var off: bool = _read.get("off", false)
	var edge := Palette.SLATE if off else color
	var plate := Rect2(Vector2.ZERO, size)
	draw_rect(plate, Color(Palette.CHARCOAL, 0.86))
	draw_rect(plate, edge, false, 2.0)
	# The knob, its needle on the station's place round the dial.
	var knob := Vector2(23.0, 23.0)
	draw_circle(knob, 15.0, Palette.CABLE)
	draw_circle(knob, 12.0, Color(0.08, 0.09, 0.09) if off else color.darkened(0.45))
	var stops := Radio.dial()
	var at := float(maxi(0, stops.find(_read.get("station", ""))))
	var angle := lerpf(deg_to_rad(140.0), deg_to_rad(400.0), at / maxf(1.0, stops.size() - 1.0))
	draw_line(knob, knob + Vector2(cos(angle), sin(angle)) * 11.0, Palette.SAND if not off else Palette.SLATE, 2.5)
	var font := UiFonts.bold()
	var x := 46.0
	var meter_w := 4.0 * 7.0
	var line_w := size.x - x - meter_w - 18.0
	# The words draw only once the plate has opened far enough to hold some of them.
	if says() and line_w >= UiFonts.width("MMM", UiTokens.CAPTION):
		var pin_w := UiFonts.width("PIN", UiTokens.CAPTION) + 8.0 if _read.get("pinned", false) else 0.0
		var call := fit(String(_read.get("call", "")), line_w - pin_w, UiTokens.BODY)
		draw_string(font, Vector2(x, 21.0), call, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.BODY, edge)
		var dial_x := x + UiFonts.width(call, UiTokens.BODY) + 8.0
		var dial_words := fit(String(_read.get("dial", "")), x + line_w - pin_w - dial_x, UiTokens.CAPTION)
		if dial_words != "":
			draw_string(font, Vector2(dial_x, 21.0), dial_words, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.CAPTION, UiTokens.quiet())
		draw_string(font, Vector2(x, 39.0), fit(String(_read.get("line", "")), line_w, UiTokens.CAPTION), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.CAPTION, UiTokens.quiet() if off else Palette.SAND)
		if pin_w > 0.0:
			draw_string(font, Vector2(x + line_w - pin_w + 8.0, 21.0), "PIN", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.CAPTION, Palette.BRASS)
	for i in LAYERS:
		var h := 4.0 + _bars[i] * 26.0
		var bx := size.x - meter_w - 10.0 + i * 7.0
		draw_rect(Rect2(bx, 40.0 - h, 5.0, h), Color(color, 0.35 + 0.65 * _bars[i]) if not off else Color(Palette.SLATE, 0.4))
	if swollen() and size.y > 70.0:
		var a := clampf(_swell / 0.4, 0.0, 1.0)
		draw_string(font, Vector2(12.0, NAME_Y), fit(String(_read.get("name", "")), size.x - 24.0, UiTokens.BODY), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.BODY, Color(color, a))
		var blurb := String(RadioTakes.station(String(_read.get("station", ""))).get("blurb", ""))
		draw_multiline_string(font, Vector2(12.0, BLURB_Y), blurb, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, UiTokens.CAPTION, BLURB_LINES, Color(Palette.SAND, 0.75 * a))
	if teaching():
		_draw_keys(color)
	if _stamp > 0.0:
		var s := clampf(_stamp / STAMP * 1.6, 0.0, 1.0)
		draw_set_transform(Vector2(-86.0, 30.0), -0.14, Vector2.ONE * lerpf(1.0, 1.3, s))
		draw_string(font, Vector2(2, 2), WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.LABEL, Color(Palette.CHARCOAL, s))
		draw_string(font, Vector2.ZERO, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.LABEL, Color(Palette.AMBER, s))
		draw_set_transform(Vector2.ZERO)


# The dial's keys under the plate, from its left edge (the notes' Tab cap sits under its right),
# each cap followed by its arrow, fading out over the last half second.
func _draw_keys(color: Color) -> void:
	var a := clampf(_teach / 0.5, 0.0, 1.0)
	var y := size.y + 8.0 + TEACH_KEY_H * 0.5
	var x := 2.0
	for row in TEACH_KEYS:
		var key := Glyphs.of_action(String(row[0]), String(row[1]))
		var cap := Keycap.size_of(key, TEACH_KEY_H)
		Keycap.draw(self, Vector2(x + cap.x * 0.5, y), key, Color(Palette.SAND, a), TEACH_KEY_H)
		x += cap.x + 6.0
		var arrow := 14.0 if int(row[2]) != 2 else 22.0
		_draw_arrow(Vector2(x + arrow * 0.5, y), int(row[2]), Color(color, a))
		x += arrow + 14.0


func _draw_arrow(at: Vector2, kind: int, color: Color) -> void:
	var h := 6.0
	var heads := [at] if kind != 2 else [at + Vector2(-4.0, 0.0), at + Vector2(4.0, 0.0)]
	var dir := -1.0 if kind == -1 else 1.0
	for c in heads:
		draw_colored_polygon(PackedVector2Array([c + Vector2(dir * h, 0.0), c + Vector2(-dir * h * 0.6, -h), c + Vector2(-dir * h * 0.6, h)]), color)
