"""Is a calm take's late kick a swung groove? Diagnostic only; it changes no screen and picks nothing.

The calm parent's kick screen failed every take. Two readings compete: ACE merges the engine's
10/11 double kick into one late hit, or ACE plays a swung (shuffled) feel. This tool separates
them from the stored screen rows, then tests the caption's word "shuffled".

    PY=/home/andrew/Projects/music-video/.venv/bin/python
    $PY swing_check.py prep <slice>                     # caption-variant jobs under <slice>/diag-swing/calm
    (ACE-Step and Demucs through gpu_job.sh, as the sweep ran them)
    $PY bed_lock.py screen <slice>/guides/calm <slice>/diag-swing/calm
    $PY swing_check.py report <guides> <run> [<run> ...]   # -> <run>/swing.json and a table

kick   each found engine kick's stored error (screen.json kick_errors_ms), mapped back to its
       (bar, sixteenth) in engine_events order, split at the first bar with a third kick (the
       10/11 double). A merge shows only where 11 exists; a swing moves sixteenth 10 everywhere.
hats   the take's Demucs drums above 6 kHz: onsets folded into one beat, median offset per
       sixteenth slot (0 to 3), minus the parent's own straight guide through Demucs. Eighth-note
       swing moves slot 2 (the "and") late; a triplet feel also pulls slot 3 early (-29 ms at 172).
null   the kick screen's own matcher (strongest local peak within +-43 ms, same floor), centred on
       sixteenth 6 instead of each engine kick: no engine kick is within reach there. A screen that
       discriminates finds few hits at s6 (the control: 6 of 85); a take that finds as many hits
       there as on the grid has low-band onsets everywhere, so its kick number is not about lock.
"""

import json
import sys
from collections import defaultdict
from pathlib import Path

import librosa
import numpy as np
from scipy.signal import butter, sosfiltfilt

import bed_lock as bl
from audition import HOP, SR, kick_envelope, load
from slice0 import STRENGTH, captions

SEEDS = (7, 42, 1001)
# F with the one swing word removed, and F asking for the opposite. Everything else is verbatim.
VARIANTS = {
    'Fns': ('shuffled ghost-note hats', 'ghost-note hats'),
    'Fst': ('shuffled ghost-note hats', 'straight, unswung sixteenth-note hats'),
}


def prep(slice_dir):
    src = slice_dir / 'run' / 'calm'
    run = slice_dir / 'diag-swing' / 'calm'
    (run / 'inputs').mkdir(parents=True, exist_ok=True)
    (run / 'jobs').mkdir(parents=True, exist_ok=True)
    (run / 'inputs' / 'guide-full.wav').write_bytes((src / 'inputs' / 'guide-full.wav').read_bytes())
    base = json.loads((src / 'jobs' / 'calm-F-085-s7.json').read_text())
    text = captions()['calm-F']
    for tag, (old, new) in VARIANTS.items():
        if old not in text:
            raise SystemExit(f'calm-F caption no longer contains {old!r}')
        for seed in SEEDS:
            name = f'calm-{tag}-{round(STRENGTH * 100):03d}-s{seed}'
            job = json.loads(json.dumps(base['jobs'][0]))
            job.update(name=name, seeds=[seed])
            job['params']['caption'] = text.replace(old, new)
            (run / 'jobs' / f'{name}.json').write_text(json.dumps(dict(out_dir=f'../takes/{name}',
                                                                      defaults=base['defaults'], jobs=[job]), indent=1))
            print(name)


def kick_map(events, row, split):
    miss = set(row['missing_other']) | {f'{b}.0' for b in row['missing_downbeats']}
    errs = iter(row['kick_errors_ms'])
    cells = defaultdict(list)
    for b, s, _ in events:
        if f'{b + 1}.{s}' not in miss:
            cells[f"{'two' if b < split else 'three'}-kick bars s{s}"].append(next(errs))
    if next(errs, None) is not None:
        raise SystemExit(f"{row['take']}: stored errors do not match the engine events")
    return {k: dict(median_ms=round(float(np.median(v)), 1), n=len(v)) for k, v in sorted(cells.items())}


def hat_slots(drums, off, n, step):
    hi = sosfiltfilt(butter(4, 6000, 'high', fs=SR, output='sos'), drums.mean(axis=1))
    env = librosa.onset.onset_strength(y=hi.astype(np.float32), sr=SR, hop_length=HOP, n_fft=512)
    lo, top = max(off, 0) // HOP, (off + n) // HOP
    onsets = bl.strong_peaks(env, lo, top, .25 * float(np.quantile(env[lo:top], .99)), round(.035 * SR / HOP))
    dev = defaultdict(list)
    for i in onsets:
        p = (i * HOP - off) % (4 * step)
        k = int(round(p / step)) % 4
        d = p - k * step
        dev[k].append((d - 4 * step if d > 2 * step else d) / SR * 1000)
    return {k: (float(np.median(dev[k])), len(dev[k])) if dev[k] else (None, 0) for k in range(4)}


def matcher(c, off, events, step, target=None):
    """bed_lock.screen_take's kick match, optionally re-centred on one sixteenth: (median |ms|, found, multi-peak)."""
    floor = .3 * np.quantile(c, .995)
    reach = round(bl.THRESHOLDS['downbeat_window_ms'] / 1000 * SR / HOP)
    errors, multi = [], 0
    for _, s, t in events:
        centre = t + round(((target - s) * step if target is not None else 0) / HOP) + round(off / HOP)
        found = bl.local_peaks(c, centre - reach, centre + reach + 1, floor)
        if found:
            errors.append((max(found, key=lambda i: c[i]) - centre) * HOP / SR * 1000)
            multi += len(found) > 1
    return dict(median_abs_ms=round(float(np.median(np.abs(errors))), 1) if errors else None, found=len(errors),
                windows_with_2plus_peaks=multi)


def report(guides, runs):
    bar, n, step = bl.grid(guides)
    start, bars, _, _ = bl.region(guides)
    ref = bl.reference(guides, bar, step)
    per_bar = defaultdict(int)
    for b, _, _ in ref['events']:
        per_bar[b] += 1
    split = min((b for b, c in per_bar.items() if c > 2), default=bars)
    ctrl = load(guides / 'guide-full.drums.wav')[start:]
    lag = bl.drift(ref['kick'], ctrl, bar, bars)
    coff = round(float(np.median(lag['lag_ms_per_bar'])) / 1000 * SR)
    control = hat_slots(ctrl, coff, n, step)
    cenv = kick_envelope(ctrl)
    ctrl_kick = dict(on_grid=matcher(cenv, coff, ref['events'], step), null_s6=matcher(cenv, coff, ref['events'], step, 6))
    print('control kick matcher', ctrl_kick)
    print(f'sixteenth {step / SR * 1000:.1f} ms; three-kick bars from bar {split + 1}; control hats (abs ms):',
          {k: (round(v, 1), c) for k, (v, c) in control.items()})
    for run in runs:
        rows = json.loads((run / 'screen.json').read_text())['rows']
        out = []
        for r in rows:
            drums = load(Path(r['path']).with_suffix('.drums.wav'))[start:]
            hats = hat_slots(drums, r['trim_samples'], n, step)
            env = kick_envelope(drums)
            null = dict(on_grid=matcher(env, r['trim_samples'], ref['events'], step),
                        null_s6=matcher(env, r['trim_samples'], ref['events'], step, 6))
            rel = {f's{k}': dict(ms_vs_control=None if v is None else round(v - control[k][0], 1), n=c)
                   for k, (v, c) in hats.items()}
            kicks = kick_map(ref['events'], r, split)
            out.append(dict(take=r['take'], kick_median_abs_ms=r['kick_median_abs_ms'], fails=r['fails'],
                            kick_by_sixteenth=kicks, hats_by_slot=rel, kick_matcher=null))
            k = '  '.join(f"{c.split(' ')[0][:3]}/{c.split(' ')[-1]} {v['median_ms']:+.1f} n{v['n']}" for c, v in kicks.items())
            h = '  '.join(f"{s} {'-' if v['ms_vs_control'] is None else format(v['ms_vs_control'], '+.1f')} n{v['n']}"
                          for s, v in rel.items())
            g, z = null['on_grid'], null['null_s6']
            print(f"{r['take']:24s} kick {r['kick_median_abs_ms']:>6} | {k}\n{'':24s} hats | {h}\n"
                  f"{'':24s} null | grid {g['median_abs_ms']} ms n{g['found']}  s6 {z['median_abs_ms']} ms n{z['found']}")
        (run / 'swing.json').write_text(json.dumps(dict(split_bar=split + 1, control_hats_ms=control, control_kick_matcher=ctrl_kick, rows=out), indent=1))


if __name__ == '__main__':
    if len(sys.argv) >= 3 and sys.argv[1] == 'prep':
        prep(Path(sys.argv[2]))
    elif len(sys.argv) >= 4 and sys.argv[1] == 'report':
        report(Path(sys.argv[2]), [Path(p) for p in sys.argv[3:]])
    else:
        sys.exit(__doc__)
