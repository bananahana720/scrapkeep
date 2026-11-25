extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EnemyClips := preload("res://src/presentation/enemy_clips.gd")


const SIZE := Vector2i(640, 480)
const KINDS := ["chaser", "lobber", "mag_trapper", "plated_brute", "winch_drone", "jolt_layer"]
const SHOTS := [[null, 0.0, "rest"], ["idle", 0.67, "idle"], ["move", 0.25, "move"], ["windup", 0.5, "windup_half"],
	["windup", 1.0, "windup_release"], ["attack", 0.08, "attack"], ["hit", 0.12, "hit"], ["death", 1.0, "death"]]
const DISTANCE := {"chaser": 6.5, "lobber": 9.0, "mag_trapper": 8.5, "plated_brute": 7.0, "winch_drone": 8.0, "jolt_layer": 7.5}

var game
var out := ""
var kinds: Array = KINDS
var camera: Camera3D
var records := []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--kinds="):
			kinds = Array(arg.trim_prefix("--kinds=").split(","))
	if out.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _run() -> void:
	seed(280928)
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	for i in 60:
		await physics_frame
	for node in root.find_children("*", "CanvasLayer", true, false):
		node.visible = false
	camera = Camera3D.new()
	game.add_child(camera)
	camera.current = true
	camera.fov = 40.0
	var terrain = game.ctx.terrain
	var dam_apron: bool = terrain.map().title == "park_dam"
	var base: Vector3 = terrain.drop_point(-65.0, -130.0, 0.0)
	game.player.reset_to(base + Vector3(0, 0, -60))
	game.player.visible = false
	var at: Vector3 = terrain.drop_point(10.0, 540.0, 1.2) if dam_apron else terrain.drop_point(base.x + 30.0, base.z + 25.0, 1.2)
	var centre: Vector3 = at + Vector3.UP * (1.6 if dam_apron else 0.6)
	for kind in kinds:
		var enemy = game.ctx.spawner.spawn_enemy(kind, at)
		for f in 4:
			await physics_frame
		paused = true
		enemy.global_position = at
		enemy.rotation.y = 0.0
		var driver = enemy._clips
		if driver == null:
			printerr("enemy_clip_capture: %s has no clips seated" % kind)
			quit(3)
			return
		enemy.reaction_pivot.transform = Transform3D.IDENTITY
		var d := float(DISTANCE.get(kind, 8.0)) * (1.55 if dam_apron else 1.0)
		camera.look_at_from_position(centre + Vector3(-0.62, 0.32, -0.72).normalized() * d, centre)
		for i in SHOTS.size():
			var shot: Array = SHOTS[i]
			var seconds := 0.0
			if shot[0] == null:
				driver._sample("", 0.0, 1.0)
			else:
				seconds = float(shot[1]) * float(driver.lib.anims[shot[0]].length)
				driver._blend_left = 0.0
				driver._sample(String(shot[0]), seconds, 1.0)
			for f in 6:
				await RenderingServer.frame_post_draw
			var file := "%s_%02d_%s.png" % [kind, i, shot[2]]
			if root.get_texture().get_image().save_png(out.path_join(file)) != OK:
				quit(3)
				return
			records.append({"file": file, "kind": kind, "clip": "rest" if shot[0] == null else shot[0], "t": snappedf(seconds, 0.001), "label": shot[2]})
		enemy.queue_free()
		paused = false
		for f in 2:
			await physics_frame
	var json := FileAccess.open(out.path_join("shots.json"), FileAccess.WRITE)
	json.store_string(JSON.stringify({"size": [SIZE.x, SIZE.y], "shots": records}, "\t"))
	quit()
