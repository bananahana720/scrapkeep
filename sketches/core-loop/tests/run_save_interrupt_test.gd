extends SceneTree
# smoke: bots timeout=1200s
# 2026-10-15 RS-CAP: the whole-flow interrupt replays ran at 131 s at load 3 and about 160 s under
# load, and hit the 180 s default limit in three smokes, so the test moved to the bot tier
# (npm run sketch:bots; sketch:gate runs both). Every check is unchanged.

const Intent := preload("res://src/movement/intent.gd")
const RunStore := preload("res://src/core/run_store.gd")
const RunState := preload("res://src/core/run_state.gd")
const Profile := preload("res://src/core/profile.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")

# Interrupted transitions (RS5): the process dies between two steps of a transition, and a fresh
# Game loads whatever the files on disk hold. A kill is simulated by driving flow to the point,
# freeing the Game with no further save, and booting a new one from the files. "Killed before the
# write" is a store whose save or clear is dropped; "killed after the write" is the plain store.
# For each step the resumed run must be the pre-step or the post-step entrance, never a mix:
# stage, world, hp, max_hp, mass, cogs, parts, retries_spent and the entry pose all come from one
# of the two documents. Also: retries_spent never decreases on disk, a profile unlock is never
# lost once its save returned, nothing the run store leaves behind loads as corrupt, the file's
# generation never goes down, and each hostile file (unreadable, newer_schema, invalid_run) is
# named and leaves the title with New run only.

const DIR := "user://run_save_interrupt_test/"
const PATH := DIR + "run.json"
const POSE_TOLERANCE := 0.05


class TwoWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return TwoWorld


# A store whose writes can be dropped, as if the process died just before them.
class DropStore extends "res://src/core/run_store.gd":
	var drop_saves := false
	var drop_clear := false
	var dropped := 0

	func save(doc: Dictionary) -> String:
		if drop_saves:
			dropped += 1
			return ""
		return super.save(doc)

	func clear() -> bool:
		if drop_clear:
			dropped += 1
			return true
		return super.clear()


var _game
var _failures := 0
var _profile_dir := DIR + "profiles/"


func _initialize() -> void:
	_wipe()
	_run.call_deferred()


func _wipe() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	DirAccess.make_dir_recursive_absolute(_profile_dir)
	for dir in [DIR, _profile_dir]:
		for name in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + name)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _boot():
	var game = TwoWorldGame.new()
	game.test_mode = true
	game.run_store_path = PATH
	root.add_child(game)
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	var store := DropStore.new(PATH)
	store.load()
	game.flow.store = store
	await _frames(3)
	return game


func _begin(game, class_index: int) -> void:
	game.flow.press_start()
	game.flow.choose_class(class_index)
	await _frames(3)


func _state(game) -> Dictionary:
	var run = game.run
	var pose: Vector3 = run.snapshot_value("entry_position")
	return {
		"stage": run.stage, "world": run.world, "hp": run.hp, "max_hp": run.max_hp, "mass": run.mass,
		"cogs": run.cogs, "parts": Array(run.parts), "spent": _spent(run.retries_spent), "pose": pose,
	}


func _doc_state(doc: Dictionary) -> Dictionary:
	var p: Array = doc["entry_position"]
	return {
		"stage": int(doc["stage"]), "world": int(doc["world"]), "hp": float(doc["hp"]), "max_hp": float(doc["max_hp"]),
		"mass": float(doc["mass"]), "cogs": int(doc.get("cogs", 0)), "parts": Array(doc["parts"]),
		"spent": _spent(doc["retries_spent"]), "pose": Vector3(p[0], p[1], p[2]),
	}


func _spent(map: Dictionary) -> Dictionary:
	var out := {}
	for w in map:
		out[int(str(w))] = int(map[w])
	return out


func _same(a: Dictionary, b: Dictionary) -> bool:
	return a["stage"] == b["stage"] and a["world"] == b["world"] and is_equal_approx(a["hp"], b["hp"]) \
		and is_equal_approx(a["max_hp"], b["max_hp"]) and is_equal_approx(a["mass"], b["mass"]) \
		and a["cogs"] == b["cogs"] and a["parts"] == b["parts"] and a["spent"] == b["spent"] \
		and (a["pose"] as Vector3).distance_to(b["pose"]) < POSE_TOLERANCE


func _disk() -> Dictionary:
	return RunStore.new(PATH).load()


func _raw_gen() -> int:
	if not FileAccess.file_exists(PATH):
		return -1
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return int(parsed.get("generation", -1)) if parsed is Dictionary else -1


func _spent_on_disk(world: int) -> int:
	return int(_disk().get("retries_spent", {}).get(str(world), 0))


func _bad_files() -> Array:
	var out := []
	for name in DirAccess.get_files_at(DIR):
		if ".bad" in name:
			out.append(name)
	return out


# What a fresh store makes of the file left behind: a valid run, or a tombstone/no run, and no
# sign it judged the file corrupt (no refusal, no error sentence, nothing moved to .bad).
func _loads_clean() -> bool:
	var store := RunStore.new(PATH)
	var doc := store.load()
	var valid: bool = doc.is_empty() or RunState.validate_entrance_doc(doc) == ""
	# An ended run's tombstone is a named refusal (run_ended), not damage.
	var ended := store.refusal == RunStore.REFUSED_ENDED
	return valid and (ended or (store.refusal == "" and store.last_error == "")) and _bad_files().is_empty()


func _tear(game) -> void:
	game.free()


func _grow(game) -> void:
	game.run.add_part("boost_coil", "test")
	game.run.damage(12.0, "test")
	game.run.mass += 40.0
	game.run.add_cogs(7)


func _kill(game) -> void:
	game.run.damage(9999.0, "test")


func _run() -> void:
	for lose in [true, false]:
		await _entrance_case(lose)
	for lose in [true, false]:
		await _retry_case(lose)
	await _boss_case()
	for lose in [true, false]:
		await _world_case(lose)
	for lose in [true, false]:
		await _end_case(lose)
	await _new_run_case()
	await _hostile_cases()
	_wipe()
	DirAccess.remove_absolute(_profile_dir)
	DirAccess.remove_absolute(DIR)
	print("run_save_interrupt_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


# (1) Stage 2's entrance: the doc is written once the ball is placed. Killed before that write
# the disk still holds stage 1's entrance; killed after, stage 2's, pose included.
func _entrance_case(lose: bool) -> void:
	var label := "entrance, killed %s the write" % ("before" if lose else "after")
	_wipe()
	_game = await _boot()
	await _begin(_game, 1)
	var pre := _doc_state(_disk())
	var gen_pre := _raw_gen()
	_grow(_game)
	_game.flow.store.drop_saves = lose
	_game.flow.enter_stage(2, Vector3(0.0, 0.0, 14.0), false)
	var post := _state(_game)
	_tear(_game)
	if lose:
		# A write cut short leaves a half-written temp file beside the whole old one.
		var tmp := FileAccess.open(PATH + ".4242.tmp", FileAccess.WRITE)
		tmp.store_string('{"schema": 1, "generation": 9, "run": {"sta')
		tmp.close()
	var gen_disk := _raw_gen()
	_game = await _boot()
	var resumed: bool = _game.flow.resume_run()
	var back := _state(_game)
	var want := pre if lose else post
	var either: bool = _same(back, pre) or _same(back, post)
	var distinct: bool = not _same(pre, post)
	_report(label, resumed and distinct and either and _same(back, want) and post["stage"] == 2 and pre["stage"] == 1 \
		and (gen_disk == gen_pre if lose else gen_disk > gen_pre) and _loads_clean(),
		"resumed %s at stage %d: %s; pre %s, post %s; generation %d then %d" % [resumed, back["stage"], back, pre, post, gen_pre, gen_disk])
	_tear(_game)


# (2) A death retry spends the world's one retry and saves the entrance with it. Killed before the
# write the disk holds the unspent entrance (a lost spend, the retry is given back); killed after,
# the spend. The count on disk never goes down, and a spend that was saved stays spent.
func _retry_case(lose: bool) -> void:
	var label := "retry spend, killed %s the write" % ("before" if lose else "after")
	_wipe()
	_game = await _boot()
	await _begin(_game, 0)
	var pre := _doc_state(_disk())
	var spent_pre := _spent_on_disk(1)
	var gen_pre := _raw_gen()
	_kill(_game)
	var dead: bool = _game.flow.state_name() == "dead"
	_game.flow.store.drop_saves = lose
	_game.flow.retry_stage()
	var post := _state(_game)
	_tear(_game)
	var spent_disk := _spent_on_disk(1)
	var gen_disk := _raw_gen()
	_game = await _boot()
	var resumed: bool = _game.flow.resume_run()
	var back := _state(_game)
	var want := pre if lose else post
	var spent_after := _spent_on_disk(1)
	# One more death on the resumed run: spent retries are not handed back.
	_kill(_game)
	var ends_after: bool = _game.flow.state_name() == ("dead" if lose else "summary")
	_report(label, dead and resumed and _same(back, want) and (_same(back, pre) or _same(back, post)) \
		and spent_disk >= spent_pre and spent_after >= spent_disk and spent_disk == (0 if lose else 1) \
		and (gen_disk == gen_pre if lose else gen_disk > gen_pre) and ends_after and _loads_clean(),
		"dead %s; spent on disk %d then %d (resume spent %s); next death flow %s; generation %d then %d" % [dead, spent_pre, spent_disk, back["spent"], _game.flow.state_name(), gen_pre, gen_disk])
	_tear(_game)


# (3) A boss kill earns the unlock and saves the profile straight away. Killed before that save
# the profile holds no unlock and loads clean; once the save returned, no later save (the run's
# end, a stale writer) takes the unlock back, and the run itself resumes at its entrance.
func _boss_case() -> void:
	_wipe()
	var held := _profile_dir + "held.json"
	_game = await _boot()
	await _begin(_game, 0)
	await physics_frame
	await physics_frame
	var entrance := _doc_state(_disk())
	var live_profile := String(_game.storage_dir).path_join("profile.json")
	var before := Profile.new(held)
	var earned := [false]
	_game.events.achievement_earned.connect(func(id): earned[0] = earned[0] or id == "brindle_routed")
	_game.events.enemy_killed.emit("brindle", Vector3.ZERO, 0)
	var saved_ok := FileAccess.file_exists(live_profile)
	var after_bytes := FileAccess.get_file_as_bytes(live_profile)
	var out := FileAccess.open(_profile_dir + "after.json", FileAccess.WRITE)
	out.store_buffer(after_bytes)
	out.close()
	# The run file as the kill left it, kept before the run goes on and ends.
	var run_bytes := FileAccess.get_file_as_bytes(PATH)
	# The run goes on and ends: its profile saves must keep the unlock.
	_kill(_game)
	_game.flow.retry_stage()
	_kill(_game)
	var ended: bool = _game.flow.state_name() == "summary"
	var end_bytes := FileAccess.get_file_as_bytes(live_profile)
	out = FileAccess.open(_profile_dir + "end.json", FileAccess.WRITE)
	out.store_buffer(end_bytes)
	out.close()
	_tear(_game)

	# Killed before the save returned: the file the boss kill never wrote. A torn temp file beside it.
	var tmp := FileAccess.open(held + ".4242.tmp", FileAccess.WRITE)
	tmp.store_string('{"schema": 1, "generation": 9, "pilots": ["ta')
	tmp.close()
	var pre_load := before.load_profile()
	var pre_clean: bool = pre_load and not before.has_pilot("tarn") and before.last_error == ""

	var after := Profile.new(_profile_dir + "after.json")
	var after_ok := after.load_profile() and after.has_pilot("tarn") and after.can_save
	var done := Profile.new(_profile_dir + "end.json")
	var done_ok := done.load_profile() and done.has_pilot("tarn") and done.generation() >= after.generation()

	# A stale writer that loaded the profile before the unlock saves over it: the merge keeps it.
	DirAccess.copy_absolute(_profile_dir + "after.json", _profile_dir + "stale.json")
	var stale := Profile.new(_profile_dir + "stale.json")
	stale.load_profile()
	var late := Profile.new(_profile_dir + "stale.json")
	late.load_profile()
	late.unlock_cosmetic("paint_any_night")
	late.save()
	var stale_saved := stale.save()
	var merged := Profile.new(_profile_dir + "stale.json")
	merged.load_profile()
	var stale_ok: bool = stale_saved and merged.has_pilot("tarn") and merged.has_cosmetic("paint_any_night") and merged.generation() > after.generation()

	out = FileAccess.open(PATH, FileAccess.WRITE)
	out.store_buffer(run_bytes)
	out.close()
	_game = await _boot()
	var resumed: bool = _game.flow.resume_run()
	var back := _state(_game)
	_report("boss kill and unlock, killed before the profile save", pre_clean and resumed and _same(back, entrance) and _loads_clean(),
		"profile without the unlock loads clean %s; run resumed %s at stage %d, matching the entrance %s" % [pre_clean, resumed, back["stage"], _same(back, entrance)])
	_report("boss kill and unlock, killed after the profile save", saved_ok and earned[0] and after_ok and done_ok and ended and stale_ok,
		"earned %s, file written %s, unlock on disk %s, kept through the run's end %s (generation %d to %d), stale writer's save %s" % [earned[0], saved_ok, after_ok, done_ok, after.generation(), done.generation(), stale_ok])
	_tear(_game)


# (4) World 1 cleared, world 2's first entrance. Killed before the write the run resumes at the
# stage-3 entrance with world 1's spent retry; killed after, at stage 4 in world 2 with that
# retry still spent.
func _world_case(lose: bool) -> void:
	var label := "world transition, killed %s the write" % ("before" if lose else "after")
	_wipe()
	_game = await _boot()
	await _begin(_game, 0)
	_game.flow.enter_stage(3, Vector3(0.0, 0.0, 14.0), false)
	_kill(_game)
	_game.flow.retry_stage()
	_grow(_game)
	_game.flow.enter_stage(3, Vector3(0.0, 0.0, 14.0), false)
	var pre := _doc_state(_disk())
	var gen_pre := _raw_gen()
	_game.run.add_part("boost_coil", "test")
	_game.run.add_cogs(5)
	_game.flow.store.drop_saves = lose
	_game.flow._advance_from(3)
	var post := _state(_game)
	_tear(_game)
	var gen_disk := _raw_gen()
	_game = await _boot()
	var resumed: bool = _game.flow.resume_run()
	var back := _state(_game)
	var want := pre if lose else post
	_report(label, resumed and pre["stage"] == 3 and post["stage"] == 4 and post["world"] == 2 and not _same(pre, post) \
		and _same(back, want) and (_same(back, pre) or _same(back, post)) and back["spent"].get(1, 0) == 1 \
		and (gen_disk == gen_pre if lose else gen_disk > gen_pre) and _loads_clean(),
		"resumed %s at stage %d world %d: %s; spent %s; generation %d then %d" % [resumed, back["stage"], back["world"], back, back["spent"], gen_pre, gen_disk])
	_tear(_game)


# (5) The run ends: the tombstone replaces the entrance. Killed before the clear the disk still
# holds the last entrance, with the spent retry in it (the next death ends the run, as it would
# have); killed after, no run and the title offers none.
func _end_case(lose: bool) -> void:
	var label := "run end, killed %s the tombstone" % ("before" if lose else "after")
	_wipe()
	_game = await _boot()
	await _begin(_game, 0)
	_kill(_game)
	_game.flow.retry_stage()
	var pre := _doc_state(_disk())
	var gen_pre := _raw_gen()
	_game.flow.store.drop_clear = lose
	_kill(_game)
	var ended: bool = _game.flow.state_name() == "summary"
	_tear(_game)
	var gen_disk := _raw_gen()
	var raw := FileAccess.get_file_as_string(PATH)
	_game = await _boot()
	var doc: Dictionary = _game.flow.saved_run()
	var cause: String = _game.flow.saved_run_cause
	var resumed: bool = _game.flow.resume_run()
	var detail := "ended %s; generation %d then %d; title offers continue %s (cause '%s')" % [ended, gen_pre, gen_disk, not doc.is_empty(), cause]
	if lose:
		var back := _state(_game)
		_kill(_game)
		_report(label, ended and resumed and _same(back, pre) and gen_disk == gen_pre and _game.flow.state_name() == "summary" and _loads_clean(),
			detail + "; resumed spent %s, next death flow %s" % [back["spent"], _game.flow.state_name()])
	else:
		_report(label, ended and not resumed and doc.is_empty() and cause == "" and gen_disk > gen_pre and raw.contains("\"ended\": true") \
			and not raw.contains("\"run\"") and _loads_clean(), detail + "; file %s" % raw.replace("\n", " "))
	_tear(_game)


# A crash mid-run and then New run (not Continue): the new run does not inherit the old run's
# spent retries, and the generation keeps rising.
func _new_run_case() -> void:
	_wipe()
	_game = await _boot()
	await _begin(_game, 0)
	_kill(_game)
	_game.flow.retry_stage()
	var gen_old := _raw_gen()
	var spent_old := _spent_on_disk(1)
	_tear(_game)
	_game = await _boot()
	await _begin(_game, 0)
	var gen_new := _raw_gen()
	var spent_new := _spent_on_disk(1)
	_report("crash then New run", spent_old == 1 and spent_new == 0 and gen_new > gen_old and _loads_clean(),
		"old spent %d, new run's spent %d; generation %d then %d" % [spent_old, spent_new, gen_old, gen_new])
	_tear(_game)


func _write_file(file_path: String, text: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# One hostile file per refusal cause. The store names it on load(), and a booted Game's title
# (flow.saved_run) offers no Continue, names the same cause, and a New run goes on.
func _hostile_cases() -> void:
	_wipe()
	_game = await _boot()
	await _begin(_game, 0)
	var good := FileAccess.get_file_as_string(PATH)
	var good_doc := _disk()
	_tear(_game)
	var invalid_doc: Dictionary = good_doc.duplicate(true)
	invalid_doc.erase("hp")
	var cases := {
		"unreadable": '{"schema": 1, "generation": 3, "run": {"stage":',
		"newer_schema": '{"schema": 9, "generation": 4, "run": {"x": 1}}',
		"invalid_run": JSON.stringify({"schema": 1, "generation": 3, "run": invalid_doc}),
	}
	for cause in cases:
		_wipe()
		_write_file(DIR + "probe.json", cases[cause])
		var probe := RunStore.new(DIR + "probe.json")
		var probed := probe.load()
		var named := false
		match cause:
			"unreadable":
				named = probed.is_empty() and probe.refusal == RunStore.REFUSED_CHANGED and "unreadable" in probe.last_error and ".bad" in probe.last_error \
					and FileAccess.file_exists(DIR + "probe.json.bad")
			"newer_schema":
				named = probed.is_empty() and probe.refusal == "newer_schema" and probe.save(good_doc) == "newer_schema"
			"invalid_run":
				named = not probed.is_empty() and RunState.validate_entrance_doc(probed) != ""
		DirAccess.remove_absolute(DIR + "probe.json")
		DirAccess.remove_absolute(DIR + "probe.json.bad")
		_write_file(PATH, cases[cause])
		var bytes := FileAccess.get_file_as_bytes(PATH)
		_game = await _boot()
		# The boot's title already read the file once; the fields below are what it shows.
		var cause_shown: String = _game.flow.saved_run_cause
		var offered: bool = _game.flow.continue_ready
		var resumed: bool = _game.flow.resume_run() if cause == "newer_schema" else false
		await _begin(_game, 0)
		var after := FileAccess.get_file_as_bytes(PATH)
		var new_run_ok := false
		match cause:
			"newer_schema":
				new_run_ok = after == bytes and _game.flow.store_error == "newer_schema"
			_:
				new_run_ok = _disk().get("stage", 0) == 1 and RunState.validate_entrance_doc(_disk()) == ""
		_report("hostile file: %s" % cause, named and cause_shown == cause and not offered and not resumed and _game.flow.state_name() == "stage" and new_run_ok,
			"load() names it %s; title cause '%s', continue offered %s; New run started %s, file after %s" % [named, cause_shown, offered, _game.flow.state_name() == "stage", "kept byte for byte" if after == bytes else "rewritten"])
		_tear(_game)
