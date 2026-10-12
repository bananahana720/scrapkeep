extends SceneTree

const Hero := preload("res://src/presentation/hero_assets.gd")
const Motion := preload("res://src/presentation/mecha_motion.gd")
const T := preload("res://tests/support/t.gd")
var t := T.new("pilot_clip_shell_lookup_test")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var roster: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/presentation/clips/roster.json"))
	for pilot in roster.pilots:
		var row: Dictionary = roster.pilots[pilot]
		var scene: Node3D = load("res://" + row.shell).instantiate()
		root.add_child(scene)
		var pod := scene.find_child("Pod", true, false) as Node3D
		var core := scene.find_child("Core", true, false) as Node3D
		var names: Array = ["Core", "Fin.L", "Fin.R"]
		for node in scene.find_children("Control_*", "Node3D", true, false):
			names.append(String(node.name))
		var table_path := "res://src/presentation/clips/%s.json" % pilot
		var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(table_path)) if FileAccess.file_exists(table_path) else {}
		for machinery in table.get("machinery", []):
			if not machinery.node in names:
				names.append(machinery.node)
		var expected := {}
		for name in names:
			expected[name] = core if name == "Core" else scene.find_child(String(name).replace(".", "_"), true, false)
		# Reproduce the loader's split and runtime rename with Core and Pod in separate parents.
		var parts := Hero._split(scene)
		var roll := Node3D.new()
		var juice := Node3D.new()
		root.add_child(roll)
		root.add_child(juice)
		roll.add_child(parts.core)
		juice.add_child(parts.pod)
		core.name = "HeroCore"
		pod.name = "HeroPod"
		var motion := Motion.new(pod, core, row["class"], table.get("machinery", []))
		for name in names:
			var got: Node3D = motion._node(name)
			var searched := "%s + %s" % [pod.get_path(), core.get_path()]
			print("SHELL_LOOKUP pilot=%s request=%s searched=%s found=%s" % [pilot, name, searched, got.get_path() if got != null else "ABSENT"])
			t.eq("%s finds shipped %s" % [pilot, name], got, expected[name])
			motion._node(name)
			if expected[name] == null:
				t.eq("%s %s skips once" % [pilot, name], motion.skip_lines.count("SKIP control " + String(name).trim_prefix("Control.")), 1)
		print("SHELL_SKIPS pilot=%s searched=%s lines=%s" % [pilot, "%s + %s" % [pod.get_path(), core.get_path()], motion.skip_lines])
		roll.free()
		juice.free()
	quit(t.verdict())
