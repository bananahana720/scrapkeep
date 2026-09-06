extends SceneTree

## Headless runner for the TADR-004 save-owner proof (cards S0-07 and S0-08).
## Exit 0 when every case passes, 1 on an assertion failure, 2 on an
## environment failure, 3 on a harness error.

const SaveOwner: GDScript = preload("res://proofs/tadr-004/save_owner.gd")

const PROOF: String = "S0-07"
const METHOD: String = "headless fixture run, Linux only"
const PASSES: int = 2
const EXIT_PASS: int = 0
const EXIT_ASSERTION: int = 1
const EXIT_ENVIRONMENT: int = 2
const EXIT_HARNESS: int = 3

const CASES: Array[String] = [
	"commit_path",
	"roundtrip",
	"newer_schema_candidate",
	"newer_schema_committed",
	"interruption_stale",
	"interruption_ambiguous",
	"lifecycle_spent",
	"lifecycle_terminal",
	"converged",
]

const FIXTURES: Dictionary = {
	"newer_schema_committed": "newer-version",
	"interruption_stale": "interruption",
	"interruption_ambiguous": "interruption_ambiguous",
	"lifecycle_spent": "lifecycle",
	"lifecycle_terminal": "lifecycle",
}

var inject_fault: bool = false
var fixtures_dir: String = ""
var run_dir: String = ""
var results: Array[Dictionary] = []
var _failures: PackedStringArray = []
var _notes: PackedStringArray = []


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	inject_fault = args.has("--inject-fault")
	var environment_error: String = prepare_environment()
	if not environment_error.is_empty():
		print("%s environment ERROR %s" % [PROOF, environment_error])
		quit(EXIT_ENVIRONMENT)
		return
	var exit_code: int = EXIT_PASS
	for pass_index: int in range(1, PASSES + 1):
		for case_name: String in CASES:
			var verdict: Dictionary = run_case(case_name, pass_index)
			if verdict.is_empty():
				print("%s harness ERROR no method for case %s" % [PROOF, case_name])
				quit(EXIT_HARNESS)
				return
			results.append(verdict)
			if not verdict["passed"]:
				exit_code = EXIT_ASSERTION
	var idempotent: bool = check_idempotence()
	if not idempotent:
		exit_code = EXIT_ASSERTION
	var summary: Dictionary = build_summary(exit_code, idempotent)
	write_result(summary)
	print("SUMMARY " + JSON.stringify(summary, "", true))
	quit(exit_code)


func prepare_environment() -> String:
	fixtures_dir = ProjectSettings.globalize_path("res://proofs/tadr-004/fixtures")
	if not DirAccess.dir_exists_absolute(fixtures_dir):
		return "fixtures directory missing: " + fixtures_dir
	var run_root: String = OS.get_environment("SCRAPKEEP_PROOF_RUN_ROOT")
	if run_root.is_empty():
		var project_dir: String = ProjectSettings.globalize_path("res://").rstrip("/")
		run_root = project_dir.get_base_dir().path_join("artifacts/local/proofs/tadr-004")
	var stamp: String = Time.get_datetime_string_from_system(true, true).replace("-", "").replace(":", "").replace(" ", "T") + "Z"
	var millis: int = int(Time.get_unix_time_from_system() * 1000.0)
	run_dir = run_root.path_join("run-%s-%d" % [stamp, millis])
	var make_error: Error = DirAccess.make_dir_recursive_absolute(run_dir)
	if make_error != OK:
		return "cannot create run directory %s: %s" % [run_dir, error_string(make_error)]
	var probe_path: String = run_dir.path_join("writable.probe")
	var probe: FileAccess = FileAccess.open(probe_path, FileAccess.WRITE)
	if probe == null:
		return "run directory not writable %s: %s" % [run_dir, error_string(FileAccess.get_open_error())]
	probe.store_string("ok\n")
	probe.close()
	var remove_error: Error = DirAccess.remove_absolute(probe_path)
	if remove_error != OK:
		return "cannot remove probe file %s: %s" % [probe_path, error_string(remove_error)]
	return ""


func run_case(case_name: String, pass_index: int) -> Dictionary:
	var callable: Callable = Callable(self, "case_" + case_name)
	if not callable.is_valid():
		return {}
	var case_root: String = run_dir.path_join("pass%d" % pass_index).path_join(case_name)
	var make_error: Error = DirAccess.make_dir_recursive_absolute(case_root)
	_failures = []
	_notes = []
	if make_error != OK:
		_failures.append("cannot create case directory: " + error_string(make_error))
	else:
		if FIXTURES.has(case_name):
			var fixture_name: String = FIXTURES[case_name]
			copy_fixture(fixture_name, case_root)
		callable.call(case_root)
	var passed: bool = _failures.is_empty()
	var detail: String = ", ".join(_notes) if passed else _failures[0]
	print("%s %s %s pass=%d %s" % [PROOF, case_name, "PASS" if passed else "FAIL", pass_index, detail])
	return {
		"case": case_name,
		"pass": pass_index,
		"passed": passed,
		"detail": detail,
		"failures": Array(_failures),
		"fixture": FIXTURES.get(case_name, ""),
		"root": case_root,
	}


func copy_fixture(fixture_name: String, case_root: String) -> void:
	var source_dir: String = fixtures_dir.path_join(fixture_name)
	if not DirAccess.dir_exists_absolute(source_dir):
		_failures.append("fixture directory missing: " + source_dir)
		return
	for file_name: String in DirAccess.get_files_at(source_dir):
		var copy_error: Error = DirAccess.copy_absolute(source_dir.path_join(file_name), case_root.path_join(file_name))
		if copy_error != OK:
			_failures.append("fixture copy failed for %s: %s" % [file_name, error_string(copy_error)])


func check(condition: bool, detail: String) -> bool:
	if not condition:
		_failures.append(detail)
	return condition


func note(detail: String) -> void:
	_notes.append(detail)


func placeholder_aggregate(generation: int, transaction_id: String, revival_spent: bool = false, terminal: bool = false) -> Dictionary:
	return {
		"schema_version": SaveOwner.SCHEMA_VERSION,
		"content_revision": "placeholder-content-0",
		"generation": generation,
		"transaction_id": transaction_id,
		"profile": {"placeholder": true},
		"run": {
			"checkpoint": {"next_entrance": "placeholder-entrance-%d" % generation},
			"lifecycle": {"revival_spent": revival_spent, "terminal": terminal},
		},
	}


func commit_through_protocol(owner: SaveOwner, aggregate: Dictionary) -> bool:
	var temp: String = owner.stage(aggregate)
	if not check(not temp.is_empty(), "stage returned no temp path"):
		return false
	var validate_error: Error = owner.validate(temp)
	if not check(validate_error == OK, "validate returned " + error_string(validate_error)):
		return false
	var commit_error: Error = owner.commit(temp)
	if not check(commit_error == OK, "commit returned " + error_string(commit_error)):
		return false
	var transaction_id: String = aggregate["transaction_id"]
	owner.acknowledge(transaction_id)
	return check(owner.is_acknowledged(transaction_id), "acknowledge not recorded after commit")


func get_bool(source: Dictionary, key: String) -> bool:
	if typeof(source.get(key)) != TYPE_BOOL:
		return false
	var value: bool = source[key]
	return value


func get_int(source: Dictionary, key: String) -> int:
	if typeof(source.get(key)) != TYPE_INT:
		return -1
	var value: int = source[key]
	return value


func get_string(source: Dictionary, key: String) -> String:
	if typeof(source.get(key)) != TYPE_STRING:
		return ""
	var value: String = source[key]
	return value


func read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func load_fixture_aggregate(owner: SaveOwner, file_name: String) -> Dictionary:
	var read: Dictionary = owner.read_envelope(owner.root.path_join(file_name))
	var read_error: Error = read["error"]
	check(read_error == OK, "fixture %s unreadable: %s" % [file_name, error_string(read_error)])
	return read["aggregate"]


func case_commit_path(case_root: String) -> void:
	var owner: SaveOwner = SaveOwner.new(case_root, inject_fault)
	var save_path: String = owner.save_path()
	var aggregate: Dictionary = placeholder_aggregate(1, "txn-0001")
	var temp: String = owner.stage(aggregate)
	check(not temp.is_empty() and FileAccess.file_exists(temp), "temp file missing after stage")
	check(not FileAccess.file_exists(save_path), "save.json exists before commit")
	var staged_sha: String = FileAccess.get_sha256(temp)
	var staged_text: String = read_text(temp)
	owner.acknowledge("txn-0001")
	check(not owner.is_acknowledged("txn-0001"), "acknowledge accepted before commit")
	var early_commit: Error = owner.commit(temp)
	check(early_commit == ERR_UNCONFIGURED, "commit before validate returned " + error_string(early_commit))
	var validate_error: Error = owner.validate(temp)
	check(validate_error == OK, "validate returned " + error_string(validate_error))
	check(not owner.converged, "first commit reported converged")
	var commit_error: Error = owner.commit(temp)
	check(commit_error == OK, "commit returned " + error_string(commit_error))
	check(FileAccess.file_exists(save_path), "save.json missing after commit")
	check(not FileAccess.file_exists(temp), "temp still present after commit")
	check(FileAccess.get_sha256(save_path) == staged_sha, "save.json sha256 differs from staged bytes")
	check(read_text(save_path) == staged_text, "save.json text differs from staged text")
	owner.acknowledge("txn-0001")
	check(owner.is_acknowledged("txn-0001"), "acknowledge not recorded after commit")
	var recovered: Dictionary = owner.recover()
	check(get_string(recovered, "status") == SaveOwner.STATUS_COMMITTED, "recover status " + str(recovered["status"]))
	note("staged temp validated from re-read bytes, renamed to save.json with identical sha256 %s, acknowledge refused before commit and recorded after" % staged_sha.substr(0, 12))


func case_roundtrip(case_root: String) -> void:
	var owner: SaveOwner = SaveOwner.new(case_root, inject_fault)
	var aggregate: Dictionary = placeholder_aggregate(7, "txn-0007", true, false)
	var text: String = owner.serialize(aggregate)
	var raw: Variant = JSON.parse_string(text)
	check(typeof(raw) == TYPE_DICTIONARY, "raw parse is not a dictionary")
	var raw_dict: Dictionary = raw
	check(typeof(raw_dict.get("generation")) == TYPE_FLOAT, "raw JSON generation is not a float before casting")
	var parsed: Dictionary = owner.parse_envelope(text)
	var parse_error: Error = parsed["error"]
	check(parse_error == OK, "parse_envelope returned " + error_string(parse_error))
	var restored: Dictionary = parsed["aggregate"]
	check(typeof(restored.get("generation")) == TYPE_INT, "restored generation is not an int")
	check(typeof(restored.get("schema_version")) == TYPE_INT, "restored schema_version is not an int")
	check(restored == aggregate, "restored aggregate differs from the original")
	check(owner.serialize(restored) == text, "re-serialized text differs from the original")
	var run: Dictionary = restored["run"]
	var lifecycle: Dictionary = run["lifecycle"]
	check(get_bool(lifecycle, "revival_spent"), "revival_spent lost in round trip")
	note("stringify, parse, int cast at the envelope boundary, deep-equal and byte-equal re-stringify")


func case_newer_schema_candidate(case_root: String) -> void:
	var owner: SaveOwner = SaveOwner.new(case_root, inject_fault)
	if not commit_through_protocol(owner, placeholder_aggregate(1, "txn-0001")):
		return
	var save_path: String = owner.save_path()
	var sha_before: String = FileAccess.get_sha256(save_path)
	var candidate: Dictionary = placeholder_aggregate(2, "txn-0002")
	candidate["schema_version"] = 99
	var temp: String = owner.stage(candidate)
	check(not temp.is_empty(), "stage of the newer candidate failed")
	var validate_error: Error = owner.validate(temp)
	check(validate_error == ERR_UNAVAILABLE, "validate returned %s for schema 99, expected ERR_UNAVAILABLE" % error_string(validate_error))
	var commit_error: Error = owner.commit(temp)
	check(commit_error == ERR_UNCONFIGURED, "commit of a rejected candidate returned " + error_string(commit_error))
	check(FileAccess.get_sha256(save_path) == sha_before, "save.json changed after a rejected candidate")
	check(FileAccess.file_exists(temp), "rejected temp was not preserved")
	note("schema 99 candidate rejected with ERR_UNAVAILABLE, committed sha256 %s unchanged, rejected temp preserved" % sha_before.substr(0, 12))


func case_newer_schema_committed(case_root: String) -> void:
	var owner: SaveOwner = SaveOwner.new(case_root, inject_fault)
	var save_path: String = owner.save_path()
	var sha_before: String = FileAccess.get_sha256(save_path)
	var recovered: Dictionary = owner.recover()
	check(get_string(recovered, "status") == SaveOwner.STATUS_UNSUPPORTED_NEWER, "recover status " + str(recovered["status"]))
	check(not get_bool(recovered, "playable"), "unsupported newer save reported playable")
	var aggregate: Dictionary = recovered["aggregate"]
	check(aggregate.is_empty(), "unsupported newer save exposed an aggregate")
	var temp: String = owner.stage(placeholder_aggregate(1, "txn-0001"))
	var validate_error: Error = owner.validate(temp)
	check(validate_error == ERR_UNAVAILABLE, "validate over an unsupported committed file returned " + error_string(validate_error))
	var commit_error: Error = owner.commit(temp)
	check(commit_error == ERR_UNCONFIGURED, "commit over an unsupported committed file returned " + error_string(commit_error))
	check(FileAccess.file_exists(save_path), "schema 99 save.json disappeared")
	check(FileAccess.get_sha256(save_path) == sha_before, "schema 99 save.json was modified")
	note("schema 99 save.json recovered as unsupported_newer, not playable, sha256 %s unchanged, later commit refused" % sha_before.substr(0, 12))


func case_interruption_stale(case_root: String) -> void:
	var owner: SaveOwner = SaveOwner.new(case_root, inject_fault)
	var temp_name: String = "save.json.tmp-txn-0004"
	var temp_path: String = case_root.path_join(temp_name)
	var temp_sha: String = FileAccess.get_sha256(temp_path)
	var save_sha: String = FileAccess.get_sha256(owner.save_path())
	var recovered: Dictionary = owner.recover()
	check(get_string(recovered, "status") == SaveOwner.STATUS_COMMITTED_STALE_TEMP, "recover status " + str(recovered["status"]))
	var aggregate: Dictionary = recovered["aggregate"]
	check(get_int(aggregate, "generation") == 3, "recovered generation " + str(aggregate.get("generation")))
	var stale: Array[String] = recovered["stale"]
	var expected_stale: Array[String] = [temp_name]
	check(stale == expected_stale, "stale list " + str(stale))
	check(get_bool(recovered, "playable"), "committed generation 3 not playable")
	check(FileAccess.file_exists(temp_path), "truncated temp was removed")
	check(FileAccess.get_sha256(temp_path) == temp_sha, "truncated temp bytes changed")
	check(FileAccess.get_sha256(owner.save_path()) == save_sha, "save.json changed during recovery")
	note("generation 3 recovered, truncated temp listed as stale and left untouched")


func case_interruption_ambiguous(case_root: String) -> void:
	var owner: SaveOwner = SaveOwner.new(case_root, inject_fault)
	var temp_name: String = "save.json.tmp-txn-0004"
	var temp_path: String = case_root.path_join(temp_name)
	var temp_sha: String = FileAccess.get_sha256(temp_path)
	var save_sha: String = FileAccess.get_sha256(owner.save_path())
	var recovered: Dictionary = owner.recover()
	check(get_string(recovered, "status") == SaveOwner.STATUS_AMBIGUOUS_LIFECYCLE, "recover status " + str(recovered["status"]))
	var aggregate: Dictionary = recovered["aggregate"]
	check(get_int(aggregate, "generation") == 3, "source generation " + str(aggregate.get("generation")))
	check(not get_bool(recovered, "playable"), "ambiguous lifecycle reported playable")
	var stale: Array[String] = recovered["stale"]
	var expected_stale: Array[String] = [temp_name]
	check(stale == expected_stale, "stale list " + str(stale))
	check(FileAccess.file_exists(temp_path), "valid unrenamed temp was removed")
	check(FileAccess.get_sha256(temp_path) == temp_sha, "valid unrenamed temp bytes changed")
	check(FileAccess.get_sha256(owner.save_path()) == save_sha, "save.json changed during recovery")
	note("generation 3 stays the source, unrenamed generation 4 revival_spent temp preserved, status ambiguous_lifecycle and not playable")


func case_lifecycle_spent(case_root: String) -> void:
	var owner: SaveOwner = SaveOwner.new(case_root, inject_fault)
	var save_path: String = owner.save_path()
	var sha_before: String = FileAccess.get_sha256(save_path)
	var gen5: Dictionary = load_fixture_aggregate(owner, "save.json")
	var gen4: Dictionary = load_fixture_aggregate(owner, "older.json")
	if not _failures.is_empty():
		return
	var resolved: Dictionary = owner.resolve_lifecycle(gen5, gen4)
	var resolved_run: Dictionary = resolved["run"]
	var resolved_lifecycle: Dictionary = resolved_run["lifecycle"]
	check(get_bool(resolved_lifecycle, "revival_spent"), "resolve_lifecycle(gen5, gen4) lost revival_spent")
	check(get_int(resolved, "generation") == 5, "resolve_lifecycle took facts from generation " + str(resolved["generation"]))
	check(get_bool(resolved, "playable"), "spent revival without terminal reported not playable")
	var reversed: Dictionary = owner.resolve_lifecycle(gen4, gen5)
	var reversed_run: Dictionary = reversed["run"]
	var reversed_lifecycle: Dictionary = reversed_run["lifecycle"]
	check(get_bool(reversed_lifecycle, "revival_spent"), "resolve_lifecycle(gen4, gen5) lost revival_spent")
	var temp: String = owner.stage(gen4)
	var validate_error: Error = owner.validate(temp)
	check(validate_error == ERR_ALREADY_EXISTS, "staging generation 4 over 5 returned " + error_string(validate_error))
	var commit_error: Error = owner.commit(temp)
	check(commit_error == ERR_UNCONFIGURED, "commit of the older checkpoint returned " + error_string(commit_error))
	check(FileAccess.get_sha256(save_path) == sha_before, "save.json changed after the older checkpoint was rejected")
	note("revival_spent stays true from generation 5, generation 4 rejected with ERR_ALREADY_EXISTS, sha256 %s unchanged" % sha_before.substr(0, 12))


func case_lifecycle_terminal(case_root: String) -> void:
	var owner: SaveOwner = SaveOwner.new(case_root, inject_fault)
	var gen5: Dictionary = load_fixture_aggregate(owner, "save.json")
	var gen6: Dictionary = load_fixture_aggregate(owner, "terminal.json")
	if not _failures.is_empty():
		return
	var resolved: Dictionary = owner.resolve_lifecycle(gen6, gen5)
	check(not get_bool(resolved, "playable"), "terminal generation 6 reported playable")
	var reversed: Dictionary = owner.resolve_lifecycle(gen5, gen6)
	check(not get_bool(reversed, "playable"), "terminal generation 6 reported playable in reversed order")
	check(get_int(reversed, "generation") == 6, "reversed resolution took generation " + str(reversed["generation"]))
	if not commit_through_protocol(owner, gen6):
		return
	var recovered: Dictionary = owner.recover()
	check(get_string(recovered, "status") == SaveOwner.STATUS_COMMITTED, "recover status after terminal commit " + str(recovered["status"]))
	check(not get_bool(recovered, "playable"), "committed terminal run reported playable")
	note("terminal generation 6 beats generation 5 in both orders and stays not playable after commit")


func case_converged(case_root: String) -> void:
	var owner: SaveOwner = SaveOwner.new(case_root, inject_fault)
	var aggregate: Dictionary = placeholder_aggregate(1, "txn-0001")
	if not commit_through_protocol(owner, aggregate):
		return
	var save_path: String = owner.save_path()
	var sha_before: String = FileAccess.get_sha256(save_path)
	var temp: String = owner.stage(aggregate)
	var validate_error: Error = owner.validate(temp)
	check(validate_error == OK, "duplicate delivery validate returned " + error_string(validate_error))
	check(owner.converged, "duplicate delivery did not report converged")
	var commit_error: Error = owner.commit(temp)
	check(commit_error == OK, "duplicate delivery commit returned " + error_string(commit_error))
	check(FileAccess.get_sha256(save_path) == sha_before, "save.json rewritten by a converged duplicate")
	check(not FileAccess.file_exists(temp), "converged duplicate temp left behind")
	var recovered: Dictionary = owner.recover()
	var recovered_aggregate: Dictionary = recovered["aggregate"]
	check(get_int(recovered_aggregate, "generation") == 1, "generation changed after a converged duplicate")
	check(get_string(recovered, "status") == SaveOwner.STATUS_COMMITTED, "recover status after convergence " + str(recovered["status"]))
	note("re-staged txn-0001 converged with generation 1 and sha256 %s unchanged" % sha_before.substr(0, 12))


func check_idempotence() -> bool:
	var outcomes: Dictionary = {}
	var identical: bool = true
	for verdict: Dictionary in results:
		var case_name: String = verdict["case"]
		var outcome: String = "%s %s" % ["PASS" if verdict["passed"] else "FAIL", verdict["detail"]]
		if outcomes.has(case_name):
			if outcomes[case_name] != outcome:
				identical = false
		else:
			outcomes[case_name] = outcome
	print("%s idempotence %s %d cases compared across %d passes" % [PROOF, "PASS" if identical else "FAIL", CASES.size(), PASSES])
	return identical


func build_summary(exit_code: int, idempotent: bool) -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	for verdict: Dictionary in results:
		if verdict["passed"]:
			passed += 1
		else:
			failed += 1
	return {
		"proof": PROOF,
		"engine": version_token(),
		"host_os": OS.get_name(),
		"method": METHOD,
		"inject_fault": inject_fault,
		"passes": PASSES,
		"cases": CASES.size(),
		"passed": passed,
		"failed": failed,
		"idempotent": idempotent,
		"run_dir": run_dir,
		"exit_code": exit_code,
	}


func write_result(summary: Dictionary) -> void:
	var payload: Dictionary = summary.duplicate(true)
	payload["results"] = results
	payload["not_asserted"] = [
		"flush or fsync durability across power loss",
		"rename semantics on any operating system other than Linux",
		"single-writer exclusion between processes",
	]
	var file: FileAccess = FileAccess.open(run_dir.path_join("result.json"), FileAccess.WRITE)
	if file == null:
		push_error("result.json not written: " + error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(payload, "  ", true) + "\n")
	file.close()


func version_token() -> String:
	var info: Dictionary = Engine.get_version_info()
	var major: int = info["major"]
	var minor: int = info["minor"]
	var patch: int = info["patch"]
	var status: String = info["status"]
	var build: String = info["build"]
	var full_hash: String = info["hash"]
	return "%d.%d.%d.%s.%s.%s" % [major, minor, patch, status, build, full_hash.substr(0, 9)]
