extends Control

const Icons := preload("res://src/ui/icons.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const StageModifier := preload("res://src/world/events/stage_modifier.gd")

# The stage card: the stage's icon and name, faded in over the launch and out after the
# drop, with the stage's modifier (SI3) on a second line when it has one. It only draws: it takes no input and never pauses anything, so the ball keeps
# every bit of the speed it launched with (principle 1).
#
# The second line is the Foreman's memo (StageModifier.memo), so it sits on an old-works plate (LEGIBILITY
# section 14.3): cast glass, no fastener, no lean, the uranium-green seam along its foot, the works' face.
# A cursed run's line is the crew's (a keeper's gamble come due), so it stays in the card's own words above
# the plate, a mark laid on the works' card. The card fades in a straight line.

const ICON := 44.0
const FONT := UiTokens.HEADING
const LINE_FONT := UiTokens.BODY
const LINE_GAP := 8.0
const GAP := 14.0
const FADE_IN := 0.25
const HOLD := 1.4
const FADE_OUT := 0.4
# The name and its line are read mid-drop, over the yard (PF-08 found them too faint): the words
# are lightened toward bone and wear a heavy outline, so they keep MIN_CONTRAST against the
# outline's ink wherever the card lands. LEGIBILITY.md sets no number for a line in play, so the
# floor is WCAG's 7:1 for large text, held by tests/run_opening_test.gd.
const BONE := Color("f3ecdc")
const LIGHTEN := 0.5
const TEXT_OUTLINE := 10
const MIN_CONTRAST := 7.0
# The memo plate: its words in the old works' face, padded clear of the edge and the seam, and how the
# card's line joins its parts (StageModifier.card_line).
const MEMO_PAD := Vector2(UiTokens.GAP_L, UiTokens.GAP_S)
const SEAM_ROOM := float(UiTokens.GAP_S)
const SEPARATOR := "  /  "
const SERIAL := 47

var icon_id := ""
var title := ""
var line := ""
var color := Color.WHITE
var _tween: Tween
var _memo_box: StyleBox = ScrapFrame.hand_plate(UiTokens.Hand.OLD_WORKS, SERIAL)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0


# The card's second line in its two voices: "crew", the cursed run's line, and "memo", the Foreman's rest.
static func voices(card_line: String) -> Dictionary:
	var crew := PackedStringArray()
	var memo := PackedStringArray()
	for part in card_line.split(SEPARATOR, false):
		var cursed: bool = part == StageModifier.CURSE.line or part.begins_with(String(StageModifier.CURSE.word) + ":")
		if cursed:
			crew.append(part)
		else:
			memo.append(part)
	return {"crew": SEPARATOR.join(crew), "memo": SEPARATOR.join(memo)}


func memo_text() -> String:
	return String(voices(line)["memo"])


# The memo plate's style box: the old works' hand, never the Kindness's seam.
func memo_box() -> StyleBox:
	return _memo_box


# The memo plate's size: its words in the works' face, the pad round them and the seam's room under them.
func memo_size() -> Vector2:
	var memo := memo_text()
	if memo.is_empty():
		return Vector2.ZERO
	var font := UiFonts.face(UiTokens.Hand.OLD_WORKS)
	return Vector2(font.get_string_size(memo, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FONT).x, font.get_height(LINE_FONT)) \
		+ MEMO_PAD * 2.0 + Vector2(0.0, SEAM_ROOM)


# The colour the card's words are drawn in: the stage's tint lightened toward bone.
static func word_colour(tint: Color) -> Color:
	return Color(tint.lerp(BONE, LIGHTEN), 1.0)


# WCAG contrast ratio of two opaque colours.
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var out := 0.0
	var weights := [0.2126, 0.7152, 0.0722]
	var channels := [c.r, c.g, c.b]
	for i in 3:
		var v: float = channels[i]
		out += weights[i] * (v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4))
	return out


func extent() -> Vector2:
	var w := ICON + GAP + UiDraw.width(title, FONT)
	if line.is_empty():
		return Vector2(w, ICON + 8.0)
	var crew := String(voices(line)["crew"])
	var h := ICON + 8.0
	if not crew.is_empty():
		w = maxf(w, UiDraw.width(crew, LINE_FONT))
		h += LINE_GAP + LINE_FONT
	var memo := memo_size()
	if memo != Vector2.ZERO:
		w = maxf(w, memo.x)
		h += LINE_GAP + memo.y
	return Vector2(w, h)


func showing() -> bool:
	return visible


func show_card(icon: String, text: String, tint: Color, subline := "") -> void:
	icon_id = icon
	title = text
	line = subline
	color = tint
	custom_minimum_size = extent()
	visible = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(UiTokens.hand(UiTokens.Hand.OLD_WORKS).trans)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN * (1.0 - modulate.a))
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(func(): visible = false)
	queue_redraw()


# Keeps a card that is already up on screen for another full hold.
func extend() -> void:
	if visible:
		show_card(icon_id, title, color, line)


func drawn_words() -> PackedStringArray:
	if not visible:
		return PackedStringArray()
	return PackedStringArray([title]) if line.is_empty() else PackedStringArray([title, line])


func _draw() -> void:
	var w := ICON + GAP + UiDraw.width(title, FONT)
	var x := (size.x - w) * 0.5
	var mid := (ICON + 8.0) * 0.5 if not line.is_empty() else size.y * 0.5
	draw_texture_rect(Icons.texture(icon_id), Rect2(Vector2(x, mid - ICON * 0.5), Vector2(ICON, ICON)), false, Icons.tint(icon_id, color))
	_words(x + ICON + GAP, mid, title, FONT)
	var rule_y := ICON + 7.0 if not line.is_empty() else size.y - 1.0
	draw_line(Vector2(x, rule_y), Vector2(x + w, rule_y), Color(color, 0.6), 2.0)
	if line.is_empty():
		return
	var y := ICON + 8.0 + LINE_GAP
	var crew := String(voices(line)["crew"])
	if not crew.is_empty():
		_words((size.x - UiDraw.width(crew, LINE_FONT)) * 0.5, y + LINE_FONT * 0.5, crew, LINE_FONT)
		y += LINE_FONT + LINE_GAP
	var memo := memo_size()
	if memo == Vector2.ZERO:
		return
	var plate := Rect2(Vector2((size.x - memo.x) * 0.5, y), memo)
	draw_style_box(_memo_box, plate)
	var font := UiFonts.face(UiTokens.Hand.OLD_WORKS)
	draw_string(font, plate.position + Vector2(MEMO_PAD.x, MEMO_PAD.y + font.get_ascent(LINE_FONT)), memo_text(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FONT, UiTokens.HANDS[UiTokens.Hand.OLD_WORKS].ink)


# One line of the card's words: left edge x, middle y.
func _words(x: float, y: float, value: String, font_size: int) -> void:
	var font := UiFonts.bold()
	var at := Vector2(x, y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string_outline(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_OUTLINE, UiDraw.OUTLINE)
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, word_colour(color))
