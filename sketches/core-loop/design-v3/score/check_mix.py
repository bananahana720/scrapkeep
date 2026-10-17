"""Mix and master check: a pass/fail row per track, so every cue sits at one loudness, in its own
frequency and stereo slot, and loops without a click.

    python check_mix.py [--cues] <file|folder> ...      table to stdout, JSON lines to --json <path>

With --cues, a file whose name starts with a cue id from themes.py (title-a, roam-dig, ...) is
also checked for key against that cue (check_score.py's scale fit).

Targets (one table, SCORE.md "Mix and master"):
  loudness      integrated -16 LUFS +/- 0.5 (ffmpeg's EBU R128 meter)
  true peak     at or below -1 dBTP (the same meter, 4x oversampled)
  low end mono  L/R correlation below 150 Hz at least 0.9, so kick, bass and 808 sit centre
  width         side/mid energy 0.08 to 0.6: a real stereo stage, never collapsing in mono
  balance       each band's share of energy inside the window of the cue's role (BANDS)
  lead space    2 to 5 kHz energy at least LEAD_MIN of the 250 Hz to 2 kHz energy, so the sax reads
  loop seam     the last and first 50 ms within 3 dB and spectrally close, for files cut as loops
  clipping      no run of 3+ samples at full scale
Standard library, NumPy and ffmpeg only.
"""

import json
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

SR = 48000
TARGET_LUFS, LUFS_TOL, MAX_TP = -16.0, 0.5, -1.0
LEAD_MIN = 0.06
# (name, low Hz, high Hz, min share, max share) of total energy. Wide on purpose: they catch a
# track whose sub swamps everything or whose lead register is empty, not taste.
BANDS = [
    ("sub", 20, 60, 0.03, 0.35),
    ("low", 60, 250, 0.15, 0.55),
    ("low-mid", 250, 2000, 0.12, 0.50),
    ("presence", 2000, 5000, 0.02, 0.20),
    ("air", 5000, 16000, 0.005, 0.15),
]
AUDIO = {".wav", ".mp3", ".flac", ".ogg"}


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "2", "-ar", str(SR),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").astype(float).reshape(-1, 2)


def meter(path):
    """Integrated loudness and true peak from ffmpeg's EBU R128 meter, the reference
    implementation, rather than a home-made one."""
    log = subprocess.run(["ffmpeg", "-nostats", "-i", str(path), "-af", "ebur128=peak=true", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    summary = log[log.rindex("Summary:"):]
    integrated = float(summary.split("I:")[1].split("LUFS")[0])
    peak = float(summary.split("Peak:")[1].split("dBFS")[0])
    return integrated, peak


def band_energy(mono, lo, hi):
    spec = np.abs(np.fft.rfft(mono)) ** 2
    f = np.fft.rfftfreq(len(mono), 1 / SR)
    return spec[(f >= lo) & (f < hi)].sum(), spec[(f >= 20) & (f < 16000)].sum()


def low_mono(x):
    f = np.fft.rfftfreq(len(x), 1 / SR)
    keep = f < 150
    lo = [np.fft.irfft(np.fft.rfft(x[:, c]) * keep, len(x)) for c in (0, 1)]
    return float(np.corrcoef(lo[0], lo[1])[0, 1]) if lo[0].std() > 1e-6 else 1.0


def width(x):
    mid, side = (x[:, 0] + x[:, 1]) / 2, (x[:, 0] - x[:, 1]) / 2
    return float((side ** 2).sum() / ((mid ** 2).sum() + 1e-12))


def seam(x):
    n = int(0.05 * SR)
    head, tail = x[:n].mean(axis=1), x[-n:].mean(axis=1)
    db = lambda s: 10 * np.log10((s ** 2).mean() + 1e-12)  # noqa: E731
    jump = abs(db(head) - db(tail))
    sh, st = np.abs(np.fft.rfft(head)), np.abs(np.fft.rfft(tail))
    sim = float((sh * st).sum() / (np.linalg.norm(sh) * np.linalg.norm(st) + 1e-12))
    return round(jump, 1), round(sim, 2)


def clipped(x):
    full = np.abs(x) >= 0.999
    runs = full[2:] & full[1:-1] & full[:-2]
    return int(runs.sum())


def cue_of(path):
    import themes
    stem = Path(path).stem
    return max((c for c in themes.CUES if stem.startswith(c)), key=len, default=None)


def check(path, with_cues=False, is_loop=None):
    x = load(path)
    mono = x.mean(axis=1)
    loud, tp = meter(path)
    shares = {}
    for name, lo, hi, _, _ in BANDS:
        e, total = band_energy(mono, lo, hi)
        shares[name] = e / (total + 1e-12)
    lead_space = shares["presence"] / (shares["low-mid"] + 1e-12)
    jump, sim = seam(x)
    loop = is_loop if is_loop is not None else "loop" in Path(path).stem or "roam" in Path(path).stem
    row = {
        "file": Path(path).name,
        "lufs": round(loud, 1), "lufs_ok": abs(loud - TARGET_LUFS) <= LUFS_TOL,
        "true_peak": round(tp, 1), "peak_ok": tp <= MAX_TP,
        "low_mono": round(low_mono(x), 2), "low_mono_ok": low_mono(x) >= 0.9,
        "width": round(width(x), 2), "width_ok": 0.08 <= width(x) <= 0.6,
        "bands": {k: round(v, 3) for k, v in shares.items()},
        "balance_ok": all(lo_s <= shares[n] <= hi_s for n, _, _, lo_s, hi_s in BANDS),
        "lead_space": round(lead_space, 2), "lead_ok": lead_space >= LEAD_MIN,
        "clip_runs": clipped(x), "clip_ok": clipped(x) == 0,
    }
    if loop:
        row.update(seam_db=jump, seam_sim=sim, seam_ok=jump <= 3 and sim >= 0.5)
    if with_cues and (cue := cue_of(path)):
        import check_score
        import themes
        full, _ = themes.render(cue, len(x) / SR + 30)
        offset, best, home = check_score.key_offset(check_score.salience(check_score.resample(x.mean(axis=1), SR)),
                                                    check_score.salience(check_score.resample(full, themes.SR)))
        row.update(cue=cue, key_offset=offset, key_ok=offset == 0 or best - home < check_score.KEY_TIE)
    row["pass"] = all(v for k, v in row.items() if k.endswith("_ok"))
    row["fails"] = [k[:-3] for k, v in row.items() if k.endswith("_ok") and not v]
    return row


def main(argv):
    with_cues = "--cues" in argv
    out = argv[argv.index("--json") + 1] if "--json" in argv else None
    paths = []
    for a in argv:
        if a.startswith("--") or a == out:
            continue
        p = Path(a)
        paths += sorted(q for q in p.rglob("*") if q.suffix in AUDIO) if p.is_dir() else [p]
    if not paths:
        print(__doc__)
        return 2
    rows = [check(p, with_cues) for p in paths]
    print(f"{'file':44} {'LUFS':>6} {'TP':>5} {'lowM':>5} {'width':>5} {'lead':>5}  result")
    for r in rows:
        print(f"{r['file'][:44]:44} {r['lufs']:6} {r['true_peak']:5} {r['low_mono']:5} {r['width']:5} "
              f"{r['lead_space']:5}  {'PASS' if r['pass'] else 'FAIL ' + ', '.join(r['fails'])}")
    if out:
        Path(out).write_text("".join(json.dumps(r) + "\n" for r in rows))
    return 0 if all(r["pass"] for r in rows) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
