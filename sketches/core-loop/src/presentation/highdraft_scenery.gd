extends RefCounted

# The Highdraft's dress: the islands, ridge bridges, return ramps and barges skinned with the
# modelled kit, the thermal vent and air, the net deck, the harpoon anchors, a prop scatter, the
# cloud deck and distant silhouettes, and the open sky. Visual only: no collision
# shape, body or tuning is touched. Every piece falls back to the greybox the map and contraptions
# already built when its GLB is missing (the original meshes stay visible until a skin lands).
# Hooked from game.gd through hook(ctx), which builds the zone on the entry that builds its ground.

const Palette := preload("res://src/core/palette.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const SetDressing := preload("res://src/presentation/set_dressing.gd")
const Augments := preload("res://src/movement/augments.gd")
const HighdraftMap := preload("res://src/world/map_highdraft.gd")
const HighdraftFx := preload("res://src/presentation/highdraft_fx.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const Finishes := preload("res://src/presentation/highdraft_finishes.gd")
const ParkSites := preload("res://src/presentation/park_sites.gd")

const DIR := "res://assets/models/highdraft/"
const NODE_NAME := "HighdraftScenery"
# Skins sit a hair above the collider so they never z-fight the ground mesh; bridges and ramps
# sit above the island skin so the mouth joins read without a step.
const ISLAND_LIFT := 0.03
const STRIP_LIFT := 0.05
const WALL_OUT := 0.12
const WALL_SEARCH := 5.0
# The slab's 1.2 m wall is stretched down the skirt so the stone reads as a course, not a lip.
const WALL_STRETCH := 2.0
const NET_TILE := 4.0
const NET_MARGIN := 36.0
const NET_LIFT := 0.125
const CHUNK := 32.0
const EYE_HEIGHT := 16.6
const ANCHOR_REACH := 1.8
const SKY_RING := 460.0
# The cloud deck plane lies well under the catch plane and the banks; it never collides.
const CLOUD_DECK_Y := -32.0
const CLOUD_DECK_SIZE := 1600.0
# A park's cloud deck lies this far under its lowest ground.
const PARK_DECK_DROP := 40.0
const LOOK := Finishes.LOOK

# Tests point this at a missing folder to prove the fallback; the game never changes it.
static var dir := DIR
static var _sky: PanoramaSkyMaterial
static var _cloud: StandardMaterial3D
static var _cloud_image: Image
static var _cloud_task := -1
static var _warned := {}
static var _coloured := {}


static func reset_for_tests() -> void:
	if _cloud_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_cloud_task)
		_cloud_task = -1
	dir = DIR
	_sky = null
	_cloud = null
	_cloud_image = null
	_warned.clear()
	_coloured.clear()


# ---- Hook and environment ----

static func is_highdraft(map) -> bool:
	if map == null or map.get_script() == null:
		return false
	var path: String = (map.get_script() as Script).resource_path
	return path == "res://src/world/map_highdraft.gd" or path == "res://src/world/map_highdraft_crown.gd"


# Build the zone's dress on the entry that builds its ground, and swap the light for it; any
# other stage restores the shared environment. The stage's world look (world_look.gd, hooked after
# this in game.gd) is applied later, so its time of day owns the key, ambient and fog colour here. Connected after the world module's own handler,
# so the stage's contraptions already exist.
static func hook(ctx) -> void:
	ctx.events.stage_entered.connect(_on_stage_entered.bind(ctx))
	_start_cloud()


# A Highdraft park stage (park_islands, park_crown) takes the park pass (build_park): its islands, nets
# and anchors are park rows, and world_look.gd's time of day owns its light, so the zone's own
# environment swap stays on the old maps.
static func _on_stage_entered(stage: int, _retry: bool, ctx) -> void:
	var terrain = ctx.terrain
	var map = terrain.map_for(stage)
	var park := ParkSites.is_park(map) and _world(ctx, stage) == 3
	if not is_highdraft(map) and not park:
		restore_environment(terrain)
		return
	var root: Node3D = terrain.geometry_root(stage)
	if root.get_node_or_null(NODE_NAME) == null:
		var world = ctx.root.get("world") if ctx.root != null else null
		var contraptions = world.contraptions.get(stage) if world != null and "contraptions" in world else null
		var ground: Callable = terrain.ground_callable(stage)
		var scenery := build_park(root, map, contraptions, ground, ctx.player) if park \
			else build(root, map, contraptions, ground, ctx.player)
		var effects := scenery.get_node_or_null("WindEffects")
		if effects != null and ctx.player != null and ctx.events.has_signal("landed"):
			ctx.events.connect("landed", effects.on_landed.bind(ctx.player))
	if park:
		restore_environment(terrain)
	else:
		apply_environment(terrain, root)


static func _world(ctx, stage: int) -> int:
	for row in ctx.stages.DEFS:
		if int(row["stage"]) == stage:
			return int(row.get("world", 0))
	return 0


static func apply_environment(terrain, root: Node3D) -> void:
	var env: Environment = terrain.environment
	if env == null:
		return
	var sun := _sun(root)
	var look: Dictionary = WorldLook.ROWS[3]
	var values := {"ambient_light_color": LOOK["ambient"], "fog_light_color": LOOK["fill"],
		"tonemap_exposure": look.exposure, "adjustment_saturation": look.saturation}
	if look.sky == "own":
		if _sky == null:
			_sky = _sky_material()
		var sky := Sky.new()
		sky.sky_material = _sky
		values["sky"] = sky
	var lights := []
	var key_rotation: Vector3 = LOOK["key_rotation"]
	if sun != null:
		lights.append({"object": sun, "values": {"light_color": LOOK["key"], "shadow_enabled": true,
			"rotation": Vector3(deg_to_rad(key_rotation.x), deg_to_rad(key_rotation.y), 0.0)}})
		var fill := sun.get_parent().get_node_or_null("SkyFill") as DirectionalLight3D
		if fill != null:
			lights.append({"object": fill, "values": {"light_color": LOOK["fill"],
				"rotation": Vector3(deg_to_rad(-40.0), deg_to_rad(key_rotation.y + 180.0), 0.0)}})
	GraphicsPreset.set_lighting(root, env, values, lights, "highdraft")


static func restore_environment(terrain) -> void:
	var env: Environment = terrain.environment
	if env != null:
		GraphicsPreset.clear_lighting(env, "highdraft")


static func _sun(root: Node3D) -> DirectionalLight3D:
	var holder := root.get_parent()
	if holder == null:
		return null
	for light in holder.find_children("*", "DirectionalLight3D", false, false):
		if light.name != "SkyFill":
			return light
	return null


# One cached 512 x 256 panorama: cool sky `#a9b6c0` over the `#798c9e` haze, a cream `#ece7da`
# cloud deck below the horizon and a few broad cream banks above it. No storm, no glow.
static func _sky_material() -> PanoramaSkyMaterial:
	var image := Image.create_empty(512, 256, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 301006
	noise.frequency = 1.0
	noise.fractal_octaves = 2
	var haze := Color("798c9e")
	var high := Color("a9b6c0")
	var cream := Color("ece7da")
	for y in 256:
		var elevation := (0.5 - float(y) / 255.0) * PI
		for x in 512:
			var angle := float(x) / 512.0 * TAU
			var color := haze.lerp(high, clampf(elevation * 2.2, 0.0, 1.0))
			if elevation < 0.0:
				color = haze.lerp(cream, clampf(-elevation * 9.0, 0.0, 1.0))
			elif elevation > 0.05:
				var direction := Vector3(cos(angle) * cos(elevation), sin(elevation), sin(angle) * cos(elevation))
				var cloud := noise.get_noise_3d(direction.x * 4.0, direction.y * 9.0, direction.z * 4.0)
				color = color.lerp(cream, smoothstep(0.3, 0.55, cloud) * smoothstep(0.05, 0.25, elevation) * 0.7)
			image.set_pixel(x, y, color)
	image.generate_mipmaps()
	var material := PanoramaSkyMaterial.new()
	material.panorama = ImageTexture.create_from_image(image)
	return material


# ---- Build ----

# `ground` is the terrain's grid callable (x, z, clearance) -> Vector3; without it the map's own
# height function stands in. `contraptions` is the stage's Contraptions node, if it exists yet.
static func build(stage_root: Node3D, map, contraptions = null, ground := Callable(), player = null) -> Node3D:
	var scenery := Node3D.new()
	scenery.name = NODE_NAME
	stage_root.add_child(scenery)
	var state := Updater.new()
	state.name = "Presence"
	state.player = player
	scenery.add_child(state)
	_islands(scenery, map, ground)
	_bridges_and_ramps(scenery, map)
	if contraptions != null:
		_barges(contraptions)
		_thermals(scenery, state, map, contraptions)
	_net_deck(scenery, map)
	_anchors(scenery, state, stage_root, map, ground)
	_props(scenery, map)
	_sky_pieces(scenery)
	_relief(scenery, stage_root, map)
	state.fx = HighdraftFx.install(scenery, state, map)
	return scenery


# The park pass: the barge rigs and the thermal vents and air on the park's own contraptions, and the
# cloud deck and far silhouettes dropped under the park's lowest ground. The chase camera sees 700 m
# and a park is 1.6 km across, so the sky rides with the ball (Updater) and stays at the old maps'
# distances, a backdrop that never comes nearer. The wind effects follow the vents and the clouds; a
# park has no catch plane, so no net sags.
static func build_park(stage_root: Node3D, map, contraptions = null, ground := Callable(), player = null) -> Node3D:
	var scenery := Node3D.new()
	scenery.name = NODE_NAME
	stage_root.add_child(scenery)
	var state := Updater.new()
	state.name = "Presence"
	state.player = player
	scenery.add_child(state)
	if contraptions != null:
		_barges(contraptions)
		_thermals(scenery, state, map, contraptions)
	var rect: Rect2 = map.play_rect
	var low := INF
	for i in 17:
		for j in 17:
			low = minf(low, _height(ground, map, rect.position.x + rect.size.x * i / 16.0, rect.position.y + rect.size.y * j / 16.0))
	_sky_pieces(scenery, minf(0.0, low - PARK_DECK_DROP - CLOUD_DECK_Y))
	state.sky = scenery.get_node("Sky")
	state.fx = HighdraftFx.install(scenery, state, map)
	return scenery


static func _scene(file: String) -> Node:
	var packed: PackedScene = load(dir + file) as PackedScene if ResourceLoader.exists(dir + file) else null
	if packed == null:
		if not _warned.has(dir + file):
			_warned[dir + file] = true
			push_warning("highdraft_scenery: %s missing, its piece stays on the greybox" % file)
		return null
	var scene := packed.instantiate()
	for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if view.mesh != null:
			for i in view.mesh.get_surface_count():
				var source := view.mesh.surface_get_material(i)
				var drawn := Finishes.for_piece(file, _vertex_coloured(source))
				if drawn != source:
					view.set_surface_override_material(i, drawn)
			if file in Finishes.DISTANT:
				var coloured := view.mesh.duplicate() as Mesh
				for i in coloured.get_surface_count():
					coloured.surface_set_material(i, view.get_active_material(i))
				view.mesh = Finishes.aerial_mesh(coloured)
	return scene


# The kit's GLBs keep their colour in vertex colours and import with white materials that
# ignore them, so every piece would draw flat white. One shared copy per source material.
static func _vertex_coloured(source: Material) -> Material:
	if not (source is BaseMaterial3D):
		return source
	var base := source as BaseMaterial3D
	if base.vertex_color_use_as_albedo:
		return source
	var key := base.get_instance_id()
	if not _coloured.has(key):
		var copy := base.duplicate() as BaseMaterial3D
		copy.vertex_color_use_as_albedo = true
		_coloured[key] = copy
	return _coloured[key]


static func _loop(scene: Node, choices: Array[String]) -> void:
	for player: AnimationPlayer in scene.find_children("*", "AnimationPlayer", true, false):
		for clip in choices:
			if player.has_animation(clip):
				if player.get_animation(clip).loop_mode != Animation.LOOP_LINEAR:
					var library_name := player.find_animation_library(player.get_animation(clip))
					var library := player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
					var key := clip.get_slice("/", clip.get_slice_count("/") - 1)
					library.get_animation(key).loop_mode = Animation.LOOP_LINEAR
					player.remove_animation_library(library_name)
					player.add_animation_library(library_name, library)
				player.play(clip)
				return


# The first MeshInstance3D's mesh in a GLB (named when the file holds several), or null.
static func _mesh(file: String, node_name := "*") -> Mesh:
	var scene := _scene(file)
	if scene == null:
		return null
	var found: Mesh = null
	for view: MeshInstance3D in scene.find_children(node_name, "MeshInstance3D", true, false):
		if view.mesh != null:
			found = view.mesh.duplicate() as Mesh
			for i in found.get_surface_count():
				found.surface_set_material(i, view.get_active_material(i))
			break
	scene.free()
	return found


static func _height(ground: Callable, map, x: float, z: float) -> float:
	if ground.is_valid():
		return (ground.call(x, z, 0.0) as Vector3).y
	return float(map.sample(x, z)[0])


static func _multi(parent: Node3D, label: String, mesh: Mesh, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	if mesh == null or transforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	var bounds := AABB()
	var local := mesh.get_aabb()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		var placed: AABB = transforms[i] * local
		bounds = placed if i == 0 else bounds.merge(placed)
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = mm
	node.custom_aabb = bounds
	node.set_meta("placements", transforms)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	GraphicsPreset.register_scenery(node)
	return node


# ---- Islands ----

# The island GLB's top slab, fitted to the sampled ground: its top lies ISLAND_LIFT over the
# flat top and its wall is walked down the terrain's own skirt, so the stone hugs the real
# collider. A wall vertex that finds the ground still high (a bridge or ramp mouth) is pushed
# out and buried, so no lip stands in a mouth. The keel and the underside stay out: they would
# sit inside the pillar.
static func _islands(parent: Node3D, map, ground: Callable) -> void:
	var isles: Dictionary = map._islands()
	for id in isles:
		var isle: Dictionary = isles[id]
		var radius: float = isle["radius"]
		var file := "island_large.glb" if radius >= 20.0 else ("island_medium.glb" if radius >= 15.0 else "island_small.glb")
		var skin := _island_mesh(file, isle, map, ground)
		if skin == null:
			continue
		var view := MeshInstance3D.new()
		view.name = "IslandSkin_%s" % id
		view.mesh = skin
		parent.add_child(view)
		GraphicsPreset.register_scenery(view)


static func _island_mesh(file: String, isle: Dictionary, map, ground: Callable) -> ArrayMesh:
	var source := _mesh(file, "IslandStone")
	if source == null or source.get_surface_count() == 0:
		return _reject_island(file)
	var arrays := source.surface_get_arrays(0)
	var material := source.surface_get_material(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var original_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if material == null or vertices.is_empty() or colors.size() != vertices.size() or original_normals.size() != vertices.size() \
			or indices.is_empty() or indices.size() % 3 != 0 or source.get_aabb().size.x <= 0.0:
		return _reject_island(file)
	for index in indices:
		if index < 0 or index >= vertices.size():
			return _reject_island(file)
	var centre: Vector2 = isle["at"]
	var radius: float = isle["radius"]
	var top: float = isle["top"]
	var scale := radius / (source.get_aabb().size.x * 0.5)
	var remap := {}
	var out_vertices := PackedVector3Array()
	var out_uvs := PackedVector2Array()
	var out_colors := PackedColorArray()
	var out_normals := PackedVector3Array()
	var out_indices := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		var keep := true
		var centroid := Vector3.ZERO
		for k in 3:
			var v := vertices[indices[t + k]]
			centroid += v / 3.0
			if v.y < -1.3 or (v.y < -0.02 and Vector2(v.x, v.z).length() * scale < radius - 1.5):
				keep = false
		if not keep:
			continue
		var normal := (vertices[indices[t + 1]] - vertices[indices[t]]).cross(vertices[indices[t + 2]] - vertices[indices[t]])
		if centroid.y < -0.05 and normal.normalized().y < -0.5:
			continue
		for k in 3:
			var index := indices[t + k]
			if not remap.has(index):
				remap[index] = out_vertices.size()
				out_vertices.append(_fit(vertices[index], centre, radius, top, scale, map, ground))
				out_uvs.append(uvs[index] if index < uvs.size() else Vector2.ZERO)
				out_colors.append(_stone(colors[index], vertices[index].y))
				out_normals.append(original_normals[index])
			out_indices.append(remap[index])
	if out_indices.is_empty():
		return null
	var normals := PackedVector3Array()
	normals.resize(out_vertices.size())
	for t in range(0, out_indices.size(), 3):
		var face := (out_vertices[out_indices[t + 1]] - out_vertices[out_indices[t]]).cross(out_vertices[out_indices[t + 2]] - out_vertices[out_indices[t]])
		if face.dot(out_normals[out_indices[t]]) < 0.0:
			face = -face
		for k in 3:
			normals[out_indices[t + k]] += face
	for i in normals.size():
		normals[i] = normals[i].normalized() if normals[i].length_squared() > 0.000001 else Vector3.UP
	var built := []
	built.resize(Mesh.ARRAY_MAX)
	built[Mesh.ARRAY_VERTEX] = out_vertices
	built[Mesh.ARRAY_NORMAL] = normals
	built[Mesh.ARRAY_TEX_UV] = out_uvs
	built[Mesh.ARRAY_COLOR] = out_colors
	built[Mesh.ARRAY_INDEX] = out_indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, built)
	mesh.surface_set_material(0, material)
	return mesh


# Pale stone top, darker fascia down the wall: the island's edge reads in greyscale.
static func _stone(authored: Color, local_y: float) -> Color:
	var band: Color = LOOK["stone"] if local_y > -0.02 else LOOK["fascia"]
	return authored.lerp(band.srgb_to_linear(), 0.55 if local_y > -0.02 else 0.7)


static func _reject_island(file: String) -> ArrayMesh:
	if not _warned.has(dir + file):
		_warned[dir + file] = true
		push_warning("highdraft_scenery: %s malformed; keeping greybox island" % file)
	return null


static func _fit(v: Vector3, centre: Vector2, radius: float, top: float, scale: float, map, ground: Callable) -> Vector3:
	var flat := Vector2(v.x, v.z) * scale
	if v.y > -0.02:
		# The collider is a 2 m grid, so its rim droops inside the analytic radius: follow it.
		var spot := centre + flat
		return Vector3(spot.x, minf(top, _height(ground, map, spot.x, spot.y)) + ISLAND_LIFT, spot.y)
	var dir := flat.normalized() if flat.length() > 0.001 else Vector2.RIGHT
	var target := top + v.y * WALL_STRETCH
	var reach := radius
	while reach < radius + WALL_SEARCH:
		var at := centre + dir * reach
		if _height(ground, map, at.x, at.y) <= target + 0.05:
			break
		reach += 0.25
	var place := centre + dir * (reach + WALL_OUT)
	return Vector3(place.x, minf(target, _height(ground, map, place.x, place.y) + ISLAND_LIFT), place.y)


# ---- Bridges, return ramps, barges ----

static func _bridges_and_ramps(parent: Node3D, map) -> void:
	var isles: Dictionary = map._islands()
	var bays: Array[Transform3D] = []
	for pair in map._bridges():
		var a: Dictionary = isles[pair[0]]
		var b: Dictionary = isles[pair[1]]
		var way: Vector2 = ((b["at"] as Vector2) - (a["at"] as Vector2)).normalized()
		var from: Vector2 = (a["at"] as Vector2) + way * float(a["radius"])
		var to: Vector2 = (b["at"] as Vector2) - way * float(b["radius"])
		_strip(bays, from, to, float(a["top"]), float(b["top"]))
	_multi(parent, "BridgeSkins", _mesh("bridge_skin.glb", "HardwareSkin"), bays)
	var slopes: Array[Transform3D] = []
	for ramp in map._ramps():
		var line: Dictionary = map.ramp_line(ramp)
		_strip(slopes, line["foot"], line["rim"], HighdraftMap.NET_H, float(line["top"]))
	_multi(parent, "ReturnRampSkins", _mesh("return_ramp_skin.glb", "HardwareSkin"), slopes)


# 8 m wide bays, 4 m long before scaling, laid end to end along a line that rises linearly.
static func _strip(into: Array[Transform3D], from: Vector2, to: Vector2, from_y: float, to_y: float) -> void:
	var length := from.distance_to(to)
	if length < 0.5:
		return
	var way := (to - from) / length
	var count := maxi(1, roundi(length / 4.0))
	var slope := (to_y - from_y) / length
	var z_axis := Vector3(way.x, slope, way.y).normalized()
	var x_axis := Vector3(way.y, 0.0, -way.x)
	var y_axis := z_axis.cross(x_axis)
	var stretch := length / count / 4.0 * 1.04
	for k in count:
		var t := (k + 0.5) / count
		var at := from.lerp(to, t)
		var basis := Basis(x_axis, y_axis, z_axis * stretch)
		into.append(Transform3D(basis, Vector3(at.x, lerpf(from_y, to_y, t), at.y) + y_axis * STRIP_LIFT))


# The barge's own tilted deck node carries its recipe views (contraptions.gd _build_barge), so the
# rig leans with the scripted settle: the sail and pennant ride the deck too.
static func _barges(contraptions: Node) -> void:
	for barge in contraptions.barges:
		var deck: MeshInstance3D = barge["deck"]
		if deck.get_node_or_null("HighdraftWeatherSail") != null:
			continue
		# Reuse the kit's rig for a full weather sail and a small corner pennant.
		for marker in [
			{"name": "HighdraftWeatherSail", "at": Vector3(5.5, 1.0, -5.5), "scale": 1.0},
			{"name": "HighdraftPennant", "at": Vector3(-5.5, 1.0, 5.5), "scale": 0.5},
		]:
			var sail := _scene("prop_sail.glb")
			if sail != null:
				sail.name = marker.name
				sail.position = marker.at
				sail.scale = Vector3.ONE * marker.scale
				deck.add_child(sail)
				_loop(sail, ["wind", "wind_loop"])


# ---- Thermals ----

static func _thermals(parent: Node3D, state: Node, map, contraptions: Node) -> void:
	for thermal in contraptions.thermals:
		var spec: Dictionary = thermal["spec"]
		var base: Vector3 = thermal["base"]
		var vent := _scene("thermal_vent.glb")
		var air := _scene("thermal_air.glb")
		if vent == null or air == null:
			if vent != null:
				vent.free()
			if air != null:
				air.free()
			continue
		_hide_thermal_greybox(contraptions, base, float(spec["height"]))
		vent.name = "Vent_%s" % spec["id"]
		vent.position = base
		parent.add_child(vent)
		air.name = "Air_%s" % spec["id"]
		air.position = base
		air.scale = Vector3(1.0, float(spec["height"]) / 40.0, 1.0)
		parent.add_child(air)
		_loop(air, ["rise", "rise_loop"])
		var vent_player := vent.find_children("*", "AnimationPlayer", true, false)
		state.thermals.append({"base": base, "radius": float(spec["radius"]), "height": float(spec["height"]),
			"player": vent_player[0] if not vent_player.is_empty() else null, "state": ""})


# The column and grate _build_thermal added: unnamed cylinders at the base and mid-height.
static func _hide_thermal_greybox(contraptions: Node, base: Vector3, height: float) -> void:
	for child in contraptions.get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh:
			var near_column: bool = (child.position - (base + Vector3.UP * height * 0.5)).length() < 0.05
			var near_grate: bool = (child.position - (base + Vector3.UP * 0.1)).length() < 0.05
			if near_column or near_grate:
				child.visible = false


# ---- Net deck ----

# The terrain's own ground mesh drew the catch plane out to the 400 m grid edge as a flat grid.
# It is hidden here and redrawn without the open floor outside the play rect, so past the edge
# the eye falls to the cloud deck; the collider is untouched and the floor the ball can reach
# still draws as the net. Pillars take the darker stone.
static func _relief(scenery: Node3D, stage_root: Node3D, map) -> void:
	var body := stage_root.get_node_or_null("Ground")
	if body == null:
		return
	var views := body.find_children("*", "MeshInstance3D", true, false)
	if views.is_empty() or (views[0] as MeshInstance3D).mesh == null:
		return
	var grid: MeshInstance3D = views[0]
	var arrays := grid.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if arrays[Mesh.ARRAY_INDEX] == null:
		# A grid with no index buffer cannot be trimmed, but it still wears the catch floor.
		GraphicsPreset.set_ground_material(grid, _catch_material())
		return
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var rect: Rect2 = map.play_rect
	var deck: float = HighdraftMap.NET_H + 0.05
	var kept := PackedInt32Array()
	kept.resize(indices.size())
	var count := 0
	for t in range(0, indices.size(), 3):
		var a := vertices[indices[t]]
		var b := vertices[indices[t + 1]]
		var c := vertices[indices[t + 2]]
		if a.y > deck or b.y > deck or c.y > deck or rect.has_point(Vector2(a.x + b.x + c.x, a.z + b.z + c.z) / 3.0):
			kept[count] = indices[t]
			kept[count + 1] = indices[t + 1]
			kept[count + 2] = indices[t + 2]
			count += 3
	kept.resize(count)
	arrays[Mesh.ARRAY_INDEX] = kept
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var relief := MeshInstance3D.new()
	relief.name = "IslandRelief"
	relief.mesh = mesh
	scenery.add_child(relief)
	grid.name = "GridFloor"
	grid.visible = false
	GraphicsPreset.set_ground_material(relief, _catch_material())


static func _catch_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials/highdraft/catch_floor.gdshader")
	material.set_shader_parameter("floor_map", Palette.painted_texture(256, true))
	material.set_shader_parameter("stone_tint", LOOK["pillar"])
	material.set_shader_parameter("cord_tint", LOOK["bone"])
	material.set_shader_parameter("deck_tint", (LOOK["bone"] as Color).lerp(LOOK["charcoal"], 0.45))
	material.set_shader_parameter("net_height", HighdraftMap.NET_H)
	material.set_shader_parameter("net_pitch", 4.0)
	return material


# The padded perimeter in the catch amber the sheet keeps for offered lift and catch edges.
static func net_edge_material() -> StandardMaterial3D:
	return Palette.nosing_material()


static func _net_deck(parent: Node3D, map) -> void:
	var tile := _mesh("net_tile.glb", "Weave")
	if tile == null:
		return
	var isles: Dictionary = map._islands()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for id in isles:
		var at: Vector2 = isles[id]["at"]
		var extent: float = float(isles[id]["radius"]) + HighdraftMap.SKIRT
		low = Vector2(minf(low.x, at.x - extent), minf(low.y, at.y - extent))
		high = Vector2(maxf(high.x, at.x + extent), maxf(high.y, at.y + extent))
	var rect := Rect2(low, high - low).grow(NET_MARGIN).intersection(map.play_rect)
	var chunks := {}
	var x0 := floorf(rect.position.x / NET_TILE) * NET_TILE
	var z0 := floorf(rect.position.y / NET_TILE) * NET_TILE
	var net_h: float = HighdraftMap.NET_H
	var x := x0
	while x < rect.end.x:
		var z := z0
		while z < rect.end.y:
			var c := Vector2(x + NET_TILE * 0.5, z + NET_TILE * 0.5)
			var open := true
			for probe in [Vector2.ZERO, Vector2(2, 2), Vector2(-2, 2), Vector2(2, -2), Vector2(-2, -2)]:
				if float(map.sample(c.x + probe.x, c.y + probe.y)[0]) > net_h + 0.05:
					open = false
					break
			if open:
				var key := Vector2i(floori(c.x / CHUNK), floori(c.y / CHUNK))
				if not chunks.has(key):
					var list: Array[Transform3D] = []
					chunks[key] = list
				(chunks[key] as Array[Transform3D]).append(Transform3D(Basis.IDENTITY, Vector3(c.x, net_h + NET_LIFT, c.y)))
			z += NET_TILE
		x += NET_TILE
	var deck := Node3D.new()
	deck.name = "NetDeck"
	parent.add_child(deck)
	for key in chunks:
		_multi(deck, "Tiles_%d_%d" % [key.x, key.y], tile, chunks[key])
	# Padded edge around the tiled bay, and a shoe at each corner.
	var edge := _mesh("net_edge.glb", "Hardware")
	var edges: Array[Transform3D] = []
	var span := Rect2(Vector2(x0, z0), Vector2(ceilf((rect.end.x - x0) / NET_TILE) * NET_TILE, ceilf((rect.end.y - z0) / NET_TILE) * NET_TILE))
	var steps_x := roundi(span.size.x / NET_TILE)
	var steps_z := roundi(span.size.y / NET_TILE)
	for i in steps_x:
		var px := span.position.x + NET_TILE * (i + 0.5)
		edges.append(Transform3D(Basis.IDENTITY, Vector3(px, net_h + NET_LIFT, span.position.y)))
		edges.append(Transform3D(Basis(Vector3.UP, PI), Vector3(px, net_h + NET_LIFT, span.end.y)))
	for i in steps_z:
		var pz := span.position.y + NET_TILE * (i + 0.5)
		edges.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(span.position.x, net_h + NET_LIFT, pz)))
		edges.append(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(span.end.x, net_h + NET_LIFT, pz)))
	var kept: Array[Transform3D] = []
	for placement in edges:
		if float(map.sample(placement.origin.x, placement.origin.z)[0]) <= net_h + 0.05:
			kept.append(placement)
	var padded := _multi(deck, "NetEdges", edge, kept)
	if padded != null:
		padded.material_override = net_edge_material()
	var shoes: Array[Transform3D] = []
	for corner in [span.position, Vector2(span.end.x, span.position.y), Vector2(span.position.x, span.end.y), span.end]:
		shoes.append(Transform3D(Basis.IDENTITY, Vector3(corner.x, net_h, corner.y)))
	_multi(deck, "NetShoes", _mesh("net_shoe.glb", "Hardware"), shoes)


# ---- Harpoon anchors ----

# The mast and eye replace the post's drawn cylinder and cap; the post's collider stays. The
# eye turns to face the camera and reads the harpoon's own state: slate idle, mint when this
# post is what a press would bite, steady mint while the line holds it.
static func _anchors(parent: Node3D, state: Node, stage_root: Node3D, map, ground: Callable) -> void:
	var posts: Array = map._posts()
	for post in posts:
		var at: Vector2 = post["at"]
		var height: float = post["height"]
		var foot := Vector3(at.x, _height(ground, map, at.x, at.y) - 0.5, at.y)
		var mast := _scene("anchor_mast.glb")
		var eye := _scene("anchor_eye.glb")
		if mast == null or eye == null:
			if mast != null:
				mast.free()
			if eye != null:
				eye.free()
			continue
		_hide_post_greybox(stage_root, foot, height)
		mast.name = "AnchorMast_%d" % state.anchors.size()
		mast.position = foot
		parent.add_child(mast)
		eye.name = "AnchorEye_%d" % state.anchors.size()
		eye.position = foot + Vector3.UP * (height + 0.6)
		parent.add_child(eye)
		var collars: Array = []
		for socket in ["collar_lb", "collar_lt", "collar_rb", "collar_rt"]:
			var anchor_point := eye.find_child(socket, true, false) as Node3D
			var collar := _scene("anchor_collar.glb")
			if anchor_point == null or collar == null:
				if collar != null:
					collar.free()
				continue
			collar.position = anchor_point.position
			# The collar block sits on its local (+1, +1) diagonal and closes toward the origin, so
			# turn that diagonal onto the socket's corner direction.
			collar.rotation.z = atan2(anchor_point.position.y, anchor_point.position.x) - PI * 0.25
			eye.add_child(collar)
			var players := collar.find_children("*", "AnimationPlayer", true, false)
			if not players.is_empty():
				collars.append(players[0])
		var eye_players := eye.find_children("*", "AnimationPlayer", true, false)
		state.anchors.append({"eye": eye, "foot": foot, "height": height, "collars": collars,
			"player": eye_players[0] if not eye_players.is_empty() else null, "state": ""})


static func _hide_post_greybox(stage_root: Node3D, foot: Vector3, height: float) -> void:
	var shaft_at := foot + Vector3.UP * height * 0.5
	var cap_at := foot + Vector3.UP * (height + 0.6)
	for child in stage_root.get_children():
		if child is StaticBody3D and ((child as Node3D).position - shaft_at).length() < 0.05:
			for part in child.get_children():
				if part is MeshInstance3D:
					part.visible = false
		elif child is MeshInstance3D and child.mesh is SphereMesh and ((child as Node3D).position - cap_at).length() < 0.05:
			child.visible = false


# ---- Props ----

const PROPS := [
	{"file": "prop_spool.glb", "node": "Surface", "weight": 2, "size": 1.8},
	{"file": "prop_bearing.glb", "node": "Surface", "weight": 2, "size": 1.2},
	{"file": "prop_crate.glb", "node": "Surface", "weight": 3, "size": 1.5},
	{"file": "prop_pot.glb", "node": "Surface", "weight": 2, "size": 1.2},
	{"file": "prop_clamp.glb", "node": "Surface", "weight": 2, "size": 1.0},
	{"file": "prop_ballast.glb", "node": "Surface", "weight": 3, "size": 1.3},
	{"file": "prop_bench.glb", "node": "Surface", "weight": 1, "size": 2.0},
	{"file": "prop_lamp_body.glb", "node": "Surface", "weight": 1, "size": 0.7},
]


# Props stand in a ring near each island's rim, 2.5 to 6 m in from the edge, off every route:
# the spawn, beacon bowl, vault, gate slots, sites and relic, the bridge and ramp mouths, the
# harpoon posts, thermals, barge lanes and the cable. A weather sail (animated) rides each
# island too. Seeded per island, so a run always sees the same yard.
static func _props(parent: Node3D, map) -> void:
	var rows := _keepouts(map)
	var isles: Dictionary = map._islands()
	var lists := {}
	for id in isles:
		var isle: Dictionary = isles[id]
		var radius: float = isle["radius"]
		var centre: Vector2 = isle["at"]
		var top: float = isle["top"]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(id)) ^ int(radius * 100.0)
		var want: int = map.scatter["per_preset"]["large" if radius >= 20.0 else ("medium" if radius >= 15.0 else "small")]
		var placed: Array[Vector2] = []
		var tries := 0
		while placed.size() < want and tries < 80:
			tries += 1
			var pick := _pick_prop(rng)
			var angle := rng.randf() * TAU
			var reach := radius - rng.randf_range(2.5, 6.0)
			var at := centre + Vector2.from_angle(angle) * reach
			var size: float = float(PROPS[pick]["size"])
			if SetDressing.blocked(rows, at, size * 0.5 + 0.5) != "":
				continue
			var crowded := false
			for other in placed:
				if other.distance_to(at) < 4.0:
					crowded = true
					break
			if crowded:
				continue
			placed.append(at)
			var turn := rng.randf() * TAU
			if not lists.has(pick):
				var list: Array[Transform3D] = []
				lists[pick] = list
			(lists[pick] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, turn), Vector3(at.x, top, at.y)))
		# One weather sail per island, an animated scene so its wind loop runs.
		var sail_at := Vector2.ZERO
		var found := false
		for k in 40:
			sail_at = centre + Vector2.from_angle(rng.randf() * TAU) * (radius - rng.randf_range(2.5, 5.0))
			if SetDressing.blocked(rows, sail_at, 1.5) == "":
				var clear := true
				for other in placed:
					clear = clear and other.distance_to(sail_at) >= 4.0
				if clear:
					found = true
					break
		if found:
			var sail := _scene("prop_sail.glb")
			if sail != null:
				sail.name = "Sail_%s" % id
				sail.position = Vector3(sail_at.x, top, sail_at.y)
				sail.rotation.y = rng.randf() * TAU
				parent.add_child(sail)
				_loop(sail, ["wind", "wind_loop"])
				_sail_capture(parent, sail)
		if radius >= 15.0:
			var taken := placed.duplicate()
			if found:
				taken.append(sail_at)
			_fan(parent, rows, taken, id, centre, radius, top)
	var yard := Node3D.new()
	yard.name = "Props"
	parent.add_child(yard)
	for pick in lists:
		var row: Dictionary = PROPS[pick]
		_multi(yard, String(row["file"]).get_basename(), _mesh(row["file"], row["node"]), lists[pick])
		if row["file"] == "prop_lamp_body.glb":
			_multi(yard, "prop_lamp_glass", _mesh("prop_lamp_glass.glb", "Surface"), lists[pick])


# One spinning yard fan (animated) on each medium or large island. Its own seed, so the yard
# props and sails keep their places.
static func _fan(parent: Node3D, rows, taken: Array[Vector2], id, centre: Vector2, radius: float, top: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(id) + ":fan") ^ int(radius * 100.0)
	for k in 40:
		var at := centre + Vector2.from_angle(rng.randf() * TAU) * (radius - rng.randf_range(2.5, 6.0))
		if SetDressing.blocked(rows, at, 1.5) != "":
			continue
		var clear := true
		for other in taken:
			clear = clear and other.distance_to(at) >= 4.0
		if not clear:
			continue
		var fan := _scene("prop_fan.glb")
		if fan == null:
			return
		fan.name = "Fan_%s" % id
		fan.position = Vector3(at.x, top, at.y)
		fan.rotation.y = rng.randf() * TAU
		parent.add_child(fan)
		_loop(fan, ["spin", "spin_loop"])
		return


# A capture viewpoint 6 m off the first sail's face, aimed at its 2 m face, so stills can frame one.
static func _sail_capture(parent: Node3D, sail: Node3D) -> void:
	if parent.has_node("SailCapture"):
		return
	# The triangle spans local +X and faces local Z, so the view stands off that face.
	var face := sail.transform * Vector3(0.9, 1.2, 0.0)
	var view := Marker3D.new()
	view.name = "SailCapture"
	view.transform = Transform3D(Basis.IDENTITY, sail.transform * Vector3(1.5, 2.4, 6.0)).looking_at(face, Vector3.UP)
	parent.add_child(view)


static func _pick_prop(rng: RandomNumberGenerator) -> int:
	var total := 0
	for row in PROPS:
		total += int(row["weight"])
	var roll := rng.randi_range(0, total - 1)
	for i in PROPS.size():
		roll -= int(PROPS[i]["weight"])
		if roll < 0:
			return i
	return 0


static func _keepouts(map) -> Array:
	var isles: Dictionary = map._islands()
	var row := func(what: String, points: Array, radius: float) -> Dictionary:
		return {"what": what, "points": PackedVector2Array(points), "radius": radius, "ride": false}
	var rows := []
	rows.append(row.call("spawn", [map.spawn], 7.0))
	rows.append(row.call("warden ground", [map.beacon], 16.0))
	rows.append(row.call("vault", [map.vault], 8.0))
	for slot in map.gate_slots:
		rows.append(row.call("reward gate slot", [slot["at"]], 6.0))
	for site in map.activity_sites:
		rows.append(row.call("activity site", [site["at"]], 8.0))
	rows.append(row.call("relic", [map.relic_spot], 7.0))
	for pair in map._bridges():
		var a: Dictionary = isles[pair[0]]
		var b: Dictionary = isles[pair[1]]
		rows.append(row.call("bridge mouth", [a["at"], b["at"]], HighdraftMap.BRIDGE_HALF + 4.0))
	for ramp in map._ramps():
		var line: Dictionary = map.ramp_line(ramp)
		rows.append(row.call("return ramp", [line["foot"], line["rim"]], HighdraftMap.RAMP_HALF + 4.0))
	for post in map._posts():
		rows.append(row.call("anchor", [post["at"]], 6.0))
	for spec in map.contraptions:
		match spec["kind"]:
			"thermal":
				rows.append(row.call("thermal", [spec["at"]], float(spec["radius"]) + 4.0))
			"barge":
				var a3: Vector3 = spec["a"]
				var b3: Vector3 = spec["b"]
				rows.append(row.call("barge lane", [Vector2(a3.x, a3.z), Vector2(b3.x, b3.z)], 12.0))
			"cable":
				var f: Vector3 = spec["from"]
				var t: Vector3 = spec["to"]
				rows.append(row.call("cable", [Vector2(f.x, f.z), Vector2(t.x, t.z)], float(spec["radius"]) + 3.0))
	return rows


# ---- Sky: cloud deck and distant silhouettes ----

static func _sky_pieces(parent: Node3D, drop := 0.0) -> void:
	var sky := Node3D.new()
	sky.name = "Sky"
	parent.add_child(sky)
	sky.position.y = drop
	var rng := RandomNumberGenerator.new()
	rng.seed = 7_310_006
	# Cloud deck: broad banks under the catch plane, top face at Y -20, never over the playfield.
	var clouds: Array[Transform3D] = []
	for k in 36:
		var angle := TAU * k / 36.0 + rng.randf_range(-0.05, 0.05)
		var reach := rng.randf_range(250.0, 560.0)
		var wide := rng.randf_range(1.6, 3.0)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(wide, 1.0, wide))
		clouds.append(Transform3D(basis, Vector3(cos(angle) * reach, -26.0, sin(angle) * reach)))
	_multi(sky, "CloudDeck", _mesh("sky_cloud.glb", "CloudHull"), clouds)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * CLOUD_DECK_SIZE
	var deck := MeshInstance3D.new()
	deck.name = "CloudPlane"
	deck.mesh = plane
	deck.position = Vector3(0.0, CLOUD_DECK_Y, 0.0)
	deck.material_override = _cloud_material()
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.add_child(deck)
	# Mesas stand well past the playable bounds; fog and scale keep them distant.
	var mesas: Array[Transform3D] = []
	for k in 7:
		var angle := TAU * k / 7.0 + rng.randf_range(-0.2, 0.2)
		var reach := rng.randf_range(SKY_RING, SKY_RING + 80.0)
		var scale := rng.randf_range(2.0, 3.2)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, scale, scale))
		mesas.append(Transform3D(basis, Vector3(cos(angle) * reach, -50.0, sin(angle) * reach)))
	_multi(sky, "DistantMesas", _mesh("sky_mesa.glb", "MesaHull"), mesas)
	# Landmarks frame the quiet centre: the loom to one side, the split blades to the other,
	# a pair of far cradles between. None of them has an eye or a hard point.
	_landmark(sky, "sky_loom.glb", "LoomHull", "Loom", 205.0, SKY_RING + 20.0, -40.0, 2.4)
	_landmark(sky, "sky_blades.glb", "BladeHull", "Blades", 335.0, SKY_RING + 40.0, -50.0, 2.0)
	_landmark(sky, "sky_cradle.glb", "CradleHull", "CradleA", 95.0, SKY_RING, 30.0, 2.2)
	_landmark(sky, "sky_cradle.glb", "CradleHull", "CradleB", 265.0, SKY_RING + 60.0, 55.0, 2.6)


# One cached cream deck with soft seamless noise, tiled; fog carries it into the haze. The
# per-pixel pass cost 23 to 37 ms inside the stage 5 entry frame on the cloud, so hook() bakes
# the image on a worker at boot and the entry only waits if that bake has not finished (0.5 to
# 1.1 ms left on the cloud once it has).
static func _cloud_material() -> StandardMaterial3D:
	if _cloud != null:
		return _cloud
	_start_cloud()
	WorkerThreadPool.wait_for_task_completion(_cloud_task)
	_cloud_task = -1
	_cloud = StandardMaterial3D.new()
	_cloud.albedo_texture = ImageTexture.create_from_image(_cloud_image)
	_cloud_image = null
	_cloud.uv1_scale = Vector3(6.0, 6.0, 1.0)
	_cloud.roughness = 1.0
	_cloud.metallic_specular = 0.0
	return _cloud


static func _start_cloud() -> void:
	if _cloud == null and _cloud_task < 0:
		_cloud_task = WorkerThreadPool.add_task(_bake_cloud, false, "Highdraft cloud deck")


# Image and noise only, so it is safe off the main thread; the texture is made on the main thread.
static func _bake_cloud() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7_310_032
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var image := noise.get_seamless_image(256, 256)
	image.convert(Image.FORMAT_RGB8)
	var cream: Color = LOOK["cloud"]
	var shade := cream.lerp(LOOK["fill"], 0.6)
	for y in image.get_height():
		for x in image.get_width():
			image.set_pixel(x, y, shade.lerp(cream, smoothstep(0.3, 0.7, image.get_pixel(x, y).r)))
	image.generate_mipmaps()
	_cloud_image = image


static func _landmark(parent: Node3D, file: String, hull: String, label: String, degrees: float, reach: float, base_y: float, scale: float) -> void:
	var mesh := _mesh(file, hull)
	if mesh == null:
		return
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var angle := deg_to_rad(degrees)
	view.transform = Transform3D(Basis(Vector3.UP, angle + PI * 0.5).scaled(Vector3.ONE * scale), Vector3(cos(angle) * reach, base_y, sin(angle) * reach))
	parent.add_child(view)
	GraphicsPreset.register_scenery(view)


# ---- Live reads ----

# Per-frame presentation only: the anchor eyes face the camera and show the harpoon's state,
# the vents show whether the ball stands in their column. Nothing here writes game state.
class Updater extends Node3D:
	var player = null
	var anchors: Array[Dictionary] = []
	var thermals: Array[Dictionary] = []
	var fx: Node3D
	# A park's sky, kept centred on the ball (build_park); null on the old maps.
	var sky: Node3D

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		var cam := get_viewport().get_camera_3d()
		var kit = player.kit if player != null and "kit" in player else null
		var ball := Vector3.INF
		if player != null and is_instance_valid(player):
			ball = player.shown_position() if player.has_method("shown_position") else player.global_position
		for row in anchors:
			var eye: Node3D = row["eye"]
			if cam != null:
				var toward := cam.global_position - eye.global_position
				eye.global_rotation.y = atan2(toward.x, toward.z)
			_set_anchor(row, _anchor_state(row, kit))
		for row in thermals:
			var base: Vector3 = row["base"]
			var inside: bool = ball != Vector3.INF and Vector2(ball.x - base.x, ball.z - base.z).length() <= float(row["radius"]) \
				and ball.y >= base.y and ball.y <= base.y + float(row["height"])
			var want := "occupied" if inside else "idle"
			if want != row["state"] and row["player"] != null:
				(row["player"] as AnimationPlayer).play(want, 0.15)
			row["state"] = want
		if sky != null and ball != Vector3.INF:
			sky.position = Vector3(ball.x, sky.position.y, ball.z)
		if fx != null:
			fx.step(delta, ball)

	func _anchor_state(row: Dictionary, kit) -> String:
		if kit == null:
			return "idle"
		var foot: Vector3 = row["foot"]
		var eye_at := foot + Vector3.UP * EYE_HEIGHT
		if kit.line_state != Augments.LINE_IDLE and (kit.anchor as Vector3).distance_to(eye_at) < 4.0:
			return "attached"
		var aim: Dictionary = kit.aim
		if aim.get("state", Augments.AIM_NONE) != Augments.AIM_NONE:
			var point: Vector3 = aim["point"]
			if Vector2(point.x - foot.x, point.z - foot.z).length() <= ANCHOR_REACH and point.y >= foot.y - 1.0 and point.y <= foot.y + float(row["height"]) + 3.0:
				return "ready"
		return "idle"

	func _set_anchor(row: Dictionary, want: String) -> void:
		if want == row["state"]:
			return
		row["state"] = want
		if row["player"] != null:
			(row["player"] as AnimationPlayer).play(want, 0.15)
		for collar in row["collars"]:
			(collar as AnimationPlayer).play("open" if want == "idle" else "close", 0.1)
