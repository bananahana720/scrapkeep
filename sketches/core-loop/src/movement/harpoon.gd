extends RefCounted

const Augments := preload("res://src/movement/augments.gd")
const AbilityState := preload("res://src/core/ability_state.gd")

# The harpoon's static rules (DESIGN-NOTES, "Harpoon and winch"): which body a press would
# bite, and whether the class burst can take a press. The line itself is
# the grapple's, on AugmentKit, and moves in Augments._grapple.

# A lock already held survives out to this many times the cone.
const STICKY := 1.5


# What a press would bite right now, in the record the reticle, the world marker and the
# fire action share. Lock prefers an enemy inside the cone, seen from the ball, and otherwise
# falls back to the centre ray, which takes an enemy or the world. Walkable ground is refused.
static func target(kit, tuning, space: PhysicsDirectSpaceState3D, enemies: Array, from: Vector3,
		forward: Vector3, ball: Vector3) -> Dictionary:
	var reach: float = tuning.f("rope_range")
	var assist: float = tuning.f("grapple_assist_deg")
	forward = forward.normalized()
	var locked := _lock(kit, tuning, space, enemies, from, forward, ball, reach)
	if not locked.is_empty():
		return locked
	return Augments.grapple_target(space, from, forward, ball, reach, assist,
		Augments.WORLD_MASK | Augments.ENEMY_MASK, false)


static func _lock(kit, tuning, space: PhysicsDirectSpaceState3D, enemies: Array, from: Vector3,
		forward: Vector3, ball: Vector3, reach: float) -> Dictionary:
	var cone := deg_to_rad(tuning.f("harpoon_lock_deg"))
	var held = kit.lock_body
	var found: Array = []
	for enemy in enemies:
		if not Augments.hookable_body(enemy):
			continue
		var centre: Vector3 = enemy.global_position
		var gap := centre.distance_to(ball)
		if gap > reach or (centre - ball).dot(forward) <= 0.0:
			continue
		var angle := forward.angle_to(centre - from)
		if angle <= cone * (STICKY if enemy == held else 1.0):
			found.append([angle, enemy])
	found.sort_custom(func(a, b): return a[0] < b[0])
	for entry in found:
		var enemy: Node3D = entry[1]
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(ball, enemy.global_position, Augments.WORLD_MASK)).is_empty():
			kit.lock_body = enemy
			var away := ball - enemy.global_position
			return {"state": Augments.AIM_BODY, "point": enemy.global_position,
				"normal": away.normalized() if away.length() > 0.01 else Vector3.UP, "body": enemy}
	kit.lock_body = null
	return {}


# Whether the class movement burst can take a press this tick: Rivet's sprint with a
# charge and not already running, Kest's blink with a charge (or her free blink out of the
# cloak). A slam plant or a pylon mount stands the burst down.
static func burst_ready(kit) -> bool:
	if Augments.holding(kit):
		return false
	if kit.on(Augments.SPRINT):
		return kit.abilities.ready(AbilityState.MOVEMENT) and not kit.sprinting
	if kit.on(Augments.BLINK):
		return kit.abilities.ready(AbilityState.MOVEMENT) or (kit.cloaked and kit.knob("cloak_free_blink"))
	return false
