class_name VistaMegastructures
extends Node3D


const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/core/flash_guard.gd")
const Comfort := preload("res://src/core/comfort.gd")

const COMBAT_EXCLUSION_RADIUS_M := 160.0
const MIN_VISTA_DISTANCE_M := 180.0
const MAX_VISTA_DISTANCE_M := 650.0

const CRANE_SPECS := [
	{"name": "SalvageCrane_NW", "pos": Vector3(-148.0, -18.0, -228.0), "height": 124.0, "boom": 72.0, "yaw_deg": 22.0, "rotor_speed": 0.42},
	{"name": "SalvageCrane_NE", "pos": Vector3(156.0, -18.0, -236.0), "height": 130.0, "boom": 76.0, "yaw_deg": -148.0, "rotor_speed": -0.34},
	{"name": "SalvageCrane_FarW", "pos": Vector3(-258.0, -20.0, -352.0), "height": 152.0, "boom": 84.0, "yaw_deg": 48.0, "rotor_speed": 0.28},
	{"name": "SalvageCrane_FarE", "pos": Vector3(268.0, -20.0, -372.0), "height": 146.0, "boom": 80.0, "yaw_deg": -128.0, "rotor_speed": -0.31},
]

const SMOKESTACK_SPECS := [
	{"name": "SmelterStack_W1", "pos": Vector3(-92.0, -18.0, -264.0), "height": 106.0, "base_r": 9.5, "top_r": 5.4, "vent_energy": 3.0},
	{"name": "SmelterStack_W2", "pos": Vector3(-56.0, -18.0, -330.0), "height": 122.0, "base_r": 11.0, "top_r": 6.2, "vent_energy": 3.2},
	{"name": "SmelterStack_E1", "pos": Vector3(102.0, -18.0, -274.0), "height": 112.0, "base_r": 10.2, "top_r": 5.8, "vent_energy": 3.1},
	{"name": "SmelterStack_E2", "pos": Vector3(150.0, -18.0, -342.0), "height": 134.0, "base_r": 11.8, "top_r": 6.5, "vent_energy": 3.3},
	{"name": "SmelterStack_Far", "pos": Vector3(44.0, -20.0, -438.0), "height": 148.0, "base_r": 13.0, "top_r": 7.2, "vent_energy": 2.9},
]

const PIER_SPECS := [
	{"name": "HorizonPier_W1", "pos": Vector3(-196.0, -18.0, -172.0), "width": 30.0, "height": 94.0, "depth": 36.0, "yaw_deg": 18.0},
	{"name": "HorizonPier_E1", "pos": Vector3(198.0, -18.0, -176.0), "width": 30.0, "height": 98.0, "depth": 36.0, "yaw_deg": -16.0},
	{"name": "HorizonPier_W2", "pos": Vector3(-282.0, -20.0, -296.0), "width": 38.0, "height": 122.0, "depth": 44.0, "yaw_deg": 10.0},
	{"name": "HorizonPier_E2", "pos": Vector3(288.0, -20.0, -304.0), "width": 38.0, "height": 126.0, "depth": 44.0, "yaw_deg": -12.0},
	{"name": "CanyonRidge_W", "pos": Vector3(-355.0, -22.0, -478.0), "width": 270.0, "height": 152.0, "depth": 125.0, "yaw_deg": 14.0},
	{"name": "CanyonRidge_E", "pos": Vector3(362.0, -22.0, -488.0), "width": 280.0, "height": 160.0, "depth": 130.0, "yaw_deg": -12.0},
]

const BASIN_SHELVES := [
	{"name": "CanyonBasin_LowerDeck", "pos": Vector3(0.0, -48.0, -355.0), "size": Vector3(760.0, 62.0, 420.0)},
	{"name": "CanyonBasin_MidTerrace", "pos": Vector3(0.0, -25.0, -275.0), "size": Vector3(440.0, 22.0, 150.0)},
	{"name": "CanyonBasin_WestSlope", "pos": Vector3(-240.0, -36.0, -250.0), "size": Vector3(280.0, 48.0, 260.0)},
	{"name": "CanyonBasin_EastSlope", "pos": Vector3(245.0, -36.0, -255.0), "size": Vector3(280.0, 48.0, 260.0)},
]

const ORBITAL_RING_POS := Vector3(-10.0, -16.0, -448.0)
const ORBITAL_RING_RADIUS_M := 304.0
const ORBITAL_RING_TUBE_W := 28.0
const ORBITAL_RING_TUBE_H := 22.0

var _built := false
var _records: Array[Dictionary] = []
var _rotors: Array[Dictionary] = []
var _vent_materials: Array[Dictionary] = []
var _plume_tex: ImageTexture
var _anim_time := 0.0


func _ready() -> void:
	build_all()


func _process(delta: float) -> void:
	step_animation(delta)


func build_all() -> void:
	if _built:
		return
	_built = true
	_records.clear()
	_rotors.clear()
	_vent_materials.clear()
	_plume_tex = _make_soft_cloud_texture(64)

	var mats := _build_materials()
	_build_canyon_basin(mats)
	_build_orbital_launch_ring(mats)
	_build_salvage_cranes(mats)
	_build_smelter_smokestacks(mats)
	_build_horizon_piers(mats)
	apply_accessibility()


func apply_accessibility() -> void:
	for entry in _vent_materials:
		var mat: StandardMaterial3D = entry["material"]
		var rest: float = entry["base_energy"]
		if is_instance_valid(mat):
			mat.emission_energy_multiplier = FlashGuard.spike(rest * 0.7, rest)


func step_animation(delta: float) -> void:
	if not _built or delta <= 0.0:
		return
	if not Comfort.reduced_motion:
		_anim_time += delta
		for entry in _rotors:
			var rotor: Node3D = entry["node"]
			if is_instance_valid(rotor):
				rotor.rotate_z(float(entry["speed"]) * delta)
	var pulse_hz := FlashGuard.rate(0.32)
	for i in _vent_materials.size():
		var entry: Dictionary = _vent_materials[i]
		var mat: StandardMaterial3D = entry["material"]
		if not is_instance_valid(mat):
			continue
		var base_e: float = entry["base_energy"]
		if Comfort.reduced_motion:
			mat.emission_energy_multiplier = FlashGuard.spike(base_e * 0.7, base_e)
		else:
			var wave := 0.5 + 0.5 * sin(_anim_time * TAU * pulse_hz + float(i) * 1.17)
			var peak := base_e * lerpf(0.88, 1.18, wave)
			mat.emission_energy_multiplier = FlashGuard.spike(base_e * 0.88, peak)


func get_vista_records() -> Array[Dictionary]:
	return _records.duplicate(true)


func get_rotor_count() -> int:
	return _rotors.size()


func _record_vista(node_name: String, kind: String, pos: Vector3, height_m: float) -> void:
	var horizontal_m := Vector2(pos.x, pos.z).length()
	_records.append({
		"name": node_name,
		"kind": kind,
		"position": pos,
		"distance_m": horizontal_m,
		"height_m": height_m,
	})


func _build_materials() -> Dictionary:
	var old_works := StandardMaterial3D.new()
	old_works.albedo_color = Palette.CHARCOAL.lerp(Palette.VERDIGRIS, 0.24)
	old_works.roughness = 0.68
	old_works.metallic = 0.42
	_apply_vista_patina(old_works, 12.0, 36.0, 0.45)

	var crane_steel := StandardMaterial3D.new()
	crane_steel.albedo_color = Palette.CHARCOAL.lerp(Palette.MAST_STEEL, 0.34)
	crane_steel.roughness = 0.70
	crane_steel.metallic = 0.46

	var crane_oxide := StandardMaterial3D.new()
	crane_oxide.albedo_color = Palette.RUST.lerp(Palette.CHARCOAL, 0.54)
	crane_oxide.roughness = 0.84
	crane_oxide.metallic = 0.18
	_apply_vista_patina(crane_oxide, 8.0, 26.0, 0.45)

	var stack_iron := StandardMaterial3D.new()
	stack_iron.albedo_color = Palette.CHARCOAL.lerp(Palette.SANDSTONE, 0.18)
	stack_iron.roughness = 0.88
	stack_iron.metallic = 0.24
	_apply_vista_patina(stack_iron, 7.5, 22.0, 0.65)

	var pier_concrete := StandardMaterial3D.new()
	pier_concrete.albedo_color = Palette.CHARCOAL.lerp(Palette.SANDSTONE, 0.32)
	pier_concrete.roughness = 0.92
	pier_concrete.metallic = 0.04
	_apply_vista_patina(pier_concrete, 6.0, 18.0, 0.70)

	var mesa_rock := StandardMaterial3D.new()
	mesa_rock.albedo_color = Palette.CHARCOAL.lerp(Palette.SANDSTONE, 0.28).lerp(Palette.RUST, 0.18)
	mesa_rock.roughness = 0.96
	mesa_rock.metallic = 0.0
	_apply_vista_patina(mesa_rock, 14.0, 42.0, 0.60)

	var basin_floor := StandardMaterial3D.new()
	basin_floor.albedo_color = Palette.CHARCOAL.lerp(Palette.SANDSTONE, 0.16)
	basin_floor.roughness = 0.95
	basin_floor.metallic = 0.05

	var ancient_seam := StandardMaterial3D.new()
	ancient_seam.albedo_color = Palette.ANCIENT
	ancient_seam.roughness = 0.35
	ancient_seam.emission_enabled = true
	ancient_seam.emission = Palette.ANCIENT
	ancient_seam.emission_energy_multiplier = 3.8

	var plume_mats: Array[StandardMaterial3D] = []
	for alpha in [0.22, 0.14, 0.07]:
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.76, 0.67, 0.59, alpha)
		pm.albedo_texture = _plume_tex
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		pm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		plume_mats.append(pm)

	return {
		"old_works": old_works,
		"crane_steel": crane_steel,
		"crane_oxide": crane_oxide,
		"stack_iron": stack_iron,
		"pier_concrete": pier_concrete,
		"mesa_rock": mesa_rock,
		"basin_floor": basin_floor,
		"ancient_seam": ancient_seam,
		"plume_tiers": plume_mats,
	}


func _apply_vista_patina(mat: StandardMaterial3D, grain_m: float, grime_m: float, normal_strength: float) -> void:
	Palette.surface_grain(mat)
	mat.normal_scale = normal_strength
	mat.uv1_scale = Vector3.ONE / grain_m
	mat.uv2_scale = Vector3.ONE / grime_m


func _make_vent_material(energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Palette.SODIUM
	mat.roughness = 0.4
	mat.emission_enabled = true
	mat.emission = Palette.SODIUM.lerp(Palette.AMBER, 0.35)
	mat.emission_energy_multiplier = energy
	_vent_materials.append({"material": mat, "base_energy": energy})
	return mat


func _build_canyon_basin(mats: Dictionary) -> void:
	var basin_root := Node3D.new()
	basin_root.name = "CanyonBasinFloor"
	add_child(basin_root)
	for shelf in BASIN_SHELVES:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_append_box(st, Transform3D(Basis.IDENTITY, Vector3.ZERO), shelf["size"] as Vector3)
		var mi := _add_surface_mesh(basin_root, String(shelf["name"]), st, mats["basin_floor"])
		mi.position = shelf["pos"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_record_vista(String(shelf["name"]), "canyon_basin", shelf["pos"], (shelf["size"] as Vector3).y)

	var trestle_st := SurfaceTool.new()
	trestle_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(trestle_st, Transform3D(Basis.IDENTITY, Vector3(0.0, 3.0, -188.0)), Vector3(440.0, 4.2, 18.0))
	for px in [-144.0, -108.0, -72.0, -36.0, 0.0, 36.0, 72.0, 108.0, 144.0]:
		_append_box(trestle_st, Transform3D(Basis.IDENTITY, Vector3(px, -11.0, -188.0)), Vector3(11.0, 28.0, 20.0))
		_append_box(trestle_st, Transform3D(Basis.IDENTITY, Vector3(px, -16.0, -180.0)), Vector3(14.0, 14.0, 10.0))
	for ax in [-126.0, -90.0, -54.0, -18.0, 18.0, 54.0, 90.0, 126.0]:
		_append_box(trestle_st, Transform3D(Basis.IDENTITY, Vector3(ax, -1.2, -188.0)), Vector3(25.0, 3.8, 14.0))
	var trestle := _add_surface_mesh(basin_root, "HorizonAqueductTrestle", trestle_st, mats["pier_concrete"])
	trestle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_record_vista("HorizonAqueductTrestle", "horizon_pier", Vector3(0.0, 3.0, -188.0), 28.0)

	var floor_st := SurfaceTool.new()
	floor_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(floor_st, Transform3D(Basis.IDENTITY, Vector3(0.0, -16.5, -225.0)), Vector3(540.0, 7.0, 175.0))
	_append_box(floor_st, Transform3D(Basis.IDENTITY, Vector3(-95.0, -12.0, -215.0)), Vector3(110.0, 4.0, 90.0))
	_append_box(floor_st, Transform3D(Basis.IDENTITY, Vector3(95.0, -12.0, -215.0)), Vector3(110.0, 4.0, 90.0))
	var canyon_floor := _add_surface_mesh(basin_root, "CanyonSpillwayFloor", floor_st, mats["mesa_rock"])
	canyon_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_record_vista("CanyonSpillwayFloor", "canyon_basin", Vector3(0.0, -16.5, -225.0), 7.0)


func _build_orbital_launch_ring(mats: Dictionary) -> void:
	var ring_root := Node3D.new()
	ring_root.name = "OrbitalLaunchRing"
	ring_root.position = ORBITAL_RING_POS
	ring_root.rotation_degrees = Vector3(-8.0, 6.0, -12.0)
	add_child(ring_root)

	var hull_st := SurfaceTool.new()
	hull_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rib_st := SurfaceTool.new()
	rib_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seam_st := SurfaceTool.new()
	seam_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var arcs := [
		{"start_deg": 8.0, "end_deg": 94.0, "steps": 18},
		{"start_deg": 112.0, "end_deg": 176.0, "steps": 14},
	]
	for arc in arcs:
		var steps: int = arc["steps"]
		var a0 := deg_to_rad(float(arc["start_deg"]))
		var a1 := deg_to_rad(float(arc["end_deg"]))
		for i in steps:
			var t0 := float(i) / float(steps)
			var t1 := float(i + 1) / float(steps)
			var ang0 := lerpf(a0, a1, t0)
			var ang1 := lerpf(a0, a1, t1)
			var mid := (ang0 + ang1) * 0.5
			var seg_len := (ang1 - ang0) * ORBITAL_RING_RADIUS_M * 1.03
			var radial_dir := Vector3(cos(mid), sin(mid), 0.0)
			var tangent_dir := Vector3(-sin(mid), cos(mid), 0.0)
			var seg_basis := Basis(tangent_dir, radial_dir, Vector3.BACK).orthonormalized()
			var seg_pos := radial_dir * ORBITAL_RING_RADIUS_M

			_append_box(hull_st, Transform3D(seg_basis, seg_pos), Vector3(seg_len, ORBITAL_RING_TUBE_H, ORBITAL_RING_TUBE_W))
			_append_box(hull_st, Transform3D(seg_basis, seg_pos - radial_dir * 14.0), Vector3(seg_len * 0.94, 6.0, ORBITAL_RING_TUBE_W * 0.62))

			if i % 2 == 0:
				_append_box(rib_st, Transform3D(seg_basis, seg_pos + radial_dir * 4.0), Vector3(5.6, ORBITAL_RING_TUBE_H + 16.0, ORBITAL_RING_TUBE_W + 10.0))
				_append_box(rib_st, Transform3D(seg_basis, seg_pos - radial_dir * 23.0), Vector3(4.0, 20.0, 12.0))
			if i % 3 == 1:
				_append_box(seam_st, Transform3D(seg_basis, seg_pos - radial_dir * 9.0 + Vector3(0.0, 0.0, ORBITAL_RING_TUBE_W * 0.54)), Vector3(seg_len * 0.62, 2.4, 1.6))

		for end_deg in [float(arc["end_deg"]), float(arc["start_deg"])]:
			if end_deg > 90.0 and end_deg < 116.0:
				var er := deg_to_rad(end_deg)
				var rdir := Vector3(cos(er), sin(er), 0.0)
				var tdir := Vector3(-sin(er), cos(er), 0.0)
				var dir_sign := 1.0 if end_deg < 103.0 else -1.0
				var b := Basis(tdir, rdir, Vector3.BACK).orthonormalized()
				for k in 3:
					var stub_off := rdir * (float(k - 1) * 7.8) + Vector3(0.0, 0.0, float(k - 1) * 6.0)
					_append_box(rib_st, Transform3D(b, rdir * ORBITAL_RING_RADIUS_M + stub_off + tdir * (dir_sign * (11.0 + float(k) * 5.5))), Vector3(24.0 + float(k) * 7.5, 3.0, 3.4))

	_add_surface_mesh(ring_root, "RingHullMesh", hull_st, mats["old_works"])
	_add_surface_mesh(ring_root, "RingRibsMesh", rib_st, mats["crane_steel"])
	_add_surface_mesh(ring_root, "RingAncientSeams", seam_st, mats["ancient_seam"])

	_record_vista(ring_root.name, "orbital_launch_ring", ORBITAL_RING_POS, ORBITAL_RING_RADIUS_M)


func _build_salvage_cranes(mats: Dictionary) -> void:
	var cranes_root := Node3D.new()
	cranes_root.name = "SalvageCraneTowers"
	add_child(cranes_root)

	for spec in CRANE_SPECS:
		var tower := Node3D.new()
		tower.name = spec["name"]
		tower.position = spec["pos"]
		tower.rotation_degrees = Vector3(0.0, float(spec["yaw_deg"]), 0.0)
		cranes_root.add_child(tower)

		var h: float = spec["height"]
		var boom: float = spec["boom"]
		var steel_st := SurfaceTool.new()
		steel_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var oxide_st := SurfaceTool.new()
		oxide_st.begin(Mesh.PRIMITIVE_TRIANGLES)

		_append_box(oxide_st, Transform3D(Basis.IDENTITY, Vector3(0.0, -24.0, 0.0)), Vector3(26.0, 68.0, 26.0))
		var bays := 6
		var bay_h := (h - 10.0) / float(bays)
		for b in bays:
			var y0 := 10.0 + float(b) * bay_h
			var y1 := y0 + bay_h
			var w0 := lerpf(9.5, 4.2, float(b) / float(bays))
			var w1 := lerpf(9.5, 4.2, float(b + 1) / float(bays))
			var corners0 := [Vector3(-w0, y0, -w0), Vector3(w0, y0, -w0), Vector3(w0, y0, w0), Vector3(-w0, y0, w0)]
			var corners1 := [Vector3(-w1, y1, -w1), Vector3(w1, y1, -w1), Vector3(w1, y1, w1), Vector3(-w1, y1, w1)]
			for c in 4:
				var cn := (c + 1) % 4
				_append_strut(steel_st, corners0[c], corners1[c], 1.7)
				_append_strut(steel_st, corners1[c], corners1[cn], 1.15)
				_append_strut(steel_st, corners0[c], corners1[cn], 0.95)
				_append_strut(steel_st, corners0[cn], corners1[c], 0.95)

		_append_box(oxide_st, Transform3D(Basis.IDENTITY, Vector3(-11.0, h + 3.0, 0.0)), Vector3(19.0, 10.0, 11.5))
		_append_box(steel_st, Transform3D(Basis.IDENTITY, Vector3(4.0, h + 15.0, 0.0)), Vector3(5.2, 22.0, 5.2))

		var jib_tip := Vector3(boom, h + 18.0, 0.0)
		var jib_root := Vector3(-18.0, h + 2.0, 0.0)
		var peak := Vector3(4.0, h + 26.0, 0.0)
		_append_strut(steel_st, jib_root + Vector3(0.0, 0.0, -3.2), jib_tip + Vector3(0.0, 0.0, -1.6), 1.55)
		_append_strut(steel_st, jib_root + Vector3(0.0, 0.0, 3.2), jib_tip + Vector3(0.0, 0.0, 1.6), 1.55)
		_append_strut(steel_st, jib_root + Vector3(0.0, 5.4, 0.0), jib_tip + Vector3(0.0, 2.4, 0.0), 1.35)
		_append_strut(steel_st, peak, jib_tip, 0.95)
		_append_strut(steel_st, peak, jib_root, 1.05)
		for s in 5:
			var f := float(s + 1) / 6.0
			var p := jib_root.lerp(jib_tip, f)
			_append_strut(steel_st, p + Vector3(0.0, 0.0, -2.5), p + Vector3(0.0, 4.2, 0.0), 0.8)
			_append_strut(steel_st, p + Vector3(0.0, 0.0, 2.5), p + Vector3(0.0, 4.2, 0.0), 0.8)

		var hook_top := jib_root.lerp(jib_tip, 0.78)
		var hook_bot := hook_top + Vector3(0.0, -34.0, 0.0)
		_append_strut(steel_st, hook_top + Vector3(0.0, 0.0, -1.3), hook_bot + Vector3(0.0, 0.0, -1.3), 0.55)
		_append_strut(steel_st, hook_top + Vector3(0.0, 0.0, 1.3), hook_bot + Vector3(0.0, 0.0, 1.3), 0.55)
		_append_box(oxide_st, Transform3D(Basis.IDENTITY, hook_bot), Vector3(8.0, 6.0, 7.0))

		_add_surface_mesh(tower, "LatticeSteel", steel_st, mats["crane_steel"])
		_add_surface_mesh(tower, "OxideHousing", oxide_st, mats["crane_oxide"])

		var rotor := Node3D.new()
		rotor.name = "SlowRotor"
		rotor.position = Vector3(4.0, h + 28.0, 5.0)
		tower.add_child(rotor)
		var rotor_st := SurfaceTool.new()
		rotor_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_append_box(rotor_st, Transform3D(Basis.IDENTITY, Vector3.ZERO), Vector3(5.6, 5.6, 4.2))
		for blade_i in 4:
			var ang := float(blade_i) * PI * 0.5 + 0.35
			var b := Basis(Vector3.BACK, ang)
			_append_box(rotor_st, Transform3D(b, b * Vector3(0.0, 14.5, 0.0)), Vector3(3.4, 26.0, 1.0))
			_append_box(rotor_st, Transform3D(b, b * Vector3(1.5, 20.0, 0.4)), Vector3(4.4, 11.5, 0.8))
		_add_surface_mesh(rotor, "RotorBlades", rotor_st, mats["crane_steel"])
		_rotors.append({"node": rotor, "speed": float(spec["rotor_speed"])})

		_record_vista(tower.name, "salvage_crane_tower", spec["pos"], h + 28.0)


func _build_smelter_smokestacks(mats: Dictionary) -> void:
	var stacks_root := Node3D.new()
	stacks_root.name = "SmelterSmokestacks"
	add_child(stacks_root)

	var plume_tiers: Array = mats["plume_tiers"]
	for spec in SMOKESTACK_SPECS:
		var stack := Node3D.new()
		stack.name = spec["name"]
		stack.position = spec["pos"]
		stacks_root.add_child(stack)

		var h: float = spec["height"]
		var r0: float = spec["base_r"]
		var r1: float = spec["top_r"]

		var body_st := SurfaceTool.new()
		body_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var band_st := SurfaceTool.new()
		band_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vent_st := SurfaceTool.new()
		vent_st.begin(Mesh.PRIMITIVE_TRIANGLES)

		_append_box(body_st, Transform3D(Basis.IDENTITY, Vector3(0.0, -24.0, 0.0)), Vector3(r0 * 2.1, 84.0, r0 * 2.1))
		_append_frustum(body_st, Vector3(0.0, 16.0, 0.0), h - 16.0, r0, r1, 12)
		_append_frustum(band_st, Vector3(0.0, h - 7.0, 0.0), 7.5, r1 * 1.04, r1 * 1.38, 12)
		for ring_i in 4:
			var frac := 0.25 + float(ring_i) * 0.19
			var ry := lerpf(20.0, h - 10.0, frac)
			var rr := lerpf(r0, r1, frac) * 1.12
			_append_frustum(band_st, Vector3(0.0, ry, 0.0), 2.4, rr, rr, 12)

		_append_frustum(vent_st, Vector3(0.0, h + 0.2, 0.0), 2.8, r1 * 0.92, r1 * 1.10, 12)
		_append_box(vent_st, Transform3D(Basis.IDENTITY, Vector3(0.0, 12.0, r0 * 1.06)), Vector3(r0 * 1.1, 4.4, 1.4))

		_add_surface_mesh(stack, "StackBody", body_st, mats["stack_iron"])
		_add_surface_mesh(stack, "StackBands", band_st, mats["crane_steel"])
		_add_surface_mesh(stack, "HotVentGlow", vent_st, _make_vent_material(float(spec["vent_energy"])))

		var plume_root := Node3D.new()
		plume_root.name = "SoftSmokePlume"
		stack.add_child(plume_root)
		var puff_count := 22
		for p_i in puff_count:
			var frac := float(p_i) / float(puff_count - 1)
			var quad := QuadMesh.new()
			var puff_size := r1 * lerpf(3.4, 11.8, pow(frac, 0.72))
			quad.size = Vector2(puff_size, puff_size * 0.88)
			var puff := MeshInstance3D.new()
			puff.name = "Puff_%d" % p_i
			puff.mesh = quad
			var tier_idx := 0 if frac < 0.35 else (1 if frac < 0.72 else 2)
			puff.material_override = plume_tiers[tier_idx]
			var billow_x := sin(float(p_i) * 1.4 + r0) * 5.5 * frac
			var billow_y := cos(float(p_i) * 1.1 + r1) * 3.5 * frac
			var drift_x := pow(frac, 1.35) * 68.0 + billow_x
			var rise_y := h + 4.0 + frac * 78.0 + billow_y
			var drift_z := -frac * 22.0
			puff.position = Vector3(drift_x, rise_y, drift_z)
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			plume_root.add_child(puff)

		_record_vista(stack.name, "smelter_smokestack", spec["pos"], h)


func _build_horizon_piers(mats: Dictionary) -> void:
	var piers_root := Node3D.new()
	piers_root.name = "HorizonFramingPiers"
	add_child(piers_root)

	for spec in PIER_SPECS:
		var is_ridge: bool = String(spec["name"]).begins_with("CanyonRidge")
		var pier := Node3D.new()
		pier.name = spec["name"]
		pier.position = spec["pos"]
		pier.rotation_degrees = Vector3(0.0, float(spec["yaw_deg"]), 0.0)
		piers_root.add_child(pier)

		var w: float = spec["width"]
		var h: float = spec["height"]
		var d: float = spec["depth"]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		if is_ridge:
			_append_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.14, 0.0)), Vector3(w, h * 1.25, d))
			_append_box(st, Transform3D(Basis.IDENTITY, Vector3(-w * 0.12, h * 0.78, -d * 0.08)), Vector3(w * 0.62, h * 0.34, d * 0.72))
			_append_box(st, Transform3D(Basis.IDENTITY, Vector3(w * 0.22, h * 0.66, d * 0.05)), Vector3(w * 0.44, h * 0.28, d * 0.65))
			_add_surface_mesh(pier, "MesaSilhouette", st, mats["mesa_rock"])
		else:
			_append_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.20, 0.0)), Vector3(w, h * 1.60, d))
			_append_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, h + 3.5, 0.0)), Vector3(w * 1.28, 7.0, d * 1.22))
			_append_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.16, d * 0.54)), Vector3(w * 0.56, h * 1.20, d * 0.28))
			_append_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.16, -d * 0.54)), Vector3(w * 0.56, h * 1.20, d * 0.28))
			_add_surface_mesh(pier, "PierConcrete", st, mats["pier_concrete"])

			var cap_st := SurfaceTool.new()
			cap_st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_append_box(cap_st, Transform3D(Basis.IDENTITY, Vector3(0.0, h + 11.0, 0.0)), Vector3(w * 0.75, 8.0, d * 0.6))
			_add_surface_mesh(pier, "PierTopCap", cap_st, mats["crane_steel"])

		_record_vista(pier.name, "canyon_ridge" if is_ridge else "horizon_pier", spec["pos"], h)


func _add_surface_mesh(parent: Node3D, mesh_name: String, st: SurfaceTool, mat: Material) -> MeshInstance3D:
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


static func _make_soft_cloud_texture(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var half := float(size) * 0.5
	for y in size:
		for x in size:
			var dx := (float(x) + 0.5 - half) / half
			var dy := (float(y) + 0.5 - half) / half
			var r := sqrt(dx * dx + dy * dy)
			var wisp := 0.82 + 0.18 * sin(dx * 5.2 + dy * 2.8) * cos(dy * 4.6 - dx * 2.4)
			var a := clampf((1.0 - smoothstep(0.08, 0.96, r)) * wisp, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a * a))
	return ImageTexture.create_from_image(img)


static func _append_box(st: SurfaceTool, xform: Transform3D, size: Vector3) -> void:
	var h := size * 0.5
	var p := [
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
		Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z),
	]
	var faces := [
		[0, 1, 2, 3],
		[4, 5, 6, 7],
		[1, 4, 7, 2],
		[5, 0, 3, 6],
		[3, 2, 7, 6],
		[5, 4, 1, 0],
	]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for f in faces:
		var v0 := xform * (p[f[0]] as Vector3)
		var v1 := xform * (p[f[1]] as Vector3)
		var v2 := xform * (p[f[2]] as Vector3)
		var v3 := xform * (p[f[3]] as Vector3)
		st.set_uv(uvs[0]); st.add_vertex(v0)
		st.set_uv(uvs[3]); st.add_vertex(v3)
		st.set_uv(uvs[2]); st.add_vertex(v2)
		st.set_uv(uvs[0]); st.add_vertex(v0)
		st.set_uv(uvs[2]); st.add_vertex(v2)
		st.set_uv(uvs[1]); st.add_vertex(v1)


static func _append_strut(st: SurfaceTool, a: Vector3, b: Vector3, thickness: float) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.01:
		return
	var dir := delta / length
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var side := dir.cross(up).normalized()
	var ortho := side.cross(dir).normalized()
	var strut_basis := Basis(side, dir, ortho)
	_append_box(st, Transform3D(strut_basis, (a + b) * 0.5), Vector3(thickness, length, thickness))


static func _append_frustum(st: SurfaceTool, base_pos: Vector3, height: float, r_bottom: float, r_top: float, sides: int) -> void:
	var top_pos := base_pos + Vector3(0.0, height, 0.0)
	for i in sides:
		var a0 := float(i) / float(sides) * TAU
		var a1 := float(i + 1) / float(sides) * TAU
		var b0 := base_pos + Vector3(cos(a0) * r_bottom, 0.0, sin(a0) * r_bottom)
		var b1 := base_pos + Vector3(cos(a1) * r_bottom, 0.0, sin(a1) * r_bottom)
		var t0 := top_pos + Vector3(cos(a0) * r_top, 0.0, sin(a0) * r_top)
		var t1 := top_pos + Vector3(cos(a1) * r_top, 0.0, sin(a1) * r_top)
		st.set_uv(Vector2(0, 1)); st.add_vertex(b0)
		st.set_uv(Vector2(1, 1)); st.add_vertex(b1)
		st.set_uv(Vector2(1, 0)); st.add_vertex(t1)
		st.set_uv(Vector2(0, 1)); st.add_vertex(b0)
		st.set_uv(Vector2(1, 0)); st.add_vertex(t1)
		st.set_uv(Vector2(0, 0)); st.add_vertex(t0)
		st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(top_pos)
		st.set_uv(Vector2(0, 0)); st.add_vertex(t0)
		st.set_uv(Vector2(1, 0)); st.add_vertex(t1)
