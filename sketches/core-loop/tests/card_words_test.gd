extends SceneTree

# PF-29 and PF-22. A card says what its part really does, in words a first-timer knows.
# Walks every part and item card (Parts.rows(), the hot-wired rows and the burdens):
#  - the word "armour" (or "armor") sits only on a card whose part fills the ARMOUR bar, which
#    is a hot-wired row that needs armour mode; no catalogue row changes that bar;
#  - a card whose effect is maximum health says "health" in its verb or text;
#  - the game-term reward lines the first-timer film could not read are gone.
const Parts := preload("res://src/build/parts.gd")

const GONE_LINES := ["Bank a bigger plant", "Rebounds deal a weapon hit"]

var _failures := 0
var _checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _report(label: String, ok: bool, detail: String) -> void:
	_checked += 1
	if not ok:
		_failures += 1
		print("[%s] %s -> FAIL" % [label, detail])


# Every word a card shows for a catalogue row: verb, pitch, text and each level's text.
# The caller adds the display name, so a part named "Armor" that fills no armour bar fails too.
func _words(row: Dictionary) -> Array:
	var out: Array = []
	for key in ["verb", "pitch", "text", "label"]:
		if row.has(key):
			out.append(String(row[key]))
	for level in row.get("levels", []):
		if level.has("text"):
			out.append(String(level["text"]))
	return out


func _says(words: Array, needle: String) -> bool:
	return words.any(func(w): return needle in w.to_lower())


func _changes_max_health(row: Dictionary) -> bool:
	if float(row.get("max_hp_bonus", 0.0)) != 0.0:
		return true
	for level in row.get("levels", []):
		if float(level.get("max_hp_bonus", 0.0)) != 0.0:
			return true
	return String(row.get("effect", {}).get("do", "")) == "hp_per_mass"


func _run() -> void:
	var rows: Dictionary = Parts.rows()
	_report("rows", rows.size() >= 90, "%d catalogue and item rows walked" % rows.size())
	for key in rows:
		var row: Dictionary = rows[key]
		var words := _words(row)
		words.append(Parts.display_name(key))
		for gone in GONE_LINES:
			_report(key + " lines", not _says(words, gone.to_lower()), "%s still says \"%s\"" % [key, gone])
		# No catalogue or item row fills the ARMOUR bar, so none may use the word.
		var fills_armour := row.has("armor") or row.has("armour") or row.has("armor_bonus")
		var uses_word := _says(words, "armour") or _says(words, "armor")
		_report(key + " armour", fills_armour or not uses_word, "%s says armour but changes no armour value" % key)
		if _changes_max_health(row):
			_report(key + " health", _says(words, "health"), "%s changes max health but its card never says health" % key)
	for key in Parts.HOTWIRED:
		var spec: Dictionary = Parts.HOTWIRED[key]
		var texts: Array = [String(spec.get("label", "")), String(spec.get("name", ""))]
		for side in ["upside", "downside"]:
			texts.append(String(spec.get(side, {}).get("words", "")))
		var part: Dictionary = spec.get("part", {})
		for k in ["verb", "text"]:
			texts.append(String(part.get(k, "")))
		var uses_word := _says(texts, "armour") or _says(texts, "armor")
		_report(key + " hot-wired armour", bool(spec.get("needs_armor", false)) or not uses_word,
			"%s says armour but needs no armour mode" % key)
		if _changes_max_health(part):
			_report(key + " hot-wired health", _says(texts, "health"), "%s changes max health but never says health" % key)
	# The brief's own case: Rivet Plating's name line and panel say the same true thing.
	var rivet: Dictionary = rows["rivet_plating"]
	_report("rivet plating", "health" in String(rivet["verb"]).to_lower() and not _says(_words(rivet), "armour"),
		"Rivet Plating's verb is \"%s\"" % rivet["verb"])
	print("%d checks" % _checked)
	print("card_words_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
