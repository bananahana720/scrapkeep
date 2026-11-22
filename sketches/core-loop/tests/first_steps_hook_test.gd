extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# The slam lesson (ui/first_steps.gd) at an open core never names a key that would not slam:
# a standing line owns Ctrl (player_ball._read_ctrl), so with one the lesson shows nothing,
# does not retire, and returns the moment the line drops.

class OpenCore:
	extends Node3D

	func staggered() -> bool:
		return true


var _game
var _failures := 0
var _wait := 0
var _started := false
var _prompts: Array[String] = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.events.prompt_shown.connect(func(verb: String): _prompts.append(verb))
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	_wait += 1
	if _wait < 3:
		return false
	# Ensure HUD play-piece visibility catches up to flow.in_play() when choose_class()
	# causes consecutive physics ticks before the next frame's _process().
	_game.hud._process(0.016)
	var lessons = _game.hud.first_steps
	var profile = _game.hud.profile
	var player = _game.player
	var core := OpenCore.new()
	_game.add_child(core)
	var cam: Camera3D = _game.camera.cam
	core.global_position = cam.global_position - cam.global_transform.basis.z * 12.0 - lessons.CORE_LIFT
	_game.flow.warden = core
	profile.add_use("roll")
	profile.add_use("roll")
	profile.add_use("roll")

	var free := {}
	for grounded in [true, false]:
		player.state.grounded = grounded
		player.kit.hooked = false
		lessons.step(0.016)
		free[grounded] = Array(lessons.drawn_words())
	_check("a free ball", free[true] == ["Space", "Ctrl", "SLAM"] and free[false] == ["Ctrl", "SLAM"],
		"grounded %s, airborne %s" % [free[true], free[false]])
	_prompts.clear()

	var hooked_words := {}
	for on_body in [true, false]:
		for grounded in [true, false]:
			player.state.grounded = grounded
			player.kit.hooked = true
			player.kit.on_body = on_body
			lessons.step(0.016)
			hooked_words["%s %s" % [on_body, grounded]] = Array(lessons.drawn_words())
	_check("a line to the Warden or to scenery shows no slam key",
		hooked_words.values().all(func(w): return w.is_empty()) and not "slam" in _prompts,
		"words %s, prompts %s" % [hooked_words, _prompts])
	_check("a hidden lesson does not retire", not lessons.retired("slam") and profile.uses("slam") == 0,
		"slam uses %d" % profile.uses("slam"))

	player.state.grounded = false
	player.kit.hooked = false
	lessons.step(0.016)
	_check("the lesson returns when the line drops", Array(lessons.drawn_words()) == ["Ctrl", "SLAM"],
		"words %s" % [Array(lessons.drawn_words())])

	player.kit.on_body = false
	_game.flow.warden = null
	core.queue_free()
	print("first_steps_hook_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
