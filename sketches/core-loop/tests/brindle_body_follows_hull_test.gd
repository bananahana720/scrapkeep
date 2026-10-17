extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")

# Brindle's collision bodies move with her visible hull. Every strikeable piece (hull,
# caps, magnets) is an AnimatableBody3D under the Requisition, which boss.gd moves each
# tick. The physics server's copy of each body must sit on its visible node while the ship
# moves, and a probe at the visible hull must reach the body on the enemy layer, so a ram
# or slam at what the player sees lands (the seed-2 stall: the body stayed near the arena
# centre while the hull charged around).
#
# Evidence limit: the probe is a physics point query on layer 3, the layer the ball's
# contacts resolve against; no ball is driven into the hull here.

const TOLERANCE := 0.25
const STOPS := [Vector3(60.0, 0.0, 0.0), Vector3(-45.0, 0.0, 50.0), Vector3(10.0, 0.0, -70.0)]

var _game
var _boss
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _server_pos(body) -> Vector3:
	return PhysicsServer3D.body_get_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM).origin


func _pieces() -> Array:
	var out: Array = [_boss.ship.hull]
	out.append_array(_boss.ship.caps)
	out.append_array(_boss.ship.magnets)
	return out


func _probe_hits(body, at: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = at
	query.collision_mask = 1 << 2
	for hit in _boss.ship.get_world_3d().direct_space_state.intersect_point(query, 8):
		if hit["collider"] == body:
			return true
	return false


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_game.ctx.spawner = _game.combat
	_boss = _game.boss
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	await physics_frame
	var ship = _boss.ship
	var worst := 0.0
	var worst_name := ""
	var missed: Array = []
	var checked := 0
	for stop in STOPS:
		ship.move_to(_boss.arena.global_position + stop, stop.normalized())
		for i in 4:
			await physics_frame
		for body in _pieces():
			if body.collision_layer == 0:
				continue
			checked += 1
			var off: float = _server_pos(body).distance_to(body.global_position)
			if off > worst:
				worst = off
				worst_name = String(body.name)
			if not _probe_hits(body, body.global_position):
				missed.append(String(body.name))
	# The live fight: the ship circles in phase 1 and charges in phase 3 under boss.gd's own tick.
	var live_worst := 0.0
	var live_name := ""
	var live_frames := 0
	var moved := 0.0
	var last_at: Vector3 = ship.global_position
	for phase in [1, 3]:
		_boss._enter_phase(phase)
		for i in 540:
			await physics_frame
			live_frames += 1
			moved = maxf(moved, ship.global_position.distance_to(last_at))
			for body in _pieces():
				if body.collision_layer == 0:
					continue
				var off: float = _server_pos(body).distance_to(body.global_position)
				if off > live_worst:
					live_worst = off
					live_name = "%s phase %d" % [body.name, phase]
	var live_missed: Array = []
	for body in _pieces():
		if body.collision_layer != 0 and not _probe_hits(body, body.global_position):
			live_missed.append(String(body.name))
	_report("a probe at each visible body reaches it after the live fight", live_missed.is_empty(), "missed: %s" % [live_missed])
	_report("the live fight moved the ship", moved > 5.0 and live_frames == 1080, "ship travelled %.1f m from its start over %d frames" % [moved, live_frames])
	_report("every body stays on its node through the live fight", live_worst <= TOLERANCE,
		"worst server-to-node offset %.2f m (%s), tolerance %.2f" % [live_worst, live_name, TOLERANCE])
	_report("the test reached the bodies", checked >= STOPS.size() * 4, "%d body checks (hull and three caps per stop)" % checked)
	_report("every body sits on its visible node while the ship moves", worst <= TOLERANCE,
		"worst server-to-node offset %.2f m (%s), tolerance %.2f" % [worst, worst_name, TOLERANCE])
	_report("a probe at each visible body reaches it on the enemy layer", missed.is_empty(),
		"missed: %s" % [missed])
	print("brindle_body_follows_hull_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
