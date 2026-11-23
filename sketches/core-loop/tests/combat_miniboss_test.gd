extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Miniboss := preload("res://src/combat/miniboss.gd")

# The miniboss an event spawns through ctx.spawner.spawn_enemy("miniboss", at): it
# spawns, commits a slam ring on the ball and lands it, opens a weak window where its
# plating drops to 0 (a small punch lands in full instead of chipping 20%), commits a charge lane that misses a ball
# moved off the lane (damage reads only the telegraph's geometry), and dies to the
# runner's laser with its scrap. The ball is held in place, so every hit is the
# boss's committed geometry and not the ball's momentum.

const AHEAD := 14.0
const PROBE := 10.0
const STEP_LIMIT := 5.0
const KILL_LIMIT := 40.0

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _stage := "setup"
var _clock := 0.0
var _boss: Node3D
var _anchor := Vector3.ZERO
var _spawned := []
var _hits := []
var _kills := []
var _weak_strikes := 0
var _armour_drop := 0.0
var _weak_drop := 0.0


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
	var boss_state: String = _boss.state_name() if is_instance_valid(_boss) else "dead"
	match _stage:
		"await_slam":
			if boss_state == "slam_crouch":
				var ring: Node3D = _boss.telegraph()
				_report("slam_telegraph", ring != null and ring.contains(_game.player.ball_position()),
					"slam ring committed on the ball after %.2f s, radius %.1f m" % [_clock, ring.radius if ring != null else 0.0])
				_next("await_weak")
		"await_weak":
			if _boss.is_weak():
				_report("slam_hit", _hits.size() == 1 and _hits[0] == "miniboss",
					"the ring landed on the ball it contained: player_hit %s" % [_hits])
				var before: float = _boss.hp
				_game.ctx.spawner.strike(_boss, "runner", PROBE)
				_weak_drop = before - _boss.hp
				_next("await_stalk")
		"await_stalk":
			if boss_state == "stalk":
				var before: float = _boss.hp
				_game.ctx.spawner.strike(_boss, "runner", PROBE)
				_armour_drop = before - _boss.hp
				_report("weak_window", is_equal_approx(_weak_drop, PROBE) and is_equal_approx(_armour_drop, PROBE * 0.2),
					"a %.0f-punch hit took %.1f hp in the weak window (plating 0) and %.1f through plating %.0f (20%% chip)"
						% [PROBE, _weak_drop, _armour_drop, _boss.plating])
				_next("await_charge")
		"await_charge":
			if boss_state == "charge_brace":
				var lane: Node3D = _boss.telegraph()
				var side: Vector3 = lane.dir.cross(Vector3.UP).normalized()
				var moved: Vector3 = _anchor + side * (lane.width + 8.0)
				moved.y = _game.ctx.terrain.height(moved.x, moved.z) + 1.05
				_report("charge_telegraph", lane != null and lane.contains(_anchor) and not lane.contains(moved),
					"charge lane committed %.0f m long, %.1f m wide; the ball is moved %.1f m off it" % [lane.length, lane.width, lane.width + 8.0])
				_anchor = moved
				_next("await_second_weak")
		"await_second_weak":
			if _boss.is_weak():
				_report("charge_dodged", _hits.size() == 1,
					"the charge ran its lane and missed the ball outside it: player_hit still %s" % [_hits])
				_source.press = {"fire_pressed": true}
				_next("kill")
		"kill":
			if is_instance_valid(_boss):
				_aim_at(_boss.global_position + Vector3.UP * 0.6)
			var snap: Dictionary = _game.ctx.spawner.weapon_driver.state_snapshot()
			if bool(snap.get("reloading", false)):
				if bool(snap.get("window_open", false)):
					_source.press = {"fire_pressed": true}
			elif bool(snap.get("ready", false)):
				_source.press = {"fire_pressed": true}
			if not _kills.is_empty():
				_report("kill", _kills[0][0] == "miniboss" and _kills[0][1] == Miniboss.SCRAP,
					"miniboss killed %.1f s into held fire, drop %s scrap, %d strikes landed in weak windows"
						% [_clock, _kills[0][1], _weak_strikes])
				return _finish()
			if _clock > KILL_LIMIT:
				_report("kill", false, "miniboss still alive with %.0f hp after %.0f s" % [_boss.hp, KILL_LIMIT])
				return _finish()
			return false
	if _clock > STEP_LIMIT and _stage != "kill":
		_report(_stage, false, "timed out in boss state '%s' after %.1f s" % [boss_state, _clock])
		return _finish()
	return false


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.player.source = _source
	_game.events.enemy_spawned.connect(func(_enemy: Node3D, kind: String): _spawned.append(kind))
	_game.events.player_hit.connect(func(_amount: float, source: String): _hits.append(source))
	_game.events.enemy_killed.connect(func(kind: String, _at: Vector3, scrap: int): _kills.append([kind, scrap]))
	_game.events.enemy_struck.connect(func(enemy: Node3D, _kind: String, _force: float):
		if enemy == _boss and _boss.is_weak():
			_weak_strikes += 1)
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(99999.0)
	var heading: Vector3 = ctx.terrain.entry_heading(1)
	var spawn: Vector3 = ctx.terrain.spawn_point(1)
	_anchor = Vector3(spawn.x, ctx.terrain.height(spawn.x, spawn.z) + 1.05, spawn.z)
	_game.player.reset_to(_anchor)
	_game.player.body().global_position = _anchor
	_game.camera.snap(heading, -0.1)
	var ahead: Vector3 = _anchor + heading * AHEAD
	_boss = ctx.spawner.spawn_enemy("miniboss", ctx.terrain.drop_point(ahead.x, ahead.z, Miniboss.HALF_HEIGHT + 0.2))
	_report("spawn", _spawned == ["miniboss"] and _boss.is_in_group("enemy") and _boss.hp > 0.0,
		"spawn_enemy('miniboss') published enemy_spawned %s with %.0f hp" % [_spawned, _boss.hp])
	_next("await_slam")


func _next(stage: String) -> void:
	_stage = stage
	_clock = 0.0


func _aim_at(point: Vector3) -> void:
	var cam = _game.camera
	var d: Vector3 = (point - cam.aim_origin()).normalized()
	cam.yaw = atan2(-d.x, -d.z)
	cam.pitch = clampf(asin(d.y), -1.25, 0.55)


func _finish() -> bool:
	_source.hold = {}
	var ok := _failures == 0
	print("combat_miniboss_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
