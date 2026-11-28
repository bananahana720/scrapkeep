extends RefCounted

const DIR := "res://assets/audio/"
const UNIT_SIZE := 12.0
const FAR := 80.0
const NEAR := 70.0
const ROWS := {
	"lift_cage_arrive": {"file": "foley/lift_cage_arrive.wav", "db": -4.0, "range": FAR},
	"zipline_whine": {"file": "foley/zipline_whine.wav", "db": -6.0, "range": FAR},
	"zipline_snap": {"file": "foley/zipline_snap.wav", "db": -4.0, "range": FAR},
	"cave_in_rumble": {"file": "foley/cave_in_rumble.wav", "db": -5.0, "range": FAR},
	"cave_in_debris": {"file": "foley/cave_in_debris.wav", "db": -4.0, "range": FAR},
	"prop_crew_presence": {"file": "foley/prop_crew_presence.wav", "db": -14.0, "range": FAR, "loop": true},
	"prop_crew_strain": {"file": "foley/prop_crew_strain.wav", "db": -4.0, "range": FAR},
	"prop_crew_collapse": {"file": "foley/prop_crew_collapse.wav", "db": -3.0, "range": FAR},
	"jolt_layer_presence": {"file": "specials/jolt_layer_presence.wav", "db": -14.0, "range": NEAR, "loop": true},
	"jolt_layer_tell": {"file": "specials/jolt_layer_tell.wav", "db": -4.0, "range": NEAR},
	"jolt_layer_jam": {"file": "specials/jolt_layer_jam.wav", "db": -4.0, "range": NEAR},
	"jolt_layer_fizzle": {"file": "specials/jolt_layer_fizzle.wav", "db": -4.0, "range": NEAR},
	"jolt_layer_break": {"file": "specials/jolt_layer_break.wav", "db": -3.0, "range": NEAR},
	"foreman_presence": {"file": "specials/foreman_presence.wav", "db": -14.0, "range": NEAR},
	"dispatcher_presence": {"file": "specials/dispatcher_presence.wav", "db": -14.0, "range": NEAR},
	"splitter_presence": {"file": "specials/splitter_presence.wav", "db": -14.0, "range": NEAR},
	"linker_presence": {"file": "specials/linker_presence.wav", "db": -14.0, "range": NEAR},
}
