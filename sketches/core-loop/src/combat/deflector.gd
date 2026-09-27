extends "res://src/combat/counter.gd"

const Augments := preload("res://src/movement/augments.gd")

# The deflector (DESIGN-V2 section 10.6): a crew figure behind a big curved dish shield.
# It braces the dish toward the ball, and the warning is a lane out from the dish's
# face: the zone it will throw you back from. Braced, a ball in that zone rolling into
# the face is reflected across the dish's normal at RESTITUTION 0.9, through the CC
# door, so you lose your line but keep most of your speed. The counterplay is the
# opportunity: jump within VAULT_WINDOW of the rebound and it becomes a vault for any
# class, exit speed incoming x 1.8 (the vault kick's gain), with the break refund.
# Rivet's sprint ignores the dish and rolls through.

const RESTITUTION := 0.9
const FACE_LENGTH := 6.0
const FACE_WIDTH := 5.0
const MIN_CLOSING := 3.0
const VAULT_WINDOW := 0.45
const VAULT_LIFT := 0.35
const HP := 60.0

var rebounds := 0
var vaults := 0
var last_vault_speed := 0.0
var _window := 0.0
var _rebound_v := Vector3.ZERO
var _dish: Node3D


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 5
	weight = 2.0
	walk_speed = 2.6
	keep_near = 7.0
	keep_far = 20.0
	attack_range = 16.0
	warn_seconds = 0.9
	live_seconds = 2.6
	rest_seconds = 2.5


func _build_tool() -> void:
	_dish = Node3D.new()
	_dish.position = Vector3(0.0, 0.2, CREW_RADIUS + 0.6)
	add_child(_dish)
	var face := CylinderMesh.new()
	face.top_radius = 1.9
	face.bottom_radius = 1.5
	face.height = 0.3
	var disc := MeshInstance3D.new()
	disc.mesh = face
	disc.rotation.x = PI * 0.5
	disc.material_override = Palette.solid(Palette.CHARCOAL.lightened(0.2), 0.0)
	_dish.add_child(disc)
	var rim := TorusMesh.new()
	rim.inner_radius = 1.75
	rim.outer_radius = 1.95
	var ring := MeshInstance3D.new()
	ring.mesh = rim
	ring.rotation.x = PI * 0.5
	ring.position = Vector3(0.0, 0.0, 0.18)
	ring.material_override = Palette.solid(Palette.BRASS, 0.4)
	_dish.add_child(ring)


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	var face := global_position + to_ball.normalized() * (CREW_RADIUS + 0.6)
	return _commit_lane(Threat.Type.LANE, face, to_ball, FACE_LENGTH, FACE_WIDTH, 2.5)


func _go_live() -> void:
	_window = 0.0
	if holds != null and not holds.ctx.events.jumped.is_connected(_on_jumped):
		holds.ctx.events.jumped.connect(_on_jumped)


func _live(delta: float) -> bool:
	var face := telegraph()
	if face == null:
		return false
	_window = maxf(0.0, _window - delta)
	if rebounds > 0 and _window <= 0.0 and _rebound_v != Vector3.ZERO:
		return false
	if _rebound_v != Vector3.ZERO:
		return true
	var player = _player()
	var ball := _real_ball()
	if not face.contains(ball):
		return true
	var v: Vector3 = player.state.velocity
	var normal: Vector3 = face.dir
	var into := v.dot(normal)
	if into > -MIN_CLOSING:
		return true
	var out := v - normal * into * (1.0 + RESTITUTION)
	var step := get_physics_process_delta_time()
	if not player.crowd_control(String(row["mechanic"]), (out - v) / step):
		return true
	rebounds += 1
	_rebound_v = out
	_window = VAULT_WINDOW
	return true


func _on_jumped(_air: bool) -> void:
	if _window <= 0.0 or _rebound_v == Vector3.ZERO or phase != Phase.LIVE:
		return
	_window = 0.0
	var player = _player()
	var flat := Vector3(_rebound_v.x, 0.0, _rebound_v.z)
	var speed := Augments.vault_exit(_rebound_v.length(), player.tuning.f("jump_speed"))
	var dir := (flat.normalized() + Vector3.UP * VAULT_LIFT).normalized() if flat.length() > 0.1 else Vector3.UP
	player.set_velocity_now(dir * speed)
	vaults += 1
	last_vault_speed = speed
	holds.gift_refund()
	holds.ctx.events.shield_vaulted.emit(player.ball_position(), speed)
	if fleet != null:
		fleet.discover("shield_vault", player.ball_position())


func _on_end() -> void:
	_rebound_v = Vector3.ZERO
	_window = 0.0


func _exit_tree() -> void:
	if holds != null and is_instance_valid(holds) and holds.ctx.events.jumped.is_connected(_on_jumped):
		holds.ctx.events.jumped.disconnect(_on_jumped)
	super._exit_tree()
