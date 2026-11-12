extends SceneTree

const Intent := preload("res://src/movement/intent.gd")
const Shop := preload("res://src/build/shop.gd")
const MakerSets := preload("res://src/build/maker_sets.gd")
const UltimateMeter := preload("res://src/core/ultimate_meter.gd")
const ShopCounter := preload("res://src/ui/shop_counter.gd")
const T := preload("res://tests/support/t.gd")

# Moss's last call (W1-73) and the hook with a goal (W1-79), on a two-world table whose world 1
# ends at a boss (stages 1 to 3):
#   - a locked hook carries to the next stage's stock with the class it asked for, and the HUD's
#     cog chip pins that class; a bought hook does not carry;
#   - only the world's last stage is the last call: its first shelf slot is a missing piece of the
#     maker set nearest to waking, marked with the set's pips on Moss's counter;
#   - the kettle takes cogs in BREW_PRICES pours, caps at three, and the boss fight's arrival pours
#     a third of the ultimate meter per pour, every arrival in that arena; a stage retry gives the
#     pours back with the cogs, and no other stage's arena gets them.

class TwoWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd")


var _t := T.new("moss_last_call_test")
var _game
var _ticks := 0
var _goal := 0


func _initialize() -> void:
	_game = TwoWorldGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.player.source = Intent.Scripted.new()
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
	elif _ticks == 30:
		_hook_checks()
	elif _ticks == 33:
		# The HUD has updated since the hook was seen.
		_t.eq("the cog chip pins the hook's class", _game.hud._cogs.hook_class, _goal)
		_last_call_checks()
		quit(_t.verdict())
		return true
	return false


func _shop():
	return _game.ctx.build.shop


func _hook_checks() -> void:
	var run = _game.run
	var shop = _shop()
	var stages = _game.ctx.stages
	run.stage = 1
	shop.enter()
	_t.check("stage 1 is no last call", not shop.last_call() and shop.brew_offer().is_empty(), "")
	var hook: Dictionary = shop.top_shelf()
	_t.check("stage 1 stocks a locked hook", not hook.is_empty() and hook["locked"], str(hook))
	shop.leave()
	_goal = shop.hook_goal()
	_t.eq("the seen hook is the HUD's goal", _goal, int(hook.get("needs_class", -1)))
	run.stage = 2
	shop.enter()
	var carried: Dictionary = shop.top_shelf()
	_t.check("the locked hook carries to stage 2 at its class", carried.get("part_id") == hook.get("part_id") \
		and carried.get("needs_class") == hook.get("needs_class"), "%s -> %s" % [hook, carried])
	_t.check("the shelf never stocks the carried hook", not shop.shelf.any(func(e): return e["part_id"] == hook.get("part_id")), str(shop.shelf))
	shop.leave()
	# A sold hook is not carried: the next stock rolls its own.
	shop.top["sold"] = true
	_t.check("a sold hook does not carry", shop._carried_hook().is_empty(), "")
	shop.top["sold"] = false
	_t.check("stage 2 is no last call either", stages.is_world_last(3) and not stages.is_world_last(2), "")


func _last_call_checks() -> void:
	var run = _game.run
	var shop = _shop()
	# Two distinct pieces of one 3-piece maker set, so that set is the nearest to waking.
	var maker := MakerSets.SPILLWAY
	var pool: Array = shop._set_pool(maker, [])
	_t.check("the table stocks spillway pieces", pool.size() >= 3, str(pool))
	if pool.size() < 3:
		return
	run.add_part(pool[0], "test")
	run.add_part(pool[1], "test")
	var target: Dictionary = shop.set_piece()
	_t.check("the nearest set is the one a piece short", target.get("maker") == maker and target.get("held") == 2, str(target))
	run.stage = 3
	shop.enter()
	_t.check("the world's last stage is the last call", shop.last_call(), "")
	var first: Dictionary = shop.shelf_offers()[0]
	_t.check("its first slot is a missing piece of that set", MakerSets.maker_of(first["part_id"]) == maker \
		and not first["part_id"] in [pool[0], pool[1]] and first.get("set") == maker, str(first))
	_t.check("the offer carries the set's pips", first.get("set_held") == 2 and first.get("set_pieces") == 3, str(first))
	run.add_cogs(5000)
	_t.check("a reroll is made", shop.reroll().get("ok", false), "")
	_t.check("a reroll keeps the set slot", MakerSets.maker_of(shop.shelf[0]["part_id"]) == maker, str(shop.shelf[0]))

	# The kettle.
	var cogs0: int = run.cogs
	var paid := 0
	for pour in Shop.BREW_PRICES.size():
		var offer: Dictionary = shop.brew_offer()
		_t.eq("pour %d is offered at its price" % (pour + 1), offer.get("pours"), pour)
		var r: Dictionary = shop.buy_brew()
		_t.check("pour %d is bought" % (pour + 1), r.get("ok", false), str(r))
		paid += int(r.get("price", 0))
	_t.eq("the cogs paid are the pours' prices", cogs0 - run.cogs, paid)
	_t.eq("a fourth pour is refused", shop.buy_brew().get("reason"), Shop.CAPPED)
	_t.check("the counter shows the kettle", _counter_has("brew"), "")
	shop.leave()

	var meter = _game.player.abilities.meter
	meter.reset()
	_game.events.boss_arena_entered.emit()
	_t.check("a full brew opens the fight with the ultimate ready", meter.full(), "meter %.1f" % meter.value)
	meter.reset()
	_game.events.boss_arena_entered.emit()
	_t.check("an arena retry pours it again", meter.full(), "meter %.1f" % meter.value)

	shop.rewind_stage()
	_t.eq("a stage retry gives the pours back", shop.brew_offer().get("pours"), 0)
	shop.inside = true
	shop.buy_brew()
	shop.inside = false
	run.stage = 4
	_t.near("no other stage's arena gets the brew", shop.pour_brew(), 0.0)
	_t.check("stage 4 is no last call", shop.brew_offer().is_empty(), "")


func _counter_has(kind: String) -> bool:
	var counter := ShopCounter.new()
	counter.setup(_game)
	_game.hud.add_child(counter)
	counter.open(_shop(), 0.0)
	var found: bool = counter.tile_for(kind) != null
	counter.queue_free()
	return found
