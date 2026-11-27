extends Resource


@export var profile_id: StringName = &"spillway_default"
@export var default_biome_id: StringName = &""
@export var default_cruise_mps: float = 14.0
@export var tier_interval_s: float = 45.0
@export var max_clock_tier: int = 5
@export var base_income_per_s: float = 2.4
@export var tier_income_step: float = 0.55
@export var stall_income_max_bonus: float = 0.85
@export var setpiece_spike_credits: float = 12.0

@export var stall_speed_ratio: float = 0.55
@export var fast_speed_ratio: float = 0.85
@export var camp_radius_m: float = 8.5
@export var stall_rise_per_s: float = 0.28
@export var stall_decay_per_s: float = 0.45
@export var flow_rise_per_s: float = 0.30
@export var flow_decay_per_s: float = 0.25

@export var alive_cap: int = 18
@export var credit_pool_cap: float = 48.0
@export var max_active_elites: int = 2
@export var elite_min_cooldown_s: float = 18.0
@export var hazard_cooldown_s: float = 16.0
@export var slag_hold_cap_s: float = 2.0

@export var enemy_roles: Dictionary = {}
@export var fleet_packs: Array = []
@export var elite_pool: Array = []
@export var hazard_configs: Dictionary = {}
@export var foreman_tier_memos: Array = []
