"""The new arrival forms' and the prop crew's sounds (PR #71), synthesized in the machine-foley palette.

    python -I arrival_sfx.py <assets/audio/foley>

Each world's sounds sit in its key (the Dig in E, the Highdraft in G). A tell ends on the frame its
visual lands, so the game starts it its own length before that frame:

  lift_cage_arrive.wav     1.4 s: the Dig's lift cage tops out, a clank at 0 then the winch ratchet settling
  zipline_whine.wav        2.0 s tell: the trolley's cable whine rising toward the landing, ends on it
  zipline_snap.wav         0.5 s: the hook comes off the cable, a snap and a ringing cable
  cave_in_rumble.wav       1.2 s tell: cave_ins.gd WARN_S, a rumble building under the burrower, ends on the fall
  cave_in_debris.wav       1.0 s: the debris lands, a thump and rock scatter
  prop_crew_presence.wav   2.0 s seamless loop: the timber prop creaking under the roof
  prop_crew_strain.wav     1.0 s tell: prop_crew.gd ROOF_WARN, the jack groaning as the prop goes, ends on the fall
  prop_crew_collapse.wav   1.5 s: the roof comes down, timber cracks, a heavy slab and dust

44.1 kHz, mono, 16-bit, peaks at -1 dBFS, like the specials and the jolt layer (jolt_layer_sfx.py).
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from jolt_layer_sfx import SR, bandpass_noise, buzz, env, sweep, t_of, write

E1, E2, E3, B3, E4 = 41.20, 82.41, 164.81, 246.94, 329.63
G2, G3, D4, G4, G5 = 98.0, 196.0, 293.66, 392.0, 783.99
rng = np.random.default_rng(71)


def metal_hit(seconds, partials, decay):
    t = t_of(seconds)
    return sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t / (decay * d)) for f, a, d in partials)


def place(n, at, x):
    out = np.zeros(n)
    s = int(at * SR)
    out[s:s + len(x)] += x[:n - s]
    return out


def ratchet(seconds, rate0, rate1, pitch):
    n = round(seconds * SR)
    out = np.zeros(n)
    t, i = 0.0, 0
    while t < seconds - 0.02:
        click = bandpass_noise(500, pitch, pitch * 4) * np.exp(-np.arange(500) / 90) * (1 - t / seconds) ** 0.5
        out += place(n, t, click)
        rate = rate0 + (rate1 - rate0) * t / seconds
        t += 1 / rate
        i += 1
    return out


def lift_cage_arrive():
    n = round(1.4 * SR)
    clank = metal_hit(1.4, [(E2, 1.0, 0.25), (E3 * 1.01, 0.6, 0.18), (B3 * 1.5, 0.4, 0.08), (E4 * 1.7, 0.3, 0.05)], 1.0)
    thud = np.sin(2 * np.pi * E1 * t_of(1.4)) * np.exp(-t_of(1.4) / 0.08)
    return clank + thud * 0.8 + ratchet(1.4, 18, 5, 900) * 0.5 + bandpass_noise(n, 100, 600) * np.exp(-t_of(1.4) / 0.1) * 0.3


def zipline_whine():
    n = round(2.0 * SR)
    whine = buzz(sweep(G3, G4, 2.0, 1.5), 5) * np.linspace(0.05, 0.7, n) ** 1.3
    rattle = bandpass_noise(n, 2000, 8000) * (0.15 + 0.15 * np.sin(2 * np.pi * 23 * t_of(2.0))) * np.linspace(0.2, 1.0, n)
    return whine + rattle * 0.4


def zipline_snap():
    t = t_of(0.5)
    snap = np.zeros_like(t)
    s = bandpass_noise(int(0.03 * SR), 1500, 12000) * np.exp(-np.arange(int(0.03 * SR)) / 200)
    snap[:len(s)] = s * 1.3
    cable = metal_hit(0.5, [(G4, 0.6, 0.2), (D4 * 2, 0.4, 0.15), (G5 * 1.02, 0.3, 0.1)], 1.0)
    return snap + cable * (1 + 0.3 * np.sin(2 * np.pi * 9 * t))


def cave_in_rumble():
    n = round(1.2 * SR)
    t = t_of(1.2)
    rumble = bandpass_noise(n, 25, 180) * np.linspace(0.1, 1.0, n) ** 2
    tone = np.sin(2 * np.pi * E1 * t) * np.linspace(0, 0.6, n) ** 2
    grit = bandpass_noise(n, 800, 4000) * (rng.random(n // 400 + 1) > 0.7).repeat(400)[:n] * np.linspace(0, 0.4, n)
    return rumble + tone + grit


def cave_in_debris():
    n = round(1.0 * SR)
    t = t_of(1.0)
    thump = (np.sin(2 * np.pi * E1 * t) + 0.5 * np.sin(2 * np.pi * E2 * t)) * np.exp(-t / 0.12)
    scatter = np.zeros(n)
    for _ in range(40):
        at = rng.uniform(0.02, 0.7)
        rock = bandpass_noise(900, 600, 5000) * np.exp(-np.arange(900) / 150) * rng.uniform(0.1, 0.5) * (1 - at)
        scatter += place(n, at, rock)
    dust = bandpass_noise(n, 1500, 9000) * np.exp(-t / 0.4) * 0.15
    return thump * 1.1 + scatter + dust


def creak(seconds, pitch, loudness):
    n = round(seconds * SR)
    t = t_of(seconds)
    rate = 40 + 25 * np.sin(np.pi * t / seconds)
    pulses = np.sin(np.cumsum(2 * np.pi * rate / SR)) > 0.6
    body = buzz(2 * np.pi * pitch * t * (1 + 0.04 * np.sin(np.pi * t / seconds)), 6)
    return body * pulses * np.sin(np.pi * t / seconds) ** 2 * loudness


def prop_crew_presence():
    n = round(2.0 * SR)
    out = place(n, 0.15, creak(0.6, E3, 0.6)) + place(n, 1.1, creak(0.5, B3, 0.4))
    out += bandpass_noise(n, 150, 500) * 0.03
    return out


def prop_crew_strain():
    n = round(1.0 * SR)
    t = t_of(1.0)
    groan = buzz(sweep(E2, E3, 1.0, 2.0), 8) * np.linspace(0.1, 0.8, n) ** 1.5
    pops = np.zeros(n)
    for at in (0.35, 0.6, 0.78, 0.9):
        pops += place(n, at, bandpass_noise(700, 1500, 7000) * np.exp(-np.arange(700) / 100) * (0.3 + at * 0.4))
    return groan * (1 + 0.3 * np.sin(2 * np.pi * 7 * t)) + pops


def prop_crew_collapse():
    n = round(1.5 * SR)
    t = t_of(1.5)
    crack = bandpass_noise(int(0.08 * SR), 1000, 9000) * np.exp(-np.arange(int(0.08 * SR)) / 800)
    slab = (np.sin(2 * np.pi * E1 * t) + 0.6 * np.sin(2 * np.pi * E2 * t)) * np.exp(-np.clip(t - 0.12, 0, None) / 0.18) * (t >= 0.12)
    rubble = np.zeros(n)
    for _ in range(60):
        at = rng.uniform(0.12, 1.1)
        rubble += place(n, at, bandpass_noise(1200, 300, 4000) * np.exp(-np.arange(1200) / 250) * rng.uniform(0.1, 0.45) * (1.3 - at))
    dust = bandpass_noise(n, 1000, 8000) * np.clip((t - 0.15) / 0.2, 0, 1) * np.exp(-np.clip(t - 0.35, 0, None) / 0.5) * 0.18
    return place(n, 0, crack) * 1.2 + slab * 1.2 + rubble + dust


SOUNDS = {
    "lift_cage_arrive": (lift_cage_arrive, False), "zipline_whine": (zipline_whine, False),
    "zipline_snap": (zipline_snap, False), "cave_in_rumble": (cave_in_rumble, False),
    "cave_in_debris": (cave_in_debris, False), "prop_crew_presence": (prop_crew_presence, True),
    "prop_crew_strain": (prop_crew_strain, False), "prop_crew_collapse": (prop_crew_collapse, False),
}


def main(argv):
    out = Path(argv[0])
    out.mkdir(parents=True, exist_ok=True)
    for name, (make, loop) in SOUNDS.items():
        x = make()
        if not loop:
            x = x * env(len(x), 0.002, 0.0)
        write(out / f"{name}.wav", x, loop)
        print(f"{name}.wav {len(x) / SR:.2f} s")


if __name__ == "__main__":
    main(sys.argv[1:])
