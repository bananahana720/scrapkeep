extends SceneTree

## Compare first commitments on the flume kicker approach and the dam yard's drop arc.
## Run with --script res://tools/spillway_crew_trial.gd -- --trial=stock|flank|lobber|boom|yard|arrivals
## --out=/absolute/dir. Add --pictures in a drawn run to keep the 720p chase frames.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Budget := preload("res://src/combat/attack_budget.gd")
const Pressure := preload("res://src/combat/pack_pressure.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const Director := preload("res://src/world/director.gd")
const SIPHON := Vector2(-21.7, 186.3)
const KICKER := Vector2(40, 255)
const LOWER := Vector2(85, 335)
const UPPER := Vector2(124.1, 349.9)
const LockRows := preload("res://src/world/lock_rows.gd")
const CASES := ["stall", "straight", "turn", "ram", "grown"]
var game
var trial := ""
var out := ""
var pictures := false
var rows: Array = []
var first := {}
var only_case := ""
var tick := 0
var case_id := ""
var wanted_shot := ""
var observed: Array = []
var tell := false
var events: Array = []

# Observe the branch that returned the position without consuming another random draw.
class Placement extends Director:
	var source := ""
	var shift_home := false
	var shift_line := false
	var wasteway_seats := 0
	var seating := false

	func _home_pack_spots(kinds: Array, ball: Vector2, side: Vector2, riders := {}) -> Dictionary:
		seating = true
		var seats := super._home_pack_spots(kinds, ball, side, riders)
		seating = false
		return seats

	func _home_at(home: Dictionary) -> Vector2:
		if seating and shift_home and home.id == "wasteway_chasers":
			# Same chute, on the west side visible past the entry kicker.
			return Vector2(75.47, 342.29)
		return super._home_at(home)

	func _try_nearer_bearing(spot: Vector2, ball: Vector2, heading: Vector2) -> Vector2:
		var offset := spot - ball
		var angle := heading.angle_to(offset)
		# Move just outside the same side of the chosen line. Check all of the director's
		# safety rules again on this experimental position, leaving the RNG untouched.
		if absf(angle) <= deg_to_rad(22.0):
			return spot
		var candidate := ball + heading.rotated(signf(angle) * deg_to_rad(22.0)) * offset.length()
		if play_rect.has_point(candidate) and _park_safe(candidate):
			for line in _corridors.pilot_lines():
				for i in range(1, line.size()):
					var nearest := Geometry2D.get_closest_point_to_segment(candidate, line[i-1], line[i])
					if candidate.distance_to(nearest) <= LINE_SIDE.y:
						return candidate
		return spot

	func _line_spot(ball: Vector2, heading: Vector2) -> Vector2:
		var spot := super._line_spot(ball, heading)
		source = "free-line" if spot.is_finite() else "free-ahead"
		return _try_nearer_bearing(spot, ball, heading) if shift_line and spot.is_finite() else spot

	func _home_spot(home: Dictionary, ball: Vector2, preferred := Vector2.ZERO, assigned: Array[Vector2] = []) -> Vector2:
		var spot := super._home_spot(home, ball, preferred, assigned)
		if spot.is_finite():
			source = String(home.id)
			if seating and home.id == "wasteway_chasers":
				wasteway_seats += 1
		return spot


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--trial="):
			trial = arg.trim_prefix("--trial=")
		if arg.begins_with("--case="):
			only_case = arg.trim_prefix("--case=")
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	pictures = "--pictures" in OS.get_cmdline_user_args()
	if trial not in ["stock", "flank", "lobber", "boom", "yard", "arrivals", "motion", "home", "crossing"] or out.is_empty() \
			or DirAccess.make_dir_recursive_absolute(out) != OK:
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	if pictures:
		root.size = Vector2i(1280, 720)
		root.content_scale_size = root.size
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	if trial == "arrivals":
		await _boot()
		await _arrivals()
		if pictures:
			await _arrival_stills()
		game.free()
	elif trial == "home":
		await _boot()
		await _home_reveal()
		game.free()
	elif trial == "crossing":
		for approach in ["light", "grown", "slow", "outside"]:
			await _boot()
			await _crossing(approach)
			game.free()
			await process_frame
	elif trial == "motion":
		await _boot()
		await _motion()
		game.free()
	else:
		for approach in (["stock", "alternate"] if trial == "yard" else CASES):
			if only_case != "" and approach != only_case:
				continue
			await _boot()
			case_id = approach
			if trial == "yard":
				await _yard(approach == "alternate")
			else:
				await _pass(approach)
			game.free()
			await process_frame
	var file := FileAccess.open(out.path_join(trial + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	file.close()
	print("CREW_TRIAL ", trial, " ", rows.size(), " rows")
	quit()


func _boot() -> void:
	seed(1)
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.player.source = Intent.Scripted.new()
	game.ctx.calm = true
	if "--comfort" in OS.get_cmdline_user_args():
		game.set_reduced_motion(true)
		game.set_reduce_flashes(true)
	game.ctx.rng.seed = 1
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999)
	game.presentation.juice.hit_stop_sink = func(_s): pass
	if trial != "yard":
		game.flow.enter_stage(2, Vector3.ZERO, false)
	for i in (420 if pictures else 10):
		await physics_frame
	for enemy in get_nodes_in_group("enemy"):
		if not enemy.is_in_group("harpoon_anchor"):
			enemy.queue_free()
	await physics_frame


func _point(xz: Vector2, above: float) -> Vector3:
	return game.ctx.terrain.drop_point(xz.x, xz.y, above)


func _watch(enemy) -> void:
	var who := "%s-%d" % [enemy.kind, observed.size()]
	observed.append(weakref(enemy))
	enemy.attack_phase.connect(func(fact: Dictionary):
		if fact.phase in ["windup", "strike", "recover", "cancelled"]:
			_note(who, fact.phase, enemy))
	enemy.hit_player.connect(func(_damage, _shove): _note(who, "hit", enemy))
	if enemy.has_signal("pressure_cue"):
		enemy.pressure_cue.connect(func(_cue, _at, _seconds): _note(who, "call", enemy))
	if enemy.has_signal("fired"):
		enemy.fired.connect(func(origin, landing, flight):
			_note(who, "shell", enemy)
			events.append({"tick": tick, "origin": str(origin), "landing": str(landing), "flight": flight}))


func _note(who: String, phase: String, enemy) -> void:
	var key := who + "-" + phase
	if first.has(key):
		return
	first[key] = tick
	if wanted_shot.is_empty():
		wanted_shot = key
	if phase == "windup":
		tell = true
	var cam: Camera3D = game.camera.cam
	var ball: Vector3 = game.player.ball_position()
	var at: Vector3 = enemy.global_position
	var lane = enemy.telegraph()
	var heading: Vector3 = game.player.planar_velocity().normalized()
	events.append({"who": who, "phase": phase, "tick": tick, "ball": str(ball), "at": str(at),
		"geometry": str(lane.descriptor()) if is_instance_valid(lane) else "",
		"inside_lane": lane.contains(ball) if is_instance_valid(lane) else false,
		"inside_view": cam.is_position_in_frustum(at), "forward_m": (at - ball).dot(heading),
		"speed": game.player.planar_velocity().length(), "attack_slots": Budget.attackers(self)})


func _shot(label: String) -> void:
	if not pictures:
		return
	paused = true
	for i in 2:
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out.path_join("%s-%s-%s.jpg" % [trial, case_id, label]), 0.9)
	paused = false


func _pass(approach: String) -> void:
	first = {}
	events = []
	observed = []
	tell = false
	tick = 0
	var bearing := SIPHON.direction_to(KICKER)
	var along := Vector3(bearing.x, 0, bearing.y)
	var side := Vector2(-bearing.y, bearing.x)
	var ram := approach in ["ram", "grown"]
	var start := KICKER - bearing * 44.0
	var target := start + bearing * (8.0 if approach == "stall" else 28.0)
	game.player.reset_to(_point(start, 1.4))
	game.player.body().freeze = true
	game.camera.snap(along)
	game.combat.heft_override = 4.0 if approach == "grown" else 1.0
	game.player.heft_of = func(): return game.combat.heft_override
	var kinds := ["chaser", "chaser"] if trial in ["stock", "flank"] else ["boom_tender" if trial == "boom" else "lobber"]
	if trial == "flank":
		ChallengeDials.set_overrides(ChallengeDials.parse(Pressure.tune_spec("C")))
	for index in kinds.size():
		var offset := (0.0 if ram else 3.5) if index == 0 else -5.0
		if trial == "lobber":
			offset = 12.0
		if trial == "boom":
			offset = 2.0
		var enemy = game.combat.spawn_enemy(kinds[index], _point(target + side * offset, 2.4))
		enemy.set_meta("pack_seq", 908)
		_watch(enemy)
	ChallengeDials.set_overrides({})
	for i in 36:
		await physics_frame
	var v := 0.0 if approach == "stall" else (14.0 if approach == "straight" else 28.0)
	game.player.body().freeze = approach == "stall"
	game.player.reset_to(_point(start, 1.25), along * v)
	game.camera.snap(along)
	if v > 0:
		game.player.source.hold = {"move": Vector2(0, 1)}
	var turned := false
	var trace := []
	var hp: float = game.run.hp
	var first_view := {}
	await _shot("approach")
	for i in 630:
		tick = i
		if approach == "turn" and tell and not turned:
			game.player.source.hold = {"move": Vector2(1, 0)}
			turned = true
		await physics_frame
		for index in observed.size():
			var member = observed[index].get_ref()
			if is_instance_valid(member) and not first_view.has(index) and game.camera.cam.is_position_in_frustum(member.global_position):
				first_view[index] = i
		if i % 9 == 0:
			var bodies := []
			for ref in observed:
				var enemy = ref.get_ref()
				if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
					bodies.append({"kind": enemy.kind, "at": str(enemy.global_position), "hp": enemy.hp,
						"pops": enemy.pops if enemy.kind == "boom_tender" else 0})
			trace.append({"tick": i, "ball": str(game.player.ball_position()),
				"speed": game.player.planar_velocity().length(), "bodies": bodies})
		if not wanted_shot.is_empty():
			await _shot("%03d-%s" % [i, wanted_shot])
			wanted_shot = ""
		elif i in [45, 100, 220, 450]:
			await _shot(str(i))
	rows.append({"approach": approach, "start": str(start), "target": str(target), "initial_speed": v,
		"heft": game.combat.heft_override, "lost_hp": hp - game.run.hp, "turn_triggered": turned, "first_view_ticks": first_view,
		"events": events, "trace": trace})


func _arrivals() -> void:
	for seed_value in [1, 1, 17, 31]:
		for aim in [UPPER, LOWER, SIPHON]:
			var heading := KICKER.direction_to(aim)
			var ahead := Vector3(heading.x, 0, heading.y)
			game.player.reset_to(_point(KICKER, 1.4))
			game.player.body().freeze = true
			game.camera.snap(ahead)
			for i in 6:
				await physics_frame
			for shift in [false, true]:
				var d := Placement.new(seed_value)
				d.author(ParkDefs.DEFS[1], ParkDefs)
				d.use_row(ParkDefs.DEFS[1])
				d.play_rect = game.world.director.play_rect
				d.shift_home = shift
				d.shift_line = shift
				for draw in 20:
					d.source = "flank"
					var spot := d.spawn_spot(KICKER, heading * 28.0, heading)
					var source := d.source
					var queued := 0
					if spot.is_finite():
						queued = d._place_pack(spot, ["chaser", "lobber"], KICKER)
					var members := []
					for member in d.arrivals:
						var eye := _point(member.at, 2.4)
						var camera: Camera3D = game.camera.cam
						var ray := PhysicsRayQueryParameters3D.create(camera.global_position, eye, 1)
						var block := camera.get_world_3d().direct_space_state.intersect_ray(ray)
						members.append({"kind": Director.KIND_NAMES[member.kind], "at": str(member.at),
							"bearing_deg": rad_to_deg(heading.angle_to(member.at - KICKER)),
							"safe": d._park_safe(member.at), "inside_view": camera.is_position_in_frustum(eye),
							"occluded": not block.is_empty()})
					rows.append({"seed": seed_value, "aim": str(aim), "draw": draw, "source": source,
						"anchor": str(spot), "queued": queued, "members": members, "shift": shift})
					d.arrivals.clear()


func _yard(alternate: bool) -> void:
	var locks = game.world.locks
	var centre := Vector2(0, 530)
	game.player.reset_to(_point(centre - Vector2(0, 10), 1.1))
	game.player.body().freeze = true
	game.camera.snap(Vector3.BACK)
	locks.set_physics_process(false)
	locks.row = LockRows.row("park_dam")
	locks.lock_centre = _point(centre, 0)
	locks._facing = PI / 2
	var sentinel_start: Vector3 = game.flow.beacon.global_position - Vector3.BACK * 260.0
	game.player.reset_to(_point(Vector2(sentinel_start.x, sentinel_start.z), 1.25))
	locks._land_sentry(game.player.ball_position(), game.flow.beacon.global_position)
	if locks._sentry != null and is_instance_valid(locks._sentry.get_ref()):
		var sentry = locks._sentry.get_ref()
		game.camera.snap((sentry.global_position - game.player.ball_position()).normalized())
		await _shot("sentry")
		rows.append({"order": case_id, "wave": "sentry", "kind": sentry.kind, "at": str(sentry.global_position)})
		sentry.free()
	game.player.reset_to(_point(centre - Vector2(0, 10), 1.1))
	for wave in [0, 3, 4]:
		var source: Array = locks.lock_row().waves[wave]
		var kinds := source.duplicate()
		if alternate:
			# Place the odd tool between scrapers; compare identical bearings, counts and clocks.
			var lesson = kinds.pop_back()
			kinds.insert(kinds.size() / 2, lesson)
		var spots: Array = locks._wave_spots(wave)
		events = []
		first = {}
		observed = []
		tell = false
		tick = 0
		var placement := []
		for i in kinds.size():
			var enemy = game.combat.spawn_enemy(kinds[i], spots[i])
			enemy.set_meta("pack_seq", 901)
			_watch(enemy)
			placement.append({"kind": kinds[i], "at": str(spots[i])})
		game.camera.snap((spots[spots.size()/2] - game.player.ball_position()).normalized())
		await _shot("wave-%d-land" % (wave + 1))
		for i in 450:
			tick = i
			await physics_frame
			if i in [70, 326]:
				await _shot("wave-%d-%d" % [wave + 1, i])
		rows.append({"order": case_id, "wave": wave + 1, "members": placement,
			"events": events, "survivors_5s": observed.filter(func(r): return is_instance_valid(r.get_ref())).size()})
		for ref in observed:
			var unit = ref.get_ref()
			if is_instance_valid(unit):
				unit.queue_free()
		await physics_frame


# Use the actual driver's lens for approach, and freeze on the same live pose for the three
# inspection cameras. Model-space AABB projections include the claws, pivot, clip and brace.
func _motion() -> void:
	var camera: Camera3D = game.camera.cam
	var start := KICKER - SIPHON.direction_to(KICKER) * 33.0
	var at := start + SIPHON.direction_to(KICKER) * 11.5
	game.player.reset_to(_point(start, 1.3))
	game.player.body().freeze = true
	var enemy = game.combat.spawn_enemy("chaser", _point(at, 1.6))
	game.camera.snap((enemy.global_position - game.player.ball_position()).normalized())
	case_id = "chase"
	var seen := {}
	for i in 420:
		await physics_frame
		if not is_instance_valid(enemy):
			break
		var phase: String = enemy.state_name()
		if phase == "windup" and enemy._clock < 0.45:
			continue
		if seen.has(phase):
			continue
		seen[phase] = true
		var body: Node3D = enemy._pose_parts["ChaserBody"].node
		var feet: Node3D = enemy._pose_parts["ChaserClaws"].node
		rows.append({"tick": i, "phase": phase, "enemy": str(enemy.global_position),
			"floor_normal": str(enemy.get_floor_normal()), "visual_up": str(feet.global_basis.y.normalized()),
			"head": str(body.global_transform), "camera": str(camera.global_transform),
			"telegraph": str(enemy.telegraph().descriptor()) if is_instance_valid(enemy.telegraph()) else ""})
		await _shot(phase)
		if phase in ["windup", "lunge"] and pictures:
			var original := camera.global_transform
			var overlays := root.find_children("*", "CanvasLayer", true, false).filter(func(layer): return layer.visible)
			for layer in overlays:
				layer.visible = false
			var forward: Vector3 = Vector3(-sin(enemy._mesh.rotation.y), 0, -cos(enemy._mesh.rotation.y))
			var centre: Vector3 = enemy.global_position + Vector3.UP * 0.35
			paused = true
			for view in [["front", forward], ["side", forward.cross(Vector3.UP)], ["rear", -forward]]:
				camera.look_at_from_position(centre + view[1] * 7.0 + Vector3.UP * 1.1, centre, Vector3.UP)
				for j in 3:
					await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg(out.path_join("motion-%s-%s.jpg" % [phase, view[0]]), 0.9)
			camera.global_transform = original
			for layer in overlays:
				layer.visible = true
			paused = false
		if phase == "recover":
			break


# Test the wasteway crew along the moving pilot's camera. Keep each alternative inside
# the same authored footprint and on its eligible side; keep quiet ground and all corridors free.
func _home_reveal() -> void:
	var origin := Vector2(14, 220)
	var d := Placement.new(1)
	d.author(ParkDefs.DEFS[1], ParkDefs)
	d.use_row(ParkDefs.DEFS[1])
	d.play_rect = game.world.director.play_rect
	var home: Dictionary = d.homes.filter(func(h): return h.id == "wasteway_chasers")[0]
	var site: Dictionary = d._home_sites[home.site]
	var anchor := d._home_at(home)
	var half: Vector2 = d._park_map.footprint_half_extents(site)
	var heading := origin.direction_to(KICKER)
	var along := Vector3(heading.x, 0, heading.y)
	game.player.reset_to(_point(origin, 1.3), along * 24)
	game.player.source.hold = {"move": Vector2(0, 1)}
	game.camera.snap(along)
	var positions := []
	for x in [-0.8, -0.4, 0.0, 0.4, 0.8]:
		for z in [-0.65, 0.0, 0.65]:
			var spot := anchor + Vector2(x * half.x,z * half.y).rotated(-deg_to_rad(float(site.yaw_deg)))
			if d._home_point_safe(site,spot,origin,[]):
				positions.append(spot)
	for i in 500:
		await physics_frame
		if i % 9 != 0:
			continue
		var camera: Camera3D = game.camera.cam
		var samples := []
		for spot in positions:
			var eye := _point(spot, 2.4)
			var ray := PhysicsRayQueryParameters3D.create(camera.global_position, eye, 1)
			var block := camera.get_world_3d().direct_space_state.intersect_ray(ray)
			samples.append({"at":str(spot), "projected":camera.is_position_in_frustum(eye),
				"block": str(block.collider.get_path()) if not block.is_empty() else "",
				"hit": str(block.position) if not block.is_empty() else ""})
		rows.append({"map": game.ctx.terrain.map().title, "tick":i, "lens":str(camera.global_position),
			"ball":str(game.player.ball_position()), "speed":game.player.planar_velocity().length(), "samples":samples})


# Release the pilot on the tender's already committed line. This isolates whether a
# timely crossing pays once and retains a clear exit when the ordinary approach misses.
func _crossing(approach: String) -> void:
	case_id = approach
	var bearing := SIPHON.direction_to(KICKER)
	var along := Vector3(bearing.x, 0, bearing.y)
	var side := Vector3(-bearing.y, 0, bearing.x)
	var hull := KICKER - bearing * 22.0
	var speed := 7.0 if approach == "slow" else 28.0
	var offset := 5.0 if approach == "outside" else 0.85
	var from := _point(hull - bearing * 9.8, 1.1)
	game.player.reset_to(from)
	game.player.body().freeze = true
	game.combat.heft_override = 4.0 if approach == "grown" else 1.0
	game.player.heft_of = func(): return game.combat.heft_override
	game.camera.snap(along)
	var tender = game.combat.spawn_enemy("boom_tender", _point(hull, 1.35))
	tender.target = game.player
	tender._warn(from - tender.global_position)
	await _shot("line")
	for i in 120:
		await physics_frame
		if tender.phase == tender.Phase.LIVE:
			break
	var committed: Vector3 = tender._heading
	game.player.body().freeze = false
	game.player.reset_to(from + side * offset, along * speed)
	game.player.source.hold = {"move": Vector2(0, 1)}
	var trace := []
	var last_pops := 0
	for i in 100:
		await physics_frame
		if not is_instance_valid(tender):
			continue
		if tender.pops != last_pops or i % 10 == 0:
			trace.append({"tick": i, "ball": str(game.player.ball_position()), "speed": game.player.planar_velocity().length(),
				"pops": tender.pops, "strikes": tender.strikes, "pins": tender.pinned})
		if tender.pops > last_pops:
			await _shot("pop-%d" % tender.pops)
		last_pops = tender.pops
	await _shot("exit")
	rows.append({"approach": approach, "start": str(from + side * offset), "heading": str(committed),
		"heft": game.combat.heft_override, "release_speed": speed, "exit_ball": str(game.player.ball_position()),
		"exit_speed": game.player.planar_velocity().length(), "trace": trace})


# Land a matched seed-one home pair through the real reinforcement circle and enemy paths.
func _arrival_stills() -> void:
	for shift in [false, true]:
		case_id = "west" if shift else "stock"
		var d := Placement.new(1)
		d.author(ParkDefs.DEFS[1], ParkDefs)
		d.use_row(ParkDefs.DEFS[1])
		d.play_rect = game.world.director.play_rect
		d.shift_home = shift
		var heading := KICKER.direction_to(LOWER)
		var along := Vector3(heading.x, 0, heading.y)
		game.player.body().freeze = true
		game.player.reset_to(_point(KICKER, 1.25))
		game.camera.snap(along)
		var spot := d.spawn_spot(KICKER, heading * 28.0, heading)
		d._place_pack(spot, ["chaser", "lobber"], KICKER)
		game.world.view.show_arrivals(d.arrivals)
		await _shot("warning")
		var crew := []
		for member in d.arrivals:
			crew.append(game.combat.spawn_enemy(Director.KIND_NAMES[member.kind], _point(member.at, 2.4)))
		game.world.view.show_arrivals([])
		await _shot("landing")
		game.player.body().freeze = false
		game.player.reset_to(_point(KICKER, 1.25), along * 24)
		game.player.source.hold = {"move": Vector2(0, 1)}
		for tick_index in 1000:
			await physics_frame
			if crew.any(func(c): return is_instance_valid(c) and is_instance_valid(c.telegraph())):
				await _shot("first-attack")
				break
		for member in crew:
			if is_instance_valid(member):
				member.queue_free()
		await physics_frame
