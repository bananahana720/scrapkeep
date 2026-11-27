extends SceneTree

const T := preload("res://tests/support/t.gd")
const Palette := preload("res://src/core/palette.gd")
const Augments := preload("res://src/movement/augments.gd")
const PropMeshes := preload("res://src/presentation/craft_prop_meshes.gd")
const PrimCensus := preload("res://tools/prim_census.gd")
const ActivityView := preload("res://src/world/activity_view.gd")
const RescueSite := preload("res://src/world/rescue_site.gd")
const Contraptions := preload("res://src/world/contraptions.gd")
const Gorge := preload("res://src/world/map_gorge.gd")
const Launch := preload("res://src/world/launch.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const Game := preload("res://src/game.gd")

var t := T.new("step5_world1_sites_craft_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	PropMeshes.reset_for_tests()
	_check_pin_zero_stand_ins()
	_check_step5_mesh_topology_and_wear_masks()
	_check_activity_view_zero_prims()
	_check_launch_zero_prims()
	_check_scrap_field_beacons_zero_prims()
	_check_contraptions_world1_zero_prims()
	await _check_live_world1_sites_and_sable_stakes()
	PropMeshes.reset_for_tests()
	ScrapField.reset_for_tests()
	quit(t.verdict())


func _check_pin_zero_stand_ins() -> void:
	var pin := PrimCensus.load_pin()
	var stand_ins := pin.filter(func(r): return String(r.get("kind", "")).begins_with("stand-in"))
	t.check("prim_census_pin.tsv has zero stand-in rows left (W1-23 resolved)", stand_ins.is_empty(), str(stand_ins))


func _check_step5_mesh_topology_and_wear_masks() -> void:
	var builders := {
		"sable_stake_body": [func(): return PropMeshes.sable_stake_body(), true],
		"sable_stake_ring": [func(): return PropMeshes.sable_stake_ring(), false],
		"activity_column_spire": [func(): return PropMeshes.activity_column_spire(1.4, 70.0), false],
		"activity_glyph_cross": [func(): return PropMeshes.activity_glyph_cross(3.2), false],
		"activity_glyph_diamond": [func(): return PropMeshes.activity_glyph_diamond(3.2), false],
		"activity_glyph_cube": [func(): return PropMeshes.activity_glyph_cube(3.2), false],
		"activity_ring_dash": [func(): return PropMeshes.activity_ring_dash(0.9), false],
		"activity_pay_beam": [func(): return PropMeshes.activity_pay_beam(0.35, 14.0), false],
		"rescue_ring_dash": [func(): return PropMeshes.rescue_ring_dash(0.62), false],
		"rescue_cage_bar": [func(): return PropMeshes.rescue_cage_bar(0.08, 3.0), true],
		"rescue_cage_rail": [func(): return PropMeshes.rescue_cage_rail(2.8, 0.08), true],
		"rescue_cage_post": [func(): return PropMeshes.rescue_cage_post(0.3, 3.2), true],
		"rescue_cage_lockbox": [func(): return PropMeshes.rescue_cage_lockbox(Vector3(0.7, 0.5, 0.2)), false],
		"launcher_mouth_ring": [func(): return PropMeshes.launcher_mouth_ring(3.8), false],
		"fluted_plume_column": [func(): return PropMeshes.fluted_plume_column(1.6, 2.4, 10.0), false],
		"cannon_band_collar": [func(): return PropMeshes.cannon_band_collar(), false],
		"grapple_cable_span": [func(): return PropMeshes.grapple_cable_span(24.0), false],
		"grapple_target_ring": [func(): return PropMeshes.grapple_target_ring(3.4), false],
		"sluice_pay_ring": [func(): return PropMeshes.sluice_pay_ring(), false],
		"steam_puff_cloud": [func(): return PropMeshes.steam_puff_cloud(), false],
		"vent_dash_segment": [func(): return PropMeshes.vent_dash_segment(0.8), false],
		"launch_flight_ring": [func(): return PropMeshes.launch_flight_ring(3.2), false],
		"launch_landing_pad": [func(): return PropMeshes.launch_landing_pad(7.0), false],
		"scrap_beacon_column": [func(): return PropMeshes.scrap_beacon_column(0.20, 0.03, 14.0), false],
	}
	for name in builders:
		var fn: Callable = builders[name][0]
		var masked: bool = builders[name][1]
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
		var cols = arr[Mesh.ARRAY_COLOR]
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
		var col_ok := (cols != null and (cols as PackedColorArray).size() == verts.size()) if masked else (cols == null)
		t.check("%s is watertight outward-wound manifold with UVs, tangents, expected color mask" % name,
			verts.size() >= 12 and verts.size() % 3 == 0 and norms.size() == verts.size()
			and uvs.size() == verts.size() and tangents.size() == verts.size() * 4 and col_ok
			and bad_winding == 0 and bad_normal == 0 and zero_area == 0 and open_edges == 0 and non_manifold == 0,
			"verts=%d open=%d non_manifold=%d bad_winding=%d col_ok=%s" % [verts.size(), open_edges, non_manifold, bad_winding, col_ok])

	var stake_arr := PropMeshes.sable_stake_body().surface_get_arrays(0)
	var stake_cols: PackedColorArray = stake_arr[Mesh.ARRAY_COLOR]
	var max_r := 0.0
	var max_g := 0.0
	var max_b := 0.0
	for c in stake_cols:
		max_r = maxf(max_r, c.r)
		max_g = maxf(max_g, c.g)
		max_b = maxf(max_b, c.b)
	t.check("sable_stake_body encodes RGB edge-wear, cavity-grime, and ARC emissive masks",
		max_r > 0.8 and max_g > 0.7 and max_b > 0.9,
		"max RGB=(%.2f, %.2f, %.2f)" % [max_r, max_g, max_b])
	var stake_aabb := PropMeshes.sable_stake_body().get_aabb()
	t.check("sable_stake_body fits inside Stake CylinderShape3D(h=0.9, r=0.3)",
		stake_aabb.size.y <= 0.92 and stake_aabb.size.x <= 0.60 and stake_aabb.size.z <= 0.60, str(stake_aabb))


func _check_activity_view_zero_prims() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	for id in ["cracked_cache", "hold_the_relay", "surge_run", "ambush_altar"]:
		var view := ActivityView.new()
		holder.add_child(view)
		view.build(id, 6.0)
		view.set_sight(0.75)
		view.ring_role("amber")
		var pay := ActivityView.gem(id)
		holder.add_child(pay)
	var prims := _prims_under(holder)
	t.check("ActivityView columns, glyphs (cross/diamond/cube), rings, and pay beams build zero PrimitiveMesh",
		prims.is_empty(), str(prims))
	holder.free()


func _check_launch_zero_prims() -> void:
	var launch := Launch.new()
	root.add_child(launch)
	launch.setup()
	launch.fire(Vector3.ZERO, Vector3(0.0, 24.0, 18.0))
	launch.mark_landing(Vector3(0.0, 20.0, 40.0), Vector3(0.0, -4.0, 18.0), func(_x: float, _z: float): return 0.0)
	var prims := _prims_under(launch)
	t.check("Launch flight rings, landing rings, and touchdown pad build zero PrimitiveMesh",
		prims.is_empty() and launch._rings.size() == Launch.RINGS and launch._landing.size() == Launch.LANDING_RINGS,
		str(prims))
	launch.free()


func _check_scrap_field_beacons_zero_prims() -> void:
	ScrapField.reset_for_tests()
	var field := ScrapField.new()
	root.add_child(field)
	field.setup()
	field.drop_panel(Vector3(0.0, 0.0, 0.0), "hull_plate", false, false)
	field.drop_panel(Vector3(10.0, 0.0, 0.0), "hull_plate", true, true)
	var prims := _prims_under(field)
	t.check("ScrapField dropped panels and 14 m rib cache columns build zero PrimitiveMesh",
		prims.is_empty(), str(prims))
	field.clear()
	field.free()


func _check_contraptions_world1_zero_prims() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var map := Gorge.new()
	map.contraptions = [
		{"kind": "launcher", "id": "w1_cannon", "style": "cannon", "recipe": "cannon", "at": Vector2(0, 0),
			"radius": 4.0, "target": Vector3(0, 18, 40), "floor": 20.0, "min_flight": 2.2, "charge": 3.0},
		{"kind": "launcher", "id": "w1_treb", "style": "trebuchet", "recipe": "trebuchet", "at": Vector2(30, 0),
			"radius": 3.5, "target": Vector3(30, 25, 60), "floor": 20.0, "min_flight": 2.5, "charge": 3.0},
		{"kind": "launcher", "id": "w1_geyser", "style": "geyser", "recipe": "geyser_vent", "at": Vector2(60, 0),
			"radius": 3.5, "target": Vector3(60, 22, 40), "floor": 16.0, "min_flight": 2.2, "charge": 3.0},
		{"kind": "cable", "id": "w1_cable", "from": Vector3(0, 12, -20), "to": Vector3(40, 4, 20), "radius": 3.4, "floor": 18.0},
		{"kind": "valve", "id": "w1_valve", "at": Vector2(-30, 0),
			"door": {"at": Vector2(-30, 14), "size": Vector3(10, 5, 1), "turn": 0.0},
			"vent": {"at": Vector2(-42, 8), "radius": 5.0}},
		{"kind": "sluice_valve", "id": "w1_sluice", "at": Vector2(-60, 0), "price": 8, "charge": 10.0,
			"lane": {"from": Vector2(-60, 4), "to": Vector2(-60, 28), "half_width": 4.0}},
		{"kind": "thermal", "id": "w1_thermal", "at": Vector2(90, 0), "radius": 5.0, "height": 40.0},
	]
	var c := Contraptions.new()
	holder.add_child(c)
	c.setup(map, func(x: float, z: float, lift := 0.0): return Vector3(x, lift, z), 14.0, 26.0)
	c._puff(Vector3(0, 4, 0), 3.0)
	var prims := _prims_under(c)
	t.check("World 1 skinned launchers, geysers, cables, grapple hooks, valves, sluice pay rings, thermals, and puffs build zero PrimitiveMesh",
		prims.is_empty(), str(prims))
	var shackles := c.find_children("GrappleShackle", "MeshInstance3D", true, false)
	t.check("Grapple line mounts sculpted grapple_hook_anchor shackle", shackles.size() == 1 and shackles[0].mesh == PropMeshes.grapple_hook_anchor())
	holder.free()


func _check_live_world1_sites_and_sable_stakes() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	for _i in 300:
		if game.flow != null:
			break
		await physics_frame
	if not t.check("live game initialized", game.flow != null):
		game.free()
		return
	game.ctx.calm = true
	game.flow.press_start()
	var roster := preload("res://src/core/class_def.gd").all()
	var sable_idx := 0
	for idx in roster.size():
		if roster[idx].id == "pylon_engineer":
			sable_idx = idx
			break
	game.flow.choose_class(sable_idx)
	for _i in 12:
		await physics_frame

	var stakes = game.combat.ultimate.stakes
	var planted = stakes.plant(game.player.ball_position() + Vector3(3.0, 0.0, 3.0))
	t.check("SableStakes.plant spawns live Stake with CylinderShape3D(0.9, 0.3) and STAKE_MASK",
		planted != null and planted.collision_layer == Augments.STAKE_MASK
		and planted.is_in_group(Augments.STAKE_GROUP) and planted.is_in_group(Augments.ANCHOR_GROUP))
	if planted != null:
		var col := planted.get_child(0) as CollisionShape3D
		var cyl := col.shape as CylinderShape3D
		t.check("Stake collider keeps exact radius=0.3 and height=0.9",
			cyl != null and is_equal_approx(cyl.radius, 0.3) and is_equal_approx(cyl.height, 0.9))
		var stake_prims := _prims_under(planted)
		t.check("Planted Sable Stake draws zero PrimitiveMesh", stake_prims.is_empty(), str(stake_prims))

	var contraption_prims: Array[String] = []
	for c_node in game.world.contraptions.values():
		if c_node is Node:
			contraption_prims.append_array(_prims_under(c_node))
	var owners_checked := {
		"stakes": _prims_under(stakes),
		"rescue": _prims_under(game.world.rescue),
		"contraptions": contraption_prims,
		"launch": _prims_under(game.world.launch),
		"scrap": _prims_under(game.build.scrap),
	}
	var act_view_prims: Array[String] = []
	for site in game.world.activities.sites:
		if site is Node and "view" in site and site.view is Node:
			act_view_prims.append_array(_prims_under(site.view))
	owners_checked["activity_views"] = act_view_prims

	for key in owners_checked:
		var list: Array = owners_checked[key]
		t.check("live park_dam %s has zero PrimitiveMesh" % key, list.is_empty(), str(list))

	var cage = game.world.rescue.cage("rivet")
	if t.check("park_dam Rivet rescue cage present", cage != null):
		cage.fire()
		cage.tick(RescueSite.BREAK_SECONDS + 0.1)
		var freed_prims := _prims_under(cage)
		t.check("freed Rivet rescue cage (including FreedWalls and ground ring) has zero PrimitiveMesh",
			freed_prims.is_empty(), str(freed_prims))

	var census := PrimCensus.new()
	var stage1_rows := census.scan(game, Engine.get_physics_frames(), 1, true)
	print("step5 park_dam live PrimitiveMesh keys remaining: %d" % stage1_rows.size())
	game.free()


func _prims_under(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node == null:
		return out
	if node is MeshInstance3D and node.mesh is PrimitiveMesh:
		out.append("%s:%s" % [node.name, node.mesh.get_class()])
	for child in node.get_children():
		out.append_array(_prims_under(child))
	return out


static func _vkey(v: Vector3) -> String:
	return "%d:%d:%d" % [roundi(v.x * 10000.0), roundi(v.y * 10000.0), roundi(v.z * 10000.0)]


static func _ekey(a: String, b: String) -> String:
	return (a + "|" + b) if a < b else (b + "|" + a)
