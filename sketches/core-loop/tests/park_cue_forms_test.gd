extends SceneTree

# CUE-FORMS: every music cue a park event row names (telegraph and land, through aliases)
# resolves to a MusicRows record with a family, a voice and at least one note, and every
# trim_sound and sound on those records names a level in SfxBank's own TRIM_DB.

const MusicRows := preload("res://src/presentation/music_rows.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const PARK_DIR := "res://src/world/park"
const FIXTURE := "res://tests/fixtures/park_cue_forms_pending.json"
# Exact counts for the repository as it stands (2026-10-13): 26 park rows plus 11 fixture rows,
# 19 distinct cue ids, 2 resolution checks per row (74) and 1 bank check per distinct id (19).
# A stage merge changes them; the new values are re-pinned with a dated header.
const EXPECTED_ROWS := 37
const EXPECTED_DISTINCT := 19
const EXPECTED_CHECKS := 93

var _failures := 0
var _checks := 0
var _rows: Array = []


func _initialize() -> void:
	_collect()
	_resolution()
	_bank()
	_counts()
	var ok := _failures == 0 and _checks == EXPECTED_CHECKS
	print("park_cue_forms_test: PASS" if ok else "park_cue_forms_test: FAIL")
	quit(0 if ok else 1)


func _collect() -> void:
	var dir := DirAccess.open(PARK_DIR)
	var names := []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".json"):
			names.append(name)
		name = dir.get_next()
	names.sort()
	for file in names:
		_add_rows(PARK_DIR + "/" + file, file)
	_add_rows(FIXTURE, "fixture")


func _add_rows(path: String, source: String) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_check("%s parses" % source, false, path)
		return
	for row in parsed.get("event_rows", []):
		_rows.append({"source": source, "id": str(row.id), "music_cue": row.music_cue})


func _resolution() -> void:
	for entry in _rows:
		for phase in ["telegraph", "land"]:
			var cue := str(entry.music_cue[phase])
			var row: Dictionary = MusicRows.cue(cue)
			var ok: bool = not row.is_empty() and str(row.get("family", "")) != "" \
				and str(row.get("voice", "")) != "" and row.get("notes", []).size() > 0
			_check("%s %s %s" % [entry.source, entry.id, phase], ok,
				"cue=%s resolves=%s" % [cue, not row.is_empty()])


func _bank() -> void:
	var distinct := _distinct_cues()
	for cue in distinct:
		var row: Dictionary = MusicRows.cue(cue)
		var trim_ok := row.has("trim_sound") and SfxBank.has_recipe(str(row.trim_sound))
		var sound_ok := not row.has("sound") or SfxBank.has_recipe(str(row.sound))
		_check("bank %s" % cue, trim_ok and sound_ok,
			"trim=%s sound=%s trim_level=%s sound_level=%s" % [row.get("trim_sound", ""), row.get("sound", ""), trim_ok, sound_ok])


func _counts() -> void:
	var distinct := _distinct_cues()
	print("park_cue_forms_test: rows %d (expected %d), distinct cue ids %d (expected %d), checks %d (expected %d)"
		% [_rows.size(), EXPECTED_ROWS, distinct.size(), EXPECTED_DISTINCT, _checks, EXPECTED_CHECKS])
	if _rows.size() != EXPECTED_ROWS or distinct.size() != EXPECTED_DISTINCT:
		_failures += 1


func _distinct_cues() -> Array:
	var seen := {}
	for entry in _rows:
		seen[str(entry.music_cue.telegraph)] = true
		seen[str(entry.music_cue.land)] = true
	var out := seen.keys()
	out.sort()
	return out


func _check(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	_failures += int(not ok)
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
