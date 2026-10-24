extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const T := preload("res://tests/support/t.gd")

# The ACE stem player keeps its own copy of the band's release (audio.gd primes it from the
# engine's committed value, and each phrase commit is a queued "parameters" action). Before
# this test the arena cleared only the engine's flag, so on the PC checkout with all stems
# Brindle's other stem (the melody) stayed at 0 for the whole fight after the flume Warden
# broke (PC run of music_brindle_release_test, 4 of 17 failed).
#
# The Oggs are gitignored, so this test builds a stub pack in user://: Brindle's anthem
# manifest with one committed 2 s tone (tests/fixtures/ace_stub/tone.ogg) as every stem.
# It installs that player as the live ACE band at the flume, breaks the Warden, queues a
# release commit, then enters the arena through flow.enter_boss and retries it.

const MANIFEST := "res://assets/music_ace/anthem_brindle/manifest.json"
const TONE := "res://tests/fixtures/ace_stub/tone.ogg"

var t := T.new("ace_arena_release_test")


func _initialize() -> void:
	_run.call_deferred()


func _stub_pack() -> String:
	var dir := ProjectSettings.globalize_path("user://ace_stub/anthem_brindle")
	DirAccess.make_dir_recursive_absolute(dir)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var tone := FileAccess.get_file_as_bytes(TONE)
	for clip in manifest["clips"].values():
		for stem in clip["files"]:
			var out := FileAccess.open(dir.path_join(String(clip["files"][stem])), FileAccess.WRITE)
			out.store_buffer(tone)
	var path := dir.path_join("manifest.json")
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(manifest))
	return path


# Pumps the real mix (synth band and the live ACE band) so commits are sent and run.
func _pump(audio, frames: int) -> void:
	var until: int = audio.engine.clock + frames
	while audio.engine.clock < until:
		audio._pump(mini(4096, until - audio.engine.clock))


func _queued_release(ace) -> bool:
	return ace.actions.any(func(a): return a["type"] == "parameters" and a["released"])


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
	game.flow.enter_stage(2, Vector3.ZERO, false)
	audio._flush_flow()
	game.run.mass = 100.0

	var stub := Ace.new(_stub_pack())
	if not t.check("stub stem pack loads", stub.ready(), stub.missing):
		game.queue_free()
		await process_frame
		quit(t.verdict())
		return
	audio.ace = stub
	audio._ace_from = audio.ace_manifest
	stub.clock = engine.clock
	audio._prime_band_parameters()
	stub.start_level(engine.clock)
	t.check("stub plays as the live ACE band", stub.parameter_enabled and stub.active())

	var phrase: int = engine.step_len * Harmony.STEPS_PER_BAR * Harmony.PHRASE_BARS
	_pump(audio, phrase + 1)
	game.flow._unseal()
	audio._flush_flow()
	_pump(audio, phrase + 1)
	t.check("flume Warden break releases the stems (control)", stub.parameter_released and stub.parameter_gain("other") == 0.0,
		"released=%s other=%.2f" % [stub.parameter_released, stub.parameter_gain("other")])
	# A Warden-break commit still in the queue when the run reaches the arena.
	stub.commit_parameters(engine.clock + phrase, stub.parameters, true, false, "")
	t.check("a release commit is queued (control)", _queued_release(stub))

	game.flow.enter_boss(Vector3.ZERO)
	game.boss.set_physics_process(false)
	t.check("arena entry clears the stems' release at once", not stub.parameter_released, "released=%s" % stub.parameter_released)
	t.check("arena entry voids the queued release", not _queued_release(stub))
	t.check("arena entry clears the engine's committed release", not engine.parameter_committed_released)
	audio.ace = stub
	_pump(audio, phrase * 2)
	t.check("stems stay open past the queued commit", not stub.parameter_released and stub.parameter_layer_log.all(func(e): return e["at"] < engine.clock - phrase * 2 or not e["released"]))
	# Brindle's own pack, when it loads after the arena opens, is primed from the engine.
	audio._prime_band_parameters()
	t.check("a newly primed ACE band starts open", not stub.parameter_released)

	# A retry clears it again, from any later release.
	audio.ace = stub
	stub.parameter_released = true
	stub.commit_parameters(stub.clock + phrase, stub.parameters, true, false, "")
	game.flow._retry_arena()
	t.check("arena retry clears the stems' release and voids the queued one", not stub.parameter_released and not _queued_release(stub))

	game.queue_free()
	await process_frame
	quit(t.verdict())
