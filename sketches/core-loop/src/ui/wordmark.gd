extends RefCounted

# The game's name as drawn art (W1-47): gig-poster letters in thick ink with a halftone drop,
# drawn by tools/wordmark/generate_wordmark.py into one SVG. The title, the boot card and the
# opening all show this one picture, so the name looks the same everywhere it is stamped.

const PATH := "res://assets/ui/wordmark.svg"
const NAME := "Scrapkeep"
# Width over height of the drawing, so a caller sizes it by height alone.
const ASPECT := 900.0 / 240.0

static var _texture: Texture2D


static func texture() -> Texture2D:
	if _texture == null:
		_texture = load(PATH) as Texture2D if ResourceLoader.exists(PATH) else null
	return _texture


# A picture of the name height px tall that a screen reader reads as the name.
static func view(height: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = "Wordmark"
	rect.texture = texture()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(height * ASPECT, height)
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.accessibility_name = NAME
	return rect
