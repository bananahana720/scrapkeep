extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Build := preload("res://src/build/build.gd")
const RunState := preload("res://src/core/run_state.gd")
const Parts := preload("res://src/build/parts.gd")

# Fitting the hot-wired Riveted Shell is a real choice (world 1 design pass, 9 Nov). Until now
# the shell's two numbers came from the --hotwire-shell flag, which ships on, so every run rolled
# with them whether it held the part or not: Fit changed nothing and Recycle's 20 cogs always won.
# Those two numbers are the baseline every band and pin was fit on, so they stay the baseline, and
# the held part pays what its card says on top of them.
# 1. Not held (the flag on, as shipped): 5 scrap per absorbed HP and air steering x0.75, exactly
#    as before, through the real Warden break, the offer and Recycle (which pays its cogs once).
# 2. Fit, then the striped gate taken: the armour goes twice as far again (2.5 scrap per HP, a
#    12 HP hit on 200 mass costs 30) and air steering takes x0.75 again; nothing is handed over
#    on fitting, no other tuning value moves, and fitting plays no inversion cue.
# 3. The card's words are those two numbers.
# 4. An inversion still lifts the held shell to its own factor (S4: x1.25 for 2 s after a vault),
#    cues once each way, and drops back to the held shell's resting factor.
# 5. It follows the part: losing the part returns the baseline; the flag off is the bare game.
# Evidence limit: a fixture on the real Game; the Warden break is the beacon_unsealed fact and
# the gate pass is run.add_part. It does not judge how the heavier steering feels.
# smoke: timeout=180s

const CLASS_ID := "pylon_engineer"
const SHELL := "riveted_shell"

var _t := preload("res://tests/support/t.gd").new("hotwire_shell_held_test")
var _game
var _player
var _cues: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in int(round(seconds * Engine.physics_ticks_per_second)):
		await physics_frame


func _ratio() -> float:
	return _game.tuning.f("air_control") / _game.tuning.base("air_control")


func _others() -> Dictionary:
	var out := {}
	for spec in _game.tuning.SPECS:
		if spec["key"] != "air_control":
			out[spec["key"]] = _game.tuning.f(spec["key"])
	return out


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
	var run = _game.run
	run.mitigation = 0.0
	build.shell_air_changed.connect(func(factor: float, rose: bool): _cues.append([snappedf(factor, 0.0001), rose]))
	build.recompute()

	# 1. Not held: the shipped baseline.
	_t.check("not held: the baseline every band was fit on", build.shell_fitted() and not build.shell_held()
		and run.scrap_per_hp == Build.SHELL_SCRAP_PER_HP and is_equal_approx(_ratio(), Build.SHELL_AIR_FACTOR),
		"cost %.1f, air x%.4f" % [run.scrap_per_hp, _ratio()])
	# 2. The Warden break puts the shell up as a rare gate part: no screen, no cogs, and nothing
	# changes until the gate is taken.
	var cogs_before: int = run.cogs
	_game.events.beacon_unsealed.emit(1)
	_t.check("the break puts the shell at the gates and changes nothing yet", build.hotwire_pending()["part_id"] == SHELL
		and build.hotwire_pending()["state"] == "fit" and run.cogs == cogs_before
		and not SHELL in run.parts and not build.shell_held() and run.scrap_per_hp == Build.SHELL_SCRAP_PER_HP
		and is_equal_approx(_ratio(), Build.SHELL_AIR_FACTOR),
		"pending %s, cogs %d to %d, parts %s, cost %.1f, air x%.4f" % [build.hotwire_pending(), cogs_before, run.cogs, run.parts,
			run.scrap_per_hp, _ratio()])
	run.grant_start_mass(200.0 - run.mass)
	var before := {"mass": run.mass, "hp": run.hp, "max_hp": run.max_hp, "others": _others()}
	_cues.clear()
	run.add_part(SHELL, "gate")
	var moved: Array = []
	var after := _others()
	for key in after:
		if not is_equal_approx(after[key], before["others"][key]):
			moved.append(key)
	_t.check("held: the armour goes twice as far again", build.shell_held()
		and is_equal_approx(run.scrap_per_hp, Build.SHELL_SCRAP_PER_HP / Build.RIVETED_ARMOUR) and is_equal_approx(run.scrap_per_hp, 2.5),
		"scrap per HP %.2f" % run.scrap_per_hp)
	_t.check("held: air steering takes x0.75 again", is_equal_approx(_ratio(), Build.SHELL_AIR_FACTOR * Build.RIVETED_AIR_FACTOR)
		and is_equal_approx(build.shell_air_factor(), 0.5625), "air x%.4f, factor %.4f" % [_ratio(), build.shell_air_factor()])
	_t.check("fitting hands nothing over, moves nothing else and plays no inversion cue", run.mass == before["mass"] and run.hp == before["hp"]
		and run.max_hp == before["max_hp"] and moved.is_empty() and _cues.is_empty(),
		"mass %.0f, hp %.0f, max hp %.0f, moved %s, cues %s" % [run.mass, run.hp, run.max_hp, moved, _cues])
	var hp_before: float = run.hp
	run.damage(12.0, "t")
	_t.check("a 12 HP hit on 200 mass costs 30, none of it hull", is_equal_approx(run.mass, 170.0) and is_equal_approx(run.hp, hp_before),
		"mass %.0f, hp %.0f" % [run.mass, run.hp])
	build.recompute()
	build.recompute()
	_t.check("it survives a recompute", is_equal_approx(run.scrap_per_hp, 2.5) and is_equal_approx(_ratio(), 0.5625),
		"cost %.2f, air x%.4f" % [run.scrap_per_hp, _ratio()])
	_t.check("a held shell is never offered again", Parts.hotwire_offer(true, run.parts, 1).is_empty(), "offer %s" % [Parts.hotwire_offer(true, run.parts, 1)])

	# 3. The card says those two numbers.
	var line := String(Parts.def(SHELL).verb)
	_t.check("the card's words are the fitted numbers", "Double" in line and "25%" in line, "gate card line '%s'" % line)

	# 4. An inversion lifts the held shell and drops back to its resting factor.
	_game.tuning.set_option("world_one_builds", "on")
	var tree = _player.tree
	tree.reset(CLASS_ID)
	tree.max_depth = 2
	tree.world_one = true
	for id in ["s_static_flutter", "s_face_runner"]:
		tree.open_checkpoint()
		tree.pick(id)
	build.recompute()
	_cues.clear()
	var s4: bool = build._face_runner_s4()
	_game.events.vault_kicked.emit(_player.ball_position(), 20.0)
	var lifted: float = _ratio()
	await _sim(2.3)
	_t.check("S4 lifts the held shell to x1.25 for 2 s, then back to x0.5625, one cue each way", s4 and is_equal_approx(lifted, Build.SHELL_AIR_FACTOR_VAULT)
		and is_equal_approx(_ratio(), 0.5625) and _cues == [[1.25, true], [0.5625, false]],
		"S4 %s, in the window x%.4f, after x%.4f, cues %s" % [s4, lifted, _ratio(), _cues])

	# 5. It follows the part and the flag.
	_game.tuning.set_option("hotwire_shell", "off")
	build.recompute()
	_t.check("the flag off is the bare game, part or no part", not build.shell_held() and run.scrap_per_hp == RunState.SCRAP_PER_HP
		and is_equal_approx(_ratio(), 1.0), "cost %.1f, air x%.4f" % [run.scrap_per_hp, _ratio()])
	_game.tuning.set_option("hotwire_shell", "on")
	run.remove_part(SHELL)
	build.recompute()
	_t.check("losing the part returns the baseline", not build.shell_held() and run.scrap_per_hp == Build.SHELL_SCRAP_PER_HP
		and is_equal_approx(_ratio(), Build.SHELL_AIR_FACTOR), "cost %.1f, air x%.4f" % [run.scrap_per_hp, _ratio()])
	_game.free()
	quit(_t.verdict())
