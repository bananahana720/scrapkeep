extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const SignalLifetime := preload("res://src/core/signal_lifetime.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")

# The swarm remnant's per-kind driver (unit KF3, design-v3/wardens/swarm.md sections 3 and 4).
# warden.gd loads it for every park Warden of the swarm family (spec "harpoon_anchor": true,
# no "mount_driver"; warden.gd "The per-kind hook"). The swarm carries: both mechanisms move
# the fight up and down, and neither adds a posture number.
#
# - headframe (stage 3): the hive rides the hoist on a CYCLE of 12 s: DWELL low at the collar,
#   MOVE up RISE metres, DWELL high under the tipple deck, MOVE back down. A charge starts only
#   PULSE_TELEGRAPH before a dwell ends (charge_allowed), so the pulse lands on each dwell's last
#   tick and the 6 s pulse cycle locks to the hoist. A stagger brakes the hoist: the hive drops
#   to the collar over BRAKE_DROP, stays there for the stagger, and the cycle starts again from
#   the low dwell when it ends. A ball latched through RIDE_MIN of the rise is thrown at the
#   stop: the line drops off the grip cell ("shrugged") and the ball keeps the hoist's upward
#   speed, so the ride throws it toward the tipple deck (the section 4 throw); the hoist_ride
#   fact fires. A ball that latches at the high dwell hangs there for the line fight.
# - sinkhole (stage 4, brood): the nest never moves. Each chunk lost raises the pool floor
#   POOL_STEP: the pool_swell fact telegraphs it for SWELL_SECONDS, then the floor rises over
#   RISE_SECONDS. The rise waits while the ball is grounded on the pool (terrain_event.gd's hold
#   rule); after HOLD_FALLBACK held seconds the swell lifts the ball LIFT m/s straight up through
#   crowd_control, as the pulse does, planar speed untouched, and the floor rises under the
#   airborne ball. The floor is a collider this driver moves, built only where the terrain
#   under the pool's centre lies at or below the first floor (a park pit); elsewhere the floor
#   is kept as numbers alone. Where the pool is: spec "pool_centre" and "pool_floor", else
#   POOL_OFFSET from the nest and POOL_BELOW_NEST under it (the stage 4 page's numbers).
# - The lamp guard (brood): the cruise-or-faster ram that kills the last lamp pays the rack's
#   25 posture once per guard, through the same judge the rack uses (warden.gd judge_hit
#   "guard_rack"), because lamp_swarm has no formation for warden.gd's rack rule to read.
# - The snip is the swarm's shrug: warden.gd cuts the flaring line on the pulse with the
#   ball's velocity kept plus the lift. snip_progress() is the drones' walk up the rope for the
#   look (the charge's fill); the driver changes nothing else about the cut.

const HEADFRAME := "headframe"
const SINKHOLE := "sinkhole"
const DWELL := 4.0
const MOVE := 2.0
const CYCLE := 2.0 * (DWELL + MOVE)
const RISE := 30.0
const BRAKE_DROP := 0.9
const RIDE_MIN := 1.0
# Height above the ground under the hive at which floor rams can no longer reach it (PF-42).
const HEADFRAME_FLOOR_REACH := 5.0
# The ball must still be rising at least this fast at the stop to be thrown.
const THROW_SPEED := 5.0
const POOL_STEP := 5.0
const POOL_BELOW_NEST := 21.0
const POOL_OFFSET := Vector3(0.0, 0.0, -38.0)
const POOL_RADIUS := 40.0
# A grounded ball this close above the floor stands on the pool.
const POOL_ON_FLOOR := 3.0
const SWELL_SECONDS := 2.0
const RISE_SECONDS := 3.0
const HOLD_FALLBACK := 6.0
const LIFT := 10.0
const POOL_THICKNESS := 1.0
const HOIST_FACT := "hoist_ride"
const SWELL_FACT := "pool_swell"
const LAMP_GUARD := "lamp_swarm"
# The kill and the ram that made it are a frame or two apart (strike, then the step).
const LAMP_RAM_FRAMES := 3

# The hoist: the cycle clock, the hive's height over the collar, the brake-drop, the ride.
var clock := 0.0
var height := 0.0
var dropping := false
var rides := 0
var _drop_from := 0.0
var _drop_time := 0.0
var _last_mount := 0.0
var _ride := 0.0
var _prev_clock := 0.0

# The pool: where it is, its floor now and where it is going, the swell, the hold.
var pool_centre := Vector3.ZERO
var pool_radius := POOL_RADIUS
var pool_floor := 0.0
var pool_target := 0.0
var _pool_base := 0.0
var swell_left := -1.0
var held := 0.0
var swells := 0
var lifts := 0
var _pool_ready := false
var _slab: Node3D
var _post_break_target = null

# The lamp guard.
var lamp_pays := 0
var _lamp_guard = null
var _lamp: Node3D
var _lamp_paid := false
var _lamp_ram_frame := -100
var _listening := false


# The body's offset from home at the mounting clock (warden.gd _step_mounting).
func mount_offset(warden, mount_clock: float) -> Vector3:
	var dt := maxf(0.0, mount_clock - _last_mount)
	_last_mount = mount_clock
	if warden.mounting != HEADFRAME:
		return Vector3.ZERO
	_prev_clock = clock
	if warden.staggered():
		if not dropping:
			dropping = true
			_drop_from = height
			_drop_time = 0.0
		_drop_time += dt
		height = maxf(0.0, _drop_from * (1.0 - _drop_time / BRAKE_DROP))
		clock = 0.0
		_prev_clock = 0.0
		return Vector3.UP * height
	if dropping:
		dropping = false
		clock = 0.0
		_prev_clock = 0.0
	var next := clock + dt
	# A dwell ends on its pulse: while a charge is in flight the hoist holds at the dwell's
	# end, so a pulse a tick late (the warden's float clocks) never lands on a moving hive
	# and the next window finds the pulse clock ready.
	if warden.state_name() == "charging":
		for dwell_end in [DWELL, 2.0 * DWELL + MOVE]:
			if clock <= dwell_end and next > dwell_end:
				next = dwell_end
	clock = fmod(next, CYCLE)
	height = height_at(clock)
	return Vector3.UP * height


# The hive's height over the collar at a point of the cycle.
static func height_at(t: float) -> float:
	if t < DWELL:
		return 0.0
	if t < DWELL + MOVE:
		return RISE * (t - DWELL) / MOVE
	if t < 2.0 * DWELL + MOVE:
		return RISE
	return RISE * maxf(0.0, 1.0 - (t - 2.0 * DWELL - MOVE) / MOVE)


# A charge starts only on the tick that leaves exactly PULSE_TELEGRAPH of a dwell, so the
# pulse lands on the dwell's last tick. Off the hoist every charge may start.
func charge_allowed(warden) -> bool:
	if warden.mounting != HEADFRAME:
		return true
	if dropping:
		return false
	# Half a tick early to two and a half late, so a pulse clock a float's width short of
	# ready on the window's tick still starts the charge; the dwell then waits for the pulse.
	var tick := 1.0 / Engine.physics_ticks_per_second
	for dwell_end in [DWELL, 2.0 * DWELL + MOVE]:
		var late: float = warden.pulse_telegraph(warden.stage) - (dwell_end - clock)
		if late >= -0.5 * tick and late <= 2.5 * tick:
			return true
	return false


func step(warden, delta: float) -> void:
	_listen(warden)
	if warden.mounting == HEADFRAME:
		_step_hoist(warden, delta)
	elif warden.mounting == SINKHOLE:
		_step_pool(warden, delta)
	_step_lamp(warden)


# --- The hoist ride ------------------------------------------------------------------

func _step_hoist(warden, delta: float) -> void:
	var lined: bool = warden.lined_hardpoint() >= 0
	if warden.get("_posture") != null:
		var engaged_in_reach: bool = warden.target != null and warden._flat_to_ball().length() <= warden.reach
		var out_of_floor_reach := _headframe_out_of_floor_reach(warden)
		warden._posture.drain_rate_scale = 0.0 if (out_of_floor_reach and not lined and engaged_in_reach) else 1.0
	if dropping:
		_ride = 0.0
		return
	if clock > DWELL and clock <= DWELL + MOVE and _prev_clock >= DWELL:
		_ride = _ride + delta if lined else 0.0
		return
	var stopped := _prev_clock < DWELL + MOVE and clock >= DWELL + MOVE and clock < 2.0 * DWELL + MOVE
	if stopped and lined and _ride >= RIDE_MIN:
		_throw(warden)
	_ride = 0.0


func _headframe_out_of_floor_reach(warden) -> bool:
	if height > HEADFRAME_FLOOR_REACH:
		return true
	var terrain = warden.get("terrain")
	if terrain != null and terrain.has_method("height"):
		var floor_y: float = terrain.height(warden.global_position.x, warden.global_position.z)
		if warden.global_position.y - floor_y > HEADFRAME_FLOOR_REACH:
			return true
	return false


func _throw(warden) -> void:
	var target = warden.target
	var body = target.body() if target != null and target.has_method("body") else null
	var rising: float = body.linear_velocity.y if body != null else 0.0
	var at: Vector3 = target.ball_position() if target.has_method("ball_position") else warden.global_position
	if rising >= THROW_SPEED and target.has_method("cut_line"):
		target.cut_line("shrugged")
	rides += 1
	_fact(warden, HOIST_FACT, at)


# --- The pool --------------------------------------------------------------------------

# Places the pool outright (a test or a mounting row): its centre, its first floor, its radius.
func set_pool(centre: Vector3, floor_y: float, radius := POOL_RADIUS) -> void:
	if is_instance_valid(_slab):
		_slab.queue_free()
	_slab = null
	pool_centre = centre
	pool_floor = floor_y
	pool_target = floor_y
	_pool_base = floor_y
	pool_radius = radius
	_pool_ready = true
	_pending_slab = true


var _pending_slab := false


func _ready_pool(warden) -> void:
	if _pool_ready and not _pending_slab:
		return
	if not _pool_ready:
		var spec: Dictionary = warden.spec if warden.get("spec") is Dictionary else {}
		var centre = _vec(spec.get("pool_centre"))
		pool_centre = centre if centre is Vector3 else warden.home + POOL_OFFSET
		pool_floor = float(spec.get("pool_floor", warden.home.y - POOL_BELOW_NEST))
		pool_target = pool_floor
		_pool_base = pool_floor
		pool_centre.y = pool_floor
		_pool_ready = true
	_pending_slab = false
	var terrain = warden.terrain
	if terrain == null or terrain.height(pool_centre.x, pool_centre.z) > pool_floor + 0.5:
		return
	_build_slab(warden)


static func _vec(value):
	if value is Vector3:
		return value
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return null


class _PostBreakPoolFlood extends Node:
	var driver

	func _physics_process(delta: float) -> void:
		if driver == null or not is_instance_valid(driver._slab):
			driver = null
			queue_free()
			return
		driver._step_pool_rise(driver._post_break_target, delta)
		if driver.swell_left < 0.0 and driver.pool_floor >= driver.pool_target:
			driver._post_break_target = null
			driver = null
			queue_free()


func _build_slab(warden) -> void:
	var body := StaticBody3D.new()
	body.name = "SwarmPoolFloor"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = pool_radius
	cylinder.height = POOL_THICKNESS
	shape.shape = cylinder
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = pool_radius
	disc.bottom_radius = pool_radius
	disc.height = POOL_THICKNESS
	disc.radial_segments = 32
	mesh.mesh = disc
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(Palette.VERDIGRIS, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = material
	body.add_child(mesh)
	var parent: Node = warden.get("world_root") if warden.get("world_root") is Node else warden.get_parent()
	parent.add_child(body)
	body.global_position = Vector3(pool_centre.x, pool_floor - POOL_THICKNESS * 0.5, pool_centre.z)
	_slab = body
	# PF-43: When the Warden exits because it was broken (chunks_left == 0), keep SwarmPoolFloor
	# alive so the final chunk floods pool_floor flush to gallery_ring (y -100) and free it on
	# stage unload instead. Non-break exits (stage unload before break, retry, or mock Wardens
	# without chunks_left) still free the slab immediately so zero leaks occur.
	SignalLifetime.listen(body, warden.tree_exiting, func():
		if not is_instance_valid(body):
			return
		var broken: bool = is_instance_valid(warden) and warden.has_method("chunks_left") and int(warden.chunks_left()) <= 0
		if not broken:
			body.queue_free()
			return
		_persist_slab(warden, body))


func _persist_slab(warden, body: Node3D) -> void:
	pool_target = maxf(pool_target, _pool_base + float(BossPosture.CHUNKS) * POOL_STEP)
	_post_break_target = warden.get("target")
	var flood := _PostBreakPoolFlood.new()
	flood.name = "PostBreakPoolFlood"
	flood.driver = self
	body.add_child(flood)
	var fleet = warden.get("fleet")
	if fleet != null and fleet.has_method("events"):
		var events = fleet.events()
		if events != null:
			if events.has_signal("stage_content_cleared"):
				SignalLifetime.listen(body, events.stage_content_cleared, func(_reason = ""):
					if is_instance_valid(body):
						body.queue_free())
			if events.has_signal("stage_entered"):
				SignalLifetime.listen(body, events.stage_entered, func(_next_stage = 0, _retry = false):
					if is_instance_valid(body):
						body.queue_free())
	var terrain = warden.get("terrain")
	var own_stage := int(warden.get("stage")) if warden.get("stage") != null else -1
	if terrain != null and terrain.has_signal("stage_freed"):
		SignalLifetime.listen(body, terrain.stage_freed, func(freed_stage: int):
			if (own_stage < 0 or freed_stage == own_stage) and is_instance_valid(body):
				body.queue_free())


func on_chunk_lost(warden, left: int) -> void:
	if warden.mounting != SINKHOLE:
		return
	_ready_pool(warden)
	var lost_total := clampi(BossPosture.CHUNKS - maxi(0, left), 1, BossPosture.CHUNKS)
	var ceiling := _pool_base + float(BossPosture.CHUNKS) * POOL_STEP
	pool_target = clampf(maxf(pool_target + POOL_STEP, _pool_base + float(lost_total) * POOL_STEP), _pool_base, ceiling)
	swell_left = SWELL_SECONDS
	swells += 1
	_fact(warden, SWELL_FACT, Vector3(pool_centre.x, pool_floor, pool_centre.z))


func _step_pool(warden, delta: float) -> void:
	_ready_pool(warden)
	_step_pool_rise(warden.target, delta)


func _step_pool_rise(target, delta: float) -> void:
	if swell_left >= 0.0:
		swell_left -= delta
		if swell_left > 0.0:
			return
		swell_left = -1.0
	if pool_floor >= pool_target:
		held = 0.0
		return
	if _ball_on_pool_target(target):
		held += delta
		if held >= HOLD_FALLBACK:
			_lift_target(target, delta)
			held = 0.0
		return
	held = 0.0
	pool_floor = minf(pool_target, pool_floor + POOL_STEP / RISE_SECONDS * delta)
	if is_instance_valid(_slab):
		_slab.global_position.y = pool_floor - POOL_THICKNESS * 0.5


# How far the swell has run, 0 to 1, or 0 when none; read by the look.
func swell_fraction() -> float:
	return clampf(1.0 - swell_left / SWELL_SECONDS, 0.0, 1.0) if swell_left >= 0.0 else 0.0


func _ball_on_pool(warden) -> bool:
	return _ball_on_pool_target(warden.target)


func _ball_on_pool_target(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var state = target.get("state")
	if state == null or not state.on_floor():
		return false
	var ball: Vector3 = target.ball_position() if target.has_method("ball_position") else target.global_position
	return Vector2(ball.x - pool_centre.x, ball.z - pool_centre.z).length() <= pool_radius \
			and ball.y - pool_floor <= POOL_ON_FLOOR


# The fallback: the swell pops a ball that would not leave the floor, straight up, as the pulse does.
func _lift(warden, delta: float) -> void:
	_lift_target(warden.target, delta)


func _lift_target(target, delta: float) -> void:
	if target != null and is_instance_valid(target) and target.has_method("crowd_control") \
			and target.crowd_control("pool_swell", Vector3.UP * LIFT / maxf(delta, 0.0001)):
		lifts += 1


# --- The lamp guard ----------------------------------------------------------------------

func _listen(warden) -> void:
	if _listening or warden.fleet == null:
		return
	_listening = true
	SignalLifetime.listen(warden, warden.fleet.events().enemy_struck, func(enemy: Node3D, hit_kind: String, force: float):
		if hit_kind != "ram" or enemy == null or enemy != _lamp or not is_instance_valid(warden) or warden.target == null:
			return
		if SpeedTier.of(force, warden.target.tuning.tier_cruise()) >= SpeedTier.CRUISE:
			_lamp_ram_frame = Engine.get_physics_frames())


func _step_lamp(warden) -> void:
	var guard = warden.guard
	if guard != _lamp_guard:
		_lamp_guard = guard
		_lamp = null
		_lamp_paid = false
	if guard == null or warden.guard_kind() != LAMP_GUARD:
		return
	var alive: Array = guard.alive()
	if not alive.is_empty():
		_lamp = alive[0]
		return
	if _lamp_paid or _lamp == null:
		return
	_lamp_paid = true
	if Engine.get_physics_frames() - _lamp_ram_frame <= LAMP_RAM_FRAMES:
		lamp_pays += 1
		warden._apply_posture(warden.judge_hit("guard_rack", 0.0, false, 0))


# --- The snip and the facts --------------------------------------------------------------

# How far the drones have walked up the lined rope, 0 to 1 (the charge's fill), for the look.
func snip_progress(warden) -> float:
	return warden.shrug_flare() if warden.flaring_hardpoint() >= 0 else 0.0


func _fact(warden, kind: String, at: Vector3) -> void:
	if warden.fleet != null:
		warden.fleet.events().world_fact.emit(kind, at)
