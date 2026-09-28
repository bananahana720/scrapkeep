"""Pack 3 (Slice 0, round 2): full-ACE takes through gates that prove themselves, the Warden arc
made by runtime stem automation, and blind pack 3. ACE performs; the runtime owns the dynamics;
Andrew's ear decides.

    PY=/home/andrew/Projects/music-video/.venv/bin/python
    $PY pack3.py prep <slice>            # round-2 job files and the vocal negative-control mixes
    (one ACE process per take, then one Demucs pass: flock /tmp/scrapkeep-gpu.lock gpu_job.sh ...)
    $PY pack3.py controls <slice>        # every gate on its positive and negative control
    $PY pack3.py screen <slice>          # round 1 and round 2 takes through the counted gates
    $PY pack3.py assemble <slice>        # chosen takes -> timeline assemblies, stem automation, arc measured
    $PY pack3.py pack <slice> <dest>     # Y1.. shuffled, WAV and Opus, .key.json, README.txt

Everything lands in <slice>/round2 except the pack.

Gates (coordinator ruling, 2026-09-28). The engine-kick conformity gate is retired for full-ACE
takes: drums and bass come from one performance, and the gate failed its null control. The
Warden breath gate is gone too, because the runtime makes the held breath. What remains:
  tempo     audio.drift() slope, |drift| <= 12 ms per 16 bars
  downbeat  a take kick within +-43 ms of every engine kick downbeat, after the global trim
  dorian    D Dorian chroma energy >= the guide's own minus 0.05
  chords    per-bar chroma follows the guide better than the guide's own next-bar baseline
  density   mean significant bands <= B's mean and the 90th-percentile bar <= B's busiest bar
  lag       the take's own bass-to-kick envelope lag, |median| <= 12 ms
  vocals    Demucs vocals stem <= -45 dB RMS (pack 2's a-080-s1001 read -43.3)
  seam      the 16-bar loop: the join step no larger than the loop's own 99.9th-percentile step,
            and the loop head's kick envelope within 12 ms of the take's own continuation
A gate counts for a parent only when the parent's guide through Demucs passes it (positive) and
its negative control fails it. Otherwise it is reported and never gates. Negatives are built
from the same guide-through-Demucs inputs:
  tempo     resampled 0.2% slow                      (off-grid tempo)
  downbeat  every stem one eighth late               (off-grid)
  dorian    up a semitone by resampling              (off the pitch grid)
  chords    bars shuffled by a fixed derangement     (shuffled)
  density   the 12-layer render Andrew rejected      (no off-grid or shuffled copy changes a band count)
  lag       the bass 40 ms late                      (off-grid)
  vocals    a real sung vocal 24 dB under the guide, through Demucs
  seam      the loop cut one sixteenth long          (off-grid)

Selection, fixed before round 2 was rendered or screened. A survivor passes every counted gate;
pilot takes and the Fns diagnostic caption are never selected. The best of a pool has the lowest
|tempo drift|, then the lowest vocal residue. Calm takes are straight (the caption asks for
straight, unswung sixteenth-note hats) or swung (round 1's captions). Per direction, in F, X1, X2
order, the best straight calm survivor makes one assembly; then the best swung calm survivor over
all directions makes one more. So the pack holds at most one straight version per direction, one
swung version in all and four candidates. Each assembly takes its own direction's best Warden
survivor (0.85 and 0.95 pooled), or, when that direction has none, the best Warden survivor of
any direction, labelled as a cross pair in the key. The planted weak take is round 1's diagnostic
F master: raw ACE dynamics (the kick plays through the breath) on a Warden take that failed
downbeats.

The Warden arc. One continuous Warden performance, cut to timeline.json, with the stem automation
in STATE_PROFILE on its Demucs stems, as the runtime sequencer will play it. Build, telegraph,
drop, pivot and return play every stem at 0 dB. The open and the break are the held breath:
drums and bass at the runtime's silence (-80 dB), other 8 dB down through a 900 Hz low-pass.
Every gain or filter edge is an 8 ms linear ramp that ends on the state's first sample, so the
drop's downbeat lands at full level. States that continue the performance join with no fade;
jumps take slice0's 10 ms equal-power join ending on the bar line. Measured on the master:
the kick band (< 120 Hz) in each open against its own cycle's build must be <= -12 dB, and each
drop's loudness must rise >= 8 dB above its open. The positive control is the engine guide
through Demucs under the same automation; the negative is the same take with automation off.
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
from scipy.signal import butter, resample_poly, sosfilt, sosfiltfilt

import bed_lock as bl
import swing_check as sc
from arrange_restraint import spectral_rows
from audition import HOP, SR, XFADE, db, kick_envelope, load, lufs, seam, segment, wrap
from slice0 import DIRECTIONS, JOIN, PARENTS, captions

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
TWELVE_LAYER = ROOT / 'artifacts/local/v3-audio/hybrid-v2/hybrid-spillway-16bar.wav'
VOICE = Path('/home/andrew/Projects/music-video/renders/stems/vocals.wav')
VOICE_START_S = 6.0
VOICE_UNDER_DB = 24.0
PLANT = 'diagnostic/F/F.wav'

GATES = ('tempo', 'downbeat', 'dorian', 'chords', 'density', 'lag', 'vocals', 'seam')
LIMITS = dict(tempo_ms=12.0, dorian_margin=.05, lag_ms=12.0, vocals_db=-45.0, seam_lag_ms=12.0, seam_step_db=0.0)
NEGATIVE = dict(tempo='resampled 0.2% slow', downbeat='one eighth late', dorian='up a semitone',
                chords='bars shuffled', density='12-layer render (rejected)', lag='bass 40 ms late',
                vocals=f'real vocal {VOICE_UNDER_DB:.0f} dB under', seam='loop one sixteenth long')

NEW_SEED = 2026
CALM_SEEDS = (42, 1001, NEW_SEED)
WARDEN_SEEDS = (42, 1001, NEW_SEED)
WARDEN_STRENGTH = 0.95
STRAIGHT = {
    'F': ('shuffled ghost-note hats', 'straight, unswung sixteenth-note hats'),
    'X1': ('fast breakbeats with ghost notes and a ride cymbal',
           'fast breakbeats with ghost notes, straight, unswung sixteenth-note hats and a ride cymbal'),
    'X2': ('bit-crushed ghost hats', 'straight, unswung sixteenth-note bit-crushed hats'),
}
TAKE_DIRS = ('run/calm', 'run/warden', 'diag-swing/calm', 'round2/calm', 'round2/warden')
LOG_DIRS = ('logs', 'diag-swing/logs', 'round2/logs')

STEMS = ('drums', 'bass', 'other')
SILENT_DB = -80.0
EDGE = round(0.008 * SR)
LOWPASS_HZ = 900
PROFILES = {
    'full': dict(drums=dict(volume_db=0.0, lowpass_hz=None), bass=dict(volume_db=0.0, lowpass_hz=None),
                 other=dict(volume_db=0.0, lowpass_hz=None)),
    'breath': dict(drums=dict(volume_db=SILENT_DB, lowpass_hz=None), bass=dict(volume_db=SILENT_DB, lowpass_hz=None),
                   other=dict(volume_db=-8.0, lowpass_hz=LOWPASS_HZ, lowpass_order=2)),
}
STATE_PROFILE = {'open': 'breath', 'break': 'breath'}
ENTER_ON = {'drop': 'the next beat after contact; scripted here on the drop bar line, the performance drop downbeat'}
ARC_LIMITS = dict(open_kick_max_db=-12.0, drop_rise_min_db=8.0)
KICK_BAND = butter(4, 120, 'low', fs=SR, output='sos')
LOWPASS = butter(2, LOWPASS_HZ, 'low', fs=SR, output='sos')


def kind(state):
    return state.split(':')[-1]


def rdir(slice_dir):
    return slice_dir / 'round2'


def straight_caption(parent, direction):
    old, new = STRAIGHT[direction]
    text = captions()[f'{parent}-{direction}']
    if old not in text:
        raise SystemExit(f'{parent}-{direction} caption no longer contains {old!r}')
    return text.replace(old, new)


def prep(slice_dir):
    out = rdir(slice_dir)
    text = captions()
    reuse = {}
    for parent in PARENTS:
        run = out / parent
        (run / 'inputs').mkdir(parents=True, exist_ok=True)
        (run / 'jobs').mkdir(parents=True, exist_ok=True)
        shutil.copyfile(slice_dir / 'run' / parent / 'inputs' / 'guide-full.wav', run / 'inputs' / 'guide-full.wav')
        base = json.loads((slice_dir / 'run' / parent / 'jobs' / f'{parent}-F-085-s7.json').read_text())
        if parent == 'calm':
            cells = [(f'{d}st', straight_caption(parent, d), 0.85, s) for d in DIRECTIONS for s in CALM_SEEDS]
        else:
            cells = [('F', text['warden-F'], WARDEN_STRENGTH, s) for s in WARDEN_SEEDS]
        for tag, caption, strength, seed in cells:
            name = f'{parent}-{tag}-{round(strength * 100):03d}-s{seed}'
            old = slice_dir / 'diag-swing' / parent / 'jobs' / f'{name}.json'
            if old.exists() and json.loads(old.read_text())['jobs'][0]['params']['caption'] == caption:
                reuse[name] = str(old)
                continue
            job = json.loads(json.dumps(base['jobs'][0]))
            job.update(name=name, seeds=[seed])
            job['params'].update(caption=caption, audio_cover_strength=strength)
            (run / 'jobs' / f'{name}.json').write_text(json.dumps(dict(out_dir=f'../takes/{name}',
                                                                      defaults=base['defaults'], jobs=[job]), indent=1))
            print('job', name)
    for name, path in reuse.items():
        print('reused (same caption, rendered in round 1):', name, path)
    voice = load(VOICE)
    for parent in PARENTS:
        y = load(slice_dir / 'guides' / parent / 'guide-full.wav')
        v = segment(voice, round(VOICE_START_S * SR), len(y))
        v *= 10 ** ((db(np.sqrt(np.mean(y ** 2))) - VOICE_UNDER_DB - db(np.sqrt(np.mean(v ** 2)))) / 20)
        (out / 'controls').mkdir(parents=True, exist_ok=True)
        sf.write(out / 'controls' / f'vocal-negative-{parent}.wav', y + v, SR, subtype='PCM_24')
    (out / 'prep.json').write_text(json.dumps(dict(calm_seeds=CALM_SEEDS, warden_seeds=WARDEN_SEEDS,
                                                   warden_strength=WARDEN_STRENGTH, straight=STRAIGHT, reused=reuse,
                                                   voice=str(VOICE), voice_under_db=VOICE_UNDER_DB), indent=1))


def vocals(slice_dir):
    found, current = {}, None
    for d in LOG_DIRS:
        for log in sorted((slice_dir / d).glob('demucs*.log')):
            for line in log.read_text().splitlines():
                if ': separated in' in line:
                    current = line.split(':')[0]
                elif line.strip().startswith('vocals:') and current:
                    found[current] = float(line.split()[1])
    return found


class Parent:
    """One parent's grid, engine reference and the inputs of its positive control."""

    def __init__(self, slice_dir, parent):
        self.name, self.guides = parent, slice_dir / 'guides' / parent
        self.bar, self.n, self.step = bl.grid(self.guides)
        self.start, self.bars, self.bpm, _ = bl.region(self.guides)
        self.ref = bl.reference(self.guides, self.bar, self.step)

    def guide(self):
        return [load(self.guides / f'guide-full{s}.wav') for s in ('', '.drums', '.bass')]


def seam_measure(mix, drums, off, bar, n, extra=0):
    """The 16-bar loop at the take's trim: the join step against its own body, and the loop head's
    kick envelope against the take's own continuation after the loop's end."""
    length = n + extra
    s = seam(wrap(segment(mix, off, length), segment(mix, off + length, XFADE)))
    head, cont = kick_envelope(segment(drums, off, bar)), kick_envelope(segment(drums, off + length, bar))
    head = head - head.mean()
    reach = round(0.120 * SR / HOP)
    scores = []
    for lag in range(-reach, reach + 1):
        a = cont[max(lag, 0):len(cont) + min(lag, 0)]
        b = head[max(-lag, 0):len(head) + min(-lag, 0)]
        scores.append(float(np.dot(a - a.mean(), b)))
    lag_ms = (int(np.argmax(scores)) - reach) * HOP / SR * 1000
    return dict(seam_step_over_p999_db=s['join_over_p999_db'], seam_lag_ms=round(lag_ms, 2))


def measure(p, mix, drums, bass, vocals_db, seam_extra=0):
    cut = [y[p.start:] for y in (mix, drums, bass)]
    row = bl.screen_take(*cut, p.ref, p.bar, p.step, p.n)
    row.update(seam_measure(cut[0], cut[1], row['trim_samples'], p.bar, 16 * p.bar, seam_extra))
    row['vocals_rms_db'] = vocals_db
    return row


def values(row, p, b_dens):
    """Each gate's (value, pass) for one screened row."""
    ch = row['follows_chords']
    return dict(
        tempo=(row['tempo_drift_per_16_bars_ms'], abs(row['tempo_drift_per_16_bars_ms']) <= LIMITS['tempo_ms']),
        downbeat=(len(row['missing_downbeats']), not row['missing_downbeats']),
        dorian=(row['dorian_d_energy'], row['dorian_d_energy'] >= p.ref['dorian'] - LIMITS['dorian_margin']),
        chords=(f"{ch['cover_vs_guide_mean']}/{ch['guide_vs_next_bar_mean']}",
                ch['cover_vs_guide_mean'] > ch['guide_vs_next_bar_mean']),
        density=(f"{row['density_mean']}/{row['density_p90']}",
                 row['density_mean'] <= b_dens['mean'] and row['density_p90'] <= b_dens['max']),
        lag=(row['lock_lag_median_ms'], abs(row['lock_lag_median_ms']) <= LIMITS['lag_ms']),
        vocals=(row['vocals_rms_db'], row['vocals_rms_db'] is not None and row['vocals_rms_db'] <= LIMITS['vocals_db']),
        seam=(f"{row['seam_step_over_p999_db']}/{row['seam_lag_ms']}",
              row['seam_step_over_p999_db'] <= LIMITS['seam_step_db'] and abs(row['seam_lag_ms']) <= LIMITS['seam_lag_ms']))


def late(y, frames):
    return np.concatenate([np.zeros((frames, y.shape[1])), y])


def shuffled_bars(y, p):
    body = y[p.start:p.start + p.n].copy()
    order = list(range(p.bars))
    rng = random.Random(172)
    while any(i == o for i, o in enumerate(order)):
        rng.shuffle(order)
    out = y.copy()
    out[p.start:p.start + p.n] = np.concatenate([body[o * p.bar:(o + 1) * p.bar] for o in order])
    return out


def controls(slice_dir):
    out = rdir(slice_dir)
    voc = vocals(slice_dir)
    b_dens = bl.b_density()
    twelve = [r['density_mean'] for r in spectral_rows(load(TWELVE_LAYER), bl.B_BAR)]
    twelve = dict(density_mean=round(float(np.mean(twelve)), 3), density_p90=round(float(np.quantile(twelve, .9)), 3))
    report = dict(limits=LIMITS, b_density=dict(mean=b_dens['mean'], max=b_dens['max']), twelve_layer=twelve, parents={})
    for parent in PARENTS:
        p = Parent(slice_dir, parent)
        mix, drums, bass = p.guide()
        pos_voc = voc.get(str(p.guides / 'guide-full.wav'))
        neg_voc = voc.get(str(out / 'controls' / f'vocal-negative-{parent}.wav'))
        if pos_voc is None or neg_voc is None:
            raise SystemExit(f'{parent}: no Demucs vocals reading for the guide ({pos_voc}) or the vocal negative ({neg_voc})')
        pos = measure(p, mix, drums, bass, pos_voc)
        eighth, sixteenth = 2 * p.step, p.step
        neg_rows = {
            'tempo': measure(p, *[resample_poly(y, 501, 500, axis=0) for y in (mix, drums, bass)], pos_voc),
            'downbeat': measure(p, *[late(y, eighth) for y in (mix, drums, bass)], pos_voc),
            'dorian': measure(p, *[resample_poly(y, 84, 89, axis=0) for y in (mix, drums, bass)], pos_voc),
            'chords': measure(p, shuffled_bars(mix, p), drums, bass, pos_voc),
            'lag': measure(p, mix, drums, late(bass, round(0.040 * SR)), pos_voc),
            'seam': measure(p, mix, drums, bass, pos_voc, seam_extra=sixteenth),
        }
        pv = values(pos, p, b_dens)
        rows = {}
        for g in GATES:
            if g == 'density':
                neg_value = f"{twelve['density_mean']}/{twelve['density_p90']}"
                neg_pass = twelve['density_mean'] <= b_dens['mean'] and twelve['density_p90'] <= b_dens['max']
            elif g == 'vocals':
                neg_value, neg_pass = neg_voc, neg_voc <= LIMITS['vocals_db']
            else:
                neg_value, neg_pass = values(neg_rows[g], p, b_dens)[g]
            rows[g] = dict(positive=pv[g][0], positive_pass=pv[g][1], negative=NEGATIVE[g], negative_value=neg_value,
                           negative_pass=neg_pass, counted=bool(pv[g][1] and not neg_pass))
        report['parents'][parent] = dict(guide_dorian=p.ref['dorian'], gates=rows)
        print(parent, {g: ('counted' if r['counted'] else 'report-only') for g, r in rows.items()}, flush=True)
    (out / 'controls.json').write_text(json.dumps(report, indent=1, default=str))
    lines = ['| parent | gate | positive (guide through Demucs) | pass | negative control | negative value | fails | status |',
             '|---|---|---|---|---|---|---|---|']
    for parent, rep in report['parents'].items():
        for g, r in rep['gates'].items():
            lines.append(f"| {parent} | {g} | {r['positive']} | {'yes' if r['positive_pass'] else 'NO'} | {r['negative']} | "
                         f"{r['negative_value']} | {'yes' if not r['negative_pass'] else 'NO'} | "
                         f"{'counted' if r['counted'] else 'report-only'} |")
    lines.append(f"\nB density mean/max {b_dens['mean']}/{b_dens['max']}. Limits {LIMITS}.")
    (out / 'controls.md').write_text('\n'.join(lines) + '\n')
    print('\n'.join(lines))


def parse(label):
    """calm-X1st-085-s42 -> parent, direction, hats, strength, seed, pilot."""
    m = re.fullmatch(r'(pilot-)?(calm|warden)-([A-Z]\d?)(st|ns)?-(\d{3})-s(\d+)', label)
    if not m:
        raise SystemExit(f'unparsed take name {label}')
    pilot, parent, direction, variant, strength, seed = m.groups()
    hats = None if parent == 'warden' else {'st': 'straight', 'ns': 'no swing word', None: 'swung'}[variant]
    return dict(parent=parent, direction=direction, hats=hats, variant=variant, strength=int(strength) / 100,
                seed=int(seed), pilot=bool(pilot))


def all_takes(slice_dir):
    found = {}
    for d in TAKE_DIRS:
        run = slice_dir / d
        if (run / 'takes').exists():
            for label, path in bl.takes(run).items():
                found[label] = (path, d)
    return found


def screen(slice_dir):
    out = rdir(slice_dir)
    ctrl = json.loads((out / 'controls.json').read_text())
    b_dens = bl.b_density()
    voc = vocals(slice_dir)
    parents = {p: Parent(slice_dir, p) for p in PARENTS}
    calm = parents['calm']
    guide_drums = load(calm.guides / 'guide-full.drums.wav')[calm.start:]
    coff = round(float(np.median(bl.drift(calm.ref['kick'], guide_drums, calm.bar, calm.bars)['lag_ms_per_bar'])) / 1000 * SR)
    hat_ctrl = sc.hat_slots(guide_drums, coff, calm.n, calm.step)
    rows = []
    for label, (path, where) in sorted(all_takes(slice_dir).items()):
        info = parse(label)
        stems = {s: path.with_suffix(f'.{s}.wav') for s in STEMS}
        if not all(s.exists() for s in stems.values()):
            print('no stems yet:', label)
            continue
        p = parents[info['parent']]
        row = dict(take=label, source=where, path=str(path), sha256=hashlib.sha256(path.read_bytes()).hexdigest(), **info,
                   **measure(p, load(path), load(stems['drums']), load(stems['bass']), voc.get(str(path))))
        if info['parent'] == 'calm':
            hats = sc.hat_slots(load(stems['drums'])[p.start:], row['trim_samples'], p.n, p.step)
            row['hat_s2_vs_guide_ms'] = None if hats[2][0] is None else round(hats[2][0] - hat_ctrl[2][0], 1)
        gates = values(row, p, b_dens)
        counted = ctrl['parents'][info['parent']]['gates']
        row['gates'] = {g: v[0] for g, v in gates.items()}
        row['fails'] = [g for g in GATES if not gates[g][1] and counted[g]['counted']]
        row['reported'] = [g for g in GATES if not gates[g][1] and not counted[g]['counted']]
        row['eligible'] = not info['pilot'] and info['variant'] != 'ns'
        rows.append(row)
        print(label, row['fails'] or 'PASS', row['reported'], flush=True)
    report = dict(controls=str(out / 'controls.json'), rows=rows)
    (out / 'screen.json').write_text(json.dumps(report, indent=1, default=str))
    head = ('| take | round | hats | str | seed | tempo ms/16 | missing downbeats | dorian | chords | density mean/p90 | '
            'lag ms | vocals dB | seam step dB/lag ms | hat s2 vs guide ms | fails (counted) | reported only |')
    lines = [head, '|' + '---|' * (head.count('|') - 1)]
    for r in rows:
        lines.append(f"| {r['take']} | {'2' if r['source'].startswith('round2') else '1'} | {r['hats'] or '-'} | {r['strength']} | "
                     f"{r['seed']} | {r['tempo_drift_per_16_bars_ms']} | {r['missing_downbeats'] or '-'} | {r['dorian_d_energy']} | "
                     f"{r['gates']['chords']} | {r['gates']['density']} | {r['lock_lag_median_ms']} | {r['vocals_rms_db']} | "
                     f"{r['gates']['seam']} | {r.get('hat_s2_vs_guide_ms', '-')} | "
                     f"{' '.join(r['fails']) or ('PASS' if r['eligible'] else 'PASS (not eligible)')} | "
                     f"{' '.join(r['reported']) or '-'} |")
    (out / 'screen.md').write_text('\n'.join(lines) + '\n')


def best(pool):
    return min(pool, key=lambda r: (abs(r['tempo_drift_per_16_bars_ms']),
                                    r['vocals_rms_db'] if r['vocals_rms_db'] is not None else 0.0), default=None)


def choose(rows):
    alive = [r for r in rows if r['eligible'] and not r['fails']]
    calm = [r for r in alive if r['parent'] == 'calm']
    warden = [r for r in alive if r['parent'] == 'warden']
    if not warden:
        return {}, 'no Warden take survived'
    chosen = {}

    def pair(c):
        own = best([w for w in warden if w['direction'] == c['direction']])
        w, rule = (own, 'own direction') if own else (best(warden), 'cross: best Warden survivor of any direction')
        return dict(calm=c, warden=w, warden_rule=rule)
    for d in DIRECTIONS:
        c = best([r for r in calm if r['direction'] == d and r['hats'] == 'straight'])
        if c:
            chosen[f'{d} straight'] = dict(pair(c), calm_rule=f'best straight {d} calm survivor')
    c = best([r for r in calm if r['hats'] == 'swung'])
    if c:
        chosen[f"{c['direction']} swung"] = dict(pair(c), calm_rule='best swung calm survivor, any direction')
    return chosen, None


def build(plan, sources):
    """Cut each state from its parent's source at the take's trim. A state that continues the
    previous one in the same performance plays on; a jump takes the 10 ms equal-power join that
    ends on the bar line. The last state fades out."""
    states, total = plan['states'], plan['total_frames']
    out = np.zeros((total + JOIN, 2))
    theta = np.linspace(0, np.pi / 2, JOIN)[:, None]

    def continues(a, b):
        return a['parent'] == b['parent'] and a['source_start'] + a['frames'] == b['source_start']
    for i, s in enumerate(states):
        y, trim = sources[s['parent']]
        joined = i > 0 and not continues(states[i - 1], s)
        pre = JOIN if joined else 0
        seg = segment(y, s['source_start'] + trim - pre, pre + s['frames'])
        if joined:
            seg[:JOIN] *= np.sin(theta)
        if i == len(states) - 1:
            seg[pre:] *= np.cos(np.linspace(0, np.pi / 2, s['frames']))[:, None]
        elif not continues(s, states[i + 1]):
            seg[-JOIN:] *= np.cos(theta)
        out[s['out_start'] - pre:s['out_start'] + s['frames']] += seg
    return out[:total]


def curves(plan, edge=EDGE):
    """Per-stem gain and low-pass wet curves from STATE_PROFILE, with EDGE-long linear ramps ending on each edge."""
    total = plan['total_frames']
    gain = {s: np.ones(total) for s in STEMS}
    wet = np.zeros(total)
    edges = []
    for i, st in enumerate(plan['states']):
        prof = PROFILES[STATE_PROFILE.get(kind(st['state']), 'full')]
        a, b = st['out_start'], st['out_start'] + st['frames']
        for s in STEMS:
            v = prof[s]['volume_db']
            gain[s][a:b] = 0.0 if v <= SILENT_DB else 10 ** (v / 20)
        wet[a:b] = 1.0 if prof['other']['lowpass_hz'] else 0.0
        if i:
            edges.append(a)
    moved = []
    for e in edges:
        changed = False
        for arr in [*gain.values(), wet]:
            before, after = arr[e - 1], arr[e]
            if before != after:
                arr[e - edge:e] = np.linspace(before, after, edge + 1)[:-1]
                changed = True
        if changed:
            moved.append(e)
    return gain, wet, moved


def mix_stems(stems, plan, automate=True, edge=EDGE):
    if not automate:
        return sum(stems.values())
    gain, wet, _ = curves(plan, edge)
    other = stems['other'] * (1 - wet[:, None]) + sosfilt(LOWPASS, stems['other'], axis=0) * wet[:, None]
    return stems['drums'] * gain['drums'][:, None] + stems['bass'] * gain['bass'][:, None] + other * gain['other'][:, None]


def arc(y, plan):
    """Per Warden cycle, and the break against the last build: the open's kick band against its build, and the drop's rise."""
    low = sosfiltfilt(KICK_BAND, y.mean(axis=1))
    st = {s['state']: s for s in plan['states']}

    def span(s, tail=0):
        return s['out_start'], s['out_start'] + s['frames'] - tail

    def kick(s, tail=0):
        a, b = span(s, tail)
        return db(np.sqrt(np.mean(low[a:b] ** 2)))

    def loud(s, tail=0):
        a, b = span(s, tail)
        return lufs(y[a:b])
    rows = []
    for c in (1, 2, 3):
        b, o, d = (st[f'warden-{c}:{k}'] for k in ('build', 'open', 'drop'))
        rows.append(dict(cycle=c, open_kick_vs_build_db=round(kick(o, EDGE) - kick(b), 1),
                         drop_rise_db=round(loud(d) - loud(o, EDGE), 1)))
    rows.append(dict(cycle='break', open_kick_vs_build_db=round(kick(st['break'], EDGE) - kick(st['warden-3:build']), 1),
                     drop_rise_db=None))
    worst_open = max(r['open_kick_vs_build_db'] for r in rows)
    worst_rise = min(r['drop_rise_db'] for r in rows if r['drop_rise_db'] is not None)
    return dict(cycles=rows, worst_open_kick_db=worst_open, worst_drop_rise_db=worst_rise,
                passes=bool(worst_open <= ARC_LIMITS['open_kick_max_db'] and worst_rise >= ARC_LIMITS['drop_rise_min_db']))


def clicks(y, plan):
    """A click is a one-sample jump: |step| against the median |step| over the 1.5 ms around it.
    The worst such ratio within 12 ms of each state edge (ramps and joins) is compared with the
    same ratio at every other bar line, where only the music sets it."""
    d = np.abs(np.diff(y, axis=0)).max(axis=1)
    reach, ctx = round(0.012 * SR), 32

    def spike(at):
        lo, hi = max(at - reach, ctx), min(at + reach, len(d) - ctx)
        win = np.lib.stride_tricks.sliding_window_view(d[lo - ctx:hi + ctx], 2 * ctx + 1)
        return float((d[lo:hi] / (np.median(win, axis=1) + 1e-9)).max())
    edges = [s['out_start'] for s in plan['states'][1:]]
    lines = []
    for s in plan['states']:
        first, last = (int(v) for v in s['bars'].split('-'))
        bar = s['frames'] // (last - first + 1)
        lines += [s['out_start'] + k * bar for k in range(1, last - first + 1)]
    edge, music = max(spike(a) for a in edges), [spike(a) for a in lines]
    return dict(edge_worst_spike=round(edge, 1), bar_line_max_spike=round(max(music), 1),
                bar_line_p95_spike=round(float(np.quantile(music, .95)), 1), passes=bool(edge <= max(music)))


def automation(plan, dest):
    dest.mkdir(parents=True, exist_ok=True)
    seen = {}
    for s in plan['states']:
        k = kind(s['state'])
        if k in seen:
            continue
        profile = STATE_PROFILE.get(k, 'full')
        seen[k] = dict(state=k, parent=s['parent'], section=s['section'], profile=profile,
                       enter_on=ENTER_ON.get(k, 'the state bar line'),
                       ramp=dict(ms=round(EDGE / SR * 1000, 1), shape='linear', ends_on='the entry point'),
                       silent_db=SILENT_DB, stems=PROFILES[profile])
        (dest / f'{k}.json').write_text(json.dumps(seen[k], indent=1))
    return seen


def stems_of(path):
    return {s: load(Path(path).with_suffix(f'.{s}.wav')) for s in STEMS}


def assemble(slice_dir):
    from slice0 import timeline
    out = rdir(slice_dir)
    plan = timeline(slice_dir)
    automation(plan, out / 'automation')
    rows = json.loads((out / 'screen.json').read_text())['rows']
    chosen, blocked = choose(rows)
    if blocked:
        raise SystemExit(blocked)
    guide_stems = {p: stems_of(slice_dir / 'guides' / p / 'guide-full.wav') for p in PARENTS}
    ctrl_stems = {s: build(plan, {p: (guide_stems[p][s], 0) for p in PARENTS}) for s in STEMS}
    positive = arc(mix_stems(ctrl_stems, plan), plan)
    print('arc positive control (engine guide through Demucs, automated)', positive, flush=True)
    done = dict(positive_control=positive, assemblies={})
    for label, pick in chosen.items():
        dest = out / 'assembled' / label.replace(' ', '-')
        dest.mkdir(parents=True, exist_ok=True)
        take_stems = {p: stems_of(pick[p]['path']) for p in PARENTS}
        stems = {s: build(plan, {p: (take_stems[p][s], pick[p]['trim_samples']) for p in PARENTS}) for s in STEMS}
        raw = arc(mix_stems(stems, plan, automate=False), plan)
        mastered, loud = bl.master(mix_stems(stems, plan), dest / f"{label.replace(' ', '-')}.wav")
        measured = arc(mastered, plan)
        done['assemblies'][label] = dict(
            takes={p: dict(take=pick[p]['take'], path=pick[p]['path'], sha256=pick[p]['sha256'],
                           trim_samples=pick[p]['trim_samples'], tempo=pick[p]['tempo_drift_per_16_bars_ms'],
                           vocals=pick[p]['vocals_rms_db'], reported=pick[p]['reported']) for p in PARENTS},
            calm_rule=pick['calm_rule'], warden_rule=pick['warden_rule'],
            drop_downbeat_kick=25 not in pick['warden']['missing_downbeats'],
            arc=measured, arc_negative_raw=raw, edge_clicks=clicks(mastered, plan),
            edge_clicks_negative_instant=clicks(mix_stems(stems, plan, edge=1), plan),
            wav=str(dest / f"{label.replace(' ', '-')}.wav"), seconds=round(len(mastered) / SR, 2), master=loud)
        print(label, {p: pick[p]['take'] for p in PARENTS}, 'arc', measured['worst_open_kick_db'], measured['worst_drop_rise_db'],
              'raw', raw['worst_open_kick_db'], raw['worst_drop_rise_db'], loud['lufs_after'], loud['true_peak_dbtp'], flush=True)
    plant_dest = out / 'assembled' / 'planted-weak'
    plant_dest.mkdir(parents=True, exist_ok=True)
    plant, loud = bl.master(load(slice_dir / PLANT), plant_dest / 'planted-weak.wav')
    done['planted'] = dict(source=str(slice_dir / PLANT), arc=arc(plant, plan), wav=str(plant_dest / 'planted-weak.wav'),
                           seconds=round(len(plant) / SR, 2), master=loud,
                           takes=json.loads((slice_dir / 'diagnostic' / 'assemble.json').read_text())['F']['takes'])
    (out / 'assemble.json').write_text(json.dumps(done, indent=1, default=str))


def pack(slice_dir, dest):
    done = json.loads((rdir(slice_dir) / 'assemble.json').read_text())
    items = [(label, Path(a['wav'])) for label, a in done['assemblies'].items()] + [('planted weak', Path(done['planted']['wav']))]
    random.SystemRandom().shuffle(items)
    dest.mkdir(parents=True, exist_ok=True)
    key, manifest = {}, {}
    for i, (label, src) in enumerate(items, 1):
        entry = done['assemblies'].get(label) or done['planted']
        for ext in ('.wav', '.opus'):
            target = dest / f'Y{i}{ext}'
            shutil.copyfile(src.with_suffix(ext), target)
            manifest[target.name] = hashlib.sha256(target.read_bytes()).hexdigest()
        key[f'Y{i}'] = dict(label=label, takes={p: t['take'] for p, t in entry['takes'].items()}, source=str(src))
    (dest / '.key.json').write_text(json.dumps(key, indent=1))
    (dest / 'README.txt').write_text('Rank by ear, note any moment that sounds wrong, and say which are fit for the game.\n')
    (rdir(slice_dir) / 'pack-manifest.json').write_text(json.dumps(dict(dest=str(dest), sha256=manifest), indent=1))
    print('packed', len(items), 'candidates to', dest)


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    args = [Path(a) for a in sys.argv[2:]]
    if cmd in ('prep', 'controls', 'screen', 'assemble') and len(args) == 1:
        globals()[cmd](args[0])
    elif cmd == 'pack' and len(args) == 2:
        pack(*args)
    else:
        sys.exit(__doc__)
