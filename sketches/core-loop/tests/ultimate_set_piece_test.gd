extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Bindings := preload("res://src/core/bindings.gd")
const T := preload("res://tests/support/t.gd")

# The set piece on Q (design-v3/SKILL-BAR.md sections 2, 4, 7), wave P-B unit B3, 2026-10-10.
# A real Game with Sable and the shared ult_default row. The ball flies on the physics tick;
# the plan and the Q press are called with a scripted aim so the path is chosen on purpose.
# Covers: the Q refusals (uncharged, busy), the path order line, rail, arc, hop; the meter
# sources and the stage-entry restore; recall refunds, bail spends, a stage change and a
# death abort; damage taken x0.2 with health floored at 1; Q breaks a hold and no hold starts
# during the ride; the landing pays and ends the chain; the line cut publishes no "broke";
# a closed Warden guard takes at most 45 posture in one set piece and an open core shatters;
# the run log's rows. Evidence limit: the rules in a headless run, not the feel of the ride.

const DT := 1.0 / 60.0
const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)

var _t := T.new("ultimate_set_piece_test")
var _game
var _player
var _combat
var _ult
var _source := Intent.Scripted.new()
var _fails: Array = []
var _started: Array = []
var _landed: Array = []
var _cancelled: Array = []
var _ready: Array = []
var _peaks: Array = []
var _lines: Array = []
var _broken: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _never() -> bool:
	return false


func _ground(dx: float, dz := 0.0) -> Vector3:
	return _game.ctx.terrain.drop_point(FLAT_SHELF.x + dx, FLAT_SHELF.z + dz, 1.0)


func _enemy(kind: String, dx: float, dz := 0.0) -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy(kind, _ground(dx, dz))
	if "live" in enemy:
		enemy.live = Callable(self, "_never")
	return enemy


# The ball back on the shelf, at rest. The teleport lands on the next physics step, so this
# waits for it before anything reads the ball's position.
func _home() -> void:
	_player.reset_to(_ground(0.0) + Vector3.UP * 1.0)
	await physics_frame
	await physics_frame
	_player.kit.rewind_left = 0.0
	_player.chain.reset()
	_fails.clear()
	_started.clear()
	_landed.clear()
	_cancelled.clear()
	_ready.clear()
	_peaks.clear()
	_lines.clear()
	_broken.clear()


func _fill() -> void:
	_ult.meter.locked = false
	_ult.meter.refund(_ult.meter.CAP)


# An aim from just above the ball toward a point.
func _aim_at(point: Vector3) -> Dictionary:
	var origin: Vector3 = _player.ball_position() + Vector3.UP * 2.0
	return {"origin": origin, "forward": (point - origin).normalized(), "harpoon": {"state": Augments.AIM_NONE}}


func _sky() -> Dictionary:
	return {"origin": _player.ball_position() + Vector3.UP * 2.0, "forward": Vector3.UP, "harpoon": {"state": Augments.AIM_NONE}}


# Waits out a running set piece, at most 5 s.
func _ride_out() -> void:
	for i in 300:
		if _ult.phase() == "idle":
			return
		await physics_frame


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
	_combat.heft_override = 1.0
	_ult = _combat.get("ultimate")
	_t.check("00 combat carries the set piece node", _ult != null)
	if _ult == null:
		quit(_t.verdict())
		return
	var ev = _game.events
	ev.verb_failed.connect(func(verb: String, reason: String, _at: Vector3): _fails.append([verb, reason]))
	ev.ultimate_started.connect(func(id: String, path: String, _from: Vector3, _to: Vector3, seconds: float): _started.append([id, path, seconds]))
	ev.ultimate_landed.connect(func(id: String, _at: Vector3, hits: int, damage: float): _landed.append([id, hits, damage]))
	ev.ultimate_cancelled.connect(func(id: String, reason: String, refunded: bool): _cancelled.append([id, reason, refunded]))
	ev.ultimate_ready.connect(func(id: String): _ready.append(id))
	ev.ultimate_peak.connect(func(id: String, _at: Vector3): _peaks.append(id))
	ev.line_state_changed.connect(func(state: String, _target: Node3D, _at: Vector3, cause: String): _lines.append([state, cause]))
	ev.hold_broken.connect(func(kind: String, method: String): _broken.append([kind, method]))

	# --- The meter on the record and its sources ---------------------------------------
	_t.check("01 the meter is the ability record's meter", _player.abilities.meter == _ult.meter and _player.abilities.ultimate()["id"] == "ult_default",
		"ultimate %s" % [_player.abilities.ultimate()])
	_ult.meter.reset()
	var a := _enemy("chaser", 14.0, 6.0)
	ev.enemy_killed.emit("chaser", Vector3.ZERO, 1)
	ev.near_miss.emit("bolt", Vector3.ZERO)
	ev.enemy_struck.emit(a, "ram", 10.0)
	ev.enemy_struck.emit(a, "ram", 10.0)
	_t.near("02 kill 1 + near miss 4 + one contact 2 (the second inside 0.5 s is gated)", _ult.meter.value, 7.0)
	await _sim(0.6)
	ev.enemy_struck.emit(a, "ram", 10.0)
	_t.check("03 a contact on the same enemy after 0.5 s pays again", absf(_ult.meter.value - 9.0) < 0.6, "%.2f" % _ult.meter.value)
	_ult.meter.reset()
	ev.enemy_struck.emit(a, _player.abilities.id_of(AbilityState.WEAPON), 12.0)
	_t.near("04 a weapon hit pays 0.25", _ult.meter.value, 0.25)
	_ult.meter.reset()
	# The handler the stage_entered connection calls; emitting the bus fact would restart the stage.
	_ult._on_stage_entered(_game.ctx.run.stage, false)
	_ult.meter.add("stagger")
	_ult._on_stage_entered(_game.ctx.run.stage, true)
	_t.near("05 a retry restores the stage-entry value", _ult.meter.value, 0.0)
	# 2026-10-10 fix round: a retry that restores a full entry publishes ultimate_ready, so the
	# layers that read it (music lift, glow, HUD) show full again (section 4).
	_ult.meter.refund(_ult.meter.CAP)
	_ult._on_stage_entered(_game.ctx.run.stage, false)
	_ult.meter.value = 0.0
	_ready.clear()
	_ult._on_stage_entered(_game.ctx.run.stage, true)
	_t.eq("05b a retry restoring a full meter emits ultimate_ready", [_ready, _ult.meter.full()], [["ult_default"], true])
	_ult.meter.reset()
	# Back to an empty entry through the handlers, so the next fill reads as a fresh one.
	_ult._on_stage_entered(_game.ctx.run.stage, false)
	_ult._on_stage_entered(_game.ctx.run.stage, true)
	_ult.meter.refund(99.0)
	_ready.clear()
	ev.enemy_killed.emit("chaser", Vector3.ZERO, 1)
	ev.enemy_killed.emit("chaser", Vector3.ZERO, 1)
	await _sim(0.05)
	_t.eq("06 ultimate_ready goes out once on reaching full", _ready, ["ult_default"])
	_t.eq("07 the record reads ready and full", [_player.abilities.ultimate()["state"], _player.abilities.ultimate()["fill"]], ["ready", 1.0])

	# --- Refusals ------------------------------------------------------------------------
	await _home()
	_ult.meter.reset()
	_t.eq("08 Q short of full is refused uncharged and spends nothing", [_ult.press(_sky()), _fails, _ult.phase(), _ult.meter.value],
		["uncharged", [["ultimate", "uncharged"]], "idle", 0.0])
	_t.eq("09 READS: Q is recall during the set piece", Bindings.READS["ultimate"]["set_piece"], "recall")

	# --- The path order ------------------------------------------------------------------
	await _home()
	var target := _ground(20.0)
	_t.eq("10 ground in arc reach plans an arc", String(_ult.plan(_player.ball_position(), _aim_at(target))["path"]), "arc")
	_t.eq("11 nothing to aim at plans the hop", String(_ult.plan(_player.ball_position(), _sky())["path"]), "hop")
	var lock := _aim_at(target)
	lock["harpoon"] = {"state": Augments.AIM_BODY, "point": a.global_position, "body": a}
	_t.eq("12 a harpoon lock plans a line to it", [String(_ult.plan(_player.ball_position(), lock)["path"]), _ult.plan(_player.ball_position(), lock)["to"]],
		["line", a.global_position])
	_ult.rail_query = func(point: Vector3) -> Dictionary: return {"entry": point + Vector3(5.0, 0.0, 0.0), "to": point + Vector3(30.0, 0.0, 0.0)}
	_t.eq("13 a rail entry within 12 m beats the arc in the framework order; ult_default (line, arc) keeps its arc",
		[String(_ult.plan(_player.ball_position(), _aim_at(target), ["line", "rail", "arc"])["path"]),
		String(_ult.plan(_player.ball_position(), _aim_at(target))["path"])], ["rail", "arc"])
	_ult.rail_query = Callable()
	var anchor: Vector3 = _player.ball_position() + Vector3(10.0, 4.0, 0.0)
	_player.grapple_to(anchor, Vector3.LEFT, null)
	_t.eq("14 a standing line beats every other path", [String(_ult.plan(_player.ball_position(), lock)["path"]), _ult.plan(_player.ball_position(), lock)["to"]],
		["line", anchor])
	var p: Dictionary = _ult.plan(_player.ball_position(), _aim_at(target))
	_t.check("15 a plan carries one leg and a flight of 1.6 to 3.2 s", (p["legs"] as Array).size() == 1 and float(p["flight"]) >= 1.6 and float(p["flight"]) <= 3.2,
		"legs %d, flight %.2f" % [(p["legs"] as Array).size(), float(p["flight"])])

	# --- Q with a line standing: the cut publishes no broke; a full meter never meets a dead Q
	_lines.clear()
	_fill()
	_player.abilities.select(AbilityState.SPECIAL)
	var picked_home: Array = []
	var on_snap := func(slot: String, reason: String): picked_home.append([slot, reason])
	ev.slot_selected.connect(on_snap)
	_t.eq("16 Q at a full meter starts", _ult.press(_aim_at(target)), "")
	ev.slot_selected.disconnect(on_snap)
	_t.eq("16b the start snaps a picked slot home with the reason ultimate", [picked_home, _player.abilities.selected],
		[[[AbilityState.WEAPON, "ultimate"]], AbilityState.WEAPON])
	_t.eq("17 the start emits once with the planned path, and the meter locks", [_started.size(), _ult.phase(), _ult.meter.locked, _ult.meter.value],
		[1, "windup", true, 0.0])
	_t.eq("18 the ability record reads active", _player.abilities.ultimate()["state"], "active")
	await _ride_out()
	var broke := _lines.filter(func(l): return l[0] == "broke")
	_t.eq("19 the handover publishes no broke", broke, [])
	_t.eq("20 the set piece lands once and goes idle", [_landed.size(), _ult.phase(), _ult.meter.locked], [1, "idle", false])

	await _home()
	_fill()
	_ult.press(_sky())
	_t.eq("21 a full meter with nothing to aim at hops", _started[0][1] if _started.size() > 0 else "", "hop")
	await _ride_out()

	# --- Busy -------------------------------------------------------------------------------
	await _home()
	_fill()
	_ult.press(_sky())
	await _sim(0.5)
	_fails.clear()
	_t.eq("22 Q while a set piece flies is refused busy", [_ult.press(_sky()), _fails], ["busy", [["ultimate", "busy"]]])
	await _ride_out()

	# --- Recall, bail, stage, death ---------------------------------------------------------
	await _home()
	_fill()
	_ult.press(_aim_at(target))
	await _sim(0.1)
	_source.press = {"ultimate_pressed": true}
	await _sim(0.05)
	_t.eq("23 Q in the wind-up recalls with a full refund", [_cancelled, _ult.phase(), _ult.meter.value, _landed],
		[[["ult_default", "recall", true]], "idle", 100.0, []])

	await _home()
	_fill()
	_ult.press(_aim_at(target))
	await _sim(0.6)
	var in_flight: bool = _ult.phase() == "flight"
	_source.press = {"jump_pressed": true}
	await _sim(0.05)
	# Spent: after the bail the ball still rolls fast, so speed may pay a few hundredths back.
	_t.check("24 Space in flight bails: spent, no landing", in_flight and _cancelled == [["ult_default", "bail", false]] and _ult.phase() == "idle"
		and _ult.meter.value < 1.0 and _landed.is_empty(), "flight %s, cancelled %s, meter %.3f, landed %s" % [in_flight, _cancelled, _ult.meter.value, _landed])

	# --- Defence -----------------------------------------------------------------------------
	await _home()
	var run = _game.ctx.run
	run.armor_mode = false
	run.hp = 50.0
	_fill()
	_ult.press(_aim_at(target))
	await _sim(0.1)
	# Set right before the hit: the hull regenerates between ticks.
	run.hp = 50.0
	_combat._on_player_hit(20.0, Vector3.ZERO, "test")
	var after_small: float = run.hp
	_combat._on_player_hit(500.0, Vector3.ZERO, "test")
	_t.eq("27 damage taken is x0.2 and health floors at 1", [after_small, run.hp], [46.0, 1.0])
	# 2026-10-10 fix round: the defence lives in RunState.damage, so a boss's direct run.damage
	# (Brindle's slag and charge, the Mind) is defended too, and armour sheds no scrap.
	var riding_still: bool = _ult.active()
	run.hp = 50.0
	run.damage(500.0, "brindle_charge")
	var direct_hp: float = run.hp
	run.armor_mode = true
	var mass_was: float = run.mass
	run.mass = 40.0
	var mass_before: float = run.mass
	run.hp = 50.0
	run.damage(500.0, "brindle_slag")
	_t.eq("27b a direct run.damage in the ride is defended; armour sheds no scrap",
		[riding_still, direct_hp, run.hp, run.mass], [true, 1.0, 1.0, mass_before])
	run.mass = mass_was
	run.armor_mode = false
	var holds = _combat.fleet.holds
	var b := _enemy("chaser", -8.0, 4.0)
	_t.eq("28 no hostile hold can start during the ride", holds.catch(b, "net", ["jump"]), false)
	await _ride_out()
	run.hp = run.max_hp

	await _home()
	var c := _enemy("chaser", -8.0, -4.0)
	holds.catch(c, "net", ["jump"])
	var held: bool = holds.holding()
	_fill()
	_ult.press(_aim_at(target))
	_t.eq("29 Q breaks a hold as hold_broken(kind, ultimate)", [held, holds.holding(), _broken], [true, false, [["net", "ultimate"]]])
	await _ride_out()

	# --- The landing pays and ends the chain; the run log -----------------------------------
	await _home()
	var d := _enemy("chaser", 20.0, 0.5)
	# Tough enough to outlive the volleys and the ram on the way in, so the landing meets it.
	d.max_hp = 5000.0
	d.hp = 5000.0
	for i in 3:
		_player.grapple_to(d.global_position, Vector3.UP, d)
		_player.release_grapple()
	var mult: float = _player.chain.multiplier()
	_fill()
	_ult.press(_aim_at(_ground(20.0, 0.5)))
	await _ride_out()
	var row: Dictionary = _player.chain.finished.back() if _player.chain.finished.size() > 0 else {}
	_t.check("30 the landing pays the chain x%.2f and ends it" % mult, mult > 1.0 and bool(row.get("paid", false)) and _player.chain.combo == 0,
		"finished %s" % [row])
	_t.check("31 the landing strike hits the enemy at B", _landed.size() == 1 and int(_landed[0][1]) >= 1 and float(_landed[0][2]) > 0.0, "landed %s" % [_landed])
	_t.eq("32 a peak went out on the middle beat", _peaks, ["ult_default"])
	var log_rows: Array = _game.ctx.run_log._record.get("ultimates", [])
	var last: Dictionary = log_rows.back() if log_rows.size() > 0 else {}
	_t.check("33 the run log keeps one ultimates row per start", log_rows.size() >= 5 and String(last.get("path", "")) == "arc" and int(last.get("landing_hits", 0)) >= 1
		and last.has("fill_seconds") and last.has("heft_class") and last.has("volley_hits"), "%d rows, last %s" % [log_rows.size(), last])
	var recalled: Array = log_rows.filter(func(r): return bool(r.get("recalled", false)))
	var bailed: Array = log_rows.filter(func(r): return bool(r.get("bailed", false)))
	_t.eq("34 the run log marks the recall and the bail", [recalled.size(), bailed.size()], [1, 1])
	var snaps: Dictionary = _game.ctx.run_log._record.get("snaps", {})
	_t.check("35 the run log counts the ultimate snap back", _game.ctx.run_log._record.has("picks") and _game.ctx.run_log._record.has("slot_casts")
		and _game.ctx.run_log._record.has("line_skill"), "snaps %s" % [snaps])

	# --- Wardens ----------------------------------------------------------------------------
	await _home()
	var w := _enemy("warden", 18.0, 0.0)
	var before: float = w.posture()
	_fill()
	_ult.press(_aim_at(_ground(18.0)))
	await _ride_out()
	var gained: float = w.posture() - before
	_t.check("36 a closed guard takes at most 45 posture from one set piece", gained > 0.0 and gained <= 45.001 and w.chunks_left() == 4,
		"gained %.2f, chunks %d" % [gained, w.chunks_left()])
	await _home()
	w._apply_posture({"gain": 100.0, "contact": false})
	var open: bool = w.staggered()
	_fill()
	_ult.press(_aim_at(_ground(18.0)))
	await _ride_out()
	_t.eq("37 an open core shatters on the landing", [open, w.chunks_left()], [true, 3])

	# --- A real harpoon smash pays 5 x the multiplier its landing paid (2026-10-10 fix round) -
	# chain.pay() zeroes the combo before harpoon_smashed goes out, so the feed must read the
	# landing's paid multiplier, not chain.multiplier() at emit time.
	await _home()
	var s := _enemy("chaser", 6.0, -8.0)
	s.max_hp = 5000.0
	s.hp = 5000.0
	_ult.meter.reset()
	var smashes: Array = []
	var on_smash := func(_e: Node3D, _at: Vector3, _speed: float): smashes.append(true)
	ev.harpoon_smashed.connect(on_smash)
	# Three links, then the committed haul lands through the player's own landing pair, as
	# hook_chain_test check 13 lands one: _begin_landing pays the chain, _finish_landing emits
	# harpoon_smashed. Run in one step, so no physics tick can end the chain in between. (A
	# physics-driven haul in this scene ended the chain with cause "ground" on the contact
	# frame before the landing paid it; reported as a follow-up, outside this unit.)
	for i in 2:
		_player.grapple_to(s.global_position, Vector3.UP, s)
		_player.release_grapple()
	_player.grapple_to(s.global_position, Vector3.UP, s)
	_player.kit.line_state = Augments.LINE_SMASH
	var landed: bool = _player._begin_landing(s)
	_player._finish_landing(s, 20.0)
	ev.harpoon_smashed.disconnect(on_smash)
	var smash_row: Dictionary = _player.chain.finished.back() if _player.chain.finished.size() > 0 else {}
	var combo := int(smash_row.get("combo", 0))
	var paid_mult := 1.0 + 0.3 * maxf(0.0, minf(float(combo), 6.0) - 1.0)
	var smash_pts := float(_ult.meter.sources.get("smash", 0.0))
	_t.check("38b a real smash on a %d-link chain pays 5 x %.2f to the meter" % [combo, paid_mult],
		landed and smashes.size() == 1 and bool(smash_row.get("paid", false)) and combo >= 3 and absf(smash_pts - 5.0 * paid_mult) < 0.001,
		"smashes %d, row %s, smash points %.3f" % [smashes.size(), smash_row, smash_pts])
	await _sim(0.3)

	# --- Aborts, last: these fire real reset facts on the bus -------------------------------
	await _home()
	_fill()
	_ult.press(_aim_at(target))
	await _sim(0.2)
	ev.stage_content_cleared.emit("test")
	_t.eq("38 a stage change aborts and spends", [_cancelled, _ult.phase(), _ult.meter.value], [[["ult_default", "stage", false]], "idle", 0.0])

	await _home()
	_fill()
	_ult.press(_aim_at(target))
	await _sim(0.2)
	ev.player_died.emit()
	_t.eq("39 a death aborts and spends", [_cancelled, _ult.phase(), _ult.meter.value], [[["ult_default", "death", false]], "idle", 0.0])

	quit(_t.verdict())
