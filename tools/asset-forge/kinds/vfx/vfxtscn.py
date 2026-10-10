"""Converter: a validated vfx spec -> effect.tscn (Godot text scene) and the expectations the
Godot check compares against. Stdlib only. The spec is data; this module is the only thing that
writes scene text, so no model-written code ever reaches Godot.

One Node3D root, one CPUParticles3D child per emitter, one shared unshaded StandardMaterial3D
and mesh per emitter. The properties set are the ones vfx.gd sets on its pooled bursts (one_shot,
explosiveness, direction, spread, velocity, gravity, scale curve, align_y, no shadows), plus a
colour ramp and a fixed seed.
"""
import hashlib
import json
import math

import vfxsim

EMISSION = {"point": 0, "sphere": 1, "box": 3}     # CPUParticles3D.EMISSION_SHAPE_*
MESH_CLASS = {"quad": "QuadMesh", "sphere": "SphereMesh", "box": "BoxMesh", "prism": "PrismMesh"}


def f(x):
    """Short stable float text."""
    s = ("%.6f" % x).rstrip("0").rstrip(".")
    return "0" if s in ("", "-0") else s


def ff(x):
    """Float text that always has a decimal point (Curve._data wants real floats)."""
    s = f(x)
    return s if "." in s else s + ".0"


def v3(v):
    return "Vector3(%s, %s, %s)" % tuple(f(x) for x in v)


def unit(v):
    n = math.sqrt(sum(c * c for c in v))
    return [c / n for c in v]


def spec_sha256(spec):
    return hashlib.sha256(json.dumps(spec, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def mesh_size(e):
    s = e["mesh_size"]
    return {"quad": [s[0], s[1]], "sphere": [s[0], s[0]], "box": list(s), "prism": list(s)}[e["mesh"]]


def curve_data(pts):
    parts = []
    for i, (t, v) in enumerate(pts):
        left = right = 0.0
        if i > 0:
            left = (v - pts[i - 1][1]) / (t - pts[i - 1][0])
        if i < len(pts) - 1:
            right = (pts[i + 1][1] - v) / (pts[i + 1][0] - t)
        parts.append("Vector2(%s, %s), %s, %s, 1, 1" % (f(t), f(v), ff(left), ff(right)))
    return "[" + ", ".join(parts) + "]"


def gradient(e, palette):
    offs, cols = [], []
    for s in e["color_ramp"]:
        r, g, b = vfxsim.hex_rgb(palette[s["role"]])
        offs.append(s["t"])
        cols += [r, g, b, s.get("alpha", 1.0)]
    return offs, cols


def expectations(spec, palette):
    """What a loaded effect.tscn must hold, derived from the spec alone."""
    out = []
    for e in spec["emitters"]:
        offs, cols = gradient(e, palette)
        out.append({
            "name": e["name"], "amount": e["amount"], "lifetime": e["lifetime"], "one_shot": e["one_shot"],
            "explosiveness": e["explosiveness"], "randomness": e["randomness"],
            "position": list(e["offset"]), "emission_shape": EMISSION[e["shape"]],
            "emission_sphere_radius": e["extents"][0], "emission_box_extents": list(e["extents"]),
            "direction": unit(e["direction"]), "spread": e["spread"],
            "initial_velocity_min": e["velocity"][0], "initial_velocity_max": e["velocity"][1],
            "gravity": list(e["gravity"]), "damping_min": e["damping"][0], "damping_max": e["damping"][1],
            "scale_amount_min": e["scale"][0], "scale_amount_max": e["scale"][1],
            "particle_flag_align_y": e["align_y"], "seed": spec["seed"],
            "gradient_offsets": offs, "gradient_colors": cols,
            "curve": [list(p) for p in e["scale_curve"]],
            "mesh_class": MESH_CLASS[e["mesh"]], "mesh_size": mesh_size(e),
            "emissive": e["emissive"], "additive": e["blend"] == "add",
        })
    return {"schema": 1, "spec_sha256": spec_sha256(spec), "emitters": out}


def to_tscn(spec, palette, asset):
    subs, nodes = [], []
    for i, e in enumerate(spec["emitters"]):
        offs, cols = gradient(e, palette)
        subs.append('[sub_resource type="Gradient" id="Gradient_%d"]\noffsets = PackedFloat32Array(%s)\ncolors = PackedColorArray(%s)\n'
                    % (i, ", ".join(f(x) for x in offs), ", ".join(f(x) for x in cols)))
        subs.append('[sub_resource type="Curve" id="Curve_%d"]\n_data = %s\npoint_count = %d\n'
                    % (i, curve_data(e["scale_curve"]), len(e["scale_curve"])))
        translucent = e["blend"] == "add" or any(s.get("alpha", 1.0) < 1.0 for s in e["color_ramp"]) or e["mesh"] == "quad"
        mat = ['[sub_resource type="StandardMaterial3D" id="Mat_%d"]' % i, "shading_mode = 0"]
        if translucent:
            mat.append("transparency = 1")
        if e["blend"] == "add":
            mat.append("blend_mode = 1")
        mat.append("vertex_color_use_as_albedo = true")
        mat.append("albedo_color = Color(%s, %s, %s, 1)" % ((f(e["emissive"]),) * 3))
        if e["mesh"] == "quad":
            mat.append("billboard_mode = 3")
        subs.append("\n".join(mat) + "\n")
        mesh = ['[sub_resource type="%s" id="Mesh_%d"]' % (MESH_CLASS[e["mesh"]], i), 'material = SubResource("Mat_%d")' % i]
        s = e["mesh_size"]
        if e["mesh"] == "quad":
            mesh.append("size = Vector2(%s, %s)" % (f(s[0]), f(s[1])))
        elif e["mesh"] == "sphere":
            mesh += ["radius = %s" % f(s[0] / 2), "height = %s" % f(s[0]), "radial_segments = 6", "rings = 3"]
        else:
            mesh.append("size = %s" % v3(s))
        subs.append("\n".join(mesh) + "\n")
        n = ['[node name="%s" type="CPUParticles3D" parent="."]' % e["name"],
             "position = %s" % v3(e["offset"]),
             "cast_shadow = 0",
             "emitting = false",
             "amount = %d" % e["amount"],
             "lifetime = %s" % f(e["lifetime"]),
             "one_shot = %s" % ("true" if e["one_shot"] else "false"),
             "explosiveness = %s" % f(e["explosiveness"]),
             "randomness = %s" % f(e["randomness"]),
             "use_fixed_seed = true",
             "seed = %d" % spec["seed"],
             'mesh = SubResource("Mesh_%d")' % i,
             "emission_shape = %d" % EMISSION[e["shape"]]]
        if e["shape"] == "sphere":
            n.append("emission_sphere_radius = %s" % f(e["extents"][0]))
        if e["shape"] == "box":
            n.append("emission_box_extents = %s" % v3(e["extents"]))
        n += ["particle_flag_align_y = %s" % ("true" if e["align_y"] else "false"),
              "direction = %s" % v3(unit(e["direction"])),
              "spread = %s" % f(e["spread"]),
              "gravity = %s" % v3(e["gravity"]),
              "initial_velocity_min = %s" % f(e["velocity"][0]),
              "initial_velocity_max = %s" % f(e["velocity"][1]),
              "damping_min = %s" % f(e["damping"][0]),
              "damping_max = %s" % f(e["damping"][1]),
              "scale_amount_min = %s" % f(e["scale"][0]),
              "scale_amount_max = %s" % f(e["scale"][1]),
              'scale_amount_curve = SubResource("Curve_%d")' % i,
              'color_ramp = SubResource("Gradient_%d")' % i]
        nodes.append("\n".join(n) + "\n")
    head = '[gd_scene load_steps=%d format=3]\n' % (len(subs) + 1)
    root = '[node name="%s" type="Node3D"]\nmetadata/forge_spec_sha256 = "%s"\n' % (asset, spec_sha256(spec))
    return head + "\n" + "\n".join(subs) + "\n" + root + "\n" + "\n".join(nodes)
