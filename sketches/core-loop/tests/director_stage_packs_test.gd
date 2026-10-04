extends SceneTree

const RowPacks := preload("res://tests/doubles/row_packs_defs.gd")
const Director := preload("res://src/world/director.gd")
const T := preload("res://tests/support/t.gd")

# A stage row's own packs, elite and elite_arrival reach the director on stage entry; a row
# without them keeps the table's. A pack kind the director cannot spawn is skipped with one
# warning, never spawned as index -1.

class RowPacksGame extends "res://src/game.gd":
	func _chosen_table():
		return RowPacks

const H := 1.0 / 90.0
const ARRIVALS := 6
const STEP_LIMIT := 90 * 120
const FRAME_LIMIT := 60 * 20

var _t := T.new("director_stage_packs_test")
var _game


func _initialize() -> void:
	_game = RowPacksGame.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _finish() -> void:
	_game.free()
	quit(_t.verdict())


# Steps the director headless until `count` arrivals are due; returns their kind names.
func _due_kinds(d, count: int) -> Array:
	var kinds: Array = []
	var steps := 0
	while kinds.size() < count and steps < STEP_LIMIT:
		steps += 1
		for spawn in d.advance(H, 0):
			kinds.append(Director.KIND_NAMES[spawn["kind"]] if spawn["kind"] >= 0 else "index -1")
	return kinds


func _all(kinds: Array, kind: String) -> bool:
	return kinds.size() >= ARRIVALS and kinds.all(func(k: String) -> bool: return k == kind)


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	var flow = _game.flow
	_game.ctx.calm = true
	flow.press_start()
	flow.choose_class(0)
	var frames := 0
	while _game.run.stage != 1 and frames < FRAME_LIMIT:
		frames += 1
		await physics_frame
	_t.eq("on stage 1", _game.run.stage, 1)
	var d = _game.world.director
	_t.eq("stage 1 (no packs key): the table's packs", d.authored, RowPacks.PACKS)
	_t.eq("stage 1: the table's elite", d.elite, RowPacks.elite())
	var kinds := _due_kinds(d, ARRIVALS)
	_t.check("stage 1: every arrival a lobber", _all(kinds, "lobber"), str(kinds))

	flow._finish_stage()
	frames = 0
	while _game.run.stage != 2 and frames < FRAME_LIMIT:
		frames += 1
		await physics_frame
	_t.eq("on stage 2", _game.run.stage, 2)
	d = _game.world.director
	_t.eq("stage 2: the row's packs", d.authored, RowPacks.DEFS[1]["packs"])
	_t.check("stage 2: the row's empty elite", d.elite.is_empty(), str(d.elite))
	_t.eq("stage 2: the row's elite_arrival", d.elite_arrival, 0)
	kinds = _due_kinds(d, ARRIVALS)
	_t.check("stage 2: every arrival a chaser", _all(kinds, "chaser"), str(kinds))

	_game.world.director = Director.new(7)
	_game.world._author_director({"packs": [{"id": "bad", "kinds": ["nonesuch"]}], "elite": {}, "elite_arrival": 0})
	d = _game.world.director
	var t := 0.0
	var minus_one := 0
	while d.packs.size() < 3 and t < 120.0:
		t += H
		for spawn in d.advance(H, 0):
			if spawn["kind"] == -1:
				minus_one += 1
		for arrival in d.arrivals:
			if arrival["kind"] == -1:
				minus_one += 1
	_t.check("scratch row: the nonesuch pack was drawn", d.packs.size() >= 3, "%d packs" % d.packs.size())
	_t.eq("scratch row: no arrival with kind -1", minus_one, 0)
	_t.eq("scratch row: nothing arrives", d.arrivals.size(), 0)
	_t.eq("scratch row: one warning", d.unknown_kinds.keys(), ["nonesuch"])
	_finish()
