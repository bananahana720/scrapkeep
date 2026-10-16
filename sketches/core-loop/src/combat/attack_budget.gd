extends RefCounted

# The attacker budget (W13-INTEGRATION-3 SQ2): at most CAP pack units in WARN or LIVE at
# once. A counter asks where it decides to attack (counter.gd, before _warn) and gives its
# slot back when the attack ends; a freed unit leaves the group with its node, so a death
# mid-attack never strands a slot. The Warden and its posture fight never ask: they are
# not counters, so they are exempt by construction.
#
# A unit refused a slot waits in line. The longest waiter gets the next free slot, so a
# crowd takes turns instead of the scene tree's first units taking every opening.
#
# CAP: KE9's spawner arm reported peak alive counts, not WARN or LIVE peaks, so the value
# comes from attack_budget_test's own uncapped arm: 20 seeded encounters at the park
# table's highest tier (stage 6, top time tier with the spike, hard run tier).

const CAP := 4
const ATTACKING := "attack_budget"
const WAITING := "attack_budget_wait"
# Test hook: a world root may carry its own cap (the uncapped measuring arm).
const CAP_META := "attack_budget_cap"


static func cap_for(unit: Node) -> int:
	var root = unit.get("world_root")
	if root != null and is_instance_valid(root) and root.has_meta(CAP_META):
		return int(root.get_meta(CAP_META))
	return CAP


static func attackers(tree: SceneTree) -> int:
	return tree.get_nodes_in_group(ATTACKING).size()


# Whether `unit` may start an attack now; true takes a slot it keeps until release().
static func ask(unit: Node) -> bool:
	if unit.is_in_group(ATTACKING):
		return true
	if not unit.is_inside_tree():
		return true
	var tree := unit.get_tree()
	var free := cap_for(unit) - attackers(tree)
	if free <= 0:
		_queue(unit)
		return false
	_queue(unit)
	var mine := _ticket(unit)
	var ahead := 0
	for other in tree.get_nodes_in_group(WAITING):
		if other != unit and _before(_ticket(other), mine):
			ahead += 1
	if ahead >= free:
		return false
	unit.remove_from_group(WAITING)
	unit.add_to_group(ATTACKING)
	return true


# The unit no longer wants a slot this tick (out of range, stunned, recovering).
static func withdraw(unit: Node) -> void:
	if unit.is_in_group(WAITING):
		unit.remove_from_group(WAITING)


static func release(unit: Node) -> void:
	if unit.is_in_group(ATTACKING):
		unit.remove_from_group(ATTACKING)


static func _queue(unit: Node) -> void:
	if not unit.is_in_group(WAITING):
		unit.set_meta(WAITING, Engine.get_physics_frames())
		unit.add_to_group(WAITING)


static func _ticket(unit: Node) -> Array:
	return [int(unit.get_meta(WAITING, 0)), unit.get_instance_id()]


static func _before(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])
