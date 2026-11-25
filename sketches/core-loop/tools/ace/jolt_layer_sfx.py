"""The jolt layer's five sounds (roster E25, Spillway), synthesized in the machine-foley palette.

    python -I jolt_layer_sfx.py <out dir>

The jolt layer unrolls a live cable mat that pulses every 3.25 s, each pulse read over a 1 s
lead (telegraph_record.gd E25). Its sounds sit in the band's home key, D (harmony.gd HOME = 62),
and are all electricity and machinery: a mains hum and crackle, a capacitor whine, arcs, a spool.

  jolt_layer_presence.wav  2.0 s seamless loop: the live mat's hum and crackle
  jolt_layer_tell.wav      1.0 s: the coil charging over the pulse lead, ending on the jolt
  jolt_layer_jam.wav       0.4 s: the ball caught, an arc snap and a downward "bwow" as it drains
  jolt_layer_fizzle.wav    0.6 s: Q recalled, a sputtering spark that dies into a hiss
  jolt_layer_break.wav     1.1 s: the layer dies, a big arc, the spool unwinding, a last clunk

44.1 kHz, mono, 16-bit, peaks at -1 dBFS like the special cues (assets/audio/specials).
"""

import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
D2, D3, A3, D4, A4, D5 = 73.42, 146.83, 220.0, 293.66, 440.0, 587.33
rng = np.random.default_rng(25)


def t_of(seconds):
    return np.arange(int(round(seconds * SR))) / SR


def env(n, attack, release):
    e = np.ones(n)
    a, r = int(attack * SR), int(release * SR)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r) ** 2
    return e


def bandpass_noise(n, lo, hi):
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    spec[(f < lo) | (f > hi)] = 0
    x = np.fft.irfft(spec, n)
    return x / (np.abs(x).max() + 1e-9)


def sweep(f0, f1, seconds, shape=1.0):
    t = t_of(seconds)
    f = f0 + (f1 - f0) * (t / seconds) ** shape
    return np.cumsum(f) / SR * 2 * np.pi


def buzz(phase, harmonics=12):
    return sum(np.sin(k * phase) / k for k in range(1, harmonics + 1))


def arc(seconds, decay):
    n = int(seconds * SR)
    x = bandpass_noise(n, 1500, 12000)
    gate = (rng.random(n // 64 + 1) > 0.35).repeat(64)[:n]
    return x * gate * np.exp(-t_of(seconds) / decay)


def presence():
    t = t_of(2.0)
    hum = 0.5 * np.sin(2 * np.pi * 73.5 * t) + 0.3 * np.sin(2 * np.pi * 147.0 * t) + 0.06 * np.tanh(4 * np.sin(2 * np.pi * A3 * t))
    wobble = 1 + 0.25 * np.sin(2 * np.pi * 2.0 * t)
    crackle = np.zeros_like(t)
    for at in rng.choice(len(t) - 600, 14, replace=False):
        crackle[at:at + 600] += bandpass_noise(600, 2000, 9000) * np.exp(-np.arange(600) / 120) * rng.uniform(0.3, 0.8)
    return hum * wobble * 0.6 + crackle * 0.35


def tell():
    n = int(1.0 * SR)
    whine = buzz(sweep(D3, D5, 1.0, 2.0), 6) * np.linspace(0.05, 0.6, n) ** 1.5
    tick = np.zeros(n)
    for i, at in enumerate([0.25, 0.5, 0.7, 0.85, 0.93]):
        s = int(at * SR)
        tick[s:s + 400] += bandpass_noise(400, 3000, 10000) * np.exp(-np.arange(400) / 80) * (0.3 + 0.12 * i)
    zap = np.zeros(n)
    z = arc(0.06, 0.03)
    zap[-len(z):] = z * 1.2
    return whine + tick + zap


def jam():
    t = t_of(0.4)
    snap = np.zeros_like(t)
    a = arc(0.12, 0.04)
    snap[:len(a)] = a
    drain = buzz(sweep(A4, D2, 0.4, 0.5), 8) * np.exp(-t / 0.15) * 0.7
    clunk = np.sin(2 * np.pi * D2 * t) * np.exp(-t / 0.06) * 0.9
    return snap + drain + clunk


def fizzle():
    n = int(0.6 * SR)
    t = t_of(0.6)
    spit = buzz(sweep(D5, A3, 0.6, 0.7), 10)
    gate = (rng.random(n // 300 + 1) > np.linspace(0.2, 0.8, n // 300 + 1)).repeat(300)[:n]
    hiss = bandpass_noise(n, 4000, 14000) * np.clip((t - 0.3) / 0.3, 0, 1) * np.exp(-np.clip(t - 0.45, 0, None) / 0.05) * 0.3
    return spit * gate * np.exp(-t / 0.3) * 0.6 + hiss


def death():
    t = t_of(1.1)
    big = np.zeros_like(t)
    a = arc(0.3, 0.12)
    big[:len(a)] = a * 1.2
    spool = buzz(sweep(D4, D2 / 2, 1.1, 0.6), 10) * env(len(t), 0.01, 0.4) * 0.6
    rattle = np.sign(np.sin(sweep(30, 6, 1.1))) * bandpass_noise(len(t), 200, 2500) * np.exp(-t / 0.5) * 0.25
    clunk = np.zeros_like(t)
    c = int(0.9 * SR)
    ct = t[:len(t) - c]
    clunk[c:] = (np.sin(2 * np.pi * D2 * ct) + 0.5 * np.sin(2 * np.pi * D3 * ct)) * np.exp(-ct / 0.05)
    return big + spool + rattle + clunk * 0.8


def write(path, x, loop=False):
    if not loop:
        x = x * env(len(x), 0.002, 0.01)
    x = x / (np.abs(x).max() + 1e-9) * 10 ** (-1 / 20)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def main(argv):
    out = Path(argv[0])
    out.mkdir(parents=True, exist_ok=True)
    for name, x, loop in (("presence", presence(), True), ("tell", tell(), False), ("jam", jam(), False),
                          ("fizzle", fizzle(), False), ("break", death(), False)):
        write(out / f"jolt_layer_{name}.wav", x, loop)
        print(f"jolt_layer_{name}.wav {len(x) / SR:.2f} s")


if __name__ == "__main__":
    main(sys.argv[1:])
