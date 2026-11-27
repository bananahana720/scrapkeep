extends RefCounted


const UNLOCK := "first_win"
const LOG_WORD_CAP := 40
const PilotStory := preload("res://src/core/pilot_story.gd")

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

const STAGE_ROOMS := {
	"spillway_dam_vault": {
		"world": 1, "map": "park_dam", "site": "east_abutment", "at": [152, 608], "skill": "momentum",
		"name": "East Abutment Vault",
		"log": "Maintenance tally: east abutment locker bolted shut after the high-water shift. Wrenches still hung by size. Nobody logged the last check-in.",
	},
	"dig_cenote_alcove": {
		"world": 2, "map": "park_sinkhole", "site": "west_cenote", "at": [-296, -232], "skill": "abilities",
		"name": "Cenote Core Alcove",
		"log": "Bore log, deep shift: cut an alcove into the west cenote wall to cool the lamps. Left two chalk marks and a spare lamp wick.",
	},
	"highdraft_storm_bunker": {
		"world": 3, "map": "park_crown", "site": "crown_apron", "at": [-144, 712], "skill": "grapple",
		"name": "Crown Storm Bunker",
		"log": "Wind watch: storm shelter bolted under the crown apron when the anemometer snapped. Door latch still holds. Somebody left the thermos capped.",
	},
}

const TUNE := "secret-after-hours"

const PAINTS := {
	"pylon_engineer": "paint_sable_overtime",
	"runner_gunner": "paint_rivet_inside_job",
	"demolitions_caster": "paint_kest_knock_back",
	"tarn": "paint_tarn_unissued",
	"tally": "paint_tally_carbon",
	"remembered_cannon": "paint_cannon_velvet",
}
const PAINT_ROWS := {
	"pylon_engineer": "secret_paint_sable",
	"runner_gunner": "secret_paint_rivet",
	"demolitions_caster": "secret_paint_kest",
	"tarn": "secret_paint_tarn",
	"tally": "secret_paint_tally",
	"remembered_cannon": "secret_paint_cannon",
}
const ROOM_PAY := {"rarities": ["rare"]}

const FIND_KINDS := ["crack", "radio"]
const DRIP_HEAR_M := 22.0
const RADIO_HEAR_M := 40.0
const FIND_PAY := {"rarities": ["rare"]}

const FINDS := {
	"dam_turbine_hall": {
		"world": 1, "map": "park_dam", "kind": "crack",
		"spots": [{"site": "service_ledge", "at": [-176, 494], "face": [-1, -1]}, {"site": "eye_fin_east", "at": [20, 140], "face": [1, -3]}],
		"name": "Turbine Hall Seep",
		"log": "Maintenance note: the old turbine hall was bricked up after the flood. The bricks were not asked. Water found the way first.",
		"codex": {"id": "spillway_turbine_seep", "category": "world", "name": "Where the Water Got In",
			"hint": "A wet streak on dry rock. Water knows where the walls are thin.",
			"clue": "A seeping, dripping cracked face on the service ledge or the east eye fin + a ram at speed",
			"text": "Follow the seep. Behind the dam's cracked faces the crew walled up rooms the flood had already found."},
	},
	"dam_shift_radio": {
		"world": 1, "map": "park_dam", "kind": "radio",
		"spots": [{"site": "dome_18", "at": [-156, -524], "face": [1, -1]}, {"site": "slot_fin_far", "at": [44, -244], "face": [2, -1]}],
		"name": "Night Shift Radio",
		"log": "Night shift: radio left on in the spare room so the dam has company. Station went off air years ago. Radio did not.",
		"codex": {"id": "spillway_shift_radio", "category": "world", "name": "Still On Air",
			"hint": "Music where nobody works any more. Roll toward it.",
			"clue": "A tune through a cracked wall among the shelf domes or at the north tip of the far slot fin + a ram at speed",
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

const WARDS := {
	"dam_ledge_ward": {"site": "lobber_ledge", "at": [-185, 455]},
	"flume_pond_ward": {"site": "weir_pond", "at": [-650, -690]},
}

const PLATES := {
	"dam_era_survey_deck": "lore.park_dam.note.plumb",
	"dam_era_gate_flags": "lore.park_dam.note.gate_log",
	"ancient_eye_marks": "lore.park_dam.note.eye",
	"dam_era_incline_tally": "lore.park_dam.note.incline",
	"dam_era_haul_sign": "lore.park_dam.note.fleet",
	"dam_dedication_plaque": "lore.park_dam.note.apron",
	"dam_era_flume_survey": "lore.park_flume.note.weir",
	"dam_era_trestle_tag": "lore.park_flume.note.bents",
	"dam_era_siphon_plate": "lore.park_flume.note.siphon",
	"dam_era_rim_milepost": "lore.park_flume.note.milepost",
	"dam_era_boom_tag": "lore.park_flume.note.boom",
	"dam_era_wasteway_gauge": "lore.park_flume.note.wasteway",
	"dam_era_annex_dial": "lore.park_flume.note.annex",
	"headhouse_relic_plate": "lore.park_flume.note.drum",
}

const PLATE_NUDGES := {
	"dam_era_gate_flags": [-4, 3],
	"dam_dedication_plaque": [0, -2.25],
	"ancient_eye_marks": [1.5, 0],
}

const WORLD_CODEX := {1: ["spillway_turbine_seep", "spillway_shift_radio", "spillway_flume_seep", "spillway_crew_radio",
	"spillway_gallery_cache", "flume_weir_cache", "flume_grade_cache", "spillway_clock_door"]}
const WORLD_NAMES := {1: "Spillway", 2: "The Dig", 3: "The Highdraft"}


static func all_rooms() -> Dictionary:
	var out: Dictionary = ROOMS.duplicate(true)
	for id in STAGE_ROOMS:
		out[id] = STAGE_ROOMS[id].duplicate(true)
	return out


static func room_by_id(id: String) -> Dictionary:
	if ROOMS.has(id):
		return ROOMS[id]
	return STAGE_ROOMS.get(id, {})


static func shut_paint(id: String, profile) -> bool:
	return PAINTS.values().has(id) and not (profile != null and profile.has_cosmetic(id))


static func shut_row(id: String, profile) -> bool:
	return PAINT_ROWS.values().has(id) and not (profile != null and profile.earned(id))


static func open(profile, sitting := false) -> bool:
	return sitting or (profile != null and profile.earned(UNLOCK))


static func tune_open(profile, sitting := false) -> bool:
	return open(profile, sitting)


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


static func stage_room_sites(map_id: String, profile, sitting := false) -> Array:
	var out := []
	if not open(profile, sitting):
		return out
	var combined := all_rooms()
	for id in combined:
		var r: Dictionary = combined[id]
		if r["map"] == map_id:
			out.append({"id": "cracked_cache", "row": id, "site": r["site"], "secret": id,
				"at": Vector2(float(r["at"][0]), float(r["at"][1])), "pay": ROOM_PAY.duplicate(true)})
	return out


static func held(profile, sitting := false) -> Dictionary:
	var out := {"rooms": [], "tunes": [], "paints": []}
	if open(profile, sitting):
		out["rooms"] = ROOMS.keys()
		out["tunes"] = [TUNE]
	for pilot in PAINTS:
		if profile != null and profile.has_cosmetic(PAINTS[pilot]):
			out["paints"].append(PAINTS[pilot])
	return out


static func open_for_sitting(profile) -> void:
	if profile == null:
		return
	for pilot in PAINTS:
		profile.unlock_cosmetic(PAINTS[pilot])


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


static func ward_sites(park: Dictionary) -> Array:
	var rows := {}
	for row: Dictionary in park.get("park_rows", []):
		rows[String(row["id"])] = true
	var out := []
	for id in WARDS:
		var w: Dictionary = WARDS[id]
		if rows.has(w["site"]):
			out.append({"id": id, "site": w["site"], "at": Vector2(float(w["at"][0]), float(w["at"][1]))})
	return out


static func plate_sites(park: Dictionary) -> Array:
	var out := []
	var landmark: Dictionary = park.get("landmark", {})
	var fragment := String(landmark.get("fragment", ""))
	if PLATES.has(fragment):
		var dock: Array = landmark.get("bay_dock", {}).get("at", landmark.get("beacon", landmark.get("at", [0, 0])))
		out.append({"fragment": fragment, "note": PLATES[fragment], "row": String(landmark.get("id", "")),
			"at": Vector2(float(dock[0]), float(dock[1])) + _nudge(fragment)})
	for row: Dictionary in park.get("park_rows", []):
		fragment = String(row.get("fragment", ""))
		if PLATES.has(fragment):
			out.append({"fragment": fragment, "note": PLATES[fragment], "row": String(row["id"]),
				"at": Vector2(float(row["at"][0]), float(row["at"][1])) + _nudge(fragment)})
	return out


static func _nudge(fragment: String) -> Vector2:
	var nudge: Array = PLATE_NUDGES.get(fragment, [0, 0])
	return Vector2(float(nudge[0]), float(nudge[1]))


static func find_spot(id: String, seed: int) -> Dictionary:
	var spots: Array = FINDS[id]["spots"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [id, seed])
	return spots[rng.randi_range(0, spots.size() - 1)]


static func world_count(world: int, known: Callable) -> Dictionary:
	var ids: Array = WORLD_CODEX.get(world, [])
	var got := 0
	for id in ids:
		if known.call(id):
			got += 1
	return {"world": world, "name": WORLD_NAMES.get(world, "World %d" % world), "found": got, "total": ids.size()}


static func note_rout(profile, boss: String, run_time: float) -> bool:
	if profile == null or boss != DOOR["boss"] or run_time >= float(DOOR["under_s"]):
		return false
	profile.set_stat(DOOR_FOR, profile.stat(DOOR_RUNS) + 1.0)
	return true


static func roll_door(profile) -> void:
	if profile != null:
		profile.add_stat(DOOR_RUNS)


static func door_open(profile) -> bool:
	return profile != null and profile.stat(DOOR_FOR) >= 1.0 and profile.stat(DOOR_FOR) == profile.stat(DOOR_RUNS)


static func door_sites(map_id: String, profile) -> Array:
	if DOOR["map"] != map_id or not door_open(profile):
		return []
	return [{"id": "cracked_cache", "row": "timed_door", "site": DOOR["site"], "door": true,
		"at": Vector2(float(DOOR["at"][0]), float(DOOR["at"][1])), "pay": FIND_PAY.duplicate(true),
		"face": Vector2(float(DOOR["face"][0]), float(DOOR["face"][1])).normalized()}]


static func patch_trail() -> Dictionary:
	return PilotStory.PATCH_TRAIL


static func patch_wire_sites(map_id: String, run_seed: int, codex = null) -> Array:
	var out := []
	var known_fn := Callable(codex, "known") if codex != null and codex.has_method("known") else Callable()
	for node_id in PilotStory.PATCH_TRAIL:
		var node: Dictionary = PilotStory.PATCH_TRAIL[node_id]
		if String(node.get("kind", "")) != "wire" or String(node.get("map", "")) != map_id:
			continue
		if not PilotStory.entry_visible(String(node_id), known_fn):
			continue
		var spot := PilotStory.patch_spot(String(node_id), run_seed)
		if spot.is_empty():
			continue
		var at_arr: Array = spot.get("at", [0, 0])
		out.append({
			"id": "cracked_cache", "row": String(node_id), "site": String(spot.get("site", "")),
			"patch_wire": String(node_id), "at": Vector2(float(at_arr[0]), float(at_arr[1])),
			"pay": FIND_PAY.duplicate(true),
		})
	return out
