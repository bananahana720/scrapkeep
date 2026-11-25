"""Re-paging on synthetic Oggs: same samples, short pages, originals kept, and new packs born short-paged (needs ffmpeg, no GPU)."""
import contextlib
import io
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import package_music as pack
import repage


def quiet(fn, *args):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = fn(*args)
    return code, out.getvalue()


def run():
    with tempfile.TemporaryDirectory(prefix='repage-') as folder:
        root = Path(folder) / 'music_ace'
        (root / 'spillway').mkdir(parents=True)
        backup = Path(folder) / 'before'
        # ffmpeg's own paging: one second a page.
        tone = root / 'spillway' / 'build.other.ogg'
        subprocess.run(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i', 'sine=frequency=220:duration=6:sample_rate=44100',
                        '-ac', '2', '-c:a', 'libvorbis', '-q:a', '6', str(tone)], check=True)
        noise = root / 'spillway' / 'build.drums.ogg'
        subprocess.run(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i', 'anoisesrc=d=4:c=pink:r=44100:a=0.3',
                        '-ac', '2', '-c:a', 'libvorbis', '-q:a', '6', str(noise)], check=True)
        assert repage.longest_page(tone)[0] > 0.9, 'the planted file is long-paged'
        code, said = quiet(repage.check, root)
        assert code == 1 and said.count('LONG') == 2, said
        before = {f: repage.pcm_sha(f) for f in (tone, noise)}
        raw = {f: f.read_bytes() for f in (tone, noise)}
        code, said = quiet(repage.apply, root, str(backup))
        assert code == 0 and '2 of 2' in said, said
        for f in (tone, noise):
            assert repage.pcm_sha(f) == before[f], f'{f.name} decodes to the same samples'
            assert repage.longest_page(f)[0] <= repage.MAX_PAGE_S, f'{f.name} is short-paged'
            assert f.read_bytes() != raw[f], f'{f.name} was rewritten'
            assert (backup / f.relative_to(root)).read_bytes() == raw[f], f'{f.name} was kept as it was'
        code, said = quiet(repage.check, root)
        assert code == 0, said
        again = {f: f.read_bytes() for f in (tone, noise)}
        code, said = quiet(repage.apply, root, None)
        assert code == 0 and '0 of 2' in said, said
        assert all(f.read_bytes() == again[f] for f in again), 'a second pass changes nothing'
        t = np.arange(pack.RATE * 3) / pack.RATE
        born = root / 'spillway' / 'calm.bass.ogg'
        pack.encode(np.stack([np.sin(2 * np.pi * 110 * t)] * 2, axis=1) * 0.3, born)
        assert repage.longest_page(born)[0] <= repage.MAX_PAGE_S, 'the encoder writes short pages'
        (root / 'spillway' / 'broken.ogg').write_bytes(b'not an ogg')
        try:
            repage.check(root)
        except ValueError as e:
            assert 'broken.ogg' in str(e)
        else:
            raise AssertionError('a file that is not an Ogg was passed over')


if __name__ == '__main__':
    try:
        run()
    except Exception:
        print('repage_test: FAIL')
        raise
    print('repage_test: PASS')
