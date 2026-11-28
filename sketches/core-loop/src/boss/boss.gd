extends Node

const Rules := preload("res://src/boss/boss_rules.gd")
const Arena := preload("res://src/boss/arena.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const Target := preload("res://src/boss/boss_target.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const BossFurnace := preload("res://src/boss/boss_furnace.gd")
const BossCharge := preload("res://src/boss/boss_charge.gd")
const BossScooter := preload("res://src/boss/boss_scooter.gd")
const CHARGE_REACH := BossCharge.CHARGE_REACH
const CHARGE_RIM_CLEAR := BossCharge.CHARGE_RIM_CLEAR
const CHARGE_MIN_LANE := BossCharge.CHARGE_MIN_LANE
const PICKUP_HULL_MARGIN := 0.25
const CodexEntries := preload("res://src/boss/codex_entries.gd")
const Palette := preload("res://src/core/palette.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const Field := preload("res://src/build/scrap_field.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const Worlds := preload("res://src/core/worlds.gd")
const EnemyBossCraft := preload("res://src/presentation/craft/enemy_boss_craft.gd")

enum { IDLE, FIGHT, EJECT, DEFEATED }
const STATE_NAMES := ["idle", "fight", "eject", "defeated"]
const CHASE_PHASE := 4
const CHASE_NAME := "chase"
const RESCUE_DEPTH := 10.0
const RESCUE_CLEAR := 14.0
const PLATE_SHORT := Color("9fb0bf")
static var _pickup_materials := {}
static var _pickup_mesh: Mesh

var ctx
var state := IDLE
var phase := 0
var hp := Rules.MAX_HP
var max_hp := Rules.MAX_HP
var clock := 0.0
var phase_clock := 0.0
var arena
var ship
var scooter
var hazards: Array = []
var stuns := 0
var clashes := 0
var catches := 0

var _furnace := BossFurnace.new()
var _charge_ctrl := BossCharge.new()
var _scooter_ctrl := BossScooter.new()

var _scooter_anim: AnimationPlayer:
	get:
		return _scooter_ctrl.scooter_anim
	set(v):
		_scooter_ctrl.scooter_anim = v

var _delta := 1.0 / 90.0
var _next_attack := 0.0
var _crane_turn := 0
var _combo_left := -1
var _cranes: Array = [{}, {}]
var _pickups: Array = []
const CHARGE_REST := BossCharge.CHARGE_REST
const CHARGE_BRACE := BossCharge.CHARGE_BRACE
const CHARGE_RUN := BossCharge.CHARGE_RUN
const CHARGE_RECOVER := BossCharge.CHARGE_RECOVER
const CHARGE_STUN := BossCharge.CHARGE_STUN
const CHARGE_HOOK := BossCharge.CHARGE_HOOK
var _charge: Dictionary:
	get:
		return _charge_ctrl.charge
	set(v):
		_charge_ctrl.charge = v
var _grace := {}
var _eject: Dictionary:
	get:
		return _scooter_ctrl.eject
	set(v):
		_scooter_ctrl.eject = v
var _ship_angle := 0.0
var _crest: Node3D
var _drones: Array:
	get:
		return _furnace.drones
	set(v):
		_furnace.drones = v
var _lobbers: Array:
	get:
		return _furnace.lobbers
	set(v):
		_furnace.lobbers = v
var _reprise: Dictionary:
	get:
		return _furnace.reprise
	set(v):
		_furnace.reprise = v
var _posture := BossPosture.new(Rules.POSTURE)
var _phases: FightPhases
var _reel_hits := 0
var _reel_last := -INF
var _preview: Node3D
var _reprise_preview: Node3D
var _last_commit_at := -INF
var _was_reeling := false
var _reel_plant := ""
var brindle_cobalt_offers: Array = []
var brindle_cobalt_picked := ""
var _cobalt_gates: Node3D = null


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
	var world = ctx.root.get("world") if ctx.root != null else null
	if world != null and world.has_method("mark_arrival"):
		var ground: RefCounted = arena.ground_query()
		world.mark_arrival(at, velocity, Callable(ground, "height"))


func arrival_heading() -> Vector3:
	return Arena.arrival_heading()


func exit_arena() -> void:
	_furnace.reset()
	_charge_ctrl.reset()
	_scooter_ctrl.reset()
	if is_instance_valid(arena):
		arena.get_parent().remove_child(arena)
		arena.queue_free()
	arena = null
	if ctx.camera != null:
		ctx.camera.clear_contact_subject(ship)
	ship = null
	scooter = null
	hazards.clear()
	_pickups.clear()
	_grace.clear()
	_cranes = [{}, {}]
	_preview = null
	_reprise_preview = null
	_last_commit_at = -INF
	_was_reeling = false
	_close_cobalt_gates()
	brindle_cobalt_offers = []
	if state != DEFEATED:
		state = IDLE
	phase = 0


func _on_flow_changed(flow_state: String) -> void:
	if flow_state in ["title", "class_select", "summary"]:
		exit_arena()
		state = IDLE


func _physics_process(delta: float) -> void:
	if active() and ctx.flow.state_name() == "boss":
		advance(delta)
	elif state == DEFEATED and is_instance_valid(_cobalt_gates) and _cobalt_gates.is_open():
		var heading: Vector3 = ctx.player.planar_velocity()
		heading = heading.normalized() if heading.length() > 0.5 else ctx.heading()
		_cobalt_gates.step(ctx.player.ball_position(), heading)


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


func _held() -> bool:
	return state == FIGHT and _chunks_lost() >= phase


func banking() -> bool:
	return _held() and phase < 3 and not _in_transition()


func reeling() -> bool:
	return _held() and not _in_transition()


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


func bank_cap() -> float:
	return Rules.HELD_BANK / BossPosture.FULL


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
			_furnace.enter_phase(clock)
			_combo_left = -1
		3:
			ship.shed_armour()
			ship.cockpit_open(true, "enter_scuttle")
			_combo_left = -1
			_charge_ctrl.enter_phase()
	ship.cue_phase(next)
	_publish("boss_phase_changed", [next, Rules.PHASE_NAMES[next - 1]])
	if _phases != null:
		_phases.enter(next, clock)
	_show_preview(next)


func _bone_ring(id: String, band: Vector2, warn_s: float, floor_s := -1.0) -> Node3D:
	var h = Hazard.new()
	h.ground = arena.ground
	h.color = Palette.SAND
	if floor_s > 0.0:
		h.warn_floor = floor_s
	h.commit_annulus(id, Hazard.Threat.Type.INSTANT, arena.global_position, band, 0.0, warn_s, 0.01)
	arena.add_child(h)
	return h


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


func jump_to_phase(next: int) -> void:
	if not active():
		return
	if next >= 1:
		_posture.chunks = BossPosture.CHUNKS - (mini(next, 4) - 1)
		hp = float(_posture.chunks)
	if next > 3:
		_begin_eject()
	else:
		_enter_phase(next)


func _move_ship_on_circle(delta: float) -> void:
	_ship_angle += Rules.CIRCLE_SPEED / Rules.CIRCLE_RADIUS * delta
	ship.move_to(arena.point_at(_ship_angle, Rules.CIRCLE_RADIUS), Arena.tangent(_ship_angle))


func _paced(normal: float) -> float:
	_combo_left = ChallengeDials.combo_step("brindle", _combo_left)
	if _combo_left > 0:
		return ChallengeDials.WARN_GAP
	_combo_left = -1
	return normal


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
	if reeling() and not _was_reeling and _reel_plant != "stop":
		var base_period := ChallengeDials.period("brindle", Rules.CRANE_PERIOD, 1)
		_next_attack = minf(_next_attack, clock + minf(base_period * Rules.REEL_PERIOD_MULT, Rules.REEL_MAX_GAP))
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
		if not ctx.flow.in_play():
			return


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


func _ball_cruising() -> bool:
	return ctx != null and ctx.player != null and ctx.tuning != null \
		and ctx.player.planar_velocity().length() >= ctx.tuning.f("cruise")


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
			if not c["caught"] and h.contains(ball) and _swept(h, ball) and not _ball_cruising():
				_crane_catch(i, ball, at)
				if not ctx.flow.in_play():
					return
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
	var taken := 0
	if ctx.run.mass >= 1.0:
		var steal_share := Rules.REEL_STEAL_SHARE if reeling() else Rules.STEAL_SHARE
		var steal_cap := Rules.REEL_STEAL_MAX if reeling() else Rules.STEAL_MAX
		var amount := clampi(int(round(ctx.run.mass * steal_share)), Rules.STEAL_MIN, steal_cap)
		taken = ctx.run.lose_scrap(amount, ball, "crane")
	if not reeling():
		ctx.run.damage(ChallengeDials.damage("brindle", Rules.CRANE_DAMAGE, phase), "crane")
		if not ctx.flow.in_play():
			return
	if taken <= 0:
		return
	var h = c["hazard"]
	var r := Vector2(ball.x - h.centre.x, ball.z - h.centre.z).length()
	if reeling():
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


func _tug(ball: Vector3, magnet_at: Vector3) -> void:
	if ctx.calm:
		return
	var pull := Vector3(magnet_at.x - ball.x, 0.0, magnet_at.z - ball.z)
	pull = pull.normalized() if pull.length() > 0.1 else Vector3.ZERO
	var step := maxf(_delta, 1.0 / float(Engine.physics_ticks_per_second))
	ctx.player.crowd_control("brindle_tug", (Vector3.UP * Rules.TUG_LIFT + pull * Rules.TUG_PULL) / step, false)


func _shove_ball(kind: String, dv: Vector3, interrupts := true) -> void:
	if ctx.player.has_method("shove_planar"):
		ctx.player.shove_planar(dv, interrupts, kind)


func _drip(c: Dictionary) -> void:
	var k: int = c["dripped"]
	if k >= c["trail"].size():
		c["held"] = 0
		return
	_place_pickup(c["trail"][k], c["values"][k], "returned")
	c["held"] -= c["values"][k]
	c["dripped"] = k + 1
	ship.cue("magnet_hold_drip", int(c["dripped"]))


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
		var made: ShaderMaterial = Field.pickup_material(Palette.AMBER)
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


func _spill_break() -> void:
	var at: Vector3 = ship.global_position
	for k in Rules.BREAK_PICKUPS:
		var p: Vector3 = at + Arena.dir(TAU * k / Rules.BREAK_PICKUPS) * Rules.BREAK_RADIUS
		var value := Rules.BREAK_SPILL / Rules.BREAK_PICKUPS + (1 if k < Rules.BREAK_SPILL % Rules.BREAK_PICKUPS else 0)
		_place_pickup(Vector3(p.x, arena.ground(p) + 0.9, p.z), value, "spill")


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


func _on_enemy_killed(kind: String, at: Vector3, scrap_value: int) -> void:
	if not active() or kind != "lobber" or not is_instance_valid(arena):
		return
	_place_pickup(Vector3(at.x, arena.ground(at) + 0.9, at.z), maxi(1, scrap_value), "kill")


func pickups_left() -> Array:
	return _pickups.map(func(p): return {"at": p["at"], "value": p["value"], "source": p["source"]})


func _step_furnace(delta: float) -> void:
	_furnace.step(self, delta)


func _slag_band(turn: int) -> Vector2:
	return _furnace.slag_band(self, turn)


func _commit_slag(turn: int, cued: bool, live_override := -1.0) -> float:
	return _furnace.commit_slag(self, turn, cued, live_override)


func _in_transition() -> bool:
	return _phases != null and _phases.in_transition()


func in_transition() -> bool:
	return _in_transition()


func trace_snapshot() -> Dictionary:
	return {
		"charge_state": String(_charge.get("state", "")),
		"charge_timer": float(_charge.get("timer", 0.0)),
		"held": _held(),
		"in_transition": _in_transition(),
	}


func _follow_ups() -> int:
	return _phases.follow_ups() if _phases != null else 0


func follow_ups() -> int:
	return _follow_ups()


func pending_drones() -> Array:
	return _furnace.pending_drones()


func _step_drones(delta: float) -> void:
	_furnace.step_drones(self, delta)


func _step_vents(ball: Vector3) -> void:
	var vent: int = arena.vent_at(ball)
	if vent >= 0:
		arena.quench(vent, clock)


func _reel_sear(ball: Vector3, cause: String) -> void:
	if not ctx.run.armor_mode or ctx.run.mass < 1.0:
		return
	var share := Rules.REEL_SEAR_SHARE if reeling() else Rules.SLOW_SEAR_SHARE
	var cap := Rules.REEL_SEAR_MAX if reeling() else Rules.SLOW_SEAR_MAX
	var sear := clampi(int(round(ctx.run.mass * share)), 0, cap)
	if sear > 0:
		ctx.run.lose_scrap(sear, ball, cause)


func _slag_hit(h, ball: Vector3, skim := false) -> void:
	_furnace.slag_hit(self, h, ball, skim)


func _step_charges(delta: float, ball: Vector3) -> void:
	_charge_ctrl.step(self, delta, ball)


func _aim_at(ball: Vector3) -> Vector3:
	return _charge_ctrl.aim_at(self, ball)


func _commit_charge(cued := false) -> void:
	_charge_ctrl.commit_charge(self, cued)


func _travel_to_rim(from: Vector3, heading: Vector3) -> float:
	return _charge_ctrl.travel_to_rim(self, from, heading)


func _step_ghost() -> void:
	_charge_ctrl.step_ghost(self)


func _stun(seconds: float) -> void:
	_charge_ctrl.stun(self, seconds)


func stunned() -> bool:
	return _charge_ctrl.stunned(self)


func _note_glance(target, part: String, result: Dictionary) -> void:
	_charge_ctrl.note_glance(self, target, part, result)


func take_hint() -> String:
	return _charge_ctrl.take_hint(self)


func charging() -> bool:
	return _charge_ctrl.charging(self)


func _begin_eject() -> void:
	_scooter_ctrl.begin_eject(self)


const EJECT_MARK_LIVE := BossScooter.EJECT_MARK_LIVE


func eject_mark() -> Node3D:
	return _scooter_ctrl.eject_mark()


func _step_scooter(delta: float) -> void:
	_scooter_ctrl.step(self, delta)


func scooter_speed() -> float:
	return _scooter_ctrl.scooter_speed(clock)


func scooter_landed() -> bool:
	return _scooter_ctrl.scooter_landed(self)


func _on_enemy_struck(enemy: Node3D, kind: String, _force: float) -> void:
	_scooter_ctrl.on_enemy_struck(self, enemy, kind)


func new_hazard():
	return _new_hazard()


func add_hazard(h) -> void:
	_add_hazard(h)


func publish_event(signal_name: String, args: Array = []) -> void:
	_publish(signal_name, args)


func discover_entry(id: String, at: Vector3) -> void:
	_discover(id, at)


func paced_cadence(normal: float) -> float:
	return _paced(normal)


func rest_time_now() -> float:
	return _rest_time()


func shove_ball(kind: String, dv: Vector3, interrupts := true) -> void:
	_shove_ball(kind, dv, interrupts)


func reel_sear(ball: Vector3, cause: String) -> void:
	_reel_sear(ball, cause)


func ball_cruising() -> bool:
	return _ball_cruising()


func show_reprise_preview(turn: int) -> void:
	_show_reprise_preview(turn)


func clear_reprise_preview() -> void:
	_clear_reprise_preview()


func cancel_hazards() -> void:
	_cancel_hazards()


func spill_break() -> void:
	_spill_break()


func defeat_boss(kind: String, at: Vector3, source := "") -> void:
	_defeat(kind, at, source)


func from_above_target(target) -> bool:
	return _from_above(target)


func set_hazard_grace(id: int, until: float) -> void:
	_grace[id] = until


func hazard_grace(id: int) -> float:
	return float(_grace.get(id, -1.0))


func note_commit() -> void:
	_last_commit_at = clock


func last_commit_at() -> float:
	return _last_commit_at


func step_combo() -> void:
	_combo_left = ChallengeDials.combo_step("brindle", _combo_left)


func clear_combo() -> void:
	_combo_left = -1


func set_next_attack(at: float) -> void:
	_next_attack = at


func next_attack_at() -> float:
	return _next_attack


func was_reeling_now() -> bool:
	return _was_reeling


func reel_plant_mode() -> String:
	return _reel_plant


func cue_phase_name(event_name: String) -> void:
	_phases.cue(event_name)


func posture_staggered() -> bool:
	return _posture.staggered


func is_held() -> bool:
	return _held()


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
	_offer_cobalt_pick()
	ctx.flow.boss_active = false
	if is_instance_valid(ship):
		ctx.camera.clear_contact_subject(ship)
		ship.follow_shoved_rider(null)
	_publish("boss_defeated")
	if is_instance_valid(scooter):
		scooter.visible = false


func _offer_cobalt_pick() -> void:
	_close_cobalt_gates()
	brindle_cobalt_offers = []
	brindle_cobalt_picked = ""
	if not Worlds.BRINDLE_COBALT_PICK or ctx == null or ctx.flow == null or ctx.run == null:
		return
	if ctx.flow.run_ends_after(ctx.run.stage):
		return
	if ctx.build != null and ctx.build.has_method("scrapless") and ctx.build.scrapless():
		return
	if String(ctx.run.extra.get("brindle_cobalt_picked", "")) != "":
		return
	if ctx.build == null or not ctx.build.has_method("roll_cobalt_boss_picks"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([ctx.rng.seed if ctx.rng != null else 0, ctx.flow.run_key(), ctx.run.stage, "brindle_cobalt"])
	var class_id: String = ctx.run.class_id() if ctx.run.has_method("class_id") else ""
	var picks: Array = ctx.build.roll_cobalt_boss_picks(rng, class_id, ctx.run.parts, 2)
	if picks.is_empty():
		return
	brindle_cobalt_offers = picks
	ctx.run.extra["brindle_cobalt_pending"] = String(picks[0])
	if is_instance_valid(arena):
		var heading: Vector3 = ctx.player.planar_velocity()
		heading = heading.normalized() if heading.length() > 0.5 else ctx.heading()
		_cobalt_gates = ctx.build.open_cobalt_boss_gates(arena, arena.ground_query(), picks, ctx.player.ball_position(), heading, ctx.run.parts, _on_cobalt_pick_chosen)


func _on_cobalt_pick_chosen(part_id: String) -> void:
	if part_id == "" or ctx == null or ctx.run == null:
		return
	if String(ctx.run.extra.get("brindle_cobalt_picked", "")) != "":
		return
	brindle_cobalt_picked = part_id
	ctx.run.extra.erase("brindle_cobalt_pending")
	ctx.run.extra["brindle_cobalt_picked"] = part_id
	if ctx.build == null or not ctx.build.has_method("scrapless") or not ctx.build.scrapless():
		ctx.run.add_part(part_id, "boss_cobalt")
	if ctx.flow != null and ctx.flow.has_method("save_boss_won"):
		ctx.flow.save_boss_won()


func _close_cobalt_gates() -> void:
	if is_instance_valid(_cobalt_gates):
		_cobalt_gates.close()
		_cobalt_gates.queue_free()
	_cobalt_gates = null


func _sync_crest() -> void:
	var wanted: bool = ctx.run.parts.has(Rules.CREST_PART)
	if wanted and not is_instance_valid(_crest):
		_crest = Node3D.new()
		_crest.name = "AdmiralsCrest"
		var badge := MeshInstance3D.new()
		badge.name = "AdmiralsCrestBadge"
		badge.mesh = EnemyBossCraft.admirals_crest_badge(0.5, 0.14)
		badge.material_override = EnemyBossCraft.craft_shader_material("admirals_crest_brass", "oxidized_hull_plating", Palette.BRASS, Palette.AMBER, 0.38, 0.76, Palette.AMBER, 1.1)
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


func _cancel_hazards() -> void:
	_clear_preview()
	_clear_reprise_preview()
	if is_instance_valid(ship):
		ship.set_hook_brace(false)
	_scooter_ctrl.clear_mark()
	for h in hazards:
		if is_instance_valid(h):
			h.queue_free()
	hazards.clear()
	_furnace.cancel_hazards()
	for c in _cranes:
		if c.has("hazard"):
			c.erase("hazard")
		while c.get("held", 0) > 0:
			_drip(c)


func active_hazards() -> Array:
	return hazards.filter(func(h): return is_instance_valid(h) and not h.is_done())


func _step_hazards(delta: float, ball: Vector3) -> void:
	var kept: Array = []
	for h in hazards:
		if not is_instance_valid(h):
			continue
		h.step(delta)
		if h.is_live() and h.is_hostile() and h.type != Hazard.Threat.Type.WAVE and not h.has_meta("fx27_flashed"):
			h.set_meta("fx27_flashed", true)
			if is_instance_valid(ship) and ship.has_method("trigger_strike_flash"):
				ship.trigger_strike_flash()
		if h.shape == Hazard.Shape.ANNULUS and h.is_live() \
				and (not h.cued or h.age >= h.warn_seconds + 0.025):
			if h.contains(ball) and clock >= _grace.get(h.get_instance_id(), -1.0):
				_slag_hit(h, ball, _ball_cruising())
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
	return _furnace.on_crust(self, h, ball)


func floor_y() -> float:
	return arena.global_position.y - RESCUE_DEPTH if is_instance_valid(arena) else -INF


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


func _rescue(ball: Vector3) -> void:
	if arena.contains(ball):
		return
	var v: Vector3 = ctx.player.state.velocity
	var speed := Vector2(v.x, v.z).length()
	var turning := signf(v.dot(Arena.tangent(arena.angle_of(ball))))
	var at := rescue_point(ball)
	ctx.player.reset_to(at, Arena.tangent(arena.angle_of(at)) * speed * (turning if turning != 0.0 else 1.0))


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


func _landing(target, kind: String) -> bool:
	if kind in Rules.CAP_KINDS:
		return _over(target) and ctx.player.ball_position().y >= target.global_position.y - 0.5
	return kind == "ram" and _from_above(target)


func _from_above(target) -> bool:
	return ctx.player.ball_position().y - target.global_position.y >= Rules.ABOVE and _over(target)


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
	if _held() or _in_transition():
		result = result.duplicate()
		_bank(result)
	_posture.apply(result, Engine.get_physics_frames())
	_sync_stagger(was_staggered)
	_publish_posture(before)


func _step_posture(delta: float) -> void:
	var before := _posture_signature()
	var was_staggered: bool = _posture.staggered
	if (_held() or _in_transition()) and not _posture.staggered:
		_posture.idle = 0.0
	_posture.step(delta)
	_sync_stagger(was_staggered)
	_publish_posture(before)


func _posture_signature() -> Array:
	return [floori(_posture.posture), _posture.staggered, _posture.chunks, _posture.cracked]


func _publish_posture(before: Array) -> void:
	if before != _posture_signature() and is_instance_valid(ship) and is_instance_valid(ship.hull):
		ctx.events.posture_changed.emit(ship.hull, _posture.posture, _posture.staggered)


func _sync_stagger(was_staggered: bool) -> void:
	if _posture.staggered == was_staggered or not is_instance_valid(ship):
		return
	ship.cockpit_open(_posture.staggered or phase >= 3)


func hull_plating_now() -> float:
	if not active() or not is_instance_valid(ship):
		return Rules.HULL_PLATING
	var plating := plating_for(ship.hull, "", "")
	if ctx.spawner != null and ctx.spawner.has_method("shred_of"):
		plating = maxf(0.0, plating - ctx.spawner.shred_of(ship.hull))
	return plating


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


func plate_reading() -> Dictionary:
	return {"phase": phase if active() else 0, "open": (stunned() or staggered()) and not charge_coming()}


func charge_coming() -> bool:
	return _charge_ctrl.charge_coming(self)


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


func live_plating() -> float:
	if state == EJECT or state == DEFEATED:
		return 0.0
	return hull_plating_now()


func live_punch() -> float:
	return ram_punch_now() if charging() else ctx.flow.punch_now()


func ram_punch_now() -> float:
	var spawner = ctx.spawner
	if spawner != null and spawner.has_method("ram_punch_now"):
		return spawner.ram_punch_now()
	if spawner == null or not spawner.has_method("punch_of") or ctx.player.speed_tier() < 1:
		return 0.0
	return spawner.punch_of("ram", ctx.player.planar_velocity().length())


func ground_height_at(point: Vector3) -> float:
	if is_instance_valid(arena):
		return arena.ground(point)
	if ctx.terrain != null and ctx.terrain.has_method("height"):
		return ctx.terrain.height(point.x, point.z)
	return point.y


func tint_for(target, suggested: String) -> String:
	if target.role == "hull" and charging():
		return "amber" if ram_punch_now() >= hull_plating_now() else "slate"
	return suggested


func scooter_craft():
	return EnemyBossCraft


func _publish(signal_name: String, args: Array = []) -> void:
	if ctx.events.has_signal(signal_name):
		ctx.events.callv("emit_signal", [signal_name] + args)


func _row(kind: String) -> Dictionary:
	var kinds = load("res://src/core/event_kinds.gd")
	return kinds.ROWS.get(kind, {})


func _discover(id: String, at: Vector3) -> void:
	if ctx.codex != null and ctx.codex.has_method("mark_discovered"):
		ctx.codex.mark_discovered(id, at)
