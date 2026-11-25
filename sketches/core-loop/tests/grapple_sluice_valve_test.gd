extends SceneTree

const T := preload("res://tests/support/t.gd")
const Augments := preload("res://src/movement/augments.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const SluiceValves := preload("res://src/world/sluice_valves.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# W47-GRAPPLE-CODE: W1 Spillway grapple-yank sluice valves (g12, TADR-008, ParkFlood.tla).
# Proves in headless Godot:
#   1. sluice_valve_body.glb & sluice_valve_wheel.glb load with socket_hub and socket_bite.
#   2. Bite ring is a WORLD_ANCHOR_GROUP + ANCHOR_GROUP body on WORLD_MASK; hooking it with
#      PlayerBall links as a world pivot (preserving universal HOOK-CHAIN without faking an enemy).
#   3. Mid-swing grapple yank spins sluice_valve_wheel.glb about local Z and commits a visible
#      TADR-008 Hazard lane (warn_seconds >= 0.6 s) BEFORE any wash damage or knockback occurs.
#   4. Flood-wash damages & throws locked yard crews/enemies inside the lane once (sparing set
#      pieces/Wardens), hits/tosses a slow or parked ball once (double-edged), and spares a
#      ball rolling at cruise or faster (ruling cu).
#   5. ParkFlood.tla compliance: even with a ball parked dead-still inside the lane, full water
#      is NEVER held indefinitely; the cycle always drains back to 0.0 and recharges cleanly.
#   6. Dam (apron_sluice, pump_yard_sluice) and Flume (wasteway_sluice, forecourt_sluice) specs
#      load cleanly via sync_stage and reset cleanly.

const CRUISE := 14.0
const DT := 1.0 / 60.0

var t := T.new("grapple_sluice_valve_test")


class FakeEnemy extends Node3D:
	var half_height := 1.0
	var hp := 80.0
	var hits := 0
	var knocked := Vector3.ZERO
	var last_damage_source := ""
	var kind := "chaser"

	func is_dead() -> bool:
		return hp <= 0.0

	func take_damage(amount: float) -> void:
		hits += 1
		hp = maxf(0.0, hp - amount)

	func knock(dir: Vector3, force: float) -> void:
		knocked = dir * force


class FakeRun extends RefCounted:
	var damage_taken := 0.0
	var damage_sources: Array[String] = []

	func damage(amount: float, source: String) -> void:
		damage_taken += amount
		damage_sources.append(source)


class FakePlayer extends Node3D:
	var last_velocity := Vector3.ZERO
	var velocity_source := ""

	func set_velocity_now(v: Vector3, source := "") -> void:
		last_velocity = v
		velocity_source = source


func _initialize() -> void:
	_run()


func _flat_ground(x: float, z: float, _lift := 0.0) -> Vector3:
	return Vector3(x, 0.0, z)


func _valve_spec(id := "test_sluice") -> Dictionary:
	return {
		"id": id,
		"kind": "sluice_valve",
		"at": [0.0, 0.0],
		"lane": {"from": [0.0, 4.0], "to": [0.0, 28.0], "half_width": 5.0, "reach": 4.0},
		"charge": 3.0,
	}


func _run() -> void:
	await process_frame
	_check_glb_and_sockets()
	_check_player_hook_yank_and_chain_pivot()
	_check_tadr008_warn_floor_and_double_edged_wash()
	_check_park_flood_tla_never_holds_under_parked_ball()
	await _check_clear_valves_frees_sheets_and_hazards()
	_check_dam_and_flume_specs_and_reset()
	quit(t.verdict())


func _check_glb_and_sockets() -> void:
	t.check("sluice_valve_body.glb exists", ResourceLoader.exists(SluiceValves.BODY_PATH), SluiceValves.BODY_PATH)
	t.check("sluice_valve_wheel.glb exists", ResourceLoader.exists(SluiceValves.WHEEL_PATH), SluiceValves.WHEEL_PATH)
	var sv := SluiceValves.new()
	root.add_child(sv)
	sv.build_from_specs([_valve_spec()], Callable(self, "_flat_ground"), CRUISE, null)
	var v := sv.valve_of("test_sluice")
	t.check("valve built with body, wheel, hub and bite sockets",
		v.get("body") != null and v.get("wheel") != null and v.get("socket_hub") != null and v.get("socket_bite") != null,
		str(v.keys()))
	var bite: StaticBody3D = v["bite_body"]
	t.check("bite_body is hookable world anchor on WORLD_MASK",
		bite.collision_layer == Augments.WORLD_MASK
		and bite.is_in_group(Augments.WORLD_ANCHOR_GROUP)
		and bite.is_in_group(Augments.ANCHOR_GROUP)
		and bite.is_in_group(SluiceValves.BITE_GROUP),
		"layer=%d" % bite.collision_layer)
	sv.free()


func _check_player_hook_yank_and_chain_pivot() -> void:
	var ev := GameEvents.new()
	var pb := PlayerBall.new()
	root.add_child(pb)
	pb.setup(Tuning.new(), ev, Vector3.ZERO)
	pb.fit_class(ClassDef.all()[0])

	var sv := SluiceValves.new()
	root.add_child(sv)
	sv.build_from_specs([_valve_spec("apron_test")], Callable(self, "_flat_ground"), CRUISE, {"events": ev, "player": pb})
	var v := sv.valve_of("apron_test")
	var bite: StaticBody3D = v["bite_body"]
	var wheel: Node3D = v["wheel"]

	# Hook the valve bite ring via PlayerBall.grapple_to.
	pb.grapple_to(bite.global_position, Vector3.BACK, bite)
	t.check("hooking bite ring links as world pivot (not enemy)",
		pb.chain.active() and pb.chain.pivots == 1 and pb.chain.links == 0,
		str(pb.chain.snapshot()))

	# Mid-swing pull turns wheel about local Z and arms warning state.
	var warned := false
	for _i in 20:
		var facts := sv.step(DT, Vector3(6.0, 2.5, 4.0), Vector3(12.0, 0.0, 4.0), pb.kit, false)
		for f in facts:
			if String(f.get("kind", "")) == "sluice_warning":
				warned = true
		if String(v["state"]) == "warning":
			break
	t.check("mid-swing grapple yank opens valve into warning", warned and String(v["state"]) == "warning",
		"state=%s yanks=%d" % [v["state"], int(v["yanks_triggered"])])
	t.check("wheel rotates about local Z when yanked", wheel.rotation.z >= SluiceValves.YANK_OPEN_RAD - 0.01,
		"wheel.rotation.z=%.3f" % wheel.rotation.z)

	sv.free()
	pb.free()
	ev.free()


func _check_tadr008_warn_floor_and_double_edged_wash() -> void:
	var run_ref := FakeRun.new()
	var player_ref := FakePlayer.new()
	root.add_child(player_ref)
	var sv := SluiceValves.new()
	root.add_child(sv)
	sv.build_from_specs([_valve_spec("yard_sluice")], Callable(self, "_flat_ground"), CRUISE,
		{"run": run_ref, "player": player_ref, "calm": false})

	var crew_in := FakeEnemy.new()
	crew_in.add_to_group("enemy")
	crew_in.position = Vector3(0.0, 1.0, 14.0)
	root.add_child(crew_in)

	var crew_out := FakeEnemy.new()
	crew_out.add_to_group("enemy")
	crew_out.position = Vector3(18.0, 1.0, 14.0)
	root.add_child(crew_out)

	var warden := FakeEnemy.new()
	warden.kind = "warden"
	warden.add_to_group("enemy")
	warden.position = Vector3(1.0, 1.0, 16.0)
	root.add_child(warden)

	t.check("yank arms valve", sv.yank("yard_sluice"), "armed")
	var v := sv.valve_of("yard_sluice")
	var h: Hazard = v["hazard"]
	t.check("TADR-008 Hazard lane committed on yank",
		h != null and h.type == Threat.Type.LANE and h.warn_seconds >= SluiceValves.WARN_MIN_S and h.is_in_group(Threat.GROUP),
		"warn_s=%.2f" % (h.warn_seconds if h != null else -1.0))

	# Step through 0.55 s of warning: ZERO hits allowed before warn_seconds elapses!
	var ball_in_lane := Vector3(0.0, 1.0, 14.0)
	for _i in 33:
		sv.step(DT, ball_in_lane, Vector3.ZERO, null, false)
	t.eq("still warning before 0.6 s floor", String(v["state"]), "warning")
	t.eq("TADR-008 zero enemy damage during warning", crew_in.hits, 0)
	t.near("TADR-008 zero ball damage during warning", run_ref.damage_taken, 0.0, 0.001)
	t.near("water_level stays 0.0 during warning", float(v["water_level"]), 0.0, 0.001)

	# Finish warning -> surging washes crew_in & slow/parked ball once, spares crew_out and warden!
	for _i in 40:
		sv.step(DT, ball_in_lane, Vector3(2.0, 0.0, 0.0), null, false)
		if String(v["state"]) == "surging":
			break
	t.eq("entered surging after visible warning", String(v["state"]), "surging")
	t.check("visible warning elapsed >= 0.6 s", float(v["last_warn_visible_s"]) >= SluiceValves.WARN_MIN_S - 0.001,
		"warn_vis=%.3f" % float(v["last_warn_visible_s"]))
	t.eq("locked yard crew inside lane washed once", crew_in.hits, 1)
	t.check("locked yard crew tossed along flow", crew_in.knocked.z > 10.0, str(crew_in.knocked))
	t.eq("crew outside lane untouched", crew_out.hits, 0)
	t.eq("set piece warden spared", warden.hits, 0)
	t.near("slow ball takes double-edged wash damage once", run_ref.damage_taken, SluiceValves.WASH_BALL_DAMAGE, 0.01)
	t.check("slow ball pushed along wash", player_ref.last_velocity.z > 10.0, str(player_ref.last_velocity))

	# Second cycle: a ball rolling at >= CRUISE through the lane is SPARED (ruling cu).
	sv.reset()
	run_ref.damage_taken = 0.0
	player_ref.last_velocity = Vector3.ZERO
	sv.yank("yard_sluice")
	for _i in 90:
		sv.step(DT, ball_in_lane, Vector3(0.0, 0.0, CRUISE + 2.0), null, false)
		if String(v["state"]) == "surging":
			break
	t.eq("surging with fast ball", String(v["state"]), "surging")
	t.near("ruling cu: rolling ball at cruise+ takes zero wash damage", run_ref.damage_taken, 0.0, 0.001)
	t.eq("ruling cu: rolling ball at cruise+ is not tossed", player_ref.last_velocity, Vector3.ZERO)

	crew_in.free()
	crew_out.free()
	warden.free()
	sv.free()
	player_ref.free()


func _check_park_flood_tla_never_holds_under_parked_ball() -> void:
	var sv := SluiceValves.new()
	root.add_child(sv)
	sv.build_from_specs([_valve_spec("tla_sluice")], Callable(self, "_flat_ground"), CRUISE, null)
	var v := sv.valve_of("tla_sluice")
	sv.yank("tla_sluice")

	var parked := Vector3(0.0, 1.0, 14.0)
	var saw_surging := false
	var saw_draining := false
	var saw_charging := false
	var full_water_s := 0.0
	# Step 3.0 seconds with a dead-still parked ball sitting inside the wash lane.
	for _i in 180:
		sv.step(DT, parked, Vector3.ZERO, null, false)
		var st := String(v["state"])
		if st == "surging":
			saw_surging = true
			full_water_s += DT
		elif st == "draining":
			saw_draining = true
		elif st == "charging":
			saw_charging = true
	t.check("ParkFlood.tla cycle progresses surging -> draining -> charging under parked ball",
		saw_surging and saw_draining and saw_charging,
		"surging=%s draining=%s charging=%s final=%s" % [saw_surging, saw_draining, saw_charging, v["state"]])
	t.check("ParkFlood.tla full water never held past SURGE_LIVE_S under parked ball",
		full_water_s <= SluiceValves.SURGE_LIVE_S + DT * 2.0 and float(v["water_level"]) <= 0.001,
		"full_water_s=%.3f water_level=%.3f" % [full_water_s, float(v["water_level"])])

	# Recharge finishes back to ready cleanly.
	for _i in 220:
		sv.step(DT, parked, Vector3.ZERO, null, false)
		if String(v["state"]) == "ready":
			break
	t.eq("valve recharges cleanly to ready", String(v["state"]), "ready")
	sv.free()


func _check_clear_valves_frees_sheets_and_hazards() -> void:
	var sv := SluiceValves.new()
	root.add_child(sv)
	sv.build_from_specs([_valve_spec("leak_a"), _valve_spec("leak_b")], Callable(self, "_flat_ground"), CRUISE, null)
	sv.yank("leak_a")
	for _i in 70:
		sv.step(DT, Vector3(0.0, 1.0, 14.0), Vector3.ZERO, null, false)
		if String(sv.valve_of("leak_a")["state"]) == "surging":
			break
	t.check("mid-surge has holder, sheet and hazard children", sv.get_child_count() >= 4, "children=%d" % sv.get_child_count())
	sv.clear_valves()
	await process_frame
	t.eq("clear_valves frees every holder, FloodWashSheet, and Hazard (zero leaked children)", sv.get_child_count(), 0)
	sv.free()


func _check_dam_and_flume_specs_and_reset() -> void:
	for entry in [
		["res://src/world/park/park_dam.json", ["apron_sluice", "pump_yard_sluice"]],
		["res://src/world/park/park_flume.json", ["wasteway_sluice", "forecourt_sluice"]],
	]:
		var raw := FileAccess.get_file_as_string(String(entry[0]))
		var data: Dictionary = JSON.parse_string(raw)
		var specs: Array = []
		for row in data.get("contraption_rows", []):
			if String(row.get("kind", "")) == "sluice_valve":
				specs.append(row)
		var sv := SluiceValves.new()
		root.add_child(sv)
		sv.build_from_specs(specs, Callable(self, "_flat_ground"), CRUISE, null)
		var ids := sv.valve_ids()
		for want_id: String in entry[1]:
			t.check("%s loads %s" % [String(entry[0]).get_file(), want_id], ids.has(want_id), str(ids))
		sv.yank(ids[0])
		sv.reset()
		t.eq("%s reset returns valve to ready" % String(entry[0]).get_file(), String(sv.valve_of(ids[0])["state"]), "ready")
		sv.free()
