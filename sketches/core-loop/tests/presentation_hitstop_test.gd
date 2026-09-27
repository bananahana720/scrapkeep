extends SceneTree

const Game := preload("res://src/game.gd")

# The hit-stop policy from the demo spec, through the real game. A stop is asked only
# when a hit breaks through plating (plating > 0, not deflected) and when a Warden
# breaks, at least 0.4 s apart. Ten crush kills in a second ask for none; five plated
# break-throughs in a second get at most three; a deflected hit gets none whichever
# order combat publishes it in. Plating is read the way combat will expose it
# (ctx.spawner.plating_of); until combat has it, the test supplies it.

var _game
var _juice
var _failures := 0
var _t0 := 0
var _plan: Array = []
var _fodder: Array = []
var _plated: Node3D
var _marks := {}
var _done := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	var events = _game.events
	if _juice == null:
		_juice = _game.presentation.juice
		for name in ["strike_deflected", "beacon_unsealed"]:
			if not events.has_signal(name):
				var args := [{"name": "stage", "type": TYPE_INT}]
				if name == "strike_deflected":
					args = [{"name": "enemy", "type": TYPE_OBJECT}, {"name": "kind", "type": TYPE_STRING},
						{"name": "punch", "type": TYPE_FLOAT}, {"name": "plating", "type": TYPE_FLOAT}]
				events.add_user_signal(name, args)
		_game.presentation.wire_optional()
		_juice.plating_of = func(enemy: Node3D) -> float: return float(enemy.get_meta("plating", 0.0))
		_juice.resolve_of = Callable()
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		for i in 10:
			var chaser := Node3D.new()
			chaser.set_meta("plating", 0.0)
			_game.add_child(chaser)
			_fodder.append(chaser)
		_plated = Node3D.new()
		_plated.set_meta("plating", 30.0)
		_game.add_child(_plated)
		_t0 = Time.get_ticks_msec()
		# Ten crushes, 100 ms apart: a fodder strike and its kill in the same frame.
		for i in 10:
			_plan.append([100 + i * 100, func():
				events.enemy_struck.emit(_fodder[i], "ram", 26.0)
				events.enemy_killed.emit("chaser", Vector3.ZERO, 1)])
		_plan.append([1150, func(): _marks["crush"] = _sent().size()])
		# A deflected hit, in both publication orders.
		_plan.append([1700, func():
			events.emit_signal("strike_deflected", _plated, "ram", 20.0, 30.0)
			events.enemy_struck.emit(_plated, "ram", 20.0)])
		_plan.append([2200, func():
			events.enemy_struck.emit(_plated, "stomp", 9.0)
			events.emit_signal("strike_deflected", _plated, "stomp", 9.0, 30.0)])
		_plan.append([2700, func(): _marks["deflect"] = _sent().size()])
		# Five break-throughs in one second.
		for i in 5:
			_plan.append([3000 + i * 200, func(): events.enemy_struck.emit(_plated, "ram", 40.0)])
		_plan.append([4050, func(): _marks["plated"] = _sent().size()])
		_plan.append([4700, func(): events.emit_signal("beacon_unsealed", 1)])
		_plan.append([4800, func(): _marks["unseal"] = _sent().size()])
		return false
	var elapsed := Time.get_ticks_msec() - _t0
	while not _plan.is_empty() and elapsed >= _plan[0][0]:
		var item: Array = _plan.pop_front()
		(item[1] as Callable).call()
	if not _plan.is_empty() or _done:
		return false
	_done = true
	_check("crushes free", _marks["crush"] == 0, "10 crush kills in 1 s send %d hit-stops" % _marks["crush"])
	_check("deflects free", _marks["deflect"] == 0, "a deflected ram and a deflected stomp, in either publication order, send %d" % _marks["deflect"])
	var plated: int = _marks["plated"] - _marks["deflect"]
	_check("break-throughs spaced", plated >= 2 and plated <= 3, "5 plated break-throughs in 1 s send %d (at most 3)" % plated)
	_check("unseal stops", _marks["unseal"] - _marks["plated"] == 1, "beacon_unsealed sends one stop of its own")
	var gaps_ok := true
	var sent := _sent()
	var gaps: Array = []
	for i in range(1, sent.size()):
		var gap: int = sent[i][3] - sent[i - 1][3]
		gaps.append(gap)
		gaps_ok = gaps_ok and gap >= 400
	var lengths_ok := true
	for entry in sent:
		lengths_ok = lengths_ok and entry[1] >= 0.03 and entry[1] <= 0.05
	_check("0.4 s apart", gaps_ok and lengths_ok, "gaps between stops %s ms; every stop 30-50 ms" % [gaps])
	print("presentation_hitstop_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _sent() -> Array:
	return _juice.hit_stop_log.filter(func(entry: Array): return entry[1] > 0.0)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
