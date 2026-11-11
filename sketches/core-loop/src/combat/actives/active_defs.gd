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
#              fire() may run twice in one release (Open Frame, maker_sets.gd: fired in the
#              air, an active fires twice), so a kind keeps no per-release state across it.

const SCRAP_ROCKET := "scrap_rocket"

const ROWS := {
	SCRAP_ROCKET: {
		"name": "Scrap Rocket Rack", "maker": "spillway_works", "rarity": "rare",
		"verb": "Rack homing scrap rockets", "text": "Four rockets steer onto machines",
		"max_charges": 2, "recharge": 9.0, "kill_charge": 0.15, "bonus_cap": 4, "windup": 0.0,
		"kind": preload("res://src/combat/actives/scrap_rockets.gd"),
	},
	# One marked block per active, so each active's unit edits only its own.
	# --- Silo Battery (Fleet Surplus) ---
	"silo_battery": {
		"name": "Silo Battery", "maker": "fleet_surplus", "rarity": "relic",
		"verb": "Call down a silo strike", "text": "Rings mark the ground, then the sky answers",
		"max_charges": 1, "recharge": 14.0, "kill_charge": 0.1, "bonus_cap": 3, "windup": 0.5,
		"kind": preload("res://src/combat/actives/silo_battery.gd"),
	},
	# --- end Silo Battery ---
	# --- Cutting Torch (Redjaw Workshops) ---
	"cutting_torch": {
		"name": "Cutting Torch", "maker": "redjaw", "rarity": "rare",
		"verb": "Sweep a plate-cutting torch", "text": "A guide line, then a beam that burns through plating",
		"max_charges": 1, "recharge": 11.0, "kill_charge": 0.12, "bonus_cap": 4, "windup": 0.3,
		"kind": preload("res://src/combat/actives/cutting_torch.gd"),
	},
	# --- end Cutting Torch ---
	# --- Lift Pulse (Highdraft Roosts) ---
	"lift_pulse": {
		"name": "Lift Pulse", "maker": "highdraft_roosts", "rarity": "rare",
		"verb": "Pulse a lift fan", "text": "A fan cone shoves machines away, harder per heft tier",
		"max_charges": 2, "recharge": 7.0, "kill_charge": 0.15, "bonus_cap": 4, "windup": 0.0,
		"kind": preload("res://src/combat/actives/lift_pulse.gd"),
	},
	# --- end Lift Pulse ---
	# --- Quake Knock (Waking-made) ---
	"quake_knock": {
		"name": "Quake Knock", "maker": "waking", "rarity": "relic",
		"verb": "Knock a quake ring into the floor", "text": "A ring of cracks draws itself, then the floor hits",
		"max_charges": 1, "recharge": 11.0, "kill_charge": 0.12, "bonus_cap": 4, "windup": 0.5,
		"kind": preload("res://src/combat/actives/quake_knock.gd"),
	},
	# --- end Quake Knock ---
	# --- Glass Lance (Mind-glass) ---
	"glass_lance": {
		"name": "Glass Lance", "maker": "mind_glass", "rarity": "relic",
		"verb": "Throw a shard of the Mind", "text": "A glass lance pierces every machine in a line",
		"max_charges": 2, "recharge": 11.0, "kill_charge": 0.12, "bonus_cap": 3, "windup": 0.0,
		"kind": preload("res://src/combat/actives/glass_lance.gd"),
	},
	# --- end Glass Lance ---
}

# The active every run opens with while --actives=on and no offer has racked one yet.
const STARTER := SCRAP_ROCKET


static func row(id: String) -> Dictionary:
	return ROWS.get(id, {})
