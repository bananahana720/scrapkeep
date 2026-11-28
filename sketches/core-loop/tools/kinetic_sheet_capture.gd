extends SceneTree


const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const WorldFxAnchor := preload("res://src/presentation/world_fx/world_fx_anchor.gd")
const ModelVariants := preload("res://src/presentation/model_variants.gd")
const Recipes := preload("res://src/world/park/park_recipes.gd")
const WardenReactor := preload("res://src/combat/warden_reactor.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Comfort := preload("res://src/core/comfort.gd")

const TILE_W := 640
const TILE_H := 480
const HEADER_H := 36
const CAMERA_FOV := 38.0
const CAMERA_MARGIN := 1.48

const GATE_MIN_DRAWN_PX := 800
const GATE_MIN_DELTA_PX := 120
const GATE_MAX_NEAR_BLACK := 0.15
const GATE_MAX_FOOT_ERR := 0.45

const VIEW_ANGLES := {
	"front34": Vector2(32.0, 20.0),
	"side": Vector2(90.0, 16.0),
	"back34": Vector2(148.0, 22.0),
	"top": Vector2(18.0, 48.0),
}

const ENEMY_SCRIPTS := {
	"jolt_layer": "res://src/combat/jolt_layer.gd",
	"swatter": "res://src/combat/swatter.gd",
	"ramp_flipper": "res://src/combat/ramp_flipper.gd",
	"plated_brute": "res://src/combat/plated_brute.gd",
	"netcaster": "res://src/combat/netcaster.gd",
	"boom_tender": "res://src/combat/boom_tender.gd",
	"chaser": "res://src/combat/chaser.gd",
	"catch_trap": "res://src/combat/catch_trap.gd",
}

const FONT_3X5 := {
	"A": [2, 5, 7, 5, 5], "B": [6, 5, 6, 5, 6], "C": [3, 4, 4, 4, 3], "D": [6, 5, 5, 5, 6],
	"E": [7, 4, 6, 4, 7], "F": [7, 4, 6, 4, 4], "G": [3, 4, 5, 5, 3], "H": [5, 5, 7, 5, 5],
	"I": [7, 2, 2, 2, 7], "J": [1, 1, 1, 5, 2], "K": [5, 5, 6, 5, 5], "L": [4, 4, 4, 4, 7],
	"M": [5, 7, 7, 5, 5], "N": [5, 7, 7, 7, 5], "O": [2, 5, 5, 5, 2], "P": [6, 5, 6, 4, 4],
	"Q": [2, 5, 5, 6, 3], "R": [6, 5, 6, 5, 5], "S": [3, 4, 2, 1, 6], "T": [7, 2, 2, 2, 2],
	"U": [5, 5, 5, 5, 7], "V": [5, 5, 5, 5, 2], "W": [5, 5, 7, 7, 5], "X": [5, 5, 2, 5, 5],
	"Y": [5, 5, 2, 2, 2], "Z": [7, 1, 2, 4, 7], "0": [7, 5, 5, 5, 7], "1": [2, 6, 2, 2, 7],
	"2": [6, 1, 2, 4, 7], "3": [6, 1, 2, 1, 6], "4": [5, 5, 7, 1, 1], "5": [7, 4, 6, 1, 6],
	"6": [3, 4, 6, 5, 2], "7": [7, 1, 2, 2, 2], "8": [2, 5, 2, 5, 2], "9": [2, 5, 3, 1, 6],
	"_": [0, 0, 0, 0, 7], "-": [0, 0, 7, 0, 0], "|": [2, 2, 2, 2, 2], ":": [0, 2, 0, 2, 0],
	".": [0, 0, 0, 0, 2], " ": [0, 0, 0, 0, 0], "/": [1, 1, 2, 4, 4],
}


class DummyTerrain extends RefCounted:
	func height(_x: float, _z: float) -> float:
		return 0.0
	func on_water(_at: Vector3) -> bool:
		return false


class DummyTuning extends RefCounted:
	func f(key: String) -> float:
		if key == "gravity":
			return 24.0
		return 14.0


class DummyBallState extends RefCounted:
	var velocity := Vector3(0.0, 0.0, -18.0)
	func on_floor() -> bool:
		return true


class DummyTarget extends RefCounted:
	var pos := Vector3(0.0, 1.0, 5.5)
	var vel := Vector3(0.0, 0.0, -16.0)
	var state := DummyBallState.new()
	var tuning := DummyTuning.new()
	func ball_position() -> Vector3:
		return pos
	func planar_velocity() -> Vector3:
		return Vector3(vel.x, 0.0, vel.z)
	func speed_tier() -> int:
		return 3
	func add_external_accel(_a: Vector3) -> void:
		pass


class DummyRun extends RefCounted:
	var stage := 1
	var parts: Array = []
	func class_id() -> String:
		return "tarn"
	func add_part(_id: String, _from: String) -> void:
		pass


class DummyStages extends RefCounted:
	func world_of(_stage: int) -> int:
		return 1


class DummySystem extends RefCounted:
	func luck(_id: String) -> RandomNumberGenerator:
		var r := RandomNumberGenerator.new()
		r.seed = 42
		return r


class DummyCacheCtx extends RefCounted:
	var events: GameEvents
	var terrain := DummyTerrain.new()
	var player := DummyTarget.new()
	var run := DummyRun.new()
	var stages := DummyStages.new()


class DummyWarden extends Node3D:
	var home := Vector3.ZERO
	var world_root: Node3D
	var terrain := DummyTerrain.new()
	var target := DummyTarget.new()
	var fleet = null
	var spec := {}
	func family_point_at() -> Vector3:
		return home + Vector3(0.0, 4.5, 0.0)


var _opts := {}


func _initialize() -> void:
	_opts = parse_args(OS.get_cmdline_user_args())
	_run.call_deferred()


static func parse_args(args: PackedStringArray) -> Dictionary:
	var out := {
		"category": "enemy",
		"assets": [],
		"world": 1,
		"models": "authored",
		"frames": ["idle", "windup", "attack", "death"],
		"with_vfx": true,
		"views": ["front34"],
		"concept": "",
		"reduce_flashes": false,
		"out": "",
	}
	for raw in args:
		var arg := String(raw)
		if not arg.begins_with("--") or not arg.contains("="):
			continue
		var eq := arg.find("=")
		var k := arg.substr(2, eq - 2)
		var v := arg.substr(eq + 1)
		match k:
			"category":
				out["category"] = v.strip_edges().to_lower()
			"assets":
				out["assets"] = _split_csv(v)
			"world":
				out["world"] = clampi(int(v), 1, 3)
			"models":
				out["models"] = v.strip_edges().to_lower()
			"frames":
				out["frames"] = _split_csv(v)
			"with-vfx":
				out["with_vfx"] = v.to_lower() != "false" and v != "0"
			"views":
				out["views"] = _split_csv(v)
			"concept":
				out["concept"] = v.strip_edges()
			"reduce-flashes":
				out["reduce_flashes"] = v.to_lower() == "true" or v == "1"
			"out":
				out["out"] = v.strip_edges()
	return out


static func _split_csv(text: String) -> Array:
	var items: Array = []
	for part in text.split(",", false):
		var clean := String(part).strip_edges()
		if clean != "":
			items.append(clean)
	return items


static func validate_options(opts: Dictionary) -> String:
	var cat := String(opts.get("category", ""))
	if not (cat in ["enemy", "boss", "warden", "setpiece"]):
		return "unsupported --category=%s" % cat
	if (opts.get("assets", []) as Array).is_empty():
		return "--assets must list at least one asset id"
	if String(opts.get("out", "")) == "":
		return "--out directory is required"
	if (opts.get("frames", []) as Array).is_empty():
		return "--frames must list at least one beat"
	return ""


static func box_of(node: Node3D) -> AABB:
	var have := false
	var merged := AABB()
	if node == null or not is_instance_valid(node):
		return AABB(Vector3(-1.0, 0.0, -1.0), Vector3(2.0, 2.0, 2.0))
	var stack: Array = [node]
	while not stack.is_empty():
		var cur = stack.pop_back()
		if cur is Node3D and not (cur as Node3D).visible:
			continue
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh != null and not mi.name.begins_with("StageFloor"):
				var local_box := mi.mesh.get_aabb()
				var xf := mi.global_transform
				for ix in 2:
					for iy in 2:
						for iz in 2:
							var corner := Vector3(
								local_box.position.x + (local_box.size.x if ix == 1 else 0.0),
								local_box.position.y + (local_box.size.y if iy == 1 else 0.0),
								local_box.position.z + (local_box.size.z if iz == 1 else 0.0),
							)
							var wp := xf * corner
							if not have:
								merged = AABB(wp, Vector3.ZERO)
								have = true
							else:
								merged = merged.expand(wp)
		for child in cur.get_children():
			stack.append(child)
	if not have or merged.size.length() < 0.05:
		return AABB(Vector3(-1.2, 0.0, -1.2), Vector3(2.4, 2.4, 2.4))
	return merged


static func frame_camera(cam: Camera3D, box: AABB, view_name: String, margin := CAMERA_MARGIN) -> void:
	var angles: Vector2 = VIEW_ANGLES.get(view_name, VIEW_ANGLES["front34"])
	var az := deg_to_rad(angles.x)
	var el := deg_to_rad(angles.y)
	var center := box.get_center()
	var radius := maxf(1.2, box.size.length() * 0.5)
	var half_fov := deg_to_rad(cam.fov * 0.5)
	var dist := (radius / tan(half_fov)) * margin
	var dir := Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el)).normalized()
	cam.global_position = center + dir * dist
	cam.look_at(center, Vector3.UP)


static func image_metrics(img: Image, bg_img: Image, idle_img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var drawn_px := 0
	var near_black_px := 0
	var delta_px := 0
	var luma_sum := 0.0
	var step := 2
	for y in range(0, h, step):
		for x in range(0, w, step):
			var c := img.get_pixel(x, y)
			var is_drawn := true
			if bg_img != null and bg_img.get_width() == w and bg_img.get_height() == h:
				var b := bg_img.get_pixel(x, y)
				var diff := absf(c.r - b.r) + absf(c.g - b.g) + absf(c.b - b.b)
				is_drawn = diff > 0.07
			if is_drawn:
				drawn_px += step * step
				var luma := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
				luma_sum += luma
				if luma < 0.04:
					near_black_px += step * step
			if idle_img != null and idle_img.get_width() == w and idle_img.get_height() == h:
				var ic := idle_img.get_pixel(x, y)
				var idiff := absf(c.r - ic.r) + absf(c.g - ic.g) + absf(c.b - ic.b)
				if idiff > 0.08:
					delta_px += step * step
	var near_black := float(near_black_px) / float(maxi(1, drawn_px))
	var mean_luma := luma_sum / float(maxi(1, drawn_px / (step * step)))
	return {
		"drawn_px": drawn_px,
		"delta_vs_idle_px": delta_px,
		"near_black": snappedf(near_black, 0.0001),
		"mean_luma": snappedf(mean_luma, 0.0001),
	}


static func judge_metrics(beat: String, metrics: Dictionary, foot_min_y: float, death_ok := true) -> Dictionary:
	var reasons: Array = []
	var drawn := int(metrics.get("drawn_px", 0))
	var delta := int(metrics.get("delta_vs_idle_px", 0))
	var nb := float(metrics.get("near_black", 1.0))
	if drawn < GATE_MIN_DRAWN_PX:
		reasons.append("drawn_px %d < %d" % [drawn, GATE_MIN_DRAWN_PX])
	if beat != "idle" and delta < GATE_MIN_DELTA_PX:
		reasons.append("delta_vs_idle_px %d < %d" % [delta, GATE_MIN_DELTA_PX])
	if nb > GATE_MAX_NEAR_BLACK:
		reasons.append("near_black %.4f > %.2f" % [nb, GATE_MAX_NEAR_BLACK])
	if beat == "idle" and absf(foot_min_y) > GATE_MAX_FOOT_ERR:
		reasons.append("foot_min_y %.3f outside +/-%.2f" % [foot_min_y, GATE_MAX_FOOT_ERR])
	if beat == "death" and not death_ok:
		reasons.append("death clip cancelled")
	return {"pass": reasons.is_empty(), "reasons": reasons}


static func stitch_strip(frames: Array, labels: Array) -> Image:
	var n := maxi(1, frames.size())
	var tile_w := TILE_W
	var tile_h := TILE_H
	if not frames.is_empty() and frames[0] is Image:
		tile_w = (frames[0] as Image).get_width()
		tile_h = (frames[0] as Image).get_height()
	var sheet := Image.create(tile_w * n, tile_h + HEADER_H, false, Image.FORMAT_RGBA8)
	sheet.fill(Palette.CHARCOAL)
	for i in frames.size():
		var img := frames[i] as Image
		if img == null:
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(i * tile_w, HEADER_H))
		var label := String(labels[i]) if i < labels.size() else ("FRAME_%d" % i)
		draw_text(sheet, label.to_upper(), i * tile_w + 12, 10, 3, Palette.LEDGER)
		if i > 0:
			for y in sheet.get_height():
				sheet.set_pixel(i * tile_w, y, Palette.BRASS)
				if i * tile_w + 1 < sheet.get_width():
					sheet.set_pixel(i * tile_w + 1, y, Palette.CHARCOAL)
	return sheet


static func draw_text(img: Image, text: String, x0: int, y0: int, scale: int, col: Color) -> void:
	var cx := x0
	for idx in text.length():
		var ch := text.substr(idx, 1)
		var rows: Array = FONT_3X5.get(ch, FONT_3X5[" "])
		for r in rows.size():
			var bits := int(rows[r])
			for c in 3:
				if (bits & (4 >> c)) != 0:
					for dy in scale:
						for dx in scale:
							var px := cx + c * scale + dx
							var py := y0 + r * scale + dy
							if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
								img.set_pixel(px, py, col)
		cx += 4 * scale


static func freeze_particles(node: Node) -> int:
	var count := 0
	for p in node.find_children("*", "GPUParticles3D", true, false):
		var gpu := p as GPUParticles3D
		gpu.emitting = true
		gpu.preprocess = maxf(0.08, gpu.lifetime * 0.35)
		gpu.speed_scale = 0.0
		gpu.restart()
		count += 1
	return count


func _run() -> void:
	var err := validate_options(_opts)
	if err != "":
		push_error("kinetic_sheet_capture: " + err)
		quit(2)
		return
	FlashGuard.on = bool(_opts["reduce_flashes"])
	Comfort.reduced_motion = false
	var out_dir := String(_opts["out"])
	DirAccess.make_dir_recursive_absolute(out_dir)
	var stage := build_stage(int(_opts["world"]))
	root.add_child(stage)
	var vp := SubViewport.new()
	vp.size = Vector2i(TILE_W, TILE_H)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = false
	vp.msaa_3d = Viewport.MSAA_2X
	stage.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = CAMERA_FOV
	cam.far = 250.0
	cam.near = 0.1
	vp.add_child(cam)
	cam.current = true
	var receipt := {
		"category": _opts["category"],
		"world": int(_opts["world"]),
		"with_vfx": bool(_opts["with_vfx"]),
		"reduce_flashes": bool(_opts["reduce_flashes"]),
		"pass": true,
		"assets": {},
	}
	for asset_id in _opts["assets"]:
		var res: Dictionary = await _capture_asset(stage, vp, cam, String(asset_id), out_dir)
		receipt["assets"][String(asset_id)] = res
		if not bool(res.get("pass", false)):
			receipt["pass"] = false
	var json_path := out_dir.path_join("kinetic_receipt.json")
	var fh := FileAccess.open(json_path, FileAccess.WRITE)
	if fh != null:
		fh.store_string(JSON.stringify(receipt, "  ") + "\n")
		fh.close()
	print("kinetic_sheet_capture: %s -> %s" % ["PASS" if receipt["pass"] else "FAIL", json_path])
	stage.queue_free()
	await process_frame
	quit(0 if receipt["pass"] else 1)


static func build_stage(world_id: int) -> Node3D:
	var stage := Node3D.new()
	stage.name = "KineticStage"
	var row: Dictionary = WorldLook.ROWS.get(world_id, WorldLook.ROWS[1])
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(row.get("fill_color", Color("a3c4e6"))).darkened(0.25)
	sky_mat.sky_horizon_color = Color("d8ccb6")
	sky_mat.ground_bottom_color = Palette.SANDSTONE.darkened(0.15)
	sky_mat.ground_horizon_color = Color("d8ccb6")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = row.get("ambient", Color("9db5cf"))
	env.ambient_light_energy = maxf(0.45, float(row.get("energy", 0.28)) * 1.8)
	env.tonemap_exposure = float(row.get("exposure", 1.1))
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = row.get("sun_color", Color("ffd49a"))
	sun.light_energy = float(row.get("sun_energy", 2.0))
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = row.get("fill_color", Color("a3c4e6"))
	fill.light_energy = maxf(0.55, float(row.get("fill", 0.5)) * 1.2)
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(float(row.get("fill_pitch", -50.0)), -140.0, 0.0)
	stage.add_child(fill)
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "StageFloor"
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(80.0, 0.4, 80.0)
	floor_mi.mesh = floor_box
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Palette.SANDSTONE
	floor_mat.roughness = 0.92
	floor_mi.material_override = floor_mat
	floor_mi.position = Vector3(0.0, -0.2, 0.0)
	stage.add_child(floor_mi)
	var ruler := MeshInstance3D.new()
	ruler.name = "StageFloorRuler"
	var rbox := BoxMesh.new()
	rbox.size = Vector3(1.0, 0.04, 0.08)
	ruler.mesh = rbox
	ruler.material_override = PaletteMaterials.solid(Palette.CHARCOAL, 0.9)
	ruler.position = Vector3(0.0, 0.02, 2.8)
	stage.add_child(ruler)
	return stage


func _grab(vp: SubViewport) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


func _capture_asset(stage: Node3D, vp: SubViewport, cam: Camera3D, asset_id: String, out_dir: String) -> Dictionary:
	var cat := String(_opts["category"])
	var views: Array = _opts["views"]
	var beats: Array = _opts["frames"]
	var result := {"pass": true, "views": {}}
	for view_name_raw in views:
		var view_name := String(view_name_raw)
		var holder := Node3D.new()
		holder.name = "Subject_" + asset_id
		stage.add_child(holder)
		var ctx: Dictionary = await _setup_subject(cat, asset_id, holder)
		var base_box: AABB = ctx.get("box", box_of(holder))
		var foot_min_y := base_box.position.y
		var margin := float(ctx.get("margin", CAMERA_MARGIN))
		frame_camera(cam, base_box, view_name, margin)
		holder.visible = false
		var bg_img: Image = await _grab(vp)
		holder.visible = true
		var imgs: Array = []
		var labels: Array = []
		var idle_img: Image = null
		var view_res := {"pass": true, "foot_min_y": snappedf(foot_min_y, 0.001), "frames": {}}
		for beat_raw in beats:
			var beat := String(beat_raw)
			var beat_info: Dictionary = await _pose_subject(cat, asset_id, beat, ctx, holder)
			if bool(_opts["with_vfx"]):
				freeze_particles(holder)
			var img: Image = await _grab(vp)
			if idle_img == null:
				idle_img = img
			var m := image_metrics(img, bg_img, idle_img)
			var death_ok := bool(beat_info.get("death_ok", true))
			var verdict := judge_metrics(beat, m, foot_min_y, death_ok)
			m["pass"] = verdict["pass"]
			m["reasons"] = verdict["reasons"]
			view_res["frames"][beat] = m
			if not bool(verdict["pass"]):
				view_res["pass"] = false
				result["pass"] = false
			imgs.append(img)
			labels.append("%s | %s | %s" % [asset_id, beat, view_name])
		var sheet := stitch_strip(imgs, labels)
		var sheet_path := out_dir.path_join("%s_%s_4x1.png" % [asset_id, view_name])
		sheet.save_png(sheet_path)
		view_res["sheet"] = sheet_path
		result["views"][view_name] = view_res
		holder.queue_free()
		await process_frame
		await process_frame
	return result


func _setup_subject(cat: String, asset_id: String, holder: Node3D) -> Dictionary:
	match cat:
		"enemy":
			var path: String = ENEMY_SCRIPTS.get(asset_id, "")
			if path == "" or not ResourceLoader.exists(path):
				return {"error": "unknown enemy " + asset_id}
			var script := load(path) as GDScript
			var enemy: Node3D = script.new()
			enemy.kind = asset_id
			holder.add_child(enemy)
			enemy.global_position = Vector3(0.0, 1.1, 0.0)
			enemy.setup(DummyTarget.new(), DummyTerrain.new(), holder, func() -> bool: return true, 1.0)
			await physics_frame
			await process_frame
			var raw_box := box_of(enemy)
			if absf(raw_box.position.y) > 0.02:
				enemy.global_position.y -= raw_box.position.y
				await process_frame
				raw_box = box_of(enemy)
			return {"enemy": enemy, "box": raw_box, "margin": 1.38}
		"warden":
			var w := DummyWarden.new()
			w.world_root = holder
			holder.add_child(w)
			var driver := WardenReactor.new()
			driver.sheet_dir = Vector3(0.0, 0.0, 1.0)
			driver._show_sheet(w, WardenReactor.LANE_TELL_ALPHA)
			await process_frame
			var box := AABB(Vector3(-12.0, 0.0, 10.0), Vector3(24.0, 4.0, 22.0))
			return {"warden": w, "driver": driver, "box": box, "margin": 1.25}
		"boss":
			var scooter := Node3D.new()
			scooter.name = "BrindleScooter"
			holder.add_child(scooter)
			var anim: AnimationPlayer = Requisition.dress_scooter(scooter)
			await process_frame
			var raw_box := box_of(scooter)
			var base_y := -raw_box.position.y
			scooter.position.y = base_y
			await process_frame
			var box := box_of(scooter)
			return {"scooter": scooter, "anim": anim, "base_y": base_y, "box": box, "margin": 1.65}
		"setpiece":
			if asset_id == "camp_pet":
				var pit := _place_glb(holder, "res://assets/models/camp/camp_fire_pit.glb", Vector3(-1.8, 0.0, -1.1))
				var pet := _place_glb(holder, "res://assets/models/camp/camp_pet.glb", Vector3(0.7, 0.0, 0.3))
				var fx := WorldFxAnchor.make("camp")
				if fx != null:
					fx.position = Vector3(-1.8, 0.65, -1.1)
					holder.add_child(fx)
				await process_frame
				var box := AABB(Vector3(-3.0, 0.0, -2.2), Vector3(4.8, 2.4, 3.6))
				return {"pet": pet, "pit": pit, "fx": fx, "box": box, "margin": 1.22}
			elif asset_id == "cracked_cache":
				var ctx := DummyCacheCtx.new()
				ctx.events = GameEvents.new()
				holder.add_child(ctx.events)
				var cache := CrackedCache.new()
				cache.ctx = ctx
				cache.system = DummySystem.new()
				cache.id = "capture_cache"
				cache.relic_guaranteed = true
				holder.add_child(cache)
				cache.build()
				await process_frame
				var box := box_of(cache)
				return {"cache": cache, "box": box, "margin": 1.32}
	return {"box": AABB(Vector3(-1.5, 0.0, -1.5), Vector3(3.0, 3.0, 3.0))}


func _place_glb(parent: Node3D, path: String, at: Vector3) -> Node3D:
	var holder := Node3D.new()
	holder.position = at
	parent.add_child(holder)
	var body := Recipes.collider_body(holder)
	var scenes := Recipes.load_glb(path)
	if not scenes.is_empty():
		var s: Node = scenes[0]
		Recipes.attach_views(s, holder, body, Transform3D.IDENTITY)
		s.free()
	return holder


func _pose_subject(cat: String, asset_id: String, beat: String, ctx: Dictionary, holder: Node3D) -> Dictionary:
	var vfx_on := bool(_opts["with_vfx"])
	match cat:
		"enemy":
			var enemy = ctx.get("enemy")
			if enemy == null or not is_instance_valid(enemy):
				return {"death_ok": false}
			if beat == "idle":
				enemy.phase = enemy.Phase.IDLE
				enemy._t = 0.0
				enemy._pose()
				await physics_frame
				return {"death_ok": true}
			elif beat == "windup":
				enemy.phase = enemy.Phase.WARN
				enemy._t = enemy.warn_seconds * 0.85
				if asset_id == "ramp_flipper":
					enemy._commit(Vector3(0.0, 0.0, 4.0))
					enemy.phase = enemy.Phase.WARN
					enemy._t = enemy.warn_seconds * 0.85
				elif asset_id == "netcaster" and vfx_on:
					FxLibrary.burst(holder, "brass_spark", enemy.global_position + Vector3(0.0, 2.8, -0.3), 10)
				enemy._pose()
				await physics_frame
				return {"death_ok": true}
			elif beat == "attack":
				enemy.phase = enemy.Phase.LIVE
				enemy._t = 0.08
				if asset_id == "plated_brute":
					enemy.on_struck("ram", "front", {"full": true})
					for _i in 6:
						await physics_frame
				elif asset_id == "swatter":
					enemy._go_live()
				elif asset_id == "jolt_layer":
					enemy._crackle(14, 10)
				elif asset_id == "netcaster":
					if vfx_on:
						FxLibrary.burst(holder, "arc_fizz", enemy.global_position + Vector3(0.0, 1.8, -0.3), 14)
						FxLibrary.burst(holder, "brass_spark", enemy.global_position + Vector3(0.0, 2.6, -0.3), 10)
				elif asset_id == "ramp_flipper":
					enemy._go_live()
				elif asset_id == "boom_tender":
					if vfx_on:
						FxLibrary.burst(holder, "plate_chunks", enemy.global_position + Vector3(0.0, 0.8, -3.0), 10)
						FxLibrary.burst(holder, "brass_spark", enemy.global_position + Vector3(0.0, 0.9, -3.0), 12)
						FxLibrary.burst(holder, "steam_puff", enemy.global_position + Vector3(0.0, 0.8, -3.0), 6)
				enemy._pose()
				await physics_frame
				return {"death_ok": true}
			elif beat == "death":
				if asset_id == "catch_trap" and enemy.get("_cup") != null:
					enemy._cup.top_level = true
				enemy.take_damage(enemy.hp + 10.0)
				var has_clip := holder.get_node_or_null("DeathClip") != null
				if vfx_on:
					FxLibrary.burst(holder, "plate_chunks", Vector3(0.0, 1.0, 0.0), 10)
					FxLibrary.burst(holder, "steam_puff", Vector3(0.0, 1.2, 0.0), 6)
				for _i in 12:
					await physics_frame
				var expect_clip := asset_id in ["catch_trap", "chaser", "swatter", "ramp_flipper", "jolt_layer", "netcaster", "boom_tender"]
				return {"death_ok": has_clip or not expect_clip}
		"warden":
			var w = ctx["warden"]
			var d: WardenReactor = ctx["driver"]
			match beat:
				"idle":
					d._show_sheet(w, WardenReactor.LANE_TELL_ALPHA)
				"windup":
					d._show_sheet(w, WardenReactor.SHEET_ALPHA)
					if is_instance_valid(d._sheet_view):
						d._sheet_view.scale = Vector3(1.0, 1.0, 0.52)
				"attack":
					d._show_sheet(w, WardenReactor.SHEET_ALPHA)
					if is_instance_valid(d._sheet_view):
						d._sheet_view.scale = Vector3.ONE
					if vfx_on:
						FxLibrary.burst(holder, "steam_puff", Vector3(0.0, 0.8, 30.0), 14, Color("e8efe9"))
						FxLibrary.burst(holder, "slam_dust", Vector3(0.0, 0.6, 28.0), 10)
				"death":
					d._show_sheet(w, WardenReactor.SHEET_ALPHA)
					if is_instance_valid(d._sheet_view):
						d._sheet_view.scale = Vector3(1.0, 1.0, 1.0)
					if vfx_on:
						FxLibrary.burst(holder, "steam_puff", Vector3(0.0, 1.4, 22.0), 16, Color("e8efe9"))
						FxLibrary.burst(holder, "brass_spark", Vector3(0.0, 1.6, 16.0), 12)
			await process_frame
			return {"death_ok": true}
		"boss":
			var sc: Node3D = ctx["scooter"]
			var anim: AnimationPlayer = ctx["anim"]
			var by: float = float(ctx.get("base_y", 0.7))
			match beat:
				"idle":
					sc.position = Vector3(0.0, by, 0.0)
					sc.rotation = Vector3.ZERO
					if anim != null:
						BossModel.play(anim, "chase")
				"windup":
					sc.position = Vector3(0.0, by + 1.1, -0.3)
					sc.rotation = Vector3(-0.22, 0.15, 0.0)
					if anim != null:
						BossModel.play(anim, "eject")
				"attack":
					sc.position = Vector3(0.0, by, 0.35)
					sc.rotation = Vector3(0.0, 0.0, 0.14)
					if vfx_on:
						FxLibrary.burst(holder, "slam_dust", Vector3(0.0, 0.2, 0.35), 14)
						FxLibrary.burst(holder, "steam_puff", Vector3(0.0, 0.8, -1.3), 8)
				"death":
					sc.position = Vector3(0.25, by, 0.15)
					sc.rotation = Vector3(0.05, 0.4, -0.22)
					if vfx_on:
						FxLibrary.burst(holder, "brass_spark", Vector3(0.25, 1.1, 0.15), 16)
						FxLibrary.burst(holder, "steam_puff", Vector3(-0.3, 0.9, -1.0), 10)
			await process_frame
			return {"death_ok": true}
		"setpiece":
			if asset_id == "camp_pet":
				var pet: Node3D = ctx["pet"]
				match beat:
					"idle":
						pet.position = Vector3(0.7, 0.0, 0.3)
						pet.scale = Vector3.ONE
						pet.rotation = Vector3.ZERO
					"windup":
						pet.position = Vector3(0.7, 0.0, 0.3)
						pet.scale = Vector3(1.18, 0.80, 1.18)
						pet.rotation = Vector3(0.0, -0.45, 0.0)
					"attack":
						pet.position = Vector3(1.0, 0.72, 0.7)
						pet.scale = Vector3(0.86, 1.20, 0.86)
						pet.rotation = Vector3(0.0, -0.55, 0.0)
						if vfx_on:
							FxLibrary.burst(holder, "brass_spark", pet.global_position + Vector3.UP * 0.7, 12, Palette.BRASS)
							FxLibrary.burst(holder, "steam_puff", Vector3(0.7, 0.2, 0.3), 6)
					"death":
						pet.position = Vector3(1.25, 0.0, 0.95)
						pet.scale = Vector3(1.16, 0.84, 1.16)
						pet.rotation = Vector3(0.0, -0.55, 0.0)
						if vfx_on:
							FxLibrary.burst(holder, "steam_puff", Vector3(1.25, 0.2, 0.95), 8)
				await process_frame
				return {"death_ok": true}
			elif asset_id == "cracked_cache":
				var cache: CrackedCache = ctx["cache"]
				match beat:
					"idle":
						pass
					"windup":
						cache.crumble()
						if vfx_on:
							FxLibrary.burst(holder, "crack_debris", Vector3(0.0, 2.0, 4.5), 14)
					"attack":
						Comfort.reduced_motion = true
						cache.fire()
						Comfort.reduced_motion = false
						if vfx_on:
							FxLibrary.burst(holder, "brass_spark", Vector3(0.0, 1.8, -1.5), 16, Palette.BRASS)
							FxLibrary.burst(holder, "steam_puff", Vector3(0.0, 1.5, -1.5), 8)
					"death":
						if cache.offers.size() > 0:
							cache.take(0)
						await process_frame
				await process_frame
				return {"death_ok": true}
	return {"death_ok": true}
