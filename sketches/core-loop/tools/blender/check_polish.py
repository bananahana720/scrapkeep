# Builds a recipe twice in fresh Blender processes with polish enabled and fails unless
# the two GLBs are byte-identical (POLISH.md).
#
#   blender -b --factory-startup -P check_polish.py -- <recipe.py relative to here> [option=value ...]
#
# Recipe budget asserts are left to the recipe: an unpolished recipe can stop on its own
# old cap, so run this on recipes that already opted in, or pass options a recipe allows.

import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))

RUNNER = """
import os, runpy, sys
sys.path.insert(0, {here!r})
import common, polish
opts = {{}}
for pair in {pairs!r}:
    key, value = pair.split("=")
    opts[key] = float(value) if "." in value else (value == "True" if value in ("True", "False") else int(value))
if not getattr(polish, "options")():
    polish.enable(**opts)
sys.argv = [{recipe!r}, "--", "--out", {out!r}]
runpy.run_path({recipe!r}, run_name="__main__")
"""


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not argv:
        raise SystemExit("usage: check_polish.py -- <recipe.py> [option=value ...]")
    recipe = os.path.join(HERE, argv[0])
    blender = os.environ.get("BLENDER", "blender")
    outs = []
    with tempfile.TemporaryDirectory() as tmp:
        for run in (1, 2):
            out = os.path.join(tmp, "run%d.glb" % run)
            script = os.path.join(tmp, "run%d.py" % run)
            with open(script, "w") as f:
                f.write(RUNNER.format(here=HERE, pairs=argv[1:], recipe=recipe, out=out))
            subprocess.run([blender, "-b", "--factory-startup", "-P", script], check=True,
                           stdout=subprocess.DEVNULL)
            outs.append(open(out, "rb").read())
    if outs[0] != outs[1]:
        raise SystemExit("POLISH_CHECK FAIL %s: rebuilds differ" % argv[0])
    print("POLISH_CHECK OK %s: %d bytes, identical" % (argv[0], len(outs[0])))


main()
