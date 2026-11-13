extends SceneTree

# A crew starts with weight (W1-84, counter.gd STRIDE_RAMP): from a standstill it builds to its
# walking speed over STRIDE_RAMP instead of jumping there in one tick, and a warning still stands
# it still from its first tick, as before.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

var _game
var _t := T.new("crew_stride_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.rng.seed = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	for i in 3:
		await physics_frame
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	var ball: Vector3 = _game.player.ball_position()
	var crew = _game.combat.spawn_enemy("hooker", ball + Vector3(14.0, 1.6, 0.0))
	crew.hp = 100000.0
	crew._rest = 999.0
	# It walks straight at the ball at full pace while measured (inside keep_far it would circle),
	# after 40 ticks standing (walk_speed 0) to land.
	var full: float = crew.walk_speed
	var far: float = crew.keep_far
	crew.keep_far = 1.0
	crew.walk_speed = 0.0
	for i in 40:
		await physics_frame
	crew.walk_speed = full
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	var speeds := []
	for i in 30:
		await physics_frame
		speeds.append(Vector2(crew.velocity.x, crew.velocity.z).length())
	var first: float = speeds[0]
	var reach := speeds.find(speeds.filter(func(s): return s >= full * 0.99).front() if speeds.any(func(s): return s >= full * 0.99) else -1.0)
	_t.check("the first tick is a step, not full speed", first < full * 0.3, "%.2f of %.2f" % [first, full])
	var seconds := float(reach + 1) * tick
	_t.check("it reaches walking speed in about STRIDE_RAMP", reach >= 0 and absf(seconds - crew.STRIDE_RAMP) <= 2.0 * tick, "%.3f s" % seconds)
	var rising := true
	for i in range(1, reach + 1):
		rising = rising and speeds[i] >= speeds[i - 1] - 0.001
	_t.check("its speed only climbs on the way", rising)
	# A warning stands it still from its first tick, with no ease-out.
	crew.keep_far = far
	crew._rest = 0.0
	var stood := true
	var warned := false
	for i in 400:
		await physics_frame
		if crew.phase == crew.Phase.WARN:
			warned = true
			# The commit tick moved as roam did; the warning's first own tick stands.
			await physics_frame
			stood = Vector2(crew.velocity.x, crew.velocity.z).length() < 0.01
			break
	_t.check("the crew warned", warned)
	_t.check("a warning stands it still from its first tick", stood)
	# Out of the attack it builds up from a standstill again.
	crew._rest = 999.0
	crew.keep_far = 1.0
	var restarted := -1.0
	for i in 600:
		await physics_frame
		if crew.phase == crew.Phase.ROAM and not crew.recovering():
			await physics_frame
			restarted = Vector2(crew.velocity.x, crew.velocity.z).length()
			break
	_t.check("after its attack it starts with a step again", restarted >= 0.0 and restarted < full * 0.3, "%.2f" % restarted)
	# A knock carries the stride: when the knock bleeds out the crew does not snap to full speed.
	for i in 30:
		await physics_frame
	crew.knock(Vector3.LEFT, 12.0 * crew.weight)
	await physics_frame
	_t.check("the knock carried it", crew._knocked_speed() >= 1.0, "%.2f" % crew._knocked_speed())
	var after_knock := -1.0
	for i in 120:
		await physics_frame
		if crew._knocked_speed() < 1.0:
			# The tick after the knock hands control back to the crew.
			await physics_frame
			after_knock = Vector2(crew.velocity.x, crew.velocity.z).length()
			break
	_t.check("a knock hands over without a burst", after_knock >= 0.0 and after_knock <= full * 0.6, "%.2f of %.2f" % [after_knock, full])
	quit(_t.verdict())
