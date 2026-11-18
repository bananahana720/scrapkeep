extends SceneTree

# A placed, level 14 m/s entry. Only the release tick changes between takes.
# The original flume trial held for 75 ticks after its bite. Compare every earlier
# tick and report horizontal speed at the first grounded tick after letting go.
const STATIONS := "res://tools/stations/W1-135.json"
const ENTRY_SPEED := 14.0
const HOLD_TICKS := 75
const LANDING_LIMIT := 360
const Rules := preload("res://src/movement/ball_rules.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Arena := preload("res://src/boss/arena.gd")
const Intent := preload("res://src/movement/intent.gd")

const Game := preload("res://src/game.gd")

var game
var source := Intent.Scripted.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(731)
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.flow.force_warden = false
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.source = source
	var stations: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STATIONS))
	var station_ids := stations.keys()
	station_ids.sort_custom(func(a, b): return int(stations[a].hook_order) < int(stations[b].hook_order))
	var rows := []
	for id: String in station_ids:
		var site: Dictionary = stations[id]
		if int(site.stage) != game.run.stage:
			game.flow.enter_stage(int(site.stage), Vector3.ZERO, false)
		if not await _ready_stage(int(site.stage)):
			printerr("Hook station %s could not enter stage %s" % [id, site.stage])
			quit(1)
			return
		if site.has("mast_angle_deg"):
			game.flow.enter_boss(Vector3.ZERO)
			# Isolate the swing from Brindle's ordnance while leaving the real bowl in physics.
			game.ctx.boss.set_physics_process(false)
		game.run.set_max_hp(99999.0)
		rows.append(await measure(id, site, OS.get_environment("PLANT") == "no_bite" and id == "flume_hollow_trestles"))
	print("HOOK_SITES ", JSON.stringify(rows))
	game.free()
	await process_frame
	quit(0)


func _ready_stage(stage: int) -> bool:
	for tick in 1200:
		await physics_frame
		if game.ctx.terrain.is_ready(stage) and game.flow.in_play() and not game.player.frozen():
			game.flow.start_card.hide_card()
			return true
	return false


func measure(id: String, site: Dictionary, no_bite: bool) -> Dictionary:
	var pose := _station(site)
	var row := {"site": id, "status": "no hold"}
	if pose.is_empty():
		row.status = "invalid setup"
		return row
	if no_bite:
		# Move the approach beyond rope range. The ordinary aim and fire decide the result.
		var away: Vector3 = (pose.entry - pose.target).normalized() * (game.player.grapple_range() + 5.0)
		pose.entry += away
		pose.eye += away
	row["target_xyz"] = [pose.target.x, pose.target.y, pose.target.z]
	row["entry_xyz"] = [pose.entry.x, pose.entry.y, pose.entry.z]
	row["gravity_mps2"] = float(ProjectSettings.get_setting("physics/3d/default_gravity")) * game.player.body().gravity_scale
	var held := await _take(pose, HOLD_TICKS)
	row["held"] = held
	if held.status != "landed":
		row.status = held.status
		return row
	var best := {}
	var worst_energy := float(held.exit_energy_residual)
	var early_surfaces := {}
	for tick in range(1, HOLD_TICKS):
		var early := await _take(pose, tick)
		if early.status != "landed":
			row.status = "incomplete early trial"
			row["early"] = early
			return row
		if not early.tier.is_empty():
			early_surfaces[early.tier] = true
		worst_energy = maxf(worst_energy, early.exit_energy_residual)
		if best.is_empty() or early.landing_mps > best.landing_mps:
			best = early
	row["best_early"] = best
	row["worst_exit_energy_residual"] = worst_energy
	row["held_only_tier"] = not held.tier.is_empty() and not early_surfaces.has(held.tier)
	row["early_tiers"] = early_surfaces.keys()
	row["early_trials"] = HOLD_TICKS - 1
	row.status = "measured"
	return row


func _station(site: Dictionary) -> Dictionary:
	var target := _xyz(site.point)
	var entry := _xyz(site.ball_position)
	var heading := _xyz(site.ball_velocity).normalized()
	var expected: Node3D
	if site.has("mast_angle_deg"):
		var arena = game.ctx.boss.arena
		target = arena.global_position + _xyz(site.bowl_target_local)
		entry = arena.global_position + _xyz(site.bowl_entry_local)
		expected = arena.get_node_or_null("Bowl")
	else:
		expected = game.find_child("Park_" + String(site.park_row), true, false)
		if site.terrain_relative:
			target.y += game.ctx.terrain.height(target.x, target.z)
			entry.y += game.ctx.terrain.height(entry.x, entry.z)
	if expected == null:
		return {}
	var eye := _xyz(site.eye) if site.has("eye") else entry - heading * 6.0 + Vector3.UP * 3.0
	return {"target": target, "entry": entry, "eye": eye, "heading": heading, "expected": expected,
		"stamped": site.get("stamped", false), "tiers": site.get("tiers", []), "bowl": site.has("mast_angle_deg")}


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
	var intended := false
	if not hit.is_empty():
		intended = hit.collider == pose.expected or pose.expected.is_ancestor_of(hit.collider)
		if pose.stamped:
			intended = hit.collider.name.begins_with("Tile")
	if not intended or point.distance_to(pose.target) > 2.0:
		result["reason"] = "line caught a different face"
		result["hit_xyz"] = [point.x, point.y, point.z]
		return result
	result["bite_xyz"] = [point.x, point.y, point.z]
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
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity")) * body.gravity_scale
	result["exit_energy_residual"] = body.linear_velocity.length_squared() - (ENTRY_SPEED * ENTRY_SPEED + 2.0 * gravity * result.drop_m)
	for tick in LANDING_LIMIT:
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		for i in state.get_contact_count():
			var floor_body = state.get_contact_collider_object(i)
			if not Rules.world_face(floor_body) or state.get_contact_local_normal(i).y <= Tuning.MAX_SLOPE_DOT:
				continue
			var at := state.get_contact_collider_position(i)
			var v := state.linear_velocity
			result["landing_mps"] = Vector2(v.x, v.z).length()
			result["landing_xyz"] = [at.x, at.y, at.z]
			result["landing_surface"] = str(game.get_path_to(floor_body))
			result["landing_shape"] = state.get_contact_collider_shape(i)
			result["tier"] = _tier(pose, floor_body, at)
			result.status = "landed"
			return result
		await game.get_tree().physics_frame
	result.status = "no landing"
	return result


# Only a named ledge/deck with a walkable contact counts. In the bowl the
# deck and floor share one body, so check the raised end of the actual ramp.
func _tier(pose: Dictionary, surface: Node3D, at: Vector3) -> String:
	if pose.bowl:
		var arena = game.ctx.boss.arena
		if surface != pose.expected:
			return ""
		for degrees in Arena.RAMP_ANGLES:
			var angle := deg_to_rad(float(degrees))
			var deck: Vector3 = arena.point_at(angle, Arena.RAMP_TO, Arena.RAMP_TOP)
			var rel := at - deck
			if absf(rel.dot(Arena.tangent(angle))) <= Arena.RAMP_HALF_WIDTH and absf(rel.dot(Arena.dir(angle))) <= 1.0 and absf(rel.y) <= 0.5:
				return "bowl_ramp_%d" % degrees
	else:
		for id in pose.tiers:
			var ledge := game.find_child("Park_" + String(id), true, false) as Node3D
			if ledge != null and (ledge == surface or ledge.is_ancestor_of(surface)):
				return id
	return ""


func _xyz(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])
