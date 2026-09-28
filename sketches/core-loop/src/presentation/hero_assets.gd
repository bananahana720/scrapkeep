extends Node

const Palette := preload("res://src/core/palette.gd")
const Accretion := preload("res://src/build/accretion.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const ShellAnimator := preload("res://src/presentation/shell_animator.gd")

# V3 hero assets (VISUAL-LANGUAGE.md section 9). Dresses the greybox in the procedural
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
# Pod (the kit, the dome and the pilot) rides the juice node and stays upright, so the
# cockpit is always findable (AD-01, AC-01) and Rivet's fins and Kest's satchel bands
# keep their direction. Each fitted shell gets a shell_animator.gd, which yaws the pod to
# the heading and gives the shell its idle, motion, ability and reaction life. Chunks tuck under the pod's saddle as they
# roll through it instead of clipping the glass.

const SHELLS := {
	"pylon_engineer": "res://assets/models/shell_sable.glb",
	"runner_gunner": "res://assets/models/shell_rivet.glb",
	"demolitions_caster": "res://assets/models/shell_kest.glb",
}
const DEFAULT_CLASS := "pylon_engineer"
const CHUNKS_PATH := "res://assets/models/chunks.glb"
const GATE_PATH := "res://assets/models/reward_gate.glb"
# Accretion slot index bands: a young build carries small scrap, a heavy one large.
const CHUNK_BANDS := [[12, "small"], [24, "medium"], [Accretion.MAX_CHUNKS, "large"]]
# Cosine from straight up where a chunk starts tucking under the pod, and where it is gone.
const TUCK_FROM := 0.52
const TUCK_GONE := 0.74
# ANCIENT is still pending Andrew (VISUAL-LANGUAGE section 2); candidate A until W7
# adds Palette.ANCIENT.
const ANCIENT := Color("3d8bff")

const SLOTS := {
	"paint": {"color": Color.WHITE, "vertex": true, "rough": 0.8},
	"bare_metal": {"color": Palette.SAND, "lighten": 0.25, "metal": 0.6, "rough": 0.45},
	"rubber": {"color": Palette.CHARCOAL, "rough": 0.95},
	"class_accent": {"from": "class", "emit": 0.5, "rough": 0.5},
	"field": {"color": Palette.ARC, "emit": 1.6, "rough": 0.4},
	"glass": {"color": Color.WHITE, "alpha": 0.16, "rough": 0.04},
	"pilot": {"color": Color.WHITE, "vertex": true, "rough": 0.9},
	"fleet_paint": {"color": Palette.RUST, "rough": 0.8},
	"requisition_tag": {"color": Palette.BRASS, "metal": 0.5, "rough": 0.4},
	"ancient_enamel": {"color": Color.WHITE, "vertex": true, "rough": 0.55},
	"ancient_light": {"color": ANCIENT, "emit": 2.4, "rough": 0.3},
	"rarity": {"from": "rarity", "emit": 1.4, "rough": 0.5},
}

var ctx
var _materials := {}
var _scenes := {}
var _meshes := {}
var _players := {}
var _tucked: Array[MeshInstance3D] = []
var _warned := {}


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "HeroAssets"
	if ctx != null and ctx.player != null:
		attach_player(ctx.player)


func _enter_tree() -> void:
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var parent := node.get_parent()
	if parent == null:
		return
	if node is MeshInstance3D and parent.get_script() == Accretion:
		dress_chunk(node)
	elif node is Node3D and parent.get_script() == RewardGates:
		_dress_gate.call_deferred(node)


# --- materials ---------------------------------------------------------------------

func material(slot: String, tint := Color.WHITE) -> StandardMaterial3D:
	var key := "%s:%s" % [slot, tint.to_html()]
	if _materials.has(key):
		return _materials[key]
	var spec: Dictionary = SLOTS[slot]
	var color: Color = tint if spec.has("from") else spec["color"]
	color = color.lerp(Color.WHITE, spec.get("lighten", 0.0))
	var mat := StandardMaterial3D.new()
	mat.resource_name = slot
	mat.albedo_color = Color(color, spec.get("alpha", 1.0))
	mat.vertex_color_use_as_albedo = spec.get("vertex", false)
	mat.roughness = spec.get("rough", 0.8)
	mat.metallic = spec.get("metal", 0.0)
	if spec.has("alpha"):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.metallic_specular = 1.0
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
				mi.set_surface_override_material(i, material(slot, tints.get(from, Color.WHITE)))


static func hide_placeholder(mi: GeometryInstance3D) -> void:
	mi.layers = 0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _scene(path: String) -> Node:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return (_scenes[path] as PackedScene).instantiate()


# The mesh of the named node in a glb, loaded once.
func mesh_named(path: String, node_name: String) -> Mesh:
	var key := path + "#" + node_name
	if not _meshes.has(key):
		var scene := _scene(path)
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
	_players[player.get_instance_id()] = {"player": player, "class": "", "core": null, "pod": null}
	_fit(_players[player.get_instance_id()])
	for chunk in player.roll_node().get_children():
		if chunk.get_script() == Accretion:
			for child in chunk.get_children():
				if child is MeshInstance3D:
					dress_chunk(child)


static func class_id(player: Node) -> String:
	var def = player.get("class_def")
	return def.id if def != null and SHELLS.has(def.id) else DEFAULT_CLASS


func _fit(rec: Dictionary) -> void:
	var player: Node3D = rec["player"]
	var id := class_id(player)
	if rec["class"] == id:
		return
	for key in ["core", "pod"]:
		var old = rec[key]
		if old != null and is_instance_valid(old):
			old.get_parent().remove_child(old)
			old.queue_free()
	var rolling := player.roll_node().get_parent() as MeshInstance3D
	hide_placeholder(rolling)
	var shell := _scene(SHELLS[id])
	var core := shell.find_child("Core", true, false) as Node3D
	var pod := shell.find_child("Pod", true, false) as Node3D
	core.get_parent().remove_child(core)
	pod.get_parent().remove_child(pod)
	shell.free()
	var tints := {"class": player.class_color()}
	paint(core, tints)
	paint(pod, tints)
	# The animator binds by the glb's role names, before the pod and core take theirs here.
	var animator := ShellAnimator.new()
	animator.name = "ShellAnimator"
	animator.clock = _sixteenths
	animator.bind([core, pod], id, player, ctx.events if ctx != null else null)
	core.name = "HeroCore"
	pod.name = "HeroPod"
	pod.add_child(animator)
	rolling.add_child(core)
	player.juice_node().add_child(pod)
	rec["class"] = id
	rec["core"] = core
	rec["pod"] = pod
	rec["animator"] = animator


func _process(delta: float) -> void:
	for key in _players.keys():
		var rec: Dictionary = _players[key]
		var player = rec["player"]
		if not is_instance_valid(player):
			_players.erase(key)
			continue
		_fit(rec)
	_tuck_chunks()


# The band's position in sixteenths, so the shells pulse on its grid; -1 when silent.
func _sixteenths() -> float:
	var audio = get_parent().get("audio") if get_parent() != null else null
	var engine = audio.engine if audio != null else null
	if engine == null or engine.step_len <= 0:
		return -1.0
	return float(engine.clock - engine.grid_origin) / float(engine.step_len)


# The shell the player wears, for tests and tools: {class, core, pod, animator} or {}.
func shell_of(player: Node) -> Dictionary:
	return _players.get(player.get_instance_id(), {})


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
	var tints := {"rarity": RewardGates.rarity_color(rarity)}
	var topper := gate.get_node_or_null("Topper") as MeshInstance3D
	for child in gate.get_children():
		if child is MeshInstance3D:
			hide_placeholder(child)
	var arch := MeshInstance3D.new()
	arch.name = "HeroArch"
	arch.mesh = mesh_named(GATE_PATH, "Arch")
	gate.add_child(arch)
	paint(arch, tints)
	if topper != null:
		for child in topper.get_children():
			if child is GeometryInstance3D:
				hide_placeholder(child)
		var hero_topper := MeshInstance3D.new()
		hero_topper.name = "HeroTopper"
		hero_topper.mesh = mesh_named(GATE_PATH, "Topper_" + rarity)
		topper.add_child(hero_topper)
		paint(hero_topper, tints)
	for child in gate.get_children():
		if child is Sprite3D and String(child.name).begins_with("Glyph"):
			var plate := MeshInstance3D.new()
			plate.name = "HeroPlate" + String(child.name).trim_prefix("Glyph")
			plate.mesh = mesh_named(GATE_PATH, "GlyphPlate1")
			plate.position = (child as Sprite3D).position + Vector3(0.0, 0.0, -0.14)
			gate.add_child(plate)
			paint(plate, tints)
