"""Tarn's seated tiger, authored surfaces and rigid pilot-v1 weights.

Model first: blender -b --threads 2 --python-exit-code 1 -P this_file -- --model
Final seven-clip export: the same command without --model. --preview renders on CPU.
No source images or other pilots are modified. Neutral outputs/receipts are disposable.
"""
import argparse
import math
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SKETCH = HERE.parents[1]
OUT = ROOT / "artifacts/local/dress-preview/PTA"
sys.path.insert(0, str(HERE))
import common
import polish
import rig_pilot

POLISH = {"detail": 1, "bevel": 0}
SOFT_BONES = ("head", "ear.R", "ear.L", "snout", "jaw", "hand.R", "hand.L")

ASH = "5e5a54"


class TigerSurface:
    def __init__(self):
        self.part = common.Part("Pilot")
        self.layer = self.part.bm.verts.layers.int.new("tarn_bone")
        self.bones = []

    def add(self, bone, method, *args, **kwargs):
        before = set(self.part.bm.verts)
        faces = getattr(self.part, method)(*args, **kwargs)
        if bone not in self.bones:
            self.bones.append(bone)
        for v in self.part.bm.verts:
            if v not in before:
                v[self.layer] = self.bones.index(bone) + 1
        return faces

    def sculpt(self, bone, centre, radii, u=16, v=10, color=ASH, deform=None, stripe=None):
        faces = self.add(bone, "uv", "pilot", 1, max(6, round(u * .8)), max(4, round(v * .65)), loc=centre, scale=radii, color=color)
        c = Vector(centre)
        for vertex in self.part.verts_of(faces):
            q = Vector(((vertex.co[i] - c[i]) / radii[i] for i in range(3)))
            if deform:
                vertex.co = c + Vector((deform(q)[i] * radii[i] for i in range(3)))
            if stripe:
                tint = common.rgba("oxide" if stripe(q) else color)
                for loop in vertex.link_loops:
                    loop[self.part.col] = tint
        for face in faces:
            face.smooth = True
        return faces

    def arm_surface(self, bone, a, b, r0, r1):
        av, bv = Vector(a), Vector(b)
        axis = (bv - av).normalized()
        right = axis.cross(Vector((0, 0, 1))).normalized()
        up = axis.cross(right).normalized()
        if bone not in self.bones:
            self.bones.append(bone)
        rows = []
        for i in range(6):
            f = i / 5
            radius = (r0 + (r1 - r0) * f) * (.88 if i in (0, 5) else 1)
            row = [self.part.bm.verts.new(av.lerp(bv, f) + radius *
                   (right * math.cos(k * math.tau / 10) + up * math.sin(k * math.tau / 10))) for k in range(10)]
            for vertex in row:
                vertex[self.layer] = self.bones.index(bone) + 1
            rows.append(row)
        for i in range(5):
            for k in range(10):
                face = self.part.bm.faces.new((rows[i][k], rows[i][(k + 1) % 10], rows[i + 1][(k + 1) % 10], rows[i + 1][k]))
                self.part.paint([face], "pilot", "oxide" if i in (1, 4) else ASH)
                face.smooth = True
        self.part.paint([self.part.bm.faces.new(tuple(reversed(rows[0]))), self.part.bm.faces.new(rows[-1])], "pilot", ASH)


def head_shape(q):
    return (math.copysign(abs(q.x) ** .82, q.x) * (1 - .07 * q.z),
            math.copysign(abs(q.y) ** .88, q.y), math.copysign(abs(q.z) ** .72, q.z))


def fur_stripe(q):
    band = abs(math.sin(10 * q.z + 2.1 * q.y)) > .91
    forehead = q.y > .25 and q.z > .45 and (abs(q.x) < .12 or (.61 < q.z < .83 and abs(q.x) < .47))
    return forehead or (band and (q.y < .35 or abs(q.x) > .63))


def build_model():
    t = TigerSurface()
    scalp = t.sculpt("head", (0, .015, .20), (.24, .18, .20), 24, 14,
                     deform=head_shape, stripe=fur_stripe)
    for face in scalp:
        q = face.calc_center_median() - Vector((0, .015, .20))
        if q.y > .10 and q.z > .085:
            stripe = abs(q.x) < .026 or (.11 < q.z < .145 and abs(q.x) < .13)
            t.part.paint([face], "pilot", "oxide" if stripe else ASH)
    for side, sign in (("R", 1), ("L", -1)):
        t.sculpt("head", (sign * .23, .13, .13), (.065, .08, .10), 12, 8, "bone",
                 deform=lambda q: (q.x * (1 + .22 * q.z), q.y, q.z))
        t.sculpt("head", (sign * .091, .187, .239), (.038, .014, .044), 12, 8, "charcoal")
        t.sculpt("head", (sign * .095, .201, .252), (.010, .004, .014), 8, 6, "bone")
        brow = t.sculpt("head", (sign * .096, .191, .294), (.050, .019, .017), 10, 6, ASH)
        for vertex in t.part.verts_of(brow):
            vertex.co.z += sign * (vertex.co.x - sign * .096) * .16
        t.sculpt("ear." + side, (sign * .181, 0, .354), (.043, .025, .044), 10, 6, ASH)
        ear = t.sculpt("ear." + side, (sign * .20, 0, .40), (.065, .025, .065), 16, 10, "charcoal")
        for vertex in t.part.verts_of(ear):
            local = vertex.co - Vector((sign * .20, 0, .40))
            if local.y > .010 and abs(local.x) < .045 and abs(local.z) < .046:
                for loop in vertex.link_loops:
                    loop[t.part.col] = common.rgba("bone")
    def muzzle_shape(q):
        return (q.x, q.y * (1 - .13 * math.exp(-q.x * q.x * 45)), q.z)
    t.sculpt("snout", (0, .23, .12), (.115, .075, .060), 20, 10, "bone", deform=muzzle_shape)
    t.sculpt("jaw", (0, .227, .065), (.092, .055, .024), 14, 8, "bone")
    t.sculpt("head", (0, .239, .081), (.065, .026, .018), 12, 6, "charcoal")
    nose = t.sculpt("snout", (0, .294, .159), (.046, .022, .025), 12, 8, "charcoal")
    for vertex in t.part.verts_of(nose):
        vertex.co.x *= .72 + .28 * max(0, (vertex.co.z - .134) / .05)
    t.add("snout", "rod", "pilot", (0, .303, .144), (0, .306, .085), .0025, 5, color="charcoal")

    t.sculpt("spine_01", (0, -.005, -.20), (.28, .205, .215), 20, 12, ASH)
    t.sculpt("spine_02", (0, .005, -.043), (.235, .155, .113), 16, 10, ASH)
    t.sculpt("spine_01", (0, .155, -.215), (.221, .049, .162), 16, 10, "petrol")
    for side, sign in (("R", 1), ("L", -1)):
        t.sculpt("pelvis", (sign * .18, .18, -.30), (.105, .145, .09), 12, 8, ASH)
        t.sculpt("pelvis", (sign * .19, .31, -.40), (.082, .117, .102), 10, 8, "petrol")
        t.sculpt("pelvis", (sign * .20, .45, -.48), (.10, .14, .06), 12, 8, "charcoal")
        t.add("spine_02", "beam", "pilot", (sign * .155, .161, -.22),
              (sign * .142, .120, .04), .040, .017, color="petrol")
        t.add("spine_02", "box", "bare_metal", (.045, .017, .036), loc=(sign * .154, .175, -.141))
        t.sculpt("shoulder." + side, (sign * .22, .005, -.09), (.095, .086, .104), 12, 8, ASH, stripe=fur_stripe)
        for bone, a, b, r0, r1 in [
            ("upper_arm.", (sign * .24, .015, -.09), (sign * .36, .24, -.12), .083, .076),
            ("lower_arm.", (sign * .36, .24, -.12), (sign * .32, .4, .05), .077, .064),
        ]:
            t.arm_surface(bone + side, a, b, r0, r1)
        t.sculpt("hand." + side, (sign * .32, .40, .05), (.09, .07, .06), 12, 8, ASH)
        centre = Vector((sign * .32, .446, .046))
        outline = [(-.086, -.038), (-.084, .013), (-.064, .050), (-.043, .014),
                   (-.025, .055), (0, .070), (.025, .055), (.043, .014),
                   (.064, .050), (.084, .013), (.086, -.038)]
        fan = t.add("curl." + side, "prism", "pilot", [(x, -y) for x, y in reversed(outline)], .040,
                    matrix=common.mtx(centre, (math.pi / 2, 0, 0)), color="bone")
        edges = {edge for face in fan for edge in face.edges}
        bevel = bmesh.ops.bevel(t.part.bm, geom=sorted(edges, key=lambda e: (tuple(e.verts[0].co), tuple(e.verts[1].co))),
                                offset=.006, segments=2, affect="EDGES")
        t.part.paint(bevel["faces"], "pilot", "bone")
        for face in bevel["faces"]:
            face.smooth = True
            for vertex in face.verts:
                vertex[t.layer] = t.bones.index("curl." + side) + 1

    for bone, start, end, r in [("tail.01", (0, -.16, -.27), (0, -.37, -.23), .05),
                                ("tail.02", (0, -.37, -.23), (.08, -.57, -.17), .04)]:
        av, bv = Vector(start), Vector(end)
        frames = []
        axis = (bv - av).normalized()
        right = axis.cross(Vector((1, 0, 0))).normalized()
        up = axis.cross(right).normalized()
        for i in range(9):
            f = i / 8
            radius = r * (1 - .66 * max(0, (f - .7) / .3)) if bone == "tail.02" else r
            c = av.lerp(bv, f) + Vector((.013 * math.sin(math.pi * f), 0, .012 * math.sin(math.pi * f)))
            frames.append([t.part.bm.verts.new(c + radius * (right * math.cos(k * math.tau / 10) + up * math.sin(k * math.tau / 10))) for k in range(10)])
        if bone not in t.bones:
            t.bones.append(bone)
        for row in frames:
            for vertex in row:
                vertex[t.layer] = t.bones.index(bone) + 1
        for i in range(8):
            for k in range(10):
                face = t.part.bm.faces.new((frames[i][k], frames[i][(k + 1) % 10], frames[i + 1][(k + 1) % 10], frames[i + 1][k]))
                t.part.paint([face], "pilot", "oxide" if i in (1, 4, 7) else ASH)
                face.smooth = True
        t.part.paint([t.part.bm.faces.new(tuple(reversed(frames[0]))), t.part.bm.faces.new(frames[-1])], "pilot", ASH)
    soft = {t.bones.index(name) + 1 for name in SOFT_BONES}
    pilot_slot = t.part.slots.index("pilot")
    polish.subdivide_where(t.part.bm, 1, lambda island: island[0].material_index == pilot_slot
                           and island[0].verts[0][t.layer] in soft)
    obj = t.part.to_object()
    attr = obj.data.attributes["tarn_bone"]
    for index, name in enumerate(t.bones, 1):
        vertices = [v.index for v in obj.data.vertices if attr.data[v.index].value == index]
        obj.vertex_groups.new(name=name).add(vertices, 1, "REPLACE")
    assert all(len(v.groups) == 1 for v in obj.data.vertices)
    return obj


def build_cap():
    """The battered welding cap: crown and brim, rigid on head, one pilot-slot mesh named Cap."""
    cap = common.Part("Cap")
    crown = cap.uv("pilot", 1, 13, 4, loc=(0, -.005, .401), scale=(.133, .116, .018), color="petrol")
    for face in crown:
        face.smooth = True
    cap.beam("pilot", (-.10, .102, .396), (.10, .102, .396), .026, .011, color="petrol")
    polish.subdivide_where(cap.bm, 1, lambda island: island[0] in crown)
    obj = cap.to_object()
    obj.vertex_groups.new(name="head").add([v.index for v in obj.data.vertices], 1, "REPLACE")
    return obj


def make_rig(mesh):
    fitted = {"head": (0, .015, .20), "snout": (0, .23, .11),
              "ear.R": (.20, 0, .40), "ear.L": (-.20, 0, .40),
              "jaw": (0, .205, .080), "tail.02": (0, -.37, -.23)}
    spec = [(name, fitted.get(name, pos), parent) for name, pos, parent in rig_pilot.bone_spec("rivet", [])]
    arm = bpy.data.objects.new("TarnRig", bpy.data.armatures.new("TarnSkeleton"))
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, position, parent in spec:
        bone = arm.data.edit_bones.new(name)
        bone.head, bone.tail = position, Vector(position) + Vector((0, .08, 0))
        if parent:
            bone.parent = arm.data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for bone in arm.data.bones:
        bone.inherit_scale = "FULL"
    for bone in arm.pose.bones:
        bone.rotation_mode = "XYZ"
    mesh.parent = arm
    mesh.modifiers.new("Rigid tiger weights", "ARMATURE").object = arm
    return arm


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", action="store_true")
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    OUT.mkdir(parents=True, exist_ok=True)
    common.reset()
    polish.enable(**POLISH)
    mesh = build_model()
    cap = build_cap()
    assert common.tris(mesh) + common.tris(cap) <= 10600, common.tris(mesh) + common.tris(cap)
    if args.model:
        root = common.empty("TarnNeutral")
        mesh.parent = root
        cap.parent = root
        common.export(root, str(args.out or OUT / "pilot_tarn_neutral.glb"))
        print("TARN_MODEL: PASS", common.tris(mesh) + common.tris(cap), "triangles")
        if args.preview:
            from preview_tarn import render_model
            render_model(mesh)
    else:
        from anim_tarn import animate_and_export
        arm = make_rig(mesh)
        cap.parent = arm
        cap.modifiers.new("Rigid cap weight", "ARMATURE").object = arm
        polish.bake(arm)
        destination = args.out or SKETCH / "assets/models/pilot_tarn_anim.glb"
        animate_and_export(arm, mesh, destination)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in (arm, mesh, cap):
            obj.select_set(True)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.export_scene.gltf(filepath=str(destination), export_format="GLB", use_selection=True,
            export_animations=True, export_animation_mode="ACTIONS", export_anim_slide_to_zero=True,
            export_frame_range=False, export_force_sampling=True, export_def_bones=False,
            export_skins=True, export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
            export_cameras=False, export_lights=False)
        common.canonical_indices(str(destination), vertices=common.POLISH is not None)
        print("TARN_CAP: PASS Cap node", common.tris(cap), "triangles, rigid on head")
        if args.preview:
            from preview_tarn import render_delivery
            render_delivery(arm, mesh)


if __name__ == "__main__":
    main()
