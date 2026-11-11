extends "res://tools/bot_run.gd"

# Systems audit pass B (docs/systems-audit/economy/README.md): bot_run with a resource ledger, and
# the min-maxer's choices. Run one seed per process (a multi-seed bot_run forks children that run
# bot_run.gd itself, without this wrapper). Extra flag: --econ=none|minmax (default none).
#   none    the ledger only; the policy's run is bot_run's, untouched.
#   minmax  also takes the start pick (a part or core, never the cogs), boards Moss's bay each
#           stage it docks and buys out what it can afford (the hook, the shelf by price, one
#           reroll and a second pass, then charge cells), and takes every upgrade-tree offer.
# The bay visit is modelled: the probe makes the boarding call the cradle makes (world.gd
# _bay_fact "entered"), shops through shop.gd's own verbs, then the pad's "left" call. The ball
# never rides the barge, so the few seconds of the ride are not counted; the stage clock pauses
# aboard in the game anyway.
# Writes econ-<seed>.ndjson in --out: every gain, every drop in cogs, every heal, every buy, every
# tree pick, the start pick, and a snapshot at each stage entry and at the end.

var _hooked: Object = null
var _ledger: FileAccess = null
var _last := {}
var _econ := ""
var _emitted := 0
var _visited := {}
var _pick_rng := RandomNumberGenerator.new()


func _row(kind: String, extra := {}) -> void:
	if _ledger == null or _game == null:
		return
	var run = _game.run
	var r: Dictionary = {"t": snappedf(run.run_time, 0.01), "stage": run.stage, "kind": kind,
		"cogs": run.cogs, "scrap": run.scrap, "mass": snappedf(run.mass, 0.1), "hp": snappedf(run.hp, 0.1),
		"max_hp": snappedf(run.max_hp, 0.1), "cores": run.bonus_cores, "parts": run.parts.size(),
		"panels": run.panels.size(), "tree": run.tree_picks.size(), "relics": run.relics.size(),
		"heft": run.heft_class()}
	r.merge(extra)
	_ledger.store_line(JSON.stringify(r))


func _physics_process(delta: float) -> bool:
	var over := super(delta)
	if _game != null and _game != _hooked and _game.events != null:
		_hook()
	if _game != null and _game == _hooked and _game.run != null:
		_watch()
		if _econ == "minmax":
			_choose()
	if over and _ledger != null:
		_row("end", {"outcome": _driver.outcome if _driver != null else ""})
		_ledger.close()
		_ledger = null
	return over


func _hook() -> void:
	_hooked = _game
	_last = {}
	_visited = {}
	_econ = String(_settings.get("econ", "none"))
	_pick_rng.seed = hash(["econ", _seeds[_index]])
	_ledger = FileAccess.open(_out.path_join("econ-%d.ndjson" % _seeds[_index]), FileAccess.WRITE)
	var ev = _game.events
	ev.cogs_collected.connect(func(a, _t): _emitted += a; _row("cogs+", {"amount": a}))
	ev.part_gained.connect(func(p, s): _row("part+", {"part": p, "source": s}))
	ev.core_gained.connect(func(s, _at, c): _row("core+", {"source": s, "count": c}))
	ev.panel_gained.connect(func(p, _c, _at, j): _row("panel+", {"panel": p, "jackpot": j}))
	ev.scrap_lost.connect(func(a, _at, _t, c): _row("scrap-", {"amount": a, "cause": c}))
	ev.stage_entered.connect(func(i, retry): _row("stage", {"index": i, "retry": retry}))
	ev.tree_offered.connect(_on_tree_offered)


# Tick-to-tick changes no signal names: a cog gain nobody emitted, any cog drop, any heal.
func _watch() -> void:
	var run = _game.run
	var now := {"cogs": run.cogs, "hp": run.hp}
	if not _last.is_empty():
		var gained: int = now["cogs"] - _last["cogs"]
		if gained > _emitted:
			_row("cogs+", {"amount": gained - _emitted, "source": "unsignalled"})
		elif gained < 0 and _emitted == 0:
			_row("cogs-", {"amount": -gained})
		if now["hp"] > _last["hp"] + 0.5:
			_row("heal", {"amount": snappedf(now["hp"] - _last["hp"], 0.1)})
	_emitted = 0
	_last = now


func _on_tree_offered(_class_id: String, depth: int, choices: Array) -> void:
	if _econ != "minmax" or choices.is_empty():
		return
	var choice: String = choices[_pick_rng.randi() % choices.size()]
	if _game.player.tree.pick(choice):
		_row("tree+", {"node": choice, "depth": depth})


func _choose() -> void:
	var run = _game.run
	if run.stage == 1 and run.has_method("start_pick_options") and run._start_pick_open() and run._stage_entered:
		var options: Array = run.start_pick_options()
		var pick := -1
		for want in ["core", "part"]:
			for i in options.size():
				var is_part: bool = String(options[i]) not in ["cogs", "core"]
				if pick < 0 and ((want == "core" and options[i] == "core") or (want == "part" and is_part)):
					pick = i
		if pick < 0:
			pick = 0
		var id := String(options[pick])
		if run.take_start_pick(pick):
			_row("start_pick", {"id": id, "options": options})
	var world = _game.world
	if world == null or world.bay == null or not world.bay.docked or world.ride != null:
		return
	var key := "%d:%d" % [run.world, run.stage]
	if _visited.has(key):
		return
	_visited[key] = true
	_shop_visit(world)


func _shop_visit(world) -> void:
	var shop = world._shop()
	if shop == null:
		return
	var speed: float = _game.player.planar_velocity().length()
	world._bay_fact({"kind": "entered", "banked": speed})
	_row("bay", {"heft": _game.run.heft_class()})
	var t: Dictionary = shop.top_shelf()
	if not t.is_empty() and not t["sold"]:
		var r: Dictionary = shop.buy_top()
		_row("buy" if r.get("ok", false) else "no_buy", {"what": "top", "item": t["part_id"], "price": t["price"], "why": r.get("reason", "")})
	_buy_shelf(shop)
	if shop.rerolls_left > 0 and _game.run.cogs >= shop.reroll_price():
		var price: int = shop.reroll_price()
		if shop.reroll().get("ok", false):
			_row("buy", {"what": "reroll", "price": price})
			_buy_shelf(shop)
	var bought := true
	while bought:
		bought = false
		for o in shop.charge_offers():
			if o["can"] and _game.run.cogs >= o["price"]:
				var r: Dictionary = shop.buy_charge(o["slot"])
				if r.get("ok", false):
					_row("buy", {"what": "cell", "item": o["part_id"], "price": r.get("price", 0)})
					bought = true
	for o in shop.shelf_offers():
		if not o.get("sold", false):
			_row("no_buy", {"what": "shelf", "item": o.get("part_id", ""), "price": o.get("price", 0)})
	world._bay_fact({"kind": "left", "velocity": _game.player.state.velocity})


func _buy_shelf(shop) -> void:
	var offers: Array = shop.shelf_offers()
	var order := range(offers.size())
	order.sort_custom(func(a, b): return int(offers[a].get("price", 0)) > int(offers[b].get("price", 0)))
	for i in order:
		var o: Dictionary = offers[i]
		if o.get("sold", false) or _game.run.cogs < int(o.get("price", 0)):
			continue
		var r: Dictionary = shop.buy(i)
		if r.get("ok", false):
			_row("buy", {"what": "shelf", "item": o.get("part_id", ""), "price": r.get("price", 0)})
