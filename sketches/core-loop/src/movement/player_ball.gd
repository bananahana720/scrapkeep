extends Node3D

const Tuning := preload("res://src/movement/tuning.gd")
const Rules := preload("res://src/movement/ball_rules.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const BallState := preload("res://src/movement/ball_state.gd")
const RigidBall := preload("res://src/movement/rigid_ball.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")
const Augments := preload("res://src/movement/augments.gd")
const AugmentKit := preload("res://src/movement/augment_kit.gd")
const Harpoon := preload("res://src/movement/harpoon.gd")
const Grip := preload("res://src/movement/grip.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Contact := preload("res://src/movement/contact.gd")
const Indicator := preload("res://src/movement/indicator.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const ChainState := preload("res://src/combat/chain.gd")
const Dunk := preload("res://src/combat/dunk.gd")
const Redline := preload("res://src/combat/redline.gd")
const ExceptionHold := preload("res://src/movement/exception_hold.gd")


const STOMP := "stomp"
const RAM := "ram"
const SLAM := "slam"
const BOW_REACH := 1.0
const CRUSH_PASS := 0.3
const STOMP_SPEED := 3.0
const CC_IGNORED_GAP_MS := 250
const FACE_TAG_REACH := 12.0
const FACE_TAG_SECONDS := 2.0
const FACE_TAG_RAYS := 16
const SKID_REACH := 10.0
const SKID_CONE := 0.35
const SKID_INNER := 1.5
const SKID_REFUND := 0.5
const REND_PULL := 0.8
const DRAG_SECONDS := 0.4
const AIM_CONE_LENGTH := 5.0
const AIM_CONE_HALF := 0.3
const AIM_CONE_CLEAR := 1.3
const DRY_FIRE_HOLD := 0.25
const LET_GO_HOLD := 0.15
const BROKE_HOLD := 0.3
const LANDS_HOLD := 0.1
const REFUSE_REST := 0.5
const SHATTER_MARGIN := 0.25

signal shockwave(position: Vector3, strength: float)
signal struck(enemy: Node3D, kind: String, force: float)

var tuning
var events
var state := BallState.new()
var kit := AugmentKit.new()
var abilities = kit.abilities
var tree = kit.tree
var class_def: Resource
var indicator: Node3D
var intent := Intent.new()
var source = Intent.Source.new()
var drive_basis := Basis.IDENTITY
var spawn_point := Vector3.ZERO
var builtin_squash := true
var crush_check := Callable()
var heft_of := Callable()
var enemy_heft_of := Callable()
var strike_damage := {}
var mass_of := Callable()
var pressure_grant := Callable()
var hulk_launch := Callable()
var interact_claim := Callable()
var talk_claim := Callable()
var face_tags: Array = []
var _cc_ignored_at := {}
var immune_left := 0.0
var _smashes := {}
var _drags := {}
var smash_landing: Node3D
var chain := ChainState.new()
var dunk := Dunk.new()
var redline := Redline.new()
var _landing_mult := 1.0
var set_piece_phase := Callable()
var line_load_of := Callable()
var _fire_latched := false
var _click_held := false

var _rigid
var _visual_root: Node3D
var _pod_mount: Node3D
var _juice: Node3D
var _mesh: MeshInstance3D
var _roll_mount: Node3D
var _wings: Node3D
var _wings_material: StandardMaterial3D
var _pylon: Node3D
var _plate: MeshInstance3D
var _roll := Basis.IDENTITY
const SPIN_AIR_DAMP := 0.25
const SPIN_HELD_DAMP := 2.5
var _spin_on := false
var _spin_basis := Basis.IDENTITY
var _spin_omega := Vector3.ZERO
var _spin_set_tick := -10
var _spin_held := false
var _spin_freeze := false
var _spin_offset := Basis.IDENTITY
var _frozen := false
var _was_hooked := false
var _brake_was_held := false
var _ctrl_claimed := false
var _line_state := ""
var _line_target = null
var _line_anchor := Vector3.ZERO
var _line_hold := 0.0
var _line_standing := false
var _bow: Area3D
var speed_bank := {}
var _speed_bank_airborne := false
var _speed_bank_jumped := false
enum BankMove { NONE, JUMP, SLIDE, SLIDE_FLIGHT }
var _speed_bank_chosen := BankMove.NONE
var _speed_bank_move_held := false
var _speed_bank_brake_held := false
var _speed_bank_rest_ticks := 0
var _speed_bank_rest_braked := false
var _bow_check_queued := false
var _crushing := {}
var exceptions
var _destructibles: Node = null
var _destructibles_class := Callable()
var air_draw_active := false
var air_draw_left := Augments.KEST_AIR_DRAW_MAX_S
var _kest_wall_kick_faces := {}
var _kest_wall_aim := {}
var last_kest_wall_kick := {}
var last_spire_vault := {}


func setup(tuning_ref, events_ref, spawn: Vector3) -> void:
	tuning = tuning_ref
	events = events_ref
	spawn_point = spawn

	_rigid = RigidBall.new()
	_rigid.name = "RigidBall"
	add_child(_rigid)
	exceptions = ExceptionHold.new(_rigid, Tuning.RADIUS)
	_rigid.setup(tuning, state)
	_rigid.intent = intent
	_rigid.kit = kit
	_rigid.velocity_setting.connect(_keep_spin)
	_rigid.teleporting.connect(_spin_clear)
	_rigid.enemy_touched.connect(_on_enemy_touched)
	_rigid.slammed.connect(_on_rigid_slammed)
	_rigid.pylon_planted.connect(_on_pylon_planted)
	_rigid.pylon_ejected.connect(func(v: Vector3): events.dismounted.emit(v))
	_rigid.jumped.connect(func(air: bool): events.jumped.emit(air))
	_rigid.boosted.connect(func(dir: Vector3): events.boosted.emit(dir))
	_rigid.kit_fact.connect(_on_kit_fact)
	tree.events = events
	tree.picked.connect(_on_tree_picked)
	events.enemy_killed.connect(func(_kind: String, _at: Vector3, _scrap: int): kit.rewind_left = 0.0)
	events.player_died.connect(func(): kit.drop_line("reset"))
	events.player_died.connect(func(): dunk.clear("reset"))
	events.stage_content_cleared.connect(func(_reason: String): dunk.clear("reset"))
	events.player_died.connect(func(): redline.clear())
	events.stage_entered.connect(func(_stage: int, _retry: bool): redline.clear())
	events.near_miss.connect(func(_kind: String, at: Vector3): redline.skim(state.tier, at))
	redline.cooked_off.connect(_redline_blast)
	redline.detonated.connect(_redline_blast)
	_smashes = {"arc": _smash_arc, "skid": _smash_skid, "demo": _smash_demo, "rend": _smash_rend, "stamp": _smash_stamp}
	events.run_started.connect(func(class_id: String):
		fit_class(ClassDef.by_id(class_id))
		chain.reset()
		redline.set_mode(tuning.option("heat"))
		redline.reset_counts()
		tree.world_one = tuning.world_one()
		tree.open_checkpoint())
	events.stage_entered.connect(func(_stage: int, _retry: bool): abilities.refill())
	events.stage_content_cleared.connect(func(_reason: String): abilities.refill())
	events.slot_cast.connect(func(_slot: String, _id: String, _at: Vector3): snap_slots("cast"))
	events.ultimate_started.connect(func(_id: String, _path: String, _from: Vector3, _to: Vector3, _seconds: float):
		snap_slots("ultimate"))
	events.stage_entered.connect(func(_stage: int, _retry: bool): snap_slots("reset"))
	events.stage_content_cleared.connect(func(_reason: String): snap_slots("reset"))
	events.player_died.connect(func(): snap_slots("reset"))
	events.run_ended.connect(func(_won: bool): snap_slots("reset"))
	events.world_fact.connect(func(kind: String, _at: Vector3):
		if kind in ["ride_chute", "ride_grapple_line", "ride_bowl", "ride_drop", "ride_ledge",
			"kicker_launch", "ride_glide_drop", "thermal_ride", "ride_hop", "crater_ride", "lift_fired"]:
			_clear_speed_bank())
	_rigid.landed.connect(func(impact: float): events.landed.emit(impact))
	_rigid.bumped.connect(func(at: Vector3, normal: Vector3, speed: float): events.bumped.emit(at, normal, speed))
	_rigid.jumped.connect(func(air: bool):
		if not air:
			_speed_bank_jumped = true
		_speed_bank_chosen = BankMove.JUMP
		_speed_bank_airborne = false)

	# Everything under the player is placed per frame in _process, which interpolation
	# must leave alone; only the body is ticked by physics and interpolated.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rigid.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON

	_visual_root = Node3D.new()
	_visual_root.name = "Visual"
	add_child(_visual_root)
	_juice = Node3D.new()
	_juice.name = "Juice"
	_visual_root.add_child(_juice)
	_pod_mount = Node3D.new()
	_pod_mount.name = "PodMount"
	_visual_root.add_child(_pod_mount)
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = Tuning.RADIUS
	sphere.height = Tuning.RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_mesh.mesh = sphere
	_mesh.material_override = Palette.ball_material()
	_juice.add_child(_mesh)
	_roll_mount = Node3D.new()
	_roll_mount.name = "RollMount"
	_mesh.add_child(_roll_mount)

	_build_bow()
	_build_augment_visuals()
	indicator = Indicator.new()
	indicator.name = "Indicator"
	add_child(indicator)
	_rigid.set_active(true)
	reset_to(spawn_point)


func body() -> RigidBody3D:
	return _rigid


func active_body() -> RigidBody3D:
	return _rigid


func ball_position() -> Vector3:
	return _rigid.global_position


func shown_transform() -> Transform3D:
	if is_inside_tree() and get_tree().physics_interpolation and not _rigid.placing:
		return _rigid.get_global_transform_interpolated()
	return _rigid.global_transform


func shown_position() -> Vector3:
	return shown_transform().origin


func juice_node() -> Node3D:
	return _juice


func pod_mount() -> Node3D:
	return _pod_mount


func roll_node() -> Node3D:
	return _roll_mount


func speed_tier() -> int:
	return state.tier


func speed_fraction() -> float:
	return SpeedTier.fraction(state.velocity.length(), tuning.f("cruise"))


func planar_velocity() -> Vector3:
	return Vector3(state.velocity.x, 0.0, state.velocity.z)


func add_external_accel(accel: Vector3) -> void:
	if _frozen:
		return
	_rigid.external_accel += accel


func set_frozen(frozen: bool) -> void:
	_frozen = frozen
	_rigid.set_active(not frozen)
	if frozen:
		_clear_speed_bank()
		_rigid.external_accel = Vector3.ZERO


func frozen() -> bool:
	return _frozen


func reset_to(point: Vector3, velocity := Vector3.ZERO) -> void:
	_bank_pending = {}
	_drags.clear()
	_clear_speed_bank()
	_speed_bank_move_held = false
	_speed_bank_brake_held = false
	_speed_bank_rest_ticks = 0
	_speed_bank_rest_braked = false
	state.reset()
	kit.clear_runtime()
	chain.clear_active()
	_roll = Basis.IDENTITY
	_spin_clear()
	_was_hooked = false
	_brake_was_held = false
	_ctrl_claimed = false
	_line_state = ""
	_line_target = null
	_line_hold = 0.0
	_line_standing = false
	air_draw_active = false
	air_draw_left = Augments.KEST_AIR_DRAW_MAX_S
	_kest_wall_kick_faces.clear()
	_kest_wall_aim = {}
	last_kest_wall_kick = {}
	last_spire_vault = {}
	_rigid.external_accel = Vector3.ZERO
	_rigid.teleport(point, velocity)


func set_velocity_now(velocity: Vector3, cause := "launched") -> void:
	cut_line(cause)
	_clear_speed_bank()
	_rigid.set_velocity_now(velocity)


func _keep_spin() -> void:
	var tick := Engine.get_physics_frames()
	if state.grounded:
		_spin_end()
		return
	_spin_held = tick - _spin_set_tick <= 1
	_spin_set_tick = tick
	if _spin_on:
		return
	_spin_on = true
	_settle_offset(_body_basis())
	_spin_basis = (_body_basis() * _spin_offset).orthonormalized()
	_spin_omega = _rigid.angular_velocity


func _spin_end() -> void:
	if _spin_on:
		_spin_on = false
		_spin_freeze = true


func _body_basis() -> Basis:
	return shown_transform().basis.orthonormalized()


func _settle_offset(body_basis: Basis) -> void:
	if _spin_freeze:
		_spin_freeze = false
		_spin_offset = (body_basis.inverse() * _spin_basis).orthonormalized()


func _spin_clear() -> void:
	_spin_on = false
	_spin_freeze = false
	_spin_offset = Basis.IDENTITY


func _drawn_basis(body_basis: Basis, delta: float) -> Basis:
	body_basis = body_basis.orthonormalized()
	if _spin_on and state.grounded and Engine.get_physics_frames() - _spin_set_tick > 1:
		_spin_end()
	if _spin_on:
		var held := _spin_held and Engine.get_physics_frames() - _spin_set_tick <= 1
		_spin_omega *= exp(-(SPIN_HELD_DAMP if held else SPIN_AIR_DAMP) * delta)
		var w := _spin_omega.length()
		if w > 0.0001:
			_spin_basis = (Basis(_spin_omega / w, w * delta) * _spin_basis).orthonormalized()
		return _spin_basis
	_settle_offset(body_basis)
	return (body_basis * _spin_offset).orthonormalized()


var _bank_pending := {}
var bank_last := {}
var _bank_logging_deferred := false


func bank_geometry() -> Dictionary:
	var at := ball_position()
	var launch := Augments.bank_exit(state.velocity.length(), at - kit.anchor, drive_basis, kit)
	return _aim_cone(at, launch.normalized(), AIM_CONE_LENGTH * (1.0 + launch.length() / Augments.LAUNCH_CEILING), {"speed": launch.length()})


func _aim_cone(at: Vector3, dir: Vector3, length: float, more := {}) -> Dictionary:
	var shape := {"kind": "cone", "aim": true, "apex": at, "dir": dir, "length": length, "half_angle": AIM_CONE_HALF, "clear": AIM_CONE_CLEAR}
	shape.merge(more)
	return yours(shape)


func bank_shot() -> void:
	if kit.line_state == Augments.LINE_SMASH:
		_bank_pending = {"anchor": kit.anchor}
		return
	_bank_release(kit.anchor)


func _bank_release(anchor: Vector3) -> void:
	var incoming := state.velocity.length()
	var base := maxf(incoming, minf(Augments.LAUNCH_CEILING, maxf(incoming, 13.0) * 1.25 + 4.0))
	var launch := Augments.bank_exit(incoming, ball_position() - anchor, drive_basis, kit)
	Augments.mass_spend(kit, base)
	bank_last = {"entry": incoming, "exit": launch.length(), "dir": launch.normalized(), "pending_log": _bank_logging_deferred}
	kit.mounted = false
	kit.slingshot.cancel()
	set_velocity_now(launch, "bank")
	chain.let_go()
	events.dismounted.emit(launch)


func pay_chain(at: Vector3) -> float:
	var paid: Dictionary = chain.pay()
	_publish_chain(paid["events"], null, at)
	return float(paid["mult"])


func in_set_piece() -> bool:
	if not set_piece_phase.is_valid():
		return false
	var phase := String(set_piece_phase.call())
	return phase != "idle" and phase != ""


func fit_class(def: Resource) -> void:
	class_def = def
	air_draw_active = false
	air_draw_left = Augments.KEST_AIR_DRAW_MAX_S
	_kest_wall_kick_faces.clear()
	_kest_wall_aim = {}
	tree.reset(def.id if def != null else "")
	abilities.fit(class_def)
	_refit()


func refresh_air_draw() -> void:
	air_draw_left = Augments.KEST_AIR_DRAW_MAX_S


func apply_spire_vault(anchor: Vector3) -> bool:
	if class_def == null or class_def.id != "demolitions_caster" or _frozen:
		return false
	var v: Vector3 = state.velocity
	v.y = maxf(v.y, Augments.KEST_SPIRE_VAULT_UP)
	_rigid.set_velocity_now(v)
	air_draw_left = Augments.KEST_AIR_DRAW_MAX_S
	state.air_actions = maxi(state.air_actions, 1)
	last_spire_vault = {"anchor": anchor, "vy": v.y}
	return true


func _on_tree_picked(n: Dictionary) -> void:
	UpgradeTree.apply_pick(abilities, n)
	_refit()


func _refit() -> void:
	if class_def == null:
		kit.fit(Augments.DEFAULT_MOVEMENT, "")
	else:
		kit.fit(abilities.id_of(AbilityState.MOVEMENT), abilities.id_of(AbilityState.SMASH))
	abilities.movement_key = _burst_key()
	_paint_effects()


func _paint_effects() -> void:
	var color := class_color()
	_wings_material.albedo_color = Color(color, 0.75)
	_plate.material_override = Palette.solid(color, 1.2)


func class_color() -> Color:
	return class_def.color if class_def != null else ClassDef.SABLE_COLOR


func yours(shape: Dictionary) -> Dictionary:
	shape["color"] = class_color()
	shape["ticks"] = class_def.shape if class_def != null else "ring"
	return shape


func heft() -> float:
	return float(heft_of.call()) if heft_of.is_valid() else 1.0


func enemy_heft(target) -> float:
	return float(enemy_heft_of.call(target)) if enemy_heft_of.is_valid() else INF


func bind_destructibles(pieces: Node, class_of := Callable()) -> void:
	if is_instance_valid(_destructibles) and _destructibles.piece_shattered.is_connected(_on_piece_shattered):
		_destructibles.piece_shattered.disconnect(_on_piece_shattered)
	_destructibles = pieces
	_destructibles_class = class_of
	redline.blast_props = _break_props if pieces != null else Callable()
	if pieces != null:
		pieces.piece_shattered.connect(_on_piece_shattered)


func _break_props(at: Vector3, radius: float, source: String) -> void:
	if is_instance_valid(_destructibles):
		_destructibles.on_blast(at, radius, source, 1, int(_destructibles_class.call()) if _destructibles_class.is_valid() else -1)


func _point_in_shattered(bounds: AABB, point: Vector3) -> bool:
	var id: String = _destructibles.last_shattered_id() if is_instance_valid(_destructibles) else ""
	if id != "":
		return _destructibles.contains_point(id, point, SHATTER_MARGIN)
	return bounds.grow(SHATTER_MARGIN).has_point(point)


func _on_piece_shattered(bounds: AABB) -> void:
	if kit.hooked and not kit.on_body and _point_in_shattered(bounds, kit.anchor):
		cut_line("shattered")
	if kit.mounted and _point_in_shattered(bounds, kit.mount_face):
		kit.mounted = false
		kit.slingshot.cancel()
		kit.mount_block = Augments.MOUNT_COOLDOWN
		kit.dismount_velocity = Vector3.ZERO
		kit.dismount_fired = true
	if kit.aim.get("state", Augments.AIM_NONE) != Augments.AIM_NONE and kit.aim.get("body") == null and _point_in_shattered(bounds, kit.aim["point"]):
		kit.aim = Augments.no_aim()


func crowd_control(kind: String, shove := Vector3.ZERO, interrupts := true) -> bool:
	if _frozen:
		return false
	if kit.sprinting or immune_left > 0.0 or (kit.mounted and tree.knob("mount_cc_immune")):
		var now := SimClock.msec()
		if now - int(_cc_ignored_at.get(kind, -100000)) >= CC_IGNORED_GAP_MS:
			_cc_ignored_at[kind] = now
			events.cc_ignored.emit(kind)
		return false
	_clear_speed_bank()
	if interrupts:
		for id in abilities.cancel_gauges():
			events.gauge_cancelled.emit(id, kind)
		if kit.slingshot.cancel():
			events.gauge_cancelled.emit("slingshot", kind)
		indicator.collapse_all()
	if shove != Vector3.ZERO:
		add_external_accel(shove)
	return true


func grant_immunity(seconds: float) -> void:
	immune_left = maxf(immune_left, seconds)


func refresh_air() -> void:
	state.air_actions = 1
	abilities.grant(AbilityState.MOVEMENT)
	kit.refresh_vault()


func grapple_to(point: Vector3, normal := Vector3.ZERO, body: Node3D = null) -> void:
	if not kit.on(Augments.GRAPPLE):
		return
	_clear_speed_bank()
	Augments.attach(kit, ball_position(), point, normal, body)
	kit.grip = Grip.of(body, heft(), enemy_heft(body), tuning.pole_flail())
	events.grapple_fired.emit(point)
	if body != null:
		if body.has_method("flash"):
			body.flash()
		events.harpoon_bit.emit(body, point)
	_publish_chain(chain.link(body != null and not body.is_in_group(Augments.STAKE_GROUP)
		and not body.is_in_group(Augments.WORLD_ANCHOR_GROUP), state.grounded), body, point)


func link_chain(body: Node3D) -> void:
	_publish_chain(chain.link(true, state.grounded), body, body.global_position)


func release_grapple() -> void:
	_clear_speed_bank()
	kit.drop_line()


func cut_line(cause := "hold") -> void:
	_clear_speed_bank()
	kit.drop_line(cause)


func grapple_range() -> float:
	return tuning.f("rope_range")


func active_line_id() -> String:
	if abilities != null:
		var slot_id := String(abilities.id_of(AbilityState.LINE))
		if slot_id != "":
			return slot_id
	if class_def != null and String(class_def.line_id) != "":
		return String(class_def.line_id)
	return "line_reel"


func grapple_rig_state() -> Dictionary:
	return {
		"class_id": String(class_def.id) if class_def != null else "",
		"line_id": active_line_id(),
		"hooked": kit.hooked,
		"on_body": kit.on_body,
		"winching": kit.winching,
		"rope": kit.rope,
		"anchor": kit.anchor,
		"anchor_body": kit.anchor_body,
		"anchor_normal": kit.anchor_normal,
		"aim": kit.aim,
		"line_state": kit.line_state,
		"shown_position": shown_position(),
		"velocity": state.velocity,
		"chain": chain.snapshot(),
	}


func _physics_process(delta: float) -> void:
	exceptions.step(delta)
	_step_drags(delta)
	source.poll(intent)
	_route_slots(delta)
	abilities.movement_key = _burst_key()
	_read_mass()
	_route_interact()
	_read_grammar(delta)
	abilities.tick(delta)
	immune_left = maxf(0.0, immune_left - delta)
	if kit.mounted and tree.knob("mounted_recharge") > 1.0:
		abilities.refund(AbilityState.SPECIAL, delta * (tree.knob("mounted_recharge") - 1.0))
	state.tick_timers(delta)
	_tick_speed_bank(delta)
	if intent.jump_pressed:
		state.jump_buffer = Tuning.JUMP_BUFFER
	_step_kest_wall_kick(delta)
	_step_kest_air_draw(delta)
	_rigid.drive_basis = drive_basis
	state.refresh_tier(tuning.f("cruise"))
	if _was_hooked and not kit.hooked:
		events.grapple_released.emit()
	_was_hooked = kit.hooked
	_publish_line(delta)
	dunk.tick(delta)
	if redline.mode != Redline.OFF:
		redline.tick(delta, state.tier, ball_position(), state.velocity.length())
	_tick_chain(delta)
	_try_buffered_harpoon()
	_recheck_bow()
	_tick_face_tags(delta)
	_mark_slots()


func _clear_speed_bank() -> void:
	speed_bank = {}
	_speed_bank_airborne = false
	_speed_bank_jumped = false
	_speed_bank_chosen = BankMove.NONE


func _tick_speed_bank(delta: float) -> void:
	var landed := false
	var jumped := _speed_bank_jumped
	_speed_bank_jumped = false
	var moving := intent.move.length_squared() >= 0.02
	var roll_start := moving and not _speed_bank_move_held
	var slide_start := intent.brake_held and not _speed_bank_brake_held
	_speed_bank_move_held = moving
	_speed_bank_brake_held = intent.brake_held
	var cruise: float = tuning.f("cruise")
	if _frozen or kit.hooked or Augments.holding(kit) or in_set_piece():
		_clear_speed_bank()
		_speed_bank_rest_ticks = 0
		_speed_bank_rest_braked = false
		return
	var floored: bool = state.grounded and state.contact_normal.y > Tuning.MAX_SLOPE_DOT
	var planar := planar_velocity()
	var speed := planar.length()
	var free_rest := _speed_bank_rest_ticks > 0 and not _speed_bank_rest_braked
	if floored and speed <= Tuning.BANK_REST * cruise:
		_speed_bank_rest_ticks += 1
		_speed_bank_rest_braked = _speed_bank_rest_braked or intent.brake_held
	else:
		_speed_bank_rest_ticks = 0
		_speed_bank_rest_braked = false
	var probe_grounded := false
	for i in _rigid._probe.get_collision_count():
		if _rigid._probe.get_collision_normal(i).y > Tuning.MAX_SLOPE_DOT:
			probe_grounded = true
	if _speed_bank_chosen != BankMove.NONE:
		if not probe_grounded:
			_speed_bank_airborne = true
		elif _speed_bank_airborne:
			landed = true
			_speed_bank_chosen = BankMove.NONE
			_speed_bank_airborne = false
	if _speed_bank_chosen == BankMove.SLIDE:
		if not floored:
			_speed_bank_chosen = BankMove.SLIDE_FLIGHT
		elif not intent.brake_held or speed <= Tuning.BANK_REST * cruise:
			_speed_bank_chosen = BankMove.NONE
	if slide_start and floored and speed >= Tuning.BANK_ARM * cruise:
		_speed_bank_chosen = BankMove.SLIDE
		_speed_bank_airborne = false
	roll_start = roll_start and free_rest and floored and not intent.brake_held and speed <= Tuning.BANK_REST * cruise
	if not speed_bank.is_empty() and jumped:
		var row: Dictionary = speed_bank["row"]
		var u: float = speed_bank["t"] / float(row["decay_s"])
		if u >= 1.0 - Tuning.BANK_WINDOW:
			_bank_push(planar, maxf(0.0, float(row["ratio"]) * cruise - speed))
		else:
			_bank_push(planar, -minf(float(speed_bank["bonus"]), maxf(0.0, speed - cruise)))
		speed_bank = {}
		return
	if speed_bank.is_empty():
		if not floored or not (roll_start or (landed and speed >= Tuning.BANK_ARM * cruise)):
			return
		var row := Tuning.bank_row(class_def.id if class_def != null else "")
		var bonus := float(row["ratio"]) * cruise - speed
		if bonus <= 0.0:
			return
		if roll_start:
			var heading := Rules.wish_direction(intent, drive_basis, state)
			var target := Vector3(heading.x, 0.0, heading.z).normalized() * float(row["ratio"]) * cruise
			var push := target - planar
			_bank_push(push, push.length())
		else:
			_bank_push(planar, bonus)
		var banked := minf(bonus, (float(row["ratio"]) - 1.0) * cruise)
		speed_bank = {"row": row, "t": 0.0, "bonus0": banked, "bonus": banked}
		return
	if not floored:
		return
	var row: Dictionary = speed_bank["row"]
	speed_bank["t"] += delta
	var left: float = float(speed_bank["bonus0"]) * Tuning.bank_share(row, speed_bank["t"] / float(row["decay_s"]))
	var give_back: float = float(speed_bank["bonus"]) - left
	speed_bank["bonus"] = left
	_bank_push(planar, -minf(give_back, maxf(0.0, speed - (cruise + left))))
	if speed_bank["t"] >= float(row["decay_s"]):
		_clear_speed_bank()


func _bank_push(planar: Vector3, dv: float) -> void:
	if absf(dv) < 0.0001 or planar.length_squared() < 0.0001:
		return
	var push := planar.normalized() * dv
	_rigid.apply_central_impulse(push * _rigid.mass)
	var axis := Rules.roll_axis(push, state.contact_normal if state.grounded else Vector3.UP)
	if axis != Vector3.ZERO:
		_rigid.angular_velocity += axis / Tuning.RADIUS
	state.velocity += push


func _mark_slots() -> void:
	if kit.on(Augments.GRAPPLE) and kit.movement_id == Augments.GRAPPLE:
		abilities.slot(AbilityState.MOVEMENT).active = kit.hooked
	var smash = abilities.slot(AbilityState.SMASH)
	smash.active = kit.slamming or kit.plant_time > 0.0
	smash.available = smash.active or not state.grounded


func _charging() -> bool:
	var special = abilities.gauge(AbilityState.SPECIAL)
	var line = abilities.gauge(AbilityState.LINE)
	return (special != null and special.charging) or (line != null and line.charging) or kit.slingshot.charging \
		or abilities.casting != AbilityState.UNSTARTED


func _route_slots(delta: float) -> void:
	_click_held = intent.fire_held
	if _fire_latched and not intent.fire_held:
		_fire_latched = false
		intent.fire_released = false
	if in_set_piece():
		_swallow_for_set_piece()
		return
	if abilities.tick_selection(delta, abilities.charging()):
		snap_slots("timeout", intent.fire_held and not intent.fire_pressed)
	if intent.slot_pick >= 0 and intent.slot_pick < AbilityState.BAR.size():
		_pick(AbilityState.BAR[intent.slot_pick])
	var picked: String = abilities.selected
	if picked == AbilityState.SPECIAL:
		intent.special_pressed = intent.special_pressed or intent.fire_pressed
		intent.special_held = intent.special_held or intent.fire_held
		intent.special_released = intent.special_released or intent.fire_released
		_clear_fire()
	elif picked == AbilityState.LINE:
		intent.line_pressed = intent.line_pressed or intent.fire_pressed
		intent.line_held = intent.line_held or intent.fire_held
		intent.line_released = intent.line_released or intent.fire_released
		_clear_fire()
	elif _fire_latched:
		_clear_fire()


func _swallow_for_set_piece() -> void:
	var move := intent.move
	var jump_pressed := intent.jump_pressed
	var jump_held := intent.jump_held
	var ultimate_pressed := intent.ultimate_pressed
	intent.clear()
	intent.move = move
	intent.jump_pressed = jump_pressed
	intent.jump_held = jump_held
	intent.ultimate_pressed = ultimate_pressed


func _clear_fire() -> void:
	intent.fire_pressed = false
	intent.fire_held = false
	intent.fire_released = false


func _pick(slot: String) -> void:
	var held: String = abilities.selected
	if slot == AbilityState.WEAPON or slot == held:
		if held == AbilityState.WEAPON:
			return
		_drop_gauge(held, "cancel")
		snap_slots("deselect")
		return
	var swapped := false
	if held != AbilityState.WEAPON:
		swapped = _drop_gauge(held, "swap")
	else:
		for id in abilities.cancel_gauges():
			events.gauge_cancelled.emit(id, "swap")
			indicator.collapse_all()
	var refusal := "loaded" if slot == AbilityState.LINE and _line_loaded() else abilities.select(slot)
	if refusal != "":
		_fail("select", refusal)
		if swapped:
			snap_slots("swap")
		return
	events.slot_selected.emit(slot, "swap" if swapped else "pick")


func _drop_gauge(slot: String, reason: String) -> bool:
	var gauge = abilities.gauge(slot)
	if gauge == null or not gauge.cancel():
		if abilities.casting != slot or abilities.cancel_cast() == "":
			return false
	indicator.collapse(slot)
	events.gauge_cancelled.emit(abilities.id_of(slot), reason)
	return true


func _line_loaded() -> bool:
	return line_load_of.is_valid() and not (line_load_of.call() as Dictionary).is_empty()


func snap_slots(reason: String, latch := true) -> void:
	if not abilities.snap_back(reason):
		return
	if latch and (intent.fire_held or _click_held):
		_fire_latched = true
	events.slot_selected.emit(AbilityState.WEAPON, reason)


func _read_grammar(delta := 0.0) -> void:
	_read_shift(delta)
	if intent.harpoon_pressed and _charging():
		intent.harpoon_pressed = false
		intent.cancel_pressed = true
		kit.harpoon_buffer = 0.0
		kit.harpoon_buffer_reason = ""
		snap_slots("cancel")
	if not _frozen and kit.on(Augments.GRAPPLE) and intent.harpoon_released and kit.hooked:
		_fling()
		_pole_exit()
		release_grapple()
	_read_ctrl(delta)
	if _frozen or not kit.on(Augments.GRAPPLE):
		kit.harpoon_buffer = 0.0
		kit.harpoon_buffer_reason = ""
		return
	_step_harpoon_buffer(delta)
	if intent.harpoon_pressed and not kit.hooked:
		_press_harpoon()
	if tree.knob("winch_mount") and kit.hooked and kit.winching and not kit.mounted \
			and ball_position().distance_to(kit.anchor) <= Augments.MIN_ROPE + 2.5:
		intent.mount_pressed = true


func _burst_key() -> String:
	return Bindings.label("boost")


func _burst_pilot() -> bool:
	return kit.on(Augments.SPRINT) or kit.on(Augments.BLINK) or kit.on(Augments.CLAW_PULL) or kit.on(Augments.SURGE) \
		or kit.on(Augments.RECOIL)


func _read_shift(delta := 0.0) -> void:
	if delta > 0.0 and kit.movement_buffer > 0.0:
		kit.movement_buffer = maxf(0.0, kit.movement_buffer - delta)
	if intent.cancel_pressed or (kit.on(Augments.SPRINT) and intent.shift_released):
		kit.movement_buffer = 0.0
	if _burst_pilot():
		intent.movement_held = intent.movement_held or intent.shift_held
		intent.movement_released = intent.movement_released or intent.shift_released
		if intent.shift_pressed:
			var wait: float = Harpoon.burst_wait(kit)
			if wait <= 0.0:
				kit.movement_buffer = 0.0
				intent.movement_pressed = true
			elif wait <= Tuning.ACTION_BUFFER_S + 0.0001:
				kit.movement_buffer = Tuning.ACTION_BUFFER_S
			else:
				_fail("boost", "busy" if kit.mounted else "uncharged")
	else:
		intent.boost_pressed = intent.boost_pressed \
				or (intent.shift_pressed and (state.boost_cooldown <= Tuning.BOOST_BUFFER or kit.plant_time > 0.0))
		if intent.shift_pressed and state.boost_cooldown > Tuning.BOOST_BUFFER:
			_fail("boost", "cooldown")
		elif intent.shift_pressed and kit.mounted:
			_fail("boost", "busy")


func _fail(verb: String, reason: String) -> void:
	events.verb_failed.emit(verb, reason, ball_position())


func verb_ready(verb: String) -> bool:
	match verb:
		"harpoon":
			return not _frozen and kit.on(Augments.GRAPPLE) and not kit.hooked and not _charging() \
					and not kit.mounted and _harpoon_refusal() == "" and chain.miss_left <= 0.0
		"interact":
			if _frozen or kit.mounted:
				return false
			var taken: bool = interact_claim.is_valid() and interact_claim.call(kit.on(Augments.PYLON) and face_in_reach()) \
					and not mobility_started()
			return taken or mount_ready()
		"jump":
			if _frozen:
				return false
			if kit.mounted:
				return true
			return not kit.mounted and (state.grounded or state.coyote > 0.0 or state.air_actions > 0 or kit.plant_time > 0.0)
		"haul":
			return not _frozen and not Augments.holding(kit) and kit.hooked \
					and (not kit.on_body or (kit.line_state == Augments.LINE_LATCHED and Augments.haul_open(kit)))
		"boost":
			if _burst_pilot():
				return Harpoon.burst_ready(kit)
			return state.boost_cooldown <= 0.0 and not kit.mounted
	return false


func mount_ready() -> bool:
	return not _frozen and not kit.mounted and kit.on(Augments.PYLON) and kit.mount_block <= 0.0 and face_in_reach() \
			and (mobility_started() or not (interact_claim.is_valid() and interact_claim.call(true)))


func _harpoon_refusal() -> String:
	if kit.rewind_left > 0.0:
		return "rewinding"
	if kit.aim.get("state", Augments.AIM_NONE) == Augments.AIM_NONE:
		return "no_aim"
	if kit.mounted:
		return "busy"
	return ""


func _harpoon_wait() -> float:
	if kit.mounted:
		return INF
	return maxf(kit.rewind_left, chain.miss_left)


func _emit_harpoon_refusal() -> void:
	if chain.miss_left > 0.0:
		_fail("harpoon", "cooldown")
		return
	var reason := _harpoon_refusal()
	if reason == "":
		return
	if not kit.hooked:
		_emit_line("dry_fire", null, ball_position(), "", DRY_FIRE_HOLD)
		if reason == "no_aim":
			_publish_chain(chain.dry_fire(), null, ball_position())
	_fail("harpoon", reason)


func _try_buffered_harpoon() -> bool:
	if kit.harpoon_buffer <= 0.0 or _frozen or kit.hooked or not kit.on(Augments.GRAPPLE) or _charging():
		return false
	if chain.miss_left > 0.0 or _harpoon_refusal() != "":
		return false
	kit.harpoon_buffer = 0.0
	kit.harpoon_buffer_reason = ""
	grapple_to(kit.aim["point"], kit.aim["normal"], kit.aim.get("body"))
	return true


func _step_harpoon_buffer(delta: float) -> void:
	if intent.harpoon_released or intent.cancel_pressed or kit.hooked or _charging():
		kit.harpoon_buffer = 0.0
		kit.harpoon_buffer_reason = ""
		return
	if kit.harpoon_buffer <= 0.0:
		return
	if _try_buffered_harpoon():
		return
	kit.harpoon_buffer = maxf(0.0, kit.harpoon_buffer - delta)
	if kit.harpoon_buffer <= 0.0:
		kit.harpoon_buffer_reason = ""
		if not intent.harpoon_pressed:
			_emit_harpoon_refusal()


func _press_harpoon() -> void:
	if chain.miss_left <= 0.0 and _harpoon_refusal() == "":
		kit.harpoon_buffer = 0.0
		kit.harpoon_buffer_reason = ""
		grapple_to(kit.aim["point"], kit.aim["normal"], kit.aim.get("body"))
		return
	var wait := _harpoon_wait()
	if wait > 0.0 and wait <= Tuning.ACTION_BUFFER_S + 0.0001:
		kit.harpoon_buffer = Tuning.ACTION_BUFFER_S
		kit.harpoon_buffer_reason = "cooldown" if chain.miss_left > 0.0 else "rewinding"
		return
	_emit_harpoon_refusal()


func _haul_refusal() -> String:
	if kit.grip == "flail":
		return "flail"
	if is_instance_valid(kit.anchor_body) and kit.anchor_body.is_in_group(Augments.STAKE_GROUP):
		return "stake"
	return "unstaggered"


func line_stands() -> bool:
	return kit.hooked


func _read_ctrl(delta := 0.0) -> void:
	if delta > 0.0 and kit.slam_buffer > 0.0:
		kit.slam_buffer = maxf(0.0, kit.slam_buffer - delta)
	if intent.cancel_pressed or _frozen or kit.mounted or in_set_piece():
		kit.slam_buffer = 0.0
	var edge: bool = intent.brake_held and not _brake_was_held
	_brake_was_held = intent.brake_held
	var on_body: bool = kit.hooked and kit.on_body
	kit.winching = kit.hooked and not on_body and intent.brake_held
	if edge and not _frozen:
		if on_body and kit.line_state == Augments.LINE_LATCHED and Augments.holding(kit):
			_fail("haul", "busy")
		elif on_body and kit.line_state == Augments.LINE_LATCHED and Augments.haul_open(kit):
			kit.slam_buffer = 0.0
			Augments.commit_smash(kit, tuning, _rigid.linear_velocity)
		elif on_body and kit.line_state == Augments.LINE_LATCHED:
			_fail("haul", _haul_refusal())
		elif on_body:
			_fail("haul", "committed")
		elif kit.hooked:
			if kit.on(Augments.SLAM) and not Augments.holding(kit) and not in_set_piece() \
					and (not state.grounded or state.jump_buffer > 0.0 or intent.jump_pressed or state.velocity.y > 0.5):
				kit.slam_buffer = Tuning.SLAM_BUFFER_S
		elif _ctrl_idle():
			_fail("haul", "no_line")
		elif kit.on(Augments.SLAM) and not Augments.holding(kit) and not in_set_piece() \
				and (not state.grounded or state.jump_buffer > 0.0 or intent.jump_pressed or state.velocity.y > 0.5):
			kit.slam_buffer = Tuning.SLAM_BUFFER_S
	if line_stands():
		_ctrl_claimed = true
	if not intent.brake_held:
		_ctrl_claimed = false
	if _ctrl_claimed:
		intent.brake_held = false


func _ctrl_idle() -> bool:
	if Augments.holding(kit) or in_set_piece():
		return false
	if not state.grounded:
		return not kit.on(Augments.SLAM)
	if kit.on(Augments.SLAM) and (state.jump_buffer > 0.0 or intent.jump_pressed or state.velocity.y > 0.5):
		return false
	return planar_velocity().length() <= REFUSE_REST


func _emit_line(id: String, target: Node3D, at: Vector3, cause := "", hold := 0.0) -> void:
	_line_state = id
	_line_target = target
	_line_hold = hold
	events.line_state_changed.emit(id, target, at, cause)


func _publish_chain(emitted: Array, target: Node3D, at: Vector3) -> void:
	for e in emitted:
		events.line_state_changed.emit(e["id"], target, at, e["cause"])


func _tick_chain(delta: float) -> void:
	if in_set_piece():
		return
	_publish_chain(chain.tick(delta, state.grounded, kit.hooked), null, ball_position())


const QUIET_ENDS := ["landed", "reset", "ultimate", "bank", ""]


func _publish_end() -> void:
	_line_standing = false
	var end: String = kit.line_end
	if end != "landed":
		_bank_pending = {}
	kit.line_end = ""
	if not end in QUIET_ENDS:
		chain.let_go()
	if end == "let_go":
		_emit_line("let_go", _line_target_alive(), _line_anchor, "", LET_GO_HOLD)
	elif not end in QUIET_ENDS:
		_emit_line("broke", _line_target_alive(), _line_anchor, end, BROKE_HOLD)


func _line_target_alive() -> Node3D:
	return _line_target if is_instance_valid(_line_target) else null


func _publish_line(delta: float) -> void:
	_line_hold = maxf(0.0, _line_hold - delta)
	if kit.hooked:
		if _line_standing and kit.line_end != "":
			_publish_end()
		var id := "smash_committed" if kit.line_state == Augments.LINE_SMASH \
				else ("latched_body" if kit.on_body else "latched_world")
		var target: Node3D = kit.anchor_body if kit.on_body else null
		if id != _line_state or target != _line_target:
			_emit_line(id, target, kit.anchor)
		_line_anchor = kit.anchor
		_line_standing = true
		kit.line_end = ""
		return
	if _line_standing:
		_publish_end()
	if _line_hold > 0.0:
		return
	var steady := "searching"
	var aimed = null
	if kit.rewind_left > 0.0:
		steady = "rewinding"
	elif not _frozen and kit.on(Augments.GRAPPLE) and _harpoon_refusal() == "":
		steady = "locked"
		aimed = kit.aim.get("body")
	var target: Node3D = aimed if is_instance_valid(aimed) else null
	if steady != _line_state or target != _line_target:
		_emit_line(steady, target, kit.aim.get("point", ball_position()))


func _route_interact() -> void:
	if not intent.mount_pressed or kit.mounted or mobility_started() or not interact_claim.is_valid():
		return
	var face: bool = kit.on(Augments.PYLON) and face_in_reach()
	if interact_claim.call(face):
		intent.mount_pressed = false
		intent.interact_pressed = true
	elif not _frozen and not face and not (talk_claim.is_valid() and talk_claim.call()):
		_fail("interact", "nothing")


func mobility_started() -> bool:
	return (kit.hooked and kit.on(Augments.PYLON)) or kit.plant_time > 0.0 or kit.slingshot.charging


func face_in_reach() -> bool:
	if not is_inside_tree():
		return false
	return not Augments.mount_face(kit, get_world_3d().direct_space_state, ball_position()).is_empty()


func _read_mass() -> void:
	kit.mass_on = tuning != null and tuning.world_one() and tree.knob("mass_launch")
	var mass := maxf(0.0, float(mass_of.call())) if kit.mass_on and mass_of.is_valid() else 0.0
	kit.mass_q = clampf(mass / Augments.MASS_FULL, 0.0, 1.0)


func _pole_exit() -> void:
	if not Augments.pole_line(kit):
		return
	var v: Vector3 = state.velocity
	var to_body: Vector3 = kit.anchor - ball_position()
	if to_body.length() < 0.01:
		return
	var share := Augments.POLE_EXIT_SABLE if class_def != null and class_def.id == "pylon_engineer" else Augments.POLE_EXIT
	_rigid.set_velocity_now(Augments.pole_exit(v, to_body.normalized(), share))


func _fling() -> void:
	var fling: float = tree.knob("grapple_fling")
	if not kit.hooked or fling <= 0.0:
		return
	var v: Vector3 = state.velocity
	var dir := v.normalized() if v.length() > 0.5 else -drive_basis.z
	var flung := v + dir * fling
	if kit.mass_on:
		flung += dir * Augments.mass_spend(kit, flung.length())
	_rigid.set_velocity_now(flung)


func _process(delta: float) -> void:
	var shown := shown_transform()
	_visual_root.global_position = shown.origin
	_visual_root.global_basis = Basis.IDENTITY
	_update_augment_visuals(shown.origin)
	_update_aim_cones(shown.origin)
	_roll = _drawn_basis(shown.basis, delta)
	_mesh.basis = (_squash_basis() if builtin_squash else Basis.IDENTITY) * _roll


func _squash_basis() -> Basis:
	var amount := clampf(state.impact / 26.0, 0.0, 0.42)
	if amount <= 0.001:
		return Basis.IDENTITY
	var align := _align_up(state.contact_normal)
	var scale := Basis.from_scale(Vector3(1.0 + amount * 0.55, 1.0 - amount, 1.0 + amount * 0.55))
	return align * scale * align.inverse()


static func _align_up(normal: Vector3) -> Basis:
	var up := normal.normalized()
	var right := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	right = (right - up * right.dot(up)).normalized()
	return Basis(right, up, right.cross(up))


func _build_bow() -> void:
	_bow = Area3D.new()
	_bow.name = "Bow"
	_bow.collision_layer = 0
	_bow.collision_mask = 0
	_bow.set_collision_mask_value(3, true)
	_bow.monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS + BOW_REACH
	shape.shape = sphere
	_bow.add_child(shape)
	_rigid.add_child(_bow)
	_bow.body_entered.connect(_on_bow_entered)


func _on_bow_entered(_body: Node3D) -> void:
	if not _bow_check_queued:
		_bow_check_queued = true
		_flush_bow.call_deferred()


func _flush_bow() -> void:
	_bow_check_queued = false
	_recheck_bow()


func _recheck_bow() -> void:
	if _bow == null or _frozen or state.tier < SpeedTier.CRUISE:
		return
	var bodies := _bow.get_overlapping_bodies()
	bodies.sort_custom(func(a: Node, b: Node): return b.is_greater_than(a))
	for body in bodies:
		_try_crush(body)


func _try_crush(body: Node3D) -> void:
	if _frozen or not body.is_in_group("enemy") or state.tier < SpeedTier.CRUISE or not crush_check.is_valid():
		return
	var id := body.get_instance_id()
	if _crushing.has(id):
		return
	var speed := planar_velocity().length()
	if not crush_check.call(body, RAM, speed):
		return
	_crushing[id] = true
	if kit.sprinting:
		kit.sprint_left += tree.knob("crush_refund")
	exceptions.hold(body)
	var closing := kit.line_closing
	var landing := _begin_landing(body)
	if landing:
		smash_landing = body
	struck.emit(body, RAM, _landing_force(RAM, speed))
	_bowl_if_killed(body, planar_velocity(), Contact.ram_knock(Augments.RAM_KNOCK, speed, heft(), _landing_mult))
	if landing:
		_finish_landing(body, closing)
	smash_landing = null
	get_tree().create_timer(CRUSH_PASS, false, true).timeout.connect(_end_crush.bind(id))


func _end_crush(id: int) -> void:
	_crushing.erase(id)
	var body := instance_from_id(id)
	if is_instance_valid(body) and body is PhysicsBody3D:
		exceptions.release(body)


func _build_augment_visuals() -> void:
	_wings = Node3D.new()
	var wing_material := Palette.unshaded(Color(class_color(), 0.75))
	_wings_material = wing_material
	for side in [-1.0, 1.0]:
		var fin := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.6, 0.12, 1.5)
		fin.mesh = box
		fin.material_override = wing_material
		fin.position = Vector3(side * 1.7, 0.2, 0.2)
		fin.rotation = Vector3(0.0, 0.0, side * -0.25)
		_wings.add_child(fin)
	_wings.visible = false
	add_child(_wings)

	_pylon = Node3D.new()
	_pylon.name = "Pylon"
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.26
	cyl.height = Augments.MOUNT_OFFSET
	post.mesh = cyl
	post.material_override = Palette.solid(Color(0.58, 0.52, 0.44))
	post.position = Vector3(0.0, Augments.MOUNT_OFFSET * 0.5, 0.0)
	_pylon.add_child(post)
	var plate := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.12
	plate.mesh = disc
	plate.material_override = Palette.solid(class_color(), 1.2)
	_plate = plate
	_pylon.add_child(plate)
	_pylon.visible = false
	add_child(_pylon)


func pylon_node() -> Node3D:
	return _pylon


func _update_augment_visuals(at: Vector3) -> void:
	_pylon.visible = kit.mounted
	if kit.mounted:
		_pylon.global_transform = Transform3D(_align_up(kit.mount_normal), kit.mount_face)

	_wings.visible = kit.gliding or air_draw_active
	if _wings.visible:
		_wings.global_position = at
		var heading := Vector3(state.velocity.x, 0.0, state.velocity.z)
		if heading.length() > 0.5:
			_wings.global_basis = Basis.looking_at(heading.normalized(), Vector3.UP)
		else:
			var flat_aim := Vector3(-drive_basis.z.x, 0.0, -drive_basis.z.z)
			if flat_aim.length() > 0.01:
				_wings.global_basis = Basis.looking_at(flat_aim.normalized(), Vector3.UP)


func slam_radius() -> float:
	return Augments.SLAM_RADIUS + tuning.add("area_radius")


static func slam_strength(speed: float, flatness := 1.0) -> float:
	return clampf(speed / 30.0, 0.4, 1.6) * flatness


func _on_rigid_slammed(at: Vector3, speed: float, flatness: float) -> void:
	_on_slammed(at, speed, flatness)
	var strength := slam_strength(speed, flatness)
	if strength < 0.05:
		return
	var row: Array = strike_damage.get("slam", [])
	if row.size() >= 2:
		dunk.store(Dunk.slam_damage(Augments.SLAM_KNOCK * strength, row, heft()) * tuning.mod("dunk_store"),
			kit.smash_flavour, String(class_def.id) if class_def != null else "", class_color())


func _on_slammed(at: Vector3, speed: float, flatness: float) -> void:
	var strength := slam_strength(speed, flatness)
	events.slammed.emit(at, strength, flatness)
	if strength >= 0.05:
		shockwave.emit(at, strength)
		_break_props(at, slam_radius(), "slam")
		var hits := _push_enemies(at, slam_radius(), Augments.SLAM_KNOCK * strength, SLAM, Contact.heft_knock(heft()))
		if hits > 0:
			events.drop_landed.emit(hits)
			redline.spend(SLAM, at, Augments.SLAM_KNOCK * strength)
		else:
			events.missed_drop.emit()
	if _smashes.has(kit.smash_flavour):
		_smashes[kit.smash_flavour].call(at, speed)


func _smash_arc(at: Vector3, _speed: float) -> void:
	events.arc_slammed.emit(at, _tag_faces(at))


func _smash_skid(at: Vector3, speed: float) -> void:
	events.skid_smashed.emit(at, _skid_push(at, clampf(speed / 30.0, 0.4, 1.6)))


func _smash_demo(at: Vector3, _speed: float) -> void:
	events.demo_slammed.emit(at)


func _smash_rend(at: Vector3, speed: float) -> void:
	if abilities.cap(AbilityState.SMASH, "mutation", "") == "rend_drag":
		_drag_in(at)
		return
	var strength := clampf(speed / 30.0, 0.4, 1.6)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		var inward: Vector3 = at - enemy.global_position
		if inward.length() > slam_radius():
			continue
		inward.y = 0.0
		inward = inward.normalized() if inward.length() > 0.01 else Vector3.FORWARD
		enemy.knock(inward + Vector3.UP * 0.2, Contact.heft_shove(Augments.SLAM_KNOCK * strength * REND_PULL, heft()))
		enemy.flash()


func _drag_in(at: Vector3) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		var offset: Vector3 = at - enemy.global_position
		if offset.length() > slam_radius() or enemy_heft(enemy) > heft():
			continue
		_drags[enemy.get_instance_id()] = {"enemy": weakref(enemy), "to": at, "t": 0.0}
		enemy.flash()


func _step_drags(delta: float) -> void:
	for id in _drags.keys():
		var drag: Dictionary = _drags[id]
		var enemy = drag["enemy"].get_ref()
		if enemy == null or (enemy.has_method("is_dead") and enemy.is_dead()):
			_drags.erase(id)
			continue
		var before: float = smoothstep(0.0, 1.0, drag["t"] / DRAG_SECONDS)
		drag["t"] = minf(float(drag["t"]) + delta, DRAG_SECONDS)
		var after: float = smoothstep(0.0, 1.0, drag["t"] / DRAG_SECONDS)
		var gap: Vector3 = drag["to"] - enemy.global_position
		gap.y = 0.0
		var step: Vector3 = gap * (after - before) / maxf(1.0 - before, 0.0001)
		if enemy is CharacterBody3D:
			enemy.move_and_collide(step)
		else:
			enemy.global_position += step
		if drag["t"] >= DRAG_SECONDS:
			_drags.erase(id)


func _smash_stamp(at: Vector3, _speed: float) -> void:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		if (enemy.global_position - at).length() <= slam_radius():
			count += 1
	if count > 0 and pressure_grant.is_valid():
		pressure_grant.call(count)


func _tag_faces(at: Vector3) -> int:
	face_tags.clear()
	var space: PhysicsDirectSpaceState3D = _rigid.get_world_3d().direct_space_state
	var from := at + Vector3.UP * 1.0
	for i in FACE_TAG_RAYS:
		var angle := TAU * float(i) / float(FACE_TAG_RAYS)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * FACE_TAG_REACH, Augments.WORLD_MASK))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) >= Augments.FACE_MAX_TILT:
			continue
		face_tags.append({"point": hit["position"] + (hit["normal"] as Vector3) * 0.1, "left": FACE_TAG_SECONDS})
	return face_tags.size()


func _tick_face_tags(delta: float) -> void:
	for tag in face_tags:
		tag["left"] -= delta
	face_tags = face_tags.filter(func(tag): return tag["left"] > 0.0)


func _skid_push(at: Vector3, strength: float, reach := SKID_REACH, inner := SKID_INNER) -> int:
	var ahead := planar_velocity()
	ahead = ahead.normalized() if ahead.length() > 0.5 else Vector3.FORWARD
	var hits := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var to: Vector3 = enemy.global_position - at
		to.y = 0.0
		if not in_skid_cone(to, ahead, reach, inner):
			continue
		var falloff := 1.0 - to.length() / reach
		enemy.knock(ahead + Vector3.UP * 0.3, Contact.heft_shove(Augments.SLAM_KNOCK * strength * falloff * tree.knob("skid_pins"), heft()))
		enemy.flash()
		struck.emit(enemy, SLAM, Augments.SLAM_KNOCK * strength * falloff)
		abilities.refund(AbilityState.MOVEMENT, SKID_REFUND)
		hits += 1
	return hits


static func in_skid_cone(to: Vector3, ahead: Vector3, reach := SKID_REACH, inner := SKID_INNER) -> bool:
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > reach:
		return false
	return flat.length() <= inner or flat.normalized().dot(ahead) >= SKID_CONE


func _update_aim_cones(at: Vector3) -> void:
	if abilities.selected == AbilityState.LINE and abilities.id_of(AbilityState.LINE) in ["bank_shot", "bank_arc"] and kit.hooked:
		indicator.set_shape("bank", bank_geometry())
	else:
		indicator.clear("bank")
	var vault_aim: Dictionary = kit.vault_aim if not kit.vault_aim.is_empty() else _kest_wall_aim
	if not vault_aim.is_empty():
		indicator.set_shape("vault", _aim_cone(at, vault_aim["dir"], AIM_CONE_LENGTH))
	else:
		indicator.clear("vault")
	if kit.mounted and not kit.slingshot_aim.is_empty():
		var fill: float = kit.slingshot_aim["fill"]
		indicator.set_shape("slingshot", _aim_cone(at, kit.slingshot_aim["dir"], AIM_CONE_LENGTH * (1.0 + fill), {"fill": fill}))
	else:
		indicator.clear("slingshot")
	if face_tags.is_empty():
		indicator.clear("faces")
	else:
		indicator.set_shape("faces", yours({"kind": "marks", "points": face_tags.map(func(tag): return tag["point"])}))


func _on_kit_fact(kind: String, args: Array) -> void:
	if kind == "gauge_cancelled":
		indicator.collapse("slingshot")
	if kind == "vault_kicked" and tree.knob("vault_tags"):
		_tag_faces(ball_position())
	events.callv("emit_signal", [kind] + args)


func _on_pylon_planted(at: Vector3, banked_speed: float) -> void:
	events.mounted.emit(at, banked_speed)
	shockwave.emit(at, 0.7)
	_push_enemies(at, Augments.MOUNT_REPEL_RADIUS, Augments.MOUNT_REPEL_KNOCK * tree.knob("plant_repel"), "")


func _redline_blast(at: Vector3, force: float) -> void:
	if force <= 0.0:
		return
	shockwave.emit(at, 1.0)
	_push_enemies(at, Redline.BLAST_RADIUS, force, SLAM, Contact.heft_knock(heft()))


func _push_enemies(at: Vector3, radius: float, force: float, kind: String, knock_mult := 1.0) -> int:
	var hits := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var away: Vector3 = enemy.global_position - at
		var reach := away.length()
		if reach > radius:
			continue
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
		var falloff := 1.0 - reach / radius
		enemy.knock(away + Vector3.UP * 0.5, minf(force * falloff * knock_mult, maxf(force * falloff, Contact.KNOCK_CEILING)))
		enemy.flash()
		hits += 1
		if kind != "":
			struck.emit(enemy, kind, force * falloff)
	return hits


func pre_contact_velocity(toward: Vector3) -> Vector3:
	var best: Vector3 = state.velocity
	var closing := -INF
	for velocity in _rigid.recent_velocities:
		var c: float = velocity.dot(toward)
		if c > closing:
			closing = c
			best = velocity
	return best


# `body` is untyped on purpose: a typed Node3D argument errors at the call when the body is freed.
func touch_body(body, normal := Vector3.ZERO) -> void:
	if not is_instance_valid(body) or not body is Node3D:
		return
	var n := normal.normalized() if normal.length() > 0.01 else Contact.normal_between(ball_position(), body.global_position)
	_on_enemy_touched(body, n)


func _on_enemy_touched(enemy: Node3D, normal: Vector3) -> void:
	if _crushing.has(enemy.get_instance_id()):
		return
	var closing := kit.line_closing
	var landing := _begin_landing(enemy)
	if landing:
		smash_landing = enemy
	var to_enemy := enemy.global_position - ball_position()
	var before := pre_contact_velocity(to_enemy.normalized() if to_enemy.length() > 0.01 else Vector3.DOWN)
	var planar := Vector2(before.x, before.z).length()
	var away := Vector3(to_enemy.x, 0.0, to_enemy.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	if before.y < -STOMP_SPEED and normal.y > 0.3:
		refresh_air()
		kit.rewind_left = 0.0
		state.impact = maxf(state.impact, -before.y)
		set_velocity_now(Vector3(before.x, tuning.f("jump_speed") * 0.95, before.z))
		enemy.knock(away * 0.6 + Vector3.DOWN * 0.2, 7.0 * _landing_mult)
		shockwave.emit(enemy.global_position, 0.6)
		struck.emit(enemy, STOMP, _landing_force(STOMP, -before.y))
		redline.spend(STOMP, ball_position(), _landing_force(STOMP, -before.y))
	elif _rebounds_off(enemy) and before.dot(normal) < -Contact.MIN_CLOSING:
		_rebound(enemy, normal, before, planar, away)
	elif SpeedTier.of(planar, tuning.tier_cruise()) >= SpeedTier.CRUISE:
		var shove: float = Augments.RAM_KNOCK * _landing_mult if enemy.get("swarm") != null else Contact.ram_knock(Augments.RAM_KNOCK, planar, heft(), _landing_mult)
		enemy.knock(away + Vector3.UP * 0.35, shove)
		enemy.flash()
		shockwave.emit(enemy.global_position, 1.0)
		struck.emit(enemy, RAM, _landing_force(RAM, planar))
		_bowl_if_killed(enemy, away, shove)
		redline.spend(RAM, ball_position(), _landing_force(RAM, planar))
	if landing:
		_finish_landing(enemy, closing)
	smash_landing = null


func _bowl_if_killed(enemy: Node3D, direction: Vector3, shove: float) -> void:
	if not hulk_launch.is_valid() or not is_instance_valid(enemy) or not enemy.has_method("is_dead") or not enemy.is_dead():
		return
	var weight = enemy.get("weight")
	hulk_launch.call(enemy, Vector3(direction.x, 0.0, direction.z), shove / maxf(float(weight) if weight != null else 1.0, 0.1))


func _begin_landing(enemy: Node3D) -> bool:
	if Augments.landing_body(kit) != enemy:
		return false
	kit.drop_line("landed")
	kit.rewind_left = tuning.harpoon_rewind()
	var paid: Dictionary = chain.pay()
	_landing_mult = paid["mult"]
	_publish_chain(paid["events"], enemy, ball_position())
	return true


func _landing_force(kind: String, force: float) -> float:
	if _landing_mult == 1.0 or not strike_damage.has(kind):
		return force
	var row: Array = strike_damage[kind]
	return (_landing_mult * (row[0] + force * row[1]) - row[0]) / row[1]


func _finish_landing(enemy: Node3D, closing: float) -> void:
	_on_slammed(ball_position(), closing, 1.0)
	var landed_on: Node3D = enemy if is_instance_valid(enemy) else null
	events.harpoon_smashed.emit(landed_on, ball_position(), closing)
	if not _bank_pending.is_empty():
		var anchor: Vector3 = _bank_pending["anchor"]
		_bank_pending = {}
		_bank_logging_deferred = true
		_bank_release(anchor)
		_bank_logging_deferred = false
	_emit_line("smash_lands", landed_on, ball_position(), "", LANDS_HOLD)
	_landing_mult = 1.0


func _rebounds_off(enemy: Node3D) -> bool:
	var weight = enemy.get("weight")
	if kit.sprinting and tree.knob("sprint_no_rebound"):
		return false
	return weight != null and Contact.rebounds(float(weight), heft(), kit.sprinting)


func _rebound(enemy: Node3D, normal: Vector3, before: Vector3, planar: float, away: Vector3) -> void:
	var out := Contact.rebound_velocity(before, normal, tuning.f("jump_speed"))
	set_velocity_now(out)
	refresh_air()
	state.impact = maxf(state.impact, -before.dot(normal))
	enemy.knock(away + Vector3.UP * 0.2, 6.0 * _landing_mult)
	enemy.flash()
	shockwave.emit(enemy.global_position, 0.8)
	if SpeedTier.of(planar, tuning.tier_cruise()) >= SpeedTier.CRUISE:
		struck.emit(enemy, RAM, _landing_force(RAM, planar))
		_bowl_if_killed(enemy, away, Contact.ram_knock(Augments.RAM_KNOCK, planar, heft(), _landing_mult))
		redline.spend(RAM, ball_position(), _landing_force(RAM, planar))
	events.enemy_rebounded.emit(enemy, out.length())


func _step_kest_air_draw(delta: float) -> void:
	if class_def == null or class_def.id != "demolitions_caster" or _frozen:
		air_draw_active = false
		return
	if state.grounded:
		air_draw_active = false
		air_draw_left = Augments.KEST_AIR_DRAW_MAX_S
		return
	if kit.slamming or Augments.holding(kit) or in_set_piece():
		air_draw_active = false
		return
	var wg = abilities.gauge(AbilityState.WEAPON)
	var drawing: bool = (wg != null and wg.charging) or (abilities.selected == AbilityState.WEAPON and intent.fire_held)
	if drawing and air_draw_left > 0.0:
		air_draw_active = true
		air_draw_left = maxf(0.0, air_draw_left - delta)
		add_external_accel(Vector3.UP * tuning.f("gravity") * (1.0 - Augments.KEST_AIR_DRAW_GRAVITY))
	else:
		air_draw_active = false


func _step_kest_wall_kick(delta: float) -> void:
	for k in _kest_wall_kick_faces.keys():
		_kest_wall_kick_faces[k] = float(_kest_wall_kick_faces[k]) - delta
		if float(_kest_wall_kick_faces[k]) <= 0.0:
			_kest_wall_kick_faces.erase(k)
	_kest_wall_aim = {}
	if class_def == null or class_def.id != "demolitions_caster" or _frozen or state.grounded \
			or kit.hooked or Augments.holding(kit) or in_set_piece() or not is_inside_tree():
		return
	var face := _kest_steep_face()
	if face.is_empty():
		return
	var key := Augments.face_key(face["point"], face["normal"])
	if float(_kest_wall_kick_faces.get(key, 0.0)) > 0.0:
		return
	var n: Vector3 = (face["normal"] as Vector3).normalized()
	var look: Vector3 = -drive_basis.z
	var along := look - n * look.dot(n)
	var dir := (Vector3.UP * 0.78 + n * 0.48 + (along.normalized() * 0.35 if along.length_squared() > 0.01 else Vector3.ZERO)).normalized()
	var jump_spd: float = tuning.f("jump_speed")
	var incoming: float = state.velocity.length()
	var speed := minf(Augments.KEST_WALL_KICK_CAP, maxf(jump_spd * Augments.KEST_WALL_KICK_MULT, incoming * 1.15))
	var launch := dir * speed
	launch.y = maxf(launch.y, jump_spd * Augments.KEST_WALL_KICK_UP_MULT)
	_kest_wall_aim = {"point": face["point"], "normal": n, "dir": launch.normalized(), "speed": launch.length()}
	if state.jump_buffer <= 0.0 and not intent.jump_pressed:
		return
	state.jump_buffer = 0.0
	state.coyote = 0.0
	intent.jump_pressed = false
	_kest_wall_kick_faces[key] = Augments.KEST_WALL_KICK_LOCK_S
	air_draw_left = Augments.KEST_AIR_DRAW_MAX_S
	_rigid.set_velocity_now(launch)
	last_kest_wall_kick = {"point": face["point"], "normal": n, "velocity": launch}
	_on_kit_fact("vault_kicked", [face["point"], launch.length()])
	events.jumped.emit(true)


func _kest_steep_face() -> Dictionary:
	var space: PhysicsDirectSpaceState3D = _rigid.get_world_3d().direct_space_state
	var origin := ball_position()
	var reach := Tuning.RADIUS + Augments.FACE_REACH
	var best := {}
	var best_tilt := Augments.FACE_MAX_TILT
	for i in Augments.FACE_RAYS:
		var ang := TAU * float(i) / float(Augments.FACE_RAYS)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, Augments.WORLD_MASK))
		if hit.is_empty():
			continue
		var n: Vector3 = (hit["normal"] as Vector3).normalized()
		var tilt := absf(n.y)
		if tilt < best_tilt:
			best_tilt = tilt
			best = {"point": hit["position"], "normal": n}
	return best
