shader_type spatial;
render_mode diffuse_burley;
uniform bool cliff_only = false;
// Anchor the pattern in the mesh's own metres (Moss's carried shelter) instead of world metres.
uniform bool local_pattern = false;
uniform sampler2D strata_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D floor_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float strata_metres = 6.0;
uniform float floor_metres = 5.0;
varying vec3 world_at;
varying vec3 world_normal;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float grain(vec3 p) {
 vec3 i = floor(p); vec3 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
// World-space triplanar: each axis projects the map, weighted by how squarely the surface faces it.
vec3 triplanar(sampler2D map, vec3 p, vec3 w, float metres) {
 vec3 q = p / metres;
 return texture(map, q.zy).rgb*w.x + texture(map, q.xz).rgb*w.y + texture(map, q.xy).rgb*w.z;
}
void vertex() {
 world_at = local_pattern ? VERTEX : (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = local_pattern ? normalize(NORMAL) : normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 vec3 p = world_at;
 vec3 weights = pow(abs(world_normal), vec3(4.0)); weights /= max(dot(weights,vec3(1.0)),0.001);
 // Macro variation: two octaves of broad noise, tens of metres across, so no tile repeats evenly.
 float macro = grain(p*0.031)*0.65 + grain(p*0.11+vec3(7.3,1.9,4.1))*0.35;
 float swap = smoothstep(0.38,0.62,grain(p*0.047+vec3(3.1,0.0,5.7)));
 // Rock: the palette-quantised CC0 map at two scales, one rotated off the other, mixed by the macro field.
 vec3 rock_near = triplanar(strata_map, p, weights, strata_metres);
 vec3 rock_far = triplanar(strata_map, p + vec3(13.1,7.7,3.3), weights, strata_metres*2.7);
 vec3 rock_mean = textureLod(strata_map, vec2(0.5), 10.0).rgb;
 vec3 rock = mix(rock_near, rock_far, swap);
 rock = mix(rock_mean, rock, 0.7) * (vec3(0.57,0.38,0.21) / max(rock_mean, vec3(0.02))) * (0.86 + macro*0.28);
 float strata = cliff_only ? 1.0 : 1.0-smoothstep(0.58,0.93,abs(world_normal.y));
 // A broad, irregular abrasion field suggests repeated rolling without drawing new routes.
 float track = sin(p.z*0.065+p.x*0.026)*9.0;
 float ruts = pow(0.5+0.5*sin((p.x+track)*4.2),18.0);
 float worn = smoothstep(0.40,0.68,grain(vec3(p.x*0.026,0.0,p.z*0.009)));
 vec3 floor_near = texture(floor_map, p.xz / floor_metres).rgb;
 vec3 floor_far = texture(floor_map, p.zx / (floor_metres*3.1) + vec2(0.37,0.61)).rgb;
 vec3 floor_tex = mix(floor_near, floor_far, swap*0.6);
 vec3 sand = floor_tex * (COLOR.rgb / vec3(0.82,0.77,0.65)) * (0.95+macro*0.08-worn*ruts*0.08);
 float damp = smoothstep(200.0,214.0,p.z)*(1.0-smoothstep(29.0,39.0,p.y));
 ALBEDO = mix(sand,rock,strata) * (1.0-damp*0.26);
 ROUGHNESS = 0.94;
 // Normal relief only: vertex positions and physics stay identical.
 vec3 dx = dFdx(VERTEX); vec3 dy = dFdy(VERTEX);
 float relief = strata*dot(rock_near, vec3(0.3,0.59,0.11))*0.05+(1.0-strata)*ruts*worn*0.008;
 NORMAL = normalize(NORMAL - normalize(dx)*dFdx(relief)*3.0 - normalize(dy)*dFdy(relief)*3.0);
}
