extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# Scrapless armour run (--scrap=armor --start-mass=200 plus the class screen's scrapless modifier):
# scrap.step is gated off, so a recovery cluster could never be collected, aged or expired. A hit
# must destroy and log its spill instead of dropping clusters, and the run's metrics must match.
# Evidence limit: a fixture on the real Game with a direct run.damage; how it feels is unjudged.

var _failures := 0
var _game


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
	_game.player.source = Intent.Scripted.new()
	_game.tuning.apply_args(PackedStringArray(["--scrap=armor", "--start-mass=200"]))
	_game.flow.press_start()
	_game.build.set_modifiers({"scrapless": true})
	_game.flow.choose_class(0)
	await _sim(0.5)
	var run = _game.run
	var build = _game.build
	_check("scrapless armour stage", build.scrapless() and run.armor_mode and _game.flow.in_stage() and run.mass > 0.0,
		"scrapless %s, armour %s, in stage %s, mass %.0f" % [build.scrapless(), run.armor_mode, _game.flow.in_stage(), run.mass])
	var destroyed_before: float = run.metrics["destroyed"]
	var mass_before: float = run.mass
	run.damage(10.0, "test_hit")
	var lost: float = mass_before - run.mass
	await _sim(25.0)
	_check("no uncollectable spill", lost > 0.0 and build.scrap.recovery_count() == 0
			and is_equal_approx(run.metrics["destroyed"] - destroyed_before, lost),
		"hit took %.0f scrap: %d clusters live after 25 s, destroyed +%.0f" % [lost, build.scrap.recovery_count(), run.metrics["destroyed"] - destroyed_before])
	_check("no phantom reversing time", is_equal_approx(run.metrics["reverse_seconds"], 0.0), "reverse_seconds %.2f" % run.metrics["reverse_seconds"])

	print("armor_scrapless_spill_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
