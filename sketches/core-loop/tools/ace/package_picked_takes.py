#!/usr/bin/env python3
"""Packages the sound-bible picked takes as music_ace themes (SOUND-INT, INTEGRATION section 7 item 1).

    python tools/ace/package_picked_takes.py prep   <work dir>
    python tools/ace/package_picked_takes.py package <work dir>

Run with an interpreter that has numpy and soundfile (the ACE-Step venv does). `prep` writes
each pick as a 44.1 kHz stereo WAV on the house grid, time-stretching titles A and B (127.0 and
128.0 measured) onto 129 and title C (172.1) onto 172 with Rubber Band. The roam, boss and camp
picks are the grid-stretched WAVs of design-v3/sound/RENDERS.md as they are. The caller then splits
every <work>/src/<theme>.wav with htdemucs into <work>/stems/htdemucs/<theme>/ (drums, bass,
other, vocals); `package` folds the vocals stem into other (an instrumental render keeps its sax
lead there, and the lead fader reads other), cuts three clips per theme and writes
assets/music_ace/<theme>/manifest.json beside their Oggs. The Oggs are gitignored; the manifest is
committed.

Clip layout, the menu bank's: calm is bars 5 to 20 of the take, travel bars 21 to 36, cadence the
last two whole bars, all counted from the take's measured downbeat. The downbeat is found from the
drums stem (beat phase) and the bass stem (which beat of the bar carries the most bass), so the cuts
are nominal: nobody has listened to a seam. Every manifest says so (timing_verified false).
"""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from package_music import (RATE, PRE_ROLL, POST_ROLL, LOOP_JOIN, STEMS, SILENT_DB, SECTIONS, SET_PIECE,
                           PROFILES, cut_clip, encode, sha)
import package_render_music

SKETCH = HERE.parents[1]
BIBLE = Path.home() / 'Music/Scrapkeep-sound-direction/sound-bible-2026-10-16/renders'
KEYS = package_render_music.KEYS
G172 = BIBLE / 'lab-round5-1/grid172'
G129 = BIBLE / 'lab-round4-1/grid129'

PICKS = {
    'title_a': (BIBLE / 'sketch-1/title-a-sax-noir/f91247ea-1d1c-c226-cecc-5635e9a422e4.wav', 127.0, 129, 'D', 'title A, sax noir (s2101)'),
    'title_b': (BIBLE / 'sketch-1/title-b-machine-lead/c955043f-d642-ce30-90b2-116687ac3989.wav', 128.0, 129, 'D', 'title B, machine lead (s2101)'),
    'title_c': (BIBLE / 'lab-round3-1/title-c2-show-opening/1132a7ef-e5bf-63ca-6a7e-2635f35641ca.wav', 172.1, 172, 'D', 'title C, show opening (s2301, Andrew picked)'),
    'roam_spillway': (G172 / 'roam-spillway-s2501-172bpm.wav', 172, 172, 'D', 'Spillway roaming (s2501)'),
    'roam_dig': (G172 / 'roam-dig-s2501-172bpm.wav', 172, 172, 'E', 'the Dig roaming (s2501)'),
    'roam_highdraft': (G172 / 'roam-highdraft-s2501-172bpm.wav', 172, 172, 'G', 'Highdraft roaming (s2501, tempo reads 166.65 then 177.4: needs an ear)'),
    'boss_brindle': (G129 / 'boss-brindle-s2402-129bpm.wav', 129, 129, 'D', "Brindle's theme (s2402)"),
    'boss_waking': (G129 / 'boss-waking-s2401-129bpm.wav', 129, 129, 'E', "the Waking's theme (s2401)"),
    'boss_mind': (G129 / 'boss-mind-s2402-129bpm.wav', 129, 129, 'G', "the Mind's theme (s2402)"),
    'camp': (BIBLE / 'lab-round5-1/grid129/camp-s2502-129bpm.wav', 129, 129, 'D', 'camp (s2502)'),
}
BAR_CLIPS = {'calm': (5, 16, 1), 'travel': (21, 16, 1)}
CADENCE_BARS = 2


def named(path):
    """A committed manifest never holds a home path: a file under a known root is written as
    'root:relative/path' (sound-bible: the sound-bible render folder, scratch: ~/scratch)."""
    roots = {'sound-bible': BIBLE.parent, 'scratch': Path.home() / 'scratch'}
    for name, root in roots.items():
        try:
            return f'{name}:{Path(path).resolve().relative_to(root)}'
        except ValueError:
            continue
    raise SystemExit(f'{path}: under no named source root')


def prep(work):
    (work / 'src').mkdir(parents=True, exist_ok=True)
    for theme, (source, measured, grid, _key, _what) in PICKS.items():
        out = work / 'src' / f'{theme}.wav'
        stretched = work / 'src' / f'{theme}.stretched.wav'
        src = source
        if abs(measured / grid - 1) > 0.0005:
            subprocess.run(['rubberband', '-q', '--fine', '-T', f'{grid / measured:.5f}', str(source), str(stretched)], check=True)
            src = stretched
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(src), '-ar', str(RATE), '-ac', '2',
                        '-c:a', 'pcm_s16le', str(out)], check=True)
        print(f'prep {theme}: {out} ({"stretched " + format(grid / measured, ".5f") if src == stretched else "as is"})', flush=True)


def onset_envelope(y, hop):
    """Half-wave-rectified rise of the short-time RMS, one value per hop."""
    n = len(y) // hop
    rms = np.sqrt((y[:n * hop].reshape(n, hop) ** 2).mean(axis=1))
    return np.maximum(np.diff(rms, prepend=rms[0]), 0.0)


def downbeat(drums, bass, beat, bar):
    """The sample offset of the take's first bar line. Beat phase from the drums onsets, then the
    beat of the bar that carries the most bass onset."""
    hop = 128
    de = onset_envelope(drums.mean(axis=1), hop)
    best, best_score = 0, -1.0
    for off in range(0, beat, hop):
        idx = np.arange(off // hop, len(de), beat / hop).astype(int)
        score = float(de[idx[idx < len(de)]].sum())
        if score > best_score:
            best, best_score = off, score
    be = onset_envelope(bass.mean(axis=1), hop)
    pick, pick_score = 0, -1.0
    for j in range(4):
        start = best + j * beat
        idx = np.arange(start / hop, len(be), bar / hop).astype(int)
        score = float(be[idx[idx < len(be)]].sum())
        if score > pick_score:
            pick, pick_score = j, score
    return best + pick * beat


def read_stem(path):
    y, sr = sf.read(path, always_2d=True)
    if sr != RATE or y.shape[1] != 2:
        raise SystemExit(f'{path}: expected 44.1 kHz stereo, got {sr} Hz x {y.shape[1]}')
    return y.astype(np.float64)


def package(work):
    reference = json.loads((SKETCH / 'assets/music_ace/spillway/manifest.json').read_text())
    for theme, (source, measured, grid, key, what) in PICKS.items():
        stem_dir = work / 'stems/htdemucs' / theme
        stems = {s: read_stem(stem_dir / f'{s}.wav') for s in ('drums', 'bass', 'other', 'vocals')}
        other = stems['other'] + stems['vocals']
        peak = float(np.abs(other).max())
        if peak > 1.0:
            other = other / peak
        audio = {'drums': stems['drums'], 'bass': stems['bass'], 'other': other}
        beat = round(RATE * 60 / grid)
        bar = beat * 4
        length = min(len(v) for v in audio.values())
        d = downbeat(stems['drums'], stems['bass'], beat, bar)
        whole = (length - d) // bar
        out = SKETCH / 'assets/music_ace' / theme
        out.mkdir(parents=True, exist_ok=True)
        clips, sources = {}, {}
        plan = {cid: (first, bars, loop_bar) for cid, (first, bars, loop_bar) in BAR_CLIPS.items()}
        plan['cadence'] = (whole - CADENCE_BARS + 1, CADENCE_BARS, None)
        for cid, (first, bars, loop_bar) in plan.items():
            if first + bars - 1 > whole or first < 1:
                raise SystemExit(f'{theme}/{cid}: bars {first}-{first + bars - 1} do not fit {whole} whole bars')
            start = d + (first - 1) * bar
            state = dict(source_start=start, frames=bars * bar)
            files, count, offset = {}, 0, 0
            for stem in STEMS:
                pcm, loop_offset = cut_clip(audio[stem], state, 0, loop_bar, bar)
                name = f'{cid}.{stem}.ogg'
                encode(pcm, out / name)
                files[stem] = name
                count = len(pcm)
                offset = loop_offset or 0
            clips[cid] = dict(parent='picked', take=theme, source_state=cid, source_bars=f'{first}-{first + bars - 1}',
                              source_start=start, take_start=start, bpm=grid, beat=beat, bar=bar, beats_per_bar=4,
                              bars=bars, entry=PRE_ROLL, exit=PRE_ROLL + bars * bar, loop=loop_bar is not None,
                              loop_offset=offset, loop_to_bar=loop_bar, sample_count=count, key=key,
                              key_offset=KEYS[key], files=files)
            sources[cid] = dict(take=theme, render=named(source), pick=what, trim_samples=start,
                                timing='downbeat measured from the drums and bass stems, never heard: unverified',
                                stems={s: dict(path=named(stem_dir / f'{s}.wav'), sha256=sha(stem_dir / f'{s}.wav'))
                                       for s in ('drums', 'bass', 'other', 'vocals')},
                                other_stem='other plus vocals, scaled to peak 1 if over')
            print(f'{theme}/{cid}: bars {first}-{first + bars - 1} at {grid}, downbeat {d}, {count} frames', flush=True)
        sections = {k: dict(v) for k, v in SECTIONS.items()}
        for section, cid in dict(pivot='cadence', build='calm', telegraph='calm', open='calm', drop='cadence',
                                 **{'break': 'calm'}).items():
            sections[section]['clip'] = cid
        sections['pivot']['game'] = 'boss or Warden entry'
        sections['build']['reenter_bar'] = 1
        sections['return'].pop('then', None)
        sections['return']['then'] = 'home'
        manifest = dict(format=1, theme=theme, bank='menu', rate=RATE, key=key, key_offset=KEYS[key], stems=list(STEMS),
                        level_db=0.0, pre_roll=PRE_ROLL, post_roll=POST_ROLL, loop_join=LOOP_JOIN, join_ms=10.0,
                        silent_db=SILENT_DB, sources=sources, clips=clips, sections=sections, set_piece=SET_PIECE,
                        profiles=PROFILES, breath=reference['breath'], breath_default='hard',
                        cuts='nominal-unverified', timing_verified=False)
        (out / 'manifest.json').write_text(json.dumps(manifest, indent=1) + '\n')
        print(f'wrote {out}/manifest.json', flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('step', choices=['prep', 'package'])
    ap.add_argument('work', type=Path)
    args = ap.parse_args()
    (prep if args.step == 'prep' else package)(args.work.resolve())


if __name__ == '__main__':
    main()
