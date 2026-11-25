extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")

# R6 Second Wind inversion (--hotwire-shell=on --world-one-builds=on, BUILD-SYSTEMS.md R6 row):
# Riveted Shell's air-control factor is x0.75, and x1.0 while Rivet sprints with the world-one
# Second Wind taken. The sprint edge is read from kit.sprinting in Build's physics step (no end
# signal exists), so the mod follows within STEP_TICKS physics ticks, never the same frame.
# The sprint is driven through the real player tick (intent.movement_pressed/held), because
# augments._sprint overwrites kit.sprinting each tick.
# S4 and R6 cannot co-occur through UpgradeTree.pick (trees are per class); the overlap is a
# forced fixture. The precedence, the highest active factor, is a code choice, not a design ruling.
# Evidence limit: a fixture on the real Game; how the cancellation feels is unjudged.

const CLASS_ID := "runner_gunner"
const STEP_TICKS := 2

var _failures := 0
var _game
var _player
var _held := true


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _ratio() -> float:
	return _game.tuning.f("air_control") / _game.tuning.base("air_control")


func _is(v: float) -> bool:
	return is_equal_approx(_ratio(), v) and is_equal_approx(_game.build.shell_air_factor(), v)


func _fmt() -> String:
	return "ratio %.3f, factor %.2f, sprinting %s" % [_ratio(), _game.build.shell_air_factor(), _player.kit.sprinting]


# A fresh Rivet tree with these picks, shell and world-one profile as given, charges full.
func _setup(picks: Array, world_one: bool, shell: bool) -> void:
	_game.tuning.set_option("world_one_builds", "on" if world_one else "off")
	_game.tuning.set_option("hotwire_shell", "on" if shell else "off")
	var tree = _player.tree
	tree.reset(CLASS_ID)
	tree.max_depth = 2 if world_one else 4
	tree.world_one = world_one
	for id in picks:
		tree.open_checkpoint()
		tree.pick(id)
	_player.fit_class(ClassDef.by_id(CLASS_ID))
	# fit_class reset the tree; take the picks again on the fitted kit.
	tree.reset(CLASS_ID)
	tree.max_depth = 2 if world_one else 4
	tree.world_one = world_one
	for id in picks:
		tree.open_checkpoint()
		tree.pick(id)
	_player.kit.sprinting = false
	_game.run.parts.clear()
	_lift()
	_game.build.recompute()


# Hold the ball in the air, so grounded state is not what the check relies on.
func _lift() -> void:
	var body = _player.body()
	body.global_position = _player.ball_position() + Vector3(0.0, 30.0, 0.0)
	body.linear_velocity = Vector3.ZERO


func _sprint_start() -> void:
	_player.source.hold = {"movement_held": true}
	_player.source.press = {"movement_pressed": true}


func _release() -> void:
	_player.source.hold = {}


func _vault() -> void:
	_game.events.vault_kicked.emit(_player.ball_position(), 20.0)


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.class_def = ClassDef.by_id(CLASS_ID)
	_player.fit_class(ClassDef.by_id(CLASS_ID))
	await _ticks(30)
	var build = _game.build
	# Re-pinned 2026-11-24 (E2-09, PILOT-CADENCE §6.2): R6 sits under Big Iron in World 1.
	var r6 := ["r_big_iron", "r_second_wind"]

	# Before a sprint x0.75; a real sprint start cancels; release restores.
	_setup(r6, true, true)
	await _ticks(STEP_TICKS)
	_check("before sprint x0.75", _is(0.75) and not _player.state.grounded and build._second_wind_r6() and _game.flow.in_play(),
		"%s, grounded %s, R6 %s, in play %s" % [_fmt(), _player.state.grounded, build._second_wind_r6(), _game.flow.in_play()])
	_sprint_start()
	await _ticks(STEP_TICKS + 1)
	_check("sprinting airborne x1.0", _player.kit.sprinting and _is(1.0) and not _player.state.grounded, "%s, grounded %s" % [_fmt(), _player.state.grounded])
	await _ticks(10)
	_check("still x1.0 mid sprint", _player.kit.sprinting and _is(1.0), _fmt())

	# Recompute during the sprint keeps the cancellation and stacks with a part's mod.
	_game.run.parts.append("slipstream")
	build.recompute()
	var part_mod: float = build.sheet.mod("air_control")
	_check("recompute during sprint", _player.kit.sprinting and is_equal_approx(_ratio(), part_mod * 1.0) and part_mod > 1.0,
		"ratio %.4f, part x%.2f, expected %.4f" % [_ratio(), part_mod, part_mod])
	_release()
	await _ticks(STEP_TICKS + 1)
	_check("after release x0.75 (part)", not _player.kit.sprinting and is_equal_approx(_ratio(), part_mod * 0.75), "%s, expected %.4f" % [_fmt(), part_mod * 0.75])
	_game.run.parts.clear()
	build.recompute()

	# The sprint ends by drain (charge spent, sprint_left runs out while still held).
	_setup(r6, true, true)
	_sprint_start()
	await _ticks(STEP_TICKS + 1)
	var was: bool = _player.kit.sprinting and _is(1.0)
	_player.kit.sprint_left = 0.02
	await _ticks(STEP_TICKS + 2)
	_check("after drain x0.75", was and not _player.kit.sprinting and _is(0.75), "sprinted %s, %s" % [was, _fmt()])
	_release()

	# The sprint ends because the SPRINT flag goes false (augments.gd :185).
	_setup(r6, true, true)
	_sprint_start()
	await _ticks(STEP_TICKS + 1)
	var was2: bool = _player.kit.sprinting and _is(1.0)
	_player.kit.set_on(preload("res://src/movement/augments.gd").SPRINT, false)
	await _ticks(STEP_TICKS + 1)
	_check("after SPRINT off x0.75", was2 and not _player.kit.sprinting and _is(0.75), "sprinted %s, %s" % [was2, _fmt()])
	_player.kit.set_on(preload("res://src/movement/augments.gd").SPRINT, true)
	_release()

	# No R6 (another node): stays x0.75 through a sprint.
	_setup(["r_big_iron"], true, true)
	_sprint_start()
	await _ticks(STEP_TICKS + 3)
	_check("no R6 stays x0.75", _player.kit.sprinting and _is(0.75), _fmt())
	_release()
	await _ticks(STEP_TICKS + 1)
	_check("no R6 after sprint x0.75", _is(0.75), _fmt())

	# No shell: 1.0 throughout.
	_setup(r6, true, false)
	await _ticks(STEP_TICKS)
	var before := _is(1.0)
	_sprint_start()
	await _ticks(STEP_TICKS + 3)
	_check("no shell stays x1.0", before and _player.kit.sprinting and _is(1.0), "before %s, %s" % [before, _fmt()])
	_release()
	await _ticks(STEP_TICKS + 1)
	_check("no shell after sprint x1.0", _is(1.0), _fmt())

	# World-one profile off: R6 taken (under base root r_juggernaut) but the ratio stays x0.75 through a sprint.
	_setup(["r_juggernaut", "r_second_wind"], false, true)
	_sprint_start()
	await _ticks(STEP_TICKS + 3)
	_check("world-one off stays x0.75", _player.kit.sprinting and _is(0.75) and not build._second_wind_r6(),
		"%s, picks %s, world_one %s" % [_fmt(), _player.tree.picks, _player.tree.world_one])
	_release()

	# S4 and R6. The real pick path gives Rivet no s_face_runner.
	_setup(r6, true, true)
	_player.tree.open_checkpoint()
	var took: bool = _player.tree.pick("s_face_runner")
	_check("Rivet cannot take S4", not took and not build._face_runner_s4(), "pick accepted %s, S4 %s" % [took, build._face_runner_s4()])
	# Forced overlap: the highest active factor wins (1.25 over 1.0 over 0.75), either order.
	_player.tree.picks.append("s_face_runner")
	build.recompute()
	_check("forced S4+R6 fixture", build._face_runner_s4() and build._second_wind_r6(), "S4 %s, R6 %s" % [build._face_runner_s4(), build._second_wind_r6()])
	_vault()
	_sprint_start()
	await _ticks(STEP_TICKS + 1)
	_check("S4+R6 vault then sprint: 1.25", _player.kit.sprinting and _is(1.25), _fmt())
	_release()
	await _ticks(STEP_TICKS + 1)
	_check("S4+R6 sprint ended in window: 1.25", _is(1.25), _fmt())
	await _ticks(roundi(2.2 * Engine.physics_ticks_per_second))
	_check("S4+R6 window closed: 0.75", _is(0.75), _fmt())
	_setup(r6, true, true)
	_player.tree.picks.append("s_face_runner")
	build.recompute()
	_sprint_start()
	await _ticks(STEP_TICKS + 1)
	var sprint_only: bool = _player.kit.sprinting and _is(1.0)
	_vault()
	await _ticks(1)
	_check("S4+R6 sprint then vault: 1.25", sprint_only and _player.kit.sprinting and _is(1.25), "sprint alone x1.0 %s, %s" % [sprint_only, _fmt()])
	_release()

	print("hotwire_r6_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
