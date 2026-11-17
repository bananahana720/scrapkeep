extends SceneTree

# Water flow stills on the real renderer: the spillway scenery (spill_water.gdshader) shot through an
# orthographic camera, at the spill sheets (side on, from the arena) and at the tailrace (from above).
# Needs a window, so run it only through scripts/water-flow-stills.mjs (scripts/gate/display-run.mjs).
#   --out=<absolute dir>        where the PNGs and stats.json go (outside the scratch home)
#   --shader=<absolute file>    shoot with this shader source instead (the stage's old water, for "before")
#   --calm                      water_flow_scale 0.35 (reduced motion), as SpillwayScenery.set_water_calm sets it
# It writes two overview stills (all the sheets; the whole tailrace) and, for one close view of a sheet and one of
# the tailrace: <view>_ground.png (water hidden), <view>_a.png and <view>_b.png (STEP_S apart) and a sequence
# <view>_seq<k>.png (SEQ_GAP_S apart). In each close view it measures, inside the water mask (pixels the water
# changes against the ground) and outside it, the share of pixels that changed between a and b; and the pattern's
# shift along the expected flow on screen (the projected downhill, or the tailrace's drift), found as the best
# match of the later still against the earlier one moved along that axis. Positive is with the flow, negative is
# uphill. The speed is the median over the a-b pair and each sequence pair, in metres a second on the surface.
# Exit 0 when each close view moves inside the water, holds still outside it and shifts with the flow; 1 otherwise.
# SCRAPKEEP_WATER_FLOW_PLANT=freeze sets water_flow_scale to 0, so the water stands still and the run must exit 1.
# What it cannot show: whether the water looks good, and frame cost (no frame-time reading is taken).

const Terrain := preload("res://src/world/terrain.gd")
const Scenery := preload("res://src/presentation/spillway_scenery.gd")

const SIZE := Vector2i(1280, 720)
const STEP_S := 0.4
const SEQ := 6
const SEQ_GAP_S := 0.25
# The close views are this many metres tall; a spill sheet is about this half wide.
const VIEW_M := 25.0
const SHEET_HALF_M := 5.0
# A pixel changed when its luminance moved more than this (of 255); it is water when the water moves it this far.
const CHANGED := 2
const WATER_DIFF := 4
const MOVES_IN := 0.15
const STILL_OUT := 0.01
const SEARCH_PX := 40
const STRIDE := 4

var out := ""
var shader_file := ""
var calm := false
var plant := OS.get_environment("SCRAPKEEP_WATER_FLOW_PLANT")
var camera: Camera3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shader="):
			shader_file = arg.trim_prefix("--shader=")
		elif arg == "--calm":
			calm = true
		else:
			printerr("water_flow_stills: unknown option %s" % arg)
			quit(2)
			return
	if out.is_empty() or DisplayServer.get_name() == "headless":
		printerr("water_flow_stills: needs --out=<absolute dir> and a display")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	_shoot.call_deferred()


func _shoot() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var terrain := Terrain.new()
	terrain.build(world)
	var scenery := Scenery.build(terrain.geometry_root(1))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(camera)
	camera.current = true
	for t in root.find_children("*", "Terrain3D", true, false):
		t.set_camera(camera)
	var sheets: MeshInstance3D = scenery.get_node("SpillSheets")
	var tailrace: MeshInstance3D = scenery.get_node("Tailrace")
	scenery.get_node("WaterMist").visible = false
	if not shader_file.is_empty():
		var old := Shader.new()
		old.code = FileAccess.get_file_as_string(shader_file)
		for view in [sheets, tailrace]:
			(view.material_override as ShaderMaterial).shader = old
	var scale := 0.0 if plant == "freeze" else (Scenery.CALM_FLOW if calm else 1.0)
	RenderingServer.global_shader_parameter_set("water_flow_scale", scale)
	var drift = (tailrace.material_override as ShaderMaterial).get_shader_parameter("drift")
	print("water_flow_stills: shader %s, water_flow_scale %.2f, plant %s, tailrace drift %s" % [
		"stage file" if not shader_file.is_empty() else "branch", scale, plant if plant != "" else "none", drift])
	# Overview stills, not measured: all the sheets side on, the whole tailrace from above.
	var box := sheets.global_transform * sheets.mesh.get_aabb()
	_side_on(box.get_center(), box.size.y * 1.15, box.size.z)
	(await _still()).save_png(out.path_join("overview_sheets.png"))
	var tail_box := tailrace.global_transform * tailrace.mesh.get_aabb()
	_from_above(tail_box.get_center(), maxf(tail_box.size.z, tail_box.size.x * SIZE.y / float(SIZE.x)) * 1.1, tail_box.size.y)
	(await _still()).save_png(out.path_join("overview_tailrace.png"))
	# Close views: the spill sheet nearest the middle, and the middle of the tailrace.
	var mid := box.get_center().x
	var nearest := INF
	for v in sheets.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if absf(v.x - mid) < absf(nearest - mid):
			nearest = v.x
	var sum := 0.0
	var count := 0
	for v in sheets.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if absf(v.x - nearest) < SHEET_HALF_M * 2.0:
			sum += v.x
			count += 1
	var sheet_at := Vector3(sum / count, box.get_center().y, box.get_center().z)
	var rows := {}
	_side_on(sheet_at, VIEW_M, box.size.z)
	rows["sheet"] = await _view("sheet", [sheets, tailrace], sheet_at, Vector3.DOWN)
	_from_above(tail_box.get_center(), VIEW_M, tail_box.size.y)
	var along := Vector3(drift.x, 0.0, drift.y).normalized() if drift != null else Vector3.FORWARD
	rows["tailrace"] = await _view("tailrace", [sheets, tailrace], tail_box.get_center(), along)
	var ok := true
	for key in rows:
		var row: Dictionary = rows[key]
		var good: bool = row.moved_in > MOVES_IN and row.moved_out < STILL_OUT and row.shift_px > 0.5
		ok = ok and good
		print("%s %s: water %d px, changed in water %.3f, outside %.4f; a to b shift with the flow %.2f px in %.3f s; median %.3f m/s on the surface over %d pairs (%.1f px/m): %s" % [
			"PASS" if good else "FAIL", key, row.water_px, row.moved_in, row.moved_out, row.shift_px, row.elapsed_s,
			row.speed_m_s, row.speeds.size(), row.px_per_m, ", ".join(row.speeds.map(func(v): return "%.3f" % v))])
	var file := FileAccess.open(out.path_join("stats.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"scale": scale, "plant": plant, "shader": shader_file, "step_s": STEP_S, "views": rows}, "\t"))
	file.close()
	print("water_flow_stills: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _side_on(centre: Vector3, size_m: float, depth_m: float) -> void:
	camera.size = size_m
	camera.look_at_from_position(centre + Vector3(0, 0, -40), centre, Vector3.UP)
	camera.near = 40.0 - depth_m * 0.5 - 6.0
	camera.far = 40.0 + depth_m * 0.5 + 6.0


func _from_above(centre: Vector3, size_m: float, depth_m: float) -> void:
	camera.size = size_m
	camera.look_at_from_position(centre + Vector3(0, 60, 0), centre, Vector3(0, 0, 1))
	camera.near = 60.0 - depth_m * 0.5 - 4.0
	camera.far = 60.0 + depth_m * 0.5 + 4.0


func _view(label: String, water: Array, centre: Vector3, flow_dir: Vector3) -> Dictionary:
	for view: Node3D in water:
		view.visible = false
	var ground := await _still()
	for view: Node3D in water:
		view.visible = true
	var a := await _still()
	var t_a := Time.get_ticks_usec()
	await _wait(STEP_S)
	var b := await _still()
	var t_b := Time.get_ticks_usec()
	var elapsed := (t_b - t_a) / 1e6
	ground.save_png(out.path_join("%s_ground.png" % label))
	a.save_png(out.path_join("%s_a.png" % label))
	b.save_png(out.path_join("%s_b.png" % label))
	var on_screen := camera.unproject_position(centre + flow_dir) - camera.unproject_position(centre)
	var axis := on_screen.normalized()
	var px_per_m := on_screen.length() / flow_dir.length()
	var stills: Array = [[_lum(b), t_b]]
	for k in SEQ:
		await _wait(SEQ_GAP_S)
		var next := await _still()
		stills.append([_lum(next), Time.get_ticks_usec()])
		next.save_png(out.path_join("%s_seq%d.png" % [label, k]))
	var ground_l := _lum(ground)
	var row := _measure(ground_l, _lum(a), stills[0][0], axis)
	var speeds: Array = [row.shift_px / elapsed / px_per_m]
	for k in range(1, stills.size()):
		var pair := _measure(ground_l, stills[k - 1][0], stills[k][0], axis)
		speeds.append(pair.shift_px / ((stills[k][1] - stills[k - 1][1]) / 1e6) / px_per_m)
	var sorted := speeds.duplicate()
	sorted.sort()
	row.elapsed_s = elapsed
	row.axis = [axis.x, axis.y]
	row.px_per_m = px_per_m
	row.speeds = speeds
	row.speed_m_s = sorted[sorted.size() / 2]
	return row


func _wait(seconds: float) -> void:
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < int(seconds * 1e6):
		await process_frame


func _still() -> Image:
	for f in 4:
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _lum(image: Image) -> PackedByteArray:
	var copy := image.duplicate() as Image
	copy.convert(Image.FORMAT_L8)
	return copy.get_data()


func _measure(ground: PackedByteArray, a: PackedByteArray, b: PackedByteArray, axis: Vector2) -> Dictionary:
	var w := SIZE.x
	var h := SIZE.y
	var water := PackedByteArray()
	water.resize(w * h)
	var water_px := 0
	var in_changed := 0
	var out_px := 0
	var out_changed := 0
	for i in w * h:
		var wet := absi(int(a[i]) - int(ground[i])) > WATER_DIFF or absi(int(b[i]) - int(ground[i])) > WATER_DIFF
		var changed := absi(int(a[i]) - int(b[i])) > CHANGED
		if wet:
			water[i] = 1
			water_px += 1
			in_changed += int(changed)
		else:
			out_px += 1
			out_changed += int(changed)
	# Best match of b against a moved s pixels along the axis: mean |b(p + s*axis) - a(p)| over water pixels.
	var costs := {}
	for s in range(-SEARCH_PX, SEARCH_PX + 1):
		var dx := int(round(axis.x * s))
		var dy := int(round(axis.y * s))
		var total := 0
		var n := 0
		for y in range(SEARCH_PX, h - SEARCH_PX, STRIDE):
			for x in range(SEARCH_PX, w - SEARCH_PX, STRIDE):
				var i := y * w + x
				var j := (y + dy) * w + x + dx
				if water[i] == 0 or water[j] == 0:
					continue
				total += absi(int(b[j]) - int(a[i]))
				n += 1
		costs[s] = float(total) / maxf(1.0, n)
	var best := 0
	for s in costs:
		if costs[s] < costs[best]:
			best = s
	var shift := float(best)
	if best > -SEARCH_PX and best < SEARCH_PX:
		var l: float = costs[best - 1]
		var c: float = costs[best]
		var r: float = costs[best + 1]
		var bend := l - 2.0 * c + r
		if bend > 0.0:
			shift += 0.5 * (l - r) / bend
	return {"water_px": water_px, "moved_in": float(in_changed) / maxf(1.0, water_px),
		"moved_out": float(out_changed) / maxf(1.0, out_px), "shift_px": shift, "mismatch": costs[best]}
