extends RefCounted

const Parts := preload("res://src/build/parts.gd")
const Relics := preload("res://src/build/relics.gd")

# Maker sets (design page "Makers and Actives", 17 Oct 2026; Andrew tapped "Core now": the set
# bonuses on the existing items land before the sitting, the 5-piece transformations after it).
# Every find was made by someone for another job (Bible 5.3): each of the 62 items, Moss's cells,
# every relic and every active names its maker in its own row ("maker"). Holding SETS[maker]
# ["pieces"] distinct pieces of one maker turns its bonus on for the rest of the run; maker_
# bonuses.gd does what each bonus does. A copy of a piece already held is not a second piece:
# a set is a collection, so it pays for range, and luck still pays through the offer nudge.
#
# Overpowered pays: a set stays on while its pieces are held, and a bonus has no falloff.

const SPILLWAY := "spillway_works"
const FLEET := "fleet_surplus"
const REDJAW := "redjaw"
const ROOSTS := "highdraft_roosts"
const WAKING := "waking"
const MIND := "mind_glass"
const MOSS := "moss"

const SETS := {
	SPILLWAY: {"name": "Spillway Works", "pieces": 3, "bonus": "full_pressure", "bonus_name": "Full Pressure",
		"text": "Every active vents a steam ring that shoves machines back"},
	FLEET: {"name": "Fleet Surplus", "pieces": 3, "bonus": "rounded_up", "bonus_name": "Rounded Up",
		"text": "Every hit's damage rounds up to the next 5"},
	REDJAW: {"name": "Redjaw Workshops", "pieces": 3, "bonus": "bench_teeth", "bonus_name": "Bench Teeth",
		"text": "Your rolling line leaves teeth that bite anything crossing"},
	ROOSTS: {"name": "Highdraft Roosts", "pieces": 3, "bonus": "open_frame", "bonus_name": "Open Frame",
		"text": "An active fired in the air fires twice"},
	WAKING: {"name": "Waking-made", "pieces": 3, "bonus": "tremor", "bonus_name": "Tremor",
		"text": "Landing from a jump sends a ground ripple"},
	MIND: {"name": "Mind-glass", "pieces": 3, "bonus": "noticed", "bonus_name": "Noticed",
		"text": "Every crit leaves a glass splinter that strikes again"},
	MOSS: {"name": "Moss's Spares", "pieces": 2, "bonus": "packed_a_spare", "bonus_name": "Packed a Spare",
		"text": "The next item each stage comes with a second copy"},
}

static var _maker_of := {}


# The maker of a part row; "" for a generated recipe, an Evolved part, a burden or any row
# without a maker. A relic's part row carries its relic's maker; actives name theirs in their rows.
static func maker_of(part_id: String) -> String:
	if not _maker_of.has(part_id):
		_maker_of[part_id] = String(Parts.row(part_id).get("maker", "")) if Parts.has(part_id) else ""
	return _maker_of[part_id]


static func relic_maker(relic_id: String) -> String:
	return String(Relics.row(relic_id).get("maker", ""))


# maker -> distinct pieces held. `parts` is the run's part list (relics are parts in it),
# `extra` more makers to count once each (the racked active's).
static func counts(parts: Array, extra: Array = []) -> Dictionary:
	var seen := {}
	var out := {}
	for part_id in parts:
		_count(out, seen, "part:" + String(part_id), maker_of(String(part_id)))
	for i in extra.size():
		_count(out, seen, "extra:%d" % i, String(extra[i]))
	return out


static func _count(out: Dictionary, seen: Dictionary, key: String, maker: String) -> void:
	if maker == "" or not SETS.has(maker) or seen.has(key):
		return
	seen[key] = true
	out[maker] = int(out.get(maker, 0)) + 1


# The bonus ids live for these counts, in SETS order.
static func live_bonuses(counted: Dictionary) -> Array:
	var out := []
	for maker in SETS:
		if int(counted.get(maker, 0)) >= int(SETS[maker]["pieces"]):
			out.append(SETS[maker]["bonus"])
	return out


static func maker_of_bonus(bonus_id: String) -> String:
	for maker in SETS:
		if SETS[maker]["bonus"] == bonus_id:
			return maker
	return ""


# Problems with the maker fields, one string each; empty when sound. Every authored item row
# names a known maker, every relic does, and each set can be completed by every pilot from the
# rows that pilot can be offered.
static func validate() -> Array:
	var bad := []
	for part_id in Parts.rows():
		var maker := maker_of(part_id)
		if maker == "" or not SETS.has(maker):
			if _is_item(part_id):
				bad.append("%s: no known maker" % part_id)
	for relic_id in Relics.ids():
		if not SETS.has(relic_maker(relic_id)):
			bad.append("%s: relic has no known maker" % relic_id)
	for pilot in Relics.PILOTS:
		var reach := {}
		for part_id in Parts.rows():
			var r: Dictionary = Parts.rows()[part_id]
			var only := String(r.get("class_id", ""))
			if only != "" and only != pilot:
				continue
			var maker := maker_of(part_id)
			if maker != "":
				reach[maker] = int(reach.get(maker, 0)) + 1
		for maker in SETS:
			if int(reach.get(maker, 0)) < int(SETS[maker]["pieces"]):
				bad.append("%s: only %d %s pieces reachable" % [pilot, int(reach.get(maker, 0)), maker])
	return bad


# The 62 items (items.gd's table and the three catalogue pattern parts) and Moss's cells.
static func _is_item(part_id: String) -> bool:
	return Parts.Items.TABLE.has(part_id) or Parts.Items.CELLS.has(part_id) or part_id in Parts.PATTERN_PARTS
