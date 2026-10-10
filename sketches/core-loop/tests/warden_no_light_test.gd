extends SceneTree

const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")

# LIGHT-WARDEN (w13): a dressed Warden carries no Light3D. flow._place_beacon frees the Warden on
# every stage, and a light freed with it is the stage-freed light crash class (light_lifetime_lint_test).
# The cool fill reads as an additive rim on its own CoolFill shells over Tower and Housing instead.
# Two stages, so two Wardens are dressed and the first one's free is crossed.
const MAX_WAIT := 120

var _t := T.new("warden_no_light_test")
var _game


func _initialize() -> void:
	_run.call_deferred()


func _dressed(warden) -> bool:
	return is_instance_valid(warden) and not _game.presentation.hero_assets.warden_of(warden).is_empty()


func _check_warden(stage: int) -> void:
	var waited := 0
	while not _dressed(_game.flow.warden) and waited < MAX_WAIT:
		await physics_frame
		waited += 1
	var warden = _game.flow.warden
	if not _t.check("stage %d dresses its Warden" % stage, _dressed(warden), "%d frames" % waited):
		return
	var lights: Array = warden.find_children("*", "Light3D", true, false)
	_t.check("stage %d Warden has no Light3D descendant" % stage, lights.is_empty(),
		", ".join(lights.map(func(l: Node) -> String: return String(warden.get_path_to(l)))))
	var rims: Array = warden.find_children("CoolFill", "MeshInstance3D", true, false)
	_t.check("stage %d cool fill is drawn as rim shells" % stage, rims.size() == 2, "%d CoolFill shells" % rims.size())


func _run() -> void:
	seed(280928)
	_game = Game.new()
	_game.name = "Game"
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	await process_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.flow.press_start()
	await physics_frame
	_game.flow.choose_class(0)
	await _check_warden(1)
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	await physics_frame
	await _check_warden(2)
	quit(_t.verdict())
