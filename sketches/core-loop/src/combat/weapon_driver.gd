extends RefCounted

const Pattern := preload("res://src/combat/pattern.gd")

# Weapon trigger and cadence driver (PILOT-CADENCE.md sections 2, 4 and 7).
# Owned by Combat, one instance per Combat with no static state, so warm-batched tests need
# no reset. Combat calls step() once per physics tick and lifecycle hooks on attempt
# boundaries and interruptions; the reticle, sound twins and tests read state_snapshot().
# Procs never call into this module.

# One-press input buffer (PILOT-CADENCE.md section 2.2): a press inside BUFFER_S before ready
# acts the instant the trigger is ready.
const BUFFER_S := 0.10

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

var _weapon := ""
var _trigger: String = Pattern.DEFAULT_TRIGGER
var _cooldown := 0.0
var _recover_s := 0.0
var _press_held := false
var _hold_s := 0.0
var _buffered := false
var _buffer_s := 0.0
var _chamber := 0
var _mag := 0
var _hot_rounds := 0
var _reloading := false
var _reload_t := 0.0
var _reload_s := 0.0
var _charge := 0.0
var _charging := false
var _beat := 0
var _beat_t := 0.0
var _window_state := WINDOW_IDLE
var _window_t := 0.0
var _window_s := Vector2.ZERO
var _lane_painted := false


# Advances trigger timers by `delta` and interprets `intent` for `weapon` under `pattern`.
# Returns an array of shot descriptors ({kind, weapon, damage_mult, pierce}) to fire this tick.
# When `rate_hz` is positive, sustained hold fires at `rate_hz` in `hold_auto`; when zero
# (tap/card weapons such as Tally, or lob weapons handled by a gauge), a fresh press emits
# a press descriptor only when cooldown is ready and leaves recovery to commit_recovery().
func step(delta: float, intent, weapon: String, pattern: Resource, rate_hz: float) -> Array:
	var trigger: String = String(pattern.trigger) if pattern != null else Pattern.DEFAULT_TRIGGER
	if _weapon != weapon or _trigger != trigger:
		_switch_weapon(weapon, pattern, trigger)
	var held: bool = bool(intent.fire_held) if intent != null else false
	var pressed: bool = bool(intent.fire_pressed) if intent != null else false
	_press_held = held
	if pressed:
		_hold_s = 0.0
	elif held:
		_hold_s += delta
	else:
		_hold_s = 0.0
	_cooldown -= delta
	if _recover_s > 0.0:
		_recover_s = maxf(0.0, _recover_s - delta)
	if _buffered:
		_buffer_s -= delta
		if _buffer_s <= 0.0:
			_buffered = false
			_buffer_s = 0.0
	# E1-01 routes all pilots in hold_auto; pilot-specific cadence modes land in E1-02..E1-07
	# and safely fall back to hold_auto here until wired.
	return _step_hold_auto(weapon, pattern, rate_hz, pressed, held)


# Charges a flat recovery floor after a tap/card weapon commits a cast.
func commit_recovery(seconds: float) -> void:
	_cooldown = maxf(_cooldown, 0.0) + maxf(seconds, 0.0)


# Returns the driver to rest (PILOT-CADENCE.md section 2.2): zero cooldown, full plain
# chamber, no charge, beat zero, no window open, no painted lane.
func reset(pattern: Resource = null) -> void:
	_cooldown = 0.0
	_recover_s = 0.0
	_press_held = false
	_hold_s = 0.0
	_buffered = false
	_buffer_s = 0.0
	_hot_rounds = 0
	_reloading = false
	_reload_t = 0.0
	_charge = 0.0
	_charging = false
	_beat = 0
	_beat_t = 0.0
	_window_state = WINDOW_IDLE
	_window_t = 0.0
	_lane_painted = false
	if pattern != null:
		_sync_pattern(pattern)
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
			_lane_painted = false
			_buffered = false
			_buffer_s = 0.0
			if _window_state == WINDOW_WAITING or _window_state == WINDOW_OPEN:
				_window_state = WINDOW_SPENT
		INTERRUPT_MOUNT:
			_charge = 0.0
			_charging = false
			_buffered = false
			_buffer_s = 0.0


# Read-only snapshot for the aim reticle, sound twins and tests. Mutating the returned
# dictionary never alters internal state.
func state_snapshot() -> Dictionary:
	var reload_frac := clampf(_reload_t / _reload_s, 0.0, 1.0) if _reloading and _reload_s > 0.0 else 0.0
	var ready := _cooldown <= 0.0 and not _reloading and _recover_s <= 0.0
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
		"reloading": _reloading,
		"reload": reload_frac,
		"charge": _charge,
		"charging": _charging,
		"beat": _beat,
		"window": _window_state,
		"window_open": _window_state == WINDOW_OPEN,
		"window_spent": _window_state == WINDOW_SPENT,
		"window_t": _window_t,
		"window_range": _window_s,
		"painted": _lane_painted,
	}


# Current cadence cooldown in seconds (may be negative mid-hold before release clamps it).
func cooldown_s() -> float:
	return _cooldown


# Sets cadence cooldown directly (compatibility path for legacy kit tests).
func set_cooldown_s(seconds: float) -> void:
	_cooldown = seconds


# Careless baseline DPS for a pattern (PILOT-CADENCE.md section 2.5).
static func base_dps(pattern: Resource) -> float:
	if pattern == null:
		return 0.0
	return float(pattern.damage) * float(pattern.rate)


func _step_hold_auto(weapon: String, pattern: Resource, rate_hz: float, pressed: bool, held: bool) -> Array:
	var shots: Array = []
	if rate_hz > 0.0:
		if held and _cooldown <= 0.0 and pattern != null:
			shots.append({"kind": SHOT_PLAIN, "weapon": weapon, "damage_mult": 1.0, "pierce": false})
			_cooldown += 1.0 / rate_hz
	elif pressed and _cooldown <= 0.0 and pattern != null:
		shots.append({"kind": SHOT_PRESS, "weapon": weapon, "damage_mult": 1.0, "pierce": false})
	if not held:
		_cooldown = maxf(_cooldown, 0.0)
	return shots


func _switch_weapon(weapon: String, pattern: Resource, trigger: String) -> void:
	var trigger_changed := _trigger != trigger
	var stay_hold_auto := _trigger == Pattern.TRIGGER_HOLD_AUTO and trigger == Pattern.TRIGGER_HOLD_AUTO
	_weapon = weapon
	_trigger = trigger
	if not stay_hold_auto and (_weapon != "" or trigger_changed):
		var keep_cooldown := _cooldown if not trigger_changed else 0.0
		reset(pattern)
		_cooldown = keep_cooldown
	elif pattern != null:
		_sync_pattern(pattern)


func _sync_pattern(pattern: Resource) -> void:
	_trigger = String(pattern.trigger)
	_mag = int(pattern.mag)
	_chamber = _mag
	_reload_s = float(pattern.reload_s)
	_window_s = pattern.window_s
