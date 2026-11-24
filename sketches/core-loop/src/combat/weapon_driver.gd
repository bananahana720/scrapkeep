extends RefCounted

const Pattern := preload("res://src/combat/pattern.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Weapons := preload("res://src/combat/weapons.gd")

# Weapon trigger and cadence driver (PILOT-CADENCE.md sections 2, 3.1-3.6, 4 and 7).
# Owned by Combat, one instance per Combat with no static state, so warm-batched tests need
# no reset. Combat calls step() once per physics tick and lifecycle hooks on attempt
# boundaries and interruptions; the reticle, sound twins and tests read state_snapshot().
# Procs never call into this module.

# One-press input buffer (PILOT-CADENCE.md section 2.2): a press inside BUFFER_S before ready
# acts the instant the trigger is ready.
const BUFFER_S := 0.10
const EPS := 0.00001

# Window states published in state_snapshot().
const WINDOW_IDLE := "idle"
const WINDOW_WAITING := "waiting"
const WINDOW_OPEN := "open"
const WINDOW_SPENT := "spent"
const WINDOW_HIT := "hit"

# Interrupt reasons (PILOT-CADENCE.md section 2.3).
const INTERRUPT_ATTEMPT := "attempt"
const INTERRUPT_ULTIMATE := "ultimate"
const INTERRUPT_MOUNT := "mount"
const INTERRUPT_SWAP := "swap"

# Shot kinds emitted by step().
const SHOT_PLAIN := "plain"
const SHOT_PRESS := "press"
const SHOT_HOT := "hot"
const SHOT_FAN := "fan"
const SHOT_SPARK := "spark"
const SHOT_CHARGED := "charged"
const SHOT_THROW := "throw"
const SHOT_SNAP := "snap"
const SHOT_BEAT_1 := "beat_1"
const SHOT_BEAT_2 := "beat_2"
const SHOT_BEAT_3 := "beat_3"
const SHOT_STAMP := "stamp"
const SHOT_PULSE := "pulse"
const SHOT_RAIL := "rail"
const SHOT_BARRAGE := "barrage"

var _weapon := ""
var _trigger: String = Pattern.DEFAULT_TRIGGER
var _cooldown := 0.0
var _recover_s := 0.0
var _press_held := false
var _hold_s := 0.0
var _buffered := false
var _buffer_s := 0.0
var _buffer_latched := false
var _chamber := 0
var _mag := 0
var _hot_rounds := 0
var _hot_pierce := false
var _reloading := false
var _reload_t := 0.0
var _reload_s := 0.0
var _floor_s := 0.0
var _beat_floors_s: Array = []
var _beat_window_s := 0.0
var _beat_mults: Array = []
var _beat_speed_mult := 0.0
var _beat_knock_mult := 1.0
var _beat_range_mult := 1.0
var _window_mult := 1.0
var _charge_s := 0.0
var _charge_min := 0.0
var _tap_threshold_s := 0.0
var _recover_cfg_s := 0.0
var _charge := 0.0
var _charging := false
var _charge_armed := false
var _lob_charging := false
var _snap_token := 0
var _snap_hold_lock := false
var _slot_ready := true
var _beat := 0
var _beat_t := 0.0
var _window_state := WINDOW_IDLE
var _window_t := 0.0
var _window_s := Vector2.ZERO
var _lane_painted := false
var _cast_cost := 1.0
var _refund := 0.0
var _stamp_streak := 0
var _stamp_streak_bonus := 0.0
var _stamp_streak_cap := 0.0
var _lock_rail_damage := 0.0
var _lock_barrage_damage := 0.0
var _lock_pulse_reach := 0.0
var _lock_rail_reach := 0.0
var _lock_pulse_width_mult := 1.0
var _lock_rail_width_mult := 1.0
var _lock_barrage_width_mult := 1.0
var _lock_rail_breaks_props := false


# Advances trigger timers by `delta` and interprets `intent` for `weapon` under `pattern`.
# Returns an array of shot descriptors ({kind, weapon, damage_mult, pierce, spread_deg}) to
# fire this tick. Optional `context` supplies live cadence modifiers:
#   rate_mult (float, default 1.0): overdrive / weapon_rate floor divisor
#   reload_rate_mult (float, default 1.0): reload pace (rate parts; never Overdrive)
#   sprinting (bool, default false): Rivet Overdrive Sprint fan
#   charge_rate (float, default 1.0): Sable speed-tier charge multiplier (1.0 / 1.5 / 2.0)
#   planar_speed (float, default 0.0): Tarn Beat 3 speed term (capped at BEAT_SPEED_CAP)
#   managed_gauge (bool, default false): Kest live Combat owns AbilityState.Gauge
#   slot_ready (bool, default true): Kest AbilityState.WEAPON readiness
#   lob_charging (bool, default false): Kest live gauge.charging mirror for state_snapshot()
func step(delta: float, intent, weapon: String, pattern: Resource, rate_hz: float, context: Dictionary = {}) -> Array:
	var trigger: String = String(pattern.trigger) if pattern != null else Pattern.DEFAULT_TRIGGER
	if _weapon != weapon or _trigger != trigger:
		_switch_weapon(weapon, pattern, trigger)
	elif pattern != null:
		_sync_pattern(pattern, false)
	var was_held := _press_held
	var held: bool = bool(intent.fire_held) if intent != null else false
	var pressed: bool = bool(intent.fire_pressed) if intent != null else false
	var released: bool = (bool(intent.fire_released) if intent != null else false) or (was_held and not held)
	_press_held = held
	_buffer_latched = false
	var shots: Array
	if _trigger == Pattern.TRIGGER_PRESS:
		shots = _step_press(delta, weapon, pattern, pressed, held, context)
	elif _trigger == Pattern.TRIGGER_TAP_CHARGE:
		shots = _step_tap_charge(delta, weapon, pattern, pressed, held, released, context)
	elif _trigger == Pattern.TRIGGER_LOB_SNAP:
		shots = _step_lob_snap(delta, weapon, pattern, pressed, held, released, context)
	elif _trigger == Pattern.TRIGGER_BEATS:
		shots = _step_beats(delta, weapon, pattern, pressed, held, context)
	elif _trigger == Pattern.TRIGGER_STAMP:
		shots = _step_stamp(delta, weapon, pattern, pressed, held, context)
	elif _trigger == Pattern.TRIGGER_LOCK:
		shots = _step_lock(delta, weapon, pattern, pressed, held, released, context)
	else:
		if pressed:
			_hold_s = 0.0
		elif held:
			_hold_s += delta
		else:
			_hold_s = 0.0
		_cooldown -= delta
		if _recover_s > 0.0:
			_recover_s = maxf(0.0, _recover_s - delta)
		shots = _step_hold_auto(weapon, pattern, rate_hz, pressed, held)
	# The buffer ages after the trigger has had its chance to spend it, and never on the
	# tick it was latched, so a press kept BUFFER_S before ready fires on the ready tick.
	if _buffered and not _buffer_latched:
		_buffer_s -= delta
		if _buffer_s <= EPS:
			_buffered = false
			_buffer_s = 0.0
	return shots


# Refreshes cached magazine, reload, floor, charge and window limits after a mid-run
# pattern rebuild even when the weapon id and trigger mode are unchanged.
func sync_pattern(weapon: String, pattern: Resource) -> void:
	if pattern == null or (_weapon != "" and _weapon != weapon):
		return
	var trigger: String = String(pattern.trigger)
	if _weapon != weapon or _trigger != trigger:
		_switch_weapon(weapon, pattern, trigger)
		return
	_sync_pattern(pattern, false)


# Rivet's Skid landing or Line Drive (PILOT-CADENCE.md section 3.1): ends a reload at once,
# or tops a part-used cylinder up to six. Added rounds are plain and fire after any loaded
# hot rounds already in the cylinder.
func top_up_cylinder() -> bool:
	if _trigger != Pattern.TRIGGER_PRESS or _mag <= 0:
		return false
	if _reloading:
		_reloading = false
		_reload_t = 0.0
		_window_t = 0.0
		_window_state = WINDOW_IDLE
		_chamber = _mag
		_hot_rounds = 0
		_hot_pierce = false
		_cooldown = 0.0
		return true
	if _chamber < _mag:
		_chamber = _mag
		return true
	return false


# Charges a flat recovery floor after a tap/card weapon commits a cast.
func commit_recovery(seconds: float) -> void:
	_cooldown = maxf(_cooldown, 0.0) + maxf(seconds, 0.0)


# Tally's stamp: commits a landed Balance Due cast, sets the cast floor and opens the PAID
# stamp window. Updating streak here keeps sky-aim and dry presses from faking a beat.
func commit_stamp(paid: bool, rate_mult := 1.0) -> void:
	_cooldown = _floor_s / maxf(rate_mult, 0.1)
	_window_t = 0.0
	_window_state = WINDOW_WAITING if _window_s.y > _window_s.x else WINDOW_IDLE
	_stamp_streak = (_stamp_streak + 1) if paid else 0
	_buffered = false
	_buffer_s = 0.0


# Kest's lob_snap: opens the snap window for a newly committed throw and arms the throw floor.
# Returns the opaque throw token carried by the charge(s) of this throw.
func commit_lob_throw(rate_mult := 1.0) -> int:
	var floor_s: float = _floor_s / maxf(rate_mult, 0.1)
	_cooldown = floor_s
	_snap_token += 1
	_window_t = 0.0
	_window_state = WINDOW_WAITING if _window_s.y > _window_s.x else WINDOW_IDLE
	_lob_charging = false
	_hold_s = 0.0
	_buffered = false
	_buffer_s = 0.0
	return _snap_token


# Consumes an open snap window on behalf of Detonation Line (PILOT-CADENCE.md section 3.3).
# Returns true iff `token` matches the live charge whose window is currently open.
func consume_snap_window(token: int) -> bool:
	if _trigger != Pattern.TRIGGER_LOB_SNAP or token <= 0 or token != _snap_token:
		return false
	if _window_state != WINDOW_OPEN:
		return false
	_window_state = WINDOW_HIT
	return true


# Called when all live charges belonging to `token` have detonated or been cleared.
func notify_lob_charge_gone(token: int) -> void:
	if _trigger != Pattern.TRIGGER_LOB_SNAP or token <= 0 or token != _snap_token:
		return
	if _window_state == WINDOW_WAITING or _window_state == WINDOW_OPEN or _window_state == WINDOW_SPENT:
		_window_state = WINDOW_IDLE
		_window_t = 0.0


# Consumes a latched one-press buffer when live Combat opens a managed lob gauge.
func consume_buffer() -> void:
	_buffered = false
	_buffer_s = 0.0


# Syncs managed lob-gauge charging state immediately when Combat opens or closes the gauge.
func set_lob_charging(active: bool) -> void:
	_lob_charging = active


# Returns the driver to rest (PILOT-CADENCE.md section 2.2): zero cooldown, full plain
# chamber, no charge, beat zero, no window open, no painted lane.
func reset(pattern: Resource = null) -> void:
	_cooldown = 0.0
	_recover_s = 0.0
	_press_held = false
	_hold_s = 0.0
	_buffered = false
	_buffer_s = 0.0
	_buffer_latched = false
	_hot_rounds = 0
	_hot_pierce = false
	_reloading = false
	_reload_t = 0.0
	_charge = 0.0
	_charging = false
	_charge_armed = false
	_lob_charging = false
	_snap_token = 0
	_snap_hold_lock = false
	_slot_ready = true
	_beat = 0
	_beat_t = 0.0
	_window_state = WINDOW_IDLE
	_window_t = 0.0
	_lane_painted = false
	_stamp_streak = 0
	if pattern != null:
		_sync_pattern(pattern, true)
	else:
		_chamber = _mag


# Handles a cycle interruption (PILOT-CADENCE.md section 2.3).
func interrupt(reason: String) -> void:
	match reason:
		INTERRUPT_ATTEMPT, INTERRUPT_SWAP:
			reset()
		INTERRUPT_ULTIMATE:
			_charge = 0.0
			_charging = false
			_charge_armed = false
			_lob_charging = false
			_snap_hold_lock = false
			_beat = 0
			_beat_t = 0.0
			_hold_s = 0.0
			_lane_painted = false
			_stamp_streak = 0
			_buffered = false
			_buffer_s = 0.0
			if _window_state == WINDOW_WAITING or _window_state == WINDOW_OPEN:
				_window_state = WINDOW_SPENT
		INTERRUPT_MOUNT:
			_charge = 0.0
			_charging = false
			_charge_armed = false
			_hold_s = 0.0
			_buffered = false
			_buffer_s = 0.0


# Read-only snapshot for the aim reticle, sound twins and tests. Mutating the returned
# dictionary never alters internal state.
func state_snapshot() -> Dictionary:
	var reload_frac := clampf(_reload_t / _reload_s, 0.0, 1.0) if _reloading and _reload_s > 0.0 else 0.0
	var slot_ok := _slot_ready if (_trigger == Pattern.TRIGGER_LOB_SNAP or _trigger == Pattern.TRIGGER_STAMP) else true
	var ready := _cooldown <= 0.0 and not _reloading and _recover_s <= 0.0 and not _lane_painted and slot_ok
	var safe_cost: float = maxf(_cast_cost, Pattern.MIN_CAST_COST)
	return {
		"weapon": _weapon,
		"trigger": _trigger,
		"ready": ready,
		"cooldown": maxf(_cooldown, 0.0),
		"recover": maxf(_recover_s, 0.0),
		"held": _press_held,
		"hold": _hold_s,
		"buffered": _buffered,
		"chamber": _chamber,
		"mag": _mag,
		"hot": _hot_rounds,
		"hot_pierce": _hot_pierce,
		"reloading": _reloading,
		"reload": reload_frac,
		"reload_t": _reload_t,
		"reload_s": _reload_s,
		"charge": _charge,
		"charging": _charging,
		"charge_armed": _charge_armed,
		"lob_charging": _lob_charging,
		"snap_locked": _snap_hold_lock,
		"snap_token": _snap_token,
		"beat": _beat,
		"window": _window_state,
		"window_open": _window_state == WINDOW_OPEN,
		"window_spent": _window_state == WINDOW_SPENT,
		"window_t": _window_t,
		"window_range": _window_s,
		"painted": _lane_painted,
		"lock_stage": _lock_stage_for(_hold_s) if _lane_painted else "idle",
		"lock_bracket": _lock_bracket_gap() if _lane_painted else 1.0,
		"stamp_streak": _stamp_streak,
		"cast_cost": safe_cost,
		"refund": clampf(_refund, 0.0, safe_cost),
	}


# Current cadence cooldown in seconds (may be negative mid-hold before release clamps it).
func cooldown_s() -> float:
	return _cooldown


# Sets cadence cooldown directly (compatibility path for legacy kit tests).
func set_cooldown_s(seconds: float) -> void:
	_cooldown = seconds


# Charge fill speed multiplier from a SpeedTier (PILOT-CADENCE.md section 3.2).
static func charge_rate_for_tier(tier: int) -> float:
	if tier >= SpeedTier.BLAZING:
		return Weapons.CHARGE_BLAZING_RATE
	if tier >= SpeedTier.FAST:
		return Weapons.CHARGE_FAST_RATE
	return 1.0


# Careless baseline DPS for a pattern (PILOT-CADENCE.md sections 1 and 2.5).
static func base_dps(pattern: Resource) -> float:
	if pattern == null:
		return 0.0
	var dmg: float = float(pattern.damage)
	match String(pattern.trigger):
		Pattern.TRIGGER_PRESS:
			var mag: int = int(pattern.mag)
			var floor_s: float = float(pattern.floor_s)
			var reload_s: float = float(pattern.reload_s)
			if mag > 0 and floor_s > 0.0:
				var cycle: float = float(maxi(mag - 1, 0)) * floor_s + maxf(reload_s, 0.0)
				return (float(mag) * dmg / cycle) if cycle > 0.0 else 0.0
			return (dmg / floor_s) if floor_s > 0.0 else dmg * float(pattern.rate)
		Pattern.TRIGGER_TAP_CHARGE, Pattern.TRIGGER_LOB_SNAP:
			var floor_s: float = float(pattern.floor_s)
			return (dmg / floor_s) if floor_s > 0.0 else dmg * float(pattern.rate)
		Pattern.TRIGGER_BEATS:
			var floors: Array = pattern.beat_floors_s
			var mults: Array = pattern.beat_mults
			var f1: float = float(floors[0]) if floors.size() >= 1 else float(pattern.floor_s)
			var f2: float = float(floors[1]) if floors.size() >= 2 else f1
			var m1: float = float(mults[0]) if mults.size() >= 1 else 1.0
			var m2: float = float(mults[1]) if mults.size() >= 2 else m1
			var cycle: float = f1 + f2
			return (dmg * (m1 + m2) / cycle) if cycle > 0.0 else dmg * float(pattern.rate)
		Pattern.TRIGGER_STAMP:
			var cost: float = maxf(float(pattern.cast_cost), Pattern.MIN_CAST_COST)
			return (dmg / (Weapons.PRESSURE_ROLL_S * cost)) if Weapons.PRESSURE_ROLL_S > 0.0 else 0.0
		Pattern.TRIGGER_LOCK:
			var recover_s: float = float(pattern.recover_s)
			return (dmg / recover_s) if recover_s > 0.0 else dmg * float(pattern.rate)
		_:
			return dmg * float(pattern.rate)


func _step_hold_auto(weapon: String, pattern: Resource, rate_hz: float, pressed: bool, held: bool) -> Array:
	var shots: Array = []
	if rate_hz > 0.0:
		if held and _cooldown <= 0.0 and pattern != null:
			shots.append({"kind": SHOT_PLAIN, "weapon": weapon, "damage_mult": 1.0, "pierce": false, "spread_deg": 0.0})
			_cooldown += 1.0 / rate_hz
	elif pressed and _cooldown <= 0.0 and pattern != null:
		shots.append({"kind": SHOT_PRESS, "weapon": weapon, "damage_mult": 1.0, "pierce": false, "spread_deg": 0.0})
	if not held:
		_cooldown = maxf(_cooldown, 0.0)
	return shots


func _step_press(delta: float, weapon: String, pattern: Resource, pressed: bool, held: bool, context: Dictionary) -> Array:
	var shots: Array = []
	if pressed:
		_hold_s = 0.0
	elif held:
		_hold_s += delta
	else:
		_hold_s = 0.0
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown <= EPS:
		_cooldown = 0.0
	if _recover_s > 0.0:
		_recover_s = maxf(0.0, _recover_s - delta)
		if _recover_s <= EPS:
			_recover_s = 0.0
	if pattern == null:
		return shots
	var rate_mult: float = maxf(float(context.get("rate_mult", 1.0)), 0.1)
	var reload_rate_mult: float = maxf(float(context.get("reload_rate_mult", 1.0)), 0.1)
	var floor_s: float = _floor_s / rate_mult
	var sprinting: bool = bool(context.get("sprinting", false))

	if _reloading:
		_reload_t += delta * reload_rate_mult
		_window_t = _reload_t
		_update_reload_window()
		if pressed:
			if _window_state == WINDOW_OPEN:
				_reloading = false
				_reload_t = 0.0
				_window_t = 0.0
				_window_state = WINDOW_HIT
				_chamber = _mag
				_hot_rounds = _mag
				_hot_pierce = _mag > 0
				_buffered = false
				_buffer_s = 0.0
				shots.append(_fire_press_round(weapon, floor_s, false, rate_mult))
				return shots
			if _window_state == WINDOW_WAITING:
				_window_state = WINDOW_SPENT
			elif _reload_s - _reload_t <= BUFFER_S * reload_rate_mult + EPS:
				_latch_buffer()
		if _reload_t + EPS >= _reload_s:
			_reloading = false
			_reload_t = 0.0
			_window_t = 0.0
			_window_state = WINDOW_IDLE
			_chamber = _mag
			_hot_rounds = 0
			_hot_pierce = false
			_cooldown = 0.0
			if _buffered and _chamber > 0:
				_buffered = false
				_buffer_s = 0.0
				shots.append(_fire_press_round(weapon, floor_s, false, rate_mult))
		return shots

	if pressed:
		if _cooldown <= 0.0 and _loaded():
			_window_state = WINDOW_IDLE
			_buffered = false
			_buffer_s = 0.0
			shots.append(_fire_press_round(weapon, floor_s, false, rate_mult))
			return shots
		if _cooldown > 0.0 and _cooldown <= BUFFER_S + EPS and _loaded():
			_latch_buffer()
			return shots
	elif _buffered and _cooldown <= 0.0 and _loaded():
		_window_state = WINDOW_IDLE
		_buffered = false
		_buffer_s = 0.0
		shots.append(_fire_press_round(weapon, floor_s, false, rate_mult))
		return shots

	# Overdrive Sprint fan: holding fire while sprinting fans remaining rounds at 0.10 s / 0.5x / 5 deg.
	if sprinting and held and not pressed and _cooldown <= 0.0 and _loaded():
		_window_state = WINDOW_IDLE
		shots.append(_fire_press_round(weapon, floor_s, true, rate_mult))
	return shots


# A press weapon with no cylinder (mag 0) never runs dry.
func _loaded() -> bool:
	return _mag <= 0 or _chamber > 0


func _latch_buffer() -> void:
	_buffered = true
	_buffer_s = BUFFER_S
	_buffer_latched = true


func _fire_press_round(weapon: String, floor_s: float, fan: bool, rate_mult: float) -> Dictionary:
	var is_hot := _hot_rounds > 0
	var pierce := is_hot and _hot_rounds == 1 and _hot_pierce
	if _mag > 0:
		_chamber = maxi(0, _chamber - 1)
	if is_hot:
		_hot_rounds -= 1
		if _hot_rounds <= 0:
			_hot_pierce = false
	var mult := _window_mult if is_hot else 1.0
	var spread := 0.0
	var next_floor := floor_s
	var kind := SHOT_HOT if is_hot else SHOT_PLAIN
	if fan:
		mult *= Weapons.RIVET_FAN_DAMAGE
		spread = Weapons.RIVET_FAN_SPREAD_DEG
		next_floor = Weapons.RIVET_FAN_FLOOR_S / rate_mult
		kind = SHOT_FAN
	if _mag > 0 and _chamber <= 0:
		_reloading = true
		_reload_t = 0.0
		_window_t = 0.0
		_window_state = WINDOW_WAITING if _window_s.y > _window_s.x else WINDOW_IDLE
		_cooldown = 0.0
	else:
		_cooldown = next_floor
	return {"kind": kind, "weapon": weapon, "damage_mult": mult, "pierce": pierce, "spread_deg": spread, "hot": is_hot, "fan": fan}


func _update_reload_window() -> void:
	if _window_state == WINDOW_SPENT or _window_state == WINDOW_HIT:
		return
	if _window_s.y <= _window_s.x:
		_window_state = WINDOW_IDLE
		return
	if _reload_t < _window_s.x:
		_window_state = WINDOW_WAITING
	elif _reload_t <= _window_s.y:
		_window_state = WINDOW_OPEN
	else:
		_window_state = WINDOW_SPENT


func _step_tap_charge(delta: float, weapon: String, pattern: Resource, pressed: bool, held: bool, released: bool, context: Dictionary) -> Array:
	var shots: Array = []
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown <= EPS:
		_cooldown = 0.0
	if _recover_s > 0.0:
		_recover_s = maxf(0.0, _recover_s - delta)
		if _recover_s <= EPS:
			_recover_s = 0.0
	if pattern == null:
		return shots
	var rate_mult: float = maxf(float(context.get("rate_mult", 1.0)), 0.1)
	var floor_s: float = _floor_s / rate_mult
	var charge_rate: float = maxf(float(context.get("charge_rate", 1.0)), 0.1)
	var fired_spark := false

	if pressed:
		if _cooldown <= 0.0 and _recover_s <= 0.0:
			shots.append({"kind": SHOT_SPARK, "weapon": weapon, "damage_mult": 1.0, "pierce": false, "spread_deg": 0.0})
			_cooldown = floor_s
			_buffered = false
			_buffer_s = 0.0
			_charge_armed = held
			_hold_s = 0.0
			_charging = false
			_charge = 0.0
			fired_spark = true
		else:
			var wait_s := maxf(_cooldown, _recover_s)
			if wait_s <= BUFFER_S + EPS:
				_latch_buffer()
	elif _buffered and _cooldown <= 0.0 and _recover_s <= 0.0:
		shots.append({"kind": SHOT_SPARK, "weapon": weapon, "damage_mult": 1.0, "pierce": false, "spread_deg": 0.0})
		_cooldown = floor_s
		_buffered = false
		_buffer_s = 0.0
		_charge_armed = held
		_hold_s = 0.0
		_charging = false
		_charge = 0.0
		fired_spark = true

	if _charge_armed:
		if held and not released:
			if not fired_spark:
				_hold_s += delta
				if _hold_s > _tap_threshold_s:
					var fill_dt: float = minf(delta, _hold_s - _tap_threshold_s)
					_charging = true
					if _charge_s > 0.0:
						_charge = minf(1.0, _charge + (fill_dt * charge_rate) / _charge_s)
					else:
						_charge = 1.0
		else:
			if _charging and _charge >= _charge_min:
				var bolt_mult: float = Weapons.charge_bolt_mult(weapon) * _charge
				shots.append({"kind": SHOT_CHARGED, "weapon": weapon, "damage_mult": bolt_mult,
					"pierce": false, "spread_deg": 0.0, "charge": _charge})
				_recover_s = _recover_cfg_s
			_charge_armed = false
			_charging = false
			_charge = 0.0
			_hold_s = 0.0
	elif not held:
		_hold_s = 0.0
	return shots


func _step_lob_snap(delta: float, weapon: String, pattern: Resource, pressed: bool, held: bool, released: bool, context: Dictionary) -> Array:
	var shots: Array = []
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown <= EPS:
		_cooldown = 0.0
	if not held:
		_snap_hold_lock = false
	if pattern == null:
		return shots
	var managed: bool = bool(context.get("managed_gauge", false))
	_slot_ready = bool(context.get("slot_ready", true)) if managed else true
	if managed:
		_lob_charging = bool(context.get("lob_charging", false))
	var rate_mult: float = maxf(float(context.get("rate_mult", 1.0)), 0.1)

	if _window_state == WINDOW_WAITING or _window_state == WINDOW_OPEN:
		_window_t += delta
		if _window_s.y <= _window_s.x:
			_window_state = WINDOW_IDLE
		elif _window_t < _window_s.x:
			_window_state = WINDOW_WAITING
		elif _window_t <= _window_s.y + EPS:
			_window_state = WINDOW_OPEN
		else:
			_window_state = WINDOW_SPENT

	if pressed:
		if _window_state == WINDOW_OPEN:
			_window_state = WINDOW_HIT
			_snap_hold_lock = held
			_lob_charging = false
			_hold_s = 0.0
			_buffered = false
			_buffer_s = 0.0
			shots.append({
				"kind": SHOT_SNAP, "weapon": weapon, "damage_mult": _window_mult,
				"radius_mult": Weapons.STICKY_SNAP_RADIUS_MULT, "knock_mult": Weapons.STICKY_SNAP_KNOCK_MULT,
				"pierce": false, "spread_deg": 0.0, "token": _snap_token,
			})
			return shots
		if _window_state == WINDOW_WAITING:
			_window_state = WINDOW_SPENT

	if managed:
		if pressed and not _lob_charging and _window_state != WINDOW_OPEN and _window_state != WINDOW_WAITING:
			var ready_now: bool = _slot_ready and (_floor_s <= 0.601 or _cooldown <= 0.0)
			if not ready_now and _cooldown > 0.0 and _cooldown <= BUFFER_S + EPS:
				_latch_buffer()
		return shots

	if not _lob_charging:
		var want_start: bool = pressed or _buffered or (held and not _snap_hold_lock)
		if want_start and _cooldown <= 0.0 and not _snap_hold_lock:
			_buffered = false
			_buffer_s = 0.0
			if not held:
				var tok := commit_lob_throw(rate_mult)
				shots.append({"kind": SHOT_THROW, "weapon": weapon, "damage_mult": 1.0,
					"pierce": false, "spread_deg": 0.0, "tail_drop": true, "fraction": 0.0, "token": tok})
				return shots
			_lob_charging = true
			_hold_s = 0.0
		elif pressed and _cooldown > 0.0 and _cooldown <= BUFFER_S + EPS \
				and _window_state != WINDOW_OPEN and _window_state != WINDOW_WAITING:
			_latch_buffer()
		return shots

	if held and not released:
		_hold_s += delta
		if _hold_s < Weapons.STICKY_CHARGE_MAX + 0.5:
			return shots
	var hold_used := _hold_s
	var tail_drop := hold_used < Weapons.STICKY_TAIL_HOLD_S
	var frac := clampf(hold_used / Weapons.STICKY_CHARGE_MAX, 0.0, 1.0)
	var tok := commit_lob_throw(rate_mult)
	shots.append({"kind": SHOT_THROW, "weapon": weapon, "damage_mult": 1.0,
		"pierce": false, "spread_deg": 0.0, "tail_drop": tail_drop, "fraction": frac, "token": tok})
	return shots


func _beat_mult(idx: int) -> float:
	if idx >= 0 and idx < _beat_mults.size():
		return float(_beat_mults[idx])
	return 1.0


func _beat_floor(idx: int, rate_mult: float) -> float:
	var raw := _floor_s
	if idx >= 0 and idx < _beat_floors_s.size():
		raw = float(_beat_floors_s[idx])
	elif not _beat_floors_s.is_empty():
		raw = float(_beat_floors_s[-1])
	return raw / maxf(rate_mult, 0.1)


func _step_beats(delta: float, weapon: String, pattern: Resource, pressed: bool, held: bool, context: Dictionary) -> Array:
	var shots: Array = []
	if pressed:
		_hold_s = 0.0
	elif held:
		_hold_s += delta
	else:
		_hold_s = 0.0
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown <= EPS:
		_cooldown = 0.0
	if _recover_s > 0.0:
		_recover_s = maxf(0.0, _recover_s - delta)
		if _recover_s <= EPS:
			_recover_s = 0.0
	if pattern == null:
		return shots
	var rate_mult: float = maxf(float(context.get("rate_mult", 1.0)), 0.1)
	var planar_speed: float = clampf(float(context.get("planar_speed", 0.0)), 0.0, Weapons.BEAT_SPEED_CAP)
	var floor1 := _beat_floor(0, rate_mult)
	var floor2 := _beat_floor(1, rate_mult)
	var recover := _recover_cfg_s / rate_mult

	if _beat == 1:
		_beat_t += delta
		if _beat_window_s > 0.0 and _beat_t > _beat_window_s + EPS:
			_beat = 0
			_beat_t = 0.0

	if _beat == 2:
		_window_t += delta * rate_mult
		if _window_state != WINDOW_SPENT and _window_state != WINDOW_HIT:
			if _window_s.y <= _window_s.x:
				_window_state = WINDOW_IDLE
			elif _window_t < _window_s.x:
				_window_state = WINDOW_WAITING
			elif _window_t <= _window_s.y + EPS:
				_window_state = WINDOW_OPEN
			else:
				_window_state = WINDOW_SPENT
		if pressed:
			if _window_state == WINDOW_OPEN:
				var mult := _beat_mult(2) + _beat_speed_mult * planar_speed
				_beat = 0
				_beat_t = 0.0
				_cooldown = 0.0
				_recover_s = recover
				_window_state = WINDOW_HIT
				_window_t = 0.0
				_buffered = false
				_buffer_s = 0.0
				shots.append({
					"kind": SHOT_BEAT_3, "weapon": weapon, "beat": 3,
					"damage_mult": mult, "knock_mult": _beat_knock_mult, "range_mult": _beat_range_mult,
					"pierce": false, "spread_deg": 0.0,
				})
				return shots
			if _window_state == WINDOW_WAITING:
				_window_state = WINDOW_SPENT
			elif _cooldown > 0.0 and _cooldown <= BUFFER_S + EPS:
				_latch_buffer()
		if _cooldown <= 0.0:
			_beat = 0
			_beat_t = 0.0
			_window_t = 0.0
			_window_state = WINDOW_IDLE
			if pressed or _buffered:
				_buffered = false
				_buffer_s = 0.0
				_beat = 1
				_beat_t = 0.0
				_cooldown = floor1
				shots.append({
					"kind": SHOT_BEAT_1, "weapon": weapon, "beat": 1,
					"damage_mult": _beat_mult(0), "knock_mult": 1.0, "range_mult": 1.0,
					"pierce": false, "spread_deg": 0.0,
				})
		return shots

	if _beat == 0 and _cooldown <= 0.0 and _recover_s <= 0.0:
		if _window_state == WINDOW_HIT or _window_state == WINDOW_SPENT:
			_window_state = WINDOW_IDLE
	var ready_now := _cooldown <= 0.0 and _recover_s <= 0.0
	if (pressed or _buffered) and ready_now:
		_buffered = false
		_buffer_s = 0.0
		if _beat == 1:
			_beat = 2
			_beat_t = 0.0
			_cooldown = floor2
			_window_t = 0.0
			_window_state = WINDOW_WAITING if _window_s.y > _window_s.x else WINDOW_IDLE
			shots.append({
				"kind": SHOT_BEAT_2, "weapon": weapon, "beat": 2,
				"damage_mult": _beat_mult(1), "knock_mult": 1.0, "range_mult": 1.0,
				"pierce": false, "spread_deg": 0.0,
			})
		else:
			_beat = 1
			_beat_t = 0.0
			_cooldown = floor1
			_window_state = WINDOW_IDLE
			_window_t = 0.0
			shots.append({
				"kind": SHOT_BEAT_1, "weapon": weapon, "beat": 1,
				"damage_mult": _beat_mult(0), "knock_mult": 1.0, "range_mult": 1.0,
				"pierce": false, "spread_deg": 0.0,
			})
		return shots
	if pressed and not ready_now:
		var wait_s := maxf(_cooldown, _recover_s)
		if wait_s <= BUFFER_S + EPS:
			_latch_buffer()
	return shots


func _step_stamp(delta: float, weapon: String, pattern: Resource, pressed: bool, held: bool, context: Dictionary) -> Array:
	var shots: Array = []
	if pressed:
		_hold_s = 0.0
	elif held:
		_hold_s += delta
	else:
		_hold_s = 0.0
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown <= EPS:
		_cooldown = 0.0
	if pattern == null:
		return shots
	var rate_mult: float = maxf(float(context.get("rate_mult", 1.0)), 0.1)
	var managed: bool = bool(context.get("managed_commit", false))
	_slot_ready = bool(context.get("slot_ready", true)) if managed else true

	if _window_state == WINDOW_WAITING or _window_state == WINDOW_OPEN:
		_window_t += delta * rate_mult
		if _window_s.y <= _window_s.x:
			_window_state = WINDOW_IDLE
		elif _window_t + EPS < _window_s.x:
			_window_state = WINDOW_WAITING
		elif _window_t <= _window_s.y + EPS:
			_window_state = WINDOW_OPEN
		else:
			_window_state = WINDOW_SPENT
			_stamp_streak = 0

	if pressed:
		if _window_state == WINDOW_WAITING:
			_window_state = WINDOW_SPENT
			_stamp_streak = 0
			if _cooldown > 0.0:
				if _cooldown <= BUFFER_S + EPS:
					_latch_buffer()
				return shots
			shots.append(_make_stamp_shot(weapon, false, managed, rate_mult))
			return shots
		if _cooldown <= 0.0:
			var is_paid := _window_state == WINDOW_OPEN
			_buffered = false
			_buffer_s = 0.0
			shots.append(_make_stamp_shot(weapon, is_paid, managed, rate_mult))
			return shots
		if _cooldown <= BUFFER_S + EPS:
			_latch_buffer()
		return shots
	if _buffered and _cooldown <= 0.0:
		_buffered = false
		_buffer_s = 0.0
		shots.append(_make_stamp_shot(weapon, false, managed, rate_mult))
	return shots


func _make_stamp_shot(weapon: String, is_paid: bool, managed: bool, rate_mult: float) -> Dictionary:
	var safe_cost: float = maxf(_cast_cost, Pattern.MIN_CAST_COST)
	var safe_refund: float = clampf(_refund, 0.0, safe_cost) if is_paid else 0.0
	var next_streak := (_stamp_streak + 1) if is_paid else 0
	var dmg_mult := _window_mult if is_paid else 1.0
	var bonus := (float(next_streak) * _stamp_streak_bonus) if (is_paid and _stamp_streak_bonus > 0.0) else 0.0
	var cap := _stamp_streak_cap if (is_paid and _stamp_streak_bonus > 0.0) else 0.0
	if not managed:
		commit_stamp(is_paid, rate_mult)
	return {
		"kind": SHOT_STAMP if is_paid else SHOT_PLAIN,
		"weapon": weapon,
		"damage_mult": dmg_mult,
		"paid": is_paid,
		"cast_cost": safe_cost,
		"refund": safe_refund,
		"streak": next_streak,
		"streak_bonus": bonus,
		"streak_cap": cap,
		"pierce": false,
		"spread_deg": 0.0,
	}


func _lock_stage_for(hold_s: float) -> String:
	if _window_s.y <= _window_s.x:
		return SHOT_PULSE
	if hold_s + EPS < _window_s.x:
		return SHOT_PULSE
	if hold_s <= _window_s.y + EPS:
		return SHOT_RAIL
	return SHOT_BARRAGE


func _lock_bracket_gap() -> float:
	if _window_s.y <= _window_s.x:
		return 1.0
	if _hold_s + EPS < _window_s.x:
		return clampf(1.0 - _hold_s / maxf(_window_s.x, 0.001), 0.0, 1.0)
	if _hold_s <= _window_s.y + EPS:
		return 0.0
	return clampf((_hold_s - _window_s.y) / 0.16, 0.25, 1.0)


func _step_lock(delta: float, weapon: String, pattern: Resource, pressed: bool, held: bool, released: bool, context: Dictionary) -> Array:
	var shots: Array = []
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown <= EPS:
		_cooldown = 0.0
	if _recover_s > 0.0:
		_recover_s = maxf(0.0, _recover_s - delta)
		if _recover_s <= EPS:
			_recover_s = 0.0
	if pattern == null:
		return shots
	var rate_mult: float = maxf(float(context.get("rate_mult", 1.0)), 0.1)
	var recover_s: float = _recover_cfg_s / rate_mult

	if not _lane_painted:
		if _recover_s <= 0.0 and _window_state == WINDOW_HIT:
			_window_state = WINDOW_IDLE
		if (pressed or _buffered) and _recover_s <= 0.0:
			_buffered = false
			_buffer_s = 0.0
			_lane_painted = true
			_hold_s = 0.0
			_window_t = 0.0
			_window_state = WINDOW_WAITING if _window_s.y > _window_s.x else WINDOW_IDLE
			if not held or released:
				shots.append(_release_lock(weapon, pattern, recover_s))
			return shots
		if pressed and _recover_s > 0.0 and _recover_s <= BUFFER_S + EPS:
			_latch_buffer()
		return shots

	if held and not released:
		_hold_s += delta
		_window_t = _hold_s
		if _window_s.y <= _window_s.x:
			_window_state = WINDOW_IDLE
		elif _hold_s + EPS < _window_s.x:
			_window_state = WINDOW_WAITING
		elif _hold_s <= _window_s.y + EPS:
			_window_state = WINDOW_OPEN
		else:
			_window_state = WINDOW_SPENT
		return shots

	shots.append(_release_lock(weapon, pattern, recover_s))
	return shots


func _release_lock(weapon: String, pattern: Resource, recover_s: float) -> Dictionary:
	var stage := _lock_stage_for(_hold_s)
	var pulse_dmg: float = maxf(float(pattern.damage), 0.001)
	var rail_dmg: float = _lock_rail_damage if _lock_rail_damage > 0.0 else pulse_dmg
	var barrage_dmg: float = _lock_barrage_damage if _lock_barrage_damage > 0.0 else pulse_dmg
	var pulse_reach: float = _lock_pulse_reach if _lock_pulse_reach > 0.0 else float(pattern.range_m)
	var rail_reach: float = _lock_rail_reach if _lock_rail_reach > 0.0 else float(pattern.range_m)
	var barrage_reach: float = float(pattern.range_m)
	var dmg := pulse_dmg
	var reach := pulse_reach
	var width_mult := _lock_pulse_width_mult
	var pierce := false
	var breaks_props := false
	if stage == SHOT_RAIL:
		dmg = rail_dmg
		reach = rail_reach
		width_mult = _lock_rail_width_mult
		pierce = true
		breaks_props = _lock_rail_breaks_props
	elif stage == SHOT_BARRAGE:
		dmg = barrage_dmg
		reach = barrage_reach
		width_mult = _lock_barrage_width_mult
	_lane_painted = false
	_hold_s = 0.0
	_window_t = 0.0
	_window_state = WINDOW_HIT if stage == SHOT_RAIL else WINDOW_IDLE
	_recover_s = recover_s
	return {
		"kind": stage,
		"weapon": weapon,
		"damage": dmg,
		"damage_mult": dmg / pulse_dmg,
		"reach": reach,
		"width_mult": width_mult,
		"pierce": pierce,
		"breaks_props": breaks_props,
		"spread_deg": 0.0,
	}


func _switch_weapon(weapon: String, pattern: Resource, trigger: String) -> void:
	var trigger_changed := _trigger != trigger
	var stay_hold_auto := _trigger == Pattern.TRIGGER_HOLD_AUTO and trigger == Pattern.TRIGGER_HOLD_AUTO
	var prev_weapon := _weapon
	_weapon = weapon
	_trigger = trigger
	if not stay_hold_auto and (prev_weapon != "" or trigger_changed):
		var mount_swap := not trigger_changed and ((prev_weapon == Weapons.ARC_CASTER and weapon == Weapons.PYLON_TURRET)
			or (prev_weapon == Weapons.PYLON_TURRET and weapon == Weapons.ARC_CASTER))
		var keep_cooldown := _cooldown if (not trigger_changed and (prev_weapon == "" or mount_swap)) else 0.0
		var keep_recover := _recover_s if mount_swap else 0.0
		reset(pattern)
		_cooldown = keep_cooldown
		_recover_s = keep_recover
	elif pattern != null:
		_sync_pattern(pattern, true)


func _sync_pattern(pattern: Resource, reset_chamber := true) -> void:
	_trigger = String(pattern.trigger)
	_mag = int(pattern.mag)
	_floor_s = float(pattern.floor_s)
	_beat_floors_s = pattern.beat_floors_s.duplicate()
	_beat_window_s = float(pattern.beat_window_s)
	_beat_mults = pattern.beat_mults.duplicate()
	_beat_speed_mult = float(pattern.beat_speed_mult)
	_beat_knock_mult = float(pattern.beat_knock_mult)
	_beat_range_mult = float(pattern.beat_range_mult)
	_reload_s = float(pattern.reload_s)
	_window_s = pattern.window_s
	_window_mult = float(pattern.window_mult)
	_charge_s = float(pattern.charge_s)
	_charge_min = float(pattern.charge_min)
	_tap_threshold_s = float(pattern.tap_threshold_s)
	_recover_cfg_s = float(pattern.recover_s)
	_cast_cost = maxf(float(pattern.cast_cost), Pattern.MIN_CAST_COST)
	_refund = clampf(float(pattern.refund), 0.0, minf(Pattern.MAX_REFUND, _cast_cost))
	_stamp_streak_bonus = float(pattern.stamp_streak_bonus)
	_stamp_streak_cap = float(pattern.stamp_streak_cap)
	_lock_rail_damage = float(pattern.lock_rail_damage)
	_lock_barrage_damage = float(pattern.lock_barrage_damage)
	_lock_pulse_reach = float(pattern.lock_pulse_reach)
	_lock_rail_reach = float(pattern.lock_rail_reach)
	_lock_pulse_width_mult = float(pattern.lock_pulse_width_mult)
	_lock_rail_width_mult = float(pattern.lock_rail_width_mult)
	_lock_barrage_width_mult = float(pattern.lock_barrage_width_mult)
	_lock_rail_breaks_props = bool(pattern.lock_rail_breaks_props)
	if reset_chamber:
		_chamber = _mag
		_hot_rounds = 0
		_hot_pierce = false
		return
	if _mag <= 0:
		_chamber = 0
		_hot_rounds = 0
		_hot_pierce = false
		_reloading = false
		_reload_t = 0.0
		if _trigger == Pattern.TRIGGER_PRESS:
			_window_state = WINDOW_IDLE
	else:
		_chamber = mini(_chamber, _mag)
		_hot_rounds = mini(_hot_rounds, _chamber)
		if _hot_rounds <= 0:
			_hot_pierce = false
		if _reloading:
			_update_reload_window()
