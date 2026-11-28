extends RefCounted

const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const LoopTally := preload("res://src/core/loop_tally.gd")
const Relics := preload("res://src/build/relics.gd")
const Items := preload("res://src/build/items.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const ActiveOffers := preload("res://src/combat/actives/active_offers.gd")
const MakerSets := preload("res://src/build/maker_sets.gd")
const UltimateMeter := preload("res://src/core/ultimate_meter.gd")
const Consumables := preload("res://src/build/consumables.gd")


const SHELF_SIZE := 3
const CONSUMABLE_STOCK_SIZE := 2
const TRI_TERMINAL_SIZE := 3
const SHELF_RARITIES := ["common", "rare"]
const TOP_RARITIES := ["relic"]
const FLOOR_RARITIES := ["rare"]
const TOP_FALLBACK := FLOOR_RARITIES
const REROLLS_PER_VISIT := 1
const TOP_CLASS_MAX := 5
const SEED := 4242

const OK := "ok"
const CANT_AFFORD := "cant_afford"
const SOLD_OUT := "sold_out"
const LOCKED := "locked"
const CAPPED := "capped"
const NO_REROLL := "no_reroll"
const WELDED := "welded"
const NOT_HELD := "not_held"
const CLOSED := "closed"
const TOO_LIGHT := "too_light"
const NO_FUEL := "no_fuel"
const TRI_CLOSED := "tri_closed"

const BREW_PRICES := [250, 450, 700]
const BREW_SHARE := 1.0 / 3.0

const BEATS := [
	{"id": "ask", "root": "D3", "grumble": false},
	{"id": "refuse", "root": "E3", "grumble": true},
	{"id": "insist", "root": "F3", "grumble": false},
	{"id": "double_down", "root": "G3", "grumble": true},
	{"id": "plead", "root": "A3", "grumble": false},
	{"id": "send_off", "root": "C3", "grumble": true},
]
const RELENT_ROOT := "D3"
const BARK_ROOT := "D3"
const CLASS_LINES := {"moss.ask.sable": Items.SABLE, "moss.refuse.rivet": Items.RIVET, "moss.plead.kest": Items.KEST}
const LINES := {
	"moss.ask.1": "The hook. Everyone looks at the hook. Shelf's the thing for sale.",
	"moss.ask.2": "Eyes off the top shelf, salvager. Three fine parts, right there.",
	"moss.ask.3": "That one? Not for you. Not for anyone your size.",
	"moss.ask.sable": "Ears up already. No, fox. The hook stays hooked.",
	"moss.refuse.1": "No. It'd shear your axle the first bump you took.",
	"moss.refuse.2": "Too strong for a ball that light. Ask the dial.",
	"moss.refuse.3": "Bolt that on and I'm scraping you off the rapids.",
	"moss.refuse.rivet": "You'd measure it twice and still be too light.",
	"moss.insist.1": "Still no. The shelf has three answers. Pick one.",
	"moss.insist.2": "Asking louder doesn't add weight. Scrap adds weight.",
	"moss.insist.3": "I heard you the first time. I said it the first time.",
	"moss.double_down.1": "Read the dial. One notch short. Come back heavier.",
	"moss.double_down.2": "That part needs a heft you haven't rolled up yet.",
	"moss.double_down.3": "Rules of the bench. Weight before wonders. Always were.",
	"moss.plead.1": "Don't give me the look. I like the look. Still no.",
	"moss.plead.2": "Begging's free. The hook isn't. Roll some scrap in.",
	"moss.plead.3": "You'd float away with it. Then who buys my parts?",
	"moss.plead.kest": "Crest down, bird. Pleading doesn't count as lift.",
	"moss.send_off.1": "Try the scrapper past the rapids. Sells lighter. Sells worse.",
	"moss.send_off.2": "There's a cart down the shelf road. Flimsy parts, no questions.",
	"moss.send_off.3": "Go bother the gates. They'll give you anything.",
	"moss.restart": "Again? Fine. From the top.",
	"moss.relent.1": "Fine. You're heavy enough. Don't come back lighter.",
	"moss.relent.2": "Hook's yours. Took you long enough to get fat.",
	"moss.relent.3": "Alright, salvager. It'll hold now. Probably. Bolt it on.",
	"moss.bark.buy": "Bolted. Mind the weld, it's still warm.",
	"moss.bark.reroll": "New shelf. Same shop. Don't get used to it.",
	"moss.bark.sell": "Half back. Lighter, but faster to the next part.",
	"moss.bark.charge": "Second cell's in. Two shots, then wait like everyone.",
	"moss.bark.cant_afford": "Scrap first. I don't run tabs for rolling things.",
	"moss.bark.leaving": "Pad's hot. Go on, before the clock notices.",
	"moss.remember.first_visit": "Shelf's there. Hook's not for sale. Ask anyway, everyone does.",
	"moss.remember.died_last_run": "Back again. The Warden keeps your last shell, you know.",
	"moss.remember.won_last_run": "You finished one. Shelf's the same. Standards aren't.",
	"moss.remember.class_changed": "New pilot, same ball. Moss remembers the ball.",
	"moss.remember.skipped_visits": "Three launches past my door. Bell still works.",
	"moss.remember.relented_before": "Heavy again. Hook's already yours, don't act surprised.",
	"moss.remember.neglected": "Died holding scrap. Scrap that could've been plating. Hm.",
	"moss.ledger.1": "A ledger leaf. Tally's scrawl. Pinned it by the shelf.",
	"moss.ledger.2": "Second leaf. Tally's been counting on you. Literally. One more.",
	"moss.ledger.3": "Three leaves. Balance due. Tally's at the gate, pockets full.",
}
const REMEMBER_ORDER := ["neglected", "relented_before", "died_last_run", "won_last_run", "class_changed",
	"skipped_visits"]
const CODEX_ID := "too_heavy_for_you"

var ctx
var build
var visit := 0
var inside := false
var shelf: Array = []
var consumable_stock: Array = []
var tri_terminal: Array = []
var tri_terminal_closed := false
var top := {}
var rerolls_left := 0
var bought_this_visit := 0
var history := {}
var neglected := false
var talks := {"beat": -1, "used": {}, "loops": 0, "relented": false}
var leaves_this_visit: Array = []
var return_leaves := Callable()
var leaves_returned := Callable()
var stocked_for: Array = []
var stocks := 0
var _stage_stocks := {}

var _rng := RandomNumberGenerator.new()
var _cons_rng := RandomNumberGenerator.new()
var _tri_rng := RandomNumberGenerator.new()
var _press_rng := RandomNumberGenerator.new()
var _left_empty := false
var _cheapest_left := 0


func _init(ctx_ref = null, build_ref = null) -> void:
	ctx = ctx_ref
	build = build_ref


func reset_run() -> void:
	visit = 0
	inside = false
	shelf = []
	consumable_stock = []
	tri_terminal = []
	tri_terminal_closed = false
	top = {}
	stocked_for = []
	stocks = 0
	_stage_stocks = {}
	neglected = false
	_left_empty = false
	talks = {"beat": -1, "used": {}, "loops": 0, "relented": false}
	if ctx != null and ctx.run != null:
		Fabricators.reset_ingots(ctx.run)


static func line(line_id: String) -> Dictionary:
	return {"line_id": line_id, "text": LINES.get(line_id, ""), "root": BARK_ROOT}


func enter() -> Dictionary:
	inside = true
	visit += 1
	bought_this_visit = 0
	var here := [ctx.run.world, ctx.run.stage]
	if here != stocked_for:
		_stock_stage(here)
	talks = {"beat": -1, "used": {}, "loops": 0, "relented": false}
	var greeting: Dictionary = greeting_line()
	leaves_this_visit = _return_leaves()
	if not leaves_this_visit.is_empty():
		var returned: int = int(leaves_returned.call()) if leaves_returned.is_valid() else leaves_this_visit.size()
		greeting = line("moss.ledger.%d" % clampi(returned, 1, 3))
	neglected = false
	return greeting


func _stock_stage(here: Array) -> void:
	var carried := _carried_hook() if not stocked_for.is_empty() and stocked_for != here else {}
	stocked_for = here
	stocks += 1
	rerolls_left = REROLLS_PER_VISIT
	if ctx != null and ctx.run != null and ctx.run.has_method("override_on") and ctx.run.override_on("shops_and_crates_shut"):
		shelf = []
		top = {}
		consumable_stock = []
		tri_terminal = []
		tri_terminal_closed = true
		return
	_rng.seed = hash([SEED, ctx.flow.run_key() if ctx.flow != null else ctx.run.run_seed, ctx.run.world, ctx.run.stage, "shelf"])
	shelf = _stock()
	var lock_class: int = mini(TOP_CLASS_MAX, ctx.run.heft_class() + 1)
	var hook := _roll_hook(shelf.map(func(entry): return entry["part_id"]))
	top = {"part_id": hook["part_id"], "table": hook["table"], "lock_class": lock_class, "sold": false} if hook["part_id"] != "" else {}
	if not carried.is_empty() and not shelf.any(func(entry): return entry["part_id"] == carried["part_id"]):
		top = carried
	_cons_rng.seed = hash([SEED, ctx.flow.run_key() if ctx.flow != null else ctx.run.run_seed, ctx.run.world, ctx.run.stage, "consumables"])
	consumable_stock = _stock_consumables()
	_tri_rng.seed = hash([SEED, ctx.flow.run_key() if ctx.flow != null else ctx.run.run_seed, ctx.run.world, ctx.run.stage, "tri_terminal"])
	_press_rng.seed = hash([SEED, ctx.flow.run_key() if ctx.flow != null else ctx.run.run_seed, ctx.run.world, ctx.run.stage, "part_press"])
	tri_terminal = _stock_tri_terminal()
	tri_terminal_closed = false
	_stage_stocks[str(here)] = {
		"shelf": shelf.duplicate(true),
		"consumables": consumable_stock.duplicate(true),
		"tri_terminal": tri_terminal.duplicate(true),
		"tri_terminal_closed": tri_terminal_closed,
		"ingots": Fabricators.ingots_to_doc(ctx.run),
		"top": top.duplicate(true),
		"rng": _rng.state,
	}


func _carried_hook() -> Dictionary:
	if top.is_empty() or top["sold"] or ctx.run.heft_class() >= int(top["lock_class"]):
		return {}
	if Parts.stacked_out(top["part_id"], ctx.run.parts):
		return {}
	var out := top.duplicate(true)
	out["carried"] = true
	return out


func hook_goal() -> int:
	if top.is_empty() or top["sold"] or stocks == 0:
		return 0
	var needs := int(top["lock_class"])
	return needs if ctx.run.heft_class() < needs else 0


func rewind_stage() -> void:
	var here := [ctx.run.world, ctx.run.stage]
	var kept: Dictionary = _stage_stocks.get(str(here), {})
	if kept.is_empty():
		stocked_for = []
		return
	stocked_for = here
	rerolls_left = REROLLS_PER_VISIT
	shelf = kept["shelf"].duplicate(true)
	consumable_stock = (kept.get("consumables", []) as Array).duplicate(true)
	tri_terminal = (kept.get("tri_terminal", []) as Array).duplicate(true)
	tri_terminal_closed = bool(kept.get("tri_terminal_closed", false))
	if kept.has("ingots"):
		Fabricators.ingots_from_doc(ctx.run, kept["ingots"])
	top = kept["top"].duplicate(true)
	_rng.state = kept["rng"]


func leave() -> Dictionary:
	inside = false
	_left_empty = bought_this_visit == 0
	_cheapest_left = _cheapest_price()
	return line("moss.bark.leaving")


func _return_leaves() -> Array:
	if not return_leaves.is_valid():
		return []
	return return_leaves.call(ctx.player.ball_position() if ctx.player != null else Vector3.ZERO)


func clock_paused() -> bool:
	return inside


func note_death(cogs_held: int) -> void:
	if _left_empty and _cheapest_left > 0 and cogs_held >= _cheapest_left:
		neglected = true


func greeting_line() -> Dictionary:
	var keys := history.duplicate()
	keys["neglected"] = neglected
	if ctx.codex != null and ctx.codex.known(CODEX_ID):
		keys["relented_before"] = true
	for key in REMEMBER_ORDER:
		if keys.get(key, false):
			return line("moss.remember." + key)
	return line("moss.remember.first_visit")


func shelf_offers() -> Array:
	var out: Array = []
	for i in shelf.size():
		var offer := _offer(shelf[i]["part_id"], shelf[i]["sold"], i)
		offer["odds"] = shelf[i].get("odds", [])
		offer["odds_text"] = ItemGen.odds_text(offer["odds"])
		if shelf[i].has("set"):
			var maker := String(shelf[i]["set"])
			offer["set"] = maker
			offer["set_held"] = int(_set_counts().get(maker, 0))
			offer["set_pieces"] = int(MakerSets.SETS.get(maker, {}).get("pieces", 0))
		out.append(offer)
	return out


func buy(index: int) -> Dictionary:
	if not inside:
		return _result(false, CLOSED)
	if index < 0 or index >= shelf.size() or shelf[index]["sold"]:
		return _result(false, SOLD_OUT)
	var part_id: String = shelf[index]["part_id"]
	var rack = _rack() if ActiveOffers.is_offer(part_id) else null
	if ActiveOffers.is_offer(part_id) and (rack == null or rack.active_id == ActiveOffers.active_of(part_id)):
		return _result(false, SOLD_OUT, "", part_id)
	var cost: int = price(part_id)
	if not ctx.run.spend_cogs(cost):
		return _result(false, CANT_AFFORD, "moss.bark.cant_afford", part_id, cost)
	shelf[index]["sold"] = true
	bought_this_visit += 1
	if rack != null:
		rack.take(part_id, ctx.player.ball_position() if ctx.player != null else Vector3.ZERO)
	else:
		ctx.run.add_part(part_id, "shop")
	return _result(true, OK, "moss.bark.buy", part_id, cost)


func reroll_price() -> int:
	return int(round(Fabricators.COG_PRICES["reroll_base"] * pow(Fabricators.COG_PRICES["reroll_growth"], maxi(0, stocks - 1))))


func reroll() -> Dictionary:
	if not inside:
		return _result(false, CLOSED)
	if rerolls_left <= 0:
		return _result(false, NO_REROLL)
	var cost: int = reroll_price()
	if not ctx.run.spend_cogs(cost):
		return _result(false, CANT_AFFORD, "moss.bark.cant_afford", "", cost)
	rerolls_left -= 1
	shelf = _stock()
	return _result(true, OK, "moss.bark.reroll", "", cost)


func scale_open() -> bool:
	return ctx != null and ctx.tuning != null and ctx.tuning.option("moss_scale") == "on"


func weigh_quote() -> Dictionary:
	if not scale_open():
		return {"mass": 0, "cogs": 0}
	var per := float(Fabricators.COG_PRICES["mass_per_cog"])
	var cogs := int(floor(minf(float(Fabricators.COG_PRICES["weigh_lump"]), ctx.run.mass) / per))
	return {"mass": int(ceil(cogs * per)), "cogs": cogs}


func weigh() -> Dictionary:
	if not inside:
		return _result(false, CLOSED)
	if not scale_open():
		return _result(false, LOCKED)
	var quote := weigh_quote()
	if int(quote["cogs"]) <= 0:
		return _result(false, TOO_LIGHT)
	var taken: int = ctx.run.weigh_out(int(quote["mass"]))
	LoopTally.note(ctx.run, "moss_scale")
	var paid := int(floor(taken / float(Fabricators.COG_PRICES["mass_per_cog"])))
	_refund(paid)
	if build != null:
		build.recompute()
	var out := _result(true, OK, "", "", -paid)
	out["mass"] = taken
	return out


func stow_open() -> bool:
	return ctx != null and ctx.tuning != null and ctx.tuning.option("carry_core") == "on" and not ctx.run.companion.is_empty()


func stow_core() -> Dictionary:
	if not inside:
		return _result(false, CLOSED)
	if not stow_open():
		return _result(false, LOCKED)
	if not ctx.run.stow_core():
		return _result(false, CAPPED if ctx.run.carried_core > 0 else CANT_AFFORD)
	LoopTally.note(ctx.run, "carry_core")
	return _result(true, OK)


func charge_offers() -> Array:
	var out: Array = []
	var abilities = ctx.player.abilities if ctx.player != null else null
	for slot in Items.CELLS_FOR:
		if abilities == null or abilities.cooldown_of(slot) <= 0.0:
			continue
		var part_id: String = Items.CELLS_FOR[slot]
		var cells: int = ctx.run.parts.count(part_id)
		var cap := int(Parts.def(part_id).stack_cap)
		out.append({"slot": slot, "part_id": part_id, "price": cell_price(slot), "cells": cells, "cap": cap,
			"max_charges": abilities.slot(slot).max_charges, "icon": "cat_charge",
			"can": cells < cap and abilities.slot(slot).max_charges < build.effects.MAX_CHARGES})
	return out


func cell_price(slot: String) -> int:
	return _cell_cost(ctx.run.parts.count(Items.CELLS_FOR.get(slot, "")))


func _cell_cost(cells: int) -> int:
	return int(round(Fabricators.COG_PRICES["cell_base"] * pow(Fabricators.COG_PRICES["cell_growth"], cells) * _price_scale()))


func buy_charge(slot: String) -> Dictionary:
	if not inside:
		return _result(false, CLOSED)
	var offer := {}
	for o in charge_offers():
		if o["slot"] == slot:
			offer = o
	if offer.is_empty() or not offer["can"]:
		return _result(false, CAPPED)
	if not ctx.run.spend_cogs(offer["price"]):
		return _result(false, CANT_AFFORD, "moss.bark.cant_afford", offer["part_id"], offer["price"])
	bought_this_visit += 1
	ctx.run.add_part(offer["part_id"], "shop")
	return _result(true, OK, "moss.bark.charge", offer["part_id"], offer["price"])


func _stock_consumables() -> Array:
	var out: Array = []
	var picked: Array = []
	for i in CONSUMABLE_STOCK_SIZE:
		var cid := Consumables.roll_id(_cons_rng, picked)
		if cid == "":
			break
		picked.append(cid)
		out.append({"consumable_id": cid, "sold": false})
	return out


func consumable_price(consumable_id: String) -> int:
	return int(round(Consumables.price_of(consumable_id) * _price_scale()))


func consumable_offers() -> Array:
	var out: Array = []
	for i in consumable_stock.size():
		var entry: Dictionary = consumable_stock[i]
		var cid := String(entry["consumable_id"])
		var row: Dictionary = Consumables.row_of(cid)
		var cost := consumable_price(cid)
		out.append({
			"index": i,
			"consumable_id": cid,
			"name": String(row.get("name", cid)),
			"price": cost,
			"sold": bool(entry["sold"]),
			"icon": String(row.get("icon", "")),
			"color": row.get("color", Color.WHITE),
			"affordable": ctx.run.cogs >= cost,
			"can_hold": ctx.run.can_hold_consumable(),
		})
	return out


func buy_consumable(index: int) -> Dictionary:
	if not inside:
		return _result(false, CLOSED)
	if index < 0 or index >= consumable_stock.size() or bool(consumable_stock[index]["sold"]):
		return _result(false, SOLD_OUT)
	var cid := String(consumable_stock[index]["consumable_id"])
	if not ctx.run.can_hold_consumable():
		return _result(false, CAPPED, "", cid)
	var cost := consumable_price(cid)
	if not ctx.run.spend_cogs(cost):
		return _result(false, CANT_AFFORD, "moss.bark.cant_afford", cid, cost)
	consumable_stock[index]["sold"] = true
	bought_this_visit += 1
	ctx.run.add_consumable(cid)
	return _result(true, OK, "moss.bark.buy", cid, cost)


func belt_offer() -> Dictionary:
	var cost := int(round(Consumables.BELT_PRICE * _price_scale()))
	var slots: int = ctx.run.consumable_capacity()
	var max_slots: int = ctx.run.CONSUMABLE_SLOTS_MAX
	return {
		"part_id": Consumables.BELT_PART_ID,
		"price": cost,
		"slots": slots,
		"max_slots": max_slots,
		"can": slots < max_slots,
		"affordable": ctx.run.cogs >= cost,
	}


func buy_belt_slot() -> Dictionary:
	if not inside:
		return _result(false, CLOSED)
	var offer := belt_offer()
	if not bool(offer["can"]):
		return _result(false, CAPPED, "", Consumables.BELT_PART_ID)
	var cost := int(offer["price"])
	if not ctx.run.spend_cogs(cost):
		return _result(false, CANT_AFFORD, "moss.bark.cant_afford", Consumables.BELT_PART_ID, cost)
	bought_this_visit += 1
	ctx.run.expand_consumable_belt()
	return _result(true, OK, "moss.bark.buy", Consumables.BELT_PART_ID, cost)


func sell_quote(part_id: String) -> int:
	if not part_id in ctx.run.parts:
		return -1
	if not _can_remove(part_id):
		return -1
	var held: int = mini(ctx.run.parts.size() - 1, ctx.run.parts.find(part_id))
	var now: float = Fabricators.price(part_id, held) * _price_scale()
	if part_id in Items.CELLS_FOR.values():
		now = _cell_cost(ctx.run.parts.count(part_id) - 1)
	return int(floor(now * Fabricators.COG_PRICES["sell_share"]))


func sell_offers() -> Array:
	var out: Array = []
	var seen := {}
	for part_id in ctx.run.parts:
		if seen.has(part_id):
			continue
		seen[part_id] = true
		var d: Resource = Parts.def(part_id)
		out.append({"part_id": part_id, "name": Parts.display_name(part_id), "quote": sell_quote(part_id),
			"icon": "cat_" + (d.icon_category if d != null else "utility")})
	return out


func sell(part_id: String) -> Dictionary:
	if not inside:
		return _result(false, CLOSED)
	var quote: int = sell_quote(part_id)
	if quote < 0:
		return _result(false, NOT_HELD if not part_id in ctx.run.parts else WELDED, "", part_id)
	_remove_part(part_id)
	_refund(quote)
	return _result(true, OK, "moss.bark.sell", part_id, -quote)


func top_shelf() -> Dictionary:
	if top.is_empty():
		return {}
	var locked: bool = ctx.run.heft_class() < top["lock_class"]
	return {"part_id": top["part_id"], "name": Parts.display_name(top["part_id"]), "price": price(top["part_id"]),
		"odds": Parts.odds_for(top.get("table", TOP_RARITIES), ctx.run.class_id()), "locked": locked, "needs_class": top["lock_class"], "heft_class": ctx.run.heft_class(),
		"lock_icon": "res_heft", "sold": top["sold"], "relented": talks["relented"]}


func buy_top() -> Dictionary:
	if not inside:
		return _result(false, CLOSED)
	var t: Dictionary = top_shelf()
	if t.is_empty() or t["sold"]:
		return _result(false, SOLD_OUT)
	if t["locked"]:
		return _result(false, LOCKED, "moss.refuse.2", t["part_id"])
	if not ctx.run.spend_cogs(t["price"]):
		return _result(false, CANT_AFFORD, "moss.bark.cant_afford", t["part_id"], t["price"])
	top["sold"] = true
	bought_this_visit += 1
	ctx.run.add_part(t["part_id"], "shop")
	return _result(true, OK, "moss.bark.buy", t["part_id"], t["price"])


func talk() -> Dictionary:
	if not inside:
		return {}
	var class_ok: bool = not top.is_empty() and ctx.run.heft_class() >= top["lock_class"]
	if class_ok:
		var first: bool = not talks["relented"]
		talks["relented"] = true
		var relent: String = _variation("relent", ["moss.relent.1", "moss.relent.2", "moss.relent.3"])
		if first and ctx.codex != null:
			ctx.codex.mark_discovered(CODEX_ID, ctx.player.ball_position() if ctx.player != null else Vector3.ZERO, ["player"])
		return _talk_record(-1, relent, RELENT_ROOT, false, true, false)
	var beat: int = talks["beat"] + 1
	if beat == BEATS.size():
		talks["beat"] = -1
		talks["loops"] += 1
		return _talk_record(BEATS.size(), "moss.restart", BEATS[0]["root"], false, false, true)
	talks["beat"] = beat
	var row: Dictionary = BEATS[beat]
	var ids: Array = []
	for key in LINES:
		if key.begins_with("moss.%s." % row["id"]):
			var only: String = CLASS_LINES.get(key, "")
			if only == "" or only == ctx.run.class_id():
				ids.append(key)
	return _talk_record(beat, _variation(row["id"], ids), row["root"], row["grumble"], false, false)


func _talk_record(beat: int, line_id: String, root: String, grumble: bool, relent: bool, restart: bool) -> Dictionary:
	return {"beat": beat, "beat_id": BEATS[beat]["id"] if beat >= 0 and beat < BEATS.size() else ("relent" if relent else "restart"),
		"line_id": line_id, "text": LINES[line_id], "root": root, "grumble": grumble, "exasperation": maxi(beat, 0),
		"relent": relent, "restart": restart, "loops": talks["loops"]}


func _variation(beat_id: String, ids: Array) -> String:
	var used: Array = talks["used"].get(beat_id, [])
	var fresh: Array = ids.filter(func(id): return not id in used)
	if fresh.is_empty():
		used = []
		fresh = ids.duplicate()
	var pick: String = fresh[_rng.randi_range(0, fresh.size() - 1)]
	used.append(pick)
	talks["used"][beat_id] = used
	return pick


func price(part_id: String) -> int:
	if ActiveOffers.is_offer(part_id):
		return int(round(ActiveOffers.price(_active_row(part_id), Parts.priced_count(ctx.run.parts)) * _price_scale()))
	return int(round(Fabricators.price(part_id, Parts.priced_count(ctx.run.parts)) * _price_scale()))


func _price_scale() -> float:
	return build.effects.price_scale if build != null and build.effects != null else 1.0


func _offer(part_id: String, sold: bool, index: int) -> Dictionary:
	if ActiveOffers.is_offer(part_id):
		var g := ActiveOffers.gate_record(part_id, _active_row(part_id))
		return {"index": index, "part_id": part_id, "name": g["name"], "price": price(part_id), "sold": sold,
			"rarity": g["rarity"], "text": g["text"], "icon": g["icon"], "trigger_icon": "", "element_icon": "",
			"affordable": ctx.run.cogs >= price(part_id), "active": g["active"], "maker": g["maker"],
			"headline": "%s. %s" % [g["headline"], g["mark"]]}
	var d: Resource = Parts.offer_def(part_id, ctx.run.parts)
	return {"index": index, "part_id": part_id, "name": Parts.display_name(part_id), "price": price(part_id),
		"sold": sold, "rarity": d.rarity if d != null else "common", "text": d.text if d != null else "",
		"icon": "cat_" + (d.icon_category if d != null else "utility"),
		"trigger_icon": "trg_" + d.trigger if d != null and d.trigger != "" else "",
		"element_icon": "el_" + d.element if d != null and d.element != "" else "",
		"affordable": ctx.run.cogs >= price(part_id)}


func _result(ok: bool, reason: String, line_id := "", part_id := "", cost := 0) -> Dictionary:
	var out := {"ok": ok, "reason": reason, "part_id": part_id, "price": cost, "cogs": ctx.run.cogs, "scrap": ctx.run.scrap}
	if line_id != "":
		out["bark"] = line(line_id)
	return out


func _stock() -> Array:
	if ctx != null and ctx.run != null and ctx.run.has_method("override_on") and ctx.run.override_on("maker_focused_shelves"):
		var maker := _focused_maker()
		if maker != "":
			var focused_pool := _set_pool(maker, [])
			if not focused_pool.is_empty():
				var focused_out: Array = []
				var focused_odds: Array = Parts.odds_for(SHELF_RARITIES, ctx.run.class_id())
				var pool_copy := focused_pool.duplicate()
				for _k in mini(SHELF_SIZE, pool_copy.size()):
					var idx := _rng.randi_range(0, pool_copy.size() - 1)
					focused_out.append({"part_id": String(pool_copy[idx]), "sold": false, "odds": focused_odds})
					pool_copy.remove_at(idx)
				if focused_out.size() < SHELF_SIZE:
					var used_ids: Array = focused_out.map(func(e): return e["part_id"])
					for fill_id in Parts.roll(_rng, SHELF_RARITIES, ctx.run.class_id(), ctx.run.parts, SHELF_SIZE - focused_out.size(), used_ids):
						focused_out.append({"part_id": fill_id, "sold": false, "odds": focused_odds})
				return focused_out
	var stage: int = int(ctx.run.stage) if ctx != null and ctx.run != null else 1
	var deep_world := stage >= PartOffers.WORLD_ESCALATION_STAGE_W2
	var near_set := deep_world and _set_near_complete()
	var set_pick: String = _set_pick() if (last_call() or near_set) else ""
	var floor_pick: Array = [set_pick] if set_pick != "" else (
		Parts.roll_high_impact(_rng, FLOOR_RARITIES, ctx.run.class_id(), ctx.run.parts, 1, [], {}, stage, false)
		if deep_world else Parts.roll(_rng, FLOOR_RARITIES, ctx.run.class_id(), ctx.run.parts, 1))
	var picks: Array = PartOffers.roll_for_stage(_rng, SHELF_RARITIES, ctx.run.class_id(), ctx.run.parts,
		SHELF_SIZE - floor_pick.size(), stage, floor_pick, {}, false, Parts.offer_ops()) if deep_world \
		else Parts.roll(_rng, SHELF_RARITIES, ctx.run.class_id(), ctx.run.parts, SHELF_SIZE - floor_pick.size(), floor_pick)
	var out: Array = []
	for part_id in floor_pick:
		var entry := {"part_id": part_id, "sold": false, "odds": [] if set_pick != "" else Parts.odds_for(FLOOR_RARITIES, ctx.run.class_id())}
		if set_pick != "":
			entry["set"] = MakerSets.maker_of(part_id)
		out.append(entry)
	var odds: Array = Parts.odds_for(SHELF_RARITIES, ctx.run.class_id())
	for part_id in picks:
		out.append({"part_id": part_id, "sold": false, "odds": odds})
	var rack = _rack()
	if rack != null and not out.is_empty():
		var active: String = build.active_offer_for_channel("shop", SHELF_RARITIES, _rng, deep_world) \
			if build != null and build.has_method("active_offer_for_channel") \
			else ActiveOffers.roll(_rng, "shop", rack.rows(), SHELF_RARITIES, rack.held())
		if active != "":
			out[-1] = {"part_id": active, "sold": false, "odds": odds}
	return out


func _set_near_complete() -> bool:
	var target := set_piece()
	return not target.is_empty() and int(target["pieces"]) - int(target["held"]) == 1


func last_call() -> bool:
	var stages = ctx.get("stages") if ctx != null else null
	return stages != null and stages.BOSS != "" and stages.is_world_last(ctx.run.stage)


func set_piece() -> Dictionary:
	var counted: Dictionary = _set_counts()
	var best := {}
	for maker in MakerSets.SETS:
		var held := int(counted.get(maker, 0))
		var pieces := int(MakerSets.SETS[maker]["pieces"])
		if held <= 0 or held >= pieces or _set_pool(maker, []).is_empty():
			continue
		if best.is_empty() or pieces - held < int(best["pieces"]) - int(best["held"]):
			best = {"maker": maker, "held": held, "pieces": pieces}
	return best


func _set_counts() -> Dictionary:
	return build.maker_counts() if build != null and build.has_method("maker_counts") else MakerSets.counts(ctx.run.parts)


func _set_pick() -> String:
	var target := set_piece()
	if target.is_empty():
		return ""
	var pool := _set_pool(String(target["maker"]), [])
	return pool[_rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else ""


func _focused_maker() -> String:
	var counted: Dictionary = _set_counts()
	var best_maker := ""
	var best_count := 0
	for maker in MakerSets.SETS:
		var c := int(counted.get(maker, 0))
		if c > best_count and not _set_pool(maker, []).is_empty():
			best_count = c
			best_maker = maker
	if best_maker != "":
		return best_maker
	for maker in MakerSets.SETS:
		if not _set_pool(maker, []).is_empty():
			return maker
	return ""


func _set_pool(maker: String, exclude: Array) -> Array:
	var pool: Array = Parts.offer_pool(ctx.run.class_id(), SHELF_RARITIES + FLOOR_RARITIES).filter(func(id):
		return MakerSets.maker_of(id) == maker and not id in ctx.run.parts and not id in exclude)
	pool.sort()
	return pool


func brew_offer() -> Dictionary:
	if not last_call():
		return {}
	var pours := _pours()
	return {"pours": pours, "cap": BREW_PRICES.size(), "share": BREW_SHARE,
		"price": -1 if pours >= BREW_PRICES.size() else int(round(BREW_PRICES[pours] * _price_scale()))}


func _pours() -> int:
	return ctx.run.brew if ctx.run.brew_stage == ctx.run.stage else 0


func buy_brew() -> Dictionary:
	if not inside:
		return _result(false, CLOSED)
	var offer := brew_offer()
	if offer.is_empty():
		return _result(false, LOCKED)
	if int(offer["price"]) < 0:
		return _result(false, CAPPED)
	if not ctx.run.spend_cogs(int(offer["price"])):
		return _result(false, CANT_AFFORD, "moss.bark.cant_afford", "", int(offer["price"]))
	ctx.run.brew = _pours() + 1
	ctx.run.brew_stage = ctx.run.stage
	bought_this_visit += 1
	return _result(true, OK, "", "", int(offer["price"]))


func pour_brew() -> float:
	return _pours() * BREW_SHARE * UltimateMeter.CAP


func _rack():
	return build.active_rack() if build != null and build.has_method("active_rack") else null


func _active_row(part_id: String) -> Dictionary:
	var rack = _rack()
	var id := ActiveOffers.active_of(part_id)
	return rack.row_of(id) if rack != null else {}


func _roll_one(rarities: Array, exclude: Array = []) -> String:
	var picks: Array = Parts.roll(_rng, rarities, ctx.run.class_id(), ctx.run.parts, 1, exclude)
	if not picks.is_empty():
		return picks[0]
	if PartOffers.listed_only():
		var any: Array = Parts.roll(_rng, SHELF_RARITIES, ctx.run.class_id(), ctx.run.parts, 1, exclude)
		return any[0] if not any.is_empty() else ""
	return ItemGen.roll_id(_rng, rarities[0])


func _roll_hook(exclude: Array = []) -> Dictionary:
	var stage: int = int(ctx.run.stage) if ctx != null and ctx.run != null else 1
	if PartOffers.listed_only() and not Parts.offer_pool(ctx.run.class_id(), TOP_RARITIES).is_empty():
		for table in [TOP_RARITIES, TOP_FALLBACK]:
			var picks: Array = Parts.roll_high_impact(_rng, table, ctx.run.class_id(), ctx.run.parts, 1, exclude, {}, stage, false) \
				if table == TOP_FALLBACK and stage >= PartOffers.WORLD_ESCALATION_STAGE_W2 \
				else Parts.roll(_rng, table, ctx.run.class_id(), ctx.run.parts, 1, exclude)
			if not picks.is_empty():
				return {"part_id": picks[0], "table": table}
		return {"part_id": _roll_one(SHELF_RARITIES, exclude), "table": SHELF_RARITIES}
	var part_id := _roll_one(TOP_RARITIES, exclude)
	var top_rung: bool = part_id != "" and Parts.rarity_of(part_id) in TOP_RARITIES
	return {"part_id": part_id, "table": TOP_RARITIES if top_rung else SHELF_RARITIES}


func _cheapest_price() -> int:
	var cheapest := 0
	for s in shelf:
		if not s["sold"]:
			var p: int = price(s["part_id"])
			cheapest = p if cheapest == 0 else mini(cheapest, p)
	return cheapest


func _can_remove(part_id: String) -> bool:
	var d: Resource = Parts.def(part_id)
	return d != null and d.patterns.is_empty() and not Relics.is_relic(part_id)


func _remove_part(part_id: String) -> void:
	if not ctx.run.remove_part(part_id):
		return
	if build != null:
		build.recompute()


func _refund(amount: int) -> void:
	if amount <= 0:
		return
	ctx.run.add_cogs(amount)


func ingot_counts() -> Dictionary:
	return Fabricators.scrap_ingots(ctx.run if ctx != null else null)


func scrap_to_ingot(part_id: String) -> Dictionary:
	if not inside:
		return _result(false, CLOSED, "", part_id)
	var res := Fabricators.scrap_part(ctx.run, part_id, build)
	if not bool(res.get("ok", false)):
		var reason := String(res.get("reason", NOT_HELD))
		return _result(false, NOT_HELD if reason in ["empty", "not_held"] else WELDED, "", part_id)
	var out := _result(true, OK, "moss.bark.sell", part_id, 0)
	out["tier"] = int(res["tier"])
	out["rarity"] = String(res["rarity"])
	out["ingots"] = int(res["ingots"])
	return out


func press_duplicate(target_part_id: String) -> Dictionary:
	if not inside:
		return _result(false, CLOSED, "", target_part_id)
	var res := Fabricators.press_part(ctx.run, target_part_id, _press_rng, build)
	if not bool(res.get("ok", false)):
		var reason := String(res.get("reason", NO_FUEL))
		return _result(false, CAPPED if reason == "capped" else NO_FUEL, "", target_part_id)
	bought_this_visit += 1
	var out := _result(true, OK, "moss.bark.buy", target_part_id, 0)
	out["tier"] = int(res["tier"])
	out["paid_kind"] = String(res["paid_kind"])
	out["sacrificed"] = String(res["sacrificed"])
	out["ingots_left"] = int(res["ingots_left"])
	return out


func _stock_tri_terminal() -> Array:
	var stage: int = int(ctx.run.stage) if ctx != null and ctx.run != null else 1
	var picks: Array = PartOffers.roll_for_stage(_tri_rng, SHELF_RARITIES, ctx.run.class_id(), ctx.run.parts, TRI_TERMINAL_SIZE, stage, [], {}, false, Parts.offer_ops()) \
		if stage >= PartOffers.WORLD_ESCALATION_STAGE_W2 \
		else Parts.roll(_tri_rng, SHELF_RARITIES, ctx.run.class_id(), ctx.run.parts, TRI_TERMINAL_SIZE)
	var out: Array = []
	for i in picks.size():
		out.append({"part_id": String(picks[i]), "sold": false, "chosen": false, "revealed": i == 0})
	return out


func tri_terminal_offers() -> Array:
	var out: Array = []
	for i in tri_terminal.size():
		var entry: Dictionary = tri_terminal[i]
		var offer := _offer(String(entry["part_id"]), bool(entry["sold"]) or tri_terminal_closed, i)
		offer["chosen"] = bool(entry.get("chosen", false))
		offer["closed"] = tri_terminal_closed
		offer["revealed"] = bool(entry.get("revealed", i == 0))
		out.append(offer)
	return out


func buy_tri_terminal(index: int) -> Dictionary:
	if not inside:
		return _result(false, CLOSED)
	if tri_terminal_closed:
		return _result(false, TRI_CLOSED)
	if index < 0 or index >= tri_terminal.size() or bool(tri_terminal[index]["sold"]):
		return _result(false, SOLD_OUT)
	var part_id := String(tri_terminal[index]["part_id"])
	var cost: int = price(part_id)
	if not ctx.run.spend_cogs(cost):
		return _result(false, CANT_AFFORD, "moss.bark.cant_afford", part_id, cost)
	tri_terminal_closed = true
	for i in tri_terminal.size():
		tri_terminal[i]["sold"] = true
		tri_terminal[i]["chosen"] = (i == index)
	bought_this_visit += 1
	ctx.run.add_part(part_id, "tri_terminal")
	return _result(true, OK, "moss.bark.buy", part_id, cost)


func audit_reroll(rng: RandomNumberGenerator = null) -> Dictionary:
	if shelf.is_empty():
		return {"rerolled": 0, "before_tiers": [], "after_tiers": []}
	var roll_rng := rng if rng != null else _tri_rng
	var before_tiers: Array[int] = []
	var after_tiers: Array[int] = []
	var used: Array = []
	for entry in shelf:
		used.append(String(entry["part_id"]))
	var rerolled := 0
	for i in shelf.size():
		if bool(shelf[i].get("sold", false)):
			continue
		var old_id := String(shelf[i]["part_id"])
		if ActiveOffers.is_offer(old_id):
			continue
		var old_tier := Fabricators.tier_of(old_id)
		before_tiers.append(old_tier)
		var rarities: Array = ["rare", "relic"] if old_tier >= 2 else ["common", "rare"]
		var candidates: Array = Parts.offer_pool(ctx.run.class_id(), rarities).filter(func(pid):
			var d: Resource = Parts.def(pid)
			return d != null and int(d.tier) >= old_tier and not (pid in used) and not Parts.stacked_out(pid, ctx.run.parts) and not Parts.maxed(pid, ctx.run.parts))
		if candidates.is_empty():
			candidates = Parts.offer_pool(ctx.run.class_id(), rarities).filter(func(pid):
				var d: Resource = Parts.def(pid)
				return d != null and int(d.tier) >= old_tier and pid != old_id)
		if not candidates.is_empty():
			candidates.sort()
			var picked := String(candidates[roll_rng.randi_range(0, candidates.size() - 1)])
			shelf[i]["part_id"] = picked
			used.append(picked)
			after_tiers.append(Fabricators.tier_of(picked))
			rerolled += 1
		else:
			after_tiers.append(old_tier)
	return {"rerolled": rerolled, "before_tiers": before_tiers, "after_tiers": after_tiers}
