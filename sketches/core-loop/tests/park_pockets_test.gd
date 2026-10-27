extends SceneTree

# Rule: the four pockets of design-v3/PARK.md 2.12 hold on the stage graph (2.11, K-UNITS KB8)
# for the committed fixture as it stands (no in-memory overrides), every distance a path distance
# on the graph. Two distances, two points (2.12): door_m is the path from the nearest line node
# to the door node, and the door rules read the door (sight_ok, off the line, at least 240 m from
# the spawn and 320 m from the beacon, every pair of off-line doors at least 200 m apart, clear of
# home sites, destructive event sites and contraption hazards for 40 m); detour_m is the path from
# the nearest line node to the pay point (the activity row's at, the hidden pocket's cache), and
# the reward and risk detour_m lie in 150 to 600 m, the reward's the larger. The hidden pocket
# stays off the line, off the warden ring and on a site row with three or more routes. Three
# planted rows each break the rule they plant: a door 100 m from the spawn, a door on a line node
# (which also has no detour), a hidden pocket whose site lists one route.
#
# The pay ladder (2.12): the on-line part is common (the camp's named Hot Rivets, which wins over
# the roll, activities.gd _finish), the larger-detour off-line pocket pays rare only and the
# smaller one common or rare. A planted swap, the camp paying rare and the larger-detour pocket
# common, breaks the ladder on both rows, and a row with no pay.rarities and no named part breaks
# it too. The full visit (spawn, all four doors in the best order, beacon) is reported and finite.
#
# SR15, reported and not gated (K-UNITS KB8): the report prints full_visit_ratio (start target at
# most 3.0) as a target, and reward_ratio, the median spawn-to-pocket path over the
# spawn-to-beacon path across the off-line pockets, as information with no target (ruling ac,
# 26 Oct: the beacon is the park's far end, so no legal door reaches the old 1.5). Both are
# structural facts here (present, finite); a target miss is printed as out of target and is no
# test failure. Planted fixtures: off-line doors next to the spawn lower reward_ratio and print no
# target miss for it; two doors sent to the far corners print full_visit_ratio out of target.

const T := preload("res://tests/support/t.gd")

const PARK := "res://src/world/park/park_test.json"
const BAKED := "res://assets/park/park_test"
const TOOL := "res://tools/park_graph.gd"
const LOADER := "res://src/world/park/park_graph.gd"

var t := T.new("park_pockets_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not t.check("graph tool and loader exist", ResourceLoader.exists(TOOL) and ResourceLoader.exists(LOADER)):
		quit(t.verdict())
		return
	var tool: GDScript = load(TOOL)
	var loader: GDScript = load(LOADER)
	var graph = loader.read(BAKED + "/graph.bin")
	if not t.check("graph.bin loads", graph != null):
		quit(t.verdict())
		return
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PARK))

	var ruling: Dictionary = tool.pockets(graph, park)
	_print(tool, ruling)
	t.eq("four pockets", ruling["rows"].size(), 4)
	var roles := []
	for row in ruling["rows"]:
		roles.append(row["role"])
	roles.sort()
	t.eq("one on-line, one reward, one risk, one hidden", roles, ["hidden", "online", "reward", "risk"])
	t.eq("every 2.12 rule holds on the fixture", ruling["breaches"], [])
	_distances(ruling)

	# Planted: the risk door 100 m from the spawn.
	var near := park.duplicate(true)
	_activity(near, "bench_altar")["at"] = [-100, -600]
	t.check("a door 100 m from the spawn breaks the spawn distance", _breaks(tool.pockets(graph, near), "bench_altar", "spawn"))

	# Planted: the reward door on a line node far from both ends.
	var line_node := -1
	var line_bit := int(loader.get("LINE"))
	for n in graph.node_count():
		if graph.flags(n) & line_bit != 0 and graph.d_spawn_node(n) > 400.0 and graph.d_landmark_node(n) > 400.0:
			line_node = n
			break
	if t.check("the fixture has a line node 400 m from both ends", line_node >= 0):
		var p: Vector3 = graph.position(line_node)
		var on_line := park.duplicate(true)
		_activity(on_line, "tube_cache")["at"] = [p.x, p.z]
		var on_ruling: Dictionary = tool.pockets(graph, on_line)
		t.check("a door on a line node breaks off-the-line", _breaks(on_ruling, "tube_cache", "off_line"))
		t.check("a pay point on a line node breaks the detour band", _breaks(on_ruling, "tube_cache", "detour"))

	# Planted: the hidden pocket's site row lists one route.
	var hidden_id := ""
	for row in ruling["rows"]:
		if row["role"] == "hidden":
			hidden_id = row["id"]
	var one_route := park.duplicate(true)
	for row in one_route["contraption_rows"]:
		if row["id"] == hidden_id:
			row["site"] = "tube"
	t.check("a hidden pocket whose site lists one route breaks the three-route rule", _breaks(tool.pockets(graph, one_route), hidden_id, "hidden_routes"))

	# The pay ladder on the fixture: which off-line pocket is far is the graph's call.
	var pay := {}
	var detour := {}
	for row in ruling["rows"]:
		pay[row["role"]] = row["pay_rarities"]
		detour[row["role"]] = row.get("detour_m", -1.0)
	var far_role := "reward" if detour.get("reward", 0.0) >= detour.get("risk", 0.0) else "risk"
	var near_role := "risk" if far_role == "reward" else "reward"
	t.eq("the on-line part is common (named Hot Rivets)", pay.get("online"), ["common"])
	t.eq("the larger-detour pocket pays rare only", pay.get(far_role), ["rare"])
	t.eq("the smaller-detour pocket rolls common or rare", pay.get(near_role), ["common", "rare"])
	var far_id: String = tool._role(ruling["rows"], far_role)["id"]

	# Planted: the tiers swapped, the camp paying rare and the larger-detour pocket common.
	var swapped := park.duplicate(true)
	_activity(swapped, "wash_camp")["pay"] = {"rarities": ["rare"]}
	_activity(swapped, far_id)["pay"] = {"rarities": ["common"]}
	var swap_ruling: Dictionary = tool.pockets(graph, swapped)
	t.check("a camp paying rare breaks the pay ladder", _breaks(swap_ruling, "wash_camp", "pay"))
	t.check("a larger-detour pocket paying common breaks the pay ladder", _breaks(swap_ruling, far_id, "pay"))

	# Planted: an off-line row with no pay.rarities and no named part.
	var bare := park.duplicate(true)
	_activity(bare, far_id)["pay"] = {}
	t.check("a row with no pay.rarities breaks the pay ladder", _breaks(tool.pockets(graph, bare), far_id, "pay"))

	# The full visit is reported: finite, and at least the spawn-to-beacon path.
	var full: float = ruling["full_visit_m"]
	var ratio: float = ruling["full_visit_ratio"]
	t.check("full_visit_ratio is finite", full < INF and ratio < INF, "%.1f m, ratio %.3f" % [full, ratio])
	t.check("the full visit is no shorter than spawn to beacon", ratio >= 1.0, "%.3f" % ratio)
	print("[full_visit] %.1f m, ratio %.3f (start target at most 3.0, reported)" % [full, ratio])
	_ratios(tool, graph, park, ruling)
	quit(t.verdict())


# SR15: the two ratios as targets. Structural asserts only; the targets are printed.
func _ratios(tool: GDScript, graph, park: Dictionary, ruling: Dictionary) -> void:
	var reward_ratio: float = ruling.get("reward_ratio", -1.0)
	t.check("reward_ratio is present and finite", reward_ratio > 0.0 and reward_ratio < INF, str(reward_ratio))
	var targets: Array = ruling.get("targets", [])
	var names := []
	for row in targets:
		names.append(row["name"])
		t.check("target %s carries a value, a target and a verdict" % row["name"],
			row.has("value") and row.has("target") and row.has("ok") and is_finite(float(row["value"])), str(row))
	t.eq("the report's one target is full_visit_ratio (reward_ratio retired, ruling ac)", names, ["full_visit_ratio"])
	print("[reward_ratio] %.3f (information only, ruling ac)" % reward_ratio)
	for line in tool.target_lines(ruling):
		print("[target] " + line)
	var table: String = tool.pocket_table(ruling)
	t.check("the table text prints full_visit_ratio and reward_ratio as information", table.contains("full_visit_ratio") and table.contains("reward_ratio") and table.contains("information only"))

	# Planted: every off-line door next to the spawn, so the spawn-to-pocket median collapses.
	var close := park.duplicate(true)
	_activity(close, "tube_cache")["at"] = [-100, -560]
	_activity(close, "bench_altar")["at"] = [-60, -560]
	for c in close["contraption_rows"]:
		if c["id"] == _role_id(ruling, "hidden"):
			if c.has("door"):
				c["door"]["at"] = [-80, -540]
			c["at"] = [-80, -540]
	var near_ruling: Dictionary = tool.pockets(graph, close)
	_print_targets("planted close doors", tool, near_ruling)
	var near_names := []
	for row in near_ruling.get("targets", []):
		near_names.append(row["name"])
	t.eq("pockets planted near the spawn still report only full_visit_ratio as a target", near_names, ["full_visit_ratio"])
	t.check("the planted ruling still prints reward_ratio as information", tool.pocket_table(near_ruling).contains("reward_ratio %.3f (information only" % near_ruling["reward_ratio"]))

	t.check("the fixture's full_visit_ratio prints in target", not _out_of_target(ruling, "full_visit_ratio"), str(targets))

	# The fixture's own reward_ratio is the median off-line d_spawn over the spawn-to-beacon path.
	var d := []
	for row in ruling["rows"]:
		if row["role"] != "online":
			d.append(row["d_spawn"])
	d.sort()
	t.near("reward_ratio is the median off-line spawn-to-door path over spawn to beacon", reward_ratio, float(d[1]) / float(ruling["beacon_d_spawn"]), 0.0001)
	t.check("the planted close doors lower reward_ratio", float(near_ruling["reward_ratio"]) < reward_ratio, "%.3f vs %.3f" % [near_ruling["reward_ratio"], reward_ratio])

	# Planted: two doors in the far corners, so the tour dwarfs the spawn-to-beacon path.
	var beyond := park.duplicate(true)
	_activity(beyond, "tube_cache")["at"] = [700, 700]
	_activity(beyond, "bench_altar")["at"] = [-700, 700]
	var beyond_ruling: Dictionary = tool.pockets(graph, beyond)
	_print_targets("planted far corners", tool, beyond_ruling)
	t.check("far off-line doors raise reward_ratio over the fixture's", float(beyond_ruling["reward_ratio"]) > reward_ratio, "%.3f vs %.3f" % [beyond_ruling["reward_ratio"], reward_ratio])
	t.check("two doors in the far corners print full_visit_ratio out of target", _out_of_target(beyond_ruling, "full_visit_ratio"))

	# The metric itself on hand-made rows: median 900 over a 600 m beacon walk is 1.5.
	var rows := []
	for d_spawn in [600.0, 1200.0, 900.0]:
		rows.append({"role": "reward", "d_spawn": d_spawn})
	rows.append({"role": "online", "d_spawn": 100.0})
	t.near("the median of 600, 900 and 1200 over a 600 m beacon walk is 1.5", tool._reward_ratio(rows, 600.0), 1.5, 0.0001)
	var made := {"targets": [{"name": "full_visit_ratio", "value": 3.0, "target": "at most 3.0", "ok": true},
		{"name": "full_visit_ratio", "value": 3.01, "target": "at most 3.0", "ok": false}]}
	var lines: PackedStringArray = tool.target_lines(made)
	t.check("a ratio at 3.0 prints in target and one at 3.01 prints out", lines[0].ends_with("in target") and lines[1].ends_with("OUT OF TARGET"), str(lines))
	t.eq("an unreachable door gives an infinite reward_ratio", tool._reward_ratio([{"role": "reward", "d_spawn": INF}], 600.0), INF)
	t.check("an unreachable reward_ratio prints as unreachable", tool.reward_line(INF).begins_with("reward_ratio unreachable"))

func _role_id(ruling: Dictionary, role: String) -> String:
	for row in ruling["rows"]:
		if row["role"] == role:
			return row["id"]
	return ""


func _out_of_target(ruling: Dictionary, name: String) -> bool:
	for row in ruling.get("targets", []):
		if row["name"] == name:
			return not row["ok"]
	return false


func _print_targets(label: String, tool: GDScript, ruling: Dictionary) -> void:
	for line in tool.target_lines(ruling):
		print("[%s] %s" % [label, line])


# The two distances of 2.12 on the loaded fixture: the door rules on door_m, the detour band
# and its order on detour_m.
func _distances(ruling: Dictionary) -> void:
	var reward := {}
	var risk := {}
	for row in ruling["rows"]:
		if not (row.has("door_m") and row.has("detour_m")):
			t.check("%s carries door_m and detour_m" % row["id"], false, str(row.keys()))
			continue
		var door_m: float = row["door_m"]
		var detour_m: float = row["detour_m"]
		if row["role"] == "online":
			t.check("the on-line door is on the line (door_m within 8 m)", door_m <= 8.0, "%.1f m" % door_m)
			continue
		t.check("%s door is reached from the line and is off it" % row["id"], door_m > 0.0 and door_m < INF, "%.1f m" % door_m)
		t.check("%s door is sight_ok" % row["id"], row["sight_ok"])
		t.check("%s door is at least 240 m from the spawn" % row["id"], row["d_spawn"] >= 240.0, "%.1f m" % row["d_spawn"])
		t.check("%s door is at least 200 m from the nearest door" % row["id"], row["nearest_door"] >= 200.0, "%.1f m" % row["nearest_door"])
		if row["role"] == "hidden":
			continue
		t.check("%s door is at least 320 m from the beacon" % row["id"], row["d_landmark"] >= 320.0, "%.1f m" % row["d_landmark"])
		t.check("%s detour_m (line to pay point) is 150 to 600 m" % row["id"], detour_m >= 150.0 and detour_m <= 600.0, "%.1f m" % detour_m)
		if row["role"] == "reward":
			reward = row
		else:
			risk = row
	if not reward.is_empty() and not risk.is_empty():
		t.check("the reward carries the larger detour_m", reward["detour_m"] > risk["detour_m"],
			"%.1f vs %.1f m" % [reward["detour_m"], risk["detour_m"]])


func _activity(park: Dictionary, id: String) -> Dictionary:
	for row in park["activity_rows"]:
		if row["id"] == id:
			return row
	return {}


func _breaks(ruling: Dictionary, pocket: String, rule: String) -> bool:
	for b in ruling["breaches"]:
		if b["pocket"] == pocket and b["rule"] == rule:
			print("[planted] %s %s: %s" % [pocket, rule, b["detail"]])
			return true
	print("[planted] %s %s not found in %s" % [pocket, rule, str(ruling["breaches"])])
	return false


func _print(tool: GDScript, ruling: Dictionary) -> void:
	for line in tool.pocket_table(ruling).split("\n"):
		print("[table] " + line)
