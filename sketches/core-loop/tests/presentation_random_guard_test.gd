# smoke: solo
# 2026-10-12 FIXTURE-ADAPT: 5f95fb5 parsed a killed child's truncated JSON into Dictionary and never quit.
# 2026-10-12 R2/m6: malformed child records are skipped safely and fail trace integrity with a verdict.
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")
const TICKS := 6000
const FIELDS := ["position", "velocity", "scrap", "enemies", "warden_integrity", "run_rng", "bot_rng", "stage", "hp", "mass", "parts", "cogs"]


func _initialize() -> void:
	# If an unexpected script error aborts initialization, the pending exit still fails closed.
	quit(1)
	var t := T.new("presentation_random_guard_test")
	var scratch := OS.get_environment("TMPDIR")
	if scratch.is_empty():
		scratch = ProjectSettings.globalize_path("res://../../artifacts/local/determinism")
	var base := scratch.path_join("guard-%d-%d" % [OS.get_process_id(), RandomNumberGenerator.new().randi()])
	var fingerprints := []
	var sample := {}
	for field in FIELDS:
		sample[field] = []
	t.eq("truncated final JSON record is skipped", _trace_rows(JSON.stringify(sample) + "\n{\"position\":", "parser probe").size(), 1)
	for arm in 2:
		var folder := base.path_join(str(arm))
		var results := ChildRuns.run([{"script": "res://tests/trees/presentation_random_child.gd", "home": folder, "args": [
			"--out=" + folder, "--policy=completionist", "--seeds=11", "--pilot=remembered_cannon",
			"--from-stage=4", "--trace-ticks=1", "--ticks=%d" % TICKS,
			"--presentation-draws=%d" % (17 if arm == 1 else 0)]}], 180.0)
		var result: Dictionary = results[0]
		var errors: Array = ChildRuns.summary(result)["errors"]
		t.check("arm %d completed" % arm, result["code"] == 0 and not result["timed_out"] and errors.is_empty(),
			"exit %s, timeout %s, errors %s" % [result["code"], result["timed_out"], errors])
		var rows := _trace_rows(FileAccess.get_file_as_string(folder.path_join("trace-11.ndjson")), "arm %d" % arm, t)
		t.eq("arm %d fixed ticks" % arm, rows.size(), TICKS)
		var fingerprint := []
		var enemies_seen := false
		var warden_seen := false
		for row in rows:
			var state := {}
			for field in FIELDS:
				state[field] = row[field]
			fingerprint.append(JSON.stringify(state))
			enemies_seen = enemies_seen or not row["enemies"].is_empty()
			warden_seen = warden_seen or not row["warden_integrity"].is_empty()
		t.check("arm %d live enemies and Warden" % arm, enemies_seen and warden_seen)
		fingerprints.append(fingerprint)
	_compare(t, "presentation draws leave simulation unchanged", fingerprints[0], fingerprints[1])
	print("guard evidence: %s" % base)
	quit(t.verdict())


func _compare(t, label: String, a: Array, b: Array) -> void:
	var first := 0
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			first = i + 1
			break
	t.check(label, not a.is_empty() and a == b, "first differing tick %d" % first)


func _trace_rows(text: String, label: String, t = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var invalid := 0
	var lines := text.split("\n", false)
	for i in lines.size():
		var parser := JSON.new()
		var error := parser.parse(lines[i])
		var parsed = parser.data
		if error != OK or not parsed is Dictionary:
			invalid += 1
			print("guard skipped invalid JSON record %d/%d in %s: %s" % [i + 1, lines.size(), label, parser.get_error_message()])
			continue
		if not FIELDS.all(func(field): return parsed.has(field)) or not parsed["enemies"] is Array or not parsed["warden_integrity"] is Array:
			invalid += 1
			print("guard skipped incomplete state record %d/%d in %s" % [i + 1, lines.size(), label])
			continue
		out.append(parsed)
	if t != null:
		t.eq("%s trace has no malformed records" % label, invalid, 0)
	return out
