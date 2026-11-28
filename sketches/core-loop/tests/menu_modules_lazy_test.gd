extends SceneTree

# The camp, workshop, pause menu and met-enemy watch are off the title's path: a played game (not
# test_mode) builds them a few frames after the menu, and at once if a run or a camp visit comes
# first. A test-mode game keeps them built in _ready.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")

const FRAMES_MAX := 600

var _t := T.new("menu_modules_lazy_test")


func _initialize() -> void:
	_run.call_deferred()


func _built(game) -> bool:
	return game.get_node_or_null("Workshop") != null and game.get_node_or_null("PauseMenu") != null and game.get_node_or_null("CampHub") != null


func _none(game) -> bool:
	return game.get_node_or_null("Workshop") == null and game.get_node_or_null("PauseMenu") == null and game.get_node_or_null("CampHub") == null


func _game(test_mode: bool):
	var game = Game.new()
	game.test_mode = test_mode
	game.table = "park"
	root.add_child(game)
	return game


func _run() -> void:
	var eager = _game(true)
	_t.check("a test-mode game has them built in _ready", _built(eager) and eager.camp_hub != null)
	eager.free()

	var played = _game(false)
	_t.check("the menu shows without them", played.flow.state_name() == "title" and _none(played))
	var frames := 0
	while not _built(played) and frames < FRAMES_MAX:
		await process_frame
		frames += 1
	_t.check("they are built a few frames after the menu", _built(played) and frames >= 6, "%d frames" % frames)
	_t.check("the met-enemy watch is on", played.has_meta("met_watch"))
	_t.check("the camp's enemy picker is loaded with the camp", ResourceLoader.has_cached("res://src/ui/camp_enemy_picker.gd"))
	_t.check("the title is still up", played.flow.state_name() == "title")
	played.free()

	var early = _game(false)
	early.flow.press_start()
	_t.check("an early Start builds them before the class screen", _built(early) and early.flow.state_name() == "class_select")
	early.free()

	var camp = _game(false)
	_t.check("an early camp visit finds the camp", _none(camp) and camp.camp_hub != null and _built(camp))
	camp.free()

	var shop = _game(false)
	_t.check("an early workshop read finds it", shop.workshop() != null and _built(shop))
	shop.free()
	await physics_frame
	quit(_t.verdict())
