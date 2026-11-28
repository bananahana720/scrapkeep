"""Named Godot test, raw receipts, scratch failure probes and final file fence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
SKETCH = HERE.parents[2]
ROOT = SKETCH.parents[1]
MODELS = SKETCH / "assets/models/dig_stone"
EVIDENCE = ROOT / "artifacts/local/dress-preview/MDS"
GODOT = Path.home() / ".local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64"
TEST = "dress_mds_assets_test"


def untracked_uids():
    data = subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard", "-z"], cwd=ROOT)
    return {p.decode() for p in data.split(b"\0") if p.endswith(b".uid")}


def run(command, label, env, expect=0):
    before = untracked_uids()
    result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=180)
    output = result.stdout + result.stderr
    (EVIDENCE / (label + ".log")).write_text(output)
    for relative in untracked_uids() - before:
        (ROOT / relative).unlink()
    for match in re.finditer(r"^receipt (.+)$", output, re.M):
        path = Path(match.group(1).strip())
        destination = EVIDENCE / (label + "-receipt.json")
        if path.is_file() and path.parent == ROOT / "artifacts/local/receipts":
            path.replace(destination)
    print(label + ": exit=" + str(result.returncode), flush=True)
    for line in output.splitlines():
        if TEST + ":" in line or "MDS_BUDGET" in line or "sketch:smoke " in line or " -> FAIL" in line:
            print(line, flush=True)
    assert result.returncode == expect, (command, result.returncode, expect, output[-2000:])
    return output


def over_budget(path):
    payload = path.read_bytes()
    jsize = struct.unpack_from("<I", payload, 12)[0]
    doc = json.loads(payload[20:20 + jsize])
    binary = payload[28 + jsize:]
    doc["meshes"][0]["primitives"] *= 2
    packed = json.dumps(doc, separators=(",", ":")).encode()
    packed += b" " * (-len(packed) % 4)
    path.write_bytes(struct.pack("<III", 0x46546C67, 2, 28 + len(packed) + len(binary))
                     + struct.pack("<II", len(packed), 0x4E4F534A) + packed
                     + struct.pack("<II", len(binary), 0x004E4942) + binary)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--previews", action="store_true")
    opt = parser.parse_args()
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="mds-verify-") as temporary:
        temp = Path(temporary)
        env = dict(os.environ, XDG_CONFIG_HOME=str(temp / "config"), XDG_CACHE_HOME=str(temp / "cache"), XDG_DATA_HOME=str(temp / "data"))
        smoke = ["node", "scripts/sketch-smoke.mjs", "--sketch", "core-loop", "--test", TEST + ".gd"]
        run(smoke, "named-pass", env)
        raw = [str(GODOT), "--headless", "--path", str(SKETCH), "--script", "res://tests/" + TEST + ".gd"]
        output = run(raw, "asset-test", env)
        assert TEST + ": PASS" in output and " -> FAIL" not in output
        assert len(re.findall(r"^MDS_BUDGET ", output, re.M)) == 8
        missing = temp / "missing"
        shutil.copytree(MODELS, missing)
        (missing / "bed_floor.glb").unlink()
        failed = run(raw + ["--", "--mds-model-dir=" + str(missing)], "broken-missing", env, expect=1)
        assert TEST + ": FAIL" in failed and "bed_floor GLB exists -> FAIL" in failed
        over = temp / "over-budget"
        shutil.copytree(MODELS, over)
        over_budget(over / "cut_face_long.glb")
        failed = run(raw + ["--", "--mds-model-dir=" + str(over)], "broken-budget", env, expect=1)
        assert TEST + ": FAIL" in failed and "cut_face_long landform budget 8000 triangles / 24000 imported vertices / 1 draw / 1 material -> FAIL" in failed
        print("MDS_BROKEN_RULE: PASS (missing GLB and over-budget GLB both fail)", flush=True)
    manifest = json.loads((MODELS / "manifest.json").read_text())
    if opt.previews:
        receipt = json.loads((EVIDENCE / "release/preview-receipt.json").read_text())
        assert len(receipt) == 8
        for row in manifest["assets"]:
            preview = next(p for p in receipt if p["asset"] == row["file"])
            assert preview["renderer"] in ("Cycles CPU", "Cycles GPU") and preview["reference_ball_diameter_m"] == 2
            assert preview["glb_sha256"] == row["sha256"]
            assert {p["view"] for p in preview["views"]} == {"front", "side", "three-quarter"}
            for view in preview["views"]:
                png = EVIDENCE / "release" / view["file"]
                assert hashlib.sha256(png.read_bytes()).hexdigest() == view["sha256"]
        print("MDS_PREVIEWS: PASS (24 hashed CPU views of final GLB bytes)", flush=True)
    changed = subprocess.check_output(["git", "status", "--short", "-uall"], cwd=ROOT, text=True)
    (EVIDENCE / "git-status.txt").write_text(changed)
    allowed = ("sketches/core-loop/tools/blender/dig_stone/", "sketches/core-loop/assets/models/dig_stone/", "artifacts/local/dress-preview/MDS/")
    single = {"sketches/core-loop/assets/materials/dig_stone/stone.tres", "sketches/core-loop/tests/dress_mds_assets_test.gd"}
    for line in changed.splitlines():
        relative = line[3:]
        assert relative in single or relative.startswith(allowed), "outside fence: " + relative
    sizes = {str(p.relative_to(ROOT)): p.stat().st_size for p in sorted(HERE.glob("*")) if p.is_file()}
    sizes.update({str(p.relative_to(ROOT)): p.stat().st_size for p in sorted(MODELS.glob("*")) if p.is_file() and not p.name.endswith(".import")})
    for relative in single:
        sizes[relative] = (ROOT / relative).stat().st_size
    (EVIDENCE / "file-sizes.json").write_text(json.dumps(sizes, indent=2) + "\n")
    print("MDS_FENCE: PASS (%d changed files, all owned)" % len(changed.splitlines()), flush=True)
    print("MDS_VERIFY: PASS", flush=True)


if __name__ == "__main__":
    main()
