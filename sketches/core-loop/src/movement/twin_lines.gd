extends RefCounted

const Augments := preload("res://src/movement/augments.gd")

# Twin lines (docs/design/twin-lines.md), a prototype behind `--twin-lines=on`, off by default.
# A second, hand-fitted line beside the harpoon: the off line. Middle mouse (or the mouse's
# back button) and the right stick click fire it at the reticle and hold it; letting go drops
# it. It bites the world only, so combat is unchanged. Two things pay:
#
#   clean release  let go of a swinging line (the off line or the harpoon's world line) on the
#                  up-swing and the ball keeps RELEASE_GAIN more speed. The line glows while a
#                  release would pay, so the read is "let go when it lights".
#   the sling      with both lines on the world, Ctrl reels both. Tension builds while both are
#                  drawn; let go of the off line as the ball crosses between the two anchors and
#                  the stored tension throws it on: up to SLING_SPEED more metres a second.
#
# The off line has SHOTS bites per time in the air (the ground refills them) and frays after
# HOLD_MAX seconds, so it swings and slings but never hangs the ball over a gap for free.
#
# One call from the ball (rigid_ball.gd, after the augments) runs the whole rule, and the view
# draws itself from this object's state. Nothing else reads or writes it.

const FLAG := "twin-lines"
const ACTION := "cl_twin"

const SHOTS := 2
const HOLD_MAX := 3.5
const FRAY := 0.8
const MIN_ROPE := Augments.MIN_ROPE
# The up-swing window: the ball's climb angle, in degrees, inside which a release pays in full,
# fading to nothing at the outer edges. Below MIN_SPEED nothing pays.
const WINDOW_LOW := 0.0
const WINDOW_HIGH := 45.0
const WINDOW_FADE := 15.0
const MIN_SPEED := 8.0
const RELEASE_GAIN := 0.18
# Tension fills over TENSION_TIME while both lines reel; the sling pays in full inside
# SLING_GAP of half the anchors' span from the point between them.
const TENSION_TIME := 0.7
const SLING_SPEED := 16.0
const SLING_GAP := 0.45
const SPEED_CEILING := 48.0

static var _on = null

var hooked := false
var anchor := Vector3.ZERO
var rope := 0.0
var held_for := 0.0
var shots := SHOTS
var tension := 0.0
# What a release would pay right now, 0 to 1; the view's glow reads it.
var pay := 0.0
# The last release that paid: its gain as a fraction and the time it happened, for the view.
var last_gain := 0.0
var last_gain_at := -1000.0
var _harpoon_world := false
var _ball: RigidBody3D
var _view


# The flag, read once from the launch args (engine or user args): `--twin-lines=on`.
static func enabled() -> bool:
	if _on == null:
		_on = false
		var args := OS.get_cmdline_args()
		args.append_array(OS.get_cmdline_user_args())
		for arg in args:
			if arg == "--%s=on" % FLAG:
				_on = true
	return _on


# Tests and tools switch the prototype without launch args.
static func force(on: bool) -> void:
	_on = on


# The ball's twin lines, or null with the flag off, so the ball's one call costs nothing.
static func create(ball: RigidBody3D):
	if not enabled():
		return null
	_bind_action()
	var twin = new()
	twin._ball = ball
	var View := load("res://src/presentation/twin_line_view.gd")
	twin._view = View.new()
	twin._view.twin = twin
	twin._view.ball = ball
	ball.add_child(twin._view)
	return twin


static func _bind_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	for button in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1]:
		var click := InputEventMouseButton.new()
		click.button_index = button
		InputMap.action_add_event(ACTION, click)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_RIGHT_STICK
	InputMap.action_add_event(ACTION, pad)


# One physics tick: fire, hold, reel, pay a release. `kit` is the ball's augment kit (its
# harpoon line and the shared aim record), `state` the ball state.
func step(kit, state, tuning, intent, body_state) -> void:
	var dt: float = body_state.step
	var v: Vector3 = body_state.linear_velocity
	var origin: Vector3 = body_state.transform.origin
	if state.grounded:
		shots = SHOTS
	var harpoon_world: bool = kit.hooked and not kit.on_body
	var both := hooked and harpoon_world
	# The harpoon's own let-go on a world line pays a clean release too (the up-swing window
	# only; a sling is the off line's).
	if intent.harpoon_released and _harpoon_world and not kit.hooked:
		v = _pay(v, swing_pay(v, origin, kit.anchor))
	_harpoon_world = harpoon_world

	if intent.twin_pressed and not hooked:
		_fire(kit, origin, tuning.f("rope_range"))
	elif hooked and (intent.twin_released or not intent.twin_held):
		if both:
			v = _sling(v, sling_pay(v, origin, anchor, kit.anchor, tension))
		else:
			v = _pay(v, swing_pay(v, origin, anchor))
		_drop()
	if hooked:
		held_for += dt
		if held_for >= HOLD_MAX:
			_drop()
	if hooked:
		var reeling: bool = both and kit.winching
		tension = minf(1.0, tension + dt / TENSION_TIME) if reeling else maxf(0.0, tension - dt / TENSION_TIME)
		v = _rope(v, origin, tuning, dt, reeling)
		pay = sling_pay(v, origin, anchor, kit.anchor, tension) / SLING_SPEED if both \
				else swing_pay(v, origin, anchor) / RELEASE_GAIN
	else:
		tension = 0.0
		pay = swing_pay(v, origin, kit.anchor) / RELEASE_GAIN if harpoon_world else 0.0
	body_state.linear_velocity = v


func fraying() -> float:
	return clampf((held_for - (HOLD_MAX - FRAY)) / FRAY, 0.0, 1.0) if hooked else 0.0


func clear() -> void:
	_drop()
	shots = SHOTS
	_harpoon_world = false


func _fire(kit, origin: Vector3, reach: float) -> void:
	if shots <= 0:
		return
	var point = _world_point(kit, origin, reach)
	if point == null:
		return
	shots -= 1
	hooked = true
	anchor = point
	rope = maxf(MIN_ROPE, origin.distance_to(anchor))
	held_for = 0.0


# The off line bites where the reticle aims, on the world only: an enemy under the reticle is
# looked past along the same ray, and walkable ground is refused as the harpoon refuses it.
func _world_point(kit, origin: Vector3, reach: float):
	var aim: Dictionary = kit.aim
	var kind: int = aim.get("state", Augments.AIM_NONE)
	if kind == Augments.AIM_NONE:
		return null
	if kind != Augments.AIM_BODY:
		return aim["point"]
	var point: Vector3 = aim["point"]
	var dir := (point - origin).normalized()
	var space := _ball.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, Augments.WORLD_MASK)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or (hit["normal"] as Vector3).y >= Augments.WALKABLE_Y:
		return null
	return hit["position"]


func _drop() -> void:
	hooked = false
	held_for = 0.0
	tension = 0.0


# The off line's rope: a winch while the sling reels, then the same no-stretch rule as the
# harpoon's world line (augments.gd _grapple), which turns a fall into a pendulum.
func _rope(v: Vector3, origin: Vector3, tuning, dt: float, reeling: bool) -> Vector3:
	var to_anchor := anchor - origin
	var dist := to_anchor.length()
	if dist < 0.001:
		return v
	var dir := to_anchor / dist
	if reeling:
		rope = maxf(MIN_ROPE, minf(rope, dist))
		var head := clampf(1.0 - v.dot(dir) / tuning.f("reel_speed"), 0.0, 1.0)
		if dist > MIN_ROPE:
			v += dir * tuning.f("reel_force") * head * dt
	if dist > rope:
		var outward := -v.dot(dir)
		if outward > 0.0:
			v += dir * outward
		v += dir * (dist - rope) * tuning.f("rope_spring")
	return v


# A clean release: `gain` more speed along the way the ball already goes.
func _pay(v: Vector3, gain: float) -> Vector3:
	if gain <= 0.0:
		return v
	_paid(gain / RELEASE_GAIN)
	var speed := v.length()
	return v.normalized() * maxf(speed, minf(speed * (1.0 + gain), SPEED_CEILING))


# A sling: `add` metres a second along the way the ball already goes.
func _sling(v: Vector3, add: float) -> Vector3:
	if add <= 0.0:
		return v
	_paid(add / SLING_SPEED)
	var speed := v.length()
	return v.normalized() * maxf(speed, minf(speed + add, SPEED_CEILING))


# `share` is how full the payment was, 0 to 1; the view rings its chime at that strength.
func _paid(share: float) -> void:
	last_gain = share
	last_gain_at = Time.get_ticks_msec() / 1000.0
	if _view != null:
		_view.released(share)


# What letting go of a swinging line pays now, as a speed fraction: full inside the up-swing
# window, fading over WINDOW_FADE degrees either side; nothing while the ball is above its
# anchor (that is a fall, not a swing) or slower than MIN_SPEED.
static func swing_pay(v: Vector3, origin: Vector3, at: Vector3) -> float:
	if v.length() < MIN_SPEED or origin.y >= at.y:
		return 0.0
	var climb := rad_to_deg(asin(clampf(v.normalized().y, -1.0, 1.0)))
	var off := 0.0
	if climb < WINDOW_LOW:
		off = WINDOW_LOW - climb
	elif climb > WINDOW_HIGH:
		off = climb - WINDOW_HIGH
	return RELEASE_GAIN * clampf(1.0 - off / WINDOW_FADE, 0.0, 1.0)


# What letting go of the off line pays with both lines on the world: the stored tension, in full
# while the ball is within SLING_GAP of the point between the anchors (as a share of half the
# span), fading to nothing at twice that, and only above MIN_SPEED. Returns metres a second.
static func sling_pay(v: Vector3, origin: Vector3, a: Vector3, b: Vector3, stored: float) -> float:
	if stored <= 0.0 or v.length() < MIN_SPEED:
		return 0.0
	var half := maxf(1.0, a.distance_to(b) * 0.5)
	var off := origin.distance_to((a + b) * 0.5) / half
	var share := clampf((2.0 * SLING_GAP - off) / SLING_GAP, 0.0, 1.0)
	return SLING_SPEED * stored * share
