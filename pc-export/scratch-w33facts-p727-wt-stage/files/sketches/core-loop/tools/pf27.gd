extends "res://tools/bot_run.gd"
# Scratch (p727, untracked, never committed): PF-27 attack cages on the real renderer and chase camera.
# A bot run warms up on stage 1 of the park table (park_dam) in play; then a pack is staged round the
# ball and kept topped up while the bot keeps driving, health held. 20 s at 90 ticks/s; every third tick
# the frame is saved with the telegraphs drawn, then the tree is paused for a moment, every telegraph
# (groups "telegraph" and "threat") hidden, and the same frame saved again; every tenth sample a second
# hidden frame is the noise floor. Coverage is measured offline (box A = Rect2i(480,0,960,ball_top)).
#   -- --shots=<abs dir> [--warm=20] [--seconds=20] [--still=1: the bot stops driving once the pack is staged] [bot_run flags]

const Palette := preload("res://src/core/palette.gd")

var _sg: Dictionary = {}
var _sg_state := "warm"
var _sg_dir := ""
var _sg_started := false
var _hold := false


func _initialize() -> void:
	_sg = _parse(OS.get_cmdline_user_args())
	_sg_dir = String(_sg.get("shots", ""))
	if DisplayServer.get_name() == "headless" or _sg_dir == "":
		printerr("pf27: needs a rendered display and --shots=<abs dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_sg_dir)
	super._initialize()


func _physics_process(delta: float) -> bool:
	if _sg_state == "warm":
		var over: bool = super._physics_process(delta)
		if not over and _game != null and _driver != null and _game.flow != null and _game.flow.in_play() \
				and _game.run.stage_time > float(_sg.get("warm", "20")) and not _sg_started:
			_sg_started = true
			_sg_state = "go"
			_go.call_deferred()
		return over
	if _game != null and _game.run != null:
		_game.run.hp = _game.run.max_hp
	if _hold or paused:
		return false
	if _sg.get("still", "0") == "1" and _sg_state == "go" and _driver != null:
		_driver.source.hold = {}
		_driver.source.press = {}
		return false
	return super._physics_process(delta)


func _marks() -> Array:
	var seen := {}
	var out: Array = []
	for g in ["telegraph", "threat"]:
		for n in get_nodes_in_group(g):
			if n is Node3D and n.is_inside_tree() and not seen.has(n.get_instance_id()):
				seen[n.get_instance_id()] = true
				out.append(n)
	return out


func _enemies_near(r: float) -> int:
	var b: Vector3 = _game.player.ball_position()
	var n := 0
	for e in get_nodes_in_group("enemy"):
		if e is Node3D and e.is_inside_tree() and (e as Node3D).global_position.distance_to(b) < r:
			n += 1
	return n


func _spawn_ring() -> void:
	var ball: Vector3 = _game.player.ball_position()
	var fwd: Vector3 = _game.ctx.heading()
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var kinds := ["chaser", "lobber", "chaser", "lobber", "plated_brute", "chaser", "lobber"]
	for i in kinds.size():
		var ang := TAU * float(i) / kinds.size() + 0.3
		var d := 11.0 + 3.0 * float(i % 3)
		var p: Vector3 = ball + fwd.rotated(Vector3.UP, ang) * d
		var at: Vector3 = _game.ctx.terrain.drop_point(p.x, p.z, 2.4)
		var e = _game.ctx.spawner.spawn_enemy(String(kinds[i]), at, "")
		print("pf27: spawned ", kinds[i], " at ", at, " -> ", e)


func _ball_top() -> float:
	var cam := root.get_camera_3d()
	var b: Vector3 = _game.player.shown_position()
	return cam.unproject_position(b + cam.global_basis.y * 1.0).y


func _go() -> void:
	print("pf27: VIEWPORT window=", root.size, " visible_rect=", root.get_visible_rect().size, " texture=", root.get_texture().get_size(), " adapter=", RenderingServer.get_video_adapter_name())
	print("pf27: control taken stage=", _game.run.stage, " map=", String(_game.ctx.stages.of(_game.run.stage).get("map", "")), " ball=", _game.player.ball_position())
	_game.ctx.calm = false
	_game.run.set_max_hp(999999.0)
	_spawn_ring()
	for i in 240:
		await RenderingServer.frame_post_draw
	var drawn := _sg_dir.path_join("drawn")
	var hidden := _sg_dir.path_join("hidden")
	var noise := _sg_dir.path_join("noise")
	for d in [drawn, hidden, noise]:
		DirAccess.make_dir_recursive_absolute(d)
	var tr := FileAccess.open(_sg_dir.path_join("trace.tsv"), FileAccess.WRITE)
	tr.store_line("frame\ttick_i\tstage_time\tmarks_live\tmarks_within_25m\tmarks_on_screen\tenemies_within_40m\tball_px_x\tball_px_y\tball_top_px\tball_speed")
	var ticks := int(float(_sg.get("seconds", "20")) * 90.0)
	var n := 0
	for i in ticks:
		var refill_every := 90 if _sg.get("still", "0") == "1" else 180
		var keep := 8 if _sg.get("still", "0") == "1" else 5
		if i % refill_every == 0 and _enemies_near(40.0) < keep:
			_spawn_ring()
		await RenderingServer.frame_post_draw
		if i % 3 != 0:
			continue
		# The drawn frame is the one just shown; freeze the world, hide the marks, show the same moment again.
		var img := root.get_texture().get_image()
		_hold = true
		paused = true
		var cam := root.get_camera_3d()
		var ball: Vector3 = _game.player.ball_position()
		var bp := cam.unproject_position(_game.player.shown_position())
		var marks := _marks()
		var near := 0
		var onscreen := 0
		for m in marks:
			if (m as Node3D).global_position.distance_to(ball) < 25.0:
				near += 1
			if not cam.is_position_behind(m.global_position):
				var sp := cam.unproject_position(m.global_position)
				if Rect2(0, 0, 1920, 1080).has_point(sp):
					onscreen += 1
		var vis := []
		for m in marks:
			vis.append([m, m.visible])
			m.visible = false
		await RenderingServer.frame_post_draw
		var himg := root.get_texture().get_image()
		var nimg: Image = null
		if n % 10 == 0:
			await RenderingServer.frame_post_draw
			nimg = root.get_texture().get_image()
		for pair in vis:
			if is_instance_valid(pair[0]):
				pair[0].visible = pair[1]
		paused = false
		_hold = false
		img.save_png(drawn.path_join("f%04d.png" % n))
		himg.save_png(hidden.path_join("f%04d.png" % n))
		if nimg != null:
			nimg.save_png(noise.path_join("f%04d.png" % n))
		tr.store_line("%d\t%d\t%.2f\t%d\t%d\t%d\t%d\t%.0f\t%.0f\t%.0f\t%.1f" % [n, i, _game.run.stage_time, marks.size(), near, onscreen, _enemies_near(40.0), bp.x, bp.y, _ball_top(), _game.player.planar_velocity().length()])
		n += 1
	tr.close()
	print("pf27: frames ", n)
	print("pf27: done")
	quit(0)
