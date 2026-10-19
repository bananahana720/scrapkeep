extends SceneTree

# Rule: the traversal bot's optional hands (traversal_line.gd --hands=, bot_driver.gd HAND_NAMES)
# are off unless named, parse in the order given, and do not fire without a target or the glide
# augment. The cheap guard under the slow bot lines: a bare pilot's baselines hold only while a
# driver with no hands decides nothing here. The lines themselves are the proof of what the hands
# measure; this file proves the flag and the gates.

const Augments := preload("res://src/movement/augments.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const TraversalLine := preload("res://tools/traversal_line.gd")
const T := preload("res://tests/support/t.gd")
const EXPECTED_CHECKS := 35
const DT := 1.0 / 90.0

var _t := T.new("bot_hands_flag_test")
var _game
var _player
var _driver


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	_parse_cases()
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_player = _game.player
	for i in 36:
		await physics_frame
	_player.set_physics_process(false)
	_driver = BotDriver.new(_game, "traversal", 1)
	_player.source = _driver.source
	_default_is_bare()
	_glide_needs_the_augment()
	_harpoon_needs_speed_and_a_target()
	await _harpoon_bites_a_world_anchor()
	_glide_holds_over_a_drop()
	_no_q_while_the_hand_looks()
	_t.eq("check count", _t.checks, EXPECTED_CHECKS)
	var code := _t.verdict()
	quit(code)


func _parse_cases() -> void:
	var parse := func(args: Array) -> Array[String]:
		return TraversalLine.hands_of(TraversalLine._parse(PackedStringArray(args)))
	_t.eq("no flag names no hand", parse.call(["--pilot=kest"]), [])
	_t.eq("both hands in the order given", parse.call(["--hands=glide,harpoon"]), ["glide", "harpoon"])
	_t.eq("one hand", parse.call(["--hands=harpoon"]), ["harpoon"])
	_t.eq("an empty value names no hand", parse.call(["--hands="]), [])
	_t.eq("the known hands", BotDriver.HAND_NAMES, ["harpoon", "glide"])
	var named: Array = parse.call(["--hands=harpoon,glide"])
	_t.eq("the flag's hands are all known", named.filter(func(h): return h in BotDriver.HAND_NAMES), named)
	var typo: Array = parse.call(["--hands=harpon"])
	_t.eq("a typo parses but names no known hand", typo.filter(func(h): return h in BotDriver.HAND_NAMES), [])
	var kept: Array[String] = []
	_t.eq("a bare run writes <pilot>.json", TraversalLine.summary_name("kest", kept), "kest.json")
	_t.eq("a hands run writes <pilot>.hands.json", TraversalLine.summary_name("kest", named), "kest.hands.json")


func _set_hands(names: Array) -> void:
	var typed: Array[String] = []
	for name in names:
		typed.append(name)
	_driver.hands = typed


func _step(point: Vector3) -> Variant:
	_driver.source.press.clear()
	_driver.source.hold.clear()
	_driver._harpoon_held = false
	return _driver._traverse_hands(_player.ball_position(), point, DT)


func _default_is_bare() -> void:
	var point: Vector3 = _player.ball_position() + Vector3(0.0, 0.0, 40.0)
	_t.eq("a new driver has no hands", _driver.hands, [])
	_player.set_velocity_now(Vector3.FORWARD * 20.0)
	_player.state.grounded = false
	var aim = _step(point)
	_t.check("no hands: no aim", aim == null)
	_t.check("no hands: no harpoon press", not _driver.source.press.has("harpoon_pressed"))
	_t.check("no hands: no harpoon hold", not _driver._harpoon_held)
	_t.check("no hands: glide not held", not _driver._glide_held)
	_t.check("no hands: no jump press", not _driver.source.press.has("jump_pressed"))


func _glide_needs_the_augment() -> void:
	_set_hands(["glide"])
	var point: Vector3 = _player.ball_position() + Vector3(0.0, 0.0, 40.0)
	_player.kit.set_on("glide", false)
	_player.state.grounded = false
	_player.set_velocity_now(Vector3(0.0, -8.0, -20.0))
	_step(point)
	_t.check("glide hand: a kit without the augment never holds glide", not _driver._glide_held and not _driver._gliding)
	_player.state.grounded = true
	_player.kit.set_on("glide", true)
	_step(point)
	_t.check("glide hand: grounded never holds glide", not _driver._glide_held and not _driver._gliding)
	_set_hands(["harpoon"])
	_step(point)
	_t.check("harpoon-only: glide hand stays off", not _driver._glide_held)


func _harpoon_needs_speed_and_a_target() -> void:
	_set_hands(["harpoon"])
	_driver._swing_cool = 0.0
	_driver._swing_sent = 0.0
	var point: Vector3 = _player.ball_position() + Vector3(0.0, 0.0, 40.0)
	_player.state.grounded = false
	_player.set_velocity_now(Vector3.ZERO)
	_step(point)
	_t.check("harpoon hand: a still ball presses nothing", not _driver.source.press.has("harpoon_pressed"))
	_t.check("harpoon hand: a still ball holds nothing", not _driver._harpoon_held)
	_driver._swing_cool = 5.0
	_player.set_velocity_now(Vector3.FORWARD * 20.0)
	_step(point)
	_t.check("harpoon hand: the cool-down holds the next bite", not _driver.source.press.has("harpoon_pressed"))
	_driver._swing_cool = 0.0
	_player.kit.set_on(Augments.GRAPPLE, false)
	var presses := 0
	for tick in 30:
		_step(point)
		if _driver.source.press.has("harpoon_pressed"):
			presses += 1
	_t.eq("harpoon hand: a kit without the harpoon never presses it", presses, 0)
	_t.check("harpoon hand: and holds no line", not _driver._harpoon_held)
	_t.check("harpoon hand: a point on the ball gives no way, so no press",
		_step(_player.ball_position()) == null and not _driver.source.press.has("harpoon_pressed"))
	_t.check("the hands leave the default press map empty", _driver.source.press.is_empty())


func _glide_holds_over_a_drop() -> void:
	_set_hands(["glide"])
	_player.kit.set_on("glide", true)
	_player.state.grounded = false
	var ball: Vector3 = _player.ball_position()
	var high := Vector3(ball.x, _driver._ground_point(ball.x, ball.z).y + 40.0, ball.z)
	var way := Vector3.FORWARD
	_player.set_velocity_now(way * 20.0)
	var far_low: Vector3 = high + way * 80.0 + Vector3.DOWN * 30.0
	_driver._gliding = false
	_driver._glide_hand(high, far_low)
	_t.check("glide hand: a 40 m drop toward a distant lower waypoint holds glide", _driver._glide_held and _driver._gliding)
	_driver._gliding = false
	_driver._glide_held = false
	_driver._glide_hand(high, high + way * 20.0 + Vector3.DOWN * 30.0)
	_t.check("glide hand: a waypoint inside GLIDE_NEAR is not overflown", not _driver._gliding)
	_driver._glide_hand(high, high + way * 80.0 + Vector3.UP * 5.0)
	_t.check("glide hand: a waypoint above the ball is not overflown", not _driver._gliding)
	_driver._glide_hand(high, far_low)
	_driver.source.press.clear()
	_driver.source.hold.clear()
	_driver._shift_left = 1.0
	_driver.source.press["shift_pressed"] = true
	_player.state.velocity.y = -5.0
	_player.state.air_actions = 0
	_driver._drive(far_low, null, DT)
	_t.check("glide hand: the drop holds the jump key while falling", _driver.source.hold.get("jump_held", false))
	_t.check("glide hand: the drop clears a leftover blink hold and press",
		not _driver.source.hold.has("shift_held") and not _driver.source.press.has("shift_pressed"))
	_driver._shift_left = 0.0
	_t.eq("a bare trace stem is the pilot", TraversalLine.trace_stem("kest", []), "kest")
	_t.eq("a hands trace stem is apart", TraversalLine.trace_stem("kest", ["glide"]), "kest.hands")


func _harpoon_bites_a_world_anchor() -> void:
	_set_hands(["harpoon"])
	_driver._swing_cool = 0.0
	_driver._swing_sent = 0.0
	_player.kit.set_on(Augments.GRAPPLE, true)
	_player.set_physics_process(true)
	var ball: Vector3 = _player.ball_position()
	var way := Vector3.FORWARD
	var beam := StaticBody3D.new()
	beam.collision_layer = Augments.WORLD_MASK
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, 2.0, 12.0)
	shape.shape = box
	beam.add_child(shape)
	root.add_child(beam)
	beam.global_position = ball + way * 25.0 + Vector3.UP * 14.0
	await physics_frame
	var point: Vector3 = ball + way * 60.0
	var best_yaw := 0.0
	var best := -2.0
	var toward: Vector3 = (beam.global_position - ball).normalized()
	_game.camera.pitch = 0.5
	for yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
		_game.camera.yaw = yaw
		var dot: float = _game.camera.aim_forward().dot(toward)
		if dot > best:
			best = dot
			best_yaw = yaw
	_game.camera.yaw = best_yaw
	var hooked := false
	var pressed := false
	for tick in 120:
		if not hooked:
			_player.set_velocity_now(way * 20.0 + Vector3.UP * 0.5)
		_driver.source.press.clear()
		_driver.source.hold.clear()
		_driver._harpoon_held = false
		_driver._traverse_hands(_player.ball_position(), point, DT)
		pressed = pressed or _driver.source.press.has("harpoon_pressed")
		if _driver._harpoon_held:
			_driver.source.hold["harpoon_held"] = true
		await physics_frame
		if _player.kit.hooked:
			hooked = true
			break
	_t.check("harpoon hand: the hand presses the harpoon for it", pressed)
	_t.check("harpoon hand: the hook lands on the beam, a world anchor", hooked and not _player.kit.on_body \
			and _player.kit.anchor.distance_to(beam.global_position) < 8.0)
	beam.queue_free()
	_player.set_physics_process(false)


func _no_q_while_the_hand_looks() -> void:
	var ab = _player.abilities
	_driver._ult_wait = 0.0
	_driver._cast_phase = ""
	var ball: Vector3 = _player.ball_position()
	_driver._traverse_point = Vector3.INF
	for turn in 16:
		var at: Vector3 = ball + Vector3.FORWARD.rotated(Vector3.UP, TAU * turn / 16.0) * 40.0
		if _driver._way_clear(ball, at):
			_driver._traverse_point = at
			break
	ab.meter.locked = false
	ab.meter.value = ab.meter.CAP
	var ready: bool = String(ab.ultimate().get("state", "")) == AbilityState.READY
	_driver.source.press.clear()
	_driver._hand_aim = true
	_driver._ultimate_hands(null)
	var held_back: bool = not _driver.source.press.has("ultimate_pressed")
	_driver._hand_aim = false
	_driver._ultimate_hands(null)
	var sent: bool = _driver.source.press.has("ultimate_pressed")
	_t.check("Q: pressed with a clear way and no hand aim, held back while the hand looks at an anchor",
		ready and held_back and sent)
