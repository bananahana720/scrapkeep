extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const WordBudget := preload("res://src/core/word_budget.gd")

# The Scuttle tells a light build what to do. Phase 3's hull plating is 110 and a light
# build's punch is about 37, so its hits are turned and the only way in is a stun: a charge
# baited into the rim wall. Nothing on screen said so and such a build stalled. Now, once a
# try has come up short, the HUD toasts the hint's row, again every SCUTTLE_HINT_GAP seconds,
# until he is first stunned.
#
# The fight runs through the real boss module and HUD with the spawner double fixing the
# punch. The ball is held high over the bowl's middle, so every charge runs out short of the
# rim and none hits: no stun happens that the test did not ask for.
#
# Evidence limit: the toast's words are read from the HUD's toast row, not from pixels, and
# the chime is not listened for here.

const LIGHT := 37.0
const HEAVY := 160.0
const TICKS := 90

var _game
var _double
var _boss
var _failures := 0
var _prompts: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _words() -> String:
	return String(EventKinds.UI_ROWS[Rules.SCUTTLE_HINT]["hud"])


func _hints() -> int:
	return _prompts.count(Rules.SCUTTLE_HINT)


func _aloft() -> Vector3:
	return _boss.arena.global_position + Vector3.UP * 40.0


# Runs the fight for `seconds` with the ball held over the middle, or until `stop` is true.
func _fight(seconds: float, stop := Callable()) -> void:
	for i in int(seconds * TICKS):
		Harness.put_ball(_game, _aloft())
		await physics_frame
		if stop.is_valid() and stop.call():
			return


func _scuttle(punch: float) -> void:
	_game.flow.retry_stage()
	_game.run.heal(1000.0)
	_double.punch_override = punch
	_prompts.clear()
	_game.hud.clear_toasts()
	_boss.jump_to_phase(3)


func _ram_hull(punch: float) -> Dictionary:
	_double.strike(_boss.ship.hull, "ram", _double.force_for("ram", punch))
	return _double.strikes[_double.strikes.size() - 1]["result"]


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_double = Harness.install(_game)
	_boss = _game.boss
	_game.player.source = Intent.Scripted.new()
	_game.events.prompt_shown.connect(func(id: String): _prompts.append(id))
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	_check_row()
	await _check_other_phases()
	await _check_glance()
	await _check_missed_charge()
	await _check_heavy()
	print("brindle_scuttle_hint_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _check_row() -> void:
	var row: Dictionary = EventKinds.UI_ROWS.get(Rules.SCUTTLE_HINT, {})
	var words := WordBudget.words_in(String(row.get("hud", "")))
	var ok: bool = not row.is_empty() and words > 0 and words <= 4 and row.get("color") is Color and row.get("shape", "") in EventKinds.SHAPES
	for field in EventKinds.FIELDS:
		ok = ok and row.has(field)
	_report("the hint is a UI row of four words or fewer", ok, "%s: \"%s\" (%d words)" % [Rules.SCUTTLE_HINT, row.get("hud", ""), words])


# A turned hit in the Requisition or the Furnace is those phases' own lesson: no Scuttle hint.
func _check_other_phases() -> void:
	_double.punch_override = LIGHT
	_prompts.clear()
	var turned := 0
	for phase in [1, 2]:
		_boss.jump_to_phase(phase)
		await _fight(FightPhases.TRANSITION_SECONDS + 0.5)
		var result := _ram_hull(LIGHT)
		if not result["full"]:
			turned += 1
		await _fight(1.0)
	_report("no hint outside the Scuttle", turned == 2 and _hints() == 0 and _boss.take_hint() == "",
		"%d hull hits turned in phases 1 and 2, %d hints" % [turned, _hints()])


func _check_glance() -> void:
	await _scuttle(LIGHT)
	await _fight(0.5)
	var in_beat: bool = _boss._in_transition()
	var early := _ram_hull(LIGHT)
	await _fight(0.3)
	_report("the hint waits for the transition beat to end", in_beat and not early["full"] and _hints() == 0,
		"a turned hit %.1f s into the beat (in transition %s) raised %d hints" % [0.5, in_beat, _hints()])
	# The hint also waits for the HUD's toast row: the phase's own name is still up when the beat ends.
	await _fight(FightPhases.TRANSITION_SECONDS + 3.0, func(): return _hints() > 0)
	var after_beat: bool = not _boss._in_transition()
	_report("a hit the plating turned brings the hint", _hints() == 1 and after_beat and _game.hud.toast_texts() == [_words()],
		"punch %.0f against plating %.0f: %d hint, toast %s" % [early["punch"], early["plating"], _hints(), _game.hud.toast_texts()])
	var told_at: float = _boss.clock
	await _fight(Rules.SCUTTLE_HINT_GAP - 2.0)
	_ram_hull(LIGHT)
	await _fight(0.5)
	_report("it does not nag inside its gap", _hints() == 1 and _boss.stuns == 0,
		"%d hint in the %.1f s after the first, with another turned hit and %d stuns" % [_hints(), _boss.clock - told_at, _boss.stuns])
	await _fight(4.0, func(): return _hints() > 1)
	_report("it comes back after the gap while he is still unstunned", _hints() == 2 and _boss.clock - told_at >= Rules.SCUTTLE_HINT_GAP,
		"second hint %.1f s after the first (gap %.0f s)" % [_boss.clock - told_at, Rules.SCUTTLE_HINT_GAP])
	_boss._stun(0.5)
	await _fight(Rules.SCUTTLE_HINT_GAP + 3.0)
	_ram_hull(LIGHT)
	await _fight(1.0)
	_report("the first stun ends it for the fight", _hints() == 2 and _boss.stuns == 1,
		"%d hints after a stun and another %.0f s with a turned hit" % [_hints(), Rules.SCUTTLE_HINT_GAP + 4.0])


# A light build that never touches the hull still gets it, once a charge has run out with no stun.
func _check_missed_charge() -> void:
	await _scuttle(LIGHT)
	var before_charge := 0
	var charged := false
	for i in 12 * TICKS:
		Harness.put_ball(_game, _aloft())
		await physics_frame
		var state: String = _boss._charge.get("state", "")
		if state == _boss.CHARGE_RUN:
			charged = true
		if not charged:
			before_charge = maxi(before_charge, _hints())
		if _hints() > 0:
			break
	_report("a charge that runs out with no stun brings the hint to a ball that never hit", charged and before_charge == 0 and _hints() == 1
			and _boss.stuns == 0,
		"charged %s, hints before the first charge ran %d, hints after it ran out %d, stuns %d" % [charged, before_charge, _hints(), _boss.stuns])


# A build whose punch meets the plating can hit its way in: it is never told to bait the wall,
# not for a charge that runs out and not for a stray light hit the plating turns.
func _check_heavy() -> void:
	await _scuttle(HEAVY)
	await _fight(FightPhases.TRANSITION_SECONDS + 0.5)
	var landed := _ram_hull(HEAVY)
	await _fight(10.0)
	_report("a build that meets the plating gets no hint", landed["full"] and _hints() == 0,
		"punch %.0f against plating %.0f landed %s; %d hints over 12 s of charges" % [landed["punch"], landed["plating"], landed["full"], _hints()])
	var stray := _ram_hull(LIGHT)
	await _fight(3.0)
	_report("its stray light hit is not a short try", not stray["full"] and _hints() == 0 and _boss.take_hint() == "",
		"a punch %.0f hit turned by plating %.0f after the build showed punch %.0f: %d hints" % [stray["punch"], stray["plating"], HEAVY, _hints()])
	# A light build that showed a heavy hit once is no longer told.
	await _scuttle(LIGHT)
	await _fight(FightPhases.TRANSITION_SECONDS + 0.5)
	_ram_hull(HEAVY)
	_ram_hull(LIGHT)
	await _fight(3.0)
	_report("a ball whose punch has met the plating once is not told", _hints() == 0,
		"a punch %.0f hit, then a turned punch %.0f hit: %d hints" % [HEAVY, LIGHT, _hints()])
