extends SceneTree

const Game := preload("res://src/game.gd")
const Chain := preload("res://src/combat/chain.gd")

# W1-74: a paid chain of 3 or more bursts scrap at its landing, stepped by combo; an unpaid end
# or a short chain pays nothing. The test writes player.chain.finished as the player does before
# it publishes chain_end, then reads how many scrap pieces build dropped. Pass: every label
# prints PASS, exit 0.

var _game
var _failures := 0
var _wait := 0
var _started := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


# Ends a chain at `combo` and returns the scrap pieces it dropped.
func _end(combo: int, paid: bool) -> int:
	var before: int = _game.build.scrap.count()
	_game.player.chain.finished.append({"links": combo, "pivots": 0, "combo": combo, "paid": paid, "cause": "paid" if paid else "ground"})
	_game.events.line_state_changed.emit("chain_end", null, _game.player.ball_position() + Vector3(30, 0, 0), "paid" if paid else "ground")
	return _game.build.scrap.count() - before


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	_wait += 1
	if _wait < 3:
		return false
	var chain := Chain.new()
	var steps := []
	for combo in [1, 2, 3, 4, 5, 6, 9]:
		chain.finished = [{"links": combo, "pivots": 0, "combo": combo, "paid": true, "cause": "paid"}]
		steps.append(chain.last_burst())
	_report("(a) stepped by combo", steps == [0, 0, 4, 6, 9, 12, 12], "combo 1,2,3,4,5,6,9 -> %s" % [steps])
	chain.finished = [{"links": 5, "pivots": 0, "combo": 5, "paid": false, "cause": "ground"}]
	_report("(b) unpaid pays nothing", chain.last_burst() == 0, "unpaid combo 5 -> %d" % chain.last_burst())
	_report("(c) in stage", _game.flow.in_stage(), "flow in a stage after choose_class")
	# A burst scales as a kill's scrap does: the sheet's kill_scrap times the stage row's.
	var kill_scrap: float = _game.build.sheet.kill_scrap * float(_game.flow.stage_def().get("kill_scrap", 1.0))
	var short: int = _end(2, true)
	_report("(d) combo 2 drops nothing", short == 0, "dropped %d" % short)
	var three: int = _end(3, true)
	_report("(e) combo 3 bursts", three == int(round(4 * kill_scrap)), "dropped %d at kill pay x%.2f" % [three, kill_scrap])
	var full: int = _end(6, true)
	_report("(f) combo 6 bursts more", full == int(round(12 * kill_scrap)) and full > three, "dropped %d" % full)
	var unpaid: int = _end(6, false)
	_report("(g) an unpaid end drops nothing", unpaid == 0, "dropped %d" % unpaid)
	var other: int = _game.build.scrap.count()
	_game.events.line_state_changed.emit("chain_link", null, Vector3.ZERO, "")
	_report("(h) other line states drop nothing", _game.build.scrap.count() == other, "count %d" % _game.build.scrap.count())
	print("chain_burst_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)
	return true
