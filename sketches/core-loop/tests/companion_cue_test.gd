extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")
const T := preload("res://tests/support/t.gd")

# The companion pip and chirps (ALPHA-PLAN:68): the HUD reads the escape charge from
# run.companion, shows it as the companion_ready / companion_spent UI row, and chirps once
# per change between ready and spent. No pip and no chirp without a seated escape corridor.

var _t := T.new("companion_cue_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _doc(owned: Array, seated: Array) -> Dictionary:
	var m := Companion.new()
	for id in owned:
		m.acquire(id)
	if not seated.is_empty():
		m.assemble(seated)
	return m.to_dict()


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	var flow = _game.flow
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	flow.press_start()
	flow.choose_class(1)
	await _frames(20)
	var hud = _game.hud
	var run = _game.run

	run.companion = {}
	await _frames(3)
	_t.eq("empty companion state", hud.companion_state(), "none")
	_t.eq("empty companion is silent", hud.companion_cues(), [] as Array[String])
	_t.check("empty companion has no pip", not hud._companion.visible, "pip hidden")

	run.companion = _doc(["escape_vent", "ram_prow"], ["escape_vent", "ram_prow"])
	await _frames(3)
	_t.eq("seated escape is ready", hud.companion_state(), "ready")
	_t.eq("none to ready is silent", hud.companion_cues(), [] as Array[String])
	_t.check("ready pip shows", hud._companion.visible, "pip visible while playing")
	_t.eq("ready pip colour", hud._companion.modulate, EventKinds.UI_ROWS["companion_ready"]["color"])
	_t.check("ready pip in bottom pieces", hud.piece_rects()["bottom"].has(hud._rect_of(hud._companion)), "pip rect listed")

	run.max_hp = 200.0
	run.hp = 60.0
	run.damage(10.0, "test")
	await _frames(3)
	_t.check("hull at or under a quarter", run.hp > 0.0 and run.hp <= 50.0, "hp %.1f / %.1f" % [run.hp, run.max_hp])
	_t.eq("low-hull hit spends", hud.companion_state(), "spent")
	_t.eq("spent chirp", hud.companion_cues(), ["companion_spent"] as Array[String])
	_t.eq("spent pip colour", hud._companion.modulate, EventKinds.UI_ROWS["companion_spent"]["color"])

	run._on_stage_entered(run.stage, false)
	await _frames(3)
	_t.eq("fresh entry re-arms", hud.companion_state(), "ready")
	_t.eq("ready chirp", hud.companion_cues(), ["companion_spent", "companion_ready"] as Array[String])

	for id in ["companion_chirp_ready", "companion_chirp_spent"]:
		_t.check("%s recipe" % id, SfxBank.has_recipe(id), "TRIM_DB lists it")
		var peak := Synth.wav_peak(SfxBank.stream(id))
		_t.check("%s audible" % id, peak >= 0.1, "peak %.3f" % peak)
	_t.check("escape_window stays a grammar signal", EventKinds.GRAMMAR_SIGNALS.has("escape_window"), "listed")

	quit(_t.verdict())
