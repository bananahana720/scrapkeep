extends "res://src/combat/counter.gd"

# The bola thrower (DESIGN-V2 section 10): a crew figure with a bola spinning overhead.
# It throws at where the ball will be in FLIGHT seconds: a projectile reticle on the
# landing point under a dotted flight trace (W2's grammar, set_flight), and the bola
# flies that exact arc, slowly, so a read is always possible. If the landing ring holds
# the ball when the bola lands it wraps it: a sting of damage, then cords that bleed its
# speed and drag it down out of the air for up to WRAP seconds. A jump, a boost or a
# smash bursts the cords. As the director's punisher it lands on a ball another unit
# holds.

const FLIGHT := 1.3
const RING_RADIUS := 3.2
const RING_REACH := 5.0
const HEIGHT := 2.6
const WRAP := 1.3
const DRAG := 3.0
const DOWN := 16.0
const STING := 6.0
const HP := 40.0

var _bola: MeshInstance3D
var _launch := Vector3.ZERO
var _bump := 0.0
var _landed := false


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.0
	warn_seconds = 0.5
	live_seconds = FLIGHT + WRAP
	rest_seconds = 3.2
	attack_range = 30.0
	keep_near = 14.0


func _build_tool() -> void:
	_bola = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.7
	mesh.outer_radius = 0.9
	_bola.mesh = mesh
	_bola.material_override = Palette.solid(Palette.HAZARD, 0.6)
	_bola.position = Vector3(0.0, CREW_HALF + 1.1, 0.0)
	add_child(_bola)


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
		_bola.top_level = true
		_bola.global_position = Threat.flight_point(_launch, ring.center, _bump, _t / FLIGHT)
		ring.set_progress(_t / FLIGHT)
		return true
	if not _landed:
		_landed = true
		_bola.top_level = false
		_bola.position = Vector3(0.0, CREW_HALF + 1.1, 0.0)
		if not ring.contains(_real_ball()) or not _catch(WRAP):
			return false
		hit_player.emit(STING, Vector3.ZERO)
		return true
	if not _holding():
		return false
	var player = _player()
	var v: Vector3 = player.state.velocity
	_pull(Vector3(-v.x * DRAG, -DOWN if not player.state.grounded else 0.0, -v.z * DRAG))
	return true


func _on_end() -> void:
	if _bola != null:
		_bola.top_level = false
		_bola.position = Vector3(0.0, CREW_HALF + 1.1, 0.0)


func _pose() -> void:
	if _bola != null and not _bola.top_level:
		_bola.rotation.y += 0.25
