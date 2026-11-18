# smoke: bots timeout=1700s
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const BotFairness := preload("res://tools/bot_fairness.gd")
const TelegraphRecord := preload("res://src/combat/telegraph_record.gd")
const T := preload("res://tests/support/t.gd")

# The bot record's fairness numbers (tools/bot_fairness.gd) and their planted controls (tools/bot_plants.gd). The pass lines and
# the tell time are scripts/challenge/fairness.json's, read here and nowhere else.
#
# Part 1, fixtures: the classifier on hand-made telegraph reads, so the cases a live seed does not make still run (an unlisted
# source reads unknown, a listed contact source in another enemy's old ring, a young charge lane under an older slag ring, a
# young shell ring inside an old ring of another source). Each round 3 fixture also runs the frozen round 2 rule, which must
# misread it.
# Part 2, live: one seed on stage 1 (novice, which loses hull both moving and stopped), played unplanted and once per plant.
# Unplanted, every number is measured and on the passing side. Each plant moves its own number under the line and leaves the
# other two readings inside a stated tolerance of the unplanted run, so a plant proves its own reading and not the plumbing.
# A null is "not measured" and never a passing control.
#
# Run it by hand after any change under tools/bot_* or to the classifier (it is on the weekly list).
const SEED := 40301
const TICKS := 30000
# Tolerances against the unplanted run: F1 within 0.15 of the share (a plant's own hull is untelegraphed by construction, so it
# moves F1 by its share of the hull; the plants here add 2 to 4 hull to about 34), F2 within 50% of the ratio, F3 within 0.5 s.
const TOL_SHARE := 0.15
const TOL_TAX := 0.5
const TOL_FIRST_HIT_S := 0.5

var _t := T.new("bot_fairness_test")
var _line := {}


func _initialize() -> void:
	_run.call_deferred()


func _row(owner: String, age: float, covers: bool, attack := "") -> Dictionary:
	return {"id": 1, "owner": owner, "attack": attack, "age_s": age, "covers": covers}


# The round 2 rule (tools/bot_fairness.gd at 09364d29), frozen with that commit's lists: the planted control. Every fixture
# that the round 3 rule added must read differently here, so its pass cannot be true by construction.
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


# A round 3 fixture: the current rule must give `want`, and the frozen round 2 rule must not.
func _new_case(name: String, source: String, now: Array, published: Dictionary, want: String, cfg := {}) -> void:
	_t.eq(name, BotFairness.classify(source, now, [], published, cfg), want)
	var old := _round2_classify(source, now, [], published)
	_t.check("planted: the round 2 rule misreads '%s'" % name, old != want, "round 2 reads %s" % old)


func _fixtures() -> void:
	var tell := float(_line["tellS"])
	_t.check("the shared lines loaded", not _line.is_empty() and _line.has("telegraphShare") and _line.has("contactSources"), "%s" % [_line])
	# Round 3: unknown is what is left; contact needs a listing; a boss hit is matched to its own attack's hazards.
	var with_bump := _line.duplicate(true)
	with_bump["contactSources"] = ["bump"]
	_new_case("an unlisted source that matches nothing published is unknown, even in another enemy's old ring", "new_thing", [_row("chaser", 5.0, true)], {"chaser": true}, "unknown")
	_new_case("a source on contactSources is contact inside another enemy's old ring", "bump", [_row("chaser", 5.0, true)], {"chaser": true, "bump": true}, "contact", with_bump)
	_new_case("a charge whose own lane is younger than the tell is untelegraphed under an older slag ring", "brindle_charge", [_row("boss", tell - 0.2, true, "charge"), _row("boss", 3.0, true, "slag_ring_a")], {"boss": true}, "untelegraphed")
	_new_case("a boss source with no attack on bossAttacks is unknown, not judged by another attack's hazard", "waking_bore", [_row("boss", 3.0, true, "slag_ring_b")], {"boss": true}, "unknown")
	# Kept from round 2 under the round 3 rule.
	_t.eq("a shell younger than the tell inside another source's older ring is untelegraphed", BotFairness.classify("lobber", [_row("lobber", tell - 0.2, true), _row("mag_trapper", 3.0, true)], [], {"lobber": true, "mag_trapper": true}), "untelegraphed")
	_t.eq("the shell's own ring, old enough, is telegraphed", BotFairness.classify("lobber", [_row("lobber", tell + 0.4, true)], [], {"lobber": true}), "telegraphed")
	_t.eq("a ring that freed itself as it landed still counts from the tick before", BotFairness.classify("lobber", [], [_row("lobber", tell + 0.4, true)], {"lobber": true}), "telegraphed")
	_t.eq("a ring that does not cover the ball is not a tell", BotFairness.classify("chaser", [_row("chaser", 3.0, false)], [], {"chaser": true}), "untelegraphed")
	# Replaces round 2's "a boss hit with an old hazard over the ball is telegraphed" (any boss row counted): only the
	# landing attack's own hazard counts now.
	_t.eq("a charge with its own old lane over the ball is telegraphed", BotFairness.classify("brindle_charge", [_row("boss", 2.0, true, "charge")], [], {"boss": true}), "telegraphed")
	_t.eq("a slag hit with its own old ring over the ball is telegraphed", BotFairness.classify("brindle_slag", [_row("boss", 2.0, true, "slag_ring_b")], [], {"boss": true}), "telegraphed")
	_t.eq("a charge with its own young lane is untelegraphed", BotFairness.classify("brindle_charge", [_row("boss", 0.1, true, "charge")], [], {"boss": true}), "untelegraphed")
	_t.eq("an unowned ring is the Warden's own", BotFairness.classify("warden", [_row("", 2.0, true)], [], {}), "telegraphed")
	_t.eq("an unowned ring is not a pack unit's", BotFairness.classify("chaser", [_row("", 2.0, true)], [], {"chaser": true}), "untelegraphed")
	_t.eq("a planted drain is untelegraphed", BotFairness.classify("drain_plant", [_row("chaser", 5.0, true)], [], {}), "untelegraphed")
	# Scrap causes (lose_scrap's own cause, read through the same rule): a world cause matches only a world telegraph of its own cause.
	_t.eq("a lightning theft under its own old ring is telegraphed", BotFairness.classify("lightning", [_row("world", 2.0, true, "lightning")], [], {}), "telegraphed")
	_t.eq("a lightning theft under another cause's old mark is untelegraphed", BotFairness.classify("lightning", [_row("world", 2.0, true, "impact")], [], {}), "untelegraphed")
	_t.eq("a boiler theft under a young hazard is untelegraphed", BotFairness.classify("boiler_burst", [_row("world", tell - 0.2, true, "boiler_burst")], [], {}), "untelegraphed")
	_t.eq("a crane theft under the crane's own old sweep is telegraphed", BotFairness.classify("crane", [_row("boss", 2.0, true, "crane_0")], [], {"boss": true}), "telegraphed")
	_t.eq("the scrap plant is untelegraphed", BotFairness.classify("scrap_plant", [_row("world", 5.0, true, "lightning")], [], {}), "untelegraphed")
	_t.eq("an environment source has no owner to match", BotFairness.classify("cinder_floor", [], [], {}), "unknown")
	_t.eq("a chaser hit under another chaser's old lane reads telegraphed (sources carry only the kind)", BotFairness.classify("chaser", [_row("chaser", 2.0, true)], [], {"chaser": true}), "telegraphed")


func _args(out: String, plant: String) -> Array:
	var args := ["--out=" + out, "--policy=skipper", "--seeds=%d" % SEED, "--until=1", "--band=novice", "--attempt=1", "--ticks=%d" % TICKS]
	if plant != "":
		args.append("--plant=" + plant)
	return args


func _run() -> void:
	_line = BotFairness.config()
	_fixtures()
	var base := OS.get_user_data_dir().path_join("bot-fairness-%d" % OS.get_process_id())
	var arms := {"plain": "", "drain": "drain=0.02", "fast_tax": "fast_tax=0.03", "ringless": "ringless=0.3", "scrap": "scrap=0.3"}
	var jobs := []
	for name in arms:
		jobs.append({"script": "res://tools/bot_run.gd", "args": _args(base.path_join(name), arms[name])})
	var results := ChildRuns.run(jobs, 1500.0, 2)
	var fair := {}
	var i := 0
	for name in arms:
		var result: Dictionary = results[i]
		i += 1
		_t.check("%s child ran" % name, result["code"] == 0 and not result["timed_out"], "exit %s, timeout %s" % [result["code"], result["timed_out"]])
		var path: String = base.path_join(name).path_join("bots.ndjson")
		var rows := FileAccess.get_file_as_string(path).split("\n", false) if FileAccess.file_exists(path) else PackedStringArray()
		var row = JSON.parse_string(rows[-1]) if rows.size() > 0 else null
		var f = row.get("fairness") if row is Dictionary else null
		_t.check("%s record carries fairness" % name, f is Dictionary, "%d rows in %s" % [rows.size(), path])
		fair[name] = f if f is Dictionary else {}
		print("%s: %s" % [name, JSON.stringify(fair[name])])
	_plain(fair["plain"])
	var f1: float = _share(fair["plain"])
	var f2: float = float(fair["plain"].get("stop_tax", 0.0))
	var f3: float = _first_hit(fair["plain"])
	_drain(fair["drain"], f1, f2, f3)
	_fast_tax(fair["fast_tax"], f1, f2, f3)
	_ringless(fair["ringless"], f1, f2, f3)
	_scrap(fair["scrap"], f1, f2, f3)
	quit(_t.verdict())


func _share(f: Dictionary) -> float:
	var v = f.get("telegraph_share")
	return float(v) if v != null else -1.0


func _first_hit(f: Dictionary) -> float:
	var seg = f.get("first_hit", {}).get("s1")
	if seg == null or seg.get("first_hit_s") == null:
		return -1.0
	return float(seg["first_hit_s"])


func _plain(f: Dictionary) -> void:
	var hull: Dictionary = f.get("hull", {})
	var total := 0.0
	for k in hull:
		total += float(hull[k])
	var shares := {}
	for k in hull:
		shares[k] = snappedf(float(hull[k]) / maxf(total, 0.001), 0.001)
	print("unplanted bucket shares of %.1f hull: %s" % [total, JSON.stringify(shares)])
	_t.check("unplanted lost hull to measure", total > 0.0, "hull %s" % [hull])
	_t.check("unplanted unknown hull is within the share the mark needs", float(shares.get("unknown", 1.0)) <= float(_line["unknownMaxShare"]), "unknown %s" % [shares.get("unknown")])
	_t.check("unplanted F1 is measured and on the passing side", _share(f) >= float(_line["telegraphShare"]), "share %s" % [f.get("telegraph_share")])
	_t.check("unplanted F2 is measured (hull lost at cruise and slow) and on the passing side", f.get("stop_tax") != null and float(f["stop_tax"]) >= float(_line["stopTax"]), "stop_tax %s, slow %s hull / %s s, fast %s hull / %s s" % [f.get("stop_tax"), f.get("slow_hull"), f.get("slow_s"), f.get("fast_hull"), f.get("fast_s")])
	_t.check("unplanted F3 is measured and on the passing side", _first_hit(f) >= float(_line["firstHitS"]), "first_hit %s" % [f.get("first_hit")])


# A plant must leave the readings it does not own where the unplanted run had them.
func _others(name: String, f: Dictionary, f1: float, f2: float, f3: float, skip: String) -> void:
	if skip != "F1":
		_t.check("%s leaves F1 within %.2f" % [name, TOL_SHARE], f.get("telegraph_share") != null and absf(_share(f) - f1) <= TOL_SHARE, "planted %s, unplanted %s" % [f.get("telegraph_share"), f1])
	if skip != "F2":
		_t.check("%s leaves F2 within %.0f%%" % [name, TOL_TAX * 100.0], f.get("stop_tax") != null and absf(float(f["stop_tax"]) - f2) <= TOL_TAX * f2, "planted %s, unplanted %s" % [f.get("stop_tax"), f2])
	if skip != "F3":
		_t.check("%s leaves F3 within %.1f s" % [name, TOL_FIRST_HIT_S], _first_hit(f) >= 0.0 and absf(_first_hit(f) - f3) <= TOL_FIRST_HIT_S, "planted %s, unplanted %s" % [_first_hit(f), f3])


func _drain(f: Dictionary, f1: float, f2: float, f3: float) -> void:
	_t.check("F1 drops below the line with the drain planted", f.get("telegraph_share") != null and _share(f) < float(_line["telegraphShare"]), "share %s" % [f.get("telegraph_share")])
	_t.check("F1 planted reads below unplanted", f.get("telegraph_share") != null and _share(f) < f1, "planted %s, unplanted %s" % [f.get("telegraph_share"), f1])
	_others("drain", f, f1, f2, f3, "F1")


func _fast_tax(f: Dictionary, f1: float, f2: float, f3: float) -> void:
	_t.check("F2 falls below the line with the fast-ball tax", f.get("stop_tax") != null and float(f["stop_tax"]) < float(_line["stopTax"]), "stop_tax %s" % [f.get("stop_tax")])
	_t.check("F2 planted reads below unplanted", f.get("stop_tax") != null and float(f["stop_tax"]) < f2, "planted %s, unplanted %s" % [f.get("stop_tax"), f2])
	_others("fast_tax", f, f1, f2, f3, "F2")


func _ringless(f: Dictionary, f1: float, f2: float, f3: float) -> void:
	var v := _first_hit(f)
	_t.check("F3 drops below the line with the ringless spawn", v >= 0.0 and v < float(_line["firstHitS"]), "first_hit %s" % [f.get("first_hit")])
	_t.check("F3 planted reads below unplanted", v >= 0.0 and v < f3, "planted %s, unplanted %s" % [v, f3])
	_others("ringless", f, f1, f2, f3, "F3")


# Scrap taken through run.lose_scrap with no telegraph (the plant's cause) is a loss the three lines must see: F1 drops below the line.
# F2 and F3 are hull readings and stay where they were.
func _scrap(f: Dictionary, f1: float, f2: float, f3: float) -> void:
	_t.check("F1 drops below the line with the scrap theft planted", f.get("telegraph_share") != null and _share(f) < float(_line["telegraphShare"]), "share %s" % [f.get("telegraph_share")])
	_t.check("F1 planted reads below unplanted", f.get("telegraph_share") != null and _share(f) < f1, "planted %s, unplanted %s" % [f.get("telegraph_share"), f1])
	_t.check("the planted theft is in the scrap record", float(f.get("scrap_sources", {}).get("scrap_plant", 0.0)) > 0.0, "scrap_sources %s" % [f.get("scrap_sources")])
