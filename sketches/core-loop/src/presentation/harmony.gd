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


# The nth rung of the reward ladder above home, in semitones. Rung 0 is home.
static func pentatonic_step(rung: int) -> int:
	var octave := int(floor(float(rung) / PENTATONIC.size()))
	var index := posmod(rung, PENTATONIC.size())
	return octave * 12 + PENTATONIC[index]


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
