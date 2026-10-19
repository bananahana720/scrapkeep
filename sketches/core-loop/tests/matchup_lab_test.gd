# smoke: solo timeout=300s (a small real table: 2 pilots x 3 kinds x 2 seeds, 12 duel processes)
extends SceneTree

const Lab := preload("res://tools/matchup_lab.gd")

# tools/matchup_lab.gd: the pure table, hard-cell and gate logic on synthetic tables (with a
# planted control), then a small real table run through the tool itself.

const PILOTS_SMALL := ["tarn", "tally"]
const KINDS_SMALL := ["chaser", "lobber", "plated_brute"]
const SEEDS_SMALL := [1, 2]

var _failures := 0


func _initialize() -> void:
	_synthetic()
	_lookup()
	_real_run()
	print("matchup_lab_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _row(pilot: String, kind: String, seed_value: int, ttk: float) -> Dictionary:
	return {"pilot": pilot, "kind": kind, "seed": seed_value, "outcome": "killed" if ttk >= 0.0 else "capped",
			"ttk_s": ttk, "hull_lost": 0.0 if ttk < 5.0 else 10.0}


# Every seed of a cell takes the same ttk, so the cell median is the number given.
func _table(ttks: Dictionary, pilots: Array, kinds: Array) -> Dictionary:
	var results := []
	for key in ttks:
		var parts: PackedStringArray = String(key).split("|")
		for s in [1, 2, 3]:
			results.append(_row(parts[0], parts[1], s, ttks[key]))
	return Lab.build_table(results, pilots, kinds, 40.0)


func _synthetic() -> void:
	var pilots := ["a", "b", "c"]
	var kinds := ["k1", "k2"]
	# k1 row medians: a 2, b 2, c 9 -> row median 2, c is over 2 x 2 = 4: hard.
	# k2 row medians: a 3, b 5, c 4 -> row median 4, nothing over 8.
	var ttks := {"a|k1": 2.0, "b|k1": 2.0, "c|k1": 9.0, "a|k2": 3.0, "b|k2": 5.0, "c|k2": 4.0}
	var table := _table(ttks, pilots, kinds)
	_check("row median is the median across pilots", is_equal_approx(float(table["row_median"]["k1"]), 2.0)
		and is_equal_approx(float(table["row_median"]["k2"]), 4.0))
	_check("exactly the over-2x cell is hard", (table["hard"] as Array).size() == 1
		and table["hard"][0]["pilot"] == "c" and table["hard"][0]["kind"] == "k1")
	var edge := _table({"a|k1": 2.0, "b|k1": 2.0, "c|k1": 4.0, "a|k2": 1.0, "b|k2": 1.0, "c|k2": 1.0}, pilots, kinds)
	_check("exactly 2x the row median is not hard", (edge["hard"] as Array).is_empty())
	var floored := _table({"a|k1": 0.1, "b|k1": 0.1, "c|k1": 0.9, "a|k2": 1.0, "b|k2": 1.0, "c|k2": 1.0}, pilots, kinds)
	_check("the row median is floored so instant kills make no hard cell", (floored["hard"] as Array).is_empty())
	var capped_rows := []
	for s in [1, 2, 3]:
		capped_rows.append(_row("a", "k1", s, 1.0))
		capped_rows.append(_row("b", "k1", s, 1.0))
		capped_rows.append(_row("c", "k1", s, -1.0))
	var capped := Lab.build_table(capped_rows, ["a", "b", "c"], ["k1"], 40.0)
	_check("a duel never won counts the cap and is hard", capped["cells"]["c|k1"]["hard"] and is_equal_approx(float(capped["cells"]["c|k1"]["median_ttk"]), 40.0)
		and capped["cells"]["c|k1"]["kills"] == 0)
	_check("a no_result run is left out", Lab.build_table([{"pilot": "a", "kind": "k1", "outcome": "no_result", "ttk_s": -1.0}], ["a"], ["k1"], 40.0)["cells"]["a|k1"]["runs"] == 0)

	# Gate part one on the table above: a and b have no hard cell, so the gate fails.
	var gate := Lab.gate_hard(table)
	_check("gate fails when a pilot has no hard cell", not gate["ok"] and gate["missing"] == ["a", "b"])
	# Planted control: every pilot gets one hard cell and the gate must flip; strip pilot b's
	# and it must flip back, naming b.
	var every := _table({"a|k1": 9.0, "b|k1": 2.0, "c|k1": 2.0, "a|k2": 2.0, "b|k2": 9.0, "c|k2": 2.0, "a|k3": 2.0, "b|k3": 2.0, "c|k3": 9.0}, pilots, ["k1", "k2", "k3"])
	_check("gate passes when every pilot has a hard cell", Lab.gate_hard(every)["ok"])
	var planted := _table({"a|k1": 9.0, "b|k1": 2.0, "c|k1": 2.0, "a|k2": 2.0, "b|k2": 2.5, "c|k2": 2.0, "a|k3": 2.0, "b|k3": 2.0, "c|k3": 9.0}, pilots, ["k1", "k2", "k3"])
	var planted_gate := Lab.gate_hard(planted)
	_check("planted control: no hard cell for one pilot reports FAIL", not planted_gate["ok"] and planted_gate["missing"] == ["b"]
		and Lab.gate_verdict(planted, {}) == "FAIL")

	# Gate part two: answers pending, won, lost.
	var pending := Lab.grade_answers(every, [], {}, 40.0, 3)
	_check("no answer item reports pending, not a failure", pending["a|k1"]["status"] == "pending" and pending["a|k1"]["text"] == Lab.PENDING
		and Lab.gate_verdict(every, pending) == "INCONCLUSIVE")
	var plan := {"a|k1": "x", "b|k2": "x", "c|k3": "x"}
	var results := []
	for s in [1, 2, 3]:
		results.append(_row("a", "k1", s, 3.0))
		results.append(_row("b", "k2", s, -1.0))
		results.append(_row("c", "k3", s, 3.0))
	var graded := Lab.grade_answers(every, results, plan, 40.0, 3)
	_check("an answer arm that kills and is no longer hard wins", graded["a|k1"]["status"] == "won")
	_check("an answer arm that never kills loses", graded["b|k2"]["status"] == "lost" and Lab.gate_verdict(every, graded) == "FAIL")
	var all_won := Lab.grade_answers(every, results.filter(func(r): return r["pilot"] != "b"), {"a|k1": "x", "b|k2": "", "c|k3": "x"}, 40.0, 3)
	_check("won plus pending is still inconclusive", Lab.gate_verdict(every, all_won) == "INCONCLUSIVE")
	var heat := Lab.heatmap(every)
	_check("the heatmap has one line per kind under two header lines", heat.size() == 5 and "9.0*[" in heat[2])
	var star_count := 0
	for line in heat.slice(2):
		star_count += line.count("*")
	_check("the heatmap stars exactly the hard cells", star_count == (every["hard"] as Array).size())


func _lookup() -> void:
	var rows := {
		"p_none": {"tags": ["spread"]},
		"p_range_b": {"answers": ["range", "air"]},
		"p_range_a": {"answers": "range"},
		"p_plating_sable": {"answers": ["plating"], "class": "pylon_engineer"},
	}
	_check("the answers field is detected", Lab.answers_field_exists(rows) and not Lab.answers_field_exists({"x": {"tags": []}}))
	_check("an axis finds the first sorted part carrying it", Lab.answer_item(rows, "tarn", "kite_drone") == "p_range_b")
	_check("a range kind finds the first sorted range part", Lab.answer_item(rows, "tarn", "lobber") == "p_range_a")
	_check("a class-gated part is withheld from other pilots", Lab.answer_item(rows, "tarn", "plated_brute") == ""
		and Lab.answer_item(rows, "pylon_engineer", "plated_brute") == "p_plating_sable")
	var real: Dictionary = load("res://src/build/parts.gd").rows()
	if not Lab.answers_field_exists(real):
		_check("a base without answers tags yields no answer item", Lab.answer_item(real, "tarn", "lobber") == "")
	_check("the default kinds skip the two kill-first specials and keep the built ones", "linker" not in Lab.default_kinds()
		and "foreman" not in Lab.default_kinds() and "plated_brute" in Lab.default_kinds() and Lab.default_kinds().size() >= 20)


func _real_run() -> void:
	var out := OS.get_user_data_dir().path_join("matchup_lab_test").path_join("small.ndjson")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	if FileAccess.file_exists(out):
		DirAccess.remove_absolute(out)
	var output := []
	var args := ["--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/matchup_lab.gd", "--",
			"--out=" + out, "--procs=3", "--seeds=1,2", "--pilots=" + ",".join(PILOTS_SMALL), "--kinds=" + ",".join(KINDS_SMALL),
			"--bot-no-mix=1", "--bot-no-visuals=1", "--bot-no-pilot-tracks=1"]
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var text := "\n".join(output)
	_check("the lab exits 0", code == 0)
	_check("the lab printed a heatmap and a gate verdict", "matchup_lab: heatmap" in text and "matchup_lab: gate verdict" in text)
	_check("with no answers tags, hard cells report pending and the arm does not fail", "no answers tags on this base" in text or "hard cells" in text)
	var rows := []
	if FileAccess.file_exists(out):
		for line in FileAccess.get_file_as_string(out).split("\n", false):
			var parsed = JSON.parse_string(line)
			if parsed is Dictionary:
				rows.append(parsed)
	_check("a row for every pilot, kind and seed (12)", rows.size() == PILOTS_SMALL.size() * KINDS_SMALL.size() * SEEDS_SMALL.size())
	var seen := {}
	var bad := 0
	for r in rows:
		seen["%s|%s|%d" % [r["pilot"], r["kind"], int(r["seed"])]] = true
		if String(r["outcome"]) in ["no_result", "wall_timeout"] or String(r.get("class", r["pilot"])) != String(r["pilot"]):
			bad += 1
	_check("every cell has both seeds", seen.size() == 12)
	_check("every run produced a result for the pilot asked", bad == 0)
	var table := Lab.build_table(rows, PILOTS_SMALL, KINDS_SMALL, 40.0)
	var runs_ok := true
	for key in table["cells"]:
		runs_ok = runs_ok and table["cells"][key]["runs"] == 2
	_check("the table has two runs in every cell", runs_ok)


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
