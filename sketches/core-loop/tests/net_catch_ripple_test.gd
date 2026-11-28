extends SceneTree

const Fx := preload("res://src/presentation/highdraft_fx.gd")
const Map := preload("res://src/world/map_highdraft.gd")
const T := preload("res://tests/support/t.gd")
const Comfort := preload("res://src/core/comfort.gd")


func _net(fx: Node3D) -> MultiMeshInstance3D:
	var view := MultiMeshInstance3D.new()
	view.multimesh = MultiMesh.new()
	view.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.material = StandardMaterial3D.new()
	view.multimesh.mesh = mesh
	view.multimesh.instance_count = 1
	view.custom_aabb = AABB(Vector3(-64, 10, 32), Vector3(32, 1, 32))
	var placements: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(-40, 10, 60))]
	view.set_meta("placements", placements)
	fx.add_child(view)
	fx._net_chunk(view, Fx._shader("net_catch.gdshader"))
	return view


func _initialize() -> void:
	var t := T.new("net_catch_ripple_test")
	var fx := Fx.new()
	root.add_child(fx)
	fx._map = Map.new()
	var material: ShaderMaterial = _net(fx).material_override
	var gain: float = material.get_shader_parameter("visual_catch_gain")
	fx.catch_at(Vector3(-40, 11, 60))
	var row: Dictionary = fx.active_catches[0]
	var impact: Vector4 = material.get_shader_parameter("catch_point")
	t.check("drawn depth at impact is at most 0.3 m", impact.z * gain <= 0.3 + 0.0001, "%.3f" % (impact.z * gain))
	var ring: Vector4 = material.get_shader_parameter("ring_a")
	t.near("ring starts at contact X", ring.x, -40.0)
	t.near("ring starts at contact Z", ring.y, 60.0)
	t.near("ring starts at the contact point", ring.z, 0.0)
	t.check("ring is lit at contact", ring.w > 0.0)
	var worst := 0.0
	var started_capture := false
	var last_front := 0.0
	var edge_at := -1.0
	var clock := 0.0
	var capture_drawn := -1.0
	for i in 60:
		fx.step(0.01, Vector3.INF)
		clock += 0.01
		var sag: Vector4 = material.get_shader_parameter("catch_point")
		worst = maxf(worst, sag.z * gain)
		if not started_capture and row.captured:
			started_capture = true
			capture_drawn = sag.z * gain
			t.check("second ring starts at capture", (material.get_shader_parameter("ring_b") as Vector4).w > 0.0)
			t.check("second ring is smaller", Fx.CAPTURE_RIPPLE_SCALE < 1.0)
		t.check("front never runs backwards", row.front >= last_front)
		last_front = row.front
		if edge_at < 0.0 and row.front >= Fx.CATCH_RADIUS - 0.0001:
			edge_at = clock
	t.check("drawn depth stays within twice the sink", worst <= 2.0 * Fx.CATCH_DEPTH + 0.0001, "%.3f" % worst)
	t.check("capture drawn depth is at most 0.1 m", capture_drawn >= 0.0 and capture_drawn <= 0.1 + 0.0001, "%.3f" % capture_drawn)
	t.check("ring reaches the net edge within 0.6 s", edge_at > 0.0 and edge_at <= 0.6, "%.2f" % edge_at)
	t.check("capture ring was seen", row.capture_front > 0.0)
	t.eq("catch retired", fx.active_catches.size(), 0)
	t.eq("rings cleared", material.get_shader_parameter("ring_a"), Vector4.ZERO)
	Comfort.reduced_motion = true
	fx.catch_at(Vector3(-40, 11, 60))
	fx.step(0.05, Vector3.INF)
	t.eq("reduced motion spawns no ring", material.get_shader_parameter("ring_a"), Vector4.ZERO)
	t.eq("reduced motion spawns no capture ring", material.get_shader_parameter("ring_b"), Vector4.ZERO)
	t.check("reduced motion pulses once", (material.get_shader_parameter("pulse") as Vector4).w > 0.0)
	fx.step(0.5, Vector3.INF)
	t.eq("pulse ends", material.get_shader_parameter("pulse"), Vector4.ZERO)
	Comfort.reduced_motion = false
	fx.free()
	quit(t.verdict())
