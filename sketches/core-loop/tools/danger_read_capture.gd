extends SceneTree


const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const SiltBoil := preload("res://src/combat/silt_boil.gd")
const Projectile := preload("res://src/combat/projectile.gd")
const Arena := preload("res://src/boss/arena.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const MossBubble := preload("res://src/ui/moss_bubble.gd")
const LockRows := preload("res://src/world/lock_rows.gd")

const MARKS := ["boil", "lobber", "yard", "slag", "charge"]
const SETTLE := 45
const CLEAR := 5.0
const LOBBER_AT := 30.0
const CHARGE_FAR := 8.0
const WAIT_TICKS := 2400
const QUIET_TICKS := 900
const LANDED := 1.6

var game
var out := ""
var only: Array = []
var at := 0.6
var records := []
var failed := ""
var _made: Array = []
var _bubble: Node


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = Array(arg.trim_prefix("--only=").split(","))
		elif arg.begins_with("--at="):
			if not arg.trim_prefix("--at=").is_valid_float():
				quit(2)
				return
			at = clampf(float(arg.trim_prefix("--at=")), 0.05, 0.95)
	if out.is_empty() or DisplayServer.get_name() == "headless" or only.any(func(id): return not MARKS.has(id)):
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		quit(3)
		return
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	var waited := 0
	while game.flow == null and waited < 600:
		waited += 1
		await physics_frame
	if game.flow == null:
		return _fail("the game never built its flow")
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	var ground = game.ctx.spawner.ground
	var down := 0
	for i in WAIT_TICKS:
		await physics_frame
		var p: Vector3 = game.player.ball_position()
		down = down + 1 if p.y - Telegraph.ground_under(ground, p) < LANDED else 0
		if down >= 30:
			break
	if down < 30:
		return _fail("the ball never landed")
	if game.hud.get("first_steps") != null:
		game.hud.first_steps.modulate.a = 0.0

	var spot: Vector3 = game.player.ball_position()
	var ahead := _flat(game.flow.beacon.global_position - spot) if is_instance_valid(game.flow.beacon) else Vector3.BACK
	await _place(spot, ahead)
	await _quiet()
	if _wanted("boil"):
		var boil := func(centre: Vector3) -> void:
			var mid := _on(ground, centre)
			var ring = Telegraph.ring(game.ctx.root, ground, Threat.Type.INSTANT, mid, SiltBoil.RADIUS)
			ring.set_progress(at)
			_made.append(ring)
			game.ctx.spawner.boils.rumbled.emit(mid, SiltBoil.WARN)
		await _place(spot, ahead)
		boil.call(spot)
		await _stills("boil", spot, SiltBoil.WARN * at)
		_clear()
		boil.call(spot + ahead * (SiltBoil.RADIUS + CLEAR))
		await _still("boil", "outside", spot, SiltBoil.WARN * at)
		_clear()
	if _wanted("lobber") and failed == "":
		await _lobber(ground, spot, ahead)
	if _wanted("yard") and failed == "":
		var map = game.ctx.terrain.map()
		var row: Dictionary = LockRows.row(String(map.title)) if map != null and "title" in map else {}
		var lock: Dictionary = row.get("lock", {})
		if lock.is_empty():
			return _fail("this map has no yard lock row")
		var locks = game.world.locks
		var radius := float(lock["radius_m"])
		var wall := func(centre: Vector3) -> void:
			locks.lock_centre = Vector3(centre.x, spot.y, centre.z)
			locks._build_wall(radius)
			locks._wall.scale = Vector3.ONE
		await _place(spot, ahead)
		wall.call(spot + ahead * minf(float(lock.get("ahead_m", 0.0)), radius * 0.5))
		await _still("yard", "inside", spot, 0.5)
		locks._drop_wall()

	if (_wanted("slag") or _wanted("charge")) and failed == "":
		game.player.body().freeze = false
		game.flow.enter_stage(1, Vector3.ZERO, false)
		await _ticks(60)
		game.flow.enter_stage(2, Vector3.ZERO, false)
		await _ticks(60)
		game.flow.enter_boss(Vector3.ZERO)
		await _ticks(180)
		var boss = game.ctx.boss
		var arena = boss.get("arena") if boss != null else null
		if arena == null or boss.get("ship") == null:
			return _fail("the boss fight did not build its arena and ship")
		var floor_query = arena.ground_query()
		var centre: Vector3 = arena.global_position
		var start: Vector3 = game.player.ball_position()
		var out_dir := _flat(start - centre)
		if out_dir == Vector3.ZERO:
			out_dir = Vector3.RIGHT
		game.run.set_max_hp(999999.0)
		await _place(_stand(floor_query, start), _flat(boss.ship.global_position - start))
		await _quiet()
		if _wanted("slag"):
			boss.jump_to_phase(2)
			boss._next_lobber = INF
			var parked := 0
			while parked < WAIT_TICKS and _flat_length(boss.ship.global_position - centre) > 0.3:
				parked += 1
				await physics_frame
			var ring = await _attack("slag_ring", null)
			if ring == null:
				return _fail("Brindle laid no slag ring")
			var inside := _stand(floor_query, centre + out_dir * (ring.r_in + ring.r_out) * 0.5)
			await _place(inside, _flat(boss.ship.global_position - inside), 4)
			await _stills("slag", inside, -1.0, ring)
			ring = await _attack("slag_ring", ring)
			if ring == null:
				return _fail("Brindle laid no second slag ring")
			var off: float = ring.r_out + CLEAR if ring.r_out < Arena.RING_B.x else ring.r_in - CLEAR
			var outside := _stand(floor_query, centre + out_dir * off)
			await _place(outside, _flat(boss.ship.global_position - outside), 4)
			await _still("slag", "outside", outside, -1.0, ring)
		if _wanted("charge") and failed == "":
			var aimed := _stand(floor_query, start)
			await _place(aimed, _flat(boss.ship.global_position - aimed))
			boss.jump_to_phase(3)
			var lane = await _attack("charge", null)
			if lane == null:
				return _fail("Brindle never charged")
			game.camera.snap(_flat(boss.ship.global_position - aimed))
			await _stills("charge", aimed, -1.0, lane)
			for i in WAIT_TICKS:
				if not is_instance_valid(lane) or lane.is_done():
					break
				await physics_frame
			var far := _stand(floor_query, centre - out_dir * CHARGE_FAR)
			await _place(far, _flat(boss.ship.global_position - far), 4)
			lane = await _attack("charge", lane)
			if lane == null:
				return _fail("Brindle never charged a second time")
			var side: Vector3 = (lane.heading as Vector3).cross(Vector3.UP).normalized()
			var dodged := _stand(floor_query, far + side * (lane.half_width + CLEAR))
			await _place(dodged, _flat(boss.ship.global_position - dodged), 4)
			await _still("charge", "outside", dodged, -1.0, lane)

	if failed != "":
		return
	var file := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	if file == null:
		quit(3)
		return
	var size := root.get_visible_rect().size
	file.store_string(JSON.stringify({"tool": "danger_read_capture.gd", "at": at, "size": [size.x, size.y], "table": game.table,
		"adapter": RenderingServer.get_video_adapter_name(), "danger_mark": _danger_mark() != null, "frames": records,
		"limits": "The lobber, the slag ring and the charge lane are the game's own attacks. The boil ring and the yard wall are staged through the game's builders and sizes with no fight running, the wall where the run starts and not where the lock fires. No crew is on screen, Brindle's drones are held off, and the crew's hello is put down as a press of fire does. Each still lists the warnings on screen under threats. Size, place and read only on a software renderer."}, "\t"))
	file.close()
	quit(0)


func _lobber(ground, spot: Vector3, ahead: Vector3) -> void:
	await _place(spot, ahead)
	var stand := spot + ahead * LOBBER_AT
	var lobber: Node3D = game.ctx.spawner.spawn_enemy("lobber", _on(ground, stand) + Vector3.UP)
	var shell = await _shell()
	if shell == null:
		return _fail("the lobber never fired")
	await _stills("lobber", spot, -1.0, shell)
	_drop(shell)
	var on := spot + ahead * (Projectile.BLAST_RADIUS + CLEAR)
	on = _on(ground, on) + Vector3.UP * (spot.y - Telegraph.ground_under(ground, spot))
	await _place(on, ahead, 4)
	shell = await _shell()
	if shell == null:
		return _fail("the lobber never fired a second shell")
	await _place(spot, ahead, 4)
	await _still("lobber", "outside", spot, -1.0, shell)
	_drop(shell)
	if is_instance_valid(lobber):
		lobber.queue_free()
	await _ticks(4)


func _shell():
	for i in WAIT_TICKS:
		for node in get_nodes_in_group("enemy_shot"):
			if is_instance_valid(node) and is_instance_valid(node.get("ring")):
				return node
		await physics_frame
	return null


static func _drop(shell) -> void:
	if not is_instance_valid(shell):
		return
	if is_instance_valid(shell.get("ring")):
		shell.ring.free()
	shell.free()


func _stills(id: String, ball: Vector3, hold: float, shell = null) -> void:
	await _hold(hold, shell)
	paused = true
	await _shot(id, "inside", false, ball, shell)
	if _danger_mark() != null:
		await _shot(id, "inside-plain", true, ball, shell)
	paused = false


func _still(id: String, where: String, ball: Vector3, hold: float, shell = null) -> void:
	await _hold(hold, shell)
	paused = true
	await _shot(id, where, false, ball, shell)
	paused = false


func _hold(seconds: float, mark) -> void:
	if mark == null:
		await _ticks(maxi(4, roundi(seconds * Engine.physics_ticks_per_second)))
		return
	for i in WAIT_TICKS:
		if _run_of(mark) >= at:
			return
		await physics_frame


static func _run_of(mark) -> float:
	if not is_instance_valid(mark):
		return 2.0
	if mark.get("ring") != null:
		return float(mark.ring.progress) if is_instance_valid(mark.ring) else 2.0
	return float(mark.age) / maxf(float(mark.warn_seconds), 0.01) if int(mark.state) == Hazard.WARN else 2.0


func _attack(prefix: String, after):
	for i in WAIT_TICKS * 2:
		for node in get_nodes_in_group(Threat.GROUP):
			if node != after and is_instance_valid(node) and str(node.get("attack_id")).begins_with(prefix) \
					and not bool(node.cued) and int(node.state) == Hazard.WARN and float(node.age) < float(node.warn_seconds) * at * 0.5:
				return node
		await physics_frame
	return null


func _quiet() -> void:
	await _ticks(QUIET_TICKS)
	var down := 0
	for i in WAIT_TICKS:
		if _speaking():
			_bubble.dismiss_exchange()
			_bubble.hush()
		down = 0 if _speaking() else down + 1
		if down >= 2 * Engine.physics_ticks_per_second:
			return
		await physics_frame


func _speaking() -> bool:
	if _bubble == null:
		for node in game.find_children("*", "Control", true, false):
			if node.get_script() == MossBubble:
				_bubble = node
				break
	return is_instance_valid(_bubble) and _bubble.showing()


func _threats() -> Array:
	var found := []
	for node in get_nodes_in_group(Threat.GROUP):
		if is_instance_valid(node) and node.is_inside_tree():
			found.append(str(node.get("attack_id")) if node.get("attack_id") != null else "ring")
	return found


func _shot(id: String, where: String, plain: bool, ball: Vector3, mark_node = null) -> void:
	if failed != "":
		return
	var mark = _danger_mark()
	if mark != null:
		mark.modulate.a = 0.0 if plain else 1.0
	await _frames(3)
	await RenderingServer.frame_post_draw
	var path := out.path_join("%s-%s.png" % [id, where])
	if root.get_texture().get_image().save_png(path) != OK:
		return _fail("could not save %s" % path)
	var watch = game.combat.get("near_miss")
	var standing = watch.standing_in() if watch != null and watch.has_method("standing_in") else null
	if standing != null and id != "yard" and (float(standing) >= 0.0) != where.begins_with("inside"):
		return _fail("%s-%s: the game reads the ball %s the mark" % [id, where, "inside" if float(standing) >= 0.0 else "outside"])
	var threats := _threats()
	if id in ["boil", "lobber", "yard"] and threats.size() != (0 if id == "yard" else 1):
		return _fail("%s-%s: %d warnings on screen: %s" % [id, where, threats.size(), str(threats)])
	records.append({"id": id, "where": where, "ball": [ball.x, ball.y, ball.z],
		"standing_in": standing, "threats": threats, "crew_line": _speaking(),
		"warning_run": snappedf(_run_of(mark_node), 0.01) if mark_node != null else at,
		"danger_mark_shown": mark != null and mark.visible and not plain, "sha256": FileAccess.get_sha256(path)})
	if mark != null:
		mark.modulate.a = 1.0


func _place(point: Vector3, heading: Vector3, settle := SETTLE) -> void:
	var body = game.player.body()
	body.freeze = false
	game.player.reset_to(point)
	await _ticks(2)
	body.freeze = true
	game.camera.snap(heading)
	await _frames(settle)


func _clear() -> void:
	for node in _made:
		if is_instance_valid(node):
			node.free()
	_made.clear()


func _fail(why: String) -> void:
	if failed != "":
		return
	failed = why
	push_error("danger_read_capture: %s" % why)
	paused = false
	quit(4)


func _danger_mark():
	return game.hud.get("danger_mark") if game.hud != null else null


func _wanted(id: String) -> bool:
	return only.is_empty() or id in only


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()


static func _flat_length(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


static func _on(ground, point: Vector3) -> Vector3:
	return Vector3(point.x, Telegraph.ground_under(ground, point), point.z)


func _stand(floor_query, point: Vector3) -> Vector3:
	return Vector3(point.x, floor_query.height(point.x, point.z) + 1.2, point.z)
