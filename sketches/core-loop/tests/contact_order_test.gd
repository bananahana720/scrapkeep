extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Augments := preload("res://src/movement/augments.gd")
const Contact := preload("res://src/movement/contact.gd")

# Two enemies met in one tick are handled in an order the game's state sets, not the order the
# physics server lists them (which follows its worker threads and differed between two PC
# launches of learner seed 40322: a haul through a pair of chasers landed in one launch and was
# spent on the bystander in the other).
# - Contact.meets_first: the body a committed haul is landing on, then the nearer, then tree order.
# - In a live game the ball drops through a side-by-side pair with real physics. Whichever of the
#   two was spawned first, a committed haul lands on its own body (harpoon_smashed names it), and
#   with no line the nearer body is told first.
# Evidence limit: a headless run on one machine. It shows the order no longer follows spawn
# order; it cannot show two launches on another machine agree.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)
const GAP := 0.2

var _failures := 0
var _game
var _player
var _combat
var _source := Intent.Scripted.new()


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


func _spawn(at: Vector3) -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy("chaser", at)
	enemy.live = Callable(self, "_never")
	enemy.hp = 1000000.0
	enemy.max_hp = 1000000.0
	return enemy


func _point(dx: float, dz: float, lift: float) -> Vector3:
	return _game.ctx.terrain.drop_point(FLAT_SHELF.x + dx, FLAT_SHELF.z + dz, lift)


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
	var def: Resource = ClassDef.by_id("pylon_engineer")
	_game.run.class_def = def
	_player.fit_class(def)
	for enemy in get_nodes_in_group("enemy"):
		if not enemy.get("kind") in ["warden", "vault"]:
			enemy.queue_free()
	await _sim(0.2)
	_rule()
	var slot := 0
	for hauled in [true, false]:
		for first_spawned in [true, false]:
			await _pair(hauled, first_spawned, slot)
			slot += 1
	print("contact_order_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(1 if _failures > 0 else 0)


func _rule() -> void:
	var a := Node3D.new()
	var b := Node3D.new()
	_game.add_child(a)
	_game.add_child(b)
	a.global_position = Vector3(2.0, 0.0, 0.0)
	b.global_position = Vector3(1.0, 0.0, 0.0)
	var at := Vector3.ZERO
	_check("nearer first", Contact.meets_first(b, a, at, null) and not Contact.meets_first(a, b, at, null), "b at 1 m before a at 2 m")
	_check("landing body first", Contact.meets_first(a, b, at, a) and not Contact.meets_first(b, a, at, a), "a is the haul's body, though farther")
	b.global_position = a.global_position
	_check("tree order breaks a tie", Contact.meets_first(a, b, at, null) and not Contact.meets_first(b, a, at, null), "same distance, a is earlier in the tree")
	a.free()
	b.free()


# The ball falls onto `target`, with `other` GAP beside it, so both are met in one tick. A haul
# must tell its own body first; with no line the nearer of the two is first, whichever that is on
# the slope. `first_spawned` says whether `target` is the earlier of the two in
# the tree and in the physics server.
func _pair(hauled: bool, first_spawned: bool, slot: int) -> void:
	var here := _point(12.0 * slot, -20.0, 1.5)
	var beside := here + Vector3(GAP, 0.0, 0.0)
	var target: Node3D
	var other: Node3D
	if first_spawned:
		target = _spawn(here)
		other = _spawn(beside)
	else:
		other = _spawn(beside)
		target = _spawn(here)
	await _sim(0.4)
	var told := []
	var hear := func(enemy: Node3D, _normal: Vector3):
		told.append([enemy, Engine.get_physics_frames(), _player.ball_position().distance_to(enemy.global_position)])
	var smashed := []
	var landed := func(enemy, _at: Vector3, _closing: float): smashed.append(enemy)
	_player.body().enemy_touched.connect(hear)
	_game.events.harpoon_smashed.connect(landed)
	var fall := Vector3(0.0, -24.0, 0.0)
	_player.reset_to(target.global_position + Vector3(0.0, 5.0, 0.0), fall)
	if hauled:
		_player.grapple_to(target.global_position, Vector3.BACK, target)
		Augments.commit_smash(_player.kit, _player.tuning, fall)
	for tick in roundi(1.0 * Engine.physics_ticks_per_second):
		await physics_frame
		if told.size() >= 2:
			break
	_player.body().enemy_touched.disconnect(hear)
	_game.events.harpoon_smashed.disconnect(landed)
	var label := "%s, %s spawned first" % ["haul" if hauled else "no line", "its body" if first_spawned else "the bystander"]
	var same_tick: bool = told.size() >= 2 and told[0][1] == told[1][1]
	_check(label + ": one tick", same_tick, "%d touches, ticks %s" % [told.size(), str(told.map(func(row): return row[1]))])
	if same_tick:
		_check(label + ": order", told[0][0] == target if hauled else told[0][2] < told[1][2],
			"first told is the %s at %.3f m, then one at %.3f m" % ["target" if told[0][0] == target else "bystander", told[0][2], told[1][2]])
	if hauled:
		_check(label + ": the haul lands on its body", smashed.size() == 1 and smashed[0] == target,
			"%d landings, on its body %s" % [smashed.size(), not smashed.is_empty() and smashed[0] == target])
	_player.release_grapple()
	for enemy in [target, other]:
		if is_instance_valid(enemy):
			enemy.queue_free()
	await _sim(0.2)
