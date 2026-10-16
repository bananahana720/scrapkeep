"""Five Scrapkeep event sounds from the 2026-10-16 sound bible, synthesized from code.

    python event_sounds.py <out_dir>

Every pitch comes from D Dorian, the home key of the title and Spillway music, so an
event never clashes with the band. Writes 48 kHz mono WAVs peaking at -1 dBFS.
"""

import sys
from pathlib import Path

import numpy as np
import soundfile as sf

SR = 48000
RNG = np.random.default_rng(1016)


def hz(note):
    names = {"C": 0, "C#": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "F#": 6, "G": 7,
             "G#": 8, "A": 9, "Bb": 10, "B": 11}
    return 440.0 * 2 ** ((names[note[:-1]] + 12 * (int(note[-1]) + 1) - 69) / 12)


def t_of(seconds):
    return np.arange(int(seconds * SR)) / SR


def env(seconds, attack, decay):
    t = t_of(seconds)
    return np.minimum(t / attack, 1.0) * np.exp(-t / decay)


def place(buf, sound, at):
    i = int(at * SR)
    buf[i:i + len(sound)] += sound[:len(buf) - i]


def rhodes(note, seconds, level=1.0):
    """FM electric piano: a 1:1 body plus a 14:1 tine that dies fast."""
    f, t = hz(note), t_of(seconds)
    index = 1.6 * np.exp(-t / 0.25)
    body = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * f * t))
    tine = 0.25 * np.sin(2 * np.pi * 14 * f * t) * np.exp(-t / 0.03)
    return level * (body + tine) * env(seconds, 0.002, seconds / 3)


def bell(note, seconds, ratio=3.5, level=1.0):
    """Inharmonic FM bell: the metal in the scrap."""
    f, t = hz(note), t_of(seconds)
    index = 3.0 * np.exp(-t / 0.08)
    return level * np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * ratio * f * t)) \
        * env(seconds, 0.001, seconds / 4)


def sax(note, seconds, level=1.0, bend=0.0):
    """Additive reed: odd-heavy harmonics, breath noise, delayed vibrato, a scoop up into the note."""
    f, t = hz(note), t_of(seconds)
    scoop = 1 - (0.03 + bend) * np.exp(-t / 0.04)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(t / 0.25, 1)
    phase = 2 * np.pi * np.cumsum(f * scoop * vib) / SR
    tone = sum((0.9 if k % 2 else 0.45) / k * np.sin(k * phase) for k in range(1, 9))
    breath = 0.04 * np.convolve(RNG.standard_normal(len(t)), np.ones(6) / 6, "same")
    shape = np.minimum(t / 0.025, 1) * np.minimum((seconds - t) / 0.06, 1).clip(0, 1)
    return level * (tone + breath) * shape


def noise_burst(seconds, decay, smooth):
    n = np.convolve(RNG.standard_normal(int(seconds * SR)), np.ones(smooth) / smooth, "same")
    return n * env(seconds, 0.0005, decay)


def pluck(note, seconds, damp=0.996, level=1.0):
    """Karplus-Strong string: the harpoon cable."""
    period = int(SR / hz(note))
    buf = RNG.uniform(-1, 1, period)
    out = np.empty(int(seconds * SR))
    for i in range(len(out)):
        out[i] = buf[i % period]
        buf[i % period] = damp * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return level * out


def scrap_pickup():
    """Two rising metal tinks, A5 then D6, the fifth landing home. About 0.2 s."""
    out = np.zeros(int(0.24 * SR))
    place(out, bell("A5", 0.12, level=0.6) + rhodes("A5", 0.12, 0.3), 0.0)
    place(out, bell("D6", 0.18, level=0.8) + rhodes("D6", 0.18, 0.4), 0.055)
    place(out, noise_burst(0.01, 0.002, 2) * 0.3, 0.0)
    return out


def harpoon_hit():
    """A dull thunk, a low boom dropping in pitch, then the cable twanging on D2. About 0.5 s."""
    seconds = 0.55
    t = t_of(seconds)
    boom = np.sin(2 * np.pi * np.cumsum(60 + 90 * np.exp(-t / 0.03)) / SR) * env(seconds, 0.001, 0.12)
    thunk = noise_burst(0.08, 0.015, 40) * 1.4
    out = boom * 1.1
    place(out, thunk, 0.0)
    place(out, pluck("D2", 0.5, 0.995, 0.5) * env(0.5, 0.003, 0.18), 0.012)
    place(out, noise_burst(0.02, 0.004, 1) * 0.25, 0.0)
    return out


def run_complete():
    """The end-of-cycle chime: a tenor sax bebop pickup over Em9 to A13, landing on D major 6/9."""
    out = np.zeros(int(3.2 * SR))
    line = [("E4", 0.00, 0.14), ("F#4", 0.14, 0.14), ("A4", 0.28, 0.14), ("B4", 0.42, 0.14),
            ("C#5", 0.56, 0.22), ("B4", 0.78, 0.12), ("C#5", 0.90, 0.12), ("D5", 1.02, 1.2)]
    for note, at, length in line:
        place(out, sax(note, length, 0.28, bend=0.04 if note == "D5" else 0.0), at)
    for note in ("E3", "G3", "B3", "D4", "F#4"):        # Em9 under the pickup
        place(out, rhodes(note, 0.6, 0.12), 0.0)
    for note in ("A2", "G3", "C#4", "F#4"):             # A13 under the turn
        place(out, rhodes(note, 0.5, 0.12), 0.56)
    for note in ("D3", "A3", "B3", "E4", "F#4"):        # D6/9, the arrival
        place(out, rhodes(note, 2.0, 0.14), 1.02)
    for i, note in enumerate(("D6", "F#6", "A6", "D7")):  # the rice-cooker bells climbing out
        place(out, bell(note, 0.9, ratio=2.0, level=0.18), 1.3 + 0.12 * i)
    hiss = noise_burst(0.9, 0.35, 3) * np.linspace(0, 1, int(0.9 * SR)) ** 0.5 * 0.05
    place(out, hiss, 2.0)                                # a steam valve lets go
    return out


def run_failed():
    """Melodramatic and self-aware: the sax sighs down a chromatic line over Bbmaj7 to A7,
    the last note droops, then one bright bell answers on D6, a wink that says go again."""
    out = np.zeros(int(2.8 * SR))
    line = [("A4", 0.00, 0.36), ("G#4", 0.36, 0.36), ("G4", 0.72, 0.36), ("F#4", 1.08, 0.9)]
    for note, at, length in line:
        place(out, sax(note, length, 0.3, bend=0.02), at)
    t = t_of(0.9)
    droop = np.sin(2 * np.pi * np.cumsum(hz("F#4") * (1 - 0.06 * np.minimum(t / 0.9, 1) ** 2)) / SR)
    place(out, 0.12 * droop * np.minimum((0.9 - t) / 0.3, 1).clip(0, 1), 1.08)
    for note in ("Bb2", "D3", "F3", "A3"):               # Bbmaj7, the tragic flat six
        place(out, rhodes(note, 1.0, 0.12), 0.0)
    for note in ("A2", "C#3", "G3", "Bb3"):              # A7b9, left hanging
        place(out, rhodes(note, 1.4, 0.12), 1.08)
    place(out, bell("D6", 0.5, ratio=2.0, level=0.25), 2.25)
    return out


def menu_move():
    """A soft woody tick with a D5 Rhodes blip. About 0.08 s."""
    out = np.zeros(int(0.09 * SR))
    place(out, rhodes("D5", 0.08, 0.5), 0.0)
    place(out, noise_burst(0.006, 0.0015, 3) * 0.4, 0.0)
    return out


def menu_confirm():
    """A valve click, then a fourth up, A4 to D5, on Rhodes with a bell on top. About 0.35 s."""
    out = np.zeros(int(0.36 * SR))
    place(out, noise_burst(0.012, 0.003, 2) * 0.5, 0.0)
    place(out, rhodes("A4", 0.12, 0.6), 0.0)
    place(out, rhodes("D5", 0.28, 0.7), 0.07)
    place(out, bell("D6", 0.25, ratio=2.0, level=0.15), 0.07)
    return out


SOUNDS = {"scrap-pickup": scrap_pickup, "harpoon-hit": harpoon_hit, "run-complete": run_complete,
          "menu-move": menu_move, "menu-confirm": menu_confirm, "run-failed": run_failed}


def main():
    out_dir = Path(sys.argv[1])
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, make in SOUNDS.items():
        audio = make()
        audio = audio / np.max(np.abs(audio)) * 10 ** (-1 / 20)
        fade = int(0.004 * SR)
        audio[-fade:] *= np.linspace(1, 0, fade)
        sf.write(out_dir / f"{name}.wav", audio.astype(np.float32), SR, subtype="PCM_16")
        print(f"{name}.wav {len(audio) / SR:.2f} s")


if __name__ == "__main__":
    main()
