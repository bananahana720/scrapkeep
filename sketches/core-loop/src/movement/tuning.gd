extends RefCounted

# One table drives the defaults, the tuning panel rows and the clamping, so a new
# knob is one row here and nothing else.
const SPECS := [
	{"key": "drive_accel", "label": "Drive accel", "min": 5.0, "max": 90.0, "step": 1.0, "value": 34.0},
	{"key": "cruise", "label": "Cruise speed", "min": 4.0, "max": 40.0, "step": 0.5, "value": 14.0},
	{"key": "air_control", "label": "Air control", "min": 0.0, "max": 1.0, "step": 0.01, "value": 0.25},
	{"key": "gravity", "label": "Gravity", "min": 5.0, "max": 60.0, "step": 0.5, "value": 26.0},
	{"key": "jump_speed", "label": "Jump speed", "min": 4.0, "max": 30.0, "step": 0.5, "value": 13.0},
	{"key": "restitution", "label": "Restitution", "min": 0.0, "max": 0.95, "step": 0.01, "value": 0.35},
	{"key": "rolling_resistance", "label": "Rolling resist", "min": 0.0, "max": 3.0, "step": 0.05, "value": 0.30},
	{"key": "rigid_torque", "label": "Rigid torque", "min": 10.0, "max": 600.0, "step": 10.0, "value": 220.0},
	# Kest's blink leaves at least this speed; Dash Vane scales it and the blink's reach.
	{"key": "dash_impulse", "label": "Blink speed floor", "min": 4.0, "max": 40.0, "step": 0.5, "value": 16.0},
	{"key": "glide_gravity", "label": "Glide gravity", "min": 0.05, "max": 1.0, "step": 0.01, "value": 0.30},
	{"key": "glide_lift", "label": "Glide lift", "min": 0.0, "max": 4.0, "step": 0.05, "value": 1.30},
	{"key": "rope_range", "label": "Rope range", "min": 10.0, "max": 60.0, "step": 1.0, "value": 45.0},
	{"key": "rope_spring", "label": "Rope spring", "min": 1.0, "max": 30.0, "step": 0.5, "value": 12.0},
	{"key": "grapple_assist_deg", "label": "Grapple assist (deg)", "min": 0.0, "max": 12.0, "step": 0.5, "value": 4.0},
	# The winch is an acceleration toward the hook that fades out as the haul reaches
	# its top speed, so holding Q draws you in rather than snapping you there.
	{"key": "reel_force", "label": "Winch pull", "min": 5.0, "max": 120.0, "step": 1.0, "value": 45.0},
	{"key": "reel_speed", "label": "Winch top speed", "min": 2.0, "max": 40.0, "step": 0.5, "value": 16.0},
	{"key": "slam_speed", "label": "Slam speed", "min": 10.0, "max": 80.0, "step": 1.0, "value": 42.0},
	{"key": "slam_anchor_max", "label": "Slam anchor (s)", "min": 0.0, "max": 1.0, "step": 0.02, "value": 0.30},
	{"key": "slam_flat_exp", "label": "Slam flatness exp", "min": 0.5, "max": 12.0, "step": 0.5, "value": 4.0},
	{"key": "slam_downhill", "label": "Slam downhill", "min": 0.0, "max": 1.5, "step": 0.05, "value": 0.50},
	# The pylon banks the speed you plant with and pays it back on a Space eject along
	# the face: keep is the fraction returned, boost is added on top.
	{"key": "slingshot_keep", "label": "Slingshot keep", "min": 0.0, "max": 1.5, "step": 0.05, "value": 0.85},
	{"key": "slingshot_boost", "label": "Slingshot boost", "min": 0.0, "max": 20.0, "step": 0.5, "value": 6.0},
	# v2's ground probe turned with the ball, so "grounded" flickered with the spin.
	# Off is the fix; on brings the v2 feel back for a side-by-side comparison.
	{"key": "legacy_spin_probe", "label": "Legacy spin probe (v2)", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "toggle": true},
	# v3 spike S2 (LOOP-REDESIGN section 8): a ripe part plus its pair evolves at the
	# Warden break. Off leaves the build exactly as it was.
	{"key": "evolutions", "label": "Evolutions (v3 spike)", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "toggle": true},
]

const BRAKE_RESISTANCE := 4.0
const BRAKE_TURN_BOOST := 2.2
const BOOST_IMPULSE := 11.0
const BOOST_COOLDOWN := 1.1
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.14
const MAX_SLOPE_DOT := 0.45
const STICK_ACCEL := 22.0
const STICK_SPEED := 18.0
const QUAD_DRAG := 0.0045
const RADIUS := 1.0
const SKIN := 0.12

var _values := {}
# Parts scale knobs through mods rather than by moving the sliders, so the F1 panel
# keeps showing the base value and a recompute from the part list is idempotent.
var _mods := {}
# Parts shorten the shared boost cooldown; a constant, not a slider row.
var boost_cooldown_scale := 1.0


func _init() -> void:
	reset()


func f(key: String) -> float:
	return _values[key] * _mods.get(key, 1.0)


func base(key: String) -> float:
	return _values[key]


func set_mod(key: String, multiplier: float) -> void:
	_mods[key] = multiplier


func mod(key: String) -> float:
	return _mods.get(key, 1.0)


func clear_mods() -> void:
	_mods.clear()
	boost_cooldown_scale = 1.0


func boost_cooldown() -> float:
	return BOOST_COOLDOWN * boost_cooldown_scale


func set_value(key: String, value: float) -> void:
	for spec in SPECS:
		if spec["key"] == key:
			_values[key] = clampf(value, spec["min"], spec["max"])
			return


func on(key: String) -> bool:
	return _values[key] >= 0.5


func reset() -> void:
	for spec in SPECS:
		_values[spec["key"]] = spec["value"]
