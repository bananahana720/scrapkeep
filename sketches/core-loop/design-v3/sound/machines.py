"""Machine percussion, synthesized and locked to a track's beat grid: the Keepers' engines play along.

Andrew (2026-10-17) loves the Machine themes for the machine sounds looped into the groove: piston
hits, steam releases, electro whirs. layer() returns a stereo bed for a mix: a piston clank on
beats 2 and 4 under the backbeat, a steam release on the last eighth of every second bar, and a
rising whir into every eighth bar. `amount` scales the whole bed; lighter tracks pass a smaller
one and lose the whir.
"""

import numpy as np

import cut_loops

SR = 48000
RNG = np.random.default_rng(17)


def _decay(n, seconds):
    return np.exp(-np.arange(n) / SR * 6.9 / seconds)


def piston():
    """A low thump under an inharmonic metal clank, 180 ms."""
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    thump = np.sin(2 * np.pi * (70 + 60 * np.exp(-t * 40)) * t) * _decay(n, 0.09)
    clank = sum(np.sin(2 * np.pi * f * t + RNG.uniform(0, 6.28)) / (i + 1)
                for i, f in enumerate((612, 1033, 1517, 2231, 3090)))
    clank = clank * _decay(n, 0.07) * 0.5
    return thump + clank


def steam(seconds=0.35):
    """A band of hiss that opens fast and sighs away."""
    n = int(seconds * SR)
    noise = RNG.standard_normal(n)
    spec = np.fft.rfft(noise)
    f = np.fft.rfftfreq(n, 1 / SR)
    spec *= np.exp(-((np.log(f + 1) - np.log(4500)) ** 2) / 0.35)
    hiss = np.fft.irfft(spec, n)
    env = np.minimum(np.arange(n) / (0.01 * SR), 1) * _decay(n, seconds * 0.8)
    return hiss / (np.abs(hiss).max() + 1e-9) * env * 0.6


def whir(seconds):
    """A motor spinning up: a buzzy tone sweeping from 80 to 600 Hz, swelling in."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    freq = 80 * (600 / 80) ** (t / seconds)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    tone = np.sign(np.sin(phase)) * 0.3 + np.sin(2 * phase) * 0.3
    return tone * (t / seconds) ** 2 * 0.35


def _place(bed, sound, at, pan):
    at = int(at)
    if at < 0 or at >= len(bed):
        return
    end = min(len(bed), at + len(sound))
    left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    bed[at:end, 0] += sound[:end - at] * left
    bed[at:end, 1] += sound[:end - at] * right


def layer(drums, amount=1.0, light=False):
    """The machine bed for a drum stem: grid read from the kick band, then placed and scaled so its
    energy sits about 16 dB under the drums at amount 1."""
    mono = drums.mean(axis=1)
    flux, rate = cut_loops.onset_envelope(mono, SR)
    bpm = float(cut_loops.tempo(flux, rate, 80, 180))
    first = cut_loops.phase(flux, rate, bpm) * SR
    beat = 60 / bpm * SR
    bed = np.zeros_like(drums)
    clank, hiss = piston(), steam()
    k = 0
    while first + k * beat < len(bed):
        at = first + k * beat
        if k % 4 in (1, 3):
            _place(bed, clank, at, 0.25 if k % 8 < 4 else -0.25)
        if k % 8 == 7:
            _place(bed, hiss, at + beat / 2, 0.5)
        if not light and k % 32 == 28:
            _place(bed, whir(4 * beat / SR), at, -0.3)
        k += 1
    if not bed.any():
        return bed
    gain = np.sqrt((drums ** 2).mean() / ((bed ** 2).mean() + 1e-12)) * 10 ** (-16 / 20) * amount
    return bed * gain
