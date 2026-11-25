"""Tally's seated pack rat, pilot-v1 rig and seven reactions.

blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/pilot_tally.py -- --model-only --preview
blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/pilot_tally.py -- --preview

Organic forms are connected ring surfaces, not a reskin of another pilot. Colours
and rigid part weights are authored on that topology before adding the shared rig.
The closed, perforated ledger belongs to spine_01 throughout every action.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import common
import cycles_device
import polish
import rig_pilot
import anim_rivet_drop as arm_solver

SKETCH = HERE.parents[1]
ROOT = HERE.parents[3]
PREVIEW = ROOT / "artifacts/local/dress-preview/PTL"
PILOT_OUT = SKETCH / "assets/models/pilot_tally_anim.glb"
REFERENCE_HASHES = {
    "pilot-tally.png": "5ec88f4f6ecd42917355f85d8a23e09f369de57097a34f13702f6b22a72f61d7",
    "shell-tally.png": "209703bc741987b1b9cd7039cbc2b556a7a05a24c1d58f90ee390ddd181d2838",
    "motion-tally.png": "ac8b215dd791fbe4e60ae0ec480a5f42108b6ebf911589fcc0315d1b8a6c1978",
    "pilots-lineup.png": "ba8c5d3fe7601adfc29741f58422359dc49b1085cf3439d164ed59f7c6de8b87",
    "BUILD-SPEC.md": "7edf693cf21da1e497a6a4e492b9b03763037496950ad41987c773486a6f4beb",
    "SHEET.md": "bd58aa656e2644d51b585527c71a0a479256804b11fc806fea554d5682c6ebcf"
}
CLIPS = {"drop_land": 66, "big_cheer": 85, "wince": 16, "slump": 46,
         "phew": 25, "brace": 19, "heave": 25}
KEYS = {"drop_land": [1, 7, 13, 17, 21, 29, 39, 49, 58, 66],
        "big_cheer": [1, 7, 16, 25, 46, 58, 73, 85],
        "wince": [1, 3, 5, 8, 12, 16], "slump": [1, 7, 15, 23, 31, 39, 46],
        "phew": [1, 5, 10, 14, 19, 25], "brace": [1, 3, 6, 10, 14, 19],
        "heave": [1, 3, 7, 10, 15, 25]}
KEY_POSES = {"drop_land": 17, "big_cheer": 25, "wince": 3,
             "slump": 23, "phew": 10, "brace": 6, "heave": 7}
POLISH = {"detail": 1, "bevel": 0}
SOFT_BONES = ("head", "ear.R", "ear.L", "snout", "jaw", "hand.R", "hand.L", "curl.R", "curl.L")
COLOURS = {"fur": "706a5d", "ear": "906681", "cream": "f7f1e3",
           "mulberry": "906681", "cloth_shadow": "694b5d"}


def bone_schema():
    spec = rig_pilot.bone_spec("rivet", [])
    anchors = {"head": (0, .015, .20), "snout": (0, .24, .12),
               "jaw": (0, .19, .09), "ear.R": (.17, 0, .335),
               "ear.L": (-.17, 0, .335), "tail.02": (0, -.36, -.22)}
    return [(n, anchors.get(n, p), parent) for n, p, parent in spec]


class AnimalSurface:
    def __init__(self):
        self.part = common.Part("Pilot")
        self.bones = [n for n, _, _ in bone_schema()]
        self.weights = self.part.bm.verts.layers.int.new("tally_bone")
        self.ledger = self.part.bm.verts.layers.int.new("tally_ledger")
        self.parts = []

    def colour(self, name):
        return COLOURS.get(name, name)

    def surface(self, name, points, faces, bone, colour, slot="pilot", smooth=True):
        vs = [self.part.bm.verts.new(Vector(p)) for p in points]
        for i, v in enumerate(vs):
            tag = bone(points[i]) if callable(bone) else bone
            v[self.weights] = self.bones.index(tag) + 1
        fs = []
        for ids in faces:
            f = self.part.bm.faces.new([vs[i] for i in ids])
            f.smooth = smooth
            c = colour([points[i] for i in ids]) if callable(colour) else colour
            self.part.paint([f], slot, self.colour(c))
            if callable(colour):
                for loop, index in zip(f.loops, ids):
                    loop[self.part.col] = common.rgba(self.colour(colour([points[index]])))
            fs.append(f)
        self.parts.append({"part": name, "vertices": len(vs), "bone": bone if isinstance(bone, str) else "body rings"})
        return fs

    def loft(self, name, rows, n, bone, colour, axis="Z", smooth=True):
        """Rows: centre, cross-section radii. End rings close with one pole each."""
        points = []
        for centre, rx, ry in rows:
            for j in range(n):
                a = math.tau * j / n
                offset = (rx * math.sin(a), ry * math.cos(a), 0)
                if axis == "Y":
                    offset = (offset[0], 0, offset[1])
                points.append(tuple(Vector(centre) + Vector(offset)))
        faces = []
        for i in range(len(rows) - 1):
            for j in range(n):
                faces.append((i*n+j, i*n+(j+1)%n, (i+1)*n+(j+1)%n, (i+1)*n+j))
        points += [rows[0][0], rows[-1][0]]
        for j in range(n):
            faces += [(len(points)-2, (j+1)%n, j),
                      (len(points)-1, (len(rows)-1)*n+j, (len(rows)-1)*n+(j+1)%n)]
        return self.surface(name, points, faces, bone, colour, smooth=smooth)

    def oval(self, name, centre, scale, bone, colour, n=12, rings=7, slot="pilot"):
        rows = []
        c = Vector(centre)
        for i in range(1, rings):
            a = -math.pi/2 + math.pi*i/rings
            rows.append((tuple(c+Vector((0, 0, scale[2]*math.sin(a)))),
                         scale[0]*math.cos(a), scale[1]*math.cos(a)))
        points = []
        for p, rx, ry in rows:
            for j in range(n):
                a = math.tau*j/n
                points.append(tuple(Vector(p)+Vector((rx*math.sin(a), ry*math.cos(a), 0))))
        points += [tuple(c-Vector((0,0,scale[2]))), tuple(c+Vector((0,0,scale[2])))]
        faces = []
        for i in range(len(rows)-1):
            for j in range(n):
                faces.append((i*n+j, i*n+(j+1)%n, (i+1)*n+(j+1)%n, (i+1)*n+j))
        for j in range(n):
            faces += [(len(points)-2, (j+1)%n, j),
                      (len(points)-1, (len(rows)-1)*n+j, (len(rows)-1)*n+(j+1)%n)]
        return self.surface(name, points, faces, bone, colour, slot)

    def tube(self, name, path, radii, bone, colour, n=10):
        points = []
        for i, (p, r) in enumerate(zip(path, radii)):
            prev, following = Vector(path[max(0,i-1)]), Vector(path[min(len(path)-1,i+1)])
            axis = (following-prev).normalized()
            tangent = axis.cross(Vector((1,0,0))).normalized()
            bitangent = axis.cross(tangent).normalized()
            for j in range(n):
                a = math.tau*j/n
                points.append(tuple(Vector(p)+r*(math.cos(a)*tangent+math.sin(a)*bitangent)))
        faces = []
        for i in range(len(path)-1):
            for j in range(n):
                faces.append((i*n+j, i*n+(j+1)%n, (i+1)*n+(j+1)%n, (i+1)*n+j))
        points += [path[0], path[-1]]
        for j in range(n):
            faces += [(len(points)-2, (j+1)%n, j),
                      (len(points)-1, (len(path)-1)*n+j, (len(path)-1)*n+(j+1)%n)]
        return self.surface(name, points, faces, bone, colour)

    def mechanical(self, name, bone, fn):
        before = set(self.part.bm.verts)
        fn(self.part)
        for v in self.part.bm.verts:
            if v not in before:
                v[self.weights] = self.bones.index(bone) + 1
                if name=="ClosedLedger":
                    v[self.ledger]=1
        self.parts.append({"part": name, "bone": bone})

    def finish(self):
        bmesh.ops.recalc_face_normals(self.part.bm, faces=list(self.part.bm.faces))
        soft = {self.bones.index(name) + 1 for name in SOFT_BONES}
        polish.subdivide_where(self.part.bm, 1, lambda island: all(
            v[self.weights] in soft for f in island for v in f.verts))
        obj = self.part.to_object()
        tags = obj.data.attributes["tally_bone"]
        for i, name in enumerate(self.bones):
            ids = [v.index for v in obj.data.vertices if tags.data[v.index].value == i+1]
            if ids:
                obj.vertex_groups.new(name=name).add(ids, 1, "REPLACE")
        assert all(tags.data[v.index].value > 0 for v in obj.data.vertices)
        return obj


def punched_panel(part, centre, width, height, depth, holes=3, strip=None, colour="bone"):
    """A closed blank cover with actual through-holes, front normal +Y.

    Three rectangular annuli share a straight spine. The rest is a blank face.
    This avoids booleans and keeps export topology and triangle order stable.
    """
    cx, cy, cz = centre
    spine = strip or width
    sx = cx - width/2 + spine/2
    if spine < width:
        part.box("paint" if part.name != "Pilot" else "pilot", (width-spine, depth, height),
                 loc=(cx+spine/2, cy, cz), color=colour)
    slot = "pilot" if part.name == "Pilot" else "paint"
    for row in range(holes):
        z = cz-height/2 + height*(row+.5)/holes
        w, h, radius = spine/2, height/(2*holes), min(spine*.24, height*.065)
        corner = math.atan2(h, w)
        angles = sorted([math.tau*j/12 for j in range(12)]+[
            corner,math.pi-corner,math.pi+corner,math.tau-corner])
        rings = []
        for y in (cy-depth/2, cy+depth/2):
            inner, outer = [], []
            for a in angles:
                dx, dz = math.cos(a), math.sin(a)
                reach = min(w/max(abs(dx), 1e-9), h/max(abs(dz), 1e-9))
                inner.append(part.bm.verts.new((sx+radius*dx, y, z+radius*dz)))
                outer.append(part.bm.verts.new((sx+reach*dx, y, z+reach*dz)))
            rings.append((inner, outer))
        fs = []
        for j in range(len(angles)):
            k = (j+1)%len(angles)
            for inner, outer in rings:
                fs.append(part.bm.faces.new((inner[j],inner[k],outer[k],outer[j])))
            fs.append(part.bm.faces.new((rings[0][0][j],rings[1][0][j],rings[1][0][k],rings[0][0][k])))
            fs.append(part.bm.faces.new((rings[0][1][j],rings[0][1][k],rings[1][1][k],rings[1][1][j])))
        part.paint(fs, slot, colour)


def model():
    a = AnimalSurface()
    def head_colour(ps):
        c = sum((Vector(p) for p in ps), Vector())/len(ps)
        line = .18 - .045*(abs(c.x)/.222)**2
        mask = min(1,max(0,(line-c.z)/.035+.5))*min(1,max(0,(c.y-.055)/.065))
        fur,cream=common.srgb(COLOURS["fur"]),common.srgb(COLOURS["cream"])
        return tuple(fur[i]+mask*(cream[i]-fur[i]) for i in range(3))
    a.loft("HeadCheeks", [((0,.055,.032),.055,.05), ((0,.05,.055),.13,.10),
        ((0,.054,.10),.205,.151), ((0,.04,.145),.222,.17),
        ((0,.015,.20),.215,.17), ((0,0,.265),.178,.147),
        ((0,-.005,.32),.166,.112), ((0,-.005,.360),.099,.068),
        ((0,-.005,.377),.042,.028), ((0,-.005,.38),.005,.005)], 20, "head", head_colour)
    a.loft("Snout", [((0,.18,.12),.072,.042), ((0,.22,.12),.09,.05),
        ((0,.266,.125),.05,.031), ((0,.291,.134),.016,.014)], 12, "snout", "cream", axis="Y")
    a.oval("Nose", (0,.298,.142), (.025,.015,.017), "snout", "charcoal", 10, 5)
    a.oval("LowerLip", (0,.225,.078), (.068,.046,.018), "jaw", "cream", 12, 5)
    for side, s in (("R",1),("L",-1)):
        a.oval("Eye."+side, (s*.095,.162,.236), (.022,.017,.028), "head", "charcoal", 10, 6)
        a.oval("EyeGlint."+side, (s*.092,.178,.244), (.006,.003,.007), "head", "cream", 6, 4)
        centre = Vector((s*.255,0,.405))
        points, faces = [], []
        profiles = [(.012,.006),(.055,.011),(.099,.021),(.114,.025),(.12,.010),
                    (.116,-.014),(.086,-.025),(.025,-.026)]
        n = 16
        for r,y in profiles:
            for j in range(n):
                t = math.tau*j/n
                offset=Vector((r*math.sin(t),y,r*math.cos(t)))
                if s*offset.x < -.04 and offset.z < -.045:
                    offset += Vector((-s*.035,0,-.020))
                points.append(tuple(centre+offset))
        for i in range(len(profiles)-1):
            for j in range(n):
                faces.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
        points += [tuple(centre+Vector((0,.006,0))),tuple(centre+Vector((0,-.026,0)))]
        for j in range(n):
            faces += [(len(points)-2,(j+1)%n,j), (len(points)-1,(len(profiles)-1)*n+j,(len(profiles)-1)*n+(j+1)%n)]
        def ear_colour(ps):
            c = sum((Vector(p) for p in ps),Vector())/len(ps)-centre
            return "ear" if c.y > .006 and math.hypot(c.x,c.z)<.111 else "fur"
        a.surface("EarDisc."+side,points,faces,"ear."+side,ear_colour)

    def body_weight(p):
        return "pelvis" if p[2]<-.31 else "spine_01" if p[2]<-.1 else "spine_02"
    def body_colour(ps):
        c = sum((Vector(p) for p in ps),Vector())/len(ps)
        return "cream" if c.y > .095 and abs(c.x)<.165 else "petrol"
    a.loft("PouchBodyBib", [((0,-.015,-.42),.10,.07),((0,-.012,-.38),.205,.135),
        ((0,-.01,-.30),.262,.197),((0,-.007,-.20),.28,.21),
        ((0,-.004,-.10),.254,.181),((0,.002,0),.19,.115),
        ((0,.008,.058),.105,.075),((0,.008,.074),.07,.053)],20,body_weight,body_colour)
    a.tube("TailBase",[(0,-.16,-.27),(0,-.22,-.29),(0,-.29,-.26),(0,-.36,-.22)],
           [.0175,.017,.015,.013],"tail.01","ear",8)
    a.tube("TailTip",[(0,-.36,-.22),(.03,-.405,-.18),(.06,-.44,-.15),(.08,-.48,-.19),(.085,-.51,-.23)],
           [.013,.011,.009,.007,.003],"tail.02","ear",8)
    for side,s in (("R",1),("L",-1)):
        a.tube("Thigh."+side,[(s*.16,.10,-.32),(s*.18,.17,-.30),(s*.20,.23,-.34)],
               [.079,.106,.082],"pelvis","fur",10)
        a.tube("Boot."+side,[(s*.20,.26,-.36),(s*.20,.34,-.43),(s*.20,.45,-.48),(s*.20,.52,-.48)],
               [.085,.088,.09,.05],"pelvis","petrol",10)
        a.oval("BootToe."+side,(s*.20,.47,-.486),(.098,.124,.054),"pelvis","charcoal",10,5)
        a.oval("Shoulder."+side,(s*.22,.005,-.09) if side=="R" else (s*.22,.005,.005),
               (.106,.09,.10) if side=="R" else (.090,.075,.052),"shoulder."+side,"fur",10,5)
        upper_path=[(s*.24,.015,-.09),(s*.285,.075,-.10),(s*.34,.18,-.115),(s*.36,.24,-.12)]
        if side=="L":
            upper_path=[(s*.24,.145,-.09),(s*.285,.175,-.10),(s*.34,.22,-.115),(s*.36,.24,-.12)]
        a.tube("UpperArm."+side,upper_path,
               [.073,.085,.078,.070] if side=="R" else [.050,.065,.065,.070],"upper_arm."+side,"fur",10)
        a.tube("Forearm."+side,[(s*.36,.24,-.12),(s*.345,.29,-.072),(s*.32,.35,.005),(s*.32,.395,.045)],
               [.069,.073,.070,.056],"lower_arm."+side,"fur",10)
        a.tube("Cuff."+side,[(s*.327,.326,-.021),(s*.325,.337,-.005),(s*.32,.35,.010)],
               [.077,.079,.074],"lower_arm."+side,"mulberry",10)
        a.oval("Paw."+side,(s*.32,.40,.05),(.065,.052,.055),"hand."+side,"cream",10,5)
        points, faces = [], []
        n=18
        for y,r in ((.421,.050),(.454,.047),(.469,.036)):
            for j in range(n):
                t=math.tau*j/n
                lobe=1+.16*math.cos(3*t)
                points.append((s*.32+r*math.sin(t)*lobe,y,.052+r*.8*math.cos(t)*lobe))
        for i in range(2):
            for j in range(n):
                faces.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
        points += [(s*.32,.421,.052),(s*.32,.480,.052)]
        for j in range(n):
            faces += [(54,(j+1)%n,j),(55,2*n+j,2*n+(j+1)%n)]
        a.surface("FusedGrip."+side,points,faces,"curl."+side,"cream")
        a.mechanical("BibStrap."+side,"spine_02",lambda p,s=s:
            p.beam("pilot",(s*.175,.129,-.14),(s*.12,.105,.048),.027,.012,color="sandstone"))

    a.loft("ScarfCollar", [((0,0,.012),.137,.091),((0,0,.047),.145,.096),
                           ((0,0,.068),.128,.083)],16,"spine_02","mulberry")
    a.surface("ScarfBib",[(-.126,.115,.043),(.126,.115,.043),(.086,.171,-.064),
        (0,.197,-.146),(-.086,.171,-.064),(0,.143,-.022)],
        [(0,1,5),(1,2,5),(2,3,5),(3,4,5),(4,0,5)],"spine_02",
        lambda ps:"cloth_shadow" if sum(p[2] for p in ps)/len(ps)<-.065 else "mulberry",smooth=False)
    def ledger(p):
        punched_panel(p,(-.255,.045,-.20),.17,.23,.045,strip=.034,colour=COLOURS["cream"])
        for x in (-.335,-.178):
            p.box("pilot",(.012,.049,.23),loc=(x,.045,-.20),color=COLOURS["mulberry"])
        p.box("pilot",(.17,.049,.012),loc=(-.255,.045,-.309),color=COLOURS["mulberry"])
        p.box("pilot",(.17,.049,.012),loc=(-.255,.045,-.091),color=COLOURS["mulberry"])
        p.beam("pilot",(-.286,.014,-.19),(-.201,.014,-.19),.025,.012,color="sandstone")
        p.box("bare_metal",(.026,.008,.028),loc=(-.215,.073,-.18))
    a.mechanical("ClosedLedger","spine_01",ledger)
    obj=a.finish()
    obj["ledger_bone"]="spine_01"
    return obj,a.parts


def rig_model(obj):
    arm=bpy.data.objects.new("TallyRig",bpy.data.armatures.new("TallySkeleton"))
    bpy.context.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active=arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name,pos,parent in bone_schema():
        b=arm.data.edit_bones.new(name)
        b.head=pos
        b.tail=Vector(pos)+Vector((0,.08,0))
        if parent:
            b.parent=arm.data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for b in arm.data.bones:
        b.inherit_scale="FULL"
    for b in arm.pose.bones:
        b.rotation_mode="XYZ"
    obj.parent=arm
    obj.modifiers.new("Pilot-v1 rigid weights","ARMATURE").object=arm
    return arm


def rotate(arm,name,xyz):
    arm.pose.bones[name].rotation_euler=tuple(math.radians(v) for v in xyz)


def solve_tally_arm_once(arm,side,target,pole=None):
    """Copied solve_arm geometry with a forward elbow pole for ledger clearance."""
    upper=arm.pose.bones["upper_arm."+side]
    lower=arm.pose.bones["lower_arm."+side]
    hand=arm.pose.bones["hand."+side]
    bpy.context.view_layer.update()
    shoulder=upper.head.copy()
    delta=Vector(target)-shoulder
    a,b=(lower.head-shoulder).length,(hand.head-lower.head).length
    distance=min(delta.length,(a+b)*.995)
    axis=delta.normalized()
    along=(a*a-b*b+distance*distance)/(2*distance)
    height=math.sqrt(max(0,a*a-along*along))
    s=1 if side=="R" else -1
    pole=Vector((s*.9,1.35,-.25)) if pole is None else Vector(pole)
    pole=(pole-axis*pole.dot(axis)).normalized()
    elbow=shoulder+axis*along+pole*height
    rig_pilot.point_segment(arm,upper.name,lower.name,elbow)
    rig_pilot.point_segment(arm,lower.name,hand.name,target)


def solve_tally_arm(arm,side,target,pole=None):
    for _ in range(8):
        solve_tally_arm_once(arm,side,target,pole)
        if (arm.pose.bones["hand."+side].head-Vector(target)).length<.00001:
            break


def pose(arm,clip,k):
    rig_pilot.clear_pose(arm)
    if k in (0,len(KEYS[clip])-1):
        return
    right,left=(.32,.4,.05),(-.32,.4,.05)
    pitch=yaw=roll=ear=shoulder=tail=0
    height=1
    if clip=="drop_land":
        strength=[0,.2,.65,1,.85,.25,0,.06,.02,0][k]
        height=1-.08*strength
        pitch=-9*strength
        ear=28*strength
        if k in (5,6):
            height=1.025
            pitch=4
            ear=-7
    elif clip=="big_cheer":
        height=[1,.96,1.025,1.04,1.04,1.045,1.01,1][k]
        pitch=[0,-5,2,3,3,5,1,0][k]
        yaw=[0,0,5,8,12,-8,3,0][k]
        width=[.32,.37,.40,.41,.41,.43,.36,.32][k]
        lift=[.05,.09,.20,.34,.34,.32,.13,.05][k]
        right,left=(width,.16,lift),(-width,.16,lift)
        shoulder=.035
        ear=-12
    elif clip=="wince":
        strength=[0,1,.9,.5,.15,0][k]
        height=1-.065*strength
        pitch,yaw,roll=-9*strength,24*strength,7*strength
        shoulder=.032*strength
        ear=20*strength
        right,left=(.32+.055*strength,.34,.05+.07*strength),(-.32-.055*strength,.34,.05+.07*strength)
    elif clip=="slump":
        strength=[0,.3,.8,1,1,.4,0][k]
        height=1-.075*strength
        pitch,yaw,roll=-16*strength,8*strength,-5*strength
        shoulder=-.025*strength
        ear=36*strength
        right,left=(.32+.10*strength,.40-.02*strength,.05-.28*strength),(-.32-.10*strength,.40-.02*strength,.05-.28*strength)
        tail=-12*strength
    elif clip=="phew":
        strength=[0,.45,1,1,.35,0][k]
        height=[1,1.02,1.015,1.005,.97,1][k]
        yaw=-35*strength
        ear=9*strength
        left=(-.32-.08*strength,.30,.05+.21*strength)
    elif clip=="brace":
        strength=[0,1,1,.85,.35,0][k]
        height=1-.07*strength
        pitch=-17*strength
        ear=40*strength
    elif clip=="heave":
        strength=[0,.7,1,.85,.35,0][k]
        height=[1,1.025,.96,.975,.99,1][k]
        pitch=[0,12,-14,-10,-4,0][k]
        ear=18*strength
        if k==1:
            right=(.37,.28,.08)
        else:
            right=(.32+.05*strength,.40+.23*strength,.05+.08*strength)
        tail=20*strength
    rotate(arm,"spine_01",(pitch*.55,0,0))
    rotate(arm,"spine_02",(pitch*.45,0,0))
    arm.pose.bones["spine_01"].scale=(1+(1-height)*.15,1,height)
    arm.pose.bones["spine_02"].scale.z=height
    rotate(arm,"head",(pitch*.35,roll,yaw))
    for side,s in (("R",1),("L",-1)):
        rotate(arm,"ear."+side,(ear,s*ear*.28,0))
        arm.pose.bones["shoulder."+side].location.z=shoulder
    rotate(arm,"tail.01",(0,0,tail))
    rotate(arm,"tail.02",(0,0,-tail*.6))
    bpy.context.view_layer.update()
    for side,target in (("R",right),("L",left)):
        solve_tally_arm(arm,side,target)
        arm_solver.world_hand(arm,side,(0,0,0))
    if clip in ("big_cheer","phew","heave"):
        rotate(arm,"jaw",(-12 if clip=="big_cheer" else -6,0,0))


def animate(arm):
    arm.animation_data_create()
    actions=[]
    tables={}
    image_hash=REFERENCE_HASHES["motion-tally.png"]
    observations={
        "drop_land":"Neutral anatomy governs; gently compress belly, hinge whole ear discs, rebound to both grips.",
        "big_cheer":"Both paws rise outside the ear silhouette; reject enlarged torso and generated finger changes.",
        "wince":"Head twists and shoulders lift; discs tilt outward without changing cheek or pupil geometry.",
        "slump":"Shoulders and ears droop; paws hang beside knees while closed ledger remains on the torso.",
        "phew":"Anatomical LEFT paw releases, head turns to profile, RIGHT grip stays planted; reject four tips.",
        "brace":"Forward torso bite, both grips planted, whole discs rake backward; fixed seated legs.",
        "heave":"Seat recoil followed by one anatomical RIGHT punch and LEFT counterbrace; small bare-tail curl.",
    }
    for clip,frames in KEYS.items():
        arm.animation_data.action=None
        rows=[]
        for k,frame in enumerate(frames):
            pose(arm,clip,k)
            rows.append({"frame":frame,"source_image_sha256":image_hash,
                "observation":"Exact driving rest." if k in (0,len(frames)-1) else observations[clip],
                "bones":{b.name:{"location":list(b.location),
                "rotation":list(b.rotation_euler),"scale":list(b.scale)} for b in arm.pose.bones}})
            for b in arm.pose.bones:
                for channel in ("location","rotation_euler","scale"):
                    b.keyframe_insert(data_path=channel,frame=frame,group=b.name)
        action=arm.animation_data.action
        action.name=clip
        action.use_fake_user=True
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for point in curve.keyframe_points:
                            point.interpolation="LINEAR"
        planted=["R","L"] if clip in ("brace","drop_land") else ["R"] if clip=="phew" else ["L"] if clip=="heave" else []
        if planted:
            baked=[]
            for frame in range(1,CLIPS[clip]+1):
                bpy.context.scene.frame_set(frame)
                bpy.context.view_layer.update()
                if frame not in (1,CLIPS[clip]):
                    for side in planted:
                        shoulder=arm.pose.bones["upper_arm."+side].head.copy()
                        pole=arm.pose.bones["lower_arm."+side].head-shoulder
                        solve_tally_arm(arm,side,(.32 if side=="R" else -.32,.4,.05),pole)
                        arm_solver.world_hand(arm,side,(0,0,0))
                baked.append({b.name:(b.location.copy(),b.rotation_euler.copy(),b.scale.copy()) for b in arm.pose.bones})
            for frame,values in enumerate(baked,1):
                for name,(location,rotation,scale) in values.items():
                    bone=arm.pose.bones[name]
                    bone.location,bone.rotation_euler,bone.scale=location,rotation,scale
                    for channel in ("location","rotation_euler","scale"):
                        bone.keyframe_insert(data_path=channel,frame=frame,group=name)
            for layer in action.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        for curve in bag.fcurves:
                            for point in curve.keyframe_points:
                                point.interpolation="LINEAR"
        actions.append(action)
        tables[clip]=rows
    bpy.context.scene.render.fps=30
    return actions,tables


def export_pilot(arm,obj,path):
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active=arm
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
        export_animations=True,export_animation_mode="ACTIONS",export_anim_slide_to_zero=True,
        export_frame_range=False,export_force_sampling=True,export_def_bones=False,
        export_skins=True,export_yup=True,export_materials="EXPORT",export_vertex_color="ACTIVE",
        export_extras=False,export_cameras=False,export_lights=False)
    common.canonical_indices(str(path),vertices=common.POLISH is not None)


def verify_motion(arm,obj,actions):
    checks=[]
    for action in actions:
        arm.animation_data.action=action
        radius=0
        root_error=0
        grip_error=0
        ledger_clearance=float("inf")
        overlap_count=0
        arm_tags={i+1 for i,b in enumerate([n for n,_,_ in bone_schema()])
                  if b.startswith(("shoulder.","upper_arm.","lower_arm.","hand.","curl."))}
        for half in range(2,CLIPS[action.name]*2+1):
            frame=half/2
            bpy.context.scene.frame_set(int(frame),subframe=frame%1)
            bpy.context.view_layer.update()
            evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh=evaluated.to_mesh()
            radius=max(radius,max(v.co.length for v in mesh.vertices))
            tags=mesh.attributes["tally_bone"].data
            ledger_tags=mesh.attributes["tally_ledger"].data
            positions=[v.co.copy() for v in mesh.vertices]
            arm_faces=[list(p.vertices) for p in mesh.polygons
                       if all(tags[i].value in arm_tags for i in p.vertices)]
            ledger_faces=[list(p.vertices) for p in mesh.polygons
                          if all(ledger_tags[i].value==1 for i in p.vertices)]
            arm_bvh=BVHTree.FromPolygons(positions,arm_faces,all_triangles=True)
            ledger_bvh=BVHTree.FromPolygons(positions,ledger_faces,all_triangles=True)
            overlap_count+=len(arm_bvh.overlap(ledger_bvh))
            for i,p in enumerate(positions):
                if ledger_tags[i].value==1:
                    nearest=arm_bvh.find_nearest(p)
                    if nearest[0] is not None:
                        ledger_clearance=min(ledger_clearance,nearest[3])
            evaluated.to_mesh_clear()
            root_error=max(root_error,(arm.pose.bones["pelvis"].head-Vector((0,0,-.3))).length)
            planted=["R","L"] if action.name in ("brace","drop_land") else ["R"] if action.name=="phew" else ["L"] if action.name=="heave" else []
            for side in planted:
                target=Vector((.32 if side=="R" else -.32,.4,.05))
                grip_error=max(grip_error,(arm.pose.bones["hand."+side].head-target).length)
        assert radius < .98,(action.name,"glass clearance",radius)
        assert root_error < 1e-6,(action.name,"pelvis drift",root_error)
        assert grip_error < .003,(action.name,"planted grip",grip_error)
        assert overlap_count==0,(action.name,"ledger/arm intersection",overlap_count,ledger_clearance)
        checks.append({"clip":action.name,"seconds":(CLIPS[action.name]-1)/30,
                       "maximum_pilot_radius":radius,"pelvis_drift":root_error,
                       "maximum_planted_hand_error":grip_error,"half_frame_samples":CLIPS[action.name]*2-1})
        checks[-1]["minimum_ledger_vertex_to_arm_distance"]=ledger_clearance
        checks[-1]["ledger_arm_triangle_overlaps"]=overlap_count
    return checks


def studio():
    cam=rig_pilot.studio()
    scene=bpy.context.scene
    cycles_device.use(scene)
    scene.cycles.samples=8
    scene.render.resolution_x=720
    scene.render.resolution_y=720
    scene.world.node_tree.nodes["Background"].inputs[0].default_value=common.rgba("c6baaa")
    scene.world.node_tree.nodes["Background"].inputs[1].default_value=.6
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.99))
    floor=bpy.context.object
    floor.name="PreviewFloor"
    floor.data.materials.append(common._flat("preview_ground","b6ab9a"))
    return cam


def previews(arm,obj,actions,tag):
    import shell_tally
    shell_tally.build()
    cam=studio()
    scene=bpy.context.scene
    paths=[]
    neutral=actions[0] if actions else None
    if arm:
        arm.animation_data.action=neutral
        scene.frame_set(1)
    positions={"front":(0,5,.85),"side":(-5,0,.65),"back":(0,-5,.85),"three-quarter":(-3,4,1.6)}
    for view,position in positions.items():
        cam.location=position
        common._look(cam,(0,0,-.03))
        cam.data.ortho_scale=2.32
        scene.render.filepath=str(PREVIEW/(tag+"turnaround-"+view+".png"))
        bpy.ops.render.render(write_still=True)
        paths.append(Path(scene.render.filepath))
    if arm:
        for action in actions:
            arm.animation_data.action=action
            scene.frame_set(KEY_POSES[action.name])
            cam.location=(-2.7,4,1.25)
            common._look(cam,(0,.05,-.015))
            cam.data.ortho_scale=2.32
            scene.render.filepath=str(PREVIEW/(tag+"clip-"+action.name+".png"))
            bpy.ops.render.render(write_still=True)
            paths.append(Path(scene.render.filepath))
    for o in common.tree(bpy.data.objects["ShellTally"]):
        o.hide_render=True
    if arm:
        arm.animation_data.action=neutral
        scene.frame_set(1)
    for view in ("front","side","back","three-quarter"):
        cam.location=positions[view]
        common._look(cam,(0,.03,-.015))
        cam.data.ortho_scale=1.25
        scene.render.filepath=str(PREVIEW/(tag+"pilot-"+view+".png"))
        bpy.ops.render.render(write_still=True)
        paths.append(Path(scene.render.filepath))
    if arm:
        arm.animation_data.action=next(a for a in actions if a.name=="big_cheer")
        scene.frame_set(KEY_POSES["big_cheer"])
    cam.location=(-3,4,.6)
    common._look(cam,(-.255,.045,-.20))
    cam.data.ortho_scale=.65
    scene.render.filepath=str(PREVIEW/(tag+"ledger-detail.png"))
    bpy.ops.render.render(write_still=True)
    paths.append(Path(scene.render.filepath))
    manifest={"engine":"Cycles","device":bpy.context.scene.cycles.device,"samples":scene.cycles.samples,
        "threads":scene.render.threads,"size":[scene.render.resolution_x,scene.render.resolution_y],
        "pilot_glb":glb_counts(PILOT_OUT),"shell_glb":glb_counts(shell_tally.OUT),
        "clip_key_frames":KEY_POSES,"ledger_detail_pose":"big_cheer" if arm else "neutral",
        "images":{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}}
    (PREVIEW/("preview-manifest-"+tag.rstrip("-")+".json")).write_text(json.dumps(manifest,indent=2)+"\n")
    print("PTL_PREVIEW: PASS",len(paths),"PNGs; Cycles",bpy.context.scene.cycles.device+"; 8 samples; 2 threads")


def glb_counts(path):
    raw=Path(path).read_bytes()
    size=struct.unpack_from("<I",raw,12)[0]
    doc=json.loads(raw[20:20+size])
    counts={"triangles":0,"vertices":0,"draws":0,"materials":len(doc.get("materials",[]))}
    for mesh in doc["meshes"]:
        for p in mesh["primitives"]:
            counts["triangles"]+=doc["accessors"][p["indices"]]["count"]//3
            counts["vertices"]+=doc["accessors"][p["attributes"]["POSITION"]]["count"]
            counts["draws"]+=1
    counts["sha256"]=hashlib.sha256(raw).hexdigest()
    return counts


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--model-only",action="store_true")
    parser.add_argument("--preview",action="store_true")
    parser.add_argument("--out",type=Path,default=PILOT_OUT)
    parser.add_argument("--preview-tag",default="final-")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    common.reset()
    polish.enable(**POLISH)
    PREVIEW.mkdir(parents=True,exist_ok=True)
    obj,parts=model()
    arm=None
    actions=[]
    report={"parts":parts,"bone_hierarchy":{n:parent for n,_,parent in bone_schema()},
            "rest_anchors":{n:list(p) for n,p,_ in bone_schema()},
            "design":"Pack rat B; blank closed ledger; three fused grip lobes; nonemissive mulberry cloth",
            "references":REFERENCE_HASHES}
    if not args.model_only:
        arm=rig_model(obj)
        actions,tables=animate(arm)
        report["motion"]=verify_motion(arm,obj,actions)
        (PREVIEW/"poses.json").write_text(json.dumps(tables,indent=2)+"\n")
        arm.animation_data.action=actions[0]
        bpy.context.scene.frame_set(1)
        polish.bake(arm)
        export_pilot(arm,obj,args.out)
        report["export"]=glb_counts(args.out)
        counts=report["export"]
        assert counts["triangles"]<=10600 and counts["vertices"]<=8100 and counts["draws"]<=5,counts
        print("TALLY_PILOT",json.dumps(counts,sort_keys=True))
    bpy.ops.wm.save_as_mainfile(filepath=str(PREVIEW/("tally-model.blend" if args.model_only else "tally-rig.blend")))
    (PREVIEW/"model-receipt.json").write_text(json.dumps(report,indent=2)+"\n")
    if args.preview:
        previews(arm,obj,actions,args.preview_tag)


if __name__=="__main__":
    main()
