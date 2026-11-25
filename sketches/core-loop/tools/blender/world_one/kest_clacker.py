# E2-03 (wave 46, ruling en): Kest's clacker, kest_clacker.glb. The detonator she snaps to set off
# a cooked charge, clamped on the cockpit beside her right yoke (the wave 46 3D review, Kest
# "cook and snap": "the clacker goes on the cockpit at the right yoke ... closes over 0.04 s on
# the snap"). Concept: artifacts/local/w46-concept-art/heroic-cutaway/05-kest-heroic-cutaway.png.
# hero_assets.gd mounts the file at identity on the shell's Pod (its origin is the ball centre;
# WEAPONS, COCKPIT_WEAPONS, mount_weapon), so it stays at her hands while the ring yaws to the aim,
# and clips/kest.json's machinery row snaps the handle shut on each throw.
#
#   prlimit --as=12884901888 -- blender --background --threads 2 --python-exit-code 1 \
#     --python world_one/kest_clacker.py -- [--out <file.glb>]
#
# Node tree (Blender axes, +Y forward, +Z up; glTF and Godot +Y up, -Z forward):
#   KestClacker (empty) > ClackerRig (armature) > Clacker (skinned mesh: paint, copper)
#   bones  mount (the ball centre) > lever (the hinge at the back of the body). Bones point along
#          +Y with no roll, so in the lever's rest frame X is +X: a turn about X by -OPEN_DEG lays
#          the raised handle flat on the body (the snap).
# Every vertex is weighted whole to one bone (PILOT-RIG.md): the body, its bail, the clamp and the
# firing lead to mount, the handle, its knob and the hinge pin to lever. Paint faces carry vertex
# alpha 0, so an equipped paint never recolours it (hero_assets.gd PAINT_TAKE); copper is the one
# metal. Every piece is a closed island; the build fails on an open, non-manifold or inside-out
# island. No class_accent: the amber fuse on the mortar pods stays Kest's only glow.

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

import common  # noqa: E402
import shell_base as sb  # noqa: E402  (also registers the copper slot)
from common import Part  # noqa: E402

TRIS = (150, 600)
DRAWS = 2
REACH = 0.80                      # inside the gimbal sweep (0.829): the clacker rides inside the ball
# Blender metres, Pod space. The right yoke column runs up to the grip at shell_base CONTROLS
# Grip.R (0.32, 0.40, 0.05); the body sits outboard of it, toward the bank.
BODY = (0.455, 0.43, 0.005)       # centre
BODY_SIZE = (0.09, 0.20, 0.07)    # x, y, z
BODY_CHAMFER = 0.018
HINGE = (BODY[0], BODY[1] - BODY_SIZE[1] / 2 + 0.02, BODY[2] + BODY_SIZE[2] / 2 + 0.014)
HANDLE = (0.06, 0.21, 0.024)      # width, length from the hinge, thickness
OPEN_DEG = 24.0                   # the handle rests raised by this much; the snap lays it flat
KNOB_R = 0.022
BAIL_Y = 0.05                     # the bail's top bar stands this far forward of the body, past the knob
GRIP = sb.CONTROLS["Grip.R"]
LEAD_TO = (0.52, 0.30, -0.24)     # the firing lead runs down to the FusePlunger in the bank

BONES = ("mount", "lever")
TAG = "rig_part"


class Kit:
    """One Part whose vertices carry the bone each piece is weighted to."""

    def __init__(self):
        self.part = Part("Clacker")
        self.tag = self.part.bm.verts.layers.int.new(TAG)

    def mark(self, faces, bone):
        k = BONES.index(bone) + 1
        for f in faces:
            for v in f.verts:
                v[self.tag] = k
        return faces

    def box(self, bone, slot, size, loc, rot=(0, 0, 0), color=None):
        return self.mark(self.part.box(slot, size, loc=loc, rot=rot, color=color, alpha=0.0), bone)

    def rod(self, bone, slot, a, b, r, segs, color=None, r2=None):
        return self.mark(self.part.rod(slot, a, b, r, segs, color=color, r2=r2, alpha=0.0), bone)

    def beam(self, bone, slot, a, b, w, h=None, color=None):
        return self.mark(self.part.beam(slot, a, b, w, h, color=color, alpha=0.0), bone)

    def chamfered(self, bone, slot, centre, size, chamfer, color=None, pitch=0.0, pivot=None):
        """A box along +Y with its four long edges chamfered (28 tris), turned about X by pitch
        round pivot."""
        cx, cy, cz = centre
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        c = chamfer
        ring = [(hx, hz - c), (hx - c, hz), (-hx + c, hz), (-hx, hz - c), (-hx, -hz + c), (-hx + c, -hz),
                (hx - c, -hz), (hx, -hz + c)]
        bm = self.part.bm
        pv = Vector(pivot) if pivot is not None else Vector(centre)
        cs, sn = math.cos(pitch), math.sin(pitch)

        def at(x, y, z):
            d = Vector((x, y, z)) - pv
            return pv + Vector((d.x, d.y * cs - d.z * sn, d.y * sn + d.z * cs))
        back = [bm.verts.new(at(cx + x, cy - hy, cz + z)) for x, z in ring]
        front = [bm.verts.new(at(cx + x, cy + hy, cz + z)) for x, z in ring]
        faces = [bm.faces.new(back), bm.faces.new(list(reversed(front)))]
        faces += [bm.faces.new((back[(i + 1) % 8], back[i], front[i], front[(i + 1) % 8])) for i in range(8)]
        self.part.paint(faces, slot, color, alpha=0.0)
        return self.mark(faces, bone)


def build_kit(kit):
    bx, by, bz = BODY
    sx, sy, sz = BODY_SIZE
    # The body: a charcoal block with a bone face plate and an oxide band, chamfered so it reads
    # as a cast case, not a box.
    kit.chamfered("mount", "paint", BODY, BODY_SIZE, BODY_CHAMFER, "charcoal")
    kit.box("mount", "paint", (sx + 0.008, 0.03, sz - 0.02), (bx, by - sy / 2 + 0.035, bz), color="oxide")
    kit.box("mount", "paint", (sx - 0.03, 0.006, sz - 0.03), (bx, by + sy / 2 + 0.002, bz), color="bone")
    # The safety bail: a bone loop over the front of the handle, its top bar forward of the knob's
    # sweep so the handle snaps shut under it (snap_report).
    top = bz + sz / 2
    for side in (-1, 1):
        kit.beam("mount", "paint", (bx + side * (sx / 2 - 0.006), by + sy / 2 - 0.03, top - 0.01),
                 (bx + side * (sx / 2 - 0.006), by + sy / 2 + BAIL_Y, top + 0.05), 0.012, color="bone")
    kit.beam("mount", "paint", (bx - sx / 2 + 0.006, by + sy / 2 + BAIL_Y, top + 0.05),
             (bx + sx / 2 - 0.006, by + sy / 2 + BAIL_Y, top + 0.05), 0.012, color="bone")
    # The clamp to the yoke column: a charcoal arm and a copper collar round the column.
    col = Vector((GRIP[0], GRIP[1] - 0.01, GRIP[2] - 0.11))
    kit.rod("mount", "copper", col - Vector((0, 0, 0.03)), col + Vector((0, 0, 0.03)), 0.034, 8)
    kit.beam("mount", "paint", col + Vector((0.02, 0, 0)), Vector((bx - sx / 2 + 0.01, by - 0.03, bz - 0.01)), 0.03,
             color="charcoal")
    # The firing lead down to the bank, oxide.
    kit.rod("mount", "paint", Vector((bx, by - sy / 2 + 0.005, bz - 0.015)), Vector(LEAD_TO), 0.009, 6, color="oxide")
    # The handle, raised OPEN_DEG on its hinge: a copper plate with a knob at its free end.
    hx, hy, hz = HINGE
    w, length, t = HANDLE
    pitch = math.radians(OPEN_DEG)
    centre = (hx, hy + length / 2, hz)
    kit.chamfered("lever", "copper", centre, (w, length, t), 0.008, pitch=pitch, pivot=HINGE)
    knob = Vector((hx, hy + length - 0.012, hz + t / 2))
    d = knob - Vector(HINGE)
    knob = Vector(HINGE) + Vector((d.x, d.y * math.cos(pitch) - d.z * math.sin(pitch), d.y * math.sin(pitch) + d.z * math.cos(pitch)))
    kit.rod("lever", "copper", knob, knob + Vector((0, -0.006, 0.03)), KNOB_R, 8, r2=KNOB_R * 0.8)
    # The hinge pin across the back of the body.
    kit.rod("lever", "copper", Vector((hx - w / 2 - 0.008, hy, hz)), Vector((hx + w / 2 + 0.008, hy, hz)), 0.012, 8)


# --- checks ------------------------------------------------------------------------------------


def islands(bm):
    bm.faces.index_update()
    seen, out = set(), []
    for start in bm.faces:
        if start.index in seen:
            continue
        group, stack = [], [start]
        seen.add(start.index)
        while stack:
            f = stack.pop()
            group.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        out.append(group)
    return out


def closed_report(obj):
    """MANIFOLD line for one mesh: islands, open (boundary) and non-manifold edges after welding by
    position (as check_manifold.py does), and islands with negative signed volume (inside out)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    boundary = sum(1 for e in bm.edges if len(e.link_faces) == 1)
    nonmanifold = sum(1 for e in bm.edges if len(e.link_faces) > 2)
    groups = islands(bm)
    inverted = 0
    for g in groups:
        vol = 0.0
        for f in g:
            vs = [v.co for v in f.verts]
            for i in range(1, len(vs) - 1):
                vol += vs[0].dot(vs[i].cross(vs[i + 1])) / 6.0
        inverted += 1 if vol <= 0.0 else 0
    bm.free()
    print("MANIFOLD %s islands=%d boundary=%d nonmanifold=%d inverted=%d" % (obj.name, len(groups), boundary,
                                                                            nonmanifold, inverted))
    return boundary == 0 and nonmanifold == 0 and inverted == 0


def snap_report(obj):
    """SNAP line: the lever's pieces (handle, knob, pin) against the mount's (body, bail, clamp,
    lead) with the handle raised and snapped shut (turned -OPEN_DEG about the hinge's X).
    Returns True when no lever triangle meets a mount triangle in either pose."""
    tags = obj.data.attributes[TAG]
    lever = {v.index for v in obj.data.vertices if tags.data[v.index].value == BONES.index("lever") + 1}
    hinge = Vector(HINGE)
    out = {}
    for name, deg in (("open", 0.0), ("shut", -OPEN_DEG)):
        cs, sn = math.cos(math.radians(deg)), math.sin(math.radians(deg))
        verts = []
        for v in obj.data.vertices:
            p = v.co.copy()
            if v.index in lever:
                d = p - hinge
                p = hinge + Vector((d.x, d.y * cs - d.z * sn, d.y * sn + d.z * cs))
            verts.append(p)
        on_lever = [list(f.vertices) for f in obj.data.polygons if f.vertices[0] in lever]
        on_mount = [list(f.vertices) for f in obj.data.polygons if f.vertices[0] not in lever]
        hits = BVHTree.FromPolygons(verts, on_lever).overlap(BVHTree.FromPolygons(verts, on_mount))
        knob = max(verts[i].z for i in lever)
        out[name] = (len(hits), knob)
    print("SNAP open %d hits (top %.3f), shut %d hits (top %.3f), handle drops %.3f m"
          % (out["open"][0], out["open"][1], out["shut"][0], out["shut"][1], out["open"][1] - out["shut"][1]))
    return out["open"][0] == 0 and out["shut"][0] == 0


def reach_of(obj):
    mw = obj.matrix_world
    return max((mw @ v.co).length for v in obj.data.vertices)


# --- rig and export ----------------------------------------------------------------------------


def rig(root, obj):
    data = bpy.data.armatures.new("ClackerRig")
    arm = bpy.data.objects.new("ClackerRig", data)
    bpy.context.scene.collection.objects.link(arm)
    common.place(arm, (0, 0, 0), root)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.scene.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    at = {"mount": Vector((0, 0, 0)), "lever": Vector(HINGE)}
    for name in BONES:
        bone = data.edit_bones.new(name)
        bone.head = at[name]
        bone.tail = at[name] + Vector((0, 0.05, 0))
        bone.roll = 0.0
        if name != "mount":
            bone.parent = data.edit_bones["mount"]
            bone.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.parent = arm
    obj.matrix_parent_inverse.identity()
    obj.location = (0, 0, 0)
    mod = obj.modifiers.new("Rig", "ARMATURE")
    mod.object = arm
    tags = obj.data.attributes[TAG]
    for i, name in enumerate(BONES):
        ids = [v.index for v in obj.data.vertices if tags.data[v.index].value == i + 1]
        obj.vertex_groups.new(name=name).add(ids, 1.0, "REPLACE")
    untagged = sum(1 for v in obj.data.vertices if tags.data[v.index].value == 0)
    if untagged:
        raise SystemExit("%d vertices carry no bone" % untagged)
    obj.data.attributes.remove(tags)
    return arm


def export(root, arm, path):
    bpy.context.view_layer.update()
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in common.tree(root):
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=False,
                              export_def_bones=False, export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_vertex_color="ACTIVE", export_extras=False, export_cameras=False,
                              export_lights=False)
    common.canonical_indices(path, vertices=True)
    print("EXPORTED", path)


def build():
    root = common.empty("KestClacker")
    kit = Kit()
    build_kit(kit)
    bmesh.ops.recalc_face_normals(kit.part.bm, faces=kit.part.bm.faces[:])
    sb._sharpen(kit.part)
    obj = kit.part.to_object((0, 0, 0), root)
    return root, obj


def main():
    common.reset()
    common.preview_class("amber")
    root, obj = build()
    tris = common.tris(obj)
    draws = len(obj.data.materials)
    reach = reach_of(obj)
    closed = closed_report(obj)
    snap = snap_report(obj)
    print("CLACKER tris=%d verts=%d draws=%d reach=%.4f (limit %.2f)" % (tris, len(obj.data.vertices), draws, reach, REACH))
    arm = rig(root, obj)
    ok = TRIS[0] <= tris <= TRIS[1] and draws == DRAWS and reach <= REACH and closed and snap
    out = common.args()["out"] or os.path.join(common.MODELS, "world_one", "kest_clacker.glb")
    export(root, arm, out)
    if not ok:
        raise SystemExit("kest_clacker out of budget, reach, watertight or snap clearance")


if __name__ == "__main__":
    main()
