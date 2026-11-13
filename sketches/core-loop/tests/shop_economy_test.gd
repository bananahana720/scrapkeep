extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Shop := preload("res://src/build/shop.gd")
const Items := preload("res://src/build/items.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const REROLL_BASE: int = Fabricators.COG_PRICES["reroll_base"]

# Moss's workshop economy (DESIGN-V2 section 12), as Rivet, whose sprint and special
# both recharge:
#   - entering stocks a visible shelf of three and pauses the difficulty clock, and
#     Moss greets with his first-visit line;
#   - short of scrap, a buy spends nothing and Moss says so; a buy adds the part, and a
#     sold slot stays sold;
#   - one reroll per visit at its price, then no more;
#   - charge cells raise max_charges one at a time, cost more each time, and stop at
#     the shop's cap;
#   - sell-back refunds half and leaves heft where it was (parts add none under armour); a pattern part stays
#     welded until run_state can take a part back;
#   - the hook is locked a heft class up; the talk key walks the six beats, restarts,
#     never repeats a variation inside a visit, and relents once the ball is heavy
#     enough, which unlocks the hook and writes "Too heavy for you" to the codex;
#   - leaving says the leaving bark and restarts the clock; dying after leaving
#     empty-handed with a shelf part's worth of scrap is what Moss notices next visit.

var _game
var _build
var _shop
var _failures := 0
var _ticks := 0
var _phase := 0
var _wait := 0
var _paused_at := 0.0
var _stage_at := 0.0
var _locked_buy := {}


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
		_build = _game.ctx.build
		_shop = _build.shop
		return false
	if _ticks < 12:
		return false
	match _phase:
		0:
			_check_enter()
			_paused_at = _build.clock.difficulty_seconds
			_stage_at = _build.clock.stage_seconds
			_phase = 1
		1:
			_wait += 1
			if _wait >= 20:
				_check_paused()
				_check_talk()
				_check_shelf()
				_check_reroll()
				_check_charges()
				_check_sell()
				_check_relent()
				_check_leave()
				_check_neglect()
				return _finish()
	return false


func _check_enter() -> void:
	var greeting: Dictionary = _shop.enter()
	var offers: Array = _shop.shelf_offers()
	var complete := offers.all(func(o): return o["price"] > 0 and String(o["icon"]).begins_with("cat_") and o["name"] != "")
	_report("enter", greeting["line_id"] == "moss.remember.first_visit" and offers.size() == Shop.SHELF_SIZE and complete
			and _build.clock_paused(),
		"greeting '%s'; shelf %s; difficulty clock paused %s" % [greeting["text"], offers.map(func(o): return "%s %d" % [o["name"], o["price"]]), _build.clock_paused()])


func _check_paused() -> void:
	var moved: float = _build.clock.difficulty_seconds - _paused_at
	var stage_moved: float = _build.clock.stage_seconds - _stage_at
	_report("clock paused inside", moved == 0.0 and stage_moved > 0.1 and _build.clock_record()["difficulty"]["paused"],
		"20 ticks in the bay: difficulty clock +%.2f s, stage clock +%.2f s (the par timer keeps running)" % [moved, stage_moved])


func _check_shelf() -> void:
	var broke: Dictionary = _shop.buy(0)
	var price: int = _shop.shelf_offers()[0]["price"]
	_game.run.add_cogs(price)
	var before: int = _game.run.parts.size()
	var wallet: int = _game.run.cogs
	var bought: Dictionary = _shop.buy(0)
	var again: Dictionary = _shop.buy(0)
	_report("shelf", not broke["ok"] and broke["reason"] == Shop.CANT_AFFORD and broke["bark"]["line_id"] == "moss.bark.cant_afford"
			and bought["ok"] and _game.run.parts.size() == before + 1 and _game.run.cogs == wallet - price
			and bought["bark"]["line_id"] == "moss.bark.buy" and again["reason"] == Shop.SOLD_OUT,
		"broke: %s '%s'; bought %s for %d cogs ('%s'); the same slot again: %s"
			% [broke["reason"], broke["bark"]["text"], bought["part_id"], price, bought["bark"]["text"], again["reason"]])


func _check_reroll() -> void:
	_game.run.add_cogs(40)
	var price: int = _shop.reroll_price()
	var first: Dictionary = _shop.reroll()
	var second: Dictionary = _shop.reroll()
	var fresh: bool = _shop.shelf_offers().all(func(o): return not o["sold"])
	_report("one reroll", first["ok"] and first["price"] == REROLL_BASE and price == REROLL_BASE and fresh
			and not second["ok"] and second["reason"] == Shop.NO_REROLL and first["bark"]["line_id"] == "moss.bark.reroll",
		"reroll for %d: %s ('%s'), a fresh shelf %s; a second: %s" % [price, first["ok"], first["bark"]["text"], fresh, second["reason"]])


func _check_charges() -> void:
	_game.run.add_cogs(200)
	var slots: Array = _shop.charge_offers().map(func(o): return o["slot"])
	var prices: Array = []
	var maxes: Array = []
	var results: Array = []
	for i in 3:
		var offer: Dictionary = _shop.charge_offers().filter(func(o): return o["slot"] == "movement")[0]
		prices.append(offer["price"])
		var r: Dictionary = _shop.buy_charge("movement")
		results.append(r["reason"])
		maxes.append(_game.player.abilities.slot("movement").max_charges)
	var line: String = _shop.LINES["moss.bark.charge"]
	_report("charge cells", "movement" in slots and "special" in slots and not "weapon" in slots
			and results == [Shop.OK, Shop.OK, Shop.CAPPED] and maxes == [2, 3, 3] and prices[1] > prices[0],
		"Rivet can stock %s; three buys %s at %s cogs; movement max_charges %s; bark '%s'" % [slots, results, prices, maxes, line])


func _check_sell() -> void:
	var run = _game.run
	run.add_part("light_frame", "test")
	run.add_part("cross_split", "test")
	var heft: float = run.heft()
	var parts: int = run.parts.size()
	var wallet: int = run.cogs
	var quote: int = _shop.sell_quote("light_frame")
	var sold: Dictionary = _shop.sell("light_frame")
	var welded: Dictionary = _shop.sell("cross_split")
	_report("sell-back", sold["ok"] and quote > 0 and run.cogs == wallet + quote and run.parts.size() == parts - 1
			and absf(run.heft() - heft) < 0.001 and sold["bark"]["line_id"] == "moss.bark.sell"
			and not welded["ok"] and welded["reason"] == Shop.WELDED,
		"sold Light Frame for %d (half of %d): heft %.2f -> %.2f (unchanged under armour), '%s'; Cross Split: %s"
			% [quote, _shop.price("light_frame"), heft, run.heft(), sold["bark"]["text"], welded["reason"]])


func _check_talk() -> void:
	var top: Dictionary = _shop.top_shelf()
	_locked_buy = _shop.buy_top()
	var beats: Array = []
	var lines: Array = []
	for i in 7:
		var t: Dictionary = _shop.talk()
		beats.append(t["beat_id"])
		lines.append(t["line_id"])
	var second: Array = []
	for i in 6:
		second.append(_shop.talk()["line_id"])
	var first_loop: Array = lines.slice(0, 6)
	var repeats: Array = second.filter(func(id): return id in first_loop and _variants(id) > 1)
	var rivet_line := lines.has("moss.refuse.rivet") or second.has("moss.refuse.rivet")
	var no_foreign := not (lines + second).any(func(id): return id in ["moss.ask.sable", "moss.plead.kest"])
	_report("talk loop", top["locked"] and top["needs_class"] == top["heft_class"] + 1 and top["lock_icon"] == "res_heft"
			and beats == ["ask", "refuse", "insist", "double_down", "plead", "send_off", "restart"] and repeats.is_empty() and no_foreign,
		"hook %s locked until class %d (now %d); beats %s; second loop %s shares no line with the first; Rivet's own line heard %s"
			% [top["name"], top["needs_class"], top["heft_class"], beats, second, rivet_line])


func _variants(line_id: String) -> int:
	var beat := line_id.split(".")[1]
	return Shop.LINES.keys().filter(func(id): return id.begins_with("moss.%s." % beat)).size()


func _check_relent() -> void:
	var run = _game.run
	var need: int = _shop.top_shelf()["needs_class"]
	var locked_buy: Dictionary = _locked_buy
	while run.heft_class() < need:
		run.add_scrap(40, Vector3.ZERO)
	run.add_cogs(400)
	var t: Dictionary = _shop.talk()
	var top: Dictionary = _shop.top_shelf()
	var known: bool = _game.codex.known(Shop.CODEX_ID)
	var bought: Dictionary = _shop.buy_top()
	_report("relent", not locked_buy["ok"] and locked_buy["reason"] == Shop.LOCKED and t["relent"]
			and String(t["line_id"]).begins_with("moss.relent.") and not top["locked"] and known and bought["ok"],
		"locked buy: %s '%s'; at class %d the talk key says '%s', the hook unlocks, the codex knows it %s, bought %s"
			% [locked_buy["reason"], locked_buy["bark"]["text"], run.heft_class(), t["text"], known, bought["part_id"]])


func _check_leave() -> void:
	var bye: Dictionary = _shop.leave()
	_report("leave", bye["line_id"] == "moss.bark.leaving" and not _build.clock_paused(),
		"'%s'; difficulty clock paused %s" % [bye["text"], _build.clock_paused()])


func _check_neglect() -> void:
	_shop.enter()
	var cheapest: int = _shop.shelf_offers().map(func(o): return o["price"]).min()
	_shop.leave()
	_game.run.add_cogs(cheapest + 5)
	_shop.note_death(_game.run.cogs)
	var greeting: Dictionary = _shop.enter()
	_report("neglect callback", greeting["line_id"] == "moss.remember.neglected",
		"left empty-handed, died holding %d cogs (a shelf part is %d): next visit '%s'" % [_game.run.cogs, cheapest, greeting["text"]])


func _finish() -> bool:
	print("shop_economy_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
