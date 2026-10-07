extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Dress := preload("res://src/presentation/arena_bowl_dress.gd")
const Proof := preload("res://tests/support/arena_bowl_proof.gd")
const T := preload("res://tests/support/t.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Palette := preload("res://src/core/palette.gd")

var t := T.new("dress_arb_test")
var game
var errors := Proof.Errors.new()


func _initialize() -> void:
	OS.add_logger(errors)
	var directory := OS.get_environment("ARB_ASSET_DIR")
	if not directory.is_empty():
		Dress.asset_dir = directory
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	t.check("no bowl dressing at boot", game.find_children("ArenaBowlDress", "Node3D", true, false).is_empty()
		and game.boss.arena == null)
	Harness.start_run(game)
	Harness.enter(game, Vector3(18, 0, 0))
	await physics_frame
	var arena: Node3D = game.boss.arena
	t.check("enters the real Brindle fight", game.boss.active() and game.flow.state_name() == "boss")
	Proof.check_colliders(t, arena)
	var dressing := arena.get_node_or_null("ArenaBowlDress") as Node3D
	t.check("foundry dressing exists", dressing != null)
	if dressing != null:
		_check_dress(arena, dressing)
		t.eq("no fallback warnings", errors.warnings.size(), 0)
		var first_id := dressing.get_instance_id()
		game.boss.enter_arena(Vector3(18, 0, 0))
		await physics_frame
		arena = game.boss.arena
		var replacement := arena.get_node_or_null("ArenaBowlDress") as Node3D
		t.check("retry builds a fresh dressing", replacement != null and replacement.get_instance_id() != first_id)
		Proof.check_colliders(t, arena)
	else:
		Proof.check_greybox(t, arena)
		t.eq("missing folder warns once", errors.warnings.size(), 1)
		print("ARB fallback: old greybox visible, warnings=%d" % errors.warnings.size())
	t.eq("no loader errors or crashes", errors.errors, 0)
	game.free()
	Dress.asset_dir = Dress.ASSET_DIR
	OS.remove_logger(errors)
	quit(t.verdict())


func _check_dress(arena: Node3D, dressing: Node3D) -> void:
	for part in Dress.FOUNDRY_PARTS + ["SpillwayRimStone"]:
		t.check("foundry part exists: " + part, dressing.get_node_or_null(part) != null)
	t.eq("reuses Spillway rim stone", dressing.get_node("SpillwayRimStone").get_child_count(), 16)
	var nearest_stone := INF
	for view: MeshInstance3D in dressing.get_node("SpillwayRimStone").get_children():
		var local := dressing.global_transform.affine_inverse() * view.global_transform
		for surface in view.mesh.get_surface_count():
			for vertex: Vector3 in view.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = local * vertex
				nearest_stone = minf(nearest_stone, Vector2(point.x, point.z).length())
	t.check("rim rubble stays behind the wall and out of the riding lane", nearest_stone >= 60.5, "nearest stone %.3f m" % nearest_stone)
	var pools := dressing.get_node("CooledSlagPools") as MeshInstance3D
	var pan_centers: Array[Vector2] = []
	for degrees in [15.0, 165.0, 255.0]:
		var angle := deg_to_rad(degrees)
		pan_centers.append(Vector2(cos(angle), sin(angle)) * 70.5)
	var supported := true
	var exterior_vertices := 0
	for surface in pools.mesh.get_surface_count():
		for vertex: Vector3 in pools.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var point: Vector3 = pools.transform * vertex
			var flat := Vector2(point.x, point.z)
			if flat.length() > 62.0:
				exterior_vertices += 1
				var nearest := INF
				for center in pan_centers:
					nearest = minf(nearest, flat.distance_to(center))
				if nearest > 4.2:
					supported = false
	t.check("cooled overflow stays on the foundry catch pans", supported and exterior_vertices > 0)
	t.check("dressing adds no physics bodies or colliders", dressing.find_children("*", "CollisionObject3D", true, false).is_empty()
		and dressing.find_children("*", "CollisionShape3D", true, false).is_empty())
	var surface_count := 0
	for view: MeshInstance3D in dressing.find_children("*", "MeshInstance3D", true, false):
		t.check("visual mesh is visible: " + String(view.name), view.visible and view.mesh != null)
		if view.mesh == null:
			continue
		for surface in view.mesh.get_surface_count():
			surface_count += 1
			var material := view.get_active_material(surface) as StandardMaterial3D
			t.check("rebuilt vertex-colour material: " + String(view.name), material != null
				and material.vertex_color_use_as_albedo and not material.emission_enabled
				and Dress.SLOTS.has(material.resource_name))
			var colors = view.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			t.check("authored colour data: " + String(view.name), colors != null and not colors.is_empty())
			if colors != null:
				var muted := true
				for color: Color in colors:
					var srgb := color.linear_to_srgb()
					if srgb.v > 0.83 or srgb.s > 0.65:
						muted = false
				t.check("dressing stays muted: " + String(view.name), muted)
	t.check("inspects every dressing surface", surface_count >= 23, "%d surfaces" % surface_count)
	var roles := {"Floor": "bowl_cast_floor", "Bank": "bowl_sandstone_bank", "RimWall": "bowl_rusted_rim",
		"Ramp": "bowl_cast_ramps", "Kicker": "bowl_cast_ramps", "Mast": "bowl_crane_masts", "Crossbar": "bowl_crane_masts"}
	var counts := {}
	for view in arena.get_children():
		if not view is MeshInstance3D:
			continue
		var role: String = view.get_meta("bowl_surface", "")
		if not roles.has(role):
			continue
		counts[role] = counts.get(role, 0) + 1
		var material: Material = view.material_override
		t.check("greybox re-materialled: " + role, material != null and material.resource_name == roles[role] and view.visible)
		if material is StandardMaterial3D:
			t.check("vertex colour or explicit texture: " + role, material.vertex_color_use_as_albedo or material.albedo_texture != null)
		elif material is ShaderMaterial:
			t.check("Spillway bank has explicit textures", material.get_shader_parameter("strata_map") is Texture2D
				and material.get_shader_parameter("floor_map") is Texture2D and material.get_shader_parameter("cliff_only") == true)
	for role in roles:
		var expected := 4
		if role in ["Floor", "Bank", "RimWall"]:
			expected = 1
		elif role in ["Ramp", "Kicker"]:
			expected = 2
		t.eq("all arena surfaces dressed: " + role, counts.get(role, 0), expected)
	var channels := arena.get_children().filter(func(n): return n is MeshInstance3D and n.get_meta("bowl_surface", "") == "Channel")
	t.eq("both live slag channels retained", channels.size(), 2)
	for channel in channels:
		t.check("channel colour unchanged", channel.material_override.albedo_color == Color("171a19"))
	var vents := arena.get_children().filter(func(n): return n is MeshInstance3D and n.mesh is CylinderMesh and is_equal_approx(n.mesh.top_radius, Rules.VENT_REACH))
	t.eq("all mint quench pads retained", vents.size(), 4)
	for vent in vents:
		t.check("live mint and emission unchanged", vent.material_override.albedo_color == Palette.ARC
			and is_equal_approx(vent.material_override.emission_energy_multiplier, 0.6))
