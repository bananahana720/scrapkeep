extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Claw := preload("res://src/combat/tarn_claw.gd")
const T := preload("res://tests/support/t.gd")

# PC-TARN, 2026-10-11. Expected: 32 checks, including the count assertion.
# Real game, router and CharacterBody3D collision motion; scripted calm shelf, no AI attacks.
const DT := 1.0 / 60.0
const SHELF := Vector3(-45.0, 122.0, 6.0)
var _t := T.new("tarn_claw_drag_test")
var _expected_checks := 32
var _game
var _player
var _combat
var _claw
var _source := Intent.Scripted.new()
var _struck: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _boot() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	var def: Resource = ClassDef.by_id("tarn")
	_game.run.class_def = def
	_player.fit_class(def)
	await _sim(0.6)
	_claw = _combat.get_node("TarnClaw")
	_player.set_physics_process(false)
	_combat.set_physics_process(false)
	_claw.set_physics_process(false)
	_combat.ultimate.set_physics_process(false)
	_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, force: float): _struck.append([enemy.get_instance_id(), kind, force]))
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	collision.shape = box
	floor_body.add_child(collision)
	_game.add_child(floor_body)
	floor_body.global_position = Vector3(-45.0, 119.5, 6.0)
	await _fresh()


func _never() -> bool:
	return false


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _fresh() -> void:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.queue_free()
	_claw._clear()
	_claw._cards.clear()
	_claw._dragged.clear()
	_claw._holds = 0
	_combat.ultimate._phase = "idle"
	_combat.ultimate.meter.locked = false
	_player.kit.drop_line("reset")
	_player.kit.rewind_left = 0.0
	_player.chain.reset()
	_player.abilities.refill()
	_player.abilities.snap_back("test")
	_player._fire_latched = false
	_combat._line_load = {}
	_combat._bite_pending = false
	_combat._clamped.clear()
	_struck.clear()
	_game.run.mass = 0.0
	_game.run.parts.clear()
	_game.run._heft_class = 1
	_player.body().freeze = true
	_player.reset_to(SHELF)
	await physics_frame
	await physics_frame


func _enemy(kind: String, dx: float, dz := 0.0) -> Node3D:
	var ball: Vector3 = _player.ball_position()
	var enemy: Node3D = _combat.spawn_enemy(kind, ball + Vector3(dx, 0.0, dz))
	enemy.global_position = ball + Vector3(dx, 0.0, dz)
	if enemy.get("live") != null:
		enemy.live = _never
	if enemy.get("hp") != null:
		enemy.hp = 10000.0
		enemy.max_hp = 10000.0
	enemy.set_physics_process(true)
	return enemy


func _tick(fields := {}, dt := DT) -> void:
	_player.intent.clear()
	for key in fields:
		_player.intent.set(key, fields[key])
	_player._route_slots(dt)
	_combat._step_line(_player.intent, dt)


func _cast(target: Node3D = null, anchor := Vector3.ZERO) -> void:
	if target != null:
		_player.grapple_to(target.global_position, Vector3.UP, target)
	elif anchor != Vector3.ZERO:
		_player.grapple_to(anchor, Vector3.LEFT, null)
	_tick({"slot_pick": 2, "fire_pressed": true, "fire_held": true})
	_tick({"fire_released": true}, 0.0)


func _drag_for(seconds: float) -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		_claw.step(dt)
		await physics_frame


func _hits(enemy: Node3D) -> Array:
	return _struck.filter(func(row): return row[0] == enemy.get_instance_id())


func _finish() -> void:
	_t.eq("expected check count", _t.checks + 1, _expected_checks)
	_game.free()
	quit(_t.verdict())


func _run() -> void:
	await _boot()
	_t.eq("slot 3 is Claw Drag", _player.abilities.id_of("line"), "claw_drag")
	_t.eq("drag is a tap", _player.abilities.gauge("line"), null)
	_t.eq("tow weights I to V", range(1, 6).map(func(c): return Claw.tow_limit(c)), [1.5, 2.0, 2.5, 3.0, 3.5])
	var a := _enemy("chaser", 20.0)
	_cast(a)
	var links: int = _player.chain.links
	_t.near("committed body half width", float(_player.indicator.shapes["tarn_drag"]["width"]) / 2.0, 1.0)
	await _drag_for(0.9)
	_t.check("20m chaser arrives inside 3.5m within 1s", a.global_position.distance_to(_player.ball_position()) <= 3.5, str(a.global_position.distance_to(_player.ball_position())))
	_t.eq("one 14 damage arrival hit", _hits(a).map(func(row): return row[2]), [14.0])
	_t.near("arrival mark lasts 2.5s", float(_combat._clamped.get(a.get_instance_id(), -100.0)) - _combat._clock, 2.5)
	_t.eq("drag adds no chain link", _player.chain.links, links)
	_struck.clear()
	_combat._on_bolt_hit({"kind": "claw", "damage": 32.0, "dir": Vector3.RIGHT, "knock": 0.0, "chain_jumps": 0, "color": Color.WHITE}, a, a.global_position)
	_t.near("next sweep gets x1.5", float(_hits(a)[0][2]), 48.0)

	await _fresh()
	a = _enemy("chaser", 20.0)
	for i in 3:
		_player.chain.link(true, false)
	var multiplier: float = _player.chain.multiplier()
	_cast(a)
	multiplier = _player.chain.multiplier()
	await _drag_for(0.9)
	_t.near("drag damage uses chain at fire", float(_hits(a)[0][2]) if not _hits(a).is_empty() else -1.0, 14.0 * multiplier)

	await _fresh()
	var heavy := _enemy("lobber", 20.0)
	var before := heavy.global_position
	_player.body().linear_velocity = Vector3.ZERO
	_cast(heavy)
	_t.eq("class I leaves a lobber unmoved", heavy.global_position, before)
	_t.near("class I reel burst toward lobber", _player.body().linear_velocity.dot((before - _player.ball_position()).normalized()), 8.0, 0.01)
	_t.near("heavy bite mark lasts 2.5s", float(_combat._clamped[heavy.get_instance_id()]) - _combat._clock, 2.5)
	_t.eq("heavy bite deals 14", _hits(heavy).map(func(row): return row[2]), [14.0])
	await _fresh()
	_game.run.mass = (3.3 - 1.0) * 450.0
	heavy = _enemy("lobber", 20.0)
	_t.eq("fixture is heft class IV", _game.run.heft_class(), 4)
	_cast(heavy)
	await _drag_for(0.9)
	_t.check("class IV drags the lobber", heavy.global_position.distance_to(_player.ball_position()) <= 3.5, str(heavy.global_position.distance_to(_player.ball_position())))

	await _fresh()
	a = _enemy("chaser", 20.0)
	_cast(a)
	await _drag_for(0.3)
	_player.cut_line("enemy")
	_claw.step(0.0)
	_t.check("line cut stops that tick", _claw.drag.is_empty())
	_t.check("cut leaves body momentum", a._knock.length() > 1.0)
	await _drag_for(0.8)
	_t.eq("cut leaves no clamp mark", _combat._clamped.has(a.get_instance_id()), false)
	_t.eq("cut leaves no arrival hit", _hits(a), [])

	await _fresh()
	var inside := _enemy("chaser", 10.0, 1.0)
	var outside := _enemy("chaser", 10.0, 2.0)
	_player.body().linear_velocity = Vector3.ZERO
	_cast(null, _player.ball_position() + Vector3.RIGHT * 20.0)
	_t.near("slab drawing half width is 1.2m", float(_player.indicator.shapes["tarn_drag"]["width"]) / 2.0, 1.2)
	await _drag_for(0.9)
	_t.eq("slab hits 1m off line", _hits(inside).map(func(row): return row[2]), [16.0])
	_t.eq("slab misses 2m off line", _hits(outside), [])
	_t.near("world slab leaves ball at rest", _player.body().linear_velocity.length(), 0.0)

	await _fresh()
	a = _enemy("chaser", 20.0)
	_cast()
	_tick({}, 3.99)
	_t.check("load survives 3.99s", not _combat.line_load().is_empty())
	_player.grapple_to(a.global_position, Vector3.UP, a)
	_tick({}, 0.0)
	_t.check("bite at 3.99s starts drag", not _claw.drag.is_empty())
	await _fresh()
	_cast()
	_tick({}, 4.01)
	_t.eq("load expires at 4.01s", _combat.line_load(), {})
	a = _enemy("chaser", 20.0)
	_player.grapple_to(a.global_position, Vector3.UP, a)
	_tick({}, 0.0)
	_t.check("late bite carries no drag", _claw.drag.is_empty())

	await _fresh()
	var warden := _enemy("warden", 20.0)
	warden.set_physics_process(false)
	before = warden.global_position
	var posture: float = warden.posture()
	var gun_gain: float = warden.judge_hit("runner", 14.0, false, 0)["gain"]
	_cast(warden)
	_t.eq("Warden never moves", warden.global_position, before)
	_t.eq("Warden gets no mark", _combat._clamped.has(warden.get_instance_id()), false)
	_t.near("Warden gets gun-bolt posture", warden.posture() - posture, gun_gain)
	_finish()
