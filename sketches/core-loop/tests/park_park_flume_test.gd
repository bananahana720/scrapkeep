extends SceneTree

# Stage 2, park_flume (design-v3/park/stages/2-park_flume.md, K-UNITS KD2): the stage's own pins.
#
# Pinned on the committed file (greybox pass, 2026-10-11):
#   freshness  the bake (tools/park_bake.gd) and the graph (tools/park_graph.gd) of
#              src/world/park/park_flume.json are fresh: the hashes in bake.json and graph.json
#              match the park file, the tools and the outputs.
#   ruling     graph.json has no line errors and no pocket breaches, every route is connected
#              through its via rows, and the spawn sits in the farthest quarter.
#   waymarks   drop_in, butte_gap, siphon_camp, landmark, in that order.
#   pockets    siphon_camp is the on-line camp (pays common), bend_cache the reward (rare),
#              bench_bounty the risk (common or rare), weir_valve the hidden valve; the valve's
#              codex id is flume_weir_cache (coordinator ruling R5).
#   landmark   penstock_tower, beacon [230, 480]; the Warden row is the reactor kind on the flume
#              mounting with harpoon_anchor true (reactor.md section 3).
#   lines      every named waypoint of tools/park_lines/park_flume.json resolves on the park
#              file (drop_in, landmark, a waymark, a park row or an activity), every line ends at
#              the landmark, and the six pilots and the floor line are present.
#
# Planted: a copy of the park with butte_gap and siphon_camp swapped in the waymarks, the valve's
# codex id back on the draft's reach_pressure_cache and the Warden on a crown mounting breaks
# the pins (three failures named); the same copy written to user:// is stale against the
# committed bake.

const T := preload("res://tests/support/t.gd")
const ParkBake := preload("res://tools/park_bake.gd")
const GraphTool := preload("res://tools/park_graph.gd")

const MAP := "park_flume"
const PARK_PATH := "res://src/world/park/park_flume.json"
const BAKE_DIR := "res://assets/park/park_flume"
const LINES_PATH := "res://tools/park_lines/park_flume.json"
const PLANT_PATH := "user://park_flume_plant.json"

const WAYMARKS := ["drop_in", "butte_gap", "siphon_camp", "landmark"]
const POCKETS := {
	"siphon_camp": {"role": "online", "rarities": ["common"]},
	"bend_cache": {"role": "reward", "rarities": ["rare"]},
	"bench_bounty": {"role": "risk", "rarities": ["common", "rare"]},
	"weir_valve": {"role": "hidden"},
}
const VALVE_CODEX := "flume_weir_cache"
const LANDMARK_ID := "penstock_tower"
const BEACON := [230, 480]
const WARDEN := {"family": "reactor", "mounting": "flume", "harpoon_anchor": true}
const PILOTS := ["sable", "rivet", "kest", "tarn", "tally", "cannon"]

var t := T.new("park_park_flume_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var text := FileAccess.get_file_as_string(PARK_PATH)
	var park = JSON.parse_string(text)
	if not t.check("park_flume.json parses", park is Dictionary):
		quit(t.verdict())
		return
	var bake_stale: Array = ParkBake.freshness(PARK_PATH, BAKE_DIR)
	t.check("the bake is fresh", bake_stale.is_empty(), "; ".join(bake_stale))
	var graph_stale: Array = GraphTool.freshness(PARK_PATH, BAKE_DIR, BAKE_DIR)
	t.check("the graph is fresh", graph_stale.is_empty(), "; ".join(graph_stale))

	var info = JSON.parse_string(FileAccess.get_file_as_string(BAKE_DIR + "/graph.json"))
	if t.check("graph.json parses", info is Dictionary):
		t.check("no line errors", info["line_errors"].is_empty(), str(info["line_errors"]))
		t.check("no pocket breaches", info["breaches"].is_empty(), str(info["breaches"]))
		var broken := []
		for id in info["routes"]:
			if not info["routes"][id].is_empty():
				broken.append("%s: %s" % [id, info["routes"][id]])
		t.check("every route connected", broken.is_empty() and info["routes"].size() == park["routes"].size(), "; ".join(broken))
		t.check("spawn in the farthest quarter", bool(info["spawn"]["ok"]), str(info["spawn"]))
		t.check("the beacon is on an objective-fit node (beacon_ok, SR15)", bool(info.get("beacon_ok", false)) and String(info.get("first_failed", "x")) == "",
			"beacon_ok %s, first_failed %s" % [info.get("beacon_ok"), info.get("first_failed")])
		var by_id := {}
		for p in info["pockets"]:
			by_id[String(p["id"])] = p
		var rule_fails := pocket_rule_failures(info["pockets"])
		t.check("every pocket meets PARK.md 2.12 by path on graph.json", rule_fails.is_empty(), "; ".join(rule_fails))
		for id in POCKETS:
			if not t.check("pocket %s in graph.json" % id, by_id.has(id)):
				continue
			t.eq("pocket %s role" % id, String(by_id[id]["role"]), String(POCKETS[id]["role"]))
			if POCKETS[id].has("rarities"):
				t.eq("pocket %s pay" % id, by_id[id]["pay_rarities"], POCKETS[id]["rarities"])
			print("[pocket] %s %s door_m %s detour_m %s d_spawn %s d_landmark %s sight_ok %s" % [id, by_id[id]["role"],
				by_id[id]["door_m"], by_id[id]["detour_m"], by_id[id]["d_spawn"], by_id[id]["d_landmark"], by_id[id]["sight_ok"]])

	var fails := pin_failures(park)
	t.check("the stage's pins hold on the committed file", fails.is_empty(), "; ".join(fails))

	var lines = JSON.parse_string(FileAccess.get_file_as_string(LINES_PATH))
	if t.check("the lines file parses", lines is Dictionary):
		var bad := line_failures(park, lines)
		t.check("every line's named waypoints resolve and end at the landmark", bad.is_empty(), "; ".join(bad))

	# Planted: three pinned facts changed in a copy.
	var plant: Dictionary = park.duplicate(true)
	plant["waymarks"] = ["drop_in", "siphon_camp", "butte_gap", "landmark"]
	for c in plant["contraption_rows"]:
		if String(c["id"]) == "weir_valve":
			c["codex"]["id"] = "reach_pressure_cache"
	plant["landmark"]["warden"]["mounting"] = "crown"
	var planted := pin_failures(plant)
	print("[planted] %s" % "; ".join(planted))
	t.check("planted copy breaks three pins", planted.size() == 3, "%d: %s" % [planted.size(), "; ".join(planted)])
	var f := FileAccess.open(PLANT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(plant, " "))
	f.close()
	var plant_stale: Array = ParkBake.freshness(PLANT_PATH, BAKE_DIR)
	t.check("planted copy is stale against the committed bake", not plant_stale.is_empty(), "%d reasons" % plant_stale.size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PLANT_PATH))

	# Planted: the reward pocket's door 60 m from the spawn, its detour under the risk's, and
	# a door 120 m from another breaks three distance rules.
	var rows: Array = []
	if info is Dictionary:
		rows = (info["pockets"] as Array).duplicate(true)
	for p in rows:
		if String(p["role"]) == "reward":
			p["d_spawn"] = 60
			p["detour_m"] = 100
			p["nearest_door"] = 120
	var planted_rules := pocket_rule_failures(rows)
	print("[planted rules] %s" % "; ".join(planted_rules))
	t.check("planted pocket rows break the 2.12 rules", planted_rules.size() >= 3, "%d: %s" % [planted_rules.size(), "; ".join(planted_rules)])
	quit(t.verdict())


# PARK.md 2.12 on graph.json's pocket rows (distances by path on the stage graph, rulings R1 and R2):
# every off-line door at least 240 m from the spawn and 200 m from any other door; the reward
# and risk doors at least 320 m from the beacon (the hidden pocket keeps every rule but the
# beacon distance) with a detour to the pay of 150 to 600 m, the reward's larger; every door
# sight_ok with a clear 40 m ring; the on-line camp keeps only the ring and the sightline.
static func pocket_rule_failures(pockets: Array) -> Array:
	var out := []
	var detours := {}
	for p in pockets:
		var id := String(p["id"])
		var role := String(p["role"])
		if not bool(p["sight_ok"]):
			out.append("%s door not sight_ok" % id)
		if not (p["clear_ring"] as Array).is_empty():
			out.append("%s clear ring holds %s" % [id, p["clear_ring"]])
		if role == "online":
			continue
		if int(p["d_spawn"]) < 240:
			out.append("%s door %d m from the spawn, want at least 240" % [id, int(p["d_spawn"])])
		if int(p["nearest_door"]) < 200:
			out.append("%s door %d m from %s, want at least 200" % [id, int(p["nearest_door"]), p["nearest_door_id"]])
		if role == "hidden":
			continue
		if int(p["d_landmark"]) < 320:
			out.append("%s door %d m from the beacon, want at least 320" % [id, int(p["d_landmark"])])
		if int(p["detour_m"]) < 150 or int(p["detour_m"]) > 600:
			out.append("%s detour %d m, want 150 to 600" % [id, int(p["detour_m"])])
		detours[role] = int(p["detour_m"])
	if detours.has("reward") and detours.has("risk") and detours["reward"] <= detours["risk"]:
		out.append("reward detour %d m not over the risk's %d m" % [detours["reward"], detours["risk"]])
	return out


static func pin_failures(park: Dictionary) -> Array:
	var out := []
	if Array(park["waymarks"]) != WAYMARKS:
		out.append("waymarks %s, want %s" % [park["waymarks"], WAYMARKS])
	var codex := ""
	for c in park["contraption_rows"]:
		if String(c["id"]) == "weir_valve":
			codex = String(c["codex"]["id"])
	if codex != VALVE_CODEX:
		out.append("weir_valve codex id %s, want %s" % [codex, VALVE_CODEX])
	var lm: Dictionary = park["landmark"]
	if String(lm["id"]) != LANDMARK_ID or int(lm["beacon"][0]) != BEACON[0] or int(lm["beacon"][1]) != BEACON[1]:
		out.append("landmark %s at %s, want %s at %s" % [lm["id"], lm["beacon"], LANDMARK_ID, BEACON])
	var w: Dictionary = lm["warden"]
	for k in WARDEN:
		if w.get(k) != WARDEN[k]:
			out.append("warden %s %s, want %s" % [k, w.get(k), WARDEN[k]])
	var acts := {}
	for a in park["activity_rows"]:
		acts[String(a["id"])] = a
	for id in ["siphon_camp", "bend_cache", "bench_bounty"]:
		if not acts.has(id):
			out.append("activity %s missing" % id)
	return out


static func line_failures(park: Dictionary, lines: Dictionary) -> Array:
	var out := []
	var names := {"drop_in": true, "landmark": true}
	for w in park["waymarks"]:
		names[String(w)] = true
	for r in park["park_rows"]:
		names[String(r["id"])] = true
	for a in park["activity_rows"]:
		names[String(a["id"])] = true
	var all := {}
	for key in PILOTS:
		if not lines["pilots"].has(key):
			out.append("pilot %s missing" % key)
			continue
		all[key] = lines["pilots"][key]["waypoints"]
	if not lines.has("floor"):
		out.append("floor line missing")
	else:
		all["floor"] = lines["floor"]["waypoints"]
	for key in all:
		var pts: Array = all[key]
		for p in pts:
			if p is String and not names.has(p):
				out.append("%s: %s does not resolve" % [key, p])
		if pts.is_empty() or pts[-1] != "landmark":
			out.append("%s does not end at the landmark" % key)
		if pts.is_empty() or pts[0] != "drop_in":
			out.append("%s does not start at drop_in" % key)
	return out
