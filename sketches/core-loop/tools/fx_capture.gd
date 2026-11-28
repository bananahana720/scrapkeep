extends SceneTree

const FxLibrary := preload("res://src/presentation/fx_library.gd")
const Vfx := preload("res://src/presentation/vfx.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const EventJuice := preload("res://src/presentation/event_juice.gd")
const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/core/flash_guard.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const AppShell := preload("res://src/core/app_shell.gd")


const SIZE := Vector2i(640, 400)
const FREEZE := 0.35
const ROW_KIND := "enemy_struck"
const DRAWN := 20

var out := ""
var freeze := FREEZE
var only: Array = []
var records := []
var camera: Camera3D
var stage: Node3D
var world_row := 1
var _empty := PackedByteArray()
var tint := Color.TRANSPARENT


class Eye:
	var cam: Camera3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--reduce-flashes":
			FlashGuard.on = true
		elif arg.begins_with("--world="):
			world_row = int(arg.trim_prefix("--world="))
		elif arg.begins_with("--freeze="):
			if not arg.trim_prefix("--freeze=").is_valid_float():
				quit(2)
				return
			freeze = clampf(float(arg.trim_prefix("--freeze=")), 0.0, 1.0)
		elif arg.begins_with("--tint="):
			tint = Color(arg.trim_prefix("--tint="))
		elif arg.begins_with("--only="):
			only = Array(arg.trim_prefix("--only=").split(","))
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
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = 50.0
	camera.look_at_from_position(Vector3(0.0, 3.2, 7.5), Vector3(0.0, 1.1, 0.0))
	for i in 6:
		await RenderingServer.frame_post_draw
	_empty = _bytes(root.get_texture().get_image())
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
	vfx.camera = Eye.new()
	vfx.camera.cam = camera
	vfx._build_glyphs()
	vfx._build_fx()
	for id in ["moment_hit", "moment_crit", "moment_kill", "moment_kill_elite"]:
		if only.is_empty() or id in only:
			await _moment_shot(vfx, id)
	var file := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"world": world_row, "size": [SIZE.x, SIZE.y], "freeze": freeze, "reduce_flashes": FlashGuard.on,
		"adapter": RenderingServer.get_video_adapter_name(), "frames": records}, "\t"))
	quit()


func _spec_shot(id: String) -> void:
	var s: Dictionary = FxLibrary.spec(id)
	var p := FxLibrary.build(id)
	stage.add_child(p)
	p.preprocess = float(s["life"]) * freeze
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
		p.preprocess = float(spec["life"]) * freeze
	vfx.burst(kind, Vector3(0.0, 0.6, 0.0), EventKinds.color(ROW_KIND), int(spec["max"]))
	await process_frame
	for p in vfx._bursts[kind]:
		p.speed_scale = 0.0
	await _save("burst_" + kind)
	for p in vfx._bursts[kind]:
		p.emitting = false
		p.speed_scale = 1.0
	await create_timer(float(spec["life"]) + 0.1).timeout


func _moment_shot(vfx, id: String) -> void:
	var at := Vector3(0.0, 0.6, 0.0)
	var used: Array = []
	for pool in vfx._fx.values():
		for p: GPUParticles3D in pool:
			p.preprocess = p.lifetime * freeze
	for kind in vfx._bursts:
		for p: CPUParticles3D in vfx._bursts[kind]:
			p.preprocess = p.lifetime * freeze
	var copper := EventKinds.color(ROW_KIND)
	match id:
		"moment_hit", "moment_crit":
			var crit := id == "moment_crit"
			var force := 30.0 if crit else 10.0
			vfx.glyph(ROW_KIND, at, 0.4, clampf(0.8 + force * 0.03, 0.8, 1.6), 0.14)
			var colour: Color = EventJuice.juice(ROW_KIND)["crit"]["color"] if crit else copper
			vfx.play_fx(ROW_KIND, at, colour, "crit" if crit else "")
		_:
			var shown: Color = tint if tint.a > 0.0 else copper
			vfx.kill_look(at - Vector3.UP * 0.6, 1.0, shown)
			if id == "moment_kill_elite":
				vfx.kill_mark.card(at + Vector3.UP * 2.0)
	await process_frame
	for g in vfx._glyphs:
		if g["t"] < 1.0:
			g["t"] = freeze
			vfx._draw_glyph(g)
	for slot in vfx.kill_mark._slots:
		if slot["t"] < 1.0:
			slot["t"] = freeze
			vfx.kill_mark._draw(slot)
	vfx.kill_mark.set_process(false)
	for pool in vfx._fx.values():
		for p: GPUParticles3D in pool:
			p.speed_scale = 0.0
	for kind in vfx._bursts:
		for p: CPUParticles3D in vfx._bursts[kind]:
			p.speed_scale = 0.0
	await _save(id)
	vfx.kill_mark.clear()
	vfx.kill_mark.set_process(true)
	for g in vfx._glyphs:
		g["t"] = 1.0
		g["node"].visible = false
	for pool in vfx._fx.values():
		for p: GPUParticles3D in pool:
			p.emitting = false
			p.speed_scale = 1.0
	for kind in vfx._bursts:
		for p: CPUParticles3D in vfx._bursts[kind]:
			p.emitting = false
			p.speed_scale = 1.0
	await create_timer(1.0).timeout


func _save(id: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := out.path_join(id + ".png")
	if image.save_png(path) != OK:
		quit(3)
	var seen := _drawn(_bytes(image))
	records.append({"id": id, "sha256": FileAccess.get_sha256(path), "drawn_px": seen.x, "contrast": seen.y})


static func _bytes(image: Image) -> PackedByteArray:
	image.convert(Image.FORMAT_RGB8)
	return image.get_data()


func _drawn(bytes: PackedByteArray) -> Vector2i:
	if bytes.size() != _empty.size():
		return Vector2i(-1, -1)
	var count := 0
	var total := 0
	for i in range(0, bytes.size(), 3):
		var moved := maxi(absi(bytes[i] - _empty[i]), maxi(absi(bytes[i + 1] - _empty[i + 1]), absi(bytes[i + 2] - _empty[i + 2])))
		if moved > DRAWN:
			count += 1
			total += moved
	return Vector2i(count, roundi(float(total) / count) if count > 0 else 0)
