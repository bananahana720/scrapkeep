extends SceneTree

# SQ15: closures remove real navigation edges and place KC0 greybox solids from the same
# socket record. The paired lab varies landform dimensions and fixed connector masks, using
# SQ13's node membership and zone crossings. No authored park file is changed.
const T := preload("res://tests/support/t.gd")
const MODULE := "res://src/world/park/sockets.gd"
const Recipes := preload("res://src/world/park/park_recipes.gd")
const EXPECTED_CHECKS := 35
var t := T.new("park_sockets_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not t.check("socket builder exists", ResourceLoader.exists(MODULE)):
		t.eq("the test ran its stated check count", t.checks + 1, EXPECTED_CHECKS)
		quit(t.verdict())
		return
	var sockets: GDScript = load(MODULE)
	var layout: Dictionary = sockets.template(17)
	var graph = layout["graph"]
	var original: PackedByteArray = graph.to_bytes()
	t.eq("authored openings validate", sockets.validate(graph, layout["sockets"]), [])
	var made: Dictionary = sockets.stage(layout, 17, "sockets")
	t.check("socket stage builds", made["ok"], str(made["errors"]))
	t.eq("input graph is preserved", graph.to_bytes(), original)
	t.eq("seeded build repeats", sockets.signature(sockets.stage(layout, 17, "sockets")), sockets.signature(made))
	t.check("every zone has 2 to 4 authored openings", made["openings_ok"])
	t.eq("every selected anchor has one open socket", made["one_socket"], made["pocket_count"])
	t.check("guaranteed pockets are off the route", made["off_route"])
	t.check("all fillers are off the shortest route", made["fillers_off_route"])
	t.eq("one filler per closed socket", made["fillers"].size(), made["closed"].size())
	t.check("closures remove navigation edges", made["graph"].edge_count() < graph.edge_count())
	t.near("the shortest route stays open at the same length", made["shortest_m"], graph.d_from[graph.beacon_node])
	t.check("full visit is finite and at most 3.0", made["full_visit_ratio"] <= 3.0)
	t.check("all pockets remain reachable both ways", made["reachable"])
	var parent := Node3D.new()
	root.add_child(parent)
	var placed := 0
	var colliders := 0
	for row in made["fillers"]:
		var node: Node3D = Recipes.place(row, parent)
		if node != null:
			placed += 1
			for body in node.find_children("*", "StaticBody3D", true, false):
				colliders += body.find_children("*", "CollisionShape3D", true, false).size()
	t.eq("every filler places through KC0", placed, made["fillers"].size())
	t.eq("every filler has a collider", colliders, placed)
	parent.free()
	var missing: Array = layout["sockets"].duplicate(true)
	missing.pop_back()
	t.check("control: an unmanaged crossing fails", not sockets.validate(graph, missing).is_empty())
	var bad: Array = layout["sockets"].duplicate(true)
	bad[0]["filler"]["size"] = [0, 8, 8]
	t.check("control: a zero-width filler fails", not sockets.validate(graph, bad).is_empty())
	var poisoned: Dictionary = layout.duplicate(true)
	poisoned["sockets"] = layout["sockets"].duplicate(true)
	for socket in poisoned["sockets"]:
		if layout["pocket_zones"].has(socket["a"]):
			socket["filler"]["size"] = [4000, 8, 4000]
	t.check("control: fillers across the route cannot be closed", not sockets.stage(poisoned, 17, "sockets")["ok"])
	var crowded: Dictionary = layout.duplicate(true)
	crowded["pocket_zones"] = [graph.zone_of(graph.spawn_node)]
	t.check("control: a route zone cannot be a guaranteed pocket", not sockets.stage(crowded, 17, "sockets")["ok"])
	var empty: Dictionary = layout.duplicate(true)
	empty["pocket_zones"] = []
	t.check("control: an empty placement fails", not sockets.stage(empty, 17, "sockets")["ok"])
	t.check("control: zero seeds cannot pass the arm", not sockets.sweep(0)["ok"])
	var swept: Dictionary = sockets.sweep(1000)
	print(sockets.report(swept))
	t.eq("fixed arm runs 1,000 stages", swept["fixed"]["seeds"], 1000)
	t.eq("socket arm runs 1,000 stages", swept["sockets"]["seeds"], 1000)
	t.check("at least 95% of socket seeds meet all stage criteria", swept["sockets"]["success_share"] >= 0.95)
	t.eq("pocket counts are 3 to 8 on every socket seed", swept["sockets"]["count_ok"], 1000)
	t.eq("no guaranteed pocket is on the shortest route", swept["sockets"]["off_route"], 1000)
	t.check("socket re-roll rate is under 10%", swept["sockets"]["reroll_share"] < 0.10)
	t.check("socket re-roll rate is at most half the fixed rate", swept["sockets"]["reroll_share"] <= swept["fixed"]["reroll_share"] * 0.5)
	t.eq("full visit is at most 3.0 on every socket seed", swept["sockets"]["visit_ok"], 1000)
	t.eq("every socket seed has only route-safe fillers", swept["sockets"]["fillers_off_route"], 1000)
	t.eq("each arm retains a per-stage metric row", [swept["fixed"]["rows"].size(), swept["sockets"]["rows"].size()], [1000, 1000])
	t.check("the comparison gate passes", swept["ok"], str(swept["errors"]))
	var weak: Dictionary = swept.duplicate(true)
	weak["sockets"]["success_share"] = 0.94
	weak["sockets"]["reroll_share"] = 0.11
	t.check("control: changed success and re-roll numbers fail the gate", not sockets.gate(weak).is_empty())
	t.eq("the test ran its stated check count", t.checks + 1, EXPECTED_CHECKS)
	quit(t.verdict())
