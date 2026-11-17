extends SceneTree

const Game := preload("res://src/game.gd")
const Rows := preload("res://src/presentation/rows.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")

# W1-42: the beacon-open chime rides the unseal stinger's downbeat BEACON_OPEN_DB under it, and
# stays under it when world 1's story sting holds the moment and ducks the stinger (the sting is
# the moment's voice, audio.gd STORY_DUCKED). Read from the engine's booked stinger actions.

var t := T.new("beacon_open_level_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _unseal(false)
	await _unseal(true)
	quit(t.verdict())


func _unseal(story: bool) -> void:
	var label := "story sting" if story else "plain"
	if not Array(DirAccess.get_files_at("res://assets/music_ace/spillway")).any(func(name): return name.ends_with(".ogg")):
		AceStub.install()
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.set_frozen(true)
	var audio = game.presentation.audio
	audio.bake_now()
	audio.set_process(false)
	audio._flush_flow()
	var engine = audio.engine
	engine.track = "warden"
	if story:
		audio._story_until_ms = 1 << 62  # a sting holding the moment for good
	game.flow._unseal()
	audio._flush_flow()
	var stinger: String = Rows.sound("beacon_unsealed")
	var chime: String = Rows.heard(EventKinds.state_row("beacon_open"))
	var levels := {}
	for action in engine._actions:
		var a: Dictionary = action if action is Dictionary else {}
		if a.get("type") == "stinger" and a.get("id") in [stinger, chime]:
			levels[a["id"]] = float(a["db"])
	if t.check("%s: the unseal booked the stinger and the chime" % label, levels.has(stinger) and levels.has(chime), "%s in %d actions" % [levels, engine._actions.size()]):
		var want: float = audio.STORY_DUCK_DB if story else 0.0
		t.near("%s: the stinger plays at its duck" % label, levels[stinger], want)
		t.near("%s: the chime sits BEACON_OPEN_DB under the stinger" % label, levels[chime] - levels[stinger], audio.BEACON_OPEN_DB)
	game.queue_free()
	await process_frame
