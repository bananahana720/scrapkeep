import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import common
import shell_base as sb

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
