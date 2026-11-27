// Shared stochastic triplanar detail, macro variation, curvature, and micro-normal relief
// for Scrapkeep high-craft PBR surface shaders.
// No vertex displacement; all relief stays strictly in shading normals.

float craft_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 craft_hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float craft_hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float craft_noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = craft_hash12(i);
	float b = craft_hash12(i + vec2(1.0, 0.0));
	float c = craft_hash12(i + vec2(0.0, 1.0));
	float d = craft_hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float craft_noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = craft_hash13(i + vec3(0.0, 0.0, 0.0));
	float n100 = craft_hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = craft_hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = craft_hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = craft_hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = craft_hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = craft_hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = craft_hash13(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, u.x);
	float nx10 = mix(n010, n110, u.x);
	float nx01 = mix(n001, n101, u.x);
	float nx11 = mix(n011, n111, u.x);
	return mix(mix(nx00, nx10, u.y), mix(nx01, nx11, u.y), u.z);
}

float craft_fbm2(vec2 p) {
	float v = 0.0;
	float amp = 0.55;
	mat2 rot = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
	for (int i = 0; i < 3; i++) {
		v += craft_noise2(p) * amp;
		p = rot * p * 2.07 + vec2(17.1, 9.3);
		amp *= 0.45;
	}
	return v / 0.90875;
}

float craft_fbm3(vec3 p) {
	float v = craft_noise3(p) * 0.56;
	v += craft_noise3(p * 2.09 + vec3(13.7, 4.1, 8.9)) * 0.29;
	v += craft_noise3(p * 4.31 + vec3(2.3, 19.4, 5.7)) * 0.15;
	return v;
}

vec3 craft_triplanar_weights(vec3 world_normal, float sharpness) {
	vec3 w = pow(max(abs(world_normal), vec3(0.0001)), vec3(sharpness));
	return w / max(w.x + w.y + w.z, 0.0001);
}

// rotation_mode:
//   0 = continuous stochastic angle (best for organic concrete/floors, zero grid)
//   1 = 90-degree orthogonal rotations (preserves riveted panel geometry, breaks tiling)
//   2 = horizontal mirror/offset only (preserves vertical rain/soot streaks on walls)
vec4 craft_stochastic_sample(sampler2D tex, vec2 uv, float warp_strength, int rotation_mode) {
	vec2 duvdx = dFdx(uv);
	vec2 duvdy = dFdy(uv);
	vec2 cell_uv = uv * 0.5;
	vec2 cell = floor(cell_uv);
	vec2 f = fract(cell_uv);
	vec4 accum = vec4(0.0);
	float wsum = 0.0;

	for (int j = 0; j <= 1; j++) {
		for (int i = 0; i <= 1; i++) {
			vec2 g = cell + vec2(float(i), float(j));
			vec2 h = craft_hash22(g);
			mat2 rmat = mat2(vec2(1.0, 0.0), vec2(0.0, 1.0));
			if (rotation_mode == 0) {
				float ang = h.x * 6.2831853;
				float ca = cos(ang);
				float sa = sin(ang);
				rmat = mat2(vec2(ca, -sa), vec2(sa, ca));
			} else if (rotation_mode == 1) {
				float q = floor(h.x * 4.0) * 1.5707963;
				float ca = cos(q);
				float sa = sin(q);
				rmat = mat2(vec2(ca, -sa), vec2(sa, ca));
			} else {
				float sx = h.x > 0.5 ? -1.0 : 1.0;
				rmat = mat2(vec2(sx, 0.0), vec2(0.0, 1.0));
			}
			vec2 sample_uv = rmat * uv + h * 5.73;
			vec2 rdx = rmat * duvdx;
			vec2 rdy = rmat * duvdy;
			vec2 d = abs(f - vec2(float(i), float(j)));
			float w = (1.0 - smoothstep(0.0, 1.0, d.x)) * (1.0 - smoothstep(0.0, 1.0, d.y));
			w = w * w + 0.0001;
			accum += textureGrad(tex, sample_uv, rdx, rdy) * w;
			wsum += w;
		}
	}
	vec4 base_sample = accum / max(wsum, 0.0001);

	// Dual-scale domain-warped macro layer eliminates long-range repetition.
	vec2 warp = (vec2(craft_noise2(uv * 0.29 + vec2(3.1, 7.4)), craft_noise2(uv * 0.29 + vec2(11.3, 2.7))) - 0.5) * warp_strength;
	vec2 macro_uv = uv * 0.6180339 + vec2(0.37, 0.61) + warp;
	if (rotation_mode == 0) {
		mat2 grot = mat2(vec2(0.73736888, -0.67549029), vec2(0.67549029, 0.73736888));
		macro_uv = grot * (uv * 0.6180339) + warp;
	}
	vec4 macro_sample = textureGrad(tex, macro_uv, duvdx * 0.618, duvdy * 0.618);
	float blend = smoothstep(0.25, 0.75, craft_noise2(uv * 0.21 + vec2(5.7, 1.9)));
	return mix(base_sample, macro_sample, blend * 0.42);
}

vec3 craft_triplanar_stochastic(sampler2D tex, vec3 p, vec3 weights, float tile_metres, float warp_strength, int rotation_mode) {
	float inv_tile = 1.0 / max(tile_metres, 0.05);
	vec3 q = p * inv_tile;
	vec3 sx = craft_stochastic_sample(tex, q.zy, warp_strength, rotation_mode).rgb;
	vec3 sy = craft_stochastic_sample(tex, q.xz, warp_strength, rotation_mode == 2 ? 1 : rotation_mode).rgb;
	vec3 sz = craft_stochastic_sample(tex, q.xy, warp_strength, rotation_mode).rgb;
	return sx * weights.x + sy * weights.y + sz * weights.z;
}

float craft_luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Multi-scale procedural triplanar micro-grain height (used alongside or as fallback for textures).
float craft_procedural_detail(vec3 p, vec3 weights, float tile_metres) {
	float inv_tile = 1.0 / max(tile_metres, 0.05);
	vec3 q = p * inv_tile;
	float gx = craft_fbm2(q.zy * 4.5) * 0.6 + craft_noise2(q.zy * 14.0) * 0.4;
	float gy = craft_fbm2(q.xz * 4.5) * 0.6 + craft_noise2(q.xz * 14.0) * 0.4;
	float gz = craft_fbm2(q.xy * 4.5) * 0.6 + craft_noise2(q.xy * 14.0) * 0.4;
	return gx * weights.x + gy * weights.y + gz * weights.z;
}

// Screen-space geometric curvature estimator: highlights convex bevels automatically.
float craft_curvature(vec3 world_normal, vec3 world_pos) {
	vec3 dn_x = dFdx(world_normal);
	vec3 dn_y = dFdy(world_normal);
	vec3 dp_x = dFdx(world_pos);
	vec3 dp_y = dFdy(world_pos);
	float pos_step = max(length(dp_x) + length(dp_y), 0.0025);
	float norm_delta = length(dn_x) + length(dn_y);
	// Dot checks convexity vs concavity relative to tangent step.
	float convex = max(0.0, dot(dn_x, dp_x) + dot(dn_y, dp_y));
	float raw = (norm_delta / pos_step) * 0.085;
	return clamp(raw * smoothstep(0.0, 0.0004, convex + norm_delta * 0.002), 0.0, 1.0);
}

// Pixel-footprint fade so high-frequency normal relief never shimmers at long distance.
float craft_footprint_fade(vec3 world_pos, float near_footprint, float far_footprint) {
	float fp = max(length(dFdx(world_pos)), length(dFdy(world_pos)));
	return 1.0 - smoothstep(near_footprint, far_footprint, fp);
}

// Cotangent-frame screen-space derivative normal perturbation (view-space VERTEX / NORMAL).
vec3 craft_bump_normal(vec3 view_pos, vec3 view_normal, float height, float strength) {
	vec3 dx = dFdx(view_pos);
	vec3 dy = dFdy(view_pos);
	vec3 across_x = cross(dy, view_normal);
	vec3 across_y = cross(view_normal, dx);
	float det = dot(dx, across_x);
	float denom = sign(det) * max(abs(det), 0.00001);
	vec3 grad = (across_x * dFdx(height) + across_y * dFdy(height)) / (denom + 0.0000001);
	return normalize(view_normal - grad * strength);
}
