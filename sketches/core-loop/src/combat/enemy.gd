extends CharacterBody3D

const Palette := preload("res://src/core/palette.gd")
const Groups := preload("res://src/core/groups.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")
const InkOutline := preload("res://src/presentation/ink_outline.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Contact := preload("res://src/movement/contact.gd")
const BallRules := preload("res://src/movement/ball_rules.gd")
const _Tuning := preload("res://src/movement/tuning.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const EnemyClips := preload("res://src/presentation/enemy_clips.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const WindupPoses := preload("res://src/presentation/windup_poses.gd")
const EnemyGait := preload("res://src/presentation/enemy_gait.gd")
const _Roster := preload("res://src/combat/roster.gd")
const Comfort := preload("res://src/core/comfort.gd")

const GROUP := Groups.ENEMY
const GRAVITY := _Tuning.GRAVITY
const KNOCK_DECAY := 16.0
const FLOOR_RESCUE := 30.0
const RALLY_ARRIVE := 0.5
const RALLY_MAX_SPEED := 48.0
const RALLY_MIN_SPEED := 8.0
const RALLY_INTERRUPT_KNOCK := 5.0
const RING_OUT_WORLD := 3
const RING_OUT_DROP := 6.0
const RING_OUT_KEPT := ["warden", "vault", "miniboss", "reactor_relic", "swarm_remnant", "mind_hand",
	"foreman", "dispatcher", "splitter", "linker", "rogue_crane", "rogue_skip", "rogue_tender"]
static var _ring_out_kept := _as_set(RING_OUT_KEPT)
const _NON_ORDINARY := {"warden": true, "vault": true, "miniboss": true, "rogue_crane": true, "rogue_skip": true, "rogue_tender": true}
const PLATE_CLOSED := Color("3b403d")
const TINT_ENERGY := 0.9
const PLATE_GLOW_LIVE := 1.8
const PLATE_GLOW_SLATE := 0.5
const PULSE_DEPTH := 0.14
const PULSE_HZ := 2.0
const GLANCE_SECONDS := 0.9
const GLANCE_BEATS := 2.0
const GLANCE_PEAK := 4.0
const RIM_CELL := 8
const RIM_EDGE := 2

signal hit_player(amount: float, shove: Vector3)
signal died(at: Vector3, scrap_value: int)
signal attack_phase(facts: Dictionary)

const PHASE_WINDUP := "windup"
const PHASE_STRIKE := "strike"
const STRIKE_FRAMES := 2
const STRIKE_DONE := -1
const STRIKE_TINT := 0.85
const STRIKE_GLOW := 1.6
const PHASE_RECOVER := "recover"
const PHASE_CANCELLED := "cancelled"
const FACTS_UNMAPPED := {
	"swarm_remnant": "the formation lane is committed and driven by swarm.gd, not by the remnant's own state",
}
static var _attack_serial := 0
static var _variables_by_script := {}

var kind := "chaser"
var faction := "fleet"
var target
var terrain
var world_root: Node3D
var live := Callable()
var spec := {}
var hp := 40.0
var max_hp := 40.0
var plating := 0.0
var scrap_value := 3
var last_damage_source := ""
var ringed_out := false
var _ring_from := INF
var weight := 1.0
var threat_level := 1.0


func anchor_point(point: Vector3, _from = null) -> Vector3:
	return point


func anchor_velocity() -> Vector3:
	return velocity
var radius := 1.0
var half_height := 1.5
var tint_state := ""
var knocks := 0
var wall_slams := 0
var _walled_knock := -1

var _knock := Vector3.ZERO
var _rally_left := 0.0
var _rally_target := Vector3.ZERO
var _flash := 0.0
var _strike_frames := 0
var _dead := false
var _material: StandardMaterial3D
var _base_color := Palette.RUST
var _telegraph: Node3D
var _tint_materials: Array = []
# Godot BaseMaterial3D frees its shader when its last material is freed (~12-15 ms compile hitch on stage swap).
static var _plate_shaders: Array[Material] = []
var _cracks: Array = []
var _rim_clock := 0.0
var _glance_left := 0.0
var _atk := {}


var reactions_enabled := true
var reaction_pivot: Node3D
var _reaction_bus: Node
var _react_row := {}
var _react_time := 0.0
var _react_duration := 0.0
var _react_start := Quaternion.IDENTITY
var _react_pose := Quaternion.IDENTITY
var _react_direction := Vector3.FORWARD
var _react_speed := 0.0
var _reaction_handed := false
var _line_lean := 0.0
var _line_lean_goal := 0.0
var _line_lean_from := 0.0
var _line_lean_time := LINE_EASE
const LINE_LEAN := 10.0
const LINE_EASE := 0.15
var idle_offset := Vector3.ZERO
var _idle_pose := Basis.IDENTITY
const IDLE_FADE_OUT := 0.12
const IDLE_FADE_IN := 0.15
const POSE_EASE := 0.12
var _idle_mix := 1.0
var _idle_held := Vector3.ZERO
var _was_winding := false
var _wind_pose := Basis.IDENTITY
var _eased_from := Basis.IDENTITY
var _ease_age := -1.0
var _posed := ""
var _posing := false
var _posed_struck := false
var _posed_instance := -1
var _release_age := -1.0
var _idle_clock := -1.0
var _idle_period := 0.0
var _clips: Node
var _clips_tried := false
var _gait: EnemyGait


func _visual_parent() -> Node3D:
	if reaction_pivot == null:
		reaction_pivot = Node3D.new()
		reaction_pivot.name = "ReactionPivot"
		add_child(reaction_pivot)
	return reaction_pivot


var _ordinary_kind := ""
var _ordinary_cached := true


static func is_ordinary_kind(enemy_kind: String) -> bool:
	return not _NON_ORDINARY.has(enemy_kind) and not _Roster.is_boss_piece(enemy_kind)


func is_fleet_husk_eligible() -> bool:
	if ringed_out or is_in_group("spectator"):
		return false
	if not is_ordinary_kind(kind):
		return false
	return _Roster.has(kind) and _Roster.faction_of(kind) == _Roster.FLEET


func _ordinary_reaction() -> bool:
	if kind != _ordinary_kind:
		_ordinary_kind = kind
		_ordinary_cached = is_ordinary_kind(kind)
	return _ordinary_cached


static func _as_set(names: Array) -> Dictionary:
	var out := {}
	for entry in names:
		out[entry] = true
	return out


func react(reaction: String, direction: Vector3, handed := false, struck := true) -> void:
	_reaction_handed = handed
	if not reactions_enabled or _dead or not _ordinary_reaction():
		return
	_react_row = EventKinds.REACTIONS[reaction]
	_react_start = _react_pose
	_react_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	_react_speed = _knocked_speed()
	_react_time = 0.0
	if struck and is_instance_valid(_clips):
		_clips.hit()
	_react_duration = float(_react_row["rise"]) + float(_react_row["hold"]) + float(_react_row["recover"])
	if float(_react_row["tumble"]) > 0.0:
		_react_duration = minf(float(_react_row["limit"]), maxf(_react_duration, _react_speed / KNOCK_DECAY + float(_react_row["recover"])))
	_visual_parent()


func _on_reaction_hit(enemy: Node3D, hit: String, _force: float) -> void:
	if enemy != self:
		return
	if _reaction_handed:
		_reaction_handed = false
		return
	var away := _knock if _knocked_speed() > 0.0 else global_position - _reaction_ball()
	react(String(EventKinds.impact(hit)["react"]), away)


func _reaction_ball() -> Vector3:
	var player = target.get("player") if is_instance_valid(target) and "player" in target else target
	return player.ball_position() if is_instance_valid(player) else global_position


func _on_reaction_line(state: String, held: Node3D, _at: Vector3, _cause: String) -> void:
	if state.begins_with("chain_"):
		return
	if not reactions_enabled or _dead or not _ordinary_reaction():
		return
	if state == "latched_body":
		_set_line_lean(1.0 if held == self else 0.0)
	elif state == "smash_committed":
		if _line_lean_goal != 0.0:
			_set_line_lean(-1.0)
	else:
		_set_line_lean(0.0)


func _set_line_lean(goal: float) -> void:
	if goal == _line_lean_goal:
		return
	_line_lean_from = _line_lean
	_line_lean_goal = goal
	_line_lean_time = 0.0


func _reaction_axis(direction: Vector3) -> Vector3:
	var local := global_basis.inverse() * direction
	var axis := Vector3.UP.cross(local)
	return axis.normalized() if axis.length_squared() > 0.0001 else Vector3.RIGHT


func _update_reaction(delta: float) -> void:
	if not reactions_enabled or not _ordinary_reaction():
		_react_row = {}
		_react_pose = Quaternion.IDENTITY
		_line_lean = 0.0
		_line_lean_goal = 0.0
		_line_lean_from = 0.0
	if not _react_row.is_empty():
		_react_time += delta
		var rise := float(_react_row["rise"])
		var scale_angle := 1.0 / sqrt(maxf(weight, 1.0))
		var axis := _reaction_axis(_react_direction)
		var peak := deg_to_rad(float(_react_row["angle"])) * scale_angle
		if _react_time >= _react_duration:
			_react_pose = Quaternion.IDENTITY
			_react_row = {}
		elif _react_time < rise:
			_react_pose = _react_start.slerp(Quaternion(axis, peak), smoothstep(0.0, rise, _react_time))
		else:
			var recovery := rise + float(_react_row["hold"])
			var progress := clampf((_react_time - recovery) / (_react_duration - recovery), 0.0, 1.0)
			var angle := peak * (1.0 - smoothstep(0.0, 1.0, progress))
			if float(_react_row["tumble"]) > 0.0:
				var knock_share := clampf(_knocked_speed() / maxf(_react_speed, 0.001), 0.0, 1.0)
				angle *= knock_share
				angle += deg_to_rad(float(_react_row["tumble"])) * scale_angle * sin(PI * progress) * knock_share
			elif float(_react_row["overshoot"]) > 0.0:
				var overshoot := -peak * float(_react_row["overshoot"])
				angle = lerpf(peak, overshoot, smoothstep(0.0, 0.72, progress)) if progress < 0.72 else lerpf(overshoot, 0.0, smoothstep(0.72, 1.0, progress))
			_react_pose = Quaternion(axis, angle)
	_line_lean_time = minf(LINE_EASE, _line_lean_time + delta)
	_line_lean = _line_lean_goal if _line_lean_time >= LINE_EASE else lerpf(_line_lean_from, _line_lean_goal, smoothstep(0.0, LINE_EASE, _line_lean_time))
	if reaction_pivot == null and (_line_lean != 0.0 or not _react_row.is_empty()):
		_visual_parent()
	_update_idle(delta)
	var tilt := Transform3D.IDENTITY
	var turn := Transform3D.IDENTITY
	if _gait != null and reaction_pivot != null and not _dead:
		var walking := is_on_floor() and _knocked_speed() < 1.0
		_gait.step(delta, self, velocity, half_height, walking, get_floor_normal() if walking else Vector3.UP, radius)
		tilt = _gait.tilt
		turn = _gait.turn
	if reaction_pivot != null and not _dead:
		var lean_pose := Quaternion.IDENTITY
		if _line_lean != 0.0 and is_instance_valid(target):
			lean_pose = Quaternion(_reaction_axis(_reaction_ball() - global_position), deg_to_rad(LINE_LEAN) * _line_lean)
		var next_xform := tilt * Transform3D(Basis(lean_pose * _react_pose), Vector3.ZERO) * turn * Transform3D(_idle_pose, idle_offset)
		if reaction_pivot.transform != next_xform:
			reaction_pivot.transform = next_xform


func _update_idle(delta: float) -> void:
	idle_offset = Vector3.ZERO
	_idle_pose = Basis.IDENTITY
	if reaction_pivot == null or _dead or not EnemyMotion.active():
		return
	var row: Dictionary = WindupRows.ROWS.get(kind, {})
	if winding_up():
		_was_winding = true
		_ease_age = -1.0
		_idle_mix = move_toward(_idle_mix, 0.0, delta / IDLE_FADE_OUT)
		idle_offset = _idle_held * _idle_mix
		_idle_pose = EnemyMotion.pose_basis(row)
		if row.get("pose", {}).is_empty():
			_idle_pose = _attack_pose()
		else:
			_idle_pose = Transform3D(Basis.IDENTITY, Vector3.ZERO).interpolate_with(Transform3D(_idle_pose, Vector3.ZERO), 1.0 - _idle_mix).basis
		_wind_pose = _idle_pose
		return
	if _posing:
		_posing = false
		_release_age = 0.0 if _posed_struck else -1.0
		_posed_struck = false
		if _release_age < 0.0:
			_posed = ""
	if _was_winding:
		_was_winding = false
		_eased_from = _wind_pose
		_ease_age = 0.0 if _release_age < 0.0 else -1.0
	if _ease_age >= 0.0:
		_ease_age += delta
		var home := smoothstep(0.0, 1.0, _ease_age / POSE_EASE)
		_idle_pose = Transform3D(_eased_from, Vector3.ZERO).interpolate_with(Transform3D.IDENTITY, home).basis
		if _ease_age >= POSE_EASE:
			_ease_age = -1.0
	if _release_age >= 0.0:
		_idle_pose = WindupPoses.release(_posed, _release_age, Comfort.motion_scale())
		_release_age += delta
		if _release_age >= WindupPoses.RELEASE_SECONDS:
			_release_age = -1.0
			_posed = ""
	if _idle_clock < 0.0:
		_idle_period = float(row.get("idle", {}).get("beats", 0.0)) * EnemyMotion.attack_clock(kind, self)
		_idle_clock = float(absi(hash(Vector3i(global_position.round()))) % 97) / 97.0 * _idle_period
	_idle_clock += delta
	_idle_held = EnemyMotion.idle_offset(row.get("idle", {}), _idle_clock, _idle_period)
	_idle_mix = move_toward(_idle_mix, 1.0, delta / IDLE_FADE_IN)
	idle_offset = _idle_held * _idle_mix


func _attack_pose() -> Basis:
	if _atk.is_empty():
		return Basis.IDENTITY
	var pose := EventKinds.attack_pose(String(_atk["row"]))
	if not WindupPoses.has_pose(pose):
		return Basis.IDENTITY
	if int(_atk["instance"]) != _posed_instance:
		_posed_instance = int(_atk["instance"])
		_posed_struck = false
	_posed = pose
	_posing = true
	_release_age = -1.0
	var tele = _atk.get("tele")
	var live := tele != null and is_instance_valid(tele)
	var progress: float = tele.progress if live else float(_atk["progress"])
	_posed_struck = _posed_struck or String(_atk["phase"]) != PHASE_WINDUP or progress >= 1.0
	return WindupPoses.windup(pose, progress, tele.age if live else 0.0, Comfort.motion_scale())


func winding_up() -> bool:
	if not _atk.is_empty() or telegraph() != null:
		return true
	if not WindupRows.has_state_facts(kind):
		return false
	return not WindupRows.state_facts(self).is_empty()


func _death_direction() -> Vector3:
	var away := Vector3(_knock.x, 0.0, _knock.z)
	if away.length_squared() < 0.01:
		away = global_position - _reaction_ball()
		away.y = 0.0
	return away.normalized() if away.length_squared() > 0.0001 else Vector3.ZERO


func _setup_common(target_ref, terrain_ref, root_ref, live_ref: Callable, spec_ref := {}) -> void:
	target = target_ref
	terrain = terrain_ref
	world_root = root_ref
	live = live_ref
	spec = spec_ref
	_reaction_bus = world_root.get_node_or_null("GameEvents") if world_root != null else null
	if _reaction_bus != null:
		_reaction_bus.line_state_changed.connect(_on_reaction_line)
		_reaction_bus.enemy_struck.connect(_on_reaction_hit)
	add_to_group(GROUP)
	collision_layer = PhysicsLayers.NONE
	collision_mask = PhysicsLayers.NONE
	set_collision_layer_value(PhysicsLayers.ENEMY_LAYER, true)
	set_collision_mask_value(PhysicsLayers.WORLD_LAYER, true)
	floor_max_angle = deg_to_rad(60.0)
	if has_signal("released"):
		connect("released", _facts_on_released)


func _set_health(value: float) -> void:
	hp = value
	max_hp = value


func knock(direction: Vector3, force: float) -> void:
	if _dead or direction.length_squared() < 0.0001:
		return
	knocks += 1
	var push := direction.normalized() * force / weight
	if push.length() > Vector3(_knock.x, 0.0, _knock.z).length():
		_knock = Vector3(push.x, _knock.y, push.z)
	_knock.y = maxf(_knock.y, maxf(push.y, force * 0.2 / weight))


func flash() -> void:
	_flash = 1.0


func is_dead() -> bool:
	return _dead


func plating_now() -> float:
	return plating


func armour_class() -> String:
	var own := String(spec.get("armour", ""))
	if own == "" and _soaked_left > 0.0:
		return "wet"
	return own


var _soaked_left := 0.0


func soak(seconds: float) -> void:
	_soaked_left = maxf(_soaked_left, seconds)


func wet() -> bool:
	return armour_class() == "wet"


func plating_for(_kind: String, _part: String) -> float:
	return plating_now()


func hit_mult(_kind: String, _part: String) -> float:
	return 1.0


func weak_points() -> Array:
	return []


func contact_part(_ball: Vector3, _kind: String) -> String:
	return ""


func on_struck(_kind: String, _part: String, _result: Dictionary) -> void:
	pass


func set_tint(state: String) -> void:
	if state == tint_state:
		return
	tint_state = state
	_glance_left = 0.0
	var now := state == "amber"
	for mat in _tint_materials:
		_paint_plate(mat as StandardMaterial3D, state)
	for crack in _cracks:
		if is_instance_valid(crack):
			crack.visible = now
	_rim_clock = 0.0
	if _flash <= 0.0:
		_apply_rest_look()


func damage_scale() -> float:
	return 1.0


func take_damage(amount: float) -> float:
	if _dead:
		return 0.0
	var removed := minf(amount, hp)
	hp -= amount
	flash()
	if hp <= 0.0:
		_die()
	return removed


func telegraph() -> Node3D:
	return _telegraph if is_instance_valid(_telegraph) else null


func _fill(value: float) -> void:
	var shown := telegraph()
	if shown != null:
		shown.set_progress(value)


func _die() -> void:
	_dead = true
	_rally_left = 0.0
	_settle_look()
	_facts_end(true)
	collision_layer = PhysicsLayers.NONE
	collision_mask = PhysicsLayers.NONE
	_clear_telegraph()
	var land := Callable(terrain, "height") if not ringed_out and is_on_floor() and terrain != null else Callable()
	if ringed_out or not (is_instance_valid(_clips) and _clips.die(_death_direction(), land)):
		EnemyMotion.scatter(self, kind, _death_direction(), land)
	if not ringed_out and is_ordinary_kind(kind):
		var tag_land := Callable(terrain, "height") if terrain != null else Callable()
		EnemyMotion.pop_shift_tag(self, kind, _death_direction(), tag_land)
	died.emit(global_position, scrap_value)
	queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_reaction_bus) and _reaction_bus.line_state_changed.is_connected(_on_reaction_line):
		_reaction_bus.line_state_changed.disconnect(_on_reaction_line)
	if is_instance_valid(_reaction_bus) and _reaction_bus.enemy_struck.is_connected(_on_reaction_hit):
		_reaction_bus.enemy_struck.disconnect(_on_reaction_hit)
	_facts_end(true)
	_clear_telegraph()


func _clear_telegraph() -> void:
	_facts_end(false)
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _commit_ring(threat_type: int, at: Vector3, ring_radius: float, reach := 3.5, tint := Palette.HAZARD) -> Node3D:
	_clear_telegraph()
	_telegraph = Telegraph.ring(world_root, terrain, threat_type, at, ring_radius, reach, tint)
	_facts_begin(_telegraph)
	return _telegraph


func _commit_lane(threat_type: int, from: Vector3, heading: Vector3, lane_length: float, lane_width: float, reach := 3.5) -> Node3D:
	_clear_telegraph()
	_telegraph = Telegraph.lane(world_root, terrain, threat_type, from, heading, lane_length, lane_width, reach)
	_facts_begin(_telegraph)
	return _telegraph


func _in_play() -> bool:
	return not live.is_valid() or live.call()


func _ball() -> Vector3:
	return target.ball_position()


func _flat_to_ball() -> Vector3:
	var to: Vector3 = _ball() - global_position
	to.y = 0.0
	return to


func can_rally() -> bool:
	return not _dead and not winding_up() and _knocked_speed() < RALLY_INTERRUPT_KNOCK


func rally_to(spot: Vector3, seconds: float) -> bool:
	if seconds <= 0.0 or not can_rally():
		return false
	_rally_target = spot
	_rally_left = seconds
	return true


func is_rallying() -> bool:
	return _rally_left > 0.0 and not _dead


func cancel_rally() -> void:
	_rally_left = 0.0


func _rally_velocity(delta: float, desired: Vector3) -> Vector3:
	if _rally_left <= 0.0:
		return desired
	_rally_left = maxf(0.0, _rally_left - delta)
	if winding_up():
		_rally_left = 0.0
		return desired
	var to_slot := Vector3(_rally_target.x - global_position.x, 0.0, _rally_target.z - global_position.z)
	var dist := to_slot.length()
	if dist <= RALLY_ARRIVE:
		_rally_left = 0.0
		return desired
	var rem := maxf(delta, _rally_left)
	var speed := clampf(dist / rem, maxf(desired.length(), RALLY_MIN_SPEED), RALLY_MAX_SPEED)
	return to_slot / dist * speed


func _move(delta: float, desired: Vector3) -> void:
	if _knocked_speed() >= RALLY_INTERRUPT_KNOCK:
		_rally_left = 0.0
	var horizontal := Vector3(_knock.x, 0.0, _knock.z)
	if horizontal.length() < 1.0:
		horizontal = _rally_velocity(delta, desired)
	elif _rally_left > 0.0:
		_rally_left = maxf(0.0, _rally_left - delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if _knock.y > 0.0:
		velocity.y = _knock.y
		_knock.y = 0.0
	velocity.y -= GRAVITY * delta
	var grounded := is_on_floor()
	move_and_slide()
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	_wall_slam()
	_knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)
	if _rings_out(grounded):
		return
	_rescue()


func _knocked_speed() -> float:
	if _knock.x == 0.0 and _knock.z == 0.0:
		return 0.0
	return Vector2(_knock.x, _knock.z).length()


func _wall_slam() -> void:
	if _dead or _walled_knock == knocks or _knocked_speed() < Contact.WALL_SLAM_SPEED:
		return
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if not BallRules.world_face(hit.get_collider()):
			continue
		var n := hit.get_normal()
		if n.angle_to(Vector3.UP) <= floor_max_angle:
			continue
		n.y = 0.0
		if n.length_squared() < 0.01:
			continue
		n = n.normalized()
		var into := -Vector3(_knock.x, 0.0, _knock.z).dot(n)
		if into < Contact.WALL_SLAM_SPEED:
			continue
		_walled_knock = knocks
		wall_slams += 1
		react("stagger", n)
		if _reaction_bus != null and _reaction_bus.has_signal("enemy_walled"):
			_reaction_bus.enemy_walled.emit(self, hit.get_position(), n, into)
		return


func _rings_out(grounded: bool) -> bool:
	if _dead or not ring_outs_here():
		_ring_from = INF
		return false
	var knocked := _knocked_speed() >= 1.0
	if _ring_from == INF:
		if knocked and grounded:
			_ring_from = global_position.y
		return false
	var floor_line := _ring_from - RING_OUT_DROP
	if not is_on_floor() and global_position.y < floor_line \
			and terrain.height(global_position.x, global_position.z) + half_height < floor_line:
		ring_out()
		return true
	if is_on_floor() and not knocked:
		_ring_from = INF
	return false


func open_ring_out() -> void:
	if _ring_from == INF and is_on_floor():
		_ring_from = global_position.y


func ring_outs_here() -> bool:
	if terrain == null or not terrain.has_method("world") or terrain.world() != RING_OUT_WORLD:
		return false
	return not _ring_out_kept.has(kind) and not _Roster.is_boss_piece(kind)


func ring_out() -> void:
	if _dead:
		return
	ringed_out = true
	last_damage_source = "ring_out"
	if _reaction_bus != null and _reaction_bus.has_signal("enemy_ringed_out"):
		_reaction_bus.enemy_ringed_out.emit(kind, global_position)
	hp = 0.0
	_die()


var _rescue_cell := Vector2i(1 << 20, 1 << 20)
var _rescue_ground := -INF
var _rescue_terrain_id := 0


func _rescue() -> void:
	if terrain == null:
		return
	var terrain_id: int = terrain.get_instance_id()
	var cell := Vector2i(floori(global_position.x * 0.5), floori(global_position.z * 0.5))
	if is_on_floor() and terrain_id == _rescue_terrain_id and cell == _rescue_cell \
			and global_position.y >= _rescue_ground - FLOOR_RESCUE * 0.5:
		return
	var ground: float = terrain.height(global_position.x, global_position.z)
	_rescue_terrain_id = terrain_id
	_rescue_cell = cell
	_rescue_ground = ground
	if global_position.y < ground - FLOOR_RESCUE:
		global_position = terrain.drop_point(global_position.x, global_position.z, half_height + 0.5)
		velocity = Vector3.ZERO


func _update_flash(delta: float) -> void:
	if _material == null:
		return
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.5)
		_material.albedo_color = _base_color.lerp(Color(1.0, 1.0, 0.85), FlashGuard.whiten(_flash))
		_material.emission_enabled = true
		_material.emission = EventKinds.role_color("neutral")
		_material.emission_energy_multiplier = FlashGuard.spike(0.0, _flash * 2.0)
		if _flash <= 0.0:
			_apply_rest_look()
	if _strike_frames > 0:
		_strike_frames -= 1
		if _flash <= 0.0:
			_show_strike()
		if _strike_frames == 0:
			_strike_frames = STRIKE_DONE
	elif _strike_frames == STRIKE_DONE:
		_strike_frames = 0
		if _flash <= 0.0:
			_apply_rest_look()


func _show_strike(mat: StandardMaterial3D = null, base := Color.WHITE) -> void:
	if mat == null:
		mat = _material
		base = _base_color
	mat.albedo_color = base.lerp(Palette.HAZARD, FlashGuard.info(STRIKE_TINT))
	mat.emission_enabled = true
	mat.emission = Palette.HAZARD
	mat.emission_energy_multiplier = FlashGuard.spike(0.0, STRIKE_GLOW)


func strike_flashing() -> bool:
	return _flash <= 0.0 and (_strike_frames == STRIKE_DONE or (_strike_frames > 0 and _strike_frames < STRIKE_FRAMES))


func _settle_look() -> void:
	_flash = 0.0
	_strike_frames = STRIKE_DONE
	_update_flash(0.0)


func _apply_rest_look() -> void:
	if _material == null:
		return
	_material.albedo_color = _base_color
	_material.emission_enabled = false


func _add_capsule(capsule_radius: float, capsule_height: float, color: Color) -> MeshInstance3D:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = capsule_radius
	capsule.height = capsule_height
	shape.shape = capsule
	add_child(shape)
	_base_color = color
	_material = Palette.solid(color)
	var mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = capsule_radius
	capsule_mesh.height = capsule_height
	mesh.mesh = capsule_mesh
	mesh.material_override = _material
	_visual_parent().add_child(mesh)
	return mesh


func _accent(mesh: Mesh, color: Color, energy: float, at: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = Palette.solid(color, energy)
	instance.position = at
	(_visual_parent() if parent == self else parent).add_child(instance)
	return instance


func _plate_material(rim_mask: Texture2D = null) -> StandardMaterial3D:
	if rim_mask == null and not _plates_are_round():
		rim_mask = rim_frame_mask()
	var mat := Palette.solid(PLATE_CLOSED, 0.0, false)
	mat.metallic = 0.6
	mat.roughness = 0.4
	mat.emission_texture = rim_mask if rim_mask != null else mask_texture([Color.BLACK], 1)
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_paint_plate(mat, "")
	_tint_materials.append(mat)
	if _plate_shaders.is_empty():
		for lit in [false, true]:
			var held: StandardMaterial3D = mat.duplicate()
			held.emission_enabled = lit
			held.get_rid()
			_plate_shaders.append(held)
	return mat


func _plates_are_round() -> bool:
	var script := get_script() as Script
	return script != null and script.resource_path.get_file() == "mind_hand.gd"


static func _paint_plate(mat: StandardMaterial3D, state: String) -> void:
	mat.albedo_color = PLATE_CLOSED
	mat.emission_enabled = state == "amber" or state == "slate"
	if state == "amber":
		mat.emission = EventKinds.state_color("will_break")
		mat.emission_energy_multiplier = PLATE_GLOW_LIVE
	elif state == "slate":
		mat.emission = EventKinds.state_color("glancing")
		mat.emission_energy_multiplier = PLATE_GLOW_SLATE
	else:
		mat.emission = PLATE_CLOSED
		mat.emission_energy_multiplier = 0.0


static func _pulses() -> bool:
	return String(EventKinds.state_row("will_break").get("motion", "none")) == "pulse"


func _pulse_rim(delta: float) -> void:
	_rim_clock += delta
	var swing := 1.0 + PULSE_DEPTH * sin(TAU * PULSE_HZ * _rim_clock)
	for mat in _tint_materials:
		(mat as StandardMaterial3D).emission_energy_multiplier = PLATE_GLOW_LIVE * swing


func flare_glance() -> void:
	if tint_state == "slate" and not _tint_materials.is_empty() and _glance_left <= 0.0:
		_glance_left = GLANCE_SECONDS


func _beat_glance(delta: float) -> void:
	_glance_left = maxf(0.0, _glance_left - delta)
	var beat := absf(sin(PI * GLANCE_BEATS * (1.0 - _glance_left / GLANCE_SECONDS)))
	var energy := FlashGuard.spike(PLATE_GLOW_SLATE, PLATE_GLOW_SLATE * lerpf(1.0, GLANCE_PEAK, beat))
	for mat in _tint_materials:
		(mat as StandardMaterial3D).emission_energy_multiplier = energy


static func mask_texture(texels: Array, width: int, height := 1) -> ImageTexture:
	var img := Image.create_empty(width, height, false, Image.FORMAT_RGB8)
	for i in texels.size():
		img.set_pixel(i % width, i / width, texels[i])
	return ImageTexture.create_from_image(img)


static var _frame_mask: ImageTexture
static func rim_frame_mask() -> ImageTexture:
	if _frame_mask == null:
		var w := RIM_CELL * 3
		var h := RIM_CELL * 2
		var texels := []
		for y in h:
			for x in w:
				var cx := x % RIM_CELL
				var cy := y % RIM_CELL
				var edge := cx < RIM_EDGE or cx >= RIM_CELL - RIM_EDGE or cy < RIM_EDGE or cy >= RIM_CELL - RIM_EDGE
				texels.append(Color.WHITE if edge else Color.BLACK)
		_frame_mask = mask_texture(texels, w, h)
	return _frame_mask


func _add_crack(parent: Node3D, at: Vector3, size := 0.9) -> Node3D:
	var glyph := Node3D.new()
	glyph.position = at
	var mat := Palette.unshaded(EventKinds.state_color("will_break"))
	for i in 3:
		var stroke := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.09, size * 0.45, 0.06)
		stroke.mesh = box
		stroke.material_override = mat
		stroke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stroke.position = Vector3((i - 1) * size * 0.18, (1 - i) * size * 0.28, 0.0)
		stroke.rotation.z = 0.6 if i % 2 == 0 else -0.6
		glyph.add_child(stroke)
	glyph.visible = tint_state == "amber"
	parent.add_child(glyph)
	_cracks.append(glyph)
	return glyph


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_dress_bake.call_deferred()
	elif what == NOTIFICATION_PHYSICS_PROCESS:
		if not _clips_tried:
			_clips_tried = true
			_clips = EnemyClips.seat(self)
		_update_reaction(get_physics_process_delta_time())
		if _soaked_left > 0.0:
			_soaked_left = maxf(0.0, _soaked_left - get_physics_process_delta_time())
		_facts_poll()
		if tint_state == "amber" and _pulses():
			_pulse_rim(get_physics_process_delta_time())
		elif _glance_left > 0.0:
			_beat_glance(get_physics_process_delta_time())


func _dress_bake() -> void:
	if is_inside_tree():
		var owned := owned_materials()
		BakeLook.dress(self, owned)
		InkOutline.apply(self, "warden" if kind in ["warden", "miniboss"] else "enemy", owned)


func owned_materials() -> Array:
	var out: Array = []
	for prop_name in _script_variables():
		var value = get(prop_name)
		if typeof(value) == TYPE_OBJECT and not is_instance_valid(value):
			continue
		if value is StandardMaterial3D:
			out.append(value)
		elif value is Array:
			for item in value:
				if typeof(item) == TYPE_OBJECT and not is_instance_valid(item):
					continue
				if item is StandardMaterial3D:
					out.append(item)
	return out


# Godot get_property_list() walks every engine property (~0.4-0.6 ms/spawn), so cache per script.
func _script_variables() -> PackedStringArray:
	var script: Script = get_script()
	if not _variables_by_script.has(script):
		var names := PackedStringArray()
		for prop in get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
				names.append(prop.name)
		_variables_by_script[script] = names
	return _variables_by_script[script]


func attack_facts() -> Dictionary:
	if _atk.is_empty():
		return {}
	return _facts_dict(String(_atk["phase"]))


func attack_state() -> Dictionary:
	if _atk.is_empty():
		return {}
	var tele = _atk.get("tele")
	var progress := float(tele.progress) if tele != null and is_instance_valid(tele) else float(_atk.get("progress", 0.0))
	return {"phase": String(_atk.get("phase", "")), "progress": progress}


func _facts_row(is_lane: bool) -> String:
	if FACTS_UNMAPPED.has(kind):
		return ""
	var found: Array = []
	for id in EventKinds.ATTACK_ROWS:
		var row: Dictionary = EventKinds.ATTACK_ROWS[id]
		if row["group"] == "enemy" and row["owner_kind"] in ["roster", "rogue"] and row["owner"] == kind:
			found.append(id)
	if found.size() <= 1:
		return "" if found.is_empty() else found[0]
	for id in found:
		if (EventKinds.ATTACK_ROWS[id]["threat"] == "threat_lane") == is_lane:
			return id
	return ""


func _facts_begin(tele: Node3D, managed := false) -> void:
	_facts_end(false)
	var row := _facts_row(tele.shape == Telegraph.Shape.LANE)
	if row == "":
		return
	_attack_serial += 1
	_atk = {"instance": _attack_serial, "row": row, "phase": PHASE_WINDUP, "managed": managed, "tele": tele,
		"geometry": tele.descriptor(), "progress": tele.progress}
	attack_phase.emit(_facts_dict(PHASE_WINDUP))


func _facts_manage(tele: Node3D) -> void:
	if _atk.is_empty():
		_facts_begin(tele, true)
	else:
		_atk["managed"] = true


func _facts_phase(phase: String) -> void:
	if _atk.is_empty() or _atk["phase"] == phase:
		return
	_facts_refresh()
	_atk["phase"] = phase
	if phase == PHASE_STRIKE and not _dead:
		_strike_frames = STRIKE_FRAMES
	attack_phase.emit(_facts_dict(phase))


func _facts_end(cancel: bool) -> void:
	if _atk.is_empty():
		return
	if not cancel and not _dead:
		_facts_poll()
		if _atk.is_empty():
			return
	var closing := PHASE_CANCELLED if (cancel or _dead or _atk["phase"] == PHASE_WINDUP) else PHASE_RECOVER
	_facts_refresh()
	var facts := _facts_dict(closing)
	_atk = {}
	attack_phase.emit(facts)


func _facts_refresh() -> void:
	var tele = _atk.get("tele")
	if tele != null and is_instance_valid(tele):
		_atk["geometry"] = tele.descriptor()
		_atk["progress"] = tele.progress


func _facts_dict(phase: String) -> Dictionary:
	if String(_atk["phase"]) == phase:
		_facts_refresh()
	var geometry: Dictionary = _atk["geometry"]
	return {"instance": _atk["instance"], "row": _atk["row"], "owner": kind, "phase": phase,
		"committed": not geometry.is_empty(), "progress": _atk["progress"], "geometry": geometry.duplicate(),
		"at": global_position}


func _facts_poll() -> void:
	if _dead:
		return
	if kind == "lobber":
		_facts_poll_lobber()
		return
	if _atk.is_empty() or _atk["managed"] or _atk["phase"] != PHASE_WINDUP:
		return
	var tele = _atk.get("tele")
	if tele != null and is_instance_valid(tele) and tele.progress >= 1.0:
		_facts_phase(PHASE_STRIKE)


func _facts_poll_lobber() -> void:
	var charge: float = get("charge")
	if _atk.is_empty():
		if charge > 0.0 and _in_play():
			_facts_begin_lobber(charge)
	elif _atk["phase"] == PHASE_WINDUP:
		if charge <= 0.0:
			_facts_end(true)
		else:
			_atk["progress"] = clampf(charge, 0.0, 1.0)


func _facts_begin_lobber(charge: float) -> void:
	var row := _facts_row(false)
	if row == "":
		return
	_attack_serial += 1
	_atk = {"instance": _attack_serial, "row": row, "phase": PHASE_WINDUP, "managed": true, "tele": null,
		"geometry": {}, "progress": clampf(charge, 0.0, 1.0)}
	attack_phase.emit(_facts_dict(PHASE_WINDUP))


func _facts_on_released(ring: Dictionary) -> void:
	if _dead:
		return
	if _atk.is_empty():
		_facts_begin_lobber(1.0)
	if _atk.is_empty():
		return
	_atk["progress"] = 0.0
	_atk["geometry"] = ring.duplicate()
	_facts_phase(PHASE_STRIKE)
	_facts_end(false)
