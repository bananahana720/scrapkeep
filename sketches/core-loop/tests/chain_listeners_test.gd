extends SceneTree

const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")

# The hook chain rides line_state_changed (design-v3/HOOK-CHAIN.md); chain_readout_test covers what it shows and plays:
#   a  the line view keeps its state across every chain_ row
#   b  the audio keeps the hum for a chain_ row and plays only the chain's own end and miss cues
#   c  a press during the post-smash rewind is no chain miss and starts no cooldown
#   d  a combo smash does not scale the slammed strength

var _t := T.new("chain_listeners_test")
var _game
var _player
var _slammed: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(ticks: int) -> void:
	for i in ticks:
		await physics_frame


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(40)
	var view = _game.presentation.line_view
	var audio = _game.presentation.audio
	audio.bake_now()
	var events = _player.events
	for id in ["chain_end", "chain_link", "chain_pivot", "chain_miss"]:
		events.line_state_changed.emit("locked", null, Vector3.ZERO, "")
		events.line_state_changed.emit(id, null, Vector3.ZERO, "ground")
		_t.eq("a %s leaves the line view locked" % id, view._state, "locked")
	events.line_state_changed.emit("searching", null, Vector3.ZERO, "")

	audio.hum_on = true
	audio.cue_log.clear()
	audio._last_start.clear()
	_player.chain.links = 0
	for id in ["chain_miss", "chain_end", "chain_link", "chain_pivot"]:
		events.line_state_changed.emit(id, null, Vector3.ZERO, "ground")
	var heard: Array = []
	for entry in audio.cue_log:
		heard.append(entry[1])
	_t.check("b chain rows play only the end zip and the miss tick, and keep the hum",
		audio.hum_on and heard.all(func(sound): return sound in ["line_zip", "dry_tick"]) and not ("line_bite" in heard),
		"cues %s, hum_on %s" % [audio.cue_log, audio.hum_on])
	audio._stop_hum()

	_player.kit.drop_line("reset")
	_player.chain.reset()
	_player.kit.rewind_left = 0.5
	_player._press_harpoon()
	_t.check("c a press during the rewind is no chain miss", _player.chain.miss_left == 0.0 and _player.chain.misses == 0,
		"miss_left %.2f, misses %d" % [_player.chain.miss_left, _player.chain.misses])
	_player.kit.rewind_left = 0.0

	events.slammed.connect(func(_at: Vector3, strength: float, _flat: float): _slammed.append(strength))
	_player._landing_mult = 1.0
	_player._on_slammed(Vector3.ZERO, 30.0, 1.0)
	_player._landing_mult = 2.5
	_player._on_slammed(Vector3.ZERO, 30.0, 1.0)
	_player._landing_mult = 1.0
	_t.check("d slammed strength ignores the landing multiplier", _slammed.size() == 2 and is_equal_approx(_slammed[0], _slammed[1]),
		"strengths %s" % [_slammed])

	_game.free()
	var code := _t.verdict()
	if code == 0:
		print("chain_listeners_test: PASS")
	else:
		print("chain_listeners_test: FAIL (%d)" % _t.failures)
	quit(code)
