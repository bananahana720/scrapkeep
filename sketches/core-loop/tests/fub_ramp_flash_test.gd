extends SceneTree

const Ramp := preload("res://src/combat/ramp_flipper.gd")
const T := preload("res://tests/support/t.gd")

func _initialize() -> void:
	var t := T.new("fub_ramp_flash_test")
	var path := "res://assets/models/world_one/enemy_ramp_flipper.glb"
	var original := load(path) as PackedScene
	var scene := original.instantiate()
	var body := scene.find_child("RampBody", true, false) as MeshInstance3D
	body.mesh = body.mesh.duplicate()
	for surface in body.mesh.get_surface_count():
		var material := StandardMaterial3D.new()
		material.resource_name = "plain"
		body.mesh.surface_set_material(surface, material)
	var packed := PackedScene.new()
	packed.pack(scene)
	scene.free()
	packed.take_over_path(path)
	t.check("ramp without flash surface keeps greybox", Ramp._parts().is_empty())
	t.check("repeat ramp rejection keeps greybox", Ramp._parts().is_empty())
	quit(t.verdict())
