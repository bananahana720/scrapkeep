extends "res://src/combat/counter.gd"

# A reactor relic (DESIGN-V2 section 10, nuclear war): a squat cast dome with a
# cooling-tower waist and three thick vent stacks, dull petrol enamel with Cherenkov
# seams. It is slow and still, and its hazard is the ground. It opens a meltdown vent
# ahead of the ball: an instant ring that charges for CHARGE seconds while the Geiger
# tick speeds up (vent_charging carries the charge time, so presentation can pace the
# tick and the reactor pedal on it), then erupts. The eruption hurts and lifts a ball
# the ring contains, and leaves a fallout crater: the same ring, burning for CRATER
# seconds, that stings a ball each time it rolls in, without ever slowing it.

const VENT_RADIUS := 5.5
const LEAD := 1.0
const CHARGE := 2.4
const CRATER := 5.0
const ERUPT_DAMAGE := 14.0
const ERUPT_LIFT := 9.0
const BURN := 4.0
const HP := 140.0
const BODY_RADIUS := 1.6
const BODY_HALF := 1.2

var vents := 0
var eruptions_hit := 0
var burns := 0
var _inside := false
var _stacks: Array = []


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 10
	weight = 4.0
	walk_speed = 1.6
	keep_near = 14.0
	keep_far = 34.0
	attack_range = 30.0
	warn_seconds = CHARGE
	live_seconds = CRATER
	rest_seconds = 2.0
	first_rest = 2.5
	interruptible = false


func _build_crew() -> void:
	radius = BODY_RADIUS
	half_height = BODY_HALF
	_add_capsule(BODY_RADIUS, BODY_HALF * 2.0, Roster.ANCIENT_ENAMEL)
	var waist := CylinderMesh.new()
	waist.top_radius = BODY_RADIUS * 0.7
	waist.bottom_radius = BODY_RADIUS * 1.15
	waist.height = BODY_HALF * 1.2
	var skirt := MeshInstance3D.new()
	skirt.mesh = waist
	skirt.material_override = _enamel()
	skirt.position = Vector3(0.0, -BODY_HALF * 0.4, 0.0)
	_visual_parent().add_child(skirt)
	var dome := SphereMesh.new()
	dome.radius = BODY_RADIUS * 0.95
	dome.height = BODY_RADIUS * 1.2
	var cap := MeshInstance3D.new()
	cap.mesh = dome
	cap.material_override = _enamel()
	cap.position = Vector3(0.0, BODY_HALF * 0.5, 0.0)
	_visual_parent().add_child(cap)
	for i in 3:
		var angle := TAU * i / 3.0
		var at := Vector3(cos(angle) * BODY_RADIUS * 0.75, BODY_HALF + 0.4, sin(angle) * BODY_RADIUS * 0.75)
		var stack := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.28
		tube.bottom_radius = 0.34
		tube.height = 1.2
		stack.mesh = tube
		stack.material_override = _enamel()
		stack.position = at
		_visual_parent().add_child(stack)
		_stacks.append(stack)
		_seam(Vector3(0.62, 0.06, 0.62), at + Vector3.UP * 0.62)
	_seam(Vector3(BODY_RADIUS * 2.1, 0.07, 0.07), Vector3(0.0, 0.0, BODY_RADIUS * 0.02))


func _commit(_to_ball: Vector3) -> Node3D:
	var aim: Vector3 = _ball() + target.planar_velocity() * LEAD
	var ring := _commit_ring(Threat.Type.INSTANT, aim, VENT_RADIUS, 3.0)
	vents += 1
	if fleet != null:
		fleet.events().vent_charging.emit(ring.center, CHARGE)
	return ring


func _go_live() -> void:
	var ring := telegraph()
	if ring == null:
		return
	_inside = true
	if fleet != null:
		fleet.events().vent_erupted.emit(ring.center)
	if ring.contains(_real_ball()):
		eruptions_hit += 1
		hit_player.emit(ERUPT_DAMAGE, Vector3.UP * ERUPT_LIFT)


func _live(_delta: float) -> bool:
	var crater := telegraph()
	if crater == null:
		return false
	var inside: bool = crater.contains(_real_ball())
	if inside and not _inside:
		burns += 1
		hit_player.emit(BURN, Vector3.ZERO)
	_inside = inside
	return true


# A vent swells before it erupts: the stacks lengthen with the charge.
func _pose() -> void:
	var swell := clampf(_t / warn_seconds, 0.0, 1.0) if phase == Phase.WARN else 0.0
	for stack in _stacks:
		(stack as Node3D).scale = Vector3(1.0 + 0.2 * swell, 1.0 + 0.5 * swell, 1.0 + 0.2 * swell)
