extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

const JUICE := {
	"enemy_struck": {"stop_ms": 10.0, "stop_per_damage": 0.4, "stop_min_ms": 12.0, "stop_cap_ms": 40.0,
		"crit": {"stop_mult": 1.4, "shake": 0.22, "color": Palette.BRASS, "sound": "crit_ping",
			"fx": {"crit_core": 24, "crit_halo": 24}},
		"heavy": {"stop_add_ms": 10.0, "kick": 0.45, "dust": 12}, "fx": {"spark_core": 16, "spark_halo": 16}},
	"enemy_rebounded": {"kick": 0.55, "shake": 0.35, "dust": 14},
	"enemy_killed": {"debris": 10, "fx": {"kill_shards": 16}, "chain_ms": 1500, "chain_cap": 7, "multi_ms": 90, "multi_stop_ms": 30.0, "pips": 8},
	"scrap_collected": {"chain_ms": 1000, "chain_cap": 9, "pulse": 0.05, "pulse_cap": 0.16},
	"armor_reclaim": {"chain_ms": 900, "chain_cap": 7},
	"part_gained": {"fountain": 18, "element": {"frost": Palette.ANCIENT, "arc": Palette.ARC, "kinetic": Palette.SAND}},
	"core_gained": {"fountain": 24},
	"shot_fired": {"weapons": {"rapid_laser": {"kick": 0.05, "recoil": 0.04}, "arc_caster": {"kick": 0.12, "recoil": 0.08},
			"pylon_turret": {"kick": 0.08, "recoil": 0.0}, "sticky_charge": {"kick": 0.16, "recoil": 0.12},
			"claw_sweep": {"kick": 0.14, "recoil": 0.10},
			"gather_plate": {"kick": 0.06, "recoil": 0.04}, "link_clips": {"kick": 0.07, "recoil": 0.05},
			"balance_due": {"kick": 0.10, "recoil": 0.08}, "cannon_lane": {"kick": 0.2, "recoil": 0.14}},
		"throw": {"sound": "dash_whoosh", "pitch": 1.5, "db": -4.0}, "stick": {"sound": "grapple_clink", "pitch": 0.7}},
	"sticky_detonated": {"punch_fov": 3.0, "punch_per_enemy": 1.5, "punch_cap": 10.0, "debris": 12, "dust": 14, "shake": 0.35,
		"near_m": 6.0, "near_kick": 0.6},
	"rocket_jumped": {"kick": 0.8, "punch_fov": 8.0, "squash": 0.35},
	"near_miss": {"punch_fov": -5.0, "grace_ms": EventKinds.NEAR_MISS_GRACE_MS},
	"player_hit": {"edge_s": 0.4, "edge_alpha": 0.65, "squash": 0.18, "color": Palette.HAZARD},
	"scrap_lost": {"pulse": -0.22},
	"beacon_unsealed": {"punch_fov": 9.0},
	"quick_break": {"fountain": 28, "rise": 7.0},
	"rolling": {"fx": {"roll_dust": 90}, "min_speed": 9.0},
	"slammed": {"fx": {"slam_ring": 48, "slam_dust": 24}},
	"harpoon_bit": {"fx": {"latch_ring": 24, "latch_halo": 24, "latch_pulse": 12}},
	"wall_crumbled": {"fx": {"crack_debris": 28, "slam_dust": 14}},
	"prop_kicked": {"fly": {"sound": "land_thud", "metal": "clank", "pitch": [1.5, 1.15], "db": -9.0, "dust": 8},
		"shove": {"sound": "land_thud", "metal": "clank", "pitch": [0.95, 0.75], "db": -7.0, "dust": 10},
		"bend": {"sound": "", "metal": "", "pitch": [1.0, 1.0], "db": 0.0, "dust": 4}},
	"bumped": {"min_speed": 9.0, "full_speed": 30.0, "squash": 0.34, "kick": 0.45, "shake": 0.3, "shake_from": 0.5,
		"db": [-10.0, 1.0], "pitch": [1.2, 0.8], "fx": {"slam_dust": 18, "crack_debris": 12}},
	"enemy_walled": {"min_speed": 8.0, "full_speed": 30.0, "shake": 0.14, "near_m": 14.0,
		"db": [-12.0, -2.0], "pitch": [1.05, 0.75], "fx": {"slam_dust": 12, "crack_debris": 8}},
	"sticky_stuck": {"fx": {"spark_core": 8, "spark_halo": 8}},
	"breach_opened": {"fx": {"dig_debris": 10, "dig_dust": 12}, "low": {"dig_debris": 4, "dig_dust": 5}},
	"cache_spent": {"fx": {"cache_ember": 24, "cache_wisp": 6}},
	"net_caught": {"fx": {"net_dust": 14}},
	"thermal_ride": {"motes": [9, 27], "streaks": [6, 18]},
}

const STOP_GAP_MS := 90
const STOP_WINDOW_MS := 300
const STOP_WINDOW_BUDGET_MS := 60.0
const STOP_BUDGET_MS := 100.0
const STOP_PER_EXTRA_HIT_MS := 2.0
const SPINE_CAP_MS := 60.0

static func juice(kind: String) -> Dictionary:
	return JUICE.get(kind, {})


static func stop_ms_for(damage: float, crit := false, heavy := false) -> float:
	var row := juice("enemy_struck")
	var ms := clampf(float(row["stop_ms"]) + float(row["stop_per_damage"]) * maxf(damage, 0.0), float(row["stop_min_ms"]), float(row["stop_cap_ms"]))
	if crit:
		ms *= float(row["crit"]["stop_mult"])
	if heavy:
		ms += float(row["heavy"]["stop_add_ms"])
	return minf(ms, SPINE_CAP_MS)
