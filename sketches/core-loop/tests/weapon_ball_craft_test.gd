extends SceneTree


const Accretion := preload("res://src/build/accretion.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const CraftedGear := preload("res://src/presentation/crafted_ball_gear.gd")
const FlashGuard := preload("res://src/core/flash_guard.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")
const Synergies := preload("res://src/build/synergies.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")
const WeaponRigFx := preload("res://src/presentation/weapon_rig_fx.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("weapon_ball_craft_test")


func _initialize() -> void:
	_run.call_deferred()


class _MockShotBus:
	extends RefCounted
	signal shot_fired(pos: Vector3, dir: Vector3, weapon_id: String)


class _MockBuild:
	extends RefCounted
	var mask := 0
	func shot_bits() -> int:
		return mask


func _run() -> void:
	_check_crafted_meshes()
	_check_accretion_no_primitives()
	_check_weapon_rig_and_driver()
	_check_six_pilot_rig_clearance()
	_check_single_source_shot_kick()
	_check_bolts_shader_and_mesh()
	CraftedGear.clear_cache()
	WeaponRigFx.clear_cache()
	FlashGuard.on = false
	quit(_t.verdict())


static func _manifold_check(mesh: ArrayMesh) -> Dictionary:
	var edge_counts := {}
	var bad_normals := 0
	var zero_area := 0
	var tris := 0
	var has_uv := false
	var signed_vol := 0.0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs = arrays[Mesh.ARRAY_TEX_UV]
		var indices = arrays[Mesh.ARRAY_INDEX]
		if uvs != null and uvs.size() == verts.size():
			has_uv = true
		for n in normals:
			if not n.is_finite() or absf(n.length() - 1.0) > 0.05:
				bad_normals += 1
		var count: int = indices.size() if indices != null and indices.size() > 0 else verts.size()
		var i := 0
		while i + 2 < count:
			var ia: int = indices[i] if indices != null and indices.size() > 0 else i
			var ib: int = indices[i + 1] if indices != null and indices.size() > 0 else i + 1
			var ic: int = indices[i + 2] if indices != null and indices.size() > 0 else i + 2
			var va := verts[ia]
			var vb := verts[ib]
			var vc := verts[ic]
			var ka := _vkey(va)
			var kb := _vkey(vb)
			var kc := _vkey(vc)
			if ka != kb and kb != kc and kc != ka:
				tris += 1
				if (vb - va).cross(vc - va).length() < 1e-9:
					zero_area += 1
				signed_vol += va.dot(vc.cross(vb)) / 6.0
				for pair in [[ka, kb], [kb, kc], [kc, ka]]:
					var a: String = pair[0]
					var b: String = pair[1]
					var ek := (a + "|" + b) if a < b else (b + "|" + a)
					edge_counts[ek] = int(edge_counts.get(ek, 0)) + 1
			i += 3
	var open_edges := 0
	var non_manifold := 0
	for c in edge_counts.values():
		if int(c) == 1:
			open_edges += 1
		elif int(c) > 2:
			non_manifold += 1
	return {"tris": tris, "open": open_edges, "non_manifold": non_manifold, "bad_normals": bad_normals,
		"zero_area": zero_area, "has_uv": has_uv, "outward": signed_vol > 0.0, "vol": snappedf(signed_vol, 0.0001)}


static func _vkey(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x * 2000.0), roundi(v.y * 2000.0), roundi(v.z * 2000.0)]


func _check_crafted_meshes() -> void:
	for i in CraftedGear.CHUNK_VARIANTS.size():
		var m := CraftedGear.chunk_mesh(i)
		var st := _manifold_check(m)
		_t.check("chunk %s is watertight outward manifold ArrayMesh with unit normals & UVs" % CraftedGear.chunk_variant(i),
			m is ArrayMesh and st.tris >= 24 and st.open == 0 and st.non_manifold == 0 and st.bad_normals == 0
			and st.zero_area == 0 and st.has_uv and st.outward,
			str(st))
	for pair in [
		["cross_split", "weapon"], ["spiral_wave", "weapon"], ["chain_arc", "weapon"],
		["hot_rivets", "weapon"], ["dash_vane", "mobility"], ["x", "class"], ["y", "milestone"], ["rivet_plating", "stat"],
	]:
		var pm := CraftedGear.part_mesh(pair[0], pair[1])
		var pst := _manifold_check(pm)
		_t.check("part %s/%s is watertight outward manifold ArrayMesh" % [pair[0], pair[1]],
			pm is ArrayMesh and pst.tris >= 24 and pst.open == 0 and pst.non_manifold == 0 and pst.bad_normals == 0
			and pst.zero_area == 0 and pst.has_uv and pst.outward,
			str(pst))
	var ring := CraftedGear.synergy_ring_mesh(1.2, 1.28)
	var rst := _manifold_check(ring)
	_t.check("synergy ring is watertight outward manifold ArrayMesh",
		ring is ArrayMesh and rst.tris >= 64 and rst.open == 0 and rst.non_manifold == 0 and rst.bad_normals == 0
		and rst.zero_area == 0 and rst.has_uv and rst.outward,
		str(rst))
	var dart := CraftedGear.bolt_dart_mesh()
	var dst := _manifold_check(dart)
	var aabb := dart.get_aabb()
	_t.check("bolt fluted dart is watertight outward manifold 16-lobe ArrayMesh along -Z..+Z",
		dart is ArrayMesh and dst.tris >= 192 and dst.open == 0 and dst.non_manifold == 0 and dst.bad_normals == 0
		and dst.zero_area == 0 and dst.has_uv and dst.outward and absf(aabb.size.z - 1.0) < 0.02,
		"stats=%s aabb=%s" % [dst, aabb])


func _check_accretion_no_primitives() -> void:
	var acc := Accretion.new()
	acc.setup()
	root.add_child(acc)
	var parts := ["hot_rivets", "cross_split", "spiral_wave", "chain_arc", "dash_vane", "rivet_plating"]
	acc.show_build(200.0, parts, Synergies.ROWS.keys(), 3)
	var prims := []
	var chunk_meshes_seen := {}
	for mi: MeshInstance3D in acc.find_children("*", "MeshInstance3D", true, false):
		var p := mi.get_parent()
		if p != null and String(p.name).begins_with("Foot_"):
			continue
		if mi.mesh is PrimitiveMesh:
			prims.append("%s:%s" % [mi.name, mi.mesh.get_class()])
		if p == acc and mi.mesh != null:
			chunk_meshes_seen[mi.mesh.resource_name] = true
	_t.check("accretion creates zero PrimitiveMesh chunks, parts, or halos", prims.is_empty(), str(prims))
	_t.check("accretion cycles through all 4 crafted chunk variants", chunk_meshes_seen.size() == 4, str(chunk_meshes_seen.keys()))
	_t.check("accretion preserves chunk & piece counts and heft scale",
		acc.chunk_count() == Accretion.chunks_for(200.0) and acc.piece_count() == parts.size()
		and is_equal_approx(acc.scale.x, Accretion.shell_scale(3, false)),
		"chunks=%d pieces=%d scale=%.2f" % [acc.chunk_count(), acc.piece_count(), acc.scale.x])
	acc.set_lattice(true)
	_t.check("accretion lattice snap keeps chunks at LATTICE_SEAT",
		is_equal_approx(acc.chunk_point(0).length(), Accretion.LATTICE_SEAT), "")
	acc.show_build(140.0, parts, [], 2)
	for _i in 80:
		acc._process(1.0 / 60.0)
	var ring_clips := []
	var arch_clips := []
	var max_part_r := 0.0
	for mi: MeshInstance3D in acc.find_children("*", "MeshInstance3D", true, false):
		var p := mi.get_parent()
		if p != null and String(p.name).begins_with("Foot_"):
			continue
		if p != null and String(p.name).begins_with("Halo_"):
			continue
		if mi.mesh is ArrayMesh:
			var xf := acc.global_transform.affine_inverse() * mi.global_transform
			var verts: PackedVector3Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var q := xf * v
				var r := q.length()
				max_part_r = maxf(max_part_r, r)
				if absf(q.y) < 0.14 and r > 1.04:
					ring_clips.append("%s:%s" % [mi.name, q])
					break
				if q.y > 0.20 and absf(q.z) < 0.44 and absf(q.x) > 0.64 and r > 1.06:
					arch_clips.append("%s:%s" % [mi.name, q])
					break
	_t.check("accretion chunks and parts stay clear of equatorial WeaponRing and overhead arch plane",
		ring_clips.is_empty() and arch_clips.is_empty() and max_part_r <= 1.48,
		"ring_clips=%s arch_clips=%s max_r=%.3f" % [ring_clips, arch_clips, max_part_r])
	acc.free()


func _check_weapon_rig_and_driver() -> void:
	var drv_src := FileAccess.get_file_as_string("res://src/combat/weapon_driver.gd")
	_t.check("weapon_driver.gd keeps zero static vars", not drv_src.contains("static var "), "")

	var drv := WeaponDriver.new()
	var pat: Resource = Weapons.base(Weapons.RAPID_LASER)
	drv.reset(pat)
	var snap0 := drv.state_snapshot()
	var intent := Intent.new()
	intent.fire_pressed = true
	var fired := drv.step(0.016, intent, Weapons.RAPID_LASER, pat, float(pat.rate))
	var snap1 := drv.state_snapshot()
	drv.reset(pat)
	var snap_reset := drv.state_snapshot()
	_t.check("WeaponDriver publishes monotonic fire_seq and last_shot_kind and resets cleanly",
		int(snap0.get("fire_seq", -1)) == 0 and not fired.is_empty()
		and int(snap1.get("fire_seq", 0)) == 1 and String(snap1.get("last_shot_kind", "")) != ""
		and int(snap_reset.get("fire_seq", -1)) == 0,
		"s0=%s s1=%s sr=%s" % [snap0.get("fire_seq"), snap1.get("fire_seq"), snap_reset.get("fire_seq")])

	var holder := Node3D.new()
	root.add_child(holder)
	var hero := HeroAssets.new()
	holder.add_child(hero)
	var ball := Node3D.new()
	holder.add_child(ball)
	var fitted := hero.fit_shell_into(ball, "pylon_engineer", "", 1, {"class": Palette.ARC})
	var pod: Node3D = fitted.get("pod")
	var ring: Node3D = pod.get_node_or_null("WeaponRing") if pod != null else null
	var base_rig := hero.sync_weapon_rig(pod, 0, [])
	_t.check("zero build mods mounts zero WeaponRigFx nodes on base pilot",
		ring != null and base_rig == null and ring.get_node_or_null(WeaponRigFx.NODE_NAME) == null, "")

	var all_bits := ShotBits.bit("pierce") | ShotBits.bit("split") | ShotBits.bit("heat") | ShotBits.bit("bounce")
	var rig := hero.sync_weapon_rig(pod, all_bits, ["hot_rivets", "cross_split", "spiral_wave", "chain_arc", "rime_rounds"])
	_t.check("build-reactive WeaponRigFx mounts all 5 attachment families",
		rig != null and rig.active_mods().size() == 5, str(rig.active_mods() if rig != null else []))
	var rig_prims := []
	var rig_bad_manifold := []
	for mi: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is PrimitiveMesh:
			rig_prims.append(mi.name)
		elif mi.mesh is ArrayMesh:
			var st := _manifold_check(mi.mesh as ArrayMesh)
			if st.open != 0 or st.non_manifold != 0 or st.bad_normals != 0 or st.zero_area != 0 or not st.outward \
					or mi.global_transform.basis.determinant() <= 0.0:
				rig_bad_manifold.append("%s:%s:det=%.2f" % [mi.name, st, mi.global_transform.basis.determinant()])
	_t.check("all WeaponRigFx attachments are watertight manifold ArrayMeshes (0 primitives)",
		rig_prims.is_empty() and rig_bad_manifold.is_empty(),
		"prims=%s bad=%s" % [rig_prims, rig_bad_manifold])

	rig.reset_fx()
	rig.step(1.0 / 60.0, {"fire_seq": 0, "charge": 0.0, "reloading": false}, false)
	var spin0: float = rig.spin_angle()
	rig.step(1.0 / 60.0, {"fire_seq": 1, "last_shot_kind": "charged", "charge": 0.6, "reloading": false}, false)
	var kick1: float = rig.recoil_offset()
	var heat1: float = rig.heat_level()
	var rate1: float = rig.spin_rate()
	var max_deg_per_frame := 0.0
	var max_lat_drift := 0.0
	var min_clearance_r := INF
	var carriage := rig.get_node_or_null("RecoilCarriage") as Node3D
	var prev_spin: float = rig.spin_angle()
	for frame_i in 90:
		rig.step(1.0 / 60.0, {"fire_seq": 1, "charge": 0.0, "reloading": false}, false)
		var cur_spin: float = rig.spin_angle()
		var d_deg := rad_to_deg(absf(cur_spin - prev_spin) * 1.45)
		max_deg_per_frame = maxf(max_deg_per_frame, d_deg)
		prev_spin = cur_spin
		if carriage != null:
			max_lat_drift = maxf(max_lat_drift, Vector2(carriage.position.x, carriage.position.y).length())
		if frame_i < 16:
			for mi: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
				if mi.mesh is ArrayMesh:
					var xf := ball.global_transform.affine_inverse() * mi.global_transform
					var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(0)
					var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					for v in verts:
						min_clearance_r = minf(min_clearance_r, (xf * v).length())
	var settled: float = absf(rig.recoil_offset())
	var spin_after: float = rig.spin_angle()
	_t.check("WeaponRigFx kicks recoil, heats barrel, spins rotors, and springs back cleanly",
		kick1 > 0.10 and heat1 > 0.20 and rate1 > WeaponRigFx.SPIN_IDLE * 4.0 and settled < 0.01 and spin_after > spin0 + 1.0,
		"kick=%.3f heat=%.2f rate=%.1f settled=%.4f dspin=%.2f" % [kick1, heat1, rate1, settled, spin_after - spin0])
	_t.check("60 Hz recoil stays strictly axial, rotors <= 25 deg/frame, and zero vertices clip 1.0 m ball cage/cutaway",
		max_lat_drift < 1e-5 and max_deg_per_frame <= 25.0 and min_clearance_r >= 1.01,
		"lat=%.6f max_deg=%.2f min_r=%.4f" % [max_lat_drift, max_deg_per_frame, min_clearance_r])

	FlashGuard.on = false
	rig.on_shot_fired("charged", 1.5)
	rig.step(0.016, {"charge": 1.0}, false)
	var full_energy := _max_rig_emit(rig)
	FlashGuard.on = true
	rig.step(0.016, {"charge": 1.0}, false)
	var guarded_energy := _max_rig_emit(rig)
	FlashGuard.on = false
	_t.check("WeaponRigFx barrel heat glow honours FlashGuard.spike clamping",
		full_energy > 1.2 and guarded_energy < full_energy * 0.65,
		"full=%.2f guarded=%.2f" % [full_energy, guarded_energy])

	holder.free()


static func _max_rig_emit(rig: Node3D) -> float:
	var best := 0.0
	for mi: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi.material_override as StandardMaterial3D
		if m != null and m.emission_enabled:
			best = maxf(best, m.emission_energy_multiplier)
	return best


static func _frame_verts(ref: Node3D, mi: MeshInstance3D) -> PackedVector3Array:
	var xf := ref.global_transform.affine_inverse() * mi.global_transform
	var out := PackedVector3Array()
	for s in mi.mesh.get_surface_count():
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in verts:
			out.append(xf * v)
	return out


static func _pts_aabb(pts: PackedVector3Array) -> AABB:
	var b := AABB(pts[0], Vector3.ZERO)
	for i in range(1, pts.size()):
		b = b.expand(pts[i])
	return b


static func _aabb_gap(a: AABB, b: AABB) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	var dz := maxf(0.0, maxf(a.position.z - b.end.z, b.position.z - a.end.z))
	if dx == 0.0 and dy == 0.0 and dz == 0.0:
		var inter := a.intersection(b)
		return -minf(inter.size.x, minf(inter.size.y, inter.size.z))
	return Vector3(dx, dy, dz).length()


func _check_six_pilot_rig_clearance() -> void:
	var all_bits := ShotBits.bit("pierce") | ShotBits.bit("split") | ShotBits.bit("heat") | ShotBits.bit("bounce")
	var all_parts := ["hot_rivets", "cross_split", "spiral_wave", "chain_arc", "rime_rounds"]
	var worst_pilot_gap := INF
	var worst_pilot_pair := ""
	var worst_ring_gap := INF
	var worst_ring_pair := ""
	var worst_internal_gap := INF
	var worst_internal_pair := ""
	var min_cage_r := INF
	var max_mount_gap := 0.0
	for mode_name: String in ["cutaway", "today"]:
		var holder := Node3D.new()
		root.add_child(holder)
		var hero: Node = HeroAssets.previewing() if mode_name == "cutaway" else HeroAssets.new()
		holder.add_child(hero)
		for cid: String in HeroAssets.SHELLS.keys():
			var ball := Node3D.new()
			holder.add_child(ball)
			var fitted: Dictionary = hero.fit_shell_into(ball, cid, "", 5, {"class": Palette.ARC})
			var pod: Node3D = fitted.get("pod")
			var ring: Node3D = pod.get_node_or_null("WeaponRing") if pod != null else null
			var rig: Node3D = hero.sync_weapon_rig(pod, all_bits, all_parts)
			if ring == null or rig == null:
				continue
			var rig_meshes: Array[MeshInstance3D] = []
			for m: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
				rig_meshes.append(m)
			var ring_verts := PackedVector3Array()
			if ring is MeshInstance3D and (ring as MeshInstance3D).mesh != null:
				ring_verts = _frame_verts(ring, ring as MeshInstance3D)
			for mount_name: String in ["PierceCollarClamp", "Clamp", "Louvers"]:
				var mm := rig.find_child(mount_name, true, false) as MeshInstance3D
				if mm != null:
					var mv := _frame_verts(ring, mm)
					var min_r2 := INF
					var dir_sum := Vector2.ZERO
					for q in mv:
						var p2 := Vector2(q.x, q.z)
						min_r2 = minf(min_r2, p2.length())
						dir_sum += p2
					var rim_r: float = rig._ring_outer_radius_at(dir_sum.normalized(), 0.90, 0.26)
					max_mount_gap = maxf(max_mount_gap, min_r2 - rim_r)
			var pilot_parts := []
			for m: MeshInstance3D in pod.find_children("*", "MeshInstance3D", true, false):
				if not m.is_visible_in_tree() or m.mesh == null or m.layers == 0 or rig.is_ancestor_of(m) or m == ring:
					continue
				var rel := String(pod.get_path_to(m))
				if rel.begins_with("AnimatedPilot") or rel == "Cockpit" or rel.begins_with("Gyro") \
						or rel.ends_with("/Pod") or rel.find("/Pod/Carapace") >= 0:
					continue
				pilot_parts.append({"name": rel, "node": m, "aabb": _pts_aabb(_frame_verts(ring, m))})
			for recoil_val: float in [0.0, WeaponRigFx.RECOIL_MAX]:
				rig._recoil = recoil_val
				for spin_step in 6:
					rig._spin_angle = float(spin_step) * TAU / 6.0
					rig._apply_kinematics(1.0)
					var rig_boxes := {}
					for rm in rig_meshes:
						var rv := _frame_verts(ring, rm)
						var ra := _pts_aabb(rv)
						rig_boxes[rm.name] = ra
						if spin_step == 0:
							for v in _frame_verts(ball, rm):
								min_cage_r = minf(min_cage_r, v.length())
							var rm_inv := rm.global_transform.affine_inverse() * ring.global_transform
							var lbox := rm.mesh.get_aabb()
							for pv in ring_verts:
								var lp := rm_inv * pv
								var dx := maxf(0.0, maxf(lbox.position.x - lp.x, lp.x - lbox.end.x))
								var dy := maxf(0.0, maxf(lbox.position.y - lp.y, lp.y - lbox.end.y))
								var dz := maxf(0.0, maxf(lbox.position.z - lp.z, lp.z - lbox.end.z))
								var d_obb := Vector3(dx, dy, dz).length()
								if d_obb == 0.0:
									d_obb = -minf(lp.x - lbox.position.x, minf(lbox.end.x - lp.x, minf(lp.y - lbox.position.y, lbox.end.y - lp.y)))
								if d_obb < worst_ring_gap:
									worst_ring_gap = d_obb
									worst_ring_pair = "%s/%s(rec=%.2f):%s" % [mode_name, cid, recoil_val, rm.name]
							for entry: Dictionary in pilot_parts:
								var pm: MeshInstance3D = entry["node"]
								var pa: AABB = _pts_aabb(_frame_verts(ring, pm)) if String(entry["name"]).begins_with("WeaponRing/Weapon") else entry["aabb"]
								var gap := _aabb_gap(ra, pa)
								if gap < worst_pilot_gap:
									worst_pilot_gap = gap
									worst_pilot_pair = "%s/%s(rec=%.2f):%s vs %s" % [mode_name, cid, recoil_val, rm.name, entry["name"]]
					if rig_boxes.has("GyroOuter"):
						var go_a: AABB = rig_boxes["GyroOuter"]
						for chk_name: String in ["Rail_L", "Rail_R", "Core_L", "Core_R", "Strut_L", "Strut_R", "RotaryDrum", "Yoke"]:
							if rig_boxes.has(chk_name):
								var g := _aabb_gap(go_a, rig_boxes[chk_name])
								if g < worst_internal_gap:
									worst_internal_gap = g
									worst_internal_pair = "GyroOuter vs %s(spin=%d)" % [chk_name, spin_step * 60]
		holder.free()
	_t.check("all 6 pilots seat WeaponRigFx flush-bolted with zero interpenetration and >= 0.03 m GyroOuter lug clearance",
		min_cage_r >= 1.04 and worst_pilot_gap >= 0.005 and worst_ring_gap >= 0.004
		and worst_internal_gap >= 0.03 and max_mount_gap <= 0.065,
		"min_cage=%.4f pilot_gap=%.4f(%s) ring_gap=%.4f(%s) internal_gap=%.4f(%s) max_mount_gap=%.4f" % [
			min_cage_r, worst_pilot_gap, worst_pilot_pair, worst_ring_gap, worst_ring_pair,
			worst_internal_gap, worst_internal_pair, max_mount_gap
		])


func _check_single_source_shot_kick() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var bus := _MockShotBus.new()
	var drv := WeaponDriver.new()
	var pat: Resource = Weapons.base(Weapons.RAPID_LASER)
	drv.reset(pat)
	var build := _MockBuild.new()
	build.mask = ShotBits.bit("pierce") | ShotBits.bit("split") | ShotBits.bit("heat") | ShotBits.bit("bounce")
	var run_stub := {"parts": ["hot_rivets", "cross_split", "spiral_wave", "chain_arc", "rime_rounds"]}
	var hero := HeroAssets.previewing()
	hero.ctx = {"events": bus, "spawner": {"weapon_driver": drv}, "build": build, "run": run_stub}
	holder.add_child(hero)
	hero._connect_shell_events()
	var ball := Node3D.new()
	holder.add_child(ball)
	var fitted: Dictionary = hero.fit_shell_into(ball, "runner_gunner", "", 2, {"class": Palette.COPPER})
	var pod: Node3D = fitted.get("pod")
	var rec := {"player": ball, "pod": pod, "core": fitted.get("core"), "shell": fitted, "class": "runner_gunner"}
	hero._players[ball.get_instance_id()] = rec
	hero._step_weapon_rig(rec, 1.0 / 60.0)
	var ring: Node3D = pod.get_node_or_null("WeaponRing")
	var rig: Node3D = ring.get_node_or_null(WeaponRigFx.NODE_NAME)
	var intent := Intent.new()
	intent.fire_pressed = true
	var shots := drv.step(1.0 / 60.0, intent, Weapons.RAPID_LASER, pat, float(pat.rate))
	bus.shot_fired.emit(Vector3.ZERO, Vector3.FORWARD, Weapons.RAPID_LASER)
	var recoil_right_after_signal: float = rig.recoil_offset()
	hero._step_weapon_rig(rec, 1.0 / 60.0)
	var single_recoil: float = rig.recoil_offset()
	var single_heat: float = rig.heat_level()
	var single_spin: float = rig.spin_rate()
	_t.check("live shot with both shot_fired signal and WeaponDriver.fire_seq kicks WeaponRigFx once (no double-kick)",
		not shots.is_empty() and is_equal_approx(recoil_right_after_signal, 0.0)
		and single_recoil > 0.12 and single_recoil < 0.20
		and single_heat > 0.18 and single_heat < 0.26
		and single_spin > 9.0 and single_spin < 12.0,
		"sig_rec=%.4f rec=%.4f heat=%.4f spin=%.2f" % [recoil_right_after_signal, single_recoil, single_heat, single_spin])

	hero.ctx["spawner"] = {}
	rig.reset_fx()
	bus.shot_fired.emit(Vector3.ZERO, Vector3.FORWARD, Weapons.RAPID_LASER)
	var fallback_recoil: float = rig.recoil_offset()
	_t.check("shot_fired signal fallback kicks WeaponRigFx when WeaponDriver is absent",
		fallback_recoil > 0.16 and fallback_recoil < 0.20,
		"fallback_rec=%.4f" % fallback_recoil)
	holder.free()


func _check_bolts_shader_and_mesh() -> void:
	var bolts := Bolts.new()
	bolts.setup()
	root.add_child(bolts)
	var mm_view := bolts.get_child(0) as MultiMeshInstance3D
	var mm: MultiMesh = mm_view.multimesh
	var mat := mm_view.material_override as ShaderMaterial
	var out_mat := mat.next_pass as ShaderMaterial if mat != null else null
	var shader_path := mat.shader.resource_path if mat != null and mat.shader != null else ""
	var shader_code := mat.shader.code if mat != null and mat.shader != null else ""
	_t.check("Bolts uses sculpted ArrayMesh (no BoxMesh), custom data, and decoupled bolt_projectile.gdshader",
		mm.mesh is ArrayMesh and not (mm.mesh is PrimitiveMesh) and mm.use_custom_data
		and mat != null and shader_path == "res://assets/shaders/bolt_projectile.gdshader"
		and mat.render_priority == Bolts.PRIORITY and shader_code.contains("srgb_to_linear")
		and shader_code.contains("atan(xy.y, xy.x)") and not shader_code.contains("UV.y *")
		and out_mat != null and out_mat.render_priority == Bolts.PRIORITY - 1
		and out_mat.render_priority < mat.render_priority,
		"mesh=%s path=%s prio=%s out_prio=%s" % [
			mm.mesh.get_class(), shader_path,
			mat.render_priority if mat != null else -99,
			out_mat.render_priority if out_mat != null else -99
		])

	var b := {
		"origin": Vector3.ZERO, "dir": Vector3.FORWARD, "speed": 60.0, "max_dist": 30.0,
		"damage": 10.0, "kind": "arc", "weapon_id": "arc_caster", "radius": 0.25,
		"knock": 0.0, "chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 1.0,
		"color": Palette.ARC, "wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0,
		"bits": ShotBits.bit("pierce") | ShotBits.bit("heat"), "source": "weapon",
	}
	bolts.fire(b)
	b["travelled"] = 3.0
	b["age"] = 0.25
	b["shown"] = Vector3.FORWARD * 3.0
	FlashGuard.on = false
	var cd_normal := Bolts.custom_data(b)
	FlashGuard.on = true
	var cd_guard := Bolts.custom_data(b)
	FlashGuard.on = false
	bolts._process(0.016)
	var drawn_inst := Bolts.instance(b, Bolts.crowd_alpha(1))
	_t.check("Bolts populates custom_data with ShotBits boost & FlashGuard damping and preserves crowd_alpha",
		cd_normal.g >= 0.99 and cd_normal.b >= 0.85 and cd_guard.a < cd_normal.a
		and mm.visible_instance_count == 1 and mm.use_colors
		and is_equal_approx((drawn_inst[1] as Color).a, Bolts.crowd_alpha(1)),
		"normal=%s guard=%s vis=%d a=%.2f" % [cd_normal, cd_guard, mm.visible_instance_count, (drawn_inst[1] as Color).a])

	var no_hazard := true
	for name_key in ShotBits.NAMES:
		var c: Color = ShotBits.TABLE[name_key]["color"]
		if c == Palette.HAZARD:
			no_hazard = false
	_t.check("no ShotBits bolt tint uses HAZARD", no_hazard, "")
	bolts.free()
