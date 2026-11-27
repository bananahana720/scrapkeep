shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(1.0);
uniform bool vertex_tint = false;
uniform float metal = 0.0;
uniform float rough = 0.8;
uniform vec3 glow = vec3(0.0);
uniform vec3 lining : source_color = vec3(0.84, 0.79, 0.68);
uniform vec3 lining_frame : source_color = vec3(0.38, 0.42, 0.40);
uniform vec3 lining_hub : source_color = vec3(0.56, 0.35, 0.20);
uniform vec3 ink : source_color = vec3(0.14, 0.16, 0.16);
uniform float window = 0.76;
uniform float ink_width = 0.035;
uniform float fringe = 0.11;
uniform bool inside = false;
uniform bool held = false;
uniform vec3 centre_at = vec3(0.0);
uniform vec3 centre_local = vec3(0.0);
uniform vec4 paint_tint : source_color = vec4(1.0);
uniform vec4 lift : source_color = vec4(1.0);
uniform float paint_take = 0.0;
uniform vec3 enamel = vec3(1.0);
uniform float enamel_take = 0.0;
uniform float keep_within = 0.0;
uniform float tube = 0.0;
const float STANDS_OUT = 1.15;
uniform bool back_is_kit = false;
uniform float seat_back_top = 9.0;
uniform float back_above = -0.08;
uniform float back_behind = 0.05;
uniform bool plated = false;
uniform sampler2D plate : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float plate_scale = 0.667;

// Kest's mortar fuse (hero_assets.kest_fuse_material): its glow, dark at the tip once loaded.
uniform vec4 class_color : source_color = vec4(1.0);
uniform float strength = 0.5;
instance uniform float fuse_glow = 0.2;
instance uniform bool fuse_loaded = false;

varying vec3 local_pos;
varying vec3 local_normal;
varying vec3 world_normal;
varying float model_scale;
varying vec3 from_centre;
varying vec3 to_camera;
varying vec3 to_eye;

void vertex() {
	if (VERTEX.y > seat_back_top && VERTEX.y < -0.05 && abs(VERTEX.x) < 0.26 && VERTEX.z > 0.13 && VERTEX.z < 0.27) {
		VERTEX.y = seat_back_top;
	}
	local_pos = VERTEX;
	local_normal = NORMAL;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	model_scale = length(MODEL_MATRIX[0].xyz);
	vec3 centre = held ? centre_at : (MODEL_MATRIX * vec4(centre_local, 1.0)).xyz;
	from_centre = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - centre;
	to_camera = CAMERA_POSITION_WORLD - centre;
	to_eye = INV_VIEW_MATRIX[2].xyz;
}

void fragment() {
	float facing = dot(normalize(from_centre), normalize(to_camera));
	if (tube > 0.0) {
		vec3 axis = normalize(to_camera);
		float along = dot(from_centre, axis) / model_scale;
		float across = length(from_centre / model_scale - axis * along);
		facing = along > 0.0 ? sqrt(max(0.0, 1.0 - (across / tube) * (across / tube))) : -1.0;
	}
	vec3 seat_pos = local_pos - centre_local;
	bool cockpit = length(from_centre) < keep_within * model_scale;
	if (cockpit && back_is_kit && seat_pos.y > back_above && seat_pos.z > back_behind) {
		cockpit = false;
	}
	if (cockpit) {
		facing = -1.0;
	} else if (IN_SHADOW_PASS) {
		bool stands_out = tube > 0.0 && length(from_centre) > STANDS_OUT * model_scale;
		if (!stands_out && dot(normalize(from_centre), normalize(to_eye)) > 0.0) {
			discard;
		}
	} else if (facing > window) {
		discard;
	}
	vec3 base = tint.rgb;
	if (vertex_tint) {
		float takes = step(0.05, COLOR.a);
		vec3 own = mix(COLOR.rgb, enamel, enamel_take * takes);
		base *= mix(own * lift.rgb, paint_tint.rgb, paint_take * takes);
	}
	float rough_out = rough;
	if (plated) {
		vec3 weights = abs(normalize(local_normal));
		weights /= max(weights.x + weights.y + weights.z, 0.001);
		vec3 p = local_pos * plate_scale;
		base *= texture(plate, p.yz).rgb * weights.x + texture(plate, p.xz).rgb * weights.y + texture(plate, p.xy).rgb * weights.z;
	}
	vec3 emit = class_color.rgb * strength * (fuse_loaded && local_pos.x < 0.0 ? 0.0 : fuse_glow);
	float edge = window - ink_width;
	if (facing > edge) {
		base = ink;
		emit = vec3(0.0);
		rough_out = 0.92;
	} else if (facing > edge - fringe) {
		vec2 cell = fract(FRAGCOORD.xy / 6.5) - 0.5;
		float grow = (facing - (edge - fringe)) / fringe;
		float dot_mask = smoothstep(grow * 0.56 + 0.07, grow * 0.56 - 0.07, length(cell));
		base = mix(base, ink, dot_mask);
		emit *= (1.0 - dot_mask);
		rough_out = mix(rough_out, 0.92, dot_mask);
	}
	if (FRONT_FACING) {
		ALBEDO = base;
		METALLIC = metal;
		ROUGHNESS = rough_out;
		EMISSION = emit;
	} else {
		if (!inside) {
			discard;
		}
		vec3 n = normalize(local_pos - centre_local);
		float around = atan(n.y, n.z) / 6.2831853;
		float longeron = abs(fract(around * 6.0) - 0.5);
		float frame = min(abs(abs(n.x) - 0.42), abs(n.x));
		vec3 wall = mix(lining, lining * 0.88, step(0.5, fract(around * 6.0 + step(0.42, abs(n.x)) * 0.5)));
		float rib_mask = 1.0 - step(0.055, longeron) * step(0.035, frame);
		wall = mix(wall, lining_frame, rib_mask);
		wall = abs(n.x) > 0.93 ? (abs(n.x) > 0.96 ? lining_hub : lining_frame) : wall;
		ALBEDO = facing > edge ? ink : wall;
		EMISSION = facing > edge ? vec3(0.0) : wall * 0.12;
		ROUGHNESS = 0.92;
	}
}
