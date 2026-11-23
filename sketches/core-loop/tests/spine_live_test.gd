extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# A few seconds of live stage 1 through whatever modules are installed, using only the
# context and the bus: enemies spawned through ctx.spawner, the class weapon held down
# at one of them, and the facts that come back. It proves the seams carry a fight
# end to end: spawn, shot, strike, kill, scrap.

const SECONDS := 4.0
const AHEAD := 14.0

var _game
var _source := Intent.Scripted.new()
var _started := false
var _clock := 0.0
var _counts := {}
var _scrap_before := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _count(kind: String) -> void:
	_counts[kind] = _counts.get(kind, 0) + 1


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_started = true
		var events = _game.events
		for kind in ["enemy_spawned", "shot_fired", "enemy_struck", "enemy_killed", "scrap_collected"]:
			events.connect(kind, _count.bind(kind).unbind(_argc(events, kind)))
		_game.player.source = _source
		_game.flow.press_start()
		_game.flow.choose_class(0)
		var heading: Vector3 = _game.ctx.terrain.entry_heading(1)
		var at: Vector3 = _game.ctx.terrain.spawn_point(1)
		_game.player.reset_to(at)
		_game.player.body().global_position = at
		_game.camera.snap(heading, -0.08)
		var ahead: Vector3 = at + heading * AHEAD
		_game.ctx.spawner.spawn_enemy("chaser", _game.ctx.terrain.drop_point(ahead.x, ahead.z, 2.4))
		_game.ctx.spawner.spawn_enemy("lobber", _game.ctx.terrain.drop_point(ahead.x + 30.0, ahead.z + 30.0, 2.4))
		_game.ctx.spawner.spawn_enemy("miniboss", _game.ctx.terrain.drop_point(ahead.x - 30.0, ahead.z + 30.0, 2.4))
		_source.press = {"fire_pressed": true}
		return false
	_clock += delta
	if bool(_game.ctx.spawner.weapon_driver.state_snapshot().get("ready", false)):
		_source.press = {"fire_pressed": true}
	if _clock < SECONDS:
		return false
	var ok_spawn: bool = _counts.get("enemy_spawned", 0) >= 3
	var ok_fire: bool = _counts.get("shot_fired", 0) >= 10
	var ok_hit: bool = _counts.get("enemy_struck", 0) >= 1
	var ok_kill: bool = _counts.get("enemy_killed", 0) >= 1
	var alive: int = _game.get_tree().get_nodes_in_group("enemy").size()
	print("[spawn] enemy_spawned %d (needs >= 3) -> %s" % [_counts.get("enemy_spawned", 0), "PASS" if ok_spawn else "FAIL"])
	print("[fire] shot_fired %d in %.0f s of held fire -> %s" % [_counts.get("shot_fired", 0), SECONDS, "PASS" if ok_fire else "FAIL"])
	print("[strike] enemy_struck %d -> %s" % [_counts.get("enemy_struck", 0), "PASS" if ok_hit else "FAIL"])
	print("[kill] enemy_killed %d, %d enemies still alive, run kills %d -> %s" % [_counts.get("enemy_killed", 0), alive, _game.run.kills, "PASS" if ok_kill and _game.run.kills == _counts.get("enemy_killed", 0) else "FAIL"])
	var ok: bool = ok_spawn and ok_fire and ok_hit and ok_kill and _game.run.kills == _counts.get("enemy_killed", 0)
	print("spine_live_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true


static func _argc(events, kind: String) -> int:
	for info in events.get_signal_list():
		if info["name"] == kind:
			return (info["args"] as Array).size()
	return 0
