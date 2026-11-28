extends SceneTree


const Accretion := preload("res://src/build/accretion.gd")
const BallLooks := preload("res://src/presentation/ball_looks.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const Palette := preload("res://src/core/palette.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const AppShell := preload("res://src/core/app_shell.gd")

const SIZE := Vector2i(1440, 900)
const SAMPLE_PARTS := ["hot_rivets", "cross_split", "spiral_wave", "chain_arc", "dash_vane", "rivet_plating"]

var out := ""
var stage_root: Node3D
var camera: Camera3D
var records := []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out.is_empty() or AppShell.headless():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _run() -> void:
	stage_root = Node3D.new()
	root.add_child(stage_root)
	_setup_studio_world()
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.far = 300.0
	stage_root.add_child(camera)
	camera.current = true

	await _capture_ball_gear()
	await _capture_weapon_ring()
	await _capture_bolts_volley()
	await _capture_hero_combo()
	await _capture_play_distance_and_variants()
	await _capture_recoil_strip_60hz()

	var f := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"size": [SIZE.x, SIZE.y], "adapter": RenderingServer.get_video_adapter_name(),
		"frames": records}, "\t"))
	f.close()
	stage_root.free()
	quit(0)


func _setup_studio_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("5a7394")
	sky_mat.sky_horizon_color = Color("d8b48e")
	sky_mat.ground_bottom_color = Color("5e4b3c")
	sky_mat.ground_horizon_color = Color("b68d65")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_hdr_threshold = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	stage_root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe6c4")
	sun.light_energy = 1.85
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-38.0, 32.0, 0.0)
	stage_root.add_child(sun)

	var rim := DirectionalLight3D.new()
	rim.light_color = Color("9ab8e4")
	rim.light_energy = 0.55
	rim.rotation_degrees = Vector3(-18.0, -145.0, 0.0)
	stage_root.add_child(rim)

	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90.0, 90.0)
	floor_mi.mesh = plane
	var floor_mat := Palette.solid(Color("a4815d"), 0.0)
	floor_mat.roughness = 0.92
	floor_mi.material_override = floor_mat
	stage_root.add_child(floor_mi)


func _clear_scene_holder(holder: Node3D) -> void:
	if holder != null and is_instance_valid(holder):
		holder.get_parent().remove_child(holder)
		holder.free()


func _shot(id: String, eye: Vector3, target: Vector3) -> void:
	camera.look_at_from_position(eye, target, Vector3.UP)
	for _i in 10:
		await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := out.path_join(id + ".png")
	if img.save_png(path) != OK:
		quit(3)
	records.append({"id": id, "eye": [eye.x, eye.y, eye.z], "target": [target.x, target.y, target.z],
		"sha256": FileAccess.get_sha256(path)})


func _make_ball_core(parent: Node3D, radius := 0.98) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, 1.45, 0.0)
	parent.add_child(pivot)
	var hull := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	sph.radial_segments = 32
	sph.rings = 16
	hull.mesh = sph
	var hull_mat := Palette.solid(Color("2e4449"), 0.0)
	hull_mat.metallic = 0.35
	hull_mat.roughness = 0.52
	hull.material_override = hull_mat
	pivot.add_child(hull)
	return pivot


func _capture_ball_gear() -> void:
	var holder := Node3D.new()
	stage_root.add_child(holder)
	var pivot := _make_ball_core(holder, 1.01 * Accretion.shell_scale(3))
	var acc := Accretion.new()
	acc.setup()
	pivot.add_child(acc)
	acc.show_build(180.0, SAMPLE_PARTS, [], 3)
	for _i in 80:
		acc._process(1.0 / 60.0)
	await _shot("ball_gear", Vector3(2.85, 2.35, 3.35), Vector3(0.0, 1.48, 0.0))
	_clear_scene_holder(holder)


func _capture_weapon_ring() -> void:
	var holder := Node3D.new()
	stage_root.add_child(holder)
	var ball := Node3D.new()
	ball.position = Vector3(0.0, 1.45, 0.0)
	holder.add_child(ball)
	var hero := HeroAssets.new()
	holder.add_child(hero)
	var fitted := hero.fit_shell_into(ball, "pylon_engineer", "", 3, {"class": Palette.ARC})
	var pod: Node3D = fitted.get("pod")
	var ring: Node3D = pod.get_node_or_null("WeaponRing") if pod != null else null
	if ring != null and hero.has_method("sync_weapon_rig"):
		var all_bits := ShotBits.bit("pierce") | ShotBits.bit("split") | ShotBits.bit("heat") | ShotBits.bit("bounce")
		hero.sync_weapon_rig(pod, all_bits, ["hot_rivets", "cross_split", "spiral_wave", "chain_arc", "rime_rounds"])
		var rig := ring.get_node_or_null("WeaponRigFx")
		if rig != null:
			rig.on_shot_fired("charged", 1.35)
			rig.step(0.016, {"charge": 0.85, "reloading": false}, false)
	await _shot("weapon_ring", Vector3(2.45, 2.15, -2.95), Vector3(0.0, 1.48, -0.45))
	_clear_scene_holder(holder)


func _capture_bolts_volley() -> void:
	var holder := Node3D.new()
	stage_root.add_child(holder)
	var bolts := Bolts.new()
	bolts.setup()
	holder.add_child(bolts)
	var configs := [
		{"y": 1.85, "x": -1.45, "bits": ShotBits.bit("pierce"), "color": Palette.LEDGER, "ws": 1.25},
		{"y": 1.65, "x": -0.88, "bits": ShotBits.bit("bounce"), "color": Palette.ARC, "ws": 1.18},
		{"y": 1.50, "x": -0.30, "bits": ShotBits.bit("split"), "color": Palette.BRASS, "ws": 1.20},
		{"y": 1.50, "x": 0.30, "bits": ShotBits.bit("pull"), "color": Palette.SLATE, "ws": 1.18},
		{"y": 1.65, "x": 0.88, "bits": ShotBits.bit("heat"), "color": Palette.COPPER, "ws": 1.22},
		{"y": 1.85, "x": 1.45, "bits": 0, "color": Palette.VERDIGRIS, "ws": 1.38},
	]
	for idx in configs.size():
		var c: Dictionary = configs[idx]
		var origin := Vector3(float(c["x"]), float(c["y"]), 1.8)
		var b := {
			"origin": origin, "dir": Vector3.FORWARD, "speed": 76.0, "max_dist": 40.0,
			"damage": 12.0, "kind": "arc", "weapon_id": "arc_caster", "radius": 0.25,
			"knock": 0.0, "chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 1.0,
			"color": c["color"], "wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0,
			"bits": int(c["bits"]), "width_scale": float(c["ws"]), "source": "weapon",
		}
		bolts.fire(b)
		b["travelled"] = 3.5 + float(idx % 2) * 0.40
		b["age"] = 0.08 + float(idx) * 0.03
		b["shown"] = origin + Vector3.FORWARD * float(b["travelled"])
	bolts._process(0.016)
	await _shot("bolts_volley", Vector3(2.45, 3.35, 1.15), Vector3(0.0, 1.58, -1.75))
	_clear_scene_holder(holder)


func _capture_hero_combo() -> void:
	var holder := Node3D.new()
	stage_root.add_child(holder)
	var ball := Node3D.new()
	ball.position = Vector3(0.0, 1.45, 0.0)
	holder.add_child(ball)
	var hero := HeroAssets.new()
	holder.add_child(hero)
	var fitted := hero.fit_shell_into(ball, "pylon_engineer", "", 3, {"class": Palette.ARC})
	var pod: Node3D = fitted.get("pod")
	var acc := Accretion.new()
	acc.setup()
	acc.set_lattice(true)
	ball.add_child(acc)
	acc.show_build(140.0, SAMPLE_PARTS, [], 2)
	for _i in 80:
		acc._process(1.0 / 60.0)
	var ring: Node3D = pod.get_node_or_null("WeaponRing") if pod != null else null
	if ring != null and hero.has_method("sync_weapon_rig"):
		var all_bits := ShotBits.bit("pierce") | ShotBits.bit("split") | ShotBits.bit("heat") | ShotBits.bit("bounce")
		hero.sync_weapon_rig(pod, all_bits, ["hot_rivets", "cross_split", "spiral_wave", "chain_arc", "rime_rounds"])
		var rig := ring.get_node_or_null("WeaponRigFx")
		if rig != null:
			rig.on_shot_fired("charged", 1.25)
			rig.step(0.016, {"charge": 0.9, "reloading": false}, false)
	var bolts := Bolts.new()
	bolts.setup()
	holder.add_child(bolts)
	for j in 4:
		var spread := (float(j) - 1.5) * 0.22
		var d := Vector3(sin(spread), 0.02, -cos(spread)).normalized()
		var origin := Vector3(0.0, 1.45, -1.91)
		var b := {
			"origin": origin, "dir": d, "speed": 72.0, "max_dist": 40.0,
			"damage": 12.0, "kind": "arc", "weapon_id": "arc_caster", "radius": 0.25,
			"knock": 0.0, "chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 1.0,
			"color": Palette.ARC, "wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0,
			"bits": ShotBits.bit("bounce"),
			"width_scale": 1.25 if j == 1 else 1.15, "source": "weapon",
		}
		bolts.fire(b)
		b["travelled"] = [1.15, 2.25, 1.55, 2.55][j]
		b["age"] = 0.06 + float(j) * 0.02
		b["shown"] = origin + d * float(b["travelled"])
	bolts._process(0.016)
	await _shot("hero_combo", Vector3(3.65, 2.95, -4.35), Vector3(0.0, 1.42, -1.65))
	_clear_scene_holder(holder)


func _capture_play_distance_and_variants() -> void:
	var holder := Node3D.new()
	stage_root.add_child(holder)
	var ball := Node3D.new()
	ball.position = Vector3(0.0, 1.02, 0.0)
	holder.add_child(ball)
	var hero := HeroAssets.previewing()
	holder.add_child(hero)
	var fitted: Dictionary = hero.fit_shell_into(ball, "pylon_engineer", "", 2, {"class": Palette.ARC})
	var pod: Node3D = fitted.get("pod")
	var acc := Accretion.new()
	acc.setup()
	ball.add_child(acc)
	acc.show_build(80.0, ["hot_rivets", "spiral_wave", "chain_arc", "rivet_plating"], [], 2)
	for _i in 80:
		acc._process(1.0 / 60.0)
	BallLooks.ride("cutaway", acc)
	var ink_script := load("res://src/presentation/ink_outline.gd")
	ink_script.apply(acc, "pilot")
	acc.rotation.y = 0.65
	var ring: Node3D = pod.get_node_or_null("WeaponRing") if pod != null else null
	if ring != null and hero.has_method("sync_weapon_rig"):
		var all_bits := ShotBits.bit("pierce") | ShotBits.bit("split") | ShotBits.bit("heat") | ShotBits.bit("bounce")
		hero.sync_weapon_rig(pod, all_bits, ["hot_rivets", "cross_split", "spiral_wave", "chain_arc", "rime_rounds"])
		var rig := ring.get_node_or_null("WeaponRigFx")
		if rig != null:
			rig.on_shot_fired("charged", 1.35)
			rig.step(1.0 / 60.0, {"charge": 0.9, "reloading": false}, false)
	var bolts := Bolts.new()
	bolts.setup()
	holder.add_child(bolts)
	for j in 5:
		var spread := (float(j) - 2.0) * 0.14
		var d := Vector3(sin(spread), 0.0, -cos(spread)).normalized()
		var origin := Vector3(0.0, 1.02, -1.91)
		var is_center := (j == 2)
		var b := {
			"origin": origin, "dir": d, "speed": 72.0, "max_dist": 40.0,
			"damage": 12.0, "kind": "arc", "weapon_id": "arc_caster", "radius": 0.25,
			"knock": 0.0, "chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 1.0,
			"color": Palette.AMBER if is_center else Palette.ARC, "wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0,
			"bits": ShotBits.bit("heat") if is_center else ShotBits.bit("bounce"),
			"width_scale": 1.35 if is_center else 1.15, "source": "weapon",
		}
		bolts.fire(b)
		b["travelled"] = 1.2 + float(j % 3) * 0.85
		b["age"] = 0.06 + float(j) * 0.02
		b["shown"] = origin + d * float(b["travelled"])
	bolts._process(1.0 / 60.0)
	var eye := Vector3(4.4, 4.7, -6.9)
	var target := Vector3(0.0, 1.05, -0.8)
	camera.look_at_from_position(eye, target, Vector3.UP)
	for _i in 10:
		await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var full_path := out.path_join("play_distance_8m.png")
	img.save_png(full_path)
	records.append({"id": "play_distance_8m", "eye": [eye.x, eye.y, eye.z], "target": [target.x, target.y, target.z],
		"dist_m": snappedf(eye.distance_to(target), 0.01), "sha256": FileAccess.get_sha256(full_path)})

	var img_720 := img.duplicate() as Image
	img_720.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	img_720.save_png(out.path_join("play_distance_720p.png"))

	var grey := img_720.duplicate() as Image
	var deutan := img_720.duplicate() as Image
	for y in img_720.get_height():
		for x in img_720.get_width():
			var c := img_720.get_pixel(x, y)
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			grey.set_pixel(x, y, Color(l, l, l, 1.0))
			var dr := clampf(0.367322 * c.r + 0.860646 * c.g - 0.227968 * c.b, 0.0, 1.0)
			var dg := clampf(0.280085 * c.r + 0.672501 * c.g + 0.047413 * c.b, 0.0, 1.0)
			var db := clampf(-0.011820 * c.r + 0.042940 * c.g + 0.968881 * c.b, 0.0, 1.0)
			deutan.set_pixel(x, y, Color(dr, dg, db, 1.0))
	grey.save_png(out.path_join("play_distance_greyscale.png"))
	deutan.save_png(out.path_join("play_distance_deutan.png"))
	_clear_scene_holder(holder)


func _capture_recoil_strip_60hz() -> void:
	var holder := Node3D.new()
	stage_root.add_child(holder)
	var ball := Node3D.new()
	ball.position = Vector3(0.0, 1.45, 0.0)
	holder.add_child(ball)
	var hero := HeroAssets.new()
	holder.add_child(hero)
	var fitted := hero.fit_shell_into(ball, "pylon_engineer", "", 3, {"class": Palette.ARC})
	var pod: Node3D = fitted.get("pod")
	var ring: Node3D = pod.get_node_or_null("WeaponRing") if pod != null else null
	var rig: Node3D = null
	if ring != null and hero.has_method("sync_weapon_rig"):
		var all_bits := ShotBits.bit("pierce") | ShotBits.bit("split") | ShotBits.bit("heat") | ShotBits.bit("bounce")
		hero.sync_weapon_rig(pod, all_bits, ["hot_rivets", "cross_split", "spiral_wave", "chain_arc", "rime_rounds"])
		rig = ring.get_node_or_null("WeaponRigFx")
	var bolts := Bolts.new()
	bolts.setup()
	holder.add_child(bolts)
	var eye := Vector3(3.15, 2.05, -2.55)
	var target := Vector3(0.0, 1.45, -1.25)
	camera.look_at_from_position(eye, target, Vector3.UP)

	var wanted_frames := [0, 1, 2, 4, 8, 16]
	var tiles: Array[Image] = []
	var strip_metrics := []
	var tile_w := 640
	var tile_h := 400
	var b_live: Array = []
	for f_idx in 17:
		if f_idx == 1:
			if rig != null:
				rig.on_shot_fired("charged", 1.35)
			for j in 3:
				var spread := (float(j) - 1.0) * 0.12
				var d := Vector3(sin(spread), 0.0, -cos(spread)).normalized()
				var origin := Vector3(0.0, 1.45, -1.89)
				var b := {
					"origin": origin, "dir": d, "speed": 30.0, "max_dist": 40.0,
					"damage": 12.0, "kind": "arc", "weapon_id": "arc_caster", "radius": 0.25,
					"knock": 0.0, "chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 1.0,
					"color": Palette.ARC, "wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0,
					"bits": ShotBits.bit("pierce") | ShotBits.bit("heat") if j == 1 else ShotBits.bit("bounce"),
					"width_scale": 1.30 if j == 1 else 1.12, "source": "weapon",
				}
				bolts.fire(b)
				b_live.append(b)
		if f_idx > 0:
			if rig != null:
				rig.step(1.0 / 60.0, {"charge": 0.7 if f_idx <= 4 else 0.0, "reloading": false}, false)
			for b: Dictionary in b_live:
				b["travelled"] = float(b.get("travelled", 0.0)) + 0.36
				b["age"] = float(b.get("age", 0.0)) + 1.0 / 60.0
				b["shown"] = (b["origin"] as Vector3) + (b["dir"] as Vector3) * float(b["travelled"])
			bolts._process(1.0 / 60.0)
		if f_idx in wanted_frames:
			for _k in 4:
				await RenderingServer.frame_post_draw
			var frame_img := root.get_texture().get_image()
			frame_img.resize(tile_w, tile_h, Image.INTERPOLATE_LANCZOS)
			tiles.append(frame_img)
			strip_metrics.append({
				"frame": f_idx,
				"recoil_m": snappedf(float(rig.recoil_offset()), 0.0001) if rig != null else 0.0,
				"spin_deg": snappedf(rad_to_deg(float(rig.spin_angle())), 0.2) if rig != null else 0.0,
				"heat": snappedf(float(rig.heat_level()), 0.001) if rig != null else 0.0,
			})
	var fmt: Image.Format = tiles[0].get_format() if not tiles.is_empty() else Image.FORMAT_RGB8
	var sheet := Image.create(tile_w * 3, tile_h * 2, false, fmt)
	for i in tiles.size():
		var col := i % 3
		var row := floori(float(i) / 3.0)
		sheet.blit_rect(tiles[i], Rect2i(0, 0, tile_w, tile_h), Vector2i(col * tile_w, row * tile_h))
	var sheet_path := out.path_join("recoil_strip_60hz.png")
	sheet.save_png(sheet_path)
	records.append({"id": "recoil_strip_60hz", "frames": strip_metrics, "sha256": FileAccess.get_sha256(sheet_path)})
	_clear_scene_holder(holder)
