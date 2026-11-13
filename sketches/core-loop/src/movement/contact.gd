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


# The contact normal, body to ball and full 3D, as RigidBall reports it. A zero or
# near-zero offset (the centres coincide) reads as straight up.
static func normal_between(ball_at: Vector3, body_at: Vector3) -> Vector3:
	var offset := ball_at - body_at
	return offset.normalized() if offset.length() > 0.01 else Vector3.UP


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


# Knockback grows with the hit (KNOCKBACK-FEEL, 2026-10-17). A ram's shove scales with the
# speed it lands at and the heft behind it, so a late-run slam throws a body far harder than
# an early bump: (speed / KNOCK_REF_SPEED) ^ KNOCK_SPEED_EXP x heft ^ KNOCK_HEFT_EXP. At
# KNOCK_REF_SPEED (blazing at the default cruise) and heft 1 it is the old flat shove. Speed
# counts up to SOFT_CAP_SPEED: past it the wave 17 soft cap turns speed into hit damage and
# the blazing trail, not into throw. No ram throws harder than KNOCK_CEILING; a paid haul
# landing (the chain's multiplier) may reach LANDING_CEILING.
const KNOCK_REF_SPEED := 27.0
const KNOCK_SPEED_EXP := 0.6
const KNOCK_HEFT_EXP := 0.30
const SOFT_CAP_SPEED := 60.0
const KNOCK_CEILING := 34.0
const LANDING_CEILING := 42.0


static func heft_knock(heft: float) -> float:
	return pow(maxf(heft, 1.0), KNOCK_HEFT_EXP)


static func knock_scale(speed: float, heft: float) -> float:
	return pow(clampf(speed, 0.0, SOFT_CAP_SPEED) / KNOCK_REF_SPEED, KNOCK_SPEED_EXP) * heft_knock(heft)


# The shove a ram of base `base` lands at `speed` with `heft`, times a haul landing's `mult`.
# A shove's heft share: grows with heft up to the knock ceiling, never under the plain shove.
static func heft_shove(force: float, heft: float) -> float:
	return minf(force * heft_knock(heft), maxf(force, KNOCK_CEILING))


static func ram_knock(base: float, speed: float, heft: float, mult := 1.0) -> float:
	var knock := minf(base * knock_scale(speed, heft), KNOCK_CEILING)
	return minf(knock * mult, LANDING_CEILING) if mult > 1.0 else knock


# A bump: the ball meeting a world face that is not a floor (a wall, a cliff, a dam face, a
# structure's side or a ceiling) fast enough to feel it. Floors are landings (rigid_ball's
# landed). The closing speed is the part of the velocity handed to the solver that ran into
# the face; a roll along a wall closes at nothing, so a carve or a grip never bumps.
const BUMP_FLOOR_DOT := 0.45
const BUMP_MIN_SPEED := 9.0
# One bump per this many seconds, so a ball ground into a corner reports the hit, not the rub.
const BUMP_GAP_S := 0.25


static func bump_closing(velocity: Vector3, normal: Vector3) -> float:
	if normal.y > BUMP_FLOOR_DOT:
		return 0.0
	return maxf(0.0, -velocity.dot(normal.normalized()))


# A knocked enemy thrown into a world face: it stops on the face instead of gliding along it.
# The part into the face comes back at WALL_RESTITUTION, the part along it keeps WALL_GRIP_KEEP.
const WALL_SLAM_SPEED := 8.0
const WALL_RESTITUTION := 0.25
const WALL_GRIP_KEEP := 0.35


# The knock left after a wall slam: the flat part reflected off `normal` (flat, face to enemy).
static func wall_slam_knock(knock: Vector3, normal: Vector3) -> Vector3:
	var flat := Vector3(knock.x, 0.0, knock.z)
	var into := flat.dot(normal)
	if into >= 0.0:
		return knock
	var along := (flat - normal * into) * WALL_GRIP_KEEP
	var out := along - normal * into * WALL_RESTITUTION
	return Vector3(out.x, knock.y, out.z)
