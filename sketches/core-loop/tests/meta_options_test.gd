extends SceneTree

# SG12 between-run options (W13-INTEGRATION-3.md, SG12 block; comps
# gunfire/run-pacing-and-economy meta-options-tree and roboquest/stage-anatomy
# secret-reward-unlocks-later). Every node row is an option, a discovery or a pocket key;
# none carries a price, cost or stat key (BIBLE.md:513, P-UNITS B5); each opens on its one
# achievement grant, a one-run condition with count at 10 or below; a hidden pocket's
# discovery opens one; opening writes no stat; level equals nodes opened; the profile
# round-trips the opened nodes. Five simulated runs on the real bus and the shipped rows.

const MetaOptions := preload("res://src/core/meta_options.gd")
const MetaPage := preload("res://src/ui/meta_page.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const T := preload("res://tests/support/t.gd")

const DIR := "user://meta_options_test/"


# The two reads progress.gd makes of a run for need rows.
class FakeRun:
	extends RefCounted
	var parts := 0
	var settled: Array = []

	func class_id() -> String:
		return "runner_gunner"

	func summary() -> Dictionary:
		return {"parts": parts, "retries": 0, "stages": 1}


var _t := T.new("meta_options_test")
var _serial := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_rows()
	_validate_controls()
	_five_runs()
	_no_stat_moves()
	_round_trip()
	_page()
	quit(_t.verdict())


func _path() -> String:
	_serial += 1
	var path := "%smeta-%d-%d.json" % [DIR, OS.get_process_id(), _serial]
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return path


func _fresh(path := "") -> Profile:
	var store := Profile.new(_path() if path == "" else path)
	store.load_profile()
	return store


func _pilots() -> Array:
	return ClassDef.all().map(func(d): return d.id)


# Every key at any depth of a row, lower case.
func _keys(value, out: Array) -> Array:
	if value is Dictionary:
		for key in value:
			out.append(String(key).to_lower())
			_keys(value[key], out)
	elif value is Array:
		for item in value:
			_keys(item, out)
	return out


func _rows() -> void:
	_t.check("there are node rows", MetaOptions.ids().size() >= 3, str(MetaOptions.ids()))
	_t.eq("the shipped rows validate", MetaOptions.validate(MetaOptions.ROWS, Achievements.ROWS), [])
	_t.eq("achievements still validate with the grant rows", Achievements.validate(Achievements.ROWS, Achievements.bus_signals(), _pilots(), Cosmetics.ids()), [])
	var kinds := {}
	for id in MetaOptions.ids():
		var row := MetaOptions.row(id)
		kinds[row["kind"]] = true
		_t.check("%s is an option, discovery or pocket key" % id, ["option", "discovery", "pocket_key"].has(row["kind"]), String(row["kind"]))
		for key in _keys(row, []):
			for banned in ["price", "cost", "stat", "discount", "cogs", "currency"]:
				_t.check("%s key %s carries no %s" % [id, key, banned], not key.contains(banned), key)
		var grant := String(row["grant"])
		var granter := Achievements.row(grant)
		_t.check("%s has its grant row %s" % [id, grant], not granter.is_empty(), grant)
		# Systems audit pass D (row 31, 11 Nov 2026): each grant pays a paint a player sees.
		_t.check("%s's grant pays a paint" % id, String(Achievements.reward_of(grant).get("cosmetic", "")).begins_with("paint_"), str(Achievements.reward_of(grant)))
		_t.check("%s's grant count is 10 or below" % id, int(granter.get("count", 0)) >= 1 and int(granter.get("count", 0)) <= MetaOptions.MAX_GRANT_COUNT, str(granter.get("count")))
		_t.check("%s's grant adds no lifetime sum" % id, not granter.has("sum"), str(granter.get("sum", "")))
	for kind in ["option", "discovery", "pocket_key"]:
		_t.check("a %s node exists" % kind, kinds.has(kind), str(kinds.keys()))
	var granting := {}
	for id in MetaOptions.ids():
		granting[String(MetaOptions.row(id)["grant"])] = true
	_t.eq("one grant per node", granting.size(), MetaOptions.ids().size())
	var pocket := MetaOptions.row("pocket_key")
	var pocket_grant := Achievements.row(String(pocket.get("grant", "")))
	_t.check("the pocket key opens on a hidden pocket's discovery (cracked cache opened)",
		pocket_grant.get("on") == "world_fact" and pocket_grant.get("where", {}) == {"kind": "cache_spent"}, str(pocket_grant))


# Positive controls: the validator catches each planted defect.
func _validate_controls() -> void:
	var cases := {
		"a price key": func(rows): rows["spare_reroll"]["price"] = 40,
		"a stat key": func(rows): rows["spare_reroll"]["stat_bonus"] = 0.05,
		"a cost key nested": func(rows): rows["spare_reroll"]["effect"] = {"cost": 1},
		"a currency kind": func(rows): rows["spare_reroll"]["kind"] = "currency",
		"a missing grant": func(rows): rows["spare_reroll"]["grant"] = "ach_meta_nothing",
	}
	for label in cases:
		var rows := MetaOptions.ROWS.duplicate(true)
		cases[label].call(rows)
		_t.check("validate refuses %s" % label, not MetaOptions.validate(rows, Achievements.ROWS).is_empty(), str(MetaOptions.validate(rows, Achievements.ROWS)))
	var grants := Achievements.ROWS.duplicate(true)
	grants[String(MetaOptions.row("spare_reroll")["grant"])]["count"] = 11
	_t.check("validate refuses a grant count of 11", MetaOptions.validate(MetaOptions.ROWS, grants).any(func(p): return String(p).contains("count")), str(MetaOptions.validate(MetaOptions.ROWS, grants)))
	grants = Achievements.ROWS.duplicate(true)
	grants["stray_option"] = {"name": "Stray", "text": "Nothing.", "on": "jumped", "count": 1, "reward": {"option": "not_a_node"}}
	_t.check("validate refuses an option reward naming no node", MetaOptions.validate(MetaOptions.ROWS, grants).any(func(p): return String(p).contains("not_a_node")), str(MetaOptions.validate(MetaOptions.ROWS, grants)))


# Facts that meet one grant row each, from that row's own where (so a row edit moves the script).
func _meet(bus, run: FakeRun, node_id: String) -> void:
	var grant := Achievements.row(String(MetaOptions.row(node_id)["grant"]))
	for i in int(grant.get("count", 1)):
		match String(grant["on"]):
			"activity_done":
				bus.activity_done.emit("pocket_%d" % i, Vector3.ZERO)
			"beacon_unsealed":
				bus.beacon_unsealed.emit(i + 1)
			"world_fact":
				bus.world_fact.emit(String(grant.get("where", {}).get("kind", "")), Vector3.ZERO)
			"synergy_discovered":
				bus.synergy_discovered.emit("meta_test_%d" % i, "combat", true)
			_:
				_t.check("the run script knows %s's signal" % node_id, false, String(grant["on"]))


func _five_runs() -> void:
	var path := _path()
	var store := _fresh(path)
	var bus := GameEvents.new()
	var run := FakeRun.new()
	var listener := Progress.new()
	listener.setup(bus, run, store, func(): return 1700000000.0)
	# Run 1 to 4 each meet one node's grant; run 5 repeats every fact and opens nothing new.
	var plan := [["spare_reroll"], ["shelf_preview"], ["pocket_key"], ["pocket_tint"], MetaOptions.ids()]
	var opened_before := 0
	for n in plan.size():
		bus.run_started.emit("runner_gunner")
		for node_id in plan[n]:
			_meet(bus, run, node_id)
		bus.run_ended.emit(false)
		var newly := MetaOptions.open_earned(store)
		_t.check("run %d saved" % (n + 1), store.save(), store.last_error)
		var reload := _fresh(path)
		var level := MetaOptions.level(reload)
		_t.eq("run %d level equals nodes opened" % (n + 1), level, reload.option_ids().size())
		_t.eq("run %d level equals the earned grants" % (n + 1), level, MetaOptions.ids().filter(func(id): return reload.earned(String(MetaOptions.row(id)["grant"]))).size())
		for id in reload.option_ids():
			_t.check("run %d opened node %s is a row" % [n + 1, id], MetaOptions.ROWS.has(id), id)
		if n < 4:
			_t.eq("run %d opened exactly one node" % (n + 1), newly, [plan[n][0]])
			_t.eq("run %d moved the bar by one" % (n + 1), level, opened_before + 1)
		else:
			_t.eq("run 5 opened nothing new", newly, [])
			_t.eq("run 5 left the level", level, opened_before)
		opened_before = level
	_t.eq("after five runs every node is open", MetaOptions.level(store), MetaOptions.ids().size())
	listener.free()
	bus.free()


# Opening nodes writes no stat: a profile with every node open has the stats of a fresh one,
# and open_earned leaves a played profile's stats as they were.
func _no_stat_moves() -> void:
	var fresh := _fresh()
	var full := _fresh()
	full.add_stat("ach.kills_100", 7.0)
	for id in MetaOptions.ids():
		full.earn(String(MetaOptions.row(id)["grant"]), 100.0)
	_t.check("a played profile saves", full.save(), full.last_error)
	var stats_before = _doc(full.path).get("stats")
	var newly := MetaOptions.open_earned(full)
	_t.eq("open_earned opens every earned grant's node", newly.size(), MetaOptions.ids().size())
	_t.check("a full profile saves", full.save(), full.last_error)
	var reload := _fresh(full.path)
	_t.eq("open_earned left the saved stats as they were", _doc(reload.path).get("stats"), stats_before)
	for stat_name in ["damage", "health", "speed", "cogs", "scrap", "rerolls", "discount"]:
		_t.eq("stat %s matches a fresh profile" % stat_name, reload.stat(stat_name), fresh.stat(stat_name))
	var bare := _fresh()
	for id in MetaOptions.ids():
		bare.open_option(id)
	_t.check("a profile with every node open saves", bare.save(), bare.last_error)
	_t.eq("its saved stats equal a fresh profile's", _doc(bare.path).get("stats"), {})
	_t.eq("a second open_earned opens nothing", MetaOptions.open_earned(full), [])
	_t.eq("an earned row that is not a grant opens nothing", MetaOptions.open_earned(_earned_other()), [])


func _earned_other() -> Profile:
	var store := _fresh()
	store.earn("first_win", 5.0)
	return store


func _doc(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _round_trip() -> void:
	var path := _path()
	var store := _fresh(path)
	_t.check("open_option is true the first time", store.open_option("spare_reroll"))
	_t.check("open_option is false the second time", not store.open_option("spare_reroll"))
	store.open_option("pocket_key")
	_t.check("the profile saves the opened nodes", store.save(), store.last_error)
	var reload := _fresh(path)
	_t.eq("the opened nodes round-trip", reload.option_ids(), ["spare_reroll", "pocket_key"])
	_t.check("has_option reads them", reload.has_option("pocket_key") and not reload.has_option("shelf_preview"))
	_t.eq("the schema is unchanged", int(_doc(path).get("schema", -1)), Profile.SCHEMA)
	var merged := Profile.merge({"options": ["spare_reroll"], "achievements": {}, "stats": {}, "equipped": {}},
		{"options": ["pocket_key", "spare_reroll"], "achievements": {}, "stats": {}, "equipped": {}})
	_t.eq("two writers' opened nodes merge as a union", merged["options"], ["spare_reroll", "pocket_key"])
	# A v4 file from before this unit has no options key; it reads as none opened and keeps the rest.
	var old_path := _path()
	var f := FileAccess.open(old_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": 4, "generation": 2, "pilots": ["tarn"], "achievements": {"first_win": 9}}))
	f.close()
	var old := _fresh(old_path)
	_t.check("an older v4 file loads", old.last_error == "" and old.has_pilot("tarn") and old.earned("first_win"), old.last_error)
	_t.eq("an older v4 file has no opened nodes", old.option_ids(), [])
	var bad_path := _path()
	f = FileAccess.open(bad_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": 4, "options": "spare_reroll"}))
	f.close()
	var bad := Profile.new(bad_path)
	_t.check("an options value that is not a list is refused", not bad.load_profile(), bad.last_error)


func _page() -> void:
	var store := _fresh()
	store.open_option("pocket_key")
	var page := MetaPage.new()
	root.add_child(page)
	page.refresh(store)
	_t.eq("the page has one row per node", page.rows.keys(), MetaOptions.ids())
	_t.eq("the page names the level", page.level_text(), "Head starts: 1 of %d" % MetaOptions.ids().size())
	var open := MetaPage.reading("pocket_key", store)
	var shut := MetaPage.reading("spare_reroll", store)
	_t.check("an opened node shows its name and what it gives", open["open"] and open["name"] == MetaOptions.row("pocket_key")["name"] and open["text"] == MetaOptions.row("pocket_key")["text"], str(open))
	_t.eq("a closed node shows its grant's condition", shut["note"], Achievements.row(String(MetaOptions.row("spare_reroll")["grant"]))["text"])
	_t.check("a closed node is not open", not shut["open"], str(shut))
	page.free()
