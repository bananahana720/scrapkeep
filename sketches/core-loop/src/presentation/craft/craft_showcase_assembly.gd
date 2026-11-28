class_name CraftShowcaseAssembly
extends RefCounted


const HeroSculptor := preload("res://src/presentation/craft/hero_kitbash_sculptor.gd")
const Lookdev := preload("res://src/presentation/craft/craft_lookdev.gd")
const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/core/flash_guard.gd")
const PropMeshes := preload("res://src/presentation/craft_prop_meshes.gd")

const SHOWCASE_SCENE_PATH := "res://src/presentation/craft/craft_showcase_arena.tscn"
const SELECTIVE_GLOW_THRESHOLD_MIN := 2.4

static var _copper_coil_mat: ShaderMaterial
static var _vista_masonry_mat: ShaderMaterial
static var _vista_stack_mat: ShaderMaterial
static var _gantry_column_mat: ShaderMaterial
static var _gantry_truss_mat: ShaderMaterial

const PERIMETER_PRESET_MAP := {
	"IndustrialPerimeterFraming/RetainingWall_West": "scorched_concrete",
	"IndustrialPerimeterFraming/RetainingWall_East": "scorched_concrete",
	"IndustrialPerimeterFraming/OverlookParapet_North": "scorched_concrete",
	"IndustrialPerimeterFraming/Catwalk_West": "oil_slicked_iron",
	"IndustrialPerimeterFraming/Catwalk_East": "oil_slicked_iron",
	"IndustrialPerimeterFraming/FurnaceBay_NW/Housing": "oxidized_hull_plating",
	"IndustrialPerimeterFraming/FurnaceBay_NW/ExhaustHood": "oil_slicked_iron",
	"IndustrialPerimeterFraming/FurnaceBay_NW/Louver_1": "oil_slicked_iron",
	"IndustrialPerimeterFraming/FurnaceBay_NW/Louver_2": "oil_slicked_iron",
	"IndustrialPerimeterFraming/FurnaceBay_NW/Louver_3": "oil_slicked_iron",
	"IndustrialPerimeterFraming/FurnaceBay_NW/Stanchion_L": "oil_slicked_iron",
	"IndustrialPerimeterFraming/FurnaceBay_NW/Stanchion_R": "oil_slicked_iron",
	"IndustrialPerimeterFraming/FurnaceBay_NE/Housing": "oxidized_hull_plating",
	"IndustrialPerimeterFraming/FurnaceBay_NE/ExhaustHood": "oil_slicked_iron",
	"IndustrialPerimeterFraming/FurnaceBay_NE/Louver_1": "oil_slicked_iron",
	"IndustrialPerimeterFraming/FurnaceBay_NE/Louver_2": "oil_slicked_iron",
	"IndustrialPerimeterFraming/FurnaceBay_NE/Louver_3": "oil_slicked_iron",
	"IndustrialPerimeterFraming/FurnaceBay_NE/Stanchion_L": "oil_slicked_iron",
	"IndustrialPerimeterFraming/FurnaceBay_NE/Stanchion_R": "oil_slicked_iron",
	"CombatLaneFloor/ApronSeam_North": "oil_slicked_iron",
	"CombatLaneFloor/ApronSeam_South": "oil_slicked_iron",
	"CombatLaneFloor/ApronSeam_West": "oil_slicked_iron",
	"CombatLaneFloor/ApronSeam_East": "oil_slicked_iron",
}

const SOCKET_SPECS := {
	"HeroSocket_CenterBeacon": {
		"hero_id": HeroSculptor.HERO_SALVAGE_PRESS,
		"scale": 1.35,
		"yaw_deg": 18.0,
		"suspend_under_y": NAN,
	},
	"HeroSocket_EMCranGantry": {
		"hero_id": HeroSculptor.HERO_EM_CRANE,
		"scale": 1.45,
		"yaw_deg": -24.0,
		"suspend_under_y": 22.8,
	},
	"HeroSocket_ConduitPylon_W": {
		"hero_id": HeroSculptor.HERO_CONDUIT_PYLON,
		"scale": 1.25,
		"yaw_deg": 90.0,
		"suspend_under_y": NAN,
	},
	"HeroSocket_ConduitPylon_E": {
		"hero_id": HeroSculptor.HERO_CONDUIT_PYLON,
		"scale": 1.25,
		"yaw_deg": -90.0,
		"suspend_under_y": NAN,
	},
}

const REPLACED_PLACEHOLDERS := [
	"IndustrialPerimeterFraming/ArcConduitAnchor_W",
	"IndustrialPerimeterFraming/ArcConduitAnchor_E",
]

const REDUNDANT_FLOOR_SEAMS := [
	"CombatLaneFloor/ExpansionJoint_N",
	"CombatLaneFloor/ExpansionJoint_S",
	"CombatLaneFloor/ExpansionJoint_W",
	"CombatLaneFloor/ExpansionJoint_E",
]


static func assemble_into(arena: Node3D) -> Dictionary:
	var receipt := {
		"mounted_heroes": {},
		"hero_nodes": {},
		"total_surfaces_bound": 0,
		"perimeter_surfaces_bound": 0,
		"floor_bound": false,
		"floor_shader_path": "",
		"sockets_populated": 0,
		"glow_bloom": -1.0,
		"glow_hdr_threshold": 0.0,
	}
	if arena == null:
		return receipt

	for rel_path: String in REPLACED_PLACEHOLDERS:
		var placeholder := arena.get_node_or_null(rel_path) as Node3D
		if placeholder != null:
			placeholder.visible = false

	var copper_mat := _get_copper_coil_material()

	var sockets_root := arena.get_node_or_null("HeroSockets") as Node3D
	if sockets_root != null:
		for socket_name: String in SOCKET_SPECS.keys():
			var marker := sockets_root.get_node_or_null(socket_name) as Marker3D
			if marker == null:
				continue
			var spec: Dictionary = SOCKET_SPECS[socket_name]
			var hero_id: StringName = spec["hero_id"]
			var mesh: ArrayMesh = HeroSculptor.build_hero(hero_id)
			if mesh == null:
				continue

			var existing := marker.get_node_or_null("MountedHero")
			if existing != null:
				marker.remove_child(existing)
				existing.free()

			var mi := MeshInstance3D.new()
			mi.name = "MountedHero"
			mi.mesh = mesh
			var hero_scale := float(spec["scale"])
			mi.scale = Vector3.ONE * hero_scale
			mi.rotation_degrees = Vector3(0.0, float(spec["yaw_deg"]), 0.0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

			var aabb := mesh.get_aabb()
			var suspend_y := float(spec["suspend_under_y"])
			if not is_nan(suspend_y):
				var top_local := aabb.end.y * hero_scale
				mi.position = Vector3(0.0, (suspend_y - marker.position.y) - top_local + 0.35, 0.0)
			else:
				mi.position = Vector3(0.0, -aabb.position.y * hero_scale, 0.0)

			var bound := Lookdev.bind_hero_mesh(mi)
			if copper_mat != null:
				for si in mesh.get_surface_count():
					if mesh.surface_get_name(si) == "copper_coil":
						mi.set_surface_override_material(si, copper_mat)
			marker.add_child(mi)

			receipt["total_surfaces_bound"] = int(receipt["total_surfaces_bound"]) + bound
			receipt["sockets_populated"] = int(receipt["sockets_populated"]) + 1
			(receipt["mounted_heroes"] as Dictionary)[socket_name] = {
				"hero_id": String(hero_id),
				"surfaces_bound": bound,
				"surface_count": mesh.get_surface_count(),
				"scale": hero_scale,
			}
			(receipt["hero_nodes"] as Dictionary)[socket_name] = mi

	var perimeter_bound := 0
	for rel_path: String in PERIMETER_PRESET_MAP.keys():
		var pmi := arena.get_node_or_null(rel_path) as MeshInstance3D
		if pmi != null and Lookdev.bind_mesh(pmi, String(PERIMETER_PRESET_MAP[rel_path]), -1, true) != null:
			perimeter_bound += 1
	var gantry_root := arena.get_node_or_null("IndustrialPerimeterFraming/OverheadGantryTruss")
	if gantry_root != null:
		perimeter_bound += _upgrade_gantry_and_catwalks(arena, gantry_root)
	var vista_bound := _upgrade_vista_masonry(arena)
	perimeter_bound += vista_bound
	receipt["perimeter_surfaces_bound"] = perimeter_bound
	receipt["vista_surfaces_bound"] = vista_bound

	var floor_mi := arena.get_node_or_null("CombatLaneFloor/FloorMesh") as MeshInstance3D
	if floor_mi != null:
		var floor_mat := Lookdev.bind_mesh(floor_mi, "combat_floor_apron")
		if floor_mat != null and floor_mat.shader != null:
			receipt["floor_bound"] = true
			receipt["floor_shader_path"] = floor_mat.shader.resource_path
		for seam_path: String in REDUNDANT_FLOOR_SEAMS:
			var seam := arena.get_node_or_null(seam_path) as Node3D
			if seam != null:
				seam.visible = false

	var we := arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		we.environment.glow_bloom = 0.0
		we.environment.glow_hdr_threshold = maxf(we.environment.glow_hdr_threshold, SELECTIVE_GLOW_THRESHOLD_MIN)
		receipt["glow_bloom"] = we.environment.glow_bloom
		receipt["glow_hdr_threshold"] = we.environment.glow_hdr_threshold

	Lookdev.sync_flash_guard(FlashGuard.on)
	if _copper_coil_mat != null:
		_copper_coil_mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
	return receipt


static func _get_copper_coil_material() -> ShaderMaterial:
	if _copper_coil_mat != null:
		_copper_coil_mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
		return _copper_coil_mat
	var base := Lookdev.preset_material("oxidized_hull_plating")
	if base == null:
		return null
	var mat := base.duplicate(false) as ShaderMaterial
	mat.resource_name = "brushed_copper_coil"
	mat.set_shader_parameter("base_albedo", Palette.COPPER)
	mat.set_shader_parameter("secondary_albedo", Palette.COPPER.darkened(0.28))
	mat.set_shader_parameter("base_metallic", 0.78)
	mat.set_shader_parameter("base_roughness", 0.34)
	mat.set_shader_parameter("edge_wear_albedo", Color("e3b986"))
	mat.set_shader_parameter("edge_wear_strength", 0.65)
	mat.set_shader_parameter("grime_strength", 0.62)
	mat.set_shader_parameter("normal_relief", 0.36)
	mat.set_shader_parameter("detail_tex_strength", 0.34)
	mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
	_copper_coil_mat = mat
	return _copper_coil_mat


static func _upgrade_vista_masonry(arena: Node3D) -> int:
	var vistas := arena.get_node_or_null("VistaMegastructures")
	if vistas == null:
		return 0
	var masonry_mat := _get_vista_masonry_material()
	var stack_mat := _get_vista_stack_material()
	if masonry_mat == null or stack_mat == null:
		return 0
	var count := 0
	var trestle := vistas.get_node_or_null("CanyonBasinFloor/HorizonAqueductTrestle") as MeshInstance3D
	if trestle != null:
		trestle.material_override = masonry_mat
		count += 1
	var piers_root := vistas.get_node_or_null("HorizonFramingPiers")
	if piers_root != null:
		for child in piers_root.get_children():
			for mesh_name: String in ["PierConcrete", "MesaSilhouette"]:
				var mi := child.get_node_or_null(mesh_name) as MeshInstance3D
				if mi != null:
					mi.material_override = masonry_mat
					count += 1
	var stacks_root := vistas.get_node_or_null("SmelterSmokestacks")
	if stacks_root != null:
		for child in stacks_root.get_children():
			var body := child.get_node_or_null("StackBody") as MeshInstance3D
			if body != null:
				body.material_override = stack_mat
				count += 1
	return count


static func _get_vista_masonry_material() -> ShaderMaterial:
	if _vista_masonry_mat != null:
		_vista_masonry_mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
		return _vista_masonry_mat
	var base := Lookdev.preset_material("scorched_concrete")
	if base == null:
		return null
	var mat := base.duplicate(false) as ShaderMaterial
	mat.resource_name = "vista_weathered_masonry"
	mat.set_shader_parameter("use_vertex_masks", false)
	mat.set_shader_parameter("detail_tile_metres", 15.0)
	mat.set_shader_parameter("macro_scale", 0.042)
	mat.set_shader_parameter("detail_tex_strength", 0.88)
	mat.set_shader_parameter("base_albedo", Color(0.45, 0.39, 0.33, 1.0))
	mat.set_shader_parameter("secondary_albedo", Color(0.24, 0.22, 0.21, 1.0))
	mat.set_shader_parameter("macro_color_mix", 0.52)
	mat.set_shader_parameter("auto_curvature_weight", 0.38)
	mat.set_shader_parameter("edge_wear_strength", 0.74)
	mat.set_shader_parameter("grime_strength", 1.15)
	mat.set_shader_parameter("foot_grime_height", 0.0)
	mat.set_shader_parameter("dust_strength", 0.42)
	mat.set_shader_parameter("normal_relief", 0.92)
	mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
	_vista_masonry_mat = mat
	return _vista_masonry_mat


static func _get_vista_stack_material() -> ShaderMaterial:
	if _vista_stack_mat != null:
		_vista_stack_mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
		return _vista_stack_mat
	var base := Lookdev.preset_material("oil_slicked_iron")
	if base == null:
		return null
	var mat := base.duplicate(false) as ShaderMaterial
	mat.resource_name = "vista_smelter_stack_iron"
	mat.set_shader_parameter("use_vertex_masks", false)
	mat.set_shader_parameter("detail_tile_metres", 13.0)
	mat.set_shader_parameter("macro_scale", 0.05)
	mat.set_shader_parameter("detail_tex_strength", 0.78)
	mat.set_shader_parameter("base_albedo", Color(0.34, 0.31, 0.28, 1.0))
	mat.set_shader_parameter("secondary_albedo", Color(0.20, 0.19, 0.18, 1.0))
	mat.set_shader_parameter("macro_color_mix", 0.48)
	mat.set_shader_parameter("base_roughness", 0.84)
	mat.set_shader_parameter("base_metallic", 0.26)
	mat.set_shader_parameter("oil_sheen_strength", 0.32)
	mat.set_shader_parameter("auto_curvature_weight", 0.34)
	mat.set_shader_parameter("foot_grime_height", 0.0)
	mat.set_shader_parameter("normal_relief", 0.78)
	mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
	_vista_stack_mat = mat
	return _vista_stack_mat


static func apply_quality_tier(arena: Node3D, tier: String) -> Dictionary:
	if arena == null:
		return {}
	var rig := arena.get_node_or_null("VistaAtmosphereRig")
	var result := {}
	if rig != null and rig.has_method("apply_quality_tier"):
		result = rig.apply_quality_tier(tier)
	var we := arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		we.environment.glow_bloom = 0.0
		we.environment.glow_hdr_threshold = maxf(we.environment.glow_hdr_threshold, SELECTIVE_GLOW_THRESHOLD_MIN)
	return result


static func _upgrade_gantry_and_catwalks(arena: Node3D, gantry_root: Node) -> int:
	var bound := 0
	var col_mat := _get_gantry_column_material()
	var truss_mat := _get_gantry_truss_material()
	var col_mesh := PropMeshes.gantry_column_mesh(1.8, 27.0, 1.8)
	for child in gantry_root.get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if String(mi.name).begins_with("Column_"):
			mi.mesh = col_mesh
			mi.position.y = 0.0
			if col_mat != null:
				mi.material_override = col_mat
				bound += 1
		else:
			if truss_mat != null:
				mi.material_override = truss_mat
				bound += 1
	var framing := arena.get_node_or_null("IndustrialPerimeterFraming") as Node3D
	if framing != null and truss_mat != null:
		for cw_name in ["Catwalk_West", "Catwalk_East"]:
			var cw := framing.get_node_or_null(cw_name) as MeshInstance3D
			if cw != null:
				cw.material_override = truss_mat
		var existing_br := framing.get_node_or_null("CatwalkGussetBrackets")
		if existing_br != null:
			framing.remove_child(existing_br)
			existing_br.free()
		var br_root := Node3D.new()
		br_root.name = "CatwalkGussetBrackets"
		var br_mesh := PropMeshes.cantilever_gusset_bracket()
		for side in [-1.0, 1.0]:
			for z_at in [-22.0, -14.0, -6.0, 2.0, 10.0, 18.0]:
				var br := MeshInstance3D.new()
				br.name = "Gusset_%s_%d" % ["W" if side < 0.0 else "E", int(z_at)]
				br.mesh = br_mesh
				br.position = Vector3(side * 28.4, 5.125, z_at)
				if side > 0.0:
					br.rotation_degrees = Vector3(0.0, 180.0, 0.0)
				br.material_override = col_mat if col_mat != null else truss_mat
				br.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				br_root.add_child(br)
				bound += 1
		framing.add_child(br_root)
	return bound


static func _get_gantry_column_material() -> ShaderMaterial:
	if _gantry_column_mat != null:
		_gantry_column_mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
		return _gantry_column_mat
	var base := Lookdev.preset_material("oil_slicked_iron")
	if base == null:
		return null
	var mat := base.duplicate(false) as ShaderMaterial
	mat.resource_name = "gantry_column_iron"
	mat.set_shader_parameter("use_vertex_masks", true)
	mat.set_shader_parameter("foot_grime_height", 5.2)
	mat.set_shader_parameter("foot_grime_strength", 0.32)
	mat.set_shader_parameter("grime_strength", 0.58)
	mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
	_gantry_column_mat = mat
	return _gantry_column_mat


static func _get_gantry_truss_material() -> ShaderMaterial:
	if _gantry_truss_mat != null:
		_gantry_truss_mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
		return _gantry_truss_mat
	var base := Lookdev.preset_material("oil_slicked_iron")
	if base == null:
		return null
	var mat := base.duplicate(false) as ShaderMaterial
	mat.resource_name = "gantry_truss_iron"
	mat.set_shader_parameter("use_vertex_masks", false)
	mat.set_shader_parameter("foot_grime_height", 0.0)
	mat.set_shader_parameter("foot_grime_strength", 0.0)
	mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
	_gantry_truss_mat = mat
	return _gantry_truss_mat


static func reset_for_tests() -> void:
	_copper_coil_mat = null
	_vista_masonry_mat = null
	_vista_stack_mat = null
	_gantry_column_mat = null
	_gantry_truss_mat = null
	Lookdev.reset_for_tests()
