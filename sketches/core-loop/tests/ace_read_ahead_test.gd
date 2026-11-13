# smoke: solo timeout=180s
extends SceneTree

const Game := preload("res://src/game.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const Rows := preload("res://src/presentation/music_rows.gd")
const PhaseMusic := preload("res://src/presentation/phase_music.gd")
const T := preload("res://tests/support/t.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")

# A switch of ACE package read the new package's 24 Oggs on the main thread in its tick: 63 ms at
# each stage entry in the cloud, and part of the 4080's 114 to 118 ms Dig entry tick (board #934,
# 13 Nov 2026). audio.gd reads the packages a Warden's engage leads to (the next stage's band, and
# after a world's last stage the boss's entry anthem) and a boss's later phase packs on a worker,
# so the switch finds them kept. Counts and flags, not times. On stub stems.

var _t := T.new("ace_read_ahead_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	AceStub.install("ace_read_ahead_stub")
	var game := _start_game()
	var audio = game.presentation.audio
	var next: String = audio._music_row(2)["ace_manifest"]
	var later: String = audio._music_row(3)["ace_manifest"]
	_t.check("stage 2's band is not kept before the dam's Warden engages", next != "" and not Ace.kept(next), next)
	game.events.warden_engaged.emit(1)
	_t.check("the engage reads stage 2's band on a worker", audio._ace_ahead.has(next), str(audio._ace_ahead.keys()))
	audio._settle_ace_ahead(next)
	_t.check("stage 2's band is kept once the read is done", Ace.kept(next))
	_t.check("the engage reads nothing past the stage after it", not Ace.kept(later) and not audio._ace_ahead.has(later))
	var entry: String = Rows.resolve(audio._boss_entry(audio._boss_track()))["ace_manifest"]
	audio._read_ahead_after(2)
	audio._settle_ace_ahead(entry)
	audio._settle_ace_ahead(later)
	_t.check("after the world's last stage, the boss's entry anthem and the next world's band are kept",
		entry != "" and Ace.kept(entry) and Ace.kept(later), "%s %s" % [entry.get_base_dir().get_file(), later.get_base_dir().get_file()])
	var heavy: String = Rows.resolve(PhaseMusic.track_for_phase("brindle", 2, audio.pack_available))["ace_manifest"]
	audio._read_ahead_phases("brindle")
	audio._settle_ace_ahead(heavy)
	_t.check("the boss's phase 2 pack is read as the fight opens", heavy != "" and Ace.kept(heavy), heavy.get_base_dir().get_file())
	audio.ace_manifest = next
	var reads: int = audio._ace_ahead.size()
	audio.read_ace_ahead(heavy)
	_t.check("a kept package is not read again", audio._ace_ahead.size() == reads)
	for task in audio._ace_ahead.values():
		WorkerThreadPool.wait_for_task_completion(task)
	audio._ace_ahead.clear()
	game.queue_free()
	await process_frame
	quit(_t.verdict())


func _start_game() -> Node:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.set_frozen(true)
	var audio = game.presentation.audio
	audio.bake_now()
	audio.set_process(false)
	audio._flush_flow()
	return game
