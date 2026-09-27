extends SceneTree

const Shop := preload("res://src/build/shop.gd")

# Moss's lines come only from SOUND-STORY section 8 (its W4 must): every line the shop
# can say appears there word for word, fits the 12-word bubble, and each of the six
# beats has at least three variations for every class.

const SOURCE := "res://SOUND-STORY.md"
const BUBBLE_WORDS := 12
const CLASSES := ["pylon_engineer", "runner_gunner", "demolitions_caster"]

var _failures := 0


func _initialize() -> void:
	var file := FileAccess.open(SOURCE, FileAccess.READ)
	var story := file.get_as_text() if file != null else ""
	var missing: Array = []
	var long: Array = []
	for id in Shop.LINES:
		var text: String = Shop.LINES[id]
		if not story.contains(text):
			missing.append(id)
		if text.split(" ", false).size() > BUBBLE_WORDS:
			long.append(id)
	_report("lines from SOUND-STORY section 8", story != "" and missing.is_empty() and long.is_empty(),
		"%d lines; not found verbatim %s; over %d words %s" % [Shop.LINES.size(), missing, BUBBLE_WORDS, long])
	var thin: Array = []
	for beat in Shop.BEATS:
		for class_id in CLASSES:
			var n: int = Shop.LINES.keys().filter(func(id): return _for(id, beat["id"], class_id)).size()
			if n < 3:
				thin.append("%s for %s: %d" % [beat["id"], class_id, n])
	_report("three variations per beat", thin.is_empty(), "six beats x three classes; thin %s" % [thin])
	var copyright := ["potion", "traveller", "wizard", "weaker"]
	var hits: Array = []
	for id in Shop.LINES:
		for word in copyright:
			if String(Shop.LINES[id]).to_lower().contains(word):
				hits.append("%s: %s" % [id, word])
	_report("Moss's own voice", hits.is_empty(), "no line names a potion, a traveller, a wizard or a weaker seller; hits %s" % [hits])
	print("shop_lines_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _for(line_id: String, beat_id: String, class_id: String) -> bool:
	return line_id.begins_with("moss.%s." % beat_id) and Shop.CLASS_LINES.get(line_id, class_id) == class_id


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
