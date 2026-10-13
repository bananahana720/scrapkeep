# smoke: solo timeout=90s
extends SceneTree
const Game=preload("res://src/game.gd")
const BotDriver=preload("res://tools/bot_driver.gd")
const T=preload("res://tests/support/t.gd")
var t=T.new("park_reactor_sheet_bot_test")
class Hands extends BotDriver:
	var steer_seen:=Vector3.INF
	func _act(steer: Vector3,aim,delta: float,fight: Node3D=null,evade:=true) -> void:
		steer_seen=steer
		super._act(steer,aim,delta,fight,evade)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var game=Game.new()
	game.test_mode=true
	game.table="park"
	root.add_child(game)
	game.ctx.calm=true
	game.flow.force_warden=true
	var bot=Hands.new(game,"skipper",1)
	bot.start()
	var w=game.flow.warden
	var sheet=w.mount_driver
	sheet.sheet_dir=Vector3.FORWARD
	var foot: Vector3=w.home+sheet.sheet_dir*minf(BotDriver.RUNUP,sheet.SHEET_RUN-BotDriver.RUNUP_EDGE)
	game.player.reset_to(game.ctx.terrain.drop_point(foot.x,foot.z,game.player.tuning.RADIUS))
	for i in Engine.physics_ticks_per_second: await physics_frame
	t.check("the dry foot is grounded by physics",game.player.state.grounded)
	bot._fight(w,1.0/Engine.physics_ticks_per_second)
	t.check("mounted dam reactor takes the visible pulse-sheet road",bot.steer_seen.distance_to(game.ctx.terrain.drop_point(foot.x,foot.z,game.player.tuning.RADIUS))<=BotDriver.RUNUP_DROP,bot._goal)
	t.check("the dry foot reserves boost for the sheet",not bot.source.press.has("shift_pressed") and not bot.source.hold.has("shift_held") and bot._boost_clock<=0.0)
	t.check("the dry foot brakes inside its runup edge",bot.source.hold.get("brake_held",false))
	var contacts=[]
	game.events.enemy_struck.connect(func(enemy,kind,_force):
		if enemy==w and kind in ["ram","stomp","slam"]: contacts.append(kind))
	var saw_charge:=false
	var saw_launch:=false
	var pulses: int=w.pulses
	for i in roundi(w.PULSE_CYCLE*Engine.physics_ticks_per_second):
		bot.tick(1.0/Engine.physics_ticks_per_second)
		saw_charge=saw_charge or w.state_name()=="charging"
		if sheet.sheet_live() and bot.source.press.get("shift_pressed",false): saw_launch=true
		await physics_frame
	t.check("normal charge and pulse opens the road",saw_charge and w.pulses>pulses)
	t.check("normal pulse produces a launch input",saw_launch)
	for i in roundi(sheet.SHEET_SECONDS*Engine.physics_ticks_per_second):
		bot.tick(1.0/Engine.physics_ticks_per_second)
		await physics_frame
	t.check("the pulse launch approaches and contacts the core",not contacts.is_empty(),str(contacts))
	# Control clocks are set only here, to test withholding rather than supply the launch.
	game.player.reset_to(game.ctx.terrain.drop_point(foot.x,foot.z,game.player.tuning.RADIUS))
	for i in Engine.physics_ticks_per_second: await physics_frame
	sheet.sheet_left=sheet.SHEET_SECONDS
	bot.source.press.clear()
	bot._boost_clock=BotDriver.BOOST_GAP
	bot._fight(w,1.0/Engine.physics_ticks_per_second)
	t.check("on the pulse the hand drives to the visible core",bot.steer_seen.distance_to(w.family_point_at())<=game.player.tuning.RADIUS,str(bot.steer_seen))
	t.check("a cooling hand does not launch",not bot.source.press.get("shift_pressed",false))
	game.player.reset_to(game.player.ball_position()+Vector3.UP*BotDriver.RUNUP_DROP)
	for i in 2: await physics_frame
	bot._boost_clock=0.0
	bot.source.press.clear()
	bot._fight(w,1.0/Engine.physics_ticks_per_second)
	t.check("an airborne hand does not launch",not game.player.state.grounded and not bot.source.press.get("shift_pressed",false))
	game.player.reset_to(game.ctx.terrain.drop_point(foot.x,foot.z,game.player.tuning.RADIUS))
	for i in Engine.physics_ticks_per_second: await physics_frame
	game.player.state.boost_cooldown=BotDriver.BOOST_GAP
	bot._boost_clock=0.0
	bot.source.press.clear()
	bot._fight(w,1.0/Engine.physics_ticks_per_second)
	t.check("an unavailable boost does not launch",not game.player.verb_ready("boost") and not bot.source.press.get("shift_pressed",false))
	sheet.sheet_left=0.0
	for family in ["swarm","mind"]:
		w.family=family
		bot._fight(w,1.0/Engine.physics_ticks_per_second)
		t.check(family+" keeps its own mounted fight",not bot.steer_seen.is_equal_approx(game.ctx.terrain.drop_point(foot.x,foot.z,game.player.tuning.RADIUS)),bot._goal)
	w.family="reactor"
	w.mounting="flume"
	bot._fight(w,1.0/Engine.physics_ticks_per_second)
	t.check("flume keeps its own mounted fight",not bot.steer_seen.is_equal_approx(game.ctx.terrain.drop_point(foot.x,foot.z,game.player.tuning.RADIUS)),bot._goal)
	w.mounting="dam_face"
	w.spec.park_landmark=false
	bot._fight(w,1.0/Engine.physics_ticks_per_second)
	t.check("arena reactor keeps its hand",not bot.steer_seen.is_equal_approx(game.ctx.terrain.drop_point(foot.x,foot.z,game.player.tuning.RADIUS)),bot._goal)
	game.free()
	quit(t.verdict())
