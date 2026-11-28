"""Remembered cannon model, then pilot-v1 rig and seven rigid-cast reactions.

blender -b --threads 2 --python-exit-code 1 --python this_file.py
Add -- --preview to render CPU Cycles turnarounds and clip key poses.
Add -- --no-shell to leave world_one/shell_cannon.glb untouched: without it this recipe re-exports
the shell through common.export, not shell_cannon.py's finish(), so its bytes would change
(P-UNITS section 0.4 item 14; shell_cannon.py owns that GLB).
Evidence and editable intermediate models stay in artifacts/local/dress-preview/PCN.
"""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import common
import cycles_device
import polish
import rig_pilot as rig
import anim_rivet_drop as shared
from common import Part

ROOT = HERE.parents[3]
OUT = ROOT / "artifacts/local/dress-preview/PCN"
MODEL = HERE.parents[1] / "assets/models/pilot_cannon_anim.glb"
SHEET_ROOT = Path.home() / "Projects/scrapkeep/.claude/worktrees/game-completion-plan-75f776/artifacts/local/alpha/push/w1/D6/out"
REFERENCES = {
    "pilot-cannon.png": "77ac207048c0954c1b70b4dccf8df5b8211bde7003225be1ea65879b4b37fb1d",
    "shell-cannon.png": "a8b6fbac36c93b0b33588bef90ac8a3df372cf1053150da33a67580251ae5bf6",
    "motion-cannon.png": "8920e472933f8517c1f179ba37bbadc25bc2a53c7a04bebd10e42beb386d8e38",
    "pilots-lineup.png": "ba8c5d3fe7601adfc29741f58422359dc49b1085cf3439d164ed59f7c6de8b87",
}
CLIPS = {
    "drop_land": [1, 5, 10, 16, 24, 37, 51, 66],
    "big_cheer": [1, 7, 16, 25, 46, 58, 73, 85],
    "wince": [1, 3, 5, 8, 12, 16],
    "slump": [1, 7, 15, 23, 31, 39, 46],
    "phew": [1, 5, 10, 14, 19, 25],
    "brace": [1, 3, 6, 10, 14, 19],
    "heave": [1, 3, 7, 10, 15, 25],
}
OBSERVATIONS = {
    "drop_land": "Motion top-left: muzzle down, compact hinge; reject flesh squash; rebound to fixed grips.",
    "big_cheer": "Motion top-second: both paddles wide/up, muzzle upward; keep shared arm lengths and rigid panels.",
    "wince": "Motion top-third: sharp profile head swivel, modest shoulders; lenses remain static.",
    "slump": "Motion top-right: hanging paddles beside seated knees, downward muzzle; no length change.",
    "phew": "Motion bottom-left: anatomical LEFT release, profile head, right control planted; reject mirror.",
    "brace": "Motion bottom-middle: forward chest and muzzle, both grips planted; overlap panels, no squash.",
    "heave": "Motion bottom-right: one anatomical RIGHT punch, left counterbrace; one drive then settle.",
}
HEAD_LIFT = .08


class PilotPart(Part):
    """One material-packed skin; modelling calls assign one rigid control per vertex."""
    def __init__(self):
        super().__init__("Pilot")
        self.bone_layer = self.bm.verts.layers.int.new("pilot_bone")
        self.tags = []

    def piece(self, bone, function, *args, **kwargs):
        if bone not in self.tags:
            self.tags.append(bone)
        before = set(self.bm.verts)
        faces = function(*args, **kwargs)
        for v in set(self.bm.verts)-before:
            v[self.bone_layer] = self.tags.index(bone)+1
        return faces


def cast_form(p, size, centre, slot="ancient_enamel", colour="bone", u=16, v=10, squared=.86):
    """Continuous rounded casting with shaped chips and broad material wear.

    A superellipse loft defines head/torso/paddles. No overlapping sphere stack
    or generated external geometry; the closed surface is authored in metres.
    """
    def power(a):
        return math.copysign(abs(a)**squared, a)
    rows = []
    c = Vector(centre)
    for j in range(1, v):
        t = math.pi*j/v
        row = []
        for i in range(u):
            a = math.tau*i/u
            point = Vector((power(math.sin(t)*math.cos(a))*size[0]/2,
                            power(math.sin(t)*math.sin(a))*size[1]/2,
                            power(math.cos(t))*size[2]/2))
            chip = .976 if (i*7+j*11) % 47 == 0 else 1.0
            row.append(p.bm.verts.new(c+point*chip))
        rows.append(row)
    top = p.bm.verts.new(c+Vector((0, 0, size[2]/2)))
    bottom = p.bm.verts.new(c-Vector((0, 0, size[2]/2)))
    faces = []
    for i in range(u):
        k = (i+1)%u
        faces.append(p.bm.faces.new((top, rows[0][i], rows[0][k])))
        for j in range(len(rows)-1):
            faces.append(p.bm.faces.new((rows[j][i], rows[j+1][i], rows[j+1][k], rows[j][k])))
        faces.append(p.bm.faces.new((rows[-1][k], rows[-1][i], bottom)))
    p.paint(faces, slot, colour if slot == "ancient_enamel" else None)
    for f in faces:
        f.smooth = True
    return faces


def carapace(p, upper):
    """Two thick overlapping halves of one rear oval; each is a rigid casting."""
    z0, z1 = (-.085, .22) if upper else (-.34, -.065)
    rows = []
    for j in range(9):
        z = z0+(z1-z0)*j/8
        height = (z+.06)/.28
        width = .28*math.sqrt(max(0, 1-height*height))
        rows.append([p.bm.verts.new(Vector((width*math.sin(-math.pi/2+math.pi*i/12),
                    -.12-.10*math.sqrt(max(0, 1-height*height))*math.cos(-math.pi/2+math.pi*i/12), z)))
                     for i in range(13)])
    faces = []
    for j in range(8):
        for i in range(12):
            verts = (rows[j][i], rows[j][i+1], rows[j+1][i+1], rows[j+1][i])
            if (verts[0].co-verts[1].co).length < 1e-6:
                verts = (verts[0], verts[2], verts[3])
            elif (verts[2].co-verts[3].co).length < 1e-6:
                verts = (verts[0], verts[1], verts[2])
            f = p.bm.faces.new(verts)
            f.smooth = True
            faces.append(f)
    p.paint(faces, "ancient_enamel", "petrol")
    inside = [[p.bm.verts.new(Vector((q.co.x, -.02, q.co.z))) for q in row] for row in rows]
    for j in range(8):
        for i in range(12):
            verts = (inside[j][i], inside[j+1][i], inside[j+1][i+1], inside[j][i+1])
            if (verts[0].co-verts[3].co).length < 1e-6:
                verts = (verts[0], verts[1], verts[2])
            elif (verts[1].co-verts[2].co).length < 1e-6:
                verts = (verts[0], verts[1], verts[3])
            f = p.bm.faces.new(verts)
            f.smooth = True
            p.paint([f], "ancient_enamel", "petrol")
    for j in (0, 8):
        if (rows[j][0].co-rows[j][-1].co).length > .001:
            for i in range(12):
                p.paint([p.bm.faces.new((rows[j][i], rows[j][i+1], inside[j][i+1], inside[j][i]))], "ancient_enamel", "petrol")
    for i in (0, 12):
        for j in range(8):
            p.paint([p.bm.faces.new((rows[j][i], inside[j][i], inside[j+1][i], rows[j+1][i]))], "ancient_enamel", "petrol")
    for slot, width, offset in (("rubber", .02, .002), ("ancient_light", .008, .003)):
        ribbon = []
        for j in range(9):
            z = z0+(z1-z0)*j/8
            y = -.12-.10*math.sqrt(max(0, 1-((z+.06)/.28)**2))-offset
            ribbon.append([p.bm.verts.new(Vector((x, y, z))) for x in (-width/2, width/2)])
        for j in range(8):
            f = p.bm.faces.new((ribbon[j][0], ribbon[j+1][0], ribbon[j+1][1], ribbon[j][1]))
            f.smooth = True
            p.paint([f], slot)
    p.paint([faces[14], faces[65]], "ancient_enamel", common.mix("petrol", "bone", .23))
    return faces


def fan(p, s):
    outline = [(-.08, -.026), (-.075, .018), (-.063, .036), (-.049, .04),
               (-.034, .031), (-.020, .04), (0, .043), (.020, .04),
               (.034, .031), (.049, .04), (.063, .036), (.075, .018),
               (.08, -.026), (.055, -.037), (-.055, -.037)]
    return p.prism("ancient_enamel", outline, .10,
                   matrix=common.mtx((s*.32, .43, .06), (math.pi/2, 0, 0)), color="bone")


def paddle(p, a, b):
    matrix, length = common.aim(a, b)
    faces = cast_form(p, (.16, .14, length+.07), (0, 0, 0), u=12, v=6)
    for vertex in p.verts_of(faces):
        vertex.co = matrix@vertex.co
    return faces


def model():
    p = PilotPart()
    lift = HEAD_LIFT
    p.piece("head", cast_form, p, (.34, .30, .30), (0, .04, .21+lift), u=16, v=8, squared=.90)
    p.piece("snout", p.ring, "ancient_enamel", .03, .065, .12, 20,
            loc=(0, .24, .19+lift), rot=(math.pi/2, 0, 0), color="bone")
    p.piece("snout", p.cyl, "rubber", .029, .029, .005, 16,
            loc=(0, .215, .19+lift), rot=(math.pi/2, 0, 0))
    for s in (-1, 1):
        p.piece("head", cast_form, p, (.055, .025, .055), (s*.11, .16, .24+lift),
                slot="rubber", u=12, v=8)
        p.piece("head", p.ring, "ancient_enamel", .0275, .038, .014, 12,
                loc=(s*.11, .156, .24+lift), rot=(math.pi/2, 0, 0), color=common.mix("bone", "charcoal", .18))
    p.piece("neck", cast_form, p, (.18, .16, .12), (0, .03, .12), colour="petrol", u=12, v=6)
    p.piece("spine_01", cast_form, p, (.56, .41, .43), (0, -.005, -.17), colour="petrol", u=16, v=8)
    p.piece("spine_02", cast_form, p, (.28, .19, .13), (0, .02, .015), colour="petrol", u=12, v=6)
    p.piece("spine_02", carapace, p, True)
    p.piece("spine_01", carapace, p, False)
    for s, side in ((1, "R"), (-1, "L")):
        p.piece("pelvis", cast_form, p, (.24, .32, .20), (s*.18, .18, -.30), u=12, v=8)
        p.piece("pelvis", p.rod, "ancient_enamel", (s*.18, .20, -.30), (s*.20, .38, -.46),
                .082, 10, color="bone")
        p.piece("pelvis", cast_form, p, (.20, .28, .12), (s*.20, .45, -.48), slot="rubber", u=12, v=6)
        p.piece("shoulder."+side, cast_form, p, (.20, .18, .21), (s*.22, .005, -.09), u=12, v=8)
        p.piece("upper_arm."+side, paddle, p, (s*.24, .015, -.09), (s*.36, .24, -.12))
        p.piece("lower_arm."+side, paddle, p, (s*.36, .24, -.12), (s*.32, .40, .04))
        p.piece("hand."+side, cast_form, p, (.16, .14, .10), (s*.32, .40, .05), u=12, v=6)
        p.piece("curl."+side, fan, p, s)
    p.piece("tail.01", p.rod, "ancient_enamel", (0, -.22, -.27), (0, -.32, -.27),
            .0225, 10, r2=.004, color="bone")
    obj = p.to_object()
    tags = obj.data.attributes["pilot_bone"]
    for index, name in enumerate(p.tags):
        indices = [v.index for v in obj.data.vertices if tags.data[v.index].value == index+1]
        obj.vertex_groups.new(name=name).add(indices, 1, "REPLACE")
    assert all(len(v.groups) == 1 for v in obj.data.vertices)
    assert common.tris(obj) <= 6000
    print("CANNON_MODEL: %d triangles; %d source vertices; rigid weights assigned" % (common.tris(obj), len(obj.data.vertices)))
    return obj


def skeleton(mesh):
    arm = bpy.data.objects.new("CannonRig", bpy.data.armatures.new("CannonSkeleton"))
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    fitted = {"head": (0, .04, .21+HEAD_LIFT), "snout": (0, .24, .19+HEAD_LIFT),
              "jaw": (0, .19, .12+HEAD_LIFT),"tail.01": (0, -.22, -.27), "tail.02": (0, -.30, -.27)}
    spec = [(name, fitted.get(name, pos), parent) for name, pos, parent in rig.bone_spec("rivet", [])]
    for name, position, parent in spec:
        bone = arm.data.edit_bones.new(name)
        bone.head = position
        bone.tail = Vector(position)+Vector((0, .08, 0))
        if parent:
            bone.parent = arm.data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for bone in arm.data.bones:
        bone.inherit_scale = "FULL"
    for bone in arm.pose.bones:
        bone.rotation_mode = "XYZ"
    mesh.parent = arm
    mesh.modifiers.new("Rigid cast parts", "ARMATURE").object = arm
    return arm, spec


def rotate(arm, name, angles):
    arm.pose.bones[name].rotation_euler = tuple(math.radians(a) for a in angles)


def pose(arm, clip, k):
    rig.clear_pose(arm)
    last = len(CLIPS[clip])-1
    if k in (0, last):
        return
    right, left = Vector((.32, .40, .05)), Vector((-.32, .40, .05))
    pitch = head_pitch = yaw = roll = 0
    if clip == "drop_land":
        pitch = [0, -6, -14, -8, 5, 2, -1, 0][k]
        head_pitch = [0, -8, -14, -5, 8, 3, -1, 0][k]
    elif clip == "big_cheer":
        pitch = [0, -5, 2, 4, 4, 5, 2, 0][k]
        head_pitch = [0, -8, 8, 20, 22, 18, 5, 0][k]
        yaw = [0, 0, 8, 12, 22, 12, 5, 0][k]
        widths = [0, .40, .48, .49, .49, .50, .43, 0]
        heights = [0, .04, .16, .22, .22, .23, .12, 0]
        right = Vector((widths[k], .09, heights[k]))
        left = Vector((-widths[k], .09, heights[k]))
    elif clip == "wince":
        strength = [0, 1, .90, .50, .15, 0][k]
        pitch, head_pitch, yaw, roll = 4*strength, -8*strength, 34*strength, 7*strength
        right += Vector((.06, -.06, .05))*strength
        left += Vector((-.06, -.06, .05))*strength
    elif clip == "slump":
        strength = [0, .3, .8, 1, 1, .4, 0][k]
        pitch, head_pitch, yaw = -7*strength, -23*strength, 8*strength
        right = right.lerp(Vector((.41, .22, -.29)), strength)
        left = left.lerp(Vector((-.41, .22, -.29)), strength)
    elif clip == "phew":
        strength = [0, .45, 1, 1, .35, 0][k]
        pitch, head_pitch, yaw = 2*strength, -3*strength, -40*strength
        left = left.lerp(Vector((-.49, .18, .13)), strength)
    elif clip == "brace":
        strength = [0, 1, 1, .85, .35, 0][k]
        pitch, head_pitch = -10*strength, 10*strength
    elif clip == "heave":
        pitch = [0, 6, -8, -6, -2, 0][k]
        head_pitch = [0, 5, -7, -5, -2, 0][k]
        strength = [0, .35, 1, .85, .35, 0][k]
        right = right.lerp(Vector((.45, .24, .19)), strength)
    rotate(arm, "spine_01", (pitch*.35, 0, 0))
    rotate(arm, "spine_02", (pitch*.65, 0, 0))
    rotate(arm, "head", (head_pitch, roll, yaw))
    bpy.context.view_layer.update()
    for side, target in (("R", right), ("L", left)):
        shared.solve_arm(arm, side, target)
        shared.world_hand(arm, side, (0, 0, 0))
    assert max(abs(c-1) for b in arm.pose.bones for c in b.scale) < 1e-6


def actions(arm):
    tables = {}
    acts = []
    for clip, frames in CLIPS.items():
        if arm.animation_data:
            arm.animation_data.action = None
        rows = []
        for k, frame in enumerate(frames):
            pose(arm, clip, k)
            rows.append({"frame": frame, "observation": OBSERVATIONS[clip], "bones": {
                b.name: {"rotation_degrees_xyz": [math.degrees(a) for a in b.rotation_euler],
                         "location": list(b.location), "scale": list(b.scale)} for b in arm.pose.bones}})
            for b in arm.pose.bones:
                for path in ("location", "rotation_euler", "scale"):
                    b.keyframe_insert(data_path=path, frame=frame, group=b.name)
        action = arm.animation_data.action
        action.name = clip
        action.use_fake_user = True
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for point in curve.keyframe_points:
                            point.interpolation = "LINEAR"
        planted = ("R", "L") if clip in ("brace", "drop_land") else (("R",) if clip == "phew" else (("L",) if clip == "heave" else ()))
        baked = []
        for frame in range(1, frames[-1]+1):
            bpy.context.scene.frame_set(frame)
            if frame not in (1, frames[-1]):
                for side in planted:
                    shared.solve_arm(arm, side, ((1 if side == "R" else -1)*.32, .40, .05))
                    shared.world_hand(arm, side, (0, 0, 0))
            baked.append({b.name: (tuple(b.location), tuple(b.rotation_euler), tuple(b.scale)) for b in arm.pose.bones})
        for frame, values in enumerate(baked, 1):
            for b in arm.pose.bones:
                b.location, b.rotation_euler, b.scale = values[b.name]
                for path in ("location", "rotation_euler", "scale"):
                    b.keyframe_insert(data_path=path, frame=frame, group=b.name)
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for point in curve.keyframe_points:
                            point.interpolation = "LINEAR"
        acts.append(action)
        tables[clip] = rows
    return acts, tables


def check(arm, mesh, acts):
    checks = []
    scene = bpy.context.scene
    for act in acts:
        arm.animation_data.action = act
        end = int(act.frame_range[1])
        radius = root_error = grip_error = scale_error = 0
        for half in range(2, end*2+1):
            frame = half/2
            scene.frame_set(int(frame), subframe=frame%1)
            bpy.context.view_layer.update()
            evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            data = evaluated.to_mesh()
            radius = max(radius, max((evaluated.matrix_world@v.co).length for v in data.vertices))
            evaluated.to_mesh_clear()
            root_error = max(root_error, (arm.pose.bones["pelvis"].head-Vector((0, 0, -.30))).length)
            scale_error = max(scale_error, max(abs(c-1) for b in arm.pose.bones for c in b.scale))
            for side, s in (("R", 1), ("L", -1)):
                if act.name in ("brace", "drop_land") or (act.name == "phew" and side == "R") or (act.name == "heave" and side == "L"):
                    grip_error = max(grip_error, (arm.pose.bones["hand."+side].head-Vector((s*.32, .40, .05))).length)
        neutral_error = 0
        for frame in (1, end):
            scene.frame_set(frame)
            for b in arm.pose.bones:
                neutral_error = max(neutral_error, max(abs(v) for v in (*b.location, *b.rotation_euler)))
        assert radius < .98, (act.name, radius)
        assert root_error < 1e-6, root_error
        assert scale_error < 1e-5, scale_error
        assert neutral_error < 1e-5, neutral_error
        assert grip_error < .001, (act.name, grip_error)
        checks.append({"clip": act.name, "seconds": (end-1)/30, "half_frame_samples": end*2-1,
                       "max_vertex_radius": radius, "pelvis_drift": root_error,
                       "grip_error": grip_error, "scale_error": scale_error,
                       "neutral_error": neutral_error})
        print("CANNON_CLIP: %s %.6fs radius %.6f grip %.6f neutral %.6f" % (act.name, (end-1)/30, radius, grip_error, neutral_error))
    return checks


def export(arm, mesh, acts):
    arm.animation_data.action = acts[0]
    bpy.context.scene.frame_set(1)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=str(MODEL), export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIONS", export_anim_slide_to_zero=True,
        export_frame_range=False, export_force_sampling=True, export_def_bones=False,
        export_skins=True, export_yup=True, export_materials="EXPORT", export_cameras=False, export_lights=False)
    common.canonical_indices(str(MODEL), vertices=common.POLISH is not None)
    print("EXPORTED", MODEL)


def shell_module():
    spec = importlib.util.spec_from_file_location("shell_cannon", HERE/"world_one/shell_cannon.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def previews(arm, mesh, acts, shell):
    mod = shell_module()
    render_id = hashlib.sha256(MODEL.read_bytes()+mod.MODEL.read_bytes()).hexdigest()[:12]
    target = OUT/("render-"+render_id)
    target.mkdir(exist_ok=True)
    cam = rig.studio()
    scene = bpy.context.scene
    cycles_device.use(scene)
    scene.cycles.samples = 12
    scene.render.resolution_x = scene.render.resolution_y = 640
    nodes = common.material("glass").node_tree.nodes
    links = common.material("glass").node_tree.links
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    reflection = nodes.new("ShaderNodeBsdfGlossy")
    reflection.inputs["Roughness"].default_value = .035
    fresnel = nodes.new("ShaderNodeFresnel")
    fresnel.inputs["IOR"].default_value = 1.32
    mix = nodes.new("ShaderNodeMixShader")
    links.new(fresnel.outputs[0], mix.inputs[0])
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(reflection.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], nodes.get("Material Output").inputs["Surface"])
    views = {"front": (0, 5, -.04), "side": (5, 0, -.04), "back": (0, -5, -.04), "three-quarter": (3.4, 4.5, 2.0)}
    arm.animation_data.action = acts[0]
    scene.frame_set(1)
    for name, pos in views.items():
        cam.location = pos
        common._look(cam, (0, 0, -.04))
        cam.data.ortho_scale = 2.28
        scene.render.filepath = str(target/f"turnaround-{name}.png")
        bpy.ops.render.render(write_still=True)
    keys = {"drop_land": 10, "big_cheer": 25, "wince": 3, "slump": 23, "phew": 10, "brace": 6, "heave": 7}
    for act in acts:
        arm.animation_data.action = act
        scene.frame_set(keys[act.name])
        cam.location = views["three-quarter"]
        common._look(cam, (0, 0, -.04))
        scene.render.filepath = str(target/f"clip-{act.name}.png")
        bpy.ops.render.render(write_still=True)
    scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"pilot_cannon.blend"))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--no-shell", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    OUT.mkdir(parents=True, exist_ok=True)
    common.reset()
    polish.enable(detail=2, bevel=.004)
    for name, digest in REFERENCES.items():
        assert hashlib.sha256((SHEET_ROOT/name).read_bytes()).hexdigest() == digest, "Inspected reference changed: "+name
    common.SLOTS["ancient_light"] = dict(common.SLOTS["ancient_light"], emit=.45)
    mesh = model()
    shell = None
    if not args.no_shell:
        polished, detail = common.POLISH, common.DETAIL
        common.POLISH, common.DETAIL = None, 1
        mod = shell_module()
        shell = mod.build()
        common.export(shell, str(mod.MODEL))
        common.POLISH, common.DETAIL = polished, detail
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"pilot_cannon-model.blend"))
    arm, spec = skeleton(mesh)
    acts, tables = actions(arm)
    bpy.context.scene.render.fps = 30
    checks = check(arm, mesh, acts)
    polish.bake(arm)
    export(arm, mesh, acts)
    arm.animation_data.action = acts[0]
    bpy.context.scene.frame_set(1)
    sources = [HERE/"pilot_cannon.py", HERE/"world_one/shell_cannon.py", HERE/"common.py", HERE/"rig_pilot.py", HERE/"anim_rivet_drop.py"]
    receipt = {"schema": "pilot-v1", "bones": spec, "checks": checks, "poses": tables,
               "source_hashes": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
               "reference_hashes": {name: hashlib.sha256((SHEET_ROOT/name).read_bytes()).hexdigest() for name in REFERENCES},
               "axis": "+Z up, +Y forward, +X anatomical right; glTF (x,z,-y)",
               "scope": "Asset delivery only; no HeroAssets wiring or gameplay change"}
    (OUT/"receipt.json").write_text(json.dumps(receipt, indent=2)+"\n")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"pilot_cannon-rig.blend"))
    if args.preview:
        previews(arm, mesh, acts, shell)


if __name__ == "__main__":
    main()
