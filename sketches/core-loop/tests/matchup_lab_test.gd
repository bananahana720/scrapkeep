# smoke: bots timeout=1200s (real duels in child processes: a 12-duel table, an idle control, a pack duel and a 30 s capped pack duel that must outlast the beacon charge, two perched duels (park and mast); 264 s alone on the base, 701 s and 894 s beside a lab table, killed at the 360 s solo ceiling in sketch:fast on 2026-10-20, so it joins the bot tier like alpha_posture_bands_test)
extends SceneTree

const Lab := preload("res://tools/matchup_lab.gd")
const PocketArena := preload("res://tools/pocket_arena.gd")

# tools/matchup_lab.gd: the pure table, hard-cell and gate logic on synthetic tables (with a
# planted control), then a small real table run through the tool itself.

const PILOTS_SMALL := ["tarn", "tally"]
const KINDS_SMALL := ["chaser", "lobber", "plated_brute"]
const SEEDS_SMALL := [1, 2]

var _failures := 0


func _initialize() -> void:
	if "--fast-pass-only" in OS.get_cmdline_user_args():
		_fast_pass_receipt()
		quit(0 if _failures == 0 else 1)
		return
	_fast_pass_receipt()
	_synthetic()
	_pocket_pure()
	_lookup()
	_real_run()
	_damage_control()
	_packs_pure()
	_wall_rows()
	_wall_verdict()
	_pack_duel()
	_perched_pure()
	_perched_duel()
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


# ---- Pocket sweep: pure cell and verdict logic on synthetic rows -----------------------------------------------

func _pocket_row(shape: String, enemy: String, outcome: String, hull_lost: float, max_hull := 100.0) -> Dictionary:
	return {"kind": Lab.pocket_key(shape, enemy), "pocket": shape, "enemy": enemy, "outcome": outcome, "hull_lost": hull_lost,
			"real_max_hull": max_hull, "ttk_s": 10.0 if outcome == "killed" else -1.0}


func _pocket_rows(shape: String, enemy: String, wins: int, losses: int) -> Array:
	var rows := []
	for i in wins:
		rows.append(_pocket_row(shape, enemy, "killed", 30.0))
	for i in losses:
		rows.append(_pocket_row(shape, enemy, "capped", 30.0))
	return rows


func _pocket_pure() -> void:
	# Winner: killed with the hull under the class's real max hull; every other end is the enemy's; no result is void.
	var short_pack := _pocket_row("half_pipe", "chaser", "killed", 0.0)
	short_pack["spawned"] = 2
	_check("pocket winner: a pack that did not spawn whole is void", Lab.pocket_winner(short_pack) == "void")
	_check("pocket winner: a kill under the real max hull is the pilot's", Lab.pocket_winner(_pocket_row("half_pipe", "chaser", "killed", 99.9)) == "pilot")
	_check("pocket winner: a kill with hull lost at the real max hull is the enemy's", Lab.pocket_winner(_pocket_row("half_pipe", "chaser", "killed", 100.0)) == "enemy")
	_check("pocket winner: hull_out, capped and died are the enemy's", Lab.pocket_winner(_pocket_row("half_pipe", "chaser", "hull_out", 100.0)) == "enemy"
		and Lab.pocket_winner(_pocket_row("half_pipe", "chaser", "capped", 0.0)) == "enemy" and Lab.pocket_winner(_pocket_row("half_pipe", "chaser", "died", 100.0)) == "enemy")
	_check("pocket winner: the class's own max hull decides (the same loss wins for a 130 hull and loses for a 115)", Lab.pocket_winner(_pocket_row("half_pipe", "chaser", "killed", 120.0, 130.0)) == "pilot"
		and Lab.pocket_winner(_pocket_row("half_pipe", "chaser", "killed", 120.0, 115.0)) == "enemy")
	_check("pocket winner: no_result, a wall timeout, a stage change and a missing real max hull are void", Lab.pocket_winner(_pocket_row("half_pipe", "chaser", "no_result", 0.0)) == "void"
		and Lab.pocket_winner(_pocket_row("half_pipe", "chaser", "wall_timeout", 0.0)) == "void" and Lab.pocket_winner(_pocket_row("half_pipe", "chaser", "stage_changed", 0.0)) == "void"
		and Lab.pocket_winner(_pocket_row("half_pipe", "chaser", "killed", 0.0, -1.0)) == "void")
	# Cell: win rate over runs that measured something; 0% and 100% are flagged, anything between is not.
	var all_win := Lab.pocket_cell(_pocket_rows("half_pipe", "chaser", 15, 0))
	var all_lose := Lab.pocket_cell(_pocket_rows("half_pipe", "chaser", 0, 15))
	var mid := Lab.pocket_cell(_pocket_rows("half_pipe", "chaser", 7, 8))
	var near_win := Lab.pocket_cell(_pocket_rows("half_pipe", "chaser", 14, 1))
	var near_lose := Lab.pocket_cell(_pocket_rows("half_pipe", "chaser", 1, 14))
	_check("pocket cell: 15 of 15 is 100%, flagged high", is_equal_approx(all_win["win_rate"], 1.0) and all_win["n"] == 15 and all_win["flag"] and all_win["flag_kind"] == "high")
	_check("pocket cell: 0 of 15 is 0%, flagged low", is_equal_approx(all_lose["win_rate"], 0.0) and all_lose["n"] == 15 and all_lose["flag"] and all_lose["flag_kind"] == "low")
	_check("pocket cell: 7 of 15 is not flagged", mid["n"] == 15 and mid["wins"] == 7 and not mid["flag"] and mid["flag_kind"] == "")
	_check("pocket cell: 14 of 15 and 1 of 15 are not flagged (only the extremes retune)", not near_win["flag"] and not near_lose["flag"])
	var with_void := _pocket_rows("half_pipe", "chaser", 5, 0)
	with_void.append(_pocket_row("half_pipe", "chaser", "no_result", 0.0))
	var voided := Lab.pocket_cell(with_void)
	_check("pocket cell: a void run is counted apart and not in n (5 of 5 wins, void 1)", voided["n"] == 5 and voided["void"] == 1 and voided["runs"] == 6 and voided["flag_kind"] == "high")
	var empty := Lab.pocket_cell([_pocket_row("half_pipe", "chaser", "no_result", 0.0)])
	_check("pocket cell: all-void has no rate and no flag", empty["n"] == 0 and not empty["flag"] and empty["win_rate"] < 0.0)
	# Table: 5 shapes by 4 columns, hop an explicit n/a, a flyer column carrying its two sub-rows.
	var rows := []
	for shape in PocketArena.SHAPES:
		rows.append_array(_pocket_rows(shape, "chaser", 8, 7))
		rows.append_array(_pocket_rows(shape, "kite_drone", 8, 7))
		rows.append_array(_pocket_rows(shape, "winch_drone", 8, 7))
		rows.append_array(_pocket_rows(shape, "burrower", 8, 7))
	rows = rows.filter(func(r): return not (r["pocket"] == "crevice" and r["enemy"] == "winch_drone"))
	rows.append_array(_pocket_rows("crevice", "winch_drone", 0, 15))
	var table := Lab.pocket_table(rows, PocketArena.SHAPES)
	_check("pocket table: five shapes by four columns", table["shapes"].size() == 5 and table["columns"] == ["ground", "flyer", "burrower", "hop"] and table["cells"]["rail_grove"].size() == 4)
	_check("pocket table: hop is an explicit n/a cell with a reason and no runs", table["cells"]["half_pipe"]["hop"]["na"] and String(table["cells"]["half_pipe"]["hop"]["reason"]) != "" and table["cells"]["half_pipe"]["hop"]["n"] == 0)
	_check("pocket table: a flyer column flags when one sub-row is at 0%", table["cells"]["crevice"]["flyer"]["flag"] and table["cells"]["crevice"]["flyer"]["flag_kind"] == "low"
		and table["cells"]["crevice"]["flyer"]["flagged_rows"] == ["winch_drone low"] and not table["cells"]["half_pipe"]["flyer"]["flag"])
	_check("pocket table: the flyer column keeps both sub-rows at n=15 each", table["cells"]["half_pipe"]["flyer"]["rows"].size() == 2 and table["cells"]["half_pipe"]["flyer"]["rows"]["kite_drone"]["n"] == 15
		and table["cells"]["half_pipe"]["flyer"]["n"] == 30)
	var md := "\n".join(Lab.pocket_markdown(table))
	_check("pocket markdown: a header with the four columns, five shape rows, n/a for hop and the flag text", md.contains("| pocket | ground | flyer | burrower | hop |") and md.contains("| half_pipe |")
		and md.contains("n/a") and md.contains("FLAG retune (0%)") and md.contains("(n=15)"))
	_check("pocket table survives JSON", JSON.parse_string(JSON.stringify(table)) is Dictionary)
	# Jobs: shapes x (1 + 2 + 1) rows x 5 seeds x 3 runs, hop queues nothing; pilots rotate by seed and step by run.
	var roster: Array = ["p0", "p1", "p2", "p3", "p4", "p5"]
	var jobs := Lab.pocket_jobs(PocketArena.SHAPES, ["ground", "flyer", "burrower", "hop"], [1, 2, 3, 4, 5], 3, roster)
	_check("pocket jobs: 5 shapes x 4 enemy rows x 5 seeds x 3 runs = 300", jobs.size() == 300)
	_check("pocket jobs: hop alone queues nothing", Lab.pocket_jobs(["half_pipe"], ["hop"], [1, 2, 3, 4, 5], 3, roster).is_empty())
	var seed1 := jobs.filter(func(j): return j["kind"] == Lab.pocket_key("half_pipe", "chaser") and j["base_seed"] == 1)
	_check("pocket jobs: the first run of seed 1 is the plain seed on the rotation's class, the repeats step pilot and rng seed", seed1.size() == 3 and seed1[0]["seed"] == 1 and seed1[0]["pilot"] == "p1"
		and seed1[1]["pilot"] == "p2" and seed1[2]["pilot"] == "p3" and seed1[0]["seed"] != seed1[1]["seed"] and seed1[1]["seed"] != seed1[2]["seed"])
	var keys := {}
	for j in jobs:
		keys["%s|%d|%d" % [j["kind"], j["base_seed"], j["run"]]] = true
	_check("pocket jobs: every job is a distinct (row, seed, run)", keys.size() == jobs.size())
	_check("pocket key round trips and rejects strangers", Lab.pocket_parts(Lab.pocket_key("crevice", "kite_drone")) == {"shape": "crevice", "enemy": "kite_drone"}
		and Lab.pocket_parts("pocket:nowhere/chaser").is_empty() and Lab.pocket_parts("pack:run_down").is_empty() and Lab.pocket_parts("chaser").is_empty())
	_check("pocket columns: ground is the chaser, flyer the two drones, burrower the burrower", Lab.pocket_column_of("chaser") == "ground" and Lab.pocket_column_of("winch_drone") == "flyer"
		and Lab.pocket_column_of("burrower") == "burrower" and Lab.pocket_column_of("lobber") == "")
	# Plants (the controls): absent is the identity; pilot_helpless drives a cell to 0%, packs_passive to 100%; pack_damage is
	# a probe with no expectation.
	var none := Lab.pocket_plant("")
	var helpless := Lab.pocket_plant("pilot_helpless=1")
	var damage := Lab.pocket_plant("pack_damage=4")
	var passive := Lab.pocket_plant("packs_passive=1")
	_check("plant: absent is the identity (no dial, no expectation)", none["ok"] and none["dials"].is_empty() and none["expect"] == "")
	_check("plant: pilot_helpless=1 makes enemy hits lethal and expects 0%", helpless["ok"] and helpless["dials"] == {Lab.PLANT_DIAL: Lab.HELPLESS_DAMAGE} and helpless["expect"] == "low")
	_check("plant: pack_damage=4 multiplies the mobs damage dial and expects nothing", damage["ok"] and damage["dials"] == {Lab.PLANT_DIAL: 4.0} and damage["expect"] == "")
	_check("plant: packs_passive=1 zeroes the mobs damage dial and expects 100%", passive["ok"] and passive["dials"] == {Lab.PLANT_DIAL: 0.0} and passive["expect"] == "high")
	_check("plant: bad specs are refused", not Lab.pocket_plant("pack_damage=1")["ok"] and not Lab.pocket_plant("packs_passive=2")["ok"] and not Lab.pocket_plant("pilot_helpless=0")["ok"] and not Lab.pocket_plant("nothing=1")["ok"] and not Lab.pocket_plant("pack_damage")["ok"])
	# Control expectation, on synthetic planted cells: a helpless pilot loses every run, a passive cell
	# kills in every run; an unplanted mixed cell reads neither, and each plant fails the other's expectation.
	var planted_low := []
	var planted_high := []
	for i in 15:
		planted_low.append(_pocket_row("hazard_field", "chaser", "hull_out", 100.0))
		planted_high.append(_pocket_row("hazard_field", "chaser", "killed", 0.0))
	var low_cell := Lab.pocket_cell(planted_low)
	var high_cell := Lab.pocket_cell(planted_high)
	_check("control: a pilot_helpless=1 cell with the hull out in all 15 runs reads 0% and the control passes", low_cell["flag_kind"] == "low" and Lab.pocket_control_ok(helpless, low_cell))
	_check("control: pack_damage is a probe, never a passing control", not Lab.pocket_control_ok(damage, low_cell))
	_check("control: a packs_passive=1 cell with every pack killed reads 100% and the control passes", high_cell["flag_kind"] == "high" and Lab.pocket_control_ok(passive, high_cell))
	_check("control: planted negative, each plant fails the other's expectation and an unplanted mixed cell fails both", not Lab.pocket_control_ok(helpless, high_cell)
		and not Lab.pocket_control_ok(passive, low_cell) and not Lab.pocket_control_ok(helpless, mid) and not Lab.pocket_control_ok(passive, mid) and not Lab.pocket_control_ok(none, low_cell))
	# Child args: a pocket child carries its run index, base seed and plant; every other child's args are untouched.
	var pocket_args := Lab.child_args(seed1[1], 40.0, {"plant": "pack_damage=4"}, "park", "/h", "/p")
	_check("child args: a pocket child gets --base-seed, --run and --plant", "--base-seed=1" in pocket_args and "--run=1" in pocket_args and "--plant=pack_damage=4" in pocket_args
		and "--run-seed=%d" % seed1[1]["seed"] in pocket_args)
	var tuned := Lab.child_args(seed1[1], 40.0, {"tune": "mobs.damage_mult=2,mobs.pack_scale_mult=1.5"}, "park", "/h", "/p")
	_check("child args: --tune reaches every duel with its whole payload", "--tune=mobs.damage_mult=2,mobs.pack_scale_mult=1.5" in tuned)
	var kind_args := Lab.child_args({"pilot": "tarn", "kind": "lobber", "seed": 1, "give": "", "n": 0}, 40.0, {"plant": "pack_damage=4"}, "park", "/h", "/p")
	var kind_flags := false
	for a in kind_args:
		kind_flags = kind_flags or a.begins_with("--base-seed") or a.begins_with("--run=") or a.begins_with("--plant")
	_check("child args: a kind child never gets the pocket flags", not kind_flags)



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
		if String(r["outcome"]) in Lab.NO_RESULT or String(r.get("class", r["pilot"])) != String(r["pilot"]):
			bad += 1
	_check("every cell has both seeds", seen.size() == 12)
	_check("every run produced a result for the pilot asked", bad == 0)
	var rested := true
	for r in rows:
		rested = rested and float(r.get("settle_s", 0.0)) >= Lab.SETTLE_S and r.has("rest_forced")
	_check("every duel waited at least SETTLE_S before the spawn and recorded settle_s", rested and not rows.is_empty())
	var table := Lab.build_table(rows, PILOTS_SMALL, KINDS_SMALL, 40.0)
	var runs_ok := true
	for key in table["cells"]:
		runs_ok = runs_ok and table["cells"][key]["runs"] == 2
	_check("the table has two runs in every cell", runs_ok)


# Planted positive control for damage: an idle pilot (never fights) 6 m from a plated brute and a
# lobber must be hurt, so a run that reports 0 damage everywhere is a lab that cannot hurt the ball.
func _damage_control() -> void:
	_check("planted negative: rows with no hits, damage or hull lost show no damage",
		not Lab.damage_seen([{"hits": 0.0, "damage_taken": 0.0, "hull_lost": 0.0}, {}]))
	_check("damage_seen reads a hit", Lab.damage_seen([{"hits": 1.0, "damage_taken": 0.0, "hull_lost": 0.0}]))
	var out := OS.get_user_data_dir().path_join("matchup_lab_test").path_join("idle.ndjson")
	if FileAccess.file_exists(out):
		DirAccess.remove_absolute(out)
	var output := []
	var args := ["--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/matchup_lab.gd", "--",
			"--out=" + out, "--procs=2", "--seeds=1", "--idle=1", "--range=6", "--cap=12", "--pilots=tarn", "--kinds=plated_brute,lobber", "--answer=0",
			"--bot-no-mix=1", "--bot-no-visuals=1", "--bot-no-pilot-tracks=1"]
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	_check("the idle damage control exits 0", code == 0)
	var rows := []
	if FileAccess.file_exists(out):
		for line in FileAccess.get_file_as_string(out).split("\n", false):
			var parsed = JSON.parse_string(line)
			if parsed is Dictionary:
				rows.append(parsed)
	var hurt := false
	for r in rows:
		hurt = hurt or (float(r["hits"]) > 0.0 and float(r["damage_taken"]) > 0.0 and float(r["hull_lost"]) > 0.0)
	_check("planted positive: an idle pilot is hit, takes damage and loses hull (2 rows)", rows.size() == 2 and hurt)


# Both stages ship grounded. A result for the dam must never stand in for the flume.
# Invoke the producer as the done read does, without the old duel table's --out.
func _fast_pass_receipt() -> void:
	var mark := Lab.TelegraphScript.new()
	mark.radius = 1.0
	var counter := Lab.PassCounter.new()
	for x in [0.0, 3.0]:
		var owner := "on" if x == 0.0 else "off"
		mark.center = Vector3(x, 0.0, 14.0)
		for tick in range(91):
			if tick == 90:
				var ball := Vector3(0.0, 1.0, 14.0 * tick / 90.0)
				counter.shape(owner, owner, mark, ball)
				counter.shape(owner, owner, mark, ball)
	_check("a committed strike on the line counts once and a strike 3 m aside misses",
		counter.threats == {"on": 1} and counter.strikes.size() == 2)
	mark.free()
	var receipt := OS.get_user_data_dir().path_join("fast-threat-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()])
	var args := ["--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tools/matchup_lab.gd", "--", "--packs=grounded", "--table=park",
		"--pass=straight", "--speed=14,28", "--seeds=1", "--pilots=tarn", "--receipt=" + receipt]
	var output := []
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	_check("the fast-pass producer writes its receipt", code == 0 and FileAccess.file_exists(receipt))
	if code != 0 or not FileAccess.file_exists(receipt):
		printerr("\n".join(output))
		return
	var result = JSON.parse_string(FileAccess.get_file_as_string(receipt))
	var rows = result.get("passes") if result is Dictionary else null
	if not rows is Array:
		_check("the fast-pass receipt contains individual passes", false)
		return
	var observed := []
	for row in rows:
		if row is Dictionary and row.get("pack") == "grounded" and row.get("pass") == "straight" \
				and row.get("pilot") == "tarn" and row.get("seed") == 1:
			observed.append("%d/%d" % [row["stage"], row["speed"]])
	observed.sort()
	_check("grounded is ridden once at each speed on each Spillway stage",
		rows.size() == 4 and observed == ["1/14", "1/28", "2/14", "2/28"])


func _packs_pure() -> void:
	_check("run_down is chaser x3 + lobber on the park table", Lab.pack_kinds("park", "run_down") == ["chaser", "chaser", "chaser", "lobber"])
	_check("an unknown pack id is empty", Lab.pack_kinds("park", "no_such_pack").is_empty() and Lab.pack_kinds("alpha", "").is_empty())
	var ids: Array = Lab.pack_ids("park")
	_check("pack_ids lists run_down then grounded first, each once, and includes the elite", ids.size() >= 3 and ids[0] == "run_down" and ids[1] == "grounded"
		and "elite" in ids and ids.count("run_down") == 1)
	var all_known := true
	for id in ids:
		all_known = all_known and not Lab.pack_kinds("park", id).is_empty()
	_check("every listed pack id resolves to members", all_known)
	_check("the alpha table has packs too", not Lab.pack_ids("alpha").is_empty())
	# Axis: most common ANSWER_AXIS; ties by AXES order.
	_check("run_down answers on fuse (3 chasers beat 1 lobber)", Lab.pack_axis(Lab.pack_kinds("park", "run_down")) == "fuse")
	_check("an axis tie goes to the earlier AXES entry (lobber range vs mag_trapper cc)", Lab.pack_axis(["mag_trapper", "lobber"]) == "range")
	_check("a pack row finds its answer item by the pack axis", Lab.answer_item({"p_fuse": {"answers": ["fuse"]}, "p_range": {"answers": ["range"]}}, "tarn", "pack:run_down", ["chaser", "chaser", "chaser", "lobber"]) == "p_fuse")
	_check("the heatmap label is +id in 9 chars; a kind keeps its name", Lab.row_label("pack:run_down") == "+run_down" and Lab.row_label("pack:elite_highdraft") == "+elite_hi" and Lab.row_label("chaser") == "chaser")
	# A mixed table: a kind row and two pack rows; the slow pack cell is HARD, the fast one is not.
	var pilots := ["a", "b", "c"]
	var kinds := ["chaser", "pack:slow", "pack:fast"]
	var mixed := _table({"a|chaser": 2.0, "b|chaser": 2.0, "c|chaser": 2.0, "a|pack:slow": 3.0, "b|pack:slow": 3.0, "c|pack:slow": 12.0,
			"a|pack:fast": 3.0, "b|pack:fast": 3.0, "c|pack:fast": 5.0}, pilots, kinds)
	var hard_keys := []
	for cell in mixed["hard"]:
		hard_keys.append(Lab.cell_key(cell["pilot"], cell["kind"]))
	_check("a planted slow pack cell is HARD and the fast pack cell is not", hard_keys == ["c|pack:slow"])
	_check("planted negative: a slow-looking pack cell under 2x its row median is not hard", not mixed["cells"]["c|pack:fast"]["hard"] and not mixed["cells"]["a|pack:slow"]["hard"])
	_check("pack rows feed the pilot hard-cell gate", Lab.gate_hard(mixed)["missing"] == ["a", "b"] and Lab.hard_by_pilot(mixed)["c"] == ["pack:slow"])
	var heat := Lab.heatmap(mixed)
	_check("the heatmap shows the pack row labelled +slow with its star", heat.size() == 5 and heat[3].begins_with("+slow") and "12.0*" in heat[3] and heat[2].begins_with("chaser"))
	_merge_from()
	_child_args_and_empty()


func _child_args_and_empty() -> void:
	var job := {"pilot": "tarn", "kind": "pack:run_down", "seed": 1, "give": "", "n": 0}
	var args := Lab.child_args(job, 15.0, {"table": "alpha", "range": "9"}, "alpha", "/h", "/p")
	var bare := false
	for a in args:
		bare = bare or a.begins_with("--table=")
	_check("a pack child's args carry --pack-table and never a bare --table= (Game would pick a stage map)", not bare and "--pack-table=alpha" in args and "--range=9" in args)
	var kind_args := Lab.child_args({"pilot": "tarn", "kind": "lobber", "seed": 1, "give": "", "n": 0}, 15.0, {}, "park", "/h", "/p")
	var kind_bare := false
	for a in kind_args:
		kind_bare = kind_bare or a.begins_with("--table=") or a.begins_with("--pack-table=")
	_check("a kind child gets no table arg at all", not kind_bare)
	_check("planted negative: the bare-table detector would catch the old arg", "--table=park".begins_with("--table="))
	_check("a pack with nothing spawned is no_result, one that spawned keeps its outcome", Lab.pack_outcome(0, "killed") == "no_result" and Lab.pack_outcome(3, "capped") == "capped")
	var empty := Lab.build_table([{"pilot": "a", "kind": "pack:x", "outcome": Lab.pack_outcome(0, "killed"), "ttk_s": 0.0}], ["a"], ["pack:x"], 40.0)
	_check("an all-skipped pack row is left out of the table", empty["cells"]["a|pack:x"]["runs"] == 0)
	var changed := Lab.build_table([{"pilot": "a", "kind": "k1", "outcome": "stage_changed", "ttk_s": -1.0, "stage_changed": true}], ["a"], ["k1"], 40.0)
	_check("a stage_changed run is no result: left out of the table", changed["cells"]["a|k1"]["runs"] == 0 and "stage_changed" in Lab.NO_RESULT)
	_check("planted negative: a capped run still counts (the skip is only for no-result outcomes)", Lab.build_table([{"pilot": "a", "kind": "k1", "outcome": "capped", "ttk_s": -1.0}], ["a"], ["k1"], 40.0)["cells"]["a|k1"]["runs"] == 1)
	# A table with a real hard cell (c|k1: 9 s against a 2 s row), then an answer arm with stage_changed rows.
	var hard_table := _table({"a|k1": 2.0, "b|k1": 2.0, "c|k1": 9.0}, ["a", "b", "c"], ["k1"])
	var wins := []
	var junk := []
	for sd in [1, 2, 3]:
		wins.append(_row("c", "k1", sd, 3.0))
		junk.append({"pilot": "c", "kind": "k1", "seed": sd, "outcome": "stage_changed", "ttk_s": -1.0, "stage_changed": true})
	var clean: Dictionary = Lab.grade_answers(hard_table, wins, {"c|k1": "x"}, 40.0, 3)["c|k1"]
	var mixed_arm: Dictionary = Lab.grade_answers(hard_table, wins + junk, {"c|k1": "x"}, 40.0, 3)["c|k1"]
	var only_junk: Dictionary = Lab.grade_answers(hard_table, junk, {"c|k1": "x"}, 40.0, 3)["c|k1"]
	_check("the hard cell exists and the clean answer arm wins", (hard_table["hard"] as Array).size() == 1 and clean["status"] == "won")
	_check("grade_answers ignores stage_changed rows: same status, runs and kills with them added", mixed_arm["status"] == "won" and mixed_arm["runs"] == 3 and mixed_arm["kills"] == 3)
	_check("an answer arm of only stage_changed rows has no runs (not a win)", only_junk["runs"] == 0 and only_junk["status"] == "lost")


# --from merge order: kind rows (default kinds order) first, then pack rows in first-seen order.
func _merge_from() -> void:
	var dir := OS.get_user_data_dir().path_join("matchup_lab_test")
	DirAccess.make_dir_recursive_absolute(dir)
	var kind_path := dir.path_join("from_kinds.ndjson")
	var pack_path := dir.path_join("from_packs.ndjson")
	var out_path := dir.path_join("from_merge.txt")
	var f := FileAccess.open(kind_path, FileAccess.WRITE)
	for s in [1, 2]:
		f.store_line(JSON.stringify(_row("tarn", "lobber", s, 2.0)))
		f.store_line(JSON.stringify(_row("tarn", "chaser", s, 2.0)))
	f.close()
	f = FileAccess.open(pack_path, FileAccess.WRITE)
	for s in [1, 2]:
		f.store_line(JSON.stringify(_row("tarn", "pack:grounded", s, 6.0)))
		f.store_line(JSON.stringify(_row("tarn", "pack:run_down", s, 7.0)))
	f.close()
	var output := []
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/matchup_lab.gd", "--",
			"--from=" + pack_path + "," + kind_path, "--out=" + out_path]
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var text := "\n".join(output)
	_check("--from merges a pack file and a kind file and exits 0", code == 0 and "matchup_lab: heatmap" in text)
	var chaser := text.find("chaser ")
	var lobber := text.find("lobber ")
	var grounded := text.find("+grounded")
	var run_down := text.find("+run_down")
	_check("--from lists kind rows first (default order), then pack rows in first-seen order",
		chaser >= 0 and lobber >= 0 and grounded > lobber and grounded > chaser and run_down > grounded)


# WALL guard: a row a pilot ran and no pilot killed is marked WALL, fails the gate line and names
# its id; a row one pilot killed is not. Synthetic saved rows through --from, no duels.
func _wall_rows() -> void:
	var dir := OS.get_user_data_dir().path_join("matchup_lab_test")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("from_wall.ndjson")
	var out_path := dir.path_join("from_wall.txt")
	var f := FileAccess.open(path, FileAccess.WRITE)
	for s in [1, 2]:
		for pilot in ["tarn", "tally"]:
			f.store_line(JSON.stringify(_row(pilot, "chaser", s, 2.0)))
			f.store_line(JSON.stringify(_row(pilot, "pack:plate_press_draft", s, -1.0)))
			f.store_line(JSON.stringify(_row(pilot, "pack:plate_press_crown", s, -1.0)))
		f.store_line(JSON.stringify(_row("tarn", "pack:half_wall", s, -1.0)))
		f.store_line(JSON.stringify(_row("tally", "pack:half_wall", s, 9.0)))
	f.close()
	var output := []
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/matchup_lab.gd", "--",
			"--from=" + path, "--out=" + out_path]
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var text := "\n".join(output)
	_check("--from with wall rows exits 0", code == 0)
	_check("the gate line fails and names both wall rows", "wall rows: pack:plate_press_draft, pack:plate_press_crown" in text)
	_check("the verdict is FAIL with a wall row", "gate verdict FAIL" in text)
	_check("wall rows carry WALL in the heatmap, the chaser and half-killed rows do not",
		_row_text(text, "+plate_pr").ends_with("WALL") and _row_text(text, "+plate_p2").ends_with("WALL")
		and not "WALL" in _row_text(text, "chaser") and not "WALL" in _row_text(text, "+half_wal"))
	var labels := Lab.row_labels(["pack:plate_press_draft", "pack:plate_press_crown", "chaser"])
	_check("colliding row labels are made unique", labels["pack:plate_press_draft"] != labels["pack:plate_press_crown"] and labels["chaser"] == "chaser")
	var live := _table({"a|k": 2.0, "b|k": 3.0}, ["a", "b"], ["k"])
	_check("a table with kills has no wall row", (live["wall"] as Array).is_empty())


# gate_verdict in isolation: every pilot has a hard cell (gate part one passes), so only the WALL
# row can move the verdict. k4 is run by every pilot and killed by none.
func _wall_verdict() -> void:
	var pilots := ["a", "b", "c"]
	var kinds := ["k1", "k2", "k3", "k4"]
	var base := {"a|k1": 9.0, "b|k1": 2.0, "c|k1": 2.0, "a|k2": 2.0, "b|k2": 9.0, "c|k2": 2.0, "a|k3": 2.0, "b|k3": 2.0, "c|k3": 9.0}
	var walled := base.duplicate()
	for p in pilots:
		walled[p + "|k4"] = -1.0
	var wall_table := _table(walled, pilots, kinds)
	_check("wall verdict: the all-capped row is the only wall row", wall_table["wall"] == ["k4"] and Lab.gate_hard(wall_table)["ok"])
	_check("wall verdict: a wall row alone fails the gate", Lab.gate_verdict(wall_table, {}) == "FAIL")
	var killed := base.duplicate()
	killed["a|k4"] = -1.0
	killed["b|k4"] = -1.0
	killed["c|k4"] = 3.0
	var live_table := _table(killed, pilots, kinds)
	_check("wall verdict control: one pilot's kill clears the wall", (live_table["wall"] as Array).is_empty() and Lab.gate_hard(live_table)["ok"])
	_check("wall verdict control: no wall row, no failure", Lab.gate_verdict(live_table, {}) == "PASS")


func _row_text(text: String, label: String) -> String:
	for line in text.split("\n"):
		if line.begins_with(label):
			return line.strip_edges()
	return ""


# One small real pack duel: run_down (3 chasers + a lobber), one pilot, one seed, a low cap.
func _pack_duel() -> void:
	var out := OS.get_user_data_dir().path_join("matchup_lab_test").path_join("pack.ndjson")
	if FileAccess.file_exists(out):
		DirAccess.remove_absolute(out)
	var output := []
	var args := ["--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/matchup_lab.gd", "--",
			"--out=" + out, "--procs=1", "--seeds=1", "--cap=15", "--pilots=tarn", "--packs=run_down", "--answer=0",
			"--bot-no-mix=1", "--bot-no-visuals=1", "--bot-no-pilot-tracks=1"]
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	_check("the pack duel exits 0", code == 0)
	var rows := []
	if FileAccess.file_exists(out):
		for line in FileAccess.get_file_as_string(out).split("\n", false):
			var parsed = JSON.parse_string(line)
			if parsed is Dictionary:
				rows.append(parsed)
	_check("one pack row keyed pack:run_down with its pack, members and table", rows.size() == 1 and rows[0]["kind"] == "pack:run_down"
		and rows[0]["pack"] == "run_down" and rows[0]["table"] == "park" and (rows[0]["members"] as Array).size() == 4)
	if rows.is_empty():
		return
	var r: Dictionary = rows[0]
	_check("more than one member spawned", int(r.get("spawned", 0)) > 1)
	_check("the outcome is killed or capped", String(r["outcome"]) in ["killed", "capped"])
	if String(r["outcome"]) == "killed":
		_check("ttk_s covers the whole pack (not before the first member went down)", float(r["ttk_s"]) >= float(r["first_down_s"]) and float(r["first_down_s"]) >= 0.0)
	else:
		_check("a capped pack duel records no ttk", float(r["ttk_s"]) < 0.0)
	_pack_capped()


# An idle pilot cannot finish the pack inside a 30 s cap: live members must keep it from reading cleared. The
# cap is past the ~24 s the calm map's beacon needed to charge and change stage (the regression for the
# "killed, ttk -1, duel_s -10.61" rows), so the duel must run the whole cap on its own stage.
func _pack_capped() -> void:
	var out := OS.get_user_data_dir().path_join("matchup_lab_test").path_join("pack_capped.ndjson")
	if FileAccess.file_exists(out):
		DirAccess.remove_absolute(out)
	var output := []
	var args := ["--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/matchup_lab.gd", "--",
			"--out=" + out, "--procs=1", "--seeds=1", "--cap=30", "--idle=1", "--pilots=tarn", "--packs=run_down", "--answer=0",
			"--bot-no-mix=1", "--bot-no-visuals=1", "--bot-no-pilot-tracks=1"]
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var rows := []
	if FileAccess.file_exists(out):
		for line in FileAccess.get_file_as_string(out).split("\n", false):
			var parsed = JSON.parse_string(line)
			if parsed is Dictionary:
				rows.append(parsed)
	_check("an idle pilot on a 30 s cap leaves the pack alive: capped, ttk -1", code == 0 and rows.size() == 1 and rows[0]["outcome"] == "capped" and float(rows[0]["ttk_s"]) < 0.0)
	_check("the 30 s duel stays on its stage: stage_changed false and duel_s >= cap - 0.5", rows.size() == 1 and rows[0].get("stage_changed", true) == false and float(rows[0]["duel_s"]) >= 29.5)


func _perched_pure() -> void:
	_check("row keys are dispatcher@park and dispatcher@mast", Lab.perched_key("park") == "dispatcher@park" and Lab.perched_key("mast") == "dispatcher@mast"
		and Lab.perched_mode("dispatcher@mast") == "mast" and Lab.perched_mode("dispatcher") == "" and Lab.perched_mode("dispatcher@moat") == "")
	var both := Lab.perched_plan("park,mast", ["dispatcher"], false)
	_check("--perched=park,mast queues both rows in order", both["ok"] and both["kinds"] == ["dispatcher@park", "dispatcher@mast"])
	_check("a duplicate mode queues one row", Lab.perched_plan("mast,mast", ["dispatcher"], false)["kinds"] == ["dispatcher@mast"])
	_check("planted negative: another kind, several kinds, packs or an unknown mode are usage errors",
		not Lab.perched_plan("park", ["chaser"], false)["ok"] and not Lab.perched_plan("park", ["dispatcher", "chaser"], false)["ok"]
		and not Lab.perched_plan("park", ["dispatcher"], true)["ok"] and not Lab.perched_plan("roof", ["dispatcher"], false)["ok"]
		and not Lab.perched_plan("", ["dispatcher"], false)["ok"])
	var rows := [_row("a", "dispatcher@park", 1, 3.0), _row("a", "dispatcher@park", 2, 5.0)]
	rows.append({"pilot": "a", "kind": "dispatcher@park", "seed": 3, "outcome": "no_perch", "ttk_s": -1.0, "hull_lost": 0.0})
	var table := Lab.build_table(rows, ["a"], ["dispatcher@park"], 40.0)
	_check("no_perch counts as no result, not a capped duel", table["cells"]["a|dispatcher@park"]["runs"] == 2
		and is_equal_approx(float(table["cells"]["a|dispatcher@park"]["median_ttk"]), 4.0))
	_check("an all-no_perch table cell reads as no runs", Lab.build_table([rows[2]], ["a"], ["dispatcher@park"], 40.0)["cells"]["a|dispatcher@park"]["runs"] == 0)
	var kid := Lab.child_args({"pilot": "tarn", "kind": "dispatcher@mast", "seed": 1, "give": "", "n": 0}, 40.0, {}, "park", "/x", "/p")
	_check("a perched child gets --perched= and no --table=", "--perched=mast" in kid and not Array(kid).any(func(a): return String(a).begins_with("--table=")))
	var np := {"pilot": "a", "kind": "dispatcher@park", "seed": 4, "outcome": "not_perched", "ttk_s": -1.0, "hull_lost": 0.0}
	var with_np := Lab.build_table([rows[0], rows[1], np], ["a"], ["dispatcher@park"], 40.0)
	_check("not_perched is a no-result outcome and build_table drops its row", "not_perched" in Lab.NO_RESULT and with_np["cells"]["a|dispatcher@park"]["runs"] == 2
		and Lab.build_table([np], ["a"], ["dispatcher@park"], 40.0)["cells"]["a|dispatcher@park"]["runs"] == 0)
	_check("perched labels stay distinct in 9 chars", Lab.row_label("dispatcher@park") == "disp@park" and Lab.row_label("dispatcher@mast") == "disp@mast")
	# --from: kind rows, then pack rows, then perched rows, each first-seen.
	var dir := OS.get_user_data_dir().path_join("matchup_lab_test")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("from_perched.ndjson")
	var f := FileAccess.open(path, FileAccess.WRITE)
	for s in [1, 2]:
		f.store_line(JSON.stringify(_row("tarn", "dispatcher@mast", s, 9.0)))
		f.store_line(JSON.stringify(_row("tarn", "dispatcher@park", s, 3.0)))
		f.store_line(JSON.stringify(_row("tarn", "pack:grounded", s, 6.0)))
		f.store_line(JSON.stringify(_row("tarn", "lobber", s, 2.0)))
	f.close()
	var output := []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/matchup_lab.gd", "--",
			"--from=" + path, "--out=" + dir.path_join("from_perched.txt")], output, true)
	var text := "\n".join(output)
	var lobber := text.find("lobber ")
	var pack := text.find("+grounded")
	var mast := text.find("disp@mast")
	var park := text.find("disp@park")
	_check("--from lists kind, pack, then perched rows in first-seen order", code == 0 and lobber >= 0 and pack > lobber and mast > pack and park > mast)


# Two real perched duels (1 pilot, seed 4 and a low cap). Seed 4's standoff is both clear and under the top on park_dam with the canyon walls
# (#488, read at 814a53ad: 15 m out, the Dispatcher 11.5 m over the ball); seed 2, pinned before them, now finds no standoff spot (not_perched). The park row stands the Dispatcher on a real
# perch top with no mast; the mast row, planted as the negative, builds one.
func _perched_duel() -> void:
	var out := OS.get_user_data_dir().path_join("matchup_lab_test").path_join("perched.ndjson")
	if FileAccess.file_exists(out):
		DirAccess.remove_absolute(out)
	var output := []
	var args := ["--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/matchup_lab.gd", "--",
			"--out=" + out, "--procs=1", "--seeds=4", "--cap=10", "--pilots=tarn", "--kinds=dispatcher", "--perched=park,mast", "--answer=0",
			"--bot-no-mix=1", "--bot-no-visuals=1", "--bot-no-pilot-tracks=1"]
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	_check("the perched duels exit 0", code == 0)
	var by := {}
	if FileAccess.file_exists(out):
		for line in FileAccess.get_file_as_string(out).split("\n", false):
			var parsed = JSON.parse_string(line)
			if parsed is Dictionary:
				by[String(parsed["kind"])] = parsed
	_check("one row per mode", by.size() == 2 and by.has("dispatcher@park") and by.has("dispatcher@mast"))
	if by.size() != 2:
		return
	var park: Dictionary = by["dispatcher@park"]
	var mast: Dictionary = by["dispatcher@mast"]
	_check("the park row found a finite perch (not no_perch)", String(park["outcome"]) != "no_perch" and (park["perch"] as Array).size() == 3)
	_check("park: no mast was built", park["mast_built"] == false)
	_check("park: the chosen top is one of PerchPoints' tops (6 to 10 m over its base)", float(park["perch_base_rise_m"]) >= 5.99 and float(park["perch_base_rise_m"]) <= 10.01
		and park["perch_source"] in ["post", "ledge"])
	for row: Dictionary in [park, mast]:
		_check("%s: the Dispatcher stands at least PERCH_MIN over the ball at the spawn (perched_under)" % row["kind"],
			float(row["perch_over_ball_m"]) >= Lab.PerchPoints.PERCH_MIN and row["perched_under"] == true)
	_check("park: the row records its perch fields", park.has("ball_to_perch_m") and park.has("drops") and park.has("landed_hits")
		and park.has("escalation") and park.has("relocated") and park.has("dispatcher_down_s"))
	_check("contrast row: the mast row builds its own mast, 8 m up", mast["mast_built"] == true and is_equal_approx(float(mast["perch_rise_m"]), 8.0))
	# A relocated ball is held at its standoff until the spawn, level or not (seed 4's is level: standoff_ok true).
	for row: Dictionary in [park, mast]:
		_check("%s: a relocated ball was held and stood within 3 m of its standoff at the spawn" % row["kind"], row["relocated"] == true and row["held"] == true
			and absf(float(row["ball_to_perch_m"]) - float(row["standoff_m"])) <= 3.0)
	# A not_perched row that found no standoff spot carries no standoff fields: read them with .get so it fails as a check.
	_check("both rows' standoff spots are clear of landform footprints", park.get("standoff_clear") == true and mast.get("standoff_clear") == true)
	print("perched park perch_over_ball_m=%s standoff_m=%s standoff_ok=%s b2p=%s" % [park["perch_over_ball_m"], park.get("standoff_m"), park.get("standoff_ok"), park["ball_to_perch_m"]])
	_check("both rows chose the same top", park["perch"] == mast["perch"])


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
