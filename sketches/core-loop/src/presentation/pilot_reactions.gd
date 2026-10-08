extends RefCounted

# Explicit event policy: every key is a GameEvents signal.
# Cooldowns are shared by resolved clip, including per-class overrides.
const ROWS := {
	"boss_defeated": {"clip": "big_cheer", "priority": 80, "cooldown": 4.0},
	"stage_cleared": {"clip": "big_cheer", "priority": 80, "cooldown": 4.0},
	"player_hit": {"clip": "wince", "priority": 60, "cooldown": 0.8},
	"harpoon_bit": {"clip": "brace", "priority": 35, "cooldown": 1.5},
	"harpoon_smashed": {"clip": "heave", "priority": 50, "cooldown": 1.0},
	"player_died": {"clip": "slump", "priority": 100, "cooldown": 2.0},
	"near_miss": {"clip": "phew", "priority": 20, "cooldown": 4.0},
	"part_gained": {"clip": "big_cheer", "priority": 30, "cooldown": 12.0},
	"hold_broken": {"clip": "phew", "priority": 20, "cooldown": 4.0},
	"missed_drop": {"clip": "wince", "priority": 40, "cooldown": 3.0},
	"evolution_fired": {"clip": "big_cheer", "priority": 80, "cooldown": 4.0},
	"drop_landed": {"clip": "drop_land", "priority": 30, "cooldown": 1.5},
}


static func clip_for(row: Dictionary, pilot_class: String) -> String:
	return row.get("class_clips", {}).get(pilot_class, row.clip)
