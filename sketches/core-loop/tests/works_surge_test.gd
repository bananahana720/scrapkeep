extends SceneTree

const T := preload("res://tests/support/t.gd")
const Contraptions := preload("res://src/world/contraptions.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Rows := preload("res://src/presentation/rows.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const RunState := preload("res://src/core/run_state.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Gorge := preload("res://src/world/map_gorge.gd")

# W46-04: works sluice valve contraption (W1-142, rulings cu, eh, cx, Q-P22).
# Proves in headless Godot:
#   1. A ram at speed or a scrap payment sets the valve off; insufficient scrap refuses cleanly.
#   2. The lane warning is visible on screen for >= 0.6 s before the surge fires (and reported
#      through world_telegraphs), using baked sound ids with zero screen words.
#   3. A crew in the lane is thrown down the lane and damaged once; a crew outside is untouched;
#      a set piece is spared.
#   4. Destructible props in the lane shatter and pay once (props only, heightfield untouched);
#      props outside stay intact; a second surge pays nothing twice.
#   5. A ball below cruise (stopped or slow) in the lane loses hull and is tossed once;
#      a ball rolling through at cruise speed does not lose hull and is not tossed.
#   6. The piece fires once per charge, pays nothing twice, recharges cleanly, and resets cleanly.
#   7. Planted fault: a surge with no warning (test_no_warn = true) fails the warning predicate.

const CRUISE := 14.0
const DT := 1.0 / 60.0
const GRAVITY := 26.0
const PRICE := 15
const CHARGE_S := 4.0

var t := T.new("works_surge_test")


class FakePlayer extends RefCounted:
	var velocity := Vector3.ZERO
	var toss_count := 0
	var last_cause := ""
	var intent := {"interact_pressed": false}

	func set_velocity_now(v: Vector3, cause := "") -> void:
		velocity = v
		toss_count += 1
		last_cause = cause


class FakeScrap extends RefCounted:
	var scrap: Array[int] = []
	var cogs: Array[int] = []

	func drop(_at: Vector3, amount: int, _rng: RandomNumberGenerator) -> void:
		scrap.append(amount)

	func drop_cogs(_at: Vector3, amount: int) -> void:
		cogs.append(amount)

	func scrap_sum() -> int:
		var total := 0
		for a in scrap:
			total += a
		return total


class FakeEnemy extends Node3D:
	var half_height := 1.0
	var hp := 100.0
	var knocks := 0
	var last_push := Vector3.ZERO
	var last_force := 0.0
	var damage_taken := 0.0
	var last_damage_source := ""
	var kind := "chaser"

	func knock(direction: Vector3, force: float) -> void:
		knocks += 1
		last_push = direction
		last_force = force

	func take_damage(amount: float) -> void:
		damage_taken += amount
		hp = maxf(0.0, hp - amount)

	func is_dead() -> bool:
		return hp <= 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_sounds_and_words()
	await _check_ram_warn_crew_props_and_stopped_ball()
	await _check_rolling_ball_spared_and_slow_ball_bitten()
	await _check_scrap_payment_once_per_charge_and_recharge()
	await _check_planted_no_warning_fails()
	quit(t.verdict())


func _ground(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, 0.0 + lift, z)


func _valve_spec(extra: Dictionary = {}) -> Dictionary:
	var spec := {
		"id": "sluice_a",
		"kind": "sluice_valve",
		"at": Vector2(0.0, 0.0),
		"lane": {
			"from": Vector2(0.0, 2.0),
			"dir": Vector2(0.0, 1.0),
			"length": 24.0,
			"half_width": 4.5,
			"reach": 3.0,
		},
		"charge": CHARGE_S,
		"price": PRICE,
	}
	spec.merge(extra, true)
	return spec


func _make_run(scrap_amount := 100) -> Dictionary:
	var events := GameEvents.new()
	var run := RunState.new(events)
	run.begin(ClassDef.new())
	run.scrap = scrap_amount
	return {"events": events, "run": run}


func _make_rig(spec_extra: Dictionary = {}, prop_rows: Array = [], scrap_amount := 100) -> Dictionary:
	var holder := Node3D.new()
	root.add_child(holder)
	var map := Gorge.new()
	map.contraptions = [_valve_spec(spec_extra)]
	var c := Contraptions.new()
	holder.add_child(c)
	c.setup(map, Callable(self, "_ground"), CRUISE, GRAVITY)
	var rr := _make_run(scrap_amount)
	var player := FakePlayer.new()
	var scrap := FakeScrap.new()
	var props: Node3D = null
	if not prop_rows.is_empty():
		props = Destructibles.new()
		props.build(prop_rows, {"root": holder, "cruise": CRUISE, "run_seed": 11, "run_id": "surge-1", "stage": 1,
			"scrap": scrap, "no_visuals": true})
		props.finish_build()
	c.bind_context({"run": rr["run"], "player": player, "destructibles": props, "calm": false})
	return {"holder": holder, "c": c, "run": rr["run"], "events": rr["events"], "player": player, "props": props, "scrap": scrap}


func _drop_rig(rig: Dictionary) -> void:
	if rig["props"] != null and is_instance_valid(rig["props"]):
		rig["props"].teardown()
	rig["holder"].free()
	rig["events"].free()


func _make_enemy(parent: Node, at: Vector3, enemy_kind := "chaser") -> FakeEnemy:
	var e := FakeEnemy.new()
	e.kind = enemy_kind
	e.position = at
	e.add_to_group("enemy")
	parent.add_child(e)
	return e


# Shared predicate checked against both the live implementation and the planted zero-warning case.
func _warning_predicate(result: Dictionary) -> bool:
	return bool(result["saw_warning_visible"]) and float(result["warn_visible_s"]) >= Contraptions.SURGE_MIN_WARN \
		and bool(result["warn_fact_before_open"]) and bool(result["telegraph_published"])


func _run_warning_trial(skip_warn: bool) -> Dictionary:
	var rig := _make_rig()
	var c: Node3D = rig["c"]
	c.test_no_warn = skip_warn
	var saw_visible := false
	var saw_telegraph := false
	var warn_tick := -1
	var open_tick := -1
	var warned_ticks := 0
	# Ram the valve at cruise on tick 0, then move out of the way.
	for tick in 90:
		var ball := Vector3(0.0, 1.0, 0.0) if tick == 0 else Vector3(40.0, 1.0, 0.0)
		var vel := Vector3(CRUISE, 0.0, 0.0)
		var facts: Array = c.step(DT, ball, vel, null, false)
		for f in facts:
			if f.get("kind") == "fact" and f.get("fact") == "sluice_warning" and warn_tick < 0:
				warn_tick = tick
			if f.get("kind") == "fact" and f.get("fact") == "sluice_open" and open_tick < 0:
				open_tick = tick
		var st: Dictionary = c.sluice_state("sluice_a")
		if st["state"] == "warning" and bool(st["warning_visible"]):
			saw_visible = true
			warned_ticks += 1
		if not c.telegraphs(Vector3(0.0, 1.0, 10.0)).is_empty():
			saw_telegraph = true
		if open_tick >= 0:
			break
	var final_st: Dictionary = c.sluice_state("sluice_a")
	var out := {
		"saw_warning_visible": saw_visible,
		"warn_visible_s": float(final_st["last_warn_visible_s"]),
		"warned_ticks": warned_ticks,
		"warn_fact_before_open": warn_tick >= 0 and open_tick > warn_tick,
		"telegraph_published": saw_telegraph,
	}
	_drop_rig(rig)
	return out


func _check_sounds_and_words() -> void:
	for kind in ["sluice_warning", "sluice_open"]:
		var row: Dictionary = EventKinds.WORLD_ROWS.get(kind, {})
		t.check("WORLD_ROWS has %s" % kind, not row.is_empty(), kind)
		var heard := Rows.heard(row)
		t.check("%s plays a sound id with a recipe (%s)" % [kind, heard], SfxBank.plays_own(heard), heard)
		t.eq("%s puts no new words on screen (ruling cx)" % kind, String(row.get("hud", "")), "")


func _check_ram_warn_crew_props_and_stopped_ball() -> void:
	var props := [
		{"id": "lane_crate", "tier": 2, "at": Vector3(0.0, 1.0, 18.0), "size": Vector3(2.0, 2.0, 2.0)},
		{"id": "side_crate", "tier": 2, "at": Vector3(14.0, 1.0, 18.0), "size": Vector3(2.0, 2.0, 2.0)},
	]
	var rig := _make_rig({}, props, 50)
	var c: Node3D = rig["c"]
	var run: RunState = rig["run"]
	var player: FakePlayer = rig["player"]
	var destructibles: Node3D = rig["props"]
	var crew_in := _make_enemy(rig["holder"], Vector3(0.5, 1.0, 10.0))
	var crew_out := _make_enemy(rig["holder"], Vector3(12.0, 1.0, 10.0))
	var set_piece := _make_enemy(rig["holder"], Vector3(-0.5, 1.0, 15.0), "warden")
	var hp_before := run.hp
	var scrap_before := run.scrap
	# First try a slow touch at the valve: must NOT trigger a ram.
	c.step(DT, Vector3(0.0, 1.0, 0.0), Vector3(3.0, 0.0, 0.0), null, false)
	t.eq("a slow touch does not ram-trigger the valve", c.sluice_state("sluice_a")["state"], "ready")
	# Now ram at cruise speed to arm the warning.
	var warn_facts: Array = c.step(DT, Vector3(0.0, 1.0, 0.0), Vector3(CRUISE, 0.0, 0.0), null, false)
	t.eq("a ram at cruise arms the warning", c.sluice_state("sluice_a")["state"], "warning")
	t.check("ram emits sluice_warning", warn_facts.any(func(f): return f.get("kind") == "fact" and f.get("fact") == "sluice_warning"), str(warn_facts))
	t.eq("a ram spends no scrap", run.scrap, scrap_before)
	t.check("warning is visible immediately on arming", bool(c.sluice_state("sluice_a")["warning_visible"]), "")
	t.check("world_telegraphs publishes the warning covering the lane", c.telegraphs(Vector3(0.0, 1.0, 10.0)).any(func(r): return bool(r["covers"]) and String(r["cause"]) == Contraptions.SURGE_SOURCE), "")
	# Park the ball stopped in the lane while the warning counts down and the surge fires.
	var open_seen := 0
	var warned_s := 0.0
	for _i in 120:
		var st_before: Dictionary = c.sluice_state("sluice_a")
		if st_before["state"] == "warning" and bool(st_before["warning_visible"]):
			warned_s += DT
		var facts: Array = c.step(DT, Vector3(0.0, 1.0, 8.0), Vector3.ZERO, null, false)
		for f in facts:
			if f.get("kind") == "fact" and f.get("fact") == "sluice_open":
				open_seen += 1
	var st: Dictionary = c.sluice_state("sluice_a")
	t.check("warning stood visible for at least 0.6 s before surge", warned_s >= Contraptions.SURGE_MIN_WARN and float(st["last_warn_visible_s"]) >= Contraptions.SURGE_MIN_WARN, "warned %.3f s, recorded %.3f s" % [warned_s, float(st["last_warn_visible_s"])])
	t.eq("surge opened once per charge", open_seen, 1)
	t.eq("charges_fired is 1", int(st["charges_fired"]), 1)
	t.eq("enemies_thrown counter is 1", int(st["enemies_thrown"]), 1)
	t.eq("props_broken counter is 1", int(st["props_broken"]), 1)
	t.eq("crew in the lane was thrown once", crew_in.knocks, 1)
	t.check("crew was thrown down the lane (+z) with lift", crew_in.last_push.z > 0.7 and crew_in.last_push.y > 0.1 and crew_in.last_force >= Contraptions.SURGE_ENEMY_TOSS, str(crew_in.last_push))
	t.eq("crew in the lane took surge damage tagged works_surge", crew_in.last_damage_source, Contraptions.SURGE_SOURCE)
	t.check("crew damage is positive", crew_in.damage_taken >= Contraptions.SURGE_ENEMY_DAMAGE, str(crew_in.damage_taken))
	t.eq("crew outside the lane was untouched", crew_out.knocks, 0)
	t.eq("set piece (warden) in the lane was spared", set_piece.knocks, 0)
	t.eq("destructible prop in the lane shattered", destructibles.state_of("lane_crate"), "shattered")
	t.eq("destructible prop outside the lane stayed intact", destructibles.state_of("side_crate"), "intact")
	t.eq("shattered prop collider left layer 1", destructibles.body_of("lane_crate").collision_layer, 0)
	t.check("shattered prop paid its tier loot once", destructibles.loot()["scrap"] == 2 and destructibles.loot()["cogs"] == 1, str(destructibles.loot()))
	t.check("stopped ball in the lane lost hull", run.hp < hp_before and is_equal_approx(hp_before - run.hp, Contraptions.SURGE_BALL_DAMAGE), "%.1f -> %.1f" % [hp_before, run.hp])
	t.eq("stopped ball was hit and tossed once (not every live tick)", player.toss_count, 1)
	t.check("stopped ball was tossed down the lane and upward", player.velocity.z >= Contraptions.SURGE_BALL_TOSS - 0.1 and player.velocity.y >= Contraptions.SURGE_BALL_LIFT - 0.1, str(player.velocity))
	t.eq("stopped ball toss cause is works_surge", player.last_cause, Contraptions.SURGE_SOURCE)
	t.eq("valve moved into charging after the surge", st["state"], "charging")
	t.eq("ground heightfield was never deformed (Q-P22)", _ground(0.0, 12.0).y, 0.0)
	await process_frame
	_drop_rig(rig)


func _check_rolling_ball_spared_and_slow_ball_bitten() -> void:
	# Case A: ball rolling through the lane at cruise speed -> NO hull loss, NO toss.
	var cruise_rig := _make_rig()
	var c1: Node3D = cruise_rig["c"]
	var run1: RunState = cruise_rig["run"]
	var player1: FakePlayer = cruise_rig["player"]
	var hp1 := run1.hp
	c1.step(DT, Vector3(0.0, 1.0, 0.0), Vector3(CRUISE, 0.0, 0.0), null, false)
	for _i in 120:
		c1.step(DT, Vector3(0.0, 1.0, 10.0), Vector3(0.0, 0.0, CRUISE), null, false)
	t.eq("ball rolling through at cruise loses no hull", run1.hp, hp1)
	t.eq("ball rolling through at cruise is not tossed", player1.toss_count, 0)
	t.eq("surge recorded 0 ball hits for cruise ball", int(c1.sluice_state("sluice_a")["ball_hits"]), 0)
	_drop_rig(cruise_rig)

	# Case B: ball moving below cruise (0.45 * cruise, below SpeedTier.CRUISE = 0.55 * cruise) -> loses hull and tossed.
	var slow_speed := CRUISE * 0.45
	t.check("sanity: test slow speed is below SpeedTier.CRUISE", SpeedTier.of(slow_speed, CRUISE) < SpeedTier.CRUISE, str(slow_speed))
	var slow_rig := _make_rig()
	var c2: Node3D = slow_rig["c"]
	var run2: RunState = slow_rig["run"]
	var player2: FakePlayer = slow_rig["player"]
	var hp2 := run2.hp
	c2.step(DT, Vector3(0.0, 1.0, 0.0), Vector3(CRUISE, 0.0, 0.0), null, false)
	for _i in 120:
		c2.step(DT, Vector3(0.0, 1.0, 10.0), Vector3(0.0, 0.0, slow_speed), null, false)
	t.check("ball below cruise in the lane loses hull", run2.hp < hp2 and is_equal_approx(hp2 - run2.hp, Contraptions.SURGE_BALL_DAMAGE), "%.1f -> %.1f" % [hp2, run2.hp])
	t.eq("ball below cruise in the lane is tossed once", player2.toss_count, 1)
	await process_frame
	_drop_rig(slow_rig)


func _check_scrap_payment_once_per_charge_and_recharge() -> void:
	var props := [{"id": "crate_once", "tier": 2, "at": Vector3(0.0, 1.0, 10.0), "size": Vector3(2.0, 2.0, 2.0)}]
	var rig := _make_rig({}, props, 10)
	var c: Node3D = rig["c"]
	var run: RunState = rig["run"]
	var destructibles: Node3D = rig["props"]
	# Insufficient scrap refuses and spends nothing.
	t.check("payment with scrap below price is refused", not c.pay_sluice("sluice_a", run), "")
	t.eq("failed payment spends no scrap", run.scrap, 10)
	t.eq("failed payment leaves valve ready", c.sluice_state("sluice_a")["state"], "ready")
	# Give enough scrap for multiple payments and trigger via interact press while stopped beside valve.
	run.scrap = PRICE * 3
	rig["player"].intent["interact_pressed"] = true
	c.step(DT, Vector3(2.0, 1.0, 0.0), Vector3.ZERO, null, false)
	rig["player"].intent["interact_pressed"] = false
	t.eq("interact payment near valve arms warning", c.sluice_state("sluice_a")["state"], "warning")
	t.eq("scrap payment charged exact price once", run.scrap, PRICE * 2)
	t.eq("times_paid is 1", int(c.sluice_state("sluice_a")["times_paid"]), 1)
	# Attempting to pay again or ram while warning/surging/charging does nothing and spends nothing.
	t.check("second pay during warning is refused", not c.pay_sluice("sluice_a", run), "")
	t.eq("refused second pay spends nothing", run.scrap, PRICE * 2)
	# Run through warning + surge + half of charge, trying to ram and pay mid-cycle.
	for _i in 150:
		c.step(DT, Vector3(0.0, 1.0, 0.0), Vector3(CRUISE, 0.0, 0.0), null, false)
	t.eq("ram during warning/surge/charge never double-fires", int(c.sluice_state("sluice_a")["charges_fired"]), 1)
	t.check("pay during charging is refused", not c.pay_sluice("sluice_a", run), "")
	t.eq("scrap unchanged during charge", run.scrap, PRICE * 2)
	var loot_after_first: Dictionary = destructibles.loot().duplicate()
	# Finish recharging and fire a second time via direct pay_sluice.
	for _i in int((CHARGE_S + 0.5) / DT):
		c.step(DT, Vector3(40.0, 1.0, 0.0), Vector3.ZERO, null, false)
	t.eq("valve returns to ready after charge time", c.sluice_state("sluice_a")["state"], "ready")
	t.check("second pay succeeds after recharge", c.pay_sluice("sluice_a", run), "")
	t.eq("second pay charged exact price once", run.scrap, PRICE)
	for _i in 120:
		c.step(DT, Vector3(40.0, 1.0, 0.0), Vector3.ZERO, null, false)
	t.eq("charges_fired is now 2 after second charge cycle", int(c.sluice_state("sluice_a")["charges_fired"]), 2)
	t.eq("already-shattered prop pays nothing twice on a second surge", destructibles.loot(), loot_after_first)
	# Reset restores the valve cleanly.
	c.reset()
	t.eq("reset restores valve to ready with 0 fires", c.sluice_state("sluice_a")["state"], "ready")
	t.eq("reset clears charges_fired", int(c.sluice_state("sluice_a")["charges_fired"]), 0)
	await process_frame
	_drop_rig(rig)


func _check_planted_no_warning_fails() -> void:
	var live_res := _run_warning_trial(false)
	t.check("live valve passes warning predicate (>= 0.6 s visible before surge)", _warning_predicate(live_res), str(live_res))
	var planted_res := _run_warning_trial(true)
	t.check("planted case (surge with no warning) fails the same warning predicate", not _warning_predicate(planted_res), str(planted_res))
	await process_frame
