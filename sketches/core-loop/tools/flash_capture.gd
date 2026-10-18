extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")

# Rendered stills for the Reduce flashes toggle (design question 7): each flash site at its
# peak with the toggle off and on, each beside a rest still taken the frame before, so
# still_compare's --peak mode can measure the brightness the flash adds. Sites: the hit edge
# flash, a pop glyph (the shot and detonation flash), a reach ring glyph, an enemy hit flash,
# a comic sound word and the reward crate burst. It needs a rendered display; in the cloud:
#
#   xvfb-run -a -s "-screen 0 1920x1080x24" <godot> --rendering-driver opengl3 \
#     --path sketches/core-loop --script res://tools/flash_capture.gd -- --out=<absolute dir>
#
# then, per site and mode:
#   <godot> --headless --path sketches/core-loop --script res://tools/still_compare.gd -- \
#     --peak <out>/<site>-<mode>-rest.png <out>/<site>-<mode>-peak.png
#
# The run is calm (no director spawns) and the tree is paused across each rest and peak pair,
# so the two stills differ only by the flash.

const SITES := ["edge", "pop_glyph", "ring_glyph", "enemy_hit", "word"]
const SETTLE_FRAMES := 10

var _out := ""
var _game
var _frame := 0
var _queue: Array = []
var _enemy
var _shots: Array = []
var _burst_mode := ""
var _clock := 0.0


func _initialize() -> void:
	var settings := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	if DisplayServer.get_name() == "headless" or not settings.has("out"):
		printerr("flash_capture: needs a rendered display and -- --out=<absolute dir>")
		quit(2)
		return
	_out = settings["out"]
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(delta: float) -> bool:
	_frame += 1
	_clock += delta
	if _game == null or _game.flow == null:
		return false
	if _frame == 30:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
	elif _frame == 120:
		_plan()
	while not _queue.is_empty() and _queue[0]["frame"] <= _frame:
		(_queue.pop_front()["do"] as Callable).call()
	return false


func _at(frames: int, action: Callable) -> void:
	var last: int = _queue[-1]["frame"] if not _queue.is_empty() else _frame
	_queue.append({"frame": last + frames, "do": action})


func _plan() -> void:
	_enemy = _game.ctx.spawner.spawn_enemy("chaser", _ahead(6.0))
	_enemy.process_mode = Node.PROCESS_MODE_DISABLED
	for mode in ["off", "on"]:
		_at(1, func(): _game.set_reduce_flashes(mode == "on"))
		for site in SITES:
			_at(SETTLE_FRAMES, func():
				paused = true
				_place(site))
			_at(2, func(): _save("%s-%s-rest" % [site, mode]))
			_at(1, func(): _fire(site))
			_at(2, func(): _save("%s-%s-peak" % [site, mode]))
			_at(1, func():
				_calm(site)
				paused = false)
	_at(SETTLE_FRAMES, func(): _burst("off", "ram_plow"))


func _ahead(metres: float) -> Vector3:
	var ball: Vector3 = _game.player.ball_position()
	var cam: Camera3D = _game.camera.cam
	var ahead := -cam.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() * metres
	return _game.ctx.terrain.drop_point(ball.x + ahead.x, ball.z + ahead.z, 1.0)


# The enemy stands where the camera looks now, since the ball may have rolled.
func _place(site: String) -> void:
	if site == "enemy_hit":
		_enemy.global_position = _ahead(6.0)


func _fire(site: String) -> void:
	var vfx = _game.presentation.vfx
	match site:
		"edge":
			vfx.edge.flash(Vector2.ZERO, Color(1.0, 0.25, 0.2), 0.65, 0.4)
		"pop_glyph":
			vfx.glyph("sticky_detonated", _ahead(5.0) + Vector3.UP * 1.0, 3.0, 3.0, 2.0, Vector3.ZERO, "flash")
		"ring_glyph":
			vfx.glyph("slammed", _ahead(5.0) + Vector3.UP * 0.2, 4.0, 4.0, 2.0, Vector3.UP, "ring")
		"enemy_hit":
			_enemy.flash()
			_enemy._update_flash(0.0)
		"word":
			_game.presentation.machine_fx.word("KLANG", _ahead(5.0) + Vector3.UP * 2.0, Color(1.0, 0.85, 0.4), true, 2.0)


func _calm(site: String) -> void:
	if site == "enemy_hit":
		_enemy._flash = 0.001
		_enemy._update_flash(1.0)


# The crate burst only plays in a paused ceremony; the rest still is the frame it reveals,
# before the burst draws, and the peak is 0.08 s into the burst.
func _burst(mode: String, part: String) -> void:
	_game.set_reduce_flashes(mode == "on")
	_burst_mode = mode
	var ceremony = _game.presentation.ceremony
	ceremony.pause_armed = true
	if not ceremony.revealed.is_connected(_on_revealed):
		ceremony.revealed.connect(_on_revealed)
		ceremony.closed.connect(_on_closed)
	_game.run.add_part(part, "vault")


func _on_revealed(_part: String) -> void:
	_save("burst-%s-rest" % _burst_mode)
	var start := _clock
	_queue.append({"frame": _frame, "do": func(): _wait_burst(start)})


func _wait_burst(start: float) -> void:
	if _clock - start >= 0.08:
		_save("burst-%s-peak" % _burst_mode)
		return
	_queue.push_front({"frame": _frame + 1, "do": func(): _wait_burst(start)})


func _on_closed(_part: String) -> void:
	if _burst_mode == "off":
		_queue.append({"frame": _frame + SETTLE_FRAMES, "do": func(): _burst("on", "chain_arc")})
	else:
		_queue.append({"frame": _frame + 5, "do": _finish})


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(_out.path_join(name + ".png"))
	_shots.append({"file": name + ".png", "frame": _frame, "guard": FlashGuard.on})


func _finish() -> void:
	var info := {"adapter": RenderingServer.get_video_adapter_name(), "shots": _shots}
	var file := FileAccess.open(_out.path_join("capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info, "  "))
		file.close()
	print("flash_capture: %d stills in %s" % [_shots.size(), _out])
	quit(0)
