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


func _build_tool() -> void:
	_plate = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 1.9, 0.5)
	_plate.mesh = box
	_plate.material_override = _plate_material()
	_plate.position = Vector3(0.0, 0.1, CREW_RADIUS + 0.3)
	add_child(_plate)
	_add_crack(_plate, Vector3(0.0, 0.0, 0.27), 1.1)
	for side in [-1.0, 1.0]:
		var pad := MeshInstance3D.new()
		var pad_box := BoxMesh.new()
		pad_box.size = Vector3(0.7, 0.5, 1.4)
		pad.mesh = pad_box
		pad.material_override = _plate_material()
		pad.position = Vector3(side * (CREW_RADIUS + 0.35), CREW_HALF * 0.6, 0.0)
		add_child(pad)


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
