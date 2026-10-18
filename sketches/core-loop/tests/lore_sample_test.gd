extends SceneTree

const LoreRows := preload("res://src/core/lore_rows.gd")

# The 30 approved lines of design-v3/LORE-TONE-SAMPLE.md, in list order.
const SAMPLE := [
	"Packed you a spare seal. The river doesn't take promises.",
	"We fixed that leak yesterday.",
	"Yesterday's seal is in my bucket. Take today's.",
	"Shift log: intake cleared. Fleet took the spare grate. Fish now larger than permitted.",
	"Maintenance tag: handwheel replaced with a serving tray. Turns fine. Return before supper.",
	"Survey scrap: old flood marks inside the sealed housing. Outside stone is dry. Left the question on the next shift's sheet.",
	"I've counted. You're all here. Sit down; I'll mend the harnesses.",
	"Wall stencil: NO SWINGING FROM SERVICE HOOKS. Inspection note: stencil only visible from service hook.",
	"Cable Reach Warden. Still guarding a shift nobody remembers starting.",
	"Brindle: A working cableway. Excellent. We'll collect the anchors first.",
	"Brought spare lamps. Keep one for the walk back.",
	"The wall knocked first. We stopped calling it settling.",
	"Good. Put the tools down when it answers.",
	"Lamp tally: six issued, seven returned. Extra lamp burns cold. Nobody claimed it.",
	"Shift board: knock twice before drilling. Wait for the second knock to finish.",
	"Rail repair: bent axle replaced. Cart still leans toward the sealed tunnel.",
	"Lunch tin: KEEP CLOSED. Something below has learned the sound of the latch.",
	"Survey mark: measured the same shaft twice. Second measurement includes a landing.",
	"Crew notice: borrowed lights go back on the rack. Even the ones you found.",
	"Pump report: water clear. Sediment forms neat circles around every bolt.",
	"Wind took the wrench. Sent back a spoon.",
	"Fits the same nut. Keep it.",
	"Had our initials on it already.",
	"Deck ledger: three loose panels, two recovered. Third panel seen flying level.",
	"Rigging card: tension holds. Cable sings before the gust reaches the mast.",
	"Galley notice: lids tethered during supper. Soup now travels farther than gossip.",
	"Flight log: flotilla turned together. No signal sent from the bridge.",
	"Repair stencil: PATCH HERE. Paint underneath names tomorrow's shift.",
	"Tool locker: spoon filed as wrench. Wrench filed as weather loss.",
	"Lookout scrap: island lights blink in order. Count starts before the first light.",
]

# Cap edits: sample line index (1-based) to the shortened row text.
const CAP_EDITS := {
	19: "Crew notice: borrowed lights go back on the rack. Even found ones.",
	30: "Lookout scrap: island lights blink in order. Count starts before the first.",
}

# Lines LORE-REPLACE retired with the old stage 2 cableway (decisions.tsv, 2026-10-16).
const RETIRED := [7, 8, 9, 10]

var _failures := 0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	var texts := {}
	for row in LoreRows.ROWS:
		texts[String(row["text"])] = true
	_report("sample count", SAMPLE.size() == 30, "%d lines" % SAMPLE.size())
	for index in range(SAMPLE.size()):
		var number := index + 1
		var expected: String = CAP_EDITS.get(number, SAMPLE[index])
		if number in RETIRED:
			_report("retired line %d" % number, not texts.has(expected), expected)
		else:
			_report("sample line %d" % number, texts.has(expected), expected)
	print("lore_sample_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
