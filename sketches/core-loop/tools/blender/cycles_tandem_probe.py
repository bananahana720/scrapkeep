"""Times glb_stills.py on both GPUs against the 4080 alone, one TSV row per run, for re-fitting
cycles_device.TANDEM_MIN. Run from the repo root on an idle PC. Both modes are explicit, so the
helper's capture routing doesn't apply and a run would void a 4080 capture: the probe stops before
any run while cycles_device.capture_on() is true.

  python3 sketches/core-loop/tools/blender/cycles_tandem_probe.py [--glb G] [--views V] [--runs 3] \
      SIZExSAMPLES [SIZExSAMPLES ...]

Each run times SCRAPKEEP_CYCLES=all and =4080, swapping which goes first, so a warm cache favours
neither. Columns: glb, width, height, samples, views, sample_px_view, mode, run, wall_s. Wall is the whole Blender process, start to exit,
so it includes Blender's start and the GLB import (the same in both modes).
"""
import argparse
import os
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cycles_device  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
STILLS = os.path.join(HERE, "glb_stills.py")
GLB = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models", "warden_swarm.glb"))
MODES = ("all", "4080")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("jobs", nargs="+", help="SIZExSAMPLES, e.g. 3840x1024")
    p.add_argument("--glb", default=GLB)
    p.add_argument("--views", default="three-quarter")
    p.add_argument("--runs", type=int, default=3)
    p.add_argument("--blender", default=os.environ.get("BLENDER", "blender"))
    a = p.parse_args()
    print("glb\twidth\theight\tsamples\tviews\tsample_px_view\tmode\trun\twall_s", flush=True)
    for job in a.jobs:
        size, samples = (int(v) for v in job.lower().split("x"))
        height = int(size * 0.75)  # glb_stills renders size x 0.75 size
        for run in range(1, a.runs + 1):
            for mode in MODES if run % 2 else MODES[::-1]:
                if cycles_device.capture_on():
                    raise SystemExit("cycles_tandem_probe: a 4080 capture is running (%s or %s); stopped"
                                     % (cycles_device.CAPTURE_FILE, cycles_device.CAPTURE_LOCK))
                with tempfile.TemporaryDirectory() as out:
                    env = dict(os.environ, SCRAPKEEP_CYCLES=mode)
                    start = time.monotonic()
                    subprocess.run([a.blender, "-b", "--factory-startup", "-P", STILLS, "--", "--glb", a.glb,
                                    "--out", out, "--size", str(size), "--samples", str(samples), "--views", a.views],
                                   env=env, check=True, stdout=subprocess.DEVNULL)
                    wall = time.monotonic() - start
                print("%s\t%d\t%d\t%d\t%d\t%.3g\t%s\t%d\t%.2f" % (
                    os.path.basename(a.glb), size, height, samples, len(a.views.split(",")),
                    size * height * samples, mode, run, wall), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
