extends SceneTree

const Palette := preload("res://src/core/palette.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const AppShell := preload("res://src/core/app_shell.gd")


const SIZE := Vector2i(1280, 720)
const COLOURS := ["VERDIGRIS", "RUST", "COPPER", "AMBER", "CHARCOAL", "SAND", "BRASS", "HAZARD"]

var out := ""
var world_row := 1
var stage: Node3D
var camera: Camera3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--world="):
			world_row = int(arg.trim_prefix("--world="))
	if out.is_empty() or AppShell.headless():
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
	var sand := StandardMaterial3D.new()
	sand.albedo_texture = load("res://assets/textures/packed-sand-floor.webp")
	sand.uv1_scale = Vector3(12.0, 12.0, 1.0)
	sand.roughness = 0.95
	ground.material_override = sand
	stage.add_child(ground)
	var crate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	crate.mesh = box
	crate.material_override = Palette.solid(Palette.VERDIGRIS)
	crate.position = Vector3(2.2, 0.5, -1.5)
	stage.add_child(crate)
	var named: Dictionary = (Palette as Script).get_script_constant_map()
	var shapes: Array[Mesh] = [BoxMesh.new(), CylinderMesh.new(), SphereMesh.new(), PrismMesh.new()]
	for i in COLOURS.size():
		for j in shapes.size():
			var view := MeshInstance3D.new()
			view.mesh = shapes[j]
			view.material_override = Palette.solid(named[COLOURS[i]])
			view.position = Vector3((i - 3.5) * 1.6, 0.5, -j * 1.6)
			view.rotation_degrees.y = 25.0
			stage.add_child(view)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = 50.0
	await _shot("row", Vector3(0.0, 6.5, 7.0), Vector3(0.0, 0.0, -2.4))
	await _shot("close", Vector3(-3.0, 1.3, 1.6), Vector3(-2.6, 0.5, -0.2))
	quit()


func _shot(id: String, eye: Vector3, target: Vector3) -> void:
	camera.look_at_from_position(eye, target)
	for i in 8:
		await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(out.path_join(id + ".png")) != OK:
		quit(3)
