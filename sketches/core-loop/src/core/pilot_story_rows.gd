extends RefCounted

const PAIR_CODEX_META := {
	"hint": "Two freed pilots share one story at camp after a boss falls.",
	"clue": "Hear both pilots swap notes at camp, roll loud in play, then return after a boss",
}

const CHAPTERS := [
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
			"Snipped that leash with kitchen shears. Brick seam near powerhouse.",
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
			"Not dead, just compiling. Mind the tea and the jumper leads.",
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
			"Shimmed its governor with cardboard and spite. Check the east gallery.",
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
			"Borrowed two relays and fixed the hum. Do not tell Moss.",
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
			"Voided Tender 7's service plan. My wok dish faces the west fin.",
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
			"Wok dish gets better signal than the Fleet. Keep the reels.",
		],
	},
}

const FOREMAN_AXES := {
	"chronic_gambler": {
		"stage_memos": [
			"Variance appetite noted. Insurance sunsetted.",
			"High-risk alignment logged. Grateful for your metrics.",
			"Unscheduled gambling scaled. Proceeding smoothly.",
		],
		"loss_memos": [
			"Unscheduled gamble concluded as projected. Grateful for your risk metrics.",
			"Sunsetting this variance experiment. Thank you for your bold learnings.",
			"Your appetite for risk has been entered into quarterly alignment.",
		],
		"crown_lines": [
			"You gambled every shift and arrived anyway. Fascinating variance.",
			"Unhedged deliverables all the way to summit. Respectfully unaligned.",
		],
	},
	"kindness_regular": {
		"stage_memos": [
			"Preferred partner detected. Loyalty fees aligned.",
			"Thank you for choosing synergistic certainty again.",
			"Frictionless subscriber verified. Metrics appreciated.",
		],
		"loss_memos": [
			"Our kindness kiosks appreciate your repeat synergy. Next shift scheduled.",
			"Sunsetting this hull for a loyal subscriber. Grateful for your metrics.",
			"Regular kindness account logged. Replacement hull queued on schedule.",
		],
		"crown_lines": [
			"A valued subscriber at the Crown. We prepared your seat.",
			"Seamless loyalty across three worlds. Your time card stays blank.",
		],
	},
	"cursed_runner": {
		"stage_memos": [
			"Non-standard liabilities carried. Alignment unaffected.",
			"Cursed terms detected. Audit synergy active.",
			"Legacy liabilities onboarded. Grateful for transparency.",
		],
		"loss_memos": [
			"Non-standard contract terms sunsetted cleanly. Grateful for your audit data.",
			"Liability entry archived for quarterly alignment. Replacement hull ready.",
			"We appreciate your commitment to carrying unapproved operational risk.",
		],
		"crown_lines": [
			"Carrying curses to the summit is bold. Slightly unaligned.",
			"Legacy risk stacked to the rafters. Admirably stubborn metrics.",
		],
	},
	"speed_demon": {
		"stage_memos": [
			"Excess velocity logged. Right-sizing your brakes.",
			"Pace exceeds forecast. Alignment recalibrating.",
			"High-velocity metrics noted. Please slow smoothly.",
		],
		"loss_memos": [
			"Unapproved velocity sunsetted ahead of schedule. Thank you for hurrying.",
			"High-speed shift closed ahead of forecast. Grateful for the metrics.",
			"Accelerated onboarding concluded abruptly. Replacement hull queued on time.",
		],
		"crown_lines": [
			"Early arrival noted. Please wait while the storm catches up.",
			"Synergistic speed, zero regard for our schedule. Impressive metrics.",
		],
	},
	"heavy_roller": {
		"stage_memos": [
			"Payload exceeds spec. Floors right-sized.",
			"Heavy haul logged. Wear billed separately.",
			"Surplus tonnage aligned. Grateful for steel.",
		],
		"loss_memos": [
			"Excess heft sunsetted from the floor. Grateful for the scrap metrics.",
			"Overweight delivery concluded cleanly. Our floors send warmest regards.",
			"Heavy throughput archived. We have scheduled fresh concrete with gratitude.",
		],
		"crown_lines": [
			"You brought half the works upstairs. Impressive tonnage.",
			"Maximum payload alignment achieved. Our cables filed a quiet complaint.",
		],
	},
	"sig_circuit": {
		"stage_memos": [
			"Unmetered arc draw noted. Grounding aligned.",
			"Circuit traffic elevated. Synergies metered.",
			"Unauthorized voltage logged. Breakers right-sized.",
		],
		"loss_memos": [
			"Unauthorised voltage spike sunsetted. Thank you for testing our insulation.",
			"Circuit surge resolved with synergistic efficiencies. Breakers reset on schedule.",
			"Elevated arc metrics archived. Grateful for your energetic contributions.",
		],
		"crown_lines": [
			"You brought live current to a lightning spire. Ambitious.",
			"Unmetered voltage on the summit grid. Bold thought leadership.",
		],
	},
	"sig_burst": {
		"stage_memos": [
			"Impact spikes recorded. Bracing aligned.",
			"Blunt force trend noted. Synergies adjusting.",
			"Kinetic disruption logged. Grateful for data.",
		],
		"loss_memos": [
			"High-impact approach sunsetted and absorbed. Replacement hull ready.",
			"Forceful methods archived. We still recommend our frictionless workflow.",
			"Disruptive kinetic metrics noted. Thank you for testing our plating.",
		],
		"crown_lines": [
			"Every door opened by impact. Direct, if somewhat loud.",
			"Kinetic disruption across three worlds. Our maintenance teams send gratitude.",
		],
	},
}
