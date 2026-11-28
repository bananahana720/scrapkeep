extends "res://src/combat/enemy.gd"

const TelegraphRecord := preload("res://src/combat/telegraph_record.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")

const CYCLE := 3.6
const TELEGRAPH := 1.3
const FLIGHT := 1.9
const SHOT_RANGE := 75.0
const LEAD := 0.5
const HP := 26.0
const SCRAP := 4
const BODY_PAINT := Palette.RUST
const CLUSTER_RANGE := 10.0
const CLUSTER_COVER_RANGE := 28.0
const CLUSTER_COVER_SPEED := 9.0
const CLUSTER_TELEGRAPH := 0.85
const CLUSTER_SPREAD_DEG := 35.0
const CLUSTER_COUNT := 3
const CLUSTER_FLIGHT := 1.15
const CLUSTER_MIN_DIST := 4.0
const CLUSTER_MAX_DIST := 14.0
const CHAIN_BLAST_RADIUS := 7.0
const CHAIN_BLAST_DAMAGE := 40.0
const CHAIN_BAT_MIN_SPEED := 14.0
const COVER_MASK := PhysicsLayers.WORLD_MASK

signal fired(origin: Vector3, landing: Vector3, flight: float)
signal released(ring: Dictionary)

var shots := 0
var cluster_shots := 0
var chain_detonations := 0
var charge := 0.0
var recovery_seconds := TelegraphRecord.RECOVERY
var recover_left := 0.0

var _clock := 0.0
var _cluster_active := false
var _cluster_clock := 0.0
var _cluster_dir := Vector3.FORWARD
var _cluster_dist := 8.0
var _cluster_tele: Node3D
var _muzzle: MeshInstance3D
var _muzzle_material: StandardMaterial3D
var windup_pose_enabled := true
var _cart: Node3D
var _barrel: MeshInstance3D
var _cart_rest := Transform3D.IDENTITY
var _barrel_rest := Transform3D.IDENTITY
var _muzzle_at_rest := false
var _parts_off_rest := false

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
	_base_color = Palette.VERDIGRIS
	_material = Palette.solid(BODY_PAINT)
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


func _apply_rest_look() -> void:
	super()
	if _material != null:
		_material.albedo_color = BODY_PAINT


func muzzle_point() -> Vector3:
	return global_position + Vector3.UP * 2.6


func recovering() -> bool:
	return recover_left > 0.0


func is_clustering() -> bool:
	return _cluster_active


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	_move(delta, Vector3.ZERO)
	if not _in_play() or target == null or not is_on_floor():
		if _cluster_active:
			_cancel_cluster()
		else:
			AttackBudget.withdraw(self)
		_pose(0.0)
		return
	var to_ball: Vector3 = _ball() - global_position
	if to_ball.length_squared() > SHOT_RANGE * SHOT_RANGE:
		if _cluster_active:
			_cancel_cluster()
		else:
			AttackBudget.withdraw(self)
		_clock = 0.0
		_show_charge(0.0)
		return
	if _cluster_active:
		_step_cluster(delta)
		return
	_clock += delta
	if charge <= 0.0 and AttackBudget.clocked_out(self):
		AttackBudget.withdraw(self)
		_clock = minf(_clock, CYCLE - TELEGRAPH)
	if recovering():
		AttackBudget.withdraw(self)
		recover_left = maxf(0.0, recover_left - delta)
		_show_charge(0.0)
		return
	if charge <= 0.0 and _clock >= CYCLE - TELEGRAPH and _wants_cluster(to_ball):
		if AttackBudget.ask(self):
			_begin_cluster(to_ball)
		else:
			_clock = CYCLE - TELEGRAPH
		return
	AttackBudget.withdraw(self)
	_show_charge(clampf((_clock - (CYCLE - TELEGRAPH)) / TELEGRAPH, 0.0, 1.0))
	if _clock < CYCLE:
		return
	_clock = 0.0
	_show_charge(0.0)
	var lead: Vector3 = target.planar_velocity() * FLIGHT * clampf(float(spec.get("lead", LEAD)), 0.0, 1.0)
	var aim: Vector3 = _ball() + lead
	var landing := Vector3(aim.x, Telegraph.ground_under(terrain, aim), aim.z)
	shots += 1
	_pose(1.0)
	recover_left = recovery_seconds
	fired.emit(muzzle_point(), landing, FLIGHT)
	released.emit(_shell_ring())


func _wants_cluster(to_ball: Vector3) -> bool:
	var flat_dist := Vector2(to_ball.x, to_ball.z).length()
	if flat_dist < CLUSTER_RANGE:
		return true
	if flat_dist > CLUSTER_COVER_RANGE:
		return false
	var speed := 0.0
	if target != null and target.has_method("planar_velocity"):
		var pv: Vector3 = target.planar_velocity()
		speed = Vector2(pv.x, pv.z).length()
	if speed >= CLUSTER_COVER_SPEED:
		return false
	return _behind_cover()


func _behind_cover() -> bool:
	if not is_inside_tree() or get_world_3d() == null:
		return false
	var from := muzzle_point()
	var to := _ball() + Vector3.UP * 0.5
	if from.distance_to(to) < 2.5:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to, COVER_MASK)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	return (hit["position"] as Vector3).distance_to(to) > 2.0


func _begin_cluster(to_ball: Vector3) -> void:
	_cluster_active = true
	_cluster_clock = 0.0
	var flat := Vector3(to_ball.x, 0.0, to_ball.z)
	_cluster_dir = flat.normalized() if flat.length() > 0.05 else Vector3.FORWARD
	_cluster_dist = clampf(flat.length(), CLUSTER_MIN_DIST, CLUSTER_MAX_DIST)
	_clear_cluster_tele()
	_cluster_tele = Telegraph.secondary_wedge(world_root, terrain, Threat.Type.INSTANT, global_position,
		_cluster_dir, _cluster_dist + 3.0, CLUSTER_SPREAD_DEG * 0.5 + 6.0, CLUSTER_TELEGRAPH)
	_cluster_tele.owner_voice = "clank"
	_cluster_tele.mechanic_tag = "vault_rise"
	if world_root != null and is_inside_tree():
		FxLibrary.burst(world_root, "steam_puff", muzzle_point(), 6)


func _step_cluster(delta: float) -> void:
	_cluster_clock += delta
	var prog := clampf(_cluster_clock / CLUSTER_TELEGRAPH, 0.0, 1.0)
	_show_charge(prog)
	if is_instance_valid(_cluster_tele):
		_cluster_tele.set_progress(prog)
	if _cluster_clock < CLUSTER_TELEGRAPH:
		return
	_fire_cluster()


func _fire_cluster() -> void:
	_clear_cluster_tele()
	_cluster_active = false
	_cluster_clock = 0.0
	_clock = 0.0
	_show_charge(0.0)
	_pose(1.0)
	recover_left = recovery_seconds
	AttackBudget.release(self)
	var half_rad := deg_to_rad(CLUSTER_SPREAD_DEG * 0.5)
	var bungs: Array = []
	var before_ids := {}
	if is_inside_tree():
		for s in get_tree().get_nodes_in_group(Groups.ENEMY_SHOT):
			before_ids[s.get_instance_id()] = true
	var dist := _cluster_dist
	if target != null:
		var now_flat := Vector3(_ball().x - global_position.x, 0.0, _ball().z - global_position.z)
		if now_flat.length() > 1.0:
			dist = clampf(now_flat.length(), CLUSTER_MIN_DIST, CLUSTER_MAX_DIST)
	for i in CLUSTER_COUNT:
		var frac := (float(i) / float(maxi(CLUSTER_COUNT - 1, 1))) * 2.0 - 1.0
		var dir := _cluster_dir.rotated(Vector3.UP, half_rad * frac)
		var aim := global_position + dir * dist
		var landing := Vector3(aim.x, Telegraph.ground_under(terrain, aim), aim.z)
		fired.emit(muzzle_point(), landing, CLUSTER_FLIGHT)
	if is_inside_tree():
		for s in get_tree().get_nodes_in_group(Groups.ENEMY_SHOT):
			if not before_ids.has(s.get_instance_id()) and s.get("lobber") == self:
				bungs.append(s)
	shots += 1
	cluster_shots += 1
	released.emit(_shell_ring())
	if bungs.size() >= 2 and world_root != null and is_inside_tree():
		var watcher := ClusterWatcher.new()
		watcher.name = "BungClusterWatcher"
		world_root.add_child(watcher)
		watcher.bind(self, bungs, target, world_root)


func _cancel_cluster() -> void:
	_cluster_active = false
	_cluster_clock = 0.0
	_clear_cluster_tele()
	AttackBudget.release(self)
	AttackBudget.withdraw(self)
	AttackBudget.release(self)
	AttackBudget.withdraw(self)


func _clear_cluster_tele() -> void:
	if is_instance_valid(_cluster_tele):
		_cluster_tele.queue_free()
	_cluster_tele = null


class ClusterWatcher extends Node:
	var _lobber: WeakRef
	var _bungs: Array = []
	var _target
	var _root: Node
	var _chained := false

	func bind(owner_lobber: Node3D, bungs: Array, target_ref, root_ref: Node) -> void:
		_lobber = weakref(owner_lobber)
		_target = target_ref
		_root = root_ref
		for b in bungs:
			_bungs.append(weakref(b))

	func _physics_process(_delta: float) -> void:
		var alive: Array = []
		var any_returned := false
		for ref in _bungs:
			var shell = (ref as WeakRef).get_ref()
			if shell != null and is_instance_valid(shell):
				alive.append(shell)
				if bool(shell.get("returned")):
					any_returned = true
		if alive.is_empty():
			queue_free()
			return
		if any_returned and not _chained:
			if _bat_was_fast():
				_trigger_chain(alive)
			else:
				_chained = true

	func _bat_was_fast() -> bool:
		if _target == null:
			return false
		var player = _target.get("player") if "player" in _target else _target
		if player == null or not is_instance_valid(player) or not player.has_method("planar_velocity"):
			return false
		var pv: Vector3 = player.planar_velocity()
		return Vector2(pv.x, pv.z).length() >= CHAIN_BAT_MIN_SPEED

	func _trigger_chain(alive: Array) -> void:
		_chained = true
		var owner_lobber = _lobber.get_ref() if _lobber != null else null
		if owner_lobber != null and is_instance_valid(owner_lobber):
			owner_lobber.chain_detonations += 1
		for shell in alive:
			if not bool(shell.get("returned")) and shell.has_method("bat"):
				shell.bat()
			if shell.has_signal("returned_landed") and not shell.returned_landed.is_connected(_on_chain_landed):
				shell.returned_landed.connect(_on_chain_landed, CONNECT_ONE_SHOT)

	func _on_chain_landed(shell: Node3D) -> void:
		if not is_inside_tree():
			return
		var at: Vector3 = shell.landing if "landing" in shell else shell.global_position
		if _root != null and is_instance_valid(_root):
			FxLibrary.burst(_root, "brass_spark", at, 12)
			FxLibrary.burst(_root, "spark_core", at, 12, Palette.AMBER)
		var combat = _target.get("combat") if _target != null and "combat" in _target else null
		for enemy in get_tree().get_nodes_in_group(GROUP):
			if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
				continue
			var offset: Vector3 = enemy.global_position - at
			if Vector2(offset.x, offset.z).length() > CHAIN_BLAST_RADIUS:
				continue
			var push := Vector3(offset.x, 0.0, offset.z)
			push = push.normalized() if push.length() > 0.05 else Vector3.FORWARD
			if enemy.has_method("knock"):
				enemy.knock(push + Vector3.UP * 0.35, 10.0)
			if combat != null and is_instance_valid(combat) and combat.has_method("strike"):
				combat.strike(enemy, "shell", CHAIN_BLAST_DAMAGE)
			elif enemy.has_method("take_damage"):
				enemy.take_damage(CHAIN_BLAST_DAMAGE)


func _shell_ring() -> Dictionary:
	var shells := get_tree().get_nodes_in_group(Groups.ENEMY_SHOT)
	for i in range(shells.size() - 1, -1, -1):
		var shell = shells[i]
		if shell.get("lobber") == self and is_instance_valid(shell.get("ring")):
			return shell.ring.descriptor()
	return {}


func _show_charge(value: float) -> void:
	charge = value
	if value <= 0.0:
		if not _muzzle_at_rest:
			_muzzle_at_rest = true
			_muzzle_material.emission_energy_multiplier = FlashGuard.spike(0.8, 0.8)
			_muzzle.scale = Vector3.ONE
	else:
		_muzzle_at_rest = false
		_muzzle_material.emission_energy_multiplier = FlashGuard.spike(0.8, 0.8 + value * 5.0)
		_muzzle.scale = Vector3.ONE * (1.0 + value * 0.9)
	_pose()


func _reset_parts() -> void:
	if not _parts_off_rest:
		return
	_parts_off_rest = false
	_cart.transform = _cart_rest
	_barrel.transform = _barrel_rest


func _pose(progress := -1.0) -> void:
	if _cart == null or _barrel == null:
		return
	if not windup_pose_enabled or _dead or not _in_play() or not is_instance_valid(target) or not is_on_floor() or _line_lean_goal < 0.0:
		_reset_parts()
		return
	if (_ball() - global_position).length_squared() > SHOT_RANGE * SHOT_RANGE:
		_reset_parts()
		return
	var lift := smoothstep(0.0, 1.0, charge if progress < 0.0 else progress)
	var kick := 0.0
	var rock := 0.0
	if progress < 0.0 and charge == 0.0 and shots > 0 and _clock < POSE_RECOVERY:
		var recovery := clampf(_clock / POSE_RECOVERY, 0.0, 1.0)
		lift = 1.0 - smoothstep(0.0, 1.0, recovery)
		kick = sin(PI * recovery) * 0.24
		rock = sin(TAU * recovery) * deg_to_rad(5.0) * (1.0 - recovery)
	if lift == 0.0 and kick == 0.0 and rock == 0.0:
		_reset_parts()
		return
	_parts_off_rest = true
	var axle := Vector3(0.0, -1.5, -0.68)
	var cart_turn := Basis(Vector3.RIGHT, -CART_SETTLE * lift + rock)
	_cart.transform = Transform3D(cart_turn, axle - cart_turn * axle) * _cart_rest
	_barrel.transform = _barrel_rest * Transform3D(Basis(Vector3.RIGHT, -TUBE_RAISE * lift), Vector3.ZERO)
	_barrel.position -= (_barrel.basis * Vector3(0.0, cos(0.35), sin(0.35))) * kick


func _die() -> void:
	_cancel_cluster()
	_pose(0.0)
	super._die()


func _exit_tree() -> void:
	_cancel_cluster()
	_pose(0.0)
	super._exit_tree()
