extends SceneTree

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Arena := preload("res://src/boss/arena.gd")
const Quality := preload("res://src/presentation/graphics_preset.gd")
const AppShell := preload("res://src/core/app_shell.gd")

var game
var source := Intent.Scripted.new()
var out := ""
var section := "dam"
var rows := []
var drawn := false
var failed := false
var subject := Vector3.ZERO
var grown := false
var live := false
var contact_path := ""
var hook_body: StaticBody3D
var sites := {}
var waypoints := {}
var extras := {}
var landmark: Node3D
var watch_side: Camera3D
var damage_events := []
var chased_by := []
var view_rays := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--section="):
			section = arg.trim_prefix("--section=")
		elif arg == "--live":
			live = true
		elif arg == "--grown":
			grown = true
	if out.is_empty() or not section in ["dam", "flume", "bowl", "hook"] or DirAccess.make_dir_recursive_absolute(out) != OK:
		quit(2)
		return
	drawn = not AppShell.headless()
	_run.call_deferred()


func _run() -> void:
	seed(731)
	Quality.apply("high")
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	if drawn:
		watch_side = Camera3D.new()
		game.add_child(watch_side)
		watch_side.current = false
	game.ctx.calm = not live
	game.flow.force_warden = live
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.source = source
	await _ready_stage(1)
	if section != "dam":
		game.flow.enter_stage(2, Vector3.ZERO, false)
		await _ready_stage(2)
	game.run.set_max_hp(99999.0)
	game.ctx.events.player_hit.connect(func(amount, from): damage_events.append([from, amount]))
	game.get_node("Workshop").close_all()
	game.flow.start_card.hide_card()
	if grown:
		game.run.grant_start_mass(300.0)
	match section:
		"dam":
			await _road("eye-rim", [Vector2(-8, 130),
				Vector2(0, 165), Vector2(-15, 250), Vector2(-65, 285), Vector2(-100, 315),
				Vector2(-175, 347), Vector2(-202, 385), Vector2(-140, 416), Vector2(-106, 465),
				Vector2(-92, 502), Vector2(-45, 532), Vector2(-14, 555), Vector2(0, 575)])
			await _road("eye-incline", [Vector2(-8, 130),
				Vector2(0, 165), Vector2(-12, 250), Vector2(-30, 285), Vector2(-45, 330),
				Vector2(-25, 385), Vector2(0, 442), Vector2(8, 488), Vector2(12, 537),
				Vector2(0, 575)])
		"flume":
			for tree in root.find_children("Cottonwood*", "Node3D", true, false):
				if Vector2(tree.global_position.x, tree.global_position.z).distance_to(Vector2(40, 255)) < 65:
					extras[str(tree.get_path())] = _vec(tree.global_position)
			if live:
				await _road("live-wasteway", [Vector2(14, 220), Vector2(24, 255), Vector2(55, 300),
					Vector2(85, 335), Vector2(148, 418), Vector2(188, 438), Vector2(210, 452)])
			else:
				await _road("upper", [Vector2(14, 212),
					Vector2(40, 247), Vector2(70, 284), Vector2(124, 350), Vector2(207, 450)], true)
				await _road("kicker", [Vector2(14, 220), Vector2(40, 255), Vector2(70, 294), Vector2(124, 350), Vector2(207, 438)])
				await _road("lower", [Vector2(14, 220), Vector2(24, 255), Vector2(55, 300), Vector2(85, 335), Vector2(148, 418),
					Vector2(188, 438), Vector2(210, 452)])
				await _road("miss", [Vector2(14, 220), Vector2(47, 251), Vector2(58, 286), Vector2(85, 335), Vector2(148, 418),
					Vector2(188, 438), Vector2(210, 452)])
				await _road("upper-spill", [Vector2(14, 212), Vector2(53, 221), Vector2(78, 265),
					Vector2(85, 335), Vector2(148, 418), Vector2(188, 438), Vector2(210, 452)], true)
		"hook":
			await _hooks()
		"bowl":
			await _bowl()
	var f := FileAccess.open(out.path_join("paths.json"), FileAccess.WRITE)
	if f == null:
		printerr("Could not create paths.json in ", out)
		quit(2)
		return
	f.store_string(JSON.stringify({"section": section, "grown": grown, "live": live, "hz": Engine.physics_ticks_per_second, "targets": sites, "waypoints": waypoints, "fixtures": extras, "samples": rows}, " "))
	f.close()
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _bowl() -> void:
	game.ctx.calm = false
	source.hold = {"move": Vector2(0, 1)}
	var carried := Vector3(20, -2, 0)
	game.flow.enter_boss(carried)
	var boss = game.ctx.boss
	var arena = boss.arena
	for a in Arena.MAST_ANGLES:
		sites["mast-%03d" % int(a)] = _vec(arena.point_at(deg_to_rad(a), Arena.MAST_R, 4.0))
	for a in Arena.RAMP_ANGLES:
		sites["ramp-%03d" % int(a)] = _vec(arena.point_at(deg_to_rad(a), Arena.RAMP_FROM, 0.7))
		sites["ramp-top-%03d" % int(a)] = _vec(arena.point_at(deg_to_rad(a), Arena.RAMP_TO, Arena.RAMP_TOP + 0.5))
	for a in Arena.VENT_ANGLES:
		sites["vent-%03d" % int(a)] = _vec(arena.point_at(deg_to_rad(a), Arena.VENT_R, 1.2))
	extras["incoming_velocity"] = _vec(carried)
	extras["arrival_heading"] = _vec(arena.entry_heading())
	sites["entry"] = _vec(arena.entry_point())
	sites["bank"] = _vec(arena.point_at(deg_to_rad(290), 49, 0.7))
	for mode in ["entry", "reverse", "ramp", "mast", "slag", "slag-exposed", "charge"]:
		var heading: Vector3 = arena.entry_heading()
		if mode == "reverse":
			heading = -heading
		if mode != "entry":
			game.player.reset_to(arena.entry_point(), heading * 20.0)
			game.camera.snap(heading)
			source.press = {}
			source.hold = {"move": Vector2(0, 1)}
		if mode.begins_with("slag"):
			boss.jump_to_phase(2)
		if mode == "slag-exposed":
			var in_band: Vector3 = arena.point_at(deg_to_rad(245), (Arena.RING_A.x + Arena.RING_A.y) * 0.5, 1.0)
			game.player.reset_to(in_band, Vector3.ZERO)
			source.hold = {"move": Vector2.ZERO}
		if mode == "charge":
			boss.jump_to_phase(3)
		var ramp_marks := [arena.point_at(deg_to_rad(-30), 49.0), arena.point_at(deg_to_rad(-5), 51.0),
			arena.point_at(0, 50.0), arena.point_at(0, 24.0)]
		var ramp_goal := 0
		var first := -1
		var held := false
		for tick in (1080 if mode.begins_with("slag") or mode in ["charge", "ramp"] else 330):
			await physics_frame
			var ball: Vector3 = game.player.ball_position()
			var angle: float = arena.angle_of(ball)
			var side := -1.0 if mode == "reverse" else 1.0
			var track: Vector3 = ball + Arena.tangent(angle) * side * 14.0 - Arena.dir(angle) * (arena.radius_of(ball) - 48.0)
			if mode == "ramp":
				track = ramp_marks[ramp_goal]
				var gap := Vector2(track.x - ball.x, track.z - ball.z).length()
				if gap < (1.3 if ramp_goal == 2 else 3.0) and ramp_goal < ramp_marks.size() - 1:
					ramp_goal += 1
				if ramp_goal == 3 and ball.y > arena.global_position.y + 4.0 and gap < 10.0:
					await _shot("bowl-ramp-%04d" % tick)
					_sample("bowl-ramp", tick)
					extras["ramp_climb"] = _vec(ball - arena.global_position)
					break
			if mode == "mast" and tick > 22:
				var mast: Vector3 = arena.point_at(deg_to_rad(315), Arena.MAST_R, 8.0)
				var d: Vector3 = mast - game.camera.global_position
				_look(d, atan2(d.y, Vector2(d.x, d.z).length()))
				if not held and tick > 42 and game.player.kit.aim.get("state", 0) != 0:
					source.press["harpoon_pressed"] = true
					source.hold["harpoon_held"] = true
					held = true
				if tick == 170:
					source.hold.erase("harpoon_held")
					source.press["harpoon_released"] = true
			elif tick > 42 and mode != "slag-exposed":
				if mode == "ramp" and ramp_goal < 3:
					var distance := Vector2(track.x - ball.x, track.z - ball.z).length()
					_steer(track, clampf(distance * 1.3, 1.5, 15.0), 1.0)
				else:
					_steer(track)
			if first < 0 and ((mode == "charge" and boss.charge_coming()) or (mode.begins_with("slag") and boss.active_hazards().any(func(h): return h.attack_id.begins_with("slag")))):
				first = tick
			if tick in [1, 30, 115, 260] or (first >= 0 and tick in [first, first + 65, first + 240, first + 405]):
				await _shot("bowl-%s-%04d" % [mode, tick])
			if tick % 9 == 0:
				_sample("bowl-"+mode, tick)
			if first >= 0 and tick > first + 410:
				break


func _ready_stage(stage: int) -> void:
	for i in 2400:
		await physics_frame
		if game.ctx.terrain.is_ready(stage) and game.flow.in_play() and not game.player.frozen() and i > 180:
			break
		if i == 2399:
			failed = true
			printerr("Stage ", stage, " did not become playable")
	game.flow.start_card.hide_card()


func _start(p: Vector2, dir: Vector3, high := false) -> void:
	var pos: Vector3 = game.ctx.terrain.drop_point(p.x, p.y, 1.4)
	if high:
		var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, 120, p.y), pos, 1)
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			pos = hit.position + Vector3.UP * 1.1
			extras["upper_start_body"] = str(hit.collider.get_path())
	game.player.reset_to(pos, dir * 19.0)
	game.camera.snap(dir)
	source.press = {}
	source.hold = {"move": Vector2(0, 1)}
	for _tick in 8:
		await physics_frame
		if game.player.ball_position().distance_to(pos) < 2.0:
			break
	game.player.set_velocity_now(dir * 19.0)
	await physics_frame
	await physics_frame
	game.camera.snap(dir)


func _steer(point: Vector3, speed := 20.0, correction := 0.70) -> void:
	var d: Vector3 = point - game.player.ball_position()
	if Vector2(d.x, d.z).length() > 0.1:
		_look(d, -0.3)
	var velocity: Vector3 = game.player.planar_velocity()
	var wanted := Vector3(d.x, 0, d.z).normalized() * speed
	var drive := (wanted - velocity * correction).normalized()
	var basis: Basis = game.camera.yaw_basis()
	source.hold["move"] = Vector2(drive.dot(basis.x), -drive.dot(basis.z))


func _look(direction: Vector3, pitch: float) -> void:
	var yaw := atan2(-direction.x, -direction.z)
	var rig = game.camera
	var delta_yaw := clampf(wrapf(yaw - rig.yaw, -PI, PI), -0.055, 0.055)
	var delta_pitch := clampf(pitch - rig.pitch, -0.045, 0.045)
	rig.look(-Vector2(delta_yaw, delta_pitch) / rig.mouse_sensitivity)


func _road(label: String, marks: Array, high := false) -> void:
	if not waypoints.is_empty():
		var stage: int = game.run.stage
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		await _ready_stage(stage)
		game.get_node("Workshop").close_all()
		if grown:
			game.run.grant_start_mass(300.0)
	waypoints[label] = marks.map(func(pt): return [pt.x, pt.y])
	var map = game.ctx.terrain.map()
	landmark = game.ctx.terrain.geometry_root(game.run.stage).find_child("Landmark_" + String(map.park.landmark.id), true, false)
	var top: Array = map.park.landmark.get("sight_top", [])
	if top.size() == 3:
		sites["landmark"] = top
		var centre: Array = map.park.landmark.at
		var height: float = map.park.landmark["size"][1]
		sites["landmark-face"] = [centre[0], height * 0.5, centre[1]]
		sites["landmark-foot"] = [centre[0], height * 0.15, centre[1]]
	for idx in range(1, marks.size()):
		var mark: Vector2 = marks[idx]
		var pos: Vector3 = game.ctx.terrain.drop_point(mark.x, mark.y, 0.6)
		if high:
			var q := PhysicsRayQueryParameters3D.create(Vector3(mark.x, 120, mark.y), pos, 1)
			var ray: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
			if not ray.is_empty():
				pos = ray.position + Vector3.UP * 0.6
		sites["%s-%d" % [label, idx]] = _vec(pos)
	var p: Vector2 = marks[0]
	var next: Vector2 = marks[1]
	var h := (next - p).normalized()
	await _start(p, Vector3(h.x, 0, h.y), high)
	var goal := 1
	for tick in 4200:
		await physics_frame
		var ball: Vector3 = game.player.ball_position()
		var at := Vector2(ball.x, ball.z)
		next = marks[goal]
		_steer(Vector3(next.x, ball.y, next.y))
		if label == "upper-spill" and tick in [18, 72, 155] and game.player.state.grounded:
			source.press["jump_pressed"] = true
		var leg: Vector2 = next - Vector2(marks[goal - 1])
		var across := absf(leg.normalized().cross(at - next))
		var reached := at.distance_to(next) < 7 or ((at - next).dot(leg) >= 0.0 and across < 27.0)
		if tick in [9, 135, 360] or reached:
			await _shot("%s-%02d-%04d" % [label, goal, tick])
		if tick % 9 == 0:
			_sample(label, tick)
		if reached:
			goal += 1
			if goal == marks.size():
				if not game.player.state.grounded:
					for settle in range(1, 400):
						await physics_frame
						if settle % 3 == 0:
							_sample(label, tick + settle)
						if game.player.state.grounded:
							_sample(label, tick + settle)
							await _shot("%s-land-%04d" % [label, tick + settle])
							break
				break
	extras[label + "_waypoints_passed"] = goal - 1
	print("ROUTE ", label, " passed ", goal - 1, "/", marks.size() - 1, " waypoints")


func _hooks() -> void:
	var field: Node3D = root.find_child("Park_hollow_trestles", true, false)
	# Pick a real hull halfway up a timber. Some render drivers return identity for
	hook_body = field.get_node("Collider")
	var nearest := INF

	var hollow := Vector2(-185, 10)
	var down := Vector2(sin(deg_to_rad(14)), cos(deg_to_rad(14)))
	var bank := Vector2(down.y, -down.x)
	for part: Dictionary in ParkRecipes.collider_shapes(field.get_node("Collider")):
		var shape = part.shape
		var pose: Transform3D = part.global_transform
		var centre: Vector3 = pose.origin
		if shape is ConvexPolygonShape3D:
			var box := AABB(shape.points[0], Vector3.ZERO)
			for point: Vector3 in shape.points:
				box = box.expand(point)
			centre = pose * box.get_center()
		var lift: float = centre.y - game.ctx.terrain.height(centre.x, centre.z)
		if lift < 4.0 or lift > 12.0:
			continue
		var local := Vector2(centre.x, centre.z) - hollow
		var along := local.dot(down)
		var across := local.dot(bank)
		if absf(along) > 134.0:
			continue
		var score := absf(absf(across) - 20.0) + absf(lift - 8.0) * 0.25
		if score < nearest:
			nearest = score
			subject = centre
	if nearest == INF:
		printerr("No standing hook face on hollow_trestles")
		quit(1)
		return
	sites["trestle"] = _vec(subject)
	sites["receiving-bank"] = _vec(game.ctx.terrain.drop_point(-186, -57, 0.8))
	sites["receiving-slope"] = _vec(game.ctx.terrain.drop_point(-167, -116, 0.9))
	for pos in [Vector2(-171, -125), Vector2(-162, -111), Vector2(-173, -90), Vector2(-181, -70)]:
		sites["return-%d" % int(-pos.y)] = _vec(game.ctx.terrain.drop_point(pos.x, pos.y, 0.9))
	var skyline: Array = game.ctx.terrain.map().park.landmark["sight_top"]
	sites["tower"] = skyline
	print("HOLLOW POST ", subject)
	for mode in ["roll", "hook", "miss", "early", "late", "reverse", "chase"]:
		var h := Vector3(down.x, 0, down.y)
		if mode == "reverse":
			h = -h
		var start := subject - h * 31.0 - h.cross(Vector3.UP) * 6.0
		contact_path = ""
		await _start(Vector2(start.x, start.z), h)
		for lead in range(-69, 0):
			await physics_frame
			_look(h + h.cross(Vector3.UP) * 0.18, -0.19)
			var basis: Basis = game.camera.yaw_basis()
			source.hold.move = Vector2(h.dot(basis.x), -h.dot(basis.z))
			if lead == -48:
				await _shot("lead-%s-048" % mode)
			if lead % 3 == 0:
				_sample(mode, lead)
		if mode == "chase":
			game.ctx.calm = false
			for offset in [Vector2(-4, -9), Vector2(5, 24), Vector2(9, 30)]:
				var at: Vector3 = game.player.ball_position() + h * offset.y + h.cross(Vector3.UP) * offset.x
				var foot: Vector3 = game.ctx.terrain.drop_point(at.x, at.z, 0.8)
				var enemy = game.ctx.spawner.spawn_enemy("chaser", foot)
				if enemy != null:
					chased_by.append(weakref(enemy))
		var release := 80 if mode=="early" else 145 if mode=="late" else 110
		for tick in 680:
			await physics_frame
			var ball: Vector3 = game.player.ball_position()
			var rig = game.camera
			if tick < 40:
				var d: Vector3 = subject - rig.global_position
				if mode == "miss":
					d = h + Vector3.DOWN * 4.0
				_look(d, atan2(d.y, Vector2(d.x, d.z).length()))
			else:
				var to_trough := h + h.cross(Vector3.UP) * 1.05 if tick > release else h
				_steer(ball + to_trough * 15.0)
			var basis: Basis = rig.yaw_basis()
			if tick <= release:
				source.hold.move = Vector2(h.dot(basis.x), -h.dot(basis.z))
			if tick == 35 and mode != "roll":
				source.press["harpoon_pressed"] = true
				source.hold["harpoon_held"] = true
			if tick == 38 and game.player.kit.hooked:
				var bit: Vector3 = game.player.kit.anchor
				var n: Vector3 = game.player.kit.anchor_normal
				var query := PhysicsRayQueryParameters3D.create(bit + n * 0.15, bit - n * 0.2, 1)
				var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty():
					contact_path = str(hit.collider.get_path())
				source.hold["brake_held"] = true
			if tick == release:
				source.hold.erase("brake_held")
				source.hold.erase("harpoon_held")
				source.press["harpoon_released"] = true
			if tick in [15, 30, 42, release + 1, 215, 575]:
				await _shot("trestle-%s-%03d" % [mode, tick])
				if mode == "hook":
					await _side("side-%s-%03d" % [mode, tick], h)
			if tick % 3 == 0:
				_sample(mode, tick)
		if mode in ["hook", "early", "late", "reverse", "chase"] and contact_path.is_empty():
			failed = true
			printerr("No actual timber contact for ", mode)


func _sample(label: String, tick: int) -> void:
	var p: Vector3 = game.player.ball_position()
	var v: Vector3 = game.player.body().linear_velocity
	var kit = game.player.kit
	var clearances := {}
	if section == "hook":
		var world: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
		for ray in [["post", subject], ["underside", p + Vector3.UP * 80.0]]:
			var query := PhysicsRayQueryParameters3D.create(p, ray[1], 1, [game.player.body().get_rid()])
			var hit := world.intersect_ray(query)
			if not hit.is_empty() and (ray[0] == "underside" or hit.collider == hook_body):
				clearances[ray[0]] = snappedf(p.distance_to(hit.position) - Tuning.RADIUS, 0.01)
	var chase := []
	for ref: WeakRef in chased_by:
		var enemy = ref.get_ref()
		if is_instance_valid(enemy):
			chase.append([enemy.get_instance_id(), _vec(enemy.global_position)])
	var threats := []
	if section == "bowl":
		for hazard in game.ctx.boss.active_hazards():
			threats.append([hazard.attack_id, hazard.state, hazard.contains(p)])
	var view := _visible_sites()
	var gate = game.flow.gate
	var lock_state: String = gate.lock_state if gate != null else ""
	var yard_crew: int = gate.crew_alive().size() if gate != null and gate.lock_active() else 0
	rows.append({"damage": damage_events.duplicate(), "chase": chase, "clearances": clearances, "yard": lock_state, "crew": yard_crew, "threats": threats, "hp": game.run.hp, "trial": label, "tick": tick, "position": _vec(p), "velocity": _vec(v), "ground": game.player.state.grounded,
		"contact": contact_path, "input": [source.hold.get("move", Vector2.ZERO).x, source.hold.get("move", Vector2.ZERO).y, source.hold.get("harpoon_held", false), source.hold.get("brake_held", false)],
		"view": view, "view_rays": view_rays.duplicate(), "yaw": game.camera.yaw, "pitch": game.camera.pitch, "cam": _vec(game.camera.cam.global_position),
		"enemies": get_nodes_in_group("enemy").size(), "stage": game.run.stage, "frozen": game.player.frozen(), "hooked": kit.hooked, "anchor": _vec(kit.anchor), "rope": kit.rope, "heft": game.player.heft()})
	damage_events.clear()


func _visible_sites() -> Array:
	var visible := []
	view_rays.clear()
	var cam: Camera3D = game.camera.cam
	for key in sites:
		var coords: Array = sites[key]
		var p := Vector3(coords[0], coords[1], coords[2])
		if cam.is_position_in_frustum(p):
			var query := PhysicsRayQueryParameters3D.create(cam.global_position, p, 1)
			var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and (key in ["trestle", "receiving-slope", "receiving-bank", "ramp-000", "landmark", "landmark-face"]):
				view_rays[key] = [str(hit.collider.name), _vec(hit.position)]
			var sees_ramp := false
			if not hit.is_empty() and String(key).begins_with("ramp-") and hit.collider.name == "Bowl":
				var angle := deg_to_rad(float(String(key).get_slice("-", String(key).get_slice_count("-") - 1)))
				var local: Vector3 = hit.position - game.ctx.boss.arena.global_position
				var depth := Arena.RAMP_FROM - local.dot(Arena.dir(angle))
				var length := Arena.RAMP_FROM - Arena.RAMP_TO
				sees_ramp = depth >= -0.05 and depth <= length + 0.05 \
					and absf(local.dot(Arena.tangent(angle))) <= Arena.RAMP_HALF_WIDTH + 0.05 \
					and local.y >= -0.05 and local.y <= Arena.RAMP_TOP * depth / length + 0.05
			var sees_landmark: bool = not hit.is_empty() and String(key).begins_with("landmark") and is_instance_valid(landmark) and landmark.is_ancestor_of(hit.collider)
			if hit.is_empty() or sees_landmark or sees_ramp or (key == "trestle" and hit.collider == hook_body and hit.position.distance_to(p) < 5.0) or p.distance_to(hit.position) <= (1.25 if String(key).begins_with("mast-") else 0.9):
				visible.append(key)
	return visible


func _vec(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


func _side(label: String, heading: Vector3) -> void:
	if not drawn:
		return
	var ball: Vector3 = game.player.ball_position()
	var centre := (ball + subject) * 0.5
	var side := heading.cross(Vector3.UP)
	var eye := centre + side * 24.0 + Vector3.UP * 4.0
	eye.y = maxf(eye.y, game.ctx.terrain.height(eye.x, eye.z) + 2.0)
	watch_side.global_position = eye
	watch_side.look_at(centre)
	watch_side.fov = 75
	watch_side.make_current()
	await _shot(label)
	game.camera.cam.make_current()


func _shot(label: String) -> void:
	if drawn:
		paused = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(out.path_join(label + ".jpg"), 0.86)
		paused = false
