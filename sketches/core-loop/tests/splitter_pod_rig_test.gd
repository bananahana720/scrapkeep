extends SceneTree

# The Splitter pod's body (splitter_pod.gd): seated on the piece glb's own scene so its
# pop_in plays once when born (bud or death-split) and then scurry loops; its fuse wind-up
# reads the same committed warn progress as the ring and the seam glow; and none of it moves
# gameplay geometry or timing. Seating needs the headless idle opt-in (EnemyMotion.active()).

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const WindupPoses := preload("res://src/presentation/windup_poses.gd")
const Pod := preload("res://src/combat/splitter_pod.gd")
const Splitter := preload("res://src/combat/splitter.gd")
const T := preload("res://tests/support/t.gd")
const Comfort := preload("res://src/core/comfort.gd")

var game
var ball := Vector3.ZERO
var t := T.new("splitter_pod_rig_test")


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _clear() -> void:
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _boot() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.ctx.rng.seed = 7
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999.0)
	game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	_clear()
	var spawn: Vector3 = game.ctx.terrain.spawn_point(1)
	ball = game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)
	game.player.reset_to(ball)


func _pod(offset: float) -> Node3D:
	return game.combat.spawn_enemy("splitter_pod", game.ctx.terrain.drop_point(ball.x + offset, ball.z, 1.2))


func _shapes(enemy) -> Array:
	var out: Array = []
	for child in enemy.get_children():
		if child is CollisionShape3D:
			out.append([child.transform, (child.shape as CapsuleShape3D).radius, (child.shape as CapsuleShape3D).height])
	return out


func _run() -> void:
	await _boot()
	# Headless without the opt-in copies meshes, as before.
	var plain = _pod(30.0)
	t.check("headless without the idle copies meshes, no rig", plain.get_node_or_null("SpecialRig") == null
		and plain.find_children("*", "Skeleton3D", true, false).is_empty()
		and plain.find_children("*", "MeshInstance3D", true, false).size() >= 2)
	plain.free()

	EnemyMotion.headless_idle = true
	# (a) Born: pop_in from age 0, then scurry once it ends.
	var pod = _pod(30.0)
	pod.set_physics_process(false)
	var rig = pod.get_node_or_null("SpecialRig")
	t.check("a pod seats a SpecialRig on the piece glb", rig != null and rig.kind == "splitter_piece")
	if rig == null:
		quit(t.verdict())
		return
	t.check("it skins its meshes on the glb's skeleton", pod.find_children("*", "Skeleton3D", true, false).size() == 1
		and pod.find_children("*", "Skeleton3D", true, false)[0].find_children("*", "MeshInstance3D", true, false).all(func(m): return (m as MeshInstance3D).skin != null))
	var body_node: Node3D = pod.get_node("ReactionPivot/PodBody")
	t.check("the seated path adds no copied mesh beside the glb's", body_node.find_children("*", "MeshInstance3D", true, false).all(
		func(m): return (m as MeshInstance3D).skin != null) and body_node.get_child_count() == 1)
	t.eq("born plays pop_in", String(rig.player.current_animation), "pop_in")
	t.near("pop_in starts at age 0", rig.player.current_animation_position, 0.0, 0.0001)
	rig.player.advance(rig.player.get_animation("pop_in").length + 0.02)
	t.eq("then it scurries", String(rig.player.current_animation), "scurry")
	rig.player.advance(0.1)
	t.check("scurry advances", rig.player.current_animation_position > 0.0)
	t.eq("scurry loops", rig.player.get_animation("scurry").loop_mode, Animation.LOOP_LINEAR)
	pod.free()

	# A death-split pod is born the same way (Splitter.Pop spawns the same kind).
	_clear()
	game.player.reset_to(ball)
	var mama = game.combat.spawn_enemy("splitter", game.ctx.terrain.drop_point(ball.x + 2.5, ball.z, 1.2))
	var popped := false
	for p in Splitter.SPLIT_PODS:
		var child = game.combat.spawn_enemy("splitter_pod", mama.global_position + mama.pod_offsets()[p])
		var r = child.get_node_or_null("SpecialRig")
		popped = r != null and String(r.player.current_animation) == "pop_in" if p == 0 else popped and r != null and String(r.player.current_animation) == "pop_in"
	t.check("every split pod is born on pop_in", popped)
	_clear()

	# (b) The wind-up is the committed telegraph's progress, sampled live through a real fuse.
	game.player.reset_to(ball)
	pod = _pod(8.0)
	var shapes := _shapes(pod)
	var samples := {0.25: false, 0.5: false, 0.75: false}
	var matched := 0
	var worst := 0.0
	var scale_ok := true
	var shapes_ok := true
	var feet_ok := true
	var squashed := false
	for frame in 400:
		game.player.reset_to(ball)
		await physics_frame
		if not is_instance_valid(pod) or pod.is_dead():
			break
		var tele = pod.telegraph()
		if pod.phase != Pod.Phase.WARN or tele == null:
			continue
		var want: Basis = WindupPoses.windup(Pod.WIND_POSE, tele.progress, tele.age, Comfort.motion_scale())
		var body: Node3D = pod.get_node("ReactionPivot/PodBody")
		worst = maxf(worst, maxf((body.basis.x - want.x).length(), maxf((body.basis.y - want.y).length(), (body.basis.z - want.z).length())))
		scale_ok = scale_ok and is_equal_approx(rig_speed(pod), 1.0 - tele.progress)
		matched += 1
		var feet := body.position.y - Pod.BODY_HALF * body.basis.y.length()
		feet_ok = feet_ok and absf(feet + Pod.BODY_HALF) < 0.000001
		squashed = squashed or body.basis.y.length() < 0.9
		shapes_ok = shapes_ok and _shapes(pod) == shapes
		for mark in samples:
			if tele.progress >= mark and not samples[mark]:
				samples[mark] = true
				t.near("wind-up progress at %.2f of the fuse is the telegraph's" % mark, pod.fuse_progress(), tele.progress, 0.000001)
				t.check("body basis at %.2f is the pose at that progress" % mark, (body.basis.y - want.y).length() < 0.000001, str(body.basis))
	t.check("PodBody feet stay at the floor across the fuse, which did squash", feet_ok and squashed)
	t.check("sampled a whole fuse", matched >= 60 and samples.values().all(func(v): return v), "%d frames" % matched)
	t.check("body basis matches the pose on every WARN frame", worst < 0.000001, str(worst))
	t.check("scurry slows to a stop as the fuse fills", scale_ok)
	t.check("the wind-up tells before the blast (warn >= 0.6 s)", Pod.FUSE >= 0.6)
	t.check("the collider is unmoved on every WARN frame", shapes_ok and not shapes.is_empty())
	_clear()

	# The husk after the blast snaps through the release and settles, not straight to rest.
	var husk = _pod(30.0)
	husk.set_physics_process(false)
	husk.spent = true
	husk._husk_age = 0.0
	husk._pose()
	t.check("a spent husk starts its release pose", husk._body.basis != Basis.IDENTITY)
	husk._husk_age = WindupPoses.RELEASE_SECONDS + 0.01
	husk._pose()
	t.check("the release settles to rest", husk._body.basis == Basis.IDENTITY)
	husk.free()
	_clear()

	# Reduced motion: no wind-up pose (as windup_poses.gd), the scurry loop stilled.
	Comfort.reduced_motion = true
	t.check("reduced motion has no wind-up pose", WindupPoses.windup(Pod.WIND_POSE, 0.9, 0.3, 0.0) == Basis.IDENTITY)
	var calm = _pod(30.0)
	calm.set_physics_process(false)
	var calm_player: AnimationPlayer = calm.get_node("SpecialRig").player
	t.eq("reduced motion still plays the birth pop (a read, as tells)", String(calm_player.current_animation), "pop_in")
	calm_player.advance(calm_player.get_animation("pop_in").length + 0.02)
	t.check("reduced motion starts no scurry after it", not calm_player.is_playing())
	calm.free()
	Comfort.reduced_motion = false
	EnemyMotion.headless_idle = false

	# (c) Gameplay numbers are the committed ones.
	var live = _pod(30.0)
	t.eq("fuse seconds", Pod.FUSE, 1.0)
	t.eq("warn seconds are the fuse", live.warn_seconds, Pod.FUSE)
	t.eq("ring radius", Pod.BLAST_RADIUS, 4.5)
	t.eq("walk speed", live.walk_speed, 10.0)
	t.eq("collider radius", live.radius, 0.6)
	t.eq("collider half height", live.half_height, 0.9)
	t.eq("blast range", live.attack_range, 3.5)
	t.eq("pop delay", Splitter.POP_DELAY, 0.4)
	t.eq("bud knock stays out of the rig (collider shapes)", _shapes(live).size(), 1)
	live.free()
	quit(t.verdict())


func rig_speed(pod) -> float:
	return pod.get_node("SpecialRig").player.speed_scale
