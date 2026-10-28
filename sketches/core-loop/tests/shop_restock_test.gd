extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const Shop := preload("res://src/build/shop.gd")

# Moss stocks the shelf once per stage (speedrunner red team on stage/alpha-w21 bf3d2722: every
# bay re-entry restocked, so the cobalt floor's slot 0 was a fresh cobalt each lap and a probe
# bought 12 for 712 cogs). Re-entering the bay in the same stage finds the same shelf, the same
# hook, a bought part still sold and the reroll still spent; the paid reroll restocks, and a new
# stage stocks afresh with its cobalt floor and its reroll back.
# smoke: timeout=120s

var _t := preload("res://tests/support/t.gd").new("shop_restock_test")
var _game


func _initialize() -> void:
	_run()


func _run() -> void:
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
	_check()
	_game.free()
	quit(_t.verdict())


static func _ids(shop) -> Array:
	return shop.shelf.map(func(entry): return entry["part_id"])


func _check() -> void:
	var run = _game.ctx.run
	var shop = _game.ctx.build.shop
	run.cogs = 5000
	shop.enter()
	var first := _ids(shop)
	var hook: Dictionary = shop.top_shelf()
	_t.check("slot 0 is cobalt or better", Parts.rung_of(first[0]) >= Parts.RUNG_FLOOR, str(first))
	var bought: Dictionary = shop.buy(0)
	_t.check("a shelf part buys", bought["ok"], var_to_str(bought))
	shop.leave()
	for lap in 5:
		shop.enter()
		shop.leave()
	shop.enter()
	_t.eq("re-entering the bay keeps the shelf", _ids(shop), first)
	_t.eq("re-entering the bay keeps the hook", shop.top_shelf().get("part_id", ""), hook.get("part_id", ""))
	_t.check("the bought part stays sold", not shop.buy(0)["ok"], "slot 0 bought again")
	_t.check("re-entering hands back no reroll", shop.rerolls_left == Shop.REROLLS_PER_VISIT, str(shop.rerolls_left))
	var paid: Dictionary = shop.reroll()
	var rerolled := _ids(shop)
	_t.check("the paid reroll restocks", paid["ok"] and rerolled != first, "%s -> %s" % [first, rerolled])
	shop.leave()
	shop.enter()
	_t.eq("a rerolled shelf holds through a re-entry", _ids(shop), rerolled)
	_t.eq("the reroll stays spent through a re-entry", shop.rerolls_left, 0)
	shop.leave()
	run.stage += 1
	shop.enter()
	var next := _ids(shop)
	_t.check("a new stage stocks afresh", next != rerolled and next.size() == Shop.SHELF_SIZE, "%s -> %s" % [rerolled, next])
	_t.check("the new stage's slot 0 is cobalt or better", Parts.rung_of(next[0]) >= Parts.RUNG_FLOOR, str(next))
	_t.eq("a new stage hands the reroll back", shop.rerolls_left, Shop.REROLLS_PER_VISIT)
	shop.leave()
