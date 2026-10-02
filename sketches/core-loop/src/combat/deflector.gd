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


# C17 dressing (enemy_deflector.glb). The counter's capsule crew, head, ears and tag and the base
# disc and torus are replaced by the glb's crew behind one concave dish whose bead rim is the
# rebound edge. The dish sits where the base disc did (0, 0.2, CREW_RADIUS + 0.6), so it still turns
# with the enemy's yaw toward the ball (_facing, at commit); the lane the mechanic throws through
# is committed by _commit below, untouched. The glb is read once; every deflector shares its mesh
# and adds only its own flashing body material as a surface override. The resting body is the
# Fleet oxide _add_capsule already set (RUST), so the hit flash and the event colour are unchanged.
static var _shared: Dictionary = {}


func _build_tool() -> void:
	_crew.free()
	_crew = null
	var parts := _parts()
	_dish = Node3D.new()
	_dish.name = "DeflectorBody"
	_visual_parent().add_child(_dish)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = parts["body"]
	body.set_surface_override_material(parts["flash"], _material)
	_dish.add_child(body)


static func _parts() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	var scene := (load("res://assets/models/world_one/enemy_deflector.glb") as PackedScene).instantiate()
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	var flash := 0
	var mesh: Mesh = (scene.find_child("DeflectorBody", true, false) as MeshInstance3D).mesh.duplicate()
	for i in mesh.get_surface_count():
		if mesh.surface_get_material(i).resource_name == "fleet_paint":
			flash = i
		mesh.surface_set_material(i, painted)
	_shared = {"body": mesh, "flash": flash}
	scene.free()
	return _shared


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
