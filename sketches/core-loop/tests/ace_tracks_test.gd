extends SceneTree

const Game := preload("res://src/game.gd")
const Rows := preload("res://src/presentation/music_rows.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Intent := preload("res://src/movement/intent.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const PhaseMusic := preload("res://src/presentation/phase_music.gd")

const ZONES := ["spillway", "cable_reach", "dig_upper", "dig_deep", "highdraft", "highdraft_crown"]
const NEW_TRACKS := ["cable_reach", "dig_upper", "dig_deep", "highdraft", "highdraft_crown", "brindle", "waking", "mind", "title", "summary"]
var _game
var _done := false
var _failures := 0


# The Oggs are gitignored, so a fresh worktree has none: the test SKIPs (exit 0) when the
# music package holds no Ogg, and still fails when Oggs exist but a track is broken.
# ACE_MUSIC_DIR overrides the folder searched, so the SKIP path is provable without
# touching the real package.
func _oggs_in(dir: String) -> int:
	var count := 0
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".ogg"):
			count += 1
	for sub in DirAccess.get_directories_at(dir):
		# The single-loop phase packs (flat_pack_test) say nothing about the Warden themes.
		if FileAccess.file_exists(dir.path_join(sub).path_join("manifest.json")) \
				and bool(JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(sub).path_join("manifest.json"))).get("flat", false)):
			continue
		count += _oggs_in(dir.path_join(sub))
	return count


func _initialize() -> void:
	var dir := OS.get_environment("ACE_MUSIC_DIR")
	if dir == "":
		dir = "res://assets/music_ace"
	if _oggs_in(dir) == 0:
		print("ace_tracks_test: SKIP (no Oggs under %s; the music package is gitignored)" % dir)
		_done = true
		quit(0)
		return
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[%s] -> %s" % [label, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	_done = true
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	var audio = _game.presentation.audio
	audio.set_process(false)
	audio.bake_now()
	_game.tuning.set_option(Tuning.MUSIC_KEY, "ace")
	_game.events.flow_changed.emit("title")
	audio._flush_flow()
	# The sound bible's picks play where their Oggs are on disk, the older packs elsewhere.
	_selected(audio, _theme(audio.title_now()))
	var title = audio.ace
	var pending: Dictionary = title.pending.duplicate() if title != null else {}
	_game.events.flow_changed.emit("class_select")
	audio._flush_flow()
	_check("class select preserves the title phrase", audio.ace == title and title != null and title.pending == pending)
	_game.flow.press_start()
	_game.flow.choose_class(0)
	for stage in range(1, 7):
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
		audio._flush_flow()
		_check("zone %d selects %s" % [stage, ZONES[stage - 1]], audio.ace_manifest.get_base_dir().get_file() == ZONES[stage - 1])
		# The accepted Spillway Oggs are supplied separately by the coordinator.
		if stage > 1:
			_selected(audio, ZONES[stage - 1])
	for world in range(1, 4):
		_game.flow.enter_stage(world * 2, Vector3.ZERO, false)
		audio._flush_flow()
		_game.flow.enter_boss(Vector3.ZERO)
		_selected(audio, _theme(PhaseMusic.entry_track(["brindle", "waking", "mind"][world - 1], PhaseMusic.available)))
		_check("boss entry schedules the pivot", audio.ace != null and audio.ace.mode == "warden" and audio.ace.section == "pivot")
	_game.events.run_ended.emit(true)
	audio._flush_flow()
	_selected(audio, "summary")
	_check("won summary starts its cadence", audio.ace != null and audio.ace.section == "return")
	_game.events.run_ended.emit(false)
	audio._flush_flow()
	_selected(audio, "summary")
	_check("lost summary starts travel directly", audio.ace != null and audio.ace.section == "travel")
	if audio.ace != null:
		audio.ace.set_pressure(1.0)
		_check("pressure cannot turn loss into a win", audio.ace.section == "travel")
	_fallbacks(audio)
	_game.free()
	print("ace_tracks_test: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)
	return true


func _theme(row: String) -> String:
	return Rows.resolve(row)["ace_manifest"].get_base_dir().get_file()


func _selected(audio, track: String) -> void:
	_check(track + " ready through the director", audio.ace != null and audio.ace.ready() and audio.ace.manifest.get("theme") == track and audio.engine.grid == audio.ace)
	if audio.ace == null or not audio.ace.ready():
		return
	_check(track + " cuts are explicitly provisional", audio.ace.manifest.get("cuts") == "nominal-unverified" and not audio.ace.manifest.get("timing_verified", true))
	var at: int = audio.ace.pending.get("at", audio.ace.clock)
	var frames := maxi(1, at - audio.ace.clock + 2048)
	var got: PackedVector2Array = audio.ace.render(frames)
	audio.engine.render(frames)
	_check(track + " decodes real Oggs without short reads", got.size() > 0 and audio.ace.short_reads == 0 and audio.ace.misses == 0)


func _fallbacks(audio) -> void:
	var tmp := OS.get_temp_dir().path_join("ace_tracks_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(tmp)
	for track in NEW_TRACKS:
		var source: String = Rows.resolve(track if track in ["brindle", "waking", "mind", "title", "summary"] else
			["1-2", "2-1", "2-2", "3-1", "3-2"][NEW_TRACKS.find(track)])["ace_manifest"]
		if source == "":
			_check(track + " manifest exists for fallback test", false)
			continue
		var manifest := tmp.path_join("manifest.json")
		_check(track + " bare manifest copied", DirAccess.copy_absolute(source, manifest) == OK)
		var absent := Ace.new(manifest)
		_check(track + " absent Ogg is unready and named", not absent.ready() and absent.missing.ends_with(".ogg"))
		if track in ["brindle", "waking", "mind"]:
			_game.flow.enter_stage((["brindle", "waking", "mind"].find(track) + 1) * 2, Vector3.ZERO, false)
			audio._flush_flow()
		audio._ace_end()
		audio.ace_manifest = manifest
		audio._ace_failed = false
		audio.ace_missing = ""
		if track in ["brindle", "waking", "mind"]:
			_game.flow.enter_boss(Vector3.ZERO)
		elif track == "title":
			_game.events.flow_changed.emit("title")
		elif track == "summary":
			_game.events.run_ended.emit(false)
		else:
			_game.flow.enter_stage(NEW_TRACKS.find(track) + 2, Vector3.ZERO, false)
		audio._flush_flow()
		_check(track + " fallback leaves synth audible", not audio.ace_playing() and audio.engine.grid == null and not audio.engine.band_muted and audio._ace_failed and audio.ace_missing.ends_with(".ogg"))
		audio.engine.render(1024)
		_check(track + " fallback renders through synth", audio.engine.out_music.size() == 1024)
		if track == "summary":
			_game.events.run_ended.emit(true)
			audio._flush_flow()
			_check("won summary also falls back to synth", not audio.ace_playing() and audio.engine.grid == null and not audio.engine.band_muted and audio._ace_failed)
		DirAccess.remove_absolute(manifest)
	DirAccess.remove_absolute(tmp)
