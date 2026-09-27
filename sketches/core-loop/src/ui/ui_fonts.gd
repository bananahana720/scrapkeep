extends RefCounted

# The HUD's two faces (VISUAL-LANGUAGE.md section 7): Noto Sans Bold for labels and
# toasts, Noto Sans Mono Bold for numbers so digits do not jitter. They load from the
# system's Noto folder when it has them; otherwise Godot's default font stands in.

const BOLD_PATH := "/usr/share/fonts/noto/NotoSans-Bold.ttf"
const MONO_PATH := "/usr/share/fonts/noto/NotoSansMono-Bold.ttf"

static var _bold: Font
static var _mono: Font


static func bold() -> Font:
	if _bold == null:
		_bold = _load(BOLD_PATH)
	return _bold


static func mono() -> Font:
	if _mono == null:
		_mono = _load(MONO_PATH)
	return _mono


static func _load(path: String) -> Font:
	if FileAccess.file_exists(path):
		var font := FontFile.new()
		if font.load_dynamic_font(path) == OK:
			return font
	return ThemeDB.fallback_font


static func width(text: String, font_size: int, numbers := false) -> float:
	var font := mono() if numbers else bold()
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
