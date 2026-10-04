extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")

# World 3, the Highdraft: Fleet crews that work the air and the lines above it. Rows in
# roster.gd's shape plus "script", the kind's behaviour file, and "world". A row is
# declared here before its script exists; Roster.built(kind) turns true the moment the
# file does.
const ROWS := {
	"line_cutter": {"faction": "fleet", "role": "punisher", "mechanic": "line_cut", "telegraph": Threat.Type.PROJECTILE, "holds": false,
		"breaks": ["glide"], "tag": "", "tests": "air", "script": "res://src/combat/line_cutter.gd", "world": 3,
		"line": "Throws a spinning cutter across your air path that severs your line; glide under its arc or land early."},
	"anchor_crew": {"faction": "fleet", "role": "controller", "mechanic": "deck_winch", "telegraph": Threat.Type.LANE, "holds": true,
		"breaks": ["jump"], "tag": "", "tests": "heft", "script": "res://src/combat/anchor_crew.gd", "world": 3,
		"line": "Hooks you down a cable lane and winches you onto its deck; jump to slip the hook before it cinches."},
	"kite_drone": {"faction": "fleet", "role": "punisher", "mechanic": "thermal_dive", "telegraph": Threat.Type.INSTANT, "holds": false,
		"breaks": [], "tag": "", "tests": "weapon", "script": "res://src/combat/kite_drone.gd", "world": 3,
		"line": "Rides the thermals out of reach and dives on the spot it marks; shoot it while it circles or leave the mark."},
}
