"""mixsim's room rows on a made-up cue log and two generated tones: a row with an "only" list ducks just the sounds it names (warnings included), a row without one ducks every voice but a warning. Says nothing about the real game's numbers."""
import json
import runpy
import sys
import tempfile
from pathlib import Path

import numpy as np

RATE = 44100
HERE = Path(__file__).resolve().parent


def sim(rows):
    with tempfile.TemporaryDirectory(prefix='mixsim-') as folder:
        root = Path(folder)
        t = np.arange(RATE) / RATE
        (0.5 * np.sin(2 * np.pi * 1000 * t)).astype(np.float32).tofile(root / 'threat_tear.f32')
        (0.5 * np.sin(2 * np.pi * 3000 * t)).astype(np.float32).tofile(root / 'bell.f32')
        (0.5 * np.sin(2 * np.pi * 500 * t)).astype(np.float32).tofile(root / 'near_whoosh.f32')
        (root / 'ids.tsv').write_text(''.join('%s\t%s\t%d\t1\t1\n' % (n, n, RATE) for n in ('threat_tear', 'bell', 'near_whoosh')))
        cues = [[1.0, 'threat', 'threat_tear', 'now', 1.0, 0.0], [1.0, 'ding', 'bell', 'now', 1.0, 0.0],
                [1.2, 'near_miss', 'near_whoosh', 'now', 1.0, 0.0]]
        (root / 'run.json').write_text(json.dumps({'cue_rows': cues + rows}))
        sys.argv = ['mixsim.py', str(root / 'run.json'), str(root), str(root / 'out.txt')]
        g = runpy.run_path(str(HERE / 'mixsim.py'))
    by = {c['sound']: c for c in g['cues']}
    # Level over the room's window (1.2 s to 1.5 s), against the same voice's level before it.
    return {n: float(np.sqrt(np.mean(by[n]['x'][int(0.25 * RATE):int(0.28 * RATE)] ** 2)) / 0.3535) for n in ('threat_tear', 'bell')}


def run():
    only = sim([[1.2, 'near_miss', 'near_whoosh', 'room', 0.3, -8.0, ['threat_tear']]])
    plain = sim([[1.2, 'near_miss', 'near_whoosh', 'room', 0.3, -8.0]])
    g = 10 ** (-8.0 / 20)
    checks = [
        ('only: the named warning is ducked', abs(only['threat_tear'] - g) < 0.03),
        ('only: another sound is left alone', abs(only['bell'] - 1.0) < 0.03),
        ('no only: a sound is ducked', abs(plain['bell'] - g) < 0.03),
        ('no only: a warning keeps its level', abs(plain['threat_tear'] - 1.0) < 0.03),
    ]
    bad = 0
    for label, ok in checks:
        print('[%s] %s' % (label, 'PASS' if ok else 'FAIL'))
        bad += 0 if ok else 1
    print('mixsim_test: %s (%d checks) %s %s' % ('PASS' if bad == 0 else 'FAIL', len(checks), only, plain))
    return bad


if __name__ == '__main__':
    sys.exit(1 if run() else 0)
