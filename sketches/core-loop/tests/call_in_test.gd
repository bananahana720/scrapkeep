extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")

# Call-ins (design-v3/STORY-MAP.md, "Call-ins"): a named caller says one line because of what
# the player just did, and a late reaction is dropped.
# 1. A cause on the bus brings its caller's line up, named, once the stage's hello is out of the way.
# 2. A second cause inside the gap is dropped, not queued; after the gap the next one speaks.
# 3. A call is said once a run.
# 4. A call that cannot come up (a paused screen holds it) goes stale and is dropped.
# 5. The low-hull call needs a low hull, when it is caused and when it is said.
# 6. A pilot's line is said by a freed pilot who is not the one flying, one tease a run.
# 7. A call never talks over a fight: with the boss up nothing is caused, and a call that is up
#    gives way.
# 8. A Warden's fall is called by the crew whose gates they were.
# 9. A new run can say them again.
# 10. A comic beat with words up (a flourish's card, caption or panel) has the screen: the call
#     waits for it.
# 11. The stage's hello waits for a call that is up.
# 12. The killing hit calls nobody, and a call that is up does not follow the run off the field.
# 13. A caller's voice goes with a line that is cut short (a fight, another line taking the
#     bubble) and is left alone when the line runs out its time.
# smoke: timeout=180s

var _t := preload("res://tests/support/t.gd").new("call_in_test")
var _game
var _bubble


func _initialize() -> void:
	_run()


func _row(id: String) -> Dictionary:
	for row in LoreRows.CALLS:
		if row["id"] == id:
			return row
	return {}


func _said(id: String) -> bool:
	var row := _row(id)
	return _bubble.visible and _bubble.text == "%s: %s" % [LoreRows.SPEAKERS[row["speaker"]], LoreRows.call_text(row, _game.run.run_seed)]


# A stand-in for the sound's two calls, with their rule (one caller at a time; ending is nothing
# when nobody talks). No frame passes in this test, so a booked caller is still talking until
# stopped. The sound itself is audio_call_in_test's.
class Voice:
	extends RefCounted
	var booked := 0
	var stopped := 0
	var talking := false

	func call_in(_kind: String, _speaker: String, text: String) -> float:
		if talking or text == "":
			return 0.0
		talking = true
		booked += 1
		return 2.0

	func call_end() -> void:
		if talking:
			talking = false
			stopped += 1


# The line on screen is read and gone, and the gap since the last call has passed.
func _quiet() -> void:
	_bubble.hush()
	_bubble._clear_line()
	_bubble._process(LoreRows.CALL_GAP_S + 1.0)


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.world.set_physics_process(false)
	_game.world.activities.set_physics_process(false)
	_bubble = _game.get_node("Workshop").bubble
	_game.flow.press_start()
	_game.flow.choose_class(0)
	for i in 4:
		await physics_frame
	_check()
	_game.free()
	quit(_t.verdict())


func _check() -> void:
	var events = _game.events
	var at := Vector3.ZERO
	# The run's cold open is a comic beat with a card (check 10): no frame passes here to end it.
	_game.presentation.flourish.stop_all()
	# The hello waited for that card too (bubble_gives_way_test) and takes the bubble now.
	_bubble._process(0.1)
	# 1. The stage's hello has the bubble: a cause now waits for it, and speaks when it is gone.
	events.activity_done.emit("enemy_camp", at)
	_t.check("a call waits for the stage's hello", _bubble.visible and not _said("call.spillway.camp") and not _bubble._call.is_empty(),
		"bubble '%s'" % _bubble.text)
	_bubble.dismiss_exchange()
	_bubble._process(0.1)
	_t.check("a camp cleared brings the pump crew's line", _said("call.spillway.camp") and _bubble.text.begins_with("Pump crew: "),
		"bubble '%s'" % _bubble.text)
	_t.check("the line stays up long enough to read", _bubble._hold >= 1.6 + 0.3 * 8.0, "hold %.2f s" % _bubble._hold)
	# 2. Inside the gap a cause is dropped; it does not come up late.
	_bubble.hush()
	_bubble._clear_line()
	events.activity_done.emit("hold_the_relay", at)
	_bubble._process(0.1)
	_t.check("a cause inside the gap is dropped", not _bubble.visible and _bubble._call.is_empty(), "bubble '%s'" % _bubble.text)
	_quiet()
	events.activity_done.emit("hold_the_relay", at)
	_t.check("after the gap the relay's line speaks", _said("call.spillway.relay"), "bubble '%s'" % _bubble.text)
	# 3. Once a run.
	_quiet()
	events.activity_done.emit("enemy_camp", at)
	_t.check("a call is said once a run", not _bubble.visible and _bubble._call.is_empty(), "bubble '%s'" % _bubble.text)
	# 4. Held by a paused screen, it goes stale.
	paused = true
	events.trade_taken.emit("trade_risk", at)
	_t.check("a paused screen holds the call", not _bubble.visible and _bubble._call.get("id", "") == "call.spillway.gamble", "waiting %s" % [_bubble._call.get("id", "")])
	_bubble._process(LoreRows.CALL_FRESH_S + 0.1)
	paused = false
	_bubble._process(0.1)
	_t.check("a stale call is dropped, not played late", not _bubble.visible and _bubble._call.is_empty()
		and not _bubble._calls_played.has("call.spillway.gamble"), "bubble '%s'" % _bubble.text)
	# 5. Low hull.
	_quiet()
	events.player_hit.emit(1.0, "test")
	_t.check("a hit on a sound hull calls nobody", not _bubble.visible and _bubble._call.is_empty(), "bubble '%s'" % _bubble.text)
	var hp: float = _game.run.hp
	_game.run.hp = _game.run.max_hp * 0.2
	events.player_hit.emit(1.0, "test")
	_t.check("a hit on a low hull brings Moss's spare seal", _said("call.spillway.low_hull"), "bubble '%s'" % _bubble.text)
	_quiet()
	_bubble._calls_played.erase("call.spillway.low_hull")
	_game.run.hp = 0.0
	events.player_hit.emit(1.0, "test")
	_t.check("the killing hit calls nobody", not _bubble.visible and _bubble._call.is_empty(), "bubble '%s'" % _bubble.text)
	_game.run.hp = _game.run.max_hp * 0.2
	_quiet()
	_bubble._calls_played.erase("call.spillway.low_hull")
	paused = true
	events.player_hit.emit(1.0, "test")
	_game.run.hp = hp
	paused = false
	_bubble._process(0.1)
	_t.check("a hull mended before the call's turn calls nobody", not _bubble.visible and _bubble._call.is_empty()
		and not _bubble._calls_played.has("call.spillway.low_hull"), "bubble '%s'" % _bubble.text)
	# 6. A freed pilot who is not flying.
	_quiet()
	events.drop_landed.emit(3)
	_t.check("with nobody else freed, a big drop calls nobody", not _bubble.visible and _bubble._call.is_empty(), "bubble '%s'" % _bubble.text)
	_game.ctx.profile.unlock_pilot("tally")
	_game.ctx.profile.unlock_pilot("tarn")
	events.drop_landed.emit(2)
	_t.check("a small drop calls nobody", not _bubble.visible and _bubble._call.is_empty(), "bubble '%s'" % _bubble.text)
	var caller: Dictionary = _bubble.call_caused("drop_landed", [3])
	var flying: String = _game.run.class_id()
	var free := false
	for def in _game.flow.classes:
		if def.id == caller.get("pilot", ""):
			free = _game.pilot_unlocked(def)
	_t.check("a big drop is teased by a freed pilot who is not flying", caller.has("pilot") and caller["pilot"] != flying and free
		and _said(caller["id"]), "flying %s, caller %s, bubble '%s'" % [flying, caller.get("pilot", ""), _bubble.text])
	_quiet()
	events.drop_landed.emit(3)
	_t.check("one tease a run: the next big drop calls nobody", not _bubble.visible and _bubble._call.is_empty(), "bubble '%s'" % _bubble.text)
	# 7. Never over a fight.
	_quiet()
	var state: int = _game.flow.state
	_game.flow.state = _game.flow.BOSS
	_game.flow.boss_active = true
	events.evolution_fired.emit("hot_rivets")
	_t.check("with the boss up a cause calls nobody", not _bubble.visible and _bubble._call.is_empty(), "bubble '%s'" % _bubble.text)
	_game.flow.boss_active = false
	_game.flow.state = state
	events.evolution_fired.emit("hot_rivets")
	_t.check("the same cause outside the fight brings Moss's line", _said("call.spillway.evolved"), "bubble '%s'" % _bubble.text)
	_game.flow.state = _game.flow.BOSS
	_game.flow.boss_active = true
	_bubble._process(0.1)
	_t.check("a call that is up gives way when the fight goes live", _bubble._hold <= 0.0, "hold %.2f s" % _bubble._hold)
	_game.flow.boss_active = false
	_game.flow.state = state
	# 8. The Warden's fall.
	_quiet()
	events.beacon_unsealed.emit(1)
	_t.check("the dam Warden's fall is called by the pump crew", _said("call.spillway.dam_warden"), "bubble '%s'" % _bubble.text)
	# 11. The hello waits for the call that is up, then takes the bubble.
	_bubble._zones_played.clear()
	_bubble._begin_exchange(_game.run.stage)
	_t.check("the stage's hello waits for a call that is up", _said("call.spillway.dam_warden") and _bubble._hello_due == _game.run.stage,
		"bubble '%s', hello due %d" % [_bubble.text, _bubble._hello_due])
	_bubble.hush()
	_bubble._clear_line()
	_bubble._process(0.1)
	_t.check("and comes up when the call has gone", _bubble.visible and not _bubble._exchange.is_empty() and _bubble._hello_due == 0,
		"bubble '%s'" % _bubble.text)
	_bubble.dismiss_exchange()
	# 10. A comic beat's words.
	_quiet()
	var beat = _game.presentation.flourish
	_t.check("a comic beat with a card is up", beat.play("spillway_clear") and _game.presentation.reading())
	events.activity_done.emit("surge_run", at)
	_t.check("a call waits for a comic beat's words", not _bubble.visible and _bubble._call.get("id", "") == "call.spillway.surge",
		"bubble '%s', waiting %s" % [_bubble.text, _bubble._call.get("id", "")])
	beat.stop_all()
	_bubble._process(0.1)
	_t.check("and speaks when the beat has gone", _said("call.spillway.surge"), "bubble '%s'" % _bubble.text)
	# 9. A new run.
	events.run_started.emit(flying)
	_bubble.dismiss_exchange()
	events.activity_done.emit("enemy_camp", at)
	_bubble._process(0.1)
	_t.check("a new run can say them again", _said("call.spillway.camp"), "bubble '%s'" % _bubble.text)
	# 13. The voice and the card.
	var sound = _game.presentation.audio
	var voice := Voice.new()
	_game.presentation.audio = voice
	_quiet()
	events.run_started.emit(flying)
	_bubble.dismiss_exchange()
	events.activity_done.emit("enemy_camp", at)
	_bubble._process(0.1)
	_t.check("the camp call books its caller's voice", _said("call.spillway.camp") and voice.booked == 1 and voice.talking,
		"bubble '%s', booked %d" % [_bubble.text, voice.booked])
	_bubble._hold = 0.01
	_bubble._process(0.1)
	_t.check("a line that runs out its time leaves the voice alone", _bubble._hold <= 0.0 and voice.stopped == 0 and voice.talking,
		"hold %.2f, stopped %d" % [_bubble._hold, voice.stopped])
	_bubble._clear_line()
	_t.check("a line taken down stops its caller", voice.stopped == 1 and not voice.talking, "stopped %d" % voice.stopped)
	_bubble._process(LoreRows.CALL_GAP_S + 1.0)
	events.activity_done.emit("hold_the_relay", at)
	_t.check("the relay call is up and its caller talks", _said("call.spillway.relay") and voice.booked == 2, "bubble '%s', booked %d" % [_bubble.text, voice.booked])
	_game.flow.state = _game.flow.BOSS
	_game.flow.boss_active = true
	_bubble._process(0.1)
	_t.check("a fight going live stops the caller with the card", _bubble._hold <= 0.0 and voice.stopped == 2 and not voice.talking,
		"hold %.2f, stopped %d" % [_bubble._hold, voice.stopped])
	_game.flow.boss_active = false
	_game.flow.state = state
	_bubble._clear_line()
	_bubble._process(LoreRows.CALL_GAP_S + 1.0)
	events.activity_done.emit("surge_run", at)
	_t.check("the surge call is up and its caller talks", _said("call.spillway.surge") and voice.booked == 3, "bubble '%s', booked %d" % [_bubble.text, voice.booked])
	# Another line takes the bubble (a bark from the shop): the caller stops, and the bark books nobody.
	_bubble.bark({"line_id": "test", "text": "Not for sale.", "root": ""}, "shop_refused")
	_t.check("a bark that takes the bubble stops the caller under it", _bubble.text == "Not for sale." and voice.stopped == 3 and voice.booked == 3 and not voice.talking,
		"bubble '%s', stopped %d, booked %d" % [_bubble.text, voice.stopped, voice.booked])
	_bubble._zones_played.clear()
	_bubble._begin_exchange(_game.run.stage)
	_t.check("the stage's hello takes the bubble and its first speaker talks", not _bubble._exchange.is_empty() and voice.stopped == 3 and voice.booked == 4,
		"stopped %d, booked %d, bubble '%s'" % [voice.stopped, voice.booked, _bubble.text])
	var lines: int = _bubble._exchange.size()
	_bubble._advance_exchange()
	_t.check("the hello's next line stops the speaker before it, and its own speaker talks", lines > 1 and voice.stopped == 4 and voice.booked == 5,
		"lines %d, stopped %d, booked %d" % [lines, voice.stopped, voice.booked])
	# The Warden's intro is the site crew's line: the fight going live takes it and its voice down.
	_bubble.dismiss_exchange()
	_bubble._intros_played.clear()
	var booked := voice.booked
	var cut := voice.stopped
	events.warden_sighted.emit(_game.run.stage)
	_bubble._process(0.1)
	_t.check("the Warden's intro books the site crew's voice", _bubble._intro_showing and voice.booked == booked + 1 and voice.talking,
		"bubble '%s', booked %d (was %d)" % [_bubble.text, voice.booked, booked])
	cut = voice.stopped
	events.warden_engaged.emit(_game.run.stage)
	_t.check("the Warden waking stops the intro's voice", not _bubble._intro_showing and voice.stopped == cut + 1 and not voice.talking,
		"stopped %d (was %d)" % [voice.stopped, cut])
	_bubble.dismiss_exchange()
	var stopped := voice.stopped
	events.run_started.emit(flying)
	_bubble.dismiss_exchange()
	events.activity_done.emit("enemy_camp", at)
	_bubble._process(0.1)
	_t.check("a call is up for the run's end, its caller talking", _said("call.spillway.camp") and voice.talking, "bubble '%s'" % _bubble.text)
	stopped = voice.stopped
	# 12. The run ends under a call: it goes with the field.
	_game.run.damage(1.0e9, "test")
	_t.check("a call does not follow the run onto its end screen", not _game.flow.in_play() and _bubble._hold <= 0.0 and _bubble._call.is_empty(),
		"flow %s, hold %.2f" % [_game.flow.state_name(), _bubble._hold])
	_t.check("and its caller stops with it", voice.stopped == stopped + 1 and not voice.talking, "stopped %d (was %d)" % [voice.stopped, stopped])
	_game.presentation.audio = sound
