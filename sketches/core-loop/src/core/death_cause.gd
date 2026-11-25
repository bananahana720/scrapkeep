extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const PilotStory := preload("res://src/core/pilot_story.gd")
const Rogue := preload("res://src/combat/rogue.gd")


const ROW_OF := {"brindle_charge": "B03", "brindle_slag": "B02"}
const MIXED := ["plated_brute", "reactor_relic", "line_cutter"]
const BOSSES := {"brindle_": "Brindle", "mind_": "the Mind", "waking_": "the Waking"}
const WORDS := {
	"warden": "the Warden",
	"warden_counter": "the Warden's counter-pulse",
	"silt_boil": "a silt boil",
	"flood": "the flood",
	"cinder_floor": "the cinder floor",
	"pocket_veil": "a pocket veil",
	"heat_cook_off": "your own shell, cooked off",
}


static func line(source: String, attack := "", phase_note := "") -> String:
	if source == "":
		return ""
	var id := row_id(source, attack)
	var text := "Scrapped by " + words(source, id)
	if phase_note != "" and _boss(source) != "":
		text += ", " + phase_note
	return text + "."


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


static func phase_note(boss) -> String:
	if boss == null or not ("phase" in boss) or int(boss.phase) <= 0:
		return ""
	var script = boss.get_script()
	var consts: Dictionary = script.get_script_constant_map() if script != null else {}
	if consts.has("CHASE_PHASE") and int(boss.phase) == int(consts["CHASE_PHASE"]):
		return "in the chase"
	return "phase %d" % int(boss.phase)


static func row_id(source: String, attack: String) -> String:
	if EventKinds.has_attack(attack) and String(EventKinds.attack_row(attack).get("owner", "")) == source:
		return attack
	if ROW_OF.has(source):
		return String(ROW_OF[source])
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


static func _without_owner(what: String, who: String) -> String:
	var owner := who.to_lower().trim_prefix("the ").split(" ")
	var words := what.split(" ")
	var skip := 0
	while skip < words.size() - 1 and skip < owner.size() and words[skip] == owner[skip]:
		skip += 1
	return " ".join(words.slice(skip))


static func _article(what: String) -> String:
	return ("an " if what.substr(0, 1) in ["a", "e", "i", "o", "u"] else "a ") + what


const LOSS_MEMOS := [
	"We are sunsetting this pilot. Thank you for your contributions.",
	"Asset loss logged. A replacement shift has been scheduled.",
	"Loss recorded. Scrap recovered at full value. Thank you.",
	"This incident has been added to the quarterly highlights.",
	"Downtime logged. Your next shift starts immediately.",
	"Hull returned to inventory. Thank you for your service.",
]


static func memo(run_seed: int, stage: int, source := "", profile = null, pages: Array = [], run = null) -> String:
	var adaptive := PilotStory.foreman_loss_memo(run_seed, source, profile, pages, run) if profile != null else ""
	var line := adaptive if adaptive != "" else String(LOSS_MEMOS[absi(hash([run_seed, stage, "loss_memo"])) % LOSS_MEMOS.size()])
	return "%s: %s" % [LoreRows.SPEAKERS["mind"], line]
