extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Roster := preload("res://src/combat/roster.gd")
const T := preload("res://tests/support/t.gd")

# 2026-10-18 (w17 hook out): the real path. A live Game, a real hold from a hook-listing roster
# row, and player.grapple_to as the harpoon calls it: a bite on world geometry hooks out
# (hold_broken with "hook"), a bite on an enemy body does not.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)

var _t := T.new("holds_hook_out_live_test")
var _game
var _player
var _source := Intent.Scripted.new()
var _broken: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(0.6)
	_game.run.set_max_hp(99999.0)
	_game.events.hold_broken.connect(func(kind: String, method: String): _broken.append([kind, method]))
	var combat = _game.ctx.spawner
	var holds = combat.fleet.holds
	var ball: Vector3 = _game.ctx.terrain.drop_point(FLAT_SHELF.x, FLAT_SHELF.z, 6.0)
	var wall := ball + Vector3(0, 0, -8)
	var hookers := {"mag_trapper": "mag_pit", "gyro_jammer": "gyro_drift", "catch_trap": "cup_hold",
		"winch_drone": "winch_pull", "bola_thrower": "bola_wrap"}
	for row_id in hookers:
		var row: Dictionary = Roster.row(row_id)
		var src := Node3D.new()
		_game.add_child(src)
		_player.reset_to(ball)
		_player.release_grapple()
		_broken.clear()
		var held: bool = holds.catch(src, String(row["mechanic"]), row["breaks"])
		_player.grapple_to(wall, Vector3(1, 0, 0), null)
		_t.eq("%s: world bite hooks out" % row_id, [held, holds.holding(), _broken], [true, false, [[hookers[row_id], "hook"]]])
		src.free()
	# An enemy body bitten through the same call keeps the hold.
	var enemy: Node3D = combat.spawn_enemy("chaser", ball + Vector3(0, 0, -10))
	enemy.live = func(): return false
	var src2 := Node3D.new()
	_game.add_child(src2)
	_player.reset_to(ball)
	_player.release_grapple()
	_broken.clear()
	var held2: bool = holds.catch(src2, "mag_pit", Roster.ROWS["mag_trapper"]["breaks"])
	_player.grapple_to(enemy.global_position, Vector3(1, 0, 0), enemy)
	_t.eq("enemy bite keeps the hold", [held2, holds.holding(), _broken], [true, true, []])
	holds.clear()
	_player.release_grapple()
	src2.free()
	quit(_t.verdict())
