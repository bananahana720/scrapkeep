extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const ActiveOffers := preload("res://src/combat/actives/active_offers.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const T := preload("res://tests/support/t.gd")

# Actives as run loot (design page "Makers and Actives"). A real Game with the first pilot.
# Covers: the offer pool takes only rare and relic actives the gate's rarities allow and never
# the racked one; with --actives off no draw spends the rng and a gate shows only parts; on, a
# gate draw adds one active arch beside the parts, tagged with its maker; rolling through it
# racks the active, adds no part and drops the old active where the ball stands with its
# charges; rolling back over the drop swaps them again; a held active (racked or dropped) is never
# offered; Moss's shelf sells an active in its last slot; a retry rewinds the rack. Two stand-in
# rows (a relic and a rare) join the authored ones and fire as the rocket rack, so the swap checks
# hold whichever actives are authored; checks on the draw read the pool, never a fixed count.
# Evidence limit: rules in a headless run, not feel.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)
const TORCH := "test_torch"
const LANCE := "test_lance"


class TestRack:
	extends "res://src/combat/actives/active_rack.gd"

	func rows() -> Dictionary:
		var out: Dictionary = super.rows().duplicate()
		out[TORCH] = _stand_in("Test Torch", "redjaw_workshops", "relic")
		out[LANCE] = _stand_in("Test Lance", "mind_glass", "rare")
		return out

	func _row(id: String) -> Dictionary:
		return rows().get(id, {})

	func setup(context, owner_combat) -> void:
		super.setup(context, owner_combat)
		_kinds[TORCH] = _kinds[ActiveDefs.SCRAP_ROCKET]
		_kinds[LANCE] = _kinds[ActiveDefs.SCRAP_ROCKET]

	static func _stand_in(name: String, maker: String, rarity: String) -> Dictionary:
		var row: Dictionary = ActiveDefs.row(ActiveDefs.SCRAP_ROCKET).duplicate()
		row["name"] = name
		row["maker"] = maker
		row["rarity"] = rarity
		row["max_charges"] = 3
		return row


var _t := T.new("active_offers_test")
var _game
var _player
var _source := Intent.Scripted.new()


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _ground(dx: float, dz := 0.0) -> Vector3:
	return _game.ctx.terrain.drop_point(FLAT_SHELF.x + dx, FLAT_SHELF.z + dz, 1.0)


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	# Actives are on by default (24 Oct); the off checks below run with --actives=off.
	_t.eq("07 --actives defaults on", _game.tuning.option("actives"), "on")
	_game.tuning.set_option("actives", "off")
	_game.flow.press_start()
	_game.flow.choose_class(0)
	var combat = _game.combat
	await _sim(0.4)
	var build = _game.ctx.build

	# --- The pool: rarity and the racked active ------------------------------------------
	var rows := {"a": {"rarity": "rare"}, "b": {"rarity": "relic"}, "c": {"rarity": "rare"}}
	_t.eq("01 a common-only draw offers no active", ActiveOffers.pool(rows, ["common"], []), [])
	_t.eq("02 a common-or-rare draw offers the rare actives", ActiveOffers.pool(rows, ["common", "rare"], []), ["a", "c"])
	_t.eq("03 a held active (racked or dropped) is never offered", ActiveOffers.pool(rows, ["rare", "relic"], ["a", "c"]), ["b"])
	_t.check("04 an offer id names its active and is never a part id",
		ActiveOffers.is_offer("active:b") and ActiveOffers.active_of("active:b") == "b" and not ActiveOffers.is_offer("b"))
	var hits := 0
	var rng := _seeded(7)
	for i in 400:
		var got := ActiveOffers.roll(rng, "gate", rows, ["rare", "relic"], ["a"])
		if got != "":
			hits += 1
			if not got in ["active:b", "active:c"]:
				_t.check("05 a roll only draws from the pool", false, got)
	_t.check("05 a gate draw carries an active about its share of the time", absf(hits / 400.0 - ActiveOffers.SHARE["gate"]) < 0.08,
		"%d of 400" % hits)
	var dry := _seeded(9)
	var before := dry.state
	_t.check("06 a draw with nothing in the pool spends no rng", ActiveOffers.roll(dry, "gate", rows, ["common"], []) == "" and dry.state == before)

	var shipping: Array = ActiveDefs.ROWS.keys()
	var authored := not shipping.has(TORCH) and not shipping.has(LANCE) and shipping.has(ActiveDefs.SCRAP_ROCKET)
	for id in shipping:
		var r: Dictionary = ActiveDefs.row(id)
		authored = authored and String(r.get("maker", "")) != "" and String(r.get("rarity", "")) in ["rare", "relic"]
	_t.check("31 the shipping pool holds only authored actives, each rare or relic with a maker, never a stand-in",
		authored, str(shipping))

	# --- Off: no draw, no rng, parts only -------------------------------------------------
	var off_rng := _seeded(11)
	var off_state := off_rng.state
	_t.check("08 off: build offers no active and spends no rng",
		build.active_offer("gate", ["rare", "relic"], off_rng) == "" and off_rng.state == off_state)

	# --- On, with two stand-in actives ----------------------------------------------------
	combat.actives.queue_free()
	var rack := TestRack.new()
	combat.add_child(rack)
	rack.setup(_game.ctx, combat)
	combat.actives = rack
	_game.tuning.set_option("actives", "on")
	_player.reset_to(_ground(0.0) + Vector3.UP)
	await _sim(0.2)
	_t.eq("09 on: the run opens racked with the starter", rack.active_id, ActiveDefs.SCRAP_ROCKET)
	var drawn := {}
	var on_rng := _seeded(13)
	for i in 200:
		var got: String = build.active_offer("gate", ["rare", "relic"], on_rng)
		if got != "":
			drawn[got] = true
	# Across 200 draws every un-held rare or relic active turns up (the authored rows plus the two
	# stand-ins); each draw is still one id, so a gate carries at most one active arch.
	var expected: Array = ActiveOffers.pool(rack.rows(), ["rare", "relic"], rack.held()).map(func(id): return ActiveOffers.offer_id(id))
	expected.sort()
	var got_ids: Array = drawn.keys()
	got_ids.sort()
	_t.check("10 a rare-or-relic gate draws from every un-held active, stand-ins included",
		got_ids == expected and drawn.has(ActiveOffers.offer_id(TORCH)) and drawn.has(ActiveOffers.offer_id(LANCE)), "%s vs %s" % [got_ids, expected])
	_t.check("11 the racked starter is never drawn", not drawn.has(ActiveOffers.offer_id(ActiveDefs.SCRAP_ROCKET)), str(drawn.keys()))
	_t.eq("12 a gate with no bonus core (common) offers no active", build.active_offer("gate", ["common"], on_rng), "")

	# --- A gate arch for the active --------------------------------------------------------
	var gates = build.gates
	var parts_before: Array = _game.ctx.run.parts.duplicate()
	var ball: Vector3 = _player.ball_position()
	var offers: Array = gates.open(["scrap_gravity", ActiveOffers.offer_id(TORCH)], ball, Vector3.FORWARD, _game.ctx.run.parts)
	_t.eq("13 the gate stands one arch per offer", offers.size(), 2)
	var arch: Dictionary = offers[1] if offers.size() > 1 else {}
	_t.check("14 the active arch reads as the active, its rarity and its maker",
		arch.get("name") == "Test Torch" and arch.get("rarity") == "relic" and arch.get("maker") == "redjaw_workshops"
			and String(arch.get("mark", "")).contains("Redjaw Workshops") and arch.has("at") and arch.has("facing"),
		str(arch))
	_t.check("15 the arch's prompt carries the maker tag", String(RewardGates.prompt_parts(arch)["detail"]).contains("Redjaw Workshops"))
	var chosen: Array = []
	_game.events.reward_chosen.connect(func(id: String): chosen.append(id))
	var spent := 1
	rack.charges = spent
	gates.close()
	build._on_gate_chosen(ActiveOffers.offer_id(TORCH))
	_t.check("16 rolling through racks the active full", rack.active_id == TORCH and rack.charges == 3, "%s %d" % [rack.active_id, rack.charges])
	_t.eq("17 an active is never a part", _game.ctx.run.parts, parts_before)
	_t.eq("18 the flow still hears the choice", chosen, [ActiveOffers.offer_id(TORCH)])
	_t.check("19 the old active drops where the ball stands, keeping its charges",
		rack.dropped.size() == 1 and rack.dropped[0]["id"] == ActiveDefs.SCRAP_ROCKET and rack.dropped[0]["charges"] == spent
			and (rack.dropped[0]["at"] as Vector3).distance_to(ball) < 1.5 and is_instance_valid(rack.dropped[0]["node"]),
		str(rack.dropped.map(func(e): return [e["id"], e["charges"], e["at"]])))

	# --- The drop: no instant swap back; roll away and back to swap ----------------------
	await _sim(0.2)
	_t.eq("20 sitting on the drop does not swap back", rack.active_id, TORCH)
	_player.reset_to(_ground(12.0) + Vector3.UP)
	await _sim(0.2)
	rack.charges = 2
	_player.reset_to(_game.ctx.terrain.drop_point(ball.x, ball.z, 1.0) + Vector3.UP)
	await _sim(0.2)
	_t.check("21 rolling back over it swaps again with no free refill",
		rack.active_id == ActiveDefs.SCRAP_ROCKET and rack.charges == spent, "%s %d" % [rack.active_id, rack.charges])
	_t.check("22 and the torch now lies there with its own charges",
		rack.dropped.size() == 1 and rack.dropped[0]["id"] == TORCH and rack.dropped[0]["charges"] == 2)

	# --- Moss's shelf ---------------------------------------------------------------------
	var shop = build.shop
	var shelf: Array = []
	for i in 40:
		shop._rng.seed = 100 + i
		shelf = shop._stock()
		if shelf.any(func(e): return ActiveOffers.is_offer(e["part_id"])):
			break
	var at := -1
	for i in shelf.size():
		if ActiveOffers.is_offer(shelf[i]["part_id"]):
			at = i
	_t.check("23 Moss shelves an active in his last slot; the shelf stays three", at == shop.SHELF_SIZE - 1 and shelf.size() == shop.SHELF_SIZE, str(shelf))
	if at >= 0:
		shop.inside = true
		shop.shelf = shelf
		var record: Dictionary = shop.shelf_offers()[at]
		var shelved: String = ActiveOffers.active_of(shelf[at]["part_id"])
		var row: Dictionary = rack.row_of(shelved)
		_t.check("24 the shelf record names the active, its rare rung, maker and price",
			record["active"] == shelved and record["rarity"] == "rare" and record["maker"] == row.get("maker", "")
				and record["price"] > 0 and String(record["headline"]).contains(ActiveOffers.maker_name(row)), str(record))
		_game.ctx.run.add_cogs(record["price"] + 50)
		var wallet_before: int = _game.ctx.run.cogs
		var bought: Dictionary = shop.buy(at)
		_t.check("25 buying it racks it and drops the old one", bought["ok"] and rack.active_id == shelved
			and rack.dropped.any(func(e): return e["id"] == ActiveDefs.SCRAP_ROCKET), str(bought))
		_t.eq("26 still no part gained", _game.ctx.run.parts, parts_before)
		# Bought off the shelf curve, it can never sell back at the shelf's: a racked active is not
		# a held part, so Moss's sell-back refuses it and the round trip pays nothing.
		var sell_offer: Dictionary = shop.sell(shelf[at]["part_id"])
		var sell_active: Dictionary = shop.sell(shelved)
		_t.check("26b a bought active sold straight back nets nothing", not sell_offer["ok"] and not sell_active["ok"]
			and shop.sell_quote(shelf[at]["part_id"]) < 0 and _game.ctx.run.cogs - wallet_before <= 0
			and not shop.sell_offers().any(func(o): return o["part_id"] == shelf[at]["part_id"] or o["part_id"] == shelved),
			"sell %s: %s, %s; net %d cogs" % [shelved, sell_offer["reason"], sell_active["reason"], _game.ctx.run.cogs - wallet_before])
		shop.inside = false

	# --- Clearing ---------------------------------------------------------------------------
	_game.events.stage_entered.emit(2, false)
	_t.check("27 a new stage leaves the drops behind", rack.dropped.is_empty())
	var at_start: Array = [rack.active_id, rack.charges]
	rack.take(TORCH, _player.ball_position())
	_t.check("29 a dropped active is never offered again while it lies there",
		not ActiveOffers.pool(rack.rows(), ["rare", "relic"], rack.held()).has(at_start[0]) and not ActiveOffers.pool(rack.rows(), ["rare", "relic"], rack.held()).has(TORCH))
	_game.events.stage_entered.emit(2, true)
	_t.eq("30 a retry rewinds the rack to how the stage began", [rack.active_id, rack.charges], at_start)
	_game.events.run_started.emit("pylon_engineer")
	_t.check("28 a new run empties the rack and the drops", rack.active_id == "" and rack.dropped.is_empty())
	quit(_t.verdict())
