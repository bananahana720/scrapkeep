extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const FlashGuard := preload("res://src/core/flash_guard.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const AppShell := preload("res://src/core/app_shell.gd")


const SITES := ["edge", "pop_glyph", "ring_glyph", "enemy_hit", "word"]
const SETTLE_FRAMES := 10
const FLASH_LINE := 3.0
const FLASH_DELTA := 0.05
const GRID := Vector2i(4, 3)
const SAMPLE_STEP := 6
const FLOOR_SECONDS := 2.0
const CLIP_SECONDS := 5.0
const VOLLEYS := [2.0, 2.5]
const LANDED := 1.6
const HOLD_FRAMES := 120
const PLANT_HZ := 5.0
const KEEP_EVERY := 0.25

var _out := ""
var _game
var _frame := 0
var _queue: Array = []
var _enemy
var _shots: Array = []
var _burst_mode := ""
var _clock := 0.0
var _clip := false
var _plant := ""
var _clip_t0 := -1.0
var _landed := 0
var _hold := 0
var _clip_armed := false
var _volleys_left: Array = []
var _times := PackedFloat32Array()
var _series: Array = []
var _next_keep := 0.0
var _blinker: ColorRect
var _lin: PackedFloat32Array = _linear_table()


func _initialize() -> void:
	var settings := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	if AppShell.headless() or not settings.has("out"):
		printerr("flash_capture: needs a rendered display and -- --out=<absolute dir>")
		quit(2)
		return
	_out = settings["out"]
	_clip = settings.get("clip", "") == "1"
	_plant = settings.get("plant", "")
	if _plant != "" and not _clip:
		printerr("flash_capture: --plant needs --clip=1")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	if settings.get("guard", "") == "on":
		_game.set_reduce_flashes(true)


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
		if _clip:
			_clip_armed = true
		else:
			_plan()
	if _clip_armed:
		_clip_wait()
	if _clip_t0 >= 0.0:
		_clip_step()
		return false
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


func _clip_wait() -> void:
	var p: Vector3 = _game.player.ball_position()
	var ground = _game.ctx.spawner.ground
	if _hold == 0:
		_landed = _landed + 1 if p.y - Telegraph.ground_under(ground, p) < LANDED else 0
		if _landed >= 30:
			_game.player.body().freeze = true
			_hold = 1
	else:
		_hold += 1
		if _hold >= HOLD_FRAMES:
			_clip_armed = false
			_clip_begin()


func _clip_begin() -> void:
	_enemy = _game.ctx.spawner.spawn_enemy("chaser", _ahead(6.0))
	_enemy.process_mode = Node.PROCESS_MODE_DISABLED
	_clip_t0 = _clock
	_volleys_left = VOLLEYS.duplicate()
	if _plant == "blink":
		var layer := CanvasLayer.new()
		layer.layer = 100
		root.add_child(layer)
		_blinker = ColorRect.new()
		_blinker.color = Color.WHITE
		var view := root.get_visible_rect().size
		_blinker.position = Vector2(view.x * 0.25, view.y / 3.0)
		_blinker.size = Vector2(view.x / GRID.x, view.y / GRID.y)
		layer.add_child(_blinker)


func _clip_step() -> void:
	var t := _clock - _clip_t0
	while not _volleys_left.is_empty() and t >= _volleys_left[0]:
		_volleys_left.pop_front()
		for site in SITES:
			_fire(site)
	if _blinker != null:
		_blinker.visible = t >= FLOOR_SECONDS and int(floor((t - FLOOR_SECONDS) * PLANT_HZ * 2.0)) % 2 == 0
	var image := root.get_texture().get_image()
	_times.append(t)
	_series.append(region_means(image, GRID, SAMPLE_STEP, _lin))
	if t >= _next_keep:
		_next_keep += KEEP_EVERY
		_save("clip-%04.2f" % t)
	if t >= CLIP_SECONDS:
		_clip_finish()


func _clip_finish() -> void:
	_clip_t0 = -1.0
	var floor_rows := _score(0.0, FLOOR_SECONDS)
	var busy_rows := _score(FLOOR_SECONDS, CLIP_SECONDS + 1.0)
	var worst := 0.0
	var worst_region := -1
	for row in busy_rows:
		if row["flashes_per_second"] > worst:
			worst = row["flashes_per_second"]
			worst_region = row["region"]
	var floor_worst := 0.0
	for row in floor_rows:
		floor_worst = maxf(floor_worst, row["flashes_per_second"])
	var fps := float(_times.size()) / maxf(0.001, _times[_times.size() - 1]) if _times.size() > 0 else 0.0
	var pass_clip := _times.size() >= 60 and worst <= FLASH_LINE
	var head: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], head)
	var info := {"tool": "flash_capture.gd", "mode": "clip", "head": String(head[0]).strip_edges() if head.size() > 0 else "", "plant": _plant, "line": FLASH_LINE, "delta": FLASH_DELTA,
		"grid": [GRID.x, GRID.y], "sites": SITES, "volleys_at_s": VOLLEYS, "floor_seconds": FLOOR_SECONDS, "guard": FlashGuard.on,
		"frame_count": _times.size(), "frames_per_second": snappedf(fps, 0.1),
		"floor_worst_flashes_per_second": floor_worst, "worst_flashes_per_second": worst, "worst_region": worst_region,
		"verdict": "pass" if pass_clip else "fail", "busy_regions": busy_rows, "floor_regions": floor_rows,
		"adapter": RenderingServer.get_video_adapter_name(), "shots": _shots}
	var file := FileAccess.open(_out.path_join("frames.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info, "\t"))
		file.close()
	print("flash_capture clip: plant=%s frames=%d fps=%.1f floor=%.1f/s busy worst=%.1f/s in region %d line=%.1f -> %s" % [_plant, _times.size(), fps, floor_worst, worst, worst_region, FLASH_LINE, info["verdict"]])
	quit(0 if pass_clip else 1)


func _score(from: float, to: float) -> Array:
	var rows := []
	for r in GRID.x * GRID.y:
		var times := PackedFloat32Array()
		var luma := PackedFloat32Array()
		for i in _times.size():
			if _times[i] >= from and _times[i] < to:
				times.append(_times[i])
				luma.append((_series[i] as PackedFloat32Array)[r])
		rows.append({"region": r, "flashes_per_second": flashes_per_second(times, luma, FLASH_DELTA), "frames": luma.size(),
			"luminance_max": snappedf(_max_of(luma), 0.001), "luminance_min": snappedf(_min_of(luma), 0.001)})
	return rows


static func _max_of(values: PackedFloat32Array) -> float:
	var best := -INF
	for v in values:
		best = maxf(best, v)
	return best


static func _min_of(values: PackedFloat32Array) -> float:
	var best := INF
	for v in values:
		best = minf(best, v)
	return best


static func _linear_table() -> PackedFloat32Array:
	var table := PackedFloat32Array()
	table.resize(256)
	for i in 256:
		var c := i / 255.0
		table[i] = c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)
	return table


static func region_means(image: Image, grid: Vector2i, step: int, lin: PackedFloat32Array) -> PackedFloat32Array:
	var width := image.get_width()
	var height := image.get_height()
	var bytes := 4 if image.get_format() == Image.FORMAT_RGBA8 else 3
	var data := image.get_data()
	var sums := PackedFloat32Array()
	var counts := PackedInt32Array()
	sums.resize(grid.x * grid.y)
	counts.resize(grid.x * grid.y)
	for y in range(0, height, step):
		var row := mini(y * grid.y / height, grid.y - 1) * grid.x
		for x in range(0, width, step):
			var k := (y * width + x) * bytes
			var cell := row + mini(x * grid.x / width, grid.x - 1)
			sums[cell] += 0.2126 * lin[data[k]] + 0.7152 * lin[data[k + 1]] + 0.0722 * lin[data[k + 2]]
			counts[cell] += 1
	for i in sums.size():
		sums[i] = sums[i] / maxi(1, counts[i])
	return sums


static func flashes_per_second(times: PackedFloat32Array, luma: PackedFloat32Array, delta: float) -> float:
	var rises: Array = []
	if luma.size() == 0 or luma.size() != times.size():
		return -1.0
	var low := luma[0]
	var high := luma[0]
	var rising := false
	var rise_at := times[0]
	for i in luma.size():
		var v := luma[i]
		if rising:
			if v > high:
				high = v
			elif high - v >= delta:
				rises.append(rise_at)
				rising = false
				low = v
				rise_at = times[i]
		else:
			if v < low:
				low = v
				rise_at = times[i]
			elif v - low >= delta:
				rising = true
				high = v
	var best := 0
	for i in rises.size():
		var n := 0
		for j in range(i, rises.size()):
			if rises[j] - rises[i] < 0.9999:
				n += 1
		best = maxi(best, n)
	return float(best)
