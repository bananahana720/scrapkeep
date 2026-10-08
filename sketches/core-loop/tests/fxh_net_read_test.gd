extends SceneTree

const Fx := preload("res://src/presentation/highdraft_fx.gd")
const Map := preload("res://src/world/map_highdraft.gd")
const T := preload("res://tests/support/t.gd")


func _initialize() -> void:
	var t := T.new("fxh_net_read_test")
	var fx := Fx.new()
	root.add_child(fx)
	fx._map = Map.new()
	var view := MultiMeshInstance3D.new()
	view.multimesh = MultiMesh.new()
	view.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.material = StandardMaterial3D.new()
	view.multimesh.mesh = mesh
	view.multimesh.instance_count = 1
	view.custom_aabb = AABB(Vector3(-64, 10, 32), Vector3(32, 1, 32))
	var original := view.custom_aabb
	var placements: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(-40, 10, 60))]
	view.set_meta("placements", placements)
	fx.add_child(view)
	fx._net_chunk(view, Fx._shader("net_catch.gdshader"))
	var material: ShaderMaterial = view.material_override
	var gain = material.get_shader_parameter("visual_catch_gain")
	t.check("net draws at most twice its physical sink", gain != null and float(gain) <= 2.0)
	fx.catch_at(Vector3(-40, 11, 60))
	fx.step(0.2, Vector3.INF)
	var sag: Vector4 = material.get_shader_parameter("catch_point")
	t.check("capture-time net bowl stays within 0.1 m", gain != null and sag.z * float(gain) <= 0.1 + 0.0001, "base depth %.3f m" % sag.z)
	t.check("culling bounds contain full visible deflection", view.custom_aabb.position.y <= original.position.y - 0.3)
	fx.step(0.21, Vector3.INF)
	t.near("net returns to exact rest on existing schedule", (material.get_shader_parameter("catch_point") as Vector4).z, 0.0)
	t.eq("contact depth remains unchanged", Fx.CATCH_DEPTH, 0.15)
	fx.free()
	quit(t.verdict())
