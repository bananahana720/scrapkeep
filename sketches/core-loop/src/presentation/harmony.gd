extends RefCounted

const RATE := 44100
const STEP := 3846
const STEPS_PER_BEAT := 4
const BEAT := STEP * STEPS_PER_BEAT
const STEPS_PER_BAR := 16
const BAR := STEP * STEPS_PER_BAR
const PHRASE_BARS := 8
const BPM := 60.0 * RATE / BEAT

const HOME := 62
const DORIAN := [0, 2, 3, 5, 7, 9, 10]
const AEOLIAN := [0, 2, 3, 5, 7, 8, 10]
const HARMONIC := [0, 2, 3, 5, 7, 8, 11]
const PHRYGIAN := [0, 1, 3, 5, 7, 8, 10]
const MAJOR := [0, 2, 4, 5, 7, 9, 11]
const BOSS_STEP := 5128
const BOSS_BEAT := BOSS_STEP * STEPS_PER_BEAT
const PENTATONIC := [0, 3, 5, 7, 10]

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
const VICTORY := [
	{"name": "Bbmaj9", "root": 34, "voicing": [57, 60, 62, 65], "tones": [58, 62, 65, 69, 60], "scale": AEOLIAN},
	{"name": "C13", "root": 36, "voicing": [52, 57, 58, 62], "tones": [60, 64, 67, 70, 69], "scale": [0, 2, 4, 5, 7, 9, 10]},
	{"name": "A7b9", "root": 45, "voicing": [55, 58, 61, 64], "tones": [61, 64, 67, 70, 69], "scale": HARMONIC},
	{"name": "Dmaj9", "root": 38, "voicing": [54, 57, 61, 64], "tones": [62, 66, 69, 73, 64], "scale": MAJOR},
]
const MINOR_OF := {
	"G13": {"name": "Gm9", "root": 43, "voicing": [53, 57, 58, 62], "tones": [67, 70, 74, 65, 69], "scale": AEOLIAN},
	"Cmaj9": {"name": "Cm9", "root": 36, "voicing": [51, 55, 58, 62], "tones": [60, 63, 67, 70, 62], "scale": PHRYGIAN},
	"Fmaj9": {"name": "Fm9", "root": 41, "voicing": [51, 55, 56, 60], "tones": [65, 68, 72, 63, 67], "scale": PHRYGIAN},
	"Em7": {"name": "Em7b5", "root": 40, "voicing": [55, 58, 62, 64], "tones": [64, 67, 70, 62], "scale": AEOLIAN},
	"A7sus4": {"name": "A7b9", "root": 45, "voicing": [55, 58, 61, 64], "tones": [61, 64, 67, 70, 69], "scale": HARMONIC},
	"Bbmaj9": {"name": "Bb7#11", "root": 34, "voicing": [56, 60, 62, 64], "tones": [58, 62, 65, 68, 64], "scale": AEOLIAN},
}
const BRINDLE_PHRYGIAN := [
	{"name": "Dm(b9)", "root": 38, "voicing": [53, 57, 60, 63], "tones": [62, 65, 69, 63], "scale": PHRYGIAN},
	{"name": "Ebmaj9", "root": 39, "voicing": [55, 58, 62, 65], "tones": [63, 67, 70, 74, 65], "scale": PHRYGIAN},
	{"name": "Dm(b9)", "root": 38, "voicing": [57, 60, 63, 65], "tones": [62, 65, 69, 63], "scale": PHRYGIAN},
	{"name": "Cm9", "root": 36, "voicing": [51, 55, 58, 62], "tones": [60, 63, 67, 70, 62], "scale": PHRYGIAN},
]
const LOCRIAN := [0, 1, 3, 5, 6, 8, 10]
const SINISTER := [
	{"name": "Dm(b9)", "root": 38, "voicing": [53, 57, 60, 63], "tones": [62, 65, 69, 63], "scale": PHRYGIAN},
	{"name": "Ab7#11", "root": 44, "voicing": [54, 56, 60, 62], "tones": [68, 72, 63, 66, 62], "scale": LOCRIAN},
	{"name": "Dm(b9)", "root": 38, "voicing": [57, 60, 63, 65], "tones": [62, 65, 69, 63], "scale": PHRYGIAN},
	{"name": "Ebmaj7", "root": 39, "voicing": [55, 58, 62, 63], "tones": [63, 67, 70, 74], "scale": PHRYGIAN},
]
const DOMINANT := {"name": "A7b9", "root": 45, "voicing": [55, 58, 61, 64], "tones": [61, 64, 67, 70, 69], "scale": HARMONIC}
const TRITONE := {"name": "Ab7#11", "root": 44, "voicing": [54, 56, 60, 62], "tones": [68, 72, 63, 66, 62], "scale": LOCRIAN}
const LAUNCH_TUNE := [69, 73, 76, 81, 79, 76, 73, 76]
const THEMES := ["spillway", "sluice", "weir"]
const MOTIF_HEADS := [[69, 72, 74, 76], [74, 77, 79, 81], [62, 65, 69, 72]]

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


static var unknown_warned := {}


static func reset_for_tests() -> void:
	unknown_warned.clear()


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


const CADENCE := [
	{"name": "A7b9", "root": 45, "voicing": [55, 58, 61, 64], "tones": [61, 64, 67, 70, 69], "scale": HARMONIC},
	{"name": "Dmaj9", "root": 38, "voicing": [54, 57, 61, 64], "tones": [62, 66, 69, 73, 64], "scale": [0, 2, 4, 7, 9, 11]},
]


static func hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


static func ratio(semitones: float) -> float:
	return pow(2.0, semitones / 12.0)


const NOTE_OFFSETS := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


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


static func pentatonic_step(rung: int) -> int:
	var octave := int(floor(float(rung) / PENTATONIC.size()))
	var index := posmod(rung, PENTATONIC.size())
	return octave * 12 + PENTATONIC[index]


static func ladder_ratio(midi: int, steps: int) -> float:
	return ratio(scale_shift(midi, steps, PENTATONIC) - midi)


static func snapped_ratio(midi: int, semitones: float) -> float:
	return ratio(snap(midi + roundi(semitones), PENTATONIC) - midi)


static func tone_below(midi: int, tones: Array) -> int:
	var best := midi - 12
	for tone in tones:
		best = maxi(best, int(tone) + 12 * floori(float(midi - 1 - int(tone)) / 12.0))
	return best


static func snap(midi: int, scale: Array) -> int:
	var best := midi
	var best_distance := 99
	for offset in [0, -1, 1, -2, 2]:
		var candidate: int = midi + offset
		if (posmod(candidate - HOME, 12)) in scale and absi(offset) < best_distance:
			best = candidate
			best_distance = absi(offset)
	return best


static func scale_shift(midi: int, steps: int, scale: Array) -> int:
	var note := snap(midi, scale)
	var direction := 1 if steps > 0 else -1
	for _i in absi(steps):
		note += direction
		while not (posmod(note - HOME, 12) in scale):
			note += direction
	return note


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
