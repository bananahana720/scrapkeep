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
	return _bubble.visible and _bubble.text == "%s: %s" % [LoreRows.SPEAKERS[row["speaker"]], row["text"]]


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
	# 9. A new run.
	events.run_started.emit(flying)
	_bubble.dismiss_exchange()
	events.activity_done.emit("enemy_camp", at)
	_bubble._process(0.1)
	_t.check("a new run can say them again", _said("call.spillway.camp"), "bubble '%s'" % _bubble.text)
