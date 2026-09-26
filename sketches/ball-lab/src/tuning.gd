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


func _init() -> void:
	reset()


func f(key: String) -> float:
	return _values[key]


func set_value(key: String, value: float) -> void:
	for spec in SPECS:
		if spec["key"] == key:
			_values[key] = clampf(value, spec["min"], spec["max"])
			return


func nudge(key: String, direction: float) -> void:
	for spec in SPECS:
		if spec["key"] == key:
			set_value(key, _values[key] + spec["step"] * direction * 4.0)
			return


func reset() -> void:
	for spec in SPECS:
		_values[spec["key"]] = spec["value"]
