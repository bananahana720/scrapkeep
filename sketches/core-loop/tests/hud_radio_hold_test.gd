extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Radio := preload("res://src/core/radio.gd")
const RadioTakes := preload("res://src/core/radio_takes.gd")
const T := preload("res://tests/support/t.gd")

# The radio holds still through a boss fight (PF-19). On the real game with a Warden engaged:
# a take found in the fight is filed but the dial does not move; a take found outside it moves the
# dial and shows one "On air" toast.

var _t := T.new("hud_radio_hold_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _run() -> void:
	while _game.flow == null:
		await process_frame
	_game.flow.force_warden = true
	for i in 5:
		await process_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.presentation.flourish.stop_all()
	for i in 30:
		await process_frame
	_radio()
	quit(_t.verdict())


# Two takes that air on different stations, found one in a fight and one outside it.
func _radio() -> void:
	var deck = _game.radio_deck
	var profile = _game.ctx.profile
	var picks: Array = []
	for id in RadioTakes.take_ids():
		var home := RadioTakes.station_of(String(id))
		if home != "" and home != Radio.LIVE and not profile.has_tune(String(id)) and not picks.any(func(p): return RadioTakes.station_of(p) == home):
			picks.append(String(id))
		if picks.size() == 2:
			break
	_t.eq("two unfound takes on different stations", picks.size(), 2)
	if picks.size() < 2:
		return
	deck.radio.tune(Radio.LIVE)
	_game.flow._engage()
	_t.check("a Warden fight is live", _game.flow.engaged() and _game.flow.sealed, "engaged %s sealed %s" % [_game.flow.engaged(), _game.flow.sealed])
	var before: String = deck.radio.station
	var filed: bool = deck.find(picks[0])
	_t.check("the take is filed in the fight", filed and profile.has_tune(picks[0]), "filed %s" % filed)
	_t.check("a boss fight holds the station and the chip still", deck.radio.station == before and not deck.dial.swollen(), "station %s -> %s, swollen %s" % [before, deck.radio.station, deck.dial.swollen()])
	_game.flow._unseal()
	_game.hud.clear_toasts()
	deck.find(picks[1])
	_t.check("outside a fight the take moves the dial", deck.radio.station == RadioTakes.station_of(picks[1]), "station %s" % deck.radio.station)
	_t.check("and pulses the chip once, with no toast", _game.radio_deck.dial.swollen() and _game.hud.toast_texts().is_empty(), "swollen %s, toasts %s" % [_game.radio_deck.dial.swollen(), _game.hud.toast_texts()])
