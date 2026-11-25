"""SPIL-9 rigid machinery, metre scale, Blender +Y forward / +Z up.

blender -b --threads 2 --python-exit-code 1 -P <this file> -- --all
--asset NAME rebuilds one source. --pair LEFT RIGHT builds a fitted, three-surface
assembly; RAM geometry is reflected at the left socket, never its combat effect.
P-R7 removes escape_release. Spent/rearm move only the charge witness.
No external geometry, textures, randomness, collision, or gameplay code.
"""
import argparse
import itertools
import json
import math
from pathlib import Path
import struct
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
SKETCH = HERE.parents[2]
sys.path.insert(0, str(HERE.parent))
import common
import polish

POLISH = dict(detail=1, bevel=0)
OUT = SKETCH / "assets/models/companion"
NAMES = ("primer_coil", "primer_mesh", "ram_prow", "ram_spring", "escape_vent", "escape_rail")
FAMILY = {n: i // 2 for i, n in enumerate(NAMES)}
HULL_CLIPS = {"idle": 1.6, "follow": .18, "dock": .25, "empty": .25,
              "escape_spent": .14, "escape_rearm": .20,
              "assist_rise": .15, "assist_drop": .15, "assist_return": .45}
ASSIST_CLIPS = ("assist_rise", "assist_drop", "assist_return")
MARKS = ("Mk1Halo", "Mk2Fins", "Mk3Halo", "Mk4Exhaust", "Mk5CoreCrest")
MODULE_CLIPS = {
    "primer_coil": {"primer_set": .12, "primer_consume": .16, "primer_expire": .12},
    "primer_mesh": {"primer_set": .12, "primer_consume": .16, "primer_expire": .12},
    "ram_prow": {"prow_response": .20},
    "ram_spring": {"spring_arm": .10, "spring_spend": .18},
    "escape_vent": {}, "escape_rail": {},
}


def owns_channel(clip, node, path):
    if clip in ASSIST_CLIPS:
        return node == "BodyPose" and path in ("translation", "rotation", "scale")
    if clip in ("idle", "dock", "empty"):
        return node == "BodyPose" and path == "translation"
    if clip == "follow":
        return node == "BodyPose" and path == "rotation"
    if clip.startswith("primer_"):
        return node.endswith(("CoilPivot", "MeshPivot")) and path == "rotation"
    if clip == "prow_response":
        return node.endswith("ProwSlide") and path == "translation"
    if clip in ("spring_arm", "spring_spend"):
        return node.endswith("SpringSlide") and path == "scale"
    if clip in ("escape_spent", "escape_rearm"):
        return node == "EscapeWitness" and path == "rotation"
    return False


def isolate_channels(path):
    data=path.read_bytes()
    size=struct.unpack_from("<I",data,12)[0]
    gltf=json.loads(data[20:20+size])
    for animation in gltf.get("animations",[]):
        channels=[c for c in animation["channels"] if owns_channel(animation["name"],
            gltf["nodes"][c["target"]["node"]]["name"],c["target"]["path"])]
        assert len(channels)==(3 if animation["name"] in ASSIST_CLIPS else 1),(animation["name"],channels)
        samplers=[]
        for channel in channels:
            samplers.append(animation["samplers"][channel["sampler"]])
            channel["sampler"]=len(samplers)-1
        animation["channels"],animation["samplers"]=channels,samplers
    encoded=json.dumps(gltf,separators=(",",":"),ensure_ascii=False).encode("utf-8")
    encoded+=b" "*((-len(encoded))%4)
    binary=data[20+size:]
    path.write_bytes(struct.pack("<4sII",b"glTF",2,20+len(encoded)+len(binary))+
                     struct.pack("<I4s",len(encoded),b"JSON")+encoded+binary)


def g(p):
    return Vector((p[0], -p[2], p[1]))


class Model:
    def __init__(self, name):
        common.reset()
        polish.enable(**POLISH)
        common.SLOTS["bare_metal"] = {"color": "929995", "rough": .45, "metal": .6}
        self.name = name
        self.part = common.Part("CompanionMesh")
        self.tags = self.part.bm.verts.layers.int.new("rig_part")
        self.bones = []
        self.parts = {}
        self.offset = Vector((0, 0, 0))
        self.mirror = 1
        self.prefix = ""
        self.clips = {}
        self.bone("BodyPose", (0, 0, 0), None)

    def point(self, p):
        return g(self.offset + Vector((p[0] * self.mirror, p[1], p[2])))

    def bone(self, name, p, parent="BodyPose"):
        name = self.prefix + name
        parent = self.prefix + parent if parent != "BodyPose" and parent else parent
        self.bones.append((name, self.point(p), parent))
        self.parts[name] = []
        return name

    def shape(self, name, fn, *args, **kwargs):
        name = self.prefix + name
        before = set(self.part.bm.verts)
        faces = fn(*args, **kwargs)
        index = next(i for i, b in enumerate(self.bones) if b[0] == name) + 1
        for v in self.part.bm.verts:
            if v not in before:
                v[self.tags] = index
                self.parts[name].append(tuple(v.co))
        return faces

    def box(self, name, size, p, slot="paint", color="bone"):
        return self.shape(name, self.part.box, slot, (size[0], size[2], size[1]),
                          loc=self.point(p), color=color if slot == "paint" else None)

    def ring(self, name, inner, outer, depth, p, segs=6, slot="bare_metal", color=None, vertical=False):
        return self.shape(name, self.part.ring, slot, inner, outer, depth, segs,
                          loc=self.point(p), rot=(math.pi / 2, 0, 0) if vertical else (0, 0, 0), color=color)

    def cyl(self, name, radius, depth, p, segs=6, slot="bare_metal", axis="Y", caps=True):
        rot = {"Y": (0, 0, 0), "X": (0, math.pi / 2, 0), "Z": (math.pi / 2, 0, 0)}[axis]
        return self.shape(name, self.part.cyl, slot, radius, radius, depth, segs,
                          loc=self.point(p), rot=rot, caps=caps)

    def wedge(self, name, p, size, slot="bare_metal", color=None):
        x, y, z = size
        outline = [(-x/2, -z/2), (x/2, -z/2), (0, z/2)]
        matrix = Matrix.Translation(self.point(p))
        return self.shape(name, self.part.prism, slot, outline, y, matrix=matrix, color=color)

    def foot(self):
        mirror = self.mirror
        self.mirror = 1
        self.bone("Foot", (0, 0, 0))
        faces = self.cyl("Foot", .09, .055, (0, 0, 0), caps=False)
        verts = sorted({v for f in faces for v in f.verts if v.co.z > self.point((0, 0, 0)).z},
                       key=lambda v: math.atan2(v.co.y-self.point((0,0,0)).y, v.co.x-self.point((0,0,0)).x))
        self.part.paint([self.part.bm.faces.new(verts)], "bare_metal")
        for i in range(3):
            a = i * math.tau / 3
            self.wedge("Foot", (.085*math.cos(a), .015, .085*math.sin(a)), (.035, .025, .035))
        self.mirror = mirror

    def hull(self):
        self.clips.update(HULL_CLIPS)
        for name, p in [
            ("Hull", (0,0,0)), ("Deck", (0,.18,0)), ("LiftPlenum", (0,-.17,0)),
            ("Bumper", (0,-.07,0)), ("ServiceBrow", (0,.03,-.36)),
            ("EscapeWitness", (0,.03,-.385)), ("WitnessAperture", (0,.03,-.381)),
            ("Socket.01", (-.29,.225,0)), ("Socket.02", (.29,.225,0)),
            ("TrailWitness", (0,-.13,.34)),
        ]:
            self.bone(name, p)
        outline = [(-.40,-.36),(.35,-.36),(.55,-.19),(.55,.17),(.39,.36),
                   (.14,.32),(-.06,.27),(-.29,.36),(-.47,.25),(-.55,.08),(-.55,-.18),(-.49,-.28)]
        def kidney():
            rings=[]
            for height,shrink in [(-.21,.08),(-.14,0),(.12,0),(.21,.065)]:
                rings.append([self.part.bm.verts.new(g((x*(1-shrink),height,z*(1-shrink)))) for x,z in outline])
            faces=[self.part.bm.faces.new(list(reversed(rings[0]))),self.part.bm.faces.new(rings[-1])]
            self.part.paint(faces,"paint","petrol")
            for band in range(3):
                for i in range(len(outline)):
                    j=(i+1)%len(outline)
                    face=self.part.bm.faces.new((rings[band][i],rings[band][j],rings[band+1][j],rings[band+1][i]))
                    slot="bare_metal" if band==2 and i in (1,5,9) else "paint"
                    color="bone" if i in (3,6,9) else common.mix("petrol","charcoal",.25) if band==0 else "petrol"
                    self.part.paint([face],slot,color if slot=="paint" else None)
                    faces.append(face)
            return faces
        self.shape("Hull",kidney)
        deck = [(x*.98/1.10,-z*.60/.72) for x,z in reversed(outline)]
        faces = self.shape("Deck", self.part.prism, "paint", deck, .08,
                           matrix=Matrix.Translation(g((0,.18,0))), color="bone")
        for i, f in enumerate(faces):
            if i in (5, 8, 10):
                self.part.paint([f], "paint", "petrol")
        self.box("LiftPlenum", (.82,.10,.50), (0,-.17,0), "rubber")
        for i, p in enumerate([(-.27,-.21,.10),(.27,-.21,.10),(0,-.21,-.18)], 1):
            name = f"LiftWell.{i:02d}"
            self.bone(name, p)
            self.ring(name, .067, .10, .04, p)
        for x in (-.54,.54):
            self.box("Bumper", (.04,.08,.58), (x,-.07,0), "rubber")
        for z in (-.35,.35):
            self.box("Bumper", (1.04,.08,.04), (0,-.07,z), "rubber")
        self.box("ServiceBrow", (.26,.12,.04), (0,.03,-.36), color="petrol")
        self.cyl("WitnessAperture", .034, .007, (0,.03,-.385), segs=8, slot="rubber", axis="Z")
        self.box("EscapeWitness", (.14,.07,.025), (0,.03,-.385), color="e9ecea")
        for x, name in [(-.29,"Socket.01"),(.29,"Socket.02")]:
            self.ring(name, .10, .14, .05, (x,.225,0))
            for i in range(3):
                a = i*math.tau/3
                self.wedge(name, (x+.128*math.cos(a),.25,.128*math.sin(a)), (.045,.035,.045))

    def module(self, name, offset=(0,0,0), prefix="", mirror=1):
        self.offset, self.prefix, self.mirror = Vector(offset), prefix, mirror
        self.clips.update(MODULE_CLIPS[name])
        self.bone("ModuleRoot", (0,0,0))
        self.foot()
        if name == "primer_coil":
            self.bone("FootBlock", (0,.06,0))
            self.box("FootBlock", (.19,.12,.19), (0,.06,0), color="petrol")
            self.bone("CoilPivot", (0,.30,0))
            self.bone("CoilRing", (0,.30,0), "CoilPivot")
            self.ring("CoilRing", .16,.275,.12,(0,.30,0),12,"paint","bone",True)
            for i in range(3):
                a = math.pi/2+i*math.tau/3
                self.box("CoilRing", (.08,.08,.13), (.23*math.cos(a),.30+.23*math.sin(a),0), color="petrol")
        elif name == "primer_mesh":
            self.bone("Stem", (0,.075,0))
            self.cyl("Stem", .035,.11,(0,.075,0))
            self.bone("MeshPivot", (0,.26,0))
            self.bone("MeshFrame", (0,.26,0), "MeshPivot")
            for x in (-.218, .218):
                self.box("MeshFrame", (.044,.37,.10), (x,.26,0), color="petrol")
            for y in (.095,.425):
                self.box("MeshFrame", (.392,.04,.10), (0,y,0), color="petrol")
            self.box("MeshFrame", (.035,.29,.08), (0,.26,0))
            for y in (.21,.31):
                self.box("MeshFrame", (.392,.025,.08), (0,y,0))
        elif name == "ram_prow":
            self.bone("Adaptor", (.09,.08,0))
            self.box("Adaptor", (.30,.10,.16), (.09,.08,0), color="petrol")
            self.bone("ProwSlide", (.18,.16,-.06))
            self.bone("ProwBeam", (.18,.16,-.06), "ProwSlide")
            self.box("ProwBeam", (.80,.12,.16), (.18,.16,.02), color="petrol")
            for x in (-.155,.515):
                self.box("ProwBeam", (.13,.22,.24), (x,.21,-.02))
            self.bone("Sleeve", (.18,.16,-.06), "ProwSlide")
            self.box("Sleeve", (.42,.09,.10), (.18,.16,-.12), "bare_metal")
            for x in (-.075,.435):
                self.box("ProwBeam", (.045,.09,.12), (x,.16,-.06), "rubber")
        elif name == "ram_spring":
            self.bone("Adaptor", (.09,.08,0))
            self.wedge("Adaptor", (.09,.08,0), (.30,.10,.16), "paint", "petrol")
            self.bone("SpringCage", (.18,.18,0))
            for x in (-.125,.485):
                self.box("SpringCage", (.09,.23,.20), (x,.18,0))
            self.box("SpringCage", (.52,.045,.07), (.18,.0875,.065), color="petrol")
            self.bone("SpringSlide", (.18,.18,0))
            self.bone("Spring", (.18,.18,0), "SpringSlide")
            points = [(.18-.183+.366*i/20,.18+.052*math.cos(i*math.tau/4),.052*math.sin(i*math.tau/4)) for i in range(21)]
            before = set(self.part.bm.verts)
            rows = []
            for i, p in enumerate(points):
                a = i*math.tau/4
                rows.append([self.part.bm.verts.new(self.point((p[0]+.017*math.cos(j*math.tau/3),
                            p[1]+.018*math.sin(j*math.tau/3)*math.cos(a),
                            p[2]+.018*math.sin(j*math.tau/3)*math.sin(a)))) for j in range(3)])
            faces = []
            for i in range(20):
                for j in range(3):
                    faces.append(self.part.bm.faces.new((rows[i][j],rows[i+1][j],rows[i+1][(j+1)%3],rows[i][(j+1)%3])))
            faces += [self.part.bm.faces.new(list(reversed(rows[0]))),self.part.bm.faces.new(rows[-1])]
            self.part.paint(faces,"bare_metal")
            for face in faces[:-2]:
                face.smooth = True
            index = next(i for i,b in enumerate(self.bones) if b[0] == prefix+"Spring")+1
            for v in self.part.bm.verts:
                if v not in before:
                    v[self.tags] = index
                    self.parts[prefix+"Spring"].append(tuple(v.co))
            self.cyl("Spring", .016,.40,(.18,.18,0),4,axis="X",caps=False)
            for x in (-.04,.40):
                self.box("SpringCage", (.035,.10,.10), (x,.18,0), "rubber")
        elif name == "escape_vent":
            self.bone("FootBox", (0,.055,0))
            self.box("FootBox", (.29,.11,.20), (0,.055,0), color="petrol")
            for side,x in [("L",-.12),("R",.12)]:
                self.bone("VaneHinge."+side, (x,.10,0))
                self.bone("Vanes."+side, (x,.10,0), "VaneHinge."+side)
                self.box("Vanes."+side, (.11,.61,.12), (x,.405,0), color="bone" if side=="L" else "petrol")
                self.box("Vanes."+side, (.065,.44,.012), (x,.41,-.064), "rubber")
                self.cyl("Vanes."+side, .035,.11,(x,.10,0),6,axis="X")
        elif name == "escape_rail":
            self.bone("Carriage", (0,.10,0))
            self.box("Carriage", (.31,.10,.15), (0,.10,0), "bare_metal")
            for side,x in [("L",-.125),("R",.125)]:
                self.bone("RailSlide."+side, (x,.10,0))
                self.bone("Rails."+side, (x,.10,0), "RailSlide."+side)
                self.box("Rails."+side, (.09,.52,.13), (x,.36,0), color="bone" if side=="L" else "petrol")
                self.box("Rails."+side, (.09,.04,.13), (x,.64,0), "rubber")
        self.offset, self.prefix, self.mirror = Vector((0,0,0)), "", 1

    def finish(self):
        bmesh.ops.recalc_face_normals(self.part.bm, faces=list(self.part.bm.faces))
        mesh = self.part.to_object()
        root = common.empty("Spil9" if self.name=="spil9" or "__" in self.name else "ModuleRoot")
        arm = bpy.data.objects.new("Spil9Rig", bpy.data.armatures.new("Spil9Mechanism"))
        bpy.context.collection.objects.link(arm)
        arm.parent = root
        bpy.context.view_layer.objects.active = arm
        arm.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        for name,p,parent in self.bones:
            bone = arm.data.edit_bones.new(name)
            bone.head, bone.tail = p, p+Vector((0,.06,0))
            if parent:
                bone.parent = arm.data.edit_bones[parent]
        bpy.ops.object.mode_set(mode="OBJECT")
        for b in arm.pose.bones:
            b.rotation_mode = "XYZ"
        attr = mesh.data.attributes["rig_part"]
        for i,(name,_,_) in enumerate(self.bones):
            ids = [v.index for v in mesh.data.vertices if attr.data[v.index].value==i+1]
            if ids:
                mesh.vertex_groups.new(name=name).add(ids,1,"REPLACE")
        mesh.parent = arm
        mesh.modifiers.new("Rigid machinery", "ARMATURE").object = arm
        for name,p,parent in self.bones:
            if name in ("Socket.01","Socket.02","TrailWitness"):
                obj = bpy.data.objects.new(name, None)
                bpy.context.collection.objects.link(obj)
                obj.parent, obj.parent_type, obj.parent_bone = arm,"BONE",name
                obj.location = (0,-.06,0)
        self.arm,self.mesh,self.root = arm,mesh,root
        self.actions = self.animate()
        return root

    def reset_pose(self):
        for b in self.arm.pose.bones:
            b.location=(0,0,0)
            b.rotation_euler=(0,0,0)
            b.scale=(1,1,1)

    def pose(self, clip, t):
        self.reset_pose()
        b = self.arm.pose.bones["BodyPose"]
        if clip == "idle":
            b.location.z = .03*math.sin(math.tau*t)
        elif clip == "follow":
            b.rotation_euler.x = math.radians(8)*math.exp(-4*t)*math.cos(math.pi*t/2)
        elif clip in ("dock","empty"):
            b.location.z = .025*(1-t)**2
        elif clip in ASSIST_CLIPS:
            z, pitch, roll, sxy, sz = assist_pose(clip, t)
            b.location.z = z
            b.rotation_euler.x, b.rotation_euler.y = math.radians(pitch), math.radians(roll)
            b.scale = (sxy, sxy, sz)
        for bone in self.arm.pose.bones:
            if bone.name.endswith(("CoilPivot","MeshPivot")):
                if clip=="primer_set":
                    bone.rotation_euler.z=math.radians(20)*t
                elif clip in ("primer_consume","primer_expire"):
                    bone.rotation_euler.z=math.radians(20)*(1-t)
            if bone.name.endswith("ProwSlide") and clip=="prow_response":
                bone.location.y=-.12*math.sin(math.pi*t)
            if bone.name.endswith("SpringSlide"):
                if clip=="spring_arm":
                    bone.scale.x=1-.30*t
                elif clip=="spring_spend":
                    bone.scale.x=.70+.30*t
            if bone.name=="EscapeWitness":
                if clip=="escape_spent":
                    bone.rotation_euler.x=-math.pi/2*t
                elif clip=="escape_rearm":
                    bone.rotation_euler.x=-math.pi/2*(1-t)

    def animate(self):
        actions = {}
        self.arm.animation_data_create()
        bpy.context.scene.render.fps=100
        for clip,seconds in self.clips.items():
            act=bpy.data.actions.new(clip)
            act.use_fake_user=True
            self.arm.animation_data_create()
            self.arm.animation_data.action=act
            end=round(seconds*100)+1
            for frame in range(1,end+1):
                self.pose(clip,(frame-1)/(end-1))
                for bone in self.arm.pose.bones:
                    for path in ("location","rotation_euler","scale"):
                        bone.keyframe_insert(path,frame=frame,group=bone.name)
            actions[clip]=act
        self.arm.animation_data.action=None
        self.reset_pose()
        bpy.context.scene.frame_set(1)
        return actions

    def export(self, path):
        path=Path(path)
        path.parent.mkdir(parents=True,exist_ok=True)
        bpy.context.view_layer.update()
        polish.bake(self.root, common.POLISH)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in common.tree(self.root):
            obj.select_set(True)
        bpy.context.view_layer.objects.active=self.arm
        bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
            export_animations=True,export_animation_mode="ACTIONS",export_anim_slide_to_zero=True,
            export_frame_range=False,export_force_sampling=True,export_def_bones=False,
            export_skins=True,export_yup=True,export_materials="EXPORT",export_vertex_color="ACTIVE",
            export_cameras=False,export_lights=False,export_extras=False)
        common.canonical_indices(str(path),vertices=True)
        isolate_channels(path)
        data=path.read_bytes()
        gltf=json.loads(data[20:20+struct.unpack_from("<I",data,12)[0]])
        prims=[p for m in gltf["meshes"] for p in m["primitives"]]
        tris=sum(gltf["accessors"][p["indices"]]["count"]//3 for p in prims)
        verts=sum(gltf["accessors"][p["attributes"]["POSITION"]]["count"] for p in prims)
        limits=(620,1140) if self.name=="spil9" else (1100,2100) if "__" in self.name else (240,480)
        assert 0<tris<=limits[0] and 0<verts<=limits[1] and len(prims)<=3, (self.name,tris,verts,len(prims),limits)
        print("SPL_EXPORT",self.name,"T",tris,"V",verts,"D",len(prims),"BYTES",len(data),flush=True)
        return {"asset":self.name,"tris":tris,"verts":verts,"draws":len(prims),"bytes":len(data),"clips":self.clips}


def lerp(a, b, t):
    return a+(b-a)*t


def ease_out(t):
    return 1-(1-t)**3


def assist_pose(clip, t):
    """BodyPose (lift m, pitch deg nose-up, roll deg, width scale, height scale) at clip
    fraction t. The runtime carries SPIL-9 over the ball; these are the body's acting."""
    if clip == "assist_rise":
        crouch = 4/9
        if t < crouch:
            e = t/crouch; e = e*e*(3-2*e)
            return -.07*e, 12*e, 0, 1+.14*e, 1-.18*e
        e = ease_out((t-crouch)/(1-crouch))
        arc = math.sin(math.pi*e)
        return lerp(-.07, .30, e), lerp(12, -22, e), 0, lerp(1.14, 1, e)-.12*arc, lerp(.82, 1, e)+.25*arc
    if clip == "assist_drop":
        hit, flat = 2/3, 8/9
        if t <= hit:
            e = (t/hit)**3
            return lerp(.30, -.10, e), lerp(-22, -38, e), 0, 1-.14*e, 1+.28*e
        if t <= flat:
            e = min(1, (t-hit)/(flat-hit)*3)
            return lerp(-.10, -.12, e), -38, 0, lerp(.86, 1.24, e), lerp(1.28, .68, e)
        e = ease_out((t-flat)/(1-flat))
        return lerp(-.12, -.05, e), lerp(-38, -12, e), 0, lerp(1.24, 1.04, e), lerp(.68, .94, e)
    e = ease_out(t)
    fade = 1-t
    return (lerp(-.05, 0, e)+.06*math.sin(math.pi*t)*fade,
            lerp(-12, 0, e)+8*math.sin(math.tau*t)*fade,
            9*math.sin(math.tau*2.5*t)*fade**1.5,
            lerp(1.04, 1, e), lerp(.94, 1, e)+.05*math.sin(math.pi*t)*fade)


def build(asset="spil9",pair=None):
    name="__".join(pair) if pair else asset
    m=Model(name)
    if pair or asset=="spil9":
        m.hull()
    if pair:
        assert FAMILY[pair[0]]!=FAMILY[pair[1]]
        for i,mod in enumerate(pair):
            x=-.29 if i==0 else .29
            m.module(mod,(x,.225,0),f"M{i+1}.",-1 if i==0 and mod.startswith("ram_") else 1)
    elif asset!="spil9":
        m.module(asset)
    m.finish()
    return m


def build_marks():
    """Grown-mark add-ons. The glTF root is an empty named Hull, so hero_assets'
    _mount_on_bones seats it on the Hull bone. That joint's rest turns Blender Y/Z into
    Godot -Z/Y, so the empty carries the inverse (+90 deg about X) and the parts below it
    are authored in hull coordinates like the rest of this file. Rings and the core use
    the emissive field slot: the halo is the assist gauge."""
    common.reset()
    polish.enable(**POLISH)
    common.SLOTS["bare_metal"] = {"color": "929995", "rough": .45, "metal": .6}
    hull = common.empty("Hull")
    hull.rotation_euler.x = math.pi/2
    meshes = []

    def mark(name, build_fn):
        part = common.Part(name)
        build_fn(part)
        bmesh.ops.recalc_face_normals(part.bm, faces=list(part.bm.faces))
        obj = part.to_object(parent=hull)
        meshes.append(obj)

    def halo(r_in, r_out, z):
        def fn(part):
            part.ring("field", r_in, r_out, .02, 16, loc=g((0, .62, z)), rot=(math.radians(65), 0, 0))
        return fn

    def slab(part, slot, points, axis, depth, color=None):
        n = Vector(axis)*(depth/2)
        lo = [part.bm.verts.new(g(Vector(q)-n)) for q in points]
        hi = [part.bm.verts.new(g(Vector(q)+n)) for q in points]
        faces = [part.bm.faces.new(list(reversed(lo))), part.bm.faces.new(hi)]
        for i in range(len(points)):
            j = (i+1) % len(points)
            faces.append(part.bm.faces.new((lo[i], lo[j], hi[j], hi[i])))
        part.paint(faces, slot, color)

    def fins(part):
        for side in (-1, 1):
            slab(part, "paint", [(.55*side, 0, -.05), (.55*side, .06, .30), (.76*side, .14, .44),
                                 (.74*side, .10, .34)], (1, 0, 0), .035, "petrol")

    def exhaust(part):
        for x in (-.19, .19):
            part.cyl("bare_metal", .055, .045, .18, 8, loc=g((x, -.02, .42)), rot=(math.pi/2, 0, 0))
            part.ring("rubber", .028, .046, .02, 8, loc=g((x, -.02, .515)), rot=(math.pi/2, 0, 0))

    def core_crest(part):
        part.cyl("field", .055, .045, .05, 6, loc=g((0, .245, .22)))
        slab(part, "paint", [(0, .22, -.10), (0, .22, -.32), (0, .48, -.46), (0, .42, -.30)], (1, 0, 0), .03, "bone")

    mark("Mk1Halo", halo(.15, .175, .40))
    mark("Mk2Fins", fins)
    mark("Mk3Halo", halo(.205, .225, .42))
    mark("Mk4Exhaust", exhaust)
    mark("Mk5CoreCrest", core_crest)
    return hull, meshes


def export_marks(path):
    hull, meshes = build_marks()
    common.export(hull, str(path))
    data = Path(path).read_bytes()
    gltf = json.loads(data[20:20+struct.unpack_from("<I", data, 12)[0]])
    prims = [p for m in gltf["meshes"] for p in m["primitives"]]
    tris = sum(gltf["accessors"][p["indices"]]["count"]//3 for p in prims)
    verts = sum(gltf["accessors"][p["attributes"]["POSITION"]]["count"] for p in prims)
    names = [n["name"] for n in gltf["nodes"]]
    assert [gltf["nodes"][i]["name"] for i in gltf["scenes"][0]["nodes"]] == ["Hull"], names
    assert all(m in names for m in MARKS) and len(prims) <= 7 and tris <= 520, (names, len(prims), tris)
    print("SPL_EXPORT spil9_marks T", tris, "V", verts, "D", len(prims), "BYTES", len(data), flush=True)
    return {"asset": "spil9_marks", "tris": tris, "verts": verts, "draws": len(prims), "bytes": len(data)}


def pairs():
    return [(a,b) for a,b in itertools.permutations(NAMES,2) if FAMILY[a]!=FAMILY[b]]


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--asset",choices=("spil9","spil9_marks")+NAMES,default="spil9")
    parser.add_argument("--pair",nargs=2,choices=NAMES)
    parser.add_argument("--all",action="store_true")
    parser.add_argument("--out",type=Path)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    if args.all:
        reports=[]
        for name in ("spil9",)+NAMES:
            m=build(name)
            reports.append(m.export(OUT/f"{name}.glb"))
        for pair in pairs():
            m=build(pair=pair)
            reports.append(m.export(OUT/"assembled"/f"{m.name}.glb"))
        reports.append(export_marks(OUT/"spil9_marks.glb"))
        evidence=SKETCH.parents[1]/"artifacts/local/dress-preview/SPL"
        evidence.mkdir(parents=True,exist_ok=True)
        (evidence/"export-metrics.json").write_text(json.dumps(reports,indent=2)+"\n")
    elif args.asset=="spil9_marks":
        export_marks(args.out or OUT/"spil9_marks.glb")
    else:
        m=build(args.asset,args.pair)
        m.export(args.out or OUT/("assembled" if args.pair else "")/f"{m.name}.glb")


if __name__=="__main__":
    main()
