extends SceneTree

# Hitting on the beat pays in sound and look only (Andrew, Q10 "Sound only", 17 Oct 22:12Z):
# through the real game, an on-beat hit fires the on-beat clap cue and a bigger comic word, deals
# exactly what the same hit deals off the beat, and its own hit sound still plays on the
# frame of the hit (inside the 5 ms contract), ahead of the stab. The beat clock is stood in
# for by audio.beat_offset_hook, so this pins the decision, not the band's timing.
const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Audio := preload("res://src/presentation/audio.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Density := preload("res://src/presentation/density.gd")

const STURDY_HP := 100000.0
# 5 ms at the band's rate: the hit sound's budget from the hit.
const HIT_BUDGET := int(0.005 * Harmony.RATE)

var t := T.new("on_beat_hit_test")
var _game
var _offset := 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(2)
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _frames(5)
	Density.live().reset()
	var audio = _game.presentation.audio
	var fx = _game.presentation.player_fx
	audio.bake_now()
	audio.beat_offset_hook = func() -> float: return _offset

	t.check("the window is narrow: 80 ms either side", Audio.ONBEAT_WINDOW_S <= 0.08)
	_offset = 0.3
	var off := await _hit(audio, fx)
	_offset = -0.05
	var on := await _hit(audio, fx)

	t.near("an on-beat hit deals what the same hit deals off the beat", on["dealt"], off["dealt"])
	t.check("the hit dealt damage at all", off["dealt"] > 0.0, str(off["dealt"]))
	t.check("off the beat: no stab, no beat word", not off["stab"] and off["beat"] == 0)
	t.check("on the beat: the clap cue fires", on["stab"])
	t.check("on the beat: the beat fact reaches the comic word", on["beat"] == 1)
	t.check("on the beat: the word is bigger", on["size"] >= PlayerFx.WORDS["beat"]["size"] * PlayerFx.ONBEAT_GROW - 0.001, str(on["size"]))
	for row in [off, on]:
		t.check("the hit sound plays on the hit's frame, within 5 ms", row["hit_delay"] >= 0 and row["hit_delay"] <= HIT_BUDGET,
			"%d samples" % row["hit_delay"])
	t.check("the hit sound plays before the stab", on["hit_index"] >= 0 and on["hit_index"] < on["stab_index"])

	# Once a beat: a second hit on the same beat adds no second stab.
	audio.cue_log.clear()
	var enemy := _target()
	_game.combat.strike(enemy, "ram", 20.0)
	t.check("a second hit on the same beat adds no second stab", _stabs(audio) == 0)
	enemy.queue_free()

	# A foe freed on the tick of its on-beat hit: the deferred word still runs and finds no one to
	# stamp, where a typed parameter had Godot refuse the call with an ERROR line (kite_dive_stack's
	# exit error under load).
	audio._onbeat_at = -(1 << 40)
	fx._last_word = -1.0e9
	fx._word_seen.clear()
	for w in fx._words:
		w["t"] = 1.0
	var beats_before: int = fx.spawned.get("on_beat", 0)
	var words_before: int = fx.spawned.get("word_beat", 0)
	var gone := _target()
	_game.combat.strike(gone, "ram", 20.0)
	gone.free()
	await _frames(1)
	t.eq("a foe freed on the hit's tick: the beat fact still arrives", fx.spawned.get("on_beat", 0) - beats_before, 1)
	t.eq("a foe freed on the hit's tick: no word is stamped on it", fx.spawned.get("word_beat", 0) - words_before, 0)

	# No music, no window: the beat never pays.
	audio.beat_offset_hook = Callable()
	t.check("with no band playing there is no beat", audio.beat_offset_s() == INF or audio.engine.mode == audio.MusicEngine.PLAY)
	quit(t.verdict())


# One ram on a fresh sturdy chaser: what it dealt and what the audio and words did.
func _hit(audio, fx) -> Dictionary:
	audio._last_start.clear()
	audio._onbeat_at = -(1 << 40)
	audio.cue_log.clear()
	fx._last_word = -1.0e9
	fx._word_seen.clear()
	for w in fx._words:
		w["t"] = 1.0
	var beats_before: int = fx.spawned.get("on_beat", 0)
	var enemy := _target()
	var hp: float = enemy.hp
	var at: int = audio.engine.clock
	_game.combat.strike(enemy, "ram", 20.0)
	var dealt: float = hp - enemy.hp
	await _frames(1)
	var row := {"dealt": dealt, "stab": _stabs(audio) > 0, "beat": fx.spawned.get("on_beat", 0) - beats_before,
		"hit_delay": -1, "hit_index": -1, "stab_index": -1, "size": 0.0}
	for i in audio.cue_log.size():
		var cue: Array = audio.cue_log[i]
		if cue[0] == "enemy_struck" and cue[2] == "now" and row["hit_index"] < 0:
			row["hit_index"] = i
			row["hit_delay"] = int(cue[3]) - at
		if cue[0] == "hit_on_beat" and row["stab_index"] < 0:
			row["stab_index"] = i
	var word: Dictionary = fx._words_by_id("beat")
	row["size"] = float(word.get("size", 0.0))
	enemy.queue_free()
	await _frames(1)
	return row


func _stabs(audio) -> int:
	var n := 0
	for cue in audio.cue_log:
		if cue[0] == "hit_on_beat":
			n += 1
	return n


func _target() -> Node3D:
	var ball: Vector3 = _game.player.shown_position()
	var enemy: Node3D = _game.ctx.spawner.spawn_enemy("chaser", ball + Vector3(4, 0, 0))
	enemy._set_health(STURDY_HP)
	return enemy
