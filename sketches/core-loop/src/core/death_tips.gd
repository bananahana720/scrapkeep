extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const DeathCause := preload("res://src/core/death_cause.gd")

# RUN OVER's "next shift" line (9 Nov pre-sitting pass, world 1 design findings): one thing to try
# next run, picked from what scrapped you. The cause line says who; this says what to do about it.
# Hades' Hypnos follows the killer's name with a word about meeting it next time; a screen that only
# names the killer leaves the player to guess.
#
# One line, in the crew-log voice (TONE-BIBLE: dry work notes, never a joke about the player), at
# most MAX_CHARS so the note beside the comic page stays four short rows. The first rule that answers wins:
#   1. a Warden or boss fight the build arrived short for (its punch on meeting the fight under
#      GAP_RATIO of the plating: the posture rule squares the ratio, so under 0.7 a hit fills less
#      than half): grow first, with the numbers. The numbers are the arrival's (flow._arrival), since
#      scrap is armour and every death lands on a stripped ball;
#   2. the killing attack's own row in ROWS (its ATTACK_ROWS id), then its source's row;
#   3. the attack's threat type (BY_THREAT), so a later world's attack still gets a true line;
#   4. a body whose hits are all drawn first (an attack row with no threat, or a MIXED body): DRAWN.
# A death with no source, or a hazard with no row, says nothing.
#
# Each row is the kind's own answer from its design notes (SPILLWAY-ROSTER's Answer column, the
# codex hints, the comment at the head of its script). A row tells the way out and names no codex
# entry or payout, so the first time a trick pays is still a find.

const HEAD := "Next shift"
const MAX_CHARS := 82
const GAP_RATIO := 0.7
const GAP := "Punch %d met %s's plating %d. Roll up more scrap for more punch."
const DRAWN := "Every hit is drawn on the floor first. Read the mark, then move."

const ROWS := {
	"E01": "Ram a chaser while it crouches to lunge. The lunge never comes.",
	"E02": "A shell lands on the ring it draws ahead of you. Change line once it is down.",
	"E03": "The drop hammer lands on its ring. Roll out, then hit its core when it opens.",
	"E04": "The drop hammer charges down its lane. Step aside, then hit its open core.",
	"E26": "The Dispatcher's pod lands on its ring. Roll out, then go up the mast after it.",
	"E34": "The hook swings down its lane and back. Step out, then hit the core when it opens.",
	"E35": "The gate leaf falls where the crane marks. Roll clear, then hit its open core.",
	"E40": "Cross a boom at top speed and its floats pop. Slower, and it pins you.",
	"B02": "Jump the slag ring, or cross it on a rim water vent.",
	"B03": "Leave the charge lane sideways. A lane that ends in the rim wall stuns him open.",
	"plated_brute": "The brute marks its slam on the floor and its hurl in the air. Leave the mark.",
	"warden": "Back off the Warden as its ring fills. Jump any slag it leaves.",
	"warden_counter": "A staggered Warden charges one counter-pulse. Hit the core, then clear its ring.",
	"silt_boil": "Silt boils under a ball circling a fight. Roll through the crew, not round it.",
}

const BY_THREAT := {
	"threat_lane": "The rails on the floor are its lane. Step out before the fill arrives.",
	"threat_instant": "The striped ring closes, then hits. Be outside it when it shuts.",
	"threat_projectile": "The reticle marks the landing. Change line before it arrives.",
	"threat_wave": "The bright front is the wave. Be over it or past it when it arrives.",
}


# The line without its prefix; "" when there is nothing true to say. `gap` is the live Warden or boss
# fight's {"who", "punch", "plating"} as the build met it, empty off one.
static func line(source: String, attack := "", gap := {}) -> String:
	if source == "":
		return ""
	if short_build(gap):
		return GAP % [int(gap["punch"]), String(gap.get("who", "the Warden")), int(gap["plating"])]
	var id := DeathCause.row_id(source, attack)
	for key in [id, source]:
		if ROWS.has(key):
			return String(ROWS[key])
	if id != "":
		return String(BY_THREAT.get(EventKinds.attack_threat(id), DRAWN))
	return DRAWN if source in DeathCause.MIXED else ""


# The note as one line, head first: what a reader of the screen's text gets.
static func shown(tip: String) -> String:
	return "%s: %s" % [HEAD, tip] if tip != "" else ""


static func short_build(gap: Dictionary) -> bool:
	var plating := float(gap.get("plating", 0.0))
	return plating > 0.0 and float(gap.get("punch", 0.0)) < plating * GAP_RATIO
