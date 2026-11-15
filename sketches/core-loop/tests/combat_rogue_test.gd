extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const Audio := preload("res://src/presentation/audio.gd")

# The three rogue fleet machines (combat/rogue.gd), each spawned through
# ctx.spawner.spawn_enemy(kind, at) with the ball held 14 m ahead of it. For both of its
# attacks: the shape is committed before it can hurt, and the strike hits the ball exactly
# when the committed shape contains it (damage reads the telegraph's geometry only). The ball
# steps inside the whip's ring and out of the dump's, so each ring outcome is seen; every
# strike opens a vented window where plating is 0, so a small punch lands in full instead of
# chipping 20%. Then each dies with its scrap. Last, the world's rogue director wakes a
# planned rogue when the ball nears its site, and fits it to the site's disc.

const AHEAD := 14.0
const PROBE := 10.0
const STEP_LIMIT := 8.0

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _stage := "setup"
var _clock := 0.0
var _kinds: Array = Rogue.ROWS.keys()
var _kind := ""
var _boss: Node3D
var _anchor := Vector3.ZERO
var _start := Vector3.ZERO
var _spawned := []
var _hits := []
var _kills := []
var _seen := []
var _inside := false
var _hits_before := 0


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
	if _stage == "setup":
		_setup()
		return false
	_clock += delta
	_game.player.reset_to(_anchor)
	var state: String = _boss.state_name() if is_instance_valid(_boss) else "dead"
	match _stage:
		"await_wind":
			if state == "wind":
				var shape: Node3D = _boss.telegraph()
				# Both ring outcomes are exercised: the ball steps into the whip's ring and out
				# of the dump's.
				if _boss.attack == "whip":
					_hold(_boss.global_position + (_anchor - _boss.global_position).normalized() * 5.0)
				elif _boss.attack == "dump":
					_hold(_anchor + (_anchor - _boss.global_position).normalized() * 20.0)
				_inside = shape != null and shape.contains(_anchor)
				_hits_before = _hits.size()
				# Where the ball is held, every shape but the dump's must cover it: a ring that only
				# hurts at its rim, or a lane that misses the ball it aimed at, fails here.
				_report("%s %s committed" % [_kind, _boss.attack], shape != null and _inside == (_boss.attack != "dump"),
					"%s shape committed before its strike, ball inside %s" % [_boss.attack, _inside])
				_next("await_weak")
		"await_weak":
			if state == "weak":
				# Only the rogue's own hits are judged: a stage hazard (a silt boil) that reaches the held
				# ball in the same window says nothing about the rogue's shape.
				var since: Array = _hits.slice(_hits_before)
				var own: int = since.count(_kind)
				# The haul runs its lane out and back, so a ball that stays in the lane is hit on each leg.
				var want := (2 if _boss.attack == "haul" else 1) if _inside else 0
				_report("%s %s honest" % [_kind, _boss.attack], own == want,
					"ball inside %s, own hits %d, want %d (player_hit %s)" % [_inside, own, want, since])
				_seen.append(_boss.attack)
				var before: float = _boss.hp
				_game.ctx.spawner.strike(_boss, "runner", PROBE)
				var weak_drop: float = before - _boss.hp
				_report("%s weak window" % _kind, is_equal_approx(weak_drop, PROBE),
					"a %.0f punch took %.1f hp with the plating off" % [PROBE, weak_drop])
				_next("await_stalk")
		"await_stalk":
			if state == "stalk":
				var before: float = _boss.hp
				_game.ctx.spawner.strike(_boss, "runner", PROBE)
				var chip: float = before - _boss.hp
				_report("%s plated" % _kind, is_equal_approx(chip, PROBE * 0.2),
					"a %.0f punch chipped %.1f hp through plating %.0f" % [PROBE, chip, _boss.plating])
				if _seen.size() < 2:
					_next("await_wind")
				else:
					_next("kill")
		"kill":
			if is_instance_valid(_boss):
				_game.ctx.spawner.strike(_boss, "runner", 9999.0)
			if not _kills.is_empty():
				_report("%s kill" % _kind, _kills[0][0] == _kind and _kills[0][1] == Rogue.SCRAP
						and Audio.is_miniboss(_kind) and Audio.miniboss_tune(_kind) == Rogue.ROWS[_kind].anthem,
					"killed, kind %s, %s scrap; plays its own anthem %s (#389's tune rows)"
						% [_kills[0][0], _kills[0][1], Rogue.ROWS[_kind].anthem])
				_kills.clear()
				if _kinds.is_empty():
					_director()
					return false
				_spawn_next()
				return false
		"director":
			var rogue: Node3D = _game.world.rogue
			if is_instance_valid(rogue):
				_report("director wakes", _game.world.rogue_plan.is_empty() and rogue.kind == "rogue_skip"
						and is_equal_approx(rogue.site_scale, Rogue.SCALE_MIN),
					"the planned rogue woke as %s at scale %.2f for a 20 m disc" % [rogue.kind, rogue.site_scale])
				_game.ctx.calm = true
				rogue.queue_free()
				return _finish()
	if _clock > STEP_LIMIT and _stage != "director":
		_report(_stage, false, "%s timed out in state '%s' after %.1f s" % [_kind, state, _clock])
		return _finish()
	if _clock > STEP_LIMIT and _stage == "director":
		_report("director wakes", false, "no rogue after %.1f s" % _clock)
		return _finish()
	return false


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.player.source = _source
	_game.events.enemy_spawned.connect(func(_enemy: Node3D, kind: String): _spawned.append(kind))
	_game.events.player_hit.connect(func(_amount: float, source: String): _hits.append(source))
	_game.events.enemy_killed.connect(func(kind: String, _at: Vector3, scrap: int): _kills.append([kind, scrap]))
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(99999.0)
	var spawn: Vector3 = ctx.terrain.spawn_point(1)
	_anchor = Vector3(spawn.x, ctx.terrain.height(spawn.x, spawn.z) + 1.05, spawn.z)
	_start = _anchor
	_game.player.reset_to(_anchor)
	_game.player.body().global_position = _anchor
	_game.camera.snap(ctx.terrain.entry_heading(1), -0.1)
	_spawn_next()


func _spawn_next() -> void:
	var ctx = _game.ctx
	_kind = String(_kinds.pop_front())
	_hold(_start)
	_seen.clear()
	_spawned.clear()
	var ahead: Vector3 = _anchor + ctx.terrain.entry_heading(1) * AHEAD
	_boss = ctx.spawner.spawn_enemy(_kind, ctx.terrain.drop_point(ahead.x, ahead.z, float(Rogue.ROWS[_kind].half_height) + 0.2))
	_report("%s spawn" % _kind, _spawned == [_kind] and _boss.kind == _kind and _boss.hp > 0.0 and _boss.plating > 0.0,
		"spawn_enemy published %s with %.0f hp, plating %.0f" % [_spawned, _boss.hp, _boss.plating])
	_next("await_wind")


func _hold(at: Vector3) -> void:
	at.y = _game.ctx.terrain.height(at.x, at.z) + 1.05
	_anchor = at
	_game.player.reset_to(_anchor)


func _director() -> void:
	var at := Vector2(_anchor.x, _anchor.z) + Vector2(10.0, 0.0)
	_game.world.rogue_plan = {"kind": "rogue_skip", "site": "test", "at": at, "radius_m": 20.0, "trigger_m": 45.0}
	_game.ctx.calm = false
	_next("director")


func _next(stage: String) -> void:
	_stage = stage
	_clock = 0.0


func _finish() -> bool:
	var ok := _failures == 0
	print("combat_rogue_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
