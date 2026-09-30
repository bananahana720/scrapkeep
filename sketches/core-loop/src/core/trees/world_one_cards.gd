extends RefCounted

# World-one card copy (--world-one-builds=on), keyed by node id. A pick card shows the row
# here when the flag is on and one exists, and the node's own `effect` otherwise, so a node
# without a row (and every card with the flag off) reads exactly as before. Source:
# design-v3/research/build-systems/BUILD-SYSTEMS.md, the bold line of each node. Sable and
# Rivet rows join this table in their own units; nothing else needs to change.

const ROWS := {
	# Sable, S1 to S6.
	"s_cannonball": "Vault kicks discharge. Weight launches farther.",
	"s_beachhead": "Catch distant walls. Launch your weight.",
	"s_coil_hook": "Release the rope into a cannonball.",
	"s_face_runner": "Vaults restore jumps. Heavy fins steer harder.",
	"s_arc_nest": "Mounted bolts chain to another target.",
	"s_bulwark": "Mounted, shrug off crowd control.",
	# Kest, K1 to K6.
	"k_trapper": "Five waiting payloads. Weight widens their blasts.",
	"k_ghost": "Blink unseen. Carry a larger surprise.",
	"k_tripwire": "Charges spring when enemies approach.",
	"k_demo_expert": "Smash scatters five payloads.",
	"k_smoke_trail": "Glide cloaked. Heavy fins steer harder.",
	"k_ambush": "Throw payloads without breaking cloak.",
	# Rivet, R1 to R6.
	"r_gunline": "Twin bolts sweep the running line.",
	"r_juggernaut": "Starting a sprint blasts enemies back.",
	"r_tracer": "Running fire jumps to a neighbour.",
	"r_run_gun": "Sustain fire. Worn scrap sparks behind you.",
	"r_ram_fins": "Sprint through bodies instead of rebounding.",
	"r_second_wind": "Bank two sprints. Heavy fins open during sprint.",
}


static func has_row(node_id: String) -> bool:
	return ROWS.has(node_id)


# The effect line a card shows for this node: the world-one row when `world_one` and a
# row exists, else the node's own effect.
static func effect_line(node: Dictionary, world_one: bool) -> String:
	var id := String(node.get("id", ""))
	if world_one and ROWS.has(id):
		return String(ROWS[id])
	return String(node.get("effect", ""))
