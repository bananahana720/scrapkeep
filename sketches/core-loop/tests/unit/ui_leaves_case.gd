extends RefCounted

const LOWER_DIRS: Array[String] = [
	"res://src/core", "res://src/build", "res://src/combat", "res://src/boss", "res://src/movement", "res://src/world",
]
const UI_DIR := "res://src/ui/"
const UI_LEAVES: Array[String] = ["glyphs.gd", "word_budget.gd", "why_callout.gd"]
const FLOW_PATH := "res://src/core/flow.gd"


func _gd_files(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := root.path_join(name)
		if dir.current_is_dir():
			out.append_array(_gd_files(full))
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _matching_files(root: String, pattern: String) -> Array[String]:
	var re := RegEx.new()
	re.compile(pattern)
	var out: Array[String] = []
	for path in _gd_files(root):
		if re.search(FileAccess.get_file_as_string(path)) != null:
			out.append(path)
	return out


func run(t) -> void:
	t.check("glyphs.gd lives in src/core", FileAccess.file_exists("res://src/core/glyphs.gd"))
	t.check("glyphs.gd is gone from src/ui", not FileAccess.file_exists(UI_DIR + "glyphs.gd"))
	t.check("word_budget.gd lives in src/core", FileAccess.file_exists("res://src/core/word_budget.gd"))
	for name in UI_LEAVES:
		var leaf: String = UI_DIR + name
		var quoted := "[\"']" + leaf.replace(".", "\\.") + "[\"']"
		for root in LOWER_DIRS:
			t.eq("no %s names %s" % [root, leaf], _matching_files(root, quoted), [])

	var declares := "(?m)^\\s*(static\\s+)?func\\s+warden_fight_live\\b"
	t.eq("flow.gd declares warden_fight_live", _matching_files("res://src/core", declares).filter(
		func(p: String) -> bool: return p == FLOW_PATH), [FLOW_PATH])
	var others: Array[String] = []
	for root in ["res://src", "res://tools"]:
		others.append_array(_matching_files(root, declares).filter(func(p: String) -> bool: return p != FLOW_PATH))
	t.eq("only flow.gd declares warden_fight_live", others, [])
