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
# Readability is the floor under the chaos: two distinct threats never start their warnings
# within MIN_GAP of each other, so each gets its own beat to read and answer. One threat is a
# volley: the units of one director pack of one kind (pack_seq, set by world.gd from the
# director's arrival). A volley's members wind up on the same beat, together or in a ripple,
# and the gap counts from its last member (Andrew, 2026-10-17 15:30Z card "Pack as one").
# Why: a strict gap between pack mates slowed the swarm band's grown ball (46.4 s, small to
# grown 1.83x against the 2x rule; machine gate on PR #15).
#
# Who the budget counts (Andrew's rulings): counters and Dispatcher chasers do; the Foreman and
# Linker, the Warden and bosses never ask. Hive defenders skip the whole budget, cap and gap: a
# unit within DEFEND_RADIUS of a live swarm-family Warden (the stage 3 hive, the stage 4 brood nest)
# attacks whenever it is ready, for every pilot (Andrew, 2026-10-17: 20:52:11Z card "Swarm campers",
# a ranged-only pilot must not break a hive; 21:19:16Z card "All at hives", the gap goes too, since
# with it a camper still broke the hive by luck). They take no slot from the crowd elsewhere.
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
const VOLLEY_META := "attack_budget_volley"
# Hive Wardens are harpoon anchors (warden.gd set_harpoon_anchor); this is augments.gd ANCHOR_GROUP.
const ANCHOR_GROUP := "harpoon_anchor"
const HIVE_FAMILY := "swarm"
# The hive's reach (warden.gd DEFAULT_REACH, 30 m) plus a lunge, so a unit on a camper at range counts.
const DEFEND_RADIUS := 40.0
# The director pack a unit arrived with (world.gd); units spawned any other way are their own volley.
const PACK_META := "pack_seq"
# The physics frame a clocked-out unit may attack again (foreman.gd: its crew, when it dies).
const CLOCKED_OUT_META := "clocked_out_until"


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


# One threat: the unit's director pack and kind. A unit with no pack is a volley of one.
static func volley_of(unit: Node) -> Array:
	var pack := int(unit.get_meta(PACK_META, -1))
	return [pack, String(unit.get("kind"))] if pack >= 0 else [-1, unit.get_instance_id()]


# A pack mate of the last warning joins its beat while the gap is still running.
static func _joins_volley(unit: Node, tree: SceneTree) -> bool:
	return not _gap_open(tree) and int(unit.get_meta(PACK_META, -1)) >= 0 \
		and tree.root.get_meta(VOLLEY_META, []) == volley_of(unit)


# The unit no longer wants a slot this tick (out of range, stunned, recovering).
static func withdraw(unit: Node) -> void:
	if unit.is_in_group(WAITING):
		unit.remove_from_group(WAITING)


# A unit told to stand down for `seconds` starts no attack until they pass; one it has already
# warned of plays out, since its warning was a promise.
static func clock_out(unit: Node, seconds: float) -> void:
	var until := Engine.get_physics_frames() + ceili(seconds * Engine.physics_ticks_per_second)
	unit.set_meta(CLOCKED_OUT_META, maxi(until, int(unit.get_meta(CLOCKED_OUT_META, 0))))


static func clocked_out(unit: Node) -> bool:
	return Engine.get_physics_frames() < int(unit.get_meta(CLOCKED_OUT_META, 0))


static func release(unit: Node) -> void:
	if unit.is_in_group(ATTACKING):
		unit.remove_from_group(ATTACKING)


# Whether a unit that already holds an attacking slot (or checks the inter-warning floor before
# chaining a secondary tell) may open a new warning now without breaching MIN_GAP (0.2 s).
static func gap_open_for(unit: Node) -> bool:
	if clocked_out(unit):
		return false
	if not unit.is_inside_tree() or _off(unit):
		return true
	var tree := unit.get_tree()
	if defends_hive(unit, tree):
		return true
	return _gap_open(tree) or _joins_volley(unit, tree)


# Records a warning beat opened by a unit that already holds a slot (e.g. a secondary tell
# chained from an active hold), so no distinct unit warns within MIN_GAP after it.
static func mark_warn(unit: Node) -> void:
	if not unit.is_inside_tree() or _off(unit):
		return
	var tree := unit.get_tree()
	if defends_hive(unit, tree):
		return
	tree.root.set_meta(LAST_META, Engine.get_physics_frames())
	tree.root.set_meta(VOLLEY_META, volley_of(unit))


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
