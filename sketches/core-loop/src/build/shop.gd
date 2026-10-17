extends RefCounted

const Parts := preload("res://src/build/parts.gd")
const Items := preload("res://src/build/items.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const OddsReadout := preload("res://src/ui/odds_readout.gd")
const ActiveOffers := preload("res://src/combat/actives/active_offers.gd")

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
const SHELF_RARITIES := ["common", "rare"]
const TOP_RARITIES := ["relic"]
# Prices are cogs, from Fabricators.COG_PRICES: the reroll costs reroll_base at the first
# visit and rises by reroll_growth each visit after; a charge cell costs cell_base, rising
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
var top := {}
var rerolls_left := 0
var bought_this_visit := 0
# In-run memory: the neglect callback (C14) and anything PROGRESSION's profile hands in.
var history := {}
var neglected := false
var talks := {"beat": -1, "used": {}, "loops": 0, "relented": false}
var leaves_this_visit: Array = []

var _rng := RandomNumberGenerator.new()
var _left_empty := false
var _cheapest_left := 0


func _init(ctx_ref = null, build_ref = null) -> void:
	ctx = ctx_ref
	build = build_ref


func reset_run() -> void:
	visit = 0
	inside = false
	shelf = []
	top = {}
	neglected = false
	_left_empty = false
	talks = {"beat": -1, "used": {}, "loops": 0, "relented": false}


static func line(line_id: String) -> Dictionary:
	return {"line_id": line_id, "text": LINES.get(line_id, ""), "root": BARK_ROOT}


# ---- The bay's two calls (W6) ----

# The ball rolled into the bay. Stocks the shelf and the hook for this visit and
# returns the greeting line. The difficulty clock pauses until leave().
func enter() -> Dictionary:
	inside = true
	visit += 1
	bought_this_visit = 0
	rerolls_left = REROLLS_PER_VISIT
	_rng.seed = SEED + visit * 131 + ctx.run.stage * 17
	shelf = _stock()
	# The next heft class up; at the top class the hook is already yours.
	var lock_class: int = mini(TOP_CLASS_MAX, ctx.run.heft_class() + 1)
	var top_id := _roll_one(TOP_RARITIES, shelf.map(func(entry): return entry["part_id"]))
	top = {"part_id": top_id, "lock_class": lock_class, "sold": false} if top_id != "" else {}
	talks = {"beat": -1, "used": {}, "loops": 0, "relented": false}
	var greeting: Dictionary = greeting_line()
	# Moss takes every carried ledger leaf on entry; the greeting says so.
	leaves_this_visit = _return_leaves()
	if not leaves_this_visit.is_empty():
		greeting = line("moss.ledger.%d" % clampi(ctx.progress.leaves_returned(), 1, 3))
	neglected = false
	return greeting


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
	return int(round(Fabricators.COG_PRICES["reroll_base"] * pow(Fabricators.COG_PRICES["reroll_growth"], maxi(0, visit - 1))))


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
	var cells: int = ctx.run.parts.count(Items.CELLS_FOR.get(slot, ""))
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


# ---- Sell-back ----

# Half what the part would cost now, or -1 when it cannot be sold here.
func sell_quote(part_id: String) -> int:
	if not part_id in ctx.run.parts:
		return -1
	if not _can_remove(part_id):
		return -1
	var held: int = ctx.run.parts.size() - 1
	return int(floor(Fabricators.price(part_id, held) * _price_scale() * Fabricators.COG_PRICES["sell_share"]))


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
	# The table the hook was drawn from: the top rarities, or the shelf's when _roll_one fell back.
	var table: Array = TOP_RARITIES if Parts.rarity_of(top["part_id"]) in TOP_RARITIES else SHELF_RARITIES
	return {"part_id": top["part_id"], "name": Parts.display_name(top["part_id"]), "price": price(top["part_id"]),
		"odds": OddsReadout.odds_for(table, ctx.run.class_id()), "locked": locked, "needs_class": top["lock_class"], "heft_class": ctx.run.heft_class(),
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
# come back. The pick is seeded by the visit, so a replay says the same thing.
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
		return int(round(ActiveOffers.price(_active_row(part_id), ctx.run.parts.size()) * _price_scale()))
	return int(round(Fabricators.price(part_id, ctx.run.parts.size()) * _price_scale()))


func _price_scale() -> float:
	return build.effects.price_scale if build != null and build.effects != null else 1.0


func _offer(part_id: String, sold: bool, index: int) -> Dictionary:
	if ActiveOffers.is_offer(part_id):
		var g := ActiveOffers.gate_record(part_id, _active_row(part_id))
		return {"index": index, "part_id": part_id, "name": g["name"], "price": price(part_id), "sold": sold,
			"rarity": g["rarity"], "text": g["text"], "icon": g["icon"], "trigger_icon": "", "element_icon": "",
			"affordable": ctx.run.cogs >= price(part_id), "active": g["active"], "maker": g["maker"],
			"headline": "%s. %s" % [g["headline"], g["mark"]]}
	var d: Resource = Parts.def(part_id)
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
	var picks: Array = Parts.roll(_rng, SHELF_RARITIES, ctx.run.class_id(), ctx.run.parts, SHELF_SIZE)
	var out: Array = []
	# Each record carries the odds of the table it was drawn from (SG13), read from the same
	# SHELF_RARITIES and weight row the roll above reads.
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


func _cheapest_price() -> int:
	var cheapest := 0
	for s in shelf:
		if not s["sold"]:
			var p: int = price(s["part_id"])
			cheapest = p if cheapest == 0 else mini(cheapest, p)
	return cheapest


# Sell-back needs the run to take a part back. Until the spine's run_state grows
# remove_part() (requested in the W4 handback), the shop removes it here the same way
# that mutator would, and never sells a pattern part, since combat rebuilds its patterns
# only on part_gained and would keep shooting the sold pattern until the next stage.
func _can_remove(part_id: String) -> bool:
	if ctx.run.has_method("remove_part"):
		return true
	var d: Resource = Parts.def(part_id)
	return d != null and d.patterns.is_empty()


func _remove_part(part_id: String) -> void:
	var run = ctx.run
	if run.has_method("remove_part"):
		run.remove_part(part_id, "sold")
		return
	var i: int = run.parts.rfind(part_id)
	if i < 0:
		return
	run.parts.remove_at(i)
	run._publish_heft_class()
	if build != null:
		build.recompute()


func _refund(amount: int) -> void:
	if amount <= 0:
		return
	ctx.run.add_cogs(amount)
