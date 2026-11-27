extends SceneTree


const OffscreenWindow := preload("res://tools/offscreen_window.gd")
const Palette := preload("res://src/core/palette.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const PilotReactions := preload("res://src/presentation/pilot_reactions.gd")
const PilotGlance := preload("res://src/presentation/pilot_glance.gd")
const PilotLiveliness := preload("res://src/presentation/pilot_liveliness.gd")
const PilotGearKit := preload("res://src/presentation/pilot_gear_kit.gd")
const AppShell := preload("res://src/core/app_shell.gd")

const SIZE := Vector2i(1600, 900)

const GEAR_SHADED_CODE := """
shader_type spatial;
render_mode cull_back;

uniform vec3 base_albedo : source_color = vec3(0.45, 0.35, 0.25);
uniform vec3 edge_albedo : source_color = vec3(0.84, 0.78, 0.65);
uniform vec3 grime_albedo : source_color = vec3(0.11, 0.12, 0.11);
uniform vec3 emit_albedo : source_color = vec3(0.55, 0.94, 0.83);
uniform float base_roughness = 0.74;
uniform float base_metallic = 0.28;
uniform float emit_energy = 2.4;

void fragment() {
	float wear = clamp(COLOR.r, 0.0, 1.0);
	float grime = clamp(COLOR.g, 0.0, 1.0);
	float emit_mask = clamp(COLOR.b, 0.0, 1.0);
	vec3 col = mix(base_albedo, grime_albedo, grime * 0.72);
	col = mix(col, edge_albedo, smoothstep(0.45, 0.92, wear) * 0.56);
	col = mix(col, emit_albedo * 0.4, emit_mask);
	ALBEDO = col;
	ROUGHNESS = clamp(mix(base_roughness, 0.42, smoothstep(0.45, 0.92, wear)) + grime * 0.14, 0.32, 0.96);
	METALLIC = mix(base_metallic, 0.68, smoothstep(0.50, 0.92, wear)) * (1.0 - grime * 0.7);
	SPECULAR = 0.38;
	EMISSION = emit_albedo * emit_mask * emit_energy;
}
"""

const MASK_CODE := """
shader_type spatial;
render_mode unshaded, cull_back;
void fragment() {
	ALBEDO = COLOR.rgb;
}
"""

var _out := ""
var _stage: Node3D
var _cam: Camera3D
var _env: Environment
var _floor_mat: StandardMaterial3D
var _painter
var _gear_shader: Shader
var _mask_shader: Shader


func _initialize() -> void:
	OffscreenWindow.apply(root)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty() or AppShell.headless():
		printerr("pilot_liveliness_capture: needs Metal display and -- --out=<absolute dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	if DisplayServer.get_name().to_lower() != "embedded":
		root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _build_stage() -> void:
	_stage = Node3D.new()
	root.add_child(_stage)

	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("4f5458")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.DAWN_VIOLET.lerp(Palette.SAND, 0.55)
	env.ambient_light_energy = 0.68
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.06
	env.tonemap_agx_white = 16.29
	env.tonemap_agx_contrast = 1.20
	env.ssao_enabled = true
	env.ssao_radius = 0.65
	env.ssao_intensity = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.34
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.35
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, 28.0, 0.0)
	key.light_color = Palette.APRICOT.lerp(Color.WHITE, 0.62)
	key.light_energy = 1.75
	key.shadow_enabled = true
	_stage.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-22.0, -148.0, 0.0)
	rim.light_color = Palette.TURQUOISE.lerp(Color.WHITE, 0.30)
	rim.light_energy = 0.85
	_stage.add_child(rim)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40.0, 40.0)
	var floor_inst := MeshInstance3D.new()
	floor_inst.mesh = floor_mesh
	floor_inst.position = Vector3(0.0, -0.45, 0.0)
	var floor_mat := StandardMaterial3D.new()
	_floor_mat = floor_mat
	floor_mat.albedo_color = Color("494d50")
	floor_mat.roughness = 0.94
	floor_inst.material_override = floor_mat
	_stage.add_child(floor_inst)

	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.far = 100.0
	_cam.fov = 34.0
	_stage.add_child(_cam)
	_cam.make_current()

	_painter = HeroAssets.new()
	_stage.add_child(_painter)


func _gear_mat(slot: String, accent: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _gear_shader
	match slot:
		"brass_trim":
			m.set_shader_parameter("base_albedo", Palette.COPPER.lerp(Palette.BRASS, 0.42))
			m.set_shader_parameter("base_roughness", 0.56)
			m.set_shader_parameter("base_metallic", 0.52)
		"iron_hardware":
			m.set_shader_parameter("base_albedo", Palette.CHARCOAL.lerp(Palette.STEEL, 0.40))
			m.set_shader_parameter("base_roughness", 0.68)
			m.set_shader_parameter("base_metallic", 0.44)
		"strap_leather":
			m.set_shader_parameter("base_albedo", Palette.RUST.darkened(0.32))
			m.set_shader_parameter("base_roughness", 0.86)
			m.set_shader_parameter("base_metallic", 0.05)
		"emissive_dial":
			m.set_shader_parameter("base_albedo", accent)
			m.set_shader_parameter("emit_albedo", accent)
			m.set_shader_parameter("emit_energy", 2.6)
			m.set_shader_parameter("base_roughness", 0.30)
			m.set_shader_parameter("base_metallic", 0.05)
		_:
			m.set_shader_parameter("base_albedo", Palette.STEEL)
	if slot != "emissive_dial":
		m.set_shader_parameter("emit_albedo", accent)
	return m


func _apply_weathering_preview(node: Node, accent: Color) -> void:
	var list: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		list.append(node)
	for mi in list:
		var inst := mi as MeshInstance3D
		if inst != null and inst.mesh is ArrayMesh:
			var am := inst.mesh as ArrayMesh
			for s in am.get_surface_count():
				var sname := am.surface_get_name(s)
				if sname in ["brass_trim", "iron_hardware", "strap_leather", "emissive_dial"]:
					inst.set_surface_override_material(s, _gear_mat(sname, accent))


func _spawn_pilot_unit(parent: Node3D, class_id: String, pos: Vector3, yaw_deg: float, with_wearables := true, with_cockpit := true) -> Dictionary:
	var pod := Node3D.new()
	pod.name = "Pod_" + class_id
	pod.position = pos
	pod.rotation_degrees.y = yaw_deg
	parent.add_child(pod)

	var def = ClassDef.by_id(class_id)
	var accent: Color = def.color if def != null else Palette.ARC
	var fitted: Dictionary = _painter.fit_pilot_into(pod, class_id, accent)
	var pilot: Node3D = fitted.pilot
	var animator: AnimationPlayer = fitted.animator
	if animator != null:
		animator.stop()
	for sk in pilot.find_children("*", "Skeleton3D", true, false):
		(sk as Skeleton3D).reset_bone_poses()
	var glance := PilotGlance.seat(pilot, class_id)
	var live = PilotLiveliness.attach(pilot, class_id)
	live.reduced_motion_override = 0
	var wearables := {}
	var cockpit := {}
	if with_wearables:
		wearables = PilotGearKit.mount_pilot_wearables(pilot, accent)
		_apply_weathering_preview(pilot, accent)
	if with_cockpit:
		cockpit = PilotGearKit.mount_cockpit_rig(pod, accent)
		_apply_weathering_preview(cockpit.root, accent)
		live.bind_cockpit_controls(cockpit)
	return {"pod": pod, "pilot": pilot, "animator": animator, "glance": glance, "live": live, "wearables": wearables, "cockpit": cockpit}


func _grab_image(eye: Vector3, target: Vector3, fov_deg := 34.0, settle_frames := 8) -> Image:
	_cam.fov = fov_deg
	_cam.look_at_from_position(eye, target)
	for _i in settle_frames:
		await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


func _shot(filename: String, eye: Vector3, target: Vector3, fov_deg := 34.0) -> Image:
	var img := await _grab_image(eye, target, fov_deg, 10)
	var path := _out.path_join(filename)
	if img.save_png(path) != OK:
		printerr("pilot_liveliness_capture: failed to save ", path)
		quit(3)
	return img


static func _make_greyscale(src: Image) -> Image:
	var dst := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			var lr := pow(c.r, 2.2)
			var lg := pow(c.g, 2.2)
			var lb := pow(c.b, 2.2)
			var lum := clampf(0.2126 * lr + 0.7152 * lg + 0.0722 * lb, 0.0, 1.0)
			var s := pow(lum, 1.0 / 2.2)
			dst.set_pixel(x, y, Color(s, s, s, 1.0))
	return dst


static func _make_machado_deuteranopia(src: Image) -> Image:
	var dst := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			var r := pow(c.r, 2.2)
			var g := pow(c.g, 2.2)
			var b := pow(c.b, 2.2)
			var nr := clampf(0.367322 * r + 0.860646 * g - 0.227968 * b, 0.0, 1.0)
			var ng := clampf(0.280085 * r + 0.672501 * g + 0.047413 * b, 0.0, 1.0)
			var nb := clampf(-0.011820 * r + 0.042940 * g + 0.968881 * b, 0.0, 1.0)
			dst.set_pixel(x, y, Color(pow(nr, 1.0 / 2.2), pow(ng, 1.0 / 2.2), pow(nb, 1.0 / 2.2), 1.0))
	return dst


static func _crop_center(src: Image, crop_w: int, crop_h: int) -> Image:
	var cw := mini(crop_w, src.get_width())
	var ch := mini(crop_h, src.get_height())
	var x0 := int(floor(float(src.get_width() - cw) * 0.5))
	var y0 := int(floor(float(src.get_height() - ch) * 0.5))
	return src.get_region(Rect2i(x0, y0, cw, ch))


func _capture_60hz_motion_strip() -> void:
	var strip_root := Node3D.new()
	_stage.add_child(strip_root)
	var u := _spawn_pilot_unit(strip_root, "demolitions_caster", Vector3.ZERO, 168.0)
	var skel := (u.pilot as Node3D).find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var yoke_node := u.cockpit.yoke as Node3D
	var hand_l := skel.find_bone("hand.L")
	var hand_r := skel.find_bone("hand.R")
	var prev_rots: Array[Quaternion] = []
	var bcount := skel.get_bone_count()
	var frames: Array[Image] = []
	var sample_ts := [0, 1, 2, 4, 8, 16]
	var worst_vel := 0.0
	var worst_hand_err := 0.0

	for f in 17:
		if f == 1:
			u.live.trigger_recoil(0.65)
		var arc := float(f) / 16.0
		var vel := Vector3(1.8 + 2.4 * arc, 0.0, -14.0 - 4.0 * arc)
		var turn := 1.4 + 2.2 * arc
		var aim := Vector3(0.20 + 0.32 * arc, 0.06 + 0.08 * arc, -0.92).normalized()
		u.live.step_motion(1.0 / 60.0, vel, turn, aim, 0.0, 0.0)

		skel.reset_bone_poses()
		u.live._process_modification()
		var cur_rots: Array[Quaternion] = []
		cur_rots.resize(bcount)
		var frame_vel := 0.0
		for bi in bcount:
			var q := skel.get_bone_pose_rotation(bi)
			cur_rots[bi] = q
			if f > 0:
				frame_vel = maxf(frame_vel, rad_to_deg(prev_rots[bi].angle_to(q)))
		prev_rots = cur_rots
		worst_vel = maxf(worst_vel, frame_vel)

		var yxf := yoke_node.global_transform
		var err_l := (skel.global_transform * skel.get_bone_global_pose(hand_l).origin).distance_to(yxf * PilotGearKit.YOKE_GRIP_LOCAL_L)
		var err_r := (skel.global_transform * skel.get_bone_global_pose(hand_r).origin).distance_to(yxf * PilotGearKit.YOKE_GRIP_LOCAL_R)
		worst_hand_err = maxf(worst_hand_err, maxf(err_l, err_r))

		if f in sample_ts:
			var shot := await _grab_image(Vector3(0.18, 0.56, 2.02), Vector3(0.0, 0.02, -0.08), 32.0, 4)
			frames.append(shot)
			print("STRIP_60HZ t=%d max_ang_vel=%.2fdeg/f hand_L_err=%.1fmm hand_R_err=%.1fmm" % [f, frame_vel, err_l * 1000.0, err_r * 1000.0])

	var sheet := Image.create(1600, 900, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("23272a"))
	var tile_w := 524
	var tile_h := 440
	for idx in frames.size():
		var col := idx % 3
		var row := int(floor(float(idx) / 3.0))
		var cropped := _crop_center(frames[idx], 1060, 890)
		cropped.resize(tile_w, tile_h, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(cropped, Rect2i(0, 0, tile_w, tile_h), Vector2i(8 + col * (tile_w + 6), 8 + row * (tile_h + 6)))
	sheet.save_png(_out.path_join("pilot_60hz_motion_strip.png"))
	print("STRIP_60HZ_SUMMARY frames=6 worst_vel=%.2fdeg/f worst_hand_err=%.1fmm" % [worst_vel, worst_hand_err * 1000.0])
	strip_root.queue_free()
	await process_frame


func _capture_play_distance_and_cvd() -> void:
	var prev_bg := _env.background_color
	var prev_floor := _floor_mat.albedo_color
	_env.background_color = Palette.DAWN_VIOLET.lerp(Palette.APRICOT, 0.42)
	_floor_mat.albedo_color = Palette.SAND.lerp(Palette.COPPER, 0.24)

	var play_root := Node3D.new()
	_stage.add_child(play_root)

	var preview_painter := HeroAssets.previewing()
	play_root.add_child(preview_painter)

	var ball := Node3D.new()
	ball.name = "PlayBall"
	ball.position = Vector3(0.0, 0.55, 0.0)
	ball.rotation_degrees.y = 148.0
	play_root.add_child(ball)

	var def = ClassDef.by_id("pylon_engineer")
	var accent: Color = def.color if def != null else Palette.ARC
	var shell: Dictionary = preview_painter.fit_shell_into(ball, "pylon_engineer", "", 1, {"class": accent})
	var pod: Node3D = shell.get("pod", ball)
	var fitted: Dictionary = preview_painter.fit_pilot_into(pod, "pylon_engineer", accent)
	var pilot_node: Node3D = fitted.pilot
	for ap in pod.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).stop()
	for sk in pod.find_children("*", "Skeleton3D", true, false):
		(sk as Skeleton3D).reset_bone_poses()

	var live = PilotLiveliness.attach(pilot_node, "pylon_engineer")
	if live != null:
		live.reduced_motion_override = 0
		var _wearables := PilotGearKit.mount_pilot_wearables(pilot_node, accent)
		var cockpit := PilotGearKit.mount_cockpit_rig(pod, accent)
		_apply_weathering_preview(pilot_node, accent)
		_apply_weathering_preview(cockpit.root, accent)
		live.bind_cockpit_controls(cockpit)
		for _k in 42:
			live.step_motion(1.0 / 60.0, Vector3(3.2, 0.0, -16.0), 2.8, Vector3(0.55, 0.08, -0.82).normalized(), 0.0, 0.0)

	var target := Vector3(0.0, 0.62, 0.0)
	var dir_7_5 := Vector3(0.0, 0.42, 0.9075).normalized()
	var eye_7_5 := target + dir_7_5 * 7.5
	var img_7_5 := await _shot("pilot_play_distance_7_5m.png", eye_7_5, target, 42.0)

	var eye_10_5 := target + dir_7_5 * 10.5
	await _shot("pilot_play_distance_10_5m.png", eye_10_5, target, 42.0)

	var down_720 := img_7_5.duplicate() as Image
	down_720.resize(1280, 720, Image.INTERPOLATE_BILINEAR)
	var crop_720 := _crop_center(down_720, 420, 420)
	var crop_grey := _make_greyscale(crop_720)
	var crop_cvd := _make_machado_deuteranopia(crop_720)

	var panel_w := 520
	var panel_h := 520
	crop_720.resize(panel_w, panel_h, Image.INTERPOLATE_NEAREST)
	crop_grey.resize(panel_w, panel_h, Image.INTERPOLATE_LANCZOS)
	crop_cvd.resize(panel_w, panel_h, Image.INTERPOLATE_LANCZOS)

	var cvd_sheet := Image.create(1600, 560, false, Image.FORMAT_RGBA8)
	cvd_sheet.fill(Color("1c2023"))
	cvd_sheet.blit_rect(crop_720, Rect2i(0, 0, panel_w, panel_h), Vector2i(14, 20))
	cvd_sheet.blit_rect(crop_grey, Rect2i(0, 0, panel_w, panel_h), Vector2i(540, 20))
	cvd_sheet.blit_rect(crop_cvd, Rect2i(0, 0, panel_w, panel_h), Vector2i(1066, 20))
	cvd_sheet.save_png(_out.path_join("pilot_play_distance_cvd_grey.png"))

	play_root.queue_free()
	_env.background_color = prev_bg
	_floor_mat.albedo_color = prev_floor
	await process_frame


func _run() -> void:
	_gear_shader = Shader.new()
	_gear_shader.code = GEAR_SHADED_CODE
	_mask_shader = Shader.new()
	_mask_shader.code = MASK_CODE
	var mask_mat := ShaderMaterial.new()
	mask_mat.shader = _mask_shader

	_build_stage()

	var lineup_root := Node3D.new()
	_stage.add_child(lineup_root)
	var u_sable := _spawn_pilot_unit(lineup_root, "pylon_engineer", Vector3(-1.35, 0.0, 0.0), 162.0)
	var u_rivet := _spawn_pilot_unit(lineup_root, "runner_gunner", Vector3(0.0, 0.0, 0.0), 162.0)
	var u_kest := _spawn_pilot_unit(lineup_root, "demolitions_caster", Vector3(1.35, 0.0, 0.0), 162.0)
	for u in [u_sable, u_rivet, u_kest]:
		u.live.step_motion(0.016, Vector3.ZERO, 0.0, Vector3.FORWARD, 0.0, 0.0)
	await _shot("pilot_rest_audit_lineup.png", Vector3(0.0, 0.55, 3.85), Vector3(0.0, 0.02, -0.05), 32.0)
	lineup_root.queue_free()
	await process_frame

	var poses_root := Node3D.new()
	_stage.add_child(poses_root)
	var p_a := _spawn_pilot_unit(poses_root, "pylon_engineer", Vector3(-1.86, 0.0, 0.0), 156.0)
	for _k in 35:
		p_a.live.step_motion(1.0 / 60.0, Vector3.ZERO, 0.0, Vector3.FORWARD, 0.0, 0.0)
	var p_b := _spawn_pilot_unit(poses_root, "pylon_engineer", Vector3(-0.62, 0.0, 0.0), 156.0)
	for _k in 45:
		p_b.live.step_motion(1.0 / 60.0, Vector3(4.0, 0.0, -18.0), 3.6, Vector3(0.65, 0.12, -0.75).normalized(), 0.0, 0.0)
	var p_c := _spawn_pilot_unit(poses_root, "demolitions_caster", Vector3(0.62, 0.0, 0.0), 156.0)
	p_c.live.trigger_recoil(2.0)
	p_c.live.trigger_reaction("player_hit")
	for _k in 5:
		p_c.live.step_motion(1.0 / 60.0, Vector3(0.0, 0.0, -14.0), -0.6, Vector3(-0.35, 0.25, -0.90).normalized(), 0.0, 0.0)
	var p_d := _spawn_pilot_unit(poses_root, "runner_gunner", Vector3(1.86, 0.0, 0.0), 156.0)
	p_d.live.trigger_landing(1.8)
	for _k in 7:
		p_d.live.step_motion(1.0 / 60.0, Vector3(-3.0, -4.0, -14.0), -2.4, Vector3(-0.5, -0.18, -0.84).normalized(), -22.0, 0.0)
	await _shot("pilot_liveliness_poses.png", Vector3(0.0, 0.62, 4.95), Vector3(0.0, 0.05, -0.05), 32.0)
	poses_root.queue_free()
	await process_frame

	var close_root := Node3D.new()
	_stage.add_child(close_root)
	var c_sable := _spawn_pilot_unit(close_root, "pylon_engineer", Vector3(-0.62, 0.0, 0.0), 146.0)
	var c_kest := _spawn_pilot_unit(close_root, "demolitions_caster", Vector3(0.62, 0.0, 0.0), 152.0)
	for _k in 40:
		c_sable.live.step_motion(1.0 / 60.0, Vector3(3.0, 0.0, -15.0), 2.8, Vector3(0.55, 0.08, -0.82).normalized(), 0.0, 0.0)
		c_kest.live.step_motion(1.0 / 60.0, Vector3(-2.5, 0.0, -14.0), -2.4, Vector3(-0.48, 0.14, -0.86).normalized(), 0.0, 0.0)
	await _shot("pilot_cockpit_portrait.png", Vector3(0.0, 0.36, 2.35), Vector3(0.0, 0.04, -0.12), 32.0)
	close_root.queue_free()
	await process_frame

	var kit_root := Node3D.new()
	_stage.add_child(kit_root)
	var specs := [
		{"id": PilotGearKit.GEAR_GOGGLES, "pos": Vector3(-0.76, 0.25, 0.0), "rot": Vector3(8.0, 158.0, 0.0), "scale": 1.65, "accent": Palette.ARC},
		{"id": PilotGearKit.GEAR_HARNESS, "pos": Vector3(0.0, 0.24, 0.0), "rot": Vector3(8.0, 158.0, 0.0), "scale": 1.35, "accent": Palette.COPPER},
		{"id": PilotGearKit.GEAR_BELT, "pos": Vector3(0.76, 0.24, 0.0), "rot": Vector3(12.0, 154.0, 0.0), "scale": 1.25, "accent": Palette.AMBER},
		{"id": PilotGearKit.GEAR_YOKE, "pos": Vector3(-0.72, -0.26, 0.0), "rot": Vector3(10.0, 156.0, 0.0), "scale": 1.15, "accent": Palette.ARC},
		{"id": PilotGearKit.GEAR_GAUGES, "pos": Vector3(0.10, -0.18, 0.0), "rot": Vector3(12.0, -24.0, 0.0), "scale": 1.60, "accent": Palette.ARC},
		{"id": PilotGearKit.GEAR_PEDAL, "pos": Vector3(0.82, -0.08, 0.0), "rot": Vector3(8.0, -28.0, 0.0), "scale": 2.0, "accent": Palette.AMBER},
	]
	var kit_nodes: Array[MeshInstance3D] = []
	for sp in specs:
		var mi := MeshInstance3D.new()
		mi.mesh = PilotGearKit.build_gear(sp.id)
		mi.position = sp.pos
		mi.rotation_degrees = sp.rot
		mi.scale = Vector3.ONE * float(sp.scale)
		_apply_weathering_preview(mi, sp.accent)
		kit_root.add_child(mi)
		kit_nodes.append(mi)
	await _shot("pilot_gear_kit_showcase.png", Vector3(0.0, 0.14, 3.05), Vector3(0.02, 0.02, 0.0), 30.0)

	for mi in kit_nodes:
		mi.material_override = mask_mat
	await _shot("pilot_gear_kit_masks.png", Vector3(0.0, 0.14, 3.05), Vector3(0.02, 0.02, 0.0), 30.0)
	kit_root.queue_free()
	await process_frame

	await _capture_60hz_motion_strip()
	await _capture_play_distance_and_cvd()

	print("PILOT_LIVELINESS_CAPTURE ok=true out=", _out)
	quit(0)
