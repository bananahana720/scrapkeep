extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Augments := preload("res://src/movement/augments.gd")

const PILOTS := {"sable": "pylon_engineer", "rivet": "runner_gunner", "kest": "demolitions_caster"}
const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)

var _failures := 0
var _game
var _player
var _combat
var _source := Intent.Scripted.new()
var _origin := FLAT_SHELF


func _check(label: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [label, detail, "ok" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _never() -> bool:
	return false

func _pilot(name: String, harpoon := "shot", pull := "self", keys := "shift") -> void:
	var def: Resource = ClassDef.by_id(PILOTS[name])
	_game.tuning.set_option("harpoon", harpoon)
	_game.tuning.set_option("harpoon_pull", pull)
	_game.tuning.set_option("harpoon_keys", keys)
	_game.run.class_def = def
	_player.fit_class(def)
	_player.abilities.refill()
	_source.hold = {}
	_source.press = {}


func _spawn(kind: String, at: Vector3) -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy(kind, at)
	enemy.live = Callable(self, "_never")
	return enemy


func _point(dx: float, dz: float, lift: float) -> Vector3:
	return _game.ctx.terrain.drop_point(_origin.x + dx, _origin.z + dz, lift)


func _clear_field() -> void:
	for enemy in get_nodes_in_group("enemy"):
		if not enemy.get("kind") in ["warden", "vault"]:
			enemy.queue_free()


func _place(at: Vector3, velocity := Vector3.ZERO) -> void:
	_player.reset_to(at, velocity)
	_source.hold = {}


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_combat = _game.ctx.spawner
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(0.6)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_clear_field()
	await _sim(0.2)
	await _rebound_through()
	await _stomp_through()
	print("harpoon_rebound_cut_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(1 if _failures > 0 else 0)


func _rebound_through() -> void:
	_pilot("sable", "shot")
	_combat.heft_override = 1.0
	var a := _spawn("chaser", _point(0, -26, 1.5))
	var b := _spawn("lobber", _point(0, -12, 1.5))
	b.hp = 1000000.0
	b.max_hp = 1000000.0
	await _sim(0.4)
	var rebounds := [0]
	var hooked_after_first := [false]
	var tally := func(enemy: Node3D, _s: float):
		if enemy == b:
			rebounds[0] += 1
			if rebounds[0] == 1:
				hooked_after_first[0] = _player.kit.hooked and _player.kit.line_state == Augments.LINE_SMASH
	_game.events.enemy_rebounded.connect(tally)
	_place(_point(0, 0, 1.4))
	_player.grapple_to(a.global_position, Vector3.UP, a)
	_source.hold = {"harpoon_held": true}
	await _sim(0.03)
	_source.hold = {"harpoon_held": true, "brake_held": true}
	var smash_seen := false
	for tick in roundi(1.5 * Engine.physics_ticks_per_second):
		await physics_frame
		smash_seen = smash_seen or _player.kit.line_state == Augments.LINE_SMASH
		if smash_seen and not _player.kit.hooked:
			break
	_source.hold = {}
	_game.events.enemy_rebounded.disconnect(tally)
	_check("rebound lets go of the haul", smash_seen and rebounds[0] >= 1 and not hooked_after_first[0] and rebounds[0] <= 2,
		"haul committed %s; rebounds off B %d; line still hooked in SMASH right after the first rebound %s; charges now %s" % [smash_seen, rebounds[0], hooked_after_first[0], _player.abilities.slot("movement").charges if _player.abilities.slot("movement") != null else "?"])
	for e in [a, b]:
		if is_instance_valid(e):
			e.queue_free()
	await _sim(0.2)


# A stomp on a third body sets the velocity outright, so a line held on another body lets go.
func _stomp_through() -> void:
	_pilot("sable", "shot")
	var a := _spawn("chaser", _point(0, -30, 1.5))
	var b := _spawn("chaser", _point(6, -4, 1.5))
	await _sim(0.4)
	_place(_point(6, -4, 6.0), Vector3(0, -24, 0))
	_player.grapple_to(a.global_position, Vector3.UP, a)
	var stomps := [0]
	var hooked_after := [false]
	var tally := func(enemy: Node3D, kind: String, _s: float):
		if enemy == b and kind == _player.STOMP and stomps[0] == 0:
			stomps[0] = 1
			hooked_after[0] = _player.kit.hooked
	_player.struck.connect(tally)
	await _sim(0.8)
	_player.struck.disconnect(tally)
	_check("stomp lets go of the line", stomps[0] == 1 and not hooked_after[0],
		"stomp on B seen %s; line still hooked right after it %s" % [stomps[0] == 1, hooked_after[0]])
	for e in [a, b]:
		if is_instance_valid(e):
			e.queue_free()
	await _sim(0.2)
