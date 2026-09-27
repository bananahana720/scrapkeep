extends RefCounted

# Brindle's four tricks, category "enemy" (DEMO-SPEC, the codex as a treasure hunt).
# boss.gd declares them at setup and marks each one where it detects it.

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
