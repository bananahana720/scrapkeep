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
	# The v3 fun lab's switch (src/core/loop_mode.gd): an option row stores its index.
	{"key": "loop_mode", "label": "Loop mode", "min": 0.0, "max": 2.0, "step": 1.0, "value": 0.0, "options": ["v2", "drop", "laps"]},
	# The durability prototype (DESIGN-NOTES, "Scrap as armour"): `--scrap=armor` makes mass a
	# temporary health layer over the hull, `--wear=on` lets rolling friction wear it. Both
	# default off, and off is the base game. `--route-seed=<n>` reseeds the run's streams and
	# `--start-mass=<n>` opens the run with that mass, so the three variants share a route.
	{"key": "scrap_mode", "label": "Scrap mode", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "armor"]},
	{"key": "wear", "label": "Scrap wear", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "start_mass", "label": "Start mass", "min": 0.0, "max": 3000.0, "step": 10.0, "value": 0.0},
	{"key": "route_seed", "label": "Route seed (0 = off)", "min": 0.0, "max": 999999.0, "step": 1.0, "value": 0.0},
	{"key": "gun_role", "label": "Gun role", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["hold", "full"]},
	# The music lab: the synth band, or the ACE takes on stage 1 (presentation/ace_sequencer.gd),
	# and the Warden open's held breath in the ACE music.
	{"key": "music", "label": "Music", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["synth", "ace"]},
	{"key": "breath", "label": "Breath", "min": 0.0, "max": 2.0, "step": 1.0, "value": 1.0, "options": ["raw", "hard", "gentle"]},
	{"key": "discovery", "label": "Discovery", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["banner", "cards"]},
	{"key": "telegraph", "label": "Telegraph", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["classic", "haze"]},
	# World-one builds (design-v3/research/build-systems/BUILD-SYSTEMS.md, unit G): the master
	# flag gives every pilot a two-depth tree, and the two hot-wired parts are selectable
	# alone. The hot-wired flags are registered here; their effects belong to later units.
	{"key": "world_one_builds", "label": "World-one builds", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "hotwire_shell", "label": "Hot-wired shell", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "hotwire_tread", "label": "Hot-wired tread", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	# The harpoon feel prototype (DESIGN-NOTES, "Harpoon and winch"): RMB fires a line for every pilot.
	# `shot` hits what the centre ray hits; `lock` prefers an enemy inside harpoon_lock_deg. `self` always
	# flies you in; `heft` splits the closing by weight against heft. `shift` puts the class burst on
	# Shift when its charge is ready, `keep` moves it to C. Off is the base game.
	{"key": "harpoon", "label": "Harpoon", "min": 0.0, "max": 2.0, "step": 1.0, "value": 0.0, "options": ["off", "shot", "lock"]},
	{"key": "harpoon_pull", "label": "Harpoon pull", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["self", "heft"]},
	{"key": "harpoon_keys", "label": "Harpoon keys", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["shift", "keep"]},
	{"key": "harpoon_smash_speed", "label": "Harpoon smash speed", "min": 10.0, "max": 45.0, "step": 1.0, "value": 24.0},
	{"key": "harpoon_lock_deg", "label": "Harpoon lock (deg)", "min": 0.0, "max": 25.0, "step": 0.5, "value": 10.0},
	{"key": "harpoon_rewind", "label": "Harpoon rewind (s)", "min": 0.0, "max": 3.0, "step": 0.1, "value": 1.0},
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
	apply_cmdline("start")


# Every launch flag, one table and one parse pass. name -> [tuning key, kind, when]:
#   kind  "option" names one of the row's options; an unknown value warns and is refused
#         "number" takes any float (clamped by the row); a non-number is ignored quietly
#   when  "start" flags apply as Tuning is built (the durability flags, so every Tuning
#         reads them); "launch" flags apply when game.gd calls apply_cmdline("launch"),
#         so a bot or tool that builds a bare Tuning never sees them.
# `--scrap=armor --wear=on --route-seed=7 --start-mass=200 --loop=drop --gun=full
# --music=ace --breath=gentle --discovery=cards --telegraph=haze --world-one-builds=on
# --hotwire-shell=on --hotwire-tread=on --harpoon=lock --harpoon-pull=heft --harpoon-keys=keep`, from the engine args
# or the user args (after Godot's `--`). A flag in neither table is ignored.
# threat_grammar.gd's Painter.haze_on() reads --telegraph from the launch args itself,
# since the static-drawn floor marking has no tuning in reach; tuning_flags_test checks
# that its name is a row here.
const FLAGS := {
	"scrap": ["scrap_mode", "option", "start"],
	"wear": ["wear", "option", "start"],
	"route-seed": ["route_seed", "number", "start"],
	"start-mass": ["start_mass", "number", "start"],
	"loop": ["loop_mode", "option", "launch"],
	"gun": ["gun_role", "option", "launch"],
	"music": ["music", "option", "launch"],
	"breath": ["breath", "option", "launch"],
	"discovery": ["discovery", "option", "launch"],
	"telegraph": ["telegraph", "option", "launch"],
	"world-one-builds": ["world_one_builds", "option", "launch"],
	"hotwire-shell": ["hotwire_shell", "option", "launch"],
	"hotwire-tread": ["hotwire_tread", "option", "launch"],
	"harpoon": ["harpoon", "option", "launch"],
	"harpoon-pull": ["harpoon_pull", "option", "launch"],
	"harpoon-keys": ["harpoon_keys", "option", "launch"],
}


# The one parse pass. `when` limits it to one phase ("start" or "launch"); empty applies
# every row. Returns the flags it applied, name to value text.
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
				applied[flag] = value
			else:
				push_warning("tuning: unknown --%s=%s" % [flag, value])
		elif value.is_valid_float():
			set_value(row[0], float(value))
			applied[flag] = value
	return applied


func apply_cmdline(when := "") -> Dictionary:
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	return apply_args(args, when)


func world_one() -> bool:
	return option("world_one_builds") == "on"


func harpoon_on() -> bool:
	return option("harpoon") != "off"


func armor() -> bool:
	return option("scrap_mode") == "armor"


func wear_on() -> bool:
	return armor() and option("wear") == "on"


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
