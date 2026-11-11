extends RefCounted

# Maker tricks and evolutions: the build's combination rules (systems audit pass D, fold 2;
# Andrew 11 Nov 2026). There is one set rule a player learns: parts of one maker (maker_sets.gd).
# Two distinct pieces of one maker wake its trick, a rule change below; three turn on its set
# bonus (maker_bonuses.gd). The tricks are the rule changes the named synergies (hidden tag
# pairs) and the three-part sets (a second member list) used to make, moved onto the makers so
# none of them is a hidden list any more. Each row names its maker; a maker has one or two.
#
# Each trick changes behaviour, never just a number. Its effects are transformer ids (build or
# combat act on them), pattern levels, element triggers and dials, folded in by build_sheet.gd.
# A trick is derived from the part list, never held, so a retry that restores the list restores
# the tricks. `tags` are the trick's glyphs (EventKinds.cause_glyphs, accretion); `callout` is
# what the why callout draws when it fires: two of the maker's parts as icons, then three words.
# A trick with transformers is discovered on its first firing (build.gd _fire). One that only
# adds an element to an action (a former three-part set) is told when it wakes: a banner in its
# `color` and a chime in its element (presentation.gd, build.gd set_completed).
#
# This file works on maker counts (maker -> distinct pieces held, Parts.maker_counts), so it
# never needs the catalogue. declarations() is the codex card data (category "build").
#
# Evolutions stay part pairs: both ingredients held and the run gains the Evolved part once
# (build.gd). An Evolved part gives nothing while an ingredient is missing.

const Palette := preload("res://src/core/palette.gd")

const CATEGORY := "build"
# Distinct pieces of one maker that wake its trick. The maker's set bonus needs its own count
# (MakerSets.SETS[maker]["pieces"], three for every maker but Moss).
const AT := 2

# The stage table the build runs on, set by the build at setup. A table's
# synergy_in_play(id) names the tricks it keeps; null keeps them all.
static var table = null

const ROWS := {
	# Spillway Works: the dam's ice road.
	"ballast_rig": {
		"name": "Ballast Rig", "maker": "spillway_works", "tags": ["frost"], "color": Palette.RUST,
		"text": "Your dash trails frost that freezes water into road.",
		"elements": {"dash": "frost"},
	},
	"shatter_crew": {
		"name": "Shatter Crew", "maker": "spillway_works", "tags": ["frost", "kinetic"], "color": Palette.COPPER,
		"text": "Shots freeze water where they land, and ice you shatter hits harder.",
		"elements": {"shot": "frost"}, "dials": {"shatter_damage": 1.5},
	},
	# Fleet Surplus: heavy hull, hard rams.
	"wrecking_ball": {
		"name": "Wrecking Ball", "maker": "fleet_surplus", "tags": ["speed", "kinetic"],
		"text": "Rams send out a shockwave that hits everything around the target.",
		"transformers": ["wrecking_ball"],
		"callout": {"a": "double_feed", "b": "hot_rivets", "words": "Rams carry through"},
	},
	"glacier_hull": {
		"name": "Glacier Hull", "maker": "fleet_surplus", "tags": ["mass", "frost"],
		"text": "Hard landings crack out a frost ring that hits machines near you and freezes water.",
		"transformers": ["glacier_hull"],
		"callout": {"a": "slag_rounds", "b": "rivet_plating", "words": "Landings ring cold"},
	},
	# Redjaw Workshops: teeth and splinters.
	"shrapnel_bloom": {
		"name": "Shrapnel Bloom", "maker": "redjaw", "tags": ["split", "kinetic"],
		"text": "Kills burst into shrapnel that hits up to three machines nearby.",
		"transformers": ["shrapnel_bloom"],
		"callout": {"a": "cross_split", "b": "pin_setter", "words": "Kills come apart"},
	},
	"storm_lattice": {
		"name": "Storm Lattice", "maker": "redjaw", "tags": ["chain", "split"],
		"text": "Every fragment of a cross split jumps to a neighbour.",
		"transformers": ["storm_lattice"], "patterns": {"chain_arc": 1},
		"callout": {"a": "cross_split", "b": "hairline_fracture", "words": "Bolts find neighbours"},
	},
	# Mind-glass: the Mind's live current.
	"tesla_pylon": {
		"name": "Tesla Pylon", "maker": "mind_glass", "tags": ["anchor", "arc"],
		"text": "While mounted or hooked, arcs leap from you to the two nearest machines twice a second.",
		"transformers": ["tesla_pylon"],
		"callout": {"a": "focus_lens", "b": "live_line", "words": "Hooked means live"},
	},
	"live_wire": {
		"name": "Live Wire", "maker": "mind_glass", "tags": ["arc"], "color": Palette.ARC,
		"text": "Every slam bursts an arc, and shots spark where they land.",
		"elements": {"slam": "arc", "shot": "arc"},
	},
	# Highdraft Roosts: speed and air.
	"pinwheel": {
		"name": "Pinwheel", "maker": "highdraft_roosts", "tags": ["spiral", "speed"],
		"text": "At fast speed and above you spin a blade ring that cuts the machines you pass.",
		"transformers": ["pinwheel"],
		"callout": {"a": "loose_trigger", "b": "long_barrel", "words": "Speed grows blades"},
	},
	"hair_trigger": {
		"name": "Hair Trigger", "maker": "highdraft_roosts", "tags": ["arc", "speed"], "color": Palette.AMBER,
		"text": "Your dash trails arc that electrifies water.",
		"elements": {"dash": "arc"},
	},
	# Waking-made: the ground answers.
	"storm_front": {
		"name": "Storm Front", "maker": "waking", "tags": ["frost", "mass"], "color": Palette.SLATE,
		"text": "Every slam cracks out a frost ring that freezes water and lays ice.",
		"elements": {"slam": "frost"},
	},
	"thermal_shock": {
		"name": "Thermal Shock", "maker": "waking", "tags": ["frost", "arc"],
		"text": "A slam's arc shatters nearby ice into a shard nova at double damage, then fresh ice freezes around you.",
		"transformers": ["thermal_shock"], "elements": {"slam": ["arc", "frost"]}, "dials": {"shatter_damage": 2.0},
		"callout": {"a": "spiral_wave", "b": "echo_locator", "words": "Ice cracks loud"},
	},
	"linked_spiral": {
		"name": "Linked Spiral", "maker": "waking", "tags": ["spiral", "chain"],
		"text": "A spiral carrying chain links its arcs into a ring.",
		"transformers": ["linked_spiral"], "found": "A spiral carrying chain links its arcs into a ring.",
		"callout": {"a": "spiral_wave", "b": "brace_frame", "words": "Spirals link up"},
	},
	# Moss's Spares: scrap that bites back.
	"lightning_rod": {
		"name": "Lightning Rod", "maker": "moss", "tags": ["arc", "mass"],
		"text": "Every piece of scrap you pick up sparks an arc at the nearest machine.",
		"transformers": ["lightning_rod"],
		"callout": {"a": "arc_coil", "b": "drop_weight", "words": "Scrap sparks back"},
	},
}

# Evolved part -> its two ingredient parts (Parts.EVOLVED holds the Evolved rows).
const EVOLUTIONS := {
	"breaker_drive": ["double_feed", "hot_rivets"],
	"bladestorm_rotor": ["spiral_wave", "loose_trigger"],
	"storm_mast": ["focus_lens", "live_line"],
	"grounding_spike": ["arc_coil", "drop_weight"],
}
# The trick each evolution grew out of, the name its text ends on ("From Wrecking Ball.").
const EVOLVED_FROM := {
	"breaker_drive": "wrecking_ball",
	"bladestorm_rotor": "pinwheel",
	"storm_mast": "tesla_pylon",
	"grounding_spike": "lightning_rod",
}


# True when the table in use keeps this trick.
static func in_play(trick_id: String) -> bool:
	return table == null or table.synergy_in_play(trick_id)


# The tricks a maker carries that the table keeps, in row order.
static func of_maker(maker: String) -> Array:
	return ROWS.keys().filter(func(key): return ROWS[key]["maker"] == maker and in_play(key))


# The tricks awake for these maker counts (maker -> distinct pieces), in row order.
static func active(counted: Dictionary) -> Array:
	return ROWS.keys().filter(func(key): return in_play(key) and int(counted.get(ROWS[key]["maker"], 0)) >= AT)


# The first trick one more distinct piece of `maker` would wake, or "".
static func completed_by(counted: Dictionary, maker: String) -> String:
	if maker == "" or int(counted.get(maker, 0)) != AT - 1:
		return ""
	var tricks := of_maker(maker)
	return tricks[0] if not tricks.is_empty() else ""


# True for a trick that only adds elements to actions: told when it wakes, not when it fires.
static func told_on_wake(trick_id: String) -> bool:
	return ROWS.has(trick_id) and ROWS[trick_id].get("transformers", []).is_empty()


# The element a trick's rule adds first, "frost" or "arc", or "": what its chime rings in.
static func element(trick_id: String) -> String:
	var elements: Dictionary = ROWS.get(trick_id, {}).get("elements", {})
	if elements.is_empty():
		return ""
	var first = elements.values()[0]
	return String(first[0] if first is Array else first)


static func callout(trick_id: String) -> Dictionary:
	return ROWS.get(trick_id, {}).get("callout", {})


# Codex cards, one per trick in play: {id, category, name, hint, clue, text, maker, tags}.
# maker_name turns a maker id into its display name; the hint says what wakes it, the clue the
# piece still to find.
static func declarations(maker_name: Callable) -> Array:
	var cards: Array = []
	for key in ROWS:
		if not in_play(key):
			continue
		var row: Dictionary = ROWS[key]
		cards.append({
			"id": key,
			"category": CATEGORY,
			"name": row["name"],
			"hint": "Two %s parts" % maker_name.call(row["maker"]),
			"clue": "Another %s part" % maker_name.call(row["maker"]),
			"text": row["text"],
			"maker": row["maker"],
			"tags": row["tags"],
		})
	return cards


# The Evolved parts that should be gained now: both ingredients held, the Evolved part not.
static func evolutions_ready(held: Array) -> Array:
	return EVOLUTIONS.keys().filter(func(into): return not into in held and _holds_all(held, EVOLUTIONS[into]))


# True while an Evolved part's ingredients are both held; an Evolved part gives nothing otherwise.
# True for any part that is not an Evolved part.
static func evolution_live(part_id: String, held: Array) -> bool:
	return not EVOLUTIONS.has(part_id) or _holds_all(held, EVOLUTIONS[part_id])


# The trick an Evolved part grew out of, or "".
static func evolution_of(part_id: String) -> String:
	return EVOLVED_FROM.get(part_id, "")


# True for an Evolved part or one of its ingredients.
static func in_evolution(part_id: String) -> bool:
	return EVOLUTIONS.has(part_id) or EVOLUTIONS.values().any(func(pair): return part_id in pair)


static func _holds_all(held: Array, parts: Array) -> bool:
	return parts.all(func(part_id): return part_id in held)
