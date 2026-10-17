extends SceneTree

const MusicRows := preload("res://src/presentation/music_rows.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const T := preload("res://tests/support/t.gd")

# Each park stage plays stingers cut from its own ACE pack (tools/ace/cut_stingers.py). The
# synth row is the fallback when a stage has no file for a cue.

var _t := T.new("park_stinger_test")


func _initialize() -> void:
	var zones := {}
	for stage in range(1, ParkDefs.COUNT + 1):
		zones[stage] = MusicRows.zone_id(stage, ParkDefs)
	_t.eq("six park stages", zones.size(), 6)
	var by_cue := {}
	for stage in zones:
		var zone: String = zones[stage]
		var map_id: String = ParkDefs.of(stage)["map"]
		var cues := _park_cues(map_id)
		_t.check("%s (%s) names park cues" % [zone, map_id], cues.size() >= 8, str(cues))
		for cue in cues:
			var row := MusicRows.cue(cue, {"stage": zone, "theme": 0, "ancient": "reactor", "motif": "sable"})
			var want := SfxBank.stinger_id(zone, cue)
			_t.check("%s %s resolves to its own file" % [zone, cue], row.get("stinger", false) and row.get("sound", "") == want, str(row.get("sound", "")))
			var samples := SfxBank.file_samples(want)
			_t.check("%s %s file has audio" % [zone, cue], samples.size() > 4000, str(samples.size()))
			var path := SfxBank.file_path(want)
			if not by_cue.has(cue):
				by_cue[cue] = {}
			by_cue[cue][zone] = FileAccess.get_sha256(path)
	for cue in by_cue:
		var seen := {}
		for zone in by_cue[cue]:
			seen[by_cue[cue][zone]] = zone
		_t.eq("%s is cut separately in every stage that uses it" % cue, seen.size(), by_cue[cue].size())

	_fallback_checks()
	_riser_landing_checks()
	quit(_t.verdict())


func _park_cues(map_id: String) -> Array:
	var text := FileAccess.get_file_as_string("res://src/world/park/%s.json" % map_id)
	var data = JSON.parse_string(text)
	var out := {}
	for row in data["event_rows"]:
		out[row["music_cue"]["telegraph"]] = true
		out[row["music_cue"]["land"]] = true
	var ids := out.keys()
	ids.sort()
	return ids


func _fallback_checks() -> void:
	var options := {"theme": 0, "ancient": "reactor", "motif": "sable"}
	for cue in ["drop_flood", "riser_natural", "drop_boiler", "riser_mind_quote"]:
		var plain := MusicRows.cue(cue, options)
		var missing_stage := options.duplicate()
		missing_stage["stage"] = "9-9"
		_t.eq("a stage with no files falls back to the synth row for %s" % cue, MusicRows.cue(cue, missing_stage), plain)
		_t.check("%s synth fallback has notes" % cue, plain.has("notes") and not plain.has("stinger"))
	# A real stage with no file for this cue: stage 1-1's park never lands drop_impact.
	var no_file := options.duplicate()
	no_file["stage"] = "1-1"
	_t.check("1-1 has no drop_impact file", not SfxBank.file_exists(SfxBank.stinger_id("1-1", "drop_impact")))
	_t.eq("1-1 drop_impact is the synth row", MusicRows.cue("drop_impact", no_file), MusicRows.cue("drop_impact", options))
	# The synth aliases stay distinct from their targets only through files.
	var aliased := MusicRows.cue("drop_boiler", options)
	_t.eq("drop_boiler without a stage is drop_industrial's synth row", aliased, MusicRows.cue("drop_industrial", options))


func _active(e) -> Array:
	return e._actions.filter(func(a): return a.get("type") == "park_cue")


func _riser_landing_checks() -> void:
	var options := {"stage": "3-1", "theme": 2, "ancient": "mind", "motif": "sable"}
	var riser_length: int = SfxBank.file_samples(SfxBank.stinger_id("3-1", "riser_fleet")).size()
	_t.check("the riser file is a bar long", riser_length > 60000, str(riser_length))
	for lead: int in [riser_length * 4, riser_length, riser_length - 5000, 20000]:
		var e = MusicEngine.new()
		e.band_muted = true
		var landing: int = 100000 + lead
		e.park_cue("riser_fleet", lead, 100000, options, 0.0, "ev")
		e.park_cue("drop_fleet_anvil", 0, landing, options, 0.0, "ev")
		var actions := _active(e)
		var files := actions.filter(func(a): return a.row.get("stinger", false) and a.row.rise)
		var drops := actions.filter(func(a): return not a.row.rise)
		_t.eq("lead %d: one file riser and one drop" % lead, [files.size(), drops.size()], [1, 1])
		if files.size() != 1 or drops.size() != 1:
			continue
		var file: Dictionary = files[0]
		_t.eq("lead %d: the riser ends on the drop's frame" % lead, int(file.at) + int(file.length), int(drops[0].at))
		_t.eq("lead %d: the drop is at the landing" % lead, int(drops[0].at), landing)
		_t.check("lead %d: the drop plays a file" % lead, drops[0].row.get("stinger", false))
		var synth := actions.filter(func(a): return a.row.rise and not a.row.get("stinger", false))
		var latest := 0
		for a in synth:
			latest = maxi(latest, int(a.at) + int(a.length))
			_t.check("lead %d: synth cells sit before the file" % lead, int(a.at) >= 100000)
		_t.check("lead %d: synth ends by the file's start" % lead, synth.is_empty() or latest <= int(file.at), "%d vs %d" % [latest, file.at])
		if lead >= riser_length:
			_t.eq("lead %d: the whole file plays" % lead, int(file.length), riser_length)
			_t.eq("lead %d: it starts at landing minus its length" % lead, int(file.at), landing - riser_length)
		else:
			_t.eq("lead %d: a short lead starts now and trims the head" % lead, int(file.at), 100000)
			_t.eq("lead %d: the trim is the overhang" % lead, int(file.get("skip", 0)), riser_length - lead)
		var buf: PackedFloat32Array = e.park_cue_samples(file, 0)
		_t.eq("lead %d: the rendered riser length is the action length" % lead, buf.size(), int(file.length))
