extends SceneTree

# Ambient life's hook in presentation.gd: a park game on the high preset builds one AmbientLife whose pool
# fills on stage 1 (park_dam), the low preset (no set_dressing) frees it, and switching back builds it again.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const AmbientLife := preload("res://src/presentation/ambient_life.gd")
const Intent := preload("res://src/movement/intent.gd")

var _t := T.new("ambient_hook_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	GraphicsPreset.apply("high")
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 5:
		await physics_frame
	var life = game.presentation.ambient_life
	_t.check("high preset builds one AmbientLife", is_instance_valid(life) and life.get_script() == AmbientLife)
	_t.check("its pool fills on stage 1 (%s)" % (life.map_id if is_instance_valid(life) else "?"),
		is_instance_valid(life) and life.pool != null and life.pool.members.size() > 0)
	_t.eq("one AmbientLife under presentation", game.presentation.find_children("AmbientLife", "", false, false).size(), 1)
	GraphicsPreset.apply("low")
	_t.check("low preset frees it", not is_instance_valid(game.presentation.ambient_life))
	GraphicsPreset.apply("high")
	_t.check("high again builds it again", is_instance_valid(game.presentation.ambient_life))
	game.free()
	quit(_t.verdict())
