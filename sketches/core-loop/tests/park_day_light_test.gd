extends SceneTree

# The park's Dig stages (open pit at noon, sinkhole open to the sky) show their time of day: the
# park override gives them an open sky, no underground air and the standing weather row's fog, and
# leaves every other stage and the legacy no-map look as they were.

const T := preload("res://tests/support/t.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")

const EXPECTED_CHECKS := 37
# Provisional cap (#241 comment 6333015981): x 1.34 came from a light-to-floor fit on 3060 stills
# (#241 comment 6328587862) whose park ground was Terrain3D's untextured checkerboard. On sand the
# step is 8.3 L* at this cap (#241 comment 6334779159); the wave 19 exposure unit re-derives it
# (#241 comment 6334820540). The step that read as a jump to white was x 2.2.
const MAX_NOON_STEP := 1.34
var _t := T.new("park_day_light_test")


func _initialize() -> void:
	call_deferred("_run")


func _standing_fog(map: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % map))
	for row in data.weather_rows:
		if row.trigger.on == "always":
			return row.fog
	return {}


func _run() -> void:
	var times := {3: WorldLook.TIME_ROWS.noon, 4: WorldLook.TIME_ROWS.afternoon}
	for stage in [3, 4]:
		var map: String = ParkDefs.of(stage).map
		var look := WorldLook.stage_look(stage, 2, map)
		var fog := _standing_fog(map)
		_t.eq(map + " sky is open", look.sky, "hdri")
		_t.check(map + " has no volumetric air", look.air.is_empty())
		_t.near(map + " sun is the time row's", look.sun_energy, times[stage].sun_energy)
		_t.near(map + " ambient is the time row's", look.energy, times[stage].energy)
		_t.near(map + " fog density is the standing weather's", look.fog.density, float(fog.density))
		_t.eq(map + " fog colour is the standing weather's", look.fog.color, Color(String(fog.color)))
		_t.eq(map + " keeps the dig name", look.name, "dig")
		_t.eq(map + " keeps the dig exposure", look.exposure, WorldLook.ROWS[2].exposure)
		var values := WorldLook.environment(look, true)
		_t.eq(map + " draws the sky", values.background_mode, Environment.BG_SKY)
		_t.eq(map + " has no volumetric fog", values.volumetric_fog_enabled, false)
		_t.check(map + " differs from the legacy dome look (planted negative)", WorldLook.stage_look(stage, 2).sky == "dome"
			and WorldLook.stage_look(stage, 2).fog.density != look.fog.density)
	_t.near("the pit's noon sun is 1.4", WorldLook.stage_look(3, 2, "park_pit").sun_energy, 1.4)
	_t.near("the sinkhole's afternoon sun is 1.7", WorldLook.stage_look(4, 2, "park_sinkhole").sun_energy, 1.7)
	var ground := []
	for stage in range(1, 7):
		var def := ParkDefs.of(stage)
		var look := WorldLook.stage_look(stage, def.world, def.map)
		ground.append(look.sun_energy * sin(deg_to_rad(-look.sun_rotation.x)) + look.energy)
	_t.check("the ground's light rises to noon and falls after", ground[0] < ground[1] and ground[1] < ground[2]
		and ground[2] > ground[3] and ground[3] > ground[4] and ground[4] > ground[5], str(ground))
	_t.check("noon is at most morning x %.2f" % MAX_NOON_STEP, ground[2] <= ground[1] * MAX_NOON_STEP, "%.3f / %.3f" % [ground[2], ground[1]])
	_t.near("the pit ambient is 0.32", WorldLook.stage_look(3, 2, "park_pit").energy, 0.32)
	_t.near("the sinkhole ambient is 0.29", WorldLook.stage_look(4, 2, "park_sinkhole").energy, 0.29)
	var legacy := WorldLook.stage_look(3, 2)
	_t.eq("legacy stage 3 keeps the dome", legacy.sky, "dome")
	_t.near("legacy sun is the dimmed key", legacy.sun_energy, 0.7)
	_t.near("legacy ambient is 0.12", legacy.energy, 0.12)
	_t.near("legacy fog is 0.018", legacy.fog.density, 0.018)
	for stage in [1, 2, 5, 6]:
		var def := ParkDefs.of(stage)
		_t.check("stage %d (%s) takes no override" % [stage, def.map], WorldLook.stage_look(stage, def.world, def.map) == WorldLook.stage_look(stage, def.world))
	_t.check("a legacy map id takes no override", WorldLook.stage_look(3, 2, "dig_1") == legacy)
	_t.eq("every check ran", _t.checks, EXPECTED_CHECKS)
	quit(_t.verdict())
