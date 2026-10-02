shader_type spatial;
render_mode cull_disabled;
uniform bool falling = true;
varying vec3 at;
void vertex() { at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float ribbons = sin(at.x*3.7+sin(at.y*0.23)+at.z*1.7)*0.5+0.5;
 float foam = pow(ribbons,6.0);
 float flow = 0.5+0.5*sin(at.y*1.6+at.x*0.25);
 if (!falling) { foam = pow(0.5+0.5*sin(at.x*0.7+at.z*1.4+sin(at.x*0.2)),12.0); }
 ALBEDO = mix(vec3(0.065,0.23,0.24),vec3(0.63,0.81,0.76),foam*0.34+flow*0.24+(falling ? 0.25 : 0.0));
 ROUGHNESS = 0.27;
 METALLIC = 0.12;
}
