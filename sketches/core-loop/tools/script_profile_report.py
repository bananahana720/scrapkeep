"""Slowest frames in a tools/script_profile.gd capture, with their costliest script functions.

    python3 tools/script_profile_report.py <capture.jsonl> [frames=5] [functions=12]
    python3 tools/script_profile_report.py <capture.jsonl> --agg [last_frames=600] [functions=40]

--agg sums self and total time per function over the last N frames (ms per frame) and per
script file, for flat profiles where no single frame stands out. The profiler roughly doubles
frame time, so read the ranking, not the absolute numbers.
"""
import collections
import json
import sys


def functions(frame):
    i = 7
    for _ in range(int(frame[6])):
        i += 2 + int(frame[i + 1])
    count = int(frame[i]) // 5
    i += 1
    return [(int(frame[i + 5 * k]), int(frame[i + 5 * k + 1]), frame[i + 5 * k + 2], frame[i + 5 * k + 3]) for k in range(count)]


def main(path, top_frames=5, top_functions=12):
    names, frames = {}, []
    with open(path) as lines:
        for line in lines:
            row = json.loads(line)
            if row["kind"] == "servers:function_signature":
                names[int(row["data"][1])] = row["data"][0]
            else:
                frames.append(row["data"])
    for frame in sorted(frames, key=lambda f: -f[1])[:top_frames]:
        print("frame %d: %.0f ms (process %.0f, physics %.0f)" % (frame[0], frame[1] * 1000, frame[2] * 1000, frame[3] * 1000))
        for sig, calls, self_s, total_s in sorted(functions(frame), key=lambda f: -f[3])[:top_functions]:
            print("  total %7.1f  self %7.1f  x%-6d %s" % (total_s * 1000, self_s * 1000, calls, names.get(sig, sig)))


def aggregate(path, last=600, top=40):
    names, frames = {}, []
    with open(path) as lines:
        for line in lines:
            row = json.loads(line)
            if row["kind"] == "servers:function_signature":
                names[int(row["data"][1])] = row["data"][0]
            else:
                frames.append(row["data"])
    frames = frames[-last:]
    n = max(len(frames), 1)
    selfs, totals, calls = collections.Counter(), collections.Counter(), collections.Counter()
    for frame in frames:
        for sig, c, self_s, total_s in functions(frame):
            selfs[sig] += self_s
            totals[sig] += total_s
            calls[sig] += c
    print("frames=%d mean frame=%.2f ms" % (len(frames), sum(f[1] for f in frames) / n * 1000))
    print("--- top self (ms/frame)")
    for sig, v in selfs.most_common(top):
        print("%7.3f  total %7.3f  calls/frame %7.1f  %s" % (v / n * 1000, totals[sig] / n * 1000, calls[sig] / n, names.get(sig, sig)))
    print("--- by file (self ms/frame)")
    by_file = collections.Counter()
    for sig, v in selfs.items():
        by_file[str(names.get(sig, sig)).split("::")[0]] += v
    for name, v in by_file.most_common(30):
        print("%7.3f  %s" % (v / n * 1000, name))


if __name__ == "__main__":
    if "--agg" in sys.argv:
        rest = [a for a in sys.argv[1:] if a != "--agg"]
        aggregate(rest[0], *[int(a) for a in rest[1:3]])
    else:
        main(sys.argv[1], *[int(a) for a in sys.argv[2:4]])
