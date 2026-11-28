extends SceneTree

const Game := preload("res://src/game.gd")
const Audio := preload("res://src/presentation/audio.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const MusicPrebake := preload("res://src/presentation/music_prebake.gd")
const Synth := preload("res://src/presentation/synth.gd")
const T := preload("res://tests/support/t.gd")

# A game with a sound device bakes the band on two workers behind the title, about ten seconds
# of work. A game that leaves the tree while they run abandons them instead of waiting them
# out. The proof is not a stopwatch: the band bake renders Brindle's wobbles near its end, so a
# quit that waited the bake out leaves wobbles in the cache and a quit that abandoned it leaves
# none. A later bake still renders all of it.

var _t := T.new("audio_quit_settle_test")
var _step := 0
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_step += 1
	if _step == 1:
		# A headless game has no device and never starts the band bakes: start them as a game
		# with one does when its bank is baked (Audio._on_ready).
		_t.check("QS-0 the cache starts without wobbles", _wobbles() == 0, "%d wobbles before the bake" % _wobbles())
		Audio._start_band_bakes()
		return false
	if _step < 4:
		return false
	var in_flight: bool = Audio.band_bakes()["running"]
	if not _t.check("QS-0 the band bake is in flight", in_flight, "the bake must still be running when the game leaves, or the cancel is not tested"):
		quit(1)
		return false
	root.remove_child(_game)
	_t.check("QS-1 leaving the tree lets go of every bake", Audio._bake_task == -1 and not Audio.band_bakes()["held"],
		"bank %d, bakes %s" % [Audio._bake_task, Audio.band_bakes()])
	_t.check("QS-1 the cancel flag is down again", not SfxBank.bake_cancel, "a flag left up would stop the next bake")
	_t.check("QS-2 the band bake was abandoned, not waited out", _wobbles() == 0, "%d wobbles: the bake ran to its end" % _wobbles())
	_game.free()
	_game = null
	MusicPrebake.prepare_rest()
	_t.check("QS-3 a later bake renders what was abandoned", _wobbles() > 0, "no wobble after a full bake")
	quit(_t.verdict())
	return true


func _wobbles() -> int:
	Synth._lock.lock()
	var count: int = Synth._notes.keys().filter(func(key: String) -> bool: return key.begins_with("wob:")).size()
	Synth._lock.unlock()
	return count
