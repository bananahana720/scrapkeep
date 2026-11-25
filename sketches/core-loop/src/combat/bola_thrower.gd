extends "res://src/combat/counter.gd"

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
	warn_seconds = 0.6
	live_seconds = FLIGHT + WRAP
	rest_seconds = 3.2
	attack_range = 30.0
	keep_near = 14.0


const SPIN := 0.25
const WIND_SPIN := 0.35
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


func _warn_progress() -> float:
	return 0.0


func _go_live() -> void:
	_landed = false


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


func _pose() -> void:
	if _bola != null:
		var wind := clampf(_t / warn_seconds, 0.0, 1.0) if phase == Phase.WARN else 0.0
		_spin = fposmod(_spin + lerpf(SPIN, WIND_SPIN, wind), TAU)
		var seat := _flight_basis if _bola.top_level else _seat()
		_bola.basis = seat * Basis(Vector3.UP, _spin)

