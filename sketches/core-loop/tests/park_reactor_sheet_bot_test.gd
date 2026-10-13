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
	bot._fight(w,1.0/Engine.physics_ticks_per_second)
	t.check("mounted dam reactor takes the visible pulse-sheet road",bot.steer_seen.distance_to(game.ctx.terrain.drop_point(foot.x,foot.z,game.player.tuning.RADIUS))<=BotDriver.RUNUP_DROP,bot._goal)
	sheet.on_pulse(w,false)
	bot._fight(w,1.0/Engine.physics_ticks_per_second)
	t.check("on the pulse the hand drives to the visible core",bot.steer_seen.distance_to(w.family_point_at())<=game.player.tuning.RADIUS,str(bot.steer_seen))
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
