# smoke: solo timeout=90s
extends SceneTree
const Game=preload("res://src/game.gd")
const BotDriver=preload("res://tools/bot_driver.gd")
const SimClock=preload("res://src/core/sim_clock.gd")
const T=preload("res://tests/support/t.gd")
var t=T.new("park_reactor_sheet_bot_test")
class Hands extends BotDriver:
	var steer_seen:=Vector3.INF
	func _act(steer: Vector3,aim,delta: float,fight: Node3D=null,evade:=true) -> void:
		steer_seen=steer
		super._act(steer,aim,delta,fight,evade)
func _initialize() -> void:
	SimClock.ticks=true
	_run.call_deferred()
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
	var ram_cycle := -1
	for i in roundi(w.PULSE_CYCLE*Engine.physics_ticks_per_second):
		bot.tick(1.0/Engine.physics_ticks_per_second)
		saw_charge=saw_charge or w.state_name()=="charging"
		if (sheet.sheet_live() or w.state_name()=="charging") and bot.source.press.get("shift_pressed",false) and game.player.state.grounded: saw_launch=true
		await physics_frame
		if not contacts.is_empty():
			ram_cycle=sheet.gates_opened
			break
	t.check("normal charge and pulse opens the road",saw_charge and w.pulses>pulses)
	t.check("normal charge-to-pulse transition produces a grounded launch input",saw_launch)
	for i in roundi(sheet.SHEET_SECONDS*Engine.physics_ticks_per_second):
		if not contacts.is_empty():
			ram_cycle=sheet.gates_opened
			break
		bot.tick(1.0/Engine.physics_ticks_per_second)
		await physics_frame
	t.check("the pulse launch approaches and contacts the core",not contacts.is_empty(),str(contacts))
	bot.source.press.clear()
	bot._fight(w,1.0/Engine.physics_ticks_per_second)
	t.check("after a real ram the hand returns to the grounded foot",ram_cycle==sheet.gates_opened and bot._fight_phase=="sheet return %d" % ram_cycle and bot.steer_seen.is_equal_approx(game.ctx.terrain.drop_point(foot.x,foot.z,game.player.tuning.RADIUS)),str(bot.steer_seen))
	bot.source.press.clear()
	bot.source.hold.clear()
	var waiting: Vector3=w.home+sheet.sheet_dir*(sheet.SHEET_RUN+BotDriver.RUNUP_EDGE)
	var pulse_wait: Vector3=w.home+sheet.sheet_dir.cross(Vector3.UP)*sheet.SHEET_WIDTH
	game.player.reset_to(game.ctx.terrain.drop_point(pulse_wait.x,pulse_wait.z,game.player.tuning.RADIUS))
	var next_charge:=false
	for i in ceili(w.PULSE_CYCLE*2.0*Engine.physics_ticks_per_second):
		next_charge=next_charge or w.state_name()=="charging"
		if sheet.gates_opened>ram_cycle and sheet.sheet_live(): break
		await physics_frame
	t.check("a subsequent real charge and pulse opens an unrammed cycle",next_charge and sheet.gates_opened>ram_cycle and sheet.sheet_live())
	for control in ["cooldown","airborne","unavailable boost"]:
		await _prepare_launch(game,bot,w,waiting,control=="airborne")
		if control=="cooldown": bot._boost_clock=BotDriver.BOOST_GAP
		if control=="unavailable boost": game.player.abilities.slot("movement").available=false
		t.check(control+" control has a live unrammed inbound approach",sheet.sheet_live() and bot._fight_phase!="sheet return %d" % sheet.gates_opened and game.player.planar_velocity().dot(sheet.sheet_dir)<=0.0)
		t.check(control+" control isolates eligibility",(not game.player.state.grounded if control=="airborne" else game.player.state.grounded) and (not game.player.verb_ready("boost") if control=="unavailable boost" else game.player.verb_ready("boost")) and (bot._boost_clock>0.0 if control=="cooldown" else bot._boost_clock<=0.0))
		bot._fight(w,1.0/Engine.physics_ticks_per_second)
		t.check(control+" withholds launch",not bot.source.press.get("shift_pressed",false) and not bot.source.hold.get("shift_held",false))
		await _prepare_launch(game,bot,w,waiting)
		t.check(control+" positive control is eligible",sheet.sheet_live() and game.player.state.grounded and game.player.verb_ready("boost") and bot._boost_clock<=0.0 and game.player.planar_velocity().dot(sheet.sheet_dir)<=0.0)
		bot._fight(w,1.0/Engine.physics_ticks_per_second)
		t.check(control+" positive control launches",bot.source.press.get("shift_pressed",false) and bot.source.hold.get("shift_held",false))
		t.check(control+" fresh cycle drives to the visible core",bot.steer_seen.is_equal_approx(w.family_point_at()),str(bot.steer_seen))
	bot.source.press.clear()
	bot.source.hold.clear()
	for i in ceili(sheet.SHEET_SECONDS*Engine.physics_ticks_per_second):
		if not sheet.sheet_live(): break
		await physics_frame
	t.check("the real sheet expires before family controls",not sheet.sheet_live())
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

func _prepare_launch(game,bot,w,waiting: Vector3,airborne:=false) -> void:
	bot.source.press.clear()
	bot.source.hold.clear()
	bot._boost_clock=0.0
	bot._shift_left=0.0
	game.player.abilities.slot("movement").available=true
	game.player.state.boost_cooldown=0.0
	var at: Vector3=game.ctx.terrain.drop_point(waiting.x,waiting.z,game.player.tuning.RADIUS)
	if airborne: at+=Vector3.UP*BotDriver.RUNUP_DROP
	game.player.reset_to(at,-w.mount_driver.sheet_dir*game.player.tuning.f("cruise"))
	for i in 2: await physics_frame
