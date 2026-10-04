extends "res://src/combat/enemy.gd"

const WardenLook := preload("res://src/combat/warden_look.gd")
const WardenKit := preload("res://src/combat/warden_kit.gd")
const Roster := preload("res://src/combat/roster.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")

# The Warden: one per stage, an immobile clamp at the base of the beacon mast. Breaking
# it is the stage's one MUST (DEMO-SPEC). It never moves, never pins, never pushes you
# sideways. Every Warden fights on posture (boss_posture.gd): hits fill a posture bar, a
# full bar staggers the Warden for STAGGER_SECONDS and opens its core, and only a contact
# on the open core removes health, one chunk of four per stagger. Plating is the stage's
# number, read by the posture rule for its glance line. The plating fight (caps, magnet,
# mind brace, shred, the 20% chip) was retired once every Warden fought on posture.
#
# - The pulse. While you are inside its reach (the beacon ring), it charges for
#   PULSE_TELEGRAPH seconds every PULSE_CYCLE, showing a ring the size of its reach and
#   a small core ring. Then it pulses: a ball the reach ring contains gains PULSE_LIFT
#   m/s straight up for one tick, horizontal speed untouched, and a ball the core ring
#   contains also takes PULSE_DAMAGE. The pulse pauses in a stagger and a charge in
#   flight is cancelled.
# - The family kit (DESIGN-V2 section 11) is the shared clamp's look: reactor vents on the
#   pulse, the swarm keeps a guard rack of drones that pays GUARD_RACK_POSTURE once for
#   the cruise-or-faster ram that scatters it (reform and respawn on GUARD_RESPAWN), the
#   mind's lens follows you and opens on a stagger.

const HALF_HEIGHT := 1.6
const RADIUS := 2.8
const DEFAULT_REACH := 30.0
const PULSE_CYCLE := 6.0
const PULSE_TELEGRAPH := 2.0
const PULSE_LIFT := 10.0
const PULSE_DAMAGE := 10.0
const CORE_RADIUS := 6.0
const LIFT_REACH_UP := 8.0
const GUARD_RESPAWN := 10.0
const GUARD_OFFSET := 9.0
const GUARD_RACK_POSTURE := 25.0
const FAMILY_POINT_RADIUS := 1.3
const FAMILY_REACH := 3.2
const CONTACT_KINDS := ["stomp", "slam"]

var stage := 1
var reach := DEFAULT_REACH
var pulses := 0
# Whether the last pulse's reach ring contained the ball (and so lifted it).
var last_pulse_lifted := false
var min_pulse_telegraph := INF
var family := Roster.REACTOR
var fleet
var guard
var family_opens := 0

var _pulse_clock := 0.0
var _charging := false
var _charge_time := 0.0
var _core_ring: Node3D
var _since_pulse := INF
var _look: Node3D
var _kit: Node3D
var _guard_wait := 0.0
var _charge_len := PULSE_TELEGRAPH
var _posture: BossPosture
var _armed := 0.0
var _guard_scatter_frame := -1
var _guard_paid_scatters := 0


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, _threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = "warden"
	stage = spec.get("stage", 1)
	reach = spec.get("reach", DEFAULT_REACH)
	family = spec.get("family", Roster.warden_family(stage))
	_posture = BossPosture.new(spec.get("posture", {}))
	faction = family
	fleet = spec.get("fleet")
	if family == Roster.SWARM and fleet != null:
		fleet.events().enemy_struck.connect(_on_guard_struck)
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
	return "charging" if _charging else "idle"


func knock(_direction: Vector3, _force: float) -> void:
	pass


func seconds_since_pulse() -> float:
	return _since_pulse


func plating_for(_hit_kind: String, part: String) -> float:
	if part == family_point() and family_open():
		return 0.0
	return plating


func weak_points() -> Array:
	var points := []
	if family_open():
		points.append({"id": family_point(), "at": family_point_at(), "radius": FAMILY_POINT_RADIUS})
	return points


# --- The family kit (v2 W7) ---------------------------------------------------------

# The kit's weak point: the core, open for the length of a stagger.
func family_point() -> String:
	return "core"


func family_point_at() -> Vector3:
	return global_position + (_kit.point_offset() if _kit != null else Vector3.UP * 4.0)


func family_open() -> bool:
	return _posture.staggered


func on_guard_scattered(swarm, _at: Vector3) -> void:
	if swarm == guard and family == Roster.SWARM:
		_guard_scatter_frame = Engine.get_physics_frames()


# Both ball contacts and weapon knocks scatter before enemy_struck. Only the ram
# on that scatter's frame pays the rack, never a later hit on following drones.
func _on_guard_struck(enemy: Node3D, hit_kind: String, force: float) -> void:
	if hit_kind != "ram" or guard == null or not is_instance_valid(enemy):
		return
	if enemy.get("swarm") != guard or not guard.following() \
			or _guard_scatter_frame != Engine.get_physics_frames() or guard.scatters <= _guard_paid_scatters:
		return
	if SpeedTier.of(force, target.tuning.f("cruise")) < SpeedTier.CRUISE:
		return
	_guard_paid_scatters = guard.scatters
	_apply_posture(judge_hit("guard_rack", 0.0, false, 0))


func _step_guard(delta: float) -> void:
	if fleet == null:
		return
	if guard != null and not guard.alive().is_empty():
		return
	_guard_wait -= delta
	if _guard_wait > 0.0:
		return
	_guard_wait = GUARD_RESPAWN
	var out := flat_to_ball()
	var at := global_position + (out.normalized() if out.length() > 0.1 else Vector3.FORWARD) * GUARD_OFFSET
	guard = fleet.spawn_guard(global_position, terrain.drop_point(at.x, at.z, 1.4))
	_guard_scatter_frame = -1
	_guard_paid_scatters = 0


func contact_part(ball: Vector3, hit_kind: String) -> String:
	if family_open() and family != Roster.MIND and hit_kind in CONTACT_KINDS \
			and Vector2(ball.x - global_position.x, ball.z - global_position.z).length() <= FAMILY_REACH:
		return family_point()
	return ""


func on_struck(_hit_kind: String, _part: String, result: Dictionary) -> void:
	_apply_posture(result)


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	_pose(delta)
	if not _in_play() or target == null:
		return
	_since_pulse += delta
	var inside := _flat_to_ball().length() <= reach
	_step_posture(delta)
	if family == Roster.SWARM:
		_step_guard(delta)
	_step_pulse(delta, inside)


# The pulse cycle runs while you are in reach; once charging starts it is committed and
# lands even if you leave, but only a ball its rings contain feels it.
func _step_pulse(delta: float, inside: bool) -> void:
	if staggered():
		return
	if _charging:
		_charge_time += delta
		var ring := telegraph()
		if ring != null:
			ring.set_progress(_charge_time / _charge_len)
		if is_instance_valid(_core_ring):
			_core_ring.set_progress(_charge_time / _charge_len)
		if _charge_time >= _charge_len:
			_pulse()
		return
	if not inside:
		return
	_pulse_clock += delta
	if _pulse_clock >= PULSE_CYCLE - PULSE_TELEGRAPH:
		_charging = true
		_charge_time = 0.0
		_charge_len = PULSE_TELEGRAPH
		_commit_ring(Threat.Type.INSTANT, global_position, reach, LIFT_REACH_UP, Palette.SAND)
		_core_ring = Telegraph.ring(world_root, terrain, Threat.Type.INSTANT, global_position, CORE_RADIUS)
		_core_ring.owner_voice = String(Roster.faction(family)["voice"]) if family != Roster.MIND else ""
		if family == Roster.REACTOR and fleet != null:
			fleet.events().vent_charging.emit(global_position, _charge_len)


func _pulse() -> void:
	var ball := _ball()
	var ring := telegraph()
	last_pulse_lifted = ring != null and ring.contains(ball)
	if last_pulse_lifted:
		target.crowd_control("warden_pulse", Vector3.UP * PULSE_LIFT / get_physics_process_delta_time())
	if is_instance_valid(_core_ring) and _core_ring.contains(ball):
		hit_player.emit(PULSE_DAMAGE, Vector3.ZERO)
	pulses += 1
	if family == Roster.REACTOR:
		if fleet != null:
			fleet.events().vent_erupted.emit(global_position)
	min_pulse_telegraph = minf(min_pulse_telegraph, _charge_time)
	_since_pulse = 0.0
	_charging = false
	_pulse_clock = 0.0
	_clear_telegraph()
	if is_instance_valid(_core_ring):
		_core_ring.queue_free()
	_core_ring = null


func _exit_tree() -> void:
	super._exit_tree()
	if is_instance_valid(_core_ring):
		_core_ring.queue_free()


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
	_kit = WardenKit.new()
	add_child(_kit)
	_kit.build(self, family)
	_base_color = Palette.CHARCOAL
	_material = _look.body_material


func _pose(_delta: float) -> void:
	pass


func _process(delta: float) -> void:
	if _look != null:
		_look.update(delta)
	if _kit != null:
		_kit.update(delta)


# --- Read by the look --------------------------------------------------------------

func charge_fraction() -> float:
	return clampf(_charge_time / _charge_len, 0.0, 1.0) if _charging else 0.0


func flat_to_ball() -> Vector3:
	return _flat_to_ball() if target != null else Vector3.ZERO


# --- The posture fight (boss_posture.gd) --------------------------------------------

func fight() -> String:
	return "posture"


func posture() -> float:
	return _posture.posture


func staggered() -> bool:
	return _posture.staggered


func stagger_left() -> float:
	return _posture.stagger_left


func chunks_left() -> int:
	return _posture.chunks


# Hits the rule counted as glances so far.
func glances() -> int:
	return _posture.glances


func chunk_cracked() -> bool:
	return _posture.cracked


# What the rule says a hit does.
func judge_hit(hit_kind: String, punch: float, smash: bool, tier: int) -> Dictionary:
	var result := _posture.judge({"kind": hit_kind, "punch": punch, "plating": plating, "smash": smash, "tier": tier,
			"charging": _charging, "frame": Engine.get_physics_frames(), "hp": hp, "max_hp": max_hp})
	if hit_kind == "guard_rack":
		# A rack is posture pressure, not a contact on the core. Keep judge/apply's
		# stagger and shatter-frame boundaries while fixing its gain independently of heft.
		result["gain"] = GUARD_RACK_POSTURE if not staggered() and Engine.get_physics_frames() != _posture.shatter_frame else 0.0
		result["glance"] = false
		result["full"] = true
	return result


func _apply_posture(result: Dictionary) -> void:
	var before := _posture_signature()
	var was_staggered := _posture.staggered
	var chunks_before: int = _posture.chunks
	_posture.apply(result, Engine.get_physics_frames())
	if _posture.chunks < chunks_before:
		_armed = float(result["dealt"])
	if _posture.staggered and not was_staggered:
		_begin_stagger()
	_publish_posture(before)


func _step_posture(delta: float) -> void:
	var before := _posture_signature()
	_posture.step(delta)
	_publish_posture(before)


func _begin_stagger() -> void:
	_charging = false
	_charge_time = 0.0
	_pulse_clock = 0.0
	_clear_telegraph()
	if is_instance_valid(_core_ring):
		_core_ring.queue_free()
	_core_ring = null
	family_opens += 1
	if fleet != null:
		fleet.events().weak_point_opened.emit("core", family_point_at(), BossPosture.STAGGER_SECONDS)


func _posture_signature() -> Array:
	return [floori(_posture.posture), _posture.staggered, _posture.chunks, _posture.cracked]


func _publish_posture(before: Array) -> void:
	if fleet != null and _posture_signature() != before:
		fleet.events().posture_changed.emit(self, _posture.posture, _posture.staggered)


# Health falls only by what the last shattering strike armed.
func take_damage(_amount: float) -> float:
	var armed := _armed
	_armed = 0.0
	return super.take_damage(armed)


func set_tint(_state: String) -> void:
	super.set_tint("")


func integrity() -> float:
	return clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0
