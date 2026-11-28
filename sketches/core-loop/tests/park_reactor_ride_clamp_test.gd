# smoke: timeout=60s
extends SceneTree
const Reactor = preload("res://src/combat/warden_reactor.gd")
const Warden = preload("res://src/combat/warden.gd")
const Tuning = preload("res://src/movement/tuning.gd")
const T = preload("res://tests/support/t.gd")
var t = T.new("park_reactor_ride_clamp_test")

# The mounted spillway sheet's ride lifts a ball onto the core, not over it: a ball that enters
# the sheet's foot closing at 55 m/s peaks within the reactor's named RIDE_TOP_MARGIN of the
# core's height (unit BS1; the uncapped ride flung a fast ball 140 m and more above the dam).
# The cap is the dam ride's alone: an unmounted reactor sheet (other stages) keeps its uncapped lift.
const CLOSING := 55.0
const GRAVITY := 9.8

class Floor extends RefCounted:
	func height(_x: float, _z: float) -> float: return 0.0
class Body extends RefCounted:
	var linear_velocity := Vector3.ZERO
	func set_velocity_now(v: Vector3) -> void: linear_velocity = v
class Ball extends RefCounted:
	var at := Vector3.ZERO
	var rigid := Body.new()
	var tuning = null
	var last_accel := Vector3.ZERO
	func ball_position() -> Vector3: return at
	func body(): return rigid
	func add_external_accel(a: Vector3) -> void: last_accel = a
class Mount extends Node3D:
	const FAMILY_POINT_RADIUS = Warden.FAMILY_POINT_RADIUS
	var spec := {"park_landmark": true}
	var family := "reactor"
	var mounting := "dam_face"
	var home := Vector3(0, 0, 590)
	var terrain := Floor.new()
	var target := Ball.new()
	var fleet = null
	func family_point_at() -> Vector3: return home + Vector3.UP * 22.0
	func flat_to_ball() -> Vector3: return Vector3.FORWARD

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var named: Dictionary = load("res://src/combat/warden_reactor.gd").get_script_constant_map()
	t.check("the ride names its top margin", named.has("RIDE_TOP_MARGIN"), "warden_reactor.gd has no RIDE_TOP_MARGIN")
	var margin: float = float(named.get("RIDE_TOP_MARGIN", 0.0))
	t.check("the margin keeps the peak inside the core's contact reach", margin > 0.0 and margin < Warden.FAMILY_POINT_RADIUS + Tuning.RADIUS,
		"margin %.2f, contact reach %.2f" % [margin, Warden.FAMILY_POINT_RADIUS + Tuning.RADIUS])
	var m := Mount.new()
	var d := Reactor.new()
	d.sheet_left = 60.0
	d.sheet_dir = Vector3.FORWARD
	var core: float = m.family_point_at().y
	var dt := 1.0 / Engine.physics_ticks_per_second
	m.target.at = m.home + d.sheet_dir * (Reactor.SHEET_RUN - Tuning.RADIUS) + Vector3.UP * Tuning.RADIUS
	m.target.rigid.linear_velocity = -d.sheet_dir * CLOSING
	var peak := m.target.at.y
	var rides := 0
	for i in roundi(4.0 / dt):
		d._ride(m, dt)
		if d.riding:
			rides += 1
		var v: Vector3 = m.target.rigid.linear_velocity
		v.y -= GRAVITY * dt
		m.target.rigid.linear_velocity = v
		m.target.at += v * dt
		if m.target.at.y < Tuning.RADIUS:
			m.target.at.y = Tuning.RADIUS
			m.target.rigid.linear_velocity.y = maxf(0.0, m.target.rigid.linear_velocity.y)
		peak = maxf(peak, m.target.at.y)
	t.check("the 55 m/s ball rides the sheet", rides > 0, "ride ticks %d" % rides)
	t.check("the ride lifts the ball to the core's height", peak >= core - Tuning.RADIUS, "peak %.2f, core %.2f" % [peak, core])
	t.check("a 55 m/s ride peaks within the named margin of the core's height", peak <= core + margin,
		"peak %.2f, core %.2f, margin %.2f" % [peak, core, margin])
	m.free()
	_unmounted_ride_uncapped(margin)
	quit(t.verdict())


# An unmounted reactor's sheet (no park landmark, the stage 2 and alpha reactors) lifts the ball
# along its own profile with no cap: one ride tick's acceleration matches the uncapped climb.
func _unmounted_ride_uncapped(margin: float) -> void:
	var m := Mount.new()
	m.spec = {}
	var d := Reactor.new()
	d.sheet_left = 60.0
	d.sheet_dir = Vector3.FORWARD
	var core: float = m.family_point_at().y
	var dt := 1.0 / Engine.physics_ticks_per_second
	var along := 20.0
	var ground := Tuning.RADIUS
	var height: float = d._profile(m, m.home, along)
	m.target.at = m.home + d.sheet_dir * along + Vector3.UP * (height + 1.0)
	m.target.rigid.linear_velocity = -d.sheet_dir * CLOSING
	d._ride(m, dt)
	t.check("the unmounted 55 m/s ball rides the sheet", d.riding, "riding false at y %.2f" % m.target.at.y)
	var tt := (along - Reactor.SHEET_TOP) / (Reactor.SHEET_RUN - Reactor.SHEET_TOP)
	var rise := (core - ground) * 2.0 * (1.0 - tt) / (Reactor.SHEET_RUN - Reactor.SHEET_TOP) * CLOSING
	var want_vy: float = rise + Reactor.RIDE_GAIN * (height - m.target.at.y)
	var capped := sqrt(2.0 * GRAVITY * maxf(0.0, core + margin - m.target.at.y))
	var got_vy: float = (m.target.last_accel.y - GRAVITY) * dt
	t.check("the unmounted case would be capped if the cap applied", want_vy > capped + 1.0,
		"uncapped %.2f, cap %.2f" % [want_vy, capped])
	t.check("an unmounted ride keeps its uncapped lift", absf(got_vy - want_vy) < 0.05,
		"ride vy %.2f, uncapped %.2f, cap %.2f" % [got_vy, want_vy, capped])
	m.free()
