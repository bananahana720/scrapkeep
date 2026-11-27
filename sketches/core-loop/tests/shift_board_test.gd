extends SceneTree

# The shift board (shift_board.gd, design-v3/FIRST-HOUR.md): what a player's first world 1 runs
# open. Five scripted profiles, at 0 to 4 finished runs, each saved, reloaded and read the way the
# trophy wall reads them, show the next unlock; every finished run moves one mark (a stamp or a
# time card hole); a Brindle mark counts only for the pilot flown; the board's items join a listed
# table's pool only once opened; the rows validate and the validator catches planted defects.

const ShiftBoard := preload("res://src/core/shift_board.gd")
const Achievements := preload("res://src/core/achievements.gd")
const AchievementsPage := preload("res://src/ui/achievements_page.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const TuneRows := preload("res://src/core/tune_rows.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const T := preload("res://tests/support/t.gd")

const DIR := "user://shift_board_test/"
const SABLE := "pylon_engineer"
const RIVET := "runner_gunner"


class FakeRun:
	extends RefCounted
	var pilot := "pylon_engineer"
	var kills := 0
	var settled: Array = []

	func class_id() -> String:
		return pilot

	func summary() -> Dictionary:
		return {"parts": 0, "retries": 0, "stages": 1, "kills": kills}


var _t := T.new("shift_board_test")
var _serial := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_rows()
	_validate_controls()
	_first_runs()
	_one_big_first_run()
	_pilot_marks()
	_time_card()
	_pool()
	_seeds()
	quit(_t.verdict())


func _path() -> String:
	_serial += 1
	var path := "%sboard-%d-%d.json" % [DIR, OS.get_process_id(), _serial]
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return path


func _fresh(path := "") -> Profile:
	var store := Profile.new(_path() if path == "" else path)
	store.load_profile()
	return store


func _pilots() -> Array:
	return ClassDef.all().map(func(d): return d.id)


func _rows() -> void:
	_t.eq("the board validates", ShiftBoard.validate(ShiftBoard.RUNGS, Achievements.ROWS, TuneRows.ids()), [])
	_t.eq("achievements validate with the mark rows", Achievements.validate(Achievements.ROWS, Achievements.bus_signals(), _pilots(), Cosmetics.ids()), [])
	var marked := {}
	for id in ShiftBoard.ids():
		var pilot := String(ShiftBoard.rung(id).get("pilot", ""))
		if pilot != "":
			marked[pilot] = id
	_t.eq("every pilot has one Brindle mark", marked.keys().size(), _pilots().size())
	for item in ShiftBoard.all_items():
		_t.check("%s is not on the park table's list, so opening it widens the pool" % item, not ParkDefs.part_in_play(item), item)
		_t.check("%s finishes as a part row" % item, not Parts.row(item).is_empty(), item)


func _validate_controls() -> void:
	var cases := {
		"a pays that disagrees with its row": func(rows): rows["mark_sable"]["pays"] = {"item": "clean_break"},
		"an unknown earned row": func(rows): rows["clock_in"]["when"] = {"earned": "ach_nothing"},
		"an unknown tune": func(rows): rows["lost_tape"]["when"] = {"tune": "no-such-tune"},
		"a class-only item": func(rows):
			rows["mark_sable"]["pays"] = {"item": "vault_battery"},
		"a stamp word outside the list": func(rows): rows["clock_in"]["stamp"] = "APPROVED",
		"a long hint": func(rows): rows["clock_in"]["text"] = "one two three four five six seven eight nine ten eleven twelve thirteen",
	}
	for label in cases:
		var rows := ShiftBoard.RUNGS.duplicate(true)
		cases[label].call(rows)
		_t.check("validate refuses %s" % label, not ShiftBoard.validate(rows, Achievements.ROWS, TuneRows.ids()).is_empty(), str(ShiftBoard.validate(rows, Achievements.ROWS, TuneRows.ids())))
	var grants := Achievements.ROWS.duplicate(true)
	grants["brindle_mark_sable"]["pilot"] = "nobody"
	_t.check("achievements refuse a mark for no pilot", not Achievements.validate(grants, Achievements.bus_signals(), _pilots(), Cosmetics.ids()).is_empty(), "")
	grants = Achievements.ROWS.duplicate(true)
	grants["brindle_mark_sable"]["reward"] = {"item": "not_an_item"}
	_t.check("the board refuses an item reward naming no item", not ShiftBoard.validate(ShiftBoard.RUNGS, grants, TuneRows.ids()).is_empty(), "")
	grants = Achievements.ROWS.duplicate(true)
	grants["stray_item"] = {"name": "Stray", "text": "Nothing.", "on": "jumped", "count": 1, "reward": {"item": "fan_spread"}}
	_t.check("the board refuses an item reward no rung reads", not ShiftBoard.validate(ShiftBoard.RUNGS, grants, TuneRows.ids()).is_empty(), "")


# A first run that does everything at once stamps every kind of rung: the summary says it as one
# plain sentence, Clocked In first and not listed twice, the deeds in board order, no stamp word.
func _one_big_first_run() -> void:
	var store := _fresh(_path())
	var bus := GameEvents.new()
	var run := FakeRun.new()
	var listener := Progress.new()
	listener.setup(bus, run, store, func(): return 1700000000.0)
	bus.run_started.emit(SABLE)
	run.kills = 30
	bus.beacon_unsealed.emit(1)
	bus.rescue_completed.emit("rivet")
	bus.enemy_killed.emit("brindle", Vector3.ZERO, 0)
	store.hear_tune("secret-lost-tape")
	bus.run_ended.emit(true)
	_t.eq("one run, four stamps", listener.board_line,
		"You clocked in and marked off Warden Breaker, Rivet Freed, Lost Tape, Brindle Routed and Sable's Mark on the shift board.")
	listener.free()
	bus.free()


# Runs 1 to 4 of a new player who flies Sable: a death on the dam, a Warden then a death in the
# flume, a run that finds nothing new, then Rivet's cage and Brindle's rout. Profile n has n runs.
func _first_runs() -> void:
	var path := _path()
	var store := _fresh(path)
	var bus := GameEvents.new()
	var run := FakeRun.new()
	var listener := Progress.new()
	listener.setup(bus, run, store, func(): return 1700000000.0)
	var expect_next := ["clock_in", "first_warden", "rivet_freed", "rivet_freed", "lost_tape"]
	var expect_line := ["", "You clocked in. Your first shift is on the shift board.", "You marked off Warden Breaker on the shift board.",
		"Time card punched, 1 of 3.", "You marked off Rivet Freed, Brindle Routed and Sable's Mark on the shift board."]
	var scripts := [
		[],
		["kills:8"],
		["kills:14", "warden"],
		["kills:11"],
		["kills:30", "warden", "rivet", "brindle"],
	]
	var marks_before := -1
	for n in scripts.size():
		if n > 0:
			run.kills = 0
			bus.run_started.emit(SABLE)
			for step in scripts[n]:
				var s := String(step)
				if s.begins_with("kills:"):
					run.kills = int(s.substr(6))
				elif s == "warden":
					bus.beacon_unsealed.emit(1)
				elif s == "rivet":
					bus.rescue_completed.emit("rivet")
				elif s == "brindle":
					bus.enemy_killed.emit("brindle", Vector3.ZERO, 0)
			bus.run_ended.emit(false)
			_t.eq("run %d's summary line" % n, listener.board_line, expect_line[n])
			_t.check("run %d saved" % n, store.save(), store.last_error)
		var reload := _fresh(path)
		var read := ShiftBoard.reading(reload)
		_t.eq("profile at %d runs shows the next unlock" % n, read["next"], expect_next[n])
		_t.check("profile at %d runs names it and what it opens" % n, read["next_name"] != "" and read["next_pays"] != "", str(read))
		var lines := AchievementsPage.board_lines(reload)
		_t.check("the trophy wall at %d runs names the next rung" % n, lines.size() == 3 and lines[1].contains(String(read["next_name"])), str(lines))
		var marks: int = ShiftBoard.stamped_ids(reload).size() + ShiftBoard.punches(reload)
		if n > 0:
			_t.check("run %d moved at least one mark" % n, marks > marks_before, "%d -> %d" % [marks_before, marks])
		marks_before = marks
	var done := _fresh(path)
	_t.check("Rivet and Tarn are signed on", done.has_pilot(RIVET) and done.has_pilot("tarn"), str(done._doc["pilots"]))
	_t.eq("Sable's mark opened its item", ShiftBoard.opened_items(done), ["strike_pocket"])
	_t.check("Rivet's mark shows once Rivet flies", ShiftBoard.shown("mark_rivet", done), "")
	_t.check("Kest's mark stays off a board that cannot fly Kest", not ShiftBoard.shown("mark_kest", done), "")
	_t.check("the sitting shows every mark", ShiftBoard.shown("mark_kest", done, true), "")
	listener.free()
	bus.free()


func _pilot_marks() -> void:
	var store := _fresh()
	var bus := GameEvents.new()
	var run := FakeRun.new()
	run.pilot = RIVET
	var listener := Progress.new()
	listener.setup(bus, run, store, func(): return 1700000000.0)
	bus.run_started.emit(RIVET)
	bus.enemy_killed.emit("brindle", Vector3.ZERO, 0)
	bus.run_ended.emit(true)
	_t.check("routing Brindle as Rivet earns Rivet's mark", store.earned("brindle_mark_rivet"), "")
	_t.check("and not Sable's", not store.earned("brindle_mark_sable"), "")
	_t.eq("Rivet's mark opens clean_break", ShiftBoard.opened_items(store), ["clean_break"])
	listener.free()
	bus.free()


func _time_card() -> void:
	var path := _path()
	var store := _fresh(path)
	# Stamp the always-reachable rungs first, so the runs below find nothing new.
	store.earn("ach_d7_salt_skip", 1.0)
	store.earn("warden_broken", 1.0)
	var bus := GameEvents.new()
	var run := FakeRun.new()
	var listener := Progress.new()
	listener.setup(bus, run, store, func(): return 1700000000.0)
	bus.run_started.emit(SABLE)
	run.kills = int(ShiftBoard.TIME_CARD["min_kills"]) - 1
	bus.run_ended.emit(false)
	_t.eq("a run under min_kills punches nothing", ShiftBoard.punches(store), 0)
	_t.check("a returning 4-kill loss still gives a non-blank next-try line", listener.board_line != "" and listener.board_line.contains("Rivet Freed"), listener.board_line)
	var fresh_store := _fresh()
	var fresh_bus := GameEvents.new()
	var fresh_run := FakeRun.new()
	var fresh_listener := Progress.new()
	fresh_listener.setup(fresh_bus, fresh_run, fresh_store, func(): return 1700000000.0)
	fresh_bus.run_started.emit(SABLE)
	fresh_run.kills = int(ShiftBoard.TIME_CARD["min_kills"]) - 1
	fresh_bus.run_ended.emit(false)
	_t.eq("a fresh 4-kill first run stamps clock_in and punches nothing", ShiftBoard.punches(fresh_store), 0)
	_t.check("a fresh 4-kill first run names clock_in", fresh_listener.board_line.contains("clocked in"), fresh_listener.board_line)
	fresh_bus.run_started.emit(SABLE)
	fresh_run.kills = int(ShiftBoard.TIME_CARD["min_kills"])
	fresh_bus.run_ended.emit(false)
	_t.eq("a returning 5-kill loss punches the time card once", ShiftBoard.punches(fresh_store), 1)
	_t.eq("a returning 5-kill loss prints the punch line", fresh_listener.board_line, "Time card punched, 1 of 3.")
	fresh_listener.free()
	fresh_bus.free()
	var holes := int(ShiftBoard.TIME_CARD["holes"])
	for i in holes * ShiftBoard.CARDS.size() + 1:
		bus.run_started.emit(SABLE)
		run.kills = 20
		bus.run_ended.emit(false)
		if i == holes - 1:
			_t.check("the full card says what it pays", listener.board_line.begins_with("Time card full. First Card pays"), listener.board_line)
	_t.eq("every finished run punched once", ShiftBoard.punches(store), holes * ShiftBoard.CARDS.size() + 1)
	_t.eq("every card paid", ShiftBoard.cards_paid(store), ShiftBoard.CARDS.size())
	_t.check("past the last card the line says so", listener.board_line.contains("Every card is paid"), listener.board_line)
	_t.check("the punches survive a reload", store.save() and ShiftBoard.punches(_fresh(path)) == ShiftBoard.punches(store), store.last_error)
	var opened := ShiftBoard.opened_items(_fresh(path))
	for card in ShiftBoard.CARDS:
		_t.check("card item %s is open" % card["pays"]["item"], opened.has(String(card["pays"]["item"])), str(opened))
	listener.free()
	bus.free()


func _pool() -> void:
	var before = Synergies.table
	Synergies.table = ParkDefs
	Parts.opened_items = {}
	var pool := Parts.offer_pool(SABLE, ["common", "rare", "relic"])
	_t.check("a fresh profile's pool holds no board item", not ShiftBoard.all_items().any(func(id): return pool.has(id)), str(pool))
	Parts.opened_items = {"strike_pocket": true}
	pool = Parts.offer_pool(SABLE, ["common", "rare", "relic"])
	_t.check("an opened item joins the park pool", pool.has("strike_pocket"), str(pool))
	_t.check("an unopened one does not", not pool.has("clean_break"), str(pool))
	Parts.opened_items = {}
	Synergies.table = before


func _seeds() -> void:
	var store := _fresh()
	_t.eq("a fresh profile opens no seed", ShiftBoard.open_seeds(store), [])
	store.earn("brindle_routed", 1.0)
	_t.check("routing Brindle opens the dam's night shift seed", ShiftBoard.open_seeds(store).has("dam_night_shift"), str(ShiftBoard.open_seeds(store)))
