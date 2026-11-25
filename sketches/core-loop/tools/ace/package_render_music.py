"""Package a generated render bank without changing the accepted Spillway package.

Cuts JSON maps job names to {take, source_start}, in 44.1 kHz samples. Explicit
--nominal instead uses the first seed and the authored four guard bars. Such a
package records provisional timing and requires source-grid/listening approval.
"""
import copy
import json
import subprocess
from pathlib import Path

import numpy as np

from package_music import (RATE, PRE_ROLL, POST_ROLL, LOOP_JOIN, STEMS, SILENT_DB,
                           SKETCH, SECTIONS, SET_PIECE, PROFILES, cut_clip, encode, sha)

BODY_BARS = dict(calm=16, travel=16, pivot=1, build=16, telegraph=4, open=4, drop=4, cadence=2)
KEYS = {'C': -2, 'Db': -1, 'D': 0, 'Eb': 1, 'E': 2, 'F': 3, 'Gb': 4, 'G': 5, 'Ab': 6, 'A': 7, 'Bb': 8, 'B': 9}


def read_stem(path):
    info = json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-select_streams', 'a:0', '-show_entries',
        'stream=sample_rate,channels', '-of', 'json', str(path)]))['streams'][0]
    if int(info['sample_rate']) != RATE or info['channels'] != 2:
        raise SystemExit(f'{path}: expected 44.1 kHz stereo')
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path),
                                   '-f', 'f64le', '-acodec', 'pcm_f64le', 'pipe:1'])
    return np.frombuffer(raw, dtype='<f8').reshape(-1, 2)


def package_render(args):
    render = args.render.resolve()
    track = render.name
    if track == 'spillway' or track not in {
            'cable_reach', 'dig_upper', 'dig_deep', 'highdraft', 'highdraft_crown',
            'brindle', 'waking', 'mind', 'title', 'summary'}:
        raise SystemExit(f'unsupported new track: {track}')
    plan_path = render.parents[1] / 'jobs' / f'{track}.json'
    plan = json.loads(plan_path.read_text())
    renders = {r['name']: r for r in json.loads((render / 'manifest.json').read_text())}
    bank = args.bank or ('menu' if track in {'title', 'summary'} else
                         'phase1' if track in {'brindle', 'waking', 'mind'} else 'base')
    if bank not in plan['_composition']['banks']:
        raise SystemExit(f'{track}: no bank {bank}')
    if not args.cuts and not args.nominal:
        raise SystemExit('measured --cuts JSON required; --nominal explicitly marks provisional guard-bar cuts')
    cuts = json.loads(args.cuts.read_text()) if args.cuts else {}
    stem_dir = args.stems or render.parents[1] / 'stems' / 'htdemucs'
    selected = []
    for job in plan['jobs']:
        name = job['name']
        if bank != 'menu' and not name.startswith(bank + '-'):
            continue
        cid = name if bank == 'menu' else name.removeprefix(bank + '-')
        row = renders.get(name)
        if not row or not row['success']:
            raise SystemExit(f'{track}/{name}: missing successful render')
        cut = cuts.get(name, {})
        take = cut.get('take')
        candidates = [a for a in row['audios'] if
                      (Path(a['path']).stem == take if take else
                       a['seed'] == (args.seed if args.seed is not None else job['seeds'][0]))]
        if len(candidates) != 1:
            raise SystemExit(f'{name}: expected one selected take, found {len(candidates)}')
        audio = candidates[0]
        take = Path(audio['path']).stem
        bpm = int(job['params']['bpm'])
        beat = round(RATE * 60 / bpm)
        bar = beat * 4
        bars = 3 if track == 'summary' and cid == 'cadence' else BODY_BARS[cid]
        start = int(cut['source_start']) if 'source_start' in cut else 4 * bar
        if not args.nominal and 'source_start' not in cut:
            raise SystemExit(f'{name}: measured source_start missing')
        if start < PRE_ROLL:
            raise SystemExit(f'{name}: source_start lacks decoder pre-roll')
        paths = {s: stem_dir / take / f'{take}.{s}.wav' for s in STEMS}
        for f in paths.values():
            if not f.is_file():
                raise SystemExit(f'missing Demucs stem: {f}; coordinator must run separation')
        selected.append((cid, job, audio, start, beat, bar, bars, paths))
    expected = {'calm', 'travel', 'cadence'} if bank == 'menu' else set(BODY_BARS)
    if {r[0] for r in selected} != expected:
        raise SystemExit(f'{track}/{bank}: incomplete clip set')
    out = SKETCH / 'assets/music_ace' / track
    if bank not in {'base', 'phase1', 'menu'}:
        raise SystemExit('this unit emits only the top-level base, phase1 or menu bank')
    out.mkdir(parents=True, exist_ok=True)
    clips, sources = {}, {}
    for cid, job, audio, start, beat, bar, bars, paths in selected:
        loop_bar = 9 if cid == 'build' else 1 if cid in {'calm', 'travel', 'telegraph', 'open'} else None
        state = dict(source_start=start, frames=bars * bar)
        files = {}
        for stem, f in paths.items():
            y = read_stem(f)
            if len(y) < start + state['frames'] + (POST_ROLL if loop_bar is None else 0):
                raise SystemExit(f'{f}: too short for {bars} bars at {job["params"]["bpm"]}')
            pcm, offset = cut_clip(y, state, 0, loop_bar, bar)
            filename = f'{cid}.{stem}.ogg'
            encode(pcm, out / filename)
            files[stem] = filename
        key = job['params']['keyscale'].split()[0]
        clips[cid] = dict(parent=bank, take=Path(audio['path']).stem, source_state=job['name'],
                          source_bars=f'5-{4+bars}', source_start=start, take_start=start,
                          bpm=job['params']['bpm'], beat=beat, bar=bar, beats_per_bar=4, bars=bars,
                          entry=PRE_ROLL, exit=PRE_ROLL + state['frames'], loop=loop_bar is not None,
                          loop_offset=offset or 0, loop_to_bar=loop_bar, sample_count=len(pcm),
                          key=key, key_offset=KEYS[key], files=files)
        sources[cid] = dict(take=Path(audio['path']).stem, seed=audio['seed'],
                            render=audio['path'], trim_samples=start,
                            timing='authored guard-bar target, unverified' if args.nominal else 'supplied measured cut',
                            stems={s: dict(path=str(f), sha256=sha(f)) for s, f in paths.items()})
        print(f'{track}/{cid}: {bars} bars @ {job["params"]["bpm"]}, {len(pcm)/RATE:.6f}s, loop {offset or 0}->{len(pcm)}' if loop_bar else
              f'{track}/{cid}: {bars} bars @ {job["params"]["bpm"]}, {len(pcm)/RATE:.6f}s, one-shot', flush=True)
    reference = json.loads((SKETCH / 'assets/music_ace/spillway/manifest.json').read_text())
    sections = copy.deepcopy(SECTIONS)
    sections['pivot']['game'] = 'boss or Warden entry'
    if bank == 'menu':
        for section, cid in dict(pivot='cadence', build='calm', telegraph='calm',
                                 open='calm', drop='cadence', **{'break': 'calm'}).items():
            sections[section]['clip'] = cid
        sections['build']['reenter_bar'] = 1
        sections['return'].pop('then', None)
        sections['return']['then'] = 'home'
    key = plan['_composition']['banks'][bank]['key']
    manifest = dict(format=1, theme=track, bank=bank, rate=RATE, key=key, key_offset=KEYS[key],
                    stems=list(STEMS), level_db=0.0, pre_roll=PRE_ROLL, post_roll=POST_ROLL,
                    loop_join=LOOP_JOIN, join_ms=10.0, silent_db=SILENT_DB,
                    sources=sources, clips=clips, sections=sections, set_piece=SET_PIECE,
                    profiles=PROFILES, breath=reference['breath'], breath_default='hard',
                    cuts='nominal-unverified' if args.nominal else 'measured',
                    timing_verified=not args.nominal)
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=1) + '\n')
    print(f'wrote {out}/manifest.json and {len(clips)*3} Oggs', flush=True)
