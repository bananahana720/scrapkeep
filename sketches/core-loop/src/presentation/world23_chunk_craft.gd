@tool
class_name World23ChunkCraft
extends Node3D

const HeroSculptor := preload("res://src/presentation/craft/hero_kitbash_sculptor.gd")
const Lookdev := preload("res://src/presentation/craft/craft_lookdev.gd")
const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const DETAIL_TEX_PATH := "res://assets/textures/craft/oxidized_iron_detail.png"


class LegacyMaterialArrayMesh extends ArrayMesh:
	var material: Material = null


const COMPACTOR_CANYON_SPECS := {
	"Tier0_CanyonFloor/CanyonDeck/Mesh": "dig_canyon_floor",
	"Tier0_CanyonFloor/CrusherChannelLip": "dig_crusher_lip",
	"Tier0_CanyonFloor/CanyonWallNorth/Mesh": "dig_wall_ns",
	"Tier0_CanyonFloor/CanyonWallSouth/Mesh": "dig_wall_ns",
	"Tier0_CanyonFloor/CanyonWallWest/Mesh": "dig_wall_ew",
	"Tier0_CanyonFloor/CanyonWallEast/Mesh": "dig_wall_ew",
	"Tier0_CanyonFloor/VentPadSW": "dig_jump_pad",
	"Tier0_CanyonFloor/VentPadNE": "dig_jump_pad",
	"Tier0_CanyonFloor/PressHousingWest/Mesh": "dig_press_housing",
	"Tier0_CanyonFloor/PressHousingEast/Mesh": "dig_press_housing",
	"Tier0_CanyonFloor/CoolantManifold/Mesh": "dig_coolant_tank",
	"Tier1_QuarryCatwalks/CatwalkNorth/Mesh": "dig_catwalk_ns",
	"Tier1_QuarryCatwalks/CatwalkSouth/Mesh": "dig_catwalk_ns",
	"Tier1_QuarryCatwalks/CatwalkWest/Mesh": "dig_catwalk_ew",
	"Tier1_QuarryCatwalks/CatwalkEast/Mesh": "dig_catwalk_ew",
	"Tier1_QuarryCatwalks/BlastShieldWest/Mesh": "dig_blast_shield",
	"Tier1_QuarryCatwalks/BlastShieldEast/Mesh": "dig_blast_shield",
	"Tier1_QuarryCatwalks/CatwalkPierNW": "dig_catwalk_pier",
	"Tier1_QuarryCatwalks/CatwalkPierNE": "dig_catwalk_pier",
	"Tier1_QuarryCatwalks/CatwalkPierSW": "dig_catwalk_pier",
	"Tier1_QuarryCatwalks/CatwalkPierSE": "dig_catwalk_pier",
	"Tier2_HydraulicGantry/PressBridge/Mesh": "dig_gantry_bridge",
	"Tier2_HydraulicGantry/OverheadHoistRail": "dig_hoist_rail",
	"Tier2_HydraulicGantry/BridgeStanchionWest": "dig_bridge_stanchion",
	"Tier2_HydraulicGantry/BridgeStanchionEast": "dig_bridge_stanchion",
	"Tier2_HydraulicGantry/CranePortalWest": "dig_crane_portal",
	"Tier2_HydraulicGantry/CranePortalEast": "dig_crane_portal",
	"SightlineLandmark/BoreDerrickBody/DerrickMesh": "dig_bore_derrick",
	"SightlineLandmark/DerrickBeacon": "dig_derrick_beacon",
}

const ORBITAL_GRAVEYARD_SPECS := {
	"Tier0_HullDeck/MainHullDeck/Mesh": "orbital_hull_floor",
	"Tier0_HullDeck/RelayWellCollar": "orbital_relay_collar",
	"Tier0_HullDeck/CoamingNorth/Mesh": "orbital_coaming_ns",
	"Tier0_HullDeck/CoamingSouth/Mesh": "orbital_coaming_ns",
	"Tier0_HullDeck/CoamingWest/Mesh": "orbital_coaming_ew",
	"Tier0_HullDeck/CoamingEast/Mesh": "orbital_coaming_ew",
	"Tier0_HullDeck/HullRibArchWest": "orbital_rib_arch",
	"Tier0_HullDeck/HullRibArchEast": "orbital_rib_arch",
	"Tier0_HullDeck/UpdraftPadSW": "orbital_jump_pad",
	"Tier0_HullDeck/UpdraftPadNE": "orbital_jump_pad",
	"Tier0_HullDeck/BulkheadBayWest/Mesh": "orbital_bulkhead_bay",
	"Tier0_HullDeck/BulkheadBayEast/Mesh": "orbital_bulkhead_bay",
	"Tier0_HullDeck/CryoCapacitorPod/Mesh": "orbital_cryo_pod",
	"Tier1_SalvageDecks/DeckNorth/Mesh": "orbital_catwalk_ns",
	"Tier1_SalvageDecks/DeckSouth/Mesh": "orbital_catwalk_ns",
	"Tier1_SalvageDecks/DeckWest/Mesh": "orbital_catwalk_ew",
	"Tier1_SalvageDecks/DeckEast/Mesh": "orbital_catwalk_ew",
	"Tier1_SalvageDecks/ShieldFinWest/Mesh": "orbital_shield_fin",
	"Tier1_SalvageDecks/ShieldFinEast/Mesh": "orbital_shield_fin",
	"Tier1_SalvageDecks/DeckPierNW": "orbital_catwalk_pier",
	"Tier1_SalvageDecks/DeckPierNE": "orbital_catwalk_pier",
	"Tier1_SalvageDecks/DeckPierSW": "orbital_catwalk_pier",
	"Tier1_SalvageDecks/DeckPierSE": "orbital_catwalk_pier",
	"Tier2_ChoirCrane/CraneWalkway/Mesh": "orbital_gantry_bridge",
	"Tier2_ChoirCrane/ChoirSpanBeam": "orbital_crane_beam",
	"Tier2_ChoirCrane/BridgeStanchionWest": "orbital_bridge_stanchion",
	"Tier2_ChoirCrane/BridgeStanchionEast": "orbital_bridge_stanchion",
	"Tier2_ChoirCrane/CranePortalWest": "orbital_crane_portal",
	"Tier2_ChoirCrane/CranePortalEast": "orbital_crane_portal",
	"SightlineLandmark/ChoirMastBody/MastMesh": "orbital_choir_mast",
	"SightlineLandmark/ZenithCrown": "orbital_zenith_crown",
}

const COMPACTOR_WALKABLE_PATHS := [
	"Tier0_CanyonFloor/CanyonDeck/Mesh",
	"Tier1_QuarryCatwalks/CatwalkNorth/Mesh",
	"Tier1_QuarryCatwalks/CatwalkSouth/Mesh",
	"Tier1_QuarryCatwalks/CatwalkWest/Mesh",
	"Tier1_QuarryCatwalks/CatwalkEast/Mesh",
	"Tier2_HydraulicGantry/PressBridge/Mesh",
]

const ORBITAL_WALKABLE_PATHS := [
	"Tier0_HullDeck/MainHullDeck/Mesh",
	"Tier1_SalvageDecks/DeckNorth/Mesh",
	"Tier1_SalvageDecks/DeckSouth/Mesh",
	"Tier1_SalvageDecks/DeckWest/Mesh",
	"Tier1_SalvageDecks/DeckEast/Mesh",
	"Tier2_ChoirCrane/CraneWalkway/Mesh",
]

static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}
static var _cloud_shader: Shader = null
static var _bolt_shader: Shader = null
static var _wake_shader: Shader = null
static var _aura_shader: Shader = null
static var _micro_normal_tex: ImageTexture = null
static var _detail_tex: Texture2D = null

var _dressed := false


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED and not _dressed:
		_dressed = true
		dress_chunk(self)


func _ready() -> void:
	if not _dressed:
		_dressed = true
		dress_chunk(self)


static func _reset() -> void:
	reset_for_tests()


static func reset_for_tests() -> void:
	_mesh_cache.clear()
	_mat_cache.clear()
	_cloud_shader = null
	_bolt_shader = null
	_wake_shader = null
	_aura_shader = null
	_micro_normal_tex = null
	_detail_tex = null


static func warm_shaders() -> void:
	for slot in [
		"orbital_verdigris", "orbital_mast_steel", "orbital_charcoal",
		"orbital_copper", "orbital_brass", "orbital_ancient_glow",
		"orbital_ice_arc", "orbital_kindness_plate", "orbital_hazard_glow",
		"orbital_hull_deck", "dig_canyon_floor",
	]:
		get_material(slot)
	build_lightning_bolt_material()
	build_slipstream_wake_material(Palette.ICE)
	build_electric_aura_material(Palette.ICE)


static func dress_chunk(chunk_root: Node) -> int:
	if chunk_root == null or not is_instance_valid(chunk_root):
		return 0
	var chunk_id := String(chunk_root.get_meta("chunk_id", ""))
	var specs: Dictionary = {}
	if chunk_id == "compactor_canyon_v1":
		specs = COMPACTOR_CANYON_SPECS
	elif chunk_id == "orbital_graveyard_v1":
		specs = ORBITAL_GRAVEYARD_SPECS
	else:
		return 0
	var count := 0
	for rel_path: String in specs.keys():
		var mi := chunk_root.get_node_or_null(rel_path) as MeshInstance3D
		if mi == null:
			continue
		var kind := String(specs[rel_path])
		var mesh := get_chunk_mesh(kind)
		if mesh == null:
			continue
		mi.mesh = mesh
		mi.material_override = null
		bind_surface_materials(mi)
		count += 1
	return count


static func bind_surface_materials(mi: MeshInstance3D) -> int:
	if mi == null or mi.mesh == null or not (mi.mesh is ArrayMesh):
		return 0
	var am := mi.mesh as ArrayMesh
	var count := am.get_surface_count()
	var bound := 0
	mi.material_override = null
	for i in count:
		var slot := am.surface_get_name(i)
		var mat := get_material(slot)
		if mat != null:
			mi.set_surface_override_material(i, mat)
			bound += 1
	return bound


static func apply_surface_materials_to_mesh(am: ArrayMesh) -> void:
	if am == null:
		return
	for i in am.get_surface_count():
		var slot := am.surface_get_name(i)
		var mat := get_material(slot)
		if mat != null:
			am.surface_set_material(i, mat)


static func detail_texture() -> Texture2D:
	if _detail_tex != null:
		return _detail_tex
	if ResourceLoader.exists(DETAIL_TEX_PATH):
		_detail_tex = load(DETAIL_TEX_PATH) as Texture2D
	if _detail_tex == null:
		_detail_tex = Palette.painted_texture(256)
	return _detail_tex


static func micro_normal_texture() -> ImageTexture:
	if _micro_normal_tex != null:
		return _micro_normal_tex
	var sz := 128
	var noise := FastNoiseLite.new()
	noise.seed = 40731
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	var h := noise.get_seamless_image(sz, sz)
	var img := Image.create_empty(sz, sz, false, Image.FORMAT_RGB8)
	for y in sz:
		var ym := (y - 1 + sz) % sz
		var yp := (y + 1) % sz
		for x in sz:
			var xm := (x - 1 + sz) % sz
			var xp := (x + 1) % sz
			var dx := (h.get_pixel(xp, y).r - h.get_pixel(xm, y).r) * 2.2
			var dy := (h.get_pixel(x, yp).r - h.get_pixel(x, ym).r) * 2.2
			var n := Vector3(-dx, -dy, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	img.generate_mipmaps()
	_micro_normal_tex = ImageTexture.create_from_image(img)
	return _micro_normal_tex


static func make_weathered_pbr(
	albedo: Color,
	roughness: float = 0.72,
	metallic: float = 0.24,
	emit_color: Color = Color(0.0, 0.0, 0.0, 0.0),
	emit_energy: float = 0.0,
	triplanar_scale: float = 0.35,
	normal_scale: float = 0.42
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.albedo_texture = Palette.painted_texture(256)
	mat.roughness = roughness
	mat.roughness_texture = Palette.painted_texture(256)
	mat.metallic = metallic
	mat.normal_enabled = true
	mat.normal_texture = micro_normal_texture()
	mat.normal_scale = normal_scale
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * triplanar_scale
	if emit_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emit_color
		mat.emission_energy_multiplier = emit_energy
	return mat


static func enrich_standard_pbr(mat: StandardMaterial3D, normal_scale: float = 0.38, triplanar_scale: float = 0.22) -> StandardMaterial3D:
	if mat == null:
		return null
	if mat.albedo_texture == null:
		mat.albedo_texture = Palette.painted_texture(256)
	if mat.roughness_texture == null:
		mat.roughness_texture = Palette.painted_texture(256)
	mat.normal_enabled = true
	if mat.normal_texture == null:
		mat.normal_texture = micro_normal_texture()
	mat.normal_scale = normal_scale
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * triplanar_scale
	return mat


static func get_material(slot: String) -> Material:
	if slot == "hazard_stripe" or slot == "dig_hazard_stripe":
		return Palette.hazard_stripe()
	if _mat_cache.has(slot):
		var cached := _mat_cache[slot] as ShaderMaterial
		if cached != null and cached.shader != null and cached.shader.resource_path == Lookdev.MASTER_SHADER_PATH:
			cached.set_shader_parameter("reduce_flashes", FlashGuard.on)
		return cached

	var mat: ShaderMaterial = null
	match slot:
		"dig_canyon_floor":
			mat = _dup_preset("combat_floor_apron", "dig_canyon_floor")
			if mat != null:
				mat.set_shader_parameter("floor_albedo", Color(0.36, 0.28, 0.22, 1.0))
				mat.set_shader_parameter("floor_secondary_albedo", Color(0.30, 0.23, 0.18, 1.0))
				mat.set_shader_parameter("crack_albedo", Color(0.16, 0.12, 0.10, 1.0))
				mat.set_shader_parameter("slab_metres", 4.2)
				mat.set_shader_parameter("base_metallic", 0.06)
				mat.set_shader_parameter("oil_patch_strength", 0.38)
				mat.set_shader_parameter("value_clamp_min", 0.22)
				mat.set_shader_parameter("value_clamp_max", 0.44)
				mat.set_shader_parameter("saturation_cap", 0.22)
		"dig_catwalk_deck":
			mat = _dup_preset("combat_floor_apron", "dig_catwalk_deck")
			if mat != null:
				mat.set_shader_parameter("floor_albedo", Color(0.28, 0.26, 0.24, 1.0))
				mat.set_shader_parameter("floor_secondary_albedo", Color(0.23, 0.22, 0.21, 1.0))
				mat.set_shader_parameter("crack_albedo", Color(0.12, 0.11, 0.11, 1.0))
				mat.set_shader_parameter("slab_metres", 3.0)
				mat.set_shader_parameter("base_metallic", 0.18)
				mat.set_shader_parameter("oil_patch_strength", 0.52)
				mat.set_shader_parameter("value_clamp_min", 0.20)
				mat.set_shader_parameter("value_clamp_max", 0.40)
				mat.set_shader_parameter("saturation_cap", 0.12)
		"dig_gantry_deck":
			mat = _dup_preset("combat_floor_apron", "dig_gantry_deck")
			if mat != null:
				mat.set_shader_parameter("floor_albedo", Color(0.38, 0.34, 0.29, 1.0))
				mat.set_shader_parameter("floor_secondary_albedo", Color(0.32, 0.28, 0.24, 1.0))
				mat.set_shader_parameter("crack_albedo", Color(0.16, 0.14, 0.12, 1.0))
				mat.set_shader_parameter("slab_metres", 2.8)
				mat.set_shader_parameter("base_metallic", 0.16)
				mat.set_shader_parameter("value_clamp_min", 0.24)
				mat.set_shader_parameter("value_clamp_max", 0.44)
				mat.set_shader_parameter("saturation_cap", 0.16)
		"dig_redrock_wall":
			mat = _dup_preset("scorched_concrete", "dig_redrock_wall")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Color(0.49, 0.29, 0.19, 1.0))
				mat.set_shader_parameter("secondary_albedo", Color(0.37, 0.21, 0.15, 1.0))
				mat.set_shader_parameter("edge_wear_albedo", Color(0.68, 0.52, 0.36, 1.0))
				mat.set_shader_parameter("edge_wear_strength", 0.55)
				mat.set_shader_parameter("base_roughness", 0.90)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"dig_hydraulic_hull":
			mat = _dup_preset("oxidized_hull_plating", "dig_hydraulic_hull")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Color(0.56, 0.35, 0.20, 1.0))
				mat.set_shader_parameter("secondary_albedo", Color(0.42, 0.26, 0.16, 1.0))
				mat.set_shader_parameter("base_metallic", 0.28)
				mat.set_shader_parameter("base_roughness", 0.72)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"dig_bore_steel":
			mat = _dup_preset("oil_slicked_iron", "dig_bore_steel")
			if mat != null:
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"dig_copper_ram":
			mat = _dup_preset("oxidized_hull_plating", "dig_copper_ram")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Palette.COPPER)
				mat.set_shader_parameter("secondary_albedo", Palette.COPPER.darkened(0.26))
				mat.set_shader_parameter("base_metallic", 0.74)
				mat.set_shader_parameter("base_roughness", 0.36)
				mat.set_shader_parameter("edge_wear_albedo", Color("e4be8b"))
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"dig_amber_beacon":
			mat = _dup_preset("plasma_conduit_core", "dig_amber_beacon")
			if mat != null:
				mat.set_shader_parameter("emissive_color", Palette.SODIUM)
				mat.set_shader_parameter("emissive_secondary_color", Palette.AMBER)
				mat.set_shader_parameter("emissive_energy", 4.4)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"orbital_hull_deck":
			mat = _dup_preset("combat_floor_apron", "orbital_hull_deck")
			if mat != null:
				mat.set_shader_parameter("floor_albedo", Color(0.32, 0.35, 0.36, 1.0))
				mat.set_shader_parameter("floor_secondary_albedo", Color(0.26, 0.30, 0.31, 1.0))
				mat.set_shader_parameter("crack_albedo", Color(0.14, 0.17, 0.18, 1.0))
				mat.set_shader_parameter("slab_metres", 4.0)
				mat.set_shader_parameter("base_metallic", 0.18)
				mat.set_shader_parameter("oil_patch_strength", 0.34)
				mat.set_shader_parameter("value_clamp_min", 0.24)
				mat.set_shader_parameter("value_clamp_max", 0.44)
				mat.set_shader_parameter("saturation_cap", 0.14)
		"orbital_catwalk_deck":
			mat = _dup_preset("combat_floor_apron", "orbital_catwalk_deck")
			if mat != null:
				mat.set_shader_parameter("floor_albedo", Color(0.27, 0.34, 0.34, 1.0))
				mat.set_shader_parameter("floor_secondary_albedo", Color(0.22, 0.29, 0.29, 1.0))
				mat.set_shader_parameter("crack_albedo", Color(0.12, 0.16, 0.16, 1.0))
				mat.set_shader_parameter("slab_metres", 3.0)
				mat.set_shader_parameter("base_metallic", 0.22)
				mat.set_shader_parameter("value_clamp_min", 0.22)
				mat.set_shader_parameter("value_clamp_max", 0.42)
				mat.set_shader_parameter("saturation_cap", 0.14)
		"orbital_gantry_deck":
			mat = _dup_preset("combat_floor_apron", "orbital_gantry_deck")
			if mat != null:
				mat.set_shader_parameter("floor_albedo", Color(0.41, 0.41, 0.37, 1.0))
				mat.set_shader_parameter("floor_secondary_albedo", Color(0.35, 0.35, 0.32, 1.0))
				mat.set_shader_parameter("crack_albedo", Color(0.18, 0.18, 0.17, 1.0))
				mat.set_shader_parameter("slab_metres", 2.8)
				mat.set_shader_parameter("base_metallic", 0.20)
				mat.set_shader_parameter("value_clamp_min", 0.26)
				mat.set_shader_parameter("value_clamp_max", 0.46)
				mat.set_shader_parameter("saturation_cap", 0.12)
		"orbital_rib_hull":
			mat = _dup_preset("oxidized_hull_plating", "orbital_rib_hull")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Color(0.56, 0.54, 0.47, 1.0))
				mat.set_shader_parameter("secondary_albedo", Color(0.44, 0.43, 0.38, 1.0))
				mat.set_shader_parameter("base_metallic", 0.36)
				mat.set_shader_parameter("base_roughness", 0.62)
				mat.set_shader_parameter("edge_wear_albedo", Color(0.76, 0.74, 0.68, 1.0))
				mat.set_shader_parameter("edge_wear_strength", 0.68)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"orbital_verdigris":
			mat = _dup_preset("oxidized_hull_plating", "orbital_verdigris")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Palette.OLD_VERDIGRIS)
				mat.set_shader_parameter("secondary_albedo", Palette.VERDIGRIS)
				mat.set_shader_parameter("base_metallic", 0.34)
				mat.set_shader_parameter("base_roughness", 0.62)
				mat.set_shader_parameter("edge_wear_albedo", Color(0.68, 0.76, 0.72, 1.0))
				mat.set_shader_parameter("edge_wear_strength", 0.65)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"orbital_mast_steel":
			mat = _dup_preset("oil_slicked_iron", "orbital_mast_steel")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Color(0.54, 0.54, 0.48, 1.0))
				mat.set_shader_parameter("secondary_albedo", Color(0.42, 0.43, 0.39, 1.0))
				mat.set_shader_parameter("base_metallic", 0.50)
				mat.set_shader_parameter("base_roughness", 0.50)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"orbital_charcoal":
			mat = _dup_preset("oil_slicked_iron", "orbital_charcoal")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Palette.CHARCOAL.lightened(0.06))
				mat.set_shader_parameter("secondary_albedo", Palette.CHARCOAL)
				mat.set_shader_parameter("base_metallic", 0.42)
				mat.set_shader_parameter("base_roughness", 0.56)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"orbital_copper":
			mat = _dup_preset("oxidized_hull_plating", "orbital_copper")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Palette.COPPER)
				mat.set_shader_parameter("secondary_albedo", Palette.COPPER.darkened(0.24))
				mat.set_shader_parameter("base_metallic", 0.72)
				mat.set_shader_parameter("base_roughness", 0.38)
				mat.set_shader_parameter("edge_wear_albedo", Color("e4bc8a"))
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"orbital_brass":
			mat = _dup_preset("oxidized_hull_plating", "orbital_brass")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Palette.BRASS)
				mat.set_shader_parameter("secondary_albedo", Palette.BRASS.darkened(0.24))
				mat.set_shader_parameter("base_metallic", 0.68)
				mat.set_shader_parameter("base_roughness", 0.38)
				mat.set_shader_parameter("edge_wear_albedo", Color("f2dc9a"))
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"orbital_sand":
			mat = _dup_preset("scorched_concrete", "orbital_sand")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Palette.SAND)
				mat.set_shader_parameter("secondary_albedo", Palette.SANDSTONE)
				mat.set_shader_parameter("base_roughness", 0.86)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"orbital_ancient_glow":
			mat = _dup_preset("plasma_conduit_core", "orbital_ancient_glow")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Color(0.11, 0.18, 0.14, 1.0))
				mat.set_shader_parameter("secondary_albedo", Color(0.16, 0.25, 0.19, 1.0))
				mat.set_shader_parameter("emissive_color", Palette.ANCIENT)
				mat.set_shader_parameter("emissive_secondary_color", Color("6fd82c"))
				mat.set_shader_parameter("emissive_energy", 4.2)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"orbital_ice_arc":
			mat = _dup_preset("plasma_conduit_core", "orbital_ice_arc")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Color(0.24, 0.44, 0.48, 1.0))
				mat.set_shader_parameter("secondary_albedo", Color(0.18, 0.34, 0.39, 1.0))
				mat.set_shader_parameter("emissive_color", Palette.ICE)
				mat.set_shader_parameter("emissive_secondary_color", Palette.ARC)
				mat.set_shader_parameter("emissive_energy", 2.8)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"orbital_kindness_plate":
			mat = _dup_preset("plasma_conduit_core", "orbital_kindness_plate")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Palette.KINDNESS.darkened(0.22))
				mat.set_shader_parameter("secondary_albedo", Palette.KINDNESS.darkened(0.38))
				mat.set_shader_parameter("base_roughness", 0.28)
				mat.set_shader_parameter("base_metallic", 0.18)
				mat.set_shader_parameter("emissive_color", Palette.KINDNESS)
				mat.set_shader_parameter("emissive_secondary_color", Palette.KINDNESS.lightened(0.18))
				mat.set_shader_parameter("emissive_gradient_mix", 0.28)
				mat.set_shader_parameter("emissive_energy", 2.1)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"orbital_hazard_glow":
			mat = _dup_preset("plasma_conduit_core", "orbital_hazard_glow")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Color(0.24, 0.12, 0.10, 1.0))
				mat.set_shader_parameter("secondary_albedo", Color(0.18, 0.09, 0.08, 1.0))
				mat.set_shader_parameter("emissive_color", Palette.HAZARD)
				mat.set_shader_parameter("emissive_secondary_color", Palette.AMBER)
				mat.set_shader_parameter("emissive_energy", 3.2)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		_:
			mat = _dup_preset("oil_slicked_iron", "world23_default_iron")
			if mat != null:
				mat.set_shader_parameter("foot_grime_height", 0.0)

	if mat != null:
		if mat.shader != null and mat.shader.resource_path == Lookdev.MASTER_SHADER_PATH:
			mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
		_mat_cache[slot] = mat
	return mat


static func build_cloud_sea_material(base_tex: Texture2D, cloud_col: Color, fill_col: Color) -> ShaderMaterial:
	if _cloud_shader == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D cloud_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform vec3 cloud_tint : source_color = vec3(0.95, 0.91, 0.85);
uniform vec3 shadow_tint : source_color = vec3(0.58, 0.68, 0.78);
uniform vec3 horizon_tint : source_color = vec3(0.84, 0.87, 0.92);
uniform float tile_scale = 8.0;
uniform float fade_radius = 740.0;
uniform bool reduce_flashes = false;

varying vec3 cloud_world_pos;

float cloud_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float cloud_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(cloud_hash(i), cloud_hash(i + vec2(1.0, 0.0)), u.x),
		mix(cloud_hash(i + vec2(0.0, 1.0)), cloud_hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void vertex() {
	cloud_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float drift_speed = reduce_flashes ? 0.0 : 0.0028;
	vec2 uv_a = UV * tile_scale + vec2(TIME * drift_speed, TIME * drift_speed * 0.45);
	vec2 uv_b = UV * (tile_scale * 1.85) - vec2(TIME * drift_speed * 0.65, TIME * drift_speed * 0.30);
	vec3 tex_a = texture(cloud_tex, uv_a).rgb;
	vec3 tex_b = texture(cloud_tex, uv_b).rgb;
	float wisp = cloud_noise(cloud_world_pos.xz * 0.012 + vec2(TIME * drift_speed * 8.0, 0.0));
	float billow = clamp(dot(tex_a, vec3(0.333)) * 0.62 + dot(tex_b, vec3(0.333)) * 0.26 + wisp * 0.22, 0.0, 1.0);
	float ridge = smoothstep(0.28, 0.78, billow);
	vec3 col = mix(shadow_tint, cloud_tint, ridge);
	float dist_norm = clamp(length(cloud_world_pos.xz) / max(fade_radius, 100.0), 0.0, 1.0);
	float h_mix = smoothstep(0.45, 0.98, dist_norm);
	col = mix(col, horizon_tint, h_mix * 0.62);
	float bump_h = ridge * 0.06;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 n_soft = normalize(NORMAL - normalize(cross(dpdy, NORMAL)) * dFdx(bump_h) * 1.4 - normalize(cross(NORMAL, dpdx)) * dFdy(bump_h) * 1.4);
	ALBEDO = col;
	ROUGHNESS = mix(0.96, 0.84, ridge);
	METALLIC = 0.0;
	SPECULAR = 0.15;
	NORMAL = n_soft;
	EMISSION = col * (0.14 + ridge * 0.08);
}
"""
		_cloud_shader = sh
	var mat := ShaderMaterial.new()
	mat.resource_name = "highdraft_cloud_sea_shader"
	mat.shader = _cloud_shader
	if base_tex != null:
		mat.set_shader_parameter("cloud_tex", base_tex)
	mat.set_shader_parameter("cloud_tint", cloud_col)
	mat.set_shader_parameter("shadow_tint", cloud_col.lerp(fill_col, 0.58))
	mat.set_shader_parameter("horizon_tint", cloud_col.lerp(fill_col, 0.24))
	mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
	return mat


static func build_lightning_bolt_material() -> ShaderMaterial:
	if _bolt_shader == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec3 core_color : source_color = vec3(0.95, 0.98, 1.0);
uniform vec3 arc_color : source_color = vec3(0.55, 0.94, 0.85);
uniform float fade_alpha = 1.0;
uniform float energy = 3.2;

void fragment() {
	float pulse = 0.86 + 0.14 * sin(TIME * 28.0 + UV.y * 18.0);
	float edge = clamp(1.0 - abs(UV.x * 2.0 - 1.0), 0.0, 1.0);
	vec3 col = mix(arc_color, core_color, smoothstep(0.15, 0.85, edge));
	ALBEDO = col * energy * pulse;
	ALPHA = clamp(fade_alpha * (0.55 + 0.45 * edge), 0.0, 1.0);
}
"""
		_bolt_shader = sh
	var mat := ShaderMaterial.new()
	mat.resource_name = "highdraft_lightning_bolt_shader"
	mat.shader = _bolt_shader
	mat.set_shader_parameter("fade_alpha", 1.0)
	return mat


static func build_slipstream_wake_material(tint: Color) -> ShaderMaterial:
	if _wake_shader == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 wake_color : source_color = vec4(0.78, 0.94, 1.0, 0.34);
uniform bool reduce_flashes = false;

void fragment() {
	float spd = reduce_flashes ? 0.4 : 2.6;
	float streak = 0.55 + 0.45 * sin((UV.y * 12.0 - TIME * spd) * 3.14159);
	float edge = clamp(1.0 - abs(UV.x * 2.0 - 1.0), 0.0, 1.0);
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.2);
	ALBEDO = wake_color.rgb * (0.95 + 0.35 * streak);
	ALPHA = clamp(wake_color.a * (0.45 + 0.55 * streak) * (0.35 + 0.65 * edge + fresnel * 0.25), 0.0, 0.85);
}
"""
		_wake_shader = sh
	var mat := ShaderMaterial.new()
	mat.resource_name = "kite_slipstream_wake_shader"
	mat.shader = _wake_shader
	mat.set_shader_parameter("wake_color", Color(tint.r, tint.g, tint.b, tint.a if tint.a < 0.99 else 0.34))
	mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
	return mat


static func build_electric_aura_material(tint: Color) -> ShaderMaterial:
	if _aura_shader == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 arc_color : source_color = vec3(0.78, 0.94, 1.0);
uniform vec3 body_color : source_color = vec3(0.18, 0.32, 0.36);
uniform float emissive_energy = 2.4;
uniform bool reduce_flashes = false;

void fragment() {
	float spd = reduce_flashes ? 1.2 : 7.5;
	float wave = 0.68 + 0.32 * sin(UV.x * 25.13 + TIME * spd);
	ALBEDO = body_color;
	ROUGHNESS = 0.34;
	METALLIC = 0.58;
	EMISSION = arc_color * emissive_energy * wave;
}
"""
		_aura_shader = sh
	var mat := ShaderMaterial.new()
	mat.resource_name = "gap_net_electric_aura_shader"
	mat.shader = _aura_shader
	mat.set_shader_parameter("arc_color", tint)
	mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
	return mat


static func _dup_preset(preset_id: String, res_name: String) -> ShaderMaterial:
	var base := Lookdev.preset_material(preset_id)
	if base == null:
		return null
	var copy := base.duplicate(false) as ShaderMaterial
	copy.resource_name = res_name
	return copy


static func _new_canvas() -> HeroSculptor.KitbashCanvas:
	var canvas := HeroSculptor.create_canvas()
	canvas.ground_foot_grime = false
	return canvas


static func _add_flat_deck_slab(
	canvas: HeroSculptor.KitbashCanvas,
	slot: String,
	size: Vector3,
	edge_grime: float = 0.40,
	center_grime: float = 0.04,
	edge_wear: float = 0.10,
	offset: Vector3 = Vector3.ZERO
) -> void:
	var hx := maxf(size.x * 0.5, 0.05)
	var hy := maxf(size.y * 0.5, 0.01)
	var hz := maxf(size.z * 0.5, 0.05)
	var ix := maxf(hx - minf(hx * 0.18, 2.8), hx * 0.55)
	var iz := maxf(hz - minf(hz * 0.18, 2.8), hz * 0.55)
	var xs := [-hx, -ix, ix, hx]
	var zs := [-hz, -iz, iz, hz]
	var top_y := offset.y + hy
	var bot_y := offset.y - hy

	var top_pts: Array = []
	var top_cols: Array = []
	for gz in 4:
		var row_p: Array[Vector3] = []
		var row_c: Array[Color] = []
		for gx in 4:
			row_p.append(Vector3(offset.x + xs[gx], top_y, offset.z + zs[gz]))
			var is_outer := (gx == 0 or gx == 3 or gz == 0 or gz == 3)
			row_c.append(Lookdev.encode_mask(edge_wear if is_outer else 0.04, edge_grime if is_outer else center_grime, 0.0))
		top_pts.append(row_p)
		top_cols.append(row_c)

	for gz in 3:
		for gx in 3:
			canvas.add_quad(
				slot,
				top_pts[gz][gx], top_pts[gz][gx + 1], top_pts[gz + 1][gx + 1], top_pts[gz + 1][gx],
				Vector3.UP,
				top_cols[gz][gx], top_cols[gz][gx + 1], top_cols[gz + 1][gx + 1], top_cols[gz + 1][gx],
				Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP
			)

	var bot_pts: Array = []
	var c_bot := Lookdev.encode_mask(0.08, maxf(edge_grime, 0.56), 0.0)
	for gz in 4:
		var brow: Array[Vector3] = []
		for gx in 4:
			brow.append(Vector3(offset.x + xs[gx], bot_y, offset.z + zs[gz]))
		bot_pts.append(brow)

	for gz in 3:
		for gx in 3:
			canvas.add_quad(
				slot,
				bot_pts[gz][gx + 1], bot_pts[gz][gx], bot_pts[gz + 1][gx], bot_pts[gz + 1][gx + 1],
				Vector3.DOWN, c_bot, c_bot, c_bot, c_bot,
				Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN
			)

	var c_side_top := Lookdev.encode_mask(maxf(edge_wear, 0.36), edge_grime, 0.0)
	for gx in 3:
		canvas.add_quad(
			slot,
			top_pts[0][gx + 1], top_pts[0][gx], bot_pts[0][gx], bot_pts[0][gx + 1],
			Vector3.FORWARD, c_side_top, c_side_top, c_bot, c_bot,
			Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD
		)
		canvas.add_quad(
			slot,
			top_pts[3][gx], top_pts[3][gx + 1], bot_pts[3][gx + 1], bot_pts[3][gx],
			Vector3.BACK, c_side_top, c_side_top, c_bot, c_bot,
			Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK
		)
	for gz in 3:
		canvas.add_quad(
			slot,
			top_pts[gz][0], top_pts[gz + 1][0], bot_pts[gz + 1][0], bot_pts[gz][0],
			Vector3.LEFT, c_side_top, c_side_top, c_bot, c_bot,
			Vector3.LEFT, Vector3.LEFT, Vector3.LEFT, Vector3.LEFT
		)
		canvas.add_quad(
			slot,
			top_pts[gz + 1][3], top_pts[gz][3], bot_pts[gz][3], bot_pts[gz + 1][3],
			Vector3.RIGHT, c_side_top, c_side_top, c_bot, c_bot,
			Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT
		)


static func _add_beveled_annulus(
	canvas: HeroSculptor.KitbashCanvas,
	slot: String,
	xform: Transform3D,
	sides: int,
	r_in: float,
	r_out_top: float,
	r_out_bot: float,
	height: float,
	base_wear: float = 0.14,
	base_grime: float = 0.34,
	emissive: float = 0.0,
	edge_wear: float = 0.82
) -> void:
	var n := maxi(sides, 6)
	var hy := height * 0.5
	var bev_y := minf(height * 0.24, 0.08)
	var r_in_top := r_in + minf((r_out_top - r_in) * 0.12, 0.10)
	var flat_inset := minf((r_out_top - r_in_top) * 0.14, 0.12)
	var r_in_flat := r_in_top + flat_inset
	var r_out_flat := r_out_top - flat_inset
	var profile: Array[Vector2] = []
	var pcols: Array[Color] = []
	var c_crest := Lookdev.encode_mask(edge_wear if emissive < 0.5 else 0.3, minf(base_grime, 0.22), emissive)
	var c_flat := Lookdev.encode_mask(base_wear, base_grime, emissive)
	profile.append(Vector2(r_in, -hy))
	pcols.append(Lookdev.encode_mask(base_wear, maxf(base_grime, 0.72), emissive))
	profile.append(Vector2(r_in, hy - bev_y))
	pcols.append(Lookdev.encode_mask(base_wear, base_grime, emissive))
	profile.append(Vector2(r_in_top, hy))
	pcols.append(c_crest)
	if r_out_flat > r_in_flat + 0.02:
		profile.append(Vector2(r_in_flat, hy))
		pcols.append(c_flat)
		profile.append(Vector2(r_out_flat, hy))
		pcols.append(c_flat)
	profile.append(Vector2(r_out_top, hy))
	pcols.append(c_crest)
	profile.append(Vector2(r_out_bot, -hy + bev_y))
	pcols.append(Lookdev.encode_mask(base_wear, maxf(base_grime, 0.52), emissive))
	profile.append(Vector2(r_out_bot, -hy))
	pcols.append(Lookdev.encode_mask(base_wear, maxf(base_grime, 0.76), emissive))
	var pcount := profile.size()
	var rings: Array = []
	for pi in pcount:
		var row: Array[Vector3] = []
		var rp: Vector2 = profile[pi]
		for si in n:
			var ang := TAU * float(si) / float(n)
			row.append(xform * Vector3(cos(ang) * rp.x, rp.y, sin(ang) * rp.x))
		rings.append(row)

	for si in n:
		var nsi := (si + 1) % n
		var mid_ang := TAU * (float(si) + 0.5) / float(n)
		var rad := Vector3(cos(mid_ang), 0.0, sin(mid_ang))
		for pi in pcount:
			var npi := (pi + 1) % pcount
			var d2: Vector2 = profile[npi] - profile[pi]
			var out2 := Vector2(-d2.y, d2.x).normalized()
			var local_n := Vector3(rad.x * out2.x, out2.y, rad.z * out2.x)
			var world_n := (xform.basis * local_n).normalized()
			canvas.add_quad(
				slot,
				rings[pi][si], rings[pi][nsi], rings[npi][nsi], rings[npi][si],
				world_n, pcols[pi], pcols[pi], pcols[npi], pcols[npi]
			)


static func _add_closed_torus(
	canvas: HeroSculptor.KitbashCanvas,
	slot: String,
	xform: Transform3D,
	major_r: float,
	minor_r: float,
	segs: int = 24,
	sides: int = 8,
	wear: float = 0.28,
	grime: float = 0.24,
	emissive: float = 0.0
) -> void:
	var n_seg := maxi(segs, 8)
	var n_side := maxi(sides, 5)
	var rings: Array = []
	var centers: Array[Vector3] = []
	for i in n_seg:
		var ang := TAU * float(i) / float(n_seg)
		var radial := Vector3(cos(ang), 0.0, sin(ang))
		centers.append(xform * (radial * major_r))
		var row: Array[Vector3] = []
		for j in n_side:
			var phi := TAU * float(j) / float(n_side)
			var local_off := radial * (cos(phi) * minor_r) + Vector3(0.0, sin(phi) * minor_r, 0.0)
			row.append(xform * (radial * major_r + local_off))
		rings.append(row)
	var c_out := Lookdev.encode_mask(wear, grime, emissive)
	for i in n_seg:
		var ni := (i + 1) % n_seg
		for j in n_side:
			var nj := (j + 1) % n_side
			var p00: Vector3 = rings[i][j]
			var p01: Vector3 = rings[i][nj]
			var p11: Vector3 = rings[ni][nj]
			var p10: Vector3 = rings[ni][j]
			var out_n := ((p00 + p01 + p11 + p10) * 0.25 - (centers[i] + centers[ni]) * 0.5).normalized()
			canvas.add_quad(
				slot, p00, p01, p11, p10, out_n, c_out, c_out, c_out, c_out,
				(p00 - centers[i]).normalized(), (p01 - centers[i]).normalized(),
				(p11 - centers[ni]).normalized(), (p10 - centers[ni]).normalized()
			)


static func _add_faceted_orb(
	canvas: HeroSculptor.KitbashCanvas,
	slot: String,
	xform: Transform3D,
	radius: float,
	sides: int = 12,
	wear: float = 0.22,
	grime: float = 0.16,
	emissive: float = 0.0
) -> void:
	var r := maxf(radius, 0.02)
	var n := maxi(sides, 6)
	HeroSculptor.add_chamfered_prism(
		canvas, slot, xform,
		n, r, r, r * 1.16, r * 0.44, r * 0.44, wear, grime, emissive, 0.0, 0.45
	)


static func get_mind_hand_seam_mesh() -> ArrayMesh:
	var key := "w3:mind_hand_seam"
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_plate(
		canvas, "orbital_charcoal", Transform3D.IDENTITY,
		Vector3(0.42, 0.08, 0.42), 0.018, 0.20, 0.46, 0.0, 0.86
	)
	var mesh := canvas.commit({"asset_kind": "mind_hand_seam"})
	apply_surface_materials_to_mesh(mesh)
	_mesh_cache[key] = mesh
	return mesh


static func get_mind_hand_crack_mesh() -> ArrayMesh:
	var key := "w3:mind_hand_crack"
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_plate(
		canvas, "orbital_ancient_glow", Transform3D.IDENTITY,
		Vector3(0.08, 0.72, 0.06), 0.012, 0.20, 0.14, 1.0, 0.50
	)
	var mesh := canvas.commit({"asset_kind": "mind_hand_crack"})
	apply_surface_materials_to_mesh(mesh)
	_mesh_cache[key] = mesh
	return mesh


static func _add_clean_louver(
	canvas: HeroSculptor.KitbashCanvas,
	frame_slot: String,
	xform: Transform3D,
	width: float,
	height: float,
	depth: float,
	slat_count: int = 4,
	emissive_slot: String = ""
) -> void:
	var fw := clampf(minf(width, height) * 0.12, 0.04, 0.14)
	var bev := minf(fw * 0.28, depth * 0.28)
	HeroSculptor.add_chamfered_plate(
		canvas, frame_slot,
		xform * Transform3D(Basis.IDENTITY, Vector3(0.0, (height - fw) * 0.5, 0.0)),
		Vector3(width, fw, depth), bev, 0.14, 0.22
	)
	HeroSculptor.add_chamfered_plate(
		canvas, frame_slot,
		xform * Transform3D(Basis.IDENTITY, Vector3(0.0, -(height - fw) * 0.5, 0.0)),
		Vector3(width, fw, depth), bev, 0.14, 0.34
	)
	var side_h := maxf(height - fw * 2.0 - 0.016, 0.04)
	HeroSculptor.add_chamfered_plate(
		canvas, frame_slot,
		xform * Transform3D(Basis.IDENTITY, Vector3(-(width - fw) * 0.5, 0.0, 0.006)),
		Vector3(fw, side_h, depth * 0.94), bev * 0.85, 0.14, 0.24
	)
	HeroSculptor.add_chamfered_plate(
		canvas, frame_slot,
		xform * Transform3D(Basis.IDENTITY, Vector3((width - fw) * 0.5, 0.0, 0.006)),
		Vector3(fw, side_h, depth * 0.94), bev * 0.85, 0.14, 0.24
	)
	var inner_w := maxf(width - fw * 2.15, 0.06)
	var back_slot := emissive_slot if emissive_slot != "" else frame_slot
	var emit := 1.0 if emissive_slot != "" else 0.0
	HeroSculptor.add_chamfered_plate(
		canvas, back_slot,
		xform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -depth * 0.26)),
		Vector3(inner_w, side_h * 0.92, depth * 0.38), minf(bev * 0.5, 0.02),
		0.10, 0.86 if emit < 0.5 else 0.08, emit, 0.30
	)
	var count := maxi(slat_count, 2)
	var step := side_h / float(count)
	var slat_t := clampf(step * 0.30, 0.02, 0.07)
	for i in count:
		var y := -side_h * 0.5 + (float(i) + 0.5) * step
		var sxf := xform * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(28.0)), Vector3(0.0, y, depth * 0.10))
		HeroSculptor.add_chamfered_plate(
			canvas, frame_slot, sxf,
			Vector3(inner_w * 0.94, slat_t, depth * 0.72), minf(slat_t * 0.26, 0.016),
			0.16, 0.68, 0.0, 0.86
		)


static func get_quiet_gun_cradle_mesh() -> ArrayMesh:
	var key := "w3:quiet_gun_cradle"
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_prism(
		canvas, "orbital_charcoal", Transform3D.IDENTITY,
		16, 1.48, 1.38, 0.28, 0.05, 0.05, 0.14, 0.54, 0.0, 0.0, 0.82
	)
	_add_beveled_annulus(
		canvas, "orbital_verdigris", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.18, 0.0)),
		16, 0.98, 1.24, 1.32, 0.16, 0.18, 0.42, 0.0, 0.86
	)
	for side in [-1.0, 1.0]:
		HeroSculptor.add_chamfered_plate(
			canvas, "orbital_copper",
			Transform3D(Basis.IDENTITY, Vector3(side * 1.10, 0.16, 0.0)),
			Vector3(0.28, 0.30, 0.78), 0.04, 0.20, 0.36, 0.0, 0.88
		)
	var mesh := canvas.commit({"asset_kind": "quiet_gun_cradle"})
	apply_surface_materials_to_mesh(mesh)
	_mesh_cache[key] = mesh
	return mesh


static func get_quiet_gun_barrel_mesh() -> LegacyMaterialArrayMesh:
	var key := "w3:quiet_gun_barrel"
	if _mesh_cache.has(key):
		return _mesh_cache[key] as LegacyMaterialArrayMesh
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_prism(
		canvas, "barrel_body", Transform3D.IDENTITY,
		16, 1.14, 1.04, 3.0, 0.08, 0.08, 0.16, 0.44, 0.0, 0.0, 0.84
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "barrel_body", Transform3D(Basis.IDENTITY, Vector3(0.0, -1.24, 0.0)),
		16, 1.28, 1.22, 0.42, 0.06, 0.06, 0.18, 0.56, 0.0, 0.0, 0.88
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "barrel_body", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.32, 0.0)),
		16, 1.18, 1.12, 0.32, 0.05, 0.05, 0.22, 0.38, 0.0, 0.0, 0.90
	)
	for i in 6:
		var ang := TAU * float(i) / 6.0
		var b := Basis(Vector3.UP, -ang)
		var pos := Vector3(cos(ang) * 1.09, 0.0, sin(ang) * 1.09)
		HeroSculptor.add_chamfered_plate(
			canvas, "barrel_body", Transform3D(b, pos),
			Vector3(0.16, 2.24, 0.18), 0.03, 0.22, 0.48, 0.0, 0.86
		)
	var built := canvas.commit({"asset_kind": "quiet_gun_barrel"})
	var wrapped := LegacyMaterialArrayMesh.new()
	var mat := make_weathered_pbr(Palette.VERDIGRIS, 0.62, 0.34, Color.BLACK, 0.0, 0.42, 0.44)
	wrapped.material = mat
	for s in built.get_surface_count():
		wrapped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, built.surface_get_arrays(s))
		wrapped.surface_set_name(s, built.surface_get_name(s))
		wrapped.surface_set_material(s, mat)
	_mesh_cache[key] = wrapped
	return wrapped


static func get_quiet_gun_band_mesh(lit: bool, radius: float = 1.16) -> ArrayMesh:
	var key := "w3:quiet_gun_band:%s:%.2f" % [str(lit), radius]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	if not lit:
		_add_beveled_annulus(
			canvas, "band_cold", Transform3D.IDENTITY,
			20, radius - 0.10, radius + 0.02, radius + 0.03, 0.22, 0.16, 0.52, 0.0, 0.80
		)
		var cold_mesh := canvas.commit({"asset_kind": "quiet_gun_band_cold"})
		var cold_mat := make_weathered_pbr(Palette.CHARCOAL.lightened(0.08), 0.62, 0.40, Color.BLACK, 0.0, 0.5, 0.40)
		cold_mesh.surface_set_material(0, cold_mat)
		_mesh_cache[key] = cold_mesh
		return cold_mesh
	var dashes := 12
	var seg_arc := TAU / float(dashes)
	var arc_w := radius * seg_arc * 0.64
	for i in dashes:
		var ang := seg_arc * float(i)
		var b := Basis(Vector3.UP, -ang)
		var pos := Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
		HeroSculptor.add_chamfered_plate(
			canvas, "band_lit", Transform3D(b, pos),
			Vector3(0.14, 0.22, arc_w), 0.025, 0.26, 0.10, 1.0, 0.60
		)
	var lit_mesh := canvas.commit({"asset_kind": "quiet_gun_band_lit"})
	var lit_mat := make_weathered_pbr(Palette.ANCIENT, 0.36, 0.22, Palette.ANCIENT, 2.2, 0.65, 0.24)
	lit_mesh.surface_set_material(0, lit_mat)
	_mesh_cache[key] = lit_mesh
	return lit_mesh


static func get_quiet_gun_plug_mesh() -> ArrayMesh:
	var key := "w3:quiet_gun_plug"
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_prism(
		canvas, "orbital_brass", Transform3D.IDENTITY,
		16, 0.82, 0.72, 0.38, 0.05, 0.05, 0.20, 0.32, 0.0, 0.0, 0.88
	)
	HeroSculptor.add_chamfered_plate(
		canvas, "orbital_copper", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.26, 0.0)),
		Vector3(0.86, 0.14, 0.18), 0.03, 0.24, 0.28, 0.0, 0.90
	)
	var mesh := canvas.commit({"asset_kind": "quiet_gun_plug"})
	apply_surface_materials_to_mesh(mesh)
	_mesh_cache[key] = mesh
	return mesh


static func get_takeover_bezel_mesh() -> ArrayMesh:
	var key := "w3:takeover_bezel"
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_plate(
		canvas, "orbital_charcoal", Transform3D.IDENTITY,
		Vector3(4.36, 1.92, 0.20), 0.06, 0.14, 0.44, 0.0, 0.86
	)
	HeroSculptor.add_chamfered_plate(
		canvas, "orbital_verdigris", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.98, 0.12)),
		Vector3(4.24, 0.16, 0.34), 0.04, 0.18, 0.36, 0.0, 0.88
	)
	HeroSculptor.add_chamfered_plate(
		canvas, "orbital_verdigris", Transform3D(Basis.IDENTITY, Vector3(0.0, -0.96, 0.08)),
		Vector3(4.12, 0.16, 0.26), 0.04, 0.18, 0.46, 0.0, 0.84
	)
	for sx in [-1.0, 1.0]:
		HeroSculptor.add_chamfered_plate(
			canvas, "orbital_copper", Transform3D(Basis.IDENTITY, Vector3(sx * 2.18, 0.0, 0.04)),
			Vector3(0.22, 1.72, 0.26), 0.04, 0.20, 0.38, 0.0, 0.88
		)
		HeroSculptor.add_rivet_strip(
			canvas, "orbital_brass",
			Vector3(sx * 2.18, -0.68, 0.18), Vector3(sx * 2.18, 0.68, 0.18),
			Vector3.BACK, 4, 0.045, 0.035
		)
	var mesh := canvas.commit({"asset_kind": "takeover_bezel"})
	apply_surface_materials_to_mesh(mesh)
	_mesh_cache[key] = mesh
	return mesh


static func get_takeover_plate_mesh() -> ArrayMesh:
	var key := "w3:takeover_plate"
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_plate(
		canvas, "orbital_kindness_plate", Transform3D.IDENTITY,
		Vector3(3.86, 1.42, 0.14), 0.04, 0.14, 0.10, 1.0, 0.42
	)
	var mesh := canvas.commit({"asset_kind": "takeover_plate"})
	apply_surface_materials_to_mesh(mesh)
	_mesh_cache[key] = mesh
	return mesh


static func get_cloud_sea_mesh(span: float = 1600.0) -> ArrayMesh:
	var key := "w3:cloud_sea:%.0f" % span
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	var n := 16
	var half := span * 0.5
	var thickness := 6.0
	var top_grid: Array = []
	var bot_grid: Array = []
	var col := Lookdev.encode_mask(0.05, 0.05, 0.0)
	for gz in n + 1:
		var row_t: Array[Vector3] = []
		var row_b: Array[Vector3] = []
		var vz := lerpf(-half, half, float(gz) / float(n))
		for gx in n + 1:
			var vx := lerpf(-half, half, float(gx) / float(n))
			row_t.append(Vector3(vx, 0.0, vz))
			row_b.append(Vector3(vx, -thickness, vz))
		top_grid.append(row_t)
		bot_grid.append(row_b)
	for gz in n:
		for gx in n:
			canvas.add_quad(
				"cloud_sea",
				top_grid[gz][gx], top_grid[gz][gx + 1], top_grid[gz + 1][gx + 1], top_grid[gz + 1][gx],
				Vector3.UP, col, col, col, col, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP
			)
			canvas.add_quad(
				"cloud_sea",
				bot_grid[gz][gx + 1], bot_grid[gz][gx], bot_grid[gz + 1][gx], bot_grid[gz + 1][gx + 1],
				Vector3.DOWN, col, col, col, col, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN
			)
	for gx in n:
		canvas.add_quad("cloud_sea", top_grid[0][gx + 1], top_grid[0][gx], bot_grid[0][gx], bot_grid[0][gx + 1], Vector3.FORWARD, col, col, col, col)
		canvas.add_quad("cloud_sea", top_grid[n][gx], top_grid[n][gx + 1], bot_grid[n][gx + 1], bot_grid[n][gx], Vector3.BACK, col, col, col, col)
	for gz in n:
		canvas.add_quad("cloud_sea", top_grid[gz][0], top_grid[gz + 1][0], bot_grid[gz + 1][0], bot_grid[gz][0], Vector3.LEFT, col, col, col, col)
		canvas.add_quad("cloud_sea", top_grid[gz + 1][n], top_grid[gz][n], bot_grid[gz][n], bot_grid[gz + 1][n], Vector3.RIGHT, col, col, col, col)
	var mesh := canvas.commit({"asset_kind": "highdraft_cloud_sea"})
	_mesh_cache[key] = mesh
	return mesh


static func get_thermal_mote_mesh() -> ArrayMesh:
	var key := "w3:thermal_mote"
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_prism(
		canvas, "mote", Transform3D.IDENTITY,
		6, 0.08, 0.04, 0.24, 0.04, 0.04, 0.16, 0.10, 0.6, 0.0, 0.50
	)
	var mesh := canvas.commit({"asset_kind": "thermal_mote"})
	_mesh_cache[key] = mesh
	return mesh


static func get_mind_hand_foot_mesh() -> ArrayMesh:
	var key := "w3:mind_hand_foot"
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_prism(
		canvas, "orbital_charcoal", Transform3D.IDENTITY,
		12, 0.40, 0.34, 0.24, 0.04, 0.04, 0.18, 0.52, 0.0, 0.0, 0.84
	)
	_add_beveled_annulus(
		canvas, "orbital_copper", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0)),
		12, 0.22, 0.32, 0.36, 0.10, 0.20, 0.36, 0.0, 0.88
	)
	var mesh := canvas.commit({"asset_kind": "mind_hand_foot"})
	apply_surface_materials_to_mesh(mesh)
	_mesh_cache[key] = mesh
	return mesh


static func get_mind_hand_rod_mesh(top_r: float, bot_r: float, height: float) -> ArrayMesh:
	var key := "w3:mind_hand_rod:%.2f:%.2f:%.2f" % [top_r, bot_r, height]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_prism(
		canvas, "orbital_verdigris", Transform3D.IDENTITY,
		10, bot_r, top_r, height, 0.03, 0.03, 0.18, 0.42, 0.0, 0.0, 0.84
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "orbital_charcoal", Transform3D(Basis.IDENTITY, Vector3(0.0, -height * 0.36, 0.0)),
		10, bot_r * 1.18, bot_r * 1.12, height * 0.18, 0.02, 0.02, 0.20, 0.50, 0.0, 0.0, 0.86
	)
	var mesh := canvas.commit({"asset_kind": "mind_hand_rod"})
	apply_surface_materials_to_mesh(mesh)
	_mesh_cache[key] = mesh
	return mesh


static func get_mind_hand_lens_mesh(radius: float = 0.22) -> ArrayMesh:
	var key := "w3:mind_hand_lens:%.2f" % radius
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	_add_faceted_orb(canvas, "lens_core", Transform3D.IDENTITY, radius, 12, 0.18, 0.08, 1.0)
	var mesh := canvas.commit({"asset_kind": "mind_hand_lens"})
	_mesh_cache[key] = mesh
	return mesh


static func get_kite_chassis_mesh() -> ArrayMesh:
	var key := "w3:kite_chassis"
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_plate(
		canvas, "orbital_rib_hull", Transform3D.IDENTITY,
		Vector3(2.8, 0.18, 1.2), 0.04, 0.16, 0.34, 0.0, 0.86
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "orbital_charcoal", Transform3D(Basis.IDENTITY, Vector3(0.0, -0.34, 0.0)),
		10, 0.26, 0.34, 0.56, 0.04, 0.04, 0.18, 0.48, 0.0, 0.0, 0.86
	)
	for sx in [-1.0, 1.0]:
		HeroSculptor.add_chamfered_plate(
			canvas, "orbital_copper", Transform3D(Basis.IDENTITY, Vector3(sx * 1.32, 0.04, 0.0)),
			Vector3(0.24, 0.26, 1.04), 0.03, 0.22, 0.32, 0.0, 0.88
		)
	var mesh := canvas.commit({"asset_kind": "kite_chassis"})
	apply_surface_materials_to_mesh(mesh)
	_mesh_cache[key] = mesh
	return mesh


static func get_kite_wake_mesh(length: float = 1.0) -> ArrayMesh:
	var key := "w3:kite_wake:%.2f" % length
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_plate(
		canvas, "wake_fin", Transform3D.IDENTITY,
		Vector3(0.46, 0.06, maxf(length, 0.2)), 0.02, 0.18, 0.08, 0.6, 0.40
	)
	HeroSculptor.add_chamfered_plate(
		canvas, "wake_fin", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.10, 0.0)),
		Vector3(0.08, 0.18, maxf(length, 0.2) * 0.92), 0.02, 0.18, 0.08, 0.6, 0.40
	)
	var mesh := canvas.commit({"asset_kind": "kite_wake"})
	_mesh_cache[key] = mesh
	return mesh


static func get_gap_net_aura_mesh(radius: float = 0.88) -> ArrayMesh:
	var key := "w3:gap_net_aura:%.2f" % radius
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	_add_closed_torus(canvas, "aura_coil", Transform3D.IDENTITY, radius, 0.065, 24, 8, 0.24, 0.12, 1.0)
	for i in 4:
		var ang := TAU * float(i) / 4.0
		var b := Basis(Vector3.UP, -ang)
		var pos := Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
		HeroSculptor.add_chamfered_plate(
			canvas, "aura_coil", Transform3D(b, pos),
			Vector3(0.18, 0.18, 0.14), 0.03, 0.28, 0.18, 1.0, 0.72
		)
	var mesh := canvas.commit({"asset_kind": "gap_net_aura"})
	_mesh_cache[key] = mesh
	return mesh


static func get_gap_net_post_mesh(height: float = 3.2) -> ArrayMesh:
	var key := "w3:gap_net_post:%.2f" % height
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var h := maxf(height, 0.8)
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_prism(
		canvas, "orbital_charcoal", Transform3D.IDENTITY,
		10, 0.28, 0.22, h, 0.04, 0.04, 0.16, 0.48, 0.0, 0.0, 0.84
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "orbital_verdigris", Transform3D(Basis.IDENTITY, Vector3(0.0, -h * 0.44, 0.0)),
		10, 0.46, 0.36, 0.32, 0.04, 0.04, 0.18, 0.56, 0.0, 0.0, 0.86
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "orbital_copper", Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.42, 0.0)),
		10, 0.34, 0.30, 0.26, 0.04, 0.04, 0.22, 0.30, 0.0, 0.0, 0.90
	)
	var mesh := canvas.commit({"asset_kind": "gap_net_post"})
	apply_surface_materials_to_mesh(mesh)
	_mesh_cache[key] = mesh
	return mesh


static func get_gap_net_panel_mesh(width: float, height: float) -> ArrayMesh:
	var key := "w3:gap_net_panel:%.2f:%.2f" % [width, height]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_plate(
		canvas, "orbital_ice_arc", Transform3D.IDENTITY,
		Vector3(maxf(width, 0.4), maxf(height, 0.4), 0.10), 0.02, 0.14, 0.16, 0.85, 0.50
	)
	var mesh := canvas.commit({"asset_kind": "gap_net_panel"})
	apply_surface_materials_to_mesh(mesh)
	_mesh_cache[key] = mesh
	return mesh


static func get_gyro_jammer_chassis_mesh() -> ArrayMesh:
	var key := "w3:gyro_jammer_chassis"
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_prism(
		canvas, "orbital_charcoal", Transform3D.IDENTITY,
		10, 0.24, 0.14, 2.5, 0.04, 0.04, 0.18, 0.52, 0.0, 0.0, 0.84
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "orbital_verdigris", Transform3D(Basis.IDENTITY, Vector3(0.0, -1.10, 0.0)),
		10, 0.56, 0.42, 0.34, 0.05, 0.05, 0.18, 0.58, 0.0, 0.0, 0.86
	)
	var heights := [0.20, 0.72, 1.18]
	var radii := [0.84, 0.56, 0.34]
	for i in 3:
		_add_closed_torus(
			canvas, "orbital_hazard_glow",
			Transform3D(Basis.IDENTITY, Vector3(0.0, heights[i], 0.0)),
			radii[i], 0.065, 20, 6, 0.26, 0.18, 1.0
		)
	var mesh := canvas.commit({"asset_kind": "gyro_jammer_chassis"})
	apply_surface_materials_to_mesh(mesh)
	_mesh_cache[key] = mesh
	return mesh


static func get_deflector_vault_rim_mesh(radius: float = 1.60, tube: float = 0.09) -> ArrayMesh:
	var key := "w3:deflector_vault_rim:%.2f:%.3f" % [radius, tube]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := _new_canvas()
	_add_closed_torus(canvas, "vault_rim", Transform3D.IDENTITY, radius, tube, 24, 8, 0.26, 0.16, 1.0)
	for i in 6:
		var ang := TAU * float(i) / 6.0
		var b := Basis(Vector3.UP, -ang)
		var pos := Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
		HeroSculptor.add_chamfered_plate(
			canvas, "vault_rim", Transform3D(b, pos),
			Vector3(tube * 2.5, tube * 2.3, tube * 3.0), tube * 0.32, 0.26, 0.16, 1.0, 0.72
		)
	var mesh := canvas.commit({"asset_kind": "deflector_vault_rim"})
	_mesh_cache[key] = mesh
	return mesh


static func get_chunk_mesh(kind: String) -> ArrayMesh:
	var key := "w23chunk:" + kind
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var mesh: ArrayMesh = null
	match kind:
		"dig_canyon_floor":
			mesh = _build_flat_floor("dig_canyon_floor", Vector3(68.0, 1.0, 60.0))
		"dig_crusher_lip":
			mesh = _build_crusher_channel_lip(9.5, 11.2, 12.2, 0.42)
		"dig_wall_ns":
			mesh = _build_canyon_wall(Vector3(68.0, 4.0, 5.0), true)
		"dig_wall_ew":
			mesh = _build_canyon_wall(Vector3(5.0, 4.0, 60.0), false)
		"dig_jump_pad":
			mesh = _build_jump_pad("dig_bore_steel", "dig_copper_ram", "dig_amber_beacon", Vector3(5.0, 0.5, 5.0))
		"dig_press_housing":
			mesh = _build_press_housing(Vector3(3.4, 4.8, 8.2))
		"dig_coolant_tank":
			mesh = _build_cryo_tank("dig_bore_steel", "dig_copper_ram", "orbital_ice_arc", 1.15, 3.3)
		"dig_catwalk_ns":
			mesh = _build_walkway_deck("dig_catwalk_deck", "dig_bore_steel", "dig_hydraulic_hull", Vector3(46.0, 0.8, 6.4), true)
		"dig_catwalk_ew":
			mesh = _build_walkway_deck("dig_catwalk_deck", "dig_bore_steel", "dig_hydraulic_hull", Vector3(6.4, 0.8, 42.0), false)
		"dig_blast_shield":
			mesh = _build_bulkhead("dig_hydraulic_hull", "dig_bore_steel", "dig_copper_ram", "dig_amber_beacon", Vector3(5.4, 2.8, 1.5))
		"dig_gantry_bridge":
			mesh = _build_gantry_bridge("dig_gantry_deck", "dig_bore_steel", "dig_hydraulic_hull", "dig_copper_ram", Vector3(48.0, 1.0, 5.6))
		"dig_hoist_rail":
			mesh = _build_overhead_rail("dig_bore_steel", "dig_hydraulic_hull", "dig_copper_ram", "dig_amber_beacon", Vector3(44.0, 1.3, 2.4))
		"dig_catwalk_pier":
			mesh = _build_stanchion_column("dig_bore_steel", "dig_hydraulic_hull", "dig_copper_ram", 7.1, 1.25, 3.8)
		"dig_bridge_stanchion":
			mesh = _build_stanchion_column("dig_bore_steel", "dig_hydraulic_hull", "dig_copper_ram", 15.8, 1.35, 4.4)
		"dig_crane_portal":
			mesh = _build_stanchion_column("dig_bore_steel", "dig_hydraulic_hull", "dig_copper_ram", 20.4, 1.45, 4.6)
		"dig_bore_derrick":
			mesh = _build_bore_derrick(44.0)
		"dig_derrick_beacon":
			mesh = _build_beacon_crown("dig_bore_steel", "dig_amber_beacon", 3.8, 3.0)
		"orbital_hull_floor":
			mesh = _build_flat_floor("orbital_hull_deck", Vector3(64.0, 1.0, 64.0))
		"orbital_relay_collar":
			mesh = _build_orbital_relay_collar(10.0, 11.4, 12.4, 0.42)
		"orbital_coaming_ns":
			mesh = _build_orbital_coaming(Vector3(64.0, 3.6, 5.0), true)
		"orbital_coaming_ew":
			mesh = _build_orbital_coaming(Vector3(5.0, 3.6, 64.0), false)
		"orbital_rib_arch":
			mesh = _build_hull_rib_arch(18.0, 15.0)
		"orbital_jump_pad":
			mesh = _build_jump_pad("orbital_charcoal", "orbital_verdigris", "orbital_ice_arc", Vector3(5.0, 0.5, 5.0))
		"orbital_bulkhead_bay":
			mesh = _build_bulkhead("orbital_rib_hull", "orbital_charcoal", "orbital_verdigris", "orbital_ice_arc", Vector3(3.2, 4.4, 7.6))
		"orbital_cryo_pod":
			mesh = _build_cryo_tank("orbital_charcoal", "orbital_copper", "orbital_ice_arc", 1.1, 3.2)
		"orbital_catwalk_ns":
			mesh = _build_walkway_deck("orbital_catwalk_deck", "orbital_charcoal", "orbital_verdigris", Vector3(44.0, 0.8, 6.5), true)
		"orbital_catwalk_ew":
			mesh = _build_walkway_deck("orbital_catwalk_deck", "orbital_charcoal", "orbital_verdigris", Vector3(6.5, 0.8, 44.0), false)
		"orbital_shield_fin":
			mesh = _build_bulkhead("orbital_verdigris", "orbital_charcoal", "orbital_copper", "orbital_ancient_glow", Vector3(5.2, 2.7, 1.4))
		"orbital_gantry_bridge":
			mesh = _build_gantry_bridge("orbital_gantry_deck", "orbital_charcoal", "orbital_rib_hull", "orbital_copper", Vector3(48.0, 1.0, 5.6))
		"orbital_crane_beam":
			mesh = _build_overhead_rail("orbital_charcoal", "orbital_mast_steel", "orbital_copper", "orbital_ice_arc", Vector3(42.0, 1.2, 2.2))
		"orbital_catwalk_pier":
			mesh = _build_stanchion_column("orbital_charcoal", "orbital_verdigris", "orbital_copper", 7.6, 1.20, 3.8)
		"orbital_bridge_stanchion":
			mesh = _build_stanchion_column("orbital_charcoal", "orbital_verdigris", "orbital_copper", 16.3, 1.32, 4.4)
		"orbital_crane_portal":
			mesh = _build_stanchion_column("orbital_charcoal", "orbital_mast_steel", "orbital_copper", 20.6, 1.42, 4.6)
		"orbital_choir_mast":
			mesh = _build_choir_mast(44.0)
		"orbital_zenith_crown":
			mesh = _build_beacon_crown("orbital_mast_steel", "orbital_ancient_glow", 4.0, 3.2)
	if mesh != null:
		_mesh_cache[key] = mesh
	return mesh


static func _build_flat_floor(slot: String, size: Vector3) -> ArrayMesh:
	var canvas := _new_canvas()
	_add_flat_deck_slab(canvas, slot, size, 0.42, 0.04, 0.10)
	return canvas.commit({"asset_kind": slot, "walkable_flat": true})


static func _build_crusher_channel_lip(r_in: float, r_out_top: float, r_out_bot: float, height: float) -> ArrayMesh:
	var canvas := _new_canvas()
	_add_beveled_annulus(canvas, "dig_bore_steel", Transform3D.IDENTITY, 24, r_in, r_out_top, r_out_bot, height, 0.14, 0.42, 0.0, 0.84)
	_add_beveled_annulus(canvas, "dig_copper_ram", Transform3D(Basis.IDENTITY, Vector3(0.0, -0.02, 0.0)), 24, r_in - 0.12, r_in + 0.14, r_in + 0.18, height * 0.78, 0.20, 0.44, 0.0, 0.88)
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var rad := Vector3(cos(ang), 0.0, sin(ang))
		HeroSculptor.add_chamfered_plate(
			canvas, "dig_hydraulic_hull", Transform3D(Basis(Vector3.UP, -ang), rad * ((r_out_top + r_out_bot) * 0.5 - 0.06)),
			Vector3(1.25, height * 0.90, 1.40), 0.05, 0.18, 0.48, 0.0, 0.86
		)
	return canvas.commit({"asset_kind": "dig_crusher_lip"})


static func _build_orbital_relay_collar(r_in: float, r_out_top: float, r_out_bot: float, height: float) -> ArrayMesh:
	var canvas := _new_canvas()
	_add_beveled_annulus(canvas, "orbital_verdigris", Transform3D.IDENTITY, 24, r_in, r_out_top, r_out_bot, height, 0.14, 0.36, 0.0, 0.84)
	_add_beveled_annulus(canvas, "orbital_ice_arc", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0)), 24, r_in - 0.12, r_in + 0.18, r_in + 0.22, height * 0.72, 0.18, 0.16, 0.92, 0.50)
	for i in 6:
		var ang := TAU * float(i) / 6.0
		var rad := Vector3(cos(ang), 0.0, sin(ang))
		HeroSculptor.add_chamfered_plate(
			canvas, "orbital_mast_steel", Transform3D(Basis(Vector3.UP, -ang), rad * (r_out_top + 0.12)),
			Vector3(1.10, height * 0.92, 1.55), 0.05, 0.18, 0.36, 0.0, 0.86
		)
	return canvas.commit({"asset_kind": "orbital_relay_collar"})


static func _build_stanchion_column(
	frame_slot: String,
	hull_slot: String,
	accent_slot: String,
	height: float,
	width: float,
	flange_span: float
) -> ArrayMesh:
	var canvas := _new_canvas()
	var hy := height * 0.5
	HeroSculptor.add_chamfered_plate(
		canvas, frame_slot, Transform3D.IDENTITY,
		Vector3(width * 0.52, height, width * 0.92), 0.06, 0.16, 0.48, 0.0, 0.86
	)
	for sx in [-1.0, 1.0]:
		HeroSculptor.add_chamfered_plate(
			canvas, hull_slot, Transform3D(Basis.IDENTITY, Vector3(sx * width * 0.34, 0.0, 0.0)),
			Vector3(width * 0.28, height - 0.2, width * 1.18), 0.05, 0.18, 0.42, 0.0, 0.86
		)
	HeroSculptor.add_chamfered_plate(
		canvas, frame_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, -hy + 0.35, 0.0)),
		Vector3(width * 1.65, 0.70, width * 1.85), 0.08, 0.16, 0.62, 0.0, 0.86
	)
	HeroSculptor.add_chamfered_plate(
		canvas, hull_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, hy - 0.35, 0.0)),
		Vector3(width * 1.55, 0.70, flange_span), 0.08, 0.18, 0.38, 0.0, 0.88
	)
	var collars := maxi(int(height / 5.2), 2)
	for i in collars:
		var cy := lerpf(-hy + 2.4, hy - 2.4, float(i) / float(maxi(collars - 1, 1)))
		HeroSculptor.add_chamfered_plate(
			canvas, accent_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, cy, 0.0)),
			Vector3(width * 1.32, 0.42, width * 1.38), 0.04, 0.22, 0.34, 0.0, 0.90
		)
	for sz in [-1.0, 1.0]:
		var p_bot := Vector3(0.0, hy - minf(height * 0.32, 3.6), sz * (width * 0.55))
		var p_top := Vector3(0.0, hy - 0.45, sz * (flange_span * 0.46))
		HeroSculptor.add_truss_rib(canvas, accent_slot, p_bot, p_top, 0.34, 0.06)
	return canvas.commit({"asset_kind": "structural_stanchion"})


static func _build_canyon_wall(size: Vector3, span_x: bool) -> ArrayMesh:
	var canvas := _new_canvas()
	var length := size.x if span_x else size.z
	var depth := size.z if span_x else size.x
	var h := size.y
	var rot := Basis.IDENTITY if span_x else Basis(Vector3.UP, PI * 0.5)
	HeroSculptor.add_chamfered_plate(
		canvas, "dig_redrock_wall", Transform3D(rot, Vector3(0.0, -h * 0.14, 0.0)),
		Vector3(length, h * 0.72, depth), 0.24, 0.12, 0.54, 0.0, 0.52
	)
	HeroSculptor.add_chamfered_plate(
		canvas, "dig_redrock_wall", Transform3D(rot, Vector3(0.0, h * 0.32, 0.0)),
		Vector3(length - 0.4, h * 0.36, depth * 0.82), 0.18, 0.14, 0.40, 0.0, 0.62
	)
	var ribs := maxi(int(length / 9.5), 4)
	for i in ribs:
		var frac := (float(i) + 0.5) / float(ribs) - 0.5
		var lx := frac * (length - 5.0)
		HeroSculptor.add_chamfered_plate(
			canvas, "dig_bore_steel", Transform3D(rot, rot * Vector3(lx, 0.0, 0.0)),
			Vector3(1.15, h * 1.02, depth * 0.96), 0.08, 0.16, 0.52, 0.0, 0.84
		)
		HeroSculptor.add_chamfered_plate(
			canvas, "dig_hydraulic_hull", Transform3D(rot, rot * Vector3(lx, h * 0.48, 0.0)),
			Vector3(1.50, 0.34, depth * 0.88), 0.06, 0.18, 0.38, 0.0, 0.86
		)
	return canvas.commit({"asset_kind": "dig_canyon_wall"})


static func _build_orbital_coaming(size: Vector3, span_x: bool) -> ArrayMesh:
	var canvas := _new_canvas()
	var length := size.x if span_x else size.z
	var depth := size.z if span_x else size.x
	var h := size.y
	var rot := Basis.IDENTITY if span_x else Basis(Vector3.UP, PI * 0.5)
	HeroSculptor.add_chamfered_plate(
		canvas, "orbital_rib_hull", Transform3D(rot, Vector3(0.0, -h * 0.12, 0.0)),
		Vector3(length, h * 0.74, depth), 0.22, 0.12, 0.42, 0.0, 0.64
	)
	HeroSculptor.add_chamfered_plate(
		canvas, "orbital_verdigris", Transform3D(rot, Vector3(0.0, h * 0.34, 0.0)),
		Vector3(length - 0.4, h * 0.28, depth * 0.78), 0.12, 0.14, 0.34, 0.0, 0.76
	)
	var ribs := maxi(int(length / 8.5), 4)
	for i in ribs:
		var frac := (float(i) + 0.5) / float(ribs) - 0.5
		var lx := frac * (length - 4.5)
		HeroSculptor.add_chamfered_plate(
			canvas, "orbital_charcoal", Transform3D(rot, rot * Vector3(lx, 0.02, 0.0)),
			Vector3(0.95, h * 1.02, depth * 0.94), 0.07, 0.16, 0.44, 0.0, 0.86
		)
		HeroSculptor.add_chamfered_plate(
			canvas, "orbital_copper", Transform3D(rot, rot * Vector3(lx, h * 0.48, 0.0)),
			Vector3(1.24, 0.24, depth * 0.84), 0.05, 0.22, 0.30, 0.0, 0.88
		)
	return canvas.commit({"asset_kind": "orbital_coaming"})


static func _build_hull_rib_arch(span_z: float, height: float) -> ArrayMesh:
	var canvas := _new_canvas()
	var steps := 7
	var half_z := span_z * 0.5
	for i in steps:
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var a0 := lerpf(-PI * 0.44, PI * 0.44, t0)
		var a1 := lerpf(-PI * 0.44, PI * 0.44, t1)
		var p0 := Vector3(0.0, cos(a0) * height, sin(a0) * half_z)
		var p1 := Vector3(0.0, cos(a1) * height, sin(a1) * half_z)
		HeroSculptor.add_truss_rib(canvas, "orbital_rib_hull", p0, p1, 1.15, 0.16)
		HeroSculptor.add_truss_rib(canvas, "orbital_charcoal", p0 + Vector3(0.0, -0.65, 0.0), p1 + Vector3(0.0, -0.65, 0.0), 0.55, 0.08)
	for sz in [-1.0, 1.0]:
		HeroSculptor.add_chamfered_plate(
			canvas, "orbital_verdigris", Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, sz * half_z)),
			Vector3(2.4, 4.2, 2.2), 0.14, 0.16, 0.46, 0.0, 0.84
		)
	return canvas.commit({"asset_kind": "orbital_rib_arch"})


static func _build_jump_pad(frame_slot: String, trim_slot: String, glow_slot: String, size: Vector3) -> ArrayMesh:
	var canvas := _new_canvas()
	var w := size.x
	var h := size.y
	var d := size.z
	HeroSculptor.add_chamfered_plate(
		canvas, frame_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, -h * 0.12, 0.0)),
		Vector3(w, h * 0.76, d), 0.10, 0.16, 0.48, 0.0, 0.86
	)
	_add_beveled_annulus(
		canvas, trim_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.24, 0.0)),
		16, w * 0.26, w * 0.38, w * 0.42, h * 0.42, 0.18, 0.34, 0.0, 0.86
	)
	HeroSculptor.add_chamfered_prism(
		canvas, glow_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.20, 0.0)),
		16, w * 0.24, w * 0.22, h * 0.32, 0.04, 0.04, 0.20, 0.12, 1.0, 0.0, 0.60
	)
	return canvas.commit({"asset_kind": "jump_pad"})


static func _build_press_housing(size: Vector3) -> ArrayMesh:
	var canvas := _new_canvas()
	var w := size.x
	var h := size.y
	var d := size.z
	HeroSculptor.add_chamfered_plate(
		canvas, "dig_hydraulic_hull", Transform3D.IDENTITY,
		Vector3(w, h, d), 0.16, 0.14, 0.46, 0.0, 0.84
	)
	HeroSculptor.add_chamfered_plate(
		canvas, "dig_bore_steel", Transform3D(Basis.IDENTITY, Vector3(0.0, -h * 0.44, 0.0)),
		Vector3(w + 0.45, h * 0.14, d + 0.45), 0.08, 0.16, 0.68, 0.0, 0.88
	)
	for sz in [-d * 0.28, d * 0.28]:
		HeroSculptor.add_chamfered_prism(
			canvas, "dig_copper_ram", Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.44, sz)),
			12, 0.62, 0.56, 1.15, 0.06, 0.06, 0.22, 0.32, 0.0, 0.0, 0.90
		)
	_add_clean_louver(
		canvas, "dig_bore_steel",
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(w * 0.52, 0.1, 0.0)),
		d * 0.48, h * 0.38, 0.22, 4, "dig_amber_beacon"
	)
	_add_clean_louver(
		canvas, "dig_bore_steel",
		Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-w * 0.52, 0.1, 0.0)),
		d * 0.48, h * 0.38, 0.22, 4, "dig_amber_beacon"
	)
	return canvas.commit({"asset_kind": "dig_press_housing"})


static func _build_cryo_tank(frame_slot: String, band_slot: String, core_slot: String, radius: float, height: float) -> ArrayMesh:
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_prism(
		canvas, core_slot, Transform3D.IDENTITY,
		16, radius * 0.94, radius * 0.94, height * 0.82, 0.08, 0.08, 0.18, 0.16, 0.92, 0.0, 0.55
	)
	for sy in [-1.0, 1.0]:
		HeroSculptor.add_chamfered_prism(
			canvas, frame_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, sy * height * 0.42, 0.0)),
			16, radius * 1.12, radius * 1.04, height * 0.20, 0.06, 0.06, 0.18, 0.48, 0.0, 0.0, 0.88
		)
	_add_beveled_annulus(
		canvas, band_slot, Transform3D.IDENTITY,
		16, radius * 0.92, radius * 1.12, radius * 1.14, 0.28, 0.20, 0.36, 0.0, 0.90
	)
	for i in 4:
		var ang := TAU * float(i) / 4.0 + PI * 0.25
		var b := Basis(Vector3.UP, -ang)
		var pos := Vector3(cos(ang) * radius * 1.02, 0.0, sin(ang) * radius * 1.02)
		HeroSculptor.add_chamfered_plate(
			canvas, frame_slot, Transform3D(b, pos),
			Vector3(0.18, height * 0.86, 0.22), 0.03, 0.18, 0.42, 0.0, 0.88
		)
	return canvas.commit({"asset_kind": "cryo_tank"})


static func _build_walkway_deck(deck_slot: String, girder_slot: String, trim_slot: String, size: Vector3, span_x: bool) -> ArrayMesh:
	var canvas := _new_canvas()
	_add_flat_deck_slab(canvas, deck_slot, Vector3(size.x, size.y * 0.56, size.z), 0.38, 0.04, 0.08, Vector3(0.0, size.y * 0.22, 0.0))
	var length := size.x if span_x else size.z
	var width := size.z if span_x else size.x
	var rot := Basis.IDENTITY if span_x else Basis(Vector3.UP, PI * 0.5)
	for side in [-1.0, 1.0]:
		HeroSculptor.add_chamfered_plate(
			canvas, girder_slot,
			Transform3D(rot, rot * Vector3(0.0, -size.y * 0.26, side * (width * 0.42))),
			Vector3(length - 0.6, size.y * 0.46, 0.56), 0.06, 0.16, 0.54, 0.0, 0.84
		)
	var ribs := maxi(int(length / 6.5), 4)
	for i in ribs:
		var frac := (float(i) + 0.5) / float(ribs) - 0.5
		var lx := frac * (length - 4.0)
		HeroSculptor.add_chamfered_plate(
			canvas, trim_slot,
			Transform3D(rot, rot * Vector3(lx, -size.y * 0.30, 0.0)),
			Vector3(0.46, size.y * 0.40, width * 0.84), 0.05, 0.16, 0.50, 0.0, 0.86
		)
	return canvas.commit({"asset_kind": deck_slot, "walkable_flat": true})


static func _build_bulkhead(hull_slot: String, frame_slot: String, accent_slot: String, glow_slot: String, size: Vector3) -> ArrayMesh:
	var canvas := _new_canvas()
	var w := size.x
	var h := size.y
	var d := size.z
	HeroSculptor.add_chamfered_plate(
		canvas, hull_slot, Transform3D.IDENTITY,
		Vector3(w, h, d), 0.12, 0.14, 0.42, 0.0, 0.84
	)
	HeroSculptor.add_chamfered_plate(
		canvas, frame_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, -h * 0.44, 0.0)),
		Vector3(w + 0.28, h * 0.16, d + 0.28), 0.06, 0.16, 0.62, 0.0, 0.86
	)
	HeroSculptor.add_chamfered_plate(
		canvas, accent_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.44, 0.0)),
		Vector3(w + 0.14, h * 0.14, d + 0.14), 0.05, 0.18, 0.34, 0.0, 0.88
	)
	for sx in [-w * 0.34, w * 0.34]:
		HeroSculptor.add_chamfered_plate(
			canvas, frame_slot, Transform3D(Basis.IDENTITY, Vector3(sx, 0.0, 0.0)),
			Vector3(0.36, h * 0.94, d + 0.22), 0.05, 0.18, 0.46, 0.0, 0.88
		)
	if w >= 4.0:
		_add_clean_louver(
			canvas, frame_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, d * 0.50)),
			w * 0.42, h * 0.38, 0.18, 3, glow_slot
		)
	return canvas.commit({"asset_kind": "hard_bulkhead"})


static func _build_gantry_bridge(deck_slot: String, frame_slot: String, truss_slot: String, trim_slot: String, size: Vector3) -> ArrayMesh:
	var canvas := _new_canvas()
	_add_flat_deck_slab(canvas, deck_slot, Vector3(size.x, size.y * 0.54, size.z), 0.36, 0.04, 0.08, Vector3(0.0, size.y * 0.23, 0.0))
	for sz in [-1.0, 1.0]:
		HeroSculptor.add_chamfered_plate(
			canvas, frame_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, -size.y * 0.28, sz * (size.z * 0.42))),
			Vector3(size.x - 0.6, size.y * 0.48, 0.58), 0.06, 0.16, 0.50, 0.0, 0.86
		)
	var bays := 8
	for i in bays:
		var lx := lerpf(-size.x * 0.44, size.x * 0.44, float(i) / float(bays - 1))
		HeroSculptor.add_chamfered_plate(
			canvas, truss_slot, Transform3D(Basis.IDENTITY, Vector3(lx, -size.y * 0.36, 0.0)),
			Vector3(0.55, size.y * 0.56, size.z * 0.86), 0.05, 0.16, 0.44, 0.0, 0.86
		)
	HeroSculptor.add_chamfered_plate(
		canvas, trim_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, -size.y * 0.58, 0.0)),
		Vector3(size.x * 0.88, 0.24, 0.46), 0.04, 0.20, 0.38, 0.0, 0.88
	)
	return canvas.commit({"asset_kind": deck_slot, "walkable_flat": true})


static func _build_overhead_rail(frame_slot: String, hull_slot: String, accent_slot: String, glow_slot: String, size: Vector3) -> ArrayMesh:
	var canvas := _new_canvas()
	HeroSculptor.add_chamfered_plate(
		canvas, frame_slot, Transform3D.IDENTITY,
		Vector3(size.x, size.y * 0.58, size.z * 0.68), 0.08, 0.16, 0.44, 0.0, 0.84
	)
	for sy in [-1.0, 1.0]:
		HeroSculptor.add_chamfered_plate(
			canvas, hull_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, sy * size.y * 0.40, 0.0)),
			Vector3(size.x + 0.4, size.y * 0.24, size.z), 0.06, 0.18, 0.38, 0.0, 0.88
		)
	for i in 7:
		var lx := lerpf(-size.x * 0.42, size.x * 0.42, float(i) / 6.0)
		HeroSculptor.add_chamfered_plate(
			canvas, accent_slot, Transform3D(Basis.IDENTITY, Vector3(lx, 0.0, 0.0)),
			Vector3(0.52, size.y * 1.06, size.z * 1.06), 0.05, 0.22, 0.34, 0.0, 0.90
		)
	HeroSculptor.add_chamfered_plate(
		canvas, glow_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, -size.y * 0.54, 0.0)),
		Vector3(6.5, 0.18, size.z * 0.42), 0.03, 0.18, 0.12, 1.0, 0.50
	)
	return canvas.commit({"asset_kind": "overhead_rail"})


static func _build_bore_derrick(height: float) -> ArrayMesh:
	var canvas := _new_canvas()
	var hy := height * 0.5
	HeroSculptor.add_chamfered_prism(
		canvas, "dig_redrock_wall", Transform3D(Basis.IDENTITY, Vector3(0.0, -hy + 3.2, 0.0)),
		8, 6.2, 5.4, 6.4, 0.24, 0.24, 0.14, 0.60, 0.0, 0.0, 0.72
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "dig_bore_steel", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0)),
		12, 3.6, 2.2, height - 6.0, 0.18, 0.18, 0.16, 0.48, 0.0, 0.0, 0.86
	)
	var leg_r_bot := 5.1
	var leg_r_top := 2.9
	for i in 4:
		var ang := TAU * float(i) / 4.0 + PI * 0.25
		var p_bot := Vector3(cos(ang) * leg_r_bot, -hy + 5.0, sin(ang) * leg_r_bot)
		var p_top := Vector3(cos(ang) * leg_r_top, hy - 1.5, sin(ang) * leg_r_top)
		HeroSculptor.add_truss_rib(canvas, "dig_hydraulic_hull", p_bot, p_top, 0.92, 0.12)
	for band: float in [0.22, 0.48, 0.74, 0.94]:
		var by := lerpf(-hy + 5.0, hy - 2.0, band)
		var br := lerpf(4.8, 2.9, band)
		_add_beveled_annulus(
			canvas, "dig_copper_ram", Transform3D(Basis.IDENTITY, Vector3(0.0, by, 0.0)),
			12, br - 0.55, br + 0.35, br + 0.45, 1.05, 0.20, 0.36, 0.0, 0.88
		)
	return canvas.commit({"asset_kind": "dig_bore_derrick"})


static func _build_choir_mast(height: float) -> ArrayMesh:
	var canvas := _new_canvas()
	var hy := height * 0.5
	HeroSculptor.add_chamfered_prism(
		canvas, "orbital_verdigris", Transform3D(Basis.IDENTITY, Vector3(0.0, -hy + 3.5, 0.0)),
		12, 5.8, 4.8, 7.0, 0.20, 0.20, 0.14, 0.52, 0.0, 0.0, 0.80
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "orbital_mast_steel", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0)),
		12, 3.8, 2.1, height - 6.0, 0.16, 0.16, 0.16, 0.42, 0.0, 0.0, 0.86
	)
	for i in 4:
		var ang := TAU * float(i) / 4.0
		var b := Basis(Vector3.UP, -ang)
		HeroSculptor.add_chamfered_plate(
			canvas, "orbital_rib_hull",
			Transform3D(b, Vector3(cos(ang) * 3.8, -hy + 14.0, sin(ang) * 3.8)),
			Vector3(1.8, 22.0, 0.68), 0.10, 0.18, 0.38, 0.0, 0.86
		)
	for ring_h: float in [0.0, 9.0, 16.5]:
		var rr := 5.2 - ring_h * 0.09
		_add_closed_torus(canvas, "orbital_copper", Transform3D(Basis.IDENTITY, Vector3(0.0, ring_h, 0.0)), rr, 0.38, 20, 8, 0.24, 0.30, 0.0)
	return canvas.commit({"asset_kind": "orbital_choir_mast"})


static func _build_beacon_crown(frame_slot: String, glow_slot: String, radius: float, height: float) -> ArrayMesh:
	var canvas := _new_canvas()
	_add_beveled_annulus(canvas, glow_slot, Transform3D.IDENTITY, 20, radius * 0.58, radius * 0.96, radius, height * 0.72, 0.20, 0.12, 1.0, 0.55)
	for sy in [-1.0, 1.0]:
		_add_beveled_annulus(
			canvas, frame_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, sy * height * 0.44, 0.0)),
			20, radius * 0.50, radius * 1.06, radius * 1.08, height * 0.24, 0.18, 0.36, 0.0, 0.88
		)
	for i in 6:
		var ang := TAU * float(i) / 6.0
		var b := Basis(Vector3.UP, -ang)
		HeroSculptor.add_chamfered_plate(
			canvas, frame_slot, Transform3D(b, Vector3(cos(ang) * radius * 0.98, 0.0, sin(ang) * radius * 0.98)),
			Vector3(0.42, height * 1.04, 0.48), 0.05, 0.18, 0.38, 0.0, 0.88
		)
	return canvas.commit({"asset_kind": "beacon_crown"})
