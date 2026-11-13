extends SceneTree

const Game := preload("res://src/game.gd")
const Activities := preload("res://src/world/activities.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const T := preload("res://tests/support/t.gd")
const Augments := preload("res://src/movement/augments.gd")

# W1-76, the dam's blazing cache: the park row's `bar: "blazing"` raises the cracked cache's wall to
# a ram at the blazing tier of the unmodded cruise (activities.gd BARS and ram_bar, read here, not
# copied). On the live dam: the bar is that tier and every other cache keeps the ordinary bar; a slam well
# over cruise's strength leaves the wall; a ram just under the bar leaves it and plays the roll's
# refused cue. On the line itself, a roll from the incline's top at cruise is refused and the same roll
# after a surge breaks it, and one part waits on the pedestal.

const RAM_FRAMES := 150
const UNDER := 0.9
const ROLL_M := 50.0
const ROLL_FRAMES := 90 * 5

var _t := T.new("blazing_cache_test")
var _game
var _refused := 0
var _done: Array = []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.events.activity_done.connect(func(id: String, _at: Vector3): _done.append(id))
	_game.events.verb_failed.connect(func(verb: String, _reason: String, _at: Vector3):
		if verb == "roll":
			_refused += 1)
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.ctx.calm = true
	await _frames(30)
	var acts = _game.world.activities
	var barred: Array = acts.sites.filter(func(x): return x.rule.has("bar_tier"))
	var plain: Array = acts.sites.filter(func(x): return x.id == "cracked_cache" and not x.rule.has("bar_tier"))
	_t.check("the dam stands one blazing cache beside its plain ones", barred.size() == 1 and plain.size() >= 1,
		"%d barred, %d plain" % [barred.size(), plain.size()])
	if barred.size() != 1 or plain.is_empty():
		quit(_t.verdict())
		return
	var s = barred[0]
	var bar: float = acts.ram_bar(s)
	var blazing: float = _game.ctx.tuning.tier_cruise() * SpeedTier.MULTIPLES[Activities.BARS["blazing"]]
	_t.check("the bar is the blazing tier", is_equal_approx(bar, blazing) and Activities.BARS["blazing"] == SpeedTier.BLAZING,
		"bar %.2f m/s, blazing %.2f m/s" % [bar, blazing])
	var ordinary: float = _game.ctx.tuning.f("cruise") * Activities.RAM_MIN_PER_CRUISE
	_t.check("every plain cache keeps the ordinary bar", plain.all(func(x): return is_equal_approx(acts.ram_bar(x), ordinary)), "%.2f m/s" % ordinary)
	var back: Vector3 = s.global_basis.z
	var heading := -back
	# A slam half again over the strength that breaks an ordinary wall.
	var slam_at: Vector3 = s.global_position + back * 3.0
	_put(_ground(s.global_position + back * 40.0))
	await _frames(3)
	var cruise: float = _game.ctx.tuning.f("cruise")
	acts._slammed(slam_at, _game.player.slam_strength(cruise) * Activities.SLAM_MIN_PER_CRUISE * 1.5)
	await _frames(2)
	_t.check("a slam does not break it", not s.done and s.wall.visible, "done %s" % s.done)
	await _ram(s, _ground(s.global_position + back * 16.0), heading * bar * UNDER)
	_t.check("a ram just under the bar leaves it", not s.done and s.wall.visible, "ram %.1f m/s against %.1f" % [bar * UNDER, bar])
	# The line itself (W1-76): the cache stands ROLL_M down the construction incline. A ball that tops the
	# incline at cruise and rolls with no input meets the face under the bar and hears the refused cue; the
	# same roll after a Shift's surge breaks it.
	var tier: float = _game.ctx.tuning.tier_cruise()
	var refused_before := _refused
	await _roll(s, back, tier)
	_t.check("a roll down the incline at cruise is refused", not s.done and s.wall.visible and _refused > refused_before,
		"done %s, %d cues" % [s.done, _refused - refused_before])
	# A Shift's surge leaves the ball at the dash floor times SURGE_SCALE (augments.gd), 20.8 m/s at base.
	var surge: float = _game.ctx.tuning.f("dash_impulse") * Augments.SURGE_SCALE
	await _roll(s, back, surge)
	_t.check("the same roll after a surge breaks it", s.done and not s.wall.visible and _done.count("cracked_cache") == 1,
		"start %.1f m/s: done %s" % [surge, s.done])
	_t.check("one part waits on the pedestal", s.pickup != null, "pickup %s" % [s.pickup])
	quit(_t.verdict())


func _ground(at: Vector3) -> Vector3:
	return _game.ctx.terrain.drop_point(at.x, at.z, 1.05)


func _put(at: Vector3, velocity := Vector3.ZERO) -> void:
	_game.player.reset_to(at, velocity)
	_game.player.set_velocity_now(velocity)


# Holds the ram's speed until the ball is 6 m from the face, as activities_test does.
func _ram(s, start: Vector3, velocity: Vector3) -> void:
	_put(start, velocity)
	await physics_frame
	for i in RAM_FRAMES:
		if s.to_local(_game.player.ball_position()).z > 6.0:
			_game.player.set_velocity_now(velocity)
		await physics_frame
		var l: Vector3 = s.to_local(_game.player.ball_position())
		if l.z < -1.0 or s.done:
			break


# A roll from ROLL_M up the line at `speed`, then no input until the wall breaks or the ball stops.
func _roll(s, back: Vector3, speed: float) -> void:
	var dir := Vector3(-back.x, 0.0, -back.z).normalized()
	_put(_ground(s.global_position + back * ROLL_M), dir * speed)
	for i in ROLL_FRAMES:
		await physics_frame
		if s.done or (i > 30 and _game.player.planar_velocity().length() < 1.0):
			break
