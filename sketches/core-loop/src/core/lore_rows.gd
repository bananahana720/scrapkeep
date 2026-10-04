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
]
