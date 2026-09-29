extends "res://src/combat/counter.gd"

# The plated brute (DESIGN-V2 section 10): a mini-Warden, bolted plate layers visibly
# one layer more than any other crew. It keeps the Warden's plating grammar (a punch
# below its plating chips 20%, the class-colour rim and open crack say "breaks now")
# with one extra rule: its outer plate takes the first breaking hit whole and pops off,
# so the body takes only the second. It walks you down and slams the ground around
# itself: an instant ring that knocks you out of it. It holds nothing; as the
# director's punisher it lands on a ball a controller is holding.

const PLATING_SCALE := 0.6
const SLAM_RADIUS := 6.0
const SLAM_RANGE := 6.5
const SLAM_DAMAGE := 12.0
const SLAM_SHOVE := 9.0
const HP := 110.0

var plates := 1
var plates_popped := 0
var slams := 0
var _absorb := false
var _plate: MeshInstance3D


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	plating = float(spec.get("plating", 24.0))
	scrap_value = 8
	weight = 3.0
	walk_speed = 3.2
	keep_near = 3.0
	keep_far = 30.0
	attack_range = SLAM_RANGE
	warn_seconds = 1.1
	live_seconds = 0.15
	rest_seconds = 2.8
	interruptible = false


# C15 dressing (enemy_plated_brute.glb). The counter's capsule crew is replaced by the glb's
# body (the collider _add_capsule laid stays) and the plate slab and pads by one plate group
# (front slab, shoulder and rear cladding) that shows exactly while plates > 0. The glb is read
# once; every brute shares its meshes and adds only its own flashing body material as a surface
# override and its own tinted plate material.
static var _shared: Dictionary = {}


func _build_tool() -> void:
	_crew.free()
	var parts := _parts()
	_crew = MeshInstance3D.new()
	_crew.name = "BruteBody"
	_crew.mesh = parts["body"]
	_crew.set_surface_override_material(parts["flash"], _material)
	add_child(_crew)
	_plate = MeshInstance3D.new()
	_plate.name = "BrutePlates"
	_plate.mesh = parts["plates"]
	_plate.material_override = _plate_material()
	add_child(_plate)
	_add_crack(_plate, Vector3(0.0, 0.1, CREW_RADIUS + 0.3 + 0.28), 1.1).name = "PlateCrack"


static func _parts() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	var scene := (load("res://assets/models/world_one/enemy_plated_brute.glb") as PackedScene).instantiate()
	var charcoal := Palette.solid(Palette.CHARCOAL)
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	var flash := -1
	var meshes := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh.duplicate()
		for i in mesh.get_surface_count():
			var slot := mesh.surface_get_material(i).resource_name
			if slot == "fleet_paint":
				flash = i
			mesh.surface_set_material(i, painted if slot == "paint" else charcoal)
		meshes[node.name] = mesh
	if flash < 0:
		push_error("enemy_plated_brute.glb has no fleet_paint surface; the flash lands on surface 0")
		flash = 0
	_shared = {"body": meshes["BruteBody"], "plates": meshes["BrutePlates"], "flash": flash}
	scene.free()
	return _shared


func _wants_attack(to_ball: Vector3) -> bool:
	return to_ball.length() <= attack_range and is_on_floor()


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	return _commit_ring(Threat.Type.INSTANT, global_position, SLAM_RADIUS, 2.2)


func _go_live() -> void:
	slams += 1
	var ring := telegraph()
	var ball := _real_ball()
	if ring == null or not ring.contains(ball):
		return
	var out := ball - global_position
	out.y = 0.0
	var dir := out.normalized() if out.length() > 0.1 else Vector3.FORWARD
	hit_player.emit(SLAM_DAMAGE, dir * SLAM_SHOVE + Vector3.UP * 3.0)


func on_struck(_kind: String, _part: String, result: Dictionary) -> void:
	if result.get("full", false) and plates > 0:
		plates -= 1
		plates_popped += 1
		_absorb = true
		if _plate != null:
			_plate.visible = false


# The popped plate took that hit whole: the body is untouched this once.
func take_damage(amount: float) -> float:
	if _absorb:
		_absorb = false
		flash()
		return 0.0
	return super.take_damage(amount)


func _pose() -> void:
	if _crew == null:
		return
	if phase == Phase.WARN:
		_crew.scale = Vector3.ONE * (1.0 + 0.1 * clampf(_t / warn_seconds, 0.0, 1.0))
	else:
		_crew.scale = Vector3.ONE
