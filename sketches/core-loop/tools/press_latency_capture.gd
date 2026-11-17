extends SceneTree
# UA-08: P5 in design-v3/ui-audit/principles.json, "A press shows on screen or in sound within 100 ms".
# For each player verb and each menu press the tool injects the press as a real input event
# (Input.parse_input_event, with the bound key or mouse button, so the engine's input path, the action
# map and the game's own readers are part of what is timed) and times it to the first change the player
# can see or hear:
#   screen  the first rendered frame that differs from the frame before it (the frame grabbed just before the
#           press, for the first one) by MIN_PX or more pixels, each differing by DIFFER or more in a channel,
#           on the picture shrunk to SMALL. It is the step from the frame before, not the distance from the
#           frame before the press: the park's smoke and dust drift all the time and add up against a fixed frame;
#   sound   the first frame at which the audio module's cue_log has grown since the press.
# Whichever answers first is recorded in `by`. Time = Time.get_ticks_usec from the injection to that
# frame's draw. This is ENGINE-SIDE latency: display scan-out and the operating system's input stack are
# not included, so the true figure on a monitor is higher. The press lands at a random point inside a
# frame (a short busy wait after a grab), so a case's spread includes where in the frame it fell.
# The menu's title is a live 3D park (birds, sparks, water) whose steps reach about 130 of these pixels, so the menu
# line is MENU_MIN_PX: a press whose only change is smaller than about 5000 full-size pixels is not seen on the menu.
# Before each press a matched control runs the same window with no press: any frame that differs, or any
# cue that grows, is a false change. A case's controls must show zero false changes or the case is
# `noisy` and fails. Each case takes TRIALS presses; the median and the worst are kept; a case passes when
# its worst is at most LINE_MS and every press was answered. A press nothing answered in WINDOW_US is an
# unanswered press and fails the case, with the worst recorded as null.
# The window is WINDOW_US (125 ms), because a press unanswered by 100 ms already fails; later frames are not read
# (a freed ball also lands about 170 ms on, which a control reads as change).
# Verbs run in a test-mode game (stage 1, the keyboard source on, the real input path to the ball); menu presses
# run in a played-mode game on the title, which also takes the game's own input handler. The ball rolls on a slope
# all the time, so a still picture needs it held: it lands, then the physics body's freeze holds it at that pose,
# and each window frees it at rest at the same instant in the press and in its control. Presses whose answer is
# the ball's own motion are therefore read from their cue, effect or HUD change, and `cues` names the cue. The two
# prompt rows by the ball (key_glyphs, first_steps) breathe on their own and are hidden, so a press answered only by
# one of them is not seen. A control window that is not still is settled and run again, at most RETRIES times per press; every window run and every one
# that was not still is reported (`control_windows`, `control_windows_not_still`), and `false_changes` counts the control paired with each press.
# --plant=slow holds one named press (jump) for PLANT_HOLD_US inside the tool before it is released to the
# game: that case must fail, and the run exits 1. Real run: exit 0 pass, 1 fail. Both: 2 with no display or
# no --out. 3 when the plant run's control reports a false change.
#   gpu-run.sh <worktree> ua08 --path sketches/core-loop --script res://tools/press_latency_capture.gd -- \
#     --out=<abs dir> [--part=verbs|menu|all] [--cases=a,b] [--trials=N] [--plant=slow]

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")

const SIZE := Vector2i(1280, 720)
const SMALL := Vector2i(256, 144)
const LINE_MS := 100.0
const DIFFER := 8
const MIN_PX := 60
const MENU_MIN_PX := 300
const TRIALS := 5
const WINDOW_FRAMES := 12
const WINDOW_US := 125000
const PLANT_HOLD_US := 150000
const PLANT_CASE := "jump"
const FRAME_US := 16000
const LANDED := 1.6
const REST_FRAMES := 90
const RETRIES := 3

# name, part, input kind, code. Keys are physical keycodes; "mouse" is a button index.
const VERBS := [
	{"name": "roll", "kind": "key", "code": KEY_W},
	{"name": "jump", "kind": "key", "code": KEY_SPACE},
	{"name": "boost", "kind": "key", "code": KEY_SHIFT},
	{"name": "fire", "kind": "mouse", "code": MOUSE_BUTTON_LEFT},
	{"name": "harpoon", "kind": "mouse", "code": MOUSE_BUTTON_RIGHT},
	{"name": "haul", "kind": "key", "code": KEY_CTRL},
	{"name": "interact", "kind": "key", "code": KEY_E},
	{"name": "slot2", "kind": "key", "code": KEY_2},
	{"name": "ultimate", "kind": "key", "code": KEY_Q},
	{"name": "active", "kind": "key", "code": KEY_F},
	{"name": "pause", "kind": "key", "code": KEY_P},
]

var out := ""
var plant := ""
var part := "all"
var trials := TRIALS
var only: Array = []
var game
var cases: Array = []
var _adapter := ""
var _rest_pose := Transform3D()
var _min_px := MIN_PX


# The first frame that answers a press. `frames` is a list of {"t": usec, "px": pixels differing from the
# frame before the press, "cues": cue_log growth since the press}. A frame stamped before `t0` is ignored.
# Returns {"answered", "us", "by", "frame"}; `by` is "screen", "sound", "both" or "none".
static func first_change(t0: int, frames: Array, min_px: int) -> Dictionary:
	for i in frames.size():
		var f: Dictionary = frames[i]
		if int(f["t"]) < t0:
			continue
		var seen: bool = int(f["px"]) >= min_px
		var heard: bool = int(f["cues"]) > 0
		if seen or heard:
			return {"answered": true, "us": int(f["t"]) - t0, "by": "both" if seen and heard else ("screen" if seen else "sound"), "frame": i}
	return {"answered": false, "us": -1, "by": "none", "frame": -1}


# How many frames of a control window changed: the false changes of a case's no-press run.
static func false_changes(frames: Array, min_px: int) -> int:
	var n := 0
	for f in frames:
		if int(f["px"]) >= min_px or int(f["cues"]) > 0:
			n += 1
	return n


# One case from its presses' results (each a first_change dictionary) and its controls' false-change counts.
static func summarize(results: Array, controls: Array, line_ms: float) -> Dictionary:
	var ms: Array = []
	var unanswered := 0
	for r in results:
		if r["answered"]:
			ms.append(float(r["us"]) / 1000.0)
		else:
			unanswered += 1
	ms.sort()
	var false_total := 0
	for c in controls:
		false_total += int(c)
	var worst: Variant = null
	var median: Variant = null
	if not ms.is_empty():
		median = ms[ms.size() / 2]
		worst = ms[ms.size() - 1]
	var ok: bool = results.size() > 0 and unanswered == 0 and worst != null and float(worst) <= line_ms and false_total == 0
	return {"n": results.size(), "answered": ms.size(), "unanswered": unanswered, "median_ms": median, "worst_ms": worst,
		"control_trials": controls.size(), "false_changes": false_total, "pass": ok}


# The number of pixels that differ by `differ` or more in any channel. Both images are RGB8 and one size.
static func differing_pixels(a: Image, b: Image, differ: int) -> int:
	var da := a.get_data()
	var db := b.get_data()
	if da == db:
		return 0
	var n := 0
	var i := 0
	var end := da.size()
	while i + 2 < end:
		if absi(da[i] - db[i]) >= differ or absi(da[i + 1] - db[i + 1]) >= differ or absi(da[i + 2] - db[i + 2]) >= differ:
			n += 1
		i += 3
	return n


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--plant="):
			plant = a.trim_prefix("--plant=")
		elif a.begins_with("--part="):
			part = a.trim_prefix("--part=")
		elif a.begins_with("--trials="):
			trials = maxi(1, int(a.trim_prefix("--trials=")))
		elif a.begins_with("--cases="):
			only = Array(a.trim_prefix("--cases=").split(",", false))
	if DisplayServer.get_name() == "headless" or out == "":
		printerr("needs a display and --out")
		quit(2)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _wanted(name: String) -> bool:
	return only.is_empty() or only.has(name)


func _run() -> void:
	seed(40808)
	DirAccess.make_dir_recursive_absolute(out)
	_adapter = RenderingServer.get_video_adapter_name()
	if plant == "slow":
		part = "verbs"
		only = [PLANT_CASE]
	if part == "verbs" or part == "all":
		await _verbs()
	if part == "menu" or part == "all":
		await _menu()
	_finish()


func _finish() -> void:
	var failed := 0
	var false_total := 0
	var plant_pass := true
	for c in cases:
		if not c["pass"]:
			failed += 1
		false_total += int(c["false_changes"])
		if plant != "" and c["name"] == PLANT_CASE:
			plant_pass = c["pass"]
	var verdict := "pass" if cases.size() > 0 and failed == 0 else "fail"
	var code := 0 if verdict == "pass" else 1
	if plant == "slow":
		# The plant's verdict is the plant's alone: it must fail, and its control must be clean.
		verdict = "pass" if plant_pass else "fail"
		code = 3 if false_total > 0 else (0 if plant_pass else 1)
	var head: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], head)
	var f := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"tool": "press_latency_capture.gd", "head": String(head[0]).strip_edges() if head.size() > 0 else "",
		"principle": "P5: A press shows on screen or in sound within 100 ms", "scope": "engine-side latency; display scan-out and the OS input stack are not included",
		"plant": plant, "adapter": _adapter, "size": [SIZE.x, SIZE.y], "line_ms": LINE_MS, "differ": DIFFER, "min_px_verbs": MIN_PX, "min_px_menu": MENU_MIN_PX,
		"compare_size": [SMALL.x, SMALL.y], "window_us": WINDOW_US, "trials": trials, "cases_run": cases.size(), "cases_failed": failed,
		"false_changes": false_total, "verdict": verdict, "cases": cases}, "\t"))
	f.close()
	for c in cases:
		print("press_latency: %-16s n=%d answered=%d median=%s worst=%s by=%s false=%d -> %s" % [c["name"], c["n"], c["answered"], c["median_ms"], c["worst_ms"], c["by"], c["false_changes"], "pass" if c["pass"] else "FAIL"])
	print("press_latency: plant=%s cases %d, failed %d, false changes %d -> %s" % [plant, cases.size(), failed, false_total, verdict])
	quit(code)


# --- the game, per part ---

func _boot_game(played: bool) -> void:
	game = Game.new()
	game.test_mode = not played
	if not played:
		game.table = Game.LAUNCH_TABLE
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	await _frames(30)


func _drop_game() -> void:
	if game != null:
		game.queue_free()
		game = null
	await _frames(20)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _audio():
	if game == null or game.presentation == null:
		return null
	return game.presentation.audio


func _cues() -> int:
	var a = _audio()
	return a.cue_log.size() if a != null else 0


# --- the verbs ---

func _verbs() -> void:
	_min_px = MIN_PX
	await _boot_game(false)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	var keyboard := Intent.Keyboard.new()
	game.player.source = keyboard
	game.flow.enter_stage(1, Vector3.ZERO, false)
	await _frames(60)
	var wait := 0
	while game.hud.launch_card.showing() and wait < 900:
		wait += 1
		await physics_frame
	# The two prompt rows by the ball breathe all the time (first_steps.gd, key_glyphs.gd), which a control would
	# read as change; they are hidden, so a press answered only by one of them is not seen here.
	game.hud.key_glyphs.visible = false
	game.hud.first_steps.visible = false
	await _frames(600)
	for spec in VERBS:
		if _wanted(spec["name"]):
			await _case(spec, "verbs", Callable(self, "_rest_ball"))
	await _drop_game()


# The ball rolls on a slope all the time, so every frame would differ and a control could never read zero. It is
# let land, then held still by the physics body's own freeze (as hud_contrast_capture does); a press still reaches
# the player through the real input path, and the cues, the effects and the HUD answer it. A press whose answer is
# the ball's own motion is therefore answered by something else here, which `answered_by` and `cues` show.
func _rest_ball() -> bool:
	var body = game.player.body()
	if _rest_pose != Transform3D():
		body.freeze = true
		body.global_transform = _rest_pose
		await _frames(REST_FRAMES)
		return true
	body.freeze = false
	var landed := 0
	for i in 2400:
		await physics_frame
		var p: Vector3 = game.player.ball_position()
		landed = landed + 1 if p.y - Telegraph.ground_under(game.ctx.spawner.ground, p) < LANDED else 0
		if landed >= 30:
			body.freeze = true
			_rest_pose = body.global_transform
			await _frames(REST_FRAMES)
			return true
	return false


# --- the menu ---

func _menu() -> void:
	_min_px = MENU_MIN_PX
	await _boot_game(true)
	await _wait_title()
	if _wanted("title_move"):
		await _case({"name": "title_move", "kind": "alternate", "codes": [KEY_DOWN, KEY_UP]}, "menu", Callable(self, "_focus_play"))
	if _wanted("help_open") or _wanted("help_back"):
		await _case({"name": "help_open", "kind": "key", "code": KEY_H, "undo": KEY_ESCAPE}, "menu", Callable(self, "_title_idle"))
		await _case({"name": "help_back", "kind": "key", "code": KEY_ESCAPE, "setup_key": KEY_H}, "menu", Callable(self, "_title_idle"))
	if _wanted("pilot_confirm") or _wanted("pilot_back") or _wanted("pilot_move"):
		await _case({"name": "title_to_pilots", "kind": "key", "code": KEY_SPACE, "undo": KEY_ESCAPE}, "menu", Callable(self, "_title_idle"))
		await _case({"name": "pilots_back", "kind": "key", "code": KEY_ESCAPE, "setup_key": KEY_SPACE}, "menu", Callable(self, "_title_idle"))
		await _pilot_move_case()
	await _drop_game()
	if _wanted("pilot_confirm"):
		await _pilot_confirm_case()


func _wait_title() -> void:
	var guard := 0
	while guard < 3600:
		var stage = game.presentation.get("title_stage") if game.presentation != null else null
		var playing: bool = stage != null and stage.intro_playing()
		if game.flow.state_name() == "title" and not playing and game.get("screens") != null and game.screens.button_for("start") != null:
			break
		guard += 1
		await physics_frame
	await _frames(120)


func _focus_play() -> bool:
	await _frames(20)
	game.screens.button_for("start").grab_focus()
	await _frames(10)
	return true


func _title_idle() -> bool:
	await _frames(20)
	return true


func _pilot_move_case() -> void:
	game.flow.press_start()
	await _frames(60)
	var cards: Array = game.screens.class_cards()
	if cards.is_empty():
		cases.append(_dead_case("pilot_move", "menu", "no pilot cards"))
		return
	await _case({"name": "pilot_move", "kind": "alternate", "codes": [KEY_RIGHT, KEY_LEFT], "focus": cards[0]}, "menu", Callable(self, "_title_idle"))
	game.flow.show_title()
	await _frames(30)


# Each press of the pilot's confirm starts a run, so each press gets a fresh game.
func _pilot_confirm_case() -> void:
	_min_px = MENU_MIN_PX
	var results: Array = []
	var controls: Array = []
	var keep := {}
	for i in trials:
		await _boot_game(true)
		await _wait_title()
		game.flow.press_start()
		await _frames(90)
		var cards: Array = game.screens.class_cards()
		var spec := {"name": "pilot_confirm", "kind": "key", "code": KEY_ENTER}
		if cards.is_empty():
			await _drop_game()
			continue
		cards[0].grab_focus()
		await _frames(30)
		var control := await _window(spec, false, 0)
		controls.append(false_changes(control["frames"], _min_px))
		var trial := await _window(spec, true, 0)
		results.append(trial["result"])
		_keep_worst(keep, trial)
		await _drop_game()
	_add_case("pilot_confirm", "menu", results, controls, keep)


# --- one case ---

func _case(spec: Dictionary, group: String, settle: Callable) -> void:
	var windows := 0
	var noisy := 0
	var results: Array = []
	var controls: Array = []
	var keep := {}
	for i in trials:
		var s: Variant = await settle.call()
		var shape := spec.duplicate()
		if shape["kind"] == "alternate":
			shape["kind"] = "key"
			shape["code"] = shape["codes"][i % 2]
			if shape.has("focus") and i == 0:
				shape["focus"].grab_focus()
				await _frames(20)
		if spec.has("setup_key"):
			await _tap(spec["setup_key"])
			await _frames(40)
		# A control that is not still means the scene had not settled: settle again, at most RETRIES times,
		# and report the retries. The control paired with the press is the one that counts.
		var control := await _window(shape, false, 0)
		var tries := 0
		windows += 1
		while false_changes(control["frames"], _min_px) > 0 and tries < RETRIES:
			tries += 1
			noisy += 1
			windows += 1
			await settle.call()
			control = await _window(shape, false, 0)
		controls.append(false_changes(control["frames"], _min_px))
		await settle.call()
		var hold := PLANT_HOLD_US if plant == "slow" and spec["name"] == PLANT_CASE else 0
		var trial := await _window(shape, true, hold)
		results.append(trial["result"])
		_keep_worst(keep, trial)
		if spec.has("undo"):
			await _frames(30)
			await _tap(spec["undo"])
		elif spec["name"] == "pause":
			await _frames(10)
			await _tap(KEY_P)
		await _frames(20)
		if s == false:
			print("press_latency: %s trial %d: the ball did not settle" % [spec["name"], i])
	_add_case(spec["name"], group, results, controls, keep, windows, noisy)


func _dead_case(name: String, group: String, why: String) -> Dictionary:
	return {"name": name, "group": group, "n": 0, "answered": 0, "unanswered": 0, "median_ms": null, "worst_ms": null, "by": "none",
		"control_trials": 0, "false_changes": 0, "pass": false, "why": why, "samples_ms": [], "frames": []}


func _add_case(name: String, group: String, results: Array, controls: Array, keep: Dictionary, windows := 0, noisy := 0) -> void:
	var rec := summarize(results, controls, LINE_MS)
	rec["control_windows"] = windows
	rec["control_windows_not_still"] = noisy
	rec["name"] = name
	rec["group"] = group
	var samples: Array = []
	var by: Array = []
	for r in results:
		samples.append(snappedf(float(r["us"]) / 1000.0, 0.01) if r["answered"] else null)
		by.append(r["by"])
	rec["samples_ms"] = samples
	rec["answered_by"] = by
	rec["by"] = ", ".join(PackedStringArray(by))
	var cue_names: Array = []
	for r in results:
		cue_names.append(r.get("cue", ""))
	rec["cues"] = cue_names
	# The longest wait between two frames inside each press's window, which says a stalled frame from a late effect.
	var gaps: Array = []
	for r in results:
		gaps.append(snappedf(float(r.get("gap_us", 0)) / 1000.0, 0.01))
	rec["longest_frame_gap_ms"] = gaps
	for k in ["median_ms", "worst_ms"]:
		if rec[k] != null:
			rec[k] = snappedf(float(rec[k]), 0.01)
	var paths: Array = []
	if keep.has("before"):
		var base: String = out.path_join("%s-before.png" % name)
		(keep["before"] as Image).save_png(base)
		paths.append(base)
		if keep.has("after"):
			var after: String = out.path_join("%s-answer.png" % name)
			(keep["after"] as Image).save_png(after)
			paths.append(after)
	rec["frames"] = paths
	cases.append(rec)


# The worst trial of a case keeps its before and answering frames for the record.
func _keep_worst(keep: Dictionary, trial: Dictionary) -> void:
	var r: Dictionary = trial["result"]
	var us: int = int(r["us"]) if r["answered"] else 1 << 40
	if keep.is_empty() or us > int(keep["us"]):
		keep["us"] = us
		keep["before"] = trial["before"]
		keep["after"] = trial["after"]


func _tap(code: int) -> void:
	Input.parse_input_event(_event({"kind": "key", "code": code}, true))
	await _frames(3)
	Input.parse_input_event(_event({"kind": "key", "code": code}, false))
	await _frames(3)


func _event(spec: Dictionary, pressed: bool) -> InputEvent:
	if spec["kind"] == "mouse":
		var m := InputEventMouseButton.new()
		m.button_index = spec["code"]
		m.pressed = pressed
		m.position = Vector2(SIZE) * 0.5
		m.global_position = m.position
		return m
	var k := InputEventKey.new()
	k.physical_keycode = spec["code"]
	k.keycode = spec["code"]
	k.pressed = pressed
	return k


# One window of WINDOW_FRAMES frames, with the press injected at its start when `press`, and none when
# not (the control). Returns the frames as the analysis wants them and the first change.
func _window(spec: Dictionary, press: bool, hold_us: int) -> Dictionary:
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	var small_before := _small(before)
	var cue0 := _cues()
	# Land the press at a random point inside a frame, so no case always meets the same phase.
	var wait_until := Time.get_ticks_usec() + randi() % FRAME_US
	while Time.get_ticks_usec() < wait_until:
		pass
	var t0 := Time.get_ticks_usec()
	# The held ball is let go at the same moment in the press and in its control, from rest.
	_let_go()
	var grabs: Array = []
	var injected := not press
	while grabs.size() < WINDOW_FRAMES + hold_us / FRAME_US and Time.get_ticks_usec() - t0 < WINDOW_US + hold_us:
		if press and not injected and Time.get_ticks_usec() - t0 >= hold_us:
			Input.parse_input_event(_event(spec, true))
			injected = true
		await RenderingServer.frame_post_draw
		var t := Time.get_ticks_usec()
		grabs.append({"t": t, "img": root.get_texture().get_image(), "cues": _cues() - cue0})
	if press:
		Input.parse_input_event(_event(spec, false))
	var inject_t0 := t0 + hold_us
	var frames: Array = []
	var prev: Image = small_before
	var after: Image = null
	for g in grabs:
		var now_small := _small(g["img"])
		var px := differing_pixels(now_small, prev, DIFFER)
		prev = now_small
		# A frame stamped before the press was meant to land cannot be its answer (the plant's hold).
		var live: bool = not press or g["t"] >= inject_t0
		frames.append({"t": g["t"], "px": px if live else 0, "cues": g["cues"] if live else 0})
		if after == null and live and (px >= _min_px or int(g["cues"]) > 0):
			after = g["img"]
	var gap := 0
	var last_t := t0
	for g in grabs:
		gap = maxi(gap, int(g["t"]) - last_t)
		last_t = int(g["t"])
	var rows: Array = []
	if _audio() != null:
		rows = _audio().cue_log.slice(cue0)
	var result := {"answered": false, "us": -1, "by": "none", "frame": -1}
	if press:
		result = first_change(t0, frames, _min_px)
		result["gap_us"] = gap
		if result["answered"]:
			result["cue"] = str(rows[0][1]) if not rows.is_empty() else ""
	return {"frames": frames, "result": result, "before": before, "after": after if after != null else before}


# The ball is held on the ground by the physics body's freeze (see _rest_ball); a window frees it at rest.
func _let_go() -> void:
	if game == null or game.test_mode == false or game.player == null:
		return
	var body = game.player.body()
	if body != null and body.freeze:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		if body.has_method("set_velocity_now"):
			body.set_velocity_now(Vector3.ZERO)
		body.freeze = false


func _small(img: Image) -> Image:
	var s := img.duplicate() as Image
	s.convert(Image.FORMAT_RGB8)
	s.resize(SMALL.x, SMALL.y, Image.INTERPOLATE_LANCZOS)
	return s
