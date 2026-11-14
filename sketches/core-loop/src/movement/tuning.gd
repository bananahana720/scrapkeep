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
	# The durability prototype (DESIGN-NOTES, "Scrap as armour"): `--scrap=armor` makes mass a
	# temporary health layer over the hull, `--wear=on` lets rolling friction wear it. Both
	# default on; `--scrap=off --wear=off` brings back the old base game. `--route-seed=<n>` reseeds the run's streams and
	# `--start-mass=<n>` opens the run with that mass, so the three variants share a route.
	{"key": "scrap_mode", "label": "Scrap mode", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["off", "armor"]},
	{"key": "wear", "label": "Scrap wear", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["off", "on"]},
	{"key": "start_mass", "label": "Start mass", "min": 0.0, "max": 3000.0, "step": 10.0, "value": 0.0},
	{"key": "route_seed", "label": "Route seed (0 = off)", "min": 0.0, "max": 999999.0, "step": 1.0, "value": 0.0},
	# The music lab: the ACE takes on stage 1 (presentation/ace_sequencer.gd, the default), or the
	# synth band, and the Warden open's held breath in the ACE music.
	{"key": "music", "label": "Music", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["synth", "ace"]},
	{"key": "breath", "label": "Breath", "min": 0.0, "max": 2.0, "step": 1.0, "value": 1.0, "options": ["raw", "hard", "gentle"]},
	# The recorded band's Warden form (ace_sequencer.gd follow_guard): the tight build as the guard
	# nears breaking, the held breath through a stagger, the drop on the hit that shatters a
	# chunk. `--warden-form=loop` keeps the build looping to the break, as it played before.
	{"key": "warden_form", "label": "Warden form", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["loop", "form"]},
	# Room for the Warden form's drop (audio.gd _make_drop_room, mix_rows.gd DROP_ROOM): candidates
	# for Andrew's ear under ruling cq, off by default so the game is unchanged. "duck" steps the
	# effects back for the drop's first two bars, "lift" raises the band for them.
	{"key": "drop_room", "label": "Drop room", "min": 0.0, "max": 2.0, "step": 1.0, "value": 0.0, "options": ["off", "duck", "lift"]},
	# The set director (presentation/set_director.gd): a DJ who reads the room each bar and mixes
	# the recorded band to it, with June's sax answering each phrase. Off by default until Andrew
	# has heard it on and off (ruling cq); `--set-director=on` turns it on.
	{"key": "set_director", "label": "Set director", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "discovery", "label": "Discovery", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["banner", "cards"]},
	# The attack warnings' look (threat_grammar.gd LOOKS). "clear" (the default since 13 Nov 2026, a
	# taste call Andrew can overturn) and "edges" are haze made less obstructive.
	{"key": "telegraph", "label": "Telegraph", "min": 0.0, "max": 4.0, "step": 1.0, "value": 2.0, "options": ["classic", "haze", "clear", "edges", "tape"]},
	# The ball's look (presentation/ball_looks.gd): Andrew picked the cutaway on 13 Nov 2026 (ruling
	# dm); gyro and bell are the two he passed over. "today" keeps the game's own shells and stays
	# the default until he has seen the finished cutaway on the PC.
	{"key": "ball_look", "label": "Ball look", "min": 0.0, "max": 3.0, "step": 1.0, "value": 0.0, "options": ["today", "gyro", "bell", "cutaway"]},
	# World-one builds (design-v3/research/build-systems/BUILD-SYSTEMS.md, unit G): the master
	# flag gives every pilot a two-depth tree, and the two hot-wired parts are selectable
	# alone. All three default on. hotwire_shell is read by the build and the tree pick; hotwire_tread is read by the build (HotwireRules.fitted, build.gd) to fit the tread.
	{"key": "world_one_builds", "label": "World-one builds", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["off", "on"]},
	# Poles and flails (design-v3/POLES-FLAILS.md): `--pole-flail=on` lets weight decide what a
	# held harpoon does to a bitten enemy. Off keeps today's reel on every body until the lab
	# gate (section 11) passes with it on.
	{"key": "pole_flail", "label": "Poles and flails", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "hotwire_shell", "label": "Hot-wired shell", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["off", "on"]},
	{"key": "hotwire_tread", "label": "Hot-wired tread", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["off", "on"]},
	# Heat on the shell (docs/design/loops.md Spec 1, src/combat/redline.gd): off by default so the
	# game is unchanged; "watch" counts blazing seconds and skims without changing play (the A/B
	# base), "on" plays it.
	{"key": "heat", "label": "Heat", "min": 0.0, "max": 2.0, "step": 1.0, "value": 0.0, "options": ["off", "watch", "on"]},
	{"key": "overtime", "label": "Overtime", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	{"key": "called_shot", "label": "Called shot", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	# The survival yard (BACKLOG W1-101, src/world/survival_count.gd): off by default, so no yard is built and
	# bots, tests and the sitting play the game without it until its band read is in.
	{"key": "stocktake", "label": "Stocktake", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	# The harpoon (DESIGN-NOTES, "Harpoon and winch"): one mode for every pilot, locking on an enemy inside
	# harpoon_lock_deg and flying the ball in.
	{"key": "harpoon_smash_speed", "label": "Harpoon smash speed", "min": 10.0, "max": 45.0, "step": 1.0, "value": 24.0},
	{"key": "harpoon_lock_deg", "label": "Harpoon lock (deg)", "min": 0.0, "max": 25.0, "step": 0.5, "value": 10.0},
	# Debug stand-in for run-found companion pieces: on grants one piece per family at run start,
	# so the intermission assembly screen has something to assemble. Off leaves run.companion {}.
	{"key": "companion_stub", "label": "Companion stub pieces", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	# The active slot on F (src/combat/actives): on by default since the six actives landed
	# (DECISIONS "New item layer before the sitting", 17 Oct; Codex world 1 review, design #5),
	# so every run opens with the Scrap Rocket Rack racked. --actives=off turns the slot off.
	{"key": "actives", "label": "Active slot", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["off", "on"]},
	# --profile=sitting: every pilot opens on the title for a sitting. It only answers
	# Game.pilot_unlocked; the saved profile is never read or written differently.
	# --profile=sitting-earned (W1-78): the sitting's loops on a profile of its own that opens
	# nothing in advance and keeps what it earns, so the sitting can judge the first unlock.
	{"key": "profile", "label": "Launch set", "min": 0.0, "max": 2.0, "step": 1.0, "value": 0.0, "options": ["default", "sitting", "sitting-earned"]},
	{"key": "harpoon_rewind", "label": "Harpoon rewind (s)", "min": 0.0, "max": 3.0, "step": 0.1, "value": 1.0},
	# Wall grip (ENEMY-PRIORITY.md 3a; Andrew's "Speed holds", 2026-10-17): at the fast tier
	# walls and the first part of an overhang count as ground. `--grip=off` for the sitting.
	{"key": "grip", "label": "Wall grip", "min": 0.0, "max": 1.0, "step": 1.0, "value": 1.0, "options": ["off", "on"]},
	# Marked hull (docs/systems-audit/feature-fit.md, new mechanic 1; src/world/hull_mark.gd): hull
	# paid at a keeper's gamble lowers max hull until the next Warden break. Off keeps today's price.
	{"key": "marked_hull", "label": "Marked hull", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	# Moss's scale (feature-fit.md, new mechanic 2; shop.gd weigh): sell mass for cogs at Moss's
	# counter. Off keeps today's shop. Rates are placeholders until the economy pass sets them.
	{"key": "moss_scale", "label": "Moss's scale", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	# Carry a core (feature-fit.md, new mechanic 3; Andrew 11 Nov 19:24Z, one core, only into
	# SPIL-9): Moss's counter stows one of this stage's cores in a SPIL-9 socket for the next stage.
	{"key": "carry_core", "label": "Carry a core", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["off", "on"]},
	# The world whose boss ends the run won (W1-60, Andrew 12 Nov 22:06Z): "last" runs the whole
	# stage table; "1" ends the world 1 sitting at Brindle, with its summary and HARD rung 1, instead
	# of rolling on into the parked Dig.
	{"key": "final_world", "label": "Run ends after", "min": 0.0, "max": 1.0, "step": 1.0, "value": 0.0, "options": ["last", "1"]},
]

# The option rows other modules read by name.
const MUSIC_KEY := "music"
const BREATH_KEY := "breath"
const WARDEN_FORM_KEY := "warden_form"
const DROP_ROOM_KEY := "drop_room"
const SET_DIRECTOR_KEY := "set_director"
const DISCOVERY_KEY := "discovery"
const TELEGRAPH_KEY := "telegraph"
const BALL_LOOK_KEY := "ball_look"

const BRAKE_RESISTANCE := 4.0
const BRAKE_TURN_BOOST := 2.2
const BOOST_IMPULSE := 11.0
const BOOST_COOLDOWN := 1.1
# Stacked cooldown parts stay uncapped as stats (overpowered pays), but the boost itself never
# recharges faster than this. Measured 2026-11-08 on the park dam with boost held: 0.165 s peaks
# at 122 m/s and 0.11 s at 165 m/s, against 180 m/s where one 90 Hz tick moves the ball its own
# diameter; with no floor a held boost fired every tick and reached 483 m/s. At this floor
# the held boost peaks at 124-134 m/s.
const BOOST_COOLDOWN_FLOOR := 0.15
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.14
const MAX_SLOPE_DOT := 0.45
const STICK_ACCEL := 22.0
const STICK_SPEED := 18.0
const QUAD_DRAG := 0.0045
const RADIUS := 1.0
# A Warden hardpoint line's winch stops at this length (start value), so a ball holding the
# harpoon reels in and then hangs or orbits instead of grinding into the body.
const ANCHOR_MIN_ROPE := 6.0
const SKIN := 0.12
# Wall grip, start values (ENEMY-PRIORITY.md 3a). From the fast tier the grounded threshold
# drops to GRIP_SLOPE_DOT; below it for GRIP_PEEL_S the ball peels off. The downforce,
# GRIP_DOWNFORCE x speed in m/s^2, presses along the contact normal only, so it never adds
# speed; it fades in from GRIP_FORCE_FROM to full at MAX_SLOPE_DOT, leaving floors, banks
# and kicker lips as they were. Carving is grip-speed contact steeper than CARVE_DOT (25 deg).
const GRIP_SLOPE_DOT := -0.2
const GRIP_PEEL_S := 0.25
const GRIP_DOWNFORCE := 0.6
const GRIP_FORCE_FROM := 0.707
const CARVE_DOT := 0.906

# The speed bank (SQ9, comps/roboquest/movement-and-feel.md): a chosen jump/slide
# landing at BANK_ARM x cruise, or a stick start from a free rest below BANK_REST x cruise
# (grounded there before the press, never held by the brake), banks speed.
# The roll starts at `ratio` x cruise and decays
# back to cruise over `decay_s`: flat for the first `hold` of the decay, then as
# ((1 - u) / (1 - hold)) ^ `exp`. A ground jump inside the last BANK_WINDOW of the decay
# keeps the burst; a jump before it spends the bank back to cruise. Per pilot so the six
# traces differ in shape, not only scale. Every row is a start value to tune in play.
const BANK_ARM := 0.9
const BANK_REST := 0.2
const BANK_WINDOW := 0.25
const BANK_DEFAULT := {"ratio": 1.25, "decay_s": 1.2, "hold": 0.0, "exp": 1.0}
const BANK_ROWS := {
	# Sable: a straight ramp, she leaves each launch point faster and spends it evenly.
	"pylon_engineer": {"ratio": 1.25, "decay_s": 1.2, "hold": 0.0, "exp": 1.0},
	# Rivet: the push holds, then falls away late; the longest bank.
	"runner_gunner": {"ratio": 1.22, "decay_s": 1.6, "hold": 0.35, "exp": 2.0},
	# Kest: the biggest, shortest kick, held high and dropped at the end.
	"demolitions_caster": {"ratio": 1.29, "decay_s": 0.8, "hold": 0.0, "exp": 0.5},
	# Tarn: a short clamp of speed that bleeds off fast.
	"tarn": {"ratio": 1.24, "decay_s": 1.0, "hold": 0.15, "exp": 3.0},
	# Tally: a flywheel run-down, early loss easing out.
	"tally": {"ratio": 1.21, "decay_s": 1.4, "hold": 0.0, "exp": 1.6},
	# The Cannon: half the decay at full burst, then a straight fall.
	"remembered_cannon": {"ratio": 1.28, "decay_s": 1.1, "hold": 0.5, "exp": 1.0},
}


static func bank_row(class_id: String) -> Dictionary:
	return BANK_ROWS.get(class_id, BANK_DEFAULT)


# The bank's share left at u (0 to 1) of its decay: 1 at the burst, 0 back at cruise.
static func bank_share(row: Dictionary, u: float) -> float:
	var hold: float = row["hold"]
	if u <= hold:
		return 1.0
	if u >= 1.0:
		return 0.0
	return pow((1.0 - u) / (1.0 - hold), float(row["exp"]))

var _values := {}
# Parts scale knobs through mods rather than by moving the sliders, so the F1 panel
# keeps showing the base value and a recompute from the part list is idempotent.
var _mods := {}
# Flat amounts the build adds in a key's own unit (grey panels' area_radius, metres); like
# _mods they never move a slider. Cleared with the mods.
var _adds := {}
# Parts shorten the shared boost cooldown; a constant, not a slider row.
var boost_cooldown_scale := 1.0
# What the command line set, key to value: reset() returns to how this launch started, so
# the F1 panel's Reset defaults keeps the flags and only the sliders go back to defaults.
var _launch := {}


func _init() -> void:
	reset()
	apply_cmdline("start")


# Every launch flag, one table and one parse pass. name -> [tuning key, kind, when]:
#   kind  "option" names one of the row's options; an unknown value warns and is refused
#         "number" takes any float (clamped by the row); a non-number is ignored quietly
#   when  "start" flags apply as Tuning is built (the durability flags, so every Tuning
#         reads them); "launch" flags apply when game.gd calls apply_cmdline("launch"),
#         so a bot or tool that builds a bare Tuning never sees them.
# `--scrap=armor --wear=on --route-seed=7 --start-mass=200 --music=ace --breath=gentle
# --warden-form=loop --discovery=cards --telegraph=clear --world-one-builds=on --hotwire-shell=on --hotwire-tread=on
# --grip=off`, from the engine args
# or the user args (after Godot's `--`). A flag in neither table is ignored.
# threat_grammar.gd's Painter.haze_on() reads --telegraph from the launch args itself,
# since the static-drawn floor marking has no tuning in reach; tuning_flags_test checks
# that its name is a row here.
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
	"final-world": ["final_world", "option", "launch"],
}


# What --profile=sitting turns on beyond the defaults: the loops Andrew wants in the world 1
# sitting (ruling da), the marked hull and Moss's scale (ruling dd), carry a core (ruling df) and
# the run's end at Brindle (W1-60).
# A flag on the same command line wins, and bots and gate bands, which never pass the profile,
# still measure the base game.
const SITTING_SET := {"heat": "on", "overtime": "on", "called-shot": "on", "marked-hull": "on", "moss-scale": "on",
	"carry-core": "on", "final-world": "1"}


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


# Everything opened for the sitting: every pilot, secret and first-win find, and no saving.
func sitting() -> bool:
	return option("profile") == "sitting"


# The sitting's loops on a fresh profile that earns its unlocks and keeps them (W1-78).
func sitting_earned() -> bool:
	return option("profile") == "sitting-earned"


# The world whose boss ends the run won, or 0 when the stage table's last stage does.
func final_world() -> int:
	var value := option("final_world")
	return int(value) if value.is_valid_int() else 0


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


# The cruise speed hit-strength reads measure against (the ram tier, a Warden's tier gate, the
# flail's scale, whether a contact rams): the slider value without build mods, so a cruise
# up (Fin Plate, cruise items) makes the ball faster and never drops it a hit tier (Coordinator
# ruling 24 Oct, principle 5 "overpowered pays").
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


# The harpoon's rewind after a landing, in seconds: the slider over the build's recovery rate
# (Ratchet Collar adds rate, so a stack shortens the wait and never reaches zero).
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
