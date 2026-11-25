extends RefCounted

const Parts := preload("res://src/build/parts.gd")
const LoopTally := preload("res://src/core/loop_tally.gd")
const Relics := preload("res://src/build/relics.gd")
const Items := preload("res://src/build/items.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const OddsReadout := preload("res://src/ui/odds_readout.gd")
const ActiveOffers := preload("res://src/combat/actives/active_offers.gd")
const MakerSets := preload("res://src/build/maker_sets.gd")
const UltimateMeter := preload("res://src/core/ultimate_meter.gd")
const Consumables := preload("res://src/build/consumables.gd")

# Moss's workshop economy (DESIGN-V2 section 12): the shelf, the reroll, charge cells,
# sell-back, the heft-locked top shelf and the conversation loop. It has no geometry:
# W6's bay calls enter() and leave(), W1's shop UI reads the records and calls the
# verbs. Every verb returns a result record with the bark Moss says, so the UI, the
# babble and the tests read one answer. Nothing here is rolled on entry that a player
# cannot see: the shelf is visible and bought on purpose.
#
# Every Moss line is SOUND-STORY section 8's, word for word, keyed by the ids below;
# shop_lines_test fails if a line is missing from that file or runs past 12 words.

const SHELF_SIZE := 3
const CONSUMABLE_STOCK_SIZE := 2
const SHELF_RARITIES := ["common", "rare"]
const TOP_RARITIES := ["relic"]
const FLOOR_RARITIES := ["rare"]
# The hook's stock once the table's relics are all held (in world 1, once the Spare Frame is
# yours): the top ordinary rung of the alpha, cobalt (ruling bn), so the part Moss calls too
# strong for you is never a common off the shelf.
const TOP_FALLBACK := FLOOR_RARITIES
# Prices are cogs, from Fabricators.COG_PRICES: the reroll costs reroll_base at the first
# stage's shelf and rises by reroll_growth each stage's shelf after; a charge cell costs cell_base, rising
# by cell_growth for each cell already in that slot; a sale pays sell_share of the price.
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

# Moss's last call (W1-73, gameplay critique finding 11): the bay after a world's last Warden
# launches the ball into that world's boss arena, so it is the last till of the world and cogs
# held past it die at the boss. There the shelf's first slot is a piece of the maker set the
# player is nearest to finishing, and Moss's kettle takes cogs: each pour starts the boss fight
# with BREW_SHARE of the ultimate meter filled, BREW_PRICES[pour] cogs each, so a full brew opens
# the fight with the ultimate ready. Prices are a first cut at the 1,332 to 2,012 cogs the economy
# pass found unspent at Brindle (assumption Andrew can overturn).
const BREW_PRICES := [250, 450, 700]
const BREW_SHARE := 1.0 / 3.0

# The conversation's six beats (SOUND-STORY section 8, "The conversation loop"), with
# the babble's root per beat and whether a refusal grumble sits under the first word.
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
# Class-tagged lines are extra choices for that class only.
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
# Which remembers-you line wins when several keys hold, first match first.
const REMEMBER_ORDER := ["neglected", "relented_before", "died_last_run", "won_last_run", "class_changed",
	"skipped_visits"]
const CODEX_ID := "too_heavy_for_you"

var ctx
var build
var visit := 0
var inside := false
var shelf: Array = []
var consumable_stock: Array = []
var top := {}
var rerolls_left := 0
var bought_this_visit := 0
# In-run memory: the neglect callback (C14) and anything PROGRESSION's profile hands in.
var history := {}
var neglected := false
var talks := {"beat": -1, "used": {}, "loops": 0, "relented": false}
var leaves_this_visit: Array = []
# The [world, stage] the shelf was stocked for. Re-entering the bay in the same stage finds the
# same shelf, hook and reroll; only a new stage or the paid reroll restocks (speedrunner red
# team, w21: a re-entry restock made the cobalt floor a fresh cobalt each lap). A retry or replay
# rewinds the run, so it rewinds the shop to that stage's first stock too (rewind_stage).
var stocked_for: Array = []
# Stages stocked this run, which prices the reroll.
var stocks := 0
var _stage_stocks := {}

var _rng := RandomNumberGenerator.new()
var _cons_rng := RandomNumberGenerator.new()
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
	top = {}
	stocked_for = []
	stocks = 0
	_stage_stocks = {}
	neglected = false
	_left_empty = false
	talks = {"beat": -1, "used": {}, "loops": 0, "relented": false}


static func line(line_id: String) -> Dictionary:
	return {"line_id": line_id, "text": LINES.get(line_id, ""), "root": BARK_ROOT}


# ---- The bay's two calls (W6) ----

# The ball rolled into the bay. Stocks the shelf and the hook once per stage and
# returns the greeting line. The difficulty clock pauses until leave().
func enter() -> Dictionary:
	inside = true
	visit += 1
	bought_this_visit = 0
	var here := [ctx.run.world, ctx.run.stage]
	if here != stocked_for:
		_stock_stage(here)
	talks = {"beat": -1, "used": {}, "loops": 0, "relented": false}
	var greeting: Dictionary = greeting_line()
	# Moss takes every carried ledger leaf on entry; the greeting says so.
	leaves_this_visit = _return_leaves()
	if not leaves_this_visit.is_empty():
		greeting = line("moss.ledger.%d" % clampi(ctx.progress.leaves_returned(), 1, 3))
	neglected = false
	return greeting


# The first stock of a stage: shelf, hook (locked one heft class up; at the top class the hook
# is already yours) and the reroll, kept so a retry can put it back. A hook left locked carries
# on to the next stage's stock at the class it asked for (W1-79), so growing into it is a goal
# the HUD can pin (hook_goal), not a lock that moves up with the ball.
func _stock_stage(here: Array) -> void:
	var carried := _carried_hook() if not stocked_for.is_empty() and stocked_for != here else {}
	stocked_for = here
	stocks += 1
	rerolls_left = REROLLS_PER_VISIT
	# Seeded by the run and the stage, not bay entries or stocks so far, so hopping in and out of
	# the bay never picks a later stage's shelf, and a Continue (which starts the count again)
	# stocks the shelf the first sitting saw.
	_rng.seed = hash([SEED, ctx.flow.run_key() if ctx.flow != null else ctx.run.run_seed, ctx.run.world, ctx.run.stage, "shelf"])
	# The shelf and the hook draw as they always have, so a Continue (which carries no hook)
	# stocks the shelf the first sitting saw; a carried hook then takes the drawn hook's place
	# unless the shelf drew the same part.
	shelf = _stock()
	var lock_class: int = mini(TOP_CLASS_MAX, ctx.run.heft_class() + 1)
	var hook := _roll_hook(shelf.map(func(entry): return entry["part_id"]))
	top = {"part_id": hook["part_id"], "table": hook["table"], "lock_class": lock_class, "sold": false} if hook["part_id"] != "" else {}
	if not carried.is_empty() and not shelf.any(func(entry): return entry["part_id"] == carried["part_id"]):
		top = carried
	_cons_rng.seed = hash([SEED, ctx.flow.run_key() if ctx.flow != null else ctx.run.run_seed, ctx.run.world, ctx.run.stage, "consumables"])
	consumable_stock = _stock_consumables()
	_stage_stocks[str(here)] = {"shelf": shelf.duplicate(true), "consumables": consumable_stock.duplicate(true), "top": top.duplicate(true), "rng": _rng.state}


# The last stage's hook, unsold and still above the ball's class, with the class it asked for;
# {} when there is none to carry (bought, opened, or never stocked).
func _carried_hook() -> Dictionary:
	if top.is_empty() or top["sold"] or ctx.run.heft_class() >= int(top["lock_class"]):
		return {}
	if Parts.stacked_out(top["part_id"], ctx.run.parts):
		return {}
	var out := top.duplicate(true)
	out["carried"] = true
	return out


# The heft class a seen, locked hook is waiting for, for the HUD's pin (W1-79); 0 when none.
func hook_goal() -> int:
	if top.is_empty() or top["sold"] or stocks == 0:
		return 0
	var needs := int(top["lock_class"])
	return needs if ctx.run.heft_class() < needs else 0


# A retry or replay (stage_entered with retry) put the run back to the stage's start: its cogs
# and parts come back, so the shelf comes back unsold, with the hook and the reroll. A stage this
# run never stocked is stocked fresh on the next entry.
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
	top = kept["top"].duplicate(true)
	# The draws after the stock come back too, so a retry's reroll is the first attempt's reroll.
	_rng.state = kept["rng"]


func leave() -> Dictionary:
	inside = false
	_left_empty = bought_this_visit == 0
	_cheapest_left = _cheapest_price()
	return line("moss.bark.leaving")


func _return_leaves() -> Array:
	if ctx.progress == null or not ctx.progress.has_method("return_leaves"):
		return []
	return ctx.progress.return_leaves(ctx.player.ball_position() if ctx.player != null else Vector3.ZERO)


func clock_paused() -> bool:
	return inside


# The run's death: dying after leaving empty-handed while holding a shelf part's worth
# of cogs is what Moss notices next time (callback C14).
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


# ---- The shelf ----

func shelf_offers() -> Array:
	var out: Array = []
	for i in shelf.size():
		var offer := _offer(shelf[i]["part_id"], shelf[i]["sold"], i)
		offer["odds"] = shelf[i].get("odds", [])
		offer["odds_text"] = OddsReadout.text(offer["odds"])
		# The last call's set piece names its maker, and how many of the set are held without it.
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


# ---- Moss's scale: mass for cogs (systems audit pass D, new mechanic 2) ----

# Behind `--moss-scale=on` (Tuning "moss_scale", default off). A press weighs one lump of mass,
# up to weigh_lump, and pays a cog for each mass_per_cog of it (Fabricators.COG_PRICES).
# Arrive at the Warden heavy, or light with a better part: size never touches handling
# (BIBLE.md section 6), so the trade is armour, heft and punch against the shelf.

func scale_open() -> bool:
	return ctx != null and ctx.tuning != null and ctx.tuning.option("moss_scale") == "on"


# What one press would weigh and pay now: {mass, cogs}. Both 0 when the scale is shut or the
# ball is too light to pay a cog.
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


# ---- Carry a core in SPIL-9 (systems audit pass D, new mechanic 3) ----

# Behind `--carry-core=on` (Tuning "carry_core", default off). Moss seats one of this stage's
# cores in a SPIL-9 socket; it rides to the next stage and counts at that stage's gate
# (run_state.stow_core). SPIL-9's help here against a better gate there.
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


# ---- Charge cells: the stockpile path ----

# One record per ability slot that recharges (a slot with no cooldown has nothing to
# stockpile): {slot, part_id, price, cells, cap, max_charges, can}.
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


# ---- Pocket Consumables (W47-C1): cheap cog cartridges & 2-slot belt expansion ----

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


# ---- Sell-back ----

# Half what the part would cost now, or -1 when it cannot be sold here. A charge cell is quoted
# off the cell price it was bought at, not the part curve: that curve rises with parts held while
# the cell price does not, so from seven parts a bought cell sold back for more than it cost
# (greedy red team, w24).
func sell_quote(part_id: String) -> int:
	if not part_id in ctx.run.parts:
		return -1
	if not _can_remove(part_id):
		return -1
	# Priced at the parts held when this copy came in (its place in the run's list), never at
	# the count held now: the curve rises part_growth per part held, so a part kept while more
	# arrived sold back for more than it cost (invariants pass, 2026-11-08). A rack active is
	# never a held part (active_rack.take), so it has no quote and cannot be sold back.
	var held: int = mini(ctx.run.parts.size() - 1, ctx.run.parts.find(part_id))
	var now: float = Fabricators.price(part_id, held) * _price_scale()
	if part_id in Items.CELLS_FOR.values():
		now = _cell_cost(ctx.run.parts.count(part_id) - 1)
	return int(floor(now * Fabricators.COG_PRICES["sell_share"]))


# Every held part with its quote, for the UI: {part_id, name, quote, icon}.
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


# ---- The top shelf (the heft lock) ----

func top_shelf() -> Dictionary:
	if top.is_empty():
		return {}
	var locked: bool = ctx.run.heft_class() < top["lock_class"]
	# The odds are the table the hook was drawn from (_roll_hook): the top rarities, else the
	# cobalt fallback, else the shelf's.
	return {"part_id": top["part_id"], "name": Parts.display_name(top["part_id"]), "price": price(top["part_id"]),
		"odds": OddsReadout.odds_for(top.get("table", TOP_RARITIES), ctx.run.class_id()), "locked": locked, "needs_class": top["lock_class"], "heft_class": ctx.run.heft_class(),
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


# ---- The conversation loop ----

# One press of the key by Moss: one beat. After the sixth beat the next press says the
# restart line and the one after begins again with fresh variations. Once the ball is
# heavy enough for the hook, the press is the relent: the loop ends, the hook unlocks
# and the codex learns "Too heavy for you".
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


# A variation the visit has not used yet for this beat; once all are used, they all
# come back. The pick draws from the stream the stage's stock seeded, so a replay says the same thing.
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


# ---- Prices and records ----

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


# 2026-10-18 (w17 answers): the shelf and the hook draw through Parts.roll, so a part that answers
# the pilot's nemesis (Parts.ANSWERS, Nemesis.OFFER_WEIGHT) is stocked more often by the same lean the
# gates get. It moves weight inside a part's offer bucket only, so the shelf's mix of buckets and its
# rarities, and every price, stay as they were (answer_weights_test).
func _stock() -> Array:
	# The last call's first slot is the nearest maker set's missing piece (set_piece) in place of the
	# cobalt rung's draw; elsewhere, and when no set is started, the rung as before.
	var set_pick: String = _set_pick() if last_call() else ""
	# The cobalt rung (item ladder, wave 20): the first slot draws from FLOOR_RARITIES, so it is
	# always a rare or better, and the other slots from the shelf's table.
	var floor_pick: Array = [set_pick] if set_pick != "" else Parts.roll(_rng, FLOOR_RARITIES, ctx.run.class_id(), ctx.run.parts, 1)
	var picks: Array = Parts.roll(_rng, SHELF_RARITIES, ctx.run.class_id(), ctx.run.parts,
		SHELF_SIZE - floor_pick.size(), floor_pick)
	var out: Array = []
	# Each record carries the odds of the table it was drawn from (SG13), read from the same
	# rarities and weight row its roll reads. The set piece is no draw, so it shows none.
	for part_id in floor_pick:
		var entry := {"part_id": part_id, "sold": false, "odds": [] if set_pick != "" else OddsReadout.odds_for(FLOOR_RARITIES, ctx.run.class_id())}
		if set_pick != "":
			entry["set"] = MakerSets.maker_of(part_id)
		out.append(entry)
	var odds: Array = OddsReadout.odds_for(SHELF_RARITIES, ctx.run.class_id())
	for part_id in picks:
		out.append({"part_id": part_id, "sold": false, "odds": odds})
	# With --actives on, Moss may shelve one active in the shelf's last slot (ActiveOffers), so
	# the shelf keeps its three tiles.
	var rack = _rack()
	if rack != null and not out.is_empty():
		var active := ActiveOffers.roll(_rng, "shop", rack.rows(), SHELF_RARITIES, rack.held())
		if active != "":
			out[-1] = {"part_id": active, "sold": false, "odds": odds}
	return out


# ---- Moss's last call (W1-73) ----

# This stage's bay is the world's last till: its launch lands in the world boss's arena.
func last_call() -> bool:
	var stages = ctx.get("stages") if ctx != null else null
	return stages != null and stages.BOSS != "" and stages.is_world_last(ctx.run.stage)


# The maker set nearest to waking: {maker, held, pieces}, fewest pieces missing first, then SETS
# order; {} when no set is started or every started set is whole.
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


# Pieces held per maker as the set bonuses count them, the racked active's included.
func _set_counts() -> Dictionary:
	return build.maker_counts() if build != null and build.has_method("maker_counts") else MakerSets.counts(ctx.run.parts)


func _set_pick() -> String:
	var target := set_piece()
	if target.is_empty():
		return ""
	var pool := _set_pool(String(target["maker"]), [])
	return pool[_rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else ""


# The maker's pieces the shelf may stock that the run does not hold yet, in a stable order.
func _set_pool(maker: String, exclude: Array) -> Array:
	var pool: Array = Parts.offer_pool(ctx.run.class_id(), SHELF_RARITIES + FLOOR_RARITIES).filter(func(id):
		return MakerSets.maker_of(id) == maker and not id in ctx.run.parts and not id in exclude)
	pool.sort()
	return pool


# The kettle at the last call: {pours, cap, price, share}; {} anywhere else. price is -1 once full.
func brew_offer() -> Dictionary:
	if not last_call():
		return {}
	var pours := _pours()
	return {"pours": pours, "cap": BREW_PRICES.size(), "share": BREW_SHARE,
		"price": -1 if pours >= BREW_PRICES.size() else int(round(BREW_PRICES[pours] * _price_scale()))}


# The pours bought on this stage (run_state.gd keeps them with the run, so a retry and a
# Continue rewind them with the cogs); a brew from another stage is spent already.
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


# What the boss fight's arrival pours into the ultimate meter, in meter points (ultimate.gd
# refunds them): the brew bought on this stage, at every arrival in its arena.
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
	# A table that lists its parts never gets a generated recipe. An empty pool falls back
	# to the shelf's rarities, never a part already on the shelf, and "" when none is left.
	if Parts.listed_only():
		var any: Array = Parts.roll(_rng, SHELF_RARITIES, ctx.run.class_id(), ctx.run.parts, 1, exclude)
		return any[0] if not any.is_empty() else ""
	return ItemGen.roll_id(_rng, rarities[0])


# The hook's part and the table it came from: {"part_id", "table"}. A table that lists a relic
# for this pilot (the park's Spare Frame) draws the top rarities first; once those relics are all
# held the hook draws a cobalt (TOP_FALLBACK), and only a pool with no cobalt left reaches the
# shelf's rarities. A table with no relic to list (alpha, slice, the default) and a table that
# generates its parts draw exactly as before, so their runs replay.
func _roll_hook(exclude: Array = []) -> Dictionary:
	if Parts.listed_only() and not Parts.offer_pool(ctx.run.class_id(), TOP_RARITIES).is_empty():
		for table in [TOP_RARITIES, TOP_FALLBACK]:
			var picks: Array = Parts.roll(_rng, table, ctx.run.class_id(), ctx.run.parts, 1, exclude)
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


# Sell-back never sells a pattern part, since combat rebuilds its patterns
# only on part_gained and would keep shooting the sold pattern until the next stage.
func _can_remove(part_id: String) -> bool:
	# A relic is the slot's kit rewrite, not stock: Moss never buys one back.
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
