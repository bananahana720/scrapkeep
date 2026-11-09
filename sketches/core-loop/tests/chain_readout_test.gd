extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const T := preload("res://tests/support/t.gd")

# The hook chain is seen and heard (design-v3/HOOK-CHAIN.md, "One source, every layer"):
#   a  the HUD counter is hidden at combo 0 and 1, shown at 2 and up, its text the combo
#   b  the counter falls and hides after the chain ends
#   c  the collar carries min(links, 6) rings, none at one link, cleared on chain_end
#   d  chain_link plays line_bite a rung of the pentatonic higher per link, none at one link, capped at six links
#   e  chain_end plays one line_zip only for a combo of 2 or more, none when the smash paid
#   f  a dry_fire and a chain_miss together make one dry_tick
#   g  no chain id changes the line view's state or stops the hum

var _t := T.new("chain_readout_test")
var _game
var _player


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(ticks: int) -> void:
	for i in ticks:
		await physics_frame


func _set_chain(links: int) -> void:
	_player.chain.links = links
	_player.chain.combo = links


func _fresh(audio) -> void:
	audio.cue_log.clear()
	audio._last_start.clear()
	audio._gates.clear()
	audio._chain_bite_ms = -100000.0


func _cues(audio, sound: String) -> Array:
	var out: Array = []
	for entry in audio.cue_log:
		if entry[1] == sound and entry[2] == "now":
			out.append(entry)
	return out


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(40)
	var view = _game.presentation.line_view
	var audio = _game.presentation.audio
	var counter = _game.hud.chain_counter
	var events = _player.events
	audio.bake_now()

	# a, b: the counter
	for combo in [0, 1]:
		counter.step(0.016, combo)
		_t.check("a counter hidden at combo %d" % combo, not counter.visible, "visible %s" % counter.visible)
	counter.step(0.016, 2)
	_t.check("a counter visible at 2 reading 2", counter.visible and counter.text() == "2", "visible %s text '%s'" % [counter.visible, counter.text()])
	counter.step(0.016, 4)
	_t.check("a counter reads 4 at combo 4", counter.visible and counter.text() == "4", "text '%s'" % counter.text())
	counter.step(0.1, 0)
	_t.check("b counter still falls 0.1 s after the end", counter.visible, "visible %s" % counter.visible)
	counter.step(0.4, 0)
	_t.check("b counter hidden after the fall", not counter.visible, "visible %s" % counter.visible)

	# a: not playing, the counter is hidden over the pause or death screen
	counter.step(0.016, 3)
	var was_state: int = _game.flow.state
	_game.flow.state = 7  # DEAD
	_game.hud._process(0.016)
	_t.check("a counter hidden while not playing", not _game.hud.chain_counter.visible, "visible %s, in_play %s" % [counter.visible, _game.flow.in_play()])
	_game.flow.state = was_state

	# c: the collar rings
	var want := {1: 0, 2: 2, 3: 3, 6: 6, 7: 6}
	for links in want:
		_set_chain(links)
		events.line_state_changed.emit("chain_link", null, Vector3.ZERO, "")
		_t.eq("c rings at %d links" % links, view.collar_rings, want[links])
	events.line_state_changed.emit("chain_end", null, Vector3.ZERO, "ground")
	_t.eq("c rings cleared on chain_end", view.collar_rings, 0)

	# d: the link's pitch
	var key := Harmony.ratio(audio.live_key())
	for links in [1, 2, 3, 4, 7]:
		_fresh(audio)
		_set_chain(links)
		events.line_state_changed.emit("chain_link", null, Vector3.ZERO, "")
		var bites := _cues(audio, "line_bite")
		if links == 1:
			_t.check("d no chain_link cue at one link", bites.is_empty(), "cues %s" % [audio.cue_log])
		else:
			var steps := mini(links - 1, 5)
			var expect := Harmony.ladder_ratio(SfxBank.BITE_MIDI, steps) * key
			var got: float = bites[0][4] if bites.size() == 1 else -1.0
			_t.check("d link %d pitches %d rungs up" % [links, steps], absf(got - expect) < 0.001, "got %.4f, expected %.4f, cues %s" % [got, expect, audio.cue_log])
	# the real bite that follows a chained link is not doubled
	_fresh(audio)
	_set_chain(3)
	events.line_state_changed.emit("chain_link", null, Vector3.ZERO, "")
	events.line_state_changed.emit("latched_body", null, Vector3.ZERO, "")
	_t.eq("d one bite for a chained link and its latch", _cues(audio, "line_bite").size(), 1)
	_fresh(audio)
	_set_chain(1)
	events.line_state_changed.emit("chain_link", null, Vector3.ZERO, "")
	events.line_state_changed.emit("latched_body", null, Vector3.ZERO, "")
	var plain := _cues(audio, "line_bite")
	_t.check("d at one link the latch plays the root bite", plain.size() == 1 and absf(float(plain[0][4]) - key) < 0.001, "cues %s" % [audio.cue_log])
	_set_chain(0)

	# e: the end
	_fresh(audio)
	events.line_state_changed.emit("chain_end", null, Vector3.ZERO, "paid")
	_t.eq("e paid end plays no zip", _cues(audio, "line_zip").size(), 0)
	for combo in [0, 1]:
		_fresh(audio)
		_player.chain.finished.append({"links": combo, "pivots": 0, "combo": combo, "paid": false, "cause": "ground"})
		events.line_state_changed.emit("chain_end", null, Vector3.ZERO, "ground")
		_t.eq("e no zip at combo %d" % combo, _cues(audio, "line_zip").size(), 0)
	_fresh(audio)
	_player.chain.finished.append({"links": 2, "pivots": 0, "combo": 2, "paid": false, "cause": "ground"})
	events.line_state_changed.emit("chain_end", null, Vector3.ZERO, "ground")
	_t.eq("e one zip at combo 2 on ground", _cues(audio, "line_zip").size(), 1)
	_fresh(audio)
	_player.chain.finished.append({"links": 2, "pivots": 0, "combo": 2, "paid": true, "cause": "paid"})
	events.line_state_changed.emit("chain_end", null, Vector3.ZERO, "paid")
	_t.eq("e no zip when paid at combo 2", _cues(audio, "line_zip").size(), 0)
	_fresh(audio)
	_set_chain(2)
	events.line_state_changed.emit("chain_link", null, Vector3.ZERO, "")
	events.line_state_changed.emit("latched_body", null, Vector3.ZERO, "")
	audio._last_start.clear()
	events.line_state_changed.emit("latched_body", null, Vector3.ZERO, "")
	_t.eq("e the hold is consumed once", _cues(audio, "line_bite").size(), 2)
	_set_chain(0)

	# f: one tick per miss, in either order
	for order in [["dry_fire", "chain_miss"], ["chain_miss", "dry_fire"]]:
		_fresh(audio)
		for id in order:
			events.line_state_changed.emit(id, null, Vector3.ZERO, "")
		_t.eq("f one dry_tick for %s" % [order], _cues(audio, "dry_tick").size(), 1)
	_fresh(audio)
	events.line_state_changed.emit("chain_miss", null, Vector3.ZERO, "")
	_t.eq("f a lone chain_miss ticks", _cues(audio, "dry_tick").size(), 1)

	# g: the line's own state and the hum stand through every chain id
	for id in ["chain_end", "chain_link", "chain_pivot", "chain_miss"]:
		events.line_state_changed.emit("locked", null, Vector3.ZERO, "")
		audio.hum_on = true
		events.line_state_changed.emit(id, null, Vector3.ZERO, "ground")
		_t.check("g %s leaves the view locked and the hum on" % id, view._state == "locked" and audio.hum_on, "state %s, hum %s" % [view._state, audio.hum_on])
	events.line_state_changed.emit("searching", null, Vector3.ZERO, "")
	audio._stop_hum()

	_game.free()
	var code := _t.verdict()
	if code == 0:
		print("chain_readout_test: PASS")
	else:
		print("chain_readout_test: FAIL (%d)" % _t.failures)
	quit(code)
