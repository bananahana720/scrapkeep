extends SceneTree

const Dress := preload("res://src/presentation/arena_mind_dress.gd")
const T := preload("res://tests/support/t.gd")

func _initialize() -> void:
	var t := T.new("fub_arena_root_test")
	var source := Node.new()
	var packed := PackedScene.new()
	packed.pack(source)
	source.free()
	packed.take_over_path(Dress.dir.path_join(Dress.PARTS["Island"][0]))
	var dress := Dress.new()
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	t.check("plain Node root rejects arena kit", dress._load_kit().is_empty())
	t.eq("rejected arena root is freed", Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)
	dress.free()
	quit(t.verdict())
