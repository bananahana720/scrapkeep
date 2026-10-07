extends SceneTree

const Finishes := preload("res://src/presentation/highdraft_finishes.gd")
const T := preload("res://tests/support/t.gd")
var t := T.new("fub_aerial_test")

func _initialize() -> void:
	for missing in ["colors", "material"]:
		var mesh := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD])
		if missing != "colors":
			arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if missing != "material":
			mesh.surface_set_material(0, StandardMaterial3D.new())
		t.check("reject aerial without " + missing, Finishes.aerial_mesh(mesh) == null)
		t.check("repeat rejection without " + missing, Finishes.aerial_mesh(mesh) == null)
	quit(t.verdict())
