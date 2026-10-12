extends SceneTree

# Stage 6, park_crown (design-v3/park/stages/6-park_crown.md, K-UNITS KD6): the stage's own pins.
#
# Pinned on greybox round 2, 2026-10-12, after alignment with 560d177:
#   freshness  the bake (tools/park_bake.gd) and the graph (tools/park_graph.gd) of
#              src/world/park/park_crown.json are fresh: the hashes in bake.json and graph.json
#              match the park file, the tools and the outputs.
#   ruling     graph.json has no line errors and no pocket breaches, every route is connected
#              through its via rows. The beacon rule must pass and the ordered spawn rule must
#              actually run; no spires exemption is accepted. A direct spawn check below also
#              explains the farthest-quarter value when the earlier beacon rule fails.
#   placement  KB9 places every row whose recipe is not "": every park row carries
#              greybox:<element> (ruling R10) except five left unplaced: the group rows
#              perch_spires, needles, hoodoo_forest and split_spire (each member spire is a row of
#              its own; a group's 20 m post lattice has no lane through it, walled Kest's needles
#              line at [-135, 105], stopped Rivet at the split spire's edge post [27, 25] and would
#              fill the Warden bowl) and spire_top_ramp (the strike's swap
#              target; no runtime swap yet), plus the 59 slickrock_field_* ground-cover rows
#              (no recipe, no stamp: they build nothing and keep park_density_test's 80 m rule;
#              2026-10-11, restored after their removal failed that rule). No reversed-ramp
#              "_rise" row is left (a kicker's wedge is its own ramp), and no kicker is stamped.
#   waymarks   drop_in, turnstone, split_spire, landmark, in that order; the Turnstone is a
#              landform waymark, not a pocket (coordinator ruling R7, PARK.md 2.12).
#   pockets    camp_signal is the on-line camp on the bajada (pays rivet_plating, common),
#              cache_turnstone the reward (rare), bounty_gauntlet the risk (common or rare),
#              meander_wall the hidden wall; the cache's pay detour is larger than the bounty's.
#   landmark   crown_spire, beacon [0, 470]; the Warden row is the mind kind on the spires
#              mounting with harpoon_anchor true (mind.md section 3).
#   toppled    the split spire's strike opens the toppled route and its last fan (ruling R6), and
#              the spire_top_ramp row it swaps in exists.
#   lines      every named waypoint of tools/park_lines/park_crown.json resolves on the park
#              file (drop_in, landmark, a waymark, a park row or an activity), every line starts
#              at drop_in and ends at the landmark, and the six pilots and the floor are present.
#
# Planted: a copy of the park with turnstone and split_spire swapped in the waymarks, the Warden
# on the island mounting, the strike opening nothing and the meander left unplaced breaks the pins
# (four failures named);
# the same copy written to user:// is stale against the committed bake.

const T := preload("res://tests/support/t.gd")
const ParkBake := preload("res://tools/park_bake.gd")
const GraphTool := preload("res://tools/park_graph.gd")
const GraphLoader := preload("res://src/world/park/park_graph.gd")

const PARK_PATH := "res://src/world/park/park_crown.json"
const BAKE_DIR := "res://assets/park/park_crown"
const LINES_PATH := "res://tools/park_lines/park_crown.json"
const PLANT_PATH := "user://park_crown_plant.json"

const WAYMARKS := ["drop_in", "turnstone", "split_spire", "landmark"]
const POCKETS := {
	"camp_signal": {"role": "online", "rarities": ["common"]},
	"cache_turnstone": {"role": "reward", "rarities": ["rare"]},
	"bounty_gauntlet": {"role": "risk", "rarities": ["common", "rare"]},
	"meander_wall": {"role": "hidden"},
}
const LANDMARK_ID := "crown_spire"
const BEACON := [0, 470]
const WARDEN := {"family": "mind", "mounting": "spires", "harpoon_anchor": true}
const STRIKE := "split_spire_strike"
const TOPPLED := ["toppled", "last_toppled"]
const SWAP_ROW := "spire_top_ramp"
const PILOTS := ["sable", "rivet", "kest", "tarn", "tally", "cannon"]
const UNPLACED := ["perch_spires", "needles", "hoodoo_forest", "split_spire", "spire_top_ramp"]
const FIELD_PREFIX := "slickrock_field_"    # the 59 ground-cover fields: unplaced, unstamped

var t := T.new("park_park_crown_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var park = JSON.parse_string(FileAccess.get_file_as_string(PARK_PATH))
	if not t.check("park_crown.json parses", park is Dictionary):
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
		t.check("beacon rule passes", bool(info["beacon_ok"]), str(info["first_failed"]))
		t.check("ordered spawn rule actually ran", bool(info["spawn"]["run"]), str(info["spawn"]))
		var broken := []
		for id in info["routes"]:
			if not info["routes"][id].is_empty():
				broken.append("%s: %s" % [id, info["routes"][id]])
		t.check("every route connected", broken.is_empty() and info["routes"].size() == park["routes"].size(), "; ".join(broken))
		var graph = GraphLoader.read(BAKE_DIR + "/graph.bin")
		if t.check("graph.bin loads", graph != null):
			var spawn: Dictionary = GraphTool.spawn_check(graph, park)
			t.check("spawn in the farthest quarter", bool(spawn["ok"]), str(spawn))
			var beacon: Dictionary = GraphTool.beacon_check(graph, park)
			print("[beacon_ok] %s: %s" % ["yes" if beacon["ok"] else "no", "; ".join(beacon["reasons"])])
		var by_id := {}
		for p in info["pockets"]:
			by_id[String(p["id"])] = p
		for id in POCKETS:
			if not t.check("pocket %s in graph.json" % id, by_id.has(id)):
				continue
			t.eq("pocket %s role" % id, String(by_id[id]["role"]), String(POCKETS[id]["role"]))
			if POCKETS[id].has("rarities"):
				t.eq("pocket %s pay" % id, by_id[id]["pay_rarities"], POCKETS[id]["rarities"])
			print("[pocket] %s %s door_m %s detour_m %s d_spawn %s d_landmark %s sight_ok %s" % [id, by_id[id]["role"],
				by_id[id]["door_m"], by_id[id]["detour_m"], by_id[id]["d_spawn"], by_id[id]["d_landmark"], by_id[id]["sight_ok"]])
		if by_id.has("cache_turnstone") and by_id.has("bounty_gauntlet"):
			t.check("the reward's detour is larger than the risk's", float(by_id["cache_turnstone"]["detour_m"]) > float(by_id["bounty_gauntlet"]["detour_m"]),
				"%s vs %s" % [by_id["cache_turnstone"]["detour_m"], by_id["bounty_gauntlet"]["detour_m"]])
			t.eq("camp_signal pays its named part", String(by_id["camp_signal"]["pay_named"]), "rivet_plating")

	var fails := pin_failures(park)
	t.check("the stage's pins hold on the committed file", fails.is_empty(), "; ".join(fails))
	t.eq("the authored engage ring stays 120 m", float(park["landmark"]["reach_m"]), 120.0)
	var by_row := {}
	for row in park["park_rows"]:
		by_row[String(row["id"])] = row
	var perches_ok := true
	var path: Array = park["landmark"]["warden"]["path"]
	for i in range(3):
		var perch: Dictionary = by_row["perch_spire_%d" % (i + 1)]
		perches_ok = perches_ok and perch["at"] == [path[i][0], path[i][2]] and String(perch["stamp"]) == ""
	t.check("the three physical perches retain the Warden path without raising the fight floor", perches_ok)
	t.eq("the bowl keeps its 12 m depth", float(by_row["crown_bowl"]["size"][1]), 12.0)

	var lines = JSON.parse_string(FileAccess.get_file_as_string(LINES_PATH))
	if t.check("the lines file parses", lines is Dictionary):
		var bad := line_failures(park, lines)
		t.check("every line's named waypoints resolve, start at drop_in and end at the landmark", bad.is_empty(), "; ".join(bad))

	# Planted: three pinned facts changed in a copy.
	var plant: Dictionary = park.duplicate(true)
	plant["waymarks"] = ["drop_in", "split_spire", "turnstone", "landmark"]
	plant["landmark"]["warden"]["mounting"] = "island"
	for e in plant["event_rows"]:
		if String(e["id"]) == STRIKE:
			e["route_change"]["opens"] = []
	for r in plant["park_rows"]:
		if String(r["id"]) == "meander":
			r["recipe"] = ""
	var planted := pin_failures(plant)
	print("[planted] %s" % "; ".join(planted))
	t.check("planted copy breaks four pins", planted.size() == 4, "%d: %s" % [planted.size(), "; ".join(planted)])
	var f := FileAccess.open(PLANT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(plant, " "))
	f.close()
	var plant_stale: Array = ParkBake.freshness(PLANT_PATH, BAKE_DIR)
	t.check("planted copy is stale against the committed bake", not plant_stale.is_empty(), "%d reasons" % plant_stale.size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PLANT_PATH))
	quit(t.verdict())


static func pin_failures(park: Dictionary) -> Array:
	var out := []
	if Array(park["waymarks"]) != WAYMARKS:
		out.append("waymarks %s, want %s" % [park["waymarks"], WAYMARKS])
	var lm: Dictionary = park["landmark"]
	if String(lm["id"]) != LANDMARK_ID or int(lm["beacon"][0]) != BEACON[0] or int(lm["beacon"][1]) != BEACON[1]:
		out.append("landmark %s at %s, want %s at %s" % [lm["id"], lm["beacon"], LANDMARK_ID, BEACON])
	var w: Dictionary = lm["warden"]
	for k in WARDEN:
		if w.get(k) != WARDEN[k]:
			out.append("warden %s %s, want %s" % [k, w.get(k), WARDEN[k]])
	var opens := []
	for e in park["event_rows"]:
		if String(e["id"]) == STRIKE:
			opens = Array(e["route_change"]["opens"])
	if opens != TOPPLED:
		out.append("%s opens %s, want %s" % [STRIKE, opens, TOPPLED])
	var rows := {}
	for r in park["park_rows"]:
		var id := String(r["id"])
		rows[id] = true
		var recipe := String(r["recipe"])
		if UNPLACED.has(id) or id.begins_with(FIELD_PREFIX):
			if recipe != "":
				out.append("%s carries recipe %s, want none (left unplaced)" % [id, recipe])
		elif recipe != "greybox:" + String(r["element"]):
			out.append("%s carries recipe %s, want greybox:%s" % [id, recipe, r["element"]])
		if id.ends_with("_rise"):
			out.append("reversed-ramp row %s is back" % id)
		if String(r["element"]) == "kicker" and String(r["stamp"]) != "":
			out.append("kicker %s is stamped %s" % [id, r["stamp"]])
	for id in ["turnstone", "split_spire", SWAP_ROW]:
		if not rows.has(id):
			out.append("park row %s missing" % id)
	var acts := {}
	for a in park["activity_rows"]:
		acts[String(a["id"])] = a
	for id in ["camp_signal", "cache_turnstone", "bounty_gauntlet"]:
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
