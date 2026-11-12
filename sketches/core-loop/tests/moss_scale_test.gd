extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Shop := preload("res://src/build/shop.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const ShopCounter := preload("res://src/ui/shop_counter.gd")

# Moss's scale (docs/systems-audit/feature-fit.md, new mechanic 2), in the running game as
# Rivet in calm, at the economy pass's rates (Fabricators.COG_PRICES weigh_lump, mass_per_cog):
#   - flag off: the scale is shut and a press changes nothing;
#   - flag on: a press weighs one lump, pays a cog per mass_per_cog, and the quote equals the sale;
#   - the sale is not a theft: no scrap_lost, and the heft class follows the lighter ball;
#   - a ball too light to pay a cog is refused and keeps its mass;
#   - Moss's counter shows the scale on its sell face only when it is open, with the mass and
#     the cogs on the plate before the press, and pressing it sells.

const RIVET := 1

var _game
var _failures := 0
var _ticks := 0
var _lost := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.player.source = Intent.Scripted.new()
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(RIVET)
	elif _ticks == 30:
		_run_checks()
		print("moss_scale_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		quit(0 if _failures == 0 else 1)
		return true
	return false


func _run_checks() -> void:
	var run = _game.run
	var shop = _game.ctx.build.shop
	var tuning = _game.tuning
	_game.ctx.events.scrap_lost.connect(func(_a: int, _at: Vector3, _t: int, _c: String): _lost += 1)
	run.add_scrap(400, Vector3.ZERO)
	shop.enter()
	var lump := int(Fabricators.COG_PRICES["weigh_lump"])
	var per := float(Fabricators.COG_PRICES["mass_per_cog"])

	# Flag off: shut.
	var mass0: float = run.mass
	var cogs0: int = run.cogs
	var shut: Dictionary = shop.weigh()
	_check("off shut", not shop.scale_open() and not bool(shut["ok"]) and shut["reason"] == Shop.LOCKED and run.mass == mass0 and run.cogs == cogs0,
		"flag off: %s, mass %.0f" % [shut["reason"], run.mass])

	# The counter: no scale plate while it is shut.
	var counter := ShopCounter.new()
	counter.setup(_game)
	_game.hud.add_child(counter)
	counter.open(shop, 0.0)
	counter.set_face("sell")
	_check("counter shut", counter.tile_for("weigh") == null, "no weigh plate with the flag off")

	# Flag on: the plate shows one press before it, and pressing it sells.
	tuning.apply_args(PackedStringArray(["--moss-scale=on"]), "launch")
	counter.refresh()
	var plate = counter.tile_for("weigh")
	var shown: Dictionary = shop.weigh_quote()
	_check("counter plate", plate != null and int(plate.rec["mass"]) == int(shown["mass"]) and int(plate.rec["price"]) == int(shown["cogs"])
		and plate.drawn_words().has(str(int(shown["mass"]))) and plate.drawn_words().has(str(int(shown["cogs"]))),
		"plate %s, quote %s" % [plate.rec if plate != null else {}, shown])
	var cogs_at_plate: int = run.cogs
	if plate != null:
		counter.press(plate)
	_check("counter sells", run.cogs - cogs_at_plate == int(shown["cogs"]) and is_equal_approx(run.mass, mass0 - float(shown["mass"])),
		"pressed: +%d cogs, mass %.0f" % [run.cogs - cogs_at_plate, run.mass])
	counter.close()
	mass0 = run.mass
	cogs0 = run.cogs

	# One press by the verb: quote equals sale.
	var quote: Dictionary = shop.weigh_quote()
	var class0: int = run.heft_class()
	var r: Dictionary = shop.weigh()
	var want_cogs := int(floor(lump / per))
	_check("press", bool(r["ok"]) and int(r["mass"]) == int(quote["mass"]) and run.cogs - cogs0 == int(quote["cogs"]) and int(quote["cogs"]) == want_cogs
		and is_equal_approx(run.mass, mass0 - float(quote["mass"])),
		"quote %s, sold %d mass for %d cogs, mass %.0f -> %.0f" % [quote, int(r["mass"]), run.cogs - cogs0, mass0, run.mass])
	_check("not a theft", _lost == 0, "%d scrap_lost facts" % _lost)

	# Sell down to nothing: the heft class falls with the mass, and the last press is refused.
	var presses := 0
	while shop.weigh()["ok"] and presses < 100:
		presses += 1
	_check("class follows", run.heft_class() < class0 and run.heft_class() == run.raw_heft_class(run.heft()),
		"heft class %d -> %d after %d more presses" % [class0, run.heft_class(), presses])
	var light: float = run.mass
	var refused: Dictionary = shop.weigh()
	_check("too light", light < per and not bool(refused["ok"]) and refused["reason"] == Shop.TOO_LIGHT and run.mass == light,
		"mass %.1f left: %s" % [light, refused["reason"]])
	shop.leave()
	var closed: Dictionary = shop.weigh()
	_check("closed outside", closed["reason"] == Shop.CLOSED, "outside the bay: %s" % closed["reason"])
