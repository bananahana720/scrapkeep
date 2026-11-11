extends RefCounted

# Kest's upgrade tree: hide, set up, burst. Heap order as in sable.gd. The left half
# sets up (Trapper); the right half hides (Ghost). Every leaf still hides by moving.

const NODES := [
	{"id": "k_trapper", "name": "Trapper", "effect": "Charges wait longer; five can be live", "key": "weapon",
		"icon": "ab_kest_weapon", "tags": ["traps"], "knob": {"sticky_fuse": 2.5, "sticky_max_live": 5}},

	{"id": "k_ghost", "name": "Ghost", "effect": "Cloaked, machines only spot you up close", "key": "movement",
		"icon": "ab_kest_cloak", "tags": ["stealth"], "knob": {"cloak_sight": 0.3}},


	{"id": "k_tripwire", "name": "Tripwire", "effect": "Charges trigger from two metres away", "key": "weapon",
		"icon": "ab_kest_weapon", "tags": ["traps"], "knob": {"sticky_reach": 2.0}},

	{"id": "k_demo_expert", "name": "Demo Expert", "effect": "Demo slams scatter five charges", "key": "smash",
		"icon": "ab_kest_smash", "tags": ["traps", "burst"], "knob": {"mini_count": 5}},

	{"id": "k_smoke_trail", "name": "Smoke Trail", "effect": "Gliding keeps you cloaked", "key": "movement",
		"icon": "ab_kest_glide", "tags": ["stealth", "air"], "knob": {"glide_cloak": true}},

	{"id": "k_ambush", "name": "Ambush", "effect": "Throwing no longer breaks your cloak", "key": "weapon",
		"icon": "ab_kest_cloak", "tags": ["stealth", "burst"], "knob": {"cloak_keep": true}},


	{"id": "k_minefield", "name": "Minefield", "effect": "Bank two sticky throws", "key": "weapon",
		"icon": "ab_kest_weapon", "tags": ["traps"], "charges": {"weapon": 1}, "swap": {"ultimate": "minelayer"}},

	{"id": "k_heavy_charge", "name": "Heavy Charge", "effect": "Two live charges, each bigger", "key": "weapon",
		"icon": "ab_kest_weapon", "tags": ["burst"], "knob": {"sticky_max_live": 2},
		"pattern": {"sticky_charge": {"mul": {"damage": 1.6, "bolt_radius": 1.3}}}, "swap": {"ultimate": "air_raid"}},

	{"id": "k_carpet", "name": "Carpet Bomb", "effect": "Gliding drops a charge every half second", "key": "smash",
		"icon": "ab_kest_glide", "tags": ["air", "traps"], "knob": {"glide_bombs": 0.5}, "swap": {"ultimate": "minelayer"}},

	{"id": "k_blast_jumper", "name": "Blast Jumper", "effect": "Your own blasts launch you, no Space", "key": "movement",
		"icon": "ab_kest_glide", "tags": ["air", "mobility"], "knob": {"rocket_auto": true}, "swap": {"ultimate": "air_raid"}},

	{"id": "k_mirage", "name": "Mirage", "effect": "Bank two smoke blinks", "key": "movement",
		"icon": "ab_kest_move", "tags": ["stealth", "mobility"], "charges": {"movement": 1}, "swap": {"ultimate": "air_raid"}},

	{"id": "k_dust_devil", "name": "Dust Devil", "effect": "Blinks drop a charge where you land", "key": "movement",
		"icon": "ab_kest_move", "tags": ["traps"], "proc": [{"on": "blink_used", "do": "charge", "scale": 1.0, "gap": 0.4}], "swap": {"ultimate": "minelayer"}},

	{"id": "k_marked", "name": "Marked", "effect": "The line marks targets for bigger blasts", "key": "special",
		"icon": "ab_kest_special", "tags": ["burst"], "knob": {"line_marks": 3.0}, "swap": {"ultimate": "minelayer"}},

	{"id": "k_vanish", "name": "Vanish", "effect": "Breaking cloak speeds your next blink", "key": "movement",
		"icon": "ab_kest_cloak", "tags": ["stealth", "mobility"], "proc": [{"on": "cloak_broken", "do": "refund_move", "scale": 1.0, "gap": 1.0}], "swap": {"ultimate": "air_raid"}},

	{"id": "k_daisy_chain", "name": "Daisy Chain", "effect": "Charges set each other off", "key": "weapon",
		"icon": "ab_kest_weapon", "tags": ["traps", "burst"], "knob": {"ult_beats": 2, "sticky_chain": 4.0}},

	{"id": "k_sticky_rain", "name": "Sticky Rain", "effect": "Each throw scatters three smaller charges", "key": "weapon",
		"icon": "ab_kest_weapon", "tags": ["traps"], "swap": {"weapon": "sticky_rain"}, "knob": {"ult_volley": 1}},

	{"id": "k_demolition", "name": "Demolition", "effect": "Charges hit plated targets far harder", "key": "weapon",
		"icon": "ab_kest_weapon", "tags": ["burst"], "knob": {"ult_radius": 2.0, "sticky_breach": 1.75}},

	{"id": "k_time_bomb", "name": "Time Bomb", "effect": "Charges grow stronger the longer they wait", "key": "weapon",
		"icon": "ab_kest_weapon", "tags": ["traps", "burst"], "knob": {"ult_beats": 2, "sticky_grow": true}},

	{"id": "k_dive_bomber", "name": "Dive Bomber", "effect": "Higher slams scatter bigger charges", "key": "smash",
		"icon": "ab_kest_smash", "tags": ["air", "burst"], "knob": {"ult_radius": 2.0, "slam_fall_scale": true}},

	{"id": "k_scorched", "name": "Scorched Earth", "effect": "Slam charges linger as traps", "key": "smash",
		"icon": "ab_kest_smash", "tags": ["traps"], "knob": {"ult_encore": true, "mini_linger": 3.0}},

	{"id": "k_skybreaker", "name": "Skybreaker", "effect": "Rocket jumps refill your blink", "key": "movement",
		"icon": "ab_kest_glide", "tags": ["air", "mobility"], "proc": [{"on": "rocket_jumped", "do": "grant_move", "scale": 1.0, "gap": 1.0}], "knob": {"ult_encore": true}},

	{"id": "k_comet", "name": "Comet", "effect": "Slams burst on impact", "key": "smash",
		"icon": "ab_kest_smash", "tags": ["air", "burst"], "proc": [{"on": "demo_slammed", "do": "detonate", "scale": 1.5, "gap": 1.0}], "knob": {"ult_radius": 2.0}},

	{"id": "k_phantom", "name": "Phantom", "effect": "Blinks cut through machines in your path", "key": "movement",
		"icon": "ab_kest_move", "tags": ["stealth", "close"], "knob": {"ult_volley": 1, "blink_cut": true}},

	{"id": "k_smoke_screen", "name": "Smoke Screen", "effect": "Blink smoke lingers; inside it, you're hidden", "key": "movement",
		"icon": "ab_kest_move", "tags": ["stealth"], "knob": {"ult_beats": 2, "smoke_cloud": 3.0}},

	{"id": "k_whirlwind", "name": "Whirlwind", "effect": "Blinks ring you with three charges", "key": "movement",
		"icon": "ab_kest_move", "tags": ["traps", "burst"], "proc": [{"on": "blink_used", "do": "charge", "scale": 3.0, "gap": 0.4}], "knob": {"ult_volley": 1}},

	{"id": "k_hitchhiker", "name": "Hitchhiker", "effect": "Charges ride the machine they hit", "key": "weapon",
		"icon": "ab_kest_weapon", "tags": ["traps", "close"], "knob": {"ult_encore": true, "sticky_ride": true}},

	{"id": "k_death_mark", "name": "Death Mark", "effect": "Marked machines burst when they die", "key": "special",
		"icon": "ab_kest_special", "tags": ["burst"], "knob": {"ult_radius": 2.0, "mark_burst": true}},

	{"id": "k_fuse_line", "name": "Fuse Line", "effect": "The line leaves charges along it", "key": "special",
		"icon": "ab_kest_special", "tags": ["traps"], "knob": {"ult_beats": 2, "line_charges": 3}},

	{"id": "k_shadow_step", "name": "Shadow Step", "effect": "Blinks from cloak cost nothing", "key": "movement",
		"icon": "ab_kest_move", "tags": ["stealth", "mobility"], "knob": {"ult_volley": 1, "cloak_free_blink": true}},

	{"id": "k_nightfall", "name": "Nightfall", "effect": "Cloak holds while you roll fast", "key": "movement",
		"icon": "ab_kest_cloak", "tags": ["stealth", "mobility"], "knob": {"ult_encore": true, "cloak_hold_fast": true}},

]


# Kest's world-one profile retains every node in the full tree's heap order.
const NODES_WORLD_ONE := NODES
