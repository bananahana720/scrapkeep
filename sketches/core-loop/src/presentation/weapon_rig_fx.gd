extends Node3D


const BallLooks := preload("res://src/presentation/ball_looks.gd")
const CraftedGear := preload("res://src/presentation/crafted_ball_gear.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const InkOutline := preload("res://src/presentation/ink_outline.gd")
const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const Parts := preload("res://src/build/parts.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")

const NODE_NAME := "WeaponRigFx"
const MOD_IDS := ["pierce", "chain_arc", "frost", "split", "spiral_bounce"]

const RECOIL_KICK := 0.18
const RECOIL_STIFFNESS := 195.0
const RECOIL_DAMPING := 19.0
const RECOIL_MAX := 0.22
const REDUCED_RECOIL_SCALE := 0.35

const SPIN_IDLE := 0.55
const SPIN_KICK := 10.5
const SPIN_MAX := 17.5
const SPIN_DECAY := 3.4

const HEAT_KICK := 0.24
const HEAT_DECAY := 0.55

const FROST_TINT := Color("9dd6e8")

var _active_mods: Array[String] = []
var _mod_nodes := {}
var _spinners: Array[Node3D] = []
var _heat_materials: Array[StandardMaterial3D] = []
var _ring_mount: Node3D
var _carriage: Node3D
var _weapon_ref: Node3D

var _recoil := 0.0
var _recoil_vel := 0.0
var _spin_rate := SPIN_IDLE
var _spin_angle := 0.0
var _heat := 0.0
var _last_fire_seq := -1
var _last_sig := ""
var _cutaway_dressed := false

static var _mesh_cache := {}


static func clear_cache() -> void:
	_mesh_cache.clear()


static func ensure_on(ring: Node3D) -> Node3D:
	if ring == null or not is_instance_valid(ring):
		return null
	var existing := ring.get_node_or_null(NODE_NAME) as Node3D
	if existing != null:
		return existing
	var script := load("res://src/presentation/weapon_rig_fx.gd") as GDScript
	var rig := script.new() as Node3D
	rig.name = NODE_NAME
	ring.add_child(rig)
	return rig


static func mods_for(shot_bits_mask: int, tags: Array) -> Array[String]:
	var tag_set := {}
	for t in tags:
		tag_set[String(t)] = true
	var out: Array[String] = []
	if ShotBits.has(shot_bits_mask, ShotBits.bit("pierce")) or tag_set.has("kinetic") or tag_set.has("mass"):
		out.append("pierce")
	if ShotBits.has(shot_bits_mask, ShotBits.bit("heat")) or tag_set.has("arc") or tag_set.has("chain") or tag_set.has("splice") or tag_set.has("line"):
		out.append("chain_arc")
	if tag_set.has("frost"):
		out.append("frost")
	if ShotBits.has(shot_bits_mask, ShotBits.bit("split")) or tag_set.has("split"):
		out.append("split")
	if ShotBits.has(shot_bits_mask, ShotBits.bit("bounce")) or ShotBits.has(shot_bits_mask, ShotBits.bit("pull")) \
			or tag_set.has("spiral"):
		out.append("spiral_bounce")
	return out


static func tags_from_parts(part_ids: Array) -> Array[String]:
	var out: Array[String] = []
	var seen := {}
	for pid in part_ids:
		var d: Resource = Parts.def(String(pid))
		if d == null:
			continue
		for tag in d.tags:
			var s := String(tag)
			if not seen.has(s):
				seen[s] = true
				out.append(s)
	return out


func active_mods() -> Array[String]:
	return _active_mods.duplicate()


func recoil_offset() -> float:
	return _recoil


func heat_level() -> float:
	return _heat


func spin_angle() -> float:
	return _spin_angle


func spin_rate() -> float:
	return _spin_rate


func sync_build(shot_bits_mask: int, part_ids: Array) -> void:
	var tags := tags_from_parts(part_ids)
	set_build_mods(shot_bits_mask, tags)


func dress_cutaway() -> void:
	if _cutaway_dressed:
		return
	var ring_mount := get_node_or_null("RingMount")
	if ring_mount != null:
		BallLooks.cut_kit(ring_mount, "")
		InkOutline.apply(ring_mount, "pilot")
	_cutaway_dressed = true


func set_build_mods(shot_bits_mask: int, tags: Array) -> void:
	var want := mods_for(shot_bits_mask, tags)
	var sig := ",".join(want)
	if sig == _last_sig:
		return
	_last_sig = sig
	_active_mods = want
	_rebuild_attachments()


func on_shot_fired(shot_kind := "plain", strength := 1.0) -> void:
	var mult := clampf(strength, 0.5, 1.8)
	if shot_kind in ["charged", "rail", "barrage", "hot", "beat_3"]:
		mult *= 1.35
	_recoil = minf(RECOIL_MAX, _recoil + RECOIL_KICK * mult)
	_recoil_vel = maxf(_recoil_vel, 1.2 * mult)
	_spin_rate = minf(SPIN_MAX, _spin_rate + SPIN_KICK * mult)
	_heat = minf(1.0, _heat + HEAT_KICK * mult)


func step(delta: float, driver_snap: Dictionary = {}, reduced_motion := false) -> void:
	var dt := clampf(delta, 0.0, 0.08)
	if not driver_snap.is_empty():
		var seq := int(driver_snap.get("fire_seq", -1))
		if seq >= 0 and _last_fire_seq >= 0 and seq > _last_fire_seq:
			on_shot_fired(String(driver_snap.get("last_shot_kind", "plain")), 1.0)
		if seq >= 0:
			_last_fire_seq = seq
	var charge := clampf(float(driver_snap.get("charge", 0.0)), 0.0, 1.0)
	var reloading := bool(driver_snap.get("reloading", false))

	if absf(_recoil) > 0.0001 or absf(_recoil_vel) > 0.0001:
		var accel := -RECOIL_STIFFNESS * _recoil - RECOIL_DAMPING * _recoil_vel
		_recoil_vel += accel * dt
		_recoil = clampf(_recoil + _recoil_vel * dt, -0.02, RECOIL_MAX)
		if absf(_recoil) < 0.0004 and absf(_recoil_vel) < 0.004:
			_recoil = 0.0
			_recoil_vel = 0.0

	var target_spin := SPIN_IDLE + charge * 6.0 + (4.5 if reloading else 0.0)
	_spin_rate = lerpf(_spin_rate, target_spin, 1.0 - exp(-SPIN_DECAY * dt))
	var motion_scale := REDUCED_RECOIL_SCALE if reduced_motion else 1.0
	_spin_angle = fmod(_spin_angle + _spin_rate * motion_scale * dt, TAU * 64.0)

	var heat_floor := charge * 0.72
	_heat = maxf(heat_floor, maxf(0.0, _heat - HEAT_DECAY * dt))

	_apply_kinematics(motion_scale)
	_apply_heat_glow()


func _apply_kinematics(motion_scale: float) -> void:
	var kick := maxf(0.0, _recoil) * motion_scale
	if _carriage != null and is_instance_valid(_carriage):
		_carriage.position = Vector3(0.0, 0.0, kick)
	var parent := get_parent() as Node3D
	if parent != null:
		var weapon := parent.get_node_or_null("Weapon") as Node3D
		if weapon != null:
			if not weapon.has_meta("rig_fx_rest_pos"):
				weapon.set_meta("rig_fx_rest_pos", weapon.position)
			var rest: Vector3 = weapon.get_meta("rig_fx_rest_pos")
			weapon.position = rest + Vector3(0.0, 0.0, kick * 0.45)
			_weapon_ref = weapon
	for i in _spinners.size():
		var spinner := _spinners[i]
		if not is_instance_valid(spinner):
			continue
		var axis: String = String(spinner.get_meta("spin_axis", "z"))
		var dir: float = float(spinner.get_meta("spin_dir", 1.0))
		if axis == "x":
			spinner.rotation.x = _spin_angle * dir
		elif axis == "y":
			spinner.rotation.y = _spin_angle * dir
		else:
			spinner.rotation.z = _spin_angle * dir


func _apply_heat_glow() -> void:
	if _heat_materials.is_empty():
		return
	var rest_energy := 0.22
	var peak_energy := lerpf(rest_energy, 2.1, _heat)
	var safe_energy := FlashGuard.spike(rest_energy, peak_energy)
	var hot_col := Palette.COPPER.lerp(Palette.AMBER, clampf(_heat * 1.15, 0.0, 1.0))
	for mat in _heat_materials:
		if not is_instance_valid(mat):
			continue
		var base_col: Color = mat.get_meta("heat_base_emit", Palette.COPPER)
		mat.emission = base_col.lerp(hot_col, clampf(_heat, 0.0, 1.0))
		mat.emission_energy_multiplier = safe_energy


func reset_fx() -> void:
	_recoil = 0.0
	_recoil_vel = 0.0
	_spin_rate = SPIN_IDLE
	_spin_angle = 0.0
	_heat = 0.0
	_last_fire_seq = -1
	_apply_kinematics(1.0)
	_apply_heat_glow()
	if _weapon_ref != null and is_instance_valid(_weapon_ref) and _weapon_ref.has_meta("rig_fx_rest_pos"):
		_weapon_ref.position = _weapon_ref.get_meta("rig_fx_rest_pos")


func _rebuild_attachments() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_mod_nodes.clear()
	_spinners.clear()
	_heat_materials.clear()
	_ring_mount = null
	_carriage = null
	_cutaway_dressed = false
	if _active_mods.is_empty():
		return
	_ring_mount = Node3D.new()
	_ring_mount.name = "RingMount"
	add_child(_ring_mount)
	_carriage = Node3D.new()
	_carriage.name = "RecoilCarriage"
	add_child(_carriage)
	for mod_id in _active_mods:
		var built := _build_mod(mod_id)
		if built != null:
			var target := _ring_mount if mod_id in ["chain_arc", "frost"] else _carriage
			target.add_child(built)
			_mod_nodes[mod_id] = built
	InkOutline.apply(_ring_mount, "pilot", _heat_materials)
	InkOutline.apply(_carriage, "pilot", _heat_materials)
	_apply_kinematics(1.0)
	_apply_heat_glow()


func _build_mod(mod_id: String) -> Node3D:
	match mod_id:
		"pierce":
			return _make_pierce_rails()
		"chain_arc":
			return _make_tesla_prongs()
		"frost":
			return _make_cryo_fins()
		"split":
			return _make_rotary_drum()
		"spiral_bounce":
			return _make_gyro_muzzle()
	return null


func _mat(color: Color, metal := 0.36, rough := 0.64, emit := 0.0, heat_reactive := false) -> StandardMaterial3D:
	var m := PaletteMaterials.solid(color, emit)
	m.metallic = metal
	m.roughness = rough
	m.metallic_specular = 0.32
	m.albedo_texture = PaletteMaterials.painted_texture(128)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 3.2
	m.vertex_color_use_as_albedo = true
	if heat_reactive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = maxf(emit, 0.22)
		m.set_meta("heat_base_emit", color)
		_heat_materials.append(m)
	return m


func _mesh_node(node_name: String, mesh: ArrayMesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	if mat in _heat_materials:
		mi.material_override = mat
	else:
		mi.set_surface_override_material(0, mat)
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _ring_outer_radius_at(dir_xz: Vector2, half_cone_cos := 0.94, y_limit := 0.24) -> float:
	var ring := get_parent() as Node3D
	if ring == null:
		return 1.086
	var d := dir_xz.normalized()
	var best := 1.086
	var meshes: Array[MeshInstance3D] = []
	if ring is MeshInstance3D and (ring as MeshInstance3D).mesh != null:
		meshes.append(ring as MeshInstance3D)
	for child in ring.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null or is_ancestor_of(mi):
			continue
		var rel := String(ring.get_path_to(mi))
		if rel.begins_with("Weapon/"):
			continue
		meshes.append(mi)
	var ring_inv := ring.global_transform.affine_inverse()
	for mi in meshes:
		var xf := ring_inv * mi.global_transform if ring.is_inside_tree() and mi.is_inside_tree() else mi.transform
		for s in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var q := xf * v
				if absf(q.y) > y_limit:
					continue
				var p2 := Vector2(q.x, q.z)
				var r := p2.length()
				if r > 0.2 and (p2 / r).dot(d) >= half_cone_cos:
					best = maxf(best, r)
	return best


func _make_pierce_rails() -> Node3D:
	var root := Node3D.new()
	root.name = "Mod_pierce"
	var clamp_mat := _mat(Palette.CHARCOAL.lerp(Palette.SLATE, 0.22), 0.32, 0.76)
	var steel_mat := _mat(Palette.SLATE.lerp(Palette.SAND, 0.20), 0.44, 0.58)
	var core_mat := _mat(Palette.LEDGER, 0.12, 0.44, 0.85, true)
	var front_r := _ring_outer_radius_at(Vector2(0.0, -1.0), 0.90, 0.24)
	var collar_z := -(front_r + 0.048)
	var rail_z := -(front_r + 0.445)
	var collar_mesh := _cached_mesh("mod_pierce_collar", func(st: SurfaceTool) -> void:
		CraftedGear.add_beveled_box(st, Transform3D.IDENTITY, Vector3(0.56, 0.12, 0.08), 0.016,
			Color(0.84, 0.85, 0.86), Color(0.96, 0.95, 0.92))
		for sx in [-0.26, 0.26]:
			CraftedGear.add_beveled_box(st, Transform3D(Basis.IDENTITY, Vector3(sx, 0.0, -0.10)),
				Vector3(0.085, 0.085, 0.16), 0.012, Color(0.78, 0.80, 0.82), Color(0.95, 0.94, 0.90))
		for sx in [-0.22, 0.0, 0.22]:
			CraftedGear.add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(sx, 0.076, 0.0)), 0.022, 0.026, 0.034, 6,
				Color(0.98, 0.95, 0.86), Color(0.76, 0.76, 0.78))
	)
	var rail_mesh := _cached_mesh("mod_pierce_rail", func(st: SurfaceTool) -> void:
		CraftedGear.add_beveled_box(st, Transform3D.IDENTITY, Vector3(0.11, 0.12, 0.42), 0.020,
			Color(0.88, 0.90, 0.92), Color(1.0, 0.98, 0.92))
		for dz in [-0.13, 0.0, 0.13]:
			CraftedGear.add_beveled_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.075, dz)),
				Vector3(0.135, 0.045, 0.060), 0.010, Color(0.72, 0.74, 0.76), Color(0.98, 0.96, 0.90))
	)
	var strip_mesh := _cached_mesh("mod_pierce_strip", func(st: SurfaceTool) -> void:
		CraftedGear.add_beveled_box(st, Transform3D.IDENTITY, Vector3(0.040, 0.048, 0.36), 0.008,
			Color.WHITE, Color.WHITE)
	)
	if _ring_mount != null:
		_ring_mount.add_child(_mesh_node("PierceCollarClamp", collar_mesh, clamp_mat, Vector3(0.0, 0.02, collar_z)))
	for sx in [-0.26, 0.26]:
		root.add_child(_mesh_node("Rail_%s" % ("L" if sx < 0.0 else "R"), rail_mesh, steel_mat, Vector3(sx, 0.02, rail_z)))
		root.add_child(_mesh_node("Core_%s" % ("L" if sx < 0.0 else "R"), strip_mesh, core_mat, Vector3(sx * 0.68, 0.02, rail_z - 0.01)))
	return root


func _make_tesla_prongs() -> Node3D:
	var root := Node3D.new()
	root.name = "Mod_chain_arc"
	var clamp_mat := _mat(Palette.CHARCOAL.lerp(Palette.SLATE, 0.22), 0.32, 0.76)
	var copper_mat := _mat(Palette.COPPER, 0.48, 0.56)
	var arc_mat := _mat(Palette.ARC, 0.10, 0.42, 0.95, true)
	var clamp_mesh := _cached_mesh("mod_tesla_clamp", func(st: SurfaceTool) -> void:
		CraftedGear.add_beveled_box(st, Transform3D.IDENTITY, Vector3(0.14, 0.14, 0.14), 0.020,
			Color(0.82, 0.83, 0.84), Color(0.96, 0.94, 0.90))
	)
	var prong_mesh := _cached_mesh("mod_tesla_prong", func(st: SurfaceTool) -> void:
		var rot_x := Basis(Vector3.RIGHT, PI * 0.5)
		CraftedGear.add_cylinder(st, Transform3D(rot_x, Vector3(0.0, 0.0, -0.22)), 0.030, 0.048, 0.40, 10,
			Color(0.96, 0.90, 0.80), Color(1.0, 0.96, 0.88))
		for dz in [-0.10, -0.21, -0.32]:
			CraftedGear.add_cylinder(st, Transform3D(rot_x, Vector3(0.0, 0.0, dz)), 0.072, 0.072, 0.030, 10,
				Color(0.70, 0.72, 0.75), Color(0.98, 0.95, 0.88))
	)
	var tip_mesh := _cached_mesh("mod_tesla_tip", func(st: SurfaceTool) -> void:
		CraftedGear.add_faceted_orb(st, Transform3D.IDENTITY, 0.052, 8, 5, Color.WHITE, Color(0.82, 0.94, 0.92))
	)
	for side in [-1.0, 1.0]:
		var holder := Node3D.new()
		holder.name = "TeslaProng_%s" % ("L" if side < 0.0 else "R")
		var brow_dir := Vector2(side * 0.454, -0.891).normalized()
		var brow_r := _ring_outer_radius_at(brow_dir, 0.95, 0.22) + 0.082
		holder.position = Vector3(brow_dir.x * brow_r, 0.05, brow_dir.y * brow_r)
		holder.rotation = Vector3(0.06, side * -0.14, 0.0)
		holder.add_child(_mesh_node("Clamp", clamp_mesh, clamp_mat))
		holder.add_child(_mesh_node("Body", prong_mesh, copper_mat))
		holder.add_child(_mesh_node("Corona", tip_mesh, arc_mat, Vector3(0.0, 0.0, -0.44)))
		root.add_child(holder)
	return root


func _make_cryo_fins() -> Node3D:
	var root := Node3D.new()
	root.name = "Mod_frost"
	var fin_mat := _mat(FROST_TINT.lerp(Palette.SLATE, 0.30), 0.28, 0.68, 0.10)
	var manifold_mat := _mat(Palette.CHARCOAL.lerp(Palette.SLATE, 0.25), 0.34, 0.74)
	var cap_mesh := _cached_mesh("mod_frost_cap", func(st: SurfaceTool) -> void:
		CraftedGear.add_beveled_box(st, Transform3D.IDENTITY, Vector3(0.12, 0.065, 0.48), 0.014,
			Color(0.76, 0.78, 0.80), Color(0.94, 0.95, 0.96))
	)
	for side in [-1.0, 1.0]:
		var side_tag := "L" if side < 0.0 else "R"
		var fin_mesh := _cached_mesh("mod_frost_fin_bank_" + side_tag, func(st: SurfaceTool) -> void:
			CraftedGear.add_beveled_box(st, Transform3D.IDENTITY, Vector3(0.08, 0.22, 0.44), 0.014,
				Color(0.76, 0.82, 0.86), Color(0.95, 0.98, 1.0))
			for i in 4:
				var dz := -0.14 + float(i) * 0.095
				CraftedGear.add_beveled_box(st, Transform3D(Basis(Vector3.UP, side * 0.26), Vector3(side * 0.08, 0.0, dz)),
					Vector3(0.13, 0.24, 0.034), 0.008, Color(0.90, 0.95, 0.98), Color(0.98, 0.99, 1.0))
		)
		var bank := Node3D.new()
		bank.name = "CryoFins_" + side_tag
		var aft_dir := Vector2(side * 0.616, 0.788).normalized()
		var aft_r := _ring_outer_radius_at(aft_dir, 0.90, 0.26) + 0.076
		bank.position = Vector3(aft_dir.x * aft_r, 0.05, aft_dir.y * aft_r)
		bank.rotation = Vector3(0.0, side * -0.90, 0.0)
		bank.add_child(_mesh_node("Louvers", fin_mesh, fin_mat))
		bank.add_child(_mesh_node("CapTop", cap_mesh, manifold_mat, Vector3(side * 0.02, 0.135, 0.0)))
		bank.add_child(_mesh_node("CapBot", cap_mesh, manifold_mat, Vector3(side * 0.02, -0.135, 0.0)))
		root.add_child(bank)
	return root


func _make_rotary_drum() -> Node3D:
	var root := Node3D.new()
	root.name = "Mod_split"
	var front_r := _ring_outer_radius_at(Vector2(0.0, -1.0), 0.90, 0.24)
	var drum_z := -(front_r + 0.435)
	var brass_mat := _mat(Palette.BRASS, 0.46, 0.56)
	var steel_mat := _mat(Palette.CHARCOAL.lerp(Palette.SAND, 0.18), 0.36, 0.74)
	var drum_mesh := _cached_mesh("mod_split_drum", func(st: SurfaceTool) -> void:
		var rot_x := Basis(Vector3.RIGHT, PI * 0.5)
		CraftedGear.add_cylinder(st, Transform3D(rot_x, Vector3.ZERO), 0.135, 0.135, 0.26, 12,
			Color(0.92, 0.87, 0.76), Color(1.0, 0.96, 0.86))
		for k in 6:
			var a := float(k) * TAU / 6.0
			var off := Vector3(cos(a) * 0.115, sin(a) * 0.115, 0.0)
			var c_body := Color(0.28, 0.30, 0.34) if k == 0 else Color(0.98, 0.93, 0.80)
			var c_edge := Color(0.98, 0.96, 0.90) if k == 0 else Color(0.78, 0.74, 0.66)
			var rad := 0.056 if k == 0 else 0.044
			CraftedGear.add_cylinder(st, Transform3D(rot_x, off), rad, rad, 0.29, 8, c_body, c_edge)
	)
	var yoke_mesh := _cached_mesh("mod_split_yoke", func(st: SurfaceTool) -> void:
		CraftedGear.add_beveled_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.12, 0.08)), Vector3(0.32, 0.15, 0.055), 0.012,
			Color(0.76, 0.77, 0.78), Color(0.94, 0.93, 0.90))
		CraftedGear.add_beveled_box(st, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.15, 0.0)), Vector3(0.30, 0.065, 0.28), 0.014,
			Color(0.74, 0.75, 0.76), Color(0.94, 0.93, 0.90))
	)
	root.add_child(_mesh_node("Yoke", yoke_mesh, steel_mat, Vector3(0.0, -0.22, drum_z)))
	var spinner := _mesh_node("RotaryDrum", drum_mesh, brass_mat, Vector3(0.0, -0.22, drum_z))
	spinner.set_meta("spin_axis", "z")
	spinner.set_meta("spin_dir", 1.0)
	root.add_child(spinner)
	_spinners.append(spinner)
	return root


func _make_gyro_muzzle() -> Node3D:
	var root := Node3D.new()
	root.name = "Mod_spiral_bounce"
	var front_r := _ring_outer_radius_at(Vector2(0.0, -1.0), 0.90, 0.24)
	var strut_z := -(front_r + 0.685)
	var gyro_z := -(front_r + 0.825)
	var clamp_mat := _mat(Palette.CHARCOAL.lerp(Palette.SLATE, 0.22), 0.34, 0.74)
	var brass_mat := _mat(Palette.BRASS.lerp(Palette.COPPER, 0.25), 0.48, 0.56)
	var core_mat := _mat(Palette.COPPER.lerp(Palette.AMBER, 0.35), 0.32, 0.48, 0.42, true)
	var bridge_mesh := _cached_mesh("mod_gyro_bridge", func(st: SurfaceTool) -> void:
		CraftedGear.add_beveled_box(st, Transform3D.IDENTITY, Vector3(0.06, 0.06, 0.10), 0.010,
			Color(0.78, 0.79, 0.80), Color(0.95, 0.94, 0.90))
	)
	var ring_mesh := _cached_mesh("mod_gyro_ring", func(st: SurfaceTool) -> void:
		var rot_x := Basis(Vector3.RIGHT, PI * 0.5)
		CraftedGear.add_torus(st, Transform3D(rot_x, Vector3.ZERO), 0.22, 0.036, 18, 8,
			Color(0.96, 0.92, 0.82), Color(0.74, 0.70, 0.64))
		for k in 3:
			var a := float(k) * TAU / 3.0
			var is_index := k == 0
			var r_lug := 0.275 if is_index else 0.242
			var lug := Vector3(cos(a) * r_lug, sin(a) * r_lug, 0.0)
			var sz := Vector3(0.13, 0.056, 0.095) if is_index else Vector3(0.064, 0.044, 0.072)
			var col_a := Color(0.28, 0.30, 0.34) if is_index else Color(0.98, 0.95, 0.86)
			CraftedGear.add_beveled_box(st, Transform3D(Basis(Vector3.FORWARD, a), lug),
				sz, 0.009, col_a, Color(0.96, 0.93, 0.84))
	)
	var inner_mesh := _cached_mesh("mod_gyro_inner", func(st: SurfaceTool) -> void:
		var rot_x := Basis(Vector3.RIGHT, PI * 0.5)
		CraftedGear.add_torus(st, Transform3D(rot_x, Vector3.ZERO), 0.145, 0.026, 16, 6,
			Color(1.0, 0.95, 0.84), Color(0.80, 0.78, 0.74))
		for tooth_deg: float in [0.0, 135.0]:
			var a := deg_to_rad(tooth_deg)
			var is_main := tooth_deg < 1.0
			var r_in := 0.105 if is_main else 0.118
			var pos := Vector3(cos(a) * r_in, sin(a) * r_in, 0.0)
			var sz := Vector3(0.088, 0.044, 0.068) if is_main else Vector3(0.062, 0.036, 0.056)
			CraftedGear.add_beveled_box(st, Transform3D(Basis(Vector3.FORWARD, a), pos),
				sz, 0.007, Color(0.16, 0.18, 0.22), Color(0.45, 0.42, 0.38))
	)
	for sx in [-0.26, 0.26]:
		root.add_child(_mesh_node("Strut_%s" % ("L" if sx < 0.0 else "R"), bridge_mesh, clamp_mat, Vector3(sx, 0.02, strut_z)))
	var outer := _mesh_node("GyroOuter", ring_mesh, brass_mat, Vector3(0.0, 0.0, gyro_z))
	outer.set_meta("spin_axis", "z")
	outer.set_meta("spin_dir", 1.0)
	var inner := _mesh_node("GyroInner", inner_mesh, core_mat, Vector3(0.0, 0.0, gyro_z), Vector3(0.32, 0.0, 0.0))
	inner.set_meta("spin_axis", "z")
	inner.set_meta("spin_dir", -1.45)
	root.add_child(outer)
	root.add_child(inner)
	_spinners.append(outer)
	_spinners.append(inner)
	return root


static func _cached_mesh(key: String, builder: Callable) -> ArrayMesh:
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.call(st)
	st.generate_normals()
	st.generate_tangents()
	var mesh := st.commit()
	mesh.resource_name = key
	_mesh_cache[key] = mesh
	return mesh
