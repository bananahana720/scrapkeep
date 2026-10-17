extends SceneTree

const GameEvents := preload("res://src/core/game_events.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Rules := preload("res://src/movement/ball_rules.gd")
const BallState := preload("res://src/movement/ball_state.gd")

# Wall grip and carving (ENEMY-PRIORITY.md 3a; Andrew's "Speed holds" and "Commit", 2026-10-17)
# on the real rigid ball in a half-pipe channel: a flat floor, a 5 m transition to a vertical
# wall 12 m tall on each side, run along z. Each run launches the ball across and along the
# channel and samples every tick it spends on the vertical wall.
#   carve       grip on at 27 m/s: while at grip speed the wall counts as ground, the ball
#               reports carving, and a jump there pushes straight off the face.
#   off         the same launch with --grip=off: the wall is never ground (today's ball).
#   slow        grip on at 15 m/s, under the fast tier: never grips, so never ground past 63 deg.
#   land        grip on, dropped in the air beside the wall moving along it: the touch grips
#               (Tally). Sable's vault, like a falling slam, keeps the faces met in the air.
#   bank        a stick press mid-climb starts no speed-bank roll (the bank reads the wall as air):
#               drive alone adds a few m/s there; the roll start added 17.5 before the fix.
#   head_on     grip on, straight into the wall: it bounces as before (pipe vault ruling).
#   peel        every wall tick after the grip clock ran out is airborne (the 0.25 s peel).
#   speed       grip never adds speed: the carve's top speed is no higher than the same
#               launch with grip off, nor than the launch (the soft cap reads speed alone).
# Plus the rule table itself: the overhang threshold and the press's size and direction.

const FLOOR_HALF := 4.0
const ARC_R := 5.0
const WALL_H := 12.0
const LENGTH := 400.0
const START := Vector3(0.0, 1.05, -150.0)
const RUN_TICKS := 150
# The vertical wall's inner face is at x = FLOOR_HALF + ARC_R; the ball's centre sits one
# radius off it, so a centre past this x and above the arc is a ball on the wall.
const ON_WALL_X := FLOOR_HALF + ARC_R - Tuning.RADIUS - 0.25
const ON_WALL_Y := ARC_R + 0.5
const CARVE_GROUNDED_SHARE := 0.8
# In the air beside the right wall, 9 m up its vertical face, for the landing runs.
const WALL_AIR := Vector3(FLOOR_HALF + ARC_R - Tuning.RADIUS - 0.4, ARC_R + 9.0, -150.0)

var _world: Node3D
var _events
var _player
var _tuning
var _source := Intent.Scripted.new()
var _failures := 0
var _runs := {}
var _queue := []
var _run := {}
var _ticks := 0


func _initialize() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_halfpipe()
	_events = GameEvents.new()
	_world.add_child(_events)
	_tuning = Tuning.new()
	_player = PlayerBall.new()
	_world.add_child(_player)
	_player.setup(_tuning, _events, START)
	_player.source = _source
	_player.fit_class(ClassDef.by_id("pylon_engineer"))
	_queue = [
		{"name": "carve", "grip": "on", "velocity": Vector3(26.0, 0.0, 7.0), "jump_on_wall": true},
		{"name": "carve_nojump", "grip": "on", "velocity": Vector3(26.0, 0.0, 7.0)},
		{"name": "carve_steer", "grip": "on", "velocity": Vector3(26.0, 0.0, 0.0), "steer_on_wall": true},
		{"name": "off", "grip": "off", "velocity": Vector3(26.0, 0.0, 7.0)},
		{"name": "slow", "grip": "on", "velocity": Vector3(15.0, 0.0, 0.0)},
		{"name": "land", "grip": "on", "velocity": Vector3(3.0, 0.0, 26.0), "at": WALL_AIR, "class": "tally"},
		{"name": "land_vault", "grip": "on", "velocity": Vector3(3.0, 0.0, 26.0), "at": WALL_AIR},
		{"name": "head_on", "grip": "on", "velocity": Vector3(26.0, 0.0, 0.0), "at": WALL_AIR},
	]


func _halfpipe() -> void:
	var section := PackedVector2Array()
	section.append(Vector2(0.0, 0.0))
	section.append(Vector2(FLOOR_HALF, 0.0))
	for i in range(1, 13):
		var a := deg_to_rad(90.0 * i / 12.0)
		section.append(Vector2(FLOOR_HALF + ARC_R * sin(a), ARC_R - ARC_R * cos(a)))
	section.append(Vector2(FLOOR_HALF + ARC_R, ARC_R + WALL_H))
	var faces := PackedVector3Array()
	var z0 := -LENGTH * 0.5
	var z1 := LENGTH * 0.5
	for side in [1.0, -1.0]:
		for i in section.size() - 1:
			var a := Vector3(section[i].x * side, section[i].y, 0.0)
			var b := Vector3(section[i + 1].x * side, section[i + 1].y, 0.0)
			var a0 := a + Vector3(0, 0, z0)
			var a1 := a + Vector3(0, 0, z1)
			var b0 := b + Vector3(0, 0, z0)
			var b1 := b + Vector3(0, 0, z1)
			faces.append_array([a0, b0, b1, a0, b1, a1])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	_world.add_child(body)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _start(run: Dictionary) -> void:
	_run = run
	_run.merge({"wall": 0, "wall_grounded": 0, "carving": 0, "peeled_wall": 0, "peeled_wall_grounded": 0,
		"min_normal_y": 1.0, "top_speed": 0.0, "max_y": 0.0, "jumped": false,
		"wall_normal_x": 0.0, "first_vx_out": 0.0})
	_tuning.set_option("grip", run["grip"])
	_player.fit_class(ClassDef.by_id(run.get("class", "pylon_engineer")))
	_source.hold = {}
	_player.reset_to(run.get("at", START), run["velocity"])
	_ticks = 0


func _sample() -> void:
	var state = _player.state
	var at: Vector3 = _player.ball_position()
	var on_wall := at.x > ON_WALL_X and at.y > ON_WALL_Y
	_run["top_speed"] = maxf(_run["top_speed"], state.velocity.length())
	_run["max_y"] = maxf(_run["max_y"], at.y)
	_run["first_vx_out"] = minf(_run["first_vx_out"], state.velocity.x)
	if state.carving:
		_run["carving"] += 1
	if state.grounded:
		_run["min_normal_y"] = minf(_run["min_normal_y"], state.contact_normal.y)
	if on_wall and not _run["jumped"]:
		_run["wall"] += 1
		if state.grounded:
			_run["wall_grounded"] += 1
			_run["wall_normal_x"] = minf(_run["wall_normal_x"], state.contact_normal.x)
		if state.grip_hold <= 0.0:
			_run["peeled_wall"] += 1
			if state.grounded:
				_run["peeled_wall_grounded"] += 1
		if _run.get("steer_on_wall", false) and _run["wall"] == 10:
			_run["steer_planar"] = Vector2(state.velocity.x, state.velocity.z).length()
			_source.hold = {"move": Vector2(0.0, 1.0)}
		if _run.has("steer_planar"):
			_run["steer_top"] = maxf(float(_run.get("steer_top", 0.0)), Vector2(state.velocity.x, state.velocity.z).length())
		if _run.get("jump_on_wall", false) and state.grounded and _run["wall"] >= 4:
			_run["jumped"] = true
			_run["jump_vx"] = state.velocity.x
			_source.press = {"jump_pressed": true}


func _physics_process(_delta: float) -> bool:
	if _run.is_empty():
		if _queue.is_empty():
			_finish()
			return true
		_start(_queue.pop_front())
		return false
	_ticks += 1
	_sample()
	if _run["jumped"] and not _run.has("after_jump_vx"):
		_run["jump_wait"] = int(_run.get("jump_wait", 0)) + 1
		if _run["jump_wait"] == 3:
			_run["after_jump_vx"] = _player.state.velocity.x
	if _ticks >= RUN_TICKS:
		_runs[_run["name"]] = _run
		print("run %s: %s" % [_run["name"], _summary(_run)])
		_run = {}
	return false


func _summary(run: Dictionary) -> String:
	return "wall %d grounded %d carving %d peeled %d/%d min_n %.2f top %.1f max_y %.1f" % [
		run["wall"], run["wall_grounded"], run["carving"], run["peeled_wall_grounded"], run["peeled_wall"],
		run["min_normal_y"], run["top_speed"], run["max_y"]]


func _finish() -> void:
	_rule_table()
	var carve: Dictionary = _runs["carve_nojump"]
	var gripped := int(carve["wall"]) - int(carve["peeled_wall"])
	var share := float(carve["wall_grounded"]) / maxf(1.0, float(gripped))
	_report("carve", gripped >= 10 and share >= CARVE_GROUNDED_SHARE and carve["min_normal_y"] < 0.1,
		"grip on, 27 m/s: %d wall ticks at grip speed, %.0f%% grounded (need %.0f%%), lowest ground normal y %.2f" % [
		gripped, share * 100.0, CARVE_GROUNDED_SHARE * 100.0, carve["min_normal_y"]])
	_report("carving", carve["carving"] >= carve["wall_grounded"],
		"state.carving on %d ticks, at least the %d grounded wall ticks" % [carve["carving"], carve["wall_grounded"]])
	var jump: Dictionary = _runs["carve"]
	var dvx := float(jump.get("after_jump_vx", 0.0)) - float(jump.get("jump_vx", 0.0))
	_report("wall_jump", jump["jumped"] and dvx < -4.0,
		"a jump from the gripped wall pushes off it: x velocity %.1f -> %.1f" % [
		float(jump.get("jump_vx", 0.0)), float(jump.get("after_jump_vx", 0.0))])
	var off: Dictionary = _runs["off"]
	_report("off", off["wall"] >= 5 and off["wall_grounded"] == 0 and off["min_normal_y"] >= Tuning.MAX_SLOPE_DOT,
		"--grip=off: %d wall ticks, %d grounded, lowest ground normal y %.2f" % [
		off["wall"], off["wall_grounded"], off["min_normal_y"]])
	var slow: Dictionary = _runs["slow"]
	_report("slow", slow["min_normal_y"] >= Tuning.MAX_SLOPE_DOT and slow["carving"] == 0,
		"grip on, 15 m/s (under the fast tier): lowest ground normal y %.2f, carving %d" % [
		slow["min_normal_y"], slow["carving"]])
	var peeled := 0
	var peeled_grounded := 0
	for name in _runs:
		peeled += int(_runs[name]["peeled_wall"])
		peeled_grounded += int(_runs[name]["peeled_wall_grounded"])
	_report("peel", peeled > 0 and peeled_grounded == 0,
		"%d wall ticks after the grip clock ran out, %d of them grounded" % [peeled, peeled_grounded])
	var steer: Dictionary = _runs["carve_steer"]
	_report("bank", steer.has("steer_planar") and float(steer.get("steer_top", 99.0)) <= float(steer["steer_planar"]) + 6.0,
		"a stick press mid-climb is no roll start: planar speed %.1f -> at most %.1f" % [
		float(steer.get("steer_planar", 0.0)), float(steer.get("steer_top", 0.0))])
	var land: Dictionary = _runs["land"]
	var land_gripped := int(land["wall"]) - int(land["peeled_wall"])
	_report("land", land_gripped >= 10 and land["wall_grounded"] >= land_gripped * CARVE_GROUNDED_SHARE
		and land["wall_normal_x"] < -0.9,
		"dropped beside the wall at 26 m/s along it: %d of %d grip-speed wall ticks grounded, face normal x %.2f" % [
		land["wall_grounded"], land_gripped, land["wall_normal_x"]])
	var vault: Dictionary = _runs["land_vault"]
	_report("land_vault", vault["wall"] >= 10 and vault["wall_grounded"] == 0,
		"Sable dropped beside the wall: %d wall ticks, %d grounded (her vault kick keeps faces met in the air)" % [
		vault["wall"], vault["wall_grounded"]])
	var head: Dictionary = _runs["head_on"]
	_report("head_on", head["wall_grounded"] == 0 and head["first_vx_out"] < -2.0,
		"straight into the wall at 26 m/s: %d grounded wall ticks, bounced back at %.1f m/s" % [
		head["wall_grounded"], -float(head["first_vx_out"])])
	var launch: float = (_runs["carve_nojump"]["velocity"] as Vector3).length()
	_report("speed", carve["top_speed"] <= off["top_speed"] + 0.25 and carve["top_speed"] <= launch + 0.25,
		"top speed %.2f with grip vs %.2f without, launch %.2f" % [carve["top_speed"], off["top_speed"], launch])
	print("wall_grip_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _rule_table() -> void:
	var tuning := Tuning.new()
	var state := BallState.new()
	state.velocity = Vector3(0.0, 20.0, 0.0)
	Rules.tick_grip(state, tuning, 1.0 / 60.0)
	_report("threshold", is_equal_approx(Rules.ground_dot(state, tuning), Tuning.GRIP_SLOPE_DOT),
		"at 20 m/s the ground threshold is the overhang's %.2f" % Rules.ground_dot(state, tuning))
	state.grounded = true
	state.contact_normal = Vector3(0.98, -0.17, 0.0).normalized()
	var press := Rules.downforce(state, tuning)
	var hang: float = tuning.f("gravity") * absf(state.contact_normal.y)
	_report("overhang", press.dot(-state.contact_normal) > hang,
		"on a 10 deg overhang the press %.1f m/s^2 beats gravity's pull off it %.1f" % [press.length(), hang])
	state.contact_normal = Vector3(0.0, 0.8, 0.6)
	_report("no_press", Rules.downforce(state, tuning) == Vector3.ZERO, "no press on a 37 deg bank or a kicker lip")
	state.velocity = Vector3(0.0, 10.0, 0.0)
	var t := 0.0
	while state.grip_hold > 0.0 and t < 1.0:
		Rules.tick_grip(state, tuning, 1.0 / 60.0)
		t += 1.0 / 60.0
	_report("peel_clock", absf(t - Tuning.GRIP_PEEL_S) < 0.02,
		"under the fast tier the grip lets go after %.2f s" % t)
	tuning.set_option("grip", "off")
	state.velocity = Vector3(0.0, 20.0, 0.0)
	Rules.tick_grip(state, tuning, 1.0 / 60.0)
	_report("toggle", is_equal_approx(Rules.ground_dot(state, tuning), Tuning.MAX_SLOPE_DOT),
		"--grip=off keeps today's %.2f threshold at speed" % Rules.ground_dot(state, tuning))
