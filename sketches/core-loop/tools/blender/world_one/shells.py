"""Mint a world-one mojulo shell recipe and export it to shells/<kind>.glb.

python3 shells.py <kind> [...]   (needs node 22.14+; runs `npx -y mojulo@3.0.0`)
Adapted from tools/blender/rogues/shells.py. The recipe is the source: <kind>.mojulo.json
is a workbench spec, units cm, z up, x right and +y forward (Godot -Z), ground at z = 0.
Each separately finished piece is its own sampled `fields` entry whose term ids start with
`<Piece>_`. The exported shells are local build inputs and stay out of git.
"""
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MOJULO = ["npx", "-y", "mojulo@3.0.0", "call"]


def call(tool, args):
    path = os.path.join(HERE, "shells", "." + tool + ".json")
    with open(path, "w") as f:
        json.dump(args, f)
    env = dict(os.environ, MOJULO_MCP_TOOL_TIMEOUT_MS="600000")
    out = subprocess.run(MOJULO + [tool, "--json", "@" + os.path.abspath(path)], env=env,
                         capture_output=True, text=True, check=True).stdout
    os.remove(path)
    head = out[:4000]
    if '"ok": true' not in head:
        raise SystemExit(tool + " failed: " + head[:800])
    return head


def build(kind):
    with open(os.path.join(HERE, kind + ".mojulo.json")) as f:
        spec = json.load(f)
    head = call("mint_solid", {"kind": "workbench", "title": "world one " + kind, "spec": spec})
    ref = head.split('"ref": "', 1)[1].split('"', 1)[0]
    head = call("export_model", {"ref": ref, "format": "glb", "lit": True})
    src = head.split('"path": "', 1)[1].split('"', 1)[0]
    tris = head.split('"triangles": ', 1)[1].split(",", 1)[0]
    dst = os.path.join(HERE, "shells", kind + ".glb")
    shutil.copyfile(src, dst)
    print("SHELL %s %s %s triangles" % (kind, ref, tris))


if __name__ == "__main__":
    os.makedirs(os.path.join(HERE, "shells"), exist_ok=True)
    for name in sys.argv[1:]:
        build(name)
