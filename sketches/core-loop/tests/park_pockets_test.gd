extends SceneTree

# Rule: the four pockets of design-v3/PARK.md 2.12 hold on the stage graph (2.11, K-UNITS KB8),
# every distance a path distance from the door node: the reward and risk doors at least 240 m
# from the spawn and 320 m from the beacon, every pair of off-line doors at least 200 m apart,
# each door sight_ok and clear of home sites, destructive event sites and contraption hazards
# for 40 m, the reward and risk doors off the line with a detour of 150 to 600 m (the reward's
# the larger), and the hidden pocket off the line, off the warden ring and on a site row with
# three or more routes. Three planted rows each break the rule they plant: a door 100 m from the
# spawn, a door on a line node, a hidden pocket whose site lists one route.
#
# The pay ladder (2.12): the on-line part is common (the camp's named Hot Rivets, which wins over
# the roll, activities.gd _finish), the larger-detour off-line pocket pays rare only and the
# smaller one common or rare. A planted swap, the camp paying rare and the larger-detour pocket
# common, breaks the ladder on both rows, and a row with no pay.rarities and no named part breaks
# it too. The full visit (spawn, all four doors in the best order, beacon) is reported and finite.

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
	var park: Dictionary = pocket_fixture(JSON.parse_string(FileAccess.get_file_as_string(PARK)))

	var ruling: Dictionary = tool.pockets(graph, park)
	_print(tool, ruling)
	t.eq("four pockets", ruling["rows"].size(), 4)
	var roles := []
	for row in ruling["rows"]:
		roles.append(row["role"])
	roles.sort()
	t.eq("one on-line, one reward, one risk, one hidden", roles, ["hidden", "online", "reward", "risk"])
	t.eq("every 2.12 rule holds on the fixture", ruling["breaches"], [])

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
		t.check("a door on a line node breaks off-the-line", _breaks(tool.pockets(graph, on_line), "tube_cache", "off_line"))

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
		detour[row["role"]] = row["detour"]
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
	quit(t.verdict())


# The fixture as a stage would carry its pockets. park_test.json predates 2.12 and is KB2's
# file: on its own graph wash_chasers' wash holds the camp's door (readings rule 4: the home
# moves), the cache sits in the tube the relic wakes in, 306 m from the beacon, the altar stands
# on the bench a 6 m sheer step keeps off the graph, neither sealed contraption sits on a
# three-route site, and the cache and altar carry an empty pay (the ladder came later; the
# cache, the larger detour, gets rare and the altar today's common or rare). These overrides touch only home, activity and contraption rows, which
# neither the bake nor the graph reads (no launcher, cable, thermal or lift moves, and no waymark),
# so the committed bake and graph serve them unchanged. The rows sit where tools/park_graph.gd's
# path distances put them inside every 2.12 rule.
static func pocket_fixture(park: Dictionary) -> Dictionary:
	for home in park["home_rows"]:
		if home["id"] == "wash_chasers":
			home["site"] = "lip"
			home["landform"] = "slickrock"
	for act in park["activity_rows"]:
		if act["id"] == "tube_cache":
			act["at"] = [-400, -320]
			act["pay"] = {"rarities": ["rare"]}
		elif act["id"] == "bench_altar":
			act["at"] = [240, -120]
			act["pay"] = {"rarities": ["common", "rare"]}
	for c in park["contraption_rows"]:
		if c["id"] == "tube_wall":
			c["site"] = "pool"
			c["at"] = [-80, 450]
			c["cache"] = {"at": [-86, 456]}
	return park


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
