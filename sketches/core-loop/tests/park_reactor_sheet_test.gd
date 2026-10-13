# smoke: solo timeout=90s
extends SceneTree
const Game = preload("res://src/game.gd")
const Intent = preload("res://src/movement/intent.gd")
const Reactor = preload("res://src/combat/warden_reactor.gd")
const Warden = preload("res://src/combat/warden.gd")
const Tuning = preload("res://src/movement/tuning.gd")
const T = preload("res://tests/support/t.gd")
var t = T.new("park_reactor_sheet_test")
var game
class Floor extends RefCounted:
	func height(_x: float,_z: float) -> float: return 0.0
class Body extends RefCounted:
	var linear_velocity:=Vector3.ZERO
	func set_velocity_now(v: Vector3) -> void: linear_velocity=v
class Ball extends RefCounted:
	signal struck(enemy: Node3D, kind: String, force: float)
	var at := Vector3.ZERO
	var rigid:=Body.new()
	var line_cuts:=0
	var tuning = null
	var kit = null
	var accel := Vector3.ZERO
	func ball_position() -> Vector3: return at
	func body(): return rigid
	func set_velocity_now(_v: Vector3) -> void: line_cuts+=1
	func add_external_accel(a: Vector3) -> void: accel+=a
	func _on_enemy_touched(enemy: Node3D, _normal: Vector3) -> void:
		struck.emit(enemy,"ram",Vector2(rigid.linear_velocity.x,rigid.linear_velocity.z).length())
class Mount extends Node3D:
	const FAMILY_POINT_RADIUS=Warden.FAMILY_POINT_RADIUS
	var spec := {"park_landmark":true}
	var family := "reactor"
	var mounting := "dam_face"
	var home := Vector3(0,22,590)
	var terrain := Floor.new()
	var target := Ball.new()
	var fleet = null
	func family_point_at() -> Vector3: return home+Vector3.UP*5.2
	func flat_to_ball() -> Vector3: return Vector3.FORWARD
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var m=Mount.new()
	var d=Reactor.new()
	d.sheet_left=Reactor.SHEET_SECONDS
	d.sheet_dir=Vector3.FORWARD
	m.target.at=m.family_point_at()+d.sheet_dir*Tuning.RADIUS
	m.target.rigid.linear_velocity=-d.sheet_dir*Reactor.RIDE_MIN_SPEED
	var hits=[]
	m.target.struck.connect(func(e,k,f): hits.append([e,k,f]))
	d._ride(m,1.0/Engine.physics_ticks_per_second)
	d._ride(m,1.0/Engine.physics_ticks_per_second)
	t.eq("the sheet leaves contact publication to the solver",hits.size(),0)
	for family in ["swarm","mind"]:
		m.family=family
		if m.has_meta("reactor_sheet_contact"): m.remove_meta("reactor_sheet_contact")
		hits.clear()
		d._ride(m,1.0/Engine.physics_ticks_per_second)
		t.eq("sheet contact stays out of "+family,hits.size(),0)
	m.family="reactor"
	for mounting in ["flume","dam_face"]:
		m.mounting=mounting
		m.spec.park_landmark=mounting!="dam_face"
		if m.has_meta("reactor_sheet_contact"): m.remove_meta("reactor_sheet_contact")
		hits.clear()
		d._ride(m,1.0/Engine.physics_ticks_per_second)
		t.eq("flume and arena retain their contact rule: "+mounting,hits.size(),0)
	m.spec.park_landmark=true
	m.mounting="dam_face"
	d.sheet_left=0.0
	hits.clear()
	d._ride(m,1.0/Engine.physics_ticks_per_second)
	t.eq("a dry sheet never pays a contact",hits.size(),0)
	d.sheet_left=Reactor.SHEET_SECONDS
	m.target.at=m.home+d.sheet_dir*(Reactor.SHEET_RUN-Tuning.RADIUS)
	m.target.at.y=Tuning.RADIUS
	m.target.rigid.linear_velocity=-d.sheet_dir*Reactor.RIDE_MIN_SPEED
	d._ride(m,1.0/Engine.physics_ticks_per_second)
	t.eq("guiding the sheet preserves a held anchor line",m.target.line_cuts,0)
	t.check("sheet guidance commits its vertical velocity to the body",m.target.rigid.linear_velocity.y>0.0,str(m.target.rigid.linear_velocity))
	m.free()
	game=Game.new()
	game.test_mode=true
	game.table="park"
	root.add_child(game)
	game.ctx.calm=true
	game.flow.force_warden=true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.player.source=Intent.Scripted.new()
	game.ctx.spawner.heft_override=1.0
	for i in 40: await physics_frame
	var w=game.flow.warden
	var driver=w.mount_driver
	var collider: CollisionShape3D
	for child in w.get_children():
		if child is CollisionShape3D: collider=child
	t.check("mounted contact volume agrees with the visible core",collider.global_position.is_equal_approx(w._kit._open_node.global_position),"collider %s, visual %s" % [collider.global_position,w._kit._open_node.global_position])
	driver.sheet_dir=Vector3.FORWARD
	var foot: Vector3=w.home+driver.sheet_dir*(driver.SHEET_RUN-Tuning.RADIUS)
	game.player.reset_to(game.ctx.terrain.drop_point(foot.x,foot.z,Tuning.RADIUS),-driver.sheet_dir*game.player.tuning.f("cruise"))
	var contacts=[]
	var body_contacts=[]
	game.player.body().enemy_touched.connect(func(enemy,_normal):
		if enemy==w: body_contacts.append(game.player.ball_position()))
	game.events.enemy_struck.connect(func(enemy,kind,force):
		if enemy==w and kind in ["ram","stomp","slam"]: contacts.append([kind,force,game.player.ball_position()]))
	driver.on_pulse(w,false)
	for i in roundi(driver.SHEET_SECONDS*Engine.physics_ticks_per_second):
		w._pulse_clock=0.0
		await physics_frame
	t.check("cruise from the authored dam apron lands a real contact on the pulse sheet",not contacts.is_empty(),"contacts %s, final ball %s" % [contacts,game.player.ball_position()])
	t.check("the solver contacts the same visible core",not body_contacts.is_empty(),str(body_contacts))
	t.check("the applied contact lands at the authored visual core",contacts.any(func(row): return (row[2] as Vector3).distance_to(w.family_point_at())<=w.FAMILY_POINT_RADIUS+Tuning.RADIUS),str(contacts))
	game.free()
	quit(t.verdict())
