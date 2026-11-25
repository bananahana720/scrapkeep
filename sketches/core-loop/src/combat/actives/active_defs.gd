extends RefCounted

const SCRAP_ROCKET := "scrap_rocket"

const ROWS := {
	SCRAP_ROCKET: {
		"name": "Scrap Rocket Rack", "maker": "spillway_works", "rarity": "rare",
		"verb": "Rack homing scrap rockets", "text": "Four rockets steer onto machines",
		"max_charges": 2, "recharge": 9.0, "kill_charge": 0.15, "bonus_cap": 4, "windup": 0.0,
		"kind": preload("res://src/combat/actives/scrap_rockets.gd"),
	},
	"silo_battery": {
		"name": "Silo Battery", "maker": "fleet_surplus", "rarity": "relic",
		"verb": "Call down a silo strike", "text": "Rings mark the ground, then the sky answers",
		"max_charges": 1, "recharge": 14.0, "kill_charge": 0.1, "bonus_cap": 3, "windup": 0.5,
		"kind": preload("res://src/combat/actives/silo_battery.gd"),
	},
	"cutting_torch": {
		"name": "Cutting Torch", "maker": "redjaw", "rarity": "rare",
		"verb": "Sweep a plate-cutting torch", "text": "A guide line, then a beam that burns through plating",
		"max_charges": 1, "recharge": 11.0, "kill_charge": 0.12, "bonus_cap": 4, "windup": 0.3,
		"kind": preload("res://src/combat/actives/cutting_torch.gd"),
	},
	"lift_pulse": {
		"name": "Lift Pulse", "maker": "highdraft_roosts", "rarity": "rare",
		"verb": "Pulse a lift fan", "text": "A fan cone shoves machines away, harder per heft tier",
		"max_charges": 2, "recharge": 7.0, "kill_charge": 0.15, "bonus_cap": 4, "windup": 0.0,
		"kind": preload("res://src/combat/actives/lift_pulse.gd"),
	},
	"quake_knock": {
		"name": "Quake Knock", "maker": "waking", "rarity": "relic",
		"verb": "Knock a quake ring into the floor", "text": "A ring of cracks draws itself, then the floor hits",
		"max_charges": 1, "recharge": 11.0, "kill_charge": 0.12, "bonus_cap": 4, "windup": 0.5,
		"kind": preload("res://src/combat/actives/quake_knock.gd"),
	},
	"glass_lance": {
		"name": "Glass Lance", "maker": "mind_glass", "rarity": "relic",
		"verb": "Throw a shard of the Mind", "text": "A glass lance pierces every machine in a line",
		"max_charges": 2, "recharge": 11.0, "kill_charge": 0.12, "bonus_cap": 3, "windup": 0.0,
		"kind": preload("res://src/combat/actives/glass_lance.gd"),
	},
	"slag_mortar": {
		"name": "Slag Mortar", "maker": "redjaw", "rarity": "rare",
		"verb": "Lob a molten slag shell", "text": "Drops a burning slag zone that breaks soft walls",
		"max_charges": 2, "recharge": 10.0, "kill_charge": 0.14, "bonus_cap": 4, "windup": 0.35,
		"kind": preload("res://src/combat/actives/slag_mortar.gd"),
	},
	"magnet_sling": {
		"name": "Magnet Sling", "maker": "fleet_surplus", "rarity": "relic",
		"verb": "Toss a cluster anchor buoy", "text": "Pulls nearby machines together, then snaps inward",
		"max_charges": 1, "recharge": 12.0, "kill_charge": 0.12, "bonus_cap": 4, "windup": 0.0,
		"kind": preload("res://src/combat/actives/magnet_sling.gd"),
	},
}

const STARTER := SCRAP_ROCKET


static func row(id: String) -> Dictionary:
	return ROWS.get(id, {})
