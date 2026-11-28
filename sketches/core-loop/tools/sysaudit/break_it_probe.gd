extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const StageModifier := preload("res://src/world/events/stage_modifier.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

const SPEED_CAP := 200.0
const ABYSS_Y := -400.0
const FAR_M := 6000.0
const LOW_HULL_FRAC := 0.15
const SPAM_TICKS := 180
const STACK_TICKS := 90
const PRESSES := [
	"jump_pressed", "shift_pressed", "mount_pressed", "interact_pressed",
	"fire_pressed", "harpoon_pressed", "harpoon_released", "cancel_pressed",
	"ultimate_pressed", "active_pressed", "slot_pick",
]
const HOLDS := ["jump_held", "shift_held", "brake_held", "fire_held", "harpoon_held", "mount_held"]

var _settings := {}
var _findings: Array = []
var _summary := {}


func _initialize() -> void:
	SimClock.ticks = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_settings["seed"] = arg.substr(7)
		elif arg.begins_with("--suite="):
			_settings["suite"] = arg.substr(8)
		elif arg.begins_with("--out="):
			_settings["out"] = arg.substr(6)
	_run.call_deferred()


func _new_game(tag: String, run_seed: int):
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	game.run_store_path = "user://break-it-probe-%s-%d-%d.json" % [tag, OS.get_process_id(), run_seed]
	if FileAccess.file_exists(game.run_store_path):
		DirAccess.remove_absolute(game.run_store_path)
	root.add_child(game)
	return game


func _cleanup_game(game, keep_store := false) -> void:
	var store_path := String(game.run_store_path)
	paused = false
	Engine.time_scale = 1.0
	game.free()
	if not keep_store and store_path != "" and FileAccess.file_exists(store_path):
		DirAccess.remove_absolute(store_path)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _note(suite: String, kind: String, detail: String) -> void:
	_findings.append({"suite": suite, "kind": kind, "detail": detail})


func _check_invariants(suite: String, game) -> void:
	var run = game.run
	var player = game.player
	var pos: Vector3 = player.ball_position()
	var vel: Vector3 = player.state.velocity
	if not (pos.is_finite() and vel.is_finite() and is_finite(run.hp) and is_finite(run.max_hp) and is_finite(run.mass)):
		_note(suite, "nonfinite", "pos=%s vel=%s hp=%s max_hp=%s mass=%s" % [pos, vel, run.hp, run.max_hp, run.mass])
		return
	if vel.length() > SPEED_CAP:
		_note(suite, "speed_cap", "speed=%.1f" % vel.length())
	if pos.y < ABYSS_Y or Vector2(pos.x, pos.z).length() > FAR_M:
		_note(suite, "out_of_bounds", "pos=%s" % pos)
	if run.hp > run.max_hp + 0.01:
		_note(suite, "hull_over", "hp=%.2f max=%.2f" % [run.hp, run.max_hp])
	if run.scrap < 0 or run.cogs < 0 or run.bonus_cores < 0:
		_note(suite, "negative_currency", "scrap=%d cogs=%d cores=%d" % [run.scrap, run.cogs, run.bonus_cores])


func _run() -> void:
	var run_seed := int(_settings.get("seed", "2881"))
	var suite := String(_settings.get("suite", "all"))
	if suite in ["all", "spam"]:
		await _suite_spam(run_seed)
	if suite in ["all", "save_resume"]:
		await _suite_save_resume(run_seed)
	if suite in ["all", "stack"]:
		await _suite_stack(run_seed)
	if suite in ["all", "sequence"]:
		await _suite_sequence(run_seed)
	var report := {
		"tool": "break_it_probe",
		"seed": run_seed,
		"suite": suite,
		"findings_count": _findings.size(),
		"findings": _findings,
		"suites": _summary,
		"pass": _findings.is_empty(),
	}
	var out_path := String(_settings.get("out", ""))
	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "  "))
			file.close()
	print("break_it_probe: seed=%d suite=%s findings=%d pass=%s" % [run_seed, suite, _findings.size(), str(_findings.is_empty())])
	SimClock.ticks = false
	quit(0 if _findings.is_empty() else 1)


func _suite_spam(run_seed: int) -> void:
	var game = _new_game("spam", run_seed)
	while game.flow == null:
		await physics_frame
	game.run.run_seed_override = run_seed
	game.flow.press_start()
	game.flow.choose_class(0)
	await _frames(15)
	var source := Intent.Scripted.new()
	game.player.source = source
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["break_spam", run_seed])
	var pause_toggles := 0
	var peak_speed := 0.0
	for tick in SPAM_TICKS:
		source.press = {}
		source.hold = {}
		for key in PRESSES:
			if rng.randf() < 0.25:
				source.press[key] = rng.randi_range(0, 2) if key == "slot_pick" else true
		for key in HOLDS:
			if rng.randf() < 0.35:
				source.hold[key] = true
		source.hold["move"] = Vector2.from_angle(rng.randf() * TAU)
		if tick % 23 == 0:
			game.toggle_pause()
			pause_toggles += 1
		await physics_frame
		if game.pause_toggled():
			game.toggle_pause()
		_check_invariants("spam", game)
		peak_speed = maxf(peak_speed, game.player.state.velocity.length())
	if game.pause_toggled() or paused:
		_note("spam", "stuck_pause", "paused after unpause")
	_summary["spam"] = {"ticks": SPAM_TICKS, "pause_toggles": pause_toggles, "peak_speed": snappedf(peak_speed, 0.1), "state": game.flow.state_name()}
	_cleanup_game(game)


func _suite_save_resume(run_seed: int) -> void:
	var game = _new_game("resume", run_seed)
	while game.flow == null:
		await physics_frame
	game.run.run_seed_override = run_seed
	game.flow.press_start()
	game.flow.choose_class(0)
	await _frames(15)
	game.run.add_cogs(135)
	game.run.add_part("heavy_bearings", "probe")
	game.run.death_save_spent = true
	game.run.hp = maxf(10.0, game.run.max_hp * 0.5)
	game.flow._save_cleared(Vector3.ZERO)
	var saved: Dictionary = game.flow.saved_run()
	if saved.is_empty():
		_note("save_resume", "no_save", "saved_run empty after cleared-stage save")
	var before := {
		"stage": int(game.run.stage),
		"cogs": int(game.run.cogs),
		"parts": game.run.parts.size(),
		"death_save_spent": bool(game.run.death_save_spent),
		"hp": snappedf(float(game.run.hp), 0.1),
	}
	var store_path := String(game.run_store_path)
	_cleanup_game(game, true)

	var resumed = Game.new()
	resumed.test_mode = true
	resumed.table = "park"
	resumed.run_store_path = store_path
	root.add_child(resumed)
	while resumed.flow == null:
		await physics_frame
	var ok: bool = resumed.flow.resume_run()
	await _frames(10)
	if not ok:
		_note("save_resume", "continue_failed", "resume_run returned false")
	else:
		if int(resumed.run.stage) != before["stage"] + 1:
			_note("save_resume", "stage_drift", "want=%d got=%d" % [before["stage"] + 1, resumed.run.stage])
		if int(resumed.run.cogs) != before["cogs"]:
			_note("save_resume", "cogs_drift", "want=%d got=%d" % [before["cogs"], resumed.run.cogs])
		if resumed.run.parts.size() != before["parts"]:
			_note("save_resume", "parts_drift", "want=%d got=%d" % [before["parts"], resumed.run.parts.size()])
		if not resumed.run.death_save_spent:
			_note("save_resume", "death_save_refilled", "death_save_spent reset on Continue")
		_check_invariants("save_resume", resumed)
		resumed.run.damage(1.0e6, "probe")
		await _frames(8)
		if not resumed.flow.saved_run().is_empty():
			_note("save_resume", "resurrect_offered", "saved_run persisted after player death")
	_summary["save_resume"] = {"continued": ok, "before": before, "terminal_cleared": resumed.flow.saved_run().is_empty()}
	_cleanup_game(resumed)


func _suite_stack(run_seed: int) -> void:
	var game = _new_game("stack", run_seed)
	while game.flow == null:
		await physics_frame
	game.run.run_seed_override = run_seed
	game.flow.press_start()
	game.flow.choose_class(0)
	await _frames(15)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["break_stack", run_seed])
	var class_id := String(game.run.class_id())
	var parts: Array = []
	for i in 12:
		var picks: Array = Parts.roll(rng, PartOffers.SOURCE_RARITIES["fabricator"], class_id, parts, 1)
		if not picks.is_empty():
			var pid := String(picks[0])
			parts.append(pid)
			game.run.add_part(pid, "stack_probe")
	game.run.trade_memory.seen.append({"curse": true, "stage": 1})
	game.run.trade_memory.decisions["1"] = true
	game.run.trade_memory.risk_taken = true
	game.build.recompute()
	game.run.hp = game.run.max_hp * LOW_HULL_FRAC
	var modifier: Dictionary = StageModifier.for_stage(game.run, game.ctx.terrain, 1)
	for i in STACK_TICKS:
		await physics_frame
		_check_invariants("stack", game)
	var fatal_ok := true
	game.run.damage(1.0e6, "stack_probe")
	await _frames(10)
	if game.run.alive():
		fatal_ok = false
		_note("stack", "unkillable", "survived fatal hit under stacked debuffs")
	_summary["stack"] = {
		"parts_stacked": parts.size(),
		"cursed": game.run.cursed(),
		"modifier": String(modifier.get("id", "none")),
		"fatal_ok": fatal_ok,
	}
	_cleanup_game(game)


func _suite_sequence(run_seed: int) -> void:
	var game = _new_game("sequence", run_seed)
	while game.flow == null:
		await physics_frame
	game.run.run_seed_override = run_seed
	game.flow.press_start()
	game.flow.choose_class(0)
	await _frames(15)
	var parts_before: int = game.run.parts.size()
	var cogs_before: int = game.run.cogs
	game.flow._unseal()
	await _frames(6)
	var gates = game.build.gates if game.build != null else null
	if gates == null or not gates.is_open():
		_note("sequence", "gates_not_open", "unseal did not open reward gates")
	else:
		var offer: Dictionary = gates.offers[0]
		var at: Vector3 = offer["at"]
		var facing: Vector3 = offer["facing"]
		gates.step(at - facing * 2.0, facing)
		gates.step(at + facing * 2.0, facing)
		gates.step(at - facing * 2.0, facing)
		gates.step(at + facing * 2.0, facing)
		await _frames(5)
		if gates.is_open():
			_note("sequence", "gates_stayed_open", "reward gates stayed open after first claim")
	var gained: int = game.run.parts.size() - parts_before
	if gained != 1:
		_note("sequence", "double_gate_claim", "gained %d parts from one gate choice" % gained)
	var pause_menu = game.get_node_or_null("PauseMenu")
	if pause_menu != null:
		for i in 5:
			pause_menu.open()
			pause_menu.close()
		if pause_menu.is_open() or paused:
			_note("sequence", "pause_softlock", "pause stuck after rapid open/close")
	_check_invariants("sequence", game)
	_summary["sequence"] = {"gate_parts_gained": gained, "cogs_delta": game.run.cogs - cogs_before}
	_cleanup_game(game)
