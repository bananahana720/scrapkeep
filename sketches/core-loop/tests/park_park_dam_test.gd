extends SceneTree

# Stage 1, park_dam (Spillway Works), greybox pass 2026-10-11, re-pinned on the KB9 head the same day
# (K-UNITS KD1). Rule: the committed
# bake and stage graph of src/world/park/park_dam.json are fresh; the waymarks run drop_in,
# domes_camp, the_eye, landmark; the four pockets hold their roles in graph.json (domes_camp on
# the line, rim_cache the reward, bench_altar the risk, gallery_valve the hidden pocket) with no
# breach; the landmark is the dam with its beacon at [0, 575] and the reactor Warden mounted on the
# dam face as a harpoon anchor; every waypoint of the six pilot lines and the floor line in
# assets/park/park_dam/lines.json resolves to a point of the park file, each line starts at drop_in,
# ends at landmark and passes every waymark in order; KD0's stand-in park_dam_stage1.json is gone.
# Two runtime facts since KB9 places the rows (park_recipes.gd place_row): every placed greybox row
# but a kicker wedge or an anchor field carries a stamp, because an unstamped greybox stand-in is a
# solid box of the row's whole size (slickrock_domes stood as a 24 m wall across every line); and no
# anchor post (park_recipes.gd anchor_posts) stands within LINE_CLEAR_M of a pilot or floor line.
#
# Re-pinned 2026-10-16 for the KD1-DRESS dressing pilot (design-v3/park/stages/1-park_dam.md section 15):
# exactly the rows in DRESSED name a landform GLB recipe, each GLB's base file exists so the row does not
# fall back to greybox, and every other park row stays a greybox stand-in. A new swap updates DRESSED and
# the stage page's swap and keep lists together. A row with recipe "" (a ground row) places nothing.
#
# Re-pinned 2026-10-17 for the dam kit (tests/park_recipes_dam_dressing_test.gd owns the recipes themselves): DRESSED now names
# 44 rows. An anchors kit recipe (ParkRecipes.ANCHOR_KITS) is not a landform dressing and was already outside this table.
#
# Planted: a copy of the park with the Warden's family changed, one with two waymarks swapped, a
# lines copy naming a row the park lacks, a pocket role changed, a stamp dropped from a placed row,
# a line bent through an anchor field, a dressed row reverted to greybox and a kept row swapped to a
# GLB each turn the pins red.

const T := preload("res://tests/support/t.gd")
const ParkBake := preload("res://tools/park_bake.gd")
const GraphTool := preload("res://tools/park_graph.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Director := preload("res://src/world/event_director.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const MAP := "park_dam"
const PARK := "res://src/world/park/park_dam.json"
const BAKED := "res://assets/park/park_dam"
const LINES := "res://assets/park/park_dam/lines.json"
const STAND_IN := "res://assets/park/park_dam_stage1.json"
const WAYMARKS := ["drop_in", "domes_camp", "the_eye", "landmark"]
const PILOTS := ["sable", "rivet", "kest", "tarn", "tally", "cannon"]
const ROLES := {"domes_camp": "online", "rim_cache": "reward", "bench_altar": "risk", "gallery_valve": "hidden"}
const BEACON := [0, 575]
const SIGHT_SHARE := 0.85
# A post is 8 m square (park_recipes.gd ANCHOR_POST_M); 15 m from its centre leaves the ball about 10 m
# of drift either side of a line before it meets a post.
const LINE_CLEAR_M := 15.0
const UNSTAMPED_OK := ["kicker", "anchor_field"]
# KD1-DRESS, 2026-10-16: the rows dressed with a landform recipe GLB, and the recipe each names. 2026-10-17 (dam kit):
# the 40 ride-lip greybox rows and `eye_mouth` join, each on its own drape recipe `dam_<row id>`
# (tools/blender/park/dam_dressing.py). The slalom (stage page section 16) adds a survey gate flag on its seven gate domes and the benchmark on dome_11.
const DRESSED := {"dome_5": "dam_survey_gate_red", "dome_6": "dam_survey_gate_red", "dome_15": "dam_survey_gate_red",
	"dome_18": "dam_survey_gate_blue", "dome_19": "dam_survey_gate_blue", "dome_24": "dam_survey_gate_blue",
	"dome_25": "dam_survey_gate_blue", "dome_11": "dam_survey_benchmark",
	"west_wash": "half_pipe_concrete", "upper_slot": "slot_canyon_flow", "corkscrew_slot": "slot_canyon_flow",
	"shelf_lip": "dam_shelf_lip", "wash_fin_west": "dam_wash_fin_west", "slot_fin_west": "dam_slot_fin_west",
	"slot_fin_east": "dam_slot_fin_east", "slot_fin_far": "dam_slot_fin_far", "domes_fin_west": "dam_domes_fin_west",
	"domes_fin_mid": "dam_domes_fin_mid", "domes_fin_east": "dam_domes_fin_east", "domes_kicker": "dam_domes_kicker",
	"wash_kicker": "dam_wash_kicker", "upper_slot_step": "dam_upper_slot_step", "corkscrew_step": "dam_corkscrew_step",
	"eye_fin_west": "dam_eye_fin_west", "eye_fin_east": "dam_eye_fin_east", "the_eye": "dam_the_eye",
	"eye_mouth": "dam_eye_mouth", "eye_chute_west": "dam_eye_chute_west", "eye_chute_east": "dam_eye_chute_east",
	"pool_rock": "dam_pool_rock", "pool_pillar": "dam_pool_pillar", "west_lane_fin": "dam_west_lane_fin",
	"east_lane_fin": "dam_east_lane_fin", "incline_spine": "dam_incline_spine",
	"training_wall_west": "dam_training_wall_west", "training_wall_east": "dam_training_wall_east",
	"spillway_tunnel": "dam_spillway_tunnel", "outlet_bucket": "dam_outlet_bucket",
	"cliff_rooms_west": "dam_cliff_rooms_west", "service_ledge": "dam_service_ledge",
	"lobber_ledge": "dam_lobber_ledge", "tailwater_bar": "dam_tailwater_bar", "pipeline_bridge": "dam_pipeline_bridge",
	"canal_lips": "dam_canal_lips", "east_abutment": "dam_east_abutment",
	"eye_fall_spire_west": "dam_eye_fall_spire_west", "eye_fall_spire_east": "dam_eye_fall_spire_east",
	"apron_kicker": "dam_apron_kicker", "plunge_pool": "dam_plunge_pool", "powerhouse": "dam_powerhouse",
	"toe_vent_pits": "dam_toe_vent_pits", "crest_rail": "dam_crest_rail"}

var t := T.new("park_park_dam_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var park = JSON.parse_string(FileAccess.get_file_as_string(PARK))
	var lines = JSON.parse_string(FileAccess.get_file_as_string(LINES))
	var graph = JSON.parse_string(FileAccess.get_file_as_string(BAKED + "/graph.json"))
	if not t.check("park file, lines file and graph.json parse", park is Dictionary and lines is Dictionary and graph is Dictionary):
		quit(t.verdict())
		return

	var stale_bake: Array = ParkBake.freshness(PARK, BAKED)
	t.check("committed bake is fresh", stale_bake.is_empty(), str(stale_bake))
	var stale_graph: Array = GraphTool.freshness(PARK, BAKED, BAKED)
	t.check("committed stage graph is fresh", stale_graph.is_empty(), str(stale_graph))
	t.check("KD0's stand-in park_dam_stage1.json is deleted", not FileAccess.file_exists(STAND_IN))

	var cells = ParkGraph.read(BAKED + "/graph.bin")
	var misses := pins(park, lines, graph, cells)
	t.check("stage pins hold", misses.is_empty(), "\n".join(misses))

	# Plants: each change must turn the pins red.
	var planted: Dictionary = park.duplicate(true)
	planted["landmark"]["warden"]["family"] = "swarm"
	t.check("planted Warden family turns the pins red", not pins(planted, lines, graph, cells).is_empty())
	planted = park.duplicate(true)
	planted["waymarks"] = ["drop_in", "the_eye", "domes_camp", "landmark"]
	t.check("planted waymark swap turns the pins red", not pins(planted, lines, graph, cells).is_empty())
	var bad_lines: Dictionary = lines.duplicate(true)
	bad_lines["pilots"]["rivet"]["waypoints"].insert(2, "no_such_row")
	t.check("planted unknown waypoint turns the pins red", not pins(park, bad_lines, graph, cells).is_empty())
	var bad_graph: Dictionary = graph.duplicate(true)
	bad_graph["pockets"][0]["role"] = "extra"
	t.check("planted pocket role turns the pins red", not pins(park, lines, bad_graph, cells).is_empty())
	planted = park.duplicate(true)
	for row in planted["park_rows"]:
		if row["id"] == "slickrock_domes":
			row["stamp"] = ""
	t.check("planted unstamped greybox row turns the pins red", not pins(planted, lines, graph, cells).is_empty())
	bad_lines = lines.duplicate(true)
	bad_lines["pilots"]["sable"]["waypoints"].insert(1, [-600, -600])
	t.check("planted line through an anchor field turns the pins red", not pins(park, bad_lines, graph, cells).is_empty())
	planted = park.duplicate(true)
	for row in planted["park_rows"]:
		if row["id"] == "toe_vent_pits":
			row["at"] = [180, 430]
	var vent_misses := pins(planted, lines, graph, cells)
	t.check("planted vent corner fails corridor clearance", vent_misses.any(func(miss): return String(miss).begins_with("toe_vents_wake corridor clearance:")), str(vent_misses))
	var closed_cells = ParkGraph.read(BAKED + "/graph.bin")
	for row in park["park_rows"]:
		if row["id"] == "the_eye":
			var eye_cell: int = closed_cells.nearest(Vector2(row["at"][0], row["at"][1]))
			closed_cells.node_flags[eye_cell] &= ~ParkGraph.OPEN
	var open_misses := pins(park, lines, graph, closed_cells)
	t.check("planted Eye OPEN bit fails its graph assertion", open_misses.any(func(miss): return String(miss).begins_with("the_eye graph OPEN:")), str(open_misses))
	planted = park.duplicate(true)
	for row in planted["park_rows"]:
		if row["id"] == "training_wall_east":
			row["size"][0] = 65.0
	var wall_misses := pins(planted, lines, graph, cells)
	t.check("planted old wall tip fails Kest landing clearance", wall_misses.any(func(miss): return String(miss).begins_with("training_wall_east Kest landing clearance:")), str(wall_misses))
	planted = park.duplicate(true)
	for row in planted["park_rows"]:
		if row["id"] == "west_wash":
			row["recipe"] = ParkRecipes.GREYBOX + "half_pipe"
	var undressed := pins(planted, lines, graph, cells)
	t.check("planted greybox west_wash fails the dressing pin", undressed.any(func(miss): return String(miss).begins_with("dressing:")), str(undressed))
	planted = park.duplicate(true)
	for row in planted["park_rows"]:
		if row["id"] == "gate_row_apron":
			row["recipe"] = "canal_lip"
	var overdressed := pins(planted, lines, graph, cells)
	t.check("planted canal_lip swap on a kept row fails the dressing pin", overdressed.any(func(miss): return String(miss).begins_with("dressing:")), str(overdressed))
	quit(t.verdict())


# Every stage fact this test pins; [] when all hold, else one line per miss.
static func pins(park: Dictionary, lines: Dictionary, graph: Dictionary, cells: ParkGraph) -> Array:
	var out := []
	if park.get("map") != MAP:
		out.append("map is %s, want %s" % [park.get("map"), MAP])
	if park.get("waymarks") != WAYMARKS:
		out.append("waymarks %s, want %s" % [park.get("waymarks"), WAYMARKS])
	var lm: Dictionary = park.get("landmark", {})
	if lm.get("id") != "spillway_dam" or lm.get("kind") != "dam":
		out.append("landmark %s %s, want spillway_dam dam" % [lm.get("id"), lm.get("kind")])
	var beacon: Array = lm.get("beacon", [])
	if beacon.size() != 2 or not is_equal_approx(float(beacon[0]), BEACON[0]) or not is_equal_approx(float(beacon[1]), BEACON[1]):
		out.append("beacon %s, want %s" % [beacon, BEACON])
	if not is_equal_approx(float(lm.get("sight_share", 0.0)), SIGHT_SHARE):
		out.append("sight_share %s, want %s" % [lm.get("sight_share"), SIGHT_SHARE])
	var warden: Dictionary = lm.get("warden", {})
	if warden.get("family") != "reactor" or warden.get("mounting") != "dam_face" or warden.get("harpoon_anchor") != true:
		out.append("warden %s/%s/%s, want reactor/dam_face/true" % [warden.get("family"), warden.get("mounting"), warden.get("harpoon_anchor")])

	# Pocket roles and breaches from the committed graph.json.
	var roles := {}
	for row in graph.get("pockets", []):
		roles[String(row["id"])] = String(row["role"])
	for id in ROLES:
		if roles.get(id) != ROLES[id]:
			out.append("pocket %s is %s in graph.json, want %s" % [id, roles.get(id), ROLES[id]])
	if not graph.get("breaches", ["missing"]).is_empty():
		out.append("graph.json breaches: %s" % str(graph.get("breaches")))
	if graph.get("map") != MAP:
		out.append("graph.json map %s" % graph.get("map"))

	# The lines: every waypoint resolves, each starts at drop_in, ends at landmark, passes the waymarks in order.
	var ids := {"drop_in": true, "landmark": true}
	for table in ["park_rows", "activity_rows", "contraption_rows"]:
		for row in park.get(table, []):
			ids[String(row["id"])] = true
	var all := {}
	for key in PILOTS:
		if not lines.get("pilots", {}).has(key):
			out.append("lines file has no %s line" % key)
			continue
		all[key] = lines["pilots"][key]["waypoints"]
	if not lines.has("floor"):
		out.append("lines file has no floor line")
	else:
		all["floor"] = lines["floor"]["waypoints"]
	for key in all:
		var wps: Array = all[key]
		var order := []
		for wp in wps:
			if wp is String:
				if not ids.has(wp):
					out.append("%s line names %s, which the park does not have" % [key, wp])
				elif WAYMARKS.has(wp):
					order.append(wp)
			elif not (wp is Array and wp.size() == 2):
				out.append("%s line has a waypoint that is neither an id nor [x, z]: %s" % [key, str(wp)])
		if wps.is_empty() or wps[0] != "drop_in" or wps[wps.size() - 1] != "landmark":
			out.append("%s line does not run drop_in to landmark" % key)
		if order != WAYMARKS:
			out.append("%s line passes waymarks %s, want %s" % [key, order, WAYMARKS])

	# KB9 runtime: no unstamped greybox box, and no anchor post near a line.
	var places := {}
	for row in park.get("park_rows", []):
		# Kest seed 4, merged round-5 trace ticks 7580..7583: ground-only wall-tip strike.
		if row["id"] == "training_wall_east" and ParkMap.footprint_contains(row, Vector2(54.66, 531.65), Tuning.RADIUS, Vector2(54.37, 531.97)):
			out.append("training_wall_east Kest landing clearance: wall footprint meets the recorded ball-radius approach at [54.66,531.65] to [54.37,531.97]")
		var recipe := String(row.get("recipe", ""))
		if recipe.begins_with(ParkRecipes.GREYBOX) and not UNSTAMPED_OK.has(row["element"]) and String(row.get("stamp", "")) == "":
			out.append("%s is a greybox %s with no stamp: KB9 builds it as a solid box" % [row["id"], row["element"]])
		# KD1-DRESS: the dressed rows name their GLB and it loads; every other row stays greybox, anchor fields aside
		# (they wear the anchors kit, park_anchors_test).
		if DRESSED.has(row["id"]):
			if recipe != DRESSED[row["id"]]:
				out.append("dressing: %s names %s, want %s" % [row["id"], recipe, DRESSED[row["id"]]])
			elif ParkRecipes.stands_in(row):
				out.append("dressing: %s names %s but its base GLB is missing, so it stands in as greybox" % [row["id"], recipe])
		elif recipe != "" and not recipe.begins_with(ParkRecipes.GREYBOX) and not ParkRecipes.is_anchor_field(row):
			out.append("dressing: %s names %s, but only %s are dressed" % [row["id"], recipe, DRESSED.keys()])
		places[String(row["id"])] = Vector2(float(row["at"][0]), float(row["at"][1]))
	for row in park.get("activity_rows", []) + park.get("contraption_rows", []):
		if row.has("at"):
			places[String(row["id"])] = Vector2(float(row["at"][0]), float(row["at"][1]))
	if park.has("spawn"):
		places["drop_in"] = Vector2(float(park["spawn"]["at"][0]), float(park["spawn"]["at"][1]))
	if beacon.size() == 2:
		places["landmark"] = Vector2(float(beacon[0]), float(beacon[1]))
	if cells == null or not places.has("the_eye"):
		out.append("the_eye graph OPEN: committed graph or authored coordinate is missing")
	else:
		var eye_cell: int = cells.nearest(places["the_eye"])
		if eye_cell < 0 or eye_cell >= cells.node_count():
			out.append("the_eye graph OPEN: authored coordinate %s has no cell" % places["the_eye"])
		elif cells.flags(eye_cell) & ParkGraph.OPEN == 0:
			out.append("the_eye graph OPEN: resolved cell %d at %s lacks OPEN" % [eye_cell, places["the_eye"]])
	var vent_site := {}
	var site_id := ""
	for event in park.get("event_rows", []):
		if event.get("id") == "toe_vents_wake":
			site_id = String(event.get("site", ""))
	for row in park.get("park_rows", []):
		if row.get("id") == site_id:
			vent_site = row
	if vent_site.is_empty():
		out.append("toe_vents_wake corridor clearance: event site %s is missing" % site_id)
	var zones := ParkRecipes.clear_zones(park)
	var posts := PackedVector2Array()
	for row in park.get("park_rows", []):
		if ParkRecipes.is_anchor_field(row):
			posts.append_array(ParkRecipes.anchor_posts(row, zones))
	for key in all:
		var pts := []
		for wp in all[key]:
			if wp is String and places.has(wp):
				pts.append(places[wp])
			elif wp is Array and wp.size() == 2:
				pts.append(Vector2(float(wp[0]), float(wp[1])))
		var near := INF
		for i in range(1, pts.size()):
			var a: Vector2 = pts[i - 1]
			var ab: Vector2 = pts[i] - a
			if not vent_site.is_empty() and ParkMap.footprint_contains(vent_site, a, Director.PARK_CORRIDOR_M, pts[i]):
				out.append("toe_vents_wake corridor clearance: %s segment %d %s to %s intersects complete footprint within %s m" % [key, i, a, pts[i], Director.PARK_CORRIDOR_M])
			for p in posts:
				var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				near = minf(near, p.distance_to(a + ab * u))
		if near < LINE_CLEAR_M:
			out.append("%s line passes %.1f m from an anchor post, want at least %s" % [key, near, LINE_CLEAR_M])
	return out
