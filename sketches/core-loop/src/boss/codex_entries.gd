extends RefCounted

const CATEGORY := "enemy"
const OWNER := "E boss"

const CRANE_DROP := "brindle_crane_drop"
const WALL_BAIT := "brindle_wall_bait"
const QUENCH_RIDE := "brindle_quench_ride"
const SCOOTER_STOMP := "brindle_scooter_stomp"

const ENTRIES := [
	{
		"id": CRANE_DROP, "name": "Requisition Denied",
		"hint": "What the magnet takes, the magnet can drop.",
		"clue": "a crane holding your scrap + a shot",
		"text": "Shoot a crane magnet while it still holds your scrap. It drops the lot in one pile and the ship takes the hit.",
	},
	{
		"id": WALL_BAIT, "name": "Rim Shot",
		"hint": "He charges where you are, not where the wall is.",
		"clue": "a charge lane + the rim wall behind you",
		"text": "Stand near the rim wall so the charge lane ends in it, then get out of the lane. The Requisition hits the wall and sits stunned with its cockpit open.",
	},
	{
		"id": QUENCH_RIDE, "name": "Cold Crossing",
		"hint": "Slag hates water.",
		"clue": "a rim water vent + live slag",
		"text": "Roll over a rim water vent while slag runs. The vent quenches its sector into rock, and you ride the crust straight across the channel.",
	},
	{
		"id": SCOOTER_STOMP, "name": "Boarding Party",
		"hint": "An admiral on a scooter is still an admiral underfoot.",
		"clue": "the eject scooter + a fall from above",
		"text": "Catch Brindle's scooter by landing on it from above instead of ramming it.",
	},
]

const WAKING_FLOOR_DROP := "waking_floor_drop"
const WAKING_BREACH_SLAM := "waking_breach_slam"
const WAKING_FLOOR_CHAIN := "waking_floor_chain"
const WAKING_FINAL_FLOOR := "waking_final_floor"
const WAKING_LIP_DROP := "waking_lip_drop"
const WAKING_WALL_HOME := "waking_wall_home"

const MIND_LANE := "mind_lane"
const MIND_SPLIT_LANE := "mind_split_lane"
const MIND_RUSH := "mind_rush"
const MIND_PLATE := "mind_plate"

const WAKING := [
	{
		"id": WAKING_FLOOR_DROP, "name": "Going Down",
		"hint": "Wake it enough and the room loses its footing.",
		"clue": "a Waking damage chunk + the next floor down",
		"text": "Break a chunk of the Waking's health and follow the fight as it drops a floor.",
	},
	{
		"id": WAKING_BREACH_SLAM, "name": "Knock Downstairs",
		"hint": "A ceiling can deliver more than dust.",
		"clue": "a dropped floor + a slam on the Waking within two seconds",
		"text": "Slam the Waking within two seconds of a floor dropping out from under the fight.",
	},
	{
		"id": WAKING_FLOOR_CHAIN, "name": "Repeat Descent",
		"hint": "The first broken floor is only the beginning.",
		"clue": "breach slams on two different Waking floors",
		"text": "Land breach slams on two different floors as the Waking sinks, the pit included.",
	},
	{
		"id": WAKING_FINAL_FLOOR, "name": "Rock Bottom",
		"hint": "Sooner or later, there is nowhere deeper to hide.",
		"clue": "the Waking's final floor + the finishing hit",
		"text": "Follow the Waking to its final floor and finish the fight there.",
	},
	{
		"id": WAKING_LIP_DROP, "name": "Off the Lip",
		"hint": "A stuck drill can't brace for what falls off the rim.",
		"clue": "a jammed bore drill + a slam straight off a carve",
		"text": "Carve the rim bank, launch off its lip and slam the Waking while its drill is jammed in the floor.",
	},
	{
		"id": WAKING_WALL_HOME, "name": "The Wall Is Home",
		"hint": "The floor fights back. The bank doesn't.",
		"clue": "a burrow lane, a cave-in and a bore breach + carving through each",
		"text": "Carve through a live burrow lane, cave-in and bore breach on the rim bank, untouched.",
	},
]

const MIND := [
	{
		"id": MIND_LANE, "name": "A Different Line",
		"hint": "A straight thought has room on either side.",
		"clue": "the Mind's lane + a sidestep outside it before release",
		"text": "Read the committed lane and leave its width before the Mind releases it.",
	},
	{
		"id": MIND_SPLIT_LANE, "name": "Third Opinion",
		"hint": "Two answers can still leave a third way out.",
		"clue": "the Mind's split_lane + an escape outside both lanes",
		"text": "Find a route clear of both committed lanes when the Mind splits its attack.",
	},
	{
		"id": MIND_RUSH, "name": "Change of Radius",
		"hint": "A circle knows your distance, not your destination.",
		"clue": "the Mind's rush ring + move inward or outward before release",
		"text": "Leave the rush ring's band by changing your distance from the Mind before it releases.",
	},
	{
		"id": MIND_PLATE, "name": "Second Tool",
		"hint": "A guarded answer leaves another question open.",
		"clue": "the Mind's plate + a different contact verb on its staggered Warden",
		"text": "While the plate's window is open and the Warden is staggered, hit it with a contact verb other than the one the plate braced.",
	},
]


static func for_boss(id: String) -> Array:
	match id:
		"brindle":
			return ENTRIES
		"waking":
			return WAKING
		"mind":
			return MIND
	return []


static func all() -> Array:
	return ENTRIES + WAKING + MIND
