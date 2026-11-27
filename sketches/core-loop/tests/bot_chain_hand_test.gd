# smoke: bots timeout=1200s (four isolated seeded bot children at a time; 352.6 s alone on 2026-10-12 and about 425 s in the w17 cloud gate on 2026-10-18, over the 360 s solo ceiling; moved to the bot tier)
# 2026-10-12, W13 smoke triage: 352.550 s alone; 1.5x exceeds the ordinary ceiling, so cap at 360 s. The fixed 5/16 band still fails at 4/16.
# 2026-10-13 RED-COMBAT regression: Sable's Bank Shot removes the old
# planned-bite reel (9000ca2, PC-SABLE brief-r4.md:3-7). A jump must clear
# the floor probe before the first bite, so hit-stop cannot end that chain.
extends SceneTree

const Game := preload("res://src/game.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const Augments := preload("res://src/movement/augments.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Flow := preload("res://src/core/flow.gd")

# Rule: the explorer re-bites a different enemy during airborne grace and pays a
# two-link chain; the seed repeats and the skipper/camper records are the same with the
# two-hook hand on and off (an in-tree control, so sibling changes to the record do not
# read as the hand leaking into other policies).
# Children use bot_run.gd's Game.new(), test_mode and ordinary scripted input.
# Only physics frames bound play; this test does not read a wall clock.
# A separate hand case stages the grounded start, apex and reticle, then sends the
# driver's inputs through the real player's grammar. It proves the new second press
# rather than treating combos that the ordinary hand already makes as its evidence.
const TICKS := 5400
const EXPLORER_TICKS := 2700
# 2026-10-04 B2: measured 5/16 in 2700 frames; lower band authorized by the unit.
# Report separates no-bite seeds from
# one-link chains that touch ground before another anchor can be locked.
const MIN_CHAIN_SEEDS := 5
const PARALLEL := 4

var _pending: Array[Dictionary] = []
var _active: Array[Dictionary] = []
var _records := {}
var _bots := {}
var _failures := 0
var _folder := ""
var _finished := false
var _hand_game


func _initialize() -> void:
	_folder = ProjectSettings.globalize_path("res://../../artifacts/local/sol/chain-hand")
	var suffix := 0
	while DirAccess.dir_exists_absolute(_folder + "-%d" % suffix):
		suffix += 1
	_folder += "-%d" % suffix
	DirAccess.make_dir_recursive_absolute(_folder)
	for number in range(1, 17):
		_pending.append({"id": "explorer-%d" % number, "policy": "completionist", "seed": number})
	_pending.append({"id": "repeat", "policy": "completionist", "seed": 2})
	for policy in ["skipper", "camper"]:
		for hand in ["0", "1"]:
			_pending.append({"id": "%s-hand-%s" % [policy, hand], "policy": policy, "seed": 1, "chain_hand": hand})
	_hand_game = Game.new()
	_hand_game.test_mode = true
	_hand_game.table = "slice"
	root.add_child(_hand_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _launch() -> void:
	while _active.size() < PARALLEL and not _pending.is_empty():
		var trial: Dictionary = _pending.pop_front()
		trial["ticks"] = EXPLORER_TICKS if trial["policy"] == "completionist" else TICKS
		var folder: String = _folder.path_join(trial["id"])
		ChildRuns.ensure_home_dirs(folder)
		var args: Array = ChildRuns.home_env(folder) + [OS.get_executable_path(), "--headless", "--quiet", "--fixed-fps", "90", "--path",
			ProjectSettings.globalize_path("res://"), "--log-file", folder.path_join("engine.log"),
			"--script", "res://tools/bot_run.gd", "--",
			"--out=" + folder, "--policy=" + trial["policy"], "--seeds=%d" % trial["seed"],
			"--table=slice", "--ticks=%d" % trial["ticks"], "--chain-hand=" + String(trial.get("chain_hand", "1"))]
		trial["pid"] = OS.create_process("env", PackedStringArray(args))
		trial["folder"] = folder
		_active.append(trial)


func _physics_process(_delta: float) -> bool:
	if _finished:
		return true
	if _hand_game != null:
		if _hand_game.flow == null:
			return false
		_check_hand()
		_hand_game.free()
		_hand_game = null
		Engine.time_scale = 1.0
		if OS.get_cmdline_user_args().has("--hand-only"):
			_finish()
			return true
		_launch()
		return false
	for index in range(_active.size() - 1, -1, -1):
		var trial: Dictionary = _active[index]
		if OS.is_process_running(trial["pid"]):
			continue
		var rows := _read_rows(trial["folder"].path_join("runs.ndjson"))
		var bots := _read_rows(trial["folder"].path_join("bots.ndjson"))
		var log := FileAccess.get_file_as_string(trial["folder"].path_join("engine.log"))
		var code := OS.get_process_exit_code(trial["pid"])
		var complete: bool = not rows.is_empty() and bots.size() == 1 and int(bots[0].get("ticks", 0)) > 0 \
			and int(bots[0].get("ticks", 0)) <= trial["ticks"] and code == 0 and not "SCRIPT ERROR:" in log and not "ERROR:" in log
		_report(trial["id"] + " completed", complete, "exit %d, %d logged records, %d bot records" % [code, rows.size(), bots.size()])
		_records[trial["id"]] = rows
		_bots[trial["id"]] = bots.back() if not bots.is_empty() else {}
		_active.remove_at(index)
	_launch()
	if not _active.is_empty() or not _pending.is_empty():
		return false
	_finished = true
	_check()
	_finish()
	return true


func _finish() -> void:
	print("bot_chain_hand_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _check_hand() -> void:
	_hand_game.ctx.calm = true
	var driver := BotDriver.new(_hand_game, "completionist", 0)
	driver.start()
	var player = _hand_game.player
	var first := StaticBody3D.new()
	var second := StaticBody3D.new()
	for anchor in [first, second]:
		anchor.collision_layer = Augments.ENEMY_MASK
		anchor.add_to_group("enemy")
		root.add_child(anchor)
	first.global_position = player.ball_position() + Vector3(0.0, 0.0, -20.0)
	second.global_position = player.ball_position() + Vector3(12.0, 0.0, -22.0)
	player.state.grounded = true
	player.kit.aim = {"body": first, "point": first.global_position, "normal": Vector3.UP, "state": Augments.AIM_BODY}
	driver._off_line = 99.0
	driver._harpoon_hand(first, 1.0 / 90.0)
	driver._act(player.ball_position(), first, 1.0 / 90.0)
	_report("hand first jump", driver._chain_phase == "takeoff" and driver._chain_second == second
		and driver.source.press.get("jump_pressed", false)
		and not driver.source.press.get("harpoon_pressed", false), "two anchors arm the jump before any bite")
	driver.source.poll(player.intent)
	player._read_grammar()
	_report("hand grounded clearance", not player.kit.hooked and not player.chain.active(),
		"a launch still in the floor probe cannot start a chain")
	player.state.grounded = false
	player.body().linear_velocity = Vector3.UP * 10.0
	driver._explorer_chain(1.0 / 90.0)
	driver.source.poll(player.intent)
	player._read_grammar()
	_report("hand rising clearance", not player.kit.hooked and not player.chain.active(),
		"the jump's first airborne flag still waits for visible height")
	_report("hand takeoff counts no bite", int(driver._note.get("harpoon_bites", 0)) == 0,
		"a jump without a harpoon press records zero bites")
	# Stage the observed clearance, independently of the pending jump impulse.
	player.state.grounded = false
	player.body().global_position += Vector3.UP * Tuning.RADIUS * 2.0
	player.body().linear_velocity = Vector3.UP * 10.0
	player.kit.aim = {"body": first, "point": first.global_position, "normal": Vector3.UP, "state": Augments.AIM_BODY}
	driver._explorer_chain(1.0 / 90.0)
	driver.source.poll(player.intent)
	player._read_grammar()
	_report("hand anchor A", player.kit.hooked and player.kit.anchor_body == first, "first input bites A")
	_report("hand first bite counted once", int(driver._note.get("harpoon_bites", 0)) == 1,
		"the first airborne harpoon press records one bite")
	# Staged apex and reticle isolate the hand from terrain, camera and jump physics.
	player.state.grounded = false
	player.body().linear_velocity = Vector3.ZERO
	driver._chain_rose = true
	driver._explorer_chain(1.0 / 90.0)
	driver.source.poll(player.intent)
	player._read_grammar()
	player._publish_end()
	_report("hand apex release", not player.kit.hooked and player.chain.grace_left > 0.0,
		"the apex sends an explicit release and starts grace")
	player.kit.aim = {"body": second, "point": second.global_position, "normal": Vector3.UP, "state": Augments.AIM_BODY}
	driver._explorer_chain(1.0 / 90.0)
	driver.source.poll(player.intent)
	player._read_grammar()
	_report("hand two-hook combo", player.chain.combo == 2 and player.kit.anchor_body == second,
		"the second input bites B inside grace and raises combo to 2")
	driver._explorer_chain(1.0 / 90.0)
	driver.source.poll(player.intent)
	player._read_grammar()
	_report("hand smash", player.kit.line_state == Augments.LINE_SMASH, "Ctrl commits the second anchor's smash")
	# A committed Warden fight finishes its body line instead of detouring to an add.
	driver._clear_chain_hand()
	driver.source.press.clear()
	driver.source.hold.clear()
	driver._cast_phase = ""
	driver._off_line = 99.0
	player.kit.drop_line("reset")
	player.kit.rewind_left = 0.0
	player.chain.reset()
	player.state.grounded = true
	player._brake_was_held = false
	player.abilities.refill()
	player.abilities.snap_back("test")
	player.kit.aim = {"body": first, "point": first.global_position, "normal": Vector3.UP, "state": Augments.AIM_BODY}
	var warden_before = _hand_game.flow.warden
	_hand_game.flow.warden = first
	driver._harpoon_hand(first, 1.0 / 90.0)
	_report("Warden hand stays on its finisher", driver._chain_phase == ""
		and driver.source.press.get("harpoon_pressed", false)
		and not driver.source.press.get("jump_pressed", false), "the Warden bite stays ordinary, with no two-hook detour")
	_hand_game.flow.warden = warden_before
	driver._clear_chain_hand()
	driver.source.press.clear()
	driver.source.hold.clear()
	driver._harpoon_commit = true
	driver.source.press["jump_pressed"] = true
	driver.source.press["shift_pressed"] = true
	driver._drive(player.ball_position(), first, 1.0 / 90.0)
	_report("ordinary haul keeps its committed inputs", driver.source.hold.get("brake_held", false)
		and not driver.source.press.get("jump_pressed", false)
		and not driver.source.press.get("shift_pressed", false)
		and not driver.source.hold.get("shift_held", false), "outside an active two-hook hand, jump and boost cannot cancel the haul")
	driver._clear_chain_hand()
	driver.source.press.clear()
	driver.source.hold.clear()
	driver._cast_phase = ""
	var state_before: int = _hand_game.flow.state
	_hand_game.flow.state = Flow.BOSS
	driver.boss_note = {"fixture": true}
	driver._harpoon_hand(first, 1.0 / 90.0)
	_report("boss hand stays on its finisher", driver._chain_phase == ""
		and driver.source.press.get("harpoon_pressed", false)
		and not driver.source.press.get("jump_pressed", false), "the boss keeps the ordinary bite, as the drive's boss guard requires")
	_hand_game.flow.state = state_before
	driver.boss_note.clear()
	first.free()
	second.free()


func _read_rows(path: String) -> Array:
	var rows := []
	if FileAccess.file_exists(path):
		for line in FileAccess.get_file_as_string(path).split("\n", false):
			var row = JSON.parse_string(line)
			if row is Dictionary:
				rows.append(row)
	return rows


func _last(id: String) -> Dictionary:
	var rows: Array = _records.get(id, [])
	return rows.back() if not rows.is_empty() else {}


func _check() -> void:
	var chained := 0
	var paid := 0
	var released := 0
	for number in range(1, 17):
		var row := _last("explorer-%d" % number)
		var combo := int(row.get("best_combo", 0))
		var lets_go := 0
		for stage in _bots["explorer-%d" % number].get("stages", []):
			lets_go += int(stage.get("chain_releases", 0))
		if lets_go > 0:
			released += 1
		if combo >= 2:
			chained += 1
		for chain in row.get("chains", []):
			if chain["combo"] >= 2 and chain["paid"]:
				paid += 1
				break
		print("seed %d: best_combo=%d chains=%d misses=%d releases=%d" % [number, combo,
			row.get("chains", []).size(), int(row.get("misses", -1)), lets_go])
	_report("two-hook combo", chained >= MIN_CHAIN_SEEDS, "%d/16 seeds reach combo 2, require %d" % [chained, MIN_CHAIN_SEEDS])
	_report("two-hook smash", paid > 0, "%d/16 seeds log a paid two-link chain" % paid)
	_report("apex release", released > 0, "%d/16 seeds observe the hand's let_go event" % released)
	var first := _last("explorer-2")
	var repeat := _last("repeat")
	_report("seed repeats", not first.is_empty() and not repeat.is_empty()
		and first["best_combo"] == repeat["best_combo"]
		and first["chains"].size() == repeat["chains"].size() and first["misses"] == repeat["misses"],
		"seed 2 repeats best_combo, chains.size and misses")
	for policy in ["skipper", "camper"]:
		var off: Array = _records.get(policy + "-hand-0", [])
		var on: Array = _records.get(policy + "-hand-1", [])
		_report(policy + " hand control", not off.is_empty() and JSON.stringify(_stable(off)) == JSON.stringify(_stable(on)),
			"all gameplay fields and seeded id match with the two-hook hand off and on, seed 1, %d frames" % TICKS)


# RunState names a run with wall seconds plus a seeded suffix. Only that clock prefix
# is identity rather than behavior; every other field and every logged record is pinned.
func _stable(rows: Array) -> Array:
	var stable := rows.duplicate(true)
	for row in stable:
		row["run_id"] = "clock-" + String(row["run_id"]).get_slice("-", 1)
	return stable
