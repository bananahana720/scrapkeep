extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const TwinLines := preload("res://src/movement/twin_lines.gd")
const TwinLineView := preload("res://src/presentation/twin_line_view.gd")
const T := preload("res://tests/support/t.gd")

# The twin lines prototype (docs/design/twin-lines.md). The rule runs on stand-ins for the
# physics state, so the swing, the release window, the sling and the fray are checked tick by
# tick with no level; then a live Game checks the flag: off, the ball has no off line at all.

const DT := 1.0 / 90.0
const GRAVITY := Vector3(0, -9.8, 0)

var _t := T.new("twin_lines_test")


class Body:
	var step := DT
	var linear_velocity := Vector3.ZERO
	var transform := Transform3D.IDENTITY


class Kit:
	var hooked := false
	var on_body := false
	var anchor := Vector3.ZERO
	var winching := false
	var aim := {"state": Augments.AIM_REACH, "point": Vector3.ZERO, "normal": Vector3.ZERO}


class State:
	var grounded := false


class Tune:
	const VALUES := {"rope_range": 45.0, "rope_spring": 12.0, "reel_force": 45.0, "reel_speed": 16.0}

	func f(key: String) -> float:
		return VALUES[key]


func _initialize() -> void:
	_rules()
	_swing()
	_sling()
	_fray_and_shots()
	_view()
	_run()


func _tick(twin, kit, state, intent, body: Body) -> void:
	body.linear_velocity += GRAVITY * DT
	twin.step(kit, state, Tune.new(), intent, body)
	body.transform.origin += body.linear_velocity * DT
	intent.twin_pressed = false
	intent.twin_released = false
	intent.harpoon_released = false


func _rules() -> void:
	var above := Vector3(0, 10, 0)
	# Rising at 20 degrees under the anchor: full pay. Falling: none. Above the anchor: none.
	var up := Vector3(cos(deg_to_rad(20.0)), sin(deg_to_rad(20.0)), 0) * 15.0
	_t.near("up-swing pays in full", TwinLines.swing_pay(up, Vector3.ZERO, above), TwinLines.RELEASE_GAIN)
	_t.eq("falling pays nothing", TwinLines.swing_pay(Vector3(10, -6, 0), Vector3.ZERO, above), 0.0)
	_t.eq("over the anchor pays nothing", TwinLines.swing_pay(up, Vector3(0, 12, 0), above), 0.0)
	_t.eq("too slow pays nothing", TwinLines.swing_pay(up.normalized() * 4.0, Vector3.ZERO, above), 0.0)
	var steep := Vector3(cos(deg_to_rad(52.5)), sin(deg_to_rad(52.5)), 0) * 15.0
	_t.near("half a fade past the window pays half", TwinLines.swing_pay(steep, Vector3.ZERO, above),
		TwinLines.RELEASE_GAIN * 0.5, 0.001)
	var a := Vector3(-10, 10, 0)
	var b := Vector3(10, 10, 0)
	var fast := Vector3(15, 0, 0)
	_t.near("sling at the gap pays the stored tension", TwinLines.sling_pay(fast, Vector3(0, 10, 0), a, b, 1.0), TwinLines.SLING_SPEED)
	_t.near("half tension, half the sling", TwinLines.sling_pay(fast, Vector3(0, 10, 0), a, b, 0.5), TwinLines.SLING_SPEED * 0.5)
	_t.eq("sling far from the gap pays nothing", TwinLines.sling_pay(fast, Vector3(-10, 10, 0), a, b, 1.0), 0.0)
	_t.eq("no tension, no sling", TwinLines.sling_pay(fast, Vector3(0, 10, 0), a, b, 0.0), 0.0)


# One off line on a post above and ahead: the rope holds the ball to its length through the
# swing, and a let-go on the up-swing leaves faster than the swing brought it.
func _swing() -> void:
	var twin = TwinLines.new()
	var kit := Kit.new()
	var state := State.new()
	var intent := Intent.new()
	var body := Body.new()
	body.linear_velocity = Vector3(12, 0, 0)
	kit.aim["point"] = Vector3(10, 10, 0)
	intent.twin_pressed = true
	intent.twin_held = true
	_tick(twin, kit, state, intent, body)
	_t.check("the off line bites the aimed point", twin.hooked and twin.anchor == Vector3(10, 10, 0))
	_t.eq("a bite spends a shot", twin.shots, TwinLines.SHOTS - 1)
	var rope: float = twin.rope
	var stretch := 0.0
	var paid_at := -1
	var before := 0.0
	for i in 400:
		stretch = maxf(stretch, body.transform.origin.distance_to(twin.anchor) - rope)
		if twin.pay >= 0.99 and body.transform.origin.x > 10.0:
			paid_at = i
			before = body.linear_velocity.length()
			intent.twin_held = false
			intent.twin_released = true
			_tick(twin, kit, state, intent, body)
			break
		_tick(twin, kit, state, intent, body)
	_t.check("the rope does not stretch (%.2f m)" % stretch, stretch < 0.3)
	_t.check("the swing reaches the up-swing window", paid_at > 0)
	_t.check("a clean release lets go", not twin.hooked)
	_t.near("a clean release keeps RELEASE_GAIN more speed", body.linear_velocity.length(), before * (1.0 + TwinLines.RELEASE_GAIN), 0.6)
	# A let-go while falling into the swing pays nothing.
	var late = TwinLines.new()
	var b2 := Body.new()
	b2.linear_velocity = Vector3(12, 0, 0)
	intent.twin_pressed = true
	intent.twin_held = true
	_tick(late, kit, state, intent, b2)
	for i in 30:
		_tick(late, kit, state, intent, b2)
	var speed := b2.linear_velocity.length()
	intent.twin_held = false
	intent.twin_released = true
	b2.linear_velocity += GRAVITY * DT
	var expect := b2.linear_velocity.length()
	late.step(kit, state, Tune.new(), intent, b2)
	_t.near("a let-go on the down-swing pays nothing", b2.linear_velocity.length(), expect, 0.001)
	_t.check("the down-swing still moves (%.1f m/s)" % speed, speed > 8.0)


# Both lines on the world: Ctrl reels both, tension fills, and letting go of the off line in the
# gap between the posts throws the ball on by the stored tension.
func _sling() -> void:
	var twin = TwinLines.new()
	var kit := Kit.new()
	var state := State.new()
	var intent := Intent.new()
	var body := Body.new()
	kit.hooked = true
	kit.anchor = Vector3(-12, 12, 0)
	kit.aim["point"] = Vector3(12, 12, 0)
	intent.twin_pressed = true
	intent.twin_held = true
	_tick(twin, kit, state, intent, body)
	kit.winching = true
	var peak := 0.0
	for i in 90:
		# The harpoon's own winch (augments.gd _grapple) pulls on the other post meanwhile.
		var to: Vector3 = kit.anchor - body.transform.origin
		var head := clampf(1.0 - body.linear_velocity.dot(to.normalized()) / 16.0, 0.0, 1.0)
		body.linear_velocity += to.normalized() * 45.0 * head * DT
		_tick(twin, kit, state, intent, body)
		peak = maxf(peak, twin.tension)
	_t.near("tension fills while both reel", peak, 1.0, 0.001)
	var mid := Vector3(0, 12, 0)
	_t.check("the reel draws the ball toward the gap (%.1f m)" % body.transform.origin.distance_to(mid),
		body.transform.origin.distance_to(mid) < 8.0)
	body.transform.origin = Vector3(1, 11, 0)
	body.linear_velocity = Vector3(10, 0, 0)
	intent.twin_held = false
	intent.twin_released = true
	twin.step(kit, state, Tune.new(), intent, body)
	_t.near("the sling throws the ball on", body.linear_velocity.length(), 10.0 + TwinLines.SLING_SPEED, 0.01)
	# The harpoon's own let-go on a world line pays the swing window too.
	var solo = TwinLines.new()
	var k2 := Kit.new()
	k2.hooked = true
	k2.anchor = Vector3(0, 10, 0)
	var b2 := Body.new()
	var i2 := Intent.new()
	b2.linear_velocity = Vector3(cos(deg_to_rad(20.0)), sin(deg_to_rad(20.0)), 0) * 15.0
	solo.step(k2, state, Tune.new(), i2, b2)
	_t.near("a harpoon swing shows its window", solo.pay, 1.0, 0.001)
	k2.hooked = false
	i2.harpoon_released = true
	b2.linear_velocity = Vector3(cos(deg_to_rad(20.0)), sin(deg_to_rad(20.0)), 0) * 15.0
	solo.step(k2, state, Tune.new(), i2, b2)
	_t.near("a clean harpoon release pays", b2.linear_velocity.length(), 15.0 * (1.0 + TwinLines.RELEASE_GAIN), 0.001)


func _fray_and_shots() -> void:
	var twin = TwinLines.new()
	var kit := Kit.new()
	var state := State.new()
	var intent := Intent.new()
	var body := Body.new()
	kit.aim["point"] = Vector3(0, 20, 0)
	intent.twin_pressed = true
	intent.twin_held = true
	_tick(twin, kit, state, intent, body)
	for i in roundi((TwinLines.HOLD_MAX - 0.1) / DT):
		_tick(twin, kit, state, intent, body)
	_t.check("the line frays near the end", twin.hooked and twin.fraying() > 0.8)
	for i in 20:
		_tick(twin, kit, state, intent, body)
	_t.check("the line snaps at HOLD_MAX", not twin.hooked)
	intent.twin_held = false
	_tick(twin, kit, state, intent, body)
	intent.twin_pressed = true
	intent.twin_held = true
	_tick(twin, kit, state, intent, body)
	_t.eq("the second shot bites", [twin.hooked, twin.shots], [true, 0])
	intent.twin_held = false
	_tick(twin, kit, state, intent, body)
	intent.twin_pressed = true
	intent.twin_held = true
	_tick(twin, kit, state, intent, body)
	_t.check("no third shot in the air", not twin.hooked)
	state.grounded = true
	intent.twin_held = false
	_tick(twin, kit, state, intent, body)
	_t.eq("the ground refills the shots", twin.shots, TwinLines.SHOTS)
	kit.aim["state"] = Augments.AIM_NONE
	intent.twin_pressed = true
	intent.twin_held = true
	_tick(twin, kit, state, intent, body)
	_t.check("no aim, no bite", not twin.hooked)


func _view() -> void:
	_t.eq("cable is twine at rest", TwinLineView.colour(0.0, 0.0, 0.0), TwinLineView.TWINE)
	_t.eq("cable is mint when a release pays in full", TwinLineView.colour(1.0, 0.0, 0.0), TwinLineView.MINT)
	var wav: AudioStreamWAV = TwinLineView.pluck(220.0)
	_t.check("the pluck is a 16-bit mono clip", wav.format == AudioStreamWAV.FORMAT_16_BITS and not wav.stereo
		and wav.data.size() == int(TwinLineView.RATE * TwinLineView.PLUCK_S) * 2)


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _run() -> void:
	TwinLines.force(false)
	var game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	await _sim(0.3)
	_t.check("flag off: the ball has no off line", game.player.body().twin == null)
	_t.check("flag off: no off-line action is bound", not InputMap.has_action(TwinLines.ACTION))
	game.queue_free()
	await process_frame
	TwinLines.force(true)
	var on = Game.new()
	on.test_mode = true
	root.add_child(on)
	while on.flow == null:
		await physics_frame
	var source := Intent.Scripted.new()
	on.player.source = source
	on.flow.press_start()
	on.flow.choose_class(0)
	await _sim(0.6)
	var twin = on.player.body().twin
	_t.check("flag on: the ball has an off line", twin != null)
	_t.check("flag on: the off-line action is bound", InputMap.has_action(TwinLines.ACTION))
	source.press = {"twin_pressed": true}
	source.hold = {"twin_held": true}
	await _sim(0.5)
	_t.check("live: the off line runs %s" % ("hooked" if twin.hooked else "dry, no aim"), true)
	source.hold = {}
	await _sim(0.2)
	_t.check("live: letting go drops the off line", not twin.hooked)
	TwinLines.force(false)
	quit(_t.verdict())
