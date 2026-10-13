# smoke: solo timeout=90s
extends SceneTree
const Game = preload("res://src/game.gd")
const Intent = preload("res://src/movement/intent.gd")
const BotDriver = preload("res://tools/bot_driver.gd")
const Reactor = preload("res://src/combat/warden_reactor.gd")
const Warden = preload("res://src/combat/warden.gd")
const SimClock = preload("res://src/core/sim_clock.gd")
const T = preload("res://tests/support/t.gd")
var t = T.new("park_reactor_staging_test")
class Hands extends BotDriver:
	var steer_at := Vector3.ZERO
	func _act(steer: Vector3, aim, delta: float, fight: Node3D = null, evade := true) -> void:
		steer_at = steer
		super._act(steer, aim, delta, fight, evade)
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
	var w = game.flow.warden
	var sheet = w.mount_driver
	var ring: Vector3 = game.ctx.terrain.beacon_point(game.run.stage)
	game.player.reset_to(game.ctx.terrain.drop_point(ring.x, ring.z, game.player.tuning.RADIUS), Vector3.ZERO)
	for i in 2: await physics_frame
	var bot = Hands.new(game, "skipper", 1)
	var dir: Vector3 = sheet._face_heading(w)
	var expected: Vector3 = w.home + dir * (Reactor.SHEET_RUN + BotDriver.RUNUP_EDGE)
	var dry_ok := true
	var charge_ok := true
	var saw_dry := false
	var saw_charge := false
	var tick := 1.0 / Engine.physics_ticks_per_second
	for i in ceili(Warden.PULSE_CYCLE * 2.0 / tick):
		if sheet.sheet_live(): break
		bot._fight(w, tick)
		var distance := Vector2(bot.steer_at.x - expected.x, bot.steer_at.z - expected.z).length()
		if w.state_name() == "charging":
			saw_charge = true
			charge_ok = charge_ok and distance < 0.0001
		else:
			saw_dry = true
			dry_ok = dry_ok and distance < 0.0001
		await physics_frame
	t.check("ordinary dry approach stages outside the sheet foot", saw_dry and dry_ok)
	t.check("charge keeps the same staging point", saw_charge and charge_ok)
	t.check("the staging probe follows a normal pulse", sheet.sheet_live() and w.pulses > 0)
	game.free()
	quit(t.verdict())
