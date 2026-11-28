extends SceneTree

# Stage 6, park_crown (design-v3/park/stages/6-park_crown.md, K-UNITS KD6): the stage's own pins.
#
# Pinned on greybox round 3, 2026-10-12, after alignment with d8e5077:
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
#              target; no runtime swap yet). The authored pass rows in DRESSED (2026-10-17) name a GLB
#              recipe instead, and its base file exists so the row does not fall back. Coverage fields build physical posts outside the
#              fixed pilot corridors and pocket rings. Effective density excludes unplaced
#              rows and empty post fields, and reads the limit from park_density_test. No reversed-ramp
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
#   lines      every named waypoint of assets/park/park_crown/lines.json resolves on the park
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
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const Density := preload("res://tests/park_density_test.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const Terrain := preload("res://src/world/terrain.gd")

const PARK_PATH := "res://src/world/park/park_crown.json"
const BAKE_DIR := "res://assets/park/park_crown"
const LINES_PATH := "res://assets/park/park_crown/lines.json"
const PLANT_PATH := "user://park_crown_plant.json"

const WAYMARKS := ["drop_in", "turnstone", "split_spire", "landmark"]
# 2026-10-17 crown authored pass (stage page section 17): the gust lips, the hammocks and the mooring deck are GLB rows.
const DRESSED := {"hoodoo_gust_lip_1": "mesa_lip_kicker", "hoodoo_gust_lip_2": "mesa_lip_kicker",
	"hoodoo_gust_lip_3": "mesa_lip_kicker", "hoodoo_gust_lip_4": "mesa_lip_kicker", "needle_gust_lip": "mesa_lip_kicker",
	"gauntlet_toe_lip": "mesa_lip_kicker", "signal_foot_lip": "mesa_lip_kicker", "kite_runout_lip": "mesa_lip_kicker",
	"scree_gust_lip": "mesa_lip_kicker", "meander_cross_lip": "mesa_lip_kicker", "needle_hammock": "net_deck",
	"needle_hammock_2": "net_deck", "kite_mooring_deck": "net_deck",
	# 2026-10-17 islands follow-up: the flank lips and nets that keep the crown over half the park median.
	"watch_flank_lip_w": "mesa_lip_kicker", "watch_flank_lip_e": "mesa_lip_kicker", "east_bajada_lip_1": "mesa_lip_kicker",
	"east_bajada_lip_2": "mesa_lip_kicker", "gauntlet_kite_lip": "mesa_lip_kicker", "alcove_foot_lip": "mesa_lip_kicker",
	"east_wash_hammock": "net_deck", "bowl_rim_net": "net_deck", "west_field_lip": "mesa_lip_kicker",
	"signal_approach_lip": "mesa_lip_kicker", "bajada_rim_lip_w": "mesa_lip_kicker", "bajada_rim_lip_e": "mesa_lip_kicker",
	"east_field_lip": "mesa_lip_kicker", "bowl_rim_net_w": "net_deck",
	# 2026-10-18 placeholder unit I: the sized kickers from the ride pieces (tools/blender/park/kickers.py), seat fit.
	"bajada_lip": "mesa_lip_kicker_24x6x90", "crown_ramp": "mesa_lip_kicker_24x6x60", "east_ribs": "mesa_lip_kicker_26x5x30",
	"kick_wmid_3": "mesa_lip_kicker_60x32x36", "kick_wlast_10": "mesa_lip_kicker_60x26x60",
	"kick_emid_1": "mesa_lip_kicker_24x6x36", "kick_emid_2": "mesa_lip_kicker_24x6x36", "kick_wmid_4": "mesa_lip_kicker_24x6x36",
	"kick_wmid_5": "mesa_lip_kicker_24x6x36", "kick_clast_6": "mesa_lip_kicker_24x6x36", "kick_nlast_7": "mesa_lip_kicker_24x6x36",
	"kick_nlast_8": "mesa_lip_kicker_24x6x36", "kick_nlast_9": "mesa_lip_kicker_24x6x36",
	"kick_wlast_12": "mesa_lip_kicker_24x6x36", "kick_slast_14": "mesa_lip_kicker_24x6x36",
	# 2026-10-18 content lane, crown greybox rows: the last ten stand-ins. The stamped washes and ramps wear decoration-only
	# liners (tools/blender/park/washes.py, 2026-10-18, no collider: the stamp stays the shape); the ledges, the kicker and the net's two 80 m cells (net_deck does
	# not tile, so gauntlet_net is split in two) take their ride pieces.
	"west_wash": "liner_west_wash", "east_wash": "liner_east_wash", "meander": "liner_meander", "meander_bend": "liner_meander_bend",
	"watch_butte_crest": "liner_watch_butte_crest", "drop_ramp": "liner_drop_ramp", "kick_wlast_11": "mesa_lip_kicker_24x6x36",
	"crown_collector": "viga_pivot", "alcove_ledge": "cliff_dwelling_row", "gauntlet_net": "net_deck", "gauntlet_net_2": "net_deck"}
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
const PERCH_XZ := [[0.0, 515.0], [39.0, 447.5], [-39.0, 447.5]]
const PERCH_TOP_M := 12.0

var t := T.new("park_park_crown_test")

class EventMap:
	extends RefCounted
	var park := {}


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
	var event_failures := lightning_failures(park)
	t.check("both Crown lightning rows register supported runtime event states", event_failures.is_empty(), "; ".join(event_failures))
	var cue_failures := music_cue_failures(park)
	t.check("every authored Crown telegraph and landing music cue resolves", cue_failures.is_empty(), "; ".join(cue_failures))
	var unknown_cue: Dictionary = park.duplicate(true)
	unknown_cue["event_rows"][0]["music_cue"]["land"] = "crown_unknown_cue_negative_control"
	var unknown_failures := music_cue_failures(unknown_cue)
	t.eq("an unknown landing cue fails music resolution", unknown_failures.size(), 1)
	t.eq("the authored engage ring stays 120 m", float(park["landmark"]["reach_m"]), 120.0)
	var by_row := {}
	for row in park["park_rows"]:
		by_row[String(row["id"])] = row
	var clear_zones := ParkRecipes.clear_zones(park)
	var t1_anchors: Array = park["park_rows"].filter(func(row: Dictionary) -> bool: return row["id"] == "tarn_west_gap_anchor")
	t.eq("T1 adds exactly one midpoint anchor row", t1_anchors.size(), 1)
	if t1_anchors.size() == 1:
		t.eq("T1 midpoint anchor preserves its clearance placement", t1_anchors[0]["at"], [-131.894, -237.941])
		t.eq("T1 anchor field builds exactly one physical post", ParkRecipes.anchor_posts(t1_anchors[0], clear_zones).size(), 1)
		t.eq("T1 anchor does not reshape the flight ground", String(t1_anchors[0]["stamp"]), "")
	t.eq("T1 restores the third Tarn launch without another launch redesign", by_row["kick_wmid_3"]["size"], [60.0, 32.0, 36.0])
	t.eq("T1 preserves the measured third-trial entry height", float(by_row["kick_wmid_3"]["y"]), 56.118102)
	var heights := ParkTerrain._read_zstd(BAKE_DIR + "/ground.bin", ParkTerrain.SIDE * ParkTerrain.SIDE * 4).to_float32_array()
	var ground := func(x: float, z: float) -> float: return Terrain.grid_height(heights, x, z)
	var holder := Node3D.new()
	root.add_child(holder)
	var perch_failures := physical_perch_failures(park, holder, ground)
	t.check("physical perch centres and tops match mind.md's 12 m seats", perch_failures.is_empty(), "; ".join(perch_failures))
	var clearance_failures := sentinel_clearance_failures(park, holder, ground)
	t.check("sentinel_40 clears the reproduced Tally approach and retains reachable posts", clearance_failures.is_empty(), "; ".join(clearance_failures))
	var mast_failures := signal_clearance_failures(park, holder, ground)
	t.check("signal_masts clears both reproduced approaches and retains reachable physical anchors", mast_failures.is_empty(), "; ".join(mast_failures))
	var ramp: Dictionary = by_row["crown_ramp"]
	var ramp_node := ParkRecipes.place_row(ramp, holder, ground, Callable(), clear_zones)
	var entry := ramp_node.to_global(Vector3(8.0, 0.0, -float(ramp["size"][0]) * 0.5))
	var entry_gap := entry.y - float(ground.call(entry.x, entry.z))
	print("[crown_ramp_entry] physical low edge %s ground gap %.3f m" % [entry, entry_gap])
	t.check("the Crown ramp entry meets Rivet's rolling ground contact", absf(entry_gap) <= Tuning.RADIUS, "entry gap %.3f m exceeds ball radius %.3f m" % [entry_gap, Tuning.RADIUS])
	ramp_node.free()
	t.eq("the Warden anchor stays at the first 18 m lens", park["landmark"]["warden"]["anchor"], [0.0, 18.0, 515.0])
	t.eq("the Warden flight path stays approved", park["landmark"]["warden"]["path"], [[0.0, 18.0, 515.0], [39.0, 18.0, 447.5], [-39.0, 18.0, 447.5]])
	var tall_perch: Dictionary = park.duplicate(true)
	for row in tall_perch["park_rows"]:
		if row["id"] == "perch_spire_1":
			row["size"][1] += 3.0
	var tall_failures := physical_perch_failures(tall_perch, holder, ground)
	t.check("height-only perch mutation breaks physical mounting", not tall_failures.is_empty(), "; ".join(tall_failures))
	holder.free()
	var effective := effective_density_rows(park)
	var density_graph = GraphLoader.read(BAKE_DIR + "/graph.bin")
	var density := Density.measure(density_graph, Density.counted_rows({"park_rows": effective}), Density.play_rect(park))
	print("[effective_density] rows %d worst %.1f m over %d" % [effective.size(), density["worst"], density["over"]])
	t.check("effective geometry meets the owner's density limit", density["open"] > 0 and density["worst"] <= Density.DENSITY_M, str(density))
	var empty_coverage: Dictionary = park.duplicate(true)
	for row in empty_coverage["park_rows"]:
		if row["id"] == "slickrock_field_1":
			row["recipe"] = ""
			row["stamp"] = ""
	var empty_density := Density.measure(density_graph, Density.counted_rows({"park_rows": effective_density_rows(empty_coverage)}), Density.play_rect(park))
	t.check("one emptied coverage row fails effective density", empty_density["worst"] > Density.DENSITY_M, str(empty_density))
	var approach: Dictionary = by_row["sentinel_48"]
	t.check("the centre approach builds anchor posts without raising the fight floor", String(approach["stamp"]) == "" and not ParkRecipes.anchor_posts(approach, clear_zones).is_empty())
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


static func lightning_failures(park: Dictionary) -> Array:
	var out := []
	var map := EventMap.new()
	map.park = park
	var director := EventDirector.new(813, {}, map, 14.0, func(_x, _z): return 0.0)
	for id in ["needle_strikes", "split_spire_strike"]:
		var matches := []
		for state in director._park_states:
			if state.row.id == id:
				matches.append(state)
		if matches.size() != 1:
			out.append("%s registered %d times, want 1" % [id, matches.size()])
			continue
		var form := str(matches[0].row.telegraph.form)
		var landed := str(EventDirector.PARK_LAND_FACTS.get(form, ""))
		if form != "lightning_mark" or landed != "lightning_mark_landed" or EventKinds.world_row(form).is_empty() or EventKinds.world_row(landed).is_empty():
			out.append("%s unsupported owner records %s/%s" % [id, form, landed])
	return out


static func music_cue_failures(park: Dictionary, owner = MusicRows) -> Array:
	var out := []
	for row: Dictionary in park["event_rows"]:
		var context := {"theme": 2, "motif": "sable",
			"ancient": MusicRows.ANCIENT_VOICES.get(row["effect"].get("miniboss", ""), "reactor")}
		for phase in ["telegraph", "land"]:
			var id := str(row["music_cue"][phase])
			var cue: Dictionary = owner.cue(id, context)
			if cue.is_empty() or str(cue.get("family", "")) == "" or str(cue.get("voice", "")) == "" or cue.get("notes", []).is_empty() or bool(cue.get("rise", false)) != (phase == "telegraph"):
				out.append("%s %s cue %s does not resolve for its phase" % [row["id"], phase, id])
	return out


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
		if UNPLACED.has(id):
			if recipe != "":
				out.append("%s carries recipe %s, want none (left unplaced)" % [id, recipe])
		elif DRESSED.has(id):
			if recipe != DRESSED[id] or not (ParkRecipes.SENSOR_ONLY.has(recipe) or ResourceLoader.exists(ParkRecipes.GLB_DIR + recipe + ".glb")):
				out.append("%s carries recipe %s, want %s%s" % [id, recipe, DRESSED[id], "" if ParkRecipes.SENSOR_ONLY.has(DRESSED[id]) else " with its GLB"])
		elif recipe != "greybox:" + String(r["element"]) and not (r["element"] == "anchor_field" and ParkRecipes.ANCHOR_KITS.has(recipe)):
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


static func effective_density_rows(park: Dictionary) -> Array:
	var out := []
	var zones := ParkRecipes.clear_zones(park)
	for row: Dictionary in park["park_rows"]:
		if row["element"] == "ground":
			continue
		if String(row["stamp"]) != "":
			out.append(row)
		elif String(row["recipe"]) != "":
			if row["element"] != "anchor_field" or not ParkRecipes.anchor_posts(row, zones).is_empty():
				out.append(row)
	var coverage := out.filter(func(row: Dictionary) -> bool: return String(row["id"]).begins_with("slickrock_field_"))
	var other := out.filter(func(row: Dictionary) -> bool: return not String(row["id"]).begins_with("slickrock_field_"))
	return coverage + other


static func physical_perch_failures(park: Dictionary, parent: Node3D, ground: Callable) -> Array:
	var out := []
	var zones := ParkRecipes.clear_zones(park)
	for i in PERCH_XZ.size():
		var id := "perch_spire_%d" % (i + 1)
		var rows: Array = park["park_rows"].filter(func(row: Dictionary) -> bool: return row["id"] == id)
		if rows.size() != 1:
			out.append("%s missing" % id)
			continue
		var row: Dictionary = rows[0]
		if row["at"] != PERCH_XZ[i] or row["stamp"] != "" or not ParkRecipes.is_anchor_field(row):
			out.append("%s placement changed" % id)
		var node := ParkRecipes.place_anchor_field(row, parent, ground, zones)
		var shapes := ParkRecipes.collider_shapes(node)
		if shapes.size() != 1:
			out.append("%s has %d posts, want one" % [id, shapes.size()])
		for shape: Dictionary in shapes:
			var centre: Vector3 = shape.global_transform.origin
			var top := centre.y + (shape.shape as BoxShape3D).size.y * 0.5
			print("[physical_perch] %s centre %s top %.6f" % [id, centre, top])
			if Vector2(centre.x, centre.z).distance_to(Vector2(PERCH_XZ[i][0], PERCH_XZ[i][1])) > 0.01 or absf(top - PERCH_TOP_M) > 0.01:
				out.append("%s centre %s top %.3f, want %s top %.1f" % [id, centre, top, PERCH_XZ[i], PERCH_TOP_M])
		node.free()
	return out


static func sentinel_clearance_failures(park: Dictionary, parent: Node3D, ground: Callable) -> Array:
	var out := []
	var rows: Array = park["park_rows"].filter(func(row: Dictionary) -> bool: return row["id"] == "sentinel_40")
	if rows.size() != 1:
		return ["sentinel_40 missing"]
	var node := ParkRecipes.place_anchor_field(rows[0], parent, ground, ParkRecipes.clear_zones(park))
	var point := Vector3(144.2, -5.93, 340.08)
	var nearest := INF
	var collisions := 0
	var rope_range := 0.0
	for spec: Dictionary in Tuning.SPECS:
		if spec["key"] == "rope_range":
			rope_range = float(spec["value"])
	var shapes := ParkRecipes.collider_shapes(node)
	for shape: Dictionary in shapes:
		var span := surface_distance(shape, point)
		if span.is_empty():
			out.append("sentinel_40 has an unsupported collider")
			continue
		nearest = minf(nearest, span[0])
		collisions += int(span[0] <= Tuning.RADIUS)
	print("[sentinel_40_clearance] colliding posts %d nearest physical surface %.3f m" % [collisions, nearest])
	if collisions != 0:
		out.append("%d posts touch the recorded ball sphere at %s" % [collisions, point])
	var reach := INF
	for shape: Dictionary in shapes:
		var span := surface_distance(shape, point)
		if not span.is_empty():
			reach = minf(reach, span[1])
	if shapes.is_empty() or rope_range <= 0.0 or reach > rope_range:
		out.append("no reachable physical anchor at the recorded approach")
	node.free()
	return out


# [at most, at least] the distance from point to a collider's surface, each bound on its safe side: a box is exact on both;
# a fitted anchor hull (ConvexPolygonShape3D, #289) is bounded below by its local bounding box (the hull lies inside it, so
# "clear of the ball" holds if even the box is clear) and above by its nearest vertex (a hull point, so "in rope reach" holds if
# even that is in reach). [] for any other shape.
static func surface_distance(shape: Dictionary, point: Vector3) -> Array:
	var xf: Transform3D = shape.global_transform
	var local := xf.affine_inverse() * point
	if shape.shape is BoxShape3D:
		var half := (shape.shape as BoxShape3D).size * 0.5
		var closest := Vector3(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y), clampf(local.z, -half.z, half.z))
		var d := point.distance_to(xf * closest)
		return [d, d]
	if shape.shape is ConvexPolygonShape3D:
		var pts := (shape.shape as ConvexPolygonShape3D).points
		if pts.is_empty():
			return []
		var box := AABB(pts[0], Vector3.ZERO)
		var vertex := INF
		for p in pts:
			box = box.expand(p)
			vertex = minf(vertex, point.distance_to(xf * p))
		var closest := Vector3(clampf(local.x, box.position.x, box.end.x), clampf(local.y, box.position.y, box.end.y), clampf(local.z, box.position.z, box.end.z))
		return [point.distance_to(xf * closest), vertex]
	return []


static func signal_clearance_failures(park: Dictionary, parent: Node3D, ground: Callable) -> Array:
	var out := []
	var rows: Array = park["park_rows"].filter(func(row: Dictionary) -> bool: return row["id"] == "signal_masts")
	if rows.size() != 1:
		return ["signal_masts missing"]
	var row: Dictionary = rows[0]
	if row["home"] != "mast_cutters" or row["stamp"] != "ridge":
		out.append("signal mast home or ridge binding changed")
	var node := ParkRecipes.place_row(row, parent, ground, Callable(), ParkRecipes.clear_zones(park))
	var shapes := ParkRecipes.collider_shapes(node)
	var approaches := [
		Vector3(-232.57, 13.85, 263.71), Vector3(-236.27, 14.46, 267.66),
		Vector3(-239.9, 14.34, 271.63), Vector3(-243.46, 13.5, 275.6),
		Vector3(-246.96, 11.95, 279.57), Vector3(-250.38, 9.69, 283.52),
		Vector3(-253.56, 7.01, 287.09),
		Vector3(-230.35, 12.99, 268.42), Vector3(-231.8, 11.87, 271.02),
		Vector3(-233.3, 10.03, 273.58), Vector3(-234.84, 7.46, 276.11),
		Vector3(-236.72, 7.0, 278.48), Vector3(-245.06, 7.01, 285.7),
		Vector3(-247.13, 6.12, 287.53),
	]
	var rope_range := 0.0
	for spec: Dictionary in Tuning.SPECS:
		if spec["key"] == "rope_range":
			rope_range = float(spec["value"])
	for point: Vector3 in approaches:
		var nearest := INF
		var reach := INF
		for shape: Dictionary in shapes:
			var span := surface_distance(shape, point)
			if span.is_empty():
				out.append("signal mast has an unsupported collider")
				continue
			nearest = minf(nearest, span[0])
			reach = minf(reach, span[1])
		var yaw := deg_to_rad(float(row["yaw_deg"]))
		var delta := Vector2(point.x - float(row["at"][0]), point.z - float(row["at"][1]))
		var along := absf(delta.dot(Vector2(sin(yaw), cos(yaw))))
		var across := absf(delta.dot(Vector2(cos(yaw), -sin(yaw))))
		var outside_ridge := along > float(row["size"][0]) * 0.5 + Tuning.RADIUS or across > float(row["size"][2]) * 0.5 + Tuning.RADIUS
		print("[signal_clearance] approach %s nearest physical surface %.3f m outside ridge %s" % [point, nearest, outside_ridge])
		if nearest <= Tuning.RADIUS or not outside_ridge:
			out.append("mast collider or ridge intersects the recorded approach at %s" % point)
		if shapes.is_empty() or reach > rope_range:
			out.append("no reachable physical mast at %s" % point)
	node.free()
	return out
