extends SceneTree

# World 1 unit 15 (secrets.gd FINDS): two field finds per Spillway park on every profile. Each
# draws one of its spots from the run seed, stands in a dead-end zone off every line, away from
# the authored activities and the zone's far end (where rib caches wait), and carries its family's
# tell: a seeping, dripping cracked face or a radio playing through the wall. Breaking the face
# files the find's codex row on disk, and the camp counts it.

const Activities := preload("res://src/world/activities.gd")
const CampMenu := preload("res://src/ui/camp_menu.gd")
const Codex := preload("res://src/core/codex.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const Park := preload("res://src/core/park_defs.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Secrets := preload("res://src/core/secrets.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const TuneMoments := preload("res://src/presentation/tune_moments.gd")
const T := preload("res://tests/support/t.gd")

const ACTIVITY_CLEAR_M := 60.0
const CONTRAPTION_CLEAR_M := 40.0
const FAR_END_CLEAR_M := 10.0
# The room's 12 x 8 m shell, checked on the real terrain: corners and centre within this rise.
const FLAT_RISE_M := 1.5
const MARKERS := ["todo", "tbd", "fixme", "lorem", "placeholder", "coming soon"]

var _t := T.new("spillway_finds_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_table()
	_placement()
	_seeds()
	_sounds()
	await _game()
	quit(_t.verdict())


func _table() -> void:
	var per_map := {}
	var codex_ids := []
	for id in Secrets.FINDS:
		var f: Dictionary = Secrets.FINDS[id]
		_t.eq("%s is world 1" % id, int(f["world"]), 1)
		_t.check("%s is a known family" % id, f["kind"] in Secrets.FIND_KINDS, str(f["kind"]))
		per_map[f["map"]] = per_map.get(f["map"], []) + [f["kind"]]
		_t.check("%s has two spots" % id, (f["spots"] as Array).size() == 2)
		var words: int = String(f["log"]).split(" ", false).size()
		_t.check("%s log fits a field note" % id, words <= mini(Secrets.LOG_WORD_CAP, LoreRows.FIELD_NOTE_WORD_CAP), str(words))
		var c: Dictionary = f["codex"]
		_t.eq("%s codex row is a world row" % id, c.get("category"), "world")
		for key in ["id", "name", "hint", "clue", "text"]:
			_t.check("%s codex row has its %s" % [id, key], String(c.get(key, "")) != "")
		codex_ids.append(c["id"])
		var all_text := "%s %s %s %s %s" % [f["name"], f["log"], c["name"], c["hint"], c["text"]]
		for word in MARKERS:
			_t.check("%s text carries no %s" % [id, word], not all_text.to_lower().contains(word))
	_t.eq("two finds per Spillway park, one of each family",
		{"park_dam": (per_map.get("park_dam", []) as Array).duplicate(), "park_flume": per_map.get("park_flume", [])},
		{"park_dam": ["crack", "radio"], "park_flume": ["crack", "radio"]})
	for cid in codex_ids:
		_t.check("%s counts at the camp" % cid, (Secrets.WORLD_CODEX[1] as Array).has(cid))
		_t.eq("%s codex id is unique" % cid, codex_ids.count(cid), 1)
	for id in Secrets.FINDS:
		var f: Dictionary = Secrets.FINDS[id]
		var tune := TuneMoments.find_tune(String(f["codex"]["id"]))
		_t.eq("%s finds %s" % [id, "the lost tape" if f["kind"] == "radio" else "no tune"], tune, "secret-lost-tape" if f["kind"] == "radio" else "")


func _placement() -> void:
	var maps := {}
	for row in Park.DEFS:
		maps[String(row["map"])] = true
	for id in Secrets.FINDS:
		var f: Dictionary = Secrets.FINDS[id]
		var map_id := String(f["map"])
		_t.check("%s stands on a park the table plays" % id, maps.has(map_id), map_id)
		var map := ParkMap.new("res://src/world/park/%s.json" % map_id)
		if not map.ok:
			_t.check("%s park loads" % id, false, str(map.errors))
			continue
		var g = ParkGraph.read("res://assets/park/%s/graph.bin" % map_id)
		_t.check("%s park has a graph" % id, g != null)
		for spot in f["spots"]:
			var label := "%s at %s" % [id, spot["site"]]
			var at := Vector2(float(spot["at"][0]), float(spot["at"][1]))
			_t.check("%s is inside the play rect" % label, map.play_rect.grow(-20.0).has_point(at), str(at))
			_t.check("%s names a real park row" % label, map.park["park_rows"].any(func(r): return r["id"] == spot["site"]))
			for act in map.park["activity_rows"]:
				var d := at.distance_to(Vector2(float(act["at"][0]), float(act["at"][1])))
				_t.check("%s keeps clear of %s" % [label, act["id"]], d >= ACTIVITY_CLEAR_M, "%.0f m" % d)
			for row in map.park["contraption_rows"]:
				if row.has("at"):
					var d := at.distance_to(Vector2(float(row["at"][0]), float(row["at"][1])))
					_t.check("%s keeps clear of %s" % [label, row["id"]], d >= CONTRAPTION_CLEAR_M, "%.0f m" % d)
			for room_id in Secrets.ROOMS:
				var room: Dictionary = Secrets.ROOMS[room_id]
				if room["map"] == map_id:
					var d := at.distance_to(Vector2(float(room["at"][0]), float(room["at"][1])))
					_t.check("%s keeps clear of %s" % [label, room_id], d >= ACTIVITY_CLEAR_M, "%.0f m" % d)
			if g == null:
				continue
			var node: int = g.nearest(at)
			_t.check("%s is reachable from the drop-in" % label, is_finite(g.d_spawn_node(node)))
			_t.check("%s is a door_ok node" % label, g.flags(node) & ParkGraph.DOOR_OK != 0, str(g.flag_names(node)))
			var zone: int = g.zone_of(node)
			var anchor := {}
			for a in g.anchors():
				if a["zone"] == zone:
					anchor = a
			_t.check("%s stands in a dead-end zone off every line" % label, not anchor.is_empty() and anchor["rank"] > 0, str(anchor))
			_t.eq("%s zone is its site row" % label, g.zones()[zone]["row"], spot["site"])
			var face := Vector2(float(spot["face"][0]), float(spot["face"][1])).normalized()
			var out_node: int = g.nearest(at + face * 16.0)
			_t.check("%s faces out of its dead end" % label, g.d_spawn_node(out_node) < g.d_spawn_node(node),
				"%.0f m out vs %.0f m in" % [g.d_spawn_node(out_node), g.d_spawn_node(node)])
			var far := -1
			var far_d := -1.0
			for n in g.zone_door_nodes(zone):
				var d: float = g.d_spawn_node(n)
				if is_finite(d) and d > far_d:
					far_d = d
					far = n
			var far_at: Vector3 = g.position(far)
			var gap := at.distance_to(Vector2(far_at.x, far_at.z))
			_t.check("%s leaves the zone's far end to the rib cache" % label, gap >= FAR_END_CLEAR_M, "%.0f m" % gap)


func _seeds() -> void:
	for id in Secrets.FINDS:
		var seen := {}
		for seed in range(1, 65):
			seen[Secrets.find_spot(id, seed)["site"]] = true
		_t.eq("%s draws both spots over 64 seeds" % id, seen.size(), 2)
		_t.eq("%s replays by seed" % id, Secrets.find_spot(id, 12345), Secrets.find_spot(id, 12345))
	var sites := Secrets.find_sites("park_dam", 7)
	_t.eq("the dam holds two find sites", sites.size(), 2)
	_t.eq("a find is a cracked cache paying green", [sites[0]["id"], sites[0]["pay"]], ["cracked_cache", {"rarities": ["rare"]}])
	_t.eq("the pit holds none", Secrets.find_sites("park_pit", 7), [])


func _sounds() -> void:
	for id in ["find_drip", "find_radio"]:
		_t.check("%s has a recipe" % id, SfxBank.has_recipe(id))
		var wav := SfxBank.loop_stream(id)
		_t.check("%s loops" % id, wav != null and wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and wav.data.size() > 0)
		var buf := SfxBank.samples(id)
		_t.check("%s is not silent" % id, buf.size() > 0 and _peak(buf) > 0.1, "%.2f" % _peak(buf))
		_t.check("%s seam is quiet" % id, absf(buf[0]) < 0.05 and absf(buf[buf.size() - 1]) < 0.05, "%.3f %.3f" % [buf[0], buf[buf.size() - 1]])


func _peak(buf: PackedFloat32Array) -> float:
	var top := 0.0
	for v in buf:
		top = maxf(top, absf(v))
	return top


# The real Game on the park table, fresh profile: each Spillway stage builds its two finds with their
# tells; breaking one files its codex row on disk and the camp's count moves.
func _game() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	var before: Dictionary = CampMenu.reading(game)["secrets"][0]
	_t.eq("a fresh camp counts no Spillway secret", [before["name"], before["found"], before["total"]], ["Spillway", 0, Secrets.WORLD_CODEX[1].size()])
	var broken := 0
	for map_id in ["park_dam", "park_flume"]:
		var index := -1
		for i in game.ctx.terrain.maps.size():
			if "park" in game.ctx.terrain.maps[i] and String(game.ctx.terrain.maps[i].park.get("map", "")) == map_id:
				index = i
		_t.check("%s is on the park table" % map_id, index >= 0)
		if index < 0:
			continue
		game.flow.enter_stage(index + 1, Vector3.ZERO, false)
		await physics_frame
		await physics_frame
		_run_seed_moves(game, map_id)
		_every_spot_flat(game, map_id)
		var want_seed := hash([game.ctx.rng.seed, game.run.run_seed, "field_finds"])
		var finds: Array = game.world.activities.sites.filter(func(s): return is_instance_valid(s) and s.has_meta("find"))
		var want := Secrets.find_sites(map_id, want_seed).map(func(s): return String(s["find"]))
		_t.eq("fresh: %s builds its two finds" % map_id, finds.map(func(s): return String(s.get_meta("find"))), want)
		for s in finds:
			var id := String(s.get_meta("find"))
			var f: Dictionary = Secrets.FINDS[id]
			var spot := Secrets.find_spot(id, want_seed)
			var planar := Vector2(s.global_position.x - float(spot["at"][0]), s.global_position.z - float(spot["at"][1])).length()
			_t.check("%s stands at its drawn spot" % id, planar <= 12.0, "%.1f m" % planar)
			_t.check("%s stands on flat ground" % id, _rise(game, s) <= FLAT_RISE_M, "%.2f m" % _rise(game, s))
			var board: Label3D = s.get_node_or_null("RoomLog")
			_t.check("%s hangs its crew-log line" % id, board != null and board.text.contains(String(f["log"])))
			_t.check("%s carries no first-win tells" % id, s.wall.get_node_or_null("RoomTally") == null and s.wall.get_node_or_null("RoomGlove") == null)
			var tell: AudioStreamPlayer3D = s.wall.get_node_or_null("FindTell")
			var reach: float = Secrets.RADIO_HEAR_M if f["kind"] == "radio" else Secrets.DRIP_HEAR_M
			_t.check("%s is heard to %.0f m" % [id, reach], tell != null and tell.autoplay and is_equal_approx(tell.max_distance, reach))
			if f["kind"] == "radio":
				_t.check("%s raises its aerial" % id, s.get_node_or_null("FindAerial") != null)
			else:
				_t.check("%s seeps down its face" % id, s.wall.get_node_or_null("FindSeep0") != null and s.wall.get_node_or_null("FindGlint") != null)
			_t.check("%s shows no beacon" % id, not s.view.lit() and not s.view.word.visible)
			# W1-22: the find draws its models (find_kit.glb, cracked_cache.glb), no Godot primitive.
			var plain := []
			for view: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
				if view.mesh is PrimitiveMesh and not s.view.is_ancestor_of(view):
					plain.append(String(view.name))
			_t.check("%s draws no plain shapes" % id, plain.is_empty(), str(plain))
			_t.check("%s is no marked activity" % id, not game.hud.edge_markers.unfinished_sites().has(s) if _has_markers(game) else true)
			_t.check("%s is declared before it is found" % id, game.ctx.codex.status(String(f["codex"]["id"])) == "unencountered")
			game.world.activities._break_wall(s)
			broken += 1
			_t.check("%s opens when its face breaks" % id, s.done and not s.wall.visible)
			_t.check("%s files its codex row" % id, game.ctx.codex.known(String(f["codex"]["id"])))
			_t.check("%s hushes its tell once open" % id, tell.is_queued_for_deletion())
			var luck: String = game.world.activities._luck_id(s)
			_t.eq("%s rolls on its own stream" % id, luck, "cracked_cache:" + id)
	var after: Dictionary = CampMenu.reading(game)["secrets"][0]
	_t.eq("the camp counts every find broken", after["found"], broken)
	_t.check("the camp shows the count", (CampMenu.reading(game)["lines"] as PackedStringArray).has("%d / %d Spillway secrets found" % [broken, Secrets.WORLD_CODEX[1].size()]))
	var disk := Codex.new()
	root.add_child(disk)
	disk.setup(game.events, game.run, game.flow, game.storage_dir)
	var kept := Secrets.WORLD_CODEX[1].filter(func(id): return disk.known(id)).size()
	_t.eq("the finds are on disk", kept, broken)
	disk.queue_free()
	game.queue_free()
	await process_frame


func _has_markers(game) -> bool:
	return game.get("hud") != null and game.hud.get("edge_markers") != null


# Two runs that differ only in their run seed can stand a find on different spots; the same run
# seed always stands it on the same one.
func _run_seed_moves(game, map_id: String) -> void:
	var picks := {}
	for run_seed in range(1, 33):
		var mixed := hash([game.ctx.rng.seed, run_seed, "field_finds"])
		for spec in Secrets.find_sites(map_id, mixed):
			picks[spec["site"]] = true
	_t.check("%s finds move with the run seed" % map_id, picks.size() == 4, str(picks.keys()))


# Every spot, not only the ones this run drew: the shell's ground (it stands CACHE_LANE_OFFSET out
# along its face, the back wall WALL_DEPTH behind) rises no more than FLAT_RISE_M.
func _every_spot_flat(game, map_id: String) -> void:
	for id in Secrets.FINDS:
		if Secrets.FINDS[id]["map"] != map_id:
			continue
		for spot in Secrets.FINDS[id]["spots"]:
			var face := Vector2(float(spot["face"][0]), float(spot["face"][1])).normalized()
			var side := Vector2(-face.y, face.x)
			var front := Vector2(float(spot["at"][0]), float(spot["at"][1])) + face * Activities.CACHE_LANE_OFFSET
			var lo := INF
			var hi := -INF
			for dx in [-Activities.WALL_HALF_W, 0.0, Activities.WALL_HALF_W]:
				for dz in [0.0, -Activities.WALL_DEPTH * 0.5, -Activities.WALL_DEPTH]:
					var p: Vector2 = front + side * dx + face * dz
					var y: float = game.ctx.terrain.height(p.x, p.y)
					lo = minf(lo, y)
					hi = maxf(hi, y)
			_t.check("%s at %s stands on flat ground" % [id, spot["site"]], hi - lo <= FLAT_RISE_M, "%.2f m" % (hi - lo))


func _rise(game, s) -> float:
	var lo := INF
	var hi := -INF
	for dx in [-Activities.WALL_HALF_W, 0.0, Activities.WALL_HALF_W]:
		for dz in [0.0, -Activities.WALL_DEPTH * 0.5, -Activities.WALL_DEPTH]:
			var p: Vector3 = s.to_global(Vector3(dx, 0.0, dz))
			var y: float = game.ctx.terrain.height(p.x, p.z)
			lo = minf(lo, y)
			hi = maxf(hi, y)
	return hi - lo
