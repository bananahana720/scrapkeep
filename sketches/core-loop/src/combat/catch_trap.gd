extends "res://src/combat/counter.gd"

# The catch-trap (DESIGN-V2 section 15.4): a crew figure setting a spring-jawed cup. It
# sets the cup where the ball will roll, and the warning is a small instant ring over
# it. Live, a grounded ball rolling onto the cup is cupped and held dead still: its
# speed is bled hard and it is pulled to the cup's centre. It is the one counter that
# stops you outright, so it is the easiest to read and the shortest: tenacity cuts it
# at 1.8 s and its own limit is HOLD. Boost or smash out; or ram or shoot the crew
# before the jaws close, since the cup dies with its crew.

const CUP_RADIUS := 2.6
const LEAD := 0.8
const HOLD := 1.4
const STOP := 14.0
const CENTRE := 10.0
const HP := 35.0

var cupped := 0
var _cup: MeshInstance3D

static var _warned_asset := false
static var _shared: Array = []


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.0
	warn_seconds = 1.0
	live_seconds = 2.0
	rest_seconds = 4.0
	attack_range = 24.0


func _build_tool() -> void:
	var parts := _parts()
	if parts.is_empty():
		_cup = MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.2
		mesh.bottom_radius = 0.7
		mesh.height = 0.8
		_cup.mesh = mesh
		_cup.material_override = Palette.solid(Palette.CHARCOAL.lightened(0.1), 0.0)
		_visual_parent().add_child(_cup)
		_cylinder(1.25, 0.1, Palette.HAZARD, Vector3(0.0, 0.42, 0.0), 0.7, _cup)
	else:
		_crew.free()
		_crew = null
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.flash >= 0:
				mi.set_surface_override_material(part.flash, _material)
			if part.name == "CatchCup":
				_cup = mi
			_visual_parent().add_child(mi)
	_cup.position = Vector3(0.0, CREW_HALF + 0.5, -0.3)


static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	if not ResourceLoader.exists("res://assets/models/world_one/enemy_catch_trap.glb"):
		return []
	var packed := load("res://assets/models/world_one/enemy_catch_trap.glb") as PackedScene
	if packed == null:
		return []
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
				push_warning("catch_trap: surface has no material; using default finish")
			if surface_material != null and surface_material.resource_name == "fleet_paint":
				flash = i
			mesh.surface_set_material(i, painted)
		_shared.append({"name": mi.name, "mesh": mesh, "xform": mi.transform, "flash": flash})
	scene.free()
	return _shared


func _commit(_to_ball: Vector3) -> Node3D:
	var aim: Vector3 = _ball() + target.planar_velocity() * LEAD
	var ring := _commit_ring(Threat.Type.INSTANT, aim, CUP_RADIUS, 2.2)
	_cup.top_level = true
	_cup.global_position = ring.center + Vector3.UP * 0.4
	return ring


func _live(_delta: float) -> bool:
	var ring := telegraph()
	if ring == null:
		return false
	var player = _player()
	var ball := _real_ball()
	if not _holding():
		if caught_live == 0 and ring.contains(ball) and player.state.grounded and _catch(HOLD):
			cupped += 1
		return true
	var to_centre: Vector3 = ring.center - ball
	to_centre.y = 0.0
	_pull(-player.planar_velocity() * STOP + to_centre * CENTRE)
	return true


func _on_broken(_method: String) -> void:
	if fleet != null:
		fleet.discover("cup_break", _real_ball())


func _on_end() -> void:
	if _cup != null:
		_cup.top_level = false
		_cup.position = Vector3(0.0, CREW_HALF + 0.5, -0.3)
