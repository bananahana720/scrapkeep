#!/usr/bin/env python3
"""Packages the Spillway ACE music for the runtime sequencer (src/presentation/ace_sequencer.gd).

    python3 sketches/core-loop/tools/ace/package_music.py [--warden s42|s7] [--slice <slice0 dir>]

Reads the Slice 0 takes, their Demucs stems and the round-2 automation, cuts one clip per
section and stem, encodes each as 44.1 kHz Ogg Vorbis into assets/music_ace/spillway/ and
writes manifest.json beside them. The Oggs are gitignored; the manifest is committed, so a
checkout without the audio still names every file the runtime needs and falls back to the
synth engine when one is missing.

Sources, fixed by Andrew's blind pack 3 verdict (all three tracks liked, Y3 the favourite):
  calm    calm-F-085-s1001, the calm of every pack-3 track
  warden  warden-F-085-s42, Y3's Warden (--warden s7 swaps in pack 3's other Warden take)
The take trims are the ones pack 3 cut with (round2/assemble.json, round2/pack4/excerpts.json).

Clip layout, per stem: PRE_ROLL frames of the take before the section's first sample (zeros
before the take's start), the section, then POST_ROLL frames of the take for one-shots. A
looping clip ends on its loop end, and its last LOOP_JOIN frames are baked as slice0's 10 ms
equal-power join into the audio that precedes the loop target in the take, so a native wrap
to loop_offset continues the performance instead of splicing it.
"""
import argparse
import hashlib
import json
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100
PRE_ROLL = 4096
POST_ROLL = 1024
LOOP_JOIN = 441
STEMS = ('drums', 'bass', 'other')
SILENT_DB = -80.0
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from repage import PAGE_USEC
SKETCH = HERE.parents[1]
OUT = SKETCH / 'assets' / 'music_ace' / 'spillway'
SLICE = Path('/home/andrew/Projects/scrapkeep-worktrees/core-loop-v3-audio-3/artifacts/local/v3-audio/slice0')
WARDEN_TAKES = {'s42': 'warden-F-085-s42', 's7': 'warden-F-085-s7'}
CALM_TAKE = 'calm-F-085-s1001'
LEVEL_DB = 4.0

CLIPS = {
    'calm': ('calm', 'calm', 1),
    'travel': ('calm', 'travel', 1),
    'pivot': ('warden', 'pivot', None),
    'build': ('warden', 'warden-1:build', 9),
    'telegraph': ('warden', 'warden-1:telegraph', 1),
    'open': ('warden', 'warden-1:open', 1),
    'drop': ('warden', 'warden-1:drop', None),
    'cadence': ('warden', 'return', None),
}

SECTIONS = {
    'calm': dict(clip='calm', game='shelf, closed Warden, pressure low', enter='bar', phase='start', profile='full'),
    'travel': dict(clip='travel', game='shelf, pressure up', enter='bar', phase='start', profile='full'),
    'pivot': dict(clip='pivot', game='the drop-line commit: 172 into 129', enter='bar', phase='start', profile='full',
                  hold_bars=1, then='build'),
    'build': dict(clip='build', game='bank and lift, the Warden closed', enter='bar', phase='start', profile='full',
                  reenter_bar=9),
    'telegraph': dict(clip='telegraph', game='the pulse charging', enter='beat', phase='keep', profile='full'),
    'open': dict(clip='open', game='window open, the held breath', enter='beat', phase='keep', profile='breath'),
    'drop': dict(clip='drop', game='landed on the core', enter='contact', phase='start', profile='full',
                 hold_bars=1, then='follow'),
    'break': dict(clip='open', game='the Warden breaks: breath before home', enter='bar', phase='start',
                  profile='breath', bars=4, then='return', directed=True),
    'return': dict(clip='cadence', game='kill cadence, A7b9 then D', enter='then', phase='start', profile='full',
                   then='home', directed=True),
    'home': dict(clip='calm', game='back on the shelf at 172', enter='then', phase='start', profile='full', bars=8,
                 then='release', directed=True),
}
SET_PIECE = ['break', 'return', 'home']
PROFILES = {
    'full': {s: dict(volume_db=0.0, lowpass_hz=None) for s in STEMS},
    'lounge': dict(drums=dict(volume_db=-12.0, lowpass_hz=None), bass=dict(volume_db=-4.0, lowpass_hz=None),
                   other=dict(volume_db=0.0, lowpass_hz=None)),
}


def read_wav(path):
    with wave.open(str(path), 'rb') as w:
        if w.getframerate() != RATE or w.getnchannels() != 2 or w.getsampwidth() != 2:
            raise SystemExit(f'{path}: expected 44.1 kHz 16-bit stereo')
        data = np.frombuffer(w.readframes(w.getnframes()), dtype='<i2')
    return data.reshape(-1, 2).astype(np.float64) / 32768.0


def segment(y, start, length):
    """length frames of y from start, zeros where the range leaves the take."""
    out = np.zeros((length, 2))
    lo, hi = max(start, 0), min(start + length, len(y))
    if hi > lo:
        out[lo - start:hi - start] = y[lo:hi]
    return out


def encode(pcm, path):
    ints = np.clip(np.round(pcm * 32767.0), -32768, 32767).astype('<i2')
    cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-f', 's16le', '-ar', str(RATE), '-ac', '2',
           '-i', 'pipe:0', '-c:a', 'libvorbis', '-q:a', '6', '-fflags', '+bitexact', '-flags:a', '+bitexact',
           '-map_metadata', '-1', '-page_duration', str(PAGE_USEC), str(path)]
    subprocess.run(cmd, input=ints.tobytes(), check=True)


def stems_of(take_dir, take):
    found = {}
    for stem in STEMS:
        hits = sorted((take_dir / take).glob(f'*.{stem}.wav'))
        if len(hits) != 1:
            raise SystemExit(f'{take_dir / take}: expected one *.{stem}.wav, found {len(hits)}')
        found[stem] = hits[0]
    return found


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def trims(slice_dir, warden_take):
    planted = json.loads((slice_dir / 'round2/assemble.json').read_text())['planted']['takes']
    found = {'calm': int(planted['calm']['trim_samples'])}
    if planted['calm']['take'] != CALM_TAKE:
        raise SystemExit(f"pack 3's planted calm is {planted['calm']['take']}, not {CALM_TAKE}")
    tracks = json.loads((slice_dir / 'round2/pack4/excerpts.json').read_text())['tracks']
    for row in tracks.values():
        if row['take'] == warden_take:
            found['warden'] = int(row['trim_samples'])
    if 'warden' not in found:
        raise SystemExit(f'no trim for {warden_take} in round2/pack4/excerpts.json')
    return found


def gains_of(auto):
    stems = {}
    for s in STEMS:
        row = auto['stems'][s]
        stems[s] = dict(volume_db=float(row['volume_db']), lowpass_hz=row.get('lowpass_hz'),
                        lowpass_order=int(row.get('lowpass_order', 2)) if row.get('lowpass_hz') else None)
    return stems


def breath(slice_dir):
    hard = json.loads((slice_dir / 'round2/automation/open.json').read_text())
    gentle = json.loads((slice_dir / 'round2/automation/open-gentle.json').read_text())
    return {
        'raw': dict(stems={s: dict(volume_db=0.0, lowpass_hz=None, lowpass_order=None) for s in STEMS},
                    ramp_in_ms=8.0, ramp_out_ms=8.0, source='the take as ACE played it: every stem at 0 dB'),
        'hard': dict(stems=gains_of(hard), ramp_in_ms=float(hard['ramp']['ms']), ramp_out_ms=float(hard['ramp']['ms']),
                     source='round2/automation/open.json'),
        'gentle': dict(stems=gains_of(gentle), ramp_in_ms=float(gentle['ramp']['in_ms']),
                       ramp_out_ms=float(gentle['ramp']['out_ms']), source='round2/automation/open-gentle.json'),
    }


def cut_clip(stem_audio, state, trim, loop_bar, bar):
    """The clip for one stem: pre-roll, the section, and a post-roll or a baked loop join."""
    start = trim + state['source_start']
    frames = state['frames']
    if loop_bar is None:
        return segment(stem_audio, start - PRE_ROLL, PRE_ROLL + frames + POST_ROLL), None
    clip = segment(stem_audio, start - PRE_ROLL, PRE_ROLL + frames)
    target = start + (loop_bar - 1) * bar
    lead = segment(stem_audio, target - LOOP_JOIN, LOOP_JOIN)
    theta = np.linspace(0.0, np.pi / 2.0, LOOP_JOIN)[:, None]
    clip[-LOOP_JOIN:] = clip[-LOOP_JOIN:] * np.cos(theta) + lead * np.sin(theta)
    return clip, PRE_ROLL + (loop_bar - 1) * bar


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--warden', choices=sorted(WARDEN_TAKES), default='s42')
    ap.add_argument('--slice', type=Path, default=SLICE)
    ap.add_argument('--render', type=Path, help='new track render folder; preserves Spillway')
    ap.add_argument('--stems', type=Path, help='htdemucs stem root for a new track')
    ap.add_argument('--cuts', type=Path, help='measured take/source_start rows keyed by render job')
    ap.add_argument('--nominal', action='store_true', help='provisional authored guard-bar cuts')
    ap.add_argument('--seed', type=int, help='select a render seed instead of the first authored seed')
    ap.add_argument('--bank', help='base, phase1 or menu bank')
    args = ap.parse_args()
    if args.render:
        from package_render_music import package_render
        return package_render(args)
    if args.stems or args.cuts or args.nominal or args.seed is not None or args.bank:
        ap.error('new-track options require --render')
    slice_dir = args.slice
    warden_take = WARDEN_TAKES[args.warden]
    plan = json.loads((slice_dir / 'timeline.json').read_text())
    by_state = {s['state']: s for s in plan['states']}
    trim = trims(slice_dir, warden_take)
    takes = {'calm': (slice_dir / 'run/calm/takes' / CALM_TAKE, CALM_TAKE),
             'warden': (slice_dir / 'run/warden/takes' / warden_take, warden_take)}
    paths = {p: stems_of(d, t) for p, (d, t) in takes.items()}
    audio = {p: {s: read_wav(f) for s, f in stems.items()} for p, stems in paths.items()}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT.parents[0] / '.gdignore').write_text('')
    clips = {}
    for cid, (parent, state_name, loop_bar) in CLIPS.items():
        st = by_state[state_name]
        first, last = (int(v) for v in st['bars'].split('-'))
        bars = last - first + 1
        bar = st['frames'] // bars
        if bar * bars != st['frames']:
            raise SystemExit(f'{state_name}: {st["frames"]} frames is not {bars} whole bars')
        files = {}
        count = None
        loop_offset = None
        for stem in STEMS:
            pcm, loop_offset = cut_clip(audio[parent][stem], st, trim[parent], loop_bar, bar)
            name = f'{cid}.{stem}.ogg'
            encode(pcm, OUT / name)
            files[stem] = name
            count = len(pcm)
        clips[cid] = dict(
            parent=parent, take=takes[parent][1], source_state=state_name, source_bars=st['bars'],
            source_start=st['source_start'], take_start=trim[parent] + st['source_start'], bpm=st['bpm'],
            beat=bar // 4, bar=bar, beats_per_bar=4, bars=bars, entry=PRE_ROLL, exit=PRE_ROLL + st['frames'],
            loop=loop_bar is not None, loop_offset=loop_offset if loop_offset is not None else 0,
            loop_to_bar=loop_bar, sample_count=count, key='D', key_offset=0, files=files)
        print(f'{cid}: {bars} bars at {st["bpm"]} from {state_name}, {count} frames'
              + (f', loops to bar {loop_bar}' if loop_bar else ', one-shot'), flush=True)
    build_loop = json.loads((slice_dir / 'round2/automation/build.json').read_text())['loop']
    if args.warden == 's42':
        build_loop['reason'] = "Bars 9 to 16 loop on warden-F-085-s42 (the packaged take). Measured on its packaged build clip (fix round 2, scratchpad/acemusic-fix2/seam_s42.py): the native 16 -> 9 wrap's join step is 26.3 dB under the loop's own 99.9th-percentile step, and its kick lands 10.2 ms off the grid across the join (an ordinary bar boundary reads 13.1 ms in the same measure). warden-F-085-s7's 16 -> 1 wrap read 17.4 ms in pack 3's screen, which is why the loop never targets bar 1."
    manifest = dict(
        format=1, theme='spillway', rate=RATE, key='D', key_offset=0, stems=list(STEMS), level_db=LEVEL_DB,
        pre_roll=PRE_ROLL, post_roll=POST_ROLL, loop_join=LOOP_JOIN, join_ms=10.0, silent_db=SILENT_DB,
        sources={p: dict(take=takes[p][1], trim_samples=trim[p],
                         stems={s: dict(path=str(f), sha256=sha(f)) for s, f in paths[p].items()}) for p in paths},
        timeline=str(slice_dir / 'timeline.json'),
        clips=clips, sections=SECTIONS, set_piece=SET_PIECE, profiles=PROFILES, breath=breath(slice_dir),
        breath_default='hard',
        build_loop=build_loop,
    )
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=1) + '\n')
    print('wrote', OUT / 'manifest.json', 'and', sum(len(c['files']) for c in clips.values()), 'Oggs')


if __name__ == '__main__':
    sys.exit(main())
