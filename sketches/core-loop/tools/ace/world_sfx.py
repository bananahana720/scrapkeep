"""World 1's water and steam, synthesized: the sounds of the Spillway's world effects (BACKLOG FX-09).

    python3 -I world_sfx.py <assets/audio/world>

The rows that play them are world_fx_specs.gd SOUNDS; this script only makes the files. Each sound is
the event it belongs to, in the 2010 band's garage-sampler register (Arlo samples the pistons and
valves): real water and steam, a little cartoon in the splash. Nothing reads as a warning: no rising
sweeps, no tritones, no metal ring, every hiss low-passed under about 4 kHz with a soft attack, and
no pulse on the 129 BPM grid.

  spill_splash.wav    0.8 s  the ball dropping into water (ball_splash, SPLOSH): a hollow plop, a
                             bright slap of spray, then droplets plinking down on D, A and E
  spill_wake.wav      2.0 s  loop: the ball rolling through water, a churn of small waves
  spill_falls.wav     4.0 s  loop: the weir's falls, a near roar with the splash-pool's patter
  dam_curtain.wav     6.0 s  loop: the dam's spray curtain, a deep wide roar that rolls slowly
  steam_breath.wav    1.6 s  the powerhouse roof breathing (one per steam pulse): a valve thunk and
                             a soft breathy plume
  penstock_vent.wav   1.3 s  the penstock tower's relief valve (one per vent pulse): a low chuff
                             and a firmer jet, settling
  flood_foam.wav      3.0 s  loop: foam on a rising flood, a fizz of bubbles over a low wash

Loops are made periodic (noise shaped in one FFT over the whole loop, every modulation a whole
number of cycles, pops wrapped round the end), so they repeat without a seam. One-shots peak at
-6.1 dBFS like the ambient life; loops sit at -26 dBFS RMS. 44.1 kHz, mono, 16-bit, deterministic.
"""

import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
PEAK_DB = -6.1
LOOP_RMS_DB = -26.0
D5, E5, A5, D6 = 587.33, 659.26, 880.0, 1174.66


def rng(name):
    return np.random.default_rng(sum(map(ord, name)) * 7919)


def t_of(seconds):
    return np.arange(round(seconds * SR)) / SR


def shaped(n, r, lo, hi, tilt=0.0, roll=2.0):
    """Noise of n samples with a smooth band from lo to hi Hz (soft skirts, no ringing) and a
    spectral tilt in dB per octave above lo. One FFT over the whole buffer, so it is periodic."""
    spec = np.fft.rfft(r.standard_normal(n))
    f = np.maximum(np.fft.rfftfreq(n, 1 / SR), 1.0)
    gain = 1 / (1 + (lo / f) ** (2 * roll)) / (1 + (f / hi) ** (2 * roll))
    gain *= (f / lo) ** (tilt / 6.02)
    x = np.fft.irfft(spec * gain, n)
    return x / (np.abs(x).max() + 1e-9)


def env(n, attack, release, curve=2.0):
    e = np.ones(n)
    a, r = max(1, int(attack * SR)), max(1, int(release * SR))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r) ** curve
    return e


def decay(n, seconds):
    return np.exp(-np.arange(n) / (seconds * SR))


def place(buf, at, x, wrap=False):
    i = int(at * SR) % len(buf) if wrap else int(at * SR)
    end = min(len(buf), i + len(x))
    buf[i:end] += x[:end - i]
    if wrap and i + len(x) > len(buf):
        rest = x[end - i:]
        buf[:len(rest)] += rest


def drop(freq, seconds, r):
    """One water droplet: a short sine that bends up a little as the bubble closes (the plink)."""
    t = t_of(seconds)
    f = freq * (1 + 0.18 * (1 - np.exp(-t / 0.02)))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / (seconds / 4)) * env(len(t), 0.002, 0.01)


def lfo(n, cycles, depth, phase=0.0):
    """A slow swell that makes a whole number of cycles over the loop, so it never seams."""
    return 1 + depth * np.sin(2 * np.pi * cycles * np.arange(n) / n + phase)


def spill_splash():
    r = rng("spill_splash")
    n = round(0.8 * SR)
    t = t_of(0.8)
    # The plop: the ball's hollow, a low sine that drops a little as the cavity closes.
    plop = np.sin(2 * np.pi * np.cumsum(150 - 60 * (1 - np.exp(-t / 0.05))) / SR) * decay(n, 0.07)
    # The slap of spray: a bright burst at once, then a wash that rains back.
    slap = shaped(n, r, 400, 3800, -2.0) * decay(n, 0.05)
    rain = shaped(n, r, 900, 3600, -3.0) * env(n, 0.06, 0.45) * np.exp(-t / 0.35)
    out = plop * 0.9 + slap * 0.8 + rain * 0.35
    # Droplets back onto the water on D, A and E (the home key's consonance), uneven gaps.
    for at, freq, gain in ((0.16, D6, 0.30), (0.23, A5, 0.26), (0.31, E5 * 2, 0.20), (0.42, D5 * 2, 0.16),
                           (0.55, A5, 0.10)):
        place(out, at, drop(freq, 0.09, r) * gain)
    return out


def spill_wake():
    r = rng("spill_wake")
    n = round(2.0 * SR)
    body = shaped(n, r, 180, 2400, -3.0) * lfo(n, 3, 0.35) * lfo(n, 7, 0.2, 1.3)
    out = body
    # Small waves slapping the ball: soft bursts at uneven times, wrapped round the loop.
    for at in (0.13, 0.52, 0.81, 1.27, 1.66):
        k = round(0.18 * SR)
        place(out, at, shaped(k, r, 300, 2600, -2.0) * env(k, 0.015, 0.15) * 0.6, wrap=True)
    return out


def spill_falls():
    r = rng("spill_falls")
    n = round(4.0 * SR)
    roar = shaped(n, r, 120, 3200, -2.5) * lfo(n, 2, 0.12) * lfo(n, 5, 0.08, 0.7)
    low = shaped(n, r, 50, 260, -1.0) * lfo(n, 3, 0.25, 2.0)
    patter = shaped(n, r, 1200, 3800, -2.0) * lfo(n, 9, 0.35, 0.4)
    return roar + low * 0.7 + patter * 0.35


def dam_curtain():
    r = rng("dam_curtain")
    n = round(6.0 * SR)
    roar = shaped(n, r, 70, 2200, -3.5) * lfo(n, 2, 0.18) * lfo(n, 3, 0.1, 1.1)
    floor = shaped(n, r, 30, 140, -0.5) * lfo(n, 1, 0.3, 0.3)
    hush = shaped(n, r, 1500, 3400, -2.0) * lfo(n, 4, 0.4, 2.2)
    return roar + floor * 0.9 + hush * 0.25


def steam_breath():
    r = rng("steam_breath")
    n = round(1.6 * SR)
    t = t_of(1.6)
    # The valve: a soft wooden thunk, no ring.
    thunk = np.sin(2 * np.pi * 95 * t) * decay(n, 0.035) + shaped(n, r, 150, 900) * decay(n, 0.02) * 0.4
    # The plume: breathy noise that swells in and fades as the puff rises off the roof.
    shape = np.sin(np.pi * np.clip(t / 1.5, 0, 1)) ** 1.4 * np.exp(-t / 1.4)
    plume = shaped(n, r, 350, 3600, -3.5) * shape
    return thunk * 0.7 + plume


def penstock_vent():
    r = rng("penstock_vent")
    n = round(1.3 * SR)
    t = t_of(1.3)
    # The chuff: a low pressure thump as the relief valve lifts.
    chuff = np.sin(2 * np.pi * 62 * t) * decay(n, 0.09) + shaped(n, r, 60, 400) * decay(n, 0.06) * 0.7
    # The jet: firmer than the roof's breath, level then settling (no glide).
    jet = shaped(n, r, 450, 3900, -2.5) * env(n, 0.03, 0.6, 1.6) * np.exp(-t / 0.9)
    return chuff * 0.8 + jet


def flood_foam():
    r = rng("flood_foam")
    n = round(3.0 * SR)
    wash = shaped(n, r, 90, 1400, -3.0) * lfo(n, 2, 0.3)
    fizz = shaped(n, r, 1800, 4200, -1.0) * lfo(n, 5, 0.3, 0.9) * 0.25
    out = wash + fizz
    # Bubbles: tiny plinks at random pitches round the loop, quiet and dense.
    for _ in range(70):
        at = r.uniform(0, 3.0)
        place(out, at, drop(r.uniform(900, 2600), r.uniform(0.02, 0.05), r) * r.uniform(0.05, 0.18), wrap=True)
    return out


def write(path, x, loop=False):
    if loop:
        x = x - x.mean()
        x = x * 10 ** (LOOP_RMS_DB / 20) / (np.sqrt(np.mean(x * x)) + 1e-12)
    else:
        x = x * env(len(x), 0.002, 0.02)
        x = x * 10 ** (PEAK_DB / 20) / (np.abs(x).max() + 1e-9)
    x = np.clip(x, -0.99, 0.99)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    return x


SOUNDS = (("spill_splash", spill_splash, False), ("spill_wake", spill_wake, True), ("spill_falls", spill_falls, True),
          ("dam_curtain", dam_curtain, True), ("steam_breath", steam_breath, False),
          ("penstock_vent", penstock_vent, False), ("flood_foam", flood_foam, True))


def main(argv):
    out = Path(argv[0])
    out.mkdir(parents=True, exist_ok=True)
    for name, make, loop in SOUNDS:
        x = write(out / f"{name}.wav", make(), loop)
        rms = 20 * np.log10(np.sqrt(np.mean(x * x)) + 1e-12)
        peak = 20 * np.log10(np.abs(x).max() + 1e-12)
        print(f"{name}.wav {len(x) / SR:.2f} s  peak {peak:.1f} dBFS  rms {rms:.1f} dBFS{'  loop' if loop else ''}")


if __name__ == "__main__":
    main(sys.argv[1:])
