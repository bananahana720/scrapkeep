# smoke: solo timeout=90s
extends SceneTree
const Game = preload("res://src/game.gd")
const BotDriver = preload("res://tools/bot_driver.gd")
const Reactor = preload("res://src/combat/warden_reactor.gd")
const T = preload("res://tests/support/t.gd")
var t = T.new("park_reactor_return_test")
class Hands extends BotDriver:
	var steer_seen := Vector3.INF
	func _act(steer: Vector3, aim, delta: float, fight: Node3D = null, evade := true) -> void:
		steer_seen = steer
		super._act(steer, aim, delta, fight, evade)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = true
	var bot = Hands.new(game, "skipper", 1)
	bot.start()
	for i in 40: await physics_frame
	var w = game.flow.warden
	var sheet = w.mount_driver
	var dir: Vector3 = sheet._face_heading(w)
	var runup: float = minf(BotDriver.RUNUP, Reactor.SHEET_RUN - BotDriver.RUNUP_EDGE)
	var foot: Vector3 = w.home + dir * runup
	game.player.reset_to(game.ctx.terrain.drop_point(foot.x, foot.z, game.player.tuning.RADIUS), Vector3.ZERO)
	for i in 2: await physics_frame
	var tick := 1.0 / Engine.physics_ticks_per_second
	bot._fight(w, tick)
	var dry_steer: Vector3 = bot.steer_seen
	for i in ceili(w.PULSE_CYCLE * 2.0 / tick):
		if w.state_name() == "charging": break
		bot.tick(tick)
		await physics_frame
	t.check("return control reaches a natural charge", w.state_name() == "charging" and not sheet.sheet_live())
	bot._fight(w, tick)
	var charged: Vector3 = bot.steer_seen
	t.near("charging keeps the same return foot", Vector2(charged.x - w.home.x, charged.z - w.home.z).length(), runup)
	t.near("charging never moves the return target outward", Vector2(charged.x - dry_steer.x, charged.z - dry_steer.z).length(), 0.0)
	t.check("charging return target stays within the pulse ring", Vector2(charged.x - w.home.x, charged.z - w.home.z).length() <= w.pulse_radius)
	t.check("charging still reserves boost for the live sheet", not bot.source.press.get("shift_pressed", false) and not bot.source.hold.get("shift_held", false))
	game.free()
	quit(t.verdict())
