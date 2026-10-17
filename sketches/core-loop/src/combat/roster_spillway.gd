extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")

# World 1, the Spillway: Fleet crews that work the current (design-v3/FIELDS-AND-CASTS.md
# section 5, the world motifs). Rows in roster.gd's shape plus "script" and "world", as the Dig
# and the Highdraft declare theirs. A declared row spawns by name (lab, tests) and joins the
# director's packs only when a pack names it.
const ROWS := {
	"jolt_layer": {"faction": "fleet", "role": "controller", "mechanic": "static_jam", "telegraph": Threat.Type.INSTANT, "holds": false,
		"breaks": ["speed", "jump"], "tag": "", "tests": "speed", "script": "res://src/combat/jolt_layer.gd", "world": 1,
		"line": "Unrolls a live cable mat that jolts a slow ball: charges and casts drop and specials jam; roll fast, jump or hook out."},
}
