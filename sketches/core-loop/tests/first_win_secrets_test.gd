extends SceneTree

# Andrew's Q8 answer, "A few secrets" (17 Oct 2026): the first won run opens one hidden room per
# world, one hidden tune and one alternate paint per pilot (secrets.gd). A fresh profile holds none
# of them and is shown no hint; a profile that won holds all of them, on disk, and so does a profile
# that won before the secrets existed. The rooms stand where secrets.gd says, in dead-end zones of
# their park graphs, and a real Game builds them only for a won profile.

const Achievements := preload("res://src/core/achievements.gd")
const AchievementsPage := preload("res://src/ui/achievements_page.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const CustomizePage := preload("res://src/ui/customize_page.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const Park := preload("res://src/core/park_defs.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const Secrets := preload("res://src/core/secrets.gd")
const T := preload("res://tests/support/t.gd")

# A secret room keeps this far from every authored activity, so it never reads as part of one.
const ROOM_CLEAR_M := 60.0
const MARKERS := ["todo", "tbd", "fixme", "lorem", "placeholder", "coming soon"]


class Bus:
	extends Node
	signal run_started
	signal run_ended(won: bool)
	signal player_died
	signal world_entered(world: int)
	signal boss_defeated
	signal achievement_earned(id: String)


class FakeRun:
	extends RefCounted
	var settled: Array = []

	func summary() -> Dictionary:
		return {"retries": 1, "parts": []}

	func class_id() -> String:
		return "pylon_engineer"


var _t := T.new("first_win_secrets_test")
var _serial := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_table()
	_placement()
	_save_round_trip()
	_backfill_old_win()
	_sitting()
	await _game_builds_rooms("fresh")
	await _game_builds_rooms("won")
	await _game_builds_rooms("sitting")
	quit(_t.verdict())


func _path() -> String:
	_serial += 1
	return "user://first-win-secrets-%d-%d.json" % [OS.get_process_id(), _serial]


func _progress(profile, bus: Bus) -> Progress:
	var progress := Progress.new()
	root.add_child(progress)
	progress.setup(bus, FakeRun.new(), profile, func(): return 1000.0)
	return progress


func _table() -> void:
	var pilots := ClassDef.all().map(func(d): return d.id)
	_t.eq("achievements still validate", Achievements.validate(Achievements.ROWS, Achievements.bus_signals(), pilots, Cosmetics.ids()), [])
	_t.eq("cosmetics still validate", Cosmetics.validate(Cosmetics.ROWS, pilots), [])
	_t.eq("one paint row per paint pilot", Secrets.PAINTS.keys(), Secrets.PAINT_ROWS.keys())
	for pilot in pilots:
		_t.check("%s has a secret paint" % pilot, Secrets.PAINTS.has(pilot))
	for pilot in Secrets.PAINTS:
		var paint: String = Secrets.PAINTS[pilot]
		var r := Cosmetics.row(paint)
		_t.check("%s is a paint for %s" % [paint, pilot], r.get("slot") == "paint" and r.get("pilot") == pilot and r.get("starter") == false, str(r))
		_t.check("%s needs no art (a tint)" % paint, not r.has("asset") and not Cosmetics.is_pending(paint))
		var grant: String = Secrets.PAINT_ROWS[pilot]
		_t.eq("%s is granted by its secret row" % paint, Achievements.for_cosmetic(paint), grant)
		var g := Achievements.row(grant)
		_t.check("%s is hidden and pays on a won run" % grant, g.get("hidden") == true and g.get("on") == "run_ended" and g.get("where", {}) == {"won": true}, str(g))
	_t.eq("the unlock is the first win", Secrets.UNLOCK, "first_win")
	_t.check("the first win row exists", Achievements.ROWS.has(Secrets.UNLOCK))
	var worlds := {}
	for id in Secrets.ROOMS:
		var room: Dictionary = Secrets.ROOMS[id]
		worlds[int(room["world"])] = worlds.get(int(room["world"]), 0) + 1
		var log_text := String(room["log"])
		_t.check("%s log fits a field note" % id, log_text.split(" ", false).size() <= mini(Secrets.LOG_WORD_CAP, LoreRows.FIELD_NOTE_WORD_CAP), str(log_text.split(" ", false).size()))
		for word in MARKERS:
			_t.check("%s text carries no %s" % [id, word], not (log_text + String(room["name"])).to_lower().contains(word))
	_t.eq("one room in each world", worlds, {1: 1, 2: 1, 3: 1})


func _placement() -> void:
	var maps := {}
	for row in Park.DEFS:
		maps[String(row["map"])] = true
	for id in Secrets.ROOMS:
		var room: Dictionary = Secrets.ROOMS[id]
		var map_id := String(room["map"])
		_t.check("%s stands on a park map the table plays" % id, maps.has(map_id), map_id)
		var map := ParkMap.new("res://src/world/park/%s.json" % map_id)
		_t.check("%s park loads" % id, map.ok, str(map.errors))
		if not map.ok:
			continue
		var at := Vector2(float(room["at"][0]), float(room["at"][1]))
		_t.check("%s is inside the play rect" % id, map.play_rect.grow(-20.0).has_point(at), str(at))
		_t.check("%s names a real park row" % id, map.park["park_rows"].any(func(r): return r["id"] == room["site"]), room["site"])
		for act in map.park["activity_rows"]:
			var d := at.distance_to(Vector2(float(act["at"][0]), float(act["at"][1])))
			_t.check("%s keeps clear of %s" % [id, act["id"]], d >= ROOM_CLEAR_M, "%.0f m" % d)
		var g = ParkGraph.read("res://assets/park/%s/graph.bin" % map_id)
		_t.check("%s park has a graph" % id, g != null)
		if g == null:
			continue
		var node: int = g.nearest(at)
		_t.check("%s door is reachable from the drop-in" % id, is_finite(g.d_spawn_node(node)), str(g.d_spawn_node(node)))
		_t.check("%s door is a door_ok node" % id, g.flags(node) & ParkGraph.DOOR_OK != 0, str(g.flag_names(node)))
		var zone: int = g.zone_of(node)
		var anchor := {}
		for a in g.anchors():
			if a["zone"] == zone:
				anchor = a
		_t.check("%s stands in a dead-end zone off every line" % id, not anchor.is_empty() and anchor["rank"] > 0, str(anchor))
		_t.eq("%s zone is its site row" % id, g.zones()[zone]["row"], room["site"])


# What a profile is shown of the secrets: the paint cards on each pilot's customize tab and the
# achievements page rows. A fresh profile must be shown none of them.
func _shown(profile) -> Array:
	var out := []
	var page = CustomizePage.new()
	page._profile = profile
	for pilot in Secrets.PAINTS:
		page.pilot = pilot
		for id in page.shown_ids("paint"):
			if Secrets.PAINTS.values().has(id):
				out.append(id)
	page.free()
	var list = AchievementsPage.new()
	root.add_child(list)
	list.refresh(profile, null)
	for id in list.rows:
		if Secrets.PAINT_ROWS.values().has(id):
			out.append(id)
	list.free()
	return out


func _held_all(profile) -> Dictionary:
	return {"rooms": Secrets.ROOMS.keys(), "tunes": [Secrets.TUNE], "paints": Secrets.PAINTS.values()}


func _save_round_trip() -> void:
	var path := _path()
	var fresh := Profile.new(path)
	fresh.load_profile()
	var bus := Bus.new()
	root.add_child(bus)
	var progress := _progress(fresh, bus)
	var announced := []
	bus.achievement_earned.connect(func(id): announced.append(id))
	_t.eq("a fresh profile is shown no secret paint or row", _shown(fresh), [])
	_t.eq("a fresh profile holds no secrets", Secrets.held(fresh), {"rooms": [], "tunes": [], "paints": []})
	_t.check("a fresh profile's jukebox has no hidden tune", not Secrets.tune_open(fresh))
	for id in Secrets.ROOMS:
		_t.eq("a fresh profile gets no %s" % id, Secrets.room_sites(String(Secrets.ROOMS[id]["map"]), fresh), [])
	for pilot in Secrets.PAINTS:
		_t.check("a fresh profile does not own %s" % Secrets.PAINTS[pilot], not CustomizePage.owns(fresh, Secrets.PAINTS[pilot]))
	bus.run_started.emit()
	bus.run_ended.emit(false)
	_t.eq("a lost run opens nothing", Secrets.held(fresh), {"rooms": [], "tunes": [], "paints": []})
	bus.run_started.emit()
	bus.run_ended.emit(true)
	_t.eq("a won run opens every secret", Secrets.held(fresh), _held_all(fresh))
	_t.check("the first win is announced", announced.has("first_win"), str(announced))
	_t.check("the secret paints earn silently", not announced.any(func(id): return Secrets.PAINT_ROWS.values().has(id)), str(announced))
	_t.eq("a won profile is shown every paint and row", _shown(fresh).size(), Secrets.PAINTS.size() * 2)
	var disk := Profile.new(path)
	_t.check("the won profile reloads", disk.load_profile(), disk.last_error)
	_t.eq("the won profile holds every secret on disk", Secrets.held(disk), _held_all(disk))
	_t.check("its jukebox opens the hidden tune", Secrets.tune_open(disk))
	for id in Secrets.ROOMS:
		var sites := Secrets.room_sites(String(Secrets.ROOMS[id]["map"]), disk)
		_t.eq("the won profile gets %s" % id, sites.map(func(s): return s["secret"]), [id])
		_t.eq("%s is a cracked cache paying rare" % id, [sites[0]["id"], sites[0]["pay"]], ["cracked_cache", {"rarities": ["rare"]}])
	progress.queue_free()
	bus.queue_free()


func _backfill_old_win() -> void:
	var path := _path()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": 4, "generation": 3, "pilots": [], "achievements": {"first_win": 9}}))
	f.close()
	var old := Profile.new(path)
	_t.check("a profile that won before the secrets loads", old.load_profile(), old.last_error)
	var bus := Bus.new()
	root.add_child(bus)
	var earned := []
	bus.achievement_earned.connect(func(id): earned.append(id))
	var progress := _progress(old, bus)
	_t.eq("setup backfills every paint for an old win", Secrets.held(old)["paints"], Secrets.PAINTS.values())
	_t.eq("the backfill announces nothing at boot", earned, [])
	_t.eq("a second setup earns nothing", progress.backfill_secrets(), 0)
	var disk := Profile.new(path)
	disk.load_profile()
	_t.eq("the backfill is saved", Secrets.held(disk), _held_all(disk))
	progress.queue_free()
	bus.queue_free()


func _sitting() -> void:
	var p := Profile.new(_path())
	p.load_profile()
	_t.check("the sitting opens the rooms and tune", Secrets.open(p, true) and Secrets.tune_open(p, true))
	_t.eq("the sitting gets every room site", Secrets.room_sites("park_pit", p, true).size(), 1)
	Secrets.open_for_sitting(p)
	_t.eq("the sitting owns every paint", Secrets.held(p, true), _held_all(p))


# The real Game on the park table: a won profile finds each world's room on its stage, a fresh one none.
func _game_builds_rooms(label: String) -> void:
	var won := label != "fresh"
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = Intent.Scripted.new()
	var profile_path: String = game.storage_dir.path_join("profile.json")
	var before := PackedByteArray()
	if label == "won":
		game.ctx.profile.earn("first_win", 1.0)
	elif label == "sitting":
		_t.check("sitting: the profile has not won", not game.ctx.profile.earned("first_win"))
		game.ctx.profile.save()
		before = FileAccess.get_file_as_bytes(profile_path)
		game.tuning.apply_args(PackedStringArray(["--profile=sitting"]), "launch")
		game.sitting_save_guard()
		_t.eq("sitting: every paint is open", Secrets.held(game.ctx.profile, true)["paints"], Secrets.PAINTS.values())
	game.flow.press_start()
	game.flow.choose_class(1)
	for id in Secrets.ROOMS:
		var map_id := String(Secrets.ROOMS[id]["map"])
		var index := -1
		for i in game.ctx.terrain.maps.size():
			if "park" in game.ctx.terrain.maps[i] and String(game.ctx.terrain.maps[i].park.get("map", "")) == map_id:
				index = i
		_t.check("%s: %s is on the park table" % [label, map_id], index >= 0)
		if index < 0:
			continue
		game.flow.enter_stage(index + 1, Vector3.ZERO, false)
		await physics_frame
		await physics_frame
		var rooms: Array = game.world.activities.sites.filter(func(s): return String(s.name).begins_with("Secret_"))
		if not won:
			_t.eq("fresh: %s builds no secret room" % map_id, rooms.size(), 0)
			continue
		_t.eq("%s: %s builds its room" % [label, map_id], rooms.map(func(s): return String(s.name)), ["Secret_" + id])
		if rooms.is_empty():
			continue
		var room = rooms[0]
		var at: Array = Secrets.ROOMS[id]["at"]
		var planar := Vector2(room.global_position.x - float(at[0]), room.global_position.z - float(at[1])).length()
		_t.check("%s: %s stands at its spot" % [label, id], planar <= 12.0, "%.1f m" % planar)
		var ground: float = game.ctx.terrain.height(room.global_position.x, room.global_position.z)
		_t.check("%s: %s sits on the ground" % [label, id], absf(room.global_position.y - ground) < 0.5, "%.2f vs %.2f" % [room.global_position.y, ground])
		var log_label: Label3D = room.get_node_or_null("RoomLog")
		_t.check("%s: %s hangs its crew-log line" % [label, id], log_label != null and log_label.text.contains(String(Secrets.ROOMS[id]["log"])))
		_room_reads(label, id, room)
		_t.check("%s: %s is sealed by its cracked wall" % [label, id], room.wall != null and room.wall.visible and not room.done)
		game.world.activities._break_wall(room)
		_t.check("%s: %s opens when its wall breaks" % [label, id], room.done and not room.wall.visible)
	if won:
		var plain = game.world.activities._build("cracked_cache", Vector2(0.0, 0.0))
		_t.check("%s: an ordinary cracked cache carries no room tell" % label, plain.wall != null
			and plain.wall.get_node_or_null("RoomTally") == null and plain.wall.get_node_or_null("RoomGlove") == null
			and plain.get_node_or_null("RoomLog") == null)
	if label == "sitting":
		_t.check("sitting: the profile file is untouched", FileAccess.get_file_as_bytes(profile_path) == before and before.size() > 0, str(before.size()))
	game.queue_free()
	await process_frame


# The red team's read on 89bc14ae: the log line washed out on the fired wall's sand glow. It now sits on
# its own dark board above the ball's eye line, fits inside it, and the room carries its two tells.
func _room_reads(label: String, id: String, room) -> void:
	var log_label: Label3D = room.get_node_or_null("RoomLog")
	var board: Node3D = room.get_node_or_null("RoomBoard")
	if log_label == null or board == null:
		_t.check("%s: %s has its crew board" % [label, id], false)
		return
	# The board's own box, the model's plate (W1-22) or the plain one, in the site's frame.
	var bm: AABB = (board as MeshInstance3D).mesh.get_aabb()
	bm.position += board.position
	var plate: Color = (board as MeshInstance3D).material_override.albedo_color
	var ratio := _contrast(log_label.modulate, plate)
	_t.check("%s: %s log contrast on its board >= 7:1" % [label, id], ratio >= 7.0, "%.1f:1" % ratio)
	_t.check("%s: %s log stands in front of its board" % [label, id], log_label.position.z > bm.end.z)
	var box: AABB = log_label.get_aabb()
	_t.check("%s: %s log fits its board" % [label, id], box.size.x > 0.0 and box.size.x <= bm.size.x and box.size.y <= bm.size.y,
		"%.2f x %.2f m on %.2f x %.2f" % [box.size.x, box.size.y, bm.size.x, bm.size.y])
	var low := bm.position.y
	_t.check("%s: %s board clears the ball's eye line" % [label, id], low >= 3.6 and bm.end.y <= 6.0, "%.2f m" % low)
	var tally: Node3D = room.wall.get_node_or_null("RoomTally")
	_t.check("%s: %s has a chalk tally on its face" % [label, id], tally != null and tally.get_child_count() == 5 and tally.position.z > 0.5)
	var glove: Node3D = room.wall.get_node_or_null("RoomGlove")
	var glove_crafted := glove != null and glove.get_child_count() == 3
	if glove_crafted:
		for child in glove.get_children():
			if not (child is MeshInstance3D and (child as MeshInstance3D).mesh is ArrayMesh):
				glove_crafted = false
				break
	_t.check("%s: %s hangs a glove on its face" % [label, id], glove != null and glove.position.z > 0.5 and glove_crafted)


# WCAG relative-luminance contrast between two colours.
func _contrast(a: Color, b: Color) -> float:
	var la := _luma(a)
	var lb := _luma(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luma(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)
