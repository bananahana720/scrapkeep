extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Roster := preload("res://src/combat/roster.gd")
const Splitter := preload("res://src/combat/splitter.gd")
const Chaser := preload("res://src/combat/chaser.gd")
const T := preload("res://tests/support/t.gd")

# The Splitter (roster_specials.gd, src/combat/splitter.gd): its fuse blast tells on the
# committed frame and hits only inside its ring; how it dies decides whether it splits.

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


func _pieces() -> Array:
	return get_nodes_in_group("enemy").filter(func(e): return e.has_meta("splitter_piece") and not e.is_dead())


# Kills a fresh Splitter `at_range` metres from the ball with one hit of `kind`, then waits
# out the seam flare. Returns [split meta, pieces standing].
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
	return [split[0], _pieces().size()]


func _run() -> void:
	await _boot()

	t.check("the splitter is declared and built", Roster.has("splitter") and Roster.built("splitter"))
	t.eq("roster row is kill-first", Roster.row("splitter").get("priority", ""), "kill_first")
	t.check("chassis column is sound", Roster.chassis_problems(Roster.row("splitter")).is_empty())

	# The fuse blast: the tell fires on the frame the ring is committed, and a ball inside it is hit.
	var splitter := _spawn(Vector3(2.5, 0.0, 0.0))
	t.eq("spawned as a splitter", String(splitter.kind), "splitter")
	var told := []
	var hits := []
	splitter.special_tell.connect(func(moment: String): told.append([moment, splitter.telegraph() != null]))
	splitter.hit_player.connect(func(amount: float, _shove: Vector3): hits.append(amount))
	for frame in 400:
		game.player.reset_to(ball)
		if not hits.is_empty():
			break
		await physics_frame
	t.check("tells on the committed frame", not told.is_empty() and told[0] == ["tell", true], str(told))
	t.check("the blast hits a ball inside its ring", hits.size() == 1 and is_equal_approx(hits[0], Splitter.BLAST_DAMAGE), str(hits))

	# Rammed at ground level it pops into three light pieces after the seam flare.
	var rammed := await _kill("ram", 2.5)
	t.check("a ram splits it", rammed[0] == true, str(rammed))
	t.eq("a ram leaves three pieces", rammed[1], Splitter.PIECES)
	var pieces := _pieces()
	if not pieces.is_empty():
		var piece = pieces[0]
		t.eq("a piece is a chaser", String(piece.kind), "chaser")
		t.check("a piece is light enough to flail", piece.weight < 1.0, str(piece.weight))
		var full: float = Chaser.HP * game.ctx.root.get_node("World").director.hp_scale()
		t.check("a piece has a share of a chaser's health", is_equal_approx(piece.max_hp, full * Splitter.PIECE_HP / Chaser.HP),
			"%.2f of %.2f" % [piece.max_hp, full])
		t.check("a piece is shrunk", is_equal_approx(piece.radius, 1.0 * Splitter.PIECE_SCALE), str(piece.radius))

	# A close shot splits it too; a stomp, a slam or any hit from 15 m kills it clean.
	var close := await _kill("arc", 6.0)
	t.check("a close shot splits it", close == [true, Splitter.PIECES], str(close))
	for kind in ["stomp", "slam"]:
		var above := await _kill(kind, 2.5)
		t.check("a %s kills it clean" % kind, above == [false, 0], str(above))
	var far := await _kill("arc", Splitter.CLEAN_RANGE + 3.0)
	t.check("a shot from 15 m kills it clean", far == [false, 0], str(far))
	t.check("clean_kill reads range", Splitter.clean_kill("ram", 15.0) and not Splitter.clean_kill("ram", 14.9))

	_clear()
	quit(t.verdict())
