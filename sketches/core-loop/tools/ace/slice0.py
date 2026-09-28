"""Slice 0 (ACE-MUSIC-REVIEW §2): two engine parents performed whole by ACE-Step, cut to a
scripted Spillway state timeline, blind-packed. Screens reject; Andrew's blind listen decides.

    PY=/home/andrew/Projects/music-video/.venv/bin/python
    godot ... ace_guide_v3.gd -- --parent=calm|warden --engine=<AU1 engine> --out=<slice>/guides/<parent>
    $PY slice0.py prep <slice>                 # ACE inputs + pilot/sweep job files per parent, from CAPTIONS.md
    (ACE-Step and Demucs run through gpu_job.sh, one job at a time)
    $PY bed_lock.py screen <slice>/guides/<parent> <slice>/run/<parent>
    $PY slice0.py timeline <slice>             # the scripted state timeline -> timeline.json
    $PY slice0.py assemble <slice>             # one master per surviving direction, plus the planted weak take
    $PY slice0.py pack <slice> <pack dir>      # Y1.. in random order, key in .key-do-not-peek

A candidate is a direction whose calm and Warden parents both survived their screens; it is
assembled only from its own two takes. With fewer than two such directions, cross-direction
pairs of survivors (calm X+Warden Y) fill the pack up to six. The planted weak take is assembled the same way from
the takes with the most screen failures, fixed here before screening: per parent, most
fails, then the loosest kick median; the sweep first, a pilot take only if no sweep take failed.
"""

import hashlib
import json
import random
import re
import shutil
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

from audition import SR, db, load, lufs
from bed_lock import master

HERE = Path(__file__).resolve().parent
PARENTS = ('calm', 'warden')
DIRECTIONS = ('F', 'X1', 'X2')
STRENGTH = 0.85
SEEDS = (7, 42, 1001)
PILOT_SEED = 172
JOIN = round(0.010 * SR)
# (state, what the game is doing, parent, section, first bar of the section, bars). The Warden
# cycles tighten: a full build, then its second half, then its last phrase. The break is the
# held breath once more as the trough before home (the sinister Eb break is Slice 1 content).
TIMELINE = [
    ('calm', 'shelf, closed Warden, pressure low', 'calm', 'calm', 1, 16),
    ('travel', 'shelf, pressure up, class motif seeded', 'calm', 'travel', 1, 15),
    ('pivot', 'the lip: drop-line commit', 'warden', 'pivot', 1, 1),
    ('warden-1:build', 'bank and lift, first lap', 'warden', 'build', 1, 16),
    ('warden-1:telegraph', 'in the air, telegraph', 'warden', 'telegraph', 1, 4),
    ('warden-1:open', 'window open, the held breath', 'warden', 'open', 1, 4),
    ('warden-1:drop', 'landed on the core', 'warden', 'drop', 1, 4),
    ('warden-2:build', 'bank and lift, second lap', 'warden', 'build', 9, 8),
    ('warden-2:telegraph', 'in the air, telegraph', 'warden', 'telegraph', 1, 4),
    ('warden-2:open', 'window open, the held breath', 'warden', 'open', 1, 4),
    ('warden-2:drop', 'landed on the core', 'warden', 'drop', 1, 4),
    ('warden-3:build', 'bank and lift, third lap', 'warden', 'build', 13, 4),
    ('warden-3:telegraph', 'in the air, telegraph', 'warden', 'telegraph', 1, 4),
    ('warden-3:open', 'window open, the held breath', 'warden', 'open', 1, 4),
    ('warden-3:drop', 'landed on the core, the unseal', 'warden', 'drop', 1, 4),
    ('break', 'the Warden breaks: breath before home', 'warden', 'open', 1, 4),
    ('return', 'kill cadence, A7b9 then D', 'warden', 'cadence', 1, 2),
    ('home', 'back on the shelf at 172', 'calm', 'calm', 1, 8),
    ('fade', 'end of the listen', 'calm', 'calm', 9, 1),
]


def captions():
    text = (HERE / 'CAPTIONS.md').read_text()
    found = dict(re.findall(r'```caption (\S+)\n(.+?)\n```', text, re.S))
    missing = [f'{p}-{d}' for p in PARENTS for d in DIRECTIONS if f'{p}-{d}' not in found]
    if missing:
        raise SystemExit(f'CAPTIONS.md has no caption for {missing}')
    return found


def name(parent, direction, seed, pilot=False):
    return f"{'pilot-' if pilot else ''}{parent}-{direction}-{round(STRENGTH * 100):03d}-s{seed}"


def prep(slice_dir):
    text = captions()
    for parent in PARENTS:
        guides, run = slice_dir / 'guides' / parent, slice_dir / 'run' / parent
        (run / 'inputs').mkdir(parents=True, exist_ok=True)
        (run / 'jobs').mkdir(parents=True, exist_ok=True)
        info = json.loads((guides / 'guide.json').read_text())
        y = load(guides / 'guide-full.wav')
        # Gain only, no limiting: the transients are what the cover must lock to.
        gain = min(-14 - lufs(y), -1 - db(np.abs(y).max()))
        sf.write(run / 'inputs' / 'guide-full.wav', y * 10 ** (gain / 20), SR, subtype='PCM_16')
        defaults = dict(lyrics='[Instrumental]', instrumental=True, bpm=info['bpm'], keyscale='D minor',
                        timesignature='4', vocal_language='en', duration=round(info['total_frames'] / SR, 3))

        def job(direction, seed, pilot=False):
            return dict(name=name(parent, direction, seed, pilot), model='acestep-v15-xl-turbo', seeds=[seed],
                        params=dict(task_type='cover', audio_cover_strength=STRENGTH, thinking=False,
                                    src_audio='path:../inputs/guide-full.wav', caption=text[f'{parent}-{direction}'],
                                    inference_steps=8, shift=3.0))
        # One take per job file and per ACE process: after a process's first job the DiT stays
        # resident (9.5 GB), and a source over 30 s then needs a two-chunk VAE encode that does
        # not fit under the VRAM cap (the Warden pilot OOMed as a second job; pack 2's 23 s
        # guides encoded in one chunk).
        (run / 'jobs' / 'pilot.json').write_text(json.dumps(dict(out_dir='../takes/pilot', defaults=defaults,
                                                                 jobs=[job('F', PILOT_SEED, True)]), indent=1))
        for d in DIRECTIONS:
            for s in SEEDS:
                one = job(d, s)
                (run / 'jobs' / f"{one['name']}.json").write_text(json.dumps(dict(out_dir=f"../takes/{one['name']}",
                                                                                 defaults=defaults, jobs=[one]), indent=1))
        (run / 'prep.json').write_text(json.dumps(dict(input_gain_db=round(gain, 2), strength=STRENGTH, seeds=SEEDS,
                                                       pilot_seed=PILOT_SEED, captions={d: text[f'{parent}-{d}'] for d in DIRECTIONS}), indent=1))
        print(parent, 'input gain', round(gain, 2), 'dB,', defaults['duration'], 's at', info['bpm'])


def sections(slice_dir, parent):
    info = json.loads((slice_dir / 'guides' / parent / 'guide.json').read_text())
    return {n: (start, bars, bar_len) for n, start, bars, bar_len in info['sections']}


def timeline(slice_dir):
    maps = {p: sections(slice_dir, p) for p in PARENTS}
    at, rows = 0, []
    for state, game, parent, section, first, bars in TIMELINE:
        start, length, bar_len = maps[parent][section]
        if first - 1 + bars > length:
            raise SystemExit(f'{state}: bars {first}..{first + bars - 1} run past {parent}/{section} ({length} bars)')
        frames = bars * bar_len
        rows.append(dict(state=state, game=game, parent=parent, section=section, bars=f'{first}-{first + bars - 1}',
                         source_start=start + (first - 1) * bar_len, frames=frames, bpm=round(4 * 60 * SR / bar_len, 2),
                         out_start=at, out_seconds=round(at / SR, 3)))
        at += frames
    out = dict(theme='spillway', key='D', join_ms=10, join='equal power, ending on the bar line', final_bar='equal-power fade',
               total_frames=at, total_seconds=round(at / SR, 2), states=rows)
    (slice_dir / 'timeline.json').write_text(json.dumps(out, indent=1))
    print('timeline', len(rows), 'states,', out['total_seconds'], 's ->', slice_dir / 'timeline.json')
    return out


def build(plan, sources):
    """Cut each state from its parent's take (guide position + the take's trim) and join them.
    Each join is a 10 ms equal-power crossfade that ends on the bar line, so the incoming
    downbeat lands at full level; the last bar fades out."""
    total = plan['total_frames']
    out = np.zeros((total + JOIN, 2))
    theta = np.linspace(0, np.pi / 2, JOIN)[:, None]
    states = plan['states']
    for i, s in enumerate(states):
        y, trim = sources[s['parent']]
        first = s['source_start'] + trim
        pre = JOIN if i else 0
        seg = np.zeros((pre + s['frames'], 2))
        lo = first - pre
        take = y[max(lo, 0):first + s['frames']]
        seg[max(-lo, 0):max(-lo, 0) + len(take)] = take
        if i:
            seg[:JOIN] *= np.sin(theta)
        if i < len(states) - 1:
            seg[-JOIN:] *= np.cos(theta)
        else:
            seg[pre:] *= np.cos(np.linspace(0, np.pi / 2, s['frames']))[:, None]
        start = s['out_start'] - pre
        out[start:start + len(seg)] += seg
    return out[:total]


def screened(slice_dir):
    return {p: json.loads((slice_dir / 'run' / p / 'screen.json').read_text()) for p in PARENTS}


def planted(reports):
    """Per parent, the failed take with the most failures, then the loosest kick (sweep before pilot)."""
    picks = {}
    for parent, report in reports.items():
        failed = [r for r in report['rows'] if r['fails']]
        pool = [r for r in failed if not r['guide'].startswith('pilot')] or failed
        if not pool:
            return None
        pool.sort(key=lambda r: (-len(r['fails']), -(r['kick_median_abs_ms'] or 1e9)))
        picks[parent] = pool[0]
    return picks


def assemble(slice_dir):
    plan = timeline(slice_dir)
    reports = screened(slice_dir)
    rows = {p: {r['take']: r for r in reports[p]['rows']} for p in PARENTS}
    survivors = {p: {rows[p][t]['guide'].split('-', 1)[1]: rows[p][t] for t in reports[p]['finish']} for p in PARENTS}
    print('survivors', {p: {d: r['take'] for d, r in s.items()} for p, s in survivors.items()})
    chosen = {d: {p: survivors[p][d] for p in PARENTS} for d in DIRECTIONS if all(d in survivors[p] for p in PARENTS)}
    if len(chosen) < 2:
        # Too few same-direction pairs for a comparative listen: cross the survivors, up to six.
        for dc in DIRECTIONS:
            for dw in DIRECTIONS:
                if dc != dw and dc in survivors['calm'] and dw in survivors['warden'] and len(chosen) < 6:
                    chosen[f'{dc}+{dw}'] = {'calm': survivors['calm'][dc], 'warden': survivors['warden'][dw]}
    weak = planted(reports)
    if weak:
        chosen['planted-weak'] = weak
    else:
        print('no failed take to plant')
    done = {}
    for label, pair in chosen.items():
        dest = slice_dir / 'assembled' / label
        dest.mkdir(parents=True, exist_ok=True)
        sources = {p: (load(Path(r['path'])), r['trim_samples']) for p, r in pair.items()}
        mastered, loud = master(build(plan, sources), dest / f'{label}.wav')
        done[label] = dict(takes={p: dict(take=r['take'], path=r['path'], sha256=r['sha256'], trim_samples=r['trim_samples'],
                                          fails=r['fails']) for p, r in pair.items()},
                           wav=str(dest / f'{label}.wav'), seconds=round(len(mastered) / SR, 2), master=loud)
        print(label, {p: r['take'] for p, r in pair.items()}, done[label]['seconds'], 's', loud['lufs_after'], 'LUFS',
              loud['true_peak_dbtp'], 'dBTP', flush=True)
    (slice_dir / 'assembled' / 'assemble.json').write_text(json.dumps(done, indent=1))


def pack(slice_dir, dest):
    done = json.loads((slice_dir / 'assembled' / 'assemble.json').read_text())
    items = [(label, Path(entry['wav'])) for label, entry in done.items()]
    random.SystemRandom().shuffle(items)
    dest.mkdir(parents=True, exist_ok=True)
    key_lines, manifest = [], {}
    for i, (label, src) in enumerate(items, 1):
        target = dest / f'Y{i}.wav'
        shutil.copyfile(src, target)
        key_lines.append(f'Y{i}={label}')
        manifest[target.name] = dict(sha256=hashlib.sha256(target.read_bytes()).hexdigest(), source=str(src))
    (dest / '.key-do-not-peek').write_text('\n'.join(key_lines) + '\n')
    (slice_dir / 'pack-manifest.json').write_text(json.dumps(dict(dest=str(dest), files=manifest), indent=1))
    print('packed', len(items), 'files to', dest)


if __name__ == '__main__':
    cmd, args = sys.argv[1], [Path(a) for a in sys.argv[2:]]
    if cmd == 'prep':
        prep(*args)
    elif cmd == 'timeline':
        timeline(*args)
    elif cmd == 'assemble':
        assemble(*args)
    elif cmd == 'pack':
        pack(*args)
    else:
        sys.exit(__doc__)
