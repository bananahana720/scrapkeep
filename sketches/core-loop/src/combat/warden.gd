extends "res://src/combat/enemy.gd"

const WardenLook := preload("res://src/combat/warden_look.gd")

# The Warden: one per stage, an immobile clamp at the base of the beacon mast. Breaking
# it is the stage's one MUST (DEMO-SPEC). It never moves, never pins, never pushes you
# sideways. Its whole kit is:
#
# - Plating. Plating and health come from the stage (spec "plating", "hp"). Punch below
#   the plating chips 20%; the tint on its shell says which side of the line you are.
# - The pulse. While you are inside its reach (the beacon ring), it charges for
#   PULSE_TELEGRAPH seconds every PULSE_CYCLE, showing a ring the size of its reach and
#   a small core ring. Then it pulses: a ball the reach ring contains gains PULSE_LIFT
#   m/s straight up for one tick, horizontal speed untouched, and a ball the core ring
#   contains also takes PULSE_DAMAGE.
# - One lesson per stage, as data (spec "lesson"):
#   - "plate": nothing more.
#   - "caps": three vent caps on top. A stomp or slam that lands on one meets plating 0
#     and hits for CAP_MULT times its punch.
#   - "magnet": every MAGNET_CYCLE it swings a magnet arm toward you and lays a wedge
#     from the arm toward the ball for MAGNET_TELEGRAPH, then tugs a ball the wedge
#     contains toward it at MAGNET_PULL m/s^2 for MAGNET_TUG. The magnet is a weak
#     point only in the tug: a weapon hit on it then drops the Warden's plating to 0
#     for UNPLATE_SECONDS and ends the tug. An earlier shot meets the body.

const HALF_HEIGHT := 1.6
const RADIUS := 2.8
const DEFAULT_REACH := 30.0
const PULSE_CYCLE := 6.0
const PULSE_TELEGRAPH := 2.0
const PULSE_LIFT := 10.0
const PULSE_DAMAGE := 10.0
const CORE_RADIUS := 6.0
const LIFT_REACH_UP := 8.0
const CAP_COUNT := 3
const CAP_RING := 1.6
const CAP_RADIUS := 0.9
const CAP_REACH := 2.6
const CAP_MULT := 1.5
const MAGNET_CYCLE := 8.0
const MAGNET_TELEGRAPH := 1.5
const MAGNET_TUG := 1.5
# The change request said 6 m/s^2; at 6 a ball driving away fell to 10.4 m/s against
# its own 0.8 x cruise (11.2) floor (a no-tug control run: 12.9); 4 cleared it by only
# 0.2 m/s, so the pull is 3.5.
const MAGNET_PULL := 3.5
const MAGNET_ARM := 3.2
# The magnet rides high over the clamp, out of the straight line from the ball to the
# body, so shooting it is a choice you aim for rather than an accident of body fire.
const MAGNET_RISE := 3.6
const MAGNET_RADIUS := 1.1
# The pull telegraphs as a wedge from the arm toward the ball, this wide either side, so
# it never reads as the pulse ring; the tug pulls only a ball the wedge contains.
const MAGNET_WEDGE_DEG := 35.0
const UNPLATE_SECONDS := 3.0
const WEAPON_KINDS := ["runner", "arc", "turret"]
const CONTACT_KINDS := ["stomp", "slam"]

enum Magnet { IDLE, TELEGRAPH, TUG }

var stage := 1
var lesson := "plate"
var reach := DEFAULT_REACH
var pulses := 0
# Whether the last pulse's reach ring contained the ball (and so lifted it).
var last_pulse_lifted := false
var min_pulse_telegraph := INF
var magnet_stuns := 0
var magnet_state := Magnet.IDLE
var shred := 0.0

var _pulse_clock := 0.0
var _charging := false
var _charge_time := 0.0
var _core_ring: Node3D
var _since_pulse := INF
var _magnet_clock := 0.0
var _magnet_time := 0.0
var _magnet_dir := Vector3.FORWARD
var _magnet_ring: Node3D
var _unplated := 0.0
var _cap_material: StandardMaterial3D
var _look: Node3D


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, _threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = "warden"
	stage = spec.get("stage", 1)
	lesson = spec.get("lesson", "plate")
	reach = spec.get("reach", DEFAULT_REACH)
	plating = spec.get("plating", 30.0)
	_set_health(spec.get("hp", 400.0))
	scrap_value = 30 * stage
	weight = 1000.0
	radius = RADIUS
	half_height = HALF_HEIGHT
	# Clamped to the mast base: sits on the ground under the point it was given.
	global_position = Vector3(global_position.x, terrain.height(global_position.x, global_position.z) + HALF_HEIGHT, global_position.z)
	_build_body()


func state_name() -> String:
	if magnet_state == Magnet.TUG:
		return "tug"
	if magnet_state == Magnet.TELEGRAPH:
		return "magnet_telegraph"
	return "charging" if _charging else "idle"


func knock(_direction: Vector3, _force: float) -> void:
	pass


func plating_now() -> float:
	return 0.0 if _unplated > 0.0 else plating


func unplated_by_magnet() -> bool:
	return _unplated > 0.0


func seconds_since_pulse() -> float:
	return _since_pulse


func plating_for(hit_kind: String, part: String) -> float:
	if part == "cap" and hit_kind in CONTACT_KINDS:
		return 0.0
	if part == "magnet" and hit_kind in WEAPON_KINDS and magnet_state == Magnet.TUG:
		return 0.0
	return plating_now()


func hit_mult(hit_kind: String, part: String) -> float:
	return CAP_MULT if part == "cap" and hit_kind in CONTACT_KINDS else 1.0


func weak_points() -> Array:
	var points := []
	if lesson == "magnet" and magnet_state == Magnet.TUG:
		points.append({"id": "magnet", "at": magnet_point(), "radius": MAGNET_RADIUS})
	return points


func cap_points() -> Array:
	var points := []
	if lesson != "caps":
		return points
	for i in CAP_COUNT:
		var angle := TAU * i / CAP_COUNT
		points.append(global_position + Vector3(cos(angle) * CAP_RING, HALF_HEIGHT + 0.3, sin(angle) * CAP_RING))
	return points


func magnet_point() -> Vector3:
	return global_position + _magnet_dir * MAGNET_ARM + Vector3.UP * MAGNET_RISE


func contact_part(ball: Vector3, hit_kind: String) -> String:
	if lesson != "caps" or not hit_kind in CONTACT_KINDS:
		return ""
	for cap in cap_points():
		if Vector2(ball.x - cap.x, ball.z - cap.z).length() <= CAP_REACH:
			return "cap"
	return ""


func on_struck(hit_kind: String, part: String, _result: Dictionary) -> void:
	if part == "magnet" and hit_kind in WEAPON_KINDS and magnet_state == Magnet.TUG:
		_unplated = UNPLATE_SECONDS
		magnet_stuns += 1
		_end_magnet()
	if part == "cap" and _cap_material != null:
		_cap_material.emission_energy_multiplier = 5.0


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	_pose(delta)
	if not _in_play() or target == null:
		return
	_since_pulse += delta
	_unplated = maxf(0.0, _unplated - delta)
	var inside := _flat_to_ball().length() <= reach
	_step_pulse(delta, inside)
	if lesson == "magnet":
		_step_magnet(delta, inside)


# The pulse cycle runs while you are in reach; once charging starts it is committed and
# lands even if you leave, but only a ball its rings contain feels it.
func _step_pulse(delta: float, inside: bool) -> void:
	if _charging:
		_charge_time += delta
		var ring := telegraph()
		if ring != null:
			ring.set_progress(_charge_time / PULSE_TELEGRAPH)
		if is_instance_valid(_core_ring):
			_core_ring.set_progress(_charge_time / PULSE_TELEGRAPH)
		if _charge_time >= PULSE_TELEGRAPH:
			_pulse()
		return
	if not inside:
		return
	_pulse_clock += delta
	if _pulse_clock >= PULSE_CYCLE - PULSE_TELEGRAPH:
		_charging = true
		_charge_time = 0.0
		_commit_ring(Threat.Type.INSTANT, global_position, reach, LIFT_REACH_UP, Palette.SAND)
		_core_ring = Telegraph.ring(world_root, terrain, Threat.Type.INSTANT, global_position, CORE_RADIUS)


func _pulse() -> void:
	var ball := _ball()
	var ring := telegraph()
	last_pulse_lifted = ring != null and ring.contains(ball)
	if last_pulse_lifted:
		target.add_external_accel(Vector3.UP * PULSE_LIFT / get_physics_process_delta_time())
	if is_instance_valid(_core_ring) and _core_ring.contains(ball):
		hit_player.emit(PULSE_DAMAGE, Vector3.ZERO)
	pulses += 1
	min_pulse_telegraph = minf(min_pulse_telegraph, _charge_time)
	_since_pulse = 0.0
	_charging = false
	_pulse_clock = 0.0
	_clear_telegraph()
	if is_instance_valid(_core_ring):
		_core_ring.queue_free()
	_core_ring = null


func _step_magnet(delta: float, inside: bool) -> void:
	match magnet_state:
		Magnet.IDLE:
			if not inside:
				return
			_magnet_clock += delta
			if _magnet_clock >= MAGNET_CYCLE - MAGNET_TELEGRAPH:
				var to := _flat_to_ball()
				_magnet_dir = to.normalized() if to.length() > 0.1 else Vector3.FORWARD
				magnet_state = Magnet.TELEGRAPH
				_magnet_time = 0.0
				_magnet_ring = Telegraph.wedge(world_root, terrain, Threat.Type.LANE, global_position + _magnet_dir * MAGNET_ARM, _magnet_dir,
						reach, MAGNET_WEDGE_DEG, LIFT_REACH_UP)
		Magnet.TELEGRAPH:
			_magnet_time += delta
			if is_instance_valid(_magnet_ring):
				_magnet_ring.set_progress(_magnet_time / MAGNET_TELEGRAPH)
			if _magnet_time >= MAGNET_TELEGRAPH:
				magnet_state = Magnet.TUG
				_magnet_time = 0.0
		Magnet.TUG:
			_magnet_time += delta
			var ball := _ball()
			if is_instance_valid(_magnet_ring) and _magnet_ring.contains(ball):
				var to := -_flat_to_ball()
				if to.length() > 0.5:
					target.add_external_accel(to.normalized() * MAGNET_PULL)
			if _magnet_time >= MAGNET_TUG:
				_end_magnet()


func _end_magnet() -> void:
	magnet_state = Magnet.IDLE
	_magnet_clock = 0.0
	_magnet_time = 0.0
	if is_instance_valid(_magnet_ring):
		_magnet_ring.queue_free()
	_magnet_ring = null


func _exit_tree() -> void:
	super._exit_tree()
	for node in [_core_ring, _magnet_ring]:
		if is_instance_valid(node):
			node.queue_free()


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = HALF_HEIGHT * 2.0
	shape.shape = cylinder
	add_child(shape)
	# Everything seen is in warden_look.gd and collides with nothing; this node keeps the
	# collider above and every number the fight uses.
	_look = WardenLook.new()
	add_child(_look)
	_look.build(self, HALF_HEIGHT)
	_base_color = Palette.CHARCOAL
	_material = _look.body_material
	_cap_material = _look.cap_material()


func _pose(_delta: float) -> void:
	pass


func _process(delta: float) -> void:
	if _look != null:
		_look.update(delta)


# --- Read by the look --------------------------------------------------------------

func charge_fraction() -> float:
	return clampf(_charge_time / PULSE_TELEGRAPH, 0.0, 1.0) if _charging else 0.0


# 0 when the magnet is stowed, rising to 1 through its telegraph, 1 through the tug.
func magnet_out() -> float:
	match magnet_state:
		Magnet.TELEGRAPH:
			return clampf(_magnet_time / MAGNET_TELEGRAPH, 0.0, 1.0)
		Magnet.TUG:
			return 1.0
	return 0.0


func magnet_dir() -> Vector3:
	return _magnet_dir


func flat_to_ball() -> Vector3:
	return _flat_to_ball() if target != null else Vector3.ZERO


func integrity() -> float:
	return clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0


# Combat's shred on this Warden (combat.gd owns the number and pushes it every tick).
func set_shred(amount: float) -> void:
	shred = amount


# The share of the plating stripped right now, 0 to 1.
func shred_fraction() -> float:
	return clampf(shred / plating, 0.0, 1.0) if plating > 0.0 else 0.0
