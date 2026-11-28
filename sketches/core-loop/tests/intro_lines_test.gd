extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const Registry := preload("res://tests/support/content_registry.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Worlds := preload("res://src/core/worlds.gd")

# Intro lines: the Warden's row plays when warden_sighted fires, before the fight, and clears
# when warden_engaged fires; the boss's row plays when boss_arena_entered fires. Each plays once per run and zone, waits out an exchange and a
# pause, and the registry keeps the rows on real zones with the boss their world owns. Every
# boss has one threat line per pilot at its arena zone, and the pilot's line wins there.

const ARENA_ZONES := {"brindle": "1-2", "waking": "2-2", "mind": "3-2"}

const SETTLE_FRAMES := 12

var _game
var _bubble
var _phase := "boot"
var _frames := 0
var _t := T.new("intro_lines_test")


# The ball reaches the Warden's spot: flow's own sighting read, as its frame would run it.
func _sight() -> void:
	_game.flow._read_sighting(_game.flow._warden_at)


func _initialize() -> void:
	_check_registry()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)


func _intro(zone: String, subject: String, pilot := "") -> Dictionary:
	for row in LoreRows.ROWS:
		if row["kind"] == "intro" and row["zone"] == zone and row["subject"] == subject and row.get("pilot", "") == pilot:
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
	var pilots: Array = ClassDef.all().map(func(p): return p.id)
	_t.eq("six pilots", pilots.size(), 6)
	_t.eq("three bosses", ARENA_ZONES.keys().size(), Worlds.BOSSES.size())
	for boss in Worlds.BOSSES:
		for pilot in pilots:
			var found := shipped.filter(func(row): return row["kind"] == "intro" and row.get("subject") == boss and row.get("pilot") == pilot)
			_t.check("%s has one threat line for %s" % [boss, pilot], found.size() == 1, str(found.size()))
			_t.check("%s line for %s sits at the arena zone" % [boss, pilot], found.size() == 1 and found[0]["zone"] == ARENA_ZONES[boss], str(found))
	var pilot_lines := shipped.filter(func(row): return row["kind"] == "intro" and row.has("pilot"))
	_t.eq("eighteen threat lines", pilot_lines.size(), 18)
	var early := {"id": "lore.test.early", "kind": "intro", "zone": "1-1", "subject": "brindle", "pilot": "tally", "text": "Too soon."}
	var stranger := {"id": "lore.test.stranger", "kind": "intro", "zone": "1-2", "subject": "brindle", "pilot": "nobody", "text": "Who?"}
	var warden_pilot := {"id": "lore.test.wardenpilot", "kind": "intro", "zone": "1-2", "subject": "warden", "pilot": "tally", "text": "Not mine."}
	rows = shipped.duplicate(true)
	rows.append_array([early, stranger, warden_pilot])
	_t.check("pilot line before the arena zone is rejected", _issues_for(rows, "lore.test.early").size() == 1, str(_issues_for(rows, "lore.test.early")))
	_t.check("pilot line for an unknown pilot is rejected", _issues_for(rows, "lore.test.stranger").size() == 1, str(_issues_for(rows, "lore.test.stranger")))
	_t.check("pilot line on a Warden is rejected", _issues_for(rows, "lore.test.wardenpilot").size() == 1, str(_issues_for(rows, "lore.test.wardenpilot")))


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_frames += 1
	if _phase != "boot" and _frames < SETTLE_FRAMES:
		return false
	var spillway_warden := _intro("1-1", "warden")
	var reach_warden := _intro("1-2", "warden")
	var pilot: String = _game.run.class_id()
	var reach_boss := _intro("1-2", "brindle", pilot)
	var dig_boss := _intro("2-2", "waking", pilot)
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_bubble = _game.get_node("Workshop").bubble
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_next("warden")
		"warden":
			# A test's run has no opening: the cold open's card starts with the stage, and the
			# hello and the Warden's line wait for a card (bubble_gives_way_test).
			_game.presentation.flourish.stop_all()
			_bubble._process(0.016)
			_bubble.dismiss_exchange()
			_sight()
			_t.check("Warden line shows at the sighting", _showing(spillway_warden), _bubble.text)
			_t.near("intro holds about four seconds", _bubble._hold, 4.0, 0.01)
			_game.flow._engage()
			_t.check("engagement clears the Warden line", _silent(), _bubble.text)
			_game.flow.enter_stage(1, Vector3.ZERO, true)
			_next("again")
		"again":
			_sight()
			_t.check("a second sighting in the same run shows nothing", _silent(), _bubble.text)
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
			_t.check("pilot's own boss line is the one queued", pilot != "" and not reach_boss.is_empty(), pilot)
			_t.check("boss line shows after the exchange ends", _showing(reach_boss), _bubble.text)
			_press("cl_interact")
			_t.check("interact dismisses the intro", _silent(), _bubble.text)
			_game.events.boss_arena_entered.emit()
			_t.check("arena entry twice in a run shows nothing", _silent(), _bubble.text)
			# The arena's own beat would hold the Warden's line. Arena, then a sighting, is this
			# test's order and not a run's.
			_game.presentation.flourish.stop_all()
			_sight()
			_t.check("Reach Warden line shows at the sighting", _showing(reach_warden), _bubble.text)
			_game.flow._engage()
			_t.check("Reach engagement clears it", _silent(), _bubble.text)
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
