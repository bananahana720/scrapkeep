"""Shared park dressing prop kit (Dressing lane; contract: design-v3/park/DRESSING-KITS.md).

A per-park recipe (tools/blender/park/props/<park>.py) declares kinds and variants:

    import kit
    K = kit.Kit("dam")

    @K.kind("gate_wheelhouse", hero=True, tags=["machine"], story="one line", variants="ab")
    def gate_wheelhouse(p, v, rng):
        p.box((2, 2, 0.5), (0, 0, 0.25), kit.C["concrete"])
        ...

    if __name__ == "__main__":
        K.main()

blender -b --factory-startup --threads 2 --python-exit-code 1 -P \
  sketches/core-loop/tools/blender/park/props/<park>.py -- \
  [--out-dir D] [--only k1,k2] [--count-only] [--preview-dir D]

Authoring frame: Blender Z up, floor at z = 0, front faces -Y (Godot +Z after import).
The kit recentres each model on its footprint (bbox xy centre) and drops its lowest point to
z = 0 before baking, so the origin is the foot centre. Every build then polishes (bevel,
subdivision), bakes AO and wear, exports LOD0, and exports LOD1 and LOD2 from a Decimate
(collapse) copy of the polished, baked mesh. Budgets are enforced at build time (exit 1).
"""
import argparse
import colorsys
import hashlib
import json
import math
from pathlib import Path
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = Path(__file__).resolve().parent
BLENDER = HERE.parent.parent
sys.path.insert(0, str(BLENDER))
import common
import polish

SCHEMA = "scrapkeep-park-props-kit/1"
SKETCH = Path(common.SKETCH)
RES_ROOT = "res://assets/models/park/props/"
LOADER = "src/presentation/park_props.gd (vignette file src/world/park/props/park_%s.json)"

# --- budgets (DRESSING-KITS.md) -----------------------------------------------------------
BUDGET = {"dress_hero": (6000, 20000), "dress_prop": (300, 3000)}
LOD1_BAND, LOD2_BAND, LOD2_MIN_TRIS = (0.40, 0.60), (0.10, 0.20), 40
LOD1_TARGET, LOD2_TARGET = 0.50, 0.15
FLOOR_TOL = 0.02  # metres a LOD bottom may sit off y 0
RESEAT_MAX = 0.15  # metres decimate() may shift a LOD down or up to put its bottom back on the floor

# --- palette: only safe colours -----------------------------------------------------------
C = {
    "sandstone": "c6a274", "sandstone_dark": "a98b60", "sandstone_pale": "d8c19a",
    "concrete": "9a9a94", "concrete_dark": "6f706b", "concrete_light": "b8b7ae",
    "concrete_stain": "7d7a70",
    "timber": "8a6a46", "timber_dark": "5d4630", "timber_grey": "8e8470", "timber_pale": "a8885c",
    "canvas": "d9d2bc", "canvas_dark": "b9b095", "canvas_stain": "a79e83",
    "cable": "2a3231", "charcoal": "242a28", "iron": "4a4e4c", "iron_light": "6b706c",
    "verdigris": "5f8a7c", "rust": "8a5a44", "bone": "d2c5a5", "soil": "6a5a42",
    "leaf": "6f7f4a", "leaf_dark": "4f5e38", "dry_grass": "a39a64",
}
BANNED = {"ff5a3c", "9dff3c", "8bf0d3"}  # HAZARD, ANCIENT, MINT
WARN = {"e5a044", "b77843", "d9b44a"}  # AMBER, COPPER (never dominant), BRASS (Fleet only)


def hexcolor(c):
    """Palette name, hex string or sRGB triple -> 6-digit hex string."""
    if isinstance(c, str):
        c = C.get(c, c).lstrip("#").lower()
        if len(c) != 6:
            raise ValueError("bad colour " + c)
        return c
    return "".join("%02x" % round(max(0.0, min(1.0, x)) * 255) for x in c)


def check_colour(c):
    """Hard readability rule: no banned hexes, no hot red/orange/amber stripes."""
    h = hexcolor(c)
    if h in BANNED:
        raise ValueError("banned colour #" + h)
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hue, sat, val = colorsys.rgb_to_hsv(r, g, b)
    if sat > 0.65 and val > 0.75 and (hue < 0.13 or hue > 0.95):
        raise ValueError("hazard-like colour #" + h)
    if h in WARN:
        print("KIT warning: #%s is AMBER/COPPER/BRASS; never dominant, brass is Fleet-only" % h, flush=True)
    return h


def mix(a, b, t):
    """Blend two colours; t = 0 gives a."""
    ca, cb = common.srgb(hexcolor(a)), common.srgb(hexcolor(b))
    return hexcolor(tuple(ca[i] + (cb[i] - ca[i]) * t for i in range(3)))


def shade(c, f):
    """Multiply value: f < 1 darkens, f > 1 lightens (clamped)."""
    return hexcolor(tuple(x * f for x in common.srgb(hexcolor(c))))


def tint(c, rng, amount=0.08):
    """Small seeded value jitter, so planks and stones differ."""
    return shade(c, 1.0 + rng.uniform(-amount, amount))


# (bevel metres, subsurf levels) per look.
STYLES = {
    "hard": (0.04, 0),         # machinery, slabs, planks: crisp edges with a rounded bevel
    "hard_smooth": (0.04, 1),  # bevelled and softened: toy-like blocks
    "fine": (0.015, 0),        # thin boards, straps, small hard bits
    "round": (0.0, 1),         # drums, hubs, rims, rods
    "soft": (0.0, 2),          # cloth, sacks, plants, mud: chunky blobs, smooth
    "flat": (0.0, 0),          # thin sheets and decals as drawn
}


class Prop:
    """Prop builder handed to a kind's builder as `p`. Blender Z up; every helper takes a
    colour (palette name, hex, or kit.C entry) and a `style` from STYLES. `jit` jitters the
    primitive's vertices by that many metres with the variant's seeded rng. Helpers return
    the new faces."""

    def __init__(self, name, rng):
        common.reset()
        self.name = name
        self.rng = rng
        self.root = common.empty(name)
        self.parts = {}

    def part(self, style):
        if style not in STYLES:
            raise ValueError("unknown style " + style)
        if style not in self.parts:
            part = common.Part("Surface." + style)
            part.bevel, part.subsurf = STYLES[style]
            self.parts[style] = part
        return self.parts[style]

    def _do(self, style, method, color, jit, *args, **kwargs):
        part = self.part(style)
        faces = getattr(part, method)("paint", *args, color=check_colour(color), **kwargs)
        if jit:
            part.jitter(faces, self.rng, jit)
        return faces

    def box(self, size, loc, color, rot=(0, 0, 0), style="hard", jit=0):
        return self._do(style, "box", color, jit, size, loc=loc, rot=rot)

    def cyl(self, radius, depth, loc, color, segs=10, rot=(0, 0, 0), r2=None, style="hard", jit=0):
        """Cylinder along local Z (rot to lay it down); r2 tapers the top."""
        return self._do(style, "cyl", color, jit, radius, radius if r2 is None else r2, depth,
                        segs=segs, loc=loc, rot=rot)

    def rod(self, a, b, radius, color, segs=6, r2=None, style="round", jit=0):
        return self._do(style, "rod", color, jit, a, b, radius, segs=segs, r2=r2)

    def beam(self, a, b, width, color, h=None, roll=0.0, style="hard", jit=0):
        """Square-section beam from a to b (h = other side, roll about its axis)."""
        return self._do(style, "beam", color, jit, a, b, width, h=h, roll=roll)

    def uv(self, radius, loc, color, scale=(1, 1, 1), rot=(0, 0, 0), u=8, v=6, style="round", jit=0):
        return self._do(style, "uv", color, jit, radius, u=u, v=v, loc=loc, scale=scale, rot=rot)

    def ico(self, radius, loc, color, scale=(1, 1, 1), rot=(0, 0, 0), subdiv=1, style="soft", jit=0):
        return self._do(style, "ico", color, jit, radius, subdiv=subdiv, loc=loc, scale=scale, rot=rot)

    def ring(self, r_in, r_out, depth, loc, color, segs=12, rot=(0, 0, 0), arc=(0.0, 2 * math.pi),
             style="hard", jit=0):
        """Flat annulus with thickness (or an arc of one), axis along local Z."""
        return self._do(style, "ring", color, jit, r_in, r_out, depth, segs=segs, loc=loc, rot=rot, arc=arc)

    def prism(self, outline, depth, loc, color, rot=(0, 0, 0), style="hard", jit=0):
        """Extrudes a 2D outline [(x, y), ...] along local Z, centred, at loc/rot."""
        return self._do(style, "prism", color, jit, outline, depth, matrix=common.mtx(loc, rot))

    def torus(self, big, small, loc, color, rot=(0, 0, 0), scale=(1, 1, 1), major=12, minor=6,
              style="round", jit=0):
        """Torus about local Z: ring radius `big`, tube radius `small`."""
        part = self.part(style)
        m = common.mtx(loc, rot, scale)
        rows = []
        for i in range(major):
            t = math.tau * i / major
            row = []
            for j in range(minor):
                f = math.tau * j / minor
                rr = big + small * math.cos(f)
                row.append(part.bm.verts.new(m @ Vector((rr * math.cos(t), rr * math.sin(t), small * math.sin(f)))))
            rows.append(row)
        faces = [part.bm.faces.new((rows[i][j], rows[(i + 1) % major][j],
                                    rows[(i + 1) % major][(j + 1) % minor], rows[i][(j + 1) % minor]))
                 for i in range(major) for j in range(minor)]
        part.paint(faces, "paint", check_colour(color))
        if jit:
            part.jitter(faces, self.rng, jit)
        return faces

    def chain(self, a, b, color, link=0.14, radius=0.02, sag=0.1, style="round"):
        """Hanging chain of alternating links from a to b, sagging by `sag` metres (never taut)."""
        a, b = Vector(a), Vector(b)
        n = max(2, int((b - a).length / (link * 0.8)))
        d = (b - a).normalized()
        for k in range(n + 1):
            t = k / n
            pos = a.lerp(b, t) - Vector((0, 0, sag * 4 * t * (1 - t)))
            # The link's long axis (local X) follows the chord; odd links roll a quarter turn.
            quat = Quaternion(d, math.pi / 2 * (k % 2)) @ Vector((1, 0, 0)).rotation_difference(d)
            self.torus(link * 0.5, radius, pos, color, rot=quat.to_euler(), scale=(1.0, 0.7, 1.0),
                       major=6, minor=4, style=style)

    def finish(self):
        """Joins the parts into one 'Surface' mesh at the foot centre, floor at z = 0."""
        objs = [self.parts[k].to_object(parent=self.root) for k in sorted(self.parts)]
        if not objs:
            raise ValueError(self.name + ": the builder drew nothing")
        obj = objs[0]
        if len(objs) > 1:
            bpy.ops.object.select_all(action="DESELECT")
            for o in objs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.join()
        obj.name = obj.data.name = "Surface"
        # Origin at the foot centre: bbox xy centre, lowest point on the floor.
        me = obj.data
        lo = Vector((min(v.co[i] for v in me.vertices) for i in range(3)))
        hi = Vector((max(v.co[i] for v in me.vertices) for i in range(3)))
        me.transform(Matrix.Translation((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)))
        me.update()
        return obj


class Kit:
    def __init__(self, park, polish_opts=None):
        self.park = park
        self.kinds = {}
        self.polish_opts = dict(detail=2, bevel=0.04, bevel_min=0.08)
        self.polish_opts.update(polish_opts or {})

    def kind(self, name, hero=False, tags=(), story="", variants="ab", polish_opts=None):
        def deco(fn):
            if name in self.kinds:
                raise ValueError("duplicate kind " + name)
            if not 1 <= len(variants) <= 3:
                raise ValueError("2 or 3 variants per kind (1 allowed only while drafting)")
            self.kinds[name] = {"fn": fn, "class": "dress_hero" if hero else "dress_prop",
                                "tags": list(tags), "story": story, "variants": list(variants),
                                "polish": dict(polish_opts or {})}
            return fn
        return deco

    # --- build ------------------------------------------------------------------------
    def build(self, kind, variant):
        spec = self.kinds[kind]
        rng = random.Random("%s/%s/%s" % (self.park, kind, variant))
        polish.enable(**dict(self.polish_opts, **spec["polish"]))
        p = Prop("%s_%s" % (kind, variant), rng)
        spec["fn"](p, variant, rng)
        return p.root, p.finish()

    def main(self, argv=None):
        ap = argparse.ArgumentParser()
        ap.add_argument("--out-dir", type=Path)
        ap.add_argument("--only")
        ap.add_argument("--count-only", action="store_true")
        ap.add_argument("--preview-dir", type=Path)
        argv = sys.argv[sys.argv.index("--") + 1:] if argv is None and "--" in sys.argv else (argv or [])
        opts = ap.parse_args(argv)
        names = list(self.kinds)
        if opts.only:
            names = opts.only.split(",")
            missing = [n for n in names if n not in self.kinds]
            if missing:
                sys.exit("unknown kinds: " + ", ".join(missing))
        default = SKETCH / "assets" / "models" / "park" / "props" / self.park
        out_dir = opts.out_dir or default
        failures = []
        results = {}
        for kind in names:
            for v in self.kinds[kind]["variants"]:
                try:
                    results[(kind, v)] = (self.count(kind, v) if opts.count_only
                                          else self.export(kind, v, out_dir))
                except AssertionError as e:
                    failures.append(str(e))
                    print("KIT FAIL", e, flush=True)
        if failures:
            print("KIT: %d budget failure(s)" % len(failures), flush=True)
            sys.exit(1)
        if opts.count_only:
            return
        self.write_manifest(out_dir, names, results)
        if opts.out_dir is None:
            self.write_registry(out_dir)
            self.write_import_stubs(out_dir)
        if opts.preview_dir:
            self.preview(out_dir, opts.preview_dir, names)

    # --- budgets ----------------------------------------------------------------------
    def check_lod0(self, kind, variant, tris):
        lo, hi = BUDGET[self.kinds[kind]["class"]]
        assert lo <= tris <= hi, "%s_%s: LOD0 %d tris outside %s %d-%d" % (
            kind, variant, tris, self.kinds[kind]["class"], lo, hi)

    def count(self, kind, variant):
        root, obj = self.build(kind, variant)
        tris = common.tris(obj)
        print("KIT_COUNT %s_%s %s tris %d" % (kind, variant, self.kinds[kind]["class"], tris), flush=True)
        self.check_lod0(kind, variant, tris)
        return tris

    # --- export -----------------------------------------------------------------------
    def export(self, kind, variant, out_dir):
        out_dir.mkdir(parents=True, exist_ok=True)
        root, obj = self.build(kind, variant)
        base = "%s_%s" % (kind, variant)
        t0 = common.tris(obj)
        self.check_lod0(kind, variant, t0)
        bpy.context.view_layer.update()
        polish.bake(root, polish.options())
        verts = [v.co.copy() for v in obj.data.vertices]
        radius = max(math.hypot(v.x, v.y) for v in verts)
        height = max(v.z for v in verts)
        info = {"radius": round(radius, 3), "height": round(height, 3)}
        stats = [self.write(root, obj, out_dir / (base + ".glb"))]
        assert stats[0]["tris"] == t0, base + ": exported tris differ from mesh tris"
        for suffix, target, band, floor in (("_lod1", LOD1_TARGET, LOD1_BAND, 0),
                                            ("_lod2", LOD2_TARGET, LOD2_BAND, LOD2_MIN_TRIS)):
            want = max(round(t0 * target), floor)
            lod = self.decimate(root, obj, want)
            stats.append(self.write(root, lod, out_dir / (base + suffix + ".glb")))
            ratio = stats[-1]["tris"] / t0
            assert band[0] <= ratio <= band[1] and stats[-1]["tris"] >= floor, \
                "%s%s: %d tris is %.1f%% of LOD0 %d (accept %d-%d%%, min %d)" % (
                    base, suffix, stats[-1]["tris"], ratio * 100, t0, band[0] * 100, band[1] * 100, floor)
            low = stats[-1]["bounds"][0][1]
            assert abs(low) <= FLOOR_TOL, "%s%s: bottom at y %.3f, not 0" % (base, suffix, low)
            bpy.data.objects.remove(lod)
        info["tris"] = [s["tris"] for s in stats]
        info["bounds"] = [s["bounds"] for s in stats]
        print("KIT_BUILT %s %s tris %s radius %.2f height %.2f" % (
            base, self.kinds[kind]["class"], info["tris"], info["radius"], info["height"]), flush=True)
        return info

    def decimate(self, root, src, want):
        """Collapse-decimated copy of the polished, baked mesh with about `want` triangles."""
        total = common.tris(src)
        mod = src.modifiers.new("lod", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.use_collapse_triangulate = True
        ratio, best = want / total, None
        for _ in range(8):
            mod.ratio = min(1.0, ratio)
            bpy.context.view_layer.update()
            ev = src.evaluated_get(bpy.context.evaluated_depsgraph_get())
            n = sum(len(p.vertices) - 2 for p in ev.data.polygons)
            if best is None or abs(n - want) < abs(best[0] - want):
                best = (n, mod.ratio)
            if abs(n - want) <= max(2, want * 0.02):
                break
            ratio *= want / max(n, 1)
        mod.ratio = best[1]
        bpy.context.view_layer.update()
        ev = src.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = bpy.data.meshes.new_from_object(ev)
        src.modifiers.remove(mod)
        obj = bpy.data.objects.new("lod_tmp", mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = root
        common.place(obj, src["world_origin"], root)
        # Collapse can lift or sink the lowest vertex a few centimetres; re-seat the LOD on LOD0's floor so no recipe
        # needs a ground plinth to hold FLOOR_TOL. A shift past RESEAT_MAX means the silhouette broke, so it fails.
        shift = min(v.co.z for v in src.data.vertices) - min(v.co.z for v in mesh.vertices)
        assert abs(shift) <= RESEAT_MAX, "LOD re-seat of %.3f m exceeds %.2f m" % (shift, RESEAT_MAX)
        for v in mesh.vertices:
            v.co.z += shift
        for poly in mesh.polygons:
            poly.use_smooth = True
        if mesh.color_attributes.get("Color") is not None:
            mesh.color_attributes.active_color = mesh.color_attributes["Color"]
            mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
        return obj

    def write(self, root, obj, path):
        keep = obj.name
        for o in common.tree(root):
            if o is not obj and o.type == "MESH":
                o.hide_set(True)
        obj.name = obj.data.name = "Surface"
        bpy.ops.object.select_all(action="DESELECT")
        root.select_set(True)
        obj.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                                  export_apply=False, export_yup=True, export_materials="EXPORT",
                                  export_vertex_color="ACTIVE", export_extras=False,
                                  export_animations=False, export_cameras=False, export_lights=False)
        common.canonical_indices(str(path), vertices=True)
        for o in common.tree(root):
            if o.type == "MESH":
                o.hide_set(False)
        obj.name = keep
        return inspect_glb(path)

    # --- manifest, registry -----------------------------------------------------------
    def write_manifest(self, out_dir, names, results):
        path = out_dir / "manifest.json"
        old = json.loads(path.read_text())["kinds"] if path.exists() else {}
        kinds = {}
        for kind, spec in self.kinds.items():
            variants = {}
            for v in spec["variants"]:
                if kind in names:
                    info = results[(kind, v)]
                elif kind in old and v in old[kind]["variants"]:
                    variants[v] = old[kind]["variants"][v]
                    continue
                else:
                    continue
                base = "%s_%s" % (kind, v)
                prefix = "%s%s/" % (RES_ROOT, self.park)
                variants[v] = {"lod": [prefix + base + s + ".glb" for s in ("", "_lod1", "_lod2")],
                               "tris": info["tris"], "radius": info["radius"], "height": info["height"]}
            if not variants:
                continue
            tags = list(spec["tags"])
            if max(x["height"] for x in variants.values()) > 3 and "tall" not in tags:
                tags.append("tall")
            kinds[kind] = {"class": spec["class"], "tags": tags, "story": spec["story"], "variants": variants}
        doc = {"schema": SCHEMA, "park": self.park,
               "recipe": "tools/blender/park/props/%s.py" % self.park, "kinds": kinds}
        path.write_text(json.dumps(doc, indent=1) + "\n")
        print("KIT_MANIFEST", path, flush=True)

    def write_registry(self, out_dir):
        manifest = json.loads((out_dir / "manifest.json").read_text())
        rows = []
        for kind, spec in manifest["kinds"].items():
            for v, var in spec["variants"].items():
                for i, res in enumerate(var["lod"]):
                    info = inspect_glb(out_dir / res.rsplit("/", 1)[1])
                    lo, hi = info["bounds"]
                    rows.append({
                        "id": "dprop_%s_%s_%s%s" % (self.park, kind, v, ("", "_lod1", "_lod2")[i]),
                        "path": res, "class": spec["class"], "ships": True,
                        "loader": LOADER % self.park,
                        "provenance": {"recipe": manifest["recipe"],
                                       "notes": "%s variant %s LOD%d (%d tris): %s Deterministic; Decimate (collapse) copy of the polished, baked LOD0." % (
                                           kind, v, i, var["tris"][i], spec["story"]) if i else
                                       "%s variant %s LOD0 (%d tris): %s Deterministic; polished and baked." % (
                                           kind, v, var["tris"][0], spec["story"])},
                        "bounds": {"min": lo, "max": hi, "size": [round(h - l, 4) for l, h in zip(lo, hi)]}})
        frag = SKETCH / "assets" / "registry.d" / ("park_props_%s.json" % self.park)
        frag.write_text(json.dumps({"assets": rows}, indent=1) + "\n")
        print("KIT_REGISTRY", frag, len(rows), "rows", flush=True)

    def write_import_stubs(self, out_dir):
        """Godot's automatic mesh LOD generation must be off (the kit ships its own LODs). A
        `.glb.import` that exists keeps its params, so write a stub for any GLB without one;
        Godot fills in the rest (uid, paths) on the next import. Commit the filled files
        (the .gitignore re-includes assets/models/park/props/*/*.glb.import)."""
        for glb in sorted(out_dir.glob("*.glb")):
            imp = Path(str(glb) + ".import")
            if not imp.exists():
                imp.write_text('[remap]\n\nimporter="scene"\ntype="PackedScene"\n\n'
                               '[params]\n\nmeshes/generate_lods=false\n')
                print("KIT_IMPORT_STUB", imp, flush=True)

    # --- preview ----------------------------------------------------------------------
    def preview(self, out_dir, folder, names):
        folder.mkdir(parents=True, exist_ok=True)
        tile = 360
        tiles, strips = [], []
        for kind in names:
            hero = self.kinds[kind]["class"] == "dress_hero"
            for v in self.kinds[kind]["variants"]:
                base = out_dir / ("%s_%s" % (kind, v))
                png = folder / ("%s_%s.png" % (kind, v))
                render([Path(str(base) + ".glb")], png, tile, tile)
                tiles.append((png, "%s_%s" % (kind, v)))
                if hero:
                    strip = folder / ("%s_%s_lods.png" % (kind, v))
                    render([Path(str(base) + s) for s in (".glb", "_lod1.glb", "_lod2.glb")],
                           strip, tile * 3, tile, spread=True)
                    strips.append((strip, "%s_%s  LOD0 / LOD1 / LOD2" % (kind, v)))
        sheet = folder / ("%s_contact_sheet.png" % self.park)
        compose(tiles, strips, sheet, tile)
        print("KIT_SHEET", sheet, flush=True)


def inspect_glb(path):
    """Counts and bounds of a kit GLB; asserts the one-surface, one-material, no-image rule."""
    raw = Path(path).read_bytes()
    gltf = json.loads(raw[20:20 + int.from_bytes(raw[12:16], "little")])
    prims = [p for m in gltf["meshes"] for p in m["primitives"]]
    assert len(prims) == 1, "%s: %d surfaces, want 1" % (Path(path).name, len(prims))
    assert len(gltf["materials"]) == 1 and not gltf.get("images"), Path(path).name + ": one vertex-colour material only"
    assert not any(any(m.get("emissiveFactor", [0])) for m in gltf["materials"]), Path(path).name + ": emissive"
    pos = gltf["accessors"][prims[0]["attributes"]["POSITION"]]
    return {"tris": gltf["accessors"][prims[0]["indices"]]["count"] // 3, "verts": pos["count"],
            "bounds": [[round(x, 4) for x in pos["min"]], [round(x, 4) for x in pos["max"]]],
            "sha256": hashlib.sha256(raw).hexdigest()}


def render(paths, out, width, height, spread=False):
    """Cycles CPU render of one or more imported GLBs (side by side when spread)."""
    common.reset()
    objs = []
    gap = 0.0
    for k, path in enumerate(paths):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(path))
        new = [o for o in bpy.data.objects if o not in before]
        if spread:
            meshes = [o for o in new if o.type == "MESH"]
            if k == 0:
                size = max(max(d) for d in (o.dimensions for o in meshes))
                gap = size * 1.25
            for o in new:
                if o.parent is None:
                    o.location.x += gap * (k - (len(paths) - 1) / 2)
        objs += new
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs if o.type == "MESH" for c in o.bound_box]
    lo = Vector((min(p[i] for p in pts) for i in range(3)))
    hi = Vector((max(p[i] for p in pts) for i in range(3)))
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("fill")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = common.rgba("a9b6c0")
    bg.inputs["Strength"].default_value = 0.8
    bpy.ops.mesh.primitive_plane_add(size=300, location=(0, 0, lo.z - 0.005))
    bpy.context.object.data.materials.append(common._flat("floor", "8a8372"))
    light = bpy.data.lights.new("sun", "AREA")
    light.energy, light.shape, light.size = 1200, "DISK", 6
    sun = bpy.data.objects.new("sun", light)
    scene.collection.objects.link(sun)
    sun.location = (-4, -5, hi.z + 7)
    centre = (lo + hi) / 2
    sun.rotation_euler = (centre - sun.location).to_track_quat("-Z", "Y").to_euler()
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = "ORTHO"
    direction = Vector((0.9, -1.3, 0.75)).normalized()
    cam.location = centre + direction * 30
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    inv = cam.rotation_euler.to_matrix().transposed()
    ip = [inv @ (p - centre) for p in pts]
    w = max(p.x for p in ip) - min(p.x for p in ip)
    h = max(p.y for p in ip) - min(p.y for p in ip)
    cam.data.ortho_scale = max(w, h * width / height) * 1.15
    cam.location += cam.rotation_euler.to_matrix() @ Vector(
        (-(max(p.x for p in ip) + min(p.x for p in ip)) / 2, -(max(p.y for p in ip) + min(p.y for p in ip)) / 2, 0))
    scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)


def compose(tiles, strips, out, tile, cols=4):
    from PIL import Image, ImageDraw
    pad = 18
    rows = (len(tiles) + cols - 1) // cols
    width = max(cols * tile, 3 * tile)
    height = rows * (tile + pad) + len(strips) * (tile + pad)
    sheet = Image.new("RGB", (width, height), (36, 42, 40))
    draw = ImageDraw.Draw(sheet)
    for k, (png, label) in enumerate(tiles):
        x, y = (k % cols) * tile, (k // cols) * (tile + pad)
        sheet.paste(Image.open(png).convert("RGB"), (x, y + pad))
        draw.text((x + 4, y + 3), label, fill=(230, 225, 205))
    y = rows * (tile + pad)
    for png, label in strips:
        sheet.paste(Image.open(png).convert("RGB"), (0, y + pad))
        draw.text((4, y + 3), label, fill=(230, 225, 205))
        y += tile + pad
    sheet.save(out)
