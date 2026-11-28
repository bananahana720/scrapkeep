extends RefCounted

const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const SourceScan := preload("res://tests/support/source_scan.gd")
const FORBIDDEN := "\\bNode\\b|[Pp]rofile|res://src/(movement|combat|build|world|boss)"

# The achievement table reads the real bus, pilots and cosmetics, and each rule is shown
# able to fail on a row built here.


func _pilots() -> Array:
	var ids: Array = []
	for def in ClassDef.all():
		ids.append(def.id)
	return ids


func _base_rows() -> Dictionary:
	var rows := {}
	for i in range(Achievements.MIN_ROWS):
		rows["pad_%d" % i] = {"name": "Pad", "text": "Do a thing.", "on": "run_ended", "count": 1, "reward": {}}
	return rows


func _bad(t, label: String, patch: Dictionary, rule: String, pilots: Array = []) -> void:
	var rows := _base_rows()
	var r: Dictionary = rows["pad_0"].duplicate(true)
	for key in patch:
		if patch[key] == null:
			r.erase(key)
		else:
			r[key] = patch[key]
	rows["pad_0"] = r
	var seen: Array = pilots if not pilots.is_empty() else _pilots()
	var problems := Achievements.validate(rows, Achievements.bus_signals(), seen, Cosmetics.ids())
	var named := false
	for p in problems:
		if p.begins_with("pad_0:") and p.contains(rule):
			named = true
	t.check(label, named, "problems %s (need one naming pad_0 and %s)" % [problems, rule])


func run(t) -> void:
	var signals := Achievements.bus_signals()
	var problems := Achievements.validate(Achievements.ROWS, signals, _pilots(), Cosmetics.ids())
	t.check("the real table validates clean", problems.is_empty(), "problems %s" % [problems])
	t.check("the table has at least 8 rows", Achievements.ROWS.size() >= 8, "%d rows" % Achievements.ROWS.size())
	t.check("the signal reader sees the bus", signals.has("enemy_killed") and signals["enemy_killed"].has("kind"), "enemy_killed args %s" % [signals.get("enemy_killed")])
	t.eq("no starter row rewards a pilot yet", Achievements.for_pilot("pylon_engineer"), "")
	t.eq("reward_of reads a row", Achievements.reward_of("warden_broken"), {"cosmetic": "paint_any_night"})

	t.check("fixture control: the padding rows validate clean", Achievements.validate(_base_rows(), signals, _pilots(), Cosmetics.ids()).is_empty(), "padding rows are not clean")
	_bad(t, "bad: an undeclared signal is refused", {"on": "no_such_signal"}, "not a declared signal")
	_bad(t, "bad: a where key off the signal is refused", {"where": {"nope": 1}}, "where key")
	_bad(t, "bad: a sum key off the signal is refused", {"sum": "nope"}, "sum")
	_bad(t, "bad: a count of zero is refused", {"count": 0}, "count")
	_bad(t, "bad: an unknown need is refused", {"need": "nope"}, "need")
	_bad(t, "bad: two reward kinds are refused", {"reward": {"cosmetic": "paint_any_salt", "world": "gorge"}}, "at most one kind")
	_bad(t, "bad: an unknown cosmetic reward is refused", {"reward": {"cosmetic": "nope"}}, "does not resolve")
	_bad(t, "bad: an unknown pilot reward is refused", {"reward": {"pilot": "nobody"}}, "does not resolve")
	# The pending id is read at runtime, so these two cases hold whichever pilots are still
	# pending, and still count their checks once every pending pilot has its class row.
	var pending_ids: Array = Achievements.PENDING_PILOTS.duplicate()
	if pending_ids.is_empty():
		_bad(t, "bad: with no pending pilots, a pilot with no class row is refused", {"reward": {"pilot": "no_class_row"}}, "does not resolve")
		t.check("no pending pilots", true, "")
	else:
		var waiting: String = pending_ids[0]
		var pending := _base_rows()
		pending["pad_0"]["reward"] = {"pilot": waiting}
		var pending_problems := Achievements.validate(pending, signals, _pilots(), Cosmetics.ids())
		t.check("good: a pending pilot reward validates", pending_problems.is_empty(), "problems %s" % [pending_problems])
		_bad(t, "bad: a pending pilot with a class row is refused", {"reward": {"pilot": waiting}}, "PENDING_PILOTS", _pilots() + [waiting])
	_bad(t, "bad: a long name is refused", {"name": "One Two Three Four"}, "name")
	_bad(t, "bad: a long text is refused", {"text": "one two three four five six seven eight nine ten eleven twelve thirteen"}, "text")

	var rows := _base_rows()
	rows["pad_0"]["reward"] = {"pilot": "pylon_engineer"}
	rows["pad_1"]["reward"] = {"pilot": "pylon_engineer"}
	var twice := Achievements.validate(rows, signals, _pilots(), Cosmetics.ids())
	var named := false
	for p in twice:
		if p.begins_with("pad_1:") and p.contains("already the reward"):
			named = true
	t.check("bad: two rows rewarding one pilot are refused", named, "problems %s" % [twice])
	var short := Achievements.validate({"only": rows["pad_2"]}, signals, _pilots(), Cosmetics.ids())
	var short_named := false
	for p in short:
		if p.begins_with("table:") and p.contains("at least 8 rows"):
			short_named = true
	t.check("bad: a short table is refused", short_named, "problems %s" % [short])

	t.eq("fixture control: the purity pattern finds a planted Node", SourceScan.search(t, "var n: Node\n", FORBIDDEN).size(), 1)
	var source := SourceScan.text(t, "res://src/core/achievements.gd")
	var hits := SourceScan.search(t, source, FORBIDDEN)
	t.check("achievements.gd references no node, profile or stat module", hits.is_empty() and source != "", "found %s" % [hits.map(func(m: RegExMatch) -> String: return m.get_string())])
