extends SceneTree
const T := preload("res://tests/support/t.gd")
const Registry := preload("res://tests/support/content_registry.gd")
const Kinds := preload("res://src/core/event_kinds.gd")
func _initialize() -> void:
	var t := T.new("ground_slump_record_test")
	var issues := Registry.validate_table("event_kinds.WORLD_ROWS", Kinds.WORLD_ROWS, Registry.snapshot(), false)
	t.eq("amended world forms satisfy canonical references", issues, [])
	quit(t.verdict())
