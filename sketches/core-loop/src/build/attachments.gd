extends RefCounted

# The weapon-local attachment layer (SQ11, W13-INTEGRATION-3.md; comps/roboquest/
# weapons-and-affixes.md:79 and :95). A pilot's one weapon carries a loadout: its tier and
# the attachments fitted to it. The tier sets how many attachments fit (0 to 3) and the top
# tier adds a second fire mode, named before anything is equipped. Attachments sit beside the
# player-global parts (build_sheet.gd): parts tune every weapon through tuning mods, while an
# attachment only scales its own weapon's Pattern fields, and weapons.gd reads them.
#
# BIBLE.md:552: the effect is rebuilt from current selections. A loadout is plain data and
# mods() folds it from scratch each read, so removing an attachment stops its contribution
# and swaps never accumulate. Every attachment multiplies; none adds, which keeps a global
# perk's DPS share the same on every weapon (attachment_layer_test).
#
# BIBLE.md:432 and :552: compatibility is explicit, so each row names the weapons it fits.
# Tiers are words (Tier I to IV), never a colour ladder, and the layer carries no price.
# Every number here is a start value for play.

const MIN_COUNT := 0
const MAX_COUNT := 3
const TOP_TIER := 4
# Tier to the attachment count range it rolls, inclusive.
const TIER_COUNT := {1: [0, 0], 2: [1, 1], 3: [1, 2], 4: [2, 3]}
const TIER_WORDS := {1: "Tier I", 2: "Tier II", 3: "Tier III", 4: "Tier IV"}

const PILOT_WEAPONS := ["arc_caster", "rapid_laser", "sticky_charge", "claw_sweep", "ledger_reader", "cannon_lane"]

# id -> name, shown text, the Pattern fields it multiplies, the weapons it fits.
const ROWS := {
	"bored_chamber": {"name": "Bored Chamber", "text": "+15% weapon damage",
		"mods": {"damage": 1.15}, "fits": PILOT_WEAPONS},
	"light_carrier": {"name": "Light Carrier", "text": "+12% fire rate",
		"mods": {"rate": 1.12}, "fits": PILOT_WEAPONS},
	"rail_extension": {"name": "Rail Extension", "text": "+20% reach, +10% bolt speed",
		"mods": {"range_m": 1.2, "speed": 1.1}, "fits": PILOT_WEAPONS},
	"wide_choke": {"name": "Wide Choke", "text": "+25% hit radius",
		"mods": {"bolt_radius": 1.25}, "fits": PILOT_WEAPONS},
	"tight_choke": {"name": "Tight Choke", "text": "-15% hit radius, +10% weapon damage",
		"mods": {"bolt_radius": 0.85, "damage": 1.1}, "fits": PILOT_WEAPONS},
	"slug_weight": {"name": "Slug Weight", "text": "+25% weapon damage, -10% fire rate",
		"mods": {"damage": 1.25, "rate": 0.9}, "fits": PILOT_WEAPONS},
	"cooling_jacket": {"name": "Cooling Jacket", "text": "+8% fire rate, +5% weapon damage",
		"mods": {"rate": 1.08, "damage": 1.05}, "fits": PILOT_WEAPONS},
	"arc_spool": {"name": "Arc Spool", "text": "Arcs reach 30% farther",
		"mods": {"chain_range": 1.3}, "fits": ["arc_caster"]},
	"fuse_trimmer": {"name": "Fuse Trimmer", "text": "+10% charge damage, +15% throw speed",
		"mods": {"damage": 1.1, "speed": 1.15}, "fits": ["sticky_charge"]},
}

# The top tier's second fire mode per pilot weapon: what it does, in words, and the Pattern
# fields it scales over the attached primary.
const SECOND_MODES := {
	"arc_caster": {"name": "Lance Arc", "text": "one slow bolt with a field twice as wide, hitting twice as hard",
		"mods": {"rate": 0.4, "bolt_radius": 2.0, "damage": 2.0}},
	"rapid_laser": {"name": "Burst Pulse", "text": "half the rate, each pulse 80% harder and faster",
		"mods": {"rate": 0.5, "damage": 1.8, "speed": 1.3}},
	"sticky_charge": {"name": "Cluster Throw", "text": "smaller blasts thrown faster",
		"mods": {"bolt_radius": 0.6, "damage": 0.6, "rate": 1.8}},
	"claw_sweep": {"name": "Long Rake", "text": "twice the reach on a narrower sweep",
		"mods": {"range_m": 2.0, "bolt_radius": 0.7, "rate": 0.8}},
	"ledger_reader": {"name": "Audit Volley", "text": "faster reads at 70% damage",
		"mods": {"rate": 1.5, "damage": 0.7}},
	"cannon_lane": {"name": "Short Lane", "text": "a lane 40% shorter that hits 40% harder",
		"mods": {"range_m": 0.6, "damage": 1.4}},
}


# A loadout with no attachments yet.
static func empty(weapon_id: String, tier: int) -> Dictionary:
	return {"weapon": weapon_id, "tier": clampi(tier, 1, TOP_TIER), "attachments": []}


# The attachment ids that fit a weapon, in a stable order.
static func fitting(weapon_id: String) -> Array:
	var out: Array = []
	for id in ROWS:
		if weapon_id in ROWS[id]["fits"]:
			out.append(id)
	out.sort()
	return out


static func capacity(loadout: Dictionary) -> int:
	return int(TIER_COUNT[int(loadout.get("tier", 1))][1])


# A new loadout with the attachment fitted; unchanged when it does not fit, is already on,
# or the tier's count is full.
static func equip(loadout: Dictionary, attachment_id: String) -> Dictionary:
	var out := loadout.duplicate(true)
	var held: Array = out["attachments"]
	if not attachment_id in fitting(String(out["weapon"])) or attachment_id in held or held.size() >= capacity(out):
		return out
	held.append(attachment_id)
	return out


# A new loadout without the attachment.
static func unequip(loadout: Dictionary, attachment_id: String) -> Dictionary:
	var out := loadout.duplicate(true)
	(out["attachments"] as Array).erase(attachment_id)
	return out


# A random weapon of this tier: a count inside the tier's range, distinct fitting attachments.
static func roll(weapon_id: String, tier: int, rng: RandomNumberGenerator) -> Dictionary:
	var out := empty(weapon_id, tier)
	var limits: Array = TIER_COUNT[int(out["tier"])]
	var want := rng.randi_range(int(limits[0]), int(limits[1]))
	var pool := fitting(weapon_id)
	for i in want:
		if pool.is_empty():
			break
		var pick: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		out = equip(out, pick)
	return out


# The Pattern field multipliers a loadout gives its own weapon, folded from scratch.
static func mods(loadout: Dictionary) -> Dictionary:
	var out := {}
	for id in loadout.get("attachments", []):
		var row: Dictionary = ROWS.get(id, {})
		for field in row.get("mods", {}):
			out[field] = float(out.get(field, 1.0)) * float(row["mods"][field])
	return out


# The second mode row a loadout carries; {} below the top tier.
static func second_mode(loadout: Dictionary) -> Dictionary:
	if int(loadout.get("tier", 1)) < TOP_TIER:
		return {}
	return SECOND_MODES.get(String(loadout.get("weapon", "")), {})
