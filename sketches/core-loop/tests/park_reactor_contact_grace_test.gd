# smoke: solo timeout=90s
extends SceneTree
const Game=preload("res://src/game.gd")
const Posture=preload("res://src/core/boss_posture.gd")
const Warden=preload("res://src/combat/warden.gd")
const Reactor=preload("res://src/combat/warden_reactor.gd")
const Tuning=preload("res://src/movement/tuning.gd")
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
	var ring: Vector3=game.ctx.terrain.beacon_point(game.run.stage)
	game.player.reset_to(game.ctx.terrain.drop_point(ring.x,ring.z,Tuning.RADIUS),Vector3.ZERO)
	for i in 2: await physics_frame
	t.check("dam hold begins after authored ring engagement",game.flow.engaged())
	p.apply({"contact":true,"gain":40.0},1)
	w.mount_driver.on_pulse(w,false)
	w.mount_driver.step(w,1.0/Engine.physics_ticks_per_second)
	p.step(Reactor.SHEET_SECONDS)
	t.eq("the live sheet holds dam posture",w.posture(),40.0)
	w.mount_driver.sheet_left=0.0
	w.mount_driver.step(w,1.0/Engine.physics_ticks_per_second)
	p.step(Posture.DRAIN_DELAY+0.5)
	t.eq("engaged dam holds posture through dry seconds",w.posture(),40.0)
	w.live=func(): return false
	w.mount_driver.step(w,1.0/Engine.physics_ticks_per_second)
	p.step(Posture.DRAIN_DELAY+0.5)
	t.eq("disengaged dam keeps ordinary drain",w.posture(),40.0-Posture.DRAIN_RATE*0.5)
	var normal=Posture.new()
	normal.apply({"contact":true,"gain":40.0},1)
	normal.step(Posture.DRAIN_DELAY+0.5)
	t.eq("the default posture retains its existing delay and rate",normal.posture,40.0-Posture.DRAIN_RATE*0.5)
	for family in ["swarm","mind","reactor"]:
		var other=Warden.new()
		game.add_child(other)
		var spec={"family":family,"mounting":"flume" if family=="reactor" else "under_island","park_landmark":true,"anchor":[0,22,590],"harpoon_anchor":true}
		other.setup(game.player,game.ctx.terrain,game,Callable(game.flow,"in_play"),1.0,spec)
		Reactor.new().step(other,1.0/Engine.physics_ticks_per_second)
		for child in other.get_children():
			if child is CollisionShape3D:
				t.check(family+" outside dam retains its collider",child.position.is_equal_approx(Vector3.ZERO),str(child.position))
		other._posture.apply({"contact":true,"gain":40.0},1)
		other._posture.step(Posture.DRAIN_DELAY+0.5)
		t.eq(family+" outside dam keeps its regeneration",other.posture(),40.0-Posture.DRAIN_RATE*0.5)
		other.queue_free()
		await physics_frame
	game.free()
	quit(t.verdict())
