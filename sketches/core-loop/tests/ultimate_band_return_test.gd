extends SceneTree

const Game := preload("res://src/game.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const T := preload("res://tests/support/t.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")

# An ultimate takes the music for its flight: the stage's recorded band stops and the synth
# band plays the build and the landing drop (audio.gd _on_ultimate_started). When the drop
# is over the recorded band comes back (_on_ultimate_landed, _ace_return): the stage's own
# take while roaming, the fight's sections inside a sealed Warden fight (never the roaming
# take), and at once after a recall or a bail. A death or a stage's end brings nothing back,
# and neither does a Warden's break or a launch inside the drop, or a boss's pack.
# The real Game with the stage's recorded band (the stub tone tree in a checkout with no
# Oggs). Sections are read from the sequencer, not from speakers.

var t := T.new("ultimate_band_return_test")
var _game
var _audio
var _ace


func _initialize() -> void:
	_run.call_deferred()


func _bars(count: float) -> void:
	var until: int = _audio.engine.clock + int(_audio.engine.bar_len() * count)
	while _audio.engine.clock < until:
		_audio._pump(mini(4096, until - _audio.engine.clock))


func _state() -> String:
	return "mode=%s section=%s track=%s in_drop=%s" % [_ace.mode, _ace.section, _audio.engine.track, _audio.engine.in_drop()]


func _start() -> void:
	_game.events.ultimate_started.emit("test_ult", "", Vector3.ZERO, Vector3.ONE, 1.5)


func _land() -> void:
	_game.events.ultimate_landed.emit("test_ult", Vector3.ONE, 3, 100.0)


# Pumps until the synth band's drop is over, a beat at a time, and returns the modes the
# recorded band was in while the drop sounded.
func _through_the_drop() -> Array:
	var seen := []
	var guard := 0
	_bars(0.5)
	while (_audio.engine.in_drop() or guard < 2) and guard < 64:
		if _audio.engine.in_drop() and not _ace.mode in seen:
			seen.append(_ace.mode)
		_bars(0.25)
		guard += 1
	return seen


func _run() -> void:
	if not Array(DirAccess.get_files_at("res://assets/music_ace/spillway")).any(func(name): return name.ends_with(".ogg")):
		AceStub.install()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.player.set_frozen(true)
	_audio = _game.presentation.audio
	_audio.bake_now()
	_audio.set_process(false)
	_audio._flush_flow()
	_ace = _audio.ace
	_bars(2)
	if not t.check("the stage's recorded band plays", _audio.ace_playing() and _ace.mode == "level", _state()):
		_game.queue_free()
		await process_frame
		quit(t.verdict())
		return
	_roaming()
	_cancels()
	_warden()
	_game.flow.warden = null
	_game.queue_free()
	await process_frame
	quit(t.verdict())


func _roaming() -> void:
	_start()
	t.check("the flight takes the music from the recorded band", not _audio.ace_playing(), _state())
	_bars(1)
	_land()
	t.check("the landing does not bring it back on the hit", not _audio.ace_playing(), _state())
	var during := _through_the_drop()
	t.check("the synth band's drop plays alone", during == ["off"], "recorded band modes during the drop: %s" % [during])
	_bars(2)
	t.check("the stage's recorded band is back after the drop", _audio.ace_playing() and _ace.mode == "level" and _audio.engine.grid == _ace, _state())
	_bars(8)
	t.check("and it stays", _audio.ace_playing() and _ace.mode == "level", _state())


func _cancels() -> void:
	_start()
	_game.events.ultimate_cancelled.emit("test_ult", "bail", false)
	_bars(2)
	t.check("a bail brings the band back at the next bar", _audio.ace_playing() and _ace.mode == "level", _state())
	_start()
	_game.events.ultimate_cancelled.emit("test_ult", "recall", true)
	_bars(2)
	t.check("a recall does too", _audio.ace_playing() and _ace.mode == "level", _state())
	for reason in ["death", "stage"]:
		_start()
		_game.events.ultimate_cancelled.emit("test_ult", reason, false)
		_bars(2)
		t.check("a cancel for %s brings nothing back" % reason, not _audio.ace_playing() and _audio._ace_arrival_stage == 0, _state())
		# A landing that never came must not leave a booking for the next ultimate to trip on.
		t.check("and leaves nothing booked (%s)" % reason, not _audio._ult_took_band and not _audio._ult_armed)
		_audio._ace_stage(1, _audio.engine.next_bar())
		_bars(2)
	# An ultimate fired with the recorded band already stopped books nothing.
	_audio._ace_end()
	_bars(1)
	_start()
	_bars(1)
	_land()
	_through_the_drop()
	_bars(2)
	t.check("a band that was not playing is not started by an ultimate", not _audio.ace_playing(), _state())
	_audio._ace_stage(1, _audio.engine.next_bar())
	_bars(2)


func _warden() -> void:
	var guard := Node3D.new()
	root.add_child(guard)
	_game.flow.warden = guard
	_game.events.warden_engaged.emit(1)
	_game.flow.sealed = true
	_bars(4)
	if not t.check("the fight's sections play", _ace.mode == "warden" and _ace.section == "build", _state()):
		return
	_start()
	_bars(1)
	_land()
	var opened: int = _ace.opened
	# The return is watched a beat at a time from the landing: the roaming take (the shelf's
	# clips) must never sound in the arena.
	var heard := []
	for i in 48:
		_bars(0.25)
		var now := "%s/%s" % [_ace.mode, _ace.section]
		if not now in heard:
			heard.append(now)
	t.check("in a Warden fight the band comes back to the fight", _audio.ace_playing() and _ace.mode == "warden" and _ace.section == "build", _state())
	t.check("the roaming take never plays in the arena", not heard.any(func(now: String): return now.begins_with("level") or now.get_slice("/", 1) in Ace.SHELF_CLIPS),
		"on the way back: %s" % [heard])
	# The pivot and then the build: two sections' stems, and none for a roaming take opened
	# only to be thrown away.
	t.eq("the way back opens the pivot and the build and nothing else", _ace.opened - opened, _ace.stems.size() * 2)
	_start()
	_game.events.ultimate_cancelled.emit("test_ult", "bail", false)
	_bars(2)
	t.check("a bail in the fight goes back to the fight", _audio.ace_playing() and _ace.mode == "warden", _state())
	_moved_on()


# The music moves on while the ultimate holds the recorded band: nothing is booked back.
func _moved_on() -> void:
	# The Warden breaks inside the ultimate's drop: the break and the kill cadence are the
	# synth band's, and the roaming take must not start over them.
	_start()
	_bars(1)
	_land()
	_bars(1)
	_audio._flow_queue.append(["unseal"])
	_audio._flush_flow()
	var came_back := false
	for i in 64:
		_bars(0.25)
		came_back = came_back or _audio.ace_playing()
	t.check("a Warden broken inside the ultimate's drop keeps the break", not came_back and _audio._ace_arrival_stage == 0, _state())
	# The ultimate still in the air when the Warden breaks books nothing at its landing.
	_audio._ace_stage(1, _audio.engine.next_bar())
	_bars(2)
	_start()
	_audio._flow_queue.append(["unseal"])
	_audio._flush_flow()
	_bars(1)
	_land()
	_through_the_drop()
	_bars(2)
	t.check("so does one broken while the ultimate is in the air", not _audio.ace_playing() and _audio._ace_arrival_stage == 0, _state())
	# A launch inside the ultimate's drop: the launch's riser plays alone to the next stage.
	_game.flow.sealed = false
	_audio._ace_stage(1, _audio.engine.next_bar())
	_bars(2)
	_start()
	_bars(1)
	_land()
	_bars(1)
	t.check("the band is booked before the launch", _audio._ace_arrival_stage > 0, _state())
	_audio._on_launched(Vector3.UP)
	came_back = false
	for i in 48:
		_bars(0.25)
		came_back = came_back or _audio.ace_playing()
	t.check("a launch inside the ultimate's drop drops the booking", not came_back and _audio._ace_arrival_stage == 0, _state())
	_audio._disarm_launch()
	# A band that is not the stage's own (a boss's or a champion's pack) is not booked back.
	_audio._ace_stage(1, _audio.engine.next_bar())
	_bars(2)
	_ace.mode = "boss"
	_start()
	t.check("a boss's pack stopped by an ultimate books nothing", not _audio._ult_took_band, _state())
	_bars(1)
	_land()
	_through_the_drop()
	_bars(2)
	t.check("and the stage's take does not start in its place", not _audio.ace_playing(), _state())
