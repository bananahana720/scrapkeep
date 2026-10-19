extends SceneTree

const T := preload("res://tests/support/t.gd")
const Core := preload("res://tools/attack_sheet_core.gd")

# The attack sheet generator (tools/attack_sheet.gd) run in-process into a temp dir:
# - every constant its map names exists (a renamed constant fails here, loudly, naming it);
# - each boss (Brindle, the Waking, the Mind) has at least three rows;
# - both output files are written, and the JSON parses back to the same row count;
# - damage rows carry a hull share and a hit count;
# - the LETHAL TELL < 0.6 s flags are reported and not failed on; the tuning units turn that
#   into a hard check.


func _initialize() -> void:
	var t := T.new("attack_sheet_test")
	var dir := OS.get_user_data_dir().path_join("attack-sheet-%d" % OS.get_process_id())
	var sheet: Dictionary = Core.new().write(dir)
	t.eq("map reads every constant it names", sheet["problems"], [])
	for group in Core.BOSS_GROUPS:
		var count := 0
		for row in sheet["rows"]:
			count += 1 if row["group"] == group else 0
		t.check("%s has at least 3 rows" % group, count >= 3, "%d rows" % count)
	var md := FileAccess.get_file_as_string(dir.path_join("attack-sheet.md"))
	t.check("markdown written", md.contains("## Brindle") and md.contains("## Mobs"), "%d bytes" % md.length())
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("attack-sheet.json")))
	t.check("json parses to the same rows", parsed is Dictionary and parsed["rows"].size() == sheet["rows"].size(), "%d rows" % sheet["rows"].size())
	var bad := 0
	for row in sheet["rows"]:
		if row["damage"] > 0.0 and (row["hits_to_kill"] == null or row["pct_hull_max"] <= 0.0 or row["tell_s"] == null):
			bad += 1
			print("incomplete damage row: %s / %s" % [row["group"], row["attack"]])
	t.eq("every damage row has a tell, a share of hull and a hit count", bad, 0)
	t.check("hulls read from the classes", sheet["header"]["hull_min"] > 0.0 and sheet["header"]["hull_max"] >= sheet["header"]["hull_min"],
		"%s to %s" % [sheet["header"]["hull_min"], sheet["header"]["hull_max"]])
	var flagged := 0
	for row in sheet["rows"]:
		if not row["flags"].is_empty():
			flagged += 1
			print("REPORT %s / %s: tell %s s, damage %s: %s" % [row["group"], row["attack"], row["tell_s"], row["damage"], ", ".join(row["flags"])])
	for row in sheet["rows"]:
		for n in row.get("notices", []):
			print("NOTICE %s / %s: %s" % [row["group"], row["attack"], n])
	print("attack_sheet_test: %d rows, %d flagged (reported, not failed)" % [sheet["rows"].size(), flagged])
	quit(t.verdict())
