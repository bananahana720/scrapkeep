"""Slowest frames in a tools/script_profile.gd capture, with their costliest script functions.

    python3 tools/script_profile_report.py <capture.jsonl> [frames=5] [functions=12]
"""
import json
import sys


def functions(frame):
    # [number, frame_s, process_s, physics_s, physics_step_s, script_s, servers, (name, n, n values)..., m, (id, calls, self_s, total_s, internal_s)...]
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


if __name__ == "__main__":
    main(sys.argv[1], *[int(a) for a in sys.argv[2:4]])
