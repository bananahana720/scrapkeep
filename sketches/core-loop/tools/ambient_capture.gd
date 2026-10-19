extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const AmbientKinds := preload("res://src/core/ambient_kinds.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")

# Receipts for ambient life (AMBIENT-LIFE.md): a calm still, a react still and a short clip of one
# home's members, for every kind whose GLB exists in the park (or just --kind). Needs a rendered
# display; on a GPU-less box run it under xvfb:
#
#   xvfb-run -a -s "-screen 0 1280x720x24" $GODOT_BIN --rendering-driver opengl3 --fixed-fps 15 \
#     --path sketches/core-loop --script res://tools/ambient_capture.gd \
#     -- --out=<absolute dir> [--park=park_dam] [--kind=<id>] [--seconds=8]
#
# --fixed-fps 15 makes each rendered frame exactly one clip frame; without it the tool still saves a
# frame per 1/15 s of game time, so a slow renderer repeats frames instead of changing speed.
# The ball is frozen and carried by hand: 25 m from the home for the calm still and the first 2 s,
# then in to 5 m (the members flee), then a bare "telegraph" node over the group (the combat
# react), then removed; the clip ends 1 s after every member has hidden, or at --seconds. The camera is fixed 7 m from the group and follows its centre.
# Writes <out>/<park>_<kind>/{calm,react}.png, frame_####.png, ambient_<park>_<kind>.mp4 and .gif.

const FPS := 15.0
const SIZE := Vector2i(1280, 720)
const FAR_M := 25.0
const NEAR_M := 5.0
const CAM_M := 7.0
const SETTLE_S := 3.0
const GIF_MAX_BYTES := 3000000

var _out := ""
var _park := "park_dam"
var _kind := ""
var _seconds := 8.0
var _game
var _cam: Camera3D
var _fails := 0


func _initialize() -> void:
	var settings := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	if DisplayServer.get_name() == "headless" or not settings.has("out"):
		printerr("ambient_capture: needs a rendered display and -- --out=<absolute dir>")
		quit(2)
		return
	_out = settings["out"]
	_park = settings.get("park", "park_dam")
	_kind = settings.get("kind", "")
	_seconds = maxf(float(settings.get("seconds", "8")), 4.0)
	if not ParkSchema.MAP_STAGE.has(_park):
		printerr("ambient_capture: unknown park ", _park)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_main.call_deferred()


func _main() -> void:
	seed(280928)
	GraphicsPreset.apply("high")
	_game = Game.new()
	_game.name = "Game"
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await process_frame
	await process_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(999999.0)
	_game.player.source = Intent.Scripted.new()
	for i in 60:
		await process_frame
	var stage: int = ParkSchema.MAP_STAGE[_park]
	if stage != 1:
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
	var waited := 0
	var life = null
	while waited < 600:
		await process_frame
		waited += 1
		life = _game.presentation.ambient_life
		if _game.ctx.terrain.is_ready(stage) and life != null and life.pool != null and _game.flow.in_play():
			break
	life = _game.presentation.ambient_life
	if life == null or life.pool == null:
		printerr("ambient_capture: no AmbientLife pool for %s (life=%s ready=%s in_play=%s map=%s preset=%s)" % [_park, life != null,
			_game.ctx.terrain.is_ready(stage), _game.flow.in_play(), _game.ctx.stages.of(stage).map, GraphicsPreset.current])
		quit(1)
		return
	_cam = Camera3D.new()
	_cam.far = 1800.0
	_cam.near = 0.05
	_cam.fov = 28.0
	_game.add_child(_cam)
	_game.player.set_frozen(true)
	_game.presentation.hide_ui()
	var kinds := {}
	for m in life.pool.members:
		if not kinds.has(m.kind):
			kinds[m.kind] = m.home_index
	var todo: Array = []
	for k in kinds:
		if _kind.is_empty() or _kind == k:
			todo.append(k)
	if todo.is_empty():
		printerr("ambient_capture: no home of kind '%s' in %s (have %s)" % [_kind, _park, str(kinds.keys())])
		quit(1)
		return
	for k in todo:
		await _shoot(life, String(k), int(kinds[k]))
	quit(_fails)


func _gh(x: float, z: float) -> float:
	return _game.ctx.terrain.height(x, z)


func _ball(at: Vector3) -> void:
	_game.player.body().global_position = at
	_game.player.body().linear_velocity = Vector3.ZERO


# The ball spot 25 m from home with the ground nearest the home's height (not a drop or a wall).
func _far_spot(home: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for i in 24:
		var dir := Vector2.from_angle(TAU * i / 24.0)
		var p := home + dir * FAR_M
		var d := absf(_gh(p.x, p.y) - _gh(home.x, home.y))
		if d < best_d:
			best_d = d
			best = {"dir": dir, "d": d}
	return best


func _members(life, home_index: int) -> Array:
	return life.pool.members.filter(func(m): return m.home_index == home_index)


func _centre(list: Array, live_only := true) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for m in list:
		if m.live or not live_only:
			sum += m.pos
			n += 1
	return sum / n if n > 0 else Vector3.ZERO


func _frame(dir_out: String, name: String) -> void:
	get_root().get_viewport().get_texture().get_image().save_png(dir_out.path_join(name))


func _shoot(life, kind: String, home_index: int) -> void:
	var list := _members(life, home_index)
	var home: Vector2 = list[0].home
	var tag := "%s_%s" % [_park, kind]
	var dir_out := _out.path_join(tag)
	DirAccess.make_dir_recursive_absolute(dir_out)
	for f in DirAccess.get_files_at(dir_out):
		if f.ends_with(".png"):
			DirAccess.remove_absolute(dir_out.path_join(f))
	life.pool.reset()
	var far := _far_spot(home)
	var dir: Vector2 = far["dir"]
	var side := Vector2(-dir.y, dir.x)
	var ball_at := func(dist: float) -> Vector3:
		var p := home + dir * dist
		return Vector3(p.x, _gh(p.x, p.y) + 0.6, p.y)
	_ball(ball_at.call(FAR_M))
	var follow := Vector3(home.x, _gh(home.x, home.y), home.y)
	var cam_offset := Vector3(side.x * CAM_M, 2.2, side.y * CAM_M)
	var states_log: Array = []
	var clock := 0.0
	var frames := 0
	var acc := 0.0
	var telegraph: Node3D = null
	var react_saved := false
	var t_far := 2.0
	var t_in := 1.2
	var t_tele := t_far + t_in
	var t_tele_end := minf(t_tele + 3.0, _seconds - 1.0)
	var total := SETTLE_S + _seconds
	var hidden_for := 0.0
	while clock < total:
		await process_frame
		var dt: float = _game.get_process_delta_time()
		clock += dt
		var t := clock - SETTLE_S
		# Ball: far until t_far, then in to NEAR_M over t_in, held there.
		if t < t_far:
			_ball(ball_at.call(FAR_M))
		else:
			_ball(ball_at.call(lerpf(FAR_M, NEAR_M, clampf((t - t_far) / t_in, 0.0, 1.0))))
		if t >= t_tele and t < t_tele_end and telegraph == null:
			telegraph = _telegraph(Vector3(follow.x, follow.y, follow.z))
		elif t >= t_tele_end and telegraph != null:
			telegraph.queue_free()
			telegraph = null
		var c := _centre(list)
		if c != Vector3.ZERO:
			follow = follow.lerp(c, clampf(dt * 10.0, 0.0, 1.0))
		_cam.global_position = follow + cam_offset
		_cam.look_at(follow + Vector3(0, 0.4, 0), Vector3.UP)
		_cam.current = true
		if telegraph != null:
			telegraph.set("center", Vector3(follow.x, _gh(follow.x, follow.z), follow.z))
		if clock >= SETTLE_S and not _has_calm(dir_out):
			_frame(dir_out, "calm.png")
		if clock < SETTLE_S:
			continue
		if list.all(func(m): return m.state == "hidden" or not m.live):
			hidden_for += dt
			if hidden_for > 1.0:
				break
		acc += dt
		if acc >= 1.0 / FPS - 0.0001:
			acc -= 1.0 / FPS
			if t >= t_tele + 0.2 and not react_saved:
				react_saved = true
				_frame(dir_out, "react.png")
			_frame(dir_out, "frame_%04d.png" % frames)
			frames += 1
			if frames % 15 == 1:
				states_log.append("%.1fs[%s]" % [t, _states(list)])
	if telegraph != null:
		telegraph.queue_free()
	var mp4 := _out.path_join("ambient_%s.mp4" % tag)
	var gif := _out.path_join("ambient_%s.gif" % tag)
	var enc := _encode(dir_out, mp4, gif)
	var live := list.filter(func(m): return m.live).size()
	print("ambient_capture: %s home=%d members=%d live=%d frames=%d far_ground_dy=%.1f states=%s mp4=%s gif=%s %s" % [
		tag, home_index, list.size(), live, frames, far["d"], " ".join(states_log), mp4, gif, enc])
	if frames == 0 or not FileAccess.file_exists(dir_out.path_join("calm.png")):
		_fails += 1


func _has_calm(dir_out: String) -> bool:
	return FileAccess.file_exists(dir_out.path_join("calm.png"))


func _states(list: Array) -> String:
	var parts: Array = []
	for m in list:
		parts.append("%s%s:%s/%s" % ["" if m.live else "-", m.id, m.state, m.loop])
	return ",".join(parts)


# A bare node in group "telegraph" with `center`, which ambient_life.gd reads, and the fields set_dressing.gd
# reads to clear clutter from a hostile telegraph.
func _telegraph(at: Vector3) -> Node3D:
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar center := Vector3.ZERO\nvar shape := 0\nvar radius := 6.0\nvar length := 0.0\nvar width := 0.0\nfunc is_hostile() -> bool:\n\treturn true\n"
	script.reload()
	var node := Node3D.new()
	node.set_script(script)
	node.name = "AmbientCaptureTelegraph"
	node.add_to_group("telegraph")
	_game.add_child(node)
	node.global_position = at
	node.set("center", at)
	return node


func _encode(dir_out: String, mp4: String, gif: String) -> String:
	var log: Array = []
	var rc := OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-framerate", "15", "-i", dir_out.path_join("frame_%04d.png"),
		"-pix_fmt", "yuv420p", "-vf", "scale=1280:-2", mp4], log, true)
	var result := "mp4_rc=%d" % rc
	for width in [480, 400, 320, 240]:
		var filter := "fps=12,scale=%d:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" % width
		rc = OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-framerate", "15", "-i", dir_out.path_join("frame_%04d.png"),
			"-filter_complex", filter, gif], log, true)
		var size := FileAccess.open(gif, FileAccess.READ).get_length() if FileAccess.file_exists(gif) else -1
		result += " gif_rc=%d gif_w=%d gif_bytes=%d" % [rc, width, size]
		if rc == 0 and size <= GIF_MAX_BYTES:
			break
	return result
