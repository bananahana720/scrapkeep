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

	# Placeholder: tone-pending 2-1.
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
		"text": "Crew notice: borrowed lights go back on the rack. Even the ones you found.",
	},
	{
		"id": "lore.dig_entry.note.7", "kind": "field_note", "zone": "2-1",
		"text": "Pump report: water clear. Sediment forms neat circles around every bolt.",
	},
	{
		"id": "lore.dig_entry.intro.warden", "kind": "intro", "zone": "2-1",
		"subject": "warden",
		"text": "Dig Warden. Lamps counted. Workers missing from the count.",
	},
	{
		"id": "lore.dig_entry.intro.waking", "kind": "intro", "zone": "2-1",
		"subject": "waking",
		"text": "Waking: Your knocking reached farther than you meant.",
	},
	# Placeholder: tone-pending 2-2.
	{
		"id": "lore.dig_depths.exchange.1", "kind": "exchange", "zone": "2-2",
		"exchange": "lore.dig_depths.exchange",
		"speaker": "Lift crew",
		"skippable": true,
		"text": "Lift came up empty. Counterweight was humming.",
	},
	{
		"id": "lore.dig_depths.exchange.2", "kind": "exchange", "zone": "2-2",
		"exchange": "lore.dig_depths.exchange",
		"speaker": "Moss",
		"skippable": true,
		"text": "Grease the bearings. Leave the humming alone.",
	},
	{
		"id": "lore.dig_depths.exchange.3", "kind": "exchange", "zone": "2-2",
		"exchange": "lore.dig_depths.exchange",
		"speaker": "Lift crew",
		"skippable": true,
		"text": "Already tried. It changed key.",
	},
	{
		"id": "lore.dig_depths.note.1", "kind": "field_note", "zone": "2-2",
		"text": "Lift docket: counterweight gained weight overnight. Nothing added to the cage.",
	},
	{
		"id": "lore.dig_depths.note.2", "kind": "field_note", "zone": "2-2",
		"text": "Chalk arrow: EXIT. A second hand has drawn it pointing down.",
	},
	{
		"id": "lore.dig_depths.note.3", "kind": "field_note", "zone": "2-2",
		"text": "Tool return: spanner warm after three shifts underground. Handle carries no fingerprints.",
	},
	{
		"id": "lore.dig_depths.note.4", "kind": "field_note", "zone": "2-2",
		"text": "Cable inspection: strands intact. Vibration persists with the motor disconnected.",
	},
	{
		"id": "lore.dig_depths.note.5", "kind": "field_note", "zone": "2-2",
		"text": "Crew list: every name checked. One checkmark continues through the paper.",
	},
	{
		"id": "lore.dig_depths.note.6", "kind": "field_note", "zone": "2-2",
		"text": "Repair note: replaced the bell. Old bell rings from the scrap bin.",
	},
	{
		"id": "lore.dig_depths.note.7", "kind": "field_note", "zone": "2-2",
		"text": "Last shift: heard breathing beyond the bulkhead. Left the lamp facing it.",
	},
	{
		"id": "lore.dig_depths.intro.warden", "kind": "intro", "zone": "2-2",
		"subject": "warden",
		"text": "Depth Warden. Lift locked. The counterweight is listening.",
	},
	{
		"id": "lore.dig_depths.intro.waking", "kind": "intro", "zone": "2-2",
		"subject": "waking",
		"text": "Waking: You brought daylight all the way down.",
	},
	# Placeholder: tone-pending 3-1.
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
		"text": "Tool locker: spoon filed as wrench. Wrench filed as weather loss.",
	},
	{
		"id": "lore.highdraft_deck.note.7", "kind": "field_note", "zone": "3-1",
		"text": "Lookout scrap: island lights blink in order. Count starts before the first light.",
	},
	{
		"id": "lore.highdraft_deck.intro.warden", "kind": "intro", "zone": "3-1",
		"subject": "warden",
		"text": "Highdraft Warden. Deck secured. The sky has other instructions.",
	},
	{
		"id": "lore.highdraft_deck.intro.mind", "kind": "intro", "zone": "3-1",
		"subject": "mind",
		"text": "Mind: Your course was recorded before you chose it.",
	},
	# Placeholder: tone-pending 3-2.
	{
		"id": "lore.highdraft_core.exchange.1", "kind": "exchange", "zone": "3-2",
		"exchange": "lore.highdraft_core.exchange",
		"speaker": "Moss",
		"skippable": true,
		"text": "Your hands are shaking. Give me the cable.",
	},
	{
		"id": "lore.highdraft_core.exchange.2", "kind": "exchange", "zone": "3-2",
		"exchange": "lore.highdraft_core.exchange",
		"speaker": "Signal crew",
		"skippable": true,
		"text": "It keeps sending our own reply ahead of us.",
	},
	{
		"id": "lore.highdraft_core.exchange.3", "kind": "exchange", "zone": "3-2",
		"exchange": "lore.highdraft_core.exchange",
		"speaker": "Moss",
		"skippable": true,
		"text": "Then let it wait. We eat first.",
	},
	{
		"id": "lore.highdraft_core.note.1", "kind": "field_note", "zone": "3-2",
		"text": "Signal book: reply received before request. Operator refused to sign both columns.",
	},
	{
		"id": "lore.highdraft_core.note.2", "kind": "field_note", "zone": "3-2",
		"text": "Bridge repair: compass housing cracked. Needle points toward the person holding it.",
	},
	{
		"id": "lore.highdraft_core.note.3", "kind": "field_note", "zone": "3-2",
		"text": "Safety notice: count your crew aloud. Leave space for each answer.",
	},
	{
		"id": "lore.highdraft_core.note.4", "kind": "field_note", "zone": "3-2",
		"text": "Line test: disconnected cable still carries a voice. Voice asks for the cable.",
	},
	{
		"id": "lore.highdraft_core.note.5", "kind": "field_note", "zone": "3-2",
		"text": "Chart margin: destination crossed out. Underneath, a drawing of this very desk.",
	},
	{
		"id": "lore.highdraft_core.note.6", "kind": "field_note", "zone": "3-2",
		"text": "Galley tally: one place left empty. Everyone remembers setting it.",
	},
	{
		"id": "lore.highdraft_core.note.7", "kind": "field_note", "zone": "3-2",
		"text": "Final watch: lights ahead match our windows. Nobody aboard is waving.",
	},
	{
		"id": "lore.highdraft_core.intro.warden", "kind": "intro", "zone": "3-2",
		"subject": "warden",
		"text": "Signal Warden. Channel closed. Your reply is already queued.",
	},
	{
		"id": "lore.highdraft_core.intro.mind", "kind": "intro", "zone": "3-2",
		"subject": "mind",
		"text": "Mind: I kept a place for everything you lost.",
	},
]
