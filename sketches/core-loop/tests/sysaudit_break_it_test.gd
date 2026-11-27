extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const StageModifier := preload("res://src/world/events/stage_modifier.gd")
const T := preload("res://tests/support/t.gd")

const SPEED_CAP := 200.0
const ABYSS_Y := -400.0
const FAR_M := 6000.0
const LOW_HULL_FRAC := 0.15
const SPAM_TICKS := 90
const STACK_TICKS := 45
const PRESSES := [
	"jump_pressed", "shift_pressed", "mount_pressed", "interact_pressed",
	"fire_pressed", "harpoon_pressed", "harpoon_released", "cancel_pressed",
	"ultimate_pressed", "active_pressed", "slot_pick",
]
const HOLDS := ["jump_held", "shift_held", "brake_held", "fire_held", "harpoon_held", "mount_held"]

var _t := T.new("sysaudit_break_it_test")


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _make_game(tag: String, run_seed: int):
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	game.run_store_path = "user://sysaudit-break-it-%s-%d-%d.json" % [tag, OS.get_process_id(), run_seed]
	if FileAccess.file_exists(game.run_store_path):
		DirAccess.remove_absolute(game.run_store_path)
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.run.run_seed_override = run_seed
	game.flow.press_start()
	game.flow.choose_class(0)
	await _frames(12)
	return game


func _dispose_game(game, keep_store := false) -> void:
	var store_path := String(game.run_store_path)
	paused = false
	Engine.time_scale = 1.0
	game.free()
	if not keep_store and store_path != "" and FileAccess.file_exists(store_path):
		DirAccess.remove_absolute(store_path)


func _invariants_ok(game) -> String:
	var run = game.run
	var player = game.player
	var pos: Vector3 = player.ball_position()
	var vel: Vector3 = player.state.velocity
	if not (pos.is_finite() and vel.is_finite() and is_finite(run.hp) and is_finite(run.max_hp) and is_finite(run.mass)):
		return "nonfinite pos=%s vel=%s hp=%s max=%s mass=%s" % [pos, vel, run.hp, run.max_hp, run.mass]
	if vel.length() > SPEED_CAP:
		return "speed %.1f > %.1f" % [vel.length(), SPEED_CAP]
	if pos.y < ABYSS_Y or Vector2(pos.x, pos.z).length() > FAR_M:
		return "out of bounds %s" % pos
	if run.hp > run.max_hp + 0.01:
		return "hp %.2f > max_hp %.2f" % [run.hp, run.max_hp]
	if run.scrap < 0 or run.cogs < 0 or run.bonus_cores < 0:
		return "negative currency scrap=%d cogs=%d cores=%d" % [run.scrap, run.cogs, run.bonus_cores]
	return ""


func _run() -> void:
	await _test_input_spam()
	await _test_save_quit_resume()
	await _test_stacked_debuffs_low_hull()
	await _test_sequence_double_claim()
	quit(_t.verdict())


func _test_input_spam() -> void:
	var game = await _make_game("spam", 2881)
	var source := Intent.Scripted.new()
	game.player.source = source
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["sysaudit_spam", 2881])
	var fault := ""
	for tick in SPAM_TICKS:
		source.press = {}
		source.hold = {}
		for key in PRESSES:
			if rng.randf() < 0.3:
				source.press[key] = rng.randi_range(0, 2) if key == "slot_pick" else true
		for key in HOLDS:
			if rng.randf() < 0.35:
				source.hold[key] = true
		source.hold["move"] = Vector2.from_angle(rng.randf() * TAU)
		if tick % 19 == 0:
			game.toggle_pause()
		await physics_frame
		if game.pause_toggled():
			game.toggle_pause()
		var check := _invariants_ok(game)
		if check != "" and fault == "":
			fault = check
	_t.eq("rapid input spam produces zero NaN, OOB, speed or currency faults", fault, "")
	_t.check("rapid pause spam leaves game unpaused and responsive", not game.pause_toggled() and not paused)
	_dispose_game(game)


func _test_save_quit_resume() -> void:
	var game = await _make_game("resume", 2882)
	game.run.add_cogs(120)
	game.run.add_part("heavy_bearings", "sysaudit")
	game.run.death_save_spent = true
	game.run.hp = maxf(10.0, game.run.max_hp * 0.55)
	game.flow._save_cleared(Vector3.ZERO)
	var saved: Dictionary = game.flow.saved_run()
	_t.check("cleared-stage save produces a non-empty checkpoint", not saved.is_empty())
	var want_next_stage := int(game.run.stage) + 1
	var want_cogs := int(game.run.cogs)
	var want_parts: int = game.run.parts.size()
	var store_path := String(game.run_store_path)
	_dispose_game(game, true)

	var resumed := Game.new()
	resumed.test_mode = true
	resumed.table = "park"
	resumed.run_store_path = store_path
	root.add_child(resumed)
	while resumed.flow == null:
		await physics_frame
	var continued: bool = resumed.flow.resume_run()
	await _frames(10)
	_t.check("Continue resumes cleared-stage save cleanly", continued)
	_t.eq("Continue advances to next stage without replaying cleared stage", int(resumed.run.stage), want_next_stage)
	_t.eq("Continue preserves cogs with zero loss or duplication", int(resumed.run.cogs), want_cogs)
	_t.eq("Continue preserves parts with zero loss or duplication", resumed.run.parts.size(), want_parts)
	_t.check("Continue never refills a spent death save", resumed.run.death_save_spent)
	_t.eq("Continue state passes all runtime invariants", _invariants_ok(resumed), "")
	resumed.run.damage(1.0e6, "sysaudit_death")
	await _frames(10)
	_t.check("death clears saved run so Continue cannot resurrect a dead run", resumed.flow.saved_run().is_empty())
	_dispose_game(resumed)


func _test_stacked_debuffs_low_hull() -> void:
	var game = await _make_game("stack", 2883)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["sysaudit_stack", 2883])
	var class_id := String(game.run.class_id())
	var parts: Array = []
	for i in 10:
		var picks: Array = Parts.roll(rng, Parts.SOURCE_RARITIES["fabricator"], class_id, parts, 1)
		if not picks.is_empty():
			var pid := String(picks[0])
			parts.append(pid)
			game.run.add_part(pid, "sysaudit_stack")
	game.run.trade_memory.seen.append({"curse": true, "stage": 1})
	game.run.trade_memory.decisions["1"] = true
	game.run.trade_memory.risk_taken = true
	game.build.recompute()
	game.run.hp = game.run.max_hp * LOW_HULL_FRAC
	var modifier: Dictionary = StageModifier.for_stage(game.run, game.ctx.terrain, 1)
	var fault := ""
	for i in STACK_TICKS:
		await physics_frame
		var check := _invariants_ok(game)
		if check != "" and fault == "":
			fault = check
	_t.check("stacked curse, parts, modifier and low hull activate cleanly", game.run.cursed() and parts.size() >= 6 and modifier is Dictionary)
	_t.eq("stacked curse + parts + modifier + low hull hold all invariants", fault, "")
	game.run.damage(1.0e6, "sysaudit_fatal")
	await _frames(8)
	_t.check("stacked build is never unkillable under fatal damage", not game.run.alive())
	_dispose_game(game)


func _test_sequence_double_claim() -> void:
	var game = await _make_game("seq", 2884)
	var parts_before: int = game.run.parts.size()
	game.flow._unseal()
	await _frames(6)
	var gates = game.build.gates if game.build != null else null
	_t.check("unseal opens reward gates cleanly", gates != null and gates.is_open())
	if gates != null and gates.is_open():
		var offer: Dictionary = gates.offers[0]
		var at: Vector3 = offer["at"]
		var facing: Vector3 = offer["facing"]
		gates.step(at - facing * 2.0, facing)
		gates.step(at + facing * 2.0, facing)
		gates.step(at - facing * 2.0, facing)
		gates.step(at + facing * 2.0, facing)
		await _frames(4)
		_t.check("reward gates close immediately on first claim", not gates.is_open())
	_t.eq("repeated gate crossings never duplicate a reward", game.run.parts.size() - parts_before, 1)
	var pause_menu = game.get_node_or_null("PauseMenu")
	if pause_menu != null:
		for i in 5:
			pause_menu.open()
			pause_menu.close()
		_t.check("rapid pause open/close never softlocks pause state", not pause_menu.is_open() and not paused)
	_t.eq("sequence-break test passes all runtime invariants", _invariants_ok(game), "")
	_dispose_game(game)
