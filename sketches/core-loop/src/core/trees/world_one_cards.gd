extends RefCounted


const ROWS := {
	"s_static_flutter": "Three sparks on tap. Six pulses charged.",
	"s_rail_lance": "Longer charge fires one piercing arc lance.",
	"s_cannonball": "Kick off a wall to zap what's near. Scrap makes you heavier. Heavier launches farther.",
	"s_beachhead": "Grab a wall from twice as far.",
	"s_coil_hook": "Let go of the rope to fling yourself.",
	"s_face_runner": "Kick off a wall to jump again. Steer sharper after each kick.",
	"s_arc_nest": "On a wall, bolts chain to another target.",
	"s_bulwark": "On a wall, nothing shoves or snares you.",
	"k_cluster": "Throws scatter three small charges sharing snap.",
	"k_keg": "One wide slow keg breaks tough props.",
	"k_trapper": "Charges wait longer. Five can wait at once.",
	"k_ghost": "Cloaked, machines spot you only up close.",
	"k_tripwire": "Charges spring when machines approach.",
	"k_demo_expert": "Smash scatters five payloads.",
	"k_smoke_trail": "Glide cloaked. Steer sharper while you glide.",
	"k_ambush": "Throw payloads without breaking cloak.",
	"r_fan_hammer": "Twelve light rounds. Hold to fan fire.",
	"r_big_iron": "Two piercing shells. Heavy knock, breaks props.",
	"r_gunline": "Your laser fires twin bolts.",
	"r_juggernaut": "Starting a sprint blasts machines back.",
	"r_tracer": "Running fire jumps to a neighbour.",
	"r_run_gun": "Sustain fire. Worn scrap sparks behind you.",
	"r_ram_fins": "Sprint through bodies instead of bouncing.",
	"r_second_wind": "Bank two sprints. Sprinting, you steer freely midair.",
	"t_saw_flurry": "Fast light sweeps. Every fifth hit pierces.",
	"t_guillotine": "Slow windup. Third beat cleaves, breaks props.",
	"t_long_claw": "Reach two metres farther. Close the gap.",
	"t_anchor_line": "Every claw pull throws a shockwave.",
	"t_twin_talons": "Two lighter talons rake each sweep.",
	"t_heavy_paw": "Sweeps hurl the crowd twice as far.",
	"t_spare_claw": "Bank two claw pulls.",
	"t_vice_grip": "Every clamp refills a claw pull.",
	"tl_petty_cash": "Half cost, half hit, faster beat spikes.",
	"tl_compound_interest": "Slower beat. Chained spikes climb to 38.",
	"tl_audit_stamp": "Every card-punch slam throws a shockwave.",
	"tl_steam_bank": "Bank two tape-reel surges.",
	"tl_through_feed": "Every hit winds your next surge closer.",
	"tl_line_feed": "Harpoon smashes throw a second shockwave.",
	"tl_spring_vent": "Each surge refills your air jump.",
	"tl_corner_plate": "Beacons refill a surge and raise Ghost-Shift husks.",
	"c_snap_battery": "Quick lock and short wait, lighter lanes.",
	"c_siege_rail": "Slow lock. 40m rail pierces and breaks props.",
	"c_quick_lane": "Call lanes a quarter faster.",
	"c_brace_kick": "Every plate refills a recoil kick.",
	"c_lane_fever": "Kills speed up your lanes.",
	"c_spare_kick": "Bank two recoil kicks.",
	"c_spare_plate": "Bank two plates.",
	"c_rush_shock": "Rush landings throw a shockwave.",
}

const SET_PIECE_LINES := {
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
	"plate_audit": "Punch what you steer over.",
	"plate_flywheel": "Launch, pull the pack, collect.",
	"ult_settle": "Clips settle for more on landing.",
	# --- end Tally ---
	# --- P-C Cannon set piece lines ---
	"cannon_creeping_barrage": "Ultimate becomes Creeping Barrage.",
	"cannon_plate_mortar": "Ultimate becomes Plate Mortar.",
	# --- end Cannon ---
}


const UNFITTED_ROWS := {
	"s_face_runner": "Kick off a wall to jump again.",
	"k_smoke_trail": "Glide cloaked.",
	"r_second_wind": "Bank two sprints.",
}


static func has_row(node_id: String) -> bool:
	return ROWS.has(node_id)


static func effect_line(node: Dictionary, world_one: bool, shell: bool) -> String:
	var id := String(node.get("id", ""))
	if world_one and not shell and UNFITTED_ROWS.has(id):
		return String(UNFITTED_ROWS[id])
	if world_one and ROWS.has(id):
		return String(ROWS[id])
	return String(node.get("effect", ""))


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
