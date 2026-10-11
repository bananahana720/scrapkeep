extends Node

const Palette := preload("res://src/core/palette.gd")
const WardenLook := preload("res://src/combat/warden_look.gd")
const WardenKit := preload("res://src/combat/warden_kit.gd")
const WARDEN_BASE := "res://assets/models/warden_clamp_base.glb"
const WARDEN_KITS := {"reactor": "reactor", "swarm": "hive", "mind": "mind"}
# Presentation-only mantles by stage, never by warden_variant: both Highdraft stages carry
# mind/choir in alpha_defs, so only the stage tells the hand from the choir. Each row names the
# family it fits; a mismatch mounts nothing. Stages 1 and 2 stay bare.
const WARDEN_MANTLES := {
	3: {"family": "reactor", "path": "res://assets/models/warden_mantle_meltdown.glb"},
	4: {"family": "swarm", "path": "res://assets/models/warden_mantle_brood.glb"},
	5: {"family": "mind", "path": "res://assets/models/warden_mantle_hand.glb"},
	6: {"family": "mind", "path": "res://assets/models/warden_mantle_choir.glb"},
}
# Mount group name -> node path under HeroKit that receives the group's meshes.
const MANTLE_MOUNTS := {
	"MountBody": "Body", "MountVent0": "Vent0", "MountVent1": "Vent1", "MountVent2": "Vent2",
	"MountArmL": "ArmL", "MountArmR": "ArmR",
}

const EventKinds := preload("res://src/core/event_kinds.gd")
const Accretion := preload("res://src/build/accretion.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const PilotReactions := preload("res://src/presentation/pilot_reactions.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
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
# The shell's air-factor cue: a flat ring on the pod, in the row's colour and shape, that swells
# out on the rise and draws in on the return (a different motion from juice.gd's shell pulse,
# which means heft). No overlay: it is a mesh under the pod.
const AIR_CUE_ROW := "shell_air_shift"
const AIR_CUE_SECONDS := 0.45
const AIR_CUE_RISE := [0.9, 1.9]
const AIR_CUE_RETURN := [1.9, 0.9]
const AIR_CUE_RADIUS := 0.62
const AIR_CUE_NAME := "AirCue"

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
	# Warden mantle working throat: hazard, lit by the Warden's charge_fraction (see _update_mantle).
	"mantle_tool": {"color": Palette.HAZARD, "emit": 0.0, "rough": 0.5},
	"rarity": {"from": "rarity", "emit": 1.4, "rough": 0.5},
}

var ctx
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


static func topper_name(rarity: String) -> String:
	return "Topper_" + rarity


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	if ctx != null and ctx.get("profile") != null:
		profile = ctx.get("profile")
	name = "HeroAssets"
	_connect_pilot_events()
	_connect_shell_events()
	_prewarm_warden_strokes()
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
	var spec: Dictionary = SLOTS[slot]
	var color: Color = tint if spec.has("from") else spec["color"]
	var paint_tint := slot == "paint" and tint != Color.WHITE
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
			if slot == "paint":  # lift once, not a second tint
				var lift := Color(1.2, 1.2, 1.2) * (tint if paint_tint else Color.WHITE)
				mat.albedo_color = Color(lift.r, lift.g, lift.b, mat.albedo_color.a)
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
	return mat


static func slot_of(mesh: Mesh, surface: int) -> String:
	var mat := mesh.surface_get_material(surface)
	return mat.resource_name if mat != null else ""


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
				mi.set_surface_override_material(i, material(slot, tints.get(from, Color.WHITE)))
				if slot == "glass":
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func hide_placeholder(mi: GeometryInstance3D) -> void:
	mi.layers = 0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _scene(path: String) -> Node:
	if not _scenes.has(path):
		_scenes[path] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	var packed := _scenes[path] as PackedScene
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
	if profile == null:
		return ""
	return profile.equipped(id, "paint")


# The equipped shell variant's asset id for a pilot, or "" for the default cage.
func _equipped_variant(id: String) -> String:
	var worn := Cosmetics.worn(profile, id, "shell")
	return String(Cosmetics.row(worn).get("asset", "")) if worn != "" else ""


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
	var tints := {"class": player.class_color()}
	if tint != null:
		tints["paint"] = tint
	var shell := fit_shell_into(rolling, id, variant, _run_heft_class(), tints, player.juice_node())
	if shell.is_empty():
		return
	hide_placeholder(rolling)
	rec["shell"] = shell
	rec["core"] = shell.core
	rec["pod"] = shell.pod
	_fit_pilot(rec)
	if rec.get("pilot") != null and profile != null:
		var outfit := Cosmetics.worn(profile, id, "outfit")
		if outfit != "":
			fit_outfit(rec.pilot, outfit, tints)


func _process(delta: float) -> void:
	_reaction_clock += delta
	for key in _players.keys():
		var rec: Dictionary = _players[key]
		var player = rec["player"]
		if not is_instance_valid(player):
			_players.erase(key)
			continue
		_fit(rec)
		_steer_pod(rec, player, delta)
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
	if gyro != null and v.length() > 0.01:
		# Motion comes from the real velocity; the pilot remains on the upright Pod.
		gyro.rotate_object_local(Vector3.RIGHT, v.length() * delta / 0.98)
	var open := 1.0 if player.kit.gliding else 0.0
	for vane_name in ["VaneL", "VaneR"]:
		var vane := pod.get_node_or_null(vane_name) as Node3D
		if vane != null:
			var side := -1.0 if vane_name == "VaneL" else 1.0
			vane.rotation.z = lerpf(vane.rotation.z, -side * open * PI * 0.5, 1.0 - exp(-VANE_RATE * delta))


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
	_shell_assets_read = true
	return shell_assets


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
	return {"core": core, "pod": pod}


# Builds the shell under ball: HeroCore and HeroPod plus one holder per layer, painted with
# tints, layers shown up to heft_class. pod_parent receives HeroPod (the game's juice node);
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
	var rec := {"core": core, "pod": pod, "layers": {}, "variant": variant, "heft": 1, "shown": {}, "tints": tints}
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
					(core_holder if key == "core" else pod_holder).add_child(part)
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
					mi.set_surface_override_material(i, lit)
					swapped += 1
				elif not on and current == lit:
					mi.set_surface_override_material(i, calm)
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
	for part in scene.get_children():
		var bone := String(part.name)
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
		scene.remove_child(player)
		player.name = "%sAnimator" % kind.capitalize()
		player.set_meta("addon", kind)
		player.root_node = NodePath("..")
		skeleton.add_child(player)
		mounts.append(player)
	scene.free()
	return mounts


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

func _fit_pilot(rec: Dictionary) -> void:
	var fitted := fit_pilot_into(rec.pod, rec["class"], rec.player.class_color())
	if fitted.is_empty():
		return
	var pilot: Node3D = fitted.pilot
	var animator: AnimationPlayer = fitted.animator
	rec["animator"] = animator
	rec["pilot"] = pilot
	rec["reaction"] = ""
	rec["priority"] = -1
	rec["cooldowns"] = {}
	if animator != null:
		animator.animation_finished.connect(_pilot_finished.bind(rec.player.get_instance_id(), animator))
		_seat_pilot(rec)


# Seats the class's animated pilot in a pod: hides the shell's embedded placeholder pilot,
# adds the pilot glb as "AnimatedPilot" and paints it in the class colour. The game's
# _fit_pilot and the class card's preview both call it. Returns {pilot, animator}, or {}
# when the class has no pilot or its scene is unavailable.
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


func _connect_pilot_events() -> void:
	if ctx == null or ctx.events == null or not _reaction_connections.is_empty():
		return
	for info in ctx.events.get_signal_list():
		var event := String(info.name)
		if not PilotReactions.ROWS.has(event) or PilotReactions.ROWS[event].get("pending", false):
			continue
		var handlers := [_pilot_event_0, _pilot_event_1, _pilot_event_2, _pilot_event_3, _pilot_event_4]
		var callback: Callable = handlers[info.args.size()].bind(event)
		ctx.events.connect(event, callback)
		_reaction_connections.append({"bus": ctx.events, "event": event, "callback": callback})


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


func _on_pilot_event(event: String, args: Array) -> void:
	for rec in _players.values():
		if is_instance_valid(rec.player):
			react(rec.player, event, args)


# Returns acceptance for tests and capture tools. Never writes to the player.
func react(player: Node, event: String, args: Array = []) -> bool:
	if not PilotReactions.ROWS.has(event):
		return false
	var row: Dictionary = PilotReactions.ROWS[event]
	if row.get("pending", false):
		return false
	if row.has("near_arg") and (args.size() <= row.near_arg or args[row.near_arg] != true):
		return false
	var rec := shell_of(player)
	if rec.is_empty() or not is_instance_valid(rec.get("animator")):
		return false
	var clip := PilotReactions.clip_for(row, rec["class"])
	var animator: AnimationPlayer = rec.animator
	if not animator.has_animation(clip) or _reaction_clock < float(rec.cooldowns.get(clip, 0.0)):
		return false
	if rec.reaction != "" and int(row.priority) <= int(rec.priority):
		return false
	rec.reaction = clip
	rec.priority = row.priority
	rec.cooldowns[clip] = _reaction_clock + float(row.cooldown)
	# No blend on impact: the authored recoil must be visible in its first frames.
	animator.play(clip, 0.0)
	animator.advance(0.0)
	# A worn outfit's clip with the same name plays on the same trigger (Rivet's hood snaps down).
	var pilot_node = rec.get("pilot")
	if pilot_node != null and is_instance_valid(pilot_node):
		for outfit_player in pilot_node.find_children("OutfitAnimator", "AnimationPlayer", true, false):
			if outfit_player.has_animation(clip):
				outfit_player.play(clip, 0.0)
	return true


func _pilot_finished(_clip: StringName, player_id: int, animator: AnimationPlayer) -> void:
	var rec: Dictionary = _players.get(player_id, {})
	if not rec.is_empty() and rec.animator == animator:
		_seat_pilot(rec)


func _seat_pilot(rec: Dictionary) -> void:
	rec.animator.stop()
	for skeleton in rec.pilot.find_children("*", "Skeleton3D", true, false):
		skeleton.reset_bone_poses()
	rec.reaction = ""
	rec.priority = -1


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
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
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
				root.set_surface_override_material(i, mat)
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
			root.set_surface_override_material(i, rec.materials[key])
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
		inner.set_surface_override_material(surface, mat)


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
	if warden.fight() != "posture":
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
		fragment.set_surface_override_material(surface, _materials[key])
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
