extends RefCounted

const Palette := preload("res://src/core/palette.gd")

# One light-and-air row per world (worlds.gd ids), per arena and per menu stage. Every layer that
# lights a place reads its row here: the stage hook, the arena dresses, the Highdraft finishes, the
# title, the ending and the class preview. Graphics presets hold quality knobs only.
#   sky: "workshop" the painted panorama, "hdri" the Poly Haven sky (Palette.hdri_sky), "own" the
#   stage or arena builds its sky, "dome" a colour background (no sky ridges).
#   fog: density and colour written when the row names them. The squall haze (event_view.gd) starts
#   from the fog the row left on the environment (record_fog after the row is entered); a row
#   without numbers leaves the environment's fog as it was.
#   air: the volumetric row entered with the world (P-LIGHT WORLD_AIR); empty is no air.
const ROWS := {
	1: {"name": "spillway", "sky": "hdri", "background": Color("243b43"),
		"ambient": Color("9db5cf"), "energy": 0.28, "exposure": 1.1, "saturation": 1.2,
		"fog": {"color": Color("a3bdd0"), "density": 0.0006},
		"sun_color": Color("ffd49a"), "sun_energy": 2.35, "sun_rotation": Vector3(-36.0, -55.0, 0.0),
		"sun_visible": true, "fill": 0.5, "fill_pitch": -50.0, "fill_color": Color("a3c4e6"),
		# A faint warm haze: the P-LIGHT row at 0.004 washed the factory toward sand.
		"air": {"volumetric_fog_density": 0.0012, "volumetric_fog_albedo": Color("e9d2a6"),
			"volumetric_fog_emission": Color("000000"), "volumetric_fog_anisotropy": 0.55,
			"volumetric_fog_length": 160.0, "volumetric_fog_ambient_inject": 0.2, "volumetric_fog_sky_affect": 0.0}},
	# Underground: a closed dark dome, low cool ambient, a dimmed shaft key and the lamp pool.
	2: {"name": "dig", "sky": "dome", "background": Color("0b0f12"),
		"ambient": Color("6d7f92"), "energy": 0.12, "exposure": 1.1, "saturation": 1.1,
		"fog": {"color": Color("56636f"), "density": 0.018},
		"sun_color": Color("e8dcc8"), "sun_energy": 0.7, "sun_rotation": Vector3(-36.0, -55.0, 0.0),
		"sun_visible": true, "fill": 0.15, "fill_pitch": -50.0, "fill_color": Color("a3c4e6"),
		"air": {"volumetric_fog_density": 0.018, "volumetric_fog_albedo": Color("56636f"),
			"volumetric_fog_emission": Color("06090d"), "volumetric_fog_anisotropy": 0.15,
			"volumetric_fog_length": 120.0, "volumetric_fog_ambient_inject": 0.2, "volumetric_fog_sky_affect": 0.0},
		"lamps": {"count": 6, "energy": 4.0, "range": 30.0, "attenuation": 1.1, "every": 0.25}},
	# The D2 sheet's surfaces and fill (highdraft_finishes.LOOK reads these). The Highdraft has no
	# fixed morning: its key is the run's late day, golden hour then dusk (TIME_ROWS), and the base
	# key here is the golden row's so a reader of the world row sees the same sun.
	3: {"name": "highdraft", "sky": "hdri", "background": Color("243b43"),
		"ambient": Color("ece7da"), "energy": 0.28, "exposure": 1.05, "saturation": 1.15,
		"fog": {},
		"sun_color": Color("ffa35c"), "sun_energy": 1.9, "sun_rotation": Vector3(-16.0, 20.0, 0.0),
		"sun_visible": true, "fill": 0.5, "fill_pitch": -40.0, "fill_color": Color("a9b6c0"), "haze": Color("798c9e"), "cloud": Color("ece7da"),
		"air": {"volumetric_fog_density": 0.0025, "volumetric_fog_albedo": Color("fff1dc"),
			"volumetric_fog_emission": Color("000000"), "volumetric_fog_anisotropy": 0.6,
			"volumetric_fog_length": 300.0, "volumetric_fog_ambient_inject": 0.3, "volumetric_fog_sky_affect": 0.0}},
}
# What a park map changes in its world's row (stage_look with a "park_" map id). The park's Dig
# stages are an open pit at noon and a sinkhole open to the sky (PARK.md), not the legacy
# underground dome: the Spillway's open-sky fill, no volumetric murk (the weather rows carry the air),
# and the fog density set per map from the standing weather row (park_fog), so it does not pop when that row lands.
const PARK_ROWS := {
	2: {"sky": "hdri", "fill": ROWS[1]["fill"], "fill_pitch": ROWS[1]["fill_pitch"], "fill_color": ROWS[1]["fill_color"], "air": {}},
}
const PARK_DIR := "res://src/world/park/"
static var _park_fog := {}
# The bowl has no row: it keeps the stage it ends (stage 2, the Spillway row under the morning row).
const ARENAS := {
	# The Waking pit: no daylight, a black ceiling, cool walls under a cool core key, the amber
	# accent on the floor pools.
	"waking": {"name": "waking", "sky": "dome", "background": Color("171e1d"),
		"ambient": Color("9ba8a3"), "energy": 0.16, "exposure": 1.1, "saturation": 1.2,
		"fog": {"color": Color("242a28"), "density": 0.008, "light_energy": 0.3, "sun_scatter": 0.0},
		"sun_color": Color("ffd49a"), "sun_energy": 2.35, "sun_rotation": Vector3(-36.0, -55.0, 0.0),
		"sun_visible": false, "fill": 0.5, "fill_pitch": -50.0, "fill_color": Color("a3c4e6"),
		"key": Color("a8c2d4"), "floor_accent": Palette.AMBER,
		"air": {"volumetric_fog_density": 0.025, "volumetric_fog_albedo": Color("4f5d63"),
			"volumetric_fog_emission": Color("05080a"), "volumetric_fog_anisotropy": 0.35,
			"volumetric_fog_length": 90.0, "volumetric_fog_ambient_inject": 0.15, "volumetric_fog_sky_affect": 0.0}},
	# The Mind's crown is the run's dusk (Andrew's "one day per run", 2026-10-17): the sun on the
	# dusk bearing but held higher than the stage's dusk row, and the light levels kept near the old
	# morning fight's, so telegraphs and the boss still read. The key is a pale rose, not the dusk
	# row's orange: an orange-lit floor swallowed the hazard-orange telegraph stripes in the capture,
	# so the dusk lives in the sky, the long shadows and the cool ambient.
	"mind": {"name": "mind", "sky": "own", "background": Color("243b43"),
		"ambient": Color("9097bd"), "energy": 0.32, "exposure": 1.15, "saturation": 0.95,
		"fog": {},
		"sun_color": Color("e6bcae"), "sun_energy": 2.1, "sun_rotation": Vector3(-14.0, 60.0, 0.0),
		"sun_visible": true, "fill": 0.55, "fill_pitch": -40.0, "fill_color": Color("9ba0cc"), "air": {},
		"grade": {"top": Color("6c6fae"), "horizon": Color("ffa07a"), "recolor": 0.45, "highlight": 2.0,
			"glow": Color("b8502a"), "energy": 0.85}},
}
# The camp walk (camp_hub.gd): the Spillway's daylight turned toward late afternoon, a warm low sun over the plaza, thin
# haze and no volumetric air, so the lamps and marquees carry the evening. Entered on the "camp" slot over the stage row.
const CAMP := {"name": "camp", "sky": "hdri", "background": Color("243b43"),
	"ambient": Color("c9c0a8"), "energy": 0.3, "exposure": 1.08, "saturation": 1.15,
	"fog": {"color": Color("d9c5a0"), "density": 0.0005},
	"sun_color": Color("ffc88a"), "sun_energy": 2.2, "sun_rotation": Vector3(-30.0, -35.0, 0.0),
	"sun_visible": true, "fill": 0.45, "fill_pitch": -45.0, "fill_color": Color("a9b6c0"), "air": {}}
# The menu stages own their small worlds; they are never freed with a stage.
const TITLE := {"energy": ROWS[1]["energy"], "sun_energy": ROWS[1]["sun_energy"], "sun_rotation": ROWS[1]["sun_rotation"],
	"fill": ROWS[1]["fill"], "background": Color("243b43"), "ambient": Color("9db5cf"), "exposure": 1.1, "contrast": 1.25,
	"sun_color": Color("ffd49a"), "fill_rotation": Vector3(-50.0, 125.0, 0.0), "fill_color": Color("a3c4e6"),
	"lamp_color": Palette.AMBER, "lamp_energy": 2.2}
const ENDING := {"sky": "workshop", "energy": 0.9, "fog": 0.0008, "sun_energy": 1.2, "sun_rotation": Vector3(-38.0, 118.0, 0.0)}
const PREVIEW := {"energy": 0.6, "sun_energy": 1.4, "sun_rotation": Vector3(-48.0, 32.0, 0.0),
	"rim_energy": 1.6, "rim_rotation": Vector3(-20.0, 200.0, 0.0)}
const NODE := "WorldLook"

# Time of day (KE7; PARK.md section 6; Andrew's "one day per run", 2026-10-17): one day across a
# run, dawn at the dam to dusk at the crown, and the light carries the run's arc: a cool hopeful
# dawn, a plain working noon over the open pit, a warm golden swing over the islands, a lonely dusk.
# Each stage enters at its time; the row lays its sun and ambient over the world row. The sun's
# height is minus its pitch (sun_rotation.x): it peaks at noon and is lowest at dawn and dusk.
#   grade: the time-of-day sky (time_sky.gdshader) over an "hdri" or "own" panorama: zenith and
#   horizon tints, recolor toward them, a cap on the painted sun, a horizon glow under the day's
#   sun, and the sky's energy. A dome world has no sky to grade.
#   fog_tint: the colour the stage's fog leans halfway toward (not under a dome).
#   sun_energy and energy: the ground's light, sun_energy x sin(sun height) + energy, rises from dawn to
#   noon and falls after (park_day_light_test). Noon is morning x 1.30 and afternoon is just under noon.
#   Provisional (#241 comment 6333015981): these values were fit to 3060 stills whose park ground
#   was Terrain3D's untextured checkerboard. On real sand the 3060 sweep (#241 comment 6334779159)
#   reads the noon floor at L* 73.9 against morning's 65.7, a step of 8.3 over the 5 target; no
#   single ambient or exposure change closes it. Ruling #241 comment 6334820540 keeps these values
#   for wave 18 and gives the step to a wave 19 exposure curve keyed to sun height.
const TIME_ORDER := ["dawn", "morning", "noon", "afternoon", "golden", "dusk"]
const STAGE_TIME := {1: "dawn", 2: "morning", 3: "noon", 4: "afternoon", 5: "golden", 6: "dusk"}
const TIME_ROWS := {
	"dawn": {"sun_rotation": Vector3(-8.0, -100.0, 0.0), "sun_color": Color("ffb27a"), "sun_energy": 1.4,
		"ambient": Color("9db5cf"), "energy": 0.22, "fog_tint": Color("f2c2b4"),
		"grade": {"top": Color("8e9ccf"), "horizon": Color("ffc3a6"), "recolor": 0.35, "highlight": 1.5,
			"glow": Color("b8683a"), "energy": 0.8}},
	"morning": {"sun_rotation": Vector3(-28.0, -70.0, 0.0), "sun_color": Color("ffd49a"), "sun_energy": 2.0,
		"ambient": Color("a9c4d6"), "energy": 0.26, "fog_tint": Color("e4ecf2"),
		"grade": {"top": Color("f2f6ff"), "horizon": Color("fff1e0"), "recolor": 0.0, "highlight": 8.0,
			"glow": Color("2a2214"), "energy": 1.0}},
	"noon": {"sun_rotation": Vector3(-62.0, -40.0, 0.0), "sun_color": Color("fff1dc"), "sun_energy": 1.4,
		"ambient": Color("dbe6ec"), "energy": 0.32, "fog_tint": Color("dfe6ea"),
		"grade": {"top": Color("ffffff"), "horizon": Color("ffffff"), "recolor": 0.0, "highlight": 65504.0,
			"glow": Color("000000"), "energy": 1.05}},
	"afternoon": {"sun_rotation": Vector3(-45.0, -15.0, 0.0), "sun_color": Color("ffd7a0"), "sun_energy": 1.7,
		"ambient": Color("c9c0a8"), "energy": 0.29, "fog_tint": Color("e6dcc8"),
		"grade": {"top": Color("fbf6ee"), "horizon": Color("ffe6c4"), "recolor": 0.1, "highlight": 8.0,
			"glow": Color("2c1e0e"), "energy": 1.0}},
	# golden grade energy 0.95 -> 1.25 (#241: purpose 6367471497, the 10 L* bar 6355922548, World's measured gaps 6356177813; tests/islands_sky_test.gd). On the 3060
	# (e9484509, World's fitted haze boxes) islands poses 26 and 159 read ground over horizon -8.46 and -7.52 against the 10 L* bar:
	# their floors are about 55 L*, their sky 63.82 and 61.84. They look 82 and 79 degrees off the sun's bearing (yaw 20), so the
	# shader's sun glow (pow(toward, 4) low + pow(toward, 48)) adds 0.017 Y there against 0.03 to 0.10 for the other nine,
	# and the horizon base (panorama x horizon tint, 0.34 Y) is nearly all of what they see. Across the 11 valid poses the shader
	# model picks the same five darkest skies as the 3060 (Spearman 0.79). The 3060 sky L* goes as 0.510 x Y^0.410 over the test's own
	# modelled Y (9 of 11 poses within 1.6 L*, pose 159 reads 4.2 under it; tests/islands_sky_test.gd), so the 2.48 L* pose 159 needs is a
	# 1.258x modelled Y at zero margin (pose 26's 1.54 is 1.150x). The test keeps 0.25 L* over the bar, which puts the floor at energy
	# 0.95 x 1.287 = about 1.22; 1.25 (a 1.316x sky) is the round value above it. Energy scales the base and the glow alike, keeps the horizon hue and moves
	# no sun value; it cannot darken any pose's sky. Sun colour, sun energy and rotation stay as they were.
	"golden": {"sun_rotation": Vector3(-16.0, 20.0, 0.0), "sun_color": Color("ffa35c"), "sun_energy": 1.9,
		"ambient": Color("e0b58a"), "energy": 0.25, "fog_tint": Color("f0b886"),
		"grade": {"top": Color("c9c2c8"), "horizon": Color("ffb47a"), "recolor": 0.45, "highlight": 2.0,
			"glow": Color("c8652a"), "energy": 1.25}},
	"dusk": {"sun_rotation": Vector3(-6.0, 60.0, 0.0), "sun_color": Color("e06f4a"), "sun_energy": 1.1,
		"ambient": Color("5d6b86"), "energy": 0.16, "fog_tint": Color("8a7a9e"),
		"grade": {"top": Color("4c5290"), "horizon": Color("e88a6a"), "recolor": 0.6, "highlight": 1.0,
			"glow": Color("b04a26"), "energy": 0.6}},
}
# Weather skies (KE7): the sky ids the weather rows name, with the tint and cloud amount each one
# sets. The fog itself comes from the row.
const WEATHER_SKY := {
	"clear": {"cloud": 0.0, "tint": Color("ffffff")},
	"dust": {"cloud": 0.1, "tint": Color("c9a36b")},
	"storm_build": {"cloud": 0.6, "tint": Color("6b7480")},
}


static func row(world: int) -> Dictionary:
	return ROWS.get(world, {})


static func time_id(stage: int) -> String:
	return STAGE_TIME.get(stage, "")


static func time_row(stage: int) -> Dictionary:
	return TIME_ROWS.get(time_id(stage), {})


# The fog {density, color} of a park map's standing weather row (the first with trigger "always" in
# World's park json, read-only); the Spillway's fog when it has none.
static func park_fog(map: String) -> Dictionary:
	if _park_fog.has(map):
		return _park_fog[map]
	var fog: Dictionary = ROWS[1].fog
	var file := FileAccess.open(PARK_DIR + map + ".json", FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text()) if file != null else null
	for weather in (data.get("weather_rows", []) if data is Dictionary else []):
		if weather.get("trigger", {}).get("on") == "always" and weather.get("fog", {}).has("density"):
			fog = {"density": float(weather.fog.density), "color": Color(String(weather.fog.color))}
			break
	_park_fog[map] = fog
	return fog


# The world row with the stage's time of day laid over it: sun, and the ambient colour and energy.
# A dome world (underground) has no daylight to vary, so its energy and sun energy stay at the
# world row; the time of day moves only the sun's direction and colour and the ambient colour there.
static func stage_look(stage: int, world: int, map := "") -> Dictionary:
	var base := row(world)
	var look := base.duplicate()
	var park: Dictionary = PARK_ROWS.get(world, {}) if map.begins_with("park_") else {}
	if not park.is_empty():
		look.merge(park, true)
		look["fog"] = park_fog(map)
		base = look.duplicate()
	look.merge(time_row(stage), true)
	if not time_id(stage).is_empty():
		look["time"] = time_id(stage)
	if base.get("sky") == "dome":
		look.energy = base.energy
		look.sun_energy = base.sun_energy
	return look


# The volumetric keys of a row: off unless the preset has air and the row has some.
static func air_values(look: Dictionary, air: bool) -> Dictionary:
	var on: bool = air and not look.air.is_empty()
	var values := {"volumetric_fog_enabled": on}
	if on:
		values.merge(look.air)
	return values


# A live override's volumetric keys follow a preset change: drop the old ones, lay the new.
static func follow_air(values: Dictionary, look: Dictionary, air: bool) -> void:
	values.erase("volumetric_fog_enabled")
	for key in look.air:
		values.erase(key)
	values.merge(air_values(look, air))


# The Environment values a row sets. Every row writes the same keys, so an arena's row covers
# the stage row it sits on, and leaving the arena uncovers it again.
static func environment(look: Dictionary, air: bool) -> Dictionary:
	var fog: Dictionary = look.fog
	var values := {
		"ambient_light_source": Environment.AMBIENT_SOURCE_COLOR,
		"ambient_light_color": look.ambient, "ambient_light_energy": look.energy,
		"tonemap_exposure": look.exposure, "adjustment_saturation": look.saturation,
		"fog_enabled": true, "fog_light_energy": fog.get("light_energy", 0.75), "fog_sun_scatter": fog.get("sun_scatter", 0.25),
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


# The time-of-day sky values a look's grade sets on a time_sky.gdshader material, as Object.set keys.
# The glow sits under the look's own sun, so the warm side of the sky is the side the key lights.
static func grade(look: Dictionary) -> Dictionary:
	var spec: Dictionary = look.get("grade", {})
	if spec.is_empty():
		return {}
	var r: Vector3 = look.sun_rotation
	var toward_sun := Basis.from_euler(Vector3(deg_to_rad(r.x), deg_to_rad(r.y), 0.0)).z
	return {"shader_parameter/top_tint": spec.top, "shader_parameter/horizon_tint": spec.horizon,
		"shader_parameter/recolor": spec.recolor, "shader_parameter/highlight": spec.highlight,
		"shader_parameter/glow": spec.glow, "shader_parameter/sun_dir": toward_sun,
		"shader_parameter/energy": spec.energy}


# The shared HDRI sky's grade as a set_lighting row, so the sky leaves with the stage's look. The
# material is one global object while set_lighting keeps a baseline per Environment, so only one
# Environment (the game's terrain environment) may enter "hdri" looks at a time.
static func sky_rows(look: Dictionary) -> Array:
	var values := grade(look)
	if values.is_empty() or look.get("sky") != "hdri":
		return []
	return [{"object": Palette.hdri_sky().sky_material, "values": values}]


# The world sun and its SkyFill sibling, as set_lighting light rows.
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


# Stage entry: the world's row on the stage root's own WorldLook node. An old map's root is parked,
# never freed; a park's root is freed when it leaves memory, and its next entry builds a new one.
static func hook(ctx) -> void:
	ctx.events.stage_entered.connect(_on_stage_entered.bind(ctx))


static func _on_stage_entered(stage: int, _retry: bool, ctx) -> void:
	var terrain = ctx.terrain
	if terrain == null or terrain.environment == null:
		return
	var root: Node3D = terrain.geometry_root(stage)
	var world: int = ctx.stages.world_of(stage)
	var GraphicsPreset := load("res://src/presentation/graphics_preset.gd")
	var look := stage_look(stage, world, String(ctx.stages.of(stage).get("map", "")))
	GraphicsPreset.enter_world(root, terrain.environment, look)
	var game = ctx.root
	if game != null and game.get("world") != null and game.world.view != null:
		game.world.view.record_fog()
	if look.has("lamps") and ctx.player != null:
		var pool := LampPool.find(root)
		if pool == null:
			pool = LampPool.new()
			pool.name = "LampPool"
			pool.setup(look.lamps, root, ctx.player)
			root.get_node(NODE).add_child(pool)


# A fixed set of shadowless lights moved to the lamps nearest the ball. The lamps themselves are
# batched meshes (dig_scenery lamp lines, their placements in the view's "origins" meta), so the
# light comes from this stage-owned pool and never from a per-lamp light.
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
		var ball: Vector3 = _player.ball_position()
		var order := Array(_lamps)
		order.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(ball) < b.distance_squared_to(ball))
		for i in _lights.size():
			_lights[i].visible = i < order.size()
			if i < order.size():
				_lights[i].global_position = order[i] + Vector3.DOWN * 1.5
