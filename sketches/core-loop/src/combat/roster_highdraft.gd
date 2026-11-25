extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")

# World 3, the Highdraft: Fleet crews that work the air and the lines above it. Rows in
# roster.gd's shape plus "script", the kind's behaviour file, and "world". A row is
# declared here before its script exists; Roster.built(kind) turns true the moment the
# file does. The new rows carry their chassis column here (roster.gd merges CHASSIS over
# nothing it lacks) and "grown", the remix a grown pilot meets (design-v3/WORLD-ROSTERS.md).
#
# The Highdraft's verb is the air: nothing to stand on. Heavies die by ring-out, not by
# damage (Andrew, "Ring-outs", 2026-10-17 20:03:50Z); the netcaster comes home as the gap
# net ("Re-home a few", 20:03:01Z). anchor_crew stays declared but is out of the packs.
const HIGHDRAFT_KINDS := ["line_cutter", "kite_drone", "ballast_heavy", "gap_net"]

const ROWS := {
	"line_cutter": {"faction": "fleet", "role": "punisher", "mechanic": "line_cut", "telegraph": Threat.Type.PROJECTILE, "holds": false,
		"breaks": ["glide"], "tag": "", "tests": "air", "script": "res://src/combat/line_cutter.gd", "world": 3,
		"secondary": "boomerang", "secondary_counter": "rebite_and_bat_ringout",
		"grown": "Every other throw lands on where you will touch down instead of your line.",
		"line": "Throws a spinning cutter that severs your line over a gap. Hook a fresh line within half a second and the swing keeps a kick."},
	"anchor_crew": {"faction": "fleet", "role": "controller", "mechanic": "deck_winch", "telegraph": Threat.Type.LANE, "holds": true,
		"breaks": ["jump"], "tag": "", "tests": "heft", "script": "res://src/combat/anchor_crew.gd", "world": 3,
		"line": "Hooks you down a cable lane and winches you onto its deck; jump to slip the hook before it cinches."},
	"kite_drone": {"faction": "fleet", "role": "punisher", "mechanic": "thermal_dive", "telegraph": Threat.Type.INSTANT, "holds": false,
		"breaks": ["glide"], "tag": "", "tests": "air", "script": "res://src/combat/kite_drone.gd", "world": 3,
		"secondary": "slipstream", "secondary_counter": "ride_wake_20m_chasm",
		"grown": "Circles over the gaps instead, and the kill drops you toward the next island.",
		"line": "Circles high in a thermal and dives on the spot it marks; ride the same thermal up and ram it in the air to kill it outright."},
	"ballast_heavy": {"faction": "fleet", "role": "punisher", "mechanic": "ring_out", "telegraph": Threat.Type.INSTANT, "holds": false,
		"breaks": ["speed"], "tag": "", "tests": "contact", "script": "res://src/combat/ballast_heavy.gd", "world": 3,
		"chassis": "heavy", "move_class": "ground", "threat_feature": "Ballast slab hoisted overhead in the brace",
		"secondary": "counter_tug", "secondary_counter": "roll_stake_catapult_heavy",
		"grown": "Stakes a cable behind it that reels it back from one ring-out; roll over the stake from the island side to cut it.",
		"line": "A slab crew posted on the island rim that no damage wears down; ram it off the edge, hardest while it braces to slam."},
	"gap_net": {"faction": "fleet", "role": "controller", "mechanic": "gap_sling", "telegraph": Threat.Type.LANE, "holds": false,
		"breaks": ["speed", "smash"], "tag": "", "tests": "air", "script": "res://src/combat/gap_net.gd", "world": 3,
		"chassis": "emplacement", "move_class": "fixed", "threat_feature": "Live net crackling across the gap between two posts",
		"secondary": "shock_net", "secondary_counter": "blazing_rip_3s_electric_aura",
		"grown": "Strings a second net behind the first on a long gap.",
		"line": "Strings a live net across a gap that slings a slow crossing back the way it came; cross faster than it can hold and you rip it."},
}


# A grown pilot (heft class GROWN_CLASS and up) meets each row's "grown" remix. Read from the
# director, which world.gd keeps at run.heft_class() every tick; no director means not grown.
const GROWN_CLASS := 3


static func grown(enemy: Node) -> bool:
	if enemy == null or enemy.get("world_root") == null:
		return false
	var world = enemy.world_root.get_node_or_null("World")
	if world == null or world.get("director") == null:
		return false
	return int(world.director.heft_class) >= GROWN_CLASS
