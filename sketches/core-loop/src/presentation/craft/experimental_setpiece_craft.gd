@tool
class_name ExperimentalSetpieceCraft
extends Node3D

const HeroSculptor := preload("res://src/presentation/craft/hero_kitbash_sculptor.gd")
const Lookdev := preload("res://src/presentation/craft/craft_lookdev.gd")
const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const DECK_LOOK := {"bottom_grime": 0.58, "side_wear": 0.42}
const ANNULUS_LOOK := {
	"lip_ratio": 0.10,
	"lip_max": 0.12,
	"ramp": true,
	"inner_foot_grime": 0.78,
	"bevel_grime": 0.56,
	"outer_foot_grime": 0.80,
}
const LOUVER_LOOK := {"back_grime": 0.88, "back_edge_wear": 0.32, "slat_grime": 0.72, "slat_edge_wear": 0.90}

const CHUNK_MESH_SPECS := {
	"Tier0_Basin/BasinFloor/Mesh": "basin_floor",
	"Tier0_Basin/CrucibleWellRing": "crucible_lip",
	"Tier0_Basin/RimNorth/Mesh": "rim_bank_ns",
	"Tier0_Basin/RimSouth/Mesh": "rim_bank_ns",
	"Tier0_Basin/RimWest/Mesh": "rim_bank_ew",
	"Tier0_Basin/RimEast/Mesh": "rim_bank_ew",
	"Tier0_Basin/JumpPadDeckSW": "jump_pad",
	"Tier0_Basin/JumpPadDeckNE": "jump_pad",
	"Tier0_Basin/CompactorHousingLeft/Mesh": "compactor_housing",
	"Tier0_Basin/CompactorHousingRight/Mesh": "compactor_housing",
	"Tier0_Basin/CryoPipeAssembly/Mesh": "cryo_pipe_tank",
	"Tier1_Catwalks/CatwalkNorth/Mesh": "catwalk_span",
	"Tier1_Catwalks/CatwalkSouth/Mesh": "catwalk_span",
	"Tier1_Catwalks/CatwalkWest/Mesh": "catwalk_side",
	"Tier1_Catwalks/CatwalkEast/Mesh": "catwalk_side",
	"Tier1_Catwalks/BulkheadMidWest/Mesh": "hard_bulkhead",
	"Tier1_Catwalks/BulkheadMidEast/Mesh": "hard_bulkhead",
	"Tier2_UpperGantry/GantryWalkway/Mesh": "gantry_bridge",
	"Tier2_UpperGantry/CraneRailBeam": "crane_track",
	"SightlineLandmark/CrucibleSpireBody/SpireMesh": "spire_stack",
	"SightlineLandmark/BeaconCollar": "beacon_collar",
}

const WALKABLE_DECK_PATHS := [
	"Tier0_Basin/BasinFloor/Mesh",
	"Tier1_Catwalks/CatwalkNorth/Mesh",
	"Tier1_Catwalks/CatwalkSouth/Mesh",
	"Tier1_Catwalks/CatwalkWest/Mesh",
	"Tier1_Catwalks/CatwalkEast/Mesh",
	"Tier2_UpperGantry/GantryWalkway/Mesh",
]

static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}
static var _slag_shader: Shader = null

var _dressed := false


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED and not _dressed:
		_dressed = true
		dress_chunk(self)


func _ready() -> void:
	if not _dressed:
		_dressed = true
		dress_chunk(self)


static func reset_for_tests() -> void:
	_mesh_cache.clear()
	_mat_cache.clear()
	_slag_shader = null


static func dress_chunk(chunk_root: Node) -> int:
	if chunk_root == null or not is_instance_valid(chunk_root):
		return 0
	var dressed_count := 0
	for rel_path: String in CHUNK_MESH_SPECS.keys():
		var mi := chunk_root.get_node_or_null(rel_path) as MeshInstance3D
		if mi == null:
			continue
		var kind := String(CHUNK_MESH_SPECS[rel_path])
		var mesh := get_chunk_mesh(kind)
		if mesh == null:
			continue
		mi.mesh = mesh
		mi.material_override = null
		bind_surface_materials(mi)
		dressed_count += 1
	return dressed_count


static func bind_surface_materials(mi: MeshInstance3D) -> int:
	return Lookdev.bind_surface_materials(mi, get_material)


static func get_material(slot: String) -> Material:
	if slot == "hazard_stripe":
		return Palette.hazard_stripe()
	if _mat_cache.has(slot):
		var cached := _mat_cache[slot] as ShaderMaterial
		if cached != null and cached.shader != null and (cached.shader.resource_path == Lookdev.MASTER_SHADER_PATH or slot == "slag_molten"):
			cached.set_shader_parameter("reduce_flashes", FlashGuard.on)
		return cached

	var mat: ShaderMaterial = null
	match slot:
		"combat_floor":
			mat = Lookdev.preset_material("combat_floor_apron")
		"catwalk_deck":
			mat = Lookdev.duplicate_preset("combat_floor_apron", "smelter_catwalk_deck")
			if mat != null:
				mat.set_shader_parameter("floor_albedo", Color(0.28, 0.34, 0.34, 1.0))
				mat.set_shader_parameter("floor_secondary_albedo", Color(0.23, 0.29, 0.30, 1.0))
				mat.set_shader_parameter("crack_albedo", Color(0.14, 0.17, 0.17, 1.0))
				mat.set_shader_parameter("slab_metres", 3.2)
				mat.set_shader_parameter("base_metallic", 0.14)
				mat.set_shader_parameter("oil_patch_strength", 0.56)
				mat.set_shader_parameter("value_clamp_min", 0.22)
				mat.set_shader_parameter("value_clamp_max", 0.42)
				mat.set_shader_parameter("saturation_cap", 0.14)
		"gantry_deck":
			mat = Lookdev.duplicate_preset("combat_floor_apron", "smelter_gantry_deck")
			if mat != null:
				mat.set_shader_parameter("floor_albedo", Color(0.39, 0.39, 0.36, 1.0))
				mat.set_shader_parameter("floor_secondary_albedo", Color(0.33, 0.34, 0.32, 1.0))
				mat.set_shader_parameter("crack_albedo", Color(0.18, 0.19, 0.18, 1.0))
				mat.set_shader_parameter("slab_metres", 3.0)
				mat.set_shader_parameter("base_metallic", 0.18)
				mat.set_shader_parameter("oil_patch_strength", 0.44)
				mat.set_shader_parameter("value_clamp_min", 0.25)
				mat.set_shader_parameter("value_clamp_max", 0.44)
				mat.set_shader_parameter("saturation_cap", 0.12)
		"hull_plating":
			mat = Lookdev.duplicate_preset("oxidized_hull_plating", "smelter_hull_plating")
			if mat != null:
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"iron_frame":
			mat = Lookdev.duplicate_preset("oil_slicked_iron", "smelter_iron_frame")
			if mat != null:
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"concrete_plinth":
			mat = Lookdev.duplicate_preset("scorched_concrete", "smelter_concrete_plinth")
			if mat != null:
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"petrol_enamel":
			mat = Lookdev.duplicate_preset("oil_slicked_iron", "smelter_petrol_enamel")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Color(0.21, 0.34, 0.33, 1.0))
				mat.set_shader_parameter("secondary_albedo", Color(0.16, 0.27, 0.27, 1.0))
				mat.set_shader_parameter("base_metallic", 0.32)
				mat.set_shader_parameter("base_roughness", 0.64)
				mat.set_shader_parameter("oil_sheen_strength", 0.46)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"mast_steel":
			mat = Lookdev.duplicate_preset("oil_slicked_iron", "smelter_mast_steel")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Color(0.55, 0.55, 0.49, 1.0))
				mat.set_shader_parameter("secondary_albedo", Color(0.43, 0.44, 0.40, 1.0))
				mat.set_shader_parameter("base_metallic", 0.48)
				mat.set_shader_parameter("base_roughness", 0.54)
				mat.set_shader_parameter("oil_sheen_strength", 0.36)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"copper_coil":
			mat = Lookdev.duplicate_preset("oxidized_hull_plating", "smelter_forged_copper")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Palette.COPPER)
				mat.set_shader_parameter("secondary_albedo", Palette.COPPER.darkened(0.28))
				mat.set_shader_parameter("base_metallic", 0.76)
				mat.set_shader_parameter("base_roughness", 0.36)
				mat.set_shader_parameter("edge_wear_albedo", Color("e3b986"))
				mat.set_shader_parameter("edge_wear_strength", 0.68)
				mat.set_shader_parameter("grime_strength", 0.64)
				mat.set_shader_parameter("normal_relief", 0.38)
				mat.set_shader_parameter("detail_tex_strength", 0.34)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"emissive_core":
			mat = Lookdev.duplicate_preset("plasma_conduit_core", "smelter_arc_core")
			if mat != null:
				mat.set_shader_parameter("emissive_color", Palette.ARC)
				mat.set_shader_parameter("emissive_secondary_color", Palette.AMBER)
				mat.set_shader_parameter("emissive_energy", 4.4)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"emissive_amber":
			mat = Lookdev.duplicate_preset("plasma_conduit_core", "smelter_amber_core")
			if mat != null:
				mat.set_shader_parameter("emissive_color", Palette.AMBER)
				mat.set_shader_parameter("emissive_secondary_color", Palette.HAZARD)
				mat.set_shader_parameter("emissive_gradient_mix", 0.42)
				mat.set_shader_parameter("emissive_energy", 4.0)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"ancient_beacon":
			mat = Lookdev.duplicate_preset("plasma_conduit_core", "smelter_ancient_beacon")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Color(0.11, 0.17, 0.14, 1.0))
				mat.set_shader_parameter("secondary_albedo", Color(0.16, 0.24, 0.19, 1.0))
				mat.set_shader_parameter("emissive_color", Palette.ANCIENT)
				mat.set_shader_parameter("emissive_secondary_color", Color("6bd42b"))
				mat.set_shader_parameter("emissive_gradient_mix", 0.32)
				mat.set_shader_parameter("emissive_energy", 4.6)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"cryo_glass":
			mat = Lookdev.duplicate_preset("plasma_conduit_core", "smelter_cryo_coolant")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Color(0.36, 0.56, 0.62, 1.0))
				mat.set_shader_parameter("secondary_albedo", Color(0.24, 0.40, 0.46, 1.0))
				mat.set_shader_parameter("base_roughness", 0.34)
				mat.set_shader_parameter("base_metallic", 0.22)
				mat.set_shader_parameter("emissive_color", Palette.ICE)
				mat.set_shader_parameter("emissive_secondary_color", Color("5ac4e8"))
				mat.set_shader_parameter("emissive_gradient_mix", 0.35)
				mat.set_shader_parameter("emissive_energy", 2.4)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		"slag_molten":
			mat = _build_molten_slag_material()
		"slag_crust":
			mat = Lookdev.duplicate_preset("scorched_concrete", "smelter_slag_crust")
			if mat != null:
				mat.set_shader_parameter("base_albedo", Color(0.18, 0.17, 0.16, 1.0))
				mat.set_shader_parameter("secondary_albedo", Color(0.27, 0.23, 0.20, 1.0))
				mat.set_shader_parameter("base_roughness", 0.90)
				mat.set_shader_parameter("base_metallic", 0.08)
				mat.set_shader_parameter("edge_wear_albedo", Color(0.42, 0.37, 0.32, 1.0))
				mat.set_shader_parameter("edge_wear_strength", 0.52)
				mat.set_shader_parameter("foot_grime_height", 0.0)
		_:
			mat = Lookdev.duplicate_preset("oil_slicked_iron", "smelter_default_iron")
			if mat != null:
				mat.set_shader_parameter("foot_grime_height", 0.0)

	if mat != null:
		if mat.shader != null and (mat.shader.resource_path == Lookdev.MASTER_SHADER_PATH or slot == "slag_molten"):
			mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
		_mat_cache[slot] = mat
	return mat


static func _build_molten_slag_material() -> ShaderMaterial:
	if _slag_shader == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 crust_albedo : source_color = vec3(0.13, 0.055, 0.045);
uniform vec3 magma_deep : source_color = vec3(0.72, 0.11, 0.02);
uniform vec3 magma_mid : source_color = vec3(1.0, 0.36, 0.05);
uniform vec3 magma_hot : source_color = vec3(1.0, 0.78, 0.22);
uniform float pool_radius = 11.0;
uniform float emissive_energy = 2.6;
uniform bool reduce_flashes = false;

varying vec3 slag_world_pos;
varying vec3 slag_local_pos;
varying vec4 slag_vcolor;

float slag_hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float slag_noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = slag_hash2(i);
	float b = slag_hash2(i + vec2(1.0, 0.0));
	float c = slag_hash2(i + vec2(0.0, 1.0));
	float d = slag_hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float slag_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
	for (int i = 0; i < 4; i++) {
		v += a * slag_noise2(p);
		p = rot * p * 2.03 + vec2(7.3, 13.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	slag_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	slag_local_pos = VERTEX;
	slag_vcolor = COLOR;
}

void fragment() {
	float flow_speed = reduce_flashes ? 0.025 : 0.085;
	vec2 uv = slag_world_pos.xz * 0.26;
	vec2 drift = vec2(TIME * flow_speed, -TIME * flow_speed * 0.72);
	float wx = slag_fbm(uv * 1.15 + drift);
	float wy = slag_fbm(uv * 1.15 - drift * 0.8 + vec2(5.2, 1.3));
	vec2 warped = uv + vec2(wx - 0.5, wy - 0.5) * 1.85;
	float cell_a = slag_fbm(warped * 1.45);
	float cell_b = slag_fbm(warped * 2.95 - drift * 0.6 + vec2(11.4, 4.7));
	float ridge_a = 1.0 - abs(cell_a * 2.0 - 1.0);
	float ridge_b = 1.0 - abs(cell_b * 2.0 - 1.0);
	float vein_primary = pow(clamp(ridge_a, 0.0, 1.0), 2.3);
	float vein_fine = pow(clamp(ridge_b, 0.0, 1.0), 3.2);
	float magma_heat = clamp(vein_primary * 0.78 + vein_fine * 0.42 + cell_a * 0.16, 0.0, 1.0);
	float r_norm = clamp(length(slag_local_pos.xz) / max(pool_radius, 0.5), 0.0, 1.0);
	float rim_cool = smoothstep(0.68, 0.99, r_norm);
	float grime_cool = clamp(slag_vcolor.g * 0.65, 0.0, 0.65);
	float heat = clamp(magma_heat * (1.0 - rim_cool * 0.68) * (1.0 - grime_cool), 0.0, 1.0);
	float pulse_amp = reduce_flashes ? 0.04 : 0.14;
	float pulse_spd = reduce_flashes ? 0.8 : 1.5;
	float pulse = 1.0 + sin(TIME * pulse_spd + cell_a * 5.0) * pulse_amp;
	vec3 glow_col = mix(magma_deep, magma_mid, smoothstep(0.24, 0.64, heat));
	glow_col = mix(glow_col, magma_hot, smoothstep(0.66, 0.94, heat));
	float crust_mask = 1.0 - smoothstep(0.22, 0.58, heat);
	vec3 base_col = mix(glow_col * 0.28, crust_albedo * (0.72 + cell_b * 0.55), crust_mask);
	float bump_h = (crust_mask * 0.032 + cell_b * 0.018);
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 n_bump = normalize(NORMAL - normalize(cross(dpdy, NORMAL)) * dFdx(bump_h) * 2.2 - normalize(cross(NORMAL, dpdx)) * dFdy(bump_h) * 2.2);
	ALBEDO = base_col;
	ROUGHNESS = mix(0.30, 0.88, crust_mask);
	METALLIC = mix(0.06, 0.16, crust_mask);
	SPECULAR = 0.42;
	NORMAL = n_bump;
	AO = mix(1.0, 0.42, rim_cool * 0.7 + crust_mask * 0.3);
	EMISSION = glow_col * emissive_energy * pulse * smoothstep(0.18, 0.88, heat) * clamp(slag_vcolor.b, 0.0, 1.0);
}
"""
		_slag_shader = sh
	var mat := ShaderMaterial.new()
	mat.resource_name = "smelter_slag_molten_convection"
	mat.shader = _slag_shader
	mat.set_shader_parameter("reduce_flashes", FlashGuard.on)
	return mat


static func get_chunk_mesh(kind: String) -> ArrayMesh:
	var key := "chunk:" + kind
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var mesh: ArrayMesh = null
	match kind:
		"basin_floor":
			mesh = build_basin_floor(Vector3(64.0, 1.0, 64.0))
		"crucible_lip":
			mesh = build_crucible_well_ring(10.85, 12.15, 13.15, 0.40)
		"rim_bank_ns":
			mesh = build_rim_bank(Vector3(64.0, 3.6, 5.0), true)
		"rim_bank_ew":
			mesh = build_rim_bank(Vector3(5.0, 3.6, 64.0), false)
		"catwalk_span":
			mesh = build_catwalk(Vector3(44.0, 0.8, 6.5), true)
		"catwalk_side":
			mesh = build_catwalk(Vector3(6.5, 0.8, 44.0), false)
		"hard_bulkhead":
			mesh = build_hard_bulkhead(Vector3(5.2, 2.6, 1.4))
		"gantry_bridge":
			mesh = build_gantry_bridge(Vector3(48.0, 1.0, 5.5))
		"crane_track":
			mesh = build_crane_track(Vector3(42.0, 1.2, 2.2))
		"spire_stack":
			mesh = build_spire_stack(3.2, 5.4, 43.0)
		"beacon_collar":
			mesh = build_beacon_collar(3.8, 3.0)
		"jump_pad":
			mesh = build_jump_pad(Vector3(5.0, 0.5, 5.0))
		"compactor_housing":
			mesh = build_compactor_housing(Vector3(3.0, 4.4, 8.0))
		"cryo_pipe_tank":
			mesh = build_cryo_pipe_tank(1.1, 3.2)
	if mesh != null:
		_mesh_cache[key] = mesh
	return mesh


static func get_cargo_hull_mesh(size: Vector3) -> ArrayMesh:
	var key := "setpiece:cargo:%s" % str(size)
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var mesh := build_salvage_cargo_hull(size)
	_mesh_cache[key] = mesh
	return mesh


static func get_harpoon_bridge_mesh(radius: float = 1.4, height: float = 0.8) -> ArrayMesh:
	var key := "setpiece:bridge:%.2f:%.2f" % [radius, height]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var mesh := build_airborne_harpoon_bridge(radius, height)
	_mesh_cache[key] = mesh
	return mesh


static func get_molten_slag_pool_mesh(radius: float, height: float = 0.25) -> ArrayMesh:
	var key := "setpiece:slag_pool:%.2f:%.2f" % [radius, height]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var mesh := build_molten_slag_pool(radius, height)
	_mesh_cache[key] = mesh
	return mesh


static func get_slag_berm_mesh(size: Vector3, brittle: bool = false) -> ArrayMesh:
	var key := "setpiece:slag_berm:%s:%s" % [str(size), str(brittle)]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var mesh := build_slag_berm(size, brittle)
	_mesh_cache[key] = mesh
	return mesh


static func get_compactor_ram_mesh(size: Vector3) -> ArrayMesh:
	var key := "setpiece:compactor_ram:%s" % str(size)
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var mesh := build_compactor_ram_gate(size)
	_mesh_cache[key] = mesh
	return mesh


static func get_hoist_cable_mesh() -> ArrayMesh:
	var key := "setpiece:hoist_cable"
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var mesh := build_hoist_cable_unit()
	_mesh_cache[key] = mesh
	return mesh


static func get_hoist_trolley_mesh() -> ArrayMesh:
	var key := "setpiece:hoist_trolley"
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var mesh := build_hoist_trolley_carriage()
	_mesh_cache[key] = mesh
	return mesh


static func build_hazard_strip_pad(width: float, length: float, height: float = 0.05) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	var w := maxf(width, 0.5)
	var l := maxf(length, 0.5)
	var h := maxf(height, 0.02)
	var rim := clampf(minf(w, l) * 0.06, 0.14, 0.34)
	HeroSculptor.add_flat_deck_slab(canvas, "iron_frame", Vector3(w, h * 0.72, l), 0.18, 0.12, 0.0, Vector3(0.0, -h * 0.14, 0.0), DECK_LOOK)
	HeroSculptor.add_flat_deck_slab(canvas, "hazard_stripe", Vector3(maxf(w - rim * 2.0, 0.2), h * 0.56, maxf(l - rim * 2.0, 0.2)), 0.05, 0.05, 0.0, Vector3(0.0, h * 0.16, 0.0), DECK_LOOK)
	return canvas.commit({"asset_kind": "hazard_strip_pad"})


static func get_hazard_disc_pad(radius: float, height: float = 0.08) -> ArrayMesh:
	var key := "setpiece:hazard_disc:%.2f:%.2f" % [radius, height]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	var r := maxf(radius, 0.5)
	var h := maxf(height, 0.03)
	HeroSculptor.add_chamfered_prism(
		canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, -h * 0.16, 0.0)),
		32, r + 0.24, r + 0.16, h * 0.68, h * 0.18, 0.08, 0.14, 0.42, 0.0, 0.0, 0.75
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "hazard_stripe", Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.16, 0.0)),
		32, r - 0.12, r - 0.18, h * 0.52, h * 0.14, 0.06, 0.06, 0.06, 0.0, 0.0, 0.12
	)
	var mesh := canvas.commit({"asset_kind": "hazard_disc_pad"})
	_mesh_cache[key] = mesh
	return mesh


static func _add_clean_valve_wheel(
	canvas: HeroSculptor.KitbashCanvas,
	slot: String,
	xform: Transform3D,
	radius: float = 0.36,
	tube_radius: float = 0.042,
	spoke_count: int = 4
) -> void:
	var segs := 16
	var sides := 8
	var rings: Array = []
	var centers: Array[Vector3] = []
	for i in segs:
		var ang := TAU * float(i) / float(segs)
		var radial := Vector3(cos(ang), sin(ang), 0.0)
		centers.append(xform * (radial * radius))
		var row: Array[Vector3] = []
		for j in sides:
			var phi := TAU * float(j) / float(sides)
			var local_off := radial * (cos(phi) * tube_radius) + Vector3(0.0, 0.0, sin(phi) * tube_radius)
			row.append(xform * (radial * radius + local_off))
		rings.append(row)
	var c_grip := Lookdev.encode_mask(0.92, 0.12, 0.0)
	var c_inner := Lookdev.encode_mask(0.32, 0.45, 0.0)
	for i in segs:
		var ni := (i + 1) % segs
		for j in sides:
			var nj := (j + 1) % sides
			var p00: Vector3 = rings[i][j]
			var p01: Vector3 = rings[i][nj]
			var p11: Vector3 = rings[ni][nj]
			var p10: Vector3 = rings[ni][j]
			var out_n := ((p00 + p01 + p11 + p10) * 0.25 - (centers[i] + centers[ni]) * 0.5).normalized()
			var cj := c_grip if (j <= 2 or j >= sides - 2) else c_inner
			canvas.add_quad(
				slot, p00, p01, p11, p10, out_n, cj, cj, cj, cj,
				(p00 - centers[i]).normalized(), (p01 - centers[i]).normalized(),
				(p11 - centers[ni]).normalized(), (p10 - centers[ni]).normalized()
			)
	var spokes := maxi(spoke_count, 3)
	var hub_r := tube_radius * 1.45
	for k in spokes:
		var ang := TAU * float(k) / float(spokes) + PI * 0.25
		var dir2 := Vector3(cos(ang), sin(ang), 0.0)
		var p_a := xform * (dir2 * hub_r)
		var p_b := xform * (dir2 * (radius - tube_radius * 0.55))
		HeroSculptor.add_truss_rib(canvas, slot, p_a, p_b, tube_radius * 1.10, tube_radius * 0.26)
	var stem_basis := xform.basis * Basis(Vector3.RIGHT, PI * 0.5)
	HeroSculptor.add_chamfered_prism(
		canvas, "iron_frame", Transform3D(stem_basis, xform * Vector3(0.0, 0.0, 0.03)), 6,
		tube_radius * 2.1, tube_radius * 1.75, tube_radius * 2.2,
		0.015, 0.015, 0.30, 0.35, 0.0, 0.0, 0.94
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "iron_frame", Transform3D(stem_basis, xform * Vector3(0.0, 0.0, -radius * 0.36)), 10,
		tube_radius * 1.65, tube_radius * 2.35, radius * 0.65,
		0.025, 0.025, 0.12, 0.84, 0.0, 0.0, 0.82
	)


static func build_basin_floor(size: Vector3) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	HeroSculptor.add_flat_deck_slab(canvas, "combat_floor", size, 0.44, 0.04, 0.10, Vector3.ZERO, DECK_LOOK)
	return canvas.commit({"asset_kind": "basin_floor", "walkable_flat": true})


static func build_crucible_well_ring(r_in: float, r_out_top: float, r_out_bot: float, height: float) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	HeroSculptor.add_beveled_annulus(canvas, "iron_frame", Transform3D.IDENTITY, 24, r_in, r_out_top, r_out_bot, height, 0.16, 0.42, 0.0, 0.88, ANNULUS_LOOK)
	HeroSculptor.add_beveled_annulus(
		canvas, "copper_coil", Transform3D(Basis.IDENTITY, Vector3(0.0, -0.02, 0.0)),
		24, r_in - 0.12, r_in + 0.14, r_in + 0.18, height * 0.76, 0.22, 0.48, 0.0, 0.90, ANNULUS_LOOK
	)
	for i in 8:
		var ang := TAU * float(i) / 8.0 + PI * 0.125
		var radial := Vector3(cos(ang), 0.0, sin(ang))
		var b_basis := Basis(Vector3.UP, -ang)
		var clamp_pos := radial * ((r_out_top + r_out_bot) * 0.5 - 0.08) + Vector3(0.0, -0.02, 0.0)
		HeroSculptor.add_chamfered_plate(
			canvas, "iron_frame", Transform3D(b_basis, clamp_pos),
			Vector3(1.18, height * 0.88, 1.35), 0.05, 0.18, 0.52, 0.0, 0.90
		)
		var bolt_base := clamp_pos + Vector3(0.0, height * 0.44, 0.0)
		var tangent := Vector3(-sin(ang), 0.0, cos(ang))
		HeroSculptor.add_rivet_strip(
			canvas, "copper_coil",
			bolt_base - tangent * 0.42, bolt_base + tangent * 0.42,
			Vector3.UP, 3, 0.065, 0.045
		)
	for j in 4:
		var ang := TAU * float(j) / 4.0
		var radial := Vector3(cos(ang), 0.0, sin(ang))
		var v_basis := Basis(Vector3.UP, -ang + PI * 0.5)
		var vent_pos := radial * (r_in - 0.04) + Vector3(0.0, 0.02, 0.0)
		HeroSculptor.add_chamfered_plate(
			canvas, "emissive_amber", Transform3D(v_basis, vent_pos),
			Vector3(1.45, 0.14, 0.24), 0.025, 0.20, 0.08, 1.0, 0.35
		)
	return canvas.commit({"asset_kind": "crucible_lip"})


static func build_rim_bank(size: Vector3, along_x: bool) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	var length := size.x if along_x else size.z
	var thick := size.z if along_x else size.x
	var h := size.y
	var rot := Basis.IDENTITY if along_x else Basis(Vector3.UP, PI * 0.5)
	var xf := Transform3D(rot, Vector3.ZERO)

	HeroSculptor.add_chamfered_plate(
		canvas, "hull_plating", xf * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.10, 0.0)),
		Vector3(length, h - 0.30, thick - 0.16), 0.14, 0.12, 0.34, 0.0, 0.88
	)
	HeroSculptor.add_chamfered_plate(
		canvas, "concrete_plinth", xf * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5 - 0.24, 0.0)),
		Vector3(length + 0.18, 0.48, thick + 0.22), 0.09, 0.10, 0.28, 0.0, 0.74
	)
	HeroSculptor.add_chamfered_plate(
		canvas, "concrete_plinth", xf * Transform3D(Basis.IDENTITY, Vector3(0.0, -h * 0.5 + 0.28, 0.0)),
		Vector3(length + 0.16, 0.56, thick + 0.26), 0.08, 0.10, 0.78, 0.0, 0.65
	)
	for side_z: float in [-1.0, 1.0]:
		HeroSculptor.add_chamfered_plate(
			canvas, "iron_frame", xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.18, side_z * (thick * 0.5 + 0.06))),
			Vector3(length - 0.5, 0.34, 0.28), 0.05, 0.16, 0.42, 0.0, 0.90
		)
	var pilaster_count := 7
	for i in pilaster_count:
		var px := lerpf(-length * 0.44, length * 0.44, float(i) / float(pilaster_count - 1))
		HeroSculptor.add_chamfered_plate(
			canvas, "iron_frame", xf * Transform3D(Basis.IDENTITY, Vector3(px, -0.04, 0.0)),
			Vector3(1.15, h - 0.14, thick + 0.48), 0.08, 0.16, 0.46, 0.0, 0.90
		)
		for side_z: float in [-1.0, 1.0]:
			var out_n := (rot * Vector3(0.0, 0.0, side_z)).normalized()
			HeroSculptor.add_rivet_strip(
				canvas, "copper_coil",
				xf * Vector3(px - 0.32, -h * 0.32, side_z * (thick * 0.5 + 0.24)),
				xf * Vector3(px - 0.32, h * 0.32, side_z * (thick * 0.5 + 0.24)),
				out_n, 4, 0.055, 0.04
			)
	for i in range(pilaster_count - 1):
		var lx := lerpf(-length * 0.44, length * 0.44, (float(i) + 0.5) / float(pilaster_count - 1))
		for side_z: float in [-1.0, 1.0]:
			var lrot := Basis.IDENTITY if side_z > 0.0 else Basis(Vector3.UP, PI)
			var lxf := xf * Transform3D(lrot, Vector3(lx, 0.62, side_z * (thick * 0.5 - 0.02)))
			HeroSculptor.add_clean_louver(canvas, "iron_frame", lxf, 3.2, 1.05, 0.32, 4, "emissive_amber" if i % 2 == 0 else "", LOUVER_LOOK)
	return canvas.commit({"asset_kind": "rim_bank"})


static func build_catwalk(size: Vector3, along_x: bool) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	var length := size.x if along_x else size.z
	var width := size.z if along_x else size.x
	var h := size.y
	var hy := h * 0.5
	var deck_h := 0.28
	HeroSculptor.add_flat_deck_slab(
		canvas, "catwalk_deck",
		Vector3(size.x, deck_h, size.z),
		0.38, 0.06, 0.14,
		Vector3(0.0, hy - deck_h * 0.5, 0.0), DECK_LOOK
	)
	var rot := Basis.IDENTITY if along_x else Basis(Vector3.UP, PI * 0.5)
	var xf := Transform3D(rot, Vector3.ZERO)
	var girder_y := hy - deck_h - 0.24
	for side_z: float in [-1.0, 1.0]:
		HeroSculptor.add_chamfered_plate(
			canvas, "petrol_enamel",
			xf * Transform3D(Basis.IDENTITY, Vector3(0.0, girder_y, side_z * (width * 0.5 - 0.22))),
			Vector3(length - 0.12, 0.44, 0.40), 0.05, 0.14, 0.36, 0.0, 0.88
		)
		HeroSculptor.add_chamfered_plate(
			canvas, "iron_frame",
			xf * Transform3D(Basis.IDENTITY, Vector3(0.0, hy - 0.15, side_z * (width * 0.5 + 0.07))),
			Vector3(length - 0.20, 0.24, 0.16), 0.03, 0.18, 0.44, 0.0, 0.90
		)
	HeroSculptor.add_chamfered_plate(
		canvas, "iron_frame",
		xf * Transform3D(Basis.IDENTITY, Vector3(0.0, girder_y - 0.04, 0.0)),
		Vector3(length - 0.36, 0.34, width - 1.1), 0.05, 0.14, 0.58, 0.0, 0.84
	)
	var rib_count := 9
	for i in rib_count:
		var rx := lerpf(-length * 0.46, length * 0.46, float(i) / float(rib_count - 1))
		HeroSculptor.add_chamfered_plate(
			canvas, "iron_frame",
			xf * Transform3D(Basis.IDENTITY, Vector3(rx, girder_y - 0.14, 0.0)),
			Vector3(0.42, 0.46, width + 0.14), 0.045, 0.16, 0.52, 0.0, 0.88
		)
		for side_z: float in [-1.0, 1.0]:
			var out_n := (rot * Vector3(0.0, 0.0, side_z)).normalized()
			HeroSculptor.add_rivet_strip(
				canvas, "copper_coil",
				xf * Vector3(rx - 0.10, girder_y - 0.04, side_z * (width * 0.5 + 0.07)),
				xf * Vector3(rx + 0.10, girder_y - 0.04, side_z * (width * 0.5 + 0.07)),
				out_n, 2, 0.045, 0.032
			)
	return canvas.commit({"asset_kind": "catwalk", "walkable_flat": true})


static func build_hard_bulkhead(size: Vector3) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	var w := size.x
	var h := size.y
	var d := size.z

	HeroSculptor.add_chamfered_plate(
		canvas, "hull_plating", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0)),
		Vector3(w - 0.16, h - 0.36, d - 0.24), 0.10, 0.11, 0.26, 0.0, 0.90
	)
	HeroSculptor.add_chamfered_plate(
		canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, -h * 0.5 + 0.20, 0.0)),
		Vector3(w + 0.10, 0.40, d + 0.12), 0.06, 0.16, 0.78, 0.0, 0.88
	)
	HeroSculptor.add_chamfered_plate(
		canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5 - 0.15, 0.0)),
		Vector3(w + 0.06, 0.30, d - 0.06), 0.06, 0.18, 0.30, 0.0, 0.92
	)
	for rx: float in [-w * 0.36, 0.0, w * 0.36]:
		HeroSculptor.add_chamfered_plate(
			canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(rx, 0.04, 0.0)),
			Vector3(0.36, h - 0.22, d + 0.08), 0.045, 0.16, 0.44, 0.0, 0.90
		)
	for sz: float in [-1.0, 1.0]:
		var lrot := Basis.IDENTITY if sz > 0.0 else Basis(Vector3.UP, PI)
		HeroSculptor.add_clean_louver(
			canvas, "iron_frame",
			Transform3D(lrot, Vector3(-w * 0.18, 0.36, sz * (d * 0.5 - 0.04))),
			1.25, 0.72, 0.24, 4, "", LOUVER_LOOK
		)
		HeroSculptor.add_rivet_strip(
			canvas, "iron_frame",
			Vector3(-w * 0.42, h * 0.5 - 0.16, sz * (d * 0.5 - 0.03)),
			Vector3(w * 0.42, h * 0.5 - 0.16, sz * (d * 0.5 - 0.03)),
			Vector3(0.0, 0.0, sz), 8, 0.042, 0.03
		)
	HeroSculptor.add_asymmetric_patch(
		canvas, "copper_coil",
		Transform3D(Basis.IDENTITY, Vector3(w * 0.20, -0.18, d * 0.5 - 0.06)),
		Vector3(1.15, 0.88, 0.12), 5.0, 6
	)
	_add_clean_valve_wheel(
		canvas, "copper_coil",
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(w * 0.5 + 0.08, -0.12, 0.0)),
		0.32, 0.04, 4
	)
	return canvas.commit({"asset_kind": "hard_bulkhead"})


static func build_gantry_bridge(size: Vector3) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	var length := size.x
	var width := size.z
	var hy := size.y * 0.5
	var deck_h := 0.30
	HeroSculptor.add_flat_deck_slab(
		canvas, "gantry_deck",
		Vector3(length, deck_h, width),
		0.36, 0.06, 0.14,
		Vector3(0.0, hy - deck_h * 0.5, 0.0), DECK_LOOK
	)
	var web_y := hy - deck_h - 0.34
	var bot_y := -hy - 0.26
	for sz: float in [-1.0, 1.0]:
		var z_chord := sz * (width * 0.5 - 0.24)
		HeroSculptor.add_chamfered_plate(
			canvas, "mast_steel", Transform3D(Basis.IDENTITY, Vector3(0.0, hy - 0.18, sz * (width * 0.5 + 0.06))),
			Vector3(length - 0.14, 0.28, 0.18), 0.035, 0.18, 0.34, 0.0, 0.90
		)
		HeroSculptor.add_chamfered_plate(
			canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, bot_y, z_chord)),
			Vector3(length - 0.4, 0.28, 0.34), 0.04, 0.16, 0.52, 0.0, 0.88
		)
		var bays := 12
		var bay_w := (length - 1.2) / float(bays)
		for b in bays:
			var x0 := -(length - 1.2) * 0.5 + float(b) * bay_w
			var x1 := x0 + bay_w
			var p_top := Vector3(x0 if b % 2 == 0 else x1, hy - deck_h - 0.04, z_chord)
			var p_bot := Vector3(x1 if b % 2 == 0 else x0, bot_y + 0.06, z_chord)
			HeroSculptor.add_truss_rib(canvas, "iron_frame", p_top, p_bot, 0.16, 0.032)
	var saddle_count := 7
	for i in saddle_count:
		var sx := lerpf(-length * 0.46, length * 0.46, float(i) / float(saddle_count - 1))
		HeroSculptor.add_chamfered_plate(
			canvas, "mast_steel", Transform3D(Basis.IDENTITY, Vector3(sx, web_y - 0.08, 0.0)),
			Vector3(0.52, 0.64, width + 0.22), 0.05, 0.16, 0.46, 0.0, 0.88
		)
	HeroSculptor.add_chamfered_plate(
		canvas, "emissive_core", Transform3D(Basis.IDENTITY, Vector3(0.0, bot_y - 0.12, 0.0)),
		Vector3(length - 4.0, 0.10, 0.28), 0.02, 0.20, 0.08, 1.0, 0.35
	)
	return canvas.commit({"asset_kind": "gantry_bridge", "walkable_flat": true})


static func build_crane_track(size: Vector3) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	var length := size.x
	var h := size.y
	var d := size.z
	HeroSculptor.add_chamfered_plate(
		canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.16, 0.0)),
		Vector3(length, h * 0.52, d * 0.72), 0.07, 0.16, 0.40, 0.0, 0.90
	)
	for sz: float in [-1.0, 1.0]:
		HeroSculptor.add_chamfered_plate(
			canvas, "copper_coil", Transform3D(Basis.IDENTITY, Vector3(0.0, -h * 0.30, sz * (d * 0.38))),
			Vector3(length - 0.24, 0.34, 0.44), 0.05, 0.22, 0.34, 0.0, 0.92
		)
	HeroSculptor.add_chamfered_plate(
		canvas, "emissive_core", Transform3D(Basis.IDENTITY, Vector3(0.0, -h * 0.34, 0.0)),
		Vector3(length - 2.4, 0.18, 0.26), 0.03, 0.20, 0.08, 1.0, 0.35
	)
	var clamp_count := 11
	for i in clamp_count:
		var cx := lerpf(-length * 0.48, length * 0.48, float(i) / float(clamp_count - 1))
		HeroSculptor.add_chamfered_plate(
			canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(cx, 0.02, 0.0)),
			Vector3(0.56, h + 0.16, d + 0.20), 0.055, 0.18, 0.48, 0.0, 0.90
		)
		for sz: float in [-1.0, 1.0]:
			HeroSculptor.add_rivet_strip(
				canvas, "copper_coil",
				Vector3(cx - 0.14, 0.22, sz * (d * 0.5 + 0.10)),
				Vector3(cx + 0.14, 0.22, sz * (d * 0.5 + 0.10)),
				Vector3(0.0, 0.0, sz), 2, 0.048, 0.036
			)
	for end_x: float in [-1.0, 1.0]:
		HeroSculptor.add_chamfered_plate(
			canvas, "hull_plating", Transform3D(Basis.IDENTITY, Vector3(end_x * (length * 0.5 - 0.36), -0.06, 0.0)),
			Vector3(0.72, h + 0.44, d + 0.36), 0.07, 0.16, 0.44, 0.0, 0.90
		)
	return canvas.commit({"asset_kind": "crane_track"})


static func build_spire_stack(r_top: float, r_bot: float, height: float) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	var hy := height * 0.5

	HeroSculptor.add_chamfered_prism(
		canvas, "concrete_plinth", Transform3D(Basis.IDENTITY, Vector3(0.0, -hy + 3.0, 0.0)),
		8, r_bot + 0.95, r_bot + 0.32, 6.0, 0.22, 0.24, 0.10, 0.72, 0.0, PI / 8.0, 0.74
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "petrol_enamel", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.2, 0.0)),
		12, r_bot - 0.12, r_top, height - 3.0, 0.18, 0.16, 0.14, 0.28, 0.0, 0.0, 0.88
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, hy - 0.65, 0.0)),
		12, r_top + 0.28, r_top + 0.68, 1.30, 0.14, 0.14, 0.18, 0.44, 0.0, 0.0, 0.92
	)
	for y_ring: float in [-10.0, 1.5, 12.5]:
		var frac := (y_ring + hy) / height
		var r_here := lerpf(r_bot, r_top, frac)
		HeroSculptor.add_chamfered_prism(
			canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, y_ring, 0.0)),
			12, r_here + 0.58, r_here + 0.52, 1.15, 0.12, 0.12, 0.18, 0.52, 0.0, 0.0, 0.90
		)
	for i in 4:
		var ang := TAU * float(i) / 4.0 + PI * 0.25
		var rad := Vector3(cos(ang), 0.0, sin(ang))
		var b_rot := Basis(Vector3.UP, -ang)
		HeroSculptor.add_chamfered_plate(
			canvas, "hull_plating", Transform3D(b_rot, rad * (r_bot - 0.15) + Vector3(0.0, -hy + 12.5, 0.0)),
			Vector3(1.55, 22.0, 1.10), 0.11, 0.14, 0.42, 0.0, 0.90
		)
	for sx: float in [-1.55, 1.55]:
		var p_bot := Vector3(sx, -hy + 4.5, r_bot * 0.86)
		var p_top := Vector3(sx * 0.84, hy - 4.0, r_top * 1.02)
		HeroSculptor.add_hydraulic_pipe(canvas, "copper_coil", p_bot, p_top, 0.42, 6, 0.58, 0.12, 0.88)
	for y_vent: float in [-4.5, 6.5]:
		var frac := (y_vent + hy) / height
		var r_here := lerpf(r_bot, r_top, frac)
		HeroSculptor.add_clean_louver(
			canvas, "iron_frame",
			Transform3D(Basis.IDENTITY, Vector3(0.0, y_vent, r_here - 0.06)),
			2.4, 2.2, 0.48, 5, "emissive_amber", LOUVER_LOOK
		)
	return canvas.commit({"asset_kind": "spire_stack"})


static func build_beacon_collar(radius: float, height: float) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	var hy := height * 0.5
	HeroSculptor.add_chamfered_prism(
		canvas, "ancient_beacon", Transform3D.IDENTITY,
		12, radius * 0.88, radius * 0.88, height * 0.74, 0.10, 0.10, 0.20, 0.06, 1.0, 0.0, 0.35
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, -hy + 0.34, 0.0)),
		12, radius + 0.32, radius + 0.16, 0.68, 0.09, 0.09, 0.18, 0.48, 0.0, 0.0, 0.92
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, hy - 0.26, 0.0)),
		12, radius + 0.22, radius + 0.48, 0.58, 0.09, 0.09, 0.18, 0.38, 0.0, 0.0, 0.92
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "copper_coil", Transform3D(Basis.IDENTITY, Vector3(0.0, hy + 0.42, 0.0)),
		8, radius * 0.72, radius * 0.24, 0.92, 0.10, 0.10, 0.22, 0.32, 0.0, 0.0, 0.92
	)
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var rad := Vector3(cos(ang), 0.0, sin(ang))
		HeroSculptor.add_chamfered_plate(
			canvas, "iron_frame", Transform3D(Basis(Vector3.UP, -ang), rad * (radius - 0.02)),
			Vector3(0.42, height - 0.24, 0.44), 0.05, 0.18, 0.42, 0.0, 0.92
		)
	return canvas.commit({"asset_kind": "beacon_collar"})


static func build_jump_pad(size: Vector3) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	var r_outer := minf(size.x, size.z) * 0.5
	var h := size.y
	HeroSculptor.add_chamfered_prism(
		canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, -h * 0.12, 0.0)),
		8, r_outer * 1.10, r_outer * 0.94, h * 0.76, 0.06, 0.08, 0.16, 0.54, 0.0, PI / 8.0, 0.90
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "copper_coil", Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.14, 0.0)),
		8, r_outer * 0.76, r_outer * 0.68, h * 0.52, 0.05, 0.06, 0.22, 0.28, 0.0, PI / 8.0, 0.92
	)
	HeroSculptor.add_beveled_annulus(
		canvas, "emissive_core", Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.24, 0.0)),
		16, r_outer * 0.50, r_outer * 0.62, r_outer * 0.64, 0.16, 0.20, 0.08, 1.0, 0.35, ANNULUS_LOOK
	)
	for i in 4:
		var ang := TAU * float(i) / 4.0 + PI * 0.25
		var rad := Vector3(cos(ang), 0.0, sin(ang))
		HeroSculptor.add_chamfered_plate(
			canvas, "iron_frame", Transform3D(Basis(Vector3.UP, -ang), rad * (r_outer * 0.86) + Vector3(0.0, 0.04, 0.0)),
			Vector3(0.54, h * 0.84, 0.72), 0.05, 0.18, 0.48, 0.0, 0.92
		)
	return canvas.commit({"asset_kind": "jump_pad"})


static func build_compactor_housing(size: Vector3) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	var w := size.x
	var h := size.y
	var d := size.z

	HeroSculptor.add_chamfered_plate(
		canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.06, 0.0)),
		Vector3(w - 0.18, h - 0.42, d - 0.22), 0.11, 0.16, 0.38, 0.0, 0.90
	)
	HeroSculptor.add_chamfered_plate(
		canvas, "concrete_plinth", Transform3D(Basis.IDENTITY, Vector3(0.0, -h * 0.5 + 0.28, 0.0)),
		Vector3(w + 0.16, 0.56, d + 0.18), 0.08, 0.10, 0.76, 0.0, 0.68
	)
	HeroSculptor.add_chamfered_plate(
		canvas, "hull_plating", Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5 - 0.22, 0.0)),
		Vector3(w + 0.08, 0.44, d + 0.08), 0.08, 0.14, 0.30, 0.0, 0.90
	)
	for sz: float in [-d * 0.30, 0.0, d * 0.30]:
		HeroSculptor.add_hydraulic_pipe(
			canvas, "copper_coil",
			Vector3(-w * 0.52, -0.35, sz), Vector3(w * 0.52, -0.35, sz),
			0.34, 4, 0.46, 0.14, 0.86
		)
	for side_x: float in [-1.0, 1.0]:
		var lrot := Basis(Vector3.UP, PI * 0.5 if side_x > 0.0 else -PI * 0.5)
		HeroSculptor.add_clean_louver(
			canvas, "iron_frame",
			Transform3D(lrot, Vector3(side_x * (w * 0.5 - 0.04), 0.85, 0.0)),
			d * 0.54, 1.05, 0.28, 4, "emissive_amber", LOUVER_LOOK
		)
		HeroSculptor.add_rivet_strip(
			canvas, "copper_coil",
			Vector3(side_x * (w * 0.5 - 0.06), -h * 0.32, -d * 0.42),
			Vector3(side_x * (w * 0.5 - 0.06), -h * 0.32, d * 0.42),
			Vector3(side_x, 0.0, 0.0), 8, 0.055, 0.04
		)
	_add_clean_valve_wheel(
		canvas, "copper_coil",
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.32, d * 0.5 + 0.08)),
		0.42, 0.048, 4
	)
	return canvas.commit({"asset_kind": "compactor_housing"})


static func build_cryo_pipe_tank(radius: float, height: float) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	var hy := height * 0.5
	HeroSculptor.add_chamfered_prism(
		canvas, "cryo_glass", Transform3D.IDENTITY,
		12, radius * 0.88, radius * 0.88, height * 0.72, 0.12, 0.10, 0.18, 0.10, 0.85, 0.0, 0.42
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, -hy + 0.28, 0.0)),
		12, radius * 1.12, radius * 1.02, 0.56, 0.07, 0.08, 0.16, 0.74, 0.0, 0.0, 0.90
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, hy - 0.24, 0.0)),
		12, radius * 1.02, radius * 0.84, 0.48, 0.07, 0.08, 0.18, 0.36, 0.0, 0.0, 0.92
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "copper_coil", Transform3D(Basis.IDENTITY, Vector3(0.0, hy + 0.14, 0.0)),
		8, radius * 0.42, radius * 0.28, 0.34, 0.05, 0.05, 0.24, 0.30, 0.0, 0.0, 0.92
	)
	for yc: float in [-0.56, 0.0, 0.56]:
		HeroSculptor.add_chamfered_prism(
			canvas, "copper_coil", Transform3D(Basis.IDENTITY, Vector3(0.0, yc, 0.0)),
			12, radius * 1.04, radius * 1.04, 0.16, 0.04, 0.04, 0.22, 0.38, 0.0, 0.0, 0.92
		)
	for i in 4:
		var ang := TAU * float(i) / 4.0 + PI * 0.25
		var rad := Vector3(cos(ang), 0.0, sin(ang))
		HeroSculptor.add_chamfered_plate(
			canvas, "iron_frame", Transform3D(Basis(Vector3.UP, -ang), rad * (radius * 0.98)),
			Vector3(0.22, height - 0.42, 0.20), 0.035, 0.18, 0.42, 0.0, 0.92
		)
	_add_clean_valve_wheel(
		canvas, "copper_coil",
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.24, radius * 1.06)),
		0.32, 0.038, 4
	)
	return canvas.commit({"asset_kind": "cryo_pipe_tank"})


static func build_salvage_cargo_hull(size: Vector3) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	var w := size.x
	var h := size.y
	var d := size.z

	HeroSculptor.add_chamfered_plate(
		canvas, "hull_plating", Transform3D.IDENTITY,
		Vector3(w - 0.18, h - 0.24, d - 0.18), 0.12, 0.11, 0.26, 0.0, 0.90
	)
	for sy: float in [-1.0, 1.0]:
		HeroSculptor.add_chamfered_plate(
			canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, sy * (h * 0.5 - 0.16), 0.0)),
			Vector3(w + 0.06, 0.32, d + 0.06), 0.055, 0.16, 0.72 if sy < 0.0 else 0.34, 0.0, 0.92
		)
	for sx: float in [-w * 0.46, -w * 0.16, w * 0.16, w * 0.46]:
		HeroSculptor.add_chamfered_plate(
			canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(sx, 0.0, 0.0)),
			Vector3(0.26, h - 0.10, d + 0.12), 0.04, 0.16, 0.46, 0.0, 0.90
		)
	HeroSculptor.add_chamfered_plate(
		canvas, "copper_coil", Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5 + 0.10, 0.0)),
		Vector3(w * 0.54, 0.26, d * 0.48), 0.05, 0.22, 0.34, 0.0, 0.92
	)
	for lx: float in [-w * 0.22, w * 0.22]:
		for lz: float in [-d * 0.18, d * 0.18]:
			HeroSculptor.add_chamfered_prism(
				canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(lx, h * 0.5 + 0.26, lz)),
				8, 0.18, 0.14, 0.24, 0.04, 0.04, 0.20, 0.44, 0.0, 0.0, 0.92
			)
	for sz: float in [-1.0, 1.0]:
		var lrot := Basis.IDENTITY if sz > 0.0 else Basis(Vector3.UP, PI)
		HeroSculptor.add_clean_louver(
			canvas, "iron_frame",
			Transform3D(lrot, Vector3(0.0, 0.26, sz * (d * 0.5 - 0.04))),
			1.22, 0.74, 0.22, 4, "", LOUVER_LOOK
		)
		HeroSculptor.add_rivet_strip(
			canvas, "copper_coil",
			Vector3(-w * 0.38, -h * 0.5 + 0.16, sz * (d * 0.5 + 0.03)),
			Vector3(w * 0.38, -h * 0.5 + 0.16, sz * (d * 0.5 + 0.03)),
			Vector3(0.0, 0.0, sz), 7, 0.045, 0.032
		)
	HeroSculptor.add_asymmetric_patch(
		canvas, "copper_coil",
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(w * 0.5 - 0.02, -0.14, 0.18)),
		Vector3(1.18, 0.92, 0.12), -4.5, 6
	)
	return canvas.commit({"asset_kind": "salvage_cargo_hull"})


static func build_airborne_harpoon_bridge(radius: float, height: float) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	HeroSculptor.add_beveled_annulus(
		canvas, "iron_frame", Transform3D.IDENTITY,
		16, radius * 0.58, radius * 1.04, radius * 1.04, height * 0.88, 0.18, 0.42, 0.0, 0.92, ANNULUS_LOOK
	)
	HeroSculptor.add_coil_winding(
		canvas, "copper_coil", Transform3D.IDENTITY,
		radius * 0.44, height * 1.04, 5, 0.055
	)
	HeroSculptor.add_beveled_annulus(
		canvas, "emissive_core", Transform3D(Basis.IDENTITY, Vector3(0.0, -height * 0.06, 0.0)),
		16, radius * 0.64, radius * 0.86, radius * 0.86, height * 0.36, 0.20, 0.08, 1.0, 0.35, ANNULUS_LOOK
	)
	for i in 4:
		var ang := TAU * float(i) / 4.0 + PI * 0.25
		var rad := Vector3(cos(ang), 0.0, sin(ang))
		HeroSculptor.add_chamfered_plate(
			canvas, "copper_coil", Transform3D(Basis(Vector3.UP, -ang), rad * (radius * 1.04)),
			Vector3(0.46, height * 0.62, 0.36), 0.045, 0.24, 0.32, 0.0, 0.94
		)
	return canvas.commit({"asset_kind": "airborne_harpoon_bridge"})


static func build_molten_slag_pool(radius: float, height: float) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	HeroSculptor.add_chamfered_prism(
		canvas, "slag_molten", Transform3D.IDENTITY,
		24, radius, radius * 0.98, height * 0.76, height * 0.18, 0.14, 0.10, 0.08, 1.0, 0.0, 0.18
	)
	HeroSculptor.add_beveled_annulus(
		canvas, "slag_crust", Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.18, 0.0)),
		24, radius * 0.79, radius * 0.98, radius * 1.01, height * 0.82, 0.10, 0.84, 0.0, 0.52, ANNULUS_LOOK
	)
	var islands := [
		{"pos": Vector3(-3.8, height * 0.14, 2.8), "r": 2.95, "s": 7, "ph": 0.2, "h": 0.34, "tx": 0.04, "tz": -0.03},
		{"pos": Vector3(4.3, height * 0.14, -2.1), "r": 2.65, "s": 6, "ph": 0.7, "h": 0.30, "tx": -0.03, "tz": 0.04},
		{"pos": Vector3(-1.4, height * 0.14, -4.6), "r": 2.40, "s": 7, "ph": 1.1, "h": 0.28, "tx": 0.03, "tz": 0.03},
		{"pos": Vector3(2.9, height * 0.14, 4.4), "r": 2.45, "s": 6, "ph": 0.4, "h": 0.32, "tx": -0.04, "tz": -0.02},
		{"pos": Vector3(-5.8, height * 0.14, -2.9), "r": 1.90, "s": 6, "ph": 0.9, "h": 0.26, "tx": 0.02, "tz": -0.04},
		{"pos": Vector3(0.4, height * 0.16, 0.5), "r": 2.05, "s": 7, "ph": 1.4, "h": 0.36, "tx": -0.02, "tz": 0.03},
		{"pos": Vector3(5.6, height * 0.14, 2.2), "r": 1.70, "s": 5, "ph": 0.3, "h": 0.25, "tx": 0.04, "tz": 0.02},
	]
	for isl: Dictionary in islands:
		var pos: Vector3 = isl["pos"]
		var r: float = float(isl["r"])
		var s: int = int(isl["s"])
		var ph: float = float(isl["ph"])
		var ih: float = float(isl["h"])
		var tilt := Basis(Vector3.RIGHT, float(isl["tx"])) * Basis(Vector3.BACK, float(isl["tz"]))
		HeroSculptor.add_chamfered_prism(
			canvas, "slag_crust", Transform3D(Basis.IDENTITY, pos + Vector3(0.0, -0.02, 0.0)),
			s, r * 1.10, r * 0.92, ih * 0.58,
			0.05, 0.18, 0.08, 0.94, 0.0, ph, 0.32
		)
		HeroSculptor.add_chamfered_prism(
			canvas, "slag_crust", Transform3D(tilt, pos + Vector3(0.04, ih * 0.34, -0.03)),
			s, r * 0.84, r * 0.62, ih * 0.72,
			0.06, 0.16, 0.12, 0.82, 0.0, ph + 0.18, 0.58
		)
		HeroSculptor.add_chamfered_prism(
			canvas, "slag_crust", Transform3D(tilt, pos + Vector3(-r * 0.14, ih * 0.68, r * 0.10)),
			maxi(s - 1, 5), r * 0.48, r * 0.30, ih * 0.46,
			0.05, 0.10, 0.16, 0.64, 0.0, ph + 0.45, 0.72
		)
	return canvas.commit({"asset_kind": "molten_slag_pool"})


static func build_hoist_cable_unit() -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	HeroSculptor.add_chamfered_prism(
		canvas, "iron_frame", Transform3D.IDENTITY,
		8, 0.068, 0.068, 1.0, 0.025, 0.014, 0.24, 0.58, 0.0, 0.0, 0.84
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "copper_coil", Transform3D(Basis.IDENTITY, Vector3(0.0, -0.44, 0.0)),
		8, 0.115, 0.095, 0.11, 0.02, 0.018, 0.24, 0.42, 0.0, 0.0, 0.90
	)
	HeroSculptor.add_chamfered_prism(
		canvas, "copper_coil", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.44, 0.0)),
		8, 0.095, 0.115, 0.11, 0.02, 0.018, 0.24, 0.42, 0.0, 0.0, 0.90
	)
	return canvas.commit({"asset_kind": "hoist_cable_unit"})


static func build_hoist_trolley_carriage() -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	HeroSculptor.add_chamfered_plate(
		canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.22, 0.0)),
		Vector3(3.4, 1.15, 2.75), 0.09, 0.16, 0.44, 0.0, 0.90
	)
	HeroSculptor.add_chamfered_plate(
		canvas, "hull_plating", Transform3D(Basis.IDENTITY, Vector3(0.0, -0.42, 0.0)),
		Vector3(2.8, 0.62, 2.15), 0.07, 0.14, 0.38, 0.0, 0.88
	)
	for sx: float in [-1.1, 1.1]:
		HeroSculptor.add_chamfered_prism(
			canvas, "copper_coil", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx, 0.42, 0.0)),
			10, 0.36, 0.36, 2.98, 0.04, 0.04, 0.24, 0.34, 0.0, 0.0, 0.92
		)
	HeroSculptor.add_chamfered_plate(
		canvas, "emissive_core", Transform3D(Basis.IDENTITY, Vector3(0.0, -0.68, 0.0)),
		Vector3(1.6, 0.16, 0.42), 0.03, 0.20, 0.08, 1.0, 0.35
	)
	return canvas.commit({"asset_kind": "hoist_trolley_carriage"})


static func build_slag_berm(size: Vector3, brittle: bool = false) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	var w := size.x
	var h := size.y
	var d := size.z
	var vein_slot := "cryo_glass" if brittle else "slag_molten"
	var body_slot := "cryo_glass" if brittle else "slag_crust"

	HeroSculptor.add_chamfered_plate(
		canvas, body_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, -h * 0.24, 0.0)),
		Vector3(w, h * 0.52, d), 0.16, 0.16, 0.68 if not brittle else 0.18, 0.22 if brittle else 0.0, 0.78
	)
	HeroSculptor.add_chamfered_plate(
		canvas, body_slot, Transform3D(Basis(Vector3.UP, 0.08), Vector3(-w * 0.14, h * 0.12, 0.04)),
		Vector3(w * 0.62, h * 0.66, d * 0.78), 0.15, 0.18, 0.44 if not brittle else 0.14, 0.28 if brittle else 0.0, 0.84
	)
	HeroSculptor.add_chamfered_plate(
		canvas, body_slot, Transform3D(Basis(Vector3.UP, -0.11), Vector3(w * 0.24, h * 0.04, -0.05)),
		Vector3(w * 0.46, h * 0.56, d * 0.72), 0.14, 0.18, 0.48 if not brittle else 0.16, 0.26 if brittle else 0.0, 0.84
	)
	HeroSculptor.add_chamfered_plate(
		canvas, vein_slot, Transform3D(Basis.IDENTITY, Vector3(0.0, -h * 0.14, 0.0)),
		Vector3(w * 0.86, 0.24, d * 0.88), 0.05, 0.20, 0.08, 0.92, 0.36
	)
	HeroSculptor.add_truss_rib(
		canvas, "iron_frame",
		Vector3(-w * 0.34, -h * 0.34, -d * 0.14),
		Vector3(-w * 0.22, h * 0.44, d * 0.10),
		0.18, 0.036
	)
	HeroSculptor.add_truss_rib(
		canvas, "iron_frame",
		Vector3(w * 0.32, -h * 0.30, d * 0.12),
		Vector3(w * 0.18, h * 0.38, -d * 0.12),
		0.16, 0.034
	)
	return canvas.commit({"asset_kind": "slag_berm", "brittle": brittle})


static func build_compactor_ram_gate(size: Vector3) -> ArrayMesh:
	var canvas := HeroSculptor.create_canvas_without_foot_grime()
	var w := size.x
	var h := size.y
	var d := size.z

	HeroSculptor.add_chamfered_plate(
		canvas, "petrol_enamel", Transform3D.IDENTITY,
		Vector3(w - 0.34, h - 0.36, d - 0.26), 0.11, 0.12, 0.28, 0.0, 0.88
	)
	HeroSculptor.add_chamfered_plate(
		canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, -h * 0.5 + 0.24, 0.0)),
		Vector3(w + 0.04, 0.48, d + 0.14), 0.07, 0.18, 0.74, 0.0, 0.92
	)
	HeroSculptor.add_chamfered_plate(
		canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5 - 0.20, 0.0)),
		Vector3(w + 0.04, 0.40, d + 0.10), 0.065, 0.18, 0.36, 0.0, 0.92
	)
	for sx: float in [-w * 0.46, -w * 0.16, w * 0.16, w * 0.46]:
		HeroSculptor.add_chamfered_plate(
			canvas, "iron_frame", Transform3D(Basis.IDENTITY, Vector3(sx, 0.0, 0.0)),
			Vector3(0.36, h - 0.12, d + 0.08), 0.05, 0.16, 0.46, 0.0, 0.90
		)
	for px: float in [-w * 0.28, w * 0.28]:
		HeroSculptor.add_hydraulic_pipe(
			canvas, "copper_coil",
			Vector3(px, -h * 0.38, 0.0), Vector3(px, h * 0.38, 0.0),
			0.26, 4, 0.36, 0.18, 0.82
		)
	for sz: float in [-1.0, 1.0]:
		var lrot := Basis.IDENTITY if sz > 0.0 else Basis(Vector3.UP, PI)
		HeroSculptor.add_clean_louver(
			canvas, "iron_frame",
			Transform3D(lrot, Vector3(0.0, h * 0.22, sz * (d * 0.5 - 0.04))),
			2.10, 0.72, 0.24, 4, "emissive_amber", LOUVER_LOOK
		)
		HeroSculptor.add_rivet_strip(
			canvas, "copper_coil",
			Vector3(-w * 0.40, -h * 0.5 + 0.24, sz * (d * 0.5 + 0.07)),
			Vector3(w * 0.40, -h * 0.5 + 0.24, sz * (d * 0.5 + 0.07)),
			Vector3(0.0, 0.0, sz), 8, 0.052, 0.038
		)
	return canvas.commit({"asset_kind": "compactor_ram_gate"})
