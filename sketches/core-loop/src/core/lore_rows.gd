extends RefCounted

const EXCHANGE_LINE_WORD_CAP := 14
const FIELD_NOTE_WORD_CAP := 40
const INTRO_LINE_WORD_CAP := 12
const CALL_LINE_WORD_CAP := 12
# A call is a reaction: one that cannot come up within CALL_FRESH_S of its cause is dropped, not
# played late, and one caused within CALL_GAP_S of the last call is dropped too.
const CALL_FRESH_S := 4.0
const CALL_GAP_S := 20.0
const CALL_LOW_HULL := 0.3
# Who may call, by id (the voice and the card read the id), and the name the card shows.
const SPEAKERS := {
	"moss": "Moss", "pump_crew": "Pump crew", "flume_crew": "Flume crew", "signal_crew": "Signal crew",
	"brindle": "Brindle", "mind": "The Foreman",
	"sable": "Sable", "rivet": "Rivet", "kest": "Kest", "tarn": "Tarn", "tally": "Tally", "cannon": "Cannon",
}

# The site crew whose radio a zone's unsigned lines come over (a Warden's intro is theirs).
const SITE_CREWS := {"1-1": "pump_crew", "1-2": "flume_crew"}

# Call-ins (design-v3/STORY-MAP.md, "Call-ins"): one line from a named caller, said because of
# what the player just did. Each plays once a run; rows are read in order and the first that
# passes is the call. Row keys:
#   on        the GameEvents signal that causes it. A Warden's fall is beacon_unsealed (the gates
#             open on it); stage_cleared comes later, in the launch, under the next stage's hello
#   arg       [index, value]: only when the signal's argument at index equals value
#   at_least  [index, value]: only when that argument is value or more
#   when      "low_hull": only with the hull under CALL_LOW_HULL, when caused and when said
#   world     the world it belongs to
#   speaker   a SPEAKERS id. A pilot's row names their class under `pilot`: it is said only by a
#             freed pilot who is not the one flying, and one pilot's line on a cause is the run's
#   text      the line, or a list of ways to say it: the run seed picks one (call_text), so the
#             same seed hears the same words and run five does not sound like run one
const CALLS := [
	{"id": "call.spillway.camp", "on": "activity_done", "arg": [0, "enemy_camp"], "world": 1, "speaker": "pump_crew",
		"text": ["Camp's quiet. We logged it quiet last week too.", "Camp's down. We'll log it down. In pencil, in case.", "Camp's clear. Their brew's still hot. We'll mind it."]},
	{"id": "call.spillway.relay", "on": "activity_done", "arg": [0, "hold_the_relay"], "world": 1, "speaker": "signal_crew",
		"text": ["Relay's back. It never stopped sending. Nobody says to whom.", "Relay's up. Signal's clean. Cleaner than we ever got it.", "Relay's ours again. Still sending somewhere. We're listening."]},
	{"id": "call.spillway.surge", "on": "activity_done", "arg": [0, "surge_run"], "world": 1, "speaker": "flume_crew",
		"text": ["Sluice shut behind you. We never opened it.", "You beat the surge. The sluice shut itself. Polite of it.", "Surge spent. We'll mark the water line. Lower, for once."]},
	{"id": "call.spillway.gamble", "on": "trade_taken", "arg": [0, "trade_risk"], "world": 1, "speaker": "moss",
		"text": ["Keeper's gamble, was it? I packed for either way.", "A gamble. I packed bandages. And a cake.", "Took the gamble, then. My grandmother did too. Mostly won."]},
	{"id": "call.spillway.kindness", "on": "trade_taken", "arg": [0, "trade_safe"], "world": 1, "speaker": "mind",
		"text": ["A sensible choice. It has been added to your schedule.", "Thank you for choosing certainty. Your feedback has been pre-recorded.", "Wonderful. Your judgement has been freed up for other priorities."]},
	{"id": "call.spillway.dam_warden", "on": "beacon_unsealed", "arg": [0, 1], "world": 1, "speaker": "pump_crew",
		"text": ["Gates open on our count now. We count on fingers.", "Warden's down. Gates answer to us again. Mostly.", "That's the Warden off shift. We'll take the gates from here."]},
	{"id": "call.spillway.evolved", "on": "evolution_fired", "world": 1, "speaker": "moss",
		"text": ["I didn't pack it like that. Keep it like that.", "That's not how it came out of the box. Better.", "Never seen it bolt up that way. I'm writing that down."]},
	{"id": "call.spillway.heft", "on": "heft_class_changed", "world": 1, "speaker": "moss",
		"text": ["You're riding low. Good ballast, that scrap. Bad brakes.", "Heavy now. The ground will notice before you do.", "Sitting low. Hits harder, stops later. Plan the corners."]},
	{"id": "call.spillway.low_hull", "on": "player_hit", "when": "low_hull", "world": 1, "speaker": "moss",
		"text": ["That spare seal I packed. Left pocket. About now.", "Hull's thin. Spare plate's in the boot. I checked twice.", "Spare patch, under the seat. I tape it there every morning."]},
	{"id": "call.spillway.drop.sable", "on": "drop_landed", "at_least": [0, 3], "world": 1, "speaker": "sable", "pilot": "pylon_engineer",
		"text": ["Nice drop. I'd have gone from higher.", "Ooh. Next time, from the top of the dam."]},
	{"id": "call.spillway.drop.rivet", "on": "drop_landed", "at_least": [0, 3], "world": 1, "speaker": "rivet", "pilot": "runner_gunner",
		"text": ["Nice drop. I'd be at the next one already.", "Heard that from here. Didn't see it. Never do."]},
	{"id": "call.spillway.drop.kest", "on": "drop_landed", "at_least": [0, 3], "world": 1, "speaker": "kest", "pilot": "demolitions_caster",
		"text": ["You dropped early. Worked anyway. Annoying.", "I'd still be measuring that one. You just went."]},
	{"id": "call.spillway.drop.tarn", "on": "drop_landed", "at_least": [0, 3], "world": 1, "speaker": "tarn", "pilot": "tarn",
		"text": ["All of them at once. I'd have said sorry first.", "That was a lot of them. Gently, next time. Maybe."]},
	{"id": "call.spillway.drop.tally", "on": "drop_landed", "at_least": [0, 3], "world": 1, "speaker": "tally", "pilot": "tally",
		"text": ["One drop, several down. Logged as several. Honest work.", "Entered as one drop, many results. The ledger likes you."]},
	{"id": "call.spillway.drop.cannon", "on": "drop_landed", "at_least": [0, 3], "world": 1, "speaker": "cannon", "pilot": "remembered_cannon",
		"text": ["Efficient. Sorry. Old habit.", "Clean grouping. Forget I said that."]},
]


# Whether a call row answers this signal with these arguments.
static func call_matches(row: Dictionary, event: String, args: Array) -> bool:
	if row["on"] != event:
		return false
	for key in ["arg", "at_least"]:
		if not row.has(key):
			continue
		var index := int(row[key][0])
		if args.size() <= index:
			return false
		if key == "arg" and args[index] != row[key][1]:
			return false
		if key == "at_least" and float(args[index]) < float(row[key][1]):
			return false
	return true


# Who says a row's line, as a SPEAKERS id: an exchange's speaker, the boss an intro quotes
# ("Brindle: ..."), or the zone's site crew for a Warden's intro. "" when the line has no voice.
static func voice_of(row: Dictionary) -> String:
	var named := String(row.get("speaker", String(row.get("text", "")).get_slice(": ", 0)))
	var id = SPEAKERS.find_key(named)
	if id != null:
		return id
	return String(SITE_CREWS.get(row.get("zone", ""), "")) if row.get("subject", "") == "warden" else ""


# The words of a row's line as said aloud: the text without the name it opens on.
static func spoken(row: Dictionary) -> String:
	var text := String(row.get("text", ""))
	var named := text.get_slice(": ", 0)
	return text.trim_prefix(named + ": ") if SPEAKERS.find_key(named) != null else text


# The words a call says this run: its one line, or the one its list gives this seed. The pick is
# salted by the row's id, so two rows on one seed do not all take the same place in their lists.
static func call_text(row: Dictionary, run_seed: int) -> String:
	var text = row.get("text", "")
	if not text is Array:
		return String(text)
	var options: Array = text
	return "" if options.is_empty() else String(options[absi(hash([run_seed, String(row.get("id", ""))])) % options.size()])


# The signals any call listens to, once each.
static func call_signals() -> Array:
	var out: Array = []
	for row in CALLS:
		if not out.has(row["on"]):
			out.append(row["on"])
	return out


# Camp quips (W46-14, living camp): a freed pilot stands round Moss's fire pit and says one line
# as the ball rolls past, on the caller plate and silent for now. speaker is the SPEAKERS id a
# voice reads (the camp hands it out with the words), pilot the class that stands there. Each
# pilot keeps their one fixed opinion; dry and workplace, never cruel. text is a list: the camp's
# visit count picks one (camp_quip_text), so the next walk sounds different.
const CAMP_QUIPS := [
	{"id": "camp.quip.sable", "speaker": "sable", "pilot": "pylon_engineer",
		"text": ["Nice roll. I'd have launched off the lamp post.", "Gate's slow. I go over it. Don't tell Moss.", "The fence is a perfectly good ramp, you know."]},
	{"id": "camp.quip.rivet", "speaker": "rivet", "pilot": "runner_gunner",
		"text": ["Heard you roll past. Lovely. Which way's the fire?", "Felt that through the bench. Good shift coming.", "I'm already at the gate. Or a bench. Something wooden."]},
	{"id": "camp.quip.kest", "speaker": "kest", "pilot": "demolitions_caster",
		"text": ["Measured your line twice. You'll be fine. Probably.", "Still deciding about the tea. Don't wait for me.", "You went straight past. I'd have circled first. Twice."]},
	{"id": "camp.quip.tarn", "speaker": "tarn", "pilot": "tarn",
		"text": ["Mind the bench. It's had a long day.", "Say sorry to the gate on your way out.", "Easy. The fire's only just got comfortable."]},
	{"id": "camp.quip.tally", "speaker": "tally", "pilot": "tally",
		"text": ["Rolled past at speed. Logged as present. Well done.", "One lap of camp. No charge. I checked.", "Ledger says you owe Moss a biscuit. Interest waived."]},
	{"id": "camp.quip.cannon", "speaker": "cannon", "pilot": "remembered_cannon",
		"text": ["Good roll. Very efficient. Sorry. Old habit.", "I used to count shots. Now I count biscuits.", "Nice line. I'd have scheduled it. I don't do that now."]},
]


# The quip row of the pilot who stands for this class, {} when the class has none.
static func camp_quip(class_id: String) -> Dictionary:
	for row in CAMP_QUIPS:
		if row["pilot"] == class_id:
			return row
	return {}


# The words a quip says on this visit: visits step through the list from a place the row's id
# picks, so two pilots on one visit do not say their first line together.
static func camp_quip_text(row: Dictionary, visit: int) -> String:
	var lines: Array = row.get("text", [])
	if lines.is_empty():
		return ""
	return String(lines[posmod(absi(hash(String(row.get("id", "")))) + visit, lines.size())])

# One row per readable line. Exchange lines share an exchange id and follow array order.
# Zone ids name the alpha route, independently of the sketch's current stage slots.
# Park era (LORE-REPLACE, decisions.tsv): park notes lead each zone; approved sample
# lines keep their slots; the old cableway set and 3-2 island notes are gone.
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
		"id": "lore.park_dam.note.gate_log", "kind": "field_note", "zone": "1-1",
		"text": "Gate log: spillway gates opened four times before breakfast. Wheel chained. Chain still warm.",
	},
	{
		"id": "lore.park_dam.note.plumb", "kind": "field_note", "zone": "1-1",
		"text": "Survey deck: plumb bob hangs toward the dam. Wind from the south. Bob reported to the foreman.",
	},
	{
		"id": "lore.park_dam.note.slot", "kind": "field_note", "zone": "1-1",
		"text": "Slot canyon tag: flood line painted at the narrows. Line repainted higher each season. The rim has not moved.",
	},
	{
		"id": "lore.park_dam.note.eye", "kind": "field_note", "zone": "1-1",
		"text": "Eye inspection: wind through the fin whistles one note. Crew tuned the compressor to match. Compressor now refuses other notes.",
	},
	{
		"id": "lore.park_dam.note.incline", "kind": "field_note", "zone": "1-1",
		"text": "Incline ticket: brake shoes replaced. Bucket went down anyway. Bucket came back up full of river.",
	},
	{
		"id": "lore.park_dam.note.apron", "kind": "field_note", "zone": "1-1",
		"text": "Toe apron stencil: STAND CLEAR OF THE FACE. Chalk tally underneath counts the balls that didn't.",
	},
	{
		"id": "lore.park_dam.note.fleet", "kind": "field_note", "zone": "1-1",
		"text": "Fleet docket: east bench cleared for landing. Dam listed as surplus concrete. Relic listed twice.",
	},
	{
		"id": "lore.world_spillway.note.water_board", "kind": "field_note", "zone": "1-1",
		"text": "Water board ledger: dam fills the reservoir, reservoir feeds the flume, flume feeds the head house. Head house returns more than it was sent.",
	},
	{
		"id": "lore.world_spillway.note.roster", "kind": "field_note", "zone": "1-1",
		"text": "Crew roster, Spillway: dam shift, flume shift, one keeper on the ball. Keeper column left blank. Moss fills it in after supper.",
	},
	{
		"id": "lore.world_spillway.note.notice", "kind": "field_note", "zone": "1-1",
		"text": "Fleet notice, posted at both ends of the river: ALL WATER IS NOW INVENTORY. Below it, in chalk: Tell the river.",
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
		"id": "lore.spillway.note.shift_board", "kind": "field_note", "zone": "1-1",
		"text": "Shift board, pump house: FOREMAN column reads MIND. HANDS column wiped clean. Chalk dust under it is fresh every morning.",
	},
	{
		"id": "lore.spillway.note.gloves", "kind": "field_note", "zone": "1-1",
		"text": "Locker row: one pair of work gloves set out per shift. Nobody on the roster draws them. A fresh pair is laid out anyway.",
	},
	{
		"id": "lore.park_dam.note.crane", "kind": "field_note", "zone": "1-1",
		"text": "Crane log: cab empty, keys on the hook. Jib swung once during the noon tune. Lift signed for in a hand nobody on shift writes.",
	},
	{
		"id": "lore.park_dam.intro.warden", "kind": "intro", "zone": "1-1", "subject": "warden",
		"text": "Warden on the dam. Gates open on its count, not ours.",
	},
	{
		"id": "lore.spillway.intro.brindle", "kind": "intro", "zone": "1-1", "subject": "brindle",
		"text": "Brindle: Your repair reserve is now Fleet inventory. Thank you.",
	},

	{
		"id": "lore.park_flume.crew.warm", "kind": "exchange", "zone": "1-2",
		"exchange": "lore.park_flume.exchange", "speaker": "Flume crew", "skippable": true,
		"text": "Flume's running warm today. Fish came down the trestles cooked.",
	},
	{
		"id": "lore.park_flume.moss.flask", "kind": "exchange", "zone": "1-2",
		"exchange": "lore.park_flume.exchange", "speaker": "Moss", "skippable": true,
		"text": "Then don't drink from it. I packed you a flask.",
	},
	{
		"id": "lore.park_flume.crew.weir", "kind": "exchange", "zone": "1-2",
		"exchange": "lore.park_flume.exchange", "speaker": "Flume crew", "skippable": true,
		"text": "Flask's warm too. You filled it at the weir.",
	},
	{
		"id": "lore.park_flume.note.weir", "kind": "field_note", "zone": "1-2",
		"text": "Weir gauge: reservoir steady. Flume carrying more than the weir lets through. Difference logged as rain. No rain.",
	},
	{
		"id": "lore.park_flume.note.bents", "kind": "field_note", "zone": "1-2",
		"text": "Trestle crew: bents numbered downhill. Count comes out one higher walking back up.",
	},
	{
		"id": "lore.park_flume.note.siphon", "kind": "field_note", "zone": "1-2",
		"text": "Siphon card: water goes under the hollow and comes up warmer. Pipe is cold the whole way.",
	},
	{
		"id": "lore.park_flume.note.milepost", "kind": "field_note", "zone": "1-2",
		"text": "Rim road milepost: someone painted the bend's depth on it. Crossed out. Painted deeper.",
	},
	{
		"id": "lore.park_flume.note.boom", "kind": "field_note", "zone": "1-2",
		"text": "Crane boom log: boom 3 locked for the night. Found swung toward the tower by morning. Lock still on.",
	},
	{
		"id": "lore.park_flume.note.drum", "kind": "field_note", "zone": "1-2",
		"text": "Head house log: flume poured onto the drum floor all shift. Floor dry by supper. Drains never fitted.",
	},
	{
		"id": "lore.park_flume.note.fleet", "kind": "field_note", "zone": "1-2",
		"text": "Fleet tally: flume flow, eleven hundred buckets an hour. Rounded to twelve. Crew asked where the hundred went.",
	},
	{
		"id": "lore.park_flume.note.wasteway", "kind": "field_note", "zone": "1-2",
		"text": "Wasteway log: weir dumped at first light. Chute ran full for a minute. Floor dry when the crew arrived. Gauge still reading high.",
	},
	{
		"id": "lore.park_flume.note.surge", "kind": "field_note", "zone": "1-2",
		"text": "Surge tower card: green light on top since the relic came in. Bulb removed for inspection. Light stayed on. Bulb filed under spares.",
	},
	{
		"id": "lore.park_flume.note.penstocks", "kind": "field_note", "zone": "1-2",
		"text": "Penstock inspection: four pipes down the bluff to the gorge. Flow measured at the bottom. Water arrives before the gate is opened.",
	},
	{
		"id": "lore.park_flume.note.catwalk", "kind": "field_note", "zone": "1-2",
		"text": "Catwalk ticket: hollow lift raised to the trestle walk. Lift stops a hand short of the top every trip. Lift was built level.",
	},
	{
		"id": "lore.park_flume.note.squall", "kind": "field_note", "zone": "1-2",
		"text": "Weather card: dust squall from the south at mid-morning. Flume carried sand the length of the run. Head house received it sorted by size.",
	},
	{
		"id": "lore.park_flume.note.zip", "kind": "field_note", "zone": "1-2",
		"text": "Zip line tag: mesa line tested with a sandbag. Bag arrived at the butte gap. Second bag arrived first.",
	},
	{
		"id": "lore.park_flume.note.culvert", "kind": "field_note", "zone": "1-2",
		"text": "Culvert notice: the wall beside the wasteway is not a door. Wall disagrees at speed. Repairs billed to the wall.",
	},
	{
		"id": "lore.park_flume.note.shadows", "kind": "field_note", "zone": "1-2",
		"text": "Morning card: trestle shadows fall west across the fields. Shadow count matches the bents until noon. After noon, one extra, standing still.",
	},
	{
		"id": "lore.park_flume.note.gap", "kind": "field_note", "zone": "1-2",
		"text": "Butte gap survey: flume clears the gap by a hand's width each side. Clearance measured again in wind. Buttes leaned in to look.",
	},
	{
		"id": "lore.park_flume.note.bend", "kind": "field_note", "zone": "1-2",
		"text": "Bend overlook: crew lunch taken on the rim. Echo from the river below repeated the grace, then asked for seconds.",
	},
	{
		"id": "lore.park_flume.note.gorge", "kind": "field_note", "zone": "1-2",
		"text": "Gorge rope tally: ninety-five metres paid down the bluff to the river. Rope came back wet to the top knot. River is lower than that.",
	},
	{
		"id": "lore.park_flume.note.annex", "kind": "field_note", "zone": "1-2",
		"text": "Annex shift: heat exchanger run cold all night to keep the relic calm. Coffee left on it came back boiling.",
	},
	{
		"id": "lore.park_flume.note.forecourt", "kind": "field_note", "zone": "1-2",
		"text": "Forecourt notice: heavy plant parks clear of the drum doors. The heavy plant parked itself. It is still there.",
	},
	{
		"id": "lore.park_flume.note.drones", "kind": "field_note", "zone": "1-2",
		"text": "Bent inspection: winch drones roosting under trestles 12 to 19. Crew asked them to move. They moved down one bent and kept the count.",
	},
	{
		"id": "lore.park_flume.note.south_bench", "kind": "field_note", "zone": "1-2",
		"text": "Fleet notice, south bench: landing pads painted overnight. Bench was rock yesterday. Today it is listed as a Fleet asset, rock included.",
	},
	{
		"id": "lore.park_flume.intro.warden", "kind": "intro", "zone": "1-2", "subject": "warden",
		"text": "Warden in the head house. Flume boiling. Flow still logged as normal.",
	},
	{
		"id": "lore.park_flume.intro.brindle", "kind": "intro", "zone": "1-2", "subject": "brindle",
		"text": "Brindle: A boiling flume. Twelve hundred tons of steam. Thank you.",
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
		"id": "lore.park_pit.note.haul", "kind": "field_note", "zone": "2-1",
		"text": "Haul road log: last truck down at shift end. Engine heard climbing all night. No truck at the top.",
	},
	{
		"id": "lore.park_pit.note.rope", "kind": "field_note", "zone": "2-1",
		"text": "Hoist ticket: rope paid out to the collar. Drum kept turning. Rope length now exceeds shaft.",
	},
	{
		"id": "lore.park_pit.note.sheave", "kind": "field_note", "zone": "2-1",
		"text": "Sheave inspection: both wheels true. One turns when the other stops. Rope not threaded yet.",
	},
	{
		"id": "lore.park_pit.note.devil", "kind": "field_note", "zone": "2-1",
		"text": "Dust devil report: spun up on bench 2, crossed the floor, climbed the haul road at posted speed.",
	},
	{
		"id": "lore.park_pit.note.seam", "kind": "field_note", "zone": "2-1",
		"text": "Face survey: turquoise seam on the north wall moved a bench lower overnight. Survey pins stayed put.",
	},
	{
		"id": "lore.park_pit.note.belt", "kind": "field_note", "zone": "2-1",
		"text": "Conveyor sign-out: belt stopped for lunch. Lunch tins arrived at the hoist house anyway.",
	},
	{
		"id": "lore.park_pit.note.fleet", "kind": "field_note", "zone": "2-1",
		"text": "Fleet docket: drill barge assigned to bench 3. Pit listed as a hole, pre-dug. Crew credit withheld.",
	},
	{
		"id": "lore.world_dig.note.mine_plan", "kind": "field_note", "zone": "2-1",
		"text": "Mine plan: open pit above, deep works below, one buried lens between. Plan stamped APPROVED by a hand older than the stamp.",
	},
	{
		"id": "lore.world_dig.note.assay", "kind": "field_note", "zone": "2-1",
		"text": "Assay office: copper from the pit, copper from the tubes. Same seam. Seam runs toward the sinkhole and does not stop.",
	},
	{
		"id": "lore.world_dig.note.headcount", "kind": "field_note", "zone": "2-1",
		"text": "Shift change rule: count heads at the collar and again at the gallery ring. Write both numbers down. Do not compare them.",
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
		"id": "lore.dig_entry.note.hoist_bell", "kind": "field_note", "zone": "2-1",
		"text": "Hoist bell log: rung for crew up, rung for crew down. Nobody rode. Bell rope worn smooth at a height no crew could reach.",
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
		"id": "lore.park_sinkhole.moss.skylights", "kind": "exchange", "zone": "2-2",
		"exchange": "lore.park_sinkhole.exchange", "speaker": "Moss", "skippable": true,
		"text": "Long dark ride today. I'll hang a lamp at every skylight.",
	},
	{
		"id": "lore.park_sinkhole.crew.caisson", "kind": "exchange", "zone": "2-2",
		"exchange": "lore.park_sinkhole.exchange", "speaker": "Pump crew", "skippable": true,
		"text": "Pumped the caisson dry at shift change. It's filling from the bottom.",
	},
	{
		"id": "lore.park_sinkhole.moss.ring", "kind": "exchange", "zone": "2-2",
		"exchange": "lore.park_sinkhole.exchange", "speaker": "Moss", "skippable": true,
		"text": "Then get your boots up on the gallery ring.",
	},
	{
		"id": "lore.park_sinkhole.note.skylight", "kind": "field_note", "zone": "2-2",
		"text": "Skylight log: noon light through skylight three. Lamp swarm under it went dark. Then lit, one at a time.",
	},
	{
		"id": "lore.park_sinkhole.note.echo", "kind": "field_note", "zone": "2-2",
		"text": "Great room ticket: echo test passed. Shout returned in the foreman's voice. Foreman was outside.",
	},
	{
		"id": "lore.park_sinkhole.note.ring", "kind": "field_note", "zone": "2-2",
		"text": "Gallery ring card: hundred-metre shelf checked. Water mark on the timbers sits above the shelf. Pool has never reached it. Yet.",
	},
	{
		"id": "lore.park_sinkhole.note.mist", "kind": "field_note", "zone": "2-2",
		"text": "Mist report: cave mist settles in rings above the pool. Ring count matches the pump strokes. Pump is off.",
	},
	{
		"id": "lore.park_sinkhole.note.monsoon", "kind": "field_note", "zone": "2-2",
		"text": "Monsoon card: rain poured into the sinkhole all afternoon. Pool level unchanged. Gauge noted it was busy.",
	},
	{
		"id": "lore.park_sinkhole.note.rack", "kind": "field_note", "zone": "2-2",
		"text": "Lamp rack: every lamp hung back facing the sinkhole. The rack faces the door.",
	},
	{
		"id": "lore.park_sinkhole.note.fleet", "kind": "field_note", "zone": "2-2",
		"text": "Fleet docket: drill barge to bore the east plateau. Hole requested for the hole below. Request approved in duplicate.",
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
		"id": "lore.park_sinkhole.intro.warden", "kind": "intro", "zone": "2-2", "subject": "warden",
		"text": "Brood Warden. The pool rises a step each time it breaks.",
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
		"id": "lore.park_islands.note.lookout", "kind": "field_note", "zone": "3-1",
		"text": "Fire lookout log: isle's waterfall seen from the tower. Mist never reaches the net. Net is wet anyway.",
	},
	{
		"id": "lore.park_islands.note.balloon", "kind": "field_note", "zone": "3-1",
		"text": "Balloon lift ticket: envelope patched again. Patch came back sewn in a stitch nobody here knows.",
	},
	{
		"id": "lore.park_islands.note.tram", "kind": "field_note", "zone": "3-1",
		"text": "Tram ticket: cable sags toward the isle at golden hour. Straightens after dark. Towers not adjusted.",
	},
	{
		"id": "lore.park_islands.note.thermal", "kind": "field_note", "zone": "3-1",
		"text": "Thermal card: column over the Anvil lifts at golden hour only. Kest's roost crew calls it the evening lift. Logged as weather.",
	},
	{
		"id": "lore.park_islands.note.tilt", "kind": "field_note", "zone": "3-1",
		"text": "Pendulum note: isle tipped ten degrees toward the lookout. Then back. Lookout had only waved.",
	},
	{
		"id": "lore.park_islands.note.fleet", "kind": "field_note", "zone": "3-1",
		"text": "Mooring tag: balloon reclassified as cargo. Cargo reclassified as ballast. Ballast keeps trying to leave.",
	},
	{
		"id": "lore.world_highdraft.note.roost_chart", "kind": "field_note", "zone": "3-1",
		"text": "Roost chart, Highdraft: islands at golden hour, the Crown at dusk. Every bearing on the chart ends at the Crown, including north.",
	},
	{
		"id": "lore.world_highdraft.note.handbook", "kind": "field_note", "zone": "3-1",
		"text": "Net crew handbook: strung under every gap from the Lookout to the Crown. Rule one, check the knots. Rule two, check who checked them.",
	},
	{
		"id": "lore.world_highdraft.note.wind", "kind": "field_note", "zone": "3-1",
		"text": "Fleet weather report: Highdraft wind requisitioned for fleet sails. Wind declined. Report filed under weather.",
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
		"id": "lore.highdraft_deck.note.work_order", "kind": "field_note", "zone": "3-1",
		"text": "Work order, issued by MIND: hold the island up, keep supper warm, count the crew. Signed in the HANDS box. Ink still wet.",
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
		"id": "lore.park_crown.moss.storm", "kind": "exchange", "zone": "3-2",
		"exchange": "lore.park_crown.exchange", "speaker": "Moss", "skippable": true,
		"text": "Storm's building over the Crown. Last crossing. I'll wait at the gates.",
	},
	{
		"id": "lore.park_crown.crew.beat", "kind": "exchange", "zone": "3-2",
		"exchange": "lore.park_crown.exchange", "speaker": "Signal crew", "skippable": true,
		"text": "Lightning's keeping time. Struck the masts on the beat all evening.",
	},
	{
		"id": "lore.park_crown.moss.offbeat", "kind": "exchange", "zone": "3-2",
		"exchange": "lore.park_crown.exchange", "speaker": "Moss", "skippable": true,
		"text": "Then roll on the off-beat. Supper's after.",
	},
	{
		"id": "lore.park_crown.note.watch", "kind": "field_note", "zone": "3-2",
		"text": "Watch log: storm cell over the Crown since noon. Wind from every side. Cloud has not moved.",
	},
	{
		"id": "lore.park_crown.note.bajada", "kind": "field_note", "zone": "3-2",
		"text": "Bajada card: a hundred washes, one fan. Every wash runs toward the Crown, including the uphill ones.",
	},
	{
		"id": "lore.park_crown.note.meander", "kind": "field_note", "zone": "3-2",
		"text": "Meander card: flash flood filled the gooseneck in minutes. Drained in hours. Left one ball track, going upstream.",
	},
	{
		"id": "lore.park_crown.note.needles", "kind": "field_note", "zone": "3-2",
		"text": "Needle survey: forty needles counted at dusk. Recount by lightning: forty-one. The new one is taller.",
	},
	{
		"id": "lore.park_crown.note.perches", "kind": "field_note", "zone": "3-2",
		"text": "Perch inspection: three spire tops, three palm-wide dishes. Two dry after rain. One warm.",
	},
	{
		"id": "lore.park_crown.note.gauntlet", "kind": "field_note", "zone": "3-2",
		"text": "Gauntlet net mends: every tear stitched from the Crown side. No crew posted on the Crown side.",
	},
	{
		"id": "lore.park_crown.note.fleet", "kind": "field_note", "zone": "3-2",
		"text": "Collector tag: storm delivered twelve strikes. Fleet billed for eleven. The Admiral rounded up.",
	},
	{
		"id": "lore.park_crown.note.hoodoos", "kind": "field_note", "zone": "3-2",
		"text": "Hoodoo count: caps checked after the wind. All present. One cap now faces the other way. Stone underneath has not turned.",
	},
	{
		"id": "lore.park_crown.note.turnstone", "kind": "field_note", "zone": "3-2",
		"text": "Turnstone watch: rock balanced on its point all night. Crew balanced a cup beside it. Cup fell. Rock logged as steady, cup as weather.",
	},
	{
		"id": "lore.park_crown.note.masts", "kind": "field_note", "zone": "3-2",
		"text": "Signal mast log: wire strung mast to mast toward the Crown. Message sent down the wire at dusk. Reply came back up it before dark.",
	},
	{
		"id": "lore.park_crown.note.updraft", "kind": "field_note", "zone": "3-2",
		"text": "Updraft card: column at the Crown's foot tested with smoke. Smoke rose straight, stopped level with the perch tops, then waited.",
	},
	{
		"id": "lore.park_crown.note.cloudburst", "kind": "field_note", "zone": "3-2",
		"text": "Cloudburst report: rain on the Watch Butte, rain on the bajada, none in the bowl. Bowl floor wet by morning. Gauge empty.",
	},
	{
		"id": "lore.park_crown.note.cannon", "kind": "field_note", "zone": "3-2",
		"text": "Shelf cannon docket: fired toward the bowl for range. Shot landed one ball's width short. Every shot since lands in the same mark.",
	},
	{
		"id": "lore.park_crown.note.kite", "kind": "field_note", "zone": "3-2",
		"text": "Mooring crew log: storm kite up off the Signal Butte. Lightning took the kite line instead of the masts. Line logged as a mast.",
	},
	{
		"id": "lore.park_crown.note.kite_strike", "kind": "field_note", "zone": "3-2",
		"text": "Strike card, Signal Butte top: lightning every thirty seconds, on the mark. Crew set the kettle by it. Kettle never late.",
	},
	{
		"id": "lore.park_crown.note.deck_lease", "kind": "field_note", "zone": "3-2",
		"text": "Mooring deck lease: weavers lend the deck to the Fleet for one storm. Lease renewed every storm. Nobody has seen a dry day.",
	},
	{
		"id": "lore.park_crown.note.winch", "kind": "field_note", "zone": "3-2",
		"text": "Winch post tally: six posts on the west butte, hooks facing the Crown. Crew turned them round at dusk. By dawn, facing the Crown.",
	},
	{
		"id": "lore.park_crown.note.weaver_knots", "kind": "field_note", "zone": "3-2",
		"text": "Weaver rule card: tie every knot twice, once for the line and once for whoever rides it. A third knot turns up on every post. Nobody ties three.",
	},
	{
		"id": "lore.park_crown.note.hammock", "kind": "field_note", "zone": "3-2",
		"text": "Hammock check: needle hammock slack at dusk, taut after the first strike. Weavers say the storm sits in it. They leave it a blanket.",
	},
	{
		"id": "lore.park_crown.note.lips", "kind": "field_note", "zone": "3-2",
		"text": "Gust lip survey: weavers cut the lips where the wind already jumped. Wind now jumps a hand early, to be helpful.",
	},
	{
		"id": "lore.park_crown.note.trade", "kind": "field_note", "zone": "3-2",
		"text": "Trade ledger, Gauntlet shelf: one Fleet winch for one weaver net. Winch returned oiled. Net returned with a Fleet number stencilled on every knot.",
	},
	{
		"id": "lore.highdraft_core.note.5", "kind": "field_note", "zone": "3-2",
		"text": "West cable inspection: knots hold. Voice in the line asks which knot belongs to which worker.",
	},
	{
		"id": "lore.park_crown.note.glove_numbers", "kind": "field_note", "zone": "3-2",
		"text": "Crown watch: four fingers of the big glove stencilled 01 to 04, numbers off the old roster. Thumb reads FOREMAN. All five still clock in.",
	},
	{
		"id": "lore.park_crown.intro.warden", "kind": "intro", "zone": "3-2", "subject": "warden",
		"text": "Crown Warden. One hand, three perches. It keeps the count.",
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
		"text": "Brindle: Ancient ordnance. Yes, I see the shape. Log it as artillery.",
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
