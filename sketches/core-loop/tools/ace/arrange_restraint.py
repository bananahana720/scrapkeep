"""CPU-only v3 arrangement from the preserved v2 slices and logged engine solos."""

import csv
import hashlib
import json
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.ndimage import uniform_filter1d
from scipy.signal import stft, resample_poly

from audition import SR, bands, db, load, lufs
from retime_slice import joins_report, master, smooth_gain, timing

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'artifacts/local/v3-audio'
OUT = BASE / 'hybrid-v3'
AUDITION = Path('/home/andrew/Projects/scrapkeep-worktrees/core-loop-v3-feel-3/artifacts/local/ace-audition')
PHRASES = [('lead', .80, 1.), ('counter', .90, .85), ('choir', .85, .65), ('lead', 1.15, 1.10)]
FADE = round(.015 * SR)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def phrase_envelope(bar, phrase, gain):
    """Outgoing part reaches zero at the line, before the incoming part fades in."""
    e = np.zeros(16 * bar)
    a, z = phrase * 4 * bar, (phrase + 1) * 4 * bar
    e[a:z] = gain
    ramp = np.sin(np.linspace(0, np.pi / 2, FADE)) ** 2
    e[a:a + FADE] *= ramp
    e[z - FADE:z] *= ramp[::-1]
    return e


def spectral_rows(y, bar):
    # Fixed for all versions before comparison. Power sums across stereo channels.
    # A significant band holds >= 0.1% of that frame's total 40 Hz-16 kHz power.
    edges = np.geomspace(40, 16000, 25)
    f, t, z = stft(y.T, fs=SR, nperseg=2048, noverlap=1536, boundary=None)
    power = np.mean(np.abs(z) ** 2, axis=0)
    band_power = np.array([power[(f >= a) & (f < b)].sum(axis=0)
                           for a, b in zip(edges[:-1], edges[1:])])
    total = band_power.sum(axis=0)
    counts = np.sum(band_power >= np.maximum(total * .001, 1e-12), axis=0)
    rows = []
    for b in range(16):
        take = y[b * bar:(b + 1) * bar]
        mask = (t >= b * bar / SR) & (t < (b + 1) * bar / SR)
        rows.append(dict(bar=b + 1, crest_db=round(db(np.abs(take).max()) - db(np.sqrt(np.mean(take ** 2))), 2),
                         density_mean=round(float(counts[mask].mean()), 3),
                         density_p95=round(float(np.quantile(counts[mask], .95)), 3),
                         rms_dbfs=round(db(np.sqrt(np.mean(take ** 2))), 2)))
    return rows


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    old = json.loads((BASE / 'hybrid-v2/metrics-hybrid.json').read_text())
    layer_log = json.loads((OUT / 'engine/layers.json').read_text())
    grid = old['grid']
    bar, n = grid['samples_per_bar'], grid['frames']
    assert n == 16 * bar
    # Bind reconstructed historical activity to the exact historical waveforms.
    reference = {}
    for new, previous in [('v1-above', 'above'), ('v2-engine', 'full')]:
        a = load(OUT / f'engine/{new}.wav')
        b = load(BASE / f'hybrid/engine/engine-{previous}.wav')
        delta = float(np.max(np.abs(a - b)))
        reference[new] = dict(max_abs_sample_difference=delta, exact=bool(np.array_equal(a, b)))
        assert delta <= 1 / 32768, reference

    drums_path = BASE / 'hybrid-v2/retimed-cover-drums.candidate.wav'
    other_path = BASE / 'hybrid-v2/retimed-cover-other.candidate.wav'
    drums, other = load(drums_path), load(other_path)
    kick = load(BASE / 'hybrid/engine/engine-kick.wav')
    k = np.sqrt(uniform_filter1d(np.mean(kick * kick, axis=1), round(.003 * SR), mode='wrap'))
    duck = smooth_gain(3 * np.clip(k / max(np.quantile(k, .98), 1e-9), 0, 1),
                       1 - np.exp(-1 / (.002 * SR)), 1 - np.exp(-1 / (.090 * SR)),
                       1 - np.exp(-1 / (.150 * SR)))
    # Undo only the old synth-kick duck. Keep the repaired slices, shelf and glue.
    un_duck = 10 ** (duck[:, None] / 20)
    drums, other = drums * un_duck, other * un_duck
    synth = load(OUT / 'engine/bass.wav')
    envelopes = {'bass': np.ones(n)}
    other_gain = np.ones(n)
    for phrase, (name, gain, bed_gain) in enumerate(PHRASES):
        e = phrase_envelope(bar, phrase, gain)
        synth += load(OUT / f'engine/{name}.wav') * e[:, None]
        envelopes[name] = envelopes.get(name, np.zeros(n)) + e
        a, z = phrase * 4 * bar, (phrase + 1) * 4 * bar
        other_gain[a:z] = bed_gain
    # Smooth only level changes; leave all v2 time maps intact.
    for boundary in [0, 4 * bar, 8 * bar, 12 * bar]:
        idx = np.arange(boundary - FADE, boundary + FADE) % n
        other_gain[idx] = np.linspace(other_gain[idx[0]], other_gain[idx[-1]], len(idx))
    other *= other_gain[:, None]
    active = np.sum([env > 1e-5 for env in envelopes.values()], axis=0)
    assert int(active.max()) == 2
    audible_voices = np.zeros(n, dtype=np.int16)
    for name, envelope in envelopes.items():
        voice_count = np.zeros(n, dtype=np.int16)
        for start, length, count in layer_log[name]['voice_blocks']:
            voice_count[start:start + length] = count
        audible_voices += voice_count * (envelope > 1e-5)
    sf.write(OUT / 'arranged-engine.wav', synth, SR, subtype='PCM_24')
    sf.write(OUT / 'cover-drums.wav', drums, SR, subtype='PCM_24')
    sf.write(OUT / 'cover-other.wav', other, SR, subtype='PCM_24')
    _, mastering = master(drums + other + synth, OUT / 'hybrid-spillway-16bar.wav')
    final = load(OUT / 'hybrid-spillway-16bar.wav')
    guide = load(AUDITION / 'guide-spillway-16bar.drums.wav')[:n]
    after = timing(drums, guide, kick, bar, 16)
    cuts = old['variants']['slice']['edits']['joins']
    bed_joins = joins_report(drums + other, other, bar, 16, cuts)
    mix_joins = joins_report(final, other, bar, 16, cuts)
    arrangement_cuts = [dict(beat=b * 4 + 1, sample=b * bar - FADE if b else n - FADE,
                            fade_ms=30) for b in (0, 4, 8, 12)]
    arrangement_joins = joins_report(final, other, bar, 16, arrangement_cuts)
    inputs = {'v1': BASE / 'hybrid/hybrid-spillway-16bar.wav',
              'v2': BASE / 'hybrid-v2/hybrid-spillway-16bar.wav',
              'v3': OUT / 'hybrid-spillway-16bar.wav'}
    comparison, rows = {}, []
    for version, path in inputs.items():
        y = load(path)
        spectral = spectral_rows(y, bar)
        if version == 'v3':
            lag, joins = after, bed_joins
        else:
            lag = old['variants']['drift' if version == 'v1' else 'slice']
            joins = lag['joins']
        for b, spec in enumerate(spectral):
            if version == 'v3':
                name = PHRASES[b // 4][0]
                layers = ['bass', name]
                voices = audible_voices[b * bar:(b + 1) * bar]
                max_voices, mean_voices = int(voices.max()), float(voices.mean())
            else:
                log = layer_log['v1-above' if version == 'v1' else 'v2-engine']['per_bar'][b]
                layers = log['layers']
                max_voices, mean_voices = log['max_voices'], log['mean_voices']
            rows.append(dict(version=version, **spec, synth_layers=' '.join(layers),
                             synth_layer_count=len(layers), synth_max_voices=max_voices,
                             synth_mean_voices=round(mean_voices, 2),
                             lag_ms=lag['after_drift']['lag_ms_per_bar'][b],
                             kick_reference_offset_ms=lag['flam_downbeat']['lag_ms_per_bar'][b],
                             join_over_p999_db=joins['per_bar'][b]['max_step_over_body_p999_db'],
                             energy_jump_db=joins['per_bar'][b]['max_abs_energy_jump_db']))
        comparison[version] = dict(lufs=round(lufs(y), 2),
            true_peak_dbtp=round(db(np.abs(resample_poly(y, 4, 1, axis=0)).max()), 2),
            crest_db=round(db(np.abs(y).max()) - db(np.sqrt(np.mean(y * y))), 2),
            density_mean=round(float(np.mean([s['density_mean'] for s in spectral])), 3),
            density_p95_mean=round(float(np.mean([s['density_p95'] for s in spectral])), 3),
            max_bar_lag_ms=max(abs(v) for v in lag['after_drift']['lag_ms_per_bar']),
            max_quarter_lag_ms=max(lag['worst_beat_residual_ms']),
            max_kick_reference_offset_ms=max(abs(v) for v in lag['flam_downbeat']['lag_ms_per_bar']),
            max_join_over_p999_db=max(r['max_step_over_body_p999_db'] for r in joins['per_bar']),
            max_energy_jump_db=max(r['max_abs_energy_jump_db'] for r in joins['per_bar']), bands=bands(y))
    decoded = load(OUT / 'opus-decoded.wav')
    checks = dict(length=final.shape == decoded.shape == (n, 2), finite=bool(np.isfinite(final).all()),
                  wav_lufs=abs(lufs(final) + 14) < .1, opus_lufs=abs(lufs(decoded) + 14) < .2,
                  wav_true_peak=comparison['v3']['true_peak_dbtp'] < -1,
                  opus_true_peak=mastering['opus']['true_peak_dbtp'] < -1,
                  layer_cap=int(active.max()) <= 4,
                  one_kit=not bool(set(envelopes) & {'kick', 'snare', 'hats', 'fleet'}),
                  sparser_than_v2=comparison['v3']['density_mean'] < comparison['v2']['density_mean'],
                  no_denser_than_v1=comparison['v3']['density_mean'] <= comparison['v1']['density_mean'])
    density = {v: np.array([r['density_mean'] for r in rows if r['version'] == v]) for v in inputs}
    checks['sparser_than_v2_every_bar'] = bool(np.all(density['v3'] < density['v2']))
    checks['no_denser_than_v1_every_bar'] = bool(np.all(density['v3'] <= density['v1']))
    with (OUT / 'per-bar.csv').open('w') as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    metrics = dict(grid=grid, supplied_base='c519926; not queried with Git', cpu_only=True,
        historical_render_validation=reference, comparison=comparison, checks=checks,
        processing=dict(synth_core_floor=0, pressure=.6, intensity=.6, fade_ms=15,
                        glue='v2 shared 2:1, mean 1.5 dB reduction retained', high_shelf_db=-3,
                        synth_kick_duck='removed by inverse gain', phases=PHRASES),
        mastering=mastering, timing=after, bed_joins=bed_joins, mix_joins=mix_joins,
        arrangement_joins=arrangement_joins,
        density_method='24 log bands 40-16000 Hz, 2048-sample Hann STFT, hop 512; significant >=0.1% frame band power; frame counts averaged per bar, then bars',
        layer_method='Scheduled nonzero-gain synth layers/voices. v1/v2 exact engine rerender validation. Cover is two stems, not two inferred voices. v3 voice blocks summed at matching sample positions after phrase gates. Chord buffers count as one engine voice, not one musical note.',
        limitations=['Cover internal instruments and voice counts are unknown.',
                     'Kick offsets in v3 are reference mismatch, not a two-kit flam.',
                     'Density is a spectral occupancy proxy, not human perceived busyness.',
                     'Historical quarter-lag failures persist; this is an arrangement audition, not an engine-ready timing qualification.'])
    (OUT / 'metrics-hybrid.json').write_text(json.dumps(metrics, indent=2) + '\n')
    sources = [Path(__file__), Path(__file__).with_name('retime_slice.py'),
               ROOT / 'sketches/core-loop/tools/ace_restraint_v3.gd',
               ROOT / 'sketches/core-loop/src/presentation/music_engine.gd',
               drums_path, other_path, BASE / 'hybrid-v2/metrics-hybrid.json',
               ROOT / 'sketches/core-loop/tools/ace_guide_v3.gd',
               Path(__file__).with_name('audition.py'),
               *sorted((OUT / 'engine').glob('*.wav')),
               OUT / 'engine/layers.json', *inputs.values(), OUT / 'hybrid-spillway-16bar.opus']
    (OUT / 'hashes.json').write_text(json.dumps({str(p.relative_to(ROOT)): digest(p) for p in sources}, indent=2) + '\n')
    print(json.dumps(dict(comparison=comparison, checks=checks, mastering=mastering), indent=2), flush=True)


if __name__ == '__main__':
    main()
