extends SceneTree

const GameEvents := preload("res://src/core/game_events.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const Augments := preload("res://src/movement/augments.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
const Indicator := preload("res://src/movement/indicator.gd")

# The hosted movement bug hunt (wave 12, bughunt/movement/bug-report.md), on the real rigid
# ball in a small fixture world. Each check names its finding: the sprint kick follows the
# roll (1), the rigid ball pays the over-speed drag in the air and not on the ground (2,
# re-specified by HOOK-FIX 2026-10-09), the harpoon press obeys
# the busy rule verb_ready shows (3), the hook ray never returns an enemy behind the ball
# (5), a collapsing marks shape shrinks in place (6), and a bow-crush smash landing sets
# smash_landing for its strike (7). Finding 4 is a doc-only change (harpoon.gd).

const OPEN := Vector3(90.0, 1.0, 0.0)
const DRAG_LANE := Vector3(-150.0, 1.0, -150.0)
const RAY_BALL := Vector3(0.0, 6.0, 150.0)
const KICK := 8.0
const DRAG_TICKS := 30
const DRAG_SPEED := 30.0
const AIR_LIFT := Vector3(0.0, 40.0, 0.0)


# A hookable enemy stand-in: in the enemy group, on the enemy layer, and able to take the
# landing's shove.
class Post:
	extends CharacterBody3D

	var weight := 0.5
	var radius := 1.0

	func knock(_direction: Vector3, _force: float) -> void:
		pass

	func flash() -> void:
		pass


var _world: Node3D
var _events
var _player
var _tuning
var _source := Intent.Scripted.new()
var _failures := 0
var _steps := []
var _index := 0
var _ticks := 0
var _sprints := []
var _record := {}
var _posts: Array[Post] = []


func _initialize() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_box(Vector3(600.0, 2.0, 600.0), Vector3(0.0, -1.0, 0.0))
	_box(Vector3(20.0, 20.0, 2.0), RAY_BALL + Vector3(0.0, 0.0, -20.0))
	for i in 3:
		_posts.append(_post(RAY_BALL + Vector3(0.0, 0.0, 3.0 * (i + 1))))
	_events = GameEvents.new()
	_world.add_child(_events)
	_events.sprint_started.connect(func(dir: Vector3): _sprints.append(dir))
	_tuning = Tuning.new()
	_record["cruise"] = _tuning.f("cruise")
	_player = PlayerBall.new()
	_world.add_child(_player)
	_player.setup(_tuning, _events, Vector3(0.0, 50.0, 0.0))
	_player.source = _source
	_steps = [
		[_noop, 3, _marks_collapse_in_place],
		[_sprint_start, 3, _check_sprint],
		[_drag_start.bind(_tuning.f("cruise"), Vector3.ZERO), DRAG_TICKS, _drag_end.bind("live")],
		[_drag_start.bind(40.0, Vector3.ZERO), DRAG_TICKS, _drag_end.bind("no_quad")],
		[_drag_start.bind(_tuning.f("cruise"), AIR_LIFT), DRAG_TICKS, _drag_end.bind("air_live")],
		[_drag_start.bind(40.0, AIR_LIFT), DRAG_TICKS, _drag_end.bind("air_no_quad")],
		[_noop, 2, _check_drag],
		[_noop, 2, _harpoon_busy],
		[_noop, 2, _hook_ray_behind],
		[_noop, 2, _crush_landing],
	]


func _box(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)


func _post(at: Vector3) -> Post:
	var post := Post.new()
	post.add_to_group("enemy")
	post.collision_layer = Augments.ENEMY_MASK
	post.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	post.add_child(shape)
	_world.add_child(post)
	post.position = at
	return post


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _index >= _steps.size():
		print("movement_bughunt_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		quit(0 if _failures == 0 else 1)
		return true
	var step: Array = _steps[_index]
	if _ticks == 0:
		(step[0] as Callable).call()
	_ticks += 1
	if _ticks >= int(step[1]):
		(step[2] as Callable).call()
		_index += 1
		_ticks = 0
	return false


func _noop() -> void:
	pass


func _planar() -> float:
	var v: Vector3 = _player.state.velocity
	return Vector2(v.x, v.z).length()


# Finding 6: a marks shape halfway through its collapse is drawn around its own points,
# not halfway to the world origin; each mark shrinks about itself.
func _marks_collapse_in_place() -> void:
	var ind := Indicator.new()
	root.add_child(ind)
	ind.set_process(false)
	ind.set_shape("slam", {"kind": "marks", "points": [Vector3(50.0, 0.0, 50.0)], "color": Color.WHITE})
	ind.collapse("slam")
	ind._process(Indicator.COLLAPSE * 0.5)
	var one: AABB = ind._tris.get_aabb()
	var centre := one.get_center()
	_report("6 marks collapse in place", Vector2(centre.x - 50.0, centre.z - 50.0).length() < 0.2,
		"one mark at (50, 0, 50), half collapsed, drawn around (%.2f, %.2f)" % [centre.x, centre.z])
	ind.set_shape("slam", {"kind": "marks", "points": [Vector3(50.0, 0.0, 50.0), Vector3(60.0, 0.0, 50.0)], "color": Color.WHITE})
	ind.collapse("slam")
	ind._process(Indicator.COLLAPSE * 0.5)
	var two: AABB = ind._tris.get_aabb()
	_report("6 every mark shrinks about itself", two.position.x > 49.0 and two.end.x > 59.5 and two.end.x < 61.0,
		"marks at x 50 and 60, half collapsed, drawn from x %.2f to %.2f" % [two.position.x, two.end.x])
	ind.free()


# Finding 1: Rivet's sprint starts on a ball rolling +Z; the kick and the fact point +Z.
func _sprint_start() -> void:
	_player.fit_class(ClassDef.by_id("runner_gunner"))
	_player.kit.tree._knobs["sprint_kick"] = KICK
	_player.reset_to(OPEN, Vector3(0.0, 0.0, 10.0))
	_sprints.clear()
	_source.hold = {"movement_held": true}
	_source.press = {"movement_pressed": true}


func _check_sprint() -> void:
	_source.hold = {}
	var dir: Vector3 = _sprints[0] if not _sprints.is_empty() else Vector3.ZERO
	var vz: float = _player.state.velocity.z
	_report("1 sprint kick along the roll", _sprints.size() == 1 and dir.z > 0.99 and vz > 10.0 + KICK * 0.8,
		"rolling +Z at 10 m/s, kick %.1f: sprint_started dir (%.2f, %.2f, %.2f), velocity z %.2f"
			% [KICK, dir.x, dir.y, dir.z, vz])


# Finding 2, re-specified by HOOK-FIX (2026-10-09): the same ball over the same ticks, once
# with the over-speed term live and once with cruise raised past the speed so the term is
# zero, rolling on the ground and then flying. The rigid ball is the game's authority
# (TADR-006) and Andrew chose it for its momentum, so on the ground it keeps its
# over-cruise speed (the designed rides to the sky layer and the two-hook apex need it);
# in the air it pays the term (rigid_ball.gd, ball_rules.over_speed_drag).
func _drag_start(cruise: float, lift: Vector3) -> void:
	_tuning.set_value("cruise", cruise)
	_player.fit_class(ClassDef.by_id("pylon_engineer"))
	_player.reset_to(DRAG_LANE + lift, Vector3(DRAG_SPEED, 0.0, 0.0))


func _drag_end(label: String) -> void:
	_record[label] = DRAG_SPEED - _planar()
	_record["grounded_" + label] = _player.state.grounded
	_tuning.set_value("cruise", _record["cruise"])


func _check_drag() -> void:
	var seconds := float(DRAG_TICKS - 1) / Engine.physics_ticks_per_second
	var excess: float = DRAG_SPEED - float(_record["cruise"]) * SpeedTier.MULTIPLES[SpeedTier.FAST]
	var predicted: float = Tuning.QUAD_DRAG * excess * excess * seconds
	var extra: float = _record["live"] - _record["no_quad"]
	_report("2 grounded rigid ball keeps its over-cruise speed",
		_record["grounded_live"] and _record["grounded_no_quad"] and absf(extra) < predicted * 0.25,
		"%d ticks grounded from %.0f m/s: lost %.3f with the term, %.3f without; extra %.3f, air term would be about %.3f"
			% [DRAG_TICKS, DRAG_SPEED, _record["live"], _record["no_quad"], extra, predicted])
	var air_extra: float = _record["air_live"] - _record["air_no_quad"]
	_report("2 flying rigid ball pays the over-speed drag",
		not _record["grounded_air_live"] and not _record["grounded_air_no_quad"] \
			and air_extra > predicted * 0.5 and air_extra < predicted * 1.5,
		"%d ticks in the air from %.0f m/s: lost %.3f with the term, %.3f without; extra %.3f, predicted about %.3f"
			% [DRAG_TICKS, DRAG_SPEED, _record["air_live"], _record["air_no_quad"], air_extra, predicted])


# Finding 3: planted (or mounted) with an aim and no cooldown, verb_ready says no and the
# press is refused busy without biting.
func _harpoon_busy() -> void:
	_player.fit_class(ClassDef.by_id("pylon_engineer"))
	var fails := []
	var on_fail := func(verb: String, reason: String, _at: Vector3): fails.append([verb, reason])
	_events.verb_failed.connect(on_fail)
	for hold in ["plant_time", "mounted"]:
		_player.reset_to(OPEN)
		fails.clear()
		_player.kit.aim = {"state": Augments.AIM_REACH, "point": OPEN + Vector3(0.0, 4.0, -20.0), "normal": Vector3.BACK}
		if hold == "plant_time":
			_player.kit.plant_time = 5.0
		else:
			_player.kit.mounted = true
		var ready: bool = _player.verb_ready("harpoon")
		_player._press_harpoon()
		var hooked: bool = _player.kit.hooked
		if hold == "plant_time":
			_report("3 harpoon cancels slam plant_time", ready and hooked and fails.is_empty(),
				"verb_ready %s, after the press hooked %s, failures %s" % [ready, hooked, fails])
		else:
			_report("3 harpoon refused while %s" % hold, not ready and not hooked and fails.has(["harpoon", "busy"]),
				"verb_ready %s, after the press hooked %s, failures %s" % [ready, hooked, fails])
		_player.release_grapple()
		_player.kit.plant_time = 0.0
		_player.kit.mounted = false
	_events.verb_failed.disconnect(on_fail)


# Finding 5: three hookable enemies stacked on the centre ray between the camera and the
# ball, a wall ahead. The ray may look past them or give up; it never returns one of them.
func _hook_ray_behind() -> void:
	var space: PhysicsDirectSpaceState3D = _world.get_world_3d().direct_space_state
	var dir := Vector3(0.0, 0.0, -1.0)
	var from := RAY_BALL + Vector3(0.0, 0.0, 12.0)
	var hit: Dictionary = Augments._hook_ray(space, from, dir, RAY_BALL, 60.0, Augments.WORLD_MASK | Augments.ENEMY_MASK, false)
	var behind := not hit.is_empty() and ((hit["position"] as Vector3) - RAY_BALL).dot(dir) <= 0.0
	var collider = hit.get("collider")
	_report("5 hook ray skips enemies behind the ball", not behind and not _posts.has(collider),
		"three enemies behind the ball on the ray: hit %s at %s" % [collider, hit.get("position", "-")])


# Finding 7: a committed smash whose first contact is a bow crush holds smash_landing on the
# crushed enemy while its strike resolves, and lets it go after.
func _crush_landing() -> void:
	_player.fit_class(ClassDef.by_id("pylon_engineer"))
	_player.reset_to(OPEN, Vector3(25.0, 0.0, 0.0))
	var enemy: Post = _posts[0]
	_player.crush_check = func(_body, _kind, _speed): return true
	_player.state.tier = SpeedTier.BLAZING
	_player.kit.hooked = true
	_player.kit.line_state = Augments.LINE_SMASH
	_player.kit.anchor_body = enemy
	var seen := []
	var on_struck := func(body: Node3D, _kind: String, _force: float): seen.append([body, _player.smash_landing])
	_player.struck.connect(on_struck)
	_player._try_crush(enemy)
	_player.struck.disconnect(on_struck)
	var during = seen[0][1] if not seen.is_empty() else null
	_report("7 bow-crush smash sets smash_landing", seen.size() == 1 and during == enemy and _player.smash_landing == null,
		"strikes %d, smash_landing during the strike %s (crushed %s), after %s"
			% [seen.size(), during, enemy, _player.smash_landing])
