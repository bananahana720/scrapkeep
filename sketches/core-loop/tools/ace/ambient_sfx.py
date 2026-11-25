"""Ambient life foley: one call and one react per critter or local, soft and friendly.

    python3 -I ambient_sfx.py <assets/audio/ambient>

The kinds and their voice names are read straight from src/core/ambient_kinds.gd (the record stays
the one source; no table is copied here). Each voice name is one recipe below; two kinds that share
a recipe (flutter_burst) differ by a pitch and timing seed taken from the kind id and the slot.

Soft-toy register, nothing that reads as a warning: every voice is low-passed under about 3.2 kHz
with a gentle attack (8 ms or more) and a long soft release, no rising sweeps, no metal, no beats on
the 129 BPM grid (note gaps are uneven). Calls run 0.3 to 1.2 s, reacts 0.2 to 0.8 s. Peaks sit at
-6.1 dBFS, 5 dB under the combat foley (roster_sfx, arrival_sfx: -1 dBFS).

44.1 kHz, mono, 16-bit, deterministic: the seed is crc32 of "<kind>:<slot>".
"""

import re
import sys
import wave
import zlib
from pathlib import Path

import numpy as np

SR = 44100
PEAK = 10 ** (-6.1 / 20)
RECORD = Path(__file__).resolve().parents[2] / "src" / "core" / "ambient_kinds.gd"
LIMITS = {"call": (0.3, 1.2), "react": (0.2, 0.8)}


def t_of(seconds):
    return np.arange(round(seconds * SR)) / SR


def env(n, attack, release, curve=2.0):
    e = np.ones(n)
    a, r = int(attack * SR), int(release * SR)
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r) ** curve
    return e


def lowpass(x, cutoff):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    spec *= 1 / (1 + (f / cutoff) ** 4)
    return np.fft.irfft(spec, len(x))


def noise(r, n, lo, hi):
    spec = np.fft.rfft(r.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    spec[(f < lo) | (f > hi)] = 0
    x = np.fft.irfft(spec, n)
    return x / (np.abs(x).max() + 1e-9)


def glide(freqs):
    return np.cumsum(freqs) / SR * 2 * np.pi


def note(f0, f1, seconds, harmonics=(1.0, 0.25, 0.08), vib=0.0, attack=0.012, release=0.05):
    t = t_of(seconds)
    f = np.linspace(f0, f1, len(t)) * (1 + vib * np.sin(2 * np.pi * 5.5 * t))
    ph = glide(f)
    x = sum(a * np.sin((k + 1) * ph) for k, a in enumerate(harmonics))
    return x * env(len(t), attack, release)


def formant(x, centers, width=0.25):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    gain = sum(np.exp(-0.5 * ((f - c) / (c * width)) ** 2) for c in centers)
    return np.fft.irfft(spec * (gain + 0.03), len(x))


def mix(parts, seconds):
    out = np.zeros(round(seconds * SR))
    for at, x, g in parts:
        i = round(at * SR)
        j = min(len(out), i + len(x))
        out[i:j] += x[: j - i] * g
    return out


def thump(f, seconds, decay):
    t = t_of(seconds)
    return np.sin(2 * np.pi * f * t * (1 + 0.3 * np.exp(-t / 0.02))) * np.exp(-t / decay) * env(len(t), 0.006, 0.03)


def tap(r, p, seconds=0.09, f=420.0, decay=0.025):
    t = t_of(seconds)
    body = np.sin(2 * np.pi * f * p * t) + 0.4 * np.sin(2 * np.pi * f * p * 1.7 * t)
    return (body * np.exp(-t / decay) + 0.15 * lowpass(noise(r, len(t), 100, 1500), 1200) * np.exp(-t / 0.02)) * env(len(t), 0.006, 0.03)


def three_note_chirp(r, p):
    return mix([(0.0, note(1250 * p, 1350 * p, 0.12), 0.7),
                (0.17, note(1650 * p, 1750 * p, 0.26, vib=0.01), 1.0),
                (0.50, note(1350 * p, 950 * p, 0.34), 0.8)], 0.88)


def thin_twitter(r, p):
    parts, at = [], 0.0
    for i in range(7):
        parts.append((at, note(2100 * p * (1 + 0.06 * r.standard_normal()), 1800 * p, 0.05, (1, 0.2), attack=0.01, release=0.025), 0.8))
        at += 0.07 + 0.03 * r.random()
    return mix(parts, at + 0.08)


def low_croak(r, p):
    t = t_of(0.55)
    pulse = 0.55 + 0.45 * np.sin(2 * np.pi * 26 * t) ** 2
    x = sum(np.sin(k * glide(np.linspace(120, 95, len(t)) * p)) / k for k in range(1, 9))
    return formant(x, [320 * p, 900 * p], 0.3) * pulse * env(len(t), 0.05, 0.18)


def two_note_whistle(r, p):
    return mix([(0.0, note(880 * p, 880 * p, 0.22, vib=0.008), 0.9),
                (0.30, note(660 * p, 640 * p, 0.42, vib=0.01, release=0.15), 1.0)], 0.76)


def bray(r, p):
    parts, at = [], 0.0
    for f, vowel, d in ((300, [450, 2200], 0.26), (190, [700, 1100], 0.32), (310, [450, 2200], 0.2), (185, [700, 1100], 0.36)):
        t = t_of(d)
        ph = glide(f * p * (1 + 0.03 * np.sin(2 * np.pi * 7 * t)))
        x = sum(np.sin(k * ph) / k for k in range(1, 14))
        parts.append((at, formant(x, [v * p for v in vowel], 0.2) * env(len(t), 0.04, 0.08), 1.0))
        at += d - 0.02
    return mix(parts, at + 0.04)


def tiny_squeak(r, p):
    return mix([(0.0, note(2300 * p, 2000 * p, 0.09, (1, 0.1), attack=0.012, release=0.04), 0.8),
                (0.14, note(2000 * p, 2350 * p, 0.07, (1, 0.1), attack=0.012, release=0.04), 0.6)], 0.34)


def pebble_scratch(r, p):
    parts, at = [], 0.0
    for i in range(6):
        d = 0.04 + 0.03 * r.random()
        g = lowpass(noise(r, round(d * SR), 600, 2600), 2200) * env(round(d * SR), 0.01, 0.025)
        parts.append((at, g, 0.5 + 0.4 * r.random()))
        at += d + 0.05 + 0.06 * r.random()
    return mix(parts, at + 0.05)


def hummed_tune(r, p):
    notes = [(262, 0.17), (330, 0.17), (294, 0.14), (392, 0.34)]
    parts, at = [], 0.0
    for f, d in notes:
        x = note(f * p, f * p * 0.998, d + 0.03, (1, 0.5, 0.2), vib=0.012, attack=0.03, release=0.05)
        parts.append((at, formant(x, [280 * p, 1000 * p], 0.35), 1.0))
        at += d + 0.015
    return mix(parts, at + 0.06)


def bleat(r, p):
    t = t_of(0.6)
    f = np.linspace(430, 360, len(t)) * p * (1 + 0.05 * np.sin(2 * np.pi * 28 * t))
    x = sum(np.sin(k * glide(f)) / k for k in range(1, 12))
    return formant(x, [850 * p, 1500 * p], 0.22) * env(len(t), 0.05, 0.2)


def falling_whistle(r, p):
    parts, at, f = [], 0.0, 2800.0
    for i in range(7):
        d = 0.15 - 0.012 * i
        parts.append((at, note(f * p, f * p * 0.93, d, (1, 0.12), attack=0.012, release=0.06), 1.0 - 0.05 * i))
        at += d * 0.82 + 0.015 * r.random()
        f *= 0.9
    return mix(parts, at + 0.15)


def humming_creak(r, p):
    t = t_of(0.95)
    hum = formant(note(196 * p, 205 * p, 0.95, (1, 0.5, 0.25), vib=0.01, attack=0.12, release=0.2), [300 * p, 800 * p], 0.3)
    saw = ((glide(np.linspace(95, 70, len(t)) * p) / (2 * np.pi)) % 1.0) * 2 - 1
    creak = lowpass(saw, 700) * (0.5 + 0.5 * np.sin(2 * np.pi * 3.1 * t + 1.0)) * env(len(t), 0.2, 0.25)
    return hum * 0.8 + creak * 0.4


def wing_whirr(r, p):
    t = t_of(0.55)
    flap = 0.55 + 0.45 * np.sin(2 * np.pi * 22 * t) ** 2
    x = lowpass(noise(r, len(t), 200, 2400), 1800) * flap
    return x * (1 - np.exp(-t / 0.08)) * env(len(t), 0.03, 0.22)


def flutter_burst(r, p):
    t = t_of(0.4)
    flap = 0.5 + 0.5 * np.sin(2 * np.pi * (34 * p) * t + 2 * r.random()) ** 2
    x = lowpass(noise(r, len(t), 300, 2800), 2200) * flap
    return x * env(len(t), 0.02, 0.18)


def water_plop(r, p):
    t = t_of(0.28)
    f = 380 * p * np.exp(-t / 0.07) + 140 * p
    return np.sin(glide(f)) * np.exp(-t / 0.08) * env(len(t), 0.008, 0.08)


def bucket_clonk(r, p):
    return mix([(0.0, tap(r, p, 0.14, 310, 0.04), 1.0), (0.19, tap(r, p, 0.12, 260, 0.035), 0.6)], 0.36)


def hoof_clops(r, p):
    gaps = [0.0, 0.17, 0.36, 0.52, 0.71]
    return mix([(at, tap(r, p * (1 + 0.05 * r.standard_normal()), 0.1, 230, 0.03), 1.0 - 0.1 * i) for i, at in enumerate(gaps)], 0.8)


def leather_flutter(r, p):
    t = t_of(0.45)
    flap = 0.5 + 0.5 * np.sin(2 * np.pi * (15 * p) * t) ** 2
    x = lowpass(noise(r, len(t), 150, 1400), 1100) * flap
    return x * env(len(t), 0.04, 0.2)


def hiss_puff(r, p):
    t = t_of(0.34)
    x = lowpass(noise(r, len(t), 500, 3000), 2400) * np.sin(np.pi * np.clip(t / 0.34, 0, 1)) ** 1.5
    return x * env(len(t), 0.05, 0.12)


def pan_clatter(r, p):
    parts = []
    for i, at in enumerate((0.0, 0.07, 0.15, 0.21, 0.31)):
        parts.append((at, tap(r, p * (1.7 + 0.1 * r.standard_normal()), 0.08, 520, 0.02), 0.9 - 0.12 * i))
    return mix(parts, 0.42)


def hoof_taps(r, p):
    return mix([(at, tap(r, p * (1 + 0.04 * r.standard_normal()), 0.07, 360, 0.02), g)
                for at, g in ((0.0, 0.9), (0.12, 0.7), (0.29, 0.9), (0.38, 0.6))], 0.52)


def chitter(r, p):
    parts, at = [], 0.0
    for i in range(6):
        d = 0.045
        parts.append((at, note(900 * p * (1 + 0.1 * r.standard_normal()), 750 * p, d, (1, 0.4, 0.15), attack=0.01, release=0.03), 0.8))
        at += d + 0.02 + 0.02 * r.random()
    return mix(parts, at + 0.08)


RECIPES = {f.__name__: f for f in (
    three_note_chirp, wing_whirr, thin_twitter, flutter_burst, low_croak, water_plop, two_note_whistle,
    bucket_clonk, bray, hoof_clops, tiny_squeak, leather_flutter, pebble_scratch, hiss_puff, hummed_tune,
    pan_clatter, bleat, hoof_taps, falling_whistle, humming_creak, chitter)}


def parse_record(path=RECORD):
    kinds, current = {}, None
    for line in path.read_text().splitlines():
        m = re.match(r'\t"(\w+)": \{$', line)
        if m:
            current = m.group(1)
        m = re.search(r'"voice": \{"call": "(\w+)", "react": "(\w+)"\}', line)
        if m and current:
            kinds[current] = {"call": m.group(1), "react": m.group(2)}
    return kinds


def render(kind, slot, voice):
    r = np.random.default_rng(zlib.crc32(f"{kind}:{slot}".encode()))
    pitch = 0.94 + 0.12 * (zlib.crc32(f"{kind}:pitch".encode()) % 1000) / 1000
    x = RECIPES[voice](r, pitch)
    x = lowpass(x, 3200)
    x = x * env(len(x), 0.008, 0.03)
    x = x - x.mean()
    return x / (np.abs(x).max() + 1e-9) * PEAK


def write(path, x):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(np.round(x * 32767).astype("<i2").tobytes())


def main(argv):
    out = Path(argv[0])
    out.mkdir(parents=True, exist_ok=True)
    kinds = parse_record()
    assert kinds, "no kinds parsed from the record"
    for kind, voices in kinds.items():
        for slot in ("call", "react"):
            x = render(kind, slot, voices[slot])
            lo, hi = LIMITS[slot]
            seconds = len(x) / SR
            assert lo <= seconds <= hi, f"{kind}_{slot} ({voices[slot]}) is {seconds:.2f} s, want {lo} to {hi}"
            write(out / f"{kind}_{slot}.wav", x)
            peak = 20 * np.log10(np.abs(x).max())
            print(f"{kind}_{slot}.wav {voices[slot]} {seconds:.2f} s {peak:.1f} dBFS")


if __name__ == "__main__":
    main(sys.argv[1:])
