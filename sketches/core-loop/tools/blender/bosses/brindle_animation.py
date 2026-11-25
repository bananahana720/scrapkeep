"""Rigid visual offsets for Brindle; timing comes from boss_rules.gd.

Import from brindle_model.py. NLA tracks with matching names combine the rigid
object actions into one GLB clip. The source root, every target socket and cable
span remain unanimated. Wire clip age to the same committed hazard age later.
lobber_warn is intentionally supplied by existing lobber.gd:_pose(), not this rig.
"""
import math
from pathlib import Path
import sys

import bpy
from mathutils import Euler, Vector

FPS = 30
SHIP_CLIPS = {
    "idle_roll": (1.2, .3), "crane_warn": (1.4, 1.4), "crane_sweep": (1.2, .6),
    "magnet_hold_drip": (.2, .1), "enter_furnace": (.6, .6),
    "slag_warn": (9.0, 2.5), "drone_deploy": (1.0, .85),
    "enter_scuttle": (.8, .8), "charge_warn": (1.4, 1.4),
    "wall_stun": (3.0, .2), "eject": (2.5, .35),
}
SCOOTER_CLIPS = {"eject": (2.5, .35), "chase": (1.0, .5)}
REST = {}
POSES = {}


def remember(root):
    import common
    for obj in common.tree(root):
        REST[obj.name] = (obj.location.copy(), obj.matrix_basis.to_euler(), obj.scale.copy())
    bpy.context.scene.render.fps = FPS


def restore(root):
    import common
    for obj in common.tree(root):
        if obj.animation_data:
            obj.animation_data.action = None
            for track in obj.animation_data.nla_tracks:
                track.mute = True
        if obj.name in REST:
            loc, rot, scale = REST[obj.name]
            obj.location, obj.scale = loc, scale
            if obj.rotation_mode == "QUATERNION":
                obj.rotation_quaternion = rot.to_quaternion()
            else:
                obj.rotation_euler = rot


def offset(obj, up=0, forward=0, pitch=0, yaw=0, roll=0, scale=1, side=0):
    loc, rot, scl = REST[obj.name]
    obj.location = loc + Vector((side, forward, up))
    turn = Euler((rot.x + pitch, rot.y + roll, rot.z + yaw))
    if obj.rotation_mode == "QUATERNION":
        obj.rotation_quaternion = turn.to_quaternion()
    else:
        obj.rotation_euler = turn
    obj.scale = scl * scale


def action(root, name, duration, rows, linear=()):
    """rows = object -> [(seconds, offset keywords)]. Only named visuals get keys.
    Parts in `linear` stay LINEAR: code moves the magnet head on a linear path, so its arm must match."""
    import common
    objects = {o.name: o for o in common.tree(root)}
    restore(root)
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = 1, 1 + round(duration * FPS)
    POSES[(root.name, name)] = rows
    for part, keys in rows.items():
        obj = objects[part]
        obj.animation_data_create()
        obj.animation_data.action = None
        for sec, values in keys:
            offset(obj, **values)
            for prop in ("location", "rotation_euler", "scale"):
                obj.keyframe_insert(data_path=prop, frame=1 + round(sec * FPS), group=part)
        act = obj.animation_data.action
        act.name = name + "__" + part
        track = obj.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 1, act)
        strip.name = name
        strip.extrapolation = "NOTHING"
        mode = "LINEAR" if part.startswith("Drum") or part in linear else "BEZIER"
        for layer in act.layers:
            for item in layer.strips:
                for bag in item.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            key.interpolation = mode
                            if mode == "BEZIER":
                                key.handle_left_type = key.handle_right_type = "AUTO_CLAMPED"
        obj.animation_data.action = None
        track.mute = True
    restore(root)


def vanished(duration):
    return [(0, {}), (duration, {"scale": .001})]


def absent(duration):
    return [(0, {"scale": .001}), (duration, {"scale": .001})]


def author_ship(root):
    remember(root)
    d = SHIP_CLIPS["idle_roll"][0]
    rows = {"Drum%s%d" % (side, k): [(0, {}), (d, {"pitch": -2 * math.pi})]
            for side in ("L", "R") for k in range(4)}
    rows["Hull"] = [(0, {}), (.3, {"up": -.025, "pitch": .004}),
                    (.6, {}), (.9, {"up": -.025, "pitch": -.004}), (d, {})]
    action(root, "idle_roll", d, rows)
    warn = math.radians(40)
    for name, duration in (("crane_warn", 1.4), ("crane_sweep", 1.2)):
        rows = {}
        for side, sign in (("Port", 1), ("Starboard", -1)):
            if name == "crane_warn":
                yaw = [(0, 0), (1.4, -warn)]
                magnet = [(0, .02), (.3, 0), (1.15, .21), (1.4, .18)]
                elbow = [(0, -.05), (.3, -.03), (1.1, -.2), (1.4, -.18)]
            else:
                yaw = [(0, -warn), (1.2, warn)]
                magnet = [(0, .18), (.7, .21), (1.2, .18)]
                elbow = [(0, -.18), (.7, -.2), (1.2, -.18)]
            rows["Crane" + side] = [(t, {"yaw": sign * v}) for t, v in yaw]
            rows["CraneElbow" + side] = [(t, {"pitch": v}) for t, v in elbow]
            rows["Magnet" + side] = [(t, {"pitch": v}) for t, v in magnet]
        action(root, name, duration, rows, linear=("CranePort", "CraneStarboard"))
    action(root, "magnet_hold_drip", .2, {
        "Magnet" + s: [(0, {"up": .035}), (.08, {"up": .055}), (.1, {"up": .025}), (.2, {"up": .035})]
        for s in ("Port", "Starboard")})
    rows = {"Cap%d" % k: [(0, {}), (.12, {"up": -.08}), (.24, {"up": .9}), (.36, {"up": .12}),
                          (.46, {"up": .36}), (.54, {"up": .22}), (.6, {"up": .25})] for k in range(3)}
    rows["CraneMasts"] = [(0, {}), (.1, {"scale": 1.06}), (.3, {"scale": .5}), (.45, {"scale": .001}),
                          (.6, {"scale": .001})]
    rows["CableSpans"] = [(0, {}), (.15, {}), (.3, {"scale": .001}), (.6, {"scale": .001})]
    for s, sign in (("Port", 1), ("Starboard", -1)):
        for prefix in ("Crane", "Magnet"):
            rows[prefix + s] = [(0, {}), (.1, {"up": .8, "scale": 1.1}), (.3, {"up": .4, "yaw": sign * 1.6, "scale": .5}),
                                (.45, {"yaw": sign * 2.4, "scale": .001}), (.6, {"yaw": sign * 2.4, "scale": .001})]
    rows["Hull"] = [(0, {}), (.1, {"up": -.16}), (.22, {"up": .1, "pitch": .01}), (.4, {}), (.6, {})]
    action(root, "enter_furnace", .6, rows)
    rows = {"SlagThroat": [(0, {}), (2.5, {"up": .25}), (8.5, {"up": .25}), (9, {})]}
    for k in range(3):
        rows["Cap%d" % k] = [(0, {"up": .25}), (9, {"up": .25})]
    action(root, "slag_warn", 9, rows)
    action(root, "drone_deploy", 1, {"Hatch" + s: [(0, {}), (.85, {"roll": sign * math.pi / 2}),
                                                      (1, {"roll": sign * math.pi / 2})]
        for s, sign in (("L", -1), ("R", 1))})
    rows = {}
    for k in range(4):
        out = -1 if k < 2 else 1
        tip = .3 if k < 2 else -.3
        rows["Armour%d" % k] = [(0, {}), (.12, {"side": -out * .08, "scale": .97}),
                                (.18, {"side": out * 1.6, "up": 1.0, "roll": tip * 2, "scale": 1.05}),
                                (.4, {"side": out * 3.0, "up": .8, "roll": tip * 4.5}),
                                (.6, {"side": out * 3.8, "up": -.6, "roll": tip * 6, "scale": .5}),
                                (.8, {"side": out * 4.2, "up": -1.4, "roll": tip * 7, "scale": .001})]
    rows["CockpitShield"] = [(0, {}), (.06, {"pitch": .04}), (.12, {"pitch": -.03}), (.2, {"pitch": .05}),
                             (.25, {}), (.38, {"pitch": math.radians(118)}), (.52, {"pitch": math.radians(100)}),
                             (.65, {"pitch": math.radians(107)}), (.8, {"pitch": math.radians(105)})]
    rows["Hull"] = [(0, {}), (.12, {"up": -.14, "pitch": -.008}), (.18, {"up": .1}), (.35, {"up": -.03}),
                    (.55, {}), (.8, {})]
    rows["CraneMasts"] = absent(.8)
    rows["CableSpans"] = absent(.8)
    for k in range(3):
        rows["Cap%d" % k] = [(0, {"up": .25}), (.8, {})]
    for s in ("Port", "Starboard"):
        for prefix in ("Crane", "Magnet"):
            rows[prefix + s] = absent(.8)
    action(root, "enter_scuttle", .8, rows)
    action(root, "charge_warn", 1.4, {
        "BowRam": [(0, {}), (.25, {"forward": .03}), (1.15, {"forward": -.2, "pitch": .028}),
                   (1.4, {"forward": -.18, "pitch": .025})],
        "Hull": [(0, {}), (.25, {"up": .012}), (1.15, {"up": -.09, "pitch": .009}),
                 (1.4, {"up": -.08, "pitch": .008})]})
    action(root, "wall_stun", 3, {
        "Hull": [(0, {}), (.10, {"pitch": -.015, "up": -.06}),
                  (.2, {"pitch": .012}), (.35, {}), (.6, {"pitch": -.004, "up": .01}), (1.1, {}), (3, {})],
        "CockpitShield": [(0, {"pitch": math.radians(105)}), (3, {"pitch": math.radians(105)})]})
    action(root, "eject", 2.5, {
        "ScooterSeat": [(0, {}), (.2, {"up": -.18}), (.35, {"up": .25}), (.5, {"scale": .001}), (2.5, {"scale": .001})],
        "CockpitShield": [(0, {"pitch": math.radians(105)}), (2.5, {"pitch": math.radians(105)})]})
    restore(root)


def author_scooter(root):
    remember(root)
    action(root, "eject", 2.5, {
        "ScooterSeat": [(0, {}), (.2, {"up": -.08}), (.35, {"up": .04, "pitch": .035}),
                        (.7, {}), (2.5, {})]})
    action(root, "chase", 1, {
        "ScooterSeat": [(0, {"roll": -.05}), (.25, {"roll": -.08, "up": .012}),
                        (.5, {"roll": -.05}), (.75, {"roll": -.08, "up": .012}), (1, {"roll": -.05})],
        "Drums": [(0, {}), (1, {"pitch": -16 * math.pi})]})
    restore(root)


def preview_pose(root, clip, seconds):
    """Evaluate the actual authored NLA track, including phase preparation."""
    import common
    restore(root)
    objects = {o.name: o for o in common.tree(root)}
    if root.name == "BrindleRoot" and clip in ("slag_warn", "drone_deploy", "enter_scuttle", "charge_warn", "wall_stun", "eject"):
        offset(objects["CraneMasts"], scale=.001)
        offset(objects["CableSpans"], scale=.001)
        for s in ("Port", "Starboard"):
            for prefix in ("Crane", "Magnet", "Cable"):
                offset(objects[prefix + s], scale=.001)
    if root.name == "BrindleRoot" and clip in ("slag_warn", "drone_deploy"):
        for k in range(3):
            offset(objects["Cap%d" % k], up=.25)
    if root.name == "BrindleRoot" and clip in ("charge_warn", "wall_stun", "eject"):
        for k in range(4):
            offset(objects["Armour%d" % k], scale=.001)
        offset(objects["CockpitShield"], pitch=math.radians(105))
    for obj in common.tree(root):
        if obj.animation_data:
            for track in obj.animation_data.nla_tracks:
                track.mute = track.name != clip
    bpy.context.scene.frame_set(1 + round(seconds * FPS))
    bpy.context.view_layer.update()


if __name__ == "__main__":
    sys.path[:0] = [str(Path(__file__).resolve().parent), str(Path(__file__).resolve().parent.parent)]
    import brindle_model
    brindle_model.main()
