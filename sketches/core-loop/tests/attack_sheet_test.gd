extends SceneTree

const T := preload("res://tests/support/t.gd")
const Core := preload("res://tools/attack_sheet_core.gd")

# The attack sheet generator (tools/attack_sheet.gd) run in-process into a temp dir:
# - every constant its map names exists (a renamed constant fails here, loudly, naming it);
# - each boss (Brindle, the Waking, the Mind) has at least three rows;
# - both output files are written, and the JSON parses back to the same row count;
# - damage rows carry a hull share and a hit count;
# - the sheet reads the effective dials (ChallengeDials), so Brindle's rows carry the tuned damage;
# - HARD: no Brindle attack that deals damage (the sheet's lethal-class definition: damage above 0)
#   has a tell under 0.6 s at the tuned values. Other groups' LETHAL TELL flags are still reported only.


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
	var brindle_damage := 0
	var short_tells: Array = []
	var tuned_seen := false
	for row in sheet["rows"]:
		if row["group"] != "Brindle" or row["damage"] <= 0.0:
			continue
		brindle_damage += 1
		tuned_seen = tuned_seen or row["damage"] > row["damage_base"] + 1e-6
		if row["tell_s"] == null or row["tell_s"] < Core.LETHAL_FLOOR - Core.EPS:
			short_tells.append("%s tell %s" % [row["attack"], str(row["tell_s"])])
	t.check("Brindle has damaging attacks on the sheet", brindle_damage >= 2, "%d" % brindle_damage)
	t.check("the sheet carries the tuned Brindle damage (above the base)", tuned_seen)
	t.eq("no Brindle attack that deals damage has a tell under 0.6 s at the tuned values", short_tells, [])
	var boss_flagged: Array = []
	for row in sheet["rows"]:
		if Core.BOSS_GROUPS.has(row["group"]) and row["flags"].has(Core.LETHAL_FLAG):
			boss_flagged.append("%s / %s" % [row["group"], row["attack"]])
	t.eq("no boss attack (Brindle, Waking, Mind) carries LETHAL TELL < 0.6 s", boss_flagged, [])
	# The sheet follows the dials: a doubled Brindle damage_mult doubles the slag row.
	ChallengeDials.set_overrides({"brindle.damage_mult": 2.0})
	var doubled: Dictionary = Core.new().build()
	ChallengeDials.reset()
	var slag_now := 0.0
	var slag_x2 := 0.0
	for row in sheet["rows"]:
		if row["group"] == "Brindle" and str(row["attack"]).begins_with("slag"):
			slag_now = row["damage"]
	for row in doubled["rows"]:
		if row["group"] == "Brindle" and str(row["attack"]).begins_with("slag"):
			slag_x2 = row["damage"]
	t.near("the sheet reads the effective dials (damage_mult 2 doubles the slag row)", slag_x2, slag_now * 2.0, 1e-6)
	# The stage dial: the dam (stage 1) ships mob hits at x1.5, so every damaging Mobs row carries its stage 1
	# numbers, and a Warden row (excluded at the hit door) carries none.
	var mob_rows := 0
	var mob_dialled := 0
	var warden_dialled := 0
	for row in sheet["rows"]:
		if row["group"] == "Mobs" and row["damage"] > 0.0:
			mob_rows += 1
			var at: Dictionary = row.get("stage_damage", {}).get("1", {})
			if not at.is_empty() and absf(float(at["damage"]) - row["damage"] * ChallengeDials.stage_mult("mobs.damage", 1)) < 1e-3:
				mob_dialled += 1
		if row["group"] == "Wardens" and row.has("stage_damage"):
			warden_dialled += 1
	t.check("Mobs has damaging rows", mob_rows > 0, "%d" % mob_rows)
	t.eq("every damaging Mobs row carries the dam's stage dial", mob_dialled, mob_rows)
	t.eq("no Warden row takes the mob dial", warden_dialled, 0)
	t.check("the markdown explains the stage dials", md.contains("Stage dials"))
	ChallengeDials.set_overrides({"mobs.damage_by_stage": ChallengeDials.ONES6})
	var identity: Dictionary = Core.new().build()
	ChallengeDials.reset()
	var any_stage := 0
	for row in identity["rows"]:
		any_stage += 1 if row.has("stage_damage") else 0
	t.eq("at identity no row carries stage damage", any_stage, 0)
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
