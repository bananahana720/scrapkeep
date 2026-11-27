shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(1.0);
uniform bool vertex_tint = false;
uniform float metal = 0.0;
uniform float rough = 0.8;
// Linear light, already multiplied by its energy.
uniform vec3 glow = vec3(0.0);
uniform vec3 lining : source_color = vec3(0.84, 0.79, 0.68);
// The inside of the plating is built, not bare: six longerons, two ring frames and a hub plate at
// each axle, in big shapes that still read at play size and show the roll.
uniform vec3 lining_frame : source_color = vec3(0.38, 0.42, 0.40);
uniform vec3 lining_hub : source_color = vec3(0.56, 0.35, 0.20);
uniform vec3 ink : source_color = vec3(0.14, 0.16, 0.16);
uniform vec3 rim_bone : source_color = vec3(0.824, 0.773, 0.647);
uniform vec3 rim_sky : source_color = vec3(0.769, 0.824, 0.910);
uniform float window = 0.76;
uniform float ink_width = 0.035;
uniform float fringe = 0.11;
// The plated ball has an inside, drawn as lining; anything else shows no back face.
uniform bool inside = false;
// A part that rides the ball away from its centre is told where the centre is each frame.
uniform bool held = false;
uniform vec3 centre_at = vec3(0.0);
// A part of the shell whose own origin is off the ball's centre: the centre in its own space.
uniform vec3 centre_local = vec3(0.0);
// hero_assets' equipped paint: the tint takes where the vertex alpha says paint.
uniform vec4 paint_tint : source_color = vec4(1.0);
uniform vec4 lift : source_color = vec4(1.0);
uniform float paint_take = 0.0;
// The pilot's own enamel on the plating's paint-taking gores, in the vertex colours' own space.
uniform vec3 enamel = vec3(1.0);
uniform float enamel_take = 0.0;
// The level part keeps what sits inside the ball (seat, controls): only what stands farther
// from the centre than this, in the model's own units, is cut.
uniform float keep_within = 0.0;
// ...except behind the pilot's back above the seat (the level part's own +Z and +Y past these),
// where only brackets and backrests stand: those count as outer kit at any distance.
// Kit is judged by the tube of sight the window opens (the plating's radius, in the model's
// units), not by its angle from the centre: a rod near the centre never reaches that angle, and
// a barrel that stands out past the ball reaches it while still beside the opening.
uniform float tube = 0.0;
const float STANDS_OUT = 1.15;
uniform bool back_is_kit = false;
// A small pilot's seat back is lowered to this height (the level part's own Y): every vertex of
// the seat back's slab above it is pressed down to it, so the back stays a closed box.
uniform float seat_back_top = 9.0;
uniform float back_above = -0.08;
uniform float back_behind = 0.05;
// hero_assets' plate map, laid on by the three axes as its own materials lay it.
uniform bool plated = false;
uniform sampler2D plate : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float plate_scale = 0.667;

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
		// In a light's pass the eye is the light. The half toward it is left out, so the sun
		// reaches the pilot; the far half still throws the whole round shadow on the ground.
		// Kit that stands out past the ball (a barrel) blocks no sun from the pilot and keeps
		// its whole shadow.
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
	float spec_out = 0.45;
	if (plated) {
		vec3 weights = abs(normalize(local_normal));
		weights /= max(weights.x + weights.y + weights.z, 0.001);
		vec3 p = local_pos * plate_scale;
		vec3 plate_tex = texture(plate, p.yz).rgb * weights.x + texture(plate, p.xz).rgb * weights.y + texture(plate, p.xy).rgb * weights.z;
		base *= plate_tex;
		// Rubbed ridges stay satin while recessed paint/oil blotches stay matte.
		float plate_luma = dot(plate_tex, vec3(0.299, 0.587, 0.114));
		rough_out = clamp(rough + (0.68 - plate_luma) * 0.28, 0.34, 0.96);
		spec_out = mix(0.38, 0.62, smoothstep(0.55, 0.90, plate_luma));
	}
	vec3 emit = glow;
	float edge = window - ink_width;
	bool on_ink = false;
	if (facing > edge) {
		base = ink;
		emit = vec3(0.0);
		rough_out = 0.92;
		on_ink = true;
	} else if (facing > edge - fringe) {
		// Subtle brushed-bone chamfer on the shoulder right outside the cutaway ink ring.
		float chamfer = smoothstep(edge - 0.018, edge - 0.002, facing);
		base = mix(base, rim_bone, chamfer * 0.48);
		rough_out = mix(rough_out, 0.46, chamfer);
		// Anti-aliased halftone dots that grow toward the ink line, fixed to the screen like print.
		vec2 cell = fract(FRAGCOORD.xy / 6.5) - 0.5;
		float grow = (facing - (edge - fringe)) / fringe;
		float dot_mask = smoothstep(grow * 0.56 + 0.07, grow * 0.56 - 0.07, length(cell));
		base = mix(base, ink, dot_mask);
		emit *= (1.0 - dot_mask);
		rough_out = mix(rough_out, 0.92, dot_mask);
	}
	if (FRONT_FACING) {
		if (!on_ink && !cockpit) {
			// Tight cool-sky Fresnel silhouette rim strictly on the outer crescent (ndv < 0.48):
			// keeps painted petrol/oxide gores saturated while cleanly separating even the dark lower
			// hemisphere off shadowed canyon floors.
			float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
			float crescent = clamp(1.0 - ndv / 0.48, 0.0, 1.0);
			float fresnel = crescent * crescent;
			float sky_facing = clamp(world_normal.y * 0.18 + 0.90, 0.78, 1.0);
			base = mix(base, rim_bone, fresnel * 0.28);
			emit += rim_sky * (fresnel * 0.46 * sky_facing);
		}
		ALBEDO = base;
		METALLIC = metal;
		ROUGHNESS = rough_out;
		SPECULAR = spec_out;
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
		// Subtle warm workshop bounce inside the open shell keeps the pilot silhouette crisp in shade.
		EMISSION = facing > edge ? vec3(0.0) : wall * 0.16;
		ROUGHNESS = 0.92;
	}
}
