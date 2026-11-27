extends SceneTree

const StageDefs := preload("res://src/core/stage_defs.gd")
const Terrain := preload("res://src/world/terrain.gd")
const T := preload("res://tests/support/t.gd")
const CodexEntries := preload("res://src/combat/codex_entries.gd")
const PendingContent := preload("res://tests/support/pending_content.gd")

# The release gate for the default table. A row whose name contains "placeholder" is a
# stage that cannot ship. While placeholders are expected this test reports each one as a
# skip and passes; sketch-export runs it with SCRAPKEEP_RELEASE_GATE=1, which makes each
# one a failure. Every other row's name must equal the title of its map. The same switch makes
# owed content a failure: every id in CodexEntries.DETECTOR_PENDING, and every map in
# PendingContent.SIDE_CONTENT_PENDING that a non-placeholder default-table row still uses.

var _t := T.new("release_gate_placeholder_test")


func _initialize() -> void:
	var enforce := OS.get_environment("SCRAPKEEP_RELEASE_GATE") == "1"
	var terrain = Terrain.new(StageDefs)
	var rows: Array = StageDefs.DEFS
	_t.check("maps built", terrain.maps.size() == rows.size(), "%d maps, %d rows" % [terrain.maps.size(), rows.size()])
	for i in rows.size():
		var row_name := str(rows[i].get("name", ""))
		if row_name.to_lower().contains("placeholder"):
			if enforce:
				_t.check("placeholder row %d" % (i + 1), false, row_name)
			else:
				print("[skip] placeholder row %d: %s" % [i + 1, row_name])
		else:
			var title := str(terrain.maps[i].title)
			_t.check("row %d name is its map title" % (i + 1), row_name == title, "name '%s' title '%s'" % [row_name, title])
	for id in CodexEntries.DETECTOR_PENDING:
		_owed("detector pending: %s" % id, enforce)
	for i in rows.size():
		var map_id := str(rows[i].get("map", ""))
		if PendingContent.SIDE_CONTENT_PENDING.has(map_id) and not str(rows[i].get("name", "")).to_lower().contains("placeholder"):
			_owed("side content pending: map %s (row %d, %s)" % [map_id, i + 1, rows[i].get("name", "")], enforce)
	quit(_t.verdict())


func _owed(item: String, enforce: bool) -> void:
	if enforce:
		_t.check(item, false, "owed before release")
	else:
		print("[skip] %s" % item)
