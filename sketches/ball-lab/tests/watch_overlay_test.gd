extends SceneTree

# JL-31: the watch overlay, in process. Two copies of one trial run side by side on
# labs of their own, answered the same way; the second has the overlay attached and
# reads a session.json and a decisions.ndjson written here the way watch.mjs writes
# them. The overlay must leave the trial exactly as it was (same trace_hash, only
# protocol files in the io directory), read every decision line, keep a trail in the
# held intent's colour from the palette, and save a mark with the exact state file,
# the options, the probabilities, the arm, the tick and the note. The runner must
# accept the watch flags and still refuse an unknown one.
#
# Trials are written to artifacts/local/watch-overlay-test/ unless `-- --out=<dir>`.

const Lab := preload("res://src/lab.gd")
const JevIO := preload("res://src/jev/jev_io.gd")
const JevRun := preload("res://src/jev/jev_run.gd")
const Overlay := preload("res://src/jev/watch_overlay.gd")

const D := 90
const K := 26
const MAX_TICKS := 4 * D
const SEED := 7
const MARK_TICK := D + K + 10
const PUSH_HEX := "#4fa3d9"
const PROTOCOL_FILES := ["hello.json", "done.json", "events.ndjson"]

var _out := ""
var _cases := []
var _started := false
var _failures := 0
var _marked := false
var _ticks := 0


func _initialize() -> void:
	_out = _out_dir()
	_check_args()
	_cases.append(_case("plain", false))
	_cases.append(_case("watched", true))


func _case(label: String, watched: bool) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var lab = Lab.new()
	lab.test_mode = true
	viewport.add_child(lab)
	return {"label": label, "watched": watched, "viewport": viewport, "lab": lab,
		"dir": _out.path_join(label).path_join("trials/000"), "done": false, "answered": {}}


func _check_args() -> void:
	var watch := JevRun.Trial.parse_args(PackedStringArray(["--io=/tmp/io", "--scenario=downhill-run",
		"--watch=/tmp/run/watch/000", "--marks=/tmp/marks/r.jsonl", "--shots=300,900", "--mark-at=400"]))
	_report("args", not watch.has("usage") and watch["watch"] == "/tmp/run/watch/000"
		and watch["marks"] == "/tmp/marks/r.jsonl" and watch["shots"] == "300,900" and watch["mark_at"] == 400,
		"the runner accepts --watch, --marks, --shots and --mark-at: %s" % JSON.stringify(watch))
	var headless := JevRun.Trial.parse_args(PackedStringArray(["--io=/tmp/io", "--scenario=downhill-run",
		"--seed=7", "--mode=kinematic", "--snapshot-every=90", "--hold-ticks=26"]))
	var keys := headless.keys()
	keys.sort()
	_report("args", keys == ["hold_ticks", "io", "mode", "scenario", "seed", "snapshot_every"],
		"headless arguments parse to the same keys: %s" % JSON.stringify(keys))
	var unknown := JevRun.Trial.parse_args(PackedStringArray(["--io=/tmp/io", "--overlay=1"]))
	_report("args", unknown.has("usage"), "an unknown option is still refused")
	var bad := JevRun.Trial.parse_args(PackedStringArray(["--io=/tmp/io", "--mark-at=soon"]))
	_report("args", bad.has("usage"), "--mark-at must be a whole number")


func _physics_process(_delta: float) -> bool:
	if not _started:
		for c in _cases:
			if c["lab"].player == null:
				return false
		for c in _cases:
			_begin(c)
		_started = true
		return false
	_ticks += 1
	if _ticks > 4 * MAX_TICKS:
		_report("bound", false, "the trials did not end within %d ticks" % _ticks)
		for c in _cases:
			if not c["done"]:
				_end(c)
	var running := 0
	for c in _cases:
		if c["done"]:
			continue
		if c["trial"].view == null or c["trial"].tick():
			_end(c)
			continue
		_answer(c)
		running += 1
	var watched: Dictionary = _cases[1]
	if not _marked and not watched["done"] and watched["trial"].view.tick >= MARK_TICK:
		watched["overlay"].poll()
		watched["overlay"].begin_mark()
		watched["overlay"].commit_mark("  the ball hesitated before the ramp  ")
		watched["overlay"].begin_mark("left open when the trial ends")
		_marked = true
	if running > 0:
		return false
	_finish()
	return true


func _begin(c: Dictionary) -> void:
	var run_dir: String = _out.path_join(c["label"])
	_reset(run_dir)
	DirAccess.make_dir_recursive_absolute(c["dir"])
	var settings := {
		"io": c["dir"],
		"scenario": "downhill-run",
		"seed": SEED,
		"mode": "kinematic",
		"snapshot_every": D,
		"hold_ticks": K,
		"intent_timeout_s": 5,
		"max_ticks": MAX_TICKS,
	}
	var watch_dir := run_dir.path_join("watch/000")
	if c["watched"]:
		DirAccess.make_dir_recursive_absolute(watch_dir)
		settings["watch"] = watch_dir
		settings["marks"] = run_dir.path_join("marks/test-run.jsonl")
		_write(watch_dir.path_join("session.json"), JSON.stringify(_session(run_dir)))
		_write(watch_dir.path_join("decisions.ndjson"), "")
	var trial = JevRun.Trial.new(c["lab"], settings)
	c["trial"] = trial
	c["watch_dir"] = watch_dir
	if c["watched"]:
		var overlay = Overlay.new()
		root.add_child(overlay)
		overlay.setup(trial, settings)
		c["overlay"] = overlay
	if not trial.begin():
		_end(c)


func _session(run_dir: String) -> Dictionary:
	return {
		"schema": "scrapkeep-watch/1",
		"run_id": "test-run",
		"trial": 0,
		"arm": "scripted",
		"demo": false,
		"label": "watch, not evidence",
		"banner": "WATCH — not evidence",
		"preflight": null,
		"cap": {"session": 60, "preflight_calls": 0, "arm": null},
		"tick_hz": 90,
		"hold_ticks": K,
		"marks": run_dir.path_join("marks/test-run.jsonl"),
		"palette": {
			"intents": {"push_objective": {"word": "push", "hex": PUSH_HEX, "glyph": "→",
				"shape": [[-1, -0.35], [1, 0], [-1, 0.35]]}},
			"sources": {"forced": {"word": "FORCED", "hex": "#3a5563"}, "rule": {"word": "RULE", "hex": "#a9c3c8"}},
			"status": {},
			"watch": {},
			"page": {"panel": "#13212a", "rule": "#1e3440", "bright": "#eaf6f7", "soft": "#a9c3c8"},
		},
	}


# Node's side for both copies: the first offered option, and for the watched copy
# one decisions.ndjson line per answer, as watch.mjs writes it.
func _answer(c: Dictionary) -> void:
	var io = c["trial"].io
	var seq := 0
	while FileAccess.file_exists(io.dir.path_join("state-%06d.json" % seq)):
		if not c["answered"].has(seq):
			var state = JSON.parse_string(FileAccess.get_file_as_string(io.dir.path_join("state-%06d.json" % seq)))
			var offered := JevIO.offered_options(state["jev"])
			_put(io.dir, "intent-%06d.json" % seq, {"protocol": JevIO.PROTOCOL, "seq": seq, "intent": offered[0],
				"arm": "scripted", "source": "forced" if offered.size() == 1 else "rule", "meta": {"rule": "first-offered"}})
			if c["watched"]:
				var line := {"trial": 0, "seq": seq, "tick": int(state["tick"]), "arm": "scripted",
					"kind": "forced" if offered.size() == 1 else "rule", "intent": offered[0],
					"offered": state["jev"]["options"], "gated": [], "probabilities": {offered[0]: 1.0},
					"latency_ms": 0.4, "state": state["jev"]}
				var file := FileAccess.open(c["watch_dir"].path_join("decisions.ndjson"), FileAccess.READ_WRITE)
				file.seek_end()
				file.store_string(JSON.stringify(line) + "\n")
				file.close()
			c["answered"][seq] = true
		seq += 1


func _end(c: Dictionary) -> void:
	c["done"] = true
	if c["watched"]:
		c["overlay"].poll()
		c["overlay"].finish()
	c["trial"].close()


func _finish() -> void:
	var plain: Dictionary = _cases[0]
	var watched: Dictionary = _cases[1]
	var hash_plain = _json(plain["dir"].path_join("done.json")).get("trace_hash", "none")
	var hash_watched = _json(watched["dir"].path_join("done.json")).get("trace_hash", "none")
	_report("trace", hash_plain == hash_watched and hash_plain != "none",
		"the overlay leaves the trial unchanged: trace_hash %s and %s" % [hash_plain, hash_watched])
	_report("trace", plain["trial"].applied > 0 and watched["trial"].applied == plain["trial"].applied,
		"both copies applied %d and %d intents" % [plain["trial"].applied, watched["trial"].applied])
	var extra := []
	for name in DirAccess.get_files_at(watched["dir"]):
		if not (name in PROTOCOL_FILES or name.begins_with("state-") or name.begins_with("intent-")):
			extra.append(name)
	_report("io", extra.is_empty(), "the watched io directory holds only protocol files: extra %s" % JSON.stringify(extra))

	var overlay = watched["overlay"]
	_report("decisions", overlay.decisions.size() == watched["trial"].applied,
		"the overlay read %d decision lines for %d intents" % [overlay.decisions.size(), watched["trial"].applied])
	var colored: bool = not overlay.trail.is_empty()
	for sample in overlay.trail:
		if sample["intent"] == "push_objective" and overlay.intent_look("push_objective")["color"] != Color.html(PUSH_HEX):
			colored = false
	_report("trail", colored and overlay.trail[-1]["intent"] == "push_objective",
		"%d trail samples, coloured from the session palette" % overlay.trail.size())
	_report("ended", overlay.ended.get("result", "") != "" and overlay.pending.is_empty(),
		"finish() shows the result %s and saves the open mark" % overlay.ended.get("result", "none"))

	var marks := _lines(_out.path_join("watched/marks/test-run.jsonl"))
	_report("marks", marks.size() == 2, "two marks saved, got %d" % marks.size())
	if marks.size() == 2:
		var first: Dictionary = marks[0]
		var state_file: Dictionary = first.get("state_file", {})
		var seq := int(first.get("seq", -1))
		var bytes := FileAccess.get_file_as_bytes(watched["dir"].path_join("state-%06d.json" % seq))
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(bytes)
		_report("marks", first["note"] == "the ball hesitated before the ramp" and first["arm"] == "scripted"
			and int(first["tick"]) == MARK_TICK and first["chosen"] == "push_objective"
			and first["options"] is Array and not first["options"].is_empty() and first["probabilities"] is Dictionary,
			"the mark keeps the note, arm, tick, chosen intent, options and probabilities: %s" % JSON.stringify(
				{"note": first.get("note"), "arm": first.get("arm"), "tick": first.get("tick"), "seq": seq}))
		_report("marks", state_file.get("sha256", "") == hashing.finish().hex_encode()
			and int(state_file["message"]["seq"]) == seq,
			"the mark keeps the exact state file %s by sha256" % state_file.get("name", "none"))
		_report("marks", first["live"] is Dictionary and first["live"].has("jev") and first["live"].has("sim"),
			"the mark keeps the live jev and sim blocks at its tick")
		_report("marks", marks[1]["note"] == "left open when the trial ends", "an open mark is saved when the trial ends")
		var raw := FileAccess.get_file_as_string(_out.path_join("watched/marks/test-run.jsonl")).split("\n")[0]
		var top := JSON.stringify({"seq": 1, "trial": 0, "tick": MARK_TICK})
		_report("marks", raw.contains('"seq":1,') and (raw.contains('"trial":0,') or raw.ends_with('"trial":0}'))
			and raw.contains('"tick":%d,' % MARK_TICK) and top == '{"seq":1,"tick":%d,"trial":0}' % MARK_TICK,
			"seq, trial and tick are written as integers")
		_report("marks", int(first["state_tick"]) == D and int(first["hold_ticks"]) == K and first["applied"] == true
			and int(first["tick"]) >= int(first["state_tick"]) + K,
			"state_tick %s and hold %s say which decision drives the ball at the mark (applied %s)" % [
				first.get("state_tick"), first.get("hold_ticks"), first.get("applied")])
		_report("marks", Overlay.repo_relative(ProjectSettings.globalize_path("res://").path_join("../../artifacts/x.png").simplify_path())
			== "artifacts/x.png" and Overlay.repo_relative("/elsewhere/x.png") == "/elsewhere/x.png",
			"paths inside the repository are stored relative to it")
		_report("marks", first["schema"] == "scrapkeep-watch-mark/1" and first["screenshot"] == null,
			"schema scrapkeep-watch-mark/1; no screenshot without a renderer")

	print("watch_overlay_test: %d failures" % _failures)
	for c in _cases:
		c["viewport"].queue_free()
		if c["watched"]:
			c["overlay"].queue_free()
	quit(1 if _failures > 0 else 0)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _lines(path: String) -> Array:
	var out := []
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			out.append(parsed)
	return out


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _put(dir: String, name: String, message: Dictionary) -> void:
	var path := dir.path_join(name)
	_write(path + ".tmp", JevIO.stringify(message) + "\n")
	DirAccess.rename_absolute(path + ".tmp", path)


func _out_dir() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return arg.trim_prefix("--out=")
	return ProjectSettings.globalize_path("res://").path_join("../../artifacts/local/watch-overlay-test").simplify_path()


func _reset(dir: String) -> void:
	if DirAccess.dir_exists_absolute(dir):
		for sub in DirAccess.get_directories_at(dir):
			_reset(dir.path_join(sub))
		for name in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(name))
	DirAccess.make_dir_recursive_absolute(dir)
