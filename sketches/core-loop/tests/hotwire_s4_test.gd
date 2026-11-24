extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# S4 Face Runner inversion (--scrap=armor --hotwire-shell=on --world-one-builds=on, BUILD-SYSTEMS.md
# S4 row): Riveted Shell's air-control factor is x0.75, and x1.25 for 2 s of sim after a valid vault
# while Sable's world-one Face Runner is taken. The window is per vault (a second vault restarts it),
# counts sim time (physics ticks, so a paused tree does not spend it), and survives a build recompute.
# The vault is the game's own vault_kicked event, the one augments.gd posts for a valid vault.
# Evidence limit: a fixture on the real Game with the event posted directly; the vault detection
# itself is combat_vault_test's and world_one_stree_test's. How it feels is unjudged.

const CLASS_ID := "pylon_engineer"

var _failures := 0
var _game
var _player


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


# Advance this many seconds of sim: whole physics ticks, so the same count Build's clock sees.
func _sim(seconds: float) -> void:
	var ticks := roundi(seconds * Engine.physics_ticks_per_second)
	for i in ticks:
		await physics_frame


func _air() -> float:
	return _game.tuning.f("air_control")


func _ratio() -> float:
	return _air() / _game.tuning.base("air_control")


# A fresh Sable tree with these picks, the world-one profile on or off, the shell on or off.
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
	_game.run.parts.clear()
	_game.build.recompute()


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
	var def: Resource = ClassDef.by_id(CLASS_ID)
	_game.run.class_def = def
	_player.fit_class(def)
	_game.tuning.set_option("scrap_mode", "armor")
	await _sim(0.5)
	var build = _game.build
	var s4 := ["s_static_flutter", "s_face_runner"]

	# S4 taken, shell fitted: x0.75, then x1.25 for 2 s after a vault, then x0.75.
	_setup(s4, true, true)
	_check("S4 fits", _game.tuning.option("hotwire_shell") == "on" and build._face_runner_s4() and _game.flow.in_play(),
		"shell on, S4 taken %s, in play %s" % [build._face_runner_s4(), _game.flow.in_play()])
	_check("before the vault x0.75", is_equal_approx(_ratio(), 0.75) and is_equal_approx(build.shell_air_factor(), 0.75),
		"air ratio %.3f, factor %.2f" % [_ratio(), build.shell_air_factor()])
	await _sim(0.5)
	_vault()
	_check("vault flips to x1.25", is_equal_approx(_ratio(), 1.25) and is_equal_approx(build.shell_air_factor(), 1.25),
		"air ratio %.3f, factor %.2f" % [_ratio(), build.shell_air_factor()])
	await _sim(1.8)
	_check("still x1.25 at 1.8 s", is_equal_approx(_ratio(), 1.25), "air ratio %.3f" % _ratio())
	await _sim(0.4)
	_check("back to x0.75 after 2 s", is_equal_approx(_ratio(), 0.75) and is_equal_approx(build.shell_air_factor(), 0.75),
		"air ratio %.3f at 2.2 s, factor %.2f" % [_ratio(), build.shell_air_factor()])

	# A second vault inside the window restarts it.
	_vault()
	await _sim(1.5)
	_vault()
	await _sim(1.5)
	_check("second vault restarts the window", is_equal_approx(_ratio(), 1.25), "3.0 s after the first, 1.5 s after the second: ratio %.3f" % _ratio())
	await _sim(0.7)
	_check("restarted window closes 2 s after the second", is_equal_approx(_ratio(), 0.75), "ratio %.3f at 2.2 s after the second" % _ratio())

	# A recompute inside the window keeps the flip, stacks with a part's own mod, and the close
	# still lands on the part-scaled x0.75.
	_game.run.parts.append("slipstream")
	build.recompute()
	var part_mod: float = build.sheet.mod("air_control")
	_vault()
	await _sim(0.5)
	build.recompute()
	_check("recompute inside the window", is_equal_approx(_ratio(), part_mod * 1.25) and part_mod > 1.0,
		"ratio %.4f, part x%.2f, expected %.4f" % [_ratio(), part_mod, part_mod * 1.25])
	await _sim(1.7)
	_check("close with a part fitted", is_equal_approx(_ratio(), part_mod * 0.75), "ratio %.4f, expected %.4f" % [_ratio(), part_mod * 0.75])

	# Without S4 (another node taken) the factor stays x0.75 through a vault.
	_setup(["s_static_flutter"], true, true)
	_vault()
	_check("no S4: unchanged through a vault", is_equal_approx(_ratio(), 0.75) and is_equal_approx(build.shell_air_factor(), 0.75),
		"ratio %.3f, factor %.2f" % [_ratio(), build.shell_air_factor()])
	await _sim(0.5)
	_check("no S4 stays x0.75", is_equal_approx(_ratio(), 0.75), "ratio %.3f" % _ratio())

	# The base Face Runner (no world-one profile) is not S4.
	# Base tree heap index 9 is s_face_runner: Cannonball (0), Live Wire (3), Face Runner (9).
	_setup(["s_cannonball", "s_live_wire", "s_face_runner"], false, true)
	var tree = _player.tree
	_check("base Face Runner taken", tree.picks.has("s_face_runner") and not tree.world_one, "picks %s, world_one %s" % [tree.picks, tree.world_one])
	_vault()
	_check("base Face Runner: no inversion", is_equal_approx(_ratio(), 0.75) and not build._face_runner_s4(), "ratio %.3f, s4 %s" % [_ratio(), build._face_runner_s4()])

	# Without the shell there is no change at all.
	_setup(s4, true, false)
	_vault()
	_check("no shell: no change", is_equal_approx(_ratio(), 1.0) and is_equal_approx(build.shell_air_factor(), 1.0),
		"ratio %.3f, factor %.2f" % [_ratio(), build.shell_air_factor()])
	await _sim(2.5)
	_check("no shell after the window", is_equal_approx(_ratio(), 1.0), "ratio %.3f" % _ratio())

	print("hotwire_s4_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
