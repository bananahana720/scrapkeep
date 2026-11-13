extends Node

const LineView := preload("res://src/presentation/line_view.gd")
const CarrierBank := preload("res://src/presentation/carrier_bank.gd")
const Palette := preload("res://src/core/palette.gd")
const SignalLifetime := preload("res://src/core/signal_lifetime.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const WardenLook := preload("res://src/combat/warden_look.gd")
const WardenKit := preload("res://src/combat/warden_kit.gd")
const WARDEN_BASE := "res://assets/models/warden_clamp_base.glb"
const WARDEN_KITS := {"reactor": "reactor", "swarm": "hive", "mind": "mind"}
# Presentation-only mantles by stage, never by warden_variant: stage 5 (the Mind's hand) has no
# variant, so only the stage tells the hand from the choir. Each row names the family it fits; a
# mismatch mounts nothing. KF0 2026-10-10: one Warden kind per world moved the reactor meltdown
# to stage 2; stages 1 and 3 (the bare reactor and the bare swarm) stay bare.
const WARDEN_MANTLES := {
	2: {"family": "reactor", "path": "res://assets/models/warden_mantle_meltdown.glb"},
	4: {"family": "swarm", "path": "res://assets/models/warden_mantle_brood.glb"},
	# Rows 5 and 6 stay until KF8b makes the stage 5 and 6 Wardens park anchors: today they take the
	# clamp path, and the body path skips mantles (coordinator ruling at the KF8a merge, 2026-10-11).
	5: {"family": "mind", "path": "res://assets/models/warden_mantle_hand.glb"},
	6: {"family": "mind", "path": "res://assets/models/warden_mantle_choir.glb"},
}
# KF8a: a park Warden (spec "harpoon_anchor": true) of a kind with a recipe body wears that body
# in place of the clamp base, kit and mantle; the authored boss arenas' Wardens keep the clamp.
# Rows from artifacts/local/alpha/push/w13/wardens/<kind>/hero_assets_rows.txt (KF5 to KF7). The
# mind body retired WARDEN_MANTLES 5 and 6 (wardens/mind.md section 8). Each body sits like the
# clamp, origin at the collider's floor (position.y = -HALF_HEIGHT); "kits" ride under it.
const WARDEN_BODIES := {
	"reactor": {"body": "res://assets/models/warden_reactor.glb", "kits": [], "point": "WeakPoint",
		# Mounting-only parts: the other mounting's are hidden.
		"mount_parts": {"dam_face": ["GateL", "GateR"], "flume": ["PourLip"]}},
	"swarm": {"body": "res://assets/models/warden_swarm.glb", "kits": ["res://assets/models/warden_swarm_kit_drones.glb"],
		"point": "WeakPoint", "hang": "Suspension", "grips": ["Grip0", "Grip1", "Grip2"],
		"shed_rings": ["Ring5", "Ring4", "Ring3", "Ring2"]},
	"mind": {"body": "res://assets/models/warden_mind.glb", "kits": [], "point": "WeakPoint"},
}
# design-v3/wardens/<kind>.md section 5: the blend (s) each clip starts with.
const WARDEN_BODY_BLENDS := {
	"reactor": {"idle": 1.0, "pulse_warn": 0.5, "pulse": 0.1, "active": 0.5, "chunk_lost": 0.8, "chunk_lost_1": 0.8,
		"chunk_lost_2": 0.8, "chunk_lost_3": 0.8, "shrug": 0.2, "gates_open": 0.3, "pour": 0.3, "final_quiet": 2.0},
	"swarm": {"idle": 1.0, "pulse": 0.1, "active": 0.5, "hoist_ride": 0.3, "snip": 0.2, "stagger_open": 0.5,
		"chunk_shed": 0.8, "brood_dark": 0.5, "break": 2.0},
	"mind": {"idle": 1.0, "pulse_warn": 0.5, "pulse": 0.1, "active": 0.5, "chunk_lost": 0.8, "chunk_lost_ring": 0.8,
		"chunk_lost_middle": 0.8, "chunk_lost_index": 0.8, "shrug": 0.2, "grip_falter": 0.5, "takeoff": 0.3,
		"glide": 0.3, "land": 0.2, "knocked_down": 0.2, "final_quiet": 2.0},
}
# The clip each kind plays on the charge, the pulse's tail and the break. The swarm has no
# pulse_warn: its pulse clip is the charge (2.0 s) then the slam (0.4 s), section 5.
const WARDEN_BODY_CHARGE := {"reactor": "pulse_warn", "swarm": "pulse", "mind": "pulse_warn"}
const WARDEN_BODY_FINAL := {"reactor": "final_quiet", "swarm": "break", "mind": "final_quiet"}
const WARDEN_REACTOR_PULSE_EXTRA := {"dam_face": "gates_open", "flume": "pour"}
# Chunk order (mind rows section 4): the chunk_lost clip by the finger it curls, and that finger's seam.
const MIND_CHUNK_FINGERS := [
	{"clip": "chunk_lost", "seam": "ancient_light_seam3"},        # little, first
	{"clip": "chunk_lost_ring", "seam": "ancient_light_seam2"},
	{"clip": "chunk_lost_middle", "seam": "ancient_light_seam1"},
	{"clip": "chunk_lost_index", "seam": "ancient_light_seam0"},  # fourth; final_quiet puts out the thumb
]
# The lens bones: under the held perch only these take idle, pulse_warn, pulse and active.
const MIND_LENS_BONES := ["Lens", "LensIris", "SmallLens0", "SmallLens1", "SmallLens2", "SmallLens3", "SmallLens4"]
# Clips that move the whole hand: the perch hold lets them through.
const MIND_FLIGHT_CLIPS := ["takeoff", "glide", "land", "knocked_down"]
# Mount group name -> node path under HeroKit that receives the group's meshes.
const MANTLE_MOUNTS := {
	"MountBody": "Body", "MountVent0": "Vent0", "MountVent1": "Vent1", "MountVent2": "Vent2",
	"MountArmL": "ArmL", "MountArmR": "ArmR",
}

const EventKinds := preload("res://src/core/event_kinds.gd")
const Accretion := preload("res://src/build/accretion.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const PilotReactions := preload("res://src/presentation/pilot_reactions.gd")
const MechaMotion := preload("res://src/presentation/mecha_motion.gd")
const BallLooks := preload("res://src/presentation/ball_looks.gd")
const Tuning := preload("res://src/movement/tuning.gd")
# One pose table per pilot (PILOT-CLIPS section 4.2), by the PILOTS glb stem.
# Pilot return-to-rest clip built at runtime for GLBs with no idle loop, and the blend an impact
# gets when it interrupts another one-shot.
# The rest clip lives in each animator's own library: the GLB's default library is shared by
# every instance and by the bot track switch (bot_options.gd), so it never gains a runtime clip.
const REST_LIBRARY := "runtime"
const REST_CLIP := "runtime/rest_pose"
const REST_LENGTH := 0.5
const INTERRUPT_BLEND := 0.05
const PILOT_TABLES := "res://src/presentation/clips/%s.json"
# The movement chip's signals kick both pedals (PILOT-CLIPS section 5), by argument count.
const MECHA_PEDAL_EVENTS := {"dashed": 1, "boosted": 1, "blink_used": 2, "sprint_started": 1, "rocket_jumped": 2}
const Cosmetics := preload("res://src/core/cosmetics.gd")
const CosmeticWear := preload("res://src/core/cosmetic_wear.gd")
const CosmeticPresentation := preload("res://src/presentation/cosmetic_presentation.gd")
const PILOTS := {
	"runner_gunner": "res://assets/models/pilot_rivet_anim.glb",
	"pylon_engineer": "res://assets/models/pilot_sable_anim.glb",
	"demolitions_caster": "res://assets/models/pilot_kest_anim.glb",
	"tarn": "res://assets/models/pilot_tarn_anim.glb",
	"tally": "res://assets/models/pilot_tally_anim.glb",
	"remembered_cannon": "res://assets/models/pilot_cannon_anim.glb",
}

# VD-01 clear sphere slice. Dresses the greybox in the procedural
# models from tools/blender/ as nodes enter the tree, without editing the gameplay
# scripts that own them: the player's class shell, accretion chunks and the reward
# gate arches. Each placeholder mesh is hidden (render layers cleared, shadow off),
# never deleted, so the gameplay code that builds it stays as it is.
#
# Every glb surface is named for its material slot, and SLOTS below is the one table
# from slot to palette role. `class` and `rarity` resolve per instance: the class row's
# colour and reward_gates.gd rarity_color(). paint, pilot and ancient_enamel carry
# palette colours baked as vertex colours (the test pins paint to the paint roles).
#
# The shell splits the way it moves. Core rolls with the ball under its rolling mesh;
# Pod (the kit and seated pilot) rides the juice node, stays upright and yaws to
# the heading, so the cockpit is always findable (AD-01, AC-01) and Rivet's fins and
# Kest's satchel bands keep their direction. Chunks tuck below the cockpit as they
# roll through it instead of clipping the glass.

const SHELLS := {
	"pylon_engineer": "res://assets/models/world_one/shell_sable.glb",
	"runner_gunner": "res://assets/models/world_one/shell_rivet.glb",
	"demolitions_caster": "res://assets/models/world_one/shell_kest.glb",
	"tarn": "res://assets/models/world_one/shell_tarn.glb",
	"tally": "res://assets/models/world_one/shell_tally.glb",
	"remembered_cannon": "res://assets/models/world_one/shell_cannon.glb",
}
const DEFAULT_CLASS := "pylon_engineer"
const CHUNKS_PATH := "res://assets/models/chunks.glb"
const GATE_PATH := "res://assets/models/reward_gate.glb"
# Accretion slot index bands: a young build carries small scrap, a heavy one large.
const CHUNK_BANDS := [[12, "small"], [24, "medium"], [Accretion.MAX_CHUNKS, "large"]]
# Cosine from straight up where a chunk starts tucking under the pod, and where it is gone.
const TUCK_FROM := -0.15
const TUCK_GONE := 0.30
const POD_TURN_RATE := 10.0
const POD_TURN_SPEED := 1.5
const VANE_RATE := 8.0
# Hoberman weapon ring yaw toward the aim (PILOT-CLIPS section 5, start value).
const WEAPON_RING_RATE := 14.0
# Carrier bank (MOTION-SPEC row 208, start values): the contact normal is smoothed at this rate
# (63 percent in 0.125 s), so the bank never pops on a take or a peel.
const BANK_RATE := 8.0
# Gap-bracket modules that ride the banked carrier (ROSTER-LOOK section 4 'bracket'). Geometry baked into
# the Pod mesh (a seat arm, Cannon's rush ring) stays level with the pod. Cannon's split ports and class V
# hoods are their own meshes (SplitPorts, PortHoods) so they bank, as are Sable's SpoolKit, Tally's
# DrumBrackets, DrumHoods and HeavyDrums, and Tarn's heft-layer claw hooks (ClawHooks).
const BRACKET_PARTS := ["CoilMast", "Exhaust_L", "Exhaust_R", "VaneL", "VaneR", "ClawPivot_L", "ClawPivot_R",
	"ClawTip_L", "ClawTip_R", "ClawLower_L", "ClawLower_R", "ClawUpper_L", "ClawUpper_R", "Flywheel_L",
	"Flywheel_R", "FlywheelAxis_L", "FlywheelAxis_R", "SplitExit_L", "SplitExit_R", "RushContact",
	"SplitPorts", "PortHoods", "SpoolKit", "DrumBrackets", "DrumHoods", "HeavyDrums", "ClawHooks"]
# The shell's air-factor cue: a flat ring on the pod, in the row's colour and shape, that swells
# out on the rise and draws in on the return (a different motion from juice.gd's shell pulse,
# which means heft). No overlay: it is a mesh under the pod.
const AIR_CUE_ROW := "shell_air_shift"
const AIR_CUE_SECONDS := 0.45
const AIR_CUE_RISE := [0.9, 1.9]
const AIR_CUE_RETURN := [1.9, 0.9]
const AIR_CUE_RADIUS := 0.62
const AIR_CUE_NAME := "AirCue"

# An equipped paint lerps the paint surfaces' baked vertex colour this far toward its tint,
# so a dark lattice takes the hue instead of only darkening (PAINT-TRACE card A2, start value).
const PAINT_TAKE := 0.6
# Vertex alpha 0 keeps a part's baked colour under any paint; alpha at or above 0.05 takes full paint, so Tally's window-index alphas (0.2 to 0.8) are unchanged.
# Plate maps average darker than the old neutral value noise; the paint slot lifts once.
const PAINT_LIFT := 1.2
const PAINT_SHADER := """shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 paint_tint : source_color = vec4(1.0);
uniform vec4 lift : source_color = vec4(1.0);
uniform float paint_take = 0.0;
uniform sampler2D plate_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 local_pos;
varying vec3 local_normal;
void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}
vec3 painted(vec3 vertex_color, float mask, vec3 pos, vec3 normal) {
	vec3 weights = abs(normalize(normal));
	weights /= max(weights.x + weights.y + weights.z, 0.001);
	vec3 p = pos / 1.5;
	vec3 plate = texture(plate_texture, p.yz).rgb * weights.x
		+ texture(plate_texture, p.xz).rgb * weights.y
		+ texture(plate_texture, p.xy).rgb * weights.z;
	return mix(vertex_color * lift.rgb, paint_tint.rgb, paint_take * step(0.05, mask)) * plate;
}
"""

const SLOTS := {
	"paint": {"color": Color.WHITE, "vertex": true, "rough": 0.8},
	"bare_metal": {"color": Palette.SAND, "lighten": 0.25, "metal": 0.6, "rough": 0.45},
	"rubber": {"color": Palette.CHARCOAL, "rough": 0.95},
	"class_accent": {"from": "class", "emit": 0.5, "rough": 0.5},
	"field": {"color": Palette.ARC, "emit": 1.6, "rough": 0.4},
	"glass": {"color": Color.WHITE, "alpha": 0.10, "rough": 0.04},
	"pilot": {"color": Color.WHITE, "vertex": true, "rough": 0.9},
	"fleet_paint": {"color": Palette.RUST, "rough": 0.8},
	"requisition_tag": {"color": Palette.BRASS, "metal": 0.5, "rough": 0.4},
	"ancient_enamel": {"color": Color.WHITE, "vertex": true, "rough": 0.72},
	"ancient_light": {"color": Palette.ANCIENT, "emit": 2.4, "rough": 0.3},
	# The mind body's own seam surfaces (KF7): one finger goes out per chunk lost, the thumb last.
	"ancient_light_seam0": {"color": Palette.ANCIENT, "emit": 2.4, "rough": 0.3},
	"ancient_light_seam1": {"color": Palette.ANCIENT, "emit": 2.4, "rough": 0.3},
	"ancient_light_seam2": {"color": Palette.ANCIENT, "emit": 2.4, "rough": 0.3},
	"ancient_light_seam3": {"color": Palette.ANCIENT, "emit": 2.4, "rough": 0.3},
	"ancient_light_thumb": {"color": Palette.ANCIENT, "emit": 2.4, "rough": 0.3},
	"ancient_light_knuckle": {"color": Palette.ANCIENT, "emit": 2.4, "rough": 0.3},
	"ancient_light_lens": {"color": Palette.ANCIENT, "emit": 2.4, "rough": 0.3},
	# Hoberman hubs, pivot pins, studs and the lap bar: its own slot so an equipped paint never
	# tints copper (ROSTER-LOOK section 6).
	"copper": {"color": Palette.COPPER, "metal": 0.6, "rough": 0.4},
	# KF7d round 4: hydraulic rams keep their vertex colours without paint or wear.
	"hydraulic": {"color": Color.WHITE, "vertex": true, "metal": 0.4, "rough": 0.35},
	# Warden mantle working throat: hazard, lit by the Warden's charge_fraction (see _update_mantle).
	"mantle_tool": {"color": Palette.HAZARD, "emit": 0.0, "rough": 0.5},
	"rarity": {"from": "rarity", "emit": 1.4, "rough": 0.5},
}

var ctx
# Frames left before the Warden stroke prewarm, once the boot card is gone; -1 when it is done or not owed.
var _prewarm_wait := -1
# The profile whose equipped paint colours the player's shell; null means no paint anywhere.
var profile = null
var _materials := {}
var _scenes := {}
var _meshes := {}
var _players := {}
var _wardens := {}
var _warden_fragments: Array[MeshInstance3D] = []
var _mast := {}
var _tucked: Array[MeshInstance3D] = []
var _warned := {}
var _reaction_clock := 0.0
var _reaction_connections: Array = []
var _pilot_tables := {}
# The last pressure_changed value, for the machinery rows that read pressure.
var _pressure := 0.0


static func topper_name(rarity: String) -> String:
	return "Topper_" + rarity


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	if ctx != null and ctx.get("profile") != null:
		profile = ctx.get("profile")
	name = "HeroAssets"
	_connect_pilot_events()
	_connect_shell_events()
	_prewarm_strokes_in_time()
	_dress_bay.call_deferred()
	if ctx != null and ctx.player != null:
		attach_player(ctx.player)
	if ctx != null and ctx.get("build") != null and ctx.build.has_signal("shell_air_changed"):
		ctx.build.shell_air_changed.connect(air_cue)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_node("WardenLook"):
			_dress_warden.call_deferred(enemy)
	if ctx != null:
		var cosmetics := CosmeticPresentation.new()
		add_child(cosmetics)
		cosmetics.setup(ctx, self)


func _enter_tree() -> void:
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	for connection in _reaction_connections:
		if is_instance_valid(connection.bus) and connection.bus.is_connected(connection.event, connection.callback):
			connection.bus.disconnect(connection.event, connection.callback)
	_reaction_connections.clear()
	for rec in _wardens.values():
		_restore_warden(rec)
	_wardens.clear()
	_restore_mast()
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var parent := node.get_parent()
	if parent == null:
		return
	if node.get_script() == WardenLook or node.get_script() == WardenKit:
		_dress_warden.call_deferred(parent)
	elif node is MeshInstance3D and parent.get_script() == Accretion:
		dress_chunk(node)
	elif node is Node3D and parent.get_script() == RewardGates:
		_dress_gate.call_deferred(node)


# --- materials ---------------------------------------------------------------------

func material(slot: String, tint := Color.WHITE) -> Material:
	var key := "%s:%s" % [slot, tint.to_html()]
	if _materials.has(key):
		return _materials[key]
	if slot == "glass":
		var glass := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = """shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
void fragment() {
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
	// Reflection lives at the edge: a rough, low-specular face-on lobe keeps the sun from
	// landing as a hotspot on the forehead, and the edge term carries the sky tint.
	ALBEDO = vec3(0.86, 0.94, 1.0);
	ALPHA = 0.05 + edge * 0.22;
	ROUGHNESS = 0.32;
	SPECULAR = 0.08 + edge * 0.5;
}
"""
		glass.shader = shader
		glass.resource_name = slot
		_materials[key] = glass
		return glass
	if slot == "paint" and tint != Color.WHITE:
		var painted := ShaderMaterial.new()
		painted.shader = _paint_shader("paint", PAINT_SHADER + """void fragment() {
	ALBEDO = painted(COLOR.rgb, COLOR.a, local_pos, local_normal);
	ROUGHNESS = 0.8;
}
""")
		painted.resource_name = slot
		_paint_parameters(painted, tint)
		_materials[key] = painted
		return painted
	var spec: Dictionary = SLOTS[slot]
	var color: Color = tint if spec.has("from") else spec["color"]
	color = color.lerp(Color.WHITE, spec.get("lighten", 0.0))
	var mat := StandardMaterial3D.new()
	mat.resource_name = slot
	mat.albedo_color = Color(color, spec.get("alpha", 1.0))
	mat.vertex_color_use_as_albedo = spec.get("vertex", false)
	mat.roughness = spec.get("rough", 0.8)
	mat.metallic = spec.get("metal", 0.0)
	if slot == "ancient_enamel":
		# Section 11: cast, seamless petrol with dust in the vertex colours; no plate map.
		mat.albedo_texture = Palette.painted_texture(128)
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * 2.0
		Palette.enamel_wear(mat)
	if slot in ["paint", "pilot", "bare_metal", "fleet_paint"]:
		# Look pass 3: broad painted material groups. Plate for hulls and Warden armor,
		# the worn variant for old fleet repairs, riveted gyro metal for bare metal.
		var map := ""
		var metres := 1.5
		match slot:
			"paint":
				map = "rusted-salvaged-plate"
			"fleet_paint":
				map = "rusted-salvaged-plate-worn"
			"bare_metal":
				map = "riveted-gyro-metal"
				metres = 0.8
		if map != "":
			mat.albedo_texture = Palette.look_texture(map, true)
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3.ONE / metres
			# Plate maps average darker than the old neutral value noise; lift them once here
			# instead of tinting twice.
			if slot == "paint":
				mat.albedo_color = Color(PAINT_LIFT, PAINT_LIFT, PAINT_LIFT, mat.albedo_color.a)
		else:
			mat.albedo_texture = Palette.painted_texture(128)
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3.ONE * 2.0
	# The plate maps carry their own wear; the old detail-mask oxide would double it.
	if spec.has("alpha"):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.metallic_specular = 0.65
		mat.cull_mode = BaseMaterial3D.CULL_BACK
	if spec.get("emit", 0.0) > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = spec["emit"]
	_materials[key] = mat
	# A Warden body paints its own copies of these slots, and only the copies ever draw. BaseMaterial3D frees a shader
	# with its last material, so the stage swap that freed the dam Warden's copies took the shader too, and the flume
	# Warden's first copy built it again on its first surface: 12-15 ms of the flume entry frame on the 4080 (scrapkeep#512).
	# The shared slot holds the shader for the run, and the enamel's lit twin holds the hit flash's (emission on).
	if slot.begins_with("ancient_light") or slot == "ancient_enamel":
		mat.get_rid()
	if slot == "ancient_enamel" and not mat.emission_enabled:
		var lit: StandardMaterial3D = mat.duplicate()
		lit.emission_enabled = true
		lit.get_rid()
		_materials[key + ":lit"] = lit
	return mat


static func slot_of(mesh: Mesh, surface: int) -> String:
	var mat := mesh.surface_get_material(surface)
	return mat.resource_name if mat != null else ""


# Metadata keeps surface materials alive until after the rendering instance is freed.
static func _surface_material(view: MeshInstance3D, surface: int, mat: Material) -> void:
	view.set_surface_override_material(surface, mat)
	var held: Dictionary = view.get_meta("hero_surface_materials", {})
	held[surface] = mat
	view.set_meta("hero_surface_materials", held)


# Paints every surface under root from SLOTS. tints: {"class": Color, "rarity": Color}.
func paint(root: Node, tints: Dictionary) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var slot := slot_of(mi.mesh, i)
				if not SLOTS.has(slot):
					_warn_once(slot, "hero_assets: unknown material slot '%s'" % slot)
					continue
				var from: String = SLOTS[slot].get("from", "")
				if slot == "paint":
					from = "paint"
				_surface_material(mi, i, material(slot, tints.get(from, Color.WHITE)))
				if slot == "glass":
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func hide_placeholder(mi: GeometryInstance3D) -> void:
	mi.layers = 0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# A scene held for the presentation's life: nothing else keeps a GLB's PackedScene, so a bare load() reads it from disk
# again every time (a Warden body, 8-25 ms, on every stage entry and retry).
func _packed(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	return _scenes[path] as PackedScene


func _scene(path: String) -> Node:
	var packed := _packed(path)
	if packed == null:
		_warn_once("scene:" + path, "hero_assets: scene '%s' unavailable; keeping primitive fallback" % path)
		return null
	return packed.instantiate()


# The mesh of the named node in a glb, loaded once.
func mesh_named(path: String, node_name: String) -> Mesh:
	var key := path + "#" + node_name
	if not _meshes.has(key):
		var scene := _scene(path)
		if scene == null:
			return null
		var found := scene.find_child(node_name, true, false) as MeshInstance3D
		_meshes[key] = found.mesh if found != null else null
		scene.free()
	return _meshes[key]


func _warn_once(key: String, text: String) -> void:
	if not _warned.has(key):
		_warned[key] = true
		push_warning(text)


# --- the player's shell ------------------------------------------------------------

func attach_player(player: Node3D) -> void:
	var rolling := player.roll_node().get_parent() as MeshInstance3D
	_players[player.get_instance_id()] = {"player": player, "class": "", "core": null, "pod": null,
		"layers": rolling.layers, "shadow": rolling.cast_shadow}
	_fit(_players[player.get_instance_id()])
	for chunk in player.roll_node().get_children():
		if chunk.get_script() == Accretion:
			for child in chunk.get_children():
				if child is MeshInstance3D:
					dress_chunk(child)


static func class_id(player: Node) -> String:
	var def = player.get("class_def")
	return def.id if def != null and SHELLS.has(def.id) else DEFAULT_CLASS


# The tint an equipped paint gives a pilot's shell, or null for none. A paint applies only
# when its row is a paint for this pilot (or any) with a tint, and the profile owns it or the
# row is a starter. Anything else warns once per id and leaves the shell as it is.
func paint_tint(pilot: String, paint_id: String):
	var row: Dictionary = Cosmetics.row(paint_id)
	var why := ""
	if paint_id == "":
		why = "no id"
	elif row.is_empty():
		why = "unknown id"
	elif row.get("slot", "") != "paint":
		why = "not a paint slot"
	elif row.get("pilot", "") != "" and row.get("pilot", "") != pilot:
		why = "belongs to another pilot"
	elif not row.has("tint"):
		why = "no tint"
	elif profile != null and not (row.get("starter", false) or profile.has_cosmetic(paint_id)):
		why = "not owned"
	if why != "":
		_warn_once("paint:" + paint_id, "hero_assets: paint '%s' ignored (%s)" % [paint_id, why])
		return null
	return row["tint"]


func _equipped_paint(id: String) -> String:
	return CosmeticWear.worn(profile, id, "paint")


# The equipped shell variant's asset id for a pilot, or "" for the default cage.
func _equipped_variant(id: String) -> String:
	var worn := CosmeticWear.worn(profile, id, "shell")
	return String(Cosmetics.row(worn).get("asset", "")) if worn != "" else ""


func _worn_tints(player: Node, tint) -> Dictionary:
	var tints := {"class": player.class_color()}
	if tint != null:
		tints["paint"] = tint
	return tints


# The shell the player wears right now (pilot, variant, paint, heft class), fitted under ball
# for a preview such as the pause menu's build read. Pass back the record it returned last time:
# the same pilot, variant and paint only update the heft class; anything else refits. {} when
# even the default base is unavailable (the caller keeps its own stand-in).
func fit_worn_into(ball: Node3D, player: Node, rec := {}) -> Dictionary:
	var id := class_id(player)
	var paint_id := _equipped_paint(id)
	var tint = paint_tint(id, paint_id) if paint_id != "" else null
	var variant := _equipped_variant(id)
	var look := [id, variant, tint]
	if not rec.is_empty() and rec.get("worn") == look and is_instance_valid(rec.core):
		set_heft_class(rec, _run_heft_class(), false)
		_glow_rec(rec, _ready_glow)
		return rec
	for key in ["core", "pod"]:
		var old = rec.get(key)
		if old != null and is_instance_valid(old):
			old.get_parent().remove_child(old)
			old.queue_free()
	var shell := fit_shell_into(ball, id, variant, _run_heft_class(), _worn_tints(player, tint))
	if not shell.is_empty():
		shell["worn"] = look
	return shell


func _run_heft_class() -> int:
	var run = ctx.get("run") if ctx != null else null
	if run != null and run.has_method("heft_class"):
		return maxi(1, int(run.heft_class()))
	return 1


func _fit(rec: Dictionary) -> void:
	var player: Node3D = rec["player"]
	var id := class_id(player)
	var paint_id := _equipped_paint(id)
	var tint = paint_tint(id, paint_id) if paint_id != "" else null
	var variant := _equipped_variant(id)
	if rec["class"] == id and rec.get("tint") == tint and rec.get("variant", "") == variant:
		return
	for key in ["core", "pod"]:
		var old = rec[key]
		if old != null and is_instance_valid(old):
			old.get_parent().remove_child(old)
			old.queue_free()
		rec[key] = null
	rec["animator"] = null
	rec["shell"] = {}
	rec["class"] = id
	rec["tint"] = tint
	rec["variant"] = variant
	var rolling := player.roll_node().get_parent() as MeshInstance3D
	rolling.layers = rec.layers
	rolling.cast_shadow = rec.shadow
	var tints := _worn_tints(player, tint)
	var shell := fit_shell_into(rolling, id, variant, _run_heft_class(), tints, player.pod_mount() if player.has_method("pod_mount") else player.juice_node())
	if shell.is_empty():
		return
	hide_placeholder(rolling)
	rec["shell"] = shell
	rec["core"] = shell.core
	rec["pod"] = shell.pod
	_fit_pilot(rec)
	if rec.get("pilot") != null and profile != null:
		var outfit := CosmeticWear.worn(profile, id, "outfit")
		if outfit != "":
			fit_outfit(rec.pilot, outfit, tints)


func _process(delta: float) -> void:
	if _prewarm_wait >= 0:
		_step_prewarm()
	_reaction_clock += delta
	for key in _players.keys():
		var rec: Dictionary = _players[key]
		var player = rec["player"]
		if not is_instance_valid(player):
			_players.erase(key)
			continue
		_fit(rec)
		_steer_pod(rec, player, delta)
		_step_mecha(rec, player, delta)
	_tuck_chunks()
	for key in _wardens.keys():
		var rec: Dictionary = _wardens[key]
		if not is_instance_valid(rec.warden) or not rec.warden.is_inside_tree():
			_restore_warden(rec)
			_wardens.erase(key)
		else:
			_update_warden(rec)


# The ring for one change of the resolved air factor, on the player's pod (every attached
# player). The row decides colour and shape; `rose` decides only the direction of the swell.
func air_cue(_factor: float, rose: bool) -> Node3D:
	var row: Dictionary = EventKinds.ROWS.get(AIR_CUE_ROW, EventKinds.WORLD_ROWS.get(AIR_CUE_ROW, {}))
	var made: Node3D = null
	for rec in _players.values():
		var pod = rec["pod"]
		if pod == null or not is_instance_valid(pod):
			continue
		for old in pod.get_children():
			if old.name == AIR_CUE_NAME:
				pod.remove_child(old)
				old.queue_free()
		var ring := MeshInstance3D.new()
		ring.name = AIR_CUE_NAME
		var torus := TorusMesh.new()
		torus.inner_radius = AIR_CUE_RADIUS * 0.86
		torus.outer_radius = AIR_CUE_RADIUS
		ring.mesh = torus
		var mat := StandardMaterial3D.new()
		var color: Color = row.get("color", Palette.AMBER)
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.set_meta("rose", rose)
		ring.set_meta("shape", String(row.get("shape", "")))
		var span: Array = AIR_CUE_RISE if rose else AIR_CUE_RETURN
		ring.scale = Vector3.ONE * float(span[0])
		pod.add_child(ring)
		var tween := ring.create_tween()
		tween.set_parallel(true)
		tween.tween_property(ring, "scale", Vector3.ONE * float(span[1]), AIR_CUE_SECONDS).set_ease(Tween.EASE_OUT)
		tween.tween_property(mat, "albedo_color:a", 0.0, AIR_CUE_SECONDS).from(0.85)
		tween.chain().tween_callback(ring.queue_free)
		made = ring
	return made


func _steer_pod(rec: Dictionary, player, delta: float) -> void:
	var pod: Node3D = rec["pod"]
	if pod == null:
		return
	var v: Vector3 = player.state.velocity
	var flat := Vector2(v.x, v.z)
	if flat.length() > POD_TURN_SPEED:
		var want := atan2(-v.x, -v.z)
		pod.rotation.y = lerp_angle(pod.rotation.y, want, 1.0 - exp(-POD_TURN_RATE * delta))
	var gyro := pod.get_node_or_null("Gyro") as Node3D
	var core = rec["core"]
	if gyro != null and gyro.has_node("GyroInner") and core != null and is_instance_valid(core):
		counter_tilt(pod, gyro, core)
	elif gyro != null and v.length() > 0.01:
		# Motion comes from the real velocity; the pilot remains on the upright Pod.
		gyro.rotate_object_local(Vector3.RIGHT, v.length() * delta / 0.98)
	sync_lattice(core, player.roll_node())
	BallLooks.ride(ball_look(), player.roll_node())
	var open := 1.0 if player.kit.gliding else 0.0
	var kest := {}
	if rec["class"] == "demolitions_caster" and ctx != null and ctx.spawner != null and ctx.spawner.get("ultimate") != null:
		kest = ctx.spawner.ultimate.kest_cage_state()
		open = float(kest["vent_angle"]) / (PI * 0.5)
	for vane_name in ["VaneL", "VaneR"]:
		var vane := pod.find_child(vane_name, true, false) as Node3D
		if vane != null:
			var side := -1.0 if vane_name == "VaneL" else 1.0
			vane.rotation.z = lerpf(vane.rotation.z, -side * open * PI * 0.5, 1.0 - exp(-VANE_RATE * delta))
	if not kest.is_empty():
		var paint_tint: Color = rec.get("shell", {}).get("tints", {}).get("paint", Color.WHITE)
		apply_kest_state(pod, kest, paint_tint)
	steer_weapon_ring(pod, _aim_of(v), delta)
	var kit = player.kit
	if kit.get("hooked") == true:
		steer_fairlead(pod, kit.anchor, delta)
	else:
		# A cable ride: the carriage turns to the trolley clamp the hanger leaves for.
		var view = get_parent().get("line_view") if get_parent() != null else null
		if view != null and view.hanger.visible:
			steer_fairlead(pod, view.hanger_to, INF if view.hanger_fresh else delta)
	# Draw only: the face under the ball, or world up in the air.
	var face: Vector3 = player.state.get("contact_normal") if player.state.get("grounded") == true else Vector3.UP
	player.set_meta("carrier_bank", update_carrier_bank(pod, face, delta))


func apply_kest_state(pod: Node3D, state: Dictionary, paint_tint := Color.WHITE) -> void:
	var ring := pod.get_node_or_null("WeaponRing") as MeshInstance3D
	if ring != null:
		for i in ring.mesh.get_surface_count():
			if slot_of(ring.mesh, i) == "paint":
				_surface_material(ring, i, kest_band_material(paint_tint))
		ring.set_instance_shader_parameter("lit_count", int(state["lit_count"]))
		ring.set_instance_shader_parameter("heft_class", int(state["heft_class"]))
	var mortar := pod.get_node_or_null("WeaponRing/Mortar") as MeshInstance3D
	if mortar != null:
		if not mortar.has_meta("kest_rest"):
			mortar.set_meta("kest_rest", mortar.position)
		mortar.position = mortar.get_meta("kest_rest") + Vector3.BACK * float(state["mortar_recoil"])
		mortar.rotation.x = -float(state["mortar_pitch"])
		for i in mortar.mesh.get_surface_count():
			if slot_of(mortar.mesh, i) == "class_accent":
				_surface_material(mortar, i, kest_fuse_material(bool(state["fuse_boost"])))
		mortar.set_instance_shader_parameter("fuse_glow", float(state["fuse_glow"]))
		mortar.set_instance_shader_parameter("fuse_loaded", bool(state["fuse_blink"]))


func kest_band_material(tint: Color) -> ShaderMaterial:
	var key := "kest_bands:" + tint.to_html()
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	# PD-KEST stores band index in UV2.x and the fourth satchel's class gate in UV2.y.
	mat.shader = _paint_shader("kest_bands", PAINT_SHADER + """uniform vec4 class_color : source_color = vec4(1.0);
instance uniform int lit_count = 0;
instance uniform int heft_class = 1;
void fragment() {
	if (UV2.y > float(heft_class) + 0.1) { discard; }
	ALBEDO = painted(COLOR.rgb, COLOR.a, local_pos, local_normal);
	ROUGHNESS = 0.8;
	if (UV2.x > 0.5) {
		bool lit = UV2.x <= float(lit_count) + 0.1;
		ALBEDO *= lit ? 1.0 : 0.35;
		EMISSION = lit ? class_color.rgb * 0.5 : vec3(0.0);
	}
}
""")
	mat.resource_name = "kest_bands"
	_paint_parameters(mat, tint)
	mat.set_shader_parameter("class_color", ClassDef.KEST_COLOR)
	_materials[key] = mat
	return mat


# One shader per paint use, shared by every tint, so a new paint adds a material, not a shader.
func _paint_shader(use: String, code: String) -> Shader:
	var key := "shader:" + use
	if not _materials.has(key):
		var shader := Shader.new()
		shader.code = code
		_materials[key] = shader
	return _materials[key]


# White is no paint: the plain lift over the vertex colour, as the StandardMaterial3D draws it.
static func _paint_parameters(mat: ShaderMaterial, tint: Color) -> void:
	var lift := Color(PAINT_LIFT, PAINT_LIFT, PAINT_LIFT)
	mat.set_shader_parameter("paint_tint", Color(PAINT_LIFT * tint.r, PAINT_LIFT * tint.g, PAINT_LIFT * tint.b))
	mat.set_shader_parameter("lift", lift)
	mat.set_shader_parameter("paint_take", PAINT_TAKE if tint != Color.WHITE else 0.0)
	mat.set_shader_parameter("plate_texture", Palette.look_texture("rusted-salvaged-plate", true))


func kest_fuse_material(bright: bool) -> ShaderMaterial:
	var key := "kest_fuse_ready" if bright else "kest_fuse"
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
uniform vec4 class_color : source_color = vec4(1.0);
uniform float strength = 0.5;
instance uniform float fuse_glow = 0.2;
instance uniform bool fuse_loaded = false;
varying float tip_side;
void vertex() { tip_side = VERTEX.x; }
void fragment() {
	ALBEDO = class_color.rgb;
	ROUGHNESS = 0.5;
	float glow = fuse_loaded && tip_side < 0.0 ? 0.0 : fuse_glow;
	EMISSION = class_color.rgb * strength * glow;
}
"""
	mat.shader = shader
	mat.resource_name = key
	mat.set_shader_parameter("class_color", ClassDef.KEST_COLOR)
	mat.set_shader_parameter("strength", READY_EMIT if bright else 0.5)
	_materials[key] = mat
	return mat


# Hoberman gimbal (ROSTER-LOOK section 2): the rings show the lattice's turn against the upright
# pod. The outer ring (Gyro) pivots on the pod's left-right axis by the lattice's pitch, the inner
# ring (Gyro > GyroInner) on its top-bottom bosses by the next turn, so both follow the tumble.
static func counter_tilt(pod: Node3D, gyro: Node3D, core: Node3D) -> void:
	if not pod.is_inside_tree() or not gyro.is_inside_tree() or not core.is_inside_tree():
		return
	var rel := (pod.global_basis.orthonormalized().inverse() * core.global_basis.orthonormalized()).get_euler(EULER_ORDER_XYZ)
	gyro.rotation = Vector3(rel.x, 0.0, 0.0)
	(gyro.get_node("GyroInner") as Node3D).rotation = Vector3(0.0, rel.y, 0.0)


# Chunks clamp onto the lattice only while the ball wears a Hoberman shell (its Core carries the
# Hub.00 empty); every Accretion under the roll node follows the shell the player wears now.
static func sync_lattice(core, roll: Node) -> void:
	var on: bool = core != null and is_instance_valid(core) and core.has_node("Hub_00")
	for child in roll.get_children():
		if child.get_script() == Accretion and child.lattice != on:
			child.set_lattice(on)


# Where the weapon ring points: the shot's aim (context.aim_forward, the lens rest), or the
# travel direction when no camera aims (stub players, tools).
func _aim_of(velocity: Vector3) -> Vector3:
	if ctx != null and ctx.get("camera") != null:
		return ctx.aim_forward()
	return velocity


# Hoberman shells (PILOT-CLIPS section 5): Pod > WeaponRing stays level under the upright pod
# and yaws to the aim at WEAPON_RING_RATE, independent of the pod's turn to the heading, so the
# weapon points where the shot goes. A shell without the ring is left alone.
func steer_weapon_ring(pod: Node3D, aim: Vector3, delta: float) -> void:
	var ring := pod.get_node_or_null("WeaponRing") as Node3D
	if ring == null or not ring.is_inside_tree():
		return
	var pz := pod.global_basis.z
	var rz := (pod.global_basis * _level(pod, ring)).z
	var yaw := weapon_ring_yaw(atan2(rz.x, rz.z), aim, delta)
	var turn := Basis(Vector3.UP, wrapf(yaw - atan2(pz.x, pz.z), -PI, PI))
	ring.basis = _bank_local(pod) * turn


# The Fairlead carriage (MOTION-SPEC swing row): a level carrier node on the collar that turns
# to the anchor's planar direction and holds its last yaw when the anchor is overhead. RopeExit
# rides it at LineView.FAIRLEAD_RADIUS, so the drawn rope and the model agree. Physics is untouched.
static func add_fairlead(pod: Node3D) -> Node3D:
	var carriage := pod.get_node_or_null("Fairlead") as Node3D
	if carriage != null:
		return carriage
	carriage = Node3D.new()
	carriage.name = "Fairlead"
	pod.add_child(carriage)
	var exit := pod.find_child("RopeExit", true, false) as Node3D
	if exit != null:
		exit.reparent(carriage, false)
		exit.position = Vector3(0.0, 0.0, -LineView.FAIRLEAD_RADIUS)
		exit.rotation = Vector3.ZERO
	return carriage


func steer_fairlead(pod: Node3D, anchor: Vector3, delta: float) -> void:
	if not pod.is_inside_tree():
		return
	var carriage := pod.get_node_or_null("Fairlead") as Node3D
	if carriage == null:
		return
	var pz := pod.global_basis.z
	var cz := (pod.global_basis * _level(pod, carriage)).z
	var yaw := LineView.fairlead_yaw(atan2(cz.x, cz.z), pod.global_position, anchor, delta)
	var turn := Basis(Vector3.UP, wrapf(yaw - atan2(pz.x, pz.z), -PI, PI))
	carriage.basis = _bank_local(pod) * turn


# --- carrier bank (MOTION-SPEC row 208) ------------------------------------------------------
#
# The WeaponRing, the Fairlead carriage and the bracket modules (BRACKET_PARTS, under the
# CarrierBank holder) share one bank: Basis(UP x normal, angle) about the pod's centre, the smallest
# angle that keeps their furthest reach along the smoothed contact normal at CarrierBank.LIMIT.
# Order: the aim yaw (or the fairlead's) is applied first, and the bank tilts the yawed carrier,
# so child = bank x yaw. The ring still turns to the aim on its bearing; the bank only leans it.
# The pod, the pilot and the gimbal rings stay level (Animation drives the gimbal from
# carrier_bank, row 207). Nothing here touches physics.

# The bank last drawn, in the pod's frame; the identity until update_carrier_bank runs.
static func _bank_local(pod: Node3D) -> Basis:
	return pod.get_meta("bank_local", Basis.IDENTITY)


# A carrier's basis with the drawn bank taken out: its pod-frame yaw alone.
static func _level(pod: Node3D, carrier: Node3D) -> Basis:
	return (_bank_local(pod).inverse() * carrier.basis).orthonormalized()


# The carrier bank in world space: a rotation about a horizontal axis that tilts the carrier's
# up toward the face. Identity on a floor and in the air. Read it for anything that rides the carrier.
static func carrier_bank(pod: Node3D) -> Basis:
	var local := _bank_local(pod)
	if not pod.is_inside_tree():
		return local
	var p := pod.global_basis.orthonormalized()
	return p * local * p.inverse()


# Every CarrierBank holder under the pod: the base shell's and each heft layer's (HeftC<n> > Pod >
# CarrierBank). With `visible_only`, a hidden layer's is left out.
static func _holders(pod: Node3D, visible_only := true) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var base := pod.get_node_or_null("CarrierBank") as Node3D
	if base != null:
		out.append(base)
	for layer in pod.get_children():
		if not String(layer.name).begins_with("HeftC") or not layer is Node3D or (visible_only and not (layer as Node3D).visible):
			continue
		for sub in layer.get_children():
			var holder := sub.get_node_or_null("CarrierBank") as Node3D
			if holder != null and (not visible_only or (sub as Node3D).visible):
				out.append(holder)
	return out


# The pod-frame transform of a node's parent chain below the pod (what a holder's points ride).
static func _frame_in(pod: Node3D, node: Node3D) -> Transform3D:
	var frame := Transform3D.IDENTITY
	var at := node.get_parent() as Node3D
	while at != null and at != pod:
		frame = _rest_transform(at) * frame
		at = at.get_parent() as Node3D
	return frame


# A node's transform with its `heft_rest` position in place of where a slam or fling has it now. The
# layer's own Pod mesh slams too (rest 0, so it moves up), and it is the parent of the layer's holder.
static func _rest_transform(node: Node3D) -> Transform3D:
	var local := node.transform
	if node.has_meta("heft_rest"):
		local.origin = node.get_meta("heft_rest")
	return local


# Which heft layers show now: the hull below is only valid for one such state.
static func _bank_key(pod: Node3D) -> String:
	var key := ""
	var ring := pod.get_node_or_null("WeaponRing")
	for scope in [pod, ring]:
		if scope == null:
			continue
		for child in scope.get_children():
			if String(child.name).begins_with("HeftC") and child is Node3D:
				key += "1" if (child as Node3D).visible else "0"
	return key


# Hull points of the ring (in the ring's frame, at yaw 0) and of the bracket modules (in the pod's
# frame), of the parts that show now: the convex hull holds every furthest point. Rebuilt when a
# heft layer appears or goes, so a hidden layer never banks the carrier.
static func _bank_hull(pod: Node3D, visible_only := true) -> Dictionary:
	var key := _bank_key(pod) if visible_only else "all"
	if visible_only and pod.has_meta("bank_hull") and pod.get_meta("bank_hull")["key"] == key:
		return pod.get_meta("bank_hull")
	var ring := pod.get_node_or_null("WeaponRing") as Node3D
	var brackets := PackedVector3Array()
	for holder in _holders(pod, visible_only):
		var frame := _frame_in(pod, holder)
		for v in _points_under(holder, holder, true, visible_only):
			brackets.append(frame * v)
	var hull := {"key": key,
		"ring": CarrierBank.hull(_points_under(ring, ring, false, visible_only)) if ring != null else PackedVector3Array(),
		"brackets": CarrierBank.hull(brackets)}
	if visible_only:
		pod.set_meta("bank_hull", hull)
	return hull


# Mesh vertices (and node origins when `origins`) under `node`, in `top`'s frame; a hidden
# child's subtree is left out when `visible_only`.
# A heft layer's mesh is read at its `heft_rest` position, not where a slam or fling has it now, so
# a hull built mid-tween (and cached until the next visibility change) still holds the settled shape.
static func _points_under(node: Node3D, top: Node3D, origins: bool, visible_only := true, to := Transform3D.IDENTITY) -> PackedVector3Array:
	var out := PackedVector3Array()
	var here := to if node == top else to * _rest_transform(node)
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			for v in mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
				out.append(here * v)
	elif origins and node != top:
		out.append(here.origin)
	for child in node.get_children():
		if child is Node3D and not (visible_only and not (child as Node3D).visible):
			out.append_array(_points_under(child, top, origins, visible_only, here))
	return out


# The holder that carries the bracket modules, so one transform banks them all and their own
# rotations (vanes, claws) stay theirs. A part a shell lacks is skipped.
static func add_bracket_carrier(pod: Node3D) -> Node3D:
	var holder := pod.get_node_or_null("CarrierBank") as Node3D
	if holder != null:
		return holder
	holder = Node3D.new()
	holder.name = "CarrierBank"
	pod.add_child(holder)
	for part_name in BRACKET_PARTS:
		var part := pod.get_node_or_null(part_name) as Node3D
		if part != null:
			part.reparent(holder, false)
	return holder


# One frame: smooth the face normal, find the bank, and pose the ring, the fairlead carriage and
# the bracket holder under it. `normal` is the contact normal on the ground and world up in the air.
# Returns the world bank (carrier_bank).
static func update_carrier_bank(pod: Node3D, normal: Vector3, delta: float) -> Basis:
	if not pod.is_inside_tree():
		return Basis.IDENTITY
	var smoothed := CarrierBank.smooth(pod.get_meta("bank_normal", Vector3.UP), normal, delta, BANK_RATE)
	pod.set_meta("bank_normal", smoothed)
	var carriers: Array[Node3D] = []
	for carrier_name in ["WeaponRing", "Fairlead"]:
		var c := pod.get_node_or_null(carrier_name) as Node3D
		if c != null:
			carriers.append(c)
	var ring := pod.get_node_or_null("WeaponRing") as Node3D
	var yaw := 0.0
	if ring != null:
		var z := _level(pod, ring).z
		yaw = atan2(z.x, z.z)
	var p := pod.global_basis.orthonormalized()
	var face := p.inverse() * smoothed
	var hull := _bank_hull(pod)
	var solved := CarrierBank.solve(hull["ring"], yaw, hull["brackets"], face)
	var angle: float = solved["angle"]
	var residual := 0.0 if solved["clears"] else maxf(0.0, float(solved["reach"]) - CarrierBank.LIMIT)
	pod.set_meta("bank_residual", residual)
	if residual <= 0.0:
		pod.remove_meta("bank_warned")
	elif CarrierBank.UP.cross(face).length() >= CarrierBank.FLAT and (not pod.has_meta("bank_warned") or pod.get_meta("bank_warned") != hull["key"]):
		pod.set_meta("bank_warned", hull["key"])
		push_warning("hero_assets: no carrier bank clears the %.2f m limit (%.3f m over) for hull %s" % [CarrierBank.LIMIT, residual, hull["key"]])
	var bank := CarrierBank.basis_for(face, angle)
	var levels: Array[Basis] = []
	for c in carriers:
		levels.append(_level(pod, c))
	pod.set_meta("bank_local", bank)
	for i in carriers.size():
		carriers[i].basis = bank * levels[i]
	for holder in _holders(pod, false):
		holder.basis = bank
	return p * bank * p.inverse()


# One step of the ring's world yaw toward aim; a vertical or empty aim holds it.
static func weapon_ring_yaw(yaw: float, aim: Vector3, delta: float) -> float:
	if Vector2(aim.x, aim.z).length_squared() < 0.0001:
		return yaw
	return lerp_angle(yaw, atan2(-aim.x, -aim.z), 1.0 - exp(-WEAPON_RING_RATE * delta))


# The shell the player wears, for tests and tools: {class, core, pod} or {}.
func shell_of(player: Node) -> Dictionary:
	return _players.get(player.get_instance_id(), {})


# --- shell variants and heft layers (design-v3/CUSTOMIZE.md section 6) ----------------
#
# One loader path for a pilot's shell: the base (class 1) and its four detail layers
# (classes 2 to 5), by variant. The pilot body is a Hoberman mecha; heft fills the lattice
# gaps with panels, so a layer is a detail shell shown up to the heft class. Layers load once
# at fit and only toggle visibility during a run; _fit's swap frees them with their pair.

const HEFT_LAYERS := [2, 3, 4, 5]
const HEFT_SLAM_FROM := 0.10
const HEFT_SLAM_SECONDS := 0.18
const HEFT_STAGGER := 0.06
const HEFT_FLING_SECONDS := Accretion.FLING_SECONDS
# A node named Replace_<name> (the importer turns "Replace.<name>" into this) hides <name>.
const REPLACE_PREFIXES := ["Replace_", "Replace."]
const READY_EMIT := 1.6
const DECOR_SPOT := Vector3(-12.6, 1.2, 1.8)

# Asset id -> path for variants and add-ons; a key equal to a pilot id overrides that pilot's
# default base (tests). Read lazily so a painter that never fits a variant never reads the registry.
var shell_assets := {}
var _shell_assets_read := false
# Every warning this painter printed, once each, for tests and tools.
var warning_log: Array[String] = []
var _ready_glow := false


func _assets() -> Dictionary:
	if not _shell_assets_read and shell_assets.is_empty():
		shell_assets = Cosmetics.asset_paths()
		shell_assets.merge(BallLooks.asset_paths(ball_look(), SHELLS.keys()), true)
	_shell_assets_read = true
	return shell_assets


# The ball look the launch asked for (--ball-look, ball_looks.gd); "today" without a tuning.
func ball_look() -> String:
	var tuning = ctx.get("tuning") if ctx != null else null
	return tuning.option(Tuning.BALL_LOOK_KEY) if tuning != null else BallLooks.TODAY


static func _layer_path(base: String, heft_class: int) -> String:
	return "%s_c%d.%s" % [base.get_basename(), heft_class, base.get_extension()]


# The one lookup: the GLB for a pilot's shell, by variant and heft class. Class 1 is the base;
# classes 2 to 5 are its detail layers, named <base>_c<N>.glb. variant "" is the pilot's
# default (SHELLS); otherwise it is a shell row's asset id, resolved through paths
# (Cosmetics.asset_paths(), or a test's own map). "" for an unknown pilot, variant or class.
static func shell_path(pilot: String, variant: String, heft_class: int, paths: Dictionary) -> String:
	if not SHELLS.has(pilot) or heft_class < 1 or heft_class > 5:
		return ""
	var base := ""
	if variant == "":
		base = String(paths.get(pilot, SHELLS[pilot]))
	else:
		var row := Cosmetics.row(variant)
		if not row.is_empty() and (row.get("slot", "") != "shell" or row.get("pilot", "") != pilot):
			return ""
		if not paths.has(variant):
			return ""
		base = String(paths[variant])
		if heft_class > 1 and paths.has("%s_c%d" % [variant, heft_class]):
			return String(paths["%s_c%d" % [variant, heft_class]])
	return base if heft_class == 1 else _layer_path(base, heft_class)


func _loadable(path: String) -> bool:
	if path == "":
		return false
	if _scenes.has(path):
		return _scenes[path] != null
	return ResourceLoader.exists(path)


func _warn_logged(key: String, text: String) -> void:
	if not _warned.has(key):
		warning_log.append(text)
	_warn_once(key, text)


# The five paths a fit loads, index 0 the base, after the fallback rules: a missing variant
# base shows the default base and layers; a missing variant layer borrows the default layer
# for that class (the armour read never vanishes for a cosmetic); a missing default layer
# shows nothing for that class; a missing default base leaves index 0 "".
func shell_layers(pilot: String, variant: String, paths: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var use := variant
	if use != "" and not _loadable(shell_path(pilot, use, 1, paths)):
		_warn_logged("shell_variant:" + use, "hero_assets: shell variant '%s' unavailable for %s; showing the default shell" % [use, pilot])
		use = ""
	var base := shell_path(pilot, use, 1, paths)
	out.append(base if _loadable(base) else "")
	for n in HEFT_LAYERS:
		# A ball look is one shell with no heft layers yet; nothing is missing, so nothing warns.
		if BallLooks.is_look(base):
			out.append("")
			continue
		var path := shell_path(pilot, use, n, paths)
		if use != "" and not _loadable(path):
			_warn_logged("shell_layer:%s:%d" % [use, n], "hero_assets: shell variant '%s' lacks its class %d layer; borrowing the default" % [use, n])
			path = shell_path(pilot, "", n, paths)
		if not _loadable(path):
			_warn_logged("shell_default_layer:%s:%d" % [pilot, n], "hero_assets: %s has no class %d layer; nothing shows for it" % [pilot, n])
			path = ""
		out.append(path)
	return out


# Removes and frees every Light3D under a scene that is still outside the tree, so the
# renderer never pairs a light with a node a slot will free (CUSTOMIZE.md section 2, rule 3).
func _strip_lights(root: Node, source: String) -> int:
	var lights: Array[Node] = []
	if root is Light3D:
		lights.append(root)
	lights.append_array(root.find_children("*", "Light3D", true, false))
	for light in lights:
		if light == root:
			continue
		light.get_parent().remove_child(light)
		light.free()
	if not lights.is_empty():
		_warn_logged("light:" + source, "hero_assets: '%s' ships %d light node(s); stripped" % [source, lights.size()])
	return lights.size()


# An add-on scene, instanced outside the tree with its lights stripped, or null.
func _addon(path: String) -> Node:
	if path == "":
		return null
	var node := _scene(path)
	if node != null:
		_strip_lights(node, path)
	return node


static func _replace_target(node_name: String) -> String:
	for prefix in REPLACE_PREFIXES:
		if node_name.begins_with(prefix):
			return node_name.substr(prefix.length())
	return ""


# Shows or hides the base nodes the Replace_ nodes under source name, searching scope. A hidden
# node keeps living (kit code reads it); its layers mask is saved and restored. Counted, so two
# sources replacing one node restore it only when both hide.
static func apply_replacements(scope: Node, source: Node, on: bool) -> int:
	var changed := 0
	var stack: Array[Node] = [source]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var target_name := _replace_target(String(node.name))
		if target_name == "":
			continue
		var target := _find_outside(scope, target_name, source)
		if target == null:
			continue
		var visuals: Array[Node] = [target]
		visuals.append_array(target.find_children("*", "VisualInstance3D", true, false))
		var count := int(target.get_meta("replace_count", 0))
		if on:
			target.set_meta("replace_count", count + 1)
			if count > 0:
				continue
			for v in visuals:
				if v is VisualInstance3D and not v.has_meta("replace_layers"):
					v.set_meta("replace_layers", v.layers)
					v.layers = 0
		else:
			if count <= 0:
				continue
			target.set_meta("replace_count", count - 1)
			if count > 1:
				continue
			for v in visuals:
				if v is VisualInstance3D and v.has_meta("replace_layers"):
					v.layers = int(v.get_meta("replace_layers"))
					v.remove_meta("replace_layers")
		changed += 1
	return changed


static func _find_outside(scope: Node, node_name: String, exclude: Node) -> Node:
	var stack: Array[Node] = [scope]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == exclude:
			continue
		if String(node.name) == node_name:
			return node
		stack.append_array(node.get_children())
	return null


# Moves a scene's Core and Pod parts out of it; {} when either is missing. Frees the rest.
static func _split(scene: Node) -> Dictionary:
	var core := scene.find_child("Core", true, false) as Node3D
	var pod := scene.find_child("Pod", true, false) as Node3D
	if core == null or pod == null:
		scene.free()
		return {}
	core.get_parent().remove_child(core)
	pod.get_parent().remove_child(pod)
	scene.free()
	add_fairlead(pod)
	add_bracket_carrier(pod)
	return {"core": core, "pod": pod}


# Builds the shell under ball: HeroCore and HeroPod plus one holder per layer, painted with
# tints, layers shown up to heft_class. pod_parent receives HeroPod (the player's level pod mount);
# null puts it under ball (previews). The game's _fit, the class card preview and the customize
# preview all call it. Returns {core, pod, layers: {2: {core, pod}, ...}, variant, heft} or {}
# when even the default base is unavailable.
func fit_shell_into(ball: Node3D, pilot: String, variant: String, heft_class: int, tints: Dictionary, pod_parent: Node3D = null) -> Dictionary:
	var paths := _assets()
	var layers := shell_layers(pilot, variant, paths)
	if layers[0] == "":
		return {}
	var base := _addon(layers[0])
	if base == null:
		return {}
	var parts := _split(base)
	if parts.is_empty():
		_warn_once("scene:" + layers[0], "hero_assets: scene '%s' lacks Core/Pod; keeping primitive fallback" % layers[0])
		return {}
	var core: Node3D = parts.core
	var pod: Node3D = parts.pod
	core.name = "HeroCore"
	pod.name = "HeroPod"
	BallLooks.replate(ball_look(), core)
	var rec := {"core": core, "pod": pod, "layers": {}, "variant": variant, "heft": 1, "shown": {}, "tints": tints}
	var ring_holders: Array = []
	for i in HEFT_LAYERS.size():
		var n: int = HEFT_LAYERS[i]
		var core_holder := Node3D.new()
		core_holder.name = "HeftC%d" % n
		var pod_holder := Node3D.new()
		pod_holder.name = "HeftC%d" % n
		var layer := _addon(layers[i + 1])
		if layer != null:
			var layer_parts := _split(layer)
			if layer_parts.is_empty():
				_warn_logged("layer_split:" + layers[i + 1], "hero_assets: layer '%s' lacks Core/Pod; nothing shows for it" % layers[i + 1])
			else:
				for key in ["core", "pod"]:
					var part: Node3D = layer_parts[key]
					part.transform = Transform3D.IDENTITY
					if key == "core":
						BallLooks.replate(ball_look(), part, n)
					else:
						BallLooks.strip(ball_look(), part)
					(core_holder if key == "core" else pod_holder).add_child(part)
				# A layer's WeaponRing rides the base ring, so a heft module turns with the aim;
				# its holder shows and hides with the layer's Pod holder.
				var layer_ring := (layer_parts.pod as Node3D).get_node_or_null("WeaponRing") as Node3D
				var base_ring := pod.get_node_or_null("WeaponRing") as Node3D
				if layer_ring != null and base_ring != null:
					var ring_holder := Node3D.new()
					ring_holder.name = "HeftC%d" % n
					ring_holder.visible = false
					layer_ring.get_parent().remove_child(layer_ring)
					ring_holder.add_child(layer_ring)
					base_ring.add_child(ring_holder)
					SignalLifetime.listen(ring_holder, pod_holder.visibility_changed, func(): ring_holder.visible = pod_holder.visible)
					ring_holders.append([pod_holder, ring_holder])
		for holder in [core_holder, pod_holder]:
			holder.visible = false
			for mi in holder.find_children("*", "MeshInstance3D", true, false):
				mi.set_meta("heft_rest", (mi as Node3D).position)
		core.add_child(core_holder)
		pod.add_child(pod_holder)
		rec.layers[n] = {"core": core_holder, "pod": pod_holder}
		rec.shown[n] = false
	paint(core, tints)
	paint(pod, tints)
	ball.add_child(core)
	(pod_parent if pod_parent != null else ball).add_child(pod)
	set_heft_class(rec, heft_class, false)
	# visibility_changed fires only inside the tree; a fit outside it syncs here.
	for pair in ring_holders:
		pair[1].visible = pair[0].visible
	# Every caller's shell wears the look's own materials: the game, the pause read, the previews.
	BallLooks.dress(ball_look(), rec)
	if _ready_glow:
		_glow_rec(rec, true)
	return rec


# Shows layers up to heft_class; animates the change when animate is true. Class up: each new
# holder shows and its meshes slam in from HEFT_SLAM_FROM outward. Class down: each lost
# holder's meshes fling outward, then the holder hides and the meshes return to rest.
func set_heft_class(rec: Dictionary, heft_class: int, animate := true) -> void:
	if rec.is_empty():
		return
	rec["heft"] = heft_class
	var stagger := 0
	for n in HEFT_LAYERS:
		var want: bool = n <= heft_class
		if bool(rec.shown.get(n, false)) == want:
			continue
		rec.shown[n] = want
		var pair: Dictionary = rec.layers[n]
		for key in ["core", "pod"]:
			var holder: Node3D = pair[key]
			if not is_instance_valid(holder):
				continue
			var scope: Node = rec.core if key == "core" else rec.pod
			var old = holder.get_meta("heft_tween") if holder.has_meta("heft_tween") else null
			if old is Tween and old.is_valid():
				old.kill()
			_rest(holder)
			if want:
				holder.visible = true
				apply_replacements(scope, holder, true)
				if animate and holder.is_inside_tree():
					_slam(holder, stagger * HEFT_STAGGER)
			else:
				apply_replacements(scope, holder, false)
				if animate and holder.is_inside_tree():
					_fling(holder)
				else:
					holder.visible = false
		stagger += 1


static func _rest(holder: Node3D) -> void:
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta("heft_rest"):
			(mi as Node3D).position = mi.get_meta("heft_rest")


static func _outward(mi: Node3D) -> Vector3:
	var rest: Vector3 = mi.get_meta("heft_rest", mi.position)
	var dir := rest.normalized() if rest.length() > 0.001 else Vector3.UP
	return dir


# Tweens run on the holder, so a refit that frees the holder ends them. Position only: a fade
# would need a per-instance material.
func _slam(holder: Node3D, delay: float) -> void:
	var meshes := holder.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return  # No layer art yet: an empty tween would log "started with no Tweeners".
	var tween := holder.create_tween().set_parallel(true)
	for mi in meshes:
		var rest: Vector3 = mi.get_meta("heft_rest", (mi as Node3D).position)
		(mi as Node3D).position = rest + _outward(mi) * HEFT_SLAM_FROM
		tween.tween_property(mi, "position", rest, HEFT_SLAM_SECONDS).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	holder.set_meta("heft_tween", tween)


func _fling(holder: Node3D) -> void:
	var meshes := holder.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		holder.visible = false
		return
	var tween := holder.create_tween()
	tween.set_parallel(true)
	for mi in meshes:
		var rest: Vector3 = mi.get_meta("heft_rest", (mi as Node3D).position)
		tween.tween_property(mi, "position", rest + _outward(mi) * 0.6, HEFT_FLING_SECONDS).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		holder.visible = false
		_rest(holder))
	holder.set_meta("heft_tween", tween)


func _on_heft_class(heft_class: int, _heft: float) -> void:
	for rec in _players.values():
		var shell = rec.get("shell", {})
		if shell is Dictionary and not shell.is_empty() and is_instance_valid(rec.get("core")):
			set_heft_class(shell, heft_class, true)


# The ready glow (SKILL-BAR asks the cage's machinery to glow when the ultimate is ready):
# every class_accent surface swaps between two cached materials per class colour. No light.
func ready_material(tint: Color) -> Material:
	var key := "class_accent_ready:%s" % tint.to_html()
	if _materials.has(key):
		return _materials[key]
	var base := material("class_accent", tint) as StandardMaterial3D
	var mat := base.duplicate() as StandardMaterial3D
	mat.resource_name = "class_accent_ready"
	mat.emission_energy_multiplier = READY_EMIT
	_materials[key] = mat
	return mat


func _glow_rec(rec: Dictionary, on: bool) -> int:
	var swapped := 0
	var tint: Color = rec.get("tints", {}).get("class", Color.WHITE)
	var calm := material("class_accent", tint)
	var lit := ready_material(tint)
	for root in [rec.get("core"), rec.get("pod")]:
		if root == null or not is_instance_valid(root):
			continue
		var meshes: Array[Node] = [root]
		meshes.append_array(root.find_children("*", "MeshInstance3D", true, false))
		for mi in meshes:
			if not (mi is MeshInstance3D) or mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				var current: Material = mi.get_surface_override_material(i)
				if on and current == calm:
					_surface_material(mi, i, lit)
					swapped += 1
				elif not on and current == lit:
					_surface_material(mi, i, calm)
					swapped += 1
				elif current != null and current.resource_name in ["kest_fuse", "kest_fuse_ready"]:
					var fuse := kest_fuse_material(on)
					if current != fuse:
						_surface_material(mi, i, fuse)
						swapped += 1
	return swapped


func set_ready_glow(on: bool) -> void:
	_ready_glow = on
	for rec in _players.values():
		var shell = rec.get("shell", {})
		if shell is Dictionary and not shell.is_empty():
			_glow_rec(shell, on)


# Connects a callback to a bus signal only when it is declared, whatever its argument count.
func _connect_optional(bus: Object, signal_name: String, callback: Callable) -> void:
	if bus == null or not bus.has_signal(signal_name):
		return
	for info in bus.get_signal_list():
		if String(info.name) == signal_name:
			var bound := callback.unbind(info.args.size()) if info.args.size() > 0 else callback
			bus.connect(signal_name, bound)
			_reaction_connections.append({"bus": bus, "event": signal_name, "callback": bound})
			return


func _connect_shell_events() -> void:
	if ctx == null or ctx.events == null:
		return
	var bus = ctx.events
	if bus.has_signal("heft_class_changed") and not bus.is_connected("heft_class_changed", _on_heft_class):
		bus.connect("heft_class_changed", _on_heft_class)
		_reaction_connections.append({"bus": bus, "event": "heft_class_changed", "callback": _on_heft_class})
	if bus.has_signal("heft_class_dropped") and not bus.is_connected("heft_class_dropped", _on_heft_class):
		bus.connect("heft_class_dropped", _on_heft_class)
		_reaction_connections.append({"bus": bus, "event": "heft_class_dropped", "callback": _on_heft_class})
	# The skill bar unit lands these later; connect only when declared (CUSTOMIZE.md section 9).
	_connect_optional(bus, "ultimate_ready", set_ready_glow.bind(true))
	_connect_optional(bus, "ultimate_started", set_ready_glow.bind(false))
	_connect_optional(bus, "ultimate_cancelled", set_ready_glow.bind(false))


# --- add-ons: outfits and bay decoration (CUSTOMIZE.md section 6) ----------------------

func _addon_path(id: String, slot: String) -> String:
	var row := Cosmetics.row(id)
	if row.is_empty() or row.get("slot", "") != slot or not row.has("asset"):
		return ""
	var path := String(_assets().get(row["asset"], ""))
	if path == "" or not _loadable(path):
		_warn_logged("addon:" + id, "hero_assets: %s '%s' has no delivered art; showing the default look" % [slot, id])
		return ""
	return path


# Mounts an outfit on the pilot's Skeleton3D: one BoneAttachment3D per top-level outfit node,
# named for its bone. Lights stripped, painted from the cache, Replace_ applied on the pilot.
# Removes any outfit already worn. Returns the attachments (empty for "" or missing art).
func fit_outfit(pilot_node: Node3D, id: String, tints := {}) -> Array:
	return fit_outfit_scene(pilot_node, _addon_path(id, "outfit") if id != "" else "", tints)


# The same mount from a scene path (tools and tests with fixture outfits).
func fit_outfit_scene(pilot_node: Node3D, path: String, tints := {}) -> Array:
	remove_outfit(pilot_node)
	var outfit := _addon(path)
	if outfit == null:
		return []
	return _mount_on_bones(pilot_node, outfit, tints, "outfit")


func remove_outfit(pilot_node: Node3D) -> void:
	_remove_bone_mounts(pilot_node, "outfit")


func _mount_on_bones(scope: Node3D, scene: Node, tints: Dictionary, kind: String) -> Array:
	var found := scope.find_children("*", "Skeleton3D", true, false)
	var skeleton: Skeleton3D = found[0] if not found.is_empty() else null
	var mounts: Array = []
	if skeleton == null:
		_warn_logged("%s:no_skeleton" % kind, "hero_assets: no Skeleton3D to mount the %s on" % kind)
		scene.free()
		return mounts
	paint(scene, tints)
	# glTF import renames a node "upper_arm.L" to "upper_arm_L"; match parts by that name.
	var bone_of := {}
	for i in skeleton.get_bone_count():
		bone_of[skeleton.get_bone_name(i).validate_node_name()] = skeleton.get_bone_name(i)
	for part in scene.get_children():
		var bone := String(bone_of.get(String(part.name), part.name))
		if part is AnimationPlayer or skeleton.find_bone(bone) < 0:
			continue
		scene.remove_child(part)
		var attach := BoneAttachment3D.new()
		attach.name = "%s_%s" % [kind.capitalize(), bone]
		attach.bone_name = bone
		attach.set_meta("addon", kind)
		attach.add_child(part)
		skeleton.add_child(attach)
		mounts.append(attach)
	for mount in mounts:
		apply_replacements(scope, mount, true)
	# An optional AnimationPlayer rides the skeleton; its clips address parts as
	# "<Kind>_<bone>/<part>" and share the pilot's clip names, so react() plays both.
	var player := scene.find_child("AnimationPlayer", false, false) as AnimationPlayer
	if player != null and not mounts.is_empty():
		_retarget_clips(player, mounts)
		scene.remove_child(player)
		player.name = "%sAnimator" % kind.capitalize()
		player.set_meta("addon", kind)
		player.root_node = NodePath("..")
		skeleton.add_child(player)
		mounts.append(player)
	scene.free()
	return mounts


# Imported clips address parts from the GLB root ("head/HoodShell"). After the mount each part
# sits under its attachment, so its tracks gain the attachment's name. Copies, never the cache.
func _retarget_clips(player: AnimationPlayer, mounts: Array) -> void:
	var under := {}
	for mount in mounts:
		under[String(mount.get_child(0).name)] = String(mount.name)
	for lib_name in player.get_animation_library_list():
		var lib := AnimationLibrary.new()
		var source := player.get_animation_library(lib_name)
		for clip in source.get_animation_list():
			var anim := source.get_animation(clip).duplicate() as Animation
			for i in anim.get_track_count():
				var path := String(anim.track_get_path(i))
				var top := path.get_slice("/", 0).get_slice(":", 0)
				if under.has(top):
					anim.track_set_path(i, NodePath(under[top] + "/" + path))
			lib.add_animation(clip, anim)
		player.remove_animation_library(lib_name)
		player.add_animation_library(lib_name, lib)


func _remove_bone_mounts(scope: Node3D, kind: String) -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for skeleton in scope.find_children("*", "Skeleton3D", true, false):
		for child in skeleton.get_children():
			if child.get_meta("addon", "") == kind:
				if child is BoneAttachment3D:
					apply_replacements(scope, child, false)
				skeleton.remove_child(child)
				child.queue_free()


# Mounts the equipped bay decoration in Moss's workshop at its DecorSpot, else DECOR_SPOT.
# One item at a time; adds no light. Returns the mounted node or null.
func fit_bay_decor(workshop: Node3D, id: String) -> Node3D:
	if workshop == null:
		return null
	for child in workshop.get_children():
		if child.get_meta("addon", "") == "bay_decor":
			workshop.remove_child(child)
			child.queue_free()
	var path := _addon_path(id, "bay_decor") if id != "" else ""
	var decor := _addon(path) as Node3D
	if decor == null:
		return null
	decor.name = "BayDecor"
	decor.set_meta("addon", "bay_decor")
	paint(decor, {"class": Palette.AMBER})
	var spot := workshop.find_child("DecorSpot", true, false) as Node3D
	decor.position = workshop.to_local(spot.global_position) if spot != null and spot.is_inside_tree() else (spot.position if spot != null else DECOR_SPOT)
	workshop.add_child(decor)
	return decor


# Mounts a companion skin on SPIL-9: top-level parts named Hull or Deck ride those bones.
func fit_companion_skin(model: Node3D, id: String) -> Array:
	_remove_bone_mounts(model, "companion_skin")
	var path := _addon_path(id, "companion_skin") if id != "" else ""
	var skin := _addon(path)
	if skin == null:
		return []
	return _mount_on_bones(model, skin, {"class": Palette.AMBER}, "companion_skin")


# --- cosmetic pilot reactions ------------------------------------------------------
#
# design-v3/PILOT-CLIPS.md sections 1.1 and 3. A row's clip cuts in over a strictly lower
# priority; when a clip ends the pilot goes back to a base loop (idle_loop, or ult_ride_loop
# while the set piece holds the ride) instead of a bone reset. A GLB without idle_loop keeps
# the old stop and reset and warns once per pilot. Code moves the mecha (mecha_motion.gd).

func _fit_pilot(rec: Dictionary) -> void:
	rec["mecha"] = MechaMotion.new(rec.pod, rec.core, rec["class"], Array(_pilot_table(rec["class"]).get("machinery", [])))
	var fitted := fit_pilot_into(rec.pod, rec["class"], rec.player.class_color())
	if fitted.is_empty():
		return
	var pilot: Node3D = fitted.pilot
	var animator = fitted.get("animator")
	rec["animator"] = animator
	rec["pilot"] = pilot
	rec["reaction"] = ""
	rec["priority"] = -1
	rec["cooldowns"] = {}
	rec["queued"] = {}
	rec["base"] = ""
	rec["blend"] = 0.0
	# Trap 1: a pilot GLB without an AnimationPlayer has nothing to seat.
	if animator is AnimationPlayer:
		animator.animation_finished.connect(_pilot_finished.bind(rec.player.get_instance_id(), animator))
		_to_base(rec)


# Seats the class's animated pilot in a pod: hides the shell's embedded placeholder pilot,
# adds the pilot glb as "AnimatedPilot" and paints it in the class colour. The game's
# _fit_pilot and the class card's preview both call it. Returns {pilot, animator}, or {}
# when the class has no pilot or its scene is unavailable; animator is null when the GLB
# carries no AnimationPlayer.
func fit_pilot_into(pod: Node3D, class_id: String, class_color: Color) -> Dictionary:
	if not PILOTS.has(class_id):
		return {}
	var pilot := _scene(PILOTS[class_id]) as Node3D
	if pilot == null:
		return {}
	pilot.name = "AnimatedPilot"
	var placeholder := pod.find_child("Pilot", true, false) as GeometryInstance3D
	if placeholder != null:
		hide_placeholder(placeholder)
	pod.add_child(pilot)
	paint(pilot, {"class": class_color})
	var animator := pilot.find_child("AnimationPlayer", true, false) as AnimationPlayer
	return {"pilot": pilot, "animator": animator}


# The pilot's pose table (src/presentation/clips/<pilot>.json, PILOT-CLIPS section 4.3), or {}
# while the pilot has none. The stem comes from the PILOTS glb name.
func _pilot_table(class_id: String) -> Dictionary:
	if _pilot_tables.has(class_id):
		return _pilot_tables[class_id]
	var table := {}
	var stem := String(PILOTS.get(class_id, "")).get_file().trim_prefix("pilot_").trim_suffix("_anim.glb")
	var path := PILOT_TABLES % stem
	if stem != "" and FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			table = parsed
		else:
			_warn_once("pilot_table:" + class_id, "hero_assets: pose table %s does not parse; no contact frames or machinery" % path)
	_pilot_tables[class_id] = table
	return table


func _connect_pilot_events() -> void:
	if ctx == null or ctx.events == null or not _reaction_connections.is_empty():
		return
	# Trap 2: ultimate_started carries five arguments.
	var handlers := [_pilot_event_0, _pilot_event_1, _pilot_event_2, _pilot_event_3, _pilot_event_4, _pilot_event_5]
	for info in ctx.events.get_signal_list():
		var event := String(info.name)
		if PilotReactions.rows_for(event).is_empty():
			continue
		if info.args.size() >= handlers.size():
			_warn_once("pilot_event:" + event, "hero_assets: %s carries %d arguments; no pilot handler" % [event, info.args.size()])
			continue
		var callback: Callable = handlers[info.args.size()].bind(event)
		ctx.events.connect(event, callback)
		_reaction_connections.append({"bus": ctx.events, "event": event, "callback": callback})
	var mecha_events := {"shot_fired": _mecha_event.bind("shot").unbind(3),
		"ultimate_started": _mecha_event.bind("ultimate_started").unbind(5),
		"ultimate_landed": _mecha_event.bind("ultimate_ended").unbind(4),
		"ultimate_cancelled": _mecha_event.bind("ultimate_ended").unbind(3),
		"landed": _mecha_event.bind("landed").unbind(1),
		"pressure_changed": _on_pressure_changed}
	for event in MECHA_PEDAL_EVENTS:
		mecha_events[event] = _mecha_event.bind("kick").unbind(MECHA_PEDAL_EVENTS[event])
	for event in mecha_events:
		if ctx.events.has_signal(event):
			ctx.events.connect(event, mecha_events[event])
			_reaction_connections.append({"bus": ctx.events, "event": event, "callback": mecha_events[event]})


func _pilot_event_0(event: String) -> void:
	_on_pilot_event(event, [])


func _pilot_event_1(a, event: String) -> void:
	_on_pilot_event(event, [a])


func _pilot_event_2(a, b, event: String) -> void:
	_on_pilot_event(event, [a, b])


func _pilot_event_3(a, b, c, event: String) -> void:
	_on_pilot_event(event, [a, b, c])


func _pilot_event_4(a, b, c, d, event: String) -> void:
	_on_pilot_event(event, [a, b, c, d])


func _pilot_event_5(a, b, c, d, e, event: String) -> void:
	_on_pilot_event(event, [a, b, c, d, e])


func _on_pilot_event(event: String, args: Array) -> void:
	for rec in _players.values():
		if is_instance_valid(rec.player):
			react(rec.player, event, args)


# Returns acceptance for tests and capture tools. Never writes to the player. `event` is a bus
# signal: the first of its rows whose argument filter passes decides.
func react(player: Node, event: String, args: Array = []) -> bool:
	var ids := PilotReactions.rows_for(event)
	if ids.is_empty() and PilotReactions.ROWS.has(event):
		ids = [event]
	for row_id in ids:
		var row: Dictionary = PilotReactions.ROWS[row_id]
		if row.get("pending", false) or not PilotReactions.arg_matches(row, args):
			continue
		return _react_row(player, row)
	return false


func _react_row(player: Node, row: Dictionary) -> bool:
	var rec := shell_of(player)
	if rec.is_empty() or not is_instance_valid(rec.get("animator")):
		return false
	var clip := PilotReactions.clip_for(row, rec["class"])
	var animator: AnimationPlayer = rec.animator
	if not animator.has_animation(clip):
		_note_clip(clip, true)
		return false
	if _reaction_clock < float(rec.cooldowns.get(clip, 0.0)):
		return false
	if int(row.priority) <= int(rec.priority):
		_offer_queue(rec, row, clip)
		return false
	rec.cooldowns[clip] = _reaction_clock + float(row.cooldown)
	_start_reaction(rec, clip, int(row.priority), float(row.get("blend", 0.0)))
	return true


# Section 3 rule 3: a queue row that lost on priority waits in the one slot when the playing
# clip has at most its row's seconds left and the set piece is idle. A later queued row of at
# least the held priority replaces it.
func _offer_queue(rec: Dictionary, row: Dictionary, clip: String) -> void:
	if not row.has("queue") or rec.reaction == "" or _riding(rec):
		return
	var animator: AnimationPlayer = rec.animator
	if animator.current_animation_length - animator.current_animation_position > float(row.queue):
		return
	var held: Dictionary = rec.queued
	if not held.is_empty() and int(held.priority) > int(row.priority):
		return
	rec.queued = {"clip": clip, "priority": int(row.priority), "blend": float(row.get("blend", 0.0)),
		"cooldown": float(row.cooldown)}


# Impact clips cut in with no blend so the authored recoil shows in its first frames; status
# clips ease in by their row's blend.
func _start_reaction(rec: Dictionary, clip: String, priority: int, blend: float, apply := true) -> void:
	rec.reaction = clip
	rec.priority = priority
	rec.base = ""
	_play(rec, clip, blend, apply)
	var mecha = rec.get("mecha")
	if mecha != null and clip in MechaMotion.CAST_CLIPS:
		var contact := _contact_of(rec, clip)
		if not contact.is_empty():
			mecha.cast(clip, contact.control, contact.seconds)
	# A worn outfit's clip with the same name plays on the same trigger (Rivet's hood snaps down).
	var pilot_node = rec.get("pilot")
	if pilot_node != null and is_instance_valid(pilot_node):
		for outfit_player in pilot_node.find_children("OutfitAnimator", "AnimationPlayer", true, false):
			if outfit_player.has_animation(clip):
				outfit_player.play(clip, blend)


func _play(rec: Dictionary, clip: String, blend: float, apply := true) -> void:
	var animator: AnimationPlayer = rec.animator
	# An impact that interrupts another one-shot (wince over big_cheer's raised arms) gets a
	# short blend so the whole arm range does not jump in one frame; over a base loop it still cuts.
	if blend <= 0.0 and animator.is_playing() and animator.current_animation != clip \
			and animator.current_animation not in [PilotReactions.BASES.idle.clip, PilotReactions.BASES.flight.clip, REST_CLIP]:
		blend = INTERRUPT_BLEND
	animator.play(clip, blend)
	if apply:
		animator.advance(0.0)
	rec.blend = blend
	_note_clip(clip)


# The cast's control and its contact time: the pose table's contact (frame E at 30 fps), else
# the class's bank control at 40 percent of the clip (PILOT-CLIPS section 10), warned once.
func _contact_of(rec: Dictionary, clip: String) -> Dictionary:
	var table := _pilot_table(rec["class"])
	var contact: Dictionary = table.get("clips", {}).get(clip, {}).get("contact", {})
	if contact.has("control") and contact.has("frame"):
		var fps := float(table.get("fps", 30))
		return {"control": String(contact.control), "seconds": maxf(0.0, (float(contact.frame) - 1.0) / fps)}
	var control := MechaMotion.cast_control(rec["class"], clip)
	if control == "":
		return {}
	var pilot := String(PILOTS.get(rec["class"], "")).get_file().trim_prefix("pilot_").trim_suffix("_anim.glb")
	var seconds: float = 0.4 * rec.animator.get_animation(clip).length
	_warn_once("contact:%s:%s" % [rec["class"], clip], "hero_assets: pilot %s class %s has no pose-table contact for %s in %s; control %s falls back to %.3fs at 40 percent" % [pilot, rec["class"], clip, PILOT_TABLES % pilot, control, seconds])
	return {"control": control, "seconds": seconds}


func _pilot_finished(clip: StringName, player_id: int, animator: AnimationPlayer) -> void:
	var rec: Dictionary = _players.get(player_id, {})
	if rec.is_empty() or rec.animator != animator:
		return
	if String(clip) == REST_CLIP:
		return
	var riding := _riding(rec)
	# Section 3 rule 2: a ride pose never snaps to rest.
	if String(clip) in PilotReactions.ENDS_ON_RIDE and not riding and animator.has_animation(PilotReactions.RECOVER.clip):
		rec.queued = {}
		_start_reaction(rec, PilotReactions.RECOVER.clip, int(PilotReactions.RECOVER.priority), 0.0, false)
		return
	var held: Dictionary = rec.queued
	rec.queued = {}
	if not held.is_empty() and not riding and animator.has_animation(held.clip) \
			and _reaction_clock >= float(rec.cooldowns.get(held.clip, 0.0)):
		rec.cooldowns[held.clip] = _reaction_clock + float(held.cooldown)
		_start_reaction(rec, held.clip, int(held.priority), float(held.blend), false)
		return
	_to_base(rec, true)


# Section 3 rule 1: the base loop from frame 0 with a 0.1 s blend, ult_ride_loop while the set
# piece holds the ride, else idle_loop. Without the loop (today's GLBs): stop, reset every bone
# to rest, and warn once per pilot.
func _to_base(rec: Dictionary, after_clip := false) -> void:
	rec.reaction = ""
	rec.queued = {}
	var animator = rec.get("animator")
	if not is_instance_valid(animator):
		rec.priority = -1
		return
	var base: Dictionary = PilotReactions.BASES.flight if _riding(rec) else PilotReactions.BASES.idle
	if not animator.has_animation(base.clip):
		base = PilotReactions.BASES.idle
	if animator.has_animation(base.clip):
		rec.base = base.clip
		rec.priority = int(base.priority)
		if animator.current_animation != base.clip or not animator.is_playing():
			_play(rec, base.clip, PilotReactions.BASE_BLEND, false)
		return
	_warn_once("pilot_base:" + String(rec["class"]), "hero_assets: pilot %s has no %s; seating by stop and reset" % [rec["class"], base.clip])
	rec.base = ""
	rec.priority = -1
	if after_clip and _play_rest(rec):
		return
	animator.stop()
	for skeleton in rec.pilot.find_children("*", "Skeleton3D", true, false):
		skeleton.reset_bone_poses()


# A pilot GLB with no idle loop eases to its rest pose over BASE_BLEND instead of snapping: a
# runtime clip keys every bone at rest. It is not a pilot clip, so the run log never counts it.
func _play_rest(rec: Dictionary) -> bool:
	var animator: AnimationPlayer = rec.animator
	if not animator.has_animation(REST_CLIP):
		var root := animator.get_node_or_null(animator.root_node)
		if root == null:
			return false
		var library := AnimationLibrary.new()
		var rest := Animation.new()
		rest.length = REST_LENGTH
		for skeleton: Skeleton3D in rec.pilot.find_children("*", "Skeleton3D", true, false):
			var path := String(root.get_path_to(skeleton))
			for bone in skeleton.get_bone_count():
				var pose := skeleton.get_bone_rest(bone)
				var node := NodePath("%s:%s" % [path, skeleton.get_bone_name(bone)])
				for kind in [[Animation.TYPE_POSITION_3D, pose.origin], [Animation.TYPE_ROTATION_3D, pose.basis.get_rotation_quaternion()], [Animation.TYPE_SCALE_3D, pose.basis.get_scale()]]:
					var track := rest.add_track(kind[0])
					rest.track_set_path(track, node)
					rest.track_insert_key(track, 0.0, kind[1])
		library.add_animation(REST_CLIP.get_file(), rest)
		animator.add_animation_library(REST_LIBRARY, library)
	animator.play(REST_CLIP, PilotReactions.BASE_BLEND)
	return true


# The set piece phase from the router's injected callable (SKILL-BAR section 7), else idle.
func _set_piece_phase(rec: Dictionary) -> String:
	var player = rec.get("player")
	if not is_instance_valid(player):
		return "idle"
	var phase = player.get("set_piece_phase")
	if phase is Callable and (phase as Callable).is_valid():
		return String(phase.call())
	return "idle"


func _riding(rec: Dictionary) -> bool:
	return _set_piece_phase(rec) in PilotReactions.RIDE_PHASES


# The run's pilot_clips row (run_log.gd): plays by clip and refusals for a clip the GLB lacks.
func _note_clip(clip: String, missing := false) -> void:
	var run = ctx.get("run") if ctx != null else null
	if run == null:
		return
	var row: Dictionary = run.get_meta("pilot_clips", {})
	if row.is_empty():
		row = {"played": {}, "missing": 0}
		run.set_meta("pilot_clips", row)
	if missing:
		row["missing"] = int(row.get("missing", 0)) + 1
	else:
		var played: Dictionary = row.get("played", {})
		played[clip] = int(played.get(clip, 0)) + 1
		row["played"] = played


# --- mecha motion (mecha_motion.gd) ------------------------------------------------------

func _mecha_event(what: String) -> void:
	for rec in _players.values():
		var mecha = rec.get("mecha")
		if mecha == null or not is_instance_valid(rec.player):
			continue
		match what:
			"shot":
				mecha.shot()
			"kick":
				mecha.kick()
			"ultimate_started":
				mecha.ultimate_started()
			"ultimate_ended":
				mecha.ultimate_ended()
			"landed":
				mecha.landed()


func _on_pressure_changed(pressure: float) -> void:
	_pressure = pressure


func _step_mecha(rec: Dictionary, player, delta: float) -> void:
	var mecha = rec.get("mecha")
	if mecha == null:
		return
	mecha.step(delta, _mecha_facts(rec, player) if mecha.needs_facts() else {})


# The facts the machinery rows read (mecha_motion.gd FACTS), only for a pilot that has rows.
func _mecha_facts(rec: Dictionary, player) -> Dictionary:
	var velocity: Vector3 = player.state.velocity if player.get("state") != null else Vector3.ZERO
	var facts := {"pressure": _pressure, "set_piece_phase": _set_piece_phase(rec), "heft_class": _run_heft_class(),
		"aim": _aim_of(velocity)}
	var kit = player.get("kit")
	if kit != null:
		facts["gliding"] = kit.get("gliding") == true
		facts["cloaked"] = kit.get("cloaked") == true
	var abilities = player.get("abilities")
	if abilities != null:
		facts["selected_slot"] = String(abilities.get("selected")) if abilities.get("selected") != null else ""
		var meter = abilities.get("meter")
		if meter != null:
			facts["meter_fill"] = float(meter.fraction())
		var ready := {}
		for slot in ["weapon", "special", "line"]:
			ready[slot] = bool(abilities.ready(slot))
		facts["slot_ready"] = ready
	var spawner = ctx.get("spawner") if ctx != null else null
	if spawner != null and spawner.has_method("line_load"):
		facts["line_load"] = 0.0 if (spawner.line_load() as Dictionary).is_empty() else 1.0
	return facts


# --- accretion chunks --------------------------------------------------------------

# The chunk's slot index, recovered from where accretion.gd _slot() put it.
static func chunk_index(chunk: Node3D) -> int:
	var y := clampf(chunk.position.y / 1.02, -1.0, 1.0)
	return clampi(roundi((1.0 - y) * Accretion.MAX_CHUNKS / 2.0 - 0.5), 0, Accretion.MAX_CHUNKS - 1)


static func chunk_name(index: int) -> String:
	for band in CHUNK_BANDS:
		if index < band[0]:
			return "chunk_%s_%d" % [band[1], index % 3]
	return "chunk_large_%d" % (index % 3)


func dress_chunk(chunk: MeshInstance3D) -> void:
	if chunk.has_node("HeroChunk"):
		return
	var mesh := mesh_named(CHUNKS_PATH, chunk_name(chunk_index(chunk)))
	if mesh == null:
		return
	hide_placeholder(chunk)
	var hero := MeshInstance3D.new()
	hero.name = "HeroChunk"
	hero.mesh = mesh
	paint(hero, {})
	chunk.add_child(hero)
	_tucked.append(hero)


func _tuck_chunks() -> void:
	var i := _tucked.size() - 1
	while i >= 0:
		var hero := _tucked[i]
		if not is_instance_valid(hero) or not hero.is_inside_tree():
			_tucked.remove_at(i)
			i -= 1
			continue
		var chunk := hero.get_parent() as Node3D
		var accretion := chunk.get_parent() as Node3D
		if accretion != null and accretion.get_script() == Accretion:
			var up := (chunk.global_position - accretion.global_position).normalized().dot(Vector3.UP)
			hero.scale = Vector3.ONE * (1.0 - smoothstep(TUCK_FROM, TUCK_GONE, up))
		else:
			hero.scale = Vector3.ONE
		i -= 1


# --- reward gates ------------------------------------------------------------------

func _dress_gate(gate: Node3D) -> void:
	if not is_instance_valid(gate) or not gate.is_inside_tree() or gate.has_node("HeroArch"):
		return
	var gates := gate.get_parent()
	var rarity := ""
	for offer in gates.offers:
		if (offer["at"] as Vector3).distance_to(gate.global_position) < 0.01:
			rarity = offer["rarity"]
	if rarity == "":
		return
	var arch_mesh := mesh_named(GATE_PATH, "Arch")
	if arch_mesh == null:
		return
	var tints := {"rarity": RewardGates.rarity_color(rarity)}
	var topper := gate.get_node_or_null("Topper") as MeshInstance3D
	for child in gate.get_children():
		if child is MeshInstance3D and child != topper:
			hide_placeholder(child)
	var arch := MeshInstance3D.new()
	arch.name = "HeroArch"
	arch.mesh = arch_mesh
	gate.add_child(arch)
	paint(arch, tints)
	var topper_mesh := mesh_named(GATE_PATH, topper_name(rarity)) if topper != null else null
	if topper != null and topper_mesh != null:
		hide_placeholder(topper)
		for child in topper.get_children():
			if child is GeometryInstance3D:
				hide_placeholder(child)
		var hero_topper := MeshInstance3D.new()
		hero_topper.name = "HeroTopper"
		hero_topper.mesh = topper_mesh
		topper.add_child(hero_topper)
		paint(hero_topper, tints)
	for child in gate.get_children():
		if child is Sprite3D and String(child.name).begins_with("Glyph"):
			var plate_mesh := mesh_named(GATE_PATH, "GlyphPlate1")
			if plate_mesh == null:
				continue
			var plate := MeshInstance3D.new()
			plate.name = "HeroPlate" + String(child.name).trim_prefix("Glyph")
			plate.mesh = plate_mesh
			plate.position = (child as Sprite3D).position + Vector3(0.0, 0.0, -0.14)
			gate.add_child(plate)
			paint(plate, tints)


# --- Warden clamp and family kit ----------------------------------------------------

func warden_of(warden: Node) -> Dictionary:
	return _wardens.get(warden.get_instance_id(), {})


func _warden_scene(path: String) -> Node3D:
	var packed := _packed(path)
	if packed == null:
		return null
	var imported := packed.instantiate() as Node3D
	if imported.get_child_count() != 1 or not imported.get_child(0) is Node3D:
		imported.free()
		return null
	var authored := imported.get_child(0) as Node3D
	imported.remove_child(authored)
	authored.transform = imported.transform * authored.transform
	imported.free()
	return authored


func _dress_warden(warden) -> void:
	if not is_inside_tree() or not is_instance_valid(warden) or not warden.is_inside_tree() or _wardens.has(warden.get_instance_id()):
		return
	if warden._look == null or warden._kit == null or not WARDEN_KITS.has(warden.family):
		return
	if _wears_body(warden):
		_dress_warden_body(warden)
		return
	var base := _warden_scene(WARDEN_BASE)
	var kit := _warden_scene("res://assets/models/warden_kit_%s.glb" % WARDEN_KITS[warden.family])
	if base == null or kit == null:
		if base != null: base.free()
		if kit != null: kit.free()
		_warn_once("warden", "hero_assets: Warden assets unavailable; keeping functional placeholders")
		return
	var tower := base.get_node_or_null("Tower") as MeshInstance3D
	var mount := base.get_node_or_null("Tower/KitMount") as Node3D
	var weak := kit.get_node_or_null("WeakPoint") as Node3D
	if tower == null or mount == null or weak == null or not base.has_node("JawL") or not base.has_node("JawR") or not _has_warden_chunk_nodes(base):
		base.free()
		kit.free()
		_warn_once("warden_nodes", "hero_assets: incomplete Warden asset hierarchy; keeping placeholders")
		return
	base.name = "HeroWarden"
	base.position.y = -warden.HALF_HEIGHT
	# Authored seam corners reach 2.826 m; keep the housing inside the 2.8 m collider.
	base.get_node("Housing").scale = Vector3(0.99, 1.0, 0.99)
	kit.name = "HeroKit"
	var target: Vector3 = warden._kit.point_offset() + Vector3.UP * warden.HALF_HEIGHT
	kit.position = target - weak.position
	var old_mount: Vector3 = tower.position + mount.position
	_adapt_warden_tower(tower, kit.position - old_mount, old_mount.y)
	mount.position = kit.position - tower.position
	base.add_child(kit)
	var rec := {"warden": warden, "base": base, "kit": kit, "weak": weak,
		"hidden": [], "materials": {}, "seams": [], "cracks": [], "lens": null, "shutters": [], "queen_hatch": null,
		"jaws": [], "light_rest": {}, "segments": [], "chunk_marks": [], "flights": [],
		"chunks_seen": 4, "core": base.get_node("CoreAssembly"), "mantle": null, "mantle_tool": null}
	if warden.family == "swarm":
		_split_queen_hatch(weak, rec)
	_paint_warden(base, rec)
	if warden._look.posture_fight():
		_rig_warden_jaws(base, rec)
	_rig_warden_chunks(base, rec)
	if warden.family == "mind":
		var lens := Node3D.new()
		lens.name = "HeroLens"
		lens.position = weak.position
		kit.add_child(lens)
		for child in kit.get_children():
			if child == weak or String(child.name).begins_with("Shutter"):
				var at: Vector3 = child.position - lens.position
				kit.remove_child(child)
				lens.add_child(child)
				child.position = at
				if child != weak:
					rec.shutters.append({"node": child, "rest": at})
		rec.lens = lens
	_mount_mantle(warden, kit, rec)
	warden.add_child(base)
	# Cool fill (LIGHTING-TARGETS, Warden) as an additive cool rim, so the barrel and armour separate from
	# the shared warm key. No light: a Warden is freed on every beacon placement, and a light freed with
	# it is the stage-freed light crash class (the cracked_cache.gd RIM_GLOW recipe: glow on its own mesh, no light).
	if not _materials.has("warden_cool_fill"):
		var shader := Shader.new()
		shader.code = """shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back;
uniform vec3 tint : source_color = vec3(0.659, 0.761, 0.831);
uniform float energy = 0.8;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = tint * rim * energy;
}
"""
		var cool := ShaderMaterial.new()
		cool.shader = shader
		_materials["warden_cool_fill"] = cool
	# The rim draws as its own shell over the part (the cache glow's own-mesh recipe); a material
	# overlay freed with a Warden logs a null material on the headless server.
	for part in ["Tower", "Housing"]:
		var view := base.get_node_or_null(part) as MeshInstance3D
		if view != null and view.mesh != null:
			var rim := MeshInstance3D.new()
			rim.name = "CoolFill"
			rim.mesh = view.mesh
			rim.material_override = _materials["warden_cool_fill"]
			rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			view.add_child(rim)
	for child in warden._look.get_children():
		if child is MeshInstance3D and child.material_override == warden._look.body_material:
			_hide_warden_mesh(child, rec)
	_hide_warden_tree(warden._look._jaws, rec)
	_hide_warden_tree(warden._kit, rec)
	_add_warden_strokes(base, warden._look, warden, rec)
	_wardens[warden.get_instance_id()] = rec
	warden.tree_exiting.connect(_forget_warden.bind(warden.get_instance_id()), CONNECT_ONE_SHOT)
	_update_warden(rec)
	if warden.fight() == "posture" and warden.fleet != null:
		var bus = warden.fleet.events()
		if not bus.posture_changed.is_connected(_warden_posture_changed):
			bus.posture_changed.connect(_warden_posture_changed)
		if not bus.stage_entered.is_connected(_warden_stage_entered):
			bus.stage_entered.connect(_warden_stage_entered)
	_dress_mast.call_deferred(warden)


# --- Warden bodies (KF8a) -----------------------------------------------------------------
# A park Warden's recipe body replaces the clamp, the kit and the mantle. It is visual only: the
# Warden's collider, weak point (warden_kit.gd point_offset) and hardpoints are the fight's.
# The clips follow what the fight already publishes, read once a frame: the charge (state_name),
# the pulse (pulses), the stagger, the chunks, the swarm driver's rides and the mind driver's
# took_off and landed signals. Each GLB clip keys every channel (Godot adds rest tracks), so what
# must outlast a clip is held after the mixer (mixer_applied): a lost reactor jacket stays
# hidden, a shed swarm ring stays at zero scale, a lost mind finger keeps its clip's end pose,
# the mind's perch grip stays under idle, pulse_warn, pulse and active, and the Lens bone looks
# at the ball last.

func _wears_body(warden) -> bool:
	return WARDEN_BODIES.has(warden.family) and bool(warden.get("harpoon_anchor"))


func _body_scene(path: String) -> Node3D:
	var packed := _packed(path)
	return packed.instantiate() as Node3D if packed != null else null


func _dress_warden_body(warden) -> void:
	var kind: String = warden.family
	var row: Dictionary = WARDEN_BODIES[kind]
	var body := _body_scene(row.body)
	var weak := body.find_child(row.point, true, false) as Node3D if body != null else null
	var player := body.find_child("AnimationPlayer", true, false) as AnimationPlayer if body != null else null
	if body == null or weak == null or player == null:
		if body != null: body.free()
		_warn_once("warden_body:" + kind, "hero_assets: Warden body '%s' unavailable; keeping functional placeholders" % row.body)
		return
	body.name = "HeroWarden"
	body.position.y = -warden.HALF_HEIGHT
	for kit_path in row.kits:
		var kit_part := _body_scene(kit_path)
		if kit_part == null:
			_warn_once("warden_body_kit:" + kit_path, "hero_assets: Warden body kit '%s' unavailable" % kit_path)
			continue
		body.add_child(kit_part)
	var rec := {"warden": warden, "base": body, "body": body, "body_kind": kind, "weak": weak, "kit": null,
		"hidden": [], "materials": {}, "seams": [], "cracks": [], "flights": [], "jaws": [], "mantle": null, "mantle_tool": null,
		"players": body.find_children("*", "AnimationPlayer", true, false), "skeleton": null, "queue": [], "lost": [],
		"dark": [], "final": false, "pose": null, "pose_base": Transform3D.IDENTITY, "perch_pose": {}, "lens": -1,
		"seen": {"charging": false, "pulses": warden.pulses, "staggered": warden.staggered(),
			"chunks": warden.chunks_left(), "rides": _driver_count(warden, "rides")}}
	rec.skeleton = body.find_child("Skeleton3D", true, false) as Skeleton3D
	_paint_body(body, rec)
	match kind:
		"reactor":
			for mount in row.mount_parts:
				for part in row.mount_parts[mount]:
					var node := body.find_child(part, true, false) as Node3D
					if node != null:
						node.visible = mount == warden.mounting
		"swarm":
			_own_clip(rec.players[0], "chunk_shed")
		"mind":
			_rig_mind_body(warden, rec)
	for child in warden._look.get_children():
		if child is MeshInstance3D and child.material_override == warden._look.body_material:
			_hide_warden_mesh(child, rec)
	_hide_warden_tree(warden._look._jaws, rec)
	_hide_warden_tree(warden._kit, rec)
	warden.add_child(body)
	var id: int = warden.get_instance_id()
	for p in rec.players:
		(p as AnimationPlayer).mixer_applied.connect(_hold_body.bind(id))
	(rec.players[0] as AnimationPlayer).animation_finished.connect(_body_clip_finished.bind(id))
	if kind == "mind" and warden.mount_driver != null and warden.mount_driver.has_signal("took_off"):
		SignalLifetime.listen(body, warden.mount_driver.took_off, func(_a: int, _b: int): _play_body(rec, ["takeoff", "glide"]))
		SignalLifetime.listen(body, warden.mount_driver.landed, func(_p: int): _play_body(rec, ["land"]))
	_wardens[id] = rec
	warden.tree_exiting.connect(_forget_warden.bind(id), CONNECT_ONE_SHOT)
	_play_body(rec, ["idle"])
	_update_warden(rec)
	if warden.fight() == "posture" and warden.fleet != null:
		var bus = warden.fleet.events()
		if not bus.posture_changed.is_connected(_warden_posture_changed):
			bus.posture_changed.connect(_warden_posture_changed)
		if not bus.stage_entered.is_connected(_warden_stage_entered):
			bus.stage_entered.connect(_warden_stage_entered)


func _driver_count(warden, key: String) -> int:
	var driver = warden.mount_driver
	if driver == null or not (key in driver):
		return 0
	return int(driver.get(key))


# Every surface by its slot, as the clamp is painted; the light and enamel slots are this
# Warden's own copies, so seams go out per body.
func _paint_body(root: Node, rec: Dictionary) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var slot := slot_of(mi.mesh, i)
			if slot != "glass" and not SLOTS.has(slot):
				_warn_once(slot, "hero_assets: unknown material slot '%s'" % slot)
				continue
			if not rec.materials.has(slot):
				var own := slot.begins_with("ancient_light") or slot == "ancient_enamel"
				rec.materials[slot] = material(slot).duplicate() if own else material(slot)
			_surface_material(mi, i, rec.materials[slot])
			if slot == "glass":
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# Gives this player its own copy of one clip, so a track filter on it touches no other body.
func _own_clip(player: AnimationPlayer, clip: String) -> void:
	var shared := player.get_animation_library(&"")
	if shared == null or not shared.has_animation(clip):
		return
	var own := AnimationLibrary.new()
	for clip_name in shared.get_animation_list():
		var anim := shared.get_animation(clip_name)
		own.add_animation(clip_name, anim.duplicate() if clip_name == clip else anim)
	player.remove_animation_library(&"")
	player.add_animation_library(&"", own)


# The perch (spires): Pose takes PosePerch's transform once, and the perch clip's end pose is
# the base every non-lens bone holds outside the flight clips (mind rows section 5).
func _rig_mind_body(warden, rec: Dictionary) -> void:
	var body: Node3D = rec.body
	var skel: Skeleton3D = rec.skeleton
	rec.pose = body.find_child("Pose", true, false) as Node3D
	rec.lens = skel.find_bone("Lens") if skel != null else -1
	# The GLB's WeakPoint sits 1.32 m out along the lens face; the fight's point (a 1.3 m sphere,
	# warden.gd FAMILY_POINT_RADIUS) is the lens itself, so the marker rides the Lens bone's origin.
	if rec.weak.get_parent() is BoneAttachment3D:
		rec.weak.position = Vector3.ZERO
	if warden.mounting == "spires":
		var perch := body.find_child("PosePerch", true, false) as Node3D
		if perch != null and rec.pose != null:
			rec.pose.transform = perch.transform
			rec.pose_base = perch.transform
		var player: AnimationPlayer = rec.players[0]
		if player.has_animation("perch"):
			rec.perch_pose = _clip_end_pose(player.get_animation("perch"), skel, MIND_LENS_BONES, true)
		else:
			push_error("hero_assets: mind body has no clip 'perch'")


# The pose a clip leaves at its last frame: {bone index: {position, rotation, scale}} for the
# bones it keys, either only `names` or (except) every bone but them.
func _clip_end_pose(anim: Animation, skel: Skeleton3D, names: Array, exclude := false) -> Dictionary:
	var out := {}
	for t in anim.get_track_count():
		var path := anim.track_get_path(t)
		if path.get_subname_count() == 0:
			continue
		var bone_name := String(path.get_subname(0))
		if (bone_name in names) == exclude:
			continue
		var bone := skel.find_bone(bone_name)
		if bone < 0:
			continue
		var entry: Dictionary = out.get(bone, {})
		match anim.track_get_type(t):
			Animation.TYPE_POSITION_3D:
				entry["position"] = anim.position_track_interpolate(t, anim.length)
			Animation.TYPE_ROTATION_3D:
				entry["rotation"] = anim.rotation_track_interpolate(t, anim.length)
			Animation.TYPE_SCALE_3D:
				entry["scale"] = anim.scale_track_interpolate(t, anim.length)
		out[bone] = entry
	return out


func _set_bone_pose(skel: Skeleton3D, bone: int, entry: Dictionary) -> void:
	if entry.has("position"):
		skel.set_bone_pose_position(bone, entry.position)
	if entry.has("rotation"):
		skel.set_bone_pose_rotation(bone, entry.rotation)
	if entry.has("scale"):
		skel.set_bone_pose_scale(bone, entry.scale)


# Plays `clips` in order on every player of the body (the swarm's hive and drone kit share the
# names); the first starts now with its section 5 blend. A clip a player lacks is an error.
func _play_body(rec: Dictionary, clips: Array, backwards := false) -> void:
	rec.queue = clips.slice(1)
	_start_body_clip(rec, String(clips[0]), backwards)


func _start_body_clip(rec: Dictionary, clip: String, backwards := false) -> void:
	var blend: float = WARDEN_BODY_BLENDS[rec.body_kind].get(clip, -1.0)
	for p in rec.players:
		var player := p as AnimationPlayer
		if not player.has_animation(clip):
			push_error("hero_assets: %s Warden body player %s has no clip '%s'" % [rec.body_kind, player.get_parent().name, clip])
			continue
		if backwards:
			player.play_backwards(clip, blend)
		else:
			player.play(clip, blend)


func _body_clip_finished(clip: StringName, id: int) -> void:
	var rec: Dictionary = _wardens.get(id, {})
	if rec.is_empty() or not is_instance_valid(rec.warden):
		return
	if not rec.queue.is_empty():
		_start_body_clip(rec, String(rec.queue.pop_front()))
		return
	# The break holds its last frame, and so does the falter while the stagger lasts.
	if rec.final or (String(clip) == "grip_falter" and rec.warden.staggered() and rec.players[0].get_playing_speed() > 0.0):
		return
	_start_body_clip(rec, "idle")


func _update_warden_body(rec: Dictionary) -> void:
	var warden = rec.warden
	var body: Node3D = rec.body
	match rec.body_kind:
		"reactor":
			body.rotation.y = warden._look._jaws.rotation.y
		"swarm":
			# The swarm's ball side is its +Z.
			body.rotation.y = warden._look._jaws.rotation.y + PI * 0.5
		"mind":
			# The driver drops the whole Warden by lens_drop in the falter while grip_falter drops
			# the lens in the body: the body rises by the same amount so the lens stays on the point.
			var driver = warden.mount_driver
			var drop: float = float(driver.get("lens_drop")) if driver != null and "lens_drop" in driver else 0.0
			body.position.y = -warden.HALF_HEIGHT + drop
	var seam: float = warden._kit._seam_material.emission_energy_multiplier
	for key in rec.materials:
		if String(key).begins_with("ancient_light"):
			(rec.materials[key] as StandardMaterial3D).emission_energy_multiplier = 0.0 if key in rec.dark else seam
	var enamel := rec.materials.get("ancient_enamel") as StandardMaterial3D
	if enamel != null:
		enamel.albedo_color = Color.WHITE.lerp(warden._look.body_material.albedo_color, warden._flash)
	_drive_body(rec)
	_hold_body(warden.get_instance_id())


# Reads the fight's facts once a frame and starts the clips they name.
func _drive_body(rec: Dictionary) -> void:
	var warden = rec.warden
	var seen: Dictionary = rec.seen
	var kind: String = rec.body_kind
	var staggered: bool = warden.staggered()
	if staggered != seen.staggered:
		seen.staggered = staggered
		_body_stagger(rec, staggered)
	var charging: bool = warden.state_name() == "charging"
	if charging and not seen.charging:
		_play_body(rec, [WARDEN_BODY_CHARGE[kind]])
	seen.charging = charging
	if warden.pulses != seen.pulses:
		seen.pulses = warden.pulses
		_body_pulse(rec)
	var chunks: int = warden.chunks_left()
	if chunks < seen.chunks:
		for n in range(5 - seen.chunks, 5 - chunks):
			_body_chunk(rec, n)
		seen.chunks = chunks
	if kind == "swarm":
		var rides := _driver_count(warden, "rides")
		if rides != seen.rides:
			seen.rides = rides
			_play_body(rec, ["hoist_ride"])


func _body_pulse(rec: Dictionary) -> void:
	var warden = rec.warden
	match rec.body_kind:
		"swarm":
			# The pulse clip's last 0.4 s is the slam; active follows it.
			var player: AnimationPlayer = rec.players[0]
			if player.current_animation == "pulse":
				rec.queue = ["active"]
			else:
				_play_body(rec, ["active"])
		"reactor":
			var clips := ["pulse"]
			if WARDEN_REACTOR_PULSE_EXTRA.has(warden.mounting):
				clips.append(WARDEN_REACTOR_PULSE_EXTRA[warden.mounting])
			clips.append("active")
			_play_body(rec, clips)
		"mind":
			_play_body(rec, ["pulse", "active"])


func _body_stagger(rec: Dictionary, open: bool) -> void:
	var warden = rec.warden
	match rec.body_kind:
		"reactor":
			# The open seam is the light slot at SEAM_OPEN (_update_warden_body); active splits the cage.
			if open:
				_play_body(rec, ["active"])
		"swarm":
			if open:
				_play_body(rec, ["stagger_open"])
		"mind":
			if warden.mounting == "spires":
				var driver = warden.mount_driver
				var flying: bool = driver != null and driver.has_method("flying") and driver.flying()
				if open:
					_play_body(rec, ["knocked_down" if flying else "active"])
			elif open:
				_play_body(rec, ["grip_falter"])
			elif rec.players[0].assigned_animation == "grip_falter":
				_play_body(rec, ["grip_falter", "idle"], true)


func _body_chunk(rec: Dictionary, n: int) -> void:
	var body: Node3D = rec.body
	var clip := ""
	var entry := {}
	match rec.body_kind:
		"reactor":
			clip = "chunk_lost" if n == 1 else "chunk_lost_%d" % (n - 1)
			entry = {"node": body.find_child("Jacket%d" % (n - 1), true, false)}
		"swarm":
			var ring: String = WARDEN_BODIES.swarm.shed_rings[n - 1]
			clip = "chunk_shed"
			_filter_shed(rec.players[0], ring)
			entry = {"bone": rec.skeleton.find_bone(ring) if rec.skeleton != null else -1}
		"mind":
			var finger: Dictionary = MIND_CHUNK_FINGERS[n - 1]
			clip = finger.clip
			var digit := String(finger.seam).right(1)
			var bones := ["Finger%s_0" % digit, "Finger%s_1" % digit, "Finger%s_2" % digit]
			var player: AnimationPlayer = rec.players[0]
			if player.has_animation(clip):
				entry = {"pose": _clip_end_pose(player.get_animation(clip), rec.skeleton, bones)}
			rec.dark.append(finger.seam)
	entry["clip"] = clip
	rec.lost.append(entry)
	var clips := [clip]
	if n >= 4:
		rec.final = true
		clips.append(WARDEN_BODY_FINAL[rec.body_kind])
		if rec.body_kind == "mind":
			rec.dark.append("ancient_light_thumb")
	_play_body(rec, clips)


# chunk_shed keys the same fall on all four shed rings: only `ring` keeps its tracks.
func _filter_shed(player: AnimationPlayer, ring: String) -> void:
	if not player.has_animation("chunk_shed"):
		return
	var anim := player.get_animation("chunk_shed")
	var rings: Array = WARDEN_BODIES.swarm.shed_rings
	for t in anim.get_track_count():
		var bone := String(anim.track_get_path(t)).get_slice(":", 1)
		if bone in rings:
			anim.track_set_enabled(t, bone == ring)


# After the mixer: lost chunks stay lost, the perch grip holds, the Pose faces the ball and the
# Lens bone looks at it. The newest lost chunk is left to its own clip while that clip plays.
func _hold_body(id: int) -> void:
	var rec: Dictionary = _wardens.get(id, {})
	if rec.is_empty() or not is_instance_valid(rec.warden) or not is_instance_valid(rec.body):
		return
	var player: AnimationPlayer = rec.players[0]
	var current := String(player.current_animation) if player.is_playing() else ""
	var skel: Skeleton3D = rec.skeleton
	var falling := -1
	if not rec.lost.is_empty() and current == rec.lost.back().clip:
		falling = rec.lost.size() - 1
	match rec.body_kind:
		"reactor":
			for i in rec.lost.size():
				var jacket = rec.lost[i].node
				if is_instance_valid(jacket):
					jacket.visible = i == falling
		"swarm":
			for i in rec.lost.size():
				if i != falling and rec.lost[i].bone >= 0:
					skel.set_bone_pose_scale(rec.lost[i].bone, Vector3.ZERO)
		"mind":
			_hold_mind(rec, current, falling)


func _hold_mind(rec: Dictionary, current: String, falling: int) -> void:
	var warden = rec.warden
	var skel: Skeleton3D = rec.skeleton
	if skel == null:
		return
	var moving: Dictionary = rec.lost[falling].get("pose", {}) if falling >= 0 else {}
	if not rec.perch_pose.is_empty() and not current in MIND_FLIGHT_CLIPS:
		for bone in rec.perch_pose:
			if not moving.has(bone):
				_set_bone_pose(skel, bone, rec.perch_pose[bone])
	for i in rec.lost.size():
		if i != falling:
			var held: Dictionary = rec.lost[i].get("pose", {})
			for bone in held:
				_set_bone_pose(skel, bone, held[bone])
	var to_ball: Vector3 = warden.flat_to_ball()
	if rec.pose != null and to_ball.length() > 0.1:
		# The hand's front is the model's -Z.
		var yaw: float = atan2(-to_ball.x, -to_ball.z) - rec.body.global_rotation.y
		rec.pose.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO) * rec.pose_base
	_track_lens(rec)


# mind rows section 5: turn the Lens bone (the cluster faces the model's -Z at rest) so it looks
# at the ball, after the AnimationPlayer: pose = parent_global^-1 * looking_at(dir) * lens_rest,
# lens_rest the bone's global rest, so the rest facing turns onto dir; dir in skeleton space.
func _track_lens(rec: Dictionary) -> void:
	var skel: Skeleton3D = rec.skeleton
	var lens: int = rec.lens
	var target = rec.warden.target
	if lens < 0 or target == null or not target.has_method("ball_position"):
		return
	var parent := skel.get_bone_parent(lens)
	var parent_pose := skel.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var origin: Vector3 = parent_pose * skel.get_bone_pose_position(lens)
	var dir: Vector3 = skel.global_transform.affine_inverse() * (target.ball_position() as Vector3) - origin
	if dir.length() < 0.1:
		return
	dir = dir.normalized()
	var look := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
	var turned := parent_pose.basis.orthonormalized().inverse() * look * skel.get_bone_global_rest(lens).basis.orthonormalized()
	skel.set_bone_pose_rotation(lens, turned.get_rotation_quaternion())


# Mounts the stage's mantle (D5 contract) after the kit is painted and the lens is split off:
# each Mount* group is detached and added to its kit node with identity transform. Enamel and
# rubber reuse the Warden's own painted materials; the seam and tool materials are the mantle's
# own and stay out of rec.materials, so the open-core mint and light records never touch them.
# A missing file or node warns once and leaves the bare kit.
func _mount_mantle(warden, kit: Node3D, rec: Dictionary) -> void:
	var row: Dictionary = WARDEN_MANTLES.get(int(warden.stage), {})
	if row.is_empty() or row.family != warden.family:
		return
	var mantle := _warden_scene(row.path)
	if mantle == null:
		_warn_once("mantle:" + row.path, "hero_assets: mantle '%s' unavailable; keeping the bare kit" % row.path)
		return
	var groups: Array[Node3D] = []
	for child in mantle.get_children():
		if child is Node3D and MANTLE_MOUNTS.has(String(child.name)):
			groups.append(child)
	var ok := not groups.is_empty()
	for group in groups:
		ok = ok and kit.get_node_or_null(MANTLE_MOUNTS[String(group.name)]) is Node3D
	if not ok:
		mantle.free()
		_warn_once("mantle_nodes:" + row.path, "hero_assets: mantle '%s' does not fit the kit; keeping the bare kit" % row.path)
		return
	var seam := material("ancient_light").duplicate() as StandardMaterial3D
	var tool := material("mantle_tool").duplicate() as StandardMaterial3D
	tool.emission_enabled = true
	tool.emission = Palette.HAZARD
	tool.emission_energy_multiplier = 0.0
	var mounted: Array[Node3D] = []
	for group in groups:
		var socket := kit.get_node(MANTLE_MOUNTS[String(group.name)]) as Node3D
		mantle.remove_child(group)
		group.transform = Transform3D.IDENTITY
		socket.add_child(group)
		mounted.append(group)
		_paint_mantle(group, rec, seam, tool)
	mantle.free()
	rec.mantle = mounted
	rec.mantle_tool = tool


func _paint_mantle(root: Node, rec: Dictionary, seam: Material, tool: Material) -> void:
	if root is MeshInstance3D:
		for i in root.mesh.get_surface_count():
			var slot := slot_of(root.mesh, i)
			var mat: Material = null
			match slot:
				"ancient_enamel", "rubber":
					mat = rec.materials.get(slot, material(slot))
				"ancient_light":
					mat = seam
				"mantle_tool":
					mat = tool
					var authored := root.mesh.surface_get_material(i) as StandardMaterial3D
					if authored != null and authored.albedo_texture != null:
						tool.albedo_texture = authored.albedo_texture
						tool.emission_texture = authored.albedo_texture
						tool.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				"bare_metal":
					mat = material(slot)
			if mat != null:
				_surface_material(root, i, mat)
	for child in root.get_children():
		_paint_mantle(child, rec, seam, tool)


# The tool throats take the Warden's own charge: lit as the pulse charges, dark at rest and
# while staggered. No clock of its own.
func _update_mantle(rec: Dictionary) -> void:
	var tool := rec.mantle_tool as StandardMaterial3D
	if tool == null:
		return
	var warden = rec.warden
	var lit: float = 0.0 if warden.staggered() else warden.charge_fraction()
	tool.emission_energy_multiplier = lit * 2.0
	if tool.albedo_texture != null:
		tool.emission = Color.WHITE
		var brightness := lerpf(0.03, 1.0, lit)
		tool.albedo_color = Color(brightness, brightness, brightness)
	else:
		tool.albedo_color = Palette.HAZARD.lerp(Palette.CHARCOAL, 1.0 - lit)


# A posture Warden's jaws lean out from their outer bottom edge while its core is open.
# Each entry keeps the rest transform, the edge to turn about and which way is out.
func _rig_warden_jaws(base: Node3D, rec: Dictionary) -> void:
	for side in [-1.0, 1.0]:
		var jaw := base.get_node("JawL" if side < 0 else "JawR") as MeshInstance3D
		var bounds := jaw.mesh.get_aabb()
		var edge := Vector3(0.0, bounds.position.y, bounds.position.z if side < 0 else bounds.end.z)
		rec.jaws.append({"node": jaw, "rest": jaw.transform, "pivot": jaw.transform * edge, "out": side})
	for key in ["ancient_light_base", "ancient_light"]:
		rec.light_rest[key] = (rec.materials[key] as StandardMaterial3D).emission


func _split_queen_hatch(weak: MeshInstance3D, rec: Dictionary) -> void:
	var body := ArrayMesh.new()
	var cap := ArrayMesh.new()
	for surface in weak.mesh.get_surface_count():
		var target := cap if slot_of(weak.mesh, surface) == "rubber" else body
		target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, weak.mesh.surface_get_arrays(surface))
		target.surface_set_material(target.get_surface_count() - 1, weak.mesh.surface_get_material(surface))
	if cap.get_surface_count() == 0:
		return
	weak.mesh = body
	var bounds := cap.get_aabb()
	var hinge := Node3D.new()
	hinge.name = "QueenHatch"
	hinge.position = Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	weak.add_child(hinge)
	var shutter := MeshInstance3D.new()
	shutter.name = "Shutter"
	shutter.mesh = cap
	shutter.position = -hinge.position
	hinge.add_child(shutter)
	rec.queen_hatch = hinge


# A played game prewarms behind the title, a frame after the boot card is gone (_process): in setup it
# held the menu for 80 to 85 ms (MENU-READY, cloud exported build). Tests, bots and a scene without a
# game root prewarm here, as before. The first Warden is stages away from the title either way.
func _prewarm_strokes_in_time() -> void:
	var root = ctx.get("root") if ctx != null else null
	if root == null or root.get("test_mode") != false:
		_prewarm_warden_strokes()
		return
	_prewarm_wait = 1


func _step_prewarm() -> void:
	if get_tree().root.get_node_or_null("Boot") != null:
		return
	_prewarm_wait -= 1
	if _prewarm_wait < 0:
		_prewarm_warden_strokes()


func _prewarm_warden_strokes() -> void:
	var base := _warden_scene(WARDEN_BASE)
	if base == null or not base.has_node("JawL") or not base.has_node("JawR"):
		if base != null: base.free()
		return
	# Detached presentation builders only: no enemy setup, tree entry, events or physics.
	var cue_owner := preload("res://src/combat/enemy.gd").new()
	var look := WardenLook.new()
	cue_owner.add_child(look)
	cue_owner.add_child(base)
	look._build_jaws()
	_add_warden_strokes(base, look, cue_owner, {"seams": [], "cracks": []})
	cue_owner.free()


func _add_warden_strokes(base: Node3D, look: Node3D, cue_owner: Node3D, rec: Dictionary) -> void:
	for side in [-1.0, 1.0]:
		var jaw: MeshInstance3D = base.get_node("JawL" if side < 0 else "JawR")
		var faces := jaw.mesh.get_faces()
		var angle: float = side * 1.3
		var normal := Vector3(cos(angle), 0, sin(angle))
		var panel := Node3D.new()
		panel.position = normal * 3.77 + Vector3.UP * 3.9 - jaw.position
		panel.basis = Basis.looking_at(-normal)
		jaw.add_child(panel)
		for level in look._seams.size():
			var row: Array = look._seams[level]
			for i in 3:
				var old := row[i] as MeshInstance3D
				var seam := MeshInstance3D.new()
				seam.mesh = old.mesh
				seam.material_override = old.material_override
				seam.transform = old.transform
				seam.position *= 0.4
				seam.position.z = 0.04
				seam.scale *= 0.5
				panel.add_child(seam)
				_fit_warden_stroke(seam, jaw, faces)
				rec.seams.append({"node": seam, "source": old})
		# Existing enemy helper owns the class-colour open-crack grammar and tint list.
		var crack: Node3D = cue_owner._add_crack(panel, Vector3(0, 0, 0.08), 0.8)
		for stroke in crack.get_children():
			_fit_warden_stroke(stroke, jaw, faces)
		rec.cracks.append(crack)


# Keep each stroke's readable length, but wrap a narrow ribbon around the cast jaw.
# Projection runs once during attachment; animation still reads the original cue.
func _fit_warden_stroke(stroke: MeshInstance3D, jaw: MeshInstance3D, faces: PackedVector3Array) -> void:
	var box := stroke.mesh as BoxMesh
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var to_jaw := Transform3D.IDENTITY
	var ancestor: Node3D = stroke
	while ancestor != jaw:
		to_jaw = ancestor.transform * to_jaw
		ancestor = ancestor.get_parent() as Node3D
	var key := "warden_stroke:%s:%s:%s" % [jaw.name, box.size, to_jaw]
	stroke.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	if _meshes.has(key):
		stroke.mesh = _meshes[key]
		return
	var from_jaw := to_jaw.affine_inverse()
	var low := INF
	var high := -INF
	for x in [-0.5, 0.5]:
		for y in [-0.5, 0.5]:
			var height: float = (to_jaw * Vector3(box.size.x * x, box.size.y * y, 0)).y
			low = minf(low, height)
			high = maxf(high, height)
	var candidates := PackedVector3Array()
	for i in range(0, faces.size(), 3):
		if maxf(faces[i].y, maxf(faces[i + 1].y, faces[i + 2].y)) >= low and minf(faces[i].y, minf(faces[i + 1].y, faces[i + 2].y)) <= high:
			candidates.append_array(PackedVector3Array([faces[i], faces[i + 1], faces[i + 2]]))
	for row in 17:
		for side in [-0.5, 0.5]:
			var point := to_jaw * Vector3(box.size.x * side, box.size.y * (float(row) / 16.0 - 0.5), 0)
			var radial := Vector3(point.x + jaw.position.x, 0, point.z + jaw.position.z).normalized()
			var start := radial * 8.0 + Vector3.UP * point.y - Vector3(jaw.position.x, 0, jaw.position.z)
			var nearest := INF
			var contact := Vector3.ZERO
			for triangle in range(0, candidates.size(), 3):
				var hit = Geometry3D.ray_intersects_triangle(start, -radial, candidates[triangle], candidates[triangle + 1], candidates[triangle + 2])
				if hit != null:
					var distance: float = start.distance_squared_to(hit)
					if distance < nearest:
						nearest = distance
						contact = hit
			if nearest == INF:
				_warn_once("warden_stroke", "hero_assets: Warden stroke missed jaw surface at %s" % point)
				return
			vertices.append(from_jaw * (contact + radial * 0.015))
			normals.append((to_jaw.basis.transposed() * radial).normalized())
		if row > 0:
			var n := row * 2
			indices.append_array(PackedInt32Array([n - 2, n, n - 1, n - 1, n, n + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var ribbon := ArrayMesh.new()
	ribbon.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[key] = ribbon
	stroke.mesh = ribbon


func _adapt_warden_tower(tower: MeshInstance3D, shift: Vector3, top: float) -> void:
	var adapted := ArrayMesh.new()
	for surface in tower.mesh.get_surface_count():
		var arrays := tower.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			var y := vertices[i].y + tower.position.y
			if y > 2.2:
				vertices[i] += shift * ((y - 2.2) / (top - 2.2))
				var shear := Basis(Vector3.RIGHT, Vector3.UP + shift / (top - 2.2), Vector3.BACK)
				normals[i] = (shear.inverse().transposed() * normals[i]).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		adapted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		adapted.surface_set_material(surface, tower.mesh.surface_get_material(surface))
	tower.mesh = adapted


func _paint_warden(root: Node, rec: Dictionary, kit := false) -> void:
	kit = kit or root.name == "HeroKit"
	if root is MeshInstance3D:
		for i in root.mesh.get_surface_count():
			var slot := slot_of(root.mesh, i)
			var key := slot
			if slot == "ancient_light" and not kit:
				if root.name != "HeartSurface":
					key += "_jaw" if String(root.name).begins_with("Jaw") or String(root.name).begins_with("ArmourSegment") else "_base"
			if not rec.materials.has(key):
				rec.materials[key] = material(slot).duplicate() if slot in ["ancient_light", "ancient_enamel"] else material(slot)
			_surface_material(root, i, rec.materials[key])
	for child in root.get_children():
		_paint_warden(child, rec, kit)


func _hide_warden_mesh(mesh: MeshInstance3D, rec: Dictionary) -> void:
	rec.hidden.append({"mesh": mesh, "layers": mesh.layers, "shadow": mesh.cast_shadow})
	hide_placeholder(mesh)


func _hide_warden_tree(node: Node, rec: Dictionary) -> void:
	if node is MeshInstance3D:
		_hide_warden_mesh(node, rec)
	for child in node.get_children():
		_hide_warden_tree(child, rec)


func _update_warden(rec: Dictionary) -> void:
	if rec.get("body") != null:
		_update_warden_body(rec)
		return
	var warden = rec.warden
	rec.base.rotation.y = warden._look._jaws.rotation.y
	rec.weak.scale = warden._kit._open_node.scale
	if rec.queen_hatch != null:
		rec.queen_hatch.rotation.z = -PI * 0.5 if warden.family_open() else 0.0
	if rec.lens != null:
		rec.lens.global_basis = warden._kit._lens.global_basis * Basis(Vector3.UP, PI * 0.5)
		for shutter in rec.shutters:
			shutter.node.position = shutter.rest * (1.5 if warden.family_open() else 1.0)
	rec.materials.ancient_light_base.emission_energy_multiplier = warden._look._core_material.emission_energy_multiplier
	var light: StandardMaterial3D = rec.materials.ancient_light
	light.emission_energy_multiplier = warden._kit._seam_material.emission_energy_multiplier
	var enamel: StandardMaterial3D = rec.materials.ancient_enamel
	enamel.albedo_color = Color.WHITE.lerp(warden._look.body_material.albedo_color, warden._flash)
	enamel.emission_enabled = warden._flash > 0.0
	enamel.emission = warden._look.body_material.emission
	enamel.emission_energy_multiplier = warden._look.body_material.emission_energy_multiplier
	var rim: StandardMaterial3D = rec.materials.ancient_light_jaw
	var plate: StandardMaterial3D = warden._look.plate_material
	var cued: bool = warden.tint_state != ""
	rim.emission = plate.emission if cued else Palette.ANCIENT
	rim.albedo_color = rim.emission
	rim.emission_energy_multiplier = plate.emission_energy_multiplier if cued else 0.8
	for seam in rec.seams:
		seam.node.visible = seam.source.visible
	if not rec.jaws.is_empty():
		_update_warden_open(rec)
	_update_warden_chunks(rec)
	_update_mantle(rec)


# The jaws spring out and the core takes the live colour while a posture Warden is open.
func _update_warden_open(rec: Dictionary) -> void:
	var warden = rec.warden
	var lean: float = deg_to_rad(warden._look.JAW_OPEN_DEGREES) * warden._look.jaw_open()
	for entry in rec.jaws:
		var turn := Transform3D(Basis(Vector3.RIGHT, entry.out * lean), entry.pivot)
		entry.node.transform = turn * Transform3D(Basis.IDENTITY, -entry.pivot) * entry.rest
	# The body material carries combat's amber hit flash; a posture Warden never wears amber.
	(rec.materials.ancient_enamel as StandardMaterial3D).emission = EventKinds.role_color("neutral")
	var open: bool = warden.staggered()
	rec.core.visible = open
	for key in rec.light_rest:
		(rec.materials[key] as StandardMaterial3D).emission = EventKinds.state_color("open") if open else rec.light_rest[key]


func _warden_posture_changed(warden: Node3D, _guard: float, _staggered: bool) -> void:
	var rec := warden_of(warden)
	if not rec.is_empty():
		_update_warden(rec)


func _warden_stage_entered(_stage: int, _retry: bool) -> void:
	for child in get_children():
		if child.has_meta("warden_flight"):
			_clear_warden_fragment(child)


func _has_warden_chunk_nodes(base: Node3D) -> bool:
	for path in ["CoreAssembly", "JawL/InnerL", "JawR/InnerR"]:
		if not base.has_node(path):
			return false
	for i in 4:
		if base.find_child("ArmourSegment%d" % i, true, false) == null:
			return false
	return true


func _rig_warden_chunks(base: Node3D, rec: Dictionary) -> void:
	var posture: bool = rec.warden.fight() == "posture"
	rec.core.visible = false
	for i in 4:
		var segment := base.find_child("ArmourSegment%d" % i, true, false) as MeshInstance3D
		rec.segments.append(segment)
		if posture:
			rec.chunk_marks.append(_warden_chunk_mark(segment))
	for side in ["L", "R"]:
		var inner := base.get_node("Jaw%s/Inner%s" % [side, side]) as MeshInstance3D
		inner.visible = posture
		if posture:
			_paint_warden_inner(inner)
	if posture:
		# The caged heart replaces the kit's visible weak point; both use ancient_light.
		rec.weak.visible = false


func _paint_warden_inner(inner: MeshInstance3D) -> void:
	for surface in inner.mesh.get_surface_count():
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Palette.CHARCOAL if slot_of(inner.mesh, surface) == "rubber" else EventKinds.role_color("rust").lerp(Palette.CHARCOAL, 0.55)
		mat.roughness = 0.95
		_surface_material(inner, surface, mat)


func _warden_chunk_mark(segment: MeshInstance3D) -> Node3D:
	var mark := Node3D.new()
	mark.name = "ChunkCrack"
	var bounds := segment.mesh.get_aabb()
	var centre := bounds.get_center()
	var normal := Vector3(centre.x + 2.2, 0, centre.z).normalized()
	mark.position = centre
	mark.basis = Basis.looking_at(-normal)
	segment.add_child(mark)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = EventKinds.role_color("neutral")
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 1.2
	var points := [Vector2(-0.22, 0.5), Vector2(0.1, 0.17), Vector2(-0.1, -0.12), Vector2(0.2, -0.5)]
	for i in 3:
		var stroke := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.09, points[i].distance_to(points[i + 1]), 0.03)
		stroke.mesh = mesh
		stroke.material_override = mat
		var mid: Vector2 = (points[i] + points[i + 1]) * 0.5
		stroke.position = Vector3(mid.x, mid.y, 0)
		var direction: Vector2 = points[i + 1] - points[i]
		stroke.rotation.z = -atan2(direction.x, direction.y)
		mark.add_child(stroke)
		_fit_warden_stroke(stroke, segment, segment.mesh.get_faces())
	mark.visible = false
	return mark


func _update_warden_chunks(rec: Dictionary) -> void:
	var warden = rec.warden
	if warden.fight() != "posture" or rec.get("body") != null:
		return
	var lost: int = 4 - warden.chunks_left()
	var seen: int = 4 - rec.chunks_seen
	for i in range(seen, lost):
		_throw_warden_segment(rec, i)
	rec.chunks_seen = warden.chunks_left()
	for i in 4:
		rec.segments[i].visible = i >= lost
		var mark: Node3D = rec.chunk_marks[i]
		mark.visible = i == lost and warden.chunk_cracked()
		var color := EventKinds.state_color("chunk_shatter") if warden.staggered() else EventKinds.role_color("neutral")
		for stroke in mark.get_children():
			var mat: StandardMaterial3D = stroke.material_override
			mat.albedo_color = color
			mat.emission = color


func _throw_warden_segment(rec: Dictionary, index: int) -> void:
	var segment: MeshInstance3D = rec.segments[index]
	# A stub boss's Warden can die while its body is out of the tree: there is nothing to throw from.
	if not is_inside_tree() or not is_instance_valid(segment) or not segment.is_inside_tree():
		return
	var fragment := MeshInstance3D.new()
	fragment.name = "WardenFragment%d" % index
	fragment.mesh = segment.mesh
	for surface in segment.mesh.get_surface_count():
		# Keep fragment materials alive with the hook, including after a copy is freed.
		var slot := slot_of(segment.mesh, surface)
		var key := "warden_fragment:" + slot
		if not _materials.has(key):
			var mat := material(slot).duplicate() as StandardMaterial3D
			mat.emission_enabled = false
			_materials[key] = mat
		_surface_material(fragment, surface, _materials[key])
	add_child(fragment)
	fragment.global_transform = segment.global_transform
	var centre := segment.to_global(segment.mesh.get_aabb().get_center())
	var normal: Vector3 = (centre - rec.base.global_position) * Vector3(1, 0, 1)
	normal = normal.normalized()
	var flight := {"node": fragment, "start": fragment.global_transform, "normal": normal, "centre": centre,
		"born": Engine.get_physics_frames(), "seconds": 0.0}
	rec.flights.append(flight)
	fragment.set_meta("warden_flight", flight)
	fragment.tree_exiting.connect(_clear_warden_fragment.bind(fragment), CONNECT_ONE_SHOT)
	_warden_fragments.append(fragment)
	# One stepper for every copy in flight: a signal holds one connection per method,
	# whatever is bound to it, so a second copy cannot connect its own.
	if not get_tree().physics_frame.is_connected(_step_warden_fragments):
		get_tree().physics_frame.connect(_step_warden_fragments)


func _step_warden_fragments() -> void:
	for fragment in _warden_fragments.duplicate():
		if not is_instance_valid(fragment):
			_warden_fragments.erase(fragment)
			continue
		var flight: Dictionary = fragment.get_meta("warden_flight")
		flight.seconds = float(Engine.get_physics_frames() - flight.born) / Engine.physics_ticks_per_second
		_move_warden_fragment(flight.seconds, flight)
		if flight.seconds >= 0.55:
			_clear_warden_fragment(fragment)
	_rest_warden_fragments()


func _clear_warden_fragment(fragment: MeshInstance3D) -> void:
	_warden_fragments.erase(fragment)
	if is_instance_valid(fragment) and not fragment.is_queued_for_deletion():
		fragment.queue_free()
	_rest_warden_fragments()


func _rest_warden_fragments() -> void:
	if _warden_fragments.is_empty() and is_inside_tree() and get_tree().physics_frame.is_connected(_step_warden_fragments):
		get_tree().physics_frame.disconnect(_step_warden_fragments)


func _move_warden_fragment(seconds: float, flight: Dictionary) -> void:
	if not is_instance_valid(flight.node):
		return
	var pose: Transform3D = flight.start
	pose.origin += flight.normal * (14.0 * seconds) + Vector3.DOWN * (18.0 * seconds * seconds)
	var turn := Basis(flight.normal.cross(Vector3.UP), seconds * 5.0)
	var offset: Vector3 = flight.centre - flight.start.origin
	pose.origin += offset - turn * offset
	pose.basis = turn * pose.basis
	flight.node.global_transform = pose
	# Hidden after 0.18 s so the copy cannot block the core.
	flight.node.visible = seconds < 0.18


func _forget_warden(id: int) -> void:
	if _wardens.has(id):
		var rec: Dictionary = _wardens[id]
		_update_warden_chunks(rec)
		_restore_warden(rec, rec.warden.fight() == "posture" and rec.warden.chunks_left() == 0)
		_wardens.erase(id)


func _restore_warden(rec: Dictionary, keep_flights := false) -> void:
	if not keep_flights:
		for flight in rec.flights:
			if is_instance_valid(flight.node):
				_clear_warden_fragment(flight.node)
	if not _mast.is_empty() and is_instance_valid(rec.warden) and _mast.owner == rec.warden.get_instance_id():
		_restore_mast()
	for item in rec.hidden:
		if is_instance_valid(item.mesh):
			item.mesh.layers = item.layers
			item.mesh.cast_shadow = item.shadow
	if is_instance_valid(rec.warden):
		for crack in rec.cracks:
			rec.warden._cracks.erase(crack)
	if is_instance_valid(rec.base):
		rec.base.queue_free()


func _dress_mast(warden) -> void:
	if not is_inside_tree() or not is_instance_valid(warden) or not warden.is_inside_tree():
		return
	if ctx == null or ctx.flow == null or ctx.flow.warden != warden or not _wardens.has(warden.get_instance_id()):
		return
	if not _mast.is_empty() and _mast.owner == warden.get_instance_id():
		return
	_restore_mast()
	var beacon = ctx.flow.beacon
	if not is_instance_valid(beacon):
		return
	if beacon.clamp_seat() != null:
		_clamp_lantern(warden, beacon.clamp_seat())
		return
	for child in beacon.get_children():
		if not child is MeshInstance3D or not child.mesh is CylinderMesh:
			continue
		var cylinder: CylinderMesh = child.mesh
		if not is_equal_approx(cylinder.height, beacon.MAST_HEIGHT):
			continue
		var centre: Vector3 = child.to_local(warden.family_point_at())
		if Vector2(centre.x, centre.z).length() > 0.001 or not child.global_basis.get_scale().is_equal_approx(Vector3.ONE):
			return
		var low := centre.y - 1.45
		var high := centre.y + 1.45
		var half := cylinder.height * 0.5
		if low <= -half or high >= half:
			return
		var support := Node3D.new()
		support.name = "HeroMastSupport"
		child.add_child(support)
		_mast = {"owner": warden.get_instance_id(), "mesh": child, "root": support, "layers": child.layers, "shadow": child.cast_shadow}
		for span in [Vector2(-half, low), Vector2(high, half)]:
			var segment := cylinder.duplicate() as CylinderMesh
			segment.height = span.y - span.x
			segment.bottom_radius = _mast_radius(cylinder, span.x)
			segment.top_radius = _mast_radius(cylinder, span.y)
			var visual := _mast_visual(segment, support, child)
			visual.position.y = (span.x + span.y) * 0.5
		for side in [-1.0, 1.0]:
			var points := [Vector3(side * _mast_radius(cylinder, low), low, 0), Vector3(side * 1.5, centre.y - 0.8, 0), Vector3(side * 1.5, centre.y + 0.8, 0), Vector3(side * _mast_radius(cylinder, high), high, 0)]
			for i in 3:
				var start: Vector3 = points[i]
				var end: Vector3 = points[i + 1]
				var beam := BoxMesh.new()
				beam.size = Vector3(0.12, start.distance_to(end), 0.12)
				var visual := _mast_visual(beam, support, child)
				visual.position = (start + end) * 0.5
				visual.rotation.z = -atan2(end.x - start.x, end.y - start.y)
		child.layers = 0
		child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return


# The lantern beacon is one authored mesh, and its recipe keeps every family's weak point clear of it around
# the clamp seat (tools/blender/lantern_beacon.py socket_clamp), so the Warden sitting on the seat owns the
# clamp and nothing is cut or added.
func _clamp_lantern(warden, seat: Node3D) -> void:
	if warden.global_position.distance_to(seat.global_position) > 0.01:
		return
	_mast = {"owner": warden.get_instance_id(), "mesh": null, "root": null, "seat": seat}


func _mast_radius(cylinder: CylinderMesh, height: float) -> float:
	return lerpf(cylinder.bottom_radius, cylinder.top_radius, (height + cylinder.height * 0.5) / cylinder.height)


func _mast_visual(mesh: Mesh, parent: Node3D, original: MeshInstance3D) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = original.material_override
	visual.layers = original.layers
	visual.cast_shadow = original.cast_shadow
	parent.add_child(visual)
	return visual


func _restore_mast() -> void:
	if _mast.is_empty():
		return
	if is_instance_valid(_mast.mesh):
		_mast.mesh.layers = _mast.layers
		_mast.mesh.cast_shadow = _mast.shadow
	if is_instance_valid(_mast.root):
		_mast.root.get_parent().remove_child(_mast.root)
		_mast.root.queue_free()
	_mast.clear()


## Carried sandstone shell beside HeroWorkshop: visual only, no collision, shares the barge's
## transforms. One mesh, one material: the dry cliff rock calculation (sandstone.gdshader,
## cliff_only) with its pattern anchored in Barge-local metres so it rides the stone.
func _dress_shelter(barge: Node) -> void:
	if barge.has_node("HeroShelter"):
		return
	var shelter := _scene("res://assets/models/moss_shelter.glb")
	if shelter == null:
		return
	shelter.name = "HeroShelter"
	if not _materials.has("moss_sandstone"):
		var stone := ShaderMaterial.new()
		stone.shader = preload("res://src/presentation/sandstone.gdshader")
		stone.set_shader_parameter("cliff_only", true)
		stone.set_shader_parameter("local_pattern", true)
		_materials["moss_sandstone"] = stone
	for node in shelter.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = _materials["moss_sandstone"]
	barge.add_child(shelter)


# moss_workshop.glb carries its own domed jukebox cabinet in the CabinDress mesh at the teal pad (Barge space
# x -6.99..-4.85, y 0..3.22, z 7.91..9.29), and it enclosed the recipe jukebox bay.gd places there. Andrew chose the
# recipe jukebox (2026-10-09, task #7), so the dressing draws without every triangle wholly inside this box; the
# apron's corners (x -7.25/-4.75, z 5.75/8.25) lie outside it, so the pad stays.
const WORKSHOP_JUKEBOX := AABB(Vector3(-7.2, -0.05, 7.85), Vector3(2.4, 3.4, 1.5))


# A copy of mesh without the triangles wholly inside WORKSHOP_JUKEBOX (xform places mesh in Barge space); same
# surfaces, materials and names. Built once per source mesh.
func _without_jukebox(mesh: Mesh, xform: Transform3D) -> Mesh:
	var key := "workshop_no_jukebox#%d" % mesh.get_instance_id()
	if _meshes.has(key):
		return _meshes[key]
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for t in range(0, index.size(), 3):
			var inside := true
			for k in 3:
				inside = inside and WORKSHOP_JUKEBOX.has_point(xform * verts[index[t + k]])
			if not inside:
				kept.append_array([index[t], index[t + 1], index[t + 2]])
		arrays[Mesh.ARRAY_INDEX] = kept
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(s, mesh.surface_get_material(s))
		out.surface_set_name(s, (mesh as ArrayMesh).surface_get_name(s) if mesh is ArrayMesh else "")
	_meshes[key] = out
	return out


func _dress_bay() -> void:
	if ctx == null or not is_inside_tree():
		return
	var bay: Node = ctx.root.find_child("MossBay", true, false)
	if bay == null:
		return
	var cabin: Node = bay.find_child("MossCabin", true, false)
	var barge: Node = bay.find_child("Barge", true, false)
	if cabin == null or barge == null or barge.has_node("HeroWorkshop"):
		return
	var workshop := _scene("res://assets/models/moss_workshop.glb")
	if workshop == null:
		return
	workshop.name = "HeroWorkshop"
	for node in workshop.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.mesh = _without_jukebox(mi.mesh, mi.transform)
	paint(workshop, {"class": Palette.AMBER})
	barge.add_child(workshop)
	_dress_shelter(barge)
	for child in cabin.get_children():
		if child is MeshInstance3D:
			hide_placeholder(child)
	# The old shutter and shelf occupy the same cabin front; keep their gameplay owner.
	for child in barge.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh and child.position.x < -13.0 and child.position.y < 6.0:
			hide_placeholder(child)

	var pool := MeshInstance3D.new()
	pool.name = "BakedLamplight"
	var quad := QuadMesh.new()
	quad.size = Vector2(4.0, 7.0)
	pool.mesh = quad
	pool.rotation.x = -PI * 0.5
	pool.position = Vector3(-12.8, 0.06, 0)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _materials.has("bay_lamplight"):
		var glow := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
void fragment() {
	float edge = max(0.0, 1.0 - length((UV - vec2(0.5)) * 2.0));
	ALBEDO = vec3(0.75, 0.34, 0.09);
	ALPHA = edge * edge * 0.42;
}
"""
		glow.shader = shader
		_materials["bay_lamplight"] = glow
	pool.material_override = _materials["bay_lamplight"]
	barge.add_child(pool)
	# One tightly bounded shadowless amber light under the roof (LIGHTING-TARGETS, Moss).
	var lamp := OmniLight3D.new()
	lamp.name = "WorkshopWarmFill"
	lamp.light_color = Color("ffc982")
	lamp.light_energy = 7.0
	lamp.omni_range = 8.0
	lamp.omni_attenuation = 1.3
	lamp.shadow_enabled = false
	lamp.position = Vector3(-12.4, 3.0, 0.0)
	barge.add_child(lamp)
	# A second amber source up under the roof and shutter, so the upper interior reads warm.
	var upper := OmniLight3D.new()
	upper.name = "WorkshopWarmFillUpper"
	upper.light_color = Color("ffbb70")
	upper.light_energy = 4.5
	upper.omni_range = 5.0
	upper.omni_attenuation = 1.2
	upper.shadow_enabled = false
	upper.position = Vector3(-12.5, 5.2, 0.0)
	barge.add_child(upper)
