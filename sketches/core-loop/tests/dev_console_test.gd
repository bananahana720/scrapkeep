extends SceneTree

const Game := preload("res://src/game.gd")
const SafeStore := preload("res://src/core/safe_store.gd")
const DevConsole := preload("res://src/dev/dev_console.gd")
const DevLook := preload("res://src/dev/dev_look.gd")
const DevLens := preload("res://src/dev/dev_lens.gd")
const DevInspect := preload("res://src/dev/dev_inspect.gd")
const DevSession := preload("res://src/dev/dev_session.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("dev_console_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true

	DevConsole.hook(game)
	_t.eq("the hook mounts nothing in a test or a plain launch", game.get_node_or_null("DevConsole"), null)
	game.dev = true
	DevConsole.hook(game)
	_t.eq("the hook still mounts nothing in test_mode even with dev=true", game.get_node_or_null("DevConsole"), null)

	var console := DevConsole.new()
	game.add_child(console)
	console.setup(game)
	var look: DevLook = console.look

	_t.check("every command has usage and help", console.commands.names().all(func(n: String): return console.commands.help(n) != ""), "")
	_t.check("an unknown command answers with a warning", console.commands.run_one("spwan chaser").begins_with("!"), "")
	_t.check("spawn before a run is refused, not crashed", console.commands.run_one("spawn chaser").begins_with("!"), "")

	game.flow.press_start()
	game.flow.choose_class(0)
	await process_frame
	await process_frame

	var env: Environment = look.environment()
	_t.check("the world environment is reachable", env != null, "")
	console.run("set dots 0.5")
	_t.check("a paint key on a fresh console leaves the print pass off", not look.passes_live()[DevLook.PRINT], str(look.passes_live()))
	console.run("reset dots")
	_t.check("resetting the only paint key turns the paint pass off", not look.passes_live()[DevLook.PAINT], str(look.passes_live()))

	var adjust_rest := env.adjustment_enabled
	console.run("set saturation 1.5")
	console.run("set contrast 1.3")
	await process_frame
	console.run("reset saturation")
	await process_frame
	console.run("reset contrast")
	_t.eq("two keys that share an enable flag hand it back once both reset", env.adjustment_enabled, adjust_rest)

	var shipped_exposure := env.tonemap_exposure
	console.run("set exposure 1.73")
	await process_frame
	_t.near("set exposure writes the live environment", env.tonemap_exposure, 1.73, 0.001)
	_t.check("the overridden key reads as touched", look.touched("exposure"), "")
	console.run("reset exposure")
	_t.near("reset hands the game's value back", env.tonemap_exposure, shipped_exposure, 0.001)

	for id in DevLook.PRESETS:
		var reply: String = console.commands.run_one("look %s" % id)
		_t.check("preset '%s' applies" % id, not reply.begins_with("!"), reply)
	console.run("look graphic press")
	var live: Dictionary = look.passes_live()
	_t.check("graphic press turns the paint pass on (3D under telegraphs)", live[DevLook.PAINT], str(live))
	_t.check("graphic press turns the print pass on (whole frame)", live[DevLook.PRINT], str(live))
	console.run("look shipped")
	live = look.passes_live()
	_t.check("shipped turns both passes off", not live[DevLook.PAINT] and not live[DevLook.PRINT], str(live))
	console.run("set dots 0.5")
	live = look.passes_live()
	_t.check("a paint key alone wakes only the paint pass", live[DevLook.PAINT] and not live[DevLook.PRINT], str(live))
	console.run("reset all")

	var keys: Array = look.keys()
	var seen := {}
	for key in keys:
		_t.check("look key '%s' has one home" % key, not seen.has(key), "")
		seen[key] = true

	var shipped_cam: Camera3D = game.get_viewport().get_camera_3d()
	for id in DevLens.MODES:
		var reply: String = console.commands.run_one("cam %s" % id)
		_t.check("camera '%s' switches" % id, not reply.begins_with("!"), reply)
		await process_frame
		if id != "game":
			_t.check("camera '%s' takes the view" % id, game.get_viewport().get_camera_3d() == console.lens.get_node("DevCamera"), "")
	console.run("cam game")
	_t.eq("cam game gives the view back to the chase camera", game.get_viewport().get_camera_3d(), shipped_cam)
	console.run("cam fov 40")
	_t.near("a knob set from the chase camera keeps its value", console.lens.fov, 40.0)
	_t.eq("a knob set from the chase camera takes the view", console.lens.mode, "orbit")
	console.run("cam game")
	console.run("cam iso")
	await process_frame
	_t.eq("iso is orthographic", console.lens.get_node("DevCamera").projection, Camera3D.PROJECTION_ORTHOGONAL)
	console.run("cam game")

	var before: int = console.fight.living().size()
	_t.check("spawn chaser 3 answers", not console.commands.run_one("spawn chaser 3").begins_with("!"), "")
	await process_frame
	_t.eq("three chasers join the fight", console.fight.living().size(), before + 3)
	_t.check("an enemy prefix resolves when unique", not console.commands.run_one("spawn lobb").begins_with("!"), "")
	await process_frame
	console.run("clear")
	await process_frame
	await process_frame
	_t.eq("clear leaves no ordinary enemy standing", console.fight.living().size(), 0)
	_t.check("the world 1 kind list is not empty and holds the chaser", "chaser" in console.fight.kinds(1), "")

	var prior_hook: Callable = game.run.defend_hook
	console.run("god on")
	_t.eq("god on leaves defend_hook untouched", game.run.defend_hook, prior_hook)
	var hp: float = game.run.hp
	game.run.damage(25.0, "dev_console_test")
	_t.near("god mode takes no hull", game.run.hp, hp)
	console.run("god off")
	_t.eq("god off hands back the defend hook it replaced", game.run.defend_hook, prior_hook)
	game.run.damage(5.0, "dev_console_test")
	_t.check("god off lets hits land again", game.run.hp < hp, "%s < %s" % [game.run.hp, hp])

	console.run("time 0.25")
	_t.near("time scale applies", Engine.time_scale, 0.25)
	console.run("time 1")
	_t.near("time scale resets", Engine.time_scale, 1.0)
	game.toggle_pause()
	console.run("time 0")
	game.toggle_pause()
	_t.check("closing the pause menu during a freeze keeps the world frozen", paused, "")
	console.run("time 1")
	_t.check("unfreezing after the pause menu closed runs the world again", not paused, "")
	console.run("time 0")
	game.toggle_pause()
	console.run("time 1")
	_t.check("unfreezing under an open pause menu keeps the game paused", paused, "")
	game.toggle_pause()
	_t.check("closing that pause menu runs the world again", not paused, "")

	console.run("look riso zine")
	console.run("set exposure 1.4")
	var id := "dev-console-test-%d" % OS.get_process_id()
	var baked: String = console.commands.run_one("bake %s" % id)
	_t.check("bake saves a look file", not baked.begins_with("!"), baked)
	console.run("reset all")
	var loaded: String = console.commands.run_one("load %s" % id)
	_t.check("load reads the baked look back", not loaded.begins_with("!"), loaded)
	_t.near("the baked print value survives the round trip", look.value("riso"), float(DevLook.PRESETS["riso zine"].filter.riso), 0.001)
	_t.near("the baked light value survives the round trip", look.value("exposure"), 1.4, 0.001)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DevLook.LOOK_DIR.path_join(id + ".json")))
	console.run("look blueprint")
	console.commands.run_one("bake %s" % id)
	console.run("reset all")
	_t.check("reset all clears the blueprint tint", not look.passes_live()[DevLook.PRINT], str(look.passes_live()))
	console.commands.run_one("load %s" % id)
	_t.check("the blueprint tint survives a bake and load", look.snapshot().has("tint") and look.passes_live()[DevLook.PRINT], str(look.snapshot()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DevLook.LOOK_DIR.path_join(id + ".json")))
	console.run("reset all")

	_t.check("a name with 'wait' in it is a plain command", not DevConsole.needs_script("bake wait-room"), "")
	_t.check("a chain with a still in it runs as a script", DevConsole.needs_script("cam iso; shot a"), "")

	console.set_open(true)
	_t.check("opening holds the game's own input", not game.is_processing_input(), "")
	_t.check("opening keeps the console's own input", console.is_processing_input(), "")
	console.set_open(false)
	_t.check("closing gives input back", game.is_processing_input(), "")
	game.hold_play("menu", true)
	console.set_open(true)
	_t.check("the console holds the menu while open", game.menu_held(), "")
	game.hold_play("menu", false)
	console.set_open(false)
	_t.check("a menu that closed while the console was open stays closed", not game.menu_held(), "")
	console.set_open(true)
	game.hold_play("menu", true)
	console.set_open(false)
	_t.check("a menu that opened while the console was open stays held", game.menu_held(), "")
	game.hold_play("menu", false)

	var late := Node.new()
	game.add_child(late)
	late.set_process_input(false)
	console.set_open(true)
	late.set_process_input(true)
	console.run("status")
	await process_frame
	_t.check("a node that wakes its input while the console is open is held", not late.is_processing_input(), "")
	console.set_open(false)
	_t.check("that node gets its input back on close", late.is_processing_input(), "")
	late.free()

	await _test_structured_and_fight(game, console)
	await _test_inspect_and_assertions(game, console)
	await _test_agent(console)

	Engine.time_scale = 1.0
	console.free()
	game.free()

	await _test_session()
	quit(_t.verdict())


func _test_structured_and_fight(game, console) -> void:
	var schema: Array = console.commands.schema()
	_t.check("commands.schema() lists all registered commands", schema.size() == console.commands.names().size() and schema.size() > 25, str(schema.size()))
	var help_res: Dictionary = console.commands.run_one_detailed("help json")
	_t.check("help json returns structured data array", help_res.ok and help_res.data is Array and help_res.data.size() == schema.size(), str(help_res))
	var bad_res: Dictionary = console.commands.run_one_detailed("not_a_cmd")
	_t.check("unknown detailed command returns ok=false", not bad_res.ok and bad_res.tone == "warn", str(bad_res))

	_t.check("seed sets override", console.commands.run_one_detailed("seed 42").ok, "")
	_t.check("stage jumps to stage 2", console.commands.run_one_detailed("stage 2").ok and game.run.stage == 2, "")
	await process_frame
	_t.check("retry succeeds from stage 2", console.commands.run_one_detailed("retry").ok, "")
	await process_frame
	console.commands.run_one("pick 1")
	await process_frame
	_t.check("assert state stage passes after stage retry", console.commands.run_one_detailed("assert state stage").ok, "")

	_t.check("warp spawn moves safely", console.commands.run_one_detailed("warp spawn").ok, "")
	_t.check("warp beacon moves safely", console.commands.run_one_detailed("warp beacon").ok, "")
	_t.check("warp ahead moves safely", console.commands.run_one_detailed("warp ahead 5").ok, "")
	_t.check("vel applies", console.commands.run_one_detailed("vel 2 0 0").ok, "")
	_t.check("speed applies", console.commands.run_one_detailed("speed 12").ok, "")
	_t.check("give grants part", console.commands.run_one_detailed("give hot_rivets 2").ok and "hot_rivets" in game.run.parts, "")
	_t.check("parts list succeeds", console.commands.run_one_detailed("parts list").ok, "")
	_t.check("parts clear empties parts", console.commands.run_one_detailed("parts clear").ok and game.run.parts.is_empty(), "")
	_t.check("panel grants panel", console.commands.run_one_detailed("panel hull_tile 2").ok, "")
	_t.check("drop_scale updates dropper", console.commands.run_one_detailed("drop_scale 3").ok and is_equal_approx(game.build.dropper.scale, 3.0), "")
	_t.check("relic adds pilot relic", console.commands.run_one_detailed("relic crater_heart").ok, "")
	_t.check("tune overrides cruise", console.commands.run_one_detailed("tune cruise 15").ok and is_equal_approx(game.tuning.base("cruise"), 15.0), "")
	_t.check("tune reset restores defaults", console.commands.run_one_detailed("tune reset").ok, "")
	_t.check("quality low switches preset", console.commands.run_one_detailed("quality low").ok, "")
	_t.check("quality high restores preset", console.commands.run_one_detailed("quality high").ok, "")
	_t.check("warden command answers cleanly", console.commands.run_one("warden") != "", "")
	_t.check("beacon status succeeds in stage", console.commands.run_one_detailed("beacon").ok, "")
	_t.check("flood command answers cleanly", console.commands.run_one("flood") != "", "")

	console.run("freeze")
	_t.check("freeze pauses the tree without zeroing Engine.time_scale", paused and Engine.time_scale > 0.0, "")
	var before_rt: float = game.run.run_time
	var tick_res: Dictionary = await console.fight.step_physics(5)
	_t.check("step_physics advances while frozen and keeps freeze", tick_res.ok and paused and game.run.run_time > before_rt and Engine.time_scale > 0.0, str(tick_res))
	game.toggle_pause()
	var paused_tick: Dictionary = await console.fight.step_physics(2)
	_t.check("step_physics refuses while pause menu wants pause", not paused_tick.ok, str(paused_tick))
	game.toggle_pause()
	console.run("freeze")
	_t.check("unfreeze resumes", not paused, "")


func _test_inspect_and_assertions(game, console) -> void:
	var insp: DevInspect = console.inspect
	_t.check("DevInspect is mounted", insp != null and insp.is_inside_tree(), "")
	insp.clear_events()
	insp.reset_assertions()
	_t.check("events recording turns on", console.commands.run_one_detailed("events on").ok, "")
	_t.check("damage hurts hull", console.commands.run_one_detailed("damage 15").ok, "")
	_t.check("events tail records player_hit", console.commands.run_one_detailed("events tail 10").ok and insp.event_count("player_hit") >= 1, "")

	for topic in DevInspect.TOPICS:
		var snap: Dictionary = insp.snapshot(topic)
		var json_str := JSON.stringify(snap)
		_t.check("inspect topic '%s' serializes to JSON cleanly" % topic, JSON.parse_string(json_str) != null, topic)

	for ok_cmd in [
		"assert finite",
		"assert no_anomalies",
		"assert state beacon",
		"assert stage 2",
		"assert enemies 0",
		"assert hp > 0",
		"assert event player_hit 1",
		"assert no_event boss_defeated",
		"assert expr flow.in_play()",
	]:
		var res: Dictionary = console.commands.run_one_detailed(ok_cmd)
		_t.check("%s passes" % ok_cmd, res.ok, str(res))

	var fail_state: Dictionary = console.commands.run_one_detailed("assert state dead")
	_t.check("assert state dead fails as negative control", not fail_state.ok, str(fail_state))
	var fail_enemies: Dictionary = console.commands.run_one_detailed("assert enemies 99")
	_t.check("assert enemies 99 fails as negative control", not fail_enemies.ok, str(fail_enemies))
	insp.reset_assertions()
	console.commands.run_one("events off")


func _test_agent(console) -> void:
	var out_dir := "user://dev_test_out_%d" % OS.get_process_id()
	var receipt: Dictionary = await console.agent.run_scenario(["inspect state", "assert finite"], {"out": out_dir, "reset_assertions": true})
	_t.check("DevAgent.run_scenario passes and writes receipt", receipt.ok and int(receipt.steps_total) == 2 and FileAccess.file_exists(String(receipt.receipt_path)) and FileAccess.file_exists(String(receipt.steps_path)), str(receipt))
	var parsed_receipt = SafeStore.parse(FileAccess.get_file_as_string(String(receipt.receipt_path)), TYPE_DICTIONARY)
	_t.check("receipt.json contains steps array and elapsed_ms", parsed_receipt is Dictionary and parsed_receipt.has("steps") and parsed_receipt.has("elapsed_ms"), "")
	_rm_dir_recursive(ProjectSettings.globalize_path(out_dir))

	var fail_receipt: Dictionary = await console.agent.run_scenario(["assert enemies 99"], {"reset_assertions": true})
	_t.check("DevAgent.run_scenario returns ok=false when assertion fails", not fail_receipt.ok and int(fail_receipt.steps_failed) == 1, str(fail_receipt))

	var inbox := "user://dev_test_inbox_%d" % OS.get_process_id()
	var g_inbox := ProjectSettings.globalize_path(inbox)
	console.agent.inbox_dir = inbox
	console.agent._start_mailbox()
	_t.check("mailbox writes ready.json", FileAccess.file_exists(g_inbox.path_join("ready.json")), g_inbox)
	SafeStore.write_atomic(g_inbox.path_join("in").path_join("0001.req.json"), JSON.stringify({"id": "0001", "cmd": "inspect state; assert finite"}))
	var res_path := g_inbox.path_join("out").path_join("0001.res.json")
	for i in 20:
		await process_frame
		if FileAccess.file_exists(res_path):
			break
	var res_doc = SafeStore.parse(FileAccess.get_file_as_string(res_path), TYPE_DICTIONARY) if FileAccess.file_exists(res_path) else null
	_t.check("mailbox answers atomic request cleanly", res_doc is Dictionary and bool(res_doc.get("ok", false)) and (res_doc.get("results", []) as Array).size() == 2, str(res_doc))
	console.agent._cleanup_ready()
	_t.check("mailbox cleanup removes ready.json", not FileAccess.file_exists(g_inbox.path_join("ready.json")), "")
	console.agent.inbox_dir = ""
	_rm_dir_recursive(g_inbox)


func _test_session() -> void:
	var session := DevSession.start(self, {"calm": true, "seed": 77, "start_run": true})
	await process_frame
	await session.tick(3)
	var snap: Dictionary = session.inspect("player")
	_t.check("DevSession runs in-process and inspects player", not snap.is_empty() and snap.has("hp"), str(snap))
	var ok_res: Dictionary = session.assert_ok("assert finite")
	_t.check("DevSession.assert_ok succeeds", ok_res.ok, str(ok_res))
	session.close()


static func _rm_dir_recursive(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for sub in d.get_directories():
		_rm_dir_recursive(dir_path.path_join(sub))
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(dir_path)
