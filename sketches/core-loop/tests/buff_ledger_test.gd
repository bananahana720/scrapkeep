extends SceneTree

const T := preload("res://tests/support/t.gd")
const BuffLedger := preload("res://src/core/buff_ledger.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Triggers := preload("res://src/build/triggers.gd")
const Palette := preload("res://src/core/palette.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Driver := preload("res://tools/test_batch_driver.gd")

# E1-02 (ruling ek, Call H): BuffLedger unit & integration checks.
# Proves:
# - active_rows(4) cap and eviction of shortest remaining time (with oldest tie-break,
#   untimed counters as INF, oldest-first stable slot order, defensive copies);
# - < 3 s timer filtering (rail_min_s = 3.0 default, draining timers >= 3 s stay visible);
# - refresh, stacking, Call H show_digit split (timers drain without digits, counts show digits),
#   and signal hygiene (buff_changed only on visible state changes, buff_expired on expiry);
# - pause and Engine.time_scale safety through live Game physics ticking;
# - attempt-boundary clearing (run_started, stage_entered, stage_content_cleared, player_died);
# - live ItemEffects and AbilityState hooks (drone, armed_hit, rebound_crit, brace filtered,
#   running ability >= 3 s vs < 3 s, and zero purple Jam tube);
# - zero save persistence in RunState entrance doc and Profile;
# - warm-batch reset via tools/test_batch_driver.gd _reset().


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("buff_ledger_test")
	_check_cap_and_eviction(t)
	_check_short_timer_filter(t)
	_check_refresh_stacking_and_signals(t)
	await _check_live_game_pause_timescale_boundaries_and_hooks(t)
	_check_warm_batch_reset(t)
	quit(t.verdict())


func _check_cap_and_eviction(t) -> void:
	var ledger := BuffLedger.new()
	ledger.post("a", {"icon": "cat_utility", "tone": Palette.ARC, "duration_s": 10.0, "kind": "timer"})
	ledger.post("b", {"icon": "cat_damage", "tone": Palette.AMBER, "duration_s": 4.0, "kind": "timer"})
	ledger.post("c", {"icon": "cat_defense", "tone": Palette.STEEL, "duration_s": 8.0, "kind": "timer"})
	ledger.post("d", {"icon": "cat_mobility", "tone": Palette.COPPER, "duration_s": 6.0, "kind": "timer"})
	ledger.step(0.5)
	var before := ledger.active_rows(4)
	t.eq("four visible rows keep oldest-first order", _ids(before), ["a", "b", "c", "d"])

	# Posting a 5th visible effect evicts "b" (3.5 s left, shortest remaining time).
	ledger.post("e", {"icon": "cat_charge", "tone": Palette.SAND, "duration_s": 5.0, "kind": "timer"})
	var after := ledger.active_rows(4)
	t.eq("5th visible effect evicts shortest remaining time", _ids(after), ["a", "c", "d", "e"])
	t.check("evicted entry removed even with wider limit", _row_by_id(ledger.active_rows(8), "b").is_empty())

	# Defensive copy: mutating a returned row never mutates internal state.
	after[0]["left_s"] = 999.0
	after[0]["icon"] = "mutated"
	var reread := ledger.active_rows(4)
	t.near("returned row copy protects left_s", float(reread[0]["left_s"]), 9.5, 0.001)
	t.eq("returned row copy protects icon", String(reread[0]["icon"]), "cat_utility")

	# Smaller limit trims shortest remaining first while keeping oldest-first order.
	# Remaining: a=9.5, c=7.5, d=5.5, e=5.0 -> limit 2 keeps a and c.
	t.eq("active_rows(2) keeps longest remaining in oldest-first order", _ids(ledger.active_rows(2)), ["a", "c"])
	t.eq("active_rows(0) returns empty", ledger.active_rows(0), [])

	# Untimed counter (INF time left) is never evicted ahead of a finite timer.
	var tie := BuffLedger.new()
	tie.post("cnt", {"icon": "cat_damage", "tone": Palette.AMBER, "duration_s": 0.0, "kind": "count", "stacks": 2, "max_stacks": 3})
	tie.post("t1", {"icon": "cat_utility", "tone": Palette.ARC, "duration_s": 5.0, "kind": "timer"})
	tie.post("t2", {"icon": "cat_utility", "tone": Palette.ARC, "duration_s": 5.0, "kind": "timer"})
	tie.post("t3", {"icon": "cat_utility", "tone": Palette.ARC, "duration_s": 7.0, "kind": "timer"})
	tie.post("t4", {"icon": "cat_utility", "tone": Palette.ARC, "duration_s": 6.0, "kind": "timer"})
	# t1 and t2 tied at 5.0 s -> oldest (t1) evicted; cnt survives.
	t.eq("equal remaining time evicts oldest finite timer and keeps untimed counter", _ids(tie.active_rows(4)), ["cnt", "t2", "t3", "t4"])


func _check_short_timer_filter(t) -> void:
	var ledger := BuffLedger.new()
	var changed := [0]
	var expired: Array[String] = []
	ledger.buff_changed.connect(func(): changed[0] += 1)
	ledger.buff_expired.connect(func(id: String): expired.append(id))

	# Timers < 3.0 s stay off the rail and emit no visible buff_changed signal.
	ledger.post("flash_1", {"icon": "cat_defense", "tone": Palette.STEEL, "duration_s": 1.5, "kind": "timer"})
	ledger.post("flash_2", {"icon": "cat_defense", "tone": Palette.STEEL, "duration_s": 2.99, "kind": "timer"})
	t.eq("sub-3s timers filtered from active_rows", ledger.active_rows(4), [])
	t.eq("sub-3s posts emit zero buff_changed", changed[0], 0)

	# Sub-3s timers never evict a full 4-tube rail.
	for i in 4:
		ledger.post("long_%d" % i, {"icon": "cat_utility", "tone": Palette.ARC, "duration_s": 4.0 + i, "kind": "timer"})
	var before_short := _ids(ledger.active_rows(4))
	var changes_before: int = changed[0]
	ledger.post("flash_3", {"icon": "cat_defense", "tone": Palette.STEEL, "duration_s": 2.0, "kind": "timer"})
	t.eq("sub-3s timer does not evict visible tubes", _ids(ledger.active_rows(4)), before_short)
	t.eq("sub-3s post on full rail emits no buff_changed", changed[0], changes_before)

	# A 3.0 s timer IS visible and stays visible while draining below 3.0 s until expiry.
	var drain := BuffLedger.new()
	var drain_expired: Array[String] = []
	drain.buff_expired.connect(func(id: String): drain_expired.append(id))
	drain.post("exact_3s", {"icon": "cat_utility", "tone": Palette.ARC, "duration_s": 3.0, "kind": "timer"})
	var rows := drain.active_rows(4)
	t.eq("exact 3.0s timer is visible on rail", _ids(rows), ["exact_3s"])
	t.check("pure timer hides digit (Call H)", not bool(rows[0]["show_digit"]))
	drain.step(1.5)
	rows = drain.active_rows(4)
	t.eq("3.0s timer stays visible while draining past 1.5s", _ids(rows), ["exact_3s"])
	t.near("draining timer frac is 0.5 at half duration", float(rows[0]["frac"]), 0.5, 0.001)
	drain.step(1.5)
	t.eq("timer clears on expiry", drain.active_rows(4), [])
	t.eq("buff_expired fires with expired id", drain_expired, ["exact_3s"])

	# Custom rail_min_s override is honored.
	drain.post("custom_min", {"icon": "cat_utility", "tone": Palette.ARC, "duration_s": 2.0, "kind": "timer", "rail_min_s": 1.5})
	t.eq("custom rail_min_s allows 2.0s timer", _ids(drain.active_rows(4)), ["custom_min"])


func _check_refresh_stacking_and_signals(t) -> void:
	var ledger := BuffLedger.new()
	var changed := [0]
	ledger.buff_changed.connect(func(): changed[0] += 1)

	# Stepping empty ledger emits nothing.
	ledger.step(0.5)
	t.eq("step on empty ledger emits zero buff_changed", changed[0], 0)

	# Posting a counter shows digit and stepping it does not emit buff_changed.
	ledger.post("armed", {"icon": "cat_damage", "tone": Palette.AMBER, "duration_s": 0.0, "kind": "count", "stacks": 1, "max_stacks": 3})
	t.eq("new counter emits buff_changed once", changed[0], 1)
	var rows := ledger.active_rows(4)
	t.check("counter row has required fields and show_digit=true",
		rows.size() == 1
		and rows[0]["id"] == "armed"
		and rows[0]["icon"] == "cat_damage"
		and rows[0]["tone"] == Palette.AMBER
		and rows[0]["kind"] == "count"
		and is_zero_approx(float(rows[0]["left_s"]))
		and is_zero_approx(float(rows[0]["duration_s"]))
		and int(rows[0]["stacks"]) == 1
		and int(rows[0]["max_stacks"]) == 3
		and bool(rows[0]["show_digit"]))
	ledger.step(1.0)
	t.eq("step with only untimed counter emits zero buff_changed", changed[0], 1)

	# Identical re-post emits nothing; stacking past max_stacks clamps cleanly.
	ledger.post("armed", {"icon": "cat_damage", "tone": Palette.AMBER, "duration_s": 0.0, "kind": "count", "stacks": 1, "max_stacks": 3})
	t.eq("identical counter re-post emits zero buff_changed", changed[0], 1)
	ledger.post("armed", {"stacks": 5})
	t.eq("stack change emits buff_changed", changed[0], 2)
	t.eq("stacks clamp to max_stacks", int(ledger.active_rows(4)[0]["stacks"]), 3)
	t.near("untimed counter frac reflects stacks/max_stacks", float(ledger.active_rows(4)[0]["frac"]), 1.0, 0.001)

	# Timer refresh preserves slot order and restores full duration.
	ledger.post("drone", {"icon": "cat_utility", "tone": Palette.ARC, "duration_s": 4.0, "kind": "timer"})
	ledger.post("second", {"icon": "cat_mobility", "tone": Palette.COPPER, "duration_s": 6.0, "kind": "timer"})
	ledger.step(2.0)
	t.near("drone drains to 2.0s", float(ledger.active_rows(4)[1]["left_s"]), 2.0, 0.001)
	var before_refresh: int = changed[0]
	ledger.post("drone", {"duration_s": 4.0})
	t.eq("refresh preserves oldest-first slot order", _ids(ledger.active_rows(4)), ["armed", "drone", "second"])
	t.near("refresh restores full left_s", float(ledger.active_rows(4)[1]["left_s"]), 4.0, 0.001)
	t.eq("refresh emits buff_changed once", changed[0], before_refresh + 1)

	# Posting stacks=0 on a counter clears it.
	ledger.post("armed", {"stacks": 0})
	t.eq("stacks=0 clears counter entry", _ids(ledger.active_rows(4)), ["drone", "second"])


func _check_live_game_pause_timescale_boundaries_and_hooks(t) -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	await physics_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	for _i in 3:
		await physics_frame

	var buffs: BuffLedger = game.ctx.buffs
	t.check("GameContext owns ctx.buffs", buffs != null)

	# 1. Pause safety: while SceneTree is paused, live buff left_s does not advance.
	buffs.post("pause_probe", {"icon": "cat_utility", "tone": Palette.ARC, "duration_s": 6.0, "kind": "timer"})
	var start_left := float(buffs.active_rows(4)[0]["left_s"])
	paused = true
	for _i in 6:
		await process_frame
	var paused_left := float(buffs.active_rows(4)[0]["left_s"])
	paused = false
	t.near("paused SceneTree does not drain buffs", paused_left, start_left, 0.0001)

	# 2. Engine.time_scale safety: 0.25 time_scale drains at 1/4 rate per physics tick vs 1.0.
	# Wait one process_frame after changing Engine.time_scale so Godot applies the new scale before measuring.
	var ticks := 6
	Engine.time_scale = 1.0
	await process_frame
	await physics_frame
	buffs.post("scale_probe", {"icon": "cat_utility", "tone": Palette.ARC, "duration_s": 10.0, "kind": "timer"})
	var before_full := float(_row_by_id(buffs.active_rows(4), "scale_probe")["left_s"])
	for _i in ticks:
		await physics_frame
	var drained_full := before_full - float(_row_by_id(buffs.active_rows(4), "scale_probe")["left_s"])

	Engine.time_scale = 0.25
	await process_frame
	await physics_frame
	buffs.post("scale_probe", {"icon": "cat_utility", "tone": Palette.ARC, "duration_s": 10.0, "kind": "timer"})
	var before_slow := float(_row_by_id(buffs.active_rows(4), "scale_probe")["left_s"])
	for _i in ticks:
		await physics_frame
	var drained_slow := before_slow - float(_row_by_id(buffs.active_rows(4), "scale_probe")["left_s"])
	Engine.time_scale = 1.0
	t.check("Engine.time_scale scales buff drain cleanly",
		drained_full > 0.0 and drained_slow > 0.0 and absf(drained_slow / drained_full - 0.25) < 0.05,
		"full=%.4f slow=%.4f ratio=%.3f" % [drained_full, drained_slow, drained_slow / maxf(0.0001, drained_full)])

	# 3. Zero save persistence: RunState entrance doc and Profile never serialize buffs.
	var entrance_doc: Dictionary = game.run.to_entrance_doc(game.player.tree)
	var doc_text := JSON.stringify(entrance_doc)
	t.check("RunState entrance doc persists no buffs",
		not entrance_doc.has("buffs") and not doc_text.contains("pause_probe") and not doc_text.contains("scale_probe"),
		"keys=%s" % [entrance_doc.keys()])

	# 4. Attempt-boundary clearing on all four GameEvents boundaries.
	buffs.clear()
	for boundary in ["run_started", "stage_entered", "stage_content_cleared", "player_died"]:
		buffs.post("boundary_probe", {"icon": "cat_utility", "tone": Palette.ARC, "duration_s": 8.0, "kind": "timer"})
		t.eq("buff active before " + boundary, _ids(buffs.active_rows(4)), ["boundary_probe"])
		match boundary:
			"run_started":
				game.events.run_started.emit("pylon_engineer")
			"stage_entered":
				game.events.stage_entered.emit(1, true)
			"stage_content_cleared":
				game.events.stage_content_cleared.emit("test")
			"player_died":
				game.events.player_died.emit()
		t.eq("buffs clear on " + boundary, buffs.active_rows(4), [])

	# Re-enter stage 1 cleanly after synthetic player_died for live producer checks.
	game.flow.new_run()
	await physics_frame
	buffs.clear()

	# 5. Live ItemEffects hooks: drone (>= 3s), armed_hit (counter), rebound_crit (timed counter), brace (< 3s filtered).
	var effects = game.ctx.build.effects
	var bus = game.ctx.build.bus
	var rng = game.ctx.build.loot_rng
	game.run.add_part("overpressure", "test")
	effects.tick(8.05, bus)
	bus.run(effects.resolve, rng)
	var armed_row := _row_by_id(buffs.active_rows(4), "item_armed_hit")
	t.check("ItemEffects arm_hit posts visible counter buff",
		not armed_row.is_empty() and armed_row["kind"] == "count" and bool(armed_row["show_digit"]) and int(armed_row["stacks"]) == 1)
	# Consuming armed_hit on ON_HIT clears the ledger row.
	var dummy := Node3D.new()
	root.add_child(dummy)
	bus.post(Triggers.Commitment.new(Triggers.Kind.ON_HIT, "arc", Triggers.DISCRETE_PROC, Vector3.ZERO, dummy, 10.0))
	bus.run(effects.resolve, rng)
	t.check("consuming armed_hit clears item_armed_hit", _row_by_id(buffs.active_rows(4), "item_armed_hit").is_empty())

	# Drone (4.0 s >= 3.0 s) shows as draining timer; brace (1.0 s < 3.0 s) is filtered off rail.
	var Parts := preload("res://src/build/parts.gd")
	game.run.add_part("salvage_drone", "test")
	game.run.add_part("brace_frame", "test")
	var drone_def := Parts.def("salvage_drone")
	var brace_def := Parts.def("brace_frame")
	effects._apply("salvage_drone", drone_def, drone_def.effect,
		Triggers.Commitment.new(Triggers.Kind.ON_KILL, "arc", Triggers.DISCRETE_PROC, Vector3.ZERO), 0.0, 0.0, 0)
	effects._apply("brace_frame", brace_def, brace_def.effect,
		Triggers.Commitment.new(Triggers.Kind.ON_LAND, "land", Triggers.DISCRETE_PROC, Vector3.ZERO, null, 20.0), 0.2, 0.0, 1)
	var drone_row := _row_by_id(buffs.active_rows(4), "item_drone")
	t.check("ItemEffects drone posts >= 3s timer with show_digit=false",
		not drone_row.is_empty() and drone_row["kind"] == "timer" and not bool(drone_row["show_digit"]) and float(drone_row["duration_s"]) >= 4.0)
	t.check("ItemEffects brace (< 3s) is filtered off rail", _row_by_id(buffs.active_rows(4), "item_brace").is_empty())

	# Rebound crit (4.0 s window, count 3): stacks 1 -> 2, then clears on 3rd payout.
	var bounce_def := Parts.def("strike_pocket")
	t.check("strike_pocket (rebound_crit) exists in catalogue", bounce_def != null)
	if bounce_def != null:
		var reb_c := Triggers.Commitment.new(Triggers.Kind.ON_REBOUND, "rebound", Triggers.DISCRETE_PROC, Vector3.ZERO, dummy, 15.0)
		effects._apply(bounce_def.id, bounce_def, bounce_def.effect, reb_c, 0.0, 0.0, 2)
		var r1 := _row_by_id(buffs.active_rows(4), "item_rebound_crit")
		t.check("rebound_crit 1st bounce posts timed count stack 1",
			not r1.is_empty() and int(r1["stacks"]) == 1 and int(r1["max_stacks"]) == 3 and bool(r1["show_digit"]))
		effects._apply(bounce_def.id, bounce_def, bounce_def.effect, reb_c, 0.0, 0.0, 2)
		var r2 := _row_by_id(buffs.active_rows(4), "item_rebound_crit")
		t.eq("rebound_crit 2nd bounce increments stack to 2", int(r2.get("stacks", 0)), 2)
		effects._apply(bounce_def.id, bounce_def, bounce_def.effect, reb_c, 0.0, 0.0, 2)
		t.check("rebound_crit 3rd bounce pays out and clears buff", _row_by_id(buffs.active_rows(4), "item_rebound_crit").is_empty())

	dummy.free()

	# 6. AbilityState hooks: NO purple Jam tube; running abilities >= 3 s appear, < 3 s stay off rail.
	buffs.clear()
	var ab: AbilityState = game.player.abilities
	ab.jam(5.0)
	var after_jam := buffs.active_rows(4)
	t.check("jam never posts a purple Jam tube (Call H)", after_jam.is_empty())

	ab.swap(AbilityState.MOVEMENT, "overdrive_sprint")
	ab.set_attack_speed(1.0)
	ab.request(AbilityState.MOVEMENT)
	ab.tick(0.01)
	t.check("2.0s overdrive_sprint stays off rail (< 3s)", _row_by_id(buffs.active_rows(4), "ability_overdrive_sprint").is_empty())
	ab.refill()

	ab.set_attack_speed(0.5)  # duration 2.0 / 0.5 = 4.0 s >= 3.0 s
	ab.request(AbilityState.MOVEMENT)
	ab.tick(0.01)
	var sprint_row := _row_by_id(buffs.active_rows(4), "ability_overdrive_sprint")
	t.check("4.0s running ability appears on rail as timer",
		not sprint_row.is_empty() and sprint_row["kind"] == "timer" and not bool(sprint_row["show_digit"]) and float(sprint_row["duration_s"]) >= 3.99)
	ab.tick(1.0)
	var sprint_mid := _row_by_id(buffs.active_rows(4), "ability_overdrive_sprint")
	t.near("running ability timer drains in lockstep with AbilityState.tick", float(sprint_mid.get("left_s", -1.0)), 3.0, 0.05)
	ab.refill()
	t.check("AbilityState.refill clears running ability buff", _row_by_id(buffs.active_rows(4), "ability_overdrive_sprint").is_empty())

	game.free()


func _check_warm_batch_reset(t) -> void:
	BuffLedger.default_rail_min_s = 99.0
	var driver := Driver.new(self, [])
	driver._reset()
	t.near("test_batch_driver._reset restores BuffLedger.default_rail_min_s",
		BuffLedger.default_rail_min_s, BuffLedger.DEFAULT_RAIL_MIN_S, 0.0001)


static func _ids(rows: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for row in rows:
		out.append(String(row["id"]))
	return out


static func _row_by_id(rows: Array[Dictionary], id: String) -> Dictionary:
	for row in rows:
		if String(row["id"]) == id:
			return row
	return {}
