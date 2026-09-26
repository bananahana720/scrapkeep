extends SceneTree

const Lab := preload("res://src/lab.gd")
const PlayerBall := preload("res://src/player_ball.gd")
const Augments := preload("res://src/augments.gd")
const Field := preload("res://src/field.gd")
const Hud := preload("res://src/hud.gd")

const SKY := Vector3(0.0, 150.0, 0.0)
const FLAT_SPOT := Vector2(20.0, 56.0)
const KICKER_SPOT := Vector2(30.0, 45.0)
const SLAM_DROP := 9.0
const SLAM_WINDOW := 1.6
const EXIT_SAMPLE := 0.1
const WINCH_SECONDS := 1.0
const WINCH_PAYOUT := 8.0
const MOUNT_HOLD := 2.0
const MOUNT_TOLERANCE := 0.1
const REPEL_WINDOW := 0.4
const PILLAR := Vector2(2.0, 40.0)
const PAUSE_SECONDS := 0.5


class ScriptedSource:
	extends RefCounted

	var hold := {}
	var press := {}

	func poll(out) -> void:
		out.clear()
		out.brake_held = hold.get("brake_held", false)
		out.reel_held = hold.get("reel_held", false)
		out.jump_pressed = press.get("jump_pressed", false)
		out.mount_pressed = press.get("mount_pressed", false)
		press = {}


var _lab
var _hud
var _source := ScriptedSource.new()
var _steps := []
var _index := 0
var _clock := 0.0
var _entered := false
var _started := false
var _failures := 0

var _slam := {}
var _slam_label := ""
var _winch := {}
var _aims := {}
var _mount := {}
var _repel := {}
var _pause := {}
var _interp := {}
var _dumped := {}


func _initialize() -> void:
	_lab = Lab.new()
	_lab.test_mode = true
	root.add_child(_lab)
	_steps = [
		{"enter": _park_enemies, "seconds": 0.05, "exit": _noop},
		{"enter": _enter_slam.bind("flat", FLAT_SPOT), "seconds": SLAM_WINDOW, "exit": _noop},
		{"enter": _enter_slam.bind("steep", KICKER_SPOT), "seconds": SLAM_WINDOW, "exit": _noop},
		{"enter": _enter_winch_spot, "seconds": 0.2, "exit": _start_winch},
		{"enter": _noop, "seconds": WINCH_SECONDS, "exit": _end_winch},
		{"enter": _enter_aim_spot, "seconds": 0.1, "exit": _check_aims},
		{"enter": _enter_wall_spot, "seconds": 0.05, "exit": _press.bind("mount_pressed")},
		{"enter": _noop, "seconds": MOUNT_HOLD, "exit": _press.bind("jump_pressed")},
		{"enter": _noop, "seconds": 0.25, "exit": _record_dismount},
		{"enter": _enter_pillar_spot, "seconds": 0.2, "exit": _mount_by_dummy},
		{"enter": _noop, "seconds": REPEL_WINDOW, "exit": _record_repel},
		{"enter": _enter_pause_drop, "seconds": 0.3, "exit": _start_pause},
		{"enter": _noop, "seconds": PAUSE_SECONDS, "exit": _end_pause},
		{"enter": _noop, "seconds": 0.3, "exit": _record_resume},
		{"enter": _enter_interp_drop, "seconds": 0.6, "exit": _end_interp},
		{"enter": _noop, "seconds": 0.05, "exit": _dump},
	]


func _process(delta: float) -> bool:
	if not _started:
		if _lab.player == null:
			return false
		_started = true
		_lab.player.source = _source
		_lab.player.set_mode(PlayerBall.RIGID)
		_hud = Hud.new()
		_lab.add_child(_hud)
		_hud.setup(_lab.player, _lab.tuning, _lab.camera.cam)
	if _index >= _steps.size():
		return _finish()
	var step: Dictionary = _steps[_index]
	if not _entered:
		_entered = true
		_clock = 0.0
		(step["enter"] as Callable).call()
		return false
	_clock += delta
	_watch_slam(delta)
	_watch_mount(delta)
	_watch_interp()
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


func _drop_at(point: Vector3, only: Array, hold: Dictionary) -> void:
	_lab.player.reset_to(point)
	for spec in Augments.SPECS:
		_lab.player.kit.set_on(spec["key"], spec["key"] in only)
	_source.hold = hold
	_source.press = {}


func _flat_speed() -> float:
	var v: Vector3 = _lab.player.state.velocity
	return Vector2(v.x, v.z).length()


# The dummies chase the ball; parked in a far corner they cannot reach any probe here.
func _park_enemies() -> void:
	for enemy in _lab.enemies:
		enemy.global_position = Field.drop_point(-100.0, 100.0, 1.6)


func _surface_y(spot: Vector2, from_y: float) -> float:
	var space: PhysicsDirectSpaceState3D = _lab.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(spot.x, from_y, spot.y), Vector3(spot.x, -20.0, spot.y), 1))
	return (hit["position"] as Vector3).y


# Brake starts the slam and is let go at once, so braking on the ground cannot eat the
# exit speed the plant hands back.
func _enter_slam(label: String, spot: Vector2) -> void:
	# Below the arch beam over the kicker, which sits about 21 m up.
	var ground := _surface_y(spot, 18.0)
	_slam_label = label
	_slam[label] = {"ground": ground, "planted_at": -1.0, "released_at": -1.0, "exit": -1.0, "exit_dir": Vector3.ZERO}
	_drop_at(Vector3(spot.x, ground + SLAM_DROP, spot.y), [Augments.SLAM], {"brake_held": true})


func _watch_slam(_delta: float) -> void:
	if _slam_label == "":
		return
	var kit = _lab.player.kit
	var row: Dictionary = _slam[_slam_label]
	if kit.slamming:
		_source.hold = {}
	if row["planted_at"] < 0.0 and kit.plant_time > 0.0:
		row["planted_at"] = _clock
		row["decided"] = kit.plant_total
		row["flat"] = kit.slam_flat
		row["pin"] = _lab.player.ball_position()
	if row["planted_at"] >= 0.0 and row["released_at"] < 0.0:
		row["drift"] = maxf(row.get("drift", 0.0), _lab.player.ball_position().distance_to(row["pin"]) if kit.plant_time > 0.0 else 0.0)
		if kit.plant_time <= 0.0:
			row["released_at"] = _clock
	if row["released_at"] >= 0.0 and row["exit"] < 0.0 and _clock - row["released_at"] >= EXIT_SAMPLE:
		row["exit"] = _flat_speed()
		row["exit_dir"] = _lab.player.state.velocity
		_slam_label = ""


func _enter_winch_spot() -> void:
	_drop_at(SKY + Vector3(10.0, -6.0, 0.0), [Augments.GRAPPLE], {})


# Tied at the ball's distance and then paid out, so the rope starts slack and a plain
# max-length reel would do nothing at all.
func _start_winch() -> void:
	_lab.player.active_body().set_velocity_now(Vector3.ZERO)
	_lab.player.grapple_to(SKY)
	_lab.player.reel_step(-WINCH_PAYOUT)
	var kit = _lab.player.kit
	_winch["start"] = _lab.player.ball_position().distance_to(SKY)
	_winch["rope"] = kit.rope
	_source.hold = {"reel_held": true}


func _end_winch() -> void:
	_winch["end"] = _lab.player.ball_position().distance_to(SKY)
	_winch["rope_end"] = _lab.player.kit.rope
	_source.hold = {}
	_lab.player.release_grapple()


func _aim_post() -> Vector3:
	var best: Vector3 = _lab.field.grapple_anchors[0]
	for anchor in _lab.field.grapple_anchors:
		if Vector2(anchor.x, anchor.z).distance_to(Vector2(46.0, 10.0)) < Vector2(best.x, best.z).distance_to(Vector2(46.0, 10.0)):
			best = anchor
	return best


func _enter_aim_spot() -> void:
	_drop_at(_aim_post() + Vector3(0.0, 3.0, 22.0), [Augments.GRAPPLE], {})


# For each aim, the reticle's reading must be the exact point the fire action hooks.
func _check_aims() -> void:
	var post := _aim_post()
	var from: Vector3 = _lab.player.ball_position() + Vector3(0.0, 1.5, 7.0)
	var cases := {
		"centre": post + Vector3(0.0, -1.5, 0.0),
		"assist": post + Vector3(0.0, 1.2, 0.0),
		"none": from + Vector3(0.0, 40.0, -8.0),
	}
	for label in cases:
		_lab.player.release_grapple()
		_lab.aim_along(from, (cases[label] as Vector3) - from)
		var shown: Dictionary = _hud.reticle.reading().duplicate()
		var fired: bool = _lab.fire_grapple()
		var kit = _lab.player.kit
		_aims[label] = {
			"state": shown["state"],
			"fired": fired,
			"hooked": kit.hooked,
			"gap": (kit.anchor as Vector3).distance_to(shown["point"]) if kit.hooked else -1.0,
			"to_post": (shown["point"] as Vector3).distance_to(post),
		}
	_lab.player.release_grapple()


func _enter_wall_spot() -> void:
	_drop_at(_lab.field.cling_spots[0], [Augments.PYLON], {})
	_mount = {"worst": 0.0, "samples": 0}


func _watch_mount(delta: float) -> void:
	var kit = _lab.player.kit
	if _mount.is_empty() or _mount.has("released") or not kit.mounted:
		return
	_mount["point"] = kit.mount_point
	_mount["worst"] = maxf(_mount["worst"], _lab.player.ball_position().distance_to(kit.mount_point))
	_mount["samples"] += 1
	_mount["time"] = _mount.get("time", 0.0) + delta


func _record_dismount() -> void:
	var kit = _lab.player.kit
	_mount["released"] = not kit.mounted
	_mount["off_face"] = (_lab.player.ball_position() - kit.mount_face).dot(kit.mount_normal)


func _enter_pillar_spot() -> void:
	var ball := Field.drop_point(PILLAR.x + 3.4, PILLAR.y, 1.2)
	_drop_at(ball, [Augments.PYLON], {})
	var enemy: Node3D = _lab.enemies[0]
	enemy.global_position = Field.drop_point(PILLAR.x + 7.5, PILLAR.y, 1.6)
	_repel = {"enemy": enemy}


func _dummy_gap(at: Vector3) -> float:
	var enemy: Node3D = _repel["enemy"]
	return Vector2(enemy.global_position.x - at.x, enemy.global_position.z - at.z).length()


func _mount_by_dummy() -> void:
	_repel["before"] = _dummy_gap(_lab.player.ball_position())
	_press("mount_pressed")


func _record_repel() -> void:
	var kit = _lab.player.kit
	_repel["mounted"] = kit.mounted
	_repel["gap"] = _dummy_gap(_lab.player.ball_position())
	_lab.player.kit.release_holds()


func _enter_pause_drop() -> void:
	_drop_at(SKY, [], {})


func _start_pause() -> void:
	_lab.toggle_pause()
	_pause["paused"] = paused
	_pause["from"] = _lab.player.ball_position()


func _end_pause() -> void:
	_pause["held"] = _lab.player.ball_position().distance_to(_pause["from"])
	_lab.toggle_pause()
	_pause["resumed_from"] = _lab.player.ball_position()


func _record_resume() -> void:
	_pause["after"] = _lab.player.ball_position().distance_to(_pause["resumed_from"])


func _enter_interp_drop() -> void:
	_drop_at(SKY, [], {})
	_interp = {"default": _lab.interpolating(), "worst": 0.0, "between": 0, "frames": 0}
	_interp["on"] = _lab.toggle_interpolation()


# With interpolation on, the drawn ball sits between physics ticks: close to the body,
# and on some frames not exactly on it.
func _watch_interp() -> void:
	if _interp.is_empty() or _interp.has("off"):
		return
	var gap: float = _lab.player.shown_position().distance_to(_lab.player.ball_position())
	_interp["worst"] = maxf(_interp["worst"], gap)
	_interp["frames"] += 1
	if gap > 0.001:
		_interp["between"] += 1


func _end_interp() -> void:
	_interp["off"] = not _lab.toggle_interpolation()


func _dump() -> void:
	var path: String = _lab.dump_tuning()
	_dumped["path"] = path
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) if path != "" else null
	_dumped["parsed"] = parsed if parsed is Dictionary else {}
	if path != "":
		DirAccess.remove_absolute(path)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _plant_seconds(row: Dictionary) -> float:
	if row["planted_at"] < 0.0 or row["released_at"] < 0.0:
		return -1.0
	return row["released_at"] - row["planted_at"]


func _finish() -> bool:
	var anchor_max: float = _lab.tuning.f("slam_anchor_max")
	var flat: Dictionary = _slam["flat"]
	var steep: Dictionary = _slam["steep"]
	var flat_held := _plant_seconds(flat)
	var steep_held := _plant_seconds(steep)
	# Held time is sampled at frame rate, so it can read one frame either side.
	_report("slam flat", absf(flat_held - anchor_max) < 0.06 and flat["exit"] >= 0.0 and flat["exit"] < 1.0 and flat.get("drift", 9.0) < 0.05,
		"flatness %.2f: planted %.2f s (decided %.2f, max %.2f), pinned within %.3f m, left at %.2f m/s horizontal (needs < 1.0)"
			% [flat.get("flat", -1.0), flat_held, flat.get("decided", -1.0), anchor_max, flat.get("drift", -1.0), flat["exit"]])
	var ramp_n: Vector3 = Basis(Vector3.RIGHT, deg_to_rad(-34.0)) * Vector3.UP
	var downhill: Vector3 = (Vector3.DOWN - ramp_n * Vector3.DOWN.dot(ramp_n)).normalized()
	var along: float = (steep["exit_dir"] as Vector3).dot(downhill)
	_report("slam steep", steep_held >= 0.0 and steep_held < flat_held - 0.05 and steep["exit"] > flat["exit"] + 5.0 and along > 5.0,
		"kicker flatness %.2f: planted %.2f s against %.2f flat, left at %.2f m/s horizontal against %.2f flat, %.2f m/s of it downhill"
			% [steep.get("flat", -1.0), steep_held, flat_held, steep["exit"], flat["exit"], along])
	_report("winch", _winch["end"] < _winch["start"] - 2.0 and _winch["rope"] > _winch["start"] + 1.0,
		"rope paid out to %.1f m with the ball %.1f m away (slack), holding Q for %.1f s hauled it to %.1f m (rope now %.1f m)"
			% [_winch["rope"], _winch["start"], WINCH_SECONDS, _winch["end"], _winch["rope_end"]])
	var centre: Dictionary = _aims["centre"]
	var assist: Dictionary = _aims["assist"]
	var none: Dictionary = _aims["none"]
	_report("aim centre", centre["state"] == Augments.AIM_REACH and centre["fired"] and centre["gap"] >= 0.0 and centre["gap"] < 0.0001 and centre["to_post"] < 3.0,
		"reticle state %d (reach = %d), fire hooked %s, hook %.4f m from the reticle's point, %.2f m from the post top"
			% [centre["state"], Augments.AIM_REACH, centre["hooked"], centre["gap"], centre["to_post"]])
	_report("aim assist", assist["state"] == Augments.AIM_ASSIST and assist["fired"] and assist["gap"] >= 0.0 and assist["gap"] < 0.0001 and assist["to_post"] < 3.0,
		"crosshair 1.2 m over the post: reticle state %d (assist = %d), fire hooked %s, hook %.4f m from the reticle's point, %.2f m from the post top"
			% [assist["state"], Augments.AIM_ASSIST, assist["hooked"], assist["gap"], assist["to_post"]])
	_report("aim none", none["state"] == Augments.AIM_NONE and not none["fired"] and not none["hooked"],
		"crosshair on open sky: reticle state %d (none = %d), fire hooked %s"
			% [none["state"], Augments.AIM_NONE, none["hooked"]])
	_report("mount", _mount.get("samples", 0) > 0 and _mount.get("time", 0.0) >= MOUNT_HOLD - 0.1 and _mount["worst"] < MOUNT_TOLERANCE,
		"mounted on the wall for %.2f s over %d frames, worst %.3f m from the mount point (needs < %.2f)"
			% [_mount.get("time", 0.0), _mount.get("samples", 0), _mount["worst"], MOUNT_TOLERANCE])
	_report("dismount", _mount.get("released", false) and _mount.get("off_face", 0.0) > Augments.MOUNT_OFFSET + 0.5,
		"Space released the mount (%s) and 0.25 s later the ball was %.2f m off the face (mounted at %.1f)"
			% [_mount.get("released", false), _mount.get("off_face", 0.0), Augments.MOUNT_OFFSET])
	var pushed: float = _repel.get("gap", 0.0) - _repel.get("before", 0.0)
	_report("repel", _repel.get("mounted", false) and pushed > 1.5,
		"planting on the pillar with a dummy %.2f m away pushed it out to %.2f m in %.1f s, %.2f m further (needs > 1.5)"
			% [_repel.get("before", 0.0), _repel.get("gap", 0.0), REPEL_WINDOW, pushed])
	_report("pause", _pause["paused"] and _pause["held"] < 0.001 and _pause["after"] > 1.0,
		"falling ball moved %.4f m in %.1f s paused (needs < 0.001) and %.2f m in 0.3 s after resuming"
			% [_pause["held"], PAUSE_SECONDS, _pause["after"]])

	_report("interpolation", not _interp["default"] and _interp["on"] and _interp["off"] and _interp["between"] > 0 and _interp["worst"] < 1.0,
		"default %s, F3 turned it %s then %s; the shown ball sat between ticks on %d of %d frames, at most %.3f m off the body (needs < 1.0)"
			% ["on" if _interp["default"] else "off", "on" if _interp["on"] else "off", "off" if _interp["off"] else "on",
				_interp["between"], _interp["frames"], _interp["worst"]])
	var record: Dictionary = _dumped["parsed"]
	var keys_match: bool = record.has("tuning") and (record["tuning"] as Dictionary).size() == _lab.tuning.SPECS.size()
	if keys_match:
		for spec in _lab.tuning.SPECS:
			keys_match = keys_match and absf(float(record["tuning"].get(spec["key"], INF)) - _lab.tuning.f(spec["key"])) < 0.0001
	_report("tuning dump", _dumped["path"] != "" and keys_match and record.get("physics_interpolation", true) == false,
		"F4 wrote %s with %d tuning values matching the live ones (%s) and interpolation %s"
			% [_dumped["path"].get_file(), (record.get("tuning", {}) as Dictionary).size(), keys_match, record.get("physics_interpolation", "missing")])

	print("kit_v2_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_lab.free()
	quit(0 if _failures == 0 else 1)
	return true
