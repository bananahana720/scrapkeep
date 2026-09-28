shader_type spatial;
render_mode diffuse_burley;
uniform bool cliff_only = false;
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
void vertex() {
 world_at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 vec3 p = world_at;
 vec3 weights = pow(abs(world_normal), vec3(4.0)); weights /= max(dot(weights,vec3(1.0)),0.001);
 float texture_grain = dot(weights, vec3(grain(vec3(p.yz*2.1,0.0)),grain(vec3(p.xz*2.1,0.0)),grain(vec3(p.xy*2.1,0.0))));
 float erosion = grain(p*0.13);
 float bed = p.y*0.39 + sin(p.x*0.073+p.z*0.052)*1.25 + erosion*1.7;
 float lip = smoothstep(0.68,0.83,fract(bed)) * (1.0-smoothstep(0.88,0.98,fract(bed)));
 float broad = 0.5+0.5*sin(bed*1.51);
 vec3 rock = mix(vec3(0.42,0.245,0.13),vec3(0.72,0.51,0.29),broad*0.22+erosion*0.78);
 rock *= 0.92 + texture_grain*0.16 - lip*0.13;
 float strata = cliff_only ? 1.0 : 1.0-smoothstep(0.58,0.93,abs(world_normal.y));
 // A broad, irregular abrasion field suggests repeated rolling without drawing new routes.
 float track = sin(p.z*0.065+p.x*0.026)*9.0;
 float ruts = pow(0.5+0.5*sin((p.x+track)*4.2),18.0);
 float worn = smoothstep(0.40,0.68,grain(vec3(p.x*0.026,0.0,p.z*0.009)));
 vec3 floor_tex = texture(floor_map, p.xz / floor_metres).rgb;
 vec3 sand = floor_tex * (COLOR.rgb / vec3(0.82,0.77,0.65)) * (0.97+texture_grain*0.05-worn*ruts*0.08);
 float damp = smoothstep(200.0,214.0,p.z)*(1.0-smoothstep(29.0,39.0,p.y));
 ALBEDO = mix(sand,rock,strata) * (1.0-damp*0.26);
 ROUGHNESS = 0.94;
 // Normal relief only: vertex positions and physics stay identical.
 vec3 dx = dFdx(VERTEX); vec3 dy = dFdy(VERTEX);
 float relief = strata*(lip*0.025+texture_grain*0.018)+(1.0-strata)*ruts*worn*0.008;
 NORMAL = normalize(NORMAL - normalize(dx)*dFdx(relief)*3.0 - normalize(dy)*dFdy(relief)*3.0);
}
