extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Warden := preload("res://src/combat/warden.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")

# The Warden, spawned at the beacon through ctx.spawner.spawn_enemy("warden", at).
# 1. A stage-1 Warden fights on posture: a blazing ram at heft 1 fills its bar and takes no health.
# 2. Pulses: the ball circles inside its reach for PULSE_SIM seconds. Every pulse
#    follows a telegraph of at least 2.0 s, adds lift only (planar speed across the
#    pulse changes by less than 3%), and the Warden never moves.
# 3. Continuous base runner fire on the body for FIRE_SIM seconds takes no health: only a
#    shatter does. The ball is held still and aimed at it.
# Long spans run at Engine.time_scale, and every duration is measured in simulated
# seconds (the sum of physics deltas), so the numbers are game time, not wall time.

const PULSE_SIM := 30.0
const PULSE_SCALE := 2.0
const FIRE_SCALE := 6.0
const FIRE_SIM := 20.0
const ORBIT := 12.0
const ORBIT_SPEED := 9.0
const STAND_OFF := 14.0

# F6 2026-10-04: blazing_ram and break_1/break_3 became posture checks; magnet stuns are gone.
# The double table keeps a stage-1 Warden at the surviving map.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _combat
var _source := Intent.Scripted.new()
var _failures := 0
var _phase := "setup"
var _sim := 0.0
var _warden: Node3D
var _home := Vector3.ZERO
var _drift := 0.0
var _pulses_seen := 0
var _planar_prev := 0.0
var _pulse_checks: Array = []
var _pending_pulse := -1
var _vy_prev := 0.0
var _missed_pulses := 0
var _anchor := Vector3.ZERO
var _kills := []


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	match _phase:
		"setup":
			_setup()
			return false
		"pulse":
			_sim += delta
			_step_pulse()
			if _sim >= PULSE_SIM:
				_finish_pulse()
				_start_fire(1)
		"fire":
			_sim += delta
			_game.player.reset_to(_anchor)
			if is_instance_valid(_warden):
				_aim_at(_warden.global_position)
			if not _kills.is_empty() or _sim > FIRE_SIM:
				# Health falls only through a shatter, and bolts never arm one.
				_report("bolts_no_health", _kills.is_empty() and is_instance_valid(_warden) and _warden.hp == _warden.max_hp,
					"%.1f s of continuous base runner fire on the body: killed %s, health %.1f of %.1f"
						% [_sim, not _kills.is_empty(), _warden.hp if is_instance_valid(_warden) else 0.0, _warden.max_hp if is_instance_valid(_warden) else 0.0])
				return _finish()
	return false


func _setup() -> void:
	_combat = _game.ctx.spawner
	var ctx = _game.ctx
	ctx.calm = true
	_game.player.source = _source
	# Hit-stop would drop time_scale back to 1 mid-test; the Warden test needs none.
	ctx._hit_stop = Callable()
	_game.events.enemy_killed.connect(func(kind: String, _at: Vector3, _scrap: int):
		if kind == "warden":
			_kills.append(_sim))
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(99999.0)
	_warden = _spawn_warden(1)
	_home = _warden.global_position

	_combat.heft_override = 1.0
	var blazing: float = ctx.tuning.f("cruise") * SpeedTier.MULTIPLES[SpeedTier.BLAZING]
	var before: float = _warden.hp
	var deflections: int = _combat.deflections
	var posture_before: float = _warden.posture()
	_combat.strike(_warden, "ram", blazing)
	_report("posture_ram", _warden.fight() == "posture" and _warden.hp == before and _warden.posture() > posture_before and _combat.deflections == deflections,
		"a blazing ram (%.1f m/s, punch %.1f) on fight %s filled posture %.1f to %.1f and took %.1f health"
			% [blazing, _combat.punch_of("ram", blazing), _warden.fight(), posture_before, _warden.posture(), before - _warden.hp])
	_combat.heft_override = -1.0
	_warden.hp = _warden.max_hp

	Engine.time_scale = PULSE_SCALE
	_place_orbit(0.0)
	_phase = "pulse"
	_sim = 0.0


func _spawn_warden(stage: int) -> Node3D:
	var ctx = _game.ctx
	return ctx.spawner.spawn_enemy("warden", ctx.terrain.beacon_point(stage))


# Circles the ball around the Warden inside its reach, at a steady speed.
func _place_orbit(angle: float) -> void:
	var ctx = _game.ctx
	var at: Vector3 = _warden.global_position + Vector3(cos(angle), 0.0, sin(angle)) * ORBIT
	at.y = ctx.terrain.height(at.x, at.z) + 1.05
	var tangent := Vector3(-sin(angle), 0.0, cos(angle))
	_game.player.reset_to(at, tangent * ORBIT_SPEED)
	_game.player.body().global_position = at


func _step_pulse() -> void:
	_drift = maxf(_drift, _warden.global_position.distance_to(_home))
	var planar: float = _game.player.planar_velocity().length()
	var vy: float = _game.player.state.velocity.y
	# The pulse lands in the Warden's tick and the ball spends it in the next physics
	# step, so the lift shows two test ticks after the count changes.
	if _pending_pulse >= 0:
		_pending_pulse += 1
		if _pending_pulse >= 2:
			if _warden.last_pulse_lifted:
				_pulse_checks.append([_planar_prev, planar, vy - _vy_prev])
			else:
				_missed_pulses += 1
			_pending_pulse = -1
	elif _warden.pulses > _pulses_seen:
		_pulses_seen = _warden.pulses
		_pending_pulse = 0
	if _pending_pulse < 0 or _pending_pulse == 0:
		_planar_prev = planar
		_vy_prev = vy
	# Re-seed the orbit between pulses so terrain never carries the ball out of reach.
	var flat: Vector3 = _game.player.ball_position() - _warden.global_position
	flat.y = 0.0
	if flat.length() > ORBIT + 8.0 or planar < 3.0:
		if _warden.state_name() == "idle" and _warden.seconds_since_pulse() > 0.3 and _pending_pulse < 0:
			_place_orbit(atan2(flat.z, flat.x))


func _finish_pulse() -> void:
	var worst := 0.0
	var least_lift := INF
	for pair in _pulse_checks:
		if pair[0] > 0.5:
			worst = maxf(worst, absf(pair[1] - pair[0]) / pair[0])
		least_lift = minf(least_lift, pair[2])
	_report("pulses", _warden.pulses >= 4 and _warden.min_pulse_telegraph >= 2.0,
		"%d pulses in %.0f s, shortest telegraph %.3f s (needs >= 2.0)" % [_warden.pulses, PULSE_SIM, _warden.min_pulse_telegraph])
	_report("pulse_planar", not _pulse_checks.is_empty() and worst < 0.03,
		"planar speed across %d pulses changed by at most %.2f%% (needs < 3%%)" % [_pulse_checks.size(), worst * 100.0])
	_report("pulse_lift", _pulse_checks.size() >= 3 and least_lift > 7.0,
		"%d pulses caught the ball in the reach ring and each raised its vertical speed by at least %.2f m/s (+10 less gravity over the sample); %d fired with the ball outside the ring and lifted nothing"
			% [_pulse_checks.size(), least_lift, _missed_pulses])
	_report("immobile", _drift < 0.001, "the Warden moved %.4f m over %.0f s" % [_drift, PULSE_SIM])


func _start_fire(stage: int) -> void:
	_kills.clear()
	var ctx = _game.ctx
	if stage != 1:
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
		_game.run.set_max_hp(99999.0)
		_warden = _spawn_warden(stage)
	var heading: Vector3 = ctx.terrain.entry_heading(stage)
	_anchor = _warden.global_position - heading * STAND_OFF
	_anchor.y = ctx.terrain.height(_anchor.x, _anchor.z) + 1.05
	_game.player.reset_to(_anchor)
	_game.player.body().global_position = _anchor
	_source.hold = {"fire_held": true}
	Engine.time_scale = FIRE_SCALE
	_phase = "fire"
	_sim = 0.0


func _aim_at(point: Vector3) -> void:
	var cam = _game.camera
	var d: Vector3 = (point - cam.aim_origin()).normalized()
	cam.yaw = atan2(-d.x, -d.z)
	cam.pitch = clampf(asin(d.y), -1.25, 0.55)


func _finish() -> bool:
	Engine.time_scale = 1.0
	_source.hold = {}
	var ok := _failures == 0
	print("combat_warden_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
