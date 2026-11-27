extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")

const PLAY_TICKS := 360
const MAX_TOTAL_TICKS := 6400
const ENEMIES := 4

var _game
var _player
var _combat
var _source := Intent.Scripted.new()
var _failures := 0
var _booted := false
var _def
var _leaf := 14
var _tick := 0
var _total_ticks := 0
var _facts := 0
var _proc_runs := 0
var _bad := []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _class_index() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class="):
			return int(arg.trim_prefix("--class="))
	return 0


func _physics_process(_delta: float) -> bool:
	_total_ticks += 1
	if _total_ticks > MAX_TOTAL_TICKS:
		var label := String(_def.display_name) if _def != null else "class %d" % _class_index()
		_report("%s tick cap" % label, false,
			"exceeded %d physics ticks at leaf %d (tick %d)" % [MAX_TOTAL_TICKS, _leaf, _tick])
		print("tree_play_run (%s): FAIL (%d)" % [label, _failures])
		_game.free()
		quit(1)
		return true
	if _game.flow == null:
		return false
	if not _booted:
		_booted = true
		_game.ctx.calm = true
		_game.tuning.set_option("world_one_builds", "off")
		_player = _game.player
		_combat = _game.combat
		_player.source = _source
		_def = ClassDef.all()[_class_index()]
		for kind in ["sticky_detonated", "enemy_struck", "special_used", "vault_kicked", "sprint_started", "blink_used"]:
			_game.events.connect(kind, func(_a = null, _b = null, _c = null): _facts += 1)
		_game.flow.press_start()
		_game.flow.choose_class(_class_index())
		_start_build()
		return false
	_game.run.hp = _game.run.max_hp
	_drive()
	_tick += 1
	if _tick < PLAY_TICKS:
		return false
	_check_build()
	_leaf += 1
	if _leaf < 30:
		_start_build()
		return false
	_report("%s builds played" % _def.display_name, _bad.is_empty(),
		"16 builds x %.1f s (%d ticks), %d ability facts, %d proc actions; bad %s" % [
			PLAY_TICKS / 90.0, _total_ticks, _facts, _proc_runs, _bad])
	print("tree_play_run (%s): %s" % [_def.display_name, "PASS" if _failures == 0 else "FAIL (%d)" % _failures])
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _start_build() -> void:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.queue_free()
	_combat.sticky.clear()
	_game.run.class_def = _def
	_game.flow.new_run()
	var tree = _player.tree
	for id in UpgradeTree.path_to(_def.id, UpgradeTree.nodes(_def.id)[_leaf]["id"]):
		if not tree.pending():
			tree.open_checkpoint()
		tree.pick(id)
	var at: Vector3 = _game.ctx.terrain.spawn_point(1)
	_player.reset_to(at)
	_player.body().global_position = at
	for i in ENEMIES:
		var angle := TAU * float(i) / float(ENEMIES)
		var flat := at + Vector3(cos(angle), 0.0, sin(angle)) * 9.0
		_combat.spawn_enemy("lobber" if i == 0 else "chaser", Vector3(flat.x, _game.ctx.terrain.height(flat.x, flat.z) + 1.5, flat.z))
	_source.hold = {}
	_source.press = {}
	_tick = 0


func _drive() -> void:
	var t := _tick
	var dirs := [Vector2(0, 1), Vector2(1, 0.4), Vector2(0, -1), Vector2(-1, 0.4)]
	var hold := {"move": dirs[(t / 90) % 4]}
	var press := {}
	hold["fire_held"] = t % 90 < 60
	if t % 90 == 0:
		press["fire_pressed"] = true
	if t % 90 == 60:
		press["fire_released"] = true
	hold["special_held"] = t % 120 < 50
	if t % 120 == 0:
		press["special_pressed"] = true
	if t % 120 == 50:
		press["special_released"] = true
	hold["movement_held"] = t % 75 >= 10 and t % 75 < 40
	if t % 75 == 10:
		press["movement_pressed"] = true
	if t % 75 == 40:
		press["movement_released"] = true
	hold["jump_held"] = t % 50 < 40
	if t % 50 == 0:
		press["jump_pressed"] = true
	hold["brake_held"] = t % 50 >= 22 and t % 50 < 30 and not _player.state.grounded
	if t % 150 == 5:
		press["mount_pressed"] = true
	if t % 100 == 0:
		press["boost_pressed"] = true
	_source.hold = hold
	_source.press = press
	_game.camera.look(Vector2(3.0, 0.0))


func _check_build() -> void:
	var id: String = UpgradeTree.nodes(_def.id)[_leaf]["id"]
	_proc_runs += _combat._proc_ready.size()
	var ball: Vector3 = _player.ball_position()
	var ok: bool = ball.is_finite() and _player.body().linear_velocity.is_finite() and _player.tree.path().size() == 4
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		ok = ok and (enemy as Node3D).global_position.is_finite()
	if not ok:
		_bad.append("%s at %s" % [id, ball])
