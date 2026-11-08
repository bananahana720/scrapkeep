#!/usr/bin/env python3
"""Loudness read of an ace_bounce WAV: integrated LUFS (BS.1770-4), true peak, short-term
range, clipped share and per-state loudness when the bounce JSON carries a mix-state timeline.

    python3 -I tools/mix_meter.py <bounce.wav> [<bounce.wav> ...] [--json out.json]

Needs numpy, scipy and pyloudnorm (pip). Short-term windows are 3 s read with the BS.1770
gate (pyloudnorm), so a quiet window reads slightly high next to an ungated EBU meter.
The WAV's JSON sibling (same basename) is read when present for the `mix_states` timeline ([seconds, state] rows) and the cue counts.
"""
import json
import os
import sys

import numpy as np
import pyloudnorm
from scipy.io import wavfile
from scipy.signal import resample_poly


def _floats(data):
    if data.dtype.kind == "f":
        return data.astype(np.float64)
    bits = {np.dtype("int16"): 32768.0, np.dtype("int32"): 2147483648.0, np.dtype("uint8"): 128.0}[data.dtype]
    out = data.astype(np.float64)
    if data.dtype == np.uint8:
        out -= 128.0
    return out / bits


def _db(x):
    return float(20.0 * np.log10(max(x, 1e-12)))


def _lufs(meter, block):
    if block.shape[0] < meter.rate * 0.4:
        return None
    value = meter.integrated_loudness(block)
    return None if not np.isfinite(value) else round(float(value), 1)


def read(path):
    rate, data = wavfile.read(path)
    x = _floats(data)
    if x.ndim == 1:
        x = x[:, None]
    meter = pyloudnorm.Meter(rate)
    sidecar = os.path.splitext(path)[0] + ".json"
    info = {}
    if os.path.exists(sidecar):
        with open(sidecar) as f:
            info = json.load(f)
    over = resample_poly(x, 4, 1, axis=0)
    short = []
    step, win = rate, rate * 3
    for start in range(0, max(0, x.shape[0] - win) + 1, step):
        value = _lufs(meter, x[start:start + win])
        if value is not None:
            short.append(value)
    out = {
        "wav": os.path.basename(path),
        "seconds": round(x.shape[0] / rate, 1),
        "integrated_lufs": _lufs(meter, x),
        "true_peak_dbtp": round(_db(np.max(np.abs(over))), 2),
        "sample_peak_dbfs": round(_db(np.max(np.abs(x))), 2),
        "short_term_max_lufs": max(short) if short else None,
        "short_term_p95_lufs": round(float(np.percentile(short, 95)), 1) if short else None,
        "short_term_p10_lufs": round(float(np.percentile(short, 10)), 1) if short else None,
        "at_ceiling_share": round(float(np.mean(np.max(np.abs(x), axis=1) > 10 ** (-1.5 / 20.0))), 4),
    }
    states = info.get("mix_states", [])
    if states:
        per = {}
        ends = [row[0] for row in states[1:]] + [out["seconds"]]
        for (at, state), end in zip(states, ends):
            a, b = int(at * rate), int(end * rate)
            if b > a:
                per.setdefault(state, []).append(x[a:b])
        out["by_state"] = {s: {"seconds": round(sum(c.shape[0] for c in chunks) / rate, 1),
                               "lufs": _lufs(meter, np.concatenate(chunks))} for s, chunks in per.items()}
    if "cue_counts" in info:
        top = sorted(info["cue_counts"].items(), key=lambda kv: -kv[1])[:12]
        out["top_cues"] = top
        out["cues_total"] = sum(info["cue_counts"].values())
    for key in ("outcome", "stage", "policy", "music"):
        if key in info:
            out[key] = info[key]
    return out


def main(argv):
    target = None
    if "--json" in argv:
        i = argv.index("--json")
        target = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    rows = [read(p) for p in argv]
    text = json.dumps(rows, indent=2)
    print(text)
    if target:
        with open(target, "w") as f:
            f.write(text + "\n")


if __name__ == "__main__":
    main(sys.argv[1:])
