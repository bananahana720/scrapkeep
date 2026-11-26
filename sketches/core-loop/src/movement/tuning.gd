extends RefCounted

const BallState := preload("res://src/movement/ball_state.gd")

const SPECS := [
	{"key": "drive_accel", "label": "Drive accel", "min": 5.0, "max": 90.0, "step": 1.0, "value": 34.0},
	{"key": "cruise", "label": "Cruise speed", "min": 4.0, "max": 40.0, "step": 0.5, "value": 14.0},
	{"key": "air_control", "label": "Air control", "min": 0.0, "max": 1.0, "step": 0.01, "value": 0.25},
	{"key": "gravity", "label": "Gravity", "min": 5.0, "max": 60.0, "step": 0.5, "value": 26.0},
	{"key": "jump_speed", "label": "Jump speed", "min": 4.0, "max": 30.0, "step": 0.5, "value": 13.0},
	{"key": "restitution", "label": "Restitution", "min": 0.0, "max": 0.95, "step": 0.01, "value": 0.35},
	{"key": "rolling_resistance", "label": "Rolling resist", "min": 0.0, "max": 3.0, "step": 0.05, "value": 0.30},
	{"key": "rigid_torque", "label": "Rigid torque", "min": 10.0, "max": 600.0, "step": 10.0, "value": 220.0},
	{"key": "dash_impulse", "label": "Blink speed floor", "min": 4.0, "max": 40.0, "step": 0.5, "value": 16.0},
	{"key": "glide_gravity", "label": "Glide gravity", "min": 0.05, "max": 1.0, "step": 0.01, "value": 0.30},
	{"key": "glide_lift", "label": "Glide lift", "min": 0.0, "max": 4.0, "step": 0.05, "value": 1.30},
	{"key": "rope_range", "label": "Rope range", "min": 10.0, "max": 60.0, "step": 1.0, "value": 45.0},
	{"key": "rope_spring", "label": "Rope spring", "min": 1.0, "max": 30.0, "step": 0.5, "value": 12.0},
	{"key": "grapple_assist_deg", "label": "Grapple assist (deg)", "min": 0.0, "max": 12.0, "step": 0.5, "value": 4.0},
	{"key": "reel_force", "label": "Winch pull", "min": 5.0, "max": 120.0, "step": 1.0, "value": 45.0},
	{"key": "reel_speed", "label": "Winch top speed", "min": 2.0, "max": 40.0, "step": 0.5, "value": 16.0},
	{"key": "slam_speed", "label": "Slam speed", "min": 10.0, "max": 80.0, "step": 1.0, "value": 42.0},
	{"key": "slam_anchor_max", "label": "Slam anchor (s)", "min": 0.0, "max": 1.0, "step": 0.02, "value": 0.30},
	{"key": "slam_flat_exp", "label": "Slam flatness exp", "min": 0.5, "max": 12.0, "step": 0.5, "value": 4.0},
	{"key": "slam_downhill", "label": "Slam downhill", "min": 0.0, "max": 1.5, "step": 0.05, "value": 0.50},
	{"key": "slingshot_keep", "label": "Slingshot keep", "min": 0.0, "max": 1.5, "step": 0.05, "value": 0.85},
	{"key": "slingshot_boost", "label": "Slingshot boost", "min": 0.0, "max": 20.0, "step": 0.5, "value": 6.0},
	{"key": "legacy_spin_probe", "label": "Legacy spin probe (v2)", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "toggle": true},
	{"key": "scrap_mode", "label": "Scrap mode", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["off", "armor"]},
	{"key": "wear", "label": "Scrap wear", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["off", "on"]},
	{"key": "start_mass", "label": "Start mass", "min": 0.0, "max": 3000.0, "step": 10.0, "value": 0.0},
	{"key": "route_seed", "label": "Route seed (0 = off)", "min": 0.0, "max": 999999.0, "step": 1.0, "value": 0.0},
	{"key": "music", "label": "Music", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["synth", "ace"]},
	{"key": "breath", "label": "Breath", "min": 0.0, "max": 2.0, "step": 1.0, "value": 1.0, "options": ["raw", "hard", "gentle"]},
	{"key": "warden_form", "label": "Warden form", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["loop", "form"]},
	{"key": "drop_room", "label": "Drop room", "min": 0.0, "max": 2.0, "step": 1.0, "value": 0.0, "options": ["off", "duck", "lift"]},
	{"key": "set_director", "label": "Set director", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "deck", "label": "Deck", "min": 0.0, "max": 2.0, "step": 1.0, "value": 0.0, "options": ["off", "festival", "viking"]},
	{"key": "discovery", "label": "Discovery", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["banner", "cards"]},
	{"key": "telegraph", "label": "Telegraph", "min": 0.0, "max": 4.0, "step": 1.0, "value": 2.0, "options": ["classic", "haze", "clear", "edges", "tape"]},
	{"key": "ball_look", "label": "Ball look", "min": 0.0, "max": 3.0, "step": 1.0, "value": 3.0, "options": ["today", "gyro", "bell", "cutaway"]},
	{"key": "world_one_builds", "label": "World-one builds", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["off", "on"]},
	{"key": "pole_flail", "label": "Poles and flails", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "hotwire_shell", "label": "Hot-wired shell", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["off", "on"]},
	{"key": "hotwire_tread", "label": "Hot-wired tread", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["off", "on"]},
	{"key": "heat", "label": "Heat", "min": 0.0, "max": 2.0, "step": 1.0, "value": 0.0, "options": ["off", "watch", "on"]},
	{"key": "overtime", "label": "Overtime", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "called_shot", "label": "Called shot", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "stocktake", "label": "Stocktake", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "posts", "label": "Survey posts", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "approach", "label": "Bowl approach", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "harpoon_smash_speed", "label": "Harpoon smash speed", "min": 10.0, "max": 45.0, "step": 1.0, "value": 24.0},
	{"key": "harpoon_lock_deg", "label": "Harpoon lock (deg)", "min": 0.0, "max": 25.0, "step": 0.5, "value": 10.0},
	{"key": "companion_stub", "label": "Companion stub pieces", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "actives", "label": "Active slot", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["off", "on"]},
	{"key": "profile", "label": "Launch set", "min": 0.0, "max": 2.0, "step": 1.0, "value": 0.0, "options": ["default", "sitting", "sitting-earned"]},
	{"key": "harpoon_rewind", "label": "Harpoon rewind (s)", "min": 0.0, "max": 3.0, "step": 0.1, "value": 1.0},
	{"key": "grip", "label": "Wall grip", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["off", "on"]},
	{"key": "marked_hull", "label": "Marked hull", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "moss_scale", "label": "Moss's scale", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "carry_core", "label": "Carry a core", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "shot_bits_live", "label": "Live shot bits", "min": 0.0, "max": 31.0, "step": 1.0, "value": 31.0},
	{"key": "final_world", "label": "Run ends after", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["last", "1"]},
]

const MUSIC_KEY := "music"
const BREATH_KEY := "breath"
const WARDEN_FORM_KEY := "warden_form"
const DROP_ROOM_KEY := "drop_room"
const SET_DIRECTOR_KEY := "set_director"
const DECK_KEY := "deck"
const DISCOVERY_KEY := "discovery"
const TELEGRAPH_KEY := "telegraph"
const BALL_LOOK_KEY := "ball_look"

const BRAKE_RESISTANCE := 4.0
const BRAKE_TURN_BOOST := 2.2
const BOOST_IMPULSE := 11.0
const BOOST_COOLDOWN := 1.1
const BOOST_COOLDOWN_FLOOR := 0.15
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.14
const BOOST_BUFFER := JUMP_BUFFER
const ACTION_BUFFER_S := 0.12
const SLAM_BUFFER_S := 0.10
const MAX_SLOPE_DOT := 0.45
const STICK_ACCEL := 22.0
const STICK_SPEED := 18.0
const QUAD_DRAG := 0.0045
const RADIUS := 1.0
const ANCHOR_MIN_ROPE := 6.0
const SKIN := 0.12
const GRIP_SLOPE_DOT := -0.2
const GRIP_PEEL_S := 0.25
const GRIP_DOWNFORCE := 0.6
const GRIP_FORCE_FROM := 0.707
const CARVE_DOT := 0.906

const BANK_ARM := 0.9
const BANK_REST := 0.2
const BANK_WINDOW := 0.25
const BANK_DEFAULT := {"ratio": 1.25, "decay_s": 1.2, "hold": 0.0, "exp": 1.0}
const BANK_ROWS := {
	"pylon_engineer": {"ratio": 1.25, "decay_s": 1.2, "hold": 0.0, "exp": 1.0},
	"runner_gunner": {"ratio": 1.22, "decay_s": 1.6, "hold": 0.35, "exp": 2.0},
	"demolitions_caster": {"ratio": 1.29, "decay_s": 0.8, "hold": 0.0, "exp": 0.5},
	"tarn": {"ratio": 1.24, "decay_s": 1.0, "hold": 0.15, "exp": 3.0},
	"tally": {"ratio": 1.21, "decay_s": 1.4, "hold": 0.0, "exp": 1.6},
	"remembered_cannon": {"ratio": 1.28, "decay_s": 1.1, "hold": 0.5, "exp": 1.0},
}


static func bank_row(class_id: String) -> Dictionary:
	return BANK_ROWS.get(class_id, BANK_DEFAULT)


static func bank_share(row: Dictionary, u: float) -> float:
	var hold: float = row["hold"]
	if u <= hold:
		return 1.0
	if u >= 1.0:
		return 0.0
	return pow((1.0 - u) / (1.0 - hold), float(row["exp"]))

var _values := {}
var _mods := {}
var _adds := {}
var boost_cooldown_scale := 1.0
var _launch := {}


func _init() -> void:
	assert(is_equal_approx(MAX_SLOPE_DOT, BallState.MAX_SLOPE_DOT), "Tuning.MAX_SLOPE_DOT must match BallState.MAX_SLOPE_DOT")
	reset()
	apply_cmdline("start")


const FLAGS := {
	"scrap": ["scrap_mode", "option", "start"],
	"wear": ["wear", "option", "start"],
	"route-seed": ["route_seed", "number", "start"],
	"start-mass": ["start_mass", "number", "start"],
	"music": ["music", "option", "launch"],
	"breath": ["breath", "option", "launch"],
	"warden-form": ["warden_form", "option", "launch"],
	"drop-room": ["drop_room", "option", "launch"],
	"set-director": ["set_director", "option", "launch"],
	"deck": ["deck", "option", "launch"],
	"discovery": ["discovery", "option", "launch"],
	"telegraph": ["telegraph", "option", "launch"],
	"ball-look": ["ball_look", "option", "launch"],
	"world-one-builds": ["world_one_builds", "option", "launch"],
	"pole-flail": ["pole_flail", "option", "launch"],
	"hotwire-shell": ["hotwire_shell", "option", "launch"],
	"hotwire-tread": ["hotwire_tread", "option", "launch"],
	"heat": ["heat", "option", "launch"],
	"companion-stub": ["companion_stub", "option", "launch"],
	"actives": ["actives", "option", "launch"],
	"profile": ["profile", "option", "launch"],
	"grip": ["grip", "option", "launch"],
	"marked-hull": ["marked_hull", "option", "launch"],
	"moss-scale": ["moss_scale", "option", "launch"],
	"carry-core": ["carry_core", "option", "launch"],
	"overtime": ["overtime", "option", "launch"],
	"called-shot": ["called_shot", "option", "launch"],
	"stocktake": ["stocktake", "option", "launch"],
	"posts": ["posts", "option", "launch"],
	"approach": ["approach", "option", "launch"],
	"final-world": ["final_world", "option", "launch"],
}


const SITTING_SET := {"heat": "on", "overtime": "on", "called-shot": "on", "marked-hull": "on", "moss-scale": "on",
	"carry-core": "on", "final-world": "1"}


func apply_args(args: PackedStringArray, when := "") -> Dictionary:
	var applied := {}
	for arg in args:
		if not arg.begins_with("--") or not "=" in arg:
			continue
		var flag := arg.substr(2, arg.find("=") - 2)
		if not FLAGS.has(flag):
			continue
		var row: Array = FLAGS[flag]
		if when != "" and row[2] != when:
			continue
		var value := arg.substr(arg.find("=") + 1)
		if row[1] == "option":
			if set_option(row[0], value):
				_launch[row[0]] = _values[row[0]]
				applied[flag] = value
			else:
				push_warning("tuning: unknown --%s=%s" % [flag, value])
		elif value.is_valid_float():
			set_value(row[0], float(value))
			_launch[row[0]] = _values[row[0]]
			applied[flag] = value
	if applied.get("profile") in ["sitting", "sitting-earned"]:
		for flag in SITTING_SET:
			if not applied.has(flag) and set_option(FLAGS[flag][0], SITTING_SET[flag]):
				_launch[FLAGS[flag][0]] = _values[FLAGS[flag][0]]
	return applied


func apply_cmdline(when := "") -> Dictionary:
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	return apply_args(args, when)


func sitting() -> bool:
	return option("profile") == "sitting"


func sitting_earned() -> bool:
	return option("profile") == "sitting-earned"


func final_world() -> int:
	var value := option("final_world")
	return int(value) if value.is_valid_int() else 0


const FULL_ALPHA_UNLOCKED := true


func end_players_run_at_world_one(applied: Dictionary) -> void:
	if not applied.has("final-world") and set_option("final_world", "1"):
		_launch["final_world"] = _values["final_world"]


func world_one() -> bool:
	return option("world_one_builds") == "on"


func pole_flail() -> bool:
	return option("pole_flail") == "on"


func grip_on() -> bool:
	return option("grip") == "on"


func armor() -> bool:
	return option("scrap_mode") == "armor"


func wear_on() -> bool:
	return armor() and option("wear") == "on"


func f(key: String) -> float:
	return _values[key] * _mods.get(key, 1.0)


func base(key: String) -> float:
	return _values[key]


func tier_cruise() -> float:
	return base("cruise")


func set_mod(key: String, multiplier: float) -> void:
	_mods[key] = multiplier


func mod(key: String) -> float:
	return _mods.get(key, 1.0)


func clear_mods() -> void:
	_mods.clear()
	_adds.clear()
	boost_cooldown_scale = 1.0


func set_add(key: String, amount: float) -> void:
	_adds[key] = amount


func add(key: String) -> float:
	return _adds.get(key, 0.0)


func harpoon_rewind() -> float:
	return f("harpoon_rewind") / maxf(mod("harpoon_recovery"), 0.001)


func boost_cooldown() -> float:
	return maxf(BOOST_COOLDOWN * boost_cooldown_scale, BOOST_COOLDOWN_FLOOR)


func set_value(key: String, value: float) -> void:
	for spec in SPECS:
		if spec["key"] == key:
			_values[key] = clampf(value, spec["min"], spec["max"])
			return


func on(key: String) -> bool:
	return _values[key] >= 0.5


func options_of(key: String) -> Array:
	for spec in SPECS:
		if spec["key"] == key:
			return spec.get("options", [])
	return []


func option(key: String) -> String:
	var options := options_of(key)
	return String(options[clampi(roundi(_values[key]), 0, options.size() - 1)]) if not options.is_empty() else ""


func set_option(key: String, name: String) -> bool:
	var index := options_of(key).find(name)
	if index < 0:
		return false
	set_value(key, float(index))
	return true


func reset() -> void:
	for spec in SPECS:
		_values[spec["key"]] = spec["value"]
	for key in _launch:
		_values[key] = _launch[key]
