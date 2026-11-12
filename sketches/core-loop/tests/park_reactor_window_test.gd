# smoke: solo timeout=90s
extends SceneTree
const Game = preload("res://src/game.gd")
const Intent = preload("res://src/movement/intent.gd")
const Reactor = preload("res://src/combat/warden_reactor.gd")
const Warden = preload("res://src/combat/warden.gd")
const BotDriver = preload("res://tools/bot_driver.gd")
const SimClock = preload("res://src/core/sim_clock.gd")
const T = preload("res://tests/support/t.gd")
var t = T.new("park_reactor_window_test")
func _initialize() -> void:
	SimClock.ticks = true
	_run.call_deferred()
func _run() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.player.source = Intent.Scripted.new()
	for i in 40: await physics_frame
	var ring: Vector3 = game.ctx.terrain.beacon_point(game.run.stage)
	game.player.reset_to(game.ctx.terrain.drop_point(ring.x, ring.z, game.player.tuning.RADIUS), Vector3.ZERO)
	for i in 2: await physics_frame
	t.check("window control engages through the beacon ring", game.flow.engaged())
	var w = game.flow.warden
	var sheet = w.mount_driver
	var waiting: Vector3 = w.home + Vector3.RIGHT * Reactor.SHEET_WIDTH
	game.player.reset_to(game.ctx.terrain.drop_point(waiting.x, waiting.z, game.player.tuning.RADIUS), Vector3.ZERO)
	var tick := 1.0 / Engine.physics_ticks_per_second
	for i in ceili(Warden.PULSE_CYCLE * 2.0 / tick):
		if sheet.sheet_live(): break
		await physics_frame
	t.near("dam pulse opens the documented three-second road", sheet.sheet_left, 3.0, 2.0 * tick)
	var started: float = game.run.stage_time
	var bot = BotDriver.new(game, "skipper", 1)
	var foot: Vector3 = w.home + sheet.sheet_dir * (Reactor.SHEET_RUN + BotDriver.RUNUP_EDGE)
	game.player.reset_to(game.ctx.terrain.drop_point(foot.x, foot.z, game.player.tuning.RADIUS), sheet.sheet_dir * game.player.tuning.f("cruise"))
	for i in 2: await physics_frame
	t.check("outbound launch control is grounded by physics", game.player.state.grounded)
	t.check("outbound control moves away from the core", game.player.planar_velocity().dot(sheet.sheet_dir) > Reactor.RIDE_MIN_SPEED)
	bot._boost_clock = 0.0
	bot._fight(w, tick)
	t.check("dam hand never boosts an outbound approach", not bot.source.press.get("shift_pressed", false) and not bot.source.hold.get("shift_held", false))
	t.near("suppressed outbound launch keeps boost clock", bot._boost_clock, 0.0)
	t.near("suppressed outbound launch keeps hold clock", bot._shift_left, 0.0)
	for direction in [0.0, -1.0]:
		bot.source.press.clear()
		bot.source.hold.clear()
		game.player.reset_to(game.ctx.terrain.drop_point(foot.x, foot.z, game.player.tuning.RADIUS), sheet.sheet_dir * game.player.tuning.f("cruise") * direction)
		for i in 2: await physics_frame
		var label := "stationary" if direction == 0.0 else "inbound"
		t.check(label + " launch control is grounded with sheet live", game.player.state.grounded and sheet.sheet_live())
		t.check(label + " approach is not outbound", game.player.planar_velocity().dot(sheet.sheet_dir) <= 0.0)
		bot._boost_clock = 0.0
		bot._shift_left = 0.0
		bot._fight(w, tick)
		t.check(label + " sheet approach launches", bot.source.press.get("shift_pressed", false) and bot.source.hold.get("shift_held", false))
		t.near(label + " launch starts boost cooldown", bot._boost_clock, BotDriver.BOOST_GAP)
		t.near(label + " launch starts hold clock", bot._shift_left, BotDriver.SHIFT_HOLD)
	bot.source.press.clear()
	bot.source.hold.clear()
	game.player.reset_to(game.ctx.terrain.drop_point(waiting.x, waiting.z, game.player.tuning.RADIUS), Vector3.ZERO)
	while game.run.stage_time - started < 3.0 - 4.0 * tick:
		await physics_frame
	t.check("dam road remains live through its three-second window", sheet.sheet_live())
	while game.run.stage_time - started < 3.0 + 2.0 * tick:
		await physics_frame
	t.check("three-second road closes before the next charge", not sheet.sheet_live() and w.state_name() != "charging")
	for i in ceili(Warden.PULSE_TELEGRAPH / tick):
		if w.state_name() == "charging": break
		await physics_frame
	t.check("the following charge closes the road", w.state_name() == "charging" and not sheet.sheet_live())
	for i in ceili(Warden.PULSE_CYCLE / tick):
		if sheet.sheet_live(): break
		await physics_frame
	t.near("next pulse reopens a three-second road", sheet.sheet_left, 3.0, 2.0 * tick)
	var cycle: int = sheet.gates_opened
	var steady_start: float = game.run.stage_time
	for i in ceili(Warden.PULSE_CYCLE * 2.0 / tick):
		if sheet.gates_opened > cycle: break
		await physics_frame
	# The stage's own cycle: world 1's Wardens pulse on 5.1 s since wave 37 (ChallengeDials.PULSE_CYCLE_W1, ruling cu).
	t.near("stationary pulse lifecycle keeps the stage's rhythm", game.run.stage_time - steady_start, Warden.pulse_cycle(game.run.stage), 2.0 * tick)
	game.free()
	quit(t.verdict())
