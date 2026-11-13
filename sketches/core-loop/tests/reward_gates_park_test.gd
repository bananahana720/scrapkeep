extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")

# REWARD-PARK: real park_dam ground and placement, with the existing spawner double
# driving the Warden kill through flow. The old stage keeps its single Ground RID.
class ScriptErrors extends Logger:
	var messages: Array[String] = []

	func _log_error(_function: String, file: String, _line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			messages.append("%s: %s %s" % [file, code, rationale])

var _failures := 0
var _errors := ScriptErrors.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	_run.call_deferred()


func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _run() -> void:
	seed(1)
	await _stage("park")
	await _stage("")
	_check("no script errors", _errors.messages.is_empty(), str(_errors.messages))
	OS.remove_logger(_errors)
	print("reward_gates_park_test: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _stage(table: String) -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = table
	root.add_child(game)
	await process_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	var spawner := SpawnerDouble.new()
	game.add_child(spawner)
	spawner.setup(game.ctx)
	game.ctx.spawner = spawner
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 12:
		await physics_frame
	var terrain = game.ctx.terrain
	var gates = game.build.gates
	var ground: Node = terrain.geometry_root(1).get_node_or_null("Ground")
	_check("%s stage 1 ground built" % table, terrain.stage == 1 and terrain.is_ready(1) and ground != null)
	if ground == null:
		game.free()
		return
	# Count independently by walking the live tree, including Ground itself.
	var bodies: Array[CollisionObject3D] = []
	var pending: Array[Node] = [ground]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is CollisionObject3D:
			bodies.append(node)
		pending.append_array(node.get_children())
	var excluded: Array = gates._prop_probe_exclude()
	if table == "park":
		_check("park table stage 1 is park_dam", game.ctx.stages == ParkDefs and terrain.map().title == "park_dam")
		_check("park ground has multiple bodies", bodies.size() > 1, "%d bodies" % bodies.size())
		var missing := 0
		for body in bodies:
			if not excluded.has(body.get_rid()):
				missing += 1
		_check("every park ground body excluded", missing == 0 and excluded.size() == bodies.size(),
			"ground bodies %d, exclusions %d, missing %d" % [bodies.size(), excluded.size(), missing])
		var warden: Node3D = game.flow.warden
		_check("park Warden exists", is_instance_valid(warden))
		if is_instance_valid(warden):
			spawner.strike(warden, "arc", warden.max_hp * 2.0)
			_check("Warden break opens placed gates", game.flow.state_name() == "gates" and gates.is_open(),
				"state %s, sites %d" % [game.flow.state_name(), gates.offers.size()])
			var plan: Dictionary = gates.choose_placement(game.player.ball_position(), Vector3.FORWARD)
			_check("post-break placement returns sites", not plan.is_empty() and plan.get("spots", []).size() == gates.offers.size(),
				"sites %d" % plan.get("spots", []).size())
			# The Warden break's hot-wired part stands at the gates with the rolled picks (pass D fold).
			var pending_offer: Dictionary = game.build.hotwire_pending()
			var ids: Array = gates.offers.map(func(offer): return offer["part_id"])
			_check("the break puts the hot-wired part at a placed gate", pending_offer["state"] == "fit" and ids.has(pending_offer["part_id"]),
				"pending %s, gate parts %s" % [pending_offer, ids])
	else:
		_check("old Ground is the single body", ground is StaticBody3D and bodies.size() == 1)
		if ground is CollisionObject3D:
			_check("old exclusions exactly Ground RID", excluded == [ground.get_rid()], "%d exclusions" % excluded.size())
	game.free()
	await process_frame
