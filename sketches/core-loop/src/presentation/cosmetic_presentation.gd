extends Node3D

const Cosmetics := preload("res://src/core/cosmetics.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const TRAIL_LIMIT := 24
const TRAIL_DISTANCE := 1.8
const TRAIL_INTERVAL := 0.03

var ctx
var hero
var assets := Cosmetics.asset_paths()
var resolver := Cosmetics.new()
var trail: Node3D
var _trail_id := ""
var _trail_clock := 0.0
var _cards: Array = []
var _decal := {}
var _companion := {}
var _art := Cosmetics.art_manifest()


func setup(context, hook) -> void:
	name = "CosmeticPresentation"
	ctx = context
	hero = hook
	trail = Node3D.new()
	trail.name = "BallTrail"
	trail.top_level = true
	add_child(trail)


func effective(pilot: String, slot: String) -> Dictionary:
	var profile = hero.profile
	if profile == null:
		return {}
	var owner := Cosmetics.owner_for(pilot, slot)
	var id: String = profile.equipped(owner, slot)
	var row := Cosmetics.row(id)
	if row.is_empty() or not Cosmetics.fits(id, owner, slot) or not (row["starter"] or profile.has_cosmetic(id)):
		return {}
	return resolver.resolve(id, assets)


func _process(delta: float) -> void:
	if ctx == null or ctx.player == null:
		return
	var rec: Dictionary = hero.shell_of(ctx.player)
	if rec.is_empty():
		return
	var pilot: String = rec["class"]
	_apply_decal(rec, effective(pilot, "decal"))
	_apply_companion(effective(pilot, "companion_paint"))
	_step_trail(delta, effective(pilot, "trail"))


func _detail(group: String, id: String) -> Dictionary:
	for entry in _art.get(group, []):
		if entry["id"] == id:
			return entry
	return {}


# Core's only surface is glass in the delivered shells. Compose a worn lower-shell
# paint patch into that surface, retaining its original glass response everywhere else.
func _apply_decal(rec: Dictionary, row: Dictionary) -> void:
	var core = rec.get("core")
	var key: String = row.get("asset", "")
	if _decal.get("core") == core and _decal.get("key", "") == key:
		return
	if not _decal.is_empty() and is_instance_valid(_decal["core"]):
		for saved in _decal["surfaces"]:
			saved["mesh"].set_surface_override_material(saved["surface"], saved["material"])
	_decal = {"core": core, "key": key, "surfaces": []}
	if core == null or row.is_empty():
		return
	var size: Array = _detail("decals", key.trim_suffix("_mask.png")).get("tile_size_m", [0.65, 0.65])
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D decal_mask : source_color, filter_linear_mipmap;
uniform vec4 decal_tint : source_color;
uniform vec4 patch_tint : source_color = vec4(0.141176, 0.164706, 0.156863, 1.0);
uniform vec2 tile_size;
varying vec3 shell_position;
void vertex() { shell_position = VERTEX; }
void fragment() {
	vec2 uv = vec2(shell_position.x, -(shell_position.y + 0.48)) / tile_size + vec2(0.5);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0) * step(0.35, shell_position.z);
	float patch = inside * step(length((uv - vec2(0.5)) * 2.0), 0.97);
	float ink = texture(decal_mask, clamp(uv, vec2(0.0), vec2(1.0))).a;
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
	ALBEDO = mix(vec3(0.86, 0.94, 1.0), mix(patch_tint.rgb, decal_tint.rgb, ink), patch);
	ALPHA = mix(0.05 + edge * 0.22, 1.0, patch);
	ROUGHNESS = mix(0.32, 0.8, patch);
	SPECULAR = mix(0.08 + edge * 0.5, 0.08, patch);
}
"""
	for mesh in _meshes(core):
		for surface in mesh.mesh.get_surface_count():
			var original: Material = mesh.get_active_material(surface)
			if original == null or not original.resource_name in ["glass", "paint"]:
				continue
			var mat := ShaderMaterial.new()
			mat.resource_name = "DecalMask"
			mat.shader = shader
			mat.set_shader_parameter("decal_mask", row["resource"])
			mat.set_shader_parameter("decal_tint", row["tint"])
			mat.set_shader_parameter("tile_size", Vector2(size[0], size[1]))
			_decal["surfaces"].append({"mesh": mesh, "surface": surface, "material": mesh.get_surface_override_material(surface)})
			mesh.set_surface_override_material(surface, mat)
	if _decal["surfaces"].is_empty():
		resolver._warn(key)


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.mesh != null:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out


# The assembled companion is one skinned mesh. Alpha in a private vertex-colour copy
# masks Hull/Deck enamel; the other painted pieces, witness and collars retain their RGB.
func _apply_companion(row: Dictionary) -> void:
	var body = hero.get_parent().get_node_or_null("CompanionBody")
	var model = body.get("_model") if body != null else null
	var key: String = row.get("asset", "")
	if _companion.get("model") == model and _companion.get("key", "") == key:
		return
	if not _companion.is_empty():
		for saved in _companion["meshes"]:
			if is_instance_valid(saved["node"]):
				saved["node"].mesh = saved["mesh"]
				for surface in saved["materials"]:
					saved["node"].set_surface_override_material(surface, saved["materials"][surface])
	_companion = {"model": model, "key": key, "meshes": []}
	if model == null or row.is_empty():
		return
	var shader := Shader.new()
	shader.code = """shader_type spatial;
uniform vec4 paint_tint : source_color;
uniform float paint_roughness;
void fragment() {
	ALBEDO = COLOR.rgb * mix(vec3(1.0), paint_tint.rgb, COLOR.a);
	ROUGHNESS = paint_roughness;
}
"""
	var delivered := row["resource"] as StandardMaterial3D
	for mesh in _meshes(model):
		var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		if mesh.skin == null or skeleton == null:
			continue
		var enamel_bones := []
		for bind in mesh.skin.get_bind_count():
			var bone := String(mesh.skin.get_bind_name(bind))
			if bone == "":
				var index := mesh.skin.get_bind_bone(bind)
				if index >= 0 and index < skeleton.get_bone_count():
					bone = skeleton.get_bone_name(index)
			if bone in ["Hull", "Deck"]:
				enamel_bones.append(bind)
		if enamel_bones.is_empty():
			continue
		var copy := ArrayMesh.new()
		var saved := {"node": mesh, "mesh": mesh.mesh, "materials": {}}
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var original: Material = mesh.get_active_material(surface)
			var paint := original != null and original.resource_name == "paint"
			if paint:
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR].duplicate()
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				if colors.is_empty() or bones.is_empty() or weights.size() != bones.size():
					paint = false
				else:
					var stride := bones.size() / colors.size()
					for vertex in colors.size():
						var coverage := 0.0
						for joint in stride:
							var index: int = vertex * stride + joint
							if bones[index] in enamel_bones:
								coverage += weights[index]
						colors[vertex].a = coverage
					arrays[Mesh.ARRAY_COLOR] = colors
			copy.add_surface_from_arrays(mesh.mesh.surface_get_primitive_type(surface), arrays, [], {}, mesh.mesh.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			copy.surface_set_material(surface, mesh.mesh.surface_get_material(surface))
			if paint:
				var mat := ShaderMaterial.new()
				mat.resource_name = "CompanionPaint"
				mat.shader = shader
				mat.set_shader_parameter("paint_tint", delivered.albedo_color)
				mat.set_shader_parameter("paint_roughness", delivered.roughness)
				saved["materials"][surface] = mesh.get_surface_override_material(surface)
				mesh.set_surface_override_material(surface, mat)
		mesh.mesh = copy
		_companion["meshes"].append(saved)
	if _companion["meshes"].is_empty():
		resolver._warn(key)


func _clear_cards() -> void:
	for card in _cards:
		card["node"].free()
	_cards.clear()
	_trail_clock = 0.0


func _step_trail(delta: float, row: Dictionary) -> void:
	var key: String = row.get("asset", "")
	if key != _trail_id:
		_clear_cards()
		_trail_id = key
	var player = ctx.player
	var velocity: Vector3 = player.planar_velocity()
	if row.is_empty() or not ctx.flow.in_play() or get_tree().paused or not player.state.grounded or velocity.length() < 1.0:
		_clear_cards()
		return
	var ball: Vector3 = player.shown_position()
	for card in _cards.duplicate():
		card["age"] += delta
		var node: Node3D = card["node"]
		if card["age"] >= card["life"] or Vector2(node.global_position.x - ball.x, node.global_position.z - ball.z).length() > TRAIL_DISTANCE:
			node.free()
			_cards.erase(card)
			continue
		var obscures := _near_threat(node.global_position)
		for mesh in _meshes(node):
			mesh.transparency = 1.0 if obscures else float(card["age"]) / float(card["life"])
	_trail_clock += delta
	if _trail_clock < TRAIL_INTERVAL or _cards.size() >= TRAIL_LIMIT:
		return
	_trail_clock = 0.0
	if _near_threat(ball):
		return
	var packed := row["resource"] as PackedScene
	var node := packed.instantiate() as Node3D
	if node == null:
		resolver._warn(key)
		return
	var meshes := _meshes(node)
	if meshes.is_empty() or not node.find_children("*", "CollisionObject3D", true, false).is_empty():
		node.free()
		resolver._warn(key)
		return
	trail.add_child(node)
	node.global_position = ball - velocity.normalized() * 0.12
	node.global_position.y = ball.y - Tuning.RADIUS + 0.04
	node.rotation.y = atan2(-velocity.x, -velocity.z)
	for mesh in meshes:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for animator in node.find_children("*", "AnimationPlayer", true, false):
		for clip in animator.get_animation_list():
			if clip != "RESET":
				animator.play(clip)
				break
	var life := minf(0.45, float(_detail("trails", key).get("duration_s", 0.35)))
	_cards.append({"node": node, "age": 0.0, "life": life})


func _near_threat(point: Vector3) -> bool:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node3D and enemy.global_position.distance_to(point) < 3.0:
			return true
	return false
