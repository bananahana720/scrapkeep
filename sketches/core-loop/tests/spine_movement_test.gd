extends SceneTree

const GameEvents := preload("res://src/core/game_events.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const Augments := preload("res://src/movement/augments.gd")
const Intent := preload("res://src/movement/intent.gd")

# The mobility kit v2 essentials, rerun on this sketch's copy of the movement core in a
# small fixture world (a floor, a 34 degree ramp, a wall and a post): the angle-blended
# slam, the winch, the grapple aim record, and the pylon with its banked slingshot.

const RAMP_DEG := 34.0
const RAMP_AT := Vector3(80.0, 8.0, 0.0)
const WALL_FACE_X := -59.0
const POST_TOP := Vector3(0.0, 12.0, -60.0)
const SKY := Vector3(0.0, 150.0, 0.0)
const FLAT_SPOT := Vector2(20.0, 40.0)
const SLAM_DROP := 9.0
const SLAM_WINDOW := 1.6
const EXIT_SAMPLE := 0.1
const WINCH_SECONDS := 1.0
const WINCH_PAYOUT := 8.0
const MOUNT_HOLD := 1.0
const MOUNT_TOLERANCE := 0.1
const ALONG_FACE := 12.0

var _world: Node3D
var _events
var _tuning
var _player
var _source := Intent.Scripted.new()
var _steps := []
var _index := 0
var _clock := 0.0
var _entered := false
var _failures := 0

var _slam := {}
var _slam_label := ""
var _winch := {}
var _aims := {}
var _mount := {}
var _facts := {"mounted": [], "dismounted": [], "slammed": []}


func _initialize() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_box(Vector3(400.0, 2.0, 400.0), Vector3(0.0, -1.0, 0.0), Basis.IDENTITY)
	_box(Vector3(24.0, 1.0, 40.0), RAMP_AT, Basis(Vector3.RIGHT, deg_to_rad(RAMP_DEG)))
	_box(Vector3(2.0, 20.0, 60.0), Vector3(WALL_FACE_X - 1.0, 10.0, 0.0), Basis.IDENTITY)
	_box(Vector3(1.5, POST_TOP.y, 1.5), POST_TOP - Vector3.UP * POST_TOP.y * 0.5, Basis.IDENTITY)
	_events = GameEvents.new()
	_world.add_child(_events)
	_events.mounted.connect(func(at: Vector3, banked: float): _facts["mounted"].append(banked))
	_events.dismounted.connect(func(v: Vector3): _facts["dismounted"].append(v))
	_events.slammed.connect(func(_at: Vector3, strength: float, _flat: float): _facts["slammed"].append(strength))
	_tuning = Tuning.new()
	_player = PlayerBall.new()
	_world.add_child(_player)
	_player.setup(_tuning, _events, SKY)
	_player.source = _source
	_steps = [
		{"enter": _enter_slam.bind("flat", Vector3(FLAT_SPOT.x, 0.0, FLAT_SPOT.y)), "seconds": SLAM_WINDOW, "exit": _noop},
		{"enter": _enter_slam.bind("steep", RAMP_AT), "seconds": SLAM_WINDOW, "exit": _noop},
		{"enter": _drop_at.bind(SKY + Vector3(10.0, -6.0, 0.0), Vector3.ZERO, {}), "seconds": 0.2, "exit": _start_winch},
		{"enter": _noop, "seconds": WINCH_SECONDS, "exit": _end_winch},
		{"enter": _drop_at.bind(POST_TOP + Vector3(0.0, 3.0, 22.0), Vector3.ZERO, {}), "seconds": 0.1, "exit": _check_aims},
		{"enter": _enter_wall, "seconds": 0.12, "exit": _press.bind("mount_pressed")},
		{"enter": _noop, "seconds": MOUNT_HOLD, "exit": _press.bind("jump_pressed")},
		{"enter": _noop, "seconds": 0.25, "exit": _record_dismount},
	]


func _box(size: Vector3, at: Vector3, basis: Basis) -> void:
	var body := StaticBody3D.new()
	body.transform = Transform3D(basis, at)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)


func _process(delta: float) -> bool:
	if _index >= _steps.size():
		return _finish()
	var step: Dictionary = _steps[_index]
	if not _entered:
		_entered = true
		_clock = 0.0
		(step["enter"] as Callable).call()
		return false
	_clock += delta
	_watch_slam()
	_watch_mount(delta)
	if _clock < float(step["seconds"]):
		return false
	(step["exit"] as Callable).call()
	_index += 1
	_entered = false
	return false


func _noop() -> void:
	pass


func _press(key: String) -> void:
	_source.press[key] = true


func _drop_at(point: Vector3, velocity: Vector3, hold: Dictionary) -> void:
	_player.reset_to(point, velocity)
	_player.body().global_position = point
	_source.hold = hold
	_source.press = {}


func _flat_speed() -> float:
	return _player.planar_velocity().length()


func _surface_y(x: float, z: float) -> float:
	var space: PhysicsDirectSpaceState3D = _world.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60.0, z), Vector3(x, -20.0, z), 1))
	return (hit["position"] as Vector3).y


# Brake starts the slam and is let go at once, so braking on the ground cannot eat the
# exit speed the plant hands back.
func _enter_slam(label: String, spot: Vector3) -> void:
	var ground := _surface_y(spot.x, spot.z)
	_slam_label = label
	_slam[label] = {"planted_at": -1.0, "released_at": -1.0, "exit": -1.0, "exit_dir": Vector3.ZERO}
	_drop_at(Vector3(spot.x, ground + SLAM_DROP, spot.z), Vector3.ZERO, {"brake_held": true})


func _watch_slam() -> void:
	if _slam_label == "":
		return
	var kit = _player.kit
	var row: Dictionary = _slam[_slam_label]
	if kit.slamming:
		_source.hold = {}
	if row["planted_at"] < 0.0 and kit.plant_time > 0.0:
		row["planted_at"] = _clock
		row["decided"] = kit.plant_total
		row["flat"] = kit.slam_flat
		row["pin"] = _player.ball_position()
	if row["planted_at"] >= 0.0 and row["released_at"] < 0.0:
		if kit.plant_time > 0.0:
			row["drift"] = maxf(row.get("drift", 0.0), _player.ball_position().distance_to(row["pin"]))
		else:
			row["released_at"] = _clock
	if row["released_at"] >= 0.0 and row["exit"] < 0.0 and _clock - row["released_at"] >= EXIT_SAMPLE:
		row["exit"] = _flat_speed()
		row["exit_dir"] = _player.state.velocity
		_slam_label = ""


# Tied at the ball's distance and then paid out, so the rope starts slack and a plain
# max-length reel would do nothing at all.
func _start_winch() -> void:
	_player.set_velocity_now(Vector3.ZERO)
	_player.grapple_to(SKY)
	_player.kit.rope = minf(_player.kit.rope + WINCH_PAYOUT, _player.grapple_range())
	_winch["start"] = _player.ball_position().distance_to(SKY)
	_winch["rope"] = _player.kit.rope
	_source.hold = {"brake_held": true}


func _end_winch() -> void:
	_winch["end"] = _player.ball_position().distance_to(SKY)
	_source.hold = {}
	_player.release_grapple()


# For each aim, the stored aim record is the exact point the fire action hooks.
func _check_aims() -> void:
	var from: Vector3 = _player.ball_position() + Vector3(0.0, 1.5, 7.0)
	var cases := {
		"centre": POST_TOP + Vector3(0.0, -1.5, 0.0),
		"assist": POST_TOP + Vector3(0.0, 1.2, 0.0),
		"none": from + Vector3(0.0, 40.0, -8.0),
	}
	var space: PhysicsDirectSpaceState3D = _world.get_world_3d().direct_space_state
	for label in cases:
		_player.release_grapple()
		var aim := Augments.grapple_target(space, from, (cases[label] as Vector3) - from,
			_player.ball_position(), _player.grapple_range(), _tuning.f("grapple_assist_deg"))
		_player.kit.aim = aim
		if aim["state"] != Augments.AIM_NONE:
			_player.grapple_to(aim["point"], aim["normal"])
		var kit = _player.kit
		_aims[label] = {
			"state": aim["state"],
			"hooked": kit.hooked,
			"gap": (kit.anchor as Vector3).distance_to(aim["point"]) if kit.hooked else -1.0,
			"to_post": (aim["point"] as Vector3).distance_to(POST_TOP),
		}
	_player.release_grapple()


# Rolling along the wall 1.8 m off its face, so the plant has speed to bank.
func _enter_wall() -> void:
	_drop_at(Vector3(WALL_FACE_X + 1.8, 1.0, -12.0), Vector3(0.0, 0.0, ALONG_FACE), {})
	_mount = {"worst": 0.0, "samples": 0, "time": 0.0}


func _watch_mount(delta: float) -> void:
	var kit = _player.kit
	if _mount.is_empty() or _mount.has("released") or not kit.mounted:
		return
	_mount["point"] = kit.mount_point
	_mount["worst"] = maxf(_mount["worst"], _player.ball_position().distance_to(kit.mount_point))
	_mount["samples"] += 1
	_mount["time"] += delta


func _record_dismount() -> void:
	var kit = _player.kit
	_mount["released"] = not kit.mounted
	_mount["off_face"] = (_player.ball_position() - kit.mount_face).dot(kit.mount_normal)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _plant_seconds(row: Dictionary) -> float:
	if row["planted_at"] < 0.0 or row["released_at"] < 0.0:
		return -1.0
	return row["released_at"] - row["planted_at"]


func _finish() -> bool:
	var anchor_max: float = _tuning.f("slam_anchor_max")
	var flat: Dictionary = _slam["flat"]
	var steep: Dictionary = _slam["steep"]
	var flat_held := _plant_seconds(flat)
	var steep_held := _plant_seconds(steep)
	# Held time is sampled at frame rate, so it can read one frame either side.
	_report("slam flat", absf(flat_held - anchor_max) < 0.06 and flat["exit"] >= 0.0 and flat["exit"] < 1.0 and flat.get("drift", 9.0) < 0.05,
		"flatness %.2f: planted %.2f s (max %.2f), pinned within %.3f m, left at %.2f m/s horizontal (needs < 1.0)"
			% [flat.get("flat", -1.0), flat_held, anchor_max, flat.get("drift", -1.0), flat["exit"]])
	var ramp_n: Vector3 = Basis(Vector3.RIGHT, deg_to_rad(RAMP_DEG)) * Vector3.UP
	var downhill: Vector3 = (Vector3.DOWN - ramp_n * Vector3.DOWN.dot(ramp_n)).normalized()
	var along: float = (steep["exit_dir"] as Vector3).dot(downhill)
	_report("slam steep", steep_held >= 0.0 and steep_held < flat_held - 0.05 and steep["exit"] > flat["exit"] + 5.0 and along > 5.0,
		"%.0f deg ramp flatness %.2f: planted %.2f s against %.2f flat, left at %.2f m/s horizontal, %.2f m/s of it downhill"
			% [RAMP_DEG, steep.get("flat", -1.0), steep_held, flat_held, steep["exit"], along])
	_report("slam fact", _facts["slammed"].size() == 2, "GameEvents.slammed published %d times for 2 slams" % _facts["slammed"].size())
	_report("winch", _winch["end"] < _winch["start"] - 2.0 and _winch["rope"] > _winch["start"] + 1.0,
		"rope paid out to %.1f m with the ball %.1f m away (slack); holding Q %.1f s hauled it to %.1f m"
			% [_winch["rope"], _winch["start"], WINCH_SECONDS, _winch["end"]])
	var centre: Dictionary = _aims["centre"]
	var assist: Dictionary = _aims["assist"]
	var none: Dictionary = _aims["none"]
	_report("aim centre", centre["state"] == Augments.AIM_REACH and centre["hooked"] and centre["gap"] >= 0.0 and centre["gap"] < 0.0001 and centre["to_post"] < 3.0,
		"aim state %d (reach = %d), hook %.4f m from the aim point, %.2f m from the post top"
			% [centre["state"], Augments.AIM_REACH, centre["gap"], centre["to_post"]])
	_report("aim assist", assist["state"] == Augments.AIM_ASSIST and assist["hooked"] and assist["gap"] >= 0.0 and assist["gap"] < 0.0001 and assist["to_post"] < 3.0,
		"crosshair 1.2 m over the post: aim state %d (assist = %d), hook %.4f m from the aim point, %.2f m from the post top"
			% [assist["state"], Augments.AIM_ASSIST, assist["gap"], assist["to_post"]])
	_report("aim none", none["state"] == Augments.AIM_NONE and not none["hooked"],
		"crosshair on open sky: aim state %d (none = %d), hooked %s" % [none["state"], Augments.AIM_NONE, none["hooked"]])
	_report("mount", _mount["samples"] > 0 and _mount["time"] >= MOUNT_HOLD - 0.1 and _mount["worst"] < MOUNT_TOLERANCE,
		"mounted on the wall for %.2f s over %d frames, worst %.3f m from the mount point (needs < %.2f)"
			% [_mount["time"], _mount["samples"], _mount["worst"], MOUNT_TOLERANCE])
	var banked: float = _facts["mounted"][0] if _facts["mounted"].size() > 0 else -1.0
	var eject: Vector3 = _facts["dismounted"][0] if _facts["dismounted"].size() > 0 else Vector3.ZERO
	var promised := maxf(_tuning.f("jump_speed"), banked * _tuning.f("slingshot_keep") + _tuning.f("slingshot_boost"))
	_report("momentum bank", banked > ALONG_FACE * 0.6 and absf(eject.length() - promised) < 0.05 and eject.length() > _tuning.f("jump_speed"),
		"planted rolling at %.0f m/s: banked %.2f m/s, Space ejected at %.2f m/s (banked x %.2f + %.1f = %.2f; a plain jump is %.1f)"
			% [ALONG_FACE, banked, eject.length(), _tuning.f("slingshot_keep"), _tuning.f("slingshot_boost"), promised, _tuning.f("jump_speed")])
	_report("dismount", _mount.get("released", false) and _mount.get("off_face", 0.0) > Augments.MOUNT_OFFSET + 0.5,
		"Space released the mount (%s) and 0.25 s later the ball was %.2f m off the face (mounted at %.1f)"
			% [_mount.get("released", false), _mount.get("off_face", 0.0), Augments.MOUNT_OFFSET])
	print("spine_movement_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_world.free()
	quit(0 if _failures == 0 else 1)
	return true
