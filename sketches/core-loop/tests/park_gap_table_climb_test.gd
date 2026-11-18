extends SceneTree
# smoke: solo timeout=600s

# The flume's butte gap table (park_flume.json gap_table and gap_table_kicker, W1-102): a sheer 14 m table whose one way
# up is the 14 m kicker set against its -z face, the lip on the face line so it meets the top with no notch. Map standard point 7 counts the climb from the stage graph's kicker edge; this test rides it with the real
# ball in the real game on the flume, so the count stands for a climb a ball makes.
#
#  climbs   a ball starts 2 m short of the kicker's foot heading up it at each of SPEEDS m/s, once holding forward and once
#           not. Each run records the planar speed as the ball passes the lip line and how it ends: on the table top, or
#           at rest. No run may end at rest anywhere but the floor or the top (not in a notch, not wedged on a face).
#           The pinned reach (measured 17 Nov 2026 on the Mac): every held start reaches the top, from rest up, so the
#           kicker is no speed gate for a ball holding forward; a free ball needs FREE_REACH_MPS (it tops out from 27 m/s
#           and rolls back from 22 m/s and under).
#  off      a ball on the top rolled slowly toward the lip, forward held, leaves over the kicker and reaches the floor
#           past the kicker's foot under its own drive.
#  grazes   a cruising ball, forward held, runs along each table face and the kicker's foot 0.3 m clear of contact (a
#           face's sheer skirt reaches one 2 m bake cell past the footprint, so the lane stands SKIRT_M further out),
#           and past the table corner nearest the mesa rim road; none stops (lowest speed at least GRAZE_KEEP of cruise).
#
# Plant (GAP_TABLE_PLANT=notch moves the kicker NOTCH_M back from the face, reopening a gap the ball's width;
# GAP_TABLE_PLANT=lip stands a LIP_M wall along the lip on the top): either turns this test red.
# Evidence limit: headless Jolt on the baked flume ground; no feel, look or camera claim.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")

const PARK := "res://src/world/park/park_flume.json"
const SPEEDS := [0.0, 8.0, 14.0, 16.0, 22.0, 27.0]
# The lowest of SPEEDS a ball not holding forward tops out from (measured; see the header).
const FREE_REACH_MPS := 27.0
const RUNUP_M := 2.0
const RUN_S := 10.0
const REST_MPS := 0.3
const REST_TICKS := 45
const ON_TOP_M := 6.0
const GRAZE_KEEP := 0.5
const GRAZE_CLEAR_M := 0.3
const SKIRT_M := 2.0
const NOTCH_M := 3.5
const NOTCH_ZONE_M := 4.0
const LIP_M := 1.2

var t := T.new("park_gap_table_climb_test")
var game
var source := Intent.Scripted.new()
var table := {}
var kicker := {}
var top_y := 0.0
var floor_y := 0.0
# The mesa rim road's centre line and heading, read from its park row.
var road_at := Vector2.ZERO
var road_yaw_deg := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_read_rows()
	if not t.check("the park file holds the gap table, its kicker and the mesa rim road", not table.is_empty() and not kicker.is_empty() and road_at != Vector2.ZERO,
			"table %s, kicker %s, road %s" % [not table.is_empty(), not kicker.is_empty(), road_at]):
		quit(t.verdict())
		return
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = source
	game.flow.press_start()
	game.flow.choose_class(0)
	game.flow.enter_stage(2, Vector3.ZERO, false)
	var terrain = game.ctx.terrain
	var waited := 0
	while waited < 3000 and not (terrain.rows_ready(2) and terrain.is_ready(2) and game.flow.state_name() == "stage"):
		await process_frame
		waited += 1
	for i in 30:
		await physics_frame
	t.eq("real Game plays the flume on the park table", terrain.map().title, "park_flume")
	var found: Array = game.find_children("Park_gap_table_kicker", "Node3D", true, false)
	if not t.check("the flume places the gap table kicker", found.size() == 1, "%d found" % found.size()):
		game.free()
		quit(t.verdict())
		return
	var node: Node3D = found[0]
	top_y = _ground(Vector3(table.cx, 0.0, (table.z0 + table.z1) * 0.5))
	floor_y = _ground(Vector3(kicker.cx, 0.0, kicker.foot - RUNUP_M))
	var plant := OS.get_environment("GAP_TABLE_PLANT")
	_plant(plant, node)
	for i in 2:
		await physics_frame
	var cruise: float = game.player.tuning.f("cruise")
	print("  table x %.0f..%.0f z %.0f..%.0f top %.2f, floor %.2f, kicker foot z %.1f lip z %.1f, cruise %.1f, plant '%s'" % [
		table.x0, table.x1, table.z0, table.z1, top_y, floor_y, kicker.foot, kicker.lip, cruise, plant])
	t.check("the table stands at least 10 m over the floor at the kicker's foot", top_y - floor_y >= 10.0, "%.2f m" % (top_y - floor_y))
	# Climbs.
	for held in [true, false]:
		for v: float in SPEEDS:
			var r := await _climb(v, held)
			var label := "climb %4.1f m/s %s" % [v, "held" if held else "free"]
			print("  %s: lip speed %s, end %s at %s" % [label, "%.1f" % r.lip if r.lip >= 0.0 else "never", r.end, r.at])
			t.check("%s ends on the floor or the top, never at rest in a notch or on a face" % label, r.end != "stuck", str(r.at))
			if held or v >= FREE_REACH_MPS:
				t.check("%s reaches the table top" % label, r.end == "top", r.end)
			else:
				t.check("%s rolls back short of the top and comes to rest on the floor" % label, r.end == "floor", r.end)
	# Off the top, back over the lip.
	var off := await _off_top()
	print("  off the top: %s at %s" % [off.end, off.at])
	t.check("a slow ball rolled off the top leaves over the kicker to the floor under its own drive", off.end == "floor", "%s at %s" % [off.end, off.at])
	# Grazes at cruise.
	var clear := SKIRT_M + GRAZE_CLEAR_M + Tuning.RADIUS
	var lanes := {
		"-x face": [Vector3(table.x0 - clear, 0, kicker.foot - 4.0), Vector3.BACK, table.z1 - kicker.foot + 12.0],
		"+x face": [Vector3(table.x1 + clear, 0, kicker.foot - 4.0), Vector3.BACK, table.z1 - kicker.foot + 12.0],
		"+z face": [Vector3(table.x0 - 8.0, 0, table.z1 + clear), Vector3.RIGHT, table.x1 - table.x0 + 16.0],
		"kicker foot (-z)": [Vector3(table.x0 - 8.0, 0, kicker.foot - clear), Vector3.RIGHT, table.x1 - table.x0 + 16.0],
	}
	var corner := _road_corner()
	var road_dir := Vector3(sin(deg_to_rad(road_yaw_deg)), 0, cos(deg_to_rad(road_yaw_deg)))
	var out_n := Vector3(-road_dir.z, 0, road_dir.x)
	if out_n.dot(Vector3(table.cx - corner.x, 0, (table.z0 + table.z1) * 0.5 - corner.z)) > 0.0:
		out_n = -out_n
	lanes["corner nearest the road"] = [corner + out_n * clear - road_dir * 16.0, road_dir, 32.0]
	for name: String in lanes:
		var lane: Array = lanes[name]
		var g := await _graze(lane[0], lane[1], lane[2], cruise)
		print("  graze %s: lowest %.1f of %.1f m/s at %s, crossed %s" % [name, g.low, cruise, g.low_at, g.crossed])
		t.check("graze %s at cruise: no stop" % name, g.crossed and g.low >= cruise * GRAZE_KEEP, "lowest %.1f, crossed %s" % [g.low, g.crossed])
	game.free()
	quit(t.verdict())


func _read_rows() -> void:
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PARK))
	for row: Dictionary in park["park_rows"]:
		var at := Vector2(float(row["at"][0]), float(row["at"][1]))
		var size: Array = row["size"]
		if row["id"] == "gap_table":
			table = {"cx": at.x, "x0": at.x - float(size[2]) * 0.5, "x1": at.x + float(size[2]) * 0.5,
				"z0": at.y - float(size[0]) * 0.5, "z1": at.y + float(size[0]) * 0.5}
		elif row["id"] == "gap_table_kicker":
			kicker = {"cx": at.x, "foot": at.y - float(size[0]) * 0.5, "lip": at.y + float(size[0]) * 0.5}
		elif row["id"] == "mesa_rim_road":
			road_at = at
			road_yaw_deg = float(row.get("yaw_deg", 0.0))


func _plant(plant: String, node: Node3D) -> void:
	if plant == "notch":
		node.global_position += Vector3.FORWARD * NOTCH_M
		kicker.foot -= NOTCH_M
		kicker.lip -= NOTCH_M
	elif plant == "lip":
		var wall := StaticBody3D.new()
		wall.name = "PlantedLipWall"
		wall.collision_layer = 0
		wall.collision_mask = 0
		wall.set_collision_layer_value(ParkRecipes.WORLD_LAYER, true)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(table.x1 - table.x0, LIP_M, 1.0)
		shape.shape = box
		wall.add_child(shape)
		node.get_parent().add_child(wall)
		wall.global_position = Vector3(table.cx, top_y + LIP_M * 0.5, table.z0 + 2.0)


# The table corner closest to the mesa rim road's centre line.
func _road_corner() -> Vector3:
	var d := Vector2(sin(deg_to_rad(road_yaw_deg)), cos(deg_to_rad(road_yaw_deg)))
	var best := Vector2.ZERO
	var best_d := INF
	for c in [Vector2(table.x0, table.z0), Vector2(table.x0, table.z1), Vector2(table.x1, table.z0), Vector2(table.x1, table.z1)]:
		var rel: Vector2 = c - road_at
		var dist := absf(rel.x * d.y - rel.y * d.x)
		if dist < best_d:
			best_d = dist
			best = c
	return Vector3(best.x, 0, best.y)


func _ground(at: Vector3) -> float:
	var space := game.player.body().get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 200.0, at.z), Vector3(at.x, -200.0, at.z))
	q.exclude = [game.player.body().get_rid()]
	var hit := space.intersect_ray(q)
	return at.y if hit.is_empty() else float(hit.position.y)


func _on_top(p: Vector3) -> bool:
	return p.x > table.x0 and p.x < table.x1 and p.z > table.z0 and p.z < table.z1 and p.y > top_y + Tuning.RADIUS - 0.5


func _drive(dir: Vector3, held: bool) -> void:
	game.camera.yaw = atan2(-dir.x, -dir.z)
	source.hold = {"move": Vector2(0.0, 1.0)} if held else {}
	game.player.grant_immunity(1.0)


# One climb from RUNUP_M short of the kicker's foot. end: "top" (on the table and ON_TOP_M past its edge, or at rest on
# it), "floor" (at rest within 2 m of the floor height, short of the face by NOTCH_ZONE_M), "stuck" (at rest anywhere
# else) or "time".
func _climb(speed: float, held: bool) -> Dictionary:
	var player = game.player
	var start := Vector3(kicker.cx, 0, kicker.foot - RUNUP_M)
	player.reset_to(Vector3(start.x, floor_y + Tuning.RADIUS + 0.3, start.z), Vector3.BACK * speed)
	source.hold = {}
	await physics_frame
	var lip_speed := -1.0
	var still := 0
	var ball: Vector3 = player.ball_position()
	for tick in int(RUN_S * Engine.physics_ticks_per_second):
		_drive(Vector3.BACK, held)
		await physics_frame
		ball = player.ball_position()
		var v: float = player.planar_velocity().length()
		if lip_speed < 0.0 and ball.z >= kicker.lip - 1.0:
			lip_speed = v
		if _on_top(ball) and ball.z > table.z0 + ON_TOP_M:
			source.hold = {}
			return {"lip": lip_speed, "end": "top", "at": _fmt(ball)}
		still = still + 1 if v < REST_MPS else 0
		if still >= REST_TICKS:
			break
	source.hold = {}
	var end := "time"
	if still >= REST_TICKS:
		if _on_top(ball):
			end = "top"
		# Floor height within NOTCH_ZONE_M of the face is down a notch between the kicker and the table, not the open floor.
		elif ball.y < floor_y + Tuning.RADIUS + 2.0 and ball.z < kicker.lip - NOTCH_ZONE_M:
			end = "floor"
		else:
			end = "stuck"
	return {"lip": lip_speed, "end": end, "at": _fmt(ball)}


# A ball on the top 6 m in from the lip, rolling at 2 m/s toward it with forward held: "floor" once it is past the
# kicker's foot near the floor height, else where it ended.
func _off_top() -> Dictionary:
	var player = game.player
	var start := Vector3(kicker.cx, top_y + Tuning.RADIUS + 0.3, table.z0 + 6.0)
	player.reset_to(start, Vector3.FORWARD * 2.0)
	await physics_frame
	var ball: Vector3 = player.ball_position()
	for tick in int(RUN_S * Engine.physics_ticks_per_second):
		_drive(Vector3.FORWARD, true)
		await physics_frame
		ball = player.ball_position()
		if ball.z < kicker.foot - 1.0 and ball.y < floor_y + Tuning.RADIUS + 2.0:
			source.hold = {}
			return {"end": "floor", "at": _fmt(ball)}
	source.hold = {}
	return {"end": "top" if _on_top(ball) else "elsewhere", "at": _fmt(ball)}


func _graze(from: Vector3, dir: Vector3, length: float, cruise: float) -> Dictionary:
	var player = game.player
	player.reset_to(Vector3(from.x, _ground(from) + Tuning.RADIUS + 0.3, from.z), dir * cruise)
	await physics_frame
	var low := INF
	var low_at := ""
	var reached := 0.0
	for tick in int((length / cruise * 3.0 + 1.0) * Engine.physics_ticks_per_second):
		_drive(dir, true)
		await physics_frame
		var ball: Vector3 = player.ball_position()
		var s: float = (ball - from).dot(dir)
		reached = maxf(reached, s)
		if tick > 10 and player.planar_velocity().length() < low:
			low = player.planar_velocity().length()
			low_at = _fmt(ball)
		if s > length:
			break
	source.hold = {}
	return {"low": low, "low_at": low_at, "crossed": reached > length}


func _fmt(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]
