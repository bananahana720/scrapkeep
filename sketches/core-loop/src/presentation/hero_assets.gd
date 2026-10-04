extends Node

const Palette := preload("res://src/core/palette.gd")
const WardenLook := preload("res://src/combat/warden_look.gd")
const WardenKit := preload("res://src/combat/warden_kit.gd")
const WARDEN_BASE := "res://assets/models/warden_clamp_base.glb"
const WARDEN_KITS := {"reactor": "reactor", "swarm": "hive", "mind": "mind"}

const EventKinds := preload("res://src/core/event_kinds.gd")
const Accretion := preload("res://src/build/accretion.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const PilotReactions := preload("res://src/presentation/pilot_reactions.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const PILOTS := {
	"runner_gunner": "res://assets/models/pilot_rivet_anim.glb",
	"pylon_engineer": "res://assets/models/pilot_sable_anim.glb",
	"demolitions_caster": "res://assets/models/pilot_kest_anim.glb",
	"tarn": "res://assets/models/pilot_rivet_anim.glb",  # placeholder: Tarn wears Rivet's pilot until the claw kit lands
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
	"tarn": "res://assets/models/world_one/shell_rivet.glb",  # placeholder: Rivet's shell
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


# The gate glb still names its toppers by the pre-wave-3 ladder. Relic and evolved reuse
# Topper_rare_plus until tools/blender/reward_gate.py is regenerated with the new names (follow-up).
const TOPPER_NAMES := {"relic": "rare_plus", "evolved": "rare_plus"}


static func topper_name(rarity: String) -> String:
	return "Topper_" + String(TOPPER_NAMES.get(rarity, rarity))


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	if ctx != null and ctx.get("profile") != null:
		profile = ctx.get("profile")
	name = "HeroAssets"
	_connect_pilot_events()
	_prewarm_warden_strokes()
	_dress_bay.call_deferred()
	if ctx != null and ctx.player != null:
		attach_player(ctx.player)
	if ctx != null and ctx.get("build") != null and ctx.build.has_signal("shell_air_changed"):
		ctx.build.shell_air_changed.connect(air_cue)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_node("WardenLook"):
			_dress_warden.call_deferred(enemy)


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


func _fit(rec: Dictionary) -> void:
	var player: Node3D = rec["player"]
	var id := class_id(player)
	var paint_id := _equipped_paint(id)
	var tint = paint_tint(id, paint_id) if paint_id != "" else null
	if rec["class"] == id and rec.get("tint") == tint:
		return
	for key in ["core", "pod"]:
		var old = rec[key]
		if old != null and is_instance_valid(old):
			old.get_parent().remove_child(old)
			old.queue_free()
		rec[key] = null
	rec["animator"] = null
	rec["class"] = id
	rec["tint"] = tint
	var rolling := player.roll_node().get_parent() as MeshInstance3D
	rolling.layers = rec.layers
	rolling.cast_shadow = rec.shadow
	var shell := _scene(SHELLS[id])
	if shell == null:
		return
	var core := shell.find_child("Core", true, false) as Node3D
	var pod := shell.find_child("Pod", true, false) as Node3D
	if core == null or pod == null:
		shell.free()
		_warn_once("scene:" + SHELLS[id], "hero_assets: scene '%s' lacks Core/Pod; keeping primitive fallback" % SHELLS[id])
		return
	core.get_parent().remove_child(core)
	pod.get_parent().remove_child(pod)
	shell.free()
	core.name = "HeroCore"
	pod.name = "HeroPod"
	var tints := {"class": player.class_color()}
	if tint != null:
		tints["paint"] = tint
	paint(core, tints)
	paint(pod, tints)
	hide_placeholder(rolling)
	rolling.add_child(core)
	player.juice_node().add_child(pod)
	rec["core"] = core
	rec["pod"] = pod
	_fit_pilot(rec)


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


# --- cosmetic pilot reactions ------------------------------------------------------

func _fit_pilot(rec: Dictionary) -> void:
	var pilot := _scene(PILOTS[rec["class"]])
	if pilot == null:
		return
	pilot.name = "AnimatedPilot"
	var pod: Node3D = rec.pod
	var placeholder := pod.find_child("Pilot", true, false) as GeometryInstance3D
	if placeholder != null:
		hide_placeholder(placeholder)
	pod.add_child(pilot)
	paint(pilot, {"class": rec.player.class_color()})
	var animator := pilot.find_child("AnimationPlayer", true, false) as AnimationPlayer
	rec["animator"] = animator
	rec["pilot"] = pilot
	rec["reaction"] = ""
	rec["priority"] = -1
	rec["cooldowns"] = {}
	if animator != null:
		animator.animation_finished.connect(_pilot_finished.bind(rec.player.get_instance_id(), animator))
		_seat_pilot(rec)


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
		"chunks_seen": 4, "core": base.get_node("CoreAssembly")}
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
	warden.add_child(base)
	# Conditional cool fill (LIGHTING-TARGETS, Warden): shadowless, 9 m, low energy, so the
	# front barrel and left armour separate from the shared warm key.
	var cool := OmniLight3D.new()
	cool.name = "WardenCoolFill"
	cool.light_color = Color("a8c2d4")
	cool.light_energy = 0.9
	cool.omni_range = 9.0
	cool.omni_attenuation = 1.2
	cool.shadow_enabled = false
	cool.light_specular = 0.0
	cool.position = Vector3(-4.5, 3.5, -5.5)
	base.add_child(cool)
	for child in warden._look.get_children():
		if child is MeshInstance3D and child.material_override == warden._look.body_material and child != warden._look._arm:
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
