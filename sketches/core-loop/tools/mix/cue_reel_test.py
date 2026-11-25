"""The cue reel on a synthetic run: a clear and a busy clip a sound, the right lengths, the tsv's counts and the mixsim margin."""
import io
import json
import sys
import tempfile
import wave
from contextlib import redirect_stdout
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cue_reel

RATE = 44100


def run():
    with tempfile.TemporaryDirectory(prefix='reel-') as folder:
        root = Path(folder)
        seconds = 12
        x = (np.random.default_rng(7).uniform(-0.2, 0.2, seconds * RATE) * 32767).astype(np.int16)
        w = wave.open(str(root / 'run.wav'), 'wb')
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(np.repeat(x, 2).tobytes())
        w.close()
        rows = [
            [0.2, 'landed', 'thud', 'now', 1.0, -6.0],
            [2.0, 'landed', 'thud', 'now', 1.0, -6.0],
            [5.0, 'landed', 'thud', 'now', 1.0, -6.0],
            [5.05, 'shot_fired', 'zap', 'now', 1.0, -9.0],
            [5.1, 'hit_on_beat', 'zap', 'beat', 1.0, None],
            [4.98, 'scrap_collected', 'tick', 'now', 1.0, -12.0],
            [5.22, 'strike_deflected', 'clank', 'now', 1.0, -9.0],
            [8.0, 'shot_fired', 'zap', 'now', 1.0, -9.0],
            [6.0, 'line_state_changed', 'hum', 'stop', 1.0, None],
            [7.0, 'tune', 'band', 'music', 1.0, None],
        ]
        (root / 'run.json').write_text(json.dumps({'cue_rows': rows, 'mix_states': [[0.0, 'roam'], [4.0, 'combat']]}))
        (root / 'run.mixsim.txt').write_text('RUN x\n\nHEARD OR BURIED  each\n  sound starts median buried\n'
            '  thud                                2   -3.5    50%    -13.9  -6.0  zap 1\n  zap 3 +4.0 0% -2.0 -9.0\n\n  median: dB\n')
        out = io.StringIO()
        sys.argv = ['cue_reel.py', str(root / 'run.wav'), str(root / 'reel')]
        with redirect_stdout(out):
            code = cue_reel.main()
        assert code == 0, code
        table = [line.split('\t') for line in (root / 'reel' / 'reel.tsv').read_text().splitlines()[1:]]
        by_clip = {row[0]: row for row in table}
        assert sorted(by_clip) == ['01_zap__busy.wav', '01_zap__clear.wav', '02_thud__busy.wav', '02_thud__clear.wav'], sorted(by_clip)
        clear, busy = by_clip['02_thud__clear.wav'], by_clip['02_thud__busy.wav']
        assert (clear[4], clear[5], clear[6]) == ('2.00', 'roam', '0'), clear
        assert (busy[4], busy[5], busy[6]) == ('5.00', 'combat', '3'), busy
        assert clear[8] == '-3.5' and by_clip['01_zap__clear.wav'][8] == '+4.0', (clear, by_clip['01_zap__clear.wav'])
        zap_clear, zap_busy = by_clip['01_zap__clear.wav'], by_clip['01_zap__busy.wav']
        assert (zap_clear[2], zap_clear[4], zap_clear[6]) == ('shot_fired', '8.00', '0'), zap_clear
        assert (zap_busy[2], zap_busy[4], zap_busy[6]) == ('hit_on_beat', '5.10', '3'), zap_busy
        clip = wave.open(str(root / 'reel' / '02_thud__busy.wav'))
        assert clip.getnframes() == int(2.5 * RATE) and clip.getnchannels() == 2, clip.getnframes()
        data = np.frombuffer(clip.readframes(clip.getnframes()), dtype=np.int16).reshape(-1, 2)
        assert data[0, 0] == 0 and abs(int(data[-1, 0])) <= 1, 'the clip fades in and out'
        want = x[int(4.2 * RATE) + 2000:int(4.2 * RATE) + 2100]
        assert np.array_equal(data[2000:2100, 0], want), 'the clip is the recording from 0.8 s before the start'
        assert not np.array_equal(data[2000:2100, 0], x[int(5.0 * RATE) + 2000:int(5.0 * RATE) + 2100]), 'not from the start itself'
        long = 'a_sound_with_a_name_longer_than_thirty_letters'
        rows += [[3.0, 'x', long, 'now', 1.0, -6.0], [9.0, 'x', long, 'now', 1.0, -6.0]]
        (root / 'run.json').write_text(json.dumps({'cue_rows': rows, 'mix_states': []}))
        (root / 'run.mixsim.txt').write_text('HEARD OR BURIED  each\n  %s 2 +1.5 0%% -2.0 -6.0\n\n' % long[:30])
        sys.argv = ['cue_reel.py', str(root / 'run.wav'), str(root / 'long'), '--ids=' + long]
        with redirect_stdout(io.StringIO()):
            assert cue_reel.main() == 0
        assert (root / 'long' / 'reel.tsv').read_text().splitlines()[1].split('\t')[8] == '+1.5'
        sys.argv = ['cue_reel.py', str(root / 'run.wav'), str(root / 'named'), '--ids=tick,nope']
        with redirect_stdout(io.StringIO()):
            assert cue_reel.main() == 0
        named = (root / 'named' / 'reel.tsv').read_text().splitlines()[1:]
        assert len(named) == 1 and named[0].startswith('01_tick__clear.wav'), named
    print('cue_reel_test: pass')


if __name__ == '__main__':
    run()
