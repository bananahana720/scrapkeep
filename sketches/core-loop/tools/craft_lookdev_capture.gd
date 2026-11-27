extends SceneTree


const Lookdev := preload("res://src/presentation/craft/craft_lookdev.gd")
const Palette := preload("res://src/core/palette.gd")

const VIEW_SIZE := Vector2i(1600, 900)
const HERO_PRESETS := [
	"oxidized_hull_plating",
	"oil_slicked_iron",
	"scorched_concrete",
	"plasma_conduit_core",
]

var _out_dir := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	if _out_dir == "":
		printerr("craft_lookdev_capture: pass --out=<dir>")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		printerr("craft_lookdev_capture: requires a GPU display driver (use --embedded --rendering-driver metal)")
		quit(2)
		return
	root.size = VIEW_SIZE
	root.content_scale_size = VIEW_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var env_node := WorldEnvironment.new()
	env_node.environment = _build_environment()
	root.add_child(env_node)

	var key_sun := DirectionalLight3D.new()
	key_sun.light_color = Palette.APRICOT.lerp(Color.WHITE, 0.35)
	key_sun.light_energy = 1.95
	key_sun.light_specular = 0.28
	key_sun.shadow_enabled = true
	key_sun.shadow_blur = 1.4
	key_sun.rotation_degrees = Vector3(-34.0, 38.0, 0.0)
	root.add_child(key_sun)

	var cool_fill := DirectionalLight3D.new()
	cool_fill.light_color = Palette.DAWN_VIOLET.lerp(Palette.TURQUOISE, 0.45)
	cool_fill.light_energy = 0.72
	cool_fill.shadow_enabled = false
	cool_fill.rotation_degrees = Vector3(-22.0, -132.0, 0.0)
	root.add_child(cool_fill)

	var rim_light := DirectionalLight3D.new()
	rim_light.light_color = Palette.SAND.lerp(Color.WHITE, 0.4)
	rim_light.light_energy = 0.72
	rim_light.light_specular = 0.22
	rim_light.shadow_enabled = false
	rim_light.rotation_degrees = Vector3(-18.0, 162.0, 0.0)
	root.add_child(rim_light)

	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "CombatFloorApron"
	floor_mi.mesh = _build_flat_apron_mesh(44.0, 44.0)
	Lookdev.bind_mesh(floor_mi, "combat_floor_apron")
	root.add_child(floor_mi)

	var wall_mi := MeshInstance3D.new()
	wall_mi.name = "ScorchedRetainingWall"
	wall_mi.mesh = _build_sculpted_retaining_wall(28.0, 5.4, 1.4)
	wall_mi.position = Vector3(0.0, 0.0, -5.6)
	Lookdev.bind_mesh(wall_mi, "scorched_concrete")
	root.add_child(wall_mi)

	var swatch_mesh := _build_lookdev_swatch_mesh()
	var swatch_nodes: Array[MeshInstance3D] = []
	var spacing := 3.15
	var start_x := -spacing * 1.5
	for i in HERO_PRESETS.size():
		var preset_id: String = HERO_PRESETS[i]
		var mi := MeshInstance3D.new()
		mi.name = "Swatch_" + preset_id
		mi.mesh = swatch_mesh
		mi.position = Vector3(start_x + float(i) * spacing, 0.0, 0.0)
		mi.rotation_degrees = Vector3(0.0, -18.0 + float(i) * 11.0, 0.0)
		Lookdev.bind_mesh(mi, preset_id)
		root.add_child(mi)
		swatch_nodes.append(mi)

	var tokens_root := _build_combat_readability_tokens()
	tokens_root.position = Vector3(0.0, 0.02, 5.2)
	tokens_root.visible = false
	root.add_child(tokens_root)

	var cam := Camera3D.new()
	cam.fov = 38.0
	cam.near = 0.1
	cam.far = 250.0
	root.add_child(cam)
	cam.current = true

	var metrics := {
		"tool": "craft_lookdev_capture.gd",
		"adapter": RenderingServer.get_video_adapter_name(),
		"presets": Lookdev.preset_ids(),
		"shots": {},
	}

	cam.position = Vector3(0.2, 2.75, 10.6)
	cam.look_at(Vector3(0.0, 1.15, -0.3), Vector3.UP)
	var img_sheet := await _capture_frame()
	var sheet_path := _out_dir.path_join("lookdev_contact_sheet.png")
	img_sheet.save_png(sheet_path)
	metrics.shots["lookdev_contact_sheet"] = _measure_image(img_sheet, Rect2i(120, 680, 1360, 180))

	cam.fov = 34.0
	cam.position = Vector3(-4.1, 2.15, 5.1)
	cam.look_at(Vector3(-3.0, 1.22, 0.0), Vector3.UP)
	var img_close := await _capture_frame()
	var close_path := _out_dir.path_join("lookdev_closeup_metals.png")
	img_close.save_png(close_path)
	metrics.shots["lookdev_closeup_metals"] = _measure_image(img_close, Rect2i(0, 0, VIEW_SIZE.x, VIEW_SIZE.y))

	tokens_root.visible = true
	cam.fov = 44.0
	cam.position = Vector3(-6.2, 7.6, 13.8)
	cam.look_at(Vector3(0.0, 0.3, 2.2), Vector3.UP)
	var img_floor := await _capture_frame()
	var floor_path := _out_dir.path_join("lookdev_floor_anti_tiling.png")
	img_floor.save_png(floor_path)
	metrics.shots["lookdev_floor_anti_tiling"] = _measure_image(img_floor, Rect2i(980, 560, 420, 220))
	tokens_root.visible = false

	var debug_mat := StandardMaterial3D.new()
	debug_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_mat.vertex_color_use_as_albedo = true
	for mi in swatch_nodes:
		mi.material_override = debug_mat
	cam.fov = 38.0
	cam.position = Vector3(0.2, 2.75, 10.6)
	cam.look_at(Vector3(0.0, 1.15, -0.3), Vector3.UP)
	var img_masks := await _capture_frame()
	var masks_path := _out_dir.path_join("lookdev_vertex_masks_debug.png")
	img_masks.save_png(masks_path)
	metrics.shots["lookdev_vertex_masks_debug"] = _measure_image(img_masks, Rect2i(200, 250, 1200, 420))

	for i in swatch_nodes.size():
		Lookdev.bind_mesh(swatch_nodes[i], HERO_PRESETS[i])

	var f := FileAccess.open(_out_dir.path_join("metrics.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(metrics, "\t"))
	f.close()
	print("craft_lookdev_capture: wrote 4 stills + metrics.json to %s" % _out_dir)
	quit(0)


func _capture_frame() -> Image:
	for _i in 10:
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _build_environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = Palette.workshop_sky()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 0.65
	e.ambient_light_energy = 0.52
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_agx_white = 16.29
	e.tonemap_agx_contrast = 1.22
	e.ssao_enabled = true
	e.ssao_radius = 0.55
	e.ssao_detail = 0.78
	e.ssao_intensity = 2.35
	e.glow_enabled = true
	e.glow_intensity = 0.65
	e.glow_strength = 1.18
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 3.4
	e.glow_hdr_scale = 2.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	return e


func _measure_image(img: Image, region: Rect2i) -> Dictionary:
	var sum_l := 0.0
	var sum_l2 := 0.0
	var sum_sat := 0.0
	var max_l := 0.0
	var min_l := 1.0
	var count := 0
	var step := 4
	var x0 := clampi(region.position.x, 0, img.get_width() - 1)
	var y0 := clampi(region.position.y, 0, img.get_height() - 1)
	var x1 := clampi(region.end.x, 0, img.get_width())
	var y1 := clampi(region.end.y, 0, img.get_height())
	for y in range(y0, y1, step):
		for x in range(x0, x1, step):
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			sum_l += l
			sum_l2 += l * l
			sum_sat += c.s
			max_l = maxf(max_l, l)
			min_l = minf(min_l, l)
			count += 1
	var mean_l := sum_l / maxf(float(count), 1.0)
	var std_l := sqrt(maxf(sum_l2 / maxf(float(count), 1.0) - mean_l * mean_l, 0.0))
	var mean_sat := sum_sat / maxf(float(count), 1.0)
	return {
		"mean_luma": snappedf(mean_l, 0.001),
		"std_luma": snappedf(std_l, 0.001),
		"min_luma": snappedf(min_l, 0.001),
		"max_luma": snappedf(max_l, 0.001),
		"mean_sat": snappedf(mean_sat, 0.001),
		"samples": count,
	}


func _build_flat_apron_mesh(width: float, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 16
	var rows := 16
	var hw := width * 0.5
	var hd := depth * 0.5
	for r in rows:
		for c in cols:
			var u0 := float(c) / float(cols)
			var u1 := float(c + 1) / float(cols)
			var v0 := float(r) / float(rows)
			var v1 := float(r + 1) / float(rows)
			var p00 := Vector3(lerpf(-hw, hw, u0), 0.0, lerpf(-hd, hd, v0))
			var p10 := Vector3(lerpf(-hw, hw, u1), 0.0, lerpf(-hd, hd, v0))
			var p11 := Vector3(lerpf(-hw, hw, u1), 0.0, lerpf(-hd, hd, v1))
			var p01 := Vector3(lerpf(-hw, hw, u0), 0.0, lerpf(-hd, hd, v1))
			_add_floor_quad(st, p00, p10, p11, p01, hw, hd)
	st.generate_tangents()
	return st.commit()


func _add_floor_quad(st: SurfaceTool, p00: Vector3, p10: Vector3, p11: Vector3, p01: Vector3, hw: float, hd: float) -> void:
	var pts := [p00, p10, p11, p00, p11, p01]
	for pt in pts:
		var edge_dist := minf(hw - absf(pt.x), hd - absf(pt.z))
		var rim_grime := clampf(1.0 - edge_dist / 3.5, 0.0, 1.0) * 0.65
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(pt.x * 0.25, pt.z * 0.25))
		st.set_color(Lookdev.encode_mask(0.0, rim_grime, 0.0))
		st.add_vertex(pt)


func _build_lookdev_swatch_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_append_chamfered_box(st, Vector3(0.0, 0.20, 0.0), Vector3(1.12, 0.20, 1.12), 0.06,
		Lookdev.encode_mask(0.08, 0.28, 0.0),
		Lookdev.encode_mask(0.92, 0.08, 0.0),
		Lookdev.encode_mask(0.05, 0.92, 0.0))

	_append_chamfered_box(st, Vector3(0.0, 0.48, 0.0), Vector3(0.86, 0.12, 0.86), 0.025,
		Lookdev.encode_mask(0.04, 0.94, 0.0),
		Lookdev.encode_mask(0.15, 0.88, 0.0),
		Lookdev.encode_mask(0.02, 0.96, 0.0))

	_append_chamfered_box(st, Vector3(0.0, 1.24, 0.0), Vector3(0.98, 0.66, 0.92), 0.09,
		Lookdev.encode_mask(0.08, 0.12, 0.0),
		Lookdev.encode_mask(0.96, 0.04, 0.0),
		Lookdev.encode_mask(0.06, 0.72, 0.0))

	_append_chamfered_box(st, Vector3(0.0, 2.02, 0.0), Vector3(0.82, 0.16, 0.78), 0.07,
		Lookdev.encode_mask(0.12, 0.14, 0.0),
		Lookdev.encode_mask(0.98, 0.02, 0.0),
		Lookdev.encode_mask(0.08, 0.68, 0.0))

	for sx in [-1.0, 1.0]:
		_append_chamfered_box(st, Vector3(sx * 0.98, 1.24, 0.0), Vector3(0.12, 0.48, 0.42), 0.04,
			Lookdev.encode_mask(0.16, 0.22, 0.0),
			Lookdev.encode_mask(0.95, 0.05, 0.0),
			Lookdev.encode_mask(0.04, 0.85, 0.0))

	_append_chamfered_box(st, Vector3(0.0, 1.26, 0.92), Vector3(0.56, 0.30, 0.07), 0.025,
		Lookdev.encode_mask(0.10, 0.88, 0.0),
		Lookdev.encode_mask(0.88, 0.18, 0.0),
		Lookdev.encode_mask(0.05, 0.92, 0.0))

	_append_chamfered_box(st, Vector3(0.0, 1.26, 0.98), Vector3(0.42, 0.14, 0.045), 0.016,
		Lookdev.encode_mask(0.0, 0.0, 1.0),
		Lookdev.encode_mask(0.0, 0.0, 1.0),
		Lookdev.encode_mask(0.0, 0.0, 1.0))

	_append_chamfered_box(st, Vector3(0.0, 2.24, 0.0), Vector3(0.36, 0.09, 0.36), 0.03,
		Lookdev.encode_mask(0.0, 0.0, 1.0),
		Lookdev.encode_mask(0.0, 0.0, 1.0),
		Lookdev.encode_mask(0.0, 0.0, 1.0))

	_append_beveled_cylinder(st, Vector3(0.56, 2.18, 0.42), 0.16, 0.28, 16,
		Lookdev.encode_mask(0.14, 0.18, 0.0),
		Lookdev.encode_mask(0.95, 0.05, 0.0),
		Lookdev.encode_mask(0.04, 0.86, 0.0))

	st.generate_tangents()
	return st.commit()


func _build_sculpted_retaining_wall(width: float, height: float, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_chamfered_box(st, Vector3(0.0, height * 0.5, 0.0), Vector3(width * 0.5, height * 0.5, depth * 0.5), 0.16,
		Lookdev.encode_mask(0.05, 0.16, 0.0),
		Lookdev.encode_mask(0.84, 0.10, 0.0),
		Lookdev.encode_mask(0.04, 0.88, 0.0))
	for i in range(-2, 3):
		var bx := float(i) * 5.6
		_append_chamfered_box(st, Vector3(bx, height * 0.46, depth * 0.5 + 0.35), Vector3(0.65, height * 0.46, 0.45), 0.10,
			Lookdev.encode_mask(0.08, 0.22, 0.0),
			Lookdev.encode_mask(0.90, 0.08, 0.0),
			Lookdev.encode_mask(0.04, 0.92, 0.0))
	st.generate_tangents()
	return st.commit()


func _append_chamfered_box(st: SurfaceTool, center: Vector3, half: Vector3, bevel: float, face_col: Color, bevel_col: Color, base_col: Color) -> void:
	var b := minf(bevel, minf(half.x, minf(half.y, half.z)) * 0.42)
	var ix := half.x - b
	var iy := half.y - b
	var iz := half.z - b

	var top_c := face_col
	var bot_c := base_col
	_add_quad_flat(st, center + Vector3(-ix, half.y, -iz), center + Vector3(ix, half.y, -iz), center + Vector3(ix, half.y, iz), center + Vector3(-ix, half.y, iz), Vector3.UP, top_c)
	_add_quad_flat(st, center + Vector3(-ix, -half.y, iz), center + Vector3(ix, -half.y, iz), center + Vector3(ix, -half.y, -iz), center + Vector3(-ix, -half.y, -iz), Vector3.DOWN, bot_c)
	_add_quad_grad(st, center + Vector3(-ix, -iy, half.z), center + Vector3(ix, -iy, half.z), center + Vector3(ix, iy, half.z), center + Vector3(-ix, iy, half.z), Vector3(0, 0, 1), base_col, face_col)
	_add_quad_grad(st, center + Vector3(ix, -iy, -half.z), center + Vector3(-ix, -iy, -half.z), center + Vector3(-ix, iy, -half.z), center + Vector3(ix, iy, -half.z), Vector3(0, 0, -1), base_col, face_col)
	_add_quad_grad(st, center + Vector3(half.x, -iy, iz), center + Vector3(half.x, -iy, -iz), center + Vector3(half.x, iy, -iz), center + Vector3(half.x, iy, iz), Vector3(1, 0, 0), base_col, face_col)
	_add_quad_grad(st, center + Vector3(-half.x, -iy, -iz), center + Vector3(-half.x, -iy, iz), center + Vector3(-half.x, iy, iz), center + Vector3(-half.x, iy, -iz), Vector3(-1, 0, 0), base_col, face_col)

	_add_quad_flat(st, center + Vector3(-ix, iy, half.z), center + Vector3(ix, iy, half.z), center + Vector3(ix, half.y, iz), center + Vector3(-ix, half.y, iz), Vector3(0, 1, 1).normalized(), bevel_col)
	_add_quad_flat(st, center + Vector3(ix, iy, -half.z), center + Vector3(-ix, iy, -half.z), center + Vector3(-ix, half.y, -iz), center + Vector3(ix, half.y, -iz), Vector3(0, 1, -1).normalized(), bevel_col)
	_add_quad_flat(st, center + Vector3(half.x, iy, iz), center + Vector3(half.x, iy, -iz), center + Vector3(ix, half.y, -iz), center + Vector3(ix, half.y, iz), Vector3(1, 1, 0).normalized(), bevel_col)
	_add_quad_flat(st, center + Vector3(-half.x, iy, -iz), center + Vector3(-half.x, iy, iz), center + Vector3(-ix, half.y, iz), center + Vector3(-ix, half.y, -iz), Vector3(-1, 1, 0).normalized(), bevel_col)

	var low_bevel := bevel_col.lerp(base_col, 0.55)
	_add_quad_flat(st, center + Vector3(-ix, -half.y, iz), center + Vector3(ix, -half.y, iz), center + Vector3(ix, -iy, half.z), center + Vector3(-ix, -iy, half.z), Vector3(0, -1, 1).normalized(), low_bevel)
	_add_quad_flat(st, center + Vector3(ix, -half.y, -iz), center + Vector3(-ix, -half.y, -iz), center + Vector3(-ix, -iy, -half.z), center + Vector3(ix, -iy, -half.z), Vector3(0, -1, -1).normalized(), low_bevel)
	_add_quad_flat(st, center + Vector3(ix, -half.y, iz), center + Vector3(ix, -half.y, -iz), center + Vector3(half.x, -iy, -iz), center + Vector3(half.x, -iy, iz), Vector3(1, -1, 0).normalized(), low_bevel)
	_add_quad_flat(st, center + Vector3(-ix, -half.y, -iz), center + Vector3(-ix, -half.y, iz), center + Vector3(-half.x, -iy, iz), center + Vector3(-half.x, -iy, -iz), Vector3(-1, -1, 0).normalized(), low_bevel)

	_add_quad_flat(st, center + Vector3(ix, -iy, half.z), center + Vector3(half.x, -iy, iz), center + Vector3(half.x, iy, iz), center + Vector3(ix, iy, half.z), Vector3(1, 0, 1).normalized(), bevel_col)
	_add_quad_flat(st, center + Vector3(half.x, -iy, -iz), center + Vector3(ix, -iy, -half.z), center + Vector3(ix, iy, -half.z), center + Vector3(half.x, iy, -iz), Vector3(1, 0, -1).normalized(), bevel_col)
	_add_quad_flat(st, center + Vector3(-ix, -iy, -half.z), center + Vector3(-half.x, -iy, -iz), center + Vector3(-half.x, iy, -iz), center + Vector3(-ix, iy, -half.z), Vector3(-1, 0, -1).normalized(), bevel_col)
	_add_quad_flat(st, center + Vector3(-half.x, -iy, iz), center + Vector3(-ix, -iy, half.z), center + Vector3(-ix, iy, half.z), center + Vector3(-half.x, iy, iz), Vector3(-1, 0, 1).normalized(), bevel_col)

	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var px := center + Vector3(sx * half.x, sy * iy, sz * iz)
				var py := center + Vector3(sx * ix, sy * half.y, sz * iz)
				var pz := center + Vector3(sx * ix, sy * iy, sz * half.z)
				var n := Vector3(sx, sy, sz).normalized()
				var col := bevel_col if sy > 0.0 else low_bevel
				if sx * sy * sz > 0.0:
					_add_tri(st, px, py, pz, n, col)
				else:
					_add_tri(st, px, pz, py, n, col)


func _append_beveled_cylinder(st: SurfaceTool, center: Vector3, radius: float, height: float, segs: int, face_col: Color, bevel_col: Color, base_col: Color) -> void:
	var hh := height * 0.5
	var b := minf(radius * 0.22, hh * 0.35)
	var ir := radius - b
	var y_bot := center.y - hh
	var y_top := center.y + hh
	var y_top_b := y_top - b
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var p_b0 := Vector3(center.x + d0.x * radius, y_bot, center.z + d0.z * radius)
		var p_b1 := Vector3(center.x + d1.x * radius, y_bot, center.z + d1.z * radius)
		var p_m0 := Vector3(center.x + d0.x * radius, y_top_b, center.z + d0.z * radius)
		var p_m1 := Vector3(center.x + d1.x * radius, y_top_b, center.z + d1.z * radius)
		var p_t0 := Vector3(center.x + d0.x * ir, y_top, center.z + d0.z * ir)
		var p_t1 := Vector3(center.x + d1.x * ir, y_top, center.z + d1.z * ir)
		var n_side := (d0 + d1).normalized()
		_add_quad_grad(st, p_b1, p_b0, p_m0, p_m1, n_side, base_col, face_col)
		var n_bev := (n_side + Vector3.UP).normalized()
		_add_quad_flat(st, p_m1, p_m0, p_t0, p_t1, n_bev, bevel_col)
		_add_tri(st, Vector3(center.x, y_top, center.z), p_t1, p_t0, Vector3.UP, face_col)


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	var v1 := b
	var v2 := c
	if (v1 - a).cross(v2 - a).dot(n) > 0.0:
		v1 = c
		v2 = b
	for p in [a, v1, v2]:
		st.set_normal(n)
		st.set_uv(Vector2(p.x + p.z, p.y))
		st.set_color(col)
		st.add_vertex(p)


func _add_quad_flat(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	_add_tri(st, a, b, c, n, col)
	_add_tri(st, a, c, d, n, col)


func _add_quad_grad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col_bot: Color, col_top: Color) -> void:
	_add_tri_grad(st, a, b, c, n, col_bot, col_bot, col_top)
	_add_tri_grad(st, a, c, d, n, col_bot, col_top, col_top)


func _add_tri_grad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var v1 := b
	var v2 := c
	var c1 := cb
	var c2 := cc
	if (v1 - a).cross(v2 - a).dot(n) > 0.0:
		v1 = c
		v2 = b
		c1 = cc
		c2 = cb
	var verts := [a, v1, v2]
	var cols := [ca, c1, c2]
	for i in 3:
		var p: Vector3 = verts[i]
		st.set_normal(n)
		st.set_uv(Vector2(p.x + p.z, p.y))
		st.set_color(cols[i])
		st.add_vertex(p)


func _build_combat_readability_tokens() -> Node3D:
	var holder := Node3D.new()
	holder.name = "CombatReadabilityTokens"

	var keyline := MeshInstance3D.new()
	var km := CylinderMesh.new()
	km.top_radius = 1.65
	km.bottom_radius = 1.65
	km.height = 0.03
	keyline.mesh = km
	keyline.position = Vector3(-3.0, 0.015, 0.0)
	keyline.material_override = Palette.unshaded(Palette.CHARCOAL)
	holder.add_child(keyline)

	var hazard := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 1.48
	hm.bottom_radius = 1.48
	hm.height = 0.04
	hazard.mesh = hm
	hazard.position = Vector3(-3.0, 0.02, 0.0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_texture = Palette.stripe_texture(Palette.HAZARD, Palette.CHARCOAL, 256)
	hmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	hmat.uv1_triplanar = true
	hmat.uv1_scale = Vector3(0.45, 0.45, 0.45)
	hmat.roughness = 0.75
	hazard.material_override = hmat
	holder.add_child(hazard)

	var arc_shadow := MeshInstance3D.new()
	var as_m := CylinderMesh.new()
	as_m.top_radius = 0.58
	as_m.bottom_radius = 0.58
	as_m.height = 0.015
	arc_shadow.mesh = as_m
	arc_shadow.position = Vector3(0.0, 0.008, 0.0)
	arc_shadow.material_override = Palette.unshaded(Palette.CHARCOAL)
	holder.add_child(arc_shadow)

	var arc_mi := MeshInstance3D.new()
	var am := PrismMesh.new()
	am.size = Vector3(0.75, 0.95, 0.75)
	arc_mi.mesh = am
	arc_mi.position = Vector3(0.0, 0.55, 0.0)
	arc_mi.material_override = Palette.solid(Palette.ARC, 2.8, false)
	holder.add_child(arc_mi)

	var amb_shadow := MeshInstance3D.new()
	var ams := CylinderMesh.new()
	ams.top_radius = 0.56
	ams.bottom_radius = 0.56
	ams.height = 0.015
	amb_shadow.mesh = ams
	amb_shadow.position = Vector3(2.8, 0.008, 0.0)
	amb_shadow.material_override = Palette.unshaded(Palette.CHARCOAL)
	holder.add_child(amb_shadow)

	var amber_mi := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.45
	cm.height = 0.9
	amber_mi.mesh = cm
	amber_mi.position = Vector3(2.8, 0.5, 0.0)
	amber_mi.material_override = Palette.solid(Palette.AMBER, 2.6, false)
	holder.add_child(amber_mi)

	return holder
