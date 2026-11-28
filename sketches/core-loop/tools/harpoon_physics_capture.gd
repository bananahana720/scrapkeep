extends SceneTree

const HarpoonPhysicsRig := preload("res://src/presentation/harpoon_physics_rig.gd")
const PropMotionRig := preload("res://src/presentation/prop_motion_rig.gd")
const LineView := preload("res://src/presentation/line_view.gd")
const AugmentKit := preload("res://src/movement/augment_kit.gd")
const Augments := preload("res://src/movement/augments.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Palette := preload("res://src/core/palette.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const AppShell := preload("res://src/core/app_shell.gd")


const SIZE := Vector2i(1280, 720)
const FRAME := 1.0 / 60.0

var _out := ""
var _stage: Node3D
var _cam: Camera3D
var _metrics := {}


class FakePlayer extends Node3D:
	var kit := AugmentKit.new()
	var events := GameEvents.new()

	func shown_position() -> Vector3:
		return global_position

	func ball_position() -> Vector3:
		return global_position

	func grapple_range() -> float:
		return 60.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty() or AppShell.headless():
		push_error("harpoon_physics_capture: pass --out=/abs/dir on a display server")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	EnemyMotion.motion_scale = 1.0
	FlashGuard.on = false
	_run.call_deferred()


func _build_env() -> void:
	_stage = Node3D.new()
	root.add_child(_stage)

	var look: Dictionary = WorldLook.ROWS[1]
	var env := Environment.new()
	if look.sky == "hdri":
		env.background_mode = Environment.BG_SKY
		env.sky = Palette.hdri_sky()
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = look.background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = look.ambient
	env.ambient_light_sky_contribution = 0.35
	env.ambient_light_energy = look.energy * 1.3
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = look.exposure
	env.tonemap_agx_white = 16.29
	env.tonemap_agx_contrast = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, -32.0, 0.0)
	sun.light_color = look.sun_color
	sun.light_energy = look.sun_energy * 1.2
	sun.shadow_enabled = true
	_stage.add_child(sun)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-22.0, 148.0, 0.0)
	rim.light_color = Palette.DAWN_VIOLET
	rim.light_energy = 0.72
	_stage.add_child(rim)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	ground.mesh = plane
	var sand := StandardMaterial3D.new()
	sand.albedo_texture = load("res://assets/textures/packed-sand-floor.webp")
	sand.uv1_scale = Vector3(22.0, 22.0, 1.0)
	sand.roughness = 0.94
	ground.material_override = sand
	_stage.add_child(ground)

	var wall := MeshInstance3D.new()
	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(36.0, 10.0, 0.6)
	wall.mesh = wall_box
	wall.position = Vector3(0.0, 5.0, -5.8)
	var wall_mat := Palette.solid(Palette.SANDSTONE.lerp(Palette.VERDIGRIS, 0.35), 0.0)
	wall_mat.roughness = 0.92
	wall.material_override = wall_mat
	_stage.add_child(wall)

	_cam = Camera3D.new()
	_cam.fov = 42.0
	_cam.current = true
	_stage.add_child(_cam)


func _snap() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _make_ball_proxy(at: Vector3) -> MeshInstance3D:
	var ball := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.95
	sph.height = 1.9
	ball.mesh = sph
	var mat := Palette.solid(Palette.VERDIGRIS, 0.0)
	mat.roughness = 0.45
	mat.metallic = 0.35
	ball.material_override = mat
	ball.position = at
	return ball


func _make_target_post(at: Vector3) -> Node3D:
	var post := Node3D.new()
	post.position = at
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.56
	cyl.height = 4.2
	cyl.radial_segments = 10
	body.mesh = cyl
	body.position = Vector3(0.0, 2.1, 0.0)
	var mat := Palette.solid(Palette.RUST.lightened(0.08), 0.0)
	mat.roughness = 0.55
	mat.metallic = 0.28
	body.material_override = mat
	post.add_child(body)
	var collar_ring := MeshInstance3D.new()
	var c_cyl := CylinderMesh.new()
	c_cyl.top_radius = 0.54
	c_cyl.bottom_radius = 0.54
	c_cyl.height = 0.36
	c_cyl.radial_segments = 12
	collar_ring.mesh = c_cyl
	collar_ring.position = Vector3(0.0, 2.45, 0.0)
	collar_ring.material_override = Palette.solid(Palette.CHARCOAL, 0.0)
	post.add_child(collar_ring)
	return post


func _make_pedestal(at: Vector3) -> MeshInstance3D:
	var ped := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.50
	cyl.height = 0.14
	cyl.radial_segments = 12
	ped.mesh = cyl
	ped.position = Vector3(at.x, 0.07, at.z)
	var mat := Palette.solid(Palette.CHARCOAL.lerp(Palette.STEEL, 0.25), 0.0)
	mat.roughness = 0.72
	ped.material_override = mat
	return ped


func _build_gantry_prop(at: Vector3) -> Dictionary:
	var root_node := Node3D.new()
	root_node.position = at

	var beam := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(3.8, 0.30, 0.46)
	beam.mesh = b_box
	beam.position = Vector3(0.0, 4.15, 0.0)
	beam.material_override = Palette.solid(Palette.CHARCOAL, 0.0)
	root_node.add_child(beam)

	for sx in [-1.75, 1.75]:
		var leg := MeshInstance3D.new()
		var l_box := BoxMesh.new()
		l_box.size = Vector3(0.28, 4.15, 0.36)
		leg.mesh = l_box
		leg.position = Vector3(sx, 2.075, 0.0)
		leg.material_override = Palette.solid(Palette.CHARCOAL.lerp(Palette.STEEL, 0.22), 0.0)
		root_node.add_child(leg)

	var hang_pivot := Node3D.new()
	hang_pivot.position = Vector3(0.0, 3.98, 0.0)
	root_node.add_child(hang_pivot)

	var rod := MeshInstance3D.new()
	var r_cyl := CylinderMesh.new()
	r_cyl.top_radius = 0.08
	r_cyl.bottom_radius = 0.08
	r_cyl.height = 1.45
	rod.mesh = r_cyl
	rod.position = Vector3(0.0, -0.72, 0.0)
	rod.material_override = Palette.solid(Palette.STEEL, 0.0)
	hang_pivot.add_child(rod)

	var pod := MeshInstance3D.new()
	var pod_box := BoxMesh.new()
	pod_box.size = Vector3(0.92, 0.78, 0.72)
	pod.mesh = pod_box
	pod.position = Vector3(0.0, -1.65, 0.0)
	var pod_mat := Palette.solid(Palette.COPPER, 0.0)
	pod_mat.metallic = 0.52
	pod_mat.roughness = 0.40
	pod.material_override = pod_mat
	hang_pivot.add_child(pod)

	var band := MeshInstance3D.new()
	var band_box := BoxMesh.new()
	band_box.size = Vector3(0.98, 0.14, 0.78)
	band.mesh = band_box
	band.position = Vector3(0.0, -1.65, 0.0)
	band.material_override = Palette.solid(Palette.CHARCOAL, 0.0)
	hang_pivot.add_child(band)

	var piston_pivot := Node3D.new()
	piston_pivot.position = Vector3(0.0, -2.02, 0.0)
	hang_pivot.add_child(piston_pivot)
	var piston_shaft := MeshInstance3D.new()
	var p_cyl := CylinderMesh.new()
	p_cyl.top_radius = 0.12
	p_cyl.bottom_radius = 0.12
	p_cyl.height = 1.45
	piston_shaft.mesh = p_cyl
	piston_shaft.position = Vector3(0.0, 0.34, 0.0)
	piston_shaft.material_override = Palette.solid(Palette.SAND, 0.15)
	piston_pivot.add_child(piston_shaft)
	var piston_cap := MeshInstance3D.new()
	var pc_cyl := CylinderMesh.new()
	pc_cyl.top_radius = 0.22
	pc_cyl.bottom_radius = 0.22
	pc_cyl.height = 0.16
	piston_cap.mesh = pc_cyl
	piston_cap.position = Vector3(0.0, -0.40, 0.0)
	piston_cap.material_override = Palette.solid(Palette.CHARCOAL, 0.0)
	piston_pivot.add_child(piston_cap)

	var turbine_pivot := Node3D.new()
	turbine_pivot.position = Vector3(0.0, -1.65, 0.42)
	hang_pivot.add_child(turbine_pivot)
	var hub := MeshInstance3D.new()
	var h_cyl := CylinderMesh.new()
	h_cyl.top_radius = 0.12
	h_cyl.bottom_radius = 0.12
	h_cyl.height = 0.12
	hub.mesh = h_cyl
	hub.rotation.x = PI * 0.5
	hub.material_override = Palette.solid(Palette.CHARCOAL, 0.0)
	turbine_pivot.add_child(hub)
	for b in 3:
		var ang := TAU * float(b) / 3.0
		var blade_arm := Node3D.new()
		blade_arm.rotation.z = ang
		turbine_pivot.add_child(blade_arm)
		var blade := MeshInstance3D.new()
		var blade_box := BoxMesh.new()
		blade_box.size = Vector3(0.14 if b > 0 else 0.17, 0.34 if b > 0 else 0.42, 0.06)
		blade.mesh = blade_box
		blade.position = Vector3(0.0, 0.22 if b > 0 else 0.25, 0.0)
		blade.material_override = Palette.solid(Palette.ARC, 0.95) if b == 0 else Palette.solid(Palette.STEEL, 0.0)
		blade_arm.add_child(blade)

	var col_rim := MeshInstance3D.new()
	var rim_torus := TorusMesh.new()
	rim_torus.inner_radius = 0.60
	rim_torus.outer_radius = 0.84
	col_rim.mesh = rim_torus
	col_rim.position = Vector3(0.0, 0.04, 0.0)
	col_rim.material_override = Palette.solid(Palette.CHARCOAL, 0.0)
	root_node.add_child(col_rim)
	var col_mark := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.66
	torus.outer_radius = 0.77
	col_mark.mesh = torus
	col_mark.position = Vector3(0.0, 0.08, 0.0)
	col_mark.material_override = Palette.solid(Palette.ARC, 0.85)
	root_node.add_child(col_mark)

	return {
		"root": root_node,
		"hang": hang_pivot,
		"piston": piston_pivot,
		"turbine": turbine_pivot,
	}


func _run() -> void:
	_build_env()

	var head_scene := Node3D.new()
	_stage.add_child(head_scene)
	_cam.look_at_from_position(Vector3(0.0, 2.05, 5.35), Vector3(0.0, 1.05, 0.0))

	var xs := [-2.25, -0.75, 0.80, 2.25]
	for x in xs:
		head_scene.add_child(_make_pedestal(Vector3(x, 0.0, 0.0)))

	var legacy := MeshInstance3D.new()
	var legacy_box := BoxMesh.new()
	legacy_box.size = Vector3.ONE * 0.62
	legacy.mesh = legacy_box
	legacy.rotation = Vector3(PI * 0.25, 0.0, PI * 0.25)
	var legacy_mat := StandardMaterial3D.new()
	legacy_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	legacy_mat.albedo_color = Palette.ARC
	legacy.material_override = legacy_mat
	head_scene.add_child(legacy)
	legacy.global_position = Vector3(xs[0], 1.10, 0.0)

	var head_open := HarpoonPhysicsRig.make_head()
	head_scene.add_child(head_open)
	head_open.scale = Vector3.ONE * 1.85
	head_open.set_mode("launch")
	head_open.step_head(FRAME, true)
	head_open.aim_along(Vector3(xs[1], 1.15, 0.0), Vector3(0.55, -0.18, 0.80))
	_set_shadows_recursive(head_open, true)

	var head_bite := HarpoonPhysicsRig.make_head()
	head_scene.add_child(head_bite)
	head_bite.scale = Vector3.ONE * 1.85
	head_bite.set_mode("bite", true)
	for i in 12:
		head_bite.step_head(FRAME, true)
	head_bite.aim_along(Vector3(xs[2], 1.15, 0.0), Vector3(-0.45, -0.18, 0.86))
	_set_shadows_recursive(head_bite, true)

	var spool_demo := HarpoonPhysicsRig.make_spool()
	head_scene.add_child(spool_demo)
	spool_demo.scale = Vector3.ONE * 3.1
	spool_demo.sync(Vector3(xs[3], 1.10, 0.0), Vector3(xs[3] - 0.65, 0.90, 1.25), 0.75)
	_set_shadows_recursive(spool_demo, true)

	var img_heads := await _snap()
	img_heads.save_png(_out.path_join("harpoon_head_before_after.png"))
	head_scene.free()

	var seq_root := Node3D.new()
	_stage.add_child(seq_root)
	var player := FakePlayer.new()
	player.position = Vector3(-5.0, 2.55, 0.0)
	seq_root.add_child(player)
	var ball_proxy := _make_ball_proxy(player.position)
	seq_root.add_child(ball_proxy)
	var post := _make_target_post(Vector3(5.0, 0.0, 0.0))
	seq_root.add_child(post)

	var view := LineView.new()
	seq_root.add_child(view)
	view.setup(player, _cam, player.events)
	view.set_process(false)
	_cam.look_at_from_position(Vector3(0.0, 3.6, 12.0), Vector3(0.0, 2.1, 0.0))

	player.kit.aim = {"state": Augments.AIM_REACH, "point": Vector3(5.0, 2.65, 0.0)}
	player.events.line_state_changed.emit("dry_fire", null, player.global_position, "")
	for i in 4:
		view.step(FRAME)
	var launch_pts := view.cable_solver.sample_points(view.cable_origin, view.flight_head.global_position, 0.0, false)
	var launch_whip_max := 0.0
	for k in range(1, launch_pts.size() - 1):
		var base := view.cable_origin.lerp(view.flight_head.global_position, float(k) / float(launch_pts.size() - 1))
		launch_whip_max = maxf(launch_whip_max, launch_pts[k].distance_to(base))
	_metrics["launch_whip_max_m"] = launch_whip_max
	_metrics["launch_jaw_rad"] = view.flight_head.current_jaw_angle()
	_metrics["launch_spool_rad"] = view.cable_solver.spool_angle
	var f1 := await _snap()
	f1.save_png(_out.path_join("seq_1_launch_whip.png"))

	player.kit.hooked = true
	player.kit.on_body = true
	player.kit.rope = 9.4
	player.kit.anchor = Vector3(4.25, 2.65, 0.0)
	player.events.harpoon_bit.emit(null, player.kit.anchor)
	view.step(FRAME)
	var strum_pts := view.cable_solver.sample_points(view.cable_origin, player.kit.anchor, 0.0, true)
	_metrics["bite_strum_mid_m"] = strum_pts[10].distance_to(view.cable_origin.lerp(player.kit.anchor, 0.5))
	_metrics["bite_jaw_rad"] = (view.barb as HarpoonPhysicsRig.HarpoonHead).current_jaw_angle()
	var f2 := await _snap()
	f2.save_png(_out.path_join("seq_2_bite_strum.png"))

	player.kit.on_body = false
	player.kit.rope = 15.5
	player.kit.anchor = Vector3(4.25, 2.75, 0.0)
	view.cable_solver.reset()
	for i in 10:
		view.step(FRAME)
	var slack_pts := view.cable_solver.sample_points(view.cable_origin, player.kit.anchor, 1.8, false)
	_metrics["slack_sag_mid_drop_m"] = view.cable_origin.lerp(player.kit.anchor, 0.5).y - slack_pts[10].y
	var f3 := await _snap()
	f3.save_png(_out.path_join("seq_3_slack_catenary.png"))

	var gantry := _build_gantry_prop(Vector3(3.15, 0.0, -2.6))
	seq_root.add_child(gantry["root"])
	var prop_rig := PropMotionRig.new()
	prop_rig.add_part("hang", gantry["hang"], {"sway": true, "sway_max_rad": 0.30, "sway_gain": 0.032})
	prop_rig.add_part("piston", gantry["piston"], {"cycle": PropMotionRig.CYCLE_PISTON, "axis": Vector3.DOWN, "amplitude": 0.48, "hz": 1.6})
	prop_rig.add_part("turbine", gantry["turbine"], {"cycle": PropMotionRig.CYCLE_TURBINE, "axis": Vector3.FORWARD, "hz": 1.9})
	prop_rig.apply_impulse(Vector3(1.0, 0.0, 0.15), 1.0, "hang")
	for i in 11:
		prop_rig.step(FRAME, Vector3(11.0, 0.0, 0.0))

	player.kit.hooked = false
	player.events.line_state_changed.emit("let_go", null, Vector3(4.25, 2.75, 0.0), "")
	for i in 4:
		view.step(FRAME)
	_metrics["retract_whip_energy"] = view.cable_solver.whip_energy
	_metrics["retract_cable_visible"] = view.cable.visible
	_metrics["prop_hang_euler_rad"] = (gantry["hang"] as Node3D).basis.get_euler().length()
	var f4 := await _snap()
	f4.save_png(_out.path_join("seq_4_retract_and_prop.png"))

	var sheet := _compose_quad(f1, f2, f3, f4)
	sheet.save_png(_out.path_join("harpoon_sequence_sheet.png"))

	prop_rig.clear()
	view.free()
	player.events.free()
	seq_root.free()

	var prop_scene := Node3D.new()
	_stage.add_child(prop_scene)
	_cam.look_at_from_position(Vector3(0.0, 2.6, 9.8), Vector3(0.0, 2.0, 0.0))
	var left_prop := _build_gantry_prop(Vector3(-2.55, 0.0, 0.0))
	var right_prop := _build_gantry_prop(Vector3(2.55, 0.0, 0.0))
	prop_scene.add_child(left_prop["root"])
	prop_scene.add_child(right_prop["root"])

	var demo_rig := PropMotionRig.new()
	demo_rig.add_part("hang", right_prop["hang"], {"sway": true, "sway_max_rad": 0.30, "sway_gain": 0.032})
	demo_rig.add_part("piston", right_prop["piston"], {"cycle": PropMotionRig.CYCLE_PISTON, "axis": Vector3.DOWN, "amplitude": 0.55, "hz": 1.6})
	demo_rig.add_part("turbine", right_prop["turbine"], {"cycle": PropMotionRig.CYCLE_TURBINE, "axis": Vector3.FORWARD, "hz": 2.1})
	demo_rig.apply_impulse(Vector3(0.85, 0.0, 0.2), 0.9, "hang")
	for i in 10:
		demo_rig.step(FRAME, Vector3(11.0, 0.0, 0.0))
	_metrics["prop_demo_sway_rad"] = (right_prop["hang"] as Node3D).basis.get_euler().length()
	_metrics["prop_demo_piston_y"] = (right_prop["piston"] as Node3D).position.y
	_metrics["prop_demo_turbine_rad"] = demo_rig.part("turbine").cycle_angle

	var img_prop := await _snap()
	img_prop.save_png(_out.path_join("prop_motion_sequence.png"))
	demo_rig.clear()
	prop_scene.free()

	await _capture_play_distance_and_strip()

	var f := FileAccess.open(_out.path_join("metrics.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_metrics, "\t"))
	f.close()
	print("harpoon_physics_capture: wrote sequence sheet, before/after head, prop motion still, 60 Hz strip, play-distance stills, and metrics.json to %s" % _out)
	_stage.free()
	quit(0)


func _capture_play_distance_and_strip() -> void:
	var strip_root := Node3D.new()
	_stage.add_child(strip_root)
	var player := FakePlayer.new()
	player.position = Vector3(-4.2, 2.35, 0.0)
	strip_root.add_child(player)
	var ball_proxy := _make_ball_proxy(player.position)
	strip_root.add_child(ball_proxy)
	var post := _make_target_post(Vector3(3.4, 0.0, -1.0))
	strip_root.add_child(post)
	var gantry := _build_gantry_prop(Vector3(7.6, 0.0, -2.2))
	strip_root.add_child(gantry["root"])

	var prop_rig := PropMotionRig.new()
	prop_rig.add_part("hang", gantry["hang"], {"sway": true, "sway_max_rad": 0.30, "sway_gain": 0.032})
	prop_rig.add_part("piston", gantry["piston"], {"cycle": PropMotionRig.CYCLE_PISTON, "axis": Vector3.DOWN, "amplitude": 0.45, "hz": 1.6})
	prop_rig.add_part("turbine", gantry["turbine"], {"cycle": PropMotionRig.CYCLE_TURBINE, "axis": Vector3.FORWARD, "hz": 2.0})
	prop_rig.apply_impulse(Vector3(0.9, 0.0, 0.15), 1.0, "hang")

	var view := LineView.new()
	strip_root.add_child(view)
	view.setup(player, _cam, player.events)
	view.set_process(false)

	_cam.look_at_from_position(Vector3(-3.2, 5.1, 9.2), Vector3(1.6, 2.1, -1.2))
	var strip_frames: Array[Image] = []

	player.kit.aim = {"state": Augments.AIM_REACH, "point": Vector3(2.82, 2.45, -0.92)}
	player.events.line_state_changed.emit("dry_fire", null, player.global_position, "")
	view.step(FRAME)
	prop_rig.step(FRAME, Vector3(10.0, 0.0, 0.0))
	strip_frames.append(await _snap())

	for i in 2:
		view.step(FRAME)
		prop_rig.step(FRAME, Vector3(10.0, 0.0, 0.0))
	strip_frames.append(await _snap())

	player.kit.hooked = true
	player.kit.on_body = true
	player.kit.rope = 7.6
	player.kit.anchor = Vector3(2.82, 2.45, -0.92)
	player.events.harpoon_bit.emit(null, player.kit.anchor)
	view.step(FRAME)
	prop_rig.step(FRAME, Vector3(10.0, 0.0, 0.0))
	var bite_play := await _snap()
	strip_frames.append(bite_play)

	var play_1080: Image = bite_play.duplicate()
	play_1080.convert(Image.FORMAT_RGBA8)
	play_1080.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	play_1080.save_png(_out.path_join("harpoon_play_distance_1080p.png"))
	var play_720_gray: Image = _to_greyscale(bite_play, Vector2i(1280, 720))
	play_720_gray.save_png(_out.path_join("harpoon_play_distance_720p_gray.png"))

	for i in 4:
		view.step(FRAME)
		prop_rig.step(FRAME, Vector3(10.0, 0.0, 0.0))
	strip_frames.append(await _snap())

	player.kit.on_body = false
	player.kit.rope = 12.2
	view.cable_solver.reset()
	for i in 8:
		view.step(FRAME)
		prop_rig.step(FRAME, Vector3(10.0, 0.0, 0.0))
	strip_frames.append(await _snap())

	player.kit.hooked = false
	player.events.line_state_changed.emit("let_go", null, player.kit.anchor, "")
	for i in 4:
		view.step(FRAME)
		prop_rig.step(FRAME, Vector3(10.0, 0.0, 0.0))
	strip_frames.append(await _snap())

	var strip_img := _compose_grid_3x2(strip_frames)
	strip_img.save_png(_out.path_join("harpoon_motion_strip_60hz.png"))
	_metrics["play_cam_distance_m"] = _cam.global_position.distance_to(player.global_position)
	_metrics["strip_frames"] = strip_frames.size()

	prop_rig.clear()
	view.free()
	player.events.free()
	strip_root.free()


static func _to_greyscale(src: Image, target_size: Vector2i) -> Image:
	var img: Image = src.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_size() != target_size:
		img.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var luma := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			img.set_pixel(x, y, Color(luma, luma, luma, 1.0))
	return img


static func _compose_grid_3x2(frames: Array[Image]) -> Image:
	var w := 1536
	var h := 640
	var cell_w := 512
	var cell_h := 320
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Palette.CHARCOAL)
	for i in mini(6, frames.size()):
		var col := i % 3
		@warning_ignore("integer_division")
		var row := i / 3
		var src: Image = frames[i].duplicate()
		src.convert(Image.FORMAT_RGBA8)
		src.resize(cell_w - 6, cell_h - 6, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(col * cell_w + 3, row * cell_h + 3))
	return out


static func _set_shadows_recursive(node: Node, enabled: bool) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_set_shadows_recursive(child, enabled)


static func _compose_quad(a: Image, b: Image, c: Image, d: Image) -> Image:
	@warning_ignore("integer_division")
	var half_w := SIZE.x / 2
	@warning_ignore("integer_division")
	var half_h := SIZE.y / 2
	var out := Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	out.fill(Palette.CHARCOAL)
	var quads := [[a, 0, 0], [b, half_w, 0], [c, 0, half_h], [d, half_w, half_h]]
	for q in quads:
		var src: Image = (q[0] as Image).duplicate()
		src.convert(Image.FORMAT_RGBA8)
		src.resize(half_w - 6, half_h - 6, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(int(q[1]) + 3, int(q[2]) + 3))
	return out
