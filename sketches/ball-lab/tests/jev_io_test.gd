extends SceneTree

# Protocol v1 I/O: the validators agree with protocol.mjs on every fixture in
# INDEX.json, the writer reproduces Node's bytes, and the reader honours the
# file rules. Written trials go to artifacts/local/jev-io-test/ unless
# `-- --out=<dir>` names another directory.

const JevIO := preload("res://src/jev/jev_io.gd")
const FIXTURES := "res://src/jev/fixtures/"

var _failures := 0


func _initialize() -> void:
	_check_fixtures()
	_check_stringify()
	_check_event_lines()
	var out := _out_dir()
	_check_complete_trial(out.path_join("complete"))
	_check_timeout_trial(out.path_join("timeout"))
	_check_internal_error(out.path_join("internal"))
	_check_reading(out.path_join("reading"))
	print("jev_io_test: %s (written trials under %s)" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures, out])
	quit(0 if _failures == 0 else 1)


func _check_fixtures() -> void:
	var index = _json("INDEX.json")
	var accepted := 0
	var rejected := 0
	for entry in index.fixtures:
		var paths := _validate(entry).map(func(error): return error.path)
		if entry.valid:
			_expect(paths.is_empty(), "%s should be valid; got %s" % [entry.file, paths])
			accepted += 1 if paths.is_empty() else 0
		else:
			_expect(paths == [entry.path], "%s should fail only at %s; got %s" % [entry.file, entry.path, paths])
			rejected += 1 if paths == [entry.path] else 0
	var valid: int = index.fixtures.filter(func(entry): return entry.valid).size()
	var invalid: int = index.fixtures.size() - valid
	print("jev_io_test: %d/%d valid fixtures accepted, %d/%d invalid rejected at the indexed path" % [accepted, valid, rejected, invalid])


func _validate(entry: Dictionary) -> Array:
	if entry.type == "events":
		return JevIO.validate_events(_text(entry.file))
	var message = _json(entry.file)
	match entry.type:
		"hello":
			return JevIO.validate_hello(message)
		"state":
			return JevIO.validate_state(message)
		"intent":
			return JevIO.validate_intent(message, _json(entry.context) if entry.has("context") else null)
		"error":
			return JevIO.validate_error(message)
		"abort":
			return JevIO.validate_abort(message)
		"done":
			return JevIO.validate_done(message)
	_expect(false, "%s has unknown type %s" % [entry.file, entry.type])
	return []


# Expected text is what Node's JSON.stringify prints for the same double. Cases
# are ones where Godot's digits are also the shortest; see jev_io.gd _number().
func _check_stringify() -> void:
	var cases := [
		[0.1 + 0.2, "0.30000000000000004"],
		[5.0, "5"],
		[-0.0, "0"],
		[7, "7"],
		[12.3, "12.3"],
		[-11.34, "-11.34"],
		[1.0 / 3.0, "0.3333333333333333"],
		[123456789.125, "123456789.125"],
		[1e20, "100000000000000000000"],
		[1e21, "1e+21"],
		[-1e22, "-1e+22"],
		[1e-6, "0.000001"],
		[1e-7, "1e-7"],
		[2.5e-5, "0.000025"],
		[-1.5e-10, "-1.5e-10"],
		[INF, "null"],
		[NAN, "null"],
		[{"a": [1.0, 2.5, "q\"\\\n\t\u0001é"], "b": null, "c": true}, "{\"a\":[1,2.5,\"q\\\"\\\\\\n\\t\\u0001é\"],\"b\":null,\"c\":true}"],
	]
	for case in cases:
		var text = JevIO.stringify(case[0])
		_expect(text == case[1], "stringify(%s) is %s, want %s" % [case[0], text, case[1]])
	_expect(JevIO.stringify({"pos": Vector3.ZERO}) == null, "stringify refuses a Vector3")


# Every NDJSON line in the fixtures was printed by Node's JSON.stringify; the
# writer must print the same bytes, or trace_hash would differ between them.
func _check_event_lines() -> void:
	var files := {}
	var index = _json("INDEX.json")
	for entry in index.fixtures:
		if entry.file.ends_with(".ndjson"):
			files[entry.file] = true
	var lines := 0
	for file in files:
		for line in _text(file).trim_suffix("\n").split("\n"):
			if line == "":
				continue
			var again = JevIO.stringify(JSON.parse_string(line))
			_expect(again == line, "%s: %s reprints as %s" % [file, line, again])
			lines += 1
	_expect(lines > 0, "found event lines to reprint")


# Replays trial-complete through the writer, with the test playing Node's part
# by placing each intent file, and compares the result to the fixture.
func _check_complete_trial(dir: String) -> void:
	_reset(dir)
	var io := JevIO.new(dir)
	_expect_ok(io.write_hello(_body("trial-complete/hello.json")), "write hello")
	for seq in 2:
		_expect_ok(io.write_state(_body("trial-complete/state-%06d.json" % seq)), "write state %d" % seq)
		_place("trial-complete/intent-%06d.json" % seq, dir)
	for line in _text("trial-complete/events.ndjson").trim_suffix("\n").split("\n"):
		_expect_ok(io.append_event(JSON.parse_string(line)), "append %s" % line)
	_expect(FileAccess.file_exists(dir.path_join("events.ndjson.tmp")), "events stay in events.ndjson.tmp during the trial")
	_expect(not FileAccess.file_exists(dir.path_join("events.ndjson")), "events.ndjson appears only at the end")
	_expect_ok(io.write_done("complete", 135, 2), "write done")
	_expect(
		FileAccess.get_file_as_bytes(dir.path_join("events.ndjson")) == FileAccess.get_file_as_bytes(FIXTURES + "trial-complete/events.ndjson"),
		"events.ndjson matches the fixture byte for byte"
	)
	var done = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("done.json")))
	_expect(done.trace_hash == _json("trial-complete/done.json").trace_hash, "trace_hash matches the fixture's")
	_expect_files(dir, ["done.json", "events.ndjson", "hello.json", "intent-000000.json", "intent-000001.json", "state-000000.json", "state-000001.json"])
	_expect_valid(dir, "hello.json", JevIO.validate_hello)
	_expect_valid(dir, "state-000000.json", JevIO.validate_state)
	_expect_valid(dir, "state-000001.json", JevIO.validate_state)
	_expect_valid(dir, "done.json", JevIO.validate_done)
	var line := FileAccess.get_file_as_string(dir.path_join("state-000001.json"))
	_expect(line.count("\n") == 1 and line.ends_with("\n"), "a state file is one LF-terminated line")
	_expect(not line.contains(".0,") and not line.contains(".0]") and not line.contains(".0}"), "whole numbers carry no .0")
	_expect(not io.write_error("internal", null, 135, "late").is_empty(), "no error.json after done.json")
	_expect(not io.append_event({"tick": 136, "kind": "landing"}).is_empty(), "no event after done.json")
	_expect(not FileAccess.file_exists(dir.path_join("error.json")), "error.json never sits beside done.json")


func _check_timeout_trial(dir: String) -> void:
	_reset(dir)
	var io := JevIO.new(dir)
	_expect_ok(io.write_hello(_body("trial-timeout/hello.json")), "write hello")
	_expect_ok(io.write_state(_body("trial-timeout/state-000000.json")), "write state 0")
	for line in _text("trial-timeout/events.ndjson").trim_suffix("\n").split("\n"):
		_expect_ok(io.append_event(JSON.parse_string(line)), "append %s" % line)
	_expect_ok(io.write_error("intent_timeout", 0, 26, "no intent-000000.json 30 s after blocking"), "write error")
	_expect_files(dir, ["error.json", "events.ndjson", "hello.json", "state-000000.json"])
	_expect_valid(dir, "error.json", JevIO.validate_error)
	_expect(not io.write_done("complete", 26, 1).is_empty(), "no done.json after error.json")


func _check_internal_error(dir: String) -> void:
	_reset(dir)
	var io := JevIO.new(dir)
	_expect_ok(io.write_hello(_body("trial-timeout/hello.json")), "write hello")
	_expect_ok(io.write_error("internal", null, 0, "the stage failed to load"), "write error with no snapshot")
	_expect_files(dir, ["error.json", "events.ndjson", "hello.json"])
	_expect(FileAccess.get_file_as_bytes(dir.path_join("events.ndjson")).is_empty(), "no events leaves an empty events.ndjson")


func _check_reading(dir: String) -> void:
	_reset(dir)
	var io := JevIO.new(dir)
	var state = _json("trial-complete/state-000000.json")
	var intent := dir.path_join("intent-000000.json")
	_expect(io.read_intent(0, state).status == JevIO.Read.ABSENT, "no intent yet")
	_write(intent + ".tmp", _text("valid/intent-random.json"))
	_expect(io.read_intent(0, state).status == JevIO.Read.ABSENT, "intent-000000.json.tmp is ignored")
	_write(intent, _text("valid/intent-random.json"))
	var read := io.read_intent(0, state)
	_expect(read.status == JevIO.Read.VALID and read.message.intent == "stomp_target", "a valid intent reads back: %s" % read)
	_write(intent, _text("invalid/intent-not-offered.json"))
	_expect_paths(io.read_intent(0, state), ["intent-000000.json:intent"])
	_write(intent, _text("valid/intent-random.json"))
	_expect_paths(io.read_intent(0, _json("trial-complete/state-000001.json")), ["intent-000000.json:seq", "intent-000000.json:intent", "intent-000000.json:source"])
	_write(intent, "{\"protocol\":")
	_expect_paths(io.read_intent(0, state), ["intent-000000.json:(root)"])
	_expect(io.read_abort().status == JevIO.Read.ABSENT, "no abort yet")
	_write(dir.path_join("abort.json"), _text("trial-aborted/abort.json"))
	_expect(io.read_abort().status == JevIO.Read.VALID, "a valid abort reads back")
	_write(dir.path_join("abort.json"), _text("invalid/abort-unknown-reason.json"))
	_expect_paths(io.read_abort(), ["abort.json:reason"])
	var refused := io.write_state(_body("invalid/state-off-grid.json"))
	_expect(refused.map(func(error): return error.path) == ["state.json:jev.state.self.speed_ms"], "an off-grid state is refused: %s" % [refused])
	_expect(not FileAccess.file_exists(dir.path_join("state-000000.json")), "a refused state writes nothing")
	_expect(not io.append_event({"tick": 0, "kind": "trace", "wall_ms": 5}).is_empty(), "an event outside its closed shape is refused")


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)


func _expect_ok(errors: Array, what: String) -> void:
	_expect(errors.is_empty(), "%s: %s" % [what, errors])


func _expect_paths(read: Dictionary, paths: Array) -> void:
	var got: Array = read.errors.map(func(error): return error.path)
	_expect(read.status == JevIO.Read.INVALID and got == paths, "read should fail at %s; got %s" % [paths, read])


func _expect_valid(dir: String, name: String, validator: Callable) -> void:
	var errors: Array = validator.call(JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(name))))
	_expect(errors.is_empty(), "written %s validates: %s" % [name, errors])


# Only finished names: every .tmp has been renamed into place.
func _expect_files(dir: String, names: Array) -> void:
	var files := Array(DirAccess.get_files_at(dir))
	files.sort()
	_expect(files == names, "%s holds %s, want %s" % [dir, files, names])


func _out_dir() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return ProjectSettings.globalize_path(arg.trim_prefix("--out="))
	return ProjectSettings.globalize_path("res://").path_join("../../artifacts/local/jev-io-test").simplify_path()


func _reset(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for name in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(name))


func _place(fixture: String, dir: String) -> void:
	_write(dir.path_join(fixture.get_file()), _text(fixture))


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _text(fixture: String) -> String:
	return FileAccess.get_file_as_string(FIXTURES + fixture)


func _json(fixture: String) -> Variant:
	return JSON.parse_string(_text(fixture))


# A fixture message without its protocol field, which the writer adds.
func _body(fixture: String) -> Dictionary:
	var message: Dictionary = _json(fixture)
	message.erase("protocol")
	return message
