extends SceneTree

const Game := preload("res://src/game.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const RunState := preload("res://src/core/run_state.gd")
const Achievements := preload("res://src/core/achievements.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# Tally's ledger: beating world N's boss finds leaf N (settled "ledger.found.N"), Moss's bay
# takes every carried leaf on entry (settled "ledger.returned.N", one world_fact
# "ledger_returned" each), and three distinct worlds' leaves earn ledger_balanced, which
# unlocks pilot tally. Leaves are counted by world id, never by emission count alone.
# The shop part (L6) runs first, so the isolated listeners' bus traffic cannot reach the
# Game's own profile before it is read. Isolated parts give each listener its own run
# document. Profiles live under the Game's test storage folder.

const NOW := 1700000000.0

var _t := T.new("ledger_leaf_test")
var _game
var _n := 0
var _earned: Array[String] = []
var _facts: Array = []
# The isolated listeners' own run document. The Game's Progress shares the Game's run, and a
# shared run.settled would mark an isolated find stale before its profile saved it.
var _run_doc


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_game.events.achievement_earned.connect(func(id: String): _earned.append(id))
	_game.events.world_fact.connect(func(kind: String, _at: Vector3): _facts.append(kind))
	await _l6()
	var shared := _profile(_path())
	_l1(shared)
	_l2(shared)
	var spanning := _profile(_path())
	_l3(spanning)
	_l4(spanning)
	_l5()
	_l7()
	_game.free()
	quit(_t.verdict())


func _path() -> String:
	_n += 1
	return "%s/ledger_%d.json" % [_game.storage_dir, _n]


func _profile(path: String, load_it := true) -> Profile:
	var profile := Profile.new(path)
	if load_it:
		profile.load_profile()
	return profile


func _progress(profile: Profile) -> Progress:
	_run_doc = RunState.new()
	var progress := Progress.new()
	_game.add_child(progress)
	progress.setup(_game.events, _run_doc, profile, func(): return NOW)
	return progress


func _begin() -> void:
	_run_doc.begin(ClassDef.all()[0])


func _find(world: int) -> void:
	_game.events.world_entered.emit(world)
	_game.events.boss_defeated.emit()


func _returned_facts() -> int:
	return _facts.count(Progress.LEDGER_FACT)


func _l1(profile: Profile) -> void:
	var progress := _progress(profile)
	_begin()
	_find(1)
	_t.check("L1 world one's boss finds leaf one", profile.is_settled("ledger.found.1"), "ledger.found.1")
	var before: Array = profile.settled_ids().duplicate()
	_game.events.boss_defeated.emit()
	_t.eq("L1 a second boss win adds nothing", profile.settled_ids(), before)
	var fresh := _profile(_path())
	var other := _progress(fresh)
	_game.events.run_started.emit("rivet")
	_game.events.boss_defeated.emit()
	var found := fresh.settled_ids().filter(func(id): return String(id).begins_with("ledger."))
	_t.eq("L1 a boss with no world entered finds nothing", found, [])
	other.free()
	progress.free()


func _l2(profile: Profile) -> void:
	var progress := _progress(profile)
	_facts.clear()
	_t.eq("L2 the first hand-in returns world one", progress.return_leaves(Vector3.ZERO), [1])
	_t.eq("L2 one ledger_returned fact", _returned_facts(), 1)
	_t.eq("L2 the row counts one leaf", progress.count_of("ledger_balanced"), 1.0)
	_t.eq("L2 a second hand-in returns nothing", progress.return_leaves(Vector3.ZERO), [])
	_t.eq("L2 a second hand-in emits nothing", _returned_facts(), 1)
	_t.eq("L2 the count stays one", progress.count_of("ledger_balanced"), 1.0)
	_t.eq("L2 one leaf returned", progress.leaves_returned(), 1)
	progress.free()


func _l3(profile: Profile) -> void:
	var progress := _progress(profile)
	_earned.clear()
	for i in 3:
		_begin()
		_game.events.run_started.emit("rivet")
		_find(1)
		progress.return_leaves(Vector3.ZERO)
	_t.eq("L3 one world's leaf counts once", progress.count_of("ledger_balanced"), 1.0)
	_t.check("L3 one world never earns the row", not profile.earned("ledger_balanced"), "world 1 three times")
	_t.check("L3 one world never unlocks tally", not profile.has_pilot("tally"), "world 1 three times")
	progress.free()


func _l4(profile: Profile) -> void:
	var progress := _progress(profile)
	_earned.clear()
	_begin()
	_game.events.run_started.emit("rivet")
	_find(2)
	_find(3)
	_t.eq("L4 the next hand-in returns worlds two and three", progress.return_leaves(Vector3.ZERO), [2, 3])
	_t.eq("L4 ledger_balanced earned once", _earned.count("ledger_balanced"), 1)
	_t.check("L4 tally unlocked", profile.has_pilot("tally"), "three worlds across two runs")
	_t.eq("L4 three leaves returned", progress.leaves_returned(), 3)
	var reloaded := _profile(profile.path)
	_t.check("L4 tally survives reload", reloaded.has_pilot("tally"), "reloaded")
	var ids: Array = []
	for w in [1, 2, 3]:
		ids.append(Progress.LEDGER_FOUND % w)
		ids.append(Progress.LEDGER_RETURNED % w)
	_t.check("L4 all six ledger ids on disk", ids.all(func(id): return reloaded.is_settled(id)), str(ids))
	progress.free()


func _l5() -> void:
	var profile := _profile(_path())
	var progress := _progress(profile)
	_begin()
	_find(2)
	var disk := _profile(profile.path)
	_t.check("L5 a find is on disk before any hand-in", disk.is_settled("ledger.found.2"), "fresh Profile, no return call")
	_t.check("L5 nothing returned yet", not disk.is_settled("ledger.returned.2"), "ledger.returned.2")
	progress.free()


func _l6() -> void:
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(1)
	for i in 10:
		await physics_frame
	var shop = _game.ctx.build.shop
	var profile = _game.ctx.profile
	_t.check("L6 the Game's profile is under test storage", profile.path.begins_with(_game.storage_dir), profile.path)
	var plain: Dictionary = shop.enter()
	_t.eq("L6 no leaves: the greeting is unchanged", plain["line_id"], "moss.remember.first_visit")
	_t.eq("L6 no leaves: nothing returned", shop.leaves_this_visit, [])
	shop.leave()
	profile.settle("ledger.found.1")
	var first: Dictionary = shop.enter()
	_t.eq("L6 Moss takes leaf one", first["line_id"], "moss.ledger.1")
	_t.eq("L6 leaf one this visit", shop.leaves_this_visit, [1])
	_t.check("L6 the ledger line has text", first["text"] != "", first["text"])
	shop.leave()
	var again: Dictionary = shop.enter()
	_t.check("L6 the next visit has no ledger line", not String(again["line_id"]).begins_with("moss.ledger."), again["line_id"])
	shop.leave()
	profile.settle("ledger.found.2")
	profile.settle("ledger.found.3")
	var last: Dictionary = shop.enter()
	_t.eq("L6 Moss takes the last two", last["line_id"], "moss.ledger.3")
	_t.eq("L6 leaves two and three this visit", shop.leaves_this_visit, [2, 3])
	_t.check("L6 tally unlocked through the shop", profile.has_pilot("tally"), "ctx.profile")
	shop.leave()


func _l7() -> void:
	var pilots: Array = ClassDef.all().map(func(def): return def.id)
	var problems: Array = Achievements.validate(Achievements.ROWS, Achievements.bus_signals(), pilots, Cosmetics.ids())
	_t.eq("L7 the table validates", problems, [])
	_t.eq("L7 ledger_balanced rewards tally", Achievements.row("ledger_balanced").get("reward"), {"pilot": "tally"})

