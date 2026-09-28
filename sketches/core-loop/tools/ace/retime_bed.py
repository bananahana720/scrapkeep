"""Retime the ACE-Step cover to the engine's grid per bar and build the hybrid bed.

Reads the audition dir (guide.json, the guide's demucs drums, the unlooped 48 kHz cover
and its stems) and the engine dir ace_guide_v3.gd wrote (engine.json and engine-*.wav).
Each cover bar is shifted by minus its measured kick lag (no stretch), joined to its
neighbours with a 10 ms crossfade that ends before the downbeat, and looped to exactly
16 bars with the 20 ms wrap. Two lag estimates are run. "drift" is audition.py's
whole-bar kick-envelope correlation; "downbeat" correlates only the window around each
bar line, because the cover's kick pattern differs from the engine's and the downbeat
is the one hit they share. The hybrid is the engine's "above" solo plus the retimed
cover drums and other stems at the levels of the engine's own drums and keys; the synth
control is the full render. Both are mastered to -14 LUFS under -1 dBFS.

Writes retimed-cover-{mix,drums,other}.loop.wav and hybrid-spillway-16bar.wav for the
drift lags into <out>, the same for the downbeat lags into <out>/downbeat,
synth-spillway-16bar.wav, Opus 96 kbps encodes of the takes and metrics-hybrid.json.

    /home/andrew/Projects/music-video/.venv/bin/python retime_bed.py <audition dir> <engine dir> <out dir>
"""

import json
import shutil
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

from audition import HOP, MAX_LAG_S, SR, XFADE, bands, db, drift, key, kick_envelope, load, lufs, match, opus, seam, segment, shape, wrap

JOIN = int(0.010 * SR)
JOIN_LEAD = int(0.020 * SR)
STEMS = ("mix", "drums", "other")
LATE_MS = 30.0
DOWNBEAT_MS = (-60.0, 120.0)
DOWNBEAT_REACH_S = 0.060


def windowed_lags(ref, env, bar, bars, window_ms=None, reach_s=MAX_LAG_S):
    """Per-bar lag of env behind ref by envelope correlation over the bar (or a window around its
    line), plus the runner-up local peak as a fraction of the best: near 1 means the pick is a coin toss."""
    reach = int(reach_s * SR / HOP)
    lags, margins = [], []
    for b in range(bars):
        if window_ms is None:
            a0, a1 = round(b * bar / HOP), round((b + 1) * bar / HOP)
        else:
            a0 = max(round((b * bar + window_ms[0] / 1000 * SR) / HOP), 0)
            a1 = round((b * bar + window_ms[1] / 1000 * SR) / HOP)
        r = ref[a0:a1] - ref[a0:a1].mean()
        scores = np.full(2 * reach + 1, -np.inf)
        for i, lag in enumerate(range(-reach, reach + 1)):
            seg = env[max(a0 + lag, 0):a1 + lag]
            if a0 + lag >= 0 and len(seg) == len(r):
                scores[i] = float(np.dot(r, seg - seg.mean()))
        k = int(np.argmax(scores))
        frac = 0.0
        if 0 < k < len(scores) - 1 and np.isfinite(scores[k - 1]) and np.isfinite(scores[k + 1]):
            den = scores[k - 1] - 2 * scores[k] + scores[k + 1]
            frac = 0.5 * (scores[k - 1] - scores[k + 1]) / den if den else 0.0
        lags.append((k - reach + frac) * HOP / SR * 1000)
        peaks = [scores[j] for j in range(1, len(scores) - 1)
                 if scores[j] >= scores[j - 1] and scores[j] >= scores[j + 1] and abs(j - k) > 2]
        margins.append(round(max(peaks) / scores[k], 2) if peaks and scores[k] > 0 else 0.0)
    return np.array(lags), margins


def retime(y, shifts, bar, bars):
    """Bar b of the result reads the source from b * bar + shifts[b]; each join is a 10 ms
    equal-power fade that finishes 15 ms before the bar line, clear of the downbeat attack."""
    n = bar * bars
    t = np.linspace(0, np.pi / 2, JOIN)[:, None]
    fade_in, fade_out = np.sin(t), np.cos(t)
    edge = [0] + [b * bar - JOIN_LEAD - JOIN // 2 for b in range(1, bars)] + [n]
    out = np.zeros((n + XFADE, y.shape[1]))
    for b, s in enumerate(shifts):
        lo = edge[b]
        hi = edge[b + 1] + JOIN if b < bars - 1 else n + XFADE
        piece = segment(y, lo + s, hi - lo)
        if b:
            piece[:JOIN] *= fade_in
        if b < bars - 1:
            piece[-JOIN:] *= fade_out
        out[lo:hi] += piece
    return out[:n], out[n:]


def lag_summary(lags, margins=None):
    lags = np.asarray(lags)
    x = np.arange(len(lags))
    fit = np.polyfit(x, lags, 1)
    row = dict(lag_ms_per_bar=[round(float(v), 2) for v in lags],
               slope_ms_per_bar=round(float(fit[0]), 3),
               residual_rms_ms=round(float(np.sqrt(np.mean((lags - np.polyval(fit, x)) ** 2))), 2),
               rms_lag_ms=round(float(np.sqrt(np.mean(lags ** 2))), 2),
               median_lag_ms=round(float(np.median(lags)), 2),
               bars_over_30ms=[int(b) + 1 for b in np.flatnonzero(np.abs(lags) > LATE_MS)])
    if margins is not None:
        row["runner_up_peak_ratio"] = margins
    return row


def at_lufs(y, target):
    gain = target - lufs(y)
    return y * 10 ** (gain / 20), round(gain, 2)


def measure(y, bar):
    return dict(lufs=round(lufs(y), 2), bands=bands(y), **shape(y, bar), key=key(y)[1])


def take(y, path, bar):
    mastered, loud = match(y)
    sf.write(path, mastered, SR, subtype="PCM_16")
    row = dict(path=str(path), seconds=round(len(mastered) / SR, 4), master=loud, **measure(mastered, bar))
    if shutil.which("ffmpeg"):
        row["opus"] = str(opus(path))
    return row


def variant(cover, shifts, guide_env, kick_env, renders, out, bar, bars):
    out.mkdir(parents=True, exist_ok=True)
    loops, files = {}, {}
    for stem in STEMS:
        loops[stem] = wrap(*retime(cover[stem], shifts, bar, bars))
        mastered, loud = match(loops[stem])
        path = out / f"retimed-cover-{stem}.loop.wav"
        sf.write(path, mastered, SR, subtype="PCM_16")
        files[stem] = dict(path=str(path), seconds=round(len(mastered) / SR, 4), **loud, seam=seam(mastered))
    env = kick_envelope(loops["drums"])
    drums, drums_gain = at_lufs(loops["drums"], lufs(renders["drums"]))
    other, other_gain = at_lufs(loops["other"], lufs(renders["keys"]))
    flam_bar, flam_bar_m = windowed_lags(kick_env, env, bar, bars)
    flam_down, flam_down_m = windowed_lags(kick_env, env, bar, bars, DOWNBEAT_MS, DOWNBEAT_REACH_S)
    return dict(
        shift_samples=shifts,
        after_drift=lag_summary(*windowed_lags(guide_env, env, bar, bars)),
        after_downbeat=lag_summary(*windowed_lags(guide_env, env, bar, bars, DOWNBEAT_MS, DOWNBEAT_REACH_S)),
        placement=dict(drums_gain_db=drums_gain, other_gain_db=other_gain),
        flam_whole_bar=lag_summary(flam_bar, flam_bar_m),
        flam_downbeat=lag_summary(flam_down, flam_down_m),
        loops=files,
        hybrid=take(renders["above"] + drums + other, out / "hybrid-spillway-16bar.wav", bar))


def main():
    audition, engine_dir, out = (Path(p) for p in sys.argv[1:4])
    grid = json.loads((audition / "guide.json").read_text())
    engine = json.loads((engine_dir / "engine.json").read_text())
    bar, bars = grid["samples_per_bar"], grid["bars"]
    if engine["samples_per_bar"] != bar or engine["bars"] != bars:
        raise SystemExit(f"grid mismatch: guide {bar} x {bars}, engine {engine['samples_per_bar']} x {engine['bars']}")
    guide_drums = load(audition / "guide-spillway-16bar.drums.wav")
    cover = {"mix": load(audition / "cover-spillway-raw.wav"),
             **{s: load(audition / f"cover-spillway-raw.{s}.wav") for s in STEMS[1:]}}
    renders = {name: load(engine_dir / f"engine-{name}.wav") for name in ("full", "above", "keys", "drums", "kick")}
    guide_env, cover_env, kick_env = (kick_envelope(y) for y in (guide_drums, cover["drums"], renders["kick"]))

    reference = drift(guide_drums, cover["drums"], bar, bars)["lag_ms_per_bar"]
    by_bar, by_bar_m = windowed_lags(guide_env, cover_env, bar, bars)
    if np.abs(by_bar - np.array(reference)).max() > 0.05:
        raise SystemExit(f"windowed_lags disagrees with drift(): {by_bar} vs {reference}")
    by_down, by_down_m = windowed_lags(guide_env, cover_env, bar, bars, DOWNBEAT_MS, DOWNBEAT_REACH_S)
    raw_flam = windowed_lags(kick_env, cover_env, bar, bars, DOWNBEAT_MS, DOWNBEAT_REACH_S)

    variants = {
        "drift": variant(cover, [round(v / 1000 * SR) for v in by_bar], guide_env, kick_env, renders, out, bar, bars),
        "downbeat": variant(cover, [round(v / 1000 * SR) for v in by_down], guide_env, kick_env, renders, out / "downbeat", bar, bars),
    }
    synth = take(renders["full"], out / "synth-spillway-16bar.wav", bar)
    under = renders["full"] - renders["above"] - renders["keys"] - renders["drums"]
    control = windowed_lags(kick_env, kick_envelope(renders["drums"]), bar, bars, DOWNBEAT_MS, DOWNBEAT_REACH_S)[0]
    metrics = dict(
        grid=dict(samples_per_bar=bar, bars=bars, frames=bar * bars, sample_rate=SR, bpm=grid["bpm"]),
        lag_reference="guide-spillway-16bar.drums.wav (demucs drums of the pressure-0.6 guide), kick envelope",
        flam_reference="engine-kick.wav (pressure 0.9 kick solo), kick envelope",
        windows=dict(whole_bar_reach_ms=MAX_LAG_S * 1000, downbeat_window_ms=DOWNBEAT_MS,
                     downbeat_reach_ms=DOWNBEAT_REACH_S * 1000, join_ms=10, join_ends_before_bar_ms=15, wrap_ms=20),
        before=dict(drift=lag_summary(by_bar, by_bar_m), downbeat=lag_summary(by_down, by_down_m),
                    flam_downbeat_unretimed=lag_summary(*raw_flam)),
        variants=variants,
        synth=synth,
        engine=dict(pressure=engine["pressure"], layer_gains=engine["layer_gains"], solos=engine["solos"],
                    lufs_py={k: round(lufs(v), 2) for k, v in renders.items()},
                    solo_sum_residual_db_vs_full=round(db(np.sqrt(np.mean(under ** 2))) - db(np.sqrt(np.mean(renders["full"] ** 2))), 1),
                    control_flam_engine_drums_vs_kick=lag_summary(control)))
    (out / "metrics-hybrid.json").write_text(json.dumps(metrics, indent=1))
    for name, v in variants.items():
        print(name, "after", v["after_drift"]["lag_ms_per_bar"], v["after_downbeat"]["lag_ms_per_bar"])
    print("done", out / "metrics-hybrid.json")


if __name__ == "__main__":
    main()
