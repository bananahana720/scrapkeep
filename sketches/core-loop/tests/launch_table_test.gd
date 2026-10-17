extends SceneTree

const Game := preload("res://src/game.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const T := preload("res://tests/support/t.gd")

# KD7 launch default: a bare launch (no --table, not a test) plays the park table, so the
# AppImage's app-menu entry reaches the six parks; test_mode keeps the legacy maps, and a named
# table still wins either way.

var _t := T.new("launch_table_test")


func _pick(test_mode: bool, table: String):
	var game := Game.new()
	game.test_mode = test_mode
	game.table = table
	var picked = game._chosen_table()
	game.free()
	return picked


func _initialize() -> void:
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	_t.check("this run passes no --table", not Array(args).any(func(a): return String(a).begins_with("--table=")), str(args))
	_t.eq("the launch default is the park table", Game.LAUNCH_TABLE, "park")
	_t.check("a bare launch picks the park table", _pick(false, "") == ParkDefs)
	_t.check("a test with no table keeps the legacy maps", _pick(true, "") == StageDefs)
	_t.check("--table=default still reaches the legacy maps from a launch", _pick(false, "default") == StageDefs)
	_t.check("a test can still pick the park table", _pick(true, "park") == ParkDefs)
	quit(_t.verdict())
