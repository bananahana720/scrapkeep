# smoke: solo timeout=90s
extends SceneTree
const SheetTest = preload("res://tests/park_reactor_sheet_test.gd")
const Reactor = preload("res://src/combat/warden_reactor.gd")
const Tuning = preload("res://src/movement/tuning.gd")
const Game = preload("res://src/game.gd")
const Intent = preload("res://src/movement/intent.gd")
const T = preload("res://tests/support/t.gd")
var t = T.new("park_reactor_jump_release_test")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var m = SheetTest.Mount.new()
	var d = Reactor.new()
	d.sheet_left = Reactor.SHEET_SECONDS
	d.sheet_dir = Vector3.FORWARD
	var jump := Tuning.new().f("jump_speed")
	for above in [false, true]:
		m.target.at = m.home + d.sheet_dir * (Reactor.SHEET_TOP - Tuning.RADIUS)
		var progress := 1.0 - (Reactor.SHEET_TOP - Tuning.RADIUS) / Reactor.SHEET_RUN
		var profile := Tuning.RADIUS + (m.family_point_at().y - Tuning.RADIUS) * progress * progress
		m.target.at.y = m.family_point_at().y + Tuning.RADIUS if above else profile + Tuning.RADIUS
		m.target.rigid.linear_velocity = -d.sheet_dir * Reactor.RIDE_MIN_SPEED + Vector3.UP * jump
		d._ride(m, 1.0 / Engine.physics_ticks_per_second)
		t.near("rising jump retained " + ("above core" if above else "above profile below core"), m.target.rigid.linear_velocity.y, jump)
		t.eq("core height releases ride" if above else "below core remains a ride", d.riding, not above)
	var along := Reactor.SHEET_RUN - Tuning.RADIUS
	m.target.at = m.home + d.sheet_dir * along
	var progress := 1.0 - along / Reactor.SHEET_RUN
	m.target.at.y = Tuning.RADIUS + (m.family_point_at().y - Tuning.RADIUS) * progress * progress + Reactor.SHEET_DEPTH - Tuning.RADIUS
	m.target.rigid.linear_velocity = -d.sheet_dir * Reactor.RIDE_MIN_SPEED + Vector3.DOWN * Reactor.RIDE_MIN_SPEED
	d._ride(m, 1.0 / Engine.physics_ticks_per_second)
	t.near("gravity owns descent above the ride profile", m.target.rigid.linear_velocity.y, -Reactor.RIDE_MIN_SPEED)
	m.free()
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.player.source = Intent.Scripted.new()
	for i in 40: await physics_frame
	var w = game.flow.warden
	var sheet = w.mount_driver
	sheet.on_pulse(w, false)
	var at: Vector3 = w.home + Vector3.FORWARD * (Reactor.SHEET_TOP - Tuning.RADIUS)
	at.y = w.family_point_at().y + Tuning.RADIUS
	game.player.reset_to(at, Vector3.UP * jump - Vector3.FORWARD * Reactor.RIDE_MIN_SPEED)
	for i in 2: await physics_frame
	var start: float = game.player.ball_position().y
	for i in 10: await physics_frame
	t.check("ordinary jump arc rises after sheet release", game.player.ball_position().y > start and game.player.body().linear_velocity.y > 0.0, str(game.player.body().linear_velocity))
	game.free()
	quit(t.verdict())
