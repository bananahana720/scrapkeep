extends RefCounted

# Relics, the relic rung of the part ladder (systems audit pass D, fold 1; Andrew 11 Nov 2026).
# A relic is a part: the run holds it in its part list as part_id(relic_id) ("relic:<id>"), the
# ladder shows it at rarity relic, and it counts toward its maker's set like any part. What
# sets it apart is its effect: it rewrites exactly one kit slot for the one pilot it fits, and a
# run holds one relic per slot. Rows are pure data: `swap` puts another ability row in the slot,
# `cooldown` multiplies the slot's cooldown scale, `charges` adds to its bank cap. AbilityState
# owns what an ability row does; build.gd (sync_relics) applies the row named here.
#
# Before the fold a relic sat in RunState.relics (slot to relic id), outside the part list. A
# save written then still loads: build.gd adopts that map into the part list on stage entry.

const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")

const PREFIX := "relic:"
const MAX_NAME_WORDS := 3
const MAX_TEXT_WORDS := 8
const MIN_PER_PILOT := 2
const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
# Rivet's kit rows; Tarn, Tally and the remembered cannon have their own rows in each world.
const RIVET := ["runner_gunner"]
const SUFFIX := {AbilityState.WEAPON: "_weapon", AbilityState.MOVEMENT: "_move",
	AbilityState.SPECIAL: "_special", AbilityState.SMASH: "_smash", AbilityState.LINE: "_line"}

# The category icon a relic shows, by the slot it rewrites.
const ICON_FOR_SLOT := {AbilityState.WEAPON: "damage", AbilityState.MOVEMENT: "mobility",
	AbilityState.SPECIAL: "charge", AbilityState.SMASH: "defense", AbilityState.LINE: "utility"}

const ROWS := {
	"crater_heart": {"maker": "waking", "name": "Crater Heart", "text": "Smash spends the special for a crater",
		"pilots": ["pylon_engineer"], "slot": AbilityState.SMASH, "swap": "crater_slam", "world": 1},
	"quick_fuse": {"maker": "spillway_works", "name": "Quick Fuse", "text": "Discharge refills 30% sooner",
		"pilots": ["pylon_engineer"], "slot": AbilityState.SPECIAL, "cooldown": 0.7, "world": 1},
	"muzzle_heart": {"maker": "fleet_surplus", "name": "Muzzle Heart", "text": "Special becomes a point-blank blast",
		"pilots": RIVET, "slot": AbilityState.SPECIAL, "swap": "point_blank", "world": 1},
	"redline_spring": {"maker": "highdraft_roosts", "name": "Redline Spring", "text": "Overdrive sprint refills 30% sooner",
		"pilots": RIVET, "slot": AbilityState.MOVEMENT, "cooldown": 0.7, "world": 1},
	"rain_heart": {"maker": "spillway_works", "name": "Rain Heart", "text": "Sticky charges scatter three at once",
		"pilots": ["demolitions_caster"], "slot": AbilityState.WEAPON, "swap": "sticky_rain", "world": 1},
	"long_fuse": {"maker": "mind_glass", "name": "Long Fuse", "text": "Detonation line refills 25% sooner",
		"pilots": ["demolitions_caster"], "slot": AbilityState.SPECIAL, "cooldown": 0.75, "world": 1},
	"taut_cable": {"maker": "redjaw", "name": "Taut Cable", "text": "Claw pull refills 30% sooner",
		"pilots": ["tarn"], "slot": AbilityState.MOVEMENT, "cooldown": 0.7, "world": 1},
	"vice_heart": {"maker": "redjaw", "name": "Vice Heart", "text": "Clamp refills 25% sooner",
		"pilots": ["tarn"], "slot": AbilityState.SPECIAL, "cooldown": 0.75, "world": 1},
	"gutter_heart": {"maker": "waking", "name": "Gutter Heart", "text": "Rend slams drag machines into the crater",
		"pilots": ["tarn"], "slot": AbilityState.SMASH, "swap": "rend_drag", "world": 1},
	"rake_heart": {"maker": "redjaw", "name": "Rake Heart", "text": "Each sweep rakes again on return",
		"pilots": ["tarn"], "slot": AbilityState.WEAPON, "swap": "claw_rake", "world": 1},
	"oiled_flywheel": {"maker": "spillway_works", "name": "Oiled Flywheel", "text": "Flywheel surge refills 30% sooner",
		"pilots": ["tally"], "slot": AbilityState.MOVEMENT, "cooldown": 0.7, "world": 1},
	"return_spring": {"maker": "mind_glass", "name": "Return Spring", "text": "Gather plate refills 25% sooner",
		"pilots": ["tally"], "slot": AbilityState.SPECIAL, "cooldown": 0.75, "world": 1},
	"ink_heart": {"maker": "mind_glass", "name": "Ink Heart", "text": "Stamped machines refill pressure on balance due",
		"pilots": ["tally"], "slot": AbilityState.SMASH, "swap": "stamp_ink", "world": 1},
	"double_entry": {"maker": "fleet_surplus", "name": "Double Entry", "text": "Settled clips jump to one fresh machine",
		"pilots": ["tally"], "slot": AbilityState.LINE, "swap": "link_double", "world": 1},
	"kick_spring": {"maker": "fleet_surplus", "name": "Kick Spring", "text": "Recoil kick refills 30% sooner",
		"pilots": ["remembered_cannon"], "slot": AbilityState.MOVEMENT, "cooldown": 0.7, "world": 1},
	"brace_pin": {"maker": "fleet_surplus", "name": "Brace Pin", "text": "Plate refills 25% sooner",
		"pilots": ["remembered_cannon"], "slot": AbilityState.SPECIAL, "cooldown": 0.75, "world": 1},
	"walking_lane": {"maker": "mind_glass", "name": "Walking Lane", "text": "Second call walks the lane further out",
		"pilots": ["remembered_cannon"], "slot": AbilityState.WEAPON, "swap": "cannon_lane_walk", "world": 1},
	"rush_wake": {"maker": "waking", "name": "Rush Wake", "text": "Rush landings leave a lane behind",
		"pilots": ["remembered_cannon"], "slot": AbilityState.SMASH, "swap": "cannon_rush_wake", "world": 1},
	# World 2, the Dig.
	"spare_cell": {"maker": "moss", "name": "Spare Cell", "text": "Bank a second discharge",
		"pilots": ["pylon_engineer"], "slot": AbilityState.SPECIAL, "charges": 1, "world": 2},
	"pit_coil": {"maker": "waking", "name": "Pit Coil", "text": "Bank Shot refills 30% sooner",
		"pilots": ["pylon_engineer"], "class_id": "pylon_engineer", "stack_rule": "capped", "slot": AbilityState.LINE, "cooldown": 0.7, "world": 2},
	"spare_spring": {"maker": "moss", "name": "Spare Spring", "text": "Bank a second overdrive sprint",
		"pilots": RIVET, "slot": AbilityState.MOVEMENT, "charges": 1, "world": 2},
	"hot_barrel": {"maker": "redjaw", "name": "Hot Barrel", "text": "Special blast refills 25% sooner",
		"pilots": RIVET, "slot": AbilityState.SPECIAL, "cooldown": 0.75, "world": 2},
	"thin_smoke": {"maker": "waking", "name": "Thin Smoke", "text": "Smoke blink refills 30% sooner",
		"pilots": ["demolitions_caster"], "slot": AbilityState.MOVEMENT, "cooldown": 0.7, "world": 2},
	"deep_satchel": {"maker": "moss", "name": "Deep Satchel", "text": "Bank one more sticky charge",
		"pilots": ["demolitions_caster"], "slot": AbilityState.WEAPON, "charges": 1, "world": 2},
	"spare_cable": {"maker": "moss", "name": "Spare Cable", "text": "Bank a second claw pull",
		"pilots": ["tarn"], "slot": AbilityState.MOVEMENT, "charges": 1, "world": 2},
	"jaw_spring": {"maker": "redjaw", "name": "Jaw Spring", "text": "Clamp refills 30% sooner",
		"pilots": ["tarn"], "slot": AbilityState.SPECIAL, "cooldown": 0.7, "world": 2},
	"spare_flywheel": {"maker": "moss", "name": "Spare Flywheel", "text": "Bank a second flywheel surge",
		"pilots": ["tally"], "slot": AbilityState.MOVEMENT, "charges": 1, "world": 2},
	"plate_hinge": {"maker": "waking", "name": "Plate Hinge", "text": "Gather plate refills 30% sooner",
		"pilots": ["tally"], "slot": AbilityState.SPECIAL, "cooldown": 0.7, "world": 2},
	"second_kick": {"maker": "fleet_surplus", "name": "Second Kick", "text": "Bank a second recoil kick",
		"pilots": ["remembered_cannon"], "slot": AbilityState.MOVEMENT, "charges": 1, "world": 2},
	"brace_spring": {"maker": "waking", "name": "Brace Spring", "text": "Plate refills 30% sooner",
		"pilots": ["remembered_cannon"], "slot": AbilityState.SPECIAL, "cooldown": 0.7, "world": 2},
	# World 3, Highdraft.
	"crown_cell": {"maker": "mind_glass", "name": "Crown Cell", "text": "Bank two more discharges",
		"pilots": ["pylon_engineer"], "slot": AbilityState.SPECIAL, "charges": 2, "world": 3},
	"storm_crater": {"maker": "highdraft_roosts", "name": "Storm Crater", "text": "Bank a second Bank Shot",
		"pilots": ["pylon_engineer"], "class_id": "pylon_engineer", "stack_rule": "capped", "slot": AbilityState.LINE, "charges": 1, "world": 3},
	"tailwind_spring": {"maker": "highdraft_roosts", "name": "Tailwind Spring", "text": "Overdrive sprint refills 40% sooner",
		"pilots": RIVET, "slot": AbilityState.MOVEMENT, "cooldown": 0.6, "world": 3},
	"twin_barrel": {"maker": "fleet_surplus", "name": "Twin Barrel", "text": "Bank a second special blast",
		"pilots": RIVET, "slot": AbilityState.SPECIAL, "charges": 1, "world": 3},
	"twin_blink": {"maker": "highdraft_roosts", "name": "Twin Blink", "text": "Bank a second smoke blink",
		"pilots": ["demolitions_caster"], "slot": AbilityState.MOVEMENT, "charges": 1, "world": 3},
	"spare_line": {"maker": "mind_glass", "name": "Spare Line", "text": "Bank a second detonation line",
		"pilots": ["demolitions_caster"], "slot": AbilityState.SPECIAL, "charges": 1, "world": 3},
	"redjaw_cable": {"maker": "redjaw", "name": "Redjaw Cable", "text": "Claw pull refills 40% sooner",
		"pilots": ["tarn"], "slot": AbilityState.MOVEMENT, "cooldown": 0.6, "world": 3},
	"twin_jaw": {"maker": "redjaw", "name": "Twin Jaw", "text": "Bank a second clamp",
		"pilots": ["tarn"], "slot": AbilityState.SPECIAL, "charges": 1, "world": 3},
	"brass_governor": {"maker": "fleet_surplus", "name": "Brass Governor", "text": "Flywheel surge refills 40% sooner",
		"pilots": ["tally"], "slot": AbilityState.MOVEMENT, "cooldown": 0.6, "world": 3},
	"second_plate": {"maker": "highdraft_roosts", "name": "Second Plate", "text": "Bank a second gather plate",
		"pilots": ["tally"], "slot": AbilityState.SPECIAL, "charges": 1, "world": 3},
	"hot_breech": {"maker": "spillway_works", "name": "Hot Breech", "text": "Recoil kick refills 40% sooner",
		"pilots": ["remembered_cannon"], "slot": AbilityState.MOVEMENT, "cooldown": 0.6, "world": 3},
	"twin_plate": {"maker": "highdraft_roosts", "name": "Twin Plate", "text": "Bank a second plate",
		"pilots": ["remembered_cannon"], "slot": AbilityState.SPECIAL, "charges": 1, "world": 3},
}


static func ids() -> Array:
	return ROWS.keys()


static func has(relic_id: String) -> bool:
	return ROWS.has(relic_id)


static func row(relic_id: String) -> Dictionary:
	return ROWS.get(relic_id, {})


static func slot_of(relic_id: String) -> String:
	return String(row(relic_id).get("slot", ""))


# The relic's id in a part list; "" for an unknown relic.
static func part_of(relic_id: String) -> String:
	return PREFIX + relic_id if ROWS.has(relic_id) else ""


# The relic a part id stands for, or "" for any other part.
static func relic_of(part_id: String) -> String:
	if not part_id.begins_with(PREFIX):
		return ""
	var id := part_id.trim_prefix(PREFIX)
	return id if ROWS.has(id) else ""


static func is_relic(part_id: String) -> bool:
	return relic_of(part_id) != ""


# Slot to relic id for the relics in a part list. The first relic in a slot holds it.
static func held(parts: Array) -> Dictionary:
	var out := {}
	for part_id in parts:
		var id := relic_of(String(part_id))
		if id != "" and not out.has(slot_of(id)):
			out[slot_of(id)] = id
	return out


# The relic's part row, read by Parts.def: the relic rung, its one pilot, its maker. It carries
# no stat effect: the slot rewrite is build.gd's (sync_relics), so nothing folds twice.
static func part_row(part_id: String) -> Dictionary:
	var id := relic_of(part_id)
	if id == "":
		return {}
	var r: Dictionary = ROWS[id]
	return {"name": r["name"], "verb": r["text"], "text": r["text"], "rarity": "relic", "tier": 3,
		"family": "relic", "class_id": r["pilots"][0], "maker": r["maker"], "tags": [],
		"icon": ICON_FOR_SLOT.get(r["slot"], "utility"), "cap": 1, "stack": "capped"}


static func name_of(relic_id: String) -> String:
	return String(row(relic_id).get("name", relic_id))


static func fits(relic_id: String, pilot: String) -> bool:
	return pilot in row(relic_id).get("pilots", [])


# Relic ids a pilot may still find: the pilot's rows whose slot holds nothing yet, in
# table order. `held` is slot to relic id (held(parts)). A relic whose swap the upgrade tree already gave
# (`tree`, optional) is not offered: it would change nothing. `world` keeps the rows of that
# world only; 0 keeps every world's.
static func eligible(pilot: String, held: Dictionary, tree = null, world := 0) -> Array:
	var out := []
	for id in ROWS:
		if not fits(id, pilot) or held.has(ROWS[id]["slot"]):
			continue
		if world != 0 and int(ROWS[id]["world"]) != world:
			continue
		if tree != null and swap_of(id) != "" and tree.gives_swap(ROWS[id]["slot"], swap_of(id)):
			continue
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
		AbilityState.SPECIAL: def.special_id, AbilityState.SMASH: def.smash_id, AbilityState.LINE: def.line_id}.get(slot, "")


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
		if r.get("pilots", []).size() != 1:
			bad.append("%s: a relic fits exactly one pilot" % id)
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
