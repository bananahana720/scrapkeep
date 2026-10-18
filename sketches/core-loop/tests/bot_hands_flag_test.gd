extends SceneTree

# Rule: the traversal bot's optional hands (traversal_line.gd --hands=, bot_driver.gd HAND_NAMES)
# are off unless named, parse in the order given, and do not fire without a target or the glide
# augment. The cheap guard under the slow bot lines: a bare pilot's baselines hold only while a
# driver with no hands decides nothing here. The lines themselves are the proof of what the hands
# measure; this file proves the flag and the gates.

const Augments := preload("res://src/movement/augments.gd")
const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const TraversalLine := preload("res://tools/traversal_line.gd")
const T := preload("res://tests/support/t.gd")
const EXPECTED_CHECKS := 23
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
	var all_known := true
	for hand in parse.call(["--hands=harpoon,glide"]):
		all_known = all_known and hand in BotDriver.HAND_NAMES
	_t.check("the flag's hands are all known", all_known)
	_t.check("a typo is not a known hand", not "harpon" in BotDriver.HAND_NAMES)


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
