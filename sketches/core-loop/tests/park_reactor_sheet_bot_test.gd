# smoke: solo timeout=90s
extends SceneTree
const Game=preload("res://src/game.gd")
const BotDriver=preload("res://tools/bot_driver.gd")
const T=preload("res://tests/support/t.gd")
var t=T.new("park_reactor_sheet_bot_test")
class Hands extends BotDriver:
	var steer_seen:=Vector3.INF
	func _act(steer: Vector3,_aim,_delta: float,_fight: Node3D=null,_evade:=true) -> void:
		steer_seen=steer
		source.press["shift_pressed"]=true
		source.hold["shift_held"]=true
		_boost_clock=BOOST_GAP
		_shift_left=SHIFT_HOLD
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
	for i in 2: await physics_frame
	game.player.state.grounded=true
	bot._fight(w,1.0/Engine.physics_ticks_per_second)
	t.check("mounted dam reactor takes the visible pulse-sheet road",bot.steer_seen.distance_to(game.ctx.terrain.drop_point(foot.x,foot.z,game.player.tuning.RADIUS))<=BotDriver.RUNUP_DROP,bot._goal)
	t.check("the dry foot reserves boost for the sheet",not bot.source.press.has("shift_pressed") and not bot.source.hold.has("shift_held") and bot._boost_clock<=0.0)
	t.check("the dry foot brakes inside its runup edge",bot.source.hold.get("brake_held",false))
	sheet.on_pulse(w,false)
	bot._fight(w,1.0/Engine.physics_ticks_per_second)
	t.check("on the pulse the hand drives to the visible core",bot.steer_seen.distance_to(w.family_point_at())<=game.player.tuning.RADIUS,str(bot.steer_seen))
	t.check("the live sheet retains the boost hand",bot.source.press.get("shift_pressed",false))
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
