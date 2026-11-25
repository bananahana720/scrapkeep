extends RefCounted

# The first run's opening: a shift note handing the ball its first job, shown once per
# profile between Start and pilot select (screens.gd). The interact key advances a line;
# fire or hook skips the rest, as a zone-entry exchange does (moss_bubble.gd).

const ID := "lore.prologue"
const LINE_WORD_CAP := 14

const ROWS := [
	{"speaker": "Moss", "text": "Shift note: new ball on the roster. First job is the Spillway."},
	{"speaker": "Pump crew", "text": "Our runner went down to check the seals. Never clocked out."},
	{"speaker": "Moss", "text": "Bring them back up. Their card still punches in each morning."},
]

# W50-STORY-ARCS additive Act II / Act III shift notes (ROWS stays 3 W1 rows for screens_prologue_test).
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
