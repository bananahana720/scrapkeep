extends SceneTree

const Intent := preload("res://src/movement/intent.gd")
const RunStore := preload("res://src/core/run_store.gd")
const RunState := preload("res://src/core/run_state.gd")
const Relics := preload("res://src/build/relics.gd")
const Game := preload("res://src/game.gd")

# Continue from the entrances of worlds 2 and 3 on the game's default table, with a store.
#   (a) for the first stage of world 2 and of world 3: enter it, free the Game, boot a new one
#       on the same path; Continue is offered and resume_run() lands on that stage with
#       world == world_of(stage), the stage's world built, the ball at the saved entry pose
#       just above the ground, and hp, parts, relics, tree picks, the spent earned-save flag and
#       retries_spent (a dead field since wave 19, still read so an old save loads) as saved.
#       Both entrance docs validate.
#   (b) the profile (worlds, pilots, settled ids) and the run doc's worlds_cleared survive the
#       save and the reload, and the next entrance save still carries worlds_cleared;
#   (c) migration: a schema-1 doc written before world was wired (world 0) and a v0 store file
#       (no schema, retries_spent as [world, count] pairs) both resume with the world
#       recomputed from the stage, and the v0 file is kept as .v0 on the first save.

const DIR := "user://run_resume_worlds_test/"
const PATH := DIR + "run.json"
const PROFILE := DIR + "profile.keep.json"
const POSE_TOLERANCE := 0.05

var _game
var _failures := 0
var _checks := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	_run.call_deferred()


func _clean() -> void:
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)


# The run file and its backups; the carried profile stays.
func _clean_run() -> void:
	for name in DirAccess.get_files_at(DIR):
		if name.begins_with("run.json"):
			DirAccess.remove_absolute(DIR + name)


func _report(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


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


func _disk() -> Dictionary:
	return RunStore.new(PATH).load()


func _start_run() -> void:
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(5)


func _state() -> Dictionary:
	var run = _game.run
	return {
		"stage": run.stage, "world": run.world, "hp": run.hp, "parts": Array(run.parts.duplicate()),
		"relics": Relics.held(run.parts), "picks": Array(_game.player.tree.picks.duplicate()),
		"spent": run.retries_spent.duplicate(), "save": run.death_save_spent,
	}


func _same(a: Dictionary, b: Dictionary) -> bool:
	return a["stage"] == b["stage"] and is_equal_approx(a["hp"], b["hp"]) and a["parts"] == b["parts"] \
		and a["relics"] == b["relics"] and a["picks"] == b["picks"] and a["spent"] == b["spent"] and a["save"] == b["save"]


# Picks the tree's first offer when one is owed; true when a pick landed.
func _pick() -> bool:
	var tree = _game.player.tree
	var offer: Array = tree.offered(tree.class_id, tree.picks.size() + 1)
	return tree.pending() and not offer.is_empty() and tree.pick(offer[0]["id"])


# Frees the Game when one is live, boots a new one on the same path and Continues. A test-mode
# Game wipes its storage_dir on exit, so the profile is carried across by hand, the way a real
# user:// directory would keep it, and loaded before Continue. Returns what the new Game
# offered and whether it resumed, plus whether the stage's world was built before the resume.
func _reboot_and_continue(stage: int) -> Dictionary:
	if is_instance_valid(_game):
		DirAccess.copy_absolute(_game.ctx.profile.path, PROFILE)
		_game.free()
	_game = _boot()
	await _frames(2)
	if FileAccess.file_exists(PROFILE):
		DirAccess.copy_absolute(PROFILE, _game.ctx.profile.path)
		_game.ctx.profile.load_profile()
	var built_before: bool = _game.ctx.terrain.is_built(stage)
	var offered: bool = _game.flow.continue_ready
	var resumed: bool = _game.flow.resume_run()
	return {"offered": offered, "resumed": resumed, "built_before": built_before}


func _resume_case(stage: int, saved: Dictionary, doc: Dictionary) -> void:
	var stages = _game.ctx.stages
	var world: int = stages.world_of(stage)
	var why := RunState.validate_entrance_doc(doc)
	_report("stage %d entrance doc validates" % stage, why == "" and int(doc.get("stage", -1)) == stage and int(doc.get("world", -1)) == world,
		"validate '%s', doc stage %s world %s (world_of %d)" % [why, doc.get("stage"), doc.get("world"), world])
	var r: Dictionary = await _reboot_and_continue(stage)
	var terrain = _game.ctx.terrain
	var back := _state()
	var ball: Vector3 = _game.player.body().global_position
	var p: Array = doc["entry_position"]
	var pose := Vector3(p[0], p[1], p[2])
	var above: float = ball.y - terrain.height(ball.x, ball.z)
	_report("stage %d continue lands in world %d" % [stage, world],
		r["offered"] and r["resumed"] and _game.flow.state_name() == "stage" and _game.run.stage == stage and _game.run.world == world \
			and terrain.is_built(stage) and terrain.stage == stage,
		"offered %s resumed %s, flow %s, stage %d world %d, built %s (before resume %s), terrain stage %d" \
			% [r["offered"], r["resumed"], _game.flow.state_name(), _game.run.stage, _game.run.world, terrain.is_built(stage), r["built_before"], terrain.stage])
	_report("stage %d ball at the entrance" % stage, ball.distance_to(pose) <= POSE_TOLERANCE and above > 0.0 and above <= _game.flow.ENTRY_LIFT + 4.0,
		"ball %s, saved %s, %.2f m above the ground (ENTRY_LIFT %.1f)" % [ball, pose, above, _game.flow.ENTRY_LIFT])
	_report("stage %d run state as saved" % stage, _same(back, saved) and not back["parts"].is_empty() and not back["relics"].is_empty() \
			and not back["picks"].is_empty() and not back["spent"].is_empty(),
		"back %s, saved %s" % [back, saved])


func _run() -> void:
	_game = _boot()
	await _frames(2)
	var stages = _game.ctx.stages
	var w2: int = stages.first_of(2)
	var w3: int = stages.first_of(3)
	var v := Vector3(0.0, 0.0, 14.0)

	# The profile's unlocks, saved before the run.
	var profile = _game.ctx.profile
	profile.unlock_world("dig")
	profile.unlock_pilot("runner_gunner")
	profile.settle("resume_worlds_grant")
	var profile_saved: bool = profile.save()

	# (a) world 2's entrance.
	await _start_run()
	_game.run.add_part("boost_coil", "test")
	var relic_ids: Array = Relics.eligible(_game.run.class_id(), Relics.held(_game.run.parts))
	if not relic_ids.is_empty():
		_game.run.add_part(Relics.part_of(relic_ids[0]), "test")
	var relic_added: bool = not relic_ids.is_empty() and not Relics.held(_game.run.parts).is_empty()
	_game.run.damage(12.0, "test")
	var picked := _pick()
	_game.run.retries_spent[1] = 1
	_game.run.extra["worlds_cleared"] = [1]
	_game.flow.enter_stage(w2, v, false)
	var saved2 := _state()
	var doc2 := _disk()
	_report("world 2 setup", profile_saved and relic_added and picked and doc2.get("worlds_cleared", []) == [1],
		"profile saved %s, relic %s, tree pick %s, worlds_cleared on disk %s" % [profile_saved, relic_added, picked, doc2.get("worlds_cleared")])
	await _resume_case(w2, saved2, doc2)

	# (b) the profile and worlds_cleared after the reload.
	profile = _game.ctx.profile
	_report("profile survives the reload", profile.has_world("dig") and profile.has_pilot("runner_gunner") and profile.is_settled("resume_worlds_grant") \
			and _game.run.settled.has("resume_worlds_grant"),
		"worlds %s pilot %s settled %s, run settled %s" % [profile.has_world("dig"), profile.has_pilot("runner_gunner"), profile.is_settled("resume_worlds_grant"), _game.run.settled])
	_report("worlds_cleared survives the reload", _game.run.extra.get("worlds_cleared", []) == [1],
		"run extra %s" % [_game.run.extra])

	# (a) world 3's entrance, from the resumed run: more picked up on the way.
	_game.run.add_part("boost_coil", "test")
	_game.run.damage(5.0, "test")
	_game.run.retries_spent[2] = 1
	_game.run.death_save_spent = true
	_game.flow.enter_stage(w3, v, false)
	var saved3 := _state()
	var doc3 := _disk()
	_report("worlds_cleared carried to the next entrance", doc3.get("worlds_cleared", []) == [1],
		"world 3 entrance doc worlds_cleared %s" % [doc3.get("worlds_cleared")])
	await _resume_case(w3, saved3, doc3)
	profile = _game.ctx.profile
	_report("profile and worlds_cleared after the second reload", profile.has_world("dig") and profile.has_pilot("runner_gunner") \
			and profile.is_settled("resume_worlds_grant") and _game.run.extra.get("worlds_cleared", []) == [1],
		"worlds %s pilot %s settled %s, worlds_cleared %s" % [profile.has_world("dig"), profile.has_pilot("runner_gunner"), profile.is_settled("resume_worlds_grant"), _game.run.extra.get("worlds_cleared")])

	# (c) a schema-1 doc from before world was wired: world 0 on a world-3 stage.
	var old: Dictionary = doc3.duplicate(true)
	old["world"] = 0
	old.erase("worlds_cleared")
	_clean_run()
	_write({"schema": 1, "generation": 1, "run": old})
	var r: Dictionary = await _reboot_and_continue(w3)
	_report("pre-wiring doc resumes with the world recomputed", RunState.validate_entrance_doc(old) == "" and r["offered"] and r["resumed"] \
			and _game.run.stage == w3 and _game.run.world == stages.world_of(w3) and int(_disk().get("world", -1)) == stages.world_of(w3),
		"offered %s resumed %s, stage %d world %d (world_of %d), saved world %s" \
			% [r["offered"], r["resumed"], _game.run.stage, _game.run.world, stages.world_of(w3), _disk().get("world")])

	# (c) a v0 store file: no schema or generation, retries_spent as pairs, world 0, world 2's stage.
	var v0: Dictionary = doc2.duplicate(true)
	v0["world"] = 0
	v0["retries_spent"] = [[1, 1]]
	_clean_run()
	_write({"run": v0})
	var migrated: Dictionary = _disk()
	r = await _reboot_and_continue(w2)
	var after := _disk()
	_report("v0 store resumes with the world recomputed", RunState.validate_entrance_doc(migrated) == "" and r["offered"] and r["resumed"] \
			and _game.run.stage == w2 and _game.run.world == stages.world_of(w2) and _game.run.retries_spent == {1: 1} \
			and int(after.get("world", -1)) == stages.world_of(w2) and after.get("worlds_cleared", []) == [1] and FileAccess.file_exists(PATH + ".v0"),
		"validate '%s', offered %s resumed %s, stage %d world %d (world_of %d), retries_spent %s, saved world %s worlds_cleared %s, .v0 kept %s" \
			% [RunState.validate_entrance_doc(migrated), r["offered"], r["resumed"], _game.run.stage, _game.run.world, stages.world_of(w2),
				_game.run.retries_spent, after.get("world"), after.get("worlds_cleared"), FileAccess.file_exists(PATH + ".v0")])

	_game.free()
	_clean()
	DirAccess.remove_absolute(DIR)
	print("run_resume_worlds_test: %s" % ("PASS (%d checks)" % _checks if _failures == 0 else "FAIL (%d of %d)" % [_failures, _checks]))
	quit(0 if _failures == 0 else 1)


func _write(doc: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc))
	f.close()
