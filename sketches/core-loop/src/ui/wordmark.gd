extends RefCounted

# The game's name as drawn art (W1-47): gig-poster letters in thick ink with a halftone drop,
# drawn by tools/wordmark/generate_wordmark.py into one SVG. The title, the boot card and the
# opening all show this one picture, so the name looks the same everywhere it is stamped.

const PATH := "res://assets/ui/wordmark.svg"
const NAME := "Scrapkeep"
# Width over height of the drawing, so a caller sizes it by height alone.
const ASPECT := 900.0 / 240.0
# On the title the name thumps on the music's bar (title_stage.gd thump()), like a press stamping the poster: it
# swells from its middle by up to THUMP of its size and settles.
const THUMP := 0.035

static var _texture: Texture2D


static func texture() -> Texture2D:
	if _texture == null:
		_texture = load(PATH) as Texture2D if ResourceLoader.exists(PATH) else null
	return _texture


# A picture of the name height px tall that a screen reader reads as the name.
static func view(height: float) -> TextureRect:
	var rect := _picture()
	rect.custom_minimum_size = Vector2(height * ASPECT, height)
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.accessibility_name = NAME
	return rect


# The picture laid over a label that keeps the word itself (for screen readers) and draws no glyphs:
# it fills the label, so whatever sizes, hides or stamps the label moves the name with it.
static func dress(label: Label) -> TextureRect:
	var rect := _picture()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_child(rect)
	return rect


# amount: 1 on the bar line, falling to 0; 0 leaves the name at rest.
static func thump(rect: TextureRect, amount: float) -> void:
	rect.pivot_offset = rect.size * 0.5
	rect.scale = Vector2.ONE * (1.0 + THUMP * clampf(amount, 0.0, 1.0))


static func _picture() -> TextureRect:
	var rect := TextureRect.new()
	rect.name = "Wordmark"
	rect.texture = texture()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
