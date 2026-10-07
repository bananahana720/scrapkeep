"""Generated-bank packaging on known, measured synthetic sources (no GPU)."""
import contextlib
import io
import json
import sys
import tempfile
import types
import wave
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import package_render_music as pack


def run():
    with tempfile.TemporaryDirectory(prefix='mus-package-') as folder:
        base = Path(folder)
        render = base / 'renders/dig_upper'
        render.mkdir(parents=True)
        (base / 'jobs').mkdir()
        reference = Path(__file__).resolve().parents[2] / 'assets/music_ace/spillway/manifest.json'
        pack.SKETCH = base / 'sketch'
        spillway = pack.SKETCH / 'assets/music_ace/spillway'
        spillway.mkdir(parents=True)
        (spillway / 'manifest.json').write_bytes(reference.read_bytes())
        jobs, rows, cuts = [], [], {}
        for cid, bars in pack.BODY_BARS.items():
            name = 'base-' + cid
            take = 'fixture-' + cid
            job = dict(name=name, seeds=[1, 2], params=dict(bpm=150, keyscale='E minor'))
            jobs.append(job)
            rows.append(dict(name=name, success=True, audios=[dict(path=str(render / (take + '.wav')), seed=1)]))
            start = 4 * 70560
            cuts[name] = dict(take=take, source_start=start)
            directory = base / 'stems/htdemucs' / take
            directory.mkdir(parents=True)
            for stem in pack.STEMS:
                with wave.open(str(directory / (take + '.' + stem + '.wav')), 'wb') as w:
                    w.setnchannels(2)
                    w.setsampwidth(2)
                    w.setframerate(44100)
                    w.writeframes(b'\0\0\0\0' * (start + bars * 70560 + 1024))
        (render / 'manifest.json').write_text(json.dumps(rows))
        (base / 'jobs/dig_upper.json').write_text(json.dumps(dict(jobs=jobs, _composition=dict(banks=dict(base=dict(key='E'))))))
        cut_file = base / 'cuts.json'
        cut_file.write_text(json.dumps(cuts))
        args = types.SimpleNamespace(render=render, cuts=cut_file, nominal=False, stems=None, seed=None, bank=None)
        with contextlib.redirect_stdout(io.StringIO()):
            pack.package_render(args)
        out = pack.SKETCH / 'assets/music_ace/dig_upper'
        manifest = json.loads((out / 'manifest.json').read_text())
        assert manifest['timing_verified'] and manifest['theme'] == 'dig_upper'
        assert manifest['cuts'] == 'measured'
        assert manifest['level_db'] == 0 and manifest['breath_default'] == 'hard'
        assert (spillway / 'manifest.json').read_bytes() == reference.read_bytes()
        assert set(manifest['clips']) == set(pack.BODY_BARS)
        named = set()
        for cid, row in manifest['clips'].items():
            assert row['key_offset'] == 2 and row['bar'] == row['beat'] * 4
            assert row['entry'] == 4096 and row['exit'] == 4096 + row['bars'] * row['bar']
            if cid == 'build':
                assert row['loop_offset'] == 4096 + 8 * row['bar'] and row['loop_to_bar'] == 9
            for file in row['files'].values():
                assert (out / file).is_file()
                named.add(file)
        assert named == {f.name for f in out.glob('*.ogg')} and len(named) == 24
        args.cuts = None
        try:
            pack.package_render(args)
        except SystemExit as error:
            assert 'measured' in str(error)
        else:
            raise AssertionError('packager silently accepted missing measured cuts')
        args.nominal = True
        with contextlib.redirect_stdout(io.StringIO()):
            pack.package_render(args)
        nominal = json.loads((out / 'manifest.json').read_text())
        assert nominal['cuts'] == 'nominal-unverified' and not nominal['timing_verified']
        assert all('unverified' in source['timing'] for source in nominal['sources'].values())


if __name__ == '__main__':
    try:
        run()
    except Exception:
        print('package_render_music_test: FAIL')
        raise
    print('package_render_music_test: PASS')
