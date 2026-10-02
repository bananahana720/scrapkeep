extends "res://src/combat/counter.gd"

const Habits := preload("res://src/combat/habits.gd")
const Icons := preload("res://src/ui/icons.gd")

# One of the Mind's hands (DESIGN-V2 section 10, superintelligence; STORY-THREADS T5):
# a tall, thin, many-jointed arm on a cast foot, a lens cluster at the top that always
# follows the ball. Still, then exact. It reads the habit you use most this run (the
# fleet's habit counts, which reset every run) and answers it:
#
# - The quote is the telegraph. It commits its strike lane with its voice set to your
#   class motif played back inverted, one note flat (the mind_ cue for your class), and
#   its lens shows the trigger icon of the habit it read, in HAZARD. mind_adapted goes
#   out on the same frame. Nothing it does lands without that quote first.
# - The strike lands down the lane after WARN.
# - Then it braces for BRACE seconds against that one verb: hits of the braced kinds
#   meet BRACE_MULT times its plating (still chipping 20%), every other verb meets the
#   plating as usual, and its lens stays open as a weak point any hit breaks through.
#   Bounded twice over: the brace ends, and it costs the hand its lens.

const LANE_LENGTH := 18.0
const LANE_WIDTH := 2.6
const STRIKE_DAMAGE := 10.0
const STRIKE_SHOVE := 6.0
const WARN := 1.4
const BRACE := 5.0
const BRACE_MULT := 1.6
const PLATING_SCALE := 0.5
const HP := 90.0
const ARM_HEIGHT := 4.2
const LENS_RADIUS := 0.7

var habit := ""
var braced_kinds: Array = []
var adaptations := 0
var strikes_landed := 0
var _lens: Node3D
var _lens_glass: MeshInstance3D
var _icon: Sprite3D
var _joints: Array = []


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	plating = float(spec.get("plating", 20.0))
	scrap_value = 10
	weight = 2.5
	walk_speed = 2.2
	keep_near = 11.0
	keep_far = 24.0
	attack_range = 17.0
	warn_seconds = WARN
	live_seconds = BRACE
	rest_seconds = 3.0
	interruptible = false


func braced() -> bool:
	return phase == Phase.LIVE and habit != ""


func lens_point() -> Vector3:
	return _lens.global_position if _lens != null else global_position + Vector3.UP * ARM_HEIGHT


func plating_for(hit_kind: String, part: String) -> float:
	if part == "lens" and braced():
		return 0.0
	if braced() and hit_kind in braced_kinds:
		return plating * BRACE_MULT
	return plating


func weak_points() -> Array:
	if not braced():
		return []
	return [{"id": "lens", "at": lens_point(), "radius": LENS_RADIUS}]


func _wants_attack(to_ball: Vector3) -> bool:
	return to_ball.length() <= attack_range and fleet != null and fleet.habits.top() != ""


func _commit(to_ball: Vector3) -> Node3D:
	habit = fleet.habits.top()
	if habit == "":
		return null
	var brace: Dictionary = Habits.BRACES[habit]
	braced_kinds = brace["kinds"]
	_facing(to_ball)
	var lane := _commit_lane(Threat.Type.LANE, global_position, to_ball, LANE_LENGTH, LANE_WIDTH)
	adaptations += 1
	fleet.mind_adapt(habit, String(brace["icon"]), lens_point())
	_show_icon(String(brace["icon"]))
	return lane


func _go_live() -> void:
	var lane := telegraph()
	if lane != null and lane.contains(_real_ball()):
		strikes_landed += 1
		hit_player.emit(STRIKE_DAMAGE, lane.dir * STRIKE_SHOVE)
	if fleet != null:
		fleet.events().weak_point_opened.emit("lens", lens_point(), BRACE)


func _live(_delta: float) -> bool:
	return true


func _on_end() -> void:
	habit = ""
	braced_kinds = []
	if _icon != null:
		_icon.visible = false


func _show_icon(id: String) -> void:
	if _icon == null:
		return
	_icon.texture = Icons.texture(id)
	_icon.modulate = Palette.HAZARD
	_icon.visible = true


# The arm: a cast foot, three thin segments with joints, and the lens cluster on top.
func _build_crew() -> void:
	radius = 0.7
	half_height = 1.8
	_crew = _add_capsule(0.7, 3.6, Roster.ANCIENT_ENAMEL)
	var foot := CylinderMesh.new()
	foot.top_radius = 0.5
	foot.bottom_radius = 1.1
	foot.height = 0.5
	var base := MeshInstance3D.new()
	base.mesh = foot
	base.material_override = _enamel()
	base.position = Vector3(0.0, -1.55, 0.0)
	_visual_parent().add_child(base)
	var at := Vector3(0.0, -1.3, 0.0)
	for i in 3:
		var joint := Node3D.new()
		joint.position = at
		_visual_parent().add_child(joint)
		_joints.append(joint)
		var bone := MeshInstance3D.new()
		var rod := CylinderMesh.new()
		rod.top_radius = 0.14
		rod.bottom_radius = 0.18
		rod.height = 1.6
		bone.mesh = rod
		bone.material_override = _plate_material() if i == 1 else _enamel()
		bone.position = Vector3(0.0, 0.8, 0.0)
		joint.add_child(bone)
		if i == 1:
			_add_crack(bone, Vector3(0.0, 0.0, 0.2), 0.7)
		_seam(Vector3(0.4, 0.06, 0.4), Vector3.ZERO, joint)
		at += Vector3.UP * 1.6
	_lens = Node3D.new()
	_lens.position = Vector3(0.0, ARM_HEIGHT - 0.8, 0.0)
	add_child(_lens)
	var glass := SphereMesh.new()
	glass.radius = LENS_RADIUS
	glass.height = LENS_RADIUS * 2.0
	_lens_glass = MeshInstance3D.new()
	_lens_glass.mesh = glass
	_lens_glass.material_override = Palette.solid(Roster.ANCIENT_LIGHT, 1.2)
	_lens.add_child(_lens_glass)
	for side in [-1.0, 1.0]:
		var small := SphereMesh.new()
		small.radius = 0.25
		small.height = 0.5
		var eye := MeshInstance3D.new()
		eye.mesh = small
		eye.material_override = Palette.solid(Roster.ANCIENT_LIGHT, 0.8)
		eye.position = Vector3(side * 0.75, -0.2, 0.2)
		_lens.add_child(eye)
	_icon = Sprite3D.new()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.no_depth_test = true
	_icon.pixel_size = 0.02
	_icon.position = Vector3(0.0, 1.3, 0.0)
	_icon.visible = false
	_lens.add_child(_icon)


# Still, then exact: the lens always follows the ball; the brace opens it wide.
func _pose() -> void:
	if _lens == null or target == null:
		return
	var to := _ball() - _lens.global_position
	if to.length() > 0.5:
		_lens.global_basis = Basis.looking_at(to.normalized(), Vector3.UP if absf(to.normalized().y) < 0.95 else Vector3.FORWARD)
	var open := 1.5 if braced() else (1.0 + 0.3 * clampf(_t / warn_seconds, 0.0, 1.0) if phase == Phase.WARN else 1.0)
	_lens_glass.scale = Vector3.ONE * open
	(_lens_glass.material_override as StandardMaterial3D).emission_energy_multiplier = 3.0 if braced() else 1.2
	if phase == Phase.WARN and not _joints.is_empty():
		(_joints[1] as Node3D).rotation.x = -0.5 * clampf(_t / warn_seconds, 0.0, 1.0)
	elif not _joints.is_empty():
		(_joints[1] as Node3D).rotation.x = 0.0
