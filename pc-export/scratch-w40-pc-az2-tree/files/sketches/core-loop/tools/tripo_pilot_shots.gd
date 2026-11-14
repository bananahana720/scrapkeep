extends SceneTree
# SCRATCH ONLY (PC lane job AZ, 14 Nov 2026): never for the repo's tests or a game branch.
# The park with a chosen pilot, the play camera's own picture at rest and rolling, then the pilot's
# big_cheer and heave clips held at their widest frame, from the play camera and from a camera in
# front of the ball (the window opens toward whichever camera draws). Pass --models=tripo for the
# Tripo bodies.
#   gamescope ... -- <godot> --audio-driver Dummy --path sketches/core-loop --resolution 1280x720 \
#     --ball-look=cutaway [--models=tripo] --script res://tools/tripo_pilot_shots.gd -- --out=<abs dir> --pilot=<class id>
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SIZE := Vector2i(1280, 720)

var out := ""
var pilot := "runner_gunner"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--pilot="):
			pilot = arg.trim_prefix("--pilot=")
	if out.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()

func _save(name: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("%s/%s-%s.png" % [out, pilot, name])

func _hide_ui(game) -> void:
	game.presentation.hide_ui()
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false

func _run() -> void:
	seed(280928)
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await process_frame
	await process_frame
	game.ctx.calm = true
	game.flow.press_start()
	var index := -1
	for i in game.flow.classes.size():
		if String(game.flow.classes[i].id) == pilot:
			index = i
	game.flow.choose_class(index)
	game.run.set_max_hp(999999.0)
	var hands := Intent.Scripted.new()
	game.player.source = hands
	for i in 900:
		await process_frame
		if game.ctx.terrain.is_ready(1) and game.flow.in_play() and i > 240:
			break
	_hide_ui(game)
	var players: Array = game.player.find_children("*", "AnimationPlayer", true, false)
	var anim: AnimationPlayer = null
	for p in players:
		if (p as AnimationPlayer).has_animation("big_cheer"):
			anim = p
	var skel: Array = game.player.find_children("*", "Skeleton3D", true, false)
	var scene_path := ""
	if not skel.is_empty():
		var n: Node = skel[0]
		while n != null and scene_path == "":
			scene_path = n.scene_file_path
			n = n.get_parent()
	print("SHOTS pilot=", pilot, " index=", index, " anim=", anim != null, " pilot_scene=", scene_path)
	for i in 30:
		await process_frame
	await _save("play_rest")
	# The big poses, held at the widest frame, from the play camera and from the front.
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	for clip in ["big_cheer", "heave"]:
		if anim == null or not anim.has_animation(clip):
			print("SHOTS no clip ", clip)
			continue
		var length := anim.get_animation(clip).length
		anim.play(clip)
		anim.seek(length * 0.45, true)
		anim.pause()
		for i in 3:
			await process_frame
		await _save(clip + "-play")
		var front := Camera3D.new()
		front.fov = 40.0
		root.add_child(front)
		var ball: Vector3 = game.player.ball_position()
		var fwd := -(skel[0] as Skeleton3D).global_basis.z.normalized() if not skel.is_empty() else Vector3.FORWARD
		fwd.y = 0.0
		fwd = fwd.normalized()
		front.global_position = ball + fwd * 6.0 + Vector3.UP * 1.4
		front.look_at(ball + Vector3.UP * 0.4, Vector3.UP)
		front.make_current()
		for i in 3:
			await process_frame
		await _save(clip + "-front")
		cam.make_current()
		front.queue_free()
		anim.play("idle_loop" if anim.has_animation("idle_loop") else "idle")
	for i in 20:
		await process_frame
	hands.hold = {"move": Vector2(0.0, 1.0)}
	for i in 120:
		await process_frame
	await _save("play_roll")
	print("SHOTS done ", pilot)
	quit(0)
