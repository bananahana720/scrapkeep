extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const WardenScript := preload("res://src/combat/warden.gd")

# KF1 and KF1b (PARK.md section 7, "Every Warden is a harpoon anchor"): one bot per Warden
# kind, on the alpha table's first stage of that kind, through real input and real physics.
# The bot holds the harpoon from the bite to the release, as the keyboard does (intent.gd:
# harpoon_held is the key held, and the release drops the line). It latches a hardpoint from
# rope range, reels in to the anchor's minimum rope and hangs there while the mounting moves,
# fires the weapon from the line, is dragged by the moving mounting, holds a line bitten
# inside the enemy line's drop radius, finds Ctrl does nothing outside a stagger, is shrugged
# once on a pulse with its swing velocity kept, keeps a line re-bitten onto another hardpoint
# mid-charge, and finishes with the drop: a haul onto the staggered Warden that removes one
# chunk. The moving mounting is a test driver through the per-kind hook (KF2 to KF4 supply
# the real ones). The mind under the island drops the line 1.2 s after the pulse
# (wardens/mind.md section 10, call 1). Wardens opt in as anchors (spec "harpoon_anchor": true; the
# test sets it), so the authored boss arenas field none, and a park spec's mount_driver and
# hardpoint_offsets arrive as JSON without erroring.

# Stage, kind, and how high the mounting hangs the body (the headframe's hive and the
# island's hand are suspended, wardens/swarm.md and mind.md section 4; the reactor stands).
const KINDS := [[1, "reactor", 0.0], [3, "swarm", 20.0], [5, "mind", 20.0]]
# Where the bite is taken from: about 37 m from the crown, inside the 45 m rope.
const BITE_OUT := 30.0
const BITE_UP := 22.0
# The anchor's minimum rope (Tuning.ANCHOR_MIN_ROPE), held here so the red run on code
# without the constant still compiles, and how close to it a hanging ball stays.
const ANCHOR_MIN_ROPE := 6.0
const HANG_BAND := 0.3
const REEL_SECONDS := 6.0
const HANG_SECONDS := 1.0
const HANG_VELOCITY := Vector3(0.0, 3.0, 0.0)
const DRAG_SECONDS := 2.0
const DRAG_VELOCITY := Vector3(6.0, 12.0, 0.0)
const FIRE_SECONDS := 1.2
const STRETCH_OK := 0.75
const CONTACTS := ["ram", "stomp", "slam", "rebound", "guard_rack", "pulse"]
const ANCHOR_GROUP := "harpoon_anchor"
const PIER_UP := Vector3(0.0, 12.0, 0.0)
const PIER_OUT := 20.0


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


# A driver whose offset is not a Vector3, as a park row's bad data would give.
class BadDriver:
	func mount_offset(_warden, _clock: float):
		return [1.0, 2.0, 3.0]


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
# Ticks the first line has held without a break, counted while the bot reels, hangs and fires.
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


func _gap() -> float:
	return _player.ball_position().distance_to(_kit().anchor)


func _stretch() -> float:
	return _gap() - _kit().rope


func _on_hardpoint() -> bool:
	for i in _warden.hardpoints.size():
		if _kit().anchor.distance_to(_warden.hardpoint_at(i)) < 0.05:
			return true
	return false


# The keyboard's hold while a line stands: the harpoon key down, plus whatever else is held.
func _line_hold(extra := {}) -> void:
	var hold := {"harpoon_held": true}
	hold.merge(extra, true)
	_source.hold = hold


# The key comes up: the line drops (player_ball._read_grammar).
func _release() -> void:
	_source.hold = {}
	_source.press = {"harpoon_released": true}
	await _frames(2)


func _keep_quiet() -> void:
	if _riding and _held():
		_ride_ticks += 1
	else:
		_riding = false
	if is_instance_valid(_warden) and not _warden._charging:
		_warden._pulse_clock = 0.0


func _new_game() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame


func _start(stage: int) -> bool:
	await _new_game()
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


# The real press: aim at the Warden, press the harpoon, and the lock bites; the key then
# stays down. The ball is held at the spot while the chase camera catches up, so the lock
# cone sits on the crosshair.
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
	_line_hold()
	_source.press = {"harpoon_pressed": true}
	await _frames(2)
	return _held()


func _run() -> void:
	# The park row's landmark.warden carries "hardpoints" as a count (park_schema.gd WARDEN_FIELDS).
	var two: Array = WardenScript.hardpoints_for({"hardpoints": 2})
	var none: Array = WardenScript.hardpoints_for({"hardpoints": 0})
	var named: Array = WardenScript.hardpoints_for({"hardpoint_offsets": [Vector3.UP]})
	_report("a spec's hardpoints count picks that many", two.size() == 2 and two[1] == WardenScript.HARDPOINTS[1]
			and none.size() == 1 and named == [Vector3.UP] and WardenScript.hardpoints_for({}).size() == 3,
		"count 2 -> %d, count 0 -> %d, offsets -> %s, none -> %d" % [two.size(), none.size(), named,
			WardenScript.hardpoints_for({}).size()])
	var tuned: float = float((Tuning as Script).get_script_constant_map().get("ANCHOR_MIN_ROPE", -1.0))
	_report("the anchor's minimum rope is a tuning constant", is_equal_approx(tuned, ANCHOR_MIN_ROPE),
		"Tuning.ANCHOR_MIN_ROPE %.1f m, expected %.1f" % [tuned, ANCHOR_MIN_ROPE])
	await _boss_arenas()
	for entry in KINDS:
		await _bot(int(entry[0]), String(entry[1]), float(entry[2]))
	print("warden_anchor_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


# The authored boss arenas (stub_boss.gd and its Mind) spawn warden.gd without opting in, so
# their fights field no anchor (wardens/mind.md:5: the Mind boss stays authored).
func _boss_arenas() -> void:
	for world in [2, 3]:
		await _new_game()
		Harness.boot(_game)
		Harness.enter_world(_game, world)
		await _frames(2)
		var mod = Harness.module(_game, world)
		var fielded: bool = mod != null and "warden" in mod and is_instance_valid(mod.warden)
		var anchors := get_nodes_in_group(ANCHOR_GROUP).size()
		_report("world %d's boss arena fields no harpoon anchor" % world, fielded and anchors == 0
				and mod.warden.get("harpoon_anchor") != true,
			"arena Warden %s, %d nodes in %s" % [fielded, anchors, ANCHOR_GROUP])
		_game.free()
		_game = null
		await _frames(2)


func _bot(stage: int, family: String, hang: float) -> void:
	if not await _start(stage):
		_report("%s: a Warden" % family, false, "stage %d spawned no Warden" % stage)
		if _game != null:
			_game.free()
		return
	_report("%s: stage %d fields the kind" % [family, stage], _warden.family == family,
		"family %s, variant '%s'" % [_warden.family, _warden.variant])
	if family == "reactor":
		await _spec_guards()
	var framework: bool = _warden.has_method("set_mount_driver") and _warden.has_method("hardpoint_at") \
			and _warden.has_method("anchor_velocity")
	if _warden.has_method("set_harpoon_anchor"):
		_warden.call("set_harpoon_anchor", true)
	_report("%s: the Warden is a harpoon anchor" % family, framework,
		"set_mount_driver %s, hardpoint_at %s, anchor_velocity %s" % [_warden.has_method("set_mount_driver"),
			_warden.has_method("hardpoint_at"), _warden.has_method("anchor_velocity")])
	var hoist := Hoist.new()
	hoist._offset = Vector3.UP * hang
	if framework:
		_warden.set_mount_driver(hoist)
		await _frames(2)
	_pick_side()
	# HARDPOINTS sit on the body, so a ball hanging 6 m from one brushes the body, and any
	# touch rebounds the ball and cuts the line (player_ball.set_velocity_now). The ride is
	# checked on hardpoints placed as the mountings place them, off the body: piers 20 m out
	# and 12 m up (the reactor's gate piers flank the relic, wardens/reactor.md section 4).
	if framework:
		_warden.hardpoints = [_out * PIER_OUT + PIER_UP, _side * PIER_OUT + PIER_UP, -_side * PIER_OUT + PIER_UP]
	await _latch_and_reel(family, framework)
	if framework:
		await _hang(family, hoist)
	await _fire(family)
	var rode := float(_ride_ticks) / Engine.physics_ticks_per_second
	_report("%s: rides one line at least 3 s" % family, rode >= 3.0, "the first line held %.2f s through reel, hang and fire" % rode)
	_riding = false
	if framework:
		await _drag(family, hoist)
	await _inside(family)
	await _ctrl_outside_stagger(family)
	if framework:
		await _shrug(family, hoist)
		await _rebite(family)
	await _drop(family)
	_source.hold = {}
	_game.free()
	_game = null
	await _frames(2)


# Park data arrives as JSON (KF8 wires landmark.warden): a string or dictionary mount_driver
# and array hardpoint_offsets must not error. A Warden built from such a spec keeps no driver,
# reads the offsets as Vector3 and drops the bad ones, and joins the anchors only on a literal
# "harpoon_anchor": true; the park schema's position "anchor" ([0, 22, 590]) neither opts in
# nor blocks it. A driver whose offset is not a Vector3 leaves the body at home.
func _spec_guards() -> void:
	var at: Vector3 = _warden.global_position + Vector3(60.0, 0.0, 60.0)
	var first = WardenScript.new()
	_game.ctx.root.add_child(first)
	first.global_position = at
	first.setup(_player, _game.ctx.terrain, _game.ctx.root, Callable(_game.flow, "in_play"), 1.0,
		{"stage": 1, "harpoon_anchor": true, "anchor": [0, 22, 590], "mount_driver": "hoist",
			"hardpoint_offsets": [[0, 2, 0], [3.0, 0.0, 0.0], "bad", [1, 2], [1, "x", 2]]})
	var second = WardenScript.new()
	_game.ctx.root.add_child(second)
	second.global_position = at + Vector3(20.0, 0.0, 0.0)
	second.setup(_player, _game.ctx.terrain, _game.ctx.root, Callable(_game.flow, "in_play"), 1.0,
		{"stage": 1, "harpoon_anchor": "yes", "anchor": [0, 22, 590], "mount_driver": {"mount_offset": 1}, "hardpoints": "two",
			"hardpoint_offsets": "crown"})
	await _frames(10)
	var first_home: Vector3 = first.home
	var second_driver = second.mount_driver
	second.set_mount_driver(BadDriver.new())
	var second_home: Vector3 = second.home
	await _frames(10)
	_report("a park spec's bad mount_driver is dropped", first.mount_driver == null and second_driver == null
			and first.global_position.is_equal_approx(first_home),
		"string -> %s, dictionary -> %s, body moved %.3f m" % [first.mount_driver, second_driver,
			first.global_position.distance_to(first_home)])
	_report("array hardpoint_offsets read as Vector3, bad entries dropped",
		first.hardpoints == [Vector3(0, 2, 0), Vector3(3, 0, 0)] and second.hardpoints.size() == 3,
		"arrays -> %s, a string -> %d hardpoints" % [first.hardpoints, second.hardpoints.size()])
	_report("a driver whose offset is not a Vector3 leaves the body at home",
		second.global_position.is_equal_approx(second_home) and second.mount_velocity == Vector3.ZERO,
		"body moved %.3f m, mount velocity %s" % [second.global_position.distance_to(second_home), second.mount_velocity])
	_report("only a literal harpoon_anchor true opts a Warden in", first.is_in_group(ANCHOR_GROUP)
			and not second.is_in_group(ANCHOR_GROUP) and not _warden.is_in_group(ANCHOR_GROUP),
		"true -> %s, \"yes\" -> %s, the stage Warden with no flag -> %s" % [first.is_in_group(ANCHOR_GROUP),
			second.is_in_group(ANCHOR_GROUP), _warden.is_in_group(ANCHOR_GROUP)])
	first.queue_free()
	second.queue_free()
	await _frames(2)


# The bite, then the key held: the winch reels the ball in to the anchor's minimum rope and
# stops there. The rope holds its length all the way (a world line).
func _latch_and_reel(family: String, framework: bool) -> void:
	_keep_quiet()
	var from: Vector3 = _warden.global_position + _out * BITE_OUT + Vector3.UP * BITE_UP
	var latched := await _latch(from)
	_riding = latched
	_ride_ticks = 0
	var kit = _kit()
	var on_point: bool = framework and latched and _on_hardpoint()
	var reach: float = from.distance_to(_warden.global_position)
	_report("%s: latches a hardpoint from rope range" % family, latched and reach > 30.0
			and from.distance_to(kit.anchor) <= Tuning.new().f("rope_range") and on_point,
		"latched %s, bite from %.1f m (the hardpoint %.1f m), on a hardpoint %s" % [latched, reach,
			from.distance_to(kit.anchor), on_point])
	var worst := 0.0
	var held := latched
	var reached := -1.0
	var closest := INF
	for tick in _seconds(REEL_SECONDS):
		_keep_quiet()
		await physics_frame
		held = held and _held()
		if not held:
			_latch_note = "lost at %s from the body, ends %s" % [_player.ball_position() - _warden.global_position, _ends]
			break
		worst = maxf(worst, _stretch())
		closest = minf(closest, _gap())
		if kit.rope <= ANCHOR_MIN_ROPE + 0.01 and absf(_gap() - ANCHOR_MIN_ROPE) <= HANG_BAND:
			reached = float(tick + 1) / Engine.physics_ticks_per_second
			break
	_report("%s: the held winch reels in to the minimum rope" % family, held and reached > 0.0 and worst <= STRETCH_OK
			and kit.rope >= ANCHOR_MIN_ROPE - 0.01,
		"held %s, reached %.1f m after %.2f s, rope %.2f m, closest %.2f m, worst stretch %.2f m%s" % [held,
			ANCHOR_MIN_ROPE, reached, kit.rope, closest, worst, "" if held else ", " + _latch_note])


# At the minimum the ball hangs or orbits: still holding the key, it stays within HANG_BAND
# of the minimum rope for HANG_SECONDS while the mounting moves.
func _hang(family: String, hoist) -> void:
	var held := _held()
	var worst := 0.0
	var gaps := Vector2(INF, -INF)
	# The rope never pays out below the minimum (the winch's stop); the gap alone would pass
	# with the stop gone, since the line's arrival rests the ball near 6 m on its own.
	var rope_low := INF
	hoist.velocity = HANG_VELOCITY
	for tick in _seconds(HANG_SECONDS):
		_keep_quiet()
		await physics_frame
		held = held and _held()
		if not held:
			_latch_note = "lost at %s from the body, ends %s" % [_player.ball_position() - _warden.global_position, _ends]
			break
		var gap := _gap()
		gaps = Vector2(minf(gaps.x, gap), maxf(gaps.y, gap))
		worst = maxf(worst, absf(gap - ANCHOR_MIN_ROPE))
		rope_low = minf(rope_low, _kit().rope)
	hoist.velocity = Vector3.ZERO
	_report("%s: hangs at the minimum rope while the mounting moves" % family, held and worst <= HANG_BAND
			and rope_low >= ANCHOR_MIN_ROPE - 0.01,
		"held %s, distance to the hardpoint %.2f to %.2f m over %.1f s (rope %.2f m, lowest %.2f m), worst %.2f m off %.1f%s" % [held,
			gaps.x, gaps.y, HANG_SECONDS, _kit().rope, rope_low, worst, ANCHOR_MIN_ROPE, "" if held else ", " + _latch_note])


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
	_line_hold()
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


# Bitten inside the enemy line's drop radius (MIN_ROPE plus both radii, centre to centre),
# the anchor line holds: there is no "passed" drop on a hardpoint line.
func _inside(family: String) -> void:
	var inside: float = Augments.MIN_ROPE + Tuning.RADIUS + float(_warden.radius)
	var latched := await _latch(_warden.global_position + _out * 5.0 + Vector3.UP * 0.5)
	var held := latched
	var ticks := 0
	var closest := INF
	for tick in _seconds(1.0):
		_keep_quiet()
		await physics_frame
		held = held and _held()
		if not held:
			break
		var gap: float = _player.ball_position().distance_to(_warden.global_position)
		closest = minf(closest, gap)
		if gap <= inside:
			ticks += 1
	_report("%s: holds inside the enemy line's drop radius" % family, held and ticks >= _seconds(0.2),
		"latched %s, held %s, closest %.2f m (the enemy line drops at %.2f m), %d ticks inside, ends %s" % [latched, held,
			closest, inside, ticks, _ends])


# The weapon slot fires while the ball hangs on the held line; each bolt is posture.
func _fire(family: String) -> void:
	var held := _held()
	var posture: float = _warden.posture()
	var worst := 0.0
	_bolts = 0
	var fire_every := maxi(1, _seconds(0.22))
	_line_hold({"fire_held": true})
	for tick in _seconds(FIRE_SECONDS):
		_keep_quiet()
		_aim_at(_warden.global_position)
		if tick % fire_every == 0:
			_source.press = {"fire_pressed": true}
		await physics_frame
		held = held and _held()
		if held:
			worst = maxf(worst, absf(_gap() - ANCHOR_MIN_ROPE))
	_line_hold()
	_report("%s: fires from the line at the minimum rope" % family, held and _bolts > 0 and _warden.posture() > posture,
		"held %s, %d bolts struck it, posture %.1f to %.1f, worst %.2f m off the minimum, ends %s" % [held, _bolts,
			posture, _warden.posture(), worst, _ends])


# Principle 23: outside a stagger, Ctrl on a hardpoint line commits nothing and the line holds.
func _ctrl_outside_stagger(family: String) -> void:
	_warden._posture.posture = 0.0
	var latched := await _latch(_warden.global_position + _out * 14.0 + Vector3.UP * 6.0)
	_smashed = 0
	_line_hold({"brake_held": true})
	var held := latched
	var hauled := false
	for tick in _seconds(0.6):
		_keep_quiet()
		await physics_frame
		held = held and _held()
		hauled = hauled or _kit().line_state == Augments.LINE_SMASH
	_line_hold()
	_report("%s: Ctrl outside a stagger does nothing" % family, latched and held and not hauled and _smashed == 0
			and not _warden.staggered(),
		"latched %s, held %s, hauled %s, smashes %d, staggered %s" % [latched, held, hauled, _smashed, _warden.staggered()])


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
	_source.hold = {}


# The shrug cuts only the flaring hardpoint's line. Bite the hardpoint facing the open side,
# start the charge (it flares), let go mid-charge (the flare goes out), bite the one facing
# across: the pulse leaves that line alone and nothing flares again this charge. The
# hardpoints are placed for the case, as a mounting row's hardpoint_offsets would place them.
func _rebite(family: String) -> void:
	_warden._posture.posture = 0.0
	var placed: Array = _warden.hardpoints
	_warden.hardpoints = [_out * 6.0 + PIER_UP, _side * 6.0 + PIER_UP]
	var latched := await _latch(_warden.global_position + _out * 9.0 + Vector3.UP * 3.0)
	var first: int = _warden.lined_hardpoint()
	var first_bite: Vector3 = _kit().anchor_offset
	var shrugs: int = _warden.shrugs
	var pulses: int = _warden.pulses
	_warden._pulse_clock = _warden.PULSE_CYCLE - _warden.PULSE_TELEGRAPH
	await _frames(_seconds(0.3))
	var flared_first: int = _warden.flaring_hardpoint()
	var lit: float = _warden.shrug_flare()
	await _release()
	var dark_after_release: bool = _warden.shrug_flare() == 0.0 and _warden.flaring_hardpoint() == -1
	_report("%s: the flare goes out when its line is let go mid-charge" % family, latched and first == 0
			and flared_first == 0 and lit > 0.0 and dark_after_release and _warden._charging,
		"bit hardpoint %d, flaring %d at %.2f, after the release flaring %d at %.2f, charging %s" % [first,
			flared_first, lit, _warden.flaring_hardpoint(), _warden.shrug_flare(), _warden._charging])
	var again := await _latch(_warden.global_position + _side * 9.0 + Vector3.UP * 3.0)
	var second: int = _warden.lined_hardpoint()
	var second_bite: Vector3 = _kit().anchor_offset
	var stayed_dark := true
	var held := again
	for tick in _seconds(_warden.PULSE_TELEGRAPH + _warden.shrug_delay + 0.5):
		await physics_frame
		stayed_dark = stayed_dark and _warden.shrug_flare() == 0.0
		held = held and _held()
	_report("%s: a re-bite onto another hardpoint is not shrugged" % family, again and second == 1 and _warden.pulses > pulses
			and held and stayed_dark and _warden.shrugs == shrugs,
		"bites at %s then %s, re-bit hardpoint %d, pulsed %s, held %s, dark %s, shrugs %d to %d" % [first_bite,
			second_bite, second, _warden.pulses > pulses, held, stayed_dark, shrugs, _warden.shrugs])
	await _release()
	_warden.hardpoints = placed


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
	_line_hold({"brake_held": true})
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
