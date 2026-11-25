"""World 1's designed event sounds and story stings (world 1 unit 18, "Spillway sound identity").

    /home/andrew/.local/share/ACE-Step-1.5/.venv/bin/python -I spillway_stingers.py [--out <assets/audio/stingers>]

Until now every Spillway event landed on a sound the Dig and the Highdraft also played. These are
designed one-shots at the Spillway's own cue ids, in D Dorian (the band's home key). The dam is
1_1 and plays them at D; the flume is 1_2 and plays each a whole step brighter, so the two parks
differ even where they share an id.

  riser_dam_siren        the dam siren winds up, a wail climbing a fifth (the flood telegraph)
  drop_flood_horn        the spillway horn: two long blasts a fifth apart, D then A
  drop_flash_flood       a rushing wash: a surge of noise sweeping down over a low D
  drop_spill_dropship    thrusters cut out, a thud, then a hard brass dyad on the landing
  drop_relic_wake        a buried machine turning over: sub D, beating partials, a stone bell
  drop_spill_boiler      the burner blows: hiss, pop, a whistle bending up a fifth
  drop_cracked_wall      the trestle gives: three cracks, a long rock rumble, a falling thud
  drop_reactor_blow      a reactor going: a boom, a rising whine, a ragged sub sweep
  drop_sluice_surge      the head gate lifts: a metal grind, then a gush through the gap

and five story stings (1_1 only, one per spillway_story flourish row):

  sting_cold_open        a plucked D Dorian climb: D A C D, the run's first morning
  sting_rivet_cage       KLANG: a cage-bar clang, then a bright release bell on A
  sting_warden_reveal    a low brass fall onto the flat second (D to Eb), a held sub
  sting_bowl_handoff     a horn call down from A to D into Brindle's bowl
  sting_spillway_clear   a bell run up the scale, D to D, and a held major sixth glint

Same finish and level as the cut stingers: -16 LUFS, true peak at or under -1 dBTP, 44.1 kHz mono.
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cut_stingers import PROJECT, RATE, finish, level, lufs, true_peak_db, write_wav

ZONES = {"1_1": 0, "1_2": 2}
CUES = ("riser_dam_siren", "drop_flood_horn", "drop_flash_flood", "drop_spill_dropship", "drop_relic_wake",
        "drop_spill_boiler", "drop_cracked_wall", "drop_reactor_blow", "drop_sluice_surge")
STINGS = ("sting_cold_open", "sting_rivet_cage", "sting_warden_reveal", "sting_bowl_handoff", "sting_spillway_clear")
DAM = ("riser_dam_siren", "drop_flood_horn", "drop_flash_flood", "drop_spill_dropship", "drop_relic_wake", "drop_spill_boiler")
FLUME = ("drop_flash_flood", "drop_spill_dropship", "drop_relic_wake", "drop_cracked_wall", "drop_reactor_blow", "drop_sluice_surge")
BY_ZONE = {"1_1": DAM + STINGS, "1_2": FLUME}
rng = np.random.default_rng(1801)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def t_of(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def noise(n, lo, hi):
    from scipy import signal
    sos = signal.butter(2, [lo, hi], "bandpass", fs=RATE, output="sos")
    return signal.sosfilt(sos, rng.standard_normal(n))


def lowpass(x, cut, order=2):
    from scipy import signal
    return signal.sosfilt(signal.butter(order, cut, "lowpass", fs=RATE, output="sos"), x)


def place(n, at, x):
    out = np.zeros(n)
    s = int(at * RATE)
    if s < n:
        out[s:s + len(x)] += x[: n - s]
    return out


def env(t, attack, decay, hold=0.0):
    return np.minimum(t / attack, 1.0) * np.exp(-np.clip(t - attack - hold, 0, None) / decay)


def tone(midi, seconds, harmonics=6, rolloff=1.2, vibrato=0.0):
    t = t_of(seconds)
    phase = 2 * np.pi * hz(midi) * t + vibrato * np.sin(2 * np.pi * 5.0 * t)
    return sum(np.sin(k * phase) / k ** rolloff for k in range(1, harmonics + 1))


def sweep(f0, f1, seconds):
    """A sine gliding exponentially from f0 to f1 Hz."""
    t = t_of(seconds)
    f = f0 * (f1 / f0) ** (t / seconds)
    return np.sin(np.cumsum(2 * np.pi * f / RATE))


def bell(midi, seconds, decay=0.5):
    t = t_of(seconds)
    f = hz(midi)
    partials = [(1.0, 1.0), (2.0, 0.5), (2.76, 0.4), (5.4, 0.2), (8.9, 0.1)]
    return sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / (decay / (0.6 + 0.4 * r))) for r, a in partials)


def pluck(midi, seconds):
    t = t_of(seconds)
    return tone(midi, seconds, 8, 1.0) * np.exp(-t / 0.18) * np.minimum(t / 0.004, 1.0)


def riser_dam_siren(s):
    seconds = 1.86
    t = t_of(seconds)
    d4 = 62 + s
    f = hz(d4) * 2 ** ((7 / 12) * (t / seconds) ** 1.4)
    wail = 1 + 0.35 * np.sin(2 * np.pi * (2.0 + 3.0 * t / seconds) * t)
    sir = np.sin(np.cumsum(2 * np.pi * f * wail / RATE)) + 0.4 * np.sin(np.cumsum(4 * np.pi * f / RATE))
    swell = np.minimum(t / 0.5, 1.0)
    return sir * swell * 0.8 + noise(len(t), 600, 3000) * 0.05 * swell


def drop_flood_horn(s):
    n = int(1.6 * RATE)
    d = 38 + s
    low = tone(d + 12, 1.1, 10, 0.9, 0.2) * env(t_of(1.1), 0.05, 0.4, 0.3)
    high = tone(d + 19, 1.2, 10, 0.9, 0.2) * env(t_of(1.2), 0.05, 0.4, 0.3)
    beat = tone(d + 12.08, 1.1, 6, 1.0) * env(t_of(1.1), 0.05, 0.4, 0.3)
    x = place(n, 0.0, low + beat * 0.6) + place(n, 0.45, high * 0.9)
    return x + place(n, 0.0, sweep(hz(d - 12) * 1.2, hz(d - 12), 0.4) * np.exp(-t_of(0.4) / 0.15)) * 0.8


def drop_flash_flood(s):
    n = int(1.5 * RATE)
    t = t_of(1.5)
    d = 50 + s
    surge = noise(n, 200, 6000) * np.minimum(t / 0.1, 1.0) * np.exp(-t / 0.7)
    fall = noise(n, 1200, 9000) * np.exp(-t / 0.25) * 0.8
    thump = np.sin(2 * np.pi * hz(d - 12) * t) * np.exp(-t / 0.25)
    gurgle = np.sin(2 * np.pi * hz(d) * t + 3 * np.sin(2 * np.pi * 9 * t)) * np.exp(-t / 0.5) * 0.25
    return surge * 0.7 + fall * 0.5 + thump * 0.9 + gurgle


def drop_spill_dropship(s):
    n = int(1.7 * RATE)
    d = 38 + s
    thrust = noise(int(0.5 * RATE), 150, 3500) * np.linspace(1.0, 0.1, int(0.5 * RATE)) ** 1.5
    thrust *= 1 + 0.4 * np.sin(2 * np.pi * 38 * t_of(0.5))
    thud = np.sin(2 * np.pi * hz(d - 12) * t_of(0.8)) * np.exp(-t_of(0.8) / 0.18)
    clank = noise(int(0.2 * RATE), 1500, 9000) * np.exp(-t_of(0.2) / 0.03)
    dyad = (tone(d + 24, 1.0, 8, 1.2) + tone(d + 31, 1.0, 8, 1.2)) * env(t_of(1.0), 0.04, 0.3, 0.1)
    return place(n, 0.0, thrust * 0.8) + place(n, 0.45, thud * 1.2) + place(n, 0.45, clank * 0.8) + place(n, 0.55, dyad * 0.6)


def drop_relic_wake(s):
    n = int(1.9 * RATE)
    t = t_of(1.9)
    d = 26 + s
    sub = np.sin(2 * np.pi * hz(d) * t) * env(t, 0.2, 0.9, 0.3)
    grind = (np.sin(2 * np.pi * hz(d + 12) * t) + np.sin(2 * np.pi * (hz(d + 12) + 3.3) * t)) * env(t, 0.3, 0.7, 0.2) * 0.4
    rise = sweep(hz(d + 24) * 0.6, hz(d + 24), 1.3) * env(t_of(1.3), 0.5, 0.4, 0.2) * 0.25
    ring = bell(d + 36, 1.2, 0.8) * 0.3
    return sub * 1.2 + grind + place(n, 0.1, rise) + place(n, 0.35, ring)


def drop_spill_boiler(s):
    n = int(1.3 * RATE)
    t = t_of(1.3)
    d = 62 + s
    hiss = noise(n, 2500, 11000) * np.minimum(t / 0.02, 1.0) * np.exp(-t / 0.5) * 0.6
    pop = place(n, 0.08, noise(int(0.04 * RATE), 80, 3000) * np.exp(-t_of(0.04) / 0.008) * 2.0)
    pop += place(n, 0.08, np.sin(2 * np.pi * hz(d - 24) * t_of(0.25)) * np.exp(-t_of(0.25) / 0.07))
    wt = t_of(1.0)
    pitch = hz(d + 12) * 2 ** ((7 / 12) * np.clip((wt - 0.2) / 0.25, 0, 1)) * (1 + 0.012 * np.sin(2 * np.pi * 14 * wt))
    whistle = np.sin(np.cumsum(2 * np.pi * pitch / RATE)) * np.minimum(wt / 0.05, 1.0) * np.exp(-np.clip(wt - 0.6, 0, None) / 0.2)
    whistle *= 1 + 0.3 * noise(len(wt), 1000, 6000) / 3
    return hiss + pop + place(n, 0.16, whistle * 0.5)


def drop_cracked_wall(s):
    n = int(1.7 * RATE)
    d = 38 + s
    x = np.zeros(n)
    for at, amp in ((0.0, 1.0), (0.09, 0.8), (0.19, 0.6)):
        crack = noise(int(0.08 * RATE), 800, 8000) * np.exp(-t_of(0.08) / 0.015)
        x += place(n, at, crack * amp * 1.6)
    rumble = lowpass(noise(n, 40, 900), 600) * env(t_of(1.7), 0.15, 0.6, 0.2)
    thud = np.sin(2 * np.pi * hz(d - 12) * t_of(0.8)) * np.exp(-t_of(0.8) / 0.22)
    fall = tone(d, 1.0, 5, 1.5) * np.exp(-t_of(1.0) / 0.3) * 0.4
    return x + rumble * 1.4 + place(n, 0.28, thud * 1.3) + place(n, 0.28, fall)


def drop_reactor_blow(s):
    n = int(1.8 * RATE)
    t = t_of(1.8)
    d = 26 + s
    boom = (np.sin(2 * np.pi * hz(d) * t) + 0.5 * np.sin(2 * np.pi * hz(d + 12) * t)) * np.exp(-t / 0.5) * np.minimum(t / 0.01, 1.0)
    whine = sweep(hz(d + 36), hz(d + 60), 1.2) * np.minimum(t_of(1.2) / 0.3, 1.0) * np.exp(-np.clip(t_of(1.2) - 0.6, 0, None) / 0.3)
    shred = noise(n, 300, 5000) * np.exp(-t / 0.35) * np.minimum(t / 0.01, 1.0)
    drive = np.tanh(2.5 * (boom * 1.4 + shred * 0.6))
    return drive + place(n, 0.1, whine * 0.3)


def drop_sluice_surge(s):
    n = int(1.7 * RATE)
    d = 38 + s
    grind = noise(int(0.7 * RATE), 100, 1800) * (1 + 0.6 * np.sin(2 * np.pi * 22 * t_of(0.7))) * np.minimum(t_of(0.7) / 0.1, 1.0)
    grind *= np.exp(-np.clip(t_of(0.7) - 0.3, 0, None) / 0.2)
    clang = bell(d + 24, 0.6, 0.3) * 0.5 + noise(int(0.6 * RATE), 1500, 7000) * np.exp(-t_of(0.6) / 0.02)
    gush_t = t_of(1.2)
    gush = noise(len(gush_t), 250, 7000) * np.minimum(gush_t / 0.2, 1.0) * np.exp(-gush_t / 0.6)
    swirl = np.sin(2 * np.pi * hz(d) * gush_t + 2 * np.sin(2 * np.pi * 5 * gush_t)) * np.exp(-gush_t / 0.5) * 0.4
    return place(n, 0.0, grind * 0.9) + place(n, 0.35, clang) + place(n, 0.4, gush * 1.0) + place(n, 0.4, swirl)


def sting_cold_open(s):
    n = int(1.6 * RATE)
    x = np.zeros(n)
    for i, m in enumerate((62, 69, 72, 74)):
        x += place(n, 0.14 * i, pluck(m, 1.0) * (0.7 + 0.1 * i))
    x += place(n, 0.42, bell(86, 1.1, 0.7) * 0.35)
    return x


def sting_rivet_cage(s):
    n = int(1.6 * RATE)
    clang = bell(50 + s, 0.9, 0.35) * 1.2 + bell(53, 0.9, 0.25) * 0.6
    clang += noise(int(0.9 * RATE), 1200, 9000) * np.exp(-t_of(0.9) / 0.025) * 1.5
    release = bell(81 + s, 1.0, 0.6) * 0.5
    rattle = sum(place(n, 0.12 + 0.07 * i, noise(int(0.05 * RATE), 2000, 9000) * np.exp(-t_of(0.05) / 0.01) * (0.6 - 0.12 * i)) for i in range(4))
    return place(n, 0.0, clang) + rattle + place(n, 0.3, release)


def sting_warden_reveal(s):
    n = int(2.0 * RATE)
    brass = (tone(38, 1.8, 10, 0.9, 0.1) + tone(50, 1.8, 10, 0.9, 0.1)) * env(t_of(1.8), 0.12, 0.7, 0.3)
    flat = (tone(39, 1.4, 10, 0.9, 0.1) + tone(51, 1.4, 10, 0.9, 0.1)) * env(t_of(1.4), 0.1, 0.5, 0.2)
    fall = sweep(hz(62), hz(38), 0.5) * np.exp(-t_of(0.5) / 0.3) * 0.5
    sub = np.sin(2 * np.pi * hz(26) * t_of(2.0)) * env(t_of(2.0), 0.3, 0.9, 0.3) * 0.9
    return place(n, 0.0, brass * 0.7) + place(n, 0.5, flat * 0.7) + place(n, 0.0, fall) + sub[:n]


def sting_bowl_handoff(s):
    n = int(2.0 * RATE)
    call1 = tone(57, 0.7, 10, 0.9, 0.15) * env(t_of(0.7), 0.04, 0.4, 0.1)
    call2 = tone(50, 1.3, 10, 0.9, 0.15) * env(t_of(1.3), 0.04, 0.6, 0.3)
    tail = lowpass(noise(n, 60, 700), 400) * env(t_of(2.0), 0.4, 0.6, 0.2) * 0.15
    return place(n, 0.0, call1) + place(n, 0.5, call2) + tail


def sting_spillway_clear(s):
    n = int(2.2 * RATE)
    x = np.zeros(n)
    for i, m in enumerate((62, 64, 65, 67, 69, 71, 74)):
        x += place(n, 0.09 * i, bell(m + 12, 1.0, 0.5) * 0.5)
    x += place(n, 0.65, bell(74 + 12, 1.4, 0.9) * 0.6)
    x += place(n, 0.65, bell(83 + 12, 1.2, 0.6) * 0.25)
    x += place(n, 0.0, tone(38, 1.2, 4, 1.5) * env(t_of(1.2), 0.1, 0.5, 0.2) * 0.3)
    return x


MAKERS = {name: globals()[name] for name in CUES + STINGS}


def design(out_dir):
    report = {}
    for zone, shift in ZONES.items():
        report[zone] = {}
        for cue in BY_ZONE[zone]:
            x = level(finish(MAKERS[cue](shift), 0.1))
            write_wav(out_dir / zone / f"{cue}.wav", x)
            report[zone][cue] = {"kind": "designed", "samples": len(x), "lufs": round(float(lufs(x)), 2),
                                 "dbtp": round(float(true_peak_db(x)), 2)}
    return report


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=PROJECT / "assets/audio/stingers")
    args = ap.parse_args()
    report = design(args.out)
    manifest_path = args.out / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    for zone, rows in report.items():
        for cue, row in rows.items():
            sha = hashlib.sha256((args.out / zone / f"{cue}.wav").read_bytes()).hexdigest()[:12]
            print(zone, cue, row, sha)
            manifest[zone]["cues"][cue] = row
        manifest[zone]["cues"] = dict(sorted(manifest[zone]["cues"].items()))
    manifest_path.write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
