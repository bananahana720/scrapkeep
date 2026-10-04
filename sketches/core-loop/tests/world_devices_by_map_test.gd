extends SceneTree

const Game := preload("res://src/game.gd")
const Interactables := preload("res://src/world/interactables.gd")
const T := preload("res://tests/support/t.gd")

# Interactable devices belong to a map, not to a stage number:
# - the default table's stage 1 is the Spillway and gets the Spillway's three devices;
# - the slice's stage 1 is another map and gets none of them, so no cache stands on its
#   spawn apron;
# - every placement key names a map some stage table uses.

var _t := T.new("world_devices_by_map_test")


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _stage_one(table: String) -> Dictionary:
	var game = Game.new()
	game.test_mode = true
	if table != "":
		game.table = table
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	await _frames(20)
	var ids: Array = game.world.interact.devices.map(func(device): return String(device.get("id")) if device.get("id") != null else device.name)
	var out := {"map": String(game.ctx.stages.of(1)["map"]), "count": game.world.interact.devices.size(), "ids": ids}
	game.free()
	await _frames(2)
	return out


func _run() -> void:
	var first: Dictionary = await _stage_one("")
	_t.eq("the default table's stage 1 is the Spillway", first["map"], "spillway")
	# META-3 (2026-10-04): the Rivet rescue cage registers as a fourth device beside the three placements.
	_t.eq("it gets the Spillway's devices plus the rescue cage", first["count"], (Interactables.PLACEMENTS["spillway"] as Array).size() + 1)
	_t.check("four of them", first["count"] == 4, "devices %s" % [first["ids"]])
	var slice: Dictionary = await _stage_one("slice")
	_t.check("the slice's stage 1 is another map", slice["map"] != "spillway", "map %s" % slice["map"])
	_t.eq("it gets none of the Spillway's devices", slice["count"], 0)
	var maps := {}
	for table in [preload("res://src/core/stage_defs.gd"), preload("res://src/core/slice_defs.gd")]:
		for row in table.DEFS:
			maps[String(row["map"])] = true
	for key in Interactables.PLACEMENTS:
		_t.check("placement key %s names a map a table uses" % key, maps.has(String(key)), "maps %s" % [maps.keys()])
	quit(_t.verdict())
