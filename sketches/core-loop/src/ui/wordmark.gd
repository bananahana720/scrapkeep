extends RefCounted


const PATH := "res://assets/ui/wordmark.svg"
const NAME := "Scrapkeep"
const ASPECT := 900.0 / 240.0
const THUMP := 0.035

static var _texture: Texture2D


static func texture() -> Texture2D:
	if _texture == null:
		_texture = load(PATH) as Texture2D if ResourceLoader.exists(PATH) else null
	return _texture


static func view(height: float) -> TextureRect:
	var rect := _picture()
	rect.custom_minimum_size = Vector2(height * ASPECT, height)
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.accessibility_name = NAME
	return rect


static func dress(label: Label) -> TextureRect:
	var rect := _picture()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_child(rect)
	return rect


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
