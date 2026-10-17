extends SceneTree

const Proof := preload("res://tools/priority_proof.gd")

# tools/priority_proof.gd's pure parts: which rows play (built, model, not built) and the
# verdict over paired runs. No game boots; the runs themselves are the tool's own job.

var _failures := 0


func _initialize() -> void:
	_check("a roster kind is built", Proof.mode_of({"id": "chaser"}) == "built")
	_check("a control is built", Proof.mode_of({"id": "no_such_kind", "control": true}) == "built")
	_check("an absent kind with design values is a model", Proof.mode_of({"id": "no_such_kind", "model": {}}) == "model")
	_check("an absent kind without them is not built", Proof.mode_of({"id": "no_such_kind"}) == "not_built")
	for row in Proof.SPECIALS:
		_check("%s has a six-strong crew" % row["name"], (row["crew"] as Array).size() == 6)

	var rows := [
		{"row": {"name": "a", "id": "a"}, "mode": "built"},
		{"row": {"name": "b", "id": "b"}, "mode": "model"},
		{"row": {"name": "c", "id": "c"}, "mode": "built"},
		{"row": {"name": "d", "id": "d"}, "mode": "not_built"},
		{"row": {"name": "e", "id": "e"}, "mode": "built"},
	]
	var results := []
	for s in [1, 2]:
		results.append(_run("a", "target", s, 10.0, 20.0))
		results.append(_run("a", "ignore", s, 14.0, 30.0))
		results.append(_run("b", "target", s, 10.0, 20.0))
		results.append(_run("b", "ignore", s, 11.0, -1.0))
		results.append(_run("c", "target", s, 0.0, 9.0))
		results.append(_run("c", "ignore", s, 2.0, 9.0))
		results.append(_run("e", "target", s, 0.0, 9.0, 8.0))
		results.append(_run("e", "ignore", s, 0.0 if s == 1 else 4.0, 9.0, 24.0))
	results.append({"special": "a", "arm": "ignore", "seed": 3, "outcome": "no_result"})
	var report := Proof.summarize(rows, results, 120.0)
	var by := {}
	for item in report["specials"]:
		by[item["name"]] = item
	_check("1.4x more hull lost passes", by["a"]["verdict"] == "pass" and is_equal_approx(float(by["a"]["ratio"]), 1.4))
	_check("a run with no result is left out", by["a"]["ignore"]["runs"] == 2 and by["a"]["paired_seeds"] == 2)
	_check("1.1x misses", by["b"]["verdict"] == "miss")
	_check("an uncleared run counts the cap", is_equal_approx(float(by["b"]["ignore"]["clear_mean_s"]), 120.0))
	_check("under MIN_HULL is too little damage", by["c"]["verdict"] == "too little damage")
	_check("hull under MIN_HULL with 3x damage passes on damage", by["e"]["verdict"] == "too little damage"
		and by["e"]["damage_verdict"] == "pass" and is_equal_approx(float(by["e"]["damage_ratio"]), 3.0)
		and by["e"]["ignore_damage_worse_seeds"] == 2)
	_check("each arm reports its median hull", is_equal_approx(float(by["e"]["ignore"]["hull_median"]), 2.0)
		and is_equal_approx(float(by["e"]["target"]["hull_median"]), 0.0))
	_check("too little damage taken is graded too", by["c"]["damage_verdict"] == "too little damage")
	_check("the table carries the damage verdict", Proof.table(report)[5].ends_with("| pass"))
	_check("not built plays no runs", by["d"]["verdict"] == "not built" and not by["d"].has("target"))
	print("priority_proof_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _run(special: String, arm: String, seed_value: int, hull: float, clear: float, damage := 0.0) -> Dictionary:
	return {"special": special, "arm": arm, "seed": seed_value, "outcome": "cleared" if clear >= 0.0 else "capped",
			"hull_lost": hull, "clear_s": clear, "warnings": 5, "damage_taken": damage}


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
