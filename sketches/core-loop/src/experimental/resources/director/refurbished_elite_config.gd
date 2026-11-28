extends Resource

const EnvTags := preload("res://src/experimental/env_tags.gd")

@export var id: StringName = &""
@export var display_name: String = ""
@export var maker: StringName = &"fleet"
@export var requisition_code: String = ""
@export var chassis: StringName = &"plated_brute"
@export var credit_cost: float = 18.0
@export var min_tier: int = 1

@export var base_hull_hp: float = 100.0
@export var plate_count: int = 2
@export var plate_integrity: float = 35.0
@export var plate_weak_tags: Array = []

@export var silhouette_cue: String = ""
@export var movement_cadence: String = ""
@export var counterplay_cue: String = ""
@export var third_person_read_distance_m: float = 42.0
@export var telegraph_kind: StringName = &"instant"
@export var tell_s: float = 0.85
@export var execute_s: float = 0.7
@export var cooldown_s: float = 3.5
@export var stagger_on_brace_break_s: float = 2.0
@export var card_line: String = ""

@export var ability_tag: StringName = &"slag_coated"
@export var secondary_tag: StringName = &""
@export var ability_radius_m: float = 8.0
@export var ability_intensity: float = 0.9
@export var ability_ttl_s: float = 3.5
@export var shatter_tag: StringName = &"slag_coated"
@export var shatter_radius_m: float = 5.0
@export var shatter_ttl_s: float = 3.0

@export var backfires_on_strip: bool = false
@export var pull_accel: float = 0.0
@export var slingshot_bonus: float = 1.0
@export var aura_pack_rest_scale: float = 1.0

@export var biome_weights: Dictionary = {}
@export var bounty: Dictionary = {}


func to_spec_dict() -> Dictionary:
	var spec := {
		"id": id,
		"display_name": display_name,
		"maker": maker,
		"requisition_code": requisition_code,
		"chassis": chassis,
		"credit_cost": credit_cost,
		"min_tier": min_tier,
		"base_hull_hp": base_hull_hp,
		"plate_count": plate_count,
		"plate_integrity": plate_integrity,
		"plate_weak_tags": plate_weak_tags.duplicate(),
		"silhouette_cue": silhouette_cue,
		"movement_cadence": movement_cadence,
		"counterplay_cue": counterplay_cue,
		"third_person_read_distance_m": third_person_read_distance_m,
		"telegraph_kind": telegraph_kind,
		"tell_s": maxf(EnvTags.MIN_TELL_S, tell_s),
		"execute_s": execute_s,
		"cooldown_s": cooldown_s,
		"stagger_on_brace_break_s": stagger_on_brace_break_s,
		"card_line": card_line,
		"ability_tag": ability_tag,
		"ability_radius_m": ability_radius_m,
		"ability_intensity": ability_intensity,
		"ability_ttl_s": ability_ttl_s,
		"shatter_tag": shatter_tag,
		"shatter_radius_m": shatter_radius_m,
		"shatter_ttl_s": shatter_ttl_s,
		"backfires_on_strip": backfires_on_strip,
		"pull_accel": pull_accel,
		"slingshot_bonus": slingshot_bonus,
		"aura_pack_rest_scale": aura_pack_rest_scale,
		"biome_weights": biome_weights.duplicate(true),
		"bounty": bounty.duplicate(true),
	}
	if secondary_tag != &"":
		spec["secondary_tag"] = secondary_tag
	return spec
