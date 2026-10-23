extends RefCounted

# The v2 item pool (I2 section 3, accepted by DESIGN-V2 section 7): 62 items in six
# families. Cross Split, Spiral Wave and Chain Arc already live in parts.gd's catalogue,
# so this table holds the other 59. Each row is compact on purpose: the generator
# (item_gen.gd) fills in the name, the tier, the icon category, the tags it lacks and
# the word-count discipline, the same way it builds a procedural item, so an authored
# row and a generated one are the same shape.
#
# base      the family archetype: weapon, pattern, mobility, defense, utility, charge.
# trigger   "" (passive) or one of Triggers.NAMES.
# stack     linear, hyperbolic or capped; cap is the ceiling for the last two.
# effect    {"do": id, ...}: item_effects.gd's closed effect table.
# charges   ability slot to extra max_charges per copy.
# class     only this class is offered the part.
# needs     the other module's seam it waits on; the part is never offered without it.
# maker     the workshop that made it (maker_sets.gd): its set counts the row as a piece.
# touches   the Bindings verb the part changes. 2026-10-15 (wave 14 SQ19b): set on the rows the
#           alpha list offers (build_synergy_test); each keeps the row's offer bucket
#           (Parts.bucket_of): fire only on weapon rows, special only on skill rows.
#
# Where I2's effect needs a hook no unit owns yet, the row keeps I2's intent with the
# nearest build-owned effect, and DESIGN-NOTES v2 W4 names each adaptation.

const SABLE := "pylon_engineer"
const RIVET := "runner_gunner"
const KEST := "demolitions_caster"

const TABLE := {
	# Charge-stockpile (8).
	"cap_relay": {"maker": "spillway_works", "touches": "special", "base": "charge", "rarity": "uncommon", "stack": "capped", "cap": 3, "tags": ["arc"],
		"verb": "Stock a spare special", "text": "+1 special charge", "charges": {"special": 1}},
	"vault_battery": {"maker": "moss", "base": "charge", "rarity": "rare", "stack": "capped", "cap": 2, "tags": ["anchor", "speed"],
		"class": SABLE, "needs": "player.set_vault_charges",
		"verb": "Bank a second vault", "text": "+1 vault kick charge", "effect": {"do": "vault_charges", "count": 1}},
	"sprint_cell": {"maker": "moss", "touches": "boost", "base": "charge", "rarity": "uncommon", "stack": "capped", "cap": 3, "tags": ["speed"],
		"class": RIVET, "verb": "Stock a spare sprint", "text": "+1 sprint charge", "charges": {"movement": 1}},
	"cloak_flask": {"maker": "moss", "base": "charge", "rarity": "rare", "stack": "capped", "cap": 2, "tags": ["speed", "anchor"],
		"class": KEST, "verb": "Stock a spare blink", "text": "+1 blink charge, more cloak", "charges": {"movement": 1}},
	"quick_spool": {"maker": "spillway_works", "base": "charge", "rarity": "common", "stack": "hyperbolic", "cap": 0.4, "tags": ["speed"],
		"verb": "Spin the special up", "text": "special recharges 8% sooner",
		"effect": {"do": "slot_cooldown", "slot": "special", "per": 0.087}},
	"overcharge_coil": {"maker": "spillway_works", "base": "charge", "rarity": "rare_plus", "trigger": "on_charge_release", "stack": "capped", "cap": 1,
		"tags": ["arc", "chain"], "verb": "Overcharge every release", "text": "Release hits 40% harder, may refund",
		"effect": {"do": "overcharge", "damage": 12.0, "radius": 9.0, "refund": 0.15}},
	"reserve_tank": {"maker": "spillway_works", "base": "charge", "rarity": "uncommon", "stack": "capped", "cap": 2, "tags": ["mass"],
		"verb": "Carry a reserve cell", "text": "+1 charge, special and movement", "charges": {"special": 1, "movement": 1}},
	"flywheel": {"maker": "highdraft_roosts", "base": "charge", "rarity": "common", "trigger": "on_speed_tier_up", "stack": "capped", "cap": 1,
		"tags": ["speed"], "verb": "Spin speed into charge", "text": "Speed up refills a movement charge",
		"effect": {"do": "grant_charge", "slot": "movement", "every": 6.0}},

	# Momentum and bowling (8), tagged bwl for the balance report.
	"pin_setter": {"maker": "redjaw", "touches": "fire", "base": "weapon", "rarity": "uncommon", "trigger": "on_smash", "stack": "linear", "cap": 3,
		"tags": ["kinetic"], "punch": 5.0, "bwl": true, "verb": "Set the pins", "text": "After a smash, pins hit 50% harder",
		"effect": {"do": "pin_bonus", "bonus": 0.5, "window": 1.5}},
	"spring_hull": {"maker": "spillway_works", "base": "defense", "rarity": "common", "trigger": "on_rebound", "stack": "linear", "cap": 5,
		"tags": ["mass", "speed"], "bwl": true, "verb": "Spring off heavies", "text": "Rebounds throw you 15% harder",
		"effect": {"do": "speed", "gain": 0.15, "max_speed": 45.0}},
	"long_lane": {"maker": "highdraft_roosts", "base": "mobility", "rarity": "rare", "trigger": "on_vault", "stack": "linear", "tags": ["speed", "anchor"],
		"bwl": true, "verb": "Kick down the long lane", "text": "Vault kicks carry 6% further",
		"effect": {"do": "speed", "gain": 0.06, "max_speed": 45.0}},
	"gutter_guard": {"maker": "highdraft_roosts", "base": "mobility", "rarity": "uncommon", "trigger": "on_rebound", "stack": "capped", "cap": 2,
		"tags": ["speed"], "bwl": true, "verb": "Bounce out of the gutter", "text": "Rebounds give back an air jump",
		"effect": {"do": "air_jump", "every": 0.5}},
	"ten_pin": {"maker": "redjaw", "base": "weapon", "rarity": "rare_plus", "trigger": "on_smash", "stack": "capped", "cap": 3,
		"tags": ["kinetic", "chain"], "punch": 10.0, "bwl": true, "verb": "Knock down all ten",
		"text": "Pins knock three more pins", "effect": {"do": "pin_chain", "count": 3, "speed": 9.0, "window": 1.5}},
	"ballast_drum": {"maker": "fleet_surplus", "touches": "roll", "base": "defense", "rarity": "common", "stack": "linear", "cap": 5, "tags": ["mass"], "bwl": true,
		"verb": "Roll a ballast drum", "text": "Bolts on 40 mass of ballast", "effect": {"do": "ballast", "mass": 40}},
	"strike_pocket": {"maker": "redjaw", "base": "weapon", "rarity": "rare", "trigger": "on_rebound", "stack": "capped", "cap": 1,
		"tags": ["kinetic", "speed"], "punch": 8.0, "bwl": true, "verb": "Hit the pocket",
		"text": "Third rebound in 4s strikes double", "effect": {"do": "rebound_crit", "count": 3, "window": 4.0, "mult": 2.0}},
	"re_rack": {"maker": "waking", "touches": "jump", "base": "utility", "rarity": "uncommon", "trigger": "on_land", "stack": "capped", "cap": 1,
		"tags": ["kinetic", "mass"], "bwl": true, "verb": "Re-rack the pins", "text": "Landing near a pin relaunches it",
		"effect": {"do": "relaunch_pin", "radius": 7.0, "speed": 10.0, "window": 2.0}},

	# Weapon-pattern transformers: three new (the other three are catalogue rows).
	"fan_spread": {"maker": "highdraft_roosts", "base": "pattern", "rarity": "rare", "stack": "linear", "cap": 3, "tags": ["split"],
		"needs": "spawner.fan_spread", "verb": "Fan shots into a cone", "text": "shots fan into a 5-round cone",
		"patterns": {"fan_spread": 1}},
	"ring_wave": {"maker": "waking", "base": "pattern", "rarity": "rare", "trigger": "on_hit", "stack": "linear", "cap": 3,
		"tags": ["spiral", "arc"], "verb": "Ring every impact", "text": "impacts emit an expanding pulse ring",
		"effect": {"do": "burst", "radius": 3.5, "damage": 6.0, "every": 0.2}},
	"helix_drill": {"maker": "waking", "base": "pattern", "rarity": "rare_plus", "stack": "linear", "cap": 3, "tags": ["spiral", "kinetic"],
		"needs": "spawner.helix_drill", "verb": "Drill through the line", "text": "shots corkscrew through two enemies",
		"patterns": {"helix_drill": 1}},

	# Designed happy accidents (5): rare, capped, fun because they are bounded.
	"scrap_geyser": {"maker": "spillway_works", "base": "utility", "rarity": "rare", "trigger": "on_pickup", "stack": "capped", "cap": 1,
		"tags": ["mass", "kinetic"], "happy": true, "verb": "Pickups may erupt", "text": "4% of pickups burst nearby pins",
		"effect": {"do": "scrap_burst", "chance": 0.04, "radius": 7.0, "speed": 11.0}},
	"echo_charge": {"maker": "mind_glass", "base": "charge", "rarity": "rare_plus", "trigger": "on_charge_release", "stack": "capped", "cap": 1,
		"tags": ["arc", "spiral"], "happy": true, "verb": "Echo the release", "text": "10% chance: a free echo, smaller",
		"effect": {"do": "echo_release", "chance": 0.1, "radius": 8.0, "damage": 16.0}},
	"feedback_loop": {"maker": "mind_glass", "base": "utility", "rarity": "rare", "trigger": "on_kill", "stack": "capped", "cap": 1,
		"tags": ["arc", "chain"], "happy": true, "class": KEST, "needs": "spawner.extend_cloak",
		"verb": "Feed the smoke", "text": "Kills in cloak extend it 0.4s", "effect": {"do": "cloak_extend", "seconds": 0.4}},
	"momentum_thief": {"maker": "moss", "base": "mobility", "rarity": "uncommon", "trigger": "on_damage_taken", "stack": "capped", "cap": 5,
		"tags": ["speed", "mass"], "happy": true, "verb": "Steal speed from hits", "text": "Chip hits push you 5% faster",
		"effect": {"do": "speed", "gain": 0.05, "max_speed": 40.0}},
	"domino_wire": {"maker": "redjaw", "base": "weapon", "rarity": "rare_plus", "trigger": "on_smash", "stack": "capped", "cap": 1,
		"tags": ["chain", "kinetic"], "punch": 10.0, "happy": true, "verb": "Wire the dominoes",
		"text": "20% chance a pin chains once more", "effect": {"do": "domino", "chance": 0.2, "speed": 10.0, "window": 1.5}},

	# Damage (10).
	"hairline_fracture": {"maker": "redjaw", "touches": "fire", "base": "weapon", "rarity": "common", "trigger": "on_hit", "stack": "linear", "cap": 5,
		"tags": ["kinetic"], "punch": 3.0, "verb": "Find the hairline", "text": "+6% chance a hit lands twice",
		"effect": {"do": "extra_hit", "chance": 0.06, "mult": 1.0}},
	"barrage_spring": {"maker": "redjaw", "touches": "fire", "base": "weapon", "rarity": "uncommon", "trigger": "on_kill", "stack": "capped", "cap": 1,
		"tags": ["speed", "split"], "punch": 6.0, "verb": "Spring the next shot", "text": "A kill refunds a weapon charge",
		"effect": {"do": "grant_charge", "slot": "weapon", "every": 1.0}},
	"warhead_slug": {"maker": "fleet_surplus", "base": "weapon", "rarity": "rare", "trigger": "on_smash", "stack": "linear", "cap": 3,
		"tags": ["kinetic", "mass"], "punch": 10.0, "verb": "Slam a warhead home", "text": "Smashes hit plating 35% harder",
		"effect": {"do": "burst", "radius": 5.0, "damage": 14.0}},
	"static_burr": {"maker": "mind_glass", "touches": "fire", "base": "weapon", "rarity": "common", "trigger": "on_hit", "element": "arc", "stack": "capped", "cap": 3,
		"tags": ["arc"], "punch": 3.0, "verb": "Burr every round", "text": "10% chance a hit arcs on",
		"effect": {"do": "zap", "chance": 0.1, "damage": 8.0, "reach": 10.0}},
	"frost_barb": {"maker": "spillway_works", "touches": "fire", "base": "weapon", "rarity": "common", "trigger": "on_hit", "element": "frost", "stack": "capped", "cap": 3,
		"tags": ["frost"], "punch": 3.0, "verb": "Barb shots with frost", "text": "10% chance a hit spreads frost",
		"effect": {"do": "burst", "chance": 0.1, "radius": 3.0, "damage": 4.0}},
	"overpressure": {"maker": "spillway_works", "touches": "fire", "base": "weapon", "rarity": "uncommon", "trigger": "timed", "stack": "capped", "cap": 1,
		"tags": ["mass", "anchor"], "punch": 6.0, "verb": "Build overpressure", "text": "Every 8s, next hit +60%",
		"effect": {"do": "arm_hit", "every": 8.0, "bonus": 0.6}},
	"clean_break": {"maker": "redjaw", "base": "weapon", "rarity": "rare", "trigger": "on_kill", "stack": "capped", "cap": 1,
		"tags": ["kinetic", "chain"], "punch": 10.0, "verb": "Break it clean", "text": "Killing blows crack nearby plating",
		"effect": {"do": "burst", "radius": 6.0, "damage": 10.0}},
	"tracer_round": {"maker": "fleet_surplus", "base": "weapon", "rarity": "common", "stack": "linear", "cap": 5, "tags": ["anchor"],
		"verb": "Trace the long shot", "text": "+8% weapon range", "mods": {"weapon_range": 1.08}},
	"impact_driver": {"maker": "redjaw", "touches": "fire", "base": "weapon", "rarity": "uncommon", "trigger": "on_rebound", "stack": "linear", "cap": 3,
		"tags": ["kinetic", "speed"], "punch": 6.0, "verb": "Drive the impact", "text": "Rebounds deal a weapon hit",
		"effect": {"do": "rebound_strike", "mult": 1.0}},
	"last_word": {"maker": "redjaw", "base": "weapon", "rarity": "rare_plus", "trigger": "on_damage_taken", "stack": "capped", "cap": 1,
		"tags": ["mass", "kinetic"], "punch": 12.0, "verb": "Get the last word", "text": "Under 25% health, next hit doubles",
		"effect": {"do": "last_word", "below": 0.25, "bonus": 1.0}},

	# Mobility (8).
	"light_frame": {"maker": "highdraft_roosts", "base": "mobility", "rarity": "common", "stack": "linear", "cap": 5, "tags": ["speed"],
		"verb": "Shave the frame", "text": "+6% cruise speed", "mods": {"cruise": 1.06}},
	"glide_vane": {"maker": "highdraft_roosts", "touches": "jump", "base": "mobility", "rarity": "uncommon", "stack": "linear", "cap": 3, "tags": ["speed", "frost"],
		"class": KEST, "punch": 3.0, "verb": "Widen the glide vane", "text": "+20% glide time, +3 punch",
		"mods": {"glide_gravity": 0.83}},
	"grapple_coil": {"maker": "waking", "touches": "harpoon", "base": "mobility", "rarity": "common", "stack": "linear", "cap": 4, "tags": ["anchor"],
		"class": SABLE, "verb": "Coil a longer rope", "text": "+20% grapple range", "mods": {"rope_range": 1.2}},
	"tumbler_bearing": {"maker": "highdraft_roosts", "base": "mobility", "rarity": "uncommon", "trigger": "on_land", "stack": "capped", "cap": 1,
		"tags": ["speed", "mass"], "verb": "Tumble into a hop", "text": "Hard landings give back an air jump",
		"effect": {"do": "air_jump", "every": 1.0}},
	"slipstream": {"maker": "highdraft_roosts", "base": "mobility", "rarity": "rare", "trigger": "on_speed_tier_up", "stack": "linear", "tags": ["speed", "spiral"],
		"verb": "Ride the slipstream", "text": "Speeding up adds a 10% surge",
		"effect": {"do": "speed", "gain": 0.1, "max_speed": 45.0, "every": 1.0}, "mods": {"air_control": 1.15}},
	"anchor_spring": {"maker": "waking", "base": "mobility", "rarity": "uncommon", "stack": "linear", "cap": 3, "tags": ["anchor", "speed"],
		"class": SABLE, "needs": "player.set_vault_cooldown_scale", "verb": "Spring the anchor",
		"text": "Vault kick recharges 20% sooner", "effect": {"do": "vault_cooldown", "per": 0.2}},
	"jet_vent": {"maker": "highdraft_roosts", "base": "mobility", "rarity": "rare", "trigger": "on_cloak_break", "stack": "capped", "cap": 1,
		"tags": ["speed", "arc"], "class": KEST, "verb": "Vent the jets", "text": "Breaking cloak fires a burst dash",
		"effect": {"do": "dash", "speed": 14.0}},
	"low_rider": {"maker": "highdraft_roosts", "base": "mobility", "rarity": "common", "stack": "linear", "cap": 5, "tags": ["speed", "mass"],
		"verb": "Ride low", "text": "+5% cruise speed", "mods": {"cruise": 1.05}},

	# Defense (9).
	"rivet_seam": {"maker": "fleet_surplus", "touches": "roll", "base": "defense", "rarity": "common", "stack": "linear", "cap": 6, "tags": ["mass"],
		"verb": "Seam the hull", "text": "+15 max health", "max_hp_bonus": 15.0},
	"shock_liner": {"maker": "spillway_works", "base": "defense", "rarity": "uncommon", "trigger": "on_damage_taken", "element": "arc", "stack": "capped",
		"cap": 3, "tags": ["arc", "mass"], "verb": "Line the hull live", "text": "Hits taken arc back at them",
		"effect": {"do": "return_arc", "share": 0.8, "reach": 12.0}},
	"crush_guard": {"maker": "fleet_surplus", "base": "defense", "rarity": "rare", "stack": "hyperbolic", "cap": 0.3, "tags": ["mass", "anchor"],
		"verb": "Guard against the crush", "text": "Take about 10% less damage",
		"effect": {"do": "damage_reduction", "per": 0.111}},
	"deflect_plate": {"maker": "spillway_works", "touches": "roll", "base": "defense", "rarity": "common", "trigger": "on_damage_taken", "stack": "capped", "cap": 3,
		"tags": ["mass"], "verb": "Angle the plate", "text": "5% chance a hit glances off",
		"effect": {"do": "heal_back", "chance": 0.05, "share": 1.0}},
	"brace_frame": {"maker": "waking", "touches": "jump", "base": "defense", "rarity": "uncommon", "trigger": "on_land", "stack": "capped", "cap": 1,
		"tags": ["mass", "kinetic"], "verb": "Brace on landing", "text": "Big drops blunt hits for 1s",
		"effect": {"do": "brace", "min_impact": 11.0, "window": 1.0, "share": 0.2}},
	"scrap_armor": {"maker": "fleet_surplus", "touches": "roll", "base": "defense", "rarity": "common", "stack": "linear", "cap": 2, "tags": ["mass"],
		"verb": "Wear your scrap", "text": "+1 max health per 50 mass", "effect": {"do": "hp_per_mass", "per": 1.0, "mass": 50.0, "cap_hp": 40.0}},
	"rebound_skin": {"maker": "waking", "base": "defense", "rarity": "rare", "trigger": "on_rebound", "stack": "capped", "cap": 1,
		"tags": ["mass", "speed"], "verb": "Skin off the heavy", "text": "After a rebound, its hits glance 1s",
		"effect": {"do": "brace", "window": 1.0, "share": 1.0, "min_impact": 0.0}},
	"warden_ward": {"maker": "fleet_surplus", "base": "defense", "rarity": "rare_plus", "trigger": "on_damage_taken", "stack": "capped", "cap": 1,
		"tags": ["mass", "anchor"], "verb": "Ward off the worst", "text": "Once a stage, hold health at 20%",
		"effect": {"do": "floor_hp", "floor": 0.2}},
	# The earned save (wave 19, "No free retry"): a killing hit leaves you at 20% health, once a run.
	# The flag lives in the run doc (run_state death_save_spent); the hook is build's death_save_hull.
	"spare_frame": {"maker": "fleet_surplus", "base": "defense", "rarity": "rare_plus", "stack": "capped", "cap": 1,
		"tags": ["mass", "anchor"], "verb": "Keep a spare frame", "text": "Once a run, a killing hit leaves you at 20%",
		"effect": {"do": "perk", "perk": "death_save", "floor": 0.2}},

	# Utility (8).
	"magnet_coil": {"maker": "fleet_surplus", "base": "utility", "rarity": "common", "stack": "linear", "cap": 4, "tags": ["mass", "anchor"],
		"verb": "Wind the magnet", "text": "Scrap magnet reaches 30% further", "magnet": 1.3},
	"cache_key": {"maker": "fleet_surplus", "touches": "roll", "base": "utility", "rarity": "uncommon", "trigger": "on_kill", "stack": "capped", "cap": 3,
		"tags": ["mass"], "verb": "Pick the cache", "text": "6% of kills drop bonus mass",
		"effect": {"do": "bonus_scrap", "chance": 0.06, "amount": 12}},
	"beacon_lamp": {"maker": "spillway_works", "touches": "roll", "base": "utility", "rarity": "common", "trigger": "timed", "stack": "capped", "cap": 1, "tags": ["arc"],
		"verb": "Light the beacon", "text": "Every 6s, the beacon pings", "effect": {"do": "ping", "every": 6.0, "target": "beacon"}},
	"fast_hands": {"maker": "moss", "touches": "roll", "base": "utility", "rarity": "common", "stack": "linear", "cap": 3, "tags": ["speed"],
		"verb": "Haggle with fast hands", "text": "Fabricator and shop prices -8%",
		"effect": {"do": "price_scale", "per": 0.08}},
	"echo_locator": {"maker": "waking", "touches": "roll", "base": "utility", "rarity": "uncommon", "trigger": "timed", "stack": "capped", "cap": 1,
		"tags": ["arc", "anchor"], "verb": "Ping the vault", "text": "Every 12s, the nearest vault pings",
		"effect": {"do": "ping", "every": 12.0, "target": "vault"}},
	"synergy_lens": {"maker": "mind_glass", "base": "utility", "rarity": "rare", "stack": "capped", "cap": 1, "tags": ["chain", "split"],
		"verb": "Read the ingredients", "text": "Hint marks name their synergy early", "effect": {"do": "perk", "perk": "lens"}},
	"salvage_drone": {"maker": "fleet_surplus", "base": "utility", "rarity": "rare", "trigger": "on_kill", "stack": "capped", "cap": 1,
		"tags": ["mass", "speed"], "verb": "Launch a salvage drone", "text": "4% of kills pull in mass for 4s",
		"effect": {"do": "drone", "chance": 0.04, "seconds": 4.0, "magnet": 3.0}},
	"par_chip": {"maker": "mind_glass", "base": "utility", "rarity": "rare_plus", "stack": "capped", "cap": 1, "tags": ["speed", "anchor"],
		"verb": "Race your own ghost", "text": "Clock shows a split against best",
		"effect": {"do": "perk", "perk": "par"}},
}

# Moss's charge cells (DESIGN-V2 section 12): the stockpile path you pay for. A cell is
# a part, so it rides the run's part list (a retry restores it), adds heft like any
# part and can be sold back. Only Moss sells them; the pool never rolls one. Two per
# slot at most from the shop.
const CELLS_FOR := {"weapon": "cell_weapon", "movement": "cell_movement", "special": "cell_special", "smash": "cell_smash"}
const CELLS := {
	"cell_weapon": {"maker": "moss", "base": "charge", "rarity": "uncommon", "stack": "capped", "cap": 2, "tags": ["mass"], "shop_only": true,
		"name": "Weapon Cell", "verb": "Fit a weapon cell", "text": "+1 weapon charge", "charges": {"weapon": 1}},
	"cell_movement": {"maker": "moss", "base": "charge", "rarity": "uncommon", "stack": "capped", "cap": 2, "tags": ["mass"], "shop_only": true,
		"name": "Movement Cell", "verb": "Fit a movement cell", "text": "+1 movement charge", "charges": {"movement": 1}},
	"cell_special": {"maker": "moss", "base": "charge", "rarity": "uncommon", "stack": "capped", "cap": 2, "tags": ["mass"], "shop_only": true,
		"name": "Special Cell", "verb": "Fit a special cell", "text": "+1 special charge", "charges": {"special": 1}},
	"cell_smash": {"maker": "moss", "base": "charge", "rarity": "uncommon", "stack": "capped", "cap": 2, "tags": ["mass"], "shop_only": true,
		"name": "Smash Cell", "verb": "Fit a smash cell", "text": "+1 smash charge", "charges": {"smash": 1}},
}
