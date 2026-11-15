extends "res://src/combat/enemy.gd"

const TelegraphRecord := preload("res://src/combat/telegraph_record.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")

# The lobber stands and shells. Its job is to make a predictable line expensive: its
# muzzle glows for TELEGRAPH seconds, then it commits a landing ring LEAD of the way
# along your held line (half the ball's FLIGHT travel, DESIGN-NOTES rule 12), and the
# shell lands there FLIGHT seconds later. Only that ring hurts (projectile.gd), so a
# change of line or a jump beats it at any speed.

const CYCLE := 3.6
const TELEGRAPH := 1.3
const FLIGHT := 1.9
const SHOT_RANGE := 75.0
const LEAD := 0.5
const HP := 26.0
const SCRAP := 4
const BODY_PAINT := Palette.RUST

signal fired(origin: Vector3, landing: Vector3, flight: float)
# Emitted right after fired, once the shell exists: the shell's own committed landing-ring
# descriptor ({} if nothing took the shot). The attack facts read it; nothing else does.
signal released(ring: Dictionary)

var shots := 0
# The wind-up, 0 to 1: the value the muzzle glow is drawn from and the attack facts read.
var charge := 0.0
var recovery_seconds := TelegraphRecord.RECOVERY
var recover_left := 0.0

var _clock := 0.0
var _muzzle: MeshInstance3D
var _muzzle_material: StandardMaterial3D
# Test control: only the body pose is disabled; bulb, attack and reactions still run.
var windup_pose_enabled := true
var _cart: Node3D
var _barrel: MeshInstance3D
var _cart_rest := Transform3D.IDENTITY
var _barrel_rest := Transform3D.IDENTITY

const TUBE_RAISE := deg_to_rad(26.0)
const CART_SETTLE := deg_to_rad(4.0)
const POSE_RECOVERY := 0.28


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = "lobber"
	_set_health(HP * threat)
	scrap_value = SCRAP
	weight = 3.0
	radius = 1.3
	half_height = 2.0

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 4.0, 2.4)
	shape.shape = box
	add_child(shape)
	# C11 correction: _base_color is the event/UI colour (the hit flash lerps from it), so it stays
	# verdigris; the resting body paints Fleet oxide (the Chaser's RUST) through BODY_PAINT.
	_base_color = Palette.VERDIGRIS
	_material = Palette.solid(BODY_PAINT)
	# The C11 mortar cart (enemy_lobber.glb): a braced tower on wheels under a loading bulb and a
	# stout leaning tube. LobberBody carries the flashing body material as its paint surface; the
	# bulb is the muzzle, and _show_charge swells and lights it exactly as before.
	_muzzle_material = Palette.solid(Palette.HAZARD, 0.2)
	var dressing := Node3D.new()
	dressing.name = "LobberBody"
	_visual_parent().add_child(dressing)
	_cart = dressing
	_cart_rest = dressing.transform
	for part in _parts():
		var mi := MeshInstance3D.new()
		mi.name = part.name
		mi.mesh = part.mesh
		mi.transform = part.xform
		if part.bulb:
			mi.name = "LobberBulb"
			mi.set_surface_override_material(0, _muzzle_material)
			_visual_parent().add_child(mi)
			_muzzle = mi
		else:
			mi.set_surface_override_material(part.body, _material)
			dressing.add_child(mi)
			if part.name == "LobberBarrel":
				_barrel = mi
				_barrel_rest = mi.transform


static var _warned_asset := false
static var _shared: Array = []


# The glb is read once; every lobber shares its meshes and carries only its own flashing
# body and muzzle materials as surface overrides.
static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var scene := (load(ModelVariants.path("res://assets/models/world_one/enemy_lobber.glb")) as PackedScene).instantiate()
	var charcoal := Palette.solid(Palette.CHARCOAL)
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate()
		var body := 0
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("lobber: surface has no material; using default finish")
			var slot := surface_material.resource_name if surface_material != null else ""
			if slot == "fleet_paint":
				body = i
			mesh.surface_set_material(i, charcoal)
		_shared.append({"name": String(mi.name), "mesh": mesh, "xform": mi.transform, "body": body, "bulb": mi.name.begins_with("LobberBulb")})
	scene.free()
	return _shared


# The resting look ends on the Fleet oxide body paint, not the verdigris event colour.
func _apply_rest_look() -> void:
	super()
	if _material != null:
		_material.albedo_color = BODY_PAINT


func muzzle_point() -> Vector3:
	return global_position + Vector3.UP * 2.6


func recovering() -> bool:
	return recover_left > 0.0


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	_move(delta, Vector3.ZERO)
	if not _in_play() or target == null or not is_on_floor():
		_pose(0.0)
		return
	var to_ball: Vector3 = _ball() - global_position
	if to_ball.length() > SHOT_RANGE:
		_clock = 0.0
		_show_charge(0.0)
		return
	_clock += delta
	# Clocked out (its Foreman fell): the muzzle does not start to glow; a glow already lit fires.
	if charge <= 0.0 and AttackBudget.clocked_out(self):
		_clock = minf(_clock, CYCLE - TELEGRAPH)
	if recovering():
		recover_left = maxf(0.0, recover_left - delta)
		_show_charge(0.0)
		return
	_show_charge(clampf((_clock - (CYCLE - TELEGRAPH)) / TELEGRAPH, 0.0, 1.0))
	if _clock < CYCLE:
		return
	_clock = 0.0
	_show_charge(0.0)
	var lead: Vector3 = target.planar_velocity() * FLIGHT * clampf(float(spec.get("lead", LEAD)), 0.0, 1.0)
	var aim: Vector3 = _ball() + lead
	var landing := Vector3(aim.x, Telegraph.ground_under(terrain, aim), aim.z)
	shots += 1
	# _show_charge(0) retains the bulb's original release behavior. The body reaches
	# its full e02_tube_raise pose on this same frame, before either release signal.
	_pose(1.0)
	recover_left = recovery_seconds
	fired.emit(muzzle_point(), landing, FLIGHT)
	released.emit(_shell_ring())


# The descriptor of the ring the shell just committed: the newest of this lobber's shells.
func _shell_ring() -> Dictionary:
	var shells := get_tree().get_nodes_in_group("enemy_shot")
	for i in range(shells.size() - 1, -1, -1):
		var shell = shells[i]
		if shell.get("lobber") == self and is_instance_valid(shell.get("ring")):
			return shell.ring.descriptor()
	return {}


func _show_charge(value: float) -> void:
	charge = value
	_muzzle_material.emission_energy_multiplier = FlashGuard.spike(0.8, 0.8 + value * 5.0)
	_muzzle.scale = Vector3.ONE * (1.0 + value * 0.9)
	_pose()


# e02_tube_raise uses only the existing charge and cycle clock. The cart and barrel
# are below ReactionPivot; their local transforms never replace its hit/line lean.
func _pose(progress := -1.0) -> void:
	if _cart == null or _barrel == null:
		return
	_cart.transform = _cart_rest
	_barrel.transform = _barrel_rest
	if not windup_pose_enabled or _dead or not _in_play() or not is_instance_valid(target) or not is_on_floor() or _line_lean_goal < 0.0:
		return
	if (_ball() - global_position).length() > SHOT_RANGE:
		return
	var lift := smoothstep(0.0, 1.0, charge if progress < 0.0 else progress)
	var kick := 0.0
	var rock := 0.0
	if progress < 0.0 and charge == 0.0 and shots > 0 and _clock < POSE_RECOVERY:
		var recovery := clampf(_clock / POSE_RECOVERY, 0.0, 1.0)
		lift = 1.0 - smoothstep(0.0, 1.0, recovery)
		kick = sin(PI * recovery) * 0.24
		rock = sin(TAU * recovery) * deg_to_rad(5.0) * (1.0 - recovery)
	# Rock about the rear wheel axle rather than sliding the enemy or its collider.
	var axle := Vector3(0.0, -1.5, -0.68)
	var cart_turn := Basis(Vector3.RIGHT, -CART_SETTLE * lift + rock)
	_cart.transform = Transform3D(cart_turn, axle - cart_turn * axle) * _cart_rest
	_barrel.transform = _barrel_rest * Transform3D(Basis(Vector3.RIGHT, -TUBE_RAISE * lift), Vector3.ZERO)
	_barrel.position -= (_barrel.basis * Vector3(0.0, cos(0.35), sin(0.35))) * kick


func _die() -> void:
	_pose(0.0)
	super._die()


func _exit_tree() -> void:
	_pose(0.0)
	super._exit_tree()
