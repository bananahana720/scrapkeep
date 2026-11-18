extends RefCounted

# A placed, level 14 m/s entry. Only the release tick changes between takes.
# The original flume trial held for 75 ticks after its bite. Compare every earlier
# tick and report horizontal speed at the first grounded tick after letting go.
const STATIONS := "res://tools/stations/W1-135.json"
const ENTRY_SPEED := 14.0
const HOLD_TICKS := 75
const LANDING_LIMIT := 360
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const Arena := preload("res://src/boss/arena.gd")
const Intent := preload("res://src/movement/intent.gd")

var game
var source := Intent.Scripted.new()


func _init(running_game) -> void:
	game = running_game
	game.player.source = source


func measure(site: Dictionary, no_bite: bool) -> Dictionary:
	var pose := _station(site)
	var row := {"site": site.id, "status": "no hold"}
	if pose.is_empty():
		row["reason"] = "station geometry missing"
		return row
	if no_bite:
		# Move the approach beyond rope range. The ordinary aim and fire decide the result.
		var away: Vector3 = (pose.entry - pose.target).normalized() * (game.player.grapple_range() + 5.0)
		pose.entry += away
		pose.eye += away
	row["target_xyz"] = [pose.target.x, pose.target.y, pose.target.z]
	row["entry_xyz"] = [pose.entry.x, pose.entry.y, pose.entry.z]
	row["gravity_mps2"] = game.tuning.f("gravity")
	var held := await _take(pose, HOLD_TICKS)
	row["held"] = held
	if held.status != "landed":
		row.status = held.status
		return row
	var best := {}
	for tick in range(1, HOLD_TICKS):
		var early := await _take(pose, tick)
		if early.status != "landed":
			row.status = "incomplete early trial"
			row["early"] = early
			return row
		if best.is_empty() or early.landing_mps > best.landing_mps:
			best = early
	row["best_early"] = best
	row["early_trials"] = HOLD_TICKS - 1
	row.status = "measured"
	return row


func _station(site: Dictionary) -> Dictionary:
	var target: Vector3
	var heading: Vector3
	var collider: Node
	if site.stage is String and site.stage == "bowl":
		var arena = game.ctx.boss.arena
		var angle := deg_to_rad(float(site.mast_angle_deg))
		target = arena.point_at(angle, Arena.MAST_R, float(site.target_lift_m))
		heading = Arena.tangent(angle)
		collider = arena.get_node_or_null("Bowl")
	else:
		var field: Node = game.find_child("Park_" + String(site.park_row), true, false)
		if field == null:
			return {}
		collider = field.get_node_or_null("Collider")
		if site.has("entry"):
			return {"target": _xyz(site.target), "eye": _xyz(site.eye), "entry": _xyz(site.entry),
				"heading": Vector3(site.bearing[0], 0, site.bearing[1]).normalized(), "collider": collider}
		var a: Array = site.bearing_from
		var b: Array = site.bearing_to
		heading = Vector3(b[0] - a[0], 0, b[1] - a[1]).normalized()
		# The span is a field of standing timbers. Aim at the nearest actual
		# timber to the station mark, which may itself be in the gap between two.
		if collider == null:
			return {}
		var mark: Vector3 = game.ctx.terrain.drop_point(site.target_xz[0], site.target_xz[1], site.target_lift_m)
		var nearest := INF
		for part: Dictionary in ParkRecipes.collider_shapes(collider):
			if part.disabled:
				continue
			var center: Vector3 = part.global_transform.origin
			if part.shape is ConvexPolygonShape3D:
				var points: PackedVector3Array = part.shape.points
				var box := AABB(points[0], Vector3.ZERO)
				for corner in points:
					box = box.expand(corner)
				center = part.global_transform * box.get_center()
			var distance := center.distance_squared_to(mark)
			if distance < nearest:
				target = center
				nearest = distance
		if nearest == INF:
			return {}
	var entry := target - heading * 8.0 + heading.cross(Vector3.UP) * 3.0 - Vector3.UP * 1.0
	return {"target": target, "entry": entry, "eye": entry - heading * 6.0 + Vector3.UP * 3.0,
		"heading": heading, "collider": collider}


func _take(pose: Dictionary, release_tick: int) -> Dictionary:
	var player = game.player
	var result := {"release_tick": release_tick, "status": "no hold"}
	player.reset_to(pose.entry, pose.heading * ENTRY_SPEED)
	var camera = game.camera
	camera.set_process(false)
	camera.arm.set_physics_process_internal(false)
	var mount := camera.cam.get_parent() as Node3D
	mount.global_transform = Transform3D(Basis.looking_at(pose.target - pose.eye, Vector3.UP), pose.eye)
	camera.cam.transform = Transform3D.IDENTITY
	game.aim_along(camera.aim_origin(), camera.aim_forward())
	source.press = {"harpoon_pressed": true}
	source.hold = {"harpoon_held": true}
	await game.get_tree().physics_frame
	if not player.kit.hooked:
		return result
	var point: Vector3 = player.kit.anchor
	var normal: Vector3 = player.kit.anchor_normal
	var query := PhysicsRayQueryParameters3D.create(point + normal * 0.1, point - normal * 0.15, 1)
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	# The bowl shares a single body between floor, ramps and masts. The face must
	# also be at the requested mast, and the flume must bite the recorded timber.
	if hit.get("collider") != pose.collider or hit.is_empty() or point.distance_to(pose.target) > 2.0:
		result["reason"] = "line caught a different face"
		return result
	result["bite_xyz"] = [point.x, point.y, point.z]
	source.hold["brake_held"] = true
	for tick in range(1, release_tick):
		await game.get_tree().physics_frame
		if not player.kit.hooked:
			result.status = "line broke before release"
			return result
	source.hold = {}
	source.press = {"harpoon_released": true}
	await game.get_tree().physics_frame
	if player.kit.hooked:
		result.status = "release missed"
		return result
	var body: RigidBody3D = player.body()
	result["exit_mps"] = body.linear_velocity.length()
	result["drop_m"] = pose.entry.y - player.ball_position().y
	for tick in LANDING_LIMIT:
		if player.state.grounded:
			var v := body.linear_velocity
			result["landing_mps"] = Vector2(v.x, v.z).length()
			result["landing_y"] = player.ball_position().y
			result.status = "landed"
			return result
		await game.get_tree().physics_frame
	result.status = "no landing"
	return result


func _xyz(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])
