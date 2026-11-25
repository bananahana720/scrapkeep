"""Shared pilot-v1 hierarchy; shell recipes supply head proportions and seated body.

Run with -- sable, -- kest or -- rivet. Rivet retains its accepted rest transforms.
Optional tail, crest, jaw and tool controls exist on every pilot for a uniform schema.
"""
import ast
import hashlib
import json
import math
from pathlib import Path
import sys
import subprocess

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OUT = ROOT / "artifacts/anim-pilot"
sys.path.insert(0, str(HERE))
import common
import cycles_device
import polish
import shell_base as sb

POLISH = {"detail": 1, "bevel": .003}
SOFT_MAX_TRIS = 200
HARD_PRIMITIVES = ("ring", "box", "beam")


def soft_toy(part, records, tags):
    """Subdivide the organic islands of the tagged Pilot part; each keeps its rig tag."""
    layer = part.bm.verts.layers.int["rig_part"]
    size = {}
    for f in part.bm.faces:
        size[f.verts[0][layer]] = size.get(f.verts[0][layer], 0) + len(f.verts) - 2

    def soft(index):
        primitive, bone = records[index - 1][1], tags[index - 1]
        return primitive not in HARD_PRIMITIVES and bone != "goggles" and size[index] <= SOFT_MAX_TRIS

    polish.subdivide_where(part.bm, 1, lambda island: all(soft(i) for i in {f.verts[0][layer] for f in island}))
    part.subsurf = 0


def recipe(pilot="rivet"):
    path = HERE / f"shell_{pilot}.py"
    tree = ast.parse(path.read_text())
    assert isinstance(tree.body[-1], ast.Expr)
    assert isinstance(tree.body[-1].value, ast.Call)
    assert tree.body[-1].value.func.id == "main"
    tree.body.pop()
    env = {"__file__": str(path), "__name__": f"{pilot}_recipe"}
    exec(compile(tree, str(path), "exec"), env)
    return env


def bone_spec(pilot_name, records):
    spec = [
        ("root", (0, 0, -.6), None),
        ("pelvis", (0, 0, -.3), "root"),
        ("spine_01", (0, 0, -.24), "pelvis"),
        ("spine_02", (0, 0, -.1), "spine_01"),
        ("neck", (0, .015, .005), "spine_02"),
        ("head", (0, .015, .17), "neck"),
        ("snout", (0, .21, .1), "head"),
        ("goggles", (0, .015, .24), "head"),
    ]
    for side, s in (("R", 1), ("L", -1)):
        spec += [
            ("ear." + side, (s * .265, .015, .21), "head"),
            ("shoulder." + side, (s * .13, .005, -.06), "spine_02"),
            ("upper_arm." + side, (s * .24, .015, -.09), "shoulder." + side),
            ("lower_arm." + side, (s * .36, .24, -.12), "upper_arm." + side),
            ("hand." + side, (s * .32, .4, .05), "lower_arm." + side),
            ("curl." + side, (s * .32, .43, .06), "hand." + side),
        ]
    if pilot_name != "rivet":
        def head_point(v):
            return (Vector(v)-Vector((0, .2 if pilot_name=="kest" else 0, 1.1)))*1.2325+Vector((0,.015,.17))
        def loc(index):
            return Vector(records[index][4]["loc"])
        if pilot_name == "sable":
            anchors = {"head": loc(0), "snout": loc(15), "goggles":loc(18),
                       "ear.L":records[5][4]["matrix"].translation,
                       "ear.R":records[12][4]["matrix"].translation}
        else:
            anchors = {"head": loc(0), "snout":loc(10), "goggles":(loc(2)+loc(6))*.5,
                       "ear.L":loc(13)+Vector((-.1,0,0)),
                       "ear.R":loc(13)+Vector((.1,0,0))}
        spec = [(name, tuple(head_point(anchors[name])) if name in anchors else pos, parent) for name,pos,parent in spec]
    head = next(Vector(pos) for name,pos,parent in spec if name=="head")
    spec += [("tail.01", (0,-.16,-.27), "pelvis"),
             ("tail.02", (0,-.46,-.20), "tail.01"),
             ("crest", tuple(head+Vector((0,-.05,.24))), "head"),
             ("jaw", tuple(head+Vector((0,.17,-.1))), "head"),
             ("tool.R", (.32,.4,.05), "hand.R")]
    return spec


def accessories(pilot_name, arm):
    meshes=[]
    def attach(part,bone):
        obj=part.to_object()
        obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))),1,"REPLACE")
        obj.parent=arm
        obj.modifiers.new("Rigid accessory", "ARMATURE").object=arm
        meshes.append(obj)
    if pilot_name == "sable":
        p=common.Part("TailBase")
        p.bevel,p.subsurf=0,1
        p.rod("pilot",(0,-.16,-.27),(0,-.46,-.20),.105,10,r2=.14,color="oxide")
        attach(p,"tail.01")
        p=common.Part("TailTip")
        p.bevel,p.subsurf=0,1
        p.rod("pilot",(0,-.46,-.20),(0,-.65,.03),.14,10,r2=.075,color="oxide")
        p.rod("pilot",(0,-.65,.03),(0,-.72,.14),.077,10,r2=.012,color="bone")
        attach(p,"tail.02")
        p=common.Part("Tool")
        p.bevel,p.subsurf=.004,0
        p.rod("bare_metal",(.32,.36,.02),(.32,.48,.20),.019,8)
        p.rod("class_accent",(.32,.36,.02),(.32,.42,.11),.028,8)
        p.ring("bare_metal",.029,.047,.025,10,loc=(.32,.49,.215),rot=(math.pi/2,0,0),arc=(.35,math.tau-.35))
        attach(p,"tool.R")
    else:
        for side,s in (("R",1),("L",-1)):
            for name,bone,base,tip in [
                ("WingUpper", "upper_arm.", (s*.25,.035,-.10),(s*.40,-.11,-.14)),
                ("WingFan", "hand.", (s*.32,.40,.05),(s*.49,.54,.09))]:
                p=common.Part(name+"."+side)
                p.bevel,p.subsurf=0,1
                for k in range(4):
                    a=Vector(base)+Vector((s*.018*k,0,-.018*k))
                    b=Vector(tip)+Vector((s*.035*k,-.025*k,-.015*k))
                    p.rod("pilot",a,b,.038,6,r2=.006,color="bone" if k%2 else "petrol")
                attach(p,bone+side)
    return meshes


def build(pilot_name="rivet", out=None, polished=True):
    global OUT
    OUT = Path(out) if out else ROOT / "artifacts/anim-pilot" / (pilot_name if pilot_name != "rivet" else "")
    common.reset()
    common.preview_class({"rivet":"copper", "sable":"mint", "kest":"amber"}[pilot_name])
    if polished:
        polish.enable(**POLISH)
    env = recipe(pilot_name)
    records = []
    originals = {}
    depth = [0]
    phase = ["head"]

    def capture(name, fn):
        def wrapped(part, *args, **kwargs):
            if part.name != "Pilot" or depth[0]:
                return fn(part, *args, **kwargs)
            layer = part.bm.verts.layers.int.get("rig_part") or part.bm.verts.layers.int.new("rig_part")
            before = set(part.bm.verts)
            depth[0] += 1
            try:
                result = fn(part, *args, **kwargs)
            finally:
                depth[0] -= 1
            new = set(part.bm.verts) - before
            for v in new:
                v[layer] = len(records) + 1
            records.append((phase[0], name, len(new), args, kwargs))
            return result
        return wrapped

    for name in ("uv", "ring", "rod", "beam", "box", "cyl", "prism"):
        originals[name] = getattr(common.Part, name)
        setattr(common.Part, name, capture(name, originals[name]))
    original_to_object = common.Part.to_object

    def to_object(part, *args, **kwargs):
        if not polished:
            pass
        elif part.name == "Pilot":
            soft_toy(part, records, tags)
        else:
            part.bevel, part.subsurf = 0, 0
        return original_to_object(part, *args, **kwargs)

    head_tags = {
        "rivet": ["head", "snout", "snout", "goggles", "ear.L", "goggles", "goggles", "goggles", "snout", "ear.R", "goggles", "goggles", "goggles", "snout", "goggles"],
        "sable": ["head"] + [b for side in ("L", "R") for b in ["snout", "goggles", "goggles", "goggles", "ear."+side, "ear."+side, "ear."+side]] + ["snout", "jaw", "snout", "goggles", "goggles"],
        "kest": ["head"] + ["goggles"]*9 + ["snout", "snout", "jaw"] + ["crest"]*3,
    }[pilot_name]
    body_tags = ["spine_01", "spine_02"]
    for side in ("L", "R"):
        body_tags += ["pelvis", "pelvis", "pelvis", "shoulder." + side,
                      "upper_arm." + side, "lower_arm." + side, "hand." + side, "spine_02"]
    tags = head_tags + body_tags
    common.Part.to_object = to_object
    try:
        animal = env["pilot"]()
        phase[0] = "body"
        root, hull, pilot = sb.spherical(pilot_name.title(), env["pod"](), animal)
    finally:
        common.Part.to_object = original_to_object
        for name, fn in originals.items():
            setattr(common.Part, name, fn)

    arm = bpy.data.objects.new(pilot_name.title()+"Rig", bpy.data.armatures.new(pilot_name.title()+"Skeleton"))
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    spec = bone_spec(pilot_name, records)
    for name, position, parent in spec:
        bone = arm.data.edit_bones.new(name)
        bone.head = position
        bone.tail = Vector(position) + Vector((0, .08, 0))
        if parent:
            bone.parent = arm.data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for bone in arm.data.bones:
        bone.inherit_scale = "FULL"
    arm.show_in_front = True
    arm.data.display_type = "STICK"
    for b in arm.pose.bones:
        b.rotation_mode = "XYZ"

    assert len(records) == len(tags), (len(records), len(tags), [(r[0], r[1]) for r in records])
    attr = pilot.data.attributes["rig_part"]
    for index, name in enumerate(tags):
        vg = pilot.vertex_groups.get(name) or pilot.vertex_groups.new(name=name)
        indices = [v.index for v in pilot.data.vertices if attr.data[v.index].value == index + 1]
        assert indices, (index, name)
        vg.add(indices, 1, "REPLACE")
    pilot.parent = arm
    modifier = pilot.modifiers.new("Rigid primitive weights", "ARMATURE")
    modifier.object = arm
    pilot["source"] = f"shell_{pilot_name}.pilot + shell_base.spherical; " + ("soft-toy polish (POLISH.md)" if polished else "unchanged original vertices")
    meshes = [pilot]
    if pilot_name == "rivet":
        for side, s in (("R", 1), ("L", -1)):
            claws = common.Part("Claws." + side)
            claws.bevel, claws.subsurf = 0, 1
            for dx in (-.041, 0, .041):
                claws.rod("pilot", (s * .32 + dx, .44, .055),
                          (s * .32 + dx, .535, .035), .015, 6, color="bone", r2=.004)
            obj = claws.to_object()
            vg = obj.vertex_groups.new(name="curl." + side)
            vg.add(list(range(len(obj.data.vertices))), 1, "REPLACE")
            obj.parent = arm
            obj.modifiers.new("Rigid claws", "ARMATURE").object = arm
            meshes.append(obj)
    else:
        meshes.extend(accessories(pilot_name, arm))
    if polished:
        polish.bake(arm)
    for obj in common.tree(root):
        obj.hide_render = True
    root.hide_render = True
    pilot.hide_render = False
    arm["pelvis_anchor"] = [0, 0, -.3]
    OUT.mkdir(parents=True, exist_ok=True)
    report = {
        "bones": len(spec), "original_pilot_triangles": common.tris(pilot),
        "export_pilot_triangles": sum(common.tris(o) for o in meshes),
        "parts": [{"index": i+1, "phase": r[0], "primitive": r[1], "bone": tags[i]}
                  for i, r in enumerate(records)],
        "sources": {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in (HERE / f"shell_{pilot_name}.py", HERE / "shell_base.py", HERE / "common.py")},
        "scope": "pilot animation only; no game integration; +Y forward, +Z up, character R is +X",
        "schema": "pilot-v1", "pilot": pilot_name,
        "bone_hierarchy": {b.name: b.parent.name if b.parent else None for b in arm.data.bones},
        "rest_heads": {b.name: list(b.head_local) for b in arm.data.bones},
        "mesh_nodes": [o.name for o in meshes],
    }
    (OUT / "rig-manifest.json").write_text(json.dumps(report, indent=2) + "\n")
    return arm, meshes, root


def studio():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.render.resolution_x = 480
    scene.render.resolution_y = 480
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    scene.world = bpy.data.worlds.new("Neutral studio")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.39, .40, .39, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .65
    for name, location, energy, size in [
        ("Key", (2, 3, 4), 180, 3), ("Fill", (-3, 1, 1), 100, 3),
        ("Rim", (1, -3, 3), 180, 2)]:
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.shape, data.size = energy, "DISK", size
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.location = location
        common._look(obj, (0, 0, 0))
    cam = bpy.data.objects.new("PilotCamera", bpy.data.cameras.new("PilotCamera"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.65
    scene.camera = cam
    return cam


def render_view(cam, path, view="front", scale=1.65):
    positions = {"front": (0, 5, -.035), "back": (0, -5, -.035),
                 "side": (5, 0, -.035), "chase": (2.5, -4, 1.6)}
    cam.location = positions[view]
    common._look(cam, (0, .05, -.035))
    cam.data.ortho_scale = scale
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def clear_pose(arm):
    for bone in arm.pose.bones:
        bone.location = (0, 0, 0)
        bone.rotation_euler = (0, 0, 0)
        bone.scale = (1, 1, 1)
    bpy.context.view_layer.update()


def point_segment(arm, name, child, target):
    """Rotate one rest segment toward a world target, retaining its length."""
    bone = arm.pose.bones[name]
    child_bone = arm.pose.bones[child]
    bpy.context.view_layer.update()
    direction = Vector(target) - bone.head
    current = child_bone.head - bone.head
    rotation = current.rotation_difference(direction)
    matrix = bone.matrix.copy()
    matrix = rotation.to_matrix().to_4x4() @ matrix
    matrix.translation = bone.head
    bone.matrix = matrix
    bpy.context.view_layer.update()


def main():
    args=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    pilot_name=args[0] if args else "rivet"
    arm, meshes, root = build(pilot_name)
    cam = studio()
    refs = OUT / "references"
    refs.mkdir(exist_ok=True)
    for view in ("front", "back", "side"):
        render_view(cam, refs / (view + ".png"), view)
    for side, s in (("R", 1), ("L", -1)):
        point_segment(arm, "upper_arm." + side, "lower_arm." + side, (s, .015, -.09))
        point_segment(arm, "lower_arm." + side, "hand." + side, (s * 1.5, .015, -.09))
    render_view(cam, refs / "t-pose.png", "front")
    clear_pose(arm)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"{pilot_name}-rig.blend"))
    subprocess.run(["python",str(HERE/"compose_pilot_evidence.py"),"--pilot",pilot_name,"--rig"],check=True)


if __name__ == "__main__":
    main()
