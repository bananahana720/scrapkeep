extends RefCounted

const EXCHANGE_LINE_WORD_CAP := 14
const FIELD_NOTE_WORD_CAP := 40
const INTRO_LINE_WORD_CAP := 12

# One row per readable line. Exchange lines share an exchange id and follow array order.
# Zone ids name the alpha route, independently of the sketch's current stage slots.
const ROWS := [
	{
		"id": "lore.spillway.moss.spare", "kind": "exchange", "zone": "1-1",
		"exchange": "lore.spillway.exchange", "speaker": "Moss", "skippable": true,
		"text": "Packed you a spare seal. The river doesn't take promises.",
	},
	{
		"id": "lore.spillway.crew.leak", "kind": "exchange", "zone": "1-1",
		"exchange": "lore.spillway.exchange", "speaker": "Pump crew", "skippable": true,
		"text": "We fixed that leak yesterday.",
	},
	{
		"id": "lore.spillway.moss.yesterday", "kind": "exchange", "zone": "1-1",
		"exchange": "lore.spillway.exchange", "speaker": "Moss", "skippable": true,
		"text": "Yesterday's seal is in my bucket. Take today's.",
	},
	{
		"id": "lore.spillway.note.shift", "kind": "field_note", "zone": "1-1",
		"text": "Shift log: intake cleared. Fleet took the spare grate. Fish now larger than permitted.",
	},
	{
		"id": "lore.spillway.note.paint", "kind": "field_note", "zone": "1-1",
		"text": "Wall stencil: HIGH WATER. Below it, in chalk: Which time?",
	},
	{
		"id": "lore.spillway.note.handwheel", "kind": "field_note", "zone": "1-1",
		"text": "Maintenance tag: handwheel replaced with a serving tray. Turns fine. Return before supper.",
	},
	{
		"id": "lore.spillway.note.old_marks", "kind": "field_note", "zone": "1-1",
		"text": "Survey scrap: old flood marks inside the sealed housing. Outside stone is dry. Left the question on the next shift's sheet.",
	},
	{
		"id": "lore.spillway.note.grease", "kind": "field_note", "zone": "1-1",
		"text": "Grease tin label: FOR THE PUMP. Someone has added: The pump knows who you are.",
	},
	{
		"id": "lore.spillway.note.hook", "kind": "field_note", "zone": "1-1",
		"text": "Repair bill: one bent hook, one missing lunch pail. Crew insists these are separate incidents.",
	},
	{
		"id": "lore.spillway.note.spares", "kind": "field_note", "zone": "1-1",
		"text": "Stores ledger: spare bearings requisitioned. Pump still expected to run. Filed request for spare expectations.",
	},
	{
		"id": "lore.spillway.intro.warden", "kind": "intro", "zone": "1-1", "subject": "warden",
		"text": "Spillway Warden. Intake closed. Local authorization no longer recognized.",
	},
	{
		"id": "lore.spillway.intro.brindle", "kind": "intro", "zone": "1-1", "subject": "brindle",
		"text": "Brindle: Your repair reserve is now Fleet inventory. Thank you.",
	},
	{
		"id": "lore.reach.crew.cable", "kind": "exchange", "zone": "1-2",
		"exchange": "lore.reach.exchange", "speaker": "Cable crew", "skippable": true,
		"text": "Fleet weighed the cable. Forgot to count who was hanging from it.",
	},
	{
		"id": "lore.reach.moss.count", "kind": "exchange", "zone": "1-2",
		"exchange": "lore.reach.exchange", "speaker": "Moss", "skippable": true,
		"text": "I've counted. You're all here. Sit down; I'll mend the harnesses.",
	},
	{
		"id": "lore.reach.crew.kettle", "kind": "exchange", "zone": "1-2",
		"exchange": "lore.reach.exchange", "speaker": "Cable crew", "skippable": true,
		"text": "Kettle's still on the far side.",
	},
	{
		"id": "lore.reach.note.load", "kind": "field_note", "zone": "1-2",
		"text": "Load docket: three housings across, two back. Third now a roof. Roof crew declined return shipment.",
	},
	{
		"id": "lore.reach.note.swing", "kind": "field_note", "zone": "1-2",
		"text": "Wall stencil: NO SWINGING FROM SERVICE HOOKS. Inspection note: stencil only visible from service hook.",
	},
	{
		"id": "lore.reach.note.anchor", "kind": "field_note", "zone": "1-2",
		"text": "Anchor tag: fourth repair, same bolt. Whoever made the first thread had a steady hand.",
	},
	{
		"id": "lore.reach.note.bell", "kind": "field_note", "zone": "1-2",
		"text": "Inspection scrap: bell rang below the empty shaft. No wire on this side. No volunteer for the other.",
	},
	{
		"id": "lore.reach.note.roll", "kind": "field_note", "zone": "1-2",
		"text": "Freight tally: drum rolled itself downhill. Marked as delivered. Recipient disputes address.",
	},
	{
		"id": "lore.reach.note.hands", "kind": "field_note", "zone": "1-2",
		"text": "Crew log: cable guide patched in three different hands. None signed. All left room for the next patch.",
	},
	{
		"id": "lore.reach.note.requisition", "kind": "field_note", "zone": "1-2",
		"text": "Fleet manifest: cableway classified as idle metal. Attached crew tally covers both sides in grease.",
	},
	{
		"id": "lore.reach.intro.warden", "kind": "intro", "zone": "1-2", "subject": "warden",
		"text": "Cable Reach Warden. Still guarding a shift nobody remembers starting.",
	},
	{
		"id": "lore.reach.intro.brindle", "kind": "intro", "zone": "1-2", "subject": "brindle",
		"text": "Brindle: A working cableway. Excellent. We'll collect the anchors first.",
	},

	{
		"id": "lore.dig_entry.exchange.1", "kind": "exchange", "zone": "2-1",
		"exchange": "lore.dig_entry.exchange",
		"speaker": "Moss",
		"skippable": true,
		"text": "Brought spare lamps. Keep one for the walk back.",
	},
	{
		"id": "lore.dig_entry.exchange.2", "kind": "exchange", "zone": "2-1",
		"exchange": "lore.dig_entry.exchange",
		"speaker": "Dig crew",
		"skippable": true,
		"text": "The wall knocked first. We stopped calling it settling.",
	},
	{
		"id": "lore.dig_entry.exchange.3", "kind": "exchange", "zone": "2-1",
		"exchange": "lore.dig_entry.exchange",
		"speaker": "Moss",
		"skippable": true,
		"text": "Good. Put the tools down when it answers.",
	},
	{
		"id": "lore.dig_entry.note.1", "kind": "field_note", "zone": "2-1",
		"text": "Lamp tally: six issued, seven returned. Extra lamp burns cold. Nobody claimed it.",
	},
	{
		"id": "lore.dig_entry.note.2", "kind": "field_note", "zone": "2-1",
		"text": "Shift board: knock twice before drilling. Wait for the second knock to finish.",
	},
	{
		"id": "lore.dig_entry.note.3", "kind": "field_note", "zone": "2-1",
		"text": "Rail repair: bent axle replaced. Cart still leans toward the sealed tunnel.",
	},
	{
		"id": "lore.dig_entry.note.4", "kind": "field_note", "zone": "2-1",
		"text": "Lunch tin: KEEP CLOSED. Something below has learned the sound of the latch.",
	},
	{
		"id": "lore.dig_entry.note.5", "kind": "field_note", "zone": "2-1",
		"text": "Survey mark: measured the same shaft twice. Second measurement includes a landing.",
	},
	{
		"id": "lore.dig_entry.note.6", "kind": "field_note", "zone": "2-1",
		"text": "Lunch notice: tins stay above the ramp. Whoever collected yesterday's returns washed the lids from inside.",
	},
	{
		"id": "lore.dig_entry.note.7", "kind": "field_note", "zone": "2-1",
		"text": "Survey sheet: cliff height unchanged. Chalk marks below the plates sit one boot higher each morning.",
	},
	{
		"id": "lore.dig_entry.intro.warden", "kind": "intro", "zone": "2-1",
		"subject": "warden",
		"text": "Crew notice: borrowed lights go back on the rack. Even found ones.",
	},
	{
		"id": "lore.dig_entry.intro.waking", "kind": "intro", "zone": "2-1",
		"subject": "waking",
		"text": "Waking: I heard the sweepings. You can put the broom down.",
	},
	{
		"id": "lore.dig_depths.exchange.1", "kind": "exchange", "zone": "2-2",
		"exchange": "lore.dig_depths.exchange",
		"speaker": "Lift crew",
		"skippable": true,
		"text": "Second ramp's clear. Something carried our chalk down ahead of us.",
	},
	{
		"id": "lore.dig_depths.exchange.2", "kind": "exchange", "zone": "2-2",
		"exchange": "lore.dig_depths.exchange",
		"speaker": "Moss",
		"skippable": true,
		"text": "Take the east ramp. I'll keep a lamp at the top.",
	},
	{
		"id": "lore.dig_depths.exchange.3", "kind": "exchange", "zone": "2-2",
		"exchange": "lore.dig_depths.exchange",
		"speaker": "Lift crew",
		"skippable": true,
		"text": "Keep two. The first one has started casting its own shadow.",
	},
	{
		"id": "lore.dig_depths.note.1", "kind": "field_note", "zone": "2-2",
		"text": "Deep shift: beacon reached by the east ramp. Return tally includes one descent nobody remembers making.",
	},
	{
		"id": "lore.dig_depths.note.2", "kind": "field_note", "zone": "2-2",
		"text": "Cover inspection: middle bench plates seated. Fresh grit on top. Something underneath has swept its side clean.",
	},
	{
		"id": "lore.dig_depths.note.3", "kind": "field_note", "zone": "2-2",
		"text": "Gate docket: deep tier hinges oiled. Gate opened toward the beacon while the crew held it shut.",
	},
	{
		"id": "lore.dig_depths.note.4", "kind": "field_note", "zone": "2-2",
		"text": "Survey note: second cliff measured. Same height as yesterday. Echo came back with an extra number.",
	},
	{
		"id": "lore.dig_depths.note.5", "kind": "field_note", "zone": "2-2",
		"text": "Camp stores: drill bits boxed on the middle bench. Box warm. Lamp swarm gathered around the packing list.",
	},
	{
		"id": "lore.dig_depths.note.6", "kind": "field_note", "zone": "2-2",
		"text": "Repair ticket: west cover needs new bolts. Brood returned the old ones in size order. No washers.",
	},
	{
		"id": "lore.dig_depths.note.7", "kind": "field_note", "zone": "2-2",
		"text": "Last shift: lamp left at the second ramp. Found it facing uphill. Nobody volunteered to turn it back.",
	},
	{
		"id": "lore.dig_depths.intro.warden", "kind": "intro", "zone": "2-2",
		"subject": "warden",
		"text": "Brood Warden. Deep works closed. The brood has counted every bolt.",
	},
	{
		"id": "lore.dig_depths.intro.waking", "kind": "intro", "zone": "2-2",
		"subject": "waking",
		"text": "Pump report: water clear. Sediment forms neat circles around every bolt.",
	},
	{
		"id": "lore.highdraft_deck.exchange.1", "kind": "exchange", "zone": "3-1",
		"exchange": "lore.highdraft_deck.exchange",
		"speaker": "Deck crew",
		"skippable": true,
		"text": "Wind took the wrench. Sent back a spoon.",
	},
	{
		"id": "lore.highdraft_deck.exchange.2", "kind": "exchange", "zone": "3-1",
		"exchange": "lore.highdraft_deck.exchange",
		"speaker": "Moss",
		"skippable": true,
		"text": "Fits the same nut. Keep it.",
	},
	{
		"id": "lore.highdraft_deck.exchange.3", "kind": "exchange", "zone": "3-1",
		"exchange": "lore.highdraft_deck.exchange",
		"speaker": "Deck crew",
		"skippable": true,
		"text": "Had our initials on it already.",
	},
	{
		"id": "lore.highdraft_deck.note.1", "kind": "field_note", "zone": "3-1",
		"text": "Deck ledger: three loose panels, two recovered. Third panel seen flying level.",
	},
	{
		"id": "lore.highdraft_deck.note.2", "kind": "field_note", "zone": "3-1",
		"text": "Rigging card: tension holds. Cable sings before the gust reaches the mast.",
	},
	{
		"id": "lore.highdraft_deck.note.3", "kind": "field_note", "zone": "3-1",
		"text": "Galley notice: lids tethered during supper. Soup now travels farther than gossip.",
	},
	{
		"id": "lore.highdraft_deck.note.4", "kind": "field_note", "zone": "3-1",
		"text": "Flight log: flotilla turned together. No signal sent from the bridge.",
	},
	{
		"id": "lore.highdraft_deck.note.5", "kind": "field_note", "zone": "3-1",
		"text": "Repair stencil: PATCH HERE. Paint underneath names tomorrow's shift.",
	},
	{
		"id": "lore.highdraft_deck.note.6", "kind": "field_note", "zone": "3-1",
		"text": "Harpoon post docket: every rim post checked. One fresh hook mark faces away from every island.",
	},
	{
		"id": "lore.highdraft_deck.note.7", "kind": "field_note", "zone": "3-1",
		"text": "Beacon watch: lens steady across both bridges. Shadow on the middle island keeps arriving before the light.",
	},
	{
		"id": "lore.highdraft_deck.intro.warden", "kind": "intro", "zone": "3-1",
		"subject": "warden",
		"text": "Tool locker: spoon filed as wrench. Wrench filed as weather loss.",
	},
	{
		"id": "lore.highdraft_deck.intro.mind", "kind": "intro", "zone": "3-1",
		"subject": "mind",
		"text": "Mind: I entered your return trip. Please leave the time blank.",
	},
	{
		"id": "lore.highdraft_core.exchange.1", "kind": "exchange", "zone": "3-2",
		"exchange": "lore.highdraft_core.exchange",
		"speaker": "Moss",
		"skippable": true,
		"text": "Long crossing today. Tie your tools before the crown takes them.",
	},
	{
		"id": "lore.highdraft_core.exchange.2", "kind": "exchange", "zone": "3-2",
		"exchange": "lore.highdraft_core.exchange",
		"speaker": "Signal crew",
		"skippable": true,
		"text": "Tied them. Knot came back with somebody else's hands in it.",
	},
	{
		"id": "lore.highdraft_core.exchange.3", "kind": "exchange", "zone": "3-2",
		"exchange": "lore.highdraft_core.exchange",
		"speaker": "Moss",
		"skippable": true,
		"text": "Set it down. I'll mend your gloves after we cross.",
	},
	{
		"id": "lore.highdraft_core.note.1", "kind": "field_note", "zone": "3-2",
		"text": "Crown survey: islands stand higher than the lower watch. Net deck unchanged. Fall estimate returned in another hand.",
	},
	{
		"id": "lore.highdraft_core.note.2", "kind": "field_note", "zone": "3-2",
		"text": "Bridge repair: both long spans checked. Middle island crew heard boots stop halfway. No weight on either span.",
	},
	{
		"id": "lore.highdraft_core.note.3", "kind": "field_note", "zone": "3-2",
		"text": "Barge log: vault run completed. Empty hull rode low on return. Cargo sheet lists the crew's names.",
	},
	{
		"id": "lore.highdraft_core.note.4", "kind": "field_note", "zone": "3-2",
		"text": "Thermal card: all three columns clear the highest island. Loose tally sheet stayed overhead, turning its own pages.",
	},
	{
		"id": "lore.highdraft_core.note.5", "kind": "field_note", "zone": "3-2",
		"text": "West cable inspection: knots hold. Voice in the line asks which knot belongs to which worker.",
	},
	{
		"id": "lore.highdraft_core.note.6", "kind": "field_note", "zone": "3-2",
		"text": "Post service: rim hooks greased. Choir repeated the crew count. Each answer came from the next island.",
	},
	{
		"id": "lore.highdraft_core.note.7", "kind": "field_note", "zone": "3-2",
		"text": "Final watch: beacon reached by both bridges. Supper kept warm. Empty place has a glove folded beside it.",
	},
	{
		"id": "lore.highdraft_core.intro.warden", "kind": "intro", "zone": "3-2",
		"subject": "warden",
		"text": "Choir Warden. Crown watch closed. The choir answers for the crew.",
	},
	{
		"id": "lore.highdraft_core.intro.mind", "kind": "intro", "zone": "3-2",
		"subject": "mind",
		"text": "Lookout scrap: island lights blink in order. Count starts before the first.",
	},
	# Boss threat lines, one per boss and pilot (Andrew's design answer 12, "One line each",
	# 2026-10-17). Each sits at the world's last zone, where the arena opens, and wins over the
	# boss row without a pilot, which stays as the fallback. The Mind's lines answer its tune
	# hidden backwards in the Spillway music (answer 9).
	# TONE-READ: boss threat lines; every line awaits Andrew's read.
	{
		"id": "lore.reach.intro.brindle.pylon_engineer", "kind": "intro", "zone": "1-2",
		"subject": "brindle", "pilot": "pylon_engineer",
		"text": "Brindle: Fastest fox on record. I've rounded you up to two.",
	},
	{
		"id": "lore.reach.intro.brindle.runner_gunner", "kind": "intro", "zone": "1-2",
		"subject": "brindle", "pilot": "runner_gunner",
		"text": "Brindle: Rivet, a perfect record. Fleet policy is to audit perfect records.",
	},
	{
		"id": "lore.reach.intro.brindle.demolitions_caster", "kind": "intro", "zone": "1-2",
		"subject": "brindle", "pilot": "demolitions_caster",
		"text": "Brindle: Take your time measuring, Kest. The Fleet bills by the hour.",
	},
	{
		"id": "lore.reach.intro.brindle.tarn", "kind": "intro", "zone": "1-2",
		"subject": "brindle", "pilot": "tarn",
		"text": "Brindle: A gentle tiger in a snarling machine. I'll address the machine.",
	},
	{
		"id": "lore.reach.intro.brindle.tally", "kind": "intro", "zone": "1-2",
		"subject": "brindle", "pilot": "tally",
		"text": "Brindle: Tally. My rival ledger. Tonight we see whose columns balance.",
	},
	{
		"id": "lore.reach.intro.brindle.remembered_cannon", "kind": "intro", "zone": "1-2",
		"subject": "brindle", "pilot": "remembered_cannon",
		"text": "Brindle: Ancient ordnance, unregistered. I'll log you as a gift.",
	},
	{
		"id": "lore.dig_depths.intro.waking.pylon_engineer", "kind": "intro", "zone": "2-2",
		"subject": "waking", "pilot": "pylon_engineer",
		"text": "Waking: Fast fox. Your pylons were planted in my back.",
	},
	{
		"id": "lore.dig_depths.intro.waking.runner_gunner", "kind": "intro", "zone": "2-2",
		"subject": "waking", "pilot": "runner_gunner",
		"text": "Waking: Another mole digging in my dark. At least you aim.",
	},
	{
		"id": "lore.dig_depths.intro.waking.demolitions_caster", "kind": "intro", "zone": "2-2",
		"subject": "waking", "pilot": "demolitions_caster",
		"text": "Waking: Kest. I knocked back the whole time. You never knocked again.",
	},
	{
		"id": "lore.dig_depths.intro.waking.tarn", "kind": "intro", "zone": "2-2",
		"subject": "waking", "pilot": "tarn",
		"text": "Waking: Your machine growls at me, tiger. You only said sorry.",
	},
	{
		"id": "lore.dig_depths.intro.waking.tally", "kind": "intro", "zone": "2-2",
		"subject": "waking", "pilot": "tally",
		"text": "Waking: Itemize this, Tally. Floor. Floor. Ceiling.",
	},
	{
		"id": "lore.dig_depths.intro.waking.remembered_cannon", "kind": "intro", "zone": "2-2",
		"subject": "waking", "pilot": "remembered_cannon",
		"text": "Waking: I know your rings, old gun. You shook my sleep.",
	},
	{
		"id": "lore.highdraft_core.intro.mind.pylon_engineer", "kind": "intro", "zone": "3-2",
		"subject": "mind", "pilot": "pylon_engineer",
		"text": "Mind: My gun remembered you, fox. I've hummed you since the Spillway.",
	},
	{
		"id": "lore.highdraft_core.intro.mind.runner_gunner", "kind": "intro", "zone": "3-2",
		"subject": "mind", "pilot": "runner_gunner",
		"text": "Mind: Lift the visor, Rivet. I'd like to see who listened.",
	},
	{
		"id": "lore.highdraft_core.intro.mind.demolitions_caster", "kind": "intro", "zone": "3-2",
		"subject": "mind", "pilot": "demolitions_caster",
		"text": "Mind: Welcome home, Kest. I kept your sky. Commit to staying.",
	},
	{
		"id": "lore.highdraft_core.intro.mind.tarn", "kind": "intro", "zone": "3-2",
		"subject": "mind", "pilot": "tarn",
		"text": "Mind: Quiet tiger. Let the machine snarl. I only want the duet.",
	},
	{
		"id": "lore.highdraft_core.intro.mind.tally", "kind": "intro", "zone": "3-2",
		"subject": "mind", "pilot": "tally",
		"text": "Mind: Tally, enter one more line. Likes: you. Balance that.",
	},
	{
		"id": "lore.highdraft_core.intro.mind.remembered_cannon", "kind": "intro", "zone": "3-2",
		"subject": "mind", "pilot": "remembered_cannon",
		"text": "Mind: You were my gun. Now you play my song backwards.",
	},
]
