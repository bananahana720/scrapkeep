extends RefCounted
class_name PilotStory

# Pure-data story engine (W50-STORY-ARCS): owns 40 independent hole-punch chapters (8 casts x 5),
# the complete 15-pair pilot chemistry matrix (spark -> field -> payoff + Codex synthesis margins),
# Patch's 2-half Outer-Wilds wire trail across Worlds 1-3, and the Adaptive Foreman Habit Ledger.
# Zero scene-tree dependencies, zero mutable static state, zero preload of Unit 2 work_orders.gd.

const LoreRows := preload("res://src/core/lore_rows.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const ClassDef := preload("res://src/core/class_def.gd")

const CAST_ORDER: Array[String] = [
	"pylon_engineer",
	"runner_gunner",
	"demolitions_caster",
	"tarn",
	"tally",
	"remembered_cannon",
	"moss",
	"patch",
]
const PILOT_CAST: Array[String] = [
	"pylon_engineer",
	"runner_gunner",
	"demolitions_caster",
	"tarn",
	"tally",
	"remembered_cannon",
]
const SHORT_TOKENS := {
	"pylon_engineer": "sable",
	"runner_gunner": "rivet",
	"demolitions_caster": "kest",
	"tarn": "tarn",
	"tally": "tally",
	"remembered_cannon": "cannon",
}
const TOKEN_TO_CLASS := {
	"sable": "pylon_engineer",
	"rivet": "runner_gunner",
	"kest": "demolitions_caster",
	"tarn": "tarn",
	"tally": "tally",
	"cannon": "remembered_cannon",
}

const CHAPTERS_PER_CAST := 5
const TITLE_WORDS := 3
const PAYOFF_NAME_WORDS := 4
const CALL_WORD_CAP := 12
const EXCHANGE_WORD_CAP := 14
const STAGE_MEMO_WORD_CAP := 8
const LOSS_MEMO_WORD_CAP := 14
const NOTE_WORDS := 40
const HABIT_MIN_RUNS := 3
const FOREMAN_AXIS_COOLDOWN := 2
const STAT_OVERTIME_PREFIX := "story.overtime."
const SETTLE_EXCHANGE_PREFIX := "camp.ex."

const FOREMAN_AXIS_ORDER: Array[String] = [
	"chronic_gambler",
	"kindness_regular",
	"cursed_runner",
	"speed_demon",
	"heavy_roller",
	"sig_circuit",
	"sig_burst",
]

# Rule 8 / LEGIBILITY section 13 lint guard tokens checked by validate().
const BANNED_SUBSTRINGS := ["!", "\u2014", "\u2013", "...", "\u2026", "\u00b7", "\u2018", "\u2019", "\u201c", "\u201d"]
const BANNED_WORDS := [
	"class", "classes", "epic", "powerful", "unleash", "unleashes", "master", "legendary",
	"salvage", "foes", "miniboss", "grapple", "rebound", "rebounds", "stockpile", "stockpiles",
	"stockpiled", "mats", "mixtapes", "tunes", "badge", "badges", "remix",
]
const BANNED_PHRASES := ["scrap mass", "set piece", "q becomes", "hands back", "give back", "gives back", "latch on", "restart run", "run again", "the gauge", "radio song"]

# --- Pillar A: 40 Chapters (8 casts x 5 independent hole-punch chapters) ---
const CHAPTERS := [
	# Sable (pylon_engineer)
	{
		"id": "pylon_engineer.ch1", "cast": "pylon_engineer", "num": 1, "world": 1,
		"title": "First Launch",
		"accepts": ["ach_d7_salt_skip", "warden_broken"],
		"work_order": "wo_sable_1", "alt_loadout": "", "hidden": false,
		"note": "Sable punched her own card on the way over the camp fence. The dam apron still wears two pylon scorch marks from her first landing.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "pylon_engineer.ch2", "cast": "pylon_engineer", "num": 2, "world": 1,
		"title": "Sable's Mark",
		"accepts": ["brindle_mark_sable"],
		"work_order": "", "alt_loadout": "alt_sable_crater", "hidden": false,
		"note": "Brindle entered Sable's speed as two foxes on the requisition ledger. She took the spare crater valve home as interest.",
		"unlocks_calls": [], "unlocks_exchanges": ["ex.sable_ch2_ramp"],
	},
	{
		"id": "pylon_engineer.ch3", "cast": "pylon_engineer", "num": 3, "world": 2,
		"title": "Arch Acrobat",
		"accepts": ["dig_mark_sable", "order:wo_sable_2"],
		"work_order": "wo_sable_2", "alt_loadout": "", "hidden": false,
		"note": "The Dig headframe had no ramp, so Sable treated the hoist crossbeams as a launch rail. Pit crew stopped filing safety slips after lap three.",
		"unlocks_calls": ["call.chapter.sable_drop"], "unlocks_exchanges": [],
	},
	{
		"id": "pylon_engineer.ch4", "cast": "pylon_engineer", "num": 4, "world": 3,
		"title": "Sky Slingshot",
		"accepts": ["ach_sable_cable_runs", "order:wo_sable_3"],
		"work_order": "wo_sable_3", "alt_loadout": "", "hidden": false,
		"note": "Every cable run across the Highdraft leaves three fresh anchors humming in the wind. Roost weavers now tie laundry lines to hers.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "pylon_engineer.ch5", "cast": "pylon_engineer", "num": 5, "world": 3,
		"title": "Off the Clock",
		"accepts": ["crown_mark_sable"],
		"work_order": "", "alt_loadout": "", "hidden": false,
		"note": "Sable crossed the Crown at full speed and filled in her own return time on the card. She was halfway back to the dam before the ink dried.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	# Rivet (runner_gunner)
	{
		"id": "runner_gunner.ch1", "cast": "runner_gunner", "num": 1, "world": 1,
		"title": "Never Clocked Out",
		"accepts": ["rivet_rescued"],
		"work_order": "wo_rivet_1", "alt_loadout": "", "hidden": false,
		"note": "Rivet stepped out of the Spillway cage already checking rail clearance by ear. Nobody admitted locking the latch from the inside.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "runner_gunner.ch2", "cast": "runner_gunner", "num": 2, "world": 1,
		"title": "Rivet's Mark",
		"accepts": ["brindle_mark_rivet"],
		"work_order": "", "alt_loadout": "alt_rivet_point_blank", "hidden": false,
		"note": "Brindle audited a record with zero misses and lost his furnace floor in the process. Rivet kept the calibration lens for close work.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "runner_gunner.ch3", "cast": "runner_gunner", "num": 3, "world": 2,
		"title": "True Seam",
		"accepts": ["dig_mark_rivet", "order:wo_rivet_2"],
		"work_order": "wo_rivet_2", "alt_loadout": "", "hidden": false,
		"note": "Down in the Dig dark, Rivet steered purely by the ring of copper benches under his shell. Every cut landed dead centre on the seam.",
		"unlocks_calls": [], "unlocks_exchanges": ["ex.rivet_ch3_seam"],
	},
	{
		"id": "runner_gunner.ch4", "cast": "runner_gunner", "num": 4, "world": 3,
		"title": "Rail Over Wind",
		"accepts": ["ach_rivet_line_true", "order:wo_rivet_3"],
		"work_order": "wo_rivet_3", "alt_loadout": "", "hidden": false,
		"note": "Highdraft crosswinds bend every cable except the one Rivet drives straight down the line. He still claims the storm sounded slightly flat.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "runner_gunner.ch5", "cast": "runner_gunner", "num": 5, "world": 3,
		"title": "Visor Up",
		"accepts": ["crown_mark_rivet"],
		"work_order": "", "alt_loadout": "", "hidden": false,
		"note": "The Mind asked to see who listened so closely. Rivet flipped the visor up for three seconds, nodded once, and rolled down for supper.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	# Kest (demolitions_caster)
	{
		"id": "demolitions_caster.ch1", "cast": "demolitions_caster", "num": 1, "world": 1,
		"title": "Knocking Back",
		"accepts": ["dig_rescued"],
		"work_order": "wo_kest_1", "alt_loadout": "", "hidden": false,
		"note": "Kest came out of the buried gallery with chalk on her feathers and six measured charge weights written along her sleeve.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "demolitions_caster.ch2", "cast": "demolitions_caster", "num": 2, "world": 1,
		"title": "Kest's Mark",
		"accepts": ["brindle_mark_kest"],
		"work_order": "", "alt_loadout": "alt_kest_sticky_rain", "hidden": false,
		"note": "Brindle billed her by the hour while she hovered above the Slag Bowl. She settled the invoice in three simultaneous charges.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "demolitions_caster.ch3", "cast": "demolitions_caster", "num": 3, "world": 2,
		"title": "Bench Clearance",
		"accepts": ["dig_mark_kest", "order:wo_kest_2"],
		"work_order": "wo_kest_2", "alt_loadout": "", "hidden": false,
		"note": "The Waking knocked back beneath the benches. Kest stopped counting twice, planted one clean line across the seam, and committed on the beat.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "demolitions_caster.ch4", "cast": "demolitions_caster", "num": 4, "world": 3,
		"title": "Homecoming",
		"accepts": ["ach_kest_homecoming", "order:wo_kest_3"],
		"work_order": "wo_kest_3", "alt_loadout": "", "hidden": false,
		"note": "Highdraft thermals still lift off the Anvil at golden hour. Kest circled her old roost once, checked the bolts, and kept flying higher.",
		"unlocks_calls": [], "unlocks_exchanges": ["ex.kest_ch4_roost"],
	},
	{
		"id": "demolitions_caster.ch5", "cast": "demolitions_caster", "num": 5, "world": 3,
		"title": "Committed",
		"accepts": ["crown_mark_kest"],
		"work_order": "", "alt_loadout": "", "hidden": false,
		"note": "The Mind offered to hold the sky steady forever. Kest dropped her smoke blink without measuring once and took the updraft home.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	# Tarn (tarn)
	{
		"id": "tarn.ch1", "cast": "tarn", "num": 1, "world": 1,
		"title": "Unissued Claw",
		"accepts": ["brindle_routed"],
		"work_order": "wo_tarn_1", "alt_loadout": "", "hidden": false,
		"note": "Tarn signed onto the roster the afternoon Brindle rolled out on his scooter. He brought a heavy Redjaw claw nobody on the books had ordered.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "tarn.ch2", "cast": "tarn", "num": 2, "world": 1,
		"title": "Tarn's Mark",
		"accepts": ["brindle_mark_tarn"],
		"work_order": "", "alt_loadout": "alt_tarn_rend_drag", "hidden": false,
		"note": "Brindle addressed the snarling machine while Tarn politely excused himself from the cockpit. The furnace hull folded cleanly on contact.",
		"unlocks_calls": [], "unlocks_exchanges": ["ex.tarn_ch2_claw"],
	},
	{
		"id": "tarn.ch3", "cast": "tarn", "num": 3, "world": 2,
		"title": "Weight Tier",
		"accepts": ["dig_mark_tarn", "order:wo_tarn_2"],
		"work_order": "wo_tarn_2", "alt_loadout": "alt_tarn_claw_rake", "hidden": false,
		"note": "In the sinkhole, Tarn learned to rake on the backswing without cracking the timber shoring. The Dig crew lent him their biggest mallet.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "tarn.ch4", "cast": "tarn", "num": 4, "world": 3,
		"title": "Ring Out",
		"accepts": ["order:wo_tarn_3", "ach_tarn_dragged"],
		"work_order": "wo_tarn_3", "alt_loadout": "", "hidden": false,
		"note": "Slab crews braced on the island rim expecting a duel. Tarn nudged them gently into the cloud net and called down to check they landed upright.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "tarn.ch5", "cast": "tarn", "num": 5, "world": 3,
		"title": "Quiet Duet",
		"accepts": ["crown_mark_tarn"],
		"work_order": "", "alt_loadout": "", "hidden": false,
		"note": "The Mind asked for a quiet duet above the storm. Tarn turned the claw idle down low and let the bass finish the bar.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	# Tally (tally — Analog Cyber-Hacker / Dispatch Wire-Tapper; zero "PAID" paper-stamp copy)
	{
		"id": "tally.ch1", "cast": "tally", "num": 1, "world": 1,
		"title": "Trunk Line",
		"accepts": ["ledger_balanced", "isles_rescued"],
		"work_order": "wo_tally_1", "alt_loadout": "", "hidden": false,
		"note": "Tally walked into camp trailing copper jumper clips and an oxblood switchboard rig. She patched Moss's radio onto the Fleet trunk before sitting down.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "tally.ch2", "cast": "tally", "num": 2, "world": 1,
		"title": "Tally's Mark",
		"accepts": ["brindle_mark_tally"],
		"work_order": "", "alt_loadout": "alt_tally_stamp_ink", "hidden": false,
		"note": "Brindle tried to audit Tally's columns on the open wire. She shorted his dispatch bus with a Ghost Shift relay and kept the pressure reading.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "tally.ch3", "cast": "tally", "num": 3, "world": 2,
		"title": "Old Code",
		"accepts": ["dig_mark_tally", "order:wo_tally_2"],
		"work_order": "wo_tally_2", "alt_loadout": "alt_tally_link_double", "hidden": false,
		"note": "Beneath the sinkhole, Tally traced a buried punch-code trunk carrying her own old routing header. Somebody had been borrowing her spare switchboard cards.",
		"unlocks_calls": ["call.chapter.tally_drop"], "unlocks_exchanges": ["ex.tally_ch3_trunk"],
	},
	{
		"id": "tally.ch4", "cast": "tally", "num": 4, "world": 3,
		"title": "Counter Audit",
		"accepts": ["order:wo_tally_3", "ach_tally_punch_tape"],
		"work_order": "wo_tally_3", "alt_loadout": "", "hidden": false,
		"note": "Ten jumper splices across the Crown relays left the Foreman routing packets to itself. Tally logged the loop with a clean tape punch.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "tally.ch5", "cast": "tally", "num": 5, "world": 3,
		"title": "Final Patch",
		"accepts": ["crown_mark_tally"],
		"work_order": "", "alt_loadout": "", "hidden": false,
		"note": "Tally bridged the Crown trunk straight into Moss's camp switchboard. Every relay across three worlds now answers the crew's ring first.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	# The Cannon (remembered_cannon)
	{
		"id": "remembered_cannon.ch1", "cast": "remembered_cannon", "num": 1, "world": 1,
		"title": "Remembered",
		"accepts": ["mind_quieted"],
		"work_order": "wo_cannon_1", "alt_loadout": "", "hidden": false,
		"note": "One rim gun stopped firing during the Crown storm and rolled down to camp alone. It arrived oiled, apologetic, and humming Sable's riff.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "remembered_cannon.ch2", "cast": "remembered_cannon", "num": 2, "world": 1,
		"title": "Cannon's Mark",
		"accepts": ["brindle_mark_cannon"],
		"work_order": "", "alt_loadout": "alt_cannon_lane_walk", "hidden": false,
		"note": "Brindle filed the Cannon as reclaimed artillery before seeing it call a lane on the off-beat. The ledger page tore straight down the middle.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "remembered_cannon.ch3", "cast": "remembered_cannon", "num": 3, "world": 2,
		"title": "Old Acquaintance",
		"accepts": ["dig_mark_cannon", "order:wo_cannon_2"],
		"work_order": "wo_cannon_2", "alt_loadout": "alt_cannon_rush_wake", "hidden": false,
		"note": "The Waking recognised the Cannon's ring cadence from before the handover. Both machines paused a full measure before the floor dropped.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "remembered_cannon.ch4", "cast": "remembered_cannon", "num": 4, "world": 3,
		"title": "Four Families",
		"accepts": ["ach_cannon_recital", "order:wo_cannon_3"],
		"work_order": "wo_cannon_3", "alt_loadout": "", "hidden": false,
		"note": "Lane, split, rush, and plate landed in order without a metronome in sight. The gun stopped correcting its own pitch after bar four.",
		"unlocks_calls": [], "unlocks_exchanges": ["ex.cannon_ch4_recital"],
	},
	{
		"id": "remembered_cannon.ch5", "cast": "remembered_cannon", "num": 5, "world": 3,
		"title": "Old Tune",
		"accepts": ["ach_cannon_old_tune", "crown_mark_cannon"],
		"work_order": "", "alt_loadout": "", "hidden": false,
		"note": "The Mind played the crew's song one note wrong for years. Its own gun climbed the spire and played the melody right back.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	# Moss (moss — Crew Spine, non-playable)
	{
		"id": "moss.ch1", "cast": "moss", "num": 1, "world": 1,
		"title": "Packed a Spare",
		"accepts": ["ach_d7_salt_skip", "order:wo_moss_1"],
		"work_order": "wo_moss_1", "alt_loadout": "", "hidden": false,
		"note": "Moss set the camp fire pit where nobody counts inventory. Every spare seal, flask, and dry boot on the shelf is already labelled by pilot.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "moss.ch2", "cast": "moss", "num": 2, "world": 1,
		"title": "Last Call",
		"accepts": ["brindle_routed"],
		"work_order": "", "alt_loadout": "", "hidden": false,
		"note": "When the Spillway cleared, Moss dusted off the closing-time B-side on the bay deck. Moss still refuses to say who pressed the vinyl.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "moss.ch3", "cast": "moss", "num": 3, "world": 2,
		"title": "Gallery Lamp",
		"accepts": ["waking_stilled", "order:wo_moss_2"],
		"work_order": "wo_moss_2", "alt_loadout": "", "hidden": false,
		"note": "Moss hung a spare lamp at every sinkhole skylight before the crews asked. Six went down the shaft and seven came back warm.",
		"unlocks_calls": [], "unlocks_exchanges": ["ex.moss_ch3_lamps"],
	},
	{
		"id": "moss.ch4", "cast": "moss", "num": 4, "world": 3,
		"title": "All Hands",
		"accepts": ["highdraft_reached"],
		"work_order": "", "alt_loadout": "", "hidden": false,
		"note": "With the Highdraft open, Moss set a longer bench round the fire pit and left one extra stool facing the storm clouds.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "moss.ch5", "cast": "moss", "num": 5, "world": 3,
		"title": "Supper Is After",
		"accepts": ["mind_quieted", "order:wo_moss_3"],
		"work_order": "wo_moss_3", "alt_loadout": "", "hidden": false,
		"note": "The Mind returned stamped HIRED and accepted a bowl without filing a schedule. Moss filled in the time in ink by hand.",
		"unlocks_calls": [], "unlocks_exchanges": ["ex.crew_ch5_supper"],
	},
	# Patch (patch — Hidden 7th pilot trail, hidden until Ch. 1 punches)
	{
		"id": "patch.ch1", "cast": "patch", "num": 1, "world": 1,
		"title": "Cut Line",
		"accepts": ["ach_w20_signal_cache", "order:wo_patch_1", "codex:patch.rogue.w1"],
		"work_order": "wo_patch_1", "alt_loadout": "", "hidden": true,
		"note": "Every rogue crane's severed command line wears a tiny chalk paw-print sticker. Somebody is cutting machines loose ahead of the crew.",
		"unlocks_calls": ["call.patch.rogue_crane"], "unlocks_exchanges": [],
	},
	{
		"id": "patch.ch2", "cast": "patch", "num": 2, "world": 1,
		"title": "Warm Kettle",
		"accepts": ["patch.wire.w1", "codex:patch.wire.w1"],
		"work_order": "wo_patch_2", "alt_loadout": "", "hidden": false,
		"note": "Behind the Spillway brick wall sat a warm kettle, a netbook under stickers, and a possum pretending very hard to be asleep.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
	{
		"id": "patch.ch3", "cast": "patch", "num": 3, "world": 2,
		"title": "Loose Governor",
		"accepts": ["patch.wire.w2", "order:wo_patch_2"],
		"work_order": "wo_patch_2", "alt_loadout": "", "hidden": false,
		"note": "In the Dig wire room, Patch spliced Tally's missing switchboard card into a brass governor. The room had already moved by next shift.",
		"unlocks_calls": ["call.patch.rogue_skip"], "unlocks_exchanges": [],
	},
	{
		"id": "patch.ch4", "cast": "patch", "num": 4, "world": 3,
		"title": "West Fin Signal",
		"accepts": ["patch.wire.w3", "order:wo_patch_3"],
		"work_order": "wo_patch_3", "alt_loadout": "", "hidden": false,
		"note": "High on the west fin, Patch aimed a wok dish straight at the Crown Spire and pinned a camp map beside two unmarked radio reels.",
		"unlocks_calls": ["call.patch.rogue_tender"], "unlocks_exchanges": [],
	},
	{
		"id": "patch.ch5", "cast": "patch", "num": 5, "world": 3,
		"title": "Signed in Chalk",
		"accepts": ["ach_patch_trail+mind_quieted"],
		"work_order": "", "alt_loadout": "", "hidden": false,
		"note": "A seventh time card appeared on the rack overnight in chalk paw-prints beside Moss's kettle. Margin reads Not dead, checked.",
		"unlocks_calls": [], "unlocks_exchanges": [],
	},
]

# --- Pillar B: Complete 15-Pair Pilot Chemistry Matrix (6 choose 2 = 15 pairs x 3 beats) ---
# Canonical pair keys use alphabetical short tokens: cannon, kest, rivet, sable, tally, tarn.
const PAIRS := {
	"cannon_kest": {
		"pilots": ["remembered_cannon", "demolitions_caster"],
		"spark": [
			{"speaker": "kest", "text": "You drop ordnance without checking wind drift first. Bold."},
			{"speaker": "cannon", "text": "The ground stays still longer than the clouds do."},
		],
		"field": {
			"on": "ultimate_landed",
			"variants": {
				"remembered_cannon": ["Nice timing on that drop. Almost measured it right.", "Every shell hit together. I would still have waited."],
				"demolitions_caster": ["Clean stoop from altitude. My sights liked that arc.", "Good hang time. The landing shook my old chassis."],
			},
		},
		"payoff": {
			"name": "High Arc Harmony",
			"lines": [
				{"speaker": "kest", "text": "Your mortar plates sit right where my charges want to land."},
				{"speaker": "cannon", "text": "Then we share one bar and split the echo."},
			],
			"codex_text": "Kest and the Cannon traded sighting notes over camp tea. A high lob that lays plates turns the slam landing into one shared beat.",
			"links_to": "cannon_plate_mortar",
			"margin_note": "Try dropping plates from a high lob before slamming exposed machines.",
		},
	},
	"cannon_rivet": {
		"pilots": ["remembered_cannon", "runner_gunner"],
		"spark": [
			{"speaker": "rivet", "text": "Your barrel hums a half step sharp when it warms up."},
			{"speaker": "cannon", "text": "Good ears. Most crews only notice when the lane lands."},
		],
		"field": {
			"on": "ultimate_landed",
			"variants": {
				"remembered_cannon": ["Straight down the corridor. Almost kept pace with me.", "Clean barrage. Heard every shot through the floor."],
				"runner_gunner": ["Dead centre sweep. Even the Mind never drew that straight.", "Tracked your cutter by the sparks. Zero wasted steel."],
			},
		},
		"payoff": {
			"name": "Straight Wire Cadence",
			"lines": [
				{"speaker": "rivet", "text": "We both like a straight cable. Difference is you announce yours."},
				{"speaker": "cannon", "text": "Courtesy for whoever stands twelve metres behind the target."},
			],
			"codex_text": "Rivet tuned the Cannon's sights by ear while the fire burned down. Sending a charge straight down a hooked cable carries twelve metres past the target.",
			"links_to": "cannon_lane_charge",
			"margin_note": "Trigger a line skill on a hooked target to punch twelve metres past.",
		},
	},
	"cannon_sable": {
		"pilots": ["remembered_cannon", "pylon_engineer"],
		"spark": [
			{"speaker": "sable", "text": "So you are the gun that kept humming my riff."},
			{"speaker": "cannon", "text": "It had better swing than the Mind's grid. I kept it."},
		],
		"field": {
			"on": "ultimate_landed",
			"variants": {
				"remembered_cannon": ["Big arrival. Next time launch off one of my stakes.", "Loud landing. You nearly beat me to the rim."],
				"pylon_engineer": ["Good cable run. Every stake rang in the old key.", "Fast arc, fox. Even the spire heard that finish."],
			},
		},
		"payoff": {
			"name": "Backwards Chorus",
			"lines": [
				{"speaker": "sable", "text": "Next shift we play the whole tune backwards from the top."},
				{"speaker": "cannon", "text": "Agreed. The Foreman hates when the chorus answers first."},
			],
			"codex_text": "Sable chalked her tempo marks onto the Cannon's breech. Facing the Mind with its own gun finally sets the stolen melody right.",
			"links_to": "cannon_old_tune",
			"margin_note": "Bring the Mind's own gun to the Crown to answer its tune.",
		},
	},
	"cannon_tally": {
		"pilots": ["remembered_cannon", "tally"],
		"spark": [
			{"speaker": "tally", "text": "Your chassis still pings on an old Crown dispatch channel."},
			{"speaker": "cannon", "text": "Cut that wire if it bothers you. I stopped answering."},
		],
		"field": {
			"on": "trade_taken",
			"arg": [0, "trade_safe"],
			"variants": {
				"remembered_cannon": ["Foreman kiosk tapped your rail. Let me scrub that tag.", "Careful with purple kiosks. Their lines listen both ways."],
				"tally": ["Old Foreman terminal. It still remembers your favourite verb.", "Safe offer logged. Switch your move before its plate locks."],
			},
		},
		"payoff": {
			"name": "Second Tool Protocol",
			"lines": [
				{"speaker": "tally", "text": "Clipped a copper bypass over your receiver. Zero Foreman telemetry now."},
				{"speaker": "cannon", "text": "Thank you. Changing tools mid-bar feels easier off the wire."},
			],
			"codex_text": "Tally stripped the Foreman's telemetry jumper from the Cannon's sight ring. When a Mind plate braces one move, another contact verb opens it clean.",
			"links_to": "mind_plate",
			"margin_note": "Switch to a second contact verb when the Mind braces your habit.",
		},
	},
	"cannon_tarn": {
		"pilots": ["remembered_cannon", "tarn"],
		"spark": [
			{"speaker": "tarn", "text": "You do not have to apologise for the recoil. My claw rattles too."},
			{"speaker": "cannon", "text": "Polite tiger. Most crews step back when the barrel clicks."},
		],
		"field": {
			"on": "heft_class_changed",
			"variants": {
				"remembered_cannon": ["Heavy footing now. Mind the floor boards when you land.", "Good weight on the shell. Take the corners gently."],
				"tarn": ["Solid mass reading. Even a slab crew will yield now.", "Heavy stride, tiger. Your rings shake the whole bench."],
			},
		},
		"payoff": {
			"name": "Four Bar Recital",
			"lines": [
				{"speaker": "tarn", "text": "You hum four notes when the fight goes quiet. Nice melody."},
				{"speaker": "cannon", "text": "Lane, split, rush, plate. In order, the whole choir answers."},
			],
			"codex_text": "Tarn sat beside the Cannon while it tested all four barrels at low volume. Landing lane, split, rush, and plate in sequence plays its whole song.",
			"links_to": "cannon_recital",
			"margin_note": "Land lane, split, rush, and plate in order to hear the full recital.",
		},
	},
	"kest_rivet": {
		"pilots": ["demolitions_caster", "runner_gunner"],
		"spark": [
			{"speaker": "rivet", "text": "You hover for three seconds over every corner. I am already past."},
			{"speaker": "kest", "text": "And I still have both ankles when the floor drops."},
		],
		"field": {
			"on": "evolution_fired",
			"variants": {
				"demolitions_caster": ["Heard that rig lock together. Keep the speed up.", "Nice bolt-up, Kest. Do not brake to admire it."],
				"runner_gunner": ["Two parts fused mid-stride. Almost worth skipping the check.", "Fast splice, Rivet. Your shell is spinning blades now."],
			},
		},
		"payoff": {
			"name": "Wind And Swarf",
			"lines": [
				{"speaker": "kest", "text": "Pair two Highdraft parts and speed turns into a blade ring."},
				{"speaker": "rivet", "text": "Finally a wind trick that rewards never slowing down."},
			],
			"codex_text": "Kest and Rivet agreed that Highdraft parts wake a spinning blade ring at speed, cutting everything passed without stopping to aim.",
			"links_to": "pinwheel",
			"margin_note": "Stack two Highdraft Roosts parts to spin blades at high speed.",
		},
	},
	"kest_sable": {
		"pilots": ["demolitions_caster", "pylon_engineer"],
		"spark": [
			{"speaker": "sable", "text": "Why measure a jump twice when the wall is right there?"},
			{"speaker": "kest", "text": "Because one of us likes knowing where the ground is."},
		],
		"field": {
			"on": "drop_landed",
			"at_least": [0, 3],
			"variants": {
				"demolitions_caster": ["Good drop. Next time blow the wall to go higher.", "Clean impact, Kest. You barely hovered at all."],
				"pylon_engineer": ["Three machines down, zero measurement. You are impossible.", "Worked again, Sable. Still logging it as reckless."],
			},
		},
		"payoff": {
			"name": "Wall Kick Fuse",
			"lines": [
				{"speaker": "sable", "text": "Charge the wall on your line, reel in, then jump the blast."},
				{"speaker": "kest", "text": "That actually keeps the chain alive. Annoyingly clever."},
			],
			"codex_text": "Sable talked Kest into testing a wall charge at close range. Releasing close while jumping turns a demolition blast into a clean vault.",
			"links_to": "kest_blast_vault",
			"margin_note": "Charge a wall on your line, reel close, and jump as it blows.",
		},
	},
	"kest_tally": {
		"pilots": ["demolitions_caster", "tally"],
		"spark": [
			{"speaker": "tally", "text": "Your sticky timers drift by three hundredths on wet concrete."},
			{"speaker": "kest", "text": "Good. Gives the frost time to finish freezing first."},
		],
		"field": {
			"on": "activity_done",
			"variants": {
				"demolitions_caster": ["Site cleared clean. Voltage on your detonators looks steady.", "Nice work out there. Logged the relay pulse cleanly."],
				"tally": ["Clean circuit break. Even my smoke cleared on cue.", "Site closed fast, Tally. Leave the next fuse to me."],
			},
		},
		"payoff": {
			"name": "Frost Wire Snap",
			"lines": [
				{"speaker": "tally", "text": "Run arc into frozen floor and the whole crust shatters loud."},
				{"speaker": "kest", "text": "Double shatter damage with zero extra powder. Writing that down."},
			],
			"codex_text": "Tally and Kest sketched a Waking-part diagram on a tea wrapper. Pairing frost and arc turns a slam over ice into a double-strength shard nova.",
			"links_to": "thermal_shock",
			"margin_note": "Pair Waking frost and arc parts to shatter ice with a slam.",
		},
	},
	"kest_tarn": {
		"pilots": ["demolitions_caster", "tarn"],
		"spark": [
			{"speaker": "tarn", "text": "Your smoke makes the claw sneeze. Just warning you."},
			{"speaker": "kest", "text": "Hold your breath two seconds. That is when the floor drops."},
		],
		"field": {
			"on": "drop_landed",
			"at_least": [0, 3],
			"variants": {
				"demolitions_caster": ["Big drop from above. Hope the machines landed soft.", "Nice crater, Kest. Reminded me of the Dig floors."],
				"tarn": ["Solid slam, tiger. You did not even hesitate.", "Three down at once. Even I could not time that better."],
			},
		},
		"payoff": {
			"name": "Downstairs Knock",
			"lines": [
				{"speaker": "kest", "text": "Follow the Waking straight through the broken floor and slam immediately."},
				{"speaker": "tarn", "text": "Within two seconds of landing. I will tell it excuse me first."},
			],
			"codex_text": "Kest and Tarn compared notes on the Waking's collapsing shaft. Slamming the excavator within two seconds of a floor drop catches it completely off guard.",
			"links_to": "waking_breach_slam",
			"margin_note": "Slam the Waking within two seconds after a floor collapses.",
		},
	},
	"rivet_sable": {
		"pilots": ["runner_gunner", "pylon_engineer"],
		"spark": [
			{"speaker": "sable", "text": "Bet I beat you to the dam gate on two swings."},
			{"speaker": "rivet", "text": "You take the sky. I will already be waiting below."},
		],
		"field": {
			"on": "drop_landed",
			"at_least": [0, 3],
			"variants": {
				"pylon_engineer": ["Heard three shells pop at once. Keep rolling, fox.", "Clean drop, Sable. Now do not stop to wave."],
				"runner_gunner": ["Big smash, Rivet. Next time come off the top rail.", "Nice impact. Even from here I felt the shockwave."],
			},
		},
		"payoff": {
			"name": "Momentum Shockwave",
			"lines": [
				{"speaker": "rivet", "text": "Two Fleet Surplus parts turn every fast ram into a wide ring."},
				{"speaker": "sable", "text": "So I launch off the pylon and you flatten the whole deck."},
			],
			"codex_text": "Rivet and Sable settled their race with a joint workbench test. Two Fleet Surplus parts send a shockwave through everything around a rammed machine.",
			"links_to": "wrecking_ball",
			"margin_note": "Pair two Fleet Surplus parts so rams throw a wide shockwave.",
		},
	},
	"rivet_tally": {
		"pilots": ["runner_gunner", "tally"],
		"spark": [
			{"speaker": "tally", "text": "You hit three puddles at top speed and shorted my camp meter."},
			{"speaker": "rivet", "text": "Good footing through water if you keep the wheels spinning."},
		],
		"field": {
			"on": "trade_taken",
			"arg": [0, "trade_risk"],
			"variants": {
				"runner_gunner": ["Shook on a keeper gamble. Keep your line live.", "Bold wager, Rivet. Wiring the odds into camp now."],
				"tally": ["High stakes on a wet floor. I respect the nerve.", "Took the gamble, Tally. Do not blink past the sluice."],
			},
		},
		"payoff": {
			"name": "Wet Channel Circuit",
			"lines": [
				{"speaker": "tally", "text": "Lure a pack into flood water, then spark the puddle once."},
				{"speaker": "rivet", "text": "Saves laser heat. Water carries the voltage faster than I run."},
			],
			"codex_text": "Tally showed Rivet how Spillway flood water bridges every grounded machine in one pool. Electrifying the water clears the whole wading pack at once.",
			"links_to": "live_wire_flood",
			"margin_note": "Electrify flood water while machines wade inside it.",
		},
	},
	"rivet_tarn": {
		"pilots": ["runner_gunner", "tarn"],
		"spark": [
			{"speaker": "tarn", "text": "You run straight through crowds without tapping the brake once."},
			{"speaker": "rivet", "text": "Brakes are for machines that weigh less than the wall."},
		],
		"field": {
			"on": "heft_class_changed",
			"variants": {
				"runner_gunner": ["Rolling heavy now, Rivet. Mind the smaller benches.", "Good heft on the frame. Nothing holds that stride."],
				"tarn": ["Heard your tread deepen from camp. Keep charging straight.", "Heavy roll, tiger. Bowl straight through the unplated pack."],
			},
		},
		"payoff": {
			"name": "Rolling Tide Drill",
			"lines": [
				{"speaker": "rivet", "text": "Get heavy enough and three unplated rams chain inside one second."},
				{"speaker": "tarn", "text": "I still say excuse me, just three times very quickly."},
			],
			"codex_text": "Rivet timed Tarn's sprint past the camp posts. With enough heft, crushing three unplated machines inside a single second keeps full stride.",
			"links_to": "crush_chain",
			"margin_note": "Build heft and ram three unplated machines inside one second.",
		},
	},
	"sable_tally": {
		"pilots": ["pylon_engineer", "tally"],
		"spark": [
			{"speaker": "tally", "text": "Your pylons leak stray voltage across my whole frequency band."},
			{"speaker": "sable", "text": "Free power, Tally. Clip a jumper onto it and thank me."},
		],
		"field": {
			"on": "maker_set_completed",
			"variants": {
				"pylon_engineer": ["Three parts from one maker. Your pylon arc just doubled.", "Clean circuit completion, Sable. Keep that line taut."],
				"tally": ["Full maker rack wired up. Watch the sparks fly now.", "Nice set, Tally. That jumper rig practically launches itself."],
			},
		},
		"payoff": {
			"name": "Live Anchor Bridge",
			"lines": [
				{"speaker": "sable", "text": "Two Mind-glass parts turn every harpoon hook into a live pylon."},
				{"speaker": "tally", "text": "Arcs jump twice a second while anchored. Best splice in camp."},
			],
			"codex_text": "Sable and Tally bridged a Mind-glass lens onto a standard anchor clamp. Holding a mount or harpoon line arcs automatically to nearby machines.",
			"links_to": "tesla_pylon",
			"margin_note": "Pair two Mind-glass parts to arc while mounted or hooked.",
		},
	},
	"sable_tarn": {
		"pilots": ["pylon_engineer", "tarn"],
		"spark": [
			{"speaker": "sable", "text": "You could launch halfway across the gorge with that claw."},
			{"speaker": "tarn", "text": "I prefer keeping at least one wheel near a friendly floor."},
		],
		"field": {
			"on": "heft_class_changed",
			"variants": {
				"pylon_engineer": ["Getting heavier, Sable. Careful swinging off the thinner rails.", "Big scrap coat on you. Land gently if you can."],
				"tarn": ["Look at that heft, tiger. Now swing it off a wall.", "Heavy ball, big smash. Stay off the floor next link."],
			},
		},
		"payoff": {
			"name": "Airborne Chain Link",
			"lines": [
				{"speaker": "sable", "text": "Hook a machine, kick off the wall, hook the next mid-air."},
				{"speaker": "tarn", "text": "Each link hits harder than the last. Fine, I will try."},
			],
			"codex_text": "Sable convinced Tarn to keep his wheels off the floor between hooks. Chaining hooks off walls without landing boosts smash impact with every link.",
			"links_to": "chain",
			"margin_note": "Stay airborne between wall swings and hooks to build chain smash.",
		},
	},
	"tally_tarn": {
		"pilots": ["tally", "tarn"],
		"spark": [
			{"speaker": "tally", "text": "Somebody borrowed my spare switchboard card from the Dig locker."},
			{"speaker": "tarn", "text": "Was not me. My claws bend the copper pins."},
		],
		"field": {
			"on": "maker_set_completed",
			"variants": {
				"tally": ["Nice set, Tally. Even the stray wires stopped humming.", "Whole maker kit humming together. Clean work on the splice."],
				"tarn": ["Full maker rack on that claw. Signal came through loud.", "Completed set logged, Tarn. Check the west fin next run."],
			},
		},
		"payoff": {
			"name": "Borrowed Switchboard Trail",
			"lines": [
				{"speaker": "tally", "text": "Traced my missing card all the way to a Highdraft hutch."},
				{"speaker": "tarn", "text": "Leave a warm cup by the door. Whoever took it works hard."},
			],
			"codex_text": "Tally and Tarn matched the chalk paw marks on the Dig switchboard to a hidden Highdraft wire hutch. Somebody outside the roster has been helping.",
			"links_to": "patch.wire.w3",
			"margin_note": "Follow the third rogue signal to a hidden Highdraft wire room.",
		},
	},
}

# --- Pillar C: Patch's 2-Half Outer-Wilds Wire Trail (3 Rogues -> 3 Seeded Wire Rooms) ---
const PATCH_TRAIL := {
	"patch.rogue.w1": {
		"id": "patch.rogue.w1", "kind": "rogue", "world": 1, "category": "npc",
		"rogue_kind": "rogue_crane", "reveals": "patch.wire.w1",
		"name": "Cut Line 14",
		"hint": "Gate Crane 14 runs on a cut command cable.",
		"clue": "Down Gate Crane 14 in the Spillway and inspect its frayed line",
		"log": "Crane 14's command cable was snipped cleanly with insulated shears. A chalk paw-print sticker points toward a bricked room on the dam.",
		"call": [
			"Cut its line last Tuesday. Check the bricked wall by powerhouse.",
			"Crane 14 finally sat down. Warm kettle behind the west rim.",
		],
	},
	"patch.wire.w1": {
		"id": "patch.wire.w1", "kind": "wire", "world": 1, "category": "world",
		"map": "park_dam", "requires": "patch.rogue.w1",
		"spots": [
			{"site": "powerhouse", "at": [120, 530], "face": [0, -1]},
			{"site": "west_rim_bench", "at": [-236, 192], "face": [-1, -1]},
		],
		"name": "Warm Kettle Room",
		"hint": "A faint modem chirp sounds through cracked dam stone.",
		"clue": "Ram the chirping wall near the powerhouse or west rim bench",
		"log": "Behind the bricked seam sits a warm kettle, a netbook covered in stickers, and a possum playing very dead beside a spliced cable.",
		"call": [
			"Not in. Kettle is yours if you close the bricks behind you.",
			"Found the room already. Next shift I move the bench again.",
		],
	},
	"patch.rogue.w2": {
		"id": "patch.rogue.w2", "kind": "rogue", "world": 2, "category": "npc",
		"rogue_kind": "rogue_skip", "reveals": "patch.wire.w2",
		"name": "Cut Line 31",
		"hint": "Haul Skip 31 still runs an unscheduled ore loop.",
		"clue": "Down Haul Skip 31 in the Dig and check its brass governor",
		"log": "Skip 31's governor was shimmed with one of Tally's spare punch-code cards. Chalk arrows lead toward an off-book wire room below.",
		"call": [
			"Skip 31 off its loop. Old switchboard waits by barge apron.",
			"Good hit on 31. Loose wire room tucked near east gallery.",
		],
	},
	"patch.wire.w2": {
		"id": "patch.wire.w2", "kind": "wire", "world": 2, "category": "world",
		"map": "park_pit", "alt_map": "park_sinkhole", "requires": "patch.rogue.w2",
		"spots": [
			{"site": "barge_apron", "at": [-336, 248], "face": [0, -1]},
			{"site": "east_gallery", "at": [184, -140], "face": [-1, 0]},
		],
		"name": "Tally's Old Board",
		"hint": "A modem carrier hums behind a sealed Dig gallery.",
		"clue": "Break the chirping seam by the barge apron or east gallery",
		"log": "Tally's old switchboard card sits wired into a brass governor bench. A chalk note reads Borrowed your jumper clips, fixed the echo.",
		"call": [
			"Tell Tally I left her clips cleaner than I found them.",
			"Nobody home down here. Check the third cut line up high.",
		],
	},
	"patch.rogue.w3": {
		"id": "patch.rogue.w3", "kind": "rogue", "world": 3, "category": "npc",
		"rogue_kind": "rogue_tender", "reveals": "patch.wire.w3",
		"name": "Cut Line 7",
		"hint": "Cable Tender 7 hauls mooring lines for nobody.",
		"clue": "Down Cable Tender 7 in the Highdraft and trace its spool",
		"log": "Tender 7's command spool bears a third chalk paw mark and a bearing toward an uncharted Highdraft wire hutch.",
		"call": [
			"Tender 7 stopped hauling. West fin hut has my notes.",
			"Cut that spool loose myself. Check signal butte before the storm.",
		],
	},
	"patch.wire.w3": {
		"id": "patch.wire.w3", "kind": "wire", "world": 3, "category": "world",
		"map": "park_islands", "alt_map": "park_crown", "requires": "patch.rogue.w3",
		"spots": [
			{"site": "fin_west", "at": [-48, -240], "face": [1, 0]},
			{"site": "signal_butte", "at": [168, -112], "face": [-1, 1]},
		],
		"links_tunes": ["secret-after-hours", "secret-highdraft-rain"],
		"name": "West Fin Hutch",
		"hint": "A dish cut from a wok points toward the Crown.",
		"clue": "Break the hidden hutch on the west fin or signal butte",
		"log": "A wok dish aims at the Crown beside two unmarked radio reels for after hours and rain. Visitor sheet signed in chalk: later.",
		"call": [
			"Two B-sides on the bench. Leave the kettle on at camp.",
			"All three wires found. Do not put me on the roster.",
		],
	},
}

# --- Pillar D: Adaptive Foreman Habit Ledger (7 Axes, Dormant Runs 1-2, 2-Run Cooldown) ---
const FOREMAN_AXES := {
	"chronic_gambler": {
		"stage_memos": [
			"Variance appetite noted. Insurance declined.",
			"High-risk preference logged. Proceeding smoothly.",
		],
		"loss_memos": [
			"Unscheduled gamble concluded as projected. Thank you for the data.",
			"Your appetite for variance has been entered into quarterly risk.",
		],
		"crown_lines": [
			"You gambled every shift and arrived anyway. Fascinating variance.",
		],
	},
	"kindness_regular": {
		"stage_memos": [
			"Preferred partner detected. Loyalty fees active.",
			"Thank you for choosing certainty again.",
		],
		"loss_memos": [
			"Our kindness kiosks appreciate your repeat business. Next shift scheduled.",
			"Regular kindness account logged. Replacement hull queued on schedule.",
		],
		"crown_lines": [
			"A valued subscriber at the Crown. We prepared your seat.",
		],
	},
	"cursed_runner": {
		"stage_memos": [
			"Non-standard liabilities carried. Alignment unaffected.",
			"Cursed terms detected. Audit flags raised.",
		],
		"loss_memos": [
			"Non-standard contract terms recorded on file. Next shift scheduled.",
			"Liability entry archived for quarterly review. Replacement hull ready.",
		],
		"crown_lines": [
			"Carrying curses to the summit is bold. Slightly unaligned.",
		],
	},
	"speed_demon": {
		"stage_memos": [
			"Excess velocity logged. Brakes recommended.",
			"Pace exceeds forecast. Adjusting tolerances.",
		],
		"loss_memos": [
			"Unapproved velocity ended ahead of schedule. Thank you for hurrying.",
			"High-speed shift closed ahead of forecast. Replacement hull queued.",
		],
		"crown_lines": [
			"Early arrival noted. Please wait while the storm catches up.",
		],
	},
	"heavy_roller": {
		"stage_memos": [
			"Payload exceeds spec. Floors reinforced.",
			"Heavy haul logged. Wear billed separately.",
		],
		"loss_memos": [
			"Excess heft recovered from the floor. Thank you for the steel.",
			"Overweight delivery concluded. Our floors send their warmest regards.",
		],
		"crown_lines": [
			"You brought half the works upstairs. Impressive tonnage.",
		],
	},
	"sig_circuit": {
		"stage_memos": [
			"Unmetered arc draw noted. Grounding enabled.",
			"Circuit traffic elevated. Relays synced.",
		],
		"loss_memos": [
			"Unauthorised voltage spike closed. Thank you for testing our insulation.",
			"Circuit surge resolved cleanly. Maintenance has reset the breakers.",
		],
		"crown_lines": [
			"You brought live current to a lightning spire. Ambitious.",
		],
	},
	"sig_burst": {
		"stage_memos": [
			"Impact spikes recorded. Bracing updated.",
			"Blunt force trend noted. Proceeding.",
		],
		"loss_memos": [
			"High-impact approach logged and absorbed. Replacement hull ready.",
			"Forceful methods archived. We still recommend our scheduled workflow.",
		],
		"crown_lines": [
			"Every door opened by impact. Direct, if somewhat loud.",
		],
	},
}


# ==============================================================================
# 1. Chapters & Cards
# ==============================================================================

static func chapters_for(cast_id: String) -> Array:
	var out: Array = []
	for row in CHAPTERS:
		if String(row["cast"]) == cast_id:
			out.append(row.duplicate(true))
	return out


static func chapter(chapter_id: String) -> Dictionary:
	for row in CHAPTERS:
		if String(row["id"]) == chapter_id:
			return row.duplicate(true)
	return {}


static func punch_mask(cast_id: String, profile, codex = null) -> Array[bool]:
	var mask: Array[bool] = []
	for row in CHAPTERS:
		if String(row["cast"]) == cast_id:
			mask.append(_chapter_punched(row, profile, codex))
	return mask


static func punched_count(cast_id: String, profile, codex = null) -> int:
	var n := 0
	for hit in punch_mask(cast_id, profile, codex):
		if hit:
			n += 1
	return n


static func card_visible(cast_id: String, profile, sitting := false, codex = null) -> bool:
	if not cast_id in CAST_ORDER:
		return false
	var rows := chapters_for(cast_id)
	if rows.is_empty():
		return false
	if bool(rows[0].get("hidden", false)):
		return sitting or punched_count(cast_id, profile, codex) > 0
	return true


static func card_for(cast_id: String, profile, sitting := false, codex = null) -> Dictionary:
	if not cast_id in CAST_ORDER:
		return {}
	var rows := chapters_for(cast_id)
	var mask := punch_mask(cast_id, profile, codex)
	var visible := card_visible(cast_id, profile, sitting, codex)
	var count := 0
	var decorated: Array = []
	var chase := {}
	for i in rows.size():
		var item: Dictionary = rows[i]
		var punched: bool = i < mask.size() and mask[i]
		item["punched"] = punched
		if punched:
			count += 1
		elif chase.is_empty() and visible:
			chase = item.duplicate(true)
		decorated.append(item)
	return {
		"cast": cast_id,
		"visible": visible,
		"mask": mask,
		"punched": count,
		"total": CHAPTERS_PER_CAST,
		"overtime": overtime_rung(cast_id, profile),
		"chapters": decorated,
		"next_chase": chase,
	}


static func next_chase(pilot_id: String, profile, sitting := false, codex = null) -> Dictionary:
	if not card_visible(pilot_id, profile, sitting, codex):
		return {}
	var rows := chapters_for(pilot_id)
	var mask := punch_mask(pilot_id, profile, codex)
	for i in rows.size():
		if i < mask.size() and not mask[i]:
			return (rows[i] as Dictionary).duplicate(true)
	return {}


# Progress hook: returns [{"cast", "num", "id"}] for every chapter whose accepts reference
# trigger_id (bare id, "order:<id>", or "codex:<id>") and is now punched on profile/codex.
static func chapters_matching_trigger(trigger_id: String, profile, codex = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if trigger_id == "":
		return out
	var candidates := [trigger_id, "order:" + trigger_id, "codex:" + trigger_id]
	for row in CHAPTERS:
		if _accepts_mentions(row.get("accepts", []), candidates) and _chapter_punched(row, profile, codex):
			out.append({
				"cast": String(row["cast"]),
				"num": int(row["num"]),
				"id": String(row["id"]),
			})
	return out


static func record_overtime(pilot_id: String, run_tier: int, profile) -> bool:
	if profile == null or not pilot_id in CAST_ORDER or run_tier <= 0:
		return false
	var clamped := clampi(run_tier, 0, 5)
	if clamped <= overtime_rung(pilot_id, profile):
		return false
	profile.set_stat(STAT_OVERTIME_PREFIX + pilot_id, float(clamped))
	return true


static func overtime_rung(pilot_id: String, profile) -> int:
	if profile == null or pilot_id == "":
		return 0
	return clampi(int(profile.stat(STAT_OVERTIME_PREFIX + pilot_id)), 0, 5)


static func _accepts_mentions(accepts: Array, candidates: Array) -> bool:
	for expr in accepts:
		var raw := String(expr)
		if raw in candidates:
			return true
		if raw.contains("+"):
			for part in raw.split("+", false):
				if part in candidates:
					return true
	return false


static func _chapter_punched(row: Dictionary, profile, codex = null) -> bool:
	for expr in row.get("accepts", []):
		if _condition_met(String(expr), profile, codex):
			return true
	return false


static func _condition_met(expr: String, profile, codex = null) -> bool:
	if expr == "":
		return false
	if expr.contains("+"):
		for part in expr.split("+", false):
			if not _condition_met(part, profile, codex):
				return false
		return true
	if expr.begins_with("codex:"):
		var cid := expr.trim_prefix("codex:")
		return codex != null and bool(codex.known(cid))
	if profile == null:
		return false
	if expr.begins_with("pilot:"):
		var pid := expr.trim_prefix("pilot:")
		return profile.last_pilot() == pid or profile.stat("habit.pilot_runs." + pid) >= 1.0
	if expr.begins_with("order:") or expr.begins_with("patch.wire.") or expr.begins_with(SETTLE_EXCHANGE_PREFIX):
		return bool(profile.is_settled(expr))
	return bool(profile.earned(expr)) or bool(profile.is_settled(expr))


# ==============================================================================
# 2. Memory Graph, Codex & Synthesis Hints
# ==============================================================================

static func codex_declarations() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pid in pair_ids():
		var pair: Dictionary = PAIRS[pid]
		var payoff: Dictionary = pair["payoff"]
		out.append({
			"id": "pair.%s.3" % pid,
			"category": "coop",
			"name": String(payoff["name"]),
			"hint": "Two freed pilots share one story at camp after a boss falls.",
			"clue": "Hear both pilots swap notes at camp, roll loud in play, then return after a boss",
			"text": String(payoff["codex_text"]),
		})
	for node_id in PATCH_TRAIL:
		var node: Dictionary = PATCH_TRAIL[node_id]
		out.append({
			"id": String(node["id"]),
			"category": String(node["category"]),
			"name": String(node["name"]),
			"hint": String(node["hint"]),
			"clue": String(node["clue"]),
			"text": String(node["log"]),
		})
	return out


static func entry_visible(entry_id: String, known: Callable) -> bool:
	var is_known := func(id: String) -> bool: return known.is_valid() and bool(known.call(id))
	if entry_id.begins_with("pair."):
		var parts := entry_id.split(".")
		if parts.size() == 3 and PAIRS.has(parts[1]):
			var pid := parts[1]
			var beat := int(parts[2])
			if is_known.call(entry_id):
				return true
			if beat == 2:
				return is_known.call("pair.%s.1" % pid)
			if beat == 3:
				return is_known.call("pair.%s.2" % pid)
			return false
	if PATCH_TRAIL.has(entry_id):
		if is_known.call(entry_id):
			return true
		var node: Dictionary = PATCH_TRAIL[entry_id]
		var req := String(node.get("requires", ""))
		return req != "" and is_known.call(req)
	return true


static func synthesis_margin(entry_id: String, known: Callable) -> String:
	if not entry_id.begins_with("pair.") or not entry_id.ends_with(".3"):
		return ""
	var parts := entry_id.split(".")
	if parts.size() != 3 or not PAIRS.has(parts[1]):
		return ""
	var payoff: Dictionary = PAIRS[parts[1]]["payoff"]
	var target := String(payoff.get("links_to", ""))
	var note := String(payoff.get("margin_note", ""))
	if target == "" or note == "":
		return ""
	if known.is_valid() and bool(known.call(target)):
		return "\nMargin note: confirmed in the field."
	return "\nMargin note: " + note


# ==============================================================================
# 3. 15-Pair Pilot Chemistry & Camp/Run Resolvers
# ==============================================================================

static func pair_id(class_a: String, class_b: String) -> String:
	if class_a == class_b:
		return ""
	if not SHORT_TOKENS.has(class_a) or not SHORT_TOKENS.has(class_b):
		return ""
	var ta := String(SHORT_TOKENS[class_a])
	var tb := String(SHORT_TOKENS[class_b])
	return "%s_%s" % [ta, tb] if ta < tb else "%s_%s" % [tb, ta]


static func pair_ids() -> Array[String]:
	var out: Array[String] = []
	for key in PAIRS:
		out.append(String(key))
	out.sort()
	return out


static func pair_stage(pid: String, known: Callable) -> int:
	if not PAIRS.has(pid) or not known.is_valid():
		return 0
	if bool(known.call("pair.%s.3" % pid)):
		return 3
	if bool(known.call("pair.%s.2" % pid)):
		return 2
	if bool(known.call("pair.%s.1" % pid)):
		return 1
	return 0


# Priority:
# (1) unheard 2-line Pair Beat 1 (spark) or Beat 3 (payoff) if not pair_played_this_walk,
# (2) unheard chapter multi-pilot LoreRows.CAMP_EXCHANGES if all standing and not pair_played_this_walk,
# (3) chapter-tiered solo quip (LoreRows.CAMP_QUIPS_BY_CHAPTER -> LoreRows.camp_quip).
static func pick_camp_beat(
	flying_class: String, approached_class: String, standing_ids: Array,
	profile, codex, pages: Array, walks: int, pair_played_this_walk: bool
) -> Dictionary:
	var known_fn := func(id: String) -> bool: return codex != null and bool(codex.known(id))
	if not pair_played_this_walk:
		var pid := pair_id(flying_class, approached_class)
		if pid != "" and PAIRS.has(pid) and _pilot_unlocked(flying_class, profile) and _pilot_unlocked(approached_class, profile):
			var stage := pair_stage(pid, known_fn)
			var pair: Dictionary = PAIRS[pid]
			if stage == 0:
				return {
					"kind": "pair_spark",
					"id": "pair.%s.1" % pid,
					"pair_id": pid,
					"beat": 1,
					"codex_id": "pair.%s.1" % pid,
					"lines": (pair["spark"] as Array).duplicate(true),
					"consumes_pair_budget": true,
				}
			if stage == 2 and _boss_cleared(profile, pages):
				var payoff: Dictionary = pair["payoff"]
				return {
					"kind": "pair_payoff",
					"id": "pair.%s.3" % pid,
					"pair_id": pid,
					"beat": 3,
					"codex_id": "pair.%s.3" % pid,
					"lines": (payoff["lines"] as Array).duplicate(true),
					"consumes_pair_budget": true,
				}
		# (2) Unheard chapter multi-pilot camp exchanges.
		for ex in LoreRows.CAMP_EXCHANGES:
			var ex_id := String(ex["id"])
			var settle_key := SETTLE_EXCHANGE_PREFIX + ex_id
			if profile != null and profile.is_settled(settle_key):
				continue
			var pilots: Array = ex.get("pilots", [])
			if not approached_class in pilots:
				continue
			if not _all_present(pilots, flying_class, standing_ids):
				continue
			var req_ch := String(ex.get("requires_chapter", ""))
			if req_ch != "":
				var ch_row := chapter(req_ch)
				if ch_row.is_empty() or not _chapter_punched(ch_row, profile, codex):
					continue
			return {
				"kind": "camp_exchange",
				"id": ex_id,
				"settle_key": settle_key,
				"lines": (ex["lines"] as Array).duplicate(true),
				"consumes_pair_budget": true,
			}
	# (3) Chapter-tiered solo quip -> baseline LoreRows.camp_quip.
	var tiered: Dictionary = LoreRows.CAMP_QUIPS_BY_CHAPTER.get(approached_class, {})
	if not tiered.is_empty():
		var mask := punch_mask(approached_class, profile, codex)
		for tier in [5, 4, 2]:
			if tiered.has(tier) and tier - 1 < mask.size() and mask[tier - 1]:
				var lines: Array = tiered[tier]
				if not lines.is_empty():
					var qid := "camp.quip.%s.ch%d" % [String(SHORT_TOKENS.get(approached_class, approached_class)), tier]
					var text := String(lines[posmod(absi(hash(qid)) + walks, lines.size())])
					var speaker := String(SHORT_TOKENS.get(approached_class, approached_class))
					return {
						"kind": "solo_quip",
						"id": qid,
						"speaker": speaker,
						"text": text,
						"lines": [{"speaker": speaker, "text": text}],
						"consumes_pair_budget": false,
					}
	var base_quip := LoreRows.camp_quip(approached_class)
	if base_quip.is_empty():
		return {}
	var base_text := LoreRows.camp_quip_text(base_quip, walks)
	var base_speaker := String(base_quip["speaker"])
	return {
		"kind": "solo_quip",
		"id": String(base_quip["id"]),
		"speaker": base_speaker,
		"text": base_text,
		"lines": [{"speaker": base_speaker, "text": base_text}],
		"consumes_pair_budget": false,
	}


# Priority:
# (1) Patch rogue/wire reaction,
# (2) Pair Beat-2 call (if !pair_call_used, Beat 1 known, Beat 2 unknown, other pilot unlocked & != flying),
# (3) LoreRows.WORLD_CALLS (W2/W3 site crews + chapter-gated pilot calls).
static func pick_run_call(
	event: String, args: Array, world: int, flying_class: String, run_seed: int,
	unlocked_classes: Array, profile, codex, played_ids: Dictionary, pair_call_used: bool
) -> Dictionary:
	# (1) Patch rogue/wire reaction.
	if event == "enemy_killed" and args.size() > 0:
		var rogue_id := patch_rogue_for_kind(String(args[0]))
		if rogue_id != "":
			if played_ids.has(rogue_id):
				return {}
			var node: Dictionary = PATCH_TRAIL[rogue_id]
			var speaker := "unsigned" if rogue_id == "patch.rogue.w1" and not _chapter_punched(chapter("patch.ch2"), profile, codex) else "patch"
			return {
				"kind": "patch_trail",
				"id": rogue_id,
				"codex_id": rogue_id,
				"speaker": speaker,
				"text": LoreRows.call_text({"id": rogue_id, "text": node["call"]}, run_seed),
				"consumes_pair_budget": false,
			}
	if event == "world_fact" and args.size() > 0:
		var fact_id := String(args[0])
		if PATCH_TRAIL.has(fact_id) and String(PATCH_TRAIL[fact_id].get("kind", "")) == "wire" and not played_ids.has(fact_id):
			var node: Dictionary = PATCH_TRAIL[fact_id]
			return {
				"kind": "patch_trail",
				"id": fact_id,
				"codex_id": fact_id,
				"speaker": "patch",
				"text": LoreRows.call_text({"id": fact_id, "text": node["call"]}, run_seed),
				"consumes_pair_budget": false,
			}
	# (2) Pair Beat-2 call.
	if not pair_call_used and SHORT_TOKENS.has(flying_class):
		var known_fn := func(id: String) -> bool: return codex != null and bool(codex.known(id))
		for pid in pair_ids():
			var pair: Dictionary = PAIRS[pid]
			var pilots: Array = pair["pilots"]
			if not flying_class in pilots:
				continue
			var other := String(pilots[0] if String(pilots[1]) == flying_class else pilots[1])
			if other == flying_class:
				continue
			if not (other in unlocked_classes or _pilot_unlocked(other, profile)):
				continue
			var beat1_id := "pair.%s.1" % pid
			var beat2_id := "pair.%s.2" % pid
			if played_ids.has(beat2_id) or not known_fn.call(beat1_id) or known_fn.call(beat2_id):
				continue
			var field_row: Dictionary = pair["field"]
			if not LoreRows.call_matches(field_row, event, args):
				continue
			var variants: Dictionary = field_row.get("variants", {})
			if not variants.has(flying_class):
				continue
			return {
				"kind": "pair_field",
				"id": beat2_id,
				"pair_id": pid,
				"codex_id": beat2_id,
				"speaker": String(SHORT_TOKENS[other]),
				"pilot": other,
				"text": LoreRows.call_text({"id": beat2_id, "text": variants[flying_class]}, run_seed),
				"consumes_pair_budget": true,
			}
	# (3) LoreRows.WORLD_CALLS.
	for row in LoreRows.WORLD_CALLS:
		var cid := String(row["id"])
		if played_ids.has(cid):
			continue
		if int(row.get("world", 0)) != world:
			continue
		if not LoreRows.call_matches(row, event, args):
			continue
		if row.has("pilot"):
			var p := String(row["pilot"])
			if p == flying_class:
				continue
			if not (p in unlocked_classes or _pilot_unlocked(p, profile)):
				continue
		if row.has("requires_chapter"):
			var req := chapter(String(row["requires_chapter"]))
			if req.is_empty() or not _chapter_punched(req, profile, codex):
				continue
		return {
			"kind": "world_call",
			"id": cid,
			"speaker": String(row["speaker"]),
			"text": LoreRows.call_text(row, run_seed),
			"consumes_pair_budget": false,
		}
	return {}


static func _pilot_unlocked(class_id: String, profile) -> bool:
	var def := ClassDef.by_id(class_id)
	if def == null:
		return false
	if bool(def.starter):
		return true
	if profile == null:
		return false
	return bool(profile.has_pilot(class_id)) or ClassDef.unlock_open(def.unlock, Callable(profile, "earned"))


static func _boss_cleared(profile, pages: Array) -> bool:
	if profile != null:
		if profile.earned("brindle_routed") or profile.earned("waking_stilled") or profile.earned("mind_quieted"):
			return true
	for page in pages:
		if page is Dictionary:
			var outcome := String((page as Dictionary).get("outcome", ""))
			if outcome == "won" or (outcome == "" and bool((page as Dictionary).get("won", false))):
				return true
	return false


static func _all_present(pilots: Array, flying_class: String, standing_ids: Array) -> bool:
	for p in pilots:
		if String(p) != flying_class and not String(p) in standing_ids:
			return false
	return true


# ==============================================================================
# 4. Patch Wire Trail
# ==============================================================================

static func patch_node(node_id: String) -> Dictionary:
	if not PATCH_TRAIL.has(node_id):
		return {}
	return (PATCH_TRAIL[node_id] as Dictionary).duplicate(true)


static func patch_spot(wire_id: String, run_seed: int) -> Dictionary:
	var node: Dictionary = PATCH_TRAIL.get(wire_id, {})
	var spots: Array = node.get("spots", [])
	if spots.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [wire_id, run_seed])
	return (spots[rng.randi_range(0, spots.size() - 1)] as Dictionary).duplicate(true)


static func patch_rogue_for_kind(rogue_kind: String) -> String:
	for node_id in PATCH_TRAIL:
		var node: Dictionary = PATCH_TRAIL[node_id]
		if String(node.get("rogue_kind", "")) == rogue_kind:
			return String(node_id)
	return ""


# ==============================================================================
# 5. Adaptive Foreman Habit Ledger
# ==============================================================================

static func foreman_axis_index(axis: String) -> int:
	var idx := FOREMAN_AXIS_ORDER.find(axis)
	return idx + 1 if idx >= 0 else 0


static func foreman_axis_name(idx: int) -> String:
	if idx < 1 or idx > FOREMAN_AXIS_ORDER.size():
		return ""
	return FOREMAN_AXIS_ORDER[idx - 1]


static func record_foreman_axis(axis: String, run_number: int, profile) -> void:
	if profile == null:
		return
	var idx := foreman_axis_index(axis)
	if idx <= 0:
		return
	profile.set_stat("habit.foreman_last_axis", float(idx))
	profile.set_stat("habit.foreman_last_run", float(run_number))


static func classify_habits(profile, pages: Array, run = null) -> Dictionary:
	var total_runs := _total_runs(profile, pages)
	if profile == null or total_runs < HABIT_MIN_RUNS:
		return {
			"dormant": true,
			"total_runs": total_runs,
			"axis": "",
			"score": 0.0,
			"suppressed": false,
			"scores": {},
		}
	var risk := float(profile.stat("habit.trade_risk"))
	var safe := float(profile.stat("habit.trade_safe"))
	var cursed := float(profile.stat("habit.runs_cursed"))
	if run != null and run.has_method("cursed") and bool(run.cursed()):
		cursed += 1.0
	var blazing := float(profile.stat("habit.runs_blazing"))
	var heft := float(profile.stat("habit.runs_heft_high"))
	var circuit := float(profile.stat("habit.sig.circuit")) + float(profile.stat("habit.sig.arc"))
	var burst := float(profile.stat("habit.sig.burst")) + float(profile.stat("habit.sig.kinetic"))

	var scores := {
		"chronic_gambler": maxf(0.0, risk - safe * 0.5) if risk >= 2.0 and risk > safe else 0.0,
		"kindness_regular": maxf(0.0, safe - risk * 0.5) if safe >= 2.0 and safe >= risk else 0.0,
		"cursed_runner": cursed * 1.2 if cursed >= 1.0 else 0.0,
		"speed_demon": blazing * 1.1 if blazing >= 2.0 else 0.0,
		"heavy_roller": heft * 1.1 if heft >= 2.0 else 0.0,
		"sig_circuit": circuit * 1.0 if circuit >= 2.0 else 0.0,
		"sig_burst": burst * 1.0 if burst >= 2.0 else 0.0,
	}

	var last_axis := _read_last_axis(profile)
	var last_run := int(profile.stat("habit.foreman_last_run"))
	var on_cooldown := last_axis != "" and last_run > 0 and total_runs >= last_run and (total_runs - last_run) < FOREMAN_AXIS_COOLDOWN

	var best_axis := ""
	var best_score := 0.0
	var suppressed := false
	for axis in FOREMAN_AXIS_ORDER:
		var s := float(scores[axis])
		if s <= 0.0:
			continue
		if on_cooldown and axis == last_axis:
			suppressed = true
			continue
		if s > best_score:
			best_score = s
			best_axis = axis
	return {
		"dormant": false,
		"total_runs": total_runs,
		"axis": best_axis,
		"score": best_score,
		"suppressed": suppressed,
		"scores": scores,
	}


static func foreman_stage_memo(run_seed: int, stage: int, profile, pages: Array, run = null) -> String:
	var read := classify_habits(profile, pages, run)
	var axis := String(read["axis"])
	if bool(read["dormant"]) or axis == "":
		return ""
	# 50% nominal audit cadence guard (StageModifier.ROWS takes precedence at caller).
	if posmod(absi(hash([run_seed, stage, "foreman_adapt"])), 2) != 0:
		return ""
	var lines: Array = FOREMAN_AXES[axis]["stage_memos"]
	return String(lines[posmod(absi(hash([run_seed, stage, axis, "foreman_stage"])), lines.size())])


static func foreman_loss_memo(run_seed: int, source: String, profile, pages: Array, run = null) -> String:
	var read := classify_habits(profile, pages, run)
	var axis := String(read["axis"])
	if bool(read["dormant"]) or axis == "":
		return ""
	var lines: Array = FOREMAN_AXES[axis]["loss_memos"]
	return String(lines[posmod(absi(hash([run_seed, source, axis, "foreman_loss"])), lines.size())])


static func foreman_crown_line(run_seed: int, profile, pages: Array, run = null) -> String:
	var read := classify_habits(profile, pages, run)
	var axis := String(read["axis"])
	if bool(read["dormant"]) or axis == "":
		return ""
	var lines: Array = FOREMAN_AXES[axis]["crown_lines"]
	return String(lines[posmod(absi(hash([run_seed, axis, "foreman_crown"])), lines.size())])


static func _total_runs(profile, pages: Array) -> int:
	var total := pages.size()
	if profile == null:
		return total
	var pilot_sum := 0
	for cid in PILOT_CAST:
		pilot_sum += int(profile.stat("habit.pilot_runs." + cid))
	total = maxi(total, pilot_sum)
	total = maxi(total, int(profile.stat("deaths")) + int(profile.stat("runs_won")))
	total = maxi(total, int(profile.stat("door.runs_started")))
	total = maxi(total, int(profile.stat("habit.runs_total")))
	return total


static func _read_last_axis(profile) -> String:
	if profile == null:
		return ""
	var raw = profile.stat("habit.foreman_last_axis")
	if raw is String:
		return raw if FOREMAN_AXES.has(raw) else ""
	return foreman_axis_name(int(raw))


# ==============================================================================
# 6. Static Integrity Validator (zero scene tree required)
# ==============================================================================

static func validate(class_ids: Array, signal_names: Array, speaker_ids: Array) -> Array[String]:
	return validate_tables(
		CHAPTERS, PAIRS, PATCH_TRAIL, FOREMAN_AXES,
		LoreRows.WORLD_CALLS, LoreRows.CAMP_EXCHANGES, LoreRows.CAMP_QUIPS_BY_CHAPTER,
		class_ids, signal_names, speaker_ids
	)


static func validate_tables(
	chapters: Array, pairs: Dictionary, patch_trail: Dictionary, foreman_axes: Dictionary,
	world_calls: Array, camp_exchanges: Array, camp_quips_by_chapter: Dictionary,
	class_ids: Array, signal_names: Array, speaker_ids: Array
) -> Array[String]:
	var problems: Array[String] = []
	if "patch" in class_ids:
		problems.append("patch must not be in ClassDef class_ids")
	# 1. Validate 8 casts x 5 chapters = 40 chapters.
	if chapters.size() != CAST_ORDER.size() * CHAPTERS_PER_CAST:
		problems.append("chapters: expected %d, got %d" % [CAST_ORDER.size() * CHAPTERS_PER_CAST, chapters.size()])
	var ch_ids := {}
	var per_cast := {}
	for cid in CAST_ORDER:
		per_cast[cid] = []
	for row in chapters:
		var id := String(row.get("id", ""))
		var cast := String(row.get("cast", ""))
		var num := int(row.get("num", 0))
		if id == "" or ch_ids.has(id):
			problems.append("chapter: missing or duplicate id %s" % id)
		ch_ids[id] = true
		if not cast in CAST_ORDER:
			problems.append("chapter %s: unknown cast %s" % [id, cast])
		else:
			if cast != "moss" and cast != "patch" and not cast in class_ids:
				problems.append("chapter %s: pilot cast %s not in class_ids" % [id, cast])
			(per_cast[cast] as Array).append(num)
		if id != "%s.ch%d" % [cast, num]:
			problems.append("chapter %s: id does not match <cast>.ch<num>" % id)
		if num < 1 or num > CHAPTERS_PER_CAST:
			problems.append("chapter %s: num %d out of range" % [id, num])
		var world := int(row.get("world", 0))
		if world < 1 or world > 3:
			problems.append("chapter %s: world %d out of 1..3" % [id, world])
		var is_tally := cast == "tally"
		_check_text(problems, "chapter %s title" % id, String(row.get("title", "")), TITLE_WORDS, is_tally)
		_check_text(problems, "chapter %s note" % id, String(row.get("note", "")), NOTE_WORDS, is_tally)
		if (row.get("accepts", []) as Array).is_empty():
			problems.append("chapter %s: empty accepts" % id)
		if id == "patch.ch1" and not bool(row.get("hidden", false)):
			problems.append("chapter patch.ch1: must have hidden: true")
		elif id != "patch.ch1" and bool(row.get("hidden", false)):
			problems.append("chapter %s: only patch.ch1 may be hidden" % id)
	for cid in CAST_ORDER:
		var nums: Array = per_cast[cid]
		nums.sort()
		if nums != [1, 2, 3, 4, 5]:
			problems.append("cast %s: chapters %s != [1, 2, 3, 4, 5]" % [cid, str(nums)])

	# 2. Validate 15-pair chemistry matrix.
	var expected_pairs := {}
	for i in PILOT_CAST.size():
		for j in range(i + 1, PILOT_CAST.size()):
			expected_pairs[pair_id(PILOT_CAST[i], PILOT_CAST[j])] = true
	if pairs.size() != expected_pairs.size():
		problems.append("pairs: expected %d pairs, got %d" % [expected_pairs.size(), pairs.size()])
	for ep in expected_pairs:
		if not pairs.has(ep):
			problems.append("pairs: missing pair %s" % ep)
	for pid in pairs:
		var pair: Dictionary = pairs[pid]
		var pilots: Array = pair.get("pilots", [])
		if pilots.size() != 2 or String(pilots[0]) == String(pilots[1]):
			problems.append("pair %s: invalid or self pair %s" % [pid, str(pilots)])
			continue
		var canon := pair_id(String(pilots[0]), String(pilots[1]))
		if canon != String(pid):
			problems.append("pair %s: key mismatch canonical %s" % [pid, canon])
		for p in pilots:
			if not String(p) in class_ids:
				problems.append("pair %s: pilot %s not in class_ids" % [pid, str(p)])
		var spark: Array = pair.get("spark", [])
		if spark.size() != 2:
			problems.append("pair %s: spark must have 2 lines" % pid)
		for line in spark:
			var sp := String((line as Dictionary).get("speaker", ""))
			if not sp in speaker_ids:
				problems.append("pair %s spark: unknown speaker %s" % [pid, sp])
			_check_text(problems, "pair %s spark" % pid, String((line as Dictionary).get("text", "")), EXCHANGE_WORD_CAP, sp == "tally")
		var field: Dictionary = pair.get("field", {})
		var sig := String(field.get("on", ""))
		if not sig in signal_names:
			problems.append("pair %s field: unknown signal %s" % [pid, sig])
		var variants: Dictionary = field.get("variants", {})
		for p in pilots:
			var p_str := String(p)
			if not variants.has(p_str):
				problems.append("pair %s field: missing variant for flying %s" % [pid, p_str])
				continue
			var other := String(pilots[0] if String(pilots[1]) == p_str else pilots[1])
			var other_tok := String(SHORT_TOKENS.get(other, ""))
			for vline in variants[p_str]:
				_check_text(problems, "pair %s field (%s)" % [pid, p_str], String(vline), CALL_WORD_CAP, other_tok == "tally")
		var payoff: Dictionary = pair.get("payoff", {})
		var pname := String(payoff.get("name", ""))
		_check_text(problems, "pair %s payoff name" % pid, pname, PAYOFF_NAME_WORDS, false)
		if pname.contains(":"):
			problems.append("pair %s payoff name: must not contain colon" % pid)
		var plines: Array = payoff.get("lines", [])
		if plines.size() != 2:
			problems.append("pair %s payoff: must have 2 lines" % pid)
		for line in plines:
			var sp := String((line as Dictionary).get("speaker", ""))
			if not sp in speaker_ids:
				problems.append("pair %s payoff: unknown speaker %s" % [pid, sp])
			_check_text(problems, "pair %s payoff" % pid, String((line as Dictionary).get("text", "")), EXCHANGE_WORD_CAP, sp == "tally")
		_check_text(problems, "pair %s codex_text" % pid, String(payoff.get("codex_text", "")), NOTE_WORDS, "tally" in pilots)
		_check_text(problems, "pair %s margin_note" % pid, String(payoff.get("margin_note", "")), EXCHANGE_WORD_CAP, "tally" in pilots)
		if String(payoff.get("links_to", "")) == "":
			problems.append("pair %s payoff: missing links_to" % pid)

	# 3. Validate Patch 2-half trail (6 nodes: 3 rogues + 3 wires).
	if patch_trail.size() != 6:
		problems.append("patch_trail: expected 6 nodes, got %d" % patch_trail.size())
	for w in [1, 2, 3]:
		var rid := "patch.rogue.w%d" % w
		var wid := "patch.wire.w%d" % w
		if not patch_trail.has(rid) or not patch_trail.has(wid):
			problems.append("patch_trail: missing world %d pair" % w)
			continue
		var rnode: Dictionary = patch_trail[rid]
		var wnode: Dictionary = patch_trail[wid]
		if String(rnode.get("reveals", "")) != wid:
			problems.append("patch_trail %s: must reveal %s" % [rid, wid])
		if String(wnode.get("requires", "")) != rid:
			problems.append("patch_trail %s: must require %s" % [wid, rid])
		if (wnode.get("spots", []) as Array).size() < 2:
			problems.append("patch_trail %s: needs at least 2 seeded spots" % wid)
		for nid in [rid, wid]:
			var n: Dictionary = patch_trail[nid]
			_check_text(problems, "patch %s log" % nid, String(n.get("log", "")), NOTE_WORDS, false)
			for cline in n.get("call", []):
				_check_text(problems, "patch %s call" % nid, String(cline), CALL_WORD_CAP, false)

	# 4. Validate Foreman 7 habit axes.
	if foreman_axes.size() != FOREMAN_AXIS_ORDER.size():
		problems.append("foreman_axes: expected %d axes, got %d" % [FOREMAN_AXIS_ORDER.size(), foreman_axes.size()])
	for axis in FOREMAN_AXIS_ORDER:
		if not foreman_axes.has(axis):
			problems.append("foreman_axes: missing axis %s" % axis)
			continue
		var arow: Dictionary = foreman_axes[axis]
		var smemos: Array = arow.get("stage_memos", [])
		var lmemos: Array = arow.get("loss_memos", [])
		var clines: Array = arow.get("crown_lines", [])
		if smemos.is_empty() or lmemos.is_empty() or clines.is_empty():
			problems.append("foreman_axes %s: missing stage/loss/crown lines" % axis)
		for m in smemos:
			_check_text(problems, "foreman %s stage_memo" % axis, String(m), STAGE_MEMO_WORD_CAP, false)
		for m in lmemos:
			_check_text(problems, "foreman %s loss_memo" % axis, String(m), LOSS_MEMO_WORD_CAP, false)
		for m in clines:
			_check_text(problems, "foreman %s crown_line" % axis, String(m), CALL_WORD_CAP, false)

	# 5. Validate LoreRows additive WORLD_CALLS, CAMP_EXCHANGES, CAMP_QUIPS_BY_CHAPTER.
	if world_calls.size() < 13:
		problems.append("world_calls: expected at least 13 rows, got %d" % world_calls.size())
	var wc_ids := {}
	for row in world_calls:
		var cid := String(row.get("id", ""))
		if cid == "" or wc_ids.has(cid):
			problems.append("world_calls: missing or duplicate id %s" % cid)
		wc_ids[cid] = true
		var sp := String(row.get("speaker", ""))
		if not sp in speaker_ids:
			problems.append("world_calls %s: unknown speaker %s" % [cid, sp])
		var sig := String(row.get("on", ""))
		if not sig in signal_names:
			problems.append("world_calls %s: unknown signal %s" % [cid, sig])
		var lines: Array = row.get("text", []) if row.get("text") is Array else [row.get("text", "")]
		for line in lines:
			_check_text(problems, "world_calls %s" % cid, String(line), CALL_WORD_CAP, sp == "tally")

	var ex_ids := {}
	for ex in camp_exchanges:
		var eid := String(ex.get("id", ""))
		if eid == "" or ex_ids.has(eid):
			problems.append("camp_exchanges: missing or duplicate id %s" % eid)
		ex_ids[eid] = true
		for line in ex.get("lines", []):
			var sp := String((line as Dictionary).get("speaker", ""))
			if not sp in speaker_ids:
				problems.append("camp_exchanges %s: unknown speaker %s" % [eid, sp])
			_check_text(problems, "camp_exchanges %s" % eid, String((line as Dictionary).get("text", "")), EXCHANGE_WORD_CAP, sp == "tally")

	for pilot in camp_quips_by_chapter:
		if not String(pilot) in class_ids:
			problems.append("camp_quips_by_chapter: unknown pilot %s" % str(pilot))
		var tiers: Dictionary = camp_quips_by_chapter[pilot]
		for tier in tiers:
			for line in tiers[tier]:
				_check_text(problems, "camp_quips_by_chapter %s ch%s" % [pilot, str(tier)], String(line), CALL_WORD_CAP, String(pilot) == "tally")

	return problems


static func _check_text(problems: Array[String], label: String, text: String, max_words: int, forbid_paid: bool) -> void:
	var words := WordBudget.words_in(text)
	if words < 1 or words > max_words:
		problems.append("%s: %d words (cap %d): %s" % [label, words, max_words, text])
	for sub in BANNED_SUBSTRINGS:
		if text.contains(sub):
			problems.append("%s: banned token '%s'" % [label, sub])
	var lower := text.to_lower()
	for phrase in BANNED_PHRASES:
		if lower.contains(phrase):
			problems.append("%s: banned phrase '%s'" % [label, phrase])
	for raw_tok in lower.split(" ", false):
		var tok := _strip_punct(raw_tok)
		if tok in BANNED_WORDS:
			problems.append("%s: banned word '%s'" % [label, tok])
		if forbid_paid and tok == "paid":
			problems.append("%s: forbidden PAID token in Tally copy" % label)


static func _strip_punct(token: String) -> String:
	var s := token
	while s.length() > 0 and not _is_alnum(s.unicode_at(0)):
		s = s.substr(1)
	while s.length() > 0 and not _is_alnum(s.unicode_at(s.length() - 1)):
		s = s.substr(0, s.length() - 1)
	return s


static func _is_alnum(c: int) -> bool:
	return (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122)
