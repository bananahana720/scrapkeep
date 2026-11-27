extends SceneTree

# W50-POCKETS-W2W3-SECRETS verification:
# - 24 authored W2 & W3 pockets (12 per world: 4 arena, 4 secret, 4 trade), world filtering,
#   W1 library invariance, real Activities build/spawn/corridor clearance & health bands.
# - PocketDraw W2/W3 level-ground TIDY safety without anchor starvation, world-filtered draws
#   and JSON cache round-trip / validation.
# - W2 & W3 BreatherRows (line coverage, free nodes, fight clearance, RADIUS; park_crown empty)
#   and LockRows (non-holding, unplated W2/W3 waves, no ballast_heavy, park_pit 0 gate packs).
# - 6 secret rooms (1 per stage across Worlds 1-3) on real off-line dead-end anchors with <= 40w
#   dry crew logs, keeping first_win_secrets_test's ROOMS contract intact.
# - W2 malpais_monsoon & W3 highdraft_eclipse shift variants preserving W1 BUILT order, ruling al
#   (zero HP/threat/plating inflation) and ruling cu.
# - 3 new Foreman-voiced stage modifiers within EFFECTS/LOOKS and <= 8w line cap.
# - Planted negative controls for every gate.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const PocketLibrary := preload("res://src/world/pockets/pocket_library.gd")
const PocketDraw := preload("res://src/world/pockets/pocket_draw.gd")
const BreatherRows := preload("res://src/world/breather_rows.gd")
const LockRows := preload("res://src/world/lock_rows.gd")
const Secrets := preload("res://src/core/secrets.gd")
const ShiftVariants := preload("res://src/core/shift_variants.gd")
const StageModifier := preload("res://src/world/events/stage_modifier.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkPlacement := preload("res://src/world/park/park_placement.gd")
const RogueDirector := preload("res://src/world/rogue_director.gd")
const Director := preload("res://src/world/director.gd")
const Roster := preload("res://src/combat/roster.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const RunState := preload("res://src/core/run_state.gd")
const Profile := preload("res://src/core/profile.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const FightReach := preload("res://tests/support/fight_reach.gd")
const Breath := preload("res://tests/park_breath_test.gd")
const LaunchCard := preload("res://src/ui/launch_card.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

const SIZES := {"small": 24.0, "medium": 32.0, "large": 44.0}
const SCALE := {1: 1.0, 5: 2.0, 10: 3.0}
const ARENAS := ["arena", "elite_arena", "round_arena", "ambush", "enemy_camp"]
const BANNED_LOCK_KINDS := ["plated_brute", "drill_crew", "ballast_heavy", "pit_jaw", "mag_trapper", "hooker", "netcaster", "bola_thrower", "winch_drone", "gyro_jammer", "catch_trap", "boom_tender", "anchor_crew", "swatter"]
const PLACEHOLDER_MARKERS := ["todo", "tbd", "fixme", "lorem", "placeholder", "coming soon"]
const ROOM_CLEAR_M := 60.0

var _t := T.new("w50_pockets_w2w3_test")
var _temp_paths: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ShiftVariants.clear_force()
	_check_pocket_library()
	await _check_pocket_builds()
	_check_pocket_draw_w2w3()
	_check_breathers_w2w3()
	_check_locks_w2w3()
	_check_six_secret_rooms()
	_check_shift_variants_w2w3()
	_check_stage_modifiers_new()
	_check_planted_controls()
	_cleanup()
	quit(_t.verdict())


func _cleanup() -> void:
	ShiftVariants.clear_force()
	for p in _temp_paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
		if FileAccess.file_exists(p + ".prev"):
			DirAccess.remove_absolute(p + ".prev")


func _check_pocket_library() -> void:
	var w1 := PocketLibrary.rows()
	var w1_by_world := PocketLibrary.rows_for_world(1)
	var w2 := PocketLibrary.rows_for_world(2)
	var w3 := PocketLibrary.rows_for_world(3)
	var all := PocketLibrary.all_rows()

	_t.eq("W1 rows() preserved at 25", w1.size(), 25)
	_t.eq("rows_for_world(1) matches rows()", w1_by_world, w1)
	_t.eq("W2 has 12 authored pockets", w2.size(), 12)
	_t.eq("W3 has 12 authored pockets", w3.size(), 12)
	_t.eq("all_rows() has 49 pockets across W1-W3", all.size(), 49)
	_t.eq("unknown world returns empty array", PocketLibrary.rows_for_world(99), [])
	_t.eq("world_for_map resolves park_pit to 2", PocketLibrary.world_for_map("park_pit"), 2)
	_t.eq("world_for_map resolves park_crown to 3", PocketLibrary.world_for_map("park_crown"), 3)

	var seen_ids := {}
	for entry in w1:
		seen_ids[entry.id] = 1
	for world in [2, 3]:
		var entries: Array = w2 if world == 2 else w3
		var split := {"arena": 0, "secret": 0, "trade": 0}
		for entry in entries:
			var keys := ["id", "kind", "activity", "footprint", "entrances", "entry_spot", "entry_radius", "difficulty", "weight", "density", "tell", "pack", "terrain", "hazards", "safe_path"]
			var complete: bool = keys.all(func(k): return entry.has(k))
			_t.check("W%d %s complete schema" % [world, entry.get("id", "missing")], complete)
			if not complete:
				continue
			_t.check("W%d %s unique across all worlds" % [world, entry.id], not seen_ids.has(entry.id) and split.has(entry.kind))
			seen_ids[entry.id] = world
			split[entry.kind] += 1
			_t.check("W%d %s valid footprint and difficulty" % [world, entry.id], SIZES.has(entry.footprint) and SCALE.has(int(entry.difficulty)))
			_t.check("W%d %s valid weight" % [world, entry.id], float(entry.weight) in [1.0, 0.1])
			var d: Dictionary = entry.density
			_t.check("W%d %s valid density shares" % [world, entry.id],
				d.get("start", false) and d.get("terrain", 0) >= 60 and d.get("terrain", 0) <= 70
				and d.get("enemies", 0) >= 20 and d.get("enemies", 0) <= 30
				and d.get("pickups", 0) >= 5 and d.get("pickups", 0) <= 10
				and d.get("terrain", 0) + d.get("enemies", 0) + d.get("pickups", 0) == 100)
			var side: float = SIZES[entry.footprint]
			var doors_ok: bool = not entry.entrances.is_empty()
			for door in entry.entrances:
				doors_ok = doors_ok and door.get("marked", false) and door.get("width", 0) >= 4 \
					and door.at.size() == 2 and absf(float(door.at[0])) <= side * 0.5 and absf(float(door.at[1])) <= side * 0.5 \
					and is_equal_approx(maxf(absf(door.at[0]), absf(door.at[1])), side * 0.5)
			_t.check("W%d %s boundary entrance marked" % [world, entry.id], doors_ok)
			_t.check("W%d %s 40m entry radius" % [world, entry.id], float(entry.entry_radius) == 40.0 and Vector2(entry.entry_spot[0], entry.entry_spot[1]).length() <= side * 0.5)
			_t.check("W%d %s valid tell record" % [world, entry.id], not String(entry.tell.get("word", "")).is_empty() and EventKinds.ACTIVITY_ROWS.has(entry.tell.get("record", "")))
			_t.check("W%d %s valid activity kind" % [world, entry.id],
				entry.activity in ARENAS if entry.kind == "arena" else entry.activity == "cracked_cache" if entry.kind == "secret" else entry.activity == "" and not entry.has("assigned"))
			_t.check("W%d %s no at or pay" % [world, entry.id], not entry.has("at") and not entry.has("pay"))
			if entry.kind == "arena":
				_t.check("W%d %s non-empty valid roster pack" % [world, entry.id],
					not entry.pack.is_empty() and entry.pack.all(func(k): return Roster.has(String(k))))
			elif entry.kind == "trade":
				var looked := PocketLibrary.trade(String(entry.id))
				_t.eq("W%d %s trade() resolves" % [world, entry.id], looked.get("id", ""), entry.id)
		_t.eq("W%d split is 4 arena / 4 secret / 4 trade" % world, split, {"arena": 4, "secret": 4, "trade": 4})

	var mutated := PocketLibrary.rows_for_world(2)
	mutated[0].tell.word = "mutated_w2"
	_t.check("rows_for_world returns defensive copy", PocketLibrary.rows_for_world(2)[0].tell.word != "mutated_w2")


func _check_pocket_builds() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	game.world.set_physics_process(false)
	game.flow.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.body().freeze = true
	var acts = game.world.activities
	acts.set_physics_process(false)
	acts.clear()

	for world in [2, 3]:
		var bands := {1: [], 5: [], 10: []}
		for entry in PocketLibrary.rows_for_world(world):
			if entry.kind == "trade":
				continue
			var spec: Dictionary = PocketLibrary.site_spec(entry)
			spec["site"] = "w50_build_test"
			var s = acts._build(entry.activity, Vector2(100, 100), spec)
			acts.sites.append(s)
			var interior = s.get_node("Interior_" + String(entry.id))
			_t.eq("W%d %s built interior children" % [world, entry.id], interior.get_child_count(), entry.terrain.size() + entry.entrances.size() * 2)
			if entry.kind == "arena":
				acts._spawn_pocket_pack(s, s.rule.pack)
				var hp_sum := 0.0
				var corridor_clear := true
				for enemy in s.pack:
					hp_sum += enemy.max_hp
					var local: Vector3 = s.to_local(enemy.global_position)
					var start := Vector2(entry.entry_spot[0], entry.entry_spot[1])
					var pt := Vector2(local.x, local.z)
					var closest := start * clampf(pt.dot(start) / start.length_squared(), 0.0, 1.0)
					if pt.distance_to(closest) < 2.0 + enemy.radius:
						corridor_clear = false
				_t.check("W%d %s enemy bodies clear 4m entry corridor" % [world, entry.id], corridor_clear)
				_t.eq("W%d %s hazard count" % [world, entry.id], s.hazards.size(), entry.hazards.size())
				bands[int(entry.difficulty)].append({"id": entry.id, "count": s.pack.size(), "health": hp_sum})
			acts.clear()
			await physics_frame
		for difficulty in [5, 10]:
			var prev: Array = bands[1 if difficulty == 5 else 5]
			for cur in bands[difficulty]:
				var rises: bool = not prev.is_empty() and int(cur.count) > 0
				for low in prev:
					rises = rises and int(cur.count) > int(low.count) and float(cur.health) > float(low.health)
				_t.check("W%d %s rises over lower difficulty band" % [world, cur.id], rises, JSON.stringify({"cur": cur, "prev": prev}))

	game.free()
	await process_frame


func _check_pocket_draw_w2w3() -> void:
	# After w50/map-w3-roboquest added 2 authored activities and 4 storm wires to park_crown,
	# park_crown holds 180 raw / 99 tidy anchors for 3 drawn slots (CAP 8 - 5 authored).
	var min_anchors := {"park_pit": 1000, "park_sinkhole": 1000, "park_islands": 400, "park_crown": 80}
	for stage in [3, 4, 5, 6]:
		var map_id := String(ParkDefs.of(stage).map)
		var world := ParkDefs.world_of(stage)
		var map := ParkMap.new("res://src/world/park/%s.json" % map_id)
		var g = ParkGraph.read("res://assets/park/%s/graph.bin" % map_id)
		_t.check("%s map and graph load" % map_id, map.ok and g != null)
		if not map.ok or g == null:
			continue
		var prepared := PocketDraw.prepare_world(g, map)
		var limit: float = PocketDraw.tidy_level_m(map_id, true)
		_t.check("%s has tidy level limit" % map_id, limit > 0.0)
		_t.check("%s tidy anchors not starved (>= %d)" % [map_id, min_anchors[map_id]],
			prepared.anchors.size() >= int(min_anchors[map_id]), str(prepared.anchors.size()))

		var keep_out := []
		for row in map.park.get("rescue_rows", []):
			keep_out.append({"at": Vector2(row.at[0], row.at[1]), "radius": ParkPlacement.RING_M})
		for at in PocketDraw.secret_spots(map_id):
			keep_out.append({"at": at, "radius": ParkPlacement.RING_M})
		for site in RogueDirector.read_sites(map_id).get("miniboss_sites", []):
			keep_out.append({"at": Vector2(site.at[0], site.at[1]), "radius": float(site.radius_m)})

		var level_ok := true
		var keepout_ok := true
		for a in prepared.anchors:
			var sizes: Dictionary = prepared.fits[a.node]
			for size in sizes:
				var half: float = PocketLibrary.FOOTPRINTS[size] * 0.5
				var box := Rect2(a.at - Vector2.ONE * half, Vector2.ONE * half * 2.0)
				var low := INF
				var high := -INF
				for k in g.box_nodes(box.position - Vector2.ONE * ParkGraph.STEP_M, box.end + Vector2.ONE * ParkGraph.STEP_M):
					low = minf(low, g.py[k])
					high = maxf(high, g.py[k])
				if high - low > limit + 0.001:
					level_ok = false
				if keep_out.any(func(ko): return PocketDraw._box_distance(box, ko.at) <= ko.radius):
					keepout_ok = false
		_t.check("%s every tidy anchor obeys level-ground cap %.1f m" % [map_id, limit], level_ok)
		_t.check("%s every tidy anchor clears rescues, secrets and rogues" % map_id, keepout_ok)

		# Draw from world-specific pool and verify save/restore round-trip.
		var world_ids := {}
		for e in PocketLibrary.rows_for_world(world):
			if e.kind != "trade":
				world_ids[e.id] = true
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([78000, 17, stage, "w50_draw"])
		var drawn := PocketDraw.draw_for_world(prepared, map, stage, rng)
		_t.check("%s world draw places >= 1 W%d pocket" % [map_id, world], not drawn.sites.is_empty())
		var all_native: bool = drawn.sites.all(func(s): return world_ids.has(s.interior.id))
		_t.check("%s world draw picks only W%d non-trade interiors" % [map_id, world], all_native)
		var cache := {str(stage): {"sites": drawn.sites}}
		var doc: Dictionary = JSON.parse_string(JSON.stringify(PocketDraw.to_doc(cache)))
		_t.eq("%s W%d draw doc validates" % [map_id, world], PocketDraw.validate_doc(doc, stage), "")
		_t.check("%s W%d draw doc round-trips" % [map_id, world], PocketDraw.from_doc(doc) == cache)


func _check_breathers_w2w3() -> void:
	var want := {"park_pit": 1, "park_sinkhole": 1, "park_islands": 1, "park_crown": 0}
	for stage in [3, 4, 5, 6]:
		var row: Dictionary = ParkDefs.DEFS[stage - 1]
		var map_id := String(row["map"])
		var map := ParkMap.new("res://src/world/park/%s.json" % map_id)
		var g = ParkGraph.read("res://assets/park/%s/graph.bin" % map_id)
		var list := map.breathers()
		_t.eq("%s breather count" % map_id, list.size(), int(want[map_id]))
		if list.is_empty():
			continue
		var d := Director.new(7)
		d.author(row, ParkDefs)
		d.use_row(row)
		var sites := map.fight_sites()
		var points := Breath.line_points(g)
		for b in list:
			var r := float(b["radius_m"])
			var inside := points.filter(func(p: Vector2) -> bool: return p.distance_to(b["at"]) <= r).size()
			var free := points.filter(func(p: Vector2) -> bool: return p.distance_to(b["at"]) <= r and d._window_homes(p).is_empty()).size()
			var clear := FightReach.nearest(sites, b["at"]) - r
			_t.check("%s %s radius in RADIUS" % [map_id, b["id"]], r >= BreatherRows.RADIUS.x and r <= BreatherRows.RADIUS.y)
			_t.check("%s %s stands on riding lines (>= 10)" % [map_id, b["id"]], inside >= 10, str(inside))
			_t.check("%s %s covers free line nodes (>= 10)" % [map_id, b["id"]], free >= 10, str(free))
			_t.check("%s %s keeps >= 25m clear of fight sites" % [map_id, b["id"]], clear >= 25.0, "%.1f m" % clear)


static func _lock_waves_safe(waves: Array) -> bool:
	if waves.is_empty():
		return false
	for wave in waves:
		if not wave is Array or wave.is_empty():
			return false
		for kind in wave:
			var k := String(kind)
			if not Roster.has(k):
				return false
			if k in BANNED_LOCK_KINDS or bool(Roster.row(k).get("holds", false)):
				return false
	return true


func _check_locks_w2w3() -> void:
	_t.eq("park_pit keeps 0 gate packs (wayfinding pin)", int(LockRows.row("park_pit").get("gate", {}).get("packs", 0)), 0)
	for map_id in ["park_pit", "park_sinkhole", "park_islands", "park_crown"]:
		var r := LockRows.row(map_id)
		_t.check("%s has lock row" % map_id, r.has("lock") and r["lock"] is Dictionary)
		var lock: Dictionary = r.get("lock", {})
		var waves: Array = lock.get("waves", [])
		_t.check("%s lock has >= 5 waves" % map_id, waves.size() >= 5, str(waves.size()))
		_t.check("%s lock waves are non-holding and unplated" % map_id, _lock_waves_safe(waves), str(waves))
		var sentry: Dictionary = lock.get("sentry", {})
		if not sentry.is_empty():
			var sk := String(sentry.get("kind", ""))
			_t.check("%s lock sentry is valid non-holding kind" % map_id,
				Roster.has(sk) and not (sk in BANNED_LOCK_KINDS) and not bool(Roster.row(sk).get("holds", false)), sk)


func _check_six_secret_rooms() -> void:
	_t.eq("Secrets.ROOMS keeps 3 first-win rooms", Secrets.ROOMS.size(), 3)
	_t.eq("Secrets.STAGE_ROOMS adds 3 stage rooms", Secrets.STAGE_ROOMS.size(), 3)
	var all := Secrets.all_rooms()
	_t.eq("Secrets.all_rooms() has 6 rooms total", all.size(), 6)

	for expected_id in ["spillway_dam_vault", "dig_cenote_alcove", "highdraft_storm_bunker"]:
		_t.check("all_rooms includes %s" % expected_id, all.has(expected_id))
		_t.check("room_by_id resolves %s" % expected_id, not Secrets.room_by_id(expected_id).is_empty())

	var maps_seen := {}
	var worlds := {}
	for id in all:
		var room: Dictionary = all[id]
		var map_id := String(room["map"])
		maps_seen[map_id] = maps_seen.get(map_id, 0) + 1
		worlds[int(room["world"])] = worlds.get(int(room["world"]), 0) + 1
		var log_words: int = String(room["log"]).split(" ", false).size()
		_t.check("%s log within 40-word cap" % id, log_words > 0 and log_words <= mini(Secrets.LOG_WORD_CAP, LoreRows.FIELD_NOTE_WORD_CAP), str(log_words))
		for marker in PLACEHOLDER_MARKERS:
			_t.check("%s carries no %s" % [id, marker], not (String(room["log"]) + String(room["name"])).to_lower().contains(marker))

		var map := ParkMap.new("res://src/world/park/%s.json" % map_id)
		var g = ParkGraph.read("res://assets/park/%s/graph.bin" % map_id)
		var at := Vector2(float(room["at"][0]), float(room["at"][1]))
		_t.check("%s inside play_rect" % id, map.play_rect.grow(-20.0).has_point(at), str(at))
		_t.check("%s names real park_row" % id, map.park["park_rows"].any(func(r): return r["id"] == room["site"]), String(room["site"]))
		for act in map.park["activity_rows"]:
			var dist := at.distance_to(Vector2(float(act["at"][0]), float(act["at"][1])))
			_t.check("%s keeps >= 60m from %s" % [id, act["id"]], dist >= ROOM_CLEAR_M, "%.1f m" % dist)
		var node: int = g.nearest(at)
		_t.check("%s reachable from spawn" % id, is_finite(g.d_spawn_node(node)))
		_t.check("%s on DOOR_OK node" % id, (g.flags(node) & ParkGraph.DOOR_OK) != 0)
		var zone: int = g.zone_of(node)
		var anchor := {}
		for a in g.anchors():
			if a["zone"] == zone:
				anchor = a
		_t.check("%s in dead-end off-line zone" % id, not anchor.is_empty() and int(anchor["rank"]) > 0, str(anchor))
		_t.eq("%s zone matches site row" % id, g.zones()[zone]["row"], room["site"])

	_t.eq("1 secret room per stage across all 6 parks", maps_seen, {
		"park_dam": 1, "park_flume": 1, "park_pit": 1, "park_sinkhole": 1, "park_islands": 1, "park_crown": 1,
	})
	_t.eq("2 secret rooms per world", worlds, {1: 2, 2: 2, 3: 2})

	var path := "user://w50-secrets-test-%d.json" % OS.get_process_id()
	_temp_paths.append(path)
	var p := Profile.new(path)
	p.load_profile()
	_t.eq("fresh profile gets no stage_room_sites on park_dam", Secrets.stage_room_sites("park_dam", p), [])
	p.earn("first_win", 1.0)
	_t.eq("won profile gets spillway_dam_vault on park_dam",
		Secrets.stage_room_sites("park_dam", p).map(func(s): return s["secret"]), ["spillway_dam_vault"])
	_t.eq("won profile gets dig_cenote_alcove on park_sinkhole",
		Secrets.stage_room_sites("park_sinkhole", p).map(func(s): return s["secret"]), ["dig_cenote_alcove"])
	_t.eq("won profile gets highdraft_storm_bunker on park_crown",
		Secrets.stage_room_sites("park_crown", p).map(func(s): return s["secret"]), ["highdraft_storm_bunker"])


static func _no_hp_inflation(base_def: Dictionary, mod_def: Dictionary) -> bool:
	return is_equal_approx(float(mod_def["threat"]), float(base_def["threat"])) \
		and is_equal_approx(float(mod_def["warden_hp"]), float(base_def["warden_hp"])) \
		and is_equal_approx(float(mod_def["warden_plating"]), float(base_def["warden_plating"]))


func _check_shift_variants_w2w3() -> void:
	_t.eq("BUILT preserves W1 order prefix", ShiftVariants.BUILT.slice(0, 3), [ShiftVariants.OVERTIME, ShiftVariants.DAM_NIGHT_SHIFT, ShiftVariants.CREW_SHORT])
	_t.eq("BUILT adds malpais_monsoon and highdraft_eclipse", ShiftVariants.BUILT.slice(3), [ShiftVariants.MALPAIS_MONSOON, ShiftVariants.HIGHDRAFT_ECLIPSE])

	var path := "user://w50-variants-test-%d.json" % OS.get_process_id()
	_temp_paths.append(path)
	var p := Profile.new(path)
	p.load_profile()
	_t.eq("fresh profile opens no W2/W3 variants", ShiftVariants.open_for(p), [])
	p.earn("waking_stilled", 1000)
	_t.eq("waking_stilled opens malpais_monsoon", ShiftVariants.open_for(p), [ShiftVariants.MALPAIS_MONSOON])
	p.earn("highdraft_reached", 1001)
	_t.eq("highdraft_reached adds highdraft_eclipse", ShiftVariants.open_for(p), [ShiftVariants.MALPAIS_MONSOON, ShiftVariants.HIGHDRAFT_ECLIPSE])

	# Malpais Monsoon on stages 3-4: look id, pressure scaling only (ruling al), extra caches, card row.
	ShiftVariants.force([ShiftVariants.MALPAIS_MONSOON])
	var run := RunState.new()
	run.stage = 3
	_t.eq("monsoon stage 3 look_id", ShiftVariants.look_id(run, 3), ShiftVariants.MONSOON_LOOK_ID)
	_t.eq("monsoon stage 1 look_id empty", ShiftVariants.look_id(run, 1), "")
	var pit_base: Dictionary = ParkDefs.of(3)
	var pit_mod: Dictionary = ShiftVariants.stage_def(pit_base, run, 3)
	_t.check("monsoon obeys ruling al (zero HP/threat/plating inflation)", _no_hp_inflation(pit_base, pit_mod))
	_t.check("monsoon raises pack_scale and lowers interval_scale",
		float(pit_mod["pressure"]["pack_scale"]) > float(pit_base["pressure"]["pack_scale"])
		and float(pit_mod["pressure"]["interval_scale"]) < float(pit_base["pressure"]["interval_scale"]))
	_t.eq("monsoon adds pit cache", ShiftVariants.extra_sites("park_pit", run).size(), 1)
	_t.eq("monsoon adds no dam cache", ShiftVariants.extra_sites("park_dam", run).size(), 0)
	_t.eq("monsoon card_rows on stage 3", ShiftVariants.card_rows(run, 3).map(func(r): return r["id"]), [ShiftVariants.MALPAIS_MONSOON])
	_t.eq("monsoon card_rows empty on stage 5", ShiftVariants.card_rows(run, 5), [])

	# Highdraft Eclipse on stages 5-6: look id, pressure + elite cadence scaling only (ruling al), extra caches, card row.
	ShiftVariants.force([ShiftVariants.HIGHDRAFT_ECLIPSE])
	run.stage = 5
	_t.eq("eclipse stage 5 look_id", ShiftVariants.look_id(run, 5), ShiftVariants.ECLIPSE_LOOK_ID)
	_t.eq("eclipse stage 3 look_id empty", ShiftVariants.look_id(run, 3), "")
	var isles_base: Dictionary = ParkDefs.of(5)
	var isles_mod: Dictionary = ShiftVariants.stage_def(isles_base, run, 5)
	_t.check("eclipse obeys ruling al (zero HP/threat/plating inflation)", _no_hp_inflation(isles_base, isles_mod))
	_t.check("eclipse raises pack_scale, elite_rate and lowers interval_scale",
		float(isles_mod["pressure"]["pack_scale"]) > float(isles_base["pressure"]["pack_scale"])
		and float(isles_mod["pressure"]["elite_rate"]) > float(isles_base["pressure"]["elite_rate"])
		and float(isles_mod["pressure"]["interval_scale"]) < float(isles_base["pressure"]["interval_scale"]))
	_t.eq("eclipse adds islands cache", ShiftVariants.extra_sites("park_islands", run).size(), 1)
	run.stage = 6
	_t.eq("eclipse adds crown cache", ShiftVariants.extra_sites("park_crown", run).size(), 1)
	_t.eq("eclipse card_rows on stage 6", ShiftVariants.card_rows(run, 6).map(func(r): return r["id"]), [ShiftVariants.HIGHDRAFT_ECLIPSE])
	ShiftVariants.clear_force()

	# Verify all 4 W2/W3 variant caches sit on reachable DOOR_OK level ground matching their site
	# park row, clear of fight sites, authored activities, and PocketDraw anchors.
	var variant_caches := {}
	for map_id in ShiftVariants.MONSOON_CACHES:
		variant_caches[map_id] = ShiftVariants.MONSOON_CACHES[map_id]
	for map_id in ShiftVariants.ECLIPSE_CACHES:
		variant_caches[map_id] = ShiftVariants.ECLIPSE_CACHES[map_id]
	for map_id in variant_caches:
		var cache: Dictionary = variant_caches[map_id]
		var map := ParkMap.new("res://src/world/park/%s.json" % map_id)
		var g = ParkGraph.read("res://assets/park/%s/graph.bin" % map_id)
		var res := _variant_cache_placement_check(g, map, map_id, cache)
		_t.check("%s %s valid reachable level placement" % [map_id, cache["row"]], res["ok"], str(res))

	# Planted negative control: cliff-hanging / unreachable coordinate on park_crown fails check.
	var crown_map := ParkMap.new("res://src/world/park/park_crown.json")
	var crown_g = ParkGraph.read("res://assets/park/park_crown/graph.bin")
	var planted_cliff := {"row": "planted_cliff_cache", "site": "crown_apron", "at": Vector2(180.0, 220.0)}
	_t.check("planted: cliff-hanging unreachable variant cache fails placement check",
		not _variant_cache_placement_check(crown_g, crown_map, "park_crown", planted_cliff)["ok"])


static func _variant_cache_placement_check(g, map, map_id: String, cache: Dictionary) -> Dictionary:
	var at: Vector2 = cache["at"]
	var site := String(cache["site"])
	var limit: float = PocketDraw.tidy_level_m(map_id, true)
	var in_rect: bool = map.play_rect.grow(-20.0).has_point(at)
	var row_exists: bool = map.park["park_rows"].any(func(r): return String(r["id"]) == site)
	var node: int = g.nearest(at)
	var reachable: bool = is_finite(g.d_spawn_node(node))
	var door_ok: bool = (g.flags(node) & ParkGraph.DOOR_OK) != 0
	var zone_row: String = String(g.zones()[g.zone_of(node)]["row"])
	var box_nodes: PackedInt32Array = g.box_nodes(at - Vector2(12.0, 12.0), at + Vector2(12.0, 12.0))
	var all_reach: bool = not box_nodes.is_empty()
	var low := INF
	var high := -INF
	for k in box_nodes:
		if not is_finite(g.d_spawn_node(k)):
			all_reach = false
		low = minf(low, g.py[k])
		high = maxf(high, g.py[k])
	var rise: float = high - low if is_finite(low) and is_finite(high) else INF
	var fight_dist: float = FightReach.nearest(map.fight_sites(), at)
	var pd_base := PocketDraw.prepare(g, map)
	var pd_tidy := PocketDraw.prepare_world(g, map)
	var min_pd := INF
	for a in pd_base.anchors:
		min_pd = minf(min_pd, at.distance_to(a.at))
	for a in pd_tidy.anchors:
		min_pd = minf(min_pd, at.distance_to(a.at))
	var ok: bool = in_rect and row_exists and reachable and door_ok and zone_row == site \
		and all_reach and rise <= limit and fight_dist >= 60.0 and min_pd > ParkPlacement.RING_M
	return {"ok": ok, "in_rect": in_rect, "row_exists": row_exists, "reachable": reachable,
		"door_ok": door_ok, "zone_row": zone_row, "want_site": site, "box_nodes": box_nodes.size(),
		"all_reach": all_reach, "rise": rise, "limit": limit, "fight_dist": fight_dist, "min_pd": min_pd}


func _check_stage_modifiers_new() -> void:
	_t.eq("StageModifier.ROWS expanded to 8", StageModifier.ROWS.size(), 8)
	var by_id := {}
	for row in StageModifier.ROWS:
		by_id[row.id] = row
	for new_id in ["overstock", "audit_flare", "brownout"]:
		_t.check("new modifier %s exists" % new_id, by_id.has(new_id))
		if not by_id.has(new_id):
			continue
		var row: Dictionary = by_id[new_id]
		_t.check("%s uses only EFFECTS/LOOKS keys" % new_id, StageModifier.valid(row))
		var words: int = String(row.line).split(" ", false).size()
		_t.check("%s fits <= 8 words" % new_id, words <= 8, "%d words: %s" % [words, row.line])
		var pair := StageModifier.caption(StageModifier.CURSE) + "  /  " + StageModifier.caption(row)
		_t.check("%s fits card width beside curse" % new_id, UiDraw.width(pair, LaunchCard.LINE_FONT) <= 1600.0 * 0.85)
		for stage in range(1, ParkDefs.COUNT + 1):
			var n := StageModifier.slots(row, stage, 3)
			_t.check("%s stage %d slots within cap" % [new_id, stage], n >= 1 and n + 3 <= StageModifier.CAP)


func _check_planted_controls() -> void:
	_t.check("planted: holding enemy pit_jaw fails lock-wave check", not _lock_waves_safe([["burrower", "pit_jaw"]]))
	_t.check("planted: plated enemy drill_crew fails lock-wave check", not _lock_waves_safe([["burrower", "drill_crew"]]))
	_t.check("planted: rim-only ballast_heavy fails lock-wave check", not _lock_waves_safe([["line_cutter", "ballast_heavy"]]))
	_t.check("planted: holding enemy anchor_crew fails lock-wave check", not _lock_waves_safe([["line_cutter", "anchor_crew"]]))
	_t.check("planted: unknown enemy kind fails lock-wave check", not _lock_waves_safe([["fake_machine"]]))
	_t.check("planted: modifier HP/handling key rejected by valid()", not StageModifier.valid({"id": "bad", "word": "Bad", "line": "Nope.", "enemy_hp": 2.0}))
	var fake_base := {"threat": 1.1, "warden_hp": 950.0, "warden_plating": 130.0}
	var fake_inflated := {"threat": 1.1, "warden_hp": 1200.0, "warden_plating": 130.0}
	_t.check("planted: ruling al detector catches Warden HP inflation", not _no_hp_inflation(fake_base, fake_inflated))
	var long_words := PackedStringArray()
	for i in 41:
		long_words.append("word")
	var too_long_log := " ".join(long_words)
	_t.check("planted: 41-word secret log exceeds LOG_WORD_CAP", too_long_log.split(" ", false).size() > Secrets.LOG_WORD_CAP)
	var bad_doc := {"3": {"sites": [{"interior": "nonexistent_pocket", "node": 0, "at": [0, 0], "turn": 0}]}}
	_t.check("planted: unknown interior fails PocketDraw.validate_doc", PocketDraw.validate_doc(bad_doc, 3) != "")
	_t.check("planted: 400m breather radius fails RADIUS bounds", not (400.0 >= BreatherRows.RADIUS.x and 400.0 <= BreatherRows.RADIUS.y))
