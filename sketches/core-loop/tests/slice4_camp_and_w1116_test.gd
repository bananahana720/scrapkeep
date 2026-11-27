extends SceneTree

const Game := preload("res://src/game.gd")
const CampCraftMeshes := preload("res://src/presentation/craft/camp_craft_meshes.gd")
const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const T := preload("res://tests/support/t.gd")

const SAMPLES := 1440

var _t := T.new("slice4_camp_and_w1116_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	CampCraftMeshes.reset_for_tests()
	_verify_craft_topology()
	await _verify_camp_scene_graph()
	_verify_w1116_threat_grammar()
	CampCraftMeshes.reset_for_tests()
	quit(_t.verdict())


func _quant_key(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))


func _edge_key(a: Vector3i, b: Vector3i) -> Array:
	if a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z))):
		return [a, b]
	return [b, a]


func _audit_mesh(mesh: ArrayMesh) -> Dictionary:
	var open_edges := 0
	var non_manifold := 0
	var degenerate := 0
	var total_tris := 0
	var signed_vol := 0.0
	var has_uv := true
	var has_tan := true
	var has_col := true
	for s in mesh.get_surface_count():
		var fmt := mesh.surface_get_format(s)
		has_uv = has_uv and ((fmt & Mesh.ARRAY_FORMAT_TEX_UV) != 0)
		has_tan = has_tan and ((fmt & Mesh.ARRAY_FORMAT_TANGENT) != 0)
		has_col = has_col and ((fmt & Mesh.ARRAY_FORMAT_COLOR) != 0)
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var edges := {}
		for i in range(0, verts.size() - 2, 3):
			var a := verts[i]
			var b := verts[i + 1]
			var c := verts[i + 2]
			total_tris += 1
			var cross_v := (b - a).cross(c - a)
			if cross_v.length_squared() < 1e-12:
				degenerate += 1
				continue
			signed_vol += a.dot(c.cross(b)) / 6.0
			var ka := _quant_key(a)
			var kb := _quant_key(b)
			var kc := _quant_key(c)
			for pair in [_edge_key(ka, kb), _edge_key(kb, kc), _edge_key(kc, ka)]:
				var ek := "%d,%d,%d|%d,%d,%d" % [pair[0].x, pair[0].y, pair[0].z, pair[1].x, pair[1].y, pair[1].z]
				edges[ek] = int(edges.get(ek, 0)) + 1
		for raw_count in edges.values():
			var count: int = int(raw_count)
			if count == 1:
				open_edges += 1
			elif count > 2:
				non_manifold += 1
	return {
		"open": open_edges,
		"non_manifold": non_manifold,
		"degenerate": degenerate,
		"tris": total_tris,
		"volume": signed_vol,
		"uv": has_uv,
		"tan": has_tan,
		"col": has_col,
	}


func _verify_craft_topology() -> void:
	var catalog := {
		"sandstone_plaza": CampCraftMeshes.sandstone_plaza_mesh(270.0, 4.0, 96),
		"perimeter_berm": CampCraftMeshes.perimeter_berm_mesh(270.0, 72, 6.0, 10.0, 0.06),
		"ring_post": CampCraftMeshes.ring_post_mesh(2.2),
		"signal_lantern": CampCraftMeshes.signal_lantern_mesh(0.34),
		"trial_lantern": CampCraftMeshes.signal_lantern_mesh(0.4),
		"ghost_sphere": CampCraftMeshes.ghost_sphere_mesh(1.0),
		"guide_pip": CampCraftMeshes.guide_pip_mesh(0.16),
	}
	for name in catalog:
		var mesh: ArrayMesh = catalog[name]
		var stats := _audit_mesh(mesh)
		var ok: bool = stats["open"] == 0 and stats["non_manifold"] == 0 and stats["degenerate"] == 0 and stats["volume"] > 0.0 and stats["uv"] and stats["tan"] and stats["col"]
		_t.check(
			"%s watertight outward 2-manifold" % name,
			ok,
			"open=%d nm=%d deg=%d vol=%.2f tris=%d uv=%s tan=%s col=%s" % [
				stats["open"], stats["non_manifold"], stats["degenerate"], stats["volume"], stats["tris"], stats["uv"], stats["tan"], stats["col"]
			],
		)
	var lantern_stats := _audit_mesh(catalog["trial_lantern"])
	_t.check("trial lantern tris << 4224 default sphere", lantern_stats["tris"] < 600, "%d tris" % lantern_stats["tris"])
	var ghost_stats := _audit_mesh(catalog["ghost_sphere"])
	_t.check("ghost sphere tris << 4224 default sphere", ghost_stats["tris"] < 600, "%d tris" % ghost_stats["tris"])


func _verify_camp_scene_graph() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	await process_frame
	await physics_frame
	var hub = game.camp_hub
	hub.ensure_built()
	await process_frame
	var ground: StaticBody3D = hub.root.get_node_or_null("CampGround") as StaticBody3D
	_t.check("CampGround exists", ground != null, str(ground))
	if ground != null:
		var ground_meshes := ground.find_children("*", "MeshInstance3D", true, false)
		var ground_cols := ground.find_children("*", "CollisionShape3D", true, false)
		_t.eq("CampGround draw-call consolidation (2 meshes, not 73)", ground_meshes.size(), 2)
		_t.eq("CampGround preserves all 73 colliders (1 floor + 72 berms)", ground_cols.size(), 73)
		var disc := ground.get_node_or_null("SandstoneDisc") as MeshInstance3D
		var berm := ground.get_node_or_null("CampBermRing") as MeshInstance3D
		_t.check("SandstoneDisc uses sculpted ArrayMesh + ShaderMaterial", disc != null and disc.mesh is ArrayMesh and disc.material_override is ShaderMaterial, str(disc))
		_t.check("CampBermRing uses sculpted ArrayMesh + ShaderMaterial", berm != null and berm.mesh is ArrayMesh and berm.material_override is ShaderMaterial, str(berm))
	var prim_nodes: Array[String] = []
	for node in hub.root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh is PrimitiveMesh:
			prim_nodes.append(str(hub.root.get_path_to(mi)))
	for node in hub.root.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		if mmi.multimesh != null and mmi.multimesh.mesh is PrimitiveMesh:
			prim_nodes.append(str(hub.root.get_path_to(mmi)))
	_t.check("Camp Hub has zero PrimitiveMesh greyboxes", prim_nodes.is_empty(), str(prim_nodes))
	for medal in ["bronze", "silver", "gold"]:
		var bulb := hub.root.get_node_or_null("Bulb_" + medal) as MeshInstance3D
		_t.check(
			"Bulb_%s uses sculpted 2-surface lantern with iron cage" % medal,
			bulb != null and bulb.mesh is ArrayMesh and bulb.mesh.get_surface_count() == 2 and bulb.get_surface_override_material(0) is ShaderMaterial,
			str(bulb),
		)
	var ring_post := hub.root.get_node_or_null("RingPost") as Node3D
	var ring_lantern := ring_post.get_node_or_null("RingLantern") as MeshInstance3D if ring_post != null else null
	_t.check(
		"RingLantern uses sculpted 2-surface lantern with iron cage",
		ring_lantern != null and ring_lantern.mesh is ArrayMesh and ring_lantern.mesh.get_surface_count() == 2 and ring_lantern.get_surface_override_material(0) is ShaderMaterial,
		str(ring_lantern),
	)
	game.queue_free()
	await process_frame


static func _inside(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var d1 := (p.x - b.x) * (a.z - b.z) - (a.x - b.x) * (p.z - b.z)
	var d2 := (p.x - c.x) * (b.z - c.z) - (b.x - c.x) * (p.z - c.z)
	var d3 := (p.x - a.x) * (c.z - a.z) - (c.x - a.x) * (p.z - a.z)
	return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))


static func _measure_ring_period(d: Dictionary, role: String) -> float:
	var tris := PackedVector3Array()
	for m in Threat.marks(d, false):
		if m["role"] == role:
			tris = m["tris"]
			break
	if tris.is_empty():
		return INF
	var r: float = float(d["r_out"]) - Threat.edge_width(d) * 0.5
	var covered: Array[bool] = []
	for i in SAMPLES:
		var a := TAU * (float(i) + 0.5) / float(SAMPLES)
		var p := Vector3(cos(a), 0.0, sin(a)) * r
		var hit := false
		for j in range(0, tris.size() - 2, 3):
			if _inside(p, tris[j], tris[j + 1], tris[j + 2]):
				hit = true
				break
		covered.append(hit)
	var runs := 0
	for i in covered.size():
		if covered[i] and not covered[(i + covered.size() - 1) % covered.size()]:
			runs += 1
	if runs == 0:
		return INF
	return TAU * r / float(runs)


func _verify_w1116_threat_grammar() -> void:
	var neutral_ring := {
		"type": Threat.Type.INSTANT,
		"tone": Palette.SAND,
		"centre": Vector3.ZERO,
		"reach": 3.5,
		"progress": 0.0,
		"live": false,
		"form": "radial",
		"r_in": 0.0,
		"r_out": 12.0,
		"a0": 0.0,
		"a1": TAU,
	}
	var hostile_wave := {
		"type": Threat.Type.WAVE,
		"tone": Palette.HAZARD,
		"centre": Vector3.ZERO,
		"reach": 3.5,
		"progress": 0.0,
		"live": false,
		"front": -1.0,
		"form": "radial",
		"r_in": 0.0,
		"r_out": 12.0,
		"a0": 0.0,
		"a1": TAU,
	}
	var owned_wave := hostile_wave.duplicate(true)
	owned_wave["tone"] = Palette.AMBER
	var neutral_period := _measure_ring_period(neutral_ring, "outline")
	var hostile_wave_period := _measure_ring_period(hostile_wave, "outline")
	var owned_wave_period := _measure_ring_period(owned_wave, "outline")
	_t.check("neutral bone ring dashes at DASH", absf(neutral_period - Threat.DASH) < 0.35, "%.2f m" % neutral_period)
	_t.check("hostile wave outline dashes at HOSTILE_WAVE_DASH", absf(hostile_wave_period - Threat.HOSTILE_WAVE_DASH) < 0.45, "%.2f m" % hostile_wave_period)
	_t.check("hostile wave outline differs clearly from neutral bone ring", absf(hostile_wave_period - neutral_period) > 1.0, "hostile=%.2f neutral=%.2f" % [hostile_wave_period, neutral_period])
	_t.check("owned wave outline stays tighter than neutral", owned_wave_period < neutral_period * 0.6, "owned=%.2f neutral=%.2f" % [owned_wave_period, neutral_period])
	_t.eq("stance(HAZARD)", Threat.stance(Palette.HAZARD), Threat.STANCE_HOSTILE)
	_t.eq("stance(SAND)", Threat.stance(Palette.SAND), Threat.STANCE_NEUTRAL)
	for owned_col in [Palette.AMBER, Palette.ARC, Palette.COPPER, Palette.RUST, Palette.LEDGER, Palette.ANCIENT, Color("ff7a29"), Color(0.78, 1.0, 0.62)]:
		_t.eq("stance known owned %s" % owned_col.to_html(false), Threat.stance(owned_col), Threat.STANCE_OWNED)
		_t.check("known_tone true for %s" % owned_col.to_html(false), Threat.known_tone(owned_col), owned_col.to_html(false))
	for unknown_col in [Color(0.18, 0.72, 0.88), Palette.KINDNESS, Color.MAGENTA, Color(0.42, 0.42, 0.42)]:
		_t.eq("stance refuses unknown color %s" % unknown_col.to_html(false), Threat.stance(unknown_col), Threat.STANCE_UNKNOWN)
		_t.check("known_tone false for %s" % unknown_col.to_html(false), not Threat.known_tone(unknown_col), unknown_col.to_html(false))
	var unknown_ring := neutral_ring.duplicate(true)
	unknown_ring["tone"] = Color(0.18, 0.72, 0.88)
	var unknown_edge_period := _measure_ring_period(unknown_ring, "edge")
	_t.check("unknown color does not silently get owned dashed edge", unknown_edge_period == INF, str(unknown_edge_period))
