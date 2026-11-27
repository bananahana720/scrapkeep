extends SceneTree
# 2026-10-09 (w12 SWAP-WAVE 12-F kicker_wedge): re-pinned for the authored kicker; measured cause: the dress hides the two Kicker greybox views and places kicker_wedge recipe views at each wedge frame, so a Kicker greybox is re-materialled but hidden.
# 2026-10-23 (world 1 unit 9, Slag Bowl to sibling parity): the Fleet yard joins the dressing. Its two melt parts glow on purpose, so they skip the muted, unlit check and are held by _check_yard instead; the surface floor rises from 23 to 39 for the yard's parts.

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Dress := preload("res://src/presentation/arena_bowl_dress.gd")
const Proof := preload("res://tests/support/arena_bowl_proof.gd")
const T := preload("res://tests/support/t.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Palette := preload("res://src/core/palette.gd")
const Arena := preload("res://src/boss/arena.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const Yard := preload("res://src/presentation/arena_bowl_yard.gd")

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
		if String(view.name) in Dress.GLOW_PARTS:
			continue
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
	t.check("inspects every dressing surface", surface_count >= 39, "%d surfaces" % surface_count)
	_check_yard(dressing)
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
		t.check("greybox re-materialled: " + role, material != null and material.resource_name == roles[role] and view.visible == (role != "Kicker"))
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
	_check_kickers(arena)
	var channels := arena.get_children().filter(func(n): return n is MeshInstance3D and n.get_meta("bowl_surface", "") == "Channel")
	t.eq("both live slag channels retained", channels.size(), 2)
	for channel in channels:
		t.check("channel colour unchanged", channel.material_override.albedo_color == Color("171a19"))
	var vents := arena.get_children().filter(func(n): return n is MeshInstance3D and String(n.name).begins_with("WaterVent") and n.mesh is ArrayMesh and is_equal_approx(n.mesh.get_aabb().size.x, Rules.VENT_REACH * 2.0))
	t.eq("all mint quench pads retained", vents.size(), 4)
	for vent in vents:
		var mat := vent.material_override as ShaderMaterial
		t.check("live mint and emission unchanged", mat != null and mat.get_shader_parameter("emissive_color") == Palette.ARC
			and float(mat.get_shader_parameter("emissive_energy")) >= 0.6)


# The Fleet yard (world 1 unit 9): every part present, nothing inside the rim wall's outer face or below its top
# except the yard deck under the wall line, the melt glows only on its own material, the crowd sits on the tiers.
func _check_yard(dressing: Node3D) -> void:
	var yard := dressing.get_node_or_null("FleetYard")
	t.check("Fleet yard exists", yard != null)
	if yard == null:
		return
	for part in Dress.YARD_PARTS + Dress.GLOW_PARTS:
		t.check("yard part exists: " + part, yard.get_node_or_null(part) is MeshInstance3D)
	var nearest := INF
	for view: MeshInstance3D in yard.get_children().filter(func(n): return n is MeshInstance3D):
		for surface in view.mesh.get_surface_count():
			for vertex: Vector3 in view.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = view.transform * vertex
				nearest = minf(nearest, Vector2(point.x, point.z).length())
	t.check("the yard stands outside the rim wall", nearest >= Arena.BANK_R + Arena.WALL_THICK, "nearest %.3f m" % nearest)
	t.check("dressing adds no bodies in the yard", yard.find_children("*", "CollisionObject3D", true, false).is_empty())
	for part in Dress.GLOW_PARTS:
		var view := yard.get_node(part) as MeshInstance3D
		t.check("melt glows on the shared phase material: " + part, view.material_override == yard.melt_material
			and yard.melt_material.emission_enabled and view.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var seated := 0
	# The dummy renderer keeps no MultiMesh transforms, so the seats are read from the yard's own rest rows.
	for c in Dress.CREW_PARTS.size():
		var kind: String = Dress.CREW_PARTS[c]
		var crowd := yard.get_node_or_null(kind + "s") as MultiMeshInstance3D
		t.check("crowd exists: " + kind, crowd != null and crowd.multimesh.instance_count > 0)
		if crowd == null:
			continue
		t.check("crowd casts no shadow: " + kind, crowd.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		t.eq("one rest row per seat: " + kind, yard.seats[c].size(), crowd.multimesh.instance_count)
		for row: Dictionary in yard.seats[c]:
			var at: Vector3 = row.rest.origin
			var tier := floori((at.y - Dress.TIER_Y0 + 0.001) / Dress.TIER_DY)
			var lift := at.y - Dress.TIER_Y0 - tier * Dress.TIER_DY
			var on := tier >= 0 and tier < Dress.TIERS and absf(lift) < 0.001 \
				and absf(Vector2(at.x, at.z).length() - (Dress.TIER_R0 + Dress.TIER_DR * tier - 0.3)) < 0.01
			seated += 1 if on else 0
	var total := 0
	for kind in Dress.CREW_PARTS:
		total += (yard.get_node(kind + "s") as MultiMeshInstance3D).multimesh.instance_count
	t.check("every fan sits on a tier", seated == total and total >= 100, "%d of %d" % [seated, total])
	t.check("the yard adds no runtime light (sketch-lint L6)", yard.find_children("*", "Light3D", true, false).is_empty())
	t.check("the ledger opens on phase one", yard.ledger_line.text == Yard.LEDGER[1], yard.ledger_line.text)
	# The board's chalk panel is 14.8 m wide (arena_bowl_yard.py ledger): every line the fight writes fits inside it.
	var widest := 0.0
	for label: Label3D in [yard.ledger_line, yard.ledger_caption, yard.get_node("LedgerTitle")]:
		var lines: Array = Yard.LEDGER if label == yard.ledger_line else Yard.LEDGER_CAPTIONS if label == yard.ledger_caption else [label.text]
		for line: String in lines:
			widest = maxf(widest, label.font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size)
	t.check("every ledger line fits the board", widest > 0.0 and widest <= 14.2, "%.2f m" % widest)


# The authored kicker stands where the collider does: per Kicker greybox view one holder at its wedge frame, the
# greybox's six collider points land on the frame's wedge (foot at the origin, top 1.6 at z 7), and the recipe's base
# never rises above the collider plane y = 1.6 z / 7 by more than 16 mm and meets it at the top edge.
func _check_kickers(arena: Node3D) -> void:
	var greybox := arena.get_children().filter(func(n): return n is MeshInstance3D and n.get_meta("bowl_surface", "") == "Kicker")
	var holders := arena.get_children().filter(func(n): return String(n.name).begins_with("KickerWedge"))
	t.eq("one recipe kicker per Kicker greybox view", holders.size(), greybox.size())
	var base_count := 0
	for path: String in RecipeProps.base_paths("kicker_wedge"):
		var scene := (load(path) as PackedScene).instantiate()
		base_count += scene.find_children("*", "MeshInstance3D", true, false).size()
		scene.free()
	for view: MeshInstance3D in greybox:
		var frame: Transform3D = view.transform * (view.get_meta(Arena.WEDGE_FRAME) as Transform3D)
		var matched := holders.filter(func(h): return (h as Node3D).transform.is_equal_approx(frame))
		t.eq("recipe kicker stands at the wedge frame", matched.size(), 1)
		if matched.size() != 1:
			continue
		var holder: Node3D = matched[0]
		var to_local := frame.affine_inverse() * view.transform
		var on_wedge := true
		for vertex: Vector3 in view.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var p := to_local * vertex
			var top := absf(p.y - Arena.KICKER_TOP) < 0.001 and absf(p.z - Arena.KICKER_LENGTH) < 0.001
			var low := absf(p.y) < 0.001 and (absf(p.z) < 0.001 or absf(p.z - Arena.KICKER_LENGTH) < 0.001)
			on_wedge = on_wedge and (top or low) and absf(absf(p.x) - Arena.KICKER_HALF_WIDTH) < 0.001
		t.check("collider points sit on the wedge frame", on_wedge)
		var views := holder.get_children().filter(func(n): return n is MeshInstance3D)
		var bases := views.filter(func(n): return not n.has_meta(RecipeProps.META_FADE))
		var shells := views.filter(func(n): return n.has_meta(RecipeProps.META_FADE))
		t.eq("recipe base views present", bases.size(), base_count)
		t.eq("recipe shells present", shells.size(), RecipeProps.shell_rows("kicker_wedge").size())
		for v: MeshInstance3D in views:
			t.check("recipe view visible: " + String(v.name), v.visible and v.is_visible_in_tree() and v.mesh != null)
		for v: MeshInstance3D in bases:
			t.check("recipe base casts its shadow: " + String(v.name), v.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		t.check("recipe riding body present", holder.get_node_or_null("kicker_wedge_Body") is MeshInstance3D)
		var above := -INF
		var reach := INF
		for v: MeshInstance3D in bases:
			for vertex: Vector3 in v.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var p := v.transform * vertex
				above = maxf(above, p.y - Arena.KICKER_TOP * p.z / Arena.KICKER_LENGTH)
				if p.z > Arena.KICKER_LENGTH - 0.05:
					reach = minf(reach, absf(p.y - Arena.KICKER_TOP))
		t.check("recipe base never above the collider plane by more than 16 mm", above <= 0.016, "%.4f m" % above)
		t.check("riding face meets the collider top", reach <= 0.016, "%.4f m" % reach)

