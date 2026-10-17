extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")

# The kill-first specials (design-v3/ENEMY-PRIORITY.md sections 4 and 4a): enemies that make
# the room worse while they live, so the read is the kill order. Rows in roster.gd's shape
# plus "script", the kind's behaviour file, and "priority", how the player should order it.
# A row is declared here before its script exists; Roster.built(kind) turns true the moment
# the file does. No world: the director places specials by its own share, not by world.
const ROWS := {
	"splitter": {"faction": "fleet", "role": "punisher", "mechanic": "split_pop", "telegraph": Threat.Type.INSTANT, "holds": false,
		"breaks": ["smash"], "tag": "", "tests": "air", "script": "res://src/combat/splitter.gd", "priority": "kill_first",
		"line": "Crawls in and fuses scrap blasts around itself; ram it and it pops into three, so smash it from above or shoot it from 15 m."},
}
