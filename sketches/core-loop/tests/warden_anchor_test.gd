extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# KF1 (PARK.md section 7, "Every Warden is a harpoon anchor"): one bot per Warden kind, on
# the alpha table's first stage of that kind, through real input and real physics. The bot
# latches a hardpoint from rope range with the harpoon press, rides the line for more than
# 3 s (a pendulum that holds its length, then winched inside the minimum rope without the
# line dropping), is dragged by a moving mounting, fires the weapon from the line, is
# shrugged once on a pulse with its swing velocity kept, and finishes with the drop: a haul
# onto the staggered Warden that removes one chunk. The moving mounting is a test driver
# through the per-kind hook (KF2 to KF4 supply the real ones). The mind under the island
# drops the line 1.2 s after the pulse (wardens/mind.md section 10, call 1).

# Stage, kind, and how high the mounting hangs the body (the headframe's hive and the
# island's hand are suspended, wardens/swarm.md and mind.md section 4; the reactor stands).
const KINDS := [[1, "reactor", 0.0], [3, "swarm", 20.0], [5, "mind", 20.0]]
# Where the bite is taken from: about 37 m from the crown, inside the 45 m rope.
const BITE_OUT := 30.0
const BITE_UP := 22.0
const SWING_SECONDS := 1.5
const DRAG_SECONDS := 2.0
const DRAG_VELOCITY := Vector3(6.0, 12.0, 0.0)
const WINCH_SECONDS := 4.0
const FIRE_SECONDS := 1.2
const STRETCH_OK := 0.75
const CONTACTS := ["ram", "stomp", "slam", "rebound", "guard_rack", "pulse"]


# A mounting that moves at `velocity` for as long as the test sets it, the shape every
# per-kind driver has: an offset from the Warden's home for the mounting clock.
class Hoist:
	var velocity := Vector3.ZERO
	var _offset := Vector3.ZERO
	var _last := 0.0

	func mount_offset(_warden, clock: float) -> Vector3:
		_offset += velocity * maxf(0.0, clock - _last)
		_last = clock
		return _offset


var _game
var _combat
var _player
var _warden
var _source := Intent.Scripted.new()
var _failures := 0
var _smashed := 0
var _bolts := 0
var _ends: Array = []
var _latch_note := ""
# Ticks the first line has held without a break, counted while the bot swings, fires and winches.
var _riding := false
var _ride_ticks := 0
# The open side the bot works from (flat, unit) and the heading across it.
var _out := Vector3.LEFT
var _side := Vector3.FORWARD


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


func _aim_at(point: Vector3) -> void:
	var cam = _game.camera
	var d: Vector3 = (point - cam.aim_origin()).normalized()
	cam.yaw = atan2(-d.x, -d.z)
	cam.pitch = clampf(asin(d.y), -1.25, 0.55)


func _kit():
	return _player.kit


func _velocity() -> Vector3:
	return _player.body().linear_velocity


func _held() -> bool:
	var kit = _kit()
	return kit.hooked and kit.on_body and kit.anchor_body == _warden


func _stretch() -> float:
	var kit = _kit()
	return _player.ball_position().distance_to(kit.anchor) - kit.rope


func _on_hardpoint() -> bool:
	for i in 3:
		if _kit().anchor.distance_to(_warden.hardpoint_at(i)) < 0.05:
			return true
	return false


func _keep_quiet() -> void:
	if _riding and _held():
		_ride_ticks += 1
	else:
		_riding = false
	if is_instance_valid(_warden) and not _warden._charging:
		_warden._pulse_clock = 0.0


func _start(stage: int) -> bool:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_player = _game.player
	_player.source = _source
	_combat = _game.ctx.spawner
	_game.flow.press_start()
	_game.flow.choose_class(1)
	if stage != 1:
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
	_smashed = 0
	_bolts = 0
	_ends.clear()
	_game.events.harpoon_smashed.connect(func(_e: Node3D, _at: Vector3, _speed: float): _smashed += 1)
	_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, _force: float):
		if enemy == _warden and not kind in CONTACTS:
			_bolts += 1)
	_game.events.line_state_changed.connect(func(id: String, _t: Node3D, _at: Vector3, cause: String):
		if id == "idle" or cause != "":
			_ends.append(cause))
	await _frames(_seconds(0.4))
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_warden = _game.flow.warden
	if not is_instance_valid(_warden):
		return false
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()
	await _frames(2)
	return true


# The stage's terrain differs per kind: the bot works from the first of eight headings
# whose bite point, swing and approach see the crown with nothing of the world between.
func _pick_side() -> void:
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	var crown: Vector3 = _warden.global_position + Vector3.UP * _warden.HALF_HEIGHT
	for i in 8:
		var out := Vector3.LEFT.rotated(Vector3.UP, TAU * float(i) / 8.0)
		var clear := true
		for spot in [out * BITE_OUT + Vector3.UP * BITE_UP, out * 20.0 + Vector3.UP * 6.0, out * 12.0 + Vector3.UP * 4.0]:
			var query := PhysicsRayQueryParameters3D.create(crown, crown + spot, Augments.WORLD_MASK)
			clear = clear and space.intersect_ray(query).is_empty()
		if clear:
			_out = out
			_side = out.cross(Vector3.UP).normalized()
			return
	_out = Vector3.LEFT
	_side = Vector3.FORWARD


# The real press: aim at the Warden, press the harpoon, and the lock bites. The ball is held
# at the spot while the chase camera catches up, so the lock cone sits on the crosshair.
func _latch(from: Vector3, velocity := Vector3.ZERO) -> bool:
	_source.hold = {}
	# The swarm's guard respawns; the lock is for the Warden.
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()
	_game.camera.snap(_warden.global_position - from)
	for i in _seconds(0.4):
		_player.reset_to(from, velocity)
		_aim_at(_warden.global_position)
		await physics_frame
	_player.reset_to(from, velocity)
	_aim_at(_warden.global_position)
	_latch_note = "rewind %.2f, cooldown %.2f, ball %.1f m from the body" % [_kit().rewind_left, _player.chain.miss_left,
			_player.ball_position().distance_to(_warden.global_position)]
	_source.press = {"harpoon_pressed": true}
	await _frames(2)
	return _held()


func _run() -> void:
	for entry in KINDS:
		await _bot(int(entry[0]), String(entry[1]), float(entry[2]))
	print("warden_anchor_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _bot(stage: int, family: String, hang: float) -> void:
	if not await _start(stage):
		_report("%s: a Warden" % family, false, "stage %d spawned no Warden" % stage)
		if _game != null:
			_game.free()
		return
	_report("%s: stage %d fields the kind" % [family, stage], _warden.family == family,
		"family %s, variant '%s'" % [_warden.family, _warden.variant])
	var framework: bool = _warden.has_method("set_mount_driver") and _warden.has_method("hardpoint_at") \
			and _warden.has_method("anchor_velocity")
	_report("%s: the Warden is a harpoon anchor" % family, framework,
		"set_mount_driver %s, hardpoint_at %s, anchor_velocity %s" % [_warden.has_method("set_mount_driver"),
			_warden.has_method("hardpoint_at"), _warden.has_method("anchor_velocity")])
	var hoist := Hoist.new()
	hoist._offset = Vector3.UP * hang
	if framework:
		_warden.set_mount_driver(hoist)
		await _frames(2)
	_pick_side()
	await _latch_and_ride(family, framework)
	await _fire(family)
	await _winch_in(family)
	if framework:
		await _drag(family, hoist)
	if framework:
		await _shrug(family, hoist)
	await _drop(family)
	_source.hold = {}
	_game.free()
	_game = null
	await _frames(2)


func _latch_and_ride(family: String, framework: bool) -> void:
	_keep_quiet()
	var from: Vector3 = _warden.global_position + _out * BITE_OUT + Vector3.UP * BITE_UP
	# Thrown outward at the bite: a free ball would stretch the line by metres.
	var latched := await _latch(from, _out * 8.0 + Vector3.UP * 4.0 + _side * 6.0)
	_riding = latched
	_ride_ticks = 0
	var kit = _kit()
	var on_point: bool = framework and latched and _on_hardpoint()
	_report("%s: latches a hardpoint from rope range" % family, latched and from.distance_to(kit.anchor) > 30.0
			and from.distance_to(kit.anchor) <= Tuning.new().f("rope_range") and on_point,
		"latched %s, bite from %.1f m, on a hardpoint %s" % [latched, from.distance_to(kit.anchor), on_point])
	var worst := 0.0
	var held := latched
	for tick in _seconds(SWING_SECONDS):
		_keep_quiet()
		await physics_frame
		held = held and _held()
		if held:
			worst = maxf(worst, _stretch())
	_report("%s: the line swings as a world line" % family, held and worst <= STRETCH_OK,
		"held %s over %.1f s, worst stretch past the rope %.2f m" % [held, SWING_SECONDS, worst])


# The mounting moves; the anchor moves with it and the rope's tension carries the ball.
func _drag(family: String, hoist) -> void:
	if not _held():
		_report("%s: dragged by the mounting" % family, false, "no line to drag")
		return
	var ball_before: Vector3 = _player.ball_position()
	var body_before: Vector3 = _warden.global_position
	var worst := 0.0
	var held := true
	var follows := true
	var carried := 0.0
	hoist.velocity = DRAG_VELOCITY
	for tick in _seconds(DRAG_SECONDS):
		_keep_quiet()
		await physics_frame
		held = held and _held()
		if held:
			worst = maxf(worst, _stretch())
			follows = follows and _on_hardpoint()
			carried = maxf(carried, _warden.anchor_velocity().length())
	hoist.velocity = Vector3.ZERO
	var moved: Vector3 = _warden.global_position - body_before
	var rose: float = _player.ball_position().y - ball_before.y
	_report("%s: the anchor moves with the mounting" % family, held and follows and moved.y > 20.0 and absf(carried - DRAG_VELOCITY.length()) < 1.0,
		"held %s, anchor on its hardpoint %s, body moved %s, anchor speed %.1f m/s" % [held, follows, moved, carried])
	_report("%s: the rope's tension drags the ball" % family, held and rose > 0.5 * moved.y and worst <= STRETCH_OK,
		"ball rose %.1f m while the mounting rose %.1f m, worst stretch %.2f m" % [rose, moved.y, worst])


# Right mouse held winches the line in, and the line never drops inside the minimum rope.
# An orbiting ball winches in only so far (the pull meets the orbit's centripetal need), so
# when the winch leaves it outside, the bot bites again level with the body, still, and hangs.
func _winch_in(family: String) -> void:
	if not _held():
		var again := await _latch(_warden.global_position + _out * 12.0 + Vector3.UP * 4.0)
		if not again:
			_report("%s: rides inside the minimum rope" % family, false, "no line to winch")
			return
	var inside: float = Augments.MIN_ROPE + Tuning.RADIUS + float(_warden.radius)
	var rope_before: float = _kit().rope
	var watch := {"closest": INF, "inside": 0, "held": true}
	_source.hold = {"harpoon_held": true}
	await _watch_inside(watch, inside, WINCH_SECONDS)
	_source.hold = {}
	var rode := float(_ride_ticks) / Engine.physics_ticks_per_second
	_report("%s: rides one line at least 3 s" % family, rode >= 3.0, "the first line held %.2f s through swing, fire and winch" % rode)
	_riding = false
	var winched: bool = watch["held"] and rope_before - _kit().rope > 5.0
	_report("%s: the winch shortens the line" % family, winched,
		"held %s, rope %.1f to %.1f m" % [watch["held"], rope_before, _kit().rope])
	var how := "winched"
	if watch["held"] and int(watch["inside"]) <= _seconds(0.5):
		how = "hung level"
		watch["held"] = await _latch(_warden.global_position + _out * 7.0)
		await _watch_inside(watch, inside, 1.5)
	_report("%s: rides inside the minimum rope" % family, watch["held"] and int(watch["inside"]) > _seconds(0.5),
		"%s: held %s, closest %.2f m (the enemy line drops at %.2f m), %d ticks inside, ends %s" % [how, watch["held"],
			watch["closest"], inside, int(watch["inside"]), _ends])


func _watch_inside(watch: Dictionary, inside: float, seconds: float) -> void:
	watch["inside"] = 0
	for tick in _seconds(seconds):
		_keep_quiet()
		await physics_frame
		watch["held"] = watch["held"] and _held()
		if not watch["held"]:
			return
		var gap: float = _player.ball_position().distance_to(_warden.global_position)
		watch["closest"] = minf(watch["closest"], gap)
		if gap <= inside:
			watch["inside"] = int(watch["inside"]) + 1
			if int(watch["inside"]) > _seconds(0.5):
				return


# The weapon slot fires while the ball hangs; each bolt is posture.
func _fire(family: String) -> void:
	var held := _held()
	var posture: float = _warden.posture()
	_bolts = 0
	_source.hold = {"fire_held": true}
	for tick in _seconds(FIRE_SECONDS):
		_keep_quiet()
		_aim_at(_warden.global_position)
		await physics_frame
		held = held and _held()
	_source.hold = {}
	_report("%s: fires from the line" % family, held and _bolts > 0 and _warden.posture() > posture,
		"held %s, %d bolts struck it, posture %.1f to %.1f, ends %s" % [held, _bolts, posture, _warden.posture(), _ends])


# Once per pulse cycle the lined hardpoint flares for the telegraph, then the line drops;
# the ball keeps its velocity (plus the lift if the reach ring held it).
func _shrug(family: String, hoist) -> void:
	_warden._posture.posture = 0.0
	var from: Vector3 = _warden.global_position + _out * 14.0 + Vector3.DOWN * 4.0
	var latched := await _latch(from, _side * 10.0)
	if not latched:
		_report("%s: shrugged once with its velocity kept" % family, false, "no line for the shrug")
		return
	var shrugs: int = _warden.shrugs
	var pulses: int = _warden.pulses
	_ends.clear()
	_warden._pulse_clock = _warden.PULSE_CYCLE - _warden.PULSE_TELEGRAPH
	var ring_start := Vector3.ZERO
	var body_start: Vector3 = _warden.global_position
	await _frames(2)
	var charging: bool = _warden._charging
	var ring = _warden.telegraph()
	if ring != null:
		ring_start = ring.center
	hoist.velocity = Vector3(4.0, 0.0, 0.0)
	var flared := true
	var held := true
	for tick in _seconds(1.5):
		await physics_frame
		flared = flared and _warden.shrug_flare() > 0.0
		held = held and _held()
	hoist.velocity = Vector3.ZERO
	var ring_now = _warden.telegraph()
	var ring_gap := INF
	if ring_now != null:
		ring_gap = Vector2(ring_now.center.x - _warden.global_position.x, ring_now.center.z - _warden.global_position.z).length()
	var body_moved: float = _warden.global_position.x - body_start.x
	_report("%s: the pulse ring follows the moving body" % family, charging and ring_now != null and body_moved > 4.0 and ring_gap < 0.5,
		"charging %s, body moved %.1f m, ring centre %.2f m from the body (started at %s)" % [charging, body_moved, ring_gap, ring_start])
	_report("%s: the lined hardpoint flares and the line holds through the charge" % family, flared and held,
		"flared %s, held %s" % [flared, held])
	var before := _velocity()
	var dropped_after := -1.0
	var at_pulse := -1.0
	var clock := 0.0
	var v_last := before
	var v_drop := Vector3.ZERO
	var v_prev := Vector3.ZERO
	for tick in _seconds(3.0):
		await physics_frame
		clock += 1.0 / Engine.physics_ticks_per_second
		if at_pulse < 0.0 and _warden.pulses > pulses:
			at_pulse = clock
		if not _held() and dropped_after < 0.0:
			dropped_after = clock - (at_pulse if at_pulse >= 0.0 else clock)
			v_prev = v_last
			await physics_frame
			v_drop = _velocity()
			break
		v_last = _velocity()
	var delay: float = _warden.shrug_delay
	var on_time := at_pulse >= 0.0 and dropped_after >= delay - 0.05 and dropped_after <= delay + 0.1
	_report("%s: the line drops on the pulse (after %.1f s)" % [family, delay], on_time and _ends.has("shrugged") and _warden.shrugs == shrugs + 1,
		"pulse at %.2f s, dropped %.2f s after it, ends %s, shrugs %d to %d" % [at_pulse, dropped_after, _ends, shrugs, _warden.shrugs])
	var flat_prev := Vector2(v_prev.x, v_prev.z)
	var flat_drop := Vector2(v_drop.x, v_drop.z)
	var lift: float = _warden.PULSE_LIFT if _warden.last_pulse_lifted and delay <= 0.0 else 0.0
	var rise: float = v_drop.y - v_prev.y
	_report("%s: the shrug keeps the ball's velocity" % family, flat_prev.length() > 2.0 and (flat_drop - flat_prev).length() < 1.5
			and rise > lift - 1.0 and rise < lift + 1.0,
		"planar %.1f to %.1f m/s (change %.2f), vertical %+.1f m/s, lift expected %.1f" % [flat_prev.length(), flat_drop.length(),
			(flat_drop - flat_prev).length(), rise, lift])


# The finisher: stagger the Warden, latch above the open core, haul, and the smash
# removes one chunk.
func _drop(family: String) -> void:
	var guard := 0
	while is_instance_valid(_warden) and not _warden.staggered() and guard < 20:
		_combat.strike(_warden, "ram", _matched_force())
		await physics_frame
		guard += 1
	var chunks: int = _warden.chunks_left()
	var top: Vector3 = _warden.global_position + Vector3.UP * _warden.HALF_HEIGHT
	var latched := await _latch(top + _out * 6.0 + Vector3.UP * 8.0)
	var held := latched
	for tick in _seconds(0.5):
		await physics_frame
		held = held and _held()
	_smashed = 0
	_source.hold = {"brake_held": true}
	for tick in _seconds(1.5):
		await physics_frame
		if _smashed > 0:
			break
	_source.hold = {}
	await _frames(2)
	var left: int = _warden.chunks_left() if is_instance_valid(_warden) else 0
	_report("%s: every hardpoint holds in the stagger" % family, latched and held, "latched %s, held %s (%s)" % [latched, held, _latch_note])
	_report("%s: the drop finisher removes a chunk" % family, _smashed == 1 and left == chunks - 1,
		"staggered %s, smashes %d, chunks %d to %d" % [_warden.staggered() if is_instance_valid(_warden) else false, _smashed, chunks, left])


func _matched_force() -> float:
	var force := 1.0
	while _combat.punch_of("ram", force) < float(_warden.plating):
		force += 0.05
	return force
