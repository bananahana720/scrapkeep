extends RefCounted

# The one musical source. The music engine, the stingers and every pitched SFX read
# their tempo, key and scales from here, so a scrap pickup, the beacon ladder and the
# stage-clear jingle are all in the key the band is playing (form mirrors function).

const RATE := 44100
# 172 BPM, drum-and-bass tempo. The grid is whole samples: one 16th is 3846 samples,
# so every beat and bar boundary is an exact sample index and quantizing never drifts.
const STEP := 3846
const STEPS_PER_BEAT := 4
const BEAT := STEP * STEPS_PER_BEAT
const STEPS_PER_BAR := 16
const BAR := STEP * STEPS_PER_BAR
const PHRASE_BARS := 8
const BPM := 60.0 * RATE / BEAT

# Home is D. The band plays D Dorian (minor with a raised sixth, the jazz-minor colour).
const HOME := 62
const DORIAN := [0, 2, 3, 5, 7, 9, 10]
const AEOLIAN := [0, 2, 3, 5, 7, 8, 10]
const HARMONIC := [0, 2, 3, 5, 7, 8, 11]
const PHRYGIAN := [0, 1, 3, 5, 7, 8, 10]
const MAJOR := [0, 2, 4, 5, 7, 9, 11]
# The boss tempo: a half-note triplet at 172 becomes the quarter at 129. One boss
# beat is exactly 4/3 of a band beat, 20512 samples, and three of them fill a band bar.
const BOSS_STEP := 5128
const BOSS_BEAT := BOSS_STEP * STEPS_PER_BEAT
# Rewards climb this ladder: D minor pentatonic, D F G A C. Every rung sits inside
# every chord of the loop, so a pickup combo never clashes with the band.
const PENTATONIC := [0, 3, 5, 7, 10]

# One chord per bar (bar 8 is the ii-V turnaround back to the top).
# root: bass midi; voicing: the keys' rootless voicing; tones: strong-beat targets for
# the lead; scale: the lead's scale for that bar.
const PROGRESSION := [
	{"name": "Dm9", "root": 38, "voicing": [53, 57, 60, 64], "tones": [62, 65, 69, 72, 64], "scale": DORIAN},
	{"name": "G13", "root": 43, "voicing": [53, 57, 59, 64], "tones": [67, 71, 65, 64, 69], "scale": DORIAN},
	{"name": "Dm9", "root": 38, "voicing": [57, 60, 64, 65], "tones": [62, 65, 69, 72, 64], "scale": DORIAN},
	{"name": "Cmaj9", "root": 36, "voicing": [55, 59, 62, 64], "tones": [60, 64, 67, 71, 62], "scale": DORIAN},
	{"name": "Bbmaj9", "root": 34, "voicing": [57, 60, 62, 65], "tones": [58, 62, 65, 69, 60], "scale": AEOLIAN},
	{"name": "G13", "root": 43, "voicing": [53, 57, 59, 64], "tones": [67, 71, 65, 64, 69], "scale": DORIAN},
	{"name": "Em7b5", "root": 40, "voicing": [55, 58, 62, 64], "tones": [64, 67, 70, 62], "scale": AEOLIAN},
	{"name": "A7b9", "root": 45, "voicing": [55, 58, 61, 64], "tones": [61, 64, 67, 70, 69], "scale": HARMONIC},
]
# Sluice: a funk vamp with the same jazz colour, the A7#9 as its sting.
const SLUICE := [
	{"name": "Dm9", "root": 38, "voicing": [53, 57, 60, 64], "tones": [62, 65, 69, 72, 64], "scale": DORIAN},
	{"name": "Dm9", "root": 38, "voicing": [57, 60, 64, 65], "tones": [62, 65, 69, 72, 64], "scale": DORIAN},
	{"name": "G13", "root": 43, "voicing": [53, 57, 59, 64], "tones": [67, 71, 65, 64, 69], "scale": DORIAN},
	{"name": "G13", "root": 43, "voicing": [53, 59, 64, 65], "tones": [67, 71, 65, 64, 69], "scale": DORIAN},
	{"name": "Bbmaj9", "root": 34, "voicing": [57, 60, 62, 65], "tones": [58, 62, 65, 69, 60], "scale": AEOLIAN},
	{"name": "A7#9", "root": 45, "voicing": [55, 61, 64, 72], "tones": [61, 64, 67, 72, 69], "scale": HARMONIC},
	{"name": "Dm9", "root": 38, "voicing": [53, 57, 60, 64], "tones": [62, 65, 69, 72, 64], "scale": DORIAN},
	{"name": "A7b9", "root": 45, "voicing": [55, 58, 61, 64], "tones": [61, 64, 67, 70, 69], "scale": HARMONIC},
]
# Weir: the halfpipe. The chords climb step by step to the A7sus at the top, then roll
# back down the same way.
const WEIR := [
	{"name": "Dm11", "root": 38, "voicing": [53, 55, 60, 64], "tones": [62, 65, 69, 72, 67], "scale": DORIAN},
	{"name": "Em7", "root": 40, "voicing": [55, 59, 62, 67], "tones": [64, 67, 71, 62], "scale": DORIAN},
	{"name": "Fmaj9", "root": 41, "voicing": [52, 55, 57, 60], "tones": [65, 69, 72, 64, 67], "scale": DORIAN},
	{"name": "G13", "root": 43, "voicing": [53, 57, 59, 64], "tones": [67, 71, 65, 64, 69], "scale": DORIAN},
	{"name": "A7sus4", "root": 45, "voicing": [55, 57, 62, 64], "tones": [69, 74, 76, 67], "scale": DORIAN},
	{"name": "G13", "root": 43, "voicing": [53, 57, 59, 64], "tones": [67, 71, 65, 64, 69], "scale": DORIAN},
	{"name": "Fmaj9", "root": 41, "voicing": [52, 55, 57, 60], "tones": [65, 69, 72, 64, 67], "scale": DORIAN},
	{"name": "Em7b5", "root": 40, "voicing": [55, 58, 62, 64], "tones": [64, 67, 70, 62], "scale": AEOLIAN},
]
# Brindle: dramatic. D minor, the Neapolitan Eb and the A7b9, twice round.
const BRINDLE := [
	{"name": "Dm(add9)", "root": 38, "voicing": [53, 57, 62, 64], "tones": [62, 65, 69, 64], "scale": HARMONIC},
	{"name": "Bbmaj7#11", "root": 34, "voicing": [57, 62, 64, 69], "tones": [58, 62, 65, 69, 64], "scale": AEOLIAN},
	{"name": "Ebmaj9", "root": 39, "voicing": [55, 58, 62, 65], "tones": [63, 67, 70, 74, 65], "scale": PHRYGIAN},
	{"name": "A7b9", "root": 45, "voicing": [55, 58, 61, 64], "tones": [61, 64, 67, 70, 69], "scale": HARMONIC},
	{"name": "Dm(add9)", "root": 38, "voicing": [57, 62, 64, 65], "tones": [62, 65, 69, 64], "scale": HARMONIC},
	{"name": "Bbmaj7#11", "root": 34, "voicing": [57, 62, 64, 69], "tones": [58, 62, 65, 69, 64], "scale": AEOLIAN},
	{"name": "Ebmaj9", "root": 39, "voicing": [55, 58, 62, 65], "tones": [63, 67, 70, 74, 65], "scale": PHRYGIAN},
	{"name": "A7b9", "root": 45, "voicing": [55, 58, 61, 64], "tones": [61, 64, 67, 70, 69], "scale": HARMONIC},
]
# The victory: Bb, C, the V, then home in D major, held.
const VICTORY := [
	{"name": "Bbmaj9", "root": 34, "voicing": [57, 60, 62, 65], "tones": [58, 62, 65, 69, 60], "scale": AEOLIAN},
	{"name": "C13", "root": 36, "voicing": [52, 57, 58, 62], "tones": [60, 64, 67, 70, 69], "scale": [0, 2, 4, 5, 7, 9, 10]},
	{"name": "A7b9", "root": 45, "voicing": [55, 58, 61, 64], "tones": [61, 64, 67, 70, 69], "scale": HARMONIC},
	{"name": "Dmaj9", "root": 38, "voicing": [54, 57, 61, 64], "tones": [62, 66, 69, 73, 64], "scale": MAJOR},
]
# The miniboss darkens its level: each bright chord gets its minor twin.
const MINOR_OF := {
	"G13": {"name": "Gm9", "root": 43, "voicing": [53, 57, 58, 62], "tones": [67, 70, 74, 65, 69], "scale": AEOLIAN},
	"Cmaj9": {"name": "Cm9", "root": 36, "voicing": [51, 55, 58, 62], "tones": [60, 63, 67, 70, 62], "scale": PHRYGIAN},
	"Fmaj9": {"name": "Fm9", "root": 41, "voicing": [51, 55, 56, 60], "tones": [65, 68, 72, 63, 67], "scale": PHRYGIAN},
	"Em7": {"name": "Em7b5", "root": 40, "voicing": [55, 58, 62, 64], "tones": [64, 67, 70, 62], "scale": AEOLIAN},
	"A7sus4": {"name": "A7b9", "root": 45, "voicing": [55, 58, 61, 64], "tones": [61, 64, 67, 70, 69], "scale": HARMONIC},
	"Bbmaj9": {"name": "Bb7#11", "root": 34, "voicing": [56, 60, 62, 64], "tones": [58, 62, 65, 68, 64], "scale": AEOLIAN},
}
# Brindle's phase 2: D Phrygian, heavy.
const BRINDLE_PHRYGIAN := [
	{"name": "Dm(b9)", "root": 38, "voicing": [53, 57, 60, 63], "tones": [62, 65, 69, 63], "scale": PHRYGIAN},
	{"name": "Ebmaj9", "root": 39, "voicing": [55, 58, 62, 65], "tones": [63, 67, 70, 74, 65], "scale": PHRYGIAN},
	{"name": "Dm(b9)", "root": 38, "voicing": [57, 60, 63, 65], "tones": [62, 65, 69, 63], "scale": PHRYGIAN},
	{"name": "Cm9", "root": 36, "voicing": [51, 55, 58, 62], "tones": [60, 63, 67, 70, 62], "scale": PHRYGIAN},
]
# The Warden's sinister break: D Phrygian against its tritone, Ab. The bass walks the
# tritone; the melody leans on the flat second.
const LOCRIAN := [0, 1, 3, 5, 6, 8, 10]
const SINISTER := [
	{"name": "Dm(b9)", "root": 38, "voicing": [53, 57, 60, 63], "tones": [62, 65, 69, 63], "scale": PHRYGIAN},
	{"name": "Ab7#11", "root": 44, "voicing": [54, 56, 60, 62], "tones": [68, 72, 63, 66, 62], "scale": LOCRIAN},
	{"name": "Dm(b9)", "root": 38, "voicing": [57, 60, 63, 65], "tones": [62, 65, 69, 63], "scale": PHRYGIAN},
	{"name": "Ebmaj7", "root": 39, "voicing": [55, 58, 62, 63], "tones": [63, 67, 70, 74], "scale": PHRYGIAN},
]
# The pivots a key change passes through: the new key's own V, and the tritone.
const DOMINANT := {"name": "A7b9", "root": 45, "voicing": [55, 58, 61, 64], "tones": [61, 64, 67, 70, 69], "scale": HARMONIC}
const TRITONE := {"name": "Ab7#11", "root": 44, "voicing": [54, 56, 60, 62], "tones": [68, 72, 63, 66, 62], "scale": LOCRIAN}
# The launch build's tune: the rice-cooker climb up the A7, looping while you fly.
const LAUNCH_TUNE := [69, 73, 76, 81, 79, 76, 73, 76]
const THEMES := ["spillway", "sluice", "weir"]
# Each level's motif, its first four notes: the synergy fanfare quotes the current one.
const MOTIF_HEADS := [[69, 72, 74, 76], [74, 77, 79, 81], [62, 65, 69, 72]]

# The leitmotifs (SOUND-STORY.md section 2), one row per id, so a class row's motif and
# an enemy row's family resolve through one lookup. cells are [step, midi, steps] on the
# band grid in D; voice is the cue's instrument; band is the voice a class motif takes
# when it seeds the counter-line, band_octave its register there. Rivet's roll is the
# closed-hat roll under the hammered note; Kest's boom doubles the last thump on the
# 808; the Fleet's stamps are the anvil hits; the swarm's chord is its lock; the Mind
# has no cells of its own and quotes the class motif (mind_quote). Tarn's taps test the
# latch and the long low A tears it loose.
# Tally counts four strokes up the ledger and strikes the total an octave over home.
# The cannon plays the Mind's quote of Sable back to front, one note per family.
const MOTIFS := {
	"sable": {"family": "class", "cells": [[0, 62, 1], [1, 65, 1], [2, 69, 1], [3, 72, 1], [4, 76, 2]], "voice": "mallet", "band": "bell", "band_octave": 12},
	"rivet": {"family": "class", "cells": [[0, 69, 1], [1, 69, 1], [2, 69, 1], [4, 74, 2]], "voice": "clav", "band": "clav", "band_octave": 12, "roll": true},
	"kest": {"family": "class", "cells": [[0, 62, 2], [2, 57, 2], [4, 53, 2], [6, 50, 4]], "voice": "tom", "band": "tom", "band_octave": 12, "boom": true},
	"tarn": {"family": "class", "cells": [[0, 50, 1], [2, 50, 1], [3, 51, 1], [4, 57, 3]], "voice": "reese", "band": "fbass", "band_octave": 12},
	"tally": {"family": "class", "cells": [[0, 62, 1], [1, 64, 1], [2, 65, 1], [3, 67, 1], [5, 74, 3]], "voice": "keys", "band": "beep", "band_octave": 0},
	"cannon": {"family": "class", "cells": [[0, 59, 2], [2, 64, 1], [3, 67, 1], [4, 74, 4]], "voice": "chime", "band": "talk", "band_octave": 0},
	"fleet": {"family": "fleet", "cells": [[0, 50, 2], [4, 50, 2], [6, 51, 2], [8, 50, 4]], "voice": "brass", "stamps": [0, 4]},
	"reactor": {"family": "ancient", "cells": [[0, 44, 16], [0, 56, 16]], "voice": "sub"},
	"swarm": {"family": "ancient", "cells": [[0, 79, 16]], "chord": [74, 79, 84, 89], "voice": "buzz"},
	"mind": {"family": "ancient", "cells": [], "voice": "chime"},
}
const CLASS_MOTIFS := ["sable", "rivet", "kest", "tarn", "tally", "cannon"]


static func family_note(family: String) -> int:
	var index := preload("res://src/boss/mind_attacks.gd").FAMILIES.find(family)
	return int(MOTIFS["cannon"]["cells"][index][1]) if index >= 0 else -1


static func motif(id: String) -> Dictionary:
	return MOTIFS.get(id, {})


# Motif ids already warned about this session, so a pilot row beyond the listed pilots
# warns once rather than every cue.
static var unknown_warned := {}


static func reset_for_tests() -> void:
	unknown_warned.clear()


# The row a cue indexes directly: the id's own, else the first pilot's, warned once per
# unknown id. A pilot added later gets its own row and never reaches the fallback.
static func motif_or_first(id: String) -> Dictionary:
	if MOTIFS.has(id):
		return MOTIFS[id]
	if not unknown_warned.has(id):
		unknown_warned[id] = true
		push_warning("harmony: no motif row for '%s'; cues use %s's" % [id, CLASS_MOTIFS[0]])
	return MOTIFS[CLASS_MOTIFS[0]]


static func motif_notes(id: String) -> Array:
	var notes: Array = []
	for cell in motif(id).get("cells", []):
		notes.append(int(cell[1]))
	return notes


# The Mind's hand quotes a class motif back: every interval flipped around the first
# note, the last note a semitone flat, over the class motif's own rhythm. Sable's
# D F A C E comes back D B G E B.
static func mind_quote(class_id: String) -> Array:
	var cells: Array = motif(class_id).get("cells", [])
	if cells.is_empty():
		return []
	var pivot: int = cells[0][1]
	var quote: Array = []
	for cell in cells:
		quote.append([cell[0], 2 * pivot - int(cell[1]), cell[2]])
	quote[quote.size() - 1][1] -= 1
	return quote


static func level_progression(theme: int) -> Array:
	return [PROGRESSION, SLUICE, WEIR][clampi(theme, 0, 2)]


static func minor_progression(theme: int) -> Array:
	var dark := []
	for chord in level_progression(theme):
		dark.append(MINOR_OF.get(chord["name"], chord))
	return dark


# The stage-clear cadence: the V chord, then D major (a Picardy lift), held like the
# end-of-cycle chime on a rice cooker.
const CADENCE := [
	{"name": "A7b9", "root": 45, "voicing": [55, 58, 61, 64], "tones": [61, 64, 67, 70, 69], "scale": HARMONIC},
	{"name": "Dmaj9", "root": 38, "voicing": [54, 57, 61, 64], "tones": [62, 66, 69, 73, 64], "scale": [0, 2, 4, 7, 9, 11]},
]


static func hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


static func ratio(semitones: float) -> float:
	return pow(2.0, semitones / 12.0)


const NOTE_OFFSETS := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


# A note name as a midi number: C4 is 60, F#3 is 54, Bb2 is 46.
static func note_midi(name: String) -> int:
	var semitone: int = NOTE_OFFSETS.get(name.substr(0, 1), 0)
	var at := 1
	var mark := name.substr(1, 1)
	if mark == "#":
		semitone += 1
		at = 2
	elif mark == "b":
		semitone -= 1
		at = 2
	return 12 * (int(name.substr(at)) + 1) + semitone


# The nth rung of the reward ladder above home, in semitones. Rung 0 is home.
static func pentatonic_step(rung: int) -> int:
	var octave := int(floor(float(rung) / PENTATONIC.size()))
	var index := posmod(rung, PENTATONIC.size())
	return octave * 12 + PENTATONIC[index]


# The pitch ratio that lifts a cue baked on midi by `steps` rungs of the reward ladder, counted
# from its own note: a climb that starts on any rung (the bite's A) stays on D F G A C, where a
# climb by semitones passes through Bb and C#.
static func ladder_ratio(midi: int, steps: int) -> float:
	return ratio(scale_shift(midi, steps, PENTATONIC) - midi)


# The pitch ratio for a cue baked on midi that asks for a free climb in semitones: the climb is
# moved to the nearest rung of the reward ladder, so a curve never lands between the notes.
static func snapped_ratio(midi: int, semitones: float) -> float:
	return ratio(snap(midi + roundi(semitones), PENTATONIC) - midi)


# The chord tone a falling line lands on: the nearest one under midi, never midi itself.
static func tone_below(midi: int, tones: Array) -> int:
	var best := midi - 12
	for tone in tones:
		best = maxi(best, int(tone) + 12 * floori(float(midi - 1 - int(tone)) / 12.0))
	return best


# The nearest note of a scale (relative to home) to a midi note.
static func snap(midi: int, scale: Array) -> int:
	var best := midi
	var best_distance := 99
	for offset in [0, -1, 1, -2, 2]:
		var candidate: int = midi + offset
		if (posmod(candidate - HOME, 12)) in scale and absi(offset) < best_distance:
			best = candidate
			best_distance = absi(offset)
	return best


# Moves a note by scale steps inside a scale.
static func scale_shift(midi: int, steps: int, scale: Array) -> int:
	var note := snap(midi, scale)
	var direction := 1 if steps > 0 else -1
	for _i in absi(steps):
		note += direction
		while not (posmod(note - HOME, 12) in scale):
			note += direction
	return note


# The chord tone nearest to a note, for strong beats and phrase endings.
static func nearest_tone(midi: int, tones: Array) -> int:
	var best := midi
	var best_distance := 99
	for tone in tones:
		for octave in [-24, -12, 0, 12, 24]:
			var candidate: int = tone + octave
			if absi(candidate - midi) < best_distance:
				best = candidate
				best_distance = absi(candidate - midi)
	return best
