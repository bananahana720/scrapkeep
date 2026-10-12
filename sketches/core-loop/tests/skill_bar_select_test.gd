# 2026-10-12, W13 smoke triage: class c re-pin for 24cc872.
# Sable slot 3 line_reel -> bank_shot.
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const T := preload("res://tests/support/t.gd")

# The skill bar's selection (design-v3/SKILL-BAR.md sections 1 and 2), wave P-B unit B1,
# 2026-10-10. A table of scripted sequences through a real Game's player router and combat:
# keys 1, 2, 3 pick, left click casts the pick, and the pick snaps back on every reason in
# section 1 (cast, deselect, cancel, timeout, reset) and on none of the "no" rows (a harpoon
# bite, damage, a hostile hold). Also the edge rule (a pick and a press on one tick cast, a
# held click at the pick does not), the release latch, the timeout edge at 2.99 and 3.01 s,
# the timer pausing while a gauge charges, Kest's slot-1 gauge cancel, the refusals, a paused
# tree freezing the pick, and a retry sending the pick home.
# Each tick runs synchronously: the router, then combat's special and line steps, the order
# the physics frame runs them in. Evidence limit: the rule, not a played fight.

const DT := 1.0 / 60.0

var _t := T.new("skill_bar_select_test")
var _game
var _player
var _combat
var _source := Intent.Scripted.new()
var _selected: Array = []
var _cancelled: Array = []
var _fails: Array = []
var _casts: Array = []
var _specials := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


# One tick: the intent the source would poll, then the router, the grammar when asked, and
# combat's slot-2 and slot-3 steps. Returns the intent as combat read it.
func _tick(fields := {}, dt := DT, grammar := false):
	var intent = _player.intent
	intent.clear()
	for k in fields:
		intent.set(k, fields[k])
	_player._route_slots(dt)
	if grammar:
		_player._read_grammar()
	_combat._step_special(intent, dt)
	_combat._step_line(intent, dt)
	return intent


func _ticks(seconds: float, fields := {}) -> void:
	for i in roundi(seconds / DT):
		_tick(fields)


func _abilities():
	return _player.abilities


func _gauge():
	return _abilities().gauge(AbilityState.SPECIAL)


func _charges(slot: String) -> int:
	return int(_abilities().slot(slot).charges)


func _fresh() -> void:
	_tick()
	_abilities().refill()
	_abilities().snap_back("test")
	_player._fire_latched = false
	_player._click_held = false
	_combat._line_load = {}
	_player.kit.drop_line("reset")
	_selected.clear()
	_cancelled.clear()
	_fails.clear()
	_casts.clear()
	_specials = 0


func _last_reason() -> String:
	return String(_selected[-1][1]) if not _selected.is_empty() else ""


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	await _sim(0.6)
	_game.events.slot_selected.connect(func(slot: String, reason: String): _selected.append([slot, reason]))
	_game.events.gauge_cancelled.connect(func(id: String, reason: String): _cancelled.append([id, reason]))
	_game.events.verb_failed.connect(func(verb: String, reason: String, _at: Vector3): _fails.append([verb, reason]))
	_game.events.slot_cast.connect(func(slot: String, _id: String, _at: Vector3): _casts.append(slot))
	_game.events.special_used.connect(func(_id: String, _at: Vector3): _specials += 1)
	_player.set_physics_process(false)
	# 2026-10-12: Sable's kit merge (9000ca2) made Bank Shot her line skill; was line_reel.
	_t.eq("setup: Sable's bar", [_abilities().id_of("weapon"), _abilities().id_of("special"), _abilities().id_of("line")],
		["arc_caster", "detonation_gauge", "bank_shot"])

	# 1. Home at the start.
	_fresh()
	_t.eq("01 weapon is home", _abilities().selected, "weapon")

	# 2. 2 picks slot 2.
	_tick({"slot_pick": 1})
	_t.eq("02 2 picks the special", [_abilities().selected, _selected], ["special", [["special", "pick"]]])

	# 3. 2 again is the undo.
	_tick({"slot_pick": 1})
	_t.eq("03 2 again snaps home (deselect)", [_abilities().selected, _last_reason()], ["weapon", "deselect"])

	# 4. 3 then 1 is the undo too.
	_fresh()
	_tick({"slot_pick": 2})
	_tick({"slot_pick": 0})
	_t.eq("04 3 then 1 snaps home (deselect)", [_abilities().selected, _selected], ["weapon", [["line", "pick"], ["weapon", "deselect"]]])

	# 5. 1 at home publishes nothing.
	_fresh()
	_tick({"slot_pick": 0})
	_t.eq("05 1 at home publishes nothing", [_abilities().selected, _selected.size()], ["weapon", 0])

	# 6. With the weapon home, left click reaches the weapon.
	var out = _tick({"fire_pressed": true, "fire_held": true})
	_t.eq("06 home: the click stays the weapon's", [out.fire_pressed, out.special_pressed, out.line_pressed], [true, false, false])

	# 7. With 2 picked, the click becomes the special's and the weapon never sees it.
	_fresh()
	_tick({"slot_pick": 1})
	out = _tick({"fire_pressed": true, "fire_held": true})
	_t.eq("07 picked 2: the click routes to the special", [out.fire_pressed, out.fire_held, out.special_pressed, _gauge().charging],
		[false, false, true, true])

	# 8. A pick and a press on the same tick cast, the pick first.
	_fresh()
	_tick({"slot_pick": 1, "fire_pressed": true, "fire_held": true})
	_t.eq("08 pick and press on one tick begin the gauge", [_abilities().selected, _gauge().charging], ["special", true])

	# 9. A click already held when the pick lands does not cast.
	_fresh()
	_tick({"fire_held": true})
	_tick({"slot_pick": 1, "fire_held": true})
	_tick({"fire_held": true})
	_t.eq("09 a held click at the pick does not begin the gauge", [_abilities().selected, _gauge().charging], ["special", false])

	# 10. A gauge release is the cast: spent, published, home.
	_fresh()
	var before := _charges("special")
	_tick({"slot_pick": 1})
	_tick({"fire_pressed": true, "fire_held": true})
	_ticks(0.3, {"fire_held": true})
	_tick({"fire_released": true})
	_t.eq("10 a gauge release casts and snaps home (cast)",
		[_charges("special"), _specials, _casts, _abilities().selected, _last_reason()], [before - 1, 1, ["special"], "weapon", "cast"])

	# 11. The latch after a tap cast with the click held: the weapon sees nothing until the
	# click comes up, then the next press is the weapon's.
	_fresh()
	_tick({"slot_pick": 2})
	_tick({"fire_pressed": true, "fire_held": true})
	var cast_home: bool = _abilities().selected == "weapon" and _casts == ["line"] and _last_reason() == "cast"
	out = _tick({"fire_held": true})
	var held_dead: bool = not out.fire_pressed and not out.fire_held
	out = _tick({"fire_released": true})
	var up_dead: bool = not out.fire_released
	out = _tick({"fire_pressed": true, "fire_held": true})
	_t.check("11 the release latch after a tap cast", cast_home and held_dead and up_dead and out.fire_pressed and out.fire_held,
		"cast home %s, held dead %s, release dead %s, next press %s" % [cast_home, held_dead, up_dead, out.fire_pressed])

	# 12. A gauge held to its grace auto-fires; the click still down fires no weapon.
	_fresh()
	_tick({"slot_pick": 1})
	_tick({"fire_pressed": true, "fire_held": true})
	_ticks(1.6, {"fire_held": true})
	var auto_cast: bool = _specials == 1 and _abilities().selected == "weapon" and _last_reason() == "cast"
	out = _tick({"fire_held": true})
	_t.check("12 a grace auto-fire snaps home and latches the held click", auto_cast and not out.fire_held and not out.fire_pressed,
		"specials %d, selected %s, weapon held %s" % [_specials, _abilities().selected, out.fire_held])

	# 13. The timeout edge: still picked at 2.99 s, home at 3.01 s.
	_fresh()
	_tick({"slot_pick": 1}, 0.0)
	for i in 299:
		_tick({}, 0.01)
	var at_299: String = _abilities().selected
	_tick({}, 0.02)
	_t.eq("13 the pick holds at 2.99 s and snaps home at 3.01 s (timeout)", [at_299, _abilities().selected, _last_reason()],
		["special", "weapon", "timeout"])

	# 14. The timer pauses while a gauge charges.
	_fresh()
	_tick({"slot_pick": 1}, 0.0)
	_ticks(2.5)
	_tick({"fire_pressed": true, "fire_held": true})
	_ticks(0.8, {"fire_held": true})
	var paused_ok: bool = _abilities().selected == "special" and _gauge().charging
	_tick({"fire_released": true})
	_t.check("14 a charging gauge pauses the timeout", paused_ok and _specials == 1,
		"held 3.3 s with 0.8 s charging: still picked %s, then cast %d" % [paused_ok, _specials])

	# 15. RMB during a charge cancels it and the pick goes home, nothing spent.
	_fresh()
	before = _charges("special")
	_tick({"slot_pick": 1})
	_tick({"fire_pressed": true, "fire_held": true})
	_ticks(0.2, {"fire_held": true})
	_tick({"fire_held": true, "harpoon_pressed": true}, DT, true)
	_t.eq("15 RMB cancels the gauge and snaps home (cancel)",
		[_gauge().charging, _charges("special"), _abilities().selected, _last_reason(), _cancelled.has(["detonation_gauge", "cancel"])],
		[false, before, "weapon", "cancel", true])

	# 16. Another number mid-gauge: the gauge drops, the new slot is picked.
	_fresh()
	before = _charges("special")
	_tick({"slot_pick": 1})
	_tick({"fire_pressed": true, "fire_held": true})
	_ticks(0.2, {"fire_held": true})
	_tick({"slot_pick": 2, "fire_held": true})
	_t.eq("16 3 mid-gauge cancels it (swap) and picks the line",
		[_gauge().charging, _charges("special"), _abilities().selected, _cancelled, _selected[-1]],
		[false, before, "line", [["detonation_gauge", "swap"]], ["line", "swap"]])

	# 17. The same number mid-gauge: the gauge drops and the pick goes home.
	_fresh()
	_tick({"slot_pick": 1})
	_tick({"fire_pressed": true, "fire_held": true})
	_tick({"slot_pick": 1, "fire_held": true})
	_t.eq("17 2 mid-gauge cancels it and snaps home", [_gauge().charging, _abilities().selected, _cancelled, _last_reason()],
		[false, "weapon", [["detonation_gauge", "cancel"]], "deselect"])

	# 18. 1 mid-gauge: the same.
	_fresh()
	_tick({"slot_pick": 1})
	_tick({"fire_pressed": true, "fire_held": true})
	_tick({"slot_pick": 0, "fire_held": true})
	_t.eq("18 1 mid-gauge cancels it and snaps home", [_gauge().charging, _abilities().selected, _cancelled, _last_reason()],
		[false, "weapon", [["detonation_gauge", "cancel"]], "deselect"])

	# 19. Picking a cooling slot is refused and spends nothing.
	_fresh()
	_abilities().spend("special")
	before = _charges("special")
	_tick({"slot_pick": 1})
	_t.eq("19 a cooling slot is refused", [_abilities().selected, _fails, _charges("special"), _selected.size()],
		["weapon", [["select", "cooling"]], before, 0])

	# 20. Picking an unavailable slot is refused.
	_fresh()
	_abilities().slot("line").available = false
	_tick({"slot_pick": 2})
	_abilities().slot("line").available = true
	_t.eq("20 an unavailable slot is refused", [_abilities().selected, _fails], ["weapon", [["select", "unavailable"]]])

	# 21. A harpoon bite keeps the pick ("pick 3, bite, click").
	_fresh()
	_tick({"slot_pick": 2})
	_player.grapple_to(_player.ball_position() + Vector3(6.0, 4.0, 0.0), Vector3.RIGHT, null)
	_tick()
	_t.eq("21 a harpoon bite keeps the pick", [_player.kit.hooked, _abilities().selected], [true, "line"])
	_player.kit.drop_line("reset")

	# 22. Damage and a hostile hold keep the pick.
	_fresh()
	_tick({"slot_pick": 1})
	_game.events.player_hit.emit(5.0, "test")
	_game.events.hold_started.emit("grab", _player.ball_position())
	_tick()
	_t.eq("22 damage and a hold keep the pick", [_abilities().selected, _selected.size()], ["special", 1])

	# 23. A stage clear is a reset point.
	_fresh()
	_tick({"slot_pick": 2})
	_game.events.stage_content_cleared.emit("test")
	_t.eq("23 stage_content_cleared snaps home (reset)", [_abilities().selected, _last_reason()], ["weapon", "reset"])

	# 24. Kest's slot-1 sticky gauge drops when 2 is pressed, and 2 is picked.
	_fresh()
	_abilities().swap("weapon", "sticky_charge")
	var sticky = _abilities().gauge("weapon")
	sticky.begin()
	_tick({"slot_pick": 1})
	_t.eq("24 Kest's slot-1 gauge drops on a pick (swap)", [sticky.charging, _cancelled, _abilities().selected],
		[false, [["sticky_charge", "swap"]], "special"])
	_abilities().swap("weapon", "arc_caster")

	# 25. The kit-test path: special_pressed written directly still drives the gauge, home.
	_fresh()
	_tick({"special_pressed": true, "special_held": true})
	_t.eq("25 special_pressed written directly begins the gauge", [_gauge().charging, _abilities().selected], [true, "weapon"])
	_tick({"special_pressed": true})

	# 26. A paused tree freezes the pick and its timer.
	_fresh()
	_player.set_physics_process(true)
	_source.press = {"slot_pick": 1}
	await _sim(0.5)
	var left_before: float = _abilities().select_left()
	paused = true
	await _sim(4.0)
	paused = false
	var left_after: float = _abilities().select_left()
	_player.set_physics_process(false)
	_t.check("26 a paused tree freezes the pick", _abilities().selected == "special" and absf(left_before - left_after) < 0.001
		and left_before < 1.0,
		"selected %s, left %.3f before, %.3f after 4 s paused" % [_abilities().selected, left_before, left_after])

	# 27. Retry is a reset point.
	_fresh()
	_tick({"slot_pick": 2})
	_game.flow.retry_stage()
	_t.eq("27 a retry snaps home (reset)", [_abilities().selected, _last_reason()], ["weapon", "reset"])

	# 28. Death is a reset point.
	_fresh()
	_tick({"slot_pick": 1})
	_game.events.player_died.emit()
	_t.eq("28 death snaps home (reset)", [_abilities().selected, _last_reason()], ["weapon", "reset"])

	# 29. Run end is a reset point.
	_fresh()
	_tick({"slot_pick": 1})
	_game.events.run_ended.emit(false)
	_t.eq("29 run end snaps home (reset)", [_abilities().selected, _last_reason()], ["weapon", "reset"])

	# 30. A click on the timeout tick is the weapon's: the stale pick goes home first, so
	# no gauge begins and nothing fires twice (fix round, 2026-10-10).
	_fresh()
	_tick({"slot_pick": 1}, 0.0)
	for i in 299:
		_tick({}, 0.01)
	out = _tick({"fire_pressed": true, "fire_held": true}, 0.02)
	var timeout_click: Array = [_gauge().charging, _abilities().selected, out.fire_pressed, out.special_pressed]
	_tick({"fire_held": true})
	_t.eq("30 a click on the timeout tick goes to the weapon", [timeout_click, _specials, _last_reason()],
		[[false, "weapon", true, false], 0, "timeout"])

	# 31. A latch set by a snap is dropped once the click comes up, even with another slot
	# picked meanwhile: the auto-fire latches the held click, 2 is picked again with the click
	# still down, the click comes up, the pick times out with the click up, and the very next
	# click reaches the weapon (fix round, 2026-10-10).
	_fresh()
	_tick({"slot_pick": 1})
	_tick({"fire_pressed": true, "fire_held": true})
	_ticks(1.6, {"fire_held": true})
	var latched_after_auto: bool = _player._fire_latched
	_abilities().refill()
	_tick({"slot_pick": 1, "fire_held": true}, 0.0)
	var repicked: bool = _abilities().selected == "special"
	_tick({"fire_released": true}, 0.0)
	for i in 299:
		_tick({}, 0.01)
	_tick({}, 0.02)
	var timed_out: bool = _abilities().selected == "weapon" and _last_reason() == "timeout"
	out = _tick({"fire_pressed": true, "fire_held": true})
	_t.check("31 a stale latch never eats a later click",
		latched_after_auto and repicked and timed_out and out.fire_pressed and out.fire_held and not _player._fire_latched,
		"latched after auto-fire %s, re-picked %s, timed out %s, later press %s, latch %s" % [latched_after_auto, repicked,
		timed_out, out.fire_pressed, _player._fire_latched])


	quit(_t.verdict())
