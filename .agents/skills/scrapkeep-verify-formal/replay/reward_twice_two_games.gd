extends SceneTree

# Replays the AtMostOnce counterexample of models/Rewards.tla (config rewards-today-two-nofail-once) on the
# real stores: two games on one user:// folder, each a Profile and Progress of its own, as two processes
# would hold them. Steps: Launch A, Launch B, A earns and saves, B earns and saves (its save merges A's).
# It prints REPRODUCED when both games ran the grant (each grant_once path returned a fresh settle) and
# the file holds the unlock once, NOT REPRODUCED otherwise.
# Copy it into sketches/core-loop/tests/ to run it (SKILL.md, "Read a result"); it is not a suite test.

const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const RunState := preload("res://src/core/run_state.gd")
const GameEvents := preload("res://src/core/game_events.gd")

const DIR := "user://replay_reward_twice/"
const ROW := "replay_row"
const PAINT := "paint_replay"
const ROWS := {ROW: {"name": "Replay", "on": "boss_defeated", "count": 1, "reward": {"cosmetic": PAINT}}}


func _initialize() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(DIR)
	var reproduced := _replay()
	_clean()
	print("REPRODUCED" if reproduced else "NOT REPRODUCED")
	quit(0)


func _clean() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	DirAccess.remove_absolute(DIR)


func _game(events) -> Array:
	var profile := Profile.new(DIR + "profile.json")
	profile.load_profile()
	var progress := Progress.new()
	progress.rows = ROWS
	progress.setup(events, RunState.new(), profile, func(): return 1000.0)
	return [profile, progress]


func _replay() -> bool:
	var events_a := GameEvents.new()
	var events_b := GameEvents.new()
	var a := _game(events_a)
	var b := _game(events_b)
	var paid := [0, 0]
	events_a.achievement_earned.connect(func(_id): paid[0] += 1)
	events_b.achievement_earned.connect(func(_id): paid[1] += 1)
	events_a.boss_defeated.emit()
	print("step A earns: A cosmetic %s, earn announced %d, file generation %d" % [a[0].has_cosmetic(PAINT), paid[0], a[0].generation()])
	events_b.boss_defeated.emit()
	print("step B earns: B cosmetic %s, earn announced %d, file generation %d" % [b[0].has_cosmetic(PAINT), paid[1], b[0].generation()])
	var disk := Profile.new(DIR + "profile.json")
	disk.load_profile()
	var count: int = disk._doc["cosmetics"].count(PAINT)
	print("step file: cosmetic held %d time(s), settled %s" % [count, disk.is_settled("reward:%s:cosmetic:%s" % [ROW, PAINT])])
	a[1].free()
	b[1].free()
	events_a.free()
	events_b.free()
	return paid[0] == 1 and paid[1] == 1 and count == 1
