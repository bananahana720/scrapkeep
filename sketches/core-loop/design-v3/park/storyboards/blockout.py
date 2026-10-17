# Rough storyboard blockouts for the six hero landmarks and the camp (storyboards-first ruling,
# 2026-10-16). Silhouette and layout only: primitives plus a few existing GLBs for scale.
# Nothing here is a game asset; LANDMARK-CARDS.md stays the build spec.
#
# Frame: Blender Z up, metres. The arriving player comes from -Y; each landmark's front faces -Y.
# Numbers come from LANDMARK-CARDS.md and src/world/park/<stage>.json.
#
#   blender -b -P blockout.py -- --only dam --out renders [--samples 48] [--scale 1.0]

import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
SKETCH = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MODELS = os.path.join(SKETCH, "assets", "models")

COL = {
    "sand": "c6a274", "sand_dark": "a3825a", "bone": "d2c5a5", "concrete": "b9b2a2",
    "concrete_dark": "8f897c", "steel": "3a3633", "iron": "2b2724", "copper": "b77843",
    "oxide": "9b513a", "basalt": "3b3633", "limestone": "d8ccb0", "timber": "7a5a3c",
    "water": "4f8c8a", "ancient": "9dff3c", "pine": "3f5a3a", "slick_red": "b5603f",
    "slick_cream": "e3cfa6", "cap": "4a3a33", "solid": "e5a044", "net": "8f8a7a",
    "mint": "8bf0d3", "amber_light": "e5a044", "hazard": "ff5a3c", "petrol": "365754", "felt": "4e6b4a",
}

_mats = {}


def rgb(hex_):
    v = [int(hex_[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in v]


def mat(name, emit=0.0, rough=0.85, metal=0.0, alpha=1.0):
    key = (name, emit, alpha)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(f"{name}_{len(_mats)}")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    c = rgb(COL[name]) + [1.0]
    b.inputs["Base Color"].default_value = c
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = c
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
    _mats[key] = m
    return m


def link(obj, material):
    if material is not None:
        obj.data.materials.clear()
        obj.data.materials.append(material)
    return obj


def mesh_obj(name, bm, material=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return link(ob, material)


def box(name, center, size, material, rz=0.0, ry=0.0, rx=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center, rotation=(rx, ry, rz))
    ob = bpy.context.object
    ob.name = name
    ob.scale = size
    return link(ob, material)


def cone(name, base, r0, r1, h, material, verts=24, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r0, radius2=r1, depth=h,
                                    location=(base[0], base[1], base[2] + h / 2), rotation=rot)
    ob = bpy.context.object
    ob.name = name
    return link(ob, material)


def cyl_between(name, a, b, r, material, verts=8):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d.length, location=(a + b) / 2)
    ob = bpy.context.object
    ob.name = name
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = d.to_track_quat("Z", "Y")
    return link(ob, material)


def torus(name, center, R, r, material, rot=(0, 0, 0), major=48):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=major,
                                     minor_segments=8, location=center, rotation=rot)
    ob = bpy.context.object
    ob.name = name
    return link(ob, material)


def sphere(name, center, r, material, seg=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=center)
    ob = bpy.context.object
    ob.name = name
    bpy.ops.object.shade_smooth()
    return link(ob, material)


def lathe(name, profile, material, segs=48, center=(0, 0, 0), arc=(0.0, 2 * math.pi)):
    """Revolve [(radius, z)] about Z. A partial arc leaves the ends open."""
    bm = bmesh.new()
    full = abs(arc[1] - arc[0] - 2 * math.pi) < 1e-6
    n = segs if full else segs + 1
    rings = []
    for i in range(n):
        t = arc[0] + (arc[1] - arc[0]) * i / segs
        rings.append([bm.verts.new((center[0] + r * math.cos(t), center[1] + r * math.sin(t), center[2] + z))
                      for r, z in profile])
    for i in range(segs):
        a, b = rings[i], rings[(i + 1) % n]
        for j in range(len(profile) - 1):
            bm.faces.new((a[j], b[j], b[j + 1], a[j + 1]))
    return mesh_obj(name, bm, material)


def annulus(name, r_in, r_out, z, material, segs=64, center=(0, 0)):
    return lathe(name, [(r_in, z), (r_out, z)], material, segs, (center[0], center[1], 0))


def ground(name, size, z, material):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, z))
    ob = bpy.context.object
    ob.name = name
    return link(ob, material)


def text(label, loc, size=6.0, color="iron", rot=(math.radians(55), 0, 0)):
    bpy.ops.object.text_add(location=loc, rotation=rot)
    ob = bpy.context.object
    ob.data.body = label
    ob.data.size = size
    ob.data.align_x = "CENTER"
    ob.data.extrude = 0.05
    ob.data.materials.append(mat(color))
    return ob


def glb(rel, loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, rel))
    new = [o for o in bpy.data.objects if o not in before]
    roots = [o for o in new if o.parent is None]
    for r in roots:
        r.location = Vector(loc) + r.location
        r.rotation_euler = Euler(rot)
        r.scale = (scale, scale, scale)
    return roots


def ball(loc):
    """The player's ball (radius 1 m) with a scale cue: a mint halo, since 1 m vanishes at 100 m."""
    glb("pilot_sable_anim.glb", loc)


def beam(base, top, r=1.6):
    cyl_between("ancient_beam", base, (top[0], top[1], top[2] + 250), r, mat("ancient", emit=12.0), verts=12)


def mesa(name, center, rx, ry, h, material, verts=10):
    ob = cone(name, (center[0], center[1], center[2]), 1.0, 0.86, h, material, verts=verts)
    ob.scale = (rx, ry, 1)
    return ob


# ---------------------------------------------------------------- scene setup

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


def world_sky(sun_elev=38, sun_from=-30, strength=1.0):
    """sun_from: compass bearing the light comes from, 0 = from the arriving player's side (-Y),
    positive toward +X."""
    w = bpy.data.worlds.new("sky")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes["Background"]
    sky = nt.nodes.new("ShaderNodeTexSky")
    try:
        sky.sky_type = "MULTIPLE_SCATTERING"
    except TypeError:
        try:
            sky.sky_type = "NISHITA"
        except TypeError:
            pass
    sky.sun_elevation = math.radians(sun_elev)
    sky.sun_rotation = math.radians(270 - sun_from)
    if hasattr(sky, "altitude"):
        sky.altitude = 1200
    nt.links.new(sky.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.35 * strength
    bpy.ops.object.light_add(type="SUN")
    sun = bpy.context.object
    e, a = math.radians(sun_elev), math.radians(sun_from)
    toward_sun = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    sun.rotation_mode = "QUATERNION"
    sun.rotation_quaternion = (-toward_sun).to_track_quat("-Z", "Y")
    sun.data.energy = 3.4 * strength
    sun.data.angle = math.radians(1.5)
    sun.data.color = (1.0, 0.93, 0.82)


def haze(density=0.0006):
    """Cheap aerial perspective: a world volume. Off when density is 0."""
    if density <= 0:
        return
    nt = bpy.context.scene.world.node_tree
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Density"].default_value = density
    vol.inputs["Color"].default_value = (0.82, 0.74, 0.62, 1)
    nt.links.new(vol.outputs[0], nt.nodes["World Output"].inputs["Volume"])


def camera(name, loc, look, fov_v=65.0, lens_mm=None):
    cam_data = bpy.data.cameras.new(name)
    cam_data.sensor_fit = "VERTICAL"
    cam_data.angle_y = math.radians(fov_v)
    cam_data.clip_end = 6000
    cam = bpy.data.objects.new(name, cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = loc
    d = Vector(look) - Vector(loc)
    cam.rotation_mode = "QUATERNION"
    cam.rotation_quaternion = d.to_track_quat("-Z", "Y")
    return cam


def chase(ball_at, yaw_deg, pitch_deg, arm=12.0, fov=65.0):
    """chase_camera.gd: boss profile arm 12 m, shoulder 0.7 m up, FOV 65 (vertical, Godot keep_height).
    yaw 0 looks toward +Y. Positive pitch looks up."""
    yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
    fwd = Vector((math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
    pivot = Vector(ball_at) + Vector((0, 0, 0.7))
    # the orbit stays above the ball (the real rig clamps against the ground); the view tilts up
    orbit = Vector((math.sin(yaw) * math.cos(0.18), math.cos(yaw) * math.cos(0.18), -math.sin(0.18)))
    loc = pivot - orbit * arm
    return camera("gameplay", loc, pivot + fwd * 50, fov)


def render(cam, path, w, h, samples):
    sc = bpy.context.scene
    sc.camera = cam
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 4
    sc.cycles.volume_bounces = 0
    sc.cycles.volume_step_rate = 4.0
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "JPEG"
    sc.render.image_settings.quality = 86
    sc.view_settings.view_transform = os.environ.get("SB_VIEW", "Khronos PBR Neutral")
    sc.view_settings.exposure = float(os.environ.get("SB_EXPOSURE", "-1.0"))
    for look in ("AgX - Punchy", "AgX - Medium High Contrast"):
        try:
            sc.view_settings.look = look
            break
        except TypeError:
            pass
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("WROTE", path)


# ---------------------------------------------------------------- landmarks

def build_dam(variant):
    """Card 1. Arch chord 320 m, crest z 121 above the toe apron (z 0), plateau z 100.
    Lower 30 m of the face is the dam_face_quarter stamp (the ridden quarter pipe)."""
    ground("canyon_floor", 4000, 0, mat("sand"))
    for s in (-1, 1):
        box(f"plateau_{s}", (s * (160 + 900), 0, 50), (1800, 4000, 100), mat("sand_dark"))
    # reservoir behind the dam, near the crest
    box("reservoir", (0, 860, 97), (322, 1660, 2), mat("water", rough=0.15))
    # arch wall: lofted sections along a parabola bowed upstream (+Y) at the centre
    bm = bmesh.new()
    prof = [(-34, 0), (-26, 6), (-19, 16), (-14, 30), (6, 121), (14, 121), (14, 0)]  # (y offset, z)
    rows = []
    n = 32
    for i in range(n + 1):
        x = -160 + 320 * i / n
        dy = 25 * (1 - (x / 160) ** 2)
        rows.append([bm.verts.new((x, y + dy, z)) for y, z in prof])
    for i in range(n):
        for j in range(len(prof)):
            a, b = rows[i][j], rows[i + 1][j]
            c, d = rows[i + 1][(j + 1) % len(prof)], rows[i][(j + 1) % len(prof)]
            bm.faces.new((a, b, c, d))
    mesh_obj("arch_wall", bm, mat("concrete"))
    # quarter-pipe band, tinted so the ridden face reads
    bm = bmesh.new()
    rows = []
    qp = [(-34.2, 0.2), (-26.2, 6), (-19.2, 16), (-14.2, 30)]
    for i in range(n + 1):
        x = -150 + 300 * i / n
        dy = 25 * (1 - (x / 160) ** 2)
        rows.append([bm.verts.new((x, y + dy, z)) for y, z in qp])
    for i in range(n):
        for j in range(len(qp) - 1):
            bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
    mesh_obj("face_quarter", bm, mat("concrete_dark"))
    # crest deck, parapet, towers, gantry
    for s in (-1, 1):
        box(f"tower_{s}", (s * 18, 25 + 10, 131), (12, 12, 20), mat("concrete"))
        box(f"buttress_{s}", (s * 166, 6, 60), (16, 40, 122), mat("concrete_dark"))
    box("gantry", (0, 35, 139), (48, 6, 4), mat("steel", metal=0.6))
    box("parapet", (0, 21, 121.6), (320, 1, 1.2), mat("concrete"))
    # relic cradle and radial gate leaves over it
    box("cradle", (0, 8 - 2, 22), (20, 4, 26), mat("concrete_dark"))
    for s in (-1, 1):
        g = cyl_between(f"gate_{s}", (s * 6, -6, 34), (s * 6, -6, 46), 6, mat("steel", metal=0.6), verts=16)
        g.rotation_quaternion = Euler((0, math.radians(90), 0)).to_quaternion()
        g.scale = (1, 1, 1)
        g.location = (s * 6, -4, 40)
        cyl_between(f"gate_arm_{s}", (s * 6, -4, 40), (s * 6, 12, 50), 0.5, mat("copper", metal=0.7))
    glb("warden_reactor.glb", (0, -14, 22 - 1))
    # spillway pour from the relic: a green slick down the quarter pipe
    beam((0, -14, 30), (0, -14, 141))
    # canyon dressing: mesas for depth
    for i, (x, y, h) in enumerate([(-420, -700, 60), (380, -900, 80), (-250, -1300, 40), (600, -400, 70)]):
        mesa(f"mesa_{i}", (x, y, 0), 90, 60, h, mat("sand_dark"))
    # play-surface context: toe apron and kicker
    box("toe_apron", (0, -100, 0.3), (160, 140, 0.6), mat("sand", rough=0.9))
    box("apron_kicker", (0, -172, 2.5), (20, 26, 5), mat("concrete_dark"), rx=math.radians(-10))
    ball((-8, -95, 1))
    return {
        "hero": dict(loc=(-110, -760, 30), look=(0, 0, 75), fov=30),
        "play": dict(ball=(-8, -95, 1), yaw=6, pitch=22),
    }


def build_penstock(variant):
    """Card 2. Surge tower 90 m (diameter 18 to 14, bell flare, gallery at 84) near the arriving side;
    head house drum 80 m across, floor 14 m below grade; three penstocks drop over the east bluff."""
    box("lower_plain", (1300, 0, -60.5), (2000, 4000, 1), mat("sand_dark"))
    box("bluff_face", (300, 0, -30), (2, 4000, 60), mat("sand_dark"))
    # drum: a sunk cylinder, wall liner, floor, parapet with gaps
    dc = (0, 55)
    lathe("drum_liner", [(40, -14), (40, 0)], mat("concrete"), 64, (dc[0], dc[1], 0))
    annulus("drum_floor", 0, 40, -14, mat("concrete_dark"), 48, dc)
    annulus("drum_grade_hole", 40, 1800, 0.05, mat("sand"), 64, dc)
    gaps = [math.radians(a) for a in (135, 225, 0)]  # forecourt NW, annex SW, gate E (local)
    segs = 36
    for i in range(segs):
        t = 2 * math.pi * i / segs
        if any(abs((t - g + math.pi) % (2 * math.pi) - math.pi) < math.radians(9) for g in gaps):
            continue
        box(f"parapet_{i}", (dc[0] + 41 * math.cos(t), dc[1] + 41 * math.sin(t), 2),
            (7.4, 1.6, 4), mat("concrete"), rz=t + math.pi / 2)
    # roof trusses at z 18
    for k in range(-3, 4):
        x = k * 10
        half = math.sqrt(max(40 ** 2 - x ** 2, 1))
        cyl_between(f"truss_top_{k}", (x, dc[1] - half, 18), (x, dc[1] + half, 18), 0.5, mat("steel", metal=0.6))
        for s in (-1, 1):
            cyl_between(f"truss_leg_{k}_{s}", (x, dc[1] + s * half, 2), (x, dc[1] + s * half * 0.6, 18), 0.4,
                        mat("steel", metal=0.6))
    # tower with bell flare and gallery ring
    tc = (0, -58, 0)
    cone("surge_tower", tc, 9, 7, 80, mat("concrete"), 32)
    cone("bell", (tc[0], tc[1], 80), 7, 11, 10, mat("concrete"), 32)
    torus("gallery", (tc[0], tc[1], 84), 11.5, 0.6, mat("steel", metal=0.6))
    # flume: elevated channel from the north, entering the north wall 12 m above the floor
    fz = -2
    box("flume", (0, dc[1] + 40 + 300, fz + 1.5), (8, 600, 3), mat("concrete_dark"))
    for k in range(12):
        box(f"trestle_{k}", (0, dc[1] + 60 + k * 50, (fz - 0.5) / 2 - 0.5), (6, 2, abs(fz) + 1), mat("timber"))
    box("pour_channel", (-14, 30, -13), (8, 30, 1), mat("concrete_dark"))
    # penstocks: three pipes from the east wall down the bluff
    for i, y in enumerate((40, 55, 70)):
        cyl_between(f"penstock_{i}", (40, y, -8), (300, y, -8), 2, mat("copper", metal=0.7), 16)
        cyl_between(f"penstock_drop_{i}", (300, y, -8), (420, y, -60), 2, mat("copper", metal=0.7), 16)
        torus(f"collar_{i}", (41, y, -8), 2.4, 0.7, mat("copper", metal=0.7), rot=(0, math.radians(90), 0))
    glb("warden_reactor.glb", (-13.7, 54.9, -14))
    beam((tc[0], tc[1], 90), (tc[0], tc[1], 90))
    box("forecourt", (-60, 10, 0.2), (40, 60, 0.4), mat("sand", rough=0.9), rz=math.radians(-40))
    ball((14, 72, -13))
    for i, (x, y, h) in enumerate([(-500, 600, 70), (-700, -300, 50), (900, 900, 30)]):
        mesa(f"mesa_{i}", (x, y, 0), 120, 80, h, mat("sand_dark"))
    return {
        "hero": dict(loc=(-170, -235, 95), look=(5, 10, 20), fov=44),
        "play": dict(ball=(14, 72, -13), yaw=-122, pitch=16),
    }


def build_headframe(variant):
    """Card 3. Origin on the pit floor. 120 m steel headframe, sheave deck 110, wheels 14 m,
    back legs rake to the hoist house about 75 m along +X. Tipple deck at (0, -15, 40).
    Variant B: legs collide only above z 40; A: legs collide all the way down (amber)."""
    # open pit: plain at +100, benches down to the floor at 0
    ground("pit_floor", 900, 0, mat("sand_dark"))
    lathe("pit_wall", [(330, 0), (350, 22), (372, 25), (392, 50), (412, 53), (432, 78), (452, 81),
                       (470, 100), (2400, 100)], mat("oxide"), 72)
    # collar dish around the shaft
    lathe("collar_dish", [(8, -10), (20, -10), (35, 0)], mat("sand"), 48)
    box("shaft_collar", (0, 0, 0.5), (14, 14, 1), mat("iron", metal=0.5))
    # headframe: black iron; amber marks the solid the fork adds (legs below the tipple deck)
    solid = mat("solid", emit=0.6)
    iron = mat("iron", metal=0.5, rough=0.6)
    feet = [(-12, -10), (-12, 10), (12, -10), (12, 10)]
    tops = [(-6, -5), (-6, 5), (6, -5), (6, 5)]
    for i, (f, t) in enumerate(zip(feet, tops)):
        mid = (f[0] + (t[0] - f[0]) * 40 / 110, f[1] + (t[1] - f[1]) * 40 / 110, 40)
        cyl_between(f"leg_lo_{i}", (f[0], f[1], 0), mid, 1.1, solid if variant == "A" else iron)
        cyl_between(f"leg_hi_{i}", mid, (t[0], t[1], 110), 1.0, iron)
    for z in range(10, 110, 18):
        k = z / 110
        pts = [(f[0] + (t[0] - f[0]) * k, f[1] + (t[1] - f[1]) * k) for f, t in zip(feet, tops)]
        for a, b in ((0, 1), (2, 3), (0, 2), (1, 3)):
            cyl_between(f"brace_{z}_{a}{b}", (*pts[a], z), (*pts[b], z), 0.35, iron, 6)
    # back legs to the hoist side
    for s in (-1, 1):
        knee = (6 + 69 * (68 / 108), s * (5 + 15 * (68 / 108)), 40)
        cyl_between(f"back_leg_hi_{s}", (6, s * 5, 108), knee, 1.2, iron)
        cyl_between(f"back_leg_lo_{s}", knee, (75, s * 20, 0), 1.2, solid if variant == "A" else iron)
    box("sheave_deck", (0, 0, 110), (16, 14, 1.5), iron)
    for s in (-1, 1):
        torus(f"sheave_{s}", (0, s * 4, 117.5), 7, 0.5, iron, rot=(math.radians(90), 0, 0))
        cyl_between(f"rope_{s}", (7, s * 4, 117.5), (88, s * 4, 92), 0.15, iron, 4)
    # hoist house up on the first bench (the rope's far end)
    box("hoist_house", (95, 0, 85), (26, 22, 18), mat("oxide"))
    # tipple deck and lift (rows; the frame dresses around them)
    box("tipple_deck", (0, -15, 40), (24, 16, 1.5), mat("timber"))
    glb("park/contraptions/lift_platform.glb", (14, -15, 0.5))
    # hive well: the swarm Warden's path, kept clear
    glb("warden_swarm.glb", (0, 0, 20))
    cyl_between("hive_well", (0, 0, 0.5), (0, 0, 38), 6, mat("ancient", emit=0.25, alpha=0.08), 16).hide_render = True
    ball((-34, -48, 1))
    return {
        "hero": dict(loc=(-250, -320, 110), look=(15, 0, 55), fov=34),
        "play": dict(ball=(-34, -48, 1), yaw=35, pitch=26),
    }


def build_sinkhole(variant):
    """Card 4. Origin at the plateau rim. 250 m collapse down to a floor near z -110; pool radius 40;
    caisson lip; gallery ring row (70 m arc at z -108 on the far side) or, in variant B, a full ring.
    Nest at (0, -38, -99); beam column to z 140."""
    lathe("plateau", [(125, 0), (2400, 0)], mat("sand"), 96)
    # basalt cap over pale limestone, slight overhang then a flare
    lathe("cap", [(118, -6), (125, 0)], mat("basalt"), 96)
    lathe("wall", [(112, -110), (110, -60), (116, -20), (118, -6)], mat("limestone"), 96)
    annulus("floor", 40, 112, -110, mat("sand_dark"), 64)
    annulus("pool", 0, 40, -112, mat("water", rough=0.1), 48)
    torus("caisson", (0, 0, -110), 40, 0.8, mat("steel", metal=0.6), major=64)
    for k in range(24):
        t = 2 * math.pi * k / 24
        box(f"stain_{k}", (113 * math.cos(t), 113 * math.sin(t), -45 - 20 * math.sin(3 * t)),
            (0.3, 4 + 3 * abs(math.sin(5 * t)), 50), mat("oxide"), rz=t)
    # gallery ring deck: shipped arc vs. full ring
    arc = (math.radians(60), math.radians(120)) if variant == "A" else (0, 2 * math.pi)
    segs = 24 if variant == "A" else 96
    lathe("gallery_deck", [(46, -108.2), (61, -108.2)], mat("timber"), segs, arc=arc)
    n = 6 if variant == "A" else 32
    for k in range(n):
        t = arc[0] + (arc[1] - arc[0]) * k / max(n - 1, 1)
        for r in (48, 59):
            cyl_between(f"corbel_{k}_{r}", (r * math.cos(t), r * math.sin(t), -110), (r * math.cos(t), r * math.sin(t), -108.2),
                        0.4, mat("timber"), 6)
        box(f"lamp_post_{k}", (61 * math.cos(t), 61 * math.sin(t), -106.7), (0.3, 0.3, 3), mat("copper", metal=0.6))
        sphere(f"lamp_{k}", (61 * math.cos(t), 61 * math.sin(t), -105), 0.5, mat("amber_light", emit=6.0), 8)
    if variant == "A":
        # collapsed remains elsewhere: scattered deck slabs
        for k in range(10):
            t = math.radians(150 + k * 22)
            box(f"slab_{k}", (55 * math.cos(t), 55 * math.sin(t), -109.5), (6, 3, 0.4), mat("timber"),
                rz=t + 0.6 * math.sin(k), rx=0.3 * math.cos(k))
    for s in (-1, 1):
        box(f"ring_post_{s}", (s * 20, -43, -103), (2, 2, 14), mat("copper", metal=0.6))
    # headgear over the pump side
    for s in (-1, 1):
        cyl_between(f"headgear_{s}", (-85, s * 12, -110), (-80, 0, -70), 0.9, mat("timber"))
    box("headgear_cap", (-80, 0, -70), (3, 26, 2), mat("timber"))
    # nest on the near wall line and the beam column
    glb("warden_swarm.glb", (0, -38, -100))
    lathe("nest", [(3, -104), (9, -100), (8, -93), (4, -90)], mat("basalt"), 16, (0, -38, 0))
    beam((0, -38, -95), (0, -38, 140))
    ball((-10, -60, -109))
    for i, (x, y, h) in enumerate([(-600, 500, 60), (700, 300, 45), (-300, 900, 80)]):
        mesa(f"mesa_{i}", (x, y, 0), 120, 90, h, mat("sand_dark"))
    return {
        "hero": dict(loc=(-150, -260, 70), look=(0, 20, -80), fov=48),
        "play": dict(ball=(-10, -60, -109), yaw=20, pitch=8),
    }


def build_islands(variant):
    """Card 5. Origin on the tilt pivot at world 200. Deck rim at +200, tip at -118 (world 82),
    the hand cups the tip; net bowl at world 44 (local -156). Variant A: tip visual only;
    B: lowest 40 m collides (amber), a moving harpoon bite."""
    for o in glb("park/floating_island.glb", (0, 90, 200)):
        pass
    if variant == "B":
        cone("tip_bite", (0, 0, -119), 1.5, 15, 40, mat("solid", emit=0.6), 16)
    # waterfall ribbon off the rim, ending in mist
    box("waterfall", (60, -40, 125), (6, 0.5, 150), mat("water", emit=0.3, rough=0.1), rz=math.radians(-35))
    sphere("mist", (60, -40, 45), 14, mat("bone", alpha=0.4))
    # keel ribs on the lower taper
    for k in range(6):
        t = 2 * math.pi * k / 6
        cyl_between(f"rib_{k}", (22 * math.cos(t), 22 * math.sin(t), -40), (6 * math.cos(t), 6 * math.sin(t), -110), 1.2,
                    mat("copper", metal=0.6))
    glb("warden_mind.glb", (0, 0, -126), rot=(math.radians(90), 0, 0))
    beam((0, 0, 200), (0, 0, 200))
    # the net bowl on a high butte, knuckle buttes, void below
    nb = -156
    lathe("net_bowl", [(0, nb - 6), (60, nb - 4), (130, nb)], mat("net"), 64)
    lathe("bowl_butte", [(130, nb), (138, nb - 20), (150, nb - 600)], mat("slick_red"), 48)
    for name, (x, y) in {"knuckle_w": (-142, 10), "knuckle_e": (142, 10), "knuckle_n": (-100, 110)}.items():
        box(name, (x, y, nb + 9.5), (36, 36, 19), mat("slick_cream"))
    for i, (x, y, z) in enumerate([(-400, 300, -260), (500, -200, -300), (-200, -600, -330), (300, 700, -250)]):
        glb("highdraft/sky_cloud.glb", (x, y, z), scale=2.5)
    for i, (x, y, z, h) in enumerate([(-700, 600, -900, 500), (800, 400, -900, 560), (-900, -500, -900, 420)]):
        mesa(f"far_butte_{i}", (x, y, z), 120, 90, h, mat("slick_red"))
    ball((-30, -60, nb + 1))
    return {
        "hero": dict(loc=(-430, -560, -60), look=(0, 0, 10), fov=44),
        "play": dict(ball=(-30, -60, nb + 1), yaw=25, pitch=34),
    }


def build_spire(variant):
    """Card 6. Bowl floor z 0 (world -12). Spire to z 342. Perches at 45 m (A) on the hand's arc.
    A: lower shaft 30 m across to z 60, widening to 50 m by z 120 (card default).
    B: full 50 m base; the perch ring moves out to 62 m so the flight lane stays clear."""
    lathe("bowl", [(0, 0), (260, 0), (300, 12), (2400, 12)], mat("sand"), 96)
    strata = []
    if variant == "A":
        prof = [(15, 0), (15.5, 3), (15, 60), (25, 120), (22, 200), (16, 280), (10, 330)]
    else:
        prof = [(26, 0), (25, 60), (25, 120), (22, 200), (16, 280), (10, 330)]
    lathe("talus", [(prof[0][0] + 8, 0), (prof[0][0], 4)], mat("slick_cream"), 32)
    # banded shaft: alternate colours per band
    for i in range(len(prof) - 1):
        z0, z1 = prof[i][1], prof[i + 1][1]
        nb = max(1, int((z1 - z0) / 20))
        for k in range(nb):
            za = z0 + (z1 - z0) * k / nb
            zb = z0 + (z1 - z0) * (k + 1) / nb
            ra = prof[i][0] + (prof[i + 1][0] - prof[i][0]) * k / nb
            rb = prof[i][0] + (prof[i + 1][0] - prof[i][0]) * (k + 1) / nb
            lathe(f"band_{i}_{k}", [(ra, za), (rb, zb)], mat("slick_red" if (i + k) % 2 else "slick_cream"), 14)
    lathe("caprock", [(10.5, 330), (12, 335), (6, 342), (0, 342)], mat("cap"), 14)
    beam((0, 0, 342), (0, 0, 342))
    pr = 45 if variant == "A" else 62
    perches = [(0, pr), (pr * math.cos(math.radians(-30)), pr * math.sin(math.radians(-30))),
               (-pr * math.cos(math.radians(-30)), pr * math.sin(math.radians(-30)))]
    for i, (x, y) in enumerate(perches):
        box(f"perch_{i}", (x, y, 11.86), (12, 12, 23.73), mat("slick_cream"))
    # the hand's flight lane (arc peaking 9 m above the perches), drawn faintly
    for i in range(3):
        a, b = perches[i], perches[(i + 1) % 3]
        prev = None
        for k in range(13):
            t = k / 12
            p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, 30 + 9 * math.sin(math.pi * t))
            if prev:
                cyl_between(f"arc_{i}_{k}", prev, p, 2.8, mat("mint", emit=1.0, alpha=0.35), 8)
            prev = p
    glb("warden_mind.glb", (perches[0][0], perches[0][1], 33), rot=(math.radians(90), 0, math.radians(180)))
    for i, (x, y, h) in enumerate([(-500, 400, 90), (600, 200, 120), (-200, 800, 60), (400, -700, 70)]):
        mesa(f"mesa_{i}", (x, y, 0), 110, 80, h, mat("slick_red"))
    box("watch_butte", (0, -1190, 12.5), (219, 260, 25), mat("slick_red"))
    ball((-20, -80, 1))
    return {
        "hero": dict(loc=(-260, -720, 110), look=(0, 0, 160), fov=40),
        "play": dict(ball=(-20, -80, 1), yaw=12, pitch=26),
    }


# ---------------------------------------------------------------- camp

CAMP_STATIONS = {
    # id: (label, ring position)
    "gate": "Launch gate",
    "lockers": "Pilot lockers",
    "moss": "Moss",
    "achieve": "Achievements",
    "settings": "Settings",
    "skee": "Skee-ball",
    "pet": "Pet + toys",
    "ghost": "Time trial",
    "sandbox": "Sandbox",
}


def camp_station(sid, x, y, facing, labels):
    """Each station as its existing model or a rough stand-in, plus a label."""
    rz = math.radians(facing)
    if sid == "gate":
        glb("reward_gate.glb", (x, y, 0), rot=(0, 0, rz), scale=1.6)
        box("launch_pad", (x, y, 0.15), (12, 12, 0.3), mat("mint", emit=0.8))
    elif sid == "lockers":
        for k, p in enumerate(["sable", "rivet", "kest", "tally", "tarn", "cannon"]):
            dx = (k - 2.5) * 3.2
            ox, oy = x + dx * math.cos(rz), y + dx * math.sin(rz)
            box(f"locker_{p}", (ox, oy, 1.6), (2.6, 2.2, 3.2), mat("petrol", metal=0.4), rz=rz)
            glb(f"pilot_{p}_anim.glb", (ox, oy, 1.4))
    elif sid == "moss":
        glb("moss_workshop.glb", (x + 12, y, 0), rot=(0, 0, rz))
        glb("moss_jukebox_cabinet.glb", (x - 6, y + 3, 0), rot=(0, 0, rz))
    elif sid == "achieve":
        box("trophy_wall", (x, y, 3), (12, 1.2, 6), mat("copper", metal=0.6), rz=rz)
    elif sid == "settings":
        box("settings_post", (x, y, 2), (2, 2, 4), mat("bone"), rz=rz)
    elif sid == "skee":
        box("skee_lane", (x, y, 0.8), (4, 22, 1.6), mat("felt"), rz=rz)
        box("skee_ramp", (x + 10 * math.sin(-rz) * 0, y, 1), (4, 4, 2), mat("copper", metal=0.6), rz=rz)
        for k in range(3):
            torus(f"skee_ring_{k}", (x - 11 * math.sin(rz), y + 11 * math.cos(rz), 2.5 + k * 0.9), 2.2 - k * 0.6, 0.25,
                  mat("amber" if False else "copper", metal=0.6))
    elif sid == "pet":
        annulus("pet_pen", 0, 9, 0.12, mat("felt"), 32, (x, y))
        glb("scrap_crate.glb", (x + 3, y + 2, 0.12))
        sphere("pet", (x - 2, y, 0.9), 0.8, mat("oxide"))
        for k in range(3):
            sphere(f"toy_{k}", (x + 4 * math.cos(k * 2), y + 4 * math.sin(k * 2), 0.5), 0.4, mat("mint", emit=0.5))
    elif sid == "ghost":
        # a looping practice track: a raised ring the ghost races on
        torus("ghost_track", (x, y, 0.6), 22, 2.4, mat("concrete"), major=64)
        box("ghost_start", (x + 22, y, 1.2), (6, 1, 2.4), mat("mint", emit=0.8))
    elif sid == "sandbox":
        annulus("sandbox_yard", 0, 22, 0.1, mat("sand_dark"), 48, (x, y))
        torus("sandbox_fence", (x, y, 1), 22, 0.4, mat("iron", metal=0.5), major=48)
        for k, e in enumerate(["world_one/enemy_chaser.glb", "world_one/enemy_plated_brute.glb", "world_two/enemy_burrower.glb"]):
            glb(e, (x - 8 + k * 8, y, 0.1))
    if labels:
        text(CAMP_STATIONS[sid], (x, y - 8, 14), size=6.5)


def build_camp(variant):
    """A small walkable camp between runs on a canyon bench. Spawn at the centre; the launch gate is
    within a five-second roll. A: hub ring (stations around a plaza, gate straight ahead).
    B: main street (one lane from spawn to the gate, stations both sides, yard off the end)."""
    ground("bench", 3000, 0, mat("sand"))
    for i, (x, y, h) in enumerate([(-260, 240, 70), (260, 300, 90), (0, 420, 110), (-320, -150, 40)]):
        mesa(f"mesa_{i}", (x, y, 0), 120, 70, h, mat("sand_dark"))
    glb("moss_hover_barge.glb", (-110, 120, 6), rot=(0, 0, math.radians(20)))
    for i, (x, y) in enumerate([(-60, 80), (70, 95), (-95, -40), (95, -55), (30, -95)]):
        glb("cottonwood_detail1.glb", (x, y, 0))
    labels = True
    if variant == "A":
        annulus("plaza", 0, 26, 0.08, mat("bone", rough=0.9), 64)
        box("spawn_pad", (0, 0, 0.2), (6, 6, 0.4), mat("bone"))
        ring = {"gate": 90, "lockers": 145, "moss": 200, "achieve": 245, "settings": 290, "pet": 35,
                "skee": 330}
        R = 48
        for sid, a in ring.items():
            t = math.radians(a)
            r = 70 if sid == "gate" else R
            camp_station(sid, r * math.cos(t), r * math.sin(t), a + 90, labels)
            box(f"path_{sid}", (r / 2 * math.cos(t), r / 2 * math.sin(t), 0.1), (r - 20, 5, 0.2), mat("bone", rough=0.9),
                rz=t)
        camp_station("ghost", 120, 20, 0, labels)
        camp_station("sandbox", -120, -10, 0, labels)
        box("shortcut", (0, 35, 1.5), (6, 18, 3), mat("mint", emit=0.6), rx=math.radians(-10))
        text("Spawn", (0, -8, 10), size=6.0)
        ball((0, 0, 1))
        look = (0, 10, 0)
        hero = dict(loc=(0, -82, 98), look=(0, 14, 0), fov=56)
        play = dict(ball=(0, -2, 1), yaw=0, pitch=6)
    else:
        box("street", (0, 35, 0.1), (14, 110, 0.2), mat("bone", rough=0.9))
        box("spawn_pad", (0, -18, 0.2), (6, 6, 0.4), mat("bone"))
        camp_station("gate", 0, 90, 0, labels)
        left = ["lockers", "moss", "achieve"]
        right = ["settings", "skee", "pet"]
        for k, sid in enumerate(left):
            camp_station(sid, -30, 0 + k * 28, 90, labels)
        for k, sid in enumerate(right):
            camp_station(sid, 30, 0 + k * 28, -90, labels)
        camp_station("ghost", 110, 40, 0, labels)
        camp_station("sandbox", -110, 40, 0, labels)
        text("Spawn", (0, -26, 10), size=6.0)
        ball((0, -18, 1))
        hero = dict(loc=(0, -110, 130), look=(0, 35, 0), fov=52)
        play = dict(ball=(0, -20, 1), yaw=0, pitch=6)
    return {"hero": hero, "play": play}


BUILDERS = {
    "dam": build_dam, "penstock": build_penstock, "headframe": build_headframe,
    "sinkhole": build_sinkhole, "islands": build_islands, "spire": build_spire, "camp": build_camp,
}

SUN = {"dam": (34, -35), "penstock": (40, -60), "headframe": (62, -20), "sinkhole": (60, -10),
       "islands": (30, -50), "spire": (24, -60), "camp": (48, -30)}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts = {"--only": None, "--out": os.path.join(HERE, "renders"), "--samples": "40", "--scale": "1.0",
            "--variant": "A", "--views": "hero,play"}
    i = 0
    while i < len(argv):
        opts[argv[i]] = argv[i + 1]
        i += 2
    os.makedirs(opts["--out"], exist_ok=True)
    names = [opts["--only"]] if opts["--only"] else list(BUILDERS)
    scale = float(opts["--scale"])
    for name in names:
        reset()
        views = BUILDERS[name](opts["--variant"])
        elev, rot = SUN[name]
        world_sky(elev, rot)
        haze(0.0)
        suffix = "" if opts["--variant"] == "A" else "_" + opts["--variant"]
        for view in opts["--views"].split(","):
            v = views[view]
            if view == "hero":
                cam = camera("hero", v["loc"], v["look"], v["fov"])
            else:
                cam = chase(v["ball"], v["yaw"], v["pitch"])
            render(cam, os.path.join(opts["--out"], f"{name}{suffix}_{view}.jpg"),
                   int(1280 * scale), int(720 * scale), int(opts["--samples"]))


main()
