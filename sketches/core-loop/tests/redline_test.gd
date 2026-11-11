extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Redline := preload("res://src/combat/redline.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")

# Heat on the shell (src/combat/redline.gd, docs/design/loops.md Spec 1). The rule on its own
# (fill, hold, drain, skim, spend, cook-off, the three modes), then the wiring in a real Game:
# the flag is off by default, a hot shell scales a hit at the run's one damage choke point, a
# blast strikes inside its radius and not outside it, and a cook-off takes its share of the hull.
# Evidence limit: the rule and its numbers, not a played run; whether it makes a player stay hot
# is the kill line's question (loops.md "The prototype").

var _failures := 0
var _count := 0
var _game
var _player
var _combat
var _hits: Array = []


func _check(label: String, ok: bool, detail: String) -> void:
	_count += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_rules()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _rules() -> void:
	var r := Redline.new()
	r.tick(1.0, SpeedTier.BLAZING)
	r.skim(SpeedTier.BLAZING)
	_check("off", r.value == 0.0 and r.blazing_s == 0.0 and r.skims == 0 and r.taken_scale() == 1.0,
		"off: value %.1f, blazing %.1f s, skims %d" % [r.value, r.blazing_s, r.skims])
	r.set_mode(Redline.WATCH)
	r.tick(1.0, SpeedTier.BLAZING)
	r.skim(SpeedTier.CRUISE)
	_check("watch counts only", r.value == 0.0 and r.blazing_s == 1.0 and r.rolled_s == 1.0 and r.skims == 1,
		"watch: value %.1f, blazing %.1f s, rolled %.1f s, skims %d" % [r.value, r.blazing_s, r.rolled_s, r.skims])
	r.set_mode(Redline.ON)
	r.reset_counts()
	r.tick(1.0, SpeedTier.BLAZING)
	_check("blazing fills", is_equal_approx(r.value, Redline.FILL_BLAZING_PER_S), "1 s at blazing: %.1f" % r.value)
	r.tick(1.0, SpeedTier.FAST)
	_check("fast holds", is_equal_approx(r.value, Redline.FILL_BLAZING_PER_S), "1 s at fast: %.1f" % r.value)
	r.tick(0.5, SpeedTier.CRUISE)
	_check("cruise drains", is_equal_approx(r.value, Redline.FILL_BLAZING_PER_S - Redline.DRAIN_PER_S * 0.5),
		"0.5 s at cruise: %.1f" % r.value)
	var stall := r.skim(SpeedTier.WALK)
	_check("no skim for the stall", not stall and r.skims == 0, "a skim at walk counted %s" % stall)
	r.skim(SpeedTier.CRUISE)
	r.skim(SpeedTier.CRUISE)
	_check("skims fill and heat", is_equal_approx(r.value, 2.0 + 2.0 * Redline.FILL_SKIM) and r.hot()
			and r.taken_scale() == Redline.HOT_DAMAGE_TAKEN,
		"two skims: %.1f, hot %s, taken x%.2f" % [r.value, r.hot(), r.taken_scale()])
	_check("no spend below redline", r.spend("ram", Vector3.ZERO, 40.0) == 0.0, "a ram at %.1f spent nothing" % r.value)
	var redlined := [0]
	r.redlined.connect(func(): redlined[0] += 1)
	r.skim(SpeedTier.CRUISE)
	r.skim(SpeedTier.CRUISE)
	_check("redline", r.redline() and redlined[0] == 1, "value %.1f, redlined %d" % [r.value, redlined[0]])
	_check("only contacts spend", r.spend("weapon", Vector3.ZERO, 40.0) == 0.0 and r.redline(), "a weapon hit left it at redline")
	var blast := r.spend("ram", Vector3.ZERO, 40.0)
	_check("ram detonates", is_equal_approx(blast, 40.0 * Redline.BLAST_FORCE) and r.value == 0.0 and r.detonations == 1,
		"blast %.1f, value after %.1f" % [blast, r.value])
	var cooked := []
	r.cooked_off.connect(func(_at: Vector3, force: float): cooked.append(force))
	r.value = Redline.MAX
	r.tick(Redline.COOK_OFF_S - 0.1, SpeedTier.CRUISE, Vector3.ZERO, 20.0)
	var waiting := cooked.is_empty() and r.redline()
	r.tick(0.2, SpeedTier.CRUISE, Vector3.ZERO, 20.0)
	_check("cook-off", waiting and cooked.size() == 1 and is_equal_approx(cooked[0], 20.0 * Redline.COOK_OFF_FORCE)
			and r.value == 0.0 and r.cook_offs == 1,
		"held %.1f s then blew at force %s" % [Redline.COOK_OFF_S + 0.1, str(cooked)])


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _never() -> bool:
	return false


func _enemy(offset: Vector3) -> Node3D:
	var ball: Vector3 = _player.ball_position()
	var at: Vector3 = _game.ctx.terrain.drop_point(ball.x + offset.x, ball.z + offset.z, 1.0)
	var enemy: Node3D = _combat.spawn_enemy("chaser", at)
	enemy.live = Callable(self, "_never")
	enemy.hp = 100000.0
	enemy.max_hp = 100000.0
	enemy.plating = 0.0
	return enemy


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_combat = _game.ctx.spawner
	_player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(0.6)
	_player.set_physics_process(false)
	_game.ctx.events.player_hit.connect(func(amount: float, source: String): _hits.append([amount, source]))
	_check("flag off by default", _player.redline.mode == Redline.OFF, "mode %s" % _player.redline.mode)

	var red: Redline = _player.redline
	red.set_mode(Redline.ON)
	_hits.clear()
	_game.ctx.run.damage(10.0, "test")
	red.value = Redline.HOT_AT
	_game.ctx.run.damage(10.0, "test")
	_check("a hot shell takes harder hits", _hits.size() == 2 and is_equal_approx(float(_hits[0][0]), 10.0)
			and is_equal_approx(float(_hits[1][0]), 10.0 * Redline.HOT_DAMAGE_TAKEN) and red.hits_hot == 1,
		"cool hit %s, hot hit %s, hits while hot %d" % [str(_hits[0]) if _hits.size() > 0 else "-",
			str(_hits[1]) if _hits.size() > 1 else "-", red.hits_hot])

	var near := _enemy(Vector3(3.0, 0.0, 0.0))
	var far := _enemy(Vector3(0.0, 0.0, Redline.BLAST_RADIUS + 4.0))
	var near_before: float = near.hp
	var far_before: float = far.hp
	red.value = Redline.MAX
	var blasts := []
	red.detonated.connect(func(at: Vector3, force: float): blasts.append(force))
	# The ball stands where the test left it, in the air; the blast's centre is on the ground under it.
	var centre := Vector3(_player.ball_position().x, near.global_position.y, _player.ball_position().z)
	_player._redline_blast(centre, red.spend("ram", centre, 40.0))
	_check("the blast strikes inside its radius only", near.hp < near_before and is_equal_approx(far.hp, far_before)
			and blasts.size() == 1 and red.value == 0.0,
		"near lost %.1f, far lost %.1f, blasts %d" % [near_before - near.hp, far_before - far.hp, blasts.size()])

	_hits.clear()
	red.value = Redline.MAX
	red.tick(Redline.COOK_OFF_S + 0.1, SpeedTier.CRUISE, _player.ball_position(), 20.0)
	var cook: Array = _hits.filter(func(h: Array): return h[1] == Redline.COOK_OFF_SOURCE)
	_check("a cook-off takes its share of the hull", cook.size() == 1
			and is_equal_approx(float(cook[0][0]), _game.ctx.run.max_hp * Redline.COOK_OFF_SELF_HULL),
		"cook-off hits %s, max hull %.1f" % [str(cook), _game.ctx.run.max_hp])

	near.queue_free()
	far.queue_free()
	print("redline_test: %d checks, %d failures" % [_count, _failures])
	quit(1 if _failures > 0 else 0)
