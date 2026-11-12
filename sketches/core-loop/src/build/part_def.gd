extends Resource

const ShotBits := preload("res://src/build/shot_bits.gd")
const Synergies := preload("res://src/build/synergies.gd")

# One part, as data (TADR-008). A part never holds run state: the run's part list says
# how many copies are held, and build_sheet.gd folds every held copy into one derived
# sheet. A new value is a row edit in parts.gd; a new kind of effect is a code change.

# Rarity is set by where a part comes from (DEMO-SPEC): gates offer common
# (rare and relic with bonus cores), fabricators common, vaults rare, won events
# relic. It is shown twice, as a colour and as a topper shape, so colour never
# carries it alone.
const RARITIES := ["common", "rare", "relic", "evolved"]
# The tag vocabulary. Every part carries one or two; named synergies are tag pairs, so
# a combination makes sense before you try it.
const TAGS := ["frost", "arc", "kinetic", "split", "spiral", "chain", "anchor", "speed", "mass"]

@export var id := ""
@export var display_name := ""
# One line a player can read at speed from 30 m away.
@export var text := ""
# What the part makes you do, as a short action ("Split shots into a cross").
@export var verb := ""
# Flat per-hit weapon damage it adds, before the weapon multipliers; may be 0.
@export var punch := 0.0
@export var tags: Array = []
@export var rarity := "common"
# 1 modest, 2 strong, 3 run-defining. Later stages weight offers toward higher tiers.
@export var tier := 1
# weapon | pattern | mobility | class | stat | milestone: picks the hardware shape the
# ball grows for this part and the family glyph on its gate.
@export var family := "stat"
# Only this class is offered the part; "" means any class.
@export var class_id := ""
# The maker whose set this part counts toward (maker_sets.gd); "" for none.
@export var maker := ""
# A won event grants it (milestone_won). Only a gate overcharged by two or more bonus
# cores may also offer it; fabricators and vaults never do.
@export var milestone_only := false
# Multipliers per knob, applied through tuning.set_mod. Keys are Tuning.SPECS keys for
# movement, or the weapon keys in SEAMS.md (weapon_damage, weapon_rate, ...), which
# combat reads with tuning.mod(key).
@export var mods := {}
# Scales the shared boost and dash cooldown; 1.0 leaves it alone.
@export var cooldown_scale := 1.0
# Weapon-pattern transformer levels this part adds, pattern id to levels.
@export var patterns := {}
# Element triggers: which element an action applies. Keys: dash, slam, roll_on_water.
@export var elements := {}
# Scrap magnet reach multiplier and kill-scrap multiplier.
@export var magnet := 1.0
@export var kill_scrap := 1.0
@export var max_hp_bonus := 0.0

# v2 W4 loot (DESIGN-V2 section 7, I2 section 4). trigger is "" (passive) or one of the
# twelve Triggers.NAMES. proc_coeff multiplies the source's base_proc. stack_rule says
# how copies add: linear, hyperbolic (1 - 1/(1 + a x), for anything that could reach
# 100%), capped (copies past stack_cap add nothing) or spike (the rare big jump: one
# copy's value times SPIKE_GROWTH^n - 1, never past SPIKE_MAX_MULTIPLE times one copy;
# stack_cap, when set, is a lower multiple ceiling). icon_category is the cat_ family
# glyph; element is the el_ glyph ("" for none).
const STACK_RULES := ["linear", "hyperbolic", "capped", "spike"]
const WEAPON_MODS := ["weapon_damage", "weapon_rate", "weapon_range", "turret_damage"]
# SR4 start values (comps/ror2/items-and-stacking.md:85 and :96): a spike family exists
# for the big-jump feel, but it is always capped (the proposed 8x of one copy) and the
# pool holds at most one spike part per tier. tools/build_sweep.gd and
# tests/stack_sweep_test.gd hold both rules.
const SPIKE_MAX_MULTIPLE := 8.0
const SPIKE_GROWTH := 2.0
const SPIKES_PER_TIER := 1
# SI5: the build-sheet categories a part can touch (stat_cache.gd refolds each alone).
const STAT_CATEGORIES := ["mods", "cooldown", "patterns", "elements", "magnet", "kill_scrap", "max_hp", "punch", "synergy"]
const ICON_CATEGORIES :=["damage", "mobility", "defense", "utility", "charge", "transform"]
@export var trigger := ""
@export var proc_coeff := 1.0
@export var stack_rule := "linear"
@export var stack_cap := 0.0
@export var icon_category := ""
@export var element := ""
# What the trigger (or, passive, the held part) does: {"do": effect id, ...numbers}.
# The effect ids are item_effects.gd's closed table.
@export var effect := {}
# Ability slot to extra max_charges per copy: weapon, movement, special, smash.
@export var charges := {}
# The seam this part needs from another module ("spawner.extend_cloak"); a part whose
# seam is missing is never offered, so no part is ever dead weight.
@export var needs := ""
# Sold only by Moss (a charge cell), never rolled by a gate, fabricator or vault.
@export var shop_only := false
@export var layer := "global"
@export var reads: Array = []
# SI4 shot bits (shot_bits.gd): zero to two behaviour bits as a set mask. A row may
# name them ("bits": ["pierce"]); otherwise they come from its tags.
@export var bits := 0
# SI5 stat cache (stat_cache.gd): the build-sheet categories this part's fold can move,
# derived from its fields in from_row so a new field cannot go undeclared. Not the row's
# "touches" key, which names the verb the build readout shows.
@export var stat_touches: Array = []
# SG15 three-level parts (parts.gd): MAX_LEVEL dicts, level n's numbers at levels[n - 1],
# on a capped row with stack_cap MAX_LEVEL. Each names only LEVEL_KEYS the row itself sets,
# so a level never moves a sheet category level 1 does not declare. level is the level this
# def stands for (Parts.def_at); a plain def is level 1.
const MAX_LEVEL := 3
const LEVEL_KEYS := ["punch", "mods", "max_hp_bonus", "magnet", "kill_scrap", "cooldown_scale", "text"]
@export var levels: Array = []
@export var level := 1

# SG3, comps/gunfire/scrolls-and-synergies.md:54. These name existing inputs;
# they do not grant eligibility or change a part's effect.
const TRIGGER_READS := {
	"on_hit": "hit_damage", "on_kill": "kill_count", "on_smash": "impact_force",
	"on_rebound": "rebound_speed", "on_vault": "vault_count", "on_charge_release": "charge_count",
	"on_cloak_break": "cloak_seconds", "on_land": "impact_force", "on_speed_tier_up": "speed_tier",
	"on_pickup": "scrap_mass", "on_damage_taken": "damage_taken", "timed": "elapsed_seconds",
}
const EFFECT_READS := {
	"damage_reduction": ["damage_taken"], "heal_back": ["damage_taken", "max_hp"],
	"brace": ["damage_taken", "impact_force"], "floor_hp": ["hp", "max_hp"],
	"hp_per_mass": ["mass", "max_hp"], "price_scale": ["cogs_price"],
	"speed": ["planar_speed"], "dash": ["planar_speed"], "air_jump": ["air_jumps"],
	"ballast": ["mass", "ram_damage"], "rebound_strike": ["weapon_damage"],
	"extra_hit": ["hit_damage", "proc_coefficient"], "last_word": ["hp", "max_hp", "hit_damage"],
	"arm_hit": ["hit_damage"], "pin_bonus": ["pin_damage"], "pin_chain": ["pin_count"],
	"rebound_crit": ["rebound_count", "hit_damage"], "relaunch_pin": ["pin_speed"],
	"return_arc": ["damage_taken", "target_distance"], "bonus_scrap": ["kill_scrap"],
	"scrap_burst": ["scrap_mass", "target_distance"], "echo_release": ["release_damage"],
	"overcharge": ["release_damage", "ability_charges"], "cloak_extend": ["cloak_seconds"],
	"domino": ["pin_speed", "target_distance"], "drone": ["magnet_reach"],
	"ping": ["target_distance"], "perk": ["discovery_state"],
	"zap": ["proc_coefficient", "target_distance"], "burst": ["proc_coefficient", "target_distance"],
}


# The cat_ glyph a row gets from its family when it names none (I2: weapon is damage,
# pattern is transform, stat is defense).
const ICON_FOR_FAMILY := {"weapon": "damage", "pattern": "transform", "mobility": "mobility", "stat": "defense",
	"class": "charge", "milestone": "transform", "utility": "utility", "charge": "charge"}


static func from_row(row_id: String, row: Dictionary) -> Resource:
	var def: Resource = load("res://src/build/part_def.gd").new()
	def.id = row_id
	def.display_name = row.get("name", row_id)
	def.text = row.get("text", "")
	def.verb = row.get("verb", "")
	def.punch = row.get("punch", 0.0)
	def.tags = row.get("tags", [])
	def.rarity = row.get("rarity", "common")
	def.tier = row.get("tier", 1)
	def.family = row.get("family", "stat")
	def.class_id = row.get("class_id", "")
	def.maker = row.get("maker", "")
	def.milestone_only = row.get("milestone_only", false)
	def.mods = row.get("mods", {})
	def.cooldown_scale = row.get("cooldown_scale", 1.0)
	def.patterns = row.get("patterns", {})
	def.elements = row.get("elements", {})
	def.magnet = row.get("magnet", 1.0)
	def.kill_scrap = row.get("kill_scrap", 1.0)
	def.max_hp_bonus = row.get("max_hp_bonus", 0.0)
	def.trigger = row.get("trigger", "")
	def.proc_coeff = row.get("proc", 1.0)
	def.stack_rule = row.get("stack", "linear")
	def.stack_cap = row.get("cap", 0.0)
	def.icon_category = row.get("icon", ICON_FOR_FAMILY.get(def.family, "utility"))
	def.element = row.get("element", "")
	def.effect = row.get("effect", {})
	def.charges = row.get("charges", {})
	def.needs = row.get("needs", "")
	def.shop_only = row.get("shop_only", false)
	def.reads = row.get("reads", def._read_stats())
	def.bits = ShotBits.part_mask(def.tags, row.get("bits"))
	def.stat_touches = def._stat_touches()
	def.levels = row.get("levels", [])
	var player_global: bool = def.max_hp_bonus != 0.0 or not def.effect.is_empty() \
		or not def.charges.is_empty() or def.trigger != "" or def.magnet != 1.0 \
		or def.cooldown_scale != 1.0 or def.kill_scrap != 1.0 or row.has("relay")
	for key in def.mods:
		if not key in WEAPON_MODS:
			player_global = true
	for action in def.elements:
		if action != "shot":
			player_global = true
	def.layer = row.get("layer", "global" if player_global else "local")
	return def


func _read_stats() -> Array:
	var out: Array = mods.keys()
	if punch != 0.0 or not patterns.is_empty():
		out.append("weapon_damage")
	if cooldown_scale != 1.0:
		out.append("movement_cooldown")
	if magnet != 1.0:
		out.append("magnet_reach")
	if kill_scrap != 1.0:
		out.append("kill_scrap")
	if max_hp_bonus != 0.0:
		out.append("max_hp")
	for slot in charges:
		out.append(slot + "_charges")
	for action in elements:
		out.append(action + "_element")
	if TRIGGER_READS.has(trigger):
		out.append(TRIGGER_READS[trigger])
	var effect_id: String = effect.get("do", "")
	out.append_array(EFFECT_READS.get(effect_id, []))
	if effect_id in ["grant_charge", "slot_cooldown"]:
		out.append(String(effect.get("slot", "special")) + ("_charges" if effect_id == "grant_charge" else "_cooldown"))
	if effect_id in ["vault_charges", "vault_cooldown"]:
		out.append(effect_id)
	if out.is_empty():
		out.append("part_count")
	var unique: Array = []
	for stat in out:
		if not stat in unique:
			unique.append(stat)
	return unique


# The sheet categories build_sheet.gd folds this part into. synergy covers the maker counts
# (the tricks a maker wakes) and the evolutions a part feeds or completes.
func _stat_touches() -> Array:
	var out: Array = []
	if not mods.is_empty():
		out.append("mods")
	if cooldown_scale != 1.0:
		out.append("cooldown")
	if not patterns.is_empty():
		out.append("patterns")
	if not elements.is_empty():
		out.append("elements")
	if magnet != 1.0:
		out.append("magnet")
	if kill_scrap != 1.0:
		out.append("kill_scrap")
	if max_hp_bonus != 0.0:
		out.append("max_hp")
	if punch != 0.0:
		out.append("punch")
	if _in_synergy_rows():
		out.append("synergy")
	return out


func _in_synergy_rows() -> bool:
	return maker != "" or Synergies.in_evolution(id)


# True when the part only scales numbers: no punch, pattern, element or behaviour. Only
# a common part may be this plain (DEMO-SPEC catalogue rule).
func percentage_only() -> bool:
	return punch <= 0.0 and patterns.is_empty() and elements.is_empty() and magnet == 1.0 and kill_scrap == 1.0 \
		and max_hp_bonus == 0.0 and trigger == "" and effect.is_empty() and charges.is_empty()


# A gate pair must hold at least one part that raises punch or transforms a pattern.
func hits_harder() -> bool:
	return punch > 0.0 or not patterns.is_empty()


# Copies of this part to the value its stack rule gives: linear adds per copy,
# hyperbolic approaches 1 and never reaches it, capped stops at stack_cap.
func stacked(per_copy: float, copies: int) -> float:
	return Stacking.value(stack_rule, per_copy, copies, stack_cap)


# The pool rule for the spike family: no spike row capped above SPIKE_MAX_MULTIPLE, and
# at most SPIKES_PER_TIER spike rows per tier. Returns one line per problem; [] is clean.
static func spike_problems(defs: Array) -> Array:
	var out: Array = []
	var per_tier := {}
	for d in defs:
		if d == null or d.stack_rule != "spike":
			continue
		if d.stack_cap > SPIKE_MAX_MULTIPLE:
			out.append("%s spike cap %sx over %sx" % [d.id, d.stack_cap, SPIKE_MAX_MULTIPLE])
		per_tier[d.tier] = per_tier.get(d.tier, []) + [d.id]
	for tier in per_tier:
		if per_tier[tier].size() > SPIKES_PER_TIER:
			out.append("tier %d holds %d spike parts %s" % [tier, per_tier[tier].size(), per_tier[tier]])
	return out


# The four stacking curves as one pure function, so the catalogue, the sheet and the
# fuzzer all read the same numbers. For linear and capped rows stack_cap counts copies
# (0 means no ceiling on a linear row); for a hyperbolic row it is the value ceiling,
# below 1, that the curve may never pass; for a spike row it is a multiple of one copy,
# and 0 or anything above SPIKE_MAX_MULTIPLE reads as SPIKE_MAX_MULTIPLE, so no spike
# is ever uncapped.
class Stacking:
	static func value(rule: String, per_copy: float, copies: int, cap: float) -> float:
		if copies <= 0:
			return 0.0
		if rule == "spike":
			var ceiling := SPIKE_MAX_MULTIPLE if cap < 1.0 or cap > SPIKE_MAX_MULTIPLE else cap
			var multiple := pow(SPIKE_GROWTH, mini(copies, 16)) - 1.0
			return per_copy * minf(multiple, ceiling)
		if rule == "hyperbolic":
			var v := 1.0 - 1.0 / (1.0 + per_copy * copies)
			return minf(v, cap) if cap > 0.0 else v
		var counted := mini(copies, int(cap)) if cap >= 1.0 else copies
		return per_copy * counted
