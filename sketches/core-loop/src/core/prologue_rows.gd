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


static func words(text: String) -> int:
	return text.split(" ", false).size()
