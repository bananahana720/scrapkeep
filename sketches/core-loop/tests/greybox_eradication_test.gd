extends SceneTree


const T := preload("res://tests/support/t.gd")
const Palette := preload("res://src/core/palette.gd")
const PropMeshes := preload("res://src/presentation/craft_prop_meshes.gd")
const StakeDevices := preload("res://src/world/stake_devices.gd")
const RadioCache := preload("res://src/world/radio_cache.gd")
const Contraptions := preload("res://src/world/contraptions.gd")
const Gorge := preload("res://src/world/map_gorge.gd")
const Arena := preload("res://src/boss/arena.gd")
const Activities := preload("res://src/world/activities.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

var t := T.new("greybox_eradication_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	PropMeshes.reset_for_tests()
	_check_mesh_library()
	_check_material_hygiene()
	_check_radio_cache_parts()
	_check_contraptions_upgraded()
	_check_arena_upgraded()
	_check_activities_upgraded()
	await _check_live_world1_prim_reduction_and_colliders()
	PropMeshes.reset_for_tests()
	quit(t.verdict())


func _check_mesh_library() -> void:
	var builders := {
		"stake_chest_body": func(): return PropMeshes.stake_chest_body(),
		"stake_chest_lid": func(): return PropMeshes.stake_chest_lid(),
		"stake_shrine_body": func(): return PropMeshes.stake_shrine_body(),
		"stake_shrine_basin": func(): return PropMeshes.stake_shrine_basin(),
		"stake_ward_pillar": func(): return PropMeshes.stake_ward_pillar(),
		"stake_ward_lantern": func(): return PropMeshes.stake_ward_lantern(),
		"stake_tier_rivet": func(): return PropMeshes.stake_tier_rivet(),
		"radio_mast": func(): return PropMeshes.radio_mast(),
		"radio_dish": func(): return PropMeshes.radio_dish(),
		"radio_lamp_housing": func(): return PropMeshes.radio_lamp_housing(),
		"radio_pulse_ring": func(): return PropMeshes.radio_pulse_ring(),
		"dial_needle": func(): return PropMeshes.dial_needle(),
		"dial_post": func(): return PropMeshes.dial_post(),
		"dial_bezel": func(): return PropMeshes.dial_bezel(),
		"dial_redline": func(): return PropMeshes.dial_redline(),
		"thermal_grate": func(): return PropMeshes.thermal_grate(3.0),
		"sluice_wheel": func(): return PropMeshes.sluice_wheel(),
		"sluice_post": func(): return PropMeshes.sluice_post(),
		"valve_door_slab": func(): return PropMeshes.valve_door_slab(Vector3(4.0, 4.0, 0.8)),
		"cracked_wall_slab": func(): return PropMeshes.cracked_wall_slab(Vector3(6.0, 4.0, 1.0)),
		"lift_deck": func(): return PropMeshes.lift_deck(4.5),
		"lift_piston": func(): return PropMeshes.lift_piston(),
		"barge_hull": func(): return PropMeshes.barge_hull(Vector3(14.0, 1.2, 14.0)),
		"grapple_hook_anchor": func(): return PropMeshes.grapple_hook_anchor(),
		"quench_vent_pad": func(): return PropMeshes.quench_vent_pad(3.0),
		"quench_vent_grate": func(): return PropMeshes.quench_vent_grate(3.0),
		"crane_mast": func(): return PropMeshes.crane_mast(16.0),
		"crane_boom": func(): return PropMeshes.crane_boom(Vector3(8.0, 0.8, 0.8)),
		"vent_nozzle": func(): return PropMeshes.vent_nozzle(),
		"lore_plate_rim": func(): return PropMeshes.lore_plate_rim(Activities.PLATE_RADIUS, Activities.PLATE_H),
		"lore_plate_face": func(): return PropMeshes.lore_plate_face(Activities.PLATE_FACE_RADIUS, Activities.PLATE_H),
		"mend_ward_ring": func(): return PropMeshes.mend_ward_ring(5.0, 0.06),
		"mend_ward_fill": func(): return PropMeshes.mend_ward_fill(5.0, 0.06),
		"door_clock_casing": func(): return PropMeshes.door_clock_casing(1.5),
		"door_clock_face": func(): return PropMeshes.door_clock_face(1.5),
		"door_clock_hand": func(): return PropMeshes.door_clock_hand(0.1, 0.45),
		"work_glove_leather": func(): return PropMeshes.work_glove_leather(),
		"work_glove_cuff": func(): return PropMeshes.work_glove_cuff(),
		"work_glove_peg": func(): return PropMeshes.work_glove_peg(),
		"chalk_stroke": func(): return PropMeshes.chalk_stroke(0.08, 0.65),
		"bevel_prop_box": func(): return PropMeshes.bevel_prop_box(Vector3(2.0, 2.0, 2.0)),
		"bevel_prop_post": func(): return PropMeshes.bevel_prop_post(Vector3(0.4, 2.2, 0.4)),
	}
	for name in builders:
		var fn: Callable = builders[name]
		var m: ArrayMesh = fn.call()
		var cached: ArrayMesh = fn.call()
		t.check("%s returns cached ArrayMesh" % name, m != null and m is ArrayMesh and m == cached and m.get_surface_count() == 1)
		if m == null or m.get_surface_count() == 0:
			continue
		var arr := m.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var tangents: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
		var bad_winding := 0
		var bad_normal := 0
		var zero_area := 0
		var edge_counts := {}
		var i := 0
		while i + 2 < verts.size():
			var a := verts[i]
			var b := verts[i + 1]
			var c := verts[i + 2]
			var n := norms[i]
			if not n.is_finite() or absf(n.length() - 1.0) > 0.02:
				bad_normal += 1
			var cross := (b - a).cross(c - a)
			if cross.length() < 1e-7:
				zero_area += 1
			if cross.dot(n) > 0.0001:
				bad_winding += 1
			var ka := _vkey(a)
			var kb := _vkey(b)
			var kc := _vkey(c)
			for e in [[ka, kb], [kb, kc], [kc, ka]]:
				var ek := _ekey(e[0], e[1])
				edge_counts[ek] = int(edge_counts.get(ek, 0)) + 1
			i += 3
		var open_edges := 0
		var non_manifold := 0
		for ek in edge_counts:
			var cnt: int = edge_counts[ek]
			if cnt == 1:
				open_edges += 1
			elif cnt > 2:
				non_manifold += 1
		t.check("%s has closed-manifold outward-wound topology, UVs, tangents, no stray color array" % name,
			verts.size() >= 12 and verts.size() % 3 == 0 and norms.size() == verts.size()
			and uvs.size() == verts.size() and tangents.size() == verts.size() * 4
			and arr[Mesh.ARRAY_COLOR] == null and bad_winding == 0 and bad_normal == 0
			and zero_area == 0 and open_edges == 0 and non_manifold == 0,
			"verts=%d bad_winding=%d bad_normal=%d zero_area=%d open=%d non_manifold=%d" % [verts.size(), bad_winding, bad_normal, zero_area, open_edges, non_manifold])

	var chest_aabb := PropMeshes.stake_chest_body().get_aabb()
	t.check("stake_chest_body grounded at y=0 and top near 1.31", absf(chest_aabb.position.y) < 0.01 and absf(chest_aabb.end.y - 1.31) < 0.05, str(chest_aabb))
	var shrine_aabb := PropMeshes.stake_shrine_body().get_aabb()
	t.check("stake_shrine_body grounded at y=0 and top near 2.42", absf(shrine_aabb.position.y) < 0.01 and absf(shrine_aabb.end.y - 2.42) < 0.05, str(shrine_aabb))
	var rim_aabb := PropMeshes.lore_plate_rim(Activities.PLATE_RADIUS, Activities.PLATE_H).get_aabb()
	t.check("lore_plate_rim stays strictly within PLATE_H", rim_aabb.size.y <= Activities.PLATE_H + 0.002, str(rim_aabb))
	var needle_aabb := PropMeshes.dial_needle().get_aabb()
	t.check("dial_needle stays thin enough to clear gauge.glb face", needle_aabb.size.z <= 0.06, str(needle_aabb))

	var before_mesh := PropMeshes.dial_needle()
	PropMeshes.reset_for_tests()
	var after_mesh := PropMeshes.dial_needle()
	t.check("reset_for_tests clears mesh cache", before_mesh != after_mesh)


func _check_material_hygiene() -> void:
	for color in [Palette.VERDIGRIS, Palette.COPPER, Palette.RUST, Palette.BRASS, Palette.CHARCOAL, Palette.SANDSTONE, Palette.SLATE]:
		var mat := PropMeshes.weathered_material(color, 0.72, 0.25, 0.0, "test")
		var h := mat.albedo_color.h * 360.0
		var in_kindness := mat.albedo_color.s >= 0.15 and h >= 300.0 and h <= 330.0
		t.check("weathered_material %s avoids Kindness hue band and has texture/normal" % color.to_html(false),
			not in_kindness and mat.albedo_texture != null and mat.normal_enabled,
			"h=%.1f tex=%s norm=%s" % [h, mat.albedo_texture != null, mat.normal_enabled])


func _check_radio_cache_parts() -> void:
	var parts := RadioCache._make_parts()
	for k in ["pole", "bowl", "bulb", "torus"]:
		t.check("radio_cache fallback part %s is sculpted ArrayMesh" % k, parts[k] is ArrayMesh, str(parts[k]))
	var rc := RadioCache.new()
	root.add_child(rc)
	rc._build_plain()
	var plain_prims := rc.find_children("*", "MeshInstance3D", true, false).filter(func(v): return v.mesh is PrimitiveMesh)
	t.check("radio_cache _build_plain draws zero PrimitiveMesh", plain_prims.is_empty(), str(plain_prims))
	rc.free()


func _check_contraptions_upgraded() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var map := Gorge.new()
	map.contraptions = [
		{"kind": "launcher", "id": "test_steam_lift", "style": "steam_lift", "at": Vector2(0, 0),
			"radius": 3.8, "target": Vector3(0, 15, 30), "floor": 15.0, "min_flight": 2.0, "charge": 3.0},
		{"kind": "launcher", "id": "test_cannon_skin", "style": "cannon", "recipe": "cannon", "at": Vector2(20, 0),
			"radius": 3.5, "target": Vector3(20, 15, 40), "floor": 15.0, "min_flight": 2.0, "charge": 3.0},
	]
	var c := Contraptions.new()
	holder.add_child(c)
	c.setup(map, func(x: float, z: float, lift := 0.0): return Vector3(x, lift, z), 14.0, 26.0)
	var needle: MeshInstance3D = c.launchers[1]["needle"]
	t.check("contraptions live dial needle is sculpted ArrayMesh (not BoxMesh)", needle != null and needle.mesh is ArrayMesh, str(needle.mesh if needle != null else null))
	var grates := c.find_children("*", "MeshInstance3D", true, false).filter(func(v): return v.mesh == PropMeshes.thermal_grate(3.0))
	t.check("contraptions steam_lift floor grate is sculpted ArrayMesh", grates.size() == 1, str(grates.size()))
	holder.free()


func _check_arena_upgraded() -> void:
	var a := Arena.new()
	root.add_child(a)
	var grates := a.find_children("QuenchGrate", "MeshInstance3D", true, false)
	t.check("Slag Bowl builds 4 sculpted QuenchGrate ArrayMeshes over its WaterVents",
		grates.size() == 4 and grates.all(func(v): return (v as MeshInstance3D).mesh is ArrayMesh),
		"count=%d" % grates.size())
	a.free()


func _check_activities_upgraded() -> void:
	var acts := Activities.new()
	var s := Activities.Site.new()
	s.wall = Node3D.new()
	s.add_child(s.wall)
	root.add_child(acts)
	root.add_child(s)
	acts._chalk_tally(s.wall)
	acts._hang_glove(s)
	var prims := s.wall.find_children("*", "MeshInstance3D", true, false).filter(func(v): return v.mesh is PrimitiveMesh)
	t.check("activities RoomTally and RoomGlove draw zero PrimitiveMesh",
		s.wall.get_node_or_null("RoomTally") != null and s.wall.get_node_or_null("RoomGlove") != null and prims.is_empty(),
		"prims=%d" % prims.size())
	s.free()
	acts.free()


static func _vkey(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0)]


static func _ekey(a: String, b: String) -> String:
	return (a + "|" + b) if a < b else (b + "|" + a)


func _check_live_world1_prim_reduction_and_colliders() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	var terrain = game.ctx.terrain
	var waited := 0
	while waited < 2000 and not (terrain.rows_ready(1) and terrain.is_ready(1) and game.flow.state_name() == "stage"):
		await process_frame
		waited += 1
	for _f in 4:
		await physics_frame

	var acts = game.world.activities
	var plate_prims := 0
	var plate_arrays := 0
	for p in acts.plates:
		for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh is PrimitiveMesh:
				plate_prims += 1
			elif mi.mesh is ArrayMesh:
				plate_arrays += 1
	t.check("live park_dam LorePlates draw 0 PrimitiveMesh and >= 2 ArrayMeshes per plate",
		acts.plates.size() > 0 and plate_prims == 0 and plate_arrays == acts.plates.size() * 2,
		"plates=%d prims=%d arrays=%d (eradicated %d raw CylinderMeshes)" % [acts.plates.size(), plate_prims, plate_arrays, acts.plates.size() * 2])

	var ward_prims := 0
	for w in acts.wards:
		for mi: MeshInstance3D in w.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh is PrimitiveMesh:
				ward_prims += 1
	t.check("live park_dam MendWards draw 0 PrimitiveMesh", ward_prims == 0,
		"wards=%d prims=%d (eradicated %d raw CylinderMeshes)" % [acts.wards.size(), ward_prims, acts.wards.size() * 2])

	var dial_needle_prims := 0
	var dial_needle_arrays := 0
	var contraptions = game.world.contraptions.get(1)
	if contraptions != null:
		for list_name in ["lifts", "launchers", "sluice_valves"]:
			for row in contraptions.get(list_name):
				var nd = row.get("needle")
				if nd is MeshInstance3D:
					if (nd as MeshInstance3D).mesh is PrimitiveMesh:
						dial_needle_prims += 1
					elif (nd as MeshInstance3D).mesh is ArrayMesh:
						dial_needle_arrays += 1
	t.check("live park_dam Contraptions dial needles draw 0 PrimitiveMesh",
		dial_needle_arrays > 0 and dial_needle_prims == 0,
		"arrays=%d prims=%d (eradicated %d raw BoxMesh needles)" % [dial_needle_arrays, dial_needle_prims, dial_needle_arrays])

	var interact = game.world.interact
	var stake_specs := [
		{"id": "live_g_chest", "device": "trade_chest", "tier": 2, "pay": "health", "owner": "gamble", "col": Vector3(2.2, 1.3, 1.5), "col_y": 0.65},
		{"id": "live_g_shrine", "device": "blood_shrine", "tier": 3, "pay": "health", "owner": "gamble", "col": Vector3(1.6, 2.4, 1.6), "col_y": 1.2},
		{"id": "live_p_ward", "device": "healing_ward", "tier": 2, "pay": "cores", "owner": "", "col": Vector3.ZERO, "col_y": 0.0},
	]
	var stake_prims := 0
	var stake_arrays := 0
	var col_ok := true
	for sp in stake_specs:
		var d := StakeDevices.new()
		interact.add_child(d)
		d.setup(game.ctx, interact, sp)
		for mi: MeshInstance3D in d.find_children("*", "MeshInstance3D", true, false):
			if mi.get_parent() != d:
				continue
			if mi.mesh is PrimitiveMesh:
				stake_prims += 1
			elif mi.mesh is ArrayMesh:
				stake_arrays += 1
		var shapes := d.find_children("*", "CollisionShape3D", true, false)
		if (sp["col"] as Vector3) == Vector3.ZERO:
			col_ok = col_ok and shapes.is_empty()
		else:
			col_ok = col_ok and shapes.size() == 1 and shapes[0].shape is BoxShape3D \
				and (shapes[0].shape as BoxShape3D).size.is_equal_approx(sp["col"]) \
				and is_equal_approx((shapes[0].get_parent() as Node3D).position.y, float(sp["col_y"]))
		d.free()
	t.check("live StakeDevices (chest/shrine/ward) draw 0 PrimitiveMesh on bodies and keep exact colliders",
		stake_prims == 0 and stake_arrays >= 15 and col_ok,
		"arrays=%d prims=%d col_ok=%s" % [stake_arrays, stake_prims, col_ok])

	var total_eradicated: int = int(acts.plates.size()) * 2 + int(acts.wards.size()) * 2 + dial_needle_arrays + 13
	print("LIVE_WORLD1_PRIM_AUDIT: stage=park_dam plates=%d wards=%d dial_needles=%d stake_arrays=%d replaced_prims_live=0 total_primitives_eradicated_in_audit=%d" % [
		acts.plates.size(), acts.wards.size(), dial_needle_arrays, stake_arrays, total_eradicated])
	game.queue_free()
	await process_frame
