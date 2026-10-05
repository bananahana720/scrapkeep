extends RefCounted

# Combat's codex entries: category "enemy" (DEMO-SPEC, the codex as a treasure hunt).
# Each is a trick the player can pull on an enemy. The card shows the name, the hint
# and the clue before discovery and the text after. combat.gd declares them through
# ctx.codex.declare(entry) at setup and detects each one in its own code. Frost tricks
# (a frozen chaser shattered by a ram) wait for build's frost state to exist.

const CATEGORY := "enemy"
const OWNER := "A combat"

const ENTRIES := [
	{
		"id": "shell_return", "name": "Return to Sender",
		"hint": "Lobbers hate their own mail.",
		"clue": "a lobber's shell + something that meets it in the air",
		"text": "Shoot a shell in flight, or roll through it, and it goes back to the lobber that fired it. The return blast is yours.",
	},
	{
		"id": "counter_ram", "name": "Counter-ram",
		"hint": "A chaser crouching to lunge is not braced for you.",
		"clue": "a chaser's wind-up + a ram",
		"text": "Ram a chaser while its lunge lane is still filling and the lunge never happens.",
	},
	{
		"id": "chain", "name": "Chain",
		"hint": "Why let go of the floor when the next enemy is right there?",
		"clue": "a hooked enemy + a wall + another enemy, feet off the floor",
		"text": "Hook an enemy, swing off a wall, hook another, and stay in the air. A smash pays the chain: 30% more per link past the first, up to six.",
	},
	{
		"id": "crush_chain", "name": "Rolling Tide",
		"hint": "Heavy enough, and they stop being obstacles.",
		"clue": "heft + three rams in a heartbeat",
		"text": "Crush three unplated enemies with rams inside one second, without breaking stride.",
	},
	{
		"id": "parting_shot", "name": "Parting Shot",
		"hint": "Leaving a pylon is a good time to be shooting.",
		"clue": "a slingshot + a kill",
		"text": "Kill an enemy within a second of slingshotting off a pylon.",
	},
	# v2 W7 enemies: the counters' opportunities and the ancients' secrets.
	{
		"id": "tether_snap", "name": "Slingshot Snap",
		"hint": "A line is only as strong as what it holds.",
		"clue": "a hooker's tether + more speed than it can take",
		"text": "Outrun or boost against a hooker's tether and it snaps, slinging you forward.",
	},
	{
		"id": "shield_vault", "name": "Off the Dish",
		"hint": "What throws you back can throw you up.",
		"clue": "a deflector's rebound + a jump",
		"text": "Jump the instant a deflector's dish throws you back and the rebound becomes a vault, whatever you pilot.",
	},
	{
		"id": "awaiting_operator", "name": "Awaiting Operator",
		"hint": "Scattered drones look for something to follow.",
		"clue": "a scattered swarm + another enemy",
		"text": "Bowl through a swarm and its drones follow you for two seconds. Lead them into another enemy and they hit it like pins. Fragment 5 reads: awaiting operator.",
	},
	{
		"id": "what_it_learned", "name": "What It Learned",
		"hint": "Something is keeping count.",
		"clue": "one of the Mind's hands + your favourite move",
		"text": "The Mind's hands brace against the move you use most this run, and show you which. Change verbs while its lens is open.",
	},
	{
		"id": "burrow_lane", "name": "Off the Bulge",
		"hint": "The floor gives away what is coming through it.",
		"clue": "a burrower's bulging lane + a sideways roll",
		"text": "Tunnels under the floor along a lane and bursts up under you; roll off the bulging line before it breaks.",
	},
	{
		"id": "bore_breach", "name": "Stop the Bore",
		"hint": "A drill making a hole cannot brace for a falling ball.",
		"clue": "a drill crew mid-bore + a smash",
		"text": "Bores a breach where you will be and the floor caves in; smash the rig mid-bore to stop it.",
	},
	{
		"id": "lure_bloom", "name": "Through the Light",
		"hint": "The lamps want your steering. Give them your speed.",
		"clue": "a lamp swarm's blooming ring + a straight boost",
		"text": "Blooms a ring of lure lamps that bends your steering toward the light; boost straight through the wave.",
	},
	{
		"id": "line_cut", "name": "Under the Cutter",
		"hint": "A spinning blade leaves room beneath its arc.",
		"clue": "a cutter crossing your air path + a low glide or early landing",
		"text": "Throws a spinning cutter across your air path that severs your line; glide under its arc or land early.",
	},
	{
		"id": "deck_winch", "name": "Slip the Hook",
		"hint": "A deck crew needs you on its cable before it can reel.",
		"clue": "an anchor crew's cable lane + a jump before the cinch",
		"text": "Hooks you down a cable lane and winches you onto its deck; jump to slip the hook before it cinches.",
	},
	{
		"id": "thermal_dive", "name": "Leave the Mark",
		"hint": "The kite commits to a spot. You do not have to.",
		"clue": "a circling kite + a shot, or a dive mark + a roll away",
		"text": "Rides the thermals out of reach and dives on the spot it marks; shoot it while it circles or leave the mark.",
	},
]


# 2026-10-04 (wave 9): entries whose in-play detector has not landed yet. Their hints show in
# the codex; combat_codex_test's "every entry discovered in one run" check skips them until the
# enemy that fires each one exists. Remove an id here when its detector lands.
const DETECTOR_PENDING := []


static func all() -> Array:
	var out := []
	for row in ENTRIES:
		var entry: Dictionary = row.duplicate()
		entry["category"] = CATEGORY
		entry["owner"] = OWNER
		entry["participants"] = ["player"]
		out.append(entry)
	return out


static func ids() -> Array:
	var out := []
	for row in ENTRIES:
		out.append(row["id"])
	return out
