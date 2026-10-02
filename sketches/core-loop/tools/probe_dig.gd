extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")

# Unit P1 probe harness (throwaway): measures the Dig terrain probe (map_dig_probe.gd) on
# --table=probe. One mode per run, one frame one physics tick:
#
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/probe_dig.gd \
#     -- --mode=break|speed|drops|camera [--out=<json>] [--table=probe]
#
#   break   P1-1: slams over the plate from heights and from real hops; strength and result
#   speed   P1-2: slam through the breach at several planar speeds; planar speed kept after landing
#   drops   P1-4: 200 drops through the broken breach at varied speeds, heights and lines
#   camera  P1-3: the scripted run (deck, jump, slam, gallery, tunnel, ramp) with a per-tick
#           occlusion test of the ball's disc from the camera

const PLATE := Vector3(0.0, 14.0, -40.0)
const FLOOR_Y := 0.0
const HEADING := Vector3(0.0, 0.0, 1.0)

var _game
var _source := Intent.Scripted.new()
var _mode := "break"
var _out := ""
var _table := "probe"
var _phase := "boot"
var _wait := 0
var _plate
var _trials: Array = []
var _trial := {}
var _t := 0
var _results: Array = []
var _trace: Array = []
var _occ_rows: Array = []
var _cam_state := {}
# Native runs only (not --headless): --shots=<ticks> --shotdir=<dir> save 1920x1080 stills of the scripted run.
var _shots: Array = []
var _shotdir := ""
var _native := false
var _gpu: Array[float] = []
var _cpu: Array[float] = []
var _wall: Array[float] = []
var _last_us := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		if arg.begins_with("--table="):
			_table = arg.trim_prefix("--table=")
	_native = DisplayServer.get_name() != "headless"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			for part in arg.trim_prefix("--shots=").split(",", false):
				_shots.append(int(part))
		if arg.begins_with("--shotdir="):
			_shotdir = arg.trim_prefix("--shotdir=")
	if _native:
		root.size = Vector2i(1920, 1080)
		root.content_scale_size = Vector2i(1920, 1080)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		OS.low_processor_usage_mode = false
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_game = Game.new()
	_game.test_mode = true
	_game.table = _table
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = _source
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_phase = "settle"
			_wait = 0
		"settle":
			if _wait == 120:
				_plate = _find_plate(_game)
				if _plate == null:
					printerr("probe_dig: no BreachPlate on table %s" % _table)
					quit(2)
					return true
				_build_trials()
				_next_trial()
		"trial":
			_step_trial()
		"gap":
			_wait_gap()
	return false


static func _find_plate(n: Node):
	if n.name == "BreachPlate":
		return n
	for c in n.get_children():
		var f = _find_plate(c)
		if f != null:
			return f
	return null


# ---- trials ----

func _build_trials() -> void:
	match _mode:
		"break":
			# Airborne slams straight down onto the plate from set heights above its top.
			for h in [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 6.0, 8.0, 12.0]:
				_trials.append({"kind": "air", "h": h, "speed": 0.0, "dz": 0.0, "label": "air h=%.1f v=0" % h})
			# Real hops: roll at 20 m/s along x=0, jump `lead` m before the plate centre, slam at the apex or after a delay.
			for sp in [12.0, 20.0, 30.0]:
				for lead in [8.0, 12.0, 16.0]:
					for at in [-4.0, -2.5, -1.0]:
						_trials.append({"kind": "hop", "lead": lead, "at": at, "speed": sp, "label": "hop v=%.0f lead=%.0f slam_at_z=%+.1f" % [sp, lead, at]})
		"speed":
			for sp in [10.0, 16.0, 22.0, 30.0]:
				for h in [4.0, 8.0]:
					_trials.append({"kind": "air", "h": h, "speed": sp, "dz": -sp * _fall_time(h), "label": "through v=%.0f h=%.0f" % [sp, h], "follow": 4.0})
				_trials.append({"kind": "ctl", "speed": sp, "label": "control: roll on the gallery floor v=%.0f" % sp})
		"drops":
			var rng := RandomNumberGenerator.new()
			rng.seed = 20261002
			for i in 200:
				var sp := rng.randf_range(0.0, 30.0)
				var h := rng.randf_range(3.0, 10.0)
				var yaw := rng.randf_range(-0.25, 0.25)
				var dx := rng.randf_range(-1.0, 1.0)
				var dz := -sp * _fall_time(h) * cos(yaw) - 1.5
				_trials.append({"kind": "air", "h": h, "speed": sp, "dz": dz, "dx": dx - sp * _fall_time(h) * sin(yaw), "yaw": yaw, "label": "drop %d" % i, "follow": 1.5, "slam": true})
		"camera":
			_trials.append({"kind": "run", "label": "scripted run"})


# Seconds a ball starting h above the plate's top takes to fall to 1.5 m above it under a slam
# (168 m/s^2 to 42 m/s, augments.gd), so a run can start that far upstream and break at the centre.
static func _fall_time(h: float) -> float:
	var d := maxf(0.2, h - 1.5)
	var ramp_d := 0.5 * 168.0 * 0.25 * 0.25
	if d <= ramp_d:
		return sqrt(2.0 * d / 168.0)
	return 0.25 + (d - ramp_d) / 42.0


func _next_trial() -> void:
	if _trials.is_empty():
		_finish()
		return
	_trial = _trials.pop_front()
	_plate.restore()
	_phase = "gap"
	_wait = 0


func _wait_gap() -> void:
	if _wait < 6:
		return
	_start_trial()


func _ball() -> RigidBody3D:
	return _game.player.body()


func _place(pos: Vector3, vel: Vector3) -> void:
	_game.player.reset_to(pos, vel)
	_ball().global_position = pos
	var flat := Vector3(vel.x, 0.0, vel.z)
	var heading := flat.normalized() if flat.length() > 0.5 else HEADING
	_game.camera.snap(heading)
	_source.hold = {}
	_source.press = {}


func _start_trial() -> void:
	_t = 0
	_trace = []
	_occ_rows = []
	_trial["broke_t"] = -1
	_trial["landed_t"] = -1
	var kind: String = _trial["kind"]
	match kind:
		"air":
			var sp: float = _trial["speed"]
			var yaw: float = _trial.get("yaw", 0.0)
			var dir := Vector3(sin(yaw), 0.0, cos(yaw))
			var pos := PLATE + Vector3(_trial.get("dx", 0.0), float(_trial["h"]) + 1.0, 0.0) + Vector3(0.0, 0.0, _trial.get("dz", 0.0))
			_place(pos, dir * sp)
			_trial["limit"] = int(90.0 * (3.0 + float(_trial.get("follow", 1.5))))
		"ctl":
			_place(Vector3(0.0, 1.0, -30.0), Vector3(0.0, 0.0, float(_trial["speed"])))
			_trial["limit"] = 90
		"hop":
			var sp: float = _trial["speed"]
			var pos := Vector3(0.0, 15.2, PLATE.z - float(_trial["lead"]) - 20.0)
			_trial["jumped"] = false
			_trial["slam_from"] = -1
			_place(pos, Vector3(0.0, 0.0, sp))
			_trial["limit"] = int(90.0 * 6.0)
		"run":
			_start_run()
	_phase = "trial"


func _planar(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _step_trial() -> void:
	_t += 1
	var kind: String = _trial["kind"]
	var body := _ball()
	var v := body.linear_velocity
	var p := body.global_position
	var state = _game.player.state
	var slam_on := true
	if kind == "air":
		slam_on = bool(_trial.get("slam", true))
		_source.hold = {"move": Vector2(0.0, 1.0)}
		if slam_on:
			_source.hold["brake_held"] = true
	elif kind == "ctl":
		_source.hold = {"move": Vector2(0.0, 1.0)}
	elif kind == "hop":
		_drive_hop(p, v)
	elif kind == "run":
		_drive_run(p, v)
	# Log.
	var row := {"t": _t, "p": [p.x, p.y, p.z], "v": [v.x, v.y, v.z], "g": state.grounded, "broken": _plate.broken,
		"slamming": _game.player.kit.slamming, "elig": _plate.eligible}
	_trace.append(row)
	if not _trial.has("pre") and _game.player.kit.slamming:
		_trial["pre"] = _planar(v)
	if _trial["broke_t"] < 0 and _plate.broken:
		_trial["broke_t"] = _t
		_trial["break_planar"] = _planar(v)
		_trial["break_fall"] = -v.y
		_trial["break_strength"] = _plate.last_break_strength
	if _trial["broke_t"] >= 0 and _trial["landed_t"] < 0 and state.grounded and p.y < 6.0 and _t > _trial["broke_t"] + 3:
		_trial["landed_t"] = _t
	if kind == "run":
		_occlusion_row(p)
		_native_row(p)
	var done := _t >= int(_trial.get("limit", 90 * 6))
	if kind == "run":
		done = done or _cam_state.get("done", false)
	elif kind == "ctl":
		pass
	elif kind != "run" and _trial["landed_t"] >= 0:
		done = done or _t >= _trial["landed_t"] + int(90.0 * float(_trial.get("follow", 0.5)))
	if kind != "run" and kind != "ctl" and _trial["landed_t"] < 0 and _t >= 90 * 4 and not _plate.broken:
		done = true
	if p.y < -20.0:
		done = true
	if done:
		_finish_trial()


func _drive_hop(p: Vector3, v: Vector3) -> void:
	_source.hold = {"move": Vector2(0.0, 1.0)}
	var lead: float = _trial["lead"]
	if not _trial["jumped"] and p.z >= PLATE.z - lead:
		_trial["jumped"] = true
		_trial["jump_t"] = _t
		_source.press = {"jump_pressed": true}
	if _trial["jumped"]:
		if _trial["slam_from"] < 0 and not _game.player.state.grounded and _t > _trial["jump_t"] + 3 and p.z >= PLATE.z + float(_trial["at"]):
			# Slam once over the plate's window.
			_trial["slam_from"] = _t
		if _trial["slam_from"] >= 0:
			_source.hold["brake_held"] = true


func _finish_trial() -> void:
	var rec := {"label": _trial["label"], "kind": _trial["kind"], "broke": _trial["broke_t"] >= 0,
		"break_strength": _trial.get("break_strength", 0.0), "break_fall": _trial.get("break_fall", 0.0),
		"break_planar": _trial.get("break_planar", 0.0)}
	if OS.get_cmdline_user_args().has("--dump"):
		print("TRACE ", _trial["label"])
		for i in range(0, _trace.size(), 6):
			var r: Dictionary = _trace[i]
			print("  t=%d p=(%.1f,%.1f,%.1f) v=(%.1f,%.1f,%.1f) g=%s slam=%s" % [r["t"], r["p"][0], r["p"][1], r["p"][2], r["v"][0], r["v"][1], r["v"][2], str(r["g"]), str(r["slamming"])])
	var last: Dictionary = _trace[_trace.size() - 1]
	if _trial["kind"] == "ctl":
		var v0: Array = _trace[0]["v"]
		var v1: Array = _trace[_trace.size() - 1]["v"]
		rec["pre"] = Vector2(v0[0], v0[2]).length()
		rec["ratio_at_1s"] = Vector2(v1[0], v1[2]).length() / rec["pre"]
		rec["ratio_min_1s"] = rec["ratio_at_1s"]
	rec["end_y"] = last["p"][1]
	rec["end_xz"] = [last["p"][0], last["p"][2]]
	rec["landed_strengths"] = _plate.landed_strengths.duplicate()
	_plate.landed_strengths.clear()
	rec["plate_breaks"] = _plate.breaks
	if _trial["kind"] == "hop":
		rec["slam_t"] = _trial.get("slam_from", -1)
	# Speed after landing on the gallery floor.
	rec["pre"] = _trial.get("pre", 0.0)
	if _trial["landed_t"] >= 0:
		var li: int = _trial["landed_t"] - 1
		var pre := float(rec["pre"])
		var after: Array = []
		var min_ratio := 9.0
		for i in range(li, mini(_trace.size(), li + 90)):
			var v: Array = _trace[i]["v"]
			var s := Vector2(v[0], v[2]).length()
			after.append(s)
			if pre > 0.5:
				min_ratio = minf(min_ratio, s / pre)
		rec["landing_planar"] = after[0] if not after.is_empty() else 0.0
		rec["planar_at_1s"] = after[after.size() - 1] if not after.is_empty() else 0.0
		rec["planar_min_1s"] = after.min() if not after.is_empty() else 0.0
		rec["ratio_at_1s"] = (rec["planar_at_1s"] / pre) if pre > 0.5 else -1.0
		rec["ratio_min_1s"] = min_ratio if pre > 0.5 else -1.0
		rec["landed_y"] = _trace[li]["p"][1]
	if _trial["kind"] == "run":
		rec["occlusion"] = _cam_state.duplicate()
		rec["occlusion_rows"] = _occ_rows
		rec["perf"] = {"native": _native, "adapter": RenderingServer.get_video_adapter_name() if _native else "", "frames": _gpu.size(),
			"gpu_ms_p50": _p50(_gpu), "gpu_ms_p99": _p99(_gpu), "cpu_ms_p50": _p50(_cpu), "cpu_ms_p99": _p99(_cpu),
			"wall_ms_p50": _p50(_wall), "wall_ms_p99": _p99(_wall), "gpu_ms_max": (_gpu.max() if not _gpu.is_empty() else -1.0)}
		print("perf: ", JSON.stringify(rec["perf"]))
		rec["trace_every_10"] = []
		for i in range(0, _trace.size(), 10):
			rec["trace_every_10"].append(_trace[i])
	_results.append(rec)
	_next_trial()


func _finish() -> void:
	var text := JSON.stringify(_results, "  ")
	if _out != "":
		var f := FileAccess.open(_out, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	_summarise()
	_game.free()
	quit(0)


func _summarise() -> void:
	for r in _results:
		if r["kind"] == "run":
			var o: Dictionary = r["occlusion"]
			print("run: ticks=%d worst_frac=%.3f worst_tick=%d worst_at=%s mean=%.4f frames_over_0.30=%d plate_broke=%s end=%s outcome=%s" % [
				_trace.size(), o.get("worst", 0.0), o.get("worst_t", -1), str(o.get("worst_at", [])), o.get("mean", 0.0),
				o.get("over", 0), str(r["broke"]), str(r["end_xz"]), o.get("outcome", "")])
			continue
		print("%s | broke=%s strength=%.3f fall=%.1f planar=%.1f end_y=%.2f landed=%s landed_str=%s ratio_1s=%s ratio_min=%s" % [
			r["label"], str(r["broke"]), r["break_strength"], r["break_fall"], r["break_planar"], r["end_y"], str(r.has("landing_planar")),
			str(r["landed_strengths"]), str(snappedf(r.get("ratio_at_1s", -2.0), 0.01)), str(snappedf(r.get("ratio_min_1s", -2.0), 0.01))])
	if _mode == "drops":
		var floor_n := 0
		var deck_n := 0
		var other := 0
		var under := 0
		for r in _results:
			var y: float = r["end_y"]
			if y < -0.5:
				under += 1
			elif r["broke"] and y < 3.5:
				floor_n += 1
			elif y > 10.0:
				deck_n += 1
			else:
				other += 1
		print("drops: %d total, %d on the lower floor, %d stayed on the deck, %d other, %d fell below the floor" % [_results.size(), floor_n, deck_n, other, under])


# ---- the scripted run ----

const RUN_WAYPOINTS := [Vector3(0.0, 0.0, -40.0), Vector3(0.0, 0.0, 20.0), Vector3(0.0, 0.0, 70.0), Vector3(0.0, 0.0, 100.0)]
var _run_leg := 0
var _run_jumped := false
var _run_slam_from := -1
var _occ_worst := 0.0


func _start_run() -> void:
	_run_leg = 0
	_run_jumped = false
	_run_slam_from = -1
	_occ_worst = 0.0
	_cam_state = {"worst": 0.0, "worst_t": -1, "sum": 0.0, "n": 0, "over": 0, "done": false, "outcome": "timeout"}
	_trial["limit"] = 90 * 40
	_place(Vector3(0.0, 15.2, -84.0), Vector3(0.0, 0.0, 1.0))
	_game.camera.snap(HEADING)


func _drive_run(p: Vector3, v: Vector3) -> void:
	_source.hold = {"move": Vector2(0.0, 1.0)}
	# Look straight down the channel line.
	_game.camera.yaw = PI
	# Deck: roll; jump 12 m before the plate; slam on the way down over it.
	if p.y > 10.0 and p.z < PLATE.z + 6.0:
		if not _run_jumped and p.z >= PLATE.z - 12.0 and _game.player.state.grounded:
			_run_jumped = true
			_source.press = {"jump_pressed": true}
		if _run_jumped and not _game.player.state.grounded and v.y < 0.0 and p.z >= PLATE.z - 5.0:
			_source.hold["brake_held"] = true
	# Gallery: hold the line on x = 0.
	if p.y < 6.0:
		var aim := Vector3(0.0, 0.0, p.z + 12.0)
		var d := aim - Vector3(p.x, 0.0, p.z)
		_game.camera.yaw = atan2(-d.x, -d.z)
	if p.z > 98.0 and p.y > 12.0:
		_cam_state["done"] = true
		_cam_state["outcome"] = "south deck reached"
	if _t > 20 and p.y < -2.0:
		_cam_state["done"] = true
		_cam_state["outcome"] = "fell below the floor"


func _native_row(p: Vector3) -> void:
	if not _native:
		return
	var now := Time.get_ticks_usec()
	var gallery := p.y < 6.0 and p.z > -46.0 and p.z < 46.0 and _t > 300
	if gallery and _last_us > 0:
		var rid := root.get_viewport_rid()
		_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		_wall.append(float(now - _last_us) / 1000.0)
	_last_us = now
	if _t in _shots and _shotdir != "":
		_save_shot.call_deferred(_t)


func _save_shot(tick: int) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shotdir)
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(_shotdir.path_join("tick-%04d.png" % tick))


static func _p50(a: Array[float]) -> float:
	if a.is_empty():
		return -1.0
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]


static func _p99(a: Array[float]) -> float:
	if a.is_empty():
		return -1.0
	var b := a.duplicate()
	b.sort()
	return b[mini(b.size() - 1, int(ceil(0.99 * b.size())) - 1)]


# The fraction of the ball's disc, seen from the camera, with a world body between.
func _occlusion_row(p: Vector3) -> void:
	var cam: Camera3D = _game.camera.cam
	var eye := cam.global_position
	var to := p - eye
	var dist := to.length()
	if dist < 0.01:
		return
	var axis := to / dist
	var right := axis.cross(Vector3.UP).normalized()
	var up := right.cross(axis).normalized()
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	var n := 40
	var blocked := 0
	for i in n:
		var r := 0.95 * sqrt((float(i) + 0.5) / float(n))
		var a := float(i) * 2.399963
		var q := p + right * (cos(a) * r) + up * (sin(a) * r)
		var ray := PhysicsRayQueryParameters3D.create(eye, q, 1)
		var hit: Dictionary = space.intersect_ray(ray)
		if not hit.is_empty() and (hit["position"] as Vector3).distance_to(q) > 0.15:
			blocked += 1
	var frac := float(blocked) / float(n)
	# The camera sitting inside geometry reads as fully hidden.
	var inside: bool = not space.intersect_point(_point_query(eye)).is_empty()
	if inside:
		frac = 1.0
	if p.z > 4.0 and p.z < 44.0 and p.y < 6.0:
		_cam_state["tunnel_frames"] = int(_cam_state.get("tunnel_frames", 0)) + 1
		_cam_state["tunnel_cam_y_max"] = maxf(float(_cam_state.get("tunnel_cam_y_max", 0.0)), eye.y)
		_cam_state["tunnel_cam_dist_min"] = minf(float(_cam_state.get("tunnel_cam_dist_min", 99.0)), dist)
		_cam_state["tunnel_cam_dist_max"] = maxf(float(_cam_state.get("tunnel_cam_dist_max", 0.0)), dist)
		if frac > float(_cam_state.get("tunnel_worst", 0.0)):
			_cam_state["tunnel_worst"] = frac
	_cam_state["sum"] += frac
	_cam_state["n"] += 1
	if frac > 0.30:
		_cam_state["over"] += 1
	if frac > _cam_state["worst"]:
		_cam_state["worst"] = frac
		_cam_state["worst_t"] = _t
		_cam_state["worst_at"] = [p.x, p.y, p.z]
		_cam_state["worst_eye"] = [eye.x, eye.y, eye.z]
	_cam_state["mean"] = _cam_state["sum"] / float(_cam_state["n"])
	if _t % 10 == 0 or frac > 0.0:
		_occ_rows.append([_t, snappedf(frac, 0.001), snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1), snappedf(eye.y, 0.1), snappedf(eye.z, 0.1)])


func _point_query(at: Vector3) -> PhysicsPointQueryParameters3D:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = at
	q.collision_mask = 1
	return q
