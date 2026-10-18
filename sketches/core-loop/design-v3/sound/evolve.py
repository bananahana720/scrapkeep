"""Evolve a standing pick onto its written theme, and master any track to SCORE.md's targets.

    python evolve.py hybrid <score dir> <cue> <stems dir> <out.wav> [--shift N] [--lead lead.wav]
    python evolve.py master <in> <out.wav> [--loop --bpm N] [--spice | --light] [--room spillway|dig|highdraft|boss|neutral]

hybrid: the kept drums and bass stems (htdemucs), pitch-shifted N semitones with Rubber Band,
plus the cue's lead line (themes.py) and its counter line where the cue has one, with each phrase
aligned to the stems' kick downbeat. The lead comes from themes.py's plain guide unless --lead
names a better one (an ACE-Step sax solo of the guide). <score dir> holds themes.py from the
score architecture branch.

master: one chain for every track, from SCORE.md "Mix and master". With a stems folder as <in>
it mixes the stems into their slots first (kick and bass centre and mono, the bass ducking under
the kick, comping high-passed and dipped at 2 to 4 kHz, the lead centre-left with presence, one
room per world on a send high-passed at 200 Hz); with a single file it applies the bus stages
only. Then: the sub and low bands cut back to at most 0.26 and 0.62 of the energy, by up to 12 dB (one owner
for the low end), 60 to 250 Hz raised up to 6 dB to at least 0.32, 2 to 5 kHz raised up to 6 dB to at least 0.09 of the 250 Hz to 2 kHz band, the stage widened above 300 Hz toward side/mid 0.16, mono below 150 Hz,
gentle bus compression, loudness to -16 LUFS by gain measured with ffmpeg's EBU R128 meter,
and a 4x-oversampled lookahead limiter at -1.2 dBTP. With --loop and --bpm the mix is cut, before loudness, to
whole bars from the kick downbeat whose wrap is closest (at most 16, a multiple of 4), its last 60 ms
replaced by the audio just before the cut.
With --spice the mix leans into the electro side: drums parallel-compressed with the kick lifted,
the bass saturated with a 900 Hz bump, the chords pumping 6 dB under the kick, sub and low held
to 0.30 and 0.58 then fitted to 0.26 and 0.62 as check_mix.py measures them, and the drums and bass above 250 Hz ramped up 3 dB from the last big switch-up, and machines.py's piston, steam and whir bed on the
grid. --light keeps the plain mix and adds only a softer machine bed, for the jazz-club tracks.
"""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, resample_poly, sosfiltfilt

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cut_loops  # noqa: E402
import machines  # noqa: E402

SR = 48000
ROOMS = {"spillway": (1.4, 0.18), "dig": (0.9, 0.14), "highdraft": (2.4, 0.22), "boss": (1.1, 0.12),
         "neutral": (1.2, 0.12)}
RNG = np.random.default_rng(1749)


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "2", "-ar", str(SR),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").astype(float).reshape(-1, 2)


def band(x, kind, f):
    return sosfiltfilt(butter(4, f, kind, fs=SR, output="sos"), x, axis=0)


def peaking(x, f0, gain_db, q=1.0):
    """A bell EQ as a parallel band: add or remove a fraction of the band-passed signal."""
    lo, hi = f0 / (2 ** (1 / (2 * q))), f0 * (2 ** (1 / (2 * q)))
    part = sosfiltfilt(butter(2, [lo, hi], "bandpass", fs=SR, output="sos"), x, axis=0)
    return x + (10 ** (gain_db / 20) - 1) * part


def pan(x, position):
    """Constant-power pan of a stereo signal's mid: -1 left, +1 right."""
    mid = x.mean(axis=1)
    a = (position + 1) * np.pi / 4
    return np.stack([mid * np.cos(a), mid * np.sin(a)], axis=1) * np.sqrt(2)


def widen(x, amount):
    mid, side = (x[:, 0] + x[:, 1]) / 2, (x[:, 0] - x[:, 1]) / 2
    side *= amount
    return np.stack([mid + side, mid - side], axis=1)


def envelope(x, attack=0.005, release=0.12):
    level = np.abs(x).max(axis=1) if x.ndim > 1 else np.abs(x)
    a, r = np.exp(-1 / (attack * SR)), np.exp(-1 / (release * SR))
    out, y = np.empty_like(level), 0.0
    for i, v in enumerate(level):
        y = a * y + (1 - a) * v if v > y else r * y + (1 - r) * v
        out[i] = y
    return out


def duck(x, key, depth_db=4.5):
    """Sidechain: x drops by up to depth_db while the key (the kick band) is loud."""
    env = envelope(band(key, "lowpass", 120))
    env /= env.max() + 1e-9
    return x * (10 ** (-depth_db * env / 20))[:, None]


def room(x, seconds, wet):
    """One shared room per world: a noise-tail impulse, high-passed at 200 Hz on the send."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = np.stack([RNG.standard_normal(n), RNG.standard_normal(n)], axis=1) * np.exp(-t * 6.9 / seconds)[:, None]
    ir = band(band(ir, "highpass", 200), "lowpass", 8000)
    ir /= np.sqrt((ir ** 2).sum(axis=0))
    send = band(x, "highpass", 200)
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    wet_sig = np.stack([np.fft.irfft(np.fft.rfft(send[:, c], size) * np.fft.rfft(ir[:, c], size), size)[:len(x)]
                        for c in range(2)], axis=1)
    return x + wet * wet_sig


def mono_lows(x, cut=150.0):
    low = band(x, "lowpass", cut)
    return x - low + low.mean(axis=1, keepdims=True)


def compress(x, threshold_db=-14.0, ratio=2.0):
    env = envelope(x, 0.01, 0.25)
    level = 20 * np.log10(env + 1e-9)
    over = np.maximum(level - threshold_db, 0)
    return x * (10 ** (-over * (1 - 1 / ratio) / 20))[:, None]


def limit(x, ceiling_db=-1.2, lookahead=0.005, release=0.08):
    """Lookahead limiter on the 4x-oversampled peak, so inter-sample peaks stay under the ceiling."""
    ceiling = 10 ** (ceiling_db / 20)
    over = np.abs(resample_poly(x, 4, 1, axis=0)).max(axis=1).reshape(-1, 4).max(axis=1)[:len(x)]
    need = np.minimum(1, ceiling / np.maximum(over, 1e-9))
    need = _window_min(need, int(lookahead * SR))
    r = np.exp(-1 / (release * SR))
    gain, g = np.empty_like(need), 1.0
    for i, v in enumerate(need):
        g = v if v < g else r * g + (1 - r) * v
        gain[i] = g
    return x * gain[:, None]


def _window_min(v, w):
    """Minimum over the next w samples, so gain reduction starts before the peak arrives."""
    from numpy.lib.stride_tricks import sliding_window_view
    padded = np.concatenate([v, np.ones(w)])
    return sliding_window_view(padded, w + 1).min(axis=1)


def lufs(x):
    with tempfile.NamedTemporaryFile(suffix=".wav") as f:
        sf.write(f.name, x.astype(np.float32), SR, subtype="FLOAT")
        log = subprocess.run(["ffmpeg", "-nostats", "-i", f.name, "-af", "ebur128=peak=true", "-f", "null", "-"],
                             capture_output=True, text=True).stderr
    summary = log[log.rindex("Summary:"):]
    return float(summary.split("I:")[1].split("LUFS")[0])


def saturate(x, drive=2.5, mix=0.5):
    """Soft-clip a copy and blend it in: grit and upper harmonics, so a bass reads on small speakers."""
    peak = np.abs(x).max() + 1e-9
    hot = np.tanh(drive * x / peak) * peak / np.tanh(drive)
    return (1 - mix) * x + mix * hot


def punch(drums):
    """Parallel-compressed drums under the dry ones, kick lifted at 60 Hz: more slam per hit."""
    crushed = compress(drums, threshold_db=-30.0, ratio=6.0)
    crushed *= np.sqrt((drums ** 2).mean() / ((crushed ** 2).mean() + 1e-12))
    return peaking(drums + 0.45 * crushed, 60, 1.0, q=0.9)


def switch_up(x, low):
    """Where the track's last big switch-up starts: the largest jump in low-band energy between
    neighbouring 4 s windows in its second half, or 70 percent of the way in when none tops 2 dB."""
    w = 4 * SR
    db = [10 * np.log10((low[i:i + w] ** 2).mean() + 1e-12) for i in range(0, len(low) - w, w // 2)]
    best, at = 0.0, int(0.7 * len(x))
    for k in range(1, len(db)):
        start = k * (w // 2)
        if start > len(x) // 2 and db[k] - db[k - 1] > best:
            best, at = db[k] - db[k - 1], start
    return at if best >= 2.0 else int(0.7 * len(x))


def mix_stems(stems, room_name, spice=False, light=False):
    s = {p.stem: load(p) for p in Path(stems).glob("*.wav")}
    n = min(len(v) for v in s.values())
    s = {k: v[:n] for k, v in s.items()}
    drums = s.get("drums", np.zeros((n, 2)))
    out = np.zeros((n, 2))
    out += punch(drums) if spice else drums
    bass = np.zeros((n, 2))
    if "bass" in s:
        bass = band(s["bass"], "lowpass", 4000)
        if spice:  # electro bass: grit and a mid bump so the line reads
            bass = peaking(saturate(bass), 900, 3.0, q=0.8)
        out += duck(pan(bass, 0.0), drums)
    comp = np.zeros((n, 2))
    for k in ("other", "piano", "guitar"):
        if k in s:
            comp += s[k]
    if comp.any():
        comp = peaking(band(comp, "highpass", 120), 3000, -2.0, q=0.7)
        comp = widen(comp, 1.3) * 0.95
        out += duck(comp, drums, 6.0) if spice else comp  # the chords pump with the kick
    if "vocals" in s:  # htdemucs files a sax lead under vocals
        lead = peaking(band(s["vocals"], "highpass", 200), 3000, 1.5, q=0.8)
        out += pan(lead, -0.12)
    if spice:  # the last switch-up hits harder: drums and bass above 250 Hz ramp up 3 dB over two seconds
        at = switch_up(out, band(drums + bass, "lowpass", 200).mean(axis=1))
        ramp = np.clip((np.arange(n) - at) / (2 * SR), 0, 1)[:, None]
        bite = band(punch(drums) + bass, "highpass", 250)
        out += (10 ** (3 / 20) - 1) * ramp * bite
    if spice or light:  # the Keepers' engines play along: pistons, steam, whirs on the grid
        out += machines.layer(drums, 0.6 if light else 1.0, light)
    seconds, wet = ROOMS[room_name]
    return room(out, seconds, wet)


def shelf_to(x, lo, hi, share_max, most_db=12):
    """Cut the lo to hi band until its share of total energy is at most share_max, by at most
    most_db: the low end gets one owner instead of swamping the mix."""
    part = band(band(x, "highpass", lo), "lowpass", hi) if lo > 20 else band(x, "lowpass", hi)
    share = (part ** 2).sum() / ((x ** 2).sum() + 1e-12)
    if share <= share_max:
        return x
    # removing a fraction g of the band leaves (1-g)^2 * share of the energy in it
    keep = max(np.sqrt(share_max * (1 - share) / (share * (1 - share_max))), 10 ** (-most_db / 20))
    return x - (1 - keep) * part


def fit_bands(x, caps=(("sub", 20, 60, 0.26), ("low", 60, 250, 0.62))):
    """Static linear-phase EQ over the whole track: each capped band is scaled down until its share
    of the 20 Hz to 16 kHz energy, measured the way check_mix.py measures it, is at most its cap.
    The gain eases over 10 Hz at each band edge."""
    spec = np.fft.rfft(x, axis=0)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    power = np.abs(spec.mean(axis=1)) ** 2  # the mono sum, as check_mix.py measures
    full = (f >= 20) & (f < 16000)
    gain = np.ones_like(f)
    for _ in range(4):
        total = (power * gain ** 2)[full].sum()
        for _, lo, hi, cap in caps:
            inside = (f >= lo) & (f < hi)
            share = (power * gain ** 2)[inside].sum() / total
            if share > cap:
                g = np.sqrt(cap * (1 - share) / (share * (1 - cap)))
                edge = np.clip(np.minimum(f - lo + 5, hi + 5 - f) / 10, 0, 1)
                gain *= 1 - (1 - g) * edge
    return np.fft.irfft(spec * gain[:, None], len(x), axis=0)


def lift_low(x, share_min=0.32, most_db=6):
    """Raise 60 to 250 Hz until it holds at least share_min of the energy, by at most most_db, so a
    bass living in the sub band still has its punch where small speakers can play it."""
    part = band(band(x, "highpass", 60), "lowpass", 250)
    share = (part ** 2).sum() / ((x ** 2).sum() + 1e-12)
    if share >= share_min:
        return x
    gain = min(np.sqrt(share_min * (1 - share) / (share * (1 - share_min))), 10 ** (most_db / 20))
    return x + (gain - 1) * part


def lift_lead(x, ratio_min=0.09, most_db=6):
    """Raise 2 to 5 kHz until it holds at least ratio_min of the 250 Hz to 2 kHz energy, by at most
    most_db, so the sax keeps its own register above the band."""
    pres = band(band(x, "highpass", 2000), "lowpass", 5000)
    body = band(band(x, "highpass", 250), "lowpass", 2000)
    ratio = (pres ** 2).sum() / ((body ** 2).sum() + 1e-12)
    if ratio >= ratio_min:
        return x
    gain = min(np.sqrt(ratio_min / max(ratio, 1e-6)), 10 ** (most_db / 20))
    return x + (gain - 1) * pres


def stage(x, target=0.16):
    """Widen the stage above 300 Hz until side/mid energy reaches the target, by at most 2.2x."""
    mid, side = (x[:, 0] + x[:, 1]) / 2, (x[:, 0] - x[:, 1]) / 2
    ratio = (side ** 2).sum() / ((mid ** 2).sum() + 1e-12)
    if ratio >= target:
        return x
    high_side = band(side, "highpass", 300)
    gain = min(np.sqrt(target / max(ratio, 1e-4)), 2.2)
    side = side + (gain - 1) * high_side
    if (side ** 2).sum() / ((mid ** 2).sum() + 1e-12) < target * 0.6:  # a near-mono source: add a Haas-free decorrelated room
        side = side + band(mid - np.roll(mid, int(0.011 * SR)), "highpass", 400) * 0.18
    return np.stack([mid + side, mid - side], axis=1)


def loop_cut(x, bpm, bars=16):
    """Whole bars from a kick downbeat, the length a multiple of 4 bars, at most `bars`. The tail is
    replaced by the 60 ms of audio just before the cut point, reached by a 60 ms equal-power
    crossfade, so the wrap plays exactly what the source played into that downbeat. Of the downbeats
    that leave room, the one whose wrap is closest in level and spectrum wins."""
    mono = band(x.mean(axis=1), "lowpass", 150)
    flux, rate = cut_loops.onset_envelope(mono, SR)
    first = int(cut_loops.phase(flux, rate, bpm) * SR)
    bar = 4 * 60 / bpm * SR
    count = min(bars, int((len(x) - first) / bar) // 4 * 4)
    if count < 4:
        return x
    length = int(round(count * bar))
    tail, fade = int(0.06 * SR), int(0.06 * SR)
    w = int(0.05 * SR)

    def build(start):
        out = x[start:start + length].copy()
        pre = x[start - tail - fade:start]
        t = np.linspace(0, np.pi / 2, fade)[:, None]
        out[-tail - fade:-tail] = out[-tail - fade:-tail] * np.cos(t) + pre[:fade] * np.sin(t)
        out[-tail:] = pre[fade:]
        return out

    def wrap(out):
        head, end = out[:w].mean(axis=1), out[-w:].mean(axis=1)
        jump = abs(10 * np.log10((head ** 2).mean() + 1e-12) - 10 * np.log10((end ** 2).mean() + 1e-12))
        sh, st = np.abs(np.fft.rfft(head)), np.abs(np.fft.rfft(end))
        sim = (sh * st).sum() / (np.linalg.norm(sh) * np.linalg.norm(st) + 1e-12)
        return jump / 3 + (1 - sim) / 0.5

    starts = [first + int(round(k * bar)) for k in range(int((len(x) - first - length) / bar) + 1)]
    starts = [s for s in starts if s >= tail + fade and s + length <= len(x)]
    if not starts:
        return x[first:first + length]
    return min((build(s) for s in starts), key=wrap)


def master(src, out, loop=False, room_name="neutral", bpm=None, spice=False, light=False):
    x = mix_stems(src, room_name, spice, light) if Path(src).is_dir() else room(load(src), *ROOMS[room_name]) if room_name != "neutral" else load(src)
    x = band(x, "highpass", 25)
    for _ in range(3 if spice else 2):
        x = shelf_to(x, 20, 60, 0.30 if spice else 0.26)
        x = shelf_to(x, 60, 250, 0.58 if spice else 0.62)
        x = lift_low(x)
    if spice or light:
        x = fit_bands(x)
    x = lift_lead(x)
    x = stage(x)
    x = mono_lows(x)
    x = compress(x)
    if loop and bpm:
        x = loop_cut(x, bpm)
    for _ in range(3):
        x *= 10 ** ((-16.0 - lufs(x)) / 20)
        x = limit(x)
    sf.write(out, x.astype(np.float32), SR, subtype="PCM_24")


def shift(path, semis, out):
    if semis:
        subprocess.run(["rubberband", "-q", "--fine", "-p", str(semis), str(path), str(out)], check=True,
                       capture_output=True)
    else:
        sf.write(out, load(path).astype(np.float32), SR, subtype="FLOAT")
    return load(out)


def hybrid(score_dir, cue, stems, out, semis=0, lead_path=None):
    sys.path.insert(0, str(score_dir))
    import themes
    with tempfile.TemporaryDirectory() as tmp:
        kept = {k: shift(Path(stems) / f"{k}.wav", semis, Path(tmp) / f"{k}.wav") for k in ("drums", "bass")}
    n = min(len(v) for v in kept.values())
    groove = kept["drums"][:n] + kept["bass"][:n]
    mono = groove.mean(axis=1)
    bpm = themes.CUES[cue]["bpm"]
    flux, rate = cut_loops.onset_envelope(mono, SR)
    offset = cut_loops.phase(flux, rate, bpm)
    seconds = n / SR + 60 / bpm * 8
    if lead_path:
        lead = load(lead_path).mean(axis=1)
    else:
        _, lead = themes.render(cue, seconds)
        if themes.SR != SR:
            lead = resample_poly(lead, SR, themes.SR)
    lead = np.concatenate([np.zeros(int(offset * SR)), lead])[:n]
    lead = np.pad(lead, (0, n - len(lead)))
    lead_st = pan(np.stack([lead, lead], axis=1), -0.12)
    rms = lambda v: np.sqrt(np.mean(v ** 2)) + 1e-9  # noqa: E731
    mix = groove + lead_st * (rms(groove) / rms(lead_st)) * 0.7
    mix *= 0.89 / np.abs(mix).max()
    sf.write(out, mix.astype(np.float32), SR, subtype="PCM_16")
    print(json.dumps(dict(cue=cue, shift=semis, beat_offset_s=round(float(offset), 3), seconds=round(n / SR, 1))))


def main(argv):
    opt = lambda name, default=None: argv[argv.index(name) + 1] if name in argv else default  # noqa: E731
    if argv[0] == "hybrid":
        hybrid(Path(argv[1]), argv[2], argv[3], argv[4], int(opt("--shift", 0)), opt("--lead"))
    elif argv[0] == "master":
        bpm = float(opt("--bpm")) if opt("--bpm") else None
        master(argv[1], argv[2], "--loop" in argv, opt("--room", "neutral"), bpm, "--spice" in argv, "--light" in argv)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
