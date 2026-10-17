"""Audio signatures for the four kill-first specials: the Foreman, the Dispatcher, the Splitter, the Linker.

    python specials.py <out_dir>

Left 4 Dead's rule: you hear which special is near before you see it. Each one owns a register
and a texture no other cue uses, and carries it through four cues:
- presence: a seamless two-bar loop at 129 BPM (3.72 s) the engine plays spatialized while it lives
- tell: the wind-up, starting on frame one so it lines up with the visual tell (danger family)
- break: its death, with the tone bible's wink (the Splitter has two: split and clean)
- spawn: a one-beat musical answer the score plays on the next beat when it arrives

Registers: Foreman low brass and steam (100-600 Hz) with a punch-clock tick; Dispatcher square
pings and teleprinter clatter (1.5-3 kHz); Splitter fuse hiss (4-8 kHz) over three beating hums;
Linker mains buzz and a bowed cable (120 Hz series, 700-900 Hz).
Writes 48 kHz mono 16-bit WAVs and manifest.json, in check_events.py's format.
"""

import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from event_sounds import SR, bell, env, hz, noise_burst, place, pluck, rhodes, t_of  # noqa: E402
from event_set import brass, chord, crunch, mix, square, sub, sweep  # noqa: E402

BEAT = 60 / 129
LOOP = 8 * BEAT
RNG = np.random.default_rng(1717)


def loop(hits, bed=None):
    """A seamless two-bar loop. The bed is generated exactly periodic over the loop (pitches on whole
    cycles, noise filtered circularly); the hits render past the end and their tails fold onto the head."""
    n = int(round(LOOP * SR))
    buf = hits(LOOP + 1.0)
    out = buf[:n].copy()
    out[: len(buf) - n] += buf[n:]
    if bed is not None:
        out += bed(n)
    return out


def cyc(f):
    """Round a frequency to a whole number of cycles per loop, so it wraps without a seam."""
    return round(f * LOOP) / LOOP


def tone(f, seconds, harmonics=(1,), vib=0.0, rate=5.0):
    t = t_of(seconds)
    ph = 2 * np.pi * np.cumsum(f * (1 + vib * np.sin(2 * np.pi * rate * t)) * np.ones_like(t)) / SR
    return sum(np.sin(k * ph) / k for k in harmonics)


def ptone(f, n, harmonics=(1,), vib=0.0, rate=5.0):
    """A tone exactly periodic over n samples: f and the vibrato rate both on whole cycles per loop."""
    t = np.arange(n) / SR
    f, rate = cyc(f), cyc(rate)
    ph = 2 * np.pi * (f * t - f * vib * np.cos(2 * np.pi * rate * t) / (2 * np.pi * rate) if vib else f * t)
    return sum(np.sin(k * ph) / k for k in harmonics)


def pnoise(n, lo, hi, level=1.0):
    """Band noise exactly periodic over n samples, filtered in the frequency domain."""
    spec = np.fft.rfft(RNG.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    spec[(f < lo) | (f > hi)] = 0
    out = np.fft.irfft(spec, n)
    return level * out / (np.max(np.abs(out)) + 1e-9)


def steam(seconds, level=1.0):
    return sweep(seconds, 2500, 900, level)


# Foreman: the boss of the shift. Steam horn, punch clock, never attacks. ----------------

def foreman_presence():
    def bed(n):
        t = np.arange(n) / SR
        return ptone(hz("D2"), n, (1, 2, 3, 5), vib=0.004, rate=0.5) * 0.25 * (0.7 + 0.3 * np.sin(2 * np.pi * t / LOOP))

    def make(sec):
        out = np.zeros(int(sec * SR))
        for b in range(8):
            place(out, noise_burst(0.03, 0.004, 2) * 0.35, b * BEAT)  # the punch clock ticks the beat
            if b % 2:
                place(out, noise_burst(0.02, 0.003, 2) * 0.2, b * BEAT + BEAT / 2)
        place(out, steam(0.6, 0.18), 3.5 * BEAT)
        place(out, steam(0.6, 0.18), 7.5 * BEAT)
        place(out, brass("A2", 0.5, 0.18), 6 * BEAT)  # the boss clearing his throat
        return out
    return loop(make, bed)


def foreman_tell():
    """The horn on the beat before each wipe: a factory horn on the tritone, full from frame one."""
    out = mix(1.1, (chord(brass, ("D3", "Ab3", "D4"), 0.9, 0.45), 0))
    t = t_of(0.9)
    out[: len(t)] += 0.35 * tone(hz("D3"), 0.9, (1, 3, 5, 7)) * np.minimum((0.9 - t) / 0.1, 1)
    place(out, steam(0.4, 0.25), 0.55)
    return out


def foreman_break():
    """SHIFT OVER: the punch clock ka-chunks, steam sighs out, a corny trombone wah-wah-wah-waaah."""
    out = mix(2.4, (crunch(0.06, 0.015, 0.7), 0), (noise_burst(0.04, 0.01, 2) * 0.6, 0.09))
    place(out, bell("D6", 0.3, ratio=1.0, level=0.3), 0.09)
    place(out, steam(1.4, 0.35), 0.2)
    for i, (note, dur) in enumerate((("A3", 0.22), ("Ab3", 0.22), ("G3", 0.22), ("F#3", 0.8))):
        place(out, brass(note, dur, 0.3) * (1 + 0.4 * np.sin(2 * np.pi * 6 * t_of(dur))), 0.45 + 0.26 * i)
    return out


def foreman_spawn():
    """One beat: a low brass two-note call, the shift whistle."""
    return mix(BEAT * 1.6, (brass("D3", BEAT * 0.45, 0.5), 0), (brass("A2", BEAT, 0.5), BEAT / 2))


# Dispatcher: the perch that keeps sending. Radar ping, teleprinter, pneumatic tube. ------

def dispatcher_presence():
    def make(sec):
        out = np.zeros(int(sec * SR))
        for b in range(8):
            place(out, square("A6", 0.09, 0.22, duty=0.25), b * BEAT)  # the beacon on every beat
            for k in range(3):  # teleprinter clatter on the off-beats
                place(out, noise_burst(0.012, 0.002, 1) * 0.22, b * BEAT + BEAT * (0.5 + 0.12 * k))
        place(out, square("E7", 0.06, 0.12), 3.75 * BEAT)
        place(out, square("E7", 0.06, 0.12), 7.75 * BEAT)
        return out
    return loop(make)


def dispatcher_tell():
    """A chaser is coming: the tube sucks up, then a tritone double ding at the drop."""
    out = mix(1.0, (sweep(0.45, 300, 3500, 0.5, attack=0.002), 0))
    place(out, bell("D6", 0.4, ratio=2.0, level=0.45), 0.45)
    place(out, bell("Ab6", 0.4, ratio=2.0, level=0.45), 0.6)
    return out


def dispatcher_break():
    """Line disconnected: the printer jams, a spring sproings, the beacon falls down a chiptune scale."""
    out = mix(1.6, (crunch(0.12, 0.03, 0.7), 0))
    for k in range(6):
        place(out, noise_burst(0.012, 0.002, 1) * 0.4, 0.02 + 0.03 * k)
    t = t_of(0.4)
    place(out, 0.3 * np.sin(2 * np.pi * np.cumsum(hz("E5") * (1 + 0.3 * np.sin(2 * np.pi * 18 * t) * np.exp(-t / 0.15))) / SR) * env(0.4, 0.002, 0.15), 0.18)
    for i, note in enumerate(("A6", "E6", "D6", "A5", "D5")):
        place(out, square(note, 0.11, 0.25, duty=0.25), 0.55 + 0.09 * i)
    return out


def dispatcher_spawn():
    """One beat of morse: short-short-long on the beacon note."""
    return mix(BEAT * 1.5, (square("A5", 0.06, 0.4), 0), (square("A5", 0.06, 0.4), BEAT / 4),
               (square("D6", BEAT * 0.6, 0.4), BEAT / 2))


# Splitter: three hulls welded into one. Fuse hiss over three hums that beat. -------------

def splitter_presence():
    def bed(n):
        hums = sum(ptone(hz("F3") * d, n, (1, 2, 3)) for d in (1.0, 1.0115, 0.988)) * 0.12
        return hums + pnoise(n, 4000, 8000, 0.09)

    def make(sec):
        t = t_of(sec)
        sput = np.zeros(len(t))
        for b in range(16):
            place(sput, noise_burst(0.03, 0.006, 1) * 0.25, b * BEAT / 2 + (0.03 if b % 3 == 0 else 0))
        lamp = np.zeros(len(t))
        for b in (0, 4):
            place(lamp, bell("C7", 0.12, ratio=1.0, level=0.12), b * BEAT)
        return sput + lamp
    return loop(make, bed)


def splitter_tell():
    """Seams flare white for 0.4 s: three voices glide up and converge, then cut dead."""
    out = np.zeros(int(0.45 * SR))
    t = t_of(0.4)
    for start, level in ((hz("F4"), 0.3), (hz("B4"), 0.3), (hz("E5"), 0.3)):
        f = start + (hz("F5") - start) * (t / 0.4) ** 1.5
        out[: len(t)] += level * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.minimum(t / 0.003, 1)
    out[: len(t)] += sweep(0.4, 3000, 9000, 0.15, attack=0.002)
    return out


def splitter_break_split():
    """Rammed at ground level: it pops into three, each piece a little chirp running off in its own key."""
    out = mix(1.2, (crunch(0.08, 0.02, 0.8), 0), (sub(0.25, 160, 60, 0.12, 0.6), 0))
    for i, (a, b) in enumerate((("F5", "C6"), ("Ab5", "Eb6"), ("B5", "F6"))):
        place(out, square(a, 0.05, 0.25, duty=0.125), 0.12 + 0.11 * i)
        place(out, square(b, 0.07, 0.25, duty=0.125), 0.17 + 0.11 * i)
    return out


def splitter_break_clean():
    """Killed from above or range: one fat pop and a reward ding. The sound of doing it right."""
    out = mix(1.0, (crunch(0.06, 0.015, 0.7), 0), (sub(0.3, 220, 50, 0.15, 0.9), 0))
    place(out, bell("A5", 0.5, ratio=3.5, level=0.35), 0.05)
    place(out, bell("D6", 0.6, ratio=3.5, level=0.35), 0.13)
    return out


def splitter_spawn():
    """One beat: three notes stacked fast, the three-in-one."""
    return mix(BEAT * 1.5, *((rhodes(n, BEAT, 0.35), i * BEAT / 6) for i, n in enumerate(("F4", "B4", "E5"))))


# Linker: a dish on a boom held over a partner by a cable. Mains buzz and a bowed wire. ---

def linker_presence():
    def bed(n):
        t = np.arange(n) / SR
        buzz = ptone(120.0, n, (1, 2, 3, 4, 5, 6, 7)) * 0.08
        wire = ptone(hz("A5"), n, (1, 2, 3), vib=0.006, rate=4.3) * 0.1
        return buzz + wire * (0.6 + 0.4 * np.sin(2 * np.pi * 2 * t / LOOP) ** 2)

    def make(sec):
        arc = np.zeros(int(sec * SR))
        for at in (1.25 * BEAT, 5.6 * BEAT):
            place(arc, noise_burst(0.05, 0.008, 1) * 0.25, at)
        return arc
    return loop(make, bed)


def linker_tell():
    """The cable goes taut and hums: a twang that tightens upward while the dish braces."""
    out = np.zeros(int(1.0 * SR))
    t = t_of(0.8)
    f = hz("A4") * 2 ** (np.minimum(t / 0.6, 1) * 0.5)
    taut = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    out[: len(t)] += 0.35 * taut * np.minimum(t / 0.002, 1) * np.minimum((0.8 - t) / 0.1, 1)
    place(out, pluck("A2", 0.6, level=0.5), 0)
    place(out, tone(120.0, 0.8, (1, 2, 3, 4, 5)) * 0.15, 0)
    return out


def linker_break():
    """Cable cut: a snap, the dish drops with a clang, then rolls off like a lost hubcap, slowing."""
    out = mix(2.4, (noise_burst(0.02, 0.004, 1) * 0.8, 0), (pluck("E4", 0.3, damp=0.99, level=0.5), 0))
    place(out, bell("C#4", 0.8, ratio=2.76, level=0.5), 0.12)
    place(out, crunch(0.05, 0.02, 0.4), 0.12)
    gap, at = 0.07, 0.4
    for k in range(9):
        place(out, bell("G#5", 0.12, ratio=2.76, level=0.22 * 0.88 ** k), at)
        at += gap
        gap *= 1.22
    return out


def linker_spawn():
    """One beat: two notes joined by a slide, a line drawn between them."""
    t = t_of(BEAT)
    f = hz("D4") * 2 ** (np.clip((t - BEAT * 0.3) / (BEAT * 0.3), 0, 1) * 7 / 12)
    return 0.4 * np.sin(2 * np.pi * np.cumsum(f) / SR) * env(BEAT, 0.004, BEAT * 0.6) + rhodes("D4", BEAT, 0.2)


CUES = {
    "foreman_presence": ("presence", foreman_presence), "foreman_tell": ("danger", foreman_tell),
    "foreman_break": ("reward", foreman_break), "foreman_spawn": ("spawn", foreman_spawn),
    "dispatcher_presence": ("presence", dispatcher_presence), "dispatcher_tell": ("danger", dispatcher_tell),
    "dispatcher_break": ("reward", dispatcher_break), "dispatcher_spawn": ("spawn", dispatcher_spawn),
    "splitter_presence": ("presence", splitter_presence), "splitter_tell": ("danger", splitter_tell),
    "splitter_break_split": ("danger", splitter_break_split), "splitter_break_clean": ("reward", splitter_break_clean),
    "splitter_spawn": ("spawn", splitter_spawn),
    "linker_presence": ("presence", linker_presence), "linker_tell": ("danger", linker_tell),
    "linker_break": ("reward", linker_break), "linker_spawn": ("spawn", linker_spawn),
}


def highpass(audio, cut=25.0):
    """One-pole high-pass: the pulse-wave squares carry DC that would eat headroom."""
    a = SR / (SR + 2 * np.pi * cut)
    out, prev_x, prev_y = np.empty_like(audio), 0.0, 0.0
    for i, x in enumerate(audio):
        prev_y = a * (prev_y + x - prev_x)
        prev_x = x
        out[i] = prev_y
    return out


def main():
    out_dir = Path(sys.argv[1])
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest = []
    for name, (family, make) in CUES.items():
        audio = make()
        audio = audio - np.mean(audio) if family == "presence" else highpass(audio)
        if family != "presence":
            nz = np.nonzero(np.abs(audio) > 1e-4)[0]
            audio = audio[: nz[-1] + 1]
            fade = min(int(0.004 * SR), len(audio) // 4)
            audio[-fade:] *= np.linspace(1, 0, fade)
        audio = audio / np.max(np.abs(audio)) * 10 ** (-1 / 20)
        sf.write(out_dir / f"{name}.wav", audio.astype(np.float32), SR, subtype="PCM_16")
        manifest.append(dict(cue=name, family=family, seconds=round(len(audio) / SR, 3)))
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=1))
    print(f"{len(manifest)} cues written to {out_dir}")


if __name__ == "__main__":
    main()
