extends RefCounted

# Tally's upgrade tree: book every contact. Heap order as in rivet.gd. The left half stamps
# and feeds the ledger (Ledger); the right half drives the surge and the plate (Flywheel).
# Depth-2 names are DESIGN-V3's (Tally's program cards, D13).
# Indices 6 and 14 take procs, not pressure charges (PLAN B): pressure stays 3, 4 with the shop part.

const NODES := [
	{"id": "tl_audit_stamp", "name": "Audit Stamp", "effect": "Stamp slams send out a shockwave", "key": "smash",
		"icon": "ab_tally_smash", "tags": ["burst", "close"], "proc": [{"on": "slammed", "do": "blast", "scale": 0.5, "gap": 1.0}]},
	{"id": "tl_steam_bank", "name": "Steam Bank", "effect": "Bank two flywheel surges", "key": "movement",
		"icon": "ab_tally_move", "tags": ["mobility"], "charges": {"movement": 1}},

	{"id": "tl_through_feed", "name": "Through Feed", "effect": "Every hit winds your surge along", "key": "weapon",
		"icon": "ab_tally_weapon", "tags": ["close", "sustain"], "proc": [{"on": "enemy_struck", "do": "refund_move", "scale": 0.5, "gap": 0.5}]},
	{"id": "tl_line_feed", "name": "Line Feed", "effect": "Harpoon smashes throw a second shockwave", "key": "weapon",
		"icon": "ab_tally_weapon", "tags": ["close", "burst"], "proc": [{"on": "harpoon_smashed", "do": "blast", "scale": 0.6, "gap": 1.0}]},
	{"id": "tl_spring_vent", "name": "Spring Vent", "effect": "Each surge hands back your air jump", "key": "movement",
		"icon": "ab_tally_move", "tags": ["air", "mobility"], "proc": [{"on": "dashed", "do": "air", "scale": 1.0, "gap": 1.0}]},
	{"id": "tl_corner_plate", "name": "Corner Plate", "effect": "Every plate return refills a surge", "key": "special",
		"icon": "ab_tally_special", "tags": ["close", "mobility"], "proc": [{"on": "special_used", "do": "grant_move", "scale": 1.0, "gap": 1.0}]},

	{"id": "tl_deep_ledger", "name": "Deep Ledger", "effect": "Kills wind your plate return along", "key": "weapon",
		"icon": "ab_tally_weapon", "tags": ["sustain"], "proc": [{"on": "enemy_killed", "do": "refund_special", "scale": 0.5, "gap": 0.5}]},
	{"id": "tl_carbon_copy", "name": "Carbon Copy", "effect": "Ram rebounds throw a shockwave", "key": "weapon",
		"icon": "ab_tally_weapon", "tags": ["close", "burst"], "proc": [{"on": "enemy_rebounded", "do": "blast", "scale": 0.5, "gap": 1.0}]},
	{"id": "tl_stamp_duty", "name": "Stamp Duty", "effect": "Stamp slams hand back your air jump", "key": "smash",
		"icon": "ab_tally_smash", "tags": ["air", "mobility"], "proc": [{"on": "slammed", "do": "air", "scale": 1.0, "gap": 1.0}]},
	{"id": "tl_reel_in", "name": "Reel In", "effect": "Harpoon smashes refill a surge", "key": "movement",
		"icon": "ab_tally_move", "tags": ["close", "mobility"], "proc": [{"on": "harpoon_smashed", "do": "grant_move", "scale": 1.0, "gap": 1.5}]},
	{"id": "tl_blowdown", "name": "Blowdown", "effect": "Each surge vents a steam shockwave", "key": "movement",
		"icon": "ab_tally_move", "tags": ["burst", "close"], "proc": [{"on": "dashed", "do": "blast", "scale": 0.5, "gap": 1.0}]},
	{"id": "tl_governor", "name": "Governor", "effect": "Bank a third surge, recharging faster", "key": "movement",
		"icon": "ab_tally_move", "tags": ["mobility"], "charges": {"movement": 1}, "cooldown": {"movement": 0.8}},
	{"id": "tl_plate_rack", "name": "Plate Rack", "effect": "Stockpile two plate returns", "key": "special",
		"icon": "ab_tally_special", "tags": ["sustain"], "charges": {"special": 1}},
	{"id": "tl_return_slip", "name": "Return Slip", "effect": "Every plate return throws a shockwave", "key": "special",
		"icon": "ab_tally_special", "tags": ["close", "burst"], "proc": [{"on": "special_used", "do": "blast", "scale": 0.5, "gap": 1.0}]},

	{"id": "tl_full_ledger", "name": "Full Ledger", "effect": "Hits hand back your air jump", "key": "weapon",
		"icon": "ab_tally_weapon", "tags": ["air", "close"], "proc": [{"on": "enemy_struck", "do": "air", "scale": 1.0, "gap": 1.5}]},
	{"id": "tl_settled", "name": "Settled Account", "effect": "Kills wind your surge a second", "key": "weapon",
		"icon": "ab_tally_weapon", "tags": ["sustain"], "proc": [{"on": "enemy_killed", "do": "refund_move", "scale": 1.0, "gap": 0.5}]},
	{"id": "tl_bounce_back", "name": "Bounce Back", "effect": "Ram rebounds refill a surge", "key": "movement",
		"icon": "ab_tally_move", "tags": ["close", "mobility"], "proc": [{"on": "enemy_rebounded", "do": "grant_move", "scale": 1.0, "gap": 2.0}]},
	{"id": "tl_red_ink", "name": "Red Ink", "effect": "Rebounds wind your plate return along", "key": "special",
		"icon": "ab_tally_special", "tags": ["close", "sustain"], "proc": [{"on": "enemy_rebounded", "do": "refund_special", "scale": 1.0, "gap": 0.5}]},
	{"id": "tl_rubber_stamp", "name": "Rubber Stamp", "effect": "Stamp slams refill a surge", "key": "smash",
		"icon": "ab_tally_smash", "tags": ["mobility"], "proc": [{"on": "slammed", "do": "grant_move", "scale": 1.0, "gap": 2.0}]},
	{"id": "tl_postmark", "name": "Postmark", "effect": "Stamp slams throw a heavier shockwave too", "key": "smash",
		"icon": "ab_tally_smash", "tags": ["burst", "close"], "proc": [{"on": "slammed", "do": "blast", "scale": 0.8, "gap": 1.5}]},
	{"id": "tl_long_line", "name": "Long Line", "effect": "Bank a second flywheel surge", "key": "movement",
		"icon": "ab_tally_move", "tags": ["mobility"], "charges": {"movement": 1}},
	{"id": "tl_closing_entry", "name": "Closing Entry", "effect": "Harpoon smashes refill your plate return", "key": "special",
		"icon": "ab_tally_special", "tags": ["close", "sustain"], "proc": [{"on": "harpoon_smashed", "do": "grant_special", "scale": 1.0, "gap": 2.0}]},
	{"id": "tl_pressure_valve", "name": "Pressure Valve", "effect": "Each surge winds your plate return along", "key": "special",
		"icon": "ab_tally_special", "tags": ["sustain", "mobility"], "proc": [{"on": "dashed", "do": "refund_special", "scale": 1.5, "gap": 1.0}]},
	{"id": "tl_scald", "name": "Scald", "effect": "Boosts vent a small steam shockwave", "key": "movement",
		"icon": "ab_tally_move", "tags": ["burst", "close"], "proc": [{"on": "boosted", "do": "blast", "scale": 0.4, "gap": 1.5}]},
	{"id": "tl_freewheel", "name": "Freewheel", "effect": "Landings wind your surge half a second", "key": "movement",
		"icon": "ab_tally_move", "tags": ["mobility", "sustain"], "proc": [{"on": "landed", "do": "refund_move", "scale": 0.5, "gap": 1.0}]},
	{"id": "tl_overspeed", "name": "Overspeed", "effect": "Kills refill a surge", "key": "movement",
		"icon": "ab_tally_move", "tags": ["sustain", "mobility"], "proc": [{"on": "enemy_killed", "do": "grant_move", "scale": 1.0, "gap": 2.0}]},
	{"id": "tl_plate_stack", "name": "Plate Stack", "effect": "Stockpile three plate returns, recharging faster", "key": "special",
		"icon": "ab_tally_special", "tags": ["sustain"], "charges": {"special": 1}, "cooldown": {"special": 0.8}},
	{"id": "tl_backstop", "name": "Backstop", "effect": "Breaking free refills your plate return", "key": "special",
		"icon": "ab_tally_special", "tags": ["cc_immune", "sustain"], "proc": [{"on": "hold_broken", "do": "grant_special", "scale": 1.0, "gap": 2.0}]},
	{"id": "tl_paid_in_full", "name": "Paid In Full", "effect": "Every plate return hands back your air jump", "key": "special",
		"icon": "ab_tally_special", "tags": ["air", "close"], "proc": [{"on": "special_used", "do": "air", "scale": 1.0, "gap": 1.0}]},
	{"id": "tl_bounced_check", "name": "Bounced Check", "effect": "Breaking free throws a steam shockwave", "key": "special",
		"icon": "ab_tally_special", "tags": ["cc_immune", "burst"], "proc": [{"on": "hold_broken", "do": "blast", "scale": 0.6, "gap": 1.5}]},
]


# Tally's world-one profile retains every node in the full tree's heap order.
const NODES_WORLD_ONE := NODES
