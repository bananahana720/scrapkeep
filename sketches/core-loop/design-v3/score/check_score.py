"""Checks a render against its row in the cue sheet (themes.py CUES): is it in the cue's key, and
did it keep the cue's written melody?

    python check_score.py <take> <cue> [<take> <cue> ...]

<take> is any file ffmpeg reads; use the htdemucs "other" stem when there is one, since the lead
sits there without the drums. The take must already sit on the cue's tempo grid (grid_stretch.py).

Key: the take's pitch-class profile against the guide's (the cue's own notes and chords) at all
12 transpositions; passes when the guide's own key fits best or within KEY_TIE of the best.
Melody: the take's lead-register pitch classes over time against the cue's written lead line
(the guide), at the best lag within one phrase, against a control: the lead line of a cue from a
different theme in the same key. Passes when the parent beats the control by 0.1, the same
margin measure_variants.py uses for covers. Prints one JSON line per take. Exit 1 if any fails.
"""

import json
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import themes  # noqa: E402

SR, HOP, N = 22050, 2048, 8192
MARGIN = 0.1
# Modes that share one note collection (D Dorian, G Mixolydian, E Phrygian) fit within a hair of
# each other, so a near tie counts as in key. This proves the scale, not the tonic; the melody
# check is what tells the Dig's E from the Spillway's D.
KEY_TIE = 0.05


def load(path, seconds=64):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-t", str(seconds), "-ac", "1",
                          "-ar", str(SR), "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").astype(float)


def resample(audio, sr):
    return np.interp(np.arange(0, len(audio), sr / SR), np.arange(len(audio)), audio)


def chroma(x, lo, hi):
    frames = np.lib.stride_tricks.sliding_window_view(x, N)[::HOP] * np.hanning(N)
    mag = np.abs(np.fft.rfft(frames, axis=1))
    f = np.fft.rfftfreq(N, 1 / SR)
    keep = (f > lo) & (f < hi)
    pc = np.round(12 * np.log2(f[keep] / 440.0)).astype(int) % 12
    pc = (pc + 9) % 12  # index 0 is C
    out = np.zeros((len(frames), 12))
    for k in range(12):
        out[:, k] = mag[:, keep][:, pc == k].sum(axis=1)
    return out


def salience(x, low=36, high=96):
    """Pitch-class salience by harmonic summation: each candidate pitch from C2 to B6 collects its
    first four harmonics at weights 1, 1/2, 1/3, 1/4. A bright lead's third harmonic would
    otherwise pull the profile a fifth up."""
    frames = np.lib.stride_tricks.sliding_window_view(x, N)[::HOP] * np.hanning(N)
    mag = np.abs(np.fft.rfft(frames, axis=1))
    mag = mag / (mag.max(axis=1, keepdims=True) + 1e-9)
    out = np.zeros(12)
    for midi in range(low, high):
        f0 = 440 * 2 ** ((midi - 69) / 12)
        bins = [int(round(f0 * h * N / SR)) for h in range(1, 5)]
        out[midi % 12] += sum(mag[:, b].sum() / h for h, b in enumerate(bins, 1) if b < mag.shape[1])
    return out


def key_offset(take_profile, guide_profile):
    """Semitones the take sits from the guide's key: the rotation of the guide's pitch-class
    profile that best fits the take. 0 means the take is in the cue's key. Modal and cadential
    phrases defeat a major/minor key finder (E Phrygian reads as C major), but comparing with
    the cue's own notes and chords does not need to name the mode."""
    fits = [np.corrcoef(np.roll(guide_profile, r), take_profile)[0, 1] for r in range(12)]
    best = int(np.argmax(fits))
    return (best + 6) % 12 - 6, round(float(fits[best]), 2), round(float(fits[0]), 2)


def lead_chroma(x):
    """Lead register only, each frame normalised, quiet frames zeroed."""
    c = chroma(x, 220, 1600)
    energy = c.sum(axis=1)
    c = c / (energy[:, None] + 1e-9)
    c[energy < 0.05 * np.median(energy[energy > 0])] = 0
    return c


def match(take, guide, phrase_frames):
    """Mean cosine between the take and the guide at the best lag within one phrase."""
    best = 0.0
    for lag in range(max(1, phrase_frames)):
        g = guide[lag:]
        n = min(len(take), len(g))
        a, b = take[:n], g[:n]
        live = (a.sum(axis=1) > 0) & (b.sum(axis=1) > 0)
        if live.sum() < 8:
            continue
        cos = (a[live] * b[live]).sum(axis=1) / (np.linalg.norm(a[live], axis=1) * np.linalg.norm(b[live], axis=1) + 1e-9)
        best = max(best, float(cos.mean()))
    return best


def control_for(cue):
    row = themes.CUES[cue]
    same_key = [c for c, r in themes.CUES.items() if r["theme"] != row["theme"] and r["tonic"] == row["tonic"]]
    other = [c for c, r in themes.CUES.items() if r["theme"] != row["theme"]]
    return (same_key or other)[0]


def guide_lead(cue, seconds):
    _, lead = themes.render(cue, seconds)
    return resample(lead, themes.SR)


def check(path, cue):
    row = themes.CUES[cue]
    x = load(path)
    seconds = len(x) / SR
    full, lead = themes.render(cue, seconds + 30)
    offset, best_fit, home_fit = key_offset(salience(x), salience(resample(full, themes.SR)))
    take = lead_chroma(x)
    control = control_for(cue)
    notes, chords, _ = themes.derive(cue)
    phrase_frames = int(4 * len(chords) * 60 / row["bpm"] * SR / HOP)
    parent = match(take, lead_chroma(resample(lead, themes.SR)), phrase_frames)
    other = match(take, lead_chroma(guide_lead(control, seconds + 30)), phrase_frames)
    result = {
        "take": Path(path).name, "cue": cue,
        "key_offset": offset, "key_fit": home_fit, "key_best_fit": best_fit, "key_ok": offset == 0 or best_fit - home_fit < KEY_TIE,
        "melody_parent": round(parent, 3), "melody_control": round(other, 3), "control_cue": control,
        "melody_ok": parent - other >= MARGIN,
    }
    result["pass"] = result["key_ok"] and result["melody_ok"]
    return result


def main(argv):
    if len(argv) < 2 or len(argv) % 2:
        print(__doc__)
        return 2
    ok = True
    for path, cue in zip(argv[::2], argv[1::2]):
        result = check(path, cue)
        ok &= result["pass"]
        print(json.dumps(result))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
