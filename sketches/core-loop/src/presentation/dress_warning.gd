extends RefCounted

const DRESS_WORDS: Array[String] = [
	"fleet_paint", # the paint slot every kind must carry
	"greybox", # a loader fell back to the placeholder body
	"fallback", # any malformed-model fallback path
	"no material", # a surface without a material
	"malformed", # a model that failed its shape check
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
