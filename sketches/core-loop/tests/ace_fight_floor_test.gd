extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Music := preload("res://src/presentation/music_engine.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const T := preload("res://tests/support/t.gd")

# The shipped stem path mirrors the band engine's fight layering. The engine holds its
# melodic layers at the section floor (PRESSURE_FLOOR) in every fight: a Warden's build,
# lift, break and drop (0.55 to 1.0), a miniboss (0.8) and a boss phase (0.8 to 1.0). The
# Warden's open window is the held breath, where OPEN_GAINS drop every melodic layer. Before
# this test the ACE melody stem got a floor only in boss fights (#448), so a calm Warden or
# miniboss fight played with the stem silent.
#
# Calm fight (threat 0) on a stub stem pack in user:// (Brindle's anthem manifest, the
# committed tone as every stem; see ace_arena_release_test), each track forced on the engine.

const MANIFEST := "res://assets/music_ace/anthem_brindle/manifest.json"
# Made with: ffmpeg -f lavfi -i "sine=frequency=440:sample_rate=44100:duration=2" -ac 2 -c:a libvorbis -q:a 0 tone.ogg
const TONE := "res://tests/fixtures/ace_stub/tone.ogg"
# track, section, whether the engine's melody holds a floor there
const CASES := [
	["warden", "build", true], ["warden", "lift", true], ["warden", "break", true],
	["warden", "open", false], ["miniboss", "", true], ["brindle", "2", true], ["level", "", false],
]

var t := T.new("ace_fight_floor_test")


func _initialize() -> void:
	_run.call_deferred()


func _stub_pack() -> String:
	var dir := ProjectSettings.globalize_path("user://ace_stub_floor/anthem_brindle")
	DirAccess.make_dir_recursive_absolute(dir)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var tone := FileAccess.get_file_as_bytes(TONE)
	for clip in manifest["clips"].values():
		for stem in clip["files"]:
			FileAccess.open(dir.path_join(String(clip["files"][stem])), FileAccess.WRITE).store_buffer(tone)
	var path := dir.path_join("manifest.json")
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(manifest))
	return path


func _pump(audio, frames: int) -> void:
	var until: int = audio.engine.clock + frames
	while audio.engine.clock < until:
		audio._pump(mini(4096, until - audio.engine.clock))


func _melodic_up(engine) -> bool:
	return Music.MELODIC.any(func(l): return engine.layer_target(l) > 0.0)


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	var audio = game.presentation.audio
	audio.bake_now()
	audio.set_process(false)
	var engine = audio.engine
	game.ctx.calm = true
	Harness.start_run(game)
	audio._flush_flow()
	game.flow.enter_stage(1, Vector3.ZERO, false)
	audio._flush_flow()
	game.run.mass = 100.0
	var stub := Ace.new(_stub_pack())
	if not t.check("stub stem pack loads", stub.ready(), stub.missing):
		game.queue_free()
		await process_frame
		quit(t.verdict())
		return
	var bar: int = engine.step_len * Harmony.STEPS_PER_BAR
	# Let the stage entry's own track actions run before any track is forced.
	_pump(audio, engine.step_len * Harmony.STEPS_PER_BAR * Harmony.PHRASE_BARS * 2)
	for row in CASES:
		var track: String = row[0]
		var section: String = row[1]
		engine.force_track(track, 0, section)
		audio.ace = stub
		audio._ace_from = audio.ace_manifest
		stub.clock = engine.clock
		audio._prime_band_parameters()
		stub.start_boss(engine.clock) if track != "level" else stub.start_level(engine.clock)
		_pump(audio, bar * 2)
		var label := "%s%s" % [track, ":" + section if section != "" else ""]
		var engine_floor: float = engine._floor()
		var band_up := _melodic_up(engine)
		t.check("%s: calm fight (control)" % label, stub.pressure == 0.0 and not stub.parameter_released and engine.track == track,
			"pressure=%.2f released=%s track=%s section=%s" % [stub.pressure, stub.parameter_released, engine.track, engine.section])
		t.check("%s: band engine melody %s (control)" % [label, "up" if row[2] else "down"], band_up == row[2],
			"engine floor=%.2f" % engine_floor)
		var gain: float = stub.parameter_gain("other")
		if row[2]:
			t.check("%s: melody stem at the band floor" % label, gain >= engine_floor - 1e-6 and gain > 0.0,
				"other_gain=%.2f band floor=%.2f" % [gain, engine_floor])
		else:
			t.check("%s: melody stem follows the band down" % label, gain == 0.0, "other_gain=%.2f" % gain)
	game.queue_free()
	await process_frame
	quit(t.verdict())
