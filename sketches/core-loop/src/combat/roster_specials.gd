extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")

# The kill-first specials (design-v3/ENEMY-PRIORITY.md section 4): each one makes its pack worse
# while it stands, so finding it and reaching it first is the read. Rows in roster.gd's shape plus
# "script" and "world" (the first world it fights in), declared like roster_dig.gd's. Each owns
# its tell sound and picture through the specials contract (design-v3/MACHINE-VFX.md), so its
# roster tag stays empty.
const ROWS := {
	"foreman": {"faction": "fleet", "role": "kill_first", "mechanic": "shift_wipe", "telegraph": -1, "holds": false,
		"breaks": [], "tag": "", "tests": "plating", "script": "res://src/combat/foreman.gd", "world": 1,
		"line": "Never attacks: it horns every 5 s and its crew's cracked plating closes up; kill it first and the crew clocks out."},
}
