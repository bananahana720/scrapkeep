extends Control

const UiTokens := preload("res://src/core/ui_tokens.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const ScreenRegions := preload("res://src/core/screen_regions.gd")
const FlashGuard := preload("res://src/core/flash_guard.gd")
const Comfort := preload("res://src/core/comfort.gd")


const FONT := UiTokens.HEADING
const ROW := 40.0
const RISE := float(UiTokens.GAP_M)
const SLAM := 0.09
const SWELL := 1.22
const FADE := 0.25
const OUTLINE := 6
const WIDTH := 480.0
const PLATE_PAD_X := 10.0
const PLATE_PAD_Y := 4.0
const ACCENT_W := 4.0

const MAKER_QUIPS := {
	"louvre": "Fleet Surplus. Vents hot, bills twice.",
	"rivet": "Keeper Forge. Bolted tight, zero paperwork.",
	"skirt": "Spillway Foundry. Wider splash, wetter boots.",
	"sight": "Old Works Optics. Approved at distance.",
	"fin": "Roost Alloy. Built for bad corners.",
	"drum": "Winch Works. Pulls first, asks later.",
	"collar": "Keeper Surplus. Snaps back on beat.",
	"spool": "Highdraft Rigging. Extra line, no net.",
	"tank": "Dig Smeltery. Heavy drop, louder floor.",
	"bumper": "Redjaw Plate. Polite nod, bent steel.",
	"tile": "Moss Stores. Packed an extra weld.",
	"bracket": "Switchboard Surplus. Hotter charge, warmer pocket.",
}

const MAKER_SLOGANS := {
	"fleet": "Counted twice, rounded up.",
	"keeper": "Bolted by hand, runs loud.",
	"works": "Aligned for frictionless compliance.",
	"rogue": "Unscheduled output, zero supervisor.",
	"patch": "Warranty voided in chalk.",
}

var lines: Array = []


static func quip_for(words: String) -> String:
	var lower := words.to_lower()
	for noun in MAKER_QUIPS:
		if lower.contains(noun):
			return String(MAKER_QUIPS[noun])
	return ""


static func maker_slogan(maker: String) -> String:
	return String(MAKER_SLOGANS.get(maker.to_lower(), ""))


func _init() -> void:
	name = "PickupLines"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_line(words: String, tint: Color, row: int, life: float) -> void:
	for line in lines:
		if int(line[2]) == row:
			lines.erase(line)
			break
	lines.append([words, tint, row, 0.0, life])
	queue_redraw()


func layout(size_now: Vector2, rows: int) -> void:
	var bottom := ScreenRegions.rect("bottom", size_now)
	size = Vector2(WIDTH, ROW * rows + RISE)
	position = Vector2(float(UiTokens.GAP_L), bottom.position.y - size.y - float(UiTokens.GAP_XS))


func step(delta: float) -> void:
	for line in lines:
		line[3] = float(line[3]) + delta
	lines = lines.filter(func(line): return float(line[3]) < float(line[4]))
	queue_redraw()


func showing() -> bool:
	return not lines.is_empty()


func rect() -> Rect2:
	if not visible or not showing():
		return Rect2()
	var font := UiFonts.bold()
	var wide := 0.0
	for line in lines:
		wide = maxf(wide, font.get_string_size(String(line[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT).x * SWELL)
	return Rect2(position, Vector2(maxf(size.x, wide + OUTLINE), size.y))


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	if visible:
		for line in lines:
			out.append(String(line[0]))
	return out


func _draw() -> void:
	var font := UiFonts.bold()
	for line in lines:
		var age: float = line[3]
		var life: float = line[4]
		var t := clampf(age / life, 0.0, 1.0)
		var leave := clampf((age - (life - FADE)) / FADE, 0.0, 1.0)
		var alpha := 1.0 - leave
		var scale_now := 1.0 if Comfort.reduced_motion or age >= SLAM else lerpf(SWELL, 1.0, age / SLAM)
		var lift := 0.0 if Comfort.reduced_motion else RISE * t
		var base := size.y - ROW * int(line[2]) - lift - font.get_descent(FONT)
		var px := int(round(FONT * scale_now))
		var words := String(line[0])
		var text_size := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var at := Vector2(ACCENT_W + PLATE_PAD_X, base)
		var tint: Color = line[1]
		var box := Rect2(
			Vector2(0.0, base - font.get_ascent(px) - PLATE_PAD_Y),
			Vector2(minf(size.x, text_size.x + ACCENT_W + PLATE_PAD_X * 2.0), font.get_height(px) + PLATE_PAD_Y * 2.0)
		)
		draw_rect(box, Color(UiTokens.INK, alpha * 0.84))
		draw_rect(Rect2(box.position, Vector2(ACCENT_W, box.size.y)), Color(tint, FlashGuard.info(alpha)))
		draw_rect(box, Color(UiTokens.INK, alpha), false, 2.0)
		draw_string_outline(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, px, OUTLINE, Color(UiTokens.INK, alpha))
		draw_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(tint, FlashGuard.info(alpha)))
