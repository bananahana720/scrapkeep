extends SceneTree

const BossPlate := preload("res://src/ui/boss_plate.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# The HUD seats the boss plate itself (LEGIBILITY section 4):
# - on the slice, striking the posture Warden engages it and the plate goes up top-centre,
#   bound to that Warden, with the objective plate under it;
# - a retry takes it down, and engaging again puts it back;
# - breaking the Warden takes it down;
# - on the local plating row the Warden never gets one.

var _t := T.new("ui_boss_plate_mount_test")
# 2026-10-04: retire with F6. The plating regression uses explicit test-only rows.
class PlatingGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _source := Intent.Scripted.new()


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _start(table: String) -> Node3D:
	_game = PlatingGame.new() if table == "" else Game.new()
	_game.test_mode = true
	if table != "":
		_game.table = table
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(36)
	_game.run.set_max_hp(99999.0)
	return _game.flow.warden


func _plates() -> Array:
	return _game.hud.get_children().filter(func(child): return child is BossPlate)


func _strike(warden: Node3D) -> void:
	_game.ctx.spawner.strike(warden, "ram", 1.0)
	await _frames(2)


func _slice() -> void:
	var warden: Node3D = await _start("slice")
	_t.check("the slice Warden fights by posture", is_instance_valid(warden) and warden.fight() == "posture")
	_t.eq("before the fight no plate is up", _plates().size(), 0)
	await _strike(warden)
	var up := _plates()
	_t.eq("striking the Warden puts one plate up", up.size(), 1)
	if up.size() == 1:
		var plate: Control = up[0]
		_t.check("it is bound to that Warden and shows its name", plate.active() and plate.drawn_words().size() > 0, "words %s" % [plate.drawn_words()])
		var screen: Vector2 = _game.hud._screen_size()
		var mounted := Rect2(plate.position, plate.size)
		_t.check("it sits top-centre inside the screen", absf(mounted.get_center().x - screen.x * 0.5) < 2.0 and mounted.position.y >= 0.0 and mounted.end.y < screen.y * 0.5,
			"plate %s on a %s screen" % [mounted, screen])
		var objective: Control = _game.hud._objective
		_t.check("the objective plate sits under it", objective.position.y >= mounted.end.y, "objective at y %.0f, plate ends at y %.0f" % [objective.position.y, mounted.end.y])
	_game.flow.retry_stage()
	await _frames(4)
	_t.eq("a retry takes the plate down", _plates().size(), 0)
	warden = _game.flow.warden
	await _strike(warden)
	_t.eq("engaging again puts it back", _plates().size(), 1)
	var guard := 0
	while is_instance_valid(warden) and not warden.is_dead() and guard < 60:
		# The slice row's rams do not shatter, so these are smashes: a smash fills the bar and, once it
		# is open, shatters the chunk at once.
		_game.player.smash_landing = warden
		_game.ctx.spawner.strike(warden, "ram", 40.0)
		await _frames(2)
		guard += 1
	_t.check("the Warden broke", not is_instance_valid(warden) or warden.is_dead(), "%d strikes" % guard)
	await _frames(4)
	_t.eq("breaking the Warden takes the plate down", _plates().size(), 0)
	_game.free()
	await _frames(2)


func _default_table() -> void:
	var warden: Node3D = await _start("")
	_t.check("the local Warden fights by plating", is_instance_valid(warden) and warden.fight() == "plating")
	await _strike(warden)
	_t.eq("a plating Warden gets no plate", _plates().size(), 0)
	_game.free()
	await _frames(2)


func _run() -> void:
	await _slice()
	await _default_table()
	quit(_t.verdict())
