extends SceneTree


const Palette := preload("res://src/core/palette.gd")
const PropMeshes := preload("res://src/presentation/craft_prop_meshes.gd")
const StakeDevices := preload("res://src/world/stake_devices.gd")
const Altar := preload("res://src/world/ambush_altar.gd")
const Activities := preload("res://src/world/activities.gd")

const WIDTH := 1600
const HEIGHT := 900
const WARMUP_FRAMES := 8

var _out_dir := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)
	if _out_dir == "":
		_out_dir = ProjectSettings.globalize_path("res://../../artifacts/local/greybox-capture")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()


func _run() -> void:
	var root_scene := Node3D.new()
	root.add_child(root_scene)

	var env_node := WorldEnvironment.new()
	env_node.environment = _studio_environment()
	root_scene.add_child(env_node)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.94, 0.84)
	key.light_energy = 2.15
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-42.0, 34.0, 0.0)
	root_scene.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.66, 0.78, 0.92)
	fill.light_energy = 0.65
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-22.0, -135.0, 0.0)
	root_scene.add_child(fill)

	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.95, 0.80, 0.62)
	rim.light_energy = 0.72
	rim.shadow_enabled = false
	rim.rotation_degrees = Vector3(-16.0, 170.0, 0.0)
	root_scene.add_child(rim)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(56.0, 56.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.21, 0.21, 0.22)
	floor_mat.roughness = 0.92
	floor_mat.metallic = 0.04
	Palette.surface_grain(floor_mat)
	floor_mesh.material_override = floor_mat
	root_scene.add_child(floor_mesh)

	var cam := Camera3D.new()
	cam.fov = 38.0
	cam.near = 0.1
	cam.far = 160.0
	cam.current = true
	root_scene.add_child(cam)

	var stage := Node3D.new()
	root_scene.add_child(stage)

	var shots := [
		{
			"id": "stake_devices",
			"cam_pos": Vector3(0.0, 2.7, 7.6),
			"cam_look": Vector3(0.0, 1.35, 0.0),
			"before": Callable(self, "_build_stake_before"),
			"after": Callable(self, "_build_stake_after"),
		},
		{
			"id": "world_props",
			"cam_pos": Vector3(0.0, 2.5, 6.9),
			"cam_look": Vector3(0.0, 1.15, 0.0),
			"before": Callable(self, "_build_world_props_before"),
			"after": Callable(self, "_build_world_props_after"),
		},
		{
			"id": "machinery_arena",
			"cam_pos": Vector3(0.0, 3.6, 10.6),
			"cam_look": Vector3(0.0, 1.55, 0.0),
			"before": Callable(self, "_build_machinery_before"),
			"after": Callable(self, "_build_machinery_after"),
		},
	]

	var metrics := {"shots": []}
	var pairs: Array = []
	for shot in shots:
		cam.look_at_from_position(shot["cam_pos"], shot["cam_look"], Vector3.UP)

		_clear_children(stage)
		(shot["before"] as Callable).call(stage)
		var img_before := await _snap()
		var before_path := _out_dir.path_join("greybox_%s_before.png" % shot["id"])
		img_before.save_png(before_path)

		_clear_children(stage)
		(shot["after"] as Callable).call(stage)
		var img_after := await _snap()
		var after_path := _out_dir.path_join("greybox_%s_after.png" % shot["id"])
		img_after.save_png(after_path)

		var diff := _compute_diff(img_before, img_after)
		diff["id"] = shot["id"]
		diff["before"] = before_path
		diff["after"] = after_path
		metrics["shots"].append(diff)
		pairs.append([img_before, img_after])
		print("SHOT %s: changed=%.2f%% mean_delta=%.2f peak=%d" % [shot["id"], diff["changed_pct"], diff["mean_delta"], diff["peak_delta"]])

	var tw := 800
	var th := 450
	var sheet := Image.create_empty(tw * 2, th * pairs.size(), false, Image.FORMAT_RGB8)
	for r in pairs.size():
		var left: Image = (pairs[r][0] as Image).duplicate()
		var right: Image = (pairs[r][1] as Image).duplicate()
		left.convert(Image.FORMAT_RGB8)
		right.convert(Image.FORMAT_RGB8)
		left.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		right.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(left, Rect2i(Vector2i.ZERO, Vector2i(tw, th)), Vector2i(0, r * th))
		sheet.blit_rect(right, Rect2i(Vector2i.ZERO, Vector2i(tw, th)), Vector2i(tw, r * th))
	for y in sheet.get_height():
		sheet.set_pixel(tw - 1, y, Color(0.9, 0.72, 0.35))
		sheet.set_pixel(tw, y, Color(0.9, 0.72, 0.35))
	var sheet_path := _out_dir.path_join("greybox_before_after_contact.png")
	sheet.save_png(sheet_path)
	metrics["contact_sheet"] = sheet_path

	_clear_children(stage)
	_build_orbit_showcase(stage)
	cam.look_at_from_position(Vector3(0.0, 3.8, 9.8), Vector3(0.0, 1.35, 0.0), Vector3.UP)
	var orbit_angles := [0.0, 90.0, 180.0, 270.0]
	var orbit_sheet := Image.create_empty(tw * 2, th * 2, false, Image.FORMAT_RGB8)
	var orig_key_rot := key.rotation_degrees
	for idx in orbit_angles.size():
		key.rotation_degrees = Vector3(-38.0, float(orbit_angles[idx]), 0.0)
		var frame_img := await _snap()
		var tile := frame_img.duplicate()
		tile.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		var col := idx % 2
		var row := int(floor(float(idx) / 2.0))
		orbit_sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, Vector2i(tw, th)), Vector2i(col * tw, row * th))
	key.rotation_degrees = orig_key_rot
	var orbit_path := _out_dir.path_join("greybox_rotating_light_orbit.png")
	orbit_sheet.save_png(orbit_path)
	metrics["rotating_light_orbit"] = orbit_path

	cam.look_at_from_position(Vector3(0.0, 4.4, 10.6), Vector3(0.2, 1.15, 0.0), Vector3.UP)
	var play_img := await _snap()
	var play_luma := _to_luma(play_img)
	var play_deutan := _to_deuteranopia(play_img)
	cam.look_at_from_position(Vector3(4.1, 2.25, 3.8), Vector3(1.5, 1.45, 0.2), Vector3.UP)
	var closeup_img := await _snap()
	var play_sheet := Image.create_empty(tw * 2, th * 2, false, Image.FORMAT_RGB8)
	var panels := [play_img, play_luma, play_deutan, closeup_img]
	for p_idx in panels.size():
		var tile: Image = (panels[p_idx] as Image).duplicate()
		tile.convert(Image.FORMAT_RGB8)
		tile.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		var col := p_idx % 2
		var row := int(floor(float(p_idx) / 2.0))
		play_sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, Vector2i(tw, th)), Vector2i(col * tw, row * th))
	var play_path := _out_dir.path_join("greybox_play_distance_and_luma.png")
	play_sheet.save_png(play_path)
	metrics["play_distance_and_luma"] = play_path

	var f := FileAccess.open(_out_dir.path_join("metrics.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(metrics, "  "))
	f.close()
	print("greybox_eradication_capture: wrote %s + orbit + play_distance_and_luma" % sheet_path)
	quit(0)


func _studio_environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = Palette.workshop_sky()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.02
	e.glow_enabled = true
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 2.6
	e.glow_intensity = 0.45
	e.ssao_enabled = true
	e.ssao_radius = 0.65
	e.ssao_intensity = 1.6
	return e


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()


func _snap() -> Image:
	for _i in WARMUP_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


static func _compute_diff(a: Image, b: Image) -> Dictionary:
	var da := a.get_data()
	var db := b.get_data()
	var pixels := int(floor(float(da.size()) / 3.0))
	var changed := 0
	var total := 0
	var peak := 0
	var i := 0
	while i < da.size():
		var dr := absi(da[i] - db[i])
		var dg := absi(da[i + 1] - db[i + 1])
		var dbl := absi(da[i + 2] - db[i + 2])
		var m := maxi(dr, maxi(dg, dbl))
		if m > 10:
			changed += 1
		total += dr + dg + dbl
		peak = maxi(peak, m)
		i += 3
	return {
		"changed_pixels": changed,
		"changed_pct": snappedf(100.0 * float(changed) / float(maxi(1, pixels)), 0.01),
		"mean_delta": snappedf(float(total) / float(maxi(1, pixels * 3)), 0.01),
		"peak_delta": peak,
	}


static func _add_mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi



func _build_stake_before(stage: Node3D) -> void:
	var chest := Node3D.new()
	chest.position = Vector3(-2.6, 0.0, 0.0)
	chest.rotation.y = 0.24
	stage.add_child(chest)
	var cb := BoxMesh.new()
	cb.size = Vector3(2.2, 1.3, 1.5)
	_add_mi(chest, cb, Altar.finish(Palette.VERDIGRIS), Vector3.UP * 0.65)
	var cl := BoxMesh.new()
	cl.size = Vector3(2.3, 0.3, 1.6)
	_add_mi(chest, cl, Palette.solid(Palette.COPPER), Vector3.UP * 1.45)
	for i in 2:
		var sb := BoxMesh.new()
		sb.size = Vector3(0.22, 0.22, 0.1)
		_add_mi(chest, sb, Palette.solid(Palette.BRASS), Vector3(-0.175 + 0.35 * i, 1.0, 0.85))
	_add_mi(chest, StakeDevices.gamble_marks_mesh("trade_chest", "bolts"), StakeDevices.bolt_material())
	_add_mi(chest, StakeDevices.gamble_marks_mesh("trade_chest", "chalk"), StakeDevices.chalk_material())

	var shrine := Node3D.new()
	shrine.position = Vector3(0.15, 0.0, -0.3)
	shrine.rotation.y = -0.14
	stage.add_child(shrine)
	var shb := BoxMesh.new()
	shb.size = Vector3(1.6, 2.4, 1.6)
	_add_mi(shrine, shb, Altar.finish(Palette.RUST), Vector3.UP * 1.2)
	var shc := CylinderMesh.new()
	shc.top_radius = 0.5
	shc.bottom_radius = 0.5
	shc.height = 0.3
	_add_mi(shrine, shc, Palette.solid(Palette.HAZARD, 0.9), Vector3.UP * 2.55)
	for i in 3:
		var sb := BoxMesh.new()
		sb.size = Vector3(0.22, 0.22, 0.1)
		_add_mi(shrine, sb, Palette.solid(Palette.BRASS), Vector3(-0.35 + 0.35 * i, 1.0, 0.85))
	_add_mi(shrine, StakeDevices.gamble_marks_mesh("blood_shrine", "bolts"), StakeDevices.bolt_material())
	_add_mi(shrine, StakeDevices.gamble_marks_mesh("blood_shrine", "chalk"), StakeDevices.chalk_material())

	var ward := Node3D.new()
	ward.position = Vector3(2.6, 0.0, 0.0)
	ward.rotation.y = -0.25
	stage.add_child(ward)
	var wp := CylinderMesh.new()
	wp.top_radius = 0.35
	wp.bottom_radius = 0.35
	wp.height = 2.8
	_add_mi(ward, wp, Altar.finish(Palette.BRASS), Vector3.UP * 1.4)
	var wl := CylinderMesh.new()
	wl.top_radius = 0.6
	wl.bottom_radius = 0.6
	wl.height = 0.25
	_add_mi(ward, wl, Palette.solid(Palette.ARC, 0.9), Vector3.UP * 2.9)


func _build_stake_after(stage: Node3D) -> void:
	var chest := Node3D.new()
	chest.position = Vector3(-2.6, 0.0, 0.0)
	chest.rotation.y = 0.24
	stage.add_child(chest)
	_add_mi(chest, PropMeshes.stake_chest_body(), PropMeshes.weathered_material(Palette.VERDIGRIS, 0.74, 0.28, 0.0, "chest_body"))
	_add_mi(chest, PropMeshes.stake_chest_lid(), PropMeshes.weathered_material(Palette.COPPER, 0.58, 0.42, 0.0, "chest_lid"), Vector3.UP * 1.45)
	for i in 2:
		_add_mi(chest, PropMeshes.stake_tier_rivet(), StakeDevices.bolt_material(), Vector3(-0.175 + 0.35 * i, 1.0, 0.85))
	_add_mi(chest, StakeDevices.gamble_marks_mesh("trade_chest", "bolts"), StakeDevices.bolt_material())
	_add_mi(chest, StakeDevices.gamble_marks_mesh("trade_chest", "chalk"), StakeDevices.chalk_material())

	var shrine := Node3D.new()
	shrine.position = Vector3(0.15, 0.0, -0.3)
	shrine.rotation.y = -0.14
	stage.add_child(shrine)
	_add_mi(shrine, PropMeshes.stake_shrine_body(), PropMeshes.weathered_material(Palette.RUST, 0.78, 0.24, 0.0, "shrine_body", true, 2.6))
	_add_mi(shrine, PropMeshes.stake_shrine_basin(), PropMeshes.weathered_material(Palette.HAZARD.darkened(0.24), 0.72, 0.22, 0.16, "shrine_basin", true, 1.8), Vector3.UP * 2.55)
	for i in 3:
		_add_mi(shrine, PropMeshes.stake_tier_rivet(), StakeDevices.bolt_material(), Vector3(-0.35 + 0.35 * i, 1.62, 0.85))
	_add_mi(shrine, StakeDevices.gamble_marks_mesh("blood_shrine", "bolts"), StakeDevices.bolt_material())
	_add_mi(shrine, StakeDevices.gamble_marks_mesh("blood_shrine", "chalk"), StakeDevices.chalk_material())

	var ward := Node3D.new()
	ward.position = Vector3(2.6, 0.0, 0.0)
	ward.rotation.y = -0.25
	stage.add_child(ward)
	_add_mi(ward, PropMeshes.stake_ward_pillar(), PropMeshes.weathered_material(Palette.BRASS.darkened(0.18), 0.50, 0.50, 0.0, "ward_pillar", true, 2.2))
	_add_mi(ward, PropMeshes.stake_ward_lantern(), PropMeshes.weathered_material(Palette.ARC.darkened(0.36), 0.94, 0.0, 0.28, "ward_lantern", true, 2.0), Vector3.UP * 2.9)



func _build_world_props_before(stage: Node3D) -> void:
	var radio := Node3D.new()
	radio.position = Vector3(-2.4, 0.0, 0.0)
	radio.rotation.y = 0.3
	stage.add_child(radio)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.1
	pole.height = 2.4
	var plain_copper := StandardMaterial3D.new()
	plain_copper.albedo_color = Palette.COPPER
	plain_copper.metallic = 0.7
	plain_copper.roughness = 0.45
	var plain_brass := StandardMaterial3D.new()
	plain_brass.albedo_color = Palette.BRASS
	plain_brass.metallic = 0.7
	plain_brass.roughness = 0.45
	_add_mi(radio, pole, plain_copper, Vector3.UP * 1.2)
	var bowl := SphereMesh.new()
	bowl.radius = 0.55
	bowl.height = 0.35
	bowl.is_hemisphere = true
	_add_mi(radio, bowl, plain_brass, Vector3(0.0, 2.2, 0.0), Vector3(deg_to_rad(-120.0), 0.0, 0.0))
	var bulb := SphereMesh.new()
	bulb.radius = 0.12
	bulb.height = 0.24
	_add_mi(radio, bulb, Palette.solid(Palette.ARC, 2.0), Vector3.UP * 2.55)

	var clock := Node3D.new()
	clock.position = Vector3(-0.3, 1.5, 0.2)
	stage.add_child(clock)
	var cm := BoxMesh.new()
	cm.size = Vector3(1.5, 1.5, 0.1)
	_add_mi(clock, cm, Palette.solid(Palette.BRASS))
	var fm := BoxMesh.new()
	fm.size = Vector3(1.2, 1.2, 0.06)
	_add_mi(clock, fm, Palette.solid(Palette.LEDGER), Vector3(0.0, 0.0, 0.06))
	var hm := BoxMesh.new()
	hm.size = Vector3(0.1, 0.45, 0.04)
	_add_mi(clock, hm, Palette.solid(Palette.CHARCOAL), Vector3(0.0, 0.225, 0.1))
	var mm := BoxMesh.new()
	mm.size = Vector3(0.07, 0.63, 0.04)
	_add_mi(clock, mm, Palette.solid(Palette.CHARCOAL), Vector3(-0.15, 0.27, 0.12), Vector3(0.0, 0.0, deg_to_rad(30.0)))

	var glove := Node3D.new()
	glove.position = Vector3(1.6, 1.45, 0.3)
	glove.basis = (Basis(Vector3.BACK, 0.22) * Basis(Vector3.RIGHT, -PI * 0.5)).scaled(Vector3.ONE * 1.1)
	stage.add_child(glove)
	var pm := BoxMesh.new()
	pm.size = Vector3(0.62, 0.2, 0.66)
	_add_mi(glove, pm, Palette.solid(Palette.COPPER))
	for k in 4:
		var cap := CapsuleMesh.new()
		cap.radius = 0.08
		cap.height = 0.5 - absf(k - 1.5) * 0.08
		_add_mi(glove, cap, Palette.solid(Palette.COPPER), Vector3(-0.23 + k * 0.155, -0.02, -0.33 - cap.height * 0.4), Vector3(PI * 0.5, (k - 1.5) * 0.12, 0.0))
	var tcap := CapsuleMesh.new()
	tcap.radius = 0.09
	tcap.height = 0.4
	_add_mi(glove, tcap, Palette.solid(Palette.COPPER), Vector3(-0.42, -0.02, -0.02), Vector3(PI * 0.5, 1.0, 0.0))
	var cfm := BoxMesh.new()
	cfm.size = Vector3(0.7, 0.24, 0.26)
	_add_mi(glove, cfm, Palette.solid(Palette.LEDGER), Vector3(0.0, 0.01, 0.42))

	var plate_n := Node3D.new()
	plate_n.position = Vector3(0.3, 0.0, 2.3)
	stage.add_child(plate_n)
	var pr := CylinderMesh.new()
	pr.top_radius = Activities.PLATE_RADIUS
	pr.bottom_radius = Activities.PLATE_RADIUS * 1.08
	pr.height = Activities.PLATE_H
	_add_mi(plate_n, pr, Palette.solid(Palette.CHARCOAL), Vector3.UP * Activities.PLATE_H * 0.5)
	var pf := CylinderMesh.new()
	pf.top_radius = Activities.PLATE_FACE_RADIUS
	pf.bottom_radius = Activities.PLATE_FACE_RADIUS
	pf.height = Activities.PLATE_H
	_add_mi(plate_n, pf, Palette.solid(Palette.AMBER, 0.55), Vector3.UP * (Activities.PLATE_H * 0.5 + 0.02))


func _build_world_props_after(stage: Node3D) -> void:
	var radio := Node3D.new()
	radio.position = Vector3(-2.4, 0.0, 0.0)
	radio.rotation.y = 0.3
	stage.add_child(radio)
	_add_mi(radio, PropMeshes.radio_mast(), PropMeshes.weathered_material(Palette.COPPER, 0.48, 0.65, 0.0, "radio_metal"), Vector3.UP * 1.2)
	_add_mi(radio, PropMeshes.radio_dish(), PropMeshes.weathered_material(Palette.BRASS, 0.48, 0.65, 0.0, "radio_metal"), Vector3(0.0, 2.2, 0.0), Vector3(deg_to_rad(-120.0), 0.0, 0.0))
	_add_mi(radio, PropMeshes.radio_lamp_housing(), Palette.solid(Palette.ARC, 0.75), Vector3.UP * 2.55)

	var clock := Node3D.new()
	clock.position = Vector3(-0.3, 1.5, 0.2)
	stage.add_child(clock)
	_add_mi(clock, PropMeshes.door_clock_casing(1.5), PropMeshes.weathered_material(Palette.BRASS, 0.52, 0.52, 0.0, "clock_brass"))
	_add_mi(clock, PropMeshes.door_clock_face(1.5), PropMeshes.weathered_material(Palette.LEDGER.darkened(0.12), 0.78, 0.06, 0.0, "clock_face"), Vector3(0.0, 0.0, 0.05))
	_add_mi(clock, PropMeshes.door_clock_hand(0.1, 0.45), Palette.solid(Palette.CHARCOAL), Vector3(0.0, 0.225, 0.1))
	_add_mi(clock, PropMeshes.door_clock_hand(0.07, 0.63), Palette.solid(Palette.CHARCOAL), Vector3(-0.15, 0.27, 0.12), Vector3(0.0, 0.0, deg_to_rad(30.0)))

	var glove := Node3D.new()
	glove.position = Vector3(1.6, 1.45, 0.3)
	glove.basis = (Basis(Vector3.BACK, 0.22) * Basis(Vector3.RIGHT, -PI * 0.5)).scaled(Vector3.ONE * 1.1)
	stage.add_child(glove)
	_add_mi(glove, PropMeshes.work_glove_leather(), PropMeshes.weathered_material(Palette.COPPER, 0.78, 0.12, 0.0, "glove_leather"))
	_add_mi(glove, PropMeshes.work_glove_cuff(), PropMeshes.weathered_material(Palette.LEDGER.darkened(0.16), 0.88, 0.02, 0.0, "glove_cuff"))
	_add_mi(glove, PropMeshes.work_glove_peg(), PropMeshes.weathered_material(Palette.CHARCOAL, 0.65, 0.45, 0.0, "glove_peg"))

	var plate_n := Node3D.new()
	plate_n.position = Vector3(0.3, 0.0, 2.3)
	stage.add_child(plate_n)
	_add_mi(plate_n, PropMeshes.lore_plate_rim(Activities.PLATE_RADIUS, Activities.PLATE_H), PropMeshes.weathered_material(Palette.CHARCOAL, 0.72, 0.35, 0.0, "plate_rim"), Vector3.UP * Activities.PLATE_H * 0.5)
	_add_mi(plate_n, PropMeshes.lore_plate_face(Activities.PLATE_FACE_RADIUS, Activities.PLATE_H), Palette.solid(Palette.AMBER, 0.55), Vector3.UP * (Activities.PLATE_H * 0.5 + 0.02))



func _build_machinery_before(stage: Node3D) -> void:
	var dial := Node3D.new()
	dial.position = Vector3(-3.8, 0.0, 0.0)
	dial.rotation.y = 0.22
	stage.add_child(dial)
	var dp := CylinderMesh.new()
	dp.top_radius = 0.2
	dp.bottom_radius = 0.2
	dp.height = 3.0
	_add_mi(dial, dp, Palette.solid(Palette.COPPER), Vector3.UP * 1.5)
	var df := CylinderMesh.new()
	df.top_radius = 1.1
	df.bottom_radius = 1.1
	df.height = 0.15
	_add_mi(dial, df, Palette.solid(Palette.SAND), Vector3.UP * 3.4, Vector3(PI * 0.5, 0.0, 0.0))
	var dr := BoxMesh.new()
	dr.size = Vector3(0.2, 0.5, 0.05)
	_add_mi(dial, dr, Palette.solid(Palette.RUST), Vector3(0.75, 3.95, 0.1), Vector3(0.0, 0.0, -0.8))
	var dn := BoxMesh.new()
	dn.size = Vector3(0.12, 0.95, 0.05)
	_add_mi(dial, dn, Palette.solid(Palette.CHARCOAL), Vector3(0.0, 3.4, 0.12), Vector3(0.0, 0.0, -0.65))

	var sluice := Node3D.new()
	sluice.position = Vector3(-1.3, 0.0, 0.6)
	sluice.rotation.y = 0.18
	stage.add_child(sluice)
	var sw := TorusMesh.new()
	sw.inner_radius = 0.75
	sw.outer_radius = 1.0
	_add_mi(sluice, sw, Palette.solid(Palette.RUST), Vector3.UP * 1.6, Vector3(PI * 0.5, 0.0, 0.0))
	var sp := CylinderMesh.new()
	sp.top_radius = 0.25
	sp.bottom_radius = 0.35
	sp.height = 1.6
	_add_mi(sluice, sp, Palette.solid(Palette.COPPER), Vector3.UP * 0.8)

	var vent := Node3D.new()
	vent.position = Vector3(1.8, 0.0, 1.4)
	stage.add_child(vent)
	var vd := CylinderMesh.new()
	vd.top_radius = 1.6
	vd.bottom_radius = 1.6
	vd.height = 0.1
	_add_mi(vent, vd, Palette.solid(Palette.ARC, 0.6), Vector3.UP * 0.06)
	var vn := CylinderMesh.new()
	vn.top_radius = 0.7
	vn.bottom_radius = 0.9
	vn.height = 3.0
	_add_mi(vent, vn, Palette.solid(Palette.VERDIGRIS), Vector3(0.6, 1.5, -1.8))

	var door := BoxMesh.new()
	door.size = Vector3(2.8, 3.4, 0.6)
	_add_mi(stage, door, Palette.striped(Palette.COPPER, Palette.CHARCOAL), Vector3(4.3, 1.7, -1.2), Vector3(0.0, -0.32, 0.0))


func _build_machinery_after(stage: Node3D) -> void:
	var dial := Node3D.new()
	dial.position = Vector3(-3.8, 0.0, 0.0)
	dial.rotation.y = 0.22
	stage.add_child(dial)
	_add_mi(dial, PropMeshes.dial_post(), PropMeshes.weathered_material(Palette.COPPER, 0.62, 0.44, 0.0, "dial_post"), Vector3.UP * 1.5)
	_add_mi(dial, PropMeshes.dial_bezel(), PropMeshes.weathered_material(Palette.SAND.darkened(0.08), 0.78, 0.10, 0.0, "dial_face"), Vector3.UP * 3.4, Vector3(PI * 0.5, 0.0, 0.0))
	_add_mi(dial, PropMeshes.dial_redline(), Palette.solid(Palette.RUST), Vector3(0.58, 3.84, 0.1), Vector3(0.0, 0.0, -0.8))
	_add_mi(dial, PropMeshes.dial_needle(), Palette.solid(Palette.CHARCOAL), Vector3(0.0, 3.4, 0.12), Vector3(0.0, 0.0, -0.65))

	var sluice := Node3D.new()
	sluice.position = Vector3(-1.3, 0.0, 0.6)
	sluice.rotation.y = 0.32
	stage.add_child(sluice)
	_add_mi(sluice, PropMeshes.sluice_wheel(), PropMeshes.weathered_material(Palette.RUST, 0.68, 0.38, 0.0, "sluice_wheel", true, 2.2), Vector3(0.0, 1.6, 0.38), Vector3(PI * 0.5, 0.0, 0.0))
	_add_mi(sluice, PropMeshes.sluice_post(), PropMeshes.weathered_material(Palette.COPPER, 0.62, 0.44, 0.0, "sluice_post", true, 2.2), Vector3.UP * 0.8)

	var vent := Node3D.new()
	vent.position = Vector3(1.8, 0.0, 1.5)
	stage.add_child(vent)
	_add_mi(vent, PropMeshes.quench_vent_pad(1.6), PropMeshes.weathered_material(Palette.ARC.darkened(0.42), 0.95, 0.0, 0.32, "quench_coolant"), Vector3.UP * 0.06)
	_add_mi(vent, PropMeshes.quench_vent_grate(1.6), PropMeshes.weathered_material(Palette.CHARCOAL, 0.68, 0.42, 0.0, "quench_grate"), Vector3.UP * 0.06)
	_add_mi(vent, PropMeshes.vent_nozzle(), PropMeshes.weathered_material(Palette.VERDIGRIS, 0.72, 0.28, 0.0, "vent_nozzle"), Vector3(0.6, 1.5, -2.5))

	_add_mi(stage, PropMeshes.valve_door_slab(Vector3(2.8, 3.4, 0.6)), PropMeshes.weathered_material(Palette.COPPER, 0.68, 0.35, 0.0, "valve_door"), Vector3(4.3, 1.7, -1.2), Vector3(0.0, -0.32, 0.0))


func _build_orbit_showcase(stage: Node3D) -> void:
	var chest := Node3D.new()
	chest.position = Vector3(-4.4, 0.0, 0.4)
	chest.rotation.y = 0.28
	stage.add_child(chest)
	_add_mi(chest, PropMeshes.stake_chest_body(), PropMeshes.weathered_material(Palette.VERDIGRIS, 0.72, 0.30, 0.0, "chest_body", true, 2.4))
	_add_mi(chest, PropMeshes.stake_chest_lid(), PropMeshes.weathered_material(Palette.COPPER, 0.52, 0.48, 0.0, "chest_lid", true, 2.0), Vector3.UP * 1.45)
	for i in 2:
		_add_mi(chest, PropMeshes.stake_tier_rivet(), StakeDevices.bolt_material(), Vector3(-0.175 + 0.35 * i, 1.0, 0.85))
	_add_mi(chest, StakeDevices.gamble_marks_mesh("trade_chest", "bolts"), StakeDevices.bolt_material())
	_add_mi(chest, StakeDevices.gamble_marks_mesh("trade_chest", "chalk"), StakeDevices.chalk_material())

	var shrine := Node3D.new()
	shrine.position = Vector3(-1.8, 0.0, -0.7)
	shrine.rotation.y = 0.1
	stage.add_child(shrine)
	_add_mi(shrine, PropMeshes.stake_shrine_body(), PropMeshes.weathered_material(Palette.RUST, 0.78, 0.24, 0.0, "shrine_body", true, 2.6))
	_add_mi(shrine, PropMeshes.stake_shrine_basin(), PropMeshes.weathered_material(Palette.HAZARD.darkened(0.24), 0.72, 0.22, 0.16, "shrine_basin", true, 1.8), Vector3.UP * 2.55)
	for i in 3:
		_add_mi(shrine, PropMeshes.stake_tier_rivet(), StakeDevices.bolt_material(), Vector3(-0.35 + 0.35 * i, 1.62, 0.85))
	_add_mi(shrine, StakeDevices.gamble_marks_mesh("blood_shrine", "bolts"), StakeDevices.bolt_material())

	var ward := Node3D.new()
	ward.position = Vector3(0.35, 0.0, -0.45)
	stage.add_child(ward)
	_add_mi(ward, PropMeshes.stake_ward_pillar(), PropMeshes.weathered_material(Palette.BRASS.darkened(0.18), 0.50, 0.50, 0.0, "ward_pillar", true, 2.2))
	_add_mi(ward, PropMeshes.stake_ward_lantern(), PropMeshes.weathered_material(Palette.ARC.darkened(0.36), 0.94, 0.0, 0.28, "ward_lantern", true, 2.0), Vector3.UP * 2.9)

	var sluice := Node3D.new()
	sluice.position = Vector3(2.2, 0.0, 0.65)
	sluice.rotation.y = -0.34
	stage.add_child(sluice)
	_add_mi(sluice, PropMeshes.sluice_wheel(), PropMeshes.weathered_material(Palette.RUST, 0.68, 0.38, 0.0, "sluice_wheel", true, 2.2), Vector3(0.0, 1.6, 0.38), Vector3(PI * 0.5, 0.0, 0.0))
	_add_mi(sluice, PropMeshes.sluice_post(), PropMeshes.weathered_material(Palette.COPPER, 0.62, 0.44, 0.0, "sluice_post", true, 2.2), Vector3.UP * 0.8)

	var vent := Node3D.new()
	vent.position = Vector3(-0.3, 0.0, 2.3)
	stage.add_child(vent)
	_add_mi(vent, PropMeshes.quench_vent_pad(1.5), PropMeshes.weathered_material(Palette.ARC.darkened(0.42), 0.95, 0.0, 0.32, "quench_coolant"), Vector3.UP * 0.06)
	_add_mi(vent, PropMeshes.quench_vent_grate(1.5), PropMeshes.weathered_material(Palette.CHARCOAL, 0.56, 0.52, 0.0, "quench_grate", true, 2.4), Vector3.UP * 0.06)

	var door := Node3D.new()
	door.position = Vector3(4.9, 1.7, -1.3)
	door.rotation.y = -0.36
	stage.add_child(door)
	_add_mi(door, PropMeshes.valve_door_slab(Vector3(2.8, 3.4, 0.6)), PropMeshes.weathered_material(Palette.COPPER, 0.68, 0.35, 0.0, "valve_door", true, 3.0))
	var clock := Node3D.new()
	clock.position = Vector3(0.0, 0.35, 0.38)
	door.add_child(clock)
	_add_mi(clock, PropMeshes.door_clock_casing(1.3), PropMeshes.weathered_material(Palette.BRASS.darkened(0.14), 0.48, 0.52, 0.0, "clock_brass", true, 2.0))
	_add_mi(clock, PropMeshes.door_clock_face(1.3), PropMeshes.weathered_material(Palette.LEDGER.darkened(0.14), 0.82, 0.04, 0.0, "clock_face", true, 1.8), Vector3(0.0, 0.0, 0.05))
	_add_mi(clock, PropMeshes.door_clock_hand(0.09, 0.38), Palette.solid(Palette.CHARCOAL), Vector3(0.0, 0.19, 0.1))


static func _to_luma(img: Image) -> Image:
	var src: Image = img.duplicate() as Image
	src.convert(Image.FORMAT_RGB8)
	var data: PackedByteArray = src.get_data()
	var out := PackedByteArray()
	out.resize(data.size())
	var i := 0
	while i < data.size():
		var y := clampi(roundi(0.2126 * float(data[i]) + 0.7152 * float(data[i + 1]) + 0.0722 * float(data[i + 2])), 0, 255)
		out[i] = y
		out[i + 1] = y
		out[i + 2] = y
		i += 3
	return Image.create_from_data(src.get_width(), src.get_height(), false, Image.FORMAT_RGB8, out)


static func _to_deuteranopia(img: Image) -> Image:
	var src: Image = img.duplicate() as Image
	src.convert(Image.FORMAT_RGB8)
	var data: PackedByteArray = src.get_data()
	var out := PackedByteArray()
	out.resize(data.size())
	var i := 0
	while i < data.size():
		var r := float(data[i])
		var g := float(data[i + 1])
		var b := float(data[i + 2])
		out[i] = clampi(roundi(0.367322 * r + 0.860646 * g - 0.227968 * b), 0, 255)
		out[i + 1] = clampi(roundi(0.280085 * r + 0.672501 * g + 0.047413 * b), 0, 255)
		out[i + 2] = clampi(roundi(-0.011820 * r + 0.042940 * g + 0.968881 * b), 0, 255)
		i += 3
	return Image.create_from_data(src.get_width(), src.get_height(), false, Image.FORMAT_RGB8, out)
