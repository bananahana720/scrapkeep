extends RefCounted

# The active family (design page "Makers and Actives", 17 Oct 2026; Andrew tapped "Core now":
# all six actives and the maker sets land before the sitting). One row per active; the rack
# (active_rack.gd) owns the slot, charges and the F press, and the row's `kind` script owns
# what a fire does. A new active is a row here plus its script, never a change to the rack.
#
# maker        the workshop that built it (the maker set it counts toward)
# rarity       ItemGen's rung: rare or relic
# max_charges  presses it can hold
# recharge     seconds per charge from time alone
# kill_charge  share of a charge each kill pays: fighting fills the rack
# bonus_cap    the most overflow pieces a full ultimate meter can bank for the next fire
# windup       seconds before it fires ("Big ones only": small actives fire on the press, big
#              ones wind up 0.5-0.8 s). The charge is spent on the press; a Jam during the
#              wind-up cancels it and refunds the charge.
# kind         the script that fires it: setup(ctx, combat), fire(rack, row, bonus) -> pieces
#              launched, step(delta), clear(); optional begin(rack, row) draws the wind-up's tell
#              (the same geometry fire() will hit) and cancel() drops it.

const SCRAP_ROCKET := "scrap_rocket"

const ROWS := {
	SCRAP_ROCKET: {
		"name": "Scrap Rocket Rack", "maker": "spillway_works", "rarity": "rare",
		"verb": "Rack homing scrap rockets", "text": "F: four rockets steer onto machines",
		"max_charges": 2, "recharge": 9.0, "kill_charge": 0.15, "bonus_cap": 4, "windup": 0.0,
		"kind": preload("res://src/combat/actives/scrap_rockets.gd"),
	},
	# One marked block per active, so each active's unit edits only its own.
	# --- Silo Battery (Fleet Surplus) ---
	# --- end Silo Battery ---
	# --- Cutting Torch (Redjaw Workshops) ---
	# --- end Cutting Torch ---
	# --- Lift Pulse (Highdraft Roosts) ---
	# --- end Lift Pulse ---
	# --- Quake Knock (Waking-made) ---
	"quake_knock": {
		"name": "Quake Knock", "maker": "waking_made", "rarity": "relic",
		"verb": "Knock a quake ring into the floor", "text": "F: a ring of cracks draws itself, then the floor hits",
		"max_charges": 1, "recharge": 11.0, "kill_charge": 0.12, "bonus_cap": 4, "windup": 0.5,
		"kind": preload("res://src/combat/actives/quake_knock.gd"),
	},
	# --- end Quake Knock ---
	# --- Glass Lance (Mind-glass) ---
	# --- end Glass Lance ---
}

# The active every run opens with while --actives=on and no offer has racked one yet.
const STARTER := SCRAP_ROCKET


static func row(id: String) -> Dictionary:
	return ROWS.get(id, {})
