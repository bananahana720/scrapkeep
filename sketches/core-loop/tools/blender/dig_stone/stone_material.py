"""Build the single stone resource from the vendored, unmerged shared-bed method."""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKETCH = HERE.parents[2]


def build():
    bed = (HERE / "target_bed4.gdshaderinc").read_text()
    body = '''
instance uniform vec4 hollow = vec4(0.0);
varying vec3 surface_at;
varying vec3 surface_normal;
varying vec3 local_at;
void vertex() {
    surface_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
    local_at = VERTEX;
}
void fragment() {
    vec3 p = surface_at;
    vec3 n = normalize(surface_normal);
    float footprint = max(length(dFdx(p)), length(dFdy(p)));
    float edge_fade = 1.0 - smoothstep(0.03, 0.14, footprint);
    float varn_w = 1.0 - smoothstep(0.30, 0.55, n.y);
    Bed4 bed = bed4_eval(p, n, length(p - INV_VIEW_MATRIX[3].xyz), edge_fade, varn_w);
    vec3 col = mix(bed.wall, bed.flat_c, smoothstep(0.50, 0.66, n.y));
    col *= COLOR.rgb;
    if (hollow.z > 0.0) {
        float side = 1.0 - smoothstep(hollow.x * 0.8, hollow.x, abs(local_at.x));
        float under = 1.0 - smoothstep(hollow.w * 0.8, hollow.w, local_at.y);
        float behind = smoothstep(hollow.y + 0.8, hollow.y + 2.0, local_at.z);
        col *= mix(1.0, 0.3, side * under * behind * hollow.z);
    }
    ALBEDO = col;
    ROUGHNESS = 0.95;
}
'''
    shader = "shader_type spatial;\nrender_mode diffuse_burley;\n" + bed + body
    path = SKETCH / "assets/materials/dig_stone/stone.tres"
    path.parent.mkdir(parents=True, exist_ok=True)
    text = '''[gd_resource type="ShaderMaterial" load_steps=4 format=3]

[ext_resource type="Texture2D" path="res://assets/textures/sandstone-strata.webp" id="1_tone"]
[ext_resource type="Texture2D" path="res://assets/textures/packed-sand-floor.webp" id="2_grain"]

[sub_resource type="Shader" id="Shader_stone"]
code = %s

[resource]
resource_name = "stone"
shader = SubResource("Shader_stone")
shader_parameter/tex_tone = ExtResource("1_tone")
shader_parameter/tex_grain = ExtResource("2_grain")
shader_parameter/bed_seed = 3.0
shader_parameter/bed_widen = 1.0
shader_parameter/tone_amp = 0.18
shader_parameter/varnish_color = Color(0.45, 0.37, 0.28, 1)
shader_parameter/flat_color = Color(0.7764706, 0.6352941, 0.454902, 1)
shader_parameter/bed_tan = Color(0.7764706, 0.6352941, 0.454902, 1)
shader_parameter/bed_orange = Color(0.721, 0.576, 0.411, 1)
shader_parameter/bed_cream = Color(0.8235294, 0.772549, 0.6470588, 1)
shader_parameter/bed_rust = Color(0.696, 0.55, 0.385, 1)
''' % json.dumps(shader)
    path.write_text(text)
    print("MDS_MATERIAL", path)


if __name__ == "__main__":
    build()
