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
	{
		"id": "pulse_stomp", "name": "Pulse Return",
		"hint": "What goes up can come down on a cap.",
		"clue": "a Warden pulse + a vent cap",
		"text": "Ride a Warden's pulse up and stomp one of its vent caps on the way down.",
	},
	{
		"id": "magnet_break", "name": "Demagnetized",
		"hint": "Its pull is also its weakness.",
		"clue": "a Warden's magnet + a shot during the tug",
		"text": "Shoot the Warden's magnet mid-tug and break the Warden before its plating comes back.",
	},
]


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
