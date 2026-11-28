extends RefCounted

const StageLocks := preload("res://src/world/stage_locks.gd")
const EncounterEngine := preload("res://src/experimental/encounter_engine.gd")
const AdversityDirector := preload("res://src/experimental/adversity_director.gd")
const AdversityDirectorConfig := preload("res://src/experimental/resources/director/adversity_director_config.gd")
const EncounterCatalogConfig := preload("res://src/experimental/resources/director/encounter_catalog_config.gd")
const RefurbishedEliteConfig := preload("res://src/experimental/resources/director/refurbished_elite_config.gd")
const RefurbishedElites := preload("res://src/experimental/refurbished_elites.gd")
const DynamicSetpieces := preload("res://src/experimental/dynamic_setpieces.gd")
const JuryRigSynergies := preload("res://src/experimental/jury_rig_synergies.gd")
const LiveWorldActors := preload("res://src/experimental/live_world_actors.gd")

const CENTRE := Vector3(3.0, 1.0, -2.0)
const SPRING_ROWS := [
	["inside", Vector3(5.0, 0.0, -2.0), Vector3(4.0, 0.0, 0.0), 10.0, Vector3.ZERO, Vector3.ZERO],
	["on the ring", Vector3(13.0, 5.0, -2.0), Vector3(4.0, 0.0, 0.0), 10.0, Vector3.ZERO, Vector3.ZERO],
	["at the centre", Vector3(3.0, 7.0, -2.0), Vector3(0.0, -3.0, 0.0), 10.0, Vector3.ZERO, Vector3.ZERO],
	["outside moving in", Vector3(14.0, 0.0, -2.0), Vector3(-3.0, 0.0, 0.0), 10.0, Vector3(-60.0, 0.0, 0.0), Vector3(-60.0, 0.0, 0.0)],
	["outside moving out", Vector3(3.0, 0.0, 9.0), Vector3(0.0, 2.0, 1.0), 10.0, Vector3(0.0, 0.0, -68.0), Vector3(0.0, 0.0, -68.0)],
	["outside at rest", Vector3(3.0, 0.0, -14.5), Vector3.ZERO, 10.0, Vector3(0.0, 0.0, 120.0), Vector3(0.0, 0.0, 120.0)],
	["far outside moving in, capped", Vector3(19.0, 0.0, -2.0), Vector3(-1.0, 0.0, 0.0), 10.0, Vector3(-120.0, 0.0, 0.0), Vector3(-120.0, 0.0, 0.0)],
	["radius zero", Vector3(8.0, 0.0, -2.0), Vector3.ZERO, 0.0, Vector3(-120.0, 0.0, 0.0), Vector3.ZERO],
	["radius below zero", Vector3(3.5, 0.0, -2.0), Vector3.ZERO, -1.0, Vector3(-90.0, 0.0, 0.0), Vector3.ZERO],
]
const DIAGONALS := [
	[Vector3(10.5, 0.0, 8.0), Vector3(0.3, 0.0, -0.4)],
	[Vector3(-6.0, 2.0, 4.5), Vector3(-2.0, 1.0, 3.0)],
	[Vector3(12.0, -1.0, -12.0), Vector3(-5.0, 0.0, 5.0)],
	[Vector3(2.0, 0.0, 9.5), Vector3(0.0, 0.0, 0.0)],
]


class FakeState extends RefCounted:
	var velocity := Vector3.ZERO


class FakePlayer extends RefCounted:
	var at := Vector3.ZERO
	var state := FakeState.new()
	var accel := Vector3.ZERO
	var set_to = null

	func ball_position() -> Vector3:
		return at

	func add_external_accel(a: Vector3) -> void:
		accel += a

	func set_velocity_now(v: Vector3, _reason: String) -> void:
		set_to = v


class FakeCtx extends RefCounted:
	var player := FakePlayer.new()


func run(t) -> void:
	_spring(t)
	_cruise_fallbacks(t)
	_warning_floors(t)


func _stage_hold(pos: Vector3, vel: Vector3, radius: float) -> Dictionary:
	var lock := StageLocks.new()
	var ctx := FakeCtx.new()
	ctx.player.at = pos
	ctx.player.state.velocity = vel
	lock.ctx = ctx
	lock.row = {"lock": {"radius_m": radius}}
	lock.lock_centre = CENTRE
	lock._hold_ball()
	lock.free()
	return {"accel": ctx.player.accel, "set_to": ctx.player.set_to}


func _spring(t) -> void:
	for row in SPRING_ROWS:
		var stage := _stage_hold(row[1], row[2], row[3])
		t.eq("yard wall, %s" % row[0], stage["accel"], row[4])
		t.eq("yard wall sets no speed, %s" % row[0], stage["set_to"], null)
		t.eq("beacon fence, %s" % row[0], EncounterEngine._perimeter_spring_accel(row[1], row[2], CENTRE, row[3]), row[5])
	for row in DIAGONALS:
		t.eq("yard wall and beacon fence agree at %s" % row[0],
			_stage_hold(row[0], row[1], 10.0)["accel"],
			EncounterEngine._perimeter_spring_accel(row[0], row[1], CENTRE, 10.0))
	var bounce := _stage_hold(Vector3(19.0, 0.0, -2.0), Vector3(5.0, 0.0, 0.0), 10.0)
	t.eq("yard wall past its slack bounces an outward ball", bounce["set_to"], Vector3(-3.0, 0.0, 0.0))
	t.eq("yard wall past its slack adds no pull", bounce["accel"], Vector3.ZERO)
	t.eq("beacon fence pulls the same ball at the cap",
		EncounterEngine._perimeter_spring_accel(Vector3(19.0, 0.0, -2.0), Vector3(5.0, 0.0, 0.0), CENTRE, 10.0),
		Vector3(-120.0, 0.0, 0.0))
	var nan_vel := Vector3(NAN, 0.0, 0.0)
	t.eq("yard wall with a NaN speed keeps the spring alone",
		_stage_hold(Vector3(14.0, 0.0, -2.0), nan_vel, 10.0)["accel"], Vector3(-60.0, 0.0, 0.0))
	var fence_nan := EncounterEngine._perimeter_spring_accel(Vector3(14.0, 0.0, -2.0), nan_vel, CENTRE, 10.0)
	t.check("beacon fence with a NaN speed pulls NaN", is_nan(fence_nan.x) and is_nan(fence_nan.y) and is_nan(fence_nan.z), str(fence_nan))


func _config_without(t, fields: Dictionary) -> Resource:
	var script := GDScript.new()
	var source := "extends Resource\n"
	for key in fields:
		source += "var %s\n" % key
	script.source_code = source
	t.eq("the stand-in config with only %s compiles" % ", ".join(fields.keys()), script.reload(), OK)
	var res: Resource = script.new()
	for key in fields:
		res.set(key, fields[key])
	return res


func _cruise_fallbacks(t) -> void:
	t.eq("a fresh director config cruises at 14", AdversityDirectorConfig.new().default_cruise_mps, 14.0)

	var tremor := {&"subterranean_tremor": {"radius_m": 48.0, "tremor_lateral_accel": 10.0, "warning_s": 1.0,
		"ramp_s": 1.0, "recede_s": 1.0, "credit_cost": 1.0}}
	var director := AdversityDirector.new(7, &"", 1.0, _config_without(t, {"hazard_configs": tremor, "fast_speed_ratio": 0.5}))
	director.start_hazard(&"subterranean_tremor", Vector3.ZERO)
	director.hazard_phase = AdversityDirector.HazardPhase.PEAK
	var slow := director.compute_tremor_force(Vector3.ZERO, Vector3(6.99, 0.0, 0.0))
	var fast := director.compute_tremor_force(Vector3.ZERO, Vector3(7.0, 0.0, 0.0))
	t.check("a director with no cruise in its config reads 14: under 7 m/s the tremor pushes in full",
		slow.length() > fast.length() * 2.0, "%s vs %s" % [slow, fast])

	var kill_defaults := []
	for method in EncounterEngine.new(1).get_method_list():
		if method["name"] == "report_encounter_kill":
			kill_defaults = method["default_args"]
	t.eq("a reported kill defaults to a ball at 14 against a cruise of 14", kill_defaults, [14.0, 14.0])

	var setpieces := DynamicSetpieces.new()
	t.eq("set pieces cruise at 14 before setup", setpieces.cruise_speed, 14.0)
	setpieces.free()

	var cooled := []
	for speed in [14.0, 10.0, 20.0]:
		var synergies := JuryRigSynergies.new()
		synergies.heat = 30.0
		synergies.step(1.0, speed)
		cooled.append(30.0 - synergies.heat)
	t.eq("airflow cools 9 heat a second from 14 m/s, 5.5 at 10 and 9 at 20", cooled, [9.0, 5.5, 9.0])

	var actors := LiveWorldActors.new()
	t.eq("live actors with no run read a cruise of 14", actors._cruise(), 14.0)
	actors.free()


func _warning_floors(t) -> void:
	var cfg := RefurbishedEliteConfig.new()
	cfg.tell_s = 0.2
	var spec := cfg.to_spec_dict()
	t.eq("an elite config tells for at least 0.6 s", spec["tell_s"], 0.6)
	cfg.tell_s = 0.9
	t.eq("an elite config keeps a longer tell", cfg.to_spec_dict()["tell_s"], 0.9)

	spec["tell_s"] = 0.2
	spec["ability_radius_m"] = 8.0
	var elite = RefurbishedElites.RefurbishedInstance.new(spec, "pin", Vector3.ZERO)
	elite.cooldown_left = 0.0
	var tick: Dictionary = elite.step(0.1, Vector3.ZERO, Vector3.ZERO, 14.0)
	t.eq("an elite with a 0.2 s tell telegraphs for 0.6 s", [elite.phase, elite.phase_timer], [&"telegraph", 0.6])
	t.eq("its telegraph fact says 0.6 s", (tick["facts"] as Array).map(func(f): return f["tell_s"]), [0.6])

	var catalog := EncounterCatalogConfig.new()
	catalog.random_specs = {&"pin_rush": {"tell_s": 0.2, "display_name": "Pin rush"}}
	var engine := EncounterEngine.new(1, catalog)
	var result := {"facts": []}
	engine._start_random_encounter(&"pin_rush", {}, result)
	t.eq("a random encounter with a 0.2 s tell telegraphs for 0.6 s",
		[engine.active_random["timer_s"], result["facts"][0]["tell_s"]], [0.6, 0.6])

	var hazards := {&"pin_flood": {"radius_m": 10.0, "warning_s": 0.2, "ramp_s": 1.0, "recede_s": 1.0,
		"credit_cost": 1.0, "display_name": "Pin flood"}}
	var director := AdversityDirector.new(7, &"", 1.0, _config_without(t, {"hazard_configs": hazards}))
	director.start_hazard(&"pin_flood", Vector3.ZERO)
	var phases := []
	for step in [0.55, 0.1]:
		director._step_hazard(step, Vector3.ZERO, Vector3.ZERO, true, 14.0, {"facts": [], "env_tags": []})
		phases.append(director.hazard_phase)
	t.eq("a hazard with a 0.2 s warning warns until 0.6 s",
		phases, [AdversityDirector.HazardPhase.WARNING, AdversityDirector.HazardPhase.RAMP])
