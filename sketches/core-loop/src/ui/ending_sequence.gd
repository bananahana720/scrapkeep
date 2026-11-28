extends Control

signal finished

const AppShell := preload("res://src/core/app_shell.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const Worlds := preload("res://src/core/worlds.gd")
const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const CompanionBody := preload("res://src/presentation/companion_body.gd")
const DigScenery := preload("res://src/presentation/dig_scenery.gd")
const HighdraftScenery := preload("res://src/presentation/highdraft_scenery.gd")
const CreditsHint := preload("res://src/ui/credits_hint.gd")
const SpillwayScenery := preload("res://src/presentation/spillway_scenery.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")

const WORLD_SECONDS := 12.0
const ESTABLISH_SECONDS := 2.0
const LINE_SECONDS := 5.0
const CREDITS_SECONDS := 18.0
const CREDITS_LINE_SECONDS := 4.5
const HINT_BAND := 72.0
const SKIP_HINT := [{"say": "Any key skips to the summary"}]
const PRELUDE_HINT := [{"say": "Any key skips to the victory lap"}]
const SKIP_GUARD := 0.75
const TOTAL_SECONDS := WORLD_SECONDS * 3.0 + CREDITS_SECONDS
const WORLD_DRESSING := {1: "SpillwayScenery", 2: "DigScenery", 3: "HighdraftScenery"}
const CRATER_ROW := {"id": "row_crater_ending", "element": "crater_bowl", "recipe": "crater_ending", "budget": "park_large",
	"at": [0.0, 0.0], "y": 0.0, "yaw_deg": 0.0, "size": [359.4, 60.0, 359.4]}
const CRATER_CAM_FROM := Vector3(-160.0, 240.0, -300.0)
const CRATER_CAM_TO := Vector3(-40.0, 95.0, -215.0)
const CRATER_LOOK := Vector3(0.0, -20.0, 0.0)
const CREDITS := "SCRAPKEEP\n\nCreator and director\nAndrew\n\nMade with\nGodot and Blender\n\nMusic\nACE-Step\n\nAI collaborators\nClaude and Codex\n\nThank you for bringing the crew home."

var active := false
var elapsed := 0.0
var phase := "flyover"
var world_index := -1
var prepare_usec := 0
var game
var viewport: SubViewport
var camera: Camera3D
var worlds: Array[Node3D] = []
var stages: Array[int] = []
static var _highdraft_skies := {}
var shell: Node3D
var companion: Node3D
var _scene: Node3D
var _environment: Environment
var _sun: DirectionalLight3D
var _world_label: Label
var _copy: Label
var _credits: Label
var _credits_clip: Control
var _hint_band: ColorRect
var skip_hint
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _credits_back: ColorRect
var _credits_band: ColorRect
var _cut: ColorRect
var _at := Vector3.ZERO
var _dig_deep := false
var _order: Array[int] = [0, 1, 2]
var _park_stage := false
var _cam_fwd := Vector3.BACK
var _active_heights := PackedFloat32Array()
var _park_heights := {}
var quiet_gun: Node3D
var crater: Node3D
var cannon_answered := false
var cannon_answer_at := -1.0
var _crater_placed := false
var _crater_files: Array = []
var _crater_requests: Array[String] = []
var _crater_serial := false
var lap := {}
var prelude := false
var _opened_at := 0.0


func start(game_ref, lap_stats := {}, prelude_only := false) -> void:
	game = game_ref
	lap = lap_stats
	prelude = prelude_only
	name = "EndingSequence"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var began := Time.get_ticks_usec()
	_order = _world_order()
	_build_view()
	if lap.is_empty():
		_build_worlds()
		_build_crew()
	if not prelude:
		_build_crater()
	if prelude:
		skip_hint.setup(PRELUDE_HINT)
	prepare_usec = Time.get_ticks_usec() - began
	active = true
	if not lap.is_empty():
		_credits.text = credits_text(lap)
		world_index = 2
		elapsed = WORLD_SECONDS * 3.0
		_opened_at = elapsed
	advance(0.0)
	var audio = game.audio()
	if audio != null:
		audio.play_ending_summary()


func _build_view() -> void:
	viewport = SubViewport.new()
	viewport.name = "EndingView"
	viewport.own_world_3d = true
	viewport.size = Vector2i(get_viewport_rect().size)
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if visible else SubViewport.UPDATE_DISABLED
	viewport.gui_disable_input = true
	add_child(viewport)
	var view := TextureRect.new()
	view.texture = viewport.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	_scene = Node3D.new()
	viewport.add_child(_scene)
	camera = Camera3D.new()
	camera.fov = 48.0
	camera.far = 1500.0
	_scene.add_child(camera)
	camera.make_current()
	var env := WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = Sky.new()
	_environment.sky.sky_material = PaletteMaterials.workshop_sky()
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_energy = WorldLook.ENDING.energy
	_environment.fog_enabled = true
	_environment.fog_density = WorldLook.ENDING.fog
	env.environment = _environment
	_scene.add_child(env)
	_sun = DirectionalLight3D.new()
	_sun.name = "EndingSun"
	_sun.light_energy = WorldLook.ENDING.sun_energy
	_sun.rotation_degrees = WorldLook.ENDING.sun_rotation
	_scene.add_child(_sun)
	_bar_top = _backing(0.0, 0.14, Palette.CHARCOAL)
	_bar_bottom = _backing(0.73, 1.0, Palette.CHARCOAL)
	_world_label = _label(UiTokens.LABEL, Palette.SAND)
	_world_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_world_label.offset_top = 28.0
	_world_label.text = String(Worlds.ENDING.title)
	_copy = _label(UiTokens.LABEL, Palette.SAND)
	_copy.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_copy.offset_left = 60.0
	_copy.offset_right = -60.0
	_copy.offset_top = -205.0
	_copy.offset_bottom = -65.0
	_copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_credits_back = _backing(0.0, 1.0, Color(Palette.CHARCOAL, 0.6))
	_credits_back.visible = false
	_credits_clip = Control.new()
	_credits_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credits_clip.offset_bottom = -HINT_BAND
	_credits_clip.clip_contents = true
	_credits_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credits_clip.visible = false
	add_child(_credits_clip)
	_credits = _label(UiTokens.HEADING, Palette.SAND)
	remove_child(_credits)
	_credits_clip.add_child(_credits)
	_credits.text = CREDITS
	_credits.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_credits_band = _backing(0.73, 1.0, Palette.CHARCOAL)
	_credits_band.visible = false
	_hint_band = ColorRect.new()
	_hint_band.name = "HintBand"
	_hint_band.color = Palette.CHARCOAL
	_hint_band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_band.offset_top = -HINT_BAND
	_hint_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_band)
	skip_hint = CreditsHint.new()
	skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	skip_hint.offset_top = -HINT_BAND
	skip_hint.offset_bottom = 0.0
	skip_hint.setup(SKIP_HINT)
	add_child(skip_hint)
	move_child(_credits_band, -1)
	move_child(_copy, -1)
	move_child(_hint_band, -1)
	move_child(skip_hint, -1)
	_cut = _backing(0.0, 1.0, Color(Palette.CHARCOAL, 0.0))


static func credits_text(stats: Dictionary) -> String:
	var block := "Victory lap\nTop speed %d m/s · Best air %.1f s · Rim laps %d" % [int(stats.get("top_speed", 0.0)),
		float(stats.get("best_air", 0.0)), int(stats.get("rim_laps", 0))]
	var thanks := CREDITS.rfind("\n\n")
	return CREDITS.substr(0, thanks) + "\n\n" + block + CREDITS.substr(thanks)


func letterbox_bars() -> Array:
	return [_bar_top, _bar_bottom, _credits_band]


func hint_band_rect() -> Rect2:
	return _hint_band.get_global_rect()


func credits_rect() -> Rect2:
	return _credits.get_global_rect().intersection(_credits_clip.get_global_rect())


func _label(size_px: int, color: Color) -> Label:
	var label := UiDraw.label(size_px, color)
	add_child(label)
	return label


func _backing(top: float, bottom: float, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.anchor_top = top
	rect.anchor_bottom = bottom
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _build_worlds() -> void:
	for row in Worlds.ROWS:
		var stage: int = game.ctx.stages.first_of(int(row.id))
		var cached := 0
		var dressed := false
		for def in game.ctx.stages.DEFS:
			if int(def.world) == int(row.id) and game.ctx.terrain.is_built(int(def.stage)):
				var has_dressing: bool = game.ctx.terrain.geometry_root(int(def.stage)).has_node(WORLD_DRESSING[int(row.id)])
				if has_dressing or not dressed:
					cached = int(def.stage)
					dressed = has_dressing
		if cached > 0:
			stage = cached
		var holder := Node3D.new()
		holder.name = "World%d" % int(row.id)
		_scene.add_child(holder)
		if stage > 0:
			var map_id := String(game.ctx.stages.of(stage).map)
			if map_id.begins_with("park_"):
				if game.ctx.terrain.is_built(stage):
					_snapshot(game.ctx.terrain.geometry_root(stage), holder, true)
				else:
					_place_park_landmark(holder, stage, game.ctx.terrain.map_for(stage), map_id)
				_build_park_ground(holder, stage, int(row.id), map_id)
				_dress_world(holder, stage, int(row.id))
			else:
				if game.ctx.terrain.is_built(stage):
					_snapshot(game.ctx.terrain.geometry_root(stage), holder, true)
					_dress_world(holder, stage, int(row.id))
				else:
					_build_uncached(holder, stage, int(row.id))
				if int(row.id) == 3:
					_hide_grid_floor(holder)
		worlds.append(holder)
		stages.append(stage)
		holder.visible = false


# Godot 4.7.2 headless dummy rasterizer RID_Owner<DummyMesh> is not thread-safe and reports driver "vulkan", so AppShell.headless() selects serial loading.
func _build_crater() -> void:
	crater = Node3D.new()
	crater.name = "MeteorCrater"
	crater.visible = false
	_scene.add_child(crater)
	_crater_serial = AppShell.headless()
	if _crater_serial:
		_crater_requests.append_array(_crater_paths())
		return
	for path in _crater_paths():
		var error := ResourceLoader.load_threaded_request(path)
		if error == OK:
			_crater_requests.append(path)
		else:
			push_warning("ending_sequence: crater_ending GLB %s request failed (error %d)" % [path, error])


func _crater_paths() -> Array:
	var parts := ParkRecipes.paths(String(CRATER_ROW["recipe"]), String(CRATER_ROW["budget"]))
	var out: Array = [parts["base"]]
	out.append_array(parts["shells"])
	return out.filter(func(path): return ResourceLoader.exists(path))


func _place_crater() -> bool:
	if _crater_placed:
		return true
	if _crater_serial:
		_crater_placed = true
		for path in _crater_requests:
			var scene := load(path) as PackedScene
			if scene != null:
				_crater_files.append(scene)
			else:
				push_warning("ending_sequence: crater_ending GLB %s did not load" % path)
		_crater_requests.clear()
		return _lay_crater()
	for path in _crater_requests:
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return false
	_crater_placed = true
	for path in _crater_requests:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_crater_files.append(ResourceLoader.load_threaded_get(path))
		else:
			push_warning("ending_sequence: crater_ending GLB %s did not load (status %d)" % [path, status])
			if status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				ResourceLoader.load_threaded_get(path)
	_crater_requests.clear()
	return _lay_crater()


func _lay_crater() -> bool:
	var placed := ParkRecipes.place(CRATER_ROW, crater, Callable(), Callable())
	if placed == null:
		push_warning("ending_sequence: crater_ending placed nothing; the credits roll over the sky")
		return true
	for body in placed.find_children("Collider", "StaticBody3D", true, false):
		body.get_parent().remove_child(body)
		body.free()
	return true


func _release_crater_requests() -> void:
	if not _crater_serial:
		for path in _crater_requests:
			if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				ResourceLoader.load_threaded_get(path)
	_crater_requests.clear()
	_crater_files.clear()


func _exit_tree() -> void:
	_release_crater_requests()


func _hide_grid_floor(holder: Node3D) -> void:
	var floor_node := holder.find_child("Ground", true, false) as Node3D
	if floor_node != null:
		floor_node.visible = false


func _snapshot(source: Node, parent: Node3D, root := false) -> void:
	if source is Node3D and not root and not source.visible:
		return
	var view: Node3D
	if source is MeshInstance3D:
		var mesh := MeshInstance3D.new()
		mesh.mesh = source.mesh
		mesh.skin = source.skin
		mesh.skeleton = source.skeleton
		if mesh.mesh != null:
			for i in mini(mesh.mesh.get_surface_count(), source.get_surface_override_material_count()):
				var material: Material = source.get_surface_override_material(i)
				if material != null:
					mesh.set_surface_override_material(i, material)
		view = mesh
	elif source is MultiMeshInstance3D:
		var multi := MultiMeshInstance3D.new()
		multi.multimesh = source.multimesh
		view = multi
	elif source is Skeleton3D:
		var skeleton := Skeleton3D.new()
		for i in source.get_bone_count():
			skeleton.add_bone(source.get_bone_name(i))
			skeleton.set_bone_parent(i, source.get_bone_parent(i))
			skeleton.set_bone_rest(i, source.get_bone_rest(i))
			skeleton.set_bone_pose_position(i, source.get_bone_pose_position(i))
			skeleton.set_bone_pose_rotation(i, source.get_bone_pose_rotation(i))
			skeleton.set_bone_pose_scale(i, source.get_bone_pose_scale(i))
		view = skeleton
	else:
		view = Node3D.new()
	view.name = source.name
	if source is Node3D and not root:
		view.transform = source.transform
	if view is GeometryInstance3D:
		view.layers = source.layers
		view.material_override = source.material_override
		view.material_overlay = source.material_overlay
		view.cast_shadow = source.cast_shadow
	parent.add_child(view)
	for child in source.get_children():
		_snapshot(child, view)


func _build_uncached(holder: Node3D, stage: int, world: int) -> void:
	var map = game.ctx.terrain.map_for(stage)
	var ground := Node3D.new()
	ground.name = "Ground"
	holder.add_child(ground)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-200, 200, 8):
		for x in range(-200, 200, 8):
			for corner in [Vector2(x, z), Vector2(x + 8, z), Vector2(x, z + 8),
				Vector2(x + 8, z), Vector2(x + 8, z + 8), Vector2(x, z + 8)]:
				var sample: Array = map.sample(corner.x, corner.y)
				surface.set_color(sample[1])
				surface.add_vertex(Vector3(corner.x, sample[0], corner.y))
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = PaletteMaterials.ground_material()
	ground.add_child(mesh)
	_dress_world(holder, stage, world)


func _dress_world(holder: Node3D, stage: int, world: int) -> void:
	if holder.has_node(WORLD_DRESSING[world]):
		return
	var map = game.ctx.terrain.map_for(stage)
	var map_id := String(game.ctx.stages.of(stage).map)
	if world == 1 and not map_id.begins_with("park_"):
		SpillwayScenery.build(holder)
	elif world == 2 and map_id in ["dig", "dig_deep"]:
		DigScenery.build(holder, map, map_id)
	elif world == 3 and HighdraftScenery.is_highdraft(map):
		HighdraftScenery.build(holder, map)


const PARK_GROUND_TINTS := {
	1: Color(0.75, 0.61, 0.44),
	2: Color(0.45, 0.49, 0.54),
	3: Color(0.68, 0.56, 0.47),
}


func _park_spot_and_fwd(map, map_id: String) -> Dictionary:
	if Worlds.ENDING_PARK_SPOTS.has(map_id):
		var row: Dictionary = Worlds.ENDING_PARK_SPOTS[map_id]
		return {"spot": row["spot"], "fwd": (row["fwd"] as Vector3).normalized()}
	var h: Vector3 = map.heading
	var fwd := Vector3(h.x, 0.0, h.z).normalized() if Vector2(h.x, h.z).length() > 0.01 else Vector3.BACK
	return {"spot": map.spawn, "fwd": fwd}


func _load_park_heights(stage: int, map_id: String) -> PackedFloat32Array:
	if _park_heights.has(stage):
		return _park_heights[stage]
	if game.ctx.terrain.is_built(stage):
		var pg = game.ctx.terrain.park_ground(stage)
		if pg != null and not pg.heights.is_empty():
			_park_heights[stage] = pg.heights
			return pg.heights
	if ParkTerrain.has_bake(map_id):
		var dir := ParkTerrain.bake_dir(map_id)
		var arr := ParkTerrain._read_zstd(dir + "/ground.bin", ParkTerrain.SIDE * ParkTerrain.SIDE * 4).to_float32_array()
		_park_heights[stage] = arr
		return arr
	return PackedFloat32Array()


func _park_height(heights: PackedFloat32Array, x: float, z: float) -> float:
	if heights.is_empty():
		return 0.0
	var fx := clampf((x + ParkTerrain.HALF) / ParkTerrain.STEP, 0.0, float(ParkTerrain.SIDE - 2))
	var fz := clampf((z + ParkTerrain.HALF) / ParkTerrain.STEP, 0.0, float(ParkTerrain.SIDE - 2))
	var ix := int(floorf(fx))
	var iz := int(floorf(fz))
	var tx := fx - float(ix)
	var tz := fz - float(iz)
	var s := ParkTerrain.SIDE
	var h00 := heights[iz * s + ix]
	var h10 := heights[iz * s + ix + 1]
	var h01 := heights[(iz + 1) * s + ix]
	var h11 := heights[(iz + 1) * s + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _build_park_ground(holder: Node3D, stage: int, world: int, map_id: String) -> void:
	var heights := _load_park_heights(stage, map_id)
	if heights.is_empty():
		return
	var map = game.ctx.terrain.map_for(stage)
	var pose := _park_spot_and_fwd(map, map_id)
	var spot: Vector2 = pose["spot"]
	var fwd: Vector3 = pose["fwd"]
	var center := Vector2(spot.x + fwd.x * 260.0, spot.y + fwd.z * 260.0)
	var step := 16
	var half_span := 448
	var min_x := maxi(int(-ParkTerrain.HALF), int(floorf((center.x - half_span) / step)) * step)
	var max_x := mini(int(ParkTerrain.HALF) - step, int(ceilf((center.x + half_span) / step)) * step)
	var min_z := maxi(int(-ParkTerrain.HALF), int(floorf((center.y - half_span) / step)) * step)
	var max_z := mini(int(ParkTerrain.HALF) - step, int(ceilf((center.y + half_span) / step)) * step)
	var base: Color = PARK_GROUND_TINTS.get(world, PARK_GROUND_TINTS[1])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(min_z, max_z, step):
		for x in range(min_x, max_x, step):
			for corner in [Vector2(x, z), Vector2(x + step, z), Vector2(x, z + step),
				Vector2(x + step, z), Vector2(x + step, z + step), Vector2(x, z + step)]:
				var h := _park_height(heights, corner.x, corner.y)
				var shade := clampf(0.86 + h * 0.0022, 0.68, 1.16)
				surface.set_color(Color(base.r * shade, base.g * shade, base.b * shade, 1.0))
				surface.add_vertex(Vector3(corner.x, h, corner.y))
	surface.generate_normals()
	var ground := Node3D.new()
	ground.name = "ParkGround"
	holder.add_child(ground)
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = PaletteMaterials.ground_material()
	ground.add_child(mesh)


func _place_park_landmark(holder: Node3D, stage: int, map, map_id: String) -> void:
	if not ("park" in map) or not (map.park is Dictionary) or not map.park.has("landmark"):
		return
	var heights := _load_park_heights(stage, map_id)
	var ground_fn := func(x: float, z: float) -> float: return _park_height(heights, x, z)
	var placed := ParkRecipes.place(map.park["landmark"], holder, ground_fn, Callable())
	if placed == null:
		return
	for body in placed.find_children("*", "CollisionObject3D", true, false):
		body.get_parent().remove_child(body)
		body.free()


func _build_crew() -> void:
	if game.run.class_def == null or game.run.class_def.id != "remembered_cannon":
		quiet_gun = preload("res://src/presentation/quiet_gun.gd").make("")
		_scene.add_child(quiet_gun)
		quiet_gun.ending_ready()
		quiet_gun.visible = false
	shell = Node3D.new()
	shell.name = "PilotShell"
	_scene.add_child(shell)
	_snapshot(game.player.juice_node(), shell, true)
	if game.player.has_method("pod_mount"):
		_snapshot(game.player.pod_mount(), shell, true)
	companion = Node3D.new()
	companion.name = "SPIL9"
	_scene.add_child(companion)
	var body = game.presentation.get_node_or_null("CompanionBody")
	if body != null and body.visible:
		_snapshot(body, companion, true)
	else:
		var path := CompanionBody.model_path(["ram_prow", "escape_rail"])
		var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
		if packed != null:
			var model := packed.instantiate()
			CompanionBody.dress_model(model)
			_snapshot(model, companion, true)
			model.free()
		else:
			push_warning("ending_sequence: SPIL-9 model missing; keeping the plain hull")
			var builder := CompanionBody.new()
			var fallback := builder._fallback()
			companion.add_child(fallback)
			builder.free()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if not active:
		return
	elapsed = minf(TOTAL_SECONDS, elapsed + maxf(0.0, delta))
	if elapsed >= TOTAL_SECONDS or (prelude and elapsed >= WORLD_SECONDS * 3.0):
		skip()
		return
	var slot := mini(2, int(elapsed / WORLD_SECONDS))
	var index: int = _order[slot]
	if index != world_index:
		_enter_world(index)
	if elapsed >= WORLD_SECONDS * 3.0:
		phase = "credits"
		_credits_back.visible = true
		_credits_clip.visible = true
		_credits_band.visible = true
		_world_label.visible = false
		var credits_at := elapsed - WORLD_SECONDS * 3.0
		_set_credits_copy(credits_at)
		var p := credits_at / CREDITS_SECONDS
		var height := get_viewport_rect().size.y - HINT_BAND
		_credits.position.y = lerpf(height, -_credits.get_minimum_size().y, p)
		_cut.color.a = 0.0
		_show_crater(credits_at / CREDITS_SECONDS)
		return
	var local := fmod(elapsed, WORLD_SECONDS)
	if world_index == 2 and local >= 8.0 and not cannon_answered:
		cannon_answered = true
		cannon_answer_at = local
		var audio = game.audio()
		if audio != null:
			audio.cannon_motif("ending_cannon", true)
	phase = "flyover" if local < ESTABLISH_SECONDS else "copy"
	var lines: Array = Worlds.ENDING.log[int(Worlds.ROWS[world_index].id)]
	var line := mini(int(maxf(0.0, local - ESTABLISH_SECONDS) / LINE_SECONDS), lines.size() - 1)
	_copy.text = "" if phase == "flyover" else String(lines[line])
	_copy.modulate.a = clampf(fmod(maxf(0.0, local - ESTABLISH_SECONDS), LINE_SECONDS) / 0.4, 0.0, 1.0)
	var p := local / WORLD_SECONDS
	var sweep := lerpf(5.0, -5.0, smoothstep(0.0, 1.0, p))
	if _park_stage:
		var side := _cam_fwd.cross(Vector3.UP).normalized()
		var cam_pos := _at - _cam_fwd * 16.0 + side * (sweep * 0.55) + Vector3.UP * 3.8
		var cam_floor := _park_height(_active_heights, cam_pos.x, cam_pos.z)
		cam_pos.y = maxf(cam_pos.y, cam_floor + 2.5)
		var lift := maxf(0.0, cam_pos.y - (_at.y + 3.8))
		camera.position = cam_pos
		camera.look_at(_at + _cam_fwd * 8.0 + Vector3.UP * (0.2 + lift * 0.5))
	elif world_index == 2:
		camera.position = _at + Vector3(sweep, 7.0, 23.0)
		camera.look_at(_at + Vector3(1.0, 2.5, -4.0))
	elif world_index == 1 and _dig_deep:
		camera.position = _at + Vector3(sweep * 0.3 - 8.0, 16.0, 9.0)
		camera.look_at(_at + Vector3(-6.0, 1.0, -2.0))
	elif world_index == 1:
		camera.position = _at + Vector3(sweep - 8.0, 7.0, -23.0)
		camera.look_at(_at + Vector3(-8.0, 2.0, 4.0))
	else:
		camera.position = _at + Vector3(sweep - 20.0, 5.0, -20.0)
		camera.look_at(_at + Vector3(4.0, 1.0, 30.0))
	_cut.color.a = maxf(1.0 - local / 0.5, (local - WORLD_SECONDS + 0.5) / 0.5)
	_cut.color.a = clampf(_cut.color.a, 0.0, 1.0)
	viewport.size = Vector2i(get_viewport_rect().size)


func _show_crater(p: float) -> void:
	for holder in worlds:
		holder.visible = false
	if crater == null:
		return
	_place_crater()
	crater.visible = true
	var drop := smoothstep(0.0, 1.0, clampf(p, 0.0, 1.0))
	camera.position = CRATER_CAM_FROM.lerp(CRATER_CAM_TO, drop)
	camera.look_at(CRATER_LOOK)


func _set_credits_copy(credits_at: float) -> void:
	var close: Array = Worlds.ENDING.close
	var slot := int(credits_at / CREDITS_LINE_SECONDS)
	_copy.visible = true
	_copy.text = String(close[slot]) if slot < close.size() else String(Worlds.ENDING.sign)
	_copy.modulate.a = clampf(fmod(credits_at, CREDITS_LINE_SECONDS) / 0.4, 0.0, 1.0) if slot < close.size() else 1.0


func _world_order() -> Array[int]:
	if game == null or game.ctx == null or game.ctx.stages == null or game.run == null:
		return [0, 1, 2]
	var first_map := String(game.ctx.stages.of(1).get("map", ""))
	if first_map.begins_with("park_") and game.ctx.stages.world_of(int(game.run.stage)) == 3:
		return [2, 1, 0]
	return [0, 1, 2]


func _enter_world(index: int) -> void:
	world_index = index
	for i in worlds.size():
		worlds[i].visible = i == index
	var stage: int = stages[index]
	_at = Vector3.ZERO
	_dig_deep = false
	_park_stage = false
	_cam_fwd = Vector3.BACK
	_active_heights = PackedFloat32Array()
	if stage > 0:
		var map = game.ctx.terrain.map_for(stage)
		var map_id := String(game.ctx.stages.of(stage).map)
		_park_stage = map_id.begins_with("park_")
		var spot: Vector2 = map.spawn
		if _park_stage:
			var pose := _park_spot_and_fwd(map, map_id)
			spot = pose["spot"]
			_cam_fwd = pose["fwd"]
			_active_heights = _load_park_heights(stage, map_id)
			_at = Vector3(spot.x, _park_height(_active_heights, spot.x, spot.y) + 2.0, spot.y)
		else:
			if index == 0:
				spot = Vector2(0.0, 196.0)
			elif index == 1:
				_dig_deep = map_id == "dig_deep"
				spot = Vector2(63.0, 184.0) if _dig_deep else Vector2(-27.0, 178.0)
			_at = Vector3(spot.x, float(map.sample(spot.x, spot.y)[0]) + 2.0, spot.y)
	camera.fov = 46.0 if _dig_deep else 48.0
	var side := _cam_fwd.cross(Vector3.UP).normalized() if _park_stage else Vector3.RIGHT
	var back := -_cam_fwd if _park_stage else Vector3.FORWARD
	if quiet_gun != null:
		quiet_gun.visible = index == 2
		quiet_gun.position = _at - side * 3.0 + Vector3.UP * -0.4 + back * 0.5
	shell.position = _at
	companion.position = _at + side * 3.0 + Vector3.UP * -0.4 + back * 0.5
	_world_label.text = "%s\n%s" % [Worlds.ENDING.title, Worlds.ROWS[index].name]
	if index == 2:
		_highdraft_light(stage)
		return
	_environment.ambient_light_color = Palette.SAND
	_environment.fog_light_color = Palette.SAND
	_environment.sky.sky_material = PaletteMaterials.workshop_sky()
	_sun.light_color = Color(1.0, 0.95, 0.80)
	_sun.rotation_degrees = Vector3(-38.0, 118.0, 0.0)


func _highdraft_light(stage: int) -> void:
	var look := WorldLook.stage_look(stage, 3) if stage > 0 else WorldLook.row(3).merged(WorldLook.TIME_ROWS.dusk, true)
	var time: String = look.get("time", "dusk")
	if not _highdraft_skies.has(time):
		var material := PaletteMaterials.time_sky_material(HighdraftScenery._sky_material().panorama)
		var graded := WorldLook.grade(look)
		for key in graded:
			material.set(key, graded[key])
		_highdraft_skies[time] = material
	_environment.ambient_light_color = look.ambient
	_environment.fog_light_color = WorldLook.environment(look, false).fog_light_color
	_environment.sky.sky_material = _highdraft_skies[time]
	_sun.light_color = look.sun_color
	_sun.rotation_degrees = look.sun_rotation


func handle(event: InputEvent) -> void:
	if not lap.is_empty() and elapsed - _opened_at < SKIP_GUARD:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or ((event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventAction) and event.pressed)
	if pressed:
		skip()


func skip() -> void:
	if not active:
		return
	cancel()
	finished.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if active and visible else SubViewport.UPDATE_DISABLED


func cancel() -> void:
	active = false
	_release_crater_requests()
	visible = false
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
