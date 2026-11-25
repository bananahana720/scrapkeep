"""Package Andrew's approved soundtrack picks as the core ACE packs, in the 8-section format.

    bash <work>/split.sh                       # resample the mastered mixes to 44.1 kHz and split them with htdemucs
    python package_core_packs.py plan <work>   # print each pack's cut plan (CPU only)
    python package_core_packs.py pack <work>   # cut, gain, encode and write the manifests

The picks are the mastered mixes in the sound bible's spice/ folder (design-v3/sound/spice.py): a
-current mix (the plain master) and a -spiced mix (a -light mix for the quieter tracks) of the same
stems, sample-aligned and at the same tempo and key, so a switch between them never jumps.

Andrew's rule (2026-10-17): roaming ramps with speed. The low-pressure clips (calm, travel and
the kill cadence) come from the -current mix and the high-pressure ones (pivot, build, telegraph,
open, drop) from the -spiced mix of the same track. The hard switch-up sits near the end of each
spiced track, so drop is its last four music bars. A 16-bar loop track is cut cyclically (its
head follows its tail). Title and summary packs have only calm, travel and cadence and use the
picked mix whole. Every clip is cut on the measured beat phase of its own drums stem, loops join
as package_music.cut_clip does, and each clip's gain lands the summed stems on -16 LUFS
(scripts/audio-gate.mjs; clips under 10 s take their mix's long-clip gain).
The Oggs are gitignored; each manifest.json is committed and keeps the section map of the pack it replaces.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from package_music import RATE, PRE_ROLL, POST_ROLL, STEMS, cut_clip, encode, sha

SKETCH = Path(__file__).resolve().parents[2]
OUT = SKETCH / 'assets/music_ace'
SPICE = Path('/home/andrew/Music/Scrapkeep-sound-direction/sound-bible-2026-10-16/spice')
SOUND = SKETCH / 'design-v3/sound'
TARGET_LUFS = -16.0
CEILING = -3.0
MUSIC_FLOOR_DB = -45.0
KEYS = {'C': -2, 'Db': -1, 'D': 0, 'Eb': 1, 'E': 2, 'F': 3, 'Gb': 4, 'G': 5, 'Ab': 6, 'A': 7, 'Bb': 8, 'B': 9}

CUES = {
    'roam-spillway': (172, 'spiced'), 'roam-dig': (172, 'spiced'), 'roam-highdraft': (172, 'spiced'),
    'spillway-loop': (None, 'spiced'), 'dig-loop': (None, 'spiced'), 'highdraft-loop': (None, 'spiced'),
    'boss-brindle': (129, 'spiced'), 'boss-waking': (129, 'spiced'), 'boss-mind': (129, 'spiced'),
    'title-a': (129, 'spiced'), 'title-b': (129, 'spiced'), 'title-c': (172, 'spiced'),
    'camp': (129, 'light'),
    'title-c-up2': (172, 'spiced'), 'summary-loss': (129, 'light'),
}
ZONE_BPM = 129
PACKS = {
    'roam_spillway': ('roam', 'D', 'roam-spillway', None, 'A'),
    'roam_dig': ('roam', 'E', 'roam-dig', None, 'A'),
    'roam_highdraft': ('roam', 'G', 'roam-highdraft', None, 'A'),
    'spillway': ('zone', 'D', 'spillway-loop', 'roam-spillway', 'A'),
    'cable_reach': ('zone', 'D', 'spillway-loop', 'roam-spillway', 'B'),
    'dig_upper': ('zone', 'E', 'dig-loop', 'roam-dig', 'A'),
    'dig_deep': ('zone', 'E', 'dig-loop', 'roam-dig', 'B'),
    'highdraft': ('zone', 'G', 'highdraft-loop', 'roam-highdraft', 'A'),
    'highdraft_crown': ('zone', 'G', 'highdraft-loop', 'roam-highdraft', 'B'),
    'boss_brindle': ('boss', 'D', 'boss-brindle', None, 'A'),
    'boss_waking': ('boss', 'E', 'boss-waking', None, 'A'),
    'boss_mind': ('boss', 'G', 'boss-mind', None, 'A'),
    'title_a': ('menu', 'D', 'title-a', None, 'A'),
    'title_b': ('menu', 'D', 'title-b', None, 'A'),
    'title_c': ('menu', 'D', 'title-c', None, 'A'),
    'camp': ('menu', 'D', 'camp', None, 'A'),
    'summary': ('summary', 'D', 'title-c', 'title-c-up2', 'A'),
}
EXTRA = {'summary': ('summary-loss',)}
CLIP_KEY = {'title-c-up2': 'E'}
TEMPLATES = {'boss_brindle': 'brindle', 'boss_waking': 'waking', 'boss_mind': 'mind', 'summary': 'summary'}


def mix_name(cue, high):
    return f'{cue}-{high}' if high else f'{cue}-current'


def stretch(work):
    """Rubber Band every stem of the three loop tracks from its native tempo to ZONE_BPM, one ratio per track."""
    for cue, (nominal, high) in CUES.items():
        if nominal is not None:
            continue
        for name in (mix_name(cue, None), mix_name(cue, high)):
            src = work / 'stems/htdemucs' / name
            native = 16 * 240 / (sf.info(src / 'drums.wav').frames / RATE)
            dst = work / 'stretched' / name
            dst.mkdir(parents=True, exist_ok=True)
            for s in ('drums', 'bass', 'other', 'vocals'):
                subprocess.run(['rubberband', '-q', '--fine', '-T', f'{ZONE_BPM / native:.8f}', str(src / f'{s}.wav'), str(dst / f'{s}.wav')], check=True)
            print(name, f'native {native:.3f} -> {ZONE_BPM}', flush=True)


def load_track(work, cue, which, stretched=False):
    """Stems of one mix at 44.1 kHz: drums, bass, other (vocals folded in), as float64 (n, 2)."""
    name = mix_name(cue, CUES[cue][1] if which == 'high' else None)
    folder = work / ('stretched' if stretched else 'stems/htdemucs') / name
    out = {}
    for s in ('drums', 'bass', 'other', 'vocals'):
        a, sr = sf.read(folder / f'{s}.wav', always_2d=True)
        if sr != RATE:
            raise SystemExit(f'{folder}/{s}.wav: {sr} Hz, expected {RATE}')
        out[s] = a
    out['other'] = out['other'] + out.pop('vocals')
    return name, out


def db(x):
    return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)


def narrow_tempo(flux, rate, bpm, w):
    best = None
    for t in np.arange(bpm * (1 - w), bpm * (1 + w), 0.01):
        lag = rate * 60 / t
        idx = np.arange(0, len(flux) - 4 * lag, lag)
        score = sum(np.mean(np.interp(idx + k * lag, np.arange(len(flux)), flux)) for k in range(4))
        if best is None or score > best[0]:
            best = (score, t)
    return best[1]


def flux_of(stems):
    import cut_loops
    low = stems['drums'].mean(axis=1) + 0.5 * stems['bass'].mean(axis=1)
    return cut_loops.onset_envelope(low, RATE)


class Track:
    """One cue: both mixes, the tempo, the downbeat head and the music bar count."""

    def __init__(self, work, cue):
        sys.path.insert(0, str(SOUND))
        import cut_loops
        self.cue = cue
        nominal, self.high_name = CUES[cue]
        self.loop = nominal is None
        self.cur_name, self.cur = load_track(work, cue, 'cur', self.loop)
        self.hi_name, self.hi = load_track(work, cue, 'high', self.loop)
        if self.loop:
            # The stretched loop is exactly 16 bars of the zone tempo; Rubber Band's length is trimmed or padded to that.
            want = int(round(16 * 240 / ZONE_BPM * RATE))
            for d in (self.cur, self.hi):
                for s in STEMS:
                    d[s] = d[s][:want] if len(d[s]) >= want else np.pad(d[s], ((0, want - len(d[s])), (0, 0)))
        self.n = len(self.cur['drums'])
        self.flux, self.rate = flux_of(self.cur)
        if self.loop:
            self.tempo = float(ZONE_BPM)
            self.read = narrow_tempo(self.flux, self.rate, self.tempo, 0.01)
            self.music_bars = 16
            self.head = 0.0
        else:
            self.read = narrow_tempo(self.flux, self.rate, nominal, 0.03 if cue.startswith('title') else 0.01)
            self.tempo = self.read if cue.startswith('title') else float(nominal)
            self.head = cut_loops.phase(self.flux, self.rate, self.tempo) * RATE
        self.bar_f = 240 / self.tempo * RATE
        self.beat_f = self.bar_f / 4
        self.bar = int(round(self.bar_f / 4)) * 4
        if not self.loop:
            bars = int((self.n - self.head) // self.bar_f)
            levels = [db(self.cur['drums'][int(self.head + i * self.bar_f):int(self.head + (i + 1) * self.bar_f)]
                         + self.cur['bass'][int(self.head + i * self.bar_f):int(self.head + (i + 1) * self.bar_f)]
                         + self.cur['other'][int(self.head + i * self.bar_f):int(self.head + (i + 1) * self.bar_f)])
                      for i in range(bars)]
            self.music_bars = max(i for i, v in enumerate(levels) if v > MUSIC_FLOOR_DB + 0) + 1
        else:
            for d in (self.cur, self.hi):
                for s in STEMS:
                    d[s] = np.concatenate([d[s]] * 3)
            self.base = self.n
            self.head = float(self.n)

    def snap(self, which, start_bar):
        """The clip start in samples: the predicted bar line, moved to the local kick grid (within 45 ms)."""
        import cut_loops
        s0 = self.head + start_bar * self.bar_f
        if self.loop:
            return int(round(s0)), 0.0
        span = int(4 * self.bar_f)
        lo = int(s0 - span)
        src = self.cur
        a = {k: src[k][max(lo, 0):lo + 2 * span] for k in ('drums', 'bass')}
        if lo < 0 or len(a['drums']) < 2 * span * 0.75:
            return int(round(s0)), 0.0
        flux, rate = cut_loops.onset_envelope(a['drums'].mean(axis=1) + 0.5 * a['bass'].mean(axis=1), RATE)
        p = cut_loops.phase(flux, rate, self.tempo) * RATE
        if p > self.beat_f / 2:
            p -= self.beat_f
        if abs(p) > 0.045 * RATE:
            return int(round(s0)), 0.0
        return int(round(s0 + p)), p / RATE * 1000


def cues_for(pack, only=None):
    """The cues a pack's cut needs; a zone pack recutting only calm and travel needs only its roam cue."""
    kind, _key, cue, roam, _stage = PACKS[pack]
    if kind == 'zone' and only and set(only) <= {'calm', 'travel'}:
        return (roam,)
    return tuple(c for c in (cue, roam) + EXTRA.get(pack, ()) if c)


def plan_for(pack, tracks, only=None):
    """clip id -> (track, mix 'cur' or 'high', first bar, bars, loop target bar or None)."""
    plan = full_plan(pack, tracks)
    return {k: v for k, v in plan.items() if only is None or k in only}


def full_plan(pack, tracks):
    kind, _key, cue, roam, stage = PACKS[pack]
    t = tracks.get(cue)
    m = t.music_bars if t else None
    if kind == 'roam':
        return dict(calm=(t, 'cur', 4, 16, 1), travel=(t, 'cur', 20, 16, 1), cadence=(t, 'high', m - 2, 2, None))
    if kind == 'boss':
        return dict(calm=(t, 'cur', 4, 16, 1), travel=(t, 'cur', 20, 16, 1), pivot=(t, 'high', 15, 1, None),
                    build=(t, 'high', 16, 16, 9), telegraph=(t, 'high', m - 12, 4, 1), open=(t, 'high', m - 8, 4, 1),
                    drop=(t, 'high', m - 4, 4, None), cadence=(t, 'cur', m - 2, 2, None))
    if kind == 'menu':
        return dict(calm=(t, 'high', 4, 16, 1), travel=(t, 'high', 20, 16, 1), cadence=(t, 'high', m - 2, 2, None))
    if kind == 'summary':
        up, loss = tracks[roam], tracks['summary-loss']
        return dict(cadence=(t, 'high', 2, 2, None), calm=(up, 'high', 4, 16, 1), travel=(loss, 'high', 1, 16, 1))
    if kind == 'zone':
        r = tracks[roam]
        o = 0 if stage == 'A' else 8
        shelf = 4 + o
        tele, opn = (4 + o, 10 + o) if stage == 'A' else (8 + o, 4 + o)
        return dict(calm=(r, 'cur', shelf, 16, 1), travel=(r, 'cur', shelf + 16, 16, 1), pivot=(t, 'high', o - 1, 1, None),
                    build=(t, 'high', o, 16, 9), telegraph=(t, 'high', tele, 4, 1), open=(t, 'high', opn, 4, 1),
                    drop=(t, 'high', 12 + o, 4, None), cadence=(t, 'cur', 14 + o, 2, None))
    raise SystemExit(f'no plan for {kind}')


def limit(pcm, ceiling_db=CEILING):
    """One smooth gain curve from the summed stems, applied to every stem (numpy only)."""
    mix = np.abs(sum(pcm.values())).max(axis=1)
    ceiling = 10 ** (ceiling_db / 20)
    want = np.minimum(1.0, ceiling / np.maximum(mix, 1e-9))
    if want.min() >= 1.0:
        return pcm
    depth = 1.0 - want
    block = 265
    pad = (-len(depth)) % block
    blocks = np.pad(depth, (0, pad)).reshape(-1, block).max(axis=1)
    held = np.maximum(np.maximum(np.roll(blocks, 1), blocks), np.roll(blocks, -1))
    held = np.repeat(held, block)[:len(depth)]
    width = int(RATE * 0.008)
    csum = np.cumsum(np.pad(held, (width, width), mode='edge'))
    smooth = (csum[2 * width:] - csum[:-2 * width]) / (2 * width)
    gain = np.minimum(1.0, 1.0 - np.maximum(smooth[:len(depth)], 0.0))[:, None]
    return {s: v * gain for s, v in pcm.items()}


def lufs_tp(pcm):
    mix = sum(pcm.values()).astype('<f4')
    out = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-f', 'f32le', '-ar', str(RATE), '-ac', '2', '-i', 'pipe:0',
                          '-af', 'ebur128=peak=true', '-f', 'null', '-'], input=mix.tobytes(), capture_output=True).stderr.decode()
    i = re.findall(r'^\s*I:\s+(-?[\d.]+)\s+LUFS', out, re.M)[-1]
    p = re.findall(r'^\s*Peak:\s+(-?[\d.]+)\s+dBFS', out, re.M)[-1]
    return float(i), float(p)


def fit_gain(pcm):
    gain = 0.0
    for _ in range(8):
        i, _p = lufs_tp(limit({s: v * 10 ** (gain / 20) for s, v in pcm.items()}))
        want = TARGET_LUFS - i
        if abs(want) < 0.03:
            break
        gain += want
    return gain


def cut_pack(work, pack, tracks, only=None):
    kind, key, cue, roam, _stage = PACKS[pack]
    for c in cues_for(pack, only):
        if c not in tracks:
            tracks[c] = Track(work, c)
    plan = plan_for(pack, tracks, only)
    rows = {}
    for cid, (tr, which, first, bars, loop_bar) in plan.items():
        stems = tr.hi if which == 'high' else tr.cur
        start, snap_ms = tr.snap(which, first)
        frames = bars * tr.bar
        state = dict(source_start=start, frames=frames)
        clips = {s: cut_clip(stems[s], state, 0, loop_bar, tr.bar) for s in STEMS}
        pcm = {s: c[0] for s, c in clips.items()}
        rows[cid] = dict(tr=tr, which=which, first=first, bars=bars, loop_bar=loop_bar, start=start, snap_ms=snap_ms,
                         pcm=pcm, offset=clips['drums'][1])
        if (len(pcm['drums']) / RATE) >= 10:
            rows[cid]['gain'] = fit_gain(pcm)
    for cid, r in rows.items():
        if 'gain' not in r:
            peers = [x['gain'] for x in rows.values() if 'gain' in x and x['which'] == r['which'] and x['tr'] is r['tr']]
            peers = peers or [x['gain'] for x in rows.values() if 'gain' in x]
            r['gain'] = float(np.mean(peers)) if peers else 0.0
    return kind, key, rows


def write_pack(work, pack, kind, key, rows, only=None, renders=None):
    own = OUT / pack / 'manifest.json'
    beside = OUT / TEMPLATES.get(pack, 'title') / 'manifest.json'
    template = json.loads((own if own.exists() and (kind == 'zone' or only) else beside).read_text())
    folder = OUT / pack
    folder.mkdir(parents=True, exist_ok=True)
    clips, sources = (dict(template['clips']), dict(template['sources'])) if only else ({}, {})
    for cid, r in rows.items():
        tr = r['tr']
        scaled = limit({s: v * 10 ** (r['gain'] / 20) for s, v in r['pcm'].items()})
        i, p = lufs_tp(scaled)
        files = {}
        for s, v in scaled.items():
            files[s] = f'{cid}.{s}.ogg'
            encode(v, folder / files[s])
        mixname = tr.hi_name if r['which'] == 'high' else tr.cur_name
        mix_path = (renders or {}).get(tr.cue) or SPICE / f'{mixname.replace("-up2", "")}.wav'
        stem_dir = work / ('stretched' if tr.loop else 'stems/htdemucs') / mixname
        total = len(r['pcm']['drums'])
        clips[cid] = dict(parent=kind, take=mixname, source_state=f'{mixname} bars {r["first"]}-{r["first"] + r["bars"] - 1}',
                          source_bars=f'{r["first"] + 1}-{r["first"] + r["bars"]}', source_start=r['start'], take_start=r['start'],
                          bpm=round(tr.tempo, 3), beat=tr.bar // 4, bar=tr.bar, beats_per_bar=4, bars=r['bars'],
                          entry=PRE_ROLL, exit=PRE_ROLL + r['bars'] * tr.bar, loop=r['loop_bar'] is not None,
                          loop_offset=r['offset'] or 0, loop_to_bar=r['loop_bar'], sample_count=total,
                          key=CLIP_KEY.get(tr.cue, key), key_offset=KEYS[CLIP_KEY.get(tr.cue, key)], files=files, mix=r['which'], grid_snap_ms=round(r['snap_ms'], 2),
                          gain_db=round(r['gain'], 2), measured=dict(lufs=i, true_peak=p, note='summed stems before Ogg encode'))
        sources[cid] = dict(take=mixname, render=str(mix_path), render_sha256=sha(mix_path), tempo_read=round(tr.read, 3),
                            timing='measured beat phase of the drums stem; downbeat identity unverified',
                            split=dict(tool='htdemucs, vocals folded into other', stems={
                                s: dict(path=str(stem_dir / f'{s}.wav'), sha256=sha(stem_dir / f'{s}.wav'))
                                for s in ('drums', 'bass', 'other', 'vocals')}))
        print(f'{pack}/{cid}: {mixname} bars {r["first"]}+{r["bars"]} @ {tr.tempo:.2f}, gain {r["gain"]:+.2f} dB, '
              f'{i:.2f} LUFS {p:.2f} dBFS, snap {r["snap_ms"]:.1f} ms', flush=True)
    first = next(iter(rows.values()))['tr']
    manifest = dict(template)
    manifest.update(theme=pack, key=key, key_offset=KEYS[key], level_db=0.0, sources=sources, clips=clips,
                    cuts='measured-beat-phase', timing_verified=False, pick='sound-bible-2026-10-16/spice')
    manifest.pop('timeline', None)
    (folder / 'manifest.json').write_text(json.dumps(manifest, indent=1) + '\n')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('cmd', choices=('stretch', 'plan', 'pack'))
    ap.add_argument('work', type=Path)
    ap.add_argument('--packs', nargs='*', default=list(PACKS))
    ap.add_argument('--clips', nargs='*', help='recut only these clip ids; the rest keep their Oggs and manifest rows')
    ap.add_argument('--render', action='append', default=[], metavar='CUE=WAV',
                    help="a stand-in take's mastered mix, recorded as the cue's source render")
    args = ap.parse_args()
    if args.cmd == 'stretch':
        return stretch(args.work)
    renders = dict((c, Path(p)) for c, p in (r.split('=', 1) for r in args.render))
    tracks = {}
    for pack in args.packs:
        if args.cmd == 'plan':
            kind, key, cue, roam, stage = PACKS[pack]
            for c in cues_for(pack, args.clips):
                if c not in tracks:
                    tracks[c] = Track(args.work, c)
            for c in cues_for(pack, args.clips):
                t = tracks[c]
                print(pack, c, kind, stage, f'tempo {t.tempo:.3f} (read {t.read:.3f}) music bars {t.music_bars} head {t.head / RATE:.4f}s')
            for cid, (t, which, first, bars, loop) in plan_for(pack, tracks, args.clips).items():
                print('   ', cid, t.cue, which, first, bars, loop, f'snap {t.snap(which, first)[1]:.1f} ms')
        else:
            kind, key, rows = cut_pack(args.work, pack, tracks, args.clips)
            write_pack(args.work, pack, kind, key, rows, args.clips, renders)


if __name__ == '__main__':
    sys.exit(main())
