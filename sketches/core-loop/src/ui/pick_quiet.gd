extends RefCounted

const WordFxWord := preload("res://src/presentation/world_fx/world_fx_word.gd")


static var _holds := {}
static var _total := 0


static func hush(host) -> Array:
	var game = host.get("game") if host != null else null
	if game == null:
		return []
	var hud = game.hud
	_holds[hud] = int(_holds.get(hud, 0)) + 1
	if _holds[hud] == 1:
		hud.quiet(true)
	_total += 1
	WordFxWord.quiet(true)
	return [hud]


static func restore(hidden: Array) -> void:
	for hud in hidden:
		if _total <= 0:
			continue
		_total -= 1
		if _holds.has(hud):
			_holds[hud] -= 1
			if _holds[hud] <= 0:
				_holds.erase(hud)
				if is_instance_valid(hud):
					hud.quiet(false)
	if _total <= 0:
		_total = 0
		WordFxWord.quiet(false)
	assert(_total >= 0, "PickQuiet._total underflow")


static func reset_for_tests() -> void:
	for hud in _holds.keys():
		if is_instance_valid(hud):
			hud.quiet(false)
	_holds.clear()
	_total = 0
	WordFxWord.quiet(false)
