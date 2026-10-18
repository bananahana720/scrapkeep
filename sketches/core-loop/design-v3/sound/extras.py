"""The four extras Andrew picked on 2026-10-17: pilot sax quotes, the clutch comeback, the machine
crowd and the sour honk.

    python extras.py <render folder>

Pilot quotes play each class's existing leitmotif cells from Harmony.MOTIFS (harmony.gd), on
tenor sax at the band's step (3846 samples at 44.1 kHz, a sixteenth at 172 BPM), with a brass hit
and kick under the last note. Same notes, new voice, so the class cue, the counter-line and the
quote stay one tune. Writes 48 kHz mono WAVs and manifest.json (check_events.py format) to
<render folder>/extras/, plus four demo reels that put them over real tracks.
"""

import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from event_sounds import SR, bell, hz, noise_burst, place, sax, t_of  # noqa: E402
from event_set import brass, chord, crunch, mix, square, sub, sweep  # noqa: E402
from variations import bar, buff_preview, load, low_hull, norm  # noqa: E402

STEP = 3846 / 44100
NAMES = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
# Copied from Harmony.MOTIFS in src/presentation/harmony.gd: [step, midi, steps].
MOTIFS = {
    "sable": [[0, 62, 1], [1, 65, 1], [2, 69, 1], [3, 72, 1], [4, 76, 2]],
    "rivet": [[0, 69, 1], [1, 69, 1], [2, 69, 1], [4, 74, 2]],
    "kest": [[0, 62, 2], [2, 57, 2], [4, 53, 2], [6, 50, 4]],
    "tarn": [[0, 50, 1], [2, 50, 1], [3, 51, 1], [4, 57, 3]],
    "tally": [[0, 62, 1], [1, 64, 1], [2, 65, 1], [3, 67, 1], [5, 74, 3]],
    "cannon": [[0, 59, 2], [2, 64, 1], [3, 67, 1], [4, 74, 4]],
}
SAX_LOW = 56  # below this a tenor line turns to mud under the band, so it moves up an octave


def name(midi):
    return f"{NAMES[midi % 12]}{midi // 12 - 1}"


def pilot_quote(cells):
    """The band quotes your motif: sax on the cells, kick on the first, brass and crash on the last."""
    shift = 12 if min(m for _, m, _ in cells) < SAX_LOW else 0
    end = max(s + n for s, _, n in cells) * STEP
    out = np.zeros(int((end + 0.9) * SR))
    for s, midi, n in cells:
        place(out, sax(name(midi + shift), max(n * STEP * 1.05, 0.12), 0.55), s * STEP)
    place(out, sub(0.25, 150, 50, 0.12, 0.7), 0)
    last_step, last, _ = cells[-1]
    root = last + shift - 12
    place(out, chord(brass, (name(root), name(root + 7), name(root + 12)), 0.5, 0.25), last_step * STEP)
    place(out, crunch(0.5, 0.2, 0.3), last_step * STEP)
    return out


def clutch():
    """Survived on 1 hull: a one-bar riser out of the muffled band, a beat of breath, then the band
    slams back a half step up (Eb) with a bell wink. The key lift is the comeback."""
    b = bar(129)
    out = np.zeros(int((b + 60 / 129 + 1.6) * SR))
    place(out, sweep(b, 300, 9000, 0.45), 0)
    for k in range(16):
        place(out, noise_burst(0.06, 0.02, 2) * (0.1 + 0.4 * k / 15), k * b / 16)
    hit = b + 60 / 129 * 0.5
    place(out, chord(brass, ("Eb3", "Bb3", "Eb4", "G4"), 1.0, 0.4), hit)
    place(out, sub(0.8, 140, 39, 0.4, 0.9), hit)
    place(out, crunch(0.9, 0.35, 0.5), hit)
    place(out, bell("Eb6", 0.8, ratio=2.0, level=0.3), hit + 0.5)
    return out


def whistle(note, seconds, level):
    """A steam whistle: a breathy sine that scoops up into its pitch."""
    t = t_of(seconds)
    f = hz(note) * (1 - 0.06 * np.exp(-t / 0.08))
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    breath = np.convolve(np.random.default_rng(int(hz(note))).standard_normal(len(t)), np.ones(4) / 4, "same")
    shape = np.minimum(t / 0.03, 1) * np.minimum((seconds - t) / 0.08, 1).clip(0, 1)
    return level * (tone + 0.25 * breath) * shape


def crowd(tier):
    """The machine crowd cheers a long chain: whistles on a D chord, clanks on the beat, ratchet
    applause. Tier 1 at chain 20, 2 at 35, 3 at 50; each adds whistles and runs longer."""
    rng = np.random.default_rng(tier)
    seconds = 0.9 + 0.45 * tier
    out = np.zeros(int(seconds * SR))
    for i, note in enumerate(("D5", "A5", "F#5", "D6", "A6")[: 2 + tier]):
        place(out, whistle(note, seconds * 0.7 - 0.05 * i, 0.22), 0.04 * i)
    for k in range(int(seconds / (60 / 129))):
        place(out, bell("D4", 0.15, ratio=2.4, level=0.3), k * 60 / 129)
    for _ in range(int(30 * tier * seconds)):
        place(out, noise_burst(0.01, 0.002, 1) * rng.uniform(0.05, 0.15), rng.uniform(0, seconds * 0.85))
    return out


def honk():
    """A whiffed smash: one sour honk, a sax Ab3 (the tritone off home) that sags a quarter tone."""
    t = t_of(0.42)
    note = sax("Ab3", 0.42, 0.7)
    sag = np.interp(np.arange(len(note)) * (1 - 0.03 * (t / 0.42) ** 2), np.arange(len(note)), note)
    return sag + 0.25 * np.tanh(4 * sag)


def supersaw(note, seconds, level=1.0):
    """Seven detuned saws: the Eurodance stab."""
    t = t_of(seconds)
    out = sum(2 * ((hz(note) * (1 + d) * t + p) % 1) - 1
              for d, p in zip((-0.02, -0.012, -0.005, 0, 0.005, 0.012, 0.02), np.linspace(0, 0.9, 7)))
    return level * out / 7 * np.minimum(t / 0.004, 1) * np.exp(-t / (seconds / 2.5))


def hype_drop(bpm=150):
    """The phase 2 to 3 handover, on every boss and champion: one bar of riser and snare roll,
    a beat of silence, then the drop lands on an 808 and a supersaw D minor stab."""
    b, beat = bar(bpm), 60 / bpm
    out = np.zeros(int((b + beat + 1.4) * SR))
    place(out, sweep(b, 200, 12000, 0.4), 0)
    for k in range(32):
        place(out, noise_burst(0.05, 0.015, 2) * (0.05 + 0.45 * k / 31), k * b / 32)
    drop = b + beat
    place(out, sub(1.2, 180, 37, 0.5, 1.0), drop)
    place(out, chord(supersaw, ("D4", "F4", "A4", "D5"), 0.6, 0.35), drop)
    place(out, crunch(0.8, 0.3, 0.45), drop)
    return out


def retry_kickin(bpm=129):
    """Go again: four kicks climbing to the downbeat, a rave stab and the 808, straight into the groove."""
    beat = 60 / bpm
    out = np.zeros(int((4 * beat + 1.0) * SR))
    for k in range(4):
        place(out, sub(0.2, 160 + 40 * k, 50, 0.09, 0.5 + 0.12 * k), k * beat)
    place(out, sax("A4", beat * 0.5, 0.35), 3 * beat)
    place(out, sax("D5", beat * 0.5, 0.4), 3.5 * beat)
    place(out, chord(supersaw, ("D4", "F4", "A4", "C5"), 0.5, 0.3), 4 * beat)
    place(out, sub(0.6, 150, 37, 0.3, 0.9), 4 * beat)
    return out


def main():
    root = Path(sys.argv[1])
    out = root / "extras"
    out.mkdir(exist_ok=True)
    cues = {f"pilot_quote_{p}": ("stinger", lambda c=c: pilot_quote(c)) for p, c in MOTIFS.items()}
    cues.update({"clutch_comeback": ("stinger", clutch), "whiff_honk": ("ui", honk),
                 "hype_drop": ("stinger", hype_drop), "retry_kickin": ("stinger", retry_kickin),
                 **{f"crowd_cheer_{n}": ("reward", lambda n=n: crowd(n)) for n in (1, 2, 3)}})
    manifest = []
    for cue, (family, make) in cues.items():
        audio = make()
        nz = np.nonzero(np.abs(audio) > 1e-4)[0]
        audio = audio[: nz[-1] + 1]
        fade = min(int(0.004 * SR), len(audio) // 4)
        audio[-fade:] *= np.linspace(1, 0, fade)
        sf.write(out / f"{cue}.wav", norm(audio).astype(np.float32), SR, subtype="PCM_16")
        manifest.append(dict(cue=cue, family=family, seconds=round(len(audio) / SR, 3)))
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1))

    def wav(cue):
        return sf.read(out / f"{cue}.wav")[0]

    gap = np.zeros(int(0.6 * SR))
    reel = np.concatenate([np.concatenate([wav(f"pilot_quote_{p}"), gap]) for p in MOTIFS])
    sf.write(out / "demo-pilot-quotes.wav", norm(reel).astype(np.float32), SR, subtype="PCM_16")

    src = root / "variant-src"
    hype = load(src / "hype-129.wav")
    b = int(bar(129) * SR)
    dying = low_hull(hype[: 4 * b].copy(), 129)
    lifted = load(src / "hype-129-up1.wav")[: 4 * b] if (src / "hype-129-up1.wav").exists() else hype[: 4 * b]
    c = wav("clutch_comeback")
    hit_at = 4 * b + int((bar(129) + 60 / 129 * 0.5) * SR)
    demo = np.zeros(hit_at + len(lifted) + SR)
    place(demo, dying * 0.7, 0)
    place(demo, c * 0.9, 4 * b / SR)
    place(demo, lifted * 0.7, hit_at / SR)
    sf.write(out / "demo-clutch.wav", norm(demo).astype(np.float32), SR, subtype="PCM_16")

    bed = hype[: 6 * b] * 0.6
    for i, n in enumerate((1, 2, 3)):
        place(bed, wav(f"crowd_cheer_{n}") * 0.8, (i * 2 * b) / SR)
    sf.write(out / "demo-crowd.wav", norm(bed).astype(np.float32), SR, subtype="PCM_16")

    bed = hype[: 2 * b] * 0.6
    place(bed, wav("whiff_honk") * 0.8, 6 * 60 / 129)
    sf.write(out / "demo-honk.wav", norm(bed).astype(np.float32), SR, subtype="PCM_16")
    print(f"{len(manifest)} cues and 4 demos written to {out}")


if __name__ == "__main__":
    main()
