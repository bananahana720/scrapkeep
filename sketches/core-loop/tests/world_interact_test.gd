extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Interactables := preload("res://src/world/interactables.gd")
const WordBudget := preload("res://src/core/word_budget.gd")

# The interact key (LOOP-REDESIGN section 9) in the running game, as Sable on stage 1 in
# calm. E takes an interactable in reach over a steep face and mounts at a bare face;
# a lock farther than the reach yields to the face; a move already under way (the hook
# in) keeps E. A tap never arms a hold and a held E arms it after HOLD_SECONDS. A lock
# made at 40 m/s finishes its hold after the ball has passed the device, at speed. A
# roll-through lane fires at 30 m/s as the ball crosses its mouth without slowing it,
# and a ball that crosses wide of the mouth fires nothing and loses nothing. Every
# stage-1 prompt shows at most PROMPT_WORDS words.


class Probe:
	extends "res://src/world/device.gd"

	var fired_at := -1
	var fired_ball := Vector3.ZERO
	var fired_speed := 0.0

	func fire() -> bool:
		fired_at = Engine.get_physics_frames()
		fired_ball = ctx.player.ball_position()
		fired_speed = ctx.player.planar_velocity().length()
		return true


const SABLE := 0
# Flat top shelf clear of the vault, stampede ring and wave-3 relay mesa (2026-10-03).
const LANE_START := Vector2(54.0, -104.0)
const LANE_SPEED := 30.0
const PASS_SPEED := 40.0
const PASS_AHEAD := 10.0

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _steps: Array = []
var _index := 0
var _ticks := 0
var _entered := false
var _facts := {"interact_armed": [], "interact_fired": []}
var _probe
var _wall: StaticBody3D
var _lane := {}
var _hold_pressed_at := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if _steps.is_empty():
		_begin()
		return false
	if _index >= _steps.size():
		print("world_interact_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		quit(0 if _failures == 0 else 1)
		return true
	var step: Array = _steps[_index]
	if not _entered:
		_entered = true
		_ticks = 0
		(step[0] as Callable).call()
		return false
	_ticks += 1
	if _ticks < int(step[1]):
		return false
	(step[2] as Callable).call()
	_index += 1
	_entered = false
	return false


func _begin() -> void:
	_game.player.source = _source
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(SABLE)
	for kind in _facts:
		_game.events.connect(kind, func(family: String, device_id: String, _at: Vector3): _facts[kind].append([family, device_id]))
	_steps = [
		[_noop, 30, _noop],
		[_face_with_probe.bind(3.0), 20, _press_e],
		[_noop, 6, _check_probe_wins],
		[_bare_face, 20, _press_e],
		[_noop, 12, _check_mounts],
		[_face_with_probe.bind(12.0), 20, _press_e],
		[_noop, 12, _check_far_yields],
		[_hooked_at_face, 3, _press_e],
		[_noop, 12, _check_hook_kept],
		[_pass_at_speed, 2, _hold_e],
		[_noop, 60, _check_pass],
		[_hold_probe, 20, _tap_e],
		[_noop, 40, _check_tap],
		[_noop, 2, _hold_e],
		[_noop, 40, _check_hold],
		[_lane_run.bind(0.0), 2, _press_e],
		[_noop, 24, _check_lane_fired],
		[_lane_run.bind(4.5), 2, _press_e],
		[_noop, 24, _check_lane_missed],
		[_noop, 1, _check_words],
	]


func _noop() -> void:
	pass


func _interact():
	return _game.world.interact


func _forward() -> Vector3:
	var f: Vector3 = -_game.camera.yaw_basis().z
	return Vector3(f.x, 0.0, f.z).normalized()


func _place(at: Vector3, velocity := Vector3.ZERO) -> void:
	_game.player.reset_to(at, velocity)
	_game.player.body().global_position = at
	_source.hold = {}
	_source.press = {}


func _ground(x: float, z: float) -> Vector3:
	return _game.ctx.terrain.drop_point(x, z, 1.05)


func _press_e() -> void:
	_source.press["mount_pressed"] = true


func _tap_e() -> void:
	_source.press["mount_pressed"] = true
	_source.press["mount_held"] = true


func _hold_e() -> void:
	_facts["interact_armed"].clear()
	_hold_pressed_at = Engine.get_physics_frames()
	_source.press["mount_pressed"] = true
	_source.hold["mount_held"] = true


# A steep wall right beside the ball (the pylon's face) and a probe `ahead` metres on.
func _face_with_probe(ahead: float) -> void:
	_clear_probe()
	var ball := _ground(-62.0, -160.0)
	_place(ball)
	var side := _forward().cross(Vector3.UP)
	if _wall != null:
		_wall.queue_free()
	_wall = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 12.0, 20.0)
	shape.shape = box
	_wall.add_child(shape)
	_game.add_child(_wall)
	_wall.global_position = ball + side * 2.3
	_wall.look_at(_wall.global_position + _forward(), Vector3.UP)
	_probe = _add_probe("secret", ball + _forward() * ahead)


func _clear_probe() -> void:
	if _probe != null and is_instance_valid(_probe):
		_interact().devices.erase(_probe)
		_probe.queue_free()
	_probe = null
	if _game.player.kit.mounted:
		_source.press["mount_pressed"] = true


func _add_probe(family: String, at: Vector3):
	var probe := Probe.new()
	probe.family = family
	_interact().add_child(probe)
	probe.global_position = at - Vector3.UP
	probe.setup(_game.ctx, _interact(), {"id": "probe_" + family})
	_interact().register(probe)
	return probe


func _check_probe_wins() -> void:
	var kit = _game.player.kit
	_report("interactable over a face", _probe.fired_at > 0 and not kit.mounted,
		"Sable at a steep face with a probe in reach: E fired the probe %s, mounted %s" % [_probe.fired_at > 0, kit.mounted])


func _bare_face() -> void:
	_clear_probe()
	var ball := _ground(-62.0, -160.0)
	_place(ball)


func _check_mounts() -> void:
	var kit = _game.player.kit
	_report("mount at a bare face", kit.mounted, "no interactable in reach: E planted the pylon, mounted %s" % kit.mounted)
	_source.press["mount_pressed"] = true


func _check_far_yields() -> void:
	var kit = _game.player.kit
	_report("a far lock yields to a face", _probe.fired_at < 0 and kit.mounted and _interact().target == _probe,
		"probe locked 12 m ahead, a face beside the ball: E mounted %s, probe fired %s" % [kit.mounted, _probe.fired_at > 0])
	_source.press["mount_pressed"] = true


# The hook in the wall beside the ball, a probe 3 m ahead: the grapple is under way.
func _hooked_at_face() -> void:
	_face_with_probe(3.0)
	var ball: Vector3 = _game.player.ball_position()
	var side := _forward().cross(Vector3.UP)
	_game.player.grapple_to(ball + side * 1.8, -side)


func _check_hook_kept() -> void:
	var kit = _game.player.kit
	_report("a started move keeps E", _probe.fired_at < 0 and kit.mounted,
		"hooked into the face with a probe in reach: E mounted %s, probe fired %s" % [kit.mounted, _probe.fired_at > 0])
	_game.player.release_grapple()
	_source.press["mount_pressed"] = true


# 40 m/s along the lane's line, a hold probe PASS_AHEAD metres on and 3 m to the side:
# E held from the lock, the ball passes the probe before the hold is done.
func _pass_at_speed() -> void:
	_clear_probe()
	if _wall != null:
		_wall.queue_free()
		_wall = null
	var heading := Vector3(1.0, 0.0, 0.0)
	_game.camera.snap(heading)
	var start := _ground(LANE_START.x, LANE_START.y)
	_place(start, heading * PASS_SPEED)
	var at := _ground(LANE_START.x + PASS_AHEAD, LANE_START.y + 3.0)
	_probe = _add_probe("fight", at)
	_facts["interact_armed"].clear()


func _check_pass() -> void:
	_source.hold = {}
	var passed: float = _probe.fired_ball.x - _probe.reach_point().x
	_report("a lock at speed completes", _probe.fired_at > 0 and passed > 0.0 and _probe.fired_speed >= PASS_SPEED * 0.8,
		"locked %.0f m ahead at %.0f m/s, E held: fired %s with the ball %.1f m past the probe at %.1f m/s"
			% [PASS_AHEAD, PASS_SPEED, _probe.fired_at > 0, passed, _probe.fired_speed])


func _hold_probe() -> void:
	_clear_probe()
	var ball := _ground(-62.0, -160.0)
	_place(ball)
	_facts["interact_armed"].clear()
	_probe = _add_probe("fight", ball + _forward() * 3.0)


func _check_tap() -> void:
	_report("a tap does nothing", _probe.fired_at < 0 and _facts["interact_armed"].is_empty(),
		"E pressed for one tick at a hold device: fired %s, armed facts %d" % [_probe.fired_at > 0, _facts["interact_armed"].size()])


func _check_hold() -> void:
	var took := float(_probe.fired_at - _hold_pressed_at) / Engine.physics_ticks_per_second
	_report("a hold arms", _probe.fired_at > 0 and _facts["interact_armed"].size() == 1 and took >= Interactables.HOLD_SECONDS - 0.05,
		"E held: fired after %.2f s (needs %.2f), armed facts %d" % [took, Interactables.HOLD_SECONDS, _facts["interact_armed"].size()])
	_source.hold = {}
	_interact().devices.erase(_probe)
	_probe.queue_free()


# A lane pointing east on the top shelf; the ball starts 8 m back at LANE_SPEED, offset
# across the lane by `wide` metres.
func _lane_run(wide: float) -> void:
	for device in _lane.get("devices", []):
		_interact().devices.erase(device)
		device.queue_free()
	var heading := Vector3(1.0, 0.0, 0.0)
	var mouth: Vector3 = _game.ctx.terrain.drop_point(LANE_START.x + 8.0, LANE_START.y, 0.0)
	var fires: Array = []
	var device = _interact().travel("probe_lane", mouth, heading, func(_ball: Vector3, v: Vector3): fires.append(Vector2(v.x, v.z).length()))
	var start := _ground(LANE_START.x, LANE_START.y + wide)
	_place(start, heading * LANE_SPEED)
	_lane = {"devices": [device], "fires": fires, "device": device, "scrap": _game.run.scrap, "hp": _game.run.hp}
	_facts["interact_fired"].clear()
	_facts["interact_armed"].clear()


func _check_lane_fired() -> void:
	var fires: Array = _lane["fires"]
	var speed: float = fires[0] if not fires.is_empty() else 0.0
	_report("roll-through at speed", fires.size() == 1 and speed >= LANE_SPEED * 0.8,
		"E in the lane at %.0f m/s: fired %d time(s), ball at %.1f m/s as it crossed the mouth" % [LANE_SPEED, fires.size(), speed])


func _check_lane_missed() -> void:
	var fires: Array = _lane["fires"]
	var speed: float = _game.player.planar_velocity().length()
	var armed_after: bool = _lane["device"].roll.armed
	var armed: int = _facts["interact_armed"].size()
	_report("a missed mouth costs nothing", armed == 1 and fires.is_empty() and not armed_after and speed >= LANE_SPEED * 0.8
		and _game.run.scrap == _lane["scrap"] and _game.run.hp == _lane["hp"],
		"armed %d time(s) in the lane, crossed 4.5 m wide of the mouth: fired %d, still armed %s, %.1f m/s kept, scrap and health unchanged"
			% [armed, fires.size(), armed_after, speed])


func _check_words() -> void:
	var counts := PackedStringArray()
	var worst := 0
	for device in _interact().devices:
		var n := WordBudget.words_in(device.words())
		worst = maxi(worst, n)
		counts.append("%s \"%s\" %d" % [device.id, device.words(), n])
	for cores in [1, 2, 5]:
		_game.run.bonus_cores = cores
		for device in _interact().devices:
			if device.family == "bet":
				var n := WordBudget.words_in(device.words())
				worst = maxi(worst, n)
				counts.append("%s at %d cores \"%s\" %d" % [device.id, cores, device.words(), n])
	_game.run.bonus_cores = 0
	print("  prompts: " + " | ".join(counts))
	_report("prompt words", worst <= Interactables.PROMPT_WORDS and counts.size() >= 5,
		"%d stage-1 prompts, the longest %d words (limit %d)" % [counts.size(), worst, Interactables.PROMPT_WORDS])
