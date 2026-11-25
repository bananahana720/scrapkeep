#!/usr/bin/env python3
"""Re-page packed Oggs so a start anywhere in a clip costs what a start at its head costs.

An Ogg file is stored in pages, and a decoder that starts anywhere but a page's first sample
decodes from the page before. ffmpeg writes pages one second long unless told otherwise, so
the sequencer's opens deep in a clip (a build's return at bar 9, a breath) decoded up to a
second of audio on the frame that asked: 2.9 ms a stem on the PC against 0.5 ms at a clip's
head. Pages of 20 ms make every start cost the same.

Re-paging moves the same audio packets into shorter pages (`ffmpeg -c copy`): nothing is
encoded again, and every file is proved to decode to the same samples before it replaces
the original. The file grows about 9 percent.

  repage.py check [dir]            page lengths of every .ogg under dir; exit 1 if any is long
  repage.py apply [dir] [--backup <dir>]
                                   re-page every long .ogg in place, originals copied to the
                                   backup first when one is named

dir defaults to assets/music_ace. After `apply`, run `scripts/music/mx stem-hashes`: the
files' bytes changed, so STEMS.sha256 must be written again (the audio is the same).
New packs are born short-paged: `package_music.encode` passes PAGE_USEC to ffmpeg.
"""
import argparse
import hashlib
import os
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
MUSIC = HERE.parent.parent / 'assets' / 'music_ace'
PAGE_USEC = 20000
MAX_PAGE_S = 0.1


def pages(data):
    """(sample rate, [granule position of each page]) of an Ogg Vorbis file's bytes."""
    rate = 0
    granules = []
    at = 0
    while True:
        at = data.find(b'OggS', at)
        if at < 0 or at + 27 > len(data):
            break
        granule = struct.unpack_from('<q', data, at + 6)[0]
        segments = data[at + 26]
        body = at + 27 + segments
        size = sum(data[at + 27:body])
        if rate == 0 and data[body:body + 7] == b'\x01vorbis':
            rate = struct.unpack_from('<I', data, body + 12)[0]
        if granule >= 0:
            granules.append(granule)
        at = body + size
    return rate, granules


def longest_page(path):
    """Seconds of audio in the file's longest page, and its page count."""
    try:
        rate, granules = pages(Path(path).read_bytes())
    except (struct.error, IndexError):
        rate, granules = 0, []
    if rate == 0 or not granules:
        raise ValueError(f'{path}: not an Ogg Vorbis file')
    steps = [b - a for a, b in zip([0] + granules, granules)]
    return max(steps) / rate, len(granules)


def pcm_sha(path):
    out = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 's16le', '-'],
                         capture_output=True, check=True).stdout
    return hashlib.sha256(out).hexdigest(), len(out)


def repage(src, dst):
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(src), '-c', 'copy', '-fflags', '+bitexact',
                    '-map_metadata', '-1', '-page_duration', str(PAGE_USEC), '-f', 'ogg', str(dst)], check=True)


def oggs(root):
    return sorted(Path(root).rglob('*.ogg'))


def check(root):
    long = []
    files = oggs(root)
    for f in files:
        seconds, _count = longest_page(f)
        if seconds > MAX_PAGE_S:
            long.append((f, seconds))
    for f, seconds in long:
        print(f'LONG {f.relative_to(root)}: longest page {seconds:.3f} s')
    print(f'{len(files)} Oggs, {len(long)} with a page over {MAX_PAGE_S} s')
    return 1 if long else 0


def apply(root, backup):
    files = oggs(root)
    done = 0
    before = after = 0
    for f in files:
        seconds, _count = longest_page(f)
        if seconds <= MAX_PAGE_S:
            continue
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / f.name
            repage(f, out)
            was, was_len = pcm_sha(f)
            now, now_len = pcm_sha(out)
            why = ''
            if was != now or was_len != now_len or was_len == 0:
                why = 'the re-paged copy does not decode to the same samples'
            elif longest_page(out)[0] > MAX_PAGE_S:
                why = 'the re-paged copy still holds a long page'
            if why:
                print(f'REFUSED {f.relative_to(root)}: {why}; left as it was, and the pass stopped here')
                if done:
                    print(f'{done} files before it were re-paged; run scripts/music/mx stem-hashes once the rest are done')
                return 1
            if backup is not None:
                keep = Path(backup) / f.relative_to(root)
                keep.parent.mkdir(parents=True, exist_ok=True)
                if not keep.exists():
                    shutil.copy2(f, keep)
            before += f.stat().st_size
            after += out.stat().st_size
            beside = f.with_name(f.name + '.repaged')
            shutil.copyfile(out, beside)
            os.replace(beside, f)
        done += 1
    grew = (after / before - 1.0) * 100.0 if before else 0.0
    print(f'{done} of {len(files)} Oggs re-paged, every one decoding to the same samples; {before} to {after} bytes ({grew:+.1f} percent)')
    if done:
        print('now run: scripts/music/mx stem-hashes')
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    sub = ap.add_subparsers(dest='cmd', required=True)
    c = sub.add_parser('check')
    c.add_argument('dir', nargs='?', default=str(MUSIC))
    a = sub.add_parser('apply')
    a.add_argument('dir', nargs='?', default=str(MUSIC))
    a.add_argument('--backup')
    args = ap.parse_args()
    if args.cmd == 'check':
        return check(Path(args.dir))
    return apply(Path(args.dir), args.backup)


if __name__ == '__main__':
    sys.exit(main())
