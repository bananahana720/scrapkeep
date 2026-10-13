extends RefCounted


static func compare(a: String, b: String, bot_seed: int) -> Dictionary:
	var result := {"pass": true, "fields_differing": [], "files": {}}
	var records := []
	for folder in [a, b]:
		var path: String = folder.path_join("bots.ndjson")
		var rows := FileAccess.get_file_as_string(path).split("\n", false) if FileAccess.file_exists(path) else PackedStringArray()
		var parsed = JSON.parse_string(rows[-1]) if not rows.is_empty() else null
		if not parsed is Dictionary:
			return {"pass": false, "error": "missing bot record: " + path}
		parsed.erase("wall_seconds")
		records.append(parsed)
	var keys: Array = records[0].keys()
	for key in records[1]:
		if not key in keys:
			keys.append(key)
	for key in keys:
		if records[0].get(key) != records[1].get(key):
			result.fields_differing.append(key)
	result.pass = result.fields_differing.is_empty()
	for name in ["events-%d.ndjson" % bot_seed, "codex-log.ndjson", "runs.ndjson"]:
		var pa: String = a.path_join(name)
		var pb: String = b.path_join(name)
		var present := FileAccess.file_exists(pa) and FileAccess.file_exists(pb)
		var same := present and FileAccess.get_file_as_bytes(pa) == FileAccess.get_file_as_bytes(pb)
		result.files[name] = {"identical": same, "a_sha256": FileAccess.get_sha256(pa) if present else "",
			"b_sha256": FileAccess.get_sha256(pb) if present else ""}
		result.pass = result.pass and same
	return result
