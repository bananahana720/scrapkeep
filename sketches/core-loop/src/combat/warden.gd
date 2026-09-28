extends "res://src/combat/enemy.gd"

const WardenLook := preload("res://src/combat/warden_look.gd")
const WardenKit := preload("res://src/combat/warden_kit.gd")
const Roster := preload("res://src/combat/roster.gd")
const Habits := preload("res://src/combat/habits.gd")
const WardenDrop := preload("res://src/combat/warden_drop.gd")

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
#   - "magnet": every MAGNET_CYCLE it swings a magnet arm toward you and lays a wedge
#     from the arm toward the ball for MAGNET_TELEGRAPH, then tugs a ball the wedge
#     contains toward it at MAGNET_PULL m/s^2 for MAGNET_TUG. The magnet is a weak
#     point only in the tug: a weapon hit on it then drops the Warden's plating to 0
#     for UNPLATE_SECONDS and ends the tug. An earlier shot meets the body.
#
# v2 W7 enemies: the clamp is a shared ancient base with one family kit per stage
# (DESIGN-V2 section 11), on top of the lesson. The body's plating, the 20% chip, the
# gate and breaking it anywhere are untouched; each kit adds a weak point with plating
# 0 that opens only when the family's own mechanic is answered:
#   - reactor (stage 1): the pulse is the reactor venting. The pulse charge publishes
#     vent_charging, the pulse vent_erupted, and the core stands open for CORE_WINDOW.
#   - swarm (stage 2): the hive keeps a guard rack of drones between itself and you.
#     Bowl through the rack and it scatters: the queen cell opens for QUEEN_WINDOW. A
#     guard that dies out is rebuilt after GUARD_RESPAWN.
#   - mind (stage 3): every ADAPT_CYCLE in reach it reads your most-used habit, quotes
#     your class motif back wrong (mind_adapted) and shows the habit's trigger icon on
#     its lens for ADAPT_WARN, then braces for BRACE: hits of that verb meet BRACE_MULT
#     times its plating, and its lens stands open. Within a run only.

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
# The change request said 6 m/s^2; at 6 a ball driving away fell to 10.4 m/s against
# its own 0.8 x cruise (11.2) floor (a no-tug control run: 12.9); 4 cleared it by only
# 0.2 m/s, so the pull is 3.5.
const MAGNET_PULL := 3.5
const MAGNET_ARM := 3.2
# The magnet rides high over the clamp, out of the straight line from the ball to the
# body, so shooting it is a choice you aim for rather than an accident of body fire.
const MAGNET_RISE := 3.6
const MAGNET_RADIUS := 1.1
# The pull telegraphs as a wedge from the arm toward the ball, this wide either side, so
# it never reads as the pulse ring; the tug pulls only a ball the wedge contains.
const MAGNET_WEDGE_DEG := 35.0
const UNPLATE_SECONDS := 3.0
const WEAPON_KINDS := ["runner", "arc", "turret"]
const CORE_WINDOW := 2.5
const QUEEN_WINDOW := 4.0
const GUARD_RESPAWN := 10.0
const GUARD_OFFSET := 9.0
const ADAPT_CYCLE := 10.0
const ADAPT_WARN := 1.2
const BRACE := 5.0
const BRACE_MULT := 1.4
const FAMILY_POINT_RADIUS := 1.3
const FAMILY_REACH := 3.2
const CONTACT_KINDS := ["stomp", "slam"]

enum Magnet { IDLE, TELEGRAPH, TUG }

var stage := 1
var lesson := "plate"
var reach := DEFAULT_REACH
var pulses := 0
# Whether the last pulse's reach ring contained the ball (and so lifted it).
var last_pulse_lifted := false
var min_pulse_telegraph := INF
var magnet_stuns := 0
var magnet_state := Magnet.IDLE
var shred := 0.0
var family := Roster.REACTOR
var fleet
var guard
var family_opens := 0
var adapt_habit := ""
var braced_kinds: Array = []

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
var _cap_material: StandardMaterial3D
var _look: Node3D
var _kit: Node3D
var _open_left := 0.0
var _guard_wait := 0.0
var _adapt_clock := 0.0
var _adapt_time := 0.0
var _brace_left := 0.0
var loop_mode := "v2"
var drop = null
# Whether the ball stood inside the core ring at any point of the current charge.
var _core_touched := false
var _core_last_in := 0.0
var near_misses := 0
var safe_dodges := 0
const NEAR_MISS := 0.3
var _charge_len := PULSE_TELEGRAPH


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, _threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = "warden"
	stage = spec.get("stage", 1)
	lesson = spec.get("lesson", "plate")
	reach = spec.get("reach", DEFAULT_REACH)
	family = spec.get("family", Roster.warden_family(stage))
	faction = family
	fleet = spec.get("fleet")
	plating = spec.get("plating", 30.0)
	_set_health(spec.get("hp", 400.0))
	scrap_value = 30 * stage
	weight = 1000.0
	radius = RADIUS
	half_height = HALF_HEIGHT
	# Clamped to the mast base: sits on the ground under the point it was given.
	global_position = Vector3(global_position.x, terrain.height(global_position.x, global_position.z) + HALF_HEIGHT, global_position.z)
	_build_body()
	loop_mode = String(spec.get("loop_mode", "v2"))
	if spec.get("drop_rules", false) and fleet != null:
		drop = WardenDrop.new(self, spec)


# --- The v3 fun lab (loop_mode.gd) ---------------------------------------------------
# drop is warden_drop.gd's rules when the drop mode applies here, else null: every
# drop-mode branch in this file is behind it, so v2 runs exactly as before. Any loop
# mode (drop, laps) also publishes the pulse's near-miss.

func loop_rule(hit_kind: String, part: String, _force: float, punch: float, heft: float) -> Dictionary:
	return drop.rule(hit_kind, part, punch, heft) if drop != null else {}


func loop_state() -> String:
	return drop.state if drop != null else ""


func _cycle_seconds() -> float:
	return drop.cycle_seconds(PULSE_CYCLE) if drop != null else PULSE_CYCLE


func _telegraph_seconds() -> float:
	return drop.telegraph_seconds(PULSE_TELEGRAPH) if drop != null else PULSE_TELEGRAPH


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
	if part == family_point() and family_open():
		return 0.0
	if braced() and hit_kind in braced_kinds:
		return plating_now() * BRACE_MULT
	if part == "magnet" and hit_kind in WEAPON_KINDS and magnet_state == Magnet.TUG:
		return 0.0
	return plating_now()


func hit_mult(hit_kind: String, part: String) -> float:
	return CAP_MULT if part == "cap" and hit_kind in CONTACT_KINDS else 1.0


func weak_points() -> Array:
	var points := []
	if lesson == "magnet" and magnet_state == Magnet.TUG:
		points.append({"id": "magnet", "at": magnet_point(), "radius": MAGNET_RADIUS})
	if family_open():
		points.append({"id": family_point(), "at": family_point_at(), "radius": FAMILY_POINT_RADIUS})
	return points


# --- The family kit (v2 W7) ---------------------------------------------------------

# The kit's weak point: the reactor's core, the hive's queen cell, the Mind's lens.
func family_point() -> String:
	return {Roster.REACTOR: "core", Roster.SWARM: "queen", Roster.MIND: "lens"}.get(family, "core")


func family_point_at() -> Vector3:
	return global_position + (_kit.point_offset() if _kit != null else Vector3.UP * 4.0)


func family_open() -> bool:
	return _open_left > 0.0 or braced()


func braced() -> bool:
	return _brace_left > 0.0


func adapting() -> bool:
	return adapt_habit != "" and _brace_left <= 0.0


func on_guard_scattered(swarm, _at: Vector3) -> void:
	if swarm == guard and family == Roster.SWARM:
		_open(QUEEN_WINDOW)


func _open(seconds: float) -> void:
	if drop != null:
		seconds = drop.opened(seconds)
	_open_left = seconds
	family_opens += 1
	if fleet != null:
		fleet.events().weak_point_opened.emit(family_point(), family_point_at(), seconds)


func _step_family(delta: float, inside: bool) -> void:
	_open_left = maxf(0.0, _open_left - delta)
	match family:
		Roster.SWARM:
			_step_guard(delta)
		Roster.MIND:
			_step_mind(delta, inside)


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


func _step_mind(delta: float, inside: bool) -> void:
	if fleet == null:
		return
	if _brace_left > 0.0:
		_brace_left -= delta
		if _brace_left <= 0.0:
			adapt_habit = ""
			braced_kinds = []
			_kit.show_icon("")
		return
	if adapt_habit != "":
		_adapt_time += delta
		if _adapt_time >= ADAPT_WARN:
			_brace_left = BRACE
			if fleet != null:
				fleet.events().weak_point_opened.emit("lens", family_point_at(), BRACE)
			family_opens += 1
		return
	if not inside:
		return
	_adapt_clock += delta
	if _adapt_clock < ADAPT_CYCLE:
		return
	var habit: String = fleet.habits.top()
	if habit == "":
		return
	_adapt_clock = 0.0
	_adapt_time = 0.0
	adapt_habit = habit
	var brace: Dictionary = Habits.BRACES[habit]
	braced_kinds = brace["kinds"]
	_kit.show_icon(String(brace["icon"]))
	fleet.mind_adapt(habit, String(brace["icon"]), family_point_at())


func cap_points() -> Array:
	var points := []
	if lesson != "caps":
		return points
	for i in CAP_COUNT:
		var angle := TAU * i / CAP_COUNT
		points.append(global_position + Vector3(cos(angle) * CAP_RING, HALF_HEIGHT + 0.3, sin(angle) * CAP_RING))
	return points


func magnet_point() -> Vector3:
	return global_position + _magnet_dir * MAGNET_ARM + Vector3.UP * MAGNET_RISE


func contact_part(ball: Vector3, hit_kind: String) -> String:
	if family_open() and family != Roster.MIND and hit_kind in CONTACT_KINDS \
			and Vector2(ball.x - global_position.x, ball.z - global_position.z).length() <= FAMILY_REACH:
		return family_point()
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
	if drop != null:
		drop.on_struck(hit_kind, _result)


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	_pose(delta)
	if not _in_play() or target == null:
		return
	_since_pulse += delta
	_unplated = maxf(0.0, _unplated - delta)
	var inside := _flat_to_ball().length() <= reach
	var was_open := _open_left > 0.0
	_step_family(delta, inside)
	# Drop mode runs the cycle on its own clock from the stage's start, so a drop can be
	# timed from the shelf; v2's runs only while you are in reach.
	_step_pulse(delta, inside or drop != null)
	if lesson == "magnet":
		_step_magnet(delta, inside)
	if drop != null:
		drop.step(delta, was_open)


# The pulse cycle runs while you are in reach; once charging starts it is committed and
# lands even if you leave, but only a ball its rings contain feels it.
func _step_pulse(delta: float, inside: bool) -> void:
	if _charging:
		_charge_time += delta
		var ring := telegraph()
		if ring != null:
			ring.set_progress(_charge_time / _charge_len)
		if is_instance_valid(_core_ring):
			_core_ring.set_progress(_charge_time / _charge_len)
			if loop_mode != "v2" and _core_ring.contains(_ball()):
				_core_touched = true
				_core_last_in = _charge_time
		if _charge_time >= _charge_len:
			_pulse()
		return
	if not inside:
		return
	_pulse_clock += delta
	if _pulse_clock >= _cycle_seconds() - _telegraph_seconds():
		_charging = true
		_charge_time = 0.0
		_charge_len = _telegraph_seconds()
		_core_touched = false
		_commit_ring(Threat.Type.INSTANT, global_position, reach, LIFT_REACH_UP, Palette.SAND)
		_core_ring = Telegraph.ring(world_root, terrain, Threat.Type.INSTANT, global_position, CORE_RADIUS)
		_core_ring.owner_voice = String(Roster.faction(family)["voice"]) if family != Roster.MIND else ""
		if family == Roster.REACTOR and fleet != null:
			fleet.events().vent_charging.emit(global_position, _charge_len)


func _pulse() -> void:
	var ball := _ball()
	var ring := telegraph()
	last_pulse_lifted = ring != null and ring.contains(ball)
	# "I dodged it" (LOOP-REDESIGN section 2, review finding 6), a loop-mode read only:
	# inside the drawn core ring during its telegraph and outside it at the clang is a
	# dodge. Out within NEAR_MISS of the clang is a near-miss, which gives the air jump
	# back as its bonus; out earlier is a safe resolution, acknowledged without one.
	if loop_mode != "v2" and _core_touched and is_instance_valid(_core_ring) and not _core_ring.contains(ball) and fleet != null:
		var near := _charge_len - _core_last_in <= NEAR_MISS
		if near:
			near_misses += 1
			target.refresh_air()
		else:
			safe_dodges += 1
		fleet.events().warden_pulse_dodged.emit(ball, near)
	# Drop mode: the air is a safe place through the telegraph (section 2, "where to be":
	# on a drop line, on the bank, or in the air), so the pulse throws and burns only a
	# ball on the floor, never one already on its drop arc.
	var airborne: bool = drop != null and not target.state.grounded
	if airborne:
		last_pulse_lifted = false
	if drop != null:
		drop.on_pulse(last_pulse_lifted, ball)
	if last_pulse_lifted:
		target.crowd_control("warden_pulse", Vector3.UP * PULSE_LIFT / get_physics_process_delta_time())
	if not airborne and is_instance_valid(_core_ring) and _core_ring.contains(ball):
		hit_player.emit(PULSE_DAMAGE, Vector3.ZERO)
	pulses += 1
	if family == Roster.REACTOR:
		if fleet != null:
			fleet.events().vent_erupted.emit(global_position)
		_open(CORE_WINDOW)
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
				_magnet_ring = Telegraph.wedge(world_root, terrain, Threat.Type.LANE, global_position + _magnet_dir * MAGNET_ARM, _magnet_dir,
						reach, MAGNET_WEDGE_DEG, LIFT_REACH_UP)
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
					target.crowd_control("warden_magnet", to.normalized() * MAGNET_PULL, false)
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
	if drop != null:
		drop.clear()


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
	_cap_material = _look.cap_material()


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


# 0 when the magnet is stowed, rising to 1 through its telegraph, 1 through the tug.
func magnet_out() -> float:
	match magnet_state:
		Magnet.TELEGRAPH:
			return clampf(_magnet_time / MAGNET_TELEGRAPH, 0.0, 1.0)
		Magnet.TUG:
			return 1.0
	return 0.0


func magnet_dir() -> Vector3:
	return _magnet_dir


func flat_to_ball() -> Vector3:
	return _flat_to_ball() if target != null else Vector3.ZERO


func integrity() -> float:
	return clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0


# Combat's shred on this Warden (combat.gd owns the number and pushes it every tick).
func set_shred(amount: float) -> void:
	shred = amount


# The share of the plating stripped right now, 0 to 1.
func shred_fraction() -> float:
	return clampf(shred / plating, 0.0, 1.0) if plating > 0.0 else 0.0
