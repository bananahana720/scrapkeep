# smoke: solo timeout=180s
extends SceneTree

const Game = preload("res://src/game.gd")
const BotDriver = preload("res://tools/bot_driver.gd")
const Run = preload("res://src/core/run_state.gd")
const Reactor = preload("res://src/combat/warden_reactor.gd")
const Arena = preload("res://tests/posture_bands_reactor_test.gd")
const SimClock = preload("res://src/core/sim_clock.gd")
const T = preload("res://tests/support/t.gd")
var t = T.new("park_reactor_repeat_test")

class Hands extends BotDriver:
	func _specials(_fight, _evading: bool) -> void: pass
	func _act(steer: Vector3, aim, delta: float, fight: Node3D = null, evade := true) -> void:
		super._act(steer, aim, delta, fight, evade)
		source.hold.erase("fire_held")

func _initialize() -> void:
	SimClock.ticks = true
	_run.call_deferred()

func _run() -> void:
	var grown: Dictionary = await _fight(Run.HEFT_CLASS_AT[2], "grown")
	var small: Dictionary = await _fight(Run.HEFT_CLASS_AT[0], "small")
	t.check("small repeated sheet fight takes at least twice grown", grown.broken and small.broken and small.seconds >= 2.0 * grown.seconds, "grown %s, small %s" % [grown, small])
	quit(t.verdict())

func _fight(heft: float, label: String) -> Dictionary:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = true
	var bot = Hands.new(game, "skipper", 1)
	bot.start()
	game.run.grant_start_mass((heft - Run.HEFT_CLASS_AT[0]) / Run.HEFT_PER_MASS)
	for i in 40: await physics_frame
	var w = game.flow.warden
	var sheet = w.mount_driver
	var dir: Vector3 = sheet._face_heading(w)
	var foot: Vector3 = w.home + dir * minf(BotDriver.RUNUP, Reactor.SHEET_RUN - BotDriver.RUNUP_EDGE)
	game.player.reset_to(game.ctx.terrain.drop_point(foot.x, foot.z, game.player.tuning.RADIUS), Vector3.ZERO)
	var result := {"broken": false, "seconds": 0.0, "contacts": 0, "cycles": 0}
	game.events.enemy_struck.connect(func(enemy, kind, _force):
		if enemy == w and kind in ["ram", "stomp", "slam"]: result.contacts += 1)
	game.events.beacon_unsealed.connect(func(_stage): result.broken = true)
	var started: float = game.run.stage_time
	for i in ceili(1.5 * Arena.EXPECT_GROWN_S * Engine.physics_ticks_per_second):
		if result.broken: break
		bot.tick(1.0 / Engine.physics_ticks_per_second)
		await physics_frame
	result.seconds = game.run.stage_time - started
	result.cycles = sheet.gates_opened
	t.check(label + " repeats the sheet approach without resetting the ball", result.broken and result.seconds <= 1.5 * Arena.EXPECT_GROWN_S, str(result))
	game.free()
	await physics_frame
	return result
