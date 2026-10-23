"""Verify the field crew's shipped clip GLBs (field_motion.py, src/presentation/enemy_clips.gd).

  python3 verify_field_clips.py [--kind chaser] [--rebuild] [--selftest]

It reads the GLBs Godot loads. Per kind, from the JSON and binary chunks:

  1. a clips-only file: no mesh, one skin, exactly the six clips;
  2. windup is the attack's lead in the enemy script within one 30 fps frame, attack is the
     strike's live time capped at field_motion.ATTACK_CAP, and nothing is longer than 4 s;
  3. idle and move loop: every channel's last key equals its first;
  4. windup starts at rest and hit and attack end at rest, so the hard cuts never pop;
  5. idle never out-moves the wind-up (the idle is never read as a telegraph): the idle's
     largest rotation and squash stay under the wind-up's, and under 20 degrees and 6%;
  6. the file is under 64 KiB.

--rebuild also rebuilds every clip file with field_motion.py into a scratch directory (bpy
needed) and requires the shipped bytes to match exactly. --selftest seeds a broken seam, a
wrong wind-up length and an extra mesh into copies and requires each to FAIL. Prints
`FIELD_CLIPS: PASS <kind> 6 clips` per kind and exits 0, or `FIELD_CLIPS: FAIL <kind>: <why>`
and exits 1.
"""
import argparse
import json
import math
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
SKETCH = HERE.parents[1]
CLIP_DIR = SKETCH / "assets/models/world_one/clips"
FPS = 30
CLIPS = ("idle", "move", "windup", "attack", "hit", "death")
KINDS = ("chaser", "lobber", "mag_trapper", "plated_brute", "winch_drone", "jolt_layer")
SIZE_CAP = 64 * 1024
TOL = 1e-4
IDLE_ROT_CAP = 20.0
IDLE_SCALE_CAP = 0.06
COMPONENTS = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}

sys.path.insert(0, str(HERE / "world_one"))


def read_glb(data):
    size = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + size])
    at = 20 + size
    blob = b""
    if at < len(data):
        length = struct.unpack_from("<I", data, at)[0]
        blob = data[at + 8:at + 8 + length]
    return doc, blob


def accessor(doc, blob, index):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    width = COMPONENTS[acc["type"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    flat = struct.unpack_from("<%df" % (acc["count"] * width), blob, start)
    return [flat[i * width:(i + 1) * width] for i in range(acc["count"])]


def channels(doc, blob):
    """{clip: {(bone, path): (times, values)}} and {bone: rest translation}."""
    names = {i: n.get("name") for i, n in enumerate(doc["nodes"])}
    rests = {n.get("name"): tuple(n.get("translation", (0, 0, 0))) for n in doc["nodes"]}
    out = {}
    for anim in doc.get("animations", []):
        rows = {}
        for ch in anim["channels"]:
            sampler = anim["samplers"][ch["sampler"]]
            rows[(names[ch["target"]["node"]], ch["target"]["path"])] = (
                [t[0] for t in accessor(doc, blob, sampler["input"])], accessor(doc, blob, sampler["output"]))
        out[anim["name"]] = rows
    return out, rests


def at_rest(path, value, rest):
    if path == "translation":
        return all(abs(a - b) <= TOL for a, b in zip(value, rest))
    if path == "rotation":
        return abs(abs(value[3]) - 1.0) <= TOL
    return all(abs(a - 1.0) <= TOL for a in value)


def angle(q):
    return math.degrees(2 * math.acos(min(1.0, abs(q[3]))))


def peaks(rows, rests):
    rot, squash = 0.0, 0.0
    for (bone, path), (_, values) in rows.items():
        for v in values:
            if path == "rotation":
                rot = max(rot, angle(v))
            elif path == "scale":
                squash = max(squash, max(abs(c - 1.0) for c in v))
    return rot, squash


def leads():
    import field_motion as fm
    return {
        "chaser": (fm.snap(fm.const("chaser", "WINDUP")), fm.snap(min(fm.const("chaser", "LUNGE_TIME"), fm.ATTACK_CAP))),
        "lobber": (fm.snap(fm.const("lobber", "TELEGRAPH")), None),
        "mag_trapper": (fm.snap(fm.configured("mag_trapper", "warn_seconds")), None),
        "plated_brute": (fm.snap(fm.configured("plated_brute", "warn_seconds")), None),
        "winch_drone": (fm.snap(fm.configured("winch_drone", "warn_seconds")), None),
        "jolt_layer": (fm.snap(fm.configured("jolt_layer", "warn_seconds")), None),
    }, fm.ATTACK_CAP


def verify(kind, data, lead_table, attack_cap):
    if len(data) > SIZE_CAP:
        return "file %d bytes over %d" % (len(data), SIZE_CAP)
    doc, blob = read_glb(data)
    if doc.get("meshes"):
        return "a clips file carries no mesh"
    if len(doc.get("skins", [])) != 1:
        return "one motion skin, found %d" % len(doc.get("skins", []))
    clips, rests = channels(doc, blob)
    if sorted(clips) != sorted(CLIPS):
        return "clips %s" % sorted(clips)
    lengths = {name: max(max(t) for t, _ in rows.values()) for name, rows in clips.items()}
    windup, attack = lead_table[kind]
    if abs(lengths["windup"] - windup) > 1.0 / FPS + TOL:
        return "windup %.4f s against the lead %.4f s" % (lengths["windup"], windup)
    if attack is not None and abs(lengths["attack"] - attack) > 1.0 / FPS + TOL:
        return "attack %.4f s against the strike %.4f s" % (lengths["attack"], attack)
    if lengths["attack"] > attack_cap + 1.0 / FPS:
        return "attack %.4f s over the cap" % lengths["attack"]
    if max(lengths.values()) > 4.0:
        return "a clip over 4 s"
    for name in ("idle", "move"):
        for (bone, path), (times, values) in clips[name].items():
            if any(abs(a - b) > TOL for a, b in zip(values[0], values[-1])):
                return "%s seam: %s %s first %s last %s" % (name, bone, path, values[0], values[-1])
    for name, index, where in (("windup", 0, "starts"), ("hit", -1, "ends"), ("attack", -1, "ends")):
        for (bone, path), (_, values) in clips[name].items():
            if not at_rest(path, values[index], rests.get(bone, (0, 0, 0))):
                return "%s %s off rest: %s %s %s" % (name, where, bone, path, values[index])
    idle_rot, idle_squash = peaks(clips["idle"], rests)
    wind_rot, wind_squash = peaks(clips["windup"], rests)
    if idle_rot > IDLE_ROT_CAP or idle_squash > IDLE_SCALE_CAP:
        return "idle peaks %.1f deg, %.3f squash over the caps" % (idle_rot, idle_squash)
    if idle_squash >= wind_squash:
        return "idle squash %.3f reaches the wind-up's %.3f" % (idle_squash, wind_squash)
    return None


def rebuild(kinds):
    """Rebuilds into a scratch copy of the clip folder and compares bytes."""
    import field_motion as fm
    failures = {}
    with tempfile.TemporaryDirectory(prefix="scrapkeep-vfc-") as scratch:
        for kind in kinds:
            fm.OUT = scratch
            fm.build(kind)
            fresh = (Path(scratch) / (kind + "_clips.glb")).read_bytes()
            shipped = (CLIP_DIR / (kind + "_clips.glb")).read_bytes()
            if fresh != shipped:
                failures[kind] = "rebuild differs from the shipped bytes"
    return failures


def selftest(lead_table, attack_cap):
    data = (CLIP_DIR / "chaser_clips.glb").read_bytes()
    assert verify("chaser", data, lead_table, attack_cap) is None, "clean chaser must pass"
    doc, blob = read_glb(data)

    def pack(d, b):
        text = json.dumps(d, separators=(",", ":")).encode()
        text += b" " * ((4 - len(text) % 4) % 4)
        body = b"".join([struct.pack("<I4s", len(text), b"JSON"), text, struct.pack("<I4s", len(b), b"BIN\x00"), b])
        return struct.pack("<4sII", b"glTF", 2, 12 + len(body)) + body

    broken = {}
    meshy = json.loads(json.dumps(doc))
    meshy["meshes"] = [{"primitives": []}]
    broken["extra mesh"] = pack(meshy, blob)
    wrong = dict(lead_table)
    wrong["chaser"] = (lead_table["chaser"][0] + 0.2, lead_table["chaser"][1])
    # A broken seam: shift the first output of the idle's first channel.
    seam_blob = bytearray(blob)
    idle = next(a for a in doc["animations"] if a["name"] == "idle")
    sampler = idle["samplers"][idle["channels"][0]["sampler"]]
    acc = doc["accessors"][sampler["output"]]
    view = doc["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    value = struct.unpack_from("<f", seam_blob, start)[0]
    struct.pack_into("<f", seam_blob, start, value + 0.25)
    broken["broken seam"] = pack(doc, bytes(seam_blob))
    ok = True
    for label, bad in broken.items():
        result = verify("chaser", bad, lead_table, attack_cap)
        print("SELFTEST %s -> %s" % (label, "FAIL as required" if result else "PASSED (wrong)"))
        ok = ok and result is not None
    result = verify("chaser", data, wrong, attack_cap)
    print("SELFTEST wrong wind-up -> %s" % ("FAIL as required" if result else "PASSED (wrong)"))
    return ok and result is not None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--kind")
    parser.add_argument("--rebuild", action="store_true")
    parser.add_argument("--selftest", action="store_true")
    opts = parser.parse_args()
    kinds = [opts.kind] if opts.kind else list(KINDS)
    lead_table, attack_cap = leads()
    failed = False
    if opts.selftest and not selftest(lead_table, attack_cap):
        print("FIELD_CLIPS: FAIL selftest")
        failed = True
    rebuilt = rebuild(kinds) if opts.rebuild else {}
    for kind in kinds:
        path = CLIP_DIR / (kind + "_clips.glb")
        why = "missing" if not path.exists() else verify(kind, path.read_bytes(), lead_table, attack_cap)
        why = why or rebuilt.get(kind)
        if why:
            failed = True
            print("FIELD_CLIPS: FAIL %s: %s" % (kind, why))
        else:
            print("FIELD_CLIPS: PASS %s %d clips%s" % (kind, len(CLIPS), " (rebuild byte-identical)" if opts.rebuild else ""))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
