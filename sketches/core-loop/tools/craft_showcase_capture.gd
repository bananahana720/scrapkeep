extends SceneTree


const Assembly := preload("res://src/presentation/craft/craft_showcase_assembly.gd")
const Palette := preload("res://src/core/palette.gd")

const SIZE := Vector2i(1600, 900)

var _out := ""
var _preset := "smelter_dawn"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--preset="):
			_preset = arg.trim_prefix("--preset=")
	if _out.is_empty() or DisplayServer.get_name() == "headless":
		printerr("craft_showcase_capture: requires Metal/rendered display and -- --out=<abs_dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _run() -> void:
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	RenderingServer.environment_set_volumetric_fog_volume_size(128, 128)

	var packed := load(Assembly.SHOWCASE_SCENE_PATH) as PackedScene
	if packed == null:
		printerr("craft_showcase_capture: failed to load showcase scene")
		quit(1)
		return
	var arena := packed.instantiate() as Node3D
	root.add_child(arena)
	await process_frame

	var rig := arena.get_node_or_null("VistaAtmosphereRig")
	if rig != null and rig.has_method("apply_preset"):
		rig.apply_preset(_preset)
	var receipt := Assembly.assemble_into(arena)

	var cam := Camera3D.new()
	cam.near = 0.2
	cam.far = 1400.0
	arena.add_child(cam)
	cam.make_current()

	for _i in 24:
		await process_frame

	var manifest := {
		"scene": Assembly.SHOWCASE_SCENE_PATH,
		"preset": _preset,
		"size": [SIZE.x, SIZE.y],
		"adapter": RenderingServer.get_video_adapter_name(),
		"sockets_populated": receipt["sockets_populated"],
		"total_surfaces_bound": receipt["total_surfaces_bound"],
		"floor_bound": receipt["floor_bound"],
		"glow_bloom": receipt["glow_bloom"],
		"glow_hdr_threshold": receipt["glow_hdr_threshold"],
		"shots": [],
	}

	await _capture_shot(cam, "showcase_wide_establishing", Vector3(0.0, 8.2, 24.5), Vector3(0.0, 14.0, -45.0), 58.0, manifest)

	await _capture_shot(cam, "showcase_hero_closeup", Vector3(7.4, 4.6, -6.2), Vector3(-0.2, 3.3, -14.2), 42.0, manifest)

	var proof := _build_combat_readability_proof()
	arena.add_child(proof)
	await _capture_shot(cam, "showcase_combat_playcam", Vector3(0.0, 15.8, 22.8), Vector3(0.0, 1.4, -10.5), 52.0, manifest)
	proof.free()

	var mf := FileAccess.open(_out.path_join("showcase_manifest.json"), FileAccess.WRITE)
	mf.store_string(JSON.stringify(manifest, "\t"))
	mf.close()
	arena.free()
	Assembly.reset_for_tests()
	quit(0)


func _capture_shot(cam: Camera3D, id: String, eye: Vector3, target: Vector3, fov: float, manifest: Dictionary) -> void:
	cam.fov = fov
	cam.global_position = eye
	cam.look_at(target, Vector3.UP)
	for _i in 18:
		await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var png_path := _out.path_join(id + ".png")
	if img.save_png(png_path) != OK:
		printerr("craft_showcase_capture: failed saving " + png_path)
		quit(3)
		return
	(manifest["shots"] as Array).append({
		"id": id,
		"path": png_path,
		"eye": [eye.x, eye.y, eye.z],
		"target": [target.x, target.y, target.z],
		"fov": fov,
		"sha256": FileAccess.get_sha256(png_path),
	})


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
