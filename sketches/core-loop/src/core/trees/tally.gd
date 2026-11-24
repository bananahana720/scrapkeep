extends RefCounted

# Tally's upgrade tree: book every contact. Heap order as in rivet.gd. The left half stamps
# and feeds the ledger (Ledger); the right half drives the surge and the plate (Flywheel).
# Depth-2 names are DESIGN-V3's (Tally's program cards, D13).
# Indices 6 and 14 take procs, not pressure charges (PLAN B): pressure stays 3, 4 with the shop part.
# Wave P-C (pilots/tally.md section 3): every depth-3 node keeps its op and swaps Q to Audit Trail
# or Flywheel Throw (siblings always one of each); every depth-4 node keeps its op and turns one
# set-piece knob, Tally's own ult_settle among them. Keys stay on the slot the kept op touches.

const NODES := [
	{"id": "tl_audit_stamp", "name": "Audit Stamp", "effect": "Stamp slams send out a shockwave", "key": "smash",
		"icon": "ab_tally_smash", "tags": ["burst", "close"], "proc": [{"on": "slammed", "do": "blast", "scale": 0.5, "gap": 1.0}]},
	{"id": "tl_steam_bank", "name": "Steam Bank", "effect": "Bank two flywheel surges", "key": "movement",
		"icon": "ab_tally_move", "tags": ["mobility"], "charges": {"movement": 1}},

	{"id": "tl_through_feed", "name": "Through Feed", "effect": "Every hit winds your surge along", "key": "weapon",
		"icon": "ab_tally_weapon", "tags": ["close", "sustain"], "proc": [{"on": "enemy_struck", "do": "refund_move", "scale": 0.5, "gap": 0.5}]},
	{"id": "tl_line_feed", "name": "Line Feed", "effect": "Harpoon smashes throw a second shockwave", "key": "weapon",
		"icon": "ab_tally_weapon", "tags": ["close", "burst"], "proc": [{"on": "harpoon_smashed", "do": "blast", "scale": 0.6, "gap": 1.0}]},
	{"id": "tl_spring_vent", "name": "Spring Vent", "effect": "Each surge refills your air jump", "key": "movement",
		"icon": "ab_tally_move", "tags": ["air", "mobility"], "proc": [{"on": "dashed", "do": "air", "scale": 1.0, "gap": 1.0}]},
	{"id": "tl_corner_plate", "name": "Corner Plate", "effect": "Every gather plate refills a surge", "key": "special",
		"icon": "ab_tally_special", "tags": ["close", "mobility"], "proc": [{"on": "special_used", "do": "grant_move", "scale": 1.0, "gap": 1.0}]},

	{"id": "tl_deep_ledger", "name": "Deep Ledger", "effect": "Ultimate becomes Audit Trail. Kills wind gather along.", "class_id": "tally", "stack_rule": "capped", "key": "weapon",
		"icon": "ab_tally_ult", "tags": ["sustain"], "proc": [{"on": "enemy_killed", "do": "refund_special", "scale": 0.5, "gap": 0.5}],
		"swap": {"ultimate": "plate_audit"}},
	{"id": "tl_carbon_copy", "name": "Carbon Copy", "effect": "Ultimate becomes Flywheel Throw. Bounces throw a shockwave.", "class_id": "tally", "stack_rule": "capped", "key": "weapon",
		"icon": "ab_tally_ult", "tags": ["close", "burst"], "proc": [{"on": "enemy_rebounded", "do": "blast", "scale": 0.5, "gap": 1.0}],
		"swap": {"ultimate": "plate_flywheel"}},
	{"id": "tl_stamp_duty", "name": "Stamp Duty", "effect": "Ultimate becomes Audit Trail. Stamps refill air jumps.", "class_id": "tally", "stack_rule": "capped", "key": "smash",
		"icon": "ab_tally_ult", "tags": ["air", "mobility"], "proc": [{"on": "slammed", "do": "air", "scale": 1.0, "gap": 1.0}],
		"swap": {"ultimate": "plate_audit"}},
	{"id": "tl_reel_in", "name": "Reel In", "effect": "Ultimate becomes Flywheel Throw. Smashes refill a surge.", "class_id": "tally", "stack_rule": "capped", "key": "movement",
		"icon": "ab_tally_ult", "tags": ["close", "mobility"], "proc": [{"on": "harpoon_smashed", "do": "grant_move", "scale": 1.0, "gap": 1.5}],
		"swap": {"ultimate": "plate_flywheel"}},
	{"id": "tl_blowdown", "name": "Blowdown", "effect": "Ultimate becomes Flywheel Throw. Surges vent a shockwave.", "class_id": "tally", "stack_rule": "capped", "key": "movement",
		"icon": "ab_tally_ult", "tags": ["burst", "close"], "proc": [{"on": "dashed", "do": "blast", "scale": 0.5, "gap": 1.0}],
		"swap": {"ultimate": "plate_flywheel"}},
	{"id": "tl_governor", "name": "Governor", "effect": "Ultimate becomes Audit Trail. A third, faster surge.", "class_id": "tally", "stack_rule": "capped", "key": "movement",
		"icon": "ab_tally_ult", "tags": ["mobility"], "charges": {"movement": 1}, "cooldown": {"movement": 0.8},
		"swap": {"ultimate": "plate_audit"}},
	{"id": "tl_plate_rack", "name": "Plate Rack", "effect": "Ultimate becomes Flywheel Throw. Bank two gather plates.", "class_id": "tally", "stack_rule": "capped", "key": "special",
		"icon": "ab_tally_ult", "tags": ["sustain"], "charges": {"special": 1},
		"swap": {"ultimate": "plate_flywheel"}},
	{"id": "tl_return_slip", "name": "Return Slip", "effect": "Ultimate becomes Audit Trail. Gather plates throw shockwaves.", "class_id": "tally", "stack_rule": "capped", "key": "special",
		"icon": "ab_tally_ult", "tags": ["close", "burst"], "proc": [{"on": "special_used", "do": "blast", "scale": 0.5, "gap": 1.0}],
		"swap": {"ultimate": "plate_audit"}},

	{"id": "tl_full_ledger", "name": "Full Ledger", "effect": "Hits refill air jumps; clips settle for more", "class_id": "tally", "stack_rule": "capped", "key": "weapon",
		"icon": "ab_tally_ult", "tags": ["air", "close"], "proc": [{"on": "enemy_struck", "do": "air", "scale": 1.0, "gap": 1.5}],
		"knob": {"ult_settle": 0.7}},
	{"id": "tl_settled", "name": "Settled Account", "effect": "Kills wind surge; ultimate flies two beats longer", "class_id": "tally", "stack_rule": "capped", "key": "weapon",
		"icon": "ab_tally_ult", "tags": ["sustain"], "proc": [{"on": "enemy_killed", "do": "refund_move", "scale": 1.0, "gap": 0.5}],
		"knob": {"ult_beats": 2}},
	{"id": "tl_bounce_back", "name": "Bounce Back", "effect": "Bounces refill a surge; ultimate lands wider", "class_id": "tally", "stack_rule": "capped", "key": "movement",
		"icon": "ab_tally_ult", "tags": ["close", "mobility"], "proc": [{"on": "enemy_rebounded", "do": "grant_move", "scale": 1.0, "gap": 2.0}],
		"knob": {"ult_radius": 2.0}},
	{"id": "tl_red_ink", "name": "Red Ink", "effect": "Bounces wind gather; clips settle for more", "class_id": "tally", "stack_rule": "capped", "key": "special",
		"icon": "ab_tally_ult", "tags": ["close", "sustain"], "proc": [{"on": "enemy_rebounded", "do": "refund_special", "scale": 1.0, "gap": 0.5}],
		"knob": {"ult_settle": 0.7}},
	{"id": "tl_rubber_stamp", "name": "Rubber Stamp", "effect": "Stamps refill a surge; ultimate lands wider", "class_id": "tally", "stack_rule": "capped", "key": "smash",
		"icon": "ab_tally_ult", "tags": ["mobility"], "proc": [{"on": "slammed", "do": "grant_move", "scale": 1.0, "gap": 2.0}],
		"knob": {"ult_radius": 2.0}},
	{"id": "tl_postmark", "name": "Postmark", "effect": "Heavier stamp shockwaves; ultimate flies an encore", "class_id": "tally", "stack_rule": "capped", "key": "smash",
		"icon": "ab_tally_ult", "tags": ["burst", "close"], "proc": [{"on": "slammed", "do": "blast", "scale": 0.8, "gap": 1.5}],
		"knob": {"ult_encore": true}},
	{"id": "tl_long_line", "name": "Long Line", "effect": "Second surge; ultimate flies an encore leg", "class_id": "tally", "stack_rule": "capped", "key": "movement",
		"icon": "ab_tally_ult", "tags": ["mobility"], "charges": {"movement": 1},
		"knob": {"ult_encore": true}},
	{"id": "tl_closing_entry", "name": "Closing Entry", "effect": "Smashes refill gather; ultimate volleys clip more", "class_id": "tally", "stack_rule": "capped", "key": "special",
		"icon": "ab_tally_ult", "tags": ["close", "sustain"], "proc": [{"on": "harpoon_smashed", "do": "grant_special", "scale": 1.0, "gap": 2.0}],
		"knob": {"ult_volley": 1}},
	{"id": "tl_pressure_valve", "name": "Pressure Valve", "effect": "Surges wind gather; ultimate flies two beats longer", "class_id": "tally", "stack_rule": "capped", "key": "special",
		"icon": "ab_tally_ult", "tags": ["sustain", "mobility"], "proc": [{"on": "dashed", "do": "refund_special", "scale": 1.5, "gap": 1.0}],
		"knob": {"ult_beats": 2}},
	{"id": "tl_scald", "name": "Scald", "effect": "Boosts vent steam; ultimate lands wider", "class_id": "tally", "stack_rule": "capped", "key": "movement",
		"icon": "ab_tally_ult", "tags": ["burst", "close"], "proc": [{"on": "boosted", "do": "blast", "scale": 0.4, "gap": 1.5}],
		"knob": {"ult_radius": 2.0}},
	{"id": "tl_freewheel", "name": "Freewheel", "effect": "Landings wind surge; ultimate flies two beats longer", "class_id": "tally", "stack_rule": "capped", "key": "movement",
		"icon": "ab_tally_ult", "tags": ["mobility", "sustain"], "proc": [{"on": "landed", "do": "refund_move", "scale": 0.5, "gap": 1.0}],
		"knob": {"ult_beats": 2}},
	{"id": "tl_overspeed", "name": "Overspeed", "effect": "Kills refill a surge; ultimate stamps wider", "class_id": "tally", "stack_rule": "capped", "key": "movement",
		"icon": "ab_tally_ult", "tags": ["sustain", "mobility"], "proc": [{"on": "enemy_killed", "do": "grant_move", "scale": 1.0, "gap": 2.0}],
		"knob": {"ult_volley": 1}},
	{"id": "tl_plate_stack", "name": "Plate Stack", "effect": "Three faster gather plates; ultimate clips one more", "class_id": "tally", "stack_rule": "capped", "key": "special",
		"icon": "ab_tally_ult", "tags": ["sustain"], "charges": {"special": 1}, "cooldown": {"special": 0.8},
		"knob": {"ult_volley": 1}},
	{"id": "tl_backstop", "name": "Backstop", "effect": "Breaking free refills gather; ultimate encore leg", "class_id": "tally", "stack_rule": "capped", "key": "special",
		"icon": "ab_tally_ult", "tags": ["cc_immune", "sustain"], "proc": [{"on": "hold_broken", "do": "grant_special", "scale": 1.0, "gap": 2.0}],
		"knob": {"ult_encore": true}},
	{"id": "tl_paid_in_full", "name": "Paid In Full", "effect": "Gather refills your air jump; ultimate encore leg", "class_id": "tally", "stack_rule": "capped", "key": "special",
		"icon": "ab_tally_ult", "tags": ["air", "close"], "proc": [{"on": "special_used", "do": "air", "scale": 1.0, "gap": 1.0}],
		"knob": {"ult_encore": true}},
	{"id": "tl_bounced_check", "name": "Bounced Check", "effect": "Breaking free vents steam; clips settle for more", "class_id": "tally", "stack_rule": "capped", "key": "special",
		"icon": "ab_tally_ult", "tags": ["cc_immune", "burst"], "proc": [{"on": "hold_broken", "do": "blast", "scale": 0.6, "gap": 1.5}],
		"knob": {"ult_settle": 0.7}},
]


# World-one Depth-1 opposite-feel keystones (PILOT-CADENCE.md §§6.1-6.2, E2-09).
# Left root: Petty Cash (tl_through_feed stays at slot 2; tl_audit_stamp moves to slot 3 in place of tl_line_feed).
# Right root: Compound Interest (tl_steam_bank moves to slot 4 in place of tl_spring_vent; tl_corner_plate stays at slot 5).
const PETTY_CASH := {"id": "tl_petty_cash", "name": "Petty Cash", "effect": "Half cost, half hit, faster beat stamps.", "key": "weapon",
	"icon": "ab_tally_weapon", "tags": ["close", "sustain"],
	"pattern": {"ledger_reader": {"set": {"cast_cost": 0.5, "floor_s": 0.25, "window_s": [0.25, 0.45], "refund": 0.25},
		"mul": {"damage": 0.5}}}}
const COMPOUND_INTEREST := {"id": "tl_compound_interest", "name": "Compound Interest", "effect": "Slower beat. Chained stamps climb to 38.", "key": "weapon",
	"icon": "ab_tally_weapon", "tags": ["burst", "sustain"],
	"pattern": {"ledger_reader": {"set": {"window_s": [0.55, 0.75], "window_mult": 1.0,
		"stamp_streak_bonus": 8.0, "stamp_streak_cap": 38.0, "refund": 0.25}}}}
# A static var, not a const: GDScript cannot fold Array.slice into a constant.
static var NODES_WORLD_ONE: Array = [PETTY_CASH, COMPOUND_INTEREST, NODES[2], NODES[0], NODES[1], NODES[5]] + NODES.slice(6)
