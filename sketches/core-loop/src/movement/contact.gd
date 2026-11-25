extends RefCounted


const REBOUND_WEIGHT := 1.15
const SPRINT_REBOUND_WEIGHT := 1.0
const RESTITUTION := 0.65
const VERTICAL_CAP := 1.4
const MIN_CLOSING := 2.0


static func normal_between(ball_at: Vector3, body_at: Vector3) -> Vector3:
	var offset := ball_at - body_at
	return offset.normalized() if offset.length() > 0.01 else Vector3.UP


static func meets_first(a: Node3D, b: Node3D, ball_at: Vector3, landing) -> bool:
	if (a == landing) != (b == landing):
		return a == landing
	var a_far := ball_at.distance_squared_to(a.global_position)
	var b_far := ball_at.distance_squared_to(b.global_position)
	if a_far != b_far:
		return a_far < b_far
	return b.is_greater_than(a)


static func rebounds(weight: float, heft: float, sprinting: bool) -> bool:
	return weight >= heft * (SPRINT_REBOUND_WEIGHT if sprinting else REBOUND_WEIGHT)


static func rebound_velocity(velocity: Vector3, normal: Vector3, jump_speed: float) -> Vector3:
	var n := normal.normalized()
	var into := velocity.dot(n)
	if into >= 0.0:
		return velocity
	var out := velocity - n * into * (1.0 + RESTITUTION)
	out.y = minf(out.y, jump_speed * VERTICAL_CAP)
	return out


static func contact_cost(velocity: Vector3, normal: Vector3) -> float:
	return maxf(0.0, -velocity.dot(normal.normalized())) * (1.0 - RESTITUTION)


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


static func heft_shove(force: float, heft: float) -> float:
	return minf(force * heft_knock(heft), maxf(force, KNOCK_CEILING))


static func ram_knock(base: float, speed: float, heft: float, mult := 1.0) -> float:
	var knock := minf(base * knock_scale(speed, heft), KNOCK_CEILING)
	return minf(knock * mult, LANDING_CEILING) if mult > 1.0 else knock


const BUMP_FLOOR_DOT := 0.45
const BUMP_MIN_SPEED := 9.0
const BUMP_GAP_S := 0.25


static func bump_closing(velocity: Vector3, normal: Vector3) -> float:
	if normal.y > BUMP_FLOOR_DOT:
		return 0.0
	return maxf(0.0, -velocity.dot(normal.normalized()))


const WALL_SLAM_SPEED := 8.0
