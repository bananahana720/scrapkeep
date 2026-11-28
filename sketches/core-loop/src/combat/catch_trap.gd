extends "res://src/combat/counter.gd"

const CUP_RADIUS := 2.6
const LEAD := 0.8
const HOLD := 1.4
const STOP := 14.0
const CENTRE := 10.0
const HP := 35.0

var cupped := 0
var _cup: MeshInstance3D

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
		_cup.material_override = PaletteMaterials.solid(Palette.CHARCOAL.lightened(0.1), 0.0)
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
	if _shared.is_empty():
		_shared = EnemyCasting.parts("res://assets/models/world_one/enemy_catch_trap.glb", "catch_trap")
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
