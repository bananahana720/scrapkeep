extends RefCounted


static func glow(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, 1.0)


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func ball(d: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = d * 0.5
	s.height = d
	s.radial_segments = 6
	s.rings = 3
	return s


static func ramp(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex


static func fade(end: float) -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, end))
	var tex := CurveTexture.new()
	tex.curve = c
	return tex


static func flecks_material() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 16.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 11.0
	pm.gravity = Vector3(0, 3.0, 0)
	pm.particle_flag_align_y = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.7
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	pm.scale_curve = fade(0.2)
	pm.color_ramp = ramp([[0.0, Color(1.0, 0.95, 0.75, 1.0)], [0.25, Color(1.0, 0.6, 0.18, 1.0)],
		[0.65, Color(0.85, 0.24, 0.08, 0.85)], [1.0, Color(0.2, 0.08, 0.06, 0.0)]])
	return pm


static func embers_material() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0, 1.4, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.9
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.scale_curve = fade(0.0)
	pm.color_ramp = ramp([[0.0, Color(1.0, 0.7, 0.3, 1.0)], [0.5, Color(0.9, 0.35, 0.12, 0.9)], [1.0, Color(0.35, 0.1, 0.06, 0.0)]])
	return pm


static func carve_material() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.35, -1)
	pm.spread = 22.0
	pm.initial_velocity_min = 7.0
	pm.initial_velocity_max = 14.0
	pm.gravity = Vector3(0, -22.0, 0)
	pm.particle_flag_align_y = true
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.scale_curve = fade(0.1)
	pm.color_ramp = ramp([[0.0, Color(1.0, 0.95, 0.7, 1.0)], [0.35, Color(1.0, 0.72, 0.25, 1.0)], [1.0, Color(0.8, 0.3, 0.1, 0.0)]])
	return pm


static func column_material() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 6.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 11.0
	pm.radial_velocity_min = -1.6
	pm.radial_velocity_max = -1.0
	pm.gravity = Vector3(0, -2.0, 0)
	pm.particle_flag_align_y = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 1.6
	pm.emission_ring_inner_radius = 1.3
	pm.emission_ring_height = 0.0
	pm.scale_curve = fade(0.0)
	pm.alpha_curve = fade(0.0)
	return pm


static func boon_material() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.angular_velocity_min = -540.0
	pm.angular_velocity_max = 540.0
	pm.scale_curve = fade(0.0)
	pm.alpha_curve = fade(0.0)
	return pm
