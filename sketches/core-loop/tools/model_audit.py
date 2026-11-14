#!/usr/bin/env python3
"""Model audit over exported GLB files: mesh and clip faults, and outlines at play size.

    python3 tools/model_audit.py faults   <glb or glob>... [--out=<json>]
    python3 tools/model_audit.py outlines <glb or glob>... --out=<dir> [--ppm=32] [--pitch=35] [--yaw=30] [--seed=7]
    python3 tools/model_audit.py cover    <LOD0 glb or glob>... [--out=<json>]

It reads the GLB the game loads, not the Blender scene, and needs no engine. `faults` needs numpy; `outlines`
also needs Pillow. Both report and exit 0: a finding is a candidate for a look, never a verdict.

faults, per file (rest pose, world space):
  degenerate   triangles with no area.
  zero_normal  vertices whose normal is shorter than 0.5.
  flipped      triangles whose three vertex normals, summed, point against the face's winding: the face is lit as
               if it faced the other way. Count and area, to set against the file's area_m2. A flipped face can
               be shut inside the body and never seen; look before fixing.
  doubled      a triangle drawn twice with the same winding (overdraw and z-fight). Count and area. Faces are
               matched inside one surface only, corners on the same WELD grid point.
  two_sided    a triangle drawn twice with opposite winding: a sheet modelled with both faces. Listed, not a fault.
  bad_weights  skinned vertices whose weights do not sum to 1 (2% slack); zero_weights, the ones that sum to 0;
               over4, the ones with more than four influences (Godot keeps four).
  snaps        clip steps on one node that are fast (over SNAP_DEG degrees a second or SNAP_M metres a second) and
               over SNAP_RATIO times both neighbouring steps: one frame that jumps. `held` is true when the sampler
               is STEP, which is a held pose by design. A clip's first and last step have one neighbour and are
               not tested. A number cannot tell style from fault: check the clip's pose table for keys one frame
               apart and draw the frames (tools/anim_clip_capture.gd) before calling one a pop.

A skinned surface is placed by its joints in their rest pose (the first four influences; its normals turn with
the blended joints, which is exact unless a joint is scaled unevenly), and a mirrored node's winding is reversed.

outlines: each model as a filled black outline from the play camera's side (orthographic, `pitch` down, `yaw`
round), feet on a shared ground point, at `ppm` pixels a metre. 32 is a 1080p frame through a 60 degree lens from
30 m. Writes to --out:
  outlines.json       each outline's area in pixels and every pair's overlap (shared area over joined area, 1 is
                      identical), highest first. The canvas is sized to hold the largest model whole.
  outlines-blind.jpg  the outlines at that size, in shuffled order under letters. Give this sheet, and nothing
                      else, to a reviewer who has not seen the game and ask what each one is and does.
  outlines-key.json   letter to file name, for scoring the answers afterwards.
cover, per LOD0 file with `<name>_lod1.glb` and `<name>_lod2.glb` beside it: how much of LOD0's outline each lower LOD
still fills, seen from COVER_YAWS round at COVER_PITCH down (a far prop seen across the map), on a COVER_PX grid across
LOD0's width. The score is the worst view's share of LOD0's filled cells that the LOD also fills (1 is whole). A
collapse that eats a part leaves a hole the faults scan cannot see: on 14 Nov the dam's cable drums drew as floating
rings at 100 m with no face flipped (W1-29). The props kit raises a LOD's triangles until it reaches COVER_MIN, and a LOD
under COVER_FLOOR fails (a thin prop, ropes and fronds, may stop between the two at the kit's cap). Pure numpy, so the
kit can call it inside Blender.

An outline has no colour, motion or sound. A high overlap or a wrong blind answer says the shape is not doing the
work on its own; whether it matters in play is for a PC photograph and a person.
"""
import glob
import json
import random
import struct
import sys
from pathlib import Path

import numpy as np

SNAP_DEG = 360.0
SNAP_M = 3.0
SNAP_RATIO = 4.0
WEIGHT_SLACK = 0.02
WELD = 1e-4                  # grid step, metres: corners on the same grid point are one point when matching faces
AREA_EPS = 1e-9
MARGIN_M = 0.25              # clear canvas round the largest outline
COVER_YAWS = 6               # views round a model for `cover`
COVER_PITCH = 12.0           # degrees down: a far prop is seen nearly side on
COVER_PX = 128               # grid cells across LOD0's widest reach
COVER_MIN = 0.85             # the share of LOD0's outline the kit aims for a lower LOD to fill, worst view
COVER_FLOOR = 0.80           # under this a LOD fails (the drums that drew as rings filled 0.70 to 0.82)
BONE = (210, 197, 165)
OXIDE = (155, 81, 58)

_COMPONENT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
_WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Glb:
    def __init__(self, path):
        data = Path(path).read_bytes()
        if data[:4] != b"glTF":
            raise ValueError("not a GLB file")
        size = struct.unpack("<I", data[12:16])[0]
        self.json = json.loads(data[20:20 + size])
        at = 20 + size
        self.bin = data[at + 8:at + 8 + struct.unpack("<I", data[at:at + 4])[0]] if at < len(data) else b""

    def accessor(self, index):
        acc = self.json["accessors"][index]
        view = self.json["bufferViews"][acc["bufferView"]]
        kind = np.dtype(_COMPONENT[acc["componentType"]])
        width = _WIDTH[acc["type"]]
        start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        stride = view.get("byteStride", 0)
        row = kind.itemsize * width
        if stride and stride != row:
            raw = np.frombuffer(self.bin, dtype=np.uint8, count=stride * (acc["count"] - 1) + row, offset=start)
            pick = (np.arange(acc["count"])[:, None] * stride + np.arange(row)[None, :]).ravel()
            values = np.frombuffer(raw[pick].tobytes(), dtype=kind)
        else:
            values = np.frombuffer(self.bin, dtype=kind, count=acc["count"] * width, offset=start)
        values = values.reshape(acc["count"], width).astype(np.float64 if kind == np.float32 else np.int64)
        if acc.get("normalized") and kind != np.float32:
            values = values / float(np.iinfo(kind).max)
        return values

    def world(self):
        """Node index to its 4x4 world matrix in the rest pose."""
        nodes = self.json.get("nodes", [])
        out = {}

        def local(node):
            if "matrix" in node:
                return np.array(node["matrix"], float).reshape(4, 4).T
            move = np.eye(4)
            move[:3, 3] = node.get("translation", [0, 0, 0])
            x, y, z, w = node.get("rotation", [0, 0, 0, 1])
            turn = np.eye(4)
            turn[:3, :3] = [
                [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
            ]
            return move @ turn @ np.diag(list(node.get("scale", [1, 1, 1])) + [1])

        def walk(index, parent):
            out[index] = parent @ local(nodes[index])
            for child in nodes[index].get("children", []):
                walk(child, out[index])

        for scene in self.json.get("scenes", []):
            for root in scene.get("nodes", []):
                walk(root, np.eye(4))
        return out

    def surfaces(self):
        """Each triangle surface in the rest pose, in world space:
        (node name, positions Nx3, normals Nx3 or None, indices Mx3, primitive, raw normal lengths or None)."""
        world = self.world()
        for index, node in enumerate(self.json.get("nodes", [])):
            if "mesh" not in node or index not in world:
                continue
            for prim in self.json["meshes"][node["mesh"]]["primitives"]:
                if prim.get("mode", 4) != 4:
                    continue
                attrs = prim["attributes"]
                local = self.accessor(attrs["POSITION"])
                raw = self.accessor(attrs["NORMAL"]) if "NORMAL" in attrs else None
                if "indices" in prim:
                    idx = self.accessor(prim["indices"]).reshape(-1, 3)
                else:
                    idx = np.arange(len(local)).reshape(-1, 3)
                if "skin" in node and "JOINTS_0" in attrs and "WEIGHTS_0" in attrs:
                    pos, nor, mirrored = self._skinned(node["skin"], world, local, raw, attrs)
                else:
                    at = world[index]
                    pos = local @ at[:3, :3].T + at[:3, 3]
                    nor = raw @ np.linalg.inv(at[:3, :3]) if raw is not None else None
                    mirrored = np.linalg.det(at[:3, :3]) < 0
                if mirrored:
                    idx = idx[:, [0, 2, 1]]
                yield (node.get("name", "?"), pos, nor, idx, prim,
                       np.linalg.norm(raw, axis=1) if raw is not None else None)

    def _skinned(self, skin_index, world, local, raw, attrs):
        skin = self.json["skins"][skin_index]
        joints = skin["joints"]
        if "inverseBindMatrices" in skin:
            bind = self.accessor(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
        else:
            bind = np.tile(np.eye(4), (len(joints), 1, 1))
        place = np.stack([world[joint] @ bind[i] for i, joint in enumerate(joints)])
        which = self.accessor(attrs["JOINTS_0"]).astype(np.int64)
        weight = self.accessor(attrs["WEIGHTS_0"])
        total = weight.sum(axis=1, keepdims=True)
        weight = np.where(total > 1e-9, weight / np.where(total > 1e-9, total, 1), 0.0)
        blend = (place[which] * weight[:, :, None, None]).sum(axis=1)
        blend[total.ravel() <= 1e-9] = np.eye(4)
        pos = np.einsum("nij,nj->ni", blend[:, :3, :3], local) + blend[:, :3, 3]
        nor = np.einsum("nij,nj->ni", blend[:, :3, :3], raw) if raw is not None else None
        return pos, nor, bool(np.median(np.linalg.det(blend[:, :3, :3])) < 0)


def _mesh_faults(glb, row):
    for _name, pos, nor, idx, prim, raw_length in glb.surfaces():
        row["tris"] += len(idx)
        a, b, c = pos[idx[:, 0]], pos[idx[:, 1]], pos[idx[:, 2]]
        face = np.cross(b - a, c - a)
        area = np.linalg.norm(face, axis=1) / 2
        flat = area < AREA_EPS
        row["degenerate"] += int(flat.sum())
        row["area_m2"] += float(area.sum())
        if nor is not None:
            row["zero_normal"] += int((~(raw_length >= 0.5)).sum())
            against = ((nor[idx].sum(axis=1) * face).sum(axis=1) < 0) & ~flat
            row["flipped"] += int(against.sum())
            row["flipped_m2"] += float(area[against].sum())
        _, weld = np.unique(np.round(pos / WELD).astype(np.int64), axis=0, return_inverse=True)
        corners = weld.ravel()[idx]
        seen = {}
        for i, tri in enumerate(corners):
            if flat[i] or len(set(tri)) < 3:
                continue
            sides = seen.setdefault(tuple(sorted(tri)), [])
            if any(np.dot(face[j], face[i]) > 0 for j in sides):
                row["doubled"] += 1
                row["doubled_m2"] += float(area[i])
            else:
                if sides:
                    row["two_sided"] += 1
                sides.append(i)
        if "WEIGHTS_0" in prim["attributes"]:
            total = glb.accessor(prim["attributes"]["WEIGHTS_0"]).sum(axis=1)
            if "WEIGHTS_1" in prim["attributes"]:
                more = glb.accessor(prim["attributes"]["WEIGHTS_1"])
                total = total + more.sum(axis=1)
                row["over4"] += int((more > 1e-4).any(axis=1).sum())
            row["bad_weights"] += int((np.abs(total - 1) > WEIGHT_SLACK).sum())
            row["zero_weights"] += int((total < 1e-4).sum())


def _clip_snaps(glb, row):
    nodes = glb.json.get("nodes", [])
    for clip in glb.json.get("animations", []):
        row["clips"] += 1
        for channel in clip["channels"]:
            path = channel["target"]["path"]
            if path not in ("rotation", "translation") or "node" not in channel["target"]:
                continue
            sampler = clip["samplers"][channel["sampler"]]
            t = glb.accessor(sampler["input"]).ravel()
            v = glb.accessor(sampler["output"])
            if sampler.get("interpolation") == "CUBICSPLINE":
                v = v.reshape(len(t), 3, -1)[:, 1]
            if len(t) < 4:
                continue
            dt = np.diff(t)
            dt[dt <= 0] = 1e-6
            if path == "rotation":
                same = np.clip(np.abs((v[1:] * v[:-1]).sum(axis=1)), 0, 1)
                speed, floor, unit = np.degrees(2 * np.arccos(same)) / dt, SNAP_DEG, "deg/s"
            else:
                speed, floor, unit = np.linalg.norm(np.diff(v, axis=0), axis=1) / dt, SNAP_M, "m/s"
            for i in range(1, len(speed) - 1):
                beside = max(speed[i - 1], speed[i + 1])
                if speed[i] > floor and speed[i] > SNAP_RATIO * max(beside, 1e-6):
                    row["snaps"].append({
                        "clip": clip.get("name", "?"),
                        "node": nodes[channel["target"]["node"]].get("name", "?"),
                        "path": path,
                        "t": round(float(t[i]), 3),
                        "speed": round(float(speed[i]), 1),
                        "beside": round(float(beside), 1),
                        "unit": unit,
                        "held": sampler.get("interpolation") == "STEP",
                    })


COUNTS = ["degenerate", "zero_normal", "flipped", "doubled", "bad_weights", "zero_weights", "over4"]


def scan(path):
    glb = Glb(path)
    row = {"file": str(path), "tris": 0, "area_m2": 0.0, "degenerate": 0, "zero_normal": 0, "flipped": 0, "flipped_m2": 0.0,
           "doubled": 0, "doubled_m2": 0.0, "two_sided": 0, "bad_weights": 0, "zero_weights": 0, "over4": 0,
           "clips": 0, "snaps": []}
    _mesh_faults(glb, row)
    _clip_snaps(glb, row)
    row["area_m2"] = round(row["area_m2"], 4)
    row["flipped_m2"] = round(row["flipped_m2"], 4)
    row["doubled_m2"] = round(row["doubled_m2"], 4)
    return row


def clean(row):
    return "error" not in row and not any(row[key] for key in COUNTS) and not any(not s["held"] for s in row["snaps"])


def faults(files, out):
    rows = []
    for path in files:
        try:
            rows.append(scan(path))
        except (OSError, ValueError, KeyError, IndexError, struct.error) as error:
            rows.append({"file": str(path), "error": repr(error)[:160]})
    if out:
        Path(out).parent.mkdir(parents=True, exist_ok=True)
        Path(out).write_text(json.dumps(rows, indent=1) + "\n")
    print("%-40s %7s" % ("file", "tris"), " ".join("%8s" % key[:8] for key in COUNTS), "  snaps  held")
    for row in rows:
        name = Path(row["file"]).name[:40]
        if "error" in row:
            print("%-40s ERROR %s" % (name, row["error"]))
        elif not clean(row) or row["snaps"]:
            held = sum(1 for s in row["snaps"] if s["held"])
            print("%-40s %7d" % (name, row["tris"]), " ".join("%8d" % row[key] for key in COUNTS),
                  "%7d %5d" % (len(row["snaps"]) - held, held))
    print("scanned %d, clean %d" % (len(rows), sum(1 for row in rows if clean(row))))
    return rows


def _view(surfaces, pitch, yaw):
    """Every triangle of `surfaces` seen from `yaw` round and `pitch` down: an Mx3x2 array of (across, up) corners."""
    cy, sy, cp, sp = np.cos(yaw), np.sin(yaw), np.cos(pitch), np.sin(pitch)
    tris = []
    for pos, idx in surfaces:
        across = pos[:, 0] * cy + pos[:, 2] * sy
        depth = -pos[:, 0] * sy + pos[:, 2] * cy
        up = pos[:, 1] * cp + depth * sp
        tris.append(np.stack([across, up], axis=1)[idx])
    return np.concatenate(tris) if tris else np.zeros((0, 3, 2))


def _fill(tris, origin, cell, shape):
    """A boolean grid of `shape` (rows, columns) from `origin` (left, top) in steps of `cell` metres: the cells whose
    centres fall inside any triangle (either winding). Scanline: each row crosses every triangle at once."""
    rows, cols = shape
    grid = np.zeros(shape, dtype=bool)
    xs = (tris[..., 0] - origin[0]) / cell - 0.5
    ys = (origin[1] - tris[..., 1]) / cell - 0.5
    ends = [(0, 1), (1, 2), (2, 0)]
    lo, hi = ys.min(axis=1), ys.max(axis=1)
    for r in range(max(int(np.ceil(lo.min())), 0) if len(tris) else 0, min(int(np.floor(hi.max())) + 1, rows) if len(tris) else 0):
        live = (lo <= r) & (hi >= r)
        if not live.any():
            continue
        tx, ty = xs[live], ys[live]
        left = np.full(len(tx), np.inf)
        right = np.full(len(tx), -np.inf)
        for a, b in ends:
            ya, yb, xa, xb = ty[:, a], ty[:, b], tx[:, a], tx[:, b]
            cross = (np.minimum(ya, yb) <= r) & (np.maximum(ya, yb) >= r) & (ya != yb)
            x = np.where(cross, xa + (r - ya) * (xb - xa) / np.where(ya != yb, yb - ya, 1.0), np.nan)
            left = np.where(cross, np.minimum(left, x), left)
            right = np.where(cross, np.maximum(right, x), right)
        c0 = np.clip(np.ceil(left), 0, cols).astype(int)
        c1 = np.clip(np.floor(right) + 1, 0, cols).astype(int)
        keep = np.isfinite(left) & (c1 > c0)
        line = np.zeros(cols + 1, dtype=int)
        np.add.at(line, c0[keep], 1)
        np.add.at(line, c1[keep], -1)
        grid[r] = np.cumsum(line[:cols]) > 0
    return grid


def cover(lod0, lod, yaws=COVER_YAWS, pitch=COVER_PITCH, px=COVER_PX):
    """The worst view's share of `lod0`'s outline that `lod` also fills (see the module doc)."""
    full = [(pos, idx) for _name, pos, _nor, idx, _prim, _raw in Glb(lod0).surfaces()]
    part = [(pos, idx) for _name, pos, _nor, idx, _prim, _raw in Glb(lod).surfaces()]
    if not full:
        raise ValueError("no triangles in " + str(lod0))
    reach = max(np.hypot(pos[:, 0], pos[:, 2]).max() for pos, _ in full)
    rise = max(np.linalg.norm(pos, axis=1).max() for pos, _ in full)
    cell = 2 * reach / px
    origin = (-reach, rise)
    shape = (int(np.ceil(2 * rise / cell)) + 1, px)
    worst = 1.0
    for k in range(yaws):
        yaw = 2 * np.pi * k / yaws
        a = _fill(_view(full, np.radians(pitch), yaw), origin, cell, shape)
        b = _fill(_view(part, np.radians(pitch), yaw), origin, cell, shape)
        if a.sum():
            worst = min(worst, float((a & b).sum() / a.sum()))
    return worst


def covers(files, out):
    rows = []
    for path in files:
        base = str(path)[:-4]
        if base.endswith(("_lod1", "_lod2")):
            continue
        for suffix in ("_lod1", "_lod2"):
            if Path(base + suffix + ".glb").exists():
                fills = cover(path, base + suffix + ".glb")
                rows.append({"file": base + suffix + ".glb", "cover": round(fills, 4), "under": fills < COVER_FLOOR})
    if out:
        Path(out).write_text(json.dumps(rows, indent=1))
    low = [row for row in rows if row["under"]]
    for row in sorted(low, key=lambda row: row["cover"]):
        print("%-50s %.3f" % (Path(row["file"]).name, row["cover"]))
    print("covered %d, under %.2f %d" % (len(rows), COVER_FLOOR, len(low)))
    return rows


def _flat(path, pitch, yaw):
    """One model seen from the play camera's side, in metres from its ground point: [(across, up, indices)]."""
    surfaces = [(pos, idx) for _name, pos, _nor, idx, _prim, _raw in Glb(path).surfaces()]
    if not surfaces:
        raise ValueError("no triangles")
    ground = min(pos[:, 1].min() for pos, _ in surfaces)
    cy, sy, cp, sp = np.cos(yaw), np.sin(yaw), np.cos(pitch), np.sin(pitch)
    out = []
    for pos, idx in surfaces:
        across = pos[:, 0] * cy + pos[:, 2] * sy
        depth = -pos[:, 0] * sy + pos[:, 2] * cy
        out.append((across, (pos[:, 1] - ground) * cp + depth * sp, idx))
    return out


def _masks(files, ppm, pitch, yaw):
    """Every model's filled outline on one canvas size, ground points together, the largest model whole."""
    from PIL import Image, ImageDraw
    flats = [_flat(path, pitch, yaw) for path in files]
    reach = max(np.abs(across).max() for flat in flats for across, _up, _idx in flat) + MARGIN_M
    top = max(up.max() for flat in flats for _across, up, _idx in flat) + MARGIN_M
    foot = max(-up.min() for flat in flats for _across, up, _idx in flat) + MARGIN_M
    width, height = int(np.ceil(2 * reach * ppm)), int(np.ceil((top + foot) * ppm))
    masks = []
    for flat in flats:
        image = Image.new("L", (width, height), 0)
        draw = ImageDraw.Draw(image)
        for across, up, idx in flat:
            px = np.stack([(reach + across) * ppm, (top - up) * ppm], axis=1)
            for tri in idx:
                draw.polygon([tuple(px[tri[0]]), tuple(px[tri[1]]), tuple(px[tri[2]])], fill=255)
        masks.append(np.array(image) > 0)
    return masks


def _font(size):
    from PIL import ImageFont
    try:
        return ImageFont.truetype("DejaVuSans-Bold.ttf", size)
    except OSError:
        return ImageFont.load_default()


def _stamp(mask):
    from PIL import Image
    ink = Image.fromarray(mask.astype(np.uint8) * 255)
    return Image.composite(Image.new("RGB", ink.size, (0, 0, 0)), Image.new("RGB", ink.size, BONE), ink)


def overlaps(masks):
    """Every pair's shared area over joined area, highest first: [(overlap, i, j)]."""
    pairs = []
    for i in range(len(masks)):
        for j in range(i + 1, len(masks)):
            joined = (masks[i] | masks[j]).sum()
            pairs.append((float((masks[i] & masks[j]).sum() / joined) if joined else 0.0, i, j))
    pairs.sort(key=lambda pair: -pair[0])
    return pairs


def outlines(files, out, ppm=32.0, pitch=35.0, yaw=30.0, seed=7):
    from PIL import Image, ImageDraw
    names = [Path(path).stem for path in files]
    masks = _masks(files, ppm, np.radians(pitch), np.radians(yaw))
    high, wide = masks[0].shape
    pairs = overlaps(masks)
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    (out / "outlines.json").write_text(json.dumps({
        "ppm": ppm, "pitch": pitch, "yaw": yaw,
        "area_px": {names[i]: int(masks[i].sum()) for i in range(len(masks))},
        "canvas_px": [wide, high],
        "pairs": [[round(share, 3), names[i], names[j]] for share, i, j in pairs],
    }, indent=1) + "\n")

    order = list(range(len(masks)))
    random.Random(seed).shuffle(order)
    letters = [chr(65 + k) if k < 26 else chr(65 + k // 26 - 1) + chr(65 + k % 26) for k in range(len(order))]
    cols = min(6, max(1, len(order)))
    rows = (len(order) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * wide, rows * high), BONE)
    draw = ImageDraw.Draw(sheet)
    for k, i in enumerate(order):
        x, y = (k % cols) * wide, (k // cols) * high
        sheet.paste(_stamp(masks[i]), (x, y))
        draw.text((x + 8, y + 6), letters[k], fill=OXIDE, font=_font(max(14, high // 12)))
    sheet.save(out / "outlines-blind.jpg", quality=88)
    (out / "outlines-key.json").write_text(json.dumps({letters[k]: names[i] for k, i in enumerate(order)}, indent=1) + "\n")

    for share, i, j in pairs[:10]:
        print("%.2f  %s / %s" % (share, names[i], names[j]))
    print("wrote %s" % out)
    return pairs


def main(argv):
    if len(argv) < 2 or argv[0] not in ("faults", "outlines", "cover"):
        print(__doc__)
        return 2
    options = {}
    files = []
    for arg in argv[1:]:
        if arg.startswith("--") and "=" in arg:
            key, value = arg[2:].split("=", 1)
            options[key] = value
        else:
            files.extend(sorted(glob.glob(arg, recursive=True)) or [arg])
    if not files:
        print("no files matched")
        return 2
    if argv[0] == "faults":
        faults(files, options.get("out"))
        return 0
    if argv[0] == "cover":
        covers(files, options.get("out"))
        return 0
    if "out" not in options:
        print("outlines needs --out=<dir>")
        return 2
    outlines(files, options["out"], float(options.get("ppm", 32)), float(options.get("pitch", 35)),
             float(options.get("yaw", 30)), int(options.get("seed", 7)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
