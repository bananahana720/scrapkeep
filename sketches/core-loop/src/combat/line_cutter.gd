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
var _body: MeshInstance3D
var _throw_arm: MeshInstance3D
static var _warned_asset := false
static var _shared: Array = []


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
	var parts := _parts()
	if not parts.is_empty():
		_crew.free()
		_crew = null
		_base_color = Color.WHITE
		_material.albedo_color = _base_color
		_material.vertex_color_use_as_albedo = true
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.flash >= 0:
				mi.set_surface_override_material(part.flash, _material)
			_visual_parent().add_child(mi)
			match part.name:
				"CutterCrewBody": _body = mi
				"ThrowArm": _throw_arm = mi
				"CutterDisc": _disc = mi
		return
	_disc = _cylinder(0.7, 0.08, Palette.HAZARD, Vector3(0.0, CREW_HALF + 1.0, 0.0), 0.6, _visual_parent())


static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var path := "res://assets/models/world_three/enemy_line_cutter.glb"
	if not ResourceLoader.exists(path):
		return _shared
	var packed := load(path) as PackedScene
	if packed == null:
		return _shared
	var scene := packed.instantiate()
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate()
		var flash := -1
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("line_cutter: surface has no material; using default finish")
			if surface_material != null and surface_material.resource_name == "fleet_paint":
				flash = i
			mesh.surface_set_material(i, painted)
		_shared.append({"name": mi.name, "mesh": mesh, "xform": mi.transform, "flash": flash})
	scene.free()
	return _shared


func _pose() -> void:
	if _body == null or _throw_arm == null:
		return
	var cock := clampf(_t / warn_seconds, 0.0, 1.0) if phase == Phase.WARN else 0.0
	_body.rotation.x = 0.08 * cock
	_throw_arm.position = _body.basis * Vector3(-0.48, 0.7, 0.0)
	_throw_arm.rotation.x = -0.52 * cock
	if phase == Phase.WARN and not _disc.top_level:
		_disc.position = _throw_arm.transform * Vector3(0.48, 1.4, 0.0)


func _wants_attack(to_ball: Vector3) -> bool:
	var player = _player()
	return super(to_ball) and player != null and (player.kit.hooked or not player.state.on_floor())


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
		if fleet != null:
			fleet.discover("line_cut", _real_ball())
	return false


func _on_end() -> void:
	_rest_disc()


func _rest_disc() -> void:
	if _disc != null:
		_disc.top_level = false
		_disc.position = Vector3(0.0, CREW_HALF + 1.0, 0.0)
		_disc.basis = Basis.IDENTITY
