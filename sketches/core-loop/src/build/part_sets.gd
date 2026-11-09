extends RefCounted

const Palette := preload("res://src/core/palette.gd")

# SI6 three-part sets (W13-INTEGRATION-3.md SI6; comps/isaac/items-and-synergies.md:76).
# Three distinct held members of one set give the set's rule change, folded into the build
# sheet like a synergy row, so it is derived from the part list and never held: a respec
# that drops a member drops the rule (BIBLE.md:564), and a restore brings it back without
# a second copy. Copies of one member count once. The discovery stays: Ledger keeps every
# set a run has completed, and build.gd files the first completion in the codex.
#
# A rule change is an element trigger build.gd already resolves (dash, slam, shot), so a
# set changes what an action does, never only a number. Every member is a part on the alpha
# list, sets share no member, each set holds more members than it needs and at least SIZE
# of them any pilot can be offered (a pilot's own class parts help it there), so no single
# part, pilot or route is required. No route, gate or pocket reads a set.

const SIZE := 3
const ROW_PREFIX := "set:"

# color is the tell's colour on the mech (set_tell.gd).
const SETS := {
	"live_wire": {
		"name": "Live Wire", "color": Palette.ARC,
		"text": "Every slam bursts an arc, and shots spark where they land.",
		"members": ["arc_coil", "live_line", "cap_relay", "beacon_lamp", "echo_locator", "pylon_capacitor"],
		"elements": {"slam": "arc", "shot": "arc"},
	},
	"storm_front": {
		"name": "Storm Front", "color": Palette.SLATE,
		"text": "Every slam cracks out a frost ring that freezes water and lays ice.",
		"members": ["static_burr", "frost_barb", "chain_arc", "spiral_wave"],
		"elements": {"slam": "frost"},
	},
	"shatter_crew": {
		"name": "Shatter Crew", "color": Palette.COPPER,
		"text": "Shots freeze water where they land; slam the ice to shatter it.",
		"members": ["hot_rivets", "slag_rounds", "pin_setter", "hairline_fracture", "impact_driver"],
		"elements": {"shot": "frost"},
	},
	"ballast_rig": {
		"name": "Ballast Rig", "color": Palette.RUST,
		"text": "Your dash trails frost that freezes water into road.",
		"members": ["rivet_plating", "rivet_seam", "deflect_plate", "ballast_drum", "scrap_armor", "magnet_spool",
			"cache_key", "re_rack"],
		"elements": {"dash": "frost"},
	},
	"hair_trigger": {
		"name": "Hair Trigger", "color": Palette.AMBER,
		"text": "Your dash trails arc that electrifies water.",
		"members": ["loose_trigger", "double_feed", "fast_hands", "barrage_spring", "gatling_heart", "runner_overclock",
			"sprint_cell"],
		"elements": {"dash": "arc"},
	},
}

const ACTIONS := ["dash", "slam", "shot"]
const ELEMENTS := ["frost", "arc"]


# The set part_id belongs to, or "".
static func set_of(part_id: String) -> String:
	for key in SETS:
		if part_id in SETS[key]["members"]:
			return key
	return ""


# The distinct members of set_id in held, in first-held order.
static func counted(set_id: String, held: Array) -> Array:
	var out: Array = []
	var members: Array = SETS.get(set_id, {}).get("members", [])
	for part_id in held:
		if part_id in members and not part_id in out:
			out.append(part_id)
	return out


# The sets held completes, in SETS order.
static func complete(held: Array) -> Array:
	return SETS.keys().filter(func(key): return counted(key, held).size() >= SIZE)


# The set taking part_id now would complete, or "".
static func completed_by(part_id: String, held: Array) -> String:
	var key := set_of(part_id)
	if key == "" or key in complete(held):
		return ""
	return key if key in complete(held + [part_id]) else ""


# The sheet row a complete set folds: its elements under the set's row key.
static func row(set_id: String) -> Dictionary:
	return {"elements": SETS[set_id]["elements"]}


static func row_key(set_id: String) -> String:
	return ROW_PREFIX + set_id


# The element set_id's rule adds, "frost" or "arc" (a set adds one, problems() checks), or "".
static func element(set_id: String) -> String:
	var elements: Dictionary = SETS.get(set_id, {}).get("elements", {})
	return "" if elements.is_empty() else String(elements.values()[0])


# Admission: every set has more than SIZE distinct members, at least SIZE of them
# class-neutral, no member sits in two sets, every member is a row in_play accepts, every
# rule names a known action and element, and a set adds one element (element() names it).
# Returns one line per problem; [] is clean.
static func problems(row_of: Callable, in_play: Callable, sets: Dictionary = SETS) -> Array:
	var out: Array = []
	var seen := {}
	for key in sets:
		var s: Dictionary = sets[key]
		var members: Array = s["members"]
		var unique: Array = []
		for part_id in members:
			if not part_id in unique:
				unique.append(part_id)
		if unique.size() != members.size():
			out.append("%s lists a member twice" % key)
		if unique.size() <= SIZE:
			out.append("%s has %d members; it needs more than %d so no one part is required" % [key, unique.size(), SIZE])
		var neutral := 0
		for part_id in unique:
			if seen.has(part_id):
				out.append("%s is in %s and %s" % [part_id, seen[part_id], key])
			seen[part_id] = key
			var r: Dictionary = row_of.call(part_id)
			if r.is_empty():
				out.append("%s member %s is not a part" % [key, part_id])
			elif String(r.get("class_id", "")) == "":
				neutral += 1
			if not in_play.call(part_id):
				out.append("%s member %s is not in play" % [key, part_id])
		if neutral < SIZE:
			out.append("%s has %d class-neutral members; any pilot needs %d" % [key, neutral, SIZE])
		var added: Array = []
		for action in s["elements"]:
			if not action in ACTIONS or not s["elements"][action] in ELEMENTS:
				out.append("%s rule %s:%s is not a known trigger" % [key, action, s["elements"][action]])
			if not s["elements"][action] in added:
				added.append(s["elements"][action])
		if added.size() != 1:
			out.append("%s adds %d elements; a set adds one" % [key, added.size()])
	return out


# The sets a run has completed. A respec does not forget one, and a repeat completion
# is not new.
class Ledger:
	var found: Array = []

	# The sets in complete that this ledger had not seen; records them.
	func note(complete_sets: Array) -> Array:
		var fresh: Array = []
		for key in complete_sets:
			if not key in found:
				found.append(key)
				fresh.append(key)
		return fresh
