extends RefCounted

# Ambient life: the one record per critter or local (AMBIENT-LIFE.md). The model, its three
# baked loops, its paint, its two sounds, where it lives and how it behaves all read the same
# row, so a kind looks, moves and sounds the same everywhere it shows up. The Blender recipes
# (tools/blender/ambient/) paint from `palette`, tools/ace/ambient_sfx.py renders `sound` from
# its `voice`, ambient_life.gd places and drives the kind, and the tests check the GLB, the wavs
# and the behaviour against this row.
#
# Ambient life never touches play: no physics body, no event, no damage, no pickup. It is
# candy (FEEL-READABILITY.md P7): first to go under load, no keyline, no emission.
#
# Colour law: every kind lives in the life band, hue LIFE_HUE (degrees) at saturation
# LIFE_SAT. No enemy, telegraph, reward or verb colour sits in it (measured on every enemy GLB,
# tests/ambient_palette_test.gd), so lilac means "harmless and alive". `cream` accents (eyes,
# bellies, fur) stay under NEUTRAL_SAT and cover at most NEUTRAL_SHARE of a model's vertices.
#
# Row fields:
#   world      1 Spillway, 2 Dig, 3 Highdraft
#   parks      park map ids (park_schema.gd MAP_STAGE) the kind lives in
#   role       "critter" | "local"
#   model      the GLB; `loops` names its three baked clips
#   height_m   standing height of the model in metres (round, small: never enemy scale)
#   tris       [min, max] triangles for the recipe's assert (the "ambient" budget class)
#   palette    name -> Color the recipe paints; every entry but `cream` and `eye` is in the band
#   sound      {"call", "react"} -> wav; `voice` is the renderer's recipe for each
#   call_every [min, max] seconds between calls while calm
#   volume_db  call level; react plays 3 dB under it
#   motion     "walk" | "hop" | "fly"
#   speed      wander speed m/s; flee_speed when fleeing
#   flee_m     the ball inside this distance (metres) sends it away, never toward the ball
#   react      what combat nearby does: "hide" (run to cover, then sink out of sight),
#              "scatter" (lift away up and out, re-perch later), "duck" (stay, hide in place)
#   wander_m   leash radius around its home
#   sleep      share of calm time spent asleep (idle loop slowed, eyes shut pose)
#   homes      where the planner may put it: landforms / elements / societies (any match),
#              perch ("ground" | "rim" | "ceiling" | "water"), count [min, max] homes per
#              park, group [min, max] members per home; optional `spots`, crew prop templates
#              (src/world/park/props/<map>.json) the kind lives beside first, so keepers stand at the camps

const LIFE_HUE := Vector2(250.0, 300.0)
const LIFE_SAT := Vector2(0.15, 0.55)
const NEUTRAL_SAT := 0.15
const NEUTRAL_SHARE := 0.30
const ACCENTS := ["cream", "eye"]
const ROLES := ["critter", "local"]
const MOTIONS := ["walk", "hop", "fly"]
const REACTS := ["hide", "scatter", "duck"]
const PERCHES := ["ground", "rim", "ceiling", "water"]
const LOOPS := {"idle": "idle", "move": "move", "react": "react"}
# The react clip is a one-shot into its ducked or hidden pose; from REACT_HOLD_S to its end it
# closes on itself, so the runtime plays it once and then loops only that hold (the recipe asserts it).
const REACT_HOLD_S := 0.8
# The recipes build every kind facing -Z (Godot forward); the pool's facing points +Z along travel.
const FRONT_YAW := PI
const MODEL_DIR := "res://assets/models/ambient/"
const SOUND_DIR := "res://assets/audio/ambient/"
const TRIS := [800, 6000]
# The pool: at most this many members drawn per park; reduced motion halves it.
const CAP := 24
# Combat within this many metres of a member makes it react; calm returns after RETURN_S.
const COMBAT_M := 30.0
const RETURN_S := Vector2(6.0, 10.0)
# Every ambient sound is muted while a telegraph is live within this many metres.
const HUSH_M := 40.0
const MAX_VOICES := 2
const FALLOFF_M := 30.0

const KINDS := {
	# --- World 1, Spillway Works: dawn water and the dam-era keepers ---
	"dusk_quail": {
		"world": 1, "parks": ["park_dam", "park_flume"], "role": "critter",
		"model": MODEL_DIR + "dusk_quail.glb", "height_m": 0.32, "tris": [1200, 3000],
		"palette": {"body": Color("8f84b3"), "wing": Color("74699a"), "plume": Color("5e4a80"), "cream": Color("efe8f2"), "eye": Color("2b2238")},
		"sound": {"call": SOUND_DIR + "dusk_quail_call.wav", "react": SOUND_DIR + "dusk_quail_react.wav"},
		"voice": {"call": "three_note_chirp", "react": "wing_whirr"},
		"call_every": [7.0, 14.0], "volume_db": -18.0,
		"motion": "walk", "speed": 1.6, "flee_speed": 6.5, "flee_m": 12.0, "react": "hide", "wander_m": 9.0, "sleep": 0.1,
		"homes": {"landforms": ["arroyo", "dry_wash", "slickrock", "saguaro_stand", "hoodoo_field"], "elements": ["ground", "bank"],
			"societies": [], "perch": "ground", "count": [3, 4], "group": [3, 5]},
	},
	"dam_swift": {
		"world": 1, "parks": ["park_dam", "park_flume"], "role": "critter",
		"model": MODEL_DIR + "dam_swift.glb", "height_m": 0.22, "tris": [900, 4000],
		"palette": {"body": Color("7d70a8"), "wing": Color("5e4a80"), "cream": Color("ece4f1"), "eye": Color("2b2238")},
		"sound": {"call": SOUND_DIR + "dam_swift_call.wav", "react": SOUND_DIR + "dam_swift_react.wav"},
		"voice": {"call": "thin_twitter", "react": "flutter_burst"},
		"call_every": [6.0, 12.0], "volume_db": -20.0,
		"motion": "fly", "speed": 1.0, "flee_speed": 9.0, "flee_m": 10.0, "react": "scatter", "wander_m": 4.0, "sleep": 0.35,
		"homes": {"landforms": ["dam_face", "mesa_rim", "butte", "penstock"], "elements": [], "societies": [],
			"perch": "rim", "count": [2, 3], "group": [3, 5]},
	},
	"puddle_toad": {
		"world": 1, "parks": ["park_dam", "park_flume"], "role": "critter",
		"model": MODEL_DIR + "puddle_toad.glb", "height_m": 0.24, "tris": [900, 4000],
		"palette": {"body": Color("8a79c8"), "spots": Color("6e5ea8"), "cream": Color("efe8f2"), "eye": Color("2b2238")},
		"sound": {"call": SOUND_DIR + "puddle_toad_call.wav", "react": SOUND_DIR + "puddle_toad_react.wav"},
		"voice": {"call": "low_croak", "react": "water_plop"},
		"call_every": [8.0, 14.0], "volume_db": -18.0,
		"motion": "hop", "speed": 0.8, "flee_speed": 4.0, "flee_m": 9.0, "react": "hide", "wander_m": 4.0, "sleep": 0.4,
		"homes": {"landforms": ["canal", "river_canyon", "horseshoe_bend", "flume", "spillway_tunnel"], "elements": ["ground", "bank"],
			"societies": [], "perch": "water", "count": [2, 3], "group": [1, 3]},
	},
	"weir_keeper": {
		"world": 1, "parks": ["park_dam", "park_flume"], "role": "local",
		"model": MODEL_DIR + "weir_keeper.glb", "height_m": 1.1, "tris": [2500, 6000],
		"palette": {"overalls": Color("9a7fc0"), "hat": Color("6e5a8c"), "tail": Color("5b4a78"), "bucket": Color("7c6fa6"), "cream": Color("ece4ee"), "eye": Color("2b2238")},
		"sound": {"call": SOUND_DIR + "weir_keeper_call.wav", "react": SOUND_DIR + "weir_keeper_react.wav"},
		"voice": {"call": "two_note_whistle", "react": "bucket_clonk"},
		"call_every": [9.0, 16.0], "volume_db": -17.0,
		"motion": "walk", "speed": 0.0, "flee_speed": 0.0, "flee_m": 8.0, "react": "duck", "wander_m": 0.0, "sleep": 0.15,
		"homes": {"landforms": [], "elements": ["ground", "bank", "terrace", "ledge"], "societies": ["dam_era"],
			"perch": "ground", "count": [5, 6], "group": [1, 1],
			"spots": ["crew_camp", "wheelhouse_yard", "survey_station", "tool_wall", "pour_site", "flood_gauge",
				"washday", "camp_corner", "sluice_station", "head_gate_crew", "crane_yard", "skiff_shore"]},
	},
	# --- World 2, the Dig: the miners left, their burros stayed ---
	"pit_burro": {
		"world": 2, "parks": ["park_pit", "park_sinkhole"], "role": "critter",
		"model": MODEL_DIR + "pit_burro.glb", "height_m": 1.3, "tris": [2500, 6000],
		"palette": {"body": Color("8d82a3"), "mane": Color("5e4a80"), "hoof": Color("4f3d6e"), "cream": Color("ece4ee"), "eye": Color("2b2238")},
		"sound": {"call": SOUND_DIR + "pit_burro_call.wav", "react": SOUND_DIR + "pit_burro_react.wav"},
		"voice": {"call": "bray", "react": "hoof_clops"},
		"call_every": [10.0, 18.0], "volume_db": -17.0,
		"motion": "walk", "speed": 0.9, "flee_speed": 4.5, "flee_m": 14.0, "react": "hide", "wander_m": 10.0, "sleep": 0.2,
		"homes": {"landforms": ["tailings_bench", "open_pit", "slickrock", "dry_wash", "butte"], "elements": ["bank", "terrace", "ground", "ledge"],
			"societies": [], "perch": "ground", "count": [2, 3], "group": [1, 3]},
	},
	"tube_bat": {
		"world": 2, "parks": ["park_pit", "park_sinkhole"], "role": "critter",
		"model": MODEL_DIR + "tube_bat.glb", "height_m": 0.2, "tris": [900, 4000],
		"palette": {"body": Color("5a4470"), "wing": Color("6e5a8c"), "cream": Color("e8e0ee"), "eye": Color("2b2238")},
		"sound": {"call": SOUND_DIR + "tube_bat_call.wav", "react": SOUND_DIR + "tube_bat_react.wav"},
		"voice": {"call": "tiny_squeak", "react": "leather_flutter"},
		"call_every": [8.0, 15.0], "volume_db": -21.0,
		"motion": "fly", "speed": 0.0, "flee_speed": 8.0, "flee_m": 10.0, "react": "scatter", "wander_m": 0.0, "sleep": 0.8,
		"homes": {"landforms": ["lava_tube", "adit", "shaft", "sinkhole", "headframe", "flooded_shaft"], "elements": [], "societies": [],
			"perch": "ceiling", "count": [3, 3], "group": [3, 6]},
	},
	"horned_lizard": {
		"world": 2, "parks": ["park_pit", "park_sinkhole"], "role": "critter",
		"model": MODEL_DIR + "horned_lizard.glb", "height_m": 0.14, "tris": [900, 4000],
		"palette": {"body": Color("9c86a8"), "nubs": Color("7d6890"), "cream": Color("ece4ee"), "eye": Color("2b2238")},
		"sound": {"call": SOUND_DIR + "horned_lizard_call.wav", "react": SOUND_DIR + "horned_lizard_react.wav"},
		"voice": {"call": "pebble_scratch", "react": "hiss_puff"},
		"call_every": [9.0, 16.0], "volume_db": -21.0,
		"motion": "walk", "speed": 0.6, "flee_speed": 3.5, "flee_m": 8.0, "react": "hide", "wander_m": 3.0, "sleep": 0.3,
		"homes": {"landforms": ["slickrock", "tailings_bench", "hoodoo_field", "open_pit", "butte"], "elements": ["ground", "bank", "ledge"],
			"societies": [], "perch": "ground", "count": [3, 3], "group": [1, 2]},
	},
	"prospector": {
		"world": 2, "parks": ["park_pit", "park_sinkhole"], "role": "local",
		"model": MODEL_DIR + "prospector.glb", "height_m": 1.0, "tris": [2500, 6000],
		"palette": {"shirt": Color("7c5ea8"), "hat": Color("5e4a80"), "pan": Color("8d82a3"), "stripe": Color("4f3d6e"), "cream": Color("e8e2ea"), "eye": Color("2b2238")},
		"sound": {"call": SOUND_DIR + "prospector_call.wav", "react": SOUND_DIR + "prospector_react.wav"},
		"voice": {"call": "hummed_tune", "react": "pan_clatter"},
		"call_every": [10.0, 18.0], "volume_db": -17.0,
		"motion": "walk", "speed": 0.0, "flee_speed": 0.0, "flee_m": 8.0, "react": "duck", "wander_m": 0.0, "sleep": 0.2,
		"homes": {"landforms": ["tailings_bench", "cenote_pool", "canal", "flume", "open_pit", "adit"], "elements": ["ground", "bank", "terrace", "ledge"],
			"societies": ["mining"], "perch": "ground", "count": [2, 2], "group": [1, 1]},
	},
	# --- World 3, the Highdraft: dusk wind and the net-weavers ---
	"bighorn_lamb": {
		"world": 3, "parks": ["park_islands", "park_crown"], "role": "critter",
		"model": MODEL_DIR + "bighorn_lamb.glb", "height_m": 0.7, "tris": [1500, 5000],
		"palette": {"wool": Color("c9b8e0"), "face": Color("6e5a8c"), "horn": Color("8d82a3"), "cream": Color("efe8f2"), "eye": Color("2b2238")},
		"sound": {"call": SOUND_DIR + "bighorn_lamb_call.wav", "react": SOUND_DIR + "bighorn_lamb_react.wav"},
		"voice": {"call": "bleat", "react": "hoof_taps"},
		"call_every": [9.0, 16.0], "volume_db": -18.0,
		"motion": "hop", "speed": 1.0, "flee_speed": 5.0, "flee_m": 12.0, "react": "hide", "wander_m": 8.0, "sleep": 0.3,
		"homes": {"landforms": ["mesa_rim", "butte", "sky_island", "slickrock", "spire"], "elements": ["ground", "bank", "ledge", "sky_island"],
			"societies": [], "perch": "rim", "count": [3, 3], "group": [2, 3]},
	},
	"canyon_wren": {
		"world": 3, "parks": ["park_islands", "park_crown"], "role": "critter",
		"model": MODEL_DIR + "canyon_wren.glb", "height_m": 0.18, "tris": [900, 4000],
		"palette": {"body": Color("a07fb8"), "wing": Color("7c5ea8"), "tail": Color("5e4a80"), "cream": Color("efe8f2"), "eye": Color("2b2238")},
		"sound": {"call": SOUND_DIR + "canyon_wren_call.wav", "react": SOUND_DIR + "canyon_wren_react.wav"},
		"voice": {"call": "falling_whistle", "react": "flutter_burst"},
		"call_every": [7.0, 13.0], "volume_db": -19.0,
		"motion": "fly", "speed": 1.2, "flee_speed": 9.0, "flee_m": 10.0, "react": "scatter", "wander_m": 5.0, "sleep": 0.15,
		"homes": {"landforms": ["hoodoo_field", "sky_island", "slickrock", "butte"], "elements": ["ground", "sky_island", "ledge"],
			"societies": ["net_weaver"], "perch": "ground", "count": [3, 3], "group": [2, 4]},
	},
	"net_weaver": {
		"world": 3, "parks": ["park_islands", "park_crown"], "role": "local",
		"model": MODEL_DIR + "net_weaver.glb", "height_m": 0.95, "tris": [2500, 6000],
		"palette": {"smock": Color("8e72b8"), "rings": Color("5b4a78"), "net": Color("b4a4cc"), "sash": Color("6e5a8c"), "cream": Color("ece4ee"), "eye": Color("2b2238")},
		"sound": {"call": SOUND_DIR + "net_weaver_call.wav", "react": SOUND_DIR + "net_weaver_react.wav"},
		"voice": {"call": "humming_creak", "react": "chitter"},
		"call_every": [9.0, 16.0], "volume_db": -17.0,
		"motion": "walk", "speed": 0.0, "flee_speed": 0.0, "flee_m": 8.0, "react": "duck", "wander_m": 0.0, "sleep": 0.15,
		"homes": {"landforms": ["sky_island", "hoodoo_field", "mesa_rim", "butte"], "elements": ["ground", "sky_island", "bank", "ledge"],
			"societies": ["net_weaver"], "perch": "ground", "count": [2, 3], "group": [1, 1]},
	},
}


static func row(id: String) -> Dictionary:
	return KINDS.get(id, {})


# The kinds that live in a park, in a stable order.
static func for_park(map_id: String) -> Array:
	var ids := []
	for id in KINDS:
		if (KINDS[id].parks as Array).has(map_id):
			ids.append(id)
	ids.sort()
	return ids


static func worlds() -> Array:
	var result := []
	for id in KINDS:
		if not result.has(KINDS[id].world):
			result.append(KINDS[id].world)
	result.sort()
	return result


# Whether a colour belongs to the life band (hue and saturation both inside).
static func in_band(c: Color) -> bool:
	var hue := c.h * 360.0
	return hue >= LIFE_HUE.x and hue <= LIFE_HUE.y and c.s >= LIFE_SAT.x and c.s <= LIFE_SAT.y


static func is_neutral(c: Color) -> bool:
	return c.s < NEUTRAL_SAT


# Every field a row must carry, for the record test.
const FIELDS := ["world", "parks", "role", "model", "height_m", "tris", "palette", "sound", "voice", "call_every",
	"volume_db", "motion", "speed", "flee_speed", "flee_m", "react", "wander_m", "sleep", "homes"]
