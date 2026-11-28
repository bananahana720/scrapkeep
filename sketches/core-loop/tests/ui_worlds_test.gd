extends SceneTree

const GameScript := preload("res://src/game.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")
const BossDouble := preload("res://tests/doubles/spine_boss_double.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")
const Worlds := preload("res://src/core/worlds.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")

# The HUD and screens on a two-world run (the six-stage double), then on the default and
# slice tables. Entering world two raises a card titled with the world's name before its
# first stage's card; the status pips count the current world's stages; the dead screen
# counts stages within the world and the replay label names the world's last stage; the
# victory and summary words come from the beaten world's boss row. A one-world table shows
# no world card. UI_WORLDS_DISABLE_CARD=1 turns the world card off, which is how the red
# run is shown.

const STAND_IN := {"name": "The Stand-in", "title": "STAND-IN ROUTED", "script": "res://src/boss/boss.gd", "kind": "standin",
	"music": "brindle", "built": true, "victory": "The stand-in is routed.", "epitaph": "The stand-in, routed in a test."}
const TICK_LIMIT := 60 * 60
const CARD_WAIT := 240

class TwoWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return TwoWorld

var _t := T.new("ui_worlds_test")
var _game
var _boss
var _phase := "double"
var _started := false
var _ticks := 0
var _last_stage := -1
var _titles: Array[String] = []
var _wait := 0
var _checked_five := false
var _checked_dead := false
var _checked_victory := false
var _victory_seen := false
var _three_i := 0
var _three_entered := false
var _three_world := 2
var _three_boss_done := false

# Stages 3 to 6 on the default table, pinned against the terrain's map titles.
const THREE_TITLES := ["Dig: the upper bench", "Dig: the deep works", "Highdraft", "Highdraft: the crown"]


func _initialize() -> void:
	_boot(TwoWorldGame.new())


func _boot(game) -> void:
	_game = game
	_game.test_mode = true
	root.add_child(_game)
	_started = false
	_ticks = 0
	_last_stage = -1
	_titles = []
	_wait = 0


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_start()
		return false
	_ticks += 1
	var card = _game.hud.launch_card
	if card.showing() and (_titles.is_empty() or _titles[-1] != card.title):
		_titles.append(card.title)
	match _phase:
		"double":
			return _double_step()
		"default":
			return _single_step("default", 2)
		"three":
			return _three_step()
		"slice":
			return _single_step("slice", 1)
	return false


func _start() -> void:
	_started = true
	if os_flag("UI_WORLDS_DISABLE_CARD"):
		_game.events.world_entered.disconnect(_game.hud._on_world_entered)
	if _phase == "double":
		_boss = BossDouble.new()
		_game.add_child(_boss)
		_boss.setup(_game.ctx)
		_game.flow.boss_row_override[2] = STAND_IN
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.player.source = Intent.Scripted.new()
	# The Mind's win opens the Q16 ending (fly-over, victory lap, credits); victory_lap_test owns it. This test ends on the summary.
	_game.flow.victory_lap = false
	_game.flow.press_start()
	_game.flow.choose_class(0)


func os_flag(name: String) -> bool:
	return OS.get_environment(name) == "1"


func _double_step() -> bool:
	if _ticks > TICK_LIMIT * 2:
		_t.check("double: timeout", false, "stalled in %s at stage %d" % [_game.flow.state_name(), _game.run.stage])
		return _finish()
	var flow = _game.flow
	var stage: int = _game.run.stage
	var name: String = flow.state_name()
	if name == "victory":
		if stage == 6 and not _checked_victory:
			_checked_victory = true
			_victory_checks()
		return false
	if name == "summary":
		_summary_checks()
		_phase = "default"
		_game.free()
		_boot(GameScript.new())
		return false
	if name == "boss":
		if stage == 6 and not _checked_dead:
			_checked_dead = true
			_dead_checks()
		_boss.defeat()
		return false
	if stage == 4 and not _carded:
		_wait += 1
		if _titles.has("Double: the top shelf") or _wait >= CARD_WAIT:
			_card_checks()
		return false
	if stage == 5 and not _checked_five:
		_checked_five = true
		_five_checks()
	if name in ["stage", "beacon", "gates", "launch"] and stage != _last_stage:
		_last_stage = stage
		flow._finish_stage()
	return false


var _carded := false


func _card_checks() -> void:
	_carded = true
	var dig := _titles.find("The Dig")
	var stage_four := _titles.find("Double: the top shelf")
	_t.check("W6-1 world two raises a card titled The Dig", dig >= 0, "cards seen %s" % [_titles])
	_t.check("W6-1 The Dig comes before the stage-4 card", dig >= 0 and stage_four > dig, "cards seen %s" % [_titles])
	_t.check("W6-1 world one is announced too on a two-world table", _titles.has("Spillway Works"), "cards seen %s" % [_titles])


func _five_checks() -> void:
	var status = _game.hud._status
	_game.hud._process(0.0)
	_t.eq("W6-2 stage 5 of the double: three pips", status.stages, 3)
	_t.eq("W6-2 stage 5 of the double: the second is current", status.stage, 2)
	_game.screens._on_flow_changed("dead")
	var text: String = _game.screens.body_text()
	_t.check("W6-3 dead screen offers a new run and no retry", text.contains("N   new run") and not text.contains("retry"), text.replace("\n", " | "))
	_game.screens._on_flow_changed(_game.flow.state_name())


func _dead_checks() -> void:
	var flow = _game.flow
	_game.hud._process(0.0)
	_t.check("W6-4 the HUD shows a boss in world two's arena when its stand-in row runs", _game.hud._status.has_boss, "has_boss false")
	_game.screens._on_flow_changed("dead")
	var text: String = _game.screens.body_text()
	_t.check("W6-3 world two's arena names the replay stage 3", text.contains("T   replay stage 3"), text.replace("\n", " | "))
	_t.eq("W6-3 the replay goes to stage 6", flow.final_stage(), 6)
	_game.screens._on_flow_changed(flow.state_name())


func _victory_checks() -> void:
	_t.eq("W6-4 victory title is the row that ran", _game.screens._title.text, String(STAND_IN["title"]))
	_t.eq("W6-4 victory body is that row's victory line", _game.screens.said_body(), String(STAND_IN["victory"]))


func _summary_checks() -> void:
	var epitaph := String(STAND_IN["epitaph"])
	_t.check("W6-4 the won summary shows the epitaph", _game.screens.said_body().contains(epitaph), _game.screens.said_body())
	_game.screens._victory_boss = STAND_IN
	_game.events.run_started.emit("runner_gunner")
	_t.check("W6-4 a new run forgets the last run's beaten boss", _game.screens._victory_boss.is_empty(), "%s" % [_game.screens._victory_boss])


func _single_step(label: String, stage: int) -> bool:
	if _ticks == 3:
		_game.flow.enter_stage(stage, Vector3(0.0, 0.0, 14.0), false)
	if _ticks == 6:
		_game.hud._process(0.0)
		var status = _game.hud._status
		_t.eq("%s: the pips read stage %d" % [label, stage], status.stage, stage)
		var tbl = _game.ctx.stages
		var world: int = tbl.world_of(stage)
		_t.eq("%s: the pips count the current world's stages" % label, status.stages, tbl.last_of(world) - tbl.first_of(world) + 1)
		var multi: bool = tbl.worlds().size() > 1
		_t.check("%s: the world card shows only on a multi-world table" % label,
			_titles.has("Spillway Works") == multi, "multi-world %s, cards seen %s" % [multi, _titles])
	if _ticks == 20:
		var first_card: String = "Spillway Works" if _game.ctx.stages.worlds().size() > 1 else String(_game.ctx.stages.of(1)["name"])
		_t.check("%s: the first card up is the world card on a multi-world table, else the stage card" % label,
			not _titles.is_empty() and _titles[0] == first_card, "cards seen %s" % [_titles])
		_game.free()
		if _phase == "default":
			_phase = "three"
			_three_i = 0
			_three_entered = false
			_boot(GameScript.new())
			return false
		return _finish()
	return false


func _three_step() -> bool:
	if _three_i < THREE_TITLES.size():
		var stage := 3 + _three_i
		if not _three_entered:
			if _game.hud.launch_card.showing() and _wait < CARD_WAIT * 2:
				_wait += 1
				return false
			_three_entered = true
			_titles = []
			_wait = 0
			_game.flow.enter_stage(stage, Vector3(0.0, 0.0, 14.0), false)
			return false
		_wait += 1
		var want: String = THREE_TITLES[_three_i]
		if not _titles.has(want) and _wait < CARD_WAIT:
			return false
		var tbl = _game.ctx.stages
		_t.eq("three: stage %d's own title is pinned" % stage, _game.ctx.terrain.map_for(stage).title, want)
		_t.check("three: stage %d card reads %s" % [stage, want], _titles.has(want), "cards seen %s" % [_titles])
		_game.hud._process(0.0)
		var world: int = tbl.world_of(stage)
		_t.eq("three: stage %d pips count two stages in the world" % stage, _game.hud._status.stages, 2)
		_t.eq("three: stage %d pips count the world's stages from the table" % stage, tbl.last_of(world) - tbl.first_of(world) + 1, 2)
		if stage == 3 or stage == 5:
			var world_name := "The Dig" if stage == 3 else "The Highdraft"
			var at := _titles.find(world_name)
			_t.check("three: stage %d raises the world card %s before its stage card" % [stage, world_name],
				at >= 0 and _titles.find(want) > at, "cards seen %s" % [_titles])
		_three_i += 1
		_three_entered = false
		return false
	var flow = _game.flow
	var boss_key := "waking" if _three_world == 2 else "mind"
	var row: Dictionary = Worlds.BOSSES[boss_key]
	if not _three_boss_done:
		Harness.enter_world(_game, _three_world)
		flow._on_boss_defeated()
		_three_boss_done = true
		_t.eq("three: world %d victory heading" % _three_world, _game.screens._title.text, String(row["title"]))
		_t.eq("three: world %d victory body" % _three_world, _game.screens.said_body(), String(row["victory"]))
		return false
	if _three_world == 2:
		_three_world = 3
		_three_boss_done = false
		_wait = 0
		return false
	if flow.state_name() == "summary":
		_t.check("three: the won summary reads RUN COMPLETE", _game.screens._title.text.contains("RUN COMPLETE"), _game.screens._title.text)
		_t.check("three: the summary body holds the Mind's epitaph", _game.screens.said_body().contains(String(row["epitaph"])), _game.screens.said_body())
		_game.free()
		_phase = "slice"
		var g = GameScript.new()
		g.table = "slice"
		_boot(g)
		return false
	_wait += 1
	if _wait > CARD_WAIT * 4:
		_t.check("three: summary reached", false, "stuck in %s" % flow.state_name())
		return _finish()
	return false


func _finish() -> bool:
	quit(_t.verdict())
	return true
