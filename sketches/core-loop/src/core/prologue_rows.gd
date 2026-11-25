extends RefCounted


const ID := "lore.prologue"
const LINE_WORD_CAP := 14

const ROWS := [
	{"speaker": "Moss", "text": "Shift note: new ball on the roster. First job is the Spillway."},
	{"speaker": "Pump crew", "text": "Our runner went down to check the seals. Never clocked out."},
	{"speaker": "Moss", "text": "Bring them back up. Their card still punches in each morning."},
]

const ACT_NOTES := {
	2: [
		{"speaker": "Moss", "text": "Shift note: Spillway is clear. Next rail runs down into the Dig."},
		{"speaker": "Dig crew", "text": "Something under the benches knocks twice before every drill cycle."},
		{"speaker": "Moss", "text": "Packed spare lamps. Follow the turquoise seam and keep moving."},
	],
	3: [
		{"speaker": "Moss", "text": "Shift note: the Dig is quiet. Last climb is the Highdraft."},
		{"speaker": "Roost crew", "text": "Every bearing on the chart ends at the Crown Spire, including north."},
		{"speaker": "Moss", "text": "Roll on the off-beat up there. Supper waits at camp."},
	],
}


static func for_world(world: int) -> Array:
	if world <= 1:
		return ROWS
	return ACT_NOTES.get(world, ROWS)


static func words(text: String) -> int:
	return text.split(" ", false).size()
