extends Resource


const EnvTags := preload("res://src/experimental/env_tags.gd")

enum Slot { WEAPON, DASH_LINE, CORE_HUSK }

const SLOT_NAMES := {
	Slot.WEAPON: &"weapon",
	Slot.DASH_LINE: &"dash_line",
	Slot.CORE_HUSK: &"core_husk",
}

const VALID_MAKERS: Array[StringName] = [
	&"spillway_works",
	&"fleet_surplus",
	&"redjaw",
	&"highdraft_roosts",
	&"waking",
	&"mind_glass",
	&"moss",
]

const VALID_RARITIES: Array[StringName] = [
	&"field_kit",
	&"fleet_grade",
	&"relic",
	&"jury_rigged",
]

const TRIG_ON_DASH: StringName = &"on_dash"
const TRIG_ON_HARPOON_SNAP: StringName = &"on_harpoon_snap"
const TRIG_ON_SCRAP_PICKUP: StringName = &"on_scrap_pickup"
const TRIG_ON_OVERHEAT: StringName = &"on_overheat"
const TRIG_ON_PROP_RUPTURE: StringName = &"on_prop_rupture"
const TRIG_ON_WEAPON_FIRE: StringName = &"on_weapon_fire"
const TRIG_ON_SLAM: StringName = &"on_slam"
const TRIG_ON_TAG_REACTION: StringName = &"on_tag_reaction"

const VALID_TRIGGERS: Array[StringName] = [
	TRIG_ON_DASH,
	TRIG_ON_HARPOON_SNAP,
	TRIG_ON_SCRAP_PICKUP,
	TRIG_ON_OVERHEAT,
	TRIG_ON_PROP_RUPTURE,
	TRIG_ON_WEAPON_FIRE,
	TRIG_ON_SLAM,
	TRIG_ON_TAG_REACTION,
]

@export var id: StringName = &""
@export var display_name: String = ""
@export var maker: StringName = &"moss"
@export var slot: int = Slot.WEAPON
@export var rarity: StringName = &"jury_rigged"
@export var trigger: StringName = TRIG_ON_DASH
@export var emits_tags: Array[StringName] = []
@export var consumes_tags: Array[StringName] = []
@export var heat_cost: float = 0.0
@export var effect_id: StringName = &""
@export var params: Dictionary = {}
@export var summary: String = ""
@export var trade_off: String = ""
@export var visual_tell: String = ""
@export var audio_tell: String = ""


static func reset() -> void:
	pass


static func slot_label(slot_value: int) -> StringName:
	return SLOT_NAMES.get(slot_value, &"unknown")


static func is_valid_trigger(trig: StringName) -> bool:
	return VALID_TRIGGERS.has(trig)


func slot_name() -> StringName:
	return slot_label(slot)


func matches_trigger(trig: StringName) -> bool:
	return trigger == trig


func emits_tag(tag: StringName) -> bool:
	return emits_tags.has(tag)


func consumes_tag(tag: StringName) -> bool:
	return consumes_tags.has(tag)


func validate() -> Array[String]:
	var problems: Array[String] = []
	if id == &"":
		problems.append("part id is empty")
	if display_name.strip_edges() == "":
		problems.append("%s: display_name is empty" % String(id))
	if not VALID_MAKERS.has(maker):
		problems.append("%s: unknown maker %s" % [String(id), String(maker)])
	if not SLOT_NAMES.has(slot):
		problems.append("%s: unknown slot %d" % [String(id), slot])
	if not VALID_RARITIES.has(rarity):
		problems.append("%s: unknown rarity %s" % [String(id), String(rarity)])
	if not VALID_TRIGGERS.has(trigger):
		problems.append("%s: unknown trigger %s" % [String(id), String(trigger)])
	if effect_id == &"":
		problems.append("%s: effect_id is empty (stat-stick parts are disallowed)" % String(id))
	for tag in emits_tags:
		if not EnvTags.is_canonical_tag(tag):
			problems.append("%s: emits non-canonical tag %s" % [String(id), String(tag)])
	for tag in consumes_tags:
		if not EnvTags.is_canonical_tag(tag):
			problems.append("%s: consumes non-canonical tag %s" % [String(id), String(tag)])
	if summary.strip_edges() == "":
		problems.append("%s: missing summary" % String(id))
	if trade_off.strip_edges() == "":
		problems.append("%s: missing give-and-take trade_off" % String(id))
	if visual_tell.strip_edges() == "":
		problems.append("%s: missing visual_tell" % String(id))
	if audio_tell.strip_edges() == "":
		problems.append("%s: missing audio_tell" % String(id))
	return problems


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"maker": maker,
		"slot": slot,
		"slot_name": slot_name(),
		"rarity": rarity,
		"trigger": trigger,
		"emits_tags": emits_tags.duplicate(),
		"consumes_tags": consumes_tags.duplicate(),
		"heat_cost": heat_cost,
		"effect_id": effect_id,
		"params": params.duplicate(true),
		"summary": summary,
		"trade_off": trade_off,
		"visual_tell": visual_tell,
		"audio_tell": audio_tell,
	}


static func from_dict(row: Dictionary) -> Resource:
	var part := new()
	part.id = StringName(row.get("id", &""))
	part.display_name = String(row.get("display_name", ""))
	part.maker = StringName(row.get("maker", &"moss"))
	part.slot = int(row.get("slot", Slot.WEAPON))
	part.rarity = StringName(row.get("rarity", &"jury_rigged"))
	part.trigger = StringName(row.get("trigger", TRIG_ON_DASH))
	var em: Array[StringName] = []
	for t in row.get("emits_tags", []):
		em.append(StringName(t))
	part.emits_tags = em
	var co: Array[StringName] = []
	for t in row.get("consumes_tags", []):
		co.append(StringName(t))
	part.consumes_tags = co
	part.heat_cost = float(row.get("heat_cost", 0.0))
	part.effect_id = StringName(row.get("effect_id", &""))
	part.params = (row.get("params", {}) as Dictionary).duplicate(true)
	part.summary = String(row.get("summary", ""))
	part.trade_off = String(row.get("trade_off", ""))
	part.visual_tell = String(row.get("visual_tell", ""))
	part.audio_tell = String(row.get("audio_tell", ""))
	return part
