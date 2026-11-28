extends SceneTree

# Rule: one music table resolves stage/boss packs; overrides win and absent manifests
# retain a valid synth theme silently. File lookup preserves source-first export sidecars.
const Rows := preload("res://src/presentation/music_rows.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const DefaultStages := preload("res://src/core/stage_defs.gd")
const AlphaStages := preload("res://src/core/alpha_defs.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")

var _failures := 0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _valid(pack: Dictionary) -> bool:
	var theme: int = pack["synth_theme"]
	var manifest: String = pack["ace_manifest"]
	return theme >= 0 and theme < Rows.THEME_COUNT and (manifest == "" or FileAccess.file_exists(manifest))


func _initialize() -> void:
	for stage in range(1, TwoWorld.COUNT + 1):
		var zone := "%d-%d" % [1 if stage <= 3 else 2, (stage - 1) % 3 + 1]
		_report("world-local zone id", Rows.zone_id(stage, TwoWorld) == zone, "stage %d -> %s, want %s" % [stage, Rows.zone_id(stage, TwoWorld), zone])
		_report("two-world override preserved", Rows.stage_theme(TwoWorld.of(stage), TwoWorld) == TwoWorld.of(stage)["music"]["theme"], "stage %d" % stage)
	_report("second world starts at 2-1", Rows.zone_id(4, TwoWorld) == "2-1", Rows.zone_id(4, TwoWorld))
	for table in [DefaultStages, AlphaStages]:
		for row in table.DEFS:
			var pack := Rows.resolve(row)
			_report("stage pack", _valid(pack), "%s: %s" % [row["name"], pack])
			_report("stage theme preserved", pack["synth_theme"] == row["music"]["theme"], str(pack))
			_report("synth uses rows", Rows.stage_theme(row) == pack["synth_theme"], str(pack))
	for id in Rows.ROWS:
		_report("table pack", _valid(Rows.resolve(id)), "%s: %s" % [id, Rows.resolve(id)])
	_report("unknown id uses default", Rows.resolve("unknown") == Rows.resolve("default"), str(Rows.resolve("unknown")))
	_report("empty stage uses default", Rows.resolve({}) == Rows.resolve("default"), str(Rows.resolve({})))
	var spillway := Rows.resolve("1-1")
	_report("Spillway keeps ACE name and theme", spillway["synth_theme"] == 0 and spillway["ace_manifest"] == Rows.resolve_manifest(Ace.MANIFEST), str(spillway))
	_report("Reach uses ACE with synth theme 1", Rows.resolve("1-2") == {"synth_theme": 1, "ace_manifest": Rows.resolve_manifest("res://assets/music_ace/cable_reach/manifest.json")}, str(Rows.resolve("1-2")))

	var tracks := {"2-1": "dig_upper", "2-2": "dig_deep", "3-1": "highdraft", "3-2": "highdraft_crown"}
	for zone in tracks:
		var theme := int(zone.split("-")[0]) - 1
		var path := Rows.resolve_manifest("res://assets/music_ace/%s/manifest.json" % tracks[zone])
		_report("zone declared", Rows.ROWS.has(zone), zone)
		_report("ACE retains fallback theme", path != "" and Rows.resolve(zone) == {"synth_theme": theme, "ace_manifest": path}, zone)
		var band = Ace.from_stage(zone)
		_report("zone manifest selects its track", band.manifest_source == path and band.manifest.get("theme") == tracks[zone]
			and (band.ready() or band.missing.ends_with(".ogg")), zone)

	var override := {"world": 1, "stage": 1, "music": {"theme": 2, "ace": ""}}
	_report("override wins over Spillway", Rows.resolve(override) == {"synth_theme": 2, "ace_manifest": ""} and Rows.stage_theme(override) == 2, str(Rows.resolve(override)))
	var other := {"world": 1, "stage": 2, "music": {"theme": 0, "ace": "spillway"}}
	_report("override selects existing ACE", Rows.resolve(other)["ace_manifest"] == spillway["ace_manifest"], str(Rows.resolve(other)))
	_report("override leaves sources intact", Rows.ROWS["1-1"]["synth_theme"] == 0 and override["music"]["theme"] == 2, "table and stage row unchanged")
	for value in [-100, 100]:
		_report("theme clamped", _valid(Rows.resolve({"music": {"theme": value, "ace": ""}})), "theme %d" % value)

	var absent := "res://tests/no_such_music_rows_manifest/manifest.json"
	var fallback := Rows.resolve_pack({"synth_theme": 2, "ace_manifest": absent})
	_report("missing manifest falls back", fallback == {"synth_theme": 2, "ace_manifest": ""}, str(fallback))
	var missing_override := {"world": 1, "stage": 1, "music": {"theme": 1, "ace": "no_such_music_rows_pack"}}
	var quiet := true
	for attempt in 5:
		var band = Ace.from_stage(missing_override)
		quiet = quiet and not band.ready() and band.missing == "" and Rows.resolve(missing_override) == {"synth_theme": 1, "ace_manifest": ""}
	_report("repeated missing override is quiet", quiet, "five unready bands without loading a missing file")
	var reach = Ace.from_stage("1-2")
	_report("Reach selects its package", reach.manifest.get("theme") == "cable_reach" and (reach.ready() or reach.missing.ends_with(".ogg")), reach.manifest_source)
	var band = Ace.from_stage("1-1")
	_report("ACE uses resolved row path", band.manifest_source == spillway["ace_manifest"], band.manifest_source)
	_report("ACE stage factory reads Spillway", band.manifest.get("theme") == "spillway" and (band.ready() or band.missing.ends_with(".ogg")), "ready=%s missing=%s" % [band.ready(), band.missing])
	var later = Ace.from_stage(4, "", TwoWorld)
	_report("ACE accepts the active table", later.manifest_source == Rows.resolve(TwoWorld.of(4), "", TwoWorld)["ace_manifest"], later.manifest_source)
	_sidecar()
	print("music_rows_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _sidecar() -> void:
	var tmp := OS.get_temp_dir().path_join("music_rows_test_%d" % OS.get_process_id())
	var resource := "res://assets/music_ace/no_such_music_rows_manifest/manifest.json"
	var file := tmp.path_join("music_ace/no_such_music_rows_manifest/manifest.json")
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var handle := FileAccess.open(file, FileAccess.WRITE)
	if handle == null:
		_report("sidecar fixture", false, "could not write temporary manifest")
		return
	handle.store_string("{}")
	handle.close()
	var pack := Rows.resolve_pack({"synth_theme": 1, "ace_manifest": resource}, tmp)
	_report("sidecar pack found", pack == {"synth_theme": 1, "ace_manifest": file}, str(pack))
	_report("source manifest found", Rows.resolve_manifest(Ace.MANIFEST, tmp) == ProjectSettings.globalize_path(Ace.MANIFEST), "committed Spillway manifest found")
	DirAccess.remove_absolute(file)
	DirAccess.remove_absolute(file.get_base_dir())
	DirAccess.remove_absolute(tmp.path_join("music_ace"))
	DirAccess.remove_absolute(tmp)
