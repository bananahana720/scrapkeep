# smoke: solo timeout=90s
extends SceneTree
const Game = preload("res://src/game.gd")
const BotDriver = preload("res://tools/bot_driver.gd")
const SimClock = preload("res://src/core/sim_clock.gd")
const T = preload("res://tests/support/t.gd")
var t = T.new("park_reactor_bot_hand_test")

# The skipper's spillway sheet hand on park stage 1 (unit BS1): it rolls to the dam as on any
# approach, holds fire near a full bar, and rides a live sheet through a stagger, since the sheet
# ram is the dam Warden's only break.
class Hands extends BotDriver:
	var steer_seen := Vector3.INF
	func _act(steer: Vector3, aim, delta: float, fight: Node3D = null, evade := true) -> void:
		steer_seen = steer
		super._act(steer, aim, delta, fight, evade)

func _initialize() -> void:
	SimClock.ticks = true
	_run.call_deferred()

func _place(game, bot, at: Vector3, velocity: Vector3) -> void:
	bot.source.press.clear()
	bot.source.hold.clear()
	bot._boost_clock = 0.0
	bot._shift_left = 0.0
	bot._cast_phase = ""
	game.player.reset_to(game.ctx.terrain.drop_point(at.x, at.z, game.player.tuning.RADIUS), velocity)
	for i in 2: await physics_frame

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
	var dt := 1.0 / Engine.physics_ticks_per_second
	var named: Dictionary = load("res://tools/bot_driver.gd").get_script_constant_map()
	t.check("the hand names its reach", named.has("SHEET_HAND_REACH"), "bot_driver.gd has no SHEET_HAND_REACH")
	var reach: float = float(named.get("SHEET_HAND_REACH", 60.0))
	var foot: Vector3 = w.home + sheet.sheet_dir * minf(BotDriver.RUNUP, sheet.SHEET_RUN - BotDriver.RUNUP_EDGE)
	for i in 40: await physics_frame
	# The roll in: far from the apron the hand is an ordinary roll.
	var far: Vector3 = foot + sheet.sheet_dir * (reach + 20.0)
	await _place(game, bot, far, -sheet.sheet_dir * game.player.tuning.f("cruise"))
	sheet.sheet_left = 0.0
	bot._fight(w, dt)
	t.check("far from the apron the skipper rolls to the dam as on any approach", bot._goal == "roll to spillway sheet", bot._goal)
	# Hold fire near a full bar; the same sheet approach fires below it (the control).
	for row in [[10.0, true], [95.0, false]]:
		w._posture.posture = row[0]
		w._posture.staggered = false
		sheet.sheet_left = 0.0
		await _place(game, bot, foot, Vector3.ZERO)
		w._posture.posture = row[0]
		bot._fight(w, dt)
		t.check("posture %.0f: the hand %s" % [row[0], "fires" if row[1] else "holds fire"],
			bot.source.hold.get("fire_held", false) == row[1] and (row[1] or not bot.source.press.get("fire_pressed", false)),
			"goal %s, hold %s, press %s" % [bot._goal, bot.source.hold, bot.source.press])
	# A stagger opened inside a live sheet: the hand rides the sheet into the core.
	await _place(game, bot, foot, -sheet.sheet_dir * game.player.tuning.f("cruise"))
	w._posture.posture = w._posture.FULL
	w._posture.staggered = true
	w._posture.stagger_left = w._posture.stagger_seconds
	sheet.on_pulse(w, false)
	bot._fight(w, dt)
	t.check("a stagger in a live sheet keeps the sheet hand", bot._goal == "ride spillway sheet", bot._goal)
	t.check("and drives at the core", bot.steer_seen.is_equal_approx(w.family_point_at()), str(bot.steer_seen))
	t.check("and holds fire", not bot.source.hold.get("fire_held", false), str(bot.source.hold))
	# Already rammed this cycle, a stagger still goes again: the second ram is the break.
	bot._fight_phase = "sheet return %d" % sheet.gates_opened
	bot._fight(w, dt)
	t.check("a rammed cycle in a stagger launches again", bot.steer_seen.is_equal_approx(w.family_point_at()), str(bot.steer_seen))
	# A stagger with the sheet dry waits at the foot for the next pulse.
	sheet.sheet_left = 0.0
	sheet._close_sheet()
	bot._fight(w, dt)
	t.check("a stagger with the sheet dry waits at the foot", bot._goal == "wait spillway sheet" \
		and bot.steer_seen.distance_to(game.ctx.terrain.drop_point(foot.x, foot.z, game.player.tuning.RADIUS)) <= BotDriver.RUNUP_DROP,
		"%s %s" % [bot._goal, bot.steer_seen])
	game.free()
	quit(t.verdict())
