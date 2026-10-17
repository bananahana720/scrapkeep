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
from package_music import RATE, PRE_ROLL, POST_ROLL, STEMS, cut_clip, encode, sha  # noqa: E402

SKETCH = Path(__file__).resolve().parents[2]
OUT = SKETCH / 'assets/music_ace'
SPICE = Path('/home/andrew/Music/Scrapkeep-sound-direction/sound-bible-2026-10-16/spice')
SOUND = SKETCH / 'design-v3/sound'
TARGET_LUFS = -16.0
CEILING = -2.0
MUSIC_FLOOR_DB = -45.0
KEYS = {'C': -2, 'Db': -1, 'D': 0, 'Eb': 1, 'E': 2, 'F': 3, 'Gb': 4, 'G': 5, 'Ab': 6, 'A': 7, 'Bb': 8, 'B': 9}

# cue -> (nominal bpm the tempo search centres on, or None for a 16-bar loop whose length gives the tempo, high mix name)
CUES = {
    'roam-spillway': (172, 'spiced'), 'roam-dig': (172, 'spiced'), 'roam-highdraft': (172, 'spiced'),
    'spillway-loop': (None, 'spiced'), 'dig-loop': (None, 'spiced'), 'highdraft-loop': (None, 'spiced'),
    'boss-brindle': (129, 'spiced'), 'boss-waking': (129, 'spiced'), 'boss-mind': (129, 'spiced'),
    'title-a': (129, 'spiced'), 'title-b': (129, 'spiced'), 'title-c': (172, 'spiced'),
    'summary-win': (129, 'spiced'), 'summary-loss': (129, 'light'),
}
# pack -> (cue, kind, key). Stage-to-pack mapping: src/core/park_defs.gd music.ace (stage 1 spillway, 2 cable_reach,
# 3 dig_upper, 4 dig_deep, 5 highdraft, 6 highdraft_crown); wardens and the menus are src/presentation/music_rows.gd.
# Worlds' tonics: Spillway D, Dig E, Highdraft G; Brindle and the Waking D, the Mind E (package_phase_tracks.py TRACKS).
PACKS = {
    'spillway': ('roam-spillway', 'long', 'D'),
    'cable_reach': ('spillway-loop', 'loop', 'D'),
    'dig_upper': ('roam-dig', 'long', 'E'),
    'dig_deep': ('dig-loop', 'loop', 'E'),
    'highdraft': ('roam-highdraft', 'long', 'G'),
    'highdraft_crown': ('highdraft-loop', 'loop', 'G'),
    'brindle': ('boss-brindle', 'long', 'D'),
    'waking': ('boss-waking', 'long', 'D'),
    'mind': ('boss-mind', 'long', 'E'),
    'title': ('title-a', 'menu', 'D'),
    'title_a': ('title-a', 'menu', 'D'),
    'title_b': ('title-b', 'menu', 'D'),
    'title_c': ('title-c', 'menu', 'D'),
    'summary': ('summary-win', 'summary', 'D'),
}
SHORT_CLIPS = {'pivot', 'telegraph', 'open', 'drop', 'cadence'}


def mix_name(cue, high):
    return f'{cue}-{high}' if high else f'{cue}-current'


def load_track(work, cue, which):
    """Stems of one mix at 44.1 kHz: drums, bass, other (vocals folded in), as float64 (n, 2)."""
    name = mix_name(cue, CUES[cue][1] if which == 'high' else None)
    folder = work / 'stems/htdemucs' / name
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
        self.cur_name, self.cur = load_track(work, cue, 'cur')
        self.hi_name, self.hi = load_track(work, cue, 'high')
        self.n = len(self.cur['drums'])
        self.loop = nominal is None
        self.flux, self.rate = flux_of(self.cur)
        if self.loop:
            # A cut loop is exactly 16 bars long, so its length gives the tempo; the onsets only confirm it.
            self.tempo = 16 * 240 * RATE / self.n / 1.0 / (RATE / RATE)
            self.tempo = 16 * 240 / (self.n / RATE)
            self.read = narrow_tempo(self.flux, self.rate, self.tempo, 0.01)
            self.music_bars = 16
            self.head = 0.0
        else:
            self.tempo = narrow_tempo(self.flux, self.rate, nominal, 0.03)
            self.read = self.tempo
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
            # Three copies so a clip can wrap past either end; the middle copy is the take.
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


def plan_for(track, kind):
    """clip id -> (mix 'cur' or 'high', first bar, bars, loop target bar or None)."""
    m = track.music_bars
    if kind == 'long':
        return dict(calm=('cur', 4, 16, 1), travel=('cur', 20, 16, 1), pivot=('high', 15, 1, None),
                    build=('high', 16, 16, 9), telegraph=('high', m - 12, 4, 1), open=('high', m - 8, 4, 1),
                    drop=('high', m - 4, 4, None), cadence=('cur', m - 2, 2, None))
    if kind == 'loop':
        return dict(calm=('cur', 0, 16, 1), travel=('cur', 8, 16, 1), pivot=('high', -1, 1, None),
                    build=('high', 0, 16, 9), telegraph=('high', 4, 4, 1), open=('high', 8, 4, 1),
                    drop=('high', 12, 4, None), cadence=('cur', 14, 2, None))
    if kind == 'menu':
        return dict(calm=('high', 4, 16, 1), travel=('high', 20, 16, 1), cadence=('high', m - 2, 2, None))
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


def cut_pack(work, pack, tracks):
    cue, kind, key = PACKS[pack]
    if cue not in tracks:
        tracks[cue] = Track(work, cue)
    t = tracks[cue]
    plan = plan_for(t, kind) if pack != 'summary' else None
    if pack == 'summary':
        loss = tracks.setdefault('summary-loss', Track(work, 'summary-loss'))
        wm = t.music_bars
        plan = dict(cadence=(t, 'high', 0, 3, None), calm=(t, 'high', 3, wm - 3, 1),
                    travel=(loss, 'high', 1, loss.music_bars - 1, 1))
        # summary-loss' light mix is its 'high' name (CUES), summary-win's spiced mix is its 'high' name.
    else:
        plan = {cid: (t, *rest) for cid, rest in plan.items()}
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
    # clips under 10 s are not metered by the gate; they take the mean gain of their mix's long clips
    for cid, r in rows.items():
        if 'gain' not in r:
            peers = [x['gain'] for x in rows.values() if 'gain' in x and x['which'] == r['which'] and x['tr'] is r['tr']]
            peers = peers or [x['gain'] for x in rows.values() if 'gain' in x]
            r['gain'] = float(np.mean(peers)) if peers else 0.0
    return kind, key, rows


def write_pack(work, pack, kind, key, rows):
    template = json.loads((OUT / pack / 'manifest.json').read_text()) if (OUT / pack / 'manifest.json').exists() else \
        json.loads((OUT / 'title' / 'manifest.json').read_text())
    folder = OUT / pack
    folder.mkdir(parents=True, exist_ok=True)
    clips, sources = {}, {}
    for cid, r in rows.items():
        tr = r['tr']
        scaled = limit({s: v * 10 ** (r['gain'] / 20) for s, v in r['pcm'].items()})
        i, p = lufs_tp(scaled)
        files = {}
        for s, v in scaled.items():
            files[s] = f'{cid}.{s}.ogg'
            encode(v, folder / files[s])
        mixname = tr.hi_name if r['which'] == 'high' else tr.cur_name
        mix_path = SPICE / f'{mixname}.wav'
        stem_dir = work / 'stems/htdemucs' / mixname
        total = len(r['pcm']['drums'])
        clips[cid] = dict(parent=kind, take=mixname, source_state=f'{mixname} bars {r["first"]}-{r["first"] + r["bars"] - 1}',
                          source_bars=f'{r["first"] + 1}-{r["first"] + r["bars"]}', source_start=r['start'], take_start=r['start'],
                          bpm=round(tr.tempo, 3), beat=tr.bar // 4, bar=tr.bar, beats_per_bar=4, bars=r['bars'],
                          entry=PRE_ROLL, exit=PRE_ROLL + r['bars'] * tr.bar, loop=r['loop_bar'] is not None,
                          loop_offset=r['offset'] or 0, loop_to_bar=r['loop_bar'], sample_count=total,
                          key=key, key_offset=KEYS[key], files=files, mix=r['which'], grid_snap_ms=round(r['snap_ms'], 2),
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
    ap.add_argument('cmd', choices=('plan', 'pack'))
    ap.add_argument('work', type=Path)
    ap.add_argument('--packs', nargs='*', default=list(PACKS))
    args = ap.parse_args()
    tracks = {}
    for pack in args.packs:
        if args.cmd == 'plan':
            cue, kind, key = PACKS[pack]
            t = tracks.setdefault(cue, Track(args.work, cue))
            print(pack, cue, kind, f'tempo {t.tempo:.3f} (read {t.read:.3f}) music bars {t.music_bars} head {t.head / RATE:.4f}s')
            if pack != 'summary':
                for cid, row in plan_for(t, kind).items():
                    print('   ', cid, row, 'snap', t.snap(row[0], row[1])[1])
        else:
            kind, key, rows = cut_pack(args.work, pack, tracks)
            write_pack(args.work, pack, kind, key, rows)


if __name__ == '__main__':
    sys.exit(main())
