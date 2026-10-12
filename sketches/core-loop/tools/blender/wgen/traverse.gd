extends "res://tools/traversal_line.gd"

const TrialGame := preload("res://tools/blender/wgen/trial_game.gd")

func _setup_park() -> bool:
	preload("res://tools/blender/wgen/context.gd").install()
	_floor = _settings.has("floor")
	_class_key = _pilot if _pilot != "" else FLOOR_CLASS
	if not PARK_PILOTS.has(_class_key):
		return false
	_pilot = FLOOR if _floor else _class_key
	_stage = 1
	_map_id = String(_settings.get("map", ""))
	_lines = load_lines(PARK_LINES % _map_id)
	var read := ParkSchema.load_park("res://src/world/park/%s.json" % _map_id)
	var errors: Array = read["errors"]
	if errors.is_empty():
		errors = ParkSchema.validate_lines(_lines, read["data"])
	if not errors.is_empty():
		printerr("wgen: traversal schema failed: " + ParkSchema.describe(errors))
		return false
	print("wgen: trial traversal %s/%s; shipped sampler and bot, private table instance" % [_map_id, _pilot])
	return true

func _next() -> void:
	_index += 1
	if _index >= _seeds.size():
		_finish()
		return
	Engine.time_scale = 1.0
	seed(_seeds[_index])
	_game = TrialGame.new()
	_game.test_mode = true
	_game.table = PARK
	root.add_child(_game)
	_driver = null
