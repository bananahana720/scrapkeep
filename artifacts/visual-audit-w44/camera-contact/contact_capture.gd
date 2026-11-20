extends "res://tools/danger_read_capture.gd"

# Draw the same approaches on the stage and candidate with a scratch home.
var hit_tick := -1
var charge_lane
var fixture := ""

func _initialize() -> void:
	seed(1)
	super()

func _lobber(_ground, _spot: Vector3, _ahead: Vector3) -> void:
	game.ctx.rng.seed = 1
	game.flow.force_warden = true
	game.flow.enter_stage(1, Vector3.ZERO, false)
	await _ticks(90)
	if not is_instance_valid(game.flow.warden):
		return _fail("dam reactor missing")
	game.flow._engage()
	for row in [["west", Vector3(-10.4, -0.2, 568.2)], ["east", Vector3(8.4, 0.1, 578.9)]]:
		var p: Vector3 = row[1]
		var heading := _flat(Vector3(0, 22, 590) - p)
		fixture = "dam-" + str(row[0])
		await _place(p - heading * 3.0, heading, 30)
		game.camera.snap(heading, 0.5)
		game.player.body().freeze = false
		game.player.set_velocity_now(heading * 8.0)
		for n in [10, 20, 20]:
			await _ticks(n)
			await _frame(fixture + "-" + str(records.size()))
	game.flow.enter_stage(2, Vector3.ZERO, false)
	await _ticks(90)
	var air := Vector3(-20, 0, 92)
	var ground = game.ctx.spawner.ground
	air = _on(ground, air) + Vector3.UP * 26.0
	var direction := Vector3(0.65, 0, 0.76).normalized()
	await _place(air, direction, 90)
	game.player.body().freeze = false
	game.player.set_velocity_now(direction * 33.0 + Vector3.DOWN * 9.0)
	await _ticks(16)
	await _frame("flume-air")
	for i in 6:
		game.camera.look(Vector2(-PI / (6.0 * game.camera.mouse_sensitivity), 0))
		await physics_frame
	await _frame("flume-turn")
	for i in 360:
		await physics_frame
		if game.player.state.grounded:
			break
	await _frame("flume-landing")
	game.ctx.calm = false
	game.flow.enter_boss(Vector3.ZERO)
	await _ticks(90)
	var boss = game.ctx.boss
	var arena = boss.arena
	var floor_query = arena.ground_query()
	var aimed := _stand(floor_query, arena.global_position + Vector3(23, 0, 3))
	await _place(aimed, _flat(boss.ship.global_position - aimed))
	game.events.player_hit.connect(func(_damage, source):
		if source == "brindle_charge":
			hit_tick = Engine.get_physics_frames())
	boss.jump_to_phase(3)
	charge_lane = await _attack("charge", null)
	if charge_lane == null:
		return _fail("no charge")
	game.camera.snap(_flat(boss.ship.global_position - aimed), 0.22)
	await _ticks(12)
	await _frame("brindle-warning")
	# Hold the position during windup, then let the normal charge shove the ball.
	game.player.body().freeze = false
	for i in WAIT_TICKS:
		await physics_frame
		if hit_tick >= 0:
			break
	if hit_tick < 0:
		return _fail("charge missed direct hit")
	await _frame("brindle-hit")
	await _ticks(roundi(Engine.physics_ticks_per_second * 0.30))
	await _frame("brindle-after")
	var far := _stand(floor_query, arena.global_position - Vector3(14, 0, 3))
	await _place(far, _flat(boss.ship.global_position - far), 4)
	charge_lane = await _attack("charge", charge_lane)
	if charge_lane == null:
		return _fail("no second charge")
	var side: Vector3 = charge_lane.heading.cross(Vector3.UP)
	var dodge := _stand(floor_query, far + side * (charge_lane.half_width + CLEAR))
	await _place(dodge, _flat(boss.ship.global_position - dodge), 4)
	var previous := hit_tick
	while is_instance_valid(charge_lane) and not charge_lane.is_done():
		await physics_frame
	if previous != hit_tick:
		return _fail("second charge hit the sidestep")
	await _frame("brindle-escape")

func _frame(label: String) -> void:
	paused = true
	for i in 2:
		await RenderingServer.frame_post_draw
	var path := out.path_join(label + ".jpg")
	root.get_texture().get_image().save_jpg(path, 0.85)
	var rig = game.camera
	var arm: Dictionary = rig.arm_reading()
	var row := {"id":label, "arm":arm, "tick":Engine.get_physics_frames(),
		"ball":str(game.player.ball_position()), "pivot":str(rig.global_position),
		"lens":str(rig.cam.global_position), "aim":str(rig.aim_forward()), "origin":str(rig.aim_origin()),
		"yaw":rig.yaw,"pitch":rig.pitch,"arm_pitch":rig.arm.rotation.x,
		"subject":str(game.flow.warden.global_position) if is_instance_valid(game.flow.warden) else null}
	var ship = game.boss.ship if game.boss != null else null
	if is_instance_valid(ship):
		row["ship"] = str(ship.global_transform)
		var boxes := []
		for entry in ship._camera_bodies:
			var body: Node3D = entry[0]
			if body.get_child(0).disabled:
				continue
			var size: Vector3 = body.get_child(0).shape.size
			var local := body.to_local(rig.cam.global_position)
			var box := AABB(-size * 0.5, size)
			boxes.append({"part":str(entry[1].name),"pose":str(body.global_transform),"size":str(size),
				"lens_inside":box.has_point(local),"blocks_arm":box.intersects_segment(body.to_local(rig.global_position), local) != null})
		row["drawn_boxes"] = boxes
	row["straight_probe"] = _probe(rig, rig.pitch)
	row["level_probe"] = _probe(rig, -0.1)
	row["high_probe"] = _probe(rig, -0.95)
	records.append(row)
	var log := FileAccess.open(out.path_join("contact.json"), FileAccess.WRITE)
	log.store_string(JSON.stringify(records,"\t"))
	log.close()
	paused = false


func _probe(rig, requested_pitch: float) -> Dictionary:
	var dir: Vector3 = rig.yaw_basis() * Basis(Vector3.RIGHT, requested_pitch) * Vector3.BACK
	var request := PhysicsShapeQueryParameters3D.new()
	request.shape = rig.arm.shape
	request.collision_mask = rig.arm.collision_mask
	request.transform.origin = rig.global_position
	request.motion = dir * rig.arm.spring_length
	var space: PhysicsDirectSpaceState3D = rig.get_world_3d().direct_space_state
	var fractions := space.cast_motion(request)
	var row := {"free_m": fractions[0] * rig.arm.spring_length}
	if fractions[0] < 1.0:
		request.transform.origin += request.motion * fractions[1]
		request.motion = Vector3.ZERO
		var rest := space.get_rest_info(request)
		if not rest.is_empty():
			row["normal"] = str(rest.normal)
			row["body"] = str(instance_from_id(rest.collider_id).get_path())
	return row
