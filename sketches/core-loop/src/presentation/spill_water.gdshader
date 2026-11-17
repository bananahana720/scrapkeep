shader_type spatial;
render_mode cull_disabled;
uniform bool falling = true;
// Horizontal drift (m/s) for water with no slope to run down; set where the surface is built.
uniform vec2 drift = vec2(0.0);
// 1.0, or less under reduced motion (SpillwayScenery.set_water_calm).
global uniform float water_flow_scale;
// SpillwayScenery.flow_at mirrors this flow; tests/water_flow_test.gd pins the two together.
const float FALL_SPEED = 2.4;
const float FLOW_PERIOD = 2.0;
varying vec3 at;
varying vec3 flow;
void vertex() {
 at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 vec3 n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
 float steep = sqrt(max(0.0, 1.0 - n.y*n.y));
 vec3 downhill = vec3(n.x*n.y, n.y*n.y - 1.0, n.z*n.y);
 flow = downhill * FALL_SPEED + vec3(drift.x, 0.0, drift.y) * (1.0 - steep);
}
vec3 shade(vec3 p) {
 float ribbons = sin(p.x*3.7+sin(p.y*0.23)+p.z*1.7)*0.5+0.5;
 float foam = pow(ribbons,6.0);
 float sheen = 0.5+0.5*sin(p.y*1.6+p.x*0.25);
 if (!falling) { foam = pow(0.5+0.5*sin(p.x*0.7+p.z*1.4+sin(p.x*0.2)),12.0); }
 return mix(vec3(0.065,0.23,0.24),vec3(0.63,0.81,0.76),foam*0.34+sheen*0.24+(falling ? 0.25 : 0.0));
}
void fragment() {
 // Two phases a half period apart, each faded out where it wraps, so the pattern runs with the
 // water for ever without stretching where neighbouring faces run at different speeds.
 float phase = fract(TIME * water_flow_scale / FLOW_PERIOD);
 float other = fract(phase + 0.5);
 float weight = 1.0 - abs(1.0 - 2.0*phase);
 ALBEDO = mix(shade(at - flow*other*FLOW_PERIOD), shade(at - flow*phase*FLOW_PERIOD), weight);
 ROUGHNESS = 0.27;
 METALLIC = 0.12;
}
