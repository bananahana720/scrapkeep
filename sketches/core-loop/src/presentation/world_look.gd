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
# Arenas that stand in their world's daylight: the world row under a time-of-day row, as a stage
# enters (arena_look). The Slag Bowl is the Spillway at noon (world 1 unit 12: dawn dam, morning
# flume, noon bowl), so Brindle's fight is the day's high sun and the pit after it keeps noon.
const BOWL_SCRIPT := "res://src/boss/arena.gd"
# `over` lays the arena's own light over that, keeping noon's sun angle and energies: the bowl's smoky furnace gold (world
# 1's third act, its W46-03 sheet pick), a warm sun through smoke, a gold haze that thickens toward the stands.
const DAYLIT_ARENAS := {"brindle": {"world": 1, "time": "noon", "over": {
	"sun_color": Color("ffe5b6"), "ambient": Color("e6dac2"), "fog_tint": Color("e8d2a8"),
	"grade": {"top": Color("f0e6d2"), "horizon": Color("ffe2af"), "recolor": 0.2, "highlight": 8.0,
		"glow": Color("4a2c10"), "energy": 1.05},
	"fog": {"color": Color("c8a46e"), "density": 0.0016}, "fill_color": Color("c9b898")}}}
# The camp walk (camp_hub.gd): the Spillway's daylight turned toward late afternoon, a warm low sun over the plaza, thin
# haze and no volumetric air, so the lamps and marquees carry the evening. Entered on the "camp" slot over the stage row.
const CAMP := {"name": "camp", "sky": "hdri", "background": Color("243b43"),
	"ambient": Color("c9c0a8"), "energy": 0.3, "exposure": 1.08, "saturation": 1.15,
	"fog": {"color": Color("d9c5a0"), "density": 0.0005},
	"sun_color": Color("ffc88a"), "sun_energy": 2.2, "sun_rotation": Vector3(-30.0, -35.0, 0.0),
	"sun_visible": true, "fill": 0.45, "fill_pitch": -45.0, "fill_color": Color("a9b6c0"), "air": {},
	# The afternoon sky (TIME_ROWS.afternoon's grade) under the camp's own sun, so the drawn sky warms
	# with the plaza instead of keeping the plain panorama or the last stage's grade.
	"time": "afternoon", "grade": {"top": Color("fbf6ee"), "horizon": Color("ffe6c4"), "recolor": 0.1, "highlight": 8.0,
		"glow": Color("2c1e0e"), "energy": 1.0}}
# The menu stages own their small worlds; they are never freed with a stage.
const TITLE := {"energy": ROWS[1]["energy"], "sun_energy": ROWS[1]["sun_energy"], "sun_rotation": ROWS[1]["sun_rotation"],
	"fill": ROWS[1]["fill"], "background": Color("3a2a2e"), "ambient": Color("9db5cf"), "exposure": 1.1, "contrast": 1.25,
	"sun_color": Color("ffb27a"), "fill_rotation": Vector3(-50.0, 125.0, 0.0), "fill_color": Color("a3c4e6"),
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
	# World 1's three acts (WORLD1-DEMO-CATALYST.md C1, ruling ei): dawn and morning are world 1's own two stages, and their
	# light colours are the picks off the W46-03 sheet (its pull request, ruling cq); the energies, angles and grade
	# energies are the day arc's and stay as they were. The third act, the Slag Bowl, is DAYLIT_ARENAS.brindle.
	# The dam's cool desert dawn: violet-indigo canyon shade under a low apricot sun.
	"dawn": {"sun_rotation": Vector3(-8.0, -100.0, 0.0), "sun_color": Palette.APRICOT, "sun_energy": 1.4,
		"ambient": Palette.DAWN_VIOLET, "energy": 0.22, "fog_tint": Color("e8bcc4"),
		"grade": {"top": Color("8486cc"), "horizon": Color("ffbc94"), "recolor": 0.4, "highlight": 1.5,
			"glow": Color("b8683a"), "energy": 0.8}},
	# The flume's morning: turquoise sky and water light over sunlit terracotta stone.
	"morning": {"sun_rotation": Vector3(-28.0, -70.0, 0.0), "sun_color": Color("ffd09a"), "sun_energy": 2.0,
		"ambient": Palette.TURQUOISE, "energy": 0.26, "fog_tint": Color("d2eee8"),
		"grade": {"top": Color("d4f4f0"), "horizon": Color("f5d4c3"), "recolor": 0.2, "highlight": 8.0,
			"glow": Color("3a2414"), "energy": 1.0}},
	# Noon is world 2's first stage (the open pit, parked by ruling at), so it stays as it was; the Slag Bowl's gold is
	# its own arena row (DAYLIT_ARENAS).
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
	# away_lift 0.5 (time_sky.gdshader): the 3060 read the energy lift short on pose 159 (-8.45 against the 10 bar, 23 Oct) because the
	# sky's ambient raised the floor too. The lift brightens only the drawn sky 80+ degrees off the sun, so the floor stays; on the cloud
	# renderer it moved pose 159's sky +8.1 L* and pose 26's +7.4 with every near floor unchanged (tests/islands_sky_test.gd).
	"golden": {"sun_rotation": Vector3(-16.0, 20.0, 0.0), "sun_color": Color("ffa35c"), "sun_energy": 1.9,
		"ambient": Color("e0b58a"), "energy": 0.25, "fog_tint": Color("f0b886"),
		"grade": {"top": Color("c9c2c8"), "horizon": Color("ffb47a"), "recolor": 0.45, "highlight": 2.0,
			"glow": Color("c8652a"), "energy": 1.25, "away_lift": 0.5}},
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
# Stage looks a shift variant picks (ShiftVariants.look_id, read through flow.stage_look_id()), laid over the stage's look
# last. Same geometry, same colliders: a row adds light and lit dressing that collides with nothing.
# Dam Night Shift (W46-13, WORLD1-DEMO-CATALYST.md C5): blue hour over the dam. The sky and the key are a cool deep blue,
# no purple (hue 300 to 330 is the Foreman's Kindness, ruling ci) and no HAZARD (live danger only); the warm light is
# the crews' sodium floodlights, and the Old Works' green seams (the ancient_lens slot of the dam's own models) burn
# brighter. Candidate A of three on the W46-13 contact sheet (ruling cq; the sheet and its numbers are on that pull
# request): a lobber's ring stood further off the ground than at dawn both in the open (CIE76 58.5 against 36.1) and
# under a floodlight (47.6 against 42.4), where the lighter rows fell under dawn's under the lamp; its floor reads L* 15
# to 18 against dawn's 29 to 34, so the lamps carry the night. The dam's lamps light the yard's terracotta toward
# HAZARD, so they stay low: at energy 4 a ring in the yard reads 48.5 against dawn's 44.9 (7 read 44.5, 40 read 30.3).
const LOOK_ROWS := {
	"dam_night": {"sun_rotation": Vector3(-40.0, 150.0, 0.0), "sun_color": Color("8fa8dc"), "sun_energy": 0.45,
		"ambient": Color("4e6394"), "energy": 0.26, "fog_tint": Color("1f3152"), "fog_color": Color("24344f"),
		"fill": 0.22, "fill_color": Color("5a72a8"),
		"grade": {"top": Color("0c1630"), "horizon": Color("24405e"), "recolor": 0.8, "highlight": 1.0,
			"glow": Color("152436"), "energy": 0.35},
		"floods": {"model": "res://assets/models/camp/camp_lamp_post.glb", "socket": "light_0", "scale": 1.5,
			"card_m": 2.2, "fade_m": 450.0,
			"at": [[-30, -579, 0], [-184, -568, 11], [-117, -515, 79], [-33, -462, 247], [-114, -412, 146], [-117, -322, 79],
				[-18, -296, 315], [-237, -475, 146], [97, -593, 315], [-24, 168, 79], [70, 30, 270], [-149, 8, 113]],
			"lamps": {"color": Palette.SODIUM, "count": 6, "energy": 6.0, "range": 36.0, "attenuation": 0.9, "drop": 0.4, "every": 0.25},
			"dam": {"at": [[-70.0, 118.0, 632.0], [0.0, 124.0, 632.0], [70.0, 118.0, 632.0]], "aim_z": 470.0,
				"color": Palette.SODIUM, "energy": 4.0, "range": 260.0, "angle": 24.0}},
		"seams": {"energy": 6.0}},
}
# The Mind's consumed purple under the day's light (card: "Should the Mind's purple stay purple at
# sunset?", not yet asked; this is the recommended default). True: a consumed surface holds hue 300
# to 330 under every look, golden hour and dusk included, because it carries its own purple glow and
# lets the light tint only a dimmed albedo. False: the sun tints it like any other surface (sunset
# reads hot pink to 346, shade reads blue-violet to 280). tests/consumed_light_test.gd gates the band
# lit when true and reports the drift when false.
const CONSUMED_HOLDS_HUE := true
# Band centre (hue 315, sat 0.75). Albedo x0.6 (sRGB, about x0.35 in linear light) with glow 1.0:
# the gate's linear model keeps every look at lit hue 301 to 325 (glow 1.5 gives 304 to 323, but under
# AgX it reads pale bubblegum, on-screen sat 0.32 to 0.36 against the true purple's 0.40 to 0.44; glow 1.0
# reads 0.42 to 0.50 at hue 316 to 328). Albedo x1.0 fails the Waking pit (295-299) and golden hour
# sun-facing (331). tools/consumed_swatch_capture.gd reads the on-screen hue under AgX.
const CONSUMED_GLOW := {"color": Color("d936b0"), "energy": 1.0, "albedo_scale": 0.6}


# A material for a consumed surface of the given albedo, dressed per CONSUMED_HOLDS_HUE.
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


static func row(world: int) -> Dictionary:
	return ROWS.get(world, {})


static func time_id(stage: int) -> String:
	return STAGE_TIME.get(stage, "")


static func time_row(stage: int) -> Dictionary:
	return TIME_ROWS.get(time_id(stage), {})


# An arena's row: its own (ARENAS) or its world's daylight at its time of day (DAYLIT_ARENAS).
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


# The fog {density, color} of a park map's standing weather row (the first with trigger "always" in
# World's park json, read-only); the Spillway's fog when it has none. park_file is the stage's loaded park
# file (ParkMap.park) when the caller has it; reading the file again took 33 ms of the sinkhole's entry.
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


# The world row with the stage's time of day laid over it: sun, and the ambient colour and energy.
# A dome world (underground) has no daylight to vary, so its energy and sun energy stay at the
# world row; the time of day moves only the sun's direction and colour and the ambient colour there.
# look_id: a shift variant's look (LOOK_ROWS), laid over everything else; "" or an unknown id is the stage's own look.
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
		"shader_parameter/energy": spec.energy, "shader_parameter/away_lift": spec.get("away_lift", 0.0)}


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
	ctx.events.boss_arena_entered.connect(_on_arena_entered.bind(ctx))


# Brindle's Slag Bowl enters its daylit row on the arena slot, on the bowl's own WorldLook node, so
# the row covers the stage's and leaves with the bowl (exit, retry, stage change). Other bosses'
# arenas light themselves (arena_waking_dress, arena_mind_dress).
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
	var look := stage_look(stage, world, String(ctx.stages.of(stage).get("map", "")), loaded.park if loaded != null and "park" in loaded else {}, look_id)
	GraphicsPreset.enter_world(root, terrain.environment, look)
	NightShift.enter(root, terrain, look, ctx.player)
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
		var ball: Vector3 = _player.shown_position()
		var order := Array(_lamps)
		order.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(ball) < b.distance_squared_to(ball))
		for i in _lights.size():
			_lights[i].visible = i < order.size()
			if i < order.size():
				_lights[i].global_position = order[i] + Vector3.DOWN * 1.5


# A shift variant's lit dressing (LOOK_ROWS floods and seams). The masts and their glow cards are meshes on the stage
# root's WorldLook node, so they leave with the stage. The lights never leave: a Light3D freed with a stage made Godot
# 4.7.2 Forward+ crash on the next boss entry (tests/light_lifetime_lint_test.gd), and a park stage's root is freed
# when the park leaves memory. So the lights hang on the stage roots' own parent, which outlives every stage, and go
# dark whenever the entered stage's look has no floods.
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

	# Every stage entry: dress the stage and light the night when the look has floods, else put both away.
	static func enter(stage_root: Node3D, terrain, look: Dictionary, player) -> void:
		var host := stage_root.get_parent()
		var holder := stage_root.get_node_or_null(NODE)
		var dress := holder.get_node_or_null(DRESS) if holder != null else null
		var lights := host.get_node_or_null(LIGHTS) as NightShift if host != null else null
		var spec: Dictionary = look.get("floods", {})
		if spec.is_empty() or holder == null or host == null:
			if dress != null:
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
		for spot in _dam:
			spot.visible = false
			spot.light_energy = 0.0
		_heads = PackedVector3Array()
		set_process(false)

	# The pool sits on the masts nearest the ball, a little under each lamp head.
	func _process(delta: float) -> void:
		_wait -= delta
		if _wait > 0.0 or _heads.is_empty() or _player == null:
			return
		_wait = _spec.lamps.every
		var ball: Vector3 = _player.shown_position()
		var order := Array(_heads)
		order.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(ball) < b.distance_squared_to(ball))
		for i in _pool.size():
			_pool[i].visible = i < order.size()
			if i < order.size():
				_pool[i].global_position = order[i] + Vector3.DOWN * float(_spec.lamps.drop)

	# The stage's masts, their glow cards and the brighter seams. Meshes only: nothing here collides or lights.
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
				# The camp's lamp post carries its own collider; a night mast stands in no one's way.
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

		# A park's rows can finish building after the stage is entered, so the seams are looked for until found.
		func _process(delta: float) -> void:
			_next -= delta
			if _next > 0.0:
				return
			_next = SEAM_EVERY_S
			_tries += 1
			var rows := []
			var seen := {}
			for view: MeshInstance3D in get_parent().get_parent().find_children("*", "MeshInstance3D", true, false):
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

		# A soft round sodium glow that always faces the eye: the lamp itself, drawn as a lighting card.
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
