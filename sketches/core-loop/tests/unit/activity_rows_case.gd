extends RefCounted

const Activities := preload("res://src/world/activities.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Reach := preload("res://src/world/map_reach.gd")
const StageMap := preload("res://src/world/stage_map.gd")

# The standing activities' tables (LEGIBILITY section 9, wave R3): every site the Reach stands has
# a rule and a row, every rule names a pay, surge_run has a row and no site, and neither new source
# file carries a colour literal, so the amber on the beam is the row's and no other.

const SOURCES := ["res://src/world/activities.gd", "res://src/world/activity_view.gd"]
const PAY_FIELDS := ["rarities", "source", "where", "scrap"]
const RULE_FIELDS := ["starts", "finishes", "pay", "ring"]


func run(t) -> void:
	var map = Reach.new()
	var site_ids: Array = map.activity_sites.map(func(s): return String(s["id"]))
	var no_rule: Array = []
	var no_row: Array = []
	for id in site_ids:
		if not Activities.RULES.has(id):
			no_rule.append(id)
		if EventKinds.activity_row(id).is_empty():
			no_row.append(id)
	t.check("the Reach stands four activities", site_ids.size() == 4, "sites: %s" % [site_ids])
	t.check("every site on the Reach has a rule", no_rule.is_empty(), "no rule: %s" % [no_rule])
	t.check("every site on the Reach has a row", no_row.is_empty(), "no row: %s" % [no_row])

	var no_pay: Array = []
	var bad_rule: Array = []
	var ceremony: Array = []
	for id in Activities.RULES:
		var rule: Dictionary = Activities.RULES[id]
		for field in RULE_FIELDS:
			if not rule.has(field):
				bad_rule.append("%s lacks %s" % [id, field])
		var pay: Dictionary = rule.get("pay", {})
		for field in PAY_FIELDS:
			if not pay.has(field):
				no_pay.append("%s lacks pay.%s" % [id, field])
		if String(pay.get("source", "")) in EventKinds.CEREMONY_SOURCES:
			ceremony.append(id)
	t.check("every rule has its fields", bad_rule.is_empty(), "%s" % [bad_rule])
	t.check("every rule names a pay", no_pay.is_empty() and not Activities.RULES.is_empty(), "%s" % [no_pay])
	t.check("no pay source is a ceremony source, so none pauses the game", ceremony.is_empty(), "ceremony sources: %s" % [ceremony])

	var row_ids: Array = EventKinds.ACTIVITY_ROWS.keys()
	# SQ5 (coordinator, 2026-10-13): a pocket kind borrows its sight and sound from an existing row
	# through cue.view, so a rule resolves through its own row or the row its view names.
	var orphan_rules: Array = Activities.RULES.keys().filter(func(id):
		var view := String(Activities.RULES[id].get("cue", {}).get("view", id))
		return not row_ids.has(id) and not row_ids.has(view))
	t.check("every rule has a row", orphan_rules.is_empty(), "rules without a row: %s" % [orphan_rules])
	t.check("surge_run has a row and no site", EventKinds.ACTIVITY_ROWS.has("surge_run") and not site_ids.has("surge_run"),
		"row %s, sites %s" % [EventKinds.ACTIVITY_ROWS.has("surge_run"), site_ids])
	# Flume pass two: surge_run is built only where a park activity row names it with a route (surge_course.gd).
	t.check("surge_run's rule is the park surge course: a ring start and a surge finish",
		Activities.RULES.get("surge_run", {}).get("starts") == "ring" and Activities.RULES.get("surge_run", {}).get("finishes") == "surge",
		"rule %s" % [Activities.RULES.get("surge_run", {})])
	t.check("the default stage map stands none", (StageMap.new()).activity_sites.is_empty(), "base map sites")

	var literals: Array = []
	for path in SOURCES:
		var text := FileAccess.get_file_as_string(path)
		t.check("%s is readable" % path, text != "", "read %d bytes" % text.length())
		if text.contains("Color("):
			literals.append(path)
	t.check("no Color( literal in the two new source files", literals.is_empty(), "files with one: %s" % [literals])
