extends RefCounted

# The attacker budget (W13-INTEGRATION-3 SQ2): a cap on pack units in WARN or LIVE at once.
# A counter asks where it decides to attack (counter.gd, before _warn) and gives its slot
# back when the attack ends; a freed unit leaves the group with its node, so a death
# mid-attack never strands a slot. The Warden and its posture fight never ask: they are
# not counters, so they are exempt by construction.
#
# The cap grows with the player (Andrew, 2026-10-16: chaos he can learn, scaled like The
# Binding of Isaac): it starts at START and climbs with the ball's heft class, the same
# growth signal that sizes the director's crowd, and with the world, up to LATE. Every
# number of the curve is here, for the playtest sitting to tune.
#
# Readability is the floor under the chaos: two warnings never start within MIN_GAP of
# each other, so each telegraph gets its own beat however many units are attacking.
#
# A unit refused a slot waits in line. The longest waiter gets the next free slot, so a
# crowd takes turns instead of the scene tree's first units taking every opening.

const START := 6
const PER_HEFT_CLASS := 1
const PER_WORLD := 2
const LATE := 12
const MIN_GAP := 0.2
const ATTACKING := "attack_budget"
const WAITING := "attack_budget_wait"
# Test hook: a world root carrying this meta turns the budget off (the uncapped arm).
const OFF_META := "attack_budget_off"
const LAST_META := "attack_budget_last"


# The curve: world 1 with a fresh ball is START; each heft class and each world past the
# first adds its step, never past LATE.
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


# Whether `unit` may start an attack now; true takes a slot it keeps until release().
static func ask(unit: Node) -> bool:
	if unit.is_in_group(ATTACKING):
		return true
	if not unit.is_inside_tree() or _off(unit):
		return true
	var tree := unit.get_tree()
	_queue(unit)
	var free := cap_for(unit) - attackers(tree)
	if free <= 0 or not _gap_open(tree):
		return false
	var mine := _ticket(unit)
	for other in tree.get_nodes_in_group(WAITING):
		if other != unit and _before(_ticket(other), mine):
			return false
	unit.remove_from_group(WAITING)
	unit.add_to_group(ATTACKING)
	tree.root.set_meta(LAST_META, Engine.get_physics_frames())
	return true


# The unit no longer wants a slot this tick (out of range, stunned, recovering).
static func withdraw(unit: Node) -> void:
	if unit.is_in_group(WAITING):
		unit.remove_from_group(WAITING)


static func release(unit: Node) -> void:
	if unit.is_in_group(ATTACKING):
		unit.remove_from_group(ATTACKING)


# MIN_GAP in physics steps: a step is 1 / ticks per second of game time, scaled by time_scale.
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
