extends RefCounted

# The HUD's two faces (VISUAL-LANGUAGE.md section 7): Noto Sans Bold for labels and
# toasts, Noto Sans Mono Bold for numbers so digits do not jitter. Both are vendored in
# assets/fonts/ with their OFL licence; if one is missing, Godot's default font stands in.

const BOLD_PATH := "res://assets/fonts/NotoSans-Bold.ttf"
const MONO_PATH := "res://assets/fonts/NotoSansMono-Bold.ttf"
# Each hand's faces, in UiTokens.Hand order (LEGIBILITY.md section 14.3). Combat numbers keep the two
# Noto faces in every hand, and a new display face changes what ships, so it waits on Andrew's go-ahead;
# until then the hands differ by frame, edge, mark and motion, and a hand that gets its own face changes
# its row here and nothing else.
const HAND_FACES := [
	{"words": BOLD_PATH, "numbers": MONO_PATH}, # Keeper
	{"words": BOLD_PATH, "numbers": MONO_PATH}, # the Fleet: ledger digits in the mono face
	{"words": BOLD_PATH, "numbers": MONO_PATH}, # the old works
	{"words": MONO_PATH, "numbers": MONO_PATH}, # Rogues: a stencilled number and no words
]

# Loaded faces by path, so each file loads once per process (reset_for_tests empties it between batched tests).
static var _faces := {}


static func bold() -> Font:
	return _face(BOLD_PATH)


static func mono() -> Font:
	return _face(MONO_PATH)


# The face a hand sets its words, or its numbers, in.
static func face(hand: int, numbers := false) -> Font:
	return _face(HAND_FACES[hand]["numbers" if numbers else "words"])


static func reset_for_tests() -> void:
	_faces.clear()


static func _face(path: String) -> Font:
	if not _faces.has(path):
		_faces[path] = _load(path)
	return _faces[path]


static func vendored() -> bool:
	return bold() != ThemeDB.fallback_font and mono() != ThemeDB.fallback_font


static func _load(path: String) -> Font:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Font:
			return res
	return ThemeDB.fallback_font


static func width(text: String, font_size: int, numbers := false) -> float:
	var font := mono() if numbers else bold()
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
