extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")


const BIG_M := 160.0
const RUNUP_M := 14.0
const CAMP_RUNUP_M := 8.0
const REACH_PAD := 3.0
const PROBE_S := 3.0
const STOP_SPEED := 1.2
const STOP_S := 0.8
const HUNG_S := 0.8
const ESCAPE_S := 1.5
const TELEPORT_M := 8.0
const COVER_PAD := 0.6
const CELL := 16.0

var _game
var _out: FileAccess
var _settings := {}
var _meshes := {}
var _rows := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			_settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	if not _settings.has("out"):
		printerr("spot_sweep: --out=<file.ndjson> is required")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	_out = FileAccess.open(String(_settings["out"]), FileAccess.WRITE)
	var shard := String(_settings.get("shard", "0/1")).split("/")
	if _out == null or shard.size() != 2 or float(_settings.get("grid", "1")) <= 0.0:
		printerr("spot_sweep: --out must be writable, --shard i/n, --grid above 0")
		quit(2)
		return
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	await process_frame
	await process_frame
	_game.ctx.calm = true
	var source := Intent.Scripted.new()
	_game.player.source = source
	if _settings.get("camp", "0") == "1":
		await _camp(source)
		print("spot_sweep: %d probes written" % _rows)
		quit(0)
		return
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await physics_frame
	var stages: Array = []
	for part in String(_settings.get("stages", "1,2")).split(",", false):
		stages.append(int(part))
	var shard_i := int(shard[0])
	var shard_n := maxi(1, int(shard[1]))
	var only := String(_settings.get("only", "")).split(",", false)
	var dirs := int(_settings.get("dirs", "8"))
	for stage in stages:
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
		for i in 30:
			await physics_frame
		var terrain = _game.ctx.terrain
		var map = terrain.map_for(stage)
		_index_meshes(terrain.geometry_root(stage))
		var spots := _grid(map.park, float(_settings["grid"])) if _settings.has("grid") else _spots(map.park)
		if _settings.has("at"):
			spots = []
			for pair in String(_settings["at"]).split(";", false):
				var xz := pair.split(",")
				if xz.size() == 3:
					spots.append({"id": "at%s" % pair, "kind": "point", "at": Vector2(float(xz[0]), float(xz[2])), "r": 0.0, "y": float(xz[1])})
				else:
					spots.append({"id": "at%s" % pair, "kind": "point", "at": Vector2(float(xz[0]), float(xz[1])), "r": 0.0})
		print("spot_sweep: stage %d (%s) %d spots, %d mesh cells" % [stage, map.park["map"], spots.size(), _meshes.size()])
		for n in spots.size():
			if n % shard_n != shard_i:
				continue
			var spot: Dictionary = spots[n]
			if not only.is_empty() and String(spot.id) not in only:
				continue
			for d in dirs:
				var angle := TAU * float(d) / float(dirs)
				var row := await _probe(stage, spot, angle, source)
				row["dir"] = d
				_out.store_line(JSON.stringify(row))
				_rows += 1
			_out.flush()
	print("spot_sweep: %d probes written" % _rows)
	quit(0)


func _spots(park: Dictionary) -> Array:
	var out := []
	for row in park.get("park_rows", []):
		var size: Array = row.get("size", [0, 0, 0])
		var r := maxf(float(size[0]), float(size[2])) * 0.5
		if r * 2.0 > BIG_M:
			continue
		out.append({"id": row.id, "kind": "row:%s" % row.get("landform", ""), "at": Vector2(row.at[0], row.at[1]), "r": r})
	var lm: Dictionary = park.get("landmark", {})
	if lm.has("beacon"):
		out.append({"id": "%s_beacon" % lm.id, "kind": "beacon", "at": Vector2(lm.beacon[0], lm.beacon[1]), "r": 4.0})
	for key in ["bay_dock"]:
		if lm.has(key):
			out.append({"id": "%s_%s" % [lm.id, key], "kind": key, "at": Vector2(lm[key].at[0], lm[key].at[1]), "r": 4.0})
	for slot in lm.get("gate_slots", []):
		out.append({"id": "gate_slot_%d" % int(slot.at[0]), "kind": "gate_slot", "at": Vector2(slot.at[0], slot.at[1]), "r": 3.0})
	for w in park.get("waymarks", []):
		if w is Dictionary and w.has("at"):
			out.append({"id": w.id, "kind": "waymark", "at": Vector2(w.at[0], w.at[1]), "r": 4.0})
	for a in park.get("activity_rows", []):
		out.append({"id": a.id, "kind": "activity:%s" % a.activity, "at": Vector2(a.at[0], a.at[1]), "r": 5.0})
	for a in park.get("rescue_rows", []):
		out.append({"id": a.id, "kind": "rescue", "at": Vector2(a.at[0], a.at[1]), "r": 4.0})
	for c in park.get("contraption_rows", []):
		if c.has("at"):
			out.append({"id": c.id, "kind": "contraption:%s" % c.kind, "at": Vector2(c.at[0], c.at[c.at.size() - 1]), "r": 4.0})
		elif c.has("from"):
			out.append({"id": c.id + "_from", "kind": "contraption:%s" % c.kind, "at": Vector2(c.from[0], c.from[2]), "r": float(c.get("radius", 4.0))})
	return out


func _probe(stage: int, spot: Dictionary, angle: float, source, from := Vector2.INF) -> Dictionary:
	var terrain = _game.ctx.terrain
	var player = _game.player
	var centre: Vector2 = spot.at
	var reach: float = REACH_PAD
	var side := Vector2(cos(angle), sin(angle))
	var start2 := centre + side * (float(spot.r) + (CAMP_RUNUP_M if stage == 0 else RUNUP_M))
	if from != Vector2.INF:
		start2 = from
	if _settings.get("leave", "0") == "1":
		var out_to := start2
		start2 = centre
		centre = out_to
	var row := {"stage": stage, "id": spot.id, "kind": spot.kind, "start": [snappedf(start2.x, 0.1), snappedf(start2.y, 0.1)]}
	var top = _top(Vector3(start2.x, 0.0, start2.y), float(spot.get("y", 400.0)) + 2.0)
	if top == null or (stage != 0 and not terrain.contains(top)):
		row["outcome"] = "bad_start"
		return row
	var aim := Vector3(centre.x - start2.x, 0.0, centre.y - start2.y).normalized()
	var cruise: float = player.tuning.f("cruise")
	source.hold = {}
	player.reset_to(top + Vector3.UP * 1.3, aim * cruise * 0.8)
	await physics_frame
	var slow := 0.0
	var hung := 0.0
	var last: Vector3 = player.ball_position()
	var min_d := INF
	var t := 0.0
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var limit := PROBE_S + start2.distance_to(centre) / 12.0
	while t < limit:
		var ball: Vector3 = player.ball_position()
		var flat := Vector3(centre.x - ball.x, 0.0, centre.y - ball.z)
		_game.camera.yaw = atan2(-flat.x, -flat.z)
		source.hold = {"move": Vector2(0.0, 1.0)}
		player.grant_immunity(1.0)
		await physics_frame
		t += dt
		ball = player.ball_position()
		if ball.distance_to(last) > TELEPORT_M:
			row["outcome"] = "fell"
			row["at"] = _v(last)
			return row
		last = ball
		var d := Vector2(ball.x - centre.x, ball.z - centre.y).length()
		min_d = minf(min_d, d)
		if d <= reach:
			row["outcome"] = "reached"
			row["t"] = snappedf(t, 0.01)
			return row
		var speed: float = player.planar_velocity().length()
		var resting := speed < STOP_SPEED and absf(player.state.velocity.y) < STOP_SPEED
		if resting and not player.state.grounded:
			hung += dt
		else:
			hung = 0.0
		slow = slow + dt if resting else 0.0
		if hung >= HUNG_S:
			row["outcome"] = "hung"
			_contact(row, ball)
			row["escaped"] = await _escape(source, ball)
			return row
		if slow >= STOP_S and t > 0.3:
			row["outcome"] = "blocked" if _contact(row, ball) else "stuck"
			if row["outcome"] == "blocked" and "/Ground/" in String(row["collider"]):
				row["outcome"] = "slope"
			return row
	row["outcome"] = "short"
	row["min_d"] = snappedf(min_d - float(spot.r), 0.1)
	row["at"] = _v(player.ball_position())
	return row


func _camp(source) -> void:
	for i in 5:
		await process_frame
	_game.screens.button_for("camp").pressed.emit()
	for i in 3:
		await process_frame
	var hub = _game.camp_hub
	_index_meshes(hub.root)
	var dirs := int(_settings.get("dirs", "8"))
	var spots := []
	for id in hub.zone_ids():
		var at: Vector3 = hub.zone_position(id)
		spots.append({"id": id, "kind": "camp", "at": Vector2(at.x, at.z), "r": 1.5})
	print("spot_sweep: camp %d zones, %d mesh cells" % [spots.size(), _meshes.size()])
	var spawn: Vector3 = hub.spawn_position()
	for spot in spots:
		for d in dirs + 1:
			var row := await _probe(0, spot, TAU * float(d) / float(dirs), source,
				Vector2(spawn.x, spawn.z) if d == dirs else Vector2.INF)
			row["dir"] = "spawn" if d == dirs else str(d)
			_out.store_line(JSON.stringify(row))
			_rows += 1
		_out.flush()


func _grid(park: Dictionary, step: float) -> Array:
	var r: Array = park["play_rect"]
	var out := []
	var x := float(r[0]) + step * 0.5
	while x < float(r[0]) + float(r[2]):
		var z := float(r[1]) + step * 0.5
		while z < float(r[1]) + float(r[3]):
			out.append({"id": "g%d_%d" % [int(x), int(z)], "kind": "grid", "at": Vector2(x, z), "r": 0.0})
			z += step
		x += step
	return out


func _escape(source, ball: Vector3) -> bool:
	source.press = {"jump_pressed": true}
	var t := 0.0
	while t < ESCAPE_S:
		source.hold = {"move": Vector2(0.0, -1.0), "jump_held": t < 0.3}
		await physics_frame
		t += 1.0 / float(Engine.physics_ticks_per_second)
	source.hold = {}
	return _game.player.ball_position().distance_to(ball) > 3.0


func _top(at: Vector3, from_y := 400.0):
	var space: PhysicsDirectSpaceState3D = _game.player.body().get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, from_y, at.z), Vector3(at.x, -200.0, at.z))
	q.exclude = [_game.player.body().get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	return null if hit.is_empty() else hit.position


func _contact(row: Dictionary, ball: Vector3) -> bool:
	row["at"] = _v(ball)
	var body: RigidBody3D = _game.player.body()
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(body.get_rid())
	var walls := []
	for i in (state.get_contact_count() if state != null else 0):
		var n: Vector3 = state.get_contact_local_normal(i)
		var p: Vector3 = state.get_contact_local_position(i)
		var other = state.get_contact_collider_object(i)
		var path := ""
		if other is Node:
			path = String((other as Node).get_path()).replace(String(_game.get_path()), "")
		var wall := absf(n.y) < 0.7
		walls.append({"collider": path, "n": _v(n), "p": _v(p), "wall": wall, "shown": _shown(p)})
	row["contacts"] = walls
	row["grounded"] = _game.player.state.grounded
	for c in walls:
		if c.wall:
			row["collider"] = c.collider
			row["visible"] = c.shown
			return true
	return false


func _shown(p: Vector3) -> bool:
	var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
	for box: AABB in _meshes.get(key, []):
		if box.grow(COVER_PAD).has_point(p):
			return true
	return false


func _index_meshes(stage_root: Node) -> void:
	_meshes.clear()
	var holders: Array = [stage_root]
	for n in _game.get_children():
		if n != stage_root and n is Node3D:
			holders.append(n)
	for holder in holders:
		for g in holder.find_children("*", "GeometryInstance3D", true, false):
			if not g.is_visible_in_tree() or g.visibility_range_begin > 0.0:
				continue
			if g is MultiMeshInstance3D:
				var mm: MultiMesh = g.multimesh
				if mm == null or mm.mesh == null:
					continue
				var local := mm.mesh.get_aabb()
				for i in mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count:
					_add_box(g.global_transform * mm.get_instance_transform(i) * local)
			else:
				_add_box(g.global_transform * g.get_aabb())


func _add_box(box: AABB) -> void:
	if box.size.length() > 4000.0:
		return
	for x in range(floori(box.position.x / CELL), floori(box.end.x / CELL) + 1):
		for z in range(floori(box.position.z / CELL), floori(box.end.z / CELL) + 1):
			var key := Vector2i(x, z)
			if not _meshes.has(key):
				_meshes[key] = []
			_meshes[key].append(box)


static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.1), snappedf(v.y, 0.1), snappedf(v.z, 0.1)]
