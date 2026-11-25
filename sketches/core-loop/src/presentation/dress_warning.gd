extends RefCounted

const DRESS_WORDS: Array[String] = [
	"fleet_paint",
	"greybox",
	"fallback",
	"no material",
	"malformed",
]


static func is_dress(text: String, ignored: Array[String]) -> bool:
	var lowered := text.to_lower()
	for word in ignored:
		if lowered.contains(word):
			return false
	for word in DRESS_WORDS:
		if lowered.contains(word):
			return true
	return false
