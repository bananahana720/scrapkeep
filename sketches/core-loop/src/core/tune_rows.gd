extends RefCounted


const SHELVES := ["Every Run", "Spillway Works", "The Dig", "The Highdraft"]

const ROWS := [
	{"id": "title", "name": "Lights On", "shelf": 0, "rare": false,
		"where": "Plays when the lights come on.",
		"sleeve": "Moss's copy. The label is a ration sticker.",
		"source": {"kind": "menu", "pack": "title"}},
	{"id": "summary-win", "name": "Shift Complete", "shelf": 0, "rare": true,
		"where": "Finish a run.",
		"sleeve": "Recorded the one time everything went right.",
		"source": {"kind": "menu", "pack": "summary", "won": true}},
	{"id": "summary-loss", "name": "Shift Over", "shelf": 0, "rare": false,
		"where": "End a run early. It happens.",
		"sleeve": "Club hours. Somebody tips the bucket.",
		"source": {"kind": "menu", "pack": "summary", "won": false}},
	{"id": "lounge", "name": "Moss's Lounge", "shelf": 0, "rare": true,
		"where": "Moss keeps a record on in the bay.",
		"sleeve": "Never turned off. The knob is decorative.",
		"source": {"kind": "lounge", "zone": "1-1"}},
	{"id": "miniboss", "name": "Heavyweight", "shelf": 0, "rare": false,
		"where": "Pick a fight with a mini-boss.",
		"sleeve": "Weigh-in was a formality.",
		"source": {"kind": "miniboss", "zone": "1-1"}},
	{"id": "champion-hype", "name": "Champion", "shelf": 0, "rare": true,
		"where": "Meet a champion out on a run.",
		"sleeve": "Brought its own entrance music.",
		"source": {"kind": "pack", "pack": "champion-hype", "boss": "brindle"}},
	{"id": "euro-champion", "name": "Champion, Drop", "shelf": 0, "rare": true,
		"where": "Wear a champion down to its last third.",
		"sleeve": "Nobody told the crowd there was a crowd.",
		"source": {"kind": "pack", "pack": "euro-champion", "boss": "brindle"}},
	{"id": "event-scrap-stampede", "name": "Scrap Stampede", "shelf": 0, "rare": false,
		"where": "Get caught in a scrap stampede.",
		"sleeve": "Recorded mid-stampede. Some percussion was debris.",
		"source": {"kind": "pack", "pack": "event-scrap-stampede", "zone": "1-1"}},
	{"id": "event-surge-run", "name": "Surge Run", "shelf": 0, "rare": false,
		"where": "Race a surge run.",
		"sleeve": "Tempo set by the surge, not the band.",
		"source": {"kind": "pack", "pack": "event-surge-run", "zone": "1-1"}},
	{"id": "event-hold-relay", "name": "Hold the Relay", "shelf": 0, "rare": false,
		"where": "Hold a relay until it finishes.",
		"sleeve": "Every bar is a bar the relay stayed up.",
		"source": {"kind": "pack", "pack": "event-hold-relay", "zone": "1-1"}},
	{"id": "event-flood", "name": "Flood Gates", "shelf": 0, "rare": false,
		"where": "Be there when the flood comes.",
		"sleeve": "Waterproof sleeve. Contents not.",
		"source": {"kind": "pack", "pack": "event-flood", "zone": "1-2"}},
	{"id": "event-dust-squall", "name": "Dust Squall", "shelf": 0, "rare": false,
		"where": "Ride out a dust squall.",
		"sleeve": "Grit in the grooves, kept for authenticity.",
		"source": {"kind": "pack", "pack": "event-dust-squall", "zone": "2-1"}},
	{"id": "event-arena", "name": "Round Arena", "shelf": 0, "rare": false,
		"where": "Step into a round arena.",
		"sleeve": "Ring bell sold separately.",
		"source": {"kind": "pack", "pack": "event-arena", "zone": "1-1"}},
	{"id": "moss-shop", "name": "Moss's Counter", "shelf": 0, "rare": false,
		"where": "Stop at Moss's counter.",
		"sleeve": "Plays while you browse. Moss insists it helps.",
		"source": {"kind": "pack", "pack": "moss-shop", "zone": "1-1", "lounge": true}},
	{"id": "modifier-par", "name": "Beat the Par", "shelf": 0, "rare": false,
		"where": "Start a run on par time.",
		"sleeve": "Stopwatch included. Starts itself.",
		"source": {"kind": "pack", "pack": "modifier-par", "zone": "1-1"}},
	{"id": "fabricator", "name": "The Fabricator", "shelf": 0, "rare": false,
		"where": "Roll through a fabricator hoop.",
		"sleeve": "Recorded at full speed. No refunds.",
		"source": {"kind": "pack", "pack": "fabricator", "zone": "1-1"}},
	{"id": "modifier-curse", "name": "Cursed Run", "shelf": 0, "rare": false,
		"where": "Take a curse pocket's deal.",
		"sleeve": "Signed in fine print. The band read it.",
		"source": {"kind": "pack", "pack": "modifier-curse", "zone": "1-1"}},
	{"id": "secret-after-hours", "name": "Moss After Hours", "shelf": 0, "rare": true,
		"where": "Moss's bay jukebox has a B-side.",
		"sleeve": "Closing time. Moss stays for one more.",
		"source": {"kind": "pack", "pack": "secret-after-hours", "zone": "1-1", "lounge": true}},
	{"id": "secret-chip-keepers", "name": "Chiptune Keepers", "shelf": 0, "rare": true,
		"where": "Sometimes a champion arrives in eight bits.",
		"sleeve": "Rare pressing. Found in a cartridge slot.",
		"source": {"kind": "pack", "pack": "secret-chip-keepers", "boss": "brindle"}},
	{"id": "roam-1-1", "name": "Top Shelf", "shelf": 1, "rare": false,
		"where": "Roll the Spillway's top shelf.",
		"sleeve": "Logged at flood stage. Drums ride the current.",
		"source": {"kind": "level", "zone": "1-1"}},
	{"id": "roam-1-2", "name": "Cable Reach", "shelf": 1, "rare": false,
		"where": "Cross the Cable Reach.",
		"sleeve": "Every span tuned by hand.",
		"source": {"kind": "level", "zone": "1-2"}},
	{"id": "warden-1-1", "name": "Shelf Riff", "shelf": 1, "rare": false,
		"where": "Wake the Warden on the top shelf.",
		"sleeve": "It was asleep. Now it is a groove.",
		"source": {"kind": "warden", "zone": "1-1"}},
	{"id": "warden-1-2", "name": "Reach Static", "shelf": 1, "rare": false,
		"where": "Wake the Warden on the Cable Reach.",
		"sleeve": "Plays louder when the cables are taut.",
		"source": {"kind": "warden", "zone": "1-2"}},
	{"id": "boss-brindle", "name": "Admiral Brindle", "shelf": 1, "rare": true,
		"where": "Meet the Admiral.",
		"sleeve": "Runtime rounded up to the nearest anthem.",
		"source": {"kind": "boss", "boss": "brindle"}},
	{"id": "brindle-p1-requisition", "name": "Requisition", "shelf": 1, "rare": true,
		"where": "Hear the Admiral open the fight.",
		"sleeve": "Form one of three. Filed in triplicate.",
		"source": {"kind": "pack", "pack": "brindle-p1-requisition", "boss": "brindle"}},
	{"id": "brindle-p2-furnace", "name": "Furnace", "shelf": 1, "rare": true,
		"where": "Push Brindle into the second phase.",
		"sleeve": "Stoked by hand. Gauges ignored.",
		"source": {"kind": "pack", "pack": "brindle-p2-furnace", "boss": "brindle"}},
	{"id": "brindle-p3-scuttle", "name": "Scuttle", "shelf": 1, "rare": true,
		"where": "Push Brindle into the last phase.",
		"sleeve": "Abandon ship, in tempo.",
		"source": {"kind": "pack", "pack": "brindle-p3-scuttle", "boss": "brindle"}},
	{"id": "euro-brindle-p3", "name": "Brindle, Drop", "shelf": 1, "rare": true,
		"where": "Hold on through Brindle's last phase.",
		"sleeve": "The Admiral discovers four on the floor.",
		"source": {"kind": "pack", "pack": "euro-brindle-p3", "boss": "brindle"}},
	{"id": "landmark-spillway-dam", "name": "Over the Dam", "shelf": 1, "rare": false,
		"where": "Roll up to the Spillway dam.",
		"sleeve": "Recorded on the crest. The spillway did backing vocals.",
		"source": {"kind": "pack", "pack": "landmark-spillway-dam", "zone": "1-1"}},
	{"id": "landmark-penstock", "name": "Penstock Pressure", "shelf": 1, "rare": false,
		"where": "Get close to the penstock tower.",
		"sleeve": "Gauge in the red the whole take.",
		"source": {"kind": "pack", "pack": "landmark-penstock", "zone": "1-2"}},
	{"id": "secret-lost-tape", "name": "The Lost Tape", "shelf": 1, "rare": true,
		"where": "Something is cached on the Cable Reach.",
		"sleeve": "Label worn off. Nobody admits recording it.",
		"source": {"kind": "pack", "pack": "secret-lost-tape", "zone": "1-2"}},
	{"id": "secret-brindle-swing", "name": "Brindle Swings", "shelf": 1, "rare": true,
		"where": "Sometimes Brindle opens with a different swing.",
		"sleeve": "The Admiral, off duty, with a horn section.",
		"source": {"kind": "pack", "pack": "secret-brindle-swing", "boss": "brindle"}},
	{"id": "roam-2-1", "name": "Upper Bench", "shelf": 2, "rare": false,
		"where": "Roll the Dig's upper bench.",
		"sleeve": "Recorded underground. The rock kept time.",
		"source": {"kind": "level", "zone": "2-1"}},
	{"id": "roam-2-2", "name": "Deep Works", "shelf": 2, "rare": false,
		"where": "Go down to the deep works.",
		"sleeve": "Deeper than the survey says. The bass knows.",
		"source": {"kind": "level", "zone": "2-2"}},
	{"id": "warden-2-1", "name": "Bench Hammer", "shelf": 2, "rare": false,
		"where": "Wake the Warden on the upper bench.",
		"sleeve": "Dust in the grooves. Left in.",
		"source": {"kind": "warden", "zone": "2-1"}},
	{"id": "warden-2-2", "name": "Works Grind", "shelf": 2, "rare": false,
		"where": "Wake the Warden in the deep works.",
		"sleeve": "Shift bell sampled without asking.",
		"source": {"kind": "warden", "zone": "2-2"}},
	{"id": "boss-waking", "name": "The Waking", "shelf": 2, "rare": true,
		"where": "Find what the Dig was digging for.",
		"sleeve": "It woke up in this key.",
		"source": {"kind": "boss", "boss": "waking"}},
	{"id": "waking-final", "name": "The Waking, Final", "shelf": 2, "rare": true,
		"where": "Take the Waking to its last phase.",
		"sleeve": "Fully awake now. Regrets nothing.",
		"source": {"kind": "pack", "pack": "waking-final", "boss": "waking"}},
	{"id": "euro-waking-final", "name": "The Waking, Drop", "shelf": 2, "rare": true,
		"where": "Stay alive in the Waking's last phase.",
		"sleeve": "Bass drop logged by the seismograph.",
		"source": {"kind": "pack", "pack": "euro-waking-final", "boss": "waking"}},
	{"id": "landmark-headframe", "name": "Down the Headframe", "shelf": 2, "rare": false,
		"where": "Find the Dig's headframe.",
		"sleeve": "Recorded on the way down. Cable creak left in.",
		"source": {"kind": "pack", "pack": "landmark-headframe", "zone": "2-1"}},
	{"id": "landmark-sinkhole", "name": "Sinkhole Echo", "shelf": 2, "rare": false,
		"where": "Stand at the edge of the sinkhole.",
		"sleeve": "Every note came back twice.",
		"source": {"kind": "pack", "pack": "landmark-sinkhole", "zone": "2-2"}},
	{"id": "secret-dig-dub", "name": "Deep Works Dub", "shelf": 2, "rare": true,
		"where": "Sometimes the deep works drop into dub.",
		"sleeve": "Same works, more echo, less hurry.",
		"source": {"kind": "pack", "pack": "secret-dig-dub", "zone": "2-2"}},
	{"id": "roam-3-1", "name": "Highdraft", "shelf": 3, "rare": false,
		"where": "Ride the Highdraft.",
		"sleeve": "Mastered at altitude. Ears may pop.",
		"source": {"kind": "level", "zone": "3-1"}},
	{"id": "roam-3-2", "name": "The Crown", "shelf": 3, "rare": false,
		"where": "Climb to the Highdraft's crown.",
		"sleeve": "The last shelf in the crate.",
		"source": {"kind": "level", "zone": "3-2"}},
	{"id": "warden-3-1", "name": "Draft Surge", "shelf": 3, "rare": false,
		"where": "Wake the Warden in the Highdraft.",
		"sleeve": "Recorded in a crosswind. Mostly.",
		"source": {"kind": "warden", "zone": "3-1"}},
	{"id": "warden-3-2", "name": "Crown Peal", "shelf": 3, "rare": false,
		"where": "Wake the Warden on the crown.",
		"sleeve": "Highest Warden on file.",
		"source": {"kind": "warden", "zone": "3-2"}},
	{"id": "boss-mind", "name": "The Mind", "shelf": 3, "rare": true,
		"where": "Reach the top of the Highdraft.",
		"sleeve": "Liner notes: one line, and it is about you.",
		"source": {"kind": "boss", "boss": "mind"}},
	{"id": "mind-final", "name": "The Mind, Final", "shelf": 3, "rare": true,
		"where": "Take the Mind to its last phase.",
		"sleeve": "It saved its best thought for last.",
		"source": {"kind": "pack", "pack": "mind-final", "boss": "mind"}},
	{"id": "euro-mind-final", "name": "The Mind, Drop", "shelf": 3, "rare": true,
		"where": "Stay alive in the Mind's last phase.",
		"sleeve": "Overthinking, set to a beat.",
		"source": {"kind": "pack", "pack": "euro-mind-final", "boss": "mind"}},
	{"id": "landmark-hanging-isle", "name": "The Hanging Isle", "shelf": 3, "rare": false,
		"where": "Get under the hanging isle.",
		"sleeve": "Recorded upside down, allegedly.",
		"source": {"kind": "pack", "pack": "landmark-hanging-isle", "zone": "3-1"}},
	{"id": "landmark-crown-spire", "name": "Crown of the Spire", "shelf": 3, "rare": false,
		"where": "Reach the crown spire.",
		"sleeve": "Thin air, thinner reverb.",
		"source": {"kind": "pack", "pack": "landmark-crown-spire", "zone": "3-2"}},
	{"id": "secret-highdraft-rain", "name": "Rain over the Highdraft", "shelf": 3, "rare": true,
		"where": "Sometimes it rains over the Highdraft.",
		"sleeve": "Forecast: slow, with scattered keys.",
		"source": {"kind": "pack", "pack": "secret-highdraft-rain", "zone": "3-1"}},
]

const BOSSES := ["brindle", "waking", "mind"]


const SECRETS := "res://src/core/secrets.gd"


static func shut(id: String, profile, sitting := false) -> bool:
	if not ResourceLoader.exists(SECRETS):
		return false
	var secrets = load(SECRETS)
	return id == String(secrets.TUNE) and not secrets.tune_open(profile, sitting)


static func ids() -> Array:
	return ROWS.map(func(r: Dictionary): return String(r["id"]))


static func row(id: String) -> Dictionary:
	for r in ROWS:
		if r["id"] == id:
			return r
	return {}


static func on_shelf(shelf: int) -> Array:
	return ROWS.filter(func(r: Dictionary): return int(r["shelf"]) == shelf)


static func key_of(state: Dictionary) -> String:
	var pack := String(state.get("pack", ""))
	if pack != "" and not row(pack).is_empty():
		return pack
	var mode := String(state.get("mode", ""))
	var track := String(state.get("track", ""))
	var zone := String(state.get("zone", ""))
	if mode == "dead":
		return ""
	var id := ""
	match track:
		"title":
			id = "title"
		"summary":
			id = "summary-win" if String(state.get("section", "")) == "won" else "summary-loss"
		"level":
			if mode == "play":
				id = "lounge" if bool(state.get("lounge", false)) else "roam-" + zone
		"warden":
			id = "warden-" + zone
		"miniboss":
			id = "miniboss"
		_:
			if track in BOSSES:
				id = "boss-" + track
	return id if not row(id).is_empty() else ""
