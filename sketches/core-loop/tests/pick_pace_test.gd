extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")

# Pick pace (BIBLE.md:538): with world_one_builds on, one stage-checkpoint pick opens at the
# first stage of each world (stage 1, 3, 5 on the alpha and park tables), so a run that clears
# stage 5 holds its fourth pick before the final boss. Class rises are held (no rise is
# emitted), so allowed reads 1 at start, then 2, 2, 3, 3, 4, 4 after stages 1 to 6. A retried
# visit and the bay-plus-clear pair open at most one pick per stage. The legacy profile
# (flag off, cap DEPTHS) keeps its old schedule: picks at stages 1, 2 and 3, none after.
# Evidence limit: stage clears and bay boardings are direct _open_pick calls on the real
# Game with a grounded ball; this does not play a run or qualify how the pace feels.

const WORLD_ONE_ALLOWED := [2, 2, 3, 3, 4, 4]
const LEGACY_ALLOWED := [2, 3, 4, 4, 4, 4]

var _game
var _done := false
var _failures := 0
var _offers: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	_done = true
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.events.tree_offered.connect(func(c: String, d: int, ids: Array):
		_offers.append({"class": c, "depth": d, "ids": ids}))
	_game.flow.press_start()
	_game.flow.choose_class(0)
	var original = _game.ctx.stages
	for entry in [["alpha", AlphaDefs], ["park", ParkDefs]]:
		_game.ctx.stages = entry[1]
		_schedule(entry[0], true, WORLD_ONE_ALLOWED)
		_schedule(entry[0] + " legacy", false, LEGACY_ALLOWED)
		_visits(entry[0])
	_game.ctx.stages = original
	print("pick_pace_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _new_run(on: bool) -> void:
	_game.ctx.tuning.set_option("world_one_builds", "on" if on else "off")
	_offers.clear()
	_game.player.state.grounded = true
	_game.flow.new_run()
	_game.player.state.grounded = true


# One stage clear, with the bay boarded at the same stage, in the order a run sees them.
func _visit(stage: int) -> void:
	# Enter the stage as flow does, so its per-stage marks (pick_opened, SA-F1) start clear.
	_game.run.enter_stage(stage)
	_game.world._open_pick(stage)
	_game.world._open_pick(stage)


func _schedule(label: String, on: bool, want: Array) -> void:
	_new_run(on)
	var tree = _game.player.tree
	var got: Array = []
	var start_allowed: int = tree.allowed
	for stage in range(1, 7):
		_visit(stage)
		got.append(tree.allowed)
	_report(label + " allowed after stages 1 to 6", start_allowed == 1 and got == want,
		"start %d, got %s, want %s" % [start_allowed, got, want])
	_report(label + " offers match allowed", _offers.size() == int(want[-1]),
		"%d tree_offered events, want %d" % [_offers.size(), int(want[-1])])


# A retried visit and the bay-plus-clear pair open at most one pick per stage.
func _visits(label: String) -> void:
	_new_run(true)
	var tree = _game.player.tree
	var ok := true
	var trail: Array = []
	for stage in range(1, 7):
		var before: int = tree.allowed
		_visit(stage)
		_game.world._open_pick(stage)
		_game.flow.retry_stage()
		_game.run.stage = stage
		_game.world._open_pick(stage)
		# A pick queued while the retried ball is airborne lands on the next calm frame.
		_game.player.state.grounded = true
		_game.world._physics_process(0.0)
		var gained: int = tree.allowed - before
		trail.append(gained)
		ok = ok and gained <= 1
	_report(label + " one pick per stage under repeats", ok and trail == [1, 0, 1, 0, 1, 0],
		"gains per stage %s, want [1, 0, 1, 0, 1, 0]" % [trail])
	_report(label + " no waiting picks left", _game.world._picks_waiting.is_empty(),
		"waiting %s" % [_game.world._picks_waiting])
