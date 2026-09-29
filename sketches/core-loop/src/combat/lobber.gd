extends "res://src/combat/enemy.gd"

# The lobber stands and shells. Its job is to make a predictable line expensive: its
# muzzle glows for TELEGRAPH seconds, then it commits a landing ring where you will
# be if you hold your line, and the shell lands there FLIGHT seconds later. Only that
# ring hurts (projectile.gd), so a change of line or a jump beats it at any speed.

const CYCLE := 3.6
const TELEGRAPH := 1.3
const FLIGHT := 1.9
const SHOT_RANGE := 75.0
const LEAD := 0.5
const HP := 26.0
const SCRAP := 4

signal fired(origin: Vector3, landing: Vector3, flight: float)

var shots := 0

var _clock := 0.0
var _muzzle: MeshInstance3D
var _muzzle_material: StandardMaterial3D


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = "lobber"
	_set_health(HP * threat)
	scrap_value = SCRAP
	weight = 3.0
	radius = 1.3
	half_height = 2.0

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 4.0, 2.4)
	shape.shape = box
	add_child(shape)
	_base_color = Palette.VERDIGRIS
	_material = Palette.solid(_base_color)
	# The C11 mortar cart (enemy_lobber.glb): a braced tower on wheels under a loading bulb and a
	# stout leaning tube. LobberBody carries the flashing body material as its paint surface; the
	# bulb is the muzzle, and _show_charge swells and lights it exactly as before.
	_muzzle_material = Palette.solid(Palette.HAZARD, 0.2)
	var dressing := Node3D.new()
	dressing.name = "LobberBody"
	add_child(dressing)
	for part in _parts():
		var mi := MeshInstance3D.new()
		mi.mesh = part.mesh
		mi.transform = part.xform
		if part.bulb:
			mi.name = "LobberBulb"
			mi.set_surface_override_material(0, _muzzle_material)
			add_child(mi)
			_muzzle = mi
		else:
			mi.set_surface_override_material(part.body, _material)
			dressing.add_child(mi)


static var _shared: Array = []


# The glb is read once; every lobber shares its meshes and carries only its own flashing
# body and muzzle materials as surface overrides.
static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var scene := (load("res://assets/models/world_one/enemy_lobber.glb") as PackedScene).instantiate()
	var charcoal := Palette.solid(Palette.CHARCOAL)
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate()
		var body := 0
		for i in mesh.get_surface_count():
			var slot := mesh.surface_get_material(i).resource_name
			if slot == "fleet_paint":
				body = i
			mesh.surface_set_material(i, charcoal)
		_shared.append({"mesh": mesh, "xform": mi.transform, "body": body, "bulb": mi.name.begins_with("LobberBulb")})
	scene.free()
	return _shared


func muzzle_point() -> Vector3:
	return global_position + Vector3.UP * 2.6


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	_move(delta, Vector3.ZERO)
	if not _in_play() or target == null or not is_on_floor():
		return
	var to_ball: Vector3 = _ball() - global_position
	if to_ball.length() > SHOT_RANGE:
		_clock = 0.0
		_show_charge(0.0)
		return
	_clock += delta
	_show_charge(clampf((_clock - (CYCLE - TELEGRAPH)) / TELEGRAPH, 0.0, 1.0))
	if _clock < CYCLE:
		return
	_clock = 0.0
	_show_charge(0.0)
	var lead: Vector3 = target.planar_velocity() * FLIGHT * LEAD
	var aim: Vector3 = _ball() + lead
	var landing := Vector3(aim.x, Telegraph.ground_under(terrain, aim), aim.z)
	shots += 1
	fired.emit(muzzle_point(), landing, FLIGHT)


func _show_charge(charge: float) -> void:
	_muzzle_material.emission_energy_multiplier = 0.8 + charge * 5.0
	_muzzle.scale = Vector3.ONE * (1.0 + charge * 0.9)
