# Model polish pass: soft bevels, denser curves, smooth shading with hard creases, and baked
# ambient occlusion and edge wear in the vertex colours. Andrew's 18 Oct ask: models should
# read baked and detailed, not as primitives tacked together, while frames stay in budget.
#
# A recipe opts in before it builds any Part:
#
#     import common, polish
#     polish.enable(detail=2, bevel=0.03)
#
# common.Part then runs `shape` on each part's bmesh before triangulating, and
# common.export runs `bake` over the whole tree before writing the GLB. A recipe that
# never calls enable() is untouched, byte for byte.
#
# Everything here is deterministic: fixed ray directions, sorted element order and
# colours rounded to 1/1024, so a rebuild stays byte-identical.

import math

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

import common

DEFAULTS = {
    # Segment multiplier for cyl, rod, uv and ring; ico gains one subdivision at 2+.
    "detail": 2,
    # Bevel width in metres on edges sharper than bevel_angle; 0 turns bevels off.
    "bevel": 0.03,
    "bevel_angle": 30.0,
    "bevel_segments": 1,
    # Edges shorter than this keep hard (no bevel), so bolts and rivets stay cheap while
    # the big panels round off; 0 bevels every hard edge.
    "bevel_min": 0.0,
    # Faces are smooth; edges sharper than this stay hard after the bevel.
    "sharp_angle": 50.0,
    # Catmull-Clark levels for parts (a Part's own .subsurf wins). Hard edges are creased,
    # so boxes keep their corners and bevels turn into fillets. Each level is about 4x tris.
    "subsurf": 0,
    # Scale each connected piece back to its unpolished bounding box after bevel and
    # subdivision, so measured envelopes (core radius, ear tips, bulb size) hold exactly.
    "fit": False,
    # On subdivided parts only edges sharper than this stay creased; softer ones round off.
    "crease_angle": 70.0,
    # Ambient occlusion: rays per corner, reach as a fraction of the asset's radius, and
    # how dark a fully covered corner gets. Only faces in bake_slots take it, because
    # only vertex-coloured slots show vertex colour in the game.
    "ao": True,
    "ao_rays": 24,
    "ao_reach": 0.18,
    "ao_strength": 0.55,
    # Convex edges lighten and creases darken by up to this much (curvature bake).
    "edge": 0.18,
    "bake_slots": None,
    # Linear RGB colours the bake never changes: a state key a shader matches exactly (the
    # kit steel shader tints loops within 0.02 of mint), so darkening it would break the tint.
    "bake_keep": (),
}

_opts = None


def enable(**opts):
    global _opts
    unknown = set(opts) - set(DEFAULTS)
    if unknown:
        raise ValueError("unknown polish options " + ", ".join(sorted(unknown)))
    _opts = dict(DEFAULTS, **opts)
    if _opts["bake_slots"] is None:
        _opts["bake_slots"] = tuple(sorted(k for k, v in common.SLOTS.items() if v.get("vc")))
    common.DETAIL = _opts["detail"]
    common.POLISH = _opts
    return _opts


def options():
    return _opts


# --- shape: per part, on the bmesh before triangulation -------------------------------

def _angle(edge):
    if len(edge.link_faces) != 2:
        return 180.0
    return math.degrees(edge.link_faces[0].normal.angle(edge.link_faces[1].normal, 0.0))


def shape(bm, opts=None, bevel=None):
    """Bevel the hard edges of one part and mark its creases; returns the bmesh."""
    o = opts or _opts
    if o is None:
        return bm
    width = o["bevel"] if bevel is None else bevel
    bm.normal_update()
    bm.edges.index_update()
    if width > 0:
        # Each loose piece (a kitbashed box, bolt, groove or decal) bevels at most a
        # quarter of its thinnest side: a full-width bevel on a 1.5 cm groove or a flat
        # decal folds the faces through each other. Pieces too thin for 5 mm keep their
        # edges, which also spares triangles on bolts and weld beads.
        groups = {}
        for island in _islands(bm):
            co = [v.co for f in island for v in f.verts]
            thin = min(max(c[i] for c in co) - min(c[i] for c in co) for i in range(3))
            w = round(min(width, 0.25 * thin), 4)
            if w < 0.005:
                continue
            edges = {e for f in island for e in f.edges
                     if _angle(e) > o["bevel_angle"] and e.calc_length() >= o["bevel_min"]}
            groups.setdefault(w, set()).update(edges)
        for w in sorted(groups, reverse=True):
            hard = sorted((e for e in groups[w] if e.is_valid), key=lambda e: e.index)
            if hard:
                bmesh.ops.bevel(bm, geom=hard, offset=w, offset_type="OFFSET",
                                segments=o["bevel_segments"], profile=0.5, affect="EDGES",
                                clamp_overlap=True, loop_slide=True, material=-1)
                bm.normal_update()
                bm.edges.index_update()
        # A clamped bevel that meets itself leaves coincident corners: zero-area
        # triangles the asset tests reject.
        bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=sorted(bm.edges, key=lambda e: e.index))
        bm.normal_update()
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        e.smooth = _angle(e) <= o["sharp_angle"]
    return bm


def _islands(bm):
    """Faces grouped into edge-connected pieces, in face index order."""
    bm.faces.index_update()
    seen, out = set(), []
    for start in bm.faces:
        if start.index in seen:
            continue
        seen.add(start.index)
        stack, island = [start], []
        while stack:
            f = stack.pop()
            island.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        out.append(island)
    return out


def subdivide(bm, levels=1):
    """Catmull-Clark in Python: Blender's subdivision runs threaded and its output differs
    in the last bits between runs. Sharp edges (edge.smooth False) and open edges are
    creased, so boxes keep their corners and bevels round into fillets. Loop colours,
    UVs, deform weights, integer tag and float vertex layers, materials and shading
    flags carry over. Returns a new bmesh."""
    limit = (_opts or DEFAULTS)["crease_angle"]
    bm.normal_update()
    for e in bm.edges:
        e.smooth = _angle(e) <= limit
    for _ in range(levels):
        old, bm = bm, _cc(bm)
        old.free()
    return bm


def finish(bm, opts, bevel=None, subsurf=None, regions=()):
    """Shape and subdivide one part. Faces tagged by Part.region take that region's bevel
    and levels; each region is cut out, finished alone and joined back. Returns the bmesh
    to triangulate, which may be a new one."""
    layer = bm.faces.layers.int.get("polish_region")
    if layer is None:
        return _finish_one(bm, opts, bevel, subsurf)
    settings = [(bevel, subsurf, None)] + [(bevel if b is None else b, subsurf if s is None else s, f)
                                           for b, s, f in regions]
    tags = sorted({f[layer] for f in bm.faces})
    out = bmesh.new()
    for tag in tags:
        piece = bm.copy()
        player = piece.faces.layers.int["polish_region"]
        drop = [f for f in piece.faces if f[player] != tag]
        if drop:
            bmesh.ops.delete(piece, geom=drop, context="FACES")
        piece.faces.layers.int.remove(player)
        piece = _finish_one(piece, opts, *settings[tag])
        _append(out, piece)
        piece.free()
    bm.free()
    return out


def _loops(face):
    """A face's loops starting from its lowest-index vertex. Recipes can hand over the
    same face with a different first loop between runs, and bevel and subdivision emit
    vertices in loop order, so polish starts every face at the same corner."""
    loops = list(face.loops)
    k = min(range(len(loops)), key=lambda i: loops[i].vert.index)
    return loops[k:] + loops[:k]


def _canonical(bm):
    out = bmesh.new()
    _append(out, bm)
    bm.free()
    return out


def _finish_one(bm, opts, bevel, subsurf, fit=None):
    bm = _canonical(bm)
    before = _boxes(bm) if (opts["fit"] if fit is None else fit) else None
    shape(bm, opts, bevel)
    levels = opts["subsurf"] if subsurf is None else subsurf
    if levels:
        bm = subdivide(bm, levels)
    if before:
        _fit(bm, before)
    return bm


def _vert_islands(bm):
    """Connected pieces as vertex lists, ordered by their lowest vertex index."""
    bm.verts.index_update()
    seen = set()
    out = []
    for v in bm.verts:
        if v.index in seen:
            continue
        seen.add(v.index)
        stack, piece = [v], []
        while stack:
            u = stack.pop()
            piece.append(u)
            for e in u.link_edges:
                w = e.other_vert(u)
                if w.index not in seen:
                    seen.add(w.index)
                    stack.append(w)
        out.append(sorted(piece, key=lambda x: x.index))
    return out


def _box(verts):
    return (tuple(min(v.co[i] for v in verts) for i in range(3)),
            tuple(max(v.co[i] for v in verts) for i in range(3)))


def _boxes(bm):
    return [_box(piece) for piece in _vert_islands(bm)]


def _fit(bm, before):
    """Scales each piece about its box centre to the nearest unpolished box."""
    for piece in _vert_islands(bm):
        lo, hi = _box(piece)
        old = min(before, key=lambda b: math.fsum((b[0][i] - lo[i]) ** 2 + (b[1][i] - hi[i]) ** 2
                                                    for i in range(3)))
        for i in range(3):
            size, want = hi[i] - lo[i], old[1][i] - old[0][i]
            if size < 1e-9:
                continue
            k, c, oc = want / size, (lo[i] + hi[i]) / 2, (old[0][i] + old[1][i]) / 2
            for v in piece:
                co = v.co.copy()
                co[i] = oc + (co[i] - c) * k
                v.co = co


def _append(dst, src):
    """Copies src into dst: positions, deform weights, integer and float vertex tags, loop
    colours and UVs, materials and shading flags, in src's element order."""
    loop_layers = []
    for kind in ("float_color", "color", "uv"):
        dl, sl = getattr(dst.loops.layers, kind), getattr(src.loops.layers, kind)
        for name in sl.keys():
            loop_layers.append((kind, sl[name], dl.get(name) or dl.new(name)))
    sdef = src.verts.layers.deform.active
    ddef = None
    if sdef is not None:
        ddef = dst.verts.layers.deform.active or dst.verts.layers.deform.new()
    vert_layers = [(sl[n], dl.get(n) or dl.new(n)) for sl, dl in
                   ((src.verts.layers.int, dst.verts.layers.int), (src.verts.layers.float, dst.verts.layers.float))
                   for n in sl.keys()]
    src.verts.index_update()
    verts = []
    for v in src.verts:
        nv = dst.verts.new(v.co)
        if ddef is not None:
            for g, w in sorted(v[sdef].items()):
                nv[ddef][g] = w
        for sl, dl in vert_layers:
            nv[dl] = v[sl]
        verts.append(nv)
    # Faces in a fixed order too: by their vertex indices from the lowest corner.
    for loops in sorted((_loops(f) for f in src.faces), key=lambda ls: [l.vert.index for l in ls]):
        f = loops[0].face
        nf = dst.faces.new([verts[l.vert.index] for l in loops])
        nf.material_index = f.material_index
        nf.smooth = f.smooth
        for sloop, dloop in zip(loops, nf.loops):
            for kind, sl, dl in loop_layers:
                if kind == "uv":
                    dloop[dl].uv = sloop[sl].uv
                else:
                    dloop[dl] = sloop[sl]
    for e in src.edges:
        if not e.smooth:
            de = dst.edges.get((verts[e.verts[0].index], verts[e.verts[1].index]))
            if de is not None:
                de.smooth = False


def _avg(points):
    n = len(points)
    return tuple(math.fsum(p[i] for p in points) / n for i in range(3))


def _cc(src):
    # A concave ngon's centroid can fall outside it and fold the corner quads; ear-clip
    # those first.
    src.normal_update()
    concave = [f for f in src.faces if len(f.verts) > 4 and not common._convex(f)]
    if concave:
        bmesh.ops.triangulate(src, faces=concave, quad_method="FIXED", ngon_method="EAR_CLIP")
    src.verts.index_update()
    src.edges.index_update()
    src.faces.index_update()
    co = [tuple(v.co) for v in src.verts]
    sharp = [not e.smooth or len(e.link_faces) != 2 for e in src.edges]
    fpt = [_avg([co[v.index] for v in f.verts]) for f in src.faces]
    ept = []
    for e in src.edges:
        a, b = e.verts[0].index, e.verts[1].index
        if sharp[e.index]:
            ept.append(_avg([co[a], co[b]]))
        else:
            ept.append(_avg([co[a], co[b]] + [fpt[f.index] for f in e.link_faces]))
    vpt = []
    for v in src.verts:
        hard = [e for e in v.link_edges if sharp[e.index]]
        if len(hard) > 2 or not v.link_faces:
            vpt.append(co[v.index])
        elif len(hard) == 2:
            o1, o2 = hard[0].other_vert(v).index, hard[1].other_vert(v).index
            vpt.append(tuple((6 * co[v.index][i] + co[o1][i] + co[o2][i]) / 8 for i in range(3)))
        else:
            n = len(v.link_edges)
            q = _avg([fpt[f.index] for f in v.link_faces])
            r = _avg([_avg([co[e.verts[0].index], co[e.verts[1].index]]) for e in v.link_edges])
            vpt.append(tuple((q[i] + 2 * r[i] + (n - 3) * co[v.index][i]) / n for i in range(3)))

    dst = bmesh.new()
    loop_layers = [(name, kind, getattr(src.loops.layers, kind)[name], getattr(dst.loops.layers, kind).new(name))
                   for kind in ("float_color", "color", "uv") for name in getattr(src.loops.layers, kind).keys()]
    sdef = src.verts.layers.deform.active
    ddef = dst.verts.layers.deform.new() if sdef is not None else None
    # Integer vertex layers are rig and part tags (pilot_bone, tally_bone, rig_part...):
    # a new vertex takes the tag most of its source vertices share, the lowest on a tie.
    # Float vertex layers average.
    ints = [(src.verts.layers.int[n], dst.verts.layers.int.new(n)) for n in src.verts.layers.int.keys()]
    floats = [(src.verts.layers.float[n], dst.verts.layers.float.new(n)) for n in src.verts.layers.float.keys()]

    def weights(vs):
        if sdef is None:
            return None
        acc = {}
        for v in vs:
            for g, w in sorted(v[sdef].items()):
                acc[g] = acc.get(g, 0.0) + w / len(vs)
        return acc

    def new_vert(pos, vs):
        nv = dst.verts.new(pos)
        if ddef is not None:
            for g, w in sorted(weights(vs).items()):
                nv[ddef][g] = w
        for sl, dl in ints:
            tags = sorted(v[sl] for v in vs)
            nv[dl] = max(tags, key=lambda t: (tags.count(t), -t))
        for sl, dl in floats:
            nv[dl] = math.fsum(v[sl] for v in vs) / len(vs)
        return nv

    nv_v = [new_vert(vpt[v.index], [v]) for v in src.verts]
    nv_e = [new_vert(ept[e.index], list(e.verts)) for e in src.edges]
    nv_f = [new_vert(fpt[f.index], list(f.verts)) for f in src.faces]
    new_sharp = set()
    for f in src.faces:
        loops = list(f.loops)
        n = len(loops)
        for k in range(n):
            lk, lprev = loops[k], loops[k - 1]
            e_out, e_in = lk.edge, lprev.edge
            quad = (nv_v[lk.vert.index], nv_e[e_out.index], nv_f[f.index], nv_e[e_in.index])
            nf = dst.faces.new(quad)
            nf.material_index = f.material_index
            nf.smooth = f.smooth
            lnext = loops[(k + 1) % n]
            for name, kind, sl, dl in loop_layers:
                a, b, p = lk[sl], lnext[sl], lprev[sl]
                if kind == "uv":
                    a, b, p = a.uv, b.uv, p.uv
                    allv = [l[sl].uv for l in loops]
                else:
                    allv = [l[sl] for l in loops]
                width = len(a)
                vals = [tuple(a), tuple((a[i] + b[i]) / 2 for i in range(width)),
                        tuple(math.fsum(x[i] for x in allv) / n for i in range(width)),
                        tuple((a[i] + p[i]) / 2 for i in range(width))]
                for loop, val in zip(nf.loops, vals):
                    if kind == "uv":
                        loop[dl].uv = val
                    else:
                        loop[dl] = val
            if not e_out.smooth:
                new_sharp.add((lk.vert.index, e_out.index))
            if not e_in.smooth:
                new_sharp.add((lk.vert.index, e_in.index))
    dst.edges.ensure_lookup_table()
    for vi, ei in sorted(new_sharp):
        e = dst.edges.get((nv_v[vi], nv_e[ei]))
        if e is not None:
            e.smooth = False
    return dst


# --- bake: AO and edge wear into vertex colours, over the whole asset ------------------

def _directions(n):
    """n fixed directions over the upper hemisphere (Fibonacci spiral), cosine weighted."""
    out = []
    golden = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(n):
        z = math.sqrt(1.0 - (i + 0.5) / n)
        r = math.sqrt(max(0.0, 1.0 - z * z))
        a = golden * i
        out.append(Vector((r * math.cos(a), r * math.sin(a), z)))
    return out


def _basis(n):
    up = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
    t = n.cross(up).normalized()
    return t, n.cross(t)


def _q(x):
    return round(max(0.0, min(1.0, x)) * 1024.0) / 1024.0


def bake(root, opts=None):
    o = opts or _opts
    if o is None:
        return
    if not (o["ao"] or o["edge"]):
        return
    meshes = [ob for ob in common.tree(root) if ob.type == "MESH" and len(ob.data.polygons)]
    if not meshes:
        return
    bpy.context.view_layer.update()
    # One BVH over every mesh in world space, so parts shade each other.
    verts, polys = [], []
    for ob in meshes:
        mw = ob.matrix_world
        base = len(verts)
        verts += [mw @ v.co for v in ob.data.vertices]
        # Glass and other see-through slots let light through, so they cast no occlusion.
        clear = {i for i, m in enumerate(ob.data.materials)
                 if m is not None and common.SLOTS.get(m.name, {}).get("alpha", 1.0) < 1.0}
        polys += [[base + i for i in p.vertices] for p in ob.data.polygons if p.material_index not in clear]
    tree = BVHTree.FromPolygons(verts, polys, all_triangles=False, epsilon=0.0)
    lo = Vector([min(v[i] for v in verts) for i in range(3)])
    hi = Vector([max(v[i] for v in verts) for i in range(3)])
    reach = max((hi - lo).length * 0.5 * o["ao_reach"], 0.02)
    dirs = _directions(o["ao_rays"])
    slots = set(o["bake_slots"])
    for ob in meshes:
        me = ob.data
        attr = me.color_attributes.get("Color")
        if attr is not None and attr.domain != "CORNER":
            attr = None
        baked = {i for i, m in enumerate(me.materials) if m is not None and m.name in slots} if attr else set()
        # UV2 carries the raw bake for every face (x: unoccluded fraction, y: wear with 0.5
        # neutral), so runtime materials of any slot can opt in. Godot reads TEXCOORD_1 as
        # UV2; a mesh that already has two UV maps keeps them and gets no UV2 bake.
        uv2 = None
        if len(me.uv_layers) < 2:
            if len(me.uv_layers) == 0:
                # A new layer starts with per-face unit squares; zero it so it adds no seams.
                uv1 = me.uv_layers.new(name="UVMap")
                uv1.data.foreach_set("uv", [0.0] * (2 * len(uv1.data)))
            uv2 = me.uv_layers.new(name="Bake")
        mw = ob.matrix_world
        rot = mw.to_3x3().normalized()
        # Area-weighted vertex normals summed in a fixed order: Blender's own corner normals
        # differ in the last bits between runs, which would flip rounded bake values.
        # Polygon normals come from Newell's method in Python doubles, starting each polygon
        # at its lowest vertex and summing each vertex's polygons in sorted order, since
        # polygon order and winding start can differ between runs.
        co = [tuple(v.co) for v in me.vertices]
        acc = [[] for _ in me.vertices]
        for poly in me.polygons:
            vs = list(poly.vertices)
            s0 = vs.index(min(vs, key=lambda i: co[i]))
            vs = vs[s0:] + vs[:s0]
            wx = wy = wz = 0.0
            for i in range(len(vs)):
                a, b = co[vs[i]], co[vs[(i + 1) % len(vs)]]
                wx += (a[1] - b[1]) * (a[2] + b[2])
                wy += (a[2] - b[2]) * (a[0] + b[0])
                wz += (a[0] - b[0]) * (a[1] + b[1])
            for vi in vs:
                acc[vi].append((wx, wy, wz))
        pn = []
        for terms in acc:
            terms.sort()
            pn.append(Vector((math.fsum(t[0] for t in terms), math.fsum(t[1] for t in terms),
                              math.fsum(t[2] for t in terms))))
        pn = [v.normalized() if v.length > 1e-12 else Vector((0, 0, 1)) for v in pn]
        # Curvature per vertex: how far the neighbours sit below (convex) or above
        # (concave) the vertex's tangent plane, relative to the edge length.
        terms = [[] for _ in me.vertices]
        for e in me.edges:
            a, b = e.vertices
            d = Vector(co[b]) - Vector(co[a])
            ln = d.length
            if ln < 1e-6:
                continue
            terms[a].append(-(pn[a].dot(d)) / ln)
            terms[b].append(pn[b].dot(d) / ln)
        curv = [math.fsum(sorted(t)) / len(t) if t else 0.0 for t in terms]
        pn = [(rot @ v).normalized() for v in pn]
        cache = {}
        for poly in me.polygons:
            if poly.material_index not in baked and uv2 is None:
                continue
            for li in poly.loop_indices:
                vi = me.loops[li].vertex_index
                n = pn[vi]
                key = vi
                shade = cache.get(key)
                if shade is None:
                    occ = 0.0
                    if o["ao"]:
                        p = mw @ me.vertices[vi].co + n * (reach * 0.02)
                        t, bt = _basis(n)
                        for d in dirs:
                            w = t * d.x + bt * d.y + n * d.z
                            hit = tree.ray_cast(p, w, reach)
                            # A back face means the corner sits inside another part
                            # (kitbashed primitives overlap); that part hides nothing.
                            # Where a front and a back face meet the ray at one point (a
                            # shared edge, coplanar overlaps) the BVH returns either by
                            # run, so any front face at the hit point counts.
                            if hit[0] is not None and (hit[1].dot(w) < 0.0 or any(
                                    f[1].dot(w) < 0.0 for f in tree.find_nearest_range(hit[0], reach * 1e-4))):
                                occ += 1.0 - (hit[3] / reach) ** 2
                        # Rays that graze a shared edge can hit either face; rounding
                        # drops that last-bit noise before the 1/1024 quantisation.
                        occ = round(occ / len(dirs), 6)
                    k = curv[vi]
                    wear = max(-1.0, min(1.0, k * 2.5)) * o["edge"]
                    shade = (_q(1.0 - occ), _q(0.5 + 0.5 * wear / max(o["edge"], 1e-6)),
                             (1.0 - o["ao_strength"] * occ) * (1.0 + wear))
                    cache[key] = shade
                if uv2 is not None:
                    uv2.data[li].uv = shade[:2]
                if poly.material_index not in baked:
                    continue
                shade = shade[2]
                c = attr.data[li].color
                if any(math.dist(c[:3], k[:3]) < 0.02 for k in o["bake_keep"]):
                    continue
                attr.data[li].color = (_q(c[0] * shade), _q(c[1] * shade), _q(c[2] * shade), c[3])
        me.update()
