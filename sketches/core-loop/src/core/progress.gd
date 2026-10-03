extends Node

# The achievement listener. It reads Achievements.ROWS, connects to the bus signals the
# rows name (plus world_entered, player_died and run_ended), counts each matching fact,
# earns a row once, saves the profile and announces the earn on the bus. The profile has
# no bus knowledge; this node is the only place the two meet.
#
# A fact is the signal's arguments keyed by their declared names. A row matches when every
# where key equals the fact's value; sum adds the named argument instead of 1. Counts are
# lifetime and live in the profile's stats under "ach.<id>". need, min and max compare
# run.summary() at the moment of the fact (parts by size) or the evaluator keys: class (the
# class id), won (run_ended's argument, false before it) and world (the last world_entered).

const Achievements := preload("res://src/core/achievements.gd")

const STAT_PREFIX := "ach."
const SAVE_POINTS := ["player_died", "run_ended"]

# The table to read. A test sets its own before setup.
var rows: Dictionary = Achievements.ROWS

# Earns whose save failed, for a test or a screen that wants to say so.
var warnings := 0

var _events
var _run
var _profile
var _now := Callable()
var _world := 0
var _won := false
var _rows_on := {}


func setup(events, run, profile, now := Callable()) -> void:
	_events = events
	_run = run
	_profile = profile
	_now = now if now.is_valid() else Callable(Time, "get_unix_time_from_system")
	_rows_on.clear()
	for id in rows:
		var on := String(rows[id].get("on", ""))
		if not _rows_on.has(on):
			_rows_on[on] = []
		_rows_on[on].append(id)
	var wanted := {"world_entered": true, "run_started": true}
	for on in _rows_on:
		wanted[on] = true
	for on in SAVE_POINTS:
		wanted[on] = true
	var arg_names := {}
	for info in events.get_signal_list():
		var names: Array = []
		for arg in info["args"]:
			names.append(arg["name"])
		arg_names[info["name"]] = names
	for signal_name in wanted:
		if arg_names.has(signal_name):
			_connect(signal_name, arg_names[signal_name])


# The saved count toward a row (read-only), for the achievements page.
func count_of(id: String) -> float:
	return _profile.stat(STAT_PREFIX + id) if _profile != null else 0.0


# When a row was earned, as unix seconds, or 0 if it has not been.
func earned_at(id: String) -> int:
	if _profile == null:
		return 0
	return _profile.earned_at(id)


func _connect(signal_name: String, names: Array) -> void:
	var sig: Signal = Signal(_events, signal_name)
	match names.size():
		0:
			sig.connect(func(): _fact(signal_name, names, []))
		1:
			sig.connect(func(a): _fact(signal_name, names, [a]))
		2:
			sig.connect(func(a, b): _fact(signal_name, names, [a, b]))
		3:
			sig.connect(func(a, b, c): _fact(signal_name, names, [a, b, c]))
		4:
			sig.connect(func(a, b, c, d): _fact(signal_name, names, [a, b, c, d]))
		_:
			push_warning("progress: %s has %d arguments; not listened to" % [signal_name, names.size()])


func _fact(signal_name: String, names: Array, values: Array) -> void:
	var fact := {}
	for i in names.size():
		fact[names[i]] = values[i]
	if signal_name == "world_entered":
		_world = int(fact.get("world", 0))
	elif signal_name == "run_started":
		_won = false
	elif signal_name == "run_ended":
		_won = bool(fact.get("won", false))
	for id in _rows_on.get(signal_name, []):
		_evaluate(id, fact)
	if SAVE_POINTS.has(signal_name) and _profile.can_save:
		_profile.save()
	if signal_name == "run_ended":
		_won = false


func _evaluate(id: String, fact: Dictionary) -> void:
	if _profile.earned(id):
		return
	var row: Dictionary = rows[id]
	var where: Dictionary = row.get("where", {})
	for key in where:
		if not fact.has(key) or fact[key] != where[key]:
			return
	var amount := 1.0
	if row.has("sum"):
		amount = float(fact.get(row["sum"], 0))
	_profile.add_stat(STAT_PREFIX + id, amount)
	if _profile.stat(STAT_PREFIX + id) < float(row.get("count", 1)):
		return
	if row.has("need") and not _need_met(row):
		return
	_earn(id, row)


func _need_met(row: Dictionary) -> bool:
	var key: String = row["need"]
	var value
	match key:
		"class":
			value = _run.class_id()
		"won":
			value = _won
		"world":
			value = _world
		_:
			value = _run.summary().get(key)
			if value is Array:
				value = value.size()
	if row.has("min") or row.has("max"):
		if not (value is int or value is float or value is bool):
			return false
		var number := float(value)
		if row.has("min") and number < float(row["min"]):
			return false
		if row.has("max") and number > float(row["max"]):
			return false
		return true
	# No bounds: the fact must be present (a class chosen, a run won, a world entered).
	if value is String:
		return value != ""
	if value is bool:
		return value
	return float(value) != 0.0


func _earn(id: String, row: Dictionary) -> void:
	if not _profile.earn(id, float(_now.call())):
		return
	var reward: Dictionary = row.get("reward", {})
	for kind in reward:
		var target := String(reward[kind])
		match kind:
			"pilot":
				_profile.unlock_pilot(target)
			"cosmetic":
				_profile.unlock_cosmetic(target)
			"world":
				_profile.unlock_world(target)
	if not _profile.save():
		warnings += 1
		push_warning("progress: %s earned but not saved: %s" % [id, _profile.last_error])
	_events.achievement_earned.emit(id)
