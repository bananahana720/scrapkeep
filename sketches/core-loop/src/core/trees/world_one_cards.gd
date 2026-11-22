extends RefCounted

# World-one card copy (--world-one-builds=on), keyed by node id. A pick card shows the row
# here when the flag is on and one exists, and the node's own `effect` otherwise, so a node
# without a row (and every card with the flag off) reads exactly as before. Source:
# design-v3/research/build-systems/BUILD-SYSTEMS.md, the bold line of each node. Sable, Kest,
# Rivet, Tarn, Tally and remembered cannon rows join this table in their own units; nothing else
# needs to change. Depth-3 and depth-4 ultimate cards read SET_PIECE_LINES below instead.

# A run's first pick is a depth-1 pair, read before the pilot has rolled a metre, so the three
# starting pilots' depth-1 rows say the effect in the words the pilot card and the HUD already use
# (vault kick, mount, charges, cloak, laser), and only what the card itself gives: Sable's two set
# the weight launch, and Cannonball says what makes the ball heavy (scrap, the HUD's "Scrap = heft"
# callout) before the launch it buys; Kest's blasts widen with weight whether or not a card is taken,
# so her cards do not claim it (player's-eye pass, 10 Nov 2026: a first-time reader could not say
# what either Sable card did; PF-01). No row uses the game's own terms for a mounted pilot or the
# shell's steering: "on a wall" says mounted, and "steer sharper" says what the shell inversion does.
const ROWS := {
	# Sable, S1 to S6.
	"s_cannonball": "Kick off a wall to zap what's near. Scrap makes you heavier. Heavier launches farther.",
	"s_beachhead": "Grab a wall from twice as far.",
	"s_coil_hook": "Let go of the rope to fling yourself.",
	"s_face_runner": "Kick off a wall to jump again. Steer sharper after each kick.",
	"s_arc_nest": "On a wall, bolts chain to another target.",
	"s_bulwark": "On a wall, nothing shoves or snares you.",
	# Kest, K1 to K6.
	"k_trapper": "Charges wait longer. Five can wait at once.",
	"k_ghost": "Cloaked, machines spot you only up close.",
	"k_tripwire": "Charges spring when machines approach.",
	"k_demo_expert": "Smash scatters five payloads.",
	"k_smoke_trail": "Glide cloaked. Steer sharper while you glide.",
	"k_ambush": "Throw payloads without breaking cloak.",
	# Rivet, R1 to R6.
	"r_gunline": "Your laser fires twin bolts.",
	"r_juggernaut": "Starting a sprint blasts machines back.",
	"r_tracer": "Running fire jumps to a neighbour.",
	"r_run_gun": "Sustain fire. Worn scrap sparks behind you.",
	"r_ram_fins": "Sprint through bodies instead of bouncing.",
	"r_second_wind": "Bank two sprints. Sprinting, you steer freely midair.",
	# Tarn, T1 to T6.
	"t_long_claw": "Reach two metres farther. Close the gap.",
	"t_anchor_line": "Every claw pull throws a shockwave.",
	"t_twin_talons": "Two lighter talons rake each sweep.",
	"t_heavy_paw": "Sweeps hurl the crowd twice as far.",
	"t_spare_claw": "Bank two claw pulls.",
	"t_vice_grip": "Every clamp refills a claw pull.",
	# Tally, TL1 to TL6.
	"tl_audit_stamp": "Every stamp slam throws a shockwave.",
	"tl_steam_bank": "Bank two flywheel surges.",
	"tl_through_feed": "Every hit winds your next surge closer.",
	"tl_line_feed": "Harpoon smashes throw a second shockwave.",
	"tl_spring_vent": "Each surge refills your air jump.",
	"tl_corner_plate": "Every gather plate refills a surge.",
	# Remembered cannon, C1 to C6.
	"c_quick_lane": "Call lanes a quarter faster.",
	"c_brace_kick": "Every plate refills a recoil kick.",
	"c_lane_fever": "Kills speed up your lanes.",
	"c_spare_kick": "Bank two recoil kicks.",
	"c_spare_plate": "Bank two plates.",
	"c_rush_shock": "Rush landings throw a shockwave.",
}

# The second line of a depth-3 or depth-4 ultimate card (SKILL-BAR section 12, item 5), keyed by
# ultimate id or by the pilot's ult_ knob. Unlike ROWS it shows at every depth and with the
# world-one flag on or off, and the node keeps its own `effect`. Wave P-B unit B6 seeds one
# marked block per pilot; each P-C unit fills its own, one line a key in the voice of ROWS, and
# edits nothing else in this table.
const SET_PIECE_LINES := {
	# Shared lines for the framework knobs (every pilot's depth-4 nodes set the same values);
	# a pilot overrides one as "<class_id>:<knob>" in its own block.
	"ult_beats": "Ultimate lasts two beats longer.",
	"ult_volley": "Ultimate strikes one more each beat.",
	"ult_radius": "Ultimate lands two metres wider.",
	"ult_encore": "Ultimate can land a second time.",
	# --- P-C Sable set piece lines ---
	"ball_lightning": "Ultimate becomes Ball Lightning.",
	"outpost": "Ultimate becomes Outpost.",
	# --- end Sable ---
	# --- P-C Rivet set piece lines ---
	"foundry_cutter": "Ultimate drives a measured cut to your aim.",
	"prism_cutter": "Your cutter splits three ways through a prism.",
	"juggernaut_drive": "Ultimate drives you through machines. No beam.",
	"ult_pins": "The ultimate's landing throws machines twice as hard.",
	"runner_gunner:ult_beats": "Ultimate cuts or drives two beats longer.",
	"runner_gunner:ult_volley": "Ultimate cuts more or rams a wider corridor.",
	"runner_gunner:ult_radius": "The ultimate's landing skids two metres wider.",
	"runner_gunner:ult_encore": "Ultimate can cut or drive an encore.",
	# --- end Rivet ---
	# --- P-C Kest set piece lines ---
	"minelayer": "Ultimate becomes Minelayer.",
	"air_raid": "Ultimate becomes Air Raid.",
	# --- end Kest ---
	# --- P-C Tarn set piece lines ---
	"redjaw_rend": "Climb the line, tow them, rend.",
	"rake_run": "Rake both sides, then sweep faster.",
	"vice_leap": "Hurl the catch, leap into the vice.",
	"tarn:ult_volley": "Ultimate rakes wider or grabs more.",
	"tarn:ult_encore": "Ultimate can rend a second landing.",
	# --- end Tarn ---
	# --- P-C Tally set piece lines ---
	"plate_return": "Ride home. Every clip settles on landing.",
	"plate_audit": "Stamp what you steer over.",
	"plate_flywheel": "Launch, gather, collect.",
	"ult_settle": "Clips settle for more on landing.",
	# --- end Tally ---
	# --- P-C Cannon set piece lines ---
	"cannon_creeping_barrage": "Ultimate becomes Creeping Barrage.",
	"cannon_plate_mortar": "Ultimate becomes Plate Mortar.",
	# --- end Cannon ---
}


# The three rows that name the Riveted Shell inversion read these instead while the shell is
# not fitted (--hotwire-shell off), because build.gd applies the inversion only with it fitted.
const UNFITTED_ROWS := {
	"s_face_runner": "Kick off a wall to jump again.",
	"k_smoke_trail": "Glide cloaked.",
	"r_second_wind": "Bank two sprints.",
}


static func has_row(node_id: String) -> bool:
	return ROWS.has(node_id)


# The effect line a card shows for this node: the world-one row when `world_one` and a
# row exists, else the node's own effect. `shell` is whether Riveted Shell is fitted.
static func effect_line(node: Dictionary, world_one: bool, shell: bool) -> String:
	var id := String(node.get("id", ""))
	if world_one and not shell and UNFITTED_ROWS.has(id):
		return String(UNFITTED_ROWS[id])
	if world_one and ROWS.has(id):
		return String(ROWS[id])
	return String(node.get("effect", ""))


# The set piece line for a node: its swapped-in ultimate id first, then any ult_ knob it sets,
# read as "<pilot>:<knob>" (the class id the card is offered to) before the shared knob line.
# "" when none is seeded. Independent of the world-one flag.
static func set_piece_line(node: Dictionary, table: Dictionary = SET_PIECE_LINES, pilot := "") -> String:
	var swap = node.get("swap", {})
	if swap is Dictionary and swap.has("ultimate"):
		var id := String(swap["ultimate"])
		if table.has(id):
			return String(table[id])
	var knob = node.get("knob", {})
	if knob is Dictionary:
		for k in knob:
			if not String(k).begins_with("ult_"):
				continue
			if table.has(pilot + ":" + String(k)):
				return String(table[pilot + ":" + String(k)])
			if table.has(String(k)):
				return String(table[String(k)])
	return ""
