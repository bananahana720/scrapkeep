extends SceneTree


const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const Palette := preload("res://src/core/palette.gd")
const AppShell := preload("res://src/core/app_shell.gd")

const SETTLE := 45
const WAIT_TICKS := 2400
const LANDED := 1.6
const ROLL_TICKS := 360
const ROLL_SPEED := 9.0
const TONE_DISTANCE := 0.12
const MARK_TINT := Color("00e0ff")
const LENS_M := 2.0
const PLAY_M := 8.0

var game
var out := ""
var stage := 1
var records := []
var failed := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--stage="):
			stage = int(arg.trim_prefix("--stage="))
	if out.is_empty() or AppShell.headless():
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		quit(3)
		return
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	var waited := 0
	while game.flow == null and waited < 600:
		waited += 1
		await physics_frame
	if game.flow == null:
		return _fail("the game never built its flow")
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	var source := Intent.Scripted.new()
	game.player.source = source
	var ground = game.ctx.spawner.ground
	var down := 0
	for i in WAIT_TICKS:
		await physics_frame
		var p: Vector3 = game.player.ball_position()
		down = down + 1 if p.y - Telegraph.ground_under(ground, p) < LANDED else 0
		if down >= 30:
			break
	if down < 30:
		return _fail("the ball never landed")
	if game.hud.get("first_steps") != null:
		game.hud.first_steps.modulate.a = 0.0
	if stage > 0:
		game.player.body().freeze = false
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		await _ticks(180)
		ground = game.ctx.spawner.ground
		game.run.set_max_hp(999999.0)
	var vfx = game.presentation.vfx
	var spot: Vector3 = game.player.ball_position()
	var ahead := _flat(game.flow.beacon.global_position - spot) if is_instance_valid(game.flow.beacon) else Vector3.BACK
	game.camera.snap(ahead)
	await _frames(SETTLE)

	var roll_speed := 0.0
	for i in ROLL_TICKS:
		source.hold["move"] = Vector2(0.0, 1.0)
		await physics_frame
		roll_speed = game.player.planar_velocity().length()
		if i > 120 and roll_speed >= ROLL_SPEED and vfx._roll.emitting and i % 20 == 0:
			break
	if roll_speed < ROLL_SPEED or not vfx._roll.emitting:
		return _fail("roll: the ball is not fast with dust live (speed %.1f, emitting %s)" % [roll_speed, vfx._roll.emitting])
	await _shot("roll", {"speed": roll_speed}, FxLibrary.colour("roll_dust", "rolling"))
	source.hold = {}
	await _place(spot, ahead)

	var cam := root.get_camera_3d()
	var fwd := -cam.global_basis.z
	var dust := FxLibrary.build("roll_dust")
	root.add_child(dust)
	dust.amount_ratio = 1.0
	dust.set_instance_shader_parameter(FxLibrary.TINT, FxLibrary.colour("roll_dust", "rolling"))
	var tone := FxLibrary.colour("roll_dust", "rolling")
	dust.global_position = cam.global_position + fwd * LENS_M
	dust.emitting = true
	await _frames(30)
	if not dust.emitting:
		return _fail("dust_lens: the dust is not live")
	await _shot("dust_lens", {"m": LENS_M}, tone)
	dust.global_position = cam.global_position + fwd * PLAY_M
	dust.restart()
	await _frames(30)
	await _shot("dust_play", {"m": PLAY_M}, tone)
	dust.emitting = false
	dust.queue_free()

	var mark = vfx.kill_mark
	mark.fire(cam.global_position + fwd * LENS_M, 3.0, MARK_TINT)
	await _frames(6)
	if not (mark._slots[mark._next - 1 if mark._next > 0 else mark.POOL - 1]["t"] < 1.0):
		return _fail("mark_lens: the mark is not live")
	await _shot("mark_lens", {"m": LENS_M}, MARK_TINT)
	await _frames(40)
	vfx.kill_look(game.player.ball_position() - Vector3.UP * 0.2, 1.0, MARK_TINT)
	await _frames(6)
	var live := false
	for slot in mark._slots:
		if slot["t"] < 1.0:
			live = true
	if not live:
		return _fail("mark_play: the mark is not live")
	await _shot("mark_play", {}, MARK_TINT)
	if failed != "":
		return
	var file := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	if file == null:
		quit(3)
		return
	var size := root.get_visible_rect().size
	var lib: GDScript = FxLibrary
	file.store_string(JSON.stringify({"tool": "lens_fade_still.gd", "size": [size.x, size.y], "tone_distance": TONE_DISTANCE,
		"adapter": RenderingServer.get_video_adapter_name(), "lens_fade": str(lib.get_script_constant_map().get("LENS_FADE", "none")),
		"frames": records}, "\t"))
	file.close()
	quit(0)


func _shot(id: String, note: Dictionary, tone: Color) -> void:
	if failed != "":
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := out.path_join("%s.png" % id)
	if image.save_png(path) != OK:
		return _fail("could not save %s" % path)
	var near := 0
	var w := image.get_width()
	var h := image.get_height()
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var c := image.get_pixel(x, y)
			if tone == MARK_TINT:
				if c.b > c.r + 0.2 and c.g > c.r + 0.15:
					near += 1
			elif Vector3(c.r - tone.r, c.g - tone.g, c.b - tone.b).length() < TONE_DISTANCE:
				near += 1
	var share := near / float((w / 2) * (h / 2))
	records.append({"id": id, "note": note, "tone": tone.to_html(false), "share": snappedf(share, 0.0001), "sha256": FileAccess.get_sha256(path)})
	print("PF53 shot %s share %.4f %s" % [id, share, str(note)])


func _place(point: Vector3, heading: Vector3) -> void:
	var body = game.player.body()
	body.freeze = false
	game.player.reset_to(point)
	await _ticks(2)
	body.freeze = true
	game.camera.snap(heading)
	await _frames(SETTLE)


func _fail(why: String) -> void:
	if failed != "":
		return
	failed = why
	push_error("lens_fade_still: %s" % why)
	quit(4)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()
