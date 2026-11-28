extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const Shop := preload("res://src/build/shop.gd")

# The shop's top hook on the park table (world 1 design pass, 9 Nov). The Spare Frame is that
# table's only relic, so it is the hook until held (ruling of 24 Oct). Once it was held the hook
# fell back to the shelf's rarities and Moss kept a common off the shelf behind the heft lock
# (probe on stage/alpha-w33 c5425bf9: Arc Coil for 18 cogs at stage 2, three pilots of three).
# Now a held Spare Frame leaves a cobalt on the hook, the top ordinary rung of the alpha (ruling
# bn), never a part on the shelf, with the odds of the table it was drawn from; the heft lock,
# the once-per-stage stock (ruling as) and a retry's rewind are as before. A table that lists no
# relic (alpha, slice, the default) has nothing to run out of: its hook draws as it always did.
# smoke: timeout=240s

const PILOTS := 6
const STAGES := [2, 3, 4]

var _t := preload("res://tests/support/t.gd").new("shop_hook_stock_test")
var _game


func _initialize() -> void:
	_run()


func _run() -> void:
	for pilot in PILOTS:
		_game = Game.new()
		_game.test_mode = true
		_game.table = "park"
		root.add_child(_game)
		while _game.flow == null:
			await physics_frame
		_game.player.source = Intent.Scripted.new()
		_game.world.set_physics_process(false)
		_game.world.activities.set_physics_process(false)
		_game.flow.press_start()
		_game.flow.choose_class(pilot)
		await physics_frame
		_check(pilot == 0)
		_game.free()
		await physics_frame
	await _no_relic_table()
	quit(_t.verdict())


# The alpha table lists no relic, so the cobalt fallback never applies: the hook is the old draw
# (the shelf's rarities after an empty relic roll) and shows the shelf's odds.
func _no_relic_table() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.player.source = Intent.Scripted.new()
	_game.world.set_physics_process(false)
	_game.world.activities.set_physics_process(false)
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await physics_frame
	var run = _game.ctx.run
	var shop = _game.ctx.build.shop
	var who: String = run.class_id()
	shop.enter()
	var hook: Dictionary = shop.top_shelf()
	_t.check("a table with no relic keeps the old hook draw and the shelf's odds", Parts.offer_pool(who, Shop.TOP_RARITIES).is_empty()
		and not hook.is_empty() and shop.top["table"] == Shop.SHELF_RARITIES and hook["odds"] == Parts.odds_for(Shop.SHELF_RARITIES, who),
		"hook %s, table %s" % [hook.get("part_id"), shop.top.get("table")])
	shop.leave()
	_game.free()
	await physics_frame


func _check(deep: bool) -> void:
	var run = _game.ctx.run
	var shop = _game.ctx.build.shop
	var who: String = run.class_id()
	run.cogs = 5000
	shop.enter()
	var first: Dictionary = shop.top_shelf()
	_t.check("%s: the hook is the Spare Frame until held" % who, first.get("part_id", "") == "spare_frame"
		and first["odds"] == Parts.odds_for(Shop.TOP_RARITIES, who), "hook %s, odds %s" % [first.get("part_id"), first.get("odds")])
	shop.leave()
	run.add_part("spare_frame", "test")
	var bad: Array = []
	var hooks: Array = []
	for stage in STAGES:
		run.stage = stage
		shop.enter()
		var hook: Dictionary = shop.top_shelf()
		var id: String = hook.get("part_id", "")
		hooks.append(id)
		var on_shelf: bool = shop.shelf.any(func(entry): return entry["part_id"] == id)
		if id == "" or Parts.rung_of(id) < Parts.RUNG_FLOOR or Parts.rarity_of(id) != "rare" or on_shelf or id in run.parts \
				or hook["odds"] != Parts.odds_for(Shop.TOP_FALLBACK, who) or not hook["locked"] \
				or hook["needs_class"] != run.heft_class() + 1:
			bad.append("stage %d: %s" % [stage, hook])
		shop.leave()
	_t.check("%s: with the Spare Frame held the hook is a cobalt off the shelf, heft-locked, with cobalt odds" % who,
		bad.is_empty(), "hooks %s; wrong %s" % [hooks, bad])
	if not deep:
		return
	# The stock is once per stage: a second visit finds the same hook, and so does a retry's rewind.
	run.stage = STAGES[0]
	shop.enter()
	var kept: String = shop.top_shelf()["part_id"]
	shop.leave()
	shop.enter()
	var again: String = shop.top_shelf()["part_id"]
	shop.leave()
	shop.rewind_stage()
	shop.enter()
	var rewound: Dictionary = shop.top_shelf()
	_t.check("the cobalt hook is stocked once per stage and a retry puts it back", kept == hooks[0] and again == kept
		and rewound["part_id"] == kept and rewound["odds"] == Parts.odds_for(Shop.TOP_FALLBACK, who),
		"first %s, re-entry %s, rewind %s" % [kept, again, rewound["part_id"]])
	# The lock still holds a light ball off, and a heavy one buys it at the shown price.
	var refused: Dictionary = shop.buy_top()
	_t.check("a light ball is refused the cobalt hook", not refused["ok"] and refused["reason"] == Shop.LOCKED, var_to_str(refused))
	shop.top["lock_class"] = run.heft_class()
	var cogs_before: int = run.cogs
	var price: int = shop.top_shelf()["price"]
	var bought: Dictionary = shop.buy_top()
	_t.check("a heavy enough ball buys it at the shown price", bought["ok"] and kept in run.parts and run.cogs == cogs_before - price,
		"%s, cogs %d to %d at price %d" % [bought["reason"], cogs_before, run.cogs, price])
	shop.leave()
