extends SceneTree

const Intent := preload("res://src/movement/intent.gd")
const RunStore := preload("res://src/core/run_store.gd")
const Game := preload("res://src/game.gd")
const Items := preload("res://src/build/items.gd")
const T := preload("res://tests/support/t.gd")

# The earned save (wave 19, "No free retry"): the Spare Frame part leaves a killing hit at 20% health,
# once a run, in both damage paths, before player_died is emitted.
#   (a) a death with the part leaves the player alive in the stage at the save's hull and spends it;
#       the next death ends the run (summary, run_ended, player_died once). Both the plain and the
#       armour damage path. A control run with no part ends at the first death.
#   (b) the spent flag is in the run doc: it survives save and Continue (a spent save is not handed
#       back), a stage retry does not refund it, and a new run starts with it clear.
#   (c) clean_win reads the flag, not the retry count: a win with the save spent is not clean, a win
#       with retries but no save spent is.
#   (d) the part itself: rare_plus, cap 1, in the defense family, with house-voice text.

const DIR := "user://earned_save_test/"
const PATH := DIR + "run.json"

var _t := T.new("earned_save_test")
var _game


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	_run.call_deferred()


func _clean() -> void:
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)


func _boot():
	var game := Game.new()
	game.test_mode = true
	game.run_store_path = PATH
	root.add_child(game)
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	return game


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _start_run() -> void:
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(5)


func _disk() -> Dictionary:
	return RunStore.new(PATH).load()


func _with_save(armour: bool) -> void:
	_game.run.armor_mode = armour
	_game.run.add_part("spare_frame", "test")
	_game.build.recompute()


# Plants a negative when the environment asks: the earned save is switched off at its hook.
func _plant() -> void:
	if OS.get_environment("EARNED_SAVE_NEG") == "hook":
		_game.run.death_save_hook = Callable()


func _kill_twice(label: String, armour: bool) -> void:
	await _start_run()
	_with_save(armour)
	_plant()
	var died := [0]
	var ended := [false, true]
	_game.events.player_died.connect(func(): died[0] += 1)
	_game.events.run_ended.connect(func(won: bool):
		ended[0] = true
		ended[1] = won)
	var max_hp: float = _game.run.max_hp
	_game.run.damage(9999.0, "test")
	var live: bool = _game.run.alive() and _game.flow.state_name() == "stage" and not _game.run.over
	_t.check("%s: the first killing hit leaves the player alive" % label, live and died[0] == 0 and _game.run.death_save_spent,
		"flow %s, hp %.1f of %.1f, player_died %d, spent %s" % [_game.flow.state_name(), _game.run.hp, max_hp, died[0], _game.run.death_save_spent])
	_t.near("%s: at the save's hull, 20%% of max health" % label, _game.run.hp, maxf(1.0, max_hp * 0.2), 0.001)
	_t.check("%s: the spend is on disk" % label, bool(_disk().get("death_save_spent", false)), "disk %s" % [_disk().get("death_save_spent")])
	_game.run.damage(9999.0, "test")
	_t.check("%s: the next killing hit ends the run" % label, _game.flow.state_name() == "summary" and died[0] == 1 and ended[0] and not ended[1] and not _game.flow.run_won,
		"flow %s, player_died %d, run_ended %s won %s" % [_game.flow.state_name(), died[0], ended[0], ended[1]])


func _run() -> void:
	_game = _boot()
	await _frames(2)
	_d_part()

	# Control: no part, the first death ends the run.
	await _start_run()
	_game.run.damage(9999.0, "test")
	_t.check("control: no part, the first death ends the run", _game.flow.state_name() == "summary" and not _game.run.death_save_spent,
		"flow %s" % _game.flow.state_name())

	await _kill_twice("plain damage", false)
	_game.flow.new_run()
	await _frames(3)
	_t.check("a new run starts with the save unspent", not _game.run.death_save_spent and _game.flow.state_name() == "stage",
		"spent %s, flow %s" % [_game.run.death_save_spent, _game.flow.state_name()])
	await _kill_twice_again("armour damage", true)

	# (b) a stage retry does not refund; save and Continue keep the flag.
	_game.flow.new_run()
	await _frames(3)
	_with_save(false)
	_game.flow.enter_stage(1, Vector3(0.0, 0.0, 14.0), false)
	_game.run.damage(9999.0, "test")
	_t.check("the save spends mid-stage", _game.run.death_save_spent and _game.run.alive(), "spent %s hp %.1f" % [_game.run.death_save_spent, _game.run.hp])
	_game.flow.retry_stage()
	_t.check("a stage retry does not hand the save back", _game.run.death_save_spent and _game.run.parts.has("spare_frame"),
		"spent %s, parts %s" % [_game.run.death_save_spent, _game.run.parts])
	_game.free()

	_game = _boot()
	await _frames(2)
	var offered: bool = _game.flow.continue_ready
	var resumed: bool = _game.flow.resume_run()
	_t.check("Continue keeps the save spent", offered and resumed and _game.run.death_save_spent and _game.run.parts.has("spare_frame"),
		"offered %s resumed %s, spent %s, parts %s" % [offered, resumed, _game.run.death_save_spent, _game.run.parts])
	_game.build.recompute()
	_game.run.damage(9999.0, "test")
	_t.check("the resumed run's next death ends it", _game.flow.state_name() == "summary", "flow %s" % _game.flow.state_name())

	# (c) clean_win reads the flag.
	_game.flow.new_run()
	await _frames(3)
	var profile = _game.ctx.profile
	_game.run.death_save_spent = true
	_game.run.retries = 0
	_game.events.run_ended.emit(true)
	_t.check("clean_win: a win with the save spent is not clean", not profile.earned("clean_win"), "earned %s" % profile.earned("clean_win"))
	_game.run.death_save_spent = false
	_game.run.retries = 2
	_game.events.run_ended.emit(true)
	_t.check("clean_win: retries no longer count, an unspent save is clean", profile.earned("clean_win"), "earned %s" % profile.earned("clean_win"))
	var Ach := preload("res://src/core/achievements.gd")
	_t.check("clean_win reads the text it earns", String(Ach.ROWS["clean_win"]["text"]) == "Win a run without using the earned save." and Ach.ROWS["clean_win"]["need"] == "save_used",
		"%s" % [Ach.ROWS["clean_win"]])

	_game.free()
	_clean()
	DirAccess.remove_absolute(DIR)
	quit(_t.verdict())


# The same two-hit check on a run already begun (a new_run, not press_start).
func _kill_twice_again(label: String, armour: bool) -> void:
	_with_save(armour)
	_plant()
	var died := [0]
	_game.events.player_died.connect(func(): died[0] += 1)
	var max_hp: float = _game.run.max_hp
	_game.run.damage(9999.0, "test")
	_t.check("%s: the first killing hit leaves the player alive" % label, _game.run.alive() and _game.flow.state_name() == "stage" and died[0] == 0 and _game.run.death_save_spent,
		"flow %s, hp %.1f of %.1f, player_died %d, spent %s" % [_game.flow.state_name(), _game.run.hp, max_hp, died[0], _game.run.death_save_spent])
	_t.near("%s: at the save's hull, 20%% of max health" % label, _game.run.hp, maxf(1.0, max_hp * 0.2), 0.001)
	_game.run.damage(9999.0, "test")
	_t.check("%s: the next killing hit ends the run" % label, _game.flow.state_name() == "summary" and died[0] == 1,
		"flow %s, player_died %d" % [_game.flow.state_name(), died[0]])


func _d_part() -> void:
	var row: Dictionary = Items.TABLE.get("spare_frame", {})
	var def = load("res://src/build/parts.gd").def("spare_frame")
	_t.check("the Spare Frame is a rare_plus defense part, cap 1", row.get("rarity") == "rare_plus" and row.get("base") == "defense" and int(row.get("cap", 0)) == 1 and def != null,
		"%s" % [row])
	_t.check("its text is short and in voice", String(row.get("text", "")).split(" ").size() <= 12 and not String(row.get("text", "")).ends_with("."), String(row.get("text", "")))
