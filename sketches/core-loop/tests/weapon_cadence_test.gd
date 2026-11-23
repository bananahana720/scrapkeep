extends SceneTree

const BuffLedger := preload("res://src/core/buff_ledger.gd")
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


func _check_warden_reactor_base_dps() -> void:
	_t.near("WardenReactor.base_dps routes Rivet through careless WeaponDriver.base_dps",
		WardenReactor.base_dps(Weapons.RAPID_LASER), 72.0 / 1.95, 0.01)
	_t.near("WardenReactor.base_dps routes Sable through careless WeaponDriver.base_dps",
		WardenReactor.base_dps(Weapons.ARC_CASTER), 8.0 / 0.30, 0.01)
	_t.near("WardenReactor.base_dps routes Pylon Turret through careless WeaponDriver.base_dps",
		WardenReactor.base_dps(Weapons.PYLON_TURRET), 9.0 / 0.30, 0.01)


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

	_game.free()
	quit(_t.verdict())


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
