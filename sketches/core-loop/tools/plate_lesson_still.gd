extends SceneTree


const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

const AHEAD := 9.0
const SHOTS := {"before": -1, "glance": 13, "streak": 30, "after": 220}

var _game
var _out := "artifacts/local/plate-lesson"
var _frame := 0
var _glanced_at := -1
var _dummy: Node3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_frame += 1
	if _frame == 2:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(1)
		_game.run.set_max_hp(99999.0)
	elif _frame == 140:
		_game.player.reset_to(_game.player.ball_position(), Vector3.ZERO)
		var combat = _game.ctx.spawner
		combat.heft_override = 1.0
		var forward: Vector3 = -_game.camera.cam.global_basis.z
		forward.y = 0.0
		var at: Vector3 = _game.player.ball_position() + forward.normalized() * AHEAD + _game.camera.cam.global_basis.x * 4.0
		_dummy = combat.spawn_enemy("plated_brute", _game.ctx.terrain.drop_point(at.x, at.z, 1.6))
		_dummy.plating = 90.0
		_dummy.hp = 1000.0
	elif _frame > 140 and _frame < 170:
		_game.player.reset_to(_game.player.ball_position(), Vector3.ZERO)
	elif _frame == 170:
		_game.player.reset_to(_game.player.ball_position(), Vector3.ZERO)
		_shot("before")
		_game.ctx.spawner.strike(_dummy, "ram", 2.0)
		_glanced_at = _frame
	elif _glanced_at > 0:
		_game.player.reset_to(_game.player.ball_position(), Vector3.ZERO)
		for name in SHOTS:
			if SHOTS[name] == _frame - _glanced_at:
				_shot(name)
		if _frame - _glanced_at >= SHOTS["after"]:
			quit(0)
			return true
	return false


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(_out.path_join("plate-%s.png" % name))
	print("still %s frame %d tint %s rim energy %.2f punch %.1f" % [name, _frame, _dummy.tint_state + (" glance %.2f s left, lesson %s" % [_dummy._glance_left, _game.hud.first_steps.shown_ids()]), _dummy._tint_materials[0].emission_energy_multiplier, _game.ctx.spawner.punch_now()])
