extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# An arena retry starts the fight clean for the class kit, as a stage retry does: the
# special cooldown, the overdrive and the fire cooldown reset on stage_content_cleared.
# Overdrive fires in the arena, the arena is retried at once with the special on its
# 6 s cooldown, and F fires again on the first tick of the retried fight.

var _game
var _combat
var _source := Intent.Scripted.new()
var _failures := 0
var _step := 0
var _specials := 0
var _before_retry := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	match _step:
		0:
			_combat = _game.ctx.spawner
			_game.ctx.calm = true
			_game.player.source = _source
			_game.events.special_used.connect(func(_id: String, _at: Vector3): _specials += 1)
			_game.flow.press_start()
			_game.flow.choose_class(1)
			_game.run.set_max_hp(99999.0)
			_game.flow.enter_boss(Vector3.ZERO)
		1:
			_source.press["special_pressed"] = true
		3:
			_before_retry = _specials
			_report("arena_special", _before_retry == 1 and _game.flow.in_arena,
				"overdrive in the arena: %d special, in_arena %s" % [_before_retry, _game.flow.in_arena])
			_game.flow.retry_stage()
		4:
			_source.press["special_pressed"] = true
		6:
			_report("retry_ready", _specials == _before_retry + 1,
				"F on the first tick after the arena retry: %d special(s) fired (cooldown would block it)" % (_specials - _before_retry))
			return _finish()
	_step += 1
	return false


func _finish() -> bool:
	var ok := _failures == 0
	print("combat_arena_retry_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
