extends SceneTree

const Augments := preload("res://src/movement/augments.gd")
const AugmentKit := preload("res://src/movement/augment_kit.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# PF2 (design-v3/POLES-FLAILS.md section 4): a pole line rides a heavy enemy like an anchor.
# Held, the ball winches in and orbits at pole_rope instead of passing the body; Ctrl stays
# open; the body braces at POLE_BRACE and snaps the line at POLE_BRACE + POLE_SNAP with an
# outward kick; no orbit outlasts 2.0 s. The let-go adds POLE_EXIT of the speed across the
# line, never past the soft cap. A reel line on the same body keeps today's pass-through drop.

const STEP := 1.0 / 60.0

var _t := T.new("pole_ride_test")


class FakeHeavy extends CharacterBody3D:
	var kind := "plated_brute"
	var radius := 1.3
	var threat_level := 1.0
	var spec := {}
	func anchor_point(point: Vector3, _from = null) -> Vector3:
		return point
	func anchor_velocity() -> Vector3:
		return velocity


class FakeState:
	var transform := Transform3D.IDENTITY
	var linear_velocity := Vector3.ZERO


func _initialize() -> void:
	_main()


func _main() -> void:
	await process_frame
	_run()
	quit(_t.verdict())


func _setup(grip: String) -> Array:
	var body := FakeHeavy.new()
	body.add_to_group("enemy")
	root.add_child(body)
	var kit := AugmentKit.new()
	var state := FakeState.new()
	state.transform.origin = Vector3(20.0, 0.0, 0.0)
	state.linear_velocity = Vector3(0.0, 0.0, 16.0)
	Augments.attach(kit, state.transform.origin, body.global_position, Vector3.RIGHT, body)
	kit.grip = grip
	return [body, kit, state]


func _tick(kit, tuning, intent, state) -> void:
	Augments._grapple(kit, tuning, intent, state, STEP)
	state.transform.origin += state.linear_velocity * STEP


func _run() -> void:
	var tuning := Tuning.new()
	var intent := Intent.new()
	intent.harpoon_held = true

	var set := _setup("pole")
	var body: Node3D = set[0]
	var kit = set[1]
	var state: FakeState = set[2]
	_t.check("a pole is a pole line", Augments.pole_line(kit))
	_t.check("Ctrl stays open on a pole", Augments.haul_open(kit))
	var rope := Augments.pole_rope(body)
	var closest := INF
	var held := 0.0
	var braced_seen := false
	var kick_speed := 0.0
	while kit.hooked and held < 3.0:
		var before := state.linear_velocity
		_tick(kit, tuning, intent, state)
		held += STEP
		if held > 1.0:
			closest = minf(closest, state.transform.origin.distance_to(body.global_position))
		if Augments.pole_bracing(kit):
			braced_seen = true
		if not kit.hooked:
			var away := (state.transform.origin - body.global_position).normalized()
			kick_speed = (state.linear_velocity - before).dot(away)
	_t.check("the winch pulls the ball in", closest < 16.0, "closest %.2f" % closest)
	_t.check("the orbit holds off the hull", closest >= rope - 0.5, "closest %.2f rope %.2f" % [closest, rope])
	_t.check("the body braced before the snap", braced_seen)
	_t.eq("the line snaps on the brace", kit.line_end, "brace")
	_t.near("the snap comes at brace plus snap", held, Augments.POLE_BRACE + Augments.POLE_SNAP, STEP * 1.5)
	_t.check("no orbit outlasts 2.0 s", held <= 2.0 + STEP)
	_t.check("the snap kicks outward", kick_speed >= Augments.POLE_KICK - 0.01, "kick %.2f" % kick_speed)

	var reel := _setup("reel")
	var rkit = reel[1]
	var rstate: FakeState = reel[2]
	rstate.linear_velocity = Vector3.ZERO
	_t.check("a reel is not a pole line", not Augments.pole_line(rkit))
	var t := 0.0
	while rkit.hooked and t < 4.0:
		_tick(rkit, tuning, intent, rstate)
		t += STEP
	_t.eq("a reel line still drops on the pass", rkit.line_end, "passed")

	var v := Vector3(0.0, 0.0, 20.0)
	var out := Augments.pole_exit(v, Vector3.RIGHT, Augments.POLE_EXIT)
	_t.near("exit adds 15% across the line", out.length(), 23.0, 0.001)
	var fast := Augments.pole_exit(Vector3(0.0, 0.0, 58.0), Vector3.RIGHT, Augments.POLE_EXIT_SABLE)
	_t.near("exit stops at the soft cap", fast.length(), Augments.POLE_EXIT_CAP, 0.001)
	var over := Augments.pole_exit(Vector3(0.0, 0.0, 70.0), Vector3.RIGHT, Augments.POLE_EXIT)
	_t.near("exit never slows a ball past the cap", over.length(), 70.0, 0.001)
	var radial := Augments.pole_exit(Vector3(10.0, 0.0, 0.0), Vector3.RIGHT, Augments.POLE_EXIT)
	_t.near("speed along the line gets no bonus", radial.length(), 10.0, 0.001)
