extends RefCounted

const ItemGen := preload("res://src/build/item_gen.gd")
const Fabricators := preload("res://src/build/fabricators.gd")

# Actives as run loot (design page "Makers and Actives"; Andrew's "Core now", 17 Oct 2026). A
# reward gate with a rare or relic rung, the vault's payout and Moss's shelf may each carry one
# active, tagged with its maker, beside their parts. An active offer is never a part: its id is
# PREFIX + the active's id, it never reaches run.parts, and taking it racks the active on F while
# the one it replaces drops where the ball stands (active_rack.gd take()). Only with --actives on;
# off, no draw here runs, so the part rolls and their rng stay as they were.
#
# An active is added beside the parts, never swapped for one, so the part rules (the synergy
# bait, the harder-hitting slot, the stage 2 pattern guarantee, maxed parts leaving the pool)
# hold exactly as the part roll left them.

const PREFIX := "active:"
# The chance a draw carries an active, by source, once one fits its rarities.
const SHARE := {"gate": 0.3, "vault": 0.25, "shop": 0.35}
const ICON := "cat_damage"


static func is_offer(id: String) -> bool:
	return id.begins_with(PREFIX)


static func active_of(id: String) -> String:
	return id.substr(PREFIX.length()) if is_offer(id) else ""


static func offer_id(active_id: String) -> String:
	return PREFIX + active_id


# The actives a draw at these rarities may offer: every row whose rarity is among them, except
# the ones held (racked or dropped), in row order.
static func pool(rows: Dictionary, rarities: Array, held: Array) -> Array:
	rarities = ItemGen.resolve_rarities(rarities)
	var out: Array = []
	for id in rows:
		if not id in held and ItemGen.resolve_rarity(String(rows[id]["rarity"])) in rarities:
			out.append(id)
	return out


# One active offer id for a draw from `source`, or "". Spends the rng only when an active fits.
static func roll(rng: RandomNumberGenerator, source: String, rows: Dictionary, rarities: Array, held: Array) -> String:
	var ids := pool(rows, rarities, held)
	if ids.is_empty() or rng.randf() >= float(SHARE.get(source, 0.0)):
		return ""
	return offer_id(ids[rng.randi_range(0, ids.size() - 1)])


# The row's rarity id; an unknown or missing one reads as rare.
static func rarity_of(row: Dictionary) -> String:
	var id := ItemGen.resolve_rarity(String(row.get("rarity", "rare")))
	return id if id != "" else "rare"


# "Spillway Works" from "spillway_works".
static func maker_name(row: Dictionary) -> String:
	return String(row.get("maker", "")).capitalize()


# The star line under an active offer, the maker tag the gate and the shelf both show.
static func mark(row: Dictionary) -> String:
	return "* active, %s *" % maker_name(row)


# A gate offer record in reward_gates' shape for this active row.
static func gate_record(id: String, row: Dictionary) -> Dictionary:
	return {
		"part_id": id, "active": active_of(id), "maker": String(row.get("maker", "")),
		"name": row.get("name", ""), "headline": "%s: %s" % [row.get("name", ""), row.get("verb", "")],
		"verb": row.get("verb", ""), "punch": 0.0, "text": row.get("text", ""),
		"rarity": rarity_of(row), "hotwired": false, "tier": int(ItemGen.RARITY[rarity_of(row)]["tier"]),
		"synergy": "", "mark": mark(row), "family": "active", "icon": ICON, "trigger_icon": "", "element_icon": "",
	}


# Moss's price: a part of the active's tier at the run's part count, on the curve kept off the
# shelf (Fabricators.OFF_SHELF; docs/systems-audit/economy/README.md).
static func price(row: Dictionary, parts_held: int) -> int:
	return Fabricators.off_shelf_price(int(ItemGen.RARITY[rarity_of(row)]["tier"]), parts_held)
