extends Node

# The spillway gates swing (port note P6 of LANDMARK-CARDS.md card 1): this rig sits under park_dam's landmark node
# and swings the GLB's two radial gate leaves, gate_l and gate_r, each about its own trunnion, whenever the stage-1
# reactor's dam_face sheet runs (warden_reactor.gd sheet_live: a pulse opens it for SHEET_SECONDS, the next charge
# ends it at the latest). landmarks.py builds each leaf as its own drawn node with its origin on the hinge and the
# trunnion along local X, the skin plate hanging upstream (-Z) of it; turning the node by +angle about its X lifts the
# skin, so the lip rises off the sill and the water the sheet rides comes out under it. OPEN_RAD lifts the lip to the
# trunnion's height (the leaf's half arc, landmarks.py dam_gate th), about 6.7 m of opening on an 11.5 m leaf.
#
# The leaves open in OPEN_SECONDS and close in CLOSE_SECONDS, eased, so the opening reads on the pulse and the leaves
# settle back after. With no reactor (a calm stage, or after the Warden breaks) they rest shut. They are views only:
# the leaves have no collider (card 1 parts table), and the swing never touches the sheet, the posture or any fact,
# so the fight is the reactor driver's alone (tests/dam_gates_test.gd).

const LEAVES := ["gate_l", "gate_r"]
const OPEN_RAD := 0.62
const OPEN_SECONDS := 0.45
const CLOSE_SECONDS := 1.2
const MOUNTING := "dam_face"
# How often a rig with no reactor looks for one, in seconds.
const SEEK_EVERY := 0.5

const Augments := preload("res://src/movement/augments.gd")

var landmark: Node3D
# Each leaf's view and its rest transform in the landmark's space.
var leaves: Array[MeshInstance3D] = []
var rests: Array[Transform3D] = []
var warden: Node3D = null
# How far open, 0 shut to 1 at OPEN_RAD, before easing.
var openness := 0.0
var _seek_left := 0.0


# Hangs a rig under node (the dam landmark) when its GLB carries both leaves; null for a stand-in with none.
static func attach(node: Node3D) -> Node:
	var found: Array[MeshInstance3D] = []
	for leaf: String in LEAVES:
		var view := node.get_node_or_null(leaf)
		if not view is MeshInstance3D:
			return null
		found.append(view)
	var rig = load("res://src/world/park/dam_rig.gd").new()
	rig.name = "DamRig"
	rig.landmark = node
	rig.leaves = found
	for view in found:
		rig.rests.append(view.transform)
	node.add_child(rig)
	return rig


func _physics_process(delta: float) -> void:
	if not _has_reactor():
		_seek_left -= delta
		if _seek_left <= 0.0:
			_seek_left = SEEK_EVERY
			warden = find_reactor(get_tree(), landmark.global_position)
	pose(_driver(), delta)


# Moves the leaves toward open while the driver's sheet runs, else toward shut (none: shut), and sets their pose.
func pose(driver, delta: float) -> void:
	var open: bool = driver != null and driver.sheet_live()
	if open:
		openness = minf(1.0, openness + delta / OPEN_SECONDS)
	else:
		openness = maxf(0.0, openness - delta / CLOSE_SECONDS)
	var turn := Basis(Vector3.RIGHT, angle())
	for k in leaves.size():
		var posed := rests[k] * Transform3D(turn, Vector3.ZERO)
		if not posed.is_equal_approx(leaves[k].transform):
			leaves[k].transform = posed


# The leaves' turn about their trunnions now, in radians: 0 shut, OPEN_RAD open.
func angle() -> float:
	return OPEN_RAD * smoothstep(0.0, 1.0, openness)


func _has_reactor() -> bool:
	return warden != null and is_instance_valid(warden) and warden.is_inside_tree() \
		and not (warden.has_method("is_dead") and warden.is_dead())


func _driver():
	if not _has_reactor():
		return null
	var driver = warden.get("mount_driver")
	return driver if driver != null and driver.has_method("sheet_live") else null


# The stage-1 reactor at the dam: an anchor Warden mounted dam_face whose driver runs the sheet, nearest the landmark's
# column. null when there is none.
static func find_reactor(tree: SceneTree, at: Vector3) -> Node3D:
	if tree == null:
		return null
	var best: Node3D = null
	var best_d := INF
	for node in tree.get_nodes_in_group(Augments.ANCHOR_GROUP):
		if not node is Node3D or str(node.get("mounting")) != MOUNTING:
			continue
		var driver = node.get("mount_driver")
		if driver == null or not driver.has_method("sheet_live"):
			continue
		var p: Vector3 = (node as Node3D).global_position
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d < best_d:
			best_d = d
			best = node
	return best
