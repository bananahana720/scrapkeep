extends SceneTree

const BuffLedger := preload("res://src/core/buff_ledger.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const WardenReactor := preload("res://src/combat/warden_reactor.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const T := preload("res://tests/support/t.gd")

# E1-06 Rivet (Iron Sixes) & Sable (Tap-Spark / Hold-Arc) cadence, interruptions, proc
# isolation, hold_auto data rollback, _sync_pattern mid-run refresh, pierce chip, Static
# Discharge speed term, and BuffLedger combat rows (PILOT-CADENCE.md §§2–4, Ruling ek).

const DT := 1.0 / 60.0

var _t := T.new("weapon_cadence_test")
var _game


func _initialize() -> void:
	_check_rivet_iron_sixes()
	_check_rivet_top_up_and_sprint_fan()
	_check_sable_tap_spark_hold_arc()
	_check_kest_lob_snap()
	_check_tarn_three_beats()
	_check_buffer_boundaries()
	_check_interruptions_and_sync_pattern()
	_check_hold_auto_data_rollback()
	_check_ultimate_and_swap()
	_check_warden_reactor_base_dps()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run_live.call_deferred()


func _press_intent(held := false) -> Intent:
	var intent := Intent.new()
	intent.fire_pressed = true
	intent.fire_held = held
	return intent


func _hold_intent() -> Intent:
	var intent := Intent.new()
	intent.fire_held = true
	return intent


func _release_intent() -> Intent:
	var intent := Intent.new()
	intent.fire_released = true
	return intent


func _check_rivet_iron_sixes() -> void:
	var pat: Resource = Weapons.base(Weapons.RAPID_LASER)
	var drv := WeaponDriver.new()
	drv.reset(pat)

	# 1. Press acts on the next physics tick (< 100 ms); holding does not repeat.
	var first: Array = drv.step(DT, _press_intent(true), Weapons.RAPID_LASER, pat, pat.rate)
	_t.eq("Rivet press fires immediately on next physics tick", first.size(), 1)
	_t.check("Rivet press latency is well under 100 ms", DT < 0.10, "%.4f s" % DT)
	_t.eq("Rivet cylinder decrements to 5", int(drv.state_snapshot()["chamber"]), 5)
	var held_shots := 0
	for _i in 30:
		held_shots += drv.step(DT, _hold_intent(), Weapons.RAPID_LASER, pat, pat.rate).size()
	_t.eq("Rivet held button fires once and waits", held_shots, 0)

	# 2. Fire remaining 5 rounds (total 6) -> 6th starts 0.95 s reload immediately.
	drv.reset(pat)
	var fired := 0
	for shot_i in 6:
		var out: Array = drv.step(DT, _press_intent(), Weapons.RAPID_LASER, pat, pat.rate)
		fired += out.size()
		if shot_i < 5:
			for _wait in 12:
				drv.step(DT, Intent.new(), Weapons.RAPID_LASER, pat, pat.rate)
	var snap: Dictionary = drv.state_snapshot()
	_t.eq("Rivet fires 6 rounds per cylinder", fired, 6)
	_t.check("6th round starts reload immediately with waiting notch",
		bool(snap["reloading"]) and int(snap["chamber"]) == 0 and String(snap["window"]) == WeaponDriver.WINDOW_WAITING,
		str(snap))

	# 3. Single-press timing rule: pressing before 0.38 s spends the notch -> reloads plain at 0.95 s.
	for _i in 12:
		drv.step(DT, Intent.new(), Weapons.RAPID_LASER, pat, pat.rate)
	var early: Array = drv.step(DT, _press_intent(), Weapons.RAPID_LASER, pat, pat.rate)
	_t.eq("early press during reload fires nothing", early.size(), 0)
	_t.eq("early press spends the reload notch", String(drv.state_snapshot()["window"]), WeaponDriver.WINDOW_SPENT)
	# Advance into [0.38, 0.54] and press again: spent window cannot pay!
	for _i in 14:
		drv.step(DT, Intent.new(), Weapons.RAPID_LASER, pat, pat.rate)
	var second_try: Array = drv.step(DT, _press_intent(), Weapons.RAPID_LASER, pat, pat.rate)
	_t.eq("second press inside spent notch cannot pay", second_try.size(), 0)
	_t.check("still reloading after spent notch", bool(drv.state_snapshot()["reloading"]), "")
	# Finish 0.95 s reload -> plain cylinder restored.
	for _i in 40:
		drv.step(DT, Intent.new(), Weapons.RAPID_LASER, pat, pat.rate)
	snap = drv.state_snapshot()
	_t.check("plain reload finishes at 0.95 s with 6 plain rounds",
		not bool(snap["reloading"]) and int(snap["chamber"]) == 6 and int(snap["hot"]) == 0, str(snap))

	# 4. Sweet-spot notch hit: shuts cylinder, loads 6 hot rounds (1.2x), fires 1st immediately, 6th pierces.
	for shot_i in 6:
		drv.step(DT, _press_intent(), Weapons.RAPID_LASER, pat, pat.rate)
		if shot_i < 5:
			for _w in 12:
				drv.step(DT, Intent.new(), Weapons.RAPID_LASER, pat, pat.rate)
	# Step to ~0.42 s (inside [0.38, 0.54]).
	for _i in 25:
		drv.step(DT, Intent.new(), Weapons.RAPID_LASER, pat, pat.rate)
	_t.check("notch is open at ~0.42 s", bool(drv.state_snapshot()["window_open"]), str(drv.state_snapshot()["reload_t"]))
	var notch_shots: Array = drv.step(DT, _press_intent(), Weapons.RAPID_LASER, pat, pat.rate)
	_t.eq("notch press fires 1st hot round immediately", notch_shots.size(), 1)
	_t.near("1st hot round carries 1.2x window_mult", float(notch_shots[0]["damage_mult"]), 1.2, 0.001)
	_t.eq("1st hot round does not pierce", bool(notch_shots[0]["pierce"]), false)
	_t.eq("5 hot rounds remain in cylinder", [int(drv.state_snapshot()["chamber"]), int(drv.state_snapshot()["hot"])], [5, 5])
	var pierce_flags: Array = [bool(notch_shots[0]["pierce"])]
	for _shot_i in 5:
		for _w in 12:
			drv.step(DT, Intent.new(), Weapons.RAPID_LASER, pat, pat.rate)
		var out: Array = drv.step(DT, _press_intent(), Weapons.RAPID_LASER, pat, pat.rate)
		pierce_flags.append(bool(out[0]["pierce"]) if not out.is_empty() else false)
	_t.eq("only the 6th hot round pierces", pierce_flags, [false, false, false, false, false, true])

	# 5. Input buffer (0.10 s): pressing 0.05 s before floor ends fires automatically on ready tick.
	drv.reset(pat)
	drv.step(DT, _press_intent(), Weapons.RAPID_LASER, pat, pat.rate)
	for _i in 9: # 0.15 s elapsed, 0.05 s remaining (<= 0.10 s buffer)
		drv.step(DT, Intent.new(), Weapons.RAPID_LASER, pat, pat.rate)
	var early_buf: Array = drv.step(DT, _press_intent(), Weapons.RAPID_LASER, pat, pat.rate)
	_t.eq("buffered press waits for floor", early_buf.size(), 0)
	_t.check("input buffer latched within 0.10 s", bool(drv.state_snapshot()["buffered"]), "")
	var buf_fired := 0
	for _i in 4:
		buf_fired += drv.step(DT, Intent.new(), Weapons.RAPID_LASER, pat, pat.rate).size()
	_t.eq("buffered press fires automatically when floor ends", buf_fired, 1)


func _check_rivet_top_up_and_sprint_fan() -> void:
	var pat: Resource = Weapons.base(Weapons.RAPID_LASER)
	var drv := WeaponDriver.new()
	drv.reset(pat)
	# Empty cylinder -> reloading -> Skid/Line Drive ends reload immediately with plain rounds.
	for shot_i in 6:
		drv.step(DT, _press_intent(), Weapons.RAPID_LASER, pat, pat.rate)
		if shot_i < 5:
			for _w in 12:
				drv.step(DT, Intent.new(), Weapons.RAPID_LASER, pat, pat.rate)
	_t.check("reloading before top_up_cylinder", bool(drv.state_snapshot()["reloading"]), "")
	_t.check("top_up_cylinder ends reload immediately", drv.top_up_cylinder(), "")
	var snap: Dictionary = drv.state_snapshot()
	_t.check("top_up_cylinder loads 6 plain rounds and clears reload",
		not bool(snap["reloading"]) and int(snap["chamber"]) == 6 and int(snap["hot"]) == 0, str(snap))

	# Hit notch (6 hot rounds, 1st fires -> 5 hot left), fire 3 more (2 hot left), then top up ->
	# remaining 2 hot rounds fire FIRST (with 6th hot piercing), followed by 4 plain rounds!
	for shot_i in 6:
		drv.step(DT, _press_intent(), Weapons.RAPID_LASER, pat, pat.rate)
		if shot_i < 5:
			for _w in 12:
				drv.step(DT, Intent.new(), Weapons.RAPID_LASER, pat, pat.rate)
	for _i in 25:
		drv.step(DT, Intent.new(), Weapons.RAPID_LASER, pat, pat.rate)
	drv.step(DT, _press_intent(), Weapons.RAPID_LASER, pat, pat.rate) # hot #1
	for _i in 3:
		for _w in 12:
			drv.step(DT, Intent.new(), Weapons.RAPID_LASER, pat, pat.rate)
		drv.step(DT, _press_intent(), Weapons.RAPID_LASER, pat, pat.rate) # hot #2, #3, #4
	_t.eq("before mid-cylinder top-up: 2 chamber, 2 hot", [int(drv.state_snapshot()["chamber"]), int(drv.state_snapshot()["hot"])], [2, 2])
	drv.top_up_cylinder()
	_t.eq("after mid-cylinder top-up: 6 chamber, 2 hot ahead of 4 plain", [int(drv.state_snapshot()["chamber"]), int(drv.state_snapshot()["hot"])], [6, 2])
	var hot_seq: Array = []
	var pierce_seq: Array = []
	for _i in 6:
		for _w in 12:
			drv.step(DT, Intent.new(), Weapons.RAPID_LASER, pat, pat.rate)
		var out: Array = drv.step(DT, _press_intent(), Weapons.RAPID_LASER, pat, pat.rate)
		hot_seq.append(bool(out[0].get("hot", false)))
		pierce_seq.append(bool(out[0].get("pierce", false)))
	_t.eq("hot rounds fire ahead of topped-up plain rounds", hot_seq, [true, true, false, false, false, false])
	_t.eq("6th hot round still pierces ahead of topped-up plain rounds", pierce_seq, [false, true, false, false, false, false])

	# Overdrive Sprint fan: holding button while sprinting fans remaining rounds at 0.10 s, 0.5x dmg, 5 deg spread, never trying notch.
	drv.reset(pat)
	var fan_shots: Array = []
	var s1: Array = drv.step(DT, _press_intent(true), Weapons.RAPID_LASER, pat, pat.rate, {"sprinting": true})
	fan_shots.append_array(s1)
	for _i in 45: # 0.75 s held while sprinting -> fans remaining 5 rounds, enters reload, hold never tries notch
		var out: Array = drv.step(DT, _hold_intent(), Weapons.RAPID_LASER, pat, pat.rate, {"sprinting": true})
		fan_shots.append_array(out)
	_t.eq("sprint fan empties 6-round cylinder", fan_shots.size(), 6)
	_t.near("fanned shots deal 0.5x damage", float(fan_shots[1]["damage_mult"]), 0.5, 0.001)
	_t.near("fanned shots carry 5 degree spread", float(fan_shots[1]["spread_deg"]), 5.0, 0.001)
	_t.check("holding during reload never spends or hits the notch",
		bool(drv.state_snapshot()["reloading"]) and String(drv.state_snapshot()["window"]) != WeaponDriver.WINDOW_HIT
		and String(drv.state_snapshot()["window"]) != WeaponDriver.WINDOW_SPENT,
		str(drv.state_snapshot()))


func _check_sable_tap_spark_hold_arc() -> void:
	var pat: Resource = Weapons.base(Weapons.ARC_CASTER)
	var drv := WeaponDriver.new()
	drv.reset(pat)

	# 1. Press fires spark immediately (< 100 ms); short tap (< 0.16 s) releases with no bolt.
	var tap: Array = drv.step(DT, _press_intent(true), Weapons.ARC_CASTER, pat, pat.rate, {"charge_rate": 1.0})
	_t.eq("Sable press fires spark immediately", tap.size(), 1)
	_t.eq("Sable tap kind is spark at 1.0x", [String(tap[0]["kind"]), float(tap[0]["damage_mult"])], [WeaponDriver.SHOT_SPARK, 1.0])
	for _i in 5: # ~0.08 s hold (< 0.16 s threshold)
		_t.eq("no extra spark while holding", drv.step(DT, _hold_intent(), Weapons.ARC_CASTER, pat, pat.rate, {"charge_rate": 1.0}).size(), 0)
	var short_rel: Array = drv.step(DT, _release_intent(), Weapons.ARC_CASTER, pat, pat.rate, {"charge_rate": 1.0})
	_t.eq("short tap under 0.16 s fires no bolt", short_rel.size(), 0)

	# 2. Release under 0.25 charge fires no bolt.
	drv.reset(pat)
	drv.step(DT, _press_intent(true), Weapons.ARC_CASTER, pat, pat.rate, {"charge_rate": 1.0})
	for _i in 15: # 0.25 s total = 0.09 s past 0.16 s -> charge ~0.14 (< 0.25)
		drv.step(DT, _hold_intent(), Weapons.ARC_CASTER, pat, pat.rate, {"charge_rate": 1.0})
	var low_charge := float(drv.state_snapshot()["charge"])
	var under_rel: Array = drv.step(DT, _release_intent(), Weapons.ARC_CASTER, pat, pat.rate, {"charge_rate": 1.0})
	_t.check("release under 0.25 charge fires no bolt", low_charge > 0.0 and low_charge < 0.25 and under_rel.is_empty(),
		"charge=%.3f shots=%d" % [low_charge, under_rel.size()])

	# 3. Full charge at BLAZING (2.0x -> 0.16 + 0.32 = 0.48 s) holds without decay or auto-fire, then releases 34 dmg bolt + 0.12 s recover.
	drv.reset(pat)
	drv.step(DT, _press_intent(true), Weapons.ARC_CASTER, pat, pat.rate, {"charge_rate": 2.0})
	for _i in 29: # ~0.483 s
		drv.step(DT, _hold_intent(), Weapons.ARC_CASTER, pat, pat.rate, {"charge_rate": 2.0})
	_t.near("blazing charge reaches 1.0 by 0.48 s", float(drv.state_snapshot()["charge"]), 1.0, 0.01)
	var auto_fired := 0
	for _i in 30: # hold 0.5 s longer at full: must NOT decay or auto-fire
		auto_fired += drv.step(DT, _hold_intent(), Weapons.ARC_CASTER, pat, pat.rate, {"charge_rate": 2.0}).size()
	_t.check("full charge holds indefinitely without decay or auto-fire",
		auto_fired == 0 and is_equal_approx(float(drv.state_snapshot()["charge"]), 1.0),
		"auto=%d charge=%.3f" % [auto_fired, float(drv.state_snapshot()["charge"])])
	var rel: Array = drv.step(DT, _release_intent(), Weapons.ARC_CASTER, pat, pat.rate, {"charge_rate": 2.0})
	_t.eq("release fires 1 charged bolt", rel.size(), 1)
	_t.near("full unmounted bolt deals 34 damage", pat.damage * float(rel[0]["damage_mult"]), 34.0, 0.01)
	_t.near("bolt applies 0.12 s recover", float(drv.state_snapshot()["recover"]), 0.12, 0.001)

	# 4. Mounted pylon_turret full bolt deals 36 damage; Static Discharge speed term is 0.8 (46.0 at 40 m/s).
	var turret: Resource = Weapons.base(Weapons.PYLON_TURRET)
	drv.reset(turret)
	drv.step(DT, _press_intent(true), Weapons.PYLON_TURRET, turret, turret.rate, {"charge_rate": 2.0})
	for _i in 30:
		drv.step(DT, _hold_intent(), Weapons.PYLON_TURRET, turret, turret.rate, {"charge_rate": 2.0})
	var mrel: Array = drv.step(DT, _release_intent(), Weapons.PYLON_TURRET, turret, turret.rate, {"charge_rate": 2.0})
	_t.near("full mounted turret bolt deals 36 damage", turret.damage * float(mrel[0]["damage_mult"]), 36.0, 0.01)
	_t.near("Static Discharge speed term is 0.8 per m/s", Weapons.BURST_DAMAGE_PER_SPEED, 0.8, 0.0001)
	_t.near("Static Discharge at 40 m/s deals 46.0", float(Weapons.burst(40.0)["damage"]), 46.0, 0.01)


func _check_kest_lob_snap() -> void:
	var pat: Resource = Weapons.base(Weapons.STICKY_CHARGE)
	var drv := WeaponDriver.new()
	drv.reset(pat)

	# 1. Press opens lob gauge immediately (< 100 ms); release < 0.10 s is tail drop, >= 0.10 s is lob.
	drv.step(DT, _press_intent(true), Weapons.STICKY_CHARGE, pat, pat.rate)
	_t.check("Kest press opens lob gauge immediately", bool(drv.state_snapshot()["lob_charging"]), str(drv.state_snapshot()))
	for _i in 3: # ~0.05 s (< 0.10 s)
		drv.step(DT, _hold_intent(), Weapons.STICKY_CHARGE, pat, pat.rate)
	var tail_shots: Array = drv.step(DT, _release_intent(), Weapons.STICKY_CHARGE, pat, pat.rate)
	_t.eq("short release < 0.10 s emits 1 tail drop throw", tail_shots.size(), 1)
	_t.check("short release marks tail_drop = true",
		String(tail_shots[0]["kind"]) == WeaponDriver.SHOT_THROW and bool(tail_shots[0]["tail_drop"]), str(tail_shots[0]))
	_t.eq("throw opens waiting snap window inside 0.60 s floor", String(drv.state_snapshot()["window"]), WeaponDriver.WINDOW_WAITING)
	_t.near("throw sets 0.60 s floor cooldown", float(drv.state_snapshot()["cooldown"]), 0.60, 0.01)

	# 2. Early press before 0.30 s spends the window -> second press inside [0.30, 0.55] cannot pay.
	for _i in 10: # ~0.167 s (< 0.30 s)
		drv.step(DT, Intent.new(), Weapons.STICKY_CHARGE, pat, pat.rate)
	var early_snap: Array = drv.step(DT, _press_intent(), Weapons.STICKY_CHARGE, pat, pat.rate)
	_t.eq("early snap press fires nothing", early_snap.size(), 0)
	_t.eq("early snap press spends the window", String(drv.state_snapshot()["window"]), WeaponDriver.WINDOW_SPENT)
	for _i in 12: # ~0.367 s (inside [0.30, 0.55])
		drv.step(DT, Intent.new(), Weapons.STICKY_CHARGE, pat, pat.rate)
	var second_try: Array = drv.step(DT, _press_intent(), Weapons.STICKY_CHARGE, pat, pat.rate)
	_t.eq("second press after spent window cannot snap", second_try.size(), 0)

	# 3. Lob (>= 0.10 s) + sweet-spot snap inside [0.30, 0.55] bursts 2x dmg, 1.35x radius, 1.5x knock,
	#    and holding the snap press never opens the next lob gauge.
	drv.reset(pat)
	drv.step(DT, _press_intent(true), Weapons.STICKY_CHARGE, pat, pat.rate)
	for _i in 12: # ~0.20 s (>= 0.10 s)
		drv.step(DT, _hold_intent(), Weapons.STICKY_CHARGE, pat, pat.rate)
	var lob_shots: Array = drv.step(DT, _release_intent(), Weapons.STICKY_CHARGE, pat, pat.rate)
	_t.check("hold >= 0.10 s releases a lob (tail_drop = false)",
		lob_shots.size() == 1 and not bool(lob_shots[0]["tail_drop"]) and float(lob_shots[0]["fraction"]) >= 0.25,
		str(lob_shots))
	for _i in 20: # ~0.333 s (inside [0.30, 0.55])
		drv.step(DT, Intent.new(), Weapons.STICKY_CHARGE, pat, pat.rate)
	_t.check("Kest snap window is open at ~0.33 s", bool(drv.state_snapshot()["window_open"]), str(drv.state_snapshot()))
	var snap_shots: Array = drv.step(DT, _press_intent(true), Weapons.STICKY_CHARGE, pat, pat.rate)
	_t.eq("snap press inside window emits 1 SHOT_SNAP", snap_shots.size(), 1)
	_t.check("SHOT_SNAP carries 2.0x dmg, 1.35x radius, 1.5x knock",
		String(snap_shots[0]["kind"]) == WeaponDriver.SHOT_SNAP
		and is_equal_approx(float(snap_shots[0]["damage_mult"]), 2.0)
		and is_equal_approx(float(snap_shots[0]["radius_mult"]), 1.35)
		and is_equal_approx(float(snap_shots[0]["knock_mult"]), 1.5), str(snap_shots[0]))
	for _i in 30: # hold well past the 0.60 s floor: snap press must NEVER open lob gauge while still held
		var held_out: Array = drv.step(DT, _hold_intent(), Weapons.STICKY_CHARGE, pat, pat.rate)
		_t.eq("holding snap press never throws", held_out.size(), 0)
	_t.check("holding snap press never opens lob gauge even after floor clears",
		not bool(drv.state_snapshot()["lob_charging"]) and bool(drv.state_snapshot()["snap_locked"]),
		str(drv.state_snapshot()))
	# Releasing unlocks the next press.
	drv.step(DT, _release_intent(), Weapons.STICKY_CHARGE, pat, pat.rate)
	_t.eq("releasing snap button clears snap_locked", bool(drv.state_snapshot()["snap_locked"]), false)
	drv.step(DT, _press_intent(true), Weapons.STICKY_CHARGE, pat, pat.rate)
	_t.eq("fresh press after release opens lob gauge cleanly", bool(drv.state_snapshot()["lob_charging"]), true)

	# 4. Snap window expires at 0.55 s (inside 0.60 s floor) so starting next throw at 0.60 s never eats the window.
	drv.reset(pat)
	drv.step(DT, _press_intent(false), Weapons.STICKY_CHARGE, pat, pat.rate)
	for _i in 34: # 0.567 s > 0.55 s
		drv.step(DT, Intent.new(), Weapons.STICKY_CHARGE, pat, pat.rate)
	_t.eq("snap window closes before 0.60 s floor", String(drv.state_snapshot()["window"]), WeaponDriver.WINDOW_SPENT)


func _check_tarn_three_beats() -> void:
	var pat: Resource = Weapons.base(Weapons.CLAW_SWEEP)
	var drv := WeaponDriver.new()
	drv.reset(pat)

	# 1. Press swings immediately (< 100 ms); holding swings once and waits.
	var b1: Array = drv.step(DT, _press_intent(true), Weapons.CLAW_SWEEP, pat, pat.rate, {"planar_speed": 14.0})
	_t.eq("Tarn Beat 1 fires immediately on press", b1.size(), 1)
	_t.check("Tarn Beat 1 is 18.0 dmg, 1.0x knock, beat 1",
		String(b1[0]["kind"]) == WeaponDriver.SHOT_BEAT_1 and int(b1[0]["beat"]) == 1
		and is_equal_approx(pat.damage * float(b1[0]["damage_mult"]), 18.0)
		and is_equal_approx(float(b1[0]["knock_mult"]), 1.0), str(b1[0]))
	var held_swings := 0
	for _i in 60:
		held_swings += drv.step(DT, _hold_intent(), Weapons.CLAW_SWEEP, pat, pat.rate, {"planar_speed": 14.0}).size()
	_t.eq("Tarn held button swings once and waits", held_swings, 0)

	# 2. Waiting > 0.75 s after Beat 1 resets to Beat 1 (not Beat 2).
	var b1_again: Array = drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, pat, pat.rate, {"planar_speed": 14.0})
	_t.eq("pressing > 0.75 s after Beat 1 resets to Beat 1", int(b1_again[0]["beat"]), 1)

	# 3. Pressing within [0.45, 0.75] fires Beat 2 (22.0 dmg) and opens [0.30, 0.54] Beat 3 window.
	for _i in 28: # ~0.467 s (past 0.45 s floor, inside 0.75 s beat window)
		drv.step(DT, Intent.new(), Weapons.CLAW_SWEEP, pat, pat.rate, {"planar_speed": 14.0})
	var b2: Array = drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, pat, pat.rate, {"planar_speed": 14.0})
	_t.check("Tarn Beat 2 deals 22.0 dmg, beat 2, opens waiting window",
		b2.size() == 1 and int(b2[0]["beat"]) == 2
		and is_equal_approx(pat.damage * float(b2[0]["damage_mult"]), 22.0)
		and String(drv.state_snapshot()["window"]) == WeaponDriver.WINDOW_WAITING, str(b2))

	# 4. Pressing inside [0.30, 0.54] fires Beat 3 with speed bonus (43 still / 50 cruise / 58 cap) & 2.0x knock + 0.50 s recover.
	for spd_case in [[0.0, 43.0], [14.0, 50.0], [30.0, 58.0], [50.0, 58.0]]:
		var spd: float = float(spd_case[0])
		var want_dmg: float = float(spd_case[1])
		drv.reset(pat)
		drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, pat, pat.rate, {"planar_speed": spd})
		for _i in 28:
			drv.step(DT, Intent.new(), Weapons.CLAW_SWEEP, pat, pat.rate, {"planar_speed": spd})
		drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, pat, pat.rate, {"planar_speed": spd})
		for _i in 20: # ~0.333 s (inside [0.30, 0.54])
			drv.step(DT, Intent.new(), Weapons.CLAW_SWEEP, pat, pat.rate, {"planar_speed": spd})
		_t.check("Beat 3 window open at ~0.33 s (speed=%.0f)" % spd, bool(drv.state_snapshot()["window_open"]), str(drv.state_snapshot()))
		var b3: Array = drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, pat, pat.rate, {"planar_speed": spd})
		_t.eq("Beat 3 fires 1 swing (speed=%.0f)" % spd, b3.size(), 1)
		_t.near("Beat 3 damage at %.0f m/s equals %.1f" % [spd, want_dmg], pat.damage * float(b3[0]["damage_mult"]), want_dmg, 0.05)
		_t.near("Beat 3 carries 2.0x knock (speed=%.0f)" % spd, float(b3[0]["knock_mult"]), 2.0, 0.001)
		_t.near("Beat 3 applies 0.50 s recovery (speed=%.0f)" % spd, float(drv.state_snapshot()["recover"]), 0.50, 0.005)
		_t.eq("Beat 3 resets beat to 0 (speed=%.0f)" % spd, int(drv.state_snapshot()["beat"]), 0)

	# 5. Early press (< 0.30 s after Beat 2) spends the window with no lockout; 0.10 s buffer before 0.55 s fires Beat 1.
	drv.reset(pat)
	drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, pat, pat.rate)
	for _i in 28:
		drv.step(DT, Intent.new(), Weapons.CLAW_SWEEP, pat, pat.rate)
	drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, pat, pat.rate) # Beat 2
	for _i in 10: # ~0.167 s (< 0.30 s)
		drv.step(DT, Intent.new(), Weapons.CLAW_SWEEP, pat, pat.rate)
	var early_b3: Array = drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, pat, pat.rate)
	_t.eq("early press after Beat 2 fires nothing", early_b3.size(), 0)
	_t.eq("early press after Beat 2 spends Beat 3 window", String(drv.state_snapshot()["window"]), WeaponDriver.WINDOW_SPENT)
	for _i in 19: # now ~0.483 s (~0.067 s left before 0.55 s floor -> within 0.10 s buffer)
		drv.step(DT, Intent.new(), Weapons.CLAW_SWEEP, pat, pat.rate)
	drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, pat, pat.rate)
	_t.eq("press within 0.10 s of Beat 2 floor buffers Beat 1 (no lockout)", bool(drv.state_snapshot()["buffered"]), true)
	var next_beats: Array = []
	for _i in 6:
		for s in drv.step(DT, Intent.new(), Weapons.CLAW_SWEEP, pat, pat.rate):
			next_beats.append(int(s["beat"]))
	_t.eq("spent Beat 3 window flows cleanly into Beat 1 at 0.55 s", next_beats, [1])

	# 6. Missed Beat 3 window (no press in [0.30, 0.54]) resets to Beat 1 at 0.55 s.
	drv.reset(pat)
	drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, pat, pat.rate)
	for _i in 28:
		drv.step(DT, Intent.new(), Weapons.CLAW_SWEEP, pat, pat.rate)
	drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, pat, pat.rate) # Beat 2
	for _i in 35: # > 0.55 s
		drv.step(DT, Intent.new(), Weapons.CLAW_SWEEP, pat, pat.rate)
	var after_miss: Array = drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, pat, pat.rate)
	_t.eq("missed Beat 3 window resets to Beat 1", int(after_miss[0]["beat"]), 1)

	# 7. Data extensibility: future Depth-1 keystones t_saw_flurry & t_guillotine work purely by Pattern data.
	var saw_pat: Resource = pat.copy()
	saw_pat.beat_floors_s = [0.35, 0.35]
	saw_pat.window_s = Vector2(0.0, 0.0)
	saw_pat.beat_mults = [1.0, 1.0, 1.0]
	drv.reset(saw_pat)
	drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, saw_pat, saw_pat.rate)
	for _i in 22: # ~0.367 s
		drv.step(DT, Intent.new(), Weapons.CLAW_SWEEP, saw_pat, saw_pat.rate)
	var saw_b2: Array = drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, saw_pat, saw_pat.rate)
	_t.check("t_saw_flurry data pattern runs flat beats with no Beat 3 window",
		saw_b2.size() == 1 and int(saw_b2[0]["beat"]) == 2
		and String(drv.state_snapshot()["window"]) == WeaponDriver.WINDOW_IDLE, str(drv.state_snapshot()))

	var guil_pat: Resource = pat.copy()
	guil_pat.beat_mults = [1.0, 22.0 / 18.0, 72.0 / 18.0]
	guil_pat.beat_range_mult = 1.4
	guil_pat.recover_s = 0.80
	drv.reset(guil_pat)
	drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, guil_pat, guil_pat.rate)
	for _i in 28:
		drv.step(DT, Intent.new(), Weapons.CLAW_SWEEP, guil_pat, guil_pat.rate)
	drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, guil_pat, guil_pat.rate)
	for _i in 20:
		drv.step(DT, Intent.new(), Weapons.CLAW_SWEEP, guil_pat, guil_pat.rate)
	var guil_b3: Array = drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, guil_pat, guil_pat.rate, {"planar_speed": 0.0})
	_t.check("t_guillotine data pattern amplifies Beat 3 damage, range_mult and recover_s without driver edits",
		guil_b3.size() == 1 and is_equal_approx(guil_pat.damage * float(guil_b3[0]["damage_mult"]), 72.0)
		and is_equal_approx(float(guil_b3[0]["range_mult"]), 1.4)
		and is_equal_approx(float(drv.state_snapshot()["recover"]), 0.80), str(guil_b3))


func _check_buffer_boundaries() -> void:
	var dt90 := 1.0 / 90.0
	var rivet: Resource = Weapons.base(Weapons.RAPID_LASER)
	var caster: Resource = Weapons.base(Weapons.ARC_CASTER)
	var drv := WeaponDriver.new()

	# 1. Rivet press floor at wait = BUFFER_S (0.10 s, 90 Hz) fires on the exact ready tick.
	drv.reset(rivet)
	drv.step(dt90, _press_intent(), Weapons.RAPID_LASER, rivet, rivet.rate)
	for _i in 8: # 8/90 s elapsed
		drv.step(dt90, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate)
	var r90_press: Array = drv.step(dt90, _press_intent(), Weapons.RAPID_LASER, rivet, rivet.rate) # 9/90 = 0.10 s left
	_t.check("Rivet 90 Hz press at wait=BUFFER_S latches without firing early",
		r90_press.is_empty() and bool(drv.state_snapshot()["buffered"]), str(drv.state_snapshot()))
	var r90_early := 0
	for _i in 8: # ticks 10..17
		r90_early += drv.step(dt90, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate).size()
	var r90_ready: Array = drv.step(dt90, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate) # tick 18
	_t.eq("Rivet 90 Hz wait=BUFFER_S fires on the exact ready tick", [r90_early, r90_ready.size()], [0, 1])

	# 2. Rivet press floor at wait = 0.09 s (60 Hz) fires on the exact ready tick.
	drv.reset(rivet)
	drv.step(DT, _press_intent(), Weapons.RAPID_LASER, rivet, rivet.rate)
	drv.set_cooldown_s(0.09 + DT)
	var r60_press: Array = drv.step(DT, _press_intent(), Weapons.RAPID_LASER, rivet, rivet.rate)
	_t.check("Rivet 60 Hz press at wait=0.09 s latches without firing early",
		r60_press.is_empty() and bool(drv.state_snapshot()["buffered"]), str(drv.state_snapshot()))
	var r60_early := 0
	for _i in 5:
		r60_early += drv.step(DT, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate).size()
	var r60_ready: Array = drv.step(DT, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate)
	_t.eq("Rivet 60 Hz wait=0.09 s fires on the exact ready tick", [r60_early, r60_ready.size()], [0, 1])

	# 3. Buffered press expires after BUFFER_S if trigger does not become ready in time.
	drv.reset(rivet)
	drv.step(DT, _press_intent(), Weapons.RAPID_LASER, rivet, rivet.rate)
	drv.set_cooldown_s(0.09 + DT)
	drv.step(DT, _press_intent(), Weapons.RAPID_LASER, rivet, rivet.rate)
	drv.set_cooldown_s(0.20) # pushed past BUFFER_S
	for _i in 6: # 0.10 s elapsed -> buffer must expire
		drv.step(DT, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate)
	_t.eq("buffered press expires once BUFFER_S elapses without becoming ready", bool(drv.state_snapshot()["buffered"]), false)
	var expired_shots := 0
	for _i in 10:
		expired_shots += drv.step(DT, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate).size()
	_t.eq("expired buffer never fires later", expired_shots, 0)

	# 4. Rivet reload-end buffering at ~0.09 s real remaining time under reload_rate_mult = 1.5 and 1.0.
	# At 90 Hz and 1.5x, 0.95 s reload finishes at tick 57 (57 * 1.5 / 90 = 0.95); tick 49 has 8/90 = 0.0889 s real left.
	drv.reset(rivet)
	for shot_i in 6:
		drv.step(dt90, _press_intent(), Weapons.RAPID_LASER, rivet, rivet.rate)
		if shot_i < 5:
			for _w in 18:
				drv.step(dt90, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate)
	for _i in 48:
		drv.step(dt90, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate, {"reload_rate_mult": 1.5})
	var rel15_press: Array = drv.step(dt90, _press_intent(), Weapons.RAPID_LASER, rivet, rivet.rate, {"reload_rate_mult": 1.5})
	_t.check("Rivet reload-end at 1.5x (0.089 s real left) latches buffer",
		rel15_press.is_empty() and bool(drv.state_snapshot()["buffered"]), str(drv.state_snapshot()))
	var rel15_early := 0
	for _i in 7: # ticks 50..56
		rel15_early += drv.step(dt90, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate, {"reload_rate_mult": 1.5}).size()
	var rel15_ready: Array = drv.step(dt90, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate, {"reload_rate_mult": 1.5}) # tick 57
	_t.eq("Rivet reload-end at 1.5x fires on the reload-complete tick", [rel15_early, rel15_ready.size()], [0, 1])

	# At 90 Hz and 1.0x, 0.95 s reload finishes at tick 86 (86/90 = 0.9556 s); tick 77 has 0.0944 s real left (9 ticks).
	drv.reset(rivet)
	for shot_i in 6:
		drv.step(dt90, _press_intent(), Weapons.RAPID_LASER, rivet, rivet.rate)
		if shot_i < 5:
			for _w in 18:
				drv.step(dt90, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate)
	for _i in 76:
		drv.step(dt90, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate, {"reload_rate_mult": 1.0})
	var rel10_press: Array = drv.step(dt90, _press_intent(), Weapons.RAPID_LASER, rivet, rivet.rate, {"reload_rate_mult": 1.0})
	_t.check("Rivet reload-end at 1.0x (0.094 s real left) latches buffer",
		rel10_press.is_empty() and bool(drv.state_snapshot()["buffered"]), str(drv.state_snapshot()))
	var rel10_early := 0
	for _i in 8: # ticks 78..85
		rel10_early += drv.step(dt90, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate, {"reload_rate_mult": 1.0}).size()
	var rel10_ready: Array = drv.step(dt90, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate, {"reload_rate_mult": 1.0}) # tick 86
	_t.eq("Rivet reload-end at 1.0x fires on the reload-complete tick", [rel10_early, rel10_ready.size()], [0, 1])

	# 5. Rivet sprint fan respects rate_mult < 1.0 (no 1.0 floor clamp).
	drv.reset(rivet)
	drv.step(DT, _press_intent(true), Weapons.RAPID_LASER, rivet, rivet.rate, {"sprinting": true, "rate_mult": 0.5})
	for _i in 24: # wait out 0.20 / 0.5 = 0.40 s first-shot floor
		drv.step(DT, _hold_intent(), Weapons.RAPID_LASER, rivet, rivet.rate, {"sprinting": true, "rate_mult": 0.5})
	_t.near("sprint fan scales floor by rate_mult < 1.0 (0.10 / 0.5 = 0.20 s)",
		float(drv.state_snapshot()["cooldown"]), Weapons.RIVET_FAN_FLOOR_S / 0.5, 0.02)

	# 6. Sable spark floor at 0.09 s (60 Hz) and 0.10 s (90 Hz) fires on the exact ready tick.
	drv.reset(caster)
	drv.step(DT, _press_intent(), Weapons.ARC_CASTER, caster, caster.rate)
	drv.set_cooldown_s(0.09 + DT)
	var s60_press: Array = drv.step(DT, _press_intent(), Weapons.ARC_CASTER, caster, caster.rate)
	_t.check("Sable spark 60 Hz at wait=0.09 s latches buffer",
		s60_press.is_empty() and bool(drv.state_snapshot()["buffered"]), str(drv.state_snapshot()))
	var s60_early := 0
	for _i in 5:
		s60_early += drv.step(DT, Intent.new(), Weapons.ARC_CASTER, caster, caster.rate).size()
	var s60_ready: Array = drv.step(DT, Intent.new(), Weapons.ARC_CASTER, caster, caster.rate)
	_t.eq("Sable spark 60 Hz wait=0.09 s fires on the exact ready tick", [s60_early, s60_ready.size()], [0, 1])

	drv.reset(caster)
	drv.step(dt90, _press_intent(), Weapons.ARC_CASTER, caster, caster.rate)
	for _i in 17: # 17/90 s elapsed on 0.30 s floor
		drv.step(dt90, Intent.new(), Weapons.ARC_CASTER, caster, caster.rate)
	var s90_press: Array = drv.step(dt90, _press_intent(), Weapons.ARC_CASTER, caster, caster.rate) # 0.10 s left
	_t.check("Sable spark 90 Hz at wait=0.10 s latches buffer",
		s90_press.is_empty() and bool(drv.state_snapshot()["buffered"]), str(drv.state_snapshot()))
	var s90_early := 0
	for _i in 8:
		s90_early += drv.step(dt90, Intent.new(), Weapons.ARC_CASTER, caster, caster.rate).size()
	var s90_ready: Array = drv.step(dt90, Intent.new(), Weapons.ARC_CASTER, caster, caster.rate)
	_t.eq("Sable spark 90 Hz wait=0.10 s fires on the exact ready tick", [s90_early, s90_ready.size()], [0, 1])

	# 7. Sable recover floor (0.12 s after bolt) at ~0.09 s (60 Hz) and ~0.10 s (90 Hz) fires on the ready tick.
	drv.reset(caster)
	drv.step(DT, _press_intent(true), Weapons.ARC_CASTER, caster, caster.rate, {"charge_rate": 2.0})
	for _i in 30:
		drv.step(DT, _hold_intent(), Weapons.ARC_CASTER, caster, caster.rate, {"charge_rate": 2.0})
	drv.step(DT, _release_intent(), Weapons.ARC_CASTER, caster, caster.rate, {"charge_rate": 2.0}) # recover_s = 0.12
	drv.step(DT, Intent.new(), Weapons.ARC_CASTER, caster, caster.rate) # tick 1: 0.1033 s left
	var rec60_press: Array = drv.step(DT, _press_intent(), Weapons.ARC_CASTER, caster, caster.rate) # tick 2: 0.0867 s left
	_t.check("Sable recover 60 Hz (~0.09 s left) latches buffer",
		rec60_press.is_empty() and bool(drv.state_snapshot()["buffered"]), str(drv.state_snapshot()))
	var rec60_early := 0
	for _i in 5: # ticks 3..7
		rec60_early += drv.step(DT, Intent.new(), Weapons.ARC_CASTER, caster, caster.rate).size()
	var rec60_ready: Array = drv.step(DT, Intent.new(), Weapons.ARC_CASTER, caster, caster.rate) # tick 8
	_t.eq("Sable recover 60 Hz fires on the exact ready tick", [rec60_early, rec60_ready.size()], [0, 1])

	drv.reset(caster)
	drv.step(dt90, _press_intent(true), Weapons.ARC_CASTER, caster, caster.rate, {"charge_rate": 2.0})
	for _i in 45:
		drv.step(dt90, _hold_intent(), Weapons.ARC_CASTER, caster, caster.rate, {"charge_rate": 2.0})
	drv.step(dt90, _release_intent(), Weapons.ARC_CASTER, caster, caster.rate, {"charge_rate": 2.0}) # recover_s = 0.12
	drv.step(dt90, Intent.new(), Weapons.ARC_CASTER, caster, caster.rate) # tick 1: 0.1089 s left
	var rec90_press: Array = drv.step(dt90, _press_intent(), Weapons.ARC_CASTER, caster, caster.rate) # tick 2: 0.0978 s left
	_t.check("Sable recover 90 Hz (~0.10 s left) latches buffer",
		rec90_press.is_empty() and bool(drv.state_snapshot()["buffered"]), str(drv.state_snapshot()))
	var rec90_early := 0
	for _i in 8: # ticks 3..10
		rec90_early += drv.step(dt90, Intent.new(), Weapons.ARC_CASTER, caster, caster.rate).size()
	var rec90_ready: Array = drv.step(dt90, Intent.new(), Weapons.ARC_CASTER, caster, caster.rate) # tick 11
	_t.eq("Sable recover 90 Hz fires on the exact ready tick", [rec90_early, rec90_ready.size()], [0, 1])


func _check_interruptions_and_sync_pattern() -> void:
	# Mount interrupt drops Sable's charge with no bolt and preserves spark floor cooldown.
	var caster: Resource = Weapons.base(Weapons.ARC_CASTER)
	var turret: Resource = Weapons.base(Weapons.PYLON_TURRET)
	var drv := WeaponDriver.new()
	drv.reset(caster)
	drv.step(DT, _press_intent(true), Weapons.ARC_CASTER, caster, caster.rate, {"charge_rate": 2.0})
	for _i in 12:
		drv.step(DT, _hold_intent(), Weapons.ARC_CASTER, caster, caster.rate, {"charge_rate": 2.0})
	var cd_before := drv.cooldown_s()
	_t.check("charging before mount interrupt", bool(drv.state_snapshot()["charging"]) and cd_before > 0.0, "")
	drv.interrupt(WeaponDriver.INTERRUPT_MOUNT)
	var after_mount: Dictionary = drv.state_snapshot()
	_t.check("mount interrupt drops charge and preserves spark floor",
		not bool(after_mount["charging"]) and is_zero_approx(float(after_mount["charge"])) and is_equal_approx(drv.cooldown_s(), cd_before),
		str(after_mount))
	# Switching weapon arc_caster -> pylon_turret keeps spark floor and fires no bolt on release.
	var post_swap: Array = drv.step(DT, _release_intent(), Weapons.PYLON_TURRET, turret, turret.rate, {"charge_rate": 2.0})
	_t.eq("mount swap drops charge with no bolt", post_swap.size(), 0)
	_t.check("mount swap preserves spark floor cooldown", drv.cooldown_s() > 0.0, "%.3f" % drv.cooldown_s())

	# Ultimate interrupt spends open reload notch but keeps reload running!
	var rivet: Resource = Weapons.base(Weapons.RAPID_LASER)
	drv.reset(rivet)
	for shot_i in 6:
		drv.step(DT, _press_intent(), Weapons.RAPID_LASER, rivet, rivet.rate)
		if shot_i < 5:
			for _w in 12:
				drv.step(DT, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate)
	for _i in 25:
		drv.step(DT, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate)
	_t.check("notch open before ultimate", bool(drv.state_snapshot()["window_open"]), "")
	drv.interrupt(WeaponDriver.INTERRUPT_ULTIMATE)
	var after_ult: Dictionary = drv.state_snapshot()
	_t.check("ultimate spends open notch and keeps reload running",
		bool(after_ult["reloading"]) and String(after_ult["window"]) == WeaponDriver.WINDOW_SPENT, str(after_ult))

	# Mid-run _sync_pattern refresh updates mag, reload_s and window_s even when weapon & trigger stay the same.
	drv.reset(rivet)
	drv.step(DT, _press_intent(), Weapons.RAPID_LASER, rivet, rivet.rate) # chamber = 5
	var modded: Resource = rivet.copy()
	modded.mag = 3
	modded.reload_s = 0.60
	modded.window_s = Vector2(0.20, 0.35)
	drv.sync_pattern(Weapons.RAPID_LASER, modded)
	var synced: Dictionary = drv.state_snapshot()
	_t.eq("sync_pattern refreshes mag and clamps chamber on same weapon/trigger",
		[int(synced["mag"]), int(synced["chamber"]), synced["window_range"]], [3, 3, Vector2(0.20, 0.35)])
	_t.near("sync_pattern refreshes reload_s", float(synced["reload_s"]), 0.60, 0.001)


func _check_hold_auto_data_rollback() -> void:
	# PILOT-CADENCE.md section 4: the BASE row with `trigger` alone set to hold_auto is today's gun.
	var legacy_rows := {
		Weapons.RAPID_LASER: [7.0, 12.0, 84.0],
		Weapons.ARC_CASTER: [12.0, 5.0, 60.0],
		Weapons.PYLON_TURRET: [11.0, 9.0, 99.0],
		Weapons.CLAW_SWEEP: [32.0, 2.0, 64.0],
	}
	for wid in legacy_rows:
		var flipped: Dictionary = Weapons.BASE[wid].duplicate()
		flipped["trigger"] = Pattern.TRIGGER_HOLD_AUTO
		var legacy: Resource = Pattern.make(Weapons.resolve_row(wid, flipped))
		var want: Array = legacy_rows[wid]
		_t.eq("%s with only trigger flipped reads the section 4 row" % wid,
			[legacy.trigger, legacy.damage, legacy.rate], [Pattern.TRIGGER_HOLD_AUTO, want[0], want[1]])
		_t.near("%s rolled back pays %.0f a second" % [wid, want[2]], WeaponDriver.base_dps(legacy), want[2], 0.001)
		_t.eq("%s hold_auto_base is the same flipped row" % wid,
			[Weapons.hold_auto_base(wid).damage, Weapons.hold_auto_base(wid).rate], [want[0], want[1]])
		_t.eq("%s cadence row is left as written" % wid, Weapons.resolve_row(wid, Weapons.BASE[wid]), Weapons.BASE[wid])
		var drv := WeaponDriver.new()
		drv.reset(legacy)
		var shots := 0
		for _i in 60: # 1.0 s held
			shots += drv.step(DT, _hold_intent(), wid, legacy, legacy.rate).size()
		_t.check("%s hold_auto data row restores continuous hold fire" % wid,
			shots >= int(legacy.rate) - 1 and shots <= int(legacy.rate) + 1,
			"shots=%d rate=%.1f" % [shots, legacy.rate])

	# Kest sticky_charge hold_auto rollback: 16.0 damage, no snap window (rate stays 0.0 slot-driven).
	var k_flip: Dictionary = Weapons.BASE[Weapons.STICKY_CHARGE].duplicate()
	k_flip["trigger"] = Pattern.TRIGGER_HOLD_AUTO
	var k_legacy: Resource = Pattern.make(Weapons.resolve_row(Weapons.STICKY_CHARGE, k_flip))
	_t.eq("sticky_charge hold_auto rollback restores 16.0 damage and disables snap window",
		[k_legacy.trigger, k_legacy.damage, k_legacy.window_s, k_legacy.window_mult],
		[Pattern.TRIGGER_HOLD_AUTO, 16.0, Vector2.ZERO, 1.0])
	_t.eq("sticky_charge hold_auto_base matches flipped row",
		[Weapons.hold_auto_base(Weapons.STICKY_CHARGE).damage, Weapons.hold_auto_base(Weapons.STICKY_CHARGE).window_s],
		[16.0, Vector2.ZERO])


func _check_ultimate_and_swap() -> void:
	# The ultimate drops Sable's charge with no bolt (PILOT-CADENCE.md section 2.3).
	var caster: Resource = Weapons.base(Weapons.ARC_CASTER)
	var drv := WeaponDriver.new()
	drv.reset(caster)
	drv.step(DT, _press_intent(true), Weapons.ARC_CASTER, caster, caster.rate, {"charge_rate": 1.0})
	for _i in 30:
		drv.step(DT, _hold_intent(), Weapons.ARC_CASTER, caster, caster.rate, {"charge_rate": 1.0})
	_t.check("charging before the ultimate", float(drv.state_snapshot()["charge"]) >= 0.25, str(drv.state_snapshot()["charge"]))
	drv.interrupt(WeaponDriver.INTERRUPT_ULTIMATE)
	_t.check("the ultimate drops the charge", not bool(drv.state_snapshot()["charging"])
		and is_zero_approx(float(drv.state_snapshot()["charge"])), str(drv.state_snapshot()))
	var after: Array = drv.step(DT, _release_intent(), Weapons.ARC_CASTER, caster, caster.rate, {"charge_rate": 1.0})
	_t.eq("a release after the ultimate fires no bolt", after.size(), 0)
	var ready_ticks := 0
	while not bool(drv.state_snapshot()["ready"]) and ready_ticks < 60:
		drv.step(DT, Intent.new(), Weapons.ARC_CASTER, caster, caster.rate)
		ready_ticks += 1
	_t.check("the trigger is ready again in bounded steps after the ultimate", ready_ticks < 60, "%d ticks" % ready_ticks)

	# A weapon swap drops the old weapon's reload and starts the new one at rest.
	var rivet: Resource = Weapons.base(Weapons.RAPID_LASER)
	drv.reset(rivet)
	for shot_i in 6:
		drv.step(DT, _press_intent(), Weapons.RAPID_LASER, rivet, rivet.rate)
		for _w in 12:
			drv.step(DT, Intent.new(), Weapons.RAPID_LASER, rivet, rivet.rate)
	_t.check("reloading before the swap", bool(drv.state_snapshot()["reloading"]), "")
	var swapped: Array = drv.step(DT, Intent.new(), Weapons.ARC_CASTER, caster, caster.rate)
	var snap: Dictionary = drv.state_snapshot()
	_t.check("the swap drops the reload and the new weapon starts at rest",
		swapped.is_empty() and not bool(snap["reloading"]) and String(snap["weapon"]) == Weapons.ARC_CASTER
		and String(snap["trigger"]) == Pattern.TRIGGER_TAP_CHARGE and bool(snap["ready"])
		and String(snap["window"]) == WeaponDriver.WINDOW_IDLE, str(snap))

	# A press weapon with no cylinder (mag 0) never runs dry.
	var bare: Resource = rivet.copy()
	bare.mag = 0
	drv.reset(bare)
	var fired := 0
	for _i in 20:
		fired += drv.step(DT, _press_intent(), Weapons.RAPID_LASER, bare, bare.rate).size()
		for _w in 12:
			drv.step(DT, Intent.new(), Weapons.RAPID_LASER, bare, bare.rate)
	_t.eq("a cylinder-less press weapon fires every press", fired, 20)

	# Kest ultimate interrupt drops lob charging, clears snap_locked and spends an open/waiting window.
	var kest: Resource = Weapons.base(Weapons.STICKY_CHARGE)
	drv.reset(kest)
	drv.step(DT, _press_intent(true), Weapons.STICKY_CHARGE, kest, kest.rate)
	for _i in 6:
		drv.step(DT, _hold_intent(), Weapons.STICKY_CHARGE, kest, kest.rate)
	_t.check("Kest lob charging before ultimate", bool(drv.state_snapshot()["lob_charging"]), "")
	drv.interrupt(WeaponDriver.INTERRUPT_ULTIMATE)
	_t.check("Kest ultimate drops lob gauge without throwing",
		not bool(drv.state_snapshot()["lob_charging"]) and not bool(drv.state_snapshot()["snap_locked"]),
		str(drv.state_snapshot()))
	drv.reset(kest)
	drv.step(DT, _press_intent(false), Weapons.STICKY_CHARGE, kest, kest.rate)
	for _i in 20:
		drv.step(DT, Intent.new(), Weapons.STICKY_CHARGE, kest, kest.rate)
	_t.check("Kest snap window open before ultimate", bool(drv.state_snapshot()["window_open"]), "")
	drv.interrupt(WeaponDriver.INTERRUPT_ULTIMATE)
	_t.eq("Kest ultimate spends open snap window", String(drv.state_snapshot()["window"]), WeaponDriver.WINDOW_SPENT)

	# Tarn ultimate interrupt resets beat to 0 and spends an open Beat 3 window.
	var tarn: Resource = Weapons.base(Weapons.CLAW_SWEEP)
	drv.reset(tarn)
	drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, tarn, tarn.rate)
	for _i in 28:
		drv.step(DT, Intent.new(), Weapons.CLAW_SWEEP, tarn, tarn.rate)
	drv.step(DT, _press_intent(), Weapons.CLAW_SWEEP, tarn, tarn.rate)
	for _i in 20:
		drv.step(DT, Intent.new(), Weapons.CLAW_SWEEP, tarn, tarn.rate)
	_t.check("Tarn Beat 3 window open before ultimate", bool(drv.state_snapshot()["window_open"]), "")
	drv.interrupt(WeaponDriver.INTERRUPT_ULTIMATE)
	var after_tarn_ult: Dictionary = drv.state_snapshot()
	_t.check("Tarn ultimate clears beat and spends Beat 3 window",
		int(after_tarn_ult["beat"]) == 0 and String(after_tarn_ult["window"]) == WeaponDriver.WINDOW_SPENT,
		str(after_tarn_ult))


func _check_warden_reactor_base_dps() -> void:
	_t.near("WardenReactor.base_dps routes Rivet through careless WeaponDriver.base_dps",
		WardenReactor.base_dps(Weapons.RAPID_LASER), 72.0 / 1.95, 0.01)
	_t.near("WardenReactor.base_dps routes Sable through careless WeaponDriver.base_dps",
		WardenReactor.base_dps(Weapons.ARC_CASTER), 8.0 / 0.30, 0.01)
	_t.near("WardenReactor.base_dps routes Pylon Turret through careless WeaponDriver.base_dps",
		WardenReactor.base_dps(Weapons.PYLON_TURRET), 9.0 / 0.30, 0.01)
	_t.near("WardenReactor.base_dps routes Kest through careless WeaponDriver.base_dps (18.33)",
		WardenReactor.base_dps(Weapons.STICKY_CHARGE), 11.0 / 0.60, 0.01)
	_t.near("WardenReactor.base_dps routes Tarn through careless WeaponDriver.base_dps (40.0)",
		WardenReactor.base_dps(Weapons.CLAW_SWEEP), 40.0, 0.01)


func _run_live() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	var source := Intent.Scripted.new()
	_game.player.source = source
	_game.flow.press_start()
	_game.flow.choose_class(1) # Rivet
	await physics_frame
	var combat = _game.ctx.spawner
	combat.set_physics_process(false)
	_game.player.set_physics_process(false)

	# 0. A press acts on the physics tick it arrives (well inside 100 ms), through combat's own tick.
	var rivet_pat: Resource = combat._patterns[Weapons.RAPID_LASER]
	combat.weapon_driver.reset(rivet_pat)
	var press_volleys: int = combat.volleys
	_game.player.intent.clear()
	_game.player.intent.fire_pressed = true
	_game.player.intent.fire_held = true
	combat._physics_process(DT)
	_t.eq("a live press fires on the tick it arrives", combat.volleys - press_volleys, 1)
	_t.eq("the live press spent one chamber", int(combat.weapon_driver.state_snapshot()["chamber"]), 5)
	_game.player.intent.clear()
	combat._physics_process(DT)

	# 0b. An attempt boundary takes a reload in flight back to rest.
	combat.weapon_driver.reset(rivet_pat)
	for _shot in 6:
		combat.weapon_driver.step(DT, _press_intent(), Weapons.RAPID_LASER, rivet_pat, rivet_pat.rate)
		for _w in 12:
			combat.weapon_driver.step(DT, Intent.new(), Weapons.RAPID_LASER, rivet_pat, rivet_pat.rate)
	_t.check("reload in flight before the attempt boundary", bool(combat.weapon_driver.state_snapshot()["reloading"]), "")
	combat._start_attempt()
	var rest: Dictionary = combat.weapon_driver.state_snapshot()
	_t.check("the attempt boundary returns Rivet to rest: a full plain cylinder, no reload, no window",
		not bool(rest["reloading"]) and int(rest["chamber"]) == 6 and int(rest["hot"]) == 0
		and String(rest["window"]) == WeaponDriver.WINDOW_IDLE and bool(rest["ready"]), str(rest))

	# 1. Proc isolation: item_proc never spends a chamber, never mutates WeaponDriver, fires plain damage.
	combat.weapon_driver.reset(combat._patterns[Weapons.RAPID_LASER])
	combat.weapon_driver.step(DT, _press_intent(), Weapons.RAPID_LASER, combat._patterns[Weapons.RAPID_LASER], combat._rate(Weapons.RAPID_LASER))
	var before_proc: Dictionary = combat.weapon_driver.state_snapshot()
	var volleys_before: int = combat.volleys
	combat._fire(Weapons.RAPID_LASER, "item_proc")
	var after_proc: Dictionary = combat.weapon_driver.state_snapshot()
	_t.eq("proc shot fires without mutating WeaponDriver state", after_proc, before_proc)
	_t.eq("proc shot still fired one volley", combat.volleys, volleys_before + 1)

	# 2. Rivet's 6th hot round pierces plating at 50% chip vs 20% normal (PILOT-CADENCE §2.5).
	var brute: Node3D = combat.spawn_enemy("plated_brute", _game.player.ball_position() + Vector3.FORWARD * 8.0)
	brute.set_physics_process(false)
	var plain_res: Dictionary = combat.resolve(brute, "runner", 14.4)
	var pierce_res: Dictionary = combat.resolve(brute, "runner", 14.4, "", 0.0, 0.0, Weapons.PIERCE_CHIP)
	_t.check("normal round chips plated brute at 20%, 6th hot round chips at 50% without ignoring plating",
		not bool(plain_res["full"]) and not bool(pierce_res["full"])
		and is_equal_approx(float(plain_res["dealt"]), 14.4 * combat.CHIP)
		and is_equal_approx(float(pierce_res["dealt"]), 14.4 * Weapons.PIERCE_CHIP),
		"plain=%.2f pierce=%.2f" % [float(plain_res["dealt"]), float(pierce_res["dealt"])])

	# 3. Overdrive shortens Rivet floor to 0.125 s (0.20 / 1.6) and posts Overdrive row to BuffLedger.
	combat._boost(Weapons.OVERDRIVE_SECONDS)
	var od_ctx: Dictionary = combat._weapon_step_context(Weapons.RAPID_LASER, combat._patterns[Weapons.RAPID_LASER], combat._rate(Weapons.RAPID_LASER))
	_t.near("Overdrive rate_mult is 1.6 (0.125 s floor)", float(od_ctx["rate_mult"]), 1.6, 0.001)
	var od_row: Dictionary = _find_buff(_game.ctx.buffs.active_rows(), "overdrive")
	_t.check("Overdrive posts visible timer row to BuffLedger with lawful tone",
		not od_row.is_empty() and _lawful_tone(od_row["tone"]), str(od_row))

	# 4. Spring, cloak, and Slag Pike rows post to BuffLedger with lawful tones and clear on attempt boundary.
	combat._spring_until = combat._clock + combat.SPRING_WINDOW
	combat._post_buff("spring", {"icon": "spring", "tone": Palette.AMBER, "kind": BuffLedger.KIND_TIMER,
		"duration_s": combat.SPRING_WINDOW, "left_s": combat.SPRING_WINDOW})
	var spring_row: Dictionary = _find_buff(_game.ctx.buffs.active_rows(), "spring")
	_t.check("Spring posts visible timer row to BuffLedger with lawful tone",
		not spring_row.is_empty() and _lawful_tone(spring_row["tone"]), str(spring_row))

	# Cloak: Kest's 1.5 s cloak is filtered below the 3 s rail minimum, and becomes visible when >= 3 s.
	combat._post_buff("cloak", {"icon": "cloak", "tone": Palette.STEEL, "kind": BuffLedger.KIND_TIMER,
		"duration_s": Weapons.CLOAK_SECONDS, "left_s": Weapons.CLOAK_SECONDS})
	_t.check("Cloak 1.5 s row is filtered below 3 s rail minimum",
		_find_buff(_game.ctx.buffs.active_rows(), "cloak").is_empty(), "")
	combat._post_buff("cloak", {"icon": "cloak", "tone": Palette.STEEL, "kind": BuffLedger.KIND_TIMER,
		"duration_s": 4.0, "left_s": 4.0})
	var cloak_row: Dictionary = _find_buff(_game.ctx.buffs.active_rows(), "cloak")
	_t.check("Extended Cloak posts visible row with lawful tone",
		not cloak_row.is_empty() and _lawful_tone(cloak_row["tone"]), str(cloak_row))

	# Slag Pike counter row.
	combat._post_buff("pike", {"icon": "pike", "tone": Palette.AMBER, "kind": BuffLedger.KIND_COUNT, "stacks": 3, "max_stacks": 5})
	var pike_row: Dictionary = _find_buff(_game.ctx.buffs.active_rows(), "pike")
	_t.check("Slag Pike posts counter row with stacks=3 and lawful tone",
		not pike_row.is_empty() and int(pike_row["stacks"]) == 3 and _lawful_tone(pike_row["tone"]), str(pike_row))

	# Attempt boundary clears all combat buffs and resets WeaponDriver.
	combat._start_attempt()
	_t.check("attempt boundary clears Overdrive, spring, cloak and pike rows",
		_game.ctx.buffs.active_rows().is_empty(),
		str(_game.ctx.buffs.active_rows()))

	# 5. Sable mounted 3 s blazing-plant boost -> walk rate after 3 s.
	_game.flow.choose_class(0) # Sable
	await physics_frame
	combat.set_physics_process(false)
	_game.player.set_physics_process(false)
	var caster_pat: Resource = combat._patterns[Weapons.ARC_CASTER]
	combat.weapon_driver.reset(caster_pat)
	combat.weapon_driver.step(DT, _press_intent(true), Weapons.ARC_CASTER, caster_pat, caster_pat.rate, {"charge_rate": 1.0})
	for _i in 30:
		combat.weapon_driver.step(DT, _hold_intent(), Weapons.ARC_CASTER, caster_pat, caster_pat.rate, {"charge_rate": 1.0})
	var mid_charge: Dictionary = combat.weapon_driver.state_snapshot()
	var sable_volleys: int = combat.volleys
	combat._fire(Weapons.ARC_CASTER, "item_proc")
	_t.eq("a proc spark mid-charge leaves Sable's charge, floor and buffer untouched", combat.weapon_driver.state_snapshot(), mid_charge)
	_t.eq("the proc still fired its plain spark", combat.volleys, sable_volleys + 1)
	_t.eq("the proc fired a plain shot, never a bolt", String(combat.last_shot.get("kind", "")), WeaponDriver.SHOT_PLAIN)
	combat._start_attempt()
	var sable_rest: Dictionary = combat.weapon_driver.state_snapshot()
	_t.check("the attempt boundary drops Sable's charge with no bolt",
		not bool(sable_rest["charging"]) and not bool(sable_rest["charge_armed"]) and is_zero_approx(float(sable_rest["charge"])),
		str(sable_rest))
	_game.player.kit.mounted = true
	_game.player.kit.mount_banked = 32.0 # blazing tier (>= 26.6)
	_game.events.mounted.emit(_game.player.ball_position(), 32.0)
	var mctx_now: Dictionary = combat._weapon_step_context(Weapons.PYLON_TURRET, combat._patterns[Weapons.PYLON_TURRET], combat._rate(Weapons.PYLON_TURRET))
	_t.near("mounted Sable reads blazing banked charge rate (2.0x) right after plant", float(mctx_now["charge_rate"]), 2.0, 0.001)
	combat._mounted_boost_left = 0.0
	var mctx_later: Dictionary = combat._weapon_step_context(Weapons.PYLON_TURRET, combat._patterns[Weapons.PYLON_TURRET], combat._rate(Weapons.PYLON_TURRET))
	_t.near("mounted Sable drops to walk charge rate (1.0x) after 3 s", float(mctx_later["charge_rate"]), 1.0, 0.001)

	# 6. WC-1 (RestAfterBoundary): run_ended and summary/title transitions return WeaponDriver to rest.
	# 6a. Rivet mid-reload + buffered -> run_ended(true) returns to rest.
	combat.weapon_driver.reset(rivet_pat)
	combat.weapon_driver.step(DT, _press_intent(), Weapons.RAPID_LASER, rivet_pat, rivet_pat.rate)
	for _shot in 5:
		for _w in 12:
			combat.weapon_driver.step(DT, Intent.new(), Weapons.RAPID_LASER, rivet_pat, rivet_pat.rate)
		combat.weapon_driver.step(DT, _press_intent(), Weapons.RAPID_LASER, rivet_pat, rivet_pat.rate)
	_t.check("WC-1 setup: Rivet reloading before run_ended", bool(combat.weapon_driver.state_snapshot()["reloading"]), "")
	_game.events.run_ended.emit(true)
	var after_end_rivet: Dictionary = combat.weapon_driver.state_snapshot()
	_t.check("WC-1: run_ended returns reloading Rivet to rest", _is_at_rest(after_end_rivet, 6), str(after_end_rivet))

	# 6b. Rivet partial hot cylinder + cooldown + buffer -> flow_changed("summary") (Victory Lap close) returns to rest.
	combat.weapon_driver.reset(rivet_pat)
	for _shot in 6:
		combat.weapon_driver.step(DT, _press_intent(), Weapons.RAPID_LASER, rivet_pat, rivet_pat.rate)
		if _shot < 5:
			for _w in 12:
				combat.weapon_driver.step(DT, Intent.new(), Weapons.RAPID_LASER, rivet_pat, rivet_pat.rate)
	for _i in 25:
		combat.weapon_driver.step(DT, Intent.new(), Weapons.RAPID_LASER, rivet_pat, rivet_pat.rate)
	combat.weapon_driver.step(DT, _press_intent(), Weapons.RAPID_LASER, rivet_pat, rivet_pat.rate) # hot #1
	combat.weapon_driver.set_cooldown_s(0.05 + DT)
	combat.weapon_driver.step(DT, _press_intent(), Weapons.RAPID_LASER, rivet_pat, rivet_pat.rate) # buffered
	var pre_summary: Dictionary = combat.weapon_driver.state_snapshot()
	_t.check("WC-1 setup: Rivet has hot rounds, cooldown and buffer before summary",
		int(pre_summary["hot"]) > 0 and float(pre_summary["cooldown"]) > 0.0 and bool(pre_summary["buffered"]),
		str(pre_summary))
	_game.events.flow_changed.emit("summary")
	var after_summary: Dictionary = combat.weapon_driver.state_snapshot()
	_t.check("WC-1: summary transition (Victory Lap close) returns Rivet to rest", _is_at_rest(after_summary, 6), str(after_summary))

	# 6c. Sable mid-charge -> run_ended(false) returns to rest; mid-charge -> flow_changed("title") returns to rest.
	combat.weapon_driver.reset(caster_pat)
	combat.weapon_driver.step(DT, _press_intent(true), Weapons.ARC_CASTER, caster_pat, caster_pat.rate, {"charge_rate": 1.0})
	for _i in 25:
		combat.weapon_driver.step(DT, _hold_intent(), Weapons.ARC_CASTER, caster_pat, caster_pat.rate, {"charge_rate": 1.0})
	_t.check("WC-1 setup: Sable charging before run_ended", bool(combat.weapon_driver.state_snapshot()["charging"]), "")
	_game.events.run_ended.emit(false)
	var after_end_sable: Dictionary = combat.weapon_driver.state_snapshot()
	_t.check("WC-1: run_ended returns charging Sable to rest", _is_at_rest(after_end_sable, 0), str(after_end_sable))

	combat.weapon_driver.step(DT, _press_intent(true), Weapons.ARC_CASTER, caster_pat, caster_pat.rate, {"charge_rate": 1.0})
	for _i in 25:
		combat.weapon_driver.step(DT, _hold_intent(), Weapons.ARC_CASTER, caster_pat, caster_pat.rate, {"charge_rate": 1.0})
	_game.events.flow_changed.emit("title")
	var after_title_sable: Dictionary = combat.weapon_driver.state_snapshot()
	_t.check("WC-1: title transition returns charging Sable to rest", _is_at_rest(after_title_sable, 0), str(after_title_sable))

	# 7. Live Kest cook-and-snap: tail drop, world fuse ring cue, snap burst (2x dmg, 1.35x radius,
	#    1.5x knock), rocket jump non-refresh, snap hold lock, Detonation Line snap, proc isolation,
	#    ultimate interrupt and WC-1 boundary reset.
	_game.flow._begin_run(ClassDef.by_id("demolitions_caster")) # Kest
	await physics_frame
	combat.set_physics_process(false)
	_game.player.set_physics_process(false)
	var kest_origin: Vector3 = _game.player.ball_position()

	# 7a. Short press & release (< 0.10 s) -> tail drop at player's tail, waiting amber fuse ring.
	combat._start_attempt()
	var kest_dummy: Node3D = combat.spawn_enemy("chaser", kest_origin + Vector3(0.0, 0.0, -3.4))
	kest_dummy.set_physics_process(false)
	kest_dummy.hp = 200.0
	kest_dummy.max_hp = 200.0
	_game.player.intent.clear()
	_game.player.intent.fire_pressed = true
	_game.player.intent.fire_held = true
	combat._physics_process(DT)
	_t.check("live Kest press opens lob gauge immediately",
		bool(combat.weapon_driver.state_snapshot()["lob_charging"]), str(combat.weapon_driver.state_snapshot()))
	_game.player.intent.clear()
	_game.player.intent.fire_released = true
	combat._physics_process(DT)
	_t.eq("live Kest short release drops 1 sticky charge", combat.sticky.live().size(), 1)
	var c0: Dictionary = combat.sticky.live()[0]
	_t.near("live Kest tail drop starts stuck (flight == 0)", float(c0["flight"]), 0.0, 0.001)
	_t.check("live Kest waiting fuse ring is amber",
		combat.sticky.fuse_ring_color(c0).is_equal_approx(Palette.AMBER), str(combat.sticky.fuse_ring_color(c0)))
	# Position dummy right at 3.6 m from charge: inside 4.05 m snapped radius, outside 3.0 m plain radius.
	var c0_pos: Vector3 = c0["pos"]
	kest_dummy.global_position = c0_pos + Vector3(3.6, 0.0, 0.0)

	# 7b. Advance into [0.30, 0.55] -> fuse ring turns mint; snap press bursts 22 dmg at 3.6 m (4.05 m radius),
	#     does NOT refresh _rocket_left, and holding snap never opens lob gauge.
	_game.player.intent.clear()
	for _i in 21: # 0.35 s
		combat._physics_process(DT)
	_t.check("live Kest snap window opens at 0.35 s and fuse ring turns mint",
		bool(combat.weapon_driver.state_snapshot()["window_open"])
		and combat.sticky.fuse_ring_color(c0).is_equal_approx(Palette.ARC),
		"open=%s col=%s" % [str(combat.weapon_driver.state_snapshot()["window_open"]), str(combat.sticky.fuse_ring_color(c0))])
	combat._rocket_left = 1.0 # simulate rocket cooldown mid-flight
	var hp_before_snap: float = kest_dummy.hp
	_game.player.intent.clear()
	_game.player.intent.fire_pressed = true
	_game.player.intent.fire_held = true
	combat._physics_process(DT)
	_t.eq("live Kest snap consumes the sticky charge", combat.sticky.live().size(), 0)
	_t.near("live Kest snap hits target at 3.6 m (4.05 m radius) for 22.0 damage", hp_before_snap - kest_dummy.hp, 22.0, 0.2)
	_t.check("live Kest snap does NOT refresh rocket cooldown", combat._rocket_left > 0.5, "%.3f" % combat._rocket_left)
	for _i in 45: # hold 0.75 s past 0.60 s floor
		_game.player.abilities.tick(DT)
		_game.player.intent.clear()
		_game.player.intent.fire_held = true
		combat._physics_process(DT)
	_t.check("live Kest holding snap press never opens lob gauge",
		not bool(combat.weapon_driver.state_snapshot()["lob_charging"]) and combat.sticky.live().is_empty(),
		str(combat.weapon_driver.state_snapshot()))
	_game.player.intent.clear()
	_game.player.intent.fire_released = true
	combat._physics_process(DT)

	# 7c. Detonation Line snaps an open-window charge and consumes the window.
	combat._start_attempt()
	_game.player.abilities.tick(1.0)
	var line_dummy: Node3D = combat.spawn_enemy("chaser", kest_origin + Vector3(0.0, 0.0, -2.5))
	line_dummy.set_physics_process(false)
	line_dummy.hp = 200.0
	line_dummy.max_hp = 200.0
	_game.player.intent.clear()
	_game.player.intent.fire_pressed = true
	_game.player.intent.fire_held = true
	combat._physics_process(DT)
	_game.player.intent.clear()
	_game.player.intent.fire_released = true
	combat._physics_process(DT)
	_t.eq("7c setup drops 1 charge for Detonation Line", combat.sticky.live().size(), 1)
	if not combat.sticky.live().is_empty():
		var lc: Dictionary = combat.sticky.live()[0]
		var lc_pos: Vector3 = lc["pos"]
		var line_from: Vector3 = _game.player.ball_position()
		var line_dir: Vector3 = (lc_pos - line_from)
		line_dir.y = 0.0
		line_dir = line_dir.normalized() if line_dir.length_squared() > 0.0001 else Vector3.FORWARD
		var line_perp := Vector3(-line_dir.z, 0.0, line_dir.x).normalized()
		line_dummy.global_position = lc_pos + line_perp * 3.5 # outside beam & 3.0 m plain blast, inside 4.05 m snapped blast
		_game.player.intent.clear()
		for _i in 21: # 0.35 s -> open window
			combat._physics_process(DT)
		var hp_before_line: float = line_dummy.hp
		var line_shape := {"from": line_from, "to": line_from + line_dir * 12.0, "width": Weapons.LINE_WIDTH}
		combat._fire_line(0.5, line_shape)
		_t.eq("Detonation Line consumes open-window charge and marks window HIT",
			[combat.sticky.live().size(), String(combat.weapon_driver.state_snapshot()["window"])],
			[0, WeaponDriver.WINDOW_HIT])
		_t.near("Detonation Line snap deals 22.0 damage at 3.5 m", hp_before_line - line_dummy.hp, 22.0, 0.2)

	# 7d. Kest proc detonation stays plain (11.0 dmg, 3.0 m) and never touches weapon_driver.
	var proc_before: Dictionary = combat.weapon_driver.state_snapshot()
	var proc_dummy: Node3D = combat.spawn_enemy("chaser", combat._floor_at(_game.player.ball_position()) + Vector3(1.5, 0.0, 0.0))
	proc_dummy.set_physics_process(false)
	proc_dummy.hp = 200.0
	proc_dummy.max_hp = 200.0
	combat._proc_detonate(1.0)
	_t.near("Kest proc detonation deals plain 11.0 damage", 200.0 - proc_dummy.hp, 11.0, 0.2)
	_t.eq("Kest proc detonation never mutates weapon_driver", combat.weapon_driver.state_snapshot(), proc_before)

	# 7e. Kest WC-1 boundary reset on run_ended.
	_game.player.intent.clear()
	_game.player.intent.fire_pressed = true
	_game.player.intent.fire_held = true
	combat._physics_process(DT)
	_game.events.run_ended.emit(false)
	var after_end_kest: Dictionary = combat.weapon_driver.state_snapshot()
	_t.check("WC-1: run_ended returns Kest to rest",
		_is_at_rest(after_end_kest, 0) and not bool(after_end_kest["lob_charging"]) and not bool(after_end_kest["snap_locked"]),
		str(after_end_kest))

	# 8. Live Tarn three-beat cadence: Beat 1 (18), Beat 2 (22), Beat 3 (43+speed, 2.0x knock),
	#    Clamp 1.5x across all three beats, proc isolation, and WC-1 boundary reset.
	_game.flow._begin_run(ClassDef.by_id("tarn")) # Tarn
	await physics_frame
	combat.set_physics_process(false)
	_game.player.set_physics_process(false)
	combat._start_attempt()
	var tarn_origin: Vector3 = _game.player.ball_position()
	var tarn_spot: Vector3 = tarn_origin + combat._flat_aim() * 3.0
	var tarn_dummy: Node3D = combat.spawn_enemy("chaser", tarn_spot)
	tarn_dummy.set_physics_process(false)
	tarn_dummy.hp = 500.0
	tarn_dummy.max_hp = 500.0
	_game.player.set_velocity_now(Vector3.ZERO)
	_game.player.intent.clear()
	_game.player.intent.fire_pressed = true
	_game.player.intent.fire_held = true
	combat._physics_process(DT)
	var d_b1: float = 500.0 - tarn_dummy.hp
	var knock_b1: float = tarn_dummy._knocked_speed()
	_t.near("live Tarn Beat 1 deals 18.0 damage", d_b1, 18.0, 0.2)
	_t.check("live Tarn Beat 1 applies positive knock speed", knock_b1 > 1.0, "%.2f" % knock_b1)
	_t.eq("live Tarn last_shot records beat 1", int(combat.last_shot.get("beat", 0)), 1)

	# Wait 0.467 s -> Beat 2
	tarn_dummy.velocity = Vector3.ZERO
	tarn_dummy.global_position = tarn_spot
	_game.player.intent.clear()
	for _i in 28:
		combat._physics_process(DT)
	var hp_pre_b2: float = tarn_dummy.hp
	_game.player.intent.fire_pressed = true
	combat._physics_process(DT)
	var d_b2: float = hp_pre_b2 - tarn_dummy.hp
	_t.near("live Tarn Beat 2 deals 22.0 damage", d_b2, 22.0, 0.2)
	_t.eq("live Tarn last_shot records beat 2", int(combat.last_shot.get("beat", 0)), 2)

	# Proc mid-combo (while Beat 3 window is open) fires plain Beat 1 (18.0) without mutating weapon_driver!
	tarn_dummy.velocity = Vector3.ZERO
	tarn_dummy.global_position = tarn_spot
	_game.player.intent.clear()
	for _i in 20: # 0.333 s -> Beat 3 window open
		combat._physics_process(DT)
	var pre_tarn_proc: Dictionary = combat.weapon_driver.state_snapshot()
	var hp_pre_proc: float = tarn_dummy.hp
	combat._fire(Weapons.CLAW_SWEEP, "item_proc")
	combat.bolts.step(DT, _game.get_world_3d().direct_space_state, [tarn_dummy]) # resolve proc bolt without ticking weapon_driver
	_t.near("live Tarn item_proc deals plain 18.0 damage", hp_pre_proc - tarn_dummy.hp, 18.0, 0.2)
	_t.eq("live Tarn item_proc leaves beat and open Beat 3 window untouched",
		combat.weapon_driver.state_snapshot(), pre_tarn_proc)

	# Beat 3 at standstill deals 43.0 damage and 2.0x knock impulse (enough to throw into a pin)!
	tarn_dummy.velocity = Vector3.ZERO
	tarn_dummy.global_position = tarn_spot
	var pin_victim: Node3D = combat.spawn_enemy("chaser", tarn_spot + combat._flat_aim() * 1.4)
	pin_victim.set_physics_process(false)
	pin_victim.hp = 200.0
	pin_victim.max_hp = 200.0
	var pins_before: int = combat.pins
	var hp_pre_b3: float = tarn_dummy.hp
	_game.player.intent.clear()
	_game.player.intent.fire_pressed = true
	combat._physics_process(DT)
	var d_b3: float = hp_pre_b3 - tarn_dummy.hp
	var knock_b3: float = tarn_dummy._knocked_speed()
	tarn_dummy._physics_process(DT)
	_game.player.intent.clear()
	combat._physics_process(DT) # allow _pin_step to resolve the Beat 3 knock throw into pin_victim
	_t.near("live Tarn Beat 3 at standstill deals 43.0 damage", d_b3, 43.0, 0.2)
	_t.near("live Tarn Beat 3 applies 2.0x knock impulse vs Beat 1", knock_b3, knock_b1 * 2.0, maxf(knock_b1 * 0.15, 0.5))
	_t.check("live Tarn Beat 3 2.0x knock exceeds pin threshold and pins neighbor",
		knock_b3 > Weapons.PIN_MIN_SPEED and combat.pins > pins_before,
		"knock_b3=%.2f pins=%d->%d" % [knock_b3, pins_before, combat.pins])
	_t.eq("live Tarn last_shot records beat 3 and 2.0x knock",
		[int(combat.last_shot.get("beat", 0)), is_equal_approx(float(combat.last_shot.get("knock_mult", 0.0)), 2.0)],
		[3, true])
	pin_victim.queue_free()

	# Clamp 1.5x applies cleanly across all three beats (27.0, 33.0, 64.5 at standstill).
	combat._start_attempt()
	var clamp_dummy: Node3D = combat.spawn_enemy("chaser", tarn_spot)
	clamp_dummy.set_physics_process(false)
	clamp_dummy.hp = 500.0
	clamp_dummy.max_hp = 500.0
	combat._clamped[clamp_dummy.get_instance_id()] = 10.0
	_game.player.set_velocity_now(Vector3.ZERO)
	_game.player.intent.clear()
	_game.player.intent.fire_pressed = true
	combat._physics_process(DT)
	var c_b1: float = 500.0 - clamp_dummy.hp
	clamp_dummy.velocity = Vector3.ZERO
	clamp_dummy.global_position = tarn_spot
	_game.player.intent.clear()
	for _i in 28:
		combat._physics_process(DT)
	var c_pre2: float = clamp_dummy.hp
	_game.player.intent.fire_pressed = true
	combat._physics_process(DT)
	var c_b2: float = c_pre2 - clamp_dummy.hp
	clamp_dummy.velocity = Vector3.ZERO
	clamp_dummy.global_position = tarn_spot
	_game.player.intent.clear()
	for _i in 20:
		combat._physics_process(DT)
	var c_pre3: float = clamp_dummy.hp
	_game.player.intent.fire_pressed = true
	combat._physics_process(DT)
	var c_b3: float = c_pre3 - clamp_dummy.hp
	_t.near("Clamp 1.5x multiplies Beat 1 (27.0)", c_b1, 27.0, 0.3)
	_t.near("Clamp 1.5x multiplies Beat 2 (33.0)", c_b2, 33.0, 0.3)
	_t.near("Clamp 1.5x multiplies Beat 3 standstill (64.5)", c_b3, 64.5, 0.4)

	# Tarn WC-1 boundary reset on run_ended.
	_game.events.run_ended.emit(true)
	var after_end_tarn: Dictionary = combat.weapon_driver.state_snapshot()
	_t.check("WC-1: run_ended returns Tarn to rest (beat 0)",
		_is_at_rest(after_end_tarn, 0) and int(after_end_tarn["beat"]) == 0, str(after_end_tarn))

	_game.free()
	quit(_t.verdict())


static func _is_at_rest(snap: Dictionary, expected_mag: int) -> bool:
	return is_zero_approx(float(snap["cooldown"])) \
		and is_zero_approx(float(snap["recover"])) \
		and not bool(snap["reloading"]) \
		and not bool(snap["charging"]) \
		and not bool(snap["charge_armed"]) \
		and is_zero_approx(float(snap["charge"])) \
		and not bool(snap["buffered"]) \
		and int(snap["hot"]) == 0 \
		and String(snap["window"]) == WeaponDriver.WINDOW_IDLE \
		and int(snap["chamber"]) == expected_mag \
		and bool(snap["ready"])


static func _find_buff(rows: Array, id: String) -> Dictionary:
	for r in rows:
		if String(r.get("id", "")) == id:
			return r
	return {}


static func _lawful_tone(tone: Color) -> bool:
	var forbidden := [Palette.ARC, Palette.HAZARD, Palette.BRASS, Palette.KINDNESS]
	for bad in forbidden:
		if tone.is_equal_approx(bad):
			return false
	var h_deg := tone.h * 360.0
	if tone.s > 0.2 and h_deg >= 300.0 and h_deg <= 330.0:
		return false
	return true
