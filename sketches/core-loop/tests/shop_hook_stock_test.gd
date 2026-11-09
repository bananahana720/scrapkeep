extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const Shop := preload("res://src/build/shop.gd")
const OddsReadout := preload("res://src/ui/odds_readout.gd")

# The shop's top hook on the park table (world 1 design pass, 9 Nov). The Spare Frame is that
# table's only relic, so it is the hook until held (ruling of 24 Oct). Once it was held the hook
# fell back to the shelf's rarities and Moss kept a common off the shelf behind the heft lock
# (probe on stage/alpha-w33 c5425bf9: Arc Coil for 18 cogs at stage 2, three pilots of three).
# Now a held Spare Frame leaves a cobalt on the hook, the top ordinary rung of the alpha (ruling
# bn), never a part on the shelf, with the odds of the table it was drawn from; the heft lock,
# the once-per-stage stock (ruling as) and a retry's rewind are as before.
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
	quit(_t.verdict())


func _check(deep: bool) -> void:
	var run = _game.ctx.run
	var shop = _game.ctx.build.shop
	var who: String = run.class_id()
	run.cogs = 5000
	shop.enter()
	var first: Dictionary = shop.top_shelf()
	_t.check("%s: the hook is the Spare Frame until held" % who, first.get("part_id", "") == "spare_frame"
		and first["odds"] == OddsReadout.odds_for(Shop.TOP_RARITIES, who), "hook %s, odds %s" % [first.get("part_id"), first.get("odds")])
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
				or hook["odds"] != OddsReadout.odds_for(Shop.TOP_FALLBACK, who) or not hook["locked"] \
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
		and rewound["part_id"] == kept and rewound["odds"] == OddsReadout.odds_for(Shop.TOP_FALLBACK, who),
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
