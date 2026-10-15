# PD-0 neutral Hoberman shell: the shared base from shell_base.hoberman() with no pilot
# machinery, petrol lattice, bone seat and a neutral weapon seat. It is a test fixture
# (registry ships: false) for cage_contract_test, the look rows and the pilot units' diffs.
# Concept: artifacts/local/alpha/push/w13/concepts/codex/base/base-hero.png and mechanism.png
# (the approved base pictures, docs/decisions.tsv w13-look rows).
#
#   prlimit --as=12884901888 -- blender --background --threads 2 --python-exit-code 1 \
#     --python world_one/shell_neutral.py -- [--out <file.glb>] [--pairs N] [--cheap] [--count-only]
#     [--strut W] [--cap D]
#
# --strut and --cap set the bar face width and tread cap diameter in metres (defaults
# shell_base.BAR_WIDTH and CAP_WIDTH, PD-0b's strut table).
# --pairs sets the X-pairs per hub-to-hub link (default 2), --cheap uses 6-sided hub drums
# and caps, and --count-only prints the TRIS and HOBERMAN lines without exporting, for the
# budget table at 2, 3 and 5 pairs (ROSTER-LOOK section 5).

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import common  # noqa: E402
import shell_base as sb  # noqa: E402

# Shell class cap (assets/asset_budgets.json): 11,000 tris. The 6,600 base target is reported.
SHELL_BAND = (3000, 11000)
TARGET_TRIS = 6600


def flag(name, default=None):
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if name not in argv:
        return default
    i = argv.index(name)
    return argv[i + 1] if i + 1 < len(argv) and not argv[i + 1].startswith("--") else True


def main():
    common.reset()
    pairs = int(flag("--pairs", 2))
    sides = 6 if flag("--cheap") else 8
    strut = float(flag("--strut", sb.BAR_WIDTH))
    cap = float(flag("--cap", sb.CAP_WIDTH))
    shell = sb.hoberman("Neutral", enamel="petrol", seat="bone", pairs=pairs, hub_sides=sides, cap_sides=sides,
                        strut_width=strut, cap_width=cap)
    tris = common.tri_total(shell["root"], skip=(shell["pilot"].name,))
    core_tris = common.tris(shell["core"])
    print("HOBERMAN Neutral pairs=%d hub_sides=%d strut=%.3f cap=%.3f tris=%d core=%d rest=%d target=%d %s"
          % (pairs, sides, strut, cap, tris, core_tris, tris - core_tris, TARGET_TRIS, "fits" if tris <= TARGET_TRIS else "over"))
    print("HUBS %d GAPS %d" % (len(shell["hubs"]), len(shell["gaps"])))
    if flag("--count-only"):
        return
    out = common.args()["out"] or os.path.join(common.MODELS, "world_one", "shell_neutral.glb")
    sb.finish("Neutral", shell["root"], shell["core"], shell["pilot"], shell_band=SHELL_BAND,
              pod_obj=shell["pod"], out=out)


main()
