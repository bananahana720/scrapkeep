extends "res://src/combat/enemy.gd"

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
#   - "magnet": every MAGNET_CYCLE it swings a magnet arm toward you, telegraphs for
#     MAGNET_TELEGRAPH, then tugs you toward it at MAGNET_PULL m/s^2 for MAGNET_TUG.
#     A weapon hit on the magnet during the tug drops the Warden's plating to 0 for
#     UNPLATE_SECONDS and ends the tug.

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
const MAGNET_PULL := 6.0
const MAGNET_ARM := 3.8
const MAGNET_RADIUS := 1.1
const UNPLATE_SECONDS := 3.0
const WEAPON_KINDS := ["runner", "arc", "turret"]
const CONTACT_KINDS := ["stomp", "slam"]

enum Magnet { IDLE, TELEGRAPH, TUG }

var stage := 1
var lesson := "plate"
var reach := DEFAULT_REACH
var pulses := 0
var min_pulse_telegraph := INF
var magnet_stuns := 0
var magnet_state := Magnet.IDLE

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
var _caps: Array = []
var _cap_material: StandardMaterial3D
var _arm: Node3D
var _magnet_material: StandardMaterial3D
var _core_material: StandardMaterial3D


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
	if lesson == "magnet" and magnet_state != Magnet.IDLE:
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
	return global_position + _magnet_dir * MAGNET_ARM + Vector3.UP * 1.0


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
		_commit_ring(global_position, reach, LIFT_REACH_UP)
		_core_ring = Telegraph.ring(world_root, terrain, global_position, CORE_RADIUS)


func _pulse() -> void:
	var ball := _ball()
	var ring := telegraph()
	if ring != null and ring.contains(ball):
		target.add_external_accel(Vector3.UP * PULSE_LIFT * Engine.physics_ticks_per_second)
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
				_magnet_ring = Telegraph.ring(world_root, terrain, global_position, reach, LIFT_REACH_UP)
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
	_base_color = Palette.CHARCOAL
	_material = Palette.solid(_base_color)
	var body := MeshInstance3D.new()
	var inner := CylinderMesh.new()
	inner.top_radius = RADIUS * 0.8
	inner.bottom_radius = RADIUS * 0.9
	inner.height = HALF_HEIGHT * 2.0
	body.mesh = inner
	body.material_override = _material
	add_child(body)
	# The clamp's plating: four jaws around the mast, tinted amber or slate.
	var plate_mat := _plate_material()
	for i in 4:
		var jaw := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(RADIUS * 1.1, HALF_HEIGHT * 1.8, 0.7)
		jaw.mesh = box
		jaw.material_override = plate_mat
		var angle := TAU * i / 4.0 + PI * 0.25
		jaw.position = Vector3(cos(angle), 0.0, sin(angle)) * (RADIUS - 0.2)
		jaw.rotation.y = -angle + PI * 0.5
		add_child(jaw)
	_core_material = Palette.solid(Palette.ARC, 1.5)
	var core := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS * 0.85
	torus.outer_radius = RADIUS * 1.05
	core.mesh = torus
	core.material_override = _core_material
	core.position = Vector3.UP * (HALF_HEIGHT - 0.3)
	add_child(core)
	if lesson == "caps":
		_cap_material = Palette.solid(Palette.SAND, 1.5)
		for cap in cap_points():
			var mesh := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = CAP_RADIUS
			disc.bottom_radius = CAP_RADIUS * 1.2
			disc.height = 0.6
			mesh.mesh = disc
			mesh.material_override = _cap_material
			mesh.position = cap - global_position
			add_child(mesh)
			_caps.append(mesh)
	if lesson == "magnet":
		_magnet_material = Palette.solid(Palette.SAND, 0.3)
		_arm = MeshInstance3D.new()
		var head := SphereMesh.new()
		head.radius = MAGNET_RADIUS
		head.height = MAGNET_RADIUS * 2.0
		(_arm as MeshInstance3D).mesh = head
		(_arm as MeshInstance3D).material_override = _magnet_material
		add_child(_arm)


# The magnet swings out and glows through its telegraph and burns bright during the
# tug, the moment a shot on it counts; the core ring dims while the plating is off.
func _pose(delta: float) -> void:
	if _cap_material != null:
		_cap_material.emission_energy_multiplier = move_toward(_cap_material.emission_energy_multiplier, 1.5, delta * 8.0)
	if _core_material != null:
		_core_material.emission_energy_multiplier = 0.3 if _unplated > 0.0 else 1.5
	if _arm == null:
		return
	var out := 0.0
	var glow := 0.3
	match magnet_state:
		Magnet.TELEGRAPH:
			out = clampf(_magnet_time / MAGNET_TELEGRAPH, 0.0, 1.0)
			glow = 1.0 + 2.0 * out
		Magnet.TUG:
			out = 1.0
			glow = 5.0
	_arm.position = (_magnet_dir * MAGNET_ARM * out + Vector3.UP * 1.0) if out > 0.0 else Vector3.UP * (HALF_HEIGHT + 0.4)
	_magnet_material.emission_energy_multiplier = glow
