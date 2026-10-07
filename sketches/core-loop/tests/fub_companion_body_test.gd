extends SceneTree

const Body := preload("res://src/presentation/companion_body.gd")
const T := preload("res://tests/support/t.gd")

func _initialize() -> void:
	var t := T.new("fub_companion_body_test")
	var model := Node3D.new()
	var empty := MeshInstance3D.new()
	model.add_child(empty)
	var valid := MeshInstance3D.new()
	valid.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.resource_name = "paint"
	valid.mesh.material = material
	model.add_child(valid)
	Body.dress_model(model)
	t.check("empty mesh does not abort valid companion paint", valid.get_active_material(0).vertex_color_use_as_albedo)
	Body.dress_model(model)
	t.check("empty mesh stays skipped", empty.mesh == null)
	t.check("cached source paint unchanged", not material.vertex_color_use_as_albedo)
	model.free()
	quit(t.verdict())
