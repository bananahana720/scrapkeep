extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const Rogue := preload("res://src/combat/rogue.gd")

# The RUN OVER line that names what scrapped you (wave 27 first-timer red team, note 2):
# one dry line from the killing hit's damage source; the ATTACK_ROWS id picks the wording but is
# never shown (the player reads words, not codes). Isaac's death note draws the killer, Dead Cells' death screen
# prints "Killed by", and Hades has Hypnos name it on the way back in: one line, read once.
#
#   Scrapped by Brindle's scuttle charge, phase 2.
#   Scrapped by Gate Crane No. 14's leaf drop.
#   Scrapped by a chaser lunge.
#   Scrapped by a silt boil.

# Sources that are a boss's own damage call and name their row outright.
const ROW_OF := {"brindle_charge": "B03", "brindle_slag": "B02"}
# A boss's sources start with its prefix: brindle_charge, mind_hand, waking_<family>.
# Bodies whose one row is not every hit they land (the brute's hurl and affix strike, the relic's
# crater burn, the cutter's sting): they read by name, not by a row that may be the wrong one.
const MIXED := ["plated_brute", "reactor_relic", "line_cutter"]
const BOSSES := {"brindle_": "Brindle", "mind_": "the Mind", "waking_": "the Waking"}
# Sources with no attack row of their own: the Warden's slag and pulse share "warden", and the
# world's hazards are not bodies.
const WORDS := {
	"warden": "the Warden",
	"warden_counter": "the Warden's counter-pulse",
	"silt_boil": "a silt boil",
	"flood": "the flood",
	"cinder_floor": "the cinder floor",
	"pocket_veil": "a pocket veil",
	"heat_cook_off": "your own shell, cooked off",
}


# The whole line; "" when the death has no source (a test's direct emit).
static func line(source: String, attack := "", phase_note := "") -> String:
	if source == "":
		return ""
	var id := row_id(source, attack)
	var text := "Scrapped by " + words(source, id)
	if phase_note != "" and _boss(source) != "":
		text += ", " + phase_note
	return text + "."


# What scrapped you, in words: the attack row's label under its owner's name when there is
# a row, else the source's own words.
static func words(source: String, id := "") -> String:
	var who := _who(source)
	if id != "":
		var what := EventKinds.attack_label(id).to_lower()
		if who == "":
			return _article(what)
		return "%s's %s" % [who, _without_owner(what, who)]
	if WORDS.has(source):
		return String(WORDS[source])
	var said := source.replace("_", " ")
	var boss := _boss(source)
	if boss != "":
		return "%s's %s" % [BOSSES[boss], said.substr(boss.length())]
	return who if who != "" else _article(said)


# "phase 2" for a boss on its phases, "in the chase" for Brindle's scooter; "" off a boss.
static func phase_note(boss) -> String:
	if boss == null or not ("phase" in boss) or int(boss.phase) <= 0:
		return ""
	var script = boss.get_script()
	var consts: Dictionary = script.get_script_constant_map() if script != null else {}
	if consts.has("CHASE_PHASE") and int(boss.phase) == int(consts["CHASE_PHASE"]):
		return "in the chase"
	return "phase %d" % int(boss.phase)


# The ATTACK_ROWS id the hit reads by, "" when the source has no one row (death_tips.gd keys its rows on it too).
static func row_id(source: String, attack: String) -> String:
	if EventKinds.has_attack(attack) and String(EventKinds.attack_row(attack).get("owner", "")) == source:
		return attack
	if ROW_OF.has(source):
		return String(ROW_OF[source])
	# A body with one hostile row (a chaser's lunge) names it; a body with two needs the attack.
	if source in MIXED:
		return ""
	var found := ""
	for id in EventKinds.attack_ids():
		var row := EventKinds.attack_row(id)
		if String(row.get("owner", "")) == source and String(row.get("allegiance", "")) == "hostile":
			if found != "":
				return ""
			found = id
	return found


static func _boss(source: String) -> String:
	for prefix in BOSSES:
		if source.begins_with(prefix):
			return prefix
	return ""


static func _who(source: String) -> String:
	var boss := _boss(source)
	if boss != "":
		return String(BOSSES[boss])
	if Rogue.ROWS.has(source):
		return String(Rogue.ROWS[source]["name"])
	return ""


# "gate crane leaf drop" under "Gate Crane No. 14" reads "leaf drop": the label's leading words
# that repeat the owner's name go.
static func _without_owner(what: String, who: String) -> String:
	var owner := who.to_lower().trim_prefix("the ").split(" ")
	var words := what.split(" ")
	var skip := 0
	while skip < words.size() - 1 and skip < owner.size() and words[skip] == owner[skip]:
		skip += 1
	return " ".join(words.slice(skip))


static func _article(what: String) -> String:
	return ("an " if what.substr(0, 1) in ["a", "e", "i", "o", "u"] else "a ") + what


# The Foreman logs your loss (W1-75; STORY-MAP, "The Foreman's voice": in world 1 it shows up as
# memos, and "your loss being logged" is one). It is said straight and grateful, about the books and
# never about the player, and it goes under the cause and above the crew's "next shift" tip, so the
# run's last word stays the crew's. The seed and the stage pick the line, the same one on a replay.
const LOSS_MEMOS := [
	"We are sunsetting this pilot. Thank you for your contributions.",
	"Asset loss logged. A replacement shift has been scheduled.",
	"Loss recorded. Scrap recovered at full value. Thank you.",
	"This incident has been added to the quarterly highlights.",
	"Downtime logged. Your next shift starts immediately.",
	"Hull returned to inventory. Thank you for your service.",
]


# The memo as the screen shows it, its sender first (the name a call card gives the Foreman).
static func memo(run_seed: int, stage: int) -> String:
	var line := String(LOSS_MEMOS[absi(hash([run_seed, stage, "loss_memo"])) % LOSS_MEMOS.size()])
	return "%s: %s" % [LoreRows.SPEAKERS["mind"], line]
