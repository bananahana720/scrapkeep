extends RefCounted

# What the first won run opens (Andrew's design answer Q8, "A few secrets", 17 Oct 2026): one hidden
# room per world, one hidden tune and one alternate paint per pilot. A fresh profile has none of
# them and shows no hint of them; a profile that holds the first_win achievement has all of them.
# The sitting profile opens them too, as it opens every pilot (Q15), without saving.
#
# rooms  one cracked cache per world, built by activities.gd beside the park's own sites. A room
#        stands in a dead-end zone of its park's graph (park_graph.gd anchors(), off every line),
#        so it is found by looking, not by riding the route. Each room tests its park's skill
#        (Q4) and carries one crew-log line on its back wall, in the lore voice of lore_rows.gd.
#        The rows live here, not in the park files, so the park threads keep sole edits there.
# tune   a jukebox row id (tune_rows.gd on the jukebox branch). tune_open() is the one gate the
#        jukebox asks before it files or spins the record.
# paints cosmetic ids by pilot (cosmetics.gd); each is the reward of one hidden achievement row
#        (achievements.gd secret_paint_*) on the won run, so a paint is owned the usual way. Those
#        rows earn silently (progress.gd): the first win's own toast is the one announcement, and
#        the paints wait on the customize page with the new-item glow.

const UNLOCK := "first_win"
const LOG_WORD_CAP := 40

const ROOMS := {
	"spillway_break_room": {
		"world": 1, "map": "park_flume", "site": "bench_wash_7", "at": [-400, 720], "skill": "momentum",
		"name": "Pump Crew Break Room",
		"log": "Shift log, after hours: found the pump crew's break room behind the bench wash. Kettle still warm. Nobody admits to the kettle.",
	},
	"dig_off_book_adit": {
		"world": 2, "map": "park_pit", "site": "barge_apron", "at": [-336, 248], "skill": "abilities",
		"name": "Off-Book Adit",
		"log": "Survey tag: sealed adit by the barge apron, on no plan. Inside, a chalk tally of every shift that came back. Someone added yours.",
	},
	"highdraft_lookout": {
		"world": 3, "map": "park_islands", "site": "fin_west", "at": [-48, -240], "skill": "grapple",
		"name": "Uncharted Lookout",
		"log": "Rigging note: a hut on the west fin, never charted. One chair, facing where the Mind sits. Cushion worn. Visitor log signed: later.",
	},
}

# Moss's closing-time record: the B-side his bay jukebox only plays once a shift has been won.
const TUNE := "secret-after-hours"

const PAINTS := {
	"pylon_engineer": "paint_sable_overtime",
	"runner_gunner": "paint_rivet_inside_job",
	"demolitions_caster": "paint_kest_knock_back",
	"tarn": "paint_tarn_unissued",
	"tally": "paint_tally_carbon",
	"remembered_cannon": "paint_cannon_velvet",
}
# The hidden achievement row that grants each paint.
const PAINT_ROWS := {
	"pylon_engineer": "secret_paint_sable",
	"runner_gunner": "secret_paint_rivet",
	"demolitions_caster": "secret_paint_kest",
	"tarn": "secret_paint_tarn",
	"tally": "secret_paint_tally",
	"remembered_cannon": "secret_paint_cannon",
}
# Hidden rooms pay as the far pocket of the pay ladder (park_placement.gd PAY_FAR): rare only.
const ROOM_PAY := {"rarities": ["rare"]}

# Field finds (world 1 unit 15, Isaac's secret rooms as the baseline): two per Spillway park on
# every profile, fresh or won. Each is a cracked room in a dead-end zone of its park's graph, off
# every line, so the skipper never passes one. The rule is what you learn, not the spot: each find
# draws one of its `spots` per run from the run seed, so a run replays by seed and the next run
# moves it. Two families, two tells:
#   crack  a wet seep runs down a cracked face and drips (seen, and heard at DRIP_HEAR_M)
#   radio  a crew radio plays through the wall (heard at RADIO_HEAR_M; the lost tape on the find)
# A find pays the world's top ordinary rung (green, `rare`) every run; the first find also files
# its codex row, so the camp counts it. Spots stand on graph door nodes that are not the zone's
# far end, where grey panels' rib caches wait (IL-01). A spot's `face` is the way its cracked face
# looks: out of the dead end, toward the drop-in, so the run-up to ram it is the way in.
const FIND_KINDS := ["crack", "radio"]
const DRIP_HEAR_M := 22.0
const RADIO_HEAR_M := 40.0
const FIND_PAY := {"rarities": ["rare"]}

const FINDS := {
	"dam_turbine_hall": {
		"world": 1, "map": "park_dam", "kind": "crack",
		"spots": [{"site": "west_rim_bench", "at": [-236, 192], "face": [-1, -1]}, {"site": "powerhouse", "at": [120, 530], "face": [0, -1]}],
		"name": "Turbine Hall Seep",
		"log": "Maintenance note: the old turbine hall was bricked up after the flood. The bricks were not asked. Water found the way first.",
		"codex": {"id": "spillway_turbine_seep", "category": "world", "name": "Where the Water Got In",
			"hint": "A wet streak on dry rock. Water knows where the walls are thin.",
			"clue": "A seeping, dripping cracked face on the west rim bench or the powerhouse deck + a ram at speed",
			"text": "Follow the seep. Behind the dam's cracked faces the crew walled up rooms the flood had already found."},
	},
	"dam_shift_radio": {
		"world": 1, "map": "park_dam", "kind": "radio",
		"spots": [{"site": "east_rim_bench", "at": [232, 184], "face": [0, -1]}, {"site": "slot_fin_far", "at": [44, -244], "face": [2, -1]}],
		"name": "Night Shift Radio",
		"log": "Night shift: radio left on in the spare room so the dam has company. Station went off air years ago. Radio did not.",
		"codex": {"id": "spillway_shift_radio", "category": "world", "name": "Still On Air",
			"hint": "Music where nobody works any more. Roll toward it.",
			"clue": "A tune through a cracked wall on the east rim bench or at the north tip of the far slot fin + a ram at speed",
			"text": "The pump crews walled their radios in with the spares. Some of them are still playing the lost tape."},
	},
	"flume_trestle_seep": {
		"world": 1, "map": "park_flume", "kind": "crack",
		"spots": [{"site": "mesa_spill", "at": [-512, -528], "face": [0, -1]}, {"site": "field_bank_4", "at": [-528, -304], "face": [1, -1]}],
		"name": "Spill Cellar",
		"log": "Flume log: cellar under the spill flooded twice, sealed once. Crew kept the key. Lock was never fitted.",
		"codex": {"id": "spillway_flume_seep", "category": "world", "name": "Spill Cellar",
			"hint": "A dripping face where the flume runs over. Something is under the spill.",
			"clue": "A seeping, dripping cracked face off the flume's lines + a ram at speed",
			"text": "The flume leaks into the cellars it was built over. A cracked face that drips is a door."},
	},
	"flume_crew_radio": {
		"world": 1, "map": "park_flume", "kind": "radio",
		"spots": [{"site": "weir_pond", "at": [-576, -664], "face": [1, 0]}, {"site": "canal_wash_1", "at": [-104, -708], "face": [-1, 1]}],
		"name": "Pond Shift Wireless",
		"log": "Pond shift: the wireless stays tuned to the dance hour. Requests are taken. None played since the Mind clocked in.",
		"codex": {"id": "spillway_crew_radio", "category": "world", "name": "Requests Taken",
			"hint": "A dance tune from inside the rock, off the canal's lines.",
			"clue": "A tune through a cracked wall by the weir pond or down the canal wash + a ram at speed",
			"text": "The flume crew listened while they worked. Their wireless is still behind the wall, still taking requests."},
	},
}
# The timed door (world 1 unit 15, Isaac's timed boss doors): rout Brindle with the run clock under
# DOOR["under_s"] and the next run finds the Shift Clock Door by the dam's drop-in, a cracked room
# that pays the green rung and files its codex row. It is earned, not hidden, so it keeps the beacon.
# Every new run counts in DOOR_RUNS as it starts (a restart or an abandoned run too; a Continue does
# not); the rout writes the count the next run will see into DOOR_FOR, so the door is open for exactly
# that run, and a quit and Continue keeps it.
const DOOR := {
	"boss": "brindle", "under_s": 720.0, "world": 1, "map": "park_dam", "site": "top_shelf_deck",
	"at": [-208, -720], "face": [2, 1],
	"name": "Shift Clock Door",
	"log": "Shift note: crews who clock Brindle out before the whistle get the side door. Do not tell the slow shift.",
	"codex": {"id": "spillway_clock_door", "category": "world", "name": "Before the Whistle",
		"hint": "Some doors only open for a fast shift.",
		"clue": "Rout Brindle in under 12 minutes; the next run finds a clock door by the drop-in",
		"text": "The Spillway crews kept a side door for the shift that beat the whistle. Clock Brindle out early and it is unlocked next run."},
}
const DOOR_RUNS := "door.runs_started"
const DOOR_FOR := "door.brindle_clock_run"

# The world codex rows each world's camp count reads: its field finds, then the parks' authored
# secret caches (the contraption rows that carry a codex id).
const WORLD_CODEX := {1: ["spillway_turbine_seep", "spillway_shift_radio", "spillway_flume_seep", "spillway_crew_radio",
	"spillway_gallery_cache", "flume_weir_cache", "flume_grade_cache", "spillway_clock_door"]}
const WORLD_NAMES := {1: "Spillway"}


# A secret paint the profile does not own, or a secret row it has not earned: the customize page,
# the achievements page and the camp's count leave these out, so a fresh profile sees no hint.
static func shut_paint(id: String, profile) -> bool:
	return PAINTS.values().has(id) and not (profile != null and profile.has_cosmetic(id))


static func shut_row(id: String, profile) -> bool:
	return PAINT_ROWS.values().has(id) and not (profile != null and profile.earned(id))


static func open(profile, sitting := false) -> bool:
	return sitting or (profile != null and profile.earned(UNLOCK))


static func tune_open(profile, sitting := false) -> bool:
	return open(profile, sitting)


# The rooms a park map holds for this profile, as activity site specs (park_map.gd's shape plus
# `secret`, the room id). [] while the secrets are shut.
static func room_sites(map_id: String, profile, sitting := false) -> Array:
	var out := []
	if not open(profile, sitting):
		return out
	for id in ROOMS:
		var r: Dictionary = ROOMS[id]
		if r["map"] == map_id:
			out.append({"id": "cracked_cache", "row": id, "site": r["site"], "secret": id,
				"at": Vector2(float(r["at"][0]), float(r["at"][1])), "pay": ROOM_PAY.duplicate(true)})
	return out


# Every secret this profile holds, for the save test and the camp: room ids, tune ids, paint ids.
static func held(profile, sitting := false) -> Dictionary:
	var out := {"rooms": [], "tunes": [], "paints": []}
	if open(profile, sitting):
		out["rooms"] = ROOMS.keys()
		out["tunes"] = [TUNE]
	for pilot in PAINTS:
		if profile != null and profile.has_cosmetic(PAINTS[pilot]):
			out["paints"].append(PAINTS[pilot])
	return out


# The sitting opens the paints in memory only (its profile never saves, game.gd sitting_save_guard).
static func open_for_sitting(profile) -> void:
	if profile == null:
		return
	for pilot in PAINTS:
		profile.unlock_cosmetic(PAINTS[pilot])


# The field finds a park map holds this run, as activity site specs (room_sites' shape, plus
# `find`, the find id, and `kind`). Every profile gets them; `seed` picks each one's spot.
static func find_sites(map_id: String, seed: int) -> Array:
	var out := []
	for id in FINDS:
		var f: Dictionary = FINDS[id]
		if f["map"] != map_id:
			continue
		var spot: Dictionary = find_spot(id, seed)
		out.append({"id": "cracked_cache", "row": id, "site": spot["site"], "find": id, "kind": f["kind"],
			"at": Vector2(float(spot["at"][0]), float(spot["at"][1])), "pay": FIND_PAY.duplicate(true),
			"face": Vector2(float(spot["face"][0]), float(spot["face"][1])).normalized()})
	return out


# The spot a find stands on for a run seed: the same seed, the same spot.
static func find_spot(id: String, seed: int) -> Dictionary:
	var spots: Array = FINDS[id]["spots"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [id, seed])
	return spots[rng.randi_range(0, spots.size() - 1)]


# A world's secret count for the camp: how many of its WORLD_CODEX rows `known` (a codex id ->
# bool callable, the codex's own known()) says the profile has found.
static func world_count(world: int, known: Callable) -> Dictionary:
	var ids: Array = WORLD_CODEX.get(world, [])
	var got := 0
	for id in ids:
		if known.call(id):
			got += 1
	return {"world": world, "name": WORLD_NAMES.get(world, "World %d" % world), "found": got, "total": ids.size()}


# A boss rout: under the clock, the profile holds the door for the run after this one. True when
# it marked it. Both stats only ever rise, as profile.gd's save merge keeps the larger value.
static func note_rout(profile, boss: String, run_time: float) -> bool:
	if profile == null or boss != DOOR["boss"] or run_time >= float(DOOR["under_s"]):
		return false
	profile.set_stat(DOOR_FOR, profile.stat(DOOR_RUNS) + 1.0)
	return true


# A new run started: it is the one a rout in the run before opened the door for.
static func roll_door(profile) -> void:
	if profile != null:
		profile.add_stat(DOOR_RUNS)


static func door_open(profile) -> bool:
	return profile != null and profile.stat(DOOR_FOR) >= 1.0 and profile.stat(DOOR_FOR) == profile.stat(DOOR_RUNS)


# The timed door a park map holds this run, as an activity site spec (find_sites' shape, with `door`).
static func door_sites(map_id: String, profile) -> Array:
	if DOOR["map"] != map_id or not door_open(profile):
		return []
	return [{"id": "cracked_cache", "row": "timed_door", "site": DOOR["site"], "door": true,
		"at": Vector2(float(DOOR["at"][0]), float(DOOR["at"][1])), "pay": FIND_PAY.duplicate(true),
		"face": Vector2(float(DOOR["face"][0]), float(DOOR["face"][1])).normalized()}]
