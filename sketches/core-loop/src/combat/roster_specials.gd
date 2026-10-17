extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")

# The kill-first specials (design-v3/ENEMY-PRIORITY.md sections 4 and 4a): enemies that make
# the room worse while they live, so the read is the kill order. Rows in roster.gd's shape
# plus "script", the kind's behaviour file, and "priority", how the player should order it.
# A row is declared here before its script exists; Roster.built(kind) turns true the moment
# the file does. No world: the director places specials by its own share, not by world.
const ROWS := {
	"splitter": {"faction": "fleet", "role": "punisher", "mechanic": "split_pop", "telegraph": -1, "holds": false,
		"breaks": ["smash"], "tag": "", "tests": "air", "script": "res://src/combat/splitter.gd", "priority": "kill_first",
		"line": "Chases you and keeps budding fuse pods that run at you and blow up; kill it to stop them, by a smash from above or a shot from 15 m, or a ram pops it into three more."},
	# Spawned by a Splitter, never placed: "spawned" keeps it out of the director's packs.
	"splitter_pod": {"faction": "fleet", "role": "punisher", "mechanic": "fuse_pod", "telegraph": Threat.Type.INSTANT, "holds": false,
		"breaks": ["smash"], "tag": "", "tests": "speed", "script": "res://src/combat/splitter_pod.gd", "priority": "spawned",
		"line": "A torn-off Splitter pod: runs at you, lights a one-second fuse ring and blows up; roll out of the ring."},
}
