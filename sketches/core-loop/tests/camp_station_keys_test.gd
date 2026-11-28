extends SceneTree

const Game := preload("res://src/game.gd")
const Radio := preload("res://src/core/radio.gd")
const RadioTakes := preload("res://src/core/radio_takes.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("camp_station_keys_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _put_in(id: String) -> void:
	var hub = _game.camp_hub
	var toward: Vector3 = hub.root.global_position - hub.zone_position(id)
	toward.y = 0.0
	var at: Vector3 = hub.zone_position(id) + toward.normalized() * 1.5
	at.y = 1.3
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	for i in 4:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _played(from: int, kind: String) -> int:
	var audio = _game.audio()
	return audio.cues_since(from).filter(func(e: Array) -> bool: return String(e[0]) == kind and e[2] in ["now", "skip"]).size()


func _key(label: String, key: int) -> void:
	_t.check("%s: the page used the key" % label, _game._screen_key(key))
	await _frames(1)


func _run() -> void:
	await _frames(3)
	_game.audio().bake_now()
	await _frames(2)
	await _radio_keys()
	await _jukebox_keys()
	quit(_t.verdict())


func _radio_keys() -> void:
	var profile = _game.ctx.profile
	var screens = _game.screens
	var audio = _game.audio()
	var radio = _game.radio_deck.radio
	var takes := RadioTakes.take_ids()
	var a: String = takes[0]
	var b: String = takes[1]
	var c: String = takes[2]
	for id in [a, b, c]:
		profile.hear_tune(id)
	_game._screen_key(KEY_K)
	await _put_in("radio")
	_game._screen_key(KEY_R)
	_t.check("R opens the mixtapes", screens.radio_open())
	var page = screens.radio_page()
	_t.eq("the tape starts empty", radio.current_mixtape()["ids"], [])

	var mark: int = audio.cue_log_total
	page.crate_row(a).grab_focus()
	await _key("Space on a crate track", KEY_SPACE)
	_t.eq("Space puts the crate track on the tape", radio.current_mixtape()["ids"], [a])
	_t.eq("with one UI sound", _played(mark, "flow_changed"), 1)
	_t.eq("and the crate track keeps focus", page.focused_id(), "c:" + a)
	page.crate_row(b).grab_focus()
	await _key("Enter on a crate track", KEY_ENTER)
	_t.eq("Enter puts it on the tape", radio.current_mixtape()["ids"], [a, b])
	page.crate_row(c).grab_focus()
	await _key("keypad Enter on a crate track", KEY_KP_ENTER)
	_t.eq("keypad Enter puts it on the tape", radio.current_mixtape()["ids"], [a, b, c])
	mark = audio.cue_log_total
	page.crate_row(a).grab_focus()
	await _key("Space on a crate track already taped", KEY_SPACE)
	_t.eq("Space on a crate track already on the tape takes it off", radio.current_mixtape()["ids"], [b, c])
	_t.eq("with one UI sound", _played(mark, "flow_changed"), 1)
	page.crate_row(a).grab_focus()
	await _key("Space puts it back", KEY_SPACE)
	_t.eq("at the end of the tape", radio.current_mixtape()["ids"], [b, c, a])

	page.tape_row(c).grab_focus()
	await _key("period on a tape track", KEY_PERIOD)
	_t.eq("period moves a tape track down", radio.current_mixtape()["ids"], [b, a, c])
	_t.eq("and it keeps focus", page.focused_id(), "t:" + c)
	await _key("comma on a tape track", KEY_COMMA)
	_t.eq("comma moves it back up", radio.current_mixtape()["ids"], [b, c, a])
	await _key("comma again", KEY_COMMA)
	_t.eq("and up again", radio.current_mixtape()["ids"], [c, b, a])
	page.crate_row(b).grab_focus()
	await _key("period on a crate track", KEY_PERIOD)
	_t.eq("period on a crate track moves nothing", radio.current_mixtape()["ids"], [c, b, a])
	page.tape_row(b).grab_focus()
	await _key("Space on a tape track", KEY_SPACE)
	_t.eq("Space on a tape track takes it off", radio.current_mixtape()["ids"], [c, a])
	page.crate_row(b).grab_focus()
	await _key("Space puts it back again", KEY_SPACE)
	_t.eq("at the end of the tape again", radio.current_mixtape()["ids"], [c, a, b])

	var before: Array = radio.current_mixtape()["ids"].duplicate()
	await _key("X", KEY_X)
	var shuffled: Array = radio.current_mixtape()["ids"].duplicate()
	_t.eq("X keeps the same tracks", shuffled.size(), before.size())
	shuffled.sort()
	before.sort()
	_t.eq("as a permutation of the tape", shuffled, before)

	radio.tune(Radio.OFF)
	await _key("T", KEY_T)
	_t.eq("T tunes the radio to the tape", radio.station, Radio.MIXTAPE)

	var taped: Array = radio.current_mixtape()["ids"].duplicate()
	await _key("N", KEY_N)
	_t.eq("N starts a new tape and picks it", [radio.mixtapes.size(), radio.mixtape, radio.current_mixtape()["ids"]], [2, 1, []])
	await _key("1", KEY_1)
	_t.eq("1 picks the first tape", [radio.mixtape, radio.current_mixtape()["ids"]], [0, taped])
	await _key("2", KEY_2)
	_t.eq("2 picks the second", radio.mixtape, 1)
	await _key("3 past the last tape", KEY_3)
	_t.eq("3 picks nothing when there are two tapes", radio.mixtape, 1)
	await _key("a key the page does not know", KEY_Q)
	_t.eq("it changes nothing", [radio.mixtapes.size(), radio.mixtape, radio.station], [2, 1, Radio.MIXTAPE])
	_t.check("and the page stays open", screens.radio_open())

	page.tape_chosen.emit(0)
	await _frames(1)
	_t.eq("a clicked tape picks it", radio.mixtape, 0)
	mark = audio.cue_log_total
	page.track_chosen.emit(b, true)
	await _frames(1)
	_t.eq("a clicked tape track comes off", radio.current_mixtape()["ids"], taped.filter(func(id): return id != b))
	_t.eq("with one UI sound", _played(mark, "flow_changed"), 1)
	page.track_chosen.emit(b, false)
	await _frames(1)
	_t.eq("a clicked crate track goes on the end", radio.current_mixtape()["ids"], taped.filter(func(id): return id != b) + [b])

	var held: Array = radio.current_mixtape()["ids"].duplicate()
	root.gui_release_focus()
	await _frames(1)
	mark = audio.cue_log_total
	await _key("Space with nothing focused", KEY_SPACE)
	_t.eq("does nothing", [radio.current_mixtape()["ids"], _played(mark, "flow_changed")], [held, 0])

	await _key("Escape", KEY_ESCAPE)
	_t.check("Escape closes the mixtapes", not screens.radio_open() and screens.walk_live())
	_t.eq("and saves the tapes", profile.radio().get("mixtapes", []).map(func(m): return m.get("ids", [])), [held, []])
	_game._screen_key(KEY_R)
	_t.check("R opens them again", screens.radio_open())
	await _key("R", KEY_R)
	_t.check("R closes them", not screens.radio_open() and screens.walk_live())


func _jukebox_keys() -> void:
	var profile = _game.ctx.profile
	var screens = _game.screens
	var audio = _game.audio()
	profile.hear_tune("roam-1-1")
	profile.hear_tune("boss-brindle")
	await _put_in("jukebox")
	_game._screen_key(KEY_J)
	_t.check("J opens the jukebox", screens.jukebox_open())
	var page = screens.jukebox_page()
	_t.eq("nothing spins", audio.spinning, "")

	var mark: int = audio.cue_log_total
	page.sleeve("roam-1-1").grab_focus()
	await _key("Space on a found sleeve", KEY_SPACE)
	_t.eq("Space plays the focused record", audio.spinning, "roam-1-1")
	_t.eq("with one sound", _played(mark, "bay_jukebox"), 1)
	_t.eq("the deck shows it", page.deck.record.get("id", ""), "roam-1-1")
	mark = audio.cue_log_total
	await _key("Space on the spinning sleeve", KEY_SPACE)
	_t.eq("Space again lifts the needle", audio.spinning, "")
	_t.eq("with no sound", _played(mark, "bay_jukebox"), 0)
	await _key("Enter on a found sleeve", KEY_ENTER)
	_t.eq("Enter plays it", audio.spinning, "roam-1-1")
	page.sleeve("boss-mind").grab_focus()
	await _key("keypad Enter on a blank sleeve while a record spins", KEY_KP_ENTER)
	_t.eq("lifts the spinning needle", audio.spinning, "")
	mark = audio.cue_log_total
	await _key("Space on a blank sleeve", KEY_SPACE)
	_t.eq("plays nothing", [audio.spinning, _played(mark, "bay_jukebox")], ["", 0])
	page.sleeve("boss-brindle").grab_focus()
	await _key("Space on a second found sleeve", KEY_SPACE)
	_t.eq("plays it", audio.spinning, "boss-brindle")

	await _key("1", KEY_1)
	_t.eq("1 turns the dial to idle", audio.spin_detent, 0)
	_t.check("and its button shows it", page.detent_button(0).button_pressed and not page.detent_button(2).button_pressed)
	await _key("2", KEY_2)
	_t.eq("2 turns it to cruise", audio.spin_detent, 1)
	await _key("3", KEY_3)
	_t.eq("3 turns it to full tilt", audio.spin_detent, 2)
	_t.check("and its button shows it", page.detent_button(2).button_pressed and not page.detent_button(1).button_pressed)
	await _key("a key the page does not know", KEY_Q)
	_t.eq("it changes nothing", [audio.spinning, audio.spin_detent], ["boss-brindle", 2])
	_t.check("and the page stays open", screens.jukebox_open())

	page.sleeve_chosen.emit("roam-1-1")
	await _frames(1)
	_t.eq("a clicked found sleeve plays", audio.spinning, "roam-1-1")
	page.sleeve_chosen.emit("roam-1-1")
	await _frames(1)
	_t.eq("clicked again it lifts the needle", audio.spinning, "")
	page.sleeve_chosen.emit("boss-mind")
	await _frames(1)
	_t.eq("a clicked blank sleeve plays nothing", audio.spinning, "")

	root.gui_release_focus()
	await _frames(1)
	await _key("Space with nothing focused or spinning", KEY_SPACE)
	_t.eq("does nothing", audio.spinning, "")
	page.sleeve("roam-1-1").grab_focus()
	await _key("Space", KEY_SPACE)
	root.gui_release_focus()
	await _frames(1)
	await _key("Space with nothing focused while a record spins", KEY_SPACE)
	_t.eq("lifts the needle", audio.spinning, "")

	page.sleeve("roam-1-1").grab_focus()
	await _key("Space", KEY_SPACE)
	await _key("Escape", KEY_ESCAPE)
	_t.check("Escape closes the jukebox", not screens.jukebox_open() and screens.walk_live())
	_t.eq("and lifts the needle", audio.spinning, "")
	_game._screen_key(KEY_J)
	_t.check("J opens it again", screens.jukebox_open())
	page.sleeve("roam-1-1").grab_focus()
	await _key("Space", KEY_SPACE)
	await _key("J", KEY_J)
	_t.check("J closes it", not screens.jukebox_open() and screens.walk_live())
	_t.eq("and lifts the needle", audio.spinning, "")
