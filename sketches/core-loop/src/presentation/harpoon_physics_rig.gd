extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")


const DEFAULT_SEGMENTS := 20
const MIN_SEGMENTS := 16
const MAX_SEGMENTS := 24
const SPOOL_RADIUS_M := 0.16

const JAW_ANGLE_LAUNCH := 0.74
const JAW_ANGLE_BITE := -0.18
const JAW_ANGLE_WORLD := -0.07
const JAW_ANGLE_RETRACT := 0.22
const JAW_CLAMP_OVERSHOOT := -0.20
const JAW_COUNT := 3

const PHASE_IDLE := 0
const PHASE_LAUNCH := 1
const PHASE_LATCHED := 2
const PHASE_RETRACT := 3
const PHASE_BROKE := 4

static var _body_mesh: ArrayMesh
static var _core_mesh: ArrayMesh
static var _jaw_mesh: ArrayMesh
static var _spool_mesh: ArrayMesh
static var _metal_mat: StandardMaterial3D
static var _spool_mat: StandardMaterial3D
static var _ink_mat: StandardMaterial3D
static var _cable_ink_mat: StandardMaterial3D


static func reset_for_tests() -> void:
	_body_mesh = null
	_core_mesh = null
	_jaw_mesh = null
	_spool_mesh = null
	_metal_mat = null
	_spool_mat = null
	_ink_mat = null
	_cable_ink_mat = null


static func is_reduced_motion(override_flag := false) -> bool:
	return override_flag or EnemyMotion.motion_scale <= 0.0



class CableSolver extends RefCounted:
	var segments: int = DEFAULT_SEGMENTS
	var reduced_motion := false

	var phase: int = PHASE_IDLE
	var phase_age := 0.0
	var strum_energy := 0.0
	var strum_phase := 0.0
	var whip_energy := 0.0
	var whip_phase := 0.0
	var whip_direction := 1.0
	var sway_offset := Vector3.ZERO
	var sway_velocity := Vector3.ZERO
	var spool_angle := 0.0
	var spool_speed := 0.0

	var _last_span := -1.0
	var _last_mid := Vector3.ZERO
	var _has_mid := false
	var _was_taut := false

	func _init(segment_count: int = DEFAULT_SEGMENTS) -> void:
		segments = clampi(segment_count, MIN_SEGMENTS, MAX_SEGMENTS)

	func reset() -> void:
		phase = PHASE_IDLE
		phase_age = 0.0
		strum_energy = 0.0
		strum_phase = 0.0
		whip_energy = 0.0
		whip_phase = 0.0
		whip_direction = 1.0
		sway_offset = Vector3.ZERO
		sway_velocity = Vector3.ZERO
		spool_angle = 0.0
		spool_speed = 0.0
		_last_span = -1.0
		_last_mid = Vector3.ZERO
		_has_mid = false
		_was_taut = false

	func trigger_launch() -> void:
		phase = PHASE_LAUNCH
		phase_age = 0.0
		whip_energy = 0.0 if _calm() else 0.56
		whip_phase = 0.0
		whip_direction = 1.0
		strum_energy = 0.0

	func trigger_bite(strength := 1.0) -> void:
		phase = PHASE_LATCHED
		phase_age = 0.0
		whip_energy = 0.0
		strum_energy = 0.0 if _calm() else clampf(0.32 * strength, 0.0, 0.44)
		strum_phase = 0.0
		_was_taut = true

	func trigger_strum(strength := 0.65) -> void:
		if _calm():
			strum_energy = 0.0
			return
		strum_energy = maxf(strum_energy, clampf(0.24 * strength, 0.0, 0.36))

	func trigger_retract() -> void:
		phase = PHASE_RETRACT
		phase_age = 0.0
		strum_energy = 0.0
		whip_energy = 0.0 if _calm() else 0.48
		whip_phase = 0.0
		whip_direction = -1.0
		_was_taut = false

	func trigger_broke() -> void:
		phase = PHASE_BROKE
		phase_age = 0.0
		strum_energy = 0.0
		whip_energy = 0.0 if _calm() else 0.38
		whip_phase = 0.0
		whip_direction = -1.0
		_was_taut = false

	func _calm() -> bool:
		return EnemyMotion.motion_scale <= 0.0 or reduced_motion

	func step(delta: float, from: Vector3, to: Vector3, taut: bool) -> void:
		var dt := clampf(delta, 0.0, 0.05)
		phase_age += dt
		var span := from.distance_to(to)
		if _calm():
			strum_energy = 0.0
			whip_energy = 0.0
			sway_offset = Vector3.ZERO
			sway_velocity = Vector3.ZERO
			spool_speed = 0.0
			_last_span = span
			_last_mid = (from + to) * 0.5
			_has_mid = true
			_was_taut = taut
			return

		if taut and not _was_taut and phase == PHASE_LATCHED:
			trigger_strum(0.75)
		_was_taut = taut

		if _last_span >= 0.0 and dt > 0.0001:
			var rate := (span - _last_span) / dt
			var target_omega := clampf(rate / SPOOL_RADIUS_M, -48.0, 48.0)
			spool_speed = lerpf(spool_speed, target_omega, minf(1.0, dt * 18.0))
		else:
			spool_speed = lerpf(spool_speed, 0.0, minf(1.0, dt * 10.0))
		spool_angle = wrapf(spool_angle + spool_speed * dt, -TAU, TAU)
		_last_span = span

		if strum_energy > 0.0005:
			strum_phase += dt * TAU * 18.0
			strum_energy *= exp(-dt * 8.5)
		else:
			strum_energy = 0.0

		if whip_energy > 0.0005:
			whip_phase += dt * TAU * 7.5 * whip_direction
			whip_energy *= exp(-dt * 5.2)
		else:
			whip_energy = 0.0

		var mid := (from + to) * 0.5
		if _has_mid and dt > 0.0001:
			var mid_vel := (mid - _last_mid) / dt
			var drive := -mid_vel * (0.015 if taut else 0.05)
			var stiffness := 110.0 if taut else 38.0
			var damping := 14.0 if taut else 7.5
			var accel := -stiffness * sway_offset - damping * sway_velocity + drive
			sway_velocity += accel * dt
			sway_offset += sway_velocity * dt
			var cap := 0.14 if taut else 0.65
			if sway_offset.length() > cap:
				sway_offset = sway_offset.normalized() * cap
		_last_mid = mid
		_has_mid = true

	func sample_points(from: Vector3, to: Vector3, sag: float, taut: bool) -> Array[Vector3]:
		var pts: Array[Vector3] = []
		pts.resize(segments + 1)
		var chord := to - from
		var length := chord.length()
		if length < 0.0001:
			for i in segments + 1:
				pts[i] = from
			return pts

		var dir := chord / length
		var ref_up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.96 else Vector3.RIGHT
		var side := dir.cross(ref_up).normalized()
		var ortho_up := side.cross(dir).normalized()
		var calm := _calm()
		var span_scale := clampf(length / 10.0, 0.25, 1.8)
		var eff_sag := maxf(sag, 0.0)
		var cat_k := clampf(0.6 + eff_sag * 0.45, 0.6, 2.2)
		var cosh_k := cosh(cat_k)
		var cat_denom := maxf(cosh_k - 1.0, 0.0001)

		for i in segments + 1:
			var f := float(i) / float(segments)
			var p := from.lerp(to, f)
			if i == 0 or i == segments:
				pts[i] = from if i == 0 else to
				continue
			var env := sin(PI * f)
			if eff_sag > 0.0001:
				var cat_profile := (cosh_k - cosh((2.0 * f - 1.0) * cat_k)) / cat_denom
				p += Vector3.DOWN * eff_sag * cat_profile
			if not calm:
				if strum_energy > 0.0005:
					var m1 := sin(PI * f) * sin(strum_phase)
					var m2 := 0.35 * sin(TAU * f) * sin(strum_phase * 1.95 + 0.7)
					var disp := strum_energy * span_scale * (m1 + m2)
					p += ortho_up * disp + side * (disp * 0.42)
				if whip_energy > 0.0005:
					var wave := sin(f * TAU * 1.65 - whip_phase)
					var cross_wave := cos(f * TAU * 1.35 - whip_phase * 0.9)
					var amp := whip_energy * env * span_scale * (0.45 if taut else 1.0)
					p += side * (wave * amp) + ortho_up * (cross_wave * amp * 0.55)
				var sway_ortho := sway_offset - dir * sway_offset.dot(dir)
				p += sway_ortho * env
			pts[i] = p
		return pts



class HarpoonHead extends MeshInstance3D:
	var jaws: Array[MeshInstance3D] = []
	var core_node: MeshInstance3D
	var jaw_angle := JAW_ANGLE_RETRACT
	var target_jaw_angle := JAW_ANGLE_RETRACT
	var clamp_impulse := 0.0
	var live_pulse_age := 0.0
	var _core_mat: StandardMaterial3D

	func _init() -> void:
		name = "HarpoonHead"
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func build(b_mesh: ArrayMesh, c_mesh: ArrayMesh, j_mesh: ArrayMesh, m_mat: StandardMaterial3D) -> void:
		if mesh != null:
			return
		mesh = b_mesh
		material_override = m_mat

		core_node = MeshInstance3D.new()
		core_node.name = "LiveCore"
		core_node.mesh = c_mesh
		_core_mat = Palette.solid(Palette.ARC, 1.35)
		_core_mat.roughness = 0.25
		_core_mat.metallic = 0.2
		core_node.material_override = _core_mat
		core_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(core_node)

		jaws.clear()
		for i in JAW_COUNT:
			var angle := TAU * float(i) / float(JAW_COUNT)
			var pivot := Node3D.new()
			pivot.name = "JawPivot_%d" % i
			pivot.rotation.z = angle
			pivot.position = Vector3(cos(angle), sin(angle), -0.14) * 0.145
			add_child(pivot)
			var jaw := MeshInstance3D.new()
			jaw.name = "ClawJaw_%d" % i
			jaw.mesh = j_mesh
			jaw.material_override = m_mat
			jaw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(jaw)
			jaws.append(jaw)
		_apply_jaws()

	func set_mode(mode: String, trigger_clamp := false, reduced_motion := false) -> void:
		match mode:
			"launch":
				target_jaw_angle = JAW_ANGLE_LAUNCH
				jaw_angle = JAW_ANGLE_LAUNCH
				clamp_impulse = 0.0
			"bite":
				target_jaw_angle = JAW_ANGLE_BITE
				if trigger_clamp and not (reduced_motion or EnemyMotion.motion_scale <= 0.0):
					clamp_impulse = 1.0
				elif reduced_motion or EnemyMotion.motion_scale <= 0.0:
					jaw_angle = JAW_ANGLE_BITE
					clamp_impulse = 0.0
			"world":
				target_jaw_angle = JAW_ANGLE_WORLD
				if trigger_clamp and not (reduced_motion or EnemyMotion.motion_scale <= 0.0):
					clamp_impulse = 0.7
				elif reduced_motion or EnemyMotion.motion_scale <= 0.0:
					jaw_angle = JAW_ANGLE_WORLD
					clamp_impulse = 0.0
			_:
				target_jaw_angle = JAW_ANGLE_RETRACT
				clamp_impulse = 0.0

	func step_head(delta: float, live: bool, reduced_motion := false, accent_color := Color(-1.0, 0.0, 0.0, 0.0)) -> void:
		var dt := clampf(delta, 0.0, 0.05)
		var calm := reduced_motion or EnemyMotion.motion_scale <= 0.0
		live_pulse_age += dt
		if calm:
			jaw_angle = target_jaw_angle
			clamp_impulse = 0.0
		else:
			jaw_angle = lerpf(jaw_angle, target_jaw_angle, minf(1.0, dt * 26.0))
			if clamp_impulse > 0.001:
				clamp_impulse *= exp(-dt * 14.0)
			else:
				clamp_impulse = 0.0
		_apply_jaws()
		if _core_mat != null:
			var base_col := Palette.ARC if accent_color.r < 0.0 else accent_color
			_core_mat.albedo_color = base_col
			_core_mat.emission = base_col
			var pulse := 1.0 if (calm or not live) else (0.85 + 0.15 * sin(live_pulse_age * TAU * 2.0))
			var clamp_boost := 0.0 if calm else FlashGuard.whiten(0.55) * clamp_impulse
			var energy := (1.15 * pulse + clamp_boost) if live else 0.25
			_core_mat.emission_energy_multiplier = FlashGuard.info(energy) if FlashGuard.on else energy

	func aim_along(at: Vector3, forward_dir: Vector3) -> void:
		var kept_scale := scale
		var fwd := forward_dir.normalized() if forward_dir.length_squared() > 0.0001 else Vector3.FORWARD
		var up := Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.96 else Vector3.RIGHT
		var rot := Basis.looking_at(fwd, up).scaled(kept_scale)
		if is_inside_tree():
			global_position = at
			global_basis = rot
		else:
			position = at
			basis = rot

	func current_jaw_angle() -> float:
		return jaw_angle + JAW_CLAMP_OVERSHOOT * clamp_impulse

	func _apply_jaws() -> void:
		var a := current_jaw_angle()
		for jaw in jaws:
			jaw.rotation = Vector3(0.0, -a, 0.0)



class FairleadSpool extends MeshInstance3D:
	func _init() -> void:
		name = "FairleadSpool"
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func build(s_mesh: ArrayMesh, s_mat: StandardMaterial3D) -> void:
		if mesh != null:
			return
		mesh = s_mesh
		material_override = s_mat

	func sync(origin: Vector3, toward: Vector3, spool_angle: float) -> void:
		var kept_scale := scale
		var dir := toward - origin
		var fwd := dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
		var up := Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.96 else Vector3.RIGHT
		var rot := (Basis.looking_at(fwd, up) * Basis(Vector3.RIGHT, spool_angle)).scaled(kept_scale)
		if is_inside_tree():
			global_position = origin
			global_basis = rot
		else:
			position = origin
			basis = rot



static func make_head() -> HarpoonHead:
	var head := HarpoonHead.new()
	head.build(body_mesh(), core_mesh(), jaw_mesh(), metal_material())
	return head


static func make_spool() -> FairleadSpool:
	var spool := FairleadSpool.new()
	spool.build(spool_mesh(), spool_material())
	return spool


static func metal_material() -> StandardMaterial3D:
	if _metal_mat == null:
		_metal_mat = Palette.solid(Color.WHITE, 0.0)
		_metal_mat.vertex_color_use_as_albedo = true
		_metal_mat.roughness = 0.42
		_metal_mat.metallic = 0.58
		_metal_mat.rim_enabled = true
		_metal_mat.rim = 0.45
		_metal_mat.rim_tint = 0.25
	return _metal_mat


static func spool_material() -> StandardMaterial3D:
	if _spool_mat == null:
		_spool_mat = Palette.solid(Color.WHITE, 0.0)
		_spool_mat.vertex_color_use_as_albedo = true
		_spool_mat.roughness = 0.46
		_spool_mat.metallic = 0.52
	return _spool_mat


static func ink_material(over := true) -> StandardMaterial3D:
	if over:
		if _ink_mat == null:
			_ink_mat = StandardMaterial3D.new()
			_ink_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_ink_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_ink_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_ink_mat.no_depth_test = true
			_ink_mat.render_priority = 9
			_ink_mat.albedo_color = Palette.CHARCOAL
		return _ink_mat
	if _cable_ink_mat == null:
		_cable_ink_mat = StandardMaterial3D.new()
		_cable_ink_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cable_ink_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cable_ink_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cable_ink_mat.no_depth_test = false
		_cable_ink_mat.render_priority = 0
		_cable_ink_mat.albedo_color = Palette.CHARCOAL
	return _cable_ink_mat


static func body_mesh() -> ArrayMesh:
	if _body_mesh != null:
		return _body_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var iron := Palette.CHARCOAL
	var dark_iron := Palette.CHARCOAL.darkened(0.25)
	var rim_steel := Palette.SAND.lerp(Palette.STEEL, 0.28)
	var copper := Palette.COPPER.lightened(0.16)
	var dark_copper := Palette.CHARCOAL.lerp(Palette.COPPER, 0.35)

	var profile := [
		[0.34, 0.055, dark_iron],
		[0.30, 0.095, iron],
		[0.24, 0.095, iron],
		[0.21, 0.165, rim_steel],
		[0.16, 0.175, iron],
		[0.13, 0.125, dark_iron],
		[0.11, 0.160, copper],
		[0.08, 0.160, copper],
		[0.065, 0.120, dark_copper],
		[0.05, 0.162, copper],
		[0.02, 0.162, copper],
		[0.005, 0.120, dark_copper],
		[-0.01, 0.160, copper],
		[-0.04, 0.160, copper],
		[-0.055, 0.125, dark_iron],
		[-0.08, 0.185, rim_steel],
		[-0.17, 0.185, iron],
		[-0.21, 0.135, dark_iron],
		[-0.31, 0.095, iron],
		[-0.41, 0.032, rim_steel],
	]
	_add_lathe(st, profile, 8)
	_body_mesh = st.commit()
	return _body_mesh


static func core_mesh() -> ArrayMesh:
	if _core_mesh != null:
		return _core_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Palette.ARC
	var profile := [
		[-0.17, 0.155, c],
		[-0.19, 0.180, c],
		[-0.26, 0.180, c],
		[-0.28, 0.148, c],
	]
	_add_lathe(st, profile, 8)
	_core_mesh = st.commit()
	return _core_mesh


static func jaw_mesh() -> ArrayMesh:
	if _jaw_mesh != null:
		return _jaw_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body_col := Palette.CHARCOAL
	var edge_col := Palette.SAND.lerp(Palette.STEEL, 0.22)
	var barb_col := Palette.SAND.lightened(0.12)

	var poly := [
		Vector2(-0.04, 0.06),
		Vector2(0.055, 0.05),
		Vector2(0.115, -0.10),
		Vector2(0.085, -0.28),
		Vector2(-0.045, -0.40),
		Vector2(-0.085, -0.31),
		Vector2(-0.020, -0.25),
		Vector2(-0.055, -0.14),
		Vector2(-0.035, -0.04),
	]
	_add_beveled_extrusion(st, poly, 0.032, 0.012, body_col, edge_col, barb_col)
	_jaw_mesh = st.commit()
	return _jaw_mesh


static func spool_mesh() -> ArrayMesh:
	if _spool_mesh != null:
		return _spool_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var iron := Palette.CHARCOAL.lerp(Palette.STEEL, 0.35)
	var dark := Palette.CHARCOAL
	var copper := Palette.COPPER
	var cable_col := Palette.CABLE.lerp(Palette.STEEL, 0.22)
	var profile := [
		[0.14, 0.06, dark],
		[0.13, 0.175, iron],
		[0.10, 0.175, copper],
		[0.09, 0.105, cable_col],
		[0.04, 0.118, cable_col],
		[0.00, 0.108, cable_col],
		[-0.04, 0.118, cable_col],
		[-0.09, 0.105, cable_col],
		[-0.10, 0.175, copper],
		[-0.13, 0.175, iron],
		[-0.14, 0.06, dark],
	]
	_add_lathe(st, profile, 10, Basis(Vector3.UP, PI * 0.5))
	_spool_mesh = st.commit()
	return _spool_mesh



static func _add_lathe(st: SurfaceTool, profile: Array, sides: int, xform := Basis.IDENTITY) -> void:
	var rings: Array = []
	var cols: Array[Color] = []
	for row in profile:
		var z := float(row[0])
		var r := float(row[1])
		var col: Color = row[2]
		var ring: Array[Vector3] = []
		for i in sides:
			var a := TAU * float(i) / float(sides)
			ring.append(xform * Vector3(cos(a) * r, sin(a) * r, z))
		rings.append(ring)
		cols.append(col)

	var n_rings := rings.size()
	for r_idx in n_rings - 1:
		var r0: Array = rings[r_idx]
		var r1: Array = rings[r_idx + 1]
		var c0: Color = cols[r_idx]
		var c1: Color = cols[r_idx + 1]
		var v0_uv := float(r_idx) / float(n_rings - 1)
		var v1_uv := float(r_idx + 1) / float(n_rings - 1)
		for i in sides:
			var j := (i + 1) % sides
			var u0 := float(i) / float(sides)
			var u1 := float(i + 1) / float(sides)
			_emit_tri(st, r0[i], r0[j], r1[j], Vector2(u0, v0_uv), Vector2(u1, v0_uv), Vector2(u1, v1_uv), c0, c0, c1)
			_emit_tri(st, r0[i], r1[j], r1[i], Vector2(u0, v0_uv), Vector2(u1, v1_uv), Vector2(u0, v1_uv), c0, c1, c1)

	var back_center: Vector3 = xform * Vector3(0.0, 0.0, float(profile[0][0]))
	var back_ring: Array = rings[0]
	var back_col: Color = cols[0]
	for i in sides:
		var j := (i + 1) % sides
		_emit_tri(st, back_center, back_ring[j], back_ring[i], Vector2(0.5, 0.5), Vector2(1.0, 0.5), Vector2(0.5, 1.0), back_col, back_col, back_col)

	var front_center: Vector3 = xform * Vector3(0.0, 0.0, float(profile[n_rings - 1][0]))
	var front_ring: Array = rings[n_rings - 1]
	var front_col: Color = cols[n_rings - 1]
	for i in sides:
		var j := (i + 1) % sides
		_emit_tri(st, front_center, front_ring[i], front_ring[j], Vector2(0.5, 0.5), Vector2(1.0, 0.5), Vector2(0.5, 1.0), front_col, front_col, front_col)


static func _add_beveled_extrusion(st: SurfaceTool, poly: Array, half_h: float, bevel: float,
		body_col: Color, edge_col: Color, tip_col: Color) -> void:
	var n := poly.size()
	var center_2d := Vector2.ZERO
	for p in poly:
		center_2d += p as Vector2
	center_2d /= float(n)

	var top_in: Array[Vector3] = []
	var top_out: Array[Vector3] = []
	var bot_out: Array[Vector3] = []
	var bot_in: Array[Vector3] = []
	var col_of: Array[Color] = []
	for p_v in poly:
		var p: Vector2 = p_v
		var inset := p.lerp(center_2d, 0.22)
		top_in.append(Vector3(inset.x, half_h, inset.y))
		top_out.append(Vector3(p.x, half_h - bevel, p.y))
		bot_out.append(Vector3(p.x, -(half_h - bevel), p.y))
		bot_in.append(Vector3(inset.x, -half_h, inset.y))
		col_of.append(tip_col if p.y < -0.26 else body_col)

	var top_c := Vector3(center_2d.x, half_h, center_2d.y)
	var bot_c := Vector3(center_2d.x, -half_h, center_2d.y)
	for i in n:
		var j := (i + 1) % n
		var ci: Color = col_of[i]
		var cj: Color = col_of[j]
		var u0 := float(i) / float(n)
		var u1 := float(i + 1) / float(n)
		_emit_tri(st, top_c, top_in[j], top_in[i], Vector2(0.5, 0.5), Vector2(u1, 0.0), Vector2(u0, 0.0), body_col, cj, ci)
		_emit_quad_ccw(st, top_in[i], top_in[j], top_out[j], top_out[i], u0, u1, 0.0, 0.3, edge_col, edge_col)
		_emit_quad_ccw(st, top_out[i], top_out[j], bot_out[j], bot_out[i], u0, u1, 0.3, 0.7, ci, cj)
		_emit_quad_ccw(st, bot_out[i], bot_out[j], bot_in[j], bot_in[i], u0, u1, 0.7, 1.0, edge_col, edge_col)
		_emit_tri(st, bot_c, bot_in[i], bot_in[j], Vector2(0.5, 0.5), Vector2(u0, 1.0), Vector2(u1, 1.0), body_col, ci, cj)


static func _emit_quad_ccw(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		u0: float, u1: float, v0: float, v1: float, ca: Color, cb: Color) -> void:
	_emit_tri(st, a, b, c, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), ca, cb, cb)
	_emit_tri(st, a, c, d, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1), ca, cb, ca)


static func _emit_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	var n := (c - a).cross(b - a)
	n = n.normalized() if n.length_squared() > 1.0e-12 else Vector3.UP
	st.set_normal(n)
	st.set_uv(ua)
	st.set_color(ca)
	st.add_vertex(a)
	st.set_normal(n)
	st.set_uv(ub)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_normal(n)
	st.set_uv(uc)
	st.set_color(cc)
	st.add_vertex(c)
