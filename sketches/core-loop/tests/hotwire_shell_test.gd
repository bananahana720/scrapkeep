extends SceneTree

const Game := preload("res://src/game.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const RunState := preload("res://src/core/run_state.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const BallRules := preload("res://src/movement/ball_rules.gd")
const Intent := preload("res://src/movement/intent.gd")

# Hot-wired H1, Riveted Shell (--hotwire-shell=on, BUILD-SYSTEMS.md). Armour mode: the scrap layer
# costs 5 scrap per absorbed HP instead of 10 inside the one damage order, and 75% of the mass
# actually removed spills. Always: airborne drive acceleration x0.75 as a build-owned tuning mod
# that survives a recompute; ground steering and every other tuning value stay as they are.
# Evidence limit: a fixture on the real Game with a scripted intent and a fake ball state for the
# drive maths; it does not judge how the air penalty feels.

class FakeState:
	var grounded := false
	var velocity := Vector3.ZERO
	var contact_normal := Vector3.UP
	var cruise_boost := 1.0

class FakeIntent:
	var brake_held := false

var _failures := 0
var _game
var _ticks := 0
var _phase := "boot"
var _nodes: Array[Node] = []


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _run(armor: bool, shell_cost: float) -> RunState:
	var events := GameEvents.new()
	_nodes.append(events)
	var run := RunState.new(events)
	run.begin(load("res://src/core/class_def.gd").by_id("pylon_engineer"))
	run.armor_mode = armor
	run.scrap_per_hp = shell_cost
	run.grant_start_mass(200.0)
	return run


func _initialize() -> void:
	# The order in isolation: 12 HP post-mitigation on 200 mass.
	var base := _run(true, RunState.SCRAP_PER_HP)
	base.damage(12.0, "t")
	_check("base cost", is_equal_approx(base.mass, 80.0) and is_equal_approx(base.hp, 100.0),
		"12 on 200 at 10/HP: mass %.0f, hp %.0f" % [base.mass, base.hp])
	var shell := _run(true, 5.0)
	var spills := []
	shell.armor_hit.connect(func(removed: float, spill: int, _s: String): spills.append([removed, spill]))
	shell.damage(12.0, "t")
	_check("shell cost", is_equal_approx(shell.mass, 140.0) and is_equal_approx(shell.hp, 100.0) and is_equal_approx(shell.metrics["hull_damage"], 0.0),
		"12 on 200 at 5/HP: mass %.0f (60 removed), hp %.0f, hull damage %.0f" % [shell.mass, shell.hp, shell.metrics["hull_damage"]])
	_check("shell spill", spills == [[60.0, 45]] and is_equal_approx(shell.metrics["destroyed"], 15.0),
		"spill %s: 75%% of the 60 removed, not of 120; destroyed %.0f" % [spills, shell.metrics["destroyed"]])
	# Overflow past the scrap layer: 30 mass at 5/HP absorbs 6 HP, the other 4 reach the hull.
	var thin := _run(true, 5.0)
	thin.mass = 30.0
	thin.damage(10.0, "t")
	_check("shell overflow", thin.mass == 0.0 and is_equal_approx(thin.hp, 96.0),
		"10 on 30 at 5/HP: mass %.0f, hp %.0f (6 absorbed, 4 to the hull)" % [thin.mass, thin.hp])
	# Air control maths through the real rules.
	var t := Tuning.new()
	var state := FakeState.new()
	var intent := FakeIntent.new()
	var wish := Vector3.FORWARD
	var air_base := BallRules.drive_accel(state, t, wish, intent).length()
	t.set_mod("air_control", 0.75)
	var air_shell := BallRules.drive_accel(state, t, wish, intent).length()
	state.grounded = true
	var ground_shell := BallRules.drive_accel(state, t, wish, intent).length()
	t.clear_mods()
	var ground_base := BallRules.drive_accel(state, t, wish, intent).length()
	_check("air x0.75 in the rules", is_equal_approx(air_shell, air_base * 0.75) and air_base > 0.0 and is_equal_approx(ground_shell, ground_base),
		"airborne %.3f vs %.3f base; ground %.3f vs %.3f" % [air_shell, air_base, ground_shell, ground_base])
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _collider_radius() -> float:
	for shape in _game.player.find_children("*", "CollisionShape3D", true, false):
		if shape.shape is SphereShape3D:
			return shape.shape.radius
	return -1.0


func _tuning_snapshot() -> Dictionary:
	var out := {}
	for spec in Tuning.SPECS:
		# air_control is the value under test; scrap_mode and hotwire_shell are the switches.
		if not spec["key"] in ["air_control", "scrap_mode", "hotwire_shell"]:
			out[spec["key"]] = _game.tuning.f(spec["key"])
	return out


func _game_checks() -> void:
	var run = _game.ctx.run
	var tuning = _game.tuning
	var build = _game.build
	run.mitigation = 0.0
	tuning.set_option("scrap_mode", "off")
	tuning.set_option("hotwire_shell", "off")
	build.recompute()
	var air_off: float = tuning.f("air_control")
	var others_off := _tuning_snapshot()
	var radius_off := _collider_radius()
	var cost_off: float = run.scrap_per_hp
	_check("flag off is base", is_equal_approx(air_off, tuning.base("air_control")) and cost_off == RunState.SCRAP_PER_HP
		and build.shell_air_factor() == 1.0 and not build.shell_fitted(),
		"air %.3f, cost %.0f, factor %.2f" % [air_off, cost_off, build.shell_air_factor()])
	tuning.set_value("scrap_mode", 1.0)
	build.recompute()
	run.grant_start_mass(200.0 - run.mass)
	var mass_before: float = run.mass
	var hp_before: float = run.hp
	var max_before: float = run.max_hp
	tuning.set_value("hotwire_shell", 1.0)
	build.recompute()
	_check("fitting gives nothing", run.mass == mass_before and run.hp == hp_before and run.max_hp == max_before,
		"mass %.0f -> %.0f, hp %.0f -> %.0f, max hp %.0f -> %.0f" % [mass_before, run.mass, hp_before, run.hp, max_before, run.max_hp])
	_check("air x0.75 resolved", is_equal_approx(tuning.f("air_control"), air_off * 0.75) and is_equal_approx(build.shell_air_factor(), 0.75),
		"air_control %.4f from %.4f" % [tuning.f("air_control"), air_off])
	var others_on := _tuning_snapshot()
	var moved := []
	for key in others_off:
		if not is_equal_approx(others_on[key], others_off[key]):
			moved.append(key)
	_check("nothing else moves", moved.is_empty() and is_equal_approx(_collider_radius(), radius_off) and radius_off > 0.0,
		"%d other tuning values equal (moved %s), collider radius %.3f" % [others_on.size(), moved, _collider_radius()])
	_check("cost halved", run.scrap_per_hp == 5.0, "scrap_per_hp %.1f" % run.scrap_per_hp)
	# Survives every recompute, including one after another part's air_control mod.
	build.recompute()
	build.recompute()
	var twice: float = tuning.f("air_control")
	run.parts.append("slipstream")
	build.recompute()
	var with_part: float = tuning.f("air_control")
	var part_mod: float = build.sheet.mod("air_control")
	run.parts.erase("slipstream")
	build.recompute()
	_check("survives recompute", is_equal_approx(twice, air_off * 0.75) and is_equal_approx(with_part, air_off * part_mod * 0.75) and part_mod > 1.0
		and is_equal_approx(tuning.f("air_control"), air_off * 0.75),
		"two recomputes %.4f; with a x%.2f part %.4f; part removed %.4f" % [twice, part_mod, with_part, tuning.f("air_control")])
	# Real damage through the game's run object.
	run.damage(12.0, "t")
	_check("game damage order", is_equal_approx(run.mass, 140.0) and is_equal_approx(run.hp, hp_before),
		"12 on 200: mass %.0f, hp %.0f" % [run.mass, run.hp])
	# Off again: back to base cost and air.
	tuning.set_value("hotwire_shell", 0.0)
	build.recompute()
	_check("flag off again", is_equal_approx(tuning.f("air_control"), air_off) and run.scrap_per_hp == RunState.SCRAP_PER_HP,
		"air %.4f, cost %.0f" % [tuning.f("air_control"), run.scrap_per_hp])
	# Armour off with the part fitted: the scrap layer never runs, so only the air penalty acts.
	tuning.set_value("scrap_mode", 0.0)
	tuning.set_value("hotwire_shell", 1.0)
	build.recompute()
	var hp_now: float = run.hp
	var mass_now: float = run.mass
	run.damage(12.0, "t")
	_check("armour off: no upside", is_equal_approx(run.hp, hp_now - 12.0) and run.mass == mass_now,
		"12 damage goes to the hull (hp %.0f), mass %.0f untouched" % [run.hp, run.mass])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_phase = "run"
			_ticks = 0
		"run":
			if _ticks < 30:
				return false
			_game_checks()
			print("hotwire_shell_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			_game.free()
			for node in _nodes:
				node.free()
			quit(0 if _failures == 0 else 1)
			return true
	return false
