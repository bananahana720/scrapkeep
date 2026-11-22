extends SceneTree

const Game := preload("res://src/game.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const Achievements := preload("res://src/core/achievements.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const T := preload("res://tests/support/t.gd")

# The achievement listener on a real Game bus: a row's trigger fact earns it once, the
# profile on disk holds it, and achievement_earned fires once. Profiles live under the
# Game's test storage folder, never user://profile.json.

const NOW := 1700000000.0

var _t := T.new("progress_bus_test")
var _game
var _n := 0
var _earned: Array[String] = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_game.events.achievement_earned.connect(func(id: String): _earned.append(id))
	_p1()
	_p2()
	_p3()
	_p4()
	_p5()
	_game.queue_free()
	quit(_t.verdict())
	return true


func _path() -> String:
	_n += 1
	return "%s/progress_%d.json" % [_game.storage_dir, _n]


func _profile(path: String, load_it := true) -> Profile:
	var profile := Profile.new(path)
	if load_it:
		profile.load_profile()
	return profile


# A listener on the real bus and a fresh run for a class, over rows.
func _progress(profile: Profile, rows := {}) -> Progress:
	var progress := Progress.new()
	if not rows.is_empty():
		progress.rows = rows
	_game.add_child(progress)
	progress.setup(_game.events, _game.run, profile, func(): return NOW)
	return progress


func _begin(class_index := 0) -> void:
	_game.run.begin(ClassDef.all()[class_index])


func _collect() -> void:
	_earned.clear()


func _row(on: String, extra := {}) -> Dictionary:
	var row := {"name": "Test", "text": "Test.", "on": on, "count": 1, "reward": {}}
	row.merge(extra, true)
	return row


func _p1() -> void:
	var path := _path()
	var profile := _profile(path)
	var progress := _progress(profile)
	_begin()
	_collect()
	_game.events.beacon_unsealed.emit(1)
	_t.check("P1-1 earned in memory", profile.earned("warden_broken"), "warden_broken after beacon_unsealed")
	_t.check("P1-1 reward applied", profile.has_cosmetic("paint_any_night"), "cosmetic paint_any_night")
	_t.eq("P1-1 announced once", _earned, ["warden_broken"])
	var disk := _profile(path)
	_t.check("P1-1 on disk", disk.earned("warden_broken") and disk.has_cosmetic("paint_any_night"), "a second Profile reads it back")
	_game.events.beacon_unsealed.emit(2)
	_t.eq("P1-1 second emit earns nothing", _earned, ["warden_broken"])
	_t.eq("P1-1 no warning", progress.warnings, 0)
	_game.events.enemy_killed.emit("brindle", Vector3.ZERO, 0)
	_t.check("P1-1 where matches brindle", profile.earned("brindle_routed"), "enemy_killed kind brindle")
	var other := _profile(_path())
	var p2 := _progress(other)
	_game.events.enemy_killed.emit("chaser", Vector3.ZERO, 0)
	_t.check("P1-1 where rejects another kind", not other.earned("brindle_routed"), "enemy_killed kind chaser")
	progress.free()
	p2.free()


func _p2() -> void:
	var path := _path()
	var profile := _profile(path)
	var rows := {
		"five": _row("enemy_killed", {"count": 5}),
		"scrappy": _row("scrap_collected", {"sum": "amount", "count": 100}),
	}
	var progress := _progress(profile, rows)
	_begin()
	_collect()
	for i in 4:
		_game.events.enemy_killed.emit("chaser", Vector3.ZERO, 0)
	_t.check("P1-2 count not yet", not profile.earned("five"), "4 of 5")
	_t.near("P1-2 counter in stats", profile.stat("ach.five"), 4.0)
	_game.events.player_died.emit()
	progress.free()
	var again := _profile(path)
	var second := _progress(again, rows)
	_t.near("P1-2 counter survives a second Progress", again.stat("ach.five"), 4.0)
	_game.events.enemy_killed.emit("chaser", Vector3.ZERO, 0)
	_t.check("P1-2 count earns at its threshold", again.earned("five"), "5 of 5")
	_t.eq("P1-2 announced once", _earned.count("five"), 1)
	_game.events.scrap_collected.emit(60, Vector3.ZERO, 60)
	_t.check("P1-2 sum below threshold", not again.earned("scrappy"), "60 of 100")
	_game.events.scrap_collected.emit(45, Vector3.ZERO, 105)
	_t.check("P1-2 sum adds the named argument", again.earned("scrappy"), "60 + 45 of 100, not 2 emissions")
	second.free()


func _p3() -> void:
	var profile := _profile(_path())
	var rows := {
		"rack": _row("run_ended", {"need": "parts", "min": 3}),
		"clean": _row("run_ended", {"where": {"won": true}, "need": "retries", "max": 0}),
		"winner": _row("run_ended", {"need": "won"}),
		"world_two": _row("stage_cleared", {"need": "world", "min": 2}),
		"sable": _row("run_ended", {"need": "class"}),
		"heavy": _row("scrap_collected", {"need": "scrap", "min": 50}),
	}
	var progress := _progress(profile, rows)
	_begin(0)
	_collect()
	_game.run.scrap = 10
	_game.events.scrap_collected.emit(1, Vector3.ZERO, 10)
	_t.check("P1-3 min reads the summary now", not profile.earned("heavy"), "scrap 10 under 50")
	_game.run.scrap = 80
	_game.events.scrap_collected.emit(1, Vector3.ZERO, 80)
	_t.check("P1-3 min earns when the summary clears it", profile.earned("heavy"), "scrap 80")
	_game.events.stage_cleared.emit(1)
	_t.check("P1-3 world defaults before world_entered", not profile.earned("world_two"), "no world yet")
	_game.events.world_entered.emit(2)
	_game.events.stage_cleared.emit(4)
	_t.check("P1-3 world from the evaluator", profile.earned("world_two"), "world 2")
	_game.run.parts.assign(["a", "b"] as Array[String])
	_game.run.retries = 1
	_game.events.run_ended.emit(true)
	_t.check("P1-3 parts counted by size (2 under 3)", not profile.earned("rack"), "2 parts")
	_t.check("P1-3 max 0 fails with a retry", not profile.earned("clean"), "retries 1")
	_t.check("P1-3 won supplied by run_ended", profile.earned("winner"), "run_ended(true)")
	_game.run.parts.assign(["a", "b", "c"] as Array[String])
	_game.run.retries = 0
	_game.events.run_ended.emit(true)
	_t.check("P1-3 parts counted by size (3)", profile.earned("rack"), "3 parts")
	_t.check("P1-3 max 0 passes with none", profile.earned("clean"), "retries 0")
	_t.check("P1-3 class is the id", profile.earned("sable"), "class id truthy")
	var lost := _profile(_path())
	var p2 := _progress(lost, {"winner": _row("run_ended", {"need": "won"})})
	_game.events.run_ended.emit(false)
	_t.check("P1-3 won false on a loss", not lost.earned("winner"), "run_ended(false)")
	progress.free()
	p2.free()


func _p4() -> void:
	var path := _path()
	var profile := _profile(path, false)
	var progress := _progress(profile)
	_begin()
	_collect()
	_game.events.beacon_unsealed.emit(1)
	_t.check("P1-4 earn lands in memory", profile.earned("warden_broken"), "profile not loaded")
	_t.eq("P1-4 warns once", progress.warnings, 1)
	_t.eq("P1-4 still emits", _earned, ["warden_broken"])
	_t.check("P1-4 nothing on disk", not FileAccess.file_exists(path), "no file written")
	progress.free()


# Pilot rewards on the real table: Brindle's kill unlocks Tarn once and it survives a
# reload; rescue_completed("rivet") earns rivet_rescued once, "dig" only dig_rescued.
func _p5() -> void:
	_t.eq("P5 table validates", Achievements.validate(Achievements.ROWS, Achievements.bus_signals(), ClassDef.all().map(func(d): return d.id), Cosmetics.ids()), [])
	var path := _path()
	var profile := _profile(path)
	var progress := _progress(profile)
	_begin()
	_collect()
	_game.events.enemy_killed.emit("brindle", Vector3.ZERO, 0)
	_game.events.enemy_killed.emit("brindle", Vector3.ZERO, 0)
	_t.eq("P5 brindle_routed earned once", _earned.count("brindle_routed"), 1)
	_t.check("P5 tarn unlocked in the profile", profile.has_pilot("tarn"), "has_pilot tarn")
	_t.check("P5 no cosmetic from brindle_routed", not profile.has_cosmetic("paint_kest_dusk"), "paint_kest_dusk")
	_t.check("P5 tarn survives save and reload", _profile(path).has_pilot("tarn"), "second Profile reads tarn")
	_collect()
	_game.events.rescue_completed.emit("dig")
	_t.eq("P5 dig earns only dig_rescued", _earned, ["dig_rescued"])
	_t.check("P5 dig does not unlock Rivet", not profile.has_pilot("runner_gunner"), "runner_gunner")
	_collect()
	_game.events.rescue_completed.emit("rivet")
	_game.events.rescue_completed.emit("rivet")
	_t.eq("P5 rivet earns rescue and Fern once", _earned, ["rivet_rescued", "ach_d7_fern"])
	_t.check("P5 Rivet unlocked", profile.has_pilot("runner_gunner"), "runner_gunner")
	progress.free()
