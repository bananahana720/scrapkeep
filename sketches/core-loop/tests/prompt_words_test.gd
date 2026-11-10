extends SceneTree

const Bindings := preload("res://src/core/bindings.gd")
const KeyGlyphs := preload("res://src/ui/key_glyphs.gd")
const T := preload("res://tests/support/t.gd")

# PF-03: a key prompt never draws a key and an icon alone. Every verb the prompts show, in every
# ball state and line, on a fresh profile and on one that has used every verb past its retirement,
# carries a non-empty word. The three prompts the player's-eye pass saw wordless (Shift as the
# run starts, E in the flume's crew fight, the mouse and Shift in Brindle's fight) are named.

class Profile:
	var count := 0

	func uses(_use: String) -> int:
		return count


var _t := T.new("prompt_words_test")


func _initialize() -> void:
	var glyphs = KeyGlyphs.new()
	glyphs.profile = Profile.new()
	var wordless: Array = []
	var seen := 0
	for count in [0, 99]:
		glyphs.profile.count = count
		for verb in KeyGlyphs.PROMPT_VERBS:
			for line in ["", "world", "body"]:
				for state in Bindings.STATES:
					seen += 1
					if glyphs.word_for(verb, line, state) == "":
						wordless.append("%s/%s/%s/uses %d" % [verb, line, state, count])
	_t.check("every prompt in every state has a word", wordless.is_empty() and seen == 2 * 6 * 3 * Bindings.STATES.size(),
		"%d combinations, wordless: %s" % [seen, wordless.slice(0, 6)])
	glyphs.profile.count = 99
	_t.eq("Shift reads BOOST after its prompt has retired", glyphs.word_for("boost", "", "ground"), "BOOST")
	_t.eq("the mouse reads HOOK after its first bite", glyphs.word_for("harpoon", "", "ground"), "HOOK")
	_t.eq("E reads MOUNT after its prompt has retired", glyphs.word_for("interact", "", "ground"), "MOUNT")
	_t.eq("the ultimate reads ULTIMATE after it retired", glyphs.word_for("ultimate", "", "ground"), "ULTIMATE")
	glyphs.profile.count = 0
	_t.eq("Shift reads BOOST on a fresh profile", glyphs.word_for("boost", "", "ground"), "BOOST")
	_t.eq("LET GO is a word", String(KeyGlyphs.LETGO_WORD), "LET GO")
	glyphs.free()
	quit(_t.verdict())
