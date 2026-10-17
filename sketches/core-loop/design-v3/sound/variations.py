"""Buff twists and switch-up transitions: the real-time side of the variation system.

    python variations.py <render folder>

Buffs are effects the engine applies live to whatever loop is playing, so every track gets them
for free. Each preview here plays the picked combat hype loop 4 bars clean, 8 bars buffed, 4 bars
clean, with a one-beat crossfade each way, so both the entry and the exit can be heard. Every effect
maps to a stock Godot AudioEffect or a pitch_scale change (INTEGRATION.md section 7).

Switch-ups are synthesized stingers that hand one loop to the next on a downbeat, and the demos
splice them between real tracks. Writes 48 kHz mono WAVs to <render folder>/variations/.
"""

import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, resample, sosfilt

sys.path.insert(0, str(Path(__file__).resolve().parent))
from event_sounds import SR, bell, hz, noise_burst, place, t_of  # noqa: E402
from event_set import brass, chord, crunch, mix, square, sub, sweep  # noqa: E402

RNG = np.random.default_rng(1718)


def bar(bpm):
    return 4 * 60 / bpm


def load(path, seconds=None):
    audio, sr = sf.read(path)
    audio = audio.mean(axis=1) if audio.ndim > 1 else audio
    if sr != SR:
        audio = resample(audio, int(len(audio) * SR / sr))
    return audio[: int(seconds * SR)] if seconds else audio


def filt(audio, kind, cut):
    return sosfilt(butter(4, cut, kind, fs=SR, output="sos"), audio)


def beats(seconds, bpm):
    return np.arange(0, seconds, 60 / bpm)


# buffs: each takes the clean loop and returns the buffed loop, same length ------------------

def overdrive(x, bpm):
    """Power-up: the band clips hot, hats double to sixteenths, a brass stab on every bar."""
    y = 0.6 * np.tanh(3 * x) / np.tanh(3) + 0.4 * x
    for at in np.arange(0, len(x) / SR, 60 / bpm / 4):
        place(y, noise_burst(0.04, 0.01, 1) * 0.12, at)
    for at in np.arange(0, len(x) / SR, bar(bpm)):
        place(y, chord(brass, ("D4", "F4", "A4"), 0.25, 0.18), at)
    return y


def slowmo(x, bpm):
    """Slow-mo or stun: tape-slow to 0.75 (pitch_scale 0.75 in Godot) under a low-pass."""
    slowed = resample(x, int(len(x) / 0.75))[: len(x)]
    return filt(slowed, "lowpass", 2500)


def low_hull(x, bpm):
    """Low hull: the band goes muffled and far away while an 808 heartbeat pumps lub-dub on every
    beat of whatever is playing, and the band ducks under each thump. Locked to the track's tempo,
    so it races when a boss phase speeds up."""
    y = filt(x, "lowpass", 700) * 0.8
    t = np.arange(len(x)) / SR
    phase = (t % (60 / bpm)) / (60 / bpm)
    y *= 0.45 + 0.55 * np.minimum(phase / 0.5, 1)
    lub = 60 / bpm * 0.3
    for at in beats(len(x) / SR, bpm):
        place(y, sub(0.22, 120, 48, 0.1, 0.9), at)
        place(y, sub(0.16, 100, 44, 0.07, 0.55), at + lub)
    return y


def shield(x, bpm):
    """Shield or invulnerable: the low end drops away, a chorus shimmers, bells sparkle on downbeats."""
    hp = filt(x, "highpass", 300)
    t = np.arange(len(x)) / SR
    delay = (0.012 + 0.004 * np.sin(2 * np.pi * 0.8 * t)) * SR
    idx = np.clip(np.arange(len(x)) - delay, 0, len(x) - 1)
    y = 0.7 * hp + 0.5 * np.interp(idx, np.arange(len(x)), hp)
    for i, at in enumerate(np.arange(0, len(x) / SR, bar(bpm))):
        place(y, bell(("D6", "A6", "E6", "A6")[i % 4], 0.6, ratio=2.0, level=0.18), at)
    return y


def scrap_streak(x, bpm):
    """Scrap magnet or a streak: the band pumps on every beat and a chiptune arpeggio climbs each bar."""
    t = np.arange(len(x)) / SR
    phase = (t % (60 / bpm)) / (60 / bpm)
    y = x * (0.35 + 0.65 * np.minimum(phase / 0.45, 1))
    steps = ("D5", "E5", "F5", "A5", "C6", "D6", "E6", "A6")
    for at in np.arange(0, len(x) / SR, bar(bpm)):
        for k, note in enumerate(steps):
            place(y, square(note, 60 / bpm / 2 * 0.9, 0.08, duty=0.25), at + k * 60 / bpm / 2)
    return y


BUFFS = {"buff-overdrive": overdrive, "buff-slowmo": slowmo, "buff-low-hull": low_hull,
         "buff-shield": shield, "buff-scrap-streak": scrap_streak}


def buff_preview(loop, bpm, effect):
    b = int(bar(bpm) * SR)
    x = loop[: 16 * b]
    wet = effect(x.copy(), bpm)
    w = np.zeros(len(x))
    fade = int(60 / bpm * SR)
    w[4 * b: 4 * b + fade] = np.linspace(0, 1, fade)
    w[4 * b + fade: 12 * b] = 1
    w[12 * b: 12 * b + fade] = np.linspace(1, 0, fade)
    return x * (1 - w) + wet * w


# switch-ups ---------------------------------------------------------------------------------

def record_scratch():
    """Something out of nowhere: a vinyl scratch back and forth, then dead air."""
    t = t_of(0.45)
    speed = np.sin(2 * np.pi * 2.2 * t) * np.exp(-t / 0.3)
    f = 400 + 1800 * np.abs(speed)
    return 0.6 * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.abs(speed) + sweep(0.45, 800, 4000, 0.3, attack=0.002)


def switch_hit(bpm):
    """The cut: everything stops, one beat of silence, then a brass and crash unison hit on the downbeat."""
    beat = 60 / bpm
    out = mix(beat + 1.0, (record_scratch(), 0))
    place(out, chord(brass, ("D3", "A3", "D4", "F4"), 0.8, 0.35), beat)
    place(out, crunch(0.6, 0.25, 0.5), beat)
    place(out, sub(0.6, 120, 40, 0.3, 0.8), beat)
    return out


def turnaround(bpm):
    """One-bar turnaround into the next loop: a snare fill that crescendos to sixteenths under a
    ii-V on brass (Em7 to A7), landing on a crash and D on the next downbeat."""
    beat = 60 / bpm
    out = np.zeros(int((4 * beat + 1.0) * SR))
    for k in range(16):
        level = 0.15 + 0.5 * k / 15
        if k < 8 and k % 2:
            continue
        place(out, noise_burst(0.08, 0.03, 2) * level, k * beat / 4)
    place(out, chord(brass, ("E3", "G3", "B3", "D4"), beat * 1.8, 0.2), 0)
    place(out, chord(brass, ("A3", "C#4", "E4", "G4"), beat * 1.8, 0.25), 2 * beat)
    place(out, chord(brass, ("D3", "F3", "A3", "D4"), 0.9, 0.35), 4 * beat)
    place(out, crunch(0.9, 0.35, 0.45), 4 * beat)
    return out


def tape_stop(x, seconds):
    """The track winds down like a tape machine losing power over the last `seconds`."""
    n = int(seconds * SR)
    head, tail = x[:-n], x[-n:]
    rate = np.linspace(1, 0.05, n) ** 1.5
    idx = np.cumsum(rate)
    return np.concatenate([head, np.interp(idx, np.arange(n), tail) * np.linspace(1, 0.6, n)])


def norm(audio, peak_db=-1.0):
    return audio / (np.max(np.abs(audio)) + 1e-9) * 10 ** (peak_db / 20)


def main():
    root = Path(sys.argv[1])
    out = root / "variations"
    out.mkdir(exist_ok=True)
    src = root / "variant-src"
    hype = load(src / "hype-129.wav")
    for name, effect in BUFFS.items():
        sf.write(out / f"{name}.wav", norm(buff_preview(hype, 129, effect)).astype(np.float32), SR, subtype="PCM_16")

    stings = {"switch-hit-129": switch_hit(129), "switch-hit-172": switch_hit(172),
              "turnaround-129": turnaround(129), "turnaround-172": turnaround(172)}
    for name, audio in stings.items():
        sf.write(out / f"{name}.wav", norm(audio).astype(np.float32), SR, subtype="PCM_16")

    # demos: real tracks handed over by the devices, laid on one timeline
    def splice(pre, device, device_at, post, post_at):
        demo = np.zeros(int((post_at + len(post) / SR) * SR) + 1)
        place(demo, pre * 0.7, 0)
        place(demo, device, device_at)
        place(demo, post * 0.7, post_at)
        return norm(demo).astype(np.float32)

    roam = load(src / "roam-spillway-172.wav", 7 * bar(172))
    fight = hype[: int(8 * bar(129) * SR)]
    sf.write(out / "demo-roam-turnaround-fight.wav",
             splice(roam, turnaround(172), len(roam) / SR, fight, len(roam) / SR + bar(172)), SR, subtype="PCM_16")

    pre = tape_stop(fight, 2 * 60 / 129)
    boss = load(src / "brindle-p1-138.wav", 8 * bar(138))
    sf.write(out / "demo-fight-switchup-boss.wav",
             splice(pre, switch_hit(129), len(pre) / SR, boss, len(pre) / SR + 60 / 129), SR, subtype="PCM_16")
    print(f"wrote {len(BUFFS) + len(stings) + 2} files to {out}")


if __name__ == "__main__":
    main()
