extends SceneTree

const Game := preload("res://src/game.gd")
const Audio := preload("res://src/presentation/audio.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")

# A game that leaves the tree right after it starts abandons the startup bake instead
# of waiting for the whole bank; a later Audio in the same process still gets a full one.

var _failures := 0
var _step := 0
var _game
var _ids: Array = []


func _initialize() -> void:
	_ids = Audio._sound_ids()
	_game = _build()


func _build():
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	return game


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	match _step:
		0:
			root.remove_child(_game)
			var baked: int = SfxBank._streams.size()
			_check("bake abandoned", baked < _ids.size(), "%d of %d ids baked when the game left the tree" % [baked, _ids.size()])
			_check("not marked baked", not Audio._baked and Audio._bake_task == -1 and not SfxBank.bake_cancel, "baked bit false, task cleared, cancel flag cleared")
			_game.free()
			_game = _build()
			_step = 1
			return false
		1:
			var audio = _game.presentation.audio
			audio.bake_now()
			var missing: Array = _ids.filter(func(id): return not SfxBank._streams.has(id))
			_check("fresh bake completes", missing.is_empty() and audio.sound_ready and Audio._baked, "every id baked, sound_ready %s, missing %s" % [audio.sound_ready, missing])
			root.remove_child(_game)
			_game.free()
			if _failures == 0:
				print("audio_bake_cancel_test: PASS")
			quit(1 if _failures > 0 else 0)
	return false


func _check(name: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [name, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1
