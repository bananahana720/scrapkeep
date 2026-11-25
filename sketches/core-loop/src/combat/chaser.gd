extends "res://src/combat/enemy.gd"

const TelegraphRecord := preload("res://src/combat/telegraph_record.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")

const SPEED := 4.8
const SPEED_CEILING := 12.0
const ENTRY_GRACE_S := 2.0
const LUNGE_RANGE := 10.0
const WINDUP := 0.6
const LUNGE_TIME := 0.34
const LUNGE_LENGTH := 11.0
const LUNGE_WIDTH := 2.8
const RECOVER := TelegraphRecord.RECOVERY
const REST := 0.8
const DAMAGE := 9.0
const SHOVE := 6.0
const INTERRUPT := 10.0
const HP := 60.0
const SCRAP := 3
const ACCENT := Color("ffb070")

const REAR_SHIFT := Vector3(0.0, 0.3, 0.7)
const REAR_PITCH := 42.0
const VAULT_WINDUP := 0.70
const VAULT_FLIGHT := 0.42
const VAULT_AIR_MIN := 1.5
const VAULT_BALL_RADIUS := 1.05
const VAULT_BANK_DIST := 10.0
const VAULT_BANK_RISE := 4.5
const VAULT_RANGE := 20.0
const VAULT_COOLDOWN := 4.5
const VAULT_RADIUS := 3.2
const VAULT_REACH := 3.5
const VAULT_DAMAGE := 12.0
const VAULT_SHOVE := 7.0
const VAULT_SLOW_LEAD_S := 0.35
const VAULT_SLOW_CAP := 12.0
const AIR_PARRY_KICK := 8.0
const AIR_PARRY_REACH := 2.6
const VAULT_COIL_SHIFT := Vector3(0.0, -0.32, 0.28)
const VAULT_COIL_PITCH := -18.0

enum State { CHASE, WINDUP, LUNGE, RECOVER, CALL }

var pressure := {}
signal pressure_cue(cue: String, at: Vector3, seconds_until: float)
const LUNGE_SPEED := LUNGE_LENGTH / LUNGE_TIME
const FLANK_AHEAD_S := 1.6
const FLANK_SIDE := 5.0
const FLANK_CALL_S := 1.1

var state := State.CHASE
var lunges := 0
var vaults := 0
var air_parries := 0
var landed_attack := ""
var run_speed := SPEED
var _age := 0.0

var _clock := 0.0
var _rest := 0.0
var _vault_cd := 0.0
var _landed := false
var _vaulting := false
var _vault_from := Vector3.ZERO
var _vault_to := Vector3.ZERO
var _vault_launch := Vector3.ZERO
var _vault_parried := false
var _mesh: Node3D
var windup_pose_enabled := true
var _pose_parts: Dictionary = {}
var _parts_off_rest := false
const INTERRUPT_SHOWN := 0.9
var body_cue_enabled := true
var _interrupted_left := 0.0
var _cue_clock := 0.0
var _cue_painted := false


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = "chaser"
	_set_health(HP * threat)
	scrap_value = SCRAP
	weight = 1.0
	radius = 1.0
	half_height = 1.5
	pressure = spec_ref.get("pressure", {})
	run_speed = clampf(float(spec_ref.get("run_speed", SPEED)), SPEED, SPEED_CEILING)
	_add_capsule(radius, half_height * 2.0, Palette.RUST).free()
	_mesh = Node3D.new()
	_mesh.name = "ChaserBody"
	_visual_parent().add_child(_mesh)
	for part in _parts():
		var mi := MeshInstance3D.new()
		mi.name = part.name
		mi.mesh = part.mesh
		mi.transform = part.xform
		_mesh.add_child(mi)
		_pose_parts[part.name] = {"node": mi, "rest": part.xform}
		if part.body >= 0:
			mi.set_surface_override_material(part.body, _material)


static var _warned_asset := false
static var _shared: Array = []


static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var scene := (load(ModelVariants.path("res://assets/models/world_one/enemy_chaser.glb")) as PackedScene).instantiate()
	var charcoal := Palette.solid(Palette.CHARCOAL)
	var visor := Palette.solid(ACCENT, 3.0)
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate()
		var body := -1
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("chaser: surface has no material; using default finish")
			var slot := surface_material.resource_name if surface_material != null else ""
			if slot == "fleet_paint":
				body = i
			mesh.surface_set_material(i, visor if slot == "requisition_tag" else charcoal)
		_shared.append({"name": String(mi.name), "mesh": mesh, "xform": mi.transform, "body": body})
	scene.free()
	return _shared


static func stage_speed(stage: int) -> float:
	var dial := ChallengeDials.by_stage_or("mobs.chaser_speed_by_stage", stage, 0.0)
	return clampf(dial, SPEED, SPEED_CEILING) if dial > 0.0 else SPEED


func _pace() -> float:
	return SPEED if _age < ENTRY_GRACE_S else run_speed


func state_name() -> String:
	return ["chase", "windup", "lunge", "recover", "call"][state]


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	if not _in_play() or target == null:
		AttackBudget.withdraw(self)
		_cue_step(delta)
		_move(delta, Vector3.ZERO)
		return
	_cue_advance(delta)
	_clock += delta
	_age += delta
	_rest = maxf(0.0, _rest - delta)
	_vault_cd = maxf(0.0, _vault_cd - delta)
	var to_ball := _flat_to_ball()
	match state:
		State.CHASE:
			var lead := PackPressure.lead_now(pressure, target)
			if pressure.get("flanker", false):
				_flank(delta, to_ball)
			elif lead > 0.0:
				_lead_chase(delta, to_ball, lead)
			else:
				var desired := Vector3.ZERO
				var reach := radius + 1.4
				var ball_sq := to_ball.length_squared()
				if ball_sq > reach * reach:
					desired = to_ball.normalized() * _pace()
				_move(delta, desired)
				if _rest <= 0.0 and _wants_vault(to_ball):
					if AttackBudget.ask(self):
						_begin_vault()
				elif _rest <= 0.0 and ball_sq < LUNGE_RANGE * LUNGE_RANGE and is_on_floor() and _knocked_speed() < 1.0:
					if AttackBudget.ask(self):
						_begin_windup(to_ball)
				else:
					AttackBudget.withdraw(self)
		State.CALL:
			_move(delta, _toward(_flat(_flank_point() - global_position)))
			if _knocked_speed() >= INTERRUPT:
				_end_attack(State.RECOVER)
			elif _clock >= PackPressure.PRESSURE_CUE_S:
				if is_on_floor() and _knocked_speed() < 1.0:
					_begin_windup(_led_aim(1.0))
				else:
					_end_attack(State.RECOVER)
		State.WINDUP:
			_move(delta, Vector3.ZERO)
			var tele := telegraph()
			var dur := VAULT_WINDUP if _vaulting else WINDUP
			if tele != null:
				tele.set_progress(_clock / dur)
			if _knocked_speed() >= INTERRUPT or tele == null:
				if _knocked_speed() >= INTERRUPT and tele != null:
					_show_interrupted()
				_end_attack(State.RECOVER)
			elif _clock >= dur:
				state = State.LUNGE
				_clock = 0.0
				if _vaulting:
					velocity = _vault_launch
					if world_root != null and is_inside_tree():
						FxLibrary.burst(world_root, "steam_puff", global_position, 5)
		State.LUNGE:
			var tele := telegraph()
			if tele == null:
				_end_attack(State.RECOVER)
				_paint_cue()
				return
			if _vaulting:
				_step_vault(delta, tele)
			else:
				_move(delta, tele.dir * LUNGE_LENGTH / LUNGE_TIME)
				var along: float = (global_position - tele.center).dot(tele.dir)
				tele.run_body(along, hit_reach())
				_check_hit(tele)
				if _clock >= LUNGE_TIME or along >= tele.length:
					_end_attack(State.RECOVER)
		State.RECOVER:
			_move(delta, Vector3.ZERO)
			if _clock >= RECOVER:
				state = State.CHASE
				_clock = 0.0
	_pose()
	_paint_cue()


func _lead_chase(delta: float, to_ball: Vector3, lead: float) -> void:
	_move(delta, _toward(_intercept(lead)))
	if _rest <= 0.0 and _wants_vault(to_ball):
		if AttackBudget.ask(self):
			_begin_vault()
		return
	var aim := _led_aim(lead)
	if _rest <= 0.0 and aim.length() < LUNGE_RANGE and is_on_floor() and _knocked_speed() < 1.0:
		if AttackBudget.ask(self):
			_begin_windup(aim)
	else:
		AttackBudget.withdraw(self)


func _flank(delta: float, to_ball: Vector3) -> void:
	_move(delta, _toward(_flat(_flank_point() - global_position)))
	var ahead := _flat(PackPressure.predict(target, FLANK_CALL_S) - global_position)
	var coming: bool = target.planar_velocity().dot(-to_ball) > 0.0
	if _rest <= 0.0 and ahead.length() < LUNGE_RANGE and coming and is_on_floor() and _knocked_speed() < 1.0:
		if AttackBudget.ask(self):
			state = State.CALL
			_clock = 0.0
			pressure_cue.emit("flank_call", global_position, PackPressure.PRESSURE_CUE_S + WINDUP)
	else:
		AttackBudget.withdraw(self)


func _flank_point() -> Vector3:
	var ahead := PackPressure.predict(target, FLANK_AHEAD_S)
	var v: Vector3 = target.planar_velocity()
	if v.length() < 1.0:
		return ahead
	var side := Vector3(-v.z, 0.0, v.x).normalized()
	if side.dot(global_position - ahead) < 0.0:
		side = -side
	return ahead + side * FLANK_SIDE


func _led_aim(lead: float) -> Vector3:
	var now := _ball()
	var t := WINDUP + _flat(now - global_position).length() / LUNGE_SPEED
	var at := PackPressure.predict(target, t)
	t = WINDUP + _flat(at - global_position).length() / LUNGE_SPEED
	at = PackPressure.predict(target, t)
	return _flat(now.lerp(at, lead) - global_position)


func _intercept(lead: float) -> Vector3:
	var steps := 10
	var best := PackPressure.predict(target, PackPressure.MAX_LEAD_S * lead)
	for i in range(steps + 1):
		var t := PackPressure.MAX_LEAD_S * lead * float(i) / steps
		var at := PackPressure.predict(target, t)
		if _flat(at - global_position).length() - _pace() * t <= LUNGE_RANGE * 0.8:
			best = at
			break
	return _flat(best - global_position)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _toward(offset: Vector3) -> Vector3:
	return offset.normalized() * _pace() if offset.length() > radius + 1.4 else Vector3.ZERO


func is_vaulting() -> bool:
	return _vaulting and (state == State.WINDUP or state == State.LUNGE)


func _wants_vault(to_ball: Vector3) -> bool:
	if target == null or _vault_cd > 0.0 or not is_on_floor() or _knocked_speed() >= 1.0:
		return false
	if target.has_method("sees") and not target.sees():
		return false
	var dist := to_ball.length()
	if dist > VAULT_RANGE or dist < 0.5:
		return false
	var ball := _ball()
	var ground_y: float = Telegraph.ground_under(terrain, ball) if terrain != null else 0.0
	var player = _real_player()
	var grounded: bool = player != null and player.get("state") != null and bool(player.state.grounded)
	var clearance := (ball.y - ground_y) - VAULT_BALL_RADIUS
	var airborne := (not grounded or clearance > VAULT_AIR_MIN + 1.0) and clearance > VAULT_AIR_MIN
	var rise := ball.y - global_position.y
	var up_bank := (dist > VAULT_BANK_DIST and rise >= VAULT_BANK_RISE) or rise > VAULT_BANK_DIST
	return airborne or up_bank


func _begin_windup(to_ball: Vector3) -> void:
	state = State.WINDUP
	_vaulting = false
	_vault_parried = false
	_clock = 0.0
	_landed = false
	_commit_lane(Threat.Type.LANE, global_position, to_ball, LUNGE_LENGTH, LUNGE_WIDTH).run_body(0.0, hit_reach())


func _begin_vault() -> void:
	state = State.WINDUP
	_vaulting = true
	_vault_parried = false
	_clock = 0.0
	_landed = false
	var ball := _ball()
	var pv: Vector3 = target.planar_velocity() if target != null and target.has_method("planar_velocity") else Vector3.ZERO
	var aim := ball
	if Vector2(pv.x, pv.z).length() < VAULT_SLOW_CAP:
		var offset := _flat((ball + pv * VAULT_SLOW_LEAD_S) - global_position)
		if offset.length() > VAULT_RANGE:
			offset = offset.normalized() * VAULT_RANGE
		aim = Vector3(global_position.x + offset.x, ball.y, global_position.z + offset.z)
	var land_y: float = Telegraph.ground_under(terrain, aim) if terrain != null else aim.y
	_vault_from = global_position
	_vault_to = Vector3(aim.x, land_y + half_height, aim.z)
	var landing := Vector3(aim.x, land_y, aim.z)
	_vault_launch = (_vault_to - _vault_from) / VAULT_FLIGHT
	_vault_launch.y += 0.5 * GRAVITY * VAULT_FLIGHT
	_clear_telegraph()
	_telegraph = Telegraph.secondary_ring(world_root, terrain, Threat.Type.PROJECTILE, landing, VAULT_RADIUS, VAULT_WINDUP, VAULT_REACH)
	_telegraph.owner_voice = "clank"
	_telegraph.mechanic_tag = "vault_rise"
	_telegraph.set_flight(_vault_from + Vector3.UP * 0.5, Threat.lob_bump(GRAVITY, VAULT_FLIGHT))
	_facts_begin(_telegraph)


func _step_vault(_delta: float, ring: Node3D) -> void:
	velocity.x = _vault_launch.x
	velocity.z = _vault_launch.z
	velocity.y = _vault_launch.y - GRAVITY * _clock
	move_and_slide()
	if _check_air_parry():
		return
	if _clock >= VAULT_FLIGHT:
		var real_ball := _real_ball()
		if not _landed and ring.contains(real_ball):
			_landed = true
			landed_attack = "spring_vault"
			var away := _flat(real_ball - ring.center)
			var dir := away.normalized() if away.length() > 0.1 else Vector3.FORWARD
			hit_player.emit(VAULT_DAMAGE, dir * VAULT_SHOVE + Vector3.UP * 2.5)
		_end_attack(State.RECOVER)


func _real_player():
	if target == null:
		return null
	return target.get("player") if "player" in target else target


func _real_ball() -> Vector3:
	var player = _real_player()
	if player != null and player.has_method("ball_position"):
		return player.ball_position()
	return _ball()


func _check_air_parry() -> bool:
	if _vault_parried or _dead:
		return false
	var player = _real_player()
	if player == null or not player.has_method("ball_position"):
		return false
	var ball: Vector3 = player.ball_position()
	if ball.distance_to(global_position) > AIR_PARRY_REACH:
		return false
	var kit = player.get("kit")
	var grapple_bump: bool = (kit != null and kit.hooked and kit.anchor_body == self) or _line_lean_goal != 0.0
	var pv: Vector3 = player.planar_velocity() if player.has_method("planar_velocity") else Vector3.ZERO
	var fast_ram: bool = Vector2(pv.x, pv.z).length() >= 12.0
	if not (grapple_bump or fast_ram):
		return false
	_air_parry(true)
	return true


func on_struck(hit_kind: String, _part: String, result: Dictionary) -> void:
	if state == State.LUNGE and _vaulting and not _vault_parried and hit_kind in ["ram", "stomp", "slam"]:
		result["dealt"] = maxf(float(result.get("dealt", 0.0)), hp + 1.0)
		_air_parry(false)


func _air_parry(kill_now: bool) -> void:
	if _vault_parried or _dead:
		return
	_vault_parried = true
	air_parries += 1
	_vaulting = false
	_clear_telegraph()
	AttackBudget.release(self)
	var player = _real_player()
	if player != null and is_instance_valid(player):
		var v: Vector3 = player.planar_velocity() if player.has_method("planar_velocity") else Vector3.ZERO
		var fwd := Vector3(v.x, 0.0, v.z)
		if fwd.length() < 0.5 and player.has_method("ball_position"):
			fwd = _flat(player.ball_position() - global_position)
		if fwd.length() < 0.1:
			fwd = Vector3.FORWARD
		var step := maxf(get_physics_process_delta_time(), 1.0 / 90.0)
		if player.has_method("add_external_accel"):
			player.add_external_accel((fwd.normalized() * AIR_PARRY_KICK + Vector3.UP * 3.0) / step)
		if player.has_method("refresh_air"):
			player.refresh_air()
	if world_root != null and is_inside_tree():
		FxLibrary.burst(world_root, "brass_spark", global_position, 14)
		FxLibrary.burst(world_root, "spark_core", global_position, 10, Palette.SAND)
	if kill_now:
		take_damage(hp + 1.0)


func hit_reach() -> float:
	return radius + 1.4


func _check_hit(lane: Node3D) -> void:
	if _landed:
		return
	var ball := _real_ball()
	var flat := Vector3(ball.x - global_position.x, 0.0, ball.z - global_position.z)
	if flat.length() > hit_reach() or not lane.contains(ball):
		return
	_landed = true
	landed_attack = "lunge"
	hit_player.emit(DAMAGE, lane.dir * SHOVE + Vector3.UP * 2.0)


func _end_attack(next: int) -> void:
	if _vaulting:
		_vault_cd = VAULT_COOLDOWN
	if state == State.LUNGE:
		if _vaulting:
			vaults += 1
		else:
			lunges += 1
	_vaulting = false
	_vault_parried = false
	state = next
	_clock = 0.0
	_rest = REST * float(pressure.get("rest", 1.0))
	_clear_telegraph()
	AttackBudget.release(self)


func _pose() -> void:
	if _mesh == null:
		return
	var dt := get_physics_process_delta_time()
	var tele := telegraph() if state == State.WINDUP or state == State.LUNGE else null
	var face: Vector3 = _flat(_vault_to - global_position) if _vaulting and tele != null else (tele.dir if tele != null else _flat_to_ball())
	if face.length_squared() > 0.0001:
		_mesh.rotation.y = lerp_angle(_mesh.rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-14.0 * dt))
	var shift := Vector3.ZERO
	var pitch := 0.0
	var flare := 0.0
	if windup_pose_enabled and tele != null and not _dead and not is_queued_for_deletion():
		if _vaulting:
			if state == State.WINDUP:
				var t := smoothstep(0.0, 1.0, clampf(_clock / VAULT_WINDUP, 0.0, 1.0))
				shift = VAULT_COIL_SHIFT * t
				pitch = deg_to_rad(VAULT_COIL_PITCH) * t
				flare = deg_to_rad(40.0) * t
			elif state == State.LUNGE:
				var arc_t := clampf(_clock / VAULT_FLIGHT, 0.0, 1.0)
				shift = Vector3(0.0, 0.12 * sin(PI * arc_t), 0.0)
				pitch = lerpf(deg_to_rad(24.0), deg_to_rad(-28.0), arc_t)
				flare = deg_to_rad(20.0) * (1.0 - arc_t)
		elif state == State.WINDUP:
			var t := smoothstep(0.0, 1.0, clampf(_clock / WINDUP, 0.0, 1.0))
			shift = REAR_SHIFT * t
			pitch = deg_to_rad(REAR_PITCH) * t
			flare = deg_to_rad(32.0) * t
		elif state == State.LUNGE:
			var snap := smoothstep(0.0, 1.0, clampf(_clock / 0.08, 0.0, 1.0))
			shift = REAR_SHIFT.lerp(Vector3(0.0, -0.08, -0.25), snap)
			pitch = lerpf(deg_to_rad(REAR_PITCH), deg_to_rad(-12.0), snap)
			flare = deg_to_rad(32.0) * (1.0 - snap)
	if pitch == 0.0 and shift == Vector3.ZERO and flare == 0.0:
		if _parts_off_rest:
			_parts_off_rest = false
			for part in _pose_parts.values():
				part.node.transform = part.rest
		return
	_parts_off_rest = true
	var body_pose := Transform3D(Basis(Vector3.RIGHT, pitch), shift)
	for part_name in _pose_parts:
		var part: Dictionary = _pose_parts[part_name]
		var node: Node3D = part.node
		var rest: Transform3D = part.rest
		match part_name:
			"ChaserBody":
				node.transform = body_pose * rest
			"ChaserFin":
				node.transform = body_pose * rest * Transform3D(Basis(Vector3.RIGHT, flare), Vector3.ZERO)
			_:
				node.transform = rest


func cue_state() -> String:
	if not body_cue_enabled or _dead:
		return ""
	if state == State.WINDUP:
		return "will_break"
	if _interrupted_left > 0.0:
		return "interrupted"
	return ""


func _show_interrupted() -> void:
	if not body_cue_enabled:
		return
	_interrupted_left = INTERRUPT_SHOWN
	react("launch", _knock)


func _cue_step(delta: float) -> void:
	_cue_advance(delta)
	_paint_cue()


func _cue_advance(delta: float) -> void:
	_interrupted_left = maxf(0.0, _interrupted_left - delta)
	_cue_clock += delta


func _paint_cue() -> void:
	var row := cue_state()
	if row == "":
		if _cue_painted:
			_cue_painted = false
			if _flash <= 0.0:
				_apply_rest_look()
		return
	_cue_painted = true
	_material.emission_enabled = true
	_material.emission = EventKinds.state_color(row)
	var swing := 1.0
	if String(EventKinds.state_row(row).get("motion", "none")) == "pulse":
		swing += PULSE_DEPTH * sin(TAU * PULSE_HZ * _cue_clock)
	_material.emission_energy_multiplier = PLATE_GLOW_LIVE * swing


func _apply_rest_look() -> void:
	super()
	_paint_cue()
