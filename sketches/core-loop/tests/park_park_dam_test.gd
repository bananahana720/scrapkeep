extends SceneTree

# Dressed pass re-pinned 2026-10-12: native family coverage and measured GLB bounds.
# Stage 1, park_dam (Spillway Works), greybox pass 2026-10-11, re-pinned on the KB9 head the same day
# (K-UNITS KD1). Rule: the committed
# bake and stage graph of src/world/park/park_dam.json are fresh; the waymarks run drop_in,
# domes_camp, the_eye, landmark; the four pockets hold their roles in graph.json (domes_camp on
# the line, rim_cache the reward, bench_altar the risk, gallery_valve the hidden pocket) with no
# breach; the landmark is the dam with its beacon at [0, 575] and the reactor Warden mounted on the
# dam face as a harpoon anchor; every waypoint of the six pilot lines and the floor line in
# tools/park_lines/park_dam.json resolves to a point of the park file, each line starts at drop_in,
# ends at landmark and passes every waymark in order; KD0's stand-in park_dam_stage1.json is gone.
# Two runtime facts since KB9 places the rows (park_recipes.gd place_row): every placed greybox row
# but a kicker wedge or an anchor field carries a stamp, because an unstamped greybox stand-in is a
# solid box of the row's whole size (slickrock_domes stood as a 24 m wall across every line); and no
# anchor post (park_recipes.gd anchor_posts) stands within LINE_CLEAR_M of a pilot or floor line.
#
# Planted: a copy of the park with the Warden's family changed, one with two waymarks swapped, a
# lines copy naming a row the park lacks, a pocket role changed, a stamp dropped from a placed row
# and a line bent through an anchor field each turn the pins red.

const T := preload("res://tests/support/t.gd")
const ParkBake := preload("res://tools/park_bake.gd")
const GraphTool := preload("res://tools/park_graph.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")

const MAP := "park_dam"
const PARK := "res://src/world/park/park_dam.json"
const BAKED := "res://assets/park/park_dam"
const LINES := "res://tools/park_lines/park_dam.json"
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
const DRESSED_RECIPES := {"west_wash": "half_pipe_concrete", "upper_slot": "slot_canyon_flow", "corkscrew_slot": "slot_canyon_flow", "west_lane_fin": "mesa_rim_ledge", "east_lane_fin": "mesa_rim_ledge", "incline_spine": "mesa_rim_ledge", "west_rim_bench": "mesa_rim_ledge", "spillway_tunnel": "spillway_tunnel", "cliff_rooms_west": "cliff_dwelling_row", "viga_span": "viga_pivot", "service_ledge": "mesa_rim_ledge", "lobber_ledge": "mesa_rim_ledge", "tailwater_bar": "half_pipe_concrete", "pipeline_bridge": "pipeline_rail", "canal_lips": "canal_lip", "east_rim_bench": "mesa_rim_ledge"}
const PIECE_BOUNDS := {"half_pipe_concrete": [60, 11.9797, 34.64], "slot_canyon_flow": [48, 14.4202, 26], "mesa_rim_ledge": [60, 19.0219, 34.1729], "spillway_tunnel": [90, 46.1333, 15.0], "cliff_dwelling_row": [60, 22.3102, 21.287], "viga_pivot": [36, 18.7, 20.02], "pipeline_rail": [120.4797, 11.0151, 4.4784], "canal_lip": [120.1375, 11.0967, 12.018]}

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

	var misses := pins(park, lines, graph)
	t.check("stage pins hold", misses.is_empty(), "\n".join(misses))

	# Plants: each change must turn the pins red.
	var planted: Dictionary = park.duplicate(true)
	planted["landmark"]["warden"]["family"] = "swarm"
	t.check("planted Warden family turns the pins red", not pins(planted, lines, graph).is_empty())
	planted = park.duplicate(true)
	planted["waymarks"] = ["drop_in", "the_eye", "domes_camp", "landmark"]
	t.check("planted waymark swap turns the pins red", not pins(planted, lines, graph).is_empty())
	var bad_lines: Dictionary = lines.duplicate(true)
	bad_lines["pilots"]["rivet"]["waypoints"].insert(2, "no_such_row")
	t.check("planted unknown waypoint turns the pins red", not pins(park, bad_lines, graph).is_empty())
	var bad_graph: Dictionary = graph.duplicate(true)
	bad_graph["pockets"][0]["role"] = "extra"
	t.check("planted pocket role turns the pins red", not pins(park, lines, bad_graph).is_empty())
	planted = park.duplicate(true)
	for row in planted["park_rows"]:
		if row["id"] == "slickrock_domes":
			row["stamp"] = ""
	t.check("planted unstamped greybox row turns the pins red", not pins(planted, lines, graph).is_empty())
	bad_lines = lines.duplicate(true)
	bad_lines["pilots"]["sable"]["waypoints"].insert(1, [-600, -600])
	t.check("planted line through an anchor field turns the pins red", not pins(park, bad_lines, graph).is_empty())
	planted = park.duplicate(true)
	for row in planted["park_rows"]:
		if row["id"] == "west_wash":
			row["recipe"] = "greybox:half_pipe"
			row["stamp"] = "wash"
	t.check("planted family greybox turns dressed coverage red", not pins(planted, lines, graph).is_empty())
	planted = park.duplicate(true)
	for row in planted["park_rows"]:
		if row["id"] == "west_wash":
			row["size"][0] *= 2
	t.check("planted oversized recipe turns dressed bounds red", not pins(planted, lines, graph).is_empty())
	quit(t.verdict())


# Every stage fact this test pins; [] when all hold, else one line per miss.
static func pins(park: Dictionary, lines: Dictionary, graph: Dictionary) -> Array:
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
		var recipe := String(row.get("recipe", ""))
		if recipe.begins_with(ParkRecipes.GREYBOX) and not UNSTAMPED_OK.has(row["element"]) and String(row.get("stamp", "")) == "":
			out.append("%s is a greybox %s with no stamp: KB9 builds it as a solid box" % [row["id"], row["element"]])
		places[String(row["id"])] = Vector2(float(row["at"][0]), float(row["at"][1]))
	for row in park.get("activity_rows", []):
		places[String(row["id"])] = Vector2(float(row["at"][0]), float(row["at"][1]))
	if park.has("spawn"):
		places["drop_in"] = Vector2(float(park["spawn"]["at"][0]), float(park["spawn"]["at"][1]))
	if beacon.size() == 2:
		places["landmark"] = Vector2(float(beacon[0]), float(beacon[1]))
	var zones := ParkRecipes.clear_zones(park)
	var posts := PackedVector2Array()
	for row in park.get("park_rows", []):
		if String(row.get("recipe", "")) == ParkRecipes.GREYBOX + "anchor_field":
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
			for p in posts:
				var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				near = minf(near, p.distance_to(a + ab * u))
		if near < LINE_CLEAR_M:
			out.append("%s line passes %.1f m from an anchor post, want at least %s" % [key, near, LINE_CLEAR_M])
	var dressed := {}
	for row in park.get("park_rows", []):
		var recipe := String(row.get("recipe", ""))
		dressed[row["id"]] = recipe
		if recipe == "" or recipe.begins_with(ParkRecipes.GREYBOX):
			continue
		if not PIECE_BOUNDS.has(recipe):
			out.append("%s uses an unmeasured native recipe %s" % [row["id"], recipe])
			continue
		for axis in 3:
			if absf(float(row["size"][axis]) - float(PIECE_BOUNDS[recipe][axis])) > 0.001:
				out.append("%s size %s differs from native %s bounds %s" % [row["id"], row["size"], recipe, PIECE_BOUNDS[recipe]])
	for id in DRESSED_RECIPES:
		if dressed.get(id) != DRESSED_RECIPES[id]:
			out.append("%s must use %s in the dressed pass" % [id, DRESSED_RECIPES[id]])
	return out
