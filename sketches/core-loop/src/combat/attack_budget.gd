extends RefCounted

const START := 6
const PER_HEFT_CLASS := 1
const PER_WORLD := 2
const LATE := 12
const MIN_GAP := 0.2
const ATTACKING := "attack_budget"
const WAITING := "attack_budget_wait"
const OFF_META := "attack_budget_off"
const LAST_META := "attack_budget_last"
const VOLLEY_META := "attack_budget_volley"
const ANCHOR_GROUP := "harpoon_anchor"
const HIVE_FAMILY := "swarm"
const DEFEND_RADIUS := 40.0
const PACK_META := "pack_seq"
const CLOCKED_OUT_META := "clocked_out_until"
const ALLY_ATTACKING := "ally_attack_budget"
const ALLY_WAITING := "ally_attack_budget_wait"
const ALLY_LAST_META := "ally_attack_budget_last"
const ALLY_START := 2
const ALLY_LATE := 3
const ALLY_MIN_GAP := 0.25


static func cap_at(heft_class: int, world: int) -> int:
	return mini(LATE, START + PER_HEFT_CLASS * maxi(0, heft_class - 1) + PER_WORLD * maxi(0, world - 1))


static func cap_for(unit: Node) -> int:
	var root = unit.get("world_root")
	if root == null or not is_instance_valid(root):
		return START
	var world_node = root.get_node_or_null("World")
	var director = world_node.get("director") if world_node != null else null
	if director == null:
		return START
	return cap_at(int(director.heft_class), int(director.world))


static func attackers(tree: SceneTree) -> int:
	return tree.get_nodes_in_group(ATTACKING).size()


static func ask(unit: Node) -> bool:
	if unit.is_in_group(ATTACKING):
		return true
	if clocked_out(unit):
		withdraw(unit)
		return false
	if not unit.is_inside_tree() or _off(unit):
		return true
	var tree := unit.get_tree()
	if defends_hive(unit, tree):
		withdraw(unit)
		return true
	_queue(unit)
	if cap_for(unit) - attackers(tree) <= 0:
		return false
	var joins := _joins_volley(unit, tree)
	if not joins:
		if not _gap_open(tree):
			return false
		var mine := _ticket(unit)
		for other in tree.get_nodes_in_group(WAITING):
			if other != unit and _before(_ticket(other), mine):
				return false
	unit.remove_from_group(WAITING)
	unit.add_to_group(ATTACKING)
	tree.root.set_meta(LAST_META, Engine.get_physics_frames())
	tree.root.set_meta(VOLLEY_META, volley_of(unit))
	return true


static func defends_hive(unit: Node, tree: SceneTree) -> bool:
	var at: Vector3 = (unit as Node3D).global_position
	for hive in tree.get_nodes_in_group(ANCHOR_GROUP):
		if hive.get("kind") != "warden" or hive.get("family") != HIVE_FAMILY or not is_instance_valid(hive):
			continue
		if hive.has_method("is_dead") and hive.is_dead():
			continue
		if (hive as Node3D).global_position.distance_to(at) <= DEFEND_RADIUS:
			return true
	return false


static func volley_of(unit: Node) -> Array:
	var pack := int(unit.get_meta(PACK_META, -1))
	return [pack, String(unit.get("kind"))] if pack >= 0 else [-1, unit.get_instance_id()]


static func _joins_volley(unit: Node, tree: SceneTree) -> bool:
	return not _gap_open(tree) and int(unit.get_meta(PACK_META, -1)) >= 0 \
		and tree.root.get_meta(VOLLEY_META, []) == volley_of(unit)


static func withdraw(unit: Node) -> void:
	if unit.is_in_group(WAITING):
		unit.remove_from_group(WAITING)


static func clock_out(unit: Node, seconds: float) -> void:
	var until := Engine.get_physics_frames() + ceili(seconds * Engine.physics_ticks_per_second)
	unit.set_meta(CLOCKED_OUT_META, maxi(until, int(unit.get_meta(CLOCKED_OUT_META, 0))))


static func clocked_out(unit: Node) -> bool:
	return Engine.get_physics_frames() < int(unit.get_meta(CLOCKED_OUT_META, 0))


static func release(unit: Node) -> void:
	if unit.is_in_group(ATTACKING):
		unit.remove_from_group(ATTACKING)


static func gap_open_for(unit: Node) -> bool:
	if clocked_out(unit):
		return false
	if not unit.is_inside_tree() or _off(unit):
		return true
	var tree := unit.get_tree()
	if defends_hive(unit, tree):
		return true
	return _gap_open(tree) or _joins_volley(unit, tree)


static func mark_warn(unit: Node) -> void:
	if not unit.is_inside_tree() or _off(unit):
		return
	var tree := unit.get_tree()
	if defends_hive(unit, tree):
		return
	tree.root.set_meta(LAST_META, Engine.get_physics_frames())
	tree.root.set_meta(VOLLEY_META, volley_of(unit))


static func gap_frames() -> int:
	return ceili(MIN_GAP * Engine.physics_ticks_per_second / Engine.time_scale - 0.0001)


static func _off(unit: Node) -> bool:
	var root = unit.get("world_root")
	return root != null and is_instance_valid(root) and root.has_meta(OFF_META)


static func _gap_open(tree: SceneTree) -> bool:
	if not tree.root.has_meta(LAST_META):
		return true
	return Engine.get_physics_frames() - int(tree.root.get_meta(LAST_META)) >= gap_frames()


static func _queue(unit: Node) -> void:
	if not unit.is_in_group(WAITING):
		unit.set_meta(WAITING, Engine.get_physics_frames())
		unit.add_to_group(WAITING)


static func _ticket(unit: Node) -> Array:
	return [int(unit.get_meta(WAITING, 0)), unit.get_instance_id()]


static func _before(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])


static func ally_cap_at(heft_class: int) -> int:
	return ALLY_LATE if heft_class >= 5 else ALLY_START


static func ally_attackers(tree: SceneTree) -> int:
	return tree.get_nodes_in_group(ALLY_ATTACKING).size() if tree != null else 0


static func ask_ally(unit: Node, heft_class := 1) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if unit.is_in_group(ALLY_ATTACKING):
		return true
	if not unit.is_inside_tree() or _off(unit):
		return true
	var tree := unit.get_tree()
	_queue_ally(unit)
	if ally_cap_at(heft_class) - ally_attackers(tree) <= 0:
		return false
	if not _ally_gap_open(tree):
		return false
	var mine := _ally_ticket(unit)
	for other in tree.get_nodes_in_group(ALLY_WAITING):
		if other != unit and _before(_ally_ticket(other), mine):
			return false
	unit.remove_from_group(ALLY_WAITING)
	unit.add_to_group(ALLY_ATTACKING)
	tree.root.set_meta(ALLY_LAST_META, Engine.get_physics_frames())
	return true


static func withdraw_ally(unit: Node) -> void:
	if unit != null and is_instance_valid(unit) and unit.is_in_group(ALLY_WAITING):
		unit.remove_from_group(ALLY_WAITING)


static func release_ally(unit: Node) -> void:
	if unit != null and is_instance_valid(unit) and unit.is_in_group(ALLY_ATTACKING):
		unit.remove_from_group(ALLY_ATTACKING)


static func reset_ally(tree: SceneTree) -> void:
	if tree == null:
		return
	for node in tree.get_nodes_in_group(ALLY_ATTACKING):
		if is_instance_valid(node):
			node.remove_from_group(ALLY_ATTACKING)
	for node in tree.get_nodes_in_group(ALLY_WAITING):
		if is_instance_valid(node):
			node.remove_from_group(ALLY_WAITING)
	if tree.root != null and tree.root.has_meta(ALLY_LAST_META):
		tree.root.remove_meta(ALLY_LAST_META)


static func ally_gap_frames() -> int:
	return ceili(ALLY_MIN_GAP * Engine.physics_ticks_per_second / Engine.time_scale - 0.0001)


static func _ally_gap_open(tree: SceneTree) -> bool:
	if tree == null or tree.root == null or not tree.root.has_meta(ALLY_LAST_META):
		return true
	return Engine.get_physics_frames() - int(tree.root.get_meta(ALLY_LAST_META)) >= ally_gap_frames()


static func _queue_ally(unit: Node) -> void:
	if not unit.is_in_group(ALLY_WAITING):
		unit.set_meta(ALLY_WAITING, Engine.get_physics_frames())
		unit.add_to_group(ALLY_WAITING)


static func _ally_ticket(unit: Node) -> Array:
	return [int(unit.get_meta(ALLY_WAITING, 0)), unit.get_instance_id()]
