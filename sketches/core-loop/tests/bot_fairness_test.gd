# smoke: bots timeout=1700s
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const BotFairness := preload("res://tools/bot_fairness.gd")
const TelegraphRecord := preload("res://src/combat/telegraph_record.gd")
const T := preload("res://tests/support/t.gd")

const SEEDS := [40303, 40304, 40305, 40306]
const TICKS := 30000
const PARALLEL := 4
const TOL_SHARE := 0.15
const TOL_TAX := 0.5
const TOL_FIRST_HIT_S := 0.5

var _t := T.new("bot_fairness_test")
var _line := {}


func _initialize() -> void:
	_run.call_deferred()


func _row(owner: String, age: float, covers: bool, attack := "", id := 1) -> Dictionary:
	return {"id": id, "owner": owner, "attack": attack, "age_s": age, "covers": covers}


const R2_ENVIRONMENT := ["cinder_floor", "pocket_veil", "start_pick", "special"]
const R2_BOSS_PREFIXES := ["brindle_", "waking_", "mind_"]


func _round2_classify(source: String, now: Array, before: Array, published: Dictionary) -> String:
	if source in _line.get("plantSources", []):
		return "untelegraphed"
	if source in R2_ENVIRONMENT or source == "":
		return "unknown"
	var owner := ""
	for prefix in R2_BOSS_PREFIXES:
		if source.begins_with(prefix):
			owner = "boss"
	var unowned: Array = _line.get("unownedSources", [])
	var publishes: bool = owner != "" or published.has(source) or source in unowned or not TelegraphRecord.row_of(source).is_empty()
	if not publishes:
		return "contact"
	for row in now + before:
		var mine: bool = row["owner"] == owner if owner == "boss" else (row["owner"] == source or (row["owner"] == "" and source in unowned))
		if mine and bool(row["covers"]) and float(row["age_s"]) >= float(_line["tellS"]):
			return "telegraphed"
	return "untelegraphed"


func _new_case(name: String, source: String, now: Array, published: Dictionary, want: String, cfg := {}) -> void:
	_t.eq(name, BotFairness.classify(source, now, [], published, cfg), want)
	var old := _round2_classify(source, now, [], published)
	_t.check("planted: the round 2 rule misreads '%s'" % name, old != want, "round 2 reads %s" % old)


func _fixtures() -> void:
	var tell := float(_line["tellS"])
	_t.check("the shared lines loaded", not _line.is_empty() and _line.has("telegraphShare") and _line.has("contactSources"), "%s" % [_line])
	var with_bump := _line.duplicate(true)
	with_bump["contactSources"] = ["bump"]
	_new_case("an unlisted source that matches nothing published is unknown, even in another enemy's old ring", "new_thing", [_row("chaser", 5.0, true)], {"chaser": true}, "unknown")
	_new_case("a source on contactSources is contact inside another enemy's old ring", "bump", [_row("chaser", 5.0, true)], {"chaser": true, "bump": true}, "contact", with_bump)
	_new_case("a charge whose own lane is younger than the tell is untelegraphed under an older slag ring", "brindle_charge", [_row("boss", tell - 0.2, true, "charge"), _row("boss", 3.0, true, "slag_ring_a")], {"boss": true}, "untelegraphed")
	_new_case("a boss source with no attack on bossAttacks is unknown, not judged by another attack's hazard", "waking_bore", [_row("boss", 3.0, true, "slag_ring_b")], {"boss": true}, "unknown")
	_t.eq("a shell younger than the tell inside another source's older ring is untelegraphed", BotFairness.classify("lobber", [_row("lobber", tell - 0.2, true), _row("mag_trapper", 3.0, true)], [], {"lobber": true, "mag_trapper": true}), "untelegraphed")
	_t.eq("the shell's own ring, old enough, is telegraphed", BotFairness.classify("lobber", [_row("lobber", tell + 0.4, true)], [], {"lobber": true}), "telegraphed")
	_t.eq("a ring that freed itself as it landed still counts from the tick before", BotFairness.classify("lobber", [], [_row("lobber", tell + 0.4, true)], {"lobber": true}), "telegraphed")
	_t.eq("a ring that does not cover the ball is not a tell", BotFairness.classify("chaser", [_row("chaser", 3.0, false)], [], {"chaser": true}), "untelegraphed")
	_t.eq("a charge with its own old lane over the ball is telegraphed", BotFairness.classify("brindle_charge", [_row("boss", 2.0, true, "charge")], [], {"boss": true}), "telegraphed")
	_t.eq("a slag hit with its own old ring over the ball is telegraphed", BotFairness.classify("brindle_slag", [_row("boss", 2.0, true, "slag_ring_b")], [], {"boss": true}), "telegraphed")
	_t.eq("a charge with its own young lane is untelegraphed", BotFairness.classify("brindle_charge", [_row("boss", 0.1, true, "charge")], [], {"boss": true}), "untelegraphed")
	_t.eq("an unowned ring is the Warden's own", BotFairness.classify("warden", [_row("", 2.0, true)], [], {}), "telegraphed")
	_t.eq("an unowned ring is not a pack unit's", BotFairness.classify("chaser", [_row("", 2.0, true)], [], {"chaser": true}), "untelegraphed")
	_t.eq("a planted drain is untelegraphed", BotFairness.classify("drain_plant", [_row("chaser", 5.0, true)], [], {}), "untelegraphed")
	_t.eq("a lightning theft under its own old ring is telegraphed", BotFairness.classify("lightning", [_row("world", 2.0, true, "lightning")], [], {}), "telegraphed")
	_t.eq("a lightning theft under another cause's old mark is untelegraphed", BotFairness.classify("lightning", [_row("world", 2.0, true, "impact")], [], {}), "untelegraphed")
	_t.eq("a boiler theft under a young hazard is untelegraphed", BotFairness.classify("boiler_burst", [_row("world", tell - 0.2, true, "boiler_burst")], [], {}), "untelegraphed")
	_t.eq("a crane theft under the crane's own old sweep is telegraphed", BotFairness.classify("crane", [_row("boss", 2.0, true, "crane_0")], [], {"boss": true}), "telegraphed")
	_t.eq("the scrap plant is untelegraphed", BotFairness.classify("scrap_plant", [_row("world", 5.0, true, "lightning")], [], {}), "untelegraphed")
	_t.eq("an environment source has no owner to match", BotFairness.classify("cinder_floor", [], [], {}), "unknown")
	var pair_both_old := [_row("chaser", 2.0, true, "", 101), _row("chaser", 2.0, true, "", 102)]
	var consumed := {}
	var m1 := BotFairness.classify_with_id("chaser", pair_both_old, [], {"chaser": true}, {}, 0, consumed)
	consumed[int(m1["matched_id"])] = true
	var m2 := BotFairness.classify_with_id("chaser", pair_both_old, [], {"chaser": true}, {}, 0, consumed)
	_t.check("two simultaneous old tells with one cause match distinct warning ids",
		m1["bucket"] == "telegraphed" and m2["bucket"] == "telegraphed" and int(m1["matched_id"]) != int(m2["matched_id"]),
		"m1 %s m2 %s" % [m1, m2])
	var pair_mixed := [_row("chaser", 2.0, true, "", 201), _row("chaser", tell - 0.2, true, "", 202)]
	_t.eq("explicit warning id matches its own old tell", BotFairness.classify("chaser", pair_mixed, [], {"chaser": true}, {}, 201), "telegraphed")
	_t.eq("explicit warning id refuses a sibling's older tell for a young warning", BotFairness.classify("chaser", pair_mixed, [], {"chaser": true}, {}, 202), "untelegraphed")
	var mixed_consumed := {}
	var first_hit := BotFairness.classify_with_id("chaser", pair_mixed, [], {"chaser": true}, {}, 0, mixed_consumed)
	mixed_consumed[int(first_hit["matched_id"])] = true
	var second_hit := BotFairness.classify_with_id("chaser", pair_mixed, [], {"chaser": true}, {}, 0, mixed_consumed)
	_t.check("same-tick pair with one old and one young tell credits the old tell once and flags the second",
		first_hit["bucket"] == "telegraphed" and int(first_hit["matched_id"]) == 201 and second_hit["bucket"] == "untelegraphed",
		"first %s second %s" % [first_hit, second_hit])
	_t.check("planted: the round 2 rule misreads a young sibling tell under an older same-cause tell",
		_round2_classify("chaser", pair_mixed, [], {"chaser": true}) == "telegraphed",
		"round 2 reads %s" % _round2_classify("chaser", pair_mixed, [], {"chaser": true}))
	var pooled_fixture := BotFairness.pool([
		{"hull": {"telegraphed": 80.0, "untelegraphed": 0.0, "contact": 0.0, "unknown": 0.0}, "scrap": {"telegraphed": 0.0, "untelegraphed": 0.0, "contact": 0.0, "unknown": 0.0}, "hit_sources": {"chaser": 80.0}, "scrap_sources": {}, "slow_s": 20.0, "fast_s": 10.0, "slow_hull": 80.0, "fast_hull": 0.0, "slow_scrap": 0.0, "fast_scrap": 0.0, "hull_lost": 80.0, "first_hit": {"s1": {"contact": true, "first_hit_s": 6.0, "opened_by_hit": false, "hit": true}}},
		{"hull": {"telegraphed": 100.0, "untelegraphed": 0.0, "contact": 0.0, "unknown": 0.0}, "scrap": {"telegraphed": 0.0, "untelegraphed": 0.0, "contact": 0.0, "unknown": 0.0}, "hit_sources": {"warden": 100.0}, "scrap_sources": {}, "slow_s": 30.0, "fast_s": 20.0, "slow_hull": 70.0, "fast_hull": 30.0, "slow_scrap": 0.0, "fast_scrap": 0.0, "hull_lost": 100.0, "first_hit": {"s1": {"contact": true, "first_hit_s": 10.0, "opened_by_hit": false, "hit": true}}},
	])
	_t.check("pooling combines a zero-fast-hull seed with nonzero seeds into a measured stop tax",
		pooled_fixture["stop_tax"] == 3.0 and pooled_fixture["telegraph_share"] == 1.0 and BotFairness.first_hit_of(pooled_fixture) == 8.0,
		"%s" % [pooled_fixture])


func _args(out: String, seed_val: int, plant: String) -> Array:
	var args := ["--out=" + out, "--policy=skipper", "--seeds=%d" % seed_val, "--until=1", "--band=novice", "--attempt=1", "--ticks=%d" % TICKS]
	if plant != "":
		args.append("--plant=" + plant)
	return args


func _run() -> void:
	_line = BotFairness.config()
	_fixtures()
	var base := OS.get_user_data_dir().path_join("bot-fairness-%d" % OS.get_process_id())
	var arms := {"plain": "", "drain": "drain=0.2", "fast_tax": "fast_tax=0.6", "ringless": "ringless=0.3", "scrap": "scrap=0.5"}
	var jobs := []
	var job_meta := []
	for name in arms:
		for seed_val in SEEDS:
			var run_dir: String = base.path_join("%s-%d" % [name, seed_val])
			jobs.append({
				"script": "res://tools/bot_run.gd",
				"home": run_dir,
				"args": _args(run_dir, seed_val, arms[name]),
			})
			job_meta.append({"arm": name, "seed": seed_val, "dir": run_dir})
	var results := ChildRuns.run(jobs, 1500.0, PARALLEL)
	var by_arm := {}
	for name in arms:
		by_arm[name] = []
	for idx in results.size():
		var meta: Dictionary = job_meta[idx]
		var name: String = meta["arm"]
		var seed_val: int = meta["seed"]
		var run_dir: String = meta["dir"]
		var result: Dictionary = results[idx]
		_t.check("%s seed %d child ran" % [name, seed_val], result["code"] == 0 and not result["timed_out"], "exit %s, timeout %s" % [result["code"], result["timed_out"]])
		var path: String = run_dir.path_join("bots.ndjson")
		var rows := FileAccess.get_file_as_string(path).split("\n", false) if FileAccess.file_exists(path) else PackedStringArray()
		var row = JSON.parse_string(rows[-1]) if rows.size() > 0 else null
		var f = row.get("fairness") if row is Dictionary else null
		_t.check("%s seed %d record carries fairness" % [name, seed_val], f is Dictionary, "%d rows in %s" % [rows.size(), path])
		if f is Dictionary:
			(by_arm[name] as Array).append(f)
	var fair := {}
	for name in arms:
		fair[name] = BotFairness.pool(by_arm[name])
		print("%s (pooled %d seeds): %s" % [name, (by_arm[name] as Array).size(), JSON.stringify(fair[name])])
	_plain(fair["plain"])
	var plain := BotFairness.baseline(fair["plain"])
	var f1: float = plain["share"]
	var f2: float = plain["stop_tax"]
	var f3: float = plain["first_hit"]
	_t.check("plain baseline measured a stop tax", plain["miss"] == "", "%s" % [plain["miss"]])
	_drain(fair["drain"], f1, f2, f3)
	_fast_tax(fair["fast_tax"], f1, f2, f3)
	_ringless(fair["ringless"], f1, f2, f3)
	_scrap(fair["scrap"], f1, f2, f3)
	if _t.failures == 0:
		_remove(base)
	quit(_t.verdict())


func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	for folder in DirAccess.get_directories_at(path):
		_remove(path.path_join(folder))
	DirAccess.remove_absolute(path)


func _share(f: Dictionary) -> float:
	return BotFairness.share_of(f)


func _first_hit(f: Dictionary) -> float:
	return BotFairness.first_hit_of(f)


func _plain(f: Dictionary) -> void:
	var hull: Dictionary = f.get("hull", {})
	var total := 0.0
	for k in hull:
		total += float(hull[k])
	var scrap: Dictionary = f.get("scrap", {})
	for k in scrap:
		total += float(scrap[k])
	hull = hull.duplicate()
	for k in scrap:
		hull[k] = float(hull.get(k, 0.0)) + float(scrap[k])
	var shares := {}
	for k in hull:
		shares[k] = snappedf(float(hull[k]) / maxf(total, 0.001), 0.001)
	print("unplanted bucket shares of %.1f hull: %s" % [total, JSON.stringify(shares)])
	_t.check("unplanted lost hull to measure", total > 0.0, "hull %s" % [hull])
	_t.check("unplanted unknown hull is within the share the mark needs", float(shares.get("unknown", 1.0)) <= float(_line["unknownMaxShare"]), "unknown %s" % [shares.get("unknown")])
	_t.check("unplanted F1 is measured and on the passing side", _share(f) >= float(_line["telegraphShare"]), "share %s" % [f.get("telegraph_share")])
	_t.check("unplanted F2 is measured (hull lost at cruise and slow) and on the passing side", f.get("stop_tax") != null and float(f["stop_tax"]) >= float(_line["stopTax"]), "stop_tax %s, slow %s hull / %s s, fast %s hull / %s s" % [f.get("stop_tax"), f.get("slow_hull"), f.get("slow_s"), f.get("fast_hull"), f.get("fast_s")])
	_t.check("unplanted F3 is measured and on the passing side", _first_hit(f) >= float(_line["firstHitS"]), "first_hit %s" % [f.get("first_hit")])


func _others(name: String, f: Dictionary, f1: float, f2: float, f3: float, skip: String) -> void:
	if skip != "F1":
		_t.check("%s leaves F1 within %.2f" % [name, TOL_SHARE], f.get("telegraph_share") != null and absf(_share(f) - f1) <= TOL_SHARE, "planted %s, unplanted %s" % [f.get("telegraph_share"), f1])
	if skip != "F2":
		if f2 < 0.0:
			_t.check("%s leaves F2 within %.0f%%: not judged, the plain baseline measured no stop tax" % [name, TOL_TAX * 100.0], false, "unplanted %s" % [f2])
		else:
			_t.check("%s leaves F2 within %.0f%%" % [name, TOL_TAX * 100.0], f.get("stop_tax") != null and absf(float(f["stop_tax"]) - f2) <= TOL_TAX * f2, "planted %s, unplanted %s" % [f.get("stop_tax"), f2])
	if skip != "F3":
		_t.check("%s leaves F3 within %.1f s" % [name, TOL_FIRST_HIT_S], _first_hit(f) >= 0.0 and absf(_first_hit(f) - f3) <= TOL_FIRST_HIT_S, "planted %s, unplanted %s" % [_first_hit(f), f3])


func _drain(f: Dictionary, f1: float, f2: float, f3: float) -> void:
	_t.check("F1 drops below the line with the drain planted", f.get("telegraph_share") != null and _share(f) < float(_line["telegraphShare"]), "share %s" % [f.get("telegraph_share")])
	_t.check("F1 planted reads below unplanted", f.get("telegraph_share") != null and _share(f) < f1, "planted %s, unplanted %s" % [f.get("telegraph_share"), f1])
	_others("drain", f, f1, f2, f3, "F1")


func _fast_tax(f: Dictionary, f1: float, f2: float, f3: float) -> void:
	_t.check("F2 falls below the line with the fast-ball tax", f.get("stop_tax") != null and float(f["stop_tax"]) < float(_line["stopTax"]), "stop_tax %s" % [f.get("stop_tax")])
	if f2 < 0.0:
		_t.check("F2 planted reads below unplanted: not judged, the plain baseline measured no stop tax", false, "unplanted %s" % [f2])
	else:
		_t.check("F2 planted reads below unplanted", f.get("stop_tax") != null and float(f["stop_tax"]) < f2, "planted %s, unplanted %s" % [f.get("stop_tax"), f2])
	_others("fast_tax", f, f1, f2, f3, "F2")


func _ringless(f: Dictionary, f1: float, f2: float, f3: float) -> void:
	var v := _first_hit(f)
	_t.check("F3 drops below the line with the ringless spawn", v >= 0.0 and v < float(_line["firstHitS"]), "first_hit %s" % [f.get("first_hit")])
	_t.check("F3 planted reads below unplanted", v >= 0.0 and v < f3, "planted %s, unplanted %s" % [v, f3])
	_others("ringless", f, f1, f2, f3, "F3")


func _scrap(f: Dictionary, f1: float, f2: float, f3: float) -> void:
	var pooled = f.get("pooled_share")
	_t.check("F1's pooled share drops below the line with the scrap theft planted", pooled != null and float(pooled) < float(_line["telegraphShare"]), "pooled %s" % [pooled])
	_t.check("F1's pooled share reads below unplanted", pooled != null and float(pooled) < f1, "planted %s, unplanted %s" % [pooled, f1])
	_t.check("the planted theft is in the scrap record", float(f.get("scrap_sources", {}).get("scrap_plant", 0.0)) > 0.0, "scrap_sources %s" % [f.get("scrap_sources")])
	var planted := float(f.get("scrap_sources", {}).get("scrap_plant", 0.0))
	var split := float(f.get("slow_scrap", -1.0)) + float(f.get("fast_scrap", -1.0))
	_t.check("slow and fast scrap sum to the scrap stolen", absf(split - planted) <= 0.15, "slow %s + fast %s, stolen %s" % [f.get("slow_scrap"), f.get("fast_scrap"), planted])
	var hull_split := float(f.get("slow_hull", -1.0)) + float(f.get("fast_hull", -1.0))
	_t.check("slow and fast hull sum to hull_lost", absf(hull_split - float(f.get("hull_lost", -2.0))) <= 0.15, "slow %s + fast %s, lost %s" % [f.get("slow_hull"), f.get("fast_hull"), f.get("hull_lost")])
	_others("scrap", f, f1, f2, f3, "F2")
