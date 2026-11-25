"""Waking asset recipe. Blender 5.2.2, metres, rigid parts, no combat logic.

blender -b --threads 2 --python-exit-code 1 --python sketches/core-loop/tools/blender/bosses/waking.py
Add -- --preview to reimport the delivered GLBs and render CPU Cycles evidence.
Add -- --out /tmp/waking-rebuild for an isolated byte-reproduction run.

Both exports have pit-centred identity roots. CombatSeat and CombatSeatAnchor are
actor anchors at pit floor + 1.6 m. The consumer must supply their transforms from
the real Warden; CoreSocket stays actor-local +5.2 m. Never animate these anchors.
KitMount aliases CoreSocket; WeakPoint aliases ReactorCore, radius 1.3 m.
IntakeVane controls rotate about their radial local X axes. Vent aliases sit on
PressureLip controls. floor_warn/drop are Spoil; *_seam and *_bedrock select the
other collars. Sample only the selected floor animation on actual floor events.
SpineInner's visual drop extends exactly 4 m with its top fixed. When wiring,
fit both spine skins to SeatTether from _seat_warden, and sample the drop against
that committed displacement. The clips do not move the actor or any floor.
core_open reveals CoreLive mint only on actual family_open(); idle is slate.
On closure reset the shutters and signal surfaces from the delivered rest pose.
pit_defeat collapses optics only. It never drops another collar or the seat.

Original geometry, continuous cast profiles and lofted vanes, vertex-painted
wear. No external textures or assets. Shared export contract BUILD-SPEC.md
2026-10-06 wins over picture heights and omitted elevated combat seats.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import common
import polish

polish.enable(detail=2, bevel=0.05, bevel_angle=46.0, ao_reach=0.06)

ROOT = HERE.parents[4]
MODELS = ROOT / "sketches/core-loop/assets/models/bosses"
PREVIEW = ROOT / "artifacts/local/dress-preview/WAK"
M1, M2, M3, M4 = "ancient_enamel", "dark_joint", "glass", "signal_surface"
BONE, PETROL, DARK = "d2c5a5", "365754", "242a28"
BLUE, HAZARD, SLATE, MINT = "3d8bff", "ff5a3c", "617481", "8bf0d3"
FPS = 60
CLIPS = {
    "sleeping": (3.0, 0.0), "wake": (1.6, 1.0),
    "pulse_warn": (2.0, 2.0), "pulse": (0.5, 0.08),
    "floor_warn": (1.0, 1.0), "floor_drop": (0.6, 0.6),
    "floor_warn_seam": (1.0, 1.0), "floor_drop_seam": (0.6, 0.6),
    "floor_warn_bedrock": (1.0, 1.0), "floor_drop_bedrock": (0.6, 0.6),
    "core_open": (0.4, 0.4), "pit_defeat": (1.2, 1.2),
}


def materials():
    common.SLOTS.update({
        M1: {"vc": True, "rough": 0.83},
        M2: {"vc": True, "metal": 0.25, "rough": 0.65},
        M3: {"color": "ffffff", "alpha": 0.23, "rough": 0.12},
        M4: {"vc": True, "rough": 0.55},
    })


def cast_paint(part):
    part.bm.normal_update()
    if M1 not in part.slots:
        return
    slot = part.slots.index(M1)
    for face in part.bm.faces:
        if face.material_index != slot:
            continue
        c = face.calc_center_median()
        phase = math.sin(c.x * 2.1 + c.y * 1.7 + c.z * 0.65)
        petrol = max(face.loops[0][part.col][:3]) < .15
        base = common.srgb(PETROL if petrol else BONE)
        if face.normal.z > 0.6:
            color = tuple(min(1.0, v * 1.035) for v in base)
        elif face.normal.z < -0.6:
            color = common.mix(PETROL, DARK, 0.30) if petrol else common.mix(BONE, PETROL, 0.45)
        else:
            color = common.mix(PETROL, BONE, .12 if phase > -.45 else .03) if petrol else common.mix(BONE, PETROL, 0.1 if phase > -0.45 else 0.25)
        part.paint([face], M1, color)


def mesh(part, parent, at=(0, 0, 0), yaw=0.0):
    cast_paint(part)
    obj = part.to_object()
    obj.parent = parent
    obj.location = at
    obj.rotation_euler.z = yaw
    return obj


def empty(name, parent=None, at=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = at
    return obj


def lathe(part, profile, segs=24, offset=0.0, slots=None):
    """Closed cross-section swept continuously around the vertical axis."""
    rows = []
    segs *= common.DETAIL
    for k in range(segs):
        a = offset + math.tau * k / segs
        rows.append([part.bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for r, z in profile])
    for k in range(segs):
        for j in range(len(profile)):
            nxt = (j + 1) % len(profile)
            face = part.bm.faces.new((rows[k][j], rows[(k + 1) % segs][j],
                                      rows[(k + 1) % segs][nxt], rows[k][nxt]))
            slot = slots[j] if slots else M1
            part.paint([face], slot, DARK if slot == M2 else BONE)


def vane(parent, index):
    pivot = empty("IntakeVane%d" % index, parent,
                  (2.2 * math.cos(index * math.tau / 3), 2.2 * math.sin(index * math.tau / 3), 24))
    pivot.rotation_euler.z = index * math.tau / 3
    p = common.Part("VaneCasting%d" % index)
    sections = [(0, 0.0, .3, .22), (-.4, .14, .8, .46),
                (-1.8, .38, 1.1, .7), (-3.5, .46, 1.0, .62),
                (-5.6, .35, .65, .36), (-7, .05, .025, .05)]
    rows = []
    for z, r, w, t in sections:
        outline = [(r-t, -.75*w), (r-.65*t, -w), (r+.65*t, -w), (r+t, -.75*w),
                   (r+t, .75*w), (r+.65*t, w), (r-.65*t, w), (r-t, .75*w)]
        rows.append([p.bm.verts.new((x, y, z)) for x, y in outline])
    for k in range(len(rows)-1):
        for j in range(8):
            face = p.bm.faces.new((rows[k][j], rows[k+1][j], rows[k+1][(j+1)%8], rows[k][(j+1)%8]))
            color = PETROL if j in (2, 3, 4) and k in (1, 2, 3) else BONE
            p.paint([face], M2 if j == 7 else M1, DARK if j == 7 else color)
    p.paint([p.bm.faces.new(rows[0]), p.bm.faces.new(list(reversed(rows[-1])))], M1, BONE)
    for slot,x,width in [(M2,1.082,.095),(M4,1.084,.045)]:
        face=p.bm.faces.new([p.bm.verts.new(v) for v in
            [(x,-.4-width/2,-3.4),(x,-.4+width/2,-3.4),
             (x,-.4+width/2,-2.0),(x,-.4-width/2,-2.0)]])
        p.paint([face],slot,DARK if slot==M2 else BLUE)
    mesh(p, pivot)
    return pivot


def build_base():
    root = empty("WakingRoot")
    root["contract"] = "pit floor origin; fixed upper collar; CombatSeat is runtime actor anchor"
    collar = common.Part("CeilingCollar")
    lathe(collar, [(3.7,-.6),(4,-.42),(4,.42),(3.7,.6),(3.35,.6),(3.35,-.6)],
          32, slots=[M1,M1,M1,M1,M2,M1])
    mesh(collar, root, (0,0,24.4))
    bell_socket = empty("BellSocket", root, (0,0,24))
    bell = common.Part("BellHousing")
    lathe(bell, [(1.0,-2),(1.2,-1.8),(2.5,-.7),(3.5,1.8),(3.5,2),
                 (3.05,2),(2.85,1.6),(2.1,-.5),(.8,-1.7),(.8,-2)],
          32, slots=[M1,M1,M1,M1,M1,M2,M2,M2,M2,M1])
    for i in range(3):
        a = math.tau*i/3 + math.pi/2
        bell.uv(M3, .22, 8, 4, loc=(1.6*math.cos(a),1.6*math.sin(a),-.9))
    mesh(bell, root, (0,0,22))
    for i in range(3):
        vane(root, i)
    outer = common.Part("SpineOuter")
    lathe(outer, [(.78,0),(.9,-.2),(.9,-5.4),(.78,-5.6),(.65,-5.6),(.65,0)],
          24, slots=[M1,M1,M1,M1,M2,M1])
    mesh(outer, bell_socket)
    inner = common.Part("SpineInner")
    lathe(inner, [(.5,-3.2),(.6,-3.4),(.6,-15.4),(.5,-15.6),(.4,-15.6),(.4,-3.2)],
          20, slots=[M1,M1,M1,M1,M2,M1])
    mesh(inner, bell_socket)
    seat = empty("CombatSeat", root, (0,0,1.6))
    seat["runtime_owner"] = "Warden actor transform; scale one; no authored tracks"
    body = common.Part("SeatCasting")
    body.bevel = 0
    lathe(body, [(1.7,-1.6),(2.55,-1.4),(2.8,-.85),(2.8,.65),(2.7,1.25),
                 (1.8,1.6),(1.4,1.6),(1.4,1.25),(2.15,.55),(2.15,-1.05),(1.7,-1.3)],
          24, slots=[M1,M1,M1,M1,M1,M1,M2,M2,M2,M2,M1])
    for i in range(3):
        a = i*math.tau/3 + math.pi/6
        r = Vector((math.cos(a),math.sin(a),0))
        body.beam(M1, r*1.85+Vector((0,0,1.25)), r*1.65+Vector((0,0,6.6)), .32, .48, color=BONE)
        body.beam(M1, (0,0,6.85), r*1.65+Vector((0,0,6.6)), .30, .25, color=BONE)
    lathe(body, [(1.55,4.95),(1.72,5.05),(1.72,5.35),(1.55,5.45),(1.37,5.45),(1.37,4.95)],
          24, slots=[M1,M1,M1,M1,M2,M1])
    mesh(body, seat)
    empty("SeatTether", seat, (0,0,6.8))
    empty("CoreSocket", seat, (0,0,5.2))
    for name, y in [("FloorSocket1",12),("FloorSocket2",8),("FloorSocket3",4),("PitSocket",0)]:
        empty(name, root, (0,0,y))
    return root


def pressure(parent, i):
    angle = i*math.tau/3 + math.pi/2
    lip = empty("PressureLip%d" % i, parent, (2.25*math.cos(angle),2.25*math.sin(angle),1.0))
    lip.rotation_euler.z = angle
    p = common.Part("PressureCasting%d" % i)
    p.box(M1, (.4,1.8,.35), color=BONE)
    count = 8
    for j in range(count):
        y0, y1 = -.9+j*1.8/count, -.9+(j+1)*1.8/count
        vs = [p.bm.verts.new(v) for v in [(.205,y0,-.175),(.205,y1,-.175),(.205,y1,.175),(.205,y0,.175)]]
        p.paint([p.bm.faces.new(vs)], M4, HAZARD if j%2 == 0 else DARK)
    for j in range(-2,10):
        polygon = [(-.2,-.9+j*.24),(.2,-.9+j*.24+.18),(.2,-.9+(j+1)*.24+.18),(-.2,-.9+(j+1)*.24)]
        for limit, keep_above in [(-.9,True),(.9,False)]:
            out=[]
            for k,a in enumerate(polygon):
                b=polygon[(k+1)%len(polygon)]
                ain=a[1]>=limit if keep_above else a[1]<=limit
                bin_=b[1]>=limit if keep_above else b[1]<=limit
                if ain: out.append(a)
                if ain != bin_:
                    t=(limit-a[1])/(b[1]-a[1])
                    out.append((a[0]+t*(b[0]-a[0]),limit))
            polygon=out
            if not polygon: break
        if len(polygon)>=3:
            face=p.bm.faces.new([p.bm.verts.new((x,y,.178)) for x,y in polygon])
            p.paint([face],M4,HAZARD if j%2==0 else DARK)
    mesh(p, lip)
    empty("Vent%d" % i, lip)


def build_kit():
    root = empty("WakingKit")
    seat = empty("CombatSeatAnchor", root, (0,0,1.6))
    socket = empty("CoreSocket", seat, (0,0,5.2))
    mount = empty("KitMount", socket)
    reactor = empty("ReactorCore", mount)
    empty("WeakPoint", reactor)
    glass = common.Part("CoreGlass")
    glass.uv(M3, 1.3, 16, 8)
    mesh(glass, reactor)
    for name, color, scale in [("CoreUnready",SLATE,1), ("CoreLive",MINT,.001)]:
        signal = common.Part(name)
        signal.ico(M4,1.18,2,color=color)
        if name=="CoreUnready":
            center=signal.bm.verts.new((0,1.20,0))
            iris=[signal.bm.verts.new((.32*math.cos(i*math.tau/16),1.20,.32*math.sin(i*math.tau/16))) for i in range(16)]
            for i in range(16):
                signal.paint([signal.bm.faces.new((center,iris[(i+1)%16],iris[i]))],M4,DARK)
        obj=mesh(signal,reactor)
        obj.scale=(scale,)*3
    for i in range(3):
        angle=i*math.tau/3 + math.pi/2
        shutter=empty("CoreShutter%d"%i, mount, (1.3*math.cos(angle),1.3*math.sin(angle),0))
        shutter.rotation_euler.z=angle
        p=common.Part("ShutterCasting%d"%i)
        p.box(M1,(.25,.8,1.4),color=BONE)
        mesh(p,shutter)
        pressure(seat,i)
    for name,y in [("CollarSpoil",12),("CollarSeam",8),("CollarBedrock",4)]:
        p=common.Part(name)
        lathe(p,[(1.3,-.325),(1.5,-.2),(1.5,.2),(1.3,.325),(.96,.325),(.96,-.325)],
              12,slots=[M1,M1,M1,M1,M2,M1])
        mesh(p,root,(0,0,y))
    return root


def nodes(root):
    return {obj.name: obj for obj in common.tree(root)}


def poses(root, clip):
    """Sparse rigid-control tracks. No root, actor or floor socket is animated."""
    found=nodes(root)
    duration=CLIPS[clip][0]
    tracks={}

    def track(name,path,keys):
        if name in found:
            tracks[(name,path)]=keys

    for i in range(3):
        vane_name="IntakeVane%d"%i
        vane_rest=tuple(found[vane_name].rotation_euler) if vane_name in found else (0,0,0)
        def vr(x): return (x,0,vane_rest[2])
        if clip == "sleeping":
            track(vane_name,"rotation_euler",[(0,vr(0)),(duration,vr(0))])
        elif clip == "wake":
            track(vane_name,"rotation_euler",[(0,vr(0)),(.65,vr(.08)),(1.15,vr(-.025)),(duration,vr(0))])
        elif clip == "pulse_warn":
            track(vane_name,"rotation_euler",[(0,vr(0)),(.35,vr(.07)),(1.7,vr(.30)),(duration,vr(.32))])
            track("PressureLip%d"%i,"location",[(0,tuple(found["PressureLip%d"%i].location))] if "PressureLip%d"%i in found else [])
        elif clip == "pulse":
            track(vane_name,"rotation_euler",[(0,vr(.32)),(.08,vr(-.05)),(.25,vr(.07)),(duration,vr(0))])
    for i in range(3):
        name="PressureLip%d"%i
        if name in found and clip in ("pulse_warn","pulse"):
            rest=tuple(found[name].location)
            def lifted(y): return (rest[0],rest[1],rest[2]+y)
            keys=[(0,lifted(0)),(.35,lifted(.12)),(1.7,lifted(.5)),(2,lifted(.55))] if clip=="pulse_warn" else [(0,lifted(.55)),(.08,lifted(-.1)),(.22,lifted(.12)),(.5,lifted(0))]
            track(name,"location",keys)
    collar="CollarSeam" if clip.endswith("_seam") else "CollarBedrock" if clip.endswith("_bedrock") else "CollarSpoil"
    if clip.startswith("floor_warn"):
        if collar in found:
            rest=tuple(found[collar].location)
            track(collar,"location",[(0,rest),(.7,(rest[0],rest[1],rest[2]+.18)),(1,(rest[0],rest[1],rest[2]+.32))])
            track(collar,"rotation_euler",[(0,(0,0,0)),(1,(0,0,.18))])
    if clip.startswith("floor_drop"):
        if collar in found:
            rest=tuple(found[collar].location)
            track(collar,"location",[(0,(0,0,rest[2]+.32)),(.6,(2.0,0,rest[2]-4))])
            track(collar,"rotation_euler",[(0,(0,0,.18)),(.6,(.5,.35,.4))])
            track(collar,"scale",[(0,(1,1,1)),(.55,(.9,)*3),(.6,(.001,)*3)])
        track("SpineInner","scale",[(0,(1,1,11.6/15.6)),(.6,(1,1,1))])
    if clip in ("sleeping","wake","core_open","pit_defeat"):
        for i in range(3):
            name="CoreShutter%d"%i
            if name not in found: continue
            rest=tuple(found[name].location)
            factor=1.65 if clip=="core_open" else .55 if clip=="pit_defeat" else 1
            track(name,"location",[(0,rest),(duration,(rest[0]*factor,rest[1]*factor,rest[2]))])
        if clip == "wake":
            track("ReactorCore","rotation_euler",[(0,(0,0,0)),(.6,(.03,.06,.12)),(duration,(0,0,0))])
        if clip == "core_open":
            track("CoreUnready","scale",[(0,(1,)*3),(.1,(.001,)*3),(duration,(.001,)*3)])
            track("CoreLive","scale",[(0,(.001,)*3),(.1,(1,)*3),(duration,(1,)*3)])
        if clip == "pit_defeat":
            track("ReactorCore","scale",[(0,(1,)*3),(.25,(1.08,)*3),(.55,(.5,)*3),(duration,(.08,)*3)])
            track("CoreUnready","scale",[(0,(.001,)*3),(duration,(.001,)*3)])
            track("CoreLive","scale",[(0,(1,)*3),(.25,(1,)*3),(duration,(.001,)*3)])
            for i in range(3):
                track("IntakeVane%d"%i,"rotation_euler",[(0,(.05,0,i*math.tau/3)),(duration,(0,0,i*math.tau/3))])
    if not tracks:
        name="SpineInner" if "SpineInner" in found else "CoreShutter0"
        rest=tuple(found[name].scale)
        track(name,"scale",[(0,rest),(duration,rest)])
    return tracks


def animate(root):
    found=nodes(root)
    rest={name:(obj.location.copy(),obj.rotation_euler.copy(),obj.scale.copy()) for name,obj in found.items()}
    for clip in CLIPS:
        grouped={}
        for (name,path),keys in poses(root,clip).items():
            grouped.setdefault(name,{})[path]=keys
        for name,channels in grouped.items():
            obj=found[name]
            obj.animation_data_create()
            action=bpy.data.actions.new(clip+"__"+name)
            obj.animation_data.action=action
            for path,keys in channels.items():
                for time,value in keys:
                    setattr(obj,path,value)
                    obj.keyframe_insert(data_path=path,frame=1+time*FPS)
            for layer in action.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        for curve in bag.fcurves:
                            for point in curve.keyframe_points:
                                point.interpolation="BEZIER"
                                point.handle_left_type=point.handle_right_type="AUTO_CLAMPED"
                            curve.update()
            obj.animation_data.action=None
            nla=obj.animation_data.nla_tracks.new()
            nla.name=clip
            nla.strips.new(clip,1,action)
            nla.mute=True
            obj.location,obj.rotation_euler,obj.scale=rest[name]
    return rest


def export(root,path):
    wrapper=empty("WakingBaseAsset" if path.stem.endswith("base") else "WakingKitAsset")
    root.parent=wrapper
    bpy.context.scene.frame_set(0)
    if common.POLISH is not None:
        polish.bake(wrapper,common.POLISH)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in common.tree(wrapper): obj.select_set(True)
    bpy.context.view_layer.objects.active=wrapper
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
        export_yup=True,export_materials="EXPORT",export_vertex_color="ACTIVE",
        export_extras=False,export_animations=True,export_animation_mode="NLA_TRACKS",
        export_merge_animation="NLA_TRACK",export_frame_range=False,
        export_anim_slide_to_zero=True,export_force_sampling=True,
        export_optimize_animation_keep_anim_object=True,
        export_cameras=False,export_lights=False)
    blob=path.read_bytes()
    json_size=struct.unpack_from("<I",blob,12)[0]
    gltf=json.loads(blob[20:20+json_size])
    # Blender's global object namespace suffixes the second CoreSocket. GLB files
    for row in gltf["nodes"]:
        name=row.get("name","")
        stem,_,suffix=name.rpartition(".")
        if stem and suffix.isdecimal(): row["name"]=stem
    encoded=json.dumps(gltf,separators=(",",":"),ensure_ascii=False).encode()
    encoded+=b" "*((-len(encoded))%4)
    binary_chunk=blob[20+json_size:]
    blob=struct.pack("<III",0x46546c67,2,20+len(encoded)+len(binary_chunk))+struct.pack("<II",len(encoded),0x4e4f534a)+encoded+binary_chunk
    path.write_bytes(blob)
    common.canonical_indices(str(path),vertices=common.POLISH is not None)
    blob=path.read_bytes()
    anims={row["name"] for row in gltf.get("animations",[])}
    assert anims == set(CLIPS), (path,anims)
    tris=verts=draws=0
    for node in gltf["nodes"]:
        if "mesh" not in node: continue
        for primitive in gltf["meshes"][node["mesh"]]["primitives"]:
            draws+=1
            verts+=gltf["accessors"][primitive["attributes"]["POSITION"]]["count"]
            tris+=gltf["accessors"][primitive["indices"]]["count"]//3
    caps=(10000,9600,32) if path.stem.endswith("base") else (4000,4000,18)
    assert 0<tris<=caps[0] and verts<=caps[1] and draws<=caps[2], (path,tris,verts,draws,caps)
    result={"file":path.name,"bytes":len(blob),"sha256":hashlib.sha256(blob).hexdigest(),
            "tris":tris,"verts":verts,"draws":draws,"clips":sorted(anims)}
    print("WAK_EXPORT",json.dumps(result,sort_keys=True))
    return result


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--out",type=Path,default=MODELS)
    parser.add_argument("--preview",action="store_true")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    common.reset()
    materials()
    scene=bpy.context.scene
    scene.unit_settings.system="METRIC"
    scene.unit_settings.scale_length=1
    scene.render.fps=FPS
    base,kit=build_base(),build_kit()
    for root in (base,kit): animate(root)
    args.out.mkdir(parents=True,exist_ok=True)
    results=[export(base,args.out/"boss_waking_base.glb"),export(kit,args.out/"boss_waking_kit.glb")]
    if args.preview:
        import waking_preview
        waking_preview.render(args.out,PREVIEW,results)


if __name__ == "__main__":
    main()
