extends RefCounted

# The one dry crew-log line the camp shows when the walk opens. Pure logic: it reads the
# scrapbook's pages (newest first, as ScrapbookStore.load_all makes them) and returns a
# line. Nothing here touches the tree, the clock or a random stream: the choice is a hash
# of the newest page's run id, so the same history says the same thing. A page is read for
# run_id, outcome ("won" or "lost"; an older page without it reads its won flag), world,
# pilot and stage_reached; missing keys read as empty. An abandoned run makes no page, so there
# is no quit line. With no pages it falls back to the profile's lifetime stats (stages_cleared,
# deaths, kills): a ledger line when there are any, the first-visit line when there are
# none. Melodrama stays in the scrapbook's captions; these are the log.

const ScrapbookStore := preload("res://src/core/scrapbook_store.gd")

const STREAK_LOSSES := 3
const STREAK_WINS := 2

const FIRST := [
	"Camp log opened. Nothing in it yet, which is the cleanest it will be.",
	"Fire pit lit. Bench count: two. Occupants: none, so far.",
	"Ledger is blank. Tally has sharpened a pencil for it and is being brave about that.",
	"First entry waits for a first run. The pencil has been counted.",
]
const LEDGER := [
	"Totals are in the log. The days they came from are not.",
	"Ledger has sums and no stories. Somebody forgot to write the stories.",
	"The numbers add up. Nobody wrote down who was flying.",
]
const WIN := [
	"Log shows the run won. Log has been wrong before, but it is wearing a clean cuff.",
	"Hull came back. Moss counted the bolts twice and kept their face still.",
	"Run closed in our favour. Someone put a washer on the fire-pit bench to mark it.",
	"Return entered in ink. The ink is the good ink.",
	"Win logged. Nobody cheered; the kettle did, briefly.",
	"They came back with all their limbs and one extra bolt. Bolt filed under found.",
]
const LOSS_1 := [
	"Spillway kept the hull. Pump crew sends a bill for the dent.",
	"Came back from the Works wet to the knee. The Works has not offered a refund.",
	"Intake won this shift. Brindle's anchors are still where he left them, which is everywhere.",
	"Log says Spillway, then a long underline.",
	"One boot returned from the Works. It was the left one. Nobody asked after the right.",
]
const LOSS_2 := [
	"The Dig kept the hull. A lamp came up in its place; we only issued six.",
	"Pit crew logs a knock from below. Nobody has been below.",
	"Dig took the run and gave back some dust. Dust has been entered as evidence.",
	"Floor held until it was asked to. Entry closed at that point.",
	"Came up from the Dig with a pocket of grit and a very polite silence.",
	"Dig shift ended early. Shovel count unchanged, morale under review.",
]
const LOSS_3 := [
	"Highdraft kept the hull. The cable is still humming something we know.",
	"Watch reports a washer rolling on the deck. It has not stopped rolling.",
	"The Mind committed its lanes. We did not commit ours in time.",
	"Reached the top and the top reached back. Details to follow, once they stop shaking.",
	"Highdraft log: wind, then a quiet, then us on the bench.",
]
const NEW_PILOT := [
	"New name on the roster. Moss has already got the wrong boots out for them.",
	"First log under this pilot. The nameplate is still tacky.",
	"A different pilot at the fire. Bench has been moved four inches to fit them.",
	"New hand on the hook. Tally wrote the name down and then the spelling.",
]
const STREAK_LOSS := [
	"Third loss in a row. The ledger has stopped adding an apology to each.",
	"Losses stacking neatly. Moss has started labelling the shelf.",
	"Several hulls back to back. The repair bay has begun to greet them by name.",
	"A run of losses on record. The kettle was put on without anyone asking.",
]
const STREAK_WIN := [
	"Two wins running. The log is suspicious and has asked for a witness.",
	"Wins in a row. Somebody oiled the gate hinge in celebration. Only the hinge.",
	"Back to back. Tally ran out of checkmarks and has started on tallies.",
]

const OUTCOME_LOSS := [LOSS_1, LOSS_2, LOSS_3]

# W50-STORY-ARCS additive story-state pools (selected only when a 3rd story_state arg reports progress).
const ORDER_DONE := [
	"Work order stamped and clipped to the brass rail. Moss signed the bottom corner.",
	"Shift slip filed on the board. One fewer job waiting on the hook.",
	"Order closed clean. The rail hangs a fraction straighter this evening.",
]
const LICENSE_UP := [
	"Maker license stamped up a grade. Shelf clerks stopped asking for a supervisor.",
	"Fresh stamp on the maker ticket. Better bins open at the next counter.",
	"License moved up the rail. Moss moved the spare crate onto the front bench.",
]
const CHAPTER_BEAT := [
	"New hole punched in the crew card. Even the Foreman's clock skipped a beat.",
	"Another chapter clipped into the shift log. Bench chatter ran past supper.",
	"Time card came back heavier. Nobody threw the old stub away.",
]
const PATCH_WALL_NOTE := [
	"Three wire rooms found, one chalk paw by the fire pit. Kettle still warm.",
	"Somebody left a coiled jumper cable on the bench. Signed in chalk, no name.",
	"All three cut lines accounted for. The camp radio tuned itself before dawn.",
]
const HARD_CLEAR := [
	"Overtime shift cleared on the first bell. The ledger needed a thicker pen.",
	"Hard rung logged and stamped. Nobody asked if the ball needed a rest.",
	"Overtime ribbon pinned over the fire pit. Moss poured the good tea.",
]


static func all_lines() -> Array:
	var out: Array = []
	for group in [
		FIRST, LEDGER, WIN, LOSS_1, LOSS_2, LOSS_3, NEW_PILOT, STREAK_LOSS, STREAK_WIN,
		ORDER_DONE, LICENSE_UP, CHAPTER_BEAT, PATCH_WALL_NOTE, HARD_CLEAR,
	]:
		out.append_array(group)
	return out


# The line for a scrapbook, newest page first. `stats` is the profile's stats map, read
# only when there are no pages. Optional `story_state` selects W50 progression pools while
# keeping 1- and 2-arg callers byte-identical.
static func line_for(pages: Array, stats := {}, story_state := {}) -> String:
	if not story_state.is_empty():
		var story_line := _story_line(pages, story_state)
		if story_line != "":
			return story_line
	if pages.is_empty():
		var played := float(stats.get("stages_cleared", 0.0)) + float(stats.get("deaths", 0.0)) + float(stats.get("kills", 0.0))
		return _pick(LEDGER if played > 0.0 else FIRST, "stats-%d" % int(played))
	var last: Dictionary = pages[0]
	var seed_text := String(last.get("run_id", "")) if String(last.get("run_id", "")) != "" else "%s/%s" % [last.get("pilot", ""), last.get("stage_reached", 0)]
	var won := is_won(last)
	var streak := _streak(pages)
	if not won and streak >= STREAK_LOSSES:
		return _pick(STREAK_LOSS, seed_text)
	if won and streak >= STREAK_WINS:
		return _pick(STREAK_WIN, seed_text)
	if _is_new_pilot(pages):
		return _pick(NEW_PILOT, seed_text)
	if won:
		return _pick(WIN, seed_text)
	var world := clampi(int(last.get("world", 1)), 1, OUTCOME_LOSS.size())
	return _pick(OUTCOME_LOSS[world - 1], seed_text)


static func _story_line(pages: Array, story_state: Dictionary) -> String:
	var base := "story"
	if not pages.is_empty():
		var last: Dictionary = pages[0]
		base = String(last.get("run_id", "")) if String(last.get("run_id", "")) != "" else "%s/%s" % [last.get("pilot", ""), last.get("stage_reached", 0)]
	if bool(story_state.get("patch_wires_all", false)):
		return _pick(PATCH_WALL_NOTE, base + ":patch")
	var hard_clear := int(story_state.get("hard_clear", 0))
	if hard_clear > 0:
		return _pick(HARD_CLEAR, "%s:hard:%d" % [base, hard_clear])
	var chapter_punched = story_state.get("chapter_punched", {})
	if chapter_punched is Dictionary and int((chapter_punched as Dictionary).get("num", 0)) >= 3:
		return _pick(CHAPTER_BEAT, "%s:ch:%s" % [base, String((chapter_punched as Dictionary).get("id", ""))])
	var licenses_up = story_state.get("licenses_up", [])
	if licenses_up is Array and not (licenses_up as Array).is_empty():
		return _pick(LICENSE_UP, "%s:lic:%s" % [base, String((licenses_up as Array)[0])])
	var order_done = story_state.get("order_done", [])
	if order_done is Array and not (order_done as Array).is_empty():
		return _pick(ORDER_DONE, "%s:ord:%s" % [base, String((order_done as Array)[0])])
	return ""


# A page's outcome: the run-end thread's "outcome" field, else the older won flag.
static func is_won(page: Dictionary) -> bool:
	return ScrapbookStore.is_won(page)


# How many pages from the newest share its outcome (won or not).
static func _streak(pages: Array) -> int:
	var won := is_won(pages[0])
	var n := 0
	for page in pages:
		if is_won(page) != won:
			break
		n += 1
	return n


# The newest page is the only one that pilot has on the shelf.
static func _is_new_pilot(pages: Array) -> bool:
	var id := String((pages[0] as Dictionary).get("pilot", ""))
	if id.is_empty():
		return false
	for i in range(1, pages.size()):
		if String((pages[i] as Dictionary).get("pilot", "")) == id:
			return false
	return pages.size() > 1


# String.hash is stable for the same text across runs of one build.
static func _pick(group: Array, seed_text: String) -> String:
	return String(group[posmod(seed_text.hash(), group.size())])
