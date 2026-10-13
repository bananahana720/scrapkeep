# smoke: solo timeout=90s
extends SceneTree
const Game=preload("res://src/game.gd")
const Posture=preload("res://src/combat/boss_posture.gd")
const Warden=preload("res://src/combat/warden.gd")
const T=preload("res://tests/support/t.gd")
var t=T.new("park_reactor_contact_grace_test")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var game=Game.new()
	game.test_mode=true
	game.table="park"
	root.add_child(game)
	game.ctx.calm=true
	game.flow.force_warden=true
	game.flow.press_start()
	game.flow.choose_class(1)
	for i in 40: await physics_frame
	var w=game.flow.warden
	var p=w._posture
	p.apply({"contact":true,"gain":40.0},1)
	p.step(Warden.PULSE_CYCLE)
	t.eq("a landed dam contact holds through one pulse rhythm",p.posture,40.0)
	p.step(0.5)
	t.eq("dam drain resumes at its unchanged rate after grace",p.posture,40.0-Posture.DRAIN_RATE*0.5)
	var normal=Posture.new()
	normal.apply({"contact":true,"gain":40.0},1)
	normal.step(Posture.DRAIN_DELAY+0.5)
	t.eq("the default posture retains its existing delay and rate",normal.posture,40.0-Posture.DRAIN_RATE*0.5)
	for family in ["swarm","mind","reactor"]:
		var other=Warden.new()
		game.add_child(other)
		var spec={"family":family,"mounting":"flume" if family=="reactor" else "under_island","park_landmark":true,"anchor":[0,22,590],"harpoon_anchor":true}
		other.setup(game.player,game.ctx.terrain,game,Callable(game.flow,"in_play"),1.0,spec)
		if other.mount_driver!=null and other.mount_driver.has_method("step"): other.mount_driver.step(other,1.0/Engine.physics_ticks_per_second)
		other._posture.apply({"contact":true,"gain":40.0},1)
		other._posture.step(Posture.DRAIN_DELAY+0.5)
		t.eq(family+" outside dam keeps its regeneration",other.posture(),40.0-Posture.DRAIN_RATE*0.5)
		other.queue_free()
		await physics_frame
	game.free()
	quit(t.verdict())
