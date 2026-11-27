extends SceneTree

const HeroKitbashSculptor := preload("res://src/presentation/craft/hero_kitbash_sculptor.gd")

var failed := false
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	failed = failed or not ok
	print(what, " -> ", "PASS" if ok else "FAIL")


func _initialize() -> void:
	_check_no_primitive_mesh_fallbacks()
	_check_reusable_kitbash_builders()
	_check_hero_assemblies()
	_check_determinism()
	print("hero_asset_sculptor_test: ", "FAIL" if failed else "PASS", " (%d checks)" % checks)
	quit(1 if failed else 0)


func _check_no_primitive_mesh_fallbacks() -> void:
	var src := FileAccess.get_file_as_string("res://src/presentation/craft/hero_kitbash_sculptor.gd")
	check(src.length() > 1000, "hero_kitbash_sculptor.gd source readable")
	var forbidden := ["BoxMesh", "CylinderMesh", "SphereMesh", "CapsuleMesh", "TorusMesh", "PrismMesh", "PlaneMesh"]
	var clean := true
	for prim in forbidden:
		if src.contains(prim):
			clean = false
	check(clean, "zero primitive Mesh fallbacks in hero_kitbash_sculptor.gd")
	check(HeroKitbashSculptor.HERO_IDS.size() == 3, "exposes 3 hero assembly ids")


func _check_reusable_kitbash_builders() -> void:
	var c1 := HeroKitbashSculptor.create_canvas()
	HeroKitbashSculptor.add_chamfered_plate(c1, "hull_plating", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0)), Vector3(1.2, 0.6, 0.8), 0.08)
	var m1 := c1.commit()
	var s1 := HeroKitbashSculptor.inspect_mesh_stats(m1)
	check(s1.triangle_count >= 40 and s1.finite_unit_normals and s1.valid_uvs and s1.valid_tangents, "chamfered plate builds manifold beveled geometry (%d tris)" % s1.triangle_count)
	check(s1.r_low_ratio > 0.10 and s1.r_high_ratio > 0.30 and s1.outward_ratio > 0.99, "chamfered plate carries flat-vs-bevel edge wear and outward winding")

	var c2 := HeroKitbashSculptor.create_canvas()
	HeroKitbashSculptor.add_chamfered_prism(c2, "hull_plating", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.2, 0.0)), 8, 1.0, 0.8, 1.0, 0.08, 0.08)
	var s2 := HeroKitbashSculptor.inspect_mesh_stats(c2.commit())
	check(s2.triangle_count >= 64 and s2.finite_unit_normals and s2.outward_ratio > 0.99, "chamfered prism builds watertight beveled octagon (%d tris)" % s2.triangle_count)

	var c3 := HeroKitbashSculptor.create_canvas()
	HeroKitbashSculptor.add_recessed_seam(c3, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0)), 1.0, 1.2, 0.16, 0.10, 0.90)
	var s3 := HeroKitbashSculptor.inspect_mesh_stats(c3.commit())
	check(s3.triangle_count >= 200 and s3.g_high_ratio > 0.08 and s3.outward_ratio > 0.99, "recessed seam produces grimy cavity pocket and beveled frame")

	var c4 := HeroKitbashSculptor.create_canvas()
	HeroKitbashSculptor.add_truss_rib(c4, "iron_frame", Vector3(0.0, 1.0, 0.0), Vector3(1.5, 2.2, 0.4), 0.10, 0.025)
	var s4 := HeroKitbashSculptor.inspect_mesh_stats(c4.commit())
	check(s4.triangle_count >= 120 and s4.finite_unit_normals and s4.outward_ratio > 0.99, "truss rib builds beveled beam with end gussets")

	var c5 := HeroKitbashSculptor.create_canvas()
	HeroKitbashSculptor.add_louver_vent(c5, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0)), 0.9, 0.7, 0.14, 5, true)
	var s5 := HeroKitbashSculptor.inspect_mesh_stats(c5.commit())
	check(s5.triangle_count >= 300 and s5.b_high_ratio > 0.01 and s5.g_high_ratio > 0.10, "louver vent builds angled slats, cavity grime, and optional hot core")

	var c6 := HeroKitbashSculptor.create_canvas()
	HeroKitbashSculptor.add_rivet_strip(c6, "iron_frame", Vector3(-0.5, 1.5, 0.0), Vector3(0.5, 1.5, 0.0), Vector3.BACK, 5, 0.04, 0.03)
	var s6 := HeroKitbashSculptor.inspect_mesh_stats(c6.commit())
	check(s6.triangle_count >= 200 and s6.g_high_ratio > 0.15 and s6.r_high_ratio > 0.15, "rivet strip builds hex bolt heads with grimy washer collars")

	var c7 := HeroKitbashSculptor.create_canvas()
	HeroKitbashSculptor.add_hydraulic_pipe(c7, "iron_frame", Vector3(0.0, 1.0, 0.0), Vector3(0.0, 3.2, 0.0), 0.16, 5, 0.28)
	var s7 := HeroKitbashSculptor.inspect_mesh_stats(c7.commit())
	check(s7.triangle_count >= 300 and s7.finite_unit_normals and s7.outward_ratio > 0.99, "hydraulic pipe builds shaft and bellows collars")

	var c8 := HeroKitbashSculptor.create_canvas()
	HeroKitbashSculptor.add_cable_catenary(c8, "cable_rubber", Vector3(-1.0, 2.0, 0.0), Vector3(1.0, 2.0, 0.0), 0.7, 0.05, 14, 8)
	var s8 := HeroKitbashSculptor.inspect_mesh_stats(c8.commit())
	check(s8.triangle_count >= 220 and s8.finite_unit_normals and s8.outward_ratio > 0.99, "cable catenary builds smooth twist-free tube with end grommets")

	var c9 := HeroKitbashSculptor.create_canvas()
	HeroKitbashSculptor.add_asymmetric_patch(c9, "patch_oxide", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0)), Vector3(1.1, 0.8, 0.09), 4.0, 6)
	var s9 := HeroKitbashSculptor.inspect_mesh_stats(c9.commit())
	check(s9.triangle_count >= 300 and s9.surface_count == 2 and s9.outward_ratio > 0.99, "asymmetric patch builds layered oxide plate and perimeter bolts")

	var c10 := HeroKitbashSculptor.create_canvas()
	HeroKitbashSculptor.add_valve_wheel(c10, "patch_oxide", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0)), 0.36, 0.04, 4)
	HeroKitbashSculptor.add_coil_winding(c10, "copper_coil", Transform3D(Basis.IDENTITY, Vector3(1.5, 1.5, 0.0)), 0.24, 0.9, 6, 0.04)
	HeroKitbashSculptor.add_service_ladder(c10, "iron_frame", Vector3(-1.5, 0.5, 0.0), Vector3(-1.5, 2.1, 0.0), Vector3.BACK, 0.36, 4)
	var s10 := HeroKitbashSculptor.inspect_mesh_stats(c10.commit())
	check(s10.triangle_count >= 800 and s10.finite_unit_normals and s10.valid_uvs and s10.valid_tangents and s10.outward_ratio > 0.99, "valve wheel, copper coil, and service ladder build clean manifold geometry")


func _check_hero_assemblies() -> void:
	for hero_id in HeroKitbashSculptor.HERO_IDS:
		var mesh := HeroKitbashSculptor.build_hero(hero_id)
		var stats := HeroKitbashSculptor.inspect_mesh_stats(mesh)
		var label := String(hero_id)
		var aabb: AABB = stats.aabb

		check(mesh != null and stats.surface_count >= 4, "%s builds multi-surface ArrayMesh (%d surfaces)" % [label, stats.surface_count])
		check(stats.vertex_count >= 3000 and stats.triangle_count >= 3000, "%s has rich sculpted silhouette detail (%d verts, %d tris)" % [label, stats.vertex_count, stats.triangle_count])
		check(stats.finite_verts and stats.finite_unit_normals, "%s has finite positions and unit outward normals" % label)
		check(stats.valid_uvs and stats.valid_tangents, "%s has valid finite UVs and tangents" % label)
		check(stats.outward_ratio > 0.99, "%s triangle winding matches outward normals (%.4f)" % [label, stats.outward_ratio])
		check(absf(aabb.position.y) < 0.05 and aabb.size.y >= 4.8, "%s grounded at y=0 with monumental scale (y0=%.3f, h=%.2fm)" % [label, aabb.position.y, aabb.size.y])

		check(stats.r_low_ratio >= 0.12 and stats.r_high_ratio >= 0.15, "%s COLOR.r edge wear spans flat interiors (%.2f) and bright bevels (%.2f)" % [label, stats.r_low_ratio, stats.r_high_ratio])
		check(stats.g_low_ratio >= 0.12 and stats.g_high_ratio >= 0.10, "%s COLOR.g cavity grime spans exposed faces (%.2f) and recessed crevices (%.2f)" % [label, stats.g_low_ratio, stats.g_high_ratio])
		check(stats.b_high_ratio >= 0.002 and stats.b_high_ratio <= 0.25 and stats.b_zero_ratio >= 0.72, "%s COLOR.b emissive strictly localized to working core/vents (lit=%.3f, dark=%.3f)" % [label, stats.b_high_ratio, stats.b_zero_ratio])
		check(stats.a_min >= 0.99, "%s COLOR.a blend weight stays 1.0 (min=%.3f)" % [label, stats.a_min])
		check(stats.surfaces.has("emissive_core"), "%s includes dedicated emissive_core surface slot" % label)
		check(String(mesh.get_meta("scale_cue", "")) != "", "%s declares hand-sized scale cue meta" % label)


func _check_determinism() -> void:
	for hero_id in HeroKitbashSculptor.HERO_IDS:
		var a := HeroKitbashSculptor.inspect_mesh_stats(HeroKitbashSculptor.build_hero(hero_id))
		var b := HeroKitbashSculptor.inspect_mesh_stats(HeroKitbashSculptor.build_hero(hero_id))
		check(
			a.vertex_count == b.vertex_count and a.triangle_count == b.triangle_count and a.aabb.is_equal_approx(b.aabb),
			"%s build is deterministic across repeat invocations" % String(hero_id)
		)
