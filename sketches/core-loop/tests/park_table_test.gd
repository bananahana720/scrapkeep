extends SceneTree
# KD0 2026-10-10: `--table=park` plays the six park map ids with the KF0 Warden columns beside the
# alpha table (PARK.md section 10). Rule: park_defs.gd has alpha's shape and Warden columns with
# the six park ids; the game resolves "park" to it and no choice stays the default; Terrain builds
# stage 1 from the park file (a ParkMap that passed the schema) and the other five from the old
# map of their stage until their park files land; a run on the park table starts on park_dam and
# the ball is placed at the park file's spawn.
# KB4: the park ground spans the 1.6 km square, so the stand-in spawn at [-100, -700] is inside
# the terrain and Terrain.contains(at) is a check.

const Game := preload("res://src/game.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Terrain := preload("res://src/world/terrain.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")

const IDS := ["park_dam", "park_flume", "park_pit", "park_sinkhole", "park_islands", "park_crown"]
const WARDEN_COLUMNS := ["world", "warden_family", "ancient", "warden_variant", "warden_plating", "warden_hp", "warden_lesson", "warden_hint", "posture"]
const SETTLE_TICKS := 20

var _failures := 0
var _game
var _ticks := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	var P = ParkDefs
	_check("count", P.COUNT == 6 and P.DEFS.size() == 6 and P.BOSS == AlphaDefs.BOSS, "COUNT %d rows %d" % [P.COUNT, P.DEFS.size()])
	for i in P.DEFS.size():
		var row: Dictionary = P.DEFS[i]
		var alpha: Dictionary = AlphaDefs.DEFS[i]
		_check("row %d map id" % (i + 1), String(row["map"]) == IDS[i], String(row["map"]))
		_check("row %d keys" % (i + 1), row.keys() == alpha.keys(), "same keys as alpha")
		for key in WARDEN_COLUMNS:
			_check("row %d %s" % [i + 1, key], row[key] == alpha[key], str(row[key]))
	_check("world kinds", [P.DEFS[1]["warden_family"], P.DEFS[2]["warden_family"], P.DEFS[4]["warden_family"]] == ["reactor", "swarm", "mind"], "KF0 columns")
	_check("lookups", P.world_of(3) == 2 and P.is_run_last(6) and P.of(1)["map"] == "park_dam" and P.packs().size() == 2, "world_of, is_run_last, of")

	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	_check("TABLES has park", Game.TABLES.get("park") == ParkDefs, "registered")
	_check("park resolves", game._chosen_table() == ParkDefs, "table park")
	game.table = "alpha"
	_check("alpha resolves", game._chosen_table() == AlphaDefs, "table alpha")
	game.table = ""
	_check("default unchanged", game._chosen_table() == StageDefs, "empty table")
	game.free()

	var alpha_terrain = Terrain.new(AlphaDefs)
	var alpha_maps := ["spillway", "reach", "dig", "dig_deep", "highdraft", "highdraft_crown"]
	for i in AlphaDefs.DEFS.size():
		_check("alpha map %d unchanged" % (i + 1), not (alpha_terrain.maps[i] is ParkMap), String(alpha_terrain.maps[i].title) + " " + alpha_maps[i])

	var terrain = Terrain.new(ParkDefs)
	_check("park terrain maps", terrain.maps.size() == 6, "%d maps" % terrain.maps.size())
	var dam = terrain.maps[0]
	_check("stage 1 is a park map", dam is ParkMap and dam.ok and dam.title == "park_dam", "title %s" % dam.title)
	# 2026-10-12 (W13 coordinator): a stage whose park file has landed must build from it as a valid
	# ParkMap; the rest stand on their old map. Was "stages 2 to 6 stand on their old map", which
	# every KD stage turned red by design when its file landed (KD2, KD3 gates).
	for i in range(1, 6):
		var path := "res://src/world/park/%s.json" % IDS[i]
		if FileAccess.file_exists(path):
			var m = terrain.maps[i]
			_check("stage %d builds from its park file" % (i + 1), m is ParkMap and m.ok and m.title == IDS[i], "%s landed" % IDS[i])
		else:
			_check("stage %d stands on its old map" % (i + 1), not (terrain.maps[i] is ParkMap), "until its park file lands")

	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	var ctx = _game.ctx
	if _ticks == 0:
		ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
	_ticks += 1
	if _ticks < SETTLE_TICKS:
		return false
	var map = ctx.terrain.map()
	_check("run on stage 1", ctx.run.stage == 1, str(ctx.run.stage))
	_check("run table is park", ctx.stages == ParkDefs and ctx.stages.of(1)["map"] == "park_dam", "park_dam")
	_check("drop-in map", map is ParkMap and map.title == "park_dam", "title %s" % map.title)
	var at: Vector3 = _game.player.body().global_position
	var spawn: Vector2 = map.spawn
	var flat := Vector2(at.x, at.z).distance_to(spawn)
	_check("ball placed at the park spawn", flat < 60.0, "%.1f m from spawn %s after %d ticks" % [flat, str(spawn), _ticks])
	_check("terrain contains the ball", ctx.terrain.contains(at), "at %s (KB4: the 1.6 km park ground)" % str(at))
	_game.queue_free()
	print("park_table_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)
	return true
