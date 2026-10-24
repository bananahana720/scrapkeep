extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# warden_sighted through flow's real physics_step (follow-up from #438, whose tests call
# _read_sighting directly): with the ball held beyond SIGHT_SHARE ring radii nothing fires; at
# 2.5 radii, outside the ring, the game's own frames fire warden_sighted once for the stage and
# never warden_engaged; staying there does not fire it again.

var _t := T.new("warden_sighted_step_test")
var _game
var _player
var _source := Intent.Scripted.new()
var _sighted: Array = []
var _engaged: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _hold_at(radii: float, frames: int) -> void:
	var flow = _game.flow
	var at: Vector3 = flow._warden_at
	var out: float = flow.beacon.radius * radii
	var spot: Vector3 = _game.ctx.terrain.drop_point(at.x + out, at.z, 1.5)
	for i in frames:
		_player.reset_to(spot)
		await physics_frame


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	var flow = _game.flow
	_game.ctx.calm = true
	flow.force_warden = true
	_player = _game.player
	_player.source = _source
	_game.events.warden_sighted.connect(func(stage: int): _sighted.append(stage))
	_game.events.warden_engaged.connect(func(stage: int): _engaged.append(stage))
	flow.press_start()
	flow.choose_class(1)
	await _frames(24)
	_game.run.set_max_hp(99999.0)
	_t.check("a sealed Warden stands", flow.sealed and is_instance_valid(flow.warden))
	_sighted.clear()
	_engaged.clear()
	await _hold_at(flow.SIGHT_SHARE + 1.0, 30)
	_t.eq("beyond the sighting distance nothing fires", [_sighted.size(), _engaged.size()], [0, 0])
	await _hold_at(2.5, 30)
	_t.eq("inside it, outside the ring, the step fires warden_sighted once", _sighted, [_game.run.stage])
	_t.eq("and the fight has not begun", _engaged.size(), 0)
	await _hold_at(2.0, 30)
	_t.eq("staying near does not fire it again", _sighted.size(), 1)
	_game.free()
	quit(_t.verdict())
