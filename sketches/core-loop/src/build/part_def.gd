extends Resource

const ShotBits := preload("res://src/build/shot_bits.gd")
const Synergies := preload("res://src/build/synergies.gd")


const RARITIES := ["common", "rare", "relic", "evolved"]
const TAGS := ["frost", "arc", "kinetic", "split", "spiral", "chain", "anchor", "speed", "mass"]

@export var id := ""
@export var display_name := ""
@export var text := ""
@export var verb := ""
@export var punch := 0.0
@export var tags: Array = []
@export var rarity := "common"
@export var tier := 1
@export var family := "stat"
@export var class_id := ""
@export var maker := ""
@export var milestone_only := false
@export var mods := {}
@export var cooldown_scale := 1.0
@export var patterns := {}
@export var elements := {}
@export var magnet := 1.0
@export var kill_scrap := 1.0
@export var max_hp_bonus := 0.0

const STACK_RULES := ["linear", "hyperbolic", "capped", "spike"]
const WEAPON_MODS := ["weapon_damage", "weapon_rate", "weapon_range", "turret_damage"]
const SPIKE_MAX_MULTIPLE := 8.0
const SPIKE_GROWTH := 2.0
const SPIKES_PER_TIER := 1
const STAT_CATEGORIES := ["mods", "cooldown", "patterns", "elements", "magnet", "kill_scrap", "max_hp", "punch", "synergy"]
const ICON_CATEGORIES :=["damage", "mobility", "defense", "utility", "charge", "transform"]
@export var trigger := ""
@export var proc_coeff := 1.0
@export var stack_rule := "linear"
@export var stack_cap := 0.0
@export var icon_category := ""
@export var element := ""
@export var effect := {}
@export var charges := {}
@export var needs := ""
@export var shop_only := false
@export var layer := "global"
@export var reads: Array = []
@export var bits := 0
@export var stat_touches: Array = []
const MAX_LEVEL := 3
const LEVEL_KEYS := ["punch", "mods", "max_hp_bonus", "magnet", "kill_scrap", "cooldown_scale", "text"]
@export var levels: Array = []
@export var level := 1

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


func percentage_only() -> bool:
	return punch <= 0.0 and patterns.is_empty() and elements.is_empty() and magnet == 1.0 and kill_scrap == 1.0 \
		and max_hp_bonus == 0.0 and trigger == "" and effect.is_empty() and charges.is_empty()


func hits_harder() -> bool:
	return punch > 0.0 or not patterns.is_empty()


func changes_behaviour() -> bool:
	return trigger != "" or not patterns.is_empty() or not elements.is_empty()


func stacked(per_copy: float, copies: int) -> float:
	return Stacking.value(stack_rule, per_copy, copies, stack_cap)


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


class Stacking:
	static func value(rule: String, per_copy: float, copies: int, cap: float) -> float:
		assert(rule in ["linear", "hyperbolic", "capped", "spike"], "unknown stack rule: %s" % rule)
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
