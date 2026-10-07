extends Control

signal finished

const Worlds := preload("res://src/core/worlds.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const CompanionBody := preload("res://src/presentation/companion_body.gd")
const DigScenery := preload("res://src/presentation/dig_scenery.gd")
const HighdraftScenery := preload("res://src/presentation/highdraft_scenery.gd")
const SpillwayScenery := preload("res://src/presentation/spillway_scenery.gd")

const WORLD_SECONDS := 12.0
const ESTABLISH_SECONDS := 2.0
const LINE_SECONDS := 5.0
const CREDITS_SECONDS := 18.0
const TOTAL_SECONDS := WORLD_SECONDS * 3.0 + CREDITS_SECONDS
const WORLD_DRESSING := {1: "SpillwayScenery", 2: "DigScenery", 3: "HighdraftScenery"}
# TONE-READ: Credits. The thanks belongs to the person who made the return trip.
const CREDITS := "SCRAPKEEP\n\nCreator and director\nAndrew\n\nMade with\nGodot · Blender\n\nMusic\nACE-Step\n\nAI collaborators\nClaude · Codex\n\nThank you for bringing the crew home."

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
var shell: Node3D
var companion: Node3D
var _scene: Node3D
var _environment: Environment
var _sun: DirectionalLight3D
var _world_label: Label
var _copy: Label
var _credits: Label
var _credits_back: ColorRect
var _cut: ColorRect
var _at := Vector3.ZERO
var _dig_deep := false


func start(game_ref) -> void:
	game = game_ref
	name = "EndingSequence"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var began := Time.get_ticks_usec()
	_build_view()
	_build_worlds()
	_build_crew()
	prepare_usec = Time.get_ticks_usec() - began
	active = true
	advance(0.0)
	# run_ended already selects the summary music through the audio director. Calling
	# its menu API also covers a sequence started from an already-settled summary.
	var audio = game.presentation.audio
	if audio != null:
		audio._flush_flow()
		audio.engine.menu_theme("summary", true)


func _build_view() -> void:
	viewport = SubViewport.new()
	viewport.name = "EndingView"
	viewport.own_world_3d = true
	viewport.size = Vector2i(get_viewport_rect().size)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	_environment.sky.sky_material = Palette.workshop_sky()
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_energy = 0.9
	_environment.fog_enabled = true
	_environment.fog_density = 0.0008
	env.environment = _environment
	_scene.add_child(env)
	_sun = DirectionalLight3D.new()
	_sun.light_energy = 1.2
	_sun.rotation_degrees = Vector3(-38.0, 118.0, 0.0)
	_scene.add_child(_sun)
	_backing(0.0, 0.14, Color(Palette.CHARCOAL, 0.78))
	_backing(0.73, 1.0, Color(Palette.CHARCOAL, 0.88))
	_world_label = _label(26, Palette.SAND)
	_world_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_world_label.offset_top = 28.0
	_world_label.text = String(Worlds.ENDING.title)
	_copy = _label(24, Palette.SAND)
	_copy.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_copy.offset_left = 60.0
	_copy.offset_right = -60.0
	_copy.offset_top = -205.0
	_copy.offset_bottom = -65.0
	_copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var skip_label := _label(18, Palette.SAND)
	skip_label.text = "Confirm / Back · Skip to summary"
	skip_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	skip_label.offset_top = -48.0
	skip_label.offset_bottom = -20.0
	_credits_back = _backing(0.0, 1.0, Color(Palette.CHARCOAL, 0.94))
	_credits_back.visible = false
	_credits = _label(30, Palette.SAND)
	_credits.text = CREDITS
	_credits.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_credits.visible = false
	# Keep the skip hint above the credit roll.
	move_child(skip_label, -1)
	_cut = _backing(0.0, 1.0, Color(Palette.CHARCOAL, 0.0))


func _label(size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		# Terrain caches sibling zones before their presentation is built.
		var cached := 0
		for def in game.ctx.stages.DEFS:
			if int(def.world) == int(row.id) and game.ctx.terrain.is_built(int(def.stage)):
				if cached == 0:
					cached = int(def.stage)
				if game.ctx.terrain.geometry_root(int(def.stage)).has_node(WORLD_DRESSING[int(row.id)]):
					cached = int(def.stage)
					break
		if cached > 0:
			stage = cached
		var holder := Node3D.new()
		holder.name = "World%d" % int(row.id)
		_scene.add_child(holder)
		if stage > 0:
			if game.ctx.terrain.is_built(stage):
				_snapshot(game.ctx.terrain.geometry_root(stage), holder, true)
				_dress_world(holder, stage, int(row.id))
			else:
				_build_uncached(holder, stage, int(row.id))
		worlds.append(holder)
		stages.append(stage)
		holder.visible = false


# Copy draw nodes, never scripts, timers, bodies, areas or collision shapes. Inactive
# terrain roots are hidden and parked at -5000; only their children carry local poses.
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
		# The skeleton's rest pose keeps the pilot recognizable in the cockpit.
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
	if source is GeometryInstance3D:
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
	# A far-camera ground at 8 m resolution; the live terrain grid is never touched.
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
	mesh.material_override = Palette.ground_material()
	ground.add_child(mesh)
	_dress_world(holder, stage, world)


func _dress_world(holder: Node3D, stage: int, world: int) -> void:
	if holder.has_node(WORLD_DRESSING[world]):
		return
	var map = game.ctx.terrain.map_for(stage)
	if world == 1:
		SpillwayScenery.build(holder)
	elif world == 2:
		DigScenery.build(holder, map, String(game.ctx.stages.of(stage).map))
	elif world == 3:
		HighdraftScenery.build(holder, map)


func _build_crew() -> void:
	shell = Node3D.new()
	shell.name = "PilotShell"
	_scene.add_child(shell)
	_snapshot(game.player.juice_node(), shell, true)
	companion = Node3D.new()
	companion.name = "SPIL9"
	_scene.add_child(companion)
	var body = game.presentation.get_node_or_null("CompanionBody")
	if body != null and body.visible:
		_snapshot(body, companion, true)
	else:
		# A return-trip tableau may show SPIL-9 even before modules were seated.
		# This is a draw-only stand-in; it does not assemble or grant a companion.
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
	if elapsed >= TOTAL_SECONDS:
		skip()
		return
	var index := mini(2, int(elapsed / WORLD_SECONDS))
	if index != world_index:
		_enter_world(index)
	if elapsed >= WORLD_SECONDS * 3.0:
		phase = "credits"
		_credits_back.visible = true
		_credits.visible = true
		_world_label.visible = false
		_copy.visible = false
		var p := (elapsed - WORLD_SECONDS * 3.0) / CREDITS_SECONDS
		var height := get_viewport_rect().size.y
		_credits.position.y = lerpf(height, -_credits.get_minimum_size().y, p)
		_cut.color.a = 0.0
		return
	var local := fmod(elapsed, WORLD_SECONDS)
	phase = "flyover" if local < ESTABLISH_SECONDS else "copy"
	var line := world_index * 2 + int(maxf(0.0, local - ESTABLISH_SECONDS) / LINE_SECONDS)
	var lines: Array = Worlds.ENDING.log.duplicate()
	lines.append(Worlds.ENDING.sign)
	_copy.text = "" if phase == "flyover" else String(lines[mini(line, lines.size() - 1)])
	_copy.modulate.a = clampf(fmod(maxf(0.0, local - ESTABLISH_SECONDS), LINE_SECONDS) / 0.4, 0.0, 1.0)
	var p := local / WORLD_SECONDS
	var sweep := lerpf(5.0, -5.0, smoothstep(0.0, 1.0, p))
	if world_index == 2:
		camera.position = _at + Vector3(sweep, 7.0, 23.0)
		camera.look_at(_at + Vector3(1.0, 2.5, -4.0))
	elif world_index == 1 and _dig_deep:
		camera.position = _at + Vector3(sweep * 0.3 - 8.0, 16.0, 9.0)
		camera.look_at(_at + Vector3(-6.0, 1.0, -2.0))
	elif world_index == 1:
		camera.position = _at + Vector3(sweep - 8.0, 7.0, -23.0)
		camera.look_at(_at + Vector3(-8.0, 2.0, 4.0))
	else:
		camera.position = _at + Vector3(sweep - 4.0, 7.0, -23.0)
		camera.look_at(_at + Vector3(-4.0, 2.0, 4.0))
	_cut.color.a = maxf(1.0 - local / 0.5, (local - WORLD_SECONDS + 0.5) / 0.5)
	_cut.color.a = clampf(_cut.color.a, 0.0, 1.0)
	viewport.size = Vector2i(get_viewport_rect().size)


func _enter_world(index: int) -> void:
	world_index = index
	for i in worlds.size():
		worlds[i].visible = i == index
	var stage: int = stages[index]
	_at = Vector3.ZERO
	_dig_deep = false
	if stage > 0:
		var map = game.ctx.terrain.map_for(stage)
		var spot: Vector2 = map.spawn
		# These are draw-only reunion positions, away from the empty drop-in sand.
		if index == 0:
			spot = Vector2(0.0, 196.0)
		elif index == 1:
			_dig_deep = String(game.ctx.stages.of(stage).map) == "dig_deep"
			spot = Vector2(63.0, 184.0) if _dig_deep else Vector2(-27.0, 178.0)
		_at = Vector3(spot.x, float(map.sample(spot.x, spot.y)[0]) + 2.0, spot.y)
	camera.fov = 46.0 if _dig_deep else 48.0
	shell.position = _at
	companion.position = _at + Vector3(3.0, -0.8, -0.5)
	_world_label.text = "%s\n%s" % [Worlds.ENDING.title, Worlds.ROWS[index].name]
	_environment.ambient_light_color = Color("b4c0c9") if index == 2 else Palette.SAND
	_environment.fog_light_color = Color("798c9e") if index == 2 else Palette.SAND
	_environment.sky.sky_material = HighdraftScenery._sky_material() if index == 2 else Palette.workshop_sky()
	_sun.light_color = Color("fff1dc") if index == 2 else Color(1.0, 0.95, 0.80)
	_sun.rotation_degrees = Vector3(-46.0, 62.0, 0.0) if index == 2 else Vector3(-38.0, 118.0, 0.0)


func handle(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		skip()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			skip()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B]:
		skip()


func skip() -> void:
	if not active:
		return
	cancel()
	finished.emit()


func cancel() -> void:
	active = false
	visible = false
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
