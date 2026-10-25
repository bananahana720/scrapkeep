extends SceneTree

# Stage 2, park_flume (design-v3/park/stages/2-park_flume.md, K-UNITS KD2): the stage's own pins.
#
# Pinned on the committed file (greybox continuation, 2026-10-12; includes dock level and clearance):
#   freshness  the bake (tools/park_bake.gd) and the graph (tools/park_graph.gd) of
#              src/world/park/park_flume.json are fresh: the hashes in bake.json and graph.json
#              match the park file, the tools and the outputs.
#   ruling     graph.json has no line errors and no pocket breaches, every route is connected
#              through its via rows, and the spawn sits in the farthest quarter.
#   waymarks   drop_in, butte_gap, siphon_camp, landmark, in that order.
#   pockets    siphon_camp is the on-line camp (pays common), bend_cache the reward (rare),
#              bench_bounty the risk (common or rare), weir_valve the hidden valve; the valve's
#              codex id is flume_weir_cache (coordinator ruling R5). Flume pass two (unit 11) adds
#              weir_surge, the opt-in event beside them (the dam's relay's role), and canal_altar,
#              the completionist card's extra risk (card 2; PARK.md 2.12 admits a second one).
#   landmark   penstock_tower, beacon [230, 480]; the Warden row is the reactor kind on the flume
#              mounting with harpoon_anchor true (reactor.md section 3); the pour channel's deck
#              top is the anchor's height (the relic clamps onto the channel, reactor.md 3.2).
#   dock       a cradle within 3 m of the gate ground height and a deck clear at 0 or 18 m lift.
#              --plant-dock inserts a blocking collider before that check, making it fail.
#              cradle and deck use the active park boundary, including a boundary control.
#   lines      every named waypoint of assets/park/park_flume/lines.json resolves on the park
#              file (drop_in, landmark, a waymark, a park row or an activity), every line ends at
#              the landmark, and the six pilots and the floor line are present.
#
# Planted: a copy of the park with butte_gap and siphon_camp swapped in the waymarks, the valve's
# codex id back on the draft's reach_pressure_cache, the Warden on a crown mounting and the pour
# channel back up at y 18 breaks the pins (four failures named); the same copy written to user://
# is stale against the committed bake.

const T := preload("res://tests/support/t.gd")
const ParkBake := preload("res://tools/park_bake.gd")
const GraphTool := preload("res://tools/park_graph.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const Kinds := preload("res://src/core/event_kinds.gd")
const Bay := preload("res://src/world/bay.gd")

const MAP := "park_flume"
const PARK_PATH := "res://src/world/park/park_flume.json"
const BAKE_DIR := "res://assets/park/park_flume"
const LINES_PATH := "res://assets/park/park_flume/lines.json"
const PLANT_PATH := "user://park_flume_plant.json"

const WAYMARKS := ["drop_in", "butte_gap", "siphon_camp", "landmark"]
const POCKETS := {
	"siphon_camp": {"role": "online", "rarities": ["common"]},
	"bend_cache": {"role": "reward", "rarities": ["rare"]},
	"bench_bounty": {"role": "risk", "rarities": ["common", "rare"]},
	"weir_valve": {"role": "hidden"},
	"weir_surge": {"role": "event", "rarities": ["common", "rare"]},
	"canal_altar": {"role": "risk", "rarities": ["common", "rare"]},
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
	if "--docs" in OS.get_cmdline_user_args():
		var output := []
		var script_path := "user://flume_docs_check.py"
		var script := FileAccess.open(script_path, FileAccess.WRITE)
		script.store_string(DOCUMENTATION_CHECK)
		script.close()
		var code := OS.execute("python3", [ProjectSettings.globalize_path(script_path), ProjectSettings.globalize_path("res://")], output, true)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(script_path))
		for line in output:
			print(line)
		t.eq("current documentation derived from qualified seed receipts", code, 0)
		quit(t.verdict())
		return
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
		t.check("spawn in the farthest quarter", bool(info["spawn"]["ok"]) and bool(info["spawn"]["run"]), str(info["spawn"]))
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
	for r in plant["park_rows"]:
		if String(r["id"]) == "pour_channel":
			r["y"] = 18.0
	var planted := pin_failures(plant)
	print("[planted] %s" % "; ".join(planted))
	t.check("planted copy breaks four pins", planted.size() == 4, "%d: %s" % [planted.size(), "; ".join(planted)])
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
	await dock_site_pins()
	await collapse_event_pins()
	quit(t.verdict())


func dock_site_pins() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()
	var terrain = Terrain.new({"DEFS": [{"stage": 1, "world": 1, "map": MAP}]})
	terrain.build(holder)
	terrain.use(1)
	var bay := Bay.new()
	holder.add_child(bay)
	bay.setup(24.0, 14.0)
	await physics_frame
	await physics_frame
	var slots: Array = terrain.map().gate_slots
	var centre := Vector3.ZERO
	for slot in slots:
		var at: Vector2 = slot["at"]
		centre += Vector3(at.x, terrain.height(at.x, at.y), at.y)
	centre /= slots.size()
	var facing: Vector3 = slots[0]["facing"]
	var side := facing.cross(Vector3.UP).normalized()
	var half := 0.0
	for slot in slots:
		var at: Vector2 = slot["at"]
		half = maxf(half, absf((Vector3(at.x, 0, at.y) - centre).dot(side)) + 4.0)
	var mid := centre - facing * (Bay.BACK + Bay.DECK_U)
	var top := -INF
	var footprint_on_park := deck_on_map(mid, facing, side, terrain.map())
	for du in [-Bay.DECK_U, 0.0, Bay.DECK_U]:
		for dv in [-Bay.DECK_V, 0.0, Bay.DECK_V]:
			var p: Vector3 = mid + facing * du + side * dv
			top = maxf(top, terrain.height(p.x, p.z))
	t.check("dock deck footprint is fully on the active park", footprint_on_park)
	var outside_centre := Vector3(700.0, centre.y, 480.0)
	var outside_mid := outside_centre - facing * (Bay.BACK + Bay.DECK_U)
	t.check("boundary control inside 800 m but outside play_rect rejects the dock",
		not deck_on_map(outside_mid, facing, side, terrain.map()))
	var level := false
	for s in [1.0, -1.0]:
		var cradle: Vector3 = centre + side * s * (half + Bay.CRADLE_SIDE)
		var delta: float = absf(terrain.height(cradle.x, cradle.z) - terrain.height(centre.x, centre.z))
		level = level or (Bay._on_map(cradle, terrain.map()) and delta <= 3.0)
		print("[dock site] cradle %s height delta %.3f park on_map %s" % [cradle, delta, Bay._on_map(cradle, terrain.map())])
	t.check("dock cradle is on the active park within 3 m of the gate ground height", level)
	var deck := Vector3(mid.x, top + Bay.LIFT, mid.z)
	bay.facing = facing
	var space := holder.get_world_3d().direct_space_state
	var plant := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(Bay.DECK_U * 2.0, 50.0, Bay.DECK_V * 2.0)
	shape.shape = box
	plant.add_child(shape)
	if "--plant-dock" in OS.get_cmdline_user_args():
		holder.add_child(plant)
		plant.global_position = deck + Vector3.UP * 9.0
		await physics_frame
		await physics_frame
	var clear := not bay._blocked(space, deck) or not bay._blocked(space, deck + Vector3.UP * 18.0)
	t.check("dock deck is clear at an allowed lift", clear, "deck %s; bay.gd collision query at 0 or 18 m" % deck)
	if plant.get_parent() == null:
		holder.add_child(plant)
		plant.global_position = deck + Vector3.UP * 9.0
		await physics_frame
		await physics_frame
	var planted_clear := not bay._blocked(space, deck) or not bay._blocked(space, deck + Vector3.UP * 18.0)
	print("[planted dock] level-and-clearance pin %s" % ("GREEN" if planted_clear else "RED"))
	t.check("a planted collider blocks both allowed dock lifts", not planted_clear)
	holder.free()


static func deck_on_map(mid: Vector3, facing: Vector3, side: Vector3, map: RefCounted) -> bool:
	for du in [-Bay.DECK_U, 0.0, Bay.DECK_U]:
		for dv in [-Bay.DECK_V, 0.0, Bay.DECK_V]:
			var p: Vector3 = mid + facing * du + side * dv
			if not Bay._on_map(p, map):
				return false
	return true


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
		# The on-line activity and an opt-in event keep only the sight and the clear ring (PARK.md 2.12).
		if role == "online" or role == "event":
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
		# The detour order ranks the first pair; a card 2 extra keeps the distance rules only.
		if not detours.has(role):
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
	# The relic clamps onto the pour channel (reactor.md section 3.2): the channel's deck top is the anchor's height.
	var deck := INF
	for r in park["park_rows"]:
		if String(r["id"]) == "pour_channel" and r.get("y") != null:
			deck = float(r["y"]) + float(r["size"][1])
	if not is_equal_approx(deck, float(w["anchor"][1])):
		out.append("pour_channel deck top %s, want the warden anchor's %s" % [deck, w["anchor"][1]])
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


func span_clearance_pins() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.presentation.audio.bake_now()
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	game.flow.enter_stage(2, Vector3.ZERO, false)
	await physics_frame
	await physics_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var world = game.world
	var director = world.events
	director._park_states = director._park_states.filter(func(s): return s.row.id == "hollow_trestle_collapse")
	var state: Dictionary = director._park_states[0]
	var intact := intact_span_heights(world)
	var deck_y: float = intact[2]
	var centre := Vector3(-115.0, deck_y, 5.5)
	var along := Vector3(sin(deg_to_rad(30.6)), 0.0, cos(deg_to_rad(30.6)))
	var across := Vector3(cos(deg_to_rad(30.6)), 0.0, -sin(deg_to_rad(30.6)))
	var context := {"clock_tier": 2, "grounded": true, "bar_s": 240.0 / 172.0, "bar_origin_s": 0.0}
	var warning_checked := false
	for step in 260:
		world._publish(director.advance(0.05, centre, Vector3.ZERO, context))
		if not warning_checked and world.event_families.natural.active.has(state.row.id):
			warning_checked = true
			var record: Dictionary = world.event_families.natural.active[state.row.id]
			t.eq("span retains authored event site", state.row.site, "trestle_hollow")
			t.check("warning record uses span centre", record.geometry.at.distance_to(centre) < 0.001)
			t.check("warning record uses span half extents", record.geometry.half.distance_to(Vector2(4.0, 186.5)) < 0.001)
			var outline: MeshInstance3D = record.mark.get_node("Footprint").get_child(0)
			var vertices: PackedVector3Array = outline.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var low := Vector2.INF
			var high := -Vector2.INF
			var deck_agrees := not vertices.is_empty()
			var warning_above_intact := not vertices.is_empty()
			for vertex: Vector3 in vertices:
				var delta: Vector3 = outline.global_transform * vertex - record.mark.position - centre
				var local := Vector2(delta.dot(across), delta.dot(along))
				low = low.min(local)
				high = high.max(local)
				deck_agrees = deck_agrees and absf(delta.y) < 0.001
				var warning_y: float = (outline.global_transform * vertex).y
				warning_above_intact = warning_above_intact and warning_y > deck_y and warning_y - deck_y <= 0.2
			t.check("warning footprint matches physical span", low.distance_to(Vector2(-4.0, -186.5)) < 0.01 and high.distance_to(Vector2(4.0, 186.5)) < 0.01)
			t.check("warning projects onto baseline deck", deck_agrees)
			t.check("warning lies above independently measured intact top within 0.2 m", warning_above_intact)
	t.check("span midpoint holds landing after due time", warning_checked and state.phase == director.ANNOUNCED and director.stage_time > state.due_s)
	var low_end: Vector3 = centre + along * 176.5
	var crossing: Vector3 = centre + across * 45.0
	for spec in [["low end", low_end, Vector3.ZERO], ["two second crossing", crossing, -across * 30.0], ["20 m margin", centre + across * 23.0, Vector3.ZERO]]:
		for step in 40:
			world._publish(director.advance(0.05, spec[1], spec[2], context))
		t.eq("span " + spec[0] + " holds landing", state.phase, director.ANNOUNCED)
	var clear := Vector3(600.0, deck_y, -600.0)
	for step in 80:
		world._publish(director.advance(0.05, clear, Vector3.ZERO, context))
		if state.phase == director.LIVE:
			break
	t.eq("span releases landing after clearance", state.phase, director.LIVE)
	world._publish(director.advance(0.5, clear, Vector3.ZERO, context))
	var swap: Dictionary = world.terrain.map().swaps["trestle_ramp"]
	t.check("clearance pause tested during partial fall", float(swap.progress) > 0.0 and float(swap.progress) < 1.0)
	for spec in [["midpoint", centre, Vector3.ZERO], ["low end", low_end, Vector3.ZERO], ["two second crossing", crossing, -across * 30.0]]:
		var before: float = swap.progress
		var vertices: PackedVector3Array = swap.surface.vertices if swap.has("surface") else swap.body.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		world._publish(director.advance(0.25, spec[1], spec[2], context))
		t.eq("span " + spec[0] + " pauses fall progress", float(swap.progress), before)
		t.eq("span " + spec[0] + " keeps physical mesh while held", swap.body.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], vertices)
	var before: float = swap.progress
	world._publish(director.advance(0.1, clear, Vector3.ZERO, context))
	t.check("span fall resumes after clearance", float(swap.progress) > before)
	game.free()


func collapse_event_pins() -> void:
	await span_clearance_pins()
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.presentation.audio.bake_now()
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	game.flow.enter_stage(2, Vector3.ZERO, false)
	await physics_frame
	await physics_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var world = game.world
	var registered := []
	for state in world.events._park_states:
		registered.append(state.row.id)
	t.check("real stage registers collapse and reactor", registered.has("hollow_trestle_collapse") and registered.has("annex_reactor_blow"))
	var facts_seen := []
	var times := {}
	var land_s := -1.0
	var observations := {}
	var intact := intact_span_heights(world)
	var floor_y := baked_floor(Vector2(-115.0, 5.5))
	var authored: Dictionary = world.terrain.map().park.event_rows.filter(func(r): return r.id == "hollow_trestle_collapse")[0]
	t.check("collapse depth independently matches committed floor", absf(float(authored.effect.depth_m) - (float(intact[2]) - floor_y)) < 0.00001)
	t.eq("collapse authorized fill seconds", float(authored.effect.fill_s), 2.0)
	for phase in ["telegraph", "land"]:
		t.check("authored collapse " + phase + " music cue available", not MusicRows.cue(authored.music_cue[phase]).is_empty())
	t.check("unknown cue control rejected", MusicRows.cue("flume_missing_cue_control").is_empty())
	var reactor_live_at_land := false
	var ball: Vector3 = game.player.ball_position()
	for step in 2400:
		var context := {"clock_tier": 2, "grounded": false, "bar_s": 240.0 / 172.0, "bar_origin_s": 0.0,
			"warden_phases": ["chunk_2"] if step == 0 else []}
		var facts: Array = world.events.advance(0.05, ball, Vector3.ZERO, context)
		world._publish(facts)
		for fact in facts:
			if fact.id not in ["hollow_trestle_collapse", "annex_reactor_blow"]:
				continue
			print("[flume event] ", JSON.stringify(fact))
			if fact.has("fact"):
				facts_seen.append(fact.fact)
				times[fact.fact] = fact.time_s
			if fact.kind == "started" and fact.id == "annex_reactor_blow":
				var active: Dictionary = world.event_families.industrial.active.get(fact.id, {})
				reactor_live_at_land = not active.is_empty() and active.hazard.is_live() and world.events.route_open("annex_ramp_line")
			if fact.kind == "started" and fact.id == "hollow_trestle_collapse":
				land_s = fact.time_s
		if land_s >= 0.0:
			var elapsed: float = world.events.stage_time - land_s
			for sample in [0.0, 0.5, 1.0, 2.0]:
				if not observations.has(sample) and elapsed + 0.00001 >= sample:
					observations[sample] = true
					observe_span(world, elapsed, floor_y, intact)
			if elapsed + 0.00001 >= 2.0:
				break
	for spec in [["trestle_groan", "trestle_landed", 6.0], ["reactor_overload", "reactor_landed", 5.0]]:
		t.check(spec[0] + " telegraph and land facts", facts_seen.count(spec[0]) == 1 and facts_seen.count(spec[1]) == 1)
		t.check(spec[0] + " authored lead", float(times.get(spec[1], -1000.0)) - float(times.get(spec[0], 0.0)) >= float(spec[2]))
		t.check(spec[0] + " presentation uses common kind records", not Kinds.world_row(spec[0]).is_empty() and not Kinds.world_row(spec[1]).is_empty())
	t.check("collapse route flags", world.events.route_open("trestle_ramp_line") and not world.events.route_open("flume_mid"))
	t.check("reactor fallout and annex route at land", reactor_live_at_land)
	var map = world.terrain.map()
	var swap: Dictionary = map.swaps.get("trestle_ramp", {}) if "swaps" in map else {}
	if t.check("collapse has a physical swapped surface", not swap.is_empty() and swap.has("target")):
		t.check("collapse fully lands in two seconds", is_equal_approx(float(swap.progress), 1.0) and swap.body.visible)

	t.eq("physical fall sampled at four elapsed times", observations.size(), 4)
	game.free()


static func collider_y(faces: PackedVector3Array, point: Vector2) -> float:
	for k in range(0, faces.size(), 3):
		var a := faces[k]
		var b := Vector2(faces[k + 1].x - a.x, faces[k + 1].z - a.z)
		var c := Vector2(faces[k + 2].x - a.x, faces[k + 2].z - a.z)
		var d := point - Vector2(a.x, a.z)
		var determinant := b.cross(c)
		if absf(determinant) < 0.0000001:
			continue
		var u := d.cross(c) / determinant
		var v := b.cross(d) / determinant
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			return a.y + u * (faces[k + 1].y - a.y) + v * (faces[k + 2].y - a.y)
	return -INF


static func highest_triangle_y(faces: PackedVector3Array, transform: Transform3D, point: Vector2) -> float:
	var highest := -INF
	for k in range(0, faces.size(), 3):
		var triangle := PackedVector3Array([transform * faces[k], transform * faces[k + 1], transform * faces[k + 2]])
		highest = maxf(highest, collider_y(triangle, point))
	return highest


func intact_span_heights(world) -> Array:
	var body: Node3D = world.terrain.geometry_root(world.terrain.stage).find_child("Park_flume_hollow_reach", true, false)
	var mesh_nodes := body.find_children("*", "MeshInstance3D", true, false)
	var colliders := body.find_children("*", "CollisionShape3D", true, false)
	var centre := Vector2(-115.0, 5.5)
	var axis := Vector2.DOWN.rotated(-deg_to_rad(30.6))
	var heights := []
	for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var point: Vector2 = centre + axis * (fraction - 0.5) * 373.0
		var mesh_top := -INF
		var collider_top := -INF
		for view: MeshInstance3D in mesh_nodes:
			mesh_top = maxf(mesh_top, highest_triangle_y(view.mesh.get_faces(), view.global_transform, point))
		for collider: CollisionShape3D in colliders:
			if not collider.get_parent() is StaticBody3D:
				continue
			var faces := PackedVector3Array()
			if collider.shape is BoxShape3D:
				var box := BoxMesh.new()
				box.size = collider.shape.size
				faces = box.get_faces()
			elif collider.shape is ConcavePolygonShape3D:
				faces = collider.shape.get_faces()
			collider_top = maxf(collider_top, highest_triangle_y(faces, collider.global_transform, point))
		print("[intact top] fraction %.2f mesh %.6f collider %.6f" % [fraction, mesh_top, collider_top])
		t.check("independent intact mesh/collider top %.2f" % fraction, is_finite(mesh_top) and is_finite(collider_top) and absf(mesh_top - collider_top) < 0.001)
		heights.append(mesh_top)
	return heights


static func baked_floor(point: Vector2) -> float:
	var bake: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BAKE_DIR + "/bake.json"))
	var grid: Dictionary = bake.grid
	var f := FileAccess.open_compressed(BAKE_DIR + "/ground.bin", FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	var side := int(grid.side)
	var heights := f.get_buffer(side * side * 4).to_float32_array()
	var cell := (point + Vector2.ONE * float(grid.half_m)) / float(grid.step_m)
	var i := floori(cell.x)
	var j := floori(cell.y)
	var u := cell.x - i
	var v := cell.y - j
	var a := heights[j * side + i]
	var b := heights[j * side + i + 1]
	var c := heights[(j + 1) * side + i]
	var d := heights[(j + 1) * side + i + 1]
	var y := a + (b - a) * u + (c - a) * v if u + v <= 1.0 else d + (c - d) * (1.0 - u) + (b - d) * (1.0 - v)
	print("[independent floor] ", JSON.stringify({"grid": grid, "cell": [i, j], "fraction": [u, v], "vertices": [a, b, c, d], "floor_y": y}))
	return y


func observe_span(world, elapsed: float, floor_y: float, intact: Array) -> void:
	var swap: Dictionary = world.terrain.map().swaps.get("trestle_ramp", {})
	if not t.check("span exists at elapsed %.2f" % elapsed, not swap.is_empty()):
		return
	var faces: PackedVector3Array = swap.body.get_child(1).shape.get_faces()
	var view: MeshInstance3D = swap.body.get_child(0)
	var mesh_vertices: PackedVector3Array = view.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for k in faces.size():
		faces[k] = swap.body.global_transform * faces[k]
	for k in mesh_vertices.size():
		mesh_vertices[k] = view.global_transform * mesh_vertices[k]
	var centre := Vector2(-115.0, 5.5)
	var axis := Vector2.DOWN.rotated(-deg_to_rad(30.6))
	var progress := clampf(elapsed / 2.0, 0.0, 1.0)
	for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var point: Vector2 = centre + axis * (fraction - 0.5) * 373.0
		var original: float = intact[int(round(fraction * 4.0))]
		var expected: float = original - (original - floor_y) * fraction * progress
		var drawn := collider_y(mesh_vertices, point)
		var physical := collider_y(faces, point)
		print("[fallen ramp] elapsed %.2f fraction %.2f xz %s expected %.6f mesh %.6f collider %.6f" % [elapsed, fraction, point, expected, drawn, physical])
		if elapsed < 0.00001:
			t.check("replacement starts continuously from intact top %.2f" % fraction, absf(drawn - original) < 0.001 and absf(physical - original) < 0.001)
		t.check("fallen ramp mesh %.2f at %.2fs" % [fraction, elapsed], absf(drawn - expected) < 0.05)
		t.check("fallen ramp collider %.2f at %.2fs" % [fraction, elapsed], absf(physical - expected) < 0.05)


const DOCUMENTATION_CHECK := """
import hashlib,json,re,statistics,sys
from pathlib import Path
sk=Path(sys.argv[1]); pages=[sk/'design-v3/park/stages/2-park_flume.md',sk/'design-v3/park/traversal/park_flume.md']
texts=[p.read_text() for p in pages]
def block(text,start,end):
 assert text.count(start)==1, 'missing or duplicate current publication block'
 tail=text.split(start,1)[1]
 assert end in tail, 'missing publication block end'
 if end!='-->':assert text.count(end)==1, 'duplicate publication block end'
 return tail.split(end,1)[0].strip()
blocks=[block(t,'<!-- flume-current-table -->','<!-- /flume-current-table -->') for t in texts]
assert blocks[0]==blocks[1], 'current pages mismatch'
b=blocks[0]
assert not re.search(r'pending|BLOCKED|unqualified population',b,re.I),'pending current cell'
meta=json.loads(block(b,'<!-- flume-current-receipts','-->'))
p=Path(meta['receipt_root']); tool=sk/'tools/traversal_line.gd'
assert meta['tool_sha256']==hashlib.sha256(tool.read_bytes()).hexdigest(),'wrong committed tool hash'
assert re.fullmatch('[a-f0-9]{40}',meta['head']),'missing measured head'
inputs={str(f.relative_to(sk.parent.parent)):hashlib.sha256(f.read_bytes()).hexdigest() for d in ['src','tools','assets/park/park_flume'] for f in (sk/d).rglob('*') if f.is_file()}
keys=['sable','rivet','kest','tarn','tally','cannon','floor'];pop={}
for k in keys:
 manifest=json.loads((p/('population-'+k+'-inputs.json')).read_text())
 assert manifest==inputs,'rejected or stale runtime inputs '+k
 folder=p/'population'/k
 data=json.loads((folder/(k+'.json')).read_text()); rows=data['runs'];pop[k]=rows
 assert sorted(r['seed'] for r in rows)==list(range(1,9)), 'missing seeds '+k
 assert data['commit']==meta['head'],'wrong measured head '+k
 logs=list((folder/'children').glob('*/child.log'))
 assert len(logs)==8,'missing child logs '+k
 for r in rows:
  child=next((folder/'children').glob('*-seed-'+str(r['seed'])))
  log=(child/'child.log').read_text()
  assert not any('SCRIPT ERROR' in x or x.startswith('ERROR:') for x in log.splitlines()),'rejected population '+k
  assert json.loads((child/(k+'.json')).read_text())['runs']==[r], 'summary differs from seed receipt '+k
 assert str(folder/(k+'.json')) in b,'missing population provenance '+k
for k,seed in [('sable',1),('rivet',5),('sable',4),('tally',5),('floor',1)]:
 row=next(r for r in pop[k] if r['seed']==seed)
 for mode in ['plain','trace']:
  name='solo-'+k+str(seed)+'-'+mode;folder=p/'solos'/name
  assert (folder/(k+'.json')).exists(),'incomplete named replay '+name
  assert json.loads((folder/(k+'.json')).read_text())['runs']==[row],'named replay differs from batch '+name
  assert json.loads((p/(name+'-inputs.json')).read_text())==inputs,'named replay runtime inputs differ '+name
  logs=list((folder/'children').glob('*/child.log'))
  assert len(logs)==1,'missing named replay child log '+name
  assert not any('SCRIPT ERROR' in x or x.startswith('ERROR:') for x in logs[0].read_text().splitlines()),'rejected named replay '+name
  if mode=='trace':
   assert (folder/(k+'-seed-'+str(seed)+'-trace.json')).exists(),'missing named replay trace '+name
print('NAMED REPLAY QUALIFICATION: PASS (5/5 batch/plain/traced comparisons)')
import math

def directed_share(a,b):
 bins={}
 for x,z in b:
  bins.setdefault((math.floor(x/8),math.floor(z/8)),[]).append((x,z))
 hits=0
 for x,z in a:
  i,j=math.floor(x/8),math.floor(z/8)
  hits+=any((x-u)**2+(z-v)**2<=64 for di in [-1,0,1] for dj in [-1,0,1] for u,v in bins.get((i+di,j+dj),[]))
 return hits/len(a)

def distinct_lines(paths):
 shares={(a,b):directed_share(paths[a],paths[b]) for a in paths for b in paths if a!=b}
 return shares,all(v<.5 for v in shares.values())

selected=[('sable',1),('rivet',5),('tally',5)]
paths={}
for k,seed in selected:
 name='solo-'+k+str(seed)+'-trace'
 receipt=p/'solos'/name/(k+'-seed-'+str(seed)+'-trace.json')
 trace=json.loads(receipt.read_text())
 assert trace['pilot']==k and trace['seed']==seed,'wrong distinct-line trace identity '+name
 ticks=trace['ticks']
 assert ticks,'empty distinct-line trace '+name
 paths[k]=[(t['at'][0],t['at'][2]) for t in ticks]
 assert str(receipt) in b,'missing distinct-line receipt '+name
shares,distinct=distinct_lines(paths)
assert distinct,'fewer than three mutually distinct lines'
assert 'Mutually distinct lines: sable / seed 1, rivet / seed 5, tally / seed 5; PASS.' in b,'missing current distinct-line result'
for (a,c),share in shares.items():
 line='| '+a+' → '+c+' | '+format(share,'.5f')+' |'
 assert b.count(line)==1,'missing or wrong directed overlap '+a+' to '+c
control=dict(paths);control['tally']=paths['sable']
assert not distinct_lines(control)[1],'duplicated-path negative control accepted'
print('CURRENT DISTINCT LINES: PASS (3 mutually distinct, maximum directed share '+format(max(shares.values()),'.5f')+'; duplicated-path control rejected)')

stops=json.loads((p/'stop-classification.json').read_text())
raw_stops=[(k,r['seed'],s) for k,rows in pop.items() for r in rows for s in r['dead_stop_at']]
assert len(stops)==len(raw_stops),'missing stop classification'
for k,seed,s in raw_stops:
 matches=[x for x in stops if x['pilot']==k and x['seed']==seed and x['time_s']==s['time']]
 assert len(matches)==1,'unmatched stop'
 item=matches[0];assert item['qualified'],'unqualified stop receipt'
 trace=Path(item['receipt']); traced=json.loads((trace.parent/(k+'.json')).read_text())['runs']
 row=next(r for r in pop[k] if r['seed']==seed)
 assert traced==[row],'stop traced row mismatch'
 plain=Path(item['plain_receipt']);probe=Path(item['probe_receipt'])
 assert json.loads(plain.read_text())['runs']==[row],'stop plain row mismatch'
 assert json.loads((probe.parent/(k+'.json')).read_text())['runs']==[row],'stop probe row mismatch'
 ticks=json.loads(trace.read_text())['ticks'];observed=json.loads((probe.parent/(k+'-seed-'+str(seed)+'-trace.json')).read_text())['ticks']
 assert ticks==observed,'stop probe changes trace'
 for folder in [trace.parent,plain.parent,probe.parent]:
  logs=list((folder/'children').glob('*/child.log'))
  assert len(logs)==1,'missing solo child log'
  assert not any('SCRIPT ERROR' in x or x.startswith('ERROR:') for x in logs[0].read_text().splitlines()),'unqualified solo log'
 increments=[tick for i,tick in enumerate(ticks) if tick['dead_stops']>(ticks[i-1]['dead_stops'] if i else 0)]
 stop=next(tick for tick in increments if abs(tick['time']-s['time'])<.02)
 contacts=[body for observation in json.loads(probe.read_text())['contacts'] if stop['tick']-90<=observation['tick']<=stop['tick'] for body in observation['bodies']]
 enemy=[body for body in contacts if body.get('kind') and body.get('spawn',{}).get('director')]
 assert item['classification']==('pack' if enemy else 'terrain'),'unsupported stop classification'
 if enemy:
  assert item['enemy_kind'] in [body['kind'] for body in enemy],'wrong enemy kind'
  assert item['provenance']==('home' if any(body['spawn'].get('home_ids') for body in enemy) else 'director'),'wrong spawning provenance'
 assert str(trace) in b and item['classification'] in b,'stop missing from publication'
 if item['classification']=='pack':
  assert item.get('enemy_kind') and item.get('provenance') in ['home','director'],'anonymous pack exemption'
labels=['Reached Warden, 8/8','Time s, median 60–120; worst ≤150','Segments s, each median 12–45','Flow, median ≥.70; worst ≥.60','Airborne, median .12–.45','Terrain or unclassified stops, every seed 0','Peak m/s, worst ≥26.6','Tier-3 s, median ≥3','Quiet s, worst ≤20','Anchor gap m, worst ≤40','Ride facts, worst ≥3','Length ratio, median 1.3–2.0','Floor, ≤2× Rivet median; zero terrain stops']
expected={l:{} for l in labels}
def f(x):
 if isinstance(x,list):return '['+', '.join(f(v) for v in x)+']'
 return str(round(x,5)) if isinstance(x,float) else str(x)
for k,rs in pop.items():
 med=lambda field:statistics.median(r[field] for r in rs)
 lo=lambda field:min(r[field] for r in rs)
 hi=lambda field:max(r[field] for r in rs)
 terrain=[r['dead_stops']-sum(s['pilot']==k and s['seed']==r['seed'] and s['classification']=='pack' and s['qualified'] for s in stops) for r in rs]
 segments=[statistics.median(r['segments_s'][i] for r in rs) for i in range(3)]
 vals=[(sum(r['reached_warden'] for r in rs),8,all(r['reached_warden'] for r in rs)),(med('time_to_warden_s'),hi('time_to_warden_s'),60<=med('time_to_warden_s')<=120 and hi('time_to_warden_s')<=150),(segments,[max(r['segments_s'][i] for r in rs) for i in range(3)],all(12<=v<=45 for v in segments)),(med('flow_share'),lo('flow_share'),med('flow_share')>=.7 and lo('flow_share')>=.6),(med('airborne_share'),[lo('airborne_share'),hi('airborne_share')],.12<=med('airborne_share')<=.45),(statistics.median(terrain),max(terrain),max(terrain)==0),(med('peak_speed_mps'),lo('peak_speed_mps'),lo('peak_speed_mps')>=26.6),(med('tier3_s'),lo('tier3_s'),med('tier3_s')>=3),(med('quiet_max_s'),hi('quiet_max_s'),hi('quiet_max_s')<=20),(med('max_anchor_gap_m'),hi('max_anchor_gap_m'),hi('max_anchor_gap_m')<=40),(med('distinct_ride_facts'),lo('distinct_ride_facts'),lo('distinct_ride_facts')>=3),(med('length_ratio'),[lo('length_ratio'),hi('length_ratio')],1.3<=med('length_ratio')<=2)]
 for i,(m,w,ok) in enumerate(vals):
  expected[labels[i]][k]=f(m)+' / '+f(w)+( ", reported, pilot band, not the floor's" if k=='floor' and i not in [0,5] else ' '+('pass' if ok else 'MISS'))
 expected[labels[-1]][k]='not applicable'
 if k=='floor':
  cap=2*statistics.median(r['time_to_warden_s'] for r in pop['rivet'])
  ok=all(r['reached_warden'] for r in rs) and max(terrain)==0 and hi('time_to_warden_s')<=cap
  expected[labels[-1]][k]=f(med('time_to_warden_s'))+' / max '+f(hi('time_to_warden_s'))+'; cap '+f(cap)+' '+('pass' if ok else 'MISS')
assert '| Band | '+' | '.join(keys)+' |' in b,'missing complete table header'
for label in labels:
 line='| '+label+' | '+' | '.join(expected[label][k] for k in keys)+' |'
 assert b.count(line)==1,'missing, duplicate or wrong measured row: '+label
assert meta['head'] in b and meta['tool_sha256'] in b,'missing provenance'
for seed in [1,2,3]:
 receipt=p/('win-seed-'+str(seed))/'bots.ndjson'
 raw=json.loads(receipt.read_text().splitlines()[-1]);stage=next(x for x in raw['stages'] if x['stage']==2)
 engage=stage['warden_engaged_s']; broken=stage['warden_broken_s']
 line='| %s | %s | %s | %s | %s | %s | `%s` |'%(seed,engage,broken if broken is not None else 'not broken in 600 s',round(broken-engage,2) if broken is not None and engage is not None else 'not applicable',raw['outcome'],stage.get('stall_state',''),receipt)
 assert line in b,'win values differ from saved seed receipt '+str(seed)
 assert not any('SCRIPT ERROR' in x or x.startswith('ERROR:') for x in (p/('win-'+str(seed)+'.log')).read_text().splitlines()),'unqualified win receipt'
print('CURRENT DOCUMENTATION: PASS (56 qualified seed rows, 13 complete measured bands, matching pages, saved win values)')
"""
