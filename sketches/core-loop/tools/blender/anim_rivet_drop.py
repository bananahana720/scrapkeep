"""Image-led Rivet drop_land action, 16 explicit poses at 30 fps.

First run -- --author to resolve the image observations into rivet-drop-poses.json.
Normal runs consume only that committed pose table, never infer poses from prose.
Use -- --draft for four inexpensive checkpoint renders before a full render.
"""
import hashlib
import json
import math
from pathlib import Path
import sys
import subprocess

import bpy
from mathutils import Vector, Matrix, Euler

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import rig_rivet as rig
import common

OUT = rig.OUT
TABLE = HERE / "rivet-drop-poses.json"
FRAMES = [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 22, 24, 26, 29, 34]

OBSERVATIONS = [
    (-2, -3, 1, 1, 0, (.32,.4,.05), (-.32,.4,.05), -35,
     "01: slight forward snout; hands level; side forearms reach forward."),
    (-8, -16, .95, .98, -.015, (.32,.4,.05), (-.32,.4,.05), -55,
     "02: steepest pre-impact head nod in side view, wrists close to snout."),
    (-9, -12, .90, .96, -.028, (.32,.4,.05), (-.32,.4,.05), -60,
     "03: added pink cheeks, raised shoulders, broad low head; cheek mesh absent."),
    (-8, -8, .88, .95, -.025, (.32,.4,.05), (-.32,.4,.05), -65,
     "04: head leveler than key 02; symmetrical tucked fists; compact torso."),
    (-3, -2, .80, .72, -.07, (.72,.10,.035), (-.72,.10,.035), 15,
     "05: broad squashed head, almost straight arms diagonally outward, splayed fingers."),
    (0, 0, .94, .97, -.015, (.50,.20,.22), (-.50,.20,.22), 12,
     "06: head nearly round again; elbows bent and palms raised beside lower face."),
    (3, 22, 1.10, 1.03, .025, (.36,.18,.40), (-.26,.34,.06), -65,
     "07: right fist at temple height; left across chest; snout angled steeply up."),
    (3, 20, 1.13, 1, .025, (.36,.10,.59), (-.32,.4,.05), -75,
     "08: right fist above head, left grip; BACK VIEW MIRRORS ARM, front/side chosen."),
    (5, 26, 1.15, 1.02, .035, (.32,.05,.66), (-.27,.35,.075), -80,
     "09: highest fist, near straight arm; open mouth invented by ImageGen, snout approximation."),
    (1, 10, 1.06, 1, .015, (.38,.17,.37), (-.32,.4,.05), -65,
     "10: fist drops beside upper goggle edge, elbow flares; mouth remains open in image."),
    (-2, 0, 1, 1, 0, (.23,.32,.27), (-.32,.4,.05), -10,
     "11: right hand already overlaps outer goggle in reference; head nearly level."),
    (-2, -5, .99, 1, -.004, (.225,.30,.30), (-.32,.4,.05), 0,
     "12: fingertips on upper outer copper rim; elbow outward, tiny downward nod."),
    (1, 2, 1.045, 1, .008, (.46,.22,.25), (-.32,.4,.05), 12,
     "13: open right hand well away from temple, elbow raised; small upward bounce."),
    (-4, -9, .97, 1, -.012, (.33,.42,-.08), (-.32,.4,.05), 5,
     "14: right wrist below left and beside knee; snout tipped down, head dips."),
    (-1, -2, .995, 1, 0, (.32,.4,.05), (-.32,.4,.05), -12,
     "15: almost rest; both forward fists slightly lower than the snout."),
    (0, 0, 1, 1, 0, (.32,.4,.05), (-.32,.4,.05), 0,
     "16: neutral identity driving pose; exact rig rest chosen over tiny generated proportion drift."),
]


def solve_arm(arm, side, target, stretch=1.0):
    upper = arm.pose.bones["upper_arm." + side]
    lower = arm.pose.bones["lower_arm." + side]
    hand = arm.pose.bones["hand." + side]
    if stretch != 1:
        upper.scale = (stretch, stretch, stretch)
        lower.scale = (1/stretch, 1/stretch, 1/stretch)
    bpy.context.view_layer.update()
    shoulder = upper.head.copy()
    target = Vector(target)
    a, b = (lower.head-shoulder).length, (hand.head-lower.head).length
    delta = target-shoulder
    distance = min(delta.length, (a+b)*.995)
    axis = delta.normalized()
    along = (a*a-b*b+distance*distance)/(2*distance)
    height = math.sqrt(max(0,a*a-along*along))
    s = 1 if side == "R" else -1
    pole = Vector((s*.9,.35,-.8))
    pole = (pole - axis*pole.dot(axis)).normalized()
    elbow = shoulder+axis*along+pole*height
    rig.point_segment(arm, upper.name, lower.name, elbow)
    rig.point_segment(arm, lower.name, hand.name, target)


def world_hand(arm, side, angles):
    hand = arm.pose.bones["hand." + side]
    matrix = Euler(tuple(math.radians(v) for v in angles), "XYZ").to_matrix().to_4x4()
    matrix.translation = hand.head
    hand.matrix = matrix
    bpy.context.view_layer.update()


def author_table(arm):
    rows = []
    for index, obs in enumerate(OBSERVATIONS):
        torso, head, body_z, head_z, neck_z, right, left, curl, note = obs
        key = index + 1
        rig.clear_pose(arm)
        for name, pitch in (("spine_01", torso*.55), ("spine_02", torso*.45), ("head", head)):
            arm.pose.bones[name].rotation_euler.x = math.radians(pitch)
        arm.pose.bones["spine_01"].scale = (1+(1-body_z)*.12, 1, body_z)
        arm.pose.bones["spine_02"].scale.z = body_z
        arm.pose.bones["neck"].location.z = neck_z
        arm.pose.bones["head"].scale = ((1+(1-head_z)*.45)/(1+(1-body_z)*.12), 1, head_z/(body_z*body_z))
        if key == 3:
            arm.pose.bones["head"].scale.x = 1.065
            arm.pose.bones["snout"].scale = (1.12,1,1.05)
        for side, s in (("R",1),("L",-1)):
            arm.pose.bones["ear."+side].rotation_euler.z = math.radians(s * (25 if key <= 5 else 0))
            if key in (2,3,4):
                arm.pose.bones["shoulder."+side].location.z = .035
            if key in (7,8,9):
                arm.pose.bones["shoulder."+side].location.z = .06 if key in (8,9) else .045
        if key in (8,9,10):
            arm.pose.bones["snout"].rotation_euler.x = math.radians(-8 if key!=9 else -14)
        if key == 12:
            arm.pose.bones["goggles"].rotation_euler.x = math.radians(3)
        bpy.context.view_layer.update()
        if key != 16:
            if key in (11,12):
                goggle = arm.pose.bones["goggles"]
                rim_rest = Vector((.197,.255,.278))
                contact = goggle.matrix @ goggle.bone.matrix_local.inverted() @ rim_rest
                hand_rotation = Euler((0,math.radians(-15),math.radians(65)),"XYZ").to_matrix()
                right = contact - hand_rotation @ Vector((0,.135,-.015))
                if key == 11:
                    right.x += .035
            solve_arm(arm,"R",right,1.40 if key in (8,9) else 1)
            solve_arm(arm,"L",left)
            world_hand(arm,"R",(0,0,0))
            world_hand(arm,"L",(0,0,0))
            if key in (5,6,13):
                world_hand(arm,"R",(65,0,-15))
                if key in (5,6):
                    world_hand(arm,"L",(65,0,15))
            if key in (11,12):
                world_hand(arm,"R",(0,-15,65))
            for side in ("R","L"):
                arm.pose.bones["curl."+side].rotation_euler.x = math.radians(curl if side=="R" or key<=6 else -35)
        bpy.context.view_layer.update()
        row = {"key": key, "frame": FRAMES[index], "image": f"keys/key-{key:02}.png",
               "image_sha256": hashlib.sha256((OUT / f"keys/key-{key:02}.png").read_bytes()).hexdigest(),
               "observation": note, "bones": {}}
        for bone in arm.pose.bones:
            row["bones"][bone.name] = {
                "rotation_degrees_xyz": [round(math.degrees(v),6) for v in bone.rotation_euler],
                "location": [round(v,6) for v in bone.location],
                "scale": [round(v,6) for v in bone.scale]}
        rows.append(row)
    TABLE.write_text(json.dumps({"action":"drop_land","fps":30,"space":"bone local XYZ; +Y forward, +Z up, +X anatomical right",
                                 "rows":rows},indent=2)+"\n")
    return rows


def apply_row(arm,row):
    for name, pose in row["bones"].items():
        b=arm.pose.bones[name]
        b.rotation_euler=tuple(math.radians(v) for v in pose["rotation_degrees_xyz"])
        b.location=pose["location"]
        b.scale=pose["scale"]


def action(arm,rows):
    scene=bpy.context.scene
    scene.render.fps=30
    scene.frame_start,scene.frame_end=1,34
    for row in rows:
        assert hashlib.sha256((OUT/row["image"]).read_bytes()).hexdigest()==row["image_sha256"], "Reference changed; reauthor explicitly"
        apply_row(arm,row)
        for b in arm.pose.bones:
            for path in ("rotation_euler","location","scale"):
                b.keyframe_insert(data_path=path,frame=row["frame"],group=b.name)
    act=arm.animation_data.action
    act.name="drop_land"
    for layer in act.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation="LINEAR"
    return act


def checks(arm,meshes,rows):
    scene=bpy.context.scene
    anchor=Vector((0,0,-.3))
    max_drift=0
    max_radius=0
    grip_errors=[]
    for frame in range(1,35):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        max_drift=max(max_drift,(arm.pose.bones["pelvis"].head-anchor).length)
        dg=bpy.context.evaluated_depsgraph_get()
        for obj in meshes:
            evaluated=obj.evaluated_get(dg)
            mesh=evaluated.to_mesh()
            max_radius=max(max_radius,max(v.co.length for v in mesh.vertices))
            evaluated.to_mesh_clear()
        if frame in (29,34):
            grip_errors.append({"frame":frame,"right":(arm.pose.bones["hand.R"].head-Vector((.32,.4,.05))).length,
                                "left":(arm.pose.bones["hand.L"].head-Vector((-.32,.4,.05))).length})
    assert max_drift<1e-6
    assert all(v["right"]<.001 and v["left"]<.001 for v in grip_errors)
    assert max_radius<.98, ("pilot intersects sphere envelope",max_radius)
    for obj in meshes:
        assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6 for v in obj.data.vertices)
    receipt={"action":"drop_land","fps":30,"duration_seconds":1.1,"key_frames":FRAMES,
             "impact_frame_gap":FRAMES[5]-FRAMES[4],"pelvis_max_drift":max_drift,
             "max_vertex_radius_over_34_frames":max_radius,"hull_radius":.98,
             "settle_grip_errors":grip_errors,"bones":len(arm.data.bones),
             "triangles":sum(common.tris(o) for o in meshes),"all_vertices_rigid_weighted":True}
    (OUT/"animation-checks.json").write_text(json.dumps(receipt,indent=2)+"\n")


def export(arm,meshes):
    bpy.context.scene.frame_set(1)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [arm,*meshes]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=arm
    dest=HERE.parents[1]/"assets/models/pilot_rivet_anim.glb"
    bpy.ops.export_scene.gltf(filepath=str(dest),export_format="GLB",use_selection=True,
                              export_animations=True,export_animation_mode="ACTIONS",
                              export_anim_slide_to_zero=True,
                              export_frame_range=True,export_force_sampling=True,
                              export_def_bones=False,export_skins=True,export_yup=True,
                              export_materials="EXPORT",export_cameras=False,export_lights=False)
    return dest


def main():
    arm,meshes,root=rig.build()
    cam=rig.studio()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"rivet-rig.blend"))
    rows=author_table(arm) if "--author" in sys.argv else json.loads(TABLE.read_text())["rows"]
    action(arm,rows)
    checks(arm,meshes,rows)
    export(arm,meshes)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"rivet-drop.blend"))
    if "--no-render" in sys.argv:
        return
    draft="--draft" in sys.argv
    target=OUT/("draft-v4" if draft else "results-v4")
    target.mkdir(exist_ok=True)
    scene=bpy.context.scene
    scene.render.resolution_x=scene.render.resolution_y=360 if draft else 400
    for row in rows:
        if draft and row["key"] not in (3,5,9,12):
            continue
        scene.frame_set(row["frame"])
        for view in ("front","back","side"):
            rig.render_view(cam,target/f'key-{row["key"]:02}-{view}.png',view,1.8)
    if draft:
        return
    subprocess.run(["python",str(HERE/"compose_rivet_evidence.py")],check=True)
    movie=OUT/"movie-frames-v4"
    movie.mkdir(exist_ok=True)
    for obj in common.tree(root):
        obj.hide_render=False
    root.hide_render=False
    scene.render.resolution_x=720
    scene.render.resolution_y=540
    scene.cycles.samples=8
    for frame in range(1,35):
        scene.frame_set(frame)
        rig.render_view(cam,movie/f'{frame:04}.png',"chase",2.5)
    subprocess.run(["ffmpeg","-hide_banner","-loglevel","error","-y","-framerate","30",
                    "-start_number","1","-i",str(movie/"%04d.png"),"-frames:v","34",
                    "-c:v","libx264","-crf","18","-pix_fmt","yuv420p","-movflags","+faststart",
                    str(OUT/"drop_land.mp4")],check=True)


if __name__=="__main__":
    main()
