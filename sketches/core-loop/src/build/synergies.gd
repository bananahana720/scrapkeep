extends RefCounted

# Named synergies and the unnamed tag rules (DEMO-SPEC "Synergies"). Every part
# carries one or two tags. A named synergy is its hint card read literally: its shown
# part plus any other held part carrying its second tag ("Chain Arc + something that
# splits"). So combinations make sense before you try them, and a mid-sized build lights
# up a few synergies rather than all of them. Unnamed tag rules are looser on purpose:
# any two parts with the pair's tags, because they are the accidents.
#
# Each synergy changes behaviour, never just a number. Its effects are transformer ids
# (build or combat act on them), pattern levels, element triggers and dials, folded in
# by build_sheet.gd. A synergy is derived from the part list, never held, so a retry
# that restores the list restores the synergies.
#
# This file works on part ids and tag sets (one tag list per held part), so it never
# needs the catalogue; parts.gd bridges part ids to tags. declarations() is the hint-card
# data for the codex registry (category "build").

const CATEGORY := "build"

# The clue a hint card shows for its hidden ingredient, by that ingredient's tag.
const CLUES := {
	"frost": "something cold",
	"arc": "something that sparks",
	"kinetic": "something that hits hard",
	"split": "something that splits",
	"spiral": "something that spirals",
	"chain": "something that chains",
	"anchor": "something that anchors",
	"speed": "something fast",
	"mass": "something heavy",
}

# tags[0] is the shown ingredient's tag and tags[1] the hidden one; "shown" is the
# part the undiscovered card names.
const ROWS := {
	"storm_lattice": {
		"name": "Storm Lattice", "tags": ["chain", "split"], "shown": "chain_arc",
		"text": "Split bolts chain: every fragment of a cross jumps to a neighbour.",
		"transformers": ["storm_lattice"], "patterns": {"chain_arc": 1},
	},
	"thermal_shock": {
		"name": "Thermal Shock", "tags": ["frost", "arc"], "shown": "frost_vane",
		"text": "Slams release a thermal shock: the arc shatters nearby ice into a shard nova at double damage, then fresh ice freezes around you.",
		"transformers": ["thermal_shock"], "elements": {"slam": ["arc", "frost"]}, "dials": {"shatter_damage": 2.0},
	},
	"lightning_rod": {
		"name": "Lightning Rod", "tags": ["arc", "mass"], "shown": "arc_coil",
		"text": "Every piece of scrap you pick up sparks an arc at the nearest enemy.",
		"transformers": ["lightning_rod"],
	},
	"tesla_pylon": {
		"name": "Tesla Pylon", "tags": ["anchor", "arc"], "shown": "focus_lens",
		"text": "While mounted or hooked, arcs leap from you to the two nearest enemies twice a second.",
		"transformers": ["tesla_pylon"],
	},
	"wrecking_ball": {
		"name": "Wrecking Ball", "tags": ["speed", "kinetic"], "shown": "double_feed",
		"text": "Rams send out a shockwave that hits everything around the target.",
		"transformers": ["wrecking_ball"],
	},
	"shrapnel_bloom": {
		"name": "Shrapnel Bloom", "tags": ["split", "kinetic"], "shown": "cross_split",
		"text": "Kills burst into shrapnel that hits up to three enemies nearby.",
		"transformers": ["shrapnel_bloom"],
	},
	"glacier_hull": {
		"name": "Glacier Hull", "tags": ["mass", "frost"], "shown": "slag_rounds",
		"text": "Hard landings crack out a frost ring: it hits enemies near you and freezes water.",
		"transformers": ["glacier_hull"],
	},
	"pinwheel": {
		"name": "Pinwheel", "tags": ["spiral", "speed"], "shown": "spiral_wave",
		"text": "At fast speed and above you spin a blade ring that cuts the enemies you pass.",
		"transformers": ["pinwheel"],
	},
}

# Unnamed tag rules: combinations the systems resolve without a card. The first time
# one fires, build logs it to the codex's Found list with this plain description.
const TAG_RULES := {
	"linked_spiral": {
		"tags": ["spiral", "chain"], "transformers": ["linked_spiral"], "fires_on": "shot",
		"found": "A spiral carrying chain links its arcs into a ring.",
	},
}


# Evolutions (v3 spike S2, LOOP-REDESIGN section 8), behind the tuning flag
# "evolutions". A row is ripe while its base part is held at `count` copies and a
# different held part carries `pair_tag`; at the Warden break build swaps the base
# copies for the evolved part (items.gd EVOLVED). Like a synergy it is derived from the
# part list, so a retry that restores the list takes the evolution back.
const EVOLUTIONS := {
	"pinball_hull": {"name": "Pinball Hull", "base": "spring_hull", "count": 3, "pair_tag": "speed",
		"text": "Spring Hull at three plus something fast becomes Pinball Hull: rebounds surge, refresh a jump and relaunch pins."},
}


static func _paired(held: Array, tag_sets: Array, base: String, pair_tag: String) -> bool:
	for i in held.size():
		if held[i] != base and pair_tag in tag_sets[i]:
			return true
	return false


# True when the base part is at its count and a different part carries the pair tag.
static func evolution_ripe(held: Array, tag_sets: Array, evolution_id: String) -> bool:
	var row: Dictionary = EVOLUTIONS[evolution_id]
	return held.count(row["base"]) >= row["count"] and _paired(held, tag_sets, row["base"], row["pair_tag"])


# The first ripe evolution for this part list, or "".
static func ripe_evolution(held: Array, tag_sets: Array) -> String:
	for key in EVOLUTIONS:
		if evolution_ripe(held, tag_sets, key):
			return key
	return ""


# The evolution this candidate moves toward, or "": it adds a base copy below the
# count, or it brings the missing pair tag while the base is already at its count.
static func ripened_by(held: Array, tag_sets: Array, candidate: String, candidate_tags: Array) -> String:
	for key in EVOLUTIONS:
		var row: Dictionary = EVOLUTIONS[key]
		var copies: int = held.count(row["base"])
		if candidate == row["base"] and copies < row["count"]:
			return key
		if candidate != row["base"] and copies >= row["count"] and row["pair_tag"] in candidate_tags \
				and not _paired(held, tag_sets, row["base"], row["pair_tag"]):
			return key
	return ""


# Codex hint cards for the evolutions, shaped like the synergy cards plus "evolution".
static func evolution_declarations(name_of: Callable) -> Array:
	var cards: Array = []
	for key in EVOLUTIONS:
		var row: Dictionary = EVOLUTIONS[key]
		var hidden: String = CLUES.get(row["pair_tag"], "something")
		cards.append({
			"id": key,
			"category": CATEGORY,
			"name": row["name"],
			"hint": "%s ×%d + %s" % [name_of.call(row["base"]), row["count"], hidden],
			"clue": hidden,
			"text": row["text"],
			"evolution": true,
		})
	return cards


# True while two different held parts carry the pair's two tags.
static func pair_live(tag_sets: Array, pair: Array) -> bool:
	for i in tag_sets.size():
		if not pair[0] in tag_sets[i]:
			continue
		for j in tag_sets.size():
			if j != i and pair[1] in tag_sets[j]:
				return true
	return false


# True while the shown part is held and a different held part carries the second tag.
static func named_live(held: Array, tag_sets: Array, synergy_id: String) -> bool:
	var row: Dictionary = ROWS[synergy_id]
	var shown_at: int = held.find(row["shown"])
	if shown_at < 0:
		return false
	for j in tag_sets.size():
		if j != shown_at and row["tags"][1] in tag_sets[j]:
			return true
	return false


static func active(held: Array, tag_sets: Array) -> Array:
	var live: Array = []
	for key in ROWS:
		if named_live(held, tag_sets, key):
			live.append(key)
	return live


static func active_rules(tag_sets: Array) -> Array:
	var live: Array = []
	for key in TAG_RULES:
		if pair_live(tag_sets, TAG_RULES[key]["tags"]):
			live.append(key)
	return live


# The named synergy that adding this part would bring live, or "".
static func completed_by(held: Array, tag_sets: Array, candidate: String, candidate_tags: Array) -> String:
	var before := active(held, tag_sets)
	var held_after: Array = held.duplicate()
	held_after.append(candidate)
	var sets_after: Array = tag_sets.duplicate()
	sets_after.append(candidate_tags)
	for key in active(held_after, sets_after):
		if not key in before:
			return key
	return ""


static func clue(synergy_id: String) -> String:
	return CLUES.get(ROWS[synergy_id]["tags"][1], "something")


# Codex hint cards, one per named synergy: {id, category, name, hint, clue, text,
# shown, tags}. name_of turns a part id into its display name.
static func declarations(name_of: Callable) -> Array:
	var cards: Array = []
	for key in ROWS:
		var row: Dictionary = ROWS[key]
		cards.append({
			"id": key,
			"category": CATEGORY,
			"name": row["name"],
			"hint": "%s + %s" % [name_of.call(row["shown"]), clue(key)],
			"clue": clue(key),
			"text": row["text"],
			"shown": row["shown"],
			"tags": row["tags"],
		})
	return cards
