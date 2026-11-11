extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LaunchTake := preload("res://src/presentation/launch_take.gd")

# The two world 1 stage launches filmed as a player with a hand on the controls sees them: the dam to the flume and the
# flume to the Slag Bowl. For each seam it saves a 1920x1080 frame every 0.1 s of game time from 2 s before the launch to
# 1.5 s after the ball touches down in the next place, then one contact sheet, so a person can judge whether the hand-over
# reads as one move. It needs a rendered display; run it headless on the 3060 with a fixed frame rate, so a frame is
# exactly 1/60 s of game time whatever the renderer's speed (see seam_strip_capture.md):
#
#   source /home/andrew/scratch/world1/env-pc.sh <name> 1 2 <pool>
#   PULSE_SINK=claude_silent timeout 600 nice -n 10 gamescope --backend headless --prefer-vk-device 10de:2504 \
#     -W 1920 -H 1080 -w 1920 -h 1080 -- $GODOT_BIN --path sketches/core-loop --gpu-index 1 \
#     --resolution 1920x1080 --fixed-fps 60 --audio-driver Dummy --script res://tools/seam_strip_capture.gd -- \
#     --out=<absolute dir> [--seed=0] [--selftest=1]
#
# The launch is the game's own: the Warden's seal is lifted as the test path does (flow._unseal), the ball rolls up to the
# stage's beacon, a reward is chosen (events.reward_chosen) and world.gd fires the ball. The take is forced live
# (launch_take.force_live), the swipe runs in real frames. Nothing here reads a position or heading: the launch, the swipe's
# phases, the cut, the touchdown and the return of control all come from signals and the take's own phase.
# Exit 0 when both strips and sheets are written; 1 naming each seam not reached (a launch that never happens, a flat or
# under-50 KB frame, no frame between full cover and the reveal's start, no touchdown); 2 on a bad argument.
# --selftest=1 adds a third seam whose launch is never fired, to show the failure path.

const SEAMS := [
	{"name": "dam-flume", "from_stage": 1, "what": "Dam to the flume"},
	{"name": "flume-bowl", "from_stage": 2, "what": "Flume to the Slag Bowl"},
]
const SELFTEST_SEAM := {"name": "selftest-never", "from_stage": 0, "what": "Planted failure: the launch never fires", "never": true}

const STEP_S := 0.1
const LEAD_S := 2.0
const TAIL_S := 1.5
# Game seconds, from the launch, to reach touchdown and the return of control.
const LIMIT_S := 8.0
# Game seconds to reach the stage before the launch.
const READY_LIMIT_S := 20.0
const SELFTEST_LIMIT_S := 3.0
const ROLL_SPEED := 8.0
const MIN_BYTES := 50000
const WATCHDOG := 400.0
const SHEET_COLUMNS := 6
const SHEET_THUMB := "384x216"

var _out := ""
var _seed := 0
var _selftest := false
var _game
var _take
var _args := {}
var _missed: Array = []
var _seams: Array = []
var _clock := 0.0
var _gt := 0.0
var _done := false
# Filled by signals during a seam.
var _events := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			_args[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	_out = _args.get("out", "")
	_seed = int(_args.get("seed", "0"))
	_selftest = _args.get("selftest", "0") == "1"
	var known := ["out", "seed", "selftest"]
	var stray := _args.keys().filter(func(k): return not known.has(k))
	if _out == "" or not stray.is_empty() or not _args.get("selftest", "0") in ["0", "1"]:
		printerr("seam_strip_capture: needs -- --out=<absolute dir> [--seed=<int>] [--selftest=0|1]%s" % ((" (unknown: %s)" % ", ".join(stray)) if not stray.is_empty() else ""))
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		printerr("seam_strip_capture: needs a rendered display (gamescope headless backend), not --headless")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	seed(_seed)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _run() -> void:
	while _game.flow == null:
		await process_frame
	_take = _game.launch_take
	await _frames(30)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	await _fresh_run()
	_connect_events()
	var rows: Array = SEAMS.duplicate()
	if _selftest:
		rows.append(SELFTEST_SEAM)
	for row in rows:
		var result := await _film(row)
		_seams.append(result)
		if result.get("fault", "") != "":
			_missed.append("%s (%s)" % [row["name"], result["fault"]])
		elif not bool(row.get("never", false)):
			_sheet(result)
		if result.get("fault", "") != "" and not bool(row.get("never", false)):
			# A seam that failed leaves the next one nothing sound to start from.
			break
	_finish()


# A watchdog on wall time: a drive that errors leaves its coroutine stuck, and the clock ends the run naming what is left.
func _process(delta: float) -> bool:
	_clock += delta
	_gt += delta
	if _clock > WATCHDOG and not _done and _game != null:
		for row in SEAMS:
			if _seams.filter(func(s): return s["seam"] == row["name"]).is_empty():
				_missed.append("%s (run timed out)" % row["name"])
		_finish()
	return false


func _frames(count: int) -> void:
	for i in count:
		await process_frame


# A fresh run of the seed's pilot, calm, with the briefing out of the way (the ui_screens_capture run rows' start).
func _fresh_run() -> void:
	_take.force_live = false
	_game.flow.show_title()
	await _frames(20)
	_game.bot_driven = true
	_game.get_node("Workshop").armed = true
	_game.flow.press_start()
	await _frames(10)
	_game.flow.choose_class(_seed % _game.flow.classes.size())
	await _frames(90)
	var ws = _game.get_node("Workshop")
	ws.armed = false
	ws.close_all()
	_game.flow.start_card.hide_card()
	await _frames(10)
	_take.force_live = true


func _connect_events() -> void:
	var ev = _game.events
	ev.launched.connect(func(_v): _events["launch"] = _gt)
	ev.landed.connect(func(impact: float):
		# Only a landing after the cut counts; the flight over the old ground never does.
		if _events.has("cut") and not _events.has("touchdown"):
			_events["touchdown"] = _gt
			_events["impact"] = impact)
	_take.covered.connect(func(): _events["covered"] = _gt)


# One seam: the ball rolls up to the beacon, the seal is lifted, a reward is chosen and the launch is filmed.
func _film(row: Dictionary) -> Dictionary:
	var name := String(row["name"])
	var never := bool(row.get("never", false))
	var flow = _game.flow
	var result := {"seam": name, "what": row["what"], "frames": [], "fault": ""}
	_events = {}
	var from_stage: int = _game.run.stage
	var ready_end := _gt + READY_LIMIT_S
	while not never and (not (flow.state_name() in ["stage", "beacon"]) or _game.player.frozen() or not _game.ctx.terrain.is_ready(from_stage)):
		await process_frame
		if _gt > ready_end:
			result["fault"] = "the stage was never ready to launch from"
			return result
	if not never and from_stage != int(row["from_stage"]):
		result["fault"] = "expected to launch from stage %d, the run is on %d" % [row["from_stage"], from_stage]
		return result
	result["from_stage"] = from_stage
	# Roll the ball up to the stage's beacon (the exit), lift the Warden's seal, then pick a reward 2 s on.
	var terrain = _game.ctx.terrain
	if never:
		# The planted seam fires nothing: it waits out its short limit and is named as not reached.
		await _frames(int(SELFTEST_LIMIT_S * 60.0))
		result["fault"] = "the launch was never reached within %.0f s" % SELFTEST_LIMIT_S
		return result
	var beacon: Vector3 = terrain.beacon_point(from_stage)
	var spawn: Vector3 = terrain.spawn_point(from_stage)
	var toward := Vector3(beacon.x - spawn.x, 0.0, beacon.z - spawn.z)
	toward = toward.normalized() if toward.length() > 0.5 else terrain.entry_heading(from_stage)
	var start := beacon - toward * ROLL_SPEED * LEAD_S
	start.y = terrain.drop_point(start.x, start.z, 1.6).y
	_game.player.reset_to(start, toward * ROLL_SPEED)
	_game.player.set_velocity_now(toward * ROLL_SPEED)
	_game.player.body().global_position = start
	if flow.has_method("_unseal") and flow.sealed:
		flow._unseal()
	await process_frame
	var t0 := _gt
	var fire_at := t0 + LEAD_S
	var frames: Array = []
	var next_k := -int(round(LEAD_S / STEP_S))
	var launched := false
	var stats := {"closed": -1.0, "reveal": -1.0, "cut": -1.0, "control": -1.0}
	var end_k := 99999
	var limit := fire_at + (SELFTEST_LIMIT_S if never else LIMIT_S)
	while true:
		if not launched and not never and _gt >= fire_at:
			launched = true
			if flow.state_name() != "gates":
				flow._set_state(flow.GATES)
			_game.events.reward_chosen.emit("seam")
			if not _events.has("launch"):
				_events["launch"] = _gt
		var base: float = _events.get("launch", fire_at)
		var rel: float = _gt - base
		# Read the take and the flow every frame, so the times are the game's.
		if launched:
			if stats["closed"] < 0.0 and _take.busy() and _take.progress() >= 1.0:
				stats["closed"] = rel
			if stats["reveal"] < 0.0 and _take.phase == LaunchTake.REVEAL:
				stats["reveal"] = rel
			if stats["cut"] < 0.0 and (_game.run.stage != from_stage or flow.state_name() == "boss"):
				stats["cut"] = rel
				_events["cut"] = _gt
			if stats["control"] < 0.0 and stats["cut"] >= 0.0 and not _take.busy() and not _game.player.frozen() and flow.in_play():
				stats["control"] = rel
		# A frame is due every STEP_S of game time from the first, whatever the renderer does.
		var due: float = (fire_at if not launched else base) + float(next_k) * STEP_S
		if _gt + 1e-6 >= due and next_k <= end_k:
			await RenderingServer.frame_post_draw
			var shot := _grab(name, frames.size(), rel)
			shot["k"] = next_k
			shot["phase"] = _take.phase
			shot["progress"] = _take.progress()
			shot["stage"] = _game.run.stage
			shot["state"] = flow.state_name()
			frames.append(shot)
			next_k += 1
		if _events.has("touchdown") and end_k == 99999:
			var tk := int(ceil((_events["touchdown"] - base) / STEP_S - 1e-6)) + int(round(TAIL_S / STEP_S))
			end_k = tk
		if next_k > end_k:
			break
		if _gt > limit:
			break
		await process_frame
	result["frames"] = frames
	result["stage_after"] = _game.run.stage
	if not launched:
		result["fault"] = "the launch was never reached within %.0f s" % (SELFTEST_LIMIT_S if never else LIMIT_S)
		return result
	if not _events.has("touchdown"):
		result["fault"] = "no touchdown within %.0f s of the launch" % LIMIT_S
		return result
	var base2: float = _events["launch"]
	result["times_s"] = {
		"launch": 0.0,
		"swipe_fully_closed": stats["closed"],
		"cut": stats["cut"],
		"reveal_starts": stats["reveal"],
		"touchdown": _events["touchdown"] - base2,
		"control": stats["control"],
	}
	result["landing_impact"] = _events.get("impact", 0.0)
	result["state_after_cut"] = flow.state_name()
	for key in ["closed", "reveal", "cut", "control"]:
		if stats[key] < 0.0:
			result["fault"] = "the %s moment never came" % key
			return result
	var flat := frames.filter(func(f): return f["flat"] or int(f["bytes"]) < MIN_BYTES)
	if not flat.is_empty():
		result["fault"] = "%d frame(s) flat or under %d bytes, first %s" % [flat.size(), MIN_BYTES, flat[0]["file"]]
		return result
	var between := frames.filter(func(f): return float(f["t"]) >= stats["closed"] - 1e-6 and float(f["t"]) <= stats["reveal"] + 1e-6)
	if between.is_empty():
		result["fault"] = "no frame between full cover (%.3f s) and the reveal's start (%.3f s)" % [stats["closed"], stats["reveal"]]
		return result
	print("seam_strip_capture: %s %d frames, launch 0, closed %.2f, cut %.2f, reveal %.2f, touchdown %.2f, control %.2f s" % [name, frames.size(),
		stats["closed"], stats["cut"], stats["reveal"], result["times_s"]["touchdown"], stats["control"]])
	return result


# The frame, as the 1920x1080 viewport drew it. Flat means almost every sampled pixel is one colour.
func _grab(seam: String, index: int, rel: float) -> Dictionary:
	var image := root.get_texture().get_image()
	var ms := int(round(rel * 1000.0))
	var file := "%s-%03d-%s%04dms.png" % [seam, index, "+" if ms >= 0 else "-", absi(ms)]
	var path := _out.path_join(file)
	image.save_png(path)
	var bytes := FileAccess.get_file_as_bytes(path).size()
	var seen := {}
	for y in range(0, image.get_height(), 24):
		for x in range(0, image.get_width(), 24):
			seen[image.get_pixel(x, y).to_html(false)] = true
	return {"file": file, "t": rel, "ms": ms, "bytes": bytes, "colours": seen.size(), "flat": seen.size() < 8,
		"size": [image.get_width(), image.get_height()]}


# One sheet per seam with ImageMagick's montage: frames in order, left to right, each labelled with its time from the launch.
func _sheet(result: Dictionary) -> void:
	var args: PackedStringArray = ["-font", "Adwaita-Sans", "-pointsize", "20"]
	for f in result["frames"]:
		args.append_array(["-label", "%+d ms  %s" % [f["ms"], _mark(result, f)], _out.path_join(f["file"])])
	args.append_array(["-tile", "%dx" % SHEET_COLUMNS, "-geometry", SHEET_THUMB + "+4+4", "-background", "#202020", "-fill", "white",
		_out.path_join("%s-sheet.png" % result["seam"])])
	var log := []
	var code := OS.execute("montage", args, log, true)
	if code != 0:
		_missed.append("%s (montage exited %d: %s)" % [result["seam"], code, "".join(log).strip_edges().left(160)])
		return
	result["sheet"] = "%s-sheet.png" % result["seam"]


# The moment words under a thumbnail, from the times already read.
func _mark(result: Dictionary, f: Dictionary) -> String:
	var t: float = f["t"]
	var times: Dictionary = result["times_s"]
	var words := []
	var step := STEP_S * 0.5
	for key in [["launch", "launch"], ["swipe_fully_closed", "closed"], ["cut", "cut"], ["reveal_starts", "reveal"], ["touchdown", "touchdown"], ["control", "control"]]:
		var at: float = float(times[key[0]])
		if at > t - step and at <= t + step:
			words.append(key[1])
	return " ".join(words)


func _finish() -> void:
	_done = true
	var info := {"exit_code": 0 if _missed.is_empty() else 1, "seed": _seed, "adapter": RenderingServer.get_video_adapter_name(), "step_s": STEP_S, "lead_s": LEAD_S, "tail_s": TAIL_S,
		"seams": _seams.map(func(s): return _brief(s)), "missed": _missed}
	var file := FileAccess.open(_out.path_join("capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info, "  "))
		file.close()
	paused = false
	if _missed.is_empty():
		print("seam_strip_capture: %d seams in %s" % [_seams.size(), _out])
		quit(0)
	else:
		printerr("seam_strip_capture: NOT REACHED: %s" % "; ".join(_missed))
		quit(1)


# The seam as capture.json keeps it: the times, then the frames' rows.
func _brief(s: Dictionary) -> Dictionary:
	var out := {"seam": s["seam"], "what": s["what"], "fault": s["fault"], "frames": s["frames"]}
	for key in ["from_stage", "stage_after", "times_s", "landing_impact", "state_after_cut", "sheet"]:
		if s.has(key):
			out[key] = s[key]
	return out
