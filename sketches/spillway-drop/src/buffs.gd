extends RefCounted

# One table is the whole buff domain: the roll, the HUD label and the stat it
# moves all read from here, so adding a buff is one row and nothing else.
const SPECS := [
	{"id": "cruise", "label": "+10% cruise"},
	{"id": "jump", "label": "+1 m/s jump"},
	{"id": "boost", "label": "-15% boost cooldown"},
	{"id": "impact", "label": "+25% impact damage"},
	{"id": "hull", "label": "+20 max HP"},
]


static func roll(rng: RandomNumberGenerator) -> String:
	return SPECS[rng.randi_range(0, SPECS.size() - 1)]["id"]


static func label(id: String) -> String:
	for spec in SPECS:
		if spec["id"] == id:
			return spec["label"]
	return id
