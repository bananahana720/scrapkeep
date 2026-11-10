# smoke: bots timeout=1500s
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")

# The bot record's fairness numbers (tools/bot_driver.gd _fair_record) and their planted controls (tools/bot_plants.gd):
# F1 telegraph share >= 0.95, F2 stop tax >= 2.0, F3 first hit >= 3 s (project-guide/handoff/shared/world1/difficulty-plan.md).
# One seed on stage 1, played four times: unplanted, then each plant on its own (drain, fast_tax, ringless; rut fires only on a circling ball, which a skipper never is). Each plant must move its own number the
# wrong way, so a pass is not the default. A number the unplanted game is under the line on today is printed as OWED (the
# line is not lowered); a number nobody measured fails here, because null is not a pass.
const SEED := 1
const TICKS := 18000
const LINE_SHARE := 0.95
const LINE_TAX := 2.0
const LINE_FIRST_HIT_S := 3.0

var _t := T.new("bot_fairness_test")


func _initialize() -> void:
	_run.call_deferred()


func _args(out: String, plant: String) -> Array:
	var args := ["--out=" + out, "--policy=skipper", "--seeds=%d" % SEED, "--until=1", "--band=expert", "--ticks=%d" % TICKS]
	if plant != "":
		args.append("--plant=" + plant)
	return args


func _run() -> void:
	var base := OS.get_user_data_dir().path_join("bot-fairness-%d" % OS.get_process_id())
	var arms := {"plain": "", "drain": "drain=1", "fast_tax": "fast_tax=1", "ringless": "ringless=1"}
	var jobs := []
	for name in arms:
		jobs.append({"script": "res://tools/bot_run.gd", "args": _args(base.path_join(name), arms[name])})
	var results := ChildRuns.run(jobs, 1200.0, 2)
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
	_share(fair)
	_tax(fair)
	_first_hit(fair)
	quit(_t.verdict())


# F1: an untelegraphed drain moves the share under the line, and under what the game reads without it.
func _share(fair: Dictionary) -> void:
	var plain = fair["plain"].get("telegraph_share")
	var planted = fair["drain"].get("telegraph_share")
	_t.check("F1 is measured planted", planted != null, "telegraph_share %s" % [planted])
	if planted != null:
		_t.check("F1 drops below %.2f with the drain planted" % LINE_SHARE, float(planted) < LINE_SHARE, "share %s" % [planted])
	_owed("F1 telegraph share", plain, float(plain) >= LINE_SHARE if plain != null else false, ">= %.2f" % LINE_SHARE)
	if plain != null and planted != null:
		_t.check("F1 planted reads below unplanted", float(planted) < float(plain), "planted %s, unplanted %s" % [planted, plain])


# F2: a tax on fast balls pulls the ratio under the line.
func _tax(fair: Dictionary) -> void:
	var plain = fair["plain"].get("stop_tax")
	var planted = fair["fast_tax"].get("stop_tax")
	_t.check("F2 is measured planted", planted != null, "stop_tax %s, parts %s" % [planted, fair["fast_tax"]])
	if planted != null:
		_t.check("F2 falls below %.1f with the fast-ball tax" % LINE_TAX, float(planted) < LINE_TAX, "stop_tax %s" % [planted])
	if plain == null and float(fair["plain"].get("fast_hull", -1.0)) == 0.0 and float(fair["plain"].get("slow_hull", 0.0)) > 0.0:
		# Hull lost only below cruise: the ratio has no finite value and is as far on the passing side as it goes.
		print("F2 stop tax unplanted on seed %d: no hull lost at cruise (slow %s hull in %s s), on the passing side (line >= %.1f)" % [SEED, fair["plain"]["slow_hull"], fair["plain"]["slow_s"], LINE_TAX])
	else:
		_owed("F2 stop tax", plain, float(plain) >= LINE_TAX if plain != null else false, ">= %.1f" % LINE_TAX)
	if plain != null and planted != null:
		_t.check("F2 planted reads below unplanted", float(planted) < float(plain), "planted %s, unplanted %s" % [planted, plain])


# F3: a spawn with no ring lands the first hit at contact.
func _first_hit(fair: Dictionary) -> void:
	var plain = fair["plain"].get("first_hit_s")
	var planted = fair["ringless"].get("first_hit_s")
	_t.check("F3 is measured planted", planted != null, "first_hit_s %s" % [planted])
	if planted != null:
		_t.check("F3 drops below %.0f s with the ringless spawn" % LINE_FIRST_HIT_S, float(planted) < LINE_FIRST_HIT_S, "first_hit_s %s" % [planted])
	_owed("F3 first hit", plain, float(plain) >= LINE_FIRST_HIT_S if plain != null else false, ">= %.0f s" % LINE_FIRST_HIT_S)
	if plain != null and planted != null:
		_t.check("F3 planted reads below unplanted", float(planted) < float(plain), "planted %s, unplanted %s" % [planted, plain])


# Unplanted, the number is on the passing side or the output says what the game reads: OWED, not a failure, the line stays.
func _owed(label: String, value, passes: bool, line: String) -> void:
	if value == null:
		print("OWED: %s was not measured unplanted on seed %d (no hull lost, or no contact); line %s" % [label, SEED, line])
	elif passes:
		print("%s unplanted on seed %d: %s, on the passing side (line %s)" % [label, SEED, value, line])
	else:
		print("OWED: %s unplanted on seed %d reads %s, under the line %s" % [label, SEED, value, line])
