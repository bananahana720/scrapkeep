extends SceneTree


const SCENE_PATH := "res://src/presentation/craft/craft_showcase_arena.tscn"
const Palette := preload("res://src/core/palette.gd")
const AppShell := preload("res://src/core/app_shell.gd")

const SIZE := Vector2i(1600, 900)

var _out := ""
var _preset := "smelter_dawn"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--preset="):
			_preset = arg.trim_prefix("--preset=")
	if _out.is_empty() or AppShell.headless():
		printerr("craft_vista_capture: requires Metal/rendered display and -- --out=<abs_dir>")
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
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		printerr("craft_vista_capture: failed to load " + SCENE_PATH)
		quit(1)
		return
	var arena := packed.instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	var rig = arena.get_node_or_null("VistaAtmosphereRig")
	if rig != null and rig.has_method("apply_preset"):
		rig.apply_preset(_preset)

	var cam := Camera3D.new()
	cam.near = 0.25
	cam.far = 1400.0
	arena.add_child(cam)
	cam.make_current()

	for _i in 24:
		await process_frame

	var manifest := {
		"scene": SCENE_PATH,
		"preset": _preset,
		"size": [SIZE.x, SIZE.y],
		"adapter": RenderingServer.get_video_adapter_name(),
		"shots": [],
	}

	await _capture_shot(cam, "wide_vista", Vector3(0.0, 7.6, 25.5), Vector3(0.0, 28.0, -180.0), 60.0, manifest)

	var proof := _build_combat_readability_proof()
	arena.add_child(proof)
	await _capture_shot(cam, "combat_lane_playcam", Vector3(0.0, 15.5, 22.5), Vector3(0.0, 1.0, -12.0), 52.0, manifest)
	proof.free()

	await _capture_shot(cam, "gantry_godrays", Vector3(-19.5, 4.8, 13.0), Vector3(8.0, 20.0, -56.0), 58.0, manifest)

	var mf := FileAccess.open(_out.path_join("capture_manifest.json"), FileAccess.WRITE)
	mf.store_string(JSON.stringify(manifest, "\t"))
	mf.close()
	arena.free()
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
		printerr("craft_vista_capture: failed saving " + png_path)
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
	holder.name = "ReadabilityProofStage"

	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.05
	sphere.height = 2.1
	ball.mesh = sphere
	ball.position = Vector3(-4.5, 1.05, 3.0)
	var ball_mat := Palette.solid(Palette.STEEL.lerp(Palette.CHARCOAL, 0.32), 0.0, false)
	ball_mat.metallic = 0.48
	ball_mat.roughness = 0.32
	ball.material_override = ball_mat
	holder.add_child(ball)

	var hoop := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.18
	hoop.mesh = torus
	hoop.position = Vector3(-4.5, 1.05, 3.0)
	hoop.material_override = Palette.solid(Palette.ARC, 1.6, false)
	holder.add_child(hoop)

	var keyline := MeshInstance3D.new()
	var key_cyl := CylinderMesh.new()
	key_cyl.top_radius = 4.6
	key_cyl.bottom_radius = 4.6
	key_cyl.height = 0.04
	keyline.mesh = key_cyl
	keyline.position = Vector3(5.0, 0.03, -2.5)
	keyline.material_override = Palette.unshaded(Palette.CHARCOAL)
	holder.add_child(keyline)

	var danger := MeshInstance3D.new()
	var d_cyl := CylinderMesh.new()
	d_cyl.top_radius = 4.32
	d_cyl.bottom_radius = 4.32
	d_cyl.height = 0.05
	danger.mesh = d_cyl
	danger.position = Vector3(5.0, 0.045, -2.5)
	var hazard_mat := Palette.hazard_stripe().duplicate() as StandardMaterial3D
	hazard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	danger.material_override = hazard_mat
	holder.add_child(danger)

	for spec in [
		{"pos": Vector3(0.0, 0.95, -7.5), "color": Palette.ARC, "emit": 1.45},
		{"pos": Vector3(-9.0, 0.95, -6.5), "color": Palette.COBALT, "emit": 1.65},
	]:
		var base_ring := MeshInstance3D.new()
		var ring_cyl := CylinderMesh.new()
		ring_cyl.top_radius = 0.95
		ring_cyl.bottom_radius = 1.05
		ring_cyl.height = 0.06
		base_ring.mesh = ring_cyl
		base_ring.position = Vector3((spec["pos"] as Vector3).x, 0.04, (spec["pos"] as Vector3).z)
		base_ring.material_override = Palette.solid(Palette.CHARCOAL, 0.0, false)
		holder.add_child(base_ring)

		var crystal := MeshInstance3D.new()
		var oct := SphereMesh.new()
		oct.radial_segments = 6
		oct.rings = 2
		oct.radius = 0.65
		oct.height = 1.45
		crystal.mesh = oct
		crystal.position = spec["pos"]
		crystal.material_override = Palette.solid(spec["color"], float(spec["emit"]), false)
		holder.add_child(crystal)

	return holder
