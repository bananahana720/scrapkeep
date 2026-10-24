extends SceneTree

# Wave 19 mini-boss sites and risk-line rows (assets/park/<map>/sites.json, src/world/park/risk_sites.gd).
# Rule: each of the six parks carries 2 to 3 mini-boss discs and 1 to 2 risk rows that hold the
# RiskSites rules against the park file and its committed graph.bin: the world's ancient kind, a
# near row within NEAR_MAX_M, radius at least RADIUS_MIN_M, no event row inside the disc, a centre and eight ring points on open
# ground off the landmark footprint, the drop-in reaching the disc and the disc reaching the
# landmark within DETOUR_MAX_M of the straight path, and a risk route that has an alternative with
# the same from and to, hazards and a reward that sit on it. Each check detail prints the numbers.
#
# Dam and flume have no main route; their shared path is the waymarks and drop_in/landmark, and a
# row's reward and a hazard must also sit off every alternative route's via.
#
# Planted: a site outside play_rect, one on a node with its OPEN bit cleared, one on the landmark
# footprint, one whose landmark path is cut, one whose path is stretched past the detour cap, a
# wrong ancient, a single site, an unknown near row, a radius under the floor, a risk row with no
# alternative route, an unknown route, a hazard and a reward off the route, a hazard-less row and a
# missing sites file each turn the validator red; a risk row copied verbatim stays green.

const T := preload("res://tests/support/t.gd")
const RiskSites := preload("res://src/world/park/risk_sites.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")

const MAPS := ["park_dam", "park_flume", "park_pit", "park_sinkhole", "park_islands", "park_crown"]
# World's survey candidates the rules drop, by park: [site, why the rules reject it].
const DROPPED := {
	"park_dam": [{"id": "dam_mb_late", "at": [240, 200], "radius_m": 36, "near": "pipeline_bridge", "third": "late", "miniboss": "reactor_relic"}, "detour"],
	"park_flume": [{"id": "flume_mb_late", "at": [48, 208], "radius_m": 38, "near": "siphon_span", "third": "late", "miniboss": "reactor_relic"}, "is not OPEN ground"],
	"park_pit": [{"id": "pit_mb_late", "at": [-104, 208], "radius_m": 44, "near": "hoist_house", "third": "late", "miniboss": "swarm_remnant"}, "hazard rows in the disc"],
}

var t := T.new("park_risk_sites_test")


func _initialize() -> void:
	_run.call_deferred()


func _park_path(map_id: String) -> String:
	return "res://src/world/park/%s.json" % map_id


func _graph(map_id: String) -> ParkGraph:
	return ParkGraph.read("res://assets/park/%s/graph.bin" % map_id)


func _run() -> void:
	var parks := {}
	var sites := {}
	var graphs := {}
	for map_id in MAPS:
		parks[map_id] = ParkSchema.read_file(_park_path(map_id))["data"]
		sites[map_id] = RiskSites.read(map_id)["data"]
		graphs[map_id] = _graph(map_id)
		var misses: Array = RiskSites.validate(sites[map_id], parks[map_id], graphs[map_id])
		t.check("%s sites hold" % map_id, misses.is_empty(), "\n".join(misses) + "\n" + _numbers(sites[map_id], parks[map_id], graphs[map_id]))

	var park: Dictionary = parks["park_dam"]
	var good: Dictionary = sites["park_dam"]
	var graph: ParkGraph = graphs["park_dam"]
	var first: Dictionary = good["miniboss_sites"][0]
	var mid: Dictionary = good["miniboss_sites"][1]

	var other_line := {"id": "dam_west_wash", "route": "west_wash_run", "hazards": ["west_wash_flash_flood"], "reward": "west_wash"}
	_red("held-out: a different valid dam line stays green", RiskSites.validate(_with_risk(good, [other_line]), park, graph), false)
	_red("schema mismatch turns red", RiskSites.validate(_with(good, {"schema": "scrapkeep-sites/0"}), park, graph), true, "schema:")
	_red("map mismatch turns red", RiskSites.validate(_with(good, {"map": "park_flume"}), park, graph), true, "map:")
	_red("invalid third turns red", RiskSites.validate(_with_site(good, 0, {"third": "dusk"}), park, graph), true, "is not early, mid or late")
	_red("two sites in one third turn red", RiskSites.validate(_with_site(good, 1, {"third": "early"}), park, graph), true, "already holds")
	_red("duplicate site id turns red", RiskSites.validate(_with_site(good, 1, {"id": "dam_mb_early"}), park, graph), true, "id repeats")
	var no_path := _graph("park_dam")
	no_path.d_from[no_path.nearest(Vector2(mid["at"][0], mid["at"][1]))] = INF
	_red("site with no path from the drop-in turns red", RiskSites.validate(good, park, no_path), true, "not reachable from the drop-in")
	var no_direct := _graph("park_dam")
	no_direct.d_land[no_direct.spawn_node] = INF
	_red("drop-in with no landmark path turns red", RiskSites.validate(good, park, no_direct), true, "landmark unreachable from drop-in")

	var planted := _with_site(good, 0, {"at": [-790, -790]})
	_red("site outside play_rect turns red", RiskSites.validate(planted, park, graph), true, "outside play_rect")

	var closed := _graph("park_dam")
	closed.node_flags[closed.nearest(Vector2(first["at"][0], first["at"][1]))] &= ~ParkGraph.OPEN
	_red("site on a node with OPEN cleared turns red", RiskSites.validate(good, park, closed), true, "is not OPEN ground")

	_red("site on the landmark footprint turns red", RiskSites.validate(_with_site(good, 0, {"at": park["landmark"]["at"]}), park, graph), true, "is on the landmark footprint")

	var cut := _graph("park_dam")
	cut.d_land[cut.nearest(Vector2(mid["at"][0], mid["at"][1]))] = INF
	_red("site whose landmark path is cut turns red", RiskSites.validate(good, park, cut), true, "landmark is not reachable")

	var stretched := _graph("park_dam")
	stretched.d_land[stretched.nearest(Vector2(mid["at"][0], mid["at"][1]))] += RiskSites.DETOUR_MAX_M + 100.0
	_red("site whose path is stretched past the detour cap turns red", RiskSites.validate(good, park, stretched), true, "detour")

	_red("wrong miniboss kind turns red", RiskSites.validate(_with_site(good, 0, {"miniboss": "mind_hand"}), park, graph), true, "ancient is")
	var one: Dictionary = good.duplicate(true)
	one["miniboss_sites"] = [one["miniboss_sites"][0]]
	_red("one site only turns red", RiskSites.validate(one, park, graph), true, "want 2 to 3")
	_red("unknown near row turns red", RiskSites.validate(_with_site(good, 0, {"near": "no_such_row"}), park, graph), true, "is no park row")
	_red("near row too far turns red", RiskSites.validate(_with_site(good, 0, {"near": "the_eye"}), park, graph), true, "over 150")
	_red("radius under the floor turns red", RiskSites.validate(_with_site(good, 0, {"radius_m": 12}), park, graph), true, "radius_m")
	_red("missing sites file turns red", RiskSites.validate(RiskSites.read("park_no_such")["data"], park, graph), true, "missing file")

	var pit_park: Dictionary = parks["park_pit"]
	var pit_row := {"id": "pit_sump_floor", "route": "sump_floor", "hazards": ["sump_flood"], "reward": "floor_sump"}
	_red("risk row with no alternative route turns red", RiskSites.validate(_with_risk(sites["park_pit"], [pit_row]), pit_park, null), true, "has no alternative from pit to landmark")
	var pit_good: Dictionary = sites["park_pit"]["risk_rows"][0]
	_red("unknown route turns red", RiskSites.validate(_with_risk(sites["park_pit"], [_with(pit_good, {"route": "no_route"})]), pit_park, null), true, "is no route")
	_red("hazard off the route turns red", RiskSites.validate(_with_risk(sites["park_pit"], [_with(pit_good, {"hazards": ["sump_flood"]})]), pit_park, null), true, "hazard sump_flood is not on route")
	_red("reward off the route turns red", RiskSites.validate(_with_risk(sites["park_pit"], [_with(pit_good, {"reward": "cache_lip"})]), pit_park, null), true, "reward cache_lip is not on route")
	var isle_park: Dictionary = parks["park_islands"]
	var isle_row: Dictionary = sites["park_islands"]["risk_rows"][0]
	var flume_park: Dictionary = parks["park_flume"]
	var junction := _with(sites["park_flume"]["risk_rows"][0], {"route": "canal_lower", "hazards": ["wasteway_flash_flood"], "reward": "drum_forecourt"})
	_red("junction reward turns red", RiskSites.validate(_with_risk(sites["park_flume"], [junction]), flume_park, null), true, "reward drum_forecourt is also on route wasteway_wall")
	var twin := _with(isle_row, {"id": "islands_wing_west", "route": "wing_west", "hazards": ["isle_shed"], "reward": "knuckle_w"})
	_red("a second row on the tail of the first turns red", RiskSites.validate(_with_risk(sites["park_islands"], [isle_row, twin]), isle_park, null), true, "are one line")
	_red("risk row on the main route turns red", RiskSites.validate(_with_risk(sites["park_islands"], [_with(isle_row, {"route": "main", "hazards": ["fin_rim_collapse"]})]), isle_park, null), true, "is the main line")
	_red("reward on a waymark turns red", RiskSites.validate(_with_risk(sites["park_islands"], [_with(isle_row, {"reward": "camp_anvil"})]), isle_park, null), true, "reward camp_anvil is on the shared path")
	_red("a waymark row named as hazard turns red", RiskSites.validate(_with_risk(sites["park_islands"], [_with(isle_row, {"hazards": ["anvil_rock"]})]), isle_park, null), true, "hazard anvil_rock is no event row")
	var crown_park: Dictionary = parks["park_crown"]
	var crown_row: Dictionary = sites["park_crown"]["risk_rows"][0]
	_red("park row as hazard turns red", RiskSites.validate(_with_risk(sites["park_crown"], [_with(crown_row, {"route": "gauntlet", "hazards": ["gauntlet_west"], "reward": "gauntlet_net"})]), crown_park, null), true, "hazard gauntlet_west is no event row")
	var waymarked: Dictionary = crown_park.duplicate(true)
	waymarked["waymarks"].append("needles")
	_red("hazard whose site is a waymark turns red", RiskSites.validate(_with_risk(sites["park_crown"], [crown_row]), waymarked, null), true, "needle_strikes is on the shared path")
	_red("hazard also on an alternative route stays green", RiskSites.validate(_with_risk(sites["park_islands"], [_with(isle_row, {"hazards": ["mooring_burner_blow"], "reward": "hoodoo_garden"})]), isle_park, null), false)
	_red("reward on an alternative route turns red", RiskSites.validate(_with_risk(sites["park_islands"], [_with(isle_row, {"reward": "west_shelf"})]), isle_park, null), true, "reward west_shelf is also on route")
	_red("risk row with no hazards turns red", RiskSites.validate(_with_risk(sites["park_pit"], [_with(pit_good, {"hazards": []})]), pit_park, null), true, "no hazards")

	for map_id in DROPPED:
		var list: Array = sites[map_id]["miniboss_sites"].duplicate(true)
		list.append(DROPPED[map_id][0])
		var extended: Dictionary = sites[map_id].duplicate(true)
		extended["miniboss_sites"] = list
		var id: String = DROPPED[map_id][0]["id"]
		var found: Array = RiskSites.validate(extended, parks[map_id], graphs[map_id]).filter(func(m): return String(m).begins_with(id))
		t.check("%s survey candidate %s is dropped (%s)" % [map_id, id, DROPPED[map_id][1]], found.any(func(m): return String(m).contains(DROPPED[map_id][1])), str(found))
	quit(t.verdict())


func _red(label: String, misses: Array, want_red: bool, needle := "") -> void:
	var ok := misses.is_empty() != want_red
	if want_red and needle != "":
		ok = ok and misses.any(func(m): return String(m).contains(needle))
	t.check(label, ok, str(misses))


func _with(row: Dictionary, change: Dictionary) -> Dictionary:
	var out: Dictionary = row.duplicate(true)
	out.merge(change, true)
	return out


func _with_site(sites: Dictionary, index: int, change: Dictionary) -> Dictionary:
	var out: Dictionary = sites.duplicate(true)
	out["miniboss_sites"][index].merge(change, true)
	return out


func _with_risk(sites: Dictionary, rows: Array) -> Dictionary:
	var out: Dictionary = sites.duplicate(true)
	out["risk_rows"] = rows
	return out


func _numbers(sites: Dictionary, park: Dictionary, graph: ParkGraph) -> String:
	var lines := []
	for site in sites.get("miniboss_sites", []):
		var m: Dictionary = RiskSites.measure(site, park, graph)
		lines.append("  %s r=%.0f out=%.0f in=%.0f detour=%.0f hazards_in_disc=%s %s" % [site["id"], site["radius_m"], m["out_m"], m["in_m"], m["detour_m"], str(RiskSites.hazards_in_disc(site, park)), "" if m["misses"].is_empty() else "MISS"])
	for row in sites.get("risk_rows", []):
		lines.append("  %s route=%s hazards=%s reward=%s" % [row["id"], row["route"], str(row["hazards"]), row["reward"]])
	return "\n".join(lines)
