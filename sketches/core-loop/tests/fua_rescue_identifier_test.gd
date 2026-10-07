extends SceneTree

const T := preload("res://tests/support/t.gd")
const SOURCES := ["res://src/world/world.gd", "res://tests/audio_rescue_test.gd",
	"res://tests/dig_rescue_test.gd", "res://tests/rescue_quest_test.gd"]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("fua_rescue_identifier_test")
	var global_names := []
	for row in ProjectSettings.get_global_class_list():
		global_names.append(String(row["class"]))
	t.check("Godot's global class registry is populated", not global_names.is_empty())
	for path in SOURCES:
		var script := load(path) as GDScript
		if t.check("rescue consumer loads: " + path, script != null and script.can_instantiate()):
			var collisions := []
			for constant in script.get_script_constant_map():
				if String(constant) in global_names:
					collisions.append(String(constant))
			t.eq("rescue consumer has no shadowed global identifiers: " + path, collisions, [])
	quit(t.verdict())
