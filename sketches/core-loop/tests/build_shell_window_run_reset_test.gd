extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# Riveted Shell's S4 vault window must not outlive its run: a vault inside the 2 s window followed by a
# new run (picks empty, S4 not taken) leaves the air factor at x0.75 with no return cue, per
# DESIGN-NOTES "Flag or node missing: nothing changes". The factor also needs S4 taken, not just a window.
# Evidence limit: a fixture on the real Game with the vault event posted directly.

const CLASS_ID := "pylon_engineer"

var _failures := 0
var _game
var _player
var _cues := []


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	var ticks := roundi(seconds * Engine.physics_ticks_per_second)
	for i in ticks:
		await physics_frame


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	var def: Resource = ClassDef.by_id(CLASS_ID)
	_game.run.class_def = def
	_player.fit_class(def)
	_game.tuning.set_option("scrap_mode", "armor")
	_game.tuning.set_option("world_one_builds", "on")
	_game.tuning.set_option("hotwire_shell", "on")
	await _sim(0.5)
	var build = _game.build
	var tree = _player.tree
	tree.reset(CLASS_ID)
	tree.max_depth = 2
	tree.world_one = true
	for id in ["s_static_flutter", "s_face_runner"]:
		tree.open_checkpoint()
		tree.pick(id)
	_game.run.parts.clear()
	build.recompute()
	_game.events.vault_kicked.emit(_player.ball_position(), 20.0)
	await _sim(0.2)
	_check("window open with S4", build._shell_window > 0.0 and is_equal_approx(build.shell_air_factor(), 1.25),
		"window %.2f, factor %.2f" % [build._shell_window, build.shell_air_factor()])
	build.shell_air_changed.connect(func(factor: float, inverted: bool) -> void: _cues.append([factor, inverted]))
	_game.flow.new_run()
	await _sim(0.2)
	_check("new run: no S4", not build._face_runner_s4(), "S4 taken %s" % build._face_runner_s4())
	_check("new run: window cleared", is_equal_approx(build._shell_window, 0.0), "window %.2f" % build._shell_window)
	_check("new run: x0.75", is_equal_approx(build.shell_air_factor(), 0.75), "factor %.2f" % build.shell_air_factor())
	await _sim(2.5)
	_check("no return cue for an inversion the run never had", _cues.is_empty(), "cues %s" % [_cues])

	# A leftover window with S4 not taken never flips the factor.
	build._shell_window = 1.0
	_check("window without S4 is ignored", is_equal_approx(build.shell_air_factor(), 0.75), "factor %.2f" % build.shell_air_factor())

	print("build_shell_window_run_reset_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
