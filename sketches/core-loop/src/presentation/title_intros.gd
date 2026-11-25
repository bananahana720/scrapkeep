extends RefCounted

const BPM := 129.0
const BAR := 240.0 / BPM
const SEEN_PREFIX := "title_intro:"
const MET_PREFIX := "title_met:"
const LAST_STAT := "title_intro.last"
const FIRST := "sable"

const WORLD_PROOF := {2: ["ach_d7_mushroom"], 3: ["highdraft_reached", "ach_d7_moth"]}
const BOSS_PROOF := {"brindle": "brindle_routed", "waking": "waking_stilled", "mind": "mind_quieted"}
const ENDING_PROOF := "mind_quieted"

const ROWS := [
	{"id": "sable", "kind": "pilot", "pilot": "pylon_engineer", "world": 1, "theme": "A",
		"card": ["SABLE", "Fox · pylon engineer", "Top speed", "yes", "Brakes", "rumoured", "Leaves", "faster than she arrived"],
		"lines": ["Spillway Works. Dawn. Probably a Tuesday.", "This is the sad part.", "Moss packed a spare."],
		"sfx": ["VRRRM", "FWOOSH", "KLANG!"], "cameo": "brindle", "inset": "Someone out there remembers her. (Later.)",
		"postcard": {
			"at": Vector3(0.0, 0.0, -950.0),
			"set": "res://assets/models/park/landmark_dam.glb",
			"dressing": [
				{"model": "res://assets/models/park/anchor_hoodoo_c.glb", "at": Vector3(-248, 5, -20), "scale": Vector3(32.0, 14.5, 23.0), "yaw_deg": 27.0},
				{"model": "res://assets/models/park/anchor_hoodoo_b.glb", "at": Vector3(254, 4, -58), "scale": Vector3(27.0, 12.5, 22.0), "yaw_deg": 145.0},
			],
			"water": {"at": Vector3(0.0, 5.0, 380.0), "size": Vector2(1600.0, 1000.0)},
			"subject": {"at": Vector3(61.0, 121.0, -71.0), "scale": 3.2},
			"camera": {"at": Vector3(-53.0, 9.0, 364.0), "look": Vector3(-11.0, 77.0, -43.0), "drift": Vector3(0.0, 0.0, -20.0), "fov": 40.0},
			"sky": "dawn",
		}},
	{"id": "spillway", "kind": "world", "world": 1, "theme": "A",
		"card": ["SPILLWAY WORKS", "World one · the river canyon", "Pumps", "rusty", "River", "keeps no promises", "Fish", "larger than the Foreman permits"],
		"lines": ["World one. Wet, sunny, loud.", "The river took the spare seal.", "Moss packed another."],
		"sfx": ["GLUG", "SPLOOSH", "CLANK!"]},
	{"id": "brindle", "kind": "boss", "boss": "brindle", "world": 1, "theme": "B",
		"card": ["ADMIRAL BRINDLE", "Badger · Furnace Fleet", "Height", "two paws", "Iron", "twelve hundred tons (rounded up)", "Voice", "never raised"],
		"lines": ["The Furnace Fleet. On schedule.", "The arithmetic never worked.", "Brindle rounded it up anyway."],
		"sfx": ["HONK", "CHUNK", "KA-CHING"]},
	{"id": "rivet", "kind": "pilot", "pilot": "runner_gunner", "world": 1, "theme": "A",
		"card": ["RIVET", "Mole · runner-gunner", "Eyesight", "theoretical", "Misses", "none on record", "Stops", "no"],
		"lines": ["Spillway Works. The cage, opened from inside.", "He measured the sadness twice.", "Moss packed spare lenses."],
		"sfx": ["BZZT", "VRAAAM", "KLANG!"]},
	{"id": "dig", "kind": "world", "world": 2, "theme": "A",
		"card": ["THE DIG", "World two · underground", "Light", "borrowed", "Walls", "knock back", "Lunch tin", "keep closed"],
		"lines": ["World two. Knock twice.", "The extra lamp burns cold.", "Moss packed a warmer one."],
		"sfx": ["TINK", "KNOCK KNOCK", "CRUNCH!"]},
	{"id": "kest", "kind": "pilot", "pilot": "demolitions_caster", "world": 2, "theme": "A",
		"card": ["KEST", "Kestrel · demolitions caster", "Measures", "every load", "Commits", "eventually", "Then", "BOOM"],
		"lines": ["The Dig. Somewhere under it, knocking.", "She hovered. For too long.", "Moss packed a longer fuse."],
		"sfx": ["FSSSS", "WHUMP", "BOOM!"]},
	{"id": "waking", "kind": "boss", "boss": "waking", "world": 2, "theme": "B",
		"card": ["THE WAKING", "Ancient · under the Dig", "Asleep", "no longer", "Knocks", "twice", "Mood", "woken"],
		"lines": ["The Dig. The wall knocked first.", "It only wanted to sleep.", "Moss packed earplugs."],
		"sfx": ["DOOM", "KNOCK", "RUMBLE"]},
	{"id": "tarn", "kind": "pilot", "pilot": "tarn", "world": 1, "theme": "A",
		"card": ["TARN", "Tiger · claw bruiser", "Temperament", "gentle", "Machine", "is not", "Claws issued", "none"],
		"lines": ["Spillway Works. The day Brindle fell.", "Even gentle tigers get rained on.", "Moss packed a claw file."],
		"sfx": ["SKREEE", "CLAMP", "RIIIP!"]},
	{"id": "highdraft", "kind": "world", "world": 3, "theme": "A",
		"card": ["THE HIGHDRAFT", "World three · islands in the air", "Altitude", "plenty", "Wind", "takes wrenches", "Returns", "spoons"],
		"lines": ["World three. Mind the gap.", "The wind took the wrench.", "It sent back a spoon."],
		"sfx": ["WHOOOSH", "FLAP", "TWANG!"]},
	{"id": "mind", "kind": "boss", "boss": "mind", "world": 3, "theme": "B",
		"card": ["THE MIND", "The Foreman · ran the old works", "Hands", "many", "Watching", "you", "Likes", "you"],
		"lines": ["The Highdraft. Still, then exact.", "It was alone a very long time.", "Moss packed it a sandwich."],
		"sfx": ["HMMMM", "CLICK", "ZAP!"]},
	{"id": "tally", "kind": "pilot", "pilot": "tally", "world": 1, "theme": "A",
		"card": ["TALLY", "Pack Rat · dispatch wire-tapper", "Switchboard", "ratted out", "Master-key ring", "kept", "Circuits", "still live"],
		"lines": ["Spillway switchboard. Night shift.", "The circuit shorted. Briefly.", "Moss packed fresh jumper clips."],
		"sfx": ["KA-CHUNK", "CLACK", "ZAP!"]},
	{"id": "cannon", "kind": "pilot", "pilot": "remembered_cannon", "world": 3, "theme": "B",
		"card": ["THE CANNON", "Rebuilt ancient", "Built by", "the Mind", "Remembers", "the fox", "Cleaned", "once"],
		"lines": ["The Highdraft gate. One gun, cleaned.", "Tragic backstory, part one of one.", "Moss packed a polishing rag."],
		"sfx": ["HUM", "KA-THOOM", "BOOM!"], "after_ending": true},
]


static func row(id: String) -> Dictionary:
	for r in ROWS:
		if r.id == id:
			return r
	return {}


static func index_of(id: String) -> int:
	for i in ROWS.size():
		if ROWS[i].id == id:
			return i
	return -1


static func facts_from(profile, flyable: Callable) -> Dictionary:
	var facts := {"seen": [], "pilots": [], "worlds": [1], "met": [], "ending": false, "last": -1}
	if profile == null:
		return facts
	for r in ROWS:
		if r.kind == "pilot" and flyable.is_valid() and bool(flyable.call(String(r.pilot))):
			facts.pilots.append(String(r.pilot))
	for world in WORLD_PROOF:
		for id in WORLD_PROOF[world]:
			if profile.earned(id) and not facts.worlds.has(world):
				facts.worlds.append(world)
	for boss in BOSS_PROOF:
		if profile.is_seen(MET_PREFIX + boss) or profile.earned(BOSS_PROOF[boss]):
			facts.met.append(boss)
	facts.ending = profile.earned(ENDING_PROOF)
	for r in ROWS:
		if profile.is_seen(SEEN_PREFIX + r.id):
			facts.seen.append(r.id)
	if profile.is_seen(SEEN_PREFIX + FIRST):
		facts.last = int(profile.stat(LAST_STAT)) % ROWS.size()
	return facts


static func available(facts: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for r in ROWS:
		var ok := false
		match String(r.kind):
			"pilot":
				ok = facts.pilots.has(String(r.pilot)) and (not r.get("after_ending", false) or facts.ending)
			"world":
				ok = facts.worlds.has(int(r.world))
			"boss":
				ok = facts.met.has(String(r.boss))
		if ok or r.id == FIRST:
			out.append(String(r.id))
	return out


static func pick(facts: Dictionary) -> String:
	if not facts.seen.has(FIRST):
		return FIRST
	var open := available(facts)
	for i in range(open.size() - 1, -1, -1):
		if not facts.seen.has(open[i]):
			return open[i]
	var last := int(facts.get("last", -1))
	for id in open:
		if index_of(id) > last:
			return id
	return open[0]


static func mark_shown(profile, id: String) -> void:
	if profile == null or index_of(id) < 0:
		return
	profile.mark_seen(SEEN_PREFIX + id)
	var turn := int(profile.stat(LAST_STAT))
	var next := turn - turn % ROWS.size() + index_of(id)
	if next <= turn:
		next += ROWS.size()
	profile.set_stat(LAST_STAT, float(next))


static func mark_met(profile, boss: String) -> bool:
	if profile == null or not BOSS_PROOF.has(boss):
		return false
	return profile.mark_seen(MET_PREFIX + boss)


static func pointer_line(id: String) -> String:
	var r := row(id)
	if r.is_empty():
		return ""
	if id == "sable":
		return "this is her."
	if r.kind == "world":
		return "you are here."
	var who := String(r.card[0]).capitalize()
	return "this is %s." % (("the " + who.trim_prefix("The ")) if who.begins_with("The ") else who)


static func shots(id: String) -> Array:
	var r := row(id)
	if r.is_empty():
		return []
	var list := [
		{"kind": "postcard", "bars": 2, "beat": "hype"},
		{"kind": "hero", "bars": 2, "beat": "hype"},
		{"kind": "card", "bars": 2, "beat": "hype"},
		{"kind": "action", "bars": 2, "beat": "hype"},
	]
	if r.kind == "pilot":
		list.append({"kind": "antics", "bars": 2, "beat": "hype"})
	if id == FIRST:
		list.append({"kind": "rollcall", "bars": 2, "beat": "hype"})
		list.append({"kind": "collision", "bars": 1, "beat": "collision"})
		list.append({"kind": "rival", "bars": 2, "beat": "collision"})
	list.append({"kind": "crash", "bars": 3, "beat": "crash"})
	list.append({"kind": "wink", "bars": 2, "beat": "wink"})
	list.append({"kind": "up", "bars": 2, "beat": "up"})
	list.append({"kind": "slam", "bars": 2, "beat": "up"})
	return list


static func length_seconds(id: String) -> float:
	var bars := 0
	for s in shots(id):
		bars += int(s.bars)
	return bars * BAR
