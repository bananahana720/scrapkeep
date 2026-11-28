extends RefCounted


const FULL_ALPHA := true

const ROWS := [
	{"id": 1, "name": "Spillway Works", "boss": "brindle"},
	{"id": 2, "name": "The Dig", "boss": "waking"},
	{"id": 3, "name": "The Highdraft", "boss": "mind"},
]

const BOSSES := {
	"brindle": {"name": "Admiral Brindle", "title": "SPILLWAY RECLAIMED", "script": "res://src/boss/boss.gd", "kind": "brindle", "music": "brindle",
		"built": true, "card_icon": "fac_fleet", "card_event_tint": true,
		"victory": "Back on the crew's books, kettle and all.", "epitaph": "Brindle, crane parked over the Slag Bowl. Anchors accounted for."},
	"waking": {"name": "The Waking", "title": "THE WAKING STILLED", "script": "res://src/boss/waking.gd", "kind": "waking", "music": "waking",
		"built": true, "card_icon": "obj_warden", "card_event_tint": false,
		"obj_closed": "Break the Waking's plates", "obj_open": "Smash the Waking's core",
		"victory": "The Waking is stilled.", "epitaph": "The Waking, stilled in the Dig. Fallen floors await pit inspection."},
	"mind": {"name": "The Mind", "title": "THE MIND QUIETED", "script": "res://src/boss/mind.gd", "kind": "mind", "music": "mind",
		"built": true, "card_icon": "obj_warden", "card_event_tint": false,
		"obj_closed": "Break the Mind's guard", "obj_open": "Smash the Mind's core",
		"victory": "The Mind is quiet.", "stamp": "HIRED", "finale_lift_semitones": 2,
		"epitaph": "The Mind, quieted in the Highdraft. Glove set by the empty place."},
}

const ENDING_PARK_SPOTS := {
	"park_dam": {"spot": Vector2(0.0, 445.0), "fwd": Vector3(0.0, 0.0, 1.0)},
	"park_flume": {"spot": Vector2(180.0, 460.0), "fwd": Vector3(90.0, 0.0, 50.0)},
	"park_pit": {"spot": Vector2(0.0, 145.0), "fwd": Vector3(0.0, 0.0, 1.0)},
	"park_sinkhole": {"spot": Vector2(0.0, 210.0), "fwd": Vector3(0.0, 0.0, 1.0)},
}


static func boss_finale_lift(boss_id: String) -> int:
	return int(BOSSES.get(boss_id, {}).get("finale_lift_semitones", 0))


const ENDING := {
	"title": "RETURN TRIP ENTERED",
	"log": {
		1: [
			"Shift log: Brindle routed. Head house drum turns without anyone on the handwheel.",
			"Intake clear. Old flood marks inside the housing are one hand higher.",
		],
		2: [
			"Shift board: the Waking is stilled. Nobody has knocked since.",
			"Pit inspected. Seven lamps back on the rack. We only issued six.",
		],
		3: [
			"Highdraft watch: the Mind is quiet. We hear a washer rolling across the deck.",
			"West cable holds its note. Nobody answers from the next island.",
		],
	},
	"close": [
		"Moss has a needle through my glove. Says supper won't mend it.",
		"Tally laid the three leaves beside the repair sheet. The torn edges fit.",
	],
	"sign": "Return trip entered. We filled in the time ourselves. Filed by the bay crew.",
	"free_roll": {"seconds": 60.0, "skippable": true, "blocking": false},
}

static func row(world: int) -> Dictionary:
	for r in ROWS:
		if int(r["id"]) == world:
			return r
	return {}


static func boss_of(world: int) -> Dictionary:
	var r := row(world)
	if r.is_empty():
		return {}
	return BOSSES.get(String(r["boss"]), {})
