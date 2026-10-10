# sand_ground: promoted from the asset forge (tools/asset-forge), pack core-loop, v001.
# Run inside Blender's Python with tools/asset-forge/kinds/terrain on sys.path (texlib.py);
# the forge's terrain entry calls build(params) and writes the maps. Original procedural code.

import numpy as np
import texlib as tl


def build(params):
    n = 512
    pal = params["palette"]

    # big slabs: cell borders near 0 are cracks
    edge = tl.worley(n, 4, 11, "edge")
    edge = tl.warp(edge, 30, 3, 12)
    cracks = 1.0 - tl.smoothstep(0.0, 0.12, edge)  # 1 in crack
    # slab tops: each plate tilts a little, flat painted steps
    plate_id = tl.worley(n, 4, 11, "id")
    plate_id = tl.blur(tl.warp(plate_id, 30, 3, 12), 1.5)
    slab = tl.posterize(plate_id, 4, 0.3)

    # wind-scoured hollows
    hollow = tl.warp(tl.fbm(n, 3, 3, 21, "value"), 24, 3, 22)
    hollow = tl.posterize(hollow, 5, 0.4)
    mid = tl.fbm(n, 8, 3, 23, "value")

    h = 0.55 * hollow + 0.25 * slab + 0.12 * mid
    h = tl.normalize(h)
    h = h * (1.0 - 0.7 * tl.blur(cracks, 3.0))
    h = tl.normalize(tl.blur(h, 1.2))

    # stains: separate broad blotches, pushed to the oxide end of the ramp
    stain = tl.warp(tl.fbm(n, 3, 2, 31, "value"), 30, 3, 32)
    stain = tl.smoothstep(0.62, 0.72, stain)

    # one scalar for colour: petrol in cracks, oxide stains, sandstone body, bone on crests
    t = 0.55 + 0.16 * (h - 0.5) + 0.04 * (slab - 0.5)
    t = t - 0.17 * stain
    t = t - 0.5 * tl.blur(cracks, 2.5)
    t = np.clip(t, 0, 1)
    albedo = tl.ramp(
        t,
        [(0.0, "petrol"), (0.14, "petrol"), (0.26, "oxide"), (0.4, "sandstone"),
         (0.75, "sandstone"), (1.0, "bone")],
        pal,
        steps=10,
    )
    # keep it gentle: the ramp itself is the palette, no blending out of it
    rough = np.clip(0.88 + 0.1 * (0.5 - h), 0, 1)
    return {
        "height": h,
        "albedo": albedo,
        "roughness": rough,
        "normal_strength": 1.8,
        "uv_scale": 1.0,
    }
