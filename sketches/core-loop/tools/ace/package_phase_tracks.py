"""Package the phase, final-phase, champion and Eurodance tracks as single-loop ACE packs.

    python package_phase_tracks.py stretch <render_root> <work_dir>
    nice -n 10 demucs -n htdemucs -d cuda -o <work_dir>/stems <work_dir>/stretched/*.wav
    python package_phase_tracks.py pack <work_dir>

The place-and-moment tunes use the same three steps, with the gapfill folder as render_root:

    python package_phase_tracks.py stretch --tunes ../../design-v3/sound/tunes.json <gapfill_dir> <work_dir>

The radio's takes are whole songs, so they pack with --whole: one clip from the first downbeat
through the last full bar, looping back to the top.

    python package_phase_tracks.py stretch --radio ../../design-v3/sound/radio_renders.json <radio_dir> <work_dir>
    python package_phase_tracks.py pack --whole <work_dir>

Each pack is assets/music_ace/<id with underscores>/manifest.json plus main.{drums,bass,other}.ogg:
one 16-bar looping clip "main", flat (ace_sequencer.gd never schedules Warden sections for it),
cut on the measured beat grid, the loop tail blended into its head like package_music.py's
cut_clip, and a uniform gain baked in so the summed stems land on -16 LUFS integrated with the
true peak under -1 dBTP (scripts/audio-gate.mjs). The Oggs are gitignored; manifest.json is
committed. The takes come from the sound bible renders (design-v3/sound/RENDERS.md picks).
"""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from package_music import RATE, PRE_ROLL, POST_ROLL, LOOP_JOIN, STEMS, SILENT_DB, PROFILES, cut_clip, encode, sha

SKETCH = Path(__file__).resolve().parents[2]
OUT = SKETCH / 'assets/music_ace'
SOUND = SKETCH / 'design-v3/sound'
BARS = 16
START_BAR = 4
START_BARS = {'landmark-penstock': 2, 'event-surge-run': 2}
TARGET_LUFS = -16.0
MAX_TP = -1.2

TRACKS = {
    'brindle-p1-requisition': ('lab-round7-1', 'brindle-p1-requisition', 2701, 138, 'D', 0),
    'brindle-p2-furnace': ('lab-round7-1', 'brindle-p2-furnace', 2702, 150, 'D', 0),
    'brindle-p3-scuttle': ('lab-round7-1', 'brindle-p3-scuttle', 2702, 172, 'D', 0),
    'waking-final': ('lab-round7-1', 'waking-final', 2702, 129, 'D', 0),
    'mind-final': ('lab-round7-1', 'mind-final', 2701, 142, 'E', 2),
    'champion-hype': ('lab-round7-1', 'champion-hype', 2702, 129, 'D', 0),
    'euro-brindle-p3': ('lab-round8-1', 'euro-brindle-p3', 2801, 172, 'D', 0),
    'euro-waking-final': ('lab-round8-1', 'euro-waking-final', 2801, 142, 'D', 0),
    'euro-mind-final': ('lab-round8-1', 'euro-mind-final', 2801, 142, 'E', 2),
    'euro-champion': ('lab-round9-1', 'euro-champion', 2901, 145, 'D', 0),
}


TUNES_JSON = SOUND / 'tunes.json'
KEY_OFFSETS = {'D': 0, 'E': 2, 'G': 5}


def tune_tracks(tunes_path=TUNES_JSON):
    out = {}
    for row in json.loads(Path(tunes_path).read_text()):
        letter = row['key'].split()[0]
        if letter not in KEY_OFFSETS:
            raise SystemExit(f"{row['id']}: key {row['key']} has no offset from D")
        out[row['id']] = (None, row['pick'], None, int(row['bpm']), letter, KEY_OFFSETS[letter])
    return out


def radio_tracks(renders_path):
    out = {}
    for row in json.loads(Path(renders_path).read_text()):
        if not row.get('takes'):
            continue
        letter = row['key'].split()[0]
        if letter not in KEY_OFFSETS:
            raise SystemExit(f"{row['id']}: key {row['key']} has no offset from D")
        out[row['id']] = (None, row.get('pick') or row['takes'][0], None, int(row['bpm']), letter, KEY_OFFSETS[letter])
    return out


def theme_of(track_id):
    return track_id.replace('-', '_')


def source_of(render_root, track_id, tracks=TRACKS):
    folder, job, seed, *_ = tracks[track_id]
    if folder is None:
        return render_root / job
    base = render_root / 'renders' / folder
    if seed is None:
        return base / job
    for row in json.loads((base / 'manifest.json').read_text()):
        if row['name'] == job:
            for audio in row['audios']:
                if audio['seed'] == seed:
                    return Path(audio['path'])
    raise SystemExit(f'{track_id}: no take {job} seed {seed}')


def mono_tempo(path, bpm, lo=0.93, hi=1.07):
    import cut_loops
    audio, sr = sf.read(path, always_2d=True)
    flux, rate = cut_loops.onset_envelope(audio.mean(axis=1), sr)
    coarse = cut_loops.tempo(flux, rate, bpm * lo, bpm * hi)
    best = None
    for t in np.arange(coarse - 0.3, coarse + 0.3, 0.01):
        lag = rate * 60 / t
        idx = np.arange(0, len(flux) - 4 * lag, lag)
        score = sum(np.mean(np.interp(idx + k * lag, np.arange(len(flux)), flux)) for k in range(4))
        if best is None or score > best[0]:
            best = (score, t)
    return best[1]


def stretch(args):
    sys.path.insert(0, str(SOUND))
    work = args.work
    (work / 'stretched').mkdir(parents=True, exist_ok=True)
    report = {}
    tracks = radio_tracks(args.radio) if args.radio else tune_tracks(args.tunes) if args.tunes else TRACKS
    at_tempo = bool(args.tunes or args.radio)
    for track_id, (_, _, _, bpm, key, key_offset) in tracks.items():
        src = source_of(args.render_root, track_id, tracks)
        measured = mono_tempo(src, bpm)
        out = work / 'stretched' / f'{theme_of(track_id)}.wav'
        if abs(measured / bpm - 1) > 0.045 and at_tempo:
            narrow = mono_tempo(src, bpm, 0.97, 1.03)
            print(f'{track_id}: wide read {measured:.2f}, narrow read {narrow:.2f}', flush=True)
            measured = narrow
        if abs(measured / bpm - 1) > 0.045:
            raise SystemExit(f'{track_id}: read {measured:.2f}, too far from {bpm}; needs an ear')
        subprocess.run(['rubberband', '-q', '--fine', '-T', f'{bpm / measured:.6f}', str(src), str(out)], check=True)
        after = mono_tempo(out, bpm)
        note = 'stretched'
        if at_tempo and abs(after / bpm - 1) > 0.01:
            import shutil
            shutil.copyfile(src, out)
            note = f'unstretched: detector unreliable (read {after:.2f} after stretching)'
            after = mono_tempo(out, bpm, 0.97, 1.03)
        report[track_id] = dict(stretch=note,source=str(src), bpm_target=bpm, bpm_before=round(measured, 3), bpm_after=round(after, 3),
                                key=key, key_offset=key_offset)
        print(track_id, report[track_id], flush=True)
    (work / 'stretch.json').write_text(json.dumps(report, indent=1))


def lufs_tp(pcm_by_stem):
    mix = sum(pcm_by_stem.values()).astype('<f4')
    out = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-f', 'f32le', '-ar', str(RATE), '-ac', '2', '-i', 'pipe:0',
                          '-af', 'ebur128=peak=true', '-f', 'null', '-'], input=mix.tobytes(), capture_output=True).stderr.decode()
    import re
    i = re.findall(r'^\s*I:\s+(-?[\d.]+)\s+LUFS', out, re.M)[-1]
    p = re.findall(r'^\s*Peak:\s+(-?[\d.]+)\s+dBFS', out, re.M)[-1]
    return float(i), float(p)


def limit(pcm, ceiling_db=-1.5):
    """One smooth gain curve from the summed stems, applied to every stem, so the sum stays
    under the ceiling and the stems keep their balance."""
    from scipy.ndimage import minimum_filter1d, uniform_filter1d
    mix = np.abs(sum(pcm.values())).max(axis=1)
    ceiling = 10 ** (ceiling_db / 20)
    want = np.minimum(1.0, ceiling / np.maximum(mix, 1e-9))
    if want.min() >= 1.0:
        return pcm
    held = minimum_filter1d(want, size=int(RATE * 0.012), mode='nearest')
    gain = uniform_filter1d(held, size=int(RATE * 0.008), mode='nearest')[:, None]
    return {s: v * gain for s, v in pcm.items()}


def read_stem(path):
    audio, sr = sf.read(path, always_2d=True)
    if sr != RATE:
        raise SystemExit(f'{path}: expected {RATE} Hz, got {sr}')
    return audio


def pack(args):
    work = args.work
    report = json.loads((work / 'stretch.json').read_text())
    sys.path.insert(0, str(SOUND))
    import cut_loops
    base = json.loads((SKETCH / 'assets/music_ace/brindle/manifest.json').read_text())
    drum_trim = json.loads(args.drum_db.read_text()) if args.drum_db else {}
    for track_id, row in report.items():
        bpm, key, key_offset = row['bpm_target'], row.get('key'), row.get('key_offset')
        if key is None:
            key, key_offset = TRACKS[track_id][4], TRACKS[track_id][5]
        theme = theme_of(track_id)
        stem_dir = work / 'stems' / 'htdemucs' / theme
        stems = {s: read_stem(stem_dir / f'{s}.wav') for s in ('drums', 'bass', 'other')}
        stems['other'] = stems['other'] + read_stem(stem_dir / 'vocals.wav')
        drum_db = drum_trim.get(track_id, 0.0)
        if drum_db:
            stems['drums'] = stems['drums'] * 10 ** (drum_db / 20)
        mix = sum(stems.values())
        flux, rate = cut_loops.onset_envelope(mix.mean(axis=1), RATE)
        beat = round(RATE * 60 / bpm)
        bar = beat * 4
        head = round(cut_loops.phase(flux, rate, bpm) * RATE)
        fit = None
        if args.whole:
            whole_bars = (len(mix) - head - POST_ROLL) // bar
            if whole_bars < BARS // 2:
                raise SystemExit(f'{track_id}: take too short for a whole-song pack at {bpm}')
            fit = (whole_bars, 0)
        for bars in () if fit else (BARS, BARS // 2):
            for start_bar in range(START_BARS.get(track_id, START_BAR), -1, -1):
                if head + start_bar * bar + bars * bar + POST_ROLL <= len(mix):
                    fit = (bars, start_bar)
                    break
            if fit:
                break
        if fit is None:
            raise SystemExit(f'{track_id}: take too short for {BARS // 2} bars at {bpm}')
        bars, start_bar = fit
        frames = bars * bar
        start = head + start_bar * bar
        state = dict(source_start=start, frames=frames)
        clips = {s: cut_clip(stems[s], state, 0, 1, bar) for s in STEMS}
        pcm = {s: c[0] for s, c in clips.items()}
        loop_offset = clips['drums'][1]
        gain_db = 0.0
        for _ in range(6):
            i, p = lufs_tp(limit({s: v * 10 ** (gain_db / 20) for s, v in pcm.items()}, args.ceiling))
            want = TARGET_LUFS - i
            if abs(want) < 0.05:
                break
            gain_db += want
        scaled = limit({s: v * 10 ** (gain_db / 20) for s, v in pcm.items()}, args.ceiling)
        i, p = lufs_tp(scaled)
        folder = OUT / theme
        folder.mkdir(parents=True, exist_ok=True)
        files = {}
        for s, v in scaled.items():
            name = f'main.{s}.ogg'
            encode(v, folder / name)
            files[s] = name
        count = len(pcm['drums'])
        manifest = dict(
            format=1, theme=theme, bank='single', flat=True, rate=RATE, key=key, key_offset=key_offset, stems=list(STEMS),
            level_db=0.0, pre_roll=PRE_ROLL, post_roll=POST_ROLL, loop_join=LOOP_JOIN, join_ms=10.0, silent_db=SILENT_DB,
            sources={'main': dict(take=str(Path(report[track_id]['source']).name), source=report[track_id]['source'],
                                  stretched=str(work / 'stretched' / f'{theme}.wav'),
                                  bpm_before=report[track_id]['bpm_before'], bpm_after=report[track_id]['bpm_after'],
                                  stems={s: dict(path=str(stem_dir / f'{s}.wav'), sha256=sha(stem_dir / f'{s}.wav')) for s in ('drums', 'bass', 'other', 'vocals')},
                                  note='htdemucs; vocals summed into other')},
            clips=dict(main=dict(
                parent='single', take=track_id, source_start=start, take_start=start, bpm=bpm, beat=beat, bar=bar,
                beats_per_bar=4, bars=bars, entry=PRE_ROLL, exit=PRE_ROLL + frames, loop=True, loop_offset=loop_offset,
                loop_to_bar=1, sample_count=count, key=key, key_offset=key_offset, files=files)),
            sections=dict(main=dict(clip='main', game=track_id, enter='bar', phase='start', profile='full')),
            set_piece=[], profiles=PROFILES, breath=base['breath'], breath_default='hard',
            cuts='measured-beat-phase', whole=bool(args.whole), timing_verified=False, gain_db=round(gain_db, 2),
            measured=dict(lufs=i, true_peak=p, note='summed stems before Ogg encode'))
        if drum_db:
            manifest['drum_trim_db'] = drum_db
        (folder / 'manifest.json').write_text(json.dumps(manifest, indent=1) + '\n')
        print(f'{track_id}: {bars} bars from bar {start_bar} at {bpm}, gain {gain_db:+.2f} dB, {i:.2f} LUFS, {p:.2f} dBFS', flush=True)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest='cmd', required=True)
    s = sub.add_parser('stretch')
    s.add_argument('render_root', type=Path)
    s.add_argument('work', type=Path)
    s.add_argument('--tunes', type=Path, help='package the picks of this tunes.json; render_root is the folder holding them')
    s.add_argument('--radio', type=Path, help='package the takes of this radio_renders.json; render_root is the radio folder')
    p = sub.add_parser('pack')
    p.add_argument('work', type=Path)
    p.add_argument('--whole', action='store_true', help='one clip spanning the whole take (radio songs), not a 16-bar loop')
    p.add_argument('--drum-db', type=Path, help='JSON {track id: dB} trimming the drum stem before the level is set (percussion serves the song)')
    p.add_argument('--ceiling', type=float, default=-1.5,
                   help='limiter ceiling in dBFS; the tunes use -2.2 so the Ogg encode stays under -1 dBTP')
    args = ap.parse_args()
    return stretch(args) if args.cmd == 'stretch' else pack(args)


if __name__ == '__main__':
    sys.exit(main())
