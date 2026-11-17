extends SceneTree

const T := preload("res://tests/support/t.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const RunState := preload("res://src/core/run_state.gd")
const RunStore := preload("res://src/core/run_store.gd")
const SafeStore := preload("res://src/core/safe_store.gd")
const GameEvents := preload("res://src/core/game_events.gd")

# W1-117 and MG-13: an earned reward is paid once and never lost (ruling ea), on the routes the
# rewards model (.agents/skills/scrapkeep-verify-formal/models/Rewards.tla) names:
#   - two games on one profile, each earning the same row (finding R-2): the second takes in the
#     first's save and neither announces nor pays it again;
#   - a run file an older build left with only the legacy key, beside a profile whose saves of the
#     earn failed (finding R-3): Continue and the earn pay the reward, never settle it unpaid;
#   - a failed profile save and a Continue on this build, paid by the next launch's
#     backfill_rewards (MG-13, the route PR 1093 fixed);
#   - the profile's save lock: held by another game, released, broken when stale or dated ahead,
#     failing fast for the rest of a transact that could not take it, and naming its own error;
#   - a launch whose rewards are all paid reads no file (the backfill's fast path).
# Each game is its own Profile and Progress on one file, as two processes hold them. The test uses
# its own user:// folder and a fixed clock.

const DIR := "user://reward_once_routes_test/"
const ROW := "routes_row"
const PAINT := "paint_routes"
const LEGACY := "reward:routes_row:cosmetic"
const KEY := "reward:routes_row:cosmetic:paint_routes"
const ROWS := {ROW: {"name": "Routes", "on": "boss_defeated", "count": 1, "reward": {"cosmetic": PAINT}}}

var _t := T.new("reward_once_routes_test")
var _n := 0
var _keep: Array = []


func _initialize() -> void:
	_clear_dir()
	DirAccess.make_dir_recursive_absolute(DIR)
	_two_games_earn_once()
	_two_launches_backfill_once()
	_old_run_key_paid_not_lost()
	_old_profile_key_still_paid()
	_failed_save_continue_backfill()
	_save_lock()
	_future_lock_broken()
	_lock_fails_fast()
	_lock_error_text()
	_paid_launch_reads_nothing()
	for node in _keep:
		node.free()
	_clear_dir()
	quit(_t.verdict())


func _clear_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for sub in DirAccess.get_directories_at(DIR):
		DirAccess.remove_absolute(DIR + sub)
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + file_name)
	DirAccess.remove_absolute(DIR)


func _path(stem: String) -> String:
	_n += 1
	return "%s%s_%d.json" % [DIR, stem, _n]


func _profile(path: String) -> Profile:
	var profile := Profile.new(path)
	profile.load_profile()
	return profile


# One game: its events, a fresh run, and Progress set up on the profile (which runs backfill_rewards).
func _game(profile: Profile, run: RunState = null, rows := ROWS) -> Dictionary:
	var events := GameEvents.new()
	var progress := Progress.new()
	progress.rows = rows
	var held := run if run != null else RunState.new()
	progress.setup(events, held, profile, func(): return 1000.0)
	var game := {"profile": profile, "run": held, "progress": progress, "events": events, "announced": [0]}
	events.achievement_earned.connect(func(_id): game["announced"][0] += 1)
	_keep.append(progress)
	_keep.append(events)
	return game


func _file(path: String) -> Profile:
	return _profile(path)


# R-2: both games load the profile before either earns. A earns and pays; B earns the same row later.
func _two_games_earn_once() -> void:
	var path := _path("two")
	_profile(path).save()
	var a := _game(_profile(path))
	var b := _game(_profile(path))
	a["events"].boss_defeated.emit()
	b["events"].boss_defeated.emit()
	_t.check("R-2 game A announces the earn and pays it", a["announced"][0] == 1 and a["profile"].has_cosmetic(PAINT))
	_t.check("R-2 game B, loaded before A's save, neither announces nor pays it again", b["announced"][0] == 0, "announced %d" % b["announced"][0])
	_t.check("R-2 game B holds what A paid, taken in from the file", b["profile"].earned(ROW) and b["profile"].has_cosmetic(PAINT) and b["profile"].is_settled(KEY))
	var disk := _file(path)
	_t.check("R-2 the file holds the reward once, settled", disk._doc["cosmetics"].count(PAINT) == 1 and disk.is_settled(KEY), str(disk._doc["cosmetics"]))
	_t.check("R-2 no save failed", a["progress"].warnings == 0 and b["progress"].warnings == 0)
	_t.check("R-2 the save lock is let go", not DirAccess.dir_exists_absolute(path + ".lock"))


# R-2 at launch: a profile that holds the earn but not its payment (the grant's save failed), opened by
# two games at once. Each launch's backfill_rewards tries to pay it; the second takes in the first's.
func _two_launches_backfill_once() -> void:
	var path := _path("launch")
	var seed := _profile(path)
	seed.earn(ROW, 1000.0)
	seed.save()
	var a := _game(_profile(path), null, {})
	var b := _game(_profile(path), null, {})
	a["progress"].rows = ROWS
	b["progress"].rows = ROWS
	var first: int = a["progress"].backfill_rewards()
	var second: int = b["progress"].backfill_rewards()
	_t.check("R-2 the first launch's backfill pays the reward", first == 1 and a["profile"].has_cosmetic(PAINT), "granted %d" % first)
	_t.check("R-2 the second launch's backfill, loaded before it, pays nothing", second == 0, "granted %d" % second)
	var disk := _file(path)
	_t.check("R-2 the file holds the backfilled reward once", disk._doc["cosmetics"].count(PAINT) == 1 and disk.is_settled(KEY))


# The state an older build (before 8 November 2026, which settled the legacy key alone) leaves when both
# profile saves of an earn failed: a profile file without the earn, and a run file whose settled list
# holds the legacy key alone.
func _old_build_left(path: String, run_path: String, profile_paid: bool) -> void:
	var old := _profile(path)
	if profile_paid:
		old.earn(ROW, 900.0)
		old.settle(LEGACY)
		old.unlock_cosmetic(PAINT)
	old.save()
	var doc := RunState.new().to_entrance_doc()
	doc["settled"] = [LEGACY]
	var store := RunStore.new(run_path)
	store.load()
	store.save(doc)


# Launch, then Continue as flow.resume_run does it: load the run file, restore it, reconcile_settled.
func _launch_and_continue(path: String, run_path: String) -> Dictionary:
	var game := _game(_profile(path))
	var store := RunStore.new(run_path)
	var doc := store.load()
	game["continued"] = not doc.is_empty() and game["run"].from_entrance_doc(doc)
	game["progress"].reconcile_settled()
	return game


# R-3 (W1-117): before this fix the legacy branch of _grant_reward read the run's list, so the earn in the
# continued run settled the targeted key into the profile with no unlock, for good.
func _old_run_key_paid_not_lost() -> void:
	var path := _path("old_run")
	var run_path := _path("old_run_file")
	_old_build_left(path, run_path, false)
	var game := _launch_and_continue(path, run_path)
	_t.check("R-3 the older build's run file continues", game["continued"] and game["run"].settled.has(LEGACY), str(game["run"].settled))
	game["events"].boss_defeated.emit()
	var disk := _file(path)
	_t.check("R-3 the earn in the continued run pays the reward", disk.earned(ROW) and disk.is_settled(KEY) and disk.has_cosmetic(PAINT),
		"earned %s settled %s cosmetic %s" % [disk.earned(ROW), disk.is_settled(KEY), disk.has_cosmetic(PAINT)])
	_t.check("R-3 the file never holds the key settled without the unlock", not (disk.is_settled(KEY) and not disk.has_cosmetic(PAINT)))
	var next := _game(_profile(path), null, {})
	next["progress"].rows = ROWS
	_t.check("R-3 the next launch pays it no more", next["progress"].backfill_rewards() == 0 and _file(path)._doc["cosmetics"].count(PAINT) == 1)


# The legacy key in the profile is still what an older build paid: the targeted key joins it, nothing more is paid.
func _old_profile_key_still_paid() -> void:
	var path := _path("old_profile")
	var run_path := _path("old_profile_run")
	_old_build_left(path, run_path, true)
	var game := _game(_profile(path), null, {})
	game["progress"].rows = ROWS
	var granted: int = game["progress"].backfill_rewards()
	_t.check("R-3 an older build's paid profile is paid nothing more", granted == 0 and game["profile"].is_settled(KEY), "granted %d" % granted)
	game["profile"].save()
	var cont := _launch_and_continue(path, run_path)
	_t.check("R-3 and its continued run pays nothing more", not cont["progress"]._grant_reward(ROW, "cosmetic", PAINT))
	_t.check("R-3 the file holds the cosmetic once", _file(path)._doc["cosmetics"].count(PAINT) == 1)


# MG-13: on this build, both profile saves of an earn fail and the run file saves the key. After a
# relaunch, Continue (PR 1093: the run's reward key is not copied into the profile) and the earn again in
# the continued run, the next launch's backfill_rewards pays the reward, once.
func _failed_save_continue_backfill() -> void:
	var path := _path("mg13")
	var run_path := _path("mg13_run")
	var game := _game(_profile(path))
	var store := RunStore.new(run_path)
	store.load()
	game["profile"].save()
	store.save(game["run"].to_entrance_doc())
	var blocker := SafeStore.tmp_path(path)
	DirAccess.make_dir_recursive_absolute(blocker)
	game["events"].boss_defeated.emit()
	DirAccess.remove_absolute(blocker)
	_t.check("MG-13 both profile saves of the earn failed", game["progress"].warnings == 2 and not _file(path).earned(ROW), "warnings %d" % game["progress"].warnings)
	store.save(game["run"].to_entrance_doc())
	var cont := _launch_and_continue(path, run_path)
	_t.check("MG-13 the run file carries the key into the continued run", cont["continued"] and cont["run"].settled.has(KEY))
	_t.check("MG-13 Continue leaves the reward unsettled in the file", not _file(path).is_settled(KEY))
	cont["events"].boss_defeated.emit()
	_t.check("MG-13 the continued run saves the earn", _file(path).earned(ROW))
	var next := _game(_profile(path))
	var disk := _file(path)
	_t.check("MG-13 the next launch's backfill_rewards pays the reward", disk.has_cosmetic(PAINT) and disk.is_settled(KEY) and next["profile"].has_cosmetic(PAINT),
		"settled %s cosmetic %s" % [disk.is_settled(KEY), disk.has_cosmetic(PAINT)])
	var later := _game(_profile(path), null, {})
	later["progress"].rows = ROWS
	_t.check("MG-13 a later launch pays nothing more", later["progress"].backfill_rewards() == 0 and _file(path)._doc["cosmetics"].count(PAINT) == 1)


func _save_lock() -> void:
	var path := _path("lock")
	var lock := path + ".lock"
	var profile := _profile(path)
	_t.check("lock a save takes and lets go of the lock", profile.save() and not DirAccess.dir_exists_absolute(lock))
	DirAccess.make_dir_absolute(lock)
	var before := FileAccess.get_file_as_string(path)
	profile.unlock_cosmetic("paint_lock")
	var saved := profile.save()
	_t.check("lock a save while another game holds the lock fails and leaves the file", not saved and FileAccess.get_file_as_string(path) == before and profile.last_error.contains("another game"), profile.last_error)
	var keep := func():
		profile.unlock_cosmetic("paint_kept")
		return true
	var ran: bool = profile.transact(keep)
	_t.check("lock a transact without the lock still runs on memory (never lost)", ran and profile.has_cosmetic("paint_kept"))
	_t.check("lock the other game's lock is left alone", DirAccess.dir_exists_absolute(lock))
	profile.lock_stale_s = -1.0
	_t.check("lock a lock left by a game that died inside a save is broken", profile.save() and not DirAccess.dir_exists_absolute(lock))
	_t.check("lock and the save that broke it wrote the file", _file(path).has_cosmetic("paint_lock") and _file(path).has_cosmetic("paint_kept"))
	DirAccess.remove_absolute(lock)


# A lock whose time is ahead of the clock (a clock moved back after a game died inside a save) is stale too.
func _future_lock_broken() -> void:
	var path := _path("future")
	var lock := path + ".lock"
	var profile := _profile(path)
	DirAccess.make_dir_absolute(lock)
	var out: Array = []
	var touched := OS.execute("touch", ["-t", "203001010000", ProjectSettings.globalize_path(lock)], out, true)
	if touched != 0 or FileAccess.get_modified_time(lock) < Time.get_unix_time_from_system() + 3600.0:
		_t.skip("lock a lock dated in the future is broken", "touch could not date the lock: %s" % str(out))
		DirAccess.remove_absolute(lock)
		return
	_t.check("lock a lock dated in the future is broken", profile.save() and not DirAccess.dir_exists_absolute(lock), profile.last_error)


# After one failed take, the rest of that transact fails at once instead of waiting again: here the
# lock is freed inside the change, and the save there still does not take it.
func _lock_fails_fast() -> void:
	var path := _path("fast")
	var lock := path + ".lock"
	var profile := _profile(path)
	profile.save()
	DirAccess.make_dir_absolute(lock)
	var tried := func():
		DirAccess.remove_absolute(lock)
		return profile.save()
	var saved_inside: bool = profile.transact(tried)
	_t.check("lock inside a transact that could not take the lock, a save does not try again", not saved_inside and profile.last_error.contains("another game"), profile.last_error)
	_t.check("lock after that transact a save takes the lock again", profile.save() and not DirAccess.dir_exists_absolute(lock), profile.last_error)


# The message names the directory's own error when the lock cannot be made, not another game.
func _lock_error_text() -> void:
	var profile := _profile(DIR + "missing_folder/profile.json")
	var saved := profile.save()
	_t.check("lock a lock that cannot be made says why", not saved and profile.last_error.contains("could not take the save lock") and not profile.last_error.contains("another game"), profile.last_error)


# A launch whose rewards are all paid in memory reads nothing: a newer file written by another game
# after the load (with a cosmetic only it holds) is not taken in by the backfill.
func _paid_launch_reads_nothing() -> void:
	var path := _path("paid")
	var payer := _profile(path)
	payer.earn(ROW, 1000.0)
	payer.save()
	_game(payer)
	var launch := _profile(path)
	var other := _profile(path)
	other.unlock_cosmetic("paint_other")
	other.save()
	var game := _game(launch, null, {})
	game["progress"].rows = ROWS
	_t.check("launch every reward paid: the backfill pays nothing", game["progress"].backfill_rewards() == 0 and launch.has_cosmetic(PAINT))
	_t.check("launch and reads no file: the other game's newer save is not taken in", not launch.has_cosmetic("paint_other"))
	var owed_path := _path("owed")
	var seed := _profile(owed_path)
	seed.earn(ROW, 1000.0)
	seed.save()
	var owed := _profile(owed_path)
	var writer := _profile(owed_path)
	writer.unlock_cosmetic("paint_other")
	writer.save()
	_game(owed)
	_t.check("launch a reward memory shows unpaid is paid after one take-in of the file", owed.has_cosmetic("paint_other") and owed.has_cosmetic(PAINT) and _file(owed_path)._doc["cosmetics"].count(PAINT) == 1)
