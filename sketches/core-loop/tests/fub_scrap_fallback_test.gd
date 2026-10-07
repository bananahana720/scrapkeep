extends SceneTree

const Field := preload("res://src/build/scrap_field.gd")
const T := preload("res://tests/support/t.gd")

func _initialize() -> void:
	var t := T.new("fub_scrap_fallback_test")
	var script: GDScript = Field
	var seam := typeof(script.get("model_path")) == TYPE_STRING
	if not t.check("scrap model path can be overridden", seam):
		quit(t.verdict())
		return
	var real_path: String = script.get("model_path")
	var real_meshes := Field._pickup_meshes().duplicate()
	script.set("model_path", "res://assets/models/__fub_missing_scrap.glb")
	var field := Field.new()
	field.setup()
	var pickup = field._add(Vector3.ZERO)
	t.check("missing scrap keeps old box mesh", pickup.mesh == field._mesh and pickup.mesh is BoxMesh)
	t.check("missing scrap keeps old material", pickup.material_override == field._material and field._material is StandardMaterial3D)
	t.check("missing path has no asset meshes", Field._pickup_meshes().is_empty())
	var second := Field.new()
	second.setup()
	t.check("second field keeps old box mesh", second._add(Vector3.ONE).mesh is BoxMesh)
	script.set("model_path", real_path)
	t.check("restoring path restores cached real meshes", Field._pickup_meshes() == real_meshes)
	field.free()
	second.free()
	quit(t.verdict())
