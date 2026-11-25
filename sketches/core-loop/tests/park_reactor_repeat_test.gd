# smoke: solo timeout=300s (one fixed-90-fps child plays both fights, about 100 s)
extends SceneTree

const Game = preload("res://src/game.gd")
const BotDriver = preload("res://tools/bot_driver.gd")
const Run = preload("res://src/core/run_state.gd")
const Reactor = preload("res://src/combat/warden_reactor.gd")
const Arena = preload("res://tests/posture_bands_reactor_test.gd")
const SimClock = preload("res://src/core/sim_clock.gd")
const T = preload("res://tests/support/t.gd")
var t = T.new("park_reactor_repeat_test")

# The run replays itself once in a child at a fixed 90 fps, one physics tick per frame, as
# park_reactor_fight_test does. Paced by the clock, the tick the bot reached the sheet moved with
# the machine's load, and a fight is a whole number of pulse cycles (about 6 s each): grown ended
# on 3 or 4 and small on 7, 8 or 9, while the old checks held only for grown 3 and small exactly 7
# (1 fail in 3 side by side on stage 2887a970, 4 in 6 on a branch that moved the tick; 1 red in
# the wave 33 gate after a three-tick wait was tried). Fixed, the same build gives the same
# numbers every time: grown 19.646 s on 3 cycles and small 55.714 s on 9, on 4 of 4 runs side by
# side on four cores (stage 2b35a11f, 10 Nov 2026), and the same on 8 runs of earlier heads.
# Each fight's allowance is 1.5 times its own pin in posture_bands_reactor_test. The small fight
# used to share the grown one's allowance (47.7 s), which a small ball can only meet on 7 cycles.
# The allowance only stops a fight that never ends; the fight's length is held by the "twice
# grown" check here and by the pins there, so the cycle counts are printed and not pinned (a
# tuning change that moves a fight by one cycle is not this test's to fail). seed(1) and
# run_seed_override = 1 pin single-seed determinism; MOUNTED_POSTURE needs 3 sheet rams for
# grown (heft 2.2) and ceil(3 * 2.2) = 7 for small (heft 1.0), and W46-S1's DAM_VENT adds one
# evade cycle to grown (4 cycles vs 7-8 for small, ~1.70x-1.94x). posture_bands_reactor_test
# holds the 9-seed >= 2.0x median band (3.19x Linux / 2.79x Mac).
const CHILD_ENV := "SCRAPKEEP_REACTOR_REPEAT_CHILD"

class Hands extends BotDriver:
	func _specials(_fight, _evading: bool) -> void: pass
	func _act(steer: Vector3, aim, delta: float, fight: Node3D = null, evade := true) -> void:
		super._act(steer, aim, delta, fight, evade)
		source.hold.erase("fire_held")

func _initialize() -> void:
	if OS.get_environment(CHILD_ENV) != "1":
		OS.set_environment(CHILD_ENV, "1")
		var output := []
		var args := PackedStringArray(["--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/park_reactor_repeat_test.gd", "--"])
		args.append_array(OS.get_cmdline_user_args())
		var code := OS.execute(OS.get_executable_path(), args, output, true)
		for chunk in output:
			print(String(chunk).strip_edges())
		quit(code)
		return
	SimClock.ticks = true
	_run.call_deferred()

func _run() -> void:
	var grown: Dictionary = await _fight(Run.HEFT_CLASS_AT[2], "grown", 1.5 * Arena.EXPECT_GROWN_S)
	var small: Dictionary = await _fight(Run.HEFT_CLASS_AT[0], "small", 1.5 * Arena.EXPECT_SMALL_S)
	t.check(
		"small repeated sheet fight takes more cycles and at least 1.5x grown",
		grown.broken and small.broken and small.cycles > grown.cycles and small.seconds >= 1.5 * grown.seconds,
		"grown %s, small %s" % [grown, small]
	)
	quit(t.verdict())

func _fight(heft: float, label: String, allowance_s: float) -> Dictionary:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = true
	seed(1)
	game.run.run_seed_override = 1
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
	for i in ceili(allowance_s * Engine.physics_ticks_per_second):
		if result.broken: break
		# Keep the unarmed Hands sheet-repeat geometry probe alive under W46-S1's 4.0x Dam Warden pulse.
		game.run.hp = game.run.max_hp
		bot.tick(1.0 / Engine.physics_ticks_per_second)
		await physics_frame
	result.seconds = game.run.stage_time - started
	result.cycles = sheet.gates_opened
	t.check(label + " repeats the sheet approach without resetting the ball", result.broken and result.seconds <= allowance_s, "%s, allowance %.1f s" % [result, allowance_s])
	game.free()
	await physics_frame
	return result
