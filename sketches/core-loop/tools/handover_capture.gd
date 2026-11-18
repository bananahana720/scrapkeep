extends SceneTree

# Run only through display-run --offscreen. Use two fresh Game instances in the same
# embedded editor process so both passes share the renderer, scratch home and resources.
const OffscreenWindow := preload("res://tools/offscreen_window.gd")
const OPTIONS := ["--self-play", "--self-play-watch=1", "--self-play-until=win",
	"--self-play-seed=1", "--self-play-pilot=pylon_engineer", "--self-play-policy=skipper",
	"--self-play-min=650", "--table=park", "--models=tripo", "--profile=sitting",
	"--ball-look=cutaway", "--preset=high", "--fullscreen=0"]

var game
var qualify_only := false
var stage_one_draws := -1
var quit_arm := ""
var profile
var trace_warm := false
var pass_number := 0
var draws := PackedInt64Array()
var entries := {}
var sleep_at_entry := false


func _initialize() -> void:
	OffscreenWindow.apply(root)
	if OS.get_environment("SCRAPKEEP_OFFSCREEN") != "1" or DisplayServer.get_name().to_lower() != "embedded":
		printerr("handover_capture requires the watched embedded display")
		quit(2)
		return
	var args := Array(OS.get_cmdline_user_args())
	qualify_only = args.has("--w144-qualify")
	if qualify_only:
		args.erase("--w144-qualify")
	sleep_at_entry = args.has("--w144-plant")
	if sleep_at_entry:
		args.erase("--w144-plant")
	trace_warm = args.has("--w144-trace")
	if trace_warm:
		args.erase("--w144-trace")
	for arg: String in args.duplicate():
		if arg.begins_with("--w144-quit="):
			var arm := arg.trim_prefix("--w144-quit=")
			if quit_arm == "" and arm in ["wait", "lights", "particles", "game", "one-light", "empty", "one-emitter"]:
				quit_arm = arm
				args.erase(arg)
	if args != OPTIONS or (qualify_only and (sleep_at_entry or trace_warm)) or (quit_arm != "" and not qualify_only):
		printerr("handover_capture needs its fixed seed-1 sitting options")
		quit(2)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.frame_post_draw.connect(_drawn)
	if quit_arm in ["empty", "one-emitter"]:
		_minimal.call_deferred()
	else:
		_start.call_deferred()


# Is a live game scene required for the particle shader teardown errors?
func _minimal() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position.z = 3.0
	if quit_arm == "one-emitter":
		var emitter := GPUParticles3D.new()
		emitter.draw_pass_1 = BoxMesh.new()
		emitter.process_material = ParticleProcessMaterial.new()
		world.add_child(emitter)
	for frame in 120:
		await RenderingServer.frame_post_draw
	print("W144_RELEASE ", quit_arm)
	world.queue_free()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	print("W144_QUIT ", quit_arm)
	quit()


func _start() -> void:
	pass_number += 1
	draws.clear()
	entries.clear()
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.events.stage_entered.connect(_stage)
	game.events.boss_arena_entered.connect(_mark.bind("flume_to_bowl"))
	game.events.run_ended.connect(_finished, CONNECT_ONE_SHOT)
	print("W144_START ", pass_number)
	if trace_warm and pass_number == 2:
		profile = load("res://tools/frame_probe.gd").new()
		profile.watch(game, "user://handover-profile.ndjson", true)


func _drawn() -> void:
	draws.append(Time.get_ticks_usec())
	if qualify_only and stage_one_draws >= 0 and draws.size() - stage_one_draws == 120:
		stage_one_draws = -1
		if quit_arm != "":
			_quit_experiment.call_deferred()
			return
		var image := root.get_texture().get_image()
		var valid := image != null and image.get_size() == Vector2i(1920, 1080)
		if valid:
			valid = image.save_png("user://handover-qualification.png") == OK
		print("W144_QUALIFICATION ", ProjectSettings.globalize_path("user://handover-qualification.png"))
		quit(0 if valid else 2)


# Each arm starts at the same dam checkpoint and pauses the game before changing
# scene ownership. Keep drawing for two frames after release, including the wait control.
func _quit_experiment() -> void:
	paused = true
	for kind in ["Light3D", "GPUParticles3D"]:
		for node in game.find_children("*", kind, true, false):
			print("W144_NODE ", kind, " ", node.get_path())
			if (quit_arm == "lights" and kind == "Light3D") or (quit_arm == "particles" and kind == "GPUParticles3D"):
				node.queue_free()
	print("W144_RELEASE ", quit_arm)
	if quit_arm == "one-light":
		for light in game.find_children("*", "Light3D", true, false):
			print("W144_FREE_LIGHT ", light.get_path())
			light.free()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			print("W144_FREED_LIGHT")
	if quit_arm == "game":
		game.queue_free()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	print("W144_QUIT ", quit_arm)
	quit()


func _stage(stage: int, retry: bool) -> void:
	if retry:
		printerr("handover_capture: retry invalidates the pass")
		quit(2)
	elif stage == 1:
		stage_one_draws = draws.size()
	elif stage == 2:
		_mark("dam_to_flume")


func _mark(seam: String) -> void:
	entries[seam] = Time.get_ticks_usec()
	if pass_number == 2 and sleep_at_entry:
		OS.delay_msec(50)


func _finished(won: bool) -> void:
	_close.call_deferred(won)


func _close(won: bool) -> void:
	if not won or entries.size() != 2:
		printerr("handover_capture: both crossings and victory required, pass ", pass_number)
		quit(2)
		return
	# Save every observed interval overlapping each window, with absolute microsecond
	# endpoints. These and the entry signals use the same monotonic engine clock.
	var rows := {}
	for seam in entries:
		var start: int = entries[seam] - 1000000
		var end: int = entries[seam] + 5000000
		if draws.size() < 2 or draws[0] > start or draws[-1] < end:
			printerr("handover_capture: incomplete drawn window for ", seam)
			quit(2)
			return
		var samples: Array = []
		var worst_us := 0
		for i in range(1, draws.size()):
			if draws[i] > start and draws[i - 1] < end:
				samples.append([draws[i - 1], draws[i]])
				worst_us = maxi(worst_us, draws[i] - draws[i - 1])
		rows[seam] = {"entry_us": entries[seam], "max_ms": worst_us / 1000.0, "intervals_us": samples}
	print("W144_PASS ", JSON.stringify({"pass_number": pass_number, "planted": pass_number == 2 and sleep_at_entry, "seams": rows}))
	if pass_number == 2:
		if profile != null:
			profile.write()
		quit()
		return
	paused = false
	game.queue_free()
	await game.tree_exited
	await process_frame
	_start.call_deferred()
