"""Author CUA assets. Blender 5.2.2, CPU only, no runtime/source changes.

blender -b --factory-startup --threads 2 -P build_cua.py
blender -b --factory-startup --threads 2 -P build_cua.py -- --out /tmp/cua-rerun
blender -b --factory-startup --threads 2 -P preview_cua.py
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import zlib

import bpy
import numpy as np

HERE = Path(__file__).resolve().parent
SKETCH = HERE.parents[2]
sys.path.insert(0, str(HERE.parent))
import common

TRAILS = [
    ("trail_salt_skip", "ChalkPuff", "e9ecea", (.09, .09), .35, "fade_shrink"),
    ("trail_ink_stitch", "FlatStamp", "2b3a4a", (.12, .07), .25, "fade"),
    ("trail_plum_curl", "CrescentPuff", "8a3f6e", (.13, .10), .35, "rotate_fade"),
    ("trail_forge_chips", "Chip", "3a6fb0", (.045, .045), .25, "tumble_fade"),
    ("trail_moth_tuft", "PairedTuft", "a39cb3", (.15, .09), .40, "expand_fade"),
    ("trail_rose_wash", "WashPuff", "d68ab0", (.16, .08), .35, "flatten_fade"),
    ("trail_sable_cable", "CableDash", "3f8f6a", (.03, .12), .35, "fade"),
    ("trail_rivet_swarf", "Swarf", "ae7240", (.07, .05), .30, "tumble_fade"),
    ("trail_kest_fuse_smoke", "SmokeWisp", "8c8577", (.07, .16), .40, "expand_fade"),
    ("trail_tarn_claw_marks", "ClawPair", "d2c5a5", (.40, .06), .40, "fade"),
    ("trail_tally_punch_tape", "TapeStrip", "f7f1e3", (.05, .14), .35, "fade"),
    ("trail_cannon_recital", "RecitalMarks", "6fb3a6", (.30, .07), .45, "fade"),
    ("trail_any_downbeat", "BeatTick", "8a5a3a", (.10, .025), .30, "fade"),
]
TRAIL_CELLS = [(0,0),(1,0),(2,0),(0,1),(1,1),(2,1),(3,0),(3,1),(0,2),(1,2),(2,2),(3,2),(0,3)]
DECALS = [
    ("decal_fern", "d2c5a5", (.44, .55)),
    ("decal_patch", "d2c5a5", (.44, .34)),
    ("decal_snail_shell", "d2c5a5", (.44, .42)),
    ("decal_thimble", "d2c5a5", (.36, .42)),
    ("decal_mushroom", "906681", (.44, .40)),
    ("decal_paw", "d2c5a5", (.42, .42)),
    ("decal_seashell", "d2c5a5", (.46, .42)),
    ("decal_moth", "906681", (.50, .34)),
    ("decal_sable_spool", "d2c5a5", (.44, .44)),
    ("decal_curtain_call", "d2c5a5", (.44, .37)),
]
PAINTS = [
    ("companion_paint_night", "2b3a4a"),
    ("companion_paint_forge", "3a6fb0"),
    ("companion_paint_plum", "8a3f6e"),
    ("companion_paint_salt", "e9ecea"),
    ("companion_paint_dusk", "d68ab0"),
    ("companion_paint_moth", "a39cb3"),
]


def png(path, pixels):
    h, w, _ = pixels.shape
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))
    raw = b"".join(b"\0" + row.tobytes() for row in pixels)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def grid(n):
    y, x = np.mgrid[:n, :n]
    return (x + .5) / n * 2 - 1, 1 - (y + .5) / n * 2


def ellipse(x, y, cx, cy, rx, ry, angle=0):
    u = (x-cx)*math.cos(angle) + (y-cy)*math.sin(angle)
    v = -(x-cx)*math.sin(angle) + (y-cy)*math.cos(angle)
    return (u/rx)**2 + (v/ry)**2 <= 1


def line(x, y, a, b, width):
    dx, dy = b[0]-a[0], b[1]-a[1]
    t = np.clip(((x-a[0])*dx+(y-a[1])*dy)/(dx*dx+dy*dy), 0, 1)
    return (x-a[0]-t*dx)**2 + (y-a[1]-t*dy)**2 <= width**2


def polygon(x, y, points):
    inside = np.zeros(x.shape, dtype=bool)
    for a, b in zip(points, points[1:] + points[:1]):
        if a[1] != b[1]:
            inside ^= ((a[1] > y) != (b[1] > y)) & (x < (b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0])
    return inside


def trail_shape(index, n=128):
    x, y = grid(n)
    w, h = TRAILS[index][3]
    mx, my = x*w/2, y*h/2
    if index == 0:
        shape = ellipse(x,y,0,0,.67,.57) | ellipse(x,y,.28,.10,.37,.32)
    elif index == 1:
        shape = polygon(x,y,[(-.78,-.47),(.71,-.42),(.80,.37),(-.68,.50)])
    elif index == 2:
        shape = ellipse(x,y,0,0,.78,.73) & ~ellipse(x,y,.22,.30,.68,.65)
    elif index == 3:
        shape = polygon(x,y,[(-.72,-.37),(.27,-.65),(.72,.12),(-.13,.73)])
    elif index == 4:
        shape = ellipse(x,y,-.28,.03,.43,.66,-.45) | ellipse(x,y,.29,-.04,.43,.65,.45)
    elif index == 5:
        shape = ellipse(x,y,0,0,.87,.52) | ellipse(x,y,-.22,.12,.61,.47)
    elif index == 6:
        shape = line(mx,my,(0,-.038),(0,.038),.011)
    elif index == 7:
        shape = np.zeros(x.shape, dtype=bool)
        pts = [((.003+.0015*t)*math.cos(t), (.003+.0015*t)*math.sin(t)) for t in np.linspace(0,math.pi*3,90)]
        for a,b in zip(pts,pts[1:]):
            shape |= line(mx,my,a,b,.003)
    elif index == 8:
        shape = ellipse(mx,my,0,-.03,.026,.036) | ellipse(mx,my,0,.03,.026,.036)
    elif index == 9:
        shape = np.zeros(x.shape, dtype=bool)
        for side in (-1,1):
            shape |= line(mx,my,(side*.165,-.018),(side*.165,.016),.008)
            shape |= line(mx,my,(side*.165+.007,-.004),(side*.165+.007,.019),.004)
            shape |= line(mx,my,(side*.165-.006,-.020),(side*.165-.006,.002),.004)
    elif index == 10:
        shape = (abs(mx) <= .021) & (abs(my) <= .058)
        for cy in (-.035,0,.035):
            shape &= ~ellipse(mx,my,0,cy,.0065,.0065)
    elif index == 11:
        shape = line(mx,my,(-.105,-.02),(-.105,.02),.006)
        shape |= line(mx,my,(-.051,.02),(-.035,-.02),.005) | line(mx,my,(-.035,-.02),(-.019,.02),.005)
        shape |= ellipse(mx,my,.035,0,.02,.02) & ~ellipse(mx,my,.035,0,.011,.011)
        fan = ellipse(mx,my,.087,-.02,.04,.04) & (mx >= .087) & (my >= -.02)
        for angle in (math.pi/6, math.pi/3):
            fan &= ~line(mx,my,(.087,-.02),(.087+.05*math.cos(angle),-.02+.05*math.sin(angle)),.0025)
        shape |= fan
    else:
        shape = line(mx,my,(-.034,0),(.034,0),.008)
    blur = shape.astype(float)
    for _ in range(5):
        blur = (blur*4 + np.roll(blur,1,0) + np.roll(blur,-1,0) + np.roll(blur,1,1) + np.roll(blur,-1,1))/8
    alpha = np.rint(blur*36).astype(np.uint8)
    rgba = np.full((n,n,4), 255, dtype=np.uint8)
    rgba[:,:,3] = alpha
    return rgba


def decal_shape(index, n=256):
    x, y = grid(n)
    mark = np.zeros((n,n), dtype=bool)
    if index == 0:
        mark |= line(x,y,(-.06,-.77),(.04,.78),.037)
        for j in range(6):
            cy = -.56 + j*.235
            span = .40-j*.046
            for side in (-1,1):
                mark |= ellipse(x,y,side*span*.56,cy+.075,span*.68,.064,side*.47)
    elif index == 1:
        mark |= polygon(x,y,[(-.75,-.43),(-.68,.46),(-.26,.55),(.05,.44),(.62,.52),(.76,.07),(.67,-.49),(.16,-.52),(-.29,-.47)])
        seam = line(x,y,(-.55,-.23),(.55,.24),.036)
        mark &= ~seam
        for cx in (-.35,0,.35):
            mark |= line(x,y,(cx-.045,cx*.42-.17),(cx+.045,cx*.42+.17),.061)
    elif index == 2:
        pts = []
        for t in np.linspace(0,math.pi*4.6,260):
            r = .045 + .045*t
            pts.append((r*math.cos(t),r*math.sin(t)))
        for a,b in zip(pts,pts[1:]):
            mark |= line(x,y,a,b,.052)
    elif index == 3:
        mark |= ellipse(x,y,0,.12,.58,.66) & (y > -.48)
        mark |= ellipse(x,y,0,-.48,.65,.10)
        for cx,cy in [(-.27,-.05),(.27,-.05),(0,.31)]:
            mark &= ~ellipse(x,y,cx,cy,.082,.094)
    elif index == 4:
        mark |= ellipse(x,y,0,.18,.78,.49) & (y > -.12)
        mark |= polygon(x,y,[(-.17,-.11),(.18,-.11),(.26,-.67),(-.22,-.67)])
    elif index == 5:
        mark |= ellipse(x,y,0,-.32,.43,.33)
        for cx,cy,angle in [(-.58,.12,-.40),(-.24,.47,-.15),(.24,.47,.15),(.58,.12,.40)]:
            mark |= ellipse(x,y,cx,cy,.15,.23,angle)
    elif index == 6:
        mark |= ellipse(x,y,0,.02,.78,.67) & (y > -.51)
        mark |= polygon(x,y,[(-.70,-.23),(0,-.71),(.70,-.23)])
        for cx in (-.62,-.31,0,.31,.62):
            mark &= ~line(x,y,(cx,.96),(cx*.13,-.52),.023)
        mark &= (y < .60 - .05*np.cos(x*15))
    elif index == 7:
        for side in (-1,1):
            mark |= ellipse(x,y,side*.40,.18,.39,.22,side*.31)
            mark |= ellipse(x,y,side*.33,-.30,.26,.25,-side*.4)
            mark |= line(x,y,(side*.055,.25),(side*.31,.70),.022)
            for j in range(4):
                cy = .34+j*.09
                cx = side*(.10+j*.055)
                mark |= line(x,y,(cx,cy),(cx+side*.12,cy+.01),.021)
        mark |= ellipse(x,y,0,-.015,.075,.34)
    elif index == 8:
        for side in (-1,1):
            mark |= ellipse(x,y,side*.40,0,.075,.52)
        drum = (abs(x) <= .33) & (abs(y) <= .30)
        for cy in (-.2,-.1,0,.1,.2):
            drum &= ~line(x,y,(-.33,cy),(.33,cy),.016)
        mark |= drum
        mark &= ~line(x,y,(-.5,-.5),(.5,.5),.13)
        mark |= line(x,y,(-.36,-.36),(.36,.36),.065)
        for end in (-1,1):
            c = end*.48
            jaw = ellipse(x,y,c,c,.17,.17) & ~ellipse(x,y,c,c,.075,.075)
            jaw &= ~line(x,y,(c,c),(c+end*.3,c+end*.3),.075)
            mark |= jaw
    else:
        for side in (-1,1):
            drape = polygon(x,y,[(side*.18,.58),(side*.74,.58),(side*.72,-.05),(side*.78,-.62),(side*.50,-.62),(side*.60,-.05)])
            for fold in (.36,.52):
                drape &= ~line(x,y,(side*(fold-.02),.50),(side*(fold+.10),-.55),.018)
            mark |= drape
        mark |= line(x,y,(-.60,.64),(.60,.64),.045)
        core = ellipse(x,y,0,-.06,.27,.27)
        crack = [(-.02,.24),(.07,.12),(-.06,.0),(.06,-.12),(-.04,-.24),(.03,-.36)]
        for a,b in zip(crack,crack[1:]):
            core &= ~line(x,y,a,b,.03)
        mark |= core
    underlay = ellipse(x,y,0,0,.91,.91)
    result = np.zeros((n,n,4),dtype=np.uint8)
    result[underlay,:3] = [36,42,40]
    result[underlay,3] = 112
    tint = tuple(int(DECALS[index][1][k:k+2],16) for k in (0,2,4))
    result[mark,:3] = tint
    result[mark,3] = 255
    return result, mark


def trail_atlas(out):
    atlas = np.full((512,512,4),255,dtype=np.uint8)
    atlas[:,:,3] = 0
    for i in range(len(TRAILS)):
        col,row = TRAIL_CELLS[i]
        atlas[row*128:(row+1)*128,col*128:(col+1)*128] = trail_shape(i)
    png(out/"textures/trail_atlas.png",atlas)


def trail_material(out):
    mat = bpy.data.materials.new("fx_neutral")
    mat.use_nodes = True
    mat.surface_render_method = "BLENDED"
    mat.diffuse_color = (1,1,1,1)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 1
    bsdf.inputs["Specular IOR Level"].default_value = 0
    bsdf.inputs["Emission Strength"].default_value = 0
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(out/"textures/trail_atlas.png"))
    tex.image.name = "trail_atlas"
    mat.node_tree.links.new(tex.outputs["Color"],bsdf.inputs["Base Color"])
    mat.node_tree.links.new(tex.outputs["Alpha"],bsdf.inputs["Alpha"])
    return mat


def build_trail(index,out,export=True):
    common.reset()
    ident,node,tint,(w,h),duration,clip = TRAILS[index]
    root = common.empty("BallTrail")
    root["attachment"] = "ball_position_floor_plus_0.04; velocity_heading; no shell spin"
    root["max_live_cards"] = 24
    root["max_wake_metres"] = 1.8
    mesh = bpy.data.meshes.new(node)
    mesh.from_pydata([(-w/2,-h/2,0),(w/2,-h/2,0),(w/2,h/2,0),(-w/2,h/2,0)],[],[(0,1,2),(0,2,3)])
    uv = mesh.uv_layers.new(name="UVMap")
    col,row = TRAIL_CELLS[index]
    coords = [(col/4,1-(row+1)/4),((col+1)/4,1-(row+1)/4),((col+1)/4,1-row/4),(col/4,1-row/4)]
    for poly in mesh.polygons:
        for loop in poly.loop_indices:
            uv.data[loop].uv = coords[mesh.loops[loop].vertex_index]
    colour = mesh.color_attributes.new(name="Color",type="FLOAT_COLOR",domain="POINT")
    mesh.color_attributes.active_color = colour
    for value in colour.data:
        value.color = common.rgba(tint)
    mesh.materials.append(trail_material(out))
    obj = bpy.data.objects.new(node,mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = root
    scene = bpy.context.scene
    scene.render.fps = 120
    scene.frame_start,scene.frame_end = 1,1+round(duration*120)
    middle = 1+round(duration*120*.40)
    curl = 20 if clip=="rotate_fade" else 0
    for frame,scale,angle in [(1,(1,1,1),0),(middle,(1.15,1.15,1) if clip=="expand_fade" else (1,1,1),curl),
                              (scene.frame_end,(.001,.001,1),curl)]:
        obj.scale = scale
        obj.rotation_euler = (0,0,math.radians(angle))
        if clip=="tumble_fade":
            obj.rotation_euler = (math.radians(12*(frame-1)/(scene.frame_end-1)),0,math.radians(24*(frame-1)/(scene.frame_end-1)))
        if clip=="flatten_fade" and frame==middle:
            obj.scale = (1.12,.65,1)
        obj.keyframe_insert(data_path="scale",frame=frame)
        obj.keyframe_insert(data_path="rotation_euler",frame=frame)
    obj.animation_data.action.name = clip
    for layer in obj.animation_data.action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = "LINEAR"
    scene.frame_set(1)
    if export:
        dest = out/"trails"/(ident+".glb")
        dest.parent.mkdir(parents=True,exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        root.select_set(True)
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(filepath=str(dest),export_format="GLB",use_selection=True,
            export_yup=True,export_apply=False,export_materials="EXPORT",export_vertex_color="ACTIVE",
            export_animations=True,export_animation_mode="ACTIONS",export_frame_range=True,
            export_force_sampling=True,export_anim_slide_to_zero=True,export_extras=True,
            export_cameras=False,export_lights=False)
        common.canonical_indices(str(dest))
        data = dest.read_bytes()
        n = struct.unpack_from("<I",data,12)[0]
        gltf = json.loads(data[20:20+n])
        for image in gltf["images"]:
            image.pop("bufferView",None)
            image.pop("mimeType",None)
            image["uri"] = "../textures/trail_atlas.png"
        body = json.dumps(gltf,separators=(",",":"),sort_keys=True).encode()
        body += b" "*((-len(body))%4)
        tail = data[20+n:]
        dest.write_bytes(b"glTF"+struct.pack("<II",2,20+len(body)+len(tail))
                         +struct.pack("<I",len(body))+b"JSON"+body+tail)
    return root,obj,middle


def build_decals(out):
    atlas = np.zeros((1024,1024,4),dtype=np.uint8)
    for i,(ident,_,_) in enumerate(DECALS):
        tile,mark = decal_shape(i)
        col,row = i%4,i//4
        atlas[row*256:(row+1)*256,col*256:(col+1)*256] = tile
        mask = np.full((256,256,4),255,dtype=np.uint8)
        mask[:,:,3] = mark.astype(np.uint8)*255
        png(out/"decals"/(ident+"_mask.png"),mask)
        target = out/"decals"/(ident+".tres")
        target.write_text('[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
            '[ext_resource type="Texture2D" path="res://assets/cosmetics/textures/decal_atlas.png" id="1"]\n\n'
            '[resource]\nresource_name = "DecalMask"\natlas = ExtResource("1")\n'
            f'region = Rect2({col*256}, {row*256}, 256, 256)\nfilter_clip = true\n')
    png(out/"textures/decal_atlas.png",atlas)


def build_paints(out):
    (out/"paints").mkdir(parents=True,exist_ok=True)
    for ident,tint in PAINTS:
        r,g,b = common.srgb(tint)
        (out/"paints"/(ident+".tres")).write_text('[gd_resource type="StandardMaterial3D" format=3]\n\n'
            '[resource]\nresource_name = "paint"\n'
            f'albedo_color = Color({r:.9f}, {g:.9f}, {b:.9f}, 1)\n'
            'roughness = 0.8\nvertex_color_use_as_albedo = true\n')


def manifest(out):
    data = {"schema":"scrapkeep-cua-assets/1","base":"955e7e55aa10a69c3d0f6c71d0bd2eb4763c5970",
        "metres_per_unit":1,"trails":[],"decals":[],"paints":[],
        "trail_contract":{"origin":"ball_position projected to floor + 0.04 m","inherit_shell_spin":False,
            "emission":"moving grounded only; suppress stationary/paused/airborne","max_cards":24,
            "max_wake_m":1.8,"max_width_m":.45,"max_height_m":.25,"max_lifetime_s":.45,
            "threat_overlap":"fade cosmetic first; zero alpha in committed threat footprint",
            "atlas":"textures/trail_atlas.png","material":"fx_neutral","max_texel_alpha":36/255,
            "opacity_envelope":[[0,1],[.40,.85],[1,0]],
            "glb_animation":"transform clips only; glTF has no core material-alpha animation; consumer applies opacity envelope",
            "batch":"24 cards share atlas/material; MultiMesh or one card buffer; never 24 scene draws"},
        "decal_contract":{"node":"DecalMask","attach":"HeroCore rolling shell paint surface only",
            "exclude":["HeroPod","glass","pilot","state-cue masks"],"plate_edge_clearance_m":.04,
            "origin":"centre of designated broad lower-shell plate","compose":"bake selected tile into existing paint surface; no projector/mesh/draw"},
        "paint_contract":{"material":"paint","attach":["Hull","Deck"],
            "exclude":["socket collars","rubber","bare_metal","EscapeWitness","module working faces","combat VFX","HUD"],
            "compose":"duplicate existing enamel material and set albedo_color only; resources are tint swatches",
            "extra_triangles":0,"extra_vertices":0,"extra_draws":0,"extra_clips":0}}
    for i,(ident,node,tint,size,duration,clip) in enumerate(TRAILS):
        data["trails"].append({"id":ident,"path":"trails/"+ident+".glb","nodes":["BallTrail",node],
            "clips":[clip],"duration_s":duration,"size_m":size,"tint":"#"+tint,"key_pose_s":round(duration*120*.4)/120,
            "triangles":2,"vertices":4,"draws":1,"selected_max_triangles":48,"selected_max_vertices":96,
            "uv_rect":[TRAIL_CELLS[i][0]/4,TRAIL_CELLS[i][1]/4,.25,.25]})
    for i,(ident,tint,size) in enumerate(DECALS):
        _,mark = decal_shape(i)
        yy,xx = np.where(mark)
        bounds = [int(xx.min()),int(yy.min()),int(xx.max()-xx.min()+1),int(yy.max()-yy.min()+1)]
        data["decals"].append({"id":ident,"path":"decals/"+ident+".tres","mask":"decals/"+ident+"_mask.png",
            "size_m":size,"tint":"#"+tint,"atlas_rect_px":[i%4*256,i//4*256,256,256],
            "mask_bounds_px":bounds,"tile_size_m":[size[0]*256/bounds[2],size[1]*256/bounds[3]],
            "extra_triangles":0,"extra_vertices":0,"extra_draws":0})
    for ident,tint in PAINTS:
        data["paints"].append({"id":ident,"path":"paints/"+ident+".tres","tint":"#"+tint,
            "extra_triangles":0,"extra_vertices":0,"extra_draws":0})
    data["files"] = [{"path":str(p.relative_to(out)),"bytes":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest()}
                     for p in sorted(out.rglob("*")) if p.is_file() and p.name!="cua_manifest.json" and p.suffix not in (".import",".uid")]
    (out/"cua_manifest.json").write_text(json.dumps(data,indent=2)+"\n")


def main():
    args = argparse.ArgumentParser()
    args.add_argument("--out",type=Path,default=SKETCH/"assets/cosmetics")
    cli = args.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    out = cli.out.resolve()
    out.mkdir(parents=True,exist_ok=True)
    trail_atlas(out)
    build_decals(out)
    build_paints(out)
    for i in range(len(TRAILS)):
        build_trail(i,out)
    manifest(out)
    print("CUA_BUILD: PASS (%d animated trail GLBs, %d decal resources/masks, %d tint resources)" % (len(TRAILS),len(DECALS),len(PAINTS)))


if __name__ == "__main__":
    main()
