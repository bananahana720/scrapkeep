extends SceneTree

const GameEvents := preload("res://src/core/game_events.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const EventJuice := preload("res://src/presentation/event_juice.gd")

# Every GameEvents signal has exactly one well-formed event_kinds row, and every row
# names a real signal, so nothing a module publishes can reach the HUD, VFX or audio
# without a colour, shape, sound and wording.


func _initialize() -> void:
	var failures := 0
	var names := GameEvents.signal_names()
	var missing: Array[String] = []
	var malformed: Array[String] = []
	for kind in names:
		if not EventKinds.has(kind):
			missing.append(kind)
			continue
		var row := EventKinds.row(kind)
		var ok := true
		for field in EventKinds.FIELDS:
			ok = ok and row.has(field)
		ok = ok and row.get("group", "") in EventKinds.GROUPS
		ok = ok and row.get("shape", "") in EventKinds.SHAPES
		ok = ok and row.get("color") is Color
		ok = ok and String(row.get("sound", "")) != ""
		ok = ok and int(row.get("priority", -1)) >= 0 and int(row.get("priority", -1)) <= 3
		if not ok:
			malformed.append(kind)
	var orphans: Array[String] = []
	for kind in EventKinds.ROWS:
		if not kind in names:
			orphans.append(kind)
	var optional: Array[String] = []
	for kind in EventKinds.ROWS:
		if String(EventKinds.ROWS[kind]["objective"]).to_lower().contains("optional"):
			optional.append(kind)
	var categories_ok := true
	for id in EventKinds.CODEX_CATEGORIES:
		var cat: Dictionary = EventKinds.CODEX_CATEGORIES[id]
		categories_ok = categories_ok and cat.get("color") is Color and String(cat.get("label", "")) != "" \
			and cat.get("shape", "") in EventKinds.SHAPES
	var contracts := FileAccess.get_file_as_string("res://CONTRACTS.md")
	var rules := [
		"A foreseen, telegraphed cost from the player's own performance is allowed; an unforeseen stop is not.",
		"Every new mechanic names in its DESIGN-NOTES line the stage demand it serves (Warden, event, vault, boss phase) and the principle it strains; a mechanic that serves none is parked, not built.",
		"Heft never changes RigidBody mass, radius, torque or air control.",
	]
	var missing_rules: Array[String] = []
	for rule in rules:
		if not contracts.contains(rule):
			missing_rules.append(rule.left(40))
	# A priority-3 fact needs a carrier: words on the HUD or the objective, or its own weighted
	# beat (wave 36: Brindle's rout is carried by its climax beat, not a toast).
	var toasts_without_words: Array[String] = []
	for kind in names:
		if EventKinds.priority(kind) >= 3 and EventKinds.row(kind).get("hud", "") == "" and EventKinds.row(kind).get("objective", "") == "" \
				and not EventJuice.WEIGHTED.has(kind):
			toasts_without_words.append(kind)
	var event_kinds_source := FileAccess.get_file_as_string("res://src/core/event_kinds.gd")
	var upward_refs: Array[String] = []
	for forbidden in ["res://src/presentation/", "res://src/combat/"]:
		if event_kinds_source.contains(forbidden):
			upward_refs.append(forbidden)

	var checks := [
		["coverage", missing.is_empty(), "%d signals on the bus, %d without a row %s" % [names.size(), missing.size(), missing]],
		["row shape", malformed.is_empty(), "%d rows missing a field or out of range %s" % [malformed.size(), malformed]],
		["orphans", orphans.is_empty(), "%d rows naming no signal %s" % [orphans.size(), orphans]],
		["critical wording", toasts_without_words.is_empty(), "%d priority-3 kinds with no HUD or objective wording and no weighted beat %s" % [toasts_without_words.size(), toasts_without_words]],
		["contract rules", missing_rules.is_empty(), "%d of %d required rules missing from CONTRACTS.md %s" % [missing_rules.size(), rules.size(), missing_rules]],
		["no optional", optional.is_empty(), "%d objectives use the word optional %s" % [optional.size(), optional]],
		["codex categories", categories_ok and EventKinds.CODEX_CATEGORIES.size() == 5, "%d codex categories, each with a colour, label and shape" % EventKinds.CODEX_CATEGORIES.size()],
		["no upward layer refs", upward_refs.is_empty(), "event_kinds.gd contains forbidden layer paths %s" % [upward_refs]],
	]
	for check in checks:
		if not check[1]:
			failures += 1
		print("[%s] %s -> %s" % [check[0], check[2], "PASS" if check[1] else "FAIL"])
	print("spine_event_kinds_test: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
