"""Bring named clips of a music_ace pack to the audio gate's level: -16 LUFS, true peak under -1 dBTP.

    python level_packs.py <music_ace stems folder> <manifest folder> <pack/clip> [<pack/clip> ...]
                          [--ceiling -2.6] [--dry]

The older packs (brindle, mind, waking, title) were cut before the packager baked a gain into each
clip, so a few of their clips sit above -16 LUFS or past -1 dBTP. This sums a clip's stems as the
engine does, finds one gain that lands the sum on -16 LUFS under the same smooth limiter the packagers
use (package_phase_tracks.limit), applies it to every stem so their balance stays, re-encodes the
three Oggs with package_music.encode, and records gain_db and measured on the clip in the manifest.
Picks, takes, cut points and loop joins are untouched. The Oggs are gitignored; only the manifests
are committed.
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import package_phase_tracks as P
from package_music import encode

STEMS = ('drums', 'bass', 'other')
NOTE = 'summed stems before Ogg re-encode, after level_packs.py'


def level_clip(stems_dir, clip, ceiling, dry):
    pcm = {s: P.read_stem(stems_dir / clip['files'][s]) for s in STEMS}
    before = P.lufs_tp(pcm)
    gain_db = 0.0
    for _ in range(8):
        i, _ = P.lufs_tp(P.limit({s: v * 10 ** (gain_db / 20) for s, v in pcm.items()}, ceiling))
        want = P.TARGET_LUFS - i
        if abs(want) < 0.05:
            break
        gain_db += want
    scaled = P.limit({s: v * 10 ** (gain_db / 20) for s, v in pcm.items()}, ceiling)
    after = P.lufs_tp(scaled)
    if not dry:
        for s in STEMS:
            encode(scaled[s], stems_dir / clip['files'][s])
    return before, after, gain_db


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('stems', type=Path)
    ap.add_argument('manifests', type=Path)
    ap.add_argument('clips', nargs='+', help='pack/clip, for example mind/travel')
    ap.add_argument('--ceiling', type=float, default=-2.6, help='limiter ceiling in dBFS; low enough that the Ogg encode stays under -1 dBTP')
    ap.add_argument('--dry', action='store_true', help='measure and print, change nothing')
    args = ap.parse_args()
    by_pack = {}
    for ref in args.clips:
        pack, clip = ref.split('/')
        by_pack.setdefault(pack, []).append(clip)
    for pack, clips in by_pack.items():
        path = args.manifests / pack / 'manifest.json'
        manifest = json.loads(path.read_text())
        for name in clips:
            clip = manifest['clips'][name]
            (bi, bp), (ai, ap_), gain_db = level_clip(args.stems / pack, clip, args.ceiling, args.dry)
            print(f'{pack}/{name}: {bi:.2f} LUFS {bp:.2f} dBFS -> {ai:.2f} LUFS {ap_:.2f} dBFS, gain {gain_db:+.2f} dB', flush=True)
            clip['gain_db'] = round(float(clip.get('gain_db', 0.0)) + gain_db, 2)
            clip['measured'] = dict(lufs=ai, true_peak=ap_, note=NOTE)
        if not args.dry:
            path.write_text(json.dumps(manifest, indent=1) + '\n')


if __name__ == '__main__':
    main()
