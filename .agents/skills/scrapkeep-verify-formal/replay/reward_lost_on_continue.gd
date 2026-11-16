extends SceneTree

# Replays the NeverLost counterexample of models/Rewards.tla (config rewards-today-one) on the real
# stores, one model step per call:
#   Launch, NewRun (run document saved), Earn with the profile write failing (StepG, FailW),
#   Checkpoint (run document saved with the settled id), Quit, Launch, Continue (reconcile_settled
#   and its profile save).
# The failed write is real: a directory sits where safe_store.gd puts the profile's temp file, so
# profile.save() returns false through its own write path. No game code is changed.
# It prints REPRODUCED when the profile ends holding the id settled without the cosmetic and a fresh
# earn and a fresh launch both leave it unpaid, NOT REPRODUCED otherwise.
# The control (`-- --control` after the script) is the same steps with the write failure left out; it must print
# NOT REPRODUCED.
# Copy it into sketches/core-loop/tests/ to run it (SKILL.md, "Read a result"); it is not a suite test.

const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const RunState := preload("res://src/core/run_state.gd")
const RunStore := preload("res://src/core/run_store.gd")
const SafeStore := preload("res://src/core/safe_store.gd")
const GameEvents := preload("res://src/core/game_events.gd")

const DIR := "user://replay_reward_lost/"

var control := OS.get_cmdline_user_args().has("--control")
const ROW := "replay_row"
const PAINT := "paint_replay"
const KEY := "reward:replay_row:cosmetic:paint_replay"
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
	for d in DirAccess.get_directories_at(DIR):
		DirAccess.remove_absolute(DIR + d)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	DirAccess.remove_absolute(DIR)


func _launch(events) -> Array:
	var profile := Profile.new(DIR + "profile.json")
	profile.load_profile()
	var run := RunState.new()
	var progress := Progress.new()
	progress.rows = ROWS
	progress.setup(events, run, profile, func(): return 1000.0)
	var store := RunStore.new(DIR + "run.json")
	store.load()
	return [profile, run, progress, store]


func _on_disk() -> Profile:
	var p := Profile.new(DIR + "profile.json")
	p.load_profile()
	return p


func _replay() -> bool:
	var events := GameEvents.new()
	# Launch, then NewRun: the profile's door save and the first entrance save.
	var a := _launch(events)
	var profile: Profile = a[0]
	var run: RunState = a[1]
	var progress: Progress = a[2]
	var store: RunStore = a[3]
	print("step launch+newrun: profile saved %s, run saved '%s'" % [profile.save(), store.save(run.to_entrance_doc())])
	# Earn, with every profile write failing.
	var blocker := SafeStore.tmp_path(profile.path)
	if not control:
		DirAccess.make_dir_recursive_absolute(blocker)
	events.boss_defeated.emit()
	print("step earn: earned %s, cosmetic in memory %s, run settled %s, save warnings %d" % [
		profile.earned(ROW), profile.has_cosmetic(PAINT), run.settled.has(KEY), progress.warnings])
	DirAccess.remove_absolute(blocker)
	# Checkpoint: the next entrance saves the run document only.
	print("step checkpoint: run saved '%s'" % store.save(run.to_entrance_doc()))
	var disk := _on_disk()
	print("step quit: profile file earned %s settled %s cosmetic %s" % [disk.earned(ROW), disk.is_settled(KEY), disk.has_cosmetic(PAINT)])
	progress.free()
	events.free()
	# Launch again (progress.setup runs backfill_rewards), then Continue: flow.resume_run's
	# run_state.from_entrance_doc and progress.reconcile_settled (flow.gd:595-599).
	events = GameEvents.new()
	var b := _launch(events)
	profile = b[0]
	run = b[1]
	progress = b[2]
	store = b[3]
	var doc := store.load()
	print("step continue: doc loads %s, from_entrance_doc %s" % [not doc.is_empty(), run.from_entrance_doc(doc)])
	progress.reconcile_settled()
	disk = _on_disk()
	var lost := disk.is_settled(KEY) and not disk.has_cosmetic(PAINT)
	print("step reconcile: profile file earned %s settled %s cosmetic %s" % [disk.earned(ROW), disk.is_settled(KEY), disk.has_cosmetic(PAINT)])
	# The fact again in the continued run, then a fresh launch with its backfill.
	events.boss_defeated.emit()
	print("step earn again: earned %s cosmetic %s" % [profile.earned(ROW), profile.has_cosmetic(PAINT)])
	progress.free()
	events.free()
	events = GameEvents.new()
	var c := _launch(events)
	var last: Profile = c[0]
	print("step relaunch: earned %s settled %s cosmetic %s" % [last.earned(ROW), last.is_settled(KEY), last.has_cosmetic(PAINT)])
	var never_paid := not last.has_cosmetic(PAINT) and last.earned(ROW) and last.is_settled(KEY)
	c[2].free()
	events.free()
	return lost and never_paid
