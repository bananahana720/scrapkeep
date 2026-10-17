extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")

# World 2, the Dig: Fleet crews that work the ground under the ball. Rows in roster.gd's
# shape plus "script", the kind's behaviour file, and "world". A row is declared here
# before its script exists; Roster.built(kind) turns true the moment the file does.
const ROWS := {
	"burrower": {"faction": "fleet", "role": "punisher", "mechanic": "burrow_lane", "telegraph": Threat.Type.INSTANT, "holds": false,
		"breaks": ["speed", "smash"], "tag": "", "tests": "speed", "script": "res://src/combat/burrower.gd", "world": 2,
		"line": "Hunts a slow ball on the floor and bursts up under it; carve the wall or take the air, or slam its marker from above."},
	"drill_crew": {"faction": "fleet", "role": "punisher", "mechanic": "bore_breach", "telegraph": Threat.Type.INSTANT, "holds": false,
		"breaks": ["smash"], "tag": "", "tests": "heft", "script": "res://src/combat/drill_crew.gd", "world": 2,
		"line": "Bores a breach where you will be and the floor caves in; smash the rig mid-bore to stop it."},
	"lamp_swarm": {"faction": "fleet", "role": "controller", "mechanic": "lure_bloom", "telegraph": Threat.Type.WAVE, "holds": false,
		"breaks": ["boost"], "tag": "", "tests": "steer", "script": "res://src/combat/lamp_swarm.gd", "world": 2,
		"line": "Blooms a ring of lure lamps that bends your steering toward the light; boost straight through the wave."},
	# The Spillway catch trap re-homed (design-v3/WORLD-ROSTERS.md): it bites only a ball on the floor.
	"pit_jaw": {"faction": "fleet", "role": "controller", "mechanic": "floor_jaw", "telegraph": Threat.Type.INSTANT, "holds": true,
		"breaks": ["boost", "smash"], "tag": "", "hold": "", "tests": "steer", "script": "res://src/combat/pit_jaw.gd", "world": 2,
		"line": "A jaw in the floor that bites a ball rolling over it; carve round it on the wall, or slam it shut from above."},
}
