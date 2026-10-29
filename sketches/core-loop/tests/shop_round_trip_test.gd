extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Items := preload("res://src/build/items.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const SELL_SHARE: float = Fabricators.COG_PRICES["sell_share"]

# A buy at Moss's counter sold straight back never pays (greedy red team, w24). As Rivet, whose
# sprint and special both recharge, at 0, 7, 10 and 20 parts held:
#   - five charge-cell buy-and-sell loops on each recharging slot leave the wallet no fuller,
#     both from no cells and with one cell already fitted (buying and selling the second);
#   - a cell sells for half the price its last buy cost;
#   - a shelf part bought and sold back leaves the wallet no fuller.
# The red team's 20-part read before the fix was +111 cogs over the loops.

const HELD := [0, 7, 10, 20]
const LOOPS := 5

var _game
var _shop
var _failures := 0
var _ticks := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(1)
		_shop = _game.ctx.build.shop
		return false
	if _ticks < 12:
		return false
	_shop.enter()
	for held in HELD:
		_pad_to(held)
		_check_cells(held)
		_check_shelf(held)
	_shop.leave()
	print("shop_round_trip_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _pad_to(held: int) -> void:
	var run = _game.run
	while run.parts.size() < held:
		run.add_part("light_frame", "test")


func _check_cells(held: int) -> void:
	var run = _game.run
	var slots: Array = _shop.charge_offers().map(func(o): return o["slot"])
	var gains: Array = []
	var halves := true
	for slot in slots:
		var part_id: String = Items.CELLS_FOR[slot]
		for fitted in 2:
			run.add_cogs(500)
			if fitted == 1:
				_shop.buy_charge(slot)
			var start: int = run.cogs
			for i in LOOPS:
				var bought: Dictionary = _shop.buy_charge(slot)
				if not bought["ok"]:
					_report("cell buy %s at %d" % [slot, held], false, "buy refused: %s" % bought["reason"])
					return
				var quote: int = _shop.sell_quote(part_id)
				halves = halves and quote == int(floor(bought["price"] * SELL_SHARE))
				_shop.sell(part_id)
			gains.append(run.cogs - start)
			if fitted == 1:
				_shop.sell(part_id)
	_report("cell round trip at %d held" % held, slots.size() >= 2 and gains.all(func(g): return g < 0) and halves,
		"%d loops on %s, from 0 and from 1 cell: wallet change %s; each cell sells for half its price %s" % [LOOPS, slots, gains, halves])


func _check_shelf(held: int) -> void:
	var run = _game.run
	_shop.rewind_stage()
	var offers: Array = _shop.shelf_offers().filter(func(o): return not o["sold"])
	run.add_cogs(500)
	var start: int = run.cogs
	var bought: Dictionary = _shop.buy(offers[0]["index"]) if not offers.is_empty() else {"ok": false, "part_id": "", "price": 0}
	var quote: int = _shop.sell_quote(bought["part_id"])
	var sold: Dictionary = _shop.sell(bought["part_id"])
	var gain: int = run.cogs - start
	_report("shelf round trip at %d held" % held, bought["ok"] and sold["ok"] and gain < 0,
		"bought %s for %d, sold back for %d: wallet change %d" % [bought["part_id"], bought["price"], quote, gain])
