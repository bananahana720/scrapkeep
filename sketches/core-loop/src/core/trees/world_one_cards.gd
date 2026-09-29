extends RefCounted

# World-one card copy (--world-one-builds=on), keyed by node id. A pick card shows the row
# here when the flag is on and one exists, and the node's own `effect` otherwise, so a node
# without a row (and every card with the flag off) reads exactly as before. Source:
# design-v3/research/build-systems/BUILD-SYSTEMS.md, the bold line of each node. Sable and
# Rivet rows join this table in their own units; nothing else needs to change.

const ROWS := {
	# Kest, K1 to K6.
	"k_trapper": "Five waiting payloads. Weight widens their blasts.",
	"k_ghost": "Blink unseen. Carry a larger surprise.",
	"k_tripwire": "Charges spring when enemies approach.",
	"k_demo_expert": "Smash scatters five payloads.",
	# k_smoke_trail is held back: its Codex line "Glide cloaked. Heavy fins steer harder." names
	# the Riveted Shell inversion, which needs hot-wired part H1. Add the row when H1 lands.
	"k_ambush": "Throw payloads without breaking cloak.",
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
