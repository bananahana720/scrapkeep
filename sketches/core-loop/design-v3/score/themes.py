"""Scrapkeep's theme bank: the few written melodies every cue is derived from (SCORE.md).

    python themes.py list                      every cue, its parent theme and devices
    python themes.py guide <cue|all> <out dir> [--seconds 64]
                                               a guide WAV (lead, chords, bass, kick), a lead-only
                                               WAV and a MIDI file per cue
    python themes.py preview <cue|all> <out dir> [--seconds 16]
                                               a fuller stereo arrangement of the same notes
    python themes.py notes <cue>               the cue's derived lead line as note names

A cue is a theme plus devices: take some bars, map onto another mode and key, invert, regroup
the rhythm, change tempo. The guide WAV is a plain mock-up of the result. It is the cover source
for ACE-Step (same mechanism as the round 7 variations), so a render inherits the written melody,
and the reference that check_score.py measures a render against. Standard library and NumPy only.
"""

import struct
import sys
import wave
from pathlib import Path

import numpy as np

SR = 48000
NAMES = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

# Scales as semitones above the tonic, matching harmony.gd.
DORIAN = [0, 2, 3, 5, 7, 9, 10]
AEOLIAN = [0, 2, 3, 5, 7, 8, 10]
PHRYGIAN = [0, 1, 3, 5, 7, 8, 10]
LYDIAN_MINOR_FLOOR = [0, 2, 3, 6, 7, 9, 10]  # Highdraft: minor third underneath, raised fourth on top
MAJOR = [0, 2, 4, 5, 7, 9, 11]
MODES = {"dorian": DORIAN, "aeolian": AEOLIAN, "phrygian": PHRYGIAN, "lydian_minor": LYDIAN_MINOR_FLOOR, "major": MAJOR}
TONIC = {"D": 62, "E": 64, "G": 67}

# Notes are (beat, midi, beats) in 4/4. Chords are (name, bass midi, voicing) one per bar, taken
# from harmony.gd so the rendered band and the procedural band play the same changes.
PROGRESSION = [
    ("Dm9", 38, [53, 57, 60, 64]), ("G13", 43, [53, 57, 59, 64]),
    ("Dm9", 38, [57, 60, 64, 65]), ("Cmaj9", 36, [55, 59, 62, 64]),
    ("Bbmaj9", 34, [57, 60, 62, 65]), ("G13", 43, [53, 57, 59, 64]),
    ("Em7b5", 40, [55, 58, 62, 64]), ("A7b9", 45, [55, 58, 61, 64]),
]
BRINDLE = [
    ("Dm(add9)", 38, [53, 57, 62, 64]), ("Bbmaj7#11", 34, [57, 62, 64, 69]),
    ("Ebmaj9", 39, [55, 58, 62, 65]), ("A7b9", 45, [55, 58, 61, 64]),
]
VICTORY = [
    ("Bbmaj9", 34, [57, 60, 62, 65]), ("C13", 36, [52, 57, 58, 62]),
    ("A7b9", 45, [55, 58, 61, 64]), ("Dmaj9", 38, [54, 57, 61, 64]),
]


def bars(*rows):
    """Bar-relative rows [(beat, midi, beats), ...] per bar into one absolute note list."""
    return [(4 * i + b, m, d) for i, row in enumerate(rows) for b, m, d in row]


# K, the Keepers' theme. Title A, the pilots and the worlds. Swung, alto sax, D Dorian.
# Bar 1 is Sable's motif (harmony.gd MOTIFS["sable"]: D F A C E) as the call; bar 2 falls back as
# the answer; bar 3 repeats the call with the octave leap; bars 5 to 8 are the consequent, which
# dips through Bb (the crash colour) and hangs on the A7b9 that the ending finally resolves.
KEEPERS = {
    "name": "Keepers' theme", "chords": PROGRESSION, "swing": True, "mode": "dorian", "tonic": "D",
    "notes": bars(
        [(0, 62, .5), (.5, 65, .5), (1, 69, .5), (1.5, 72, .5), (2, 76, 1.5)],
        [(0, 74, .5), (.5, 72, .5), (1, 71, 1), (2, 69, .5), (2.5, 67, .5), (3, 65, 1)],
        [(0, 62, .5), (.5, 65, .5), (1, 69, .5), (1.5, 74, .5), (2, 77, 1.5)],
        [(0, 76, .5), (.5, 74, .5), (1, 72, 1), (2, 71, .5), (2.5, 67, .5), (3, 64, 1)],
        [(0, 77, 1.5), (1.5, 76, .5), (2, 74, .5), (2.5, 72, .5), (3, 69, 1)],
        [(0, 71, .5), (.5, 74, .5), (1, 76, 1), (2, 77, .5), (2.5, 76, .5), (3, 74, 1)],
        [(0, 67, 1), (1, 70, .5), (1.5, 74, .5), (2, 72, .5), (2.5, 70, .5), (3, 67, 1)],
        [(0, 73, 1), (1, 69, .5), (1.5, 70, .5), (2, 69, 2)],
    ),
}

# M, the Machine theme. Title B, the Furnace Fleet and every boss. Straight eighths that never
# swing. Each bar opens on the Fleet stamp (harmony.gd MOTIFS["fleet"]: D D Eb D, anvil, anvil,
# brass lean, anvil) and then issues its decree. The lean always falls back down: the machine
# never lets go. Bar 3 is the stamp a semitone up on the Neapolitan Eb, the Fleet grown to Brindle.
MACHINE = {
    "name": "Machine theme", "chords": BRINDLE, "swing": False, "mode": "aeolian", "tonic": "D",
    "notes": bars(
        [(0, 62, .5), (.5, 62, .5), (1, 63, .5), (1.5, 62, .5), (2, 69, 1), (3, 65, .5), (3.5, 62, .5)],
        [(0, 62, .5), (.5, 62, .5), (1, 63, .5), (1.5, 62, .5), (2, 76, 1), (3, 74, 1)],
        [(0, 63, .5), (.5, 63, .5), (1, 65, .5), (1.5, 63, .5), (2, 67, .5), (2.5, 70, .5), (3, 74, 1)],
        [(0, 73, 1), (1, 70, 1), (2, 69, 2)],
    ),
}

# S, the Show theme. Title C, world clears, the run summary and the ending. The chorus hook opens
# on the octave leap, and bar 3 is the Fleet's lean resolved upward (D Eb E): the one place the
# machine lets go, which is the story's point (nobody is evil). Lands on D major: the payoff.
SHOW = {
    "name": "Show theme", "chords": VICTORY, "swing": True, "mode": "major", "tonic": "D",
    "notes": bars(
        [(0, 62, .5), (.5, 74, 1), (1.5, 72, .5), (2, 69, .5), (2.5, 65, .5), (3, 69, 1)],
        [(0, 67, .5), (.5, 72, .5), (1, 76, 1.5), (2.5, 74, .5), (3, 72, .5), (3.5, 70, .5)],
        [(0, 74, .5), (.5, 75, .5), (1, 76, 1), (2, 73, .5), (2.5, 69, .5), (3, 67, 1)],
        [(0, 78, 2), (2, 76, 1), (3, 74, 1)],
    ),
}

THEMES = {"K": KEEPERS, "M": MACHINE, "S": SHOW}


# devices --------------------------------------------------------------------------------------

def take_bars(notes, first, last):
    """Bars first..last (1-based, inclusive), re-timed to start at beat 0."""
    lo, hi = 4 * (first - 1), 4 * last
    return [(b - lo, m, d) for b, m, d in notes if lo <= b < hi]


def remap(midi, src_tonic, src_scale, dst_tonic, dst_scale):
    """Moves a note to the same scale degree in another mode and key. A note outside the source
    scale keeps its offset from the nearest degree below, so chromatic colour survives."""
    rel = midi - src_tonic
    octave, pc = divmod(rel, 12)
    degree = max(i for i, s in enumerate(src_scale) if s <= pc)
    return dst_tonic + 12 * octave + dst_scale[degree] + (pc - src_scale[degree])


def to_mode(theme, notes, chords, tonic, mode):
    src_t, src_s = TONIC[theme["tonic"]], MODES[theme["mode"]]
    dst_t, dst_s = TONIC[tonic], MODES[mode]
    if (src_t, src_s) == (dst_t, dst_s):
        return list(notes), list(chords)
    move = lambda m: remap(m, src_t, src_s, dst_t, dst_s)  # noqa: E731
    shift = dst_t - src_t
    new_chords = [(f"{NAMES[(bass + shift) % 12]} bass", bass + shift, [move(v) for v in voicing]) for _, bass, voicing in chords]
    return [(b, move(m), d) for b, m, d in notes], new_chords


def invert(notes):
    """The Mind's rule from harmony.gd mind_quote: every interval flipped around the first note,
    the last note a semitone flat."""
    pivot = notes[0][1]
    out = [(b, 2 * pivot - m, d) for b, m, d in notes]
    b, m, d = out[-1]
    out[-1] = (b, m - 1, d)
    return out


def regroup_332(notes):
    """The Waking's compression: each bar's onsets slide onto a 3+3+2 eighth grid, so the
    straight stamp limps into the ancient accent."""
    grid = [0, 1.5, 3]
    out = []
    for bar in sorted({int(b // 4) for b, _, _ in notes}):
        row = [n for n in notes if int(n[0] // 4) == bar]
        for i, (_, m, _) in enumerate(row[:3]):
            out.append((4 * bar + grid[i], m, 1.5 if i < 2 else 1))
    return out


def octave(notes, shift):
    return [(b, m + 12 * shift, d) for b, m, d in notes]


def unresolved(notes):
    """Cuts the final note short so the phrase hangs on its last chord."""
    b, m, d = notes[-1]
    return notes[:-1] + [(b, m, min(d, .5))]


# the cue sheet ---------------------------------------------------------------------------------
# One row per cue in the soundtrack. theme: parent; bars: which of its bars; tonic, mode: target;
# bpm and swing; devices: names applied in order; lead: the lead voice for the caption; job: the
# story beat the cue carries. Journey arc for K: Spillway states the call (bars 1 to 2), the Dig
# adds the answer (1 to 4), the Highdraft plays all 8 but hangs, and only the ending resolves it.

CUES = {
    "title-a": dict(theme="K", bars=(1, 8), tonic="D", mode="dorian", bpm=129, lead="alto sax", job="the keepers, first launch"),
    "title-b": dict(theme="M", bars=(1, 4), tonic="D", mode="aeolian", bpm=129, lead="machine lead, sax answering", job="the machine calls"),
    "title-c": dict(theme="S", bars=(1, 4), tonic="D", mode="major", bpm=172, lead="tenor sax and brass", job="the show opening"),
    "camp": dict(theme="K", bars=(1, 4), tonic="D", mode="dorian", bpm=129, devices=["half_time"], lead="tenor sax over Rhodes, ballad", job="home, not finished"),
    "spillway-loop": dict(theme="K", bars=(1, 2), tonic="D", mode="dorian", bpm=129, lead="bright alto sax", job="world 1: the call"),
    "roam-spillway": dict(theme="K", bars=(1, 2), tonic="D", mode="dorian", bpm=172, lead="bright alto sax", job="world 1 roaming"),
    "dig-loop": dict(theme="K", bars=(1, 4), tonic="E", mode="phrygian", bpm=129, devices=["half_time", "down_octave"], lead="baritone sax", job="world 2: call and answer, in the dark"),
    "roam-dig": dict(theme="K", bars=(1, 4), tonic="E", mode="phrygian", bpm=172, devices=["down_octave"], lead="baritone sax", job="world 2 roaming"),
    "highdraft-loop": dict(theme="K", bars=(1, 8), tonic="G", mode="lydian_minor", bpm=129, devices=["unresolved"], lead="soprano sax", job="world 3: the whole theme, hanging"),
    "roam-highdraft": dict(theme="K", bars=(1, 8), tonic="G", mode="lydian_minor", bpm=172, devices=["unresolved"], lead="soprano sax", job="world 3 roaming"),
    "combat-hype": dict(theme="K", bars=(1, 2), tonic="D", mode="dorian", bpm=129, against="M", lead="tenor sax hook over the Fleet stamp", job="every fight: your call over their stamp"),
    "champion": dict(theme="K", bars=(1, 2), tonic="D", mode="dorian", bpm=129, against="M", devices=["up_octave"], lead="tenor sax, brass a third above", job="golden fight"),
    "boss-brindle": dict(theme="M", bars=(1, 4), tonic="D", mode="aeolian", bpm=129, answer="K", lead="machine lead, alto answering", job="the duel: he states, you answer"),
    "boss-brindle-p3": dict(theme="M", bars=(1, 4), tonic="D", mode="aeolian", bpm=172, swing=True, answer="K", lead="machine lead cracking into swing", job="his arithmetic breaks"),
    "boss-waking": dict(theme="M", bars=(1, 4), tonic="E", mode="phrygian", bpm=129, devices=["regroup_332", "down_octave"], answer="K", lead="stacked-fourths hum, baritone answering", job="something old, woken"),
    "boss-mind": dict(theme="K", bars=(1, 8), tonic="G", mode="lydian_minor", bpm=129, devices=["invert"], lead="sine chime, soprano answering", job="your own song, backwards"),
    "boss-mind-final": dict(theme="K", bars=(1, 8), tonic="G", mode="major", bpm=145, lead="soprano sax, full band", job="the Mind learns your song the right way up"),
    "euro-brindle-p3": dict(theme="M", bars=(1, 4), tonic="D", mode="aeolian", bpm=145, answer="K", lead="supersaw stabs, sax hook", job="hype drop"),
    "euro-waking-final": dict(theme="M", bars=(1, 4), tonic="E", mode="phrygian", bpm=145, devices=["regroup_332"], answer="K", lead="supersaw stabs, bari hook", job="hype drop"),
    "euro-mind-final": dict(theme="K", bars=(1, 8), tonic="G", mode="major", bpm=145, lead="supersaw stabs, soprano hook", job="hype drop"),
    "summary-win": dict(theme="S", bars=(1, 4), tonic="D", mode="major", bpm=129, lead="brass fanfare", job="the swing's back-up beat"),
    "summary-loss": dict(theme="K", bars=(5, 8), tonic="D", mode="dorian", bpm=129, devices=["half_time"], lead="one sax over Rhodes, then a bell", job="the crash phrase, then the wink"),
    "ending": dict(theme="S", bars=(1, 4), tonic="D", mode="major", bpm=172, against="K", lead="full band, K and M together", job="the theme resolves; the machine lets go"),
    "secret-spillway": dict(theme="K", bars=(1, 2), tonic="D", mode="dorian", bpm=172, devices=["up_octave"], lead="music box", job="hidden: same tune, new room"),
    "secret-dig": dict(theme="K", bars=(1, 4), tonic="E", mode="phrygian", bpm=172, lead="upright piano", job="hidden: speakeasy"),
    "secret-highdraft": dict(theme="K", bars=(1, 8), tonic="G", mode="lydian_minor", bpm=172, devices=["unresolved"], lead="vibraphone and harp", job="hidden: cloud chamber"),
    "scrap-rush": dict(theme="M", bars=(1, 4), tonic="D", mode="aeolian", bpm=150, lead="game-show brass", job="event countdown"),
    "minigame": dict(theme="K", bars=(1, 4), tonic="D", mode="dorian", bpm=129, lead="8-bit square", job="game inside the game"),
}


def derive(cue):
    """The cue's lead notes and chords, in its own key and mode, at the cue's meter."""
    row = CUES[cue]
    theme = THEMES[row["theme"]]
    first, last = row["bars"]
    notes = take_bars(theme["notes"], first, last)
    chords = theme["chords"][(first - 1) % len(theme["chords"]):][: last - first + 1]
    notes, chords = to_mode(theme, notes, chords, row["tonic"], row["mode"])
    for device in row.get("devices", []):
        if device == "invert":
            notes = invert(notes)
        elif device == "regroup_332":
            notes = regroup_332(notes)
        elif device == "down_octave":
            notes = octave(notes, -1)
        elif device == "up_octave":
            notes = octave(notes, 1)
        elif device == "unresolved":
            notes = unresolved(notes)
        elif device == "half_time":
            notes = [(2 * b, m, 2 * d) for b, m, d in notes]
            chords = [c for c in chords for _ in (0, 1)]
    swing = row.get("swing", theme["swing"])
    return notes, chords, swing


def counter(cue):
    """The other theme a cue carries, in the cue's key, laid out over the cue's own bars.
    answer: the pilot's reply after the boss's statement, as (beat, midi, beats) shifted past the
    phrase (the duel). against: the other theme underneath, an octave down, at the same time."""
    row = CUES[cue]
    notes, chords, _ = derive(cue)
    other = row.get("answer") or row.get("against")
    if not other:
        return [], chords
    theme = THEMES[other]
    span = 4 * len(chords)
    part = take_bars(theme["notes"], 1, 2 if row.get("answer") else len(chords))
    part, _ = to_mode(theme, part, [], row["tonic"], row["mode"])
    if row.get("against"):
        return octave(part, -1), chords
    return [(b + span, m, d) for b, m, d in part], chords + chords[:2]


def name(midi):
    return f"{NAMES[midi % 12]}{midi // 12 - 1}"


# guide audio -----------------------------------------------------------------------------------

def swung(beat, swing):
    """Moves an off-beat eighth to the last triplet of its beat."""
    whole, frac = divmod(beat, 1)
    return whole + (2 / 3 if swing and abs(frac - .5) < 1e-6 else frac)


def tone(midi, seconds, kind):
    t = np.arange(int(seconds * SR)) / SR
    f = 440 * 2 ** ((midi - 69) / 12)
    if kind == "lead":  # a reedy saw-ish voice with a little vibrato after the attack
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(t / 0.15, 1)
        phase = 2 * np.pi * f * np.cumsum(vib) / SR
        wave_ = sum(np.sin(k * phase) / k for k in range(1, 7))
        env = np.minimum(t / 0.02, 1) * np.exp(-t * 0.8)
    elif kind == "pad":
        wave_ = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t)
        env = np.minimum(t / 0.01, 1) * np.exp(-t * 1.6)
    else:  # bass
        wave_ = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(4 * np.pi * f * t)
        env = np.minimum(t / 0.005, 1) * np.exp(-t * 3)
    rel = np.minimum((seconds - t) / 0.02, 1)
    return wave_ * env * np.clip(rel, 0, 1)


def kick(seconds=0.25):
    t = np.arange(int(seconds * SR)) / SR
    return np.sin(2 * np.pi * np.cumsum(50 + 100 * np.exp(-t * 30)) / SR) * np.exp(-t * 14)


def put(buf, sig, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    sig = sig[: len(buf) - i]
    buf[i: i + len(sig)] += sig


def render(cue, seconds=64.0):
    """(full guide, lead only) as float arrays. The phrase loops to fill the length."""
    notes, chords, swing = derive(cue)
    under, chords = counter(cue)
    bpm = CUES[cue]["bpm"]
    spb = 60 / bpm
    phrase = 4 * len(chords)
    n = int(seconds * SR)
    lead, band = np.zeros(n), np.zeros(n)
    loops = int(np.ceil(seconds / (phrase * spb)))
    for k in range(loops):
        start = k * phrase
        for b, m, d in notes:
            put(lead, 0.32 * tone(m, d * spb * 0.95, "lead"), (start + swung(b, swing)) * spb)
        for b, m, d in under:
            put(band, 0.22 * tone(m, d * spb * 0.95, "lead"), (start + swung(b, swing)) * spb)
        for i, (_, bass, voicing) in enumerate(chords):
            bar = start + 4 * i
            for v in voicing:
                put(band, 0.08 * tone(v, 4 * spb, "pad"), bar * spb)
            for beat in (0, 2.5):
                put(band, 0.30 * tone(bass, spb, "bass"), (bar + swung(beat, swing)) * spb)
            for beat in range(4):
                put(band, 0.45 * kick(), (bar + beat) * spb)
    full = lead + band
    peak = np.abs(full).max() or 1
    return full / peak * 0.8, lead / (np.abs(lead).max() or 1) * 0.8


# preview audio: a fuller stereo mock-up of the same notes, for ears and for a richer cover source.
# The plain guide above stays the reference check_score.py measures against.

RNG = np.random.default_rng(129)


def spectral(x, lo=None, hi=None):
    """Band-limits a whole buffer in the frequency domain (no SciPy needed)."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    gain = np.ones_like(f)
    if hi:
        gain /= np.sqrt(1 + (f / hi) ** 4)
    if lo:
        gain /= np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** 4)
    return np.fft.irfft(spec * gain, len(x))


def sax(midi, seconds):
    """FM reed: a brightness envelope that blooms then settles, a scoop into pitch, delayed
    vibrato and breath noise. Close enough to read as a horn line in a mock-up."""
    t = np.arange(int(seconds * SR)) / SR
    f = 440 * 2 ** ((midi - 69) / 12)
    scoop = 1 - 0.03 * np.exp(-t * 40)
    vib = 1 + 0.005 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.18) / 0.2, 0, 1)
    phase = 2 * np.pi * f * np.cumsum(scoop * vib) / SR
    index = 1.2 + 1.6 * np.exp(-t * 6) + 0.4 * np.minimum(t / 0.05, 1)
    body = np.sin(phase + index * np.sin(phase) + 0.3 * np.sin(2 * phase))
    breath = spectral(RNG.standard_normal(len(t)), lo=f * 2, hi=f * 6) * 0.08
    env = np.minimum(t / 0.035, 1) * (0.8 + 0.2 * np.exp(-t * 3)) * np.clip((seconds - t) / 0.04, 0, 1)
    return (body + breath) * env


def rhodes(midi, seconds):
    t = np.arange(int(seconds * SR)) / SR
    f = 440 * 2 ** ((midi - 69) / 12)
    tine = np.sin(2 * np.pi * f * 14 * t) * np.exp(-t * 30) * 0.15
    body = np.sin(2 * np.pi * f * t + (0.9 * np.exp(-t * 4)) * np.sin(2 * np.pi * f * t))
    trem = 1 + 0.12 * np.sin(2 * np.pi * 4.5 * t)
    return (body + tine) * np.exp(-t * 1.2) * trem * np.clip((seconds - t) / 0.05, 0, 1)


def mute_brass(midi, seconds):
    t = np.arange(int(seconds * SR)) / SR
    f = 440 * 2 ** ((midi - 69) / 12)
    phase = 2 * np.pi * f * t
    body = sum(np.sin(k * phase) / k ** 1.3 for k in range(1, 9))
    return body * np.minimum(t / 0.02, 1) * np.exp(-t * 1.5) * np.clip((seconds - t) / 0.03, 0, 1)


def reese(midi, seconds):
    t = np.arange(int(seconds * SR)) / SR
    f = 440 * 2 ** ((midi - 69) / 12)
    saw = sum(np.sin(2 * np.pi * f * d * k * t) / k for d in (0.997, 1.003) for k in range(1, 6))
    return (np.tanh(1.5 * saw) * 0.6 + np.sin(2 * np.pi * f * t)) * np.exp(-t * 2.5) * np.clip((seconds - t) / 0.01, 0, 1)


def drum(kind):
    t = np.arange(int(0.4 * SR)) / SR
    if kind == "kick":
        return np.tanh(2 * np.sin(2 * np.pi * np.cumsum(45 + 120 * np.exp(-t * 35)) / SR) * np.exp(-t * 9))
    noise = RNG.standard_normal(len(t))
    if kind == "clap":
        bursts = sum(np.exp(-np.maximum(t - d, 0) * 60) * (t >= d) for d in (0, 0.011, 0.022))
        return spectral(noise, lo=900, hi=4000) * (bursts + 0.4 * np.exp(-t * 18)) * 0.9
    if kind == "hat":
        return spectral(noise, lo=7000) * np.exp(-t * 70) * 0.5
    return spectral(noise, lo=6000) * np.exp(-t * 9) * 0.35  # open hat


def room(stereo, seconds=1.8, wet=0.35):
    """Convolution with a decaying noise tail, decorrelated per side: the sound stage."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = stereo.copy()
    for ch in (0, 1):
        ir = spectral(RNG.standard_normal(n), lo=200, hi=7000) * np.exp(-t * 6.9 / seconds)
        ir[: int(0.012 * SR)] = 0
        size = len(stereo) + n
        tail = np.fft.irfft(np.fft.rfft(stereo[:, ch], size) * np.fft.rfft(ir, size), size)[: len(stereo)]
        out[:, ch] += wet * tail / (np.abs(ir).sum() ** 0.5)
    return out


def preview(cue, seconds=16.0):
    """A stereo arrangement of the cue: sax lead centre-left, muted brass counter right, Rhodes
    comping left, reese bass and four-on-the-floor centre, clap and hats, kick-sidechained band,
    room reverb and a soft-clipped master. Same notes as the guide."""
    notes, chords, swing = derive(cue)
    under, chords = counter(cue)
    spb = 60 / CUES[cue]["bpm"]
    phrase = 4 * len(chords)
    n = int(seconds * SR)
    layers = {k: np.zeros(n) for k in ("lead", "counter", "keys", "bass", "kick", "perc")}
    pan = {"lead": -0.12, "counter": 0.6, "keys": -0.6, "bass": 0, "kick": 0, "perc": 0.3}
    at = lambda start, beat: (start + swung(beat, swing)) * spb  # noqa: E731
    for k in range(int(np.ceil(seconds / (phrase * spb)))):
        start = k * phrase
        for b, m, d in notes:
            put(layers["lead"], 0.30 * sax(m, d * spb * 0.97), at(start, b))
        for b, m, d in under:
            put(layers["counter"], 0.16 * mute_brass(m, d * spb * 0.9), at(start, b))
        for i, (_, root, voicing) in enumerate(chords):
            bar = start + 4 * i
            for hit, length in ((0, 1.2), (1.5, 2.2)):
                for j, v in enumerate(voicing):
                    put(layers["keys"], 0.07 * rhodes(v, length * spb), at(bar, hit) * 1 + j * 0.006)
            nxt = chords[(i + 1) % len(chords)][1]
            for beat, note in ((0, root), (1.5, root), (2.5, root + 7), (3.5, nxt - 1)):
                put(layers["bass"], 0.26 * reese(note, 0.45 * spb), at(bar, beat))
            for beat in range(4):
                put(layers["kick"], 0.55 * drum("kick"), (bar + beat) * spb)
                put(layers["perc"], 0.10 * drum("hat"), at(bar, beat + 0.5) if swing else (bar + beat + 0.5) * spb)
                put(layers["perc"], 0.05 * drum("hat"), (bar + beat) * spb)
            for beat in (1, 3):
                put(layers["perc"], 0.28 * drum("clap"), (bar + beat) * spb)
            put(layers["perc"], 0.12 * drum("open"), (bar + 3.5) * spb)
    # House pump: the band ducks under every kick and swells back across the beat.
    beat_phase = (np.arange(n) / SR % spb) / spb
    pump = 0.55 + 0.45 * np.minimum(beat_phase / 0.45, 1)
    for k in ("keys", "bass", "counter"):
        layers[k] *= pump
    stereo = np.zeros((n, 2))
    for k, x in layers.items():
        p = pan[k]
        stereo[:, 0] += x * np.sqrt((1 - p) / 2)
        stereo[:, 1] += x * np.sqrt((1 + p) / 2)
    dry_low = stereo.copy()
    stereo = room(stereo)
    stereo = 0.85 * stereo + 0.15 * dry_low
    stereo = np.tanh(1.4 * stereo / (np.abs(stereo).max() or 1)) / np.tanh(1.4)
    return stereo * 0.9


def write_wav(path, audio):
    audio = np.asarray(audio)
    channels = 1 if audio.ndim == 1 else audio.shape[1]
    data = (np.clip(audio, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def write_midi(path, cue):
    """Type 1 MIDI, 480 ticks a beat: tempo, lead (channel 1), chords (2), bass (3), counter (4)."""
    notes, chords, swing = derive(cue)
    under, chords = counter(cue)
    tpb = 480

    def vlq(v):
        out = [v & 0x7F]
        while v > 0x7F:
            v >>= 7
            out.insert(0, (v & 0x7F) | 0x80)
        return bytes(out)

    def track(events):
        events.sort(key=lambda e: (e[0], e[1]))
        body, now = b"", 0
        for tick, _, msg in events:
            body += vlq(tick - now) + msg
            now = tick
        body += b"\x00\xff\x2f\x00"
        return b"MTrk" + struct.pack(">I", len(body)) + body

    def note_events(rows, ch):
        ev = []
        for b, m, d in rows:
            on = int(round(swung(b, swing) * tpb))
            ev.append((on, 1, bytes([0x90 | ch, m, 96])))
            ev.append((on + int(d * tpb * 0.95), 0, bytes([0x80 | ch, m, 0])))
        return ev

    tempo = int(60_000_000 / CUES[cue]["bpm"])
    meta = track([(0, 0, b"\xff\x51\x03" + tempo.to_bytes(3, "big"))])
    pads = [(4 * i, v, 4) for i, (_, _, voicing) in enumerate(chords) for v in voicing]
    bass = [(4 * i + beat, root, 1) for i, (_, root, _) in enumerate(chords) for beat in (0, 2.5)]
    data = b"MThd" + struct.pack(">HHH", 1, 5, tpb) + meta
    data += track(note_events(notes, 0)) + track(note_events(pads, 1)) + track(note_events(bass, 2))
    data += track(note_events(under, 3))
    Path(path).write_bytes(data)


def main(argv):
    if not argv or argv[0] == "list":
        for cue, row in CUES.items():
            print(f"{cue:18} {row['theme']} bars {row['bars'][0]}-{row['bars'][1]:<2} {row['tonic']:2} {row['mode']:12} "
                  f"{row['bpm']:3} {','.join(row.get('devices', [])):22} {row['job']}")
        return 0
    if argv[0] == "notes":
        notes, chords, swing = derive(argv[1])
        print(" | ".join(c[0] for c in chords), "(swung)" if swing else "(straight)")
        print(" ".join(name(m) for _, m, _ in notes))
        return 0
    if argv[0] == "guide":
        out = Path(argv[2])
        out.mkdir(parents=True, exist_ok=True)
        seconds = float(argv[argv.index("--seconds") + 1]) if "--seconds" in argv else 64.0
        for cue in CUES if argv[1] == "all" else [argv[1]]:
            full, lead = render(cue, seconds)
            write_wav(out / f"guide-{cue}.wav", full)
            write_wav(out / f"lead-{cue}.wav", lead)
            write_midi(out / f"{cue}.mid", cue)
        print(f"wrote guides to {out}")
        return 0
    if argv[0] == "preview":
        out = Path(argv[2])
        out.mkdir(parents=True, exist_ok=True)
        seconds = float(argv[argv.index("--seconds") + 1]) if "--seconds" in argv else 16.0
        for cue in CUES if argv[1] == "all" else [argv[1]]:
            write_wav(out / f"preview-{cue}.wav", preview(cue, seconds))
        print(f"wrote previews to {out}")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
