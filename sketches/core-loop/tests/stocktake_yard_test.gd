# smoke: solo (two gates run at wall pace)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SurvivalCount := preload("res://src/world/survival_count.gd")
const Parts := preload("res://src/build/parts.gd")
const Palette := preload("res://src/core/palette.gd")

# The Stocktake yard on the dam (BACKLOG W1-101): survival_count.gd's rule stood on the map by activities.gd.
# (a) with the launch flag off the dam plans no yard; with it on it plans one of the park's two yard rows;
# (b) the flag builds one yard site, on that row's ground;
# (c) rolling in starts count 1, its machines climb in one at a time, and the gate stays shut until every one of
#     them has arrived and fallen;
# (d) a cleared floor opens the gate and the ring turns the live colour; staying through it brings count 2's
#     machines and the ring turns back; a floor cleared with the ball outside the ring banks nothing;
# (e) rolling in and out through the open gate after count 2 ends the yard won and pays exactly pay(2): its
#     scrap, and one part of the listed grade on a pickup in the ball's path;
# (f) a fresh yard left with the gate shut forfeits after out_s and pays nothing;
# (g) a ball destroyed inside forfeits a fresh yard;
# (h) a machine spawned at twice the health scale has twice the health of the same machine spawned plain.

const SEED := 23
const EXPECTED_CHECKS := 14

var _game
var _t := preload("res://tests/support/t.gd").new("stocktake_yard_test")
var _source := Intent.Scripted.new()
var _ended := []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _acts():
	return _game.world.activities


func _site():
	return _acts().site("stocktake_yard")


func _hold(at: Vector3) -> void:
	_game.player.reset_to(at, Vector3.ZERO)
	_game.player.set_velocity_now(Vector3.ZERO)
	await physics_frame


func _kill(s) -> void:
	for enemy in s.pack:
		if is_instance_valid(enemy):
			enemy.take_damage(100000.0)


func _ring_color(s) -> Color:
	return ((s.view.ring.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D).albedo_color


func _centre(s) -> Vector3:
	return _game.ctx.terrain.drop_point(s.global_position.x, s.global_position.z, 1.05)


func _outside(s) -> Vector3:
	return _game.ctx.terrain.drop_point(s.global_position.x + float(s.rule["ring"]) + 6.0, s.global_position.z, 1.05)


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.rng.seed = SEED
	_game.player.source = _source
	_game.events.event_ended.connect(func(id: String, outcome: String): if id == "stocktake_yard": _ended.append(outcome))
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	await _frames(4)
	var map = _game.ctx.terrain.map()
	_t.check("flag off: no yard is planned or built", _acts().yard_spec(map).is_empty() and _site() == null, str(_acts().yard_spec(map)))
	_game.ctx.tuning.set_option("stocktake", "on")
	var spec: Dictionary = _acts().yard_spec(map)
	_t.check("flag on: one of the dam's yard rows is drawn", spec.get("row", "") in ["shelf_yard", "slot_yard"], str(spec))
	await _fresh()
	await _counts(spec)
	await _fresh()
	await _walks_out()
	await _fresh()
	await _destroyed()
	_health()
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	_game.free()
	await _frames(2)
	quit(_t.verdict())


func _fresh() -> void:
	_game.flow.enter_stage(1, Vector3.ZERO, false)
	await _frames(4)


func _counts(spec: Dictionary) -> void:
	var s = _site()
	var at_row: bool = s != null and Vector2(s.global_position.x, s.global_position.z).distance_to(spec["at"]) < 0.01
	_t.check("the flag builds one yard on its row's ground", at_row and s.yard != null, "no site" if s == null else str(s.global_position))
	if s == null:
		return
	var rule = s.yard
	var first: Array = rule.pack(1)
	var early_gate := false
	var peak_new := 0
	var seen := {}
	for frame in int((float(s.rule["arrive_s"]) * first.size() + 0.5) * Engine.physics_ticks_per_second):
		await _hold(_centre(s))
		var fresh := 0
		for enemy in s.pack:
			if is_instance_valid(enemy) and not seen.has(enemy.get_instance_id()):
				seen[enemy.get_instance_id()] = true
				fresh += 1
		peak_new = maxi(peak_new, fresh)
		early_gate = early_gate or (rule.gate_open and seen.size() < first.size())
		# Each arrival falls the frame it lands, so the floor is empty while machines are still owed.
		_kill(s)
	_t.check("rolling in starts count 1 and its machines climb in one at a time", s.started and seen.size() == first.size() and peak_new == 1,
		"started %s arrived %d of %d, most in one frame %d" % [s.started, seen.size(), first.size(), peak_new])
	_t.check("the gate stays shut while machines are still owed", not early_gate, "")
	await _hold(_centre(s))
	_t.check("a cleared floor opens the gate and the ring turns the live colour", rule.gate_open and rule.cleared == 1 and _ring_color(s) == Palette.live(),
		"gate %s cleared %d ring %s" % [rule.gate_open, rule.cleared, _ring_color(s)])
	for frame in int((float(rule.rule["gate_s"]) + float(s.rule["arrive_s"]) * rule.pack(2).size() + 0.5) * Engine.physics_ticks_per_second):
		await _hold(_centre(s))
	_t.check("staying through the gate brings count 2's machines", rule.count == 2 and not rule.gate_open
		and _acts().yard_standing(s) == rule.pack(2).size() and s.yard_owed.is_empty() and _ring_color(s) != Palette.live(),
		"count %d standing %d" % [rule.count, _acts().yard_standing(s)])
	# The last machine falls with the ball outside the ring: the gate opens, and nothing is banked for it.
	await _hold(_outside(s))
	_kill(s)
	await _hold(_outside(s))
	await _hold(_outside(s))
	_t.check("a floor cleared from outside opens the gate and banks nothing", rule.gate_open and not s.done and _ended.is_empty(), "gate %s done %s" % [rule.gate_open, s.done])
	await _hold(_centre(s))
	var scrap_before: int = _game.run.scrap
	var parts_before: Array = _game.run.parts.duplicate()
	await _hold(_outside(s))
	var pay: Dictionary = SurvivalCount.new().pay(2)
	var pickup_at: Vector3 = s.pickup.global_position if s.pickup != null else Vector3.INF
	for frame in 40:
		await _hold(pickup_at + Vector3(0.0, 1.05, 0.0))
		if s.pickup_taken:
			break
	var gained: Array = _game.run.parts.slice(parts_before.size())
	var grades: Array = gained.map(func(part): return Parts.rarity_of(part))
	_t.check("leaving through the open gate ends the yard won", _ended == ["won"] and s.done, str(_ended))
	_t.check("it pays exactly pay(2): the scrap and each listed part grade", _game.run.scrap - scrap_before == int(pay["scrap"]) and grades == pay["rarities"],
		"scrap %d of %d, grades %s of %s" % [_game.run.scrap - scrap_before, pay["scrap"], grades, pay["rarities"]])


func _walks_out() -> void:
	var s = _site()
	if s == null:
		_t.check("a yard left with the gate shut forfeits", false, "no site")
		return
	_ended.clear()
	await _hold(_centre(s))
	var scrap_before: int = _game.run.scrap
	var short := int((float(s.rule["out_s"]) - 0.5) * Engine.physics_ticks_per_second)
	for frame in short:
		await _hold(_outside(s))
	var held: bool = not s.done
	for frame in Engine.physics_ticks_per_second:
		await _hold(_outside(s))
	_t.check("a yard left with the gate shut forfeits after out_s and pays nothing", held and s.done and _ended == ["lost"]
		and s.pickup == null and _game.run.scrap == scrap_before, "held %s done %s ended %s" % [held, s.done, _ended])
	_kill(s)


func _destroyed() -> void:
	var s = _site()
	if s == null:
		_t.check("a ball destroyed inside forfeits", false, "no site")
		return
	_ended.clear()
	await _hold(_centre(s))
	_game.events.player_died.emit()
	_t.check("a ball destroyed inside forfeits the yard", s.started and s.done and _ended == ["lost"] and s.pickup == null, "done %s ended %s" % [s.done, _ended])
	_kill(s)


func _health() -> void:
	var s = _site()
	var at: Vector3 = _outside(s)
	var plain = _game.ctx.spawner.spawn_enemy("chaser", at)
	var strong = _game.ctx.spawner.spawn_enemy("chaser", at + Vector3(4.0, 0.0, 0.0), "", Vector3.INF, 2.0)
	_t.near("twice the health scale is twice the health", strong.max_hp, plain.max_hp * 2.0, 0.01)
	plain.queue_free()
	strong.queue_free()
