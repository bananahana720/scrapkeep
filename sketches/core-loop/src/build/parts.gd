extends RefCounted

const PartDef := preload("res://src/build/part_def.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Items := preload("res://src/build/items.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Nemesis := preload("res://src/combat/nemesis.gd")
const Relics := preload("res://src/build/relics.gd")
const HotwireRules := preload("res://src/build/hotwire_rules.gd")

# The parts catalogue (TADR-008): one row per part, turned into typed PartDef resources
# once and cached. Each row has a verb (what it makes you do), punch (flat per-hit
# weapon damage it adds), one or two tags from PartDef.TAGS, and a rarity set by where
# it comes from. Effects are multipliers on named knobs, pattern levels, element
# triggers and pickup dials, so build_sheet.gd can fold any list of held parts into
# the same sheet every time. SEAMS.md lists the ids combat reads.
#
# Rules (DEMO-SPEC): only a common part may be percentage-only; every other rarity
# brings punch, a pattern, an element or a behaviour. Of every gate pair, at least one
# part raises punch or transforms a pattern. Tier drives the fabricator price.
#
# SG15 levels: a row with "levels" is picked in PartDef.MAX_LEVEL levels, a capped stack of
# that many copies. levels[n - 1] holds level n's numbers (level 1 repeats the row's own), the
# copies held pick the level, and the sheet folds that one level once, so a higher level
# replaces the lower and never adds to it. A part at its top level is never offered again.
#
# Scaling: tier 1 is +10 to 15%, tier 2 +25%, tier 3 +50%, and copies multiply;
# pattern levels and punch add. A stage-1 build is modest and a late one absurd
# (build_parts_test measures it); combat caps what is drawn.

# SG5 start values, comps/gunfire/scrolls-and-synergies.md:86 and comps/README.md row 7:
# payout approaches this share of the triggering hit; copies steepen, never raise the cap.
const BURDEN_PAYOUT_CAP := 0.75
const BURDEN_PAYOUT_SLOPE := 0.25

const CATALOGUE := {
	"load_dividend": {"maker": "redjaw", "touches": "fire", "name": "Load Dividend", "verb": "Burdens add extra hit damage", "text": "Each burden adds hit damage, up to +%d%%" % roundi(BURDEN_PAYOUT_CAP * 100.0),
		"rarity": "rare", "tier": 2, "family": "weapon", "tags": ["mass"], "icon": "damage",
		"trigger": "on_hit", "stack": "hyperbolic", "cap": BURDEN_PAYOUT_CAP,
		"effect": {"do": "burden_payout", "per": BURDEN_PAYOUT_SLOPE}},
	# Common: gate fodder. Only these may be plain percentages.
	"hot_rivets": {"maker": "fleet_surplus", "touches": "fire", "name": "Hot Rivets", "verb": "Hit harder", "text": "+4 punch, +12% weapon damage",
		"rarity": "common", "tier": 1, "family": "weapon", "tags": ["kinetic"], "punch": 4.0,
		"mods": {"weapon_damage": 1.12}, "stack": "capped", "cap": 3, "levels": [
			{"punch": 4.0, "mods": {"weapon_damage": 1.12}, "text": "+4 punch, +12% weapon damage"},
			{"punch": 8.0, "mods": {"weapon_damage": 1.25}, "text": "+8 punch, +25% weapon damage"},
			{"punch": 13.0, "mods": {"weapon_damage": 1.42}, "text": "+13 punch, +42% weapon damage"}]},
	"loose_trigger": {"maker": "highdraft_roosts", "touches": "fire", "name": "Loose Trigger", "verb": "Fire faster", "text": "+10% fire rate",
		"rarity": "common", "tier": 1, "family": "weapon", "tags": ["speed"],
		"mods": {"weapon_rate": 1.1}},
	"long_barrel": {"maker": "highdraft_roosts", "touches": "fire", "name": "Long Barrel", "verb": "Shoot farther", "text": "+12% weapon range",
		"rarity": "common", "tier": 1, "family": "weapon", "tags": ["anchor"],
		"mods": {"weapon_range": 1.12}},
	"long_spool": {"name": "Long Spool", "verb": "Harpoon reaches farther", "text": "+30% harpoon range",
		"rarity": "common", "tier": 1, "family": "mobility", "tags": ["anchor"],
		"mods": {"rope_range": 1.3}},
	"tread_plating": {"name": "Tread Plating", "verb": "Roll faster", "text": "+8% cruise speed",
		"rarity": "common", "tier": 1, "family": "mobility", "tags": ["speed"],
		"mods": {"cruise": 1.08}},
	"boost_coil": {"name": "Boost Coil", "verb": "Boost and dash refill sooner", "text": "Boost and dash refill 15% sooner",
		"rarity": "common", "tier": 1, "family": "mobility", "tags": ["speed"],
		"cooldown_scale": 0.85},
	"dash_vane": {"name": "Dash Vane", "verb": "Dash harder", "text": "+15% air dash",
		"rarity": "common", "tier": 1, "family": "mobility", "tags": ["speed"],
		"mods": {"dash_impulse": 1.15}},
	"rivet_plating": {"maker": "fleet_surplus", "touches": "roll", "name": "Rivet Hull", "verb": "Raise your max health", "text": "+15 max health",
		"rarity": "common", "tier": 1, "family": "stat", "tags": ["mass"],
		"max_hp_bonus": 15.0, "stack": "capped", "cap": 3, "levels": [
			{"max_hp_bonus": 15.0, "text": "+15 max health"},
			{"max_hp_bonus": 30.0, "text": "+30 max health"},
			{"max_hp_bonus": 48.0, "text": "+48 max health"}]},
	"magnet_spool": {"maker": "spillway_works", "touches": "roll", "name": "Magnet Spool", "verb": "Pull scrap from farther", "text": "scrap magnet reaches 50% further",
		"icon": "utility", "rarity": "common", "tier": 1, "family": "stat", "tags": ["mass"],
		"magnet": 1.5, "stack": "capped", "cap": 3, "levels": [
			{"magnet": 1.5, "text": "scrap magnet reaches 50% further"},
			{"magnet": 2.25, "text": "scrap magnet reaches 125% further"},
			{"magnet": 3.4, "text": "scrap magnet reaches 240% further"}]},
	# W13 SR9: a copy tightens the Hold the Relay ring and speeds its charge. The numbers
	# under "relay" are read by hold_relay.gd tuned(); a capped stack of three copies. The
	# seam keeps it out of every offer until the director wires the relay (follow-up).
	"relay_convergence": {"name": "Relay Convergence", "verb": "Relay ring shrinks, charges faster", "pitch": "Ring pulls in, charge quickens",
		"text": "Tighter relay ring, faster charge", "icon": "utility",
		"rarity": "common", "tier": 1, "family": "stat", "tags": ["arc"], "needs": "relay.convergence",
		"stack": "capped", "cap": 3, "relay": {"radius_div": 2.0, "charge_per": 0.3}},
	# Wave 11 GP2: one part for each verb the alpha pool barely touched (roll, harpoon, boost,
	# jump, haul; special is the rare Spare Cell). Each changes its verb through one number and
	# adds no key. "touches" is the Bindings verb, "pitch" the shelf's three words.
	# 2026-10-15 (wave 14 PC-POOL, Bible Mobility row, Andrew 2026-10-12): movement that changes
	# how a pilot moves belongs to that pilot. Grip Tread, Vent Baffle and Spring Shims keep
	# their numbers and become class parts of the pilot whose Shift they deepen (Rivet's sprint,
	# Tally's surge, Sable's vault). Live Line and Drop Weight stay shared, because they are the
	# second ingredients of two evolutions, and change what the verb does instead of how fast
	# the ball moves: how wide the harpoon's lock cone opens (it targets more, the ball goes no
# farther or faster), how hard a smash throws its pins (drop_weight's base row was slam_speed 1.15).
	"grip_tread": {"maker": "highdraft_roosts", "name": "Grip Tread", "verb": "Accelerate faster", "pitch": "Tread bites harder", "touches": "roll",
		"text": "+15% drive acceleration", "icon": "mobility",
		"rarity": "common", "tier": 1, "family": "mobility", "class_id": "runner_gunner", "tags": ["anchor"],
		"mods": {"drive_accel": 1.15}},
	"live_line": {"maker": "mind_glass", "name": "Live Line", "verb": "Harpoon locks on wider", "pitch": "Harpoon grabs wider", "touches": "harpoon",
		"text": "+25% harpoon lock cone", "icon": "mobility",
		"rarity": "common", "tier": 2, "family": "mobility", "tags": ["arc"],
		"mods": {"harpoon_lock_deg": 1.25}},
	"vent_baffle": {"maker": "spillway_works", "name": "Vent Baffle", "verb": "Boost again sooner", "pitch": "Boost breathes quicker", "touches": "boost",
		"text": "Boost refills 12% sooner", "icon": "mobility",
		"rarity": "common", "tier": 1, "family": "mobility", "class_id": "tally", "tags": ["speed"],
		"cooldown_scale": 0.88},
	# 2026-10-15 (wave 14 SQ19b, BIBLE.md Mobility row): Tally's own winch. A trial with reel_speed
	# at 1.25 while held took Tally's stage-2 Brindle fight from 340 s to 80 s. A class part,
	# like Vent Baffle, because a faster haul changes how fast the ball moves.
	"winch_pawl": {"maker": "redjaw", "name": "Winch Pawl", "verb": "Reel in faster", "pitch": "Winch hauls quicker", "touches": "harpoon",
		"text": "+25% winch top speed", "icon": "mobility",
		"rarity": "common", "tier": 1, "family": "mobility", "class_id": "tally", "tags": ["anchor"],
		"mods": {"reel_speed": 1.25}},
	"spring_shims": {"maker": "redjaw", "name": "Spring Shims", "verb": "Jump higher", "pitch": "Hop clears rails", "touches": "jump",
		"text": "+10% jump speed", "icon": "mobility",
		"rarity": "common", "tier": 1, "family": "mobility", "class_id": "pylon_engineer", "tags": ["spiral"],
		"mods": {"jump_speed": 1.1}},
	"drop_weight": {"maker": "moss", "name": "Drop Weight", "verb": "Post-smash, knocked machines hit 25% harder", "pitch": "Knocks hit harder", "touches": "haul",
		"text": "After a smash, knocked machines hit 25% harder", "icon": "mobility",
		"rarity": "common", "tier": 1, "family": "mobility", "tags": ["mass"],
		"trigger": "on_smash", "stack": "linear", "cap": 3,
		"effect": {"do": "pin_bonus", "bonus": 0.25, "window": 1.5}},

	# Uncommon: gates and fabricators. Punch, a pattern or an element on every row.
	"slag_rounds": {"maker": "fleet_surplus", "touches": "fire", "name": "Slag Rounds", "verb": "Hit much harder", "text": "+10 punch, +25% weapon damage",
		"rarity": "common", "tier": 2, "family": "weapon", "tags": ["kinetic", "mass"], "punch": 10.0,
		"mods": {"weapon_damage": 1.25}},
	"double_feed": {"maker": "fleet_surplus", "touches": "fire", "name": "Double Feed", "verb": "Fire much faster", "text": "+3 punch, +25% fire rate",
		"rarity": "common", "tier": 2, "family": "weapon", "tags": ["speed", "split"], "punch": 3.0,
		"mods": {"weapon_rate": 1.25}},
	"focus_lens": {"maker": "mind_glass", "touches": "fire", "name": "Focus Lens", "verb": "Shoot much farther", "text": "+6 punch, +25% weapon range",
		"rarity": "common", "tier": 2, "family": "weapon", "tags": ["anchor"], "punch": 6.0,
		"mods": {"weapon_range": 1.25}},
	# Pattern transformers. The part id is the pattern id, and each copy adds a level.
	# 2026-10-15 C7: round-1 arm at 0.6 gives worlds 1-3 margins 28.8%,
	# last/first 2.25x, null pair -14.1%. Coordinator-authorized scalar.
	"cross_split": {"maker": "redjaw", "touches": "fire", "name": "Cross Split", "verb": "Split shots into a cross", "text": "shots split four ways on impact",
		"rarity": "common", "tier": 2, "family": "pattern", "tags": ["split"],
		"patterns": {"cross_split": 1}, "mods": {"weapon_damage": 0.6}},
	"spiral_wave": {"maker": "waking", "touches": "fire", "name": "Spiral Wave", "verb": "Spiral shots out in a wave", "text": "shots corkscrew outward",
		"rarity": "common", "tier": 2, "family": "pattern", "tags": ["spiral"],
		"patterns": {"spiral_wave": 1}},
	"chain_arc": {"maker": "mind_glass", "touches": "fire", "name": "Chain Arc", "verb": "Chain hits to a neighbour", "text": "a hit jumps to the nearest machine",
		"rarity": "common", "tier": 2, "family": "pattern", "tags": ["chain", "arc"],
		"patterns": {"chain_arc": 1}},
	"frost_vane": {"name": "Frost Vane", "verb": "Dash trails frost", "text": "air dash freezes water into road",
		"element": "frost", "rarity": "common", "tier": 2, "family": "mobility", "tags": ["frost", "speed"],
		"elements": {"dash": "frost"}, "mods": {"dash_impulse": 1.1}},
	# Arc Coil and Runner Overclock carry one tag: kinetic was not their identity, and on
	# them it put Wrecking Ball over the 60% discovery cap (balance loop, B4).
	"arc_coil": {"maker": "moss", "touches": "haul", "name": "Arc Coil", "verb": "Slams burst arcs nearby", "text": "Slams burst arcs at everything near",
		"element": "arc", "rarity": "common", "tier": 2, "family": "mobility", "tags": ["arc"],
		"elements": {"slam": "arc"}},
	# Class mods: offered only to their class.
	"pylon_capacitor": {"maker": "spillway_works", "touches": "jump", "name": "Pylon Capacitor", "verb": "Launch harder off pylons", "text": "+8 punch, slingshot +50% boost",
		"icon": "mobility", "rarity": "common", "tier": 2, "family": "class", "class_id": "pylon_engineer", "tags": ["anchor", "arc"],
		"punch": 8.0, "mods": {"slingshot_boost": 1.5, "slingshot_keep": 1.1, "turret_damage": 1.4}},
	"runner_overclock": {"maker": "highdraft_roosts", "touches": "fire", "name": "Runner Overclock", "verb": "Fire faster, boost refills sooner", "text": "+35% fire rate, boost refills 20% sooner",
		"icon": "damage", "rarity": "common", "tier": 2, "family": "class", "class_id": "runner_gunner", "tags": ["speed"],
		"punch": 4.0, "mods": {"weapon_rate": 1.35}, "cooldown_scale": 0.8},

	# Rare: vaults, and gates with one bonus core.
	# W1-64: Sunforged Core and Spare Cell each carry a trigger, so a Warden gate's cobalt changes
	# how a fight plays. Sunforged keeps its numbers and adds a doubled hit every 6 s.
	"sunforged_core": {"maker": "waking", "touches": "fire", "name": "Sunforged Core", "verb": "Hit far harder, doubled every 6s", "text": "+22 punch, +50% damage, doubled hit every 6s",
		"rarity": "rare", "tier": 3, "family": "weapon", "tags": ["kinetic", "mass"], "punch": 22.0,
		"mods": {"weapon_damage": 1.5}, "trigger": "timed",
		"effect": {"do": "arm_hit", "every": 6.0, "bonus": 1.0}},
	"gatling_heart": {"maker": "fleet_surplus", "touches": "fire", "name": "Gatling Heart", "verb": "Fire far faster", "text": "+5 punch, +50% fire rate",
		"rarity": "rare", "tier": 3, "family": "weapon", "tags": ["spiral", "speed"], "punch": 5.0,
		"mods": {"weapon_rate": 1.5}},
	"horizon_optic": {"maker": "highdraft_roosts", "touches": "fire", "name": "Horizon Optic", "verb": "Hit harder from much farther", "text": "+12 punch, +50% range, +15% weapon damage",
		"rarity": "rare", "tier": 3, "family": "weapon", "tags": ["anchor", "kinetic"], "punch": 12.0,
		"mods": {"weapon_range": 1.5, "weapon_damage": 1.15}},
	"rime_rounds": {"maker": "spillway_works", "touches": "fire", "name": "Rime Rounds", "verb": "Shots freeze water", "text": "+6 punch. Shots freeze water.",
		"element": "frost", "rarity": "rare", "tier": 3, "family": "weapon", "tags": ["frost", "kinetic"], "punch": 6.0,
		"elements": {"shot": "frost"}},
	"galvanic_rounds": {"maker": "mind_glass", "touches": "fire", "name": "Galvanic Rounds", "verb": "Shots electrify water", "text": "+6 punch. Shots electrify water.",
		"element": "arc", "rarity": "rare", "tier": 3, "family": "weapon", "tags": ["arc", "chain"], "punch": 6.0,
		"elements": {"shot": "arc"}},
	"ram_plow": {"maker": "fleet_surplus", "touches": "roll", "name": "Ram Plow", "verb": "Hit harder, gain 15 max health", "text": "+18 punch, +15 max health",
		"icon": "damage", "rarity": "rare", "tier": 3, "family": "stat", "tags": ["kinetic", "mass"], "punch": 18.0,
		"max_hp_bonus": 15.0},
	"spare_cell": {"maker": "moss", "name": "Spare Cell", "verb": "Kills refill your special", "pitch": "One cell extra", "touches": "special",
		"text": "+1 special charge. Kills refill it, 12s apart.", "icon": "charge",
		"rarity": "rare", "tier": 3, "family": "stat", "tags": ["mass"],
		"charges": {"special": 1}, "trigger": "on_kill", "stack": "capped", "cap": 1,
		"effect": {"do": "grant_charge", "slot": "special", "every": 12.0}},

	# Rare-plus: won events, and gates with two or more bonus cores.
	"tempest_core": {"name": "Tempest Core", "verb": "Levels up spiral and chain shots", "text": "spiral +2, chain +1, +30% fire rate",
		"rarity": "relic", "tier": 3, "family": "milestone", "milestone_only": true, "tags": ["spiral", "chain"],
		"patterns": {"spiral_wave": 2, "chain_arc": 1}, "mods": {"weapon_rate": 1.3}},
	"rime_heart": {"name": "Rime Heart", "verb": "Freeze the water you roll on", "text": "Water under you freezes, +10% cruise speed",
		"icon": "mobility", "element": "frost", "rarity": "relic", "tier": 3, "family": "milestone", "milestone_only": true, "tags": ["frost", "mass"],
		"elements": {"roll_on_water": "frost"}, "mods": {"cruise": 1.1}},
	"scrap_gravity": {"name": "Scrap Gravity", "verb": "Pull scrap in, kills drop double", "text": "+8 punch, magnet x2.5, kills drop double scrap",
		"icon": "utility", "rarity": "relic", "tier": 3, "family": "milestone", "milestone_only": true, "tags": ["mass"],
		"punch": 8.0, "magnet": 2.5, "kill_scrap": 2.0},
}

# Which rarities each source grants (DEMO-SPEC "Engagement tiers" and "Cores").
const SOURCE_RARITIES := {
	"fabricator": ["common"],
	"vault": ["rare"],
	"milestone": ["relic"],
}

# Which milestone part each participatory event awards. An event not listed here
# awards the first milestone part the run does not hold yet, in MILESTONE_ORDER.
const MILESTONE_FOR_EVENT := {
	"surge_run": "rime_heart",
	"hold_the_relay": "tempest_core",
}
const MILESTONE_ORDER := ["scrap_gravity", "tempest_core", "rime_heart"]

# How often an offer slot is spent on the named partner (completing_part) of a held part whose
# maker is one piece short of waking a trick. Isaac's "one more piece" pull, kept off a sure
# thing. 0.35 since the pass D fold (was 0.5): more parts name a maker now, so the pull finds a
# partner more often; 0.35 keeps every pilot's kit lean in its band (offer_weights_test).
const SYNERGY_BAIT := 0.35

# "Nudge loot" for maker sets (maker_sets.gd): once MAKER_NUDGE_AT distinct pieces of one maker
# are held, that maker's other pieces weigh MAKER_NUDGE times their offer bucket's other parts
# inside whichever group a slot draws from, the same lean matchup counters get. Each bucket keeps
# its total weight in each group (_nudged), so a pilot's kit, shelf, movement and pair shares hold
# (offer_weights_test): the nudge picks which piece of a bucket shows, never which bucket.
const MAKER_NUDGE_AT := 2
# 1.1 since the pass D fold (was 1.5): with every world 1 part naming a maker the nudge fires on
# far more draws, and 1.5 moved bucket shares past offer_weights_test's 0.03 drift bar.
const MAKER_NUDGE := 1.1
# Off only for a measurement that needs the kit lean alone on a fixed seed (offer_weights_test).
static var maker_nudge_on := true

# 2026-10-18 (w17 answers): "Nudge loot" for matchups (Andrew, 2026-10-17 00:01Z: "Bad matchups:
# counter items show up 1.5x as often; still luck."). A part whose ANSWERS tags hold one of the
# pilot's nemesis axes (Nemesis.PILOT, design-v3/ENEMY-PRIORITY.md sections 4 lever 8 and 5) weighs
# Nemesis.OFFER_WEIGHT times its offer bucket's other parts inside whichever group a slot draws
# from, through the same _nudged pass as the maker nudge: every group and bucket keeps its share, so
# the SQ19 kit-share bands hold by construction (answer_weights_test). It sits in roll(), so every
# source that rolls parts leans (gates, shop shelf and hook, caches, fabricators, activities). It is
# a lean on a draw and never a guarantee. The table is here, not on the rows, so the pinned
# parts.rows digest and the other wave-17 cards that re-pin it stay untouched; ids absent read [].
# damage_tier, rate_tier and range_tier (pattern.gd) are pattern tiers, not offerable parts: their
# catalogue analogues carry the tag (weapon damage for plating, fire rate for fuse, range for range).
#   range    long_barrel, focus_lens, horizon_optic, tracer_round (weapon_range).
#   spread   cross_split, spiral_wave, chain_arc, fan_spread, helix_drill, ring_wave, tempest_core
#            (patterns and pulses that hit more than one target), arc_coil, static_burr (arcs).
#   fuse     tracer_round (section 5), loose_trigger, double_feed, gatling_heart (weapon_rate: a
#            faster cycle lands before a fast mover leaves).
#   cc       brace_frame (section 5) only: no other part plainly breaks or prevents a hold.
#   air      none: no pilot's nemesis is air yet, so nothing is tagged until one is.
#   plating  hot_rivets, slag_rounds, sunforged_core, ram_plow, overpressure (weapon_damage and punch
#            per hit), warhead_slug, clean_break (plating-specific), ballast_drum (section 5).
const ANSWERS := {
	"long_barrel": ["range"], "focus_lens": ["range"], "horizon_optic": ["range"],
	"tracer_round": ["range", "fuse"],
	"cross_split": ["spread"], "spiral_wave": ["spread"], "chain_arc": ["spread"], "fan_spread": ["spread"],
	"helix_drill": ["spread"], "ring_wave": ["spread"], "tempest_core": ["spread"], "arc_coil": ["spread"],
	"static_burr": ["spread"],
	"loose_trigger": ["fuse"], "double_feed": ["fuse"], "gatling_heart": ["fuse"],
	"brace_frame": ["cc"],
	"hot_rivets": ["plating"], "slag_rounds": ["plating"], "sunforged_core": ["plating"], "ram_plow": ["plating"],
	"overpressure": ["plating"], "warhead_slug": ["plating"], "clean_break": ["plating"], "ballast_drum": ["plating"],
}
# Off only for a measurement that needs the draw without the answer lean (answer_weights_test).
static var answer_nudge_on := true

# The pattern guarantee (balance loop, B4): a run that reaches stage 2's gates holding no
# pattern transformer is offered one of these in that pair. Bots without a pattern took
# 117 to 204 s on Warden III against 19 to 81 s with one, a split HP tuning cannot close.
# The other gate stays a free choice.
const PATTERN_PARTS := ["spiral_wave", "cross_split", "chain_arc"]
const PATTERN_GUARANTEE_STAGE := 2
# The rung a Warden's gate pair and the shop's first shelf slot never fall below: rare (cobalt).
const RUNG_FLOOR := 1

# v2 W4 loot: how often an offer slot is a freshly generated recipe (item_gen.gd)
# instead of an authored row. The rest of the pool is the catalogue above plus the
# item table (items.gd).
const GENERATED_SHARE := 0.25

# SQ19 weighted offers (comps/roboquest/classes-and-perks.md:82, comps/gunfire/heroes-and-ascensions.md:87).
# A pilot's kit is its own class rows plus every part in one of its two buckets (bucket_of) that
# carries one of that bucket's tags below. The two buckets are the pilot's dominant offer pair,
# one of the pairs of weapon, skill, defence and movement. Defence + movement cannot be a measured
# pair while every gate pair holds a part that hits harder (offer_weights_test PAIRS), so five pairs
# are reachable for six pilots (coordinator ruling W8, 2026-10-15): Tarn and Tally share weapon +
# defence, kinetic hitters against split ones, and every other pilot's pair is its own. Each kit
# holds a common part that hits harder, so the hitter in a gate pair can come from the kit.
# Pylon's defence half leaves the mass plates to the shelf: with them its top offers shared half
# their parts with Rivet's.
# Kest's movement half is its class rows only: Frost Vane as a kit part came back as synergy bait
# often enough to put Kest's random-bot movement at 15.2%, over the 15% cap.
# A pilot not listed here (or an empty class) draws exactly as before.
const KITS := {
	"pylon_engineer": {"skill": ["arc", "anchor"], "defence": ["arc", "anchor", "kinetic"]},
	"runner_gunner": {"skill": ["speed"], "movement": ["speed"]},
	"demolitions_caster": {"weapon": ["arc", "chain", "frost", "spiral"], "movement": []},
	"tarn": {"weapon": ["kinetic"], "defence": ["kinetic", "anchor"]},
	"tally": {"weapon": ["split"], "defence": ["speed", "mass"]},
	"remembered_cannon": {"weapon": ["mass"], "skill": ["mass", "kinetic", "speed"]},
}
# Target: 70% of a listed pilot's offered parts come from its kit (band 60 to 80%). The rest is the
# neutral shelf, plus a generated recipe GENERATED_SHARE of those neutral slots off the slice.
const KIT_SHARE := 0.7
# The most of one slot's odds a single kit part may hold (start value): on a short part list a
# one-part kit would otherwise put that part in nearly every draw.
const KIT_PART_CAP := 0.25
# Target: 12% of a movement pilot's offers are movement parts (the comps cap is 15%; bait and the
# generated recipes add a few points on top). A kit slot
# draws from the kit's movement parts this share of the time over KIT_SHARE; never more, even
# when the kit's other bucket is empty, so movement cannot fill an offer. A pilot whose pair has
# no movement bucket still sees its own class movement rows, at CLASS_MOVEMENT_SHARE each.
# 2026-10-15 (wave 14 SQ19b, coordinator ruling S2): each class movement row in the slot's
# candidates brings its own CLASS_MOVEMENT_SHARE, up to MOVEMENT_SHARE in all, so Tally's second
# movement row (Winch Pawl) adds to Vent Baffle's share instead of splitting it.
const MOVEMENT_SHARE := 0.12
const CLASS_MOVEMENT_SHARE := 0.06
# The neutral shelf: small flat parts every pilot can be offered, so a build never stalls on its
# kit. A shelf part in a pilot's kit counts as kit for that pilot. One in the pilot's non-weapon
# bucket is drawn NEUTRAL_LEAN times as often as the others (the shelf feeds the second half of
# the pair; the weapon half comes from the kit's hitters); a weapon-and-movement pilot, whose
# movement half has no shelf parts, leans to weapon. For a pilot whose pair has no weapon half, a
# weapon shelf part weighs NEUTRAL_WEAPON_EASE: the stage-2 pattern and any off-kit hitter
# already bring it weapon, so the shelf feeds its own pair instead. None is offered again
# once a stage's offered count for it reaches NEUTRAL_REPEAT_CAP.
const NEUTRAL_SHELF := ["hot_rivets", "loose_trigger", "long_barrel", "rivet_plating", "rivet_seam", "magnet_spool", "fast_hands"]
const NEUTRAL_LEAN := 4.0
const NEUTRAL_WEAPON_EASE := 0.1
const NEUTRAL_REPEAT_CAP := 2

# Hot-wired parts (BUILD-SYSTEMS.md, Two hot-wired parts). Not in CATALOGUE, so they never
# enter rows(), ids(), offer_pool() or roll(): a hot-wired part is offered by authorship,
# never drawn as loot. Each row names both consequences with an icon id and at most three
# words; "{armor}", "{armor_x}", "{steer}", "{bonus}", "{wear}" and "{wear_x}" are resolved from
# HotwireRules.fill, so the words follow the tuning; the label is the gate card's line
# (_hotwired_spec). Nothing here equips a part: build.gd puts one at the gates after Warden I
# (pass D fold; the Fit / Recycle choice is retired). recycle_commons is what a burden pays.
# Spark Tread needs armour mode too: its cost is rolling wear, which only armour mode takes.
# Burden start values (SG4; comps/gunfire/scrolls-and-synergies.md:86 sweep of 0 to 10 burdens,
# survival bar in burden_parts_test): each burden is a small pure cost, so ten stay a felt
# downside and not a trap. One named place, never spread across the rows.
const BURDEN_HP := 4.0
const BURDEN_SCRAP_LOSS := 0.05
const BURDEN_MAGNET_LOSS := 0.10
# Hot-wired parts held at once (SG4): one in world one, as before; from world 2 more than one.
# A start value. Burdens never count against it.
const HOTWIRE_CAP_WORLD_ONE := 1
const HOTWIRE_CAP_LATER := 2
const HOTWIRED := {
	"riveted_shell": {"name": "Riveted Shell", "tags": ["mass"], "maker": "fleet_surplus", "needs_armor": true, "recycle_commons": 2,
		"label": "{armor} armour. Air steering \u2212{steer}%.",
		"upside": {"icon": "cat_defense", "words": "{armor_x}x armour"},
		"downside": {"icon": "cat_mobility", "words": "Air steering \u2212{steer}%"}},
	"spark_tread": {"name": "Spark Tread", "tags": ["kinetic", "arc"], "maker": "spillway_works", "needs_armor": true, "recycle_commons": 3,
		"label": "Big signature hits. {wear} rolling wear.",
		"upside": {"icon": "cat_damage", "words": "+{bonus}% signature hit"},
		"downside": {"icon": "cat_defense", "words": "{wear_x}x rolling wear"}},
	# Burden parts (SG4, comps/gunfire/scrolls-and-synergies.md:86): rare, a pure stated downside, no
	# upside side. Not loot: only a visible optional pocket's pay.named pays one. "part" is the
	# part's own row (row(), def() and has() find it there; rows() never lists it, so no shelf,
	# gate or tree offer can roll it); "{hp}", "{scrap}" and "{magnet}" are resolved from that row
	# by burden_cost(), so the words follow the numbers.
	"cracked_plating": {"name": "Cracked Hull", "tags": ["mass"], "burden": true, "recycle_commons": 1,
		"label": "Costs {hp} max health.",
		"downside": {"icon": "cat_defense", "words": "−{hp} max health"},
		"part": {"verb": "Costs max health", "family": "stat", "max_hp_bonus": -BURDEN_HP}},
	"thin_pickings": {"name": "Thin Pickings", "tags": ["anchor"], "burden": true, "recycle_commons": 1,
		"label": "Costs {scrap}% scrap per kill.",
		"downside": {"icon": "cat_utility", "words": "−{scrap}% kill scrap"},
		"part": {"verb": "Costs kill scrap", "family": "stat", "kill_scrap": 1.0 - BURDEN_SCRAP_LOSS}},
	"slack_coil": {"name": "Slack Coil", "tags": ["arc"], "burden": true, "recycle_commons": 1,
		"label": "Costs {magnet}% magnet reach.",
		"downside": {"icon": "cat_utility", "words": "−{magnet}% magnet reach"},
		"part": {"verb": "Costs magnet reach", "family": "stat", "magnet": 1.0 - BURDEN_MAGNET_LOSS}},
}
# One common part's recycle value in cogs (design-v3/research/economy/ECONOMY.md, Cogs: recycling).
const RECYCLE_COMMON := 10

# The four Evolved parts (their ingredient pairs are Synergies.EVOLUTIONS). Not in CATALOGUE, so
# they never enter rows(), ids(), offer_pool(), roll() or roll_gate(): build.gd grants one when
# both ingredients are held (source "evolution"). Rarity evolved carries roll weight 0 too.
const EVOLVED := {
	"breaker_drive": {"name": "Breaker Drive", "verb": "Hit 35% harder, +8 punch", "text": "+8 punch, +35% weapon damage. From Wrecking Ball.",
		"rarity": "evolved", "tier": 3, "family": "weapon", "tags": ["kinetic", "speed"], "punch": 8.0,
		"mods": {"weapon_damage": 1.35}},
	"bladestorm_rotor": {"name": "Bladestorm Rotor", "verb": "Spiral level up, fire faster", "text": "Spiral level +1, +20% fire rate. From Pinwheel.",
		"rarity": "evolved", "tier": 3, "family": "pattern", "tags": ["spiral", "speed"], "patterns": {"spiral_wave": 1},
		"mods": {"weapon_rate": 1.2}},
	"storm_mast": {"name": "Storm Mast", "verb": "Fire 20% faster, +6 punch", "text": "+6 punch, +20% fire rate. From Tesla Pylon.",
		"rarity": "evolved", "tier": 3, "family": "weapon", "tags": ["anchor", "arc"], "punch": 6.0,
		"mods": {"weapon_rate": 1.2}},
	"grounding_spike": {"name": "Grounding Spike", "verb": "Hit 25% harder, +8 punch", "text": "+8 punch, +25% weapon damage. From Lightning Rod.",
		"rarity": "evolved", "tier": 3, "family": "weapon", "tags": ["arc", "mass"], "punch": 8.0,
		"mods": {"weapon_damage": 1.25}},
}

static var _defs := {}
static var _run_ref: WeakRef


# One run sets the tier every rarity roll reads. A bare RunState (no event bus: a tool's or a
# test's, built beside the game's) never takes the binding from a live run on a bus, or the
# game's rolls would read that stand-in's tier.
static func bind_run(run) -> void:
	var held = _run_ref.get_ref() if _run_ref != null else null
	if held != null and held != run and held.get("events") != null and (run == null or run.get("events") == null):
		return
	_run_ref = weakref(run)


static func active_tier() -> int:
	var run = _run_ref.get_ref() if _run_ref != null else null
	return run.selected_run_tier() if run != null else 0


static func _pick_rarity(rng: RandomNumberGenerator, allowed: Array) -> String:
	if active_tier() == 0:
		return ItemGen.pick_rarity(rng, allowed)
	var total := 0.0
	var weights := {}
	for rarity in allowed:
		weights[rarity] = ItemGen.weight_of(rarity) * (RunTier.row(active_tier()).rare_weight if rarity == "rare" else 1.0)
		total += weights[rarity]
	var x := rng.randf() * total
	for rarity in allowed:
		x -= weights[rarity]
		if x < 0.0:
			return rarity
	return allowed[-1]

static var _rows := {}
# Seams other modules offer ("spawner.extend_cloak"). A row whose needs is not here is
# never offered; build fills this at setup from what the live modules answer.
static var seams := {}
# Rows the shift board opened for this profile (shift_board.gd opened_items), id -> true. They
# join a listed table's pool beside its own list; game.gd sets them at run_started, never for a
# bot or a test, so an empty map leaves every pool as the table lists it.
static var opened_items := {}


# Every authored row: the catalogue above, the v2 item table and Moss's cells, finished
# by the generator. Generated recipes are not listed; row() builds them on demand.
static func rows() -> Dictionary:
	if _rows.is_empty():
		for key in CATALOGUE:
			_rows[key] = _settled(CATALOGUE[key])
		for key in Items.TABLE:
			_rows[key] = _settled(ItemGen.finish(key, Items.TABLE[key]))
		for key in Items.CELLS:
			_rows[key] = _settled(ItemGen.finish(key, Items.CELLS[key]))
	return _rows


# The one place a row's rarity is settled, authored or generated: an old id resolves
# through RARITY_ALIASES, and a row whose effects are only percentage scalars cannot sit
# above common (DEMO-SPEC), so it drops to common.
static func _settled(spec: Dictionary) -> Dictionary:
	var out := spec.duplicate(true)
	var rarity := ItemGen.resolve_rarity(String(spec.get("rarity", "common")))
	out["rarity"] = rarity if rarity != "" else "common"
	if out["rarity"] != "common" and PartDef.from_row("_", out).percentage_only():
		out["rarity"] = "common"
	return out


# A part's rarity, always one of ItemGen.RARITIES; common for an id the build does not know.
static func rarity_of(part_id: String) -> String:
	return String(row(part_id).get("rarity", "common"))


static func row(part_id: String, tier := -1) -> Dictionary:
	var base := _base_row(part_id)
	return RunTier.effective_part(part_id, base, active_tier() if tier < 0 else tier)


static func _base_row(part_id: String) -> Dictionary:
	var authored: Dictionary = rows().get(part_id, {})
	if not authored.is_empty():
		return authored
	if EVOLVED.has(part_id):
		return _settled(EVOLVED[part_id])
	if is_burden(part_id):
		return _settled(_burden_spec(part_id))
	if Relics.is_relic(part_id):
		return Relics.part_row(part_id)
	if HOTWIRED.has(part_id):
		return _hotwired_spec(part_id)
	var generated := ItemGen.generated_row(part_id)
	return _settled(generated) if not generated.is_empty() else generated


# SG15 admission for one row: no levels, or exactly PartDef.MAX_LEVEL of them on a capped row
# with stack_cap MAX_LEVEL; each level names only LEVEL_KEYS the row itself sets (mods only
# its knobs); level 1 is the row's own numbers; and no number falls from one level to the
# next. Returns one line per problem; [] is clean.
static func level_problems(part_id: String, r: Dictionary) -> Array:
	var levels: Array = r.get("levels", [])
	if levels.is_empty():
		return []
	var out: Array = []
	if levels.size() != PartDef.MAX_LEVEL:
		out.append("%s has %d levels, not %d" % [part_id, levels.size(), PartDef.MAX_LEVEL])
	if r.get("stack", "linear") != "capped" or int(r.get("cap", 0)) != PartDef.MAX_LEVEL:
		out.append("%s levels need a capped stack of %d" % [part_id, PartDef.MAX_LEVEL])
	var mods: Dictionary = r.get("mods", {})
	for i in levels.size():
		var lv: Dictionary = levels[i]
		for key in lv:
			if not key in PartDef.LEVEL_KEYS or not r.has(key):
				out.append("%s level %d sets %s, which the row does not" % [part_id, i + 1, key])
		for knob in lv.get("mods", {}):
			if not mods.has(knob):
				out.append("%s level %d moves %s, which the row does not" % [part_id, i + 1, knob])
		if i == 0:
			for key in lv:
				if lv[key] != r.get(key):
					out.append("%s level 1 %s is %s, the row says %s" % [part_id, key, lv[key], r.get(key)])
			continue
		var prev: Dictionary = levels[i - 1]
		for key in ["punch", "max_hp_bonus", "magnet"]:
			if lv.has(key) and float(lv[key]) < float(prev.get(key, r.get(key, lv[key]))):
				out.append("%s level %d %s falls" % [part_id, i + 1, key])
		for knob in lv.get("mods", {}):
			if float(lv["mods"][knob]) < float(prev.get("mods", mods).get(knob, 1.0)):
				out.append("%s level %d %s falls" % [part_id, i + 1, knob])
	return out


# The def and the headline an offer card shows for part_id to a run holding held: the level
# the pick would give (SG15). Every card builder (reward_gates, fabricators, shop) reads these,
# never def() or headline() on an offered id; part_levels_test guards it.
static func offer_def(part_id: String, held: Array) -> Resource:
	return def_at(part_id, next_level(part_id, held))


static func offer_headline(part_id: String, held: Array) -> String:
	return headline(part_id, next_level(part_id, held))


# The level taking part_id now would give: one past its level in held. 1 for a part with no levels.
static func next_level(part_id: String, held: Array) -> int:
	return mini(level_of(part_id, held) + 1, PartDef.MAX_LEVEL)


# part_id's level in held: its copies, at most PartDef.MAX_LEVEL; 0 when not held or not levelled.
static func level_of(part_id: String, held: Array) -> int:
	var d: Resource = def(part_id)
	if d == null or d.levels.is_empty():
		return 0
	return mini(held.count(part_id), PartDef.MAX_LEVEL)


# True when part_id is levelled and held at its top level: no offer shows it.
static func maxed(part_id: String, held: Array) -> bool:
	return level_of(part_id, held) >= PartDef.MAX_LEVEL


# Overpowered pays (17 Oct): true when another copy of part_id adds nothing, a levelled part at
# its top level or a linear or capped part held at stack_cap copies (BuildSheet.from_parts stops
# folding there). Hyperbolic rows keep growing; spike rows stay offered too, on the safe side,
# because their effect value (PartDef.Stacking) keeps its own ceiling.
static func stacked_out(part_id: String, held: Array) -> bool:
	if maxed(part_id, held):
		return true
	var d: Resource = def(part_id)
	if d == null or not d.levels.is_empty() or not d.stack_rule in ["linear", "capped"] or d.stack_cap < 1.0:
		return false
	return held.count(part_id) >= int(d.stack_cap)


# A stacked-out pick swaps for a part left in the pool under its repeat cap, of the same kit side and bucket when one
# is left, else of the same bucket, else any; with none left the slot goes. The draw keeps its
# kit and bucket lean, so a strong build's offers keep their shape.
static func _swap_stacked_out(rng: RandomNumberGenerator, class_id: String, held: Array, picks: Array, pool: Array,
		offered: Dictionary) -> Array:
	var out: Array = []
	var left: Array = _uncapped(class_id, pool, offered).filter(func(key): return not stacked_out(key, held) and not key in picks)
	for key in picks:
		if not stacked_out(key, held):
			out.append(key)
			continue
		# The swap keeps what roll() promised: a harder hitter stays a harder hitter and a shelf
		# part stays a shelf part (the pair rule and _keep_a_neutral), when the pool has one.
		var hard: bool = def(key).hits_harder()
		var shelf: bool = key in NEUTRAL_SHELF
		var kept: Array = left.filter(func(k): return (not hard or def(k).hits_harder()) and (not shelf or k in NEUTRAL_SHELF))
		if kept.is_empty():
			kept = left
		var bucket := bucket_of(key)
		var kit := in_kit(class_id, key)
		var same: Array = kept.filter(func(k): return bucket_of(k) == bucket and in_kit(class_id, k) == kit)
		if same.is_empty():
			same = kept.filter(func(k): return bucket_of(k) == bucket)
		if same.is_empty():
			same = kept
		if same.is_empty():
			continue
		var swap: String = same[rng.randi_range(0, same.size() - 1)]
		out.append(swap)
		left.erase(swap)
	return out


# part_id's def at level (1 to PartDef.MAX_LEVEL): its row with that level's numbers in place.
# def() for a part with no levels.
static func def_at(part_id: String, level: int) -> Resource:
	var base: Resource = def(part_id)
	if base == null or base.levels.is_empty():
		return base
	level = clampi(level, 1, base.levels.size())
	var key := "%d@%s:%s" % [active_tier(), level, part_id]
	if not _defs.has(key):
		var r := row(part_id).duplicate(true)
		r.merge(base.levels[level - 1], true)
		var d: Resource = PartDef.from_row(part_id, r)
		d.level = level
		_defs[key] = d
	return _defs[key]


static func def(part_id: String) -> Resource:
	var tier := active_tier()
	var key := "1:" + part_id if tier != RunTier.BASE and RunTier.ENHANCED.has(part_id) else part_id
	if not _defs.has(key):
		var r := row(part_id, tier)
		if r.is_empty():
			return null
		_defs[key] = PartDef.from_row(part_id, r)
	return _defs[key]


static func has(part_id: String) -> bool:
	return rows().has(part_id) or EVOLVED.has(part_id) or HOTWIRED.has(part_id) or Relics.is_relic(part_id) or ItemGen.is_generated(part_id) and not ItemGen.parse(part_id).is_empty()


# The authored pool, catalogue first. Generated recipes are unbounded and not listed.
static func ids() -> Array:
	return rows().keys()


# The hot-wired row for an id, or {} when the id is not hot-wired.
static func hotwired(part_id: String) -> Dictionary:
	return HOTWIRED.get(part_id, {})


# The hot-wired parts an offer may show. A part that needs armour mode (Riveted Shell is a
# pure downside without it, DESIGN-NOTES H1) is left out when armor_mode is false. At most
# one hot-wired part is held in world one and hotwire_cap(world) from world 2, so nothing is
# offered once the cap is held; a held copy is never offered again. A burden is never offered
# here (a pocket's pay.named is its only door) and never counts against the cap. Pure: read
# armor_mode from tuning.armor() or RunState.armor_mode, world from RunState.world.
static func hotwire_offer(armor_mode: bool, held: Array = [], world := 1) -> Array:
	var held_count := held.filter(func(key): return HOTWIRED.has(key) and not is_burden(key)).size()
	if held_count >= hotwire_cap(world):
		return []
	var out: Array = []
	for key in HOTWIRED:
		if is_burden(key) or key in held:
			continue
		if HOTWIRED[key].get("needs_armor", false) and not armor_mode:
			continue
		out.append(key)
	return out


# How many hot-wired parts a pilot may hold in this world: one in world one, more from world 2.
static func hotwire_cap(world: int) -> int:
	return HOTWIRE_CAP_WORLD_ONE if world <= 1 else HOTWIRE_CAP_LATER


static func is_burden(part_id: String) -> bool:
	return bool(HOTWIRED.get(part_id, {}).get("burden", false))


# The burden ids, in row order.
static func burdens() -> Array:
	return HOTWIRED.keys().filter(func(key): return is_burden(key))


# A burden's shown cost: one icon and at most three words, the numbers read from its own part
# row. {} for an id that is not a burden.
static func burden_cost(part_id: String) -> Dictionary:
	if not is_burden(part_id):
		return {}
	var cost: Dictionary = HOTWIRED[part_id]["downside"]
	return {"icon": cost["icon"], "words": _burden_fill(cost["words"], HOTWIRED[part_id]["part"])}


static func _burden_fill(text: String, part: Dictionary) -> String:
	return text.replace("{hp}", str(int(round(-float(part.get("max_hp_bonus", 0.0)))))) \
		.replace("{scrap}", str(int(round((1.0 - float(part.get("kill_scrap", 1.0))) * 100.0)))) \
		.replace("{magnet}", str(int(round((1.0 - float(part.get("magnet", 1.0))) * 100.0))))


# A burden's part row: its authored fields, rare, with the shown label as its text.
static func _burden_spec(part_id: String) -> Dictionary:
	var hot: Dictionary = HOTWIRED[part_id]
	var spec: Dictionary = hot["part"].duplicate(true)
	spec["name"] = hot["name"]
	spec["tags"] = hot["tags"]
	spec["rarity"] = "rare"
	spec["tier"] = 1
	spec["icon"] = String(hot["downside"]["icon"]).trim_prefix("cat_")
	spec["text"] = _burden_fill(hot["label"], hot["part"])
	return spec


# A hot-wired part's row on the ladder: a rare, one copy, its maker, its label as the card line.
# It carries no stat: build.gd reads the held id (shell_held, tread_fitted). Not in rows(), so
# no shelf, pool or roll draws it; the Warden's gates put it up (build.gd).
static func _hotwired_spec(part_id: String) -> Dictionary:
	var hot: Dictionary = HOTWIRED[part_id]
	var line := HotwireRules.fill(hot["label"])
	return {"name": hot["name"], "verb": line, "text": line, "tags": hot["tags"], "maker": hot["maker"],
		"rarity": "rare", "tier": 2, "family": "stat", "icon": String(hot["upside"]["icon"]).trim_prefix("cat_"),
		"cap": 1, "stack": "capped"}


# Cogs a hot-wired part recycles for; 0 for an id that is not hot-wired.
static func hotwire_recycle(part_id: String) -> int:
	return int(hotwired(part_id).get("recycle_commons", 0)) * RECYCLE_COMMON


static func seam_met(need: String) -> bool:
	return need == "" or seams.get(need, false)


static func display_name(part_id: String) -> String:
	var d: Resource = def(part_id)
	if d != null:
		return d.display_name
	return String(token(part_id).get("name", part_id.replace("_", " ").capitalize()))


# Run tokens: ids a run holds as parts (run.add_part) with no catalogue row, so they are never
# offered, rolled or read as a build part. Each row is what the token's reveal shows: its name,
# its card line and its stamp.
const TOKENS := {
	"admirals_crest": {"name": "Admiral's Crest", "verb": "Fleet property. Yours now.", "stamp": "TROPHY"},
}


static func token(part_id: String) -> Dictionary:
	return TOKENS.get(part_id, {})


static func tags_of(part_id: String) -> Array:
	var d: Resource = def(part_id)
	return d.tags if d != null else []


# The icon a part shows where it stands for itself (the why callout): its element's icon when it
# carries one, else its category icon; "" for an unknown id.
static func icon_of(part_id: String) -> String:
	var d: Resource = def(part_id)
	if d == null:
		return ""
	if d.element != "":
		return "el_" + d.element
	return "cat_" + (d.icon_category if d.icon_category != "" else "utility")


# The gate label's first line: "{name}: {verb}. Punch +{n}".
# level picks a levelled part's numbers (SG15: an offer shows the level it would give).
static func headline(part_id: String, level := 1) -> String:
	var d: Resource = def_at(part_id, level)
	if d == null:
		return display_name(part_id)
	var line := "%s: %s." % [d.display_name, d.verb]
	if d.punch > 0.0:
		line += " +%d punch" % int(d.punch)
	return line


# The shop's detail line: the name, then the part's own effect sentence with its numbers, and the
# punch when the sentence does not already carry it. No label before the sentence.
static func shop_line(part_id: String, level := 1) -> String:
	var d: Resource = def_at(part_id, level)
	if d == null:
		return display_name(part_id)
	var line := "%s. %s" % [d.display_name, d.text.substr(0, 1).to_upper() + d.text.substr(1)]
	if d.punch > 0.0 and not "punch" in d.text.to_lower():
		line += ". +%d punch" % int(d.punch)
	return line


# shop_line for the level taking part_id now would give.
static func offer_shop_line(part_id: String, held: Array) -> String:
	return shop_line(part_id, next_level(part_id, held))


static func milestone_ids() -> Array:
	var list: Array = []
	for key in rows():
		if rows()[key].get("milestone_only", false):
			list.append(key)
	return list


# One tag list per held part, in order: what the synergy rules read.
static func tag_sets(held: Array) -> Array:
	var sets: Array = []
	for part_id in held:
		sets.append(tags_of(part_id))
	return sets


# A part's maker ("spillway_works", "moss", ...), or "" for a part no maker made (a generated
# recipe, an Evolved part, a burden, a token). Relics and hot-wired parts carry theirs.
static var _maker_of := {}


static func maker_of(part_id: String) -> String:
	if not _maker_of.has(part_id):
		_maker_of[part_id] = String(row(part_id).get("maker", "")) if has(part_id) else ""
	return _maker_of[part_id]


# Held parts that set shop and fabricator prices: every part but relics, which come from caches
# and never through a till (pass D fold: a relic on the ladder adds no price step).
static func priced_count(held: Array) -> int:
	return held.filter(func(part_id): return not Relics.is_relic(String(part_id))).size()


# maker -> distinct pieces in held: a copy of a piece already held is not a second piece.
static func maker_counts(held: Array) -> Dictionary:
	var seen := {}
	var out := {}
	for part_id in held:
		var maker := maker_of(String(part_id))
		if maker == "" or seen.has(part_id):
			continue
		seen[part_id] = true
		out[maker] = int(out.get(maker, 0)) + 1
	return out


# The maker trick taking part_id now would wake, or "" (Synergies.AT pieces of one maker).
static func completed_by(part_id: String, held: Array) -> String:
	if part_id in held:
		return ""
	return Synergies.completed_by(maker_counts(held), maker_of(part_id))


# The maker trick taking part_id now would start toward, or "": the first piece of its maker.
static func started_by(part_id: String, held: Array) -> String:
	if part_id in held:
		return ""
	return Synergies.started_by(maker_counts(held), maker_of(part_id))


# The part in pool that would wake a maker trick as its named pair, or "": the callout partner
# of a held part whose maker is one piece short. Any piece of that maker wakes the trick, but
# the bait pulls only the named one, so the "one more piece" slot stays as rare as the old
# named pairs' and does not crowd out each pilot's kit lean (offer_weights_test).
static func completing_part(held: Array, pool: Array) -> String:
	var counted := maker_counts(held)
	var wanted := {}
	for trick_id in Synergies.ROWS:
		var call := Synergies.callout(trick_id)
		if call.is_empty() or not Synergies.in_play(trick_id) or int(counted.get(Synergies.ROWS[trick_id]["maker"], 0)) != Synergies.AT - 1:
			continue
		if call["a"] in held and not call["b"] in held:
			wanted[call["b"]] = true
		elif call["b"] in held and not call["a"] in held:
			wanted[call["a"]] = true
	for key in pool:
		if wanted.has(key):
			return key
	return ""


# Gate tiers by overcharge: 0 bonus cores offer common, 1 common or rare, 2 or more
# rare or relic.
# The cobalt rung's Warden floor (item ladder, wave 20): a gate pair always holds a rare or
# better, and since W1-64 that rare changes behaviour (PartDef.changes_behaviour: a trigger, a
# pattern or an element), so the Warden's guaranteed find is a new way to play, not a bigger
# number. When the roll brought no such part, a behaviour rare drawn the same way takes the slot
# of a stat-only rare in the pair, else its first pick that is not a pattern part (stage 2's
# guarantee); cores still lift the other. When the slot held the pair's only harder hitter, the
# rare drawn hits harder too. A pair short of count (the pool ran dry) gains the rare instead,
# and a pair of patterns keeps its first. With no behaviour rare left any rare stands in.
# Callers outside the Warden's gates (tests that read common shares, the tools) never pass
# through it.
static func floor_gate(rng: RandomNumberGenerator, picks: Array, class_id: String, held: Array,
		offered: Dictionary = {}, count := 2) -> Array:
	if picks.is_empty() or picks.any(func(key): return rung_of(key) >= RUNG_FLOOR and changes_behaviour(key)):
		return picks
	var out := picks.duplicate()
	var slot := -1
	for i in out.size():
		if rung_of(out[i]) >= RUNG_FLOOR:
			slot = i
			break
	if slot < 0:
		slot = 0
		while slot < out.size() and out[slot] in PATTERN_PARTS:
			slot += 1
	var others: Array = out.filter(func(key): return key != out[slot]) if slot < out.size() else out
	var needs_hitter: bool = slot < out.size() and def(out[slot]) != null and def(out[slot]).hits_harder() \
		and not others.any(func(key): return def(key) != null and def(key).hits_harder())
	var plain: Array = offer_pool(class_id, ["rare"]).filter(func(key): return not changes_behaviour(key) \
		or (needs_hitter and not def(key).hits_harder()))
	var cobalt: Array = roll(rng, ["rare"], class_id, held, 1, picks + plain, offered)
	if cobalt.is_empty():
		cobalt = roll(rng, ["rare"], class_id, held, 1, picks, offered)
	if cobalt.is_empty():
		return picks
	if slot < out.size():
		out[slot] = cobalt[0]
	elif out.size() < count:
		out.append(cobalt[0])
	else:
		out[-1] = cobalt[0]
	return out


static func changes_behaviour(part_id: String) -> bool:
	var d: Resource = def(part_id)
	return d != null and d.changes_behaviour()


# A part's rung on the ladder: 0 common, 1 rare, 2 relic, 3 evolved (ItemGen.RARITIES order).
static func rung_of(part_id: String) -> int:
	var d: Resource = def(part_id)
	return maxi(0, ItemGen.RARITIES.find(ItemGen.resolve_rarity(String(d.rarity)))) if d != null else 0


static func gate_rarities(bonus_cores: int) -> Array:
	if bonus_cores >= 2:
		return ["rare", "relic"]
	if bonus_cores == 1:
		return ["common", "rare"]
	return ["common"]


# True while the build runs on a table that names its parts (the slice). Then the pool is
# that list, no slot is a generated recipe and the shop never falls back to one.
static func listed_only() -> bool:
	return Synergies.table != null and Synergies.table.parts_listed()


# The parts a source may offer this class, at these rarities. Never another class's mod.
static func offer_pool(class_id: String, rarities: Array) -> Array:
	rarities = ItemGen.resolve_rarities(rarities)
	var pool: Array = []
	var all := rows()
	var listed := listed_only()
	for key in all:
		var r: Dictionary = all[key]
		if listed and not Synergies.table.part_in_play(key) and not opened_items.has(key):
			continue
		if is_burden(key):
			continue
		if not r["rarity"] in rarities or r.get("shop_only", false) or not seam_met(r.get("needs", "")):
			continue
		var only: String = r.get("class_id", "")
		if only != "" and only != class_id:
			continue
		pool.append(key)
	return pool


# A part's offer bucket, one of weapon, skill, defence or movement, read from its row's family,
# touches and mods: a smash or special verb (touches haul or special) is skill; a class part skill
# (the pilot's own kit, whatever verb it touches); a weapon or pattern part, or one that touches
# fire, weapon; a mobility part, or a cruise mod, movement. A stat or milestone row has no verb
# of its own, so its family's shown category (the row's icon, else PartDef.ICON_FOR_FAMILY) splits
# it: defense is defence, damage or transform weapon, mobility movement, the rest skill.
static func bucket_of(part_id: String) -> String:
	var r := row(part_id)
	var family := String(r.get("family", ""))
	var touches := String(r.get("touches", ""))
	if touches in ["haul", "special"] or family == "class":
		return "skill"
	if family in ["weapon", "pattern"] or touches == "fire":
		return "weapon"
	if family == "mobility" or r.get("mods", {}).has("cruise"):
		return "movement"
	var shown: String = r.get("icon", PartDef.ICON_FOR_FAMILY.get(family, "utility"))
	match shown:
		"defense":
			return "defence"
		"damage", "transform":
			return "weapon"
		"mobility":
			return "movement"
	return "skill"


# True when part_id is in class_id's kit (KITS): its own class row, or a part in one of the kit's
# buckets carrying one of that bucket's tags. False for a pilot with no kit.
static func in_kit(class_id: String, part_id: String) -> bool:
	if not KITS.has(class_id):
		return false
	var r := row(part_id)
	if String(r.get("class_id", "")) == class_id:
		return true
	var tags: Array = KITS[class_id].get(bucket_of(part_id), [])
	return r.get("tags", []).any(func(tag): return tag in tags)


# A neutral slot's candidates: shelf parts in the pool, outside the pilot's kit, under the cap.
static func _neutral_slot(class_id: String, pool: Array, offered: Dictionary) -> Array:
	return pool.filter(func(key): return key in NEUTRAL_SHELF and not in_kit(class_id, key) \
		and int(offered.get(key, 0)) < NEUTRAL_REPEAT_CAP)


# The pool without the shelf parts this stage has offered NEUTRAL_REPEAT_CAP times.
static func _uncapped(class_id: String, pool: Array, offered: Dictionary) -> Array:
	return pool.filter(func(key): return not key in NEUTRAL_SHELF or in_kit(class_id, key) \
		or int(offered.get(key, 0)) < NEUTRAL_REPEAT_CAP)


# One weighted slot for a pilot with a kit, drawn with a single rng.randf() so a listed slot costs
# the rarity draw and one pick, as before. Off the slice a generated recipe first takes its share
# of the shelf's part (one more draw). The rolled rarity's uncapped parts split into four groups:
# the kit's movement parts (MOVEMENT_SHARE; for a pilot whose pair has no movement,
# CLASS_MOVEMENT_SHARE per class movement row, at most MOVEMENT_SHARE), its other parts (the rest of KIT_SHARE), the shelf (1 - KIT_SHARE) and the rest of the
# pool (0). An empty group's share moves on: kit to shelf, shelf to kit, both to the rest; movement's
# own share goes to the kit's other parts, and movement never takes another group's share unless
# nothing else is left. Inside a group a part weighs 1 / (1 + times offered this stage), times
# NEUTRAL_LEAN for a shelf part in the pilot's lean bucket. No part of the rolled rarity: any rarity.
static func _lean_slot(rng: RandomNumberGenerator, rarity: String, class_id: String, pool: Array,
		offered: Dictionary, picks: Array, exclude: Array, nudge: Dictionary = {}) -> String:
	if not listed_only() and rng.randf() < (1.0 - KIT_SHARE) * GENERATED_SHARE:
		var recipe := ItemGen.roll_id(rng, rarity)
		return "" if recipe in picks or recipe in exclude else recipe
	var slot := slot_weights(rarity, class_id, pool, offered, nudge)
	if slot["candidates"].is_empty():
		return ""
	return _pick_weight(rng, slot["candidates"], slot["weights"])


# A kit slot's candidates and the weight of each (the odds _lean_slot draws by), without the
# draw: {"candidates": Array, "weights": Dictionary}. Split out so answer_weights_test reads the
# odds exactly instead of sampling them.
static func slot_weights(rarity: String, class_id: String, pool: Array, offered: Dictionary,
		nudge: Dictionary = {}) -> Dictionary:
	var kit: Dictionary = KITS[class_id]
	var open := _uncapped(class_id, pool, offered)
	var candidates: Array = open.filter(func(key): return rows()[key]["rarity"] == rarity)
	if candidates.is_empty():
		candidates = open
	if candidates.is_empty():
		return {"candidates": [], "weights": {}}
	var groups := {"moving": [], "still": [], "shelf": [], "rest": []}
	for key in candidates:
		if in_kit(class_id, key):
			groups["moving" if bucket_of(key) == "movement" else "still"].append(key)
		elif key in NEUTRAL_SHELF:
			groups["shelf"].append(key)
		else:
			groups["rest"].append(key)
	var moving := MOVEMENT_SHARE if kit.has("movement") \
		else minf(MOVEMENT_SHARE, CLASS_MOVEMENT_SHARE * groups["moving"].size())
	var share := {"moving": moving, "still": KIT_SHARE - moving, "shelf": 1.0 - KIT_SHARE, "rest": 0.0}
	if groups["moving"].is_empty():
		share["still"] += share["moving"]
		share["moving"] = 0.0
	if groups["still"].is_empty():
		share["shelf"] += share["still"]
		share["still"] = 0.0
	if groups["shelf"].is_empty():
		share["still"] += share["shelf"]
		share["shelf"] = 0.0
	if groups["still"].is_empty() and groups["shelf"].is_empty():
		share["rest"] += share["still"] + share["shelf"]
	if groups["rest"].is_empty() and share["rest"] > 0.0:
		share["moving"] += share["rest"]
	var weights := {}
	for name in groups:
		var raw := {}
		var sum := 0.0
		for key in groups[name]:
			var b := bucket_of(key)
			var lean := 1.0
			if name == "shelf" and kit.has(b) and (b != "weapon" or kit.has("movement")):
				lean = NEUTRAL_LEAN
			elif name == "shelf" and b == "weapon" and not kit.has("weapon"):
				lean = NEUTRAL_WEAPON_EASE
			raw[key] = lean / (1.0 + offered.get(key, 0))
			sum += raw[key]
		for key in raw:
			weights[key] = share[name] * raw[key] / sum
	# No kit part takes more than KIT_PART_CAP of a slot (a one-part kit on a short list would
	# otherwise show that part in almost every draw); the excess goes to the shelf, else the rest.
	var excess := 0.0
	for key in groups["moving"] + groups["still"]:
		if weights[key] > KIT_PART_CAP:
			excess += weights[key] - KIT_PART_CAP
			weights[key] = KIT_PART_CAP
	for name in ["shelf", "rest"]:
		if excess > 0.0 and not groups[name].is_empty():
			var room := 0.0
			for key in groups[name]:
				room += weights[key]
			for key in groups[name]:
				weights[key] += excess * (weights[key] / room if room > 0.0 else 1.0 / groups[name].size())
			excess = 0.0
	# The maker nudge goes last, on the settled weights, inside each group's buckets: it never
	# feeds the cap's excess to the shelf, so every group and bucket keeps its share.
	if not nudge.is_empty():
		for name in groups:
			var part: Dictionary = {}
			for key in groups[name]:
				part[key] = weights[key]
			part = _nudged(part, nudge)
			for key in part:
				weights[key] = part[key]
	return {"candidates": candidates, "weights": weights}


# One draw over keys by weight; a zero total picks uniformly by the same draw.
static func _pick_weight(rng: RandomNumberGenerator, keys: Array, weights: Dictionary) -> String:
	var total := 0.0
	for key in keys:
		total += weights.get(key, 0.0)
	var x := rng.randf()
	if total <= 0.0:
		return keys[mini(int(x * keys.size()), keys.size() - 1)]
	x *= total
	for key in keys:
		x -= weights.get(key, 0.0)
		if x < 0.0:
			return key
	return keys[-1]


static func milestone_for(event_id: String, held: Array) -> String:
	if MILESTONE_FOR_EVENT.has(event_id):
		return MILESTONE_FOR_EVENT[event_id]
	for key in MILESTONE_ORDER:
		if not key in held:
			return key
	return MILESTONE_ORDER[0]


# Picks count distinct parts from the pool at these rarities. One slot may go to the
# part that completes a synergy the run is one piece from. Every other slot draws its
# rarity by the rarity weights (common 87, rare 10, relic 3), then is
# a generated recipe GENERATED_SHARE of the time, else an authored row of that rarity,
# weighted down by how often offered (id to count this stage) has shown it, so a stage
# rarely shows the same part twice. A pair always holds at least one part that raises
# punch or transforms a pattern.
static func roll(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		exclude: Array = [], offered: Dictionary = {}) -> Array:
	rarities = ItemGen.resolve_rarities(rarities)
	var pool: Array = offer_pool(class_id, rarities).filter(func(key): return not key in exclude and not maxed(key, held))
	var picks: Array = []
	var leans := KITS.has(class_id)
	var nudge := answer_nudge(class_id, pool, maker_nudge(held, pool))
	var bait := _bait(class_id, held, pool, offered, count)
	if bait != "" and rng.randf() < SYNERGY_BAIT:
		picks.append(bait)
		pool.erase(bait)
	var tries := 0
	while picks.size() < count and not pool.is_empty() and tries < count * 8:
		tries += 1
		var rarity := _pick_rarity(rng, rarities)
		if leans:
			var slot := _lean_slot(rng, rarity, class_id, pool, offered, picks, exclude, nudge)
			if slot != "":
				picks.append(slot)
				pool.erase(slot)
			continue
		if not listed_only() and rng.randf() < GENERATED_SHARE:
			var recipe := ItemGen.roll_id(rng, rarity)
			if not recipe in picks and not recipe in exclude and not stacked_out(recipe, held):
				picks.append(recipe)
			continue
		var bucket: Array = pool.filter(func(key): return rows()[key]["rarity"] == rarity)
		if bucket.is_empty():
			bucket = pool
		var chosen := _weighted(rng, bucket, offered, {}, nudge)
		picks.append(chosen)
		pool.erase(chosen)
	if picks.size() >= 2 and not picks.any(func(key): return def(key).hits_harder()):
		var harder: Array = pool.filter(func(key): return def(key).hits_harder())
		if leans:
			# A leaning pilot's harder part comes from its kit (a non-movement one first), else
			# the shelf under its cap, else any uncapped part.
			var kit: Array = harder.filter(func(key): return in_kit(class_id, key))
			var still: Array = kit.filter(func(key): return bucket_of(key) != "movement")
			var shelf: Array = _neutral_slot(class_id, harder, offered)
			for side in [still, kit, shelf, _uncapped(class_id, harder, offered)]:
				if not side.is_empty():
					harder = side
					break
		# A leaning pilot's harder part takes the last slot past the bait that is not a kit
		# movement part, so the swap does not eat the kit's movement share; else the last slot.
		var at := picks.size() - 1
		if leans:
			var first := 1 if picks[0] == bait else 0
			for i in range(picks.size() - 1, first - 1, -1):
				if not (in_kit(class_id, picks[i]) and bucket_of(picks[i]) == "movement"):
					at = i
					break
		if not harder.is_empty():
			picks[at] = harder[rng.randi_range(0, harder.size() - 1)]
	if leans:
		_keep_a_neutral(rng, class_id, picks, pool, offered, 1 if not picks.is_empty() and picks[0] == bait else 0)
	return _swap_stacked_out(rng, class_id, held, picks, pool, offered)


# A leaning pilot's draw that holds no kit part still shows a shelf part: the first slot from first
# on (past the synergy bait) that is not the draw's only harder part becomes one, when an uncapped
# shelf part is left.
static func _keep_a_neutral(rng: RandomNumberGenerator, class_id: String, picks: Array, pool: Array,
		offered: Dictionary, first: int) -> void:
	if picks.is_empty() or picks.any(func(key): return in_kit(class_id, key) or key in NEUTRAL_SHELF):
		return
	var shelf := _neutral_slot(class_id, pool.filter(func(key): return not key in picks), offered)
	if shelf.is_empty():
		return
	var hitters: Array = picks.filter(func(key): return def(key).hits_harder())
	for i in range(first, picks.size()):
		# Only a slot of the shelf's own rarity turns, so the shown rarity odds hold.
		if rarity_of(picks[i]) != rarity_of(shelf[0]):
			continue
		if picks.size() < 2 or hitters.size() != 1 or picks[i] != hitters[0]:
			picks[i] = shelf[rng.randi_range(0, shelf.size() - 1)]
			return


# The part in pool that completes a synergy, or "". A leaning pilot's bait is never a shelf part at
# its repeat cap, and in a draw of two or more slots it is a kit or shelf part: the bait is half of
# such a draw, so an off-kit one would undo the lean. A one-slot draw (a fabricator, a pocket, the
# F004 gate) keeps the plain bait, preferring a kit or shelf one.
static func _bait(class_id: String, held: Array, pool: Array, offered: Dictionary, count: int) -> String:
	if not KITS.has(class_id):
		return completing_part(held, pool)
	var open := _uncapped(class_id, pool, offered)
	var near := completing_part(held, _near(class_id, open))
	return near if near != "" or count >= 2 else completing_part(held, open)


# The pool's kit parts and its shelf parts, in pool order.
static func _near(class_id: String, pool: Array) -> Array:
	return pool.filter(func(key): return in_kit(class_id, key) or key in NEUTRAL_SHELF)


# Offer-weight multipliers for pool given held: MAKER_NUDGE on each pool part not held whose
# maker has MAKER_NUDGE_AT or more distinct pieces in held. Empty when no maker is that far along.
static func maker_nudge(held: Array, pool: Array) -> Dictionary:
	if not maker_nudge_on:
		return {}
	var pieces := {}
	for part_id in held:
		var maker := String(rows().get(part_id, {}).get("maker", ""))
		if maker != "":
			if not pieces.has(maker):
				pieces[maker] = {}
			pieces[maker][part_id] = true
	var out := {}
	for part_id in pool:
		var maker := String(rows().get(part_id, {}).get("maker", ""))
		if maker != "" and (pieces.get(maker, {}) as Dictionary).size() >= MAKER_NUDGE_AT and not part_id in held:
			out[part_id] = MAKER_NUDGE
	return out


# A part's answer axes (ANSWERS); [] for any other id.
static func answers_of(part_id: String) -> Array:
	return ANSWERS.get(part_id, [])


# nudge with Nemesis.OFFER_WEIGHT multiplied onto each pool part that answers class_id's nemesis.
# nudge itself, untouched, when the pilot has no nemesis or no pool part answers it.
static func answer_nudge(class_id: String, pool: Array, nudge: Dictionary) -> Dictionary:
	if not answer_nudge_on or Nemesis.of(class_id).is_empty():
		return nudge
	var answering := _answering(class_id)
	var out := nudge
	var copied := false
	for part_id in pool:
		if answering.has(part_id):
			if not copied:
				out = nudge.duplicate()
				copied = true
			out[part_id] = float(out.get(part_id, 1.0)) * Nemesis.OFFER_WEIGHT
	return out


# The ANSWERS ids that answer class_id's nemesis, as a set; both tables are constants, so it is
# built once per class (Parts.roll calls answer_nudge on every offer).
static var _answering_by_class := {}


static func _answering(class_id: String) -> Dictionary:
	if not _answering_by_class.has(class_id):
		var ids := {}
		for part_id in ANSWERS:
			if Nemesis.answers(class_id, ANSWERS[part_id]):
				ids[part_id] = true
		_answering_by_class[class_id] = ids
	return _answering_by_class[class_id]


# raw (id to weight) with each nudged id's weight times its nudge, then every offer bucket
# rescaled to the total it had before, so the nudge moves weight between a bucket's own parts
# only. A bucket whose parts are all nudged, or none, is unchanged. raw itself when no nudge.
static func _nudged(raw: Dictionary, nudge: Dictionary) -> Dictionary:
	if nudge.is_empty():
		return raw
	var touched := false
	for key in nudge:
		if raw.has(key):
			touched = true
			break
	if not touched:
		return raw
	var before := {}
	var after := {}
	var out := {}
	var buckets := {}
	for key in raw:
		var b := bucket_of(key)
		buckets[key] = b
		out[key] = float(raw[key]) * float(nudge.get(key, 1.0))
		before[b] = float(before.get(b, 0.0)) + float(raw[key])
		after[b] = float(after.get(b, 0.0)) + out[key]
	for key in out:
		var b: String = buckets[key]
		if after[b] > 0.0:
			out[key] *= before[b] / after[b]
	return out


# lean: id to a weight multiplier (SQ19's neutral lean); nudge: a maker's offer nudge, applied
# inside each offer bucket (_nudged); absent ids weigh 1.
static func _weighted(rng: RandomNumberGenerator, bucket: Array, offered: Dictionary, lean: Dictionary = {},
		nudge: Dictionary = {}) -> String:
	var raw := {}
	var total := 0.0
	for key in bucket:
		raw[key] = lean.get(key, 1.0) / (1.0 + offered.get(key, 0))
	raw = _nudged(raw, nudge)
	for key in bucket:
		total += raw[key]
	var x := rng.randf() * total
	for key in bucket:
		x -= raw[key]
		if x < 0.0:
			return key
	return bucket[-1]


# True when a held part transforms a weapon pattern (the three pattern parts, Tempest Core).
static func holds_pattern(held: Array) -> bool:
	return held.any(func(key): return def(key) != null and not def(key).patterns.is_empty())


# A reward gate pair: roll(), then the pattern guarantee. On stage 2, when nothing held
# transforms a pattern and neither offer is a pattern part, the last slot becomes one.
# That slot is never the synergy bait (always first), and a pattern part hits harder, so
# the pair keeps both rules; a one-slot gate holding the bait keeps it and skips the
# pattern part. The pattern part comes from the gate's own rarities when one
# fits; at two or more bonus cores (rare and relic) none does, and only that slot
# drops to common. Any other stage, or a build that already holds a pattern, gets
# exactly what roll() gives for the same seed.
static func roll_gate(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		stage: int, offered: Dictionary = {}) -> Array:
	rarities = ItemGen.resolve_rarities(rarities)
	var picks: Array = roll(rng, rarities, class_id, held, count, [], offered)
	if stage != PATTERN_GUARANTEE_STAGE or count < 1 or holds_pattern(held) \
			or picks.any(func(key): return key in PATTERN_PARTS):
		return picks
	var eligible: Array = PATTERN_PARTS.filter(func(key): return def(key).rarity in rarities)
	if eligible.is_empty():
		eligible = PATTERN_PARTS.duplicate()
	if KITS.has(class_id):
		# SQ19: a leaning pilot's guaranteed pattern is a kit one when its kit has one.
		var own: Array = eligible.filter(func(key): return in_kit(class_id, key))
		eligible = own if not own.is_empty() else eligible
	var pattern: String = eligible[rng.randi_range(0, eligible.size() - 1)]
	if picks.size() < count:
		picks.append(pattern)
	elif picks.size() >= 2 or picks[0] != _bait(class_id, held, offer_pool(class_id, rarities), offered, count):
		picks[picks.size() - 1] = pattern
	return picks
