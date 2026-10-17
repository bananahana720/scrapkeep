extends RefCounted

# The records on Moss's jukebox: every tune a run can play, found the first time it is heard
# in play (tune_ear.gd) and kept in the profile's tunes list. One row per tune the game can
# tell apart today. A row's source says what the band was doing when it played, so the same
# row both recognises a tune (key_of) and plays it back at camp (audio.gd spin).
#   menu    the title or a summary pack (won picks the summary's outcome)
#   level   a zone's roaming music
#   warden  a zone's Warden fight
#   boss    a world boss's fight
#   lounge  Moss's bay, a layer mask over the zone the bay docks at
# A new track (a secret area, a champion, a final phase) is one more row with its own source
# kind and one more branch in key_of; nothing else changes. where is the dry hint a blank
# sleeve shows; sleeve is the note on the record once found.

const SHELVES := ["Camp", "Spillway Works", "The Dig", "The Highdraft"]

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
	{"id": "roam-1-1", "name": "Top Shelf", "shelf": 1, "rare": false,
		"where": "Roll the Spillway's top shelf.",
		"sleeve": "Logged at flood stage. Drums ride the current.",
		"source": {"kind": "level", "zone": "1-1"}},
	{"id": "roam-1-2", "name": "Cable Reach", "shelf": 1, "rare": false,
		"where": "Cross the Cable Reach.",
		"sleeve": "Every span tuned by hand.",
		"source": {"kind": "level", "zone": "1-2"}},
	{"id": "warden-1-1", "name": "Shelf Warden", "shelf": 1, "rare": false,
		"where": "Wake the Warden on the top shelf.",
		"sleeve": "It was asleep. Now it is a groove.",
		"source": {"kind": "warden", "zone": "1-1"}},
	{"id": "warden-1-2", "name": "Reach Warden", "shelf": 1, "rare": false,
		"where": "Wake the Warden on the Cable Reach.",
		"sleeve": "Plays louder when the cables are taut.",
		"source": {"kind": "warden", "zone": "1-2"}},
	{"id": "boss-brindle", "name": "Admiral Brindle", "shelf": 1, "rare": true,
		"where": "Meet the Admiral.",
		"sleeve": "Runtime rounded up to the nearest anthem.",
		"source": {"kind": "boss", "boss": "brindle"}},
	{"id": "roam-2-1", "name": "Upper Bench", "shelf": 2, "rare": false,
		"where": "Roll the Dig's upper bench.",
		"sleeve": "Recorded underground. The rock kept time.",
		"source": {"kind": "level", "zone": "2-1"}},
	{"id": "roam-2-2", "name": "Deep Works", "shelf": 2, "rare": false,
		"where": "Go down to the deep works.",
		"sleeve": "Deeper than the survey says. The bass knows.",
		"source": {"kind": "level", "zone": "2-2"}},
	{"id": "warden-2-1", "name": "Bench Warden", "shelf": 2, "rare": false,
		"where": "Wake the Warden on the upper bench.",
		"sleeve": "Dust in the grooves. Left in.",
		"source": {"kind": "warden", "zone": "2-1"}},
	{"id": "warden-2-2", "name": "Works Warden", "shelf": 2, "rare": false,
		"where": "Wake the Warden in the deep works.",
		"sleeve": "Shift bell sampled without asking.",
		"source": {"kind": "warden", "zone": "2-2"}},
	{"id": "boss-waking", "name": "The Waking", "shelf": 2, "rare": true,
		"where": "Find what the Dig was digging for.",
		"sleeve": "It woke up in this key.",
		"source": {"kind": "boss", "boss": "waking"}},
	{"id": "roam-3-1", "name": "Highdraft", "shelf": 3, "rare": false,
		"where": "Ride the Highdraft.",
		"sleeve": "Mastered at altitude. Ears may pop.",
		"source": {"kind": "level", "zone": "3-1"}},
	{"id": "roam-3-2", "name": "The Crown", "shelf": 3, "rare": false,
		"where": "Climb to the Highdraft's crown.",
		"sleeve": "The last shelf in the crate.",
		"source": {"kind": "level", "zone": "3-2"}},
	{"id": "warden-3-1", "name": "Draft Warden", "shelf": 3, "rare": false,
		"where": "Wake the Warden in the Highdraft.",
		"sleeve": "Recorded in a crosswind. Mostly.",
		"source": {"kind": "warden", "zone": "3-1"}},
	{"id": "warden-3-2", "name": "Crown Warden", "shelf": 3, "rare": false,
		"where": "Wake the Warden on the crown.",
		"sleeve": "Highest Warden on file.",
		"source": {"kind": "warden", "zone": "3-2"}},
	{"id": "boss-mind", "name": "The Mind", "shelf": 3, "rare": true,
		"where": "Reach the top of the Highdraft.",
		"sleeve": "Liner notes: one line, and it is about you.",
		"source": {"kind": "boss", "boss": "mind"}},
]

const BOSSES := ["brindle", "waking", "mind"]


static func ids() -> Array:
	return ROWS.map(func(r: Dictionary): return String(r["id"]))


static func row(id: String) -> Dictionary:
	for r in ROWS:
		if r["id"] == id:
			return r
	return {}


static func on_shelf(shelf: int) -> Array:
	return ROWS.filter(func(r: Dictionary): return int(r["shelf"]) == shelf)


# The tune the band is playing, from what the music director reports: mode (idle, play or
# dead), track and section as music_engine.gd names them, whether Moss's lounge mask is on,
# and the zone ("1-1") of the stage in play. "" when nothing on the jukebox is playing: the
# death break's keys, the miniboss's darkened level, a track no row names.
static func key_of(state: Dictionary) -> String:
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
		_:
			if track in BOSSES:
				id = "boss-" + track
	return id if not row(id).is_empty() else ""
