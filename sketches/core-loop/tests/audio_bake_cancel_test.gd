# smoke: solo (needs a cold sound bank: it leaves the tree while the startup bake still runs, and a warm batch has already baked it)
extends SceneTree

const Game := preload("res://src/game.gd")
const Audio := preload("res://src/presentation/audio.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const T := preload("res://tests/support/t.gd")

# A game that leaves the tree right after it starts abandons the startup bake instead
# of waiting for the whole bank; a later Audio in the same process still gets a full one,
# and an Audio that outlives the cancelled bake starts it again.

var _t := T.new("audio_bake_cancel_test")
var _step := 0
var _game
var _other
var _ids: Array = []


func _initialize() -> void:
	var unique := {}
	for id in Audio._sound_ids():
		unique[id] = true
	_ids = unique.keys()
	_game = _build()


func _build():
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	return game


func _missing() -> Array:
	return _ids.filter(func(id): return not SfxBank._streams.has(id))


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	match _step:
		0:
			if not _t.check("bake in flight", Audio._bake_task >= 0, "the bake must still be running when the game leaves, or the cancel is not tested"):
				quit(1)
				return false
			root.remove_child(_game)
			var baked: int = SfxBank._streams.size()
			_t.check("bake abandoned", baked < _ids.size(), "%d of %d unique ids baked when the game left the tree" % [baked, _ids.size()])
			_t.check("not marked baked", not Audio._baked and Audio._bake_task == -1 and not SfxBank.bake_cancel, "baked bit false, task cleared, cancel flag cleared")
			_game.free()
			_game = _build()
			_other = _build()
			_step = 1
		1:
			if _other.flow == null:
				return false
			_t.check("survivor setup: bake in flight", Audio._bake_task >= 0, "two games share one running bake")
			root.remove_child(_game)
			_game.free()
			_game = _other
			_other = null
			_step = 2
		2:
			_t.check("FX-1 survivor restarts the bake", Audio._bake_task >= 0 and not Audio._baked, "task %d, baked %s after the survivor's frame" % [Audio._bake_task, Audio._baked])
			root.remove_child(_game)
			root.add_child(_game)
			_step = 3
		3:
			# The fault is a bank left abandoned: no task and not baked. A bake already finished is not it:
			# few ids are left by now, so the restarted bake can end inside this one frame (the old check
			# asked for a task still running and failed 1 run in 3 to 1 in 11 on that race, 2026-11-09).
			_t.check("FX-2 re-entry restarts the bake", Audio._bake_task >= 0 or Audio._baked, "task %d, baked %s after the re-entered frame" % [Audio._bake_task, Audio._baked])
			var audio = _game.presentation.audio
			audio.bake_now()
			var missing := _missing()
			_t.check("FX-1 survivor completes", missing.is_empty() and audio.sound_ready and Audio._baked, "every id baked, sound_ready %s, missing %s" % [audio.sound_ready, missing])
			root.remove_child(_game)
			_game.free()
			_game = null
			_step = 4
			quit(_t.verdict())
	return false
