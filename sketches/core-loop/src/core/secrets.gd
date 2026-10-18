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
