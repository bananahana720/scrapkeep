extends SceneTree

const Game := preload("res://src/game.gd")

# The first-discovery burst pays cogs beside mass, one cog per scrap unit (as kills and
# activities do): scrap and cogs both rise by BURST_PER_STAGE * stage, scrap_collected and cogs_collected fire
# once each, and the codex (not the flow) still gates a second burst for the same entry.

var _game
var _ticks := 0
var _done := false
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	_ticks += 1
	if _ticks < 5:
		return false
	_done = true
	_run()
	return true


func _run() -> void:
	_game.flow.press_start()
	_game.flow.choose_class(0)
	var run = _game.ctx.run
	var scrap_events := [0]
	var cog_events := [0]
	var cog_amount := [0]
	_game.events.scrap_collected.connect(func(_a, _b, _c): scrap_events[0] += 1)
	_game.events.cogs_collected.connect(func(a, _b):
		cog_events[0] += 1
		cog_amount[0] = a)
	var stage: int = run.stage
	var expect: int = _game.flow.BURST_PER_STAGE * stage
	var scrap0: int = run.scrap
	var cogs0: int = run.cogs
	_game.flow.discovery_burst(Vector3.ZERO)
	_check("stage", stage == 1, "stage %d" % stage)
	_check("scrap rose by the burst", run.scrap - scrap0 == expect, "%d, want %d" % [run.scrap - scrap0, expect])
	_check("cogs rose by the burst", run.cogs - cogs0 == expect, "%d, want %d" % [run.cogs - cogs0, expect])
	_check("scrap_collected once", scrap_events[0] == 1, "%d" % scrap_events[0])
	_check("cogs_collected once", cog_events[0] == 1, "%d" % cog_events[0])
	_check("cogs_collected amount", cog_amount[0] == expect, "%d, want %d" % [cog_amount[0], expect])
	# The gate lives in codex.mark_discovered (codex.gd:142, _run_seen): first call bursts, second does not.
	var scrap1: int = run.scrap
	var cogs1: int = run.cogs
	_game.codex.mark_discovered("parting_shot", Vector3.ZERO)
	_check("codex first call pays scrap", run.scrap - scrap1 == expect, "%d" % (run.scrap - scrap1))
	_check("codex first call pays cogs", run.cogs - cogs1 == expect, "%d" % (run.cogs - cogs1))
	_game.codex.mark_discovered("parting_shot", Vector3.ZERO)
	_check("codex second call gated (scrap)", run.scrap - scrap1 == expect, "%d" % (run.scrap - scrap1))
	_check("codex second call gated (cogs)", run.cogs - cogs1 == expect, "%d" % (run.cogs - cogs1))
	print("discovery_burst_cogs_test: %s" % ("PASS" if _failures == 0 else "FAIL"))
	_game.free()
	quit(0 if _failures == 0 else 1)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("  %s: %s (%s)" % [label, "ok" if ok else "FAIL", detail])
