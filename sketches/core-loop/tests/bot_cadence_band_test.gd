extends SceneTree

const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SkillBand := preload("res://tools/skill_band.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const T := preload("res://tests/support/t.gd")

# E1-08: SkillBand.window_share dial, band-driven Rivet/Sable cadence hands, and
# Expert-only F active hand (PILOT-CADENCE.md §§2, 3.1, 3.2, 8).

const DT := 1.0 / 90.0
const TRIALS := 2000

var _t := T.new("bot_cadence_band_test")
var _game


func _initialize() -> void:
	_check_window_share_dial()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run_live.call_deferred()


func _check_window_share_dial() -> void:
	var novice = SkillBand.make("novice", 1, 7)
	var expert = SkillBand.make("expert", 1, 7)
	_t.near("novice window_share is 0.15", novice.window_share, 0.15)
	_t.near("expert window_share is 0.85", expert.window_share, 0.85)
	_t.near("novice describe window_share", float(novice.describe().get("window_share", -1.0)), 0.15)
	_t.near("expert describe window_share", float(expert.describe().get("window_share", -1.0)), 0.85)

	var expected_learner := {1: 0.25, 2: 0.30, 3: 0.35, 4: 0.40, 5: 0.45, 9: 0.45}
	for attempt in expected_learner:
		var band = SkillBand.make("learner", attempt, 7)
		_t.near("learner attempt %d window_share" % attempt, band.window_share, expected_learner[attempt])
		_t.near("learner attempt %d describe window_share" % attempt,
			float(band.describe().get("window_share", -1.0)), expected_learner[attempt])

	var learner1 = SkillBand.make("learner", 1, 7)
	var learner5 = SkillBand.make("learner", 5, 7)
	_t.check("window_share strictly orders Novice < Learner a1 < Learner a5 < Expert",
		novice.window_share < learner1.window_share and learner1.window_share < learner5.window_share
		and learner5.window_share < expert.window_share)

	# Determinism and RNG isolation: hits_window must never mutate band._rng.state.
	var state_before: int = expert._rng.state
	var same := true
	var expert_copy = SkillBand.make("expert", 1, 7)
	for i in 500:
		var a: bool = expert.hits_window(i)
		var b: bool = expert_copy.hits_window(i)
		var c: bool = SkillBand.roll_window(7, i, 0.85)
		if a != b or a != c:
			same = false
	_t.check("hits_window is deterministic and equals SkillBand.roll_window", same)
	_t.eq("hits_window leaves band._rng.state untouched", expert._rng.state, state_before)

	# Realized hit rate over TRIALS matches each band's window_share within +-0.03.
	for entry in [
		["novice", 1, 0.15],
		["learner", 1, 0.25],
		["learner", 5, 0.45],
		["expert", 1, 0.85],
	]:
		var b = SkillBand.make(String(entry[0]), int(entry[1]), 42)
		var hits := 0
		for i in TRIALS:
			if b.hits_window(i):
				hits += 1
		var rate := float(hits) / float(TRIALS)
		var target := float(entry[2])
		_t.check("%s a%d realized window rate matches %.2f" % [entry[0], entry[1], target],
			absf(rate - target) <= 0.03, "rate %.3f vs %.3f" % [rate, target])

	_t.check("roll_window boundary 0.0 always misses", not SkillBand.roll_window(1, 0, 0.0))
	_t.check("roll_window boundary 1.0 always hits", SkillBand.roll_window(1, 0, 1.0))


func _run_live() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	for _i in 6:
		await physics_frame
	_game.player.set_physics_process(false)
	_game.combat.set_physics_process(false)
	_game.combat.ultimate.set_physics_process(false)

	_check_unbanded_equals_expert_rolls()
	_check_rivet_cadence_hand()
	_check_sable_cadence_hand(Weapons.ARC_CASTER)
	_check_sable_cadence_hand(Weapons.PYLON_TURRET)
	_check_kest_cadence_hand()
	_check_tarn_cadence_hand()
	_check_tally_cadence_hand()
	_check_cannon_cadence_hand()
	_check_no_phantom_windows()
	_check_active_hand()

	_game.free()
	_game = null
	quit(_t.verdict())


func _make_driver(band_name: String, attempt := 1, seed_val := 11, policy := "skipper"):
	var drv := BotDriver.new(_game, policy, seed_val)
	if band_name != "":
		drv.band = SkillBand.make(band_name, attempt, seed_val)
	return drv


func _check_unbanded_equals_expert_rolls() -> void:
	var plain = _make_driver("", 1, 19)
	var expert = _make_driver("expert", 1, 19)
	var match_all := true
	for _i in 500:
		if plain._roll_cadence_window() != expert._roll_cadence_window():
			match_all = false
			break
	_t.check("unbanded and expert drivers make identical cadence window rolls", match_all)


func _run_rivet_cycles(band_name: String, attempt: int, seed_val: int, ticks_to_run: int) -> Dictionary:
	var pat: Resource = Weapons.base(Weapons.RAPID_LASER)
	var wdrv = _game.combat.weapon_driver
	wdrv.reset(pat)
	var drv = _make_driver(band_name, attempt, seed_val)
	var intent := Intent.new()
	var hot_shots := 0
	var plain_shots := 0
	var plain_reloads := 0
	var hot_reloads := 0
	var was_reloading := false
	for _tick in ticks_to_run:
		drv.source.hold = {"fire_held": true}
		drv.source.press = {}
		drv._cadence_fire_hand()
		drv.source.poll(intent)
		var shots: Array = wdrv.step(DT, intent, Weapons.RAPID_LASER, pat, pat.rate)
		var snap: Dictionary = wdrv.state_snapshot()
		var now_reloading: bool = bool(snap["reloading"])
		if was_reloading and not now_reloading:
			if int(snap["hot"]) > 0:
				hot_reloads += 1
			else:
				plain_reloads += 1
		was_reloading = now_reloading
		for s in shots:
			if s["kind"] == WeaponDriver.SHOT_HOT:
				hot_shots += 1
			else:
				plain_shots += 1
	return {
		"windows": int(drv._totals["cadence_windows"]),
		"hits": int(drv._totals["cadence_hits"]),
		"hot_shots": hot_shots,
		"plain_shots": plain_shots,
		"hot_reloads": hot_reloads,
		"plain_reloads": plain_reloads,
	}


func _check_rivet_cadence_hand() -> void:
	# 9000 ticks = 100 s -> ~50-70 reload cycles per band.
	var nov := _run_rivet_cycles("novice", 1, 13, 9000)
	var lrn := _run_rivet_cycles("learner", 5, 13, 9000)
	var exp := _run_rivet_cycles("expert", 1, 13, 9000)
	var pln := _run_rivet_cycles("", 1, 13, 9000)
	_t.check("Rivet unbanded matches Expert cycle-for-cycle", pln == exp, "plain %s vs expert %s" % [pln, exp])
	_t.check("Rivet hit cycles load hot rounds and miss cycles finish plain reloads",
		nov["plain_reloads"] > 0 and exp["hot_reloads"] > 0 and exp["hot_shots"] > nov["hot_shots"]
		and nov["plain_shots"] > 0, "nov %s exp %s" % [nov, exp])
	_t.eq("Rivet every hit reload produces a hot reload", exp["hits"], exp["hot_reloads"])
	var r_nov := float(nov["hits"]) / maxf(float(nov["windows"]), 1.0)
	var r_lrn := float(lrn["hits"]) / maxf(float(lrn["windows"]), 1.0)
	var r_exp := float(exp["hits"]) / maxf(float(exp["windows"]), 1.0)
	_t.check("Rivet cadence hits order Novice < Learner a5 < Expert",
		nov["hits"] < lrn["hits"] and lrn["hits"] < exp["hits"]
		and r_nov < r_lrn and r_lrn < r_exp,
		"hits %d/%d (%.2f) < %d/%d (%.2f) < %d/%d (%.2f)" % [
			nov["hits"], nov["windows"], r_nov,
			lrn["hits"], lrn["windows"], r_lrn,
			exp["hits"], exp["windows"], r_exp])
	_t.check("Rivet hot shots order Novice < Learner a5 < Expert",
		nov["hot_shots"] < lrn["hot_shots"] and lrn["hot_shots"] < exp["hot_shots"],
		"hot_shots %d < %d < %d" % [nov["hot_shots"], lrn["hot_shots"], exp["hot_shots"]])


func _run_sable_cycles(wid: String, band_name: String, attempt: int, seed_val: int, ticks_to_run: int) -> Dictionary:
	var pat: Resource = Weapons.base(wid)
	var wdrv = _game.combat.weapon_driver
	wdrv.reset(pat)
	var drv = _make_driver(band_name, attempt, seed_val)
	var intent := Intent.new()
	var sparks := 0
	var charged := 0
	for _tick in ticks_to_run:
		drv.source.hold = {"fire_held": true}
		drv.source.press = {}
		drv._cadence_fire_hand()
		drv.source.poll(intent)
		var shots: Array = wdrv.step(DT, intent, wid, pat, pat.rate)
		for s in shots:
			if s["kind"] == WeaponDriver.SHOT_CHARGED:
				charged += 1
			elif s["kind"] == WeaponDriver.SHOT_SPARK:
				sparks += 1
	return {
		"windows": int(drv._totals["cadence_windows"]),
		"hits": int(drv._totals["cadence_hits"]),
		"sparks": sparks,
		"charged": charged,
	}


func _check_sable_cadence_hand(wid: String) -> void:
	# 9000 ticks = 100 s -> ~100-250 shot cycles per band.
	var nov := _run_sable_cycles(wid, "novice", 1, 17, 9000)
	var lrn := _run_sable_cycles(wid, "learner", 5, 17, 9000)
	var exp := _run_sable_cycles(wid, "expert", 1, 17, 9000)
	var pln := _run_sable_cycles(wid, "", 1, 17, 9000)
	_t.check("Sable %s unbanded matches Expert cycle-for-cycle" % wid, pln == exp, "plain %s vs expert %s" % [pln, exp])
	_t.check("Sable %s hit cycles fire full charged bolts and miss cycles tap sparks only" % wid,
		nov["sparks"] > nov["charged"] and exp["charged"] > nov["charged"] and exp["hits"] == exp["charged"],
		"nov %s exp %s" % [nov, exp])
	var r_nov := float(nov["hits"]) / maxf(float(nov["windows"]), 1.0)
	var r_lrn := float(lrn["hits"]) / maxf(float(lrn["windows"]), 1.0)
	var r_exp := float(exp["hits"]) / maxf(float(exp["windows"]), 1.0)
	_t.check("Sable %s cadence hits and share order Novice < Learner a5 < Expert" % wid,
		nov["hits"] < lrn["hits"] and lrn["hits"] < exp["hits"]
		and r_nov < r_lrn and r_lrn < r_exp,
		"hits %d/%d (%.2f) < %d/%d (%.2f) < %d/%d (%.2f)" % [
			nov["hits"], nov["windows"], r_nov,
			lrn["hits"], lrn["windows"], r_lrn,
			exp["hits"], exp["windows"], r_exp])


func _run_kest_cycles(band_name: String, attempt: int, seed_val: int, ticks_to_run: int) -> Dictionary:
	var pat: Resource = Weapons.base(Weapons.STICKY_CHARGE)
	var wdrv = _game.combat.weapon_driver
	wdrv.reset(pat)
	var drv = _make_driver(band_name, attempt, seed_val)
	var intent := Intent.new()
	var throws := 0
	var snaps := 0
	for _tick in ticks_to_run:
		var pre: Dictionary = wdrv.state_snapshot()
		# Mimic _throw_hold releasing immediately when lob_charging is active (tail drop).
		drv.source.hold = {} if bool(pre.get("lob_charging", false)) else {"fire_held": true}
		drv.source.press = {}
		drv._cadence_fire_hand()
		drv.source.poll(intent)
		var shots: Array = wdrv.step(DT, intent, Weapons.STICKY_CHARGE, pat, pat.rate)
		for s in shots:
			if String(s["kind"]) == WeaponDriver.SHOT_THROW:
				throws += 1
			elif String(s["kind"]) == WeaponDriver.SHOT_SNAP:
				snaps += 1
	return {
		"windows": int(drv._totals["cadence_windows"]),
		"hits": int(drv._totals["cadence_hits"]),
		"throws": throws,
		"snaps": snaps,
	}


func _check_kest_cadence_hand() -> void:
	# 9000 ticks = 100 s -> ~150 throw windows per band.
	var nov := _run_kest_cycles("novice", 1, 29, 9000)
	var lrn := _run_kest_cycles("learner", 5, 29, 9000)
	var exp := _run_kest_cycles("expert", 1, 29, 9000)
	var pln := _run_kest_cycles("", 1, 29, 9000)
	_t.check("Kest unbanded matches Expert cycle-for-cycle", pln == exp, "plain %s vs expert %s" % [pln, exp])
	_t.check("Kest hit cycles snap charges and miss cycles leave plain throws",
		nov["throws"] > 50 and exp["snaps"] > nov["snaps"] and exp["hits"] == exp["snaps"],
		"nov %s exp %s" % [nov, exp])
	var r_nov := float(nov["hits"]) / maxf(float(nov["windows"]), 1.0)
	var r_lrn := float(lrn["hits"]) / maxf(float(lrn["windows"]), 1.0)
	var r_exp := float(exp["hits"]) / maxf(float(exp["windows"]), 1.0)
	_t.check("Kest cadence hits and share order Novice < Learner a5 < Expert",
		nov["hits"] < lrn["hits"] and lrn["hits"] < exp["hits"]
		and r_nov < r_lrn and r_lrn < r_exp,
		"hits %d/%d (%.2f) < %d/%d (%.2f) < %d/%d (%.2f)" % [
			nov["hits"], nov["windows"], r_nov,
			lrn["hits"], lrn["windows"], r_lrn,
			exp["hits"], exp["windows"], r_exp])


func _run_tarn_cycles(band_name: String, attempt: int, seed_val: int, ticks_to_run: int) -> Dictionary:
	var pat: Resource = Weapons.base(Weapons.CLAW_SWEEP)
	var wdrv = _game.combat.weapon_driver
	wdrv.reset(pat)
	var drv = _make_driver(band_name, attempt, seed_val)
	var intent := Intent.new()
	var beat1 := 0
	var beat2 := 0
	var beat3 := 0
	for _tick in ticks_to_run:
		drv.source.hold = {"fire_held": true}
		drv.source.press = {}
		drv._cadence_fire_hand()
		drv.source.poll(intent)
		var shots: Array = wdrv.step(DT, intent, Weapons.CLAW_SWEEP, pat, pat.rate, {"planar_speed": 14.0})
		for s in shots:
			match int(s.get("beat", 0)):
				1:
					beat1 += 1
				2:
					beat2 += 1
				3:
					beat3 += 1
	return {
		"windows": int(drv._totals["cadence_windows"]),
		"hits": int(drv._totals["cadence_hits"]),
		"beat1": beat1,
		"beat2": beat2,
		"beat3": beat3,
	}


func _check_tarn_cadence_hand() -> void:
	# 9000 ticks = 100 s -> ~75-95 three-beat cycles per band.
	var nov := _run_tarn_cycles("novice", 1, 31, 9000)
	var lrn := _run_tarn_cycles("learner", 5, 31, 9000)
	var exp := _run_tarn_cycles("expert", 1, 31, 9000)
	var pln := _run_tarn_cycles("", 1, 31, 9000)
	_t.check("Tarn unbanded matches Expert cycle-for-cycle", pln == exp, "plain %s vs expert %s" % [pln, exp])
	_t.check("Tarn hit cycles land Beat 3 and miss cycles return to Beat 1",
		nov["beat1"] > 50 and nov["beat2"] > 50 and exp["beat3"] > nov["beat3"] and exp["hits"] == exp["beat3"],
		"nov %s exp %s" % [nov, exp])
	var r_nov := float(nov["hits"]) / maxf(float(nov["windows"]), 1.0)
	var r_lrn := float(lrn["hits"]) / maxf(float(lrn["windows"]), 1.0)
	var r_exp := float(exp["hits"]) / maxf(float(exp["windows"]), 1.0)
	_t.check("Tarn cadence hits and share order Novice < Learner a5 < Expert",
		nov["hits"] < lrn["hits"] and lrn["hits"] < exp["hits"]
		and r_nov < r_lrn and r_lrn < r_exp,
		"hits %d/%d (%.2f) < %d/%d (%.2f) < %d/%d (%.2f)" % [
			nov["hits"], nov["windows"], r_nov,
			lrn["hits"], lrn["windows"], r_lrn,
			exp["hits"], exp["windows"], r_exp])


func _run_tally_cycles(band_name: String, attempt: int, seed_val: int, ticks_to_run: int) -> Dictionary:
	var pat: Resource = Weapons.base(Weapons.LEDGER_READER)
	var wdrv = _game.combat.weapon_driver
	wdrv.reset(pat)
	var drv = _make_driver(band_name, attempt, seed_val)
	var intent := Intent.new()
	var plain := 0
	var paid := 0
	for _tick in ticks_to_run:
		drv.source.hold = {"fire_held": true}
		drv.source.press = {}
		drv._cadence_fire_hand()
		drv.source.poll(intent)
		var shots: Array = wdrv.step(DT, intent, Weapons.LEDGER_READER, pat, 0.0)
		for s in shots:
			if bool(s.get("paid", false)):
				paid += 1
			else:
				plain += 1
	return {
		"windows": int(drv._totals["cadence_windows"]),
		"hits": int(drv._totals["cadence_hits"]),
		"plain": plain,
		"paid": paid,
	}


func _check_tally_cadence_hand() -> void:
	# 9000 ticks = 100 s -> ~240 stamp windows per band.
	var nov := _run_tally_cycles("novice", 1, 37, 9000)
	var lrn := _run_tally_cycles("learner", 5, 37, 9000)
	var exp := _run_tally_cycles("expert", 1, 37, 9000)
	var pln := _run_tally_cycles("", 1, 37, 9000)
	_t.check("Tally unbanded matches Expert cycle-for-cycle", pln == exp, "plain %s vs expert %s" % [pln, exp])
	_t.check("Tally hit cycles stamp PAID and miss cycles cast plain",
		nov["plain"] > 50 and exp["paid"] > nov["paid"] and exp["hits"] == exp["paid"],
		"nov %s exp %s" % [nov, exp])
	var r_nov := float(nov["hits"]) / maxf(float(nov["windows"]), 1.0)
	var r_lrn := float(lrn["hits"]) / maxf(float(lrn["windows"]), 1.0)
	var r_exp := float(exp["hits"]) / maxf(float(exp["windows"]), 1.0)
	_t.check("Tally cadence hits and share order Novice < Learner a5 < Expert",
		nov["hits"] < lrn["hits"] and lrn["hits"] < exp["hits"]
		and r_nov < r_lrn and r_lrn < r_exp,
		"hits %d/%d (%.2f) < %d/%d (%.2f) < %d/%d (%.2f)" % [
			nov["hits"], nov["windows"], r_nov,
			lrn["hits"], lrn["windows"], r_lrn,
			exp["hits"], exp["windows"], r_exp])


func _run_cannon_cycles(band_name: String, attempt: int, seed_val: int, ticks_to_run: int) -> Dictionary:
	var pat: Resource = Weapons.base(Weapons.CANNON_LANE)
	var wdrv = _game.combat.weapon_driver
	wdrv.reset(pat)
	var drv = _make_driver(band_name, attempt, seed_val)
	var intent := Intent.new()
	var pulses := 0
	var rails := 0
	var barrages := 0
	for _tick in ticks_to_run:
		drv.source.hold = {"fire_held": true}
		drv.source.press = {}
		drv._cadence_fire_hand()
		drv.source.poll(intent)
		var shots: Array = wdrv.step(DT, intent, Weapons.CANNON_LANE, pat, pat.rate)
		for s in shots:
			match String(s.get("kind", "")):
				WeaponDriver.SHOT_PULSE:
					pulses += 1
				WeaponDriver.SHOT_RAIL:
					rails += 1
				WeaponDriver.SHOT_BARRAGE:
					barrages += 1
	return {
		"windows": int(drv._totals["cadence_windows"]),
		"hits": int(drv._totals["cadence_hits"]),
		"pulses": pulses,
		"rails": rails,
		"barrages": barrages,
	}


func _check_cannon_cadence_hand() -> void:
	# 9000 ticks = 100 s -> ~90-100 lock cycles per band.
	var nov := _run_cannon_cycles("novice", 1, 41, 9000)
	var lrn := _run_cannon_cycles("learner", 5, 41, 9000)
	var exp := _run_cannon_cycles("expert", 1, 41, 9000)
	var pln := _run_cannon_cycles("", 1, 41, 9000)
	_t.check("Cannon unbanded matches Expert cycle-for-cycle", pln == exp, "plain %s vs expert %s" % [pln, exp])
	_t.check("Cannon hit cycles fire Rail and miss cycles fire both Pulse and Barrage",
		nov["pulses"] > 10 and nov["barrages"] > 10 and exp["rails"] > nov["rails"] and exp["hits"] == exp["rails"],
		"nov %s exp %s" % [nov, exp])
	var r_nov := float(nov["hits"]) / maxf(float(nov["windows"]), 1.0)
	var r_lrn := float(lrn["hits"]) / maxf(float(lrn["windows"]), 1.0)
	var r_exp := float(exp["hits"]) / maxf(float(exp["windows"]), 1.0)
	_t.check("Cannon cadence hits and share order Novice < Learner a5 < Expert",
		nov["hits"] < lrn["hits"] and lrn["hits"] < exp["hits"]
		and r_nov < r_lrn and r_lrn < r_exp,
		"hits %d/%d (%.2f) < %d/%d (%.2f) < %d/%d (%.2f)" % [
			nov["hits"], nov["windows"], r_nov,
			lrn["hits"], lrn["windows"], r_lrn,
			exp["hits"], exp["windows"], r_exp])


func _check_no_phantom_windows() -> void:
	var pat: Resource = Weapons.base(Weapons.ARC_CASTER)
	_game.combat.weapon_driver.reset(pat)
	var drv = _make_driver("expert", 1, 23)
	drv._sheet_hold_fire = true
	for _i in 30:
		drv.source.hold = {"fire_held": true}
		drv.source.press = {}
		drv._cadence_fire_hand()
	drv._sheet_hold_fire = false
	_t.eq("Dam sheet hold-fire rolls zero phantom cadence windows", int(drv._totals["cadence_windows"]), 0)
	var abilities = _game.player.abilities
	abilities.select(abilities.SPECIAL)
	for _i in 30:
		drv.source.hold = {"fire_held": true}
		drv.source.press = {}
		drv._cadence_fire_hand()
	abilities.snap_back("test")
	_t.eq("non-weapon slot selection rolls zero phantom cadence windows", int(drv._totals["cadence_windows"]), 0)


func _check_active_hand() -> void:
	var rack = _game.combat.actives
	rack.reset()
	_game.ctx.tuning.set_option("actives", "on")
	rack.rack(ActiveDefs.SCRAP_ROCKET, true)

	# Clear stage enemies so proximity is controlled exclusively by our staged enemy.
	for node in get_nodes_in_group("enemy"):
		node.remove_from_group("enemy")
	var ball: Vector3 = _game.player.ball_position()
	var foe: Node3D = _game.combat.spawn_enemy("chaser", ball + Vector3(12.0, 0.0, 0.0))
	foe.live = func() -> bool: return false
	foe.hp = 5000.0
	foe.max_hp = 5000.0

	# 1. Novice and Learner never press F.
	for entry in [["novice", 1], ["learner", 5]]:
		var drv = _make_driver(String(entry[0]), int(entry[1]), 5)
		drv.source.press = {}
		drv._active_hands(foe)
		_t.check("%s never sends active_pressed" % entry[0],
			not drv.source.press.has("active_pressed") and int(drv._totals["active_presses"]) == 0,
			"press %s totals %s" % [drv.source.press, drv._totals])

	# 2. Expert sends active_pressed and fires the racked active through active_rack.
	var exp = _make_driver("expert", 1, 5)
	exp.source.press = {}
	exp._active_hands(foe)
	_t.check("expert sends active_pressed when target is in range",
		bool(exp.source.press.get("active_pressed", false)) and int(exp._totals["active_presses"]) == 1)
	var fires_before: int = rack.fires
	var charges_before: int = rack.charges
	exp.source.poll(_game.player.intent)
	_t.check("polled intent carries active_pressed", _game.player.intent.active_pressed)
	rack.press()
	_t.check("active_rack consumes charge and fires",
		rack.fires == fires_before + 1 and rack.charges == charges_before - 1,
		"fires %d->%d charges %d->%d" % [fires_before, rack.fires, charges_before, rack.charges])

	# 3. Retry cooldown prevents back-to-back spam on the next tick.
	exp.source.press = {}
	exp._active_hands(foe)
	_t.check("active_wait prevents immediate repeat press", not exp.source.press.has("active_pressed"))

	# 4. Unbanded driver also fires F identically to Expert.
	rack.rack(ActiveDefs.SCRAP_ROCKET, true)
	var plain = _make_driver("", 1, 5)
	plain.source.press = {}
	plain._active_hands(foe)
	_t.check("unbanded driver sends active_pressed like Expert",
		bool(plain.source.press.get("active_pressed", false)) and int(plain._totals["active_presses"]) == 1)

	# 5. Guards: out of range, locked, zero charges, traversal, cast in flight, chain driving.
	foe.global_position = ball + Vector3(BotDriver.ACTIVE_RANGE + 20.0, 0.0, 0.0)
	var guarded = _make_driver("expert", 1, 5)
	guarded._active_hands(null)
	_t.check("active hand waits when no enemy is within ACTIVE_RANGE", not guarded.source.press.has("active_pressed"))

	foe.global_position = ball + Vector3(10.0, 0.0, 0.0)
	rack.lock(2.0)
	guarded._active_hands(foe)
	_t.check("active hand waits while rack is locked", not guarded.source.press.has("active_pressed"))
	rack.reset()
	rack.rack(ActiveDefs.SCRAP_ROCKET, false)
	guarded._active_hands(foe)
	_t.check("active hand waits with zero charges", not guarded.source.press.has("active_pressed"))

	rack.rack(ActiveDefs.SCRAP_ROCKET, true)
	var trav = _make_driver("expert", 1, 5, "traversal")
	trav._active_hands(foe)
	_t.check("traversal policy never presses F", not trav.source.press.has("active_pressed"))

	guarded._cast_phase = "click"
	guarded._active_hands(foe)
	_t.check("active hand skips during cast_phase", not guarded.source.press.has("active_pressed"))
	guarded._cast_phase = ""
	guarded._chain_driving = true
	guarded._active_hands(foe)
	_t.check("active hand skips during chain_driving", not guarded.source.press.has("active_pressed"))

	foe.free()
	rack.reset()
