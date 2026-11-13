extends RefCounted

# The park file's rules (design-v3/PARK.md section 2, checks in 2.10). validate() returns one
# error per broken rule as {"id": row id, "rule": rule key, "detail": text}, so a test or a
# tool names the row to fix. An empty array means the park loads.
#
# Rule keys: missing, type, enum, duplicate, reference, waymarks, mounting, pack, family,
# lead_floor, water_depth, handling, recipe, home_landform, guardrail, line, music_layer.

const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Director := preload("res://src/world/director.gd")
const Rogue := preload("res://src/combat/rogue.gd")

const SCHEMA := "scrapkeep-park/1"

const TIMES := ["dawn", "morning", "noon", "afternoon", "golden", "dusk"]
const ELEMENTS := ["half_pipe", "flow_line", "grind_line", "rail", "bowl", "terrace", "tunnel", "drop",
	"flooded_cavern", "elevated_line", "ledge", "crater_bowl", "sky_island", "kicker", "bank",
	"anchor_field", "ground"]
const LANDFORMS := ["slot_canyon", "arroyo", "dry_wash", "slickrock", "canal", "flume", "penstock", "pipeline",
	"dam_face", "open_pit", "tailings_bench", "headframe", "lava_tube", "adit", "shaft", "spillway_tunnel",
	"sinkhole", "cenote_pool", "flooded_shaft", "cliff_dwelling", "mesa_rim", "butte", "spire",
	"hoodoo_field", "saguaro_stand", "travertine_terrace", "horseshoe_bend", "river_canyon", "gooseneck",
	"meteor_crater", "sky_island"]
# net_weaver: the Highdraft's animals who string the nets, posts and balloon lifts (Andrew's "Now, light" tap,
# 2026-10-17; stage 6 page section 15 asked for their id).
const SOCIETIES := ["none", "hohokam", "ancestral_puebloan", "mining", "dam_era", "fleet", "ancient", "net_weaver"]
const VERBS := ["roll", "pump", "grind", "launch", "drop", "swing", "glide", "lift", "bank", "slam", "cast"]
const STAMPS := ["", "wash", "channel", "ridge", "mesa", "butte", "spire", "bowl", "terrace", "crater",
	"sinkhole", "ramp", "plateau"]
const BUDGETS := ["landform", "park_large", "hero_landmark", "detail"]
const LANDMARK_KINDS := ["dam", "penstock_tower", "headframe", "sinkhole", "sky_island", "spire"]
const LIGHTS := ["ancient_beam", ""]

# Each event kind allows one family (section 5).
const EVENT_FAMILY := {
	"flood_fill": "natural", "drain": "natural", "cave_in": "natural", "collapse": "natural",
	"impact": "natural", "flash_flood": "natural", "lightning": "natural",
	"fleet_landing": "fleet", "lift_cage": "fleet", "zipline_drop": "fleet", "machine_eruption": "ancient",
	"boiler_burst": "industrial", "reactor_blow": "industrial", "sluice_surge": "industrial",
}
const EVENT_KINDS := ["flood_fill", "drain", "cave_in", "collapse", "impact", "flash_flood", "lightning",
	"fleet_landing", "machine_eruption", "boiler_burst", "reactor_blow", "lift_cage", "zipline_drop", "sluice_surge"]
const FAMILIES := ["natural", "fleet", "ancient", "industrial"]
# Telegraph floors (section 5 rule 1): a hazard with no ground change, a ground change, and a
# Fleet landing or an ancient eruption. A row changes the ground when its kind reshapes the
# ground or water, or when its effect swaps in an overlay.
const LEAD_HAZARD_S := 3.0
const LEAD_GROUND_S := 5.0
const LEAD_ARRIVAL_S := 8.0
const GROUND_KINDS := ["flood_fill", "drain", "cave_in", "collapse", "impact", "flash_flood"]
const ARRIVAL_FAMILIES := ["fleet", "ancient"]
# Section 5 rule 2: event water is at most the pool depth a ball rolls out of. A collapse's or a
# cave-in's depth_m is a cut in the ground, not water, so the cap reads only water rows.
const MAX_EVENT_WATER_M := 1.2
const WATER_KINDS := ["flood_fill", "flash_flood", "drain"]
const PHASES := ["engaged", "stagger", "chunk_1", "chunk_2", "chunk_3", "broken"]
const MAX_CLOCK_TIER := 4
const VESSELS := ["drill_barge", "dropship"]

const HOME_BREAK := ["ram", "slam", "smash", "damage"]

# The keys contraptions.gd reads for each kind (its _build_* and reset()).
const CONTRAPTION_KEYS := {
	"barge": ["a", "b", "size", "travel", "dwell", "offset"],
	"lift": ["at", "radius", "rise", "charge", "offset"],
	"launcher": ["style", "at", "radius", "target", "floor", "min_flight", "charge"],
	"cable": ["from", "to", "radius", "floor"],
	"valve": ["at", "door"],
	"cracked_wall": ["at", "size", "turn"],
	"thermal": ["at", "radius", "height"],
	"cinder": ["strips", "drag"],
	"glaze": ["strips", "push", "cap"],
}
const CONTRAPTION_KINDS := ["barge", "lift", "launcher", "cable", "valve", "cracked_wall", "thermal", "cinder", "glaze"]
const CONTRAPTION_RECIPES := ["", "gauge", "geyser_vent", "cannon", "trebuchet", "lift_platform", "barge"]

# Activity presentation uses an ACTIVITY_ROWS key or the kind's existing cue.view alias.
const ACTIVITY_KINDS := ["enemy_camp", "surge_run", "ambush_altar", "cracked_cache", "hauler_bounty", "movement_course", "arena", "elite_arena", "objective_limit", "round_arena", "ambush", "scattered_marks", "hold_the_relay"]
const WEATHER_KINDS := ["clear", "monsoon", "dust_squall", "heat_shimmer", "cave_mist", "cloud_deck", "thunderstorm"]

# The park recipe registry until KC0 folds the park recipes into assets/registry.json: the
# starting recipe ids of section 4 and the six hero landmarks. Ids in the asset registry count too.
const RECIPES := [
	"half_pipe_concrete", "slot_canyon_flow", "wash_dropin_lip",
	"canal_lip", "flume_span", "penstock_run", "pipeline_rail",
	"bench_coping", "tailings_lip", "pit_haul_ramp", "pit_haul_lane",
	"lava_tube_run", "adit_mouth", "shaft_drop", "spillway_tunnel",
	"cenote_pool", "flooded_shaft", "cavern_shell",
	"cliff_dwelling_row", "mesa_rim_ledge", "viga_pivot",
	"crater_event", "crater_ending",
	"mesa_lip_kicker", "net_deck", "floating_island",
	"landmark_dam", "landmark_penstock_tower", "landmark_headframe", "landmark_sinkhole",
	"landmark_sky_island", "landmark_spire",
	"anchor_hoodoo", "anchor_basalt", "anchor_timber", "anchor_saguaro", "anchor_cairn",
	"ore_bin", "ore_bin_row", "timber_portal",
	"lava_wash", "lava_wash_short", "gallery_wash", "drift_wash",
	"skylight_lip", "tube_mouth_lip", "breach_lip", "miners_cap", "great_room_deck", "haulage_bed",
]
const GREYBOX := "greybox:"
# The ground scatter dresses the row (park_recipes.gd SENSOR_ONLY, with LANDMARK).
const SCATTER := "scatter"
const REGISTRY_PATH := "res://assets/registry.json"

# The real-culture guardrail (section 4): these rows house no home, carry only ref_ fragments,
# and are never the site of a ground-changing or destructive event.
const GUARDED_SOCIETIES := ["hohokam", "ancestral_puebloan"]
const GUARDED_EVENT_KINDS := ["cave_in", "collapse", "impact", "machine_eruption", "fleet_landing", "lift_cage", "zipline_drop",
	"boiler_burst", "reactor_blow"]
const REF_PREFIX := "ref_"

# One Warden kind per world after KF0 (section 7), and each kind's two mountings. The stage rows
# in alpha_defs.gd keep the old families until KF0 lands, so the kind is read by world here.
const WORLD_KINDS := {1: "reactor", 2: "swarm", 3: "mind"}
const WORLD_ANCIENTS := {1: "reactor_relic", 2: "swarm_remnant", 3: "mind_hand"}
# Packs the park stage rows add at KD0 (src/core/park_defs.gd, not yet written): the stage 6
# page's crown_hands (design-v3/park/stages/6-park_crown.md section 7). KD0 moves them to its rows.
const KD0_PACKS := {6: ["crown_hands"]}
const MOUNTINGS := {
	"reactor": ["dam_face", "flume"],
	"swarm": ["headframe", "sinkhole"],
	"mind": ["under_island", "spires"],
}
# The stage each park map replaces (section 6); the fixture borrows stage 1's row.
const MAP_STAGE := {
	"park_dam": 1, "park_flume": 2, "park_pit": 3, "park_sinkhole": 4, "park_islands": 5, "park_crown": 6,
	"park_test": 1,
}

const DROP_IN := "drop_in"
const LANDMARK := "landmark"
const MIN_WAYMARKS := 3
const MAX_WAYMARKS := 5

# Pilot lines (section 8, "The lines").
const PILOTS := ["sable", "rivet", "kest", "tarn", "tally", "cannon"]
const LINE_BAND := "PARK.md section 8"

const TOP_FIELDS := {
	"schema": "s", "map": "s", "size_m": "n", "time_of_day": TIMES, "spawn": "o", "play_rect": "v4",
	"landmark": "o", "waymarks": "a", "routes": "a", "park_rows": "a", "event_rows": "a",
	"home_rows": "a", "contraption_rows": "a", "weather_rows": "a", "activity_rows": "a",
}
const SPAWN_FIELDS := {"at": "v2", "heading_deg": "n"}
# Optional at the top (wave 36, ruling cv): how the stage is left ("exit") and entered ("arrives"), and where its
# own frame sits in the world 1 atlas. The exit's place and heading are the middle gate slot's, the arrival's are
# the spawn's, so ParkMap.handover() reads each fact once. speed_cruise is a share of cruise speed. HANDOVER_PAIRS
# says which arrival kind an exit kind pairs with (a launch lands, a slide is a slide).
const HANDOVER_PAIRS := {"launch": "land", "slide": "slide", "door": "door", "drop": "drop"}
const HANDOVER_OPENS := ["warden_broken", "boss_defeated"]
const ATLAS_FIELDS := {"origin": "v2", "heading_deg": "n"}
const EXIT_FIELDS := {"kind": ["launch", "slide", "door", "drop"], "speed_cruise": "n", "opens": HANDOVER_OPENS}
const ARRIVES_FIELDS := {"kind": ["land", "slide", "door", "drop"], "speed_cruise": "n", "from": "s"}
const PARK_FIELDS := {
	"id": "s", "element": ELEMENTS, "landform": LANDFORMS, "society": SOCIETIES, "at": "v2", "y": "n?",
	"size": "v3", "yaw_deg": "n", "verb": VERBS, "ride_fact": "s", "home": "s", "recipe": "s",
	"stamp": STAMPS, "hole": "b", "budget": BUDGETS, "routes": "a", "fragment": "s",
}
# Optional on a park row, absent on every row that places as before: "seat" seats a GLB recipe on the ground at its
# entry and exit (park_recipes.gd seat_fit); "tile" repeats a shorter GLB recipe end to end, each copy seated on the
# ground at its own ends (park_recipes.gd tile_fit); "drape" stands a ground-conforming GLB on the seat of its stamp
# (park_recipes.gd fits_drape, seat), with no `y`, so the graph reads no deck.
const FITS := ["seat", "tile", "drape"]
# Optional on a park row: "music_layer" names a layer_* WORLD_ROWS kind its ride sensor publishes on entry, beside its
# ride fact; a row with recipe "" gets a listening sensor of its footprint and nothing else (park_recipes.gd
# place_layer). The music bakes each layer's sound_next; until then its stand-in sound plays.
const MUSIC_LAYER_PREFIX := "layer_"
# Optional at the top: "rescue_rows", the stage's caged pilots (rescue_site.gd). pilot is the ClassDef id sitting in
# the cage, so who is rescued is data; quest is what rescue_completed carries (the achievement rows key on it).
const RESCUE_FIELDS := {"id": "s", "site": "s", "at": "v2", "face": "v2", "quest": "s", "pilot": "s", "prompt": "s"}
# Optional at the top: "survival_rows", the places a survival count can stand (survival_count.gd FORMS names the
# form; activities.gd builds one row of a form a run, and only with --stocktake=on). They are not activity rows, so
# nothing that reads the stage's activities sees them.
const SURVIVAL_FIELDS := {"id": "s", "form": ["yard", "muster", "ring"], "at": "v2"}
const LANDMARK_FIELDS := {
	"id": "s", "kind": LANDMARK_KINDS, "at": "v2", "size": "v3", "yaw_deg": "n", "recipe": "s",
	"budget": ["hero_landmark"], "sight_top": "v3", "sight_share": "n", "beacon": "v2", "reach_m": "n",
	"warden": "o", "bay_dock": "o", "gate_slots": "a", "light": LIGHTS, "music": "s", "fragment": "s",
}
const WARDEN_FIELDS := {"mounting": "s", "anchor": "v3", "path": "a", "hardpoints": "n"}
const SLOT_FIELDS := {"at": "v2", "facing_deg": "n"}
const EVENT_FIELDS := {
	"id": "s", "kind": EVENT_KINDS, "family": FAMILIES, "site": "s", "trigger": "o", "weight": "n",
	"telegraph": "o", "live_s": "n", "effect": "o", "route_change": "o", "hold_clear_m": "n",
	"cooldown_s": "n", "once": "b", "music_cue": "o",
}
const TELEGRAPH_FIELDS := {"lead_s": "n", "form": "s", "on_bar": "b"}
const ROUTE_CHANGE_FIELDS := {"closes": "a", "opens": "a"}
const CUE_FIELDS := {"telegraph": "s", "land": "s"}
const HOME_FIELDS := {
	"id": "s", "enemy": "s", "site": "s", "landform": LANDFORMS, "advantage": "s", "counter": "s",
	"reinforce": "o", "break": "o", "stops_kind": "b", "dormant": "b",
}
const REINFORCE_FIELDS := {"from_tier": "n", "every_s": "n", "max_alive": "n", "pack": "s"}
const BREAK_FIELDS := {"by": HOME_BREAK, "hp": "n", "scrap": "n"}
const CONTRAPTION_FIELDS := {"id": "s", "kind": CONTRAPTION_KINDS, "site": "s", "recipe": CONTRAPTION_RECIPES}
const WEATHER_FIELDS := {
	"id": "s", "kind": WEATHER_KINDS, "trigger": "o", "lead_s": "n", "live_s": "n", "gap_s": "n",
	"fog": "o", "sky": "s", "sound": "s", "music_layer": "s", "event_odds": "o", "handling": "s",
}
const FOG_FIELDS := {"density": "n", "color": "s"}
const ACTIVITY_FIELDS := {"id": "s", "activity": ACTIVITY_KINDS, "site": "s", "at": "v2", "pack": "a", "pay": "o"}
const ROUTE_FIELDS := {"id": "s", "from": "s", "to": "s", "via": "a"}

static var _registry_ids: Dictionary = {}
static var _registry_read := false


# The stage row facts the park cross-checks: stage, world, Warden kind, and the world's pack ids.
# Empty for a map with no stage.
static func stage_context(map_id: String) -> Dictionary:
	var stage := int(MAP_STAGE.get(map_id, 0))
	if stage == 0:
		return {}
	var world := int(AlphaDefs.of(stage)["world"])
	var packs := []
	for row in AlphaDefs.DEFS:
		if int(row["world"]) != world:
			continue
		for pack in row["packs"]:
			if not packs.has(pack["id"]):
				packs.append(pack["id"])
		if not packs.has(row["elite"]["id"]):
			packs.append(row["elite"]["id"])
		for pack in KD0_PACKS.get(int(row["stage"]), []):
			if not packs.has(pack):
				packs.append(pack)
	# The director's ancient pack, named by the world's ancient kind.
	packs.append(WORLD_ANCIENTS[world])
	return {"stage": stage, "world": world, "warden_family": WORLD_KINDS[world], "packs": packs}


# Parse a park or line file. {"data": Dictionary, "errors": Array}; a file that is not a JSON
# object is one "parse" error on the id "file".
static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"data": {}, "errors": [_error("file", "parse", "no file at " + path)]}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {"data": {}, "errors": [_error("file", "parse", path + " is not a JSON object")]}
	return {"data": parsed, "errors": []}


static func load_park(path: String, ctx: Dictionary = {}) -> Dictionary:
	var read := read_file(path)
	if not read["errors"].is_empty():
		return read
	return {"data": read["data"], "errors": validate(read["data"], ctx)}


static func describe(errors: Array) -> String:
	var lines := PackedStringArray()
	for e in errors:
		lines.append("%s [%s] %s" % [e["id"], e["rule"], e["detail"]])
	return "; ".join(lines)


static func validate(park: Dictionary, ctx: Dictionary = {}) -> Array:
	var out := []
	if not _fields(out, "park", park, TOP_FIELDS):
		return out
	if park["schema"] != SCHEMA:
		_add(out, "schema", "enum", "schema is %s, expected %s" % [park["schema"], SCHEMA])
	if ctx.is_empty():
		ctx = stage_context(park["map"])
	if ctx.is_empty():
		_add(out, "map", "reference", "no stage row for map " + str(park["map"]))
	_fields(out, "spawn", park["spawn"], SPAWN_FIELDS)
	for key in ["atlas", "exit", "arrives"]:
		if park.has(key):
			_fields(out, key, park[key], {"atlas": ATLAS_FIELDS, "exit": EXIT_FIELDS, "arrives": ARRIVES_FIELDS}[key])

	var rows := _rows(out, park, "park_rows", PARK_FIELDS)
	var events := _rows(out, park, "event_rows", EVENT_FIELDS)
	var homes := _rows(out, park, "home_rows", HOME_FIELDS)
	var contraptions := _rows(out, park, "contraption_rows", CONTRAPTION_FIELDS)
	var weather := _rows(out, park, "weather_rows", WEATHER_FIELDS)
	var activities := _rows(out, park, "activity_rows", ACTIVITY_FIELDS)
	var routes := _rows(out, park, "routes", ROUTE_FIELDS)
	var rescues := _rows(out, park, "rescue_rows", RESCUE_FIELDS) if park.has("rescue_rows") else {}
	if park.has("survival_rows"):
		_rows(out, park, "survival_rows", SURVIVAL_FIELDS)

	var landmark: Dictionary = park["landmark"]
	_landmark(out, landmark, ctx)

	# Places a route or a waymark may name: the drop-in, the landmark, a park row or an activity.
	var places := {DROP_IN: true, LANDMARK: true}
	for id in rows:
		places[id] = true
	for id in activities:
		places[id] = true

	_waymarks(out, park["waymarks"], places)
	for id in routes:
		var route: Dictionary = routes[id]
		for end in ["from", "to"]:
			if not places.has(route[end]):
				_add(out, id, "reference", "route %s %s does not resolve" % [end, route[end]])
		for via in route["via"]:
			if not rows.has(via):
				_add(out, id, "reference", "route via %s is no park row" % via)

	for id in rows:
		_park_row(out, id, rows[id], homes, routes, events)
	for id in events:
		_event_row(out, id, events[id], rows, homes, routes, activities)
	for id in homes:
		_home_row(out, id, homes[id], rows, ctx)
	for id in contraptions:
		var row: Dictionary = contraptions[id]
		_site(out, id, row, rows)
		for key in CONTRAPTION_KEYS[row["kind"]]:
			if not row.has(key):
				_add(out, id, "missing", "%s contraption needs %s" % [row["kind"], key])
	for id in weather:
		_weather_row(out, id, weather[id], events)
	for id in activities:
		_site(out, id, activities[id], rows)
		_activity_pack(out, id, activities[id])
		# A surge course runs down a park route's rows (surge_course.gd path).
		if activities[id]["activity"] == "surge_run" and not routes.has(activities[id].get("route")):
			_add(out, id, "reference", "a surge_run names a park route, not %s" % str(activities[id].get("route")))
		if activities[id].has("face") and not (_typed(activities[id]["face"], "v2") and _v2_len(activities[id]["face"]) > 0.0):
			_add(out, id, "type", "face %s is not a nonzero [x, z]" % str(activities[id]["face"]))
		if activities[id].has("bar") and not (activities[id]["activity"] == "cracked_cache" and activities[id]["bar"] in ["blazing"]):
			_add(out, id, "type", "bar %s is not blazing on a cracked_cache" % str(activities[id]["bar"]))
		if activities[id].has("extra") and activities[id]["extra"] != "card_2":
			_add(out, id, "type", "extra %s is not card_2" % str(activities[id]["extra"]))
		if activities[id].has("alts"):
			_activity_alts(out, id, activities[id])
	for id in rescues:
		_site(out, id, rescues[id], rows)
		if String(rescues[id]["quest"]) == "":
			_add(out, id, "missing", "a rescue names its quest")
		var pilot := String(rescues[id]["pilot"])
		if pilot != "" and ClassDef.by_id(pilot) == null:
			_add(out, id, "reference", "pilot %s is no class id" % pilot)
	return out


# Pilot lines for one stage (assets/park/<map_id>/lines.json) against its park file: every line
# starts at drop_in, names the stage's waymarks in order, ends at landmark, and its bar points
# at the section 8 bands.
static func validate_lines(lines: Dictionary, park: Dictionary) -> Array:
	var out := []
	if not _fields(out, "lines", lines, {"map": "s", "stage": "n", "pilots": "o", "floor": "o"}):
		return out
	if lines["map"] != park.get("map"):
		_add(out, "map", "reference", "lines are for %s, park is %s" % [lines["map"], park.get("map")])
	var waymarks: Array = park.get("waymarks", [])
	for pilot in PILOTS:
		if not lines["pilots"].has(pilot):
			_add(out, pilot, "missing", "no line for pilot " + pilot)
	for pilot in lines["pilots"]:
		if not PILOTS.has(pilot):
			_add(out, pilot, "enum", "no pilot named " + str(pilot))
			continue
		var line = lines["pilots"][pilot]
		if not line is Dictionary or not _fields(out, pilot, line, {"waypoints": "a", "bar": "o"}):
			continue
		_line_path(out, pilot, line["waypoints"], waymarks)
		var bar: Dictionary = line["bar"]
		if not _fields(out, pilot, bar, {"band": "s", "airborne_share": "v2"}):
			continue
		if bar["band"] != LINE_BAND:
			_add(out, pilot, "line", "bar.band is %s, expected %s" % [bar["band"], LINE_BAND])
	if _fields(out, "floor", lines["floor"], {"waypoints": "a"}):
		_line_path(out, "floor", lines["floor"]["waypoints"], waymarks)
		# Optional: the floor line's scrap, laid to the beat (park_map.gd scrap_trail).
		if lines["floor"].has("scrap") and _fields(out, "floor.scrap", lines["floor"]["scrap"], {"spacing_m": "n", "phrase": "n", "rest": "n"}):
			var scrap: Dictionary = lines["floor"]["scrap"]
			var whole := float(scrap["phrase"]) == floorf(float(scrap["phrase"])) and float(scrap["rest"]) == floorf(float(scrap["rest"]))
			if float(scrap["spacing_m"]) <= 0.0 or float(scrap["phrase"]) < 1.0 or float(scrap["rest"]) < 0.0 or not whole:
				_add(out, "floor.scrap", "range", "spacing_m must be over 0, phrase a whole number from 1 and rest a whole number from 0")
	return out


static func _line_path(out: Array, id: String, waypoints: Array, waymarks: Array) -> void:
	var named := []
	for point in waypoints:
		if point is String:
			named.append(point)
			if not waymarks.has(point):
				_add(out, id, "reference", "waypoint %s is no waymark" % point)
		elif not _is_vec(point, 2):
			_add(out, id, "type", "waypoint %s is neither a waymark id nor [x, z]" % str(point))
	if waypoints.is_empty() or str(waypoints[0]) != DROP_IN:
		_add(out, id, "line", "line does not start at " + DROP_IN)
	if waypoints.is_empty() or str(waypoints[-1]) != LANDMARK:
		_add(out, id, "line", "line does not end at " + LANDMARK)
	if named != waymarks:
		_add(out, id, "line", "line names %s, the waymarks in order are %s" % [str(named), str(waymarks)])


static func _landmark(out: Array, landmark: Dictionary, ctx: Dictionary) -> void:
	var id := str(landmark.get("id", "landmark"))
	if not _fields(out, id, landmark, LANDMARK_FIELDS):
		return
	_recipe(out, id, landmark["recipe"])
	if _fields(out, id, landmark["warden"], WARDEN_FIELDS) and not ctx.is_empty():
		var family: String = ctx["warden_family"]
		if not MOUNTINGS.get(family, []).has(landmark["warden"]["mounting"]):
			_add(out, id, "mounting", "%s is not a mounting of %s (%s)" % [landmark["warden"]["mounting"], family,
				str(MOUNTINGS.get(family, []))])
	_fields(out, id, landmark["bay_dock"], SLOT_FIELDS)
	for slot in landmark["gate_slots"]:
		if not slot is Dictionary:
			_add(out, id, "type", "gate slot is not an object")
		else:
			_fields(out, id, slot, SLOT_FIELDS)


static func _waymarks(out: Array, waymarks: Array, places: Dictionary) -> void:
	if waymarks.size() < MIN_WAYMARKS or waymarks.size() > MAX_WAYMARKS:
		_add(out, "waymarks", "waymarks", "%d waymarks, expected %d to %d" % [waymarks.size(), MIN_WAYMARKS, MAX_WAYMARKS])
	if waymarks.is_empty() or waymarks[0] != DROP_IN or waymarks[-1] != LANDMARK:
		_add(out, "waymarks", "waymarks", "waymarks must run from %s to %s" % [DROP_IN, LANDMARK])
	var seen := {}
	for w in waymarks:
		if not places.has(w):
			_add(out, "waymarks", "reference", "waymark %s does not resolve" % str(w))
		if seen.has(w):
			_add(out, "waymarks", "duplicate", "waymark %s repeats" % str(w))
		seen[w] = true


static func _park_row(out: Array, id: String, row: Dictionary, homes: Dictionary, routes: Dictionary, events := {}) -> void:
	if row["home"] != "" and not homes.has(row["home"]):
		_add(out, id, "reference", "home %s is no home row" % row["home"])
	for route in row["routes"]:
		if not routes.has(route):
			_add(out, id, "reference", "route %s is no route" % str(route))
	_recipe(out, id, row["recipe"])
	# The optional park row fields. "fit" opts a GLB row in to park_recipes.gd's seat fit (PARK-SEAT, 2026-10-16) or
	# its tile fit (PARK-TILE, 2026-10-16) or its drape fit (dam kit, 2026-10-17). "rider" sets a GLB down beside the row
	# whose jib turns when its "on" fact first fires (the dam's crest crane, 2026-10-18).
	if row.has("fit"):
		if not FITS.has(row["fit"]):
			_add(out, id, "enum", "fit %s is not in its list" % str(row["fit"]))
		elif String(row["recipe"]) == "" or String(row["recipe"]).begins_with("greybox:"):
			_add(out, id, "fit", "fit %s needs a GLB recipe, not %s" % [row["fit"], str(row["recipe"])])
	# Optional: "off_spine": true keeps the row's graph zone an off-spine dead end for the rib pay rate
	# (director.off_spine), whatever the graph reads (ruling bd).
	if row.has("off_spine") and not row["off_spine"] is bool:
		_add(out, id, "type", "off_spine %s is no bool" % str(row["off_spine"]))
	if row.has("music_layer"):
		var layer = row["music_layer"]
		if not layer is String or not String(layer).begins_with(MUSIC_LAYER_PREFIX) or not EventKinds.WORLD_ROWS.has(layer):
			_add(out, id, "music_layer", "music_layer %s is no %s* WORLD_ROWS kind" % [str(layer), MUSIC_LAYER_PREFIX])
	# Optional: "hide_on" names a natural collapse or impact event row (EventKinds.HIDING_NATURAL_KINDS) with an
	# effect.swap. event_ground.gd hides the row's placed node (and so its collider) while that swap is live and shows
	# it again on revert. Industrial and ancient events re-prepare on every activation, cave entries never reach
	# apply_swap and the other natural kinds build no swap entry, so the contract stops short of them.
	if row.has("hide_on"):
		var event_id = row["hide_on"]
		if not event_id is String or not events.has(event_id):
			_add(out, id, "reference", "hide_on %s is no event row" % str(event_id))
		else:
			var event: Dictionary = events[event_id]
			if String(event.get("effect", {}).get("swap", "")) == "":
				_add(out, id, "hide_on", "hide_on %s has no effect.swap to hide on" % event_id)
			elif String(event["family"]) != "natural" or not EventKinds.HIDING_NATURAL_KINDS.has(String(event["kind"])):
				_add(out, id, "hide_on", "hide_on %s is a %s %s event; only a natural %s swap hides rows" % [event_id, event["family"], event["kind"], "/".join(EventKinds.HIDING_NATURAL_KINDS)])
	if row.has("rider"):
		var rider = row["rider"]
		if not rider is Dictionary or not rider.get("at") is Array or (rider["at"] as Array).size() != 2 \
				or String(rider.get("recipe", "")) == "" or String(rider.get("recipe", "")).begins_with("greybox:"):
			_add(out, id, "rider", "rider needs a GLB recipe and an [x, z] at, not %s" % str(rider))
		elif rider.has("on") and not String(rider["on"]).begins_with("layer_mind_quote_"):
			_add(out, id, "rider", "rider on %s is no once-per-run fact (layer_mind_quote_*)" % str(rider["on"]))
		elif rider.has("yaw_deg") and not (rider["yaw_deg"] is float or rider["yaw_deg"] is int):
			_add(out, id, "rider", "rider yaw_deg %s is no number" % str(rider["yaw_deg"]))
		else:
			_recipe(out, id, String(rider["recipe"]))
	if GUARDED_SOCIETIES.has(row["society"]):
		if row["home"] != "":
			_add(out, id, "guardrail", "a %s row houses no home (%s)" % [row["society"], row["home"]])
		if row["fragment"] != "" and not String(row["fragment"]).begins_with(REF_PREFIX):
			_add(out, id, "guardrail", "a %s row carries only ref_ fragments (%s)" % [row["society"], row["fragment"]])


static func _event_row(out: Array, id: String, row: Dictionary, rows: Dictionary, homes: Dictionary, routes: Dictionary, activities := {}) -> void:
	var site := _site(out, id, row, rows)
	var kind: String = row["kind"]
	if EVENT_FAMILY[kind] != row["family"]:
		_add(out, id, "family", "%s is %s, not %s" % [kind, EVENT_FAMILY[kind], row["family"]])
	_trigger(out, id, row["trigger"], false)
	if row["trigger"].get("on") == "activity" and not activities.has(row["trigger"].get("value")):
		_add(out, id, "reference", "trigger activity %s is no activity row" % str(row["trigger"].get("value")))
	# The sluice is the surge course's water (activities.gd): it opens only when that course's ring is rolled into.
	if kind == "sluice_surge" and row["trigger"].get("on") != "activity":
		_add(out, id, "trigger", "a sluice_surge opens on its surge_run activity, not on %s" % str(row["trigger"].get("on")))
	if _fields(out, id, row["telegraph"], TELEGRAPH_FIELDS):
		var floor_s := _lead_floor(row)
		if float(row["telegraph"]["lead_s"]) < floor_s:
			_add(out, id, "lead_floor", "lead_s %s is under the %s s floor for %s" % [row["telegraph"]["lead_s"], floor_s, kind])
	var effect: Dictionary = row["effect"]
	var water: bool = WATER_KINDS.has(kind) or effect.get("material") == "water"
	if water and effect.has("depth_m") and (not _is_num(effect["depth_m"]) or float(effect["depth_m"]) > MAX_EVENT_WATER_M):
		_add(out, id, "water_depth", "depth_m %s is over %s m" % [str(effect["depth_m"]), MAX_EVENT_WATER_M])
	if effect.has("home") and not homes.has(effect["home"]):
		_add(out, id, "reference", "effect.home %s is no home row" % str(effect["home"]))
	if kind == "fleet_landing" and not VESSELS.has(effect.get("vessel")):
		_add(out, id, "enum", "effect.vessel %s is not one of %s" % [str(effect.get("vessel")), str(VESSELS)])
	if EVENT_FAMILY[kind] == "fleet":
		if not effect.has("home"):
			_add(out, id, "missing", "a %s names effect.home" % kind)
		if not effect.has("footprint_m"):
			_add(out, id, "missing", "a %s names effect.footprint_m" % kind)
	if _fields(out, id, row["route_change"], ROUTE_CHANGE_FIELDS):
		for key in ["closes", "opens"]:
			for route in row["route_change"][key]:
				if not routes.has(route):
					_add(out, id, "reference", "route_change.%s %s is no route" % [key, str(route)])
	_fields(out, id, row["music_cue"], CUE_FIELDS)
	if not site.is_empty() and GUARDED_SOCIETIES.has(site["society"]) and GUARDED_EVENT_KINDS.has(kind):
		_add(out, id, "guardrail", "%s at %s, a %s row" % [kind, site["id"], site["society"]])


static func _lead_floor(row: Dictionary) -> float:
	if ARRIVAL_FAMILIES.has(row["family"]):
		return LEAD_ARRIVAL_S
	if GROUND_KINDS.has(row["kind"]) or str(row["effect"].get("swap", "")) != "":
		return LEAD_GROUND_S
	return LEAD_HAZARD_S


# combat.gd spawn_enemy turns an unknown kind into a chaser with only a warning, and an enemy camp
# with an empty pack never starts, so its pay is unreachable.
const SET_PIECE_KINDS := ["miniboss", "warden", "vault"]


# W1-70: an activity row may list alternatives, one drawn per run (activities.gd drawn). An alternative names its
# own activity and pack and keeps the row's place, site, pay and pocket role (PARK.md 2.12), so every map check
# that reads the row holds whichever is drawn: a camp stays a camp, a risk stays a risk, the pay ladder stands.
static func _activity_alts(out: Array, id: String, row: Dictionary) -> void:
	var alts = row["alts"]
	if not (alts is Array and not (alts as Array).is_empty()):
		_add(out, id, "type", "alts %s is not a nonempty array" % str(alts))
		return
	var role := _alt_role(String(row["activity"]))
	if role == "":
		_add(out, id, "enum", "a %s row cannot list alts" % row["activity"])
		return
	var n := 0
	for alt in alts:
		var label := "%s alts[%d]" % [id, n]
		n += 1
		if not _fields(out, label, alt, {"activity": ACTIVITY_KINDS, "pack": "a"}):
			continue
		for key in alt:
			if not key in ["activity", "pack"]:
				_add(out, label, "type", "an alt sets only activity and pack, not %s" % key)
		if _alt_role(String(alt["activity"])) != role:
			_add(out, label, "enum", "a %s alt changes the row's role from %s" % [alt["activity"], role])
		_activity_pack(out, label, alt)


# The pocket role an alternative must keep (park_placement.gd's kinds, not preloaded: it preloads this file), "" for a
# kind that cannot vary: a cache has an assigned interior, a surge course its route and sluice, a relay its stake post.
static func _alt_role(kind: String) -> String:
	if kind == "enemy_camp":
		return "online"
	if kind in ["ambush_altar", "hauler_bounty"]:
		return "risk"
	return ""


static func _activity_pack(out: Array, id: String, row: Dictionary) -> void:
	var pack = row.get("pack", [])
	if not (pack is Array):
		return
	if row["activity"] == "enemy_camp" and row.has("pack") and pack.is_empty():
		_add(out, id, "reference", "an enemy_camp pack is empty, so the camp never starts")
	for kind in pack:
		if not (kind is String and (Director.KIND_NAMES.has(kind) or SET_PIECE_KINDS.has(kind) or Rogue.ROWS.has(kind))):
			_add(out, id, "reference", "pack kind %s is no roster kind" % str(kind))


static func _home_row(out: Array, id: String, row: Dictionary, rows: Dictionary, ctx: Dictionary) -> void:
	var site := _site(out, id, row, rows)
	if not Director.KIND_NAMES.has(row["enemy"]):
		_add(out, id, "reference", "enemy %s is no roster kind" % row["enemy"])
	if not site.is_empty():
		if site["landform"] != row["landform"]:
			_add(out, id, "home_landform", "landform %s differs from %s's %s" % [row["landform"], site["id"], site["landform"]])
		if GUARDED_SOCIETIES.has(site["society"]):
			_add(out, id, "guardrail", "a home in %s, a %s row" % [site["id"], site["society"]])
	if _fields(out, id, row["reinforce"], REINFORCE_FIELDS) and not ctx.is_empty():
		if not ctx["packs"].has(row["reinforce"]["pack"]):
			_add(out, id, "pack", "pack %s is not one of world %s's packs %s" % [row["reinforce"]["pack"], ctx["world"], str(ctx["packs"])])
	_fields(out, id, row["break"], BREAK_FIELDS)


static func _weather_row(out: Array, id: String, row: Dictionary, events: Dictionary) -> void:
	_trigger(out, id, row["trigger"], true)
	_fields(out, id, row["fog"], FOG_FIELDS)
	for event_id in row["event_odds"]:
		if not events.has(event_id):
			_add(out, id, "reference", "event_odds names %s, no event row" % event_id)
	if row["handling"] != "none":
		_add(out, id, "handling", "handling is %s; weather never changes handling" % row["handling"])


static func _trigger(out: Array, id: String, trigger: Dictionary, weather: bool) -> void:
	var on = trigger.get("on")
	if weather and on == "always":
		return
	if on == "clock_tier":
		var value = trigger.get("value")
		if not _is_num(value) or float(value) < 0.0 or float(value) > MAX_CLOCK_TIER or float(value) != floorf(float(value)):
			_add(out, id, "enum", "clock_tier value %s is not 0 to %d" % [str(value), MAX_CLOCK_TIER])
	elif on == "warden_phase":
		if not PHASES.has(trigger.get("value")):
			_add(out, id, "enum", "warden_phase value %s is not one of %s" % [str(trigger.get("value")), str(PHASES)])
	elif not weather and on == "activity":
		if not trigger.get("value") is String or String(trigger.get("value")) == "":
			_add(out, id, "enum", "activity value %s names no activity row" % str(trigger.get("value")))
	else:
		_add(out, id, "enum", "trigger.on %s is not a trigger kind" % str(on))


static func _recipe(out: Array, id: String, recipe: String) -> void:
	if recipe == "":
		return
	if recipe.begins_with(GREYBOX):
		if not ELEMENTS.has(recipe.trim_prefix(GREYBOX)):
			_add(out, id, "recipe", "%s names no park element" % recipe)
		return
	if recipe == LANDMARK or recipe == SCATTER:
		return
	if not RECIPES.has(recipe) and not _registry().has(recipe):
		_add(out, id, "recipe", "%s names no registry row" % recipe)


static func _registry() -> Dictionary:
	if _registry_read:
		return _registry_ids
	_registry_read = true
	var read := read_file(REGISTRY_PATH)
	for row in read["data"].get("assets", []):
		if row is Dictionary and row.get("id") is String:
			_registry_ids[row["id"]] = true
	return _registry_ids


# The park row a row's site names, or {} with a reference error.
static func _site(out: Array, id: String, row: Dictionary, rows: Dictionary) -> Dictionary:
	if rows.has(row["site"]):
		return rows[row["site"]]
	_add(out, id, "reference", "site %s is no park row" % str(row["site"]))
	return {}


# Check every row of one table; returns the well-formed rows keyed by id. A malformed row
# reports its errors and is left out of the reference checks.
static func _rows(out: Array, park: Dictionary, table: String, spec: Dictionary) -> Dictionary:
	var by_id := {}
	var index := 0
	for row in park[table]:
		var label := "%s[%d]" % [table, index]
		index += 1
		if not row is Dictionary:
			_add(out, label, "type", "row is not an object")
			continue
		var id = row.get("id")
		var name: String = id if id is String and id != "" else label
		if by_id.has(name):
			_add(out, name, "duplicate", "id repeats in " + table)
			continue
		if _fields(out, name, row, spec):
			by_id[name] = row
	return by_id


# True when every field is present with its type; enum lists imply a string.
static func _fields(out: Array, id: String, value, spec: Dictionary) -> bool:
	if not value is Dictionary:
		_add(out, id, "type", "expected an object")
		return false
	var ok := true
	for key in spec:
		if not value.has(key):
			_add(out, id, "missing", "no field " + key)
			ok = false
			continue
		var want = spec[key]
		var got = value[key]
		if want is Array:
			if not want.has(got):
				_add(out, id, "enum", "%s %s is not in its list" % [key, str(got)])
				ok = false
		elif not _typed(got, want):
			_add(out, id, "type", "%s %s is not %s" % [key, str(got), want])
			ok = false
	return ok


static func _typed(value, want: String) -> bool:
	match want:
		"s":
			return value is String
		"n":
			return _is_num(value)
		"n?":
			return value == null or _is_num(value)
		"b":
			return value is bool
		"a":
			return value is Array
		"o":
			return value is Dictionary
		"v2":
			return _is_vec(value, 2)
		"v3":
			return _is_vec(value, 3)
		"v4":
			return _is_vec(value, 4)
	return false


static func _is_num(value) -> bool:
	return value is float or value is int


static func _is_vec(value, n: int) -> bool:
	if not value is Array or value.size() != n:
		return false
	for v in value:
		if not _is_num(v):
			return false
	return true


static func _add(out: Array, id: String, rule: String, detail: String) -> void:
	out.append(_error(id, rule, detail))


static func _error(id: String, rule: String, detail: String) -> Dictionary:
	return {"id": id, "rule": rule, "detail": detail}


static func _v2_len(value: Array) -> float:
	return Vector2(float(value[0]), float(value[1])).length()
