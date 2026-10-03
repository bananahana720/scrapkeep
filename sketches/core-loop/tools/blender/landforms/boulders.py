"""Ten independent origin-centred fractured blocks, metres; no exported layout."""
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cliff_strata as kit

NAME = "boulders"
SIZES = [(0.6, 0.45, 0.33), (0.85, 0.7, 0.5), (1.1, 0.65, 0.8),
         (1.4, 1.0, 0.45), (1.8, 1.3, 1.2), (2.2, 1.3, 0.7),
         (2.65, 1.8, 1.65), (3.1, 2.15, 1.2), (3.6, 2.6, 2.2), (4, 2.8, 2.6)]


def build():
    root = kit.common.empty(NAME)
    for i, size in enumerate(SIZES):
        tone = kit.blend(kit.SAND, kit.BUFF if i % 3 else kit.RED, 0.65)
        obj = kit.block("boulder_%02d" % (i + 1), size, 271000 + i, tone)
        kit.attach(root, obj)
        print("LKR_BOULDER", obj.name, size, kit.common.tris(obj), flush=True)
    return root


if __name__ == "__main__":
    kit.deliver(build, NAME)
