extends SceneTree

const FxLibrary := preload("res://src/presentation/fx_library.gd")
const Vfx := preload("res://src/presentation/vfx.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")

# Particle look stills: every FxLibrary spec and every Vfx burst, one still each, fired on a
# sand plane under a fixed sun and sky, frozen at FREEZE of its life, so a build that changes how
# particles draw can be compared side by side with the build before it. A display server is
# needed (xvfb-run works; the cloud's software GL judges layout and read, not final look):
#   xvfb-run -s "-screen 0 1280x800x24" <godot> --path sketches/core-loop --rendering-driver opengl3 \
#     --script res://tools/fx_capture.gd -- --out=/abs/dir [--reduce-flashes] [--only=id,id]
# Writes <id>.png and frames.json.

const SIZE := Vector2i(640, 400)
const FREEZE := 0.35
const ROW_KIND := "enemy_struck"

var out := ""
var only: Array = []
var records := []
var camera: Camera3D
var stage: Node3D
var world_row := 1


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--reduce-flashes":
			FlashGuard.on = true
		elif arg.begins_with("--world="):
			world_row = int(arg.trim_prefix("--world="))
		elif arg.begins_with("--only="):
			only = Array(arg.trim_prefix("--only=").split(","))
	if out.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	# The world row's light as GraphicsPreset._apply_world sets it (no fog, no SSAO).
	var look: Dictionary = WorldLook.ROWS[world_row]
	var env := Environment.new()
	if look.sky == "hdri":
		env.background_mode = Environment.BG_SKY
		env.sky = Palette.hdri_sky()
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = look.background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = look.ambient
	env.ambient_light_sky_contribution = 0.25
	env.ambient_light_energy = look.energy
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = look.exposure
	env.tonemap_agx_white = 16.29
	env.tonemap_agx_contrast = 1.25
	env.adjustment_enabled = true
	env.adjustment_saturation = look.saturation
	env.glow_enabled = true
	env.glow_intensity = 0.18
	env.glow_hdr_threshold = 1.5
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = look.sun_rotation
	sun.light_color = look.sun_color
	sun.light_energy = look.sun_energy
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	# The packed sand floor as a plain lit material: the ground shader wants terrain vertex data.
	var sand := StandardMaterial3D.new()
	sand.albedo_texture = load("res://assets/textures/packed-sand-floor.webp")
	sand.uv1_scale = Vector3(12.0, 12.0, 1.0)
	sand.roughness = 0.95
	ground.material_override = sand
	stage.add_child(ground)
	# A charcoal crate for scale and for dark-background read.
	var crate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	crate.mesh = box
	crate.material_override = Palette.solid(Palette.VERDIGRIS)
	crate.position = Vector3(2.2, 0.5, -1.5)
	stage.add_child(crate)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = 50.0
	camera.look_at_from_position(Vector3(0.0, 3.2, 7.5), Vector3(0.0, 1.1, 0.0))
	for id in FxLibrary.SPECS:
		if only.is_empty() or id in only:
			await _spec_shot(id)
	var vfx := Vfx.new()
	vfx.root = Node3D.new()
	stage.add_child(vfx)
	stage.add_child(vfx.root)
	vfx._build_bursts()
	for kind in Vfx.BURSTS:
		var id: String = "burst_" + kind
		if only.is_empty() or id in only:
			await _burst_shot(vfx, kind)
	var file := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"world": world_row, "size": [SIZE.x, SIZE.y], "freeze": FREEZE, "reduce_flashes": FlashGuard.on,
		"adapter": RenderingServer.get_video_adapter_name(), "frames": records}, "\t"))
	quit()


func _spec_shot(id: String) -> void:
	var s: Dictionary = FxLibrary.spec(id)
	var p := FxLibrary.build(id)
	stage.add_child(p)
	p.preprocess = float(s["life"]) * FREEZE
	var at := Vector3(0.0, 0.6, 0.0)
	FxLibrary.fire(p, id, ROW_KIND, int(s["max"]), at, Color.TRANSPARENT, Vector3(1.0, 0.0, 0.0))
	await process_frame
	p.speed_scale = 0.0
	await _save(id)
	p.queue_free()
	await process_frame


func _burst_shot(vfx, kind: String) -> void:
	var spec: Dictionary = Vfx.BURSTS[kind]
	for p in vfx._bursts[kind]:
		p.preprocess = float(spec["life"]) * FREEZE
	vfx.burst(kind, Vector3(0.0, 0.6, 0.0), EventKinds.color(ROW_KIND), int(spec["max"]))
	await process_frame
	for p in vfx._bursts[kind]:
		p.speed_scale = 0.0
	await _save("burst_" + kind)
	for p in vfx._bursts[kind]:
		p.emitting = false
		p.speed_scale = 1.0


func _save(id: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := out.path_join(id + ".png")
	if image.save_png(path) != OK:
		quit(3)
	records.append({"id": id, "sha256": FileAccess.get_sha256(path)})
