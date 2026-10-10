"""Godot material text for a terrain asset. Stdlib only: entry.py writes it inside the
sandbox for the preview build, and promote.py regenerates it outside the sandbox from
this trusted copy, so recipe code can never choose what lands in the repo."""


PLACEHOLDER = "res://__FORGE_TEXTURES__"


def tres_text(asset, uv_scale=1.0, height_scale=0.0):
    """Godot 4 StandardMaterial3D text resource referencing the five maps by a placeholder
    res:// folder; promote rewrites PLACEHOLDER to the real folder. Normal maps use Godot's
    OpenGL (Y+) convention, matching normal_from_height. Height is attached but the
    (costly) parallax stays off unless height_scale > 0."""
    base = "%s/%s" % (PLACEHOLDER, asset)
    ids = [("albedo", "1_albedo"), ("normal", "2_normal"), ("roughness", "3_rough"), ("ao", "4_ao"), ("height", "5_height")]
    lines = ["[gd_resource type=\"StandardMaterial3D\" load_steps=%d format=3]" % (len(ids) + 1), ""]
    for kind, rid in ids:
        lines.append("[ext_resource type=\"Texture2D\" path=\"%s/%s_%s.png\" id=\"%s\"]" % (base, asset, kind, rid))
    lines += ["", "[resource]",
              "resource_name = \"%s\"" % asset,
              "albedo_texture = ExtResource(\"1_albedo\")",
              "roughness = 1.0",
              "roughness_texture = ExtResource(\"3_rough\")",
              "roughness_texture_channel = 0",
              "normal_enabled = true",
              "normal_texture = ExtResource(\"2_normal\")",
              "ao_enabled = true",
              "ao_texture = ExtResource(\"4_ao\")",
              "ao_texture_channel = 0",
              "heightmap_enabled = %s" % ("true" if height_scale > 0 else "false"),
              "heightmap_texture = ExtResource(\"5_height\")"]
    if height_scale > 0:
        lines.append("heightmap_scale = %.3f" % height_scale)
    lines += ["uv1_scale = Vector3(%g, %g, %g)" % (uv_scale, uv_scale, uv_scale),
              "texture_filter = 5", ""]
    return "\n".join(lines)
