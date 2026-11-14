extends "res://src/combat/counter.gd"

# The netcaster (DESIGN-V2 section 10): two masts with a crackling net strung between.
# It raises an electric field over where the ball is heading: an instant ring whose
# height band is tall, because only the air is its business. Live, a ball inside the
# field and airborne (at least NET_FLOOR above the ground, not touching it) is netted
# and held hanging: its fall and its drift are cancelled while the net holds. A grounded
# ball rolls under it, so a net can be baited: stay low until it drops. A double jump, a
# glide or a smash tears it.

const FIELD_RADIUS := 5.5
const FIELD_TOP := 10.0
const NET_FLOOR := 1.2
const LEAD := 0.6
const HANG := 5.0
const MAX_HOLD := 1.6
const HP := 45.0
const MAST_HEIGHT := 3.6

var _net: MeshInstance3D


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.1
	warn_seconds = 1.2
	live_seconds = 2.6
	rest_seconds = 3.5
	attack_range = 24.0


# C16 dressing (enemy_netcaster.glb). The counter's capsule crew and the two cylinder masts are
# replaced by the glb's crew, masts, crossbar, sill and stays (the collider _add_capsule laid
# stays). The net stays the runtime hazard box below, untouched: the glb frames its 2.4 x 1.6 m
# window and adds no geometry inside it. The glb is read once; every netcaster shares its mesh
# and adds only its own flashing body material as a surface override. The resting body is the
# Fleet oxide _add_capsule already set (RUST), so the hit flash and the event colour are unchanged.
static var _warned_asset := false
static var _shared: Dictionary = {}


func _build_tool() -> void:
	_crew.free()
	_crew = null
	var parts := _parts()
	var dress := Node3D.new()
	dress.name = "NetcasterBody"
	_visual_parent().add_child(dress)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = parts["body"]
	body.set_surface_override_material(parts["flash"], _material)
	dress.add_child(body)
	_net = _box(Vector3(2.4, 1.6, 0.04), Palette.HAZARD, Vector3(0.0, MAST_HEIGHT - CREW_HALF - 0.9, -0.3), 0.9)
	_net.name = "NetcasterNet"


static func _parts() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	var scene := (load("res://assets/models/world_one/enemy_netcaster.glb") as PackedScene).instantiate()
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	var flash := 0
	var mesh: Mesh = (scene.find_child("NetcasterBody", true, false) as MeshInstance3D).mesh.duplicate()
	for i in mesh.get_surface_count():
		var surface_material := mesh.surface_get_material(i)
		if surface_material == null and not _warned_asset:
			_warned_asset = true
			push_warning("netcaster: surface has no material; using default finish")
		if surface_material != null and surface_material.resource_name == "fleet_paint":
			flash = i
		mesh.surface_set_material(i, painted)
	_shared = {"body": mesh, "flash": flash}
	scene.free()
	return _shared


func _commit(_to_ball: Vector3) -> Node3D:
	var aim: Vector3 = _ball() + target.planar_velocity() * LEAD
	_facing(aim - global_position)
	var ring := _commit_ring(Threat.Type.INSTANT, aim, FIELD_RADIUS, FIELD_TOP)
	ring.air_only = true
	return ring


func _live(_delta: float) -> bool:
	var field := telegraph()
	if field == null:
		return false
	var player = _player()
	var ball := _real_ball()
	var above: float = ball.y - Telegraph.ground_under(terrain, ball)
	var airborne: bool = not player.state.on_floor() and above >= NET_FLOOR
	if not field.contains(ball) or (not _holding() and not airborne):
		if _holding():
			_release("left")
		return true
	if not _holding() and (caught_live > 0 or not _catch(MAX_HOLD)):
		return true
	var v: Vector3 = player.state.velocity
	var gravity: float = player.tuning.f("gravity")
	_pull(Vector3(-v.x * HANG, gravity - v.y * HANG, -v.z * HANG))
	return true


func _pose() -> void:
	if _net != null:
		_net.visible = phase != Phase.LIVE
