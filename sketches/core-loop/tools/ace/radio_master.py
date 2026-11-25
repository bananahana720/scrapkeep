#!/usr/bin/env python3
"""Mix and master drums/bass/other stems with a free local chain.

    radio_master.py drums.wav bass.wav other.wav out.wav [--drum-db X] [--stems-dir DIR]
        [--target-lufs -16] [--tp -1.5]

Run it with a Python that has pedalboard, pyloudnorm, scipy and soundfile (pedalboard is GPL:
an offline build tool, never shipped in the game). The radio's remake pass (radio_remake.py)
masters each candidate's htdemucs stems with it. --stems-dir also writes the processed stems at
the master's gain, so the pack step lands the same balance.

Chain: per-stem EQ (high-pass; 200-500 Hz mud cut only when the stem's measured share
exceeds its limit) -> per-stem bus compression -> sum -> gain to target LUFS -> limiter ->
true-peak trim (4x oversampled) -> 24-bit WAV. Prints LUFS, true peak, LRA, 200-500 Hz share
and stereo correlation of the master. Stack: pedalboard (EQ, compressor, limiter),
pyloudnorm (BS.1770 K-weighting), scipy (Welch, oversampling, filters), soundfile (I/O).
"""
import argparse
import sys

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from pedalboard import (Compressor, Gain, HighpassFilter, Limiter, LowpassFilter,
                        Pedalboard, PeakFilter)
from scipy import signal

MUD = (200.0, 500.0)
STEMS = {
    "drums": dict(hp=30, lp=None, mud_limit=0.10, comp=dict(threshold_db=-18, ratio=3.0, attack_ms=12, release_ms=120)),
    "bass": dict(hp=30, lp=6000, mud_limit=0.20, comp=dict(threshold_db=-20, ratio=3.0, attack_ms=25, release_ms=160)),
    "other": dict(hp=90, lp=None, mud_limit=0.30, comp=dict(threshold_db=-22, ratio=2.0, attack_ms=20, release_ms=220)),
}
MAX_MUD_CUT_DB = 4.0
MUD_CENTER_HZ = 320.0


def load(path):
    data, sr = sf.read(path, dtype="float32", always_2d=True)
    if data.shape[1] == 1:
        data = np.repeat(data, 2, axis=1)
    return data[:, :2], sr


def band_share(x, sr, lo, hi):
    """Share of total power (0..1) in lo..hi Hz of the mono sum."""
    mono = x.mean(axis=1)
    f, p = signal.welch(mono, fs=sr, nperseg=8192)
    total = p.sum()
    if total <= 0:
        return 0.0
    return float(p[(f >= lo) & (f < hi)].sum() / total)


def peak_filter_board(share, limit):
    """Peak cut sized by how far the stem is over its limit; empty when under it."""
    if share <= limit:
        return None, 0.0
    cut = min(MAX_MUD_CUT_DB, 10 * np.log10(share / limit) + 1.0)
    return PeakFilter(cutoff_frequency_hz=MUD_CENTER_HZ, gain_db=-float(cut), q=0.9), float(cut)


def process_stem(name, x, sr, extra_db=0.0):
    cfg = STEMS[name]
    before = band_share(x, sr, *MUD)
    plugins = [HighpassFilter(cutoff_frequency_hz=cfg["hp"])]
    if cfg["lp"]:
        plugins.append(LowpassFilter(cutoff_frequency_hz=cfg["lp"]))
    mud, cut = peak_filter_board(before, cfg["mud_limit"])
    if mud is not None:
        plugins.append(mud)
    plugins.append(Compressor(**cfg["comp"]))
    if extra_db:
        plugins.append(Gain(gain_db=extra_db))
    y = Pedalboard(plugins)(x.T.copy(), sr).T
    after = band_share(y, sr, *MUD)
    print(f"  {name:6s} 200-500 Hz share {before*100:5.1f}% (limit {cfg['mud_limit']*100:.0f}%) "
          f"-> cut {cut:.1f} dB at {MUD_CENTER_HZ:.0f} Hz -> {after*100:5.1f}%"
          f"{f'  gain {extra_db:+.1f} dB' if extra_db else ''}")
    return y


def mono_below(x, sr, hz=120.0):
    """Sum everything under hz to mono (zero-phase split, so the sum is exact)."""
    sos = signal.butter(4, hz, btype="low", fs=sr, output="sos")
    low = signal.sosfiltfilt(sos, x, axis=0)
    mid = low.mean(axis=1, keepdims=True)
    return (x - low) + mid


def true_peak_db(x, sr, oversample=4):
    up = signal.resample_poly(x, oversample, 1, axis=0)
    return 20 * np.log10(max(np.abs(up).max(), 1e-12))


def lra(x, sr):
    """EBU R128 loudness range from 3 s short-term blocks (1 s hop), gated at -70 / -20 LU."""
    meter = pyln.Meter(sr)
    y = np.array(x, dtype=np.float64)
    for _, filt in meter._filters.items():
        for ch in range(y.shape[1]):
            y[:, ch] = filt.apply_filter(y[:, ch])
    win, hop = int(3 * sr), int(1 * sr)
    vals = []
    for s in range(0, len(y) - win + 1, hop):
        z = np.mean(y[s:s + win] ** 2, axis=0)
        vals.append(-0.691 + 10 * np.log10(max(z.sum(), 1e-12)))
    vals = np.array(vals)
    vals = vals[vals > -70]
    if len(vals) < 2:
        return 0.0
    rel = -0.691 + 10 * np.log10(np.mean(10 ** ((vals + 0.691) / 10))) - 20
    vals = vals[vals > rel]
    return float(np.percentile(vals, 95) - np.percentile(vals, 10)) if len(vals) > 1 else 0.0


def report(label, x, sr):
    meter = pyln.Meter(sr)
    lufs = meter.integrated_loudness(x)
    tp = true_peak_db(x, sr)
    corr = float(np.corrcoef(x[:, 0], x[:, 1])[0, 1])
    sos = signal.butter(4, 120, btype="low", fs=sr, output="sos")
    low = signal.sosfiltfilt(sos, x, axis=0)
    low_corr = float(np.corrcoef(low[:, 0], low[:, 1])[0, 1])
    mid, side = (x[:, 0] + x[:, 1]) / 2, (x[:, 0] - x[:, 1]) / 2
    ms_db = 10 * np.log10(max(np.mean(side ** 2), 1e-12) / max(np.mean(mid ** 2), 1e-12))
    mono_lufs = meter.integrated_loudness(np.repeat(x.mean(axis=1, keepdims=True), 2, axis=1))
    print(f"{label}")
    print(f"  integrated loudness : {lufs:7.2f} LUFS")
    print(f"  true peak (4x)      : {tp:7.2f} dBTP")
    print(f"  loudness range      : {lra(x, sr):7.2f} LU")
    print(f"  200-500 Hz share    : {band_share(x, sr, *MUD)*100:7.2f} %")
    print(f"  stereo correlation  : {corr:7.3f}  (below 120 Hz: {low_corr:.3f})")
    print(f"  side/mid energy     : {ms_db:7.2f} dB   mono-fold loudness drop: {lufs - mono_lufs:.2f} LU")
    return lufs, tp


def main():
    ap = argparse.ArgumentParser()
    for n in ("drums", "bass", "other", "out"):
        ap.add_argument(n)
    ap.add_argument("--drum-db", type=float, default=0.0, help="extra gain on the drum bus")
    ap.add_argument("--target-lufs", type=float, default=-16.0)
    ap.add_argument("--tp", type=float, default=-1.5, help="true-peak ceiling in dBTP")
    ap.add_argument("--stems-dir", help="also write the processed stems here, at the master gain")
    a = ap.parse_args()

    stems, rates = {}, set()
    for n in ("drums", "bass", "other"):
        stems[n], sr = load(getattr(a, n))
        rates.add(sr)
    if len(rates) != 1:
        sys.exit(f"stems have different sample rates: {sorted(rates)}")
    n_samples = min(len(v) for v in stems.values())
    stems = {k: v[:n_samples] for k, v in stems.items()}

    print("stems (EQ and bus compression)")
    buses = {k: process_stem(k, v, sr, a.drum_db if k == "drums" else 0.0) for k, v in stems.items()}
    buses["bass"] = mono_below(buses["bass"], sr)
    buses["other"] = mono_below(buses["other"], sr)
    mix = sum(buses.values())

    dry = pyln.Meter(sr).integrated_loudness(mix)
    gain_db = a.target_lufs - dry
    meter = pyln.Meter(sr)
    start_gain = gain_db
    for _ in range(4):
        limiter = Pedalboard([Gain(gain_db=gain_db), Limiter(threshold_db=a.tp - 0.5, release_ms=120)])
        out = limiter(mix.T.copy(), sr).T
        tp = true_peak_db(out, sr)
        if tp > a.tp:
            out = out * 10 ** ((a.tp - tp - 0.05) / 20)
        err = a.target_lufs - meter.integrated_loudness(out)
        if abs(err) <= 0.1:
            break
        gain_db += err
    gain_db_used = gain_db
    sf.write(a.out, out, sr, subtype="PCM_24")
    if a.stems_dir:
        import os
        os.makedirs(a.stems_dir, exist_ok=True)
        stem_gain = gain_db_used + (meter.integrated_loudness(out) - meter.integrated_loudness(mix * 10 ** (gain_db_used / 20)))
        for k, v in buses.items():
            sf.write(os.path.join(a.stems_dir, f"{k}.wav"), v * 10 ** (stem_gain / 20), sr, subtype="PCM_24")

    print(f"\npre-limiter mix {dry:.2f} LUFS, gain {start_gain:+.2f} dB (closed-loop {gain_db_used:+.2f} dB), target {a.target_lufs} LUFS, ceiling {a.tp} dBTP\n")
    raw = sum(stems.values())
    report("unprocessed stem sum (reference)", raw, sr)
    print()
    report(f"master -> {a.out}", out, sr)


if __name__ == "__main__":
    main()
