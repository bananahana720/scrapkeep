extends SceneTree

const Game := preload("res://src/game.gd")

# tests/support/t.gd eq() printed both values with var_to_str(). Handed a live game node, the
# variant writer walked its stored properties across the scene graph and Godot 4.7.2 segfaulted
# (the SIGABRT core dumps from headless tests). eq() must name an object without walking it.

var _t := preload("res://tests/support/t.gd").new("t_eq_object_test")
var _game


func _initialize() -> void:
	_run()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.ctx.calm = true
	_game.flow.enter_stage(1, Vector3.ZERO, false)
	for i in 60:
		await physics_frame
	var sites: Array = _game.hud.edge_markers.unfinished_sites()
	if not _t.check("the dam has a side site to compare", not sites.is_empty()):
		quit(_t.verdict())
		return
	var site = sites[0]
	_t.eq("a live site node compares without walking its graph", site, site)
	_t.eq("an array holding a live node compares", [site, 1], [site, 1])
	_t.eq("a dictionary holding a live node compares", {"site": site}, {"site": site})
	_t.check("the shown text names the node", _t.shown(site) == str(site), _t.shown(site))
	_t.check("a node inside an array stays short", _t.shown([site]).length() < 200, "%d chars" % _t.shown([site]).length())
	_t.check("a plain value keeps var_to_str's form", _t.shown({"a": Vector2(1, 2)}) == var_to_str({"a": Vector2(1, 2)}), _t.shown({"a": Vector2(1, 2)}))
	quit(_t.verdict())
