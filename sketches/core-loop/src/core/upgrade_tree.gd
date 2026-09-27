extends RefCounted

const AbilityState := preload("res://src/core/ability_state.gd")
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
#   swap     {slot: ability id}     the slot plays a variant from AbilityState.ABILITIES
#   knob     {name: value}          a behaviour switch or number, defaults in KNOBS
#   proc     [{on, do, scale, gap}] on a bus fact, run one of ACTIONS (combat runs them)
#   pattern  {weapon: transformer}  applied to that weapon's Pattern after the parts
#   charges  {slot: max charges}
#   cooldown {slot: scale}          floored at AbilityState.COOLDOWN_FLOOR
#   tags     [..]                   what the build leans on, for the director
# A later pick overrides an earlier knob of the same name.

const DEPTHS := 4
const TREES := {"pylon_engineer": Sable.NODES, "runner_gunner": Rivet.NODES, "demolitions_caster": Kest.NODES}
const SLOTS := AbilityState.SLOTS
const KEYS := ["weapon", "movement", "special", "smash"]

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
	"plant_repel": {"default": 1.0},
	"sprint_fire_drain": {"default": 1.0}, "sprint_no_rebound": {"default": false}, "sprint_punch": {"default": Weapons.SPRINT_PUNCH},
	"blast_pull": {"default": false}, "sprint_full_blast": {"default": false}, "skid_keep": {"default": 0.6},
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

# What a proc may do, and the bus facts each action itself causes, so no proc can
# re-trigger itself (chains end by construction, DESIGN-V2 section 7).
const ACTIONS := {
	"discharge": ["enemy_struck", "enemy_killed", "strike_deflected"],
	"blast": ["enemy_struck", "enemy_killed", "strike_deflected"],
	"volley": ["shot_fired", "enemy_struck", "enemy_killed", "strike_deflected"],
	"charge": ["sticky_detonated", "rocket_jumped", "cloak_started", "cloak_broken", "enemy_struck", "enemy_killed", "strike_deflected"],
	"detonate": ["sticky_detonated", "rocket_jumped", "cloak_started", "cloak_broken", "enemy_struck", "enemy_killed", "strike_deflected"],
	"grant_special": [], "grant_move": [], "refund_special": [], "refund_move": [], "overdrive": [], "air": [],
}

var class_id := ""
var picks: Array[String] = []
# How many picks the run has opened so far: the start, then each workshop visit.
var allowed := 0
var events

var _knobs := {}
var _procs: Array = []
var _patterns := {}
var _swaps := {}
var _charges := {}
var _cooldowns := {}
var _tags: Array[String] = []

signal changed


func _init(events_ref = null) -> void:
	events = events_ref


static func nodes(for_class: String) -> Array:
	return TREES.get(for_class, [])


static func depth_of(index: int) -> int:
	return int(floor(log(float(index + 2)) / log(2.0)))


static func children_of(index: int) -> Array:
	return [2 * index + 2, 2 * index + 3]


static func index_of(for_class: String, node_id: String) -> int:
	var list := nodes(for_class)
	for i in list.size():
		if list[i]["id"] == node_id:
			return i
	return -1


static func node(for_class: String, node_id: String) -> Dictionary:
	var i := index_of(for_class, node_id)
	return nodes(for_class)[i] if i >= 0 else {}


# A node's icon: its ability glyph with a variant notch per depth.
static func icon_of(for_class: String, node_id: String) -> Dictionary:
	var i := index_of(for_class, node_id)
	if i < 0:
		return {}
	return {"id": nodes(for_class)[i]["icon"], "notch": depth_of(i)}


# A new run: no picks, nothing open, the untouched kit.
func reset(for_class: String) -> void:
	class_id = for_class
	picks.clear()
	allowed = 0
	_resolve()


# A checkpoint (class select, or a workshop visit) opens the next pick and offers it.
func open_checkpoint() -> void:
	if allowed >= DEPTHS:
		return
	allowed += 1
	if pending():
		events_emit("tree_offered", [class_id, picks.size() + 1, offered(class_id, picks.size() + 1).map(func(n): return n["id"])])


func pending() -> bool:
	return picks.size() < allowed and picks.size() < DEPTHS


# The two choices at this depth for the path this run has taken: the children of the
# pick one level up. A depth already picked answers with the pair it offered.
func offered(for_class: String, depth: int) -> Array:
	if for_class != class_id or depth < 1 or depth > DEPTHS or depth > picks.size() + 1:
		return []
	var list := nodes(for_class)
	var pair := [0, 1]
	if depth > 1:
		pair = children_of(index_of(for_class, picks[depth - 2]))
	return pair.map(func(i): return list[i])


func pick(node_id: String) -> bool:
	if not pending():
		return false
	var depth := picks.size() + 1
	if not offered(class_id, depth).any(func(n): return n["id"] == node_id):
		return false
	picks.append(node_id)
	_resolve()
	changed.emit()
	events_emit("tree_picked", [class_id, node_id, depth])
	return true


func path() -> Array[String]:
	return picks.duplicate()


func knob(name: String):
	return _knobs.get(name, KNOBS[name]["default"])


func procs() -> Array:
	return _procs


func pattern_ops(weapon_id: String) -> Array:
	return _patterns.get(weapon_id, [])


func swaps() -> Dictionary:
	return _swaps


# The build's leanings, one per tag in pick order, for the director to weight packs by
# (DESIGN-V2 section 15.5): a build is tested, never hard-countered.
func branch_tags() -> PackedStringArray:
	return PackedStringArray(_tags)


# Fits the picks onto a freshly fitted ability state: swaps, charges, cooldown scales.
func apply(abilities) -> void:
	for slot in _swaps:
		abilities.swap(slot, _swaps[slot])
	for slot in _charges:
		abilities.set_max_charges(slot, _charges[slot])
		abilities.grant(slot, _charges[slot])
	for slot in _cooldowns:
		abilities.set_cooldown_scale(slot, _cooldowns[slot])


func _resolve() -> void:
	_knobs = {}
	_procs = []
	_patterns = {}
	_swaps = {}
	_charges = {}
	_cooldowns = {}
	_tags = []
	for id in picks:
		var n := node(class_id, id)
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
		_swaps.merge(n.get("swap", {}), true)
		_charges.merge(n.get("charges", {}), true)
		_cooldowns.merge(n.get("cooldown", {}), true)
		for tag in n.get("tags", []):
			if not tag in _tags:
				_tags.append(tag)


func events_emit(kind: String, args: Array) -> void:
	if events != null and events.has_signal(kind):
		events.callv("emit_signal", [kind] + args)
