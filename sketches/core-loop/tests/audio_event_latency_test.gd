extends SceneTree

const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")

# INTEGRATION section 1, target one: a gameplay sound starts on the frame its event
# happens, at most one frame (16.7 ms at 60 fps) from the event to the play call. Each
# event is emitted on the real bus, and the test counts process frames from the emit to
# the frame Audio made its play_stream call (Audio.last_play_frame). The asset side has its
# own 5 ms onset check (check_events.py); this is the engine side.
#
# Planted control: SOUNDINT_PLANT=delay emits each event PLANTED_FRAMES frames late, as a
# handler that waits for a later frame would, and the test must then fail. The same plant
# also runs inside every pass as a detector check, so a green run proves the counter can
# see a delay.

const MAX_FRAMES := 1
const PLANTED_FRAMES := 2

var t := T.new("audio_event_latency_test")
var _plant := OS.get_environment("SOUNDINT_PLANT") == "delay"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
	await process_frame
	var events = game.events
	var cases := {
		"hit (enemy killed)": func(): events.enemy_killed.emit("drone", Vector3.ZERO, 1),
		"stomp (slammed)": func(): events.slammed.emit(Vector3.ZERO, 1.0, 1.0),
		"wall bash (landed)": func(): events.landed.emit(20.0),
		"hurt (player hit)": func(): events.player_hit.emit(10.0, "drone"),
		"telegraph (boss wind-up)": func(): events.boss_attack_telegraphed.emit("slam", 0.5),
	}
	var worst := 0
	for label in cases:
		var frames: int = await _frames(audio, cases[label], PLANTED_FRAMES if _plant else 0)
		worst = maxi(worst, frames)
		t.check("%s plays within %d frame" % [label, MAX_FRAMES], frames >= 0 and frames <= MAX_FRAMES, "%d frames" % frames)
	# Detector control: an event emitted late must read as late.
	var late: int = await _frames(audio, cases["hurt (player hit)"], PLANTED_FRAMES)
	t.check("a planted %d-frame delay is seen as late" % PLANTED_FRAMES, late > MAX_FRAMES, "%d frames" % late)
	print("EVENT_LATENCY worst_frames=%d max_frames=%d plant=%s" % [worst, MAX_FRAMES, str(_plant)])
	game.queue_free()
	await process_frame
	quit(t.verdict())


# Process frames from the event to Audio's play_stream call; -1 when nothing played. A delay
# holds the emit back that many frames, the event itself being counted from the request.
func _frames(audio, emit: Callable, delay: int) -> int:
	audio._last_start.clear()
	var frame := Engine.get_process_frames()
	var played: int = audio.cue_log_total
	audio.last_play_frame = -1
	if delay == 0:
		emit.call()
	else:
		for i in delay:
			await process_frame
		emit.call()
	var sounded := false
	for cue in audio.cues_since(played):
		sounded = sounded or cue[2] == "now"
	return audio.last_play_frame - frame if sounded and audio.last_play_frame >= 0 else -1
