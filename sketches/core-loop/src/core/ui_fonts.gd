extends RefCounted


const BOLD_PATH := "res://assets/fonts/NotoSans-Bold.ttf"
const MONO_PATH := "res://assets/fonts/NotoSansMono-Bold.ttf"
const KEEPER_PATH := "res://assets/fonts/ArchivoBlack-Regular.ttf"
const OLD_WORKS_PATH := "res://assets/fonts/IBMPlexSans-SemiBold.ttf"
const HAND_FACES := [
	{"words": KEEPER_PATH, "numbers": MONO_PATH},
	{"words": BOLD_PATH, "numbers": MONO_PATH},
	{"words": OLD_WORKS_PATH, "numbers": MONO_PATH},
	{"words": MONO_PATH, "numbers": MONO_PATH},
]

static var _faces := {}


static func bold() -> Font:
	return _face(BOLD_PATH)


static func mono() -> Font:
	return _face(MONO_PATH)


static func face(hand: int, numbers := false) -> Font:
	return _face(HAND_FACES[hand]["numbers" if numbers else "words"])


static func reset_for_tests() -> void:
	_faces.clear()


static func _face(path: String) -> Font:
	if not _faces.has(path):
		_faces[path] = _load(path)
	return _faces[path]


static func vendored() -> bool:
	for path in [BOLD_PATH, MONO_PATH, KEEPER_PATH, OLD_WORKS_PATH]:
		if _face(path) == ThemeDB.fallback_font:
			return false
	return true


static func _load(path: String) -> Font:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Font:
			return res
	return ThemeDB.fallback_font


static func width(text: String, font_size: int, numbers := false) -> float:
	var font := mono() if numbers else bold()
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
