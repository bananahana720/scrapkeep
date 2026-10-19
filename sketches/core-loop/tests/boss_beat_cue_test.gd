# smoke: solo (the boss_beat cue row, contract line and audio listener)
extends SceneTree

const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# The gated beat's cue is its own fact, boss_beat, not boss_attack_telegraphed: it has an event_kinds row
# with a non-danger sound, a CONTRACTS.md row, and Audio plays that sound on the frame it is emitted
# without the danger cue.
#
# Evidence limit: reads the cue log (what Audio asked to play), not rendered audio or its loudness.

var t := T.new("boss_beat_cue_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var row: Dictionary = EventKinds.ROWS.get("boss_beat", {})
	t.check("boss_beat has an event_kinds row", not row.is_empty())
	var danger: Dictionary = EventKinds.ROWS["boss_attack_telegraphed"]
	t.check("its sound is not the danger cue", String(row.get("sound", "")) != String(danger["sound"]) and String(row.get("sound", "")) != "")
	var contracts := FileAccess.get_file_as_string("res://CONTRACTS.md")
	t.check("CONTRACTS.md has a boss_beat row", contracts.contains("| `boss_beat` | `boss_id: String, seconds_left: float` |"))
	t.check("and says it is not an attack", contracts.contains("Not an attack"))

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
	audio.cue_log.clear()
	game.events.boss_beat.emit("mind", 4.0)
	var beat_cues: Array = audio.cue_log.filter(func(c): return c[0] == "boss_beat")
	t.eq("one boss_beat cue played", beat_cues.size(), 1)
	if beat_cues.size() == 1:
		t.eq("it plays the row's sound", beat_cues[0][1], row.get("sound", ""))
	t.eq("no danger cue", audio.cue_log.filter(func(c): return c[0] == "boss_attack_telegraphed" or c[1] == danger["sound"]).size(), 0)
	game.queue_free()
	await process_frame
	quit(t.verdict())
