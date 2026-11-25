#!/usr/bin/env python3
"""Which effects bury which: a run's effect layer rebuilt from its cue log.

    python3 mixsim.py <run.json> <folder from bounce_ids.gd> [<out.txt>]

A recording of the whole mix cannot say which of forty sounds a second is heard, because
they start together. This rebuilds the effect layer exactly instead: every cue the run
logged is placed at its start, at its pitch and level, with the game's own voice limit, and
summed. Then, for every start, the sound's loudest 150 ms is compared with everything else
sounding in that window (other voices of the same sound left out), a third of an octave at a time. A sound is heard when it leads in
at least one band. Its score is the best band's margin over the rest, in dB; the median
over all its starts is the number reported.

What this does not hear: the music (it is not in the cue log), the bus levels (one gain for
all effects at a moment, so it does not change who buries whom), distance and the limiter.
numpy only.
"""
import sys, os, json, math
from collections import defaultdict, Counter
import numpy as np

run = json.load(open(sys.argv[1]))
src = sys.argv[2]
out_path = sys.argv[3] if len(sys.argv) > 3 else sys.argv[1].rsplit(".", 1)[0] + ".mixsim.txt"
RATE = 44100
VOICE_LIMIT = {"weapon_zap": 3, "scrap_tick": 3, "cog_tick": 3, "hit_thwack": 3, "kill_pop": 3, "enemy_arrive": 2,
               "beacon_hum": 1, "hop": 2, "land_thud": 2, "hurt": 2, "babble": 1, "rarity_tick": 2, "panel_note": 3,
               "clank": 2, "grapple_clink": 2, "swarm_buzz": 2, "kill_chain_tier": 1, "achievement_chime": 1,
               "rescue_fanfare": 1}
VOICE_DEFAULT = int(os.environ.get("VOICE_DEFAULT", "3"))
WIN = int(0.15 * RATE)

bufs = {}
for line in open(os.path.join(src, "ids.tsv")):
    r = line.rstrip("\n").split("\t")
    if len(r) < 5 or r[1] == "NONE":
        continue
    x = np.fromfile(os.path.join(src, r[1] + ".f32"), dtype=np.float32).astype(np.float64)
    rate = int(r[2])
    if rate != RATE and len(x) > 1:
        n = int(len(x) * RATE / rate)
        x = np.interp(np.arange(n) * rate / RATE, np.arange(len(x)), x)
    bufs[r[0]] = x


def pitched(x, p):
    if abs(p - 1.0) < 1e-3 or len(x) < 2:
        return x
    n = max(2, int(len(x) / p))
    return np.interp(np.arange(n) * p, np.arange(len(x)), x)


cues = []
missing = Counter()
unlevelled = Counter()
other = Counter()
stops = []
gains = defaultdict(list)
has_room = False
for row in run["cue_rows"]:
    t, kind, sound, how = row[0], row[1], row[2], row[3]
    if how == "stop" and t >= 0:
        stops.append((t, sound))
        continue
    if how == "room":
        has_room = True
        continue
    if how in ("duck", "restore") and t >= 0:
        gains[(sound, float(row[4]))].append((t, float(row[5]) if how == "duck" else 0.0))
        continue
    placed = how == "now" or (kind == "set_answer" and len(row) > 5 and row[5] is not None)
    if not placed or t < 0:
        if t >= 0:
            other[how] += 1
        continue
    if sound not in bufs:
        missing[sound] += 1
        continue
    if len(row) < 6 or row[5] is None:
        unlevelled[sound] += 1
        continue
    pitch = float(row[4]) if row[4] else 1.0
    vol = float(row[5])
    cues.append({"t": t, "kind": kind, "sound": sound, "pitch": pitch if 0.1 < pitch < 8 else 1.0, "db": vol})
if has_room and not run.get("duck_log"):
    print("This take predates duck logging: its room rows say a room was made, not which voices it ducked, so the room effect is not modelled. Record the take again with the current game.")
    sys.exit(2)
cues.sort(key=lambda c: c["t"])
total_len = int((max(c["t"] for c in cues) + 6) * RATE)
mix = np.zeros(total_len)
own_layer = {}
live = defaultdict(list)
for i, c in enumerate(cues):
    x = pitched(bufs[c["sound"]], c["pitch"]) * (10 ** (c["db"] / 20))
    a = int(c["t"] * RATE)
    x = x[:total_len - a].copy()
    c["a"], c["x"], c["cut"] = a, x, len(x)
    voices = [j for j in live[c["sound"]] if cues[j]["a"] + cues[j]["cut"] > a]
    limit = VOICE_LIMIT.get(c["sound"], VOICE_DEFAULT)
    while len(voices) >= limit:
        old = cues[voices.pop(0)]
        old["cut"] = max(0, a - old["a"])
        old["stolen"] = True
    voices.append(i)
    live[c["sound"]] = voices
for t, sound in stops:
    at = int(t * RATE)
    for c in cues:
        if c["sound"] == sound and c["a"] <= at < c["a"] + c["cut"]:
            c["cut"] = at - c["a"]
            c["stolen"] = True
            c["stopped"] = True
for c in cues:
    g = np.ones(len(c["x"]))
    for t, db in sorted(gains.get((c["sound"], c["t"]), []), key=lambda r: r[0]):
        g[max(int(t * RATE) - c["a"], 0):] = 10 ** (db / 20)
    c["x"] *= g
for c in cues:
    x = c["x"][:c["cut"]].copy()
    if c.get("stolen") and len(x) > 64:
        x[-64:] *= np.linspace(1, 0, 64)
    c["x"] = x
    mix[c["a"]:c["a"] + len(x)] += x
    layer = own_layer.setdefault(c["sound"], np.zeros(total_len))
    layer[c["a"]:c["a"] + len(x)] += x

edges = [50 * 2 ** (k / 3) for k in range(0, 26)]
freqs = np.fft.rfftfreq(WIN, 1 / RATE)
band_of = np.digitize(freqs, edges) - 1
valid = (band_of >= 0) & (band_of < len(edges) - 1)
TAPER = 64


def bands(seg, n=WIN):
    n = max(256, min(n, WIN))
    w = np.zeros(WIN)
    k = min(n, len(seg))
    w[:k] = seg[:k]
    tp = min(TAPER, k // 2)
    if tp > 0:
        w[:tp] *= np.linspace(0, 1, tp)
        w[k - tp:k] *= np.linspace(1, 0, tp)
    p = np.abs(np.fft.rfft(w)) ** 2
    return np.bincount(band_of[valid], weights=p[valid], minlength=len(edges) - 1)


by_sound = defaultdict(list)
for i, c in enumerate(cues):
    if len(c["x"]) < 32:
        by_sound[c["sound"]].append((-60.0, -1, 0.0))
        continue
    k = min(WIN, len(c["x"]))
    off = 0
    if len(c["x"]) > WIN:
        e = np.concatenate([[0.0], np.cumsum(c["x"] ** 2)])
        off = int(np.argmax(e[WIN:] - e[:-WIN]))
    own = c["x"][off:off + k]
    a0 = c["a"] + off
    rest = (mix[a0:a0 + k] - own_layer[c["sound"]][a0:a0 + k])
    c["k"], c["a0"] = k, a0
    bo, br = bands(own, k), bands(rest, k)
    keep = bo >= 0.05 * bo.sum()
    margin = 10 * np.log10((bo + 1e-15) / (br + 1e-12))
    margin[~keep] = -200
    b = int(np.argmax(margin))
    whole = 10 * math.log10((bo.sum() + 1e-15) / (br.sum() + 1e-12))
    c["best"], c["band"], c["whole"] = float(min(margin[b], 60.0)), b, whole
    by_sound[c["sound"]].append((c["best"], b, whole))

masker = defaultdict(Counter)
order = np.argsort([c["a"] for c in cues])
starts = np.array([cues[j]["a"] for j in order])
for i, c in enumerate(cues):
    if c.get("best", 99) >= 0:
        continue
    lo, hi = np.searchsorted(starts, c["a0"] - 3 * RATE), np.searchsorted(starts, c["a0"] + WIN)
    best, name = 0.0, ""
    for j in order[lo:hi]:
        o = cues[j]
        if o["sound"] == c["sound"] or o["a"] + len(o["x"]) <= c["a0"]:
            continue
        s0 = max(0, c["a0"] - o["a"])
        lead = max(0, o["a"] - c["a0"])
        seg = np.concatenate([np.zeros(lead), o["x"][s0:s0 + c["k"] - lead]]) if lead < c["k"] else np.zeros(0)
        if len(seg) < 32:
            continue
        e = bands(seg, c["k"])[c["band"]]
        if e > best:
            best, name = e, o["sound"]
    if name:
        masker[c["sound"]][name] += 1

lines = []
say = lines.append
dur = cues[-1]["t"] - cues[0]["t"]
say("RUN  %s, stage %s, %.0f s; %d effect starts placed (%.1f a second), %d sounds" % (
    run.get("policy", "?"), run.get("stage", "?"), dur, len(cues), len(cues) / dur, len(by_sound)))
if missing:
    say("  not placed (no buffer): " + ", ".join("%s x%d" % kv for kv in missing.most_common()))
if unlevelled:
    say("  not placed (no level in the log: loops and voices): " + ", ".join("%s x%d" % kv for kv in unlevelled.most_common()))
pk = float(np.max(np.abs(mix)))
say("  effect layer alone, before the bus: peak %.1f dB against full scale" % (20 * math.log10(pk)))
if other:
    say("  not placed (started on the beat, the bar or by the band; no level in the log): " + ", ".join("%s x%d" % kv for kv in other.most_common()))
stolen = Counter(c["sound"] for c in cues if c.get("stolen") and not c.get("stopped"))
say("  voices cut short by the voice limit: %d (%s)" % (sum(stolen.values()), ", ".join("%s %d" % kv for kv in stolen.most_common(6))))
say("")
say("HEARD OR BURIED  each sound's best band against everything else sounding, median over its starts")
say("  %-30s %6s %7s %7s %8s %7s  %s" % ("sound", "starts", "median", "buried", "whole", "level", "most often under"))
rows = []
for name, got in by_sound.items():
    best = np.array([g[0] for g in got])
    whole = np.array([g[2] for g in got])
    level = float(np.median([c["db"] for c in cues if c["sound"] == name]))
    rows.append((float(np.median(best)), name, len(got), float(np.mean(best < 0)), float(np.median(whole)), level,
                 ", ".join("%s %d" % kv for kv in masker[name].most_common(3))))
rows.sort()
for med, name, count, share, whole, level, under in rows:
    say("  %-30s %6d %+6.1f  %5.0f%%  %+7.1f %+6.1f  %s" % (name[:30], count, med, share * 100, whole, level, under))
say("")
say("  median: dB by which the sound leads its best third-octave band. Under 0 it does not lead anywhere.")
say("  buried: share of its starts that lead no band. whole: its energy against all else in the window.")
say("  level: the median level the game played it at, in dB (trim, priority, crowd and distance).")

open(out_path, "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
