extends Node

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const CompanionBody := preload("res://src/presentation/companion_body.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const Palette := preload("res://src/core/palette.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const TitleIntros := preload("res://src/presentation/title_intros.gd")
const TitleIntroPlayer := preload("res://src/presentation/title_intro_player.gd")
const HighdraftFx := preload("res://src/presentation/highdraft_fx.gd")
const Worlds := preload("res://src/core/worlds.gd")

const PILOTS := [
	{"id": "pylon_engineer", "name": "SableShell", "color": ClassDef.SABLE_COLOR, "at": Vector3(-3.5, 1.04, 0.0)},
	{"id": "runner_gunner", "name": "RivetShell", "color": ClassDef.RIVET_COLOR, "at": Vector3(0.0, 1.04, -0.7)},
	{"id": "demolitions_caster", "name": "KestShell", "color": ClassDef.KEST_COLOR, "at": Vector3(3.5, 1.04, 0.0)},
]
const LOOK := Vector3(0.0, 2.6, 0.0)
const CAMERA_AT := Vector3(0.6, 5.1, 12.8)
const COMPANION_AT := Vector3(5.1, 1.7, 1.0)

var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var companion: Node3D
var active := false
var _layer: CanvasLayer
var _picture: TextureRect
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _environment: Environment
var _clock := 0.0
var _warned := {}
# The rotating opening (title_intros.gd). It autoplays once per launch on the first title
# screen, never for bots or tests (bot_driven, test_mode, a headless display) and never with
# --no-intro.
var intro: Node
var intro_autoplay := true
var _intro_tried := false
var _ctx


func setup(ctx) -> void:
	name = "TitleStage"
	_ctx = ctx
	intro_autoplay = ctx.root != null and not bool(ctx.root.get("bot_driven")) and not bool(ctx.root.get("test_mode")) \
		and DisplayServer.get_name() != "headless" and not "--no-intro" in OS.get_cmdline_user_args()
	process_mode = Node.PROCESS_MODE_ALWAYS
	viewport = SubViewport.new()
	viewport.name = "TitleViewport"
	viewport.own_world_3d = true
	viewport.physics_object_picking = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	stage = Node3D.new()
	stage.name = "SpillwayServiceDeck"
	viewport.add_child(stage)
	_build_lights()
	_build_deck()
	_build_heroes()
	_build_companion()
	camera = Camera3D.new()
	camera.name = "TitleCamera"
	camera.fov = 48.0
	camera.environment = _environment
	stage.add_child(camera)
	camera.current = true
	_frame()
	_layer = CanvasLayer.new()
	_layer.name = "TitleBackdrop"
	_layer.layer = 4
	add_child(_layer)
	_picture = TextureRect.new()
	_picture.name = "StagePicture"
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.texture = viewport.get_texture()
	_layer.add_child(_picture)
	get_viewport().size_changed.connect(_resize)
	intro = TitleIntroPlayer.new()
	add_child(intro)
	intro.setup(self)
	intro.finished.connect(_intro_finished)
	ctx.events.flow_changed.connect(show_flow)
	ctx.events.boss_arena_entered.connect(_boss_met)
	GraphicsPreset.register_dressing_host(self)
	show_flow(ctx.flow.state_name())


func show_flow(state: String) -> void:
	active = state in ["title", "class_select"]
	_layer.visible = active
	stage.visible = active
	if state != "title" and intro_playing():
		intro.skip()
	_sync_dressing()
	if state == "title" and intro_autoplay and not _intro_tried:
		_intro_tried = true
		play_intro.call_deferred()


func intro_playing() -> bool:
	return intro != null and intro.playing


# Plays the opening the profile's state picks (or the given row) and records it as shown.
func play_intro(id := "") -> bool:
	if not active or intro_playing() or (_ctx != null and _ctx.flow.state_name() != "title"):
		return false
	var profile = _ctx.profile if _ctx != null else null
	if id == "":
		var root = _ctx.root if _ctx != null else null
		var flyable := func(pilot: String) -> bool:
			var def = ClassDef.by_id(pilot)
			return def != null and root != null and root.has_method("pilot_unlocked") and root.pilot_unlocked(def)
		id = TitleIntros.pick(TitleIntros.facts_from(profile, flyable))
	intro.reduced_motion = HighdraftFx.preferred
	if not intro.play(id, viewport.get_texture()):
		return false
	if profile != null:
		TitleIntros.mark_shown(profile, id)
		if profile.can_save:
			profile.save()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# The music side starts title take A or B on bar 1; a no-op until audio carries title_theme.
	var audio = get_parent().get("audio") if get_parent() != null else null
	if audio != null and audio.has_method("title_theme"):
		audio.title_theme(intro.theme)
	return true


func _intro_finished(_id: String, _skipped: bool) -> void:
	_frame()
	_sync_dressing()


func _boss_met() -> void:
	var run = _ctx.run if _ctx != null else null
	var boss: Dictionary = Worlds.boss_of(int(run.world)) if run != null else {}
	# Memory only: the run's own save carries it, so a boss entry never adds a disk write.
	if _ctx.profile != null:
		TitleIntros.mark_met(_ctx.profile, String(boss.get("kind", "")))


func _sync_dressing() -> void:
	var spec: Dictionary = GraphicsPreset.PRESETS[GraphicsPreset.current]
	var low := GraphicsPreset.current == "low"
	viewport.msaa_3d = spec.msaa
	viewport.mesh_lod_threshold = spec.lod_threshold
	_environment.ssao_enabled = spec.ssao
	_environment.glow_enabled = spec.glow
	_environment.ambient_light_energy = WorldLook.TITLE.energy
	_sun.rotation_degrees = WorldLook.TITLE.sun_rotation
	_sun.light_energy = WorldLook.TITLE.sun_energy
	_sun.shadow_enabled = not low
	_fill.light_energy = WorldLook.TITLE.fill
	_resize()
	if intro_playing():
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		return
	set_process(active and not low)
	if not active:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if low else SubViewport.UPDATE_ALWAYS


func _resize() -> void:
	var pixels := Vector2i(get_viewport().get_visible_rect().size)
	if GraphicsPreset.current == "low":
		pixels /= 2
	viewport.size = Vector2i(maxi(1, pixels.x), maxi(1, pixels.y))
	if active and GraphicsPreset.current == "low":
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _process(delta: float) -> void:
	if intro_playing():
		return
	_clock += delta
	_frame()
	companion.position = COMPANION_AT + Vector3(0.0, sin(_clock * 1.25) * 0.09, 0.0)
	companion.rotation.y = -0.3 + sin(_clock * 0.35) * 0.08


func _frame() -> void:
	var drift := Vector3(sin(_clock * 0.12) * 0.55, sin(_clock * 0.17) * 0.12, cos(_clock * 0.12) * 0.18)
	camera.position = CAMERA_AT + drift
	camera.look_at(LOOK)


func _build_lights() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = WorldLook.TITLE.background
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = WorldLook.TITLE.ambient
	_environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_environment.tonemap_exposure = WorldLook.TITLE.exposure
	_environment.tonemap_agx_contrast = WorldLook.TITLE.contrast
	_environment.glow_intensity = 0.18
	_environment.glow_hdr_threshold = 1.5
	_environment.ssao_radius = 0.45
	_environment.ssao_intensity = 1.15
	_sun = DirectionalLight3D.new()
	_sun.name = "SpillwaySun"
	_sun.light_color = WorldLook.TITLE.sun_color
	_sun.directional_shadow_max_distance = 30.0
	stage.add_child(_sun)
	_fill = DirectionalLight3D.new()
	_fill.name = "SkyFill"
	_fill.rotation_degrees = WorldLook.TITLE.fill_rotation
	_fill.light_color = WorldLook.TITLE.fill_color
	_fill.shadow_enabled = false
	stage.add_child(_fill)
	var lamp := OmniLight3D.new()
	lamp.name = "WorkLamp"
	lamp.position = Vector3(-5.1, 2.5, 1.6)
	lamp.light_color = WorldLook.TITLE.lamp_color
	lamp.light_energy = WorldLook.TITLE.lamp_energy
	lamp.omni_range = 5.0
	stage.add_child(lamp)


func _build_deck() -> void:
	_box("ServiceDeck", Vector3(13.0, 0.22, 5.0), Vector3(0.0, -0.16, 0.0), Palette.VERDIGRIS)
	for i in 7:
		_box("DeckPlate%d" % i, Vector3(1.79, 0.08, 4.75), Vector3(-5.55 + i * 1.85, -0.02, 0.0), Palette.CHARCOAL.lerp(Palette.COPPER, 0.15))
	_box("CanalLip", Vector3(13.0, 0.3, 0.16), Vector3(0.0, 0.04, -2.4), Palette.SANDSTONE)
	_box("WaterChannel", Vector3(13.0, 0.05, 1.0), Vector3(0.0, -0.05, -3.0), Color("397873"))
	for i in 3:
		var pipe := CylinderMesh.new()
		pipe.top_radius = 0.16
		pipe.bottom_radius = 0.16
		pipe.height = 2.4
		var view := _mesh("PumpPipe%d" % i, pipe, Vector3(-5.5 + i * 5.5, 0.8, -2.9), Palette.COPPER)
		view.rotation.z = PI * 0.5
		_box("PipeBrace%d" % i, Vector3(0.5, 0.45, 0.5), Vector3(-5.5 + i * 5.5, 0.2, -2.9), Palette.VERDIGRIS)
	var lens := _box("LanternLens", Vector3(0.22, 0.32, 0.22), Vector3(-5.1, 2.0, 1.6), Palette.AMBER)
	var mat := lens.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = Palette.AMBER
	mat.emission_energy_multiplier = 1.5
	_box("LanternPost", Vector3(0.09, 2.0, 0.09), Vector3(-5.1, 0.9, 1.6), Palette.CHARCOAL)
	var ball := SphereMesh.new()
	ball.radius = 0.45
	ball.height = 0.9
	_mesh("Ball", ball, Vector3(-5.0, 0.45, 0.5), Palette.COPPER)
	var hoop := TorusMesh.new()
	hoop.inner_radius = 0.46
	hoop.outer_radius = 0.52
	var ring := _mesh("BallGyro", hoop, Vector3(-5.0, 0.45, 0.5), Palette.SAND)
	ring.rotation.x = PI * 0.5


func _build_heroes() -> void:
	var painter := HeroAssets.new()
	for row in PILOTS:
		var holder := Node3D.new()
		holder.name = row.name
		holder.position = row.at
		holder.rotation.y = -0.22
		stage.add_child(holder)
		var path: String = HeroAssets.SHELLS[row.id]
		var shell := _visual_scene(path)
		var pod := shell.find_child("Pod", true, false) as Node3D if shell != null else null
		var core := shell.find_child("Core", true, false) as Node3D if shell != null else null
		if pod == null or core == null:
			if shell != null:
				shell.free()
			_warn(path)
			_fallback_shell(holder, row.color)
			continue
		painter.paint(shell, {"class": row.color})
		var fitted := painter.fit_pilot_into(pod, row.id, row.color)
		if not fitted.is_empty() and fitted.animator != null:
			fitted.animator.stop()
			for skeleton in fitted.pilot.find_children("*", "Skeleton3D", true, false):
				skeleton.reset_bone_poses()
		if not _visual_only(shell):
			shell.free()
			_warn(HeroAssets.PILOTS[row.id])
			_fallback_shell(holder, row.color)
			continue
		holder.add_child(shell)
		_freeze_visual(shell)
	painter.free()


func _fallback_shell(holder: Node3D, color: Color) -> void:
	var fallback := SphereMesh.new()
	fallback.radius = 0.98
	fallback.height = 1.96
	_mesh("ShellFallback", fallback, Vector3.ZERO, color, holder)


func _build_companion() -> void:
	companion = Node3D.new()
	companion.name = "SPIL9"
	companion.position = COMPANION_AT
	companion.rotation.y = -0.3
	stage.add_child(companion)
	var path := CompanionBody.model_path(["primer_coil", "ram_prow"])
	var model := _visual_scene(path)
	if model == null:
		_warn(path)
		_box("CompanionHullFallback", Vector3(1.1, 0.42, 0.72), Vector3.ZERO, Palette.VERDIGRIS, companion)
		for x in [-0.29, 0.29]:
			_box("ModuleFallback", Vector3(0.2, 0.3, 0.2), Vector3(x, 0.38, 0.0), Palette.COPPER, companion)
		return
	CompanionBody.dress_model(model)
	companion.add_child(model)
	_freeze_visual(model)


# Reject malformed imported scenes before they enter any physics space.
func _visual_scene(path: String) -> Node3D:
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if packed == null:
		return null
	var state := packed.get_state()
	for i in state.get_node_count():
		var type := state.get_node_type(i)
		if ClassDB.class_exists(type) and ClassDB.is_parent_class(type, "CollisionObject3D"):
			return null
	var model := packed.instantiate()
	if not model is Node3D or not _visual_only(model):
		model.free()
		return null
	return model as Node3D


func _visual_only(model: Node) -> bool:
	var pending: Array[Node] = [model]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is CollisionObject3D:
			return false
		pending.append_array(node.get_children())
	return true


func _freeze_visual(model: Node) -> void:
	model.process_mode = Node.PROCESS_MODE_DISABLED
	for animator in model.find_children("*", "AnimationPlayer", true, false):
		animator.stop()


func _warn(path: String) -> void:
	if not _warned.has(path):
		_warned[path] = true
		push_warning("title_stage: '%s' unavailable or malformed; keeping a simple display body" % path)


func _box(label: String, dimensions: Vector3, at: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = dimensions
	return _mesh(label, box, at, color, parent)


func _mesh(label: String, mesh: Mesh, at: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = mesh
	view.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.78
	view.material_override = mat
	(stage if parent == null else parent).add_child(view)
	return view
