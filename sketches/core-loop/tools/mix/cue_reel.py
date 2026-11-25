#!/usr/bin/env python3
"""Cuts a recorded run into short clips of each sound on its event, for the ear.

    python3 cue_reel.py <run.wav> <out folder> [--top=24] [--ids=a,b,c] [--min-starts=2]

A bounce of one sound says what it is; it does not say what it is like in the game. This cuts
the whole-mix recording of a bot run (tools/ace_bounce.gd) around each sound's starts: once
at the start with the fewest other sounds starting beside it (clear) and once at the one with
the most (busy), so a listener hears the sound at its best and at its most crowded, with the
band and everything else playing. It is the "check in the running game" and the clips for the
"one page" of a taste pick (ruling cq); each candidate is a run cut the same way.

For each sound, by number of starts (or the ones named with --ids):
  NN_<sound>__clear.wav, NN_<sound>__busy.wav   0.8 s before the start to 1.7 s after
  reel.tsv   one row a clip: the start and its event, the game's mix state there, how many other sounds
             start within 150 ms, the mix's level over the 150 ms after the start against
             the 150 ms before, and the sound's median margin from <run>.mixsim.txt when
             mixsim.py has been run on the same recording (under 0: it leads no band).
Rows that stop a sound, and the band's own rows, are not starts and are left out. numpy only.
"""
import sys, os, json, math, wave
from collections import defaultdict
import numpy as np

BEFORE, AFTER, NEAR, FADE = 0.8, 1.7, 0.15, 0.02
STARTS = ("now", "beat", "bar")


def options(argv):
    opts = {"top": 24, "ids": [], "min-starts": 2}
    rest = []
    for a in argv:
        if a.startswith("--") and "=" in a:
            key, value = a[2:].split("=", 1)
            opts[key] = [v for v in value.split(",") if v] if key == "ids" else int(value)
        else:
            rest.append(a)
    return opts, rest


def margins(path):
    """sound -> median margin in dB, from a mixsim.py report; empty when there is none."""
    got = {}
    if not os.path.exists(path):
        return got
    inside = False
    for line in open(path):
        if line.startswith("HEARD OR BURIED"):
            inside = True
            continue
        part = line.split()
        if inside and len(part) >= 3 and part[1].isdigit():
            try:
                got[part[0]] = float(part[2])
            except ValueError:
                pass
        elif inside and not line.strip() and got:
            break
    return got


def state_at(states, t):
    name = ""
    for at, state in states:
        if at > t:
            break
        name = state
    return name


def db(seg):
    return 20 * math.log10(max(float(np.sqrt(np.mean(seg ** 2))) if len(seg) else 0.0, 1e-9))


def pick(rows, opts, seconds):
    """[(sound, [(start, others starting within NEAR, the start's event)])], most starts first.

    Every row that starts a sound counts, with or without a level in the log (a cue started
    on the beat has none)."""
    starts = sorted((float(r[0]), str(r[2])) for r in rows if r[3] in STARTS)
    times = np.array([t for t, _ in starts])
    by_sound = defaultdict(list)
    for r in rows:
        if r[3] not in STARTS:
            continue
        t, sound = float(r[0]), str(r[2])
        if t < BEFORE or t + AFTER > seconds:
            continue
        lo, hi = np.searchsorted(times, t - NEAR), np.searchsorted(times, t + NEAR)
        others = sum(1 for _, name in starts[lo:hi] if name != sound)
        by_sound[sound].append((t, others, str(r[1])))
    names = [n for n in by_sound if len(by_sound[n]) >= opts["min-starts"]]
    if opts["ids"]:
        names = [n for n in opts["ids"] if n in by_sound]
    names.sort(key=lambda n: -len(by_sound[n]))
    if not opts["ids"]:
        names = names[:opts["top"]]
    return [(n, by_sound[n]) for n in names]


def main():
    opts, rest = options(sys.argv[1:])
    if len(rest) != 2:
        print(__doc__)
        return 2
    path, out = rest
    w = wave.open(path)
    rate, ch, n = w.getframerate(), w.getnchannels(), w.getnframes()
    x = np.frombuffer(w.readframes(n), dtype=np.int16).reshape(-1, ch)
    mono = x.mean(axis=1) / 32768.0
    base = path.rsplit(".", 1)[0]
    meta = json.load(open(base + ".json"))
    margin = margins(base + ".mixsim.txt")
    os.makedirs(out, exist_ok=True)
    fade = np.linspace(0.0, 1.0, int(FADE * rate))
    lines = ["clip\tsound\tevent\tstarts\tat_s\tmix_state\tothers_within_150ms\tmix_after_less_before_db\tmixsim_median_db"]
    near = int(NEAR * rate)
    for i, (sound, starts) in enumerate(pick(meta.get("cue_rows", []), opts, n / rate), 1):
        clear = min(starts, key=lambda s: (s[1], s[0]))
        busy = max(starts, key=lambda s: (s[1], -s[0]))
        led = margin.get(sound[:30])
        for label, (t, others, kind) in (("clear", clear), ("busy", busy)):
            if label == "busy" and busy == clear:
                continue
            a = int((t - BEFORE) * rate)
            clip = x[a:a + int((BEFORE + AFTER) * rate)].astype(np.float64)
            clip[:len(fade)] *= fade[:, None]
            clip[-len(fade):] *= fade[::-1, None]
            name = "%02d_%s__%s.wav" % (i, sound.replace("/", "_").replace(":", "_"), label)
            o = wave.open(os.path.join(out, name), "wb")
            o.setnchannels(ch)
            o.setsampwidth(2)
            o.setframerate(rate)
            o.writeframes(np.clip(np.round(clip), -32768, 32767).astype(np.int16).tobytes())
            o.close()
            at = int(t * rate)
            lift = db(mono[at:at + near]) - db(mono[at - near:at])
            lines.append("%s\t%s\t%s\t%d\t%.2f\t%s\t%d\t%+.1f\t%s" % (
                name, sound, kind, len(starts), t, state_at(meta.get("mix_states", []), t), others, lift,
                "" if led is None else "%+.1f" % led))
    open(os.path.join(out, "reel.tsv"), "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))
    print("%d clips in %s" % (len(lines) - 1, out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
