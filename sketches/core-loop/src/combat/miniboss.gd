extends "res://src/combat/enemy.gd"

# The miniboss, a heavy scrap warden that events can drop into a stage through
# ctx.spawner.spawn_enemy("miniboss", at). It fights in a readable loop:
#
#   stalk -> leap slam  -> weak window -> stalk -> charge -> weak window -> ...
#
# - Leap slam: a ring is committed at where you are, it crouches, then leaps and lands
#   on the ring's centre when the ring has filled. Only the ring hurts.
# - Charge: a long lane is committed toward you; it braces, then charges down it.
#   Only the lane hurts, and only where its body is.
# - Weak window: after each attack it is stuck and vented. The armour plates swing
#   open, the core swells and glows, and a halo spins over it. Its plating drops to 0,
#   so every hit lands in full. Outside the window its plating is 1.25 times the stage
#   Warden's (spec "plating", set by the spawner), so a small punch only chips 20%: the
#   same grammar as every plated target. The fight's rhythm is: read the telegraph,
#   dodge on the move, punish the window.
#
# Weight: WEIGHT divides every shove, so rams rock it and slams nudge it; it cannot be
# knocked during a leap or a charge.

const HP := 600.0
# Used only when the spawner passes no plating (1.25 x a stage-1 Warden's 30).
const DEFAULT_PLATING := 38.0
const SCRAP := 24
const WEIGHT := 5.0
const RADIUS := 2.3
const HALF_HEIGHT := 3.45
const WALK := 5.5
const STALK := 1.6
const SLAM_CROUCH := 0.5
const SLAM_LEAP := 0.9
const SLAM_RADIUS := 7.0
const SLAM_HEIGHT := 9.0
const SLAM_DAMAGE := 24.0
const SLAM_SHOVE := 9.0
const CHARGE_BRACE := 1.0
const CHARGE_LENGTH := 30.0
const CHARGE_WIDTH := 4.6
const CHARGE_TIME := 0.9
const CHARGE_DAMAGE := 20.0
const CHARGE_SHOVE := 10.0
const WEAK_SECONDS := 2.4

enum State { STALK, SLAM_CROUCH, SLAM_LEAP, CHARGE_BRACE, CHARGE, WEAK }

var state := State.STALK
var attacks := 0
var weak_windows := 0
var hits_landed := 0

var _clock := 0.0
var _next_attack := 0
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _landed := false
var _core: MeshInstance3D
var _core_material: StandardMaterial3D
var _plates: Array = []
var _halo: MeshInstance3D


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = "miniboss"
	_set_health(HP * threat)
	plating = spec.get("plating", DEFAULT_PLATING)
	scrap_value = SCRAP
	weight = WEIGHT
	radius = RADIUS
	half_height = HALF_HEIGHT
	_add_capsule(RADIUS, HALF_HEIGHT * 2.0, Palette.COPPER)
	_build_armour()


func state_name() -> String:
	return ["stalk", "slam_crouch", "slam_leap", "charge_brace", "charge", "weak"][state]


func is_weak() -> bool:
	return state == State.WEAK


func plating_now() -> float:
	return 0.0 if state == State.WEAK else plating


func knock(direction: Vector3, force: float) -> void:
	if state == State.SLAM_LEAP or state == State.CHARGE:
		return
	super.knock(direction, force)


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	_pose(delta)
	if not _in_play() or target == null:
		if state != State.SLAM_LEAP:
			_move(delta, Vector3.ZERO)
		return
	_clock += delta
	var to_ball := _flat_to_ball()
	match state:
		State.STALK:
			_move(delta, to_ball.normalized() * WALK if to_ball.length() > RADIUS + 3.0 else Vector3.ZERO)
			if _clock >= STALK and is_on_floor():
				_begin_attack(to_ball)
		State.SLAM_CROUCH:
			_move(delta, Vector3.ZERO)
			_fill(_clock / (SLAM_CROUCH + SLAM_LEAP))
			if _clock >= SLAM_CROUCH:
				_enter(State.SLAM_LEAP)
				_leap_from = global_position
		State.SLAM_LEAP:
			_fill((SLAM_CROUCH + _clock) / (SLAM_CROUCH + SLAM_LEAP))
			var t := clampf(_clock / SLAM_LEAP, 0.0, 1.0)
			var arc := _leap_from.lerp(_leap_to, t) + Vector3.UP * SLAM_HEIGHT * 4.0 * t * (1.0 - t)
			global_position = arc
			velocity = Vector3.ZERO
			if t >= 1.0:
				_land_slam()
		State.CHARGE_BRACE:
			_move(delta, Vector3.ZERO)
			_fill(_clock / CHARGE_BRACE)
			if _clock >= CHARGE_BRACE:
				_enter(State.CHARGE)
				_landed = false
		State.CHARGE:
			var lane := telegraph()
			if lane == null:
				_open_weak_window()
				return
			_move(delta, lane.dir * CHARGE_LENGTH / CHARGE_TIME)
			_check_charge(lane)
			var along: float = (global_position - lane.center).dot(lane.dir)
			if _clock >= CHARGE_TIME or along >= lane.length:
				_open_weak_window()
		State.WEAK:
			_move(delta, Vector3.ZERO)
			if _clock >= WEAK_SECONDS:
				_enter(State.STALK)


func _enter(next: int) -> void:
	state = next
	_clock = 0.0


# Slam first, then charge, alternating. Each attack commits its geometry up front.
func _begin_attack(to_ball: Vector3) -> void:
	attacks += 1
	if _next_attack == 0:
		var ball := _ball()
		_leap_to = Vector3(ball.x, terrain.height(ball.x, ball.z) + HALF_HEIGHT, ball.z)
		_commit_ring(Threat.Type.PROJECTILE, ball, SLAM_RADIUS, 4.0)
		telegraph().set_flight(global_position + Vector3.DOWN * HALF_HEIGHT, 4.0 * SLAM_HEIGHT)
		_enter(State.SLAM_CROUCH)
	else:
		var heading := to_ball if to_ball.length() > 0.5 else -global_basis.z
		_commit_lane(Threat.Type.LANE, global_position, heading, CHARGE_LENGTH, CHARGE_WIDTH, 4.0)
		_enter(State.CHARGE_BRACE)
	_next_attack = 1 - _next_attack


func _land_slam() -> void:
	var ring := telegraph()
	if ring != null and ring.contains(_ball()):
		var away := _flat_to_ball()
		away = away.normalized() if away.length() > 0.1 else Vector3.ZERO
		hits_landed += 1
		hit_player.emit(SLAM_DAMAGE, away * SLAM_SHOVE + Vector3.UP * 5.0)
	_open_weak_window()


func _check_charge(lane: Node3D) -> void:
	if _landed:
		return
	var to := _flat_to_ball()
	if to.length() > RADIUS + 1.6 or not lane.contains(_ball()):
		return
	_landed = true
	hits_landed += 1
	hit_player.emit(CHARGE_DAMAGE, lane.dir * CHARGE_SHOVE + Vector3.UP * 3.0)


func _open_weak_window() -> void:
	_clear_telegraph()
	weak_windows += 1
	_enter(State.WEAK)


func _fill(value: float) -> void:
	var shown := telegraph()
	if shown != null:
		shown.set_progress(value)


func _build_armour() -> void:
	_core_material = Palette.solid(Palette.SAND, 0.4)
	_core = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	_core.mesh = sphere
	_core.material_override = _core_material
	_core.position = Vector3(0.0, 0.6, -RADIUS * 0.75)
	add_child(_core)
	var plate_material := _plate_material()
	for side in [-1.0, 1.0]:
		var plate := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(RADIUS * 1.1, HALF_HEIGHT * 1.3, 0.5)
		plate.mesh = box
		plate.material_override = plate_material
		plate.position = Vector3(side * RADIUS * 0.5, 0.6, -RADIUS - 0.1)
		add_child(plate)
		_plates.append({"node": plate, "side": side})
	_halo = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.4
	torus.outer_radius = 1.8
	_halo.mesh = torus
	_halo.material_override = Palette.unshaded(Palette.SAND)
	_halo.position = Vector3.UP * (HALF_HEIGHT + 1.4)
	_halo.visible = false
	add_child(_halo)
	# A lit crown of spikes: the silhouette says "boss" from 100 m before its size does.
	for i in 5:
		var angle := TAU * i / 5.0
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.4
		spike.height = 1.6
		_accent(spike, Palette.COPPER, 1.8, Vector3(cos(angle) * 1.3, HALF_HEIGHT + 0.5, sin(angle) * 1.3))


# The weak window reads three ways at once: the plates swing open (shape), the core
# swells and burns bright (colour and size), and a halo spins overhead (motion).
func _pose(delta: float) -> void:
	if _core == null:
		return
	var weak := state == State.WEAK
	var open := 1.0 if weak else 0.0
	for entry in _plates:
		var plate: MeshInstance3D = entry["node"]
		var side: float = entry["side"]
		plate.position.x = lerpf(plate.position.x, side * RADIUS * (0.5 + 0.9 * open), 1.0 - exp(-14.0 * delta))
		plate.rotation.y = lerpf(plate.rotation.y, side * 0.9 * open, 1.0 - exp(-14.0 * delta))
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.018) if weak else 1.0
	_core.scale = Vector3.ONE * (1.5 * pulse if weak else 0.8)
	_core_material.emission_energy_multiplier = 4.0 if weak else 1.2
	_halo.visible = weak
	if weak:
		_halo.rotate_y(delta * 5.0)
	# Face the ball while stalking or bracing, so the core is toward the player.
	if state == State.STALK or state == State.CHARGE_BRACE or state == State.WEAK or state == State.SLAM_CROUCH:
		var to := _flat_to_ball()
		if state == State.CHARGE_BRACE and telegraph() != null:
			to = telegraph().dir
		if to.length() > 0.5:
			var want := atan2(-to.x, -to.z)
			rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-8.0 * delta))
