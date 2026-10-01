extends SceneTree

const Keycap := preload("res://src/ui/keycap.gd")

# Godot's SVG import drops <text>, so a key SVG that spells its letter draws as a blank
# cap. The alpha captures showed F, 1, 2, N, Q and Tab blank on the pick cards, the pause
# menu and the ability bar. Every such key must be drawn by Keycap with its label.

var failures := 0


func _initialize() -> void:
	var lettered: Array[String] = []
	var dir := DirAccess.open("res://assets/icons")
	for file in dir.get_files():
		if file.begins_with("key_") and file.ends_with(".svg"):
			var body := FileAccess.get_file_as_string("res://assets/icons/" + file)
			if "<text" in body:
				lettered.append(file.get_basename())
	var drawn_from_file := lettered.filter(func(key): return Keycap.from_svg(key))
	_check("lettered keys draw their label", lettered.size() > 0 and drawn_from_file.is_empty(),
		"%d lettered key SVGs; drawn from file: %s" % [lettered.size(), drawn_from_file])
	var blank := lettered.filter(func(key): return Keycap.label(key).strip_edges().is_empty())
	_check("every lettered key has a label", blank.is_empty(), "blank labels: %s" % [blank])
	print("ui_keycap_text_test: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("[%s] %s -> %s" % [name, detail, "PASS" if ok else "FAIL"])
