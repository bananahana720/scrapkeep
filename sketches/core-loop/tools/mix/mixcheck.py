#!/usr/bin/env python3
"""Reads a whole-mix recording of a bot run (tools/ace_bounce.gd) against its cue times.

    python3 mixcheck.py <run.wav>

Three questions a bounce of single sounds cannot answer (the json beside the wav gives the cue times):
  1. Does the mix clip or sit on the limiter, and which cues were sounding when it did?
  2. Which cues start together, and how loud is the mix where they pile up?
  3. Does the level follow the game? The mix's level in each stretch of the game's own mix
     state (roaming, a fight, a boss), and its spread across the run.
Which sound buries which is mixsim.py's question: a recording cannot answer it, because
forty sounds a second start together.
numpy only. Output: <run>.mixcheck.txt beside the recording, and the same on stdout.
"""
import sys, os, json, math, wave
from collections import defaultdict
import numpy as np

path = sys.argv[1]
bank = sys.argv[2] if len(sys.argv) > 2 else ""
w = wave.open(path)
rate, ch, n = w.getframerate(), w.getnchannels(), w.getnframes()
raw = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float64) / 32768.0
x = raw.reshape(-1, ch)
mono = x.mean(axis=1)
meta = json.load(open(path.rsplit(".", 1)[0] + ".json"))
# A "room", "duck" or "restore" row (MixRows.MAKE_ROOM, audio.gd _log_gain) is a level change, not a start.
cues = [c for c in meta.get("cue_rows", []) if c[0] >= 0 and c[3] not in ("room", "duck", "restore")]
out = []


def say(s=""):
    out.append(s)


def db(v):
    return 20 * math.log10(max(v, 1e-9))


def k_weight(freqs):
    shelf = 1 + (10 ** (4 / 20) - 1) / (1 + (1681.97 / np.maximum(freqs, 1)) ** 2)
    hp = 1 / np.sqrt(1 + (38.13 / np.maximum(freqs, 1)) ** 4)
    return shelf * hp


def loud(seg):
    if len(seg) < 64:
        return -120.0
    spec = np.fft.rfft(seg)
    f = np.fft.rfftfreq(len(seg), 1 / rate)
    p = np.sum(np.abs(spec * k_weight(f)) ** 2) * 2 / (len(seg) ** 2)
    return -0.691 + 10 * math.log10(max(p, 1e-12))


def band(seg, lo, hi):
    spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg)))) ** 2
    f = np.fft.rfftfreq(len(seg), 1 / rate)
    return float(np.sum(spec[(f >= lo) & (f <= hi)])) + 1e-15


# --- 1. The whole mix -------------------------------------------------------------------
secs = len(mono) / rate
win = int(0.4 * rate)
st = [loud(mono[i:i + win]) for i in range(0, len(mono) - win, win // 2)]
gated = [v for v in st if v > -50]
peak = float(np.max(np.abs(x)))
hot = np.abs(x).max(axis=1) >= 0.985
say("MIX  %.1f s, %d cues with a start time, %d kinds of sound" % (secs, len(cues), len({c[2] for c in cues})))
say("  loudness (400 ms windows): median %.1f, loudest %.1f, quietest sounding %.1f" % (np.median(gated), max(gated), min(gated)))
say("  peak %.2f dBFS; samples within 0.13 dB of full scale: %d (%.3f%% of the run)" % (db(peak), int(hot.sum()), 100.0 * hot.sum() / len(hot)))

# Hot stretches: runs of near-full-scale samples, merged when under 50 ms apart.
idx = np.flatnonzero(hot)
runs = []
for i in idx:
    if runs and i - runs[-1][1] < 0.05 * rate:
        runs[-1][1] = i
        runs[-1][2] += 1
    else:
        runs.append([i, i, 1])
runs.sort(key=lambda r: -r[2])
say("")
say("HOT  the mix at full scale (limiter or clip), worst first, with the cues that started in the 150 ms before")
if not runs:
    say("  none")
for a, b, count in runs[:12]:
    t = a / rate
    near = [c[2] for c in cues if t - 0.15 <= c[0] <= t + 0.02]
    say("  %7.2f s  %4d samples over %3.0f ms   %s" % (t, count, (b - a) * 1000 / rate, ", ".join(near) or "(no cue: the band alone)"))

# --- 2. Pile-ups ------------------------------------------------------------------------
bins = defaultdict(list)
for c in cues:
    bins[int(c[0] / 0.04)].append(c[2])
piles = sorted(bins.items(), key=lambda kv: -len(kv[1]))
say("")
say("PILE-UPS  cues that start inside the same 40 ms, biggest first")
for b, names in piles[:10]:
    if len(names) < 3:
        break
    a = int(b * 0.04 * rate)
    seg = np.abs(x[a:a + int(0.2 * rate)])
    say("  %7.2f s  %2d cues  peak %.1f dBFS  %s" % (b * 0.04, len(names), db(float(seg.max()) if len(seg) else 0), ", ".join(sorted(names))))
sizes = [len(v) for v in bins.values()]
say("  starts alone: %d; in twos: %d; three or more together: %d" % (sizes.count(1), sizes.count(2), sum(1 for s in sizes if s >= 3)))

# --- 3. Level by what the game is doing ---------------------------------------------------
# A set needs contrast: the breath quieter than the build, the drop louder than both. This is
# the level of the whole mix in each stretch of the game's own mix state.
s50 = int(0.05 * rate)
r = np.array([math.sqrt(float(np.mean(mono[i:i + s50] ** 2))) for i in range(0, len(mono) - s50, s50)])
r = 20 * np.log10(np.maximum(r, 1e-9))
r = r[r > -60]
say("")
say("CONTRAST  level of the whole mix (rms, dBFS)")
say("  across the run, 50 ms at a time: quiet tenth %.1f, median %.1f, loud tenth %.1f, loudest hundredth %.1f" % (
    np.percentile(r, 10), np.median(r), np.percentile(r, 90), np.percentile(r, 99)))
states = meta.get("mix_states", [])
for i, (t, name) in enumerate(states):
    t2 = states[i + 1][0] if i + 1 < len(states) else secs
    if t2 - t >= 3:
        seg = mono[int(t * rate):int(t2 * rate)]
        say("  %-10s %6.1f to %6.1f s   %.1f" % (name, t, t2, db(math.sqrt(float(np.mean(seg ** 2))))))

text = "\n".join(out)
open(path.rsplit(".", 1)[0] + ".mixcheck.txt", "w").write(text + "\n")
print(text)
