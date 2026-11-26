extends RefCounted

const Game := preload("res://src/game.gd")
const DevConsole := preload("res://src/dev/dev_console.gd")
const DevInspect := preload("res://src/dev/dev_inspect.gd")
const DevAgent := preload("res://src/dev/dev_agent.gd")

var tree: SceneTree
var game: Node
var console: Node
var inspector: Node
var agent: Node
var _closed := false


static func start(scene_tree: SceneTree, opts := {}) -> RefCounted:
	var session: RefCounted = load("res://src/dev/dev_session.gd").new()
	session._boot(scene_tree, opts)
	return session


func _boot(scene_tree: SceneTree, opts: Dictionary) -> void:
	tree = scene_tree
	game = Game.new()
	game.test_mode = bool(opts.get("test_mode", true))
	game.dev = true
	if opts.has("table"):
		game.table = String(opts["table"])
	tree.root.add_child(game)
	if game.ctx != null:
		game.ctx.calm = bool(opts.get("calm", true))
	if opts.has("seed") and game.ctx != null and game.ctx.run != null and game.ctx.rng != null:
		var s := int(opts["seed"])
		game.ctx.run.run_seed_override = s
		game.ctx.rng.seed = s
	console = game.get_node_or_null("DevConsole")
	if console == null:
		console = DevConsole.new()
		game.add_child(console)
		console.setup(game)
	if not console.commands.has("stage"):
		console.fight.register_extra(console.commands)
	inspector = console.get("inspect") if "inspect" in console else console.get_node_or_null("DevInspect")
	if inspector == null:
		inspector = DevInspect.new()
		console.add_child(inspector)
		inspector.setup(game, console)
		inspector.register(console.commands)
	agent = console.get("agent") if "agent" in console else console.get_node_or_null("DevAgent")
	if agent == null:
		agent = DevAgent.new()
		console.add_child(agent)
		agent.setup(game, console)
	if bool(opts.get("events", false)):
		inspector.set_recording(true)
	if bool(opts.get("start_run", false)) or opts.has("pilot"):
		exec("pilot %s" % str(opts.get("pilot", 1)))
	if opts.has("stage"):
		exec("stage %s" % str(opts["stage"]))


func exec(cmd: String) -> Dictionary:
	if _closed or not is_instance_valid(console):
		return {"cmd": cmd, "ok": false, "text": "!session closed", "data": null, "tone": "warn"}
	var trimmed := cmd.strip_edges()
	if trimmed.contains(";"):
		var results: Array[Dictionary] = console.commands.run_detailed(trimmed, false)
		var all_ok := true
		var texts: Array[String] = []
		var last_data: Variant = null
		for row in results:
			if not bool(row.get("ok", false)):
				all_ok = false
			var t := String(row.get("text", ""))
			if not t.is_empty():
				texts.append(t)
			last_data = row.get("data", null)
		return {"cmd": trimmed, "ok": all_ok, "text": "\n".join(texts), "data": last_data, "results": results, "tone": "ok" if all_ok else "warn"}
	return console.commands.run_one_detailed(trimmed)


func tick(n := 1) -> Dictionary:
	if _closed or not is_instance_valid(console) or console.fight == null:
		return {"ok": false, "text": "!session closed", "data": {}}
	return await console.fight.step_physics(n)


func inspect(topic := "all") -> Dictionary:
	if _closed or not is_instance_valid(inspector):
		return {}
	return inspector.snapshot(topic)


func assert_ok(cmd: String) -> Dictionary:
	var res := exec(cmd)
	assert(bool(res.get("ok", false)), "DevSession.assert_ok('%s') failed: %s" % [cmd, String(res.get("text", ""))])
	return res


func close() -> void:
	if _closed:
		return
	_closed = true
	Engine.time_scale = 1.0
	if is_instance_valid(console):
		console.free()
	if is_instance_valid(game):
		game.free()
	console = null
	game = null
	inspector = null
	agent = null
	tree = null
