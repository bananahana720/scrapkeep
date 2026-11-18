extends SceneTree

# Rule: the park file loads only when every PARK.md 2.10 check holds. Each check has one
# planted bad row in a copy of the fixture, and the validator must name that row id under
# that rule; the clean fixture and the six stage pages' park file and pilot line drafts load
# with zero errors (design-v3/PARK.md section 2, K-UNITS KB2).
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const Activities := preload("res://src/world/activities.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

const FIXTURE := "res://src/world/park/park_test.json"
const PAGES := "res://design-v3/park/stages"
const PAGE_COUNT := 6

var _failures := 0
var _fixture := {}


func _initialize() -> void:
	var read := ParkSchema.load_park(FIXTURE)
	_fixture = read["data"]
	_report("fixture loads with zero errors", read["errors"].is_empty(), ParkSchema.describe(read["errors"]))
	_report("fixture is a 1.6 km park with rows in every table", _fixture_full(), "")
	var aliases := []
	for kind in ParkSchema.ACTIVITY_KINDS:
		var rule: Dictionary = Activities.RULES.get(kind, {})
		aliases.append(String(rule.get("cue", {}).get("view", kind)))
	_report("activity kinds resolve existing presentation rows", aliases.all(func(alias): return EventKinds.ACTIVITY_ROWS.has(alias)) and EventKinds.ACTIVITY_ROWS.keys().all(func(kind): return kind in aliases), str(aliases))
	if not _fixture.is_empty():
		_planted_rows()
		_planted_lines()
	_stage_pages()
	print("park_schema_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _fixture_full() -> bool:
	if _fixture.get("size_m") != 1600.0:
		return false
	for table in ["park_rows", "event_rows", "home_rows", "contraption_rows", "weather_rows", "activity_rows", "routes"]:
		if (_fixture.get(table, []) as Array).size() < 2:
			return false
	return true


func _row(park: Dictionary, table: String, id: String) -> Dictionary:
	for row in park[table]:
		if row["id"] == id:
			return row
	push_error("park_schema_test: no %s row %s in the fixture" % [table, id])
	return {}


# Copy the fixture, break one row, and expect an error naming that id under that rule.
func _plant(label: String, id: String, rule: String, mutate: Callable) -> void:
	var park: Dictionary = _fixture.duplicate(true)
	mutate.call(park)
	var errors := ParkSchema.validate(park)
	var hit := errors.any(func(e): return e["id"] == id and e["rule"] == rule)
	_report("%s fails as %s [%s]" % [label, id, rule], hit, ParkSchema.describe(errors))


func _planted_rows() -> void:
	# A row's optional clear_view needs a depth and a half width above zero.
	_plant("clear_view without a depth", "deck", "missing", func(p): _row(p, "park_rows", "deck")["clear_view"] = {"half_width_m": 8})
	_plant("clear_view of no width", "deck", "clear_view", func(p): _row(p, "park_rows", "deck")["clear_view"] = {"depth_m": 20, "half_width_m": 0})
	# A field is missing, or an enum value is not in its list.
	_plant("missing verb", "run_wash", "missing", func(p): _row(p, "park_rows", "run_wash").erase("verb"))
	_plant("unknown element", "deck", "enum", func(p): _row(p, "park_rows", "deck")["element"] = "skate_ramp")
	_plant("unknown weather kind", "test_clear", "enum", func(p): _row(p, "weather_rows", "test_clear")["kind"] = "snow")
	# An id repeats, or a reference does not resolve.
	_plant("repeated id", "lip", "duplicate", func(p): p["park_rows"].append(_row(p, "park_rows", "lip").duplicate(true)))
	_plant("unknown home", "lip", "reference", func(p): _row(p, "park_rows", "lip")["home"] = "no_home")
	_plant("unknown site", "ledge_lobbers", "reference", func(p): _row(p, "home_rows", "ledge_lobbers")["site"] = "nowhere")
	_plant("unknown route", "deck", "reference", func(p): _row(p, "park_rows", "deck")["routes"].append("no_route"))
	_plant("unknown waymark", "waymarks", "reference", func(p): p["waymarks"][1] = "no_mark")
	_plant("unknown event_odds row", "test_monsoon", "reference",
		func(p): _row(p, "weather_rows", "test_monsoon")["event_odds"]["no_event"] = 2.0)
	_plant("unknown effect.home", "bench_dropship", "reference",
		func(p): _row(p, "event_rows", "bench_dropship")["effect"]["home"] = "no_home")
	_plant("unknown route_change id", "pool_flood", "reference",
		func(p): _row(p, "event_rows", "pool_flood")["route_change"]["closes"] = ["no_route"])
	# An activity row's optional face is a nonzero [x, z].
	_plant("zero activity face", "wash_camp", "type", func(p): p["activity_rows"][0]["face"] = [0, 0])
	_plant("activity face not a pair", "wash_camp", "type", func(p): p["activity_rows"][0]["face"] = "south")
	# An activity pack names a kind spawn_enemy cannot make, or an enemy camp has no pack.
	_plant("unknown activity pack kind", "wash_camp", "reference", func(p): p["activity_rows"][0]["pack"] = ["chaser", "lobbr"])
	_plant("empty enemy camp pack", "wash_camp", "reference", func(p): p["activity_rows"][0]["pack"] = [])
	# The mounting is not one of the stage's Warden kind's two.
	_plant("mounting of another kind", "test_dam", "mounting", func(p): p["landmark"]["warden"]["mounting"] = "headframe")
	# A home's pack is not one of its world's packs.
	_plant("pack from another world", "wash_chasers", "pack",
		func(p): _row(p, "home_rows", "wash_chasers")["reinforce"]["pack"] = "dig_bore")
	# A family its kind does not allow, or a lead under its family's floor.
	_plant("wrong family", "apron_boiler", "family", func(p): _row(p, "event_rows", "apron_boiler")["family"] = "natural")
	_plant("hazard lead under 3 s", "canal_lightning", "lead_floor",
		func(p): _row(p, "event_rows", "canal_lightning")["telegraph"]["lead_s"] = 2.0)
	_plant("ground change lead under 5 s", "pool_flood", "lead_floor",
		func(p): _row(p, "event_rows", "pool_flood")["telegraph"]["lead_s"] = 4.0)
	_plant("eruption lead under 8 s", "tube_wakes", "lead_floor",
		func(p): _row(p, "event_rows", "tube_wakes")["telegraph"]["lead_s"] = 6.0)
	# Weather that touches handling.
	_plant("weather handling", "test_monsoon", "handling",
		func(p): _row(p, "weather_rows", "test_monsoon")["handling"] = "slippery")
	# A recipe with no registry row, greybox only by its prefix.
	_plant("unregistered recipe", "run_wash", "recipe",
		func(p): _row(p, "park_rows", "run_wash")["recipe"] = "half_pipe_gold")
	_plant("greybox of no element", "lip", "recipe", func(p): _row(p, "park_rows", "lip")["recipe"] = "greybox:trampoline")
	# A home row's landform differs from its site row's.
	_plant("home landform", "ledge_lobbers", "home_landform",
		func(p): _row(p, "home_rows", "ledge_lobbers")["landform"] = "arroyo")
	# The real-culture guardrail: no home, ref_ fragments only, no ground-changing event.
	_plant("home on a hohokam row", "canal_lip", "guardrail",
		func(p): _row(p, "park_rows", "canal_lip")["home"] = "wash_chasers")
	_plant("home row sited on a hohokam row", "wash_chasers", "guardrail", func(p):
		_row(p, "home_rows", "wash_chasers")["site"] = "canal_lip"
		_row(p, "home_rows", "wash_chasers")["landform"] = "canal")
	_plant("non-ref fragment on a puebloan row", "cliff_rooms", "guardrail",
		func(p): _row(p, "park_rows", "cliff_rooms")["fragment"] = "cliff_secret")
	_plant("eruption at a puebloan row", "tube_wakes", "guardrail",
		func(p): _row(p, "event_rows", "tube_wakes")["site"] = "cliff_rooms")
	# K-CRITIC: event water is at most 1.2 m deep.
	_plant("event water over 1.2 m", "pool_flood", "water_depth",
		func(p): _row(p, "event_rows", "pool_flood")["effect"]["depth_m"] = 3.0)
	# A row's music_layer is a layer_* WORLD_ROWS kind (2026-10-17, crown authored pass).
	_plant("music layer of no kind", "lip", "music_layer", func(p): _row(p, "park_rows", "lip")["music_layer"] = "layer_nowhere")
	_plant("music layer not a layer", "lip", "music_layer", func(p): _row(p, "park_rows", "lip")["music_layer"] = "ride_bowl")
	# hide_on names a natural collapse or impact event row with an effect.swap (the row hides while that swap is applied).
	_plant("hide_on of no event", "lip", "reference", func(p): _row(p, "park_rows", "lip")["hide_on"] = "nowhere")
	_plant("hide_on of an event with no swap", "lip", "hide_on", func(p): _row(p, "park_rows", "lip")["hide_on"] = "pool_flood")
	_plant("hide_on of an ancient swap event", "lip", "hide_on", func(p): _row(p, "park_rows", "lip")["hide_on"] = "tube_wakes")
	_plant("hide_on of an industrial swap event", "lip", "hide_on", func(p): _row(p, "park_rows", "lip")["hide_on"] = "apron_boiler")
	_plant("hide_on of a cave_in event", "lip", "hide_on", func(p):
		var event := _row(p, "event_rows", "pool_flood")
		event["kind"] = "cave_in"
		event["family"] = "natural"
		event["effect"]["swap"] = "pool_cave"
		_row(p, "park_rows", "lip")["hide_on"] = "pool_flood")
	_plant("hide_on of a natural flood_fill with a swap", "lip", "hide_on", func(p):
		_row(p, "event_rows", "pool_flood")["effect"]["swap"] = "pool_ramp"
		_row(p, "park_rows", "lip")["hide_on"] = "pool_flood")
	var hidden: Dictionary = _fixture.duplicate(true)
	var swapped := _row(hidden, "event_rows", "pool_flood")
	swapped["kind"] = "collapse"
	swapped["effect"]["swap"] = "pool_ramp"
	_row(hidden, "park_rows", "lip")["hide_on"] = "pool_flood"
	_report("a hide_on naming a swap event loads", ParkSchema.validate(hidden).is_empty(), ParkSchema.describe(ParkSchema.validate(hidden)))
	# The optional rescue_rows: the site resolves and the pilot is a class id.
	var cage := {"id": "test_cage", "site": "deck", "at": [0, 0], "face": [0, 1], "quest": "test", "pilot": "tally", "prompt": "free the test"}
	_plant("rescue at no site", "test_cage", "reference", func(p):
		var row := cage.duplicate(true)
		row["site"] = "nowhere"
		p["rescue_rows"] = [row])
	_plant("rescue of no pilot", "test_cage", "reference", func(p):
		var row := cage.duplicate(true)
		row["pilot"] = "nobody"
		p["rescue_rows"] = [row])
	var good: Dictionary = _fixture.duplicate(true)
	good["rescue_rows"] = [cage.duplicate(true)]
	_row(good, "park_rows", "lip")["music_layer"] = "layer_crown_ramp"
	_report("a rescue row and a music layer load", ParkSchema.validate(good).is_empty(), ParkSchema.describe(ParkSchema.validate(good)))
	# The kind's spec keys contraptions.gd reads.
	_plant("launcher without target", "deck_cannon", "missing",
		func(p): _row(p, "contraption_rows", "deck_cannon").erase("target"))


# Pilot lines for the fixture, built here (assets/park/park_test/lines.json is KB7's).
func _fixture_lines() -> Dictionary:
	var pilots := {}
	for pilot in ParkSchema.PILOTS:
		pilots[pilot] = {"waypoints": ["drop_in", [-150, -400], "wash_camp", [0, -100], "tube", [0, 500], "landmark"],
			"bar": {"band": "PARK.md section 8", "airborne_share": [0.12, 0.45]}}
	return {"map": "park_test", "stage": 1, "pilots": pilots,
		"floor": {"waypoints": ["drop_in", "wash_camp", "tube", "landmark"]}}


# detail narrows the hit to one check, so a plant cannot pass on a sibling check's error.
func _plant_line(label: String, id: String, mutate: Callable, detail := "") -> void:
	var lines := _fixture_lines()
	mutate.call(lines)
	var errors := ParkSchema.validate_lines(lines, _fixture)
	var hit := errors.any(func(e): return e["id"] == id and e["rule"] == "line" and (detail == "" or e["detail"].contains(detail)))
	_report("%s fails as %s [line]" % [label, id], hit, ParkSchema.describe(errors))


func _planted_lines() -> void:
	var clean := ParkSchema.validate_lines(_fixture_lines(), _fixture)
	_report("fixture lines load with zero errors", clean.is_empty(), ParkSchema.describe(clean))
	# A coordinate before drop_in or after landmark keeps the named waymarks in order, so only
	# the start and end checks can catch these two.
	_plant_line("line not starting at drop_in", "rivet",
		func(l): l["pilots"]["rivet"]["waypoints"].push_front([0, -700]), "does not start at")
	_plant_line("line not ending at landmark", "floor",
		func(l): l["floor"]["waypoints"].push_back([0, 640]), "does not end at")
	_plant_line("waymarks out of order", "kest", func(l):
		l["pilots"]["kest"]["waypoints"] = ["drop_in", "tube", "wash_camp", "landmark"])
	_plant_line("waymark skipped", "sable", func(l): l["pilots"]["sable"]["waypoints"].erase("wash_camp"))
	_plant_line("bar band not section 8", "tally", func(l): l["pilots"]["tally"]["bar"]["band"] = "TRAVERSAL.md")


# Each stage page's draft park file, copied to a temporary file, loads with zero errors, and
# its draft pilot lines pass against it.
func _stage_pages() -> void:
	var names := Array(DirAccess.get_files_at(PAGES)).filter(func(n): return n.ends_with(".md"))
	names.sort()
	_report("six stage pages", names.size() == PAGE_COUNT, str(names))
	for page in names:
		var text := FileAccess.get_file_as_string(PAGES + "/" + page)
		var park := {}
		var lines := {}
		var park_text := ""
		for block in _json_blocks(text):
			var json := JSON.new()
			if json.parse(block) != OK:
				continue
			var parsed = json.data
			if parsed is Dictionary and parsed.has("schema"):
				park = parsed
				park_text = block
			elif parsed is Dictionary and parsed.has("pilots"):
				lines = parsed
		if park.is_empty():
			_report(page + " has a park file block", false, "no JSON block with a schema key")
			continue
		var temp := "user://park_page_%s.json" % park.get("map", page)
		var file := FileAccess.open(temp, FileAccess.WRITE)
		file.store_string(park_text)
		file.close()
		var read := ParkSchema.load_park(temp)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		_report(page + " park file loads with zero errors", read["errors"].is_empty(), ParkSchema.describe(read["errors"]))
		if lines.is_empty():
			_report(page + " has a pilot line block", false, "no JSON block with a pilots key")
			continue
		var line_errors := ParkSchema.validate_lines(lines, park)
		_report(page + " pilot lines pass", line_errors.is_empty(), ParkSchema.describe(line_errors))


# Every fenced block's body, with or without a json tag; blocks that are not JSON parse to null.
func _json_blocks(text: String) -> Array:
	var blocks := []
	var parts := text.split("```")
	for i in range(1, parts.size(), 2):
		blocks.append(parts[i].trim_prefix("json"))
	return blocks
