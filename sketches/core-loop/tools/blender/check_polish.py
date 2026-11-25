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
sys.argv = [{recipe!r}, "--", {flag!r}, {out!r}]
runpy.run_path({recipe!r}, run_name="__main__")
"""


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not argv:
        raise SystemExit("usage: check_polish.py -- <recipe.py> [option=value ...]")
    recipe = os.path.join(HERE, argv[0])
    blender = os.environ.get("BLENDER", "blender")
    multi = "--out-dir" in open(recipe).read()
    outs = []
    with tempfile.TemporaryDirectory() as tmp:
        for run in (1, 2):
            out = os.path.join(tmp, "run%d" % run + ("" if multi else ".glb"))
            script = os.path.join(tmp, "run%d.py" % run)
            with open(script, "w") as f:
                f.write(RUNNER.format(here=HERE, pairs=argv[1:], recipe=recipe, out=out,
                                      flag="--out-dir" if multi else "--out"))
            subprocess.run([blender, "-b", "--factory-startup", "--python-exit-code", "1", "-P", script],
                           check=True, stdout=subprocess.DEVNULL)
            if multi:
                outs.append({n: open(os.path.join(out, n), "rb").read()
                             for n in sorted(os.listdir(out)) if n.endswith(".glb")})
            else:
                outs.append({os.path.basename(argv[0]): open(out, "rb").read()})
    if not outs[0] or outs[0] != outs[1]:
        bad = sorted(n for n in set(outs[0]) | set(outs[1]) if outs[0].get(n) != outs[1].get(n))
        raise SystemExit("POLISH_CHECK FAIL %s: rebuilds differ %s" % (argv[0], bad or "(no GLBs)"))
    for name, data in outs[0].items():
        print("POLISH_CHECK OK %s %s: %d bytes, identical" % (argv[0], name, len(data)))


main()
