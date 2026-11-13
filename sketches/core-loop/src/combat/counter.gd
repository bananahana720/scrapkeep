extends "res://src/combat/enemy.gd"

const Roster := preload("res://src/combat/roster.gd")
const TelegraphRecord := preload("res://src/combat/telegraph_record.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const AbilityState := preload("res://src/core/ability_state.gd")

# What every Fleet reinforcement shares (DESIGN-V2 section 10): an animal crew with its
# anti-ball tool as the biggest shape, and one loop, roam -> warn -> live -> rest.
#
# - Warn commits the unit's telegraph with W2's grammar and dresses it with the Fleet's
#   voice and the unit's mechanic tag (roster.gd), so the danger draws and sounds on the
#   frame it is declared. Nothing holds the ball before its warning has run.
# - Live is the unit's own mechanic (a subclass's _live). A hold goes through the holds
#   node, which owns the crowd-control door, tenacity and breaking free.
# - A hard hit in the warning (a knock at the unit's interrupt speed) breaks the attack
#   and staggers the unit for STAGGER_WINDOW, the same window on every pack kind: it
#   stands open, walks nowhere and starts nothing. impact_resist is the per-kind dial
#   for how hard that hit must be; the Warden keeps its own posture break.
# - A hold the player breaks by their own action ends the live phase for good: the pit
#   shatters, the net tears, the cable snaps. It never re-catches on the next tick.
# - An attack that ran its live phase ends in recovery (BIBLE "A committed attack means
#   what it shows": prepare, commit, execute, recover): for recovery_seconds, the one value
#   every ordinary attack reads from telegraph_record.gd, the unit stands where it struck
#   and starts nothing. The recovery runs inside rest_seconds, so the cadence is unchanged.
# - A unit ready to attack asks the attacker budget (attack_budget.gd, SQ2) for one of its
#   slots first; refused, it keeps circling and waits its turn. The slot goes back when
#   the attack ends, however it ends.
#
# Subclasses set the dials in _configure(), build the tool in _build_tool(), commit the
# telegraph in _commit() and run the mechanic in _live(delta) -> bool (false ends it).

enum Phase { ROAM, WARN, LIVE }

const INTERRUPT := 10.0
# Kinds that set their own body yaw every tick, so the gait's turn would fight it.
const GAIT_SKIP := ["linker"]
# One interrupt window for every ordinary pack kind (W13-INTEGRATION-3 SQ3). Start value
# from comps/roboquest/enemies-and-telegraphs.md:11 (1.25 s on nearly every row there).
const STAGGER_WINDOW := 1.25
# Interrupt priority (W13-INTEGRATION-3 SR3): one integer per state, judged by the rule the
# ability rows use (AbilityState.strongest): an interrupt lands only when strictly stronger.
# A hard knock (2) breaks the warning (1) but not the live phase (3); only the player breaking
# the hold (4) ends a live phase early. Roam (0) takes no interrupt call: a knock there stays a
# knock, never a stagger.
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
# Telegraphs committed and holds started, for tests and the balance read.
var warned := 0
var caught := 0
# The last warning's committed seconds, for the telegraph-before-hold check.
var last_warn := 0.0
# Set when the player broke this unit's hold; the live phase ends on the next tick.
var broken_by := ""
# Holds started in this live phase; a one-shot tool (a cup, a net) catches once.
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
# The per-kind dial on the interrupt: a knock must reach INTERRUPT * impact_resist.
var impact_resist := 1.0
# Seconds left in the stagger window, and staggers taken, for tests and presentation.
# Not stagger_left/staggered(): those names mark a posture fighter (boss_contract.gd,
# combat.gd's Ram Prow guard), and a pack kind must still take the prow shove.
var stun_left := 0.0
var staggers := 0
# The vulnerable tail after an attack (W13-INTEGRATION-3 SQ1): the shared record value, and
# the seconds of it left. Not a phase of its own: state_name() still reads "roam".
var recovery_seconds := TelegraphRecord.RECOVERY
var recover_left := 0.0

var _t := 0.0
var _rest := 0.0
var _strafe := 1.0
var _crew: MeshInstance3D


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = spec.get("kind", "chaser")
	row = Roster.row(kind)
	faction = Roster.faction_of(kind)
	holds = spec.get("holds")
	fleet = spec.get("fleet")
	if holds != null:
		holds.released.connect(_on_hold_released)
	# The bot supplies its own spawn-order sign; otherwise the sign follows this run's spawn order.
	_strafe = float(get_meta("bot_strafe")) if has_meta("bot_strafe") else _spawn_order_sign()
	# Tool ratings keep raw stage threat; only initialized HP reads the health dial.
	var stage_threat: float = spec.get("stage_threat", threat)
	_configure(stage_threat)
	if spec.has("stage_threat"):
		_set_health(max_hp / stage_threat * threat)
	# A unit always closes to where its attack reaches before it circles.
	keep_far = minf(keep_far, attack_range * 0.9)
	_rest = first_rest
	_build_crew()
	_build_tool()
	if walk_speed > 0.0 and not kind in GAIT_SKIP:
		_gait = EnemyGait.new()
		_gait.steps = not EnemyClips.ROWS.has(kind) and Roster.CHASSIS.get(kind, {}).get("move_class", "") != "airborne"
		if _reaction_bus != null:
			_reaction_bus.enemy_killed.connect(_on_crew_down)
			_reaction_bus.player_hit.connect(_on_ball_hit)
			_reaction_bus.near_miss.connect(_on_missed)


# Each counter setup in a run takes the next serial from world_root, so runtime identity never
# reaches gameplay: the sign alternates +1, -1, ... in spawn order. No root falls back to +1.
func _spawn_order_sign() -> float:
	if world_root == null:
		return 1.0
	var serial := int(world_root.get_meta("counter_spawn_serial", 0))
	world_root.set_meta("counter_spawn_serial", serial + 1)
	return 1.0 if serial % 2 == 0 else -1.0


func state_name() -> String:
	return ["roam", "warn", "live"][phase]


# The knock speed that breaks this unit's warning; INF when nothing does.
func interrupt_speed() -> float:
	return INTERRUPT * impact_resist if interruptible else INF


func state_priority() -> int:
	return STATE_PRIORITY[phase]


# The index of the interrupt in `priorities` that lands on this state this tick, else -1.
func resolve_interrupt(priorities: Array) -> int:
	return AbilityState.strongest(state_priority(), priorities)


func stunned() -> bool:
	return stun_left > 0.0


func recovering() -> bool:
	return recover_left > 0.0


# --- Subclass hooks -------------------------------------------------------------------

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


func _live(_delta: float) -> bool:
	return true


func _on_end() -> void:
	pass


func _pose() -> void:
	pass


# Pack pressure lead (pack_pressure.gd; identity without --pack-pressure): roam toward and size up the ball's
# roll SEEK_LEAD_S ahead along its curve, scaled by the spec's lead. A kind that aims its warn from the offset
# it is handed (the hooker, boom tender, deflector, anchor crew) lays it toward that roll; it is committed as ever.
const SEEK_LEAD_S := 1.0


func _seek(to_ball: Vector3) -> Vector3:
	var lead := float(spec.get("pressure", {}).get("lead", 0.0))
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


# --- The loop -------------------------------------------------------------------------

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
			_move(delta, Vector3.ZERO if stunned() or open else _roam(seek))
			if _gait != null and not stunned() and _knocked_speed() < 1.0 and seek.length() > 0.5:
				_gait.aim(_facing_yaw(seek))
			if not stunned() and not open and _rest <= 0.0 and _knocked_speed() < 1.0 and _wants_attack(seek):
				if AttackBudget.ask(self):
					_warn(seek)
			else:
				AttackBudget.withdraw(self)
		Phase.WARN:
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
	# Every wind-up drops the roaming look and glance, also for kinds that commit without _facing.
	if _gait != null:
		_gait.committed()
	_t = 0.0


# The Fleet's voice and this unit's mechanic tag over the type's warn sound (SOUND-STORY
# section 3): the type says what kind of danger, the voice who, the tag which unit.
func _voice(tele: Node3D) -> void:
	var motif := _motif()
	tele.owner_voice = Roster.voiced(String(Roster.faction(faction)["voice"]), motif)
	tele.mechanic_tag = Roster.voiced(String(row.get("tag", "")), motif)


func _motif() -> String:
	var player = _player()
	if player == null or player.class_def == null:
		return ""
	return String(player.class_def.motif)


# The player broke this unit's hold by their own action. The unit's tool is spent for
# this attack; a subclass may answer (the ramp's ride, the tether's sling).
func _on_hold_released(source_id: int, _kind: String, reason: String) -> void:
	if source_id != get_instance_id() or not reason in holds.PLAYER_BREAKS:
		return
	broken_by = reason
	_on_broken(reason)


func _on_broken(_method: String) -> void:
	pass


# The warning broke under a hard hit: the attack ends and the unit stands open for the
# shared window. Nothing here touches the ball; its knock carries it as before.
func _stagger() -> void:
	_end()
	staggers += 1
	stun_left = STAGGER_WINDOW
	_rest = maxf(_rest, STAGGER_WINDOW)


func _end() -> void:
	# Only an attack that went live recovers; a broken or empty warning does not.
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


# --- Holds ----------------------------------------------------------------------------

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


# --- Noticing (W1-85) ------------------------------------------------------------------
# A crew reads as a crew when it notices things. Looks only, from facts already on the bus,
# and only where the gait draws (never headless), so no clock, body or outcome moves.
const NOTICE_DOWN := 12.0
const NOTICE_HIT := 18.0
const NOTICE_MISS := 25.0


func _noticing() -> bool:
	return _gait != null and not _dead and EnemyMotion.active()


# A crewmate going down nearby: the head turns to it for a beat and the body flinches away.
func _on_crew_down(_kind: String, at: Vector3, _scrap: int) -> void:
	var from := Vector3(at.x - global_position.x, 0.0, at.z - global_position.z)
	if not _noticing() or from.length() > NOTICE_DOWN or from.length() < 0.5:
		return
	if phase == Phase.ROAM:
		_gait.glance(_facing_yaw(from))
	if _react_row.is_empty():
		react("flinch", -from, false, false)


# The ball took a hit: every crew in sight gives a small hop.
func _on_ball_hit(_amount: float, _source: String) -> void:
	if _noticing() and _flat_to_ball().length() <= NOTICE_HIT:
		_gait.hop()


# The ball slipped an attack: the nearest crew whose attack just struck lurches after it.
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


# The real ball, not what the sight sees: a hold is tested against where the ball is.
func _real_ball() -> Vector3:
	return holds.player.ball_position() if holds != null else _ball()


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


# --- The ancients' cast body ---------------------------------------------------------

# An ancient's material (VISUAL-LANGUAGE section 11): dull petrol enamel under the cap,
# no fasteners, and Cherenkov-blue seams as the only light.
func _enamel() -> StandardMaterial3D:
	var mat := Palette.solid(Roster.ANCIENT_ENAMEL)
	mat.metallic = 0.2
	mat.roughness = 0.35
	return mat


func _seam(size: Vector3, at: Vector3, parent: Node3D = self) -> MeshInstance3D:
	return _box(size, Roster.ANCIENT_LIGHT, at, 2.2, parent)


# --- The crew -------------------------------------------------------------------------

# An animal crew in Fleet paint with one brass requisition tag (VISUAL-LANGUAGE section
# 11; every crew figure is an animal, primer ruling 13): a rust body, a head with two
# ears, and the tag on the chest. The tool a subclass builds is always bigger.
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


# The body yaw that faces `to_ball`: the tool on +Z.
func _facing_yaw(to_ball: Vector3) -> float:
	return atan2(to_ball.x, to_ball.z)
