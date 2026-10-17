extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Roster := preload("res://src/combat/roster.gd")
const Splitter := preload("res://src/combat/splitter.gd")
const Pod := preload("res://src/combat/splitter_pod.gd")
const T := preload("res://tests/support/t.gd")

# The Splitter (roster_specials.gd, src/combat/splitter.gd): it chases the ball and buds fuse
# pods (splitter_pod.gd) with a tell, up to its cap; each pod chases, fuses and blows up. How
# the Splitter dies decides whether it pops into more pods.

var game
var t := T.new("enemy_splitter_test")
var ball := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


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


func _clear() -> void:
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _spawn(offset: Vector3) -> Node3D:
	var at: Vector3 = game.ctx.terrain.drop_point(ball.x + offset.x, ball.z + offset.z, 1.2)
	return game.combat.spawn_enemy("splitter", at)


func _pods() -> Array:
	return get_nodes_in_group("enemy").filter(func(e): return String(e.kind) == "splitter_pod" and not e.is_dead())


# Kills a fresh Splitter `at_range` metres from the ball with one hit of `kind`, then waits
# out the seam flare. Returns [split meta, pods standing].
func _kill(kind: String, at_range: float) -> Array:
	_clear()
	game.player.reset_to(ball)
	var splitter := _spawn(Vector3(at_range, 0.0, 0.0))
	await _frames(2)
	splitter.hp = 1.0
	var split := [null]
	splitter.died.connect(func(_at: Vector3, _scrap: int): split[0] = splitter.get_meta("split", null))
	game.combat.strike(splitter, kind, 60.0)
	await _frames(int(ceil(Splitter.POP_DELAY * Engine.physics_ticks_per_second)) + 4)
	return [split[0], _pods().size()]


func _run() -> void:
	await _boot()

	t.check("the splitter is declared and built", Roster.has("splitter") and Roster.built("splitter"))
	t.eq("roster row is kill-first", Roster.row("splitter").get("priority", ""), "kill_first")
	t.check("chassis column is sound", Roster.chassis_problems(Roster.row("splitter")).is_empty())

	# It chases: a Splitter 20 m out closes in.
	var splitter := _spawn(Vector3(20.0, 0.0, 0.0))
	t.eq("spawned as a splitter", String(splitter.kind), "splitter")
	var told := []
	splitter.special_tell.connect(func(moment: String): told.append([moment, splitter.pods().size()]))
	var start: float = Vector2(splitter.global_position.x - ball.x, splitter.global_position.z - ball.z).length()
	await _frames(int(Splitter.BUD_FIRST * Engine.physics_ticks_per_second) - 10)
	var now: float = Vector2(splitter.global_position.x - ball.x, splitter.global_position.z - ball.z).length()
	t.check("it chases the ball", now < start - 5.0, "%.1f to %.1f m" % [start, now])

	# It buds: the tell fires on the flare's first frame, and one pod follows.
	await _frames(int((Splitter.POP_DELAY + 0.1) * Engine.physics_ticks_per_second) + 20)
	t.check("tells before its first bud", not told.is_empty() and told[0] == ["tell", 0], str(told))
	t.eq("first bud is one pod", splitter.buds, 1)
	t.eq("the pod stands", _pods().size(), 1)

	# It keeps budding up to its cap, and no further while those stand.
	var pods := _pods()
	for pod in pods:
		pod.hp = 99999.0
		pod.max_hp = 99999.0
		pod.set_physics_process(false)
	for frame in int(Splitter.BUD_EVERY * (Splitter.POD_CAP + 1) * Engine.physics_ticks_per_second):
		game.player.reset_to(ball)
		for pod in _pods():
			pod.set_physics_process(false)
		await physics_frame
	t.eq("buds stop at the cap", _pods().size(), Splitter.POD_CAP)
	t.eq("one tell per bud", told.size(), splitter.buds)

	# A pod chases, lights its fuse ring, hits a ball inside it and is spent.
	_clear()
	game.player.reset_to(ball)
	var pod: Node3D = game.combat.spawn_enemy("splitter_pod", game.ctx.terrain.drop_point(ball.x + 12.0, ball.z, 1.2))
	t.check("a pod is light enough to flail", pod.weight < 1.0, str(pod.weight))
	var hits := []
	var ring_at_hit := []
	pod.hit_player.connect(func(amount: float, _shove: Vector3): hits.append(amount))
	var gone := [false]
	pod.died.connect(func(_at: Vector3, scrap: int): gone[0] = true; ring_at_hit.append(scrap))
	for frame in 600:
		game.player.reset_to(ball)
		if gone[0]:
			break
		await physics_frame
	t.check("the blast hits a ball inside its ring", hits.size() == 1 and is_equal_approx(hits[0], Pod.BLAST_DAMAGE), str(hits))
	t.check("the pod is spent by its blast and pays nothing", gone[0] and ring_at_hit == [0], str(ring_at_hit))

	# A ball that leaves the ring during the fuse is not hit.
	_clear()
	game.player.reset_to(ball)
	pod = game.combat.spawn_enemy("splitter_pod", game.ctx.terrain.drop_point(ball.x + 12.0, ball.z, 1.2))
	hits.clear()
	pod.hit_player.connect(func(amount: float, _shove: Vector3): hits.append(amount))
	var dodged := false
	var escape: Vector3 = game.ctx.terrain.drop_point(ball.x - 20.0, ball.z, 1.05)
	for frame in 600:
		if not is_instance_valid(pod) or pod.is_dead():
			break
		game.player.reset_to(escape if pod.telegraph() != null else ball)
		await physics_frame
	t.check("a ball out of the ring is not hit", hits.is_empty(), str(hits))
	t.check("rolling out is the codex trick", game.combat.discovered.has("fuse_pod"))

	# Rammed at ground level it pops into three pods after the seam flare.
	var rammed := await _kill("ram", 2.5)
	t.check("a ram splits it", rammed[0] == true, str(rammed))
	t.eq("a ram leaves three pods", rammed[1], Splitter.SPLIT_PODS)

	# A close shot splits it too; a stomp, a slam or any hit from 15 m kills it clean.
	var close := await _kill("arc", 6.0)
	t.check("a close shot splits it", close == [true, Splitter.SPLIT_PODS], str(close))
	for kind in ["stomp", "slam"]:
		var above := await _kill(kind, 2.5)
		t.check("a %s kills it clean" % kind, above == [false, 0], str(above))
	var far := await _kill("arc", Splitter.CLEAN_RANGE + 3.0)
	t.check("a shot from 15 m kills it clean", far == [false, 0], str(far))
	t.check("clean_kill reads range", Splitter.clean_kill("ram", 15.0) and not Splitter.clean_kill("ram", 14.9))

	_clear()
	quit(t.verdict())
