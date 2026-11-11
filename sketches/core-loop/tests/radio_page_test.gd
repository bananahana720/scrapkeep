extends SceneTree

const Game := preload("res://src/game.gd")
const Radio := preload("res://src/core/radio.gd")
const RadioTakes := preload("res://src/core/radio_takes.gd")
const T := preload("res://tests/support/t.gd")

# The radio's mixtapes at camp (design-v3/sound/RADIO.md): R on the camp opens the page; the
# crate shows only found tracks and counts the takes; Space adds the focused crate track to the
# tape and takes a tape track off; period moves a tape track down; N starts a new tape and 1
# picks the first again; T tunes the radio to the tape; R goes back to the camp and saves. The
# pause menu's Radio row turns the radio off and on.

var _t := T.new("radio_page_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


# The ball set down in a camp station's zone, 2 m toward the plaza from its centre (camp_hub_test.gd walks them all).
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


func _run() -> void:
	await _frames(3)
	var profile = _game.ctx.profile
	var screens = _game.screens
	var radio = _game.radio_deck.radio
	var takes := RadioTakes.take_ids()
	var a: String = takes[0]
	var b: String = takes[1]
	profile.hear_tune(a)
	profile.hear_tune(b)
	profile.hear_tune("roam-1-1")
	_game._screen_key(KEY_K)
	_game._screen_key(KEY_R)
	_t.check("R outside the radio mast's zone opens nothing", not screens.radio_open())
	await _put_in("radio")
	_game._screen_key(KEY_R)
	_t.check("R opens the mixtapes", screens.radio_open() and not screens.walk_live())
	var page = screens.radio_page()
	# The crate lists every found track (two takes and a roam record here), so the count is every track, as the tape header spaces it.
	var listable: Array = []
	for station in Radio.dial():
		for id in RadioTakes.on_station(station):
			if not id in listable:
				listable.append(id)
	for id in RadioTakes.all_ids():
		if not id in listable:
			listable.append(id)
	_t.eq("it counts the crate's found tracks over every track it can list", page._count.text, "3 / %d" % listable.size())
	_t.check("the crate holds found tracks", page.crate_row(a) != null and page.crate_row(b) != null and page.crate_row("roam-1-1") != null)
	_t.check("and never an unfound one", page.crate_row(takes[2]) == null)
	page.crate_row(b).grab_focus()
	await _frames(1)
	_t.check("a focused track shows its sleeve", page.note_text().begins_with(String(RadioTakes.take(b)["name"])), page.note_text())
	_game._screen_key(KEY_SPACE)
	await _frames(1)
	page.crate_row(a).grab_focus()
	await _frames(1)
	_game._screen_key(KEY_SPACE)
	await _frames(1)
	_t.eq("Space adds to the tape", radio.current_mixtape()["ids"], [b, a])
	page.tape_row(b).grab_focus()
	await _frames(1)
	_game._screen_key(KEY_PERIOD)
	await _frames(1)
	_t.eq("period moves a tape track down", radio.current_mixtape()["ids"], [a, b])
	page.tape_row(b).grab_focus()
	await _frames(1)
	_game._screen_key(KEY_SPACE)
	await _frames(1)
	_t.eq("Space on a tape track takes it off", radio.current_mixtape()["ids"], [a])
	_game._screen_key(KEY_N)
	_t.eq("N starts a new tape", [radio.mixtapes.size(), radio.mixtape], [2, 1])
	_game._screen_key(KEY_1)
	_t.eq("1 picks the first again", radio.mixtape, 0)
	_game._screen_key(KEY_T)
	_t.eq("T tunes the radio to the tape", radio.station, Radio.MIXTAPE)
	_game._screen_key(KEY_R)
	_t.check("R goes back to the camp walk", screens.walk_live() and not screens.radio_open())
	_t.eq("and saves the tape", profile.radio().get("mixtapes", [{}])[0].get("ids", []), [a])
	_game._screen_key(KEY_K)

	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _frames(4)
	var menu = _game.get_node("PauseMenu")
	menu.open()
	await _frames(1)
	_t.eq("the pause menu shows the radio on", menu.read("radio"), {"label": "Radio", "value": "", "pip": 1})
	menu.press("radio")
	_t.eq("its Radio row turns it off", [radio.station, menu.read("radio")], [Radio.OFF, {"label": "Radio", "value": "", "pip": 0}])
	menu.press("radio")
	_t.eq("and back on to the tape", radio.station, Radio.MIXTAPE)
	menu.close()
	quit(_t.verdict())
