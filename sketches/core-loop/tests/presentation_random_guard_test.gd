# smoke: solo
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")
const TICKS := 6000
const FIELDS := ["position", "velocity", "scrap", "enemies", "warden_integrity", "run_rng", "bot_rng", "stage", "hp", "mass", "parts", "cogs"]


func _initialize() -> void:
	var t := T.new("presentation_random_guard_test")
	var base := ProjectSettings.globalize_path("res://../../artifacts/local/determinism/guard-%d-%d" % [OS.get_process_id(), RandomNumberGenerator.new().randi()])
	var fingerprints := []
	for arm in 2:
		var folder := base.path_join(str(arm))
		var previous := {}
		for kind in ["DATA", "CONFIG", "CACHE"]:
			var key: String = "XDG_%s_HOME" % kind
			previous[key] = OS.get_environment(key)
			OS.set_environment(key, folder.path_join(kind.to_lower()))
		var results := ChildRuns.run([{"script": "res://tests/trees/presentation_random_child.gd", "args": [
			"--out=" + folder, "--policy=completionist", "--seeds=11", "--pilot=remembered_cannon",
			"--from-stage=4", "--trace-ticks=1", "--ticks=%d" % TICKS,
			"--presentation-draws=%d" % (17 if arm == 1 else 0)]}], 65.0)
		for key in previous:
			if previous[key].is_empty():
				OS.unset_environment(key)
			else:
				OS.set_environment(key, previous[key])
		var result: Dictionary = results[0]
		var errors: Array = ChildRuns.summary(result)["errors"]
		t.check("arm %d completed" % arm, result["code"] == 0 and not result["timed_out"] and errors.is_empty(),
			"exit %s, timeout %s, errors %s" % [result["code"], result["timed_out"], errors])
		var rows := FileAccess.get_file_as_string(folder.path_join("trace-11.ndjson")).split("\n", false)
		t.eq("arm %d fixed ticks" % arm, rows.size(), TICKS)
		var fingerprint := []
		var enemies_seen := false
		var warden_seen := false
		for line in rows:
			var row: Dictionary = JSON.parse_string(line)
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
