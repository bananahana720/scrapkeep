extends Node


const Augments := preload("res://src/movement/augments.gd")

const TETHER := "tether"
const TETHER_LENGTH := 13.0
const TETHER_GIRTH := 2.0
const GRIP := Vector3(0.0, 3.0, 0.0)
const TIP_LOCAL := Vector3(0.0, -118.0, 0.0)
const MOUNTING := "under_island"
const SEEK_EVERY := 0.5


class IsleTip:
	extends AnimatableBody3D
	var _bite := Vector3.ZERO
	var _velocity := Vector3.ZERO
	var _was := Transform3D.IDENTITY

	func anchor_point(point: Vector3, from = null) -> Vector3:
		if from is Vector3:
			_bite = global_transform.affine_inverse() * point
		return global_transform * _bite

	func anchor_velocity() -> Vector3:
		return _velocity

	func staggered() -> bool:
		return false

	func track(delta: float) -> void:
		var now := global_transform
		_velocity = (now * _bite - _was * _bite) / delta if delta > 0.0 else Vector3.ZERO
		_was = now


var landmark: Node3D
var tip: IsleTip
var tether: MeshInstance3D
var rest := Transform3D.IDENTITY
var warden: Node3D = null
var tilt_deg := 0.0
var sink := 0.0
var _seek_left := 0.0


static func attach(node: Node3D, tip_shape: CollisionShape3D = null) -> Node:
	var rig = load("res://src/world/park/isle_rig.gd").new()
	rig.name = "IsleRig"
	rig.landmark = node
	rig.rest = node.transform
	if tip_shape != null:
		var body := IsleTip.new()
		body.name = "IsleTip"
		body.collision_layer = Augments.WORLD_MASK
		body.collision_mask = 0
		body.top_level = true
		body.sync_to_physics = false
		body.add_to_group(Augments.ANCHOR_GROUP)
		body.add_to_group(Augments.WORLD_ANCHOR_GROUP)
		body.add_child(tip_shape)
		node.add_child(body)
		rig.tip = body
	var found := node.find_child(TETHER, true, false)
	if found is MeshInstance3D:
		rig.tether = found
	node.add_child(rig)
	rig.process_physics_priority = 100
	return rig


func _ready() -> void:
	if tip != null:
		tip.global_transform = landmark.global_transform
		tip._was = tip.global_transform
	_aim_tether()


func _physics_process(delta: float) -> void:
	if not _has_hand():
		_seek_left -= delta
		if _seek_left <= 0.0:
			_seek_left = SEEK_EVERY
			warden = find_hand(get_tree(), landmark.global_position)
	pose(_driver())
	if tip != null:
		tip.track(delta)


func pose(driver) -> void:
	tilt_deg = float(driver.island_tilt_deg) if driver != null else 0.0
	sink = float(driver.island_sink) if driver != null else 0.0
	var away: Vector3 = driver.tilt_away if driver != null else Vector3.ZERO
	var basis := rest.basis
	var axis := away.cross(Vector3.UP)
	if absf(tilt_deg) > 0.0 and axis.length() > 0.001:
		basis = Basis(axis.normalized(), deg_to_rad(tilt_deg)) * basis
	var posed := Transform3D(basis, rest.origin + Vector3.DOWN * sink)
	if not posed.is_equal_approx(landmark.transform):
		landmark.transform = posed
	if tip != null and not tip.global_transform.is_equal_approx(landmark.global_transform):
		tip.global_transform = landmark.global_transform
	_aim_tether()


func tip_point() -> Vector3:
	return landmark.global_transform * TIP_LOCAL


func grip_point() -> Vector3:
	if _has_hand():
		return warden.global_position + GRIP
	return landmark.global_transform * (TIP_LOCAL + Vector3.DOWN * TETHER_LENGTH)


func _aim_tether() -> void:
	if tether == null or not is_instance_valid(landmark) or not landmark.is_inside_tree():
		return
	var top := tip_point()
	var span := top - grip_point()
	if span.length() < 0.01:
		return
	var y := span / TETHER_LENGTH
	var side := y.cross(Vector3.FORWARD if absf(y.normalized().dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var front := side.cross(y.normalized()).normalized()
	tether.global_transform = Transform3D(Basis(side * TETHER_GIRTH, y, front * TETHER_GIRTH), top)


func _has_hand() -> bool:
	return warden != null and is_instance_valid(warden) and warden.is_inside_tree() \
		and not (warden.has_method("is_dead") and warden.is_dead())


func _driver():
	if not _has_hand():
		return null
	var driver = warden.get("mount_driver")
	return driver if driver != null and "island_tilt_deg" in driver else null


static func find_hand(tree: SceneTree, pivot: Vector3) -> Node3D:
	if tree == null:
		return null
	var best: Node3D = null
	var best_d := INF
	for node in tree.get_nodes_in_group(Augments.ANCHOR_GROUP):
		if not node is Node3D or str(node.get("mounting")) != MOUNTING:
			continue
		var driver = node.get("mount_driver")
		if driver == null or not "island_tilt_deg" in driver:
			continue
		var at: Vector3 = (node as Node3D).global_position
		var d := Vector2(at.x - pivot.x, at.z - pivot.z).length()
		if d < best_d:
			best_d = d
			best = node
	return best
