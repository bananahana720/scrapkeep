extends SceneTree

# Attack sheets generated from the game's own scripts (AMBITION-BRIEF, "Encounter craft").
#   $GODOT_BIN --headless --path sketches/core-loop --script res://tools/attack_sheet.gd -- --out=<dir>
# Writes <dir>/attack-sheet.md and <dir>/attack-sheet.json. Exit 1 when the map names a
# constant that no longer exists. The map and the reading live in attack_sheet_core.gd so the
# test can run the same generator in-process.

const Core := preload("res://tools/attack_sheet_core.gd")


func _initialize() -> void:
	var out := "artifacts/local/challenge/attack-sheet"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var sheet: Dictionary = Core.new().write(out)
	var flagged := 0
	for row in sheet["rows"]:
		if not row["flags"].is_empty():
			flagged += 1
			print("FLAG %s / %s: %s" % [row["group"], row["attack"], ", ".join(row["flags"])])
	for p in sheet["problems"]:
		printerr("attack_sheet problem: %s" % p)
	print("attack_sheet: %d rows, %d flagged, %d problems, written to %s" % [sheet["rows"].size(), flagged, sheet["problems"].size(), out])
	quit(0 if sheet["problems"].is_empty() else 1)
