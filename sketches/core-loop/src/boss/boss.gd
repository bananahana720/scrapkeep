extends Node

const Rules := preload("res://src/boss/boss_rules.gd")
const Arena := preload("res://src/boss/arena.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const Target := preload("res://src/boss/boss_target.gd")
const Hazard := preload("res://src/boss/hazard.gd")
# How far ahead of the hull's nose the ram still hits; the lane publishes its front this far
# out, so the dodge watch lands the ram where the damage does.
const CHARGE_REACH := 1.5
# A charge that is not a ram stops this far short of the point where its nose would bury in the bank.
const CHARGE_RIM_CLEAR := 1.0
# A led lane clipped shorter than this is no charge (a hull resting at the bank with the led point beyond it
# would clip to nothing or less): that charge is aimed at the ball, as the stage aimed it.
const CHARGE_MIN_LANE := 4.0
# Clearance kept outside the solid hull box plus ball radius when a pickup lands inside the hull
# or the moving hull drives over one, so no pickup sits unreachable for PICKUP_LIFE.
const PICKUP_HULL_MARGIN := 0.25
const CodexEntries := preload("res://src/boss/codex_entries.gd")
const Palette := preload("res://src/core/palette.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const Field := preload("res://src/build/scrap_field.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")

# Writer E's module: Admiral Brindle and the Requisition in the Slag Bowl (DEMO-SPEC
# Brindle, BOSS-BRINDLE). Flow calls enter_arena(entry_velocity) after stage 3's
# launch; everything from there to boss_defeated happens here. The hull is fought as a
# posture Warden (boss_posture.gd, BossContract.TARGET): hits fill its bar, a full bar
# staggers him and opens the cockpit, and a contact in the opening cracks, then
# shatters, one of four chunks. Each weak point opens to one verb and adds to the bar,
# and every attack is a committed hazard that is drawn before it can hit.
#
# Each shattered chunk ends a phase, but never before its set piece has played, so the
# fight lasts at least 75 s however hard the ball hits. A chunk lost early holds the
# phase until its set piece ends: a grown ball routs him, it does not skip him. The
# fourth chunk is the scooter, taken by the catch.
#
# Phases ratchet (fight_phases.gd, Andrew 23 Oct): from the Furnace on, a lead attack is
# answered by a cued follow-up. The Furnace's reprise fills the other slag ring as the
# first drains; the Scuttle's hook turn re-aims a charge that ended short of the rim. Each
# sounds the ratchet cue first and then draws a short tell. A wall stun ends a hook turn
# like any combo, so baiting the second charge into the bank is the practised answer.
# Phases two and three open with a transition beat: the turn animation plays, the hull
# takes no posture and no attack commits until it ends (FightPhases.in_transition).

enum { IDLE, FIGHT, EJECT, DEFEATED }
const STATE_NAMES := ["idle", "fight", "eject", "defeated"]
const CHASE_PHASE := 4
const CHASE_NAME := "chase"
const RESCUE_DEPTH := 10.0
# A rescue point keeps at least this far from the Requisition's centre.
const RESCUE_CLEAR := 14.0
# The plate's colour when your punch is short of the live plating: combat's slate.
const PLATE_SHORT := Color("9fb0bf")
static var _pickup_materials := {}
static var _pickup_mesh: Mesh

var ctx
var state := IDLE
var phase := 0
var hp := Rules.MAX_HP
var max_hp := Rules.MAX_HP
# Seconds since arena entry, and since the current phase began.
var clock := 0.0
var phase_clock := 0.0
var arena
var ship
var scooter
# The scooter model's clips (eject, then chase), when its GLB loaded.
var _scooter_anim: AnimationPlayer
# The committed hazards still drawn or live; tests read them to check every hit.
var hazards: Array = []
var stuns := 0
var clashes := 0
var catches := 0

var _delta := 1.0 / 90.0
var _next_attack := 0.0
var _crane_turn := 0
# Challenge dial brindle.combo: follow-up attacks still owed after the lead; -1 when none is open.
var _combo_left := -1
var _cranes: Array = [{}, {}]
var _pickups: Array = []
var _slag_turn := 0
var _next_lobber := 0.0
var _lobbers: Array = []
# The phase 3 charge's states, kept as strings because tests and the bot read them. Every
# write goes through these names, and _step_charges sends an unknown one back to rest, so a
# misspelt state can never strand the Scuttle mid-charge.
const CHARGE_REST := "rest"
const CHARGE_BRACE := "brace"
const CHARGE_RUN := "run"
const CHARGE_RECOVER := "recover"
const CHARGE_STUN := "stun"
const CHARGE_HOOK := "hook"
var _charge := {}
var _grace := {}
var _eject := {}
var _ship_angle := 0.0
var _crest: Node3D
# Drone pads marked before the drone arrives: [{at, marker, age}].
var _drones: Array = []
# While set, the hull ignores the ball: a charge hit's shove must clear the lane before
# the bow can touch it again.
var _ghost_until := -1.0
var _posture := BossPosture.new(Rules.POSTURE)
var _phases: FightPhases
# The Furnace's owed reprise ring: {at, cue_at, cued, turn}; empty when none is owed.
var _reprise := {}
# The Scuttle's hint (take_hint): tries that came up short this phase, the best punch the
# ball has shown in it, and the fight clock the hint may next show at.
var _short_tries := 0
var _scuttle_punch := 0.0
var _hint_next := 0.0
# The reel's paid hits this phase and the fight clock of the last one (Rules.REEL_*).
var _reel_hits := 0
var _reel_last := -INF
# The phase beat's preview (FX-03): the next phase's signature mark in the harmless bone style,
# drawn through the transition beat and cleared when it ends; null when none shows.
var _preview: Node3D
# W1-105 (A11): the Furnace reprise's harmless preview band, drawn for FightPhases.CUE_LEAD
# while the ratchet cue plays and cleared when the reprise commits or cancels.
var _reprise_preview: Node3D
# Fight clock of the last committed attack (used to keep reel gaps <= Rules.REEL_MAX_GAP)
# and whether the previous tick was reeling (to clamp a pending phase 2 timer on reel entry).
var _last_commit_at := -INF
var _was_reeling := false
# Planted fault seam for tests/brindle_reel_test.gd only ("stop" or "no_brace"); always "" in play.
var _reel_plant := ""


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Boss"
	if "boss" in ctx:
		ctx.boss = self
	else:
		ctx.set_meta("boss", self)
	if ctx.codex != null and ctx.codex.has_method("declare"):
		for entry in CodexEntries.all():
			var declared: Dictionary = entry.duplicate()
			declared["category"] = CodexEntries.CATEGORY
			ctx.codex.declare(declared)
	ctx.events.stage_entered.connect(func(_stage: int, _retry: bool):
		exit_arena()
		_sync_crest())
	ctx.events.run_started.connect(func(_class_id: String):
		exit_arena()
		_sync_crest())
	ctx.events.flow_changed.connect(_on_flow_changed)
	ctx.events.enemy_struck.connect(_on_enemy_struck)
	ctx.events.enemy_killed.connect(_on_enemy_killed)


func state_name() -> String:
	return STATE_NAMES[state]


func active() -> bool:
	return state == FIGHT or state == EJECT


# --- Entry and exit ------------------------------------------------------------------

# Builds the Slag Bowl, puts the ball on it keeping its horizontal speed (raised to
# cruise if it arrives slower, a gift), and starts phase 1. Calling it again, as the
# arena retry does, tears the old fight down first.
func enter_arena(entry_velocity: Vector3) -> void:
	exit_arena()
	arena = Arena.take_ahead()
	arena.position = Arena.place_ahead(ctx.terrain, ctx.run.stage)
	ctx.root.add_child(arena)
	ship = Requisition.new()
	arena.add_child(ship)
	ship.build(self)
	ctx.camera.set_contact_subject(ship)
	state = FIGHT
	_posture = BossPosture.new(Rules.POSTURE)
	_phases = FightPhases.boss("brindle", ctx.events)
	hp = Rules.MAX_HP
	max_hp = Rules.MAX_HP
	clock = 0.0
	stuns = 0
	clashes = 0
	catches = 0
	_ship_angle = deg_to_rad(Arena.ENTRY_ANGLE) + PI
	_move_ship_on_circle(0.0)
	_place_ball(entry_velocity)
	ctx.flow.boss_active = true
	ctx.flow.boss_plating = Rules.HULL_PLATING
	_publish("boss_arena_entered")
	_enter_phase(1)
	_update_readout()


func _place_ball(entry_velocity: Vector3) -> void:
	var flat := maxf(Vector2(entry_velocity.x, entry_velocity.z).length(), ctx.tuning.f("cruise"))
	var heading: Vector3 = arena.entry_heading()
	var velocity := heading * flat + Vector3.UP * clampf(entry_velocity.y, -8.0, 0.0)
	var at: Vector3 = arena.entry_point()
	ctx.player.reset_to(at, velocity)
	ctx.camera.snap(heading)
	# Ruling cv: the fall into the bowl is marked with landing rings and a pad, as a stage's arrival is.
	var world = ctx.root.get("world") if ctx.root != null else null
	if world != null and world.has_method("mark_arrival"):
		var ground: RefCounted = arena.ground_query()
		world.mark_arrival(at, velocity, Callable(ground, "height"))


# The heading the ball enters the bowl on, for the launch into it to turn to in flight (flow.arrival_heading_after).
func arrival_heading() -> Vector3:
	return Arena.arrival_heading()


# Frees everything the fight built. The ball, the run and the crest are left alone.
func exit_arena() -> void:
	for lobber in _lobbers:
		if is_instance_valid(lobber):
			# Freed at the frame's end, and its ground is the bowl, which leaves the tree below.
			lobber.set_physics_process(false)
			lobber.queue_free()
	_lobbers.clear()
	if is_instance_valid(arena):
		arena.get_parent().remove_child(arena)
		arena.queue_free()
	arena = null
	if ctx.camera != null:
		ctx.camera.clear_contact_subject(ship)
	ship = null
	scooter = null
	_scooter_anim = null
	hazards.clear()
	_pickups.clear()
	_grace.clear()
	_cranes = [{}, {}]
	_charge = {}
	_eject = {}
	_preview = null
	_reprise_preview = null
	_last_commit_at = -INF
	_was_reeling = false
	_drones.clear()
	_ghost_until = -1.0
	if state != DEFEATED:
		state = IDLE
	phase = 0


func _on_flow_changed(flow_state: String) -> void:
	if flow_state in ["title", "class_select", "summary"]:
		exit_arena()
		state = IDLE


# --- The tick ------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if active() and ctx.flow.state_name() == "boss":
		advance(delta)


func advance(delta: float) -> void:
	if not active() or not is_instance_valid(arena) or not is_instance_valid(ship):
		return
	_delta = maxf(delta, 0.0001)
	clock += delta
	phase_clock += delta
	if _phases != null:
		_phases.tick(clock)
	var ball: Vector3 = ctx.player.ball_position()
	_rescue(ball)
	arena.step(clock)
	_step_vents(ball)
	_step_hazards(delta, ball)
	_step_trail(ball)
	_step_drones(delta)
	_step_preview(delta)
	if state == FIGHT:
		_step_posture(delta)
		match phase:
			1:
				_step_cranes(delta, ball)
			2:
				_step_furnace(delta)
			3:
				_step_charges(delta, ball)
		_was_reeling = reeling()
		_maybe_turn_phase()
	elif state == EJECT:
		_step_scooter(delta)
	_step_ghost()
	ctx.flow.boss_plating = live_plating()
	_update_readout()


func _maybe_turn_phase() -> void:
	if state != FIGHT or _chunks_lost() < phase or phase_clock < Rules.PHASE_MIN_SECONDS[phase - 1]:
		return
	if phase < 3:
		_enter_phase(phase + 1)
	else:
		_begin_eject()


# What the music follows in the fight: how full the posture bar is toward the stagger
# that breaks this phase's chunk (1 once it is broken), whether the phase is held on a
# broken chunk, and how much of the phase's minimum time has run. Empty outside phases
# 1 to 3.
func music_state() -> Dictionary:
	if phase < 1 or phase > 3:
		return {}
	var held := _held()
	return {
		"in_phase": 1.0 if held else clampf(_posture.posture / BossPosture.FULL, 0.0, 1.0),
		"held": held,
		"phase_seconds": phase_clock / maxf(float(Rules.PHASE_MIN_SECONDS[phase - 1]), 1.0),
	}


func _chunks_lost() -> int:
	return BossPosture.CHUNKS - _posture.chunks


# This phase's chunk is broken and its set piece has not finished playing.
func _held() -> bool:
	return state == FIGHT and _chunks_lost() >= phase


# The hold banks: its hits fill the bar the next phase opens with (Rules.HELD_BANK).
func banking() -> bool:
	return _held() and phase < 3 and not _in_transition()


# The reel (W1-61, ruling ed): a held phase past its transition beat. Brindle keeps attacking
# at a slowed cadence, and a hull hit sheds scrap and fills the ultimate (_reel_hit). Effects
# and bots read this.
func reeling() -> bool:
	return _held() and not _in_transition()


# A ball contact on the hull in the reel (weapon fire sheds nothing): at most one per Rules.REEL_GAP and Rules.REEL_HITS a phase sheds
# Rules.REEL_SCRAP as pickups between the hull and the ball and publishes boss_reeled, which
# the ultimate meter pays.
func _reel_hit() -> void:
	if not reeling() or _reel_hits >= Rules.REEL_HITS or clock - _reel_last < Rules.REEL_GAP:
		return
	_reel_hits += 1
	_reel_last = clock
	var here: Vector3 = ship.global_position
	var ball: Vector3 = ctx.player.ball_position()
	var toward := Vector3(ball.x - here.x, 0.0, ball.z - here.z)
	toward = toward.normalized() if toward.length() > 0.5 else Vector3(ship.heading.x, 0.0, ship.heading.z).normalized()
	var side := toward.cross(Vector3.UP).normalized()
	var centre: Vector3 = arena.global_position
	var mid := here + toward * Rules.REEL_REACH
	for k in Rules.REEL_PICKUPS:
		var t := (k + 0.5) / float(Rules.REEL_PICKUPS) * 2.0 - 1.0
		var spot := mid + side * t * Rules.REEL_SPREAD
		var out := Vector2(spot.x - centre.x, spot.z - centre.z).limit_length(Arena.FLOOR_R - 4.0)
		spot = Vector3(centre.x + out.x, 0.0, centre.z + out.y)
		var value := Rules.REEL_SCRAP / Rules.REEL_PICKUPS + (1 if k < Rules.REEL_SCRAP % Rules.REEL_PICKUPS else 0)
		_place_pickup(Vector3(spot.x, arena.ground(spot) + 0.9, spot.z), value, "reel")
	_publish("boss_reeled", [Vector3(mid.x, arena.ground(mid), mid.z), Rules.REEL_SCRAP])


# How much of the bar a hold can bank, 0 to 1, for the plate's mark.
func bank_cap() -> float:
	return Rules.HELD_BANK / BossPosture.FULL


# A hit on a held hull: it breaks nothing, and its gain stops at the bank's cap.
func _bank(result: Dictionary) -> void:
	result["gain"] = clampf(float(result.get("gain", 0.0)), 0.0, maxf(0.0, Rules.HELD_BANK - _posture.posture)) if banking() else 0.0
	result["crack"] = false
	result["shatter"] = false
	result["dealt"] = 0.0


func _enter_phase(next: int) -> void:
	_cancel_hazards()
	if next > 1:
		_spill_break()
	phase = next
	phase_clock = 0.0
	_reel_hits = 0
	_reel_last = -INF
	_last_commit_at = clock
	_was_reeling = false
	ship.set_hook_brace(false)
	ship.show_cranes(next == 1)
	ship.open_caps(next == 2)
	match next:
		1:
			_next_attack = Rules.INTRO_SECONDS
			_crane_turn = 0
			_combo_left = -1
		2:
			_next_attack = clock + 2.0
			_next_lobber = clock + 3.0
			_slag_turn = 0
			_combo_left = -1
		3:
			ship.shed_armour()
			ship.cockpit_open(true, "enter_scuttle")
			_combo_left = -1
			_short_tries = 0
			_scuttle_punch = 0.0
			_hint_next = 0.0
			_charge = {"state": CHARGE_REST, "timer": ChallengeDials.period("brindle", Rules.CHARGE_REST, 3)}
	ship.cue_phase(next)
	_publish("boss_phase_changed", [next, Rules.PHASE_NAMES[next - 1]])
	if _phases != null:
		_phases.enter(next, clock)
	_show_preview(next)


# Harmless bone-style annulus preview shared by the Furnace phase beat (FX-03) and the cued
# slag reprise (W1-105 / A11): never hurts, never joins Threat.GROUP or hazards.
func _bone_ring(id: String, band: Vector2, warn_s: float, floor_s := -1.0) -> Node3D:
	var h = Hazard.new()
	h.ground = arena.ground
	h.color = Palette.SAND
	if floor_s > 0.0:
		h.warn_floor = floor_s
	h.commit_annulus(id, Hazard.Threat.Type.INSTANT, arena.global_position, band, 0.0, warn_s, 0.01)
	arena.add_child(h)
	return h


# FX-03: through the beat that opens the Furnace or the Scuttle, while no attack can commit, the
# phase's signature mark draws once in the harmless bone style (threat_grammar.gd, a dashed
# outline): the slag ring its first lead fills, or a charge lane from the hull's nose toward the
# ball. It never hurts and is never a threat; it shows the new rule before it is live.
func _show_preview(next: int) -> void:
	_clear_preview()
	if not _in_transition() or not next in [2, 3]:
		return
	var beat: float = _phases.transition()
	if next == 2:
		_preview = _bone_ring("preview_slag", Arena.RING_A, beat)
		return
	var h = Hazard.new()
	h.ground = arena.ground
	h.color = Palette.SAND
	var from: Vector3 = ship.global_position
	var heading := _aim_at(ctx.player.ball_position())
	var half := Requisition.HULL.z * 0.5
	var length := minf(Rules.CHARGE_STOP_R, _travel_to_rim(from, heading))
	h.commit_lane("preview_charge", Hazard.Threat.Type.LANE, from, heading, half, length + half, Requisition.HULL.x * 0.5 + 1.0,
		0.0, beat, 0.01)
	arena.add_child(h)
	_preview = h


func preview() -> Node3D:
	return _preview if is_instance_valid(_preview) else null


# W1-105 (A11): harmless bone-style preview band for the cued Furnace reprise slag ring.
func reprise_preview() -> Node3D:
	return _reprise_preview if is_instance_valid(_reprise_preview) else null


func _show_reprise_preview(turn: int) -> void:
	_clear_reprise_preview()
	if state != FIGHT or phase != 2 or not is_instance_valid(arena):
		return
	_reprise_preview = _bone_ring("preview_reprise_slag", _slag_band(turn), FightPhases.CUE_LEAD, FightPhases.CUE_LEAD)


func _clear_reprise_preview() -> void:
	if is_instance_valid(_reprise_preview):
		_reprise_preview.queue_free()
	_reprise_preview = null


func _step_preview(delta: float) -> void:
	if _preview != null:
		if not is_instance_valid(_preview) or state != FIGHT or not _in_transition():
			_clear_preview()
		else:
			_preview.step(delta)
	if _reprise_preview != null:
		if not is_instance_valid(_reprise_preview) or state != FIGHT or phase != 2 \
				or _reprise.is_empty() or not bool(_reprise.get("cued", false)):
			_clear_reprise_preview()
		else:
			_reprise_preview.step(delta)


func _clear_preview() -> void:
	if is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null


# Test and dev hook: the fight as if the earlier phases had just been won. The chunks left are
# set, not only lowered, so a jump back to an earlier phase opens it with its own chunk whole:
# a chunk already broken would hold the phase and start the reel (W1-61), not the fight.
func jump_to_phase(next: int) -> void:
	if not active():
		return
	if next > 1:
		_posture.chunks = BossPosture.CHUNKS - (mini(next, 4) - 1)
		hp = float(_posture.chunks)
	if next > 3:
		_begin_eject()
	else:
		_enter_phase(next)


# --- Phase 1: the Requisition and its cranes ------------------------------------------

func _move_ship_on_circle(delta: float) -> void:
	_ship_angle += Rules.CIRCLE_SPEED / Rules.CIRCLE_RADIUS * delta
	ship.move_to(arena.point_at(_ship_angle, Rules.CIRCLE_RADIUS), Arena.tangent(_ship_angle))


# The delay to the next crane or slag attack: the normal one, or WARN_GAP while the
# brindle.combo dial still owes follow-ups.
func _paced(normal: float) -> float:
	_combo_left = ChallengeDials.combo_step("brindle", _combo_left)
	if _combo_left > 0:
		return ChallengeDials.WARN_GAP
	_combo_left = -1
	return normal


# The rest before the next charge: WARN_GAP while a combo is owed, else CHARGE_REST scaled
# (slowed during a reel, ruling ed).
func _rest_time() -> float:
	if _combo_left > 0:
		return ChallengeDials.WARN_GAP
	_combo_left = -1
	var rest := ChallengeDials.period("brindle", Rules.CHARGE_REST, 3)
	if reeling():
		return minf(rest * Rules.REEL_PERIOD_MULT, Rules.REEL_MAX_GAP)
	return rest


func _step_cranes(delta: float, ball: Vector3) -> void:
	_move_ship_on_circle(delta)
	if clock >= _next_attack and not (reeling() and _reel_plant == "stop"):
		var committed := _commit_crane(_crane_turn, ball)
		if not committed:
			committed = _commit_crane(1 - _crane_turn, ball)
		if committed:
			_crane_turn = 1 - _crane_turn
			var base_period := ChallengeDials.period("brindle", Rules.CRANE_PERIOD, 1)
			var cadence := minf(base_period * Rules.REEL_PERIOD_MULT, Rules.REEL_MAX_GAP) if reeling() else _paced(base_period)
			_next_attack = clock + cadence
		else:
			_next_attack = clock + 0.25
	for i in 2:
		_step_crane(i, delta, ball)


# The sector is centred on the ground under the crane's pivot and aimed at the ball's
# bearing when it commits; it does not follow the ball after that.
func _commit_crane(i: int, ball: Vector3) -> bool:
	var c: Dictionary = _cranes[i]
	if c.has("hazard") and is_instance_valid(c["hazard"]) and not c["hazard"].is_done():
		return false
	if c.get("held", 0) > 0:
		return false
	var pivot: Vector3 = ship.pivot(i)
	var centre := Vector3(pivot.x, arena.ground(pivot), pivot.z)
	var to_ball := Vector3(ball.x - centre.x, 0.0, ball.z - centre.z)
	var bearing: float = atan2(to_ball.z, to_ball.x) if to_ball.length() > 0.5 else arena.angle_of(pivot)
	var sweep := 1.0 if i == 0 else -1.0
	var h = _new_hazard()
	h.commit_sector("crane_%d" % i, Hazard.Threat.Type.WAVE, centre, Rules.CRANE_BAND, bearing - sweep * Rules.CRANE_SPAN * 0.5,
		bearing + sweep * Rules.CRANE_SPAN * 0.5, Rules.CRANE_REACH, ChallengeDials.tell("brindle", Rules.CRANE_WARN, Hazard.MIN_WARN), Rules.CRANE_SWEEP)
	_add_hazard(h)
	_last_commit_at = clock
	ship.cue("crane_warn", h.get_instance_id())
	_cranes[i] = {"hazard": h, "caught": false, "held": 0, "trail": [], "values": [], "dripped": 0, "drip": 0.0}
	_publish("boss_attack_telegraphed", ["crane_sweep", h.warn_seconds])
	return true


func _step_crane(i: int, delta: float, ball: Vector3) -> void:
	var c: Dictionary = _cranes[i]
	var at: Vector3 = ship.magnet_rest(i)
	var glow := 0.0
	var h = c.get("hazard")
	if h != null and is_instance_valid(h) and not h.is_done():
		var head_r: float = (h.r_in + h.r_out) * 0.5
		if h.state == Hazard.WARN:
			glow = 0.5 + 0.5 * sin(h.age * TAU * FlashGuard.rate(4.0))
			at = at.lerp(_head(h, h.a_from, head_r), clampf(h.age / h.warn_seconds, 0.0, 1.0))
		else:
			glow = 1.0
			ship.cue("crane_sweep", h.get_instance_id())
			at = _head(h, lerpf(h.a_from, h.a_to, h.live_fraction()), head_r)
			if not c["caught"] and h.contains(ball) and _swept(h, ball):
				_crane_catch(i, ball, at)
		c["hold_at"] = at
	elif c.get("held", 0) > 0:
		at = c["hold_at"]
	if c.get("held", 0) > 0:
		c["drip"] -= delta
		while c["drip"] <= 0.0 and c["held"] > 0:
			_drip(c)
			c["drip"] += Rules.DRIP
	ship.set_magnet(i, at, glow if c.get("held", 0) <= 0 else maxf(glow, 0.6))


func _head(h, angle: float, r: float) -> Vector3:
	var p: Vector3 = h.centre + Arena.dir(angle) * r
	return Vector3(p.x, h.centre.y + 3.5, p.z)


# True when the magnet crossed the ball's bearing this tick: the part of the committed
# sector the sweep has just passed through.
func _swept(h, ball: Vector3) -> bool:
	var span := absf(h.a_to - h.a_from)
	var margin := 1.0 / maxf(1.0, Vector2(ball.x - h.centre.x, ball.z - h.centre.z).length())
	var u: float = h.sweep_offset(ball)
	return u >= span * h.prev_fraction - margin and u <= span * h.live_fraction() + margin


func _crane_catch(i: int, ball: Vector3, magnet_at: Vector3) -> void:
	var c: Dictionary = _cranes[i]
	c["caught"] = true
	catches += 1
	_tug(ball, magnet_at)
	if ctx.run.mass < 1.0:
		return
	var steal_share := Rules.REEL_STEAL_SHARE if reeling() else Rules.STEAL_SHARE
	var steal_cap := Rules.REEL_STEAL_MAX if reeling() else Rules.STEAL_MAX
	var amount := clampi(int(round(ctx.run.mass * steal_share)), Rules.STEAL_MIN, steal_cap)
	var taken: int = ctx.run.lose_scrap(amount, ball, "crane")
	if taken <= 0:
		return
	var h = c["hazard"]
	var r := Vector2(ball.x - h.centre.x, ball.z - h.centre.z).length()
	if reeling():
		# While reeling, the magnet swings stolen scrap out toward the outer floor so camping
		# under the hull sheds excess scrap armour unless the player chases the trail or shoots it.
		r = clampf(maxf(r + 12.0, 30.0), 30.0, Arena.FLOOR_R - 4.0)
	var start: float = atan2(ball.z - h.centre.z, ball.x - h.centre.x)
	var sweep := signf(h.a_to - h.a_from)
	var trail: Array = []
	var values: Array = []
	for k in Rules.TRAIL_PICKUPS:
		var a := start + sweep * Rules.TRAIL_ARC * float(k) / float(Rules.TRAIL_PICKUPS - 1)
		var p: Vector3 = h.centre + Arena.dir(a) * r
		trail.append(Vector3(p.x, arena.ground(p) + 0.9, p.z))
		values.append(taken / Rules.TRAIL_PICKUPS + (1 if k < taken % Rules.TRAIL_PICKUPS else 0))
	c["held"] = taken
	c["trail"] = trail
	c["values"] = values
	c["dripped"] = 0
	c["drip"] = 0.0


# Lifts the ball and pulls it a little toward the magnet. It adds to the ball's motion
# and never cancels it, so a catch costs scrap, not momentum.
func _tug(ball: Vector3, magnet_at: Vector3) -> void:
	if ctx.calm:
		return
	var pull := Vector3(magnet_at.x - ball.x, 0.0, magnet_at.z - ball.z)
	pull = pull.normalized() if pull.length() > 0.1 else Vector3.ZERO
	ctx.player.crowd_control("brindle_tug", (Vector3.UP * Rules.TUG_LIFT + pull * Rules.TUG_PULL) / _delta, false)


func _drip(c: Dictionary) -> void:
	var k: int = c["dripped"]
	if k >= c["trail"].size():
		c["held"] = 0
		return
	_place_pickup(c["trail"][k], c["values"][k], "returned")
	c["held"] -= c["values"][k]
	c["dripped"] = k + 1
	ship.cue("magnet_hold_drip", int(c["dripped"]))


# A shot on a magnet that still holds scrap drops the rest in one pile under it.
func _drop_held(i: int) -> void:
	var c: Dictionary = _cranes[i]
	var rest := 0
	for k in range(c["dripped"], c["trail"].size()):
		rest += c["values"][k]
	c["dripped"] = c["trail"].size()
	c["held"] = 0
	if rest <= 0:
		return
	var under: Vector3 = ship.magnets[i].global_position
	var ground := Vector3(under.x, arena.ground(under) + 0.9, under.z)
	var piles := 4
	for k in piles:
		var value := rest / piles + (1 if k < rest % piles else 0)
		if value > 0:
			_place_pickup(ground + Arena.dir(TAU * k / piles) * 1.2, value, "returned")
	_discover(CodexEntries.CRANE_DROP, ground)


func _pickup_hull_extents() -> Vector2:
	return Vector2(Requisition.HULL.x * 0.5 + Tuning.RADIUS + PICKUP_HULL_MARGIN,
		Requisition.HULL.z * 0.5 + Tuning.RADIUS + PICKUP_HULL_MARGIN)


func _inside_hull(at: Vector3) -> bool:
	if not is_instance_valid(ship):
		return false
	var loc: Vector3 = ship.to_local(at)
	var ext := _pickup_hull_extents()
	return absf(loc.x) < ext.x and absf(loc.z) < ext.y


# Keeps every arena pickup outside the Requisition's solid hull footprint while staying on
# the playable floor (for shed/reel piles) or inside the bowl wall. Pickups already clear
# of the hull keep their exact spot.
func _clear_of_hull(at: Vector3, floor_only: bool) -> Vector3:
	if not is_instance_valid(ship) or not is_instance_valid(arena) or not _inside_hull(at):
		return at
	var loc: Vector3 = ship.to_local(at)
	var push := _pickup_hull_extents() + Vector2(0.05, 0.05)
	var centre: Vector3 = arena.global_position
	var max_r := Arena.FLOOR_R - 4.0 if floor_only else Arena.BANK_R - 4.0
	var candidates: Array[Vector3] = [
		Vector3(push.x, 0.0, loc.z),
		Vector3(-push.x, 0.0, loc.z),
		Vector3(loc.x, 0.0, push.y),
		Vector3(loc.x, 0.0, -push.y),
		Vector3(push.x, 0.0, push.y),
		Vector3(push.x, 0.0, -push.y),
		Vector3(-push.x, 0.0, push.y),
		Vector3(-push.x, 0.0, -push.y),
	]
	var best := Vector3.INF
	var best_d := INF
	for c in candidates:
		var w: Vector3 = ship.to_global(c)
		if Vector2(w.x - centre.x, w.z - centre.z).length() > max_r:
			continue
		var d := Vector2(w.x - at.x, w.z - at.z).length()
		if d < best_d:
			best_d = d
			best = w
	if best == Vector3.INF:
		var ship_pos: Vector3 = ship.global_position
		var inward := Vector3(centre.x - ship_pos.x, 0.0, centre.z - ship_pos.z)
		inward = inward.normalized() if inward.length() > 0.1 else Vector3.FORWARD
		var spot: Vector3 = ship_pos + inward * (push.length() + 0.5)
		var out := Vector2(spot.x - centre.x, spot.z - centre.z).limit_length(max_r)
		best = Vector3(centre.x + out.x, 0.0, centre.z + out.y)
	return Vector3(best.x, arena.ground(best) + 0.9, best.z)


func _place_pickup(at: Vector3, value: int, source: String) -> void:
	_spawn_pickup(_clear_of_hull(at, source in ["shed", "reel"]), value, source)


func _spawn_pickup(at: Vector3, value: int, source: String) -> void:
	var node := Node3D.new()
	node.name = "BrindleReward"
	if _pickup_mesh == null:
		var packed := load("res://assets/models/bosses/boss_pickup.glb") as PackedScene
		var scene := packed.instantiate() if packed != null else null
		var part := scene.find_child("ScrapChunk", true, false) as MeshInstance3D if scene != null else null
		if part != null and part.mesh != null and part.mesh.get_surface_count() == 1:
			var mat := part.mesh.surface_get_material(0)
			if mat != null and mat.resource_name == "field":
				_pickup_mesh = part.mesh
		if scene != null:
			scene.free()
	if _pickup_mesh == null:
		var fallback := BoxMesh.new()
		fallback.size = Vector3.ONE * 0.7
		_pickup_mesh = fallback
	if not _pickup_materials.has("reward"):
		var made: ShaderMaterial = Field._pickup_material(Palette.AMBER)
		made.resource_name = "field"
		_pickup_materials["reward"] = made
	var reward_material: ShaderMaterial = _pickup_materials["reward"]
	var core := MeshInstance3D.new()
	core.name = "ScrapCore"
	core.mesh = _pickup_mesh
	core.scale = Vector3.ONE * 0.14
	core.position.y = 0.12
	core.material_override = reward_material
	node.add_child(core)
	var canister_mesh := CylinderMesh.new()
	canister_mesh.top_radius = 0.38
	canister_mesh.bottom_radius = 0.38
	canister_mesh.height = 0.72
	canister_mesh.radial_segments = 12
	var mesh_arrays := canister_mesh.get_mesh_arrays()
	var vertices := mesh_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	colors.fill(Palette.AMBER)
	mesh_arrays[Mesh.ARRAY_COLOR] = colors
	var painted_mesh := ArrayMesh.new()
	painted_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	var canister := MeshInstance3D.new()
	canister.name = "RewardCanister"
	canister.mesh = painted_mesh
	canister.material_override = reward_material
	canister.position.y = canister_mesh.height * 0.5
	node.add_child(canister)
	var band := MeshInstance3D.new()
	band.name = "BoneBand"
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.405
	band_mesh.bottom_radius = 0.405
	band_mesh.height = 0.12
	band_mesh.radial_segments = 12
	band.mesh = band_mesh
	band.material_override = Palette.solid(Palette.SAND)
	band.position.y = 0.12
	canister.add_child(band)
	arena.add_child(node)
	node.global_position = Vector3(at.x, at.y - 0.9, at.z)
	_pickups.append({"node": node, "value": value, "at": at, "age": 0.0, "source": source})


# The spill trail pays stolen mass back through add_scrap, the one way scrap is gained.
# Spill and kill pickups also pay cogs one for one; a returned pickup is the ball's own
# stolen mass, so it pays mass only and never mints cogs. A shed pile (take_spill) pays
# through recover_mass and rings the stage spill's reclaim chime.
func _step_trail(ball: Vector3) -> void:
	var kept: Array = []
	for p in _pickups:
		p["age"] += _delta
		var node: Node3D = p["node"]
		if _inside_hull(p["at"]):
			var moved := _clear_of_hull(p["at"], p["source"] in ["shed", "reel"])
			p["at"] = moved
			node.global_position = Vector3(moved.x, moved.y - 0.9, moved.z)
		if ball.distance_to(p["at"]) <= Rules.PICKUP_REACH:
			# A shed pile is the ball's own armour coming back, as a stage spill cluster pays:
			# mass only, through recover_mass, with no wallet scrap, cogs or pickup event.
			if p["source"] == "shed":
				ctx.run.recover_mass(p["value"])
				var field = ctx.build.get("scrap") if ctx.get("build") != null else null
				if field != null and field.has_signal("recovered"):
					field.recovered.emit(int(p["value"]))
			else:
				ctx.run.add_scrap(p["value"], p["at"])
			if not p["source"] in ["returned", "shed"]:
				ctx.run.add_cogs(p["value"])
				ctx.events.cogs_collected.emit(p["value"], ctx.run.cogs)
			node.queue_free()
			continue
		if p["age"] >= Rules.PICKUP_LIFE:
			if p["source"] == "shed":
				ctx.run.note_spill_expired(p["value"])
			node.queue_free()
			continue
		node.rotate_y(_delta * 2.5)
		kept.append(p)
	_pickups = kept


# A phase break sheds a ring of scrap around the ship, on the ground, to roll up.
func _spill_break() -> void:
	var at: Vector3 = ship.global_position
	for k in Rules.BREAK_PICKUPS:
		var p: Vector3 = at + Arena.dir(TAU * k / Rules.BREAK_PICKUPS) * Rules.BREAK_RADIUS
		var value := Rules.BREAK_SPILL / Rules.BREAK_PICKUPS + (1 if k < Rules.BREAK_SPILL % Rules.BREAK_PICKUPS else 0)
		_place_pickup(Vector3(p.x, arena.ground(p) + 0.9, p.z), value, "spill")


# An armour hit in the bowl spills the way a stage hit does (ruling aw): the hit's spill
# share lands as "shed" piles in a fan ahead of the ball, so a stripped ball can roll its
# mass back up instead of stalling at heft 1.0. A shed pile pays back like a stage spill
# cluster (recover_mass: mass only) and, unreached after PICKUP_LIFE, counts as expired.
# False when no fight is on, and the caller destroys the spill as before.
func take_spill(from: Vector3, heading: Vector3, spill: int) -> bool:
	if not active() or not is_instance_valid(arena) or spill <= 0:
		return false
	var flat := Vector3(heading.x, 0.0, heading.z).normalized()
	if flat.length() < 0.1:
		flat = Vector3.FORWARD
	var side := flat.cross(Vector3.UP).normalized()
	var centre: Vector3 = arena.global_position
	var n := mini(Rules.SPILL_PILES, spill)
	for k in n:
		var t := (k + 0.5) / float(n)
		var spot := from + flat * Rules.SPILL_AHEAD + side * (t * 2.0 - 1.0) * Rules.SPILL_SIDE
		var out := Vector2(spot.x - centre.x, spot.z - centre.z).limit_length(Arena.FLOOR_R - 4.0)
		spot = Vector3(centre.x + out.x, 0.0, centre.z + out.y)
		var value := spill / n + (1 if k < spill % n else 0)
		_place_pickup(Vector3(spot.x, arena.ground(spot) + 0.9, spot.z), value, "shed")
	return true


# The scrap field is stage content and idles in the arena, so a drone killed here drops
# its scrap as a pickup where it died.
func _on_enemy_killed(kind: String, at: Vector3, scrap_value: int) -> void:
	if not active() or kind != "lobber" or not is_instance_valid(arena):
		return
	_place_pickup(Vector3(at.x, arena.ground(at) + 0.9, at.z), maxi(1, scrap_value), "kill")


func pickups_left() -> Array:
	return _pickups.map(func(p): return {"at": p["at"], "value": p["value"], "source": p["source"]})


# --- Phase 2: the furnace --------------------------------------------------------------

func _step_furnace(delta: float) -> void:
	var here: Vector3 = ship.global_position
	var to_centre := Vector3(arena.global_position.x - here.x, 0.0, arena.global_position.z - here.z)
	var parked := to_centre.length() <= 0.2
	if not parked:
		var move := minf(to_centre.length(), Rules.CIRCLE_SPEED * delta)
		var at := here + to_centre.normalized() * move
		ship.move_to(Vector3(at.x, arena.ground(at), at.z), ship.heading)
	# Entering a reel clamps a long pending normal slag timer so no gap over 6 s opens, while
	# honouring any reprise whose sound cue has already started.
	if reeling() and not _was_reeling and _reel_plant != "stop":
		if _reprise.is_empty() or not bool(_reprise.get("cued", false)):
			_reprise = {}
			_next_attack = minf(_next_attack, clock + Rules.REEL_SLAG_PERIOD)
	_step_reprise()
	if clock >= _next_attack and not _in_transition() and not (reeling() and _reel_plant == "stop"):
		var ball: Vector3 = ctx.player.ball_position()
		if reeling():
			var slot := _pick_slag_slot(ball, _slag_turn)
			_commit_slag(slot, false, Rules.REEL_SLAG_LIVE)
			_slag_turn += 1
			_combo_left = -1
			_next_attack = clock + Rules.REEL_SLAG_PERIOD
		else:
			var slot := _slag_turn % 3
			var lead_live := Rules.REEL_SLAG_LIVE if slot == 2 else Rules.SLAG_LIVE
			var slag_warn := _commit_slag(slot, false, lead_live)
			_slag_turn += 1
			var gap := ChallengeDials.period("brindle", Rules.SLAG_GAP, 2)
			if _follow_ups() > 0:
				# The reprise fills the next ring in the rotation the moment this one drains.
				var at := clock + slag_warn + lead_live
				var reprise_slot := _slag_turn % 3
				var reprise_live := Rules.REEL_SLAG_LIVE if reprise_slot == 2 else Rules.SLAG_LIVE
				_reprise = {"at": at, "cue_at": at - FightPhases.CUE_LEAD, "cued": false, "turn": reprise_slot}
				_combo_left = -1
				_next_attack = at + FightPhases.CUED_WARN + reprise_live + gap
			else:
				_next_attack = clock + _paced(slag_warn + lead_live + gap)
	# Drones wait for the ship to park, so a pad is never swept by the hull.
	if parked and clock >= _next_lobber and not _in_transition() and not (reeling() and _reel_plant == "stop"):
		_next_lobber = clock + (Rules.LOBBER_PERIOD * Rules.REEL_PERIOD_MULT if reeling() else Rules.LOBBER_PERIOD)
		_launch_lobber()


# Maps the ball's bowl radius onto the Furnace band that covers it: close vent (< 16 m),
# Ring A (16..25.5 m) or Ring B (>= 25.5 m).
func _ball_slag_slot(ball: Vector3) -> int:
	var r: float = arena.radius_of(ball)
	if r < Arena.RING_A.x:
		return 2
	if r < (Arena.RING_A.y + Arena.RING_B.x) * 0.5:
		return 0
	return 1


# Turn 0 stays Arena.RING_A to match the FX-03 phase preview; later leads and reel rings target
# the band under the ball, stepping to an adjacent free band if that ring is already active.
func _pick_slag_slot(ball: Vector3, turn: int) -> int:
	if turn == 0:
		return 0
	var slot := _ball_slag_slot(ball)
	for offset in 3:
		var cand := (slot + offset) % 3
		var id := _slag_id(cand)
		var busy := false
		for h in hazards:
			if is_instance_valid(h) and not h.is_done() and h.attack_id == id:
				busy = true
				break
		if not busy:
			return cand
	return slot


func _slag_band(turn: int) -> Vector2:
	match turn % 3:
		0:
			return Arena.RING_A
		1:
			return Arena.RING_B
		_:
			return Rules.FURNACE_CLOSE_BAND


func _slag_id(turn: int) -> String:
	match turn % 3:
		0:
			return "slag_ring_a"
		1:
			return "slag_ring_b"
		_:
			return "slag_ring_inner"


# Commits slag ring `turn` (turn 0 ring A, turn 1 ring B, then rotating A, B and the close
# furnace vent band around the hull) and returns its warn. A cued ring draws the short tell its
# ratchet cue paid for.
func _commit_slag(turn: int, cued: bool, live_override := -1.0) -> float:
	var band := _slag_band(turn)
	var id := _slag_id(turn)
	var h = _new_hazard()
	var slag_warn := FightPhases.CUED_WARN if cued else ChallengeDials.tell("brindle", Rules.SLAG_WARN, Hazard.MIN_WARN)
	var live := live_override if live_override > 0.0 else Rules.SLAG_LIVE
	if cued:
		h.warn_floor = FightPhases.CUED_WARN
		h.cued = true
	h.commit_annulus(id, Hazard.Threat.Type.INSTANT, arena.global_position, band, Rules.SLAG_REACH, slag_warn, live)
	h.excluded = func(point: Vector3) -> bool: return arena.is_quenched(point, clock)
	_add_hazard(h)
	_last_commit_at = clock
	ship.cue("slag_warn", turn)
	_publish("boss_attack_telegraphed", [id, h.warn_seconds])
	return h.warn_seconds


func _in_transition() -> bool:
	return _phases != null and _phases.in_transition()


func _follow_ups() -> int:
	return _phases.follow_ups() if _phases != null else 0


func _step_reprise() -> void:
	if _reprise.is_empty():
		return
	# A reel drops an uncued reprise (the reel's own slag cadence takes over, or the stop plant
	# halts attacks); an already-cued reprise always keeps its cue's promise.
	if reeling() and not _reprise["cued"]:
		_reprise = {}
		return
	if not _reprise["cued"] and clock >= _reprise["cue_at"]:
		_reprise["cued"] = true
		var reprise_turn := int(_reprise["turn"])
		_phases.cue("slag_ring_a" if reprise_turn % 3 == 0 else ("slag_ring_b" if reprise_turn % 3 == 1 else "slag_ring_inner"))
		_show_reprise_preview(reprise_turn)
	if clock >= _reprise["at"]:
		var turn: int = _reprise["turn"]
		_reprise = {}
		_clear_reprise_preview()
		_commit_slag(turn, true, Rules.REEL_SLAG_LIVE if reeling() or turn % 3 == 2 else -1.0)
		if reeling() and _reel_plant != "stop":
			_next_attack = minf(_next_attack, clock + Rules.REEL_SLAG_PERIOD)


# Lobber drones drop off the deck onto a pad marked DRONE_WARN ahead, off the hull's side
# away from the ball. They are combat's lobbers with combat's telegraphs; their ground
# is the bowl's, so their shells land on the arena floor, not the parked stage below.
func _launch_lobber() -> void:
	if ctx.calm or ctx.spawner == null or not ctx.spawner.has_method("spawn_enemy"):
		return
	_lobbers = _lobbers.filter(func(l): return is_instance_valid(l) and not (l.has_method("is_dead") and l.is_dead()))
	if _lobbers.size() + _drones.size() >= Rules.LOBBER_CAP:
		return
	var ball_side: float = ship.to_local(ctx.player.ball_position()).x
	var side := -1.0 if ball_side >= 0.0 else 1.0
	var at: Vector3 = ship.to_global(Vector3(side * Rules.DRONE_SIDE, 0.0, 0.0))
	at = Vector3(at.x, arena.ground(at), at.z)
	var marker = Hazard.new()
	marker.ground = arena.ground
	# Bone, the harmless field: the pad hurts nothing, and amber is the player's own ring.
	marker.color = Palette.SAND
	marker.commit_annulus("drone_pad", Hazard.Threat.Type.INSTANT, at, Vector2(0.0, 2.5), 0.0, Rules.DRONE_WARN, Rules.DRONE_WAIT)
	arena.add_child(marker)
	_drones.append({"at": at, "marker": marker})
	ship.cue("drone_deploy", _drones.size() + Engine.get_physics_frames())


func pending_drones() -> Array:
	return _drones.map(func(d): return d["at"])


func _step_drones(delta: float) -> void:
	var kept: Array = []
	var ball: Vector3 = ctx.player.ball_position()
	for d in _drones:
		var marker = d["marker"]
		marker.step(delta)
		var at: Vector3 = d["at"]
		var ready: bool = marker.age >= Rules.DRONE_WARN
		var clear: bool = ball.distance_to(at + Vector3.UP) >= Rules.DRONE_CLEAR
		if ready and clear and state == FIGHT and not _in_transition():
			_drop_drone(at)
		elif marker.age < Rules.DRONE_WARN + Rules.DRONE_WAIT and state == FIGHT:
			kept.append(d)
			continue
		marker.queue_free()
	_drones = kept


func _drop_drone(at: Vector3) -> void:
	var lobber = ctx.spawner.spawn_enemy("lobber", at + Vector3.UP)
	if not lobber is Node3D:
		return
	if "terrain" in lobber:
		lobber.terrain = arena.ground_query()
	_lobbers.append(lobber)


func _step_vents(ball: Vector3) -> void:
	var vent: int = arena.vent_at(ball)
	if vent >= 0:
		arena.quench(vent, clock)


func _slag_hit(h, ball: Vector3) -> void:
	ctx.run.damage(ChallengeDials.damage("brindle", Rules.SLAG_DAMAGE, phase), "brindle_slag")
	# A killing hit ends the run inside damage(), and flow tears the arena down before it returns.
	if not ctx.flow.in_play():
		return
	_grace[h.get_instance_id()] = clock + Rules.SLAG_GRACE
	if ctx.calm:
		return
	var r: float = arena.radius_of(ball)
	var out := Vector3(ball.x - arena.global_position.x, 0.0, ball.z - arena.global_position.z).normalized()
	# The close furnace vent ring wraps the hull, so bouncing outward always clears it instead of
	# knocking the ball back into the hull and re-trapping it on the ring.
	var toward := out if h.attack_id == "slag_ring_inner" or r >= (h.r_in + h.r_out) * 0.5 else -out
	var across: Vector3 = Vector3.UP.cross(out)
	var way := toward
	for candidate in [toward, -toward, across, -across]:
		if _clear_arc(ball, candidate * Rules.SLAG_BOUNCE_OUT + Vector3.UP * Rules.SLAG_BOUNCE_UP):
			way = candidate
			break
	var v: Vector3 = ctx.player.state.velocity
	var up := maxf(0.0, Rules.SLAG_BOUNCE_UP - v.y)
	ctx.player.crowd_control("brindle_slag", (Vector3.UP * up + way * Rules.SLAG_BOUNCE_OUT) / _delta)


# Whether a ball launched from `from` at `launch` flies until it lands without meeting
# anything solid (a ramp's end face, a mast, the hull): a bounce the game chooses must
# not end in a stop the player never chose.
func _clear_arc(from: Vector3, launch: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = arena.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS * 0.95
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1 | 4
	query.exclude = [ctx.player.body().get_rid()]
	var g: float = ctx.tuning.f("gravity")
	var at := from
	for k in range(1, 16):
		var t := k * 0.08
		var next := from + Vector3(launch.x, 0.0, launch.z) * t + Vector3.UP * (launch.y * t - 0.5 * g * t * t)
		var lands: bool = t > 0.3 and next.y <= arena.ground(next) + Tuning.RADIUS
		if lands:
			next.y = arena.ground(next) + Tuning.RADIUS + 0.1
		query.transform = Transform3D(Basis.IDENTITY, at)
		query.motion = next - at
		if space.cast_motion(query)[1] < 1.0:
			return false
		if lands:
			return true
		at = next
	return true


# --- Phase 3: scuttle the flagship ------------------------------------------------------

func _step_charges(delta: float, ball: Vector3) -> void:
	_scuttle_punch = maxf(_scuttle_punch, ctx.flow.punch_now())
	match _charge.get("state", CHARGE_REST):
		CHARGE_REST, CHARGE_RECOVER, CHARGE_STUN, CHARGE_HOOK:
			if _charge["state"] == CHARGE_HOOK:
				# The hook turn starts on its cue: the hull digs in and swings its bow round after
				# the ball, so the short tell that follows has only the last of the turn left.
				if _reel_plant != "no_brace" and not ship.bracing():
					ship.set_hook_brace(true, int(_charge.get("token", 0)))
				_turn_ship(_aim_at(ball), Rules.CHARGE_TURN_RATE, delta)
			if _charge["state"] == CHARGE_STUN:
				_last_commit_at = clock
			_charge["timer"] -= delta
			if _charge["state"] == CHARGE_REST and reeling() and _reel_plant != "stop" and not _in_transition() \
					and _last_commit_at >= 0.0 and clock + float(_charge["timer"]) - _last_commit_at > Rules.REEL_MAX_GAP:
				_charge["timer"] = maxf(0.0, _last_commit_at + Rules.REEL_MAX_GAP - clock)
			if _charge["timer"] <= 0.0:
				if _charge["state"] == CHARGE_REST:
					if _in_transition() or (reeling() and _reel_plant == "stop"):
						return
					_commit_charge()
				elif _charge["state"] == CHARGE_HOOK:
					_commit_charge(true)
				else:
					_charge = {"state": CHARGE_REST, "timer": _rest_time()}
		CHARGE_BRACE:
			var h = _charge.get("hazard")
			if h == null or not is_instance_valid(h) or h.is_done():
				_charge = {"state": CHARGE_REST, "timer": _rest_time()}
				return
			_brace_turn(delta)
			if h.is_live():
				_charge["state"] = CHARGE_RUN
		CHARGE_RUN:
			_run_charge(delta, ball)
		_:
			push_error("brindle charge in unknown state %s" % _charge.get("state"))
			_charge = {"state": CHARGE_REST, "timer": _rest_time()}


# Where a charge committed now would point: at the ball, or straight on when the ball is
# too close to the ship's centre to give a bearing.
func _aim_at(ball: Vector3) -> Vector3:
	var to_ball := Vector3(ball.x - ship.global_position.x, 0.0, ball.z - ship.global_position.z)
	return to_ball.normalized() if to_ball.length() > 2.0 else ship.heading


# Swings the bow toward `heading` in place, by at most `rate` radians a second. The hull
# never takes a heading in one tick: it is a 14 m kinematic box, and a ball leaning on its
# flank takes a one-tick turn as a 300 to 500 m/s kick (or, amidships, is swallowed by the
# hull and held inside it).
func _turn_ship(heading: Vector3, rate: float, delta: float) -> void:
	var owed := Vector2(ship.heading.x, ship.heading.z).angle_to(Vector2(heading.x, heading.z))
	var step := clampf(owed, -rate * delta, rate * delta)
	var arrives := absf(owed - step) < Rules.CHARGE_TURN_SNAP
	ship.move_to(ship.global_position, heading if arrives else (ship.heading as Vector3).rotated(Vector3.UP, -step))


# The wind-up: the hull turns to its committed lane inside the tell, at CHARGE_TURN_RATE or
# as much faster as it takes to be square in the lane CHARGE_TURN_SETTLE before the lane can
# hurt. The lane itself was laid at the commit and never moves.
func _brace_turn(delta: float) -> void:
	var h = _charge["hazard"]
	var heading: Vector3 = _charge["heading"]
	var owed := absf(Vector2(ship.heading.x, ship.heading.z).angle_to(Vector2(heading.x, heading.z)))
	if owed <= 0.0:
		return
	var time_left := maxf(delta, h.warn_seconds - h.age - Rules.CHARGE_TURN_SETTLE)
	_turn_ship(heading, maxf(Rules.CHARGE_TURN_RATE, owed / time_left), delta)


# A cued charge is the Scuttle's hook turn: its ratchet cue sounded CUE_LEAD ago, so it
# draws the short tell, and it never leads a combo or a second hook turn.
#
# The lane leads a ball that holds a line (PackPressure.lead_aim): it is laid where the ball's roll
# carries it by the time the hull's nose gets there, so a straight line is met and a turn inside the
# tell escapes. A turning, slow or stopped ball is aimed at where it is, and so is every ball on the
# hook turn's short cued tell. The aim reads the ball's position and roll from the player itself.
func _commit_charge(cued := false) -> void:
	if not cued:
		_combo_left = ChallengeDials.combo_step("brindle", _combo_left)
	var from: Vector3 = ship.global_position
	var half := Requisition.HULL.z * 0.5
	var warn := FightPhases.CUED_WARN if cued else ChallengeDials.tell("brindle", Rules.CHARGE_WARN, Hazard.MIN_WARN)
	var ball: Vector3 = ctx.player.ball_position()
	var to_ball := Vector3(ball.x - from.x, 0.0, ball.z - from.z)
	# Whether it rams the bank is judged from where the ball is, as before the lead: a led point far out
	# would make almost every outward line a ram and hand the ball a free stun. A ram is aimed at the ball
	# and runs to the bank; any other charge keeps its led aim and ends short of the bank. So the flag, the
	# lane, the stun and the wind-up sound all agree.
	var ball_heading := _aim_at(ball)
	var into_wall := to_ball.length() + Rules.CHARGE_OVERSHOOT >= _travel_to_rim(from, ball_heading)
	var aim := ball
	if not into_wall:
		# The nose hurts from half a hull and its reach ahead of the centre, so it meets the ball that much sooner.
		aim = PackPressure.lead_aim(ctx.player, from, warn, Rules.CHARGE_SPEED, half + CHARGE_REACH, half + Tuning.RADIUS)
	var to_aim := Vector3(aim.x - from.x, 0.0, aim.z - from.z)
	var heading := ball_heading if into_wall else _aim_at(aim)
	var to_wall := _travel_to_rim(from, heading)
	var wanted := to_aim.length() + Rules.CHARGE_OVERSHOOT
	var length := to_wall if into_wall else maxf(0.0, minf(wanted, to_wall - CHARGE_RIM_CLEAR))
	if not into_wall and length < CHARGE_MIN_LANE:
		heading = ball_heading
		length = to_ball.length() + Rules.CHARGE_OVERSHOOT
	var h = _new_hazard()
	if cued:
		h.warn_floor = FightPhases.CUED_WARN
		h.cued = true
	h.commit_lane("charge", Hazard.Threat.Type.LANE, from, heading, half, length + half, Requisition.HULL.x * 0.5 + 1.0,
		Requisition.HULL.y + 0.5, warn, length / Rules.CHARGE_SPEED + 0.2)
	# Only the hull's nose hurts once the lane is live, and it starts at the ship.
	h.lane_front = half + CHARGE_REACH
	_add_hazard(h)
	_last_commit_at = clock
	ship.set_hook_brace(false)
	# The hull keeps its heading at the commit: _brace_turn owns the turn onto this one.
	ship.cue("charge_warn", h.get_instance_id())
	_charge = {"state": CHARGE_BRACE, "hazard": h, "from": from, "heading": heading, "length": length,
		"into_wall": into_wall, "travelled": 0.0, "cued": cued}
	_publish("boss_attack_telegraphed", ["charge_wall" if into_wall else "charge", h.warn_seconds])


# How far the ship's centre can travel along `heading` before its nose buries in the
# bank at CHARGE_STOP_R, which keeps every corner of the hull clear of the rim wall.
func _travel_to_rim(from: Vector3, heading: Vector3) -> float:
	var p := Vector2(from.x - arena.global_position.x, from.z - arena.global_position.z)
	var d := Vector2(heading.x, heading.z)
	var b := p.dot(d)
	var c := p.length_squared() - Rules.CHARGE_STOP_R * Rules.CHARGE_STOP_R
	return maxf(0.0, -b + sqrt(maxf(0.0, b * b - c)))


func _run_charge(delta: float, ball: Vector3) -> void:
	var h = _charge["hazard"]
	var half := Requisition.HULL.z * 0.5
	var front_before: float = _charge["travelled"] + half
	_charge["travelled"] = minf(_charge["length"], _charge["travelled"] + Rules.CHARGE_SPEED * delta)
	var at: Vector3 = _charge["from"] + _charge["heading"] * _charge["travelled"]
	ship.move_to(Vector3(at.x, arena.ground(at), at.z), _charge["heading"])
	var front: float = _charge["travelled"] + half
	h.lane_front = front + CHARGE_REACH
	if h.contains(ball) and clock >= _grace.get(h.get_instance_id(), -1.0) \
			and (not h.cued or h.age >= h.warn_seconds + 0.025):
		var along: float = h.lane_along(ball)
		if along >= front_before - 1.0 and along <= front + CHARGE_REACH:
			_charge_hit(h, ball)
			if not ctx.flow.in_play():
				return
	var will_hook: bool = not _charge["into_wall"] and not _charge.get("cued", false) \
		and _follow_ups() > 0 and not (reeling() and _reel_plant == "stop")
	var rem_s: float = maxf(0.0, (float(_charge["length"]) - float(_charge["travelled"])) / Rules.CHARGE_SPEED)
	if will_hook and rem_s <= Rules.HOOK_BRACE_LEAD and _reel_plant != "no_brace":
		ship.set_hook_brace(true, h.get_instance_id())
	if _charge["travelled"] >= _charge["length"]:
		h.finish()
		if _charge["into_wall"]:
			_stun(ChallengeDials.punish("brindle", Rules.WALL_STUN))
			_discover(CodexEntries.WALL_BAIT, ship.global_position)
		elif will_hook:
			_note_missed_charge()
			# The hook turn: the cue sounds as the hull digs in, the lane draws CUE_LEAD later.
			_phases.cue("charge")
			if _reel_plant != "no_brace":
				ship.set_hook_brace(true, h.get_instance_id())
			_charge = {"state": CHARGE_HOOK, "timer": FightPhases.CUE_LEAD, "token": h.get_instance_id()}
		else:
			ship.set_hook_brace(false)
			_note_missed_charge()
			_charge = {"state": CHARGE_RECOVER, "timer": Rules.CHARGE_RECOVER}


# A charge hit shoves the ball sideways out of the lane and up, never along it, so the
# hull can never carry the ball into the wall.
func _charge_hit(h, ball: Vector3) -> void:
	ctx.run.damage(ChallengeDials.damage("brindle", Rules.CHARGE_DAMAGE, phase), "brindle_charge")
	if not ctx.flow.in_play():
		return
	_grace[h.get_instance_id()] = clock + Rules.CHARGE_GRACE
	if ctx.calm:
		return
	var lateral: float = h.lane_lateral(ball)
	var away: Vector3 = h.side() * (1.0 if lateral >= 0.0 else -1.0)
	var v: Vector3 = ctx.player.state.velocity
	var along: float = v.dot(h.heading)
	var up := maxf(0.0, Rules.CHARGE_SHOVE_UP - v.y)
	ctx.player.crowd_control("brindle_charge", (away * Rules.CHARGE_SHOVE_SIDE + Vector3.UP * up - h.heading * minf(0.0, along)) / _delta)
	ship.hull.add_collision_exception_with(ctx.player.body())
	ship.follow_shoved_rider(ctx.player.body())
	_ghost_until = clock + Rules.CHARGE_GRACE


# The hull takes the ball back only once the grace is over and the ball is clear of it,
# so the exception never ends with the ball inside the hull.
func _step_ghost() -> void:
	if _ghost_until < 0.0 or clock < _ghost_until:
		return
	var local: Vector3 = ship.hull.to_local(ctx.player.ball_position())
	var half := Requisition.HULL * 0.5 + Vector3.ONE * (Tuning.RADIUS + 0.3)
	if absf(local.x) < half.x and absf(local.y) < half.y and absf(local.z) < half.z:
		return
	ship.hull.remove_collision_exception_with(ctx.player.body())
	ship.follow_shoved_rider(null)
	_ghost_until = -1.0


func _stun(seconds: float) -> void:
	_combo_left = -1  # a punish window ends any combo
	if is_instance_valid(ship):
		ship.set_hook_brace(false)
	if _charge.has("hazard") and is_instance_valid(_charge["hazard"]):
		_charge["hazard"].finish()
	_charge = {"state": CHARGE_STUN, "timer": seconds}
	_last_commit_at = clock
	stuns += 1
	ship.cue("wall_stun", stuns)


func stunned() -> bool:
	return state == FIGHT and phase == 3 and _charge.get("state", "") == CHARGE_STUN


# --- The Scuttle's hint ---------------------------------------------------------------

# A charge ran out with no stun. It counts as a try that came up short only for a ball whose
# punch has stayed under the hull's plating all phase: that build cannot hit its way in.
func _note_missed_charge() -> void:
	if _scuttle_punch < Rules.HULL_PLATING:
		_short_tries += 1


# A hit on the closed hull that its plating turned. Like a missed charge, it is a short try
# only while the ball's best punch of the phase is under the plating: a heavy build's stray
# light hit is not one.
func _note_glance(target, part: String, result: Dictionary) -> void:
	if state != FIGHT or phase != 3 or target.role != "hull" or part.begins_with("cap_") or stunned() or _posture.staggered:
		return
	var punch := float(result.get("punch", 0.0))
	_scuttle_punch = maxf(_scuttle_punch, punch)
	if punch < float(result.get("plating", Rules.HULL_PLATING)) and _scuttle_punch < Rules.HULL_PLATING:
		_short_tries += 1


# The hint the fight asks the HUD for right now, "" for none; taking it starts its gap (the
# HUD polls this when its toast row is free and shows the UI row there). In the Scuttle a
# build whose punch is short of the plating has one way in: a stun, and for a light build
# that is a charge baited into the rim wall. The hint is owed once a try has come up short
# (a hit the plating turned, or a charge that ran out), repeats every SCUTTLE_HINT_GAP
# seconds, and stops for the fight at the first stun, which is the lesson learned, or once
# the ball's punch has met the plating.
func take_hint() -> String:
	if state != FIGHT or phase != 3 or stuns > 0 or _short_tries <= 0 or clock < _hint_next:
		return ""
	if _scuttle_punch >= Rules.HULL_PLATING:
		return ""
	if _in_transition() or _held() or _posture.staggered:
		return ""
	_hint_next = clock + Rules.SCUTTLE_HINT_GAP
	return Rules.SCUTTLE_HINT


func charging() -> bool:
	return state == FIGHT and phase == 3 and _charge.get("state", "") == CHARGE_RUN


# --- The eject and the chase -------------------------------------------------------

func _begin_eject() -> void:
	_cancel_hazards()
	_spill_break()
	state = EJECT
	phase = CHASE_PHASE
	phase_clock = 0.0
	ship.hull.set_solid(true, true)
	ship.cockpit_open(true)
	ship.show_cranes(false)
	ship.open_caps(false)
	ship.cue("eject")
	scooter = Target.new()
	scooter.setup(self, "scooter", "scooter", Vector3(2.0, 1.2, 2.8), Vector2(1.6, 1.0))
	arena.add_child(scooter)
	scooter.set_solid(false)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 1.0, 2.8)
	body.mesh = box
	body.material_override = Palette.solid(Palette.BRASS, 0.8)
	scooter.add_child(body)
	_scooter_anim = Requisition.dress_scooter(scooter)
	if _scooter_anim != null:
		BossModel.hide_primitive(body)
		BossModel.play(_scooter_anim, "eject")
	var ball: Vector3 = ctx.player.ball_position()
	var land: float = arena.angle_of(ball) + PI
	var from: Vector3 = ship.to_global(Vector3(0.0, Requisition.DECK + 1.5, 4.8))
	scooter.global_position = from
	_eject = {"t": 0.0, "from": from, "angle": land, "landed": false, "dir": 1.0, "slow_until": -1.0}
	_commit_eject_mark(land)
	_publish("boss_phase_changed", [CHASE_PHASE, CHASE_NAME])
	_publish("boss_attack_telegraphed", ["eject", Rules.EJECT_FLIGHT])


# The scooter drives off the landing at SCOOTER_SPEED and leaves the catch circle after about 0.32 s,
# so the mark stays live no longer than that.
const EJECT_MARK_LIVE := 0.3


# The scooter's landing spot, marked on the ground from the cue until it lands. The eject
# hurts nothing: what the mark covers is the catch, the SCOOTER_TOUCH circle the ball must
# be inside, so it draws in the harmless bone style (like the phase previews) and goes live
# on the step the scooter lands. It is stepped here, not with the slag hazards, because a
# live ring in that list hits the ball.
func _commit_eject_mark(angle: float) -> void:
	var to: Vector3 = arena.point_at(angle, Rules.SCOOTER_RING, 0.7)
	var h = Hazard.new()
	h.ground = arena.ground
	h.color = Palette.SAND
	h.commit_annulus("eject_landing", Hazard.Threat.Type.INSTANT, Vector3(to.x, arena.ground(to), to.z),
		Vector2(0.0, Rules.SCOOTER_TOUCH), Rules.SCOOTER_TOUCH, Rules.EJECT_FLIGHT, EJECT_MARK_LIVE)
	arena.add_child(h)
	_eject["mark"] = h


func eject_mark() -> Node3D:
	var h = _eject.get("mark")
	return h if is_instance_valid(h) else null


func _step_eject_mark(delta: float) -> void:
	var h = eject_mark()
	if h == null:
		return
	h.step(delta)
	if h.is_done():
		h.queue_free()
		_eject.erase("mark")


func _step_scooter(delta: float) -> void:
	_step_eject_mark(delta)
	if not is_instance_valid(scooter):
		return
	if not _eject["landed"]:
		_eject["t"] += delta
		var f := clampf(_eject["t"] / Rules.EJECT_FLIGHT, 0.0, 1.0)
		var to: Vector3 = arena.point_at(_eject["angle"], Rules.SCOOTER_RING, 0.7)
		var at: Vector3 = (_eject["from"] as Vector3).lerp(to, f) + Vector3.UP * 14.0 * 4.0 * f * (1.0 - f)
		scooter.global_position = at
		if f >= 1.0:
			_eject["landed"] = true
			BossModel.play(_scooter_anim, "chase")
			scooter.set_solid(true)
			var ball_angle: float = arena.angle_of(ctx.player.ball_position())
			_eject["dir"] = -signf(angle_difference(_eject["angle"], ball_angle))
			if _eject["dir"] == 0.0:
				_eject["dir"] = 1.0
		return
	var speed := scooter_speed()
	_eject["angle"] += _eject["dir"] * speed / Rules.SCOOTER_RING * delta
	var at: Vector3 = arena.point_at(_eject["angle"], Rules.SCOOTER_RING, 0.7)
	var ahead: Vector3 = Arena.tangent(_eject["angle"]) * _eject["dir"]
	scooter.global_transform = Transform3D(Basis.looking_at(ahead, Vector3.UP), at)


func scooter_speed() -> float:
	var speed := Rules.SCOOTER_SPEED
	if clock < _eject.get("slow_until", -1.0):
		speed = maxf(Rules.SCOOTER_MIN_SPEED, speed * Rules.SCOOTER_SLOW)
	return speed


func scooter_landed() -> bool:
	return state == EJECT and _eject.get("landed", false)


# The catch is a contact: a ram, a stomp or a slam with the ball on the landed scooter
# wins. Anything else, a shot or a strike from afar that borrows a contact kind, slows
# him for a moment, which is how a gunner sets up the catch.
func _on_enemy_struck(enemy: Node3D, kind: String, _force: float) -> void:
	if enemy == null or enemy != scooter or not scooter_landed():
		return
	if kind in Rules.CONTACT_KINDS and ctx.player.ball_position().distance_to(scooter.global_position) <= Rules.SCOOTER_TOUCH:
		_defeat("stomp" if kind == "stomp" or _from_above(scooter) else kind, scooter.global_position, scooter.last_damage_source)
	else:
		_eject["slow_until"] = clock + Rules.SCOOTER_SLOW_SECONDS


# The one way Brindle dies: the catch takes the last chunk. `source` is the killing
# piece's damage tag ("spark" for a wear-trail patch), so run_state can tell build that
# the kill procs nothing, as combat's own kills do.
func _defeat(kind: String, at: Vector3, source := "") -> void:
	if state == DEFEATED:
		return
	state = DEFEATED
	_posture.chunks = 0
	hp = 0.0
	_cancel_hazards()
	if is_instance_valid(scooter):
		scooter.set_solid(false)
	_publish("boss_weak_point_hit", ["scooter"])
	if kind == "stomp":
		_discover(CodexEntries.SCOOTER_STOMP, at)
	ctx.run.record_kill("brindle", at, 0, source)
	ctx.run.add_part(Rules.CREST_PART, "boss")
	_sync_crest()
	ctx.flow.boss_active = false
	# A freed ship ends its own lift in the camera, and a freed object cannot be passed as a Node3D.
	if is_instance_valid(ship):
		ctx.camera.clear_contact_subject(ship)
		# No step runs after the catch, so a shove still in its grace would leave the hull cut away over the ball.
		ship.follow_shoved_rider(null)
	# The scooter stays in sight through boss_defeated, so the fall plays where he was caught
	# (machine_fx reads a visible scooter before the ship); it is hidden once the event is out.
	_publish("boss_defeated")
	if is_instance_valid(scooter):
		scooter.visible = false


# The admiral's crest rides on the ball for as long as the run holds the part.
func _sync_crest() -> void:
	var wanted: bool = ctx.run.parts.has(Rules.CREST_PART)
	if wanted and not is_instance_valid(_crest):
		_crest = Node3D.new()
		_crest.name = "AdmiralsCrest"
		var badge := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.5
		disc.bottom_radius = 0.5
		disc.height = 0.14
		disc.radial_segments = 5
		badge.mesh = disc
		badge.material_override = Palette.solid(Palette.BRASS, 1.2)
		badge.rotation.x = PI * 0.5
		_crest.add_child(badge)
		_crest.position = Vector3(0.0, 0.0, Tuning.RADIUS + 0.02)
		ctx.player.roll_node().add_child(_crest)
	elif not wanted and is_instance_valid(_crest):
		_crest.queue_free()
		_crest = null
	if not wanted and state == DEFEATED:
		state = IDLE


func crest() -> Node3D:
	return _crest if is_instance_valid(_crest) else null


# --- Hazards --------------------------------------------------------------------------

func _new_hazard():
	var h = Hazard.new()
	h.ground = arena.ground
	var row := _row("boss_attack_telegraphed")
	if row.has("color"):
		h.color = row["color"]
	return h


func _add_hazard(h) -> void:
	arena.add_child(h)
	hazards.append(h)


# Scrap a magnet still holds is dripped out along its trail at once: only phase 1 steps
# the cranes, so a hold left at the phase end would never be paid back.
func _cancel_hazards() -> void:
	_clear_preview()
	_clear_reprise_preview()
	if is_instance_valid(ship):
		ship.set_hook_brace(false)
	var mark = eject_mark()
	if mark != null:
		mark.queue_free()
		_eject.erase("mark")
	for h in hazards:
		if is_instance_valid(h):
			h.queue_free()
	hazards.clear()
	_reprise = {}
	# A drone pad is phase 2's attack: one still marked at the phase turn would drop its lobber
	# into the next phase once the transition beat ends. Lobbers already down stay.
	for d in _drones:
		if is_instance_valid(d["marker"]):
			d["marker"].queue_free()
	_drones.clear()
	for c in _cranes:
		if c.has("hazard"):
			c.erase("hazard")
		while c.get("held", 0) > 0:
			_drip(c)


func active_hazards() -> Array:
	return hazards.filter(func(h): return is_instance_valid(h) and not h.is_done())


# Ages every hazard once per tick, runs the slag rings' hits and frees what is done.
func _step_hazards(delta: float, ball: Vector3) -> void:
	var kept: Array = []
	for h in hazards:
		if not is_instance_valid(h):
			continue
		h.step(delta)
		if h.shape == Hazard.Shape.ANNULUS and h.is_live() \
				and (not h.cued or h.age >= h.warn_seconds + 0.025):
			if h.contains(ball) and clock >= _grace.get(h.get_instance_id(), -1.0):
				_slag_hit(h, ball)
				# A killing ring ended the run and exit_arena cleared the list: keep it cleared.
				if not ctx.flow.in_play():
					return
			elif _on_crust(h, ball):
				_discover(CodexEntries.QUENCH_RIDE, ball)
		if h.is_done() and h.age >= h.warn_seconds + h.live_seconds + 0.5:
			h.queue_free()
			continue
		kept.append(h)
	hazards = kept


func _on_crust(h, ball: Vector3) -> bool:
	var r: float = arena.radius_of(ball)
	return r >= h.r_in and r <= h.r_out and ball.y - arena.ground(ball) <= h.reach and arena.is_quenched(ball, clock)


# --- The rescue ------------------------------------------------------------------------

# Below this the ball has fallen out of the bowl. Flow asks it in the boss state.
func floor_y() -> float:
	return arena.global_position.y - RESCUE_DEPTH if is_instance_valid(arena) else -INF


# A safe point on the banked ring at the bearing the ball left from: outside both slag
# channels by construction, and turned aside until the Requisition is clear of it.
func rescue_point(near = null) -> Vector3:
	var from: Vector3 = near if near is Vector3 else ctx.player.ball_position()
	if not is_instance_valid(arena):
		return from
	var angle: float = arena.angle_of(from)
	for k in 12:
		var turn := 0.35 * ceilf(k / 2.0) * (1.0 if k % 2 == 0 else -1.0)
		var at: Vector3 = arena.point_at(angle + turn, Arena.RESCUE_R, 2.0)
		if not is_instance_valid(ship) or Vector2(at.x - ship.global_position.x, at.z - ship.global_position.z).length() > RESCUE_CLEAR:
			return at
	return arena.point_at(angle, Arena.RESCUE_R, 2.0)


# Flow rescues a fall below floor_y(). This catches the one it cannot see in time: a
# ball flying out over the rim, which would take over a second to fall that far. It
# goes back on the ring riding it the way it was going round, with its horizontal speed
# kept.
func _rescue(ball: Vector3) -> void:
	if arena.contains(ball):
		return
	var v: Vector3 = ctx.player.state.velocity
	var speed := Vector2(v.x, v.z).length()
	var turning := signf(v.dot(Arena.tangent(arena.angle_of(ball))))
	var at := rescue_point(ball)
	ctx.player.reset_to(at, Arena.tangent(arena.angle_of(at)) * speed * (turning if turning != 0.0 else 1.0))


# --- The enemy protocol, answered for every piece (boss_target.gd forwards here) -------

func target_live(target) -> bool:
	match target.role:
		"hull":
			return state == FIGHT
		"magnet":
			return state == FIGHT and phase == 1
		"cap":
			return state == FIGHT and phase == 2
		"scooter":
			return scooter_landed()
	return false


func plating_for(target, kind: String, part: String) -> float:
	match target.role:
		"hull":
			if part.begins_with("cap_"):
				return plating_for(_cap(part), kind, "")
			if stunned():
				return Rules.OPEN_PLATING
			if charging():
				return Rules.CLASH_PUNCH
			return Rules.HULL_PLATING
		"magnet":
			return Rules.HULL_PLATING if kind in Rules.CONTACT_KINDS else 0.0
		"cap":
			if kind == "":
				return 0.0
			return Rules.OPEN_PLATING if _landing(target, kind) else Rules.HULL_PLATING
	return 0.0


func hit_mult(target, kind: String, part: String) -> float:
	if part.begins_with("cap_"):
		return hit_mult(_cap(part), kind, "")
	if target.role == "cap" and _landing(target, kind):
		return Rules.CAP_MULT
	return 1.0


# A stomp or slam with the ball on the piece, or a ram the ball made coming down on top
# of it. The ball's position settles it, so a strike that only borrows the "slam" kind
# (build's synergies) cannot open a cap from the floor.
func _landing(target, kind: String) -> bool:
	if kind in Rules.CAP_KINDS:
		return _over(target) and ctx.player.ball_position().y >= target.global_position.y - 0.5
	return kind == "ram" and _from_above(target)


func _from_above(target) -> bool:
	return ctx.player.ball_position().y - target.global_position.y >= Rules.ABOVE and _over(target)


# A stomp or slam on the deck lands on the vent cap it is over, as the Warden's caps do.
func contact_part(target, _ball: Vector3, kind: String) -> String:
	if target.role != "hull" or phase != 2:
		return ""
	for cap in ship.caps:
		if _landing(cap, kind) and _over(cap):
			return cap.point_id
	return ""


func _over(target) -> bool:
	var ball: Vector3 = ctx.player.ball_position()
	var at: Vector3 = target.global_position
	return Vector2(ball.x - at.x, ball.z - at.z).length() <= Rules.CAP_REACH


func _cap(part: String):
	for cap in ship.caps:
		if cap.point_id == part:
			return cap
	return ship.caps[0]


# The clash: a ram into the charging bow that meets plating 150 stops the charge. Then
# the hit moves the posture bar: a hull hit by the rule judge_hit() answered (or, from
# a striker that skipped it, judged here), a weak point's hit as pressure on the bar.
func on_struck(target, kind: String, part: String, result: Dictionary) -> void:
	if target.role == "hull" and kind == "ram" and charging() \
			and float(result.get("punch", 0.0)) >= float(result.get("plating", INF)):
		clashes += 1
		_stun(ChallengeDials.punish("brindle", Rules.CLASH_STUN))
	if state != FIGHT:
		return
	if target.role == "hull" and kind in Rules.CONTACT_KINDS:
		_reel_hit()
	_note_glance(target, part, result)
	if target.role == "hull" and result.has("gain"):
		_apply_posture(result)
	elif target.role == "hull" and not part.begins_with("cap_"):
		_apply_posture(judge_hit(target, kind, float(result.get("punch", 0.0)), false, 0))
	elif target.role in ["magnet", "cap"] or part.begins_with("cap_"):
		_pressure(kind, result)


# Health falls only by the chunks the posture rule shattered; `amount` moves nothing.
# hp is read back from the chunk count, so the delivered-damage ledger sees one per chunk.
func take_damage(target, _amount: float, full: bool, part: String) -> float:
	if state != FIGHT or not target_live(target):
		return 0.0
	var before := hp
	hp = float(_posture.chunks)
	if full:
		match target.role:
			"magnet":
				_publish("boss_weak_point_hit", [target.point_id])
				var i: int = ship.magnets.find(target)
				if i >= 0 and _cranes[i].get("held", 0) > 0:
					_drop_held(i)
			"cap":
				_publish("boss_weak_point_hit", [target.point_id])
			"hull":
				if part.begins_with("cap_"):
					_publish("boss_weak_point_hit", [part])
				elif hp < before:
					_publish("boss_weak_point_hit", ["cockpit"])
	_maybe_turn_phase()
	return before - hp


# --- The posture fight on the hull (boss_posture.gd; boss_target.gd forwards here) ----

# Only the hull is fought on posture. The magnets, caps and scooter keep combat's
# plating rule, which their crane, furnace and chase mechanics read.
func fight(target) -> String:
	return "posture" if target.role == "hull" else "plating"


func posture() -> float:
	return _posture.posture


func staggered() -> bool:
	return state == FIGHT and _posture.staggered


func stagger_left() -> float:
	return _posture.stagger_left if staggered() else 0.0


func chunks_left() -> int:
	return _posture.chunks


func glances() -> int:
	return _posture.glances


func chunk_cracked() -> bool:
	return _posture.cracked


# What the rule says a hit on the hull does, or {} for any other piece so combat's own
# rule runs. Out of a stagger a slam on a vent cap meets the cap's plating; in one any
# contact meets the open cockpit. A held phase answers with the hit and what it banks.
func judge_hit(target, kind: String, punch: float, smash: bool, tier: int) -> Dictionary:
	if target.role != "hull" or state != FIGHT:
		return {}
	var part := ""
	if not _posture.staggered and kind in Rules.CONTACT_KINDS:
		part = contact_part(target, ctx.player.ball_position(), kind)
	var result := _posture.judge({"kind": kind, "punch": punch, "plating": plating_for(target, kind, part), "smash": smash,
			"tier": tier, "charging": charging(), "frame": Engine.get_physics_frames(), "hp": hp, "max_hp": max_hp})
	if part != "":
		result["part"] = part
	if _held() or _in_transition():
		_bank(result)
	return result


# A weak point's full hit adds to the hull's bar as the rule would weigh it on a body of
# that plating. It never touches the open cockpit: only a contact on the hull does.
func _pressure(kind: String, result: Dictionary) -> void:
	if _posture.staggered or (_held() and not banking()) or _in_transition() or not bool(result.get("full", false)):
		return
	var judged := _posture.judge({"kind": kind, "punch": float(result.get("punch", 0.0)),
			"plating": float(result.get("plating", 0.0)), "charging": charging(), "frame": Engine.get_physics_frames()})
	if banking():
		_bank(judged)
	_apply_posture(judged)


func _apply_posture(result: Dictionary) -> void:
	var before := _posture_signature()
	var was_staggered: bool = _posture.staggered
	# A hit is judged before its strike is published and applied after: the bank's stop is
	# measured again here, against the bar as it stands now.
	if _held() or _in_transition():
		result = result.duplicate()
		_bank(result)
	_posture.apply(result, Engine.get_physics_frames())
	_sync_stagger(was_staggered)
	_publish_posture(before)


func _step_posture(delta: float) -> void:
	var before := _posture_signature()
	var was_staggered: bool = _posture.staggered
	# A banked bar is kept: it does not drain through the hold or the beat after it.
	if (_held() or _in_transition()) and not _posture.staggered:
		_posture.idle = 0.0
	_posture.step(delta)
	_sync_stagger(was_staggered)
	_publish_posture(before)


func _posture_signature() -> Array:
	return [floori(_posture.posture), _posture.staggered, _posture.chunks, _posture.cracked]


# The hull's bar moved: the same bus signal a Warden's does, so the stagger chord plays and
# the plate and ring redraw. The run log ignores a body that carries a boss.
func _publish_posture(before: Array) -> void:
	if before != _posture_signature() and is_instance_valid(ship) and is_instance_valid(ship.hull):
		ctx.events.posture_changed.emit(ship.hull, _posture.posture, _posture.staggered)


# A stagger opens the cockpit for its window; from Scuttle on the cockpit stays open.
func _sync_stagger(was_staggered: bool) -> void:
	if _posture.staggered == was_staggered or not is_instance_valid(ship):
		return
	ship.cockpit_open(_posture.staggered or phase >= 3)


# --- Readout, publishing, codex ---------------------------------------------------------

func hull_plating_now() -> float:
	if not active() or not is_instance_valid(ship):
		return Rules.HULL_PLATING
	var plating := plating_for(ship.hull, "", "")
	if ctx.spawner != null and ctx.spawner.has_method("shred_of"):
		plating = maxf(0.0, plating - ctx.spawner.shred_of(ship.hull))
	return plating


# The name plate's words. The objective line carries the numbers, so the plate names
# who and the plating; its colour says whether your punch beats that plating.
func readout_text() -> String:
	if state == EJECT:
		return "BRINDLE · on the run"
	if charging():
		return "BRINDLE · bow plating %d" % int(hull_plating_now())
	if stunned():
		return "BRINDLE · plating 0 · stunned"
	return "BRINDLE · plating %d" % int(hull_plating_now())


func _update_readout() -> void:
	if not is_instance_valid(ship):
		return
	var beats: bool = state == EJECT or live_punch() >= live_plating()
	var anchor: Node3D = scooter if state == EJECT and is_instance_valid(scooter) else null
	ship.set_readout(readout_text(), Palette.AMBER if beats else PLATE_SHORT, anchor, 2.5 if anchor != null else Requisition.PLATE_LIFT)


# --- Live state for the HUD (flow's objective and gap lines read these) --------------

# The objective plate's reading of the fight (ui/hud.gd, core/objectives.gd): the phase whose
# verb the plate names (CHASE_PHASE is the scooter) and whether the cockpit is the place to hit
# now: a stagger in any phase (the weak points pay nothing through it, _pressure), or a stun in
# Scuttle. A stagger does not hold a Scuttle charge back, so while one is coming down its lane the
# cockpit does not count as open: the lane is what the player must read.
func plate_reading() -> Dictionary:
	return {"phase": phase if active() else 0, "open": (stunned() or staggered()) and not charge_coming()}


# A Scuttle charge is committed: its lane is drawn (the tell) or he is running it.
func charge_coming() -> bool:
	return state == FIGHT and phase == 3 and _charge.get("state", "") in [CHARGE_BRACE, CHARGE_RUN]


# Where the fight sends the player now, for the HUD to mark (ui/edge_markers.gd), each {at, what}
# with what naming the thing (objectives.gd TAGS): the crane magnets in the Requisition, the vent
# caps in the Furnace, the cockpit while it is open, the scooter in the chase. Baiting a charge
# names no one place, so it marks none.
func plate_targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if state == EJECT and is_instance_valid(scooter):
		out.append({"at": scooter.global_position, "what": "scooter"})
	elif state == FIGHT:
		if plate_reading()["open"]:
			out.append({"at": ship.cockpit_point(), "what": "cockpit"})
		elif phase == 1:
			for magnet in ship.magnets:
				out.append({"at": magnet.global_position, "what": "magnet"})
		elif phase == 2:
			for cap in ship.caps:
				out.append({"at": cap.global_position, "what": "cap"})
	return out


# What the player should do right now, in the objective line's voice. Flow shows it as
# the whole objective line, so fight states end with punch against the live plating.
func objective_text() -> String:
	match state:
		EJECT:
			return "Catch the Admiral's scooter: ram it or land on it."
		DEFEATED:
			return "Brindle is routed."
		FIGHT:
			var gap := " Punch %d / hull plating %d." % [int(live_punch()), int(live_plating())]
			match phase:
				1:
					return "Shoot the crane magnets holding your scrap." + gap
				2:
					return "Slam the vent caps from a mast or ramp." + gap
				3:
					if stunned():
						return "He is stunned with his cockpit open: hit him now." + gap
					if charging():
						return "Out-clash the charge with a ram, or get out of its lane. Ram %d / bow plating %d." % [int(live_punch()), int(hull_plating_now())]
					return "Bait a charge into the rim wall, or out-clash it at ram punch %d." % int(Rules.CLASH_PUNCH) + gap
	return ""


# The plating of what the player should hit now: the hull's live plating in the fight
# (120, 150 on a charging bow, 0 while stunned) and the scooter's 0 in the chase.
func live_plating() -> float:
	if state == EJECT or state == DEFEATED:
		return 0.0
	return hull_plating_now()


# The punch that counts against live_plating(): only a ram can clash with the bow.
func live_punch() -> float:
	return ram_punch_now() if charging() else ctx.flow.punch_now()


# Combat's ram-only punch when it has one, else the ram punch built from its punch_of.
func ram_punch_now() -> float:
	var spawner = ctx.spawner
	if spawner != null and spawner.has_method("ram_punch_now"):
		return spawner.ram_punch_now()
	if spawner == null or not spawner.has_method("punch_of") or ctx.player.speed_tier() < 1:
		return 0.0
	return spawner.punch_of("ram", ctx.player.planar_velocity().length())


# The arena-ground seam: the bowl's floor under a point, which combat's telegraphs and
# lobber aim use while flow.in_arena. Outside a fight it falls back to the terrain.
func ground_height_at(point: Vector3) -> float:
	if is_instance_valid(arena):
		return arena.ground(point)
	if ctx.terrain != null and ctx.terrain.has_method("height"):
		return ctx.terrain.height(point.x, point.z)
	return point.y


# Combat tints plated pieces by punch_now() against their plating. A charging bow only
# answers a ram, so its tint is decided by the ram punch alone.
func tint_for(target, suggested: String) -> String:
	if target.role == "hull" and charging():
		return "amber" if ram_punch_now() >= hull_plating_now() else "slate"
	return suggested


func _publish(signal_name: String, args: Array = []) -> void:
	if ctx.events.has_signal(signal_name):
		ctx.events.callv("emit_signal", [signal_name] + args)


func _row(kind: String) -> Dictionary:
	var kinds = load("res://src/core/event_kinds.gd")
	return kinds.ROWS.get(kind, {})


func _discover(id: String, at: Vector3) -> void:
	if ctx.codex != null and ctx.codex.has_method("mark_discovered"):
		ctx.codex.mark_discovered(id, at)
