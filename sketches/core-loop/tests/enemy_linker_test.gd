extends SceneTree

const Game := preload("res://src/game.gd")
const Roster := preload("res://src/combat/roster.gd")
const Linker := preload("res://src/combat/linker.gd")

# The Linker (src/combat/linker.gd; ENEMY-PRIORITY.md 4 lever 7c), against a ball at rest in a
# calm stage 1:
# - it links the heaviest enemy in reach, walks to the seat behind it and braces: special_tell
#   "tell" fires on the brace frame, once, and it never warns, holds or takes an attack slot;
# - braced, a hit from the ball's side deals nothing and publishes strike_deflected; a stomp
#   over the top lands, and so does a hit from behind before the dish has turned round;
# - a bolt on the cable cuts it for good and the partner takes hits again;
# - a harpoon bite on a second Linker cuts its cable too; a Linker whose partner dies links
#   the next one; a dead Linker leaves nothing guarded.

const TICK := 1.0 / 60.0
const LIMIT := 10.0

var _game
var _combat
var _failures := 0
var _step := 0
var _clock := 0.0
var _ball_at := Vector3.ZERO
var _held := Vector3.ZERO
var _brute: Node3D
var _lobber: Node3D
var _linker: Node3D
var _tells: Array = []
var _deflected := 0
var _warned_ever := false
var _second: Node3D
var _drill: Node3D


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_clock += delta
	# The ball stays at rest where the test put it: world 1's chasers run 9 m/s since wave 37
	# (ChallengeDials.CHASER_SPEED_W1, ruling cu), so a chaser reaches a still ball and lunges it
	# downhill, and the partner then walks after it faster than a Linker can seat.
	if _step > 0:
		_game.player.reset_to(_held)
	if is_instance_valid(_linker) and (_linker.telegraph() != null or _linker.warned > 0):
		_warned_ever = true
	match _step:
		0:
			_setup()
		1:
			if _linker.braced or _clock > LIMIT:
				_check_brace()
		2:
			_check_guard()
		3:
			# Behind the partner: the dish still faces where the ball was.
			if _clock > 0.05:
				_check_flank()
		4:
			if _clock > 2.5:
				_check_turned()
		5:
			_check_cut()
		6:
			if _linker.braced or _clock > LIMIT:
				_check_harpoon()
		7:
			if (_linker.partner == _lobber and _linker.braced) or _clock > LIMIT:
				_check_relink()
		8:
			if (_linker.braced and _second.braced) or _clock > LIMIT:
				_check_one_per_partner()
		9:
			if _clock > 0.5:
				_check_freed_partner()
		10:
			return _finish()
	return false


func _next() -> void:
	_step += 1
	_clock = 0.0


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_combat = ctx.spawner
	_ball_at = ctx.terrain.drop_point(ctx.terrain.spawn_point(1).x, ctx.terrain.spawn_point(1).z, 1.05)
	_place(_ball_at)
	_brute = _spawn("plated_brute", Vector3(10.0, 0.0, 0.0))
	_spawn("chaser", Vector3(8.0, 0.0, -9.0))
	_linker = _spawn("linker", Vector3(16.0, 0.0, 5.0))
	_linker.special_tell.connect(func(moment: String): _tells.append(moment))
	_game.events.strike_deflected.connect(func(enemy: Node3D, _kind: String, _punch: float, _plating: float):
		if enemy == _brute:
			_deflected += 1)
	_report("linker row", Roster.has("linker") and Roster.built("linker") and _combat.fleet.makes("linker")
		and Roster.chassis_problems(Roster.row("linker")).is_empty(), "roster row built, chassis %s" % [Roster.chassis_problems(Roster.row("linker"))])
	_next()


func _place(at: Vector3) -> void:
	_held = at
	_game.player.reset_to(at)


func _spawn(kind: String, offset: Vector3) -> Node3D:
	var at: Vector3 = _ball_at + offset
	return _combat.spawn_enemy(kind, _game.ctx.terrain.drop_point(at.x, at.z, 1.8))


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _check_brace() -> void:
	var from_ball := _flat(_linker.global_position - _ball_at).length()
	var brute_from_ball := _flat(_brute.global_position - _ball_at).length()
	_report("links the heaviest", _linker.partner == _brute, "partner %s" % [_linker.partner.get("kind") if _linker.partner != null else "none"])
	_report("braces", _linker.braced and _tells == ["tell"], "braced %s in %.2f s, tells %s" % [_linker.braced, _clock, _tells])
	_report("seat behind its partner", from_ball > brute_from_ball + 2.0,
		"linker %.1f m from the ball, partner %.1f m" % [from_ball, brute_from_ball])
	_next()


func _strike(enemy: Node3D, kind: String, force: float, part := "") -> float:
	var before: float = enemy.hp
	_combat.strike(enemy, kind, force, part)
	return before - float(enemy.hp)


func _check_guard() -> void:
	_place(_ball_at)
	var deflected := _deflected
	var bolt := _strike(_brute, "bolt", 40.0)
	var ram := _strike(_brute, "ram", 20.0)
	_report("dish blocks the front", bolt == 0.0 and ram == 0.0 and _deflected == deflected + 2,
		"bolt removed %.1f, ram removed %.1f, deflected %d" % [bolt, ram, _deflected - deflected])
	# The stomp's punch (52 at heft 1.0) sits just under the brute's plating (54), and the scrap
	# the ball has rolled over by now moves heft a few percent either way. Over the plating the
	# hit pops the brute's plate and removes nothing: that landed too. A stomp the dish took
	# would do neither.
	var plates: int = _brute.plates
	var stomp := _strike(_brute, "stomp", 20.0)
	_report("over the top lands", stomp > 0.0 or _brute.plates < plates,
		"stomp removed %.1f, plates %d to %d" % [stomp, plates, _brute.plates])
	var behind: Vector3 = _brute.global_position + (_brute.global_position - _ball_at).normalized() * 9.0
	_place(_game.ctx.terrain.drop_point(behind.x, behind.z, 1.05))
	_next()


func _check_flank() -> void:
	var dealt := _strike(_brute, "bolt", 40.0)
	_report("behind the dish lands", dealt > 0.0, "bolt from behind removed %.1f (dish %.0f deg off the ball)" % [dealt, _dish_off()])
	_next()


func _check_turned() -> void:
	var dealt := _strike(_brute, "bolt", 40.0)
	_report("dish turns to the ball", dealt == 0.0 and _dish_off() < 10.0, "removed %.1f, dish %.0f deg off" % [dealt, _dish_off()])
	_next()


func _dish_off() -> float:
	var to_ball: Vector3 = _flat(_game.player.ball_position() - _brute.global_position).normalized()
	return rad_to_deg(acos(clampf(to_ball.dot(_linker.dish_dir()), -1.0, 1.0)))


func _check_cut() -> void:
	var linker_hp: float = _linker.hp
	_strike(_linker, "bolt", 5.0, "cable")
	var dealt := _strike(_brute, "bolt", 40.0)
	_report("bolt cuts the cable", _linker.cut and _linker.cut_by == "struck" and not _linker.braced
		and _combat.guard_of(_brute) == null and dealt > 0.0 and _tells.has("cut"),
		"cut %s by %s, partner took %.1f, linker hp %.0f to %.0f" % [_linker.cut, _linker.cut_by, dealt, linker_hp, _linker.hp])
	_report("cable has a weak point until cut", _linker.weak_points().is_empty(), "%d weak points after the cut" % _linker.weak_points().size())
	_linker.take_damage(99999.0)
	_place(_ball_at)
	_lobber = _spawn("lobber", Vector3(-12.0, 0.0, 4.0))
	_linker = _spawn("linker", Vector3(-18.0, 0.0, 7.0))
	_tells = []
	_linker.special_tell.connect(func(moment: String): _tells.append(moment))
	_next()


func _check_harpoon() -> void:
	var partner = _linker.partner
	_report("second linker braces", _linker.braced, "partner %s" % [partner.get("kind") if partner != null else "none"])
	_game.events.harpoon_bit.emit(_linker, _linker.global_position)
	_report("harpoon bite cuts the cable", _linker.cut and _linker.cut_by == "harpoon" and _combat.guard_of(partner) == null,
		"cut %s by %s" % [_linker.cut, _linker.cut_by])
	_linker.take_damage(99999.0)
	# A fresh Linker on the brute, then the brute dies: it links the lobber next.
	_linker = _spawn("linker", Vector3(0.0, 0.0, 2.0))
	_brute.take_damage(99999.0)
	_next()


func _check_relink() -> void:
	_report("relinks when its partner dies", _linker.partner == _lobber and _linker.braced and _combat.guard_of(_lobber) == _linker,
		"partner %s braced %s in %.1f s" % [_linker.partner.get("kind") if _linker.partner != null else "none", _linker.braced, _clock])
	_linker.take_damage(99999.0)
	_report("a dead linker guards nothing", _combat.guard_of(_lobber) == null and _combat._guards.is_empty(),
		"%d guards left" % _combat._guards.size())
	_report("never warns or attacks", not _warned_ever, "a telegraph seen: %s" % _warned_ever)
	# Two Linkers beside one heavy partner and one light one: only one may hold the heavy one.
	_place(_ball_at)
	_drill = _spawn("plated_brute", Vector3(0.0, 0.0, 12.0))
	_spawn("chaser", Vector3(6.0, 0.0, 14.0))
	_linker = _spawn("linker", Vector3(3.0, 0.0, 16.0))
	_second = _spawn("linker", Vector3(-3.0, 0.0, 16.0))
	_next()


func _check_one_per_partner() -> void:
	var on_brute := [_linker, _second].filter(func(l): return l.partner == _drill)
	var other: Node3D = _second if _linker.partner == _drill else _linker
	_report("one linker per partner", on_brute.size() == 1 and _combat.guard_holder(_drill) == on_brute[0]
		and other.partner != _drill, "%d on the brute, the other holds %s" % [on_brute.size(),
		other.partner.get("kind") if other.partner != null else "nothing"])
	_drill.queue_free()
	_next()


func _check_freed_partner() -> void:
	var holder: Node3D = _linker if _linker.partner == null or not is_instance_valid(_linker.partner) else _second
	var stale := 0
	for id in _combat._guards:
		if not is_instance_valid(instance_from_id(id)):
			stale += 1
	_report("a freed partner leaves no guard", stale == 0, "%d stale guards; holder partner %s" % [stale, holder.partner])
	_next()


func _finish() -> bool:
	var ok := _failures == 0
	print("enemy_linker_test: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
