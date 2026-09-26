extends SceneTree

const GameEvents := preload("res://src/core/game_events.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

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
	var toasts_without_words: Array[String] = []
	for kind in names:
		if EventKinds.priority(kind) >= 3 and EventKinds.row(kind).get("hud", "") == "" and EventKinds.row(kind).get("objective", "") == "":
			toasts_without_words.append(kind)

	var checks := [
		["coverage", missing.is_empty(), "%d signals on the bus, %d without a row %s" % [names.size(), missing.size(), missing]],
		["row shape", malformed.is_empty(), "%d rows missing a field or out of range %s" % [malformed.size(), malformed]],
		["orphans", orphans.is_empty(), "%d rows naming no signal %s" % [orphans.size(), orphans]],
		["critical wording", toasts_without_words.is_empty(), "%d priority-3 kinds with no HUD or objective wording %s" % [toasts_without_words.size(), toasts_without_words]],
	]
	for check in checks:
		if not check[1]:
			failures += 1
		print("[%s] %s -> %s" % [check[0], check[2], "PASS" if check[1] else "FAIL"])
	print("spine_event_kinds_test: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
