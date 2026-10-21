# smoke: solo timeout=90s
extends SceneTree

const Game = preload("res://src/game.gd")
const BotDriver = preload("res://tools/bot_driver.gd")
const T = preload("res://tests/support/t.gd")
const SkillBand = preload("res://tools/skill_band.gd")
var t = T.new("park_reactor_prelaunch_test")

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
	var w = game.flow.warden
	var sheet = w.mount_driver
	sheet.sheet_dir = Vector3.FORWARD
	w._charging = true
	w._charge_time = 0.0
	sheet.sheet_left = 0.0
	bot._fight(w, 1.0 / Engine.physics_ticks_per_second)
	t.check("charging return foot stays inside the pulse ring", bot._flat(bot.steer_seen, w.home) < w.pulse_radius, str(bot.steer_seen))
	w._charge_time = w._charge_len - BotDriver.DROP_WAIT / 2.0
	bot._fight(w, 1.0 / Engine.physics_ticks_per_second)
	t.check("inbound starts before the sheet opens", not sheet.sheet_live() and bot.steer_seen.is_equal_approx(w.family_point_at()), str(bot.steer_seen))
	# Below the full kit the hand plays by sight: no launch off the Warden's clock before the sheet opens.
	bot.band = SkillBand.make("novice", 1, 1)
	bot._fight(w, 1.0 / Engine.physics_ticks_per_second)
	t.check("novice still runs the dam sheet hand", bot._goal.contains("spillway sheet"), bot._goal)
	t.check("novice does not launch before the sheet opens", not sheet.sheet_live() and not bot.steer_seen.is_equal_approx(w.family_point_at()), str(bot.steer_seen))
	bot.band = null
	w._charging = false
	for family in ["swarm", "mind"]:
		w.family = family
		bot._fight(w, 1.0 / Engine.physics_ticks_per_second)
		t.check(family + " never selects the dam sheet hand", not bot._goal.contains("spillway sheet"), bot._goal)
	game.free()
	quit(t.verdict())
