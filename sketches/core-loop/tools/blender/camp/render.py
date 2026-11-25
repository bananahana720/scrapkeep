"""Preview renders for the camp kit (Cycles on CPU, so a cloud container without a GPU can run it). Not part of any build.

  Turntable of one or more GLBs, four yaws on one sheet:
    blender -b --python-exit-code 1 -P sketches/core-loop/tools/blender/camp/render.py -- --piece a.glb [b.glb ...] --out DIR
  The whole camp from the layout (hero overhead, the spawn view at ball height, and the gate run):
    blender -b --python-exit-code 1 -P sketches/core-loop/tools/blender/camp/render.py -- --layout --models DIR --out DIR

Options: --samples N (default 24), --size WxH (default 1280x720). Collision nodes ("-col-col") are hidden. Every imported
surface is shaded from its COLOR_0 vertex colour, as the runtime enamel slot does.
"""
import argparse
import math
from pathlib import Path
import subprocess
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
import common
import cycles_device
import layout as L

SKETCH = HERE.parents[2]
MODELS = SKETCH / "assets/models"


def opts():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--piece", nargs="*", default=[])
    p.add_argument("--layout", action="store_true")
    p.add_argument("--models", default=str(MODELS / "camp"))
    p.add_argument("--out", required=True)
    p.add_argument("--samples", type=int, default=24)
    p.add_argument("--size", default="1280x720")
    p.add_argument("--stack", action="store_true", help="import every --piece into one scene (a base plus its shells)")
    p.add_argument("--dist", type=float, default=0.0, help="turntable camera distance; 0 fits the bounds")
    return p.parse_args(argv)


def vc_material():
    mat = bpy.data.materials.get("camp_preview_vc")
    if mat:
        return mat
    mat = bpy.data.materials.new("camp_preview_vc")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.85
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = ""
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def flat(name, color, rough=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = common.rgba(color)
    bsdf.inputs["Roughness"].default_value = rough
    return mat


def import_glb(path, loc=(0, 0, 0), yaw=0.0, scale=1.0):
    """Import a GLB in Godot placement terms: loc in Godot space, yaw about Godot +Y (radians)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in bpy.data.objects if o not in before]
    roots = [o for o in new if o.parent is None or o.parent not in new]
    for o in new:
        if o.name.endswith("-col-col") or "-col" in o.name and o.type == "MESH" and not o.data.materials:
            o.hide_render = True
            o.hide_viewport = True
        elif o.type == "MESH":
            has_vc = len(o.data.color_attributes) > 0
            if has_vc:
                o.data.materials.clear()
                o.data.materials.append(vc_material())
    gx, gy, gz = loc
    for r in roots:
        r.location = Vector((gx, -gz, gy)) + r.location
        r.rotation_mode = "XYZ"
        r.rotation_euler.z += yaw
        r.scale = (r.scale.x * scale, r.scale.y * scale, r.scale.z * scale)
    return new


def world_setup(samples, size, sky=True):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = (int(v) for v in size.split("x"))
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.new("sky")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes["Background"]
    bg.inputs["Color"].default_value = common.rgba("a9c3d6" if sky else common.mix("sandstone", "bone", 0.5))
    bg.inputs["Strength"].default_value = 0.9
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 4.2
    sun.angle = math.radians(2.0)
    sun.color = common.srgb("fff1dc")
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(48), math.radians(8), math.radians(-38))
    scene.collection.objects.link(so)


def camera(name, loc, look, fov):
    cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
    bpy.context.scene.collection.objects.link(cam)
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.angle = math.radians(fov)
    cam.data.clip_end = 5000
    cam.location = Vector(loc)
    d = Vector(look) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return cam


def shot(cam, path):
    scene = bpy.context.scene
    scene.camera = cam
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    print("SHOT", path)


def g2b(x, y, z):
    return (x, -z, y)


def ground(size=3000, color="c9a77a"):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, -0.01))
    g = bpy.context.active_object
    g.data.materials.append(flat("ground", color))


def turntable(o):
    out = Path(o.out)
    out.mkdir(parents=True, exist_ok=True)
    groups = [o.piece] if o.stack else [[p] for p in o.piece]
    for group in groups:
        piece = group[0]
        common.reset()
        world_setup(o.samples, o.size, sky=False)
        ground(400, common.mix("sandstone", "bone", 0.35))
        objs = []
        for p in group:
            objs += import_glb(p)
        tops = [x for x in objs if x.parent is None]
        root = bpy.data.objects.new("turn", None)
        bpy.context.scene.collection.objects.link(root)
        for x in tops:
            x.parent = root
        bpy.context.view_layer.update()
        pts = [x.matrix_world @ Vector(c) for x in objs if x.type == "MESH" and not x.hide_render for c in x.bound_box]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        centre = (lo + hi) / 2
        radius = max((hi - lo).length / 2, 0.5)
        dist = o.dist or radius * 2.6
        name = Path(piece).stem
        paths = []
        for yaw in (0, 90, 180, 270):
            root.rotation_euler.z = math.radians(yaw)
            bpy.context.view_layer.update()
            cam = camera("cam_%d" % yaw, centre + Vector((0, -dist * math.cos(0.42), dist * math.sin(0.42))), centre, 40)
            p = out / ("%s_%03d.png" % (name, yaw))
            shot(cam, p)
            paths.append(str(p))
        sheet = out / ("%s_sheet.png" % name)
        subprocess.run(["montage", *paths, "-tile", "2x", "-geometry", "+4+4", "-background", "#242a28", str(sheet)],
                       check=True)
        print("SHEET", sheet)


EXISTING = [
]


def build_layout(models):
    m = Path(models)
    have = {p.name for p in m.glob("*.glb")}

    def put(name, loc, yaw=0.0, scale=1.0, base=m):
        if (base / name).exists():
            import_glb(base / name, loc, yaw, scale)
            return True
        print("SKIP", name)
        return False

    put("camp_plaza.glb", (0, 0, 0))
    put("camp_shortcut.glb", L.SHORTCUT_AT)
    station_glbs = {"gate": "camp_launch_gate.glb", "lockers": "camp_lockers.glb", "achieve": "camp_trophy_wall.glb",
                    "settings": "camp_settings_console.glb", "skee": "camp_skee_lane.glb", "pet": "camp_pet_pen.glb"}
    for sid, glb in station_glbs.items():
        pos, yaw = L.station(sid)
        put(glb, pos, yaw)
    pos, yaw = L.station("moss")
    put("camp_moss_stall.glb", pos, yaw)
    jx, jz = 7.6, -1.2
    put("moss_jukebox_cabinet.glb", (pos[0] + jx * math.cos(yaw) + jz * math.sin(yaw), 0,
                                     pos[2] - jx * math.sin(yaw) + jz * math.cos(yaw)), yaw, 1.0, MODELS)
    put("moss_hover_barge.glb", (-120.0, 5.0, -125.0), math.radians(-20), 1.0, MODELS)
    for x, z in ((-70, -40), (75, 45), (-40, 75), (40, -95), (-95, 55), (100, -75)):
        put("cottonwood_detail1.glb", (x, 0, z), math.radians(x + z), 1.0, MODELS)
    put("camp_trial_track.glb", L.TRIAL_AT)
    put("camp_sandbox_yard.glb", L.SANDBOX_AT, math.radians(90))
    put("camp_trial_arch.glb", (L.TRIAL_AT[0] - 16.0, 0.08, L.TRIAL_AT[2] + 8.0))
    sp = L.SANDBOX_AT
    put("camp_call_box.glb", (sp[0] + 17.6, 0, sp[2] - 6.0), math.radians(90))
    pos, yaw = L.station("pet")
    put("camp_pet.glb", (pos[0] * 0.95, 0, pos[2] * 0.95), yaw + 0.6)
    for k, toy in enumerate(("camp_toy_ball.glb", "camp_toy_wrench.glb", "camp_toy_tire.glb")):
        put(toy, (pos[0] * 0.9 + 2.5 * math.cos(k * 2.1), 0.3, pos[2] * 0.9 + 2.5 * math.sin(k * 2.1)), k * 1.3)
    for stem, bearing, r, dyaw in L.DRESSING:
        x, y, z = L.at(bearing, r)
        put(stem + ".glb", (x, y, z), L.yaw_to_centre(x, z) + math.radians(dyaw))


def layout_shots(o):
    common.reset()
    world_setup(o.samples, o.size)
    ground()
    build_layout(o.models)
    out = Path(o.out)
    out.mkdir(parents=True, exist_ok=True)
    shot(camera("hero", g2b(0, 110, 95), g2b(0, 0, -8), 62), out / "camp_layout_hero.png")
    shot(camera("spawn", g2b(0, 3.2, 9), g2b(0, 2.5, -40), 75), out / "camp_layout_spawn.png")
    shot(camera("top", g2b(0, 300, 0.01), g2b(0, 0, 0), 62), out / "camp_layout_top.png")
    for sid, (dist, h, fov) in {"gate": (30, 6, 60), "lockers": (22, 5, 60), "moss": (17, 4, 60),
                                "achieve": (18, 4, 60), "settings": (10, 3, 55), "skee": (24, 7, 62),
                                "pet": (15, 4, 60)}.items():
        (x, y, z), yaw = L.station(sid)
        fx, fz = math.sin(yaw), math.cos(yaw)
        eye = (x + fx * dist, h, z + fz * dist)
        shot(camera("st_" + sid, g2b(*eye), g2b(x, 2.0, z), fov), out / ("camp_station_%s.png" % sid))
    tx, _, tz = L.TRIAL_AT
    shot(camera("trial", g2b(tx - 60, 30, tz + 45), g2b(tx, 0, tz), 55), out / "camp_station_trial.png")
    sx, _, sz = L.SANDBOX_AT
    shot(camera("sandbox", g2b(sx + 40, 20, sz + 25), g2b(sx, 0, sz), 60), out / "camp_station_sandbox.png")


def main():
    o = opts()
    if o.layout:
        layout_shots(o)
    else:
        turntable(o)


if __name__ == "__main__":
    main()
