extends RefCounted

const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Sable := preload("res://src/core/trees/sable.gd")
const Rivet := preload("res://src/core/trees/rivet.gd")
const Kest := preload("res://src/core/trees/kest.gd")
const Tarn := preload("res://src/core/trees/tarn.gd")
const Tally := preload("res://src/core/trees/tally.gd")
const Cannon := preload("res://src/core/trees/cannon.gd")
const Augments := preload("res://src/movement/augments.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Sticky := preload("res://src/combat/sticky.gd")

# One binary upgrade tree per pilot (DESIGN-V2 section 15, the primer gate). Four picks:
# at class select, then at Moss's workshop after stages 1, 2 and 3, so each tree has
# 2, 4, 8 and 16 nodes by depth and 16 end builds. A pick persists for the run and a
# new run starts clean.
#
# A node never edits ability code. It carries ops the rest of the game reads:
#   swap     {slot: ability id}     the slot (or "ultimate") plays a variant row from AbilityState.ABILITIES
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
const TREES := {"pylon_engineer": Sable.NODES, "runner_gunner": Rivet.NODES, "demolitions_caster": Kest.NODES,
	"tarn": Tarn.NODES, "tally": Tally.NODES,
	"remembered_cannon": Cannon.NODES}
# Each pilot declares NODES_WORLD_ONE in the same heap order as its full tree.
const WORLD_ONE_TABLES := {"pylon_engineer": Sable, "runner_gunner": Rivet, "demolitions_caster": Kest, "tarn": Tarn,
	"tally": Tally,
	"remembered_cannon": Cannon}
# The slot a node's card sits on: the bar, the chips and, from depth 3, the ultimate
# (design-v3/SKILL-BAR.md section 12, item 3).
const KEYS := ["weapon", "movement", "special", "smash", "line", "ultimate"]
const OPS := ["swap", "knob", "proc", "pattern", "charges", "cooldown"]
# The director's vocabulary: what a build leans on, so packs can test it fairly.
const TAGS := ["air", "burst", "close", "ranged", "mobility", "mounted", "sustain", "cc_immune", "traps", "stealth"]
# The offer kinds (W13-INTEGRATION-3 SG8). A pair is the two-card pick. A take_or_skip offer opens
# depth 4 with one child of the run's own depth-3 pick: take it as the fourth pick, or skip it for
# free and its sibling (the other child) opens as a forced pick, so the run's four picks stay one
# connected path and it still makes its fourth pick (BIBLE.md growth paragraph). No reroll; the
# skipped item never returns; only a checkpoint opens any offer, never elapsed time (TADR-010).
const OFFER_PAIR := "pair"
const OFFER_TAKE_OR_SKIP := "take_or_skip"
const OFFER_FORCED := "forced"
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
	"ult_beats": {"default": 0},
	"ult_encore": {"default": false},
	"ult_radius": {"default": 0.0},
	"ult_volley": {"default": 0},
	# The shared ultimate knobs (ult_encore, ult_beats, ult_radius, ult_volley) are B3's. A pilot
	# may own at most one ult_<word> knob, in its own block (SKILL-BAR section 12, item 4).
	# --- P-C Sable knob ---
	# --- end Sable ---
	# --- P-C Rivet knob ---
	# Rivet's own: the Breach Skid (and the Juggernaut Drive's rams) throw this many times as hard.
	"ult_pins": {"default": 1.0},
	# --- end Rivet ---
	# --- P-C Kest knob ---
	# --- end Kest ---
	# --- P-C Tarn knob ---
	# --- end Tarn ---
	# --- P-C Tally knob ---
	# Plate Return's settle share (pilots/tally.md section 3, depth 4); Weapons.SETTLE_SHARE.
	"ult_settle": {"default": Weapons.SETTLE_SHARE},
	# --- end Tally ---
	# --- P-C Cannon knob ---
	# --- end Cannon ---
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
# The deepest pick currently open to the run: worlds one, two and three allow 2, 3 and 4.
# world.gd sets it from the stage table's world index; flag off keeps the legacy four depths.
var max_depth := DEPTHS
# The world-one node tables in force; world.gd sets it beside max_depth only in world one.
var world_one := false
# The late forced-or-skip offer in force (SG8): off keeps every depth a plain pair. A run-level
# switch sets it; the full tree only, since world one never reaches depth 4.
var late_offer := false
var events

var _knobs := {}
var _procs: Array = []
var _patterns := {}
var _tags: Array[String] = []
# The run declined its take_or_skip item; depth 4 is then a plain pair. Saved with the run's picks.
var _late_skipped := false

# A pick landed; the ball fits its slot ops (swap, charges, cooldown) onto the kit.
signal picked(node: Dictionary)


func _init(events_ref = null) -> void:
	events = events_ref


# Pilot ids with no tree, already warned about this session.
static var unknown_warned := {}


static func reset_for_tests() -> void:
	unknown_warned.clear()


static func depth_cap(world_index: int) -> int:
	return clampi(world_index + 1, WORLD_ONE_DEPTHS, DEPTHS)


static func nodes(for_class: String, world_one := false) -> Array:
	if world_one and WORLD_ONE_TABLES.has(for_class):
		return WORLD_ONE_TABLES[for_class].NODES_WORLD_ONE
	if not TREES.has(for_class):
		if for_class == "":
			return []
		if not unknown_warned.has(for_class):
			unknown_warned[for_class] = true
			push_warning("upgrade_tree: no tree for '%s'; it offers no picks" % for_class)
		return []
	return TREES[for_class]


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


# Four safe growth picks preserve the untouched kit AND earlier picks on their route.
# This is a conservative data check for swaps and knobs, separate from structural
# problems(): existing tradeoff nodes remain playable and are reported, never edited.
# Any different ability id replaces the old action, even if its variant adds power.
# Any numeric reduction is flagged pending decision 3, including lower drain/timers;
# false cannot disable an enabled knob. Ram Fins explicitly removes enemy rebound.
# Other ops and runtime effectiveness are outside this check; [] is not a feel verdict.
static func safe_pick_problems(for_class: String, n: Dictionary, earlier: Array = []) -> Array[String]:
	var out: Array[String] = []
	var id: String = n.get("id", "<fixture>")
	var def := ClassDef.by_id(for_class)
	if def == null:
		out.append("%s: unknown pilot '%s'" % [id, for_class])
		return out
	var slots := {}
	var knobs := {}
	for slot in AbilityState.SWAPPABLE:
		slots[slot] = def.get("%s_id" % slot)
	for k in KNOBS:
		knobs[k] = KNOBS[k]["default"]
	for prior in earlier:
		for slot in prior.get("swap", {}):
			slots[slot] = prior["swap"][slot]
		for k in prior.get("knob", {}):
			knobs[k] = prior["knob"][k]
	for slot in n.get("swap", {}):
		var replacement = n["swap"][slot]
		if not slots.has(slot) or not AbilityState.ABILITIES.has(replacement):
			out.append("%s: swap %s -> %s removes a valid slot ability" % [id, slot, replacement])
		elif _grows(slots[slot], replacement):
			continue
		elif replacement != slots[slot] or replacement != def.get("%s_id" % slot):
			out.append("%s: swap %s -> %s replaces ability %s" % [id, slot, replacement, slots[slot]])
	for k in n.get("knob", {}):
		if not KNOBS.has(k):
			out.append("%s: unknown knob '%s' cannot be certified safe" % [id, k])
			continue
		var value = n["knob"][k]
		var base = KNOBS[k]["default"]
		var previous = knobs[k]
		if typeof(base) == TYPE_BOOL:
			if typeof(value) != TYPE_BOOL:
				out.append("%s: knob %s is not a boolean" % [id, k])
			elif not value and (base or previous):
				out.append("%s: knob %s disables an enabled ability" % [id, k])
			elif k == "sprint_no_rebound" and value:
				out.append("%s: knob sprint_no_rebound removes enemy rebound" % id)
		elif typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			out.append("%s: knob %s is not a finite number" % [id, k])
		elif float(value) < float(base):
			out.append("%s: knob %s lowers default %s to %s" % [id, k, base, value])
		elif float(value) < float(previous):
			out.append("%s: knob %s lowers earlier pick %s to %s" % [id, k, previous, value])
	return out


# A swap to a row whose variant_of is the held ability is growth: a depth-3 ultimate variant
# changes the set piece without taking it away (SKILL-BAR section 12, item 3).
static func _grows(held, replacement) -> bool:
	var base := String(AbilityState.ABILITIES.get(String(replacement), {}).get("variant_of", ""))
	return base != "" and base == String(held)


# Visit every node with its actual ancestor picks. The world-one offer profile has
# only six reachable nodes; the full profile checks all thirty, Tarn's included.
static func safe_growth_problems(for_class: String, world_one := false) -> Array[String]:
	var out: Array[String] = []
	var list := nodes(for_class, world_one)
	if list.is_empty():
		out.append("%s: no growth tree" % for_class)
		return out
	if world_one:
		list = list.slice(0, WORLD_ONE_SIZE)
	for i in list.size():
		var earlier: Array = []
		var parent: int = (i - 2) / 2 if i >= 2 else -1
		while parent >= 0:
			earlier.push_front(list[parent])
			parent = (parent - 2) / 2 if parent >= 2 else -1
		out.append_array(safe_pick_problems(for_class, list[i], earlier))
	return out


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
			if not slot in AbilityState.SWAPPABLE or not AbilityState.ABILITIES.has(variant):
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
	_late_skipped = false
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
	# A pilot with no tree has nothing to offer, so no pick is ever owed.
	return picks.size() < allowed and picks.size() < max_depth and not nodes(class_id, world_one).is_empty()


# How the offer at this depth is made: take_or_skip only at depth 4, only with late_offer on and
# never in the world-one profile; after the run skipped its late item, depth 4 is one forced pick
# (the sibling), also when the saved skip loads under a run with late_offer off. Otherwise a pair.
func offer_kind(depth: int) -> String:
	if world_one or depth != DEPTHS:
		return OFFER_PAIR
	if _late_skipped:
		return OFFER_FORCED
	if late_offer:
		return OFFER_TAKE_OR_SKIP
	return OFFER_PAIR


# The take_or_skip item for this run's path, or {} before depth 3 is picked or when none is owed.
func late_item() -> Dictionary:
	if picks.size() < DEPTHS - 1 or offer_kind(DEPTHS) != OFFER_TAKE_OR_SKIP:
		return {}
	var list := nodes(class_id, world_one)
	var i := _late_index(class_id, list)
	return list[i] if i >= 0 else {}


# The player declines the open take_or_skip item. Free: no pick, no charge. Its sibling opens at
# once as the forced fourth pick (its tree_offered goes out), and the item never comes back.
# Refused on a pair or a forced pick.
func skip() -> bool:
	if not pending() or picks.size() + 1 != DEPTHS or late_item().is_empty():
		return false
	_late_skipped = true
	events_emit("tree_offered", [class_id, DEPTHS, offered(class_id, DEPTHS).map(func(n): return n["id"])])
	return true


# A resumed run puts its saved skip back before its picks are replayed (RunState.tree_late_skipped).
func restore_late_skip(skipped: bool) -> void:
	_late_skipped = skipped


func late_skipped() -> bool:
	return _late_skipped


# The two choices at this depth for the path this run has taken: the children of the
# pick one level up. A depth already picked answers with the pair it offered. At depth 4 a
# take_or_skip offer is the late item alone and a forced offer its sibling alone.
func offered(for_class: String, depth: int) -> Array:
	if for_class != class_id or depth < 1 or depth > max_depth or depth > picks.size() + 1:
		return []
	var list := nodes(for_class, world_one)
	if list.is_empty():
		return []
	var pair := _pair_indices(for_class, list, depth)
	if pair.is_empty():
		return []
	match offer_kind(depth):
		OFFER_TAKE_OR_SKIP:
			return [list[pair[_LATE]]]
		OFFER_FORCED:
			return [list[pair[1 - _LATE]]]
	return pair.map(func(i): return list[i])


# The ordinary pair's indices at this depth, or [] for a route that cannot give two.
func _pair_indices(for_class: String, list: Array, depth: int) -> Array:
	var pair := [0, 1]
	if depth > 1:
		pair = children_of(index_of(for_class, picks[depth - 2], world_one))
	if depth > 1 and not world_one and not _pair_fits(pair, list, depth):
		# A world-one pick can sit at another depth in the full table (Sable's Face Runner: slot 3
		# there, slot 9 here). Take its children from the world-one slot, and swap any id the run
		# already holds for the first unheld depth-d node under the first pick.
		pair = _retained_pair(for_class, list, depth)
	# Refuse a route that cannot give two nodes at this depth instead of offering the wrong ones.
	if not _pair_fits(pair, list, depth):
		return []
	return pair


# Which child of the run's own depth-3 pick is the take_or_skip item (L4); the other is the
# forced sibling. Both come from the run's own depth-4 pair, so the four picks stay one path.
const _LATE := 0


func _late_index(for_class: String, list: Array) -> int:
	var pair := _pair_indices(for_class, list, DEPTHS)
	return int(pair[_LATE]) if not pair.is_empty() else -1


func _pair_fits(pair: Array, list: Array, depth: int) -> bool:
	return pair.size() == 2 and pair.all(func(i): return i >= 0 and i < list.size() and depth_of(i) == depth)


func _retained_pair(for_class: String, list: Array, depth: int) -> Array:
	var slot := index_of(for_class, picks[depth - 2], true)
	var first := index_of(for_class, picks[0], true)
	if slot < 0 or first < 0:
		return []
	var pair := children_of(slot)
	if not _pair_fits(pair, list, depth):
		return []
	var held := picks.slice(0, depth - 1)
	for n in pair.size():
		if list[pair[n]]["id"] not in held:
			continue
		var other: int = pair[1 - n]
		var found := -1
		for i in list.size():
			if depth_of(i) == depth and ((i + 2) >> (depth - 1)) - 2 == first and i != other \
					and list[i]["id"] not in held:
				found = i
				break
		if found < 0:
			return []
		pair[n] = found
	return pair


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


# True when a held pick swaps this slot to this ability row. A relic that duplicates a pick's
# swap reads this so it neither undoes the pick nor is offered on top of it.
func gives_swap(slot: String, ability: String) -> bool:
	for node_id in picks:
		var n := node(class_id, node_id, world_one)
		if n.get("swap", {}).get(slot, "") == ability:
			return true
	return false


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
		if slot == AbilityState.ULTIMATE:
			abilities.ultimate_id = String(n["swap"][slot])
		else:
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
