extends SceneTree

const Game := preload("res://src/game.gd")
const DevConsole := preload("res://src/dev/dev_console.gd")
const DevLook := preload("res://src/dev/dev_look.gd")
const DevLens := preload("res://src/dev/dev_lens.gd")
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
	paused = true
	console.run("time 0")
	console.run("time 1")
	_t.check("unfreezing keeps a pause the game already held", paused, "")
	paused = false

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
	game.set_menu_held(true)
	console.set_open(true)
	console.set_open(false)
	_t.check("closing keeps a menu hold the game already had", game.menu_held(), "")
	game.set_menu_held(false)

	Engine.time_scale = 1.0
	console.free()
	game.free()
	quit(_t.verdict())
