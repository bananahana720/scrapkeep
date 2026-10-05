extends SceneTree

const Game := preload("res://src/game.gd")
const Parts := preload("res://src/build/parts.gd")
const PartDef := preload("res://src/build/part_def.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const CombatCodex := preload("res://src/combat/codex_entries.gd")
const WorldCodex := preload("res://src/world/codex_world.gd")
const BossCodex := preload("res://src/boss/codex_entries.gd")

# The coherence check (DEMO-SPEC, "Design feedback loop", step 4). Every piece of the
# demo must say what it is for, so the loop can reason about it:
#   - every part has one or two tags from the vocabulary, and a verb;
#   - every codex entry has an owner (the module whose data declares it, and whose
#     category it carries), a clue and a live category;
#   - every GameEvents signal has an event_kinds row with a sound;
#   - every live DESIGN-NOTES line in a module section names the stage demand it serves
#     (Warden, event, vault, boss phase) with a "Demand:" marker.
#
# The notes rule arrived with DEMO-SPEC, after most module lines were written. Lines
# without the marker, and lines whose marker names something outside the four demands,
# are listed as NOTE lines, not failures, and each section's count is held to the
# baseline below: a new line without a demand fails, a fixed old one prints a note to
# lower the baseline. Superseded lines are skipped; "Demand: none" is declared plumbing.

const OWNERS := {
	"enemy": "A combat (src/combat/codex_entries.gd)",
	"build": "B build (build.codex_declarations())",
	"world": "D world (src/world/codex_world.gd)",
	"boss": "E boss (src/boss/codex_entries.gd), filed under enemy",
}
const MODULE_SECTION := "\\(writer ([A-Z])\\)"
const DEMANDS := ["warden", "event", "vault", "boss"]
# The boss section names its demand by phase ("Demand: phase 2", "the chase", "arena
# entry"): each is a boss-phase demand in the spec's sense.
const BOSS_DEMANDS := ["phase", "arena", "brindle", "finale", "chase"]
# Unmarked and off-list live lines per module section, reset at the merge of
# proto/core-loop-int 97d46ce (A's review-wave lines and C's audio notes arrived without
# the marker). Lower these as the backfill lands; never raise them.
const BASELINE_UNMARKED := {"A": 35, "B": 24, "C": 72, "D": 21, "E": 0, "L": 0}
const BASELINE_OFF_LIST := {"A": 0, "B": 0, "C": 0, "D": 1, "E": 0, "L": 0}
const PLAY_TICKS := 6

var _game
var _failures := 0
var _ticks := 0
var _started := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _note(label: String, detail: String) -> void:
	print("[%s] %s -> NOTE" % [label, detail])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	# Build declares its hint cards on the first tick of play, so wait a few.
	_ticks += 1
	if _ticks < PLAY_TICKS:
		return false
	_check_parts()
	_check_codex()
	_check_event_kinds()
	_check_notes()
	print("loop_coherence_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _check_parts() -> void:
	var bad: Array[String] = []
	for id in Parts.CATALOGUE:
		var row: Dictionary = Parts.CATALOGUE[id]
		var tags: Array = row.get("tags", [])
		var problems: Array[String] = []
		if tags.is_empty() or tags.size() > 2:
			problems.append("%d tags" % tags.size())
		for tag in tags:
			if not tag in PartDef.TAGS:
				problems.append("tag '%s' outside the vocabulary" % tag)
		if String(row.get("verb", "")).strip_edges() == "":
			problems.append("no verb")
		if not problems.is_empty():
			bad.append("%s (%s)" % [id, ", ".join(problems)])
	_report("parts tagged and verbed", bad.is_empty(),
		"%d catalogue parts, each with 1-2 tags from %s and a verb; failing: %s" % [Parts.CATALOGUE.size(), PartDef.TAGS, bad if not bad.is_empty() else "none"])


# Owner = the module whose own data declares the entry; its category must be that
# owner's. An entry nobody's data declares, or in a reserved category, has no owner.
func _check_codex() -> void:
	var declared_by := {}
	for entry in CombatCodex.ENTRIES:
		declared_by[entry["id"]] = "enemy"
	for entry in WorldCodex.ENTRIES:
		declared_by[entry["id"]] = "world"
	# Boss tricks are enemy tricks that E declares (BOSS-BRINDLE.md, wave 4 packet); all() spans
	# the Brindle, Waking and Mind tables since wave 13.
	var boss_ids := {}
	for entry in BossCodex.all():
		declared_by[entry["id"]] = BossCodex.CATEGORY
		boss_ids[entry["id"]] = true
	var build = _game.ctx.build
	if build != null and build.has_method("codex_declarations"):
		for entry in build.codex_declarations():
			declared_by[entry["id"]] = "build"
	var entries: Array = _game.codex.entries()
	var bad: Array[String] = []
	var per := {}
	for entry in entries:
		var id: String = entry["id"]
		var category: String = entry.get("category", "")
		var problems: Array[String] = []
		if category == "" or EventKinds.CODEX_CATEGORIES.get(category, {}).get("reserved", false):
			problems.append("category '%s' has no owner in the demo" % category)
		elif not declared_by.has(id):
			problems.append("declared by no module's data")
		elif declared_by[id] != category:
			var owner: String = OWNERS.get("boss" if boss_ids.has(id) else declared_by[id], "?")
			problems.append("declared by %s but filed under %s" % [owner, category])
		if String(entry.get("clue", "")).strip_edges() == "":
			problems.append("no clue")
		if not problems.is_empty():
			bad.append("%s (%s)" % [id, ", ".join(problems)])
		per[category] = int(per.get(category, 0)) + 1
	_report("codex entries owned", bad.is_empty() and entries.size() > 0,
		"%d entries %s; each has an owner, a clue and a live category; failing: %s" % [entries.size(), per, bad if not bad.is_empty() else "none"])


func _check_event_kinds() -> void:
	var missing: Array[String] = []
	var names: Array[String] = []
	for sig in _game.events.get_script().get_script_signal_list():
		names.append(sig["name"])
	for kind in names:
		var row: Dictionary = EventKinds.row(kind)
		if row.is_empty():
			missing.append("%s (no row)" % kind)
		elif String(row.get("sound", "")).strip_edges() == "":
			missing.append("%s (no sound)" % kind)
	for kind in EventKinds.ROWS:
		if String(EventKinds.ROWS[kind].get("sound", "")).strip_edges() == "" and not kind in names:
			missing.append("%s (row without sound)" % kind)
	_report("event kinds sound", missing.is_empty(),
		"%d bus signals, each with an event_kinds row and a sound; failing: %s" % [names.size(), missing if not missing.is_empty() else "none"])


func _check_notes() -> void:
	var text := FileAccess.get_file_as_string("res://DESIGN-NOTES.md")
	var sections := _module_items(text)
	_report("notes parsed", not sections.is_empty(), "module sections found: %s" % [sections.keys()])
	var marker := RegEx.create_from_string("Demands?:\\s*([^.]*)")
	for writer in sections:
		var marked := 0
		var plumbing: Array[String] = []
		var unmarked: Array[String] = []
		var off_list: Array[String] = []
		for item in sections[writer]:
			var found := marker.search(item["text"])
			if found == null:
				unmarked.append("%d %s" % [item["number"], item["title"]])
				continue
			var demand := found.get_string(1).strip_edges().to_lower()
			if demand.begins_with("none"):
				plumbing.append("%d %s" % [item["number"], item["title"]])
				continue
			var named := false
			for word in DEMANDS + BOSS_DEMANDS:
				if word in demand:
					named = true
			if named:
				marked += 1
			else:
				off_list.append("%d %s (Demand: %s)" % [item["number"], item["title"], found.get_string(1).strip_edges()])
		var unmarked_cap: int = BASELINE_UNMARKED.get(writer, 0)
		var off_cap: int = BASELINE_OFF_LIST.get(writer, 0)
		_report("notes %s demands" % writer, unmarked.size() <= unmarked_cap and off_list.size() <= off_cap,
			"%d live lines: %d name a stage demand, %d declare plumbing, %d predate the marker (baseline %d), %d name a demand outside Warden/event/vault/boss (baseline %d)"
				% [(sections[writer] as Array).size(), marked, plumbing.size(), unmarked.size(), unmarked_cap, off_list.size(), off_cap])
		if not unmarked.is_empty():
			_note("notes %s unmarked" % writer, "; ".join(unmarked))
		if not off_list.is_empty():
			_note("notes %s off-list" % writer, "; ".join(off_list))
		if not plumbing.is_empty():
			_note("notes %s plumbing" % writer, "; ".join(plumbing))
		if unmarked.size() < unmarked_cap or off_list.size() < off_cap:
			_note("notes %s baseline" % writer, "fewer lines than the baseline: lower BASELINE_UNMARKED or BASELINE_OFF_LIST to %d / %d"
				% [unmarked.size(), off_list.size()])


# Writer letter -> the section's live numbered items: {number, title, text}. An item runs
# from its "N. **Title**" line to the next item or heading; superseded items are dropped.
func _module_items(text: String) -> Dictionary:
	var section := RegEx.create_from_string(MODULE_SECTION)
	var item := RegEx.create_from_string("^(\\d+)\\. \\*\\*(.+?)\\*\\*")
	var sections := {}
	var writer := ""
	var current := {}
	for line in text.split("\n"):
		if line.begins_with("#"):
			_close_item(sections, writer, current)
			current = {}
			var m := section.search(line) if line.begins_with("## ") else null
			if line.begins_with("## "):
				writer = m.get_string(1) if m != null else ""
				if writer != "":
					sections[writer] = []
			continue
		if writer == "":
			continue
		var start := item.search(line)
		if start != null:
			_close_item(sections, writer, current)
			current = {"number": int(start.get_string(1)), "title": start.get_string(2).trim_suffix("."), "text": line}
		elif not current.is_empty():
			current["text"] += "\n" + line
	_close_item(sections, writer, current)
	return sections


static func _close_item(sections: Dictionary, writer: String, item: Dictionary) -> void:
	if writer == "" or item.is_empty() or not sections.has(writer):
		return
	var title: String = item["title"]
	if title.begins_with("Superseded") or "(Superseded by" in item["text"]:
		return
	(sections[writer] as Array).append(item)
