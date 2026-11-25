extends RefCounted

const ROWS := {
	"boss_defeated": {"clip": "big_cheer", "priority": 80, "cooldown": 4.0, "blend": 0.08},
	"stage_cleared": {"clip": "big_cheer", "priority": 80, "cooldown": 4.0, "blend": 0.08},
	"player_hit": {"clip": "wince", "priority": 60, "cooldown": 0.8},
	"harpoon_bit": {"clip": "brace", "priority": 35, "cooldown": 1.5},
	"harpoon_smashed": {"clip": "heave", "priority": 50, "cooldown": 1.0},
	"player_died": {"clip": "slump", "priority": 100, "cooldown": 2.0},
	"near_miss": {"clip": "phew", "priority": 20, "cooldown": 4.0, "blend": 0.08},
	"part_gained": {"clip": "big_cheer", "priority": 30, "cooldown": 12.0, "blend": 0.08},
	"hold_broken": {"clip": "phew", "priority": 20, "cooldown": 4.0, "blend": 0.08},
	"missed_drop": {"clip": "wince", "priority": 40, "cooldown": 3.0},
	"evolution_fired": {"clip": "big_cheer", "priority": 80, "cooldown": 4.0, "blend": 0.08},
	"drop_landed": {"clip": "drop_land", "priority": 30, "cooldown": 1.5, "queue": 1.0},
	"slammed": {"clip": "smash", "priority": 36, "cooldown": 1.0},
	"ultimate_ready": {"clip": "ult_ready", "priority": 28, "cooldown": 10.0, "blend": 0.08, "queue": 1.0},
	"ultimate_started": {"clip": "ult_windup", "priority": 70, "cooldown": 0.0},
	"ultimate_peak": {"clip": "ult_strike", "priority": 68, "cooldown": 0.0, "blend": 0.05},
	"ultimate_landed": {"clip": "ult_recover", "priority": 69, "cooldown": 0.0},
	"ultimate_cancelled": {"clip": "ult_recover", "priority": 72, "cooldown": 0.0},
	"slot_cast": {"clip": "cast_special", "priority": 30, "cooldown": 1.0, "arg": [0, "special"]},
	"line_skill_fired": {"clip": "cast_line", "priority": 32, "cooldown": 1.0},
	"heft_class_changed": {"clip": "class_up", "priority": 50, "cooldown": 4.0, "blend": 0.08},
}

const BASES := {
	"idle": {"clip": "idle_loop", "priority": -1},
	"flight": {"clip": "ult_ride_loop", "priority": 64},
}
const BASE_BLEND := 0.1


static func seat_idle(animator: AnimationPlayer, pilot: Node) -> String:
	if animator == null or pilot == null:
		return ""
	var idle: String = BASES.idle.clip
	if animator.has_animation(idle):
		if animator.current_animation != idle or not animator.is_playing():
			animator.play(idle, BASE_BLEND if animator.is_playing() else 0.0)
			animator.advance(0.0)
		return idle
	animator.stop()
	for skeleton in pilot.find_children("*", "Skeleton3D", true, false):
		skeleton.reset_bone_poses()
	return ""
const RIDE_PHASES := ["windup", "flight"]
const ENDS_ON_RIDE := ["ult_windup", "ult_strike", "ult_ride_loop"]
const RECOVER := {"clip": "ult_recover", "priority": 69}
const UNLOCK := "unlock"


static func clip_for(row: Dictionary, pilot_class: String) -> String:
	return row.get("class_clips", {}).get(pilot_class, row.clip)


static func signal_of(row_id: String) -> String:
	return String(ROWS.get(row_id, {}).get("signal", row_id))


static func rows_for(event: String) -> Array:
	var ids: Array = []
	for row_id in ROWS:
		if signal_of(row_id) == event:
			ids.append(row_id)
	return ids


static func arg_matches(row: Dictionary, args: Array) -> bool:
	if not row.has("arg"):
		return true
	var index := int(row.arg[0])
	return args.size() > index and args[index] == row.arg[1]
