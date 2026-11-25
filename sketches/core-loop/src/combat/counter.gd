extends "res://src/combat/enemy.gd"

const Roster := preload("res://src/combat/roster.gd")
const TelegraphRecord := preload("res://src/combat/telegraph_record.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const CrewLamp := preload("res://src/presentation/crew_lamp.gd")

enum Phase { ROAM, WARN, LIVE }

const INTERRUPT := 10.0
const STRIDE_RAMP := 0.15
const GAIT_SKIP := ["linker"]
const STAGGER_WINDOW := 1.25
const STATE_PRIORITY := [0, 1, 3]
const KNOCK_PRIORITY := 2
const BREAK_PRIORITY := 4
const CREW_RADIUS := 0.8
const CREW_HALF := 1.1
const HEAD_RADIUS := 0.38
const TAG_SIZE := Vector3(0.36, 0.24, 0.06)

var holds
var fleet
var row := {}
var phase := Phase.ROAM
var warned := 0
var caught := 0
var last_warn := 0.0
var broken_by := ""
var caught_live := 0

var walk_speed := 3.8
var keep_near := 9.0
var keep_far := 24.0
var attack_range := 22.0
var warn_seconds := 1.0
var live_seconds := 1.0
var rest_seconds := 3.0
var first_rest := 1.5
var interruptible := true
var impact_resist := 1.0
var stun_left := 0.0
var staggers := 0
var recovery_seconds := TelegraphRecord.RECOVERY
var recover_left := 0.0

var _t := 0.0
var _rest := 0.0
var _strafe := 1.0
var _crew: MeshInstance3D
var _stride := Vector3.ZERO
var _eye: Node3D


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = spec.get("kind", "chaser")
	row = Roster.row(kind)
	faction = Roster.faction_of(kind)
	holds = spec.get("holds")
	fleet = spec.get("fleet")
	if holds != null:
		holds.released.connect(_on_hold_released)
	_strafe = float(get_meta("bot_strafe")) if has_meta("bot_strafe") else _spawn_order_sign()
	var stage_threat: float = spec.get("stage_threat", threat)
	_configure(stage_threat)
	if spec.has("stage_threat"):
		_set_health(max_hp / stage_threat * threat)
	keep_far = minf(keep_far, attack_range * 0.9)
	_rest = first_rest
	_build_crew()
	_build_tool()
	_eye = CrewLamp.fit(reaction_pivot, kind, world_root)
	if walk_speed > 0.0 and not kind in GAIT_SKIP:
		_gait = EnemyGait.new()
		_gait.steps = not EnemyClips.ROWS.has(kind) and Roster.CHASSIS.get(kind, {}).get("move_class", "") != "airborne"
		if _reaction_bus != null:
			_reaction_bus.enemy_killed.connect(_on_crew_down)
			_reaction_bus.player_hit.connect(_on_ball_hit)
			_reaction_bus.near_miss.connect(_on_missed)


func _spawn_order_sign() -> float:
	if world_root == null:
		return 1.0
	var serial := int(world_root.get_meta("counter_spawn_serial", 0))
	world_root.set_meta("counter_spawn_serial", serial + 1)
	return 1.0 if serial % 2 == 0 else -1.0


func state_name() -> String:
	return ["roam", "warn", "live"][phase]


func interrupt_speed() -> float:
	return INTERRUPT * impact_resist if interruptible else INF


func state_priority() -> int:
	return STATE_PRIORITY[phase]


func resolve_interrupt(priorities: Array) -> int:
	return AbilityState.strongest(state_priority(), priorities)


func stunned() -> bool:
	return stun_left > 0.0


func recovering() -> bool:
	return recover_left > 0.0


func _configure(threat: float) -> void:
	_set_health(40.0 * threat)


func _build_tool() -> void:
	pass


func _wants_attack(to_ball: Vector3) -> bool:
	return to_ball.length() <= attack_range and is_on_floor()


func _commit(_to_ball: Vector3) -> Node3D:
	return null


func _go_live() -> void:
	pass


func _warn_progress() -> float:
	return _t / warn_seconds


func windup_run() -> float:
	return clampf(_t / maxf(warn_seconds, 0.001), 0.0, 1.0) if phase == Phase.WARN else -1.0


func _live(_delta: float) -> bool:
	return true


func _on_end() -> void:
	pass


func _pose() -> void:
	pass


const SEEK_LEAD_S := 1.0


func _seek(to_ball: Vector3) -> Vector3:
	var lead := PackPressure.lead_now(spec.get("pressure", {}), target)
	if lead <= 0.0:
		return to_ball
	var at: Vector3 = PackPressure.predict(target, SEEK_LEAD_S * lead) - global_position
	return Vector3(at.x, 0.0, at.z)


func _roam(to_ball: Vector3) -> Vector3:
	var distance := to_ball.length()
	if distance < 0.1:
		return Vector3.ZERO
	var toward := to_ball / distance
	if distance > keep_far:
		return toward * walk_speed
	if distance < keep_near:
		return -toward * walk_speed
	return toward.cross(Vector3.UP) * _strafe * walk_speed * 0.5


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	if not _in_play() or target == null:
		_idle(delta)
		return
	_t += delta
	stun_left = maxf(0.0, stun_left - delta)
	var to_ball := _flat_to_ball()
	match phase:
		Phase.ROAM:
			_rest -= delta
			var open := recovering()
			recover_left = maxf(0.0, recover_left - delta)
			var seek := _seek(to_ball)
			_move(delta, _ramp(delta, Vector3.ZERO if stunned() or open else _roam(seek)))
			_strode()
			if _gait != null and not stunned() and _knocked_speed() < 1.0 and seek.length() > 0.5:
				_gait.aim(_facing_yaw(seek))
			if not stunned() and not open and _rest <= 0.0 and _knocked_speed() < 1.0 and _wants_attack(seek):
				if AttackBudget.ask(self):
					_warn(seek)
			else:
				AttackBudget.withdraw(self)
		Phase.WARN:
			_stride = Vector3.ZERO
			_move(delta, Vector3.ZERO)
			var tele := telegraph()
			if tele != null:
				tele.set_progress(_warn_progress())
			if tele == null:
				_end()
			elif _knocked_speed() >= interrupt_speed() and resolve_interrupt([KNOCK_PRIORITY]) == 0:
				_stagger()
			elif _t >= warn_seconds:
				last_warn = _t
				phase = Phase.LIVE
				_t = 0.0
				caught_live = 0
				_facts_phase(PHASE_STRIKE)
				_go_live()
		Phase.LIVE:
			_move(delta, _live_motion(to_ball))
			var asks := []
			if broken_by != "":
				asks.append(BREAK_PRIORITY)
			if _knocked_speed() >= interrupt_speed():
				asks.append(KNOCK_PRIORITY)
			if resolve_interrupt(asks) >= 0 or not _live(delta) or _t >= live_seconds:
				_end()
	_pose()
	if _eye != null:
		_eye.watch(delta, _t / maxf(warn_seconds, 0.001) if phase == Phase.WARN else (1.0 if phase == Phase.LIVE else 0.0))


func _ramp(delta: float, desired: Vector3) -> Vector3:
	_stride = _stride.move_toward(desired, maxf(walk_speed, desired.length()) / STRIDE_RAMP * delta)
	return _stride


func _strode() -> void:
	var moved := Vector3(velocity.x, 0.0, velocity.z)
	if _knocked_speed() >= 1.0 or moved.length() < _stride.length():
		_stride = moved


func _idle(delta: float) -> void:
	_move(delta, Vector3.ZERO)


func _live_motion(_to_ball: Vector3) -> Vector3:
	return Vector3.ZERO


func _warn(to_ball: Vector3) -> void:
	var tele := _commit(to_ball)
	if tele == null:
		AttackBudget.release(self)
		_rest = 0.5
		return
	_voice(tele)
	_facts_manage(tele)
	warned += 1
	broken_by = ""
	phase = Phase.WARN
	if _gait != null:
		_gait.hold()
	_t = 0.0


func _voice(tele: Node3D) -> void:
	var motif := _motif()
	tele.owner_voice = Roster.voiced(String(Roster.faction(faction)["voice"]), motif)
	tele.mechanic_tag = Roster.voiced(String(row.get("tag", "")), motif)


func _motif() -> String:
	var player = _player()
	if player == null or player.class_def == null:
		return ""
	return String(player.class_def.motif)


func _on_hold_released(source_id: int, _kind: String, reason: String) -> void:
	if source_id != get_instance_id() or not reason in holds.PLAYER_BREAKS:
		return
	broken_by = reason
	_on_broken(reason)


func _on_broken(_method: String) -> void:
	pass


func stagger() -> void:
	_stagger()


func prime_attack() -> void:
	_rest = 0.0
	recover_left = 0.0
	stun_left = 0.0


func _stagger() -> void:
	_end()
	staggers += 1
	stun_left = STAGGER_WINDOW
	_rest = maxf(_rest, STAGGER_WINDOW)


func _end() -> void:
	recover_left = recovery_seconds if phase == Phase.LIVE else 0.0
	_facts_end(false)
	if holds != null and holds.held(self):
		holds.release(self, "expired")
	_on_end()
	_clear_telegraph()
	AttackBudget.release(self)
	phase = Phase.ROAM
	_t = 0.0
	_rest = rest_seconds * float(spec.get("rest_scale", 1.0)) * float(spec.get("pressure", {}).get("rest", 1.0))


func _catch(max_seconds := 0.0, shove := Vector3.ZERO, anchor = null) -> bool:
	if holds == null:
		return false
	var fresh: bool = not holds.held(self)
	var ok: bool = holds.catch(self, String(row["mechanic"]), row["breaks"], max_seconds, shove, anchor)
	if ok and fresh:
		caught += 1
		caught_live += 1
	return ok


func _pull(accel: Vector3) -> bool:
	return holds != null and holds.pull(self, accel)


func _holding() -> bool:
	return holds != null and holds.held(self)


func _release(reason := "left") -> void:
	if holds != null:
		holds.release(self, reason)


const NOTICE_DOWN := 12.0
const NOTICE_HIT := 18.0
const NOTICE_MISS := 25.0


func _noticing() -> bool:
	return _gait != null and not _dead and EnemyMotion.active()


func _on_crew_down(_kind: String, at: Vector3, _scrap: int) -> void:
	var from := Vector3(at.x - global_position.x, 0.0, at.z - global_position.z)
	if not _noticing() or from.length() > NOTICE_DOWN or from.length() < 0.5:
		return
	if phase == Phase.ROAM:
		_gait.glance(_facing_yaw(from))
	if _react_row.is_empty():
		react("flinch", -from, false, false)


func _on_ball_hit(_amount: float, _source: String) -> void:
	if _noticing() and _flat_to_ball().length() <= NOTICE_HIT:
		_gait.hop()


func _on_missed(_threat_kind: String, at: Vector3) -> void:
	if not _noticing() or not _just_struck() or global_position.distance_to(at) > NOTICE_MISS:
		return
	for other in get_tree().get_nodes_in_group("enemy"):
		if other != self and other.has_method("_just_struck") and other._just_struck() \
				and other.global_position.distance_to(at) < global_position.distance_to(at):
			return
	if _react_row.is_empty():
		react("flinch", _flat_to_ball(), false, false)


func _just_struck() -> bool:
	return phase == Phase.LIVE or recovering()


func _real_ball() -> Vector3:
	return holds.player.ball_position() if holds != null else _ball()


func _ahead(seconds: float, reach: float) -> Vector3:
	var at := _ball()
	if target == null or not target.has_method("planar_velocity"):
		return at
	var keep := float(spec.get("pressure", {}).get("lead_cruise", 1.0))
	seconds *= PackPressure.lead_now({"lead": 1.0, "lead_cruise": keep}, target)
	var on: Vector3 = PackPressure.predict(target, seconds) - at
	on.y = 0.0
	return at + on.limit_length(reach)


func _player():
	return holds.player if holds != null else null


func _exit_tree() -> void:
	if holds != null and is_instance_valid(holds) and holds.held(self):
		holds.release(self, "source_gone")
	if is_instance_valid(_reaction_bus) and _reaction_bus.enemy_killed.is_connected(_on_crew_down):
		_reaction_bus.enemy_killed.disconnect(_on_crew_down)
		_reaction_bus.player_hit.disconnect(_on_ball_hit)
		_reaction_bus.near_miss.disconnect(_on_missed)
	super._exit_tree()


func _enamel() -> StandardMaterial3D:
	var mat := Palette.solid(Roster.ANCIENT_ENAMEL)
	mat.metallic = 0.2
	mat.roughness = 0.35
	return mat


func _seam(size: Vector3, at: Vector3, parent: Node3D = self) -> MeshInstance3D:
	return _box(size, Roster.ANCIENT_LIGHT, at, 2.2, parent)


func _build_crew() -> void:
	radius = CREW_RADIUS
	half_height = CREW_HALF
	_crew = _add_capsule(CREW_RADIUS, CREW_HALF * 2.0, Palette.RUST)
	var head := SphereMesh.new()
	head.radius = HEAD_RADIUS
	head.height = HEAD_RADIUS * 2.0
	_accent(head, Palette.RUST.darkened(0.15), 0.0, Vector3(0.0, CREW_HALF + 0.2, 0.0), _crew)
	for side in [-1.0, 1.0]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.13
		ear.height = 0.34
		_accent(ear, Palette.CHARCOAL, 0.0, Vector3(side * 0.2, CREW_HALF + 0.55, 0.0), _crew)
	var tag := BoxMesh.new()
	tag.size = TAG_SIZE
	_accent(tag, Palette.BRASS, 0.8, Vector3(0.0, 0.3, CREW_RADIUS + 0.02), _crew)


func _tool_material(color := Palette.CHARCOAL, energy := 0.0) -> StandardMaterial3D:
	return Palette.solid(color, energy)


func _box(size: Vector3, color: Color, at: Vector3, energy := 0.0, parent: Node3D = self) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _accent(box, color, energy, at, parent)


func _cylinder(r: float, h: float, color: Color, at: Vector3, energy := 0.0, parent: Node3D = self) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = h
	return _accent(cyl, color, energy, at, parent)


func _facing(to_ball: Vector3) -> void:
	if to_ball.length() > 0.5:
		rotation.y = _facing_yaw(to_ball)
		if _gait != null:
			_gait.committed()


func _settle_look() -> void:
	super._settle_look()
	if _eye != null:
		_eye.go_out()


func _facing_yaw(to_ball: Vector3) -> float:
	return atan2(to_ball.x, to_ball.z)
