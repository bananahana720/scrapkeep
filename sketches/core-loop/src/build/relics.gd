extends RefCounted

# The relic layer (DESIGN-V3 build layers: Path, Relics, Parts). A relic is found on the
# map, rewrites exactly one kit slot for the pilot who holds it, and a run holds one
# relic per slot. Rows are pure data: `swap` puts another ability row in the slot,
# `cooldown` multiplies the slot's cooldown scale, `charges` adds to its stockpile cap.
# AbilityState owns what an ability row does; a relic only names the row or the number.
#
# `part` is a relic-rarity generated item id (ItemGen). It is what part_gained carries,
# so the reward ceremony resolves rarity relic (the heart and the reveal) through its one
# existing rarity read; it is never added to run.parts.

const AbilityState := preload("res://src/core/ability_state.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Parts := preload("res://src/build/parts.gd")
const ClassDef := preload("res://src/core/class_def.gd")

const MAX_NAME_WORDS := 3
const MAX_TEXT_WORDS := 8
const MIN_PER_PILOT := 2
const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn"]
# Tarn borrows Rivet's kit (class_def.gd), so Rivet's relics list both.
const RIVET := ["runner_gunner", "tarn"]
const SUFFIX := {AbilityState.WEAPON: "_weapon", AbilityState.MOVEMENT: "_move",
	AbilityState.SPECIAL: "_special", AbilityState.SMASH: "_smash"}

const ROWS := {
	"crater_heart": {"name": "Crater Heart", "text": "Smash spends the special for a crater",
		"pilots": ["pylon_engineer"], "slot": AbilityState.SMASH, "swap": "crater_slam",
		"part": "gen:defense:relic:none:on_smash"},
	"quick_fuse": {"name": "Quick Fuse", "text": "Detonation recharges 30% faster",
		"pilots": ["pylon_engineer"], "slot": AbilityState.SPECIAL, "cooldown": 0.7,
		"part": "gen:charge:relic:arc:on_charge_release"},
	"muzzle_heart": {"name": "Muzzle Heart", "text": "Special becomes a point-blank blast",
		"pilots": RIVET, "slot": AbilityState.SPECIAL, "swap": "point_blank",
		"part": "gen:weapon:relic:kinetic:on_kill"},
	"redline_spring": {"name": "Redline Spring", "text": "Overdrive sprint recharges 30% faster",
		"pilots": RIVET, "slot": AbilityState.MOVEMENT, "cooldown": 0.7,
		"part": "gen:mobility:relic:none:on_land"},
	"rain_heart": {"name": "Rain Heart", "text": "Sticky charges scatter three at once",
		"pilots": ["demolitions_caster"], "slot": AbilityState.WEAPON, "swap": "sticky_rain",
		"part": "gen:utility:relic:frost:on_hit"},
	"long_fuse": {"name": "Long Fuse", "text": "Detonation line recharges 25% faster",
		"pilots": ["demolitions_caster"], "slot": AbilityState.SPECIAL, "cooldown": 0.75,
		"part": "gen:charge:relic:none:on_cloak_break"},
}


static func ids() -> Array:
	return ROWS.keys()


static func has(relic_id: String) -> bool:
	return ROWS.has(relic_id)


static func row(relic_id: String) -> Dictionary:
	return ROWS.get(relic_id, {})


static func slot_of(relic_id: String) -> String:
	return String(row(relic_id).get("slot", ""))


static func part_of(relic_id: String) -> String:
	return String(row(relic_id).get("part", ""))


static func name_of(relic_id: String) -> String:
	return String(row(relic_id).get("name", relic_id))


static func fits(relic_id: String, pilot: String) -> bool:
	return pilot in row(relic_id).get("pilots", [])


# Relic ids a pilot may still find: the pilot's rows whose slot holds nothing yet, in
# table order. `held` is slot to relic id.
static func eligible(pilot: String, held: Dictionary) -> Array:
	var out := []
	for id in ROWS:
		if fits(id, pilot) and not held.has(ROWS[id]["slot"]):
			out.append(id)
	return out


# The one-per-slot rule: a relic is refused while its slot is held.
static func can_hold(relic_id: String, pilot: String, held: Dictionary) -> bool:
	return fits(relic_id, pilot) and not held.has(slot_of(relic_id))


# The ability row a slot would hold under the relic, or "" when it keeps the slot's own.
static func swap_of(relic_id: String) -> String:
	return String(row(relic_id).get("swap", ""))


static func _kit_slot(pilot: String, slot: String) -> String:
	var def: Resource = ClassDef.by_id(pilot)
	if def == null:
		return ""
	return {AbilityState.WEAPON: def.weapon_id, AbilityState.MOVEMENT: def.movement_id,
		AbilityState.SPECIAL: def.special_id, AbilityState.SMASH: def.smash_id}.get(slot, "")


# Problems with the table, one string each; empty when it is sound.
static func validate(rows: Dictionary = ROWS) -> Array:
	var bad := []
	var per_pilot := {}
	for id in rows:
		var r: Dictionary = rows[id]
		var name_words := String(r.get("name", "")).split(" ", false).size()
		if name_words < 1 or name_words > MAX_NAME_WORDS:
			bad.append("%s: name has %d words" % [id, name_words])
		var text_words := String(r.get("text", "")).split(" ", false).size()
		if text_words < 1 or text_words > MAX_TEXT_WORDS:
			bad.append("%s: text has %d words" % [id, text_words])
		var slot := String(r.get("slot", ""))
		if not slot in AbilityState.SLOTS:
			bad.append("%s: slot %s is not a kit slot" % [id, slot])
		var swap := String(r.get("swap", ""))
		var cooldown := float(r.get("cooldown", 1.0))
		var charges := int(r.get("charges", 0))
		if swap == "" and is_equal_approx(cooldown, 1.0) and charges == 0:
			bad.append("%s: rewrites nothing" % id)
		if swap != "" and (not AbilityState.ABILITIES.has(swap) or not String(AbilityState.ABILITIES[swap]["icon"]).ends_with(SUFFIX.get(slot, "?"))):
			bad.append("%s: swap %s is not a %s ability" % [id, swap, slot])
		if cooldown <= 0.0 or cooldown > 1.0 or charges < 0:
			bad.append("%s: knob out of range" % id)
		var def: Resource = Parts.def(String(r.get("part", "")))
		if def == null or def.rarity != "relic":
			bad.append("%s: part is not a relic-rarity item" % id)
		var pilots: Array = r.get("pilots", [])
		if pilots.is_empty():
			bad.append("%s: no pilot" % id)
		for pilot in pilots:
			if not pilot in PILOTS or _kit_slot(pilot, slot) == "":
				bad.append("%s: pilot %s has no %s slot" % [id, pilot, slot])
			per_pilot[pilot] = int(per_pilot.get(pilot, 0)) + 1
	for pilot in PILOTS:
		if int(per_pilot.get(pilot, 0)) < MIN_PER_PILOT:
			bad.append("%s: fewer than %d relics" % [pilot, MIN_PER_PILOT])
	return bad
