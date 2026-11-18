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
const Stamps := preload("res://src/world/park/park_stamps.gd")
const Arena := preload("res://src/boss/arena.gd")
const Intent := preload("res://src/movement/intent.gd")
const Game := preload("res://src/game.gd")

var game
var source := Intent.Scripted.new()
var bite_state := {}
var release_state := {}


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
	game.events.grapple_fired.connect(func(_anchor): bite_state = _motion())
	game.events.grapple_released.connect(func(): release_state = _motion())
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
	var worst_energy_trial := held
	var excess_by_tick := {}
	_record_excess(held, excess_by_tick)
	var early_surfaces := {}
	for tick in range(1, HOLD_TICKS):
		var early := await _take(pose, tick)
		if early.status != "landed":
			row.status = "incomplete early trial"
			row["early"] = early
			return row
		for tier in early.tiers:
			early_surfaces[tier] = true
		_record_excess(early, excess_by_tick)
		if early.exit_energy_residual > worst_energy_trial.exit_energy_residual:
			worst_energy_trial = early
		if best.is_empty() or early.landing_mps > best.landing_mps:
			best = early
	# A moving stage or leftover contact must not choose the winner. Repeat
	# both entries after traversing the whole schedule, in reverse order.
	var repeat_early := await _take(pose, int(best.release_tick))
	var repeat_held := await _take(pose, HOLD_TICKS)
	row["repeat_early"] = repeat_early
	row["repeat_held"] = repeat_held
	row["best_early"] = best
	row["worst_exit_energy_residual"] = worst_energy_trial.exit_energy_residual
	row["worst_energy_tick"] = worst_energy_trial.release_tick
	row["exit_excess_by_tick"] = excess_by_tick
	row["held_only_tier"] = held.tiers.any(func(tier): return not early_surfaces.has(tier))
	row["early_tiers"] = early_surfaces.keys()
	row["early_trials"] = HOLD_TICKS - 1
	row.status = "measured" if _same_landing(held, repeat_held) and _same_landing(best, repeat_early) else "inconsistent repeat"
	return row


# A negative residual is within the gravity bound. Only excess can spend the
# stock allowance for this site and this release tick.
func _record_excess(trial: Dictionary, by_tick: Dictionary) -> void:
	if trial.exit_energy_residual > 0.0:
		by_tick[str(trial.release_tick)] = trial.exit_energy_residual


static func added_excess(observed: Dictionary, stock: Dictionary) -> float:
	var largest := 0.0
	for tick in observed:
		largest = maxf(largest, float(observed[tick]) - float(stock.get(tick, 0.0)))
	return largest


func _same_landing(first: Dictionary, repeat: Dictionary) -> bool:
	return repeat.status == "landed" and first.landing_surface == repeat.landing_surface and first.tiers == repeat.tiers \
		and absf(first.landing_mps - repeat.landing_mps) <= 0.01


func _station(site: Dictionary) -> Dictionary:
	var target := _xyz(site.point)
	var entry := _xyz(site.ball_position)
	var heading := _xyz(site.ball_velocity).normalized()
	var expected: Node3D
	var ridge := {}
	if site.has("mast_angle_deg"):
		var arena = game.ctx.boss.arena
		target = arena.global_position + _xyz(site.bowl_target_local)
		entry = arena.global_position + _xyz(site.bowl_entry_local)
		expected = arena.get_node_or_null("Bowl")
	else:
		expected = game.find_child("Park_" + String(site.park_row), true, false)
		if site.get("stamped", false):
			for feature in game.ctx.terrain.map().park.park_rows:
				if feature.id == site.park_row and feature.get("fit") == "drape" and feature.stamp == "ridge":
					ridge = Stamps.frame(feature)
					break
			if ridge.is_empty():
				return {}
		if site.terrain_relative:
			target.y += game.ctx.terrain.height(target.x, target.z)
			entry.y += game.ctx.terrain.height(entry.x, entry.z)
	if expected == null:
		return {}
	var eye := _xyz(site.eye) if site.has("eye") else entry - heading * 6.0 + Vector3.UP * 3.0
	return {"target": target, "entry": entry, "eye": eye, "heading": heading, "expected": expected,
		"ridge": ridge, "tiers": site.get("tiers", []), "bowl": site.has("mast_angle_deg")}


# Both event callbacks run inside the player physics tick. Its movement state
# includes any velocity set on release before the rigid body integrates again.
func _motion() -> Dictionary:
	return {"speed": game.player.state.velocity.length(), "y": game.player.ball_position().y}


func _take(pose: Dictionary, release_tick: int) -> Dictionary:
	var player = game.player
	var result := {"release_tick": release_tick, "status": "no hold"}
	bite_state = {}
	release_state = {}
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
		if not pose.ridge.is_empty():
			intended = hit.collider.name.begins_with("Tile") and Stamps.offset(pose.ridge, point.x, point.z) > 0.0
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
	if bite_state.is_empty() or release_state.is_empty():
		result.status = "missing bite or release event"
		return result
	result["entry_mps"] = bite_state.speed
	result["entry_y"] = bite_state.y
	result["exit_mps"] = release_state.speed
	result["exit_y"] = release_state.y
	result["drop_m"] = bite_state.y - release_state.y
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity")) * body.gravity_scale
	result["exit_energy_residual"] = release_state.speed ** 2 - (bite_state.speed ** 2 + 2.0 * gravity * result.drop_m)
	for tick in LANDING_LIMIT:
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		var landing := _landing(pose, state)
		if not landing.is_empty():
			result.merge(landing)
			result.status = "landed"
			return result
		await game.get_tree().physics_frame
	result.status = "no landing"
	return result


# Physics contact order can change at a seam. Take every tier the ball touched
# on its first walkable tick and select a stable surface for the printed detail.
func _landing(pose: Dictionary, state: PhysicsDirectBodyState3D) -> Dictionary:
	var tiers := []
	var landing := {}
	var key := ""
	for i in state.get_contact_count():
		var surface = state.get_contact_collider_object(i)
		if not Rules.world_face(surface) or state.get_contact_local_normal(i).y <= Tuning.MAX_SLOPE_DOT:
			continue
		var at := state.get_contact_collider_position(i)
		var tier := _tier(pose, surface, at)
		if not tier.is_empty() and not tiers.has(tier):
			tiers.append(tier)
		var path := str(game.get_path_to(surface))
		var shape := state.get_contact_collider_shape(i)
		var contact_key := "%s/%d/%s" % [path, shape, at]
		if landing.is_empty() or contact_key < key:
			key = contact_key
			landing = {"landing_surface": path, "landing_shape": shape, "landing_xyz": [at.x, at.y, at.z]}
	if not landing.is_empty():
		tiers.sort()
		landing["tiers"] = tiers
		landing["landing_mps"] = Vector2(state.linear_velocity.x, state.linear_velocity.z).length()
	return landing


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
			# A draped ledge has no separate body. The terrain under this
			# authored plateau rises by the stamp's height within its footprint.
			if surface.name.begins_with("Tile"):
				for feature in game.ctx.terrain.map().park.park_rows:
					if feature.id == id and feature.get("fit") == "drape" and feature.stamp == "plateau":
						if Stamps.inside(Stamps.frame(feature), at.x, at.z) and feature.size[1] > 0:
							return id
	return ""


func _xyz(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])
