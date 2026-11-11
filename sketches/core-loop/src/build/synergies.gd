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

# The stage table the build runs on, set by the build at setup. A table's
# synergy_in_play(id) names the synergies and tag rules it keeps; null keeps them all.
static var table = null

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
# part the undiscovered card names. "callout" is what the why callout draws when the row
# fires: part a (the shown part) and part b (a part carrying tags[1]) as icons, then words,
# exactly three, in the work-crew voice.
const ROWS := {
	"storm_lattice": {
		"name": "Storm Lattice", "tags": ["chain", "split"], "shown": "chain_arc",
		"text": "Every fragment of a cross split jumps to a neighbour.",
		"transformers": ["storm_lattice"], "patterns": {"chain_arc": 1},
		"callout": {"a": "chain_arc", "b": "cross_split", "words": "Bolts find neighbours"},
	},
	"thermal_shock": {
		"name": "Thermal Shock", "tags": ["frost", "arc"], "shown": "frost_vane",
		"text": "A slam's arc shatters nearby ice into a shard nova at double damage, then fresh ice freezes around you.",
		"transformers": ["thermal_shock"], "elements": {"slam": ["arc", "frost"]}, "dials": {"shatter_damage": 2.0},
		"callout": {"a": "frost_vane", "b": "arc_coil", "words": "Ice cracks loud"},
	},
	"lightning_rod": {
		"name": "Lightning Rod", "tags": ["arc", "mass"], "shown": "arc_coil",
		"text": "Every piece of scrap you pick up sparks an arc at the nearest machine.",
		"transformers": ["lightning_rod"],
		"callout": {"a": "arc_coil", "b": "drop_weight", "words": "Scrap sparks back"},
		"evolution": {"parts": ["arc_coil", "drop_weight"], "into": "grounding_spike"},
	},
	"tesla_pylon": {
		"name": "Tesla Pylon", "tags": ["anchor", "arc"], "shown": "focus_lens",
		"text": "While mounted or hooked, arcs leap from you to the two nearest machines twice a second.",
		"transformers": ["tesla_pylon"],
		"callout": {"a": "focus_lens", "b": "live_line", "words": "Hooked means live"},
		"evolution": {"parts": ["focus_lens", "live_line"], "into": "storm_mast"},
	},
	"wrecking_ball": {
		"name": "Wrecking Ball", "tags": ["speed", "kinetic"], "shown": "double_feed",
		"text": "Rams send out a shockwave that hits everything around the target.",
		"transformers": ["wrecking_ball"],
		"callout": {"a": "double_feed", "b": "hot_rivets", "words": "Rams carry through"},
		"evolution": {"parts": ["double_feed", "hot_rivets"], "into": "breaker_drive"},
	},
	"shrapnel_bloom": {
		"name": "Shrapnel Bloom", "tags": ["split", "kinetic"], "shown": "cross_split",
		"text": "Kills burst into shrapnel that hits up to three machines nearby.",
		"transformers": ["shrapnel_bloom"],
		"callout": {"a": "cross_split", "b": "hot_rivets", "words": "Kills come apart"},
	},
	"glacier_hull": {
		"name": "Glacier Hull", "tags": ["mass", "frost"], "shown": "slag_rounds",
		"text": "Hard landings crack out a frost ring that hits machines near you and freezes water.",
		"transformers": ["glacier_hull"],
		"callout": {"a": "slag_rounds", "b": "frost_vane", "words": "Landings ring cold"},
	},
	"pinwheel": {
		"name": "Pinwheel", "tags": ["spiral", "speed"], "shown": "spiral_wave",
		"text": "At fast speed and above you spin a blade ring that cuts the machines you pass.",
		"transformers": ["pinwheel"],
		"callout": {"a": "spiral_wave", "b": "loose_trigger", "words": "Speed grows blades"},
		"evolution": {"parts": ["spiral_wave", "loose_trigger"], "into": "bladestorm_rotor"},
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


# True when the table in use keeps this synergy or tag rule.
static func in_play(synergy_id: String) -> bool:
	return table == null or table.synergy_in_play(synergy_id)


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
		if in_play(key) and named_live(held, tag_sets, key):
			live.append(key)
	return live


static func active_rules(tag_sets: Array) -> Array:
	var live: Array = []
	for key in TAG_RULES:
		if in_play(key) and pair_live(tag_sets, TAG_RULES[key]["tags"]):
			live.append(key)
	return live


# Evolutions: a named synergy row that carries "evolution" {parts, into} turns into an
# Evolved part once both ingredient parts are held. The Evolved part is held in the run's
# part list like any part (so a retry restores it); while it and both ingredients are
# held, the pair synergy is consumed into it: its effect folds once, never twice.

# The synergy ids that are evolutions, in row order.
static func evolution_ids() -> Array:
	var ids: Array = []
	for key in ROWS:
		if ROWS[key].has("evolution") and in_play(key):
			ids.append(key)
	return ids


# The synergy an Evolved part belongs to, or "".
static func evolution_of(part_id: String) -> String:
	for key in ROWS:
		if ROWS[key].has("evolution") and ROWS[key]["evolution"]["into"] == part_id:
			return key
	return ""


static func _holds_all(held: Array, parts: Array) -> bool:
	for part_id in parts:
		if not part_id in held:
			return false
	return true


# The Evolved part ids that should be gained now: both ingredients held, evolved part not.
static func evolutions_ready(held: Array) -> Array:
	var ready: Array = []
	for key in evolution_ids():
		var evo: Dictionary = ROWS[key]["evolution"]
		if not evo["into"] in held and _holds_all(held, evo["parts"]):
			ready.append(evo["into"])
	return ready


# The synergies consumed into a held Evolved part (its ingredients still held).
static func consumed(held: Array) -> Array:
	var out: Array = []
	for key in evolution_ids():
		var evo: Dictionary = ROWS[key]["evolution"]
		if evo["into"] in held and _holds_all(held, evo["parts"]):
			out.append(key)
	return out


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


static func callout(synergy_id: String) -> Dictionary:
	return ROWS.get(synergy_id, {}).get("callout", {})


static func clue(synergy_id: String) -> String:
	return CLUES.get(ROWS[synergy_id]["tags"][1], "something")


# Codex hint cards, one per named synergy: {id, category, name, hint, clue, text,
# shown, tags}. name_of turns a part id into its display name.
static func declarations(name_of: Callable) -> Array:
	var cards: Array = []
	for key in ROWS:
		if not in_play(key):
			continue
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
