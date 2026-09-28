"""Generation-side groove lock: ACE-Step covers of the engine's own guides, screened and finished.

The engine composes (ace_guide_v3.gd --guides), ACE-Step performs and produces the whole
track, bass included. Screens reject; they never pick a winner. Andrew's blind listen decides.

    PY=/home/andrew/Projects/music-video/.venv/bin/python
    $PY bed_lock.py prep <guides dir> <run dir>          # ACE inputs + job files (pilot, sweep)
    (ACE-Step jobs and Demucs run through gpu_job.sh, one at a time)
    $PY bed_lock.py controls <guides dir> <run dir>      # calibration numbers for the screens
    $PY bed_lock.py screen <guides dir> <run dir>        # every take, every screen -> screen.{json,md}
    $PY bed_lock.py finish <guides dir> <run dir> <take> [<take> ...]
    $PY bed_lock.py pack <run dir> <pack dir> <take> [<take> ...]

Screens, fixed before the sweep was screened (the bass-kick threshold was set from the
controls subcommand's engine and v1 numbers, recorded in THRESHOLDS below):
  kick   engine-kick events (per sixteenth) against the take's Demucs drums, un-retimed, after
         one global trim from audition.drift(): median |onset error| <= 12 ms and a kick within
         +-43 ms (half a sixteenth) of every one of the 16 downbeats.
  tempo  audition.drift() Theil-Sen slope over 16 bars: |total drift| <= 12 ms.
  lock   the take's own bass (Demucs bass, < 300 Hz onsets) against its own kick: the median
         per-bar bass-to-kick envelope lag is within +-12 ms. The grid-deviation half (the
         strongest 5 bass onsets a bar within a median 12 ms of the kick's sixteenth grid) is
         reported and no longer gates: it failed its positive control (SCREEN-RULING.md). (The
         first design, per-bar Pearson r of 16-slot onset patterns, scored the engine's own
         locked bass and kick at -0.06: it measures pattern similarity, not lock, so it is
         reported and never gates.)
  key    the existing audition.key() check's D Dorian energy within 0.05 of the engine guide's
         own, and audition.follows_chords(): the take tracks the guide's chords better than the
         guide's own next-bar baseline. (KS alone reads the engine's own rootless-voiced D Dorian
         guide as E minor, so "reads D minor" would reject the engine itself.)
  density  arrange_restraint.spectral_rows significant bands: mean over bars <= B's mean and
         the 90th-percentile bar <= B's busiest bar (B = the v1 hybrid Andrew loved; v1's own raw
         bed has one bar above B's max, so a single-bar max would reject B's own bed).

Slice 0 parents (ace_guide_v3.gd --parent) carry their own grid in guide.json: the screen
region starts at screen_start and runs `bars` bars of samples_per_bar, at the parent's bpm.
Fixed before any parent take was screened: every screen runs on that region; tempo gates on
the drift per 16 bars (the frozen 16-bar screen's unit) and reports the region's total; B's
density is always measured on B's own 172 grid. Survivors are the top passing take per parent
and direction (tightest kick, then smallest lag); pilot takes are screened and never selected.
Fixed after the two pilot takes and before any sweep take was screened:
  control  when the guides dir holds the parent's own guide through Demucs (guide-full.<stem>.wav),
           it is screened first, and any gate it fails is reported, not gated, for that parent
           (the rule of SCREEN-RULING.md made structural). The Warden's lag half fails here: the
           club's sidechain pump ducks the bass under every kick, so the lag reads the pump.
  breath   open_kick_db, the Demucs drums below 120 Hz in the open bars against the telegraph
           bars, <= -12 dB (G3, the held breath: the control reads -32.8 dB, a kick that plays
           through reads about 0 dB).
"""

import json
import sys
from pathlib import Path

import librosa
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfiltfilt

from audition import HOP, SR, XFADE, bands, db, drift, follows_chords, key, kick_envelope, load, lufs, seam, segment, shape, wrap
from arrange_restraint import spectral_rows

ROOT = Path(__file__).resolve().parents[4]
B_MIX = ROOT / 'artifacts/local/v3-audio/hybrid/hybrid-spillway-16bar.wav'
B_OPUS = B_MIX.with_suffix('.opus')
V1 = Path('/home/andrew/Projects/scrapkeep-worktrees/core-loop-v3-feel-3/artifacts/local/ace-audition')
BARS = 16
B_BAR = 61536
GUIDES = {'a': 'guide-drums', 'b': 'guide-drums-bass', 'c': 'guide-full'}
STRENGTHS = (0.8, 0.85, 0.9)
SEEDS = (172, 7, 42, 1001)
PILOT = [(g, s, 172) for g in 'abc' for s in (0.8, 0.9)]
CAPTION = ('Sparse jazzy EDM instrumental at 172 BPM in D minor, Dorian, modal. A tight, produced drum kit: '
           'punchy kick, crisp snare, shuffled ghost-note hats, locked to a rolling reese bass with a clean sub. '
           'Warm Rhodes electric piano chords with jazzy ninths, played sparingly. Lean, minimal and restrained, '
           'polished studio production. Instrumental, no vocals, no pads, no strings, no extra synths.')
THRESHOLDS = dict(kick_median_ms=12.0, downbeat_window_ms=43.0, tempo_total_ms=12.0,
                  lock_dev_ms=12.0, lock_lag_ms=12.0, dorian_margin=.05, open_kick_max_db=-12.0)


def name(guide, strength, seed):
    return f'{guide}-{round(strength * 100):03d}-s{seed}'


def prep(guides, run):
    inputs, jobs = run / 'inputs', run / 'jobs'
    inputs.mkdir(parents=True, exist_ok=True)
    jobs.mkdir(parents=True, exist_ok=True)
    levels = {}
    for g, stem in GUIDES.items():
        y = load(guides / f'{stem}.wav')
        # Gain only, no limiting: the transients are what the cover must lock to.
        gain = min(-14 - lufs(y), -1 - db(np.abs(y).max()))
        sf.write(inputs / f'{stem}.wav', y * 10 ** (gain / 20), SR, subtype='PCM_16')
        levels[g] = dict(stem=stem, gain_db=round(gain, 2), lufs=round(lufs(y) + gain, 2))
    info = json.loads((guides / 'guide.json').read_text())

    def job(g, s, seed):
        return dict(name=name(g, s, seed), model='acestep-v15-xl-turbo', seeds=[seed],
                    params=dict(task_type='cover', audio_cover_strength=s, thinking=False,
                                src_audio=f'path:../inputs/{GUIDES[g]}.wav', caption=CAPTION,
                                inference_steps=8, shift=3.0))
    defaults = dict(lyrics='[Instrumental]', instrumental=True, bpm=172, keyscale='D minor',
                    timesignature='4', vocal_language='en',
                    duration=round(info['total_frames'] / SR, 3))
    every = [(g, s, seed) for g in 'abc' for s in STRENGTHS for seed in SEEDS]
    for label, cells in [('pilot', PILOT), ('sweep', [c for c in every if c not in PILOT])]:
        spec = dict(out_dir='../takes', defaults=defaults, jobs=[job(*c) for c in cells])
        (jobs / f'{label}.json').write_text(json.dumps(spec, indent=1))
    (run / 'prep.json').write_text(json.dumps(dict(levels=levels, caption=CAPTION, seeds=SEEDS,
                                                   strengths=STRENGTHS, guides=GUIDES), indent=1))
    print(json.dumps(levels, indent=1))



def grid(guides):
    info = json.loads((guides / 'guide.json').read_text())
    bar = info['samples_per_bar']
    return bar, bar * info.get('bars', BARS), bar // 16


def region(guides):
    """Where the screens look: first sample, bars, bpm and the parent's section map (if any)."""
    info = json.loads((guides / 'guide.json').read_text())
    return info.get('screen_start', 0), info.get('bars', BARS), round(float(info['bpm'])), info.get('sections', [])


def low_envelope(y, cutoff=300):
    mono = sosfiltfilt(butter(4, cutoff, 'low', fs=SR, output='sos'), y.mean(axis=1))
    return librosa.onset.onset_strength(y=mono.astype(np.float32), sr=SR, hop_length=HOP, n_fft=1024)


def strong_peaks(env, lo, hi, floor, sep):
    """Onsets: frames at or above floor that are the maximum within +-sep frames."""
    lo, hi = max(lo, sep), min(hi, len(env) - sep)
    return [i for i in range(lo, hi) if env[i] >= floor and env[i] == env[i - sep:i + sep + 1].max()]


def local_peaks(env, lo, hi, floor):
    lo, hi = max(lo, 1), min(hi, len(env) - 1)
    return [i for i in range(lo, hi) if env[i] >= floor and env[i] >= env[i - 1] and env[i] > env[i + 1]]


def engine_events(kick, bar, step, bars):
    """Engine kick hits on the sixteenth grid (energy rise, as retime_slice.timing) and each hit's envelope peak."""
    env = kick_envelope(kick)
    events = []
    for b in range(bars):
        for s in range(16):
            p = b * bar + s * step
            before = np.sqrt(np.mean(segment(kick, p - round(.010 * SR), round(.010 * SR)) ** 2))
            attack = np.sqrt(np.mean(kick[p:p + round(.015 * SR)] ** 2))
            if db(attack) - db(before) > 3 and attack > np.abs(kick).max() * .05:
                lo, hi = max(p - round(.005 * SR), 0) // HOP, (p + round(.040 * SR)) // HOP
                events.append((b, s, lo + int(np.argmax(env[lo:hi]))))
    return events, env


def open_kick_db(drums, off, sections):
    """Kick-band level (< 120 Hz) of the take's drums in the open bars against the telegraph bars, in dB."""
    spans = {name: (start, bars * bar_len) for name, start, bars, bar_len in sections}
    if 'open' not in spans or 'telegraph' not in spans:
        return None
    low = sosfiltfilt(butter(4, 120, 'low', fs=SR, output='sos'), drums.mean(axis=1))

    def rms(name):
        start, length = spans[name]
        # The open's last eighth is the drop's gap; leave it out.
        seg = low[max(start + off, 0):start + off + length - length // 32]
        return np.sqrt(np.mean(seg ** 2)) + 1e-12
    return round(db(rms('open')) - db(rms('telegraph')), 1)


def screen_take(mix, drums, bass, ref, bar, step, n):
    kick, events, bars = ref['kick'], ref['events'], ref['bars']
    lag = drift(kick, drums, bar, bars)
    off_ms = float(np.median(lag['lag_ms_per_bar']))
    off = round(off_ms / 1000 * SR)
    c = kick_envelope(drums)
    floor = .3 * np.quantile(c, .995)
    reach = round(THRESHOLDS['downbeat_window_ms'] / 1000 * SR / HOP)
    errors, missing_down, missing, used = [], [], [], []
    for b, s, t in events:
        centre = t + round(off / HOP)
        found = local_peaks(c, centre - reach, centre + reach + 1, floor)
        if found:
            best = max(found, key=lambda i: c[i])
            used.append(best)
            errors.append((best - centre) * HOP / SR * 1000)
        elif s == 0:
            missing_down.append(b + 1)
        else:
            missing.append(f'{b + 1}.{s}')
    latency = int(round(np.median([t - round((b * bar + s * step) / HOP) for b, s, t in events])))
    lo, hi = max(off, 0) // HOP, (off + n) // HOP
    sep = round(.030 * SR / HOP)
    kick_floor = .4 * float(np.median(c[used])) if used else floor
    all_kicks = strong_peaks(c, lo, hi, kick_floor, sep)
    extra = [i for i in all_kicks if min((abs(i - u) for u in used), default=1e9) > 3]
    benv = low_envelope(bass)
    # Calibrated on the controls only (engine bass: 5 reese notes a bar): the strongest 5 onsets a bar,
    # 60 ms apart, above half the 99th percentile. Engine median |dev| ~1 ms; v1's bed ~24 ms.
    cand = strong_peaks(benv, lo, hi, .5 * float(np.quantile(benv[lo:hi], .99)), round(.060 * SR / HOP))
    bass_on = sorted(cand, key=lambda i: -benv[i])[:5 * bars]

    def grid_dev(frames):
        d = [((i - latency) * HOP - off) % step for i in frames]
        return [min(v, step - v) / SR * 1000 for v in d]
    kdev, bdev = grid_dev(all_kicks), grid_dev(bass_on)
    lock_lag, lock_r = [], []
    reach60 = round(.060 * SR / HOP)
    for b in range(bars):
        a0, a1 = max(round((off + b * bar) / HOP), 0), round((off + (b + 1) * bar) / HOP)
        ref_k = c[a0:a1] - c[a0:a1].mean()
        best, best_lag = -np.inf, 0
        for L in range(-reach60, reach60 + 1):
            if a0 + L < 0 or a1 + L > len(benv):
                continue
            seg = benv[a0 + L:a1 + L] - benv[a0 + L:a1 + L].mean()
            r = float(np.dot(ref_k, seg) / max(np.linalg.norm(ref_k) * np.linalg.norm(seg), 1e-12))
            if r > best:
                best, best_lag = r, L
        lock_lag.append(best_lag * HOP / SR * 1000)
        lock_r.append(best)
    body = segment(mix, off, n)
    k = key(body)[1]
    chords = follows_chords(ref['full'], body, bar, bars)
    tuning = float(librosa.estimate_tuning(y=body.mean(axis=1).astype(np.float32), sr=SR)) * 100
    dens = [row['density_mean'] for row in spectral_rows(body, bar)]
    tempo = librosa.beat.beat_track(y=body.mean(axis=1).astype(np.float32), sr=SR, start_bpm=ref['bpm'], units='time')[0]
    return dict(trim_ms=round(off_ms, 2), trim_samples=off, drift_lag_ms_per_bar=lag['lag_ms_per_bar'],
                kick_median_abs_ms=round(float(np.median(np.abs(errors))), 2) if errors else None,
                kick_errors_ms=[round(e, 1) for e in errors], kick_events=len(events), kick_found=len(errors),
                missing_downbeats=missing_down, missing_other=missing,
                kick_grid_dev_median_ms=round(float(np.median(kdev)), 2) if kdev else None,
                extra_kicks_per_bar=round(len(extra) / bars, 2),
                tempo_drift_per_16_bars_ms=round(lag['slope_ms_per_bar'] * BARS, 2),
                tempo_total_drift_ms=round(lag['slope_ms_per_bar'] * bars, 2),
                open_kick_db=open_kick_db(drums, off, ref['sections']),
                librosa_bpm=round(float(np.atleast_1d(tempo)[0]), 2),
                bass_onsets=len(bass_on), bass_grid_dev_median_ms=round(float(np.median(bdev)), 2) if bdev else None,
                lock_lag_median_ms=round(float(np.median(lock_lag)), 2),
                lock_r_median=round(float(np.median(lock_r)), 3), lock_r_per_bar=[round(v, 3) for v in lock_r],
                key=k['ks_key'], key_r=k['ks_r'], dorian_d_energy=k['dorian_d_energy'],
                top_pitch_classes=k['top_pitch_classes'], follows_chords=chords, tuning_cents=round(tuning, 1),
                density_per_bar=dens, density_mean=round(float(np.mean(dens)), 3),
                density_p90=round(float(np.quantile(dens, .9)), 3), density_max=round(float(np.max(dens)), 3),
                lufs_raw=round(lufs(mix), 2))


def verdict(row, ref, b_density):
    t = THRESHOLDS
    fails = []
    if row['kick_median_abs_ms'] is None or row['kick_median_abs_ms'] > t['kick_median_ms']:
        fails.append('kick')
    if row['missing_downbeats']:
        fails.append('downbeat')
    if abs(row['tempo_drift_per_16_bars_ms']) > t['tempo_total_ms']:
        fails.append('tempo')
    if abs(row['lock_lag_median_ms']) > t['lock_lag_ms']:
        fails.append('lock')
    ch = row['follows_chords']
    if (row['dorian_d_energy'] < ref['dorian'] - t['dorian_margin']
            or ch['cover_vs_guide_mean'] <= ch['guide_vs_next_bar_mean']):
        fails.append('key')
    if row['density_mean'] > b_density['mean'] or row['density_p90'] > b_density['max']:
        fails.append('density')
    if row['open_kick_db'] is not None and row['open_kick_db'] > t['open_kick_max_db']:
        fails.append('breath')
    return fails


def reference(guides, bar, step):
    start, bars, bpm, sections = region(guides)
    kick = load(guides / 'engine-kick.wav')[start:]
    events, _ = engine_events(kick, bar, step, bars)
    full = load(guides / 'guide-full.wav')[start:start + bar * bars]
    return dict(kick=kick, events=events, full=full, dorian=key(full)[1]['dorian_d_energy'], start=start,
                bars=bars, bpm=bpm, sections=[[n, s - start, b, length] for n, s, b, length in sections])


def b_density():
    dens = [row['density_mean'] for row in spectral_rows(load(B_MIX), B_BAR)]
    return dict(mean=round(float(np.mean(dens)), 3), max=round(float(np.max(dens)), 3), per_bar=dens)


def controls(guides, run):
    """The screens' instruments on known inputs: the engine against itself, and v1's cover (B's bed)."""
    bar, n, step = grid(guides)
    ref = reference(guides, bar, step)

    def cut(path):
        return load(path)[ref['start']:]
    rows = {}
    rows['engine (guide drums vs engine kick; bass = engine sub+reese)'] = screen_take(
        cut(guides / 'guide-full.wav'), cut(guides / 'guide-drums.wav'), cut(guides / 'engine-bass.wav'), ref, bar, step, n)
    if ref['sections']:
        # A parent's positive control: its own guide through Demucs, the path every take's stems take.
        rows['engine parent guide through Demucs'] = screen_take(
            cut(guides / 'guide-full.wav'), cut(guides / 'guide-full.drums.wav'), cut(guides / 'guide-full.bass.wav'),
            ref, bar, step, n)
    else:
        rows['v1 cover (B bed, raw, Demucs stems)'] = screen_take(
            load(V1 / 'cover-spillway-raw.wav'), load(V1 / 'cover-spillway-raw.drums.wav'),
            load(V1 / 'cover-spillway-raw.bass.wav'), ref, bar, step, n)
        # Added after the sweep was screened: the same locked engine guide through Demucs, the path
        # every take's stems take. The bass grid-deviation half of the lock screen reads ~17 ms here
        # (5 ms on the clean synth bass), so on separated stems it measures Demucs smearing, not lock.
        rows['engine guide through Demucs (v1 audition stems)'] = screen_take(
            load(V1 / 'guide-spillway-16bar.wav'), load(V1 / 'guide-spillway-16bar.drums.wav'),
            load(V1 / 'guide-spillway-16bar.bass.wav'), ref, bar, step, n)
    rows['B delivered mix density'] = b_density()
    (run / 'controls.json').write_text(json.dumps(rows, indent=1))
    for k, v in rows.items():
        print(k, json.dumps({f: v.get(f) for f in ('trim_ms', 'kick_median_abs_ms', 'kick_found', 'kick_events',
              'missing_downbeats', 'kick_grid_dev_median_ms', 'extra_kicks_per_bar', 'tempo_drift_per_16_bars_ms',
              'tempo_total_drift_ms', 'open_kick_db',
              'bass_onsets', 'bass_grid_dev_median_ms', 'lock_lag_median_ms', 'lock_r_median', 'key', 'dorian_d_energy',
              'follows_chords', 'tuning_cents', 'density_mean', 'density_p90', 'density_max', 'mean', 'max')}))
    print('engine dorian_d_energy', ref['dorian'], 'verdicts', {k: verdict(v, ref, rows['B delivered mix density'])
                                                               for k, v in rows.items() if 'kick_events' in v})


def takes(run):
    out = {}
    for manifest in sorted((run / 'takes').rglob('manifest*.json')):
        for entry in json.loads(manifest.read_text()):
            for audio in entry.get('audios', []):
                out[entry['name']] = Path(audio['path'])
    return out


def vocals(run):
    """Demucs' vocals RMS per take, from the separation logs (an instrumental that grew a voice)."""
    found, current = {}, None
    for log in sorted([*(run / 'logs').glob('demucs*.log'), *(run.parent / 'logs').glob('demucs*.log')]):
        for line in log.read_text().splitlines():
            if ': separated in' in line:
                current = line.split(':')[0]
            elif line.strip().startswith('vocals:') and current:
                found[current] = float(line.split()[1])
    return found


def screen(guides, run):
    bar, n, step = grid(guides)
    ref = reference(guides, bar, step)
    dens_b = b_density()
    voc = vocals(run)
    control, withdrawn = None, []
    if (guides / 'guide-full.drums.wav').exists():
        control = screen_take(*[load(guides / f'guide-full{s}.wav')[ref['start']:] for s in ('', '.drums', '.bass')],
                              ref, bar, step, n)
        withdrawn = verdict(control, ref, dens_b)
        print('control (engine guide through Demucs) fails', withdrawn or 'nothing', '-> reported, not gated')
    rows = []
    import hashlib
    for label, path in sorted(takes(run).items()):
        stems = {s: path.with_suffix(f'.{s}.wav') for s in ('drums', 'bass', 'other')}
        if not all(p.exists() for p in stems.values()):
            print('no stems yet:', label)
            continue
        *group, s, seed = label.split('-')
        cut = [load(p)[ref['start']:] for p in (path, stems['drums'], stems['bass'])]
        row = dict(take=label, guide='-'.join(group), strength=int(s) / 100, seed=int(seed[1:]), path=str(path),
                   sha256=hashlib.sha256(path.read_bytes()).hexdigest(), **screen_take(*cut, ref, bar, step, n))
        row['vocals_rms_db'] = voc.get(str(path))
        every = verdict(row, ref, dens_b)
        row['fails'] = [f for f in every if f not in withdrawn]
        row['reported_not_gated'] = [f for f in every if f in withdrawn]
        rows.append(row)
        print(label, row['fails'] or 'PASS', row['kick_median_abs_ms'], row['missing_downbeats'],
              row['tempo_drift_per_16_bars_ms'], row['lock_lag_median_ms'], row['key'],
              row['density_mean'], row['open_kick_db'], flush=True)
    dup = {}
    for row in rows:
        dup.setdefault(row['sha256'], []).append(row['take'])
    passed = [r for r in rows if not r['fails']]
    # Fixed before screening: tightest kick median, then smallest bass-to-kick lag.
    passed.sort(key=lambda r: (r['kick_median_abs_ms'], abs(r['lock_lag_median_ms'])))
    if all(len(r['guide']) == 1 for r in rows):
        # The bed sweep: top two; if both come from one guide and another guide has a passer,
        # its best replaces the second.
        top = passed[:2]
        if len(top) == 2 and top[0]['guide'] == top[1]['guide']:
            other = [r for r in passed if r['guide'] != top[0]['guide']]
            if other:
                top[1] = other[0]
    else:
        # Parents: the top passer per parent and direction; pilot takes are never selected.
        top = []
        for r in passed:
            if not r['guide'].startswith('pilot') and r['guide'] not in [t['guide'] for t in top]:
                top.append(r)
    report = dict(thresholds=THRESHOLDS, b_density=dens_b, control=control, withdrawn_by_control=withdrawn, rows=rows, identical_audio=[v for v in dup.values() if len(v) > 1],
                  passed=[r['take'] for r in passed], finish=[r['take'] for r in top])
    (run / 'screen.json').write_text(json.dumps(report, indent=1))
    head = ('| take | guide | str | seed | trim ms | kick med ms | kicks found | missing downbeats | kick grid dev ms | '
            'extra kicks/bar | tempo drift ms /16 bars (total) | bass grid dev ms (report) | lock r | lock lag ms | key | '
            'dorian | chords cover/baseline | tuning c | density mean/p90/max | open kick dB | vocals dB | result |')
    lines = [head, '|' + '---|' * (head.count('|') - 1)]
    for r in rows:
        ch = r['follows_chords']
        lines.append(f"| {r['take']} | {r['guide']} | {r['strength']} | {r['seed']} | {r['trim_ms']} | "
                     f"{r['kick_median_abs_ms']} | {r['kick_found']}/{r['kick_events']} | {r['missing_downbeats'] or '-'} | "
                     f"{r['kick_grid_dev_median_ms']} | {r['extra_kicks_per_bar']} | "
                     f"{r['tempo_drift_per_16_bars_ms']} ({r['tempo_total_drift_ms']}) | {r['bass_grid_dev_median_ms']} | "
                     f"{r['lock_r_median']} | {r['lock_lag_median_ms']} | {r['key']} | {r['dorian_d_energy']} | "
                     f"{ch['cover_vs_guide_mean']}/{ch['guide_vs_next_bar_mean']} | {r['tuning_cents']} | "
                     f"{r['density_mean']}/{r['density_p90']}/{r['density_max']} | {r['open_kick_db']} | "
                     f"{r['vocals_rms_db']} | {' '.join(r['fails']) or 'PASS'}"
                     f"{' (reported: ' + ' '.join(r['reported_not_gated']) + ')' if r['reported_not_gated'] else ''} |")
    lines.append(f"\nGuide dorian {ref['dorian']}. Withdrawn by the control: {withdrawn or 'none'}. "
                 f"B density mean/max {dens_b['mean']}/{dens_b['max']}. "
                 f"Identical audio: {report['identical_audio']}. "
                 f"Passed: {report['passed']}. Finish: {report['finish']}.")
    (run / 'screen.md').write_text('\n'.join(lines) + '\n')
    print('\n'.join(lines[-1:]))


def master(y, path):
    """retime_slice.master's chain (-14 LUFS, true-peak limiter, Opus 96k), with the limiter
    ceiling lowered in 0.5 dB steps until the decoded Opus also sits under -1 dBTP."""
    import subprocess
    from scipy.signal import resample_poly
    sys.path.insert(0, '/home/andrew/Projects/music-video')
    from engine.dsp import true_peak_limit
    before = lufs(y)
    for ceiling in (-1.8, -2.3, -2.8, -3.3, -3.8):
        gain = -14 - before
        for _ in range(8):
            z = true_peak_limit((y * 10 ** (gain / 20)).T, ceiling_db=ceiling).T
            loud = lufs(z)
            if abs(loud + 14) < .02:
                break
            gain += -14 - loud
        sf.write(path, z, SR, subtype='PCM_24')
        opus = path.with_suffix('.opus')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(path), '-c:a', 'libopus', '-b:a', '96k', str(opus)], check=True)
        decoded = path.with_name('opus-decoded.wav')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(opus), '-ar', str(SR), str(decoded)], check=True)
        enc = load(decoded)
        tp = lambda a: round(db(np.abs(resample_poly(a, 4, 1, axis=0)).max()), 2)
        row = dict(lufs_before=round(before, 2), gain_db=round(gain, 2), lufs_after=round(loud, 2), limiter_ceiling_db=ceiling,
                   peak_dbfs=round(db(np.abs(z).max()), 2), true_peak_dbtp=tp(z),
                   opus=dict(path=str(opus), bitrate=96000, lufs=round(lufs(enc), 2), true_peak_dbtp=tp(enc)))
        if row['true_peak_dbtp'] < -1 and row['opus']['true_peak_dbtp'] < -1:
            break
    return z, row


def finish(guides, run, names):
    bar, n, step = grid(guides)
    report = json.loads((run / 'screen.json').read_text())
    rows = {r['take']: r for r in report['rows']}
    out = {}
    for label in names:
        row, path = rows[label], Path(rows[label]['path'])
        dest = run / 'finished' / label
        dest.mkdir(parents=True, exist_ok=True)
        off = row['trim_samples']
        if off < 0:
            raise SystemExit(f'{label}: negative trim {off}; the loop would start in padding')
        loops = {}
        for stem, y in [('mix', load(path)), *[(s, load(path.with_suffix(f'.{s}.wav'))) for s in ('drums', 'bass', 'other')]]:
            loops[stem] = wrap(segment(y, off, n), segment(y, off + n, XFADE))
        mastered, loud = master(loops['mix'], dest / f'{label}.wav')
        gain = 10 ** (loud['gain_db'] / 20)
        stem_rows = {}
        for s in ('drums', 'bass', 'other'):
            target = dest / f'{label}.{s}.loop.wav'
            sf.write(target, loops[s] * gain, SR, subtype='PCM_24')
            stem_rows[s] = dict(path=str(target), lufs=round(lufs(loops[s] * gain), 2), seam=seam(loops[s] * gain))
        sf.write(dest / 'loop-test.wav', np.tile(mastered, (3, 1)), SR, subtype='PCM_16')
        out[label] = dict(source=str(path), trim_samples=off, frames=len(mastered), seconds=round(len(mastered) / SR, 4),
                          master=loud, seam=seam(mastered), bands=bands(mastered), **shape(mastered, bar),
                          stems=stem_rows, stem_gain_db=loud['gain_db'],
                          note='stems carry the master gain without its limiter, for later vertical layering')
        print(label, json.dumps(dict(master=loud, seam=out[label]['seam']), indent=1), flush=True)
    (run / 'finished' / 'finish.json').write_text(json.dumps(out, indent=1))


def pack(run, dest, names):
    import hashlib
    import random
    import shutil
    items = [(label, run / 'finished' / label / f'{label}.opus') for label in names] + [('B (v1 hybrid)', B_OPUS)]
    random.SystemRandom().shuffle(items)
    dest.mkdir(parents=True, exist_ok=True)
    key_lines, manifest = [], {}
    for i, (label, src) in enumerate(items, 1):
        target = dest / f'X{i}.opus'
        shutil.copyfile(src, target)
        key_lines.append(f'X{i}={label}')
        manifest[target.name] = dict(sha256=hashlib.sha256(target.read_bytes()).hexdigest(), source=str(src))
    (dest / '.key-do-not-peek').write_text('\n'.join(key_lines) + '\n')
    (run / 'pack-manifest.json').write_text(json.dumps(dict(dest=str(dest), files=manifest), indent=1))
    print('packed', len(items), 'files to', dest)

if __name__ == '__main__':
    cmd, args = sys.argv[1], [Path(a) for a in sys.argv[2:]]
    if cmd == 'prep':
        prep(*args)
    elif cmd == 'controls':
        controls(*args)
    elif cmd == 'screen':
        screen(*args)
    elif cmd == 'finish':
        finish(args[0], args[1], [str(a) for a in args[2:]])
    elif cmd == 'pack':
        pack(args[0], args[1], [str(a) for a in args[2:]])
    else:
        sys.exit(__doc__)
