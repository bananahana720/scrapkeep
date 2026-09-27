extends RefCounted

# The bowling-ball contact rule every class shares (DESIGN-V2 section 3). The ball is
# the bowling ball: an enemy at least REBOUND_WEIGHT times your heft sends you back off
# it with a controlled bounce and one refresh; a lighter one is crushed or rammed as
# before. While Rivet sprints the bar drops to SPRINT_REBOUND_WEIGHT, so every contact
# with anything your weight or more pays a refresh instead of a dead physics bounce.

const REBOUND_WEIGHT := 1.15
const SPRINT_REBOUND_WEIGHT := 1.0
const RESTITUTION := 0.65
# The bounce never throws you higher than this many jumps.
const VERTICAL_CAP := 1.4
# Slower than this into the enemy is resting against it, not hitting it.
const MIN_CLOSING := 2.0


static func rebounds(weight: float, heft: float, sprinting: bool) -> bool:
	return weight >= heft * (SPRINT_REBOUND_WEIGHT if sprinting else REBOUND_WEIGHT)


# The incoming velocity reflected across the contact normal (enemy to ball) with
# RESTITUTION on the normal part; the part along the enemy's surface is kept whole.
static func rebound_velocity(velocity: Vector3, normal: Vector3, jump_speed: float) -> Vector3:
	var n := normal.normalized()
	var into := velocity.dot(n)
	if into >= 0.0:
		return velocity
	var out := velocity - n * into * (1.0 + RESTITUTION)
	out.y = minf(out.y, jump_speed * VERTICAL_CAP)
	return out


# What a rebound may cost the player: the part of the normal speed restitution keeps.
static func contact_cost(velocity: Vector3, normal: Vector3) -> float:
	return maxf(0.0, -velocity.dot(normal.normalized())) * (1.0 - RESTITUTION)
