extends SceneTree

# JL-17: the runner's tick contract, in process. Each trial runs jev_run.gd's Trial
# on its own lab and World3D, exactly as the runner does, and a responder answers
# every snapshot with the first offered option.
#
# Delay patterns. `none` answers between ticks, as soon as the state is written, so
# the runner never blocks. `short` and `long` answer only while the runner blocks at
# t + k, after a seeded random wait, so every intent blocks. Each intent must apply
# at exactly state.tick + k, and trace_hash must be the same for all three patterns
# in each physics mode. A rigid (Jolt) divergence is reported as stochastic, not
# failed (plan section 2, "Determinism").
#
# Endings. No answer within intent_timeout_s is error intent_timeout at the
# blocking tick (exit 5); an intent that is not offered is intent_invalid (exit 4);
# abort.json while blocking is done{aborted} (exit 0). The real process and its exit
# codes are covered by tests/lab-bridge.test.js.
#
# Trials are written to artifacts/local/jev-bridge-test/ unless `-- --out=<dir>`.

const Lab := preload("res://src/lab.gd")
const JevIO := preload("res://src/jev/jev_io.gd")
const JevRun := preload("res://src/jev/jev_run.gd")

const D := 90
const K := 26
const MAX_TICKS := 5 * D
const SEED := 7
const MODES := ["kinematic", "rigid"]
# Wait before answering, in ms, drawn per intent: [least, most].
const PATTERNS := {"none": [], "short": [0, 15], "long": [20, 60]}


class Responder:
	extends RefCounted

	var io
	var pattern: Array
	var rng := RandomNumberGenerator.new()
	var mode := "answer"
	var answered := {}
	var _due := {}

	func _init(io_ref, pattern_ref: Array, seed_value: int, mode_ref := "answer") -> void:
		io = io_ref
		pattern = pattern_ref
		rng.seed = seed_value
		mode = mode_ref

	# Between ticks: only the `none` pattern answers here.
	func between_ticks() -> void:
		if pattern.is_empty() and mode == "answer":
			_answer_all()

	# While the runner blocks for `seq`.
	func waiting(seq: int) -> void:
		match mode:
			"silent":
				return
			"abort":
				_put("abort.json", {"protocol": JevIO.PROTOCOL, "reason": "interrupted"})
				return
		if not _due.has(seq):
			var wait := 0 if pattern.is_empty() else rng.randi_range(pattern[0], pattern[1])
			_due[seq] = Time.get_ticks_msec() + wait
		if Time.get_ticks_msec() >= _due[seq]:
			_answer_all()

	func _answer_all() -> void:
		var seq := 0
		while FileAccess.file_exists(io.dir.path_join("state-%06d.json" % seq)):
			if not answered.has(seq):
				_answer(seq)
			seq += 1

	func _answer(seq: int) -> void:
		var state = JSON.parse_string(FileAccess.get_file_as_string(io.dir.path_join("state-%06d.json" % seq)))
		var offered := JevIO.offered_options(state["jev"])
		var intent := {
			"protocol": JevIO.PROTOCOL,
			"seq": seq,
			"intent": offered[0],
			"arm": "scripted",
			"source": "forced" if offered.size() == 1 else "rule",
			"meta": {"rule": "first-offered"},
		}
		if mode == "invalid":
			intent["intent"] = "take_cache"
			intent["source"] = "rule"
		_put("intent-%06d.json" % seq, intent)
		answered[seq] = true

	# Node's side of the protocol: tmp-then-rename.
	func _put(name: String, message: Dictionary) -> void:
		var path: String = io.dir.path_join(name)
		var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
		file.store_string(JevIO.stringify(message) + "\n")
		file.close()
		DirAccess.rename_absolute(path + ".tmp", path)


var _out := ""
var _cases := []
var _started := false
var _failures := 0


func _initialize() -> void:
	_out = _out_dir()
	var n := 0
	for mode in MODES:
		for pattern in PATTERNS:
			_cases.append(_case(mode, pattern, "answer", 30, 1000 + n))
			n += 1
	_cases.append(_case("kinematic", "none", "silent", 1, 0, "timeout"))
	_cases.append(_case("kinematic", "none", "invalid", 30, 0, "invalid"))
	_cases.append(_case("kinematic", "none", "abort", 30, 0, "abort"))


func _case(mode: String, pattern: String, respond: String, timeout_s: int, rng_seed: int, name := "") -> Dictionary:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var lab = Lab.new()
	lab.test_mode = true
	viewport.add_child(lab)
	var label := name if name != "" else pattern
	return {"mode": mode, "pattern": pattern, "respond": respond, "timeout_s": timeout_s, "rng_seed": rng_seed,
		"label": label, "viewport": viewport, "lab": lab, "dir": _out.path_join(mode).path_join(label), "done": false}


func _physics_process(_delta: float) -> bool:
	if not _started:
		for c in _cases:
			if c["lab"].player == null:
				return false
		for c in _cases:
			_begin(c)
		_started = true
		return false
	var running := 0
	for c in _cases:
		if c["done"]:
			continue
		if c["trial"].tick():
			_end(c)
			continue
		c["responder"].between_ticks()
		running += 1
	if running > 0:
		return false
	_finish()
	return true


func _begin(c: Dictionary) -> void:
	_reset(c["dir"])
	var trial = JevRun.Trial.new(c["lab"], {
		"io": c["dir"],
		"scenario": "downhill-run",
		"seed": SEED,
		"mode": c["mode"],
		"snapshot_every": D,
		"hold_ticks": K,
		"intent_timeout_s": c["timeout_s"],
		"max_ticks": MAX_TICKS,
	})
	var responder := Responder.new(trial.io, PATTERNS[c["pattern"]], c["rng_seed"], c["respond"])
	trial.on_wait = responder.waiting
	c["trial"] = trial
	c["responder"] = responder
	if not trial.begin():
		_end(c)


func _end(c: Dictionary) -> void:
	c["done"] = true
	c["trial"].close()
	c["viewport"].queue_free()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _finish() -> void:
	var hashes := {}
	for c in _cases:
		match c["respond"]:
			"answer":
				_check_answered(c, hashes)
			"silent":
				_check_error(c, "intent_timeout", 5)
			"invalid":
				_check_error(c, "intent_invalid", 4)
			"abort":
				var done = _json(c["dir"].path_join("done.json"))
				var ok: bool = c["trial"].outcome == "aborted" and c["trial"].exit_code == 0 \
					and done is Dictionary and done["reason"] == "aborted" and done["tick"] == K
				_report("abort", ok, "abort.json while blocked at tick %d: outcome %s, exit %d, done %s"
					% [K, c["trial"].outcome, c["trial"].exit_code, JSON.stringify(done)])
	for mode in MODES:
		var seen: Dictionary = hashes[mode]
		var distinct := {}
		for pattern in seen:
			distinct[seen[pattern]] = true
		var detail := "%s trace_hash over %s: %d distinct" % [mode, ", ".join(seen.keys()), distinct.size()]
		if distinct.size() == 1:
			_report("determinism", true, detail)
		elif mode == "rigid":
			print("[determinism] %s; rigid (Jolt) is STOCHASTIC here, reported and not failed" % detail)
		else:
			_report("determinism", false, detail + " " + JSON.stringify(seen))
	print("jev_bridge_test: %s (trials under %s)" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures, _out])
	quit(0 if _failures == 0 else 1)


func _check_answered(c: Dictionary, hashes: Dictionary) -> void:
	var trial = c["trial"]
	var label := "%s/%s" % [c["mode"], c["pattern"]]
	var text := FileAccess.get_file_as_string(c["dir"].path_join(JevIO.EVENTS_FILE))
	var invalid := JevIO.validate_events(text)
	var late := []
	var intents := 0
	for line in text.split("\n", false):
		var event = JSON.parse_string(line)
		if event["kind"] == "intent":
			intents += 1
			if int(event["tick"]) != int(event["seq"]) * D + K:
				late.append("%d@%d" % [int(event["seq"]), int(event["tick"])])
	var done = _json(c["dir"].path_join("done.json"))
	var want_blocked: int = 0 if c["pattern"] == "none" else intents
	var ok: bool = trial.outcome == "complete" and trial.exit_code == 0 and invalid.is_empty() and late.is_empty() \
		and intents >= 1 and intents == trial.applied and trial.blocked == want_blocked and done is Dictionary
	_report("tick contract", ok, "%s: %s, %d intents all at seq*%d+%d%s, blocked %d, events valid %s"
		% [label, trial.outcome, intents, D, K, "" if late.is_empty() else " except " + ", ".join(late),
		trial.blocked, str(invalid.is_empty())])
	if not hashes.has(c["mode"]):
		hashes[c["mode"]] = {}
	hashes[c["mode"]][c["pattern"]] = done["trace_hash"] if done is Dictionary else "none"


func _check_error(c: Dictionary, code: String, exit_code: int) -> void:
	var trial = c["trial"]
	var error = _json(c["dir"].path_join("error.json"))
	var ok: bool = trial.outcome == code and trial.exit_code == exit_code and error is Dictionary \
		and error["code"] == code and int(error["seq"]) == 0 and int(error["tick"]) == K \
		and not FileAccess.file_exists(c["dir"].path_join("done.json"))
	_report(code, ok, "%s: outcome %s, exit %d, error.json %s" % [c["label"], trial.outcome, trial.exit_code, JSON.stringify(error)])


func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _out_dir() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return ProjectSettings.globalize_path(arg.trim_prefix("--out="))
	return ProjectSettings.globalize_path("res://").path_join("../../artifacts/local/jev-bridge-test").simplify_path()


func _reset(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for name in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(name))
