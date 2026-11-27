extends RefCounted

const Palette := preload("res://src/core/palette.gd")

const ROWS := {
	1: {"name": "spillway", "sky": "hdri", "background": Color("243b43"),
		"ambient": Color("9db5cf"), "energy": 0.28, "exposure": 1.1, "saturation": 1.2,
		"fog": {"color": Color("9cb6c8"), "density": 0.0006, "aerial_perspective": 0.58},
		"sun_color": Color("ffd49a"), "sun_energy": 2.35, "sun_rotation": Vector3(-36.0, -55.0, 0.0),
		"sun_visible": true, "fill": 0.5, "fill_pitch": -50.0, "fill_color": Color("a3c4e6"),
		"air": {"volumetric_fog_density": 0.0016, "volumetric_fog_albedo": Color("dcd4c6"),
			"volumetric_fog_emission": Color("000000"), "volumetric_fog_anisotropy": 0.55,
			"volumetric_fog_length": 220.0, "volumetric_fog_ambient_inject": 0.18, "volumetric_fog_sky_affect": 0.0}},
	2: {"name": "dig", "sky": "dome", "background": Color("0a1018"),
		"ambient": Color("587496"), "energy": 0.12, "exposure": 1.12, "saturation": 1.22,
		"fog": {"color": Color("3f546b"), "density": 0.018},
		"sun_color": Color("ffcb88"), "sun_energy": 0.7, "sun_rotation": Vector3(-36.0, -55.0, 0.0),
		"sun_visible": true, "fill": 0.18, "fill_pitch": -50.0, "fill_color": Color("7ea8d8"),
		"air": {"volumetric_fog_density": 0.018, "volumetric_fog_albedo": Color("486078"),
			"volumetric_fog_emission": Color("04080e"), "volumetric_fog_anisotropy": 0.28,
			"volumetric_fog_length": 125.0, "volumetric_fog_ambient_inject": 0.2, "volumetric_fog_sky_affect": 0.0},
		"lamps": {"count": 6, "energy": 5.2, "range": 34.0, "attenuation": 0.95, "every": 0.25}},
	3: {"name": "highdraft", "sky": "hdri", "background": Color("1f3444"),
		"ambient": Color("ece7da"), "energy": 0.28, "exposure": 1.08, "saturation": 1.24,
		"fog": {},
		"sun_color": Color("ffa35c"), "sun_energy": 1.9, "sun_rotation": Vector3(-16.0, 20.0, 0.0),
		"sun_visible": true, "fill": 0.46, "fill_pitch": -40.0, "fill_color": Color("96aec4"), "haze": Color("6d86a0"), "cloud": Color("ece7da"),
		"air": {"volumetric_fog_density": 0.0022, "volumetric_fog_albedo": Color("ffebd0"),
			"volumetric_fog_emission": Color("000000"), "volumetric_fog_anisotropy": 0.68,
			"volumetric_fog_length": 300.0, "volumetric_fog_ambient_inject": 0.26, "volumetric_fog_sky_affect": 0.0}},
}
const PARK_ROWS := {
	2: {"sky": "hdri", "fill": 0.42, "fill_pitch": -46.0, "fill_color": Color("7ea6d6"), "saturation": 1.24, "air": {}},
}
const PARK_DIR := "res://src/world/park/"
static var _park_fog := {}
const ARENAS := {
	"waking": {"name": "waking", "sky": "dome", "background": Color("101922"),
		"ambient": Color("6e88a6"), "energy": 0.16, "exposure": 1.14, "saturation": 1.26,
		"fog": {"color": Color("182532"), "density": 0.0075, "light_energy": 0.36, "sun_scatter": 0.0},
		"sun_color": Color("ffd49a"), "sun_energy": 2.35, "sun_rotation": Vector3(-36.0, -55.0, 0.0),
		"sun_visible": false, "fill": 0.5, "fill_pitch": -50.0, "fill_color": Color("8db4dc"),
		"key": Color("b6cade"), "floor_accent": Palette.AMBER,
		"air": {"volumetric_fog_density": 0.022, "volumetric_fog_albedo": Color("425b70"),
			"volumetric_fog_emission": Color("04080e"), "volumetric_fog_anisotropy": 0.42,
			"volumetric_fog_length": 95.0, "volumetric_fog_ambient_inject": 0.15, "volumetric_fog_sky_affect": 0.0}},
	"mind": {"name": "mind", "sky": "own", "background": Color("1a2638"),
		"ambient": Color("9097bd"), "energy": 0.30, "exposure": 1.16, "saturation": 1.22,
		"fog": {},
		"sun_color": Color("ffc68a"), "sun_energy": 2.25, "sun_rotation": Vector3(-14.0, 60.0, 0.0),
		"sun_visible": true, "fill": 0.48, "fill_pitch": -40.0, "fill_color": Color("7f88c8"),
		"seam_accent": Palette.ANCIENT, "air": {},
		"grade": {"top": Color("4c52a6"), "horizon": Color("ffae6e"), "recolor": 0.52, "highlight": 2.2,
			"glow": Color("c8682c"), "energy": 0.95}},
}
const BOWL_SCRIPT := "res://src/boss/arena.gd"
const DAYLIT_ARENAS := {"brindle": {"world": 1, "time": "noon", "over": {
	"sun_color": Color("ffe5b6"), "ambient": Color("e6dac2"), "fog_tint": Color("e8d2a8"),
	"exposure": 1.03, "saturation": 1.15,
	"grade": {"top": Color("f0e6d2"), "horizon": Color("ffe2af"), "recolor": 0.2, "highlight": 8.0,
		"glow": Color("4a2c10"), "energy": 1.05},
	"fog": {"color": Color("b89c74"), "density": 0.0018, "aerial_perspective": 0.30}, "fill_color": Color("c9b898")}}}
const CAMP := {"name": "camp", "sky": "hdri", "background": Color("243b43"),
	"ambient": Color("c9c0a8"), "energy": 0.3, "exposure": 1.08, "saturation": 1.15,
	"fog": {"color": Color("d9c5a0"), "density": 0.0005},
	"sun_color": Color("ffc88a"), "sun_energy": 2.2, "sun_rotation": Vector3(-30.0, -35.0, 0.0),
	"sun_visible": true, "fill": 0.45, "fill_pitch": -45.0, "fill_color": Color("a9b6c0"), "air": {},
	"time": "afternoon", "grade": {"top": Color("fbf6ee"), "horizon": Color("ffe6c4"), "recolor": 0.1, "highlight": 8.0,
		"glow": Color("2c1e0e"), "energy": 1.0}}
const TITLE := {"energy": ROWS[1]["energy"], "sun_energy": ROWS[1]["sun_energy"], "sun_rotation": ROWS[1]["sun_rotation"],
	"fill": ROWS[1]["fill"], "background": Color("3a2a2e"), "ambient": Color("9db5cf"), "exposure": 1.1, "contrast": 1.25,
	"sun_color": Color("ffb27a"), "fill_rotation": Vector3(-50.0, 125.0, 0.0), "fill_color": Color("a3c4e6"),
	"lamp_color": Palette.AMBER, "lamp_energy": 2.2}
const ENDING := {"sky": "workshop", "energy": 0.9, "fog": 0.0008, "sun_energy": 1.2, "sun_rotation": Vector3(-38.0, 118.0, 0.0)}
const PREVIEW := {"energy": 0.6, "sun_energy": 1.4, "sun_rotation": Vector3(-48.0, 32.0, 0.0),
	"rim_energy": 1.6, "rim_rotation": Vector3(-20.0, 200.0, 0.0)}
const NODE := "WorldLook"

const TIME_ORDER := ["dawn", "morning", "noon", "afternoon", "golden", "dusk"]
const STAGE_TIME := {1: "dawn", 2: "morning", 3: "noon", 4: "afternoon", 5: "golden", 6: "dusk"}
const TIME_ROWS := {
	"dawn": {"sun_rotation": Vector3(-8.0, -100.0, 0.0), "sun_color": Palette.APRICOT, "sun_energy": 1.4,
		"ambient": Palette.DAWN_VIOLET, "energy": 0.22, "fog_tint": Color("e8bcc4"),
		"grade": {"top": Color("8486cc"), "horizon": Color("ffbc94"), "recolor": 0.4, "highlight": 1.5,
			"glow": Color("b8683a"), "energy": 0.8}},
	"morning": {"sun_rotation": Vector3(-28.0, -70.0, 0.0), "sun_color": Color("ffd09a"), "sun_energy": 2.0,
		"ambient": Palette.TURQUOISE, "energy": 0.26, "fog_tint": Color("d2eee8"),
		"grade": {"top": Color("d4f4f0"), "horizon": Color("f5d4c3"), "recolor": 0.2, "highlight": 8.0,
			"glow": Color("3a2414"), "energy": 1.0}},
	"noon": {"sun_rotation": Vector3(-62.0, -40.0, 0.0), "sun_color": Color("fff1dc"), "sun_energy": 1.4,
		"ambient": Color("dbe6ec"), "energy": 0.32, "fog_tint": Color("dfe6ea"),
		"grade": {"top": Color("ffffff"), "horizon": Color("ffffff"), "recolor": 0.0, "highlight": 65504.0,
			"glow": Color("000000"), "energy": 1.05}},
	"afternoon": {"sun_rotation": Vector3(-45.0, -15.0, 0.0), "sun_color": Color("ffd7a0"), "sun_energy": 1.7,
		"ambient": Color("c9c0a8"), "energy": 0.29, "fog_tint": Color("e6dcc8"),
		"grade": {"top": Color("fbf6ee"), "horizon": Color("ffe6c4"), "recolor": 0.1, "highlight": 8.0,
			"glow": Color("2c1e0e"), "energy": 1.0}},
	"golden": {"sun_rotation": Vector3(-16.0, 20.0, 0.0), "sun_color": Color("ffa35c"), "sun_energy": 1.9,
		"ambient": Color("e0b58a"), "energy": 0.25, "fog_tint": Color("f0b886"),
		"grade": {"top": Color("c9c2c8"), "horizon": Color("ffb47a"), "recolor": 0.45, "highlight": 2.0,
			"glow": Color("c8652a"), "energy": 1.25, "away_lift": 0.5}},
	"dusk": {"sun_rotation": Vector3(-6.0, 60.0, 0.0), "sun_color": Color("e06f4a"), "sun_energy": 1.1,
		"ambient": Color("5d6b86"), "energy": 0.16, "fog_tint": Color("8a7a9e"),
		"grade": {"top": Color("4c5290"), "horizon": Color("e88a6a"), "recolor": 0.6, "highlight": 1.0,
			"glow": Color("b04a26"), "energy": 0.6}},
}
const WEATHER_SKY := {
	"clear": {"cloud": 0.0, "tint": Color("ffffff")},
	"dust": {"cloud": 0.1, "tint": Color("c9a36b")},
	"storm_build": {"cloud": 0.6, "tint": Color("6b7480")},
}
const LOOK_ROWS := {
	"dam_night": {"sun_rotation": Vector3(-40.0, 150.0, 0.0), "sun_color": Color("8fa8dc"), "sun_energy": 0.45,
		"ambient": Color("4e6394"), "energy": 0.26, "fog_tint": Color("1f3152"), "fog_color": Color("24344f"),
		"fill": 0.22, "fill_color": Color("5a72a8"),
		"grade": {"top": Color("0c1630"), "horizon": Color("24405e"), "recolor": 0.8, "highlight": 1.0,
			"glow": Color("152436"), "energy": 0.35},
		"floods": {"model": "res://assets/models/camp/camp_lamp_post.glb", "socket": "light_0", "scale": 1.5,
			"card_m": 2.2, "fade_m": 450.0,
			"at": [[-30, -579, 0], [-184, -568, 11], [-117, -515, 79], [-33, -462, 247], [-114, -412, 146], [-117, -322, 79],
				[-14, -298, 315], [-237, -475, 146], [97, -593, 315], [-24, 168, 79], [70, 30, 270], [-149, 8, 113]],
			"lamps": {"color": Palette.SODIUM, "count": 6, "energy": 6.0, "range": 36.0, "attenuation": 0.9, "drop": 0.4, "every": 0.25},
			"dam": {"at": [[-70.0, 118.0, 632.0], [0.0, 124.0, 632.0], [70.0, 118.0, 632.0]], "aim_z": 470.0,
				"color": Palette.SODIUM, "energy": 4.0, "range": 260.0, "angle": 24.0}},
		"seams": {"energy": 6.0}},
}
const DISTRICT_GRADES := {
	"dam_intake": {"time": "dawn", "ambient": Color("a8a6e6"), "fog_tint": Color("d8c8dc"),
		"grade": {"top": Color("7088d8"), "horizon": Color("ffcaa8"), "glow": Color("a8704a")},
		"exposure_add": -0.04, "saturation_add": -0.05},
	"dam_apron": {"time": "dawn", "ambient": Color("b2a6d6"), "fog_tint": Color("f2c2b4"),
		"grade": {"top": Color("908ac0"), "horizon": Color("ffb284"), "glow": Color("c87238")},
		"exposure_add": -0.03, "saturation_add": -0.03},
	"dam_pump": {"time": "dawn", "ambient": Color("9292c8"), "fog_tint": Color("c6b8ca"),
		"grade": {"top": Color("6872aa"), "horizon": Color("f2ae92"), "glow": Color("925a3a")},
		"exposure_add": -0.08, "saturation_add": -0.08},
	"flume_weir": {"time": "morning", "ambient": Color("92c6da"), "fog_tint": Color("bedcea"),
		"grade": {"top": Color("c6eef6"), "horizon": Color("e6d0cc"), "glow": Color("261c18")},
		"exposure_add": -0.07, "saturation_add": -0.04},
	"flume_trestle": {"time": "morning", "ambient": Color("b4d4cc"), "fog_tint": Color("e2ecdc"),
		"grade": {"top": Color("dcf2ea"), "horizon": Color("f8ccb4"), "glow": Color("48280e")},
		"exposure_add": -0.05, "saturation_add": -0.05},
	"flume_headhouse": {"time": "morning", "ambient": Color("aad6e2"), "fog_tint": Color("e4f2ee"),
		"grade": {"top": Color("a8d8f0"), "horizon": Color("fae0c0"), "glow": Color("3c2a10")},
		"exposure_add": -0.04, "saturation_add": -0.02},
}
const DISTRICT_EVERY_S := 0.25
const DISTRICT_BLEND_S := 1.5
const CONSUMED_HOLDS_HUE := true
const CONSUMED_GLOW := {"color": Color("d936b0"), "energy": 1.0, "albedo_scale": 0.6}


static func consumed_material(albedo: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	if CONSUMED_HOLDS_HUE:
		var k: float = CONSUMED_GLOW.albedo_scale
		material.albedo_color = Color(albedo.r * k, albedo.g * k, albedo.b * k, albedo.a)
		material.emission_enabled = true
		material.emission = CONSUMED_GLOW.color
		material.emission_energy_multiplier = CONSUMED_GLOW.energy
	return material


static func reset_for_tests() -> void:
	_park_fog.clear()


static func row(world: int) -> Dictionary:
	return ROWS.get(world, {})


static func time_id(stage: int) -> String:
	return STAGE_TIME.get(stage, "")


static func time_row(stage: int) -> Dictionary:
	return TIME_ROWS.get(time_id(stage), {})


static func arena_look(id: String) -> Dictionary:
	if ARENAS.has(id):
		return ARENAS[id]
	var spec: Dictionary = DAYLIT_ARENAS.get(id, {})
	if spec.is_empty():
		return {}
	var look := row(spec.world).duplicate()
	look.merge(TIME_ROWS[spec.time], true)
	look.merge(spec.get("over", {}), true)
	look["name"] = id
	look["time"] = spec.time
	return look


static func park_fog(map: String, park_file := {}) -> Dictionary:
	if _park_fog.has(map):
		return _park_fog[map]
	var fog: Dictionary = ROWS[1].fog
	var data = park_file
	if park_file.is_empty():
		var file := FileAccess.open(PARK_DIR + map + ".json", FileAccess.READ)
		data = JSON.parse_string(file.get_as_text()) if file != null else null
	for weather in (data.get("weather_rows", []) if data is Dictionary else []):
		if weather.get("trigger", {}).get("on") == "always" and weather.get("fog", {}).has("density"):
			fog = {"density": float(weather.fog.density), "color": Color(String(weather.fog.color))}
			break
	_park_fog[map] = fog
	return fog


static func stage_look(stage: int, world: int, map := "", park_file := {}, look_id := "") -> Dictionary:
	var base := row(world)
	var look := base.duplicate()
	var park: Dictionary = PARK_ROWS.get(world, {}) if map.begins_with("park_") else {}
	if not park.is_empty():
		look.merge(park, true)
		look["fog"] = park_fog(map, park_file)
		base = look.duplicate()
	look.merge(time_row(stage), true)
	if not time_id(stage).is_empty():
		look["time"] = time_id(stage)
	if base.get("sky") == "dome":
		look.energy = base.energy
		look.sun_energy = base.sun_energy
	var variant: Dictionary = LOOK_ROWS.get(look_id, {})
	if not variant.is_empty():
		look.merge(variant, true)
		look["fog"] = {"density": float(look.fog.get("density", 0.0)), "color": variant.fog_color}
		look["look_id"] = look_id
	return look


static func district_look(base_look: Dictionary, grade_id: String) -> Dictionary:
	var spec: Dictionary = DISTRICT_GRADES.get(grade_id, {})
	if spec.is_empty() or base_look.get("time", "") != spec.time:
		return base_look
	var look := base_look.duplicate()
	look["exposure"] = float(base_look.get("exposure", 1.0)) + float(spec.exposure_add)
	look["saturation"] = float(base_look.get("saturation", 1.0)) + float(spec.saturation_add)
	look["district"] = grade_id
	if look.has("look_id"):
		return look
	look["ambient"] = spec.ambient
	look["fog_tint"] = spec.fog_tint
	var sky: Dictionary = base_look.get("grade", {}).duplicate()
	sky.merge(spec.grade, true)
	look["grade"] = sky
	return look


static func district_at(park_file: Dictionary, pos: Vector3) -> String:
	return DistrictGrade.district_in(park_file.get("district_rows", []), pos)


static func _record_fog(ctx) -> void:
	var game = ctx.root if ctx != null else null
	if game != null and game.get("world") != null and game.world.view != null:
		game.world.view.record_fog()


static func air_values(look: Dictionary, air: bool) -> Dictionary:
	var on: bool = air and not look.air.is_empty()
	var values := {"volumetric_fog_enabled": on}
	if on:
		values.merge(look.air)
	return values


static func follow_air(values: Dictionary, look: Dictionary, air: bool) -> void:
	values.erase("volumetric_fog_enabled")
	for key in look.air:
		values.erase(key)
	values.merge(air_values(look, air))


static func environment(look: Dictionary, air: bool) -> Dictionary:
	var fog: Dictionary = look.fog
	var values := {
		"ambient_light_source": Environment.AMBIENT_SOURCE_COLOR,
		"ambient_light_color": look.ambient, "ambient_light_energy": look.energy,
		"tonemap_exposure": look.exposure, "adjustment_saturation": look.saturation,
		"fog_enabled": true, "fog_light_energy": fog.get("light_energy", 0.75), "fog_sun_scatter": fog.get("sun_scatter", 0.25),
		"fog_aerial_perspective": float(fog.get("aerial_perspective", 0.0)),
	}
	values.merge(air_values(look, air))
	if fog.has("density"):
		values["fog_density"] = fog.density
		values["fog_light_color"] = fog.color
	if look.has("fog_tint") and look.sky != "dome":
		var haze: Color = fog.get("color", look.fill_color)
		values["fog_light_color"] = haze.lerp(look.fog_tint, 0.5)
	if look.sky == "dome":
		values["background_mode"] = Environment.BG_COLOR
		values["background_color"] = look.background
		values["fog_sky_affect"] = 0.0
		values["reflected_light_source"] = Environment.REFLECTION_SOURCE_DISABLED
	elif look.sky == "workshop" or look.sky == "hdri":
		values["background_mode"] = Environment.BG_SKY
		values["fog_sky_affect"] = 0.25
		if look.sky == "hdri":
			values["sky"] = Palette.hdri_sky()
	return values


static func grade(look: Dictionary) -> Dictionary:
	var spec: Dictionary = look.get("grade", {})
	if spec.is_empty():
		return {}
	var r: Vector3 = look.sun_rotation
	var toward_sun := Basis.from_euler(Vector3(deg_to_rad(r.x), deg_to_rad(r.y), 0.0)).z
	return {"shader_parameter/top_tint": spec.top, "shader_parameter/horizon_tint": spec.horizon,
		"shader_parameter/recolor": spec.recolor, "shader_parameter/highlight": spec.highlight,
		"shader_parameter/glow": spec.glow, "shader_parameter/sun_dir": toward_sun,
		"shader_parameter/energy": spec.energy, "shader_parameter/away_lift": spec.get("away_lift", 0.0)}


static func sky_rows(look: Dictionary) -> Array:
	var values := grade(look)
	if values.is_empty() or look.get("sky") != "hdri":
		return []
	return [{"object": Palette.hdri_sky().sky_material, "values": values}]


static func lights(look: Dictionary, sun: DirectionalLight3D) -> Array:
	var result := []
	if sun == null:
		return result
	var r: Vector3 = look.sun_rotation
	result.append({"object": sun, "values": {"light_color": look.sun_color, "light_energy": look.sun_energy,
		"visible": look.sun_visible, "rotation": Vector3(deg_to_rad(r.x), deg_to_rad(r.y), 0.0)}})
	var fill := sun.get_parent().get_node_or_null("SkyFill") as DirectionalLight3D if sun.get_parent() != null else null
	if fill != null:
		result.append({"object": fill, "values": {"light_energy": look.fill, "light_color": look.fill_color,
			"visible": look.sun_visible, "rotation": Vector3(deg_to_rad(look.fill_pitch), deg_to_rad(r.y + 180.0), 0.0)}})
	return result


static func hook(ctx) -> void:
	ctx.events.stage_entered.connect(_on_stage_entered.bind(ctx))
	ctx.events.boss_arena_entered.connect(_on_arena_entered.bind(ctx))


static func _on_arena_entered(ctx) -> void:
	var boss = ctx.get("boss") if "boss" in ctx else ctx.get_meta("boss", null)
	var arena = boss.get("arena") if boss != null else null
	if not is_instance_valid(arena) or arena.get_script() == null or arena.get_script().resource_path != BOWL_SCRIPT:
		return
	if ctx.terrain == null or ctx.terrain.environment == null:
		return
	load("res://src/presentation/graphics_preset.gd").enter_world(arena, ctx.terrain.environment, arena_look("brindle"), "arena")


static func _on_stage_entered(stage: int, _retry: bool, ctx) -> void:
	var terrain = ctx.terrain
	if terrain == null or terrain.environment == null:
		return
	var root: Node3D = terrain.geometry_root(stage)
	var world: int = ctx.stages.world_of(stage)
	var GraphicsPreset := load("res://src/presentation/graphics_preset.gd")
	var loaded = terrain.map_for(stage)
	var look_id: String = ctx.flow.stage_look_id() if ctx.get("flow") != null else ""
	var park: Dictionary = loaded.park if loaded != null and "park" in loaded else {}
	var look := stage_look(stage, world, String(ctx.stages.of(stage).get("map", "")), park, look_id)
	GraphicsPreset.enter_world(root, terrain.environment, look)
	NightShift.enter(root, terrain, look, ctx.player)
	_record_fog(ctx)
	DistrictGrade.attach(root, park, look, ctx)
	if look.has("lamps") and ctx.player != null:
		var pool := LampPool.find(root)
		if pool == null:
			pool = LampPool.new()
			pool.name = "LampPool"
			pool.setup(look.lamps, root, ctx.player)
			root.get_node(NODE).add_child(pool)


class LampPool extends Node3D:
	var _spec: Dictionary
	var _stage: Node3D
	var _player
	var _lamps := PackedVector3Array()
	var _lights: Array[OmniLight3D] = []
	var _wait := 0.0

	static func find(stage_root: Node) -> Node:
		var holder := stage_root.get_node_or_null(NODE)
		return holder.get_node_or_null("LampPool") if holder != null else null

	func setup(spec: Dictionary, stage_root: Node3D, player) -> void:
		_spec = spec
		_stage = stage_root
		_player = player
		var colour: Color = load("res://src/presentation/dig_scenery.gd").LAMP_LIGHT
		for i in int(spec.count):
			var light := OmniLight3D.new()
			light.name = "Lamp%d" % i
			light.light_color = colour
			light.light_energy = spec.energy
			light.omni_range = spec.range
			light.omni_attenuation = spec.attenuation
			light.shadow_enabled = false
			light.light_specular = 0.2
			light.visible = false
			add_child(light)
			_lights.append(light)

	func _process(delta: float) -> void:
		_wait -= delta
		if _wait > 0.0 or not is_visible_in_tree():
			return
		_wait = _spec.every
		if _lamps.is_empty():
			for view in _stage.find_children("*", "MultiMeshInstance3D", true, false):
				if view.has_meta("origins") and String(view.name).contains("lamp"):
					var origins: PackedVector3Array = view.get_meta("origins")
					for at in origins:
						_lamps.append(view.global_transform * at)
		if _lamps.is_empty() or _player == null:
			return
		var ball: Vector3 = _player.shown_position()
		var order := Array(_lamps)
		order.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(ball) < b.distance_squared_to(ball))
		for i in _lights.size():
			_lights[i].visible = i < order.size()
			if i < order.size():
				_lights[i].global_position = order[i] + Vector3.DOWN * 1.5


class DistrictGrade extends Node3D:
	const NAME := "DistrictGrade"
	const LOOK := "res://src/presentation/world_look.gd"

	var _rows: Array = []
	var _base: Dictionary = {}
	var _ctx
	var _look: GDScript
	var _grade := ""
	var _started := false
	var _from: Dictionary = {}
	var _to: Dictionary = {}
	var _shown: Dictionary = {}
	var _blend := 1.0
	var _wait := 0.0

	static func attach(stage_root: Node3D, park: Dictionary, look: Dictionary, ctx) -> void:
		var holder := stage_root.get_node_or_null(NODE)
		var grade := holder.get_node_or_null(NAME) as DistrictGrade if holder != null else null
		var rows: Array = park.get("district_rows", [])
		if rows.is_empty() or holder == null or ctx == null or ctx.player == null:
			if grade != null:
				holder.remove_child(grade)
				grade.queue_free()
			return
		if grade == null:
			grade = DistrictGrade.new()
			grade.name = NAME
			holder.add_child(grade)
		grade.start(rows, look, ctx)

	func start(rows: Array, look: Dictionary, ctx) -> void:
		_rows = rows
		_base = look
		_ctx = ctx
		_look = load(LOOK)
		_shown = look
		_from = look
		_to = look
		_grade = ""
		_started = false
		_blend = 1.0
		_wait = 0.0
		set_process(true)

	func grade_id() -> String:
		return _grade

	func _process(delta: float) -> void:
		_wait -= delta
		if _wait > 0.0:
			return
		_wait = DISTRICT_EVERY_S
		step()

	func step() -> void:
		if not is_visible_in_tree() or _ctx == null or not is_instance_valid(_ctx.player):
			return
		var environment: Environment = _ctx.terrain.environment if _ctx.terrain != null else null
		if environment == null or not _on_top(environment):
			return
		var grade := district_in(_rows, _ctx.player.shown_position())
		if not _started:
			_started = true
			_grade = grade
			_to = _look.district_look(_base, grade)
			_blend = 1.0
			_show(environment, _to)
			return
		if grade != _grade:
			_grade = grade
			_from = _shown
			_to = _look.district_look(_base, grade)
			_blend = 0.0
		if _blend >= 1.0:
			return
		_blend = minf(1.0, _blend + DISTRICT_EVERY_S / DISTRICT_BLEND_S)
		_show(environment, _to if _blend >= 1.0 else mix(_from, _to, _blend))

	static func district_in(rows: Array, pos: Vector3) -> String:
		var at := Vector2(pos.x, pos.z)
		for row in rows:
			var r = row.get("rect") if row is Dictionary else null
			if r is Array and r.size() == 4 and Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).has_point(at):
				return String(row.get("grade", ""))
		return ""

	func _on_top(environment: Environment) -> bool:
		return environment.ambient_light_color == _shown.ambient and is_equal_approx(environment.tonemap_exposure, float(_shown.exposure))

	func _show(environment: Environment, look: Dictionary) -> void:
		load("res://src/presentation/graphics_preset.gd").enter_world(get_parent().get_parent(), environment, look)
		_shown = look
		_look._record_fog(_ctx)

	static func mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
		var look := b.duplicate()
		look["ambient"] = (a.ambient as Color).lerp(b.ambient, t)
		look["exposure"] = lerpf(float(a.exposure), float(b.exposure), t)
		look["saturation"] = lerpf(float(a.saturation), float(b.saturation), t)
		if a.has("fog_tint") and b.has("fog_tint"):
			look["fog_tint"] = (a.fog_tint as Color).lerp(b.fog_tint, t)
		var from_sky: Dictionary = a.get("grade", {})
		var sky: Dictionary = b.get("grade", {}).duplicate()
		for key in ["top", "horizon", "glow"]:
			if from_sky.has(key) and sky.has(key):
				sky[key] = (from_sky[key] as Color).lerp(sky[key], t)
		look["grade"] = sky
		return look


# Light3D freed with a stage crashes Godot 4.7.2 Forward+ on the next boss entry.
class NightShift extends Node3D:
	const DRESS := "NightDress"
	const LIGHTS := "NightLights"
	const SEAM_SLOT := "night"
	const SEAM_SURFACE := "ancient_lens"
	const SEAM_TRIES := 40
	const SEAM_EVERY_S := 0.5

	var _spec: Dictionary
	var _player
	var _heads := PackedVector3Array()
	var _pool: Array[OmniLight3D] = []
	var _dam: Array[SpotLight3D] = []
	var _wait := 0.0

	static func enter(stage_root: Node3D, terrain, look: Dictionary, player) -> void:
		var host := stage_root.get_parent()
		var holder := stage_root.get_node_or_null(NODE)
		var dress := holder.get_node_or_null(DRESS) if holder != null else null
		var lights := host.get_node_or_null(LIGHTS) as NightShift if host != null else null
		var spec: Dictionary = look.get("floods", {})
		if spec.is_empty() or holder == null or host == null:
			if dress != null:
				holder.remove_child(dress)
				dress.queue_free()
			if lights != null:
				lights.go_dark()
			return
		if dress == null:
			dress = Dress.new()
			dress.name = DRESS
			holder.add_child(dress)
			dress.build(look, terrain)
		if lights == null:
			lights = NightShift.new()
			lights.name = LIGHTS
			host.add_child(lights)
		lights.light(spec, dress.heads(), player)

	func light(spec: Dictionary, heads: PackedVector3Array, player) -> void:
		_spec = spec
		_heads = heads
		_player = player
		var lamps: Dictionary = spec.lamps
		while _pool.size() < int(lamps.count):
			var omni := OmniLight3D.new()
			omni.name = "NightLamp%d" % _pool.size()
			omni.shadow_enabled = false
			omni.light_specular = 0.2
			add_child(omni)
			_pool.append(omni)
		for omni in _pool:
			omni.light_color = lamps.color
			omni.light_energy = lamps.energy
			omni.omni_range = lamps.range
			omni.omni_attenuation = lamps.attenuation
			omni.visible = false
		var dam: Dictionary = spec.dam
		while _dam.size() < (dam.at as Array).size():
			var spot := SpotLight3D.new()
			spot.name = "NightDamLamp%d" % _dam.size()
			spot.shadow_enabled = false
			spot.light_specular = 0.1
			add_child(spot)
			_dam.append(spot)
		for i in _dam.size():
			var spot := _dam[i]
			var at: Array = dam.at[i] if i < (dam.at as Array).size() else []
			spot.visible = not at.is_empty()
			if at.is_empty():
				spot.light_energy = 0.0
				continue
			var from := Vector3(at[0], at[1], at[2])
			spot.light_color = dam.color
			spot.light_energy = dam.energy
			spot.spot_range = dam.range
			spot.spot_angle = dam.angle
			spot.spot_attenuation = 0.6
			spot.global_transform = Transform3D(Basis.looking_at(Vector3(at[0] * 0.5, 0.0, dam.aim_z) - from), from)
		_wait = 0.0
		set_process(true)

	func go_dark() -> void:
		for omni in _pool:
			omni.visible = false
			omni.light_energy = 0.0
		for spot in _dam:
			spot.visible = false
			spot.light_energy = 0.0
		_heads = PackedVector3Array()
		set_process(false)

	func _process(delta: float) -> void:
		_wait -= delta
		if _wait > 0.0 or _heads.is_empty() or not is_instance_valid(_player):
			return
		_wait = _spec.lamps.every
		var ball: Vector3 = _player.shown_position()
		var order := Array(_heads)
		order.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(ball) < b.distance_squared_to(ball))
		for i in _pool.size():
			_pool[i].visible = i < order.size()
			if i < order.size():
				_pool[i].global_position = order[i] + Vector3.DOWN * float(_spec.lamps.drop)

	class Dress extends Node3D:
		var _heads := PackedVector3Array()
		var _seams := 0.0
		var _environment: Environment
		var _tries := 0
		var _next := 0.0

		func heads() -> PackedVector3Array:
			return _heads

		func build(look: Dictionary, terrain) -> void:
			var spec: Dictionary = look.floods
			var model := load(String(spec.model)) as PackedScene
			var card := _card(float(spec.card_m), spec.lamps.color)
			for i in (spec.at as Array).size():
				var row: Array = spec.at[i]
				var ground: float = terrain.height(float(row[0]), float(row[1])) if terrain != null else 0.0
				var mast := model.instantiate() as Node3D
				for node in mast.find_children("*-col", "", true, false):
					node.get_parent().remove_child(node)
					node.free()
				mast.name = "Mast%d" % i
				mast.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(row[2]))).scaled(Vector3.ONE * float(spec.scale)),
					Vector3(float(row[0]), ground, float(row[1])))
				for view: GeometryInstance3D in mast.find_children("*", "GeometryInstance3D", true, false):
					view.visibility_range_end = float(spec.fade_m)
					view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(mast)
				var socket := mast.find_child(String(spec.socket), true, false) as Node3D
				var head: Vector3 = socket.global_position if socket != null else mast.global_position + Vector3.UP * 6.0
				_heads.append(head)
				var glow := MeshInstance3D.new()
				glow.name = "Glow%d" % i
				glow.mesh = card
				glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				glow.visibility_range_end = float(spec.fade_m)
				add_child(glow)
				glow.global_position = head
			_seams = float(look.get("seams", {}).get("energy", 0.0))
			_environment = terrain.environment if terrain != null else null
			set_process(_seams > 0.0)

		func _process(delta: float) -> void:
			_next -= delta
			if _next > 0.0:
				return
			_next = SEAM_EVERY_S
			_tries += 1
			var stage_root := get_parent().get_parent()
			var placer := stage_root.get_node_or_null("ParkRows")
			if placer != null and placer.has_method("is_ready") and not placer.is_ready():
				if _tries >= SEAM_TRIES:
					set_process(false)
				return
			var rows := []
			var seen := {}
			for view: MeshInstance3D in stage_root.find_children("*", "MeshInstance3D", true, false):
				var mesh := view.mesh as ArrayMesh
				if mesh == null:
					continue
				for s in mesh.get_surface_count():
					var material := view.get_active_material(s) as StandardMaterial3D
					if material != null and material.emission_enabled and mesh.surface_get_name(s) == SEAM_SURFACE and not seen.has(material):
						seen[material] = true
						rows.append({"object": material, "values": {"emission_energy_multiplier": _seams}})
			if not rows.is_empty() and _environment != null:
				load("res://src/presentation/graphics_preset.gd").set_lighting(self, _environment, {}, rows, SEAM_SLOT)
			if not rows.is_empty() or _tries >= SEAM_TRIES:
				set_process(false)

		static func _card(size: float, colour: Color) -> QuadMesh:
			var fade := Gradient.new()
			fade.set_color(0, Color(colour, 1.0))
			fade.set_color(1, Color(colour, 0.0))
			var tex := GradientTexture2D.new()
			tex.gradient = fade
			tex.fill = GradientTexture2D.FILL_RADIAL
			tex.fill_from = Vector2(0.5, 0.5)
			tex.fill_to = Vector2(0.5, 0.0)
			tex.width = 64
			tex.height = 64
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			material.albedo_texture = tex
			material.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
			var quad := QuadMesh.new()
			quad.size = Vector2(size, size)
			quad.material = material
			return quad
