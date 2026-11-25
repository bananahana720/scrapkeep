extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")

const ROWS := {
	"dispatcher": {"faction": "fleet", "role": "punisher", "mechanic": "tube_drop", "telegraph": Threat.Type.PROJECTILE, "holds": false,
		"breaks": [], "tag": "", "tests": "air", "script": "res://src/combat/dispatcher.gd", "world": 1,
		"job": "Was the pig launcher that fed the pipes.",
		"line": "Perches 8 m up and fires a chaser down its tube at you every 8 s; go up and break it or the field fills."},
	"foreman": {"faction": "fleet", "role": "kill_first", "mechanic": "shift_wipe", "telegraph": -1, "holds": false,
		"breaks": [], "tag": "", "tests": "plating", "script": "res://src/combat/foreman.gd", "world": 1,
		"name": "Shift Boss", "job": "Was the shift horn that called the patch crews.",
		"line": "Never attacks: it horns every 5 s and its crew's cracked plating closes up; kill it first and the crew clocks out."},
	"splitter": {"faction": "fleet", "role": "punisher", "mechanic": "split_pop", "telegraph": -1, "holds": false,
		"breaks": ["smash"], "tag": "", "tests": "air", "script": "res://src/combat/splitter.gd", "priority": "kill_first",
		"job": "Was a jam breaker that set charges on log jams.",
		"line": "Chases you and keeps budding fuse pods that run at you and blow up; kill it to stop them, by a smash from above or a shot from 15 m, or a ram pops it into three more."},
	"splitter_pod": {"faction": "fleet", "role": "punisher", "mechanic": "fuse_pod", "telegraph": Threat.Type.INSTANT, "holds": false,
		"breaks": ["smash"], "tag": "", "tests": "speed", "script": "res://src/combat/splitter_pod.gd", "priority": "spawned",
		"line": "A torn-off Splitter pod: runs at you, lights a one-second fuse ring and blows up; roll out of the ring."},
}
