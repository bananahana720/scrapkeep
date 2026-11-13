extends SceneTree

# A walking crew turns its model to watch the ball, leans with its weight and steps instead of
# sliding (enemy_gait.gd, W1-82); it notices a crewmate going down and the ball being hit (W1-85);
# and its death pieces land (enemy_motion.gd, W1-86). All of it is on the model's pivot: the body's yaw and colliders do not
# move, a commit snap leaves the model's heading continuous and closes within the wind-up, and a
# headless run (tests, bots) or reduced motion keeps the old exact body.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const EnemyGait := preload("res://src/presentation/enemy_gait.gd")
const T := preload("res://tests/support/t.gd")

var _game
var _t := T.new("enemy_gait_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_unit()
	await _boot()
	await _headless_off()
	EnemyMotion.headless_idle = true
	await _walking()
	EnemyMotion.headless_idle = false
	quit(_t.verdict())


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _boot() -> void:
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
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _spawn(kind: String, at: Vector3):
	var enemy = _game.combat.spawn_enemy(kind, at)
	enemy.hp = 100000.0
	# Hold its attack so the whole read is the walk.
	enemy._rest = 999.0
	return enemy


func _shapes(enemy: Node) -> Array:
	var out := []
	for child in enemy.get_children():
		if child is CollisionShape3D:
			out.append(child.transform)
	return out


func _heading(enemy: Node3D) -> float:
	return enemy.rotation.y + enemy._gait.yaw()


# The module alone: the turn rate, a commit snap kept continuous and closed, reduced motion.
func _unit() -> void:
	EnemyMotion.headless_idle = true
	var body := Node3D.new()
	root.add_child(body)
	var gait := EnemyGait.new()
	var dt := 1.0 / 60.0
	for i in 10:
		gait.aim(2.0)
		gait.step(dt, body, Vector3.ZERO, 0.6)
	_t.check("turns at its rate, never snaps", absf(gait.yaw() - EnemyGait.TURN_RATE * dt * 10.0) < 0.001, "%.3f rad after 10 ticks toward 2.0" % gait.yaw())
	for i in 60:
		gait.aim(1.0)
		gait.step(dt, body, Vector3.ZERO, 0.6)
	_t.check("reaches its aim", absf(gait.yaw() - 1.0) < 0.001, "%.3f rad" % gait.yaw())
	# The commit faces the led aim, half a radian past where the model was watching.
	body.rotation.y = 1.5
	gait.committed()
	gait.step(dt, body, Vector3.ZERO, 0.6)
	var after_snap := body.rotation.y + gait.yaw()
	var one_ease := 0.5 * (1.0 - exp(-dt / EnemyGait.CATCH))
	_t.check("a commit snap eases the model's heading, never jumps", after_snap >= 1.0 and after_snap - 1.0 <= one_ease + 0.001, "heading %.4f rad, one tick's ease %.4f" % [after_snap, one_ease])
	var ticks := 0
	while absf(gait.yaw()) > deg_to_rad(1.0) and ticks < 60:
		gait.step(dt, body, Vector3.ZERO, 0.6)
		ticks += 1
	_t.check("the model closes on the committed yaw inside the wind-up", ticks * dt <= 0.15, "%d ticks" % ticks)
	gait.aim(1.0)
	body.rotation.y = 0.0
	var lean := 0.0
	var lift := 0.0
	for i in 150:
		gait.step(dt, body, Vector3(0.0, 0.0, 3.8) if i < 45 else Vector3.ZERO, 0.6)
		lean = maxf(lean, gait.tilt.basis.get_rotation_quaternion().get_angle())
		lift = maxf(lift, gait.turn.origin.y)
	_t.check("leans with its weight, never past the cap", lean > 0.05 and lean <= EnemyGait.LEAN_MAX + 0.001, "peak %.1f deg" % rad_to_deg(lean))
	_t.check("steps instead of sliding", lift > EnemyGait.STEP_LIFT * 0.5 and lift <= EnemyGait.STEP_LIFT + 0.0001, "peak lift %.3f m" % lift)
	_t.check("stands upright once stopped", gait.tilt.is_equal_approx(Transform3D.IDENTITY), str(gait.tilt))
	EnemyMotion.motion_scale = 0.0
	var still := true
	for i in 45:
		gait.step(dt, body, Vector3(0.0, 0.0, 3.8 if i % 10 < 5 else 0.0), 0.6)
		still = still and gait.tilt.is_equal_approx(Transform3D.IDENTITY) and gait.turn.origin == Vector3.ZERO
	_t.check("reduced motion drops the lean and steps", still)
	var before := gait.yaw()
	for i in 10:
		gait.aim(before + 1.0)
		gait.step(dt, body, Vector3.ZERO, 0.6)
	_t.check("reduced motion keeps the turn", absf(gait.yaw() - before - EnemyGait.TURN_RATE * dt * 10.0) < 0.001, "%.3f rad" % (gait.yaw() - before))
	var lifted := 0.0
	for i in 30:
		gait.step(dt, body, Vector3(10.0, 0.0, 0.0), 0.6, false)
		lifted = maxf(lifted, gait.turn.origin.y)
	EnemyMotion.motion_scale = 1.0
	for i in 30:
		gait.step(dt, body, Vector3(10.0, 0.0, 0.0), 0.6, false)
		lifted = maxf(lifted, gait.turn.origin.y)
	_t.check("a knocked or falling body does not step", lifted == 0.0, "peak lift %.3f m" % lifted)
	EnemyMotion.motion_scale = 1.0
	# W1-85: a glance takes the look from the aim for a beat; a hop is a small cheer.
	var aimed := gait.yaw()
	gait.glance(aimed + 1.5)
	for i in 20:
		gait.aim(aimed)
		gait.step(dt, body, Vector3.ZERO, 0.6)
	var glanced := angle_difference(aimed, gait.yaw())
	_t.check("a glance turns the head from its aim", glanced > 1.0, "%.2f rad toward the glance" % glanced)
	for i in 60:
		gait.aim(aimed)
		gait.step(dt, body, Vector3.ZERO, 0.6)
	_t.check("then the aim takes it back", absf(angle_difference(aimed, gait.yaw())) < 0.01, "%.3f rad off" % absf(angle_difference(aimed, gait.yaw())))
	gait.hop()
	var hop := 0.0
	for i in 30:
		gait.step(dt, body, Vector3.ZERO, 0.6)
		hop = maxf(hop, gait.turn.origin.y)
	_t.check("a hop lifts and comes down", hop > EnemyGait.HOP_LIFT * 0.9 and gait.turn.origin.y < 0.001, "peak %.3f m" % hop)
	EnemyMotion.headless_idle = false
	gait.step(dt, body, Vector3(0.0, 0.0, 3.8), 0.6)
	_t.check("off in a headless run", gait.tilt == Transform3D.IDENTITY and gait.turn == Transform3D.IDENTITY)
	body.free()


# A headless run keeps the exact body: the pivot carries nothing while the crew walks.
func _headless_off() -> void:
	var ball: Vector3 = _game.player.ball_position()
	var enemy = _spawn("hooker", ball + Vector3(30.0, 2.0, 0.0))
	var exact := true
	for i in 60:
		await physics_frame
		exact = exact and enemy.reaction_pivot.transform == Transform3D.IDENTITY
	_t.check("headless pivot stays exact", exact and enemy._gait != null, str(enemy.reaction_pivot.transform))
	enemy.free()


# The real crew on the slice: it turns its model to the ball while it walks, and only the pivot moves.
func _walking() -> void:
	var ball: Vector3 = _game.player.ball_position()
	var enemy = _spawn("hooker", ball + Vector3(30.0, 2.0, 0.0))
	await _frames(2)
	var body_yaw: float = enemy.rotation.y
	var shapes := _shapes(enemy)
	var moved := 0.0
	var start: Vector3 = enemy.global_position
	await _frames(90)
	moved = start.distance_to(enemy.global_position)
	var to_ball: Vector3 = _game.player.ball_position() - enemy.global_position
	var want := atan2(to_ball.x, to_ball.z)
	var off := absf(angle_difference(_heading(enemy), want))
	_t.check("the crew walked", moved > 1.0, "%.1f m" % moved)
	_t.check("its model watches the ball", off < deg_to_rad(15.0), "%.1f deg off" % rad_to_deg(off))
	_t.check("its body keeps its own yaw", absf(enemy.rotation.y - body_yaw) < 0.0001, "%.4f -> %.4f" % [body_yaw, enemy.rotation.y])
	_t.check("its colliders do not move", _shapes(enemy) == shapes)
	await _lands(enemy)


# W1-86: a grounded crew's death pieces fall to the floor it stood on, bounce, rest, then go.
func _lands(enemy) -> void:
	_t.check("the crew stands on the floor", enemy.is_on_floor())
	var parent: Node = enemy.get_parent()
	var count := parent.get_children().filter(func(n): return n.name.begins_with("DeathScatter")).size()
	enemy.take_damage(enemy.hp + 1.0)
	var made: Array = parent.get_children().filter(func(n): return n.name.begins_with("DeathScatter"))
	var scatter = made[made.size() - 1] if made.size() > count else null
	if scatter == null:
		_t.check("a death scatters", false)
		return
	_t.check("its pieces land on the floor and rest there", scatter.floor_y > -INF and is_equal_approx(scatter.life(), scatter.seconds + EnemyMotion.LAND_REST),
		"floor %.2f, life %.2f s" % [scatter.floor_y, scatter.life()])
	var ref: WeakRef = weakref(scatter)
	var rested := 0
	var under := 0
	var ticks := 0
	while ref.get_ref() != null and ticks < 240:
		await physics_frame
		ticks += 1
		var live = ref.get_ref()
		if live == null or live.is_queued_for_deletion():
			continue
		for piece in live._pieces:
			if (piece.node as Node3D).position.y < live.floor_y - 0.001:
				under += 1
			elif is_equal_approx((piece.node as Node3D).position.y, live.floor_y) and (piece.velocity as Vector3).y == 0.0:
				rested += 1
	_t.check("no piece sinks through the floor, and pieces come to rest", under == 0 and rested > 0, "%d under, %d resting samples" % [under, rested])
	_t.check("the rest still ends", ref.get_ref() == null, "%d ticks" % ticks)
