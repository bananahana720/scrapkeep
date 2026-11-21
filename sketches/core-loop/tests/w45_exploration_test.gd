extends SceneTree
# smoke: solo timeout=300s (reads both world 1 graphs, then boots the game into the dam and the flume)

# World 1 exploration (W45 P3): what leaving the route pays.
#   Shortcuts  each park carries one shortcut destructible row; on the committed graph it has open ground behind it,
#              and with every piece solid the ride between its faces is at least SHORTCUT_SAVE_S longer at cruise
#              than straight through. It breaks at its own tier and not one class under, and pays only the light loot
#              of its tier (never a part, a cache or a codex row). Planted: a camp piece and the shortcut cut to
#              SHORT_M long each save too little.
#   Far rung   an authored cache on the pay ladder's far rung pays a cobalt weapon (the pilot's kit first); the
#              on-line camp and the near rung keep their rolls. Planted: a pool with a relic in it fails the cobalt cap.
#   Wards      one mend ward a park, in a dead end at least WARD_OFF_LINE_M off every line and reachable from the
#              drop-in; it mends only after it woke a guard and the ball held its ring for the whole charge, and once.
#              Planted: a ward with no guard (calm) never mends; a ward at the drop-in fails the dead-end read.
#   Plates     the game builds one lore plate at every fragment spot secrets.gd lists for the park; rolling over it
#              files its field note once and puts no word on screen. Planted: a second touch files nothing.
# Output: one `EXPLORE <park> <measure> <value>` line per measure, plus PASS or FAIL rows from tests/support/t.gd.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const DW := preload("res://tests/destructibles_world1_test.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const Activities := preload("res://src/world/activities.gd")
const Secrets := preload("res://src/core/secrets.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Parts := preload("res://src/build/parts.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const MAPS := ["park_dam", "park_flume"]
const SHORTCUT_SAVE_S := 3.0
const SHORT_M := 8.0
const WARD_OFF_LINE_M := 150.0
const CLASSES := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]

var t := T.new("w45_exploration_test")
var cruise := 14.0


func _initialize() -> void:
	cruise = Tuning.new().base("cruise")
	_run.call_deferred()


func _run() -> void:
	for map_id in MAPS:
		var w := DW.world(map_id)
		var graph = ParkGraph.read(ParkMap.graph_path_for(map_id + ".json"))
		if not t.check("%s graph loads" % map_id, graph != null):
			continue
		_shortcuts(map_id, w, graph)
		_far_caches(map_id, w)
		_ward_site(map_id, w, graph)
	_far_pool()
	_ward_rule()
	await _live()
	quit(t.verdict())


# ---- shortcuts -----------------------------------------------------------------------------------------------

# Seconds at cruise the shortcut saves between its two faces: the ride with every piece solid less the straight
# one, on the committed graph, from the nodes DW.shortcut_open reads.
func saved_s(graph, row: Dictionary, rows: Array) -> float:
	var at := DW._v3(row["at"])
	var across: Vector3 = Basis(Vector3.UP, deg_to_rad(float(row.get("yaw_deg", 0.0)))) \
			* Vector3(0.0, 0.0, float(row["size"][2]) * 0.5 + DW.SHORTCUT_REACH_M)
	var a: int = graph.nearest(at + across)
	var b: int = graph.nearest(at - across)
	var solid = DW.blocked_graph(graph, rows)
	return (float(solid.path_m(a, b)) - float(graph.path_m(a, b))) / cruise


func _shortcuts(map_id: String, w: Dictionary, graph) -> void:
	var rows: Array = w["park"].get("destructible_rows", [])
	var cuts: Array = rows.filter(func(row: Dictionary) -> bool: return bool(row.get("shortcut", false)))
	if not t.eq("%s shortcut rows" % map_id, cuts.size(), 1):
		return
	var row: Dictionary = cuts[0]
	t.check("%s shortcut %s has open ground behind it" % [map_id, row["id"]], DW.shortcut_open(w, row, rows))
	var saved := saved_s(graph, row, rows)
	print("EXPLORE %s shortcut %s tier %d length %.0f saved_s %.2f" % [map_id, row["id"], row["tier"], float(row["size"][0]), saved])
	t.check("%s shortcut saves at least %.1f s at cruise" % [map_id, SHORTCUT_SAVE_S], saved >= SHORTCUT_SAVE_S, "%.2f s" % saved)
	t.check("%s shortcut pays no part, cache or codex row" % map_id,
		not (row.has("pay") or row.has("cache") or row.has("part") or row.has("codex")), str(row.keys()))
	var loot: Array = Destructibles.LOOT[int(row["tier"])]
	print("EXPLORE %s shortcut loot scrap %d cogs %d" % [map_id, loot[0], loot[1]])
	# The tier: one class under (for tier 1, under the clutter's speed bar) stays solid; at its tier at cruise it breaks.
	var tier := int(row["tier"])
	var under := _ram(row, maxi(tier - 1, 1), cruise if tier > 1 else Destructibles.WALL_SPEED * 0.5)
	var at_tier := _ram(row, tier, cruise)
	t.check("%s shortcut stands to a ram under its tier" % map_id, under == "intact", under)
	t.check("%s shortcut breaks to a class %d ram at cruise" % [map_id, tier], at_tier == "shattered", at_tier)
	# Planted: a camp piece is no shortcut, and the shortcut cut short saves too little.
	var camp: Dictionary = rows.filter(func(r: Dictionary) -> bool: return not bool(r.get("shortcut", false)))[0]
	var camp_saved := saved_s(graph, camp, rows)
	t.check("%s planted: a camp piece (%s) saves under %.1f s" % [map_id, camp["id"], SHORTCUT_SAVE_S], camp_saved < SHORTCUT_SAVE_S, "%.2f s" % camp_saved)
	var short: Dictionary = row.duplicate(true)
	short["size"] = [SHORT_M, row["size"][1], row["size"][2]]
	var others: Array = rows.filter(func(r: Dictionary) -> bool: return r["id"] != row["id"])
	others.append(short)
	var short_saved := saved_s(graph, short, others)
	t.check("%s planted: the shortcut cut to %.0f m saves under %.1f s" % [map_id, SHORT_M, SHORTCUT_SAVE_S], short_saved < SHORTCUT_SAVE_S, "%.2f s" % short_saved)


# One ball tick at `speed` toward the row's face from 2 m off it, at `heft_class`: the piece's state after.
func _ram(row: Dictionary, heft_class: int, speed: float) -> String:
	var pieces := Destructibles.new()
	pieces.build({"destructible_rows": [row]}, {"root": root, "no_visuals": true, "cruise": cruise})
	var at := DW._v3(row["at"])
	var normal: Vector3 = Basis(Vector3.UP, deg_to_rad(float(row.get("yaw_deg", 0.0)))) * Vector3(0.0, 0.0, 1.0)
	var ball := at + normal * (float(row["size"][2]) * 0.5 + 2.0)
	pieces.on_ball(ball, -normal * speed, heft_class)
	var state: String = pieces.state_of(String(row["id"]))
	pieces.teardown()
	pieces.free()
	return state


# ---- the far rung --------------------------------------------------------------------------------------------

# Whether every part a pool holds is on the cobalt rung or under it (ruling bn): no relic, no evolved.
static func cobalt_capped(pool: Array) -> bool:
	return pool.all(func(key) -> bool: return int(ItemGen.RARITY[Parts.rarity_of(key)]["rung"]) <= int(ItemGen.RARITY["rare"]["rung"]))


func _far_pool() -> void:
	for class_id in CLASSES:
		var pool := Activities.far_pool(class_id, [])
		t.check("%s far pool is not empty" % class_id, not pool.is_empty())
		t.check("%s far pool is cobalt weapons" % class_id, pool.all(func(key) -> bool:
			return Parts.rarity_of(key) == "rare" and String(Parts.rows()[key].get("family", "")) == "weapon"), str(pool))
		t.check("%s far pool stays at or under cobalt (ruling bn)" % class_id, cobalt_capped(pool), str(pool))
		var kit := pool.filter(func(key) -> bool: return Parts.in_kit(class_id, key))
		t.check("%s far pool is its kit when the kit names a weapon" % class_id, kit.is_empty() or kit.size() == pool.size(), "%d of %d" % [kit.size(), pool.size()])
		print("EXPLORE far_pool %s %s" % [class_id, ",".join(pool)])
	var relic: Array = Parts.offer_pool("tarn", ["relic"])
	if t.check("planted: a relic is offered somewhere", not relic.is_empty()):
		var planted := Activities.far_pool("tarn", [])
		planted.append(relic[0])
		t.check("planted: a pool with a relic fails the cobalt cap", not cobalt_capped(planted))
	var held_all: Array = []
	for key in Activities.far_pool("tarn", []):
		for i in 8:
			held_all.append(key)
	t.check("a pilot holding every far part at the top is offered none of them again",
		Activities.far_pool("tarn", held_all).all(func(key) -> bool: return not Parts.maxed(key, held_all)))


# The authored caches of a park on each rung, read through the game's own far_rung on a built Site.
func _far_caches(map_id: String, w: Dictionary) -> void:
	var acts := Activities.new()
	var far: Array = []
	for row: Dictionary in w["park"].get("activity_rows", []):
		var kind := String(row["activity"])
		if not Activities.RULES.has(kind):
			continue
		var s := Activities.Site.new()
		s.id = kind
		s.rule = Activities.RULES[kind].duplicate(true)
		if row.has("pay") and row["pay"].has("rarities"):
			s.rule["pay"]["rarities"] = row["pay"]["rarities"]
		var is_far := acts.far_rung(s)
		if is_far:
			far.append(String(row["id"]))
		if kind == "enemy_camp":
			t.check("%s camp %s keeps the on-line roll" % [map_id, row["id"]], not is_far)
		s.free()
	print("EXPLORE %s far_caches %s" % [map_id, ",".join(far)])
	t.check("%s has a far-rung cache" % map_id, not far.is_empty())
	# A field find on the far rung keeps its own roll.
	var find := Activities.Site.new()
	find.id = "cracked_cache"
	find.rule = Activities.RULES["cracked_cache"].duplicate(true)
	find.rule["pay"]["rarities"] = Secrets.FIND_PAY["rarities"]
	find.set_meta("find", "dam_turbine_hall")
	t.check("%s a field find keeps its own roll" % map_id, not acts.far_rung(find))
	find.free()
	acts.free()


# ---- mend wards ----------------------------------------------------------------------------------------------

func _ward_site(map_id: String, w: Dictionary, graph) -> void:
	var specs := Secrets.ward_sites(w["park"])
	if not t.eq("%s mend wards" % map_id, specs.size(), 1):
		return
	var spec: Dictionary = specs[0]
	var read := _dead_end(w, graph, spec["at"])
	print("EXPLORE %s ward %s at %s off_line_m %.0f from_spawn_m %.0f" % [map_id, spec["id"], spec["at"], read["off_line"], read["from_spawn"]])
	t.check("%s ward stands %.0f m or more off every line" % [map_id, WARD_OFF_LINE_M], read["off_line"] >= WARD_OFF_LINE_M, "%.0f" % read["off_line"])
	t.check("%s ward is reachable from the drop-in" % map_id, is_finite(read["from_spawn"]), "%.0f" % read["from_spawn"])
	var spawn: Array = w["park"]["spawn"]["at"]
	var planted := _dead_end(w, graph, Vector2(float(spawn[0]), float(spawn[1])))
	t.check("%s planted: a ward at the drop-in fails the dead-end read" % map_id, planted["off_line"] < WARD_OFF_LINE_M, "%.0f" % planted["off_line"])


# {off_line, from_spawn}: the walk from the nearest line node to `at`, and from the drop-in.
static func _dead_end(w: Dictionary, graph, at: Vector2) -> Dictionary:
	var lines := PackedInt32Array()
	for n in graph.node_count():
		if graph.flags(n) & ParkGraph.LINE:
			lines.append(n)
	var node: int = graph.nearest(Vector3(at.x, DW.ground_y(w, at), at.y))
	return {"off_line": float(graph.search(lines)[node]), "from_spawn": float(graph.d_spawn_node(node))}


func _ward_rule() -> void:
	var dt := 1.0 / 60.0
	var ticks := int(ceil(Activities.MendWard.CHARGE_S / dt))
	# With a guard: one wake, no mend before the charge is full, one mend at it, nothing after.
	var ward := Activities.MendWard.new()
	var guard := Node.new()
	t.eq("the ward wakes when the ball first enters", ward.step(dt, true), "wake")
	ward.guard.append(guard)
	var mends := 0
	var first := -1
	for i in ticks * 3:
		if ward.step(dt, true) == "mend":
			mends += 1
			if first < 0:
				first = i + 1
	t.eq("a guarded ward mends once", mends, 1)
	t.check("a guarded ward mends only once the ring is full (%.0f s)" % Activities.MendWard.CHARGE_S, first * dt >= Activities.MendWard.CHARGE_S - dt, "%.2f s" % (first * dt))
	ward.free()
	# Leaving the ring drains it: 6 s in, 4 s out leaves 4 s.
	var drained := Activities.MendWard.new()
	drained.step(dt, true)
	drained.guard.append(guard)
	for i in int(6.0 / dt):
		drained.step(dt, true)
	for i in int(4.0 / dt):
		drained.step(dt, false)
	t.check("leaving the ring drains it at %.1fx" % Activities.MendWard.DRAIN, absf(drained.charge - 4.0) < 0.05, "%.2f" % drained.charge)
	drained.free()
	# Planted: no guard ever stood, so holding the ring three charges long mends nothing.
	var free_ward := Activities.MendWard.new()
	free_ward.step(dt, true)
	var free_mends := 0
	for i in ticks * 3:
		if free_ward.step(dt, true) == "mend":
			free_mends += 1
	t.eq("planted: a ward with no guard never mends", free_mends, 0)
	free_ward.free()
	guard.free()


# ---- the live game: wards and plates as a stage entry builds them ---------------------------------------------

func _live() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.run.run_seed_override = 1
	game.ctx.calm = true
	var source := Intent.Scripted.new()
	game.player.source = source
	game.flow.press_start()
	game.flow.choose_class(0)
	for map_id in MAPS:
		var stage := 0
		for row in ParkDefs.DEFS:
			if String(row.get("map", "")) == map_id:
				stage = int(row["stage"])
		if stage != 1:
			game.flow.enter_stage(stage, Vector3.ZERO, false)
		var terrain = game.ctx.terrain
		var waited := 0
		while waited < 3000 and not (terrain.rows_ready(stage) and terrain.is_ready(stage) and game.flow.state_name() == "stage"):
			await process_frame
			waited += 1
		for i in 10:
			await physics_frame
		_live_wards(map_id, game)
		_live_plates(map_id, game)
	game.queue_free()
	await process_frame


func _live_wards(map_id: String, game) -> void:
	var acts = game.world.activities
	if not t.eq("%s builds its mend ward" % map_id, acts.wards.size(), 1):
		return
	var ward = acts.wards[0]
	var spec: Dictionary = Secrets.ward_sites(game.world.activities.ctx.terrain.map().park)[0]
	t.check("%s ward stands at its spot" % map_id, Vector2(ward.global_position.x, ward.global_position.z).distance_to(spec["at"]) < 0.5)
	t.eq("%s ward carries no word" % map_id, ward.find_children("*", "Label3D", true, false).size(), 0)
	var run = game.run
	var dt := 1.0 / 60.0
	var ticks := int(ceil(Activities.MendWard.CHARGE_S / dt)) + 2
	# Planted, calm (the snag roll's world): the ward wakes, raises no guard, and the ring never fills.
	run.hp = run.max_hp * 0.3
	for i in ticks * 2:
		acts._watch_ward(ward, dt, ward.global_position)
	t.check("%s planted: a calm ward wakes with no guard" % map_id, ward.woke and ward.guard.is_empty())
	t.check("%s planted: a calm ward mends nothing" % map_id, is_equal_approx(run.hp, run.max_hp * 0.3), "%.1f of %.1f" % [run.hp, run.max_hp])
	# A pressed ward: a fresh one with the world live wakes its guard, then mends HEAL_SHARE after the full charge.
	game.ctx.calm = false
	var live = acts._build_ward(spec)
	acts.wards.append(live)
	run.hp = run.max_hp * 0.3
	acts._watch_ward(live, dt, live.global_position)
	var guards: int = live.guard.size()
	print("EXPLORE %s ward guard %d" % [map_id, guards])
	t.check("%s ward wakes a guard" % map_id, guards > 0, "%d" % guards)
	var before_full: float = run.hp
	for i in int(Activities.MendWard.CHARGE_S / dt) - 2:
		acts._watch_ward(live, dt, live.global_position)
	t.check("%s ward mends nothing before its ring is full" % map_id, is_equal_approx(run.hp, before_full), "%.1f" % run.hp)
	for i in 4:
		acts._watch_ward(live, dt, live.global_position)
	var mended: float = run.hp - before_full
	print("EXPLORE %s ward mended %.1f of max %.1f" % [map_id, mended, run.max_hp])
	t.check("%s ward mends %.0f%% of the hull once full" % [map_id, Activities.MendWard.HEAL_SHARE * 100.0], is_equal_approx(mended, run.max_hp * Activities.MendWard.HEAL_SHARE), "%.1f" % mended)
	for i in ticks:
		acts._watch_ward(live, dt, live.global_position)
	t.check("%s ward mends once a stage entry" % map_id, is_equal_approx(run.hp - before_full, mended))
	game.ctx.calm = true
	for enemy in live.guard:
		if is_instance_valid(enemy):
			enemy.queue_free()
	live.guard.clear()


func _live_plates(map_id: String, game) -> void:
	var acts = game.world.activities
	var specs := Secrets.plate_sites(game.world.activities.ctx.terrain.map().park)
	print("EXPLORE %s plates %d" % [map_id, acts.plates.size()])
	t.check("%s has lore plates" % map_id, specs.size() >= 4, "%d" % specs.size())
	t.eq("%s builds a plate at every listed fragment" % map_id, acts.plates.size(), specs.size())
	var notes := {}
	for row in LoreRows.ROWS:
		notes[row["id"]] = row["kind"]
	var misplaced := 0
	for i in mini(specs.size(), acts.plates.size()):
		var p = acts.plates[i]
		if Vector2(p.global_position.x, p.global_position.z).distance_to(specs[i]["at"]) > 0.5:
			misplaced += 1
		t.eq("%s plate %s files a field note" % [map_id, specs[i]["fragment"]], notes.get(p.note, ""), "field_note")
	t.eq("%s plates off their fragment spots" % map_id, misplaced, 0)
	var words := 0
	for p in acts.plates:
		words += p.find_children("*", "Label3D", true, false).size()
	t.eq("%s plates carry no word" % map_id, words, 0)
	if acts.plates.is_empty():
		return
	var plate = acts.plates[0]
	var codex = game.codex
	# The test profile may hold the note from an earlier run: forget it so the first touch is a first.
	codex._discovered.erase(plate.note)
	plate.read = false
	var pulses := [0]
	var on_lore := func(_id: String): pulses[0] += 1
	codex.lore_found.connect(on_lore)
	acts._watch_plate(plate, plate.global_position)
	t.check("%s rolling over a plate files its note" % map_id, codex.known(plate.note))
	t.eq("%s the first touch pulses the note once" % map_id, pulses[0], 1)
	acts._watch_plate(plate, plate.global_position)
	t.eq("%s planted: a second touch files nothing more" % map_id, acts.read_plate(plate), false)
	t.eq("%s the note pulsed once over both touches" % map_id, pulses[0], 1)
	codex.lore_found.disconnect(on_lore)
