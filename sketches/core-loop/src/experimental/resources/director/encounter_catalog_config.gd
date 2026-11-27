extends Resource


@export var catalog_id: StringName = &"spillway_encounters"
@export var default_biome_id: StringName = &""
@export var random_cooldown_s: float = 24.0
@export var initial_random_cooldown_s: float = 14.0
@export var min_random_gap_m: float = 28.0
@export var greed_scrap_threshold: int = 120
@export var triggered_specs: Dictionary = {}
@export var random_specs: Dictionary = {}
