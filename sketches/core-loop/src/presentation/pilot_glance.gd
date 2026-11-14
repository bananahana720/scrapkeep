extends SkeletonModifier3D

# The pilot glances back over a shoulder at the camera. Under the cutaway ball look the window
# shows the pilot's back from the chase camera, so when the ball has sat still for a moment the
# pilot turns chest, neck and head toward the player, holds the look, and turns back; it repeats
# while the ball stays still and stops the moment the ball moves or a reaction clip plays. The
# turn is laid over whatever clip the AnimationPlayer plays and leaves the clip untouched.
#
# hero_assets seats one on the pilot's skeleton and calls observe() every frame.

# The share of the turn each bone takes, chest to head; the pilots share one rig.
const SHARES := {"spine_02": 0.2, "neck": 0.3, "head": 0.5}
const REACH := deg_to_rad(120.0)
const FIRST_AFTER := 3.0
const EVERY := 7.0
const HOLD := 1.2
const TURN_RATE := 5.0
const RETURN_RATE := 9.0

# The turn now, -1 to 1 of REACH; a tool sets it for a still, observe() drives it in play.
var turn := 0.0

var _still := false
var _side := 0.0
var _wait := FIRST_AFTER
var _held := 0.0


# Adds a glance to the pilot's skeleton; null when the pilot has none.
static func seat(pilot: Node) -> SkeletonModifier3D:
	var found := pilot.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return null
	var glance: SkeletonModifier3D = (load("res://src/presentation/pilot_glance.gd") as GDScript).new()
	glance.name = "PilotGlance"
	found[0].add_child(glance)
	return glance


# still: the ball is at rest and no reaction clip plays. eye: the camera, in world space.
func observe(still: bool, eye: Vector3, delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if not still:
		_wait = FIRST_AFTER
		_held = 0.0
		_side = 0.0
	elif _side == 0.0:
		_wait -= delta
		if _wait <= 0.0:
			# Over the shoulder on the camera's side; a camera in front needs no glance.
			var at := skeleton.global_transform.affine_inverse() * eye
			_side = signf(at.x) if at.z > 0.0 and absf(at.x) > 0.01 else (1.0 if at.z > 0.0 else 0.0)
			_wait = EVERY
			_held = 0.0
	else:
		_held += delta
		if _held >= HOLD:
			_side = 0.0
	var rate := TURN_RATE if _side != 0.0 else RETURN_RATE
	turn = lerpf(turn, _side, 1.0 - exp(-rate * delta))
	if absf(turn) < 0.001 and _side == 0.0:
		turn = 0.0


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or turn == 0.0:
		return
	# Each bone turns about the pilot's upright, whatever way the rig's own bone axes lie.
	for bone_name in SHARES:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		var parent := skeleton.get_bone_parent(bone)
		var upright := Vector3.UP
		if parent >= 0:
			upright = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion().inverse() * Vector3.UP
		var twist := Quaternion(upright.normalized(), -turn * REACH * float(SHARES[bone_name]))
		skeleton.set_bone_pose_rotation(bone, twist * skeleton.get_bone_pose_rotation(bone))
