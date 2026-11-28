extends SceneTree

const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const Director := preload("res://src/world/director.gd")
const Cards := preload("res://src/core/director_cards.gd")
const T := preload("res://tests/support/t.gd")

# The spawn director takes the stage's counter unlock level and ancient enemy from the
# stage row the world hands it on entry; with no row it still guesses from the threat.

class TwoWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return TwoWorld

var _t := T.new("director_rows_test")
var _game
var _frames := 0
var _done := false


func _initialize() -> void:
	_game = TwoWorldGame.new()
	_game.test_mode = true
	root.add_child(_game)
	_unit()


func _unit() -> void:
	for table in [StageDefs, SliceDefs, TwoWorld]:
		for row in table.DEFS:
			_t.check("row %d carries unlock_base and ancient" % row["stage"],
				row.has("unlock_base") and Director.KIND_NAMES.has(row["ancient"]))
	var d := Director.new(1)
	d.threat = 1.0
	_t.eq("no row: threat guess unlock", d.unlocked_counters().size(), 2)
	d.use_row(TwoWorld.of(5))
	_t.eq("a row: unlock base 5", d.unlocked_counters().size(), 5)
	d.use_row({})
	_t.eq("an empty row clears it", d.unlocked_counters().size(), 2)


func _physics_process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	if _game.flow == null or _frames < 3:
		return false
	_enter(5, 5, "reactor_relic")
	_enter(2, 4, "swarm_remnant")
	_enter(4, 3, "mind_hand")
	_enter(6, 7, "swarm_remnant")
	_no_dispatcher()
	_done = true
	quit(_t.verdict())
	return true


# The dispatcher is a card, not a random draw: composed packs never hold one, so every existing
# director output is unchanged until an authored pack names it.
func _no_dispatcher() -> void:
	var d = _game.world.director
	d.stage_time = Director.TIER_SECONDS * 2
	var seen := 0
	var dispatchers := 0
	for i in 400:
		var pack: Array = d.compose()
		seen += 1
		dispatchers += int(pack.has("dispatcher"))
	_t.check("composed packs were drawn", seen == 400)
	_t.eq("no composed pack holds a dispatcher", dispatchers, 0)
	# Planted negative control: the same count over a pack that holds one must see it.
	_t.eq("negative control: the counter sees a planted dispatcher", int(["chaser", "dispatcher"].has("dispatcher")), 1)
	_t.check("the kind is placeable", Director.KIND_NAMES.has("dispatcher") and is_finite(Cards.cost(["dispatcher"])))
	_t.check("a second one in a purchase is INF", not is_finite(Cards.cost(["dispatcher", "dispatcher"])))


func _enter(stage: int, unlock: int, ancient: String) -> void:
	_game.ctx.run.stage = stage
	_game.events.stage_entered.emit(stage, false)
	var d = _game.world.director
	_t.eq("stage %d: unlock base" % stage, d.unlocked_counters().size(), unlock)
	d.stage_time = Director.TIER_SECONDS * 2
	var got := ""
	for i in 400:
		var pack: Array = d.compose()
		if pack.size() == 1 and Director.KIND_NAMES.find(pack[0]) >= 13:
			got = pack[0]
			break
	_t.eq("stage %d: ancient" % stage, got, ancient)
