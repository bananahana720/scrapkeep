extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")

# World 2, the Dig: Fleet crews that work the ground under the ball. Rows in roster.gd's
# shape plus "script", the kind's behaviour file, and "world". A row is declared here
# before its script exists; Roster.built(kind) turns true the moment the file does.
const ROWS := {
	"burrower": {"faction": "fleet", "role": "punisher", "mechanic": "burrow_lane", "telegraph": Threat.Type.LANE, "holds": false,
		"breaks": ["speed"], "tag": "", "tests": "speed", "script": "res://src/combat/burrower.gd", "world": 2,
		"line": "Tunnels under the floor along a lane and bursts up under you; roll off the bulging line before it breaks."},
	"drill_crew": {"faction": "fleet", "role": "punisher", "mechanic": "bore_breach", "telegraph": Threat.Type.INSTANT, "holds": false,
		"breaks": ["smash"], "tag": "", "tests": "heft", "script": "res://src/combat/drill_crew.gd", "world": 2,
		"line": "Bores a breach where you will be and the floor caves in; smash the rig mid-bore to stop it."},
	"lamp_swarm": {"faction": "fleet", "role": "controller", "mechanic": "lure_bloom", "telegraph": Threat.Type.WAVE, "holds": false,
		"breaks": ["boost"], "tag": "", "tests": "steer", "script": "res://src/combat/lamp_swarm.gd", "world": 2,
		"line": "Blooms a ring of lure lamps that bends your steering toward the light; boost straight through the wave."},
	"prop_crew": {"faction": "fleet", "role": "controller", "mechanic": "roof_drop", "telegraph": Threat.Type.INSTANT, "holds": false,
		"breaks": ["ram"], "tag": "", "tests": "contact", "script": "res://src/combat/prop_crew.gd", "world": 2,
		"line": "Shores a cracked roof over its pack; ram the prop from the wall side and the roof comes down on them, and on you if you are on the floor."},
}
