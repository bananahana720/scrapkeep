extends Control

const Keycap := preload("res://src/ui/keycap.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")

# Hold to retry: the retry key's cap and a bar that fills over the hold. No words beyond the
# key, so a retry reads as the key the hand is already on.

const KEY_H := float(UiTokens.GAP_XL)
const BAR := Vector2(180.0, 10.0)
const GAP := float(UiTokens.GAP_M)

var fraction := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()
	size = custom_minimum_size


func set_fraction(value: float) -> void:
	fraction = value
	_fit()
	queue_redraw()


func _fit() -> void:
	custom_minimum_size = Vector2(Keycap.size_of(_glyph(), KEY_H).x + GAP + BAR.x, KEY_H)


func drawn_words() -> PackedStringArray:
	return Keycap.words(_glyph()) if fraction > 0.0 else PackedStringArray()


func _draw() -> void:
	if fraction <= 0.0:
		return
	var glyph := _glyph()
	var cap_w := Keycap.size_of(glyph, KEY_H).x
	var left := (size.x - custom_minimum_size.x) * 0.5
	Keycap.draw(self, Vector2(left + cap_w * 0.5, size.y * 0.5), glyph, UiTokens.ACCENT, KEY_H)
	UiDraw.bar(self, Rect2(Vector2(left + cap_w + GAP, (size.y - BAR.y) * 0.5), BAR), fraction, UiTokens.ACCENT)


# The retry key now: R on the keyboard, RB on a pad, or whatever cl_retry is bound to.
func _glyph() -> String:
	return Glyphs.of_action("cl_retry", "key_r")
