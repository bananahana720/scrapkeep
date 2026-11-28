"""Cut each park stage's event stingers from that stage's own ACE music pack.

Run with the ACE-Step venv python in isolated mode:
  $HOME/.local/share/ACE-Step-1.5/.venv/bin/python -I tools/ace/cut_stingers.py \
      [--packs <dir holding <pack>/<clip>.{drums,bass,other}.ogg>] [--out assets/audio/stingers]

Stage -> pack -> park comes from src/core/park_defs.gd; the cues a stage needs come from that
park's music_cue rows. Each drop is a 1 to 2 beat downbeat hit from the pack's drop or open clip,
each riser is the last bar of its build or telegraph clip (it ends on a downbeat). Output WAVs are
44.1 kHz 16-bit mono at -16 LUFS (whole clip, ungated, BS.1770 K-weighting) and at most -1 dBTP.
A provenance manifest (source clip, bar, beat, measured loudness) is written beside them.
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import ndimage, signal

sys.path.insert(0, str(Path(__file__).resolve().parent))

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent.parent
DEFAULT_PACKS = Path.home() / "Projects/scrapkeep/sketches/core-loop/assets/music_ace"
RATE = 44100
TARGET_LUFS = -16.0
CEILING_DBTP = -1.0
STEMS = ("drums", "bass", "other")

DROPS = {
    "drop_flood": {"w": (1.0, 1.0, 1.0), "clips": ("drop",), "beats": 2, "fade": 0.09, "rank": {"low": 1.0, "level": 1.0}},
    "drop_natural": {"w": (1.0, 0.8, 1.2), "clips": ("drop",), "beats": 2, "fade": 0.09, "rank": {"level": 1.0, "onset": 0.8}},
    "drop_flash_flood": {"w": (1.2, 0.7, 1.0), "clips": ("drop", "open"), "beats": 2, "fade": 0.07, "rank": {"onset": 1.0, "bright": 0.8}},
    "stinger_lightning": {"w": (1.0, 0.3, 1.2), "clips": ("drop", "open"), "beats": 1, "fade": 0.06, "rank": {"bright": 1.2, "onset": 1.0}},
    "drop_lightning": {"w": (0.8, 0.4, 1.2), "clips": ("drop", "open"), "beats": 1, "fade": 0.06, "rank": {"bright": 1.0, "level": 0.8}},
    "drop_collapse": {"w": (1.0, 1.2, 0.6), "clips": ("drop", "open"), "beats": 2, "fade": 0.12, "rank": {"low": 1.2, "onset": -0.5}},
    "drop_cave_in": {"w": (1.0, 1.5, 0.3), "clips": ("drop", "open"), "beats": 2, "fade": 0.12, "lowpass": 1400.0, "rank": {"low": 1.5, "level": 0.5}},
    "drop_drain": {"w": (0.6, 1.0, 1.0), "clips": ("open",), "beats": 2, "fade": 0.30, "lowpass": 2800.0, "rank": {"level": -1.0, "onset": -1.0}},
    "drop_impact": {"w": (1.0, 1.0, 0.5), "clips": ("drop", "open"), "beats": 1, "fade": 0.06, "rank": {"onset": 1.2, "low": 1.0}},
    "drop_fleet": {"w": (1.5, 0.5, 1.0), "clips": ("drop", "open"), "beats": 2, "fade": 0.08, "rank": {"onset": 1.0, "level": 0.8}},
    "drop_fleet_anvil": {"w": (1.2, 1.0, 0.4), "clips": ("drop", "open"), "beats": 2, "fade": 0.09, "rank": {"low": 1.0, "onset": 1.0}},
    "drop_ancient": {"w": (0.4, 1.3, 1.0), "clips": ("drop", "open"), "beats": 2, "fade": 0.14, "lowpass": 4000.0, "rank": {"low": 1.2, "onset": -0.6}},
    "drop_mind_wrong": {"w": (0.3, 0.5, 1.5), "clips": ("drop", "open"), "beats": 2, "fade": 0.10, "rank": {"bright": 1.2, "onset": 0.4}},
    "drop_industrial": {"w": (1.5, 0.8, 0.5), "clips": ("drop", "open"), "beats": 2, "fade": 0.08, "rank": {"onset": 1.0, "bright": 0.8}},
    "drop_boiler": {"w": (1.2, 1.0, 0.8), "clips": ("drop", "open"), "beats": 2, "fade": 0.10, "rank": {"level": 1.0, "low": 0.8}},
}
RISERS = {
    "riser_natural": {"w": (1.0, 1.0, 1.0), "clip": "telegraph"},
    "riser_fleet": {"w": (1.5, 0.3, 1.0), "clip": "build"},
    "riser_ancient": {"w": (0.3, 1.4, 1.0), "clip": "build", "lowpass": 3500.0},
    "riser_industrial": {"w": (1.4, 0.7, 0.8), "clip": "telegraph", "highpass": 120.0},
    "riser_mind_quote": {"w": (0.2, 0.6, 1.6), "clip": "build"},
}
RISE_START_DB = -9.0
FADE_IN = 0.003
RISER_FADE_OUT = 0.008


def stage_rows():
    """[(zone id, ace pack, park map)] read from park_defs.gd, in stage order."""
    text = (PROJECT / "src/core/park_defs.gd").read_text()
    rows = []
    seen = {}
    pattern = r'\{"stage": (\d+), "world": (\d+), "music": \{"theme": \d+, "ace": "(\w+)"\}.*?"map": "(\w+)"'
    for stage, world, ace, park in re.findall(pattern, text):
        local = seen.get(world, 0) + 1
        seen[world] = local
        rows.append((f"{world}-{local}", ace, park))
    return rows


def park_cues(park):
    """(set of drop cue ids, set of riser cue ids) the park's events name."""
    data = json.loads((PROJECT / f"src/world/park/{park}.json").read_text())
    drops, risers = set(), set()
    for event in data["event_rows"]:
        cue = event.get("music_cue")
        if cue:
            risers.add(cue["telegraph"])
            drops.add(cue["land"])
    return drops, risers


def read_clip(pack_dir, manifest, clip):
    """The pack clip's three stems as mono arrays trimmed to start at the clip's entry."""
    meta = manifest["clips"][clip]
    stems = {}
    for stem in STEMS:
        data, rate = sf.read(pack_dir / meta["files"][stem], dtype="float64", always_2d=True)
        if rate != RATE:
            raise SystemExit(f"{pack_dir.name}/{clip}.{stem}: rate {rate} != {RATE}")
        stems[stem] = data.mean(axis=1)
    return meta, stems


def mix(stems, weights, lo, hi, lowpass=None, highpass=None):
    out = sum(w * stems[s][lo:hi] for s, w in zip(STEMS, weights))
    if highpass:
        out = signal.sosfilt(signal.butter(2, highpass, "hp", fs=RATE, output="sos"), out)
    if lowpass:
        out = signal.sosfilt(signal.butter(2, lowpass, "lp", fs=RATE, output="sos"), out)
    return out


def features(window):
    n = len(window)
    spec = np.abs(np.fft.rfft(window * np.hanning(n))) ** 2
    freqs = np.fft.rfftfreq(n, 1.0 / RATE)
    total = spec.sum() + 1e-18
    attack = window[: int(0.03 * RATE)]
    rms = float(np.sqrt(np.mean(window**2)) + 1e-12)
    return {
        "low": float(spec[freqs < 150].sum() / total),
        "bright": float((spec * freqs).sum() / total),
        "onset": float(np.max(np.abs(attack)) / rms),
        "level": float(20 * np.log10(rms)),
    }


def k_weight(x):
    """BS.1770 K-weighting (high shelf then RLB high-pass) at 44.1 kHz."""
    def shelf(f0, gain, q):
        a = 10 ** (gain / 40)
        w0 = 2 * np.pi * f0 / RATE
        al = np.sin(w0) / (2 * q)
        c = np.cos(w0)
        sq = 2 * np.sqrt(a) * al
        b = [a * ((a + 1) + (a - 1) * c + sq), -2 * a * ((a - 1) + (a + 1) * c), a * ((a + 1) + (a - 1) * c - sq)]
        d = [(a + 1) - (a - 1) * c + sq, 2 * ((a - 1) - (a + 1) * c), (a + 1) - (a - 1) * c - sq]
        return np.array(b) / d[0], np.array(d) / d[0]

    def highpass(f0, q):
        w0 = 2 * np.pi * f0 / RATE
        al = np.sin(w0) / (2 * q)
        c = np.cos(w0)
        b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
        d = [1 + al, -2 * c, 1 - al]
        return np.array(b) / d[0], np.array(d) / d[0]

    b1, a1 = shelf(1681.974450955533, 3.999843853973347, 0.7071752369554196)
    b2, a2 = highpass(38.13547087602444, 0.5003270373238773)
    return signal.lfilter(b2, a2, signal.lfilter(b1, a1, x))


def lufs(x):
    return -0.691 + 10 * np.log10(np.mean(k_weight(x) ** 2) + 1e-18)


def true_peak_db(x):
    over = signal.resample_poly(x, 4, 1)
    return 20 * np.log10(np.max(np.abs(over)) + 1e-18)


def finish(x, fade_out, fade_in=FADE_IN):
    x = x.copy()
    fi = int(fade_in * RATE)
    fo = int(fade_out * RATE)
    x[:fi] *= np.linspace(0.0, 1.0, fi, endpoint=False)
    x[-fo:] *= np.cos(np.linspace(0.0, np.pi / 2, fo)) ** 2
    return x


def level(x):
    """Drive a tanh soft clip until the clip reads TARGET_LUFS, then trim to the true-peak ceiling.

    A transient-heavy hit cannot reach -16 LUFS under -1 dBTP by gain alone; the soft clip
    rounds its peaks instead of letting them set the level. Drive is capped at 15 dB.
    """
    ceil = 10 ** (CEILING_DBTP / 20)

    def render(g):
        y = ceil * np.tanh(g * x / ceil)
        tp = true_peak_db(y)
        if tp > CEILING_DBTP:
            y = y * 10 ** ((CEILING_DBTP - tp) / 20)
        return y

    g0 = 10 ** ((TARGET_LUFS - lufs(x)) / 20)
    lo, hi = g0, g0 * 10 ** (15 / 20)
    if lufs(render(lo)) >= TARGET_LUFS - 0.05:
        return render(lo)
    for _ in range(30):
        mid = (lo * hi) ** 0.5
        if lufs(render(mid)) < TARGET_LUFS:
            lo = mid
        else:
            hi = mid
    return render(hi)


def write_wav(path, x):
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(path, np.clip(x, -1.0, 1.0), RATE, subtype="PCM_16", format="WAV")


TAKEN = {}


def cut_stage(zone, pack, park, packs_dir, out_dir):
    drops, risers = park_cues(park)
    import highdraft_stingers
    if zone.split("-")[0] == highdraft_stingers.WORLD:
        skip = set(highdraft_stingers.DESIGNED) | set(highdraft_stingers.UNCUT)
        drops, risers = drops - skip, risers - skip
    import spillway_stingers
    designed = set(spillway_stingers.BY_ZONE.get(zone.replace("-", "_"), ()))
    drops, risers = drops - designed, risers - designed
    pack_dir = packs_dir / pack
    manifest = json.loads((pack_dir / "manifest.json").read_text())
    clips = {}
    for clip in ("build", "telegraph", "open", "drop"):
        clips[clip] = read_clip(pack_dir, manifest, clip)
    report = {}
    zdir = out_dir / zone.replace("-", "_")

    for cue in sorted(risers):
        spec = RISERS[cue]
        meta, stems = clips[spec["clip"]]
        bar = meta["bar"]
        end = meta["entry"] + meta["bars"] * bar
        lo = end - bar
        x = mix(stems, spec["w"], lo, end, spec.get("lowpass"), spec.get("highpass"))
        ramp = 10 ** (np.linspace(RISE_START_DB, 0.0, len(x)) / 20)
        x = finish(x * ramp, RISER_FADE_OUT)
        x = level(x)
        write_wav(zdir / f"{cue}.wav", x)
        report[cue] = {"kind": "riser", "clip": spec["clip"], "bar": meta["bars"], "beat": 1, "samples": len(x),
                       "lufs": round(lufs(x), 2), "dbtp": round(true_peak_db(x), 2)}

    cands = []
    for clip in ("drop", "open"):
        meta, stems = clips[clip]
        for bar_i in range(meta["bars"]):
            for beat_i in (0, 2):
                start = meta["entry"] + bar_i * meta["bar"] + beat_i * meta["beat"]
                full = mix(stems, (1.0, 1.0, 1.0), start, start + 2 * meta["beat"])
                if len(full) < 2 * meta["beat"]:
                    continue
                cands.append({"clip": clip, "bar": bar_i + 1, "beat": beat_i + 1, "start": start, "f": features(full)})
    keys = ("low", "bright", "onset", "level")
    stat = {k: (np.mean([c["f"][k] for c in cands]), np.std([c["f"][k] for c in cands]) + 1e-9) for k in keys}
    used = set()
    for cue in sorted(drops):
        spec = DROPS[cue]
        ranked = sorted((c for c in cands if (c["clip"], c["bar"], c["beat"]) not in used and c["clip"] in spec["clips"]),
                        key=lambda c: -sum(w * (c["f"][k] - stat[k][0]) / stat[k][1] for k, w in spec["rank"].items()))
        for best in ranked:
            meta, stems = clips[best["clip"]]
            n = spec["beats"] * meta["beat"]
            x = mix(stems, spec["w"], best["start"], best["start"] + n, spec.get("lowpass"))
            print_ = hashlib.sha256(np.round(x, 4).tobytes()).hexdigest()
            if print_ not in TAKEN.setdefault(cue, set()):
                TAKEN[cue].add(print_)
                break
        used.add((best["clip"], best["bar"], best["beat"]))
        x = level(finish(x, spec["fade"]))
        write_wav(zdir / f"{cue}.wav", x)
        report[cue] = {"kind": "drop", "clip": best["clip"], "bar": best["bar"], "beat": best["beat"],
                       "beats": spec["beats"], "samples": len(x),
                       "lufs": round(lufs(x), 2), "dbtp": round(true_peak_db(x), 2)}
    return {"pack": pack, "park": park, "cues": report}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--packs", type=Path, default=DEFAULT_PACKS)
    ap.add_argument("--out", type=Path, default=PROJECT / "assets/audio/stingers")
    args = ap.parse_args()
    summary = {}
    for zone, pack, park in stage_rows():
        summary[zone.replace("-", "_")] = cut_stage(zone, pack, park, args.packs, args.out)
    import highdraft_stingers
    for zone, rows in highdraft_stingers.design(args.out).items():
        summary[zone]["cues"].update(rows)
    import spillway_stingers
    for zone, rows in spillway_stingers.design(args.out).items():
        summary[zone]["cues"].update(rows)
    (args.out).mkdir(parents=True, exist_ok=True)
    (args.out / "manifest.json").write_text(json.dumps(summary, indent=1, sort_keys=True) + "\n")
    hashes = {}
    for wav in sorted(args.out.glob("*/*.wav")):
        hashes[str(wav.relative_to(args.out))] = hashlib.sha256(wav.read_bytes()).hexdigest()
    dupes = len(hashes) - len(set(hashes.values()))
    print(f"{len(hashes)} stingers, {dupes} byte-identical duplicates")
    for zone, row in summary.items():
        for cue, r in row["cues"].items():
            where = f"{r['clip']} bar{r['bar']} beat{r['beat']}" if "clip" in r else "designed"
            print(zone, cue, r["kind"], where, r["samples"], r["lufs"], r["dbtp"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
