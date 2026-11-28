extends SceneTree


const Assembly := preload("res://src/presentation/craft/craft_showcase_assembly.gd")
const Palette := preload("res://src/core/palette.gd")
const AppShell := preload("res://src/core/app_shell.gd")

const CAPTURE_SIZE := Vector2i(1920, 1080)
const ORBIT_AZIMUTHS_DEG := [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
const ORBIT_ELEVATIONS_DEG := [26.0, 32.0, 20.0, 14.0, 12.0, 18.0, 22.0, 38.0]

var _out := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty() or AppShell.headless():
		printerr("craft_showcase_deep_audit: requires Metal/rendered display and -- --out=<abs_dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = CAPTURE_SIZE
	root.content_scale_size = CAPTURE_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _run() -> void:
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	RenderingServer.environment_set_volumetric_fog_volume_size(128, 128)

	var packed := load(Assembly.SHOWCASE_SCENE_PATH) as PackedScene
	if packed == null:
		printerr("craft_showcase_deep_audit: failed to load showcase scene")
		quit(1)
		return
	var arena := packed.instantiate() as Node3D
	root.add_child(arena)
	await process_frame

	var rig := arena.get_node_or_null("VistaAtmosphereRig")
	if rig != null and rig.has_method("apply_preset"):
		rig.apply_preset("smelter_dawn")
	var receipt := Assembly.assemble_into(arena)

	var cam := Camera3D.new()
	cam.near = 0.2
	cam.far = 1400.0
	arena.add_child(cam)
	cam.make_current()

	var sun := arena.get_node_or_null("SunKey") as DirectionalLight3D
	var orig_sun_xf := sun.transform if sun != null else Transform3D.IDENTITY

	for _i in 20:
		await process_frame

	var manifest := {
		"adapter": RenderingServer.get_video_adapter_name(),
		"scene": Assembly.SHOWCASE_SCENE_PATH,
		"capture_size": [CAPTURE_SIZE.x, CAPTURE_SIZE.y],
		"orbit_360": [],
		"gbuffer_panels": [],
		"quality_tiers": [],
		"cold_blind": {},
	}

	_aim_camera(cam, Vector3(7.4, 4.6, -6.2), Vector3(-0.2, 3.3, -14.2), 42.0)
	var orbit_tiles: Array[Image] = []
	for i in ORBIT_AZIMUTHS_DEG.size():
		var az := float(ORBIT_AZIMUTHS_DEG[i])
		var el := float(ORBIT_ELEVATIONS_DEG[i])
		if sun != null:
			var rad_az := deg_to_rad(az)
			var rad_el := deg_to_rad(el)
			var sun_dir := Vector3(
				cos(rad_el) * sin(rad_az),
				sin(rad_el),
				cos(rad_el) * cos(rad_az)
			).normalized()
			sun.look_at_from_position(sun_dir * 48.0, Vector3.ZERO, Vector3.UP)
		var img := await _grab_frame(10)
		var stats := _image_luma_stats(img)
		stats["azimuth_deg"] = az
		stats["elevation_deg"] = el
		(manifest["orbit_360"] as Array).append(stats)
		var tile := img.duplicate() as Image
		tile.resize(480, 270, Image.INTERPOLATE_LANCZOS)
		orbit_tiles.append(tile)
	if sun != null:
		sun.transform = orig_sun_xf
	var orbit_sheet := _compose_grid(orbit_tiles, 4, 2, 480, 270, 6)
	var orbit_path := _out.path_join("orbit_360_light_sheet.png")
	orbit_sheet.save_png(orbit_path)
	manifest["orbit_360_sheet"] = orbit_path

	_aim_camera(cam, Vector3(7.4, 4.6, -6.2), Vector3(-0.2, 3.3, -14.2), 42.0)
	var gbuf_tiles: Array[Image] = []

	root.debug_draw = Viewport.DEBUG_DRAW_DISABLED
	var p_beauty := await _grab_frame(12)
	gbuf_tiles.append(_resize_copy(p_beauty, 640, 360))
	(manifest["gbuffer_panels"] as Array).append({"id": "beauty_agx", "stats": _image_luma_stats(p_beauty)})

	root.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	var p_albedo := await _grab_frame(8)
	gbuf_tiles.append(_resize_copy(p_albedo, 640, 360))
	(manifest["gbuffer_panels"] as Array).append({"id": "gbuffer_unshaded_albedo", "stats": _image_luma_stats(p_albedo)})

	root.debug_draw = Viewport.DEBUG_DRAW_NORMAL_BUFFER
	var p_normal := await _grab_frame(8)
	gbuf_tiles.append(_resize_copy(p_normal, 640, 360))
	(manifest["gbuffer_panels"] as Array).append({"id": "gbuffer_normal_buffer", "stats": _image_luma_stats(p_normal)})

	root.debug_draw = Viewport.DEBUG_DRAW_LIGHTING
	var p_lighting := await _grab_frame(8)
	gbuf_tiles.append(_resize_copy(p_lighting, 640, 360))
	(manifest["gbuffer_panels"] as Array).append({"id": "gbuffer_lighting_ssao", "stats": _image_luma_stats(p_lighting)})

	root.debug_draw = Viewport.DEBUG_DRAW_DISABLED
	var hero_nodes: Dictionary = receipt["hero_nodes"]
	var saved_overrides := _apply_vertex_mask_debug_view(hero_nodes)
	var p_masks := await _grab_frame(8)
	_restore_vertex_mask_debug_view(saved_overrides)
	gbuf_tiles.append(_resize_copy(p_masks, 640, 360))
	(manifest["gbuffer_panels"] as Array).append({"id": "vertex_rgb_masks", "stats": _image_luma_stats(p_masks)})

	var proof := _build_combat_readability_proof()
	arena.add_child(proof)
	_aim_camera(cam, Vector3(0.0, 15.8, 22.8), Vector3(0.0, 1.4, -10.5), 52.0)
	var play_1080 := await _grab_frame(14)
	var play_1080_path := _out.path_join("cold_blind_playcam_1080p.png")
	play_1080.save_png(play_1080_path)

	var play_720 := _resize_copy(play_1080, 1280, 720)
	var play_720_path := _out.path_join("cold_blind_playcam_720p.png")
	play_720.save_png(play_720_path)

	var play_grey := _to_luminance_greyscale(play_720)
	var play_grey_path := _out.path_join("cold_blind_greyscale.png")
	play_grey.save_png(play_grey_path)

	var play_cvd := _to_machado_deuteranopia(play_720)
	var play_cvd_path := _out.path_join("cold_blind_deuteranopia.png")
	play_cvd.save_png(play_cvd_path)

	manifest["cold_blind"] = {
		"playcam_1080p": play_1080_path,
		"playcam_720p": play_720_path,
		"greyscale": play_grey_path,
		"deuteranopia": play_cvd_path,
		"stats_1080p": _image_luma_stats(play_1080),
	}

	var split_img := _resize_copy(play_grey, 640, 360)
	var cvd_small := _resize_copy(play_cvd, 640, 360)
	split_img.blit_rect(cvd_small, Rect2i(320, 0, 320, 360), Vector2i(320, 0))
	for y in 360:
		split_img.set_pixel(320, y, Color(0.95, 0.95, 0.95, 1.0))
	gbuf_tiles.append(split_img)
	var gbuf_sheet := _compose_grid(gbuf_tiles, 3, 2, 640, 360, 6)
	var gbuf_path := _out.path_join("gbuffer_mask_sheet.png")
	gbuf_sheet.save_png(gbuf_path)
	manifest["gbuffer_mask_sheet"] = gbuf_path

	var tier_tiles: Array[Image] = []
	for tier: String in ["low", "medium", "high", "ultra"]:
		var q_info := Assembly.apply_quality_tier(arena, tier)
		if tier == "low":
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
		elif tier == "medium":
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		else:
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
		var t_img := await _grab_frame(14)
		var t_stats := _image_luma_stats(t_img)
		t_stats["tier"] = tier
		t_stats["config"] = q_info
		t_stats["draw_calls"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		t_stats["primitives"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		t_stats["objects"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		(manifest["quality_tiers"] as Array).append(t_stats)
		tier_tiles.append(_resize_copy(t_img, 800, 450))
	Assembly.apply_quality_tier(arena, "high")
	var tier_sheet := _compose_grid(tier_tiles, 2, 2, 800, 450, 6)
	var tier_path := _out.path_join("quality_tiers_sheet.png")
	tier_sheet.save_png(tier_path)
	manifest["quality_tiers_sheet"] = tier_path

	var mf := FileAccess.open(_out.path_join("deep_audit_manifest.json"), FileAccess.WRITE)
	mf.store_string(JSON.stringify(manifest, "\t"))
	mf.close()

	proof.free()
	arena.free()
	Assembly.reset_for_tests()
	quit(0)


func _aim_camera(cam: Camera3D, eye: Vector3, target: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.global_position = eye
	cam.look_at(target, Vector3.UP)


func _grab_frame(settle_frames: int) -> Image:
	for _i in settle_frames:
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _resize_copy(src: Image, w: int, h: int) -> Image:
	var copy := src.duplicate() as Image
	copy.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return copy


func _compose_grid(tiles: Array[Image], cols: int, rows: int, tw: int, th: int, pad: int) -> Image:
	var out_w := cols * tw + (cols + 1) * pad
	var out_h := rows * th + (rows + 1) * pad
	var canvas := Image.create_empty(out_w, out_h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.08, 0.09, 0.09, 1.0))
	for idx in tiles.size():
		var col := idx % cols
		var row := int(floor(float(idx) / float(cols)))
		var dx := pad + col * (tw + pad)
		var dy := pad + row * (th + pad)
		var src := tiles[idx]
		if src.get_format() != Image.FORMAT_RGBA8:
			src = src.duplicate() as Image
			src.convert(Image.FORMAT_RGBA8)
		canvas.blit_rect(src, Rect2i(0, 0, tw, th), Vector2i(dx, dy))
	return canvas


func _image_luma_stats(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var step := 4
	var sum := 0.0
	var count := 0
	var clipped_hi := 0
	var crushed_lo := 0
	var samples: Array[float] = []
	for y in range(0, h, step):
		for x in range(0, w, step):
			var c := img.get_pixel(x, y)
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			sum += l
			samples.append(l)
			count += 1
			if l > 0.97:
				clipped_hi += 1
			elif l < 0.025:
				crushed_lo += 1
	samples.sort()
	var p99 := samples[int(floor(float(samples.size() - 1) * 0.99))] if not samples.is_empty() else 0.0
	var p50 := samples[int(floor(float(samples.size() - 1) * 0.50))] if not samples.is_empty() else 0.0
	return {
		"mean_luma": snappedf(sum / maxf(float(count), 1.0), 0.0001),
		"p50_luma": snappedf(p50, 0.0001),
		"p99_luma": snappedf(p99, 0.0001),
		"clipped_white_pct": snappedf(100.0 * float(clipped_hi) / maxf(float(count), 1.0), 0.01),
		"crushed_black_pct": snappedf(100.0 * float(crushed_lo) / maxf(float(count), 1.0), 0.01),
	}


func _to_luminance_greyscale(src: Image) -> Image:
	var out := Image.create_empty(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			var l := clampf(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b, 0.0, 1.0)
			out.set_pixel(x, y, Color(l, l, l, 1.0))
	return out


func _to_machado_deuteranopia(src: Image) -> Image:
	var out := Image.create_empty(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			var r := clampf(0.367322 * c.r + 0.860646 * c.g - 0.227968 * c.b, 0.0, 1.0)
			var g := clampf(0.280085 * c.r + 0.672501 * c.g + 0.047413 * c.b, 0.0, 1.0)
			var b := clampf(-0.011820 * c.r + 0.042940 * c.g + 0.968881 * c.b, 0.0, 1.0)
			out.set_pixel(x, y, Color(r, g, b, 1.0))
	return out


func _apply_vertex_mask_debug_view(hero_nodes: Dictionary) -> Array[Dictionary]:
	var mask_mat := StandardMaterial3D.new()
	mask_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mask_mat.vertex_color_use_as_albedo = true
	var saved: Array[Dictionary] = []
	for key in hero_nodes.keys():
		var mi := hero_nodes[key] as MeshInstance3D
		if mi == null:
			continue
		saved.append({"node": mi, "override": mi.material_override})
		mi.material_override = mask_mat
	return saved


func _restore_vertex_mask_debug_view(saved: Array[Dictionary]) -> void:
	for entry in saved:
		var mi: MeshInstance3D = entry["node"]
		if is_instance_valid(mi):
			mi.material_override = entry["override"]


func _build_combat_readability_proof() -> Node3D:
	var holder := Node3D.new()
	holder.name = "CombatReadabilityProof"

	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.05
	sphere.height = 2.1
	ball.mesh = sphere
	ball.position = Vector3(-4.5, 1.05, 4.0)
	var ball_mat := Palette.solid(Palette.STEEL.lerp(Palette.CHARCOAL, 0.28), 0.0, true)
	ball_mat.metallic = 0.58
	ball_mat.roughness = 0.34
	ball_mat.normal_scale = 0.28
	ball_mat.uv1_scale = Vector3.ONE / 0.38
	ball.material_override = ball_mat
	holder.add_child(ball)

	var hoop := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.18
	hoop.mesh = torus
	hoop.position = Vector3(-4.5, 1.05, 4.0)
	hoop.material_override = Palette.solid(Palette.ARC, 1.8, false)
	holder.add_child(hoop)

	var keyline := MeshInstance3D.new()
	var key_cyl := CylinderMesh.new()
	key_cyl.top_radius = 4.5
	key_cyl.bottom_radius = 4.5
	key_cyl.height = 0.04
	keyline.mesh = key_cyl
	keyline.position = Vector3(5.8, 0.03, 0.5)
	keyline.material_override = Palette.unshaded(Palette.CHARCOAL)
	holder.add_child(keyline)

	var danger := MeshInstance3D.new()
	var d_cyl := CylinderMesh.new()
	d_cyl.top_radius = 4.22
	d_cyl.bottom_radius = 4.22
	d_cyl.height = 0.05
	danger.mesh = d_cyl
	danger.position = Vector3(5.8, 0.045, 0.5)
	var hazard_mat := Palette.hazard_stripe().duplicate() as StandardMaterial3D
	hazard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	danger.material_override = hazard_mat
	holder.add_child(danger)

	var ao_mat := _make_soft_ao_shadow_material()
	for spec in [
		{"pos": Vector3(-0.6, 0.78, -4.2), "color": Palette.ARC, "emit": 1.6},
		{"pos": Vector3(-9.2, 0.78, -2.5), "color": Palette.COBALT, "emit": 1.8},
	]:
		var ao_quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(2.6, 2.6)
		ao_quad.mesh = qm
		ao_quad.position = Vector3((spec["pos"] as Vector3).x, 0.024, (spec["pos"] as Vector3).z)
		ao_quad.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		ao_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ao_quad.material_override = ao_mat
		holder.add_child(ao_quad)

		var crystal := MeshInstance3D.new()
		var oct := SphereMesh.new()
		oct.radial_segments = 6
		oct.rings = 2
		oct.radius = 0.65
		oct.height = 1.45
		crystal.mesh = oct
		crystal.position = spec["pos"]
		crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		crystal.material_override = Palette.solid(spec["color"], float(spec["emit"]), false)
		holder.add_child(crystal)

	return holder


func _make_soft_ao_shadow_material() -> StandardMaterial3D:
	var dim := 64
	var img := Image.create_empty(dim, dim, false, Image.FORMAT_RGBA8)
	var half := float(dim - 1) * 0.5
	for y in dim:
		for x in dim:
			var dx := (float(x) - half) / half
			var dy := (float(y) - half) / half
			var r := sqrt(dx * dx + dy * dy)
			var falloff := pow(clampf(1.0 - smoothstep(0.0, 0.98, r), 0.0, 1.0), 1.35)
			img.set_pixel(x, y, Color(0.02, 0.02, 0.02, falloff * 0.84))
	img.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mat
