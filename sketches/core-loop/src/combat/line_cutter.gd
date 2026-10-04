extends "res://src/combat/counter.gd"

# The line cutter (World 3, roster_highdraft.gd): a crew figure that throws a spinning
# cutter at where the ball will be. The reticle waits through the wind-up and closes over the
# flight; the disc flies the committed arc. If the ball is inside the landing ring when the
# disc lands and is on a harpoon line, the line is cut: it goes through the ball's own
# cut_line and nothing else of the harpoon is touched. A glide under the arc, or a ball that
# landed early, dodges it. A hard hit in the wind-up breaks the throw (counter.gd).

const FLIGHT := 1.1
const RING_RADIUS := 2.6
const RING_REACH := 6.0
const HEIGHT := 2.2
const STING := 4.0
const HP := 38.0
const SPIN_RATE := 0.9

var throws := 0
var cuts := 0
var dodged := 0

var _disc: MeshInstance3D
var _launch := Vector3.ZERO
var _bump := 0.0
var _landed := false


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.0
	warn_seconds = 0.6
	live_seconds = FLIGHT + 0.2
	rest_seconds = 3.0
	attack_range = 28.0
	keep_near = 12.0


func _build_tool() -> void:
	_disc = _cylinder(0.7, 0.08, Palette.HAZARD, Vector3(0.0, CREW_HALF + 1.0, 0.0), 0.6, _visual_parent())


func _wants_attack(to_ball: Vector3) -> bool:
	var player = _player()
	return super(to_ball) and player != null and (player.kit.hooked or not player.state.grounded)


func _commit(_to_ball: Vector3) -> Node3D:
	var landing: Vector3 = _ball() + target.planar_velocity() * (FLIGHT + warn_seconds)
	_facing(landing - global_position)
	var ring := _commit_ring(Threat.Type.PROJECTILE, landing, RING_RADIUS, RING_REACH)
	_launch = global_position + Vector3.UP * HEIGHT
	_bump = Threat.lob_bump(GRAVITY, FLIGHT)
	ring.set_flight(_launch, _bump)
	return ring


# The reticle stays open through the wind-up and closes over the flight.
func _warn_progress() -> float:
	return 0.0


func _go_live() -> void:
	_landed = false


func _live(_delta: float) -> bool:
	var ring := telegraph()
	if ring == null:
		return false
	if _t < FLIGHT:
		_disc.top_level = true
		_disc.global_position = Threat.flight_point(_launch, ring.center, _bump, _t / FLIGHT)
		_disc.rotate_y(SPIN_RATE)
		ring.set_progress(_t / FLIGHT)
		return true
	if _landed:
		return false
	_landed = true
	_rest_disc()
	throws += 1
	var player = _player()
	if player == null or not ring.contains(_real_ball()):
		return false
	if player.kit.hooked and not player.kit.gliding:
		player.cut_line("line_cutter")
		cuts += 1
		hit_player.emit(STING, Vector3.ZERO)
	else:
		dodged += 1
	return false


func _on_end() -> void:
	_rest_disc()


func _rest_disc() -> void:
	if _disc != null:
		_disc.top_level = false
		_disc.position = Vector3(0.0, CREW_HALF + 1.0, 0.0)
		_disc.basis = Basis.IDENTITY
