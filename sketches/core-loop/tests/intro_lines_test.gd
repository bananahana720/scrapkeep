extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const Registry := preload("res://src/core/content_registry.gd")

# Intro lines: the Warden's row plays when warden_engaged fires, the boss's row when
# boss_arena_entered fires. Each plays once per run and zone, waits out an exchange and a
# pause, and the registry keeps the rows on real zones with the boss their world owns.

const SETTLE_FRAMES := 12

var _game
var _bubble
var _phase := "boot"
var _frames := 0
var _t := T.new("intro_lines_test")


func _initialize() -> void:
	_check_registry()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)


func _intro(zone: String, subject: String) -> Dictionary:
	for row in LoreRows.ROWS:
		if row["kind"] == "intro" and row["zone"] == zone and row["subject"] == subject:
			return row
	return {}


func _showing(row: Dictionary) -> bool:
	return _bubble.visible and _bubble.text == row["text"]


func _silent() -> bool:
	return not _bubble.visible and _bubble.text == ""


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event, true)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	root.push_input(event, true)


func _next(phase: String) -> void:
	_phase = phase
	_frames = 0


func _issues_for(rows: Array, id: String) -> Array:
	var tables := Registry.snapshot()
	tables["lore_rows.ROWS"] = rows
	return Registry.validate_table("lore_rows.ROWS", rows, tables, false).filter(func(issue): return issue["row"] == id)


func _check_registry() -> void:
	var shipped: Array = Registry.snapshot()["lore_rows.ROWS"].duplicate(true)
	var all := Registry.validate_table("lore_rows.ROWS", shipped, Registry.snapshot(), false)
	_t.eq("shipped intro rows validate", all, [])
	var no_stage := {"id": "lore.test.nostage", "kind": "intro", "zone": "9-1", "subject": "warden", "text": "Nobody home."}
	var wrong_boss := {"id": "lore.test.wrongboss", "kind": "intro", "zone": "2-1", "subject": "brindle", "text": "Wrong world."}
	var rows: Array = shipped.duplicate(true)
	rows.append(no_stage)
	rows.append(wrong_boss)
	var stage_issues := _issues_for(rows, "lore.test.nostage").filter(func(issue): return issue["detail"].contains("has no stage"))
	_t.check("zone with no stage is rejected", stage_issues.size() == 1, str(stage_issues))
	_t.check("second line for a boss the world lacks is rejected", _issues_for(rows, "lore.test.wrongboss").size() == 1, str(_issues_for(rows, "lore.test.wrongboss")))


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_frames += 1
	if _phase != "boot" and _frames < SETTLE_FRAMES:
		return false
	var spillway_warden := _intro("1-1", "warden")
	var reach_warden := _intro("1-2", "warden")
	var reach_boss := _intro("1-2", "brindle")
	var dig_boss := _intro("2-2", "waking")
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_bubble = _game.get_node("Workshop").bubble
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_next("warden")
		"warden":
			_bubble.dismiss_exchange()
			_game.flow._engage()
			_t.check("Warden line shows at engagement", _showing(spillway_warden), _bubble.text)
			_t.near("intro holds about four seconds", _bubble._hold, 4.0, 0.01)
			_game.flow.enter_stage(1, Vector3.ZERO, true)
			_next("again")
		"again":
			_game.flow._engage()
			_t.check("a second engagement in the same run shows nothing", _silent(), _bubble.text)
			_game.flow.enter_stage(2, Vector3.ZERO, false)
			_next("exchange")
		"exchange":
			_t.check("Reach exchange is playing", _bubble.visible and not _showing(reach_boss), _bubble.text)
			_game.events.boss_arena_entered.emit()
			_t.check("arena entry waits behind the exchange", not _showing(reach_boss), _bubble.text)
			_press("cl_interact")
			_press("cl_interact")
			_t.check("exchange still running before its last line", not _showing(reach_boss), _bubble.text)
			_press("cl_interact")
			_t.check("boss line shows after the exchange ends", _showing(reach_boss), _bubble.text)
			_press("cl_interact")
			_t.check("interact dismisses the intro", _silent(), _bubble.text)
			_game.events.boss_arena_entered.emit()
			_t.check("arena entry twice in a run shows nothing", _silent(), _bubble.text)
			_game.flow._engage()
			_t.check("Reach Warden line shows at engagement", _showing(reach_warden), _bubble.text)
			_game.flow.enter_stage(4, Vector3.ZERO, false)
			_next("paused")
		"paused":
			_bubble.dismiss_exchange()
			paused = true
			_game.events.boss_arena_entered.emit()
			_t.check("no intro while paused", _silent(), _bubble.text)
			paused = false
			_bubble._process(0.016)
			_t.check("intro plays once the pause lifts", _showing(dig_boss), _bubble.text)
			print("intro_lines_test: %s" % ("PASS" if _t.verdict() == 0 else "FAIL"))
			quit(_t.verdict())
			return true
	return false
