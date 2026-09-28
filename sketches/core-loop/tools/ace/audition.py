"""Loop, match and measure the ACE-Step cover audition against the engine's guide.

Reads <dir>/guide.json and the files ace_guide.gd, run.py and separate.py wrote there.
Writes <dir>/loops/*.loop.wav (16 bars on the guide's grid, 20 ms wrap crossfade,
-14 LUFS under a -1 dBFS ceiling), their Opus 96 kbps encodes, loop-test-guide.wav and
loop-test-cover.wav (three passes each), and metrics.json.

    /home/andrew/Projects/music-video/.venv/bin/python audition.py <dir> <cover>.wav
"""

import json
import subprocess
import sys
from math import gcd
from pathlib import Path

import librosa
import numpy as np
import pyloudnorm
import soundfile as sf
from scipy.ndimage import minimum_filter1d
from scipy.signal import butter, resample_poly, sosfiltfilt, welch
from scipy.stats import theilslopes

SR = 44100
TARGET_LUFS = -14.0
CEILING = 10 ** (-1 / 20)
MAX_LIMIT_DB = 8.0
XFADE = int(0.020 * SR)
HOP = 64
MAX_LAG_S = 0.120
OUTLIER_MS = 40.0
DORIAN_D = {2, 4, 5, 7, 9, 11, 0}
NOTES = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
KS_MAJOR = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
KS_MINOR = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])
BANDS = [("sub", 20, 60), ("low", 60, 250), ("mid", 250, 2000), ("high", 2000, 8000), ("air", 8000, 20000)]
METER = pyloudnorm.Meter(SR)


def load(path):
    y, sr = sf.read(path, dtype="float64", always_2d=True)
    if sr != SR:
        g = gcd(SR, sr)
        y = resample_poly(y, SR // g, sr // g, axis=0)
    return y


def lufs(y):
    return float(METER.integrated_loudness(y))


def db(x):
    return float(20 * np.log10(max(x, 1e-12)))


def segment(y, start, length):
    out = np.zeros((length, y.shape[1]))
    a, b = max(start, 0), min(start + length, len(y))
    if b > a:
        out[a - start:b - start] = y[a:b]
    return out


def kick_envelope(y):
    mono = sosfiltfilt(butter(4, 150, "low", fs=SR, output="sos"), y.mean(axis=1))
    return librosa.onset.onset_strength(y=mono.astype(np.float32), sr=SR, hop_length=HOP, n_fft=1024)


def drift(guide_drums, cover_drums, bar, bars):
    """Per-bar lag of the cover's kick onsets behind the guide's, by cross-correlation."""
    g, c = kick_envelope(guide_drums), kick_envelope(cover_drums)
    reach = int(MAX_LAG_S * SR / HOP)
    lags = []
    for b in range(bars):
        a0, a1 = round(b * bar / HOP), round((b + 1) * bar / HOP)
        ref = g[a0:a1] - g[a0:a1].mean()
        scores = []
        for lag in range(-reach, reach + 1):
            seg = c[max(a0 + lag, 0):a1 + lag]
            if a0 + lag < 0 or len(seg) < len(ref):
                scores.append(-np.inf)
                continue
            scores.append(float(np.dot(ref, seg - seg.mean())))
        scores = np.array(scores)
        k = int(np.argmax(scores))
        frac = 0.0
        if 0 < k < len(scores) - 1 and np.isfinite(scores[k - 1]) and np.isfinite(scores[k + 1]):
            den = scores[k - 1] - 2 * scores[k] + scores[k + 1]
            frac = 0.5 * (scores[k - 1] - scores[k + 1]) / den if den else 0.0
        lags.append((k - reach + frac) * HOP / SR * 1000)
    lags = np.array(lags)
    x = np.arange(bars)
    slope, offset, _, _ = theilslopes(lags, x)
    residual = lags - (slope * x + offset)
    inliers = np.abs(residual) <= OUTLIER_MS
    return dict(lag_ms_per_bar=[round(v, 2) for v in lags], slope_ms_per_bar=round(float(slope), 3),
                offset_ms=round(float(offset), 2), bar1_lag_ms=round(float(lags[0]), 2),
                worst_abs_lag_ms=round(float(np.abs(lags).max()), 2),
                outlier_bars=[int(b) + 1 for b in np.flatnonzero(~inliers)],
                inlier_residual_rms_ms=round(float(np.sqrt(np.mean(residual[inliers] ** 2))), 2),
                total_drift_ms_over_16_bars=round(float(slope * bars), 2),
                fit="Theil-Sen over the per-bar lags; outliers are bars more than 40 ms off the line")


def limit(y):
    """audio_board.gd's limiter: 1.5 ms look-ahead to the ceiling, 80 ms release."""
    n, w = len(y), int(0.0015 * SR)
    need = np.minimum(1.0, CEILING / np.maximum(np.abs(y).max(axis=1), 1e-9))
    held = minimum_filter1d(need, w, origin=-(w // 2), mode="nearest")
    rel = 1.0 - np.exp(-1.0 / (0.08 * SR))
    level = 1.0
    for j in range(n):
        level = min(held[j], level + (1.0 - level) * rel)
        held[j] = level
    run = np.convolve(held, np.ones(w))[:n] / np.minimum(np.arange(1, n + 1), w)
    g = np.minimum(run, need)
    return y * g[:, None], -db(g.min())


def match(y):
    """audio_board's match, repeated while limiting leaves the take short of the target."""
    before = lufs(y)
    gain = TARGET_LUFS - before
    for _ in range(4):
        over = db(np.abs(y).max() * 10 ** (gain / 20) / CEILING)
        if over > MAX_LIMIT_DB:
            gain -= over - MAX_LIMIT_DB
        out, limited = limit(y * 10 ** (gain / 20))
        after = lufs(out)
        if after > TARGET_LUFS - 0.1 or over > MAX_LIMIT_DB:
            break
        gain += TARGET_LUFS - after
    return out, dict(lufs_before=round(before, 2), gain_db=round(gain, 2), limit_db=round(limited, 2),
                     lufs_after=round(after, 2), peak_dbfs=round(db(np.abs(out).max()), 2))


def wrap(body, tail):
    """The loop: the tail after bar 16 fades out over the first 20 ms as the head fades in."""
    t = np.linspace(0, np.pi / 2, XFADE)[:, None]
    out = body.copy()
    out[:XFADE] = body[:XFADE] * np.sin(t) + tail[:XFADE] * np.cos(t)
    return out


def seam(loop):
    """Largest sample step across the join (three passes), against the loop's own steps."""
    steps = np.abs(np.diff(loop, axis=0)).max(axis=1)
    join = float(np.abs(loop[0] - loop[-1]).max())
    wrapped = np.concatenate([loop[-XFADE:], loop[:XFADE]]).mean(axis=1)
    windows = loop[:len(loop) // (2 * XFADE) * 2 * XFADE].mean(axis=1).reshape(-1, 2 * XFADE)
    body_rms = np.median(np.sqrt(np.mean(windows ** 2, axis=1)))
    return dict(join_step_dbfs=round(db(join), 1), body_p999_step_dbfs=round(db(np.quantile(steps, 0.999)), 1),
                body_max_step_dbfs=round(db(steps.max()), 1),
                join_over_p999_db=round(db(join) - db(np.quantile(steps, 0.999)), 1),
                join_40ms_rms_vs_body_median_db=round(db(np.sqrt(np.mean(wrapped ** 2))) - db(body_rms), 1))


def chroma_of(y, hop=2048):
    mono = sosfiltfilt(butter(4, 200, "high", fs=SR, output="sos"), y.mean(axis=1))
    return librosa.feature.chroma_cqt(y=mono.astype(np.float32), sr=SR, hop_length=hop)


def key(y):
    chroma = chroma_of(y).mean(axis=1)
    chroma = chroma / chroma.sum()
    best = max(((float(np.corrcoef(np.roll(p, k), chroma)[0, 1]), f"{NOTES[k]} {m}")
                for p, m in ((KS_MAJOR, "major"), (KS_MINOR, "minor")) for k in range(12)))
    return chroma, dict(ks_key=best[1], ks_r=round(best[0], 3),
                        dorian_d_energy=round(float(sum(chroma[i] for i in DORIAN_D)), 3),
                        top_pitch_classes=[NOTES[i] for i in np.argsort(chroma)[::-1][:7]])


def per_bar_chroma(y, bar, bars):
    frames = chroma_of(y, hop=512)
    per = frames.shape[1] / (len(y) / bar)
    out = np.stack([frames[:, round(b * per):round((b + 1) * per)].mean(axis=1) for b in range(bars)])
    return out / np.linalg.norm(out, axis=1, keepdims=True)


def follows_chords(guide, cover, bar, bars):
    """Cosine per bar, cover vs guide, against the guide's own next bar as a wrong-chord baseline."""
    g, c = per_bar_chroma(guide, bar, bars), per_bar_chroma(cover, bar, bars)
    same = (g * c).sum(axis=1)
    wrong = (g[:-1] * g[1:]).sum(axis=1)
    return dict(cover_vs_guide_mean=round(float(same.mean()), 3), cover_vs_guide_min=round(float(same.min()), 3),
                guide_vs_next_bar_mean=round(float(wrong.mean()), 3),
                bars_closer_to_guide_than_baseline=int((same > wrong.mean()).sum()))


def sdr(truth, estimate):
    n = min(len(truth), len(estimate))
    t, e = truth[:n], estimate[:n]
    return round(10 * np.log10(np.sum(t ** 2) / np.sum((t - e) ** 2)), 1)


def tail_level(y, bar):
    """The last 50 ms against the median bar, in dB: a cover that fades its ending shows here."""
    mono = y.mean(axis=1)
    last = db(np.sqrt(np.mean(mono[-int(0.05 * SR):] ** 2)))
    bars_rms = [db(np.sqrt(np.mean(mono[b * bar:(b + 1) * bar] ** 2))) for b in range(len(mono) // bar)]
    return round(last - float(np.median(bars_rms)), 1)


def bands(y):
    f, p = welch(y.mean(axis=1), fs=SR, nperseg=8192)
    total = p.sum()
    out = {name: round(10 * np.log10(p[(f >= lo) & (f < hi)].sum() / total + 1e-12), 1) for name, lo, hi in BANDS}
    out["centroid_hz"] = round(float((f * p).sum() / total))
    return out


def bleed(y):
    f, p = welch(y.mean(axis=1), fs=SR, nperseg=8192)
    return round(10 * np.log10(p[f >= 300].sum() / p[f < 300].sum()), 1)


def shape(y, bar):
    mono = y.mean(axis=1)
    per_bar = [db(np.sqrt(np.mean(mono[b * bar:(b + 1) * bar] ** 2))) for b in range(len(mono) // bar)]
    rms = np.sqrt(np.mean(mono ** 2))
    return dict(crest_db=round(db(np.abs(mono).max()) - db(rms), 1),
                per_bar_rms_spread_db=round(float(np.std(per_bar)), 2))


def opus(path):
    out = path.with_suffix(".opus")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(path), "-c:a", "libopus", "-b:a", "96k", str(out)],
                   check=True)
    return out


def main():
    root, cover_path = Path(sys.argv[1]), Path(sys.argv[2])
    info = json.loads((root / "guide.json").read_text())
    bar, bars = info["samples_per_bar"], info["bars"]
    n = bar * bars
    loops = root / "loops"
    loops.mkdir(exist_ok=True)
    cover_stems = {s: cover_path.with_suffix(f".{s}.wav") for s in ("drums", "bass", "other")}
    guide = root / "guide-spillway-16bar.wav"

    cover_raw = sf.info(str(cover_path))
    lag = drift(load(guide.with_suffix(".drums.wav")), load(cover_stems["drums"]), bar, bars)
    offset = round(lag["offset_ms"] / 1000 * SR)
    cover_len = int(round(cover_raw.frames * SR / cover_raw.samplerate))

    sources = {
        "guide-mix": (load(guide), load(guide.with_suffix(".overrun.wav")), 0),
        "guide-core": (load(root / "guide-spillway-16bar-core.wav"), load(root / "guide-spillway-16bar-core.overrun.wav"), 0),
        "cover-mix": (load(cover_path), None, offset),
        **{f"cover-{s}": (load(p), None, offset) for s, p in cover_stems.items()},
    }
    metrics = dict(guide=dict(bpm=info["bpm"], samples_per_bar=bar, sample_rate=SR, bars=bars, frames=n),
                   cover_source=dict(path=str(cover_path), sample_rate=cover_raw.samplerate, frames=cover_raw.frames,
                                     seconds=round(cover_raw.duration, 4)),
                   drift=lag, trim_offset_samples=offset,
                   cover_tail_available_ms=round(max(0, cover_len - offset - n) / SR * 1000, 1),
                   cover_short_by_ms=round(max(0, offset + n - cover_len) / SR * 1000, 1),
                   files={})
    tempo = {}
    for label in ("guide-mix", "cover-mix"):
        y = sources[label][0]
        bpm_est, _ = librosa.beat.beat_track(y=y.mean(axis=1).astype(np.float32), sr=SR, start_bpm=172, units="time")
        tempo[label] = round(float(np.atleast_1d(bpm_est)[0]), 2)
    metrics["librosa_tempo"] = tempo

    chromas = {}
    loop_audio = {}
    for label, (y, overrun, start) in sources.items():
        body = segment(y, start, n)
        tail = overrun if overrun is not None else segment(y, start + n, XFADE)
        hard_seam = seam(body)
        looped, loud = match(wrap(body, tail))
        loop_audio[label] = looped
        path = loops / f"{label}.loop.wav"
        sf.write(path, looped, SR, subtype="PCM_16")
        enc = opus(path)
        row = dict(path=str(path), opus=str(enc), wav_bytes=path.stat().st_size, opus_bytes=enc.stat().st_size,
                   lufs_source=round(lufs(y), 2), **loud, seam=seam(looped), seam_without_crossfade=hard_seam,
                   bands=bands(looped), **shape(looped, bar))
        if label.endswith("mix"):
            chromas[label], row["key"] = key(looped)
        metrics["files"][label] = row
        print(f"{label}: {loud}  seam {row['seam']['join_step_dbfs']} dBFS", flush=True)

    for label in ("guide", "cover"):
        test = np.tile(loop_audio[f"{label}-mix"], (3, 1))
        sf.write(root / f"loop-test-{label}.wav", test, SR, subtype="PCM_16")
    a, b = chromas["guide-mix"], chromas["cover-mix"]
    metrics["chroma_cosine_guide_vs_cover"] = round(float(a @ b / np.linalg.norm(a) / np.linalg.norm(b)), 3)

    metrics["bleed_db_above_vs_below_300hz"] = {
        "engine_bass_solo_truth": bleed(load(root / "guide-spillway-16bar-bass.wav")),
        "demucs_bass_of_guide": bleed(load(guide.with_suffix(".bass.wav"))),
        "demucs_bass_of_cover": bleed(load(cover_stems["bass"])),
    }
    stems = [metrics["files"][f"cover-{s}"] for s in ("drums", "bass", "other")]
    per_set_wav, per_set_opus = sum(s["wav_bytes"] for s in stems), sum(s["opus_bytes"] for s in stems)
    metrics["disk_projection"] = dict(
        basis="3 stems (drums, bass, other) x 16 bars per pressure step, 6 steps x 3 stages = 54 files",
        per_step_wav_bytes=per_set_wav, per_step_opus_bytes=per_set_opus,
        total_wav_mib=round(per_set_wav * 18 / 2**20, 1), total_opus_mib=round(per_set_opus * 18 / 2**20, 2))
    (root / "metrics.json").write_text(json.dumps(metrics, indent=1))
    print(json.dumps({k: v for k, v in metrics.items() if k != "files"}, indent=1))


if __name__ == "__main__":
    main()
