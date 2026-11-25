extends SceneTree


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
