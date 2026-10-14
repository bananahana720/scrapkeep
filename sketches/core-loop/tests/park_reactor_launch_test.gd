# smoke: solo timeout=90s
extends SceneTree
const Game = preload("res://src/game.gd")
const Intent = preload("res://src/movement/intent.gd")
const Reactor = preload("res://src/combat/warden_reactor.gd")
const Warden = preload("res://src/combat/warden.gd")
const BotDriver = preload("res://tools/bot_driver.gd")
const SimClock = preload("res://src/core/sim_clock.gd")
const T = preload("res://tests/support/t.gd")
var t = T.new("park_reactor_launch_test")
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
	t.check("launch controls follow a normal charge and pulse", sheet.sheet_live() and w.pulses > 0)
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
	game.free()
	quit(t.verdict())
