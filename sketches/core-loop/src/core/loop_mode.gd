extends RefCounted

# The core-loop v3 fun lab's switch (design-v3/LOOP-REDESIGN.md section 7). One
# loop_mode and one gun_role, both option rows in tuning.gd, so the launcher flag, the
# title screen row and the F1 panel all write the same two values and every mode branch
# reads them from here:
#   loop_mode  v2    the control: the v2 Warden fight, no return, no drop lips
#              drop  Option A: only a drop on the open weak point lands
#              laps  Option C: the loop's return and lips are live; the Warden sleeps
#                    until the course is lapped (runs_laps), then fights by v2 rules
#   gun_role   hold  weapon hits on the open weak point hold the window and deal a
#                    small share
#              full  weapon hits inside the window deal full damage; drops are burst
# The mode is read at stage entry (the Warden's spawn and the loop geometry), so a flip
# in the panel takes effect on the next stage or a hold-R retry.

const MODES := ["v2", "drop", "laps"]
const GUN_ROLES := ["hold", "full"]
const LOOP_KEY := "loop_mode"
const GUN_KEY := "gun_role"
const MUSIC_KEY := "music"
const BREATH_KEY := "breath"
const TELEGRAPH_KEY := "telegraph"
# telegraph is read by combat/threat_grammar.gd itself (the floor marking is static-drawn,
# with no tuning in reach): `--telegraph=haze`, default classic.
const FLAGS := {"loop": LOOP_KEY, "gun": GUN_KEY, "music": MUSIC_KEY, "breath": BREATH_KEY, "telegraph": TELEGRAPH_KEY}


static func mode(tuning) -> String:
	return tuning.option(LOOP_KEY) if tuning != null else "v2"


static func gun_role(tuning) -> String:
	return tuning.option(GUN_KEY) if tuning != null else "hold"


static func is_drop(tuning) -> bool:
	return mode(tuning) == "drop"


# The modes that run the stage loop: the return lift and the drop lines' kicker lips.
static func uses_loop(tuning) -> bool:
	return mode(tuning) in ["drop", "laps"]


# Option C, "the Bell and the Laps", on a map with a loop: world runs the lap course
# (lap_course.gd) and flow keeps the Warden asleep until LAPS_REQUIRED laps are in. The
# one laps branch both modules read, so they never disagree on a stage without a loop.
const LAPS_REQUIRED := 3


static func runs_laps(tuning, map) -> bool:
	return mode(tuning) == "laps" and map != null and not map.drop_lines.is_empty()


# `--loop=drop --gun=full --music=ace --breath=gentle`, from the user args (after
# Godot's `--`) or the engine args (the launcher's `scrapkeep <sketch> -- --loop=drop`
# puts them there). Returns the flags it applied.
static func apply_args(tuning, args: PackedStringArray) -> Dictionary:
	var applied := {}
	for arg in args:
		if not arg.begins_with("--") or not "=" in arg:
			continue
		var flag := arg.substr(2, arg.find("=") - 2)
		if not FLAGS.has(flag):
			continue
		var value := arg.substr(arg.find("=") + 1)
		if tuning.set_option(FLAGS[flag], value):
			applied[flag] = value
		else:
			push_warning("loop_mode: unknown --%s=%s" % [flag, value])
	return applied


static func apply_cmdline(tuning) -> Dictionary:
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	return apply_args(tuning, args)


# The next option in a row's list, wrapping: the title screen's L and G.
static func cycle(tuning, key: String) -> String:
	var options: Array = tuning.options_of(key)
	var next: String = options[(options.find(tuning.option(key)) + 1) % options.size()]
	tuning.set_option(key, next)
	return next


# The tag the run log and the bots carry, so a report splits runs by mode.
static func tag(tuning) -> Dictionary:
	return {"loop_mode": mode(tuning), "gun_role": gun_role(tuning)}
