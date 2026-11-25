extends RefCounted

# The game's faces, all vendored in assets/fonts/ under SIL OFL 1.1 (PROVENANCE.txt names each source).
# Noto Sans Bold sets labels and toasts and Noto Sans Mono Bold sets numbers so digits do not jitter
# (VISUAL-LANGUAGE.md section 7). Two display faces set the words of two makers' hands (LEGIBILITY.md
# section 14.3, ruling ek): Archivo Black is the Keepers' poster face and IBM Plex Sans SemiBold the old
# works' clean corporate face. If a file is missing, Godot's default font stands in.

const BOLD_PATH := "res://assets/fonts/NotoSans-Bold.ttf"
const MONO_PATH := "res://assets/fonts/NotoSansMono-Bold.ttf"
const KEEPER_PATH := "res://assets/fonts/ArchivoBlack-Regular.ttf"
const OLD_WORKS_PATH := "res://assets/fonts/IBMPlexSans-SemiBold.ttf"
# Each hand's faces, in UiTokens.Hand order. Combat numbers keep the mono face in every hand.
const HAND_FACES := [
	{"words": KEEPER_PATH, "numbers": MONO_PATH}, # Keeper: the gig-poster face
	{"words": BOLD_PATH, "numbers": MONO_PATH}, # the Fleet: ledger digits in the mono face
	{"words": OLD_WORKS_PATH, "numbers": MONO_PATH}, # the old works: typeset, never written by hand
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


# True when every vendored face loaded from its file, not Godot's fallback.
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
