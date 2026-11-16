"""mixsim replays the game's own duck and restore rows on a made-up cue log and generated tones, and holds no copy of the room rule. A voice takes a gain only from a row naming it; a take with no duck log is refused. Says nothing about the real game's numbers."""
import json
import runpy
import sys
import tempfile
from pathlib import Path

import numpy as np

RATE = 44100
HERE = Path(__file__).resolve().parent
NAMES = ('threat_tear', 'bell', 'near_whoosh')
G8 = 10 ** (-8.0 / 20)


def sim(rows, duck_log=True):
    """The effect layer of a run made of three tones and `rows`, as {(sound, start): voice samples}."""
    with tempfile.TemporaryDirectory(prefix='mixsim-') as folder:
        root = Path(folder)
        t = np.arange(RATE) / RATE
        for name, hz in zip(NAMES, (1000, 3000, 500)):
            (0.5 * np.sin(2 * np.pi * hz * t)).astype(np.float32).tofile(root / (name + '.f32'))
        (root / 'ids.tsv').write_text(''.join('%s\t%s\t%d\t1\t1\n' % (n, n, RATE) for n in NAMES))
        run = {'cue_rows': rows}
        if duck_log:
            run['duck_log'] = True
        (root / 'run.json').write_text(json.dumps(run))
        sys.argv = ['mixsim.py', str(root / 'run.json'), str(root), str(root / 'out.txt')]
        g = runpy.run_path(str(HERE / 'mixsim.py'))
    return {(c['sound'], c['t']): c['x'] for c in g['cues']}


def level(x, start, at):
    """RMS of the voice 30 ms from `at` seconds, against a full-level tone's 0.3535."""
    a = int((at - start) * RATE)
    return float(np.sqrt(np.mean(x[a:a + int(0.03 * RATE)] ** 2)) / 0.3535)


STARTS = [[1.0, 'threat', 'threat_tear', 'now', 1.0, 0.0], [1.0, 'ding', 'bell', 'now', 1.0, 0.0],
          [1.2, 'near_miss', 'near_whoosh', 'now', 1.0, 0.0], [1.25, 'threat', 'threat_tear', 'now', 1.0, 0.0]]
ROOM = [1.2, 'near_miss', 'near_whoosh', 'room', 0.3, -8.0, ['threat_tear']]


def run():
    # The game ducks the tear already sounding (started 1.0) at 1.2 and not the one starting at 1.25.
    duck = sim(STARTS + [ROOM, [1.2, 'near_miss', 'threat_tear', 'duck', 1.0, -8.0]])
    # Whoosh, then a hit: the game restores the ducked tear at 1.25.
    early = sim(STARTS + [ROOM, [1.2, 'near_miss', 'threat_tear', 'duck', 1.0, -8.0], [1.25, 'hurt', 'threat_tear', 'restore', 1.0, 0.0]])
    # A planted disagreement: the rows duck the bell, which the old rule would never do, and not the tear, which it would.
    planted = sim(STARTS + [ROOM, [1.2, 'near_miss', 'bell', 'duck', 1.0, -6.0]])
    # A second hit inside the first hit's hold: the game restores and ducks again in one call, so the rows share a time.
    again = sim(STARTS + [[1.2, 'hurt', 'bell', 'duck', 1.0, -10.0], [1.3, 'hurt', 'bell', 'restore', 1.0, 0.0], [1.3, 'hurt', 'bell', 'duck', 1.0, -10.0]])
    old_log = None
    try:
        sim(STARTS + [ROOM], duck_log=False)
    except SystemExit as e:
        old_log = e.code
    key_a, key_b, key_bell = ('threat_tear', 1.0), ('threat_tear', 1.25), ('bell', 1.0)
    checks = [
        ('a tear already sounding is full before the duck row', abs(level(duck[key_a], 1.0, 1.1) - 1.0) < 0.03),
        ('a tear already sounding is ducked from the duck row', abs(level(duck[key_a], 1.0, 1.3) - G8) < 0.03),
        ('a tear starting in the hold, with no duck row, is at full level', abs(level(duck[key_b], 1.25, 1.3) - 1.0) < 0.03),
        ('another sound is left alone', abs(level(duck[key_bell], 1.0, 1.3) - 1.0) < 0.03),
        ('a restore row ends the duck early', abs(level(early[key_a], 1.0, 1.22) - G8) < 0.03 and abs(level(early[key_a], 1.0, 1.3) - 1.0) < 0.03),
        ('planted: the rows duck the bell, so it is ducked', abs(level(planted[key_bell], 1.0, 1.3) - 10 ** (-6.0 / 20)) < 0.03),
        ('planted: the rows leave the tear alone, so it is at full level', abs(level(planted[key_a], 1.0, 1.3) - 1.0) < 0.03),
        ('a restore and a duck at one time keep the logged order, so the voice stays ducked', abs(level(again[key_bell], 1.0, 1.35) - 10 ** (-10.0 / 20)) < 0.03),
        ('a take with room rows and no duck log is refused', old_log == 2),
    ]
    bad = 0
    for label, ok in checks:
        print('[%s] %s' % (label, 'PASS' if ok else 'FAIL'))
        bad += 0 if ok else 1
    print('mixsim_test: %s (%d checks)' % ('PASS' if bad == 0 else 'FAIL', len(checks)))
    return bad


if __name__ == '__main__':
    sys.exit(1 if run() else 0)
