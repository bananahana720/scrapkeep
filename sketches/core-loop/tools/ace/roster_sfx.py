"""The Highdraft roster's own sounds (PR #72), synthesized in the machine-foley palette, in G.

    python -I roster_sfx.py <assets/audio/foley>

A tell ends on the frame its visual lands, so the game starts it its own length before that frame:

  ballast_brace_tell.wav    1.1 s tell: ballast_heavy.gd warn_seconds, the four brake claws bite the deck
                            one after another under a rising hydraulic hiss, ends on the slam
  ballast_brace_slam.wav    1.3 s: the slam, a piston hit, the ring's shock and a steam release
  gap_net_charge_tell.wav   1.0 s tell: gap_net.gd warn_seconds, the net's charge whining up, ends on live
  gap_net_charge_live.wav   0.7 s: the net goes live, a zap and a crackle that settles into its hum

44.1 kHz, mono, 16-bit, peaks at -1 dBFS, like arrival_sfx.py and the jolt layer.
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from arrival_sfx import metal_hit, place  # noqa: E402
from jolt_layer_sfx import SR, bandpass_noise, buzz, env, sweep, t_of, write  # noqa: E402

G1, G2, D3, G3, B3, D4, G4, G5 = 49.0, 98.0, 146.83, 196.0, 246.94, 293.66, 392.0, 783.99
rng = np.random.default_rng(72)


def claw(pitch):
    # One brake claw biting the deck: a short metal clunk with a thud under it.
    t = t_of(0.35)
    hit = metal_hit(0.35, [(pitch, 1.0, 0.09), (pitch * 2.02, 0.5, 0.06), (pitch * 3.1, 0.25, 0.04)], 1.0)
    thud = np.sin(2 * np.pi * G1 * 2 * t) * np.exp(-t / 0.05)
    return hit * 0.7 + thud * 0.6


def ballast_brace_tell():
    n = round(1.1 * SR)
    t = t_of(1.1)
    hiss = bandpass_noise(n, 1500, 7000) * np.linspace(0.05, 0.6, n) ** 1.6
    hum = buzz(sweep(G2, D3, 1.1, 1.8), 6) * np.linspace(0.05, 0.4, n) ** 1.4
    out = hiss * 0.5 + hum
    # The claws drop in G, D, G, B across the brace, closer together toward the slam.
    for at, pitch, gain in ((0.10, G3, 0.7), (0.42, D3, 0.8), (0.66, G3, 0.9), (0.84, B3, 1.0)):
        out += place(n, at, claw(pitch)) * gain
    return out * (1 + 0.15 * np.sin(2 * np.pi * 11 * t))


def ballast_brace_slam():
    n = round(1.3 * SR)
    t = t_of(1.3)
    piston = metal_hit(1.3, [(G2, 1.0, 0.3), (D3 * 1.01, 0.6, 0.2), (G3 * 1.5, 0.4, 0.09), (G4 * 1.3, 0.25, 0.05)], 1.0)
    boom = (np.sin(2 * np.pi * G1 * t) + 0.5 * np.sin(2 * np.pi * G2 * t)) * np.exp(-t / 0.18)
    shock = bandpass_noise(n, 60, 900) * np.exp(-t / 0.15)
    steam = bandpass_noise(n, 2500, 11000) * np.clip((t - 0.08) / 0.05, 0, 1) * np.exp(-np.clip(t - 0.13, 0, None) / 0.35) * 0.35
    return piston + boom * 1.2 + shock * 0.6 + steam


def gap_net_charge_tell():
    n = round(1.0 * SR)
    t = t_of(1.0)
    whine = buzz(sweep(G3, G5, 1.0, 2.2), 4) * np.linspace(0.05, 0.6, n) ** 1.5
    # The charge ticks faster as it fills: crackle bursts gated by a rising pulse rate.
    rate = 8 + 30 * t
    gate = (np.sin(np.cumsum(2 * np.pi * rate / SR)) > 0.7).astype(float)
    crackle = bandpass_noise(n, 3000, 12000) * gate * np.linspace(0.1, 0.7, n)
    mains = buzz(2 * np.pi * G2 * t, 8) * np.linspace(0.0, 0.25, n)
    return whine + crackle * 0.5 + mains


def gap_net_charge_live():
    n = round(0.7 * SR)
    t = t_of(0.7)
    zap = np.zeros(n)
    z = bandpass_noise(int(0.05 * SR), 1000, 14000) * np.exp(-np.arange(int(0.05 * SR)) / 500)
    zap[:len(z)] = z * 1.3
    tone = buzz(2 * np.pi * G3 * t, 6) * np.exp(-t / 0.25) * 0.6 + buzz(2 * np.pi * D4 * t, 4) * np.exp(-t / 0.15) * 0.3
    crackle = np.zeros(n)
    for _ in range(25):
        at = rng.uniform(0.03, 0.6)
        crackle += place(n, at, bandpass_noise(400, 3000, 12000) * np.exp(-np.arange(400) / 60) * rng.uniform(0.15, 0.5) * (1 - at))
    hum = buzz(2 * np.pi * G2 * t, 8) * 0.12
    return zap + tone + crackle + hum


SOUNDS = {
    "ballast_brace_tell": ballast_brace_tell, "ballast_brace_slam": ballast_brace_slam,
    "gap_net_charge_tell": gap_net_charge_tell, "gap_net_charge_live": gap_net_charge_live,
}


def main(argv):
    out = Path(argv[0])
    out.mkdir(parents=True, exist_ok=True)
    for name, make in SOUNDS.items():
        x = make()
        x = x * env(len(x), 0.002, 0.0)
        write(out / f"{name}.wav", x, False)
        print(f"{name}.wav {len(x) / SR:.2f} s")


if __name__ == "__main__":
    main(sys.argv[1:])
