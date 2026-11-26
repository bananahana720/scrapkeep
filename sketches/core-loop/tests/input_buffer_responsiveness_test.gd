extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Augments := preload("res://src/movement/augments.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const UltimateMeter := preload("res://src/core/ultimate_meter.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const AimReticle := preload("res://src/ui/aim_reticle.gd")
const T := preload("res://tests/support/t.gd")

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)

var _t := T.new("input_buffer_responsiveness_test")
var _game
var _player
var _combat
var _source := Intent.Scripted.new()
var _fails: Array = []
var _lines: Array = []
var _dashed := 0
var _boosted := 0
var _jumped := 0
var _grappled := 0
var _special_charged := 0
var _line_loaded := 0
var _active_fired := 0
var _ult_started := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _clear_counts() -> void:
	_fails.clear()
	_lines.clear()
	_dashed = 0
	_boosted = 0
	_jumped = 0
	_grappled = 0
	_special_charged = 0
	_line_loaded = 0
	_active_fired = 0
	_ult_started = 0


func _pilot(class_id: String) -> void:
	var def: Resource = ClassDef.by_id(class_id)
	_game.run.class_def = def
	_player.fit_class(def)
	_player.abilities.refill()
	_source.hold = {}
	_source.press = {}
	_clear_counts()


func _point(dx: float, dz: float, lift: float) -> Vector3:
	return _game.ctx.terrain.drop_point(FLAT_SHELF.x + dx, FLAT_SHELF.z + dz, lift)


func _place(at: Vector3, velocity := Vector3.ZERO) -> void:
	_player.reset_to(at, velocity)
	_source.hold = {}
	_source.press = {}


func _set_slot_remaining(slot_name: String, remaining: float) -> void:
	var s = _player.abilities.slot(slot_name)
	var cd: float = _player.abilities.cooldown_of(slot_name)
	s.charges = 0
	s.recharge = maxf(0.0, cd - remaining)


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_combat = _game.combat
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(0.5)
	_game.run.set_max_hp(99999.0)
	var ev = _game.events
	ev.verb_failed.connect(func(verb: String, reason: String, _at: Vector3): _fails.append([verb, reason]))
	ev.line_state_changed.connect(func(state: String, _target: Node3D, _at: Vector3, _cause: String): _lines.append(state))
	ev.dashed.connect(func(_dir: Vector3): _dashed += 1)
	ev.boosted.connect(func(_dir: Vector3): _boosted += 1)
	ev.jumped.connect(func(_air: bool): _jumped += 1)
	ev.grapple_fired.connect(func(_anchor: Vector3): _grappled += 1)
	ev.gauge_charging.connect(func(_id: String): _special_charged += 1)
	ev.line_skill_loaded.connect(func(_id: String, _s: float): _line_loaded += 1)
	ev.active_fired.connect(func(_id: String, _at: Vector3, _count: int): _active_fired += 1)
	ev.ultimate_started.connect(func(_id: String, _path: String, _from: Vector3, _to: Vector3, _s: float): _ult_started += 1)

	_test_constants()
	await _test_burst_movement_buffers()
	await _test_harpoon_buffers()
	await _test_aerial_slam_buffers()
	await _test_slam_plant_cancels()
	await _test_ability_cast_buffers()
	await _test_reticle_frame0_feedback()

	_game.free()
	quit(_t.verdict())


func _test_constants() -> void:
	_t.near("unified action buffer is 0.12 s", Tuning.ACTION_BUFFER_S, 0.12, 0.0001)
	_t.near("slam transition buffer is 0.10 s", Tuning.SLAM_BUFFER_S, 0.10, 0.0001)


func _test_burst_movement_buffers() -> void:
	var pilots := [
		["runner_gunner", "sprint"],
		["demolitions_caster", "blink"],
		["tarn", "claw_pull"],
		["tally", "surge"],
		["remembered_cannon", "recoil"],
	]
	for entry in pilots:
		var class_id: String = entry[0]
		var label: String = entry[1]
		_pilot(class_id)
		_place(_point(0.0, 0.0, 2.0), Vector3(0.0, 0.0, -8.0))
		await _ticks(2)
		_set_slot_remaining(AbilityState.MOVEMENT, 0.08)
		_clear_counts()
		_source.press = {"shift_pressed": true}
		if label == "sprint":
			_source.hold = {"shift_held": true}
		await _ticks(1)
		var early_fails: Array = _fails.duplicate()
		await _sim(0.12)
		_source.hold = {}
		_t.check("%s buffered press inside 0.12 s fires with no refusal" % label,
			early_fails.is_empty() and _fails.is_empty() and _dashed >= 1,
			"fails %s, dashed %d" % [_fails, _dashed])

		_pilot(class_id)
		_place(_point(0.0, 0.0, 2.0), Vector3(0.0, 0.0, -8.0))
		await _ticks(2)
		_set_slot_remaining(AbilityState.MOVEMENT, 0.60)
		_clear_counts()
		_source.press = {"shift_pressed": true}
		await _ticks(2)
		_t.check("%s press outside 0.12 s emits raw uncharged refusal" % label,
			_fails == [["boost", "uncharged"]] and _dashed == 0,
			"fails %s, dashed %d" % [_fails, _dashed])

	_pilot("demolitions_caster")
	_place(_point(0.0, 0.0, 2.0), Vector3.ZERO)
	await _ticks(2)
	_player.kit.mounted = true
	_clear_counts()
	_source.press = {"shift_pressed": true}
	await _ticks(2)
	_player.kit.mounted = false
	_t.check("mounted burst press emits busy refusal",
		_fails == [["boost", "busy"]] and _dashed == 0,
		"fails %s, dashed %d" % [_fails, _dashed])


func _cam(from: Vector3, to: Vector3) -> void:
	_game.camera.set_process(false)
	_game.camera.arm.set_physics_process_internal(false)
	(_game.camera.cam.get_parent() as Node3D).global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
	_game.camera.cam.transform = Transform3D.IDENTITY


func _make_wall(at: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, 12.0, 1.0)
	shape.shape = box
	wall.add_child(shape)
	_game.ctx.root.add_child(wall)
	wall.global_position = at
	return wall


func _test_harpoon_buffers() -> void:
	_pilot("pylon_engineer")
	var ball := _point(0.0, 0.0, 4.0)
	var wall := _make_wall(ball + Vector3(0.0, 2.0, -14.0))
	var eye := ball + Vector3(0.0, 0.8, 4.0)

	_place(ball, Vector3.ZERO)
	_cam(eye, wall.global_position)
	await _ticks(3)
	_player.kit.rewind_left = 0.08
	_clear_counts()
	_source.press = {"harpoon_pressed": true}
	_source.hold = {"harpoon_held": true}
	await _ticks(1)
	var rewind_refused := not _fails.is_empty() or _lines.has("dry_fire")
	for i in 12:
		await physics_frame
		if _player.kit.hooked:
			break
	_t.check("harpoon buffered across 0.08 s rewind fires cleanly on ready",
		not rewind_refused and _player.kit.hooked and _grappled == 1 and _fails.is_empty(),
		"refused %s, hooked %s, grappled %d, fails %s" % [rewind_refused, _player.kit.hooked, _grappled, _fails])
	_player.release_grapple()

	_place(ball, Vector3.ZERO)
	_cam(eye, wall.global_position)
	await _ticks(3)
	_player.chain.miss_left = 0.08
	_clear_counts()
	_source.press = {"harpoon_pressed": true}
	_source.hold = {"harpoon_held": true}
	for i in 12:
		await physics_frame
		if _player.kit.hooked:
			break
	_t.check("harpoon buffered across 0.08 s chain miss cooldown fires cleanly",
		_player.kit.hooked and _grappled == 1 and _fails.is_empty(),
		"hooked %s, grappled %d, fails %s" % [_player.kit.hooked, _grappled, _fails])
	_player.release_grapple()

	_place(ball, Vector3.ZERO)
	_cam(eye, wall.global_position)
	await _ticks(3)
	_player.kit.rewind_left = 0.08
	_clear_counts()
	_source.press = {"harpoon_pressed": true}
	await _ticks(1)
	_source.press = {"harpoon_released": true}
	await _ticks(12)
	_t.check("harpoon release clears buffered press without firing or dry-firing",
		not _player.kit.hooked and _grappled == 0 and _fails.is_empty() and not _lines.has("dry_fire"),
		"hooked %s, grappled %d, fails %s, lines %s" % [_player.kit.hooked, _grappled, _fails, _lines])

	_place(ball, Vector3.ZERO)
	_cam(eye, wall.global_position)
	await _ticks(3)
	_player.kit.rewind_left = 0.08
	_clear_counts()
	_source.press = {"harpoon_pressed": true}
	await _ticks(1)
	_source.press = {"cancel_pressed": true}
	await _ticks(12)
	_t.check("cancel clears buffered harpoon press cleanly",
		not _player.kit.hooked and _grappled == 0 and _fails.is_empty(),
		"hooked %s, grappled %d, fails %s" % [_player.kit.hooked, _grappled, _fails])

	_place(ball, Vector3.ZERO)
	_cam(eye, eye + Vector3(0.0, 20.0, -4.0))
	await _ticks(3)
	_player.kit.rewind_left = 0.06
	_clear_counts()
	_source.press = {"harpoon_pressed": true}
	await _ticks(16)
	_t.check("expired harpoon buffer with no target preserves dry-fire feedback",
		not _player.kit.hooked and _lines.has("dry_fire") and _fails.has(["harpoon", "no_aim"]),
		"hooked %s, lines %s, fails %s" % [_player.kit.hooked, _lines, _fails])

	_place(ball, Vector3.ZERO)
	_cam(eye, wall.global_position)
	await _ticks(3)
	_player.kit.rewind_left = 0.50
	_clear_counts()
	_source.press = {"harpoon_pressed": true}
	await _ticks(2)
	_t.check("harpoon press outside 0.12 s rewind refuses immediately",
		not _player.kit.hooked and _fails == [["harpoon", "rewinding"]],
		"hooked %s, fails %s" % [_player.kit.hooked, _fails])
	wall.free()


func _test_aerial_slam_buffers() -> void:
	_pilot("pylon_engineer")
	var air := _point(0.0, 0.0, 12.0)
	_place(air, Vector3(0.0, 0.0, -4.0))
	await _ticks(2)
	_player.grapple_to(air + Vector3(0.0, 4.0, -10.0), Vector3(0.0, 0.0, 1.0))
	await _ticks(1)
	_clear_counts()
	_source.hold = {"brake_held": true}
	await _ticks(2)
	_source.press = {"harpoon_released": true}
	await _ticks(2)
	_t.check("Ctrl pressed within 0.10 s before grapple release slams on tick 0 airborne",
		not _player.kit.hooked and _player.kit.slamming,
		"hooked %s, slamming %s" % [_player.kit.hooked, _player.kit.slamming])
	_source.hold = {}

	_place(air, Vector3(0.0, 0.0, -4.0))
	await _ticks(2)
	_player.grapple_to(air + Vector3(0.0, 4.0, -10.0), Vector3(0.0, 0.0, 1.0))
	await _ticks(1)
	_clear_counts()
	_source.press = {"harpoon_released": true}
	_source.hold = {"brake_held": true}
	await _ticks(2)
	_t.check("same-tick grapple release and Ctrl engages slam on tick 0",
		not _player.kit.hooked and _player.kit.slamming,
		"hooked %s, slamming %s" % [_player.kit.hooked, _player.kit.slamming])
	_source.hold = {}

	var ground := _point(0.0, 0.0, 1.05)
	_place(ground, Vector3.ZERO)
	await _sim(0.15)
	_clear_counts()
	_source.press = {"jump_pressed": true}
	_source.hold = {"brake_held": true}
	var slammed := false
	for i in 10:
		await physics_frame
		if _player.kit.slamming:
			slammed = true
			break
	_source.hold = {}
	_t.check("takeoff Ctrl edge suppresses ground idle refusal and slams airborne",
		not _fails.has(["haul", "no_line"]) and slammed,
		"fails %s, slammed %s" % [_fails, slammed])

	_place(ground, Vector3.ZERO)
	await _sim(0.15)
	_clear_counts()
	_source.hold = {"brake_held": true}
	await _ticks(2)
	_source.hold = {}
	_t.check("Ctrl at rest on ground with no jump still refuses haul/no_line",
		_fails == [["haul", "no_line"]] and not _player.kit.slamming,
		"fails %s, slamming %s" % [_fails, _player.kit.slamming])


func _test_slam_plant_cancels() -> void:
	var ground := _point(0.0, 0.0, 1.1)
	var exit_v := Vector3(0.0, 0.0, -18.0)

	_pilot("pylon_engineer")
	_place(ground, Vector3.ZERO)
	await _sim(0.1)
	_player.kit.plant_at = _player.ball_position()
	_player.kit.plant_normal = Vector3.UP
	_player.kit.plant_exit = exit_v
	_player.kit.plant_time = 0.28
	_clear_counts()
	_source.press = {"jump_pressed": true}
	await _ticks(2)
	var after_jump: Vector3 = _player.state.velocity
	_t.check("jump cancels slam plant on frame 0 without clipping horizontal velocity",
		_player.kit.plant_time == 0.0 and _jumped >= 1 and Vector2(after_jump.x, after_jump.z).length() >= 15.0 and after_jump.y > 4.0,
		"plant %.3f, jumped %d, vel %s" % [_player.kit.plant_time, _jumped, after_jump])

	_pilot("pylon_engineer")
	_place(ground, Vector3.ZERO)
	await _sim(0.1)
	_player.kit.plant_at = _player.ball_position()
	_player.kit.plant_normal = Vector3.UP
	_player.kit.plant_exit = exit_v
	_player.kit.plant_time = 0.28
	_player.state.boost_cooldown = 0.0
	_clear_counts()
	_source.press = {"shift_pressed": true}
	await _ticks(2)
	var after_boost: float = Vector2(_player.state.velocity.x, _player.state.velocity.z).length()
	_t.check("boost cancels slam plant on frame 0 without clipping velocity",
		_player.kit.plant_time == 0.0 and _boosted >= 1 and after_boost >= 22.0,
		"plant %.3f, boosted %d, planar %.2f" % [_player.kit.plant_time, _boosted, after_boost])

	_pilot("demolitions_caster")
	_place(ground, Vector3.ZERO)
	await _sim(0.1)
	_player.kit.plant_at = _player.ball_position()
	_player.kit.plant_normal = Vector3.UP
	_player.kit.plant_exit = exit_v
	_player.kit.plant_time = 0.28
	_clear_counts()
	_source.press = {"shift_pressed": true}
	await _ticks(2)
	var after_blink: float = Vector2(_player.state.velocity.x, _player.state.velocity.z).length()
	_t.check("burst movement cancels slam plant on frame 0 without clipping velocity",
		_player.kit.plant_time == 0.0 and _dashed >= 1 and after_blink >= 15.0 and _fails.is_empty(),
		"plant %.3f, dashed %d, planar %.2f, fails %s" % [_player.kit.plant_time, _dashed, after_blink, _fails])

	_pilot("pylon_engineer")
	_place(ground, Vector3.ZERO)
	await _sim(0.1)
	var hook_wall := _make_wall(_player.ball_position() + Vector3(0.0, 4.0, -14.0))
	_cam(_player.ball_position() + Vector3(0.0, 0.8, 4.0), hook_wall.global_position)
	await _ticks(3)
	_player.kit.plant_at = _player.ball_position()
	_player.kit.plant_normal = Vector3.UP
	_player.kit.plant_exit = exit_v
	_player.kit.plant_time = 0.28
	_clear_counts()
	_source.press = {"harpoon_pressed": true}
	_source.hold = {"harpoon_held": true}
	await _ticks(2)
	var after_hook: float = _player.state.velocity.length()
	_t.check("harpoon cancels slam plant on frame 0 without clipping velocity",
		_player.kit.plant_time == 0.0 and _player.kit.hooked and _grappled == 1 and after_hook >= 15.0 and _fails.is_empty(),
		"plant %.3f, hooked %s, speed %.2f, fails %s" % [_player.kit.plant_time, _player.kit.hooked, after_hook, _fails])
	_player.release_grapple()
	_source.hold = {}
	hook_wall.free()


func _test_ability_cast_buffers() -> void:
	_pilot("pylon_engineer")
	_place(_point(0.0, 0.0, 2.0), Vector3.ZERO)
	await _ticks(2)
	_set_slot_remaining(AbilityState.SPECIAL, 0.08)
	_clear_counts()
	_source.press = {"special_pressed": true}
	_source.hold = {"special_held": true}
	await _ticks(1)
	var spec_early_fails := _fails.duplicate()
	await _sim(0.12)
	_source.hold = {}
	_t.check("special_pressed buffers within 0.12 s and starts charging on ready",
		spec_early_fails.is_empty() and _special_charged >= 1,
		"fails %s, charged %d" % [spec_early_fails, _special_charged])
	_player.abilities.refill()

	_set_slot_remaining(AbilityState.SPECIAL, 0.60)
	_player.abilities.selected = AbilityState.SPECIAL
	_clear_counts()
	_source.press = {"special_pressed": true}
	await _ticks(2)
	_player.abilities.selected = AbilityState.WEAPON
	_t.check("special_pressed past 0.12 s emits raw cooling refusal",
		_fails.has(["fire", "cooling"]) and _special_charged == 0,
		"fails %s, charged %d" % [_fails, _special_charged])
	_player.abilities.refill()

	_set_slot_remaining(AbilityState.LINE, 0.08)
	_clear_counts()
	_source.press = {"line_pressed": true}
	await _ticks(1)
	var line_early_fails := _fails.duplicate()
	await _sim(0.12)
	_t.check("line_pressed buffers within 0.12 s and loads on ready",
		line_early_fails.is_empty() and _line_loaded == 1,
		"fails %s, loaded %d" % [line_early_fails, _line_loaded])
	_combat._line_load = {}
	_player.abilities.refill()

	var rack = _combat.actives
	rack.rack(ActiveDefs.SCRAP_ROCKET, true)
	rack.lock(0.08)
	_clear_counts()
	_source.press = {"active_pressed": true}
	await _ticks(1)
	var active_early_fails := _fails.duplicate()
	await _sim(0.12)
	_t.check("active_pressed buffers within 0.12 s of lock end and fires on frame 0",
		active_early_fails.is_empty() and _active_fired == 1,
		"fails %s, fired %d" % [active_early_fails, _active_fired])

	rack.rack(ActiveDefs.SCRAP_ROCKET, true)
	rack.lock(0.50)
	_clear_counts()
	_source.press = {"active_pressed": true}
	await _ticks(2)
	rack._locked = 0.0
	_t.check("active_pressed past 0.12 s lock emits jammed refusal",
		_fails == [["active", "jammed"]] and _active_fired == 0,
		"fails %s, fired %d" % [_fails, _active_fired])

	var ult = _combat.ultimate
	ult.meter.locked = false
	ult.meter.refund(UltimateMeter.CAP)
	ult._phase = ult.RECOVER
	ult._left = 0.08
	_clear_counts()
	_source.press = {"ultimate_pressed": true}
	await _ticks(1)
	var ult_early_fails := _fails.duplicate()
	await _sim(0.12)
	_t.check("ultimate_pressed buffers across final 0.08 s of RECOVER and fires on frame 0",
		ult_early_fails.is_empty() and _ult_started == 1,
		"fails %s, started %d" % [ult_early_fails, _ult_started])
	ult._abort("test")

	ult.meter.reset()
	ult.meter.refund(UltimateMeter.CAP - 1.0)
	_clear_counts()
	_source.press = {"ultimate_pressed": true}
	await _ticks(2)
	var near_fails := _fails.duplicate()
	ult.meter.refund(2.0)
	await _ticks(2)
	_t.check("ultimate_pressed near full buffers and fires on frame 0 when meter fills",
		near_fails.is_empty() and _ult_started == 1,
		"fails %s, started %d" % [near_fails, _ult_started])
	ult._abort("test")

	ult.meter.reset()
	_clear_counts()
	_source.press = {"ultimate_pressed": true}
	await _ticks(2)
	_t.check("ultimate_pressed at empty meter refuses uncharged immediately",
		_fails == [["ultimate", "uncharged"]] and _ult_started == 0,
		"fails %s, started %d" % [_fails, _ult_started])


func _test_reticle_frame0_feedback() -> void:
	var reticle := AimReticle.new()
	root.add_child(reticle)
	reticle.setup(_player, _game.camera.cam)
	_t.near("reticle ack starts at zero", reticle.ack_fraction(), 0.0, 0.0001)
	_game.events.grapple_fired.emit(_player.ball_position())
	_t.near("grapple_fired triggers frame-0 reticle ack pulse", reticle.ack_fraction(), 1.0, 0.0001)
	reticle.step(AimReticle.ACK_PULSE_S * 0.5)
	_t.check("reticle ack decays smoothly mid-pulse", reticle.ack_fraction() > 0.3 and reticle.ack_fraction() < 0.7,
		"frac %.3f" % reticle.ack_fraction())
	reticle.step(AimReticle.ACK_PULSE_S)
	_t.near("reticle ack returns cleanly to zero", reticle.ack_fraction(), 0.0, 0.0001)
	_game.events.shot_fired.emit("arc_caster", Vector3.ZERO, Vector3.FORWARD)
	_t.near("shot_fired triggers frame-0 reticle ack pulse", reticle.ack_fraction(), 1.0, 0.0001)
	_t.eq("reticle ack adds no words", reticle.drawn_words(), PackedStringArray())
	reticle.free()
