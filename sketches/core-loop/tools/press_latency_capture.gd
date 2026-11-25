extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Augments := preload("res://src/movement/augments.gd")

const SIZE := Vector2i(1280, 720)
const SMALL := Vector2i(256, 144)
const LINE_MS := 100.0
const DIFFER := 8
const MIN_PX := 60
const MENU_MIN_PX := 300
const TRIALS := 5
const MAX_WINDOW_FRAMES := 240
const WINDOW_US := 125000
const PLANT_HOLD_US := 150000
const PLANT_CASE := "jump"
const FRAME_US := 16000
const LANDED := 1.6
const REST_FRAMES := 90
const RETRIES := 3

const MENU_CASES := ["title_move", "help_open", "help_back", "title_to_pilots", "pilots_back", "pilot_move", "pilot_confirm"]
const VERBS := [
	{"name": "roll", "kind": "key", "code": KEY_W},
	{"name": "jump", "kind": "key", "code": KEY_SPACE},
	{"name": "boost", "kind": "key", "code": KEY_SHIFT},
	{"name": "fire", "kind": "mouse", "code": MOUSE_BUTTON_LEFT},
	{"name": "harpoon", "kind": "mouse", "code": MOUSE_BUTTON_RIGHT},
	{"name": "haul", "kind": "key", "code": KEY_CTRL, "context": "no line out, ball at rest: Ctrl is the brake"},
	{"name": "interact", "kind": "key", "code": KEY_E, "context": "nothing in reach to mount or take"},
	{"name": "slot2", "kind": "key", "code": KEY_2},
	{"name": "ultimate", "kind": "key", "code": KEY_Q},
	{"name": "active", "kind": "key", "code": KEY_F},
	{"name": "pause", "kind": "key", "code": KEY_P},
	{"name": "haul_line", "kind": "key", "code": KEY_CTRL, "line": "world", "context": "a line out on a world point: Ctrl winches"},
	{"name": "reel_body", "kind": "key", "code": KEY_CTRL, "line": "body", "context": "a line out on a held chaser: Ctrl commits the haul onto it"},
	{"name": "dunk", "kind": "key", "code": KEY_CTRL, "line": "dunk", "context": "a line out on a held chaser with a dunk charge stored: Ctrl hauls it home"},
]
const LINE_REACH := 10.0
const LINE_RISE := 3.0
const DUNK_DAMAGE := 30.0

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
var _dead := false
var _pilot := ""
var _target: Node3D = null


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


static func window_open(elapsed_us: int, frames: int, window_us: int, hold_us: int) -> bool:
	return elapsed_us < window_us + hold_us and frames < MAX_WINDOW_FRAMES


static func sounds_started(rows: Array) -> Array:
	var out_rows: Array = []
	for r in rows:
		if r is Array and r.size() > 2 and str(r[2]) == "now":
			out_rows.append(r)
	return out_rows


static func unknown_cases(names: Array) -> Array:
	var known: Array = MENU_CASES.duplicate()
	for v in VERBS:
		known.append(v["name"])
	return names.filter(func(n): return not known.has(n))


static func scratch_user_dir(user_dir: String, repo_root: String) -> bool:
	var scratch := repo_root.simplify_path().path_join("artifacts/local") + "/"
	return (user_dir.simplify_path() + "/").begins_with(scratch)


static func false_changes(frames: Array, min_px: int) -> int:
	var n := 0
	for f in frames:
		if int(f["px"]) >= min_px or int(f["cues"]) > 0:
			n += 1
	return n


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
	var unknown := unknown_cases(only)
	if not unknown.is_empty():
		printerr("press_latency: unknown case %s; cases are %s and the verbs" % [", ".join(PackedStringArray(unknown)), ", ".join(PackedStringArray(MENU_CASES))])
		quit(2)
		return
	var repo := ProjectSettings.globalize_path("res://").path_join("../..")
	if not scratch_user_dir(OS.get_user_data_dir(), repo):
		printerr("press_latency: the user data folder %s is not under %s; the menu cases write the profile, so set HOME and XDG_DATA_HOME to a folder there" % [OS.get_user_data_dir(), repo.simplify_path().path_join("artifacts/local")])
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
	if (part == "verbs" or part == "all") and VERBS.any(func(v): return _wanted(v["name"])):
		await _verbs()
	if (part == "menu" or part == "all") and MENU_CASES.any(func(n): return _wanted(n)) and not _dead:
		await _menu()
	_finish()


func _die(why: String) -> void:
	if _dead:
		return
	_dead = true
	printerr("press_latency: " + why)
	quit(2)


func _finish() -> void:
	if _dead:
		return
	var failed := 0
	var false_total := 0
	var plant_pass := true
	var plant_case := {}
	var flagged := 0
	for c in cases:
		c["flagged"] = int(c.get("control_windows_not_still", 0)) > 0
		if c["flagged"]:
			flagged += 1
		if not c["pass"]:
			failed += 1
		false_total += int(c["false_changes"])
		if plant != "" and c["name"] == PLANT_CASE:
			plant_pass = c["pass"]
			plant_case = c
	var verdict := "pass" if cases.size() > 0 and failed == 0 else "fail"
	var code := 0 if verdict == "pass" else 1
	if plant == "slow":
		verdict = "pass" if plant_pass else "fail"
		code = 3 if false_total > 0 else (0 if plant_pass else 1)
	var head: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], head)
	var f := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"tool": "press_latency_capture.gd", "head": String(head[0]).strip_edges() if head.size() > 0 else "",
		"principle": "P5: A press shows on screen or in sound within 100 ms", "scope": "engine-side latency; display scan-out and the OS input stack are not included",
		"plant": plant, "adapter": _adapter, "size": [SIZE.x, SIZE.y], "line_ms": LINE_MS, "differ": DIFFER, "min_px_verbs": MIN_PX, "min_px_menu": MENU_MIN_PX,
		"compare_size": [SMALL.x, SMALL.y], "window_us": WINDOW_US, "trials": trials, "cases_run": cases.size(), "cases_failed": failed,
		"false_changes": false_total, "cases_flagged": flagged, "pilot": _pilot, "verdict": verdict, "cases": cases}, "\t"))
	f.close()
	for c in cases:
		print("press_latency: %-16s n=%d answered=%d unanswered=%d median=%s worst=%s by=%s false=%d not_still=%d/%d -> %s%s" % [c["name"], c["n"], c["answered"], c["unanswered"],
			c["median_ms"], c["worst_ms"], c["by"], c["false_changes"], c["control_windows_not_still"], c["control_windows"], "pass" if c["pass"] else "FAIL", ", FLAGGED" if c["flagged"] else ""])
	if plant == "slow" and not plant_case.is_empty():
		var how: String = "unanswered in %d of %d presses" % [plant_case["unanswered"], plant_case["n"]] if int(plant_case["unanswered"]) > 0 \
			else "answered late, worst %s ms" % plant_case["worst_ms"]
		print("press_latency: plant %s %s" % [PLANT_CASE, how])
	print("press_latency: plant=%s cases %d, failed %d, flagged %d, false changes %d -> %s" % [plant, cases.size(), failed, flagged, false_total, verdict])
	quit(code)


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
	return a.cue_log_total if a != null else 0


func _started_since(from: int) -> Array:
	var a = _audio()
	return sounds_started(a.cues_since(from)) if a != null else []


func _verbs() -> void:
	_min_px = MIN_PX
	await _boot_game(false)
	game.ctx.calm = true
	game.flow.press_start()
	_pilot = str(game.flow.classes[0].display_name)
	game.flow.choose_class(0)
	var keyboard := Intent.Keyboard.new()
	game.player.source = keyboard
	game.flow.enter_stage(1, Vector3.ZERO, false)
	game.run.set_max_hp(999999.0)
	await _frames(60)
	var wait := 0
	while game.hud.launch_card.showing() and wait < 900:
		wait += 1
		await physics_frame
	game.hud.key_glyphs.visible = false
	game.hud.first_steps.visible = false
	await _frames(600)
	for spec in VERBS:
		if _wanted(spec["name"]):
			var settle := Callable(self, "_rest_ball") if not spec.has("line") else Callable(self, "_rest_with_line").bind(String(spec["line"]))
			await _case(spec, "verbs", settle)
			await _clear_line()
	await _drop_game()


func _rest_ball() -> bool:
	var body = game.player.body()
	if _rest_pose != Transform3D():
		for k in 2:
			body.freeze = true
			body.global_transform = _rest_pose
			await _frames(REST_FRAMES)
			if k == 0:
				_let_go()
				await _frames(8)
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
			return await _rest_ball()
	return false


func _rest_with_line(line: String) -> bool:
	await _clear_line()
	var ball: Vector3 = game.player.ball_position()
	var cam = game.camera.cam if game.camera != null else null
	var ahead: Vector3 = (-cam.global_basis.z if cam != null else Vector3.FORWARD) * Vector3(1.0, 0.0, 1.0)
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	var point := ball + ahead * LINE_REACH + Vector3.UP * LINE_RISE
	var kit = game.player.kit
	if line == "world":
		Augments.attach(kit, ball, point, -ahead)
	else:
		_target = game.ctx.spawner.spawn_enemy("chaser", ball + ahead * LINE_REACH)
		if _target == null:
			_die("spawn_enemy gave no chaser; the body-line cases have nothing to bite")
			return false
		_target.process_mode = Node.PROCESS_MODE_DISABLED
		Augments.attach(kit, ball, _target.global_position, -ahead, _target)
	game.run.heal(INF)
	var rested: bool = await _rest_ball()
	if line == "dunk":
		game.player.dunk.store(DUNK_DAMAGE, "slam", _pilot, Color.WHITE)
		await _frames(10)
	return rested


func _clear_line() -> void:
	if game != null and game.player != null:
		game.player.kit.drop_line()
		game.player.dunk.clear("reset")
	if is_instance_valid(_target):
		_target.queue_free()
	_target = null
	await _frames(4)


func _menu() -> void:
	_min_px = MENU_MIN_PX
	await _boot_menu()
	if _wanted("title_move"):
		await _case({"name": "title_move", "kind": "key", "code": KEY_RIGHT}, "menu", Callable(self, "_focus_play"))
	if _wanted("help_open"):
		await _case({"name": "help_open", "kind": "key", "code": KEY_H, "undo": KEY_ESCAPE}, "menu", Callable(self, "_title_idle"))
	if _wanted("help_back"):
		await _case({"name": "help_back", "kind": "key", "code": KEY_ESCAPE, "setup_key": KEY_H}, "menu", Callable(self, "_title_idle"))
	if _wanted("title_to_pilots"):
		await _case({"name": "title_to_pilots", "kind": "key", "code": KEY_SPACE, "undo": KEY_ESCAPE}, "menu", Callable(self, "_title_idle"))
	if _wanted("pilots_back"):
		await _case({"name": "pilots_back", "kind": "key", "code": KEY_ESCAPE, "setup_key": KEY_SPACE}, "menu", Callable(self, "_title_idle"))
	if _wanted("pilot_move"):
		await _pilot_move_case()
	await _drop_game()
	if _wanted("pilot_confirm"):
		await _pilot_confirm_case()


func _boot_menu() -> void:
	await _boot_game(true)
	game.screens.prologue_enabled = false
	await _wait_title()


func _wait_title() -> void:
	var guard := 0
	while guard < 3600:
		if game.presentation != null and not "title_stage" in game.presentation:
			_die("presentation has no title_stage; the tool cannot tell when the title intro ends")
			return
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


func _pilot_confirm_case() -> void:
	_min_px = MENU_MIN_PX
	var results: Array = []
	var controls: Array = []
	var keep := {}
	var windows := 0
	var noisy := 0
	for i in trials:
		await _boot_menu()
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
		var tries := 0
		windows += 1
		while false_changes(control["frames"], _min_px) > 0 and tries < RETRIES:
			tries += 1
			noisy += 1
			windows += 1
			await _frames(30)
			control = await _window(spec, false, 0)
		controls.append(false_changes(control["frames"], _min_px))
		var trial := await _window(spec, true, 0)
		results.append(trial["result"])
		_keep_worst(keep, trial)
		await _drop_game()
	_add_case("pilot_confirm", "menu", results, controls, keep, windows, noisy)


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
	cases[-1]["context"] = spec.get("context", "")


func _dead_case(name: String, group: String, why: String) -> Dictionary:
	return {"name": name, "group": group, "n": 0, "answered": 0, "unanswered": 0, "median_ms": null, "worst_ms": null, "by": "none",
		"control_trials": 0, "control_windows": 0, "control_windows_not_still": 0, "false_changes": 0, "pass": false, "why": why, "samples_ms": [], "frames": []}


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


func _window(spec: Dictionary, press: bool, hold_us: int) -> Dictionary:
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	var small_before := _small(before)
	var cue0 := _cues()
	var wait_until := Time.get_ticks_usec() + randi() % FRAME_US
	while Time.get_ticks_usec() < wait_until:
		pass
	var t0 := Time.get_ticks_usec()
	if not spec.has("line"):
		_let_go()
	var grabs: Array = []
	var injected := not press
	while window_open(Time.get_ticks_usec() - t0, grabs.size(), WINDOW_US, hold_us):
		if press and not injected and Time.get_ticks_usec() - t0 >= hold_us:
			Input.parse_input_event(_event(spec, true))
			injected = true
		await RenderingServer.frame_post_draw
		var t := Time.get_ticks_usec()
		grabs.append({"t": t, "img": root.get_texture().get_image(), "cues": _started_since(cue0).size()})
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
	var logged: Array = []
	if _audio() != null:
		rows = _started_since(cue0)
		for r in _audio().cues_since(cue0).slice(0, 8):
			logged.append([str(r[1]), str(r[2])] if r is Array and r.size() > 2 else [str(r), ""])
	var result := {"answered": false, "us": -1, "by": "none", "frame": -1}
	if press:
		result = first_change(t0, frames, _min_px)
		result["gap_us"] = gap
		result["cue_rows"] = logged
		if result["answered"]:
			result["cue"] = str(rows[0][1]) if not rows.is_empty() else ""
	return {"frames": frames, "result": result, "before": before, "after": after if after != null else before}


func _let_go() -> void:
	if game == null or game.test_mode == false or game.player == null:
		return
	var body = game.player.body()
	if body != null and body.freeze:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		if not body.has_method("set_velocity_now"):
			_die("the player body has no set_velocity_now; the tool cannot let the held ball go from rest")
			return
		body.set_velocity_now(Vector3.ZERO)
		body.freeze = false


func _small(img: Image) -> Image:
	var s := img.duplicate() as Image
	s.convert(Image.FORMAT_RGB8)
	s.resize(SMALL.x, SMALL.y, Image.INTERPOLATE_LANCZOS)
	return s
