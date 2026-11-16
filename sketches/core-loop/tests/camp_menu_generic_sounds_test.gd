extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Rows := preload("res://src/presentation/rows.gd")
const Push := preload("res://tests/workshop/push.gd")

# World 1's camp, every menu a pad moves through, and the three facts that shared generic sounds.
# Cue decisions are read from audio.cue_log, so this is the director's choice, not a listen.

# The camp facts that borrowed a stand-in, and the sound each now hears.
const CAMP := {
	"bay_jukebox": "lounge_flip", "bay_bell": "bay_bell_ring", "bay_marble_note": "marble_tick_ladder",
	"bay_pins": "pins_crash", "bay_entered": "bay_lounge_in", "bay_left": "bay_slingshot_out",
}
# The three generic facts: ready, found and failed.
const ULTIMATE := "ultimate_ready"
const FOUND := "interaction_found"
const FAILS := ["verb_failed", "gauge_cancelled"]
const MENU := {"menu_move": "menu_move", "menu_confirm": "menu_confirm", "menu_back": "menu_back"}
const MOTIFS := ["sable", "rivet", "kest", "tarn", "tally", "cannon"]

var _t := T.new("camp_menu_generic_sounds_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# Which rows hear a sound, over every table of rows the game reads: {sound: ["TABLE:kind"]}.
func _hearers() -> Dictionary:
	var out := {}
	var tables: Dictionary = (EventKinds as GDScript).get_script_constant_map()
	for name in tables:
		var table = tables[name]
		if not table is Dictionary:
			continue
		for kind in table:
			var row = table[kind]
			if not row is Dictionary or not row.has("sound"):
				continue
			var sound := Rows.heard(row)
			if not out.has(sound):
				out[sound] = []
			out[sound].append("%s:%s" % [name, kind])
	return out


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_camp()
	_generic()
	_bank()
	_releases()
	await _menus()
	quit(_t.verdict())


func _row(kind: String) -> Dictionary:
	if EventKinds.ROWS.has(kind):
		return EventKinds.ROWS[kind]
	if EventKinds.UI_ROWS.has(kind):
		return EventKinds.UI_ROWS[kind]
	return EventKinds.WORLD_ROWS.get(kind, {})


func _only_hearer(label: String, kind: String, sound: String, hearers: Dictionary) -> void:
	var heard := Rows.heard(_row(kind))
	_t.eq("%s: %s hears %s" % [label, kind, sound], heard, sound)
	var who: Array = hearers.get(sound, [])
	_t.check("%s: only %s hears %s" % [label, kind, sound], who.size() == 1 and String(who[0]).ends_with(":" + kind), str(who))


func _camp() -> void:
	var hearers := _hearers()
	var looped := 0
	for kind in CAMP:
		_only_hearer("camp", kind, CAMP[kind], hearers)
		looped += 1
	_t.check("camp: the loop ran over every camp fact", looped == CAMP.size() and looped == 6, str(looped))
	# The jukebox is also played by name (the radio deck's find, the camp page's spin), which reads the row table.
	_t.eq("camp: playing bay_jukebox by name hears the record-on sound", Rows.sound("bay_jukebox"), "lounge_flip")


func _generic() -> void:
	var hearers := _hearers()
	var ultimate := Rows.heard(_row(ULTIMATE))
	var found := Rows.heard(_row(FOUND))
	_t.check("generic: the ultimate has a sound of its own", ultimate == "ultimate_ready", ultimate)
	_only_hearer("generic", ULTIMATE, ultimate, hearers)
	_only_hearer("generic", FOUND, found, hearers)
	_t.check("generic: the found item is not the shared found_chime", found != "found_chime", found)
	var looped := 0
	var fail_sounds := []
	for kind in FAILS:
		var sound := Rows.heard(_row(kind))
		fail_sounds.append(sound)
		_t.check("generic: %s is not the shared ui_tick" % kind, sound != "ui_tick", sound)
		_t.check("generic: %s is not a danger cue" % kind, not sound in SfxBank.DANGER_SOUNDS, sound)
		_t.check("generic: %s is not the ready or found sound" % kind, sound != ultimate and sound != found, sound)
		var who: Array = hearers.get(sound, [])
		_t.check("generic: only the failure rows hear %s" % sound, who.size() == 1 and String(who[0]).ends_with(":" + kind), str(who))
		looped += 1
	_t.check("generic: the loop ran over both failure rows", looped == 2, str(looped))
	_t.check("generic: ready, found and failure are three different sounds", ultimate != found and not ultimate in fail_sounds and not found in fail_sounds, str([ultimate, found, fail_sounds]))
	_t.eq("generic: verb_failed hears a short soft no", Rows.heard(_row("verb_failed")), "verb_fail")


func _bank() -> void:
	var ids: Array = CAMP.values() + [Rows.heard(_row(ULTIMATE)), Rows.heard(_row(FOUND)), "gauge_dry_click", "verb_fail"] + MENU.values()
	var looped := 0
	for id in ids:
		looped += 1
		_t.check("bank: %s has a recipe" % id, SfxBank.has_recipe(id))
		_t.check("bank: %s has a level" % id, SfxBank.TRIM_DB.has(id))
		var samples := SfxBank.samples(id)
		var seconds := float(samples.size()) / float(SfxBank.RATE)
		var peak := Synth.wav_peak(SfxBank.stream(id))
		_t.check("bank: %s renders non-silent and under 1.5 s" % id, peak >= 0.1 and seconds > 0.02 and seconds < 1.5, "peak %.3f, %.3f s" % [peak, seconds])
	_t.check("bank: the loop ran over every new sound", looped == ids.size() and looped >= 13, str(looped))
	for id in MENU.values():
		_t.check("bank: %s is a utility sound, not a danger cue" % id, not id in SfxBank.DANGER_SOUNDS)
		_t.check("bank: %s keeps a voice limit" % id, SfxBank.VOICE_LIMIT.has(id))
	_t.check("bank: a move repeats fast, so it keeps a minimum gap", SfxBank.MIN_GAP_MS.has("menu_move"))
	_t.check("bank: confirm rises, back falls: the three menu sounds are three renders", SfxBank.samples("menu_confirm") != SfxBank.samples("menu_back") and SfxBank.samples("menu_move") != SfxBank.samples("menu_confirm"))


func _releases() -> void:
	var looped := 0
	for motif in MOTIFS:
		looped += 1
		_t.eq("release: %s has exactly one release candidate" % motif, Rows.releases(motif).size(), 1)
	_t.eq("release: the loop ran over every motif", looped, MOTIFS.size())


# Menu cues the director chose since `from`, as their kinds.
func _menu_cues(audio, from: int) -> Array:
	var out: Array = []
	for i in range(from, audio.cue_log.size()):
		var entry: Array = audio.cue_log[i]
		if String(entry[0]).begins_with("menu_") and entry[2] == "now":
			out.append(String(entry[0]))
	return out


# A pad button held for a few frames, as a thumb holds it.
func _press(button: int) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(4)


func _menus() -> void:
	var audio = _game.presentation.audio
	audio.bake_now()
	await _frames(3)
	var flow = _game.flow
	_game.ctx.calm = true
	_t.eq("menu: the game starts on the title", flow.state_name(), "title")
	# Title: a d-pad press moves focus onto a button once.
	var from: int = audio.cue_log.size()
	await _press(JOY_BUTTON_DPAD_DOWN)
	_t.eq("menu title: d-pad down plays one move", _menu_cues(audio, from), ["menu_move"])
	if root.gui_get_focus_owner() != null:
		root.gui_get_focus_owner().release_focus()
	await _frames(2)
	# Class select: the cards move with the d-pad and B goes back to the title.
	flow.open_class_select()
	_game.screens._on_flow_changed("class_select")
	await _frames(40)
	from = audio.cue_log.size()
	_t.eq("menu class select: opening the page and its focus play nothing", _menu_cues(audio, from), [])
	await _press(JOY_BUTTON_DPAD_RIGHT)
	_t.eq("menu class select: d-pad right plays one move", _menu_cues(audio, from), ["menu_move"])
	from = audio.cue_log.size()
	await _press(JOY_BUTTON_B)
	_t.eq("menu class select: B plays one back", _menu_cues(audio, from), ["menu_back"])
	await _frames(20)
	# Pause needs a run in play: Start, the first pilot, then Esc closes the opening pick.
	# The game reads a pad's B for the screens through _screen_key, which test mode skips, so the test walks back itself.
	flow.show_title()
	_game.screens._on_flow_changed("title")
	await _frames(30)
	_t.eq("menu: the title is back", flow.state_name(), "title")
	Push.click(root, _game.screens.button_for("start"))
	await _frames(30)
	Push.click(root, _game.screens.class_cards()[0])
	await _frames(60)
	Push.key(root, KEY_ESCAPE)
	await _frames(30)
	if root.gui_get_focus_owner() != null:
		root.gui_get_focus_owner().release_focus()
	await _frames(3)
	_t.check("menu: a run is in play", flow.in_play())
	from = audio.cue_log.size()
	_game.get_node("PauseMenu").open()
	await _frames(20)
	_t.check("menu pause: it opened", _game.get_node("PauseMenu").is_open())
	_t.eq("menu pause: opening it plays nothing", _menu_cues(audio, from), [])
	await _press(JOY_BUTTON_DPAD_DOWN)
	_t.eq("menu pause: d-pad down plays one move", _menu_cues(audio, from), ["menu_move"])
	from = audio.cue_log.size()
	await _press(JOY_BUTTON_B)
	_t.eq("menu pause: B plays one back", _menu_cues(audio, from), ["menu_back"])
	await _frames(20)
	_t.check("menu pause: B closed it", not _game.get_node("PauseMenu").is_open())
	_game.get_node("PauseMenu").open()
	await _frames(20)
	from = audio.cue_log.size()
	await _press(JOY_BUTTON_A)
	_t.eq("menu pause: A on Resume plays one confirm", _menu_cues(audio, from), ["menu_confirm"])
	await _frames(20)
	# In play nothing is focused, so a pad A or B is a game input and plays no menu sound.
	if root.gui_get_focus_owner() != null:
		root.gui_get_focus_owner().release_focus()
	await _frames(3)
	from = audio.cue_log.size()
	await _press(JOY_BUTTON_A)
	_t.eq("menu: A with nothing focused plays no confirm", _menu_cues(audio, from), [])
