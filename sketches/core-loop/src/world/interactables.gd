extends RefCounted

const Palette := preload("res://src/core/palette.gd")

# The interact key's vocabulary (LOOP-REDESIGN section 9). One key is interact everywhere, and
# every interactable belongs to one of five families. A family is one shape, one colour,
# one sound register and one prompt verb, so the player learns five things, not fifty.
# The device builders, the world prompt, the reticle's hold ring, audio and VFX all read
# the family row here, so a family looks, sounds and reads the same wherever it stands.
#
# icon       Icons id the prompt draws (the family glyph at 30 m and beside the keycap).
# shape      event_kinds silhouette VFX uses for the family's facts.
# color      the family colour: the prompt glyph, the ground ring, the VFX.
# accent     the second colour its greybox wears (a cap, a stripe, a seam).
# consent    roll: E inside the amber lane, the device fires as the ball crosses its
#            mouth. hold: E held HOLD_SECONDS; a tap does nothing. press: E once, for
#            what costs nothing and is where the player stops on purpose.
# verb       the prompt's first word. A device adds its own terms, PROMPT_WORDS in all.
# arm, fire  the sound register: `sound` is a baked stand-in, `sound_next` the cue W5 is
#            to bake (SOUND-STORY registers). won and lost voice an outcome.
# cost       what a device of the family may charge: "none", "cores" (this stage's bonus
#            cores) or "scrap" (wallet scrap through run.spend_scrap(), which keeps mass,
#            so paying never shrinks heft; only a telegraphed theft does).

# E locks the nearest ready device inside FACING_DEG of the look and within LOCK_REACH,
# so a ball at 40 m/s has about 0.45 s between the lock and the device. The lock holds
# until the device is RELEASE_REACH away, so a hold may finish after the ball has passed.
# A lock beyond REACH yields to a steep face Sable could mount; within REACH it wins.
const REACH := 6.0
const LOCK_REACH := 18.0
const RELEASE_REACH := 24.0
const FACING_DEG := 60.0
const GLYPH_REACH := 30.0
const HOLD_SECONDS := 0.35
const LANE_LENGTH := 12.0
const PROMPT_WORDS := 5

const FAMILIES := {
	"travel": {"icon": "obj_launch", "shape": "arrow", "color": Palette.AMBER, "accent": Palette.SAND,
		"cost": "none", "consent": "roll", "verb": "Ride",
		"arm": {"sound": "ui_tick", "sound_next": "gauge_tick"},
		"fire": {"sound": "launch_roar", "sound_next": "launch_arpeggio"}},
	"fight": {"icon": "thr_instant", "shape": "cross", "color": Palette.HAZARD, "accent": Palette.COPPER,
		"cost": "none", "consent": "hold", "verb": "Fight",
		"arm": {"sound": "clank", "sound_next": "brass_anvil"},
		"fire": {"sound": "build_riser", "sound_next": "miniboss_riser"},
		"won": {"sound": "found_chime", "sound_next": "ambush_cleared"},
		"lost": {"sound": "event_end"}},
	"secret": {"icon": "obj_vault", "shape": "diamond", "color": Palette.VERDIGRIS, "accent": Palette.CHARCOAL,
		"cost": "none", "consent": "press", "verb": "Open",
		"arm": {"sound": "found_chime"},
		"fire": {"sound": "vault_rise", "sound_next": "codex_discovery_burst"}},
	"ally": {"icon": "cat_defense", "shape": "ring", "color": Palette.ANCIENT, "accent": Palette.ARC,
		"cost": "scrap", "consent": "hold", "verb": "Wake",
		"arm": {"sound": "zap_hum", "sound_next": "cherenkov_flicker"},
		"fire": {"sound": "beacon_hum", "sound_next": "class_motif_sine"}},
	"bet": {"icon": "trg_timed", "shape": "star", "color": Palette.COPPER, "accent": Palette.HAZARD,
		"cost": "cores", "consent": "hold", "verb": "Double",
		"arm": {"sound": "rivet_hihat_roll", "sound_next": "drum_roll"},
		"fire": {"sound": "bench_clank", "sound_next": "slot_clunk"},
		"won": {"sound": "synergy_hit", "sound_next": "crit_crack"},
		"lost": {"sound": "womp", "sound_next": "dry_refusal"}},
}

# Where each map's interactables stand, in that map's x and z, keyed by the stage row's
# map id: a stage on another map gets none of them. The Spillway's lab set: an ambush
# altar beside the east chute's head (the long line), a cracked wall behind the vault
# plinth with a cache in its pocket, and a double-or-nothing crate on the bowl's south
# bank, the rim where the loop leaves the bowl for the return. The lift (travel) is
# writer L1's and registers itself through Interact.register().
const PLACEMENTS := {
	"spillway": [
		{"id": "east_altar", "device": "ambush_altar", "at": Vector2(78.0, -96.0), "face": Vector2(-1.0, 0.0)},
		{"id": "plinth_cache", "device": "cracked_cache", "at": Vector2(-5.0, -156.0), "face": Vector2(0.0, 1.0)},
		{"id": "rim_crate", "device": "bet_crate", "at": Vector2(-14.0, 21.0), "face": Vector2(0.0, -1.0)},
	],
}


static func row(family: String) -> Dictionary:
	return FAMILIES.get(family, FAMILIES["secret"])


static func color(family: String) -> Color:
	return row(family)["color"]


# The sound entry for one beat of a family's register ("arm", "fire", "won", "lost"),
# in the event_kinds row schema so presentation resolves it with Rows.heard().
static func sound(family: String, beat: String) -> Dictionary:
	return row(family).get(beat, {})


# A device's prompt: the family verb, then its own terms. Words past PROMPT_WORDS are
# cut, so no device can grow the prompt past the rule.
static func prompt(family: String, terms: String) -> String:
	var words := (String(row(family)["verb"]) + ": " + terms).split(" ", false)
	return " ".join(words.slice(0, PROMPT_WORDS))
