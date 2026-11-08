extends SceneTree

# The seed invariants from the invariants pass (2026-11-08): a stage's plan, fabricators and
# offers come from (session seed, run seed, stage), so how much of the shared stream the stage
# before it spent, a retry, or a Continue does not change them; the shelf does not move with the
# shop's stock count; a part kept while more arrive never sells back for more than it cost; and
# the boost never recharges faster than its physics-safe floor.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const Tuning := preload("res://src/movement/tuning.gd")

var t := T.new("seed_streams_test")
var game


func _initialize() -> void:
	_run.call_deferred()


func _plan() -> Dictionary:
	var fabs := []
	for fab in game.build.fabricators.records():
		fabs.append([fab["part_id"], fab["at"]])
	var gate := []
	var rng: RandomNumberGenerator = game.build._offer_rng("gates")
	for i in 4:
		gate.append(rng.randi())
	return {"stage_seed": game.world._stage_seed, "fabs": fabs, "gate": gate, "stream": game.ctx.rng.state}


func _enter(stage: int, retry: bool) -> Dictionary:
	game.flow.enter_stage(stage, Vector3.ZERO, retry)
	for i in 4:
		await physics_frame
	return _plan()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.ctx.calm = true
	await _enter(1, false)
	var first: Dictionary = await _enter(2, false)
	# A heavy stage 1 (many kills and drops) spends more of the shared stream before stage 2.
	await _enter(1, false)
	for i in 97:
		game.ctx.rng.randi()
	var heavy: Dictionary = await _enter(2, false)
	t.eq("stage 2's event plan does not move with stage 1's draws", heavy["stage_seed"], first["stage_seed"])
	t.check("stage 2's fabricators do not move with stage 1's draws", heavy["fabs"] == first["fabs"] and not first["fabs"].is_empty(),
		"%s vs %s" % [heavy["fabs"], first["fabs"]])
	t.eq("stage 2's gate stream does not move with stage 1's draws", heavy["gate"], first["gate"])
	# A fabricator used mid-stage draws from the shared stream; the real retry (R, or T on the
	# death screen) goes through Flow.retry_stage, not enter_stage.
	for i in 13:
		game.ctx.rng.randi()
	game.flow.retry_stage()
	for i in 4:
		await physics_frame
	var retried: Dictionary = _plan()
	t.check("a retry replays the plan, fabricators and gates", retried["stage_seed"] == first["stage_seed"]
		and retried["fabs"] == first["fabs"] and retried["gate"] == first["gate"], "%s vs %s" % [retried, first])
	t.eq("the stage reseed keeps the session seed device luck reads", game.ctx.rng.seed, Game.SEED)
	# A headless test names no run seed: its stages do not follow the clock-made run id.
	t.eq("a test run with no run seed keeps one route", game.flow.run_key(), 0)
	game.ctx.run.run_seed_override = 5
	t.eq("a run seed set on purpose draws its own stages", game.flow.run_key(), game.ctx.run.run_seed)
	game.ctx.run.run_seed_override = null
	_shop()
	_sell()
	_boost_floor()
	quit(t.verdict())


func _shop() -> void:
	var shop = game.build.shop
	var here := [game.ctx.run.world, game.ctx.run.stage]
	shop.stocks = 0
	shop._stock_stage(here)
	var fresh: Array = shop.shelf.map(func(entry): return entry["part_id"])
	# A Continue makes a new shop whose stock count starts again; bay hops add stocks.
	shop.stocks = 5
	shop._stock_stage(here)
	var later: Array = shop.shelf.map(func(entry): return entry["part_id"])
	t.check("the shelf names the run and stage, not the stock count", fresh == later and not fresh.is_empty(), "%s vs %s" % [fresh, later])


func _sell() -> void:
	var run = game.ctx.run
	var shop = game.build.shop
	var part_id := "boost_coil"
	run.parts.clear()
	var paid: int = int(round(Fabricators.price(part_id, run.parts.size()) * shop._price_scale()))
	run.parts.append(part_id)
	for id in ["tread_plating", "dash_vane", "tread_plating", "dash_vane", "tread_plating", "dash_vane"]:
		run.parts.append(id)
	var quote: int = shop.sell_quote(part_id)
	t.check("a part bought at N and sold at N+6 is not a profit", quote >= 0 and quote <= paid, "paid %d quote %d" % [paid, quote])


func _boost_floor() -> void:
	var tuning = game.tuning
	var kept: float = tuning.boost_cooldown_scale
	for scale in [0.05, 0.0, -1.0]:
		tuning.boost_cooldown_scale = scale
		t.check("boost cooldown at scale %s holds the floor" % scale, tuning.boost_cooldown() >= Tuning.BOOST_COOLDOWN_FLOOR)
	tuning.boost_cooldown_scale = 1.0
	t.near("an unstacked boost keeps its cooldown", tuning.boost_cooldown(), Tuning.BOOST_COOLDOWN, 0.0001)
	tuning.boost_cooldown_scale = kept
