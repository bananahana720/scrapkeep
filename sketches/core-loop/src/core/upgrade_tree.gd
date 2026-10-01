extends RefCounted

const AbilityState := preload("res://src/core/ability_state.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Sable := preload("res://src/core/trees/sable.gd")
const Rivet := preload("res://src/core/trees/rivet.gd")
const Kest := preload("res://src/core/trees/kest.gd")
const Augments := preload("res://src/movement/augments.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Sticky := preload("res://src/combat/sticky.gd")

# One binary upgrade tree per pilot (DESIGN-V2 section 15, the primer gate). Four picks:
# at class select, then at Moss's workshop after stages 1, 2 and 3, so each tree has
# 2, 4, 8 and 16 nodes by depth and 16 end builds. A pick persists for the run and a
# new run starts clean.
#
# A node never edits ability code. It carries ops the rest of the game reads:
#   swap     {slot: ability id}     the slot plays a variant row from AbilityState.ABILITIES
#   knob     {name: value}          a behaviour switch or number, defaults in KNOBS
#   proc     [{on, do, scale, gap}] on a bus fact, run one of ACTIONS (combat runs them)
#   pattern  {weapon: transformer}  applied to that weapon's Pattern after the parts
#   charges  {slot: extra charges}  added to the slot's stockpile cap, on top of items
#   cooldown {slot: scale}          floored at AbilityState.COOLDOWN_FLOOR
#   tags     [..]                   what the build leans on, for the director (TAGS)
# A later pick overrides an earlier knob of the same name.

const DEPTHS := 4
const SIZE := 30
# The world-one profile (--world-one-builds=on): depth 1 and depth 2 only, six nodes a pilot
# (indices 0 to 5 of the same heap-ordered list), and the run's picks are the start and the
# workshop after stage 1. Deeper nodes stay in the data and are never offered.
const WORLD_ONE_DEPTHS := 2
const WORLD_ONE_SIZE := 6
const TREES := {"pylon_engineer": Sable.NODES, "runner_gunner": Rivet.NODES, "demolitions_caster": Kest.NODES}
# A pilot may declare NODES_WORLD_ONE (same heap order); with the tree's world_one flag on, every
# reader sees it in place of NODES. A pilot without one keeps NODES on both sides of the flag.
const WORLD_ONE_TABLES := {"pylon_engineer": Sable}
const KEYS := ["weapon", "movement", "special", "smash"]
const OPS := ["swap", "knob", "proc", "pattern", "charges", "cooldown"]
# The director's vocabulary: what a build leans on, so packs can test it fairly.
const TAGS := ["air", "burst", "close", "ranged", "mobility", "mounted", "sustain", "cc_immune", "traps", "stealth"]
const NAME_WORDS := 3
const EFFECT_WORDS := 8

# Every knob a node may set, with its default (the untouched kit) and whether it is a
# time between repeats, which no node may take under the cooldown floor.
const KNOBS := {
	"mount_reach": {"default": 1.0}, "grapple_fling": {"default": 0.0}, "air_charge": {"default": 1.0},
	"mount_cc_immune": {"default": false}, "vault_air": {"default": false}, "vault_lock": {"default": Augments.VAULT_FACE_COOLDOWN, "time": true},
	"mounted_recharge": {"default": 1.0}, "winch_mount": {"default": false}, "plant_all": {"default": false},
	"anchor_pulse": {"default": 0.0, "time": true}, "winch_punch": {"default": 1.0}, "discharge_chain": {"default": false},
	"special_echo": {"default": 0.0, "time": true}, "vault_gain": {"default": Augments.VAULT_GAIN}, "vault_tags": {"default": false},
	"vault_enemies": {"default": false}, "air_turret": {"default": false}, "mounted_autogauge": {"default": false},
	"winch_bank": {"default": 1.0}, "sentry": {"default": 0.0}, "mount_pulse": {"default": 0.0, "time": true},
	"plant_repel": {"default": 1.0}, "mass_launch": {"default": false},
	"sprint_fire_drain": {"default": 1.0}, "sprint_no_rebound": {"default": false}, "sprint_punch": {"default": Weapons.SPRINT_PUNCH},
	"blast_pull": {"default": false}, "sprint_full_blast": {"default": false}, "skid_keep": {"default": Augments.SKID_KEEP},
	"overdrive_immune": {"default": false}, "skid_pins": {"default": 1.0}, "crush_refund": {"default": 0.0},
	"sprint_perpetual": {"default": false}, "sprint_kick": {"default": 0.0}, "sprint_float": {"default": 1.0},
	"sticky_fuse": {"default": Weapons.STICKY_FUSE}, "sticky_max_live": {"default": Weapons.STICKY_MAX_LIVE},
	"cloak_sight": {"default": Weapons.CLOAK_SIGHT},
	"sticky_reach": {"default": Sticky.CONTACT_REACH}, "mini_count": {"default": Weapons.MINI_COUNT}, "glide_cloak": {"default": false},
	"cloak_keep": {"default": false}, "glide_bombs": {"default": 0.0, "time": true}, "rocket_auto": {"default": false},
	"line_marks": {"default": 0.0}, "sticky_chain": {"default": 0.0}, "sticky_breach": {"default": 1.0},
	"sticky_grow": {"default": false}, "slam_fall_scale": {"default": false}, "mini_linger": {"default": 0.0},
	"blink_cut": {"default": false}, "smoke_cloud": {"default": 0.0}, "sticky_ride": {"default": false},
	"mark_burst": {"default": false}, "line_charges": {"default": 0}, "cloak_free_blink": {"default": false},
	"cloak_hold_fast": {"default": false},
}

# What a proc may do, and the bus facts each action itself causes. No proc listens for
# a fact its own tree's actions cause, so chains end by construction (DESIGN-V2 section
# 7); tree_data_test checks it.
const DAMAGE_FACTS := ["enemy_struck", "enemy_killed", "strike_deflected", "enemy_pinned"]
const ACTIONS := {
	"discharge": DAMAGE_FACTS,
	"blast": DAMAGE_FACTS,
	"volley": DAMAGE_FACTS + ["shot_fired"],
	"charge": DAMAGE_FACTS + ["sticky_detonated", "rocket_jumped", "cloak_started", "cloak_broken"],
	"detonate": DAMAGE_FACTS + ["sticky_detonated", "rocket_jumped", "cloak_started", "cloak_broken"],
	"grant_special": [], "grant_move": [], "refund_special": [], "refund_move": [], "overdrive": [], "air": [],
}

var class_id := ""
var picks: Array[String] = []
# How many picks the run has opened so far: the start, then each workshop visit.
var allowed := 0
# The most picks a run may take: DEPTHS, or WORLD_ONE_DEPTHS under the world-one profile.
# world.gd sets it from the tuning flag; a new run leaves it alone.
var max_depth := DEPTHS
# The world-one node tables in force (--world-one-builds=on); world.gd sets it beside max_depth.
var world_one := false
var events

var _knobs := {}
var _procs: Array = []
var _patterns := {}
var _tags: Array[String] = []

# A pick landed; the ball fits its slot ops (swap, charges, cooldown) onto the kit.
signal picked(node: Dictionary)


func _init(events_ref = null) -> void:
	events = events_ref


static func nodes(for_class: String, world_one := false) -> Array:
	if world_one and WORLD_ONE_TABLES.has(for_class):
		return WORLD_ONE_TABLES[for_class].NODES_WORLD_ONE
	return TREES.get(for_class, [])


static func depth_of(index: int) -> int:
	return int(floor(log(float(index + 2)) / log(2.0)))


static func children_of(index: int) -> Array:
	return [2 * index + 2, 2 * index + 3]


static func index_of(for_class: String, node_id: String, world_one := false) -> int:
	var list := nodes(for_class, world_one)
	for i in list.size():
		if list[i]["id"] == node_id:
			return i
	return -1


static func node(for_class: String, node_id: String, world_one := false) -> Dictionary:
	var i := index_of(for_class, node_id, world_one)
	return nodes(for_class, world_one)[i] if i >= 0 else {}


# The four node ids from the root pair down to a node, or [] for an unknown id.
static func path_to(for_class: String, node_id: String, world_one := false) -> Array[String]:
	var out: Array[String] = []
	var i := index_of(for_class, node_id, world_one)
	while i >= 0:
		out.push_front(nodes(for_class, world_one)[i]["id"])
		i = (i - 2) / 2 if i >= 2 else -1
	return out


# A node's icon: its ability glyph with one variant notch per depth (VISUAL-LANGUAGE
# section 5's variant notch, drawn by V2).
static func icon_of(for_class: String, node_id: String, world_one := false) -> Dictionary:
	var i := index_of(for_class, node_id, world_one)
	if i < 0:
		return {}
	return {"id": nodes(for_class, world_one)[i]["icon"], "notch": depth_of(i)}


# Everything wrong with a class's tree, as sentences; empty when it is sound.
# `world_one` validates the two-depth profile: the tree is still the fixed 30 nodes, but only
# its first six are offered, so only those six are held to the node rules and to the proc-loop
# check (their leaves are the depth-2 nodes).
static func problems(for_class: String, world_one := false) -> Array[String]:
	var out: Array[String] = []
	var list := nodes(for_class, world_one)
	if list.size() != SIZE:
		out.append("%s has %d nodes, not %d" % [for_class, list.size(), SIZE])
	var seen := {}
	var bus: Script = GameEvents
	var first_leaf := list.size() - 16
	if world_one:
		list = list.slice(0, WORLD_ONE_SIZE)
		first_leaf = WORLD_ONE_SIZE - 4
	for leaf in range(first_leaf, list.size()):
		var loop := _proc_loop(for_class, path_to(for_class, list[leaf].get("id", ""), world_one), world_one)
		if loop != "":
			out.append("%s: the build ending in %s can loop on %s" % [for_class, list[leaf].get("id", ""), loop])
	for n in list:
		var id: String = n.get("id", "")
		if id == "" or seen.has(id):
			out.append("%s: missing or repeated id '%s'" % [for_class, id])
		seen[id] = true
		var words: int = String(n.get("name", "")).split(" ", false).size()
		if words < 1 or words > NAME_WORDS:
			out.append("%s: name has %d words" % [id, words])
		words = String(n.get("effect", "")).split(" ", false).size()
		if words < 1 or words > EFFECT_WORDS:
			out.append("%s: effect has %d words" % [id, words])
		if not n.get("key", "") in KEYS:
			out.append("%s: key '%s' is not one of %s" % [id, n.get("key", ""), KEYS])
		if not String(n.get("icon", "")).begins_with("ab_"):
			out.append("%s: icon '%s' is not an ab_ id" % [id, n.get("icon", "")])
		var tags: Array = n.get("tags", [])
		if tags.is_empty() or tags.any(func(t): return not t in TAGS):
			out.append("%s: tags %s outside %s" % [id, tags, TAGS])
		if not OPS.any(func(op): return n.has(op)):
			out.append("%s: no op" % id)
		for k in n.get("knob", {}):
			if not KNOBS.has(k):
				out.append("%s: unknown knob '%s'" % [id, k])
		for slot in n.get("swap", {}):
			var variant: String = n["swap"][slot]
			if not slot in AbilityState.SLOTS or not AbilityState.ABILITIES.has(variant):
				out.append("%s: swap %s -> %s is not a slot and ability row" % [id, slot, variant])
		for slot in n.get("charges", {}):
			if not slot in AbilityState.SLOTS or int(n["charges"][slot]) < 1:
				out.append("%s: charges %s" % [id, n["charges"]])
		for slot in n.get("cooldown", {}):
			if not slot in AbilityState.SLOTS:
				out.append("%s: cooldown slot %s" % [id, slot])
		for weapon in n.get("pattern", {}):
			if not weapon in Weapons.ALL:
				out.append("%s: pattern for unknown weapon %s" % [id, weapon])
				continue
			var base: Resource = Weapons.base(weapon)
			for part in n["pattern"][weapon]:
				for key in n["pattern"][weapon][part]:
					if not part in ["add", "mul", "min"] or base.get(key) == null:
						out.append("%s: pattern %s.%s" % [id, part, key])
		for p in n.get("proc", []):
			if not ACTIONS.has(p.get("do", "")) or not bus.has_script_signal(p.get("on", "")):
				out.append("%s: proc %s" % [id, p])
	return out


# A bus fact from which one build's procs can lead back to itself, or "" when every
# chain ends: each proc links its trigger to the facts its action causes.
static func _proc_loop(for_class: String, build: Array[String], world_one := false) -> String:
	var links := {}
	for id in build:
		for p in node(for_class, id, world_one).get("proc", []):
			if not links.has(p["on"]):
				links[p["on"]] = []
			links[p["on"]].append_array(ACTIONS.get(p["do"], []))
	for start in links:
		var frontier: Array = links[start].duplicate()
		var visited := {}
		while not frontier.is_empty():
			var fact = frontier.pop_back()
			if fact == start:
				return start
			if visited.has(fact):
				continue
			visited[fact] = true
			frontier.append_array(links.get(fact, []))
	return ""


# A new run: no picks, nothing open, the untouched kit.
func reset(for_class: String) -> void:
	class_id = for_class
	picks.clear()
	allowed = 0
	_resolve()


# A checkpoint (class select, or a workshop visit) opens the next pick and offers it.
func open_checkpoint() -> void:
	if allowed >= max_depth or class_id == "":
		return
	allowed += 1
	if pending():
		var depth := picks.size() + 1
		events_emit("tree_offered", [class_id, depth, offered(class_id, depth).map(func(n): return n["id"])])


func pending() -> bool:
	return picks.size() < allowed and picks.size() < max_depth


# The two choices at this depth for the path this run has taken: the children of the
# pick one level up. A depth already picked answers with the pair it offered.
func offered(for_class: String, depth: int) -> Array:
	if for_class != class_id or depth < 1 or depth > max_depth or depth > picks.size() + 1:
		return []
	var list := nodes(for_class, world_one)
	var pair := [0, 1]
	if depth > 1:
		pair = children_of(index_of(for_class, picks[depth - 2], world_one))
	return pair.map(func(i): return list[i])


func pick(node_id: String) -> bool:
	if not pending():
		return false
	var depth := picks.size() + 1
	if not offered(class_id, depth).any(func(n): return n["id"] == node_id):
		return false
	picks.append(node_id)
	_resolve()
	picked.emit(node(class_id, node_id, world_one))
	events_emit("tree_picked", [class_id, node_id, depth])
	# A skipped pick leaves one open: the next depth is offered as soon as this one lands.
	if pending():
		events_emit("tree_offered", [class_id, depth + 1, offered(class_id, depth + 1).map(func(n): return n["id"])])
	return true


func path() -> Array[String]:
	return picks.duplicate()


func knob(name: String):
	return _knobs.get(name, KNOBS[name]["default"])


func procs() -> Array:
	return _procs


func pattern_ops(weapon_id: String) -> Array:
	return _patterns.get(weapon_id, [])


# The build's leanings, one per tag in pick order, for the director to weight packs by
# (DESIGN-V2 section 15.5): a build is tested, never hard-countered. Read-only.
func branch_tags() -> PackedStringArray:
	return PackedStringArray(_tags)


# Fits one pick's slot ops onto the live ability state: a swap keeps the slot's cap and
# scale, extra charges add to whatever items gave, a cooldown scale multiplies in.
static func apply_pick(abilities, n: Dictionary) -> void:
	for slot in n.get("swap", {}):
		abilities.swap(slot, n["swap"][slot])
	for slot in n.get("charges", {}):
		var extra := int(n["charges"][slot])
		abilities.set_max_charges(slot, abilities.slot(slot).max_charges + extra)
		abilities.grant(slot, extra)
	for slot in n.get("cooldown", {}):
		abilities.set_cooldown_scale(slot, abilities.slot(slot).cooldown_scale * float(n["cooldown"][slot]))


func _resolve() -> void:
	_knobs = {}
	_procs = []
	_patterns = {}
	_tags = []
	for id in picks:
		var n := node(class_id, id, world_one)
		for k in n.get("knob", {}):
			var value = n["knob"][k]
			if KNOBS[k].get("time", false) and float(value) > 0.0:
				value = maxf(AbilityState.COOLDOWN_FLOOR, float(value))
			_knobs[k] = value
		for p in n.get("proc", []):
			var row: Dictionary = p.duplicate()
			row["gap"] = maxf(AbilityState.COOLDOWN_FLOOR, float(row.get("gap", 0.5)))
			row["node"] = id
			_procs.append(row)
		for w in n.get("pattern", {}):
			if not _patterns.has(w):
				_patterns[w] = []
			_patterns[w].append(n["pattern"][w])
		for tag in n.get("tags", []):
			if not tag in _tags:
				_tags.append(tag)


func events_emit(kind: String, args: Array) -> void:
	if events != null and events.has_signal(kind):
		events.callv("emit_signal", [kind] + args)
