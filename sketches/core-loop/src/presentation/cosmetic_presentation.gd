extends Node3D

const Cosmetics := preload("res://src/core/cosmetics.gd")
const CosmeticWear := preload("res://src/core/cosmetic_wear.gd")
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
var _spare: Array = []
var _decal := {}
var _companion := {}
var _art := Cosmetics.art_manifest()
var _threats: Array[Vector3] = []
var _skin := {}
var _bay := {}
var _bay_clock := 0.0
var set_piece := false
var _decal_materials := {}
var _decal_shaders := {}


func setup(context, hook) -> void:
	name = "CosmeticPresentation"
	ctx = context
	hero = hook
	var events = ctx.get("events")
	trail = Node3D.new()
	trail.name = "BallTrail"
	trail.top_level = true
	add_child(trail)
	if events != null:
		_connect_optional(events, "ultimate_started", _on_set_piece.bind(true))
		_connect_optional(events, "ultimate_landed", _on_set_piece.bind(false))
		_connect_optional(events, "ultimate_cancelled", _on_set_piece.bind(false))


func _connect_optional(bus: Object, signal_name: String, callback: Callable) -> void:
	if not bus.has_signal(signal_name):
		return
	for info in bus.get_signal_list():
		if String(info.name) == signal_name:
			bus.connect(signal_name, callback.unbind(info.args.size()) if info.args.size() > 0 else callback)
			return


func _on_set_piece(flying: bool) -> void:
	set_piece = flying


func effective(pilot: String, slot: String) -> Dictionary:
	var profile = hero.profile
	if profile == null:
		return {}
	var id := CosmeticWear.worn(profile, Cosmetics.owner_for(pilot, slot), slot)
	if id == "" or Cosmetics.is_pending(id):
		return {}
	return resolver.resolve(id, assets)


func _process(delta: float) -> void:
	if ctx == null or ctx.player == null:
		return
	var rec: Dictionary = hero.shell_of(ctx.player)
	if rec.is_empty():
		_clear_cards()
		return
	var pilot: String = rec["class"]
	_apply_decal(rec, effective(pilot, "decal"))
	_apply_companion(effective(pilot, "companion_paint"))
	_apply_companion_skin(effective(pilot, "companion_skin"))
	_bay_clock += delta
	_apply_bay_decor(effective(pilot, "bay_decor"))
	_step_trail(delta, effective(pilot, "trail"))


func _apply_companion_skin(row: Dictionary) -> void:
	var body = hero.get_parent().get_node_or_null("CompanionBody")
	var model = body.get("_model") if body != null else null
	var key: String = row.get("asset", "")
	if _skin.get("model") == model and _skin.get("key", "") == key:
		return
	_skin = {"model": model, "key": key}
	if model != null and is_instance_valid(model):
		fit_companion_skin(model, _id_of(row))


func fit_companion_skin(model: Node3D, id: String) -> Array:
	return hero.fit_companion_skin(model, id)


func _apply_bay_decor(row: Dictionary) -> void:
	var key: String = row.get("asset", "")
	var workshop = _bay.get("workshop")
	if _bay.get("key", "") == key and (key == "" or (workshop != null and is_instance_valid(workshop))):
		return
	if _bay_clock < 1.0 and _bay.get("key", "") == key:
		return
	_bay_clock = 0.0
	workshop = ctx.root.find_child("HeroWorkshop", true, false) if ctx.get("root") != null else null
	if workshop == null:
		_bay = {"key": key, "workshop": null}
		return
	_bay = {"key": key, "workshop": workshop}
	hero.fit_bay_decor(workshop, _id_of(row))


static func _id_of(row: Dictionary) -> String:
	for id in Cosmetics.ROWS:
		if Cosmetics.ROWS[id].get("asset", "") == row.get("asset", "-") and Cosmetics.ROWS[id]["slot"] == row.get("slot", ""):
			return id
	return ""


func _detail(group: String, id: String) -> Dictionary:
	for entry in _art.get(group, []):
		if entry["id"] == id:
			return entry
	return {}


const PLATE_TILE_M := 0.36
const PLATE_SHADER := """shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D decal_mask : source_color, filter_linear_mipmap;
uniform vec4 decal_tint : source_color;
uniform vec4 patch_tint : source_color = vec4(0.141176, 0.164706, 0.156863, 1.0);
void fragment() {
	float ink = texture(decal_mask, UV).a;
	ALBEDO = mix(patch_tint.rgb, decal_tint.rgb, ink);
	ROUGHNESS = 0.8;
}
"""


func _apply_decal(rec: Dictionary, row: Dictionary) -> void:
	var core = rec.get("core")
	var pod = rec.get("pod")
	var key: String = row.get("asset", "")
	if _decal.get("core") == core and _decal.get("pod") == pod and _decal.get("key", "") == key:
		return
	if not _decal.is_empty():
		for saved in _decal["surfaces"]:
			if is_instance_valid(saved["mesh"]):
				saved["mesh"].set_surface_override_material(saved["surface"], saved["material"])
	_decal = {"core": core, "pod": pod, "key": key, "surfaces": []}
	if core == null or row.is_empty():
		return
	var plate = pod.find_child("DecalPlate", true, false) if pod != null and is_instance_valid(pod) else null
	if plate != null:
		var plate_mat := decal_material("plate", row)
		for mesh in _meshes(plate):
			for surface in mesh.mesh.get_surface_count():
				_decal["surfaces"].append({"mesh": mesh, "surface": surface, "material": mesh.get_surface_override_material(surface)})
				mesh.set_surface_override_material(surface, plate_mat)
		if not _decal["surfaces"].is_empty():
			return
	var mat := decal_material("core", row)
	for mesh in _meshes(pod):
		var ring_band: bool = mesh.name == "WeaponRing"
		var gap_panel: bool = mesh.name == "Pod" and String(mesh.get_parent().name) in ["HeftC2", "HeftC3", "HeftC4", "HeftC5"]
		if not ring_band and not gap_panel:
			continue
		for surface in mesh.mesh.get_surface_count():
			var original: Material = mesh.get_active_material(surface)
			if original == null or original.resource_name != "paint":
				continue
			_decal["surfaces"].append({"mesh": mesh, "surface": surface, "material": mesh.get_surface_override_material(surface)})
			mesh.set_surface_override_material(surface, mat)
	if _decal["surfaces"].is_empty():
		resolver._warn(key)


func decal_material(placement: String, row: Dictionary) -> ShaderMaterial:
	var key: String = row.get("asset", "")
	var tint: Color = row.get("tint", Color.WHITE)
	var cache_key := "%s:%s:%s" % [placement, key, tint.to_html()]
	if _decal_materials.has(cache_key):
		return _decal_materials[cache_key]
	if not _decal_shaders.has(placement):
		var shader := Shader.new()
		shader.code = PLATE_SHADER if placement == "plate" else _core_decal_code()
		_decal_shaders[placement] = shader
	var mat := ShaderMaterial.new()
	mat.resource_name = "DecalMask"
	mat.shader = _decal_shaders[placement]
	mat.set_shader_parameter("decal_mask", row["resource"])
	mat.set_shader_parameter("decal_tint", tint)
	if placement == "core":
		var size: Array = _detail("decals", key.trim_suffix("_mask.png")).get("tile_size_m", [0.65, 0.65])
		mat.set_shader_parameter("tile_size", Vector2(size[0], size[1]))
	_decal_materials[cache_key] = mat
	return mat


static func _core_decal_code() -> String:
	return """shader_type spatial;
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


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.mesh != null:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out


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
			if paint and arrays[Mesh.ARRAY_COLOR] == null:
				resolver._warn(key)
				paint = false
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
		_retire(card)
	_cards.clear()
	_trail_clock = 0.0


func _retire(card: Dictionary) -> void:
	(card["node"] as Node3D).visible = false
	_spare.append(card)


func _drop_pool() -> void:
	_clear_cards()
	for card in _spare:
		card["node"].free()
	_spare.clear()


func _step_trail(delta: float, row: Dictionary) -> void:
	var key: String = row.get("asset", "")
	if key != _trail_id:
		_drop_pool()
		_trail_id = key
	var player = ctx.player
	var velocity: Vector3 = player.planar_velocity()
	var flying: bool = set_piece and not player.state.grounded
	if row.is_empty() or not ctx.flow.in_play() or get_tree().paused or not (player.state.grounded or flying) or (velocity.length() < 1.0 and not flying):
		_clear_cards()
		return
	var ball: Vector3 = player.shown_position()
	var threats := _threat_points()
	var index := _cards.size()
	while index > 0:
		index -= 1
		var card: Dictionary = _cards[index]
		card["age"] += delta
		var node: Node3D = card["node"]
		if card["age"] >= card["life"] or Vector2(node.global_position.x - ball.x, node.global_position.z - ball.z).length() > TRAIL_DISTANCE:
			_cards.remove_at(index)
			_retire(card)
			continue
		var obscures := _near_threat(node.global_position, threats)
		for mesh in card["meshes"]:
			mesh.transparency = 1.0 if obscures else float(card["age"]) / float(card["life"])
	_trail_clock += delta
	if _trail_clock < TRAIL_INTERVAL or _cards.size() >= TRAIL_LIMIT:
		return
	_trail_clock = 0.0
	if _near_threat(ball, threats):
		return
	var card := _take_card(row, key)
	if card.is_empty():
		return
	var node: Node3D = card["node"]
	node.visible = true
	node.global_position = ball - velocity.normalized() * 0.12
	node.global_position.y = ball.y if flying else ball.y - Tuning.RADIUS + 0.04
	node.rotation.y = atan2(-velocity.x, -velocity.z)
	for pair in card["clips"]:
		(pair[0] as AnimationPlayer).stop()
		(pair[0] as AnimationPlayer).play(pair[1])
	card["age"] = 0.0
	card["life"] = minf(0.45, float(_detail("trails", key).get("duration_s", 0.35)))
	_cards.append(card)


func _take_card(row: Dictionary, key: String) -> Dictionary:
	if not _spare.is_empty():
		var card: Dictionary = _spare.pop_back()
		for mesh in card["meshes"]:
			mesh.transparency = 0.0
		return card
	var packed := row["resource"] as PackedScene
	var node := packed.instantiate() as Node3D
	if node == null:
		resolver._warn(key)
		return {}
	var meshes := _meshes(node)
	if meshes.is_empty() or not node.find_children("*", "CollisionObject3D", true, false).is_empty():
		node.free()
		resolver._warn(key)
		return {}
	trail.add_child(node)
	for mesh in meshes:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var clips: Array = []
	for animator in node.find_children("*", "AnimationPlayer", true, false):
		for clip in animator.get_animation_list():
			if clip != "RESET":
				clips.append([animator, clip])
				break
	return {"node": node, "meshes": meshes, "clips": clips, "age": 0.0, "life": 0.0}


func _threat_points() -> Array[Vector3]:
	_threats.clear()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node3D:
			_threats.append(enemy.global_position)
	return _threats


func _near_threat(point: Vector3, threats: Array[Vector3]) -> bool:
	for at in threats:
		if at.distance_to(point) < 3.0:
			return true
	return false
