extends SceneTree

const Case := preload("res://tests/unit/presentation_run_identity_case.gd")
const T := preload("res://tests/support/t.gd")


func _initialize() -> void:
	var t := T.new("presentation_run_identity_test")
	Case.new().run(t)
	quit(t.verdict())
