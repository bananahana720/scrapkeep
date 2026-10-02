extends SceneTree

const Game := preload("res://src/game.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")

# Every fact on the bus has a sound. Each event kind's `sound` id bakes to a non-silent
# 16-bit stream from a recipe written for it, presentation listens to every signal,
# and the families mean what they say: danger sits lower than rewards, and the reward
# ladder climbs inside the key the band plays in. Buffers, not speakers.

const DANGER := ["hurt", "death", "enemy_arrive", "klaxon"]
const REWARD := ["scrap_tick", "part_get", "kill_pop", "gate_through"]

var _game
var _failures := 0
var _checked_bus := false


func _initialize() -> void:
	var ids: Array = []
	var silent: Array = []
	var generic: Array = []
	for kind in EventKinds.ROWS:
		var id: String = EventKinds.ROWS[kind]["sound"]
		if id in ids:
			continue
		ids.append(id)
		var wav := SfxBank.stream(id)
		var peak := Synth.wav_peak(wav)
		var seconds := wav.data.size() / 2.0 / wav.mix_rate
		if peak < 0.1 or seconds < 0.02 or wav.format != AudioStreamWAV.FORMAT_16_BITS:
			silent.append("%s (peak %.2f, %.2fs)" % [id, peak, seconds])
		if not SfxBank.has_recipe(id):
			generic.append(id)
	_check("baked", silent.is_empty(), "%d kinds, %d sound ids baked, non-silent 16-bit streams; failing %s" % [EventKinds.ROWS.size(), ids.size(), silent])
	_check("recipes", generic.is_empty(), "every sound id has its own recipe; on the fallback blip %s" % [generic])

	var danger := _mean_crossings(DANGER)
	var reward := _mean_crossings(REWARD)
	_check("danger is low", danger < reward * 0.6, "zero crossings per second: danger %.0f, rewards %.0f" % [danger, reward])

	var ladder_ok := true
	var previous := -1
	var notes: Array = []
	for rung in 11:
		var step := Harmony.pentatonic_step(rung)
		ladder_ok = ladder_ok and step > previous and posmod(step, 12) in Harmony.PENTATONIC and posmod(step, 12) in Harmony.DORIAN
		previous = step
		notes.append(step)
	_check("reward ladder", ladder_ok and notes[5] == 12 and notes[10] == 24, "rungs climb the D minor pentatonic, in D Dorian, home at rungs 5 and 10: %s" % [notes])

	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null or _checked_bus:
		return false
	_checked_bus = true
	var presentation: Node = _game.presentation
	var unheard: Array = []
	for signal_name in GameEvents.signal_names():
		if signal_name in EventKinds.GRAMMAR_SIGNALS:
			continue
		var heard := false
		for connection in _game.events.get_signal_connection_list(signal_name):
			var owner: Object = (connection["callable"] as Callable).get_object()
			if owner is Node and (owner == presentation or presentation.is_ancestor_of(owner)):
				heard = true
		if not heard:
			unheard.append(signal_name)
	_check("every signal heard", unheard.is_empty(), "%d signals, presentation listens to all but %s" % [GameEvents.signal_names().size(), unheard])
	_check("own squash", not _game.player.builtin_squash, "the spine's landing squash is off; presentation draws its own")
	print("presentation_sfx_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _mean_crossings(ids: Array) -> float:
	var total := 0.0
	for id in ids:
		var buf := SfxBank.samples(id)
		var crossings := 0
		for i in range(1, buf.size()):
			if (buf[i - 1] < 0.0) != (buf[i] < 0.0):
				crossings += 1
		total += crossings / (buf.size() / float(Harmony.RATE))
	return total / ids.size()


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
