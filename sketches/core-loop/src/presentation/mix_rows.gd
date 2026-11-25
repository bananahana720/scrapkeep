extends RefCounted

const BUS_DB := {"Music": -1.0, "SFX": -6.0, "UI": -8.0, "Ambient": -7.0}

const SFX_COMP := {"threshold_db": -16.0, "ratio": 3.0, "attack_us": 3000.0, "release_ms": 120.0, "gain_db": 0.0}
const SFX_CEILING_DB := -2.0
const MASTER_COMP := {"threshold_db": -14.0, "ratio": 2.5, "attack_us": 8000.0, "release_ms": 200.0, "gain_db": 0.0}
const MASTER_CEILING_DB := -1.5

const STATES := {
	"menu": {"Music": -6.0, "Ambient": -14.0},
	"camp": {"Music": -8.0, "Ambient": -6.0},
	"roam": {"Music": -5.0},
	"combat": {"Music": -1.5, "Ambient": -5.0},
	"shop": {"Music": -8.0, "Ambient": -6.0},
	"miniboss": {"Ambient": -10.0},
	"boss_1": {"Music": -1.0, "Ambient": -14.0},
	"boss_2": {"Music": -0.5, "Ambient": -14.0},
	"boss_3": {"Ambient": -16.0},
	"run_over": {"Music": -7.0, "Ambient": -16.0},
}
const COMBAT_ON := 0.4
const COMBAT_OFF := 0.25


static func combat_after(was: bool, pressure: float) -> bool:
	if pressure >= COMBAT_ON:
		return true
	if pressure <= COMBAT_OFF:
		return false
	return was
const GLIDE_DOWN_DB_S := 30.0
const GLIDE_UP_DB_S := 6.0

const FOCUS := {"Music": -2.0, "Ambient": -8.0, "hold_s": 0.4}

const DROP_ROOM := {"duck": {"SFX": -5.0}, "lift": {"Music": 3.0}}
const DROP_ROOM_BARS := 2
const DROP_ROOM_LEAD_S := 0.1

const MAKE_ROOM := {"hurt": {"db": -10.0, "hold_s": 0.35},
	"near_whoosh": {"db": -8.0, "hold_s": 0.3, "only": ["threat_tear"]}}


static func room_db(room_for: String, sound: String, warning: bool, sounding := true) -> float:
	if sound == room_for or not MAKE_ROOM.has(room_for):
		return 0.0
	if MAKE_ROOM[room_for].has("only"):
		return float(MAKE_ROOM[room_for]["db"]) if sounding and sound in MAKE_ROOM[room_for]["only"] else 0.0
	if warning:
		return 0.0
	return float(MAKE_ROOM[room_for]["db"])

const CROWD_SOUNDS := ["weapon_zap", "hit_thwack", "clank", "scrap_tick", "cog_tick", "kill_pop", "crit_ping", "shatter",
	"dash_whoosh", "near_whoosh", "kest_kick_thump", "rarity_tick", "panel_note", "shell_spring", "land_thud", "hop",
	"pin_double_thwack", "rebound_spring_snap", "kest_snare_crack", "cracked_wall_crumble"]
const CROWD_FREE := 6
const CROWD_DB_PER_DOUBLING := 3.0
const CROWD_FLOOR_DB := -9.0

const VOICE_DEFAULT := 3
const VOICE_LIMIT := {"weapon_zap": 3, "scrap_tick": 3, "cog_tick": 3, "hit_thwack": 3, "kill_pop": 3, "enemy_arrive": 2, "beacon_hum": 1, "sluice_siren_two_tone": 1, "steam_whistle_rise": 1, "ride_cable_clink": 2, "ride_rolling_metal": 1,
	"hop": 2, "land_thud": 2, "hurt": 2, "babble": 1, "rarity_tick": 2, "panel_note": 3, "clank": 2, "grapple_clink": 2,
	"swarm_buzz": 2, "kill_chain_tier": 1, "achievement_chime": 1, "rescue_fanfare": 1,
	"menu_move": 2, "menu_confirm": 1, "menu_back": 1, "verb_fail": 1, "gauge_dry_click": 1, "marble_tick_ladder": 3,
	"drop_thud": 1, "drop_whiff": 1, "guard_creak": 1, "beacon_open_chime": 1, "callout_warden_chime": 1,
	"motif_accumulate": 1, "pin_double_thwack": 2,
	"motif_accumulate_sable": 1, "motif_accumulate_rivet": 1, "motif_accumulate_kest": 1, "motif_accumulate_tarn": 1,
	"motif_accumulate_tally": 1, "motif_accumulate_cannon": 1,
	"kindness_chime": 1, "quick_sync_horn": 1, "shift_over_sigh": 1}
const MIN_GAP_MS := {"weapon_zap": 55, "scrap_tick": 40, "cog_tick": 40, "enemy_arrive": 200, "hit_thwack": 35, "land_thud": 80, "kill_pop": 45,
	"hurt": 90, "hop": 40, "mind_sable": 600, "mind_rivet": 600, "mind_kest": 600, "mind_tarn": 600, "mind_tally": 600, "mind_cannon": 600,
	"grapple_clink": 60, "ride_cable_clink": 60, "ride_rolling_metal": 250, "ride_hop_lift": 60, "ride_ledge_scuff": 60, "line_bite": 60, "slam_boom": 60, "core_slam": 60,
	"grown_sub": 60, "grown_crack": 60, "grown_tail": 120, "grown_rattle": 120,
	"achievement_chime": 400, "rescue_fanfare": 400, "clank": 90, "rarity_tick": 45,
	"menu_move": 45, "menu_confirm": 90, "menu_back": 90, "verb_fail": 150, "gauge_dry_click": 120, "marble_tick_ladder": 60,
	"drop_thud": 120, "drop_whiff": 200, "guard_creak": 700, "beacon_open_chime": 400, "callout_warden_chime": 300,
	"flood_drop": 60, "fleet_anvil_brass_drop": 60, "lightning_strike": 60, "rockfall_boom": 60, "crater_crump_sub_boom": 60,
	"steam_whistle_percussion_drop": 60, "ancient_family_drop": 60, "motif_line": 60, "pin_double_thwack": 90,
	"motif_line_sable": 60, "motif_line_rivet": 60, "motif_line_kest": 60, "motif_line_tarn": 60, "motif_line_tally": 60, "motif_line_cannon": 60,
	"sluice_valve_open": 60, "kindness_chime": 400, "quick_sync_horn": 200, "shift_over_sigh": 250}

const MENU_FLOWS := ["title", "class_select"]
const OVER_FLOWS := ["summary", "dead", "victory"]
const FIGHT_TRACKS := ["miniboss", "warden"]


static func resolve(flow: String, camp_open: bool, track: String, boss_phase: int, shop: bool, combat: bool) -> String:
	if flow in MENU_FLOWS or flow == "":
		return "camp" if camp_open else "menu"
	if flow in OVER_FLOWS:
		return "run_over"
	if flow == "boss":
		return "boss_%d" % clampi(boss_phase, 1, 3)
	if track in FIGHT_TRACKS:
		return "miniboss"
	if shop:
		return "shop"
	return "combat" if combat else "roam"


static func state_db(state: String, bus: String) -> float:
	return float(STATES.get(state, {}).get(bus, 0.0))


static func crowd_db(live: int, priority: int) -> float:
	if priority >= 2 or live <= CROWD_FREE:
		return 0.0
	return maxf(CROWD_FLOOR_DB, -CROWD_DB_PER_DOUBLING * log(float(live) / CROWD_FREE) / log(2.0))


static func glide(now: float, want: float, delta: float, fast := false) -> float:
	if want < now or fast:
		if want > now:
			return minf(want, now + GLIDE_DOWN_DB_S * delta)
		return maxf(want, now - GLIDE_DOWN_DB_S * delta)
	return minf(want, now + GLIDE_UP_DB_S * delta)
