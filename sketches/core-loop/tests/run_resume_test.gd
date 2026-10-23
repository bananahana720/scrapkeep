extends SceneTree

const Intent := preload("res://src/movement/intent.gd")
const RunStore := preload("res://src/core/run_store.gd")
const Activities := preload("res://src/world/activities.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")

# RS3: the run store wired into flow, on the two-world table.
#   (a) a run entered at a zone entrance and quit resumes in a new Game at that entrance with
#       the same hp, mass, cogs, parts and tree picks, and nothing refunded by the Continue;
#   (b) there is no free retry: a death with no earned save ends the run on the summary, in
#       any world, and a new run starts with no save spent;
#   (c) a crash after the entrance write replays the same activity offers (_roll's part ids);
#   (d) the ended run leaves a tombstone, so the store holds no run.

const DIR := "user://run_resume_test/"
const PATH := DIR + "run.json"
const POSE_TOLERANCE := 0.05


class TwoWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return TwoWorld


var _game
var _failures := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)
	_run.call_deferred()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _boot():
	var game := TwoWorldGame.new()
	game.test_mode = true
	game.run_store_path = PATH
	root.add_child(game)
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	return game


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _rolls(game) -> Array:
	var out := []
	for id in Activities.RULES:
		out.append(game.world.activities._roll(id, Activities.RULES[id]["pay"]["rarities"]))
	return out


func _state(game) -> Dictionary:
	var run = game.run
	return {
		"stage": run.stage, "world": run.world, "hp": run.hp, "max_hp": run.max_hp, "mass": run.mass,
		"cogs": run.cogs, "parts": Array(run.parts), "picks": Array(game.player.tree.picks),
		"spent": run.retries_spent.duplicate(), "pose": run.snapshot_value("entry_position"),
	}


func _disk() -> Dictionary:
	return RunStore.new(PATH).load()


func _kill(game) -> void:
	game.run.damage(9999.0, "test")


func _run() -> void:
	# (a) Game one: a tree pick and some growth, then stage 2's entrance.
	_game = _boot()
	await _frames(2)
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(5)
	var tree = _game.player.tree
	var offer: Array = tree.offered(tree.class_id, tree.picks.size() + 1)
	var picked: bool = tree.pending() and not offer.is_empty() and tree.pick(offer[0]["id"])
	_game.run.add_part("boost_coil", "test")
	_game.run.damage(12.0, "test")
	_game.run.mass += 40.0
	_game.run.add_cogs(7)
	_game.run.settled.append("resume_marker")
	var grown: float = _game.run.mass
	_game.flow.enter_stage(2, Vector3(0.0, 0.0, 14.0), false)
	var saved := _state(_game)
	_report("no retry is ever written", saved["spent"].is_empty() and _disk().get("retries_spent", {}).is_empty() and not _disk().get("death_save_spent", false),
		"spent %s, on disk %s, save flag on disk %s" % [saved["spent"], _disk().get("retries_spent"), _disk().get("death_save_spent")])
	# Play on past the entrance, then quit: none of this is saved.
	_game.run.add_scrap(50, Vector3.ZERO)
	_game.run.damage(20.0, "test")
	_game.free()

	var game_two = _boot()
	_game = game_two
	await _frames(2)
	var offered: bool = _game.flow.continue_ready
	var resumed: bool = _game.flow.resume_run()
	var back := _state(_game)
	var pose_gap: float = _game.player.ball_position().distance_to(saved["pose"])
	var same: bool = saved["mass"] > 0.0 and back["stage"] == 2 and back["world"] == 1 and is_equal_approx(back["hp"], saved["hp"]) \
		and is_equal_approx(back["max_hp"], saved["max_hp"]) and is_equal_approx(back["mass"], saved["mass"]) \
		and back["cogs"] == saved["cogs"] and back["parts"] == saved["parts"] and back["picks"] == saved["picks"]
	_report("resume at the entrance", offered and resumed and picked and same and pose_gap < POSE_TOLERANCE and _game.flow.state_name() == "stage",
		"continue offered %s, resumed %s: %s against saved %s (mass before entry %.0f), ball %.3f m from the entry" % [offered, resumed, back, saved, grown, pose_gap])
	_report("resume reconciles the settled ledger", _game.ctx.profile.is_settled("resume_marker") and _game.run.settled.has("resume_marker"),
		"run settled %s, profile settled %s" % [_game.run.settled, _game.ctx.profile.settled_ids()])
	_report("continue refunds nothing", back["spent"].is_empty() and _disk().get("retries_spent", {}).is_empty() and not _game.run.death_save_spent,
		"retries_spent after the continue %s, on disk %s, save spent %s" % [back["spent"], _disk().get("retries_spent"), _game.run.death_save_spent])

	# (b) + (d): a death in world one ends the run, and the store keeps a tombstone.
	var ended := [false, true]
	_game.events.run_ended.connect(func(won: bool):
		ended[0] = true
		ended[1] = won)
	_kill(_game)
	var raw := FileAccess.get_file_as_string(PATH)
	_report("a death ends the run", _game.flow.state_name() == "summary" and ended[0] and not ended[1],
		"flow %s, run_ended %s won %s" % [_game.flow.state_name(), ended[0], ended[1]])
	_report("run end leaves no run", _disk().is_empty() and raw.contains("\"ended\": true") and not raw.contains("\"run\""),
		"store loads %s; file %s" % [_disk(), raw.replace("\n", " ")])

	# A new run starts with no save spent, then stage 4 (world two) is entered and
	# the game crashes right after the entrance write.
	_game.flow.new_run()
	await _frames(2)
	_game.flow.enter_stage(4, Vector3(0.0, 0.0, 14.0), false)
	await _frames(2)
	var rolls_before := _rolls(_game)
	var run_id: String = _game.run.run_id
	_report("new run has no save spent", _game.run.retries_spent.is_empty() and not _game.run.death_save_spent and _game.flow.state_name() == "stage",
		"new run: spent %s, save spent %s, flow %s" % [_game.run.retries_spent, _game.run.death_save_spent, _game.flow.state_name()])
	_game.free()

	# (c) the replay after the crash rolls the same offers.
	var game_three = _boot()
	_game = game_three
	await _frames(2)
	var replayed: bool = _game.flow.resume_run()
	await _frames(2)
	var rolls_after := _rolls(_game)
	_report("crash replay offers", replayed and _game.run.stage == 4 and _game.run.run_id == run_id and rolls_after == rolls_before and not rolls_before.is_empty(),
		"stage %d run %s: offers %s, before the crash %s" % [_game.run.stage, _game.run.run_id, rolls_after, rolls_before])

	# (b) world two gives no retry either; its first death ends the run.
	_kill(_game)
	_report("world two death ends the run", _game.run.retries_spent.is_empty() and _game.flow.state_name() == "summary" and _disk().is_empty(),
		"world 2 first death: spent %s, flow %s" % [_game.run.retries_spent, _game.flow.state_name()])

	# (e) a save this build never owned survives a lost run's end byte for byte.
	_game.free()
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)
	var future := '{"schema": 9, "generation": 4, "run": {"x": 1}}'.to_utf8_buffer()
	var out := FileAccess.open(PATH, FileAccess.WRITE)
	out.store_buffer(future)
	out.close()
	_game = _boot()
	await _frames(2)
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _frames(5)
	_kill(_game)
	var kept := FileAccess.get_file_as_bytes(PATH)
	_report("newer-schema save survives a lost run", _game.flow.state_name() == "summary" and kept == future,
		"flow %s, file %s" % [_game.flow.state_name(), kept.get_string_from_utf8()])

	_game.free()
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)
	print("run_resume_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
