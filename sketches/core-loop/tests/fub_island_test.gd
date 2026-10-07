extends SceneTree

const Scenery := preload("res://src/presentation/highdraft_scenery.gd")
const T := preload("res://tests/support/t.gd")
var t := T.new("fub_island_test")
var fixtures: Array[PackedScene] = []

func _initialize() -> void:
	for missing in ["colors", "normals"]:
		var mesh := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
		if missing != "colors":
			arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
		if missing != "normals":
			arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, StandardMaterial3D.new())
		var scene := Node3D.new()
		var view := MeshInstance3D.new()
		view.name = "IslandStone"
		view.mesh = mesh
		scene.add_child(view)
		view.owner = scene
		var packed := PackedScene.new()
		packed.pack(scene)
		scene.free()
		var file := "fub_no_%s.glb" % missing
		packed.take_over_path(Scenery.dir + file)
		fixtures.append(packed)
		var isle := {"at": Vector2.ZERO, "radius": 4.0, "top": 0.0}
		var ground := func(x: float, z: float, _clearance: float) -> Vector3: return Vector3(x, 0.0, z)
		t.check("reject island without " + missing, Scenery._island_mesh(file, isle, null, ground) == null)
		t.check("repeat island rejection " + missing, Scenery._island_mesh(file, isle, null, ground) == null)
		t.check("island warning recorded " + missing, Scenery._warned.has(Scenery.dir + file))
	quit(t.verdict())
