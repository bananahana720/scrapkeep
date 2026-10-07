extends SceneTree

const Cosmetic := preload("res://src/presentation/cosmetic_presentation.gd")
const Body := preload("res://src/presentation/companion_body.gd")
const T := preload("res://tests/support/t.gd")

func _initialize() -> void:
	var t := T.new("fub_companion_paint_test")
	var parent := Node3D.new()
	var hero := Node3D.new()
	parent.add_child(hero)
	var body := Body.new()
	body.name = "CompanionBody"
	parent.add_child(body)
	var model := Node3D.new()
	body.add_child(model)
	body._model = model
	var rig := Skeleton3D.new()
	rig.name = "Skeleton3D"
	rig.add_bone("Hull")
	model.add_child(rig)
	var view := MeshInstance3D.new()
	view.skeleton = NodePath("../Skeleton3D")
	view.skin = Skin.new()
	view.skin.add_named_bind("Hull", Transform3D.IDENTITY)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	var source := ArrayMesh.new()
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var paint := StandardMaterial3D.new()
	paint.resource_name = "paint"
	source.surface_set_material(0, paint)
	view.mesh = source
	model.add_child(view)
	var cosmetic := Cosmetic.new()
	cosmetic.hero = hero
	var row := {"asset": "fub_paint", "resource": StandardMaterial3D.new()}
	cosmetic._apply_companion(row)
	t.check("missing colors keep original paint", view.get_active_material(0) == paint)
	t.check("missing colors warn once", cosmetic.resolver._warned.has("fub_paint"))
	cosmetic._apply_companion(row)
	t.check("repeat keeps original paint", view.get_active_material(0) == paint)
	cosmetic.free()
	parent.free()
	quit(t.verdict())
