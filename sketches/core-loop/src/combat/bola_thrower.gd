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
var _spin := 0.0
var _flight_basis := Basis.IDENTITY


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.0
	# At TELL_FLOOR (challenge_dials.gd): the whirl is the throw's tell.
	warn_seconds = 0.6
	live_seconds = FLIGHT + WRAP
	rest_seconds = 3.2
	attack_range = 30.0
	keep_near = 14.0


# C13 dressing (enemy_bola_thrower.glb). The counter's capsule crew is replaced by the glb's
# crew and raised arm (the collider _add_capsule laid stays) and the bola is the glb's tilted
# hoop with a weighted end each side. The glb is read once; every thrower shares its meshes and
# adds only its own flashing body material as a surface override (the hoop's hazard material
# is one shared resource, as the base gave every bola the same look).
const SPIN := 0.25
const WIND_SPIN := 0.35
# The hoop's ring axis (the glb's local +Y) is seated 58 degrees off vertical toward a diagonal, so
# front, side and rear cameras each look at the opening at about 0.6 of full face-on. The whirl is
# about the ring's own axis, so the opening never rolls edge-on.
const SEAT_AXIS := Vector3(0.6, 0.53, 0.6)

static var _warned_asset := false
static var _shared: Dictionary = {}


func _build_tool() -> void:
	_crew.free()
	_crew = null
	var parts := _parts()
	var body := MeshInstance3D.new()
	body.name = "BolaThrowerBody"
	body.mesh = parts["body"]
	body.set_surface_override_material(parts["flash"], _material)
	_visual_parent().add_child(body)
	_bola = MeshInstance3D.new()
	_bola.name = "BolaLoop"
	_bola.mesh = parts["loop"]
	_bola.position = Vector3(0.0, CREW_HALF + 1.1, 0.0)
	_bola.basis = _seat()
	_visual_parent().add_child(_bola)


static func _seat() -> Basis:
	return Basis(Quaternion(Vector3.UP, SEAT_AXIS.normalized()))


static func _parts() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	var scene := (load("res://assets/models/world_one/enemy_bola_thrower.glb") as PackedScene).instantiate()
	var charcoal := Palette.solid(Palette.CHARCOAL)
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	var hazard := Palette.solid(Palette.HAZARD, 0.6)
	var flash := 0
	var meshes := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh.duplicate()
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("bola_thrower: surface has no material; using default finish")
			var slot := surface_material.resource_name if surface_material != null else ""
			if slot == "fleet_paint":
				flash = i
			mesh.surface_set_material(i, hazard if slot == "class_accent" else (painted if slot == "paint" else charcoal))
		meshes[node.name] = mesh
	_shared = {"body": meshes["BolaThrowerBody"], "loop": meshes["BolaLoop"], "flash": flash}
	scene.free()
	return _shared


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


# The loop leaves the crew keeping the seat it had, so it reads open in flight too.
func _take_flight() -> void:
	_flight_basis = global_basis * _seat()
	_bola.top_level = true


func _live(_delta: float) -> bool:
	var ring := telegraph()
	if ring == null:
		return false
	if _t < FLIGHT:
		if not _bola.top_level:
			_take_flight()
		_bola.global_position = Threat.flight_point(_launch, ring.center, _bump, _t / FLIGHT)
		ring.set_progress(_t / FLIGHT)
		return true
	if not _landed:
		_landed = true
		# The flight never takes the ring to its end, so the landing is drawn as the bola arrives.
		ring.land()
		_bola.top_level = false
		_bola.position = Vector3(0.0, CREW_HALF + 1.1, 0.0)
		_bola.basis = _seat() * Basis(Vector3.UP, _spin)
		if not ring.contains(_real_ball()) or not _catch(WRAP):
			return false
		hit_player.emit(STING, Vector3.ZERO)
		return true
	if not _holding():
		return false
	var player = _player()
	var v: Vector3 = player.state.velocity
	_pull(Vector3(-v.x * DRAG, -DOWN if not player.state.on_floor() else 0.0, -v.z * DRAG))
	return true


func _on_end() -> void:
	if _bola != null:
		_bola.top_level = false
		_bola.position = Vector3(0.0, CREW_HALF + 1.1, 0.0)
		_bola.basis = _seat() * Basis(Vector3.UP, _spin)


# The loop whirls faster through the wind-up, easing with the warning's own progress
# (WARN phase, _t / warn_seconds); it reads that clock and adds none. The whirl is about the
# ring's own axis, in flight as well, so the opening stays open on every camera.
func _pose() -> void:
	if _bola != null:
		var wind := clampf(_t / warn_seconds, 0.0, 1.0) if phase == Phase.WARN else 0.0
		_spin = fposmod(_spin + lerpf(SPIN, WIND_SPIN, wind), TAU)
		var seat := _flight_basis if _bola.top_level else _seat()
		_bola.basis = seat * Basis(Vector3.UP, _spin)

