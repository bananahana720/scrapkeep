# smoke: solo timeout=360s (paired 1,000-stage graph sweeps)
extends SceneTree

# SQ15: closures remove real navigation edges and place KC0 greybox solids from the same
# socket record. The paired lab varies landform dimensions and fixed connector masks, using
# SQ13's node membership and zone crossings. No authored park file is changed.
const T := preload("res://tests/support/t.gd")
const MODULE := "res://src/world/park/sockets.gd"
const Recipes := preload("res://src/world/park/park_recipes.gd")
# 2026-10-12: round 2 opening/accounting fixtures raise the count from 41 to 65.
const EXPECTED_CHECKS := 65
var t := T.new("park_sockets_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not t.check("socket builder exists", ResourceLoader.exists(MODULE)):
		t.eq("the test ran its stated check count", t.checks + 1, EXPECTED_CHECKS)
		quit(t.verdict())
		return
	var sockets: GDScript = load(MODULE)
	for arg in OS.get_cmdline_user_args():
		if arg == "--fixture=accounting":
			_accounting_controls(sockets)
			t.eq("accounting fixture check count", t.checks + 1, 18)
			quit(t.verdict())
			return
		if arg == "--fixture=openings":
			_opening_controls(sockets)
			t.eq("opening fixture check count", t.checks + 1, 11)
			quit(t.verdict())
			return
	var layout: Dictionary = sockets.template(17)
	var graph = layout["graph"]
	var original: PackedByteArray = graph.to_bytes()
	t.eq("authored openings validate", sockets.validate(graph, layout["sockets"]), [])
	var made: Dictionary = sockets.stage(layout, 17, "sockets")
	t.check("socket stage builds", made["ok"], str(made["errors"]))
	t.check("input graph is preserved", graph.to_bytes() == original)
	t.eq("seeded build repeats", sockets.signature(sockets.stage(layout, 17, "sockets")), sockets.signature(made))
	t.check("every zone has 2 to 4 authored openings", _opening_counts(graph, layout["sockets"]).all(func(n): return n >= 2 and n <= 4))
	_opening_controls(sockets)
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
	await physics_frame
	await physics_frame
	var closed_hits := 0
	var open_hits := 0
	for socket in layout["sockets"]:
		var link: Array = socket["links"][0]
		var query := PhysicsRayQueryParameters3D.create(graph.position(link[0]) + Vector3.UP * 4,
			graph.position(link[1]) + Vector3.UP * 4)
		var hit := not parent.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		if made["closed"].has(socket["id"]):
			closed_hits += 1 if hit else 0
		else:
			open_hits += 1 if hit else 0
	t.eq("every closed opening blocks a physics ray", closed_hits, placed)
	t.eq("every retained opening stays physically open", open_hits, 0)
	t.eq("SQ13 sees every selected pocket as a viable anchor", made["graph"].anchors().filter(func(a): return a["rank"] > 0).size(), made["pocket_count"])
	parent.free()
	var missing: Array = layout["sockets"].duplicate(true)
	missing.pop_back()
	t.check("control: an unmanaged crossing fails", not sockets.validate(graph, missing).is_empty())
	var bad: Array = layout["sockets"].duplicate(true)
	bad[0]["filler"]["size"] = [0, 8, 8]
	t.check("control: a zero-width filler fails", not sockets.validate(graph, bad).is_empty())
	var raised: Array = layout["sockets"].duplicate(true)
	raised[0]["filler"]["y"] = 50
	t.check("control: a filler above its opening fails", not sockets.validate(graph, raised).is_empty())
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
	var duplicate: Dictionary = layout.duplicate(true)
	duplicate["pocket_zones"] = [layout["pocket_zones"][0], layout["pocket_zones"][0], layout["pocket_zones"][0]]
	t.check("control: duplicate zones cannot count as three pockets", not sockets.stage(duplicate, 17, "sockets")["ok"])
	var one_way: Dictionary = sockets.template(17)
	var outgoing := {}
	for socket in one_way["sockets"]:
		var retained := []
		for link in socket["links"]:
			if one_way["pocket_zones"].has(one_way["graph"].zone_of(link[0])):
				outgoing[link[0] * one_way["graph"].node_count() + link[1]] = true
			else:
				retained.append(link)
		socket["links"] = retained
	one_way["graph"] = sockets._overlay(one_way["graph"], outgoing)
	t.check("control: incoming-only sockets cannot trap a player", not sockets.stage(one_way, 17, "sockets")["ok"])
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
	_accounting_controls(sockets)
	t.eq("the test ran its stated check count", t.checks + 1, EXPECTED_CHECKS)
	quit(t.verdict())


func _opening_counts(graph, records: Array) -> Array:
	var counts := []
	counts.resize(graph.zone_count())
	counts.fill(0)
	for socket in records:
		counts[socket["a"]] += 1
		counts[socket["b"]] += 1
	return counts


func _opening_fixture(sockets: GDScript, count: int) -> Dictionary:
	if count == 5:
		var layout: Dictionary = sockets.template(17)
		var split: Dictionary = layout["sockets"].pop_front()
		for i in 2:
			var record: Dictionary = split.duplicate(true)
			record["id"] = "split_%d" % i
			record["links"] = split["links"].slice(i * 2, i * 2 + 2)
			layout["sockets"].append(record)
		return layout
	var builder = sockets.LabBuilder.new()
	builder.zone(0, true)
	builder.zone(1, false)
	for i in count:
		builder.node(i * 16, 0, 0, sockets.Graph.OPEN)
		builder.node(i * 16, 8, 1, sockets.Graph.OPEN)
		builder.link_at(i * 16, 0, i * 16, 8)
		builder.socket("boundary_%d" % i, 0, 1, [[i * 16, 0, i * 16, 8]],
			sockets._filler("boundary_%d" % i, [i * 16, 4], [4, 8, 4]), true)
	return {"graph": builder.finish(), "sockets": builder.sockets, "pocket_zones": []}


func _opening_controls(sockets: GDScript) -> void:
	for count in [2, 4]:
		var valid := _opening_fixture(sockets, count)
		t.eq("boundary fixture has exactly %d openings per zone" % count, _opening_counts(valid["graph"], valid["sockets"]), [count, count])
		t.eq("boundary %d openings validates" % count, sockets.validate(valid["graph"], valid["sockets"]), [])
	for count in [1, 5]:
		var invalid := _opening_fixture(sockets, count)
		var counts := _opening_counts(invalid["graph"], invalid["sockets"])
		t.eq("invalid fixture reaches exactly %d openings" % count, counts.max(), count)
		var expected := ["zone route_0 has 1 openings, expected 2 to 4", "zone landform_1 has 1 openings, expected 2 to 4"] if count == 1 else ["zone route_1 has 5 openings, expected 2 to 4"]
		t.eq("otherwise valid %d-opening fixture fails only the opening range" % count, sockets.validate(invalid["graph"], invalid["sockets"]), expected)
		if count == 5:
			t.eq("five openings also reject stage construction for the range", sockets.stage(invalid, 1, "sockets")["errors"], expected)


func _arm_fixture(failed: int) -> Dictionary:
	var arm := {"seeds": 100, "successes": 100 - failed, "rerolls": failed,
		"success_share": float(100 - failed) / 100, "reroll_share": float(failed) / 100,
		"count_ok": 100, "off_route": 100, "visit_ok": 100, "fillers_off_route": 100, "rows": []}
	for seed_value in range(1, 101):
		arm["rows"].append({"seed": seed_value, "reroll": seed_value <= failed})
	return arm


func _accounting_controls(sockets: GDScript) -> void:
	var clean := {"fixed": _arm_fixture(20), "sockets": _arm_fixture(0)}
	t.eq("control: consistent accounting passes", sockets.gate(clean), [])
	for arm in ["fixed", "sockets"]:
		for field in ["rerolls", "successes", "success_share", "reroll_share"]:
			var inconsistent: Dictionary = clean.duplicate(true)
			inconsistent[arm][field] += 1 if field in ["rerolls", "successes"] else 0.01
			t.check("control: %s %s must match rows" % [arm, field], sockets.gate(inconsistent).has("%s %s disagrees with rows" % [arm, field]))
		var short_rows: Dictionary = clean.duplicate(true)
		short_rows[arm]["rows"].pop_back()
		t.check("control: %s row count must match seeds" % arm, sockets.gate(short_rows).has("%s row count disagrees with seeds" % arm))
		var wrong_seed: Dictionary = clean.duplicate(true)
		wrong_seed[arm]["rows"][1]["seed"] = 1
		t.check("control: %s seed identity must be exact" % arm, sockets.gate(wrong_seed).has("%s rows must identify seeds 1 through 100 exactly" % arm))
	var boundary := {"fixed": _arm_fixture(20), "sockets": _arm_fixture(10)}
	t.check("control: exactly 10 percent fails the strict rate boundary", sockets.gate(boundary).has("socket re-roll rate is not under 10%"))
	var above_half := {"fixed": _arm_fixture(6), "sockets": _arm_fixture(4)}
	t.eq("control: a rate above half fixed fails independently", sockets.gate(above_half), ["socket re-roll rate exceeds half the fixed rate"])
	var equal_half := {"fixed": _arm_fixture(8), "sockets": _arm_fixture(4)}
	t.eq("control: exactly half fixed passes", sockets.gate(equal_half), [])
