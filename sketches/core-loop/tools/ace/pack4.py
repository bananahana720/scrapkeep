"""Pack 4: Warden-only excerpts that separate the Warden performance from the stem automation.

Pack 3's Y2 and Y3 differed in two things at once: the Warden take (warden-F-085-s7 or
warden-F-085-s42; both builds carry little kick band in bars 1-8, and s7's bars 1-4 about 12 dB
less than s42's) and the dynamics (round 2's hard stem automation against raw ACE dynamics).
Pack 4 plays one span of each combination:

    s42 raw     s42 hard     s7 raw     s7 hard     s42 gentle

    PY=/home/andrew/Projects/music-video/.venv/bin/python
    $PY pack4.py excerpts <slice>        # round2/pack4/<track>/, automation/open-gentle.json, excerpts.json
    $PY pack4.py pack <slice> <dest>     # Z1..Z5 shuffled, WAV and Opus, .key.json, README.txt
    $PY pack4.py rekey <slice> <dest>    # rewrite .key.json from excerpts.json, same Z labels, audio checked unchanged

The span is timeline.json's pivot, warden-1 build, telegraph, open and drop, then the first 4 bars
of warden-2's build (the timeline's jump back to build bar 9). Each track is cut from the full
timeline built by pack3.build at the take's screened trim, so every join and ramp is the one the
three-minute assembly plays. Raw is the take's own mix as ACE played it, the Warden of pack 3's
planted Y3. Hard and gentle automate the sum of the take's Demucs drums, bass and other stems, as
round 2 did; the vocals stem was never saved, so the automated tracks lack the take's residue
outside those three stems (excerpts.json reports it against the take's mix). The unpacked
reference 's42 raw stems' is that three-stem sum unautomated, so the residue's share of any
raw-against-automated verdict can be heard apart from the automation's.

Hard is round 2's automation through pack3.mix_stems. Gentle ducks drums 12 dB through a 2 kHz
low-pass, keeps the bass 6 dB down and leaves other untouched; its ramp into the open is 60 ms and
its ramp out is 20 ms, each linear and ending on the state's first sample, so the drop still lands
at full level on its bar line. Each excerpt gets 50 ms fades at its two ends, then pack3's master
(-14 LUFS, true peak under -1 dBTP for the WAV and the decoded Opus).

Measured per track on the master, as pack3.arc does: the kick band (< 120 Hz) in the open
against the whole build and against its last 4 bars (s7's build opens without a kick, which
lowers its whole-build reference), and the drop's loudness rise over the open. Clicks use
pack3.clicks' one-sample-jump ratio. The window at an automation edge runs from 12 ms before
the ramp starts to 12 ms after the edge, so it covers both ends of a 60 ms ramp. That ratio is
compared with the worst one at the excerpt's bar lines. The negative control is each automated
track switched in one sample. Both edges fall on bar-line downbeats, so the detector can miss even
that switch; a track's clicks.passes is true or false only where it flagged the negative, and null
otherwise, with ramp_evidence (read from the gain curves: ramp length and largest one-sample gain
step) as the structural record. kick_attribution measures the automation's own kick-band dip
pre-master, against the take's unautomated stem sum, per stem, and for gentle across bass levels.
"""

import hashlib
import json
import random
import shutil
import sys
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt, sosfiltfilt

import bed_lock as bl
import pack3 as p3
from audition import SR, db, load, lufs

WARDEN_TAKES = {'s42': 'warden-F-085-s42', 's7': 'warden-F-085-s7'}
SPAN = ('pivot', 'warden-1:build', 'warden-1:telegraph', 'warden-1:open', 'warden-1:drop')
TAIL_STATE, TAIL_BARS = 'warden-2:build', 4
FADE = round(0.050 * SR)
GENTLE = dict(drums=dict(volume_db=-12.0, lowpass_hz=2000, lowpass_order=2),
              bass=dict(volume_db=-6.0, lowpass_hz=None),
              other=dict(volume_db=0.0, lowpass_hz=None))
GENTLE_IN, GENTLE_OUT = round(0.060 * SR), round(0.020 * SR)
AUTOMATION = {
    'raw': dict(ramp_in=p3.EDGE, ramp_out=p3.EDGE),
    'raw-stems': dict(ramp_in=p3.EDGE, ramp_out=p3.EDGE),
    'hard': dict(ramp_in=p3.EDGE, ramp_out=p3.EDGE),
    'gentle': dict(ramp_in=GENTLE_IN, ramp_out=GENTLE_OUT),
}
TRACKS = (('s42 raw', 's42', 'raw'), ('s42 hard', 's42', 'hard'), ('s7 raw', 's7', 'raw'),
          ('s7 hard', 's7', 'hard'), ('s42 gentle', 's42', 'gentle'))
REFERENCE = (('s42 raw stems', 's42', 'raw-stems'),)
README = ('Warden section only, about a minute each. Rank by ear and say what you like or don\'t about '
          'the moment the Warden opens and the drop.\n')


def out_dir(slice_dir):
    return p3.rdir(slice_dir) / 'pack4'


def plan_of(slice_dir):
    """timeline.json, checked against the timeline slice0 computes for pack3.assemble."""
    from slice0 import timeline
    plan = json.loads((slice_dir / 'timeline.json').read_text())
    if plan['states'] != timeline(slice_dir)['states']:
        raise SystemExit('timeline.json no longer matches slice0.timeline(); regenerate it before pack 4')
    return plan


def span(plan):
    """(start, end) output frames of the excerpt and its states rebased to the excerpt's start."""
    st = {s['state']: s for s in plan['states']}
    names = [s['state'] for s in plan['states']]
    if names[names.index(SPAN[0]):names.index(SPAN[-1]) + 2] != [*SPAN, TAIL_STATE]:
        raise SystemExit(f'timeline order changed around {SPAN}')
    tail = st[TAIL_STATE]
    first, last = (int(v) for v in tail['bars'].split('-'))
    bar = tail['frames'] // (last - first + 1)
    a, b = st[SPAN[0]]['out_start'], tail['out_start'] + TAIL_BARS * bar
    states = [dict(st[k], out_start=st[k]['out_start'] - a) for k in SPAN]
    states.append(dict(tail, out_start=tail['out_start'] - a, frames=TAIL_BARS * bar,
                       bars=f'{first}-{first + TAIL_BARS - 1}'))
    return a, b, dict(states=states, total_frames=b - a)


def gentle_curves(plan, profile=GENTLE, ramp_in=GENTLE_IN, ramp_out=GENTLE_OUT):
    """Per-stem gain and low-pass wet curves: the given profile in every state pack3.STATE_PROFILE
    marks as the breath, full elsewhere. A linear ramp ends on each edge; ramp_in into the breath,
    ramp_out out of it."""
    total = plan['total_frames']
    full = p3.PROFILES['full']
    gain = {s: np.ones(total) for s in p3.STEMS}
    wet = {s: np.zeros(total) for s in p3.STEMS}
    for st in plan['states']:
        prof = profile if p3.STATE_PROFILE.get(p3.kind(st['state'])) == 'breath' else full
        a, b = st['out_start'], st['out_start'] + st['frames']
        for s in p3.STEMS:
            v = prof[s]['volume_db']
            gain[s][a:b] = 0.0 if v <= p3.SILENT_DB else 10 ** (v / 20)
            wet[s][a:b] = 1.0 if prof[s]['lowpass_hz'] else 0.0
    for st in plan['states'][1:]:
        e = st['out_start']
        edge = ramp_in if p3.STATE_PROFILE.get(p3.kind(st['state'])) == 'breath' else ramp_out
        for arr in [*gain.values(), *wet.values()]:
            before, after = arr[e - 1], arr[e]
            if before != after:
                arr[e - edge:e] = np.linspace(before, after, edge + 1)[:-1]
    return gain, wet


def gentle_mix(stems, plan, profile=GENTLE, ramp_in=GENTLE_IN, ramp_out=GENTLE_OUT):
    gain, wet = gentle_curves(plan, profile, ramp_in, ramp_out)
    out = 0
    for s in p3.STEMS:
        y = stems[s]
        hz = profile[s]['lowpass_hz']
        if hz:
            lp = butter(profile[s].get('lowpass_order', 2), hz, 'low', fs=SR, output='sos')
            y = y * (1 - wet[s][:, None]) + sosfilt(lp, y, axis=0) * wet[s][:, None]
        out = out + y * gain[s][:, None]
    return out


def automated(stems, plan, automation, instant=False):
    """The automation's per-stem output and its gain and wet curves; their sum is mix()'s
    (hard term by term as pack3.mix_stems, gentle as gentle_mix)."""
    if automation == 'hard':
        gain, w, _ = p3.curves(plan, 1 if instant else p3.EDGE)
        wet = {s: w if s == 'other' else np.zeros_like(w) for s in p3.STEMS}
        lp = {'other': p3.LOWPASS}
    else:
        gain, wet = gentle_curves(plan, ramp_in=1, ramp_out=1) if instant else gentle_curves(plan)
        lp = {s: butter(GENTLE[s].get('lowpass_order', 2), GENTLE[s]['lowpass_hz'], 'low', fs=SR, output='sos')
              for s in p3.STEMS if GENTLE[s]['lowpass_hz']}
    parts = {}
    for s in p3.STEMS:
        y = stems[s]
        if s in lp:
            y = y * (1 - wet[s][:, None]) + sosfilt(lp[s], y, axis=0) * wet[s][:, None]
        parts[s] = y * gain[s][:, None]
    return parts, gain, wet


def ramp_evidence(gain, wet, a, sub, ramp_in, ramp_out):
    """From the gain and wet curves, not the audio: at the open's two edges, how many samples the
    curves move over and their largest one-sample step. A linear ramp of n samples between levels
    g0 and g1 steps |g1 - g0| / n per sample; an instant switch steps the whole change at once."""
    st = {s['state']: s for s in sub['states']}
    rows = {}
    for name, state, ramp in (('open', 'warden-1:open', ramp_in), ('drop', 'warden-1:drop', ramp_out)):
        e = a + st[state]['out_start']
        lo, hi = e - 4 * ramp, e + 4 * ramp
        steps = [np.abs(np.diff(c[lo:hi])) for c in [*gain.values(), *wet.values()]]
        moving = max(int((s > 0).sum()) for s in steps)
        rows[name] = dict(ramp_samples=moving, ramp_ms=round(moving / SR * 1000, 2),
                          largest_one_sample_gain_step=round(float(max(s.max() for s in steps)), 5))
    return rows


def kick_attribution(parts, raw_parts, a, b, sub, ramp_out):
    """Pre-master, in the open less its closing ramp: the three-stem sum's kick band (< 120 Hz)
    after the automation against the same sum unautomated (the dip the automation alone makes,
    with no master gain in it), each stem's likewise, and each unautomated stem's kick band
    against the unautomated sum's."""
    o = {s['state']: s for s in sub['states']}['warden-1:open']
    lo, hi = o['out_start'], o['out_start'] + o['frames'] - ramp_out

    def low(y):
        return sosfiltfilt(p3.KICK_BAND, y[a:b].mean(axis=1))[lo:hi]
    auto_low = {s: low(parts[s]) for s in p3.STEMS}
    raw_low = {s: low(raw_parts[s]) for s in p3.STEMS}
    raw_sum = rms_db(sum(raw_low.values()))
    row = dict(open_kick_dip_vs_unautomated_stems_db=round(rms_db(sum(auto_low.values())) - raw_sum, 1),
               per_stem_dip_db={s: round(rms_db(auto_low[s]) - rms_db(raw_low[s]), 1) for s in p3.STEMS},
               unautomated_stem_kick_vs_sum_db={s: round(rms_db(raw_low[s]) - raw_sum, 1) for s in p3.STEMS})
    return row, (auto_low, raw_low, raw_sum)


def rms_db(x):
    return db(np.sqrt(np.mean(x ** 2)))


def bass_sweep(auto_low, raw_low, raw_sum):
    """The gentle breath's pre-master kick-band dip with drums and other as specified and the bass
    at 0 to -40 dB or muted. The kick band is linear in each stem's gain, so this is exact for the
    open's body; it only asks what bass level a deeper dip would need, and changes nothing."""
    rows = {}
    for v in [*range(0, -41, -2), None]:
        g = 0.0 if v is None else 10 ** (v / 20)
        rows['muted' if v is None else str(v)] = round(rms_db(auto_low['drums'] + auto_low['other'] + raw_low['bass'] * g) - raw_sum, 1)
    return rows


def mix(take, plan, automation, instant=False):
    stems = take['stems']
    if automation == 'raw':
        return take['whole']
    if automation == 'raw-stems':
        return p3.mix_stems(stems, plan, automate=False)
    if automation == 'hard':
        return p3.mix_stems(stems, plan, edge=1 if instant else p3.EDGE)
    if instant:
        return gentle_mix(stems, plan, ramp_in=1, ramp_out=1)
    return gentle_mix(stems, plan)


def arc1(y, sub, ramp_out):
    """pack3.arc for warden-1 on the excerpt: the open's kick band against the build and against the
    build's last 4 bars, and the drop's loudness over the open; the open's closing ramp excluded."""
    low = sosfiltfilt(p3.KICK_BAND, y.mean(axis=1))
    st = {s['state']: s for s in sub['states']}
    b, o, d = st['warden-1:build'], st['warden-1:open'], st['warden-1:drop']

    def rms(a, e):
        return db(np.sqrt(np.mean(low[a:e] ** 2)))
    open_end = o['out_start'] + o['frames'] - ramp_out
    build_end = b['out_start'] + b['frames']
    open_kick = rms(o['out_start'], open_end)
    return dict(open_kick_vs_build_db=round(open_kick - rms(b['out_start'], build_end), 1),
                open_kick_vs_build_last4_db=round(open_kick - rms(build_end - o['frames'], build_end), 1),
                drop_rise_db=round(lufs(y[d['out_start']:d['out_start'] + d['frames']]) - lufs(y[o['out_start']:open_end]), 1))


def clicks(y, sub, ramp_in, ramp_out):
    """pack3.clicks' one-sample-jump ratio at the open's two edges, each window reaching 12 ms past
    both ends of its ramp, against the same ratio at every bar line inside the excerpt's states."""
    d = np.abs(np.diff(y, axis=0)).max(axis=1)
    reach, ctx = round(0.012 * SR), 32

    def spike(lo, hi):
        lo, hi = max(lo, ctx), min(hi, len(d) - ctx)
        win = np.lib.stride_tricks.sliding_window_view(d[lo - ctx:hi + ctx], 2 * ctx + 1)
        return float((d[lo:hi] / (np.median(win, axis=1) + 1e-9)).max())
    st = {s['state']: s for s in sub['states']}
    into, out = st['warden-1:open']['out_start'], st['warden-1:drop']['out_start']
    lines = []
    for s in sub['states']:
        first, last = (int(v) for v in s['bars'].split('-'))
        bar = s['frames'] // (last - first + 1)
        lines += [s['out_start'] + k * bar for k in range(1, last - first + 1)]
    music = [spike(a - reach, a + reach) for a in lines]
    open_spike = spike(into - ramp_in - reach, into + reach)
    drop_spike = spike(out - ramp_out - reach, out + reach)
    return dict(open_edge_spike=round(open_spike, 1), drop_edge_spike=round(drop_spike, 1),
                bar_line_max_spike=round(max(music), 1), bar_line_p95_spike=round(float(np.quantile(music, .95)), 1),
                below_bar_max=bool(max(open_spike, drop_spike) <= max(music)))


def click_verdict(measured, negative):
    """passes is True or False only where the detector flagged the instant-switch negative, so it
    can tell a switch from the music at these edges; None where it could not (both edges fall on
    bar-line downbeats, whose own jumps can hide a switch) or where no automation edge exists."""
    if negative is None:
        return dict(passes=None, verdict='no automation edge: the take plays contiguous source through the open and the drop')
    if negative['below_bar_max']:
        return dict(passes=None, verdict='inconclusive: the one-sample-jump detector did not flag the instant-switch '
                                         'negative at these downbeat edges; see ramp_evidence for the structural record')
    if measured['below_bar_max']:
        return dict(passes=True, verdict='pass: the detector flagged the instant-switch negative and not the ramped edges')
    return dict(passes=False, verdict='fail: a ramped edge scores above the worst bar line')


def write_gentle(slice_dir):
    hard = json.loads((p3.rdir(slice_dir) / 'automation' / 'open.json').read_text())
    doc = dict(hard, profile='breath-gentle', stems=GENTLE,
               ramp=dict(in_ms=round(GENTLE_IN / SR * 1000, 1), out_ms=round(GENTLE_OUT / SR * 1000, 1),
                         shape='linear', ends_on='the entry point: the open\'s first sample in, the drop\'s first sample out'),
               exit_on='the drop returns on the next beat after contact, as drop.json enter_on',
               compare='open.json is round 2\'s hard breath; this is pack 4\'s gentle alternative for the same state')
    path = p3.rdir(slice_dir) / 'automation' / 'open-gentle.json'
    path.write_text(json.dumps(doc, indent=1))
    return path


def take_row(slice_dir, name):
    rows = {r['take']: r for r in json.loads((p3.rdir(slice_dir) / 'screen.json').read_text())['rows']}
    r = rows[name]
    if hashlib.sha256(Path(r['path']).read_bytes()).hexdigest() != r['sha256']:
        raise SystemExit(f'{name} audio no longer matches screen.json')
    return r


def excerpts(slice_dir):
    plan = plan_of(slice_dir)
    a, b, sub = span(plan)
    gentle_json = write_gentle(slice_dir)
    dest = out_dir(slice_dir)
    calm_len = max(s['source_start'] + s['frames'] for s in plan['states'] if s['parent'] == 'calm') + p3.JOIN
    silent_calm = (np.zeros((calm_len, 2)), 0)
    fade = np.ones((b - a, 1))
    fade[:FADE, 0] = np.linspace(0, 1, FADE)
    fade[-FADE:, 0] = np.linspace(1, 0, FADE)
    report = dict(timeline=str(slice_dir / 'timeline.json'), span_states=[*SPAN, f'{TAIL_STATE} bars 1-{TAIL_BARS} of it'],
                  out_start=a, out_end=b, seconds=round((b - a) / SR, 2), fade_ms=50, gentle_automation=str(gentle_json),
                  hard_automation=str(p3.rdir(slice_dir) / 'automation' / 'open.json'), states=sub['states'], tracks={})
    built = {}
    for key, name in WARDEN_TAKES.items():
        row = take_row(slice_dir, name)
        take_stems = p3.stems_of(row['path'])
        stems = {s: p3.build(plan, {'calm': silent_calm, 'warden': (take_stems[s], row['trim_samples'])}) for s in p3.STEMS}
        whole = p3.build(plan, {'calm': silent_calm, 'warden': (load(row['path']), row['trim_samples'])})
        residual = whole[a:b] - sum(stems.values())[a:b]
        built[key] = dict(stems=stems, whole=whole, row=row, stem_sum_residual_db=round(
            db(np.sqrt(np.mean(residual ** 2))) - db(np.sqrt(np.mean(whole[a:b] ** 2))), 1))
    hard_check = gentle_mix(built['s42']['stems'], plan, p3.PROFILES['breath'], p3.EDGE, p3.EDGE)
    report['gentle_mix_reproduces_hard_max_abs_diff'] = float(np.abs(hard_check - p3.mix_stems(built['s42']['stems'], plan)).max())
    for label, take, auto in TRACKS + REFERENCE:
        t = built[take]
        ramps = AUTOMATION[auto]
        y = mix(t, plan, auto)[a:b] * fade
        name = label.replace(' ', '-')
        (dest / name).mkdir(parents=True, exist_ok=True)
        mastered, loud = bl.master(y, dest / name / f'{name}.wav')
        entry = dict(take=t['row']['take'], path=t['row']['path'], sha256=t['row']['sha256'], trim_samples=t['row']['trim_samples'],
                     screen_missing_downbeats=t['row']['missing_downbeats'], screen_vocals_rms_db=t['row']['vocals_rms_db'],
                     stem_sum_residual_vs_take_db=t['stem_sum_residual_db'], automation=auto,
                     source_mix='take mix' if auto == 'raw' else 'Demucs drums+bass+other',
                     automation_file=str(gentle_json if auto == 'gentle' else report['hard_automation']) if auto in ('hard', 'gentle') else None,
                     ramp_in_ms=round(ramps['ramp_in'] / SR * 1000, 1) if auto in ('hard', 'gentle') else None,
                     ramp_out_ms=round(ramps['ramp_out'] / SR * 1000, 1) if auto in ('hard', 'gentle') else None,
                     packed=(label, take, auto) in TRACKS,
                     arc=arc1(mastered, sub, ramps['ramp_out']), clicks=clicks(mastered, sub, ramps['ramp_in'], ramps['ramp_out']),
                     wav=str(dest / name / f'{name}.wav'), seconds=round(len(mastered) / SR, 2), master=loud)
        negative = None
        if auto in ('hard', 'gentle'):
            instant = mix(t, plan, auto, instant=True)[a:b] * fade
            negative = entry['clicks_negative_instant'] = clicks(instant, sub, 1, 1)
            parts, gain, wet = automated(t['stems'], plan, auto)
            entry['parts_sum_vs_mix_max_abs_diff'] = float(np.abs(sum(parts.values()) - mix(t, plan, auto)).max())
            entry['ramp_evidence'] = ramp_evidence(gain, wet, a, sub, ramps['ramp_in'], ramps['ramp_out'])
            _, gain1, wet1 = automated(t['stems'], plan, auto, instant=True)
            entry['ramp_evidence_negative_instant'] = ramp_evidence(gain1, wet1, a, sub, 1, 1)
            entry['kick_attribution'], lows = kick_attribution(parts, t['stems'], a, b, sub, ramps['ramp_out'])
            if auto == 'gentle':
                entry['kick_attribution']['bass_sweep_dip_db'] = bass_sweep(*lows)
        entry['clicks'].update(click_verdict(entry['clicks'], negative))
        report['tracks'][label] = entry
        print(label, entry['arc'], entry['clicks'], loud['lufs_after'], loud['true_peak_dbtp'], loud['opus']['true_peak_dbtp'],
              flush=True)
    (dest / 'excerpts.json').write_text(json.dumps(report, indent=1, default=str))


def key_entry(label, entry):
    return dict(label=label, take=entry['take'], automation=entry['automation'], source_mix=entry['source_mix'],
                stem_sum_residual_vs_take_db=entry['stem_sum_residual_vs_take_db'],
                automation_file=entry['automation_file'], source=entry['wav'], arc=entry['arc'],
                kick_attribution=entry.get('kick_attribution'), clicks=entry['clicks'],
                clicks_negative_instant=entry.get('clicks_negative_instant'), ramp_evidence=entry.get('ramp_evidence'),
                master=entry['master'])


KEY_NOTES = dict(
    kick='arc is measured on the master against the track\'s own build. kick_attribution is pre-master against the '
         'same take\'s unautomated drums+bass+other sum, so it is the automation\'s own dip. The gentle spec '
         '(drums -12 dB, bass -6 dB, other untouched) gives a mix dip smaller than the drums\' 12 dB, because the '
         'bass stem, only 6 dB down, carries kick-band energy too (unautomated_stem_kick_vs_sum_db shows each '
         'stem\'s share); bass_sweep_dip_db shows what a lower bass would give.',
    clicks='passes is true or false only where the one-sample-jump detector flagged the instant-switch negative. '
           'It is null where it could not, because both edges fall on bar-line downbeats, and for raw tracks, which '
           'have no automation edge. ramp_evidence is read from the gain curves: the samples each ramp spans and '
           'its largest one-sample gain step.')


def rekey(slice_dir, dest):
    """Rewrite dest/.key.json from the current excerpts.json under the pack's existing Z labels,
    after checking that every packed Z file is still the audio the manifest recorded."""
    report = json.loads((out_dir(slice_dir) / 'excerpts.json').read_text())
    manifest = json.loads((out_dir(slice_dir) / 'pack-manifest.json').read_text())['sha256']
    old = json.loads((dest / '.key.json').read_text())
    key = dict(_notes=dict(old['_notes'], **KEY_NOTES))
    for z in sorted(k for k in old if k.startswith('Z')):
        label = old[z]['label']
        entry = report['tracks'][label]
        wav = dest / f'{z}.wav'
        if hashlib.sha256(wav.read_bytes()).hexdigest() != manifest[wav.name]:
            raise SystemExit(f'{wav} changed since it was packed')
        if hashlib.sha256(Path(entry['wav']).read_bytes()).hexdigest() != manifest[wav.name]:
            raise SystemExit(f'{label} re-rendered to different audio than {wav}; re-pack instead of re-keying')
        key[z] = key_entry(label, entry)
    (dest / '.key.json').write_text(json.dumps(key, indent=1))
    print('re-keyed', len(key) - 1, 'excerpts in', dest, {z: key[z]['label'] for z in key if z != '_notes'})


def pack(slice_dir, dest):
    report = json.loads((out_dir(slice_dir) / 'excerpts.json').read_text())
    items = [(label, e) for label, e in report['tracks'].items() if e['packed']]
    random.SystemRandom().shuffle(items)
    dest.mkdir(parents=True, exist_ok=True)
    key = dict(_notes=dict(**KEY_NOTES,
        question='Pack 3 Y2 (s7 hard) and Y3 (s42 raw) differed in the Warden take and in the automation at once; '
                 'these five separate them.',
        span=report['span_states'], seconds=report['seconds'],
        mixes='raw is the take mix as ACE played it; hard and gentle automate the Demucs drums+bass+other sum, '
              'which lacks the take\'s vocal residue (stem_sum_residual_vs_take_db). The unpacked reference '
              '\'s42 raw stems\' in excerpts.json is that sum unautomated.'))
    manifest = {}
    for i, (label, entry) in enumerate(items, 1):
        src = Path(entry['wav'])
        for ext in ('.wav', '.opus'):
            target = dest / f'Z{i}{ext}'
            shutil.copyfile(src.with_suffix(ext), target)
            manifest[target.name] = hashlib.sha256(target.read_bytes()).hexdigest()
        key[f'Z{i}'] = key_entry(label, entry)
    (dest / '.key.json').write_text(json.dumps(key, indent=1))
    (dest / 'README.txt').write_text(README)
    (out_dir(slice_dir) / 'pack-manifest.json').write_text(json.dumps(dict(dest=str(dest), sha256=manifest), indent=1))
    print('packed', len(items), 'excerpts to', dest)


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    args = [Path(a) for a in sys.argv[2:]]
    if cmd == 'excerpts' and len(args) == 1:
        excerpts(args[0])
    elif cmd == 'pack' and len(args) == 2:
        pack(*args)
    elif cmd == 'rekey' and len(args) == 2:
        rekey(*args)
    else:
        sys.exit(__doc__)
